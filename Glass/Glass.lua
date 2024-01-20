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
local imageMax
local emflag
local sidSerial
local lastWrite = 0
local image = {}
local imageFile = {}
local modelName
local sendingJSON = true
local state = {IDLE = 1, STANDBY = 2,SENDHEADER = 3, SENDFONTS = 4, SENDIMGS = 5, SENDFOOTER = 6}
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

local teleSensors, txTeleSensors
local txSensorNames = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		       "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		       "rxBVoltage", "rxBPercent", "photoValue"}
local txSensorUnits = {"V", "%", "mA", "mAh", "%", "V", "%", "V", "V", "%", " "}
local txSensorDP    = { 1,   0,    0,     0,   0,   1,   0,   1,   1,   0,   0}
local txRSSINames = {"rx1Ant1", "rx1Ant2", "rx2Ant1", "rx2Ant2",
		     "rxBAnt1", "rxBAnt2"}

-- base64 encoding/decoding routines
-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
local function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
local function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

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
   teleSensors = #tt.sensorLalist

   if true then return end -- leave the tx stuff off for now
      
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

end

local function loop()
   local now = system.getTimeCounter()
   local sensor, val, sval
   local stbl = {}
   local gtbl = {}

   if sendState == state.IDLE then
      if pageMax > 0 and (now > lastWrite + 500) then
	 --local p2 = 1+math.floor(2.51 * (1 + system.getInputs("P2")))
	 local p1 = math.floor(255 * (1 + system.getInputs("P1")) / 2)
	 local p2 = math.floor(255 * (1 + system.getInputs("P2")) / 2)
	 
	 --print("p2", p2)
	 --stbl = {page=p2}
	 stbl = {page=pageNumber, P1=p1, P2=p2}
	 for k,v in pairs(Glass.page[pageNumber]) do
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
	    sval = string.format(fms, v.value or 0)
	    gtbl = {type=v.type, value = sval, unit=v.units}
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
	 print("send header ", bufH) 
	 bw = serial.write(sidSerial, bufH)
	 io.write(sendFPser, bufH)
	 if not bw then
	    print("Glass: serial write error header")
	 else
	    sendState = state.SENDFONTS
	 end
      elseif sendState == state.SENDFOOTER then
	 print("send footer ", bufF)
	 bw = serial.write(sidSerial, bufF)
	 io.write(sendFPser, bufF)
	 if not bw then print("Glass: serial write error on footer") end
      end
      if not bw or (sendState == state.SENDFOOTER) then
	 if sendFPser then io.close(sendFPser) end
	 sendState = state.IDLE
	 --sendTime = system.getTimeCounter()	 
	 print("DONE", system.getTimeCounter() - sendTime)
      end
   elseif (sendState == state.SENDFONTS) or (sendState == state.SENDIMGS) then
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
	       print("write buf", buf)
	       if not bw then
		  print("Glass: Serial write error")
		  buf = ""
	       end
	    end
	    if buf == "" then
	       print("reached EOF on a file", sendImgsIdx, sendState)
	       if sendState == state.SENDFONTS then
		  print("done with fonts, starting images")
		  io.close(sendFP)
		  sendImgsIdx = 1
		  print("image opening " .. sendImgs[sendImgsIdx])
		  sendFP = io.open(sendImgs[sendImgsIdx], "r")
		  print("sendFP image file tt", sendFP)
		  if not sendFP then
		     print("Glass:cannot open image file "..sendImgsIdx)
		     sendState = state.IDLE
		     break
		  else
		     sendState = state.SENDIMGS
		  end
	       elseif sendState == state.SENDIMGS then
		  print("end of image file " .. sendImgsIdx)
		  io.close(sendFP)
		  if sendImgsIdx < #sendImgs then
		     sendImgsIdx = sendImgsIdx + 1
		     print("opening image file " ..sendImgs[sendImgsIdx])
		     sendFP = io.open(sendImgs[sendImgsIdx], "r")
		     print("sendFP image file  bb", sendFP)
		     if not sendFP then
			print("Glass cannot open image file "..sendImgsIdx)
			sendState = state.IDLE
			break
		     end
		  else
		     print("end of last image file")
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
   local fn = prefix().."Apps/Glass/GG_" .. modelName.. ".jsn"
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

   sendFP = io.open(prefix().."Apps/Glass/Configs/config-fonts.txt", "r")
   print("sendFP", sendFP)
   sendFPser = io.open(prefix().."Apps/Glass/Configs/config-serialout.txt", "w")
   print("sendFPser ", sendFPser)
   sendImgs = {prefix().."Apps/Glass/Configs/config-imgs-square-full.txt",
	       prefix().."Apps/Glass/Configs/config-imgs-right-half.txt",
	       prefix().."Apps/Glass/Configs/config-imgs-left-half.txt"
   }
   
   if sendFP and sidSerial then
      sendAA = 0
      sendFF = 0
      sendTime = system.getTimeCounter()
      configLine = ""
      sendState = state.SENDHEADER
   else
      print("Glass: could not open config font file or serial port not open")
      sendState = state.IDLE
   end
   
end

