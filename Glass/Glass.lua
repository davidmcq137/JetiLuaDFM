--[[

   -----------------------------------------------------------------------------------------
   Glass.lua -- write telemetry values to the serial link for AR glasses

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   Glass.lua released under MIT license by DFM 2024
   -----------------------------------------------------------------------------------------

--]]

local appName = "Glass"
local pathApp = "Apps/"..appName.."/"
local pathImages = pathApp.."Images/"
local pathConfigs = pathApp.."Configs/"
local pathJson = pathApp.."Json/"

local Glass = {}
Glass.sensorLalist = {"..."}
Glass.sensorLslist = {"..."}
Glass.sensorIdlist = {0}
Glass.sensorPalist = {0}
Glass.sensorUnlist = {"-"}
Glass.sensorDplist = {0}
Glass.sensorTylist = {0}

local pageNumber = 0
local pageMax = 0
local pageLimit = 3
local pageNumberTele
local pageSw
local subForm
local savedRow = 0
local gaugeNumber = 0
local gaugeMax = 10
local emflag
local sidSerial
local lastWrite = 0
local availImgs = {}
local encodedImgs = {}
local id2avail = {}
local editImgs = {}
local imageNum
local imageMax
local modelName
local state = {IDLE = 1, STANDBY = 2,SENDHEADER = 3, SENDFONTS = 4, SENDIMGS = 5,
	       SENDFOOTER = 6, SENDACTIVE = 7, SENDFMTS = 8}
local sendState = state.IDLE
local sendFP, sendFPser
local sendImgs
local sendImgsIdx
local sendAA
local sendFF
local sendTime
local sendLast = 0
local cpu = 0
local configLine
--local fmtNumber = 0
local writeJSON = true
local jsonHoldTime = 0
local availFmt = {}
local availFmts = {}
local tempCall
local sendFPtemp
local configVersion
local cfgimg = {}

--[[
local teleSensors
local txTeleSensors
local txSensorNames = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		       "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		       "rxBVoltage", "rxBPercent", "photoValue"}
local txSensorUnits = {"V", "%", "mA", "mAh", "%", "V", "%", "V", "V", "%", " "}
local txSensorDP    = { 1,   0,    0,     0,   0,   1,   0,   1,   1,   0,   0}
local txRSSINames = {"rx1Ant1", "rx1Ant2", "rx2Ant1", "rx2Ant2",
		     "rxBAnt1", "rxBAnt2"}
--]]

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function drawTextCenter(x, y, str, font)
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
end

local function dpFmt(x)
   if math.abs(x) - math.floor(math.abs(x)) == 0 then
      return "%d"
   end
   if math.abs(10*x) - math.floor(math.abs(10*x)) == 0 then
      return "%.1f"
   end
   return "%.2f"
end

local function readSensors(tt)
   local sensorLbl = "***"
   local l1, l2
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    table.insert(tt.sensorLalist, l1 .. "_" .. l2)
	    table.insert(tt.sensorLslist, sensor.label)	    
	    table.insert(tt.sensorIdlist, sensor.id)
	    table.insert(tt.sensorPalist, sensor.param)
	    table.insert(tt.sensorUnlist, sensor.unit)
	    table.insert(tt.sensorDplist, sensor.decimals)
	    table.insert(tt.sensorTylist, sensor.type)	    
	 end
      end
   end

   --[[
   teleSensors = #tt.sensorLalist
   l1 = "txTel"
   for i, label in ipairs(txSensorNames) do
      table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, i)
      table.insert(tt.sensorUnlist, txSensorUnits[i])
      table.insert(tt.sensorDplist, txSensorDP[i])
   end
   txTeleSensors = #tt.sensorLalist

   l1 = "txRSSI"
   for i, label in ipairs(txRSSINames) do
   table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, -i)
      table.insert(tt.sensorUnlist, " ")
      table.insert(tt.sensorDplist, 0)
   end
   --]]
end

local function sendCtrl(cc, nn)

   local bw = serial.write(sidSerial, string.rep(cc, nn))
   if not bw then
      print("Glass: Serial write error")
      sendState = state.IDLE
      return false
   end
   return bw
end

