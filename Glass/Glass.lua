--[[

   -----------------------------------------------------------------------------------------
   Glass.lua -- write telemetry values to the serial link for AR glasses

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   Glass.lua released under MIT license by DFM 2024
   -----------------------------------------------------------------------------------------

--]]

local Glass = {}
Glass.sensorLalist = {"..."}
Glass.sensorLslist = {"..."}
Glass.sensorIdlist = {0}
Glass.sensorPalist = {0}
Glass.sensorUnlist = {"-"}
Glass.sensorDplist = {0}
Glass.sensorTylist = {0}
--Glass.page = {}

local pageNumber = 0
local pageMax = 0
local subForm
local savedRow = 0
local gaugeNumber = 0
local gaugeMax = 4
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
local fmtNumber = 0
local writeJSON = true
local appName = "Glass"
local pathApp = "Apps/"..appName.."/"
local pathImages = pathApp.."Images/"
local pathConfigs = pathApp.."Configs/"
local jsonHoldTime = 0
local availFmt = {}
local availFmts = {}
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

local function loop()
   local now = system.getTimeCounter()
   local unow = system.getTime()
   local sensor, sval
   local stbl = {}
   local gtbl = {}
   local av
   local scale
   local minV, maxV
      
   if sendState == state.IDLE and unow > jsonHoldTime then
      if pageMax > 0 and (now > lastWrite + 500) then

	 local p1 = math.floor(255 * (1 + system.getInputs("P1")) / 2)
	 local p2 = math.floor(255 * (1 + system.getInputs("P2")) / 2)
	 
	 stbl = {page=pageNumber, P1=p1, P2=p2}
	 for k,v in pairs(Glass.page[pageNumber]) do
	    if (v.sensorId ~= 0) and (v.sensorLa ~= 0) then
	       sensor = system.getSensorByID(v.sensorId, v.sensorPa)
	       if sensor and sensor.valid then
		  v.value = sensor.value
	       end
	       if v.imageID >= 0 then
		  av = id2avail[v.imageID]
	       else
		  av = nil
	       end
	       if av then
		  scale = availImgs[av].scale
	       end
	       if scale == "variable" then
		  minV = v.minV or availImgs[av].minV -- if min/max not set pick up defaults
		  maxV = v.maxV or availImgs[av].maxV
	       else
		  minV = availImgs[av].minV
		  maxV = availImgs[av].maxV
	       end
	       --print("pn,g, g.imageID, scale", pageNumber, k, v.imageID, av, scale)
	    end
	    local fms
	    if v.decimals == 0 then
	       fms = "%.0f"
	    elseif v.decimals == 1 then
	       fms = "%.2f"
	    else
	       fms = "%.3f"
	    end
	    sval = string.format(fms, v.value or 0)
	    gtbl = {type=v.type, value = sval, unit=v.units}
	    gtbl.id = v.imageID
	    if scale == "variable" then
	       gtbl.minV = minV
	       gtbl.maxV = maxV
	    end
	    if Glass.page[pageNumber][k].sensorLa ~= "..." then
	       stbl[Glass.page[pageNumber][k].instName] = gtbl
	    end
	 end
	 if next(stbl) then
	    local espjson = json.encode(stbl)
	    local swa = system.getInputs("SA")
	    if swa and swa == 1 then
	       print(espjson)
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
      
      local cfgVersion = 2
      local cfgKey = 1
      local bufPre = "FFD0001561766961746F7200"
      local bufSet = "FFD2000D61766961746F7200AA"
      local bufH = bufPre .. string.format("%08X%08X", 0, cfgKey) .. "AA\n"
      local bufF = bufPre .. string.format("%08X%08X", cfgVersion, cfgKey) .. "AA\n"..bufSet.."\n"
      local bw
      if sendState == state.SENDHEADER then
	 --print("send header ", bufH)
	 print("Glass: Sending config header")
	 bw = serial.write(sidSerial, bufH)
	 io.write(sendFPser, bufH)
	 --print("bw, bufH", bw, bufH)
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
	 sendState = state.IDLE
	 --sendTime = system.getTimeCounter()	 
	 print("Send config done. Time (ms): ", system.getTimeCounter() - sendTime)
	 jsonHoldTime = system.getTime() + 2
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
	       --print("line", configLine)
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
	       io.write(sendFPser, buf)
	       --print("write buf", buf)
	       if not bw then
		  print("Glass: Serial write error")
		  buf = ""
	       end
	    end
	    if buf == "" then
	       --print("reached EOF on a file", sendImgsIdx, sendState)
	       if sendState == state.SENDFMTS then
		  io.close(sendFP)
		  sendFP = io.open(prefix() .. pathImages .. "encodedImgs.jsn", "r")
		  if not sendFP then
		     print("Glass: cannot open encoded images")
		     sendState = state.IDLE
		  end
		  sendState = state.SENDACTIVE
		  break
	       elseif sendState == state.SENDACTIVE then
		  io.close(sendFP)
		  sendState = state.SENDHEADER
		  break
	       elseif sendState == state.SENDFONTS then
		  --print("done with fonts, starting images")
		  io.close(sendFP)
		  sendImgsIdx = 1
		  --print("image opening " .. sendImgs[sendImgsIdx])
		  print("Glass: Sending image file " ..sendImgs[sendImgsIdx])
		  sendFP = io.open(sendImgs[sendImgsIdx], "r")
		  --print("sendFP image file tt", sendFP)
		  if not sendFP then
		     print("Glass:cannot open image file "..sendImgsIdx)
		     sendState = state.IDLE
		     break
		  else
		     sendState = state.SENDIMGS
		     --print("Glass: Sending images")
		  end
	       elseif sendState == state.SENDIMGS then
		  --print("end of image file " .. sendImgsIdx)
		  io.close(sendFP)
		  if sendImgsIdx < #sendImgs then
		     sendImgsIdx = sendImgsIdx + 1
		     print("Glass: Sending image file " ..sendImgs[sendImgsIdx])
		     sendFP = io.open(sendImgs[sendImgsIdx], "r")
		     --print("sendFP image file  bb", sendFP)
		     if not sendFP then
			print("Glass cannot open image file "..sendImgsIdx)
			sendState = state.IDLE
			break
		     end
		  else
		     --print("end of last image file")
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
   Glass.page[pageNumber][gaugeNumber].instName = value