local function sendFile()
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
      form.setButton(3, ":up", ENABLED)
      form.setButton(4, ":down", ENABLED)

      if gaugeNumber == 0 then gaugeNumber = 1 end
      if pageNumber == 0 then pageNumber = 1 end
      if not Glass.page[pageNumber][gaugeNumber].instName then
	 Glass.page[pageNumber][gaugeNumber].instName = 'Gauge'..gaugeNumber
      end

      --print("sf 10", Glass.page[pageNumber][1].fmtNumber)
      if Glass.page[pageNumber][1].fmtNumber < 1 then
	 Glass.page[pageNumber][1].fmtNumber = 1
      end
      
      if Glass.page[pageNumber][gaugeNumber].gaugeFile == "..." then
	 Glass.page[pageNumber][gaugeNumber].gaugeFile = imageFile[1]
      end
      
      local isen = 1
      local isel = 0
      for k = 1, #Glass.sensorLalist do
	 if (Glass.sensorIdlist[k] == Glass.page[pageNumber][gaugeNumber].sensorId) and
	    (Glass.sensorPalist[k] == Glass.page[pageNumber][gaugeNumber].sensorPa) then
	    isel = k
	    break
	 end
      end
      --form.addRow(1)
      --form.addLabel({label="Sensor:", width=155, font=FONT_NORMAL})
      form.addRow(1)
      form.addSelectbox(Glass.sensorLalist, isel, true, changedSensor,
			{width=155, font=FONT_NORMAL, alignRight=false})

      --form.addRow(1)
      --form.addLabel({label="Inst Name:", width=155, font=FONT_NORMAL})
      form.addRow(1)
      form.addTextbox(Glass.page[pageNumber][gaugeNumber].instName, 10, changedName,
			{width=155, font=FONT_NORMAL})

      form.setTitle("Page " .. pageNumber .. " Gauge " .. gaugeNumber)
      
      form.setFocusedRow(1)
   elseif sf == 11 then
      form.addRow(1)
      form.addLink(sendUSB, {label="Send config on serial>>"})
      form.addRow(1)
      form.addLink(clearJSON, {label="Reset app settings>>"})
      
      --form.addLabel({label="Tools menu", width = 220})      
   end
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end


local function keyPressed(key)
   local imageNum
   
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
	 Glass.page[pageNumber] = {}
	 for k=1,gaugeMax do
	    Glass.page[pageNumber][k] = {}
	    Glass.page[pageNumber][k].sensorId = 0
	    Glass.page[pageNumber][k].sensorPa = 0	 
	    Glass.page[pageNumber][k].sensorLs = "..."
	    Glass.page[pageNumber][k].sensorLa = "..."	    
	    Glass.page[pageNumber][k].units = "-"
	    Glass.page[pageNumber][k].decimals = 0
	    Glass.page[pageNumber][k].imageNum = 0
	    Glass.page[pageNumber][k].gaugeFile = "..."
	    Glass.page[pageNumber][k].value = 0.0
	    Glass.page[pageNumber][k].instName = "Gauge"..k
	 end
	 Glass.page[pageNumber][1].fmtNumber = fmtNumber
	 form.reinit(1)
      elseif key == KEY_2 then
	 if pageNumber < 1 then
	    system.messageBox("No pages defined")
	    return
	 end
	 fmtNumber = fmtNumber + 1
	 if fmtNumber > #Glass.availFmt then fmtNumber = 1 end
	 --print("setting .fmtNumber", fmtNumber, pageNumber)
	 Glass.page[pageNumber or 1][1].fmtNumber = fmtNumber
	 return
      elseif key == KEY_3 or key == KEY_ENTER then
	 savedRow = form.getFocusedRow()
	 if pageNumber > 0 then
	    pageNumber = savedRow
	    Glass.page[pageNumber][1].fmtNumber = fmtNumber
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
	 form.reinit(1)
      end

      imageNum = Glass.page[pageNumber][gaugeNumber].imageNum
      
      if key == KEY_1 then
	 gaugeNumber = gaugeNumber + 1
	 --if gaugeNumber > gaugeMax then
	 local fm = Glass.page[pageNumber][1].fmtNumber
	 local mx = #Glass.availFmt[fm]
	 if gaugeNumber > mx then	 
	    gaugeNumber = 1
	 end
	 form.reinit(10)
	 return
      elseif key == KEY_3 then
	 --print("enter key_3", imageNum)
	 imageNum = imageNum + 1
	 if imageNum > imageMax then imageNum = 1 end
      elseif key == KEY_4 then
	 imageNum = imageNum - 1
	 if imageNum < 1 then imageNum = imageMax end      
      end
      if key == KEY_3 or key == KEY_4 then
	 Glass.page[pageNumber][gaugeNumber].imageNum = imageNum
	 Glass.page[pageNumber][gaugeNumber].gaugeFile = imageFile[imageNum]
	 --print("key3/4", imageNum, imageFile[imageNum])
      end
   elseif subForm == 11 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
      
   end
   
end

local function drawRectangleGlass(x0, y0, xl, yl)
   local f = 0.55
   lcd.drawRectangle(f*x0 - f*xl / 2, f*y0 - f*yl / 2, f*xl, f*yl)