local function loop()
   local now = system.getTimeCounter()
   local unow = system.getTime()
   local sensor, sval
   local stbl = {}
   local gtbl = {}
   local av
   local scale
   local minV, maxV, lbl
   local LOOPTIME = 400
   if pageSw then
      local sw = system.getInputsVal(pageSw)
      local pp = sw + 2 -- -1, 0, 1 --> 1,2,3
      pp = math.min(pp, pageMax)
      pageNumberTele = pp
   end

   local swh
   local oldmode 
   if emflag then
      swh = system.getInputs("SH")
      if swh and swh == 1 then
	 oldmode = true
      else
	 oldmode = false
      end
   end

   if sendState == state.IDLE and unow > jsonHoldTime then
      if pageMax > 0 and (now > lastWrite + LOOPTIME) then

	 local p1 = math.floor(255 * (1 + system.getInputs("P1")) / 2)
	 local p2 = math.floor(255 * (1 + system.getInputs("P2")) / 2)

	 if (not pageSw) then pageNumberTele = pageNumber end

	 if not pageNumberTele or pageNumberTele < 1 then return end

	 if oldmode then
	    stbl = {page=pageNumberTele}
	 else
	    stbl = {page=string.format("p%d", pageNumberTele)}
	 end

	 for k,v in pairs(Glass.page[pageNumberTele]) do

	    if v.imageID >= 0 then
	       av = id2avail[v.imageID]
	    else
	       av = nil
	    end
	    if av then
	       scale = availImgs[av].scale
	       if scale == "variable" then
		  minV = v.minV or availImgs[av].minV -- if min/max not set pick up defaults
		  maxV = v.maxV or availImgs[av].maxV
	       else
		  minV = availImgs[av].minV
		  maxV = availImgs[av].maxV
	       end
	    end
	    
	    v.value=nil
	    --if k == 1 then print("L", k, v.sensorId, v.sensorLa) end
	    if (v.sensorId ~= 0) and (v.sensorLa ~= 0) then
	       sensor = system.getSensorByID(v.sensorId, v.sensorPa)
	       if sensor and sensor.valid then
		  v.value = sensor.value
	       end
	    end

	    local fms
	    if v.decimals == 0 then
	       fms = "%.0f"
	    elseif v.decimals == 1 then
	       fms = "%.2f"
	    else
	       fms = "%.3f"
	    end

	    if v.value then 
	       sval = string.format(fms, v.value)
	    else
	       sval = nil
	    end
	    
	    if v.imageID >= 0 then
	       stbl["g"..k] = {}

	       if oldmode then
		  stbl["g"..k].id = v.imageID
	       else
		  stbl["g"..k].id = string.format("id%d", v.imageID)
	       end
	       
	       if sval then
		  stbl["g"..k].value = tonumber(sval)
	       end
	       if scale == "variable" and sval then
		  stbl["g"..k].minV = minV
		  stbl["g"..k].maxV = maxV
		  stbl["g"..k].label=Glass.page[pageNumberTele][k].instName
	       end
	    end

	 end
	 if next(stbl) then
	    local espjson = json.encode(stbl)

	    if emflag then
	       local swa = system.getInputs("SA")
	       if swa and swa == 1 then
		  print(espjson)
	       end
	    end
	    
	    local count = serial.write(sidSerial, espjson)
	 end
	 lastWrite = now
      end

   elseif sendState == state.SENDHEADER or sendState == state.SENDFOOTER then

      --[[
	 config.txt formatting overview

	 "FFD0001561766961746F72000000000000000001AA" config header for "aviator" with zero version, key 1
	 "FF51...AA" fonts (many lines)
	 "FF41...AA" images (many lines)
	 "FFD0001561766961746F72000000000200000001AA" config footer for "aviator" with version 2, key 1
	 "FFD2000D61766961746F7200AA" config set to "aviator"

      --]]
      
      local cfgVersion = configVersion or 1
      local cfgKey = 1
      local bufPre = "FFD0001561766961746F7200"
      local bufSet = "FFD2000D61766961746F7200AA"
      local bufH = bufPre .. string.format("%08X%08X", 0, cfgKey) .. "AA\n"
      local bufF = bufPre .. string.format("%08X%08X", cfgVersion, cfgKey) .. "AA\n"..bufSet.."\n"
      local bw
      if sendState == state.SENDHEADER then
	 print("Glass: Sending config header")
	 bw = serial.write(sidSerial, bufH)
	 io.write(sendFPser, bufH)
	 if not bw then
	    print("Glass: serial write error header")
	 else
	    sendState = state.SENDFONTS
	    sendFP = io.open(prefix() .. pathConfigs .. "config-fonts.txt", "r")
	    if not sendFP then
	       print("Glass: cannot open font config")
	       sendState = state.IDLE
	    end
	 end
	 print("Glass: Sending font configs")
      elseif sendState == state.SENDFOOTER then
	 --print("send footer ", bufF)
	 bw = serial.write(sidSerial, bufF)
	 io.write(sendFPser, bufF)
	 if not bw then print("Glass: serial write error on footer") end
      end
      if not bw or (sendState == state.SENDFOOTER) then
	 print("Glass: Sending config footer")
	 if sendFPser then io.close(sendFPser) end
	 sendCtrl("\000", 1) -- back to normal mode
	 print("Send config done. Time (ms): ", system.getTimeCounter() - sendTime)
	 if tempCall then io.close(sendFPtemp) end
	 jsonHoldTime = system.getTime() + 1
	 sendState = state.IDLE
      end
   elseif (sendState == state.SENDFONTS) or (sendState == state.SENDIMGS) or
      (sendState == state.SENDACTIVE) or (sendState == state.SENDFMTS) then
      local buf, start, before, after
      if system.getTimeCounter() - sendLast > 10 then -- 10ms is essentially no delay .. can throttle...
	 for k=1,20,1 do
	    buf = io.read(sendFP, 128)
	    start = string.find(buf, "\n")
	    if not start then
	       configLine = configLine .. buf
	    else
	       before = string.sub(buf, 1, start-1)
	       after = string.sub(buf, start+1)
	       configLine = configLine .. before
	       if string.find(configLine, "AA") then
		  sendAA = sendAA + 1
	       end
	       if string.find(configLine, "FF") then
		  sendFF = sendFF + 1
	       end
	       configLine = after
	    end
	    local bw
	    if sidSerial and buf and buf ~= "" then
	       sendLast = system.getTimeCounter()
	       bw = serial.write(sidSerial, buf)
	       if (sendState == state.SENDFONTS) or (sendState == state.SENDIMGS) then
		  io.write(sendFPser, buf)
		  if not bw then
		     print("Glass: Serial write error")
		     buf = ""
		  end
	       end
	    end
	    if buf == "" then
	       if sendState == state.SENDFMTS then
		  io.close(sendFP)
		  if not sendCtrl("\000", 1) then -- signify end
		     sendState = state.IDLE
		     return
		  end
		  --send 0x02 three times to indicate file #2
		  if not sendCtrl("\002", 3) then
		     sendState = state.IDLE
		     return
		  end
		  sendState = state.SENDHEADER
		  break
		  --[[
	       elseif sendState == state.SENDACTIVE then
		  io.close(sendFP)
		  --send 0x03 three times to indicate sending config txt info
		  if not sendCtrl("\003",3) then
		     sendState = state.IDLE
		     return
		  end
		  sendState = state.SENDHEADER
		  break
		  --]]
	       elseif sendState == state.SENDFONTS then
		  io.close(sendFP)
		  sendImgsIdx = 1
		  print("Glass: Sending image file " ..sendImgs[sendImgsIdx])
		  sendFP = io.open(sendImgs[sendImgsIdx], "r")
		  if not sendFP then
		     print("Glass:cannot open image file "..sendImgsIdx)
		     sendState = state.IDLE
		     break
		  else
		     sendState = state.SENDIMGS
		  end
	       elseif sendState == state.SENDIMGS then
		  io.close(sendFP)
		  if sendImgsIdx < #sendImgs then
		     sendImgsIdx = sendImgsIdx + 1
		     print("Glass: Sending image file " ..sendImgs[sendImgsIdx])
		     sendFP = io.open(sendImgs[sendImgsIdx], "r")
		     if not sendFP then
			print("Glass cannot open image file "..sendImgsIdx)
			sendState = state.IDLE
			break
		     end
		  else
		     sendState = state.SENDFOOTER
		     break
		  end
	       end
	    end
	 end
      end
   end
   cpu = system.getCPU()