end

local function clearJSON()
   local fn = prefix() .. pathApp .. "GG_" .. modelName.. ".jsn"
   local ans
   ans = form.question("Are you sure?", "Reset all app settings?",
		       "",
		       0, false, 5)
   if ans == 1 then
      print("removing " .. fn)
      io.remove(fn)
      system.messageBox("All settings deleted .. Restart App")
      writeJSON = false
   end
   
end

local function sendUSB()

   -- go thru all pages, and gauges to find imageIDs that are referenced
   -- and put them in a table to set up the data transmission
   
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
	    local fn = prefix() .. pathConfigs .. "config-imgs-" .. availImgs[av].name .. ".txt"
	    table.insert(sendImgs, fn)
	 end
      end
   end

   if #sendImgs < 1 then
      print("Glass: no image files referenced - nothing sent")
      return
   end

   sendFP = io.open(prefix() .. pathImages .. "glassFmts.jsn", "r")
   sendFPser = io.open(prefix() .. pathConfigs .. "config-serialout.txt", "w")
   
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
	 fmtNumber = 1
      end

      --sift thru avail images and find the ones that are the correct size
      --for this gauge in the selected format

      imageNum = nil
      local imageID = Glass.page[pageNumber][gaugeNumber].imageID
      local fn = Glass.page[pageNumber][1].fmtNumber
      local wid = availFmt[fn][gaugeNumber].width
      editImgs = {}
      for i, img in ipairs(availImgs) do
	 if ((wid == "full") and (img.imageWidth > 100)) or ( (wid == "half") and (img.imageWidth < 100) ) then
	    table.insert(editImgs,
			 {id=img.id, loadImage=img.loadImage, scale=img.scale, minV=img.minV, maxV = img.maxV})
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
	 else
	    imageID = editImgs[1].id
	    Glass.page[pageNumber][gaugeNumber].imageID = imageID
	 end
      end
      
      form.addRow(1)
      form.addLink((function(x) form.reinit(12) end), {label="Data source >"})

      form.addRow(1)
      form.addLink((function(x) form.reinit(13) end), {label="Min/Max >"})

      
      form.setTitle("Page " .. pageNumber .. " Gauge " .. gaugeNumber)
      
      form.setFocusedRow(1)
   elseif sf == 11 then

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

      --print("pN,gN,fn,id,av", pageNumber, gaugeNumber, fn, id, av)

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
   local fmtNumber = 1
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
   Glass.page[pn][1].fmtNumber = fmtNumber
end