end

local function printForm(w,h)
   local offset = w - 144
   local gw = 304
   local gh = 256
   local large = 160
   local small = 144
   local ofs=5
   
   local vals = {L1 = gw/2,
		 L2 = gw/2 - large/2 - ofs, R2 = gw/2 + ofs + -large/4 + large/2,
		 L3 = gw/2 - ofs - large/4, R3 = gw/2 + ofs + large/2,
		 L4 = gw/2 - ofs - large/2, C4 = gw/2, R4 = gw/2 + ofs + large/2,
		 L5 = gw/2 - small/2, R5 = gw/2 + small/2,
		 H1 = gh/2, H2 = gh/2, H3 = gh/2, H4 = gh/2, H5 = gh/2,
		 full = 160, half = 80, small=144
   }
		 
   if subForm == 10 then
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(offset-5, 0, h+1+5, h+1)
      local imageNum = Glass.page[pageNumber][gaugeNumber].imageNum
      local fn = Glass.page[pageNumber][1].fmtNumber
      local alpha
      --print("#", fmtNumber, gaugeNumber, imageNum, Glass.availFmt[fmtNumber][gaugeNumber].width) --,
      --image[imageNum].size)\
      if imageNum < 1 then
	 imageNum = 1
	 Glass.page[pageNumber][gaugeNumber].imageNum = imageNum
      end
      --print("$", #image, ii, image[1], image[1].size)
      --print("%", Glass.availFmt[fmtNumber][gaugeNumber].width)
      if Glass.availFmt[fmtNumber][gaugeNumber].width == image[imageNum].size then
	 alpha = 255
      else
	 alpha = 32
      end
      if imageNum > 0 then
	 lcd.drawImage(offset,0,image[imageNum], alpha)
      end
      local ss = Glass.page[pageNumber][gaugeNumber].gaugeFile
      --[[
      lcd.setColor(0,0,255)
      lcd.drawText(10,50, "Units: " .. Glass.page[pageNumber][gaugeNumber].units)
      lcd.drawText(10,70, "Decimals: " .. math.floor(Glass.page[pageNumber][gaugeNumber].decimals))
      --local ww = lcd.getTextWidth(FONT_MINI, ss)
      --lcd.drawText(offset + h/2 - ww / 2, 130, ss, FONT_MINI)
      lcd.drawText(10,90, "Img: " .. ss)      
      --]]
   elseif subForm == 11 then
      lcd.drawText(10, 120, "CPU: " ..cpu)
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
	 local gp = Glass.availFmt[fmtNumber]
	 for g,t in ipairs(gp) do
	    --print(fmtNumber, g, t, vals[t.x0], vals[t.y0], vals[t.width], vals[t.height])
	    drawRectangleGlass(vals[t.x0], vals[t.y0], vals[t.width], vals[t.height])
	 end
      end
      
      lcd.resetClipping()
   end
   
   
end

local function printTele(w,h)

   local offset = (159-144) / 2
   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159)
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

   local dd, fn, ext
   local ff

   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(Glass)
   
   system.registerForm(1, MENU_APPS, "Glass", initForm, keyPressed, printForm)

   local path = prefix().."Apps/Glass/Images"
   
   imageMax = 0
   if dir(path) then
      for name, _, _ in dir(path) do
	 dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
	 if fn and ext then
	    if string.lower(ext) == "png" then
	       ff = path .. "/" .. fn .. "." .. ext
	       imageMax = imageMax + 1
	       --print(imageMax, fn)
	       imageFile[imageMax] = fn
	       image[imageMax] = lcd.loadImage(ff)
	       local w = image[imageMax].width
	       local h = image[imageMax].height
	       local s
	       if w == 144 and h == 144 then
		  s = "full"
	       elseif w == 75 and h == 144 then
		  s = "half"
	       else
		  s = "unk"
	       end
	       image[imageMax].size = s		  
	       --print("image: "..fn..' '..w..' '.. h .. ' ' ..s)
	    end
	 end
      end
   end

   local device
   
   device, emflag = system.getDeviceType() 
   
   local descr
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
      --gpio.mode(8, "out-pp")
      --gpio.write(8,1)
      --SPECIAL
      --SPECIAL
      local success, descr = serial.onRead(sidSerial,onRead)   
      if success then
	 print("Glass: Callback registered")
      else
	 print("Glass: Error setting callback", descr)
      end
            
   else
      print("Glass - Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "Glass Instruments", 4, printTele)

   local fn = prefix().."Apps/Glass/GG_" .. modelName.. ".jsn"

   local file = io.readall(fn)
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

   local fn = prefix().."Apps/Glass/availFmt.jsn"
   local file = io.readall(fn)
   if file then
      Glass.availFmt = json.decode(file)
      print("Glass - Reading availFmt ", fn)
   else
      print("Glass - Could not read availFmt.jsn")
      Glass.availFmt =  {}
   end

   if #Glass.page < 1 then
      fmtNumber = 0
   else
      fmtNumber = Glass.page[1][1].fmtNumber
   end

   
   
end


   

return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.1", name="Glass"}