end

local function changedSensor(value)
   Glass.page[pageNumber][gaugeNumber].sensorId = Glass.sensorIdlist[value]
   Glass.page[pageNumber][gaugeNumber].sensorPa = Glass.sensorPalist[value]
   Glass.page[pageNumber][gaugeNumber].sensorLa = Glass.sensorLalist[value]
   Glass.page[pageNumber][gaugeNumber].sensorLs = Glass.sensorLslist[value]
   Glass.page[pageNumber][gaugeNumber].units    = Glass.sensorUnlist[value]   
   Glass.page[pageNumber][gaugeNumber].decimals = Glass.sensorDplist[value]
   Glass.page[pageNumber][gaugeNumber].type     = Glass.sensorTylist[value]   
end

local function changedName(value)
   print("changedName instName", value, "page, gauge", pageNumber, gaugeNumber)
   Glass.page[pageNumber][gaugeNumber].instName = value
end

local function clearJSON()
   local fn = prefix() .. pathJson .. "GG_" .. modelName.. ".jsn"
   local ans
   ans = form.question("Are you sure?", "Reset all app settings?",
		       "",
		       0, false, 5)
   if ans == 1 then
      --print("removing " .. fn)
      io.remove(fn)
      system.messageBox("All settings deleted .. Restart App")
      writeJSON = false
   end
   
end

local function tempWrite(a,b)
   io.write(sendFPtemp, b)
   return tempCall(a,b)
end

local function sendUSB()

   -- go thru all pages, and gauges to find imageIDs that are referenced
   -- and put them in a table to set up the data transmission


   --[[ test code to capture serialout stream by hihacking the system call
   if not tempCall then
      tempCall = serial.write
      serial.write = tempWrite
   end
   
   sendFPtemp = io.open(prefix() .. pathConfigs .. "config-xxxx.txt", "w")
   print("sendFPtemp", sendFPtemp)
   --]]

   -- create the list of config-imgs fragments that must be uploaded
   
   sendImgs = {}
   local av
   for k,p in ipairs(Glass.page) do
      for j, g in ipairs(p) do
	 if g.imageID >=0 then
	    av = id2avail[g.imageID]
	 else
	    av = nil
	 end
	 if av then
	    local fn = prefix() .. pathConfigs .. "config-imgs-" .. availImgs[av].BMPname .. ".txt"
	    local included = false
	    for kk,vv in pairs(sendImgs) do
	       if fn == vv then included = true end
	    end
	    if not included then table.insert(sendImgs, fn) end
	 end
      end
   end
   
   if #sendImgs < 1 then
      print("Glass: no image files referenced - nothing sent")
      return
   end

   -- transmission protocol:
   -- ascii 0x01 three times: here comes file 1
   -- ascii 0x02 three times: close file 1, here comes file 2
   -- ascii 0x03 three times: close file 2, here comes file 3
   -- ascii 0x00 three times: close file 3, back to normal
   --
   -- file 1 is configformats.jsn
   -- file 2 is the streaming config.txt info
   
   --First, send 0x01 3 times to indicate file #1
   
   if not sendCtrl("\001", 3) then
      sendState = state.IDLE
      return
   end
   
   sendFP = io.open(prefix() .. pathJson .. "configimages.jsn", "r")
   if not configVersion then configVersion = 0 end
   sendFPser = io.open(prefix() .. pathConfigs .. string.format("config%d.txt", configVersion), "w")
   
   if sendFP and sidSerial then
      sendAA = 0
      sendFF = 0
      sendTime = system.getTimeCounter()
      configLine = ""
      sendState = state.SENDFMTS
      print("Glass: Sending image json description")
   else
      print("Glass: could not open file or serial port not open")
      sendState = state.IDLE
   end
   
end