local function keyPressed(key)
   
   if subForm == 1 then

      if keyExit(key) then
	 if key ~= KEY_ESC then
	    form.preventDefault()
	    form.reinit(1)
	 end
      end
   
      if key == KEY_1 then
	 pageNumber = pageNumber + 1
	 if pageNumber > 1 then -- limit #pages to 1 now
	    pageNumber = 1
	    return
	 end
	 pageMax = pageNumber
	 fmtNumber = 1
	 clearPage(pageNumber, gaugeMax)
	 form.reinit(1)
      elseif key == KEY_2 then
	 if pageNumber < 1 then
	    system.messageBox("No pages defined")
	    return
	 end
	 clearPage(pageNumber, gaugeMax)
	 fmtNumber = fmtNumber + 1
	 if fmtNumber > #availFmt then fmtNumber = 1 end
	 --print("setting .fmtNumber", fmtNumber, pageNumber)
	 Glass.page[pageNumber or 1][1].fmtNumber = fmtNumber
	 return
      elseif key == KEY_3 or key == KEY_ENTER then
	 savedRow = form.getFocusedRow()
	 if pageNumber > 0 then
	    pageNumber = savedRow
	    Glass.page[pageNumber][1].fmtNumber = fmtNumber
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
	 --print("key1 mx,gaugeNumber", mx, gaugeNumber)
	 imageNum = nil
	 form.reinit(10)
	 return
      elseif key == KEY_2 then
	 imageNum = imageNum + 1
	 if imageNum > imageMax then imageNum = 1 end
      end
      if key == KEY_2 then
	 local iid = 0
	 for i,img in ipairs(availImgs) do
	    if img.id == editImgs[imageNum].id then
	       iid = img.id
	    end
	 end
	 Glass.page[pageNumber][gaugeNumber].imageID = iid
	 print("key2 set imageID to", pageNumber, gaugeNumber, Glass.page[pageNumber][gaugeNumber].imageID)
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