local function initForm(sf)

   subForm = sf
   if sf == 1 then
      form.setButton(1, ":add",   ENABLED)
      form.setButton(2, ":up",    ENABLED)
      form.setButton(3, "Edit",   ENABLED)
      form.setButton(4, ":tools", ENABLED)
      
      if not Glass.page or #Glass.page == 0 then
	 form.addRow(1)
	 form.addLabel({label="No pages defined", width = 220})
      else
	 for i in ipairs(Glass.page) do
	    form.addRow(1)
	    form.addLabel({label="Page " .. i, width = 220})
	 end
      end

      form.setFocusedRow(savedRow)
      form.setTitle("Display Pages")
   elseif sf == 10 then
      form.setButton(1, ":forward", ENABLED)
      form.setButton(2, ":up", ENABLED)

      if gaugeNumber == 0 then gaugeNumber = 1 end
      if pageNumber == 0 then pageNumber = 1 end
      if not Glass.page[pageNumber][gaugeNumber].instName then
	 Glass.page[pageNumber][gaugeNumber].instName = 'Gauge'..gaugeNumber
      end

      if Glass.page[pageNumber][1].fmtNumber < 1 then
	 Glass.page[pageNumber][1].fmtNumber = 1
	 --fmtNumber = 1
      end

      --sift thru avail images and find the ones that are the correct size
      --for this gauge in the selected format

      imageNum = nil
      local imageID = Glass.page[pageNumber][gaugeNumber].imageID
      local fn = Glass.page[pageNumber][1].fmtNumber
      local wid = availFmt[fn][gaugeNumber].width
      local hgt = availFmt[fn][gaugeNumber].height
      local label
      
      editImgs = {}
      for i, img in ipairs(availImgs) do
	 --print(i, wid, img.origWidth, hgt, img.origHeight)
	 if (wid == img.origWidth) and (hgt == img.origHeight) then
	    --print("inserting", i)
	    table.insert(editImgs,
			 {id=img.id, loadImage=img.loadImage,
			  imageWidth=img.imageWidth, imageHeight = img.imageHeight,
			  wtype=img.wtype})
	    if img.id == imageID then
	       imageNum = #editImgs
	    end
	 end
      end
      imageMax = #editImgs
      if not imageNum then imageNum = 1 end
      if imageID < 0 then
	 if #editImgs < 1 then
	    print("Glass: no images for", pageNumber, gaugeNumber)
	 else -- default to first image
	    Glass.page[pageNumber][gaugeNumber].imageID = editImgs[1].id
	    Glass.page[pageNumber][gaugeNumber].wtype = editImgs[1].wtype
	 end
      end
      
      form.addRow(1)
      form.addLink((function(x) form.reinit(12) end), {label="Data source >"})

      form.addRow(1)
      form.addLink((function(x) form.reinit(13) end), {label="Min/Max >"})

      form.setTitle("Page " .. pageNumber .. " Gauge " .. gaugeNumber)
      
      form.setFocusedRow(1)
   elseif sf == 11 then

      local function pageSwChanged(val)
	 pageSw = val
	 local swInfo =system.getSwitchInfo(val)
	 if not swInfo.proportional then
	    system.messageBox("Please select as Proportional")
	    return
	 end
	 if not swInfo.assigned then
	    print("Sw unassigned")
	    pageSw = nil
	    pageNumberTele = nil
	 end
	 system.pSave("pageSw", pageSw)
      end

      local function cvchanged(val)
	 configVersion = val
	 system.pSave("configVersion", val)
      end
      
      form.addRow(2)
      form.addLabel({label="Page change switch"})
      form.addInputbox(pageSw, true, pageSwChanged)
      
      form.addRow(2)
      form.addLabel({label="Set config version"})
      form.addIntbox(configVersion, 1, 32767, 1, 0, 1, cvchanged)
      
      form.addRow(1)
      form.addLink(sendUSB, {label="Send config on serial>>"})
      form.addRow(1)
      form.addLink(clearJSON, {label="Reset app settings>>"})

      
   elseif sf == 12 then

      local isel = 0
      for k = 1, #Glass.sensorLalist do
	 if (Glass.sensorIdlist[k] == Glass.page[pageNumber][gaugeNumber].sensorId) and
	    (Glass.sensorPalist[k] == Glass.page[pageNumber][gaugeNumber].sensorPa) then
	    isel = k
	    break
	 end
      end

      form.addRow(2)
      form.addLabel({label="Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.sensorLalist, isel, true, changedSensor,
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="Gauge Name:", font=FONT_NORMAL})
      form.addTextbox(Glass.page[pageNumber][gaugeNumber].instName, 10, changedName,
			{width=155, font=FONT_NORMAL})
   elseif sf == 13 then

      local id, fn, minV, maxV, av

      fn = Glass.page[pageNumber][1].fmtNumber
      id = Glass.page[pageNumber][gaugeNumber].imageID
      if id < 0 then
	 print("Glass: no images")
	 return
      end

      av = id2avail[id]

      local scale = availImgs[av].scale
      
      if scale == "fixed" or not Glass.page[pageNumber][gaugeNumber].minV then
	 minV = availImgs[av].minV
      else
	 minV = Glass.page[pageNumber][gaugeNumber].minV
      end

      if scale == "fixed" or not Glass.page[pageNumber][gaugeNumber].maxV then
	 maxV = availImgs[av].maxV
      else
	 maxV = Glass.page[pageNumber][gaugeNumber].maxV
      end      
      
      if availImgs[av].scale == "variable" then
	 local function minChanged(value)
	    Glass.page[pageNumber][gaugeNumber].minV = value / 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Min value"})
	 form.addIntbox(minV*10, -32768, 32767, 0, 1, 1, minChanged)

	 local function maxChanged(value)
	    Glass.page[pageNumber][gaugeNumber].maxV = value / 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Max value"})
	 form.addIntbox(maxV*10, -32768, 32767, 100, 1, 1, maxChanged)
      else
	 if not minV or not maxV then
	    form.addRow(1)
	    form.addLabel({label="Min/Max not applicable"})
	 else
	    form.addRow(2)
	    form.addLabel({label="Min value (fixed)"})
	    form.addLabel({label=string.format("%.1f", minV)})
	    form.addRow(2)
	    form.addLabel({label="Max value (fixed)"})
	    form.addLabel({label=string.format("%.1f", maxV)})	 	 
	 end
      end
   end
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end

local function clearPage(pn, gm)
   --print("clearPage", pn, gm)
   Glass.page[pn] = {}
   for k=1,gm do
      Glass.page[pn][k] = {}
      Glass.page[pn][k].sensorId = 0
      Glass.page[pn][k].sensorPa = 0	 
      Glass.page[pn][k].sensorLs = "..."
      Glass.page[pn][k].sensorLa = "..."	    
      Glass.page[pn][k].units = "-"
      Glass.page[pn][k].decimals = 0
      Glass.page[pn][k].imageID = -1
      Glass.page[pn][k].value = 0.0
      Glass.page[pn][k].instName = "Gauge"..k
   end
   Glass.page[pn][1].fmtNumber = 1
end

local function keyPressed(key)

   local fmtNumber
   
   if pageNumber < 1 then
      fmtNumber = 1
   else
      fmtNumber = Glass.page[pageNumber][1].fmtNumber
   end
   
   if subForm == 1 then

      if keyExit(key) then
	 if key ~= KEY_ESC then
	    form.preventDefault()
	    savedRow = form.getFocusedRow()
	    form.reinit(1)
	 end
      end
   
      if key == KEY_1 then
	 if pageMax < pageLimit then
	    pageMax = pageMax + 1
	    clearPage(pageMax, gaugeMax)
	 end
	 form.reinit(1)
      elseif key == KEY_2 then
	 if pageNumber < 1 then
	    system.messageBox("No pages defined")
	    return
	 end
	 clearPage(pageNumber, gaugeMax)
	 fmtNumber = fmtNumber + 1
	 if fmtNumber > #availFmt then fmtNumber = 1 end
	 Glass.page[pageNumber or 1][1].fmtNumber = fmtNumber
	 return
      elseif key == KEY_3 or key == KEY_ENTER then
	 savedRow = form.getFocusedRow()
	 if savedRow > 0 then
	    pageNumber = savedRow
	    gaugeNumber = 1
	    form.reinit(10)
	 else
	    system.messageBox("No pages defined to edit")
	    form.reinit(1)
	 end
      elseif key == KEY_4 then
	 form.reinit(11)
      end
   elseif subForm == 10 then
      if keyExit(key) then
	 form.preventDefault()
	 imageNum = nil
	 form.reinit(1)
      end
      if key == KEY_1 then
	 local fm = Glass.page[pageNumber][1].fmtNumber
	 local mx = #availFmt[fm]
	 if gaugeNumber + 1 > mx then	 
	    gaugeNumber = 1
	 else
	    gaugeNumber = gaugeNumber + 1
	 end
	 imageNum = nil
	 form.reinit(10)
	 return
      elseif key == KEY_2 then
	 imageNum = imageNum + 1
	 if imageNum > imageMax then imageNum = 1 end
      end
      if key == KEY_2 then
	 local iid = 0
	 local min, max, wtype
	 for i,img in ipairs(availImgs) do
	    if img.id == editImgs[imageNum].id then
	       iid = img.id
	       min = img.minV
	       max = img.maxV
	       wtype = img.wtype
	    end
	 end
	 Glass.page[pageNumber][gaugeNumber].imageID = iid
	 Glass.page[pageNumber][gaugeNumber].minV = min -- may be nil
	 Glass.page[pageNumber][gaugeNumber].maxV = max -- may be nil
	 Glass.page[pageNumber][gaugeNumber].wtype = wtype
      end
   elseif subForm == 11 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   elseif subForm == 12 or subForm == 13 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(10)
      end
   end
end

local function drawRectangleGlass(x0, y0, xl, yl)
   local f = 0.55
   lcd.drawRectangle(f*x0 - f*xl / 2, f*y0 - f*yl / 2, f*xl, f*yl)
end

local function drawText(x0, y0, val, lbl, twid, thgt)
   local text = string.format(lbl .. ' ' .. "%.2f", val)
   local ww = lcd.getTextWidth(FONT_BIG, text)
   local hh = lcd.getTextHeight(FONT_BIG, text)
   lcd.drawText(x0 + (twid - ww)/2, y0 + (thgt - hh)/2, text, FONT_BIG)
end