local function printForm(w,h)

   local offset = w - 144
   --[[
   local gw = 304
   local gh = 256
   local large = 160
   local small = 144
   local ofs=5
   local vals = {L1 = gw/2,
		 L2 = gw/2 - large/2 - ofs, R2 = gw/2 + ofs + -large/4 + large/2,
		 L3 = gw/2 - ofs - large/4, R3 = gw/2 + ofs + large/2,
		 L4 = gw/2 - ofs - large/2, C4 = gw/2, R4 = gw/2 + ofs + large/2,
		 --L5 = gw/2 - small/2, R5 = gw/2 + small/2,
		 H1 = gh/2, H2 = gh/2, H3 = gh/2, H4 = gh/2, H5 = gh/2,
		 full = 160, half = 80, small=144
   }
   --]]
   if subForm == 10 then
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(offset-5, 0, h+1+5, h+1)
      --print("pF", imageNum)
      if imageNum and imageNum > 0 and editImgs[imageNum] and editImgs[imageNum].loadImage then
	 lcd.drawImage(offset,0,editImgs[imageNum].loadImage)
      else
	 lcd.setColor(0,0,0)
	 lcd.drawText(200,80, "imageNum " .. (imageNum or "nil") .." " .. #editImgs)
      end
   elseif subForm == 1 then
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(310-167, 0, 167, 141)

      lcd.setColor(0,0,0)
      lcd.setClipping(310-167, 0, 167, 141)

      lcd.drawRectangle(0, 0, 167, 141)
      lcd.setColor(200,200,200)
      lcd.drawRectangle(33/2, 28/2, 134, 113)
      lcd.setColor(0,0,0)

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

local function printTele(w,h)

   local offset = (159-144) / 2
   local v0 = 256-160
   local h0 = 5
   local id
   local av
   local xr, yr
   local gpp
   
   if fmtNumber > 0 then
      local gp = availFmts[fmtNumber]
      for g,t in ipairs(gp) do
	 --print(t.xc - t.width/2, t.yc - t.height/2, t.width, t.height)
	 xr = t.xc - t.width/2 +  h0
	 yr = t.yc - t.height/2 - v0/2
	 lcd.drawRectangle(xr, yr, t.width, t.height)
	 gpp = Glass.page[pageNumber]
	 id = gpp[g].imageID
	 if id >0 then
	    av = id2avail[id]
	 else
	    av = nil
	 end
	 --print(pageNumber, g, id, av)
	 if av then
	    lcd.drawCircle(xr + availImgs[av].x0, yr + availImgs[av].y0, 5)
	    lcd.drawText(xr + availImgs[av].x0, yr + availImgs[av].y0, string.format("%.1f", gpp[g].value or 0))
	 end
	 
      end
   end

   

   
   --[[ fix this code .. old var names and incomplete function!
   if pageNumber > 0 and gaugeNumber > 0 then
      local imageNum = Glass.page[pageNumber][1].imageNum
      local value = Glass.page[pageNumber][1].value or 0.0
      local ss
      lcd.setColor(255,255,255)
      if imageNum > 0 then
	 lcd.drawImage(offset,offset,image[imageNum])
	 ss = string.format("%.2f", value)
	 lcd.drawText(65, 138, ss)
      end
      imageNum = Glass.page[pageNumber][2].imageNum
      value = Glass.page[pageNumber][2].value or 0.0
      if imageNum > 0 then
	 lcd.drawImage(offset + 160, offset,image[imageNum])
	 ss = string.format("%.2f", value)
	 lcd.drawText(65+160, 138, string.format("%.2f", value))
      end
   end
   --]]

end

local function destroy()

   local fp
   local fn = prefix().."Apps/Glass/GG_" .. modelName.. ".jsn"

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
   
   --print("destroy", fn, json.encode(Glass.page))
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
   print("Glass onRead:", data)
end

local function init()

   local fn

   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(Glass)
   
   system.registerForm(1, MENU_APPS, "Glass", initForm, keyPressed, printForm)

   fn = prefix() .. pathImages .. "availImgs.jsn"
      
   local file = io.readall(fn)
   availImgs = {}
   if file then
      availImgs = json.decode(file)
      print("Glass - Reading avail images from ", fn)
   else
      system.messageBox("Glass: Cannot read " .. fn)
      return
   end

   -- availImgs.jsn has a lot of whitespace in it for readability, re-encode it
   -- to denser format for transmission to the ESP. Also put a 0XDD and 0XAA
   -- wrapper around it
   
   encodedImgs = json.encode(availImgs)

   local fp = io.open(prefix() .. pathImages .. "encodedImgs.jsn", "w")
   if not fp then
      print("Glass: cannot open encodedImgs.jsn for writing")
      return
   else
      if not io.write(fp, "FFDE", encodedImgs, "AA\n") then
	 print("Glass: write error encodedImgs.jsn")
	 return
      end
      io.close(fp)
      encodedImgs = nil
   end
   

   id2avail = {}
   for i,img in ipairs(availImgs) do
      local im = prefix() .. pathImages .. img.name .. "-small.png"
      img.loadImage = lcd.loadImage(im)
      img.imageWidth = img.loadImage.width
      img.imageHeight = img.loadImage.height
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
      sidSerial, descr = serial.init("ttyUSB1", baud)
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
	 print("Glass: Callback registered")
      else
	 print("Glass: Error setting callback", descr)
      end
            
   else
      print("Glass - Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "Glass Instruments", 4, printTele)

   fn = prefix().."Apps/Glass/GG_" .. modelName.. ".jsn"
   file = io.readall(fn)
   if file then
      Glass.page = json.decode(file)
      print("Glass - Reading saved state from ", fn)
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

   fn = prefix().."Apps/Glass/availFmt.jsn"
   file = io.readall(fn)
   if file then
      availFmt = json.decode(file)
      print("Glass - Reading availFmt ", fn)
   else
      print("Glass - Could not read availFmt.jsn")
      availFmt =  {}
   end

   if #Glass.page < 1 then
      fmtNumber = 0
   else
      fmtNumber = Glass.page[1][1].fmtNumber
   end

   local gw = 304
   local gh = 256
   local large = 160
   local ofs=5
   
   local availVals = {L1 = gw/2,
		 L2 = gw/2 - large/2 - ofs, R2 = gw/2 + ofs + -large/4 + large/2,
		 L3 = gw/2 - ofs - large/4, R3 = gw/2 + ofs + large/2,
		 L4 = gw/2 - ofs - large/2, C4 = gw/2, R4 = gw/2 + ofs + large/2,
		 H1 = gh/2, H2 = gh/2, H3 = gh/2, H4 = gh/2, H5 = gh/2,
		 full = 160, half = 80
   }

   local aF = {}
   availFmts = {}
   local gp = availFmt[fmtNumber]
   for k,gp in ipairs(availFmt) do
      aF[k] = {}
      availFmts[k] = {}
      for g,t in ipairs(gp) do
	 aF[k][g] = {}
	 availFmts[k][g] =  {}
	 --image coords for glasses are lower right of image, not upper left as traditional 
	 aF[k][g].xlr = availVals[t.xc] + availVals[t.width]/2
	 aF[k][g].ylr = availVals[t.yc] + availVals[t.height]/2
	 aF[k][g].width = availVals[t.width]
	 aF[k][g].height = availVals[t.hwight]

	 availFmts[k][g].xc = availVals[t.xc]
	 availFmts[k][g].yc = availVals[t.yc]
	 availFmts[k][g].width = availVals[t.width]
	 availFmts[k][g].height = availVals[t.height]
      end
   end
   
   local encodedaF = json.encode(aF)

   local fp = io.open(prefix() .. pathImages .. "glassFmts.jsn", "w")
   if not fp then
      print("Glass: cannot open glassFmts.jsn for writing")
      return
   else
      if not io.write(fp, "FFDD", encodedaF, "AA\n") then
	 print("Glass: write error glassFmts.jsn")
	 return
      end
      io.close(fp)
      encodedaF = nil
   end
end

return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.1", name="Glass"}