local function printForm(w,h)

   local fmtNumber
   local offset = w - 144

   if subForm == 10 then
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(offset-5, 0, h+1+5, h+1)
      --print("pF", imageNum)
      if imageNum and imageNum > 0 and editImgs[imageNum] then --and editImgs[imageNum].loadImage then
	 local xi, yi
	 if editImgs[imageNum].imageWidth > 144 then
	    xi, yi = w/2 - editImgs[imageNum].imageWidth/2, 80
	 else
	    xi, yi = offset, 0
	 end
	 if editImgs[imageNum].loadImage then
	    lcd.drawImage(xi,yi,editImgs[imageNum].loadImage)
	 else
	    lcd.setColor(0,0,0)
	    lcd.drawRectangle(xi, yi, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	    local iN = Glass.page[pageNumber][gaugeNumber].instName
	    local vv = Glass.page[pageNumber][gaugeNumber].value or 0.0
	    drawText(xi, yi, vv, iN, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	 end
      else
	 lcd.setColor(0,0,0)
	 lcd.drawText(200,80, "imageNum " .. (imageNum or "nil") .." " .. #editImgs)
      end
   elseif subForm == 1 then
      local fr = form.getFocusedRow()
      if fr <= pageMax and fr > 0 then pageNumber =  fr end
      
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(310-167, 0, 167, 141)

      lcd.setColor(0,0,0)
      lcd.setClipping(310-167, 0, 167, 141)

      lcd.drawRectangle(0, 0, 167, 141)
      lcd.setColor(200,200,200)
      lcd.drawRectangle(33/2, 28/2, 134, 113)
      lcd.setColor(0,0,0)

      if pageNumber < 1 then return end
      
      fmtNumber = Glass.page[pageNumber][1].fmtNumber
      if fmtNumber > 0 then
	 --local gp = availFmt[fmtNumber]
	 local gp = availFmts[fmtNumber]
	 for g,t in ipairs(gp) do
	    drawRectangleGlass(t.xc, t.yc, t.width, t.height)
	 end
      end
      
      lcd.resetClipping()
   end
end

local function drawNeedle(x0, y0, degMin, degMax, min, max, val, len)
   
   local ren = lcd.renderer()
   local sinpt, cospt
   local pct = (val - min) / (max - min)
   local deg = 180 + (degMin + pct * (degMax - degMin))

   sinpt = math.sin(math.rad(deg))
   cospt = math.cos(math.rad(deg))
   ren:reset()
   ren:addPoint(x0, y0)
   local x1 = 0
   local y1 = len
   ren:addPoint(x0 + x1 * cospt - y1 * sinpt, y0 + x1 * sinpt + y1 * cospt)
   ren:renderPolyline(1)

end

local function drawHbar(x0, y0, min, max, val, barW, barH)
   local bw = math.floor(barW * (val - min) / (max - min) + 0.5)
   bw = math.min(math.max(0, bw), barW+1)
   lcd.drawFilledRectangle(x0, y0, bw, barH)
end

local function printTele(w,h)

--[[

   Sample json file structure (snipped from configconfig.jsn) 
   It contains just one object each for "configs" and "images" as an example of the data shape
   All position coordinates are in the ActivImage space .. origin at lower right
   The main table is cfgimg .. then cfgimg.config and cfgimg.images

{
    {"config": {"p1": {"g1": {"xlr": 72, "ylr": 48}}}},
    {"images": {"id10": {"x0": 80, "scale": "variable", "wtype": "gauge", "ylmin": 15,
                            "ylmax": 15, "maxV": 100, "id": 10, "minV": 0, "inputs": 1,
		            "xlmax": 20, "minA": -150, "nlen": 70, "y0": 80, "maxA": 150,
	 	            "xlbl": 80, "ylbl": 50, "xlmin": 140}}}
}

--]]
   
   local r = 160 / 256 -- show the glasses space (304x256) in Jeti screen (320x160) .. scale by 160/256
   local offset = (319 - r * 304) / 2 -- center the shrunk glasses space on the Jeti screen
   local fmt
   local gpp

   -- Select the appropriate page (controlled by assigned switch or line in menu)
   -- Individual dynamic widget info stored in Glass.page[pageNumber][gaugeNumber].property
   -- The Glass.page values are the ones that form the 200msec json
   
   if not pageSw then pageNumberTele = pageNumber end
   if not pageNumberTele then return end
   gpp = Glass.page[pageNumberTele]
   fmt = string.format("p%d", gpp[1].fmtNumber)

   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159) -- black background over entire window
   lcd.setColor(255,255,255)            -- rest of animation (needles, etc) is white
   lcd.drawRectangle(1+offset, 1, (304-2)*r, (256-4)*r) -- draw scaled glasses hw screen as box
   lcd.drawText(10, 10, string.format("Page %d", pageNumberTele))
   
   local xr, yr, xc, yc
   local min, max, val, id, lbl
   local ccfg, cid

   local ccf =  cfgimg.config[fmt]

   -- From here, everything referenced with "t." would come from the 200msec json if we
   -- were in the ESP. Make sure we only reference things that are sent that way so we're not
   -- cheating. Everything from "cid." is from the images section cfgimg.images
   
   for g,t in ipairs(gpp) do        -- loop over all gauges on this page with a valid imageID
      ccfg = ccf["g"..g]            -- this is the "config" key for this page and this widget
      id = string.format("id%d", t.imageID)
      cid = cfgimg.images[id]       -- this is the "images" key for this page and this widget
      if t.imageID > 0 then         -- if there is a value to animate
	 xr = ccfg.xul
	 yr = ccfg.yul
	 xc = xr + cid.x0           -- for gauge, this is the pivot point of the needle
	 yc = yr + cid.y0
	 if t.value then
	    -- if scale "fixed" then scale comes from images, else from 200ms json
	    if cid.scale and cid.scale == "fixed" then
	       min = cid.minV
	       max = cid.maxV
	    else  -- be defensive in case of missing minV/maxV
	       min = t.minV or 0
	       max = t.maxV or 1
	    end
	    lbl = t.instName or "..." --.instName is named .label in the 200ms json 
	    val = t.value
	    --print(g, id, min, max, val, lbl)
	    if cid.wtype == "gauge" then
	       lcd.drawImage(offset + xr * r, yr * r, cid.loadImageSmaller)
	       drawNeedle(offset + r * xc, r * yc, cid.minA, cid.maxA, min, max, val, r * cid.nlen)
	    elseif cid.wtype == "hbar" then
	       lcd.drawImage(offset + xr * r, yr * r, cid.loadImageSmaller)
	       drawHbar(offset + r * xc, r * yc, min, max, val, r * cid.barW, r * cid.barH)
	    elseif cid.wtype == "htext" then
	       drawText(offset + r * xc, r * yc, val, lbl, r * cid.txtW, r * cid.txtH)
	    end 
	    if (cid.wtype == "gauge" or cid.wtype == "hbar") and cid.scale == "variable" then
	       drawTextCenter(offset + xr * r + r * cid.xlmin, yr * r + r * cid.ylmin,
			      string.format(dpFmt(min), min), FONT_MINI)
	       drawTextCenter(offset + xr * r + r * cid.xlmax, yr * r + r * cid.ylmax,
			      string.format(dpFmt(max), max), FONT_MINI)
	       drawTextCenter(offset + xr * r + r * cid.xlbl, yr * r + r * cid.ylbl,
			      lbl, FONT_MINI)			      
	    end
	 end
      end
   end
end

			
local function printTeleOld(w,h)

   local id
   local av
   local xr, yr
   local xc, yc
   local gpp
   local r = 160/256 -- show the glasses space (304x256) in Jeti screen (320x160) .. scale by 160/256
   local offset = (319-r * 304) / 2 -- center the shrunk glasses space on the Jeti screen
   local max, min, val
   local fmtNumber
   
   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159) -- black background

   if (not pageSw) then pageNumberTele = pageNumber end

   fmtNumber = Glass.page[pageNumberTele][1].fmtNumber -- this is the chosen screen format
   if fmtNumber > 0 then
      local gp = availFmts[fmtNumber]
      for g,t in ipairs(gp) do -- loop over gauge positions in this screen format
	 xr = t.xc - t.width/2
	 yr = t.yc - t.height/2
	 print(g, xr, yr)
	 gpp = Glass.page[pageNumberTele]
	 id = gpp[g].imageID
	 if id >0 then
	    av = id2avail[id]
	 else
	    av = nil
	 end
	 lcd.setColor(255,255,255)
	 lcd.drawRectangle(1+offset, 1, (304-2)*r, (256-4)*r) -- draw scaled glasses hw screen as box
	 lcd.drawText(10, 10, "Page "..pageNumberTele)
	 if av then
	    local aI = availImgs[av]
	    xc = xr + aI.x0
	    yc = yr + aI.y0
	    if gpp[g].value then
	       if not gpp[g].minV then min = aI.minV else min = gpp[g].minV end
	       if not gpp[g].maxV then max = aI.maxV else max = gpp[g].maxV end
	       val = gpp[g].value
	       if gpp[g].wtype == "gauge" then
		  lcd.drawImage(offset+xr*r, yr*r, aI.loadImageSmaller)
		  drawNeedle(offset+r*xc, r*yc, aI.minA, aI.maxA, min, max, val, r*aI.nlen)
	       elseif gpp[g].wtype == "hbar" then
		  lcd.drawImage(offset+xr*r, yr*r, aI.loadImageSmaller)
		  drawHbar(offset + r * xc, r * yc, min, max, val, r * aI.barW, r * aI.barH)
	       elseif gpp[g].wtype == "htext" then
		  local ins = Glass.page[pageNumberTele][g].instName
		  drawText(offset + r * xc, r * yc, val, ins, r * aI.txtW, r * aI.txtH)
	       end 
	       if gpp[g].wtype == "gauge" and aI.scale == "variable" then
		  drawTextCenter(offset + xr*r + r*aI.xlmin, yr * r + r*aI.ylmin,
			       string.format(dpFmt(min), min), FONT_MINI)
		  drawTextCenter(offset + xr*r + r*aI.xlmax, yr * r + r*aI.ylmax,
				 string.format(dpFmt(max), max), FONT_MINI)
		  drawTextCenter(offset + xr*r + r*aI.xlbl, yr * r + r*aI.ylbl,
			       Glass.page[pageNumberTele][g].instName, FONT_MINI)
	       end
	       if gpp[g].wtype == "hbar" then -- this is cheating .. the ESP won't have this info!
		  drawTextCenter(offset + xr*r + r*aI.xlbl, yr * r + r*aI.ylbl,
				 Glass.page[pageNumberTele][g].instName, FONT_MINI)
	       end
	    end
	 end
      end
   end
end

local function destroy()

   local fp
   local fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"

   if not writeJSON then
      return
   end

   --replace Id and Pa with hex values .. limited precision of JSON conversion
   --turning these (especially Id) into floats mangles them
   for k, v in pairs(Glass.page) do
      for kk,vv in pairs(v) do
	 for kkk, vvv in pairs(vv) do
	    if  kkk == "sensorId" or kkk == "sensorPa" then
	       vv[kkk] = string.format("0X%X", math.floor(vvv)) 
	    end
	 end
      end
   end

   fp = io.open(fn, "w")
   if fp then
      io.write(fp, json.encode(Glass.page), "\n")
      io.close(fp)
      print("Glass - State saved " .. fn)
   else
      print("Glass - Could not save state")
   end
   
end

local function onRead(data)
   if data == "W" then print("ENGO gesture") else print("serial input:", data) end
end

local function prepCI(availVals)
   
   -- prepare json to send to the ESP
   -- top key "config" is the widget positions
   -- top key "images" is the widget internal details

   local gw = 304
   local gh = 256
   
   local cfgimgESP = {}
   cfgimgESP.config = {}
   cfgimg.config = {}
   for k,gp in ipairs(availFmt) do
      cfgimgESP.config["p"..k] = {}
      cfgimg.config["p"..k] = {}
      availFmts[k] = {}
      for g,t in ipairs(gp) do
	 cfgimgESP.config["p"..k]["g"..g] = {}
	 cfgimgESP.config["p"..k]["g"..g].xlr = math.floor(gw - (availVals[t.xc] + t.width/2))
	 cfgimgESP.config["p"..k]["g"..g].ylr = math.floor(gh - (availVals[t.yc] + t.height/2))
	 --cfgimgESP.config["p"..k]["g"..g].wtype = t.wtype

	 cfgimg.config["p"..k]["g"..g] = {}
	 cfgimg.config["p"..k]["g"..g].xul = math.floor(availVals[t.xc] - t.width/2)
	 cfgimg.config["p"..k]["g"..g].yul = math.floor(availVals[t.yc] - t.height/2)
	 --cfgimg.config["p"..k]["g"..g].wtype = t.wtype
	 
	 availFmts[k][g] =  {}
	 availFmts[k][g].xc = availVals[t.xc]
	 availFmts[k][g].yc = availVals[t.yc]
	 availFmts[k][g].width = t.width -- availVals[t.width]
	 availFmts[k][g].height = t.height --availVals[t.height]
      end
   end

   cfgimgESP.images = {}
   cfgimg.images = {}
   local skip = {height=true, width=true, loadImage=true, loadImageSmaller = true,
		 imageHeight=true, imageWidth=true, name=true, origHeight=true,
		 origWidth=true, label=true, BMPname=true}
   local transX = {x0=true, xlmin=true, xlmax=true, xlbl=true}
   local transY = {y0=true, ylmin=true, ylmax=true, ylbl=true}   
   for i,img in ipairs(availImgs) do
      local id = math.floor(img.id)
      cfgimgESP.images["id"..id] = {}
      cfgimg.images["id"..id] = {}
      for k,v in pairs(img) do
	 if not skip[k] then
	    if transX[k] then -- move from upper left origin to lower right origin
	       cfgimgESP.images["id"..id][k] = img.width - v
	    elseif transY[k] then
	       cfgimgESP.images["id"..id][k] = img.height - v
	    else
	       cfgimgESP.images["id"..id][k] = v
	    end
	 end
      end
      for k,v in pairs(img) do
	 if true then --not skip[k] then
	    cfgimg.images["id"..id][k] = v
	 end
      end
   end
   
   local encodedaF = json.encode(cfgimgESP)

   local fp = io.open(prefix() .. pathJson .. "configimages.jsn", "w")
   if not fp then
      print("Glass: cannot open configimages.jsn for writing")
      return
   else
      if not io.write(fp, encodedaF) then
	 print("Glass: write error configimages.jsn")
	 return
      end
      io.close(fp)
      encodedaF = nil
   end

   --local encT = json.encode(cfgimg)
   --fp = io.open(prefix() .. pathJson .. "cfgimgTest.jsn", "w")
   --io.write(fp, encT)
   --io.close(fp)
end

local function init()

   local fn
   local fmtNumber
   
   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(Glass)
   
   system.registerForm(1, MENU_APPS, "Glass", initForm, keyPressed, printForm)

   fn = prefix() .. pathJson .. "availImgs.jsn"
      
   local file = io.readall(fn)
   availImgs = {}
   if file then
      availImgs = json.decode(file)
      print("Glass - Reading avail images from ", fn)
   else
      system.messageBox("Glass: Cannot read " .. fn)
      return
   end

   local ratio = 144 / 160 -- ratio of "small" images to jeti screen height
   id2avail = {}
   local im, ims
   for i,img in ipairs(availImgs) do
      --print("BMPname: $$"..img.BMPname.."$$")
      if img.BMPname ~= "" then
	 im = prefix() .. pathImages .. img.BMPname .. "-small.png"
	 ims = prefix() .. pathImages .. img.BMPname .. "-smaller.png"      
	 img.loadImage = lcd.loadImage(im)
	 img.loadImageSmaller = lcd.loadImage(ims)
	 img.imageWidth = img.loadImage.width
	 img.imageHeight = img.loadImage.height
	 img.origWidth = img.width
	 img.origHeight = img.height
      else
	 img.origWidth = img.width
	 img.origHeight = img.height
	 img.imageWidth = img.width * ratio
	 img.imageHeight = img.height * ratio
      end
      id2avail[img.id] = i
   end

   local device
   device, emflag = system.getDeviceType() 
   
   local success, descr
   local portlist = serial.getPorts()
   for k,v in pairs(portlist) do
      print("Glass - Available COM port "..k..": ".. v)
   end

   local baud = 115200
   
   if emflag ~= 0 then
      sidSerial, descr = serial.init("ttyUSB0", baud)
      os.setlocale("C")
   else
      sidSerial, descr = serial.init("COM1", baud)
   end
   
   if sidSerial then   
      print("Glass - Serial port init succeeded: ", sidSerial)
      serial.setBaudrate(sidSerial, baud)
      -- SPECIAL
      -- SPECIAL .. for Dave's BLE device turn on gpio 8
      -- gpio.mode(8, "out-pp")
      -- gpio.write(8,1)
      -- SPECIAL
      -- SPECIAL
      success, descr = serial.onRead(sidSerial,onRead)   
      if success then
	 --print("Glass: Callback registered")
      else
	 print("Glass: Error setting callback", descr)
      end
            
   else
      print("Glass - Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "Glass Instruments", 4, printTele)

   fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"
   file = io.readall(fn)
   if file then
      Glass.page = json.decode(file)
      if #Glass.page > 0 then
	 pageNumber = 1
	 pageMax = #Glass.page
      end
      gaugeNumber = 1
   else
      print("Glass - No saved state")
      Glass.page = {}
   end

   -- put hex strings back into numbers for Id and Pa
   for k, v in pairs(Glass.page) do
      for kk,vv in pairs(v) do
	 for kkk, vvv in pairs(vv) do
	    if  kkk == "sensorId" or kkk == "sensorPa" then
	       vv[kkk] = tonumber(vvv)
	    end
	 end
      end
   end

   fn = prefix()..pathJson.."availFmt.jsn"
   file = io.readall(fn)
   if file then
      availFmt = json.decode(file)
      --print("Glass - Reading availFmt ", fn)
   else
      print("Glass - Could not read availFmt.jsn")
      availFmt =  {}
   end

   local gw = 304
   local gh = 256
   local large = 160
   local ofs=5
   
   local availVals = {L1 = gw/2,
		 L2 = gw/2 - large/2 - ofs, R2 = gw/2 + ofs + -large/4 + large/2,
		 L3 = gw/2 - ofs - large/4, R3 = gw/2 + ofs + large/2,
		 L4 = gw/2 - ofs - large/2, C4 = gw/2, R4 = gw/2 + ofs + large/2,
		 H1 = gh/2, H2 = gh/2 - ofs * 6, H3 = gh/2 + large/2 + ofs * 2,
		 GWID = gw, GHGT = gh
		 
   }

   -- fill in availFmts table with actual pixel value
   
   availFmts = {}
   for k,gp in ipairs(availFmt) do
      availFmts[k] = {}
      for g,t in ipairs(gp) do
	 availFmts[k][g] =  {}
	 availFmts[k][g].xc = availVals[t.xc]
	 availFmts[k][g].yc = availVals[t.yc]
	 availFmts[k][g].width = t.width -- availVals[t.width]
	 availFmts[k][g].height = t.height -- availVals[t.height]
      end
   end

   prepCI(availVals)
   
   pageSw = system.pLoad("pageSw")

   -- to do: configVersion should go in the GG file
   
   configVersion = system.pLoad("configVersion", 1)
   
end

return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.4", name=appName}
