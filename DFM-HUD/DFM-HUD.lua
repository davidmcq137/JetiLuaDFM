--[[

   -----------------------------------------------------------------------------------------
   Glass.lua -- write telemetry values to the serial link for AR glasses

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   Glass.lua released under MIT license by DFM 2024
   -----------------------------------------------------------------------------------------

--]]

if not sharedVar then sharedVar = {} end

local appName = "DFM-HUD"
local pathApp = "Apps/"..appName.."/"
local pathImages = pathApp.."Images/"
local pathConfigs = pathApp.."Configs/"
local pathJson = pathApp.."Json/"
local JSNVERSION = 5
local dbmode = false
local loopCPU = 0	 
local logFileFP
local wasEverGreen = false
local Glass = {}
local otaTimer = 0
local restartTimer = 0
local powerDownTimer = 0
local gestureTime = 0
--local rebootDisco = false

Glass.sensorLalist = {"..."}
Glass.sensorLslist = {"..."}
Glass.sensorIdlist = {0}
Glass.sensorPalist = {0}
Glass.sensorUnlist = {"-"}
Glass.sensorDplist = {0}
Glass.sensorTylist = {0}

Glass.gpsLalist = {"..."}
Glass.gpsLslist = {"..."}
Glass.gpsIdlist = {0}
Glass.gpsPalist = {0}

Glass.settings = {}
Glass.timers = {}
Glass.switchInfo = {}
Glass.var = {}

Glass.convertStr = {"None", "m to ft", "m/s to mph", "m/s to km/h", "°C to °F"}
Glass.convertVal = {{1,0}, {3.28084,0}, {2.23694,0} , {3.6,0}, {1.8,32}}
Glass.convertUnits = {"-", "ft", "mph", "km/h", "°F"}

--Glass.switches = {}

local swtCI = {}
local switchItems = {}

local pageNumber = 0
local pageMax = 0
local pageLimit = 3
local pageNumberTele
local subForm
local savedRow = 0
local gaugeNumber = 0
local gaugeMax = 10 -- max # gauges in a format
local emflag
local sidSerial
local lastWrite = 0
local encodedImgs = {}
local id2avail = {}
local editImgs = {}
local imageNum
local imageMax
local modelName
local state = {DISCONNECTED=1, WAITING=2, CONNECTED=3, SENDHEADER=4, SENDFILE=5, SENDFOOTER=6,
	       COMPLETE=7}
local sendState = state.DISCONNECTED
local startingTime = 0
local WAIT_TIME = 200
local sendCtrlCount
local sendFP, sendFPser
local sendImgs
local sendImgsIdx
local sendAA
local sendFF
local sendTime
local sendLast = 0
local cpu = 0
local configLine
local writeJSON = true
local jsonHoldTime = 0
local tempCall
local sendFPtemp
local cfgimg = {}
local cfgimgESP = {}
local glassesIcon
local redcrossIcon
local greencheckIcon
local batteryIcon
local yellowpauseIcon
--local configIDs
local currentConfigIDs
local serialBytesSent = 0
local totalSendBytes
local serialFileName
local lastRead = 0
local serialWriteCount = 0

local gtbl = {}

local initTime

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
local function drawRectangleCenter(x,y,w,h)
   lcd.drawRectangle(x-w/2, y-h/2, w, h)
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function tempWrite(a,b)
   io.write(sendFPtemp, b)
   return tempCall(a,b)
end


local function sv(dec, val)
   local fms
   --if not dec or (dec < 0) or (dec > 2) then return nil end
   if dec == 0 then
      fms = "%.0f"
   elseif dec == 1 then
      fms = "%.2f"
   else
      fms = "%.3f"
   end
   
   if val then 
      return string.format(fms, val)
   else
      return nil
   end
end

local function svv(dec, val)
   local fms
   --if not dec or (dec < 0) or (dec > 2) then return nil end
   if dec == 0 then
      fms = "%.0f"
   elseif dec == 1 then
      fms = "%.1f"
   else
      fms = "%.2f"
   end
   
   if val then 
      return string.format(fms, val)
   else
      return nil
   end
end

local function writeInst()

   --print("writeInst()")
   local scale
   local minV, maxV
   local stbl = {}
   local gtbl = {}

   --print("writeInst: Glass", Glass)
   --print("writeInst: Glass.page", Glass.page)
   --print("writeInst: pageNumberTele", pageNumberTele)
   --print("writeInst: Glass.page[pageNumberTele", Glass.page[pageNumberTele])
   
   if not Glass.page or #Glass.page == 0 or not pageNumberTele or #Glass.page[pageNumberTele] == 0 then
      print("Glass: No instrESPW to send")
      return
   end

   local ptbl = {}
   for p = 1, #Glass.page, 1 do
      local j = 0
      stbl = {}
      for k,v in ipairs(Glass.page[p]) do
	 if v.imageID and v.imageID >= 0 then
	    j = j + 1
	    stbl[j] = {}
	    if cfgimg.instruments[v.widgetID].scale ~= "fixed" then
	       scale = "variable"
	    else
	       scale = "fixed"
	    end
	    if scale == "variable" then -- if min/max not set pick up defaults
	       minV = v.minV or cfgimg.instruments[v.widgetID].minV
	       maxV = v.maxV or cfgimg.instruments[v.widgetID].maxV
	    else
	       minV = cfgimg.instruments[v.widgetID].minV
	       maxV = cfgimg.instruments[v.widgetID].maxV 
	    end
	    stbl[j].im = v.imageID
	    stbl[j].wd = v.widgetID - 1
	    stbl[j].fm = cfgimg.instruments[v.widgetID].formID
	    stbl[j].wt = string.sub(cfgimg.instruments[v.widgetID].wtype,0,2)
	    --[[
	    if cfgimg.instruments[v.widgetID].wtype == "htext" then
	       stbl[j].u = Glass.page[p][k].units
	       stbl[j].d = Glass.page[p][k].decimals
	       stbl[j].l=Glass.page[p][k].instName
	    elseif cfgimg.instruments[v.widgetID].wtype == "arcGauge" then
	       stbl[j].d = Glass.page[p][k].decimals
	    elseif cfgimg.instruments[v.widgetID].wtype == "timer" then
	       stbl[j].u = ""
	       stbl[j].l = Glass.page[p][k].instName
	    else
	       stbl[j].u = nil
	    end
	    --]]
	    local dd
	    if true then --scale == "variable" then
	       stbl[j].nV = tonumber(sv(2, minV))
	       stbl[j].xV = tonumber(sv(2, maxV))
	       stbl[j].l = Glass.page[p][k].instName
	       stbl[j].mJ = Glass.page[p][k].major
	       stbl[j].mN = Glass.page[p][k].minor		     
	       stbl[j].f = Glass.page[p][k].fine
	       --stbl[j].fM = Glass.page[p][k].ticfmt
	       if Glass.page[p][k].dispdec then
		  dd = Glass.page[p][k].dispdec
	       else
		  dd = Glass.page[p][k].decimals
	       end
	       stbl[j].mK = Glass.page[p][k].marker
	       stbl[j].d = dd
	       stbl[j].u = Glass.page[p][k].units
	    end
	 end
      end
      ptbl[p] = stbl
   end
   --local pptbl={}
   --pptbl["instW"] = ptbl
   --print(json.encode(pptbl))
	 
   --[[
   gtbl["instW"] = {}
   for kk,vv in ipairs(stbl) do
      gtbl["instW"][kk] = vv
   end
   --]]
   --local instW =  json.encode(pptbl)
   --print("opening instW")
   --local FP = io.open(prefix() .. pathJson .. "instrESPW.jsn", "w")
   --if FP  then
   --   io.write(FP, instW, "\n")
   --   io.close(FP)
   --else
   --   print("Glass: Cannot open instrESPW.jsn for writing")
   --end
   --print("sending USB part")
   --sendUSB("part")
   --print("sending USB full")
   --sendUSB("full")

end


local function updateConfigIDs()
   -- note the current configuration of which imageIDs are used.
   -- redo whenver we hit a key so it's always current
   local iid 
   currentConfigIDs = {}
   for p,v in ipairs(Glass.page) do
      for g in ipairs(v) do
	 --print("updateConfigIDs", p,g,Glass.page[p][g].imageID)
	 iid = math.floor(Glass.page[p][g].imageID)
	 if Glass.page[p][g].imageID > 0 then
	    table.insert(currentConfigIDs, iid)
	 end
      end
   end
end

local function sortUniq(tt, ttc)
   local inc
   local outk = 1
   ttc[outk] = tt[1]
   for k in ipairs(tt) do
      for j = 1, #ttc, 1 do
	 inc = false
	 if (tt[k] == ttc[j]) then
	    inc = true
	    break
	 end
      end
      if not inc then
	 outk = outk + 1
	 ttc[outk] = tt[k]
      end
   end
   table.sort(ttc)
end

   
local function matchConfigID()
   --Glass.settings.configIDs, currentConfigIDs)

   if not dbmode then return true end
   
   local t1 = Glass.settings.configIDs
   local t2 = currentConfigIDs

   --if not t1 or not t2 or (#t1 ~= #t2) then return false end

   local t1c, t2c = {}, {}

   sortUniq(t1, t1c)
   sortUniq(t2, t2c)

   local s = ""
   for k,v in ipairs(t1c) do
      s = s..v.." "
   end
   --print("t1c " .. s)

   s = ""
   for k,v in ipairs(t2c) do
      s = s..v.." "
   end
   --print("t2c " .. s)


   local ret = true
   for k in ipairs(t2) do
      if t1c[k] ~= t2c[k] then
	 ret = false
	 break
      end
   end
   --print("matchConfigID ret",  ret)
   return ret
end

local function drawImage(x,y,imgt, key)

   --if type(imgt[key]) ~= "table" then
   --   print("loading image " .. imgt[key])
   --   imgt[key] = lcd.loadImage(imgt[key])
   --end
   
   return lcd.drawImage(x,y,imgt[key])
end

local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
end

local function drawArc(theta, x0, y0, a0, aR, ri, ro, im, alp)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*theta/im), y0 - ro * math.sin(a0 + i*theta/im))
   end
   
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*theta/im), y0 - ri * math.sin(a0+i*theta/im))
   end
   lcd.setColor(255,255,255)
   ren:renderPolygon(alp)
end

local function drawArcGauge(x0, y0, degMin, degMax, min, max, val, rO, rI)
   local pct = (val - min) / (max - min)
   pct = math.max(math.min(pct, 1.0), 0.0)
   local thd = degMin + pct * (degMax - degMin)
   local thr = math.rad(thd - degMin)
   drawArc(thr, x0, y0, math.rad(degMin + 90), math.rad(degMax + 90), rI, rO, 20, 1)
   --drawTextCenter(x0, y0, string.format("%.2f", val), FONT_BIG)
end

local function drawPitch(roll, pitch, pitchR, radAH, X0, Y0)

   local XH,YH
   local XHS = 18 * radAH / 70
   local XHL = 40 * radAH / 70
   
   local sinRoll = math.sin(math.rad(-roll))
   local cosRoll = math.cos(math.rad(-roll))
   local delta = pitch % 15    
   local ren = lcd.renderer()
   
   local i = delta - 45
   repeat
      --print(string.format("i %f delta %f pitch %f abs(pitch - i) %f", i, delta, pitch, math.abs(pitch-i)))
      if math.abs(pitch - i) < 0.01 then
	 XH = XHL;
      else
	 XH = XHS;
      end
      YH = pitchR * i                      

      local dxh = XH / 5
      local xw = {XH, XH - 3 * dxh, XH - 4 * dxh, 0}
      local yw = {YH, YH, YH + dxh, YH}
      local xp = {}
      local yp = {}
      for i = 1, 4, 1 do
	 xp[i] = -xw[i] * cosRoll - yw[i] * sinRoll
	 yp[i] = -xw[i] * sinRoll + yw[i] * cosRoll
      end
      for i = 3, 1, -1 do
	 xp[8-i] = xw[i] * cosRoll - yw[i] * sinRoll
	 yp[8-i] = xw[i] * sinRoll + yw[i] * cosRoll
      end
      if( not ( (xp[1] < -radAH and xp[7] < -radAH) or  (xp[1] > radAH and xp[7] > radAH)
	     or (yp[1] < -radAH and yp[7] < -radAH) or  (yp[1] > radAH and yp[7] > radAH) ) ) then
	 lcd.setColor(255,255,255)
	 ren:reset()
	 if (XH == XHL) then
	    for i = 1, #xp, 1 do
	       ren:addPoint(X0 + radAH + xp[i], Y0 + radAH + yp[i])
	    end
	    ren:renderPolyline(2)
	 else
	    ren:addPoint(X0 + radAH + xp[1], Y0 + radAH + yp[1])
	    ren:addPoint(X0 + radAH + xp[7], Y0 + radAH + yp[7])	    
	    ren:renderPolyline(2)
	 end
      end
      i = i + 15
   until i >= 45 + delta

end

local function drawahGauge(x, y, r, hh, ww, pp, rr)
   --local pitch = system.getInputs("P2") * 90
   --local roll = system.getInputs("P1") * 180
   local pitch, roll
   if not pp then pitch = 0 else pitch = pp end
   if not rr then roll = 0 else roll = rr end
   --print("p,r", pitch, roll)
   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(x - ww/2, y - hh/2, ww, hh)
   lcd.setColor(255,255,255)
   lcd.drawCircle(x, y, 7) 
   local BAR = 25 * ww / 160 -- scale BAR and EE to width, nominal 25 at 160px wide
   local EE = 5 * ww / 160

   lcd.drawLine(x - ww / 2 + EE, y, x - (ww / 2 - BAR), y)
   lcd.drawLine(x - ww / 2 + EE, y, x - ww / 2 + EE, y + EE)
   
   lcd.drawLine(x + ww / 2 - EE, y, x + (ww / 2 - BAR), y)
   lcd.drawLine(x + ww / 2 - EE, y, x + ww / 2 - EE, y + EE)

   --lcd.drawText(x - ww / 2 + EE, y + hh / 2 - 25, string.format("P: %d°", pitch), FONT_MINI)
   --lcd.drawText(x - ww / 2 + EE, y - hh / 2 + 5,  string.format("R: %d°", roll), FONT_MINI)   
   local radAH = ww * 0.4 -- / 2
   drawPitch(roll, pitch, radAH / 25, radAH, x - radAH, y - radAH)
end

local function changedSwitch(val, switchName)
   --print("changedSwitch", val, switchName)
   local Invert = 1.0
   local swInfo = system.getSwitchInfo(val)
   local swTyp = string.sub(swInfo.label,1,1)
   if swInfo.assigned then
      if string.sub(swInfo.mode,-1,-1) == "I" then Invert = -1.0 end
      -- note: swInfo.mode will be "PS" for normal sw eval, "P" for proportional
      local prop = (string.find(swInfo.mode, "S") == nil)
      --print("cS, prop, swTyp", prop, swTyp, swInfo.mode, Invert, swInfo.value)
      if prop or (swInfo.value == Invert) or swTyp == "L" or swTyp =="M" then
	 --print("CS assigning")
	 switchItems[switchName] = val
	 Glass.switchInfo[switchName] = {} 
	 Glass.switchInfo[switchName].name = swInfo.label
	 if swTyp == "L" or swTyp =="M" then
	    Glass.switchInfo[switchName].activeOn = 0
	 else
	    local ao = system.getInputs(string.upper(swInfo.label))
	    Glass.switchInfo[switchName].activeOn = ao
	 end
	 Glass.switchInfo[switchName].mode = swInfo.mode
      else
	 system.messageBox("Error - do not move switch when assigning")
	 --print("CS zeroing")
	 form.setValue(swtCI[switchName], nil)
	 switchItems[switchName] = nil
	 Glass.switchInfo[switchName] = nil	 
      end
   else
      if Glass.switchInfo[switchName] then
	 --print("CS zeroing - not assigned")
	 switchItems[switchName] = nil
	 Glass.switchInfo[switchName] = nil
      end
   end
end


local function ms(ival)
   local val
   if not ival then val = 0 else val = ival / 1000 end
   local sign
   if val > 0 then sign = "+" elseif val < 0 then sign = "-" else sign = " " end
   local aval = math.abs(val)
   local mins = aval // 60
   local secs = math.floor(aval - mins * 60)
   return mins, secs, sign
end

local function hms(ival)
   local val
   if not ival then val = 0 else val = ival / 1000 end
   local sign
   if val > 0 then sign = "+" elseif val < 0 then sign = "-" else sign = " " end
   local aval = math.abs(val)
   local hrs = aval // (3600)
   local mins = (aval - hrs * 3600) // 60
   local secs = math.floor(aval - hrs * 3600 - mins * 60)
   return hrs, mins, secs, sign
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
   local GPStype = 9
   
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    if sensor.type ~= GPStype then
	       table.insert(tt.sensorLalist, l1 .. "_" .. l2)
	       table.insert(tt.sensorLslist, sensor.label)	    
	       table.insert(tt.sensorIdlist, sensor.id)
	       table.insert(tt.sensorPalist, sensor.param)
	       table.insert(tt.sensorUnlist, sensor.unit)
	       table.insert(tt.sensorDplist, sensor.decimals)
	       table.insert(tt.sensorTylist, sensor.type)
	    else
	       table.insert(tt.gpsLalist, l1 .. "_" .. l2)	       
	       table.insert(tt.gpsLslist, sensor.label)	    
	       table.insert(tt.gpsIdlist, sensor.id)
	       table.insert(tt.gpsPalist, sensor.param)
	    end
	 end
      end
   end

   -- Special sensors (values come from other than telemetry sensors)
   --
   -- Id = -1
   --
   -- Pa = 1  GPS Distance
   -- Pa = 2  GPS Bearing To
   -- Pa = 3  GPS Bearing From
   -- Pa = 4  Timer 1
   -- Pa = 5  Timer 2
   -- Pa = 6  Timer 1 percentage of time/(initial-target)
   -- Pa = 7  Timer 2 percentage of time/(initial-target)   
   
   local function insertSp(tbl, id, pa, la, ls, un)
      table.insert(tbl.sensorLalist, la)
      table.insert(tbl.sensorLslist, ls)
      table.insert(tbl.sensorIdlist, id)
      table.insert(tbl.sensorPalist, pa)
      table.insert(tbl.sensorUnlist, un)      
   end

   insertSp(tt, -1, 1, "GPS_Distance", "Distance", "m")
   insertSp(tt, -1, 2, "GPS_BearingTo", "BearingTo", "°")
   insertSp(tt, -1, 3, "GPS_BearingFrom", "BearingFrom", "°")
   insertSp(tt, -1, 4, "GPS_Heading", "Heading", "°")   
   insertSp(tt, -1, 5, "T_Timer1", "Timer1Secs", "s")
   insertSp(tt, -1, 6, "T_Timer2", "Timer2Secs", "s")
   insertSp(tt, -1, 7, "T_Timer1Pct", "Timer1Pct", "%")
   insertSp(tt, -1, 8, "T_Timer2Pct", "Timer2Pct", "%")
   insertSp(tt, -1, 9, "P_ControlP1", "P1", "")
   insertSp(tt, -1,10, "P_ControlP2", "P2", "")
   insertSp(tt, -1,11, "P_ControlP3", "P3", "")
   insertSp(tt, -1,12, "P_ControlP4", "P4", "")
   insertSp(tt, -1,13, "TG_Remaining", "TG_R", "s")
   insertSp(tt, -1,14, "TG_Elapsed", "TG_E", "s")         

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

local function serialWrite(port, ...)
   local arg = {...}
   local cc, err
   cc, err = serial.write(port, table.unpack(arg))

   if not cc then
      print("DFM-HUD: serial write error " .. err)
   else
      serialBytesSent = serialBytesSent + cc
   end

   return cc
end

local function setpNT()
      local sw = system.getInputsVal(switchItems.pageChange) or -1
      local pp = sw + 2 -- -1, 0, 1 --> 1,2,3
      pp = math.min(pp, pageMax)
      pageNumberTele = pp
end

local function ALColor(color) 
      serial.write(sidSerial, 0xFF, 0x30, 0x00, 0x06, color & 0xF, 0xAA)
end

local function ALColorBlack()
  ALColor(0x00);
end

local function ALColorGray()
  ALColor(0x08);
end

local function ALColorWhite() 
  ALColor(0xFF);
end

local function ALHold()
   serial.write(sidSerial, 0xFF, 0x39, 0x00, 0x06, 0x00, 0xAA)
end

local function ALFlush(wait)
   --how to implement waitReply .. talk to RFM
   serial.write(sidSerial, 0xFF, 0x39, 0x00, 0x06, 0x01, 0xAA)
end

local function ALDrawRect(x0, y0, x1, y1, rCode, wait)
  
   -- {0xFF, 0x33, 0x00, 0xLL, x0_u, x0_l, x1_u, y1_k, valX_u, valX_l, valY_u, valY_l, 0xAA}
   --     1     2     3     4     5     6     7     8       9      10      11      12    13
   -- rCode 0X33 for empty rect
   -- rCode 0X34 for filled rect
   local pattern = ">BBBI1I2I2I2I2B"
   local len = string.packsize(pattern)
   serial.write(sidSerial,string.pack(pattern, 0xFF, rCode, 0x00, len, x0, y0, x1, y1, 0xAA))
   return (len);
end

local function ALDrawText(str, fontHeight, xp, yp, wait) 

   --{0xFF, 0x37, 0x00, 0xLL, valX_u, valX_l, valY_u, valY_l, 0x04, 0x05, 0x0F, str, 0xAA}
   --    0     1     2     3       4       5       6       7     8     9   10  
   -- Fixed part of the 0x37 draw text command is 11 elements
  
   local textDir = 4 -- left to right (AL doc section 5.7)
   local textColor = 0x0F -- AL specs all text to be black

   -- we have preloaded font sizes of 16, 26 and 36 in Roboto-light
   -- with codes 4, 6 and 5 respectively
   
   local fontCode

   if fontHeight == 16 then
      fontCode = 4
   elseif fontHeight == 26 then
      fontCode = 6
   elseif fontHeight == 36 then
      fontCode = 5
   else
      fontCode = 0
   end
   
   local pattern = string.format(">BBBI1I2I2I1I1I1c%dB", #str)
   local len = string.packsize(pattern)
   local ps = string.pack(pattern, 0xFF, 0x37, 0x00, len, xp, yp, textDir, fontCode,
			  textColor, str, 0xAA)
   serial.write(sidSerial,ps)
   print("ALDrawText", str, fontHeight, fontCode, xp, yp)
   --local ss=""
   --for i=1,#ps,1 do
   --   ss = ss .. string.format("%02X ", string.byte(ps, i))
   --end
   --print(ss)
   
   return len
end

--sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, arcStart, arcErase, thk);

local function ALDrawArc(x, y, r, arcS, arcE, thk)

   --0xFF, 0x3C, 0x00, 0x0F, x_u, x_l, y_u, y_l, r, as_u, as_l, ae_u, ae_l, thk, 0xAA
   --   0     1     2     3    4    5    6    7  8     9     A     B     C    D     E

   local arcStart, arcEnd

   if arcS - arcE > 0 then
      arcStart = arcE
      arcEnd = arcS
   else
      arcStart = arcS
      arcEnd = arcE
   end
   if (arcStart == arcEnd) then
      arcEnd = arcEnd + 1
   end

   local pattern = ">BBBI1I2I2I1i2i2I1B"
   local len = string.packsize(pattern)
   --print("ALDrawArc len, r, thk", len, r, thk, arcStart, arcEnd)
   serial.write(sidSerial, string.pack(pattern, 0xFF, 0x3C, 0x00, len, x, y, r,
				       arcStart, arcEnd, thk, 0xAA))
end


local function encdp(dp, val)
   if dp == 2 then
      return string.format("%.2f", val)
   elseif dp == 1 then
      return string.format("%.1f", val)
   else
      return string.format("%.0f", val)
   end
end

local function RLwid(str, font)
   return math.floor( (20/36) * font * #str + 0.5 )
end

local arcAnglePrev = {0,0,0,0}
local arcFirstTime = {0,0,0,0}
local arcAngle = {0,0,0,0}
local arcReset = 1

local function arcGauge(seq, reset, x0, y0, x, y, nv, xv, lbl, val, val2,
			as, ae, mk, dd, xlbl, ylbl, width, rIn, rOut,
			xlmin, ylmin, xlmax, ylmax)

   local pct, markPct, ipct10
   local markAngle
   local arcStart = as
   local arcEnd = ae
   local thk = rOut - rIn
   local sinM, cosM
   local xm1, ym1, xm2, ym2
   local lblX, lblY
   local valText
   local valX, valY
   local minText
   local xlMin, xlMax
   local maxText
   local ylMin, ylMax
   local valaX, valaY
   local valbX, valbY
   local arcErase

   serialWriteCount = 0
   local now = system.getTimeCounter()
   
   --print("ag", seq, x0, y0, x, y)
   --print(nv, xv, lbl, val, val2)
   --print(as, ae, mk, dd, xlbl, ylbl, width)

   reset = arcReset
   if reset == 1 then
      arcFirstTime[seq] = 1
      arcReset = 0
   end
   
   pct = (val - nv) / (xv - nv)
   markPct = (mk - nv) / (xv - nv)
   ipct10 = math.floor(pct * 1000)

   arcAngle[seq] = arcStart + pct * (arcEnd - arcStart)
   markAngle = arcStart + markPct * (arcEnd - arcStart)

   arcStart = arcStart - 90
   arcAngle[seq] = arcAngle[seq] - 90

   sinM = math.sin(math.rad(markAngle))
   cosM = math.cos(math.rad(markAngle))
   
   xm1 = x + x0 - sinM * (rIn - thk/4)
   ym1 = y + y0 + cosM * (rIn - thk/4)
   xm2 = x + x0 - sinM * rOut * 1.25
   ym2 = y + y0 + cosM * rOut * 1.25

   lblX = xlbl + x + RLwid(lbl, 16) / 2
   lblY = ylbl + y + 16 / 2

   valText = encdp(dd, val)
   
   valX = xlbl + x + RLwid(valText, 26) / 2
   valY = y + y0 + 26/2

   minText = encdp(dd, nv)
   xlMin = xlmin
   ylMin = ylmin
   xlMin = xlMin + x + RLwid(minText, 16) / 2
   ylMin = ylMin + y + 16 / 2

   maxText = encdp(dd, xv)
   xlMax = xlmax
   ylMax = ylmax
   xlMax = xlMax + x + RLwid(maxText, 16) / 2
   ylMax = ylMax + y + 16 / 2   

   valaX = x
   valaY = y + y0 + 18

   valbX = x + width
   valbY = y + y0 - 18

   --****

   if ( (arcFirstTime[seq] ==  1) or arcAnglePrev[seq] ~= arcAngle[seq]) then

    if (arcFirstTime[seq] == 1) then
      arcFirstTime[seq] = 0;

      ALDrawText(lbl, 16, lblX, lblY, false)
      --pRemActiveLookRxChar->writeValue(drawLbl, sizeofLbl, false);
      
      ALDrawText(minText, 16, xlMin, ylMin, false)
      --pRemActiveLookRxChar->writeValue(drawMin, sizeofMin, false);

      ALDrawText(maxText, 16, xlMax, ylMax, false)
      --pRemActiveLookRxChar->writeValue(drawMax, sizeofMax, false);
    end

    ALHold()
    --pRemActiveLookRxChar->writeValue(hold, sizeof(hold), true);

    --//Serial.printf("drawColorBlack\n");
    --pRemActiveLookRxChar->writeValue(drawColorBlack, sizeof(drawColorBlack), false);
    ALColorBlack()

    --local function ALDrawRect(x0, y0, x1, y1, rCode, wait)
    ALDrawRect(valaX, valaY, valbX, valbY, 0x34, false)
    --pRemActiveLookRxChar->writeValue(drawBox, sizeof(drawBox), false);

    arcErase = arcAnglePrev[seq];
    if (arcErase == arcStart) then
      arcErase = arcErase + 1;
    end
    
    --sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, arcStart, arcErase, thk);
    ALDrawArc(x + x0, y + y0, rOut, arcStart, arcErase, thk)
    --pRemActiveLookRxChar->writeValue(drawArc, sizeofArc, true);
    --Serial.printf("black arc %d %d\n", arcStart, arcErase);
    
    --Serial.printf("drawColorWhite\n");
    ALColorWhite()
    --pRemActiveLookRxChar->writeValue(drawColorWhite, sizeof(drawColorWhite), false);

    if (arcAngle[seq] == arcStart) then
       ALDrawArc(x + x0, y + y0, rOut, arcStart, arcAngle[seq] + 1, thk)
       --sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, arcStart, arcAngle[seq] + 1, thk);  
    else
       ALDrawArc(x + x0, y + y0, rOut, arcStart, arcAngle[seq], thk)
      --sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, arcStart, arcAngle[seq], thk);  
    end

    --pRemActiveLookRxChar->writeValue(drawArc, sizeofArc, true);
    
    if ( (markPct > 0.0) and (markPct < 1.0) ) then
       --while (controlState > 1);
       --ALDrawLine(xm1, ym1, xm2, ym2, false);
      --ALDrawCircF(xm1, ym1, thk/2, false);
      --Serial.printf("markAngle %d thk %d\n", markAngle, thk);
      if (markPct > pct) then
	 --sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, (markAngle - 2) - 90, (markAngle + 2) - 90, thk);
	 ALDrawArc(x + x0, y + y0, rOut, (markAngle - 2) - 90, (markAngle + 2) - 90, thk)
	 --pRemActiveLookRxChar->writeValue(drawArc, sizeofArc, true);      
      else
	 ALDrawBlack()
	 --pRemActiveLookRxChar->writeValue(drawColorBlack, sizeof(drawColorBlack), false);
	 --sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, (markAngle - 2) - 90, (markAngle + 2) - 90, thk);
	 ALDrawArc(x + x0, y + y0, rOut, (markAngle - 2) - 90, (markAngle + 2) - 90, thk)
        --pRemActiveLookRxChar->writeValue(drawArc, sizeofArc, true);
	 ALDrawWhite()
	 --pRemActiveLookRxChar->writeValue(drawColorWhite, sizeof(drawColorWhite), false);
      end

      --while (controlState > 1);
      --pRemActiveLookRxChar->writeValue(drawArc, sizeofArc, false);
      --Serial.printf("white arc %d %d\n", arcStart, arcAngle);
    end

    ALDrawText(valText, 26, valX, valY, false)
    --pRemActiveLookRxChar->writeValue(drawVal, sizeofVal, false);
    
    --flush pending writes
    --Serial.printf("flush\n");
    ALFlush(true)
    --pRemActiveLookRxChar->writeValue(flush, sizeof(flush), true);

   end
   
   arcAnglePrev[seq] = arcAngle[seq]
   --print("arcgauge delta t", (system.getTimeCounter() - now))
   --****
   print("serialWriteCount", serialWriteCount)
end

local function encodeBuf(str)
   local ret
   ret = str:gsub("(%x%x)", (function(s) return string.char(tonumber(s,16)) end))
   --[[
   local ss = ""
   for i=1,#ret,1 do
      ss = ss .. string.format("%02X ", string.byte(ret, i))
   end
   print("encodebuf==>"..ss)
   --]]
   return ret
end


local function sendAL(j2)

   local gpp
   local ccfg, cid, fid, fmt
   local min, max
   local xr, yr
   local xc, yc
   local x0, y0
   local mk
   local dd
   local val, val2
   local xlbl, ylbl
   local width
   local xlmin, ylmin
   local xlmax, ylmax
   local lbl
   --
   -- REMINDER: USE cfgimgESP table to send to the glasses!!!
   --
   
   gpp = Glass.page[pageNumberTele]
   if not gpp then
      print("sendAL: Glass.page[pageNumberTele] is nil")
      return
   end
   
   if not gpp[1].fmtNumber then gpp[1].fmtNumber = 1 end
   fmt = gpp[1].fmtNumber --  string.format("p%d", gpp[1].fmtNumber)
   local ccf =  cfgimgESP.config[fmt]
   
   for g,t in ipairs(gpp) do        -- loop over all gauges on this page with a valid imageID
      --[[
	 if g <= 3  then
	 print("g, t.widgetID, t.imageID", g, t.widgetID, t.imageID)
      end
      --]]
      if t.widgetID > 0 and t.imageID >= 0 then        -- if there is a value to animate
	 ccfg = ccf[g]                 -- this is the "config" key for this page and this widget
	 cid = cfgimgESP.instruments[t.widgetID]
	 fid = cid.formID + 1
	 --print("fid", fid)
	 xr = ccfg.xlr
	 yr = ccfg.ylr
	 width = ccfg.width
	 xc = xr + cfgimgESP.forms[fid].x0           -- for gauge, this is the pivot pt of the needle
	 yc = yr + cfgimgESP.forms[fid].y0

	 x0 = cfgimgESP.forms[fid].x0
	 y0 = cfgimgESP.forms[fid].y0

	 mk = t.marker
	 if t.dispdec then
	    dd = t.dispdec
	 else
	    dd = t.decimals
	 end
	 xlbl = cfgimgESP.forms[fid].xlbl
	 ylbl = cfgimgESP.forms[fid].ylbl
	 xlmin = cfgimgESP.forms[fid].xlmin
	 ylmin = cfgimgESP.forms[fid].ylmin
	 xlmax = cfgimgESP.forms[fid].xlmax
	 ylmax = cfgimgESP.forms[fid].ylmax	 	 
	 
	 if true then --t.value then
	    -- if scale "fixed" then scale comes from images, else from 200ms json
	    if cid.scale and cid.scale == "fixed" then
	       min = cid.minV
	       max = cid.maxV
	    else  -- be defensive in case of missing minV/maxV
	       --print(t.minV, cid.minV, t.maxV, cid.maxV)
	       if not t.minV then
		  if cid.minV then min = cid.minV else min = 0 end
	       else
		  min = t.minV
	       end
	       if not t.maxV then
		  if cid.maxV then max = cid.maxV else max = 1 end
	       else
		  max = t.maxV
	       end
	       
	       --min = t.minV or 0
	       --max = t.maxV or 1
	    end
	    lbl = t.instName or "..." --.instName is named .label in the 200ms json 
	    val = t.value
	    val2 = t.value2
	    local reset = 0
	    --print(g, cid.wtype,t.widgetID)
	    if cid.wtype == "oldgauge" then
	    elseif cid.wtype == "gauge" then
	    elseif cid.wtype == "gNew" then
	    elseif cid.wtype == "compass" then
	    elseif cid.wtype == "hbar" then
	    elseif cid.wtype == "vbar" then
	    elseif cid.wtype == "htext" then
	    elseif cid.wtype == "timer" then
	    elseif cid.wtype == "arcGauge" then
	       
	       --[[
		  elseif cid.wtype == "arcGauge" then
		  if val then
		  local minA = cfgimg.forms[fid].arcStart --22.5 * (cfgimg.forms[fid].arcStart - 9)
		  local maxA = cfgimg.forms[fid].arcEnd--22.5 * (cfgimg.forms[fid].arcEnd - 8)
		  drawArcGauge(offset + r * xc, r * yc, minA, maxA,
		  min, max, val, r*cfgimg.forms[fid].radiusOut,
		  r*cfgimg.forms[fid].radiusIn)
		  -- center value at same point as label, not pivot pt (because of half arcs)
		  drawTextCenter(offset + xr * r + r * cfgimg.forms[fid].xlbl,
		  r * yc,
		  svv(t.decimals, val), FONT_BIG)
		  end
		  
		  
	       --]]
	       local as = cfgimgESP.forms[fid].arcStart
	       local ae = cfgimgESP.forms[fid].arcEnd
	       local rIn = cfgimgESP.forms[fid].radiusIn
	       local rOut = cfgimgESP.forms[fid].radiusOut
	       arcGauge(g, reset, x0, y0, xr, yr, min, max, lbl, val, val2,
			as, ae, mk, dd, xlbl, ylbl, width, rIn, rOut, xlmin, ylmin, xlmax, ylmax)
	    elseif cid.wtype == "ahGauge" then
	    elseif cid.wtype == "vltape" then
	    end
	 end
      end
   end
end


local lastSend = 0
local linecount = 0

local function loop()
   local now = system.getTimeCounter()
   local unow = system.getTimeCounter()
   local sensor, sval, sval2
   local stbl = {}
   -- temporarily made global -- local gtbl = {}
   local dbstbl = {}
   local dbgtbl = {}
   local av
   local scale
   local minV, maxV, lbl
   local LOOPTIME = 250
   local CTRLREP = 5
   local SEND_DELAY = 50 --10
   local BUF_SIZE = 64
   local SEND_LOOPS = 2 --20


   --if true then return end -- ********************************************************************************
   
   if otaTimer ~= 0 and now > otaTimer then
      otaTimer = 0
      gpio.write(5,0)
      print("gpio 5 cleared")
   end

   if restartTimer ~= 0 and now > restartTimer then
      restartTimer = 0
      gpio.write(6,0)
      print("gpio 6 cleared")
   end
   
   if powerDownTimer ~= 0 and now > powerDownTimer then
      powerDownTimer = 0
      gpio.write(7,1)
      print("gpio 7 set high")
   end

   if Glass.var.statusAL and Glass.var.statusAL.Conn and Glass.var.statusAL.Conn == 1 and
      Glass.var.statusAL.Conf == Glass.var.statusAL.GlassConf and matchConfigID() then
      --and system.getTimeCounter() < Glass.var.statusTime + 3000 then
      wasEverGreen = true
   end

   --[[
   -- we perform writeInst() to send the json for the selected pages at init() time, but it can
   -- sometimes get missed if the ESP is busy .. send once more 10s after init
   if initTime ~= 0 and system.getTime() > initTime + 10 then
      --print("10s writeInst")
      writeInst()
      initTime = 0
   end
   --]]
   if system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
   end
   
   if switchItems.pageChange then
     setpNT()
      --local sw = system.getInputsVal(switchItems.pageChange)
      --local pp = sw + 2 -- -1, 0, 1 --> 1,2,3
      --pp = math.min(pp, pageMax)
      --pageNumberTele = pp
   end

   local gs = Glass.settings
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      local temp
      temp = Glass.curPos
      Glass.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      if Glass.curPos and temp then
	 if gps.getDistance(temp, Glass.curPos) > 5 then --5m dist min to compute heading
	    Glass.lastPos = temp
	 end
      end
      local lt, lg = 0, 0
      if Glass.curPos then lt, lg = gps.getValue(Glass.curPos) end
      if Glass.curPos and lt ~= 0 and lg ~= 0 and not Glass.initPos then
	 Glass.gpsReads = Glass.gpsReads + 1
      end
      if Glass.gpsReads > 9 and not Glass.initPos then
	 system.messageBox("GPS zero point set")
	 Glass.initPos = Glass.curPos
	 if not Glass.zeroPos then Glass.zeroPos = Glass.curPos end
      end
   end

   local gt = Glass.timers
   local si, ud1, ud2
   local now = system.getTimeCounter()

   if (gt.timer1.target or 0) - (gt.timer1.initial or 0) < 0 then
      ud1 = "down"
   else
      ud1 = "up"
   end

   if switchItems.t1enable then
      si = system.getSwitchInfo(switchItems.t1enable)      
      if si and si.value == 1 then 
	 if gt.timer1.state == gt.stateSTOP then --prior sw position
	    if ud1 == "up" then
	       gt.timer1.start = now - gt.timer1.time
	    else
	       gt.timer1.start = now + gt.timer1.time
	    end
	 end
	 gt.timer1.state = gt.stateRUN
      else
	 gt.timer1.state = gt.stateSTOP
      end
   end

   if switchItems.t1reset then
      si = system.getSwitchInfo(switchItems.t1reset)
      if si and si.value == 1 then 
	 gt.timer1.time = gt.timer1.initial
      end
   end
   
   if (gt.timer2.target or 0) - (gt.timer2.initial or 0) < 0 then
      ud2 = "down"
   else
      ud2 = "up"
   end

   if switchItems.t2enable then
      si = system.getSwitchInfo(switchItems.t2enable)
      if si and si.value == 1 then -- current sw position
	 if gt.timer2.state == gt.stateSTOP then --prior sw position
	    if ud2 == "up" then
	       gt.timer2.start = now - gt.timer2.time
	    else
	       gt.timer2.start = now + gt.timer2.time
	    end
	 end
	 gt.timer2.state = gt.stateRUN
      else
	 gt.timer2.state = gt.stateSTOP
      end
   end

   if switchItems.t2reset then
      si = system.getSwitchInfo(switchItems.t2reset)      
      if si and si.value == 1 then
	 gt.timer2.time = gt.timer2.initial
      end
   end

   if sendState == state.COMPLETE and system.getTimeCounter() > jsonHoldTime then
      if pageMax > 0 and (now > lastWrite + LOOPTIME) then

	 if Glass.curPos and Glass.zeroPos then
	    Glass.gpsBearingFrom = gps.getBearing(Glass.curPos, Glass.zeroPos)
	    Glass.gpsBearingTo = gps.getBearing(Glass.zeroPos, Glass.curPos)	    
	    Glass.gpsDistance = gps.getDistance(Glass.curPos, Glass.zeroPos)
	    --print("#", Glass.lastPos)
	    if Glass.lastPos then
	       Glass.gpsHeading = gps.getBearing(Glass.lastPos, Glass.curPos)
	       --print("heading, bearing", Glass.gpsHeading, Glass.gpsBearingTo)
	    end
	 end
	 
	 --local p1 = math.floor(255 * (1 + system.getInputs("P1")) / 2)
	 --local p2 = math.floor(255 * (1 + system.getInputs("P2")) / 2)

	 if (not switchItems.pageChange) then pageNumberTele = pageNumber end

	 if not pageNumberTele or pageNumberTele < 1 then return end
	 if not Glass.page[pageNumberTele] then return end


	 stbl = {page=pageNumberTele}

	 gtbl = {}
	 gtbl.v = {}
	 gtbl.v2 = {}
	 gtbl["pg"] = pageNumberTele 
	 gtbl["cfg"] = Glass.page[pageNumberTele][1].fmtNumber - 1 --  convert lua convention to c++

	 dbgtbl = {}
	 dbgtbl["p"] = pageNumberTele
	 
	 for k,v in ipairs(Glass.page[pageNumberTele]) do
	    if v.imageID and v.imageID >= 0 then
	       if not v.imageID then print("imageID nil:", k, v.imageID) end
	       if v.imageID >= 0 then
		  if cfgimg.instruments[v.widgetID].scale ~= "fixed" then
		     scale = "variable"
		  else
		     scale = "fixed"
		  end
		  if scale == "variable" then -- if min/max not set pick up defaults
		     minV = v.minV or cfgimg.instruments[v.widgetID].minV
		     maxV = v.maxV or cfgimg.instruments[v.widgetID].maxV
		  else
		     minV = cfgimg.instruments[v.widgetID].minV
		     maxV = cfgimg.instruments[v.widgetID].maxV 
		  end
	       end
	       local now = system.getTimeCounter()
	       v.value = nil
	       sensor = {}
	       if (v.sensorId ~= 0) and (v.sensorPa ~= 0) then
		  if v.sensorId == -1 then -- special sensors, derived values
		     --print("v1 sensorPa", v.sensorPa)
		     if v.sensorPa == 1 then
			if Glass.gpsDistance then
			   sensor.valid = true
			   sensor.value = Glass.gpsDistance
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa == 2 or v.sensorPa == 3 or v.sensorPa == 4 then -- bearing to or from 
			if Glass.gpsBearingTo and v.sensorPa == 2 then--                  or heading
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingTo
			elseif Glass.gpsBearingFrom and v.sensorPa == 3 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingFrom
			elseif Glass.gpsHeading and v.sensorPa == 4 then
			   sensor.valid = true
			   sensor.value = Glass.gpsHeading
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa == 5 or v.sensorPa == 7 then -- t1sec and t1pct
			if Glass.timers.timer1.state == Glass.timers.stateSTOP then
			   if ud1 == "up" then
			      Glass.timers.timer1.start = now - Glass.timers.timer1.time
			   else
			      Glass.timers.timer1.start = now + Glass.timers.timer1.time
			   end
			end
			if ud1 == "up" then
			   Glass.timers.timer1.time = (now - Glass.timers.timer1.start)
			   sensor.tpct = 100 * Glass.timers.timer1.time /
			      (Glass.timers.timer1.target - Glass.timers.timer1.initial)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			else
			   Glass.timers.timer1.time = (Glass.timers.timer1.start - now)
			   sensor.tpct = 100 * Glass.timers.timer1.time /
			      (Glass.timers.timer1.initial - Glass.timers.timer1.target)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			end
			if v.sensorPa == 5 then
			   sensor.value = math.floor(100 * Glass.timers.timer1.time / 1000) / 100
			else
			   sensor.value = (sensor.tpct or 0)
			end

			sensor.valid = true
		     elseif v.sensorPa == 6 or v.sensorPa == 8 then --t2sec and t2pct
			if Glass.timers.timer2.state == Glass.timers.stateSTOP then
			   if ud2 == "up" then
			      Glass.timers.timer2.start = now - Glass.timers.timer2.time
			   else
			      Glass.timers.timer2.start = now + Glass.timers.timer2.time
			   end
			end
			if ud2 == "up" then
			   Glass.timers.timer2.time = (now - Glass.timers.timer2.start)
			   sensor.tpct = 100 * Glass.timers.timer2.time /
			      (Glass.timers.timer2.target - Glass.timers.timer2.initial)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			else
			   Glass.timers.timer2.time = (Glass.timers.timer2.start - now)
			   sensor.tpct = 100 * Glass.timers.timer2.time /
			      (Glass.timers.timer2.initial - Glass.timers.timer2.target)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			end
			if v.sensorPa == 6 then
			   sensor.value = math.floor(100 * Glass.timers.timer2.time / 1000) / 100
			else
			   sensor.value = (sensor.tpct or 0)
			end
			sensor.valid = true
		     elseif v.sensorPa == 9 then
			sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P1")) / 2
			sensor.valid = true
		     elseif v.sensorPa == 10 then
			sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P2")) / 2
			sensor.valid = true
		     elseif v.sensorPa == 11 then
			sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P3")) / 2
			sensor.valid = true
		     elseif v.sensorPa == 12 then
			sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P4")) / 2
			sensor.valid = true
		     elseif v.sensorPa == 13 and sharedVar["DFM-TimG"] then -- remaining time
			sensor.value = sharedVar["DFM-TimG"].remaining or 0
			sensor.valid = true
		     elseif v.sensorPa == 14 and sharedVar["DFM-TimG"] then -- elapsed time
			sensor.value = sharedVar["DFM-TimG"].elapsed or 0
			sensor.valid = true
		     end
		  else
		     sensor = system.getSensorByID(v.sensorId, v.sensorPa)
		  end
		  if sensor and sensor.valid then
		     v.value = sensor.value
		     --print("v.value", v.value)
		     if v.convertIdx then
			--print("v.convertIdx", v.convertIdx, Glass.convertVal[v.convertIdx])
			v.value = v.value * Glass.convertVal[v.convertIdx][1] +
			   Glass.convertVal[v.convertIdx][2]
		     end
		     if not v.value then print("v.value nil") end
		  end
	       end

	       v.value2 = nil -- value2 can only be for compass or ahGauge now...
	       sensor = {}
	       --print("v.sensorId2, v.sensorPa2", v.sensorId2, v.sensorPa2)
	       if v.sensorId2 and v.sensorId2 ~= 0 and v.sensorPa2 and v.sensorPa2 ~= 0 then
		  if v.sensorId2 == -1 then -- special sensors, derived values
		     --print("v2 sensorPa2", v.sensorPa2)
		     if v.sensorPa2 == 1 then
			--print(Glass.gpsDistance)
			if Glass.gpsDistance then
			   sensor.valid = true
			   sensor.value2 = Glass.gpsDistance
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa2 == 2 or v.sensorPa2 == 3 or v.sensorPa2 == 4 then
			if Glass.gpsBearingTo and v.sensorPa2 == 2 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingTo
			elseif Glass.gpsBearingFrom and v.sensorPa2 == 3 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingFrom
			elseif Glass.gpsHeading and v.sensorPa2 == 4 then
			   --print("v.sensorPa2", v.sensorPa2, Glass.gpsHeading)
			   sensor.valid = true
			   sensor.value = Glass.gpsHeading
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa2 == 9 then
			sensor.value = 45 * system.getInputs("P1")
			sensor.valid = true
		     elseif v.sensorPa2 == 10 then
			sensor.value = 45 * system.getInputs("P2")
			sensor.valid = true
		     elseif v.sensorPa2 == 11 then
			sensor.value =  1 + system.getInputs("P3")
			sensor.valid = true
		     elseif v.sensorPa2 == 12 then
			sensor.value = 50 * (1 + system.getInputs("P4"))
			sensor.valid = true
		     end
		     if sensor and sensor.valid then
			v.value2 = sensor.value
			--print("v.value2", v.value2)
		     end
		  else
		     sensor = system.getSensorByID(v.sensorId2, v.sensorPa2)
		     if sensor and sensor.valid then
			v.value2 = sensor.value
			--print("v.value2", v.value2)
		     end
		  end
	       end

	       
	       sval = sv(v.decimals, v.value)
	       sval2 = sv(v.decimals2, v.value2)
	       
	       if v.imageID >= 0 then
		  stbl[k] = {}
		  dbstbl[k] = {}
		  dbstbl[k].id = v.widgetID - 1
		  dbstbl[k].loc = cfgimg.lenmap[Glass.page[pageNumberTele][1].fmtNumber][k] - 1
		  stbl[k].im = v.imageID
		  stbl[k].wd = v.widgetID - 1
		  stbl[k].fm = cfgimg.instruments[v.widgetID].formID
		  stbl[k].wt = string.sub(cfgimg.instruments[v.widgetID].wtype,0,2)
		  if sval then
		     stbl[k].v = tonumber(sval)
		     dbstbl[k].v = tonumber(sval)
		     if cfgimg.instruments[v.widgetID].wtype == "htext" then
			stbl[k].u = Glass.page[pageNumberTele][k].units
			dbstbl[k].u = Glass.page[pageNumberTele][k].units
			
			stbl[k].d = Glass.page[pageNumberTele][k].decimals
			dbstbl[k].d = Glass.page[pageNumberTele][k].decimals
			stbl[k].l=Glass.page[pageNumberTele][k].instName
			dbstbl[k].l=Glass.page[pageNumberTele][k].instName			
		     elseif cfgimg.instruments[v.widgetID].wtype == "arcGauge" then

			stbl[k].d = Glass.page[pageNumberTele][k].decimals
			dbstbl[k].d = Glass.page[pageNumberTele][k].decimals
			
		     elseif cfgimg.instruments[v.widgetID].wtype == "timer" then
			stbl[k].u = ""
			dbstbl[k].u = ""			
			stbl[k].l = Glass.page[pageNumberTele][k].instName
			dbstbl[k].l = Glass.page[pageNumberTele][k].instName
		     else
			stbl[k].u = nil
			dbstbl[k].u = nil			
		     end
		  end
		  if sval and sval2 then
		     stbl[k].v2 = tonumber(sval2)
		     dbstbl[k].v2 = tonumber(sval2)
		  end
		  if scale == "variable" and sval then
		     stbl[k].nV = tonumber(sv(2, minV))
		     dbstbl[k].nV = tonumber(sv(2, minV))

		     stbl[k].xV = tonumber(sv(2, maxV))
		     dbstbl[k].xV = tonumber(sv(2, maxV))

		     stbl[k].l = Glass.page[pageNumberTele][k].instName
		     dbstbl[k].l = Glass.page[pageNumberTele][k].instName
		     
		     -- not yet in db info
		     stbl[k].mJ = Glass.page[pageNumberTele][k].major
		     stbl[k].mN = Glass.page[pageNumberTele][k].minor		     
		     stbl[k].f = Glass.page[pageNumberTele][k].fine
		     stbl[k].fM = Glass.page[pageNumberTele][k].ticfmt		     
		  end
	       end
	       gtbl.v[k] = tonumber(sval) or 0 -- avoid json "null" for unset v[]
	       gtbl.v2[k] = tonumber(sval2) or 0 -- avoid json "null" for unset v2[]
	    end

	    dbgtbl["w"] = {}
	    for kk,vv in ipairs(dbstbl) do
	       dbgtbl["w"][kk] = vv
	    end
	    dbgtbl["n"] = #dbstbl
	 end

	 gtbl["n"] = #stbl

	 -- if we don't match the glasses config, or there is a menu open don't
	 -- send the 200 ms json

	 local sendJson = true
	 if not Glass.var.statusAL then
	    --print("not statusAL")
	    sendJson = false
	 else
	    if Glass.var.statusAL.Conn == 0 then
	       --print(".Conn is 0")
	       sendJson = false
	    end
	    if Glass.var.statusAL.Conf ~= Glass.var.statusAL.GlassConf then
	       --print(".Conf ~=")
	       sendJson = false
	    end 
	    if not matchConfigID() then
	       --print("not matchConfigID")
	       sendJson = false
	    end
	    if form.getActiveForm() then
	       --print("getActiveForm")
	       sendJson = false
	    end
	 end
	 
	 local swb = system.getInputs("SB") -- SB to force sending only on emulator

	 --print("swb, sendJson", swb, sendJson)
	 
	 if sendJson or (emflag ~= 0 and swb and swb == 1) then
	    
	    if emflag ~= 0 then
	       local swa = system.getInputs("SA") -- SA to show json only on emulator
	       if swa and swa == 1 then
		  print(espjson)
	       end
	    end
	    --local count = serial.write(sidSerial, espjson, "\n")
	    if system.getTimeCounter() - lastSend > (1*LOOPTIME) then
	       print("=================> sendAL")
	       sendAL(gtbl)
	       lastSend = system.getTimeCounter()
	    end
	    

	    
	    --*********************************local count = serial.write(sidSerial, binser, "\n")
	    --print("count, out", count, out)
	 end
	 lastWrite = now
      end

   end

   if unow <= jsonHoldTime then return end

   if sendState == state.DISCONNECTED then
      print("disconnected, sending config request")
      bw = serialWrite(sidSerial, 0xFF, 0xD3, 0x02, 0x07, 0x01, 0x01, 0xAA) -- read config
      if not bw then
	 print("DFM-HUD: cannot write config query")
	 jsonHoldTime = unow + 1000
      end
      print("set state to WAITING")
      sendState = state.WAITING -- wait for onRead to get config list
   end

   if sendState == state.WAITING then
      --just spin, when config is available, sendState will be set to CONNECTED
      --print("sendState WAITING")
   end
   
   if sendState == state.CONNECTED then 
      if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
      sendFP = io.open(prefix() .. pathConfigs .. "config-fonts.txt", "r")
      if not sendFP then
	 print("Glass: cannot open font config")
	 sendState = state.DISCONNECTED
	 jsonHoldTime = unow + 1000
      else
	 print("opened config-fonts-break.txt")
	 sendState = state.SENDHEADER
      end
      linecount = 0
      serialBytesSent = 0
      startingTime = system.getTimeCounter()
   end
   
   if (sendState == state.SENDHEADER) or (sendState == state.SENDFOOTER) then
      
      --[[
	 config.txt formatting overview
	 
	 "FFD0001561766961746F72000000000000000001AA" config header for "aviator" with 0 version, key 1
	 "FF51...AA" fonts (many lines)
	 "FF41...AA" images (many lines)
	 "FFD0001561766961746F72000000000200000001AA" config footer for "aviator" with version 2, key 1
	 "FFD2000D61766961746F7200AA" config set to "aviator"
	 
	 --"FF460006FFAA" delete all images -- this is now done in the config-fonts.json file
	 
      --]]
      
      if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
      
      local cfgVersion = 1
      local cfgKey = 1
      local bufPre = "FFD0001561766961746F7200"
      local bufSet = "FFD2000D61766961746F7200AA"
      local bufH = bufPre .. string.format("%08X%08X", 0, cfgKey) .. "AA"
      local bufF = bufPre .. string.format("%08X%08X", cfgVersion, cfgKey) .. "AA"
      local bw
            
      if sendState == state.SENDHEADER then
	 print("sending header")
	 bw = serialWrite(sidSerial, encodeBuf(bufH))
	 --bw = serial.write(sidSerial,0xFF, 0xD0,  0x00, 0x15, 0x61, 0x76, 0x69, 0x61, 0x74, 0x6F, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0xAA)
	 if not bw then
	    print("DFM-HUD: cannot write header")
	    io.close(sendFP)
	    sendState = state.DISCONNECTED
	    jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
	 else
	    sendState = state.SENDFILE
	 end
      end

      if sendState == state.SENDFOOTER then
	 print("DFM-HUD: Sending config footer")
	 bw = serialWrite(sidSerial, encodeBuf(bufF))
	 --bw = serial.write(sidSerial, encodeBuf(bufSet))
	 if not bw then
	    print("DFM-HUD: cannot write footer")
	    io.close(sendFP)
	    sendState = state.DISCONNECTED
	    jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
	 else
	    print("set state to COMPLETE")
	    sendState = state.COMPLETE
	 end
	 
	 local dt = system.getTimeCounter() - startingTime
	 serialFileName = string.format("Transfer complete. Time: %.2f s", dt / 1000.0)
	 print(string.format("Send config done. Time: %.2f s", dt / 1000))
	 print(string.format("%d bytes sent. Aggregate data rate: %.1f kB/s",
			     serialBytesSent, serialBytesSent / dt))
	 Glass.settings.configIDs = {}
	 for k in ipairs(currentConfigIDs) do -- remember that this config was sent last
	    Glass.settings.configIDs[k] = currentConfigIDs[k] 
	 end
	 jsonHoldTime = system.getTimeCounter() + WAIT_TIME * 40 -- long (!) wait before restarting 200ms json
	 Glass.settings.configVersion = 1
      end
   end

   local LINESPERLOOP = 1
   local line   
   if sendState == state.SENDFILE then
      --print("sendState is SENDFILE")
      
      for i=1, LINESPERLOOP, 1 do
	 line = io.readline(sendFP, true)
	 linecount = linecount + 1
	 if not line then
	    print("io,readline EOF")
	    sendState = state.SENDFOOTER
	    io.close(sendFP)
	    break
	 else
	    local ll
	    local ldx=1
	    local chunk = 100
	    repeat
	       ll = string.sub(line, ldx, ldx + chunk - 1)
	       ldx = ldx + chunk
	       --print("> "..ll)
	       bw = serialWrite(sidSerial, encodeBuf(ll))
	       --print("write encoded line, bw", bw, #line)
	    until ldx >= #line
	    
	    if not bw then
	       print("DFM-HUD: cannot write line of config file")
	       io.close(sendFP)
	       sendState = state.DISCONNECTED
	       jsonHoldTime = unow + 1000
	       break
	    end
	 end
	 jsonHoldTime = unow + 50
      end
   end
   loopCPU = loopCPU + (system.getCPU() - loopCPU) / 10
end

local function changedSensor(value, inp, sf)
   --print("changedSensor: val, inp", value, inp)
   if inp ~= 2 then
      Glass.page[pageNumber][gaugeNumber].sensorId = Glass.sensorIdlist[value]
      Glass.page[pageNumber][gaugeNumber].sensorPa = Glass.sensorPalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLa = Glass.sensorLalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLs = Glass.sensorLslist[value]
      Glass.page[pageNumber][gaugeNumber].units    = Glass.sensorUnlist[value]
      Glass.page[pageNumber][gaugeNumber].nativeUnits    = Glass.sensorUnlist[value]   
      Glass.page[pageNumber][gaugeNumber].decimals = Glass.sensorDplist[value]
      Glass.page[pageNumber][gaugeNumber].wtype     = Glass.sensorTylist[value]
   else
      Glass.page[pageNumber][gaugeNumber].sensorId2 = Glass.sensorIdlist[value]
      Glass.page[pageNumber][gaugeNumber].sensorPa2 = Glass.sensorPalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLa2 = Glass.sensorLalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLs2 = Glass.sensorLslist[value]
      Glass.page[pageNumber][gaugeNumber].units2    = Glass.sensorUnlist[value]   
      Glass.page[pageNumber][gaugeNumber].decimals2 = Glass.sensorDplist[value]
      Glass.page[pageNumber][gaugeNumber].wtype2     = Glass.sensorTylist[value]
   end
   if inp == 0 then
      Glass.page[pageNumber][gaugeNumber].sensorId2 = 0
      Glass.page[pageNumber][gaugeNumber].sensorPa2 = 0
   end
   if sf then form.reinit(sf) end
end


local function changedName(value)
   --print("changedName instName", value, "page, gauge", pageNumber, gaugeNumber)
   Glass.page[pageNumber][gaugeNumber].instName = value
end

local function clearJSON()
   local fn = prefix() .. pathJson .. "GG_" .. modelName.. ".jsn"
   local ans
   ans = form.question("Are you sure?", "Reset all app settings?",
		       "",
		       0, false, 5)
   if ans == 1 then
      io.remove(fn)
      system.messageBox("All settings deleted .. Restart App")
      writeJSON = false
   end
   
end



local inpN

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
      if  #Glass.page < 1 then
	 form.addRow(1)
	 form.addLabel({label="No pages defined"})
	 return
      end
      
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
      local widgetID = Glass.page[pageNumber][gaugeNumber].widgetID
      local imageID = Glass.page[pageNumber][gaugeNumber].imageID
      local fn = Glass.page[pageNumber][1].fmtNumber
      local wid = cfgimg.config[fn][gaugeNumber].width
      local hgt = cfgimg.config[fn][gaugeNumber].height
      local label

      --print("$ fn, gaugeNumber wid hgt", fn, gaugeNumber, wid, hgt)
      
      editImgs = {}
      for i, img in ipairs(cfgimg.instruments) do
	 --print("% i, img.origWidth, img.origHeight", i, img.origWidth, img.origHeight)
	 if (wid == img.origWidth) and (hgt == img.origHeight) then
	    table.insert(editImgs,
			 {widgetID = i, imageID=img.imageID, loadImage=img.loadImage,
			  loadImageSmaller = img.loadImageSmaller,
			  imageWidth=img.imageWidth, imageHeight = img.imageHeight,
			  wtype=img.wtype, inputs=img.inputs, scale = img.scale })
	    if widgetID == i then imageNum = #editImgs end
	 end
      end
      imageMax = #editImgs
      --print("imageMax", imageMax)
      if not imageNum then imageNum = 1 end

      -- isn't imageNum really widgetID??
      
      if widgetID <= 0 then
	 if #editImgs < 1 then
	    print("Glass: no images for", pageNumber, gaugeNumber)
	 else -- default to first image
	    --print("defaulting widgetID")
	    Glass.page[pageNumber][gaugeNumber].widgetID = editImgs[1].widgetID	    
	    Glass.page[pageNumber][gaugeNumber].imageID = editImgs[1].imageID
	    Glass.page[pageNumber][gaugeNumber].wtype = editImgs[1].wtype
	 end
      end

      local function setinp(inp, ii)
	 if ii == 0 then inpN = 0 else inpN = inp end
	 form.reinit(12)
      end
      
      inpN = 0
      local inpS
      local ii
      if not editImgs[imageNum] then return end -- only happens if no gauges match this box size - config error

      for inp=1,editImgs[imageNum].inputs do
	 if editImgs[imageNum].inputs == 1 then
	    inpS = "Data source"
	    ii = 0
	 else
	    inpS = "Data source " .. tostring(inp)
	    if editImgs[imageNum].wtype == "ahGauge" then
	       if inp == 1 then
		  inpS = "Pitch"
	       elseif inp == 2 then
		  inpS = "Roll"
	       end
	    elseif editImgs[imageNum].wtype == "compass" then
	       if inp == 1 then
		  inpS = "Bearing"
	       elseif inp == 2 then
		  inpS = "Heading"
	       end
	    end
	    ii = inp
	 end
	 form.addRow(1)
	 form.addLink((function() return setinp(inp, ii) end), {label=inpS.." >"})
      end
      if editImgs[imageNum].wtype ~= "ahGauge" and editImgs[imageNum].wtype ~= "compass" 
	 and editImgs[imageNum].scale == "variable" then
	 
	 local function changedMMscl(value)
	    --print("changeMMscl", value)
	    Glass.page[pageNumber][gaugeNumber].scl = value
	 end
	 
	 local mmscl = {"+/- 10000", "+/- 1000", "+/- 100"}
	 if not Glass.page[pageNumber][gaugeNumber].scl then
	    Glass.page[pageNumber][gaugeNumber].scl = 1
	 end
	 local iscl = Glass.page[pageNumber][gaugeNumber].scl
	 
	 form.addRow(2)
	 form.addLabel({label="Min/Max Scale>"})
	 form.addSelectbox(mmscl, iscl, true, changedMMscl)

	 form.addRow(1)
	 form.addLink((function() form.reinit(13) end), {label="Min/Max >"})

      end
      
      form.setTitle("Page " .. pageNumber .. " Gauge " .. gaugeNumber)
      
      form.setFocusedRow(1)
   elseif sf == 11 then

      form.setTitle("Utilities")
      if emflag ~= 0 then -- emulator only: button to force serial send
	 form.setButton(1, "USB",   ENABLED)
      end
      
      local function pageSwChanged(val, name)
	 local swInfo =system.getSwitchInfo(val)
	 if not swInfo.proportional then
	    system.messageBox("Please select as Proportional")
	    return
	 end
	 if not swInfo.assigned then
	    print("Sw unassigned")
	    --pageSw = nil
	    pageNumberTele = nil
	 end
	 changedSwitch(val, name)
      end
      

      local function cvchanged(val)
	 Glass.settings.configVersion = val
      end

      local latsel = 0
      local lngsel = 0
      for k = 1, #Glass.gpsLalist do
	 if (Glass.gpsIdlist[k] == Glass.settings.latId) and
	    (Glass.gpsPalist[k] == Glass.settings.latPa) then
	    latsel = k
	 end
	 if (Glass.gpsIdlist[k] == Glass.settings.lngId) and
	    (Glass.gpsPalist[k] == Glass.settings.lngPa) then
	    lngsel = k
	 end	 
      end

      form.addRow(2)
      form.addLabel({label="Page change switch"})
      swtCI.pageChange = form.addInputbox(switchItems.pageChange, true,
					  (function(x) return  pageSwChanged(x, "pageChange") end)
      )
      
      
      --form.addRow(2)
      --form.addLabel({label="Set config version"})
      --form.addIntbox(Glass.settings.configVersion, 0, 32767, 1, 0, 1, cvchanged)

      form.addRow(2)
      form.addLabel({label="GPS Lat Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.gpsLalist, latsel, true,
			(function(i)
			      Glass.settings.latId = Glass.gpsIdlist[i]
			      Glass.settings.latPa = Glass.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="GPS Lng Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.gpsLalist, lngsel, true,
			(function(i)
			      Glass.settings.lngId = Glass.gpsIdlist[i]
			      Glass.settings.lngPa = Glass.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      --form.addRow(1)
      --form.addLink((function() sendUSB() form.reinit(15) return end),
      --{label="Send config on serial>>"})

      form.addRow(1)
      form.addLink((function() form.reinit(14) return end), {label="Timer setup>>"})      

      form.addRow(1)
      form.addLink(clearJSON, {label="Reset app settings>>"})
      
      form.addRow(1)
      form.addLink((function() sendUSB("full") form.reinit(15) return end), {label="Set up AL Glasses>>"})
      form.addRow(1)
      form.addLink(
	 (
	    function()
	       otaTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       gpio.write(5,1)
	       print("gpio 5 set high")
	       system.messageBox("OTA update initialized")
	       --form.reinit(11)
	       return
	 end), {label="Start OTA update>>"}
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       restartTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       gpio.write(6,1)
	       print("gpio 6 set high")
	       system.messageBox("Rebooting AL controller")
	       --form.reinit(11)
	       return
	 end), {label="Reboot AL controller>>"}
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       powerDownTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       gpio.write(7,0)
	       print("gpio 7 set low")
	       system.messageBox("Cycling AL controller power")
	       --form.reinit(11)
	       return
	 end), {label="CyclePwr AL controller>>"}
      )

      form.addRow(2)
      form.addLabel({label="Reboot on disconnect", width=270})
      local rdIndex
      rdIndex = form.addCheckbox(Glass.settings.rebootDisco,
				 (function()
				       if not Glass.settings.rebootDisco then
					  Glass.settings.rebootDisco = true
				       else
					  Glass.settings.rebootDisco = not Glass.settings.rebootDisco
				       end
				       form.setValue(rdIndex, Glass.settings.rebootDisco)
				       print("rebootDisco", Glass.settings.rebootDisco)
				       return
				 end)
      )
      --[[
      form.addRow(1)
      form.addLink(
	 (
	    function()
	       rebootDisco = true
	       --form.reinit(11)
	       return
	 end), {label="Set reboot on disconnect>>"}
      )
      --]]
   elseif sf == 12 then

      local isel = 0
      for k = 1, #Glass.sensorLalist do
	 if inpN ~= 2 then
	    if (Glass.sensorIdlist[k] == Glass.page[pageNumber][gaugeNumber].sensorId) and
	       (Glass.sensorPalist[k] == Glass.page[pageNumber][gaugeNumber].sensorPa) then
	       isel = k
	       break
	    end
	 else
	    if (Glass.sensorIdlist[k] == Glass.page[pageNumber][gaugeNumber].sensorId2) and
	       (Glass.sensorPalist[k] == Glass.page[pageNumber][gaugeNumber].sensorPa2) then
	       isel = k
	       break
	    end
	 end
      end

      form.addRow(2)
      form.addLabel({label="Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.sensorLalist, isel, true,
			(function(x) return changedSensor(x, inpN, 12) end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      local sd = Glass.page[pageNumber][gaugeNumber].decimals or 0
      local txt = string.format("Sensor Decimals: %d", sd)
      form.addRow(1)
      form.addLabel({label=txt, font=FONT_NORMAL})

      local sc = Glass.page[pageNumber][gaugeNumber].units or '-'
      txt = string.format("Sensor Units: %s", sc)
      form.addRow(1)
      form.addLabel({label=txt, font=FONT_NORMAL})

      form.addRow(2)
      form.addLabel({label="Unit conversion:", font=FONT_NORMAL})

      if not Glass.page[pageNumber][gaugeNumber].convertIdx then
	 Glass.page[pageNumber][gaugeNumber].convertIdx = 1
      end

      local cvi = Glass.page[pageNumber][gaugeNumber].convertIdx

      local function changedConversion(val)
	 --print("pageNumber, gaugeNumber, val", pageNumber, gaugeNumber, val)
	 Glass.page[pageNumber][gaugeNumber].convertIdx =  val
	 if val == 1 then -- val is 1 means no conversion
	    if Glass.page[pageNumber][gaugeNumber].nativeUnits then
	       Glass.page[pageNumber][gaugeNumber].units =
		  Glass.page[pageNumber][gaugeNumber].nativeUnits
	    end
	 else
	    Glass.page[pageNumber][gaugeNumber].units = Glass.convertUnits[val]
	 end
	 form.reinit(12)
	 
      end

      form.addSelectbox(Glass.convertStr, cvi, true, changedConversion)

      form.addRow(2)
      form.addLabel({label="Displayed Decimals", font=FONT_NORMAL})

      if not Glass.page[pageNumber][gaugeNumber].dispdec then
	 Glass.page[pageNumber][gaugeNumber].dispdec = sd
      end
      
      local function changedDispDec(val)
	 Glass.page[pageNumber][gaugeNumber].dispdec = val
      end
      
      local dd = Glass.page[pageNumber][gaugeNumber].dispdec
      form.addIntbox(dd, 0, 2, sd, 0, 1, changedDispDec)

      form.addRow(2)
      form.addLabel({label="Marker value", font=FONT_NORMAL})

      local mk = Glass.page[pageNumber][gaugeNumber].marker or 0
      
      if not Glass.page[pageNumber][gaugeNumber].marker then
	 Glass.page[pageNumber][gaugeNumber].marker = mk
      end
      
      local function changedMarker(val)
	 Glass.page[pageNumber][gaugeNumber].marker = val
	 print("marker", val)
      end
      
      form.addIntbox(mk, -32768, 32767, 0, 0, 1, changedMarker)
      
      form.addRow(2)
      form.addLabel({label="Gauge Name:", font=FONT_NORMAL})
      form.addTextbox(Glass.page[pageNumber][gaugeNumber].instName, 10,
		      (function(x) return changedName(x, inpN) end),
		      {width=155, font=FONT_NORMAL})

      
   elseif sf == 13 then

      local id, fn, minV, maxV
      
      fn = Glass.page[pageNumber][1].fmtNumber
      id = Glass.page[pageNumber][gaugeNumber].widgetID
      if id < 0 then
	 print("Glass: no images")
	 return
      end

      local scale = cfgimg.instruments[id].scale
      
      if scale == "fixed" or not Glass.page[pageNumber][gaugeNumber].minV then
	 minV = cfgimg.instruments[id].minV
      else
	 minV = Glass.page[pageNumber][gaugeNumber].minV
      end

      if scale == "fixed" or not Glass.page[pageNumber][gaugeNumber].maxV then
	 maxV = cfgimg.instruments[id].maxV
      else
	 maxV = Glass.page[pageNumber][gaugeNumber].maxV
      end      
      
      if cfgimg.instruments[id].scale == "variable" then
	 local scl = Glass.page[pageNumber][gaugeNumber].scl - 1
	 local mult = 10 ^ scl

	 local function minChanged(value)
	    Glass.page[pageNumber][gaugeNumber].minV = value / mult  --/ 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Min value"})
	 form.addIntbox(minV*mult, -10000, 10000, 0, scl, 1, minChanged)

	 local function maxChanged(value)
	    Glass.page[pageNumber][gaugeNumber].maxV = value / mult --/ 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Max value"})
	 form.addIntbox(maxV*mult, -10000, 10000, 10000, scl, 1, maxChanged)
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
   elseif sf == 14 then
      local hrs, mins, secs, sign      
            
      local function changedMS(val, tn, u, tm, tmud)
	 local tt = {hrs=hrs, mins=mins, secs=secs}
	 local tmsg = {timer1="Timer 1 ", timer2="Timer 2 "}
	 local umsg = {initial = "Initial Value ", target = "Target Value "} 
	 tt[u] = val
	 mins, secs, sign = ms(Glass.timers[tn][tm])
	 local ss = 1
	 if Glass.timers[tn][tmud] == "-" then ss = -1 end
	 Glass.timers[tn][tm] = ss * (tt.secs + 60 * tt.mins) * 1000
	 mins, secs, sign = ms(Glass.timers[tn][tm])
	 form.setTitle(string.format(tmsg[tn]..umsg[tm]..sign.."%02d:%02d", mins, secs))
      end

      local function timerPMChanged(x, tn, ud)
	 Glass.timers[tn][ud] = string.sub("+-", x, x)
	 sign = Glass.timers[tn][ud]
	 if sign == "-" then
	    Glass.timers[tn].initial = math.abs(Glass.timers[tn].initial) * -1
	 else
	    Glass.timers[tn].initial = math.abs(Glass.timers[tn].initial)	    
	 end
      end
      
      local plusminus = {"+", "-"}

      form.addRow(1)
            form.addLabel({label=string.rep(" ", 28) .. "Timer 1", font=FONT_BOLD})
      
      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      local isel = string.find("+-", (Glass.timers.timer1.initialUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer1", "initialUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer1.initial)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer1", "mins", "initial", "initialUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer1", "secs", "initial", "initialUD") end),
		     {width=60}
      )
      
      form.addRow(8)
      form.addLabel({label="Target:", width=65})
      local isel = string.find("+-", (Glass.timers.timer1.targetUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer1", "targetUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer1.target)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer1", "mins", "target", "targetUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer1", "secs", "target", "targetUD") end),
		     {width=60}
      )

      form.addRow(4)
      form.addLabel({label="Run Sw", width=65})
      local swe = "t1enable"
      swtCI.t1enable = form.addInputbox(switchItems.t1enable, true,
		       (function(x) return changedSwitch(x, "t1enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      local swr = "t1reset"
      swtCI.t1reset = form.addInputbox(switchItems.t1reset, true,
		       (function(x) return changedSwitch(x, "t1reset") end),
		       {width=100}
      )

      -------------------------------------------------------------------------
      
      form.addRow(1)
      form.addLabel({label=string.rep(" ", 28) .. "Timer 2", font=FONT_BOLD})

      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      local isel = string.find("+-", (Glass.timers.timer2.initialUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer2", "initialUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer2.initial)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer2", "mins", "initial", "initialUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer2", "secs", "initial", "initialUD") end),
		     {width=60}
      )
      
      form.addRow(8)
      form.addLabel({label="Target:", width=65})
      local isel = string.find("+-", (Glass.timers.timer2.targetUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer2", "targetUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer2.target)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer2", "mins", "target", "targetUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer2", "secs", "target", "targetUD") end),
		     {width=60}
      )

      form.addRow(4)
      form.addLabel({label="Run Sw", width=65})
      local swe = "t2enable"
      swtCI.t2enable = form.addInputbox(switchItems.t2enable, true,
		       (function(x) return changedSwitch(x, "t2enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      local swr = "t2reset"
      swtCI.t2reset = form.addInputbox(switchItems.t2reset, true,
		       (function(x) return changedSwitch(x, "t2reset") end),
		       {width=100}
      )
      
      form.setFocusedRow(1)
      form.setTitle("Timer Setup")
   elseif sf == 15 then
      --form.addRow(1)
      --form.addLabel({label="sf15"})
      form.setButton(1, "Exit",   ENABLED)
      form.setTitle("Serial data transfer")
   end
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end

local function clearPage(pn, gm)
   Glass.page[pn] = {}
   for k=1,gm do
      Glass.page[pn][k] = {}
      Glass.page[pn][k].sensorId = 0
      Glass.page[pn][k].sensorPa = 0	 
      Glass.page[pn][k].sensorLs = "..."
      Glass.page[pn][k].sensorLa = "..."	    
      Glass.page[pn][k].units = "-"
      Glass.page[pn][k].decimals = 0
      Glass.page[pn][k].dispdec = nil
      Glass.page[pn][k].imageID = -1
      Glass.page[pn][k].widgetID = -1
      Glass.page[pn][k].value = 0.0
      Glass.page[pn][k].instName = "GG"..k
      Glass.page[pn][k].sensorId2 = 0
      Glass.page[pn][k].sensorPa2 = 0      
      Glass.page[pn][k].scl = 1
   end
   Glass.page[pn][1].fmtNumber = 1
end

local function keyPressed(key)

   local fmtNumber
   local iid
   if pageNumber < 1 or #Glass.page < 1 then
      fmtNumber = 1
   else
      fmtNumber = Glass.page[pageNumber][1].fmtNumber
   end

   --print("key pressed", key)
   updateConfigIDs()

   if subForm == 1 then

      if keyExit(key) then
	 if key ~= KEY_ESC then
	    form.preventDefault()
	    savedRow = form.getFocusedRow()
	    form.reinit(1)
	 else
	    writeInst()
	    if dbmode and (not matchConfigID()) then
	       --print("time since last onRead: ", system.getTime() - lastRead)
	       print("lastRead, system.getTime() - lastRead", lastRead, system.getTime() - lastRead)
	       if (lastRead == 0) or (system.getTime() - lastRead > 5) then
		  system.messageBox("Can't update - glasses offline")
	       else
		  -- send goes here --
		  system.messageBox("Sending new config to Glasses")
		  sendUSB("full")
		  form.preventDefault()
		  form.reinit(15)
	       end
	    end
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
	 if fmtNumber > #cfgimg.config then fmtNumber = 1 end
	 Glass.page[pageNumber or 1][1].fmtNumber = fmtNumber
	 savedRow = form.getFocusedRow()
	 form.reinit(1)
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
	 local mx = #cfgimg.config[fm]
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
	 local wid = 0
	 local min, max, wtype, inp
	 print("key2: imageNum, editImgs[imageNum].widgetID", imageNum, editImgs[imageNum].widgetID)
	 
	 for i,img in ipairs(cfgimg.instruments) do
	    if i == editImgs[imageNum].widgetID then
	       --print("key2 match")
	    --if img.imageID == editImgs[imageNum].imageID then
	       wid = i
	       iid = img.imageID
	       min = img.minV
	       max = img.maxV
	       wtype = img.wtype
	       inp = img.inputs
	    end
	 end
	 --print("key2 set widgetID", wid)
	 Glass.page[pageNumber][gaugeNumber].widgetID = wid	 
	 Glass.page[pageNumber][gaugeNumber].imageID = iid
	 Glass.page[pageNumber][gaugeNumber].minV = min -- may be nil
	 Glass.page[pageNumber][gaugeNumber].maxV = max -- may be nil
	 Glass.page[pageNumber][gaugeNumber].wtype = wtype
	 Glass.page[pageNumber][gaugeNumber].inputs = inp	 
	 form.reinit(10)
      end
   elseif subForm == 11 then
      if key == KEY_1 then
	 print("subForm 11 sendUSB full")
	 sendUSB("full")
	 form.reinit(15)
      end
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   elseif subForm == 12 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(10)
      end
   elseif subForm == 13 or subForm == 14 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   elseif subForm == 15 then
      if keyExit(key) or key == KEY_ENTER then
	 --print("sf 15, keyExit, key", keyExit(key), key)
	 form.preventDefault()
	 --form.reinit(1)
      elseif key == KEY_1 then
	 form.reinit(1)
      end
   end
end

local function drawRectangleGlass(x0, y0, xl, yl)
   local f = 0.55
   lcd.drawRectangle(f*x0 - f*xl / 2, f*y0 - f*yl / 2, f*xl, f*yl)
end

local function drawText(x0, y0, val, lbl, units, dp, twid, thgt)
   --print("@", units, x0, y0, twid, thgt)
   --local text = string.format(lbl .. ' ' .. "%.2f", val)
   local text = svv(dp, val) --string.format("%.2f", val)
   local ww = lcd.getTextWidth(FONT_BIG, text)
   local hh = lcd.getTextHeight(FONT_BIG, text)
   lcd.drawText(x0 + (twid - ww)/2, y0 + thgt/2 - hh/2, text, FONT_BIG)
   ww = lcd.getTextWidth(FONT_MINI, lbl)
   hh = lcd.getTextHeight(FONT_MINI, lbl)
   lcd.drawText(x0, y0 + thgt/2 - hh/2, lbl, FONT_MINI)
   ww = lcd.getTextWidth(FONT_MINI, (units or ""))
   hh = lcd.getTextHeight(FONT_MINI, (units or ""))
   lcd.drawText(x0 + twid - ww, y0 + thgt/2 - hh/2, units, FONT_MINI)
end

local function drawTimer(x0, y0, val, lbl, twid, thgt)
   local sign, mins, secs
   mins, secs, sign = ms(val * 1000)
   local text = string.format(lbl .. ' ' .. "%s%02d:%02d", sign, mins, secs)
   local ww = lcd.getTextWidth(FONT_BIG, text)
   local hh = lcd.getTextHeight(FONT_BIG, text)
   lcd.drawText(x0 + (twid - ww)/2, y0 + (thgt - hh)/2, text, FONT_BIG)
end

local function drawTape(r, x, y, v, lbl, barW, barH, width, height, side)

   local xtick
   local xnum
   local xb
   local xs
   local valX
   local barX
   
   if side == "left"  then
      barX = 0
      valX = 3 * barW / 2 - 1
      xtick = -5
      xnum = 25*r + 4
   else
      barX = barW
      valX = barW / 2 + 1
      xtick = 5
      xnum = barW/2 
   end
   
   local nums = 6
   local zp = nums / 2
   local step = 10
   local delta = v % step
   local inc = step / nums
   local k1 = ((zp * nums) / step - (zp+1))
   local k2 = ((zp * nums) / step + (zp-0))
   local kdx
   local idx
   local yp
   local yv
   local bar = barH
   local valText
   local ypi

   lcd.setClipping(x + barX, y, barW, barH)
   local x0 = x + barX
   local y0 = y
   kdx = k1
   repeat
      idx = kdx * inc
      yp = zp * (bar / step) - (bar / step) * (delta /step) * inc - (bar /step) * idx
      ypi = yp
      yv = (zp * step / inc) - (step * idx / inc) + (v - delta)
      yv = math.floor(yv * 100.0 + 0.5) / 100.0
      valText = string.format("%g", yv) 
      if true then --if (y - barH / 2 + ypi > 0 and y + barH / 2 - ypi < 160) then
	 lcd.drawLine(x - x0 + 2 * barX, y + barH / 2 - ypi - y0,
		      x - x0 - xtick + 2 * barX, y + barH / 2 - ypi - y0)
	 drawTextCenter(x - x0 + xnum + barX, y + barH / 2 - ypi - y0, valText, FONT_MINI)
      end
      kdx = kdx + 1
   until (kdx > k2)
   lcd.resetClipping()
   
   lcd.drawLine(x + barW , y + barH / 2, x + barW + xtick, y + barH / 2)
   lcd.drawRectangle(x + barX, y, barW, barH)
   drawRectangleCenter(x + valX, y + barH / 2, barW, lcd.getTextHeight(FONT_NORMAL) + 4)
   valText = string.format("%d", v)
   drawTextCenter(x + valX, y + barH / 2, valText, FONT_NORMAL)
   
end

local function printForm(w,h)

   local fmtNumber
   local r = 144/160 -- jeti screen size vs. pixel ht on glasses
   local offset = w - 144
   local fudge = 131 -- extra bytes sent that are not in files
   if subForm == 15 then
      lcd.setColor(0,0,255)
      lcd.drawFilledRectangle(10, 20, (w-20) * serialBytesSent / (totalSendBytes + fudge), 30)
      lcd.setColor(0,0,0)
      lcd.drawText(10, 60, string.format("Bytes sent: %d / %d", serialBytesSent, totalSendBytes + fudge))
      lcd.drawText(10, 80, serialFileName)
   elseif subForm == 10 then
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(offset-5, 0, h+1+5, h+1)
      if imageNum and imageNum > 0 and editImgs[imageNum] then --and editImgs[imageNum].loadImage then
	 local xi, yi
	 -- This works but is stupid ... rethink a better way to offset the long thin hbars and text boxes
	 if editImgs[imageNum].imageWidth > 144 and editImgs[imageNum].imageHeight < 50 then -- 160 widths on glasses are 144 on Jeti
	    xi, yi = w/2 - editImgs[imageNum].imageWidth/2, 80
	 else
	    xi, yi = offset, 0
	 end
	 --if editImgs[imageNum].loadImage then
	 local un = Glass.page[pageNumber][gaugeNumber].units
	 local dp = Glass.page[pageNumber][gaugeNumber].decimals
	 --print("wtype", editImgs[imageNum].wtype)
	 if editImgs[imageNum].wtype == "gauge" or editImgs[imageNum].wtype == "compass" or
	    editImgs[imageNum].wtype == "hbar" or  editImgs[imageNum].wtype == "vbar" then
	    drawImage(xi,yi,editImgs[imageNum], "loadImage")
	 elseif editImgs[imageNum].wtype == "gNew" then
	    lcd.setColor(0,0,0)
	    lcd.drawText(xi + 40, yi + 40, "gNew")
	 elseif editImgs[imageNum].wtype == "arcGauge" then
	    lcd.setColor(0,0,0)
	    lcd.drawFilledRectangle(xi, yi, editImgs[imageNum].imageWidth,
				    editImgs[imageNum].imageHeight)
	    local id = editImgs[imageNum].widgetID
	    --drawArcGauge(offset + r * xc, r * yc, minA, maxA,
	    --min, max, val, r*cfgimg.forms[fid].radiusOut, r*cfgimg.forms[fid].radiusIn)
	    local fid = cfgimg.instruments[id].formID + 1
	    --print("id, fid", id, fid)
	    local minA = cfgimg.forms[fid].arcStart --22.5 * (cfgimg.forms[fid].arcStart - 9)
	    local maxA = cfgimg.forms[fid].arcEnd --22.5 * (cfgimg.forms[fid].arcEnd - 8)
	    --local hh, ww = cfgimg.forms[fid].height, cfgimg.forms[fid].width
	    local x0, y0 = cfgimg.forms[fid].x0, cfgimg.forms[fid].y0
	    --local xc, yc = x0 + ww / 2, y0 + hh / 2
	    --print(xi, yi, hh, ww, minA, maxA)
	    lcd.setColor(255,255,255)
	    drawArcGauge(xi + r * x0 , yi + r * y0, minA, maxA,
			 cfgimg.instruments[id].minV, cfgimg.instruments[id].maxV,
			 cfgimg.instruments[id].maxV, r * cfgimg.forms[fid].radiusOut,
			 r * cfgimg.forms[fid].radiusIn)
	 elseif editImgs[imageNum].wtype == "ahGauge" then
	    local id = editImgs[imageNum].widgetID
	    local fid = cfgimg.instruments[id].formID + 1	    
	    local hh, ww = cfgimg.forms[fid].height, cfgimg.forms[fid].width	    
	    local rr = ww / 2
	    local r = 144/160
	    --print(xi + ww / 2, yi + hh / 2, rr)
	    drawahGauge(xi + ww / 2 - 8, yi + hh / 2 - 8, r * rr, r * hh, r * ww)
	 elseif editImgs[imageNum].wtype == "htext" then
	    lcd.setColor(0,0,0)
	    lcd.drawRectangle(xi, yi, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	    local iN = Glass.page[pageNumber][gaugeNumber].instName
	    local vv = Glass.page[pageNumber][gaugeNumber].value or 0.0
	    drawText(xi, yi + 0*editImgs[imageNum].imageHeight/2, vv, iN, un, dp,
		     editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	 elseif editImgs[imageNum].wtype == "timer" then
	    lcd.setColor(0,0,0)
	    lcd.drawRectangle(xi, yi, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	    local iN = Glass.page[pageNumber][gaugeNumber].instName
	    local vv = Glass.page[pageNumber][gaugeNumber].value or 0.0
	    drawTimer(xi, yi, vv, iN, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	 elseif editImgs[imageNum].wtype == "vltape" then
	    lcd.setColor(0,0,0)
	    --local function drawTape(r, x, y, v, lbl, barW, barH, width, height, side)
	    local r = 130/160
	    local id = editImgs[imageNum].widgetID
	    local fid = cfgimg.instruments[id].formID + 1
	    local hh, ww = cfgimg.forms[fid].height, cfgimg.forms[fid].width	    	    
	    local bh, bw = cfgimg.forms[fid].hgt, cfgimg.forms[fid].wid	    	    
	    local side = cfgimg.instruments[id].side
	    local dx
	    if side == "left" then dx = 10 else dx = 10 end
	    drawTape(r, xi + dx, yi+5, 100, "", bw*r, bh*r, ww*r, hh*r, side) 
	 end
      else
	 lcd.setColor(0,0,0)
	 --lcd.drawText(200,80, "imageNum " .. (imageNum or "nil") .." " .. #editImgs)
	 lcd.drawText(200,60, "No Image")
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

      if pageNumber < 1 or not Glass.page[pageNumber] then return end
      
      fmtNumber = Glass.page[pageNumber][1].fmtNumber
      if fmtNumber > 0 then
	 local gp = cfgimg.config[fmtNumber]
	 for g,t in ipairs(gp) do
	    drawRectangleGlass(t.xc, t.yc, t.width, t.height)
	 end
      end
      lcd.drawText(2,0,string.format("%d", fmtNumber))
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

local function drawHbar(x0, y0, min, max, val, wid, hgt)
   local bw = math.floor(wid * (val - min) / (max - min) + 0.5)
   bw = math.min(math.max(0, bw), wid)
   lcd.drawFilledRectangle(x0, y0, bw, hgt)
end

local function drawVbar(x0, y0, min, max, val, wid, hgt)
   local bh = math.floor(hgt * (val - min) / (max - min) + 0.5)
   bh = math.min(math.max(0, bh), hgt + 1)
   --print(x0, y0, wid, hgt, bh)
   lcd.drawFilledRectangle(x0, math.floor(y0) + (math.floor(hgt) - math.floor(bh)) + 2, wid+1, bh)
end

local function drawScale(x0, y0, minA, maxA, major, minor, fine, ro)
   local minR = math.rad(minA)
   local maxR = math.rad(maxA)
   local dR = (maxR - minR) / fine
   local alpha
   local sinA, cosA
   local xo, yo, xi, yi
   local ri
   local nextMaj = 0
   local ren=lcd.renderer()
   
   for tick = 0, fine, 1 do
      if tick == nextMaj then
	 ri = ro * 0.80
	 nextMaj = nextMaj + fine / major
      else
	 ri = ro * 0.90
      end
      alpha = minR + tick * dR
      sinA = math.sin(alpha)
      cosA = -math.cos(alpha)
      xo = ro * sinA
      yo = ro * cosA
      xi = ri * sinA
      yi = ri * cosA
      ren:reset()
      ren:addPoint(x0+xo, y0+yo)
      ren:addPoint(x0+xi, y0+yi)
      ren:renderPolyline(1)
      --lcd.drawLine(x0 + xo, y0 + yo, x0 + xi, y0 + yi)
   end
end


local function printTeleSmall(w,h)
   if pageNumberTele and pageNumberTele > 0 then
      drawTextCenter(20, 10, string.format("Page %d", pageNumberTele), FONT_MINI)
   end

   lcd.drawImage(45, 3, glassesIcon)
   if not Glass.var.statusAL or system.getTime() - lastRead > 5 then
      lcd.drawImage(75, 3, redcrossIcon)
      return
   end

   if Glass.var.statusAL and Glass.var.statusAL.Conn then
      if Glass.var.statusAL.Conn == 1 then
	 drawTextCenter(110, 10, string.format("%d%%", Glass.var.statusAL.Batt), FONT_MINI)
	 if (Glass.var.statusAL.Conf == Glass.var.statusAL.GlassConf and matchConfigID()) then
	    lcd.drawImage(75, 3, greencheckIcon)
	 else
	    lcd.drawImage(75, 3, yellowpauseIcon)	 
	 end
      else
	 lcd.drawImage(75, 3, yellowpauseIcon)	 
      end
   end
   

   --[[
   lcd.drawImage(45, 3, glassesIcon)
   if not Glass.var.statusAL or Glass.var.statusAL.Conn == 0 then
      lcd.drawImage(75, 3, redcrossIcon)
   end

   if Glass.var.statusAL and Glass.var.statusAL.Conn == 1 then
      lcd.drawImage(75, 3, greencheckIcon)
      --lcd.drawImage(100,  0, batteryIcon)
      lcd.drawText(100, 3, string.format("Batt %d%%", Glass.var.statusAL.Batt), FONT_MINI)
   end
   --]]
end

local function printTele(w,h)

--[[
   UPDATE: THIS IS OLD (PRE-FORMS) -- PLS UPDATE IT

   Sample json file structure (snipped from configconfig.jsn) 
   It contains just one object each for "configs" and "images" as an example of the data shape
   All position coordinates are in the ActivImage space .. origin at lower right
   The main table is cfgimg .. then cfgimg.config and cfgimg.instruments

{
    { "config": [ [ {"xlr": 72,"ylr": 48} ], [] ...] },
    { "images": [{"scale": "variable","xlmin": 140,"ylmin": 15,
      "ylmax": 15,"xlmax": 20,"x0": 80,"y0": 80,"nlen": 70,
      "maxA": 150, "inputs": 1,"minA": -150,"maxV": 100,
      "ylbl": 50,"wtype": "gauge","xlbl": 80,"widgetID": 10,
      "minV": 0},{} ... ] }
}

--]]
   
   local r = 160 / 256 -- show the glasses space (304x256) in Jeti screen (320x160) .. scale by 160/256
   local offset = (319 - r * 304) / 2 -- center the shrunk glasses space on the Jeti screen
   local fmt
   local gpp

   -- Select the appropriate page (controlled by assigned switch or line in menu)
   -- Individual dynamic widget info stored in Glass.page[pageNumber][gaugeNumber].property
   -- The Glass.page values are the ones that form the 200msec json
   
   if not switchItems.pageChange  then pageNumberTele = pageNumber end

   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159) -- black background over entire window
   lcd.setColor(255,255,255)            -- rest of animation (needles, etc) is white
   lcd.drawRectangle(1+offset, 1, (304-2)*r, (256-4)*r) -- draw scaled glasses hw screen as box
   if pageNumberTele and pageNumberTele > 0 then
      lcd.drawText(10, 10, string.format("Page %d", pageNumberTele))
   end
   local offline = system.getTime() - lastRead > 10

   lcd.drawImage(265, 15, glassesIcon)
   if not Glass.var.statusAL or offline then
      lcd.drawImage(295, 15, redcrossIcon)
   end

   if Glass.var.statusAL and Glass.var.statusAL.Conn and not offline then
      if Glass.var.statusAL.Conn == 1 then
	 lcd.drawImage(272,  40, batteryIcon)
	 drawTextCenter(287, 70, string.format("%d%%", Glass.var.statusAL.Batt), FONT_MINI)
	 if (Glass.var.statusAL.Conf == Glass.var.statusAL.GlassConf and matchConfigID()) then
	    lcd.drawImage(295, 15, greencheckIcon)
	 else
	    lcd.drawImage(295, 15, yellowpauseIcon)	    
	 end
      else
	 lcd.drawImage(295, 15, yellowpauseIcon)	 
      end
      --drawTextCenter(287,120, string.format("C:%d", Glass.var.statusAL.Conf), FONT_MINI)
      --drawTextCenter(287,135, string.format("CG:%d", Glass.var.statusAL.GlassConf), FONT_MINI)
      drawTextCenter(287,135, string.format("%d/%d", Glass.var.statusAL.Conf,
					    Glass.var.statusAL.GlassConf), FONT_MINI)
   end
      
   if Glass.var.statusAL and Glass.var.statusTime and Glass.var.statusAL.Conn == 1 and
      system.getTimeCounter() < Glass.var.statusTime + 5000 then
      drawTextCenter(287, 90, "G", FONT_MINI)
   else
      drawTextCenter(287, 90, "-", FONT_MINI)
      if system.getTimeCounter() > initTime + 2 -- only when run
	 and wasEverGreen and Glass.settings.rebootDisco then
	 wasEverGreen = false
	 if Glass.var.statusAL then
	    Glass.var.statusAL.Conn = 0 -- note that we are no longer connected
	 end
	 restartTimer = system.getTimeCounter() + 500 -- set high for 500ms
	 gpio.write(6,1)
	 print("gpio 6 set high rebootDisco")
	 system.messageBox("Rebooting AL controller")
	 system.playBeep(2, 440, 200)
      end
   end
   
   if not pageNumberTele or pageNumberTele < 1 then return end

   local xr, yr, xc, yc
   local min, max, val, val2, lbl
   local ccfg, cid, fid

   gpp = Glass.page[pageNumberTele]
   if not gpp then
      lcd.drawTextCenter(160, 80, "No pages defined")
      print("Glass.page[pageNumberTele] is nil")
      return
   end
   
   if not gpp[1].fmtNumber then gpp[1].fmtNumber = 1 end
   fmt = gpp[1].fmtNumber --  string.format("p%d", gpp[1].fmtNumber)
   local ccf =  cfgimg.config[fmt]

   -- From here, everything referenced with "t." would come from the 200msec json if we
   -- were in the ESP. Make sure we only reference things that are sent that way so we're not
   -- cheating. Everything from "cid." is from the instruments section cfgimg.instruments

   for g,t in ipairs(gpp) do        -- loop over all gauges on this page with a valid imageID
      --[[
      if g <= 3  then
	 print("g, t.widgetID, t.imageID", g, t.widgetID, t.imageID)
      end
      --]]
      if t.widgetID > 0 and t.imageID >= 0 then        -- if there is a value to animate
	 ccfg = ccf[g]                 -- this is the "config" key for this page and this widget
	 cid = cfgimg.instruments[t.widgetID]
	 fid = cid.formID + 1
	 --print("fid", fid)
	 xr = ccfg.xul
	 yr = ccfg.yul
	 xc = xr + cfgimg.forms[fid].x0           -- for gauge, this is the pivot point of the needle
	 yc = yr + cfgimg.forms[fid].y0
	 if true then --t.value then
	    -- if scale "fixed" then scale comes from images, else from 200ms json
	    if cid.scale and cid.scale == "fixed" then
	       min = cid.minV
	       max = cid.maxV
	    else  -- be defensive in case of missing minV/maxV
	       --print(t.minV, cid.minV, t.maxV, cid.maxV)
	       if not t.minV then
		  if cid.minV then min = cid.minV else min = 0 end
	       else
		  min = t.minV
	       end
	       if not t.maxV then
		  if cid.maxV then max = cid.maxV else max = 1 end
	       else
		  max = t.maxV
	       end
	       
	       --min = t.minV or 0
	       --max = t.maxV or 1
	    end
	    lbl = t.instName or "..." --.instName is named .label in the 200ms json 
	    val = t.value
	    val2 = t.value2
	    --print(g, cid.wtype,t.widgetID)
	    if cid.wtype == "oldgauge" then
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       if val then
		  drawNeedle(offset + r * xc, r * yc, cfgimg.forms[fid].minA, cfgimg.forms[fid].maxA,
			     min, max, val, r * cfgimg.forms[fid].nlen)
	       end
	    elseif cid.wtype == "gauge" then
	       drawScale(offset + r * xc, r * yc, cfgimg.forms[fid].minA, cfgimg.forms[fid].maxA,
			 cfgimg.forms[fid].major, cfgimg.forms[fid].minor, cfgimg.forms[fid].fine,
			 r * cfgimg.forms[fid].radius)
			 
	       if val then
		  drawNeedle(offset + r * xc, r * yc, cfgimg.forms[fid].minA, cfgimg.forms[fid].maxA,
			     min, max, val, r * cfgimg.forms[fid].radius * 0.75)
	       end
	       
	    elseif cid.wtype == "gNew" then

	       --print("foo")
	       lcd.drawText(offset + 10, 80, "gNew")
	    elseif cid.wtype == "compass" then

	       local xdelta = {  0, -16,   0,  16,   0}
	       local ydelta = { 24, -24, -24, -24,  24}
	       local xdr, ydr
	       local ren = lcd.renderer()

	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")

	       if t.value2 then
		  ren:reset()
		  for k,v in ipairs(xdelta) do
		     xdr, ydr = rotateXY(xdelta[k], ydelta[k], math.rad(t.value2 + 180))
		     ren:addPoint(offset +  r * (xc + xdr), r * (yc + ydr))
		  end
		  ren:renderPolyline(2)
	       end

	       local xcc, ycc, nl
	       local nl =  0.75 * r * cfgimg.forms[fid].nlen
	       if val then
		  xcc = offset + r * xc + math.cos(math.rad(val-90)) * nl
		  ycc = r * yc + math.sin(math.rad(val-90)) * nl
		  lcd.drawCircle(xcc, ycc, r*8)
	       end
	       
	       --[[
	       if val then
		  drawNeedle(offset + r * xc, r * yc, 0, 360, 0, 360, val,
			     r * cfgimg.forms[fid].nlen)
	       end

	       if t.value2 then
		  drawNeedle(offset + r * xc, r * yc, 0, 360, 0, 360, t.value2,
			     r * cfgimg.forms[fid].nlen)
	       end
	       --]]
	    elseif cid.wtype == "hbar" then
	       --print(offset+r*xr, r*yr,  cfgimg.forms[fid].width, cfgimg.forms[fid].height)
				 
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       if val then
		  drawHbar(offset + r * xc, r * yc, min, max, val, r * cfgimg.forms[fid].wid,
			   r * cfgimg.forms[fid].hgt)
	       end
	       --[[
	       lcd.drawRectangle(offset + r * xr,
	       r * yr,
	       r*cfgimg.forms[fid].width,
	       r*cfgimg.forms[fid].height)
	       --]]
	    elseif cid.wtype == "vbar" then
	       --print(offset+r*xr, r*yr,  cfgimg.forms[fid].width, cfgimg.forms[fid].height)
				 
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       if val then
		  drawVbar(offset + r * xc, r * yc, min, max, val, r * cfgimg.forms[fid].wid,
			   r * cfgimg.forms[fid].hgt)
	       end
	       --[[
	       lcd.drawRectangle(offset + r * xr,
	       r * yr,
	       r*cfgimg.forms[fid].width,
	       r*cfgimg.forms[fid].height)
	       --]]
	    elseif cid.wtype == "htext" then
	       if val then
		  drawText(offset + r * xc, r * yc, val, lbl, t.units, t.decimals, r * cfgimg.forms[fid].wid,
			   r * cfgimg.forms[fid].hgt)
	       end
	       lcd.drawRectangle(offset + r * xr,
	       r * yr,
	       r*cfgimg.forms[fid].width,
	       r*cfgimg.forms[fid].height)
	    elseif cid.wtype == "timer" then
	       if val then
		  drawTimer(offset + r * xc, r * yc, val, lbl, r * cfgimg.forms[fid].wid,
			    r * cfgimg.forms[fid].hgt)
	       end
	    elseif cid.wtype == "arcGauge" then
	       if val then
		  local minA = cfgimg.forms[fid].arcStart --22.5 * (cfgimg.forms[fid].arcStart - 9)
		  local maxA = cfgimg.forms[fid].arcEnd--22.5 * (cfgimg.forms[fid].arcEnd - 8)
		  drawArcGauge(offset + r * xc, r * yc, minA, maxA,
			       min, max, val, r*cfgimg.forms[fid].radiusOut,
			       r*cfgimg.forms[fid].radiusIn)
		  -- center value at same point as label, not pivot pt (because of half arcs)
		  drawTextCenter(offset + xr * r + r * cfgimg.forms[fid].xlbl,
				 r * yc,
				 svv(t.decimals, val), FONT_BIG)
	       end
	    elseif cid.wtype == "ahGauge" then
	       local hh = cfgimg.forms[fid].width
	       local ww = cfgimg.forms[fid].height
	       --print("ahGauge", val, offset + r * xc, r * yc, r * ww / 2)
	       if val then
		  drawahGauge(offset + r * xc, r * yc, r * (ww - 10) / 2, r*hh, r*ww, val, val2)
	       end
	    elseif cid.wtype == "vltape" then
	       if val then
		  drawTape(r, offset + r * xc, r * yc, val, lbl, r * cfgimg.forms[fid].wid,
			   r * cfgimg.forms[fid].hgt, r * cfgimg.forms[fid].width,
			   r * cfgimg.forms[fid].height, cid.side)
	       end
	       
	    end 
	    --print(cid.wtype, cid.scale, min, max)
	    if ( ((cid.wtype == "gauge" or cid.wtype == "hbar" or cid.wtype == "vbar" or cid.wtype == "arcGauge")
	       and cid.scale == "variable") or cid.wtype == "ahGauge") then
	       local smin = string.format(dpFmt(min), min)
	       local smax = string.format(dpFmt(max), max)
	       if cid.wtype == "ahGauge" then
		  smin = ""--string.format("R: %.0f°", val2 or 0)
		  smax = ""--string.format("P: %.0f°", val or 0)
		  lbl = ""
	       end

	       local cfylmin 
	       local cfylmax 

	       cfylmin = cfgimg.forms[fid].ylmin
	       cfylmax = cfgimg.forms[fid].ylmax
	       
	       drawTextCenter(offset + xr * r + r * cfgimg.forms[fid].xlmin,
			      yr * r + r * cfylmin,
			      smin, FONT_MINI)
	       drawTextCenter(offset + xr * r + r * cfgimg.forms[fid].xlmax,
			      yr * r + r * cfylmax,
			      smax, FONT_MINI)
	       --print("cid.wtype, cid.scale, val", cid.wtype, cid.scale, val)
	       if ((cid.wtype == "gauge") or (cid.wtype == "hbar") or (cid.wtype == "vbar")) and (cid.scale == "variable") then
		  drawTextCenter(offset + xr * r + r * cfgimg.forms[fid].xlbl,
				 yr * r + r * cfgimg.forms[fid].ylbl,
				 svv(t.decimals, val), FONT_MINI)
	       else
		  drawTextCenter(offset + xr * r + r * cfgimg.forms[fid].xlbl,
				 yr * r + r * cfgimg.forms[fid].ylbl,
				 lbl, FONT_MINI)		  
	       end
	       
	    end
	 end
      end
   end
   if emflag ~= 0 then
      lcd.drawText(10,130, string.format("%d", system.getCPU()))
      lcd.drawText(10,110, string.format("%d", loopCPU))
   end
   
   
end

local function destroy()

   --print("closing")
   if (logFileFP) then
      io.close(logFileFP)
   end
   
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
	    if  kkk == "sensorId" or kkk == "sensorPa" or kkk == "sensorId2" or kkk == "sensorPa2" then
	       vv[kkk] = string.format("0X%X", math.floor(vvv)) 
	    end
	 end
      end
   end

   for k,v in pairs(Glass.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa" then
	 Glass.settings[k] = string.format("0X%X", math.floor(v))
      end
   end

   Glass.timers.timer1.start = 0 -- no need to save these
   Glass.timers.timer1.time = 0 
   
   Glass.timers.timer2.start = 0
   Glass.timers.timer2.time = 0
   
   local GGtbl = {}
   GGtbl.page = Glass.page
   GGtbl.settings = Glass.settings
   GGtbl.timers = Glass.timers
   GGtbl.settings.jsnVersion = JSNVERSION
   GGtbl.switchInfo = Glass.switchInfo
   
   fp = io.open(fn, "w")
   if fp then
      local jt = json.encode(GGtbl)
      if not jt then print("json encode error GGtbl") else
	 io.write(fp, json.encode(GGtbl), "\n")
	 io.close(fp)
      end
      print("Glass - State saved " .. fn)
   else
      print("Glass - Could not save state")
   end
end

local savedData
local onReadBuf = ""

local function onRead(indata)

   local MAX_ALOOK_CMD = 533
   local cmd_len
   local command
   local str
   
   --local str = "indata ==> "
   --for i=1,#indata,1 do
   --   str = str .. string.format("0x%02X ", string.byte(indata, i))
   --end
   --print(str)
   
   onReadBuf = onReadBuf .. indata
   if #onReadBuf < 1 or string.byte(onReadBuf, 1) ~= 0xFF then
      print("DFM-HUD: CS_INVALID - bad format")
      print(onReadBuf)
      onReadBuf = ""
      return
   end
   
   cmd_len = string.byte(onReadBuf, 4)
   --print("DFM-HUD: cmd_len", cmd_len)
   
   if not cmd_len then return end -- input too short to have len 
   
   if cmd_len > MAX_ALOOK_CMD then
      print("DFM-HUD: CS_INVALID - too long")
      onReadBuf = ""
      return
   end

   if #onReadBuf < cmd_len then -- incomplete .. wait for more data
      --print("waiting for more data")
      return
   end

   if string.byte(onReadBuf, cmd_len) == 0xAA then -- complete and valid Alook reply

      --str = "DFM-HUD onRead complete Cmd ==> "
      --for i=1,cmd_len,1 do
      -- str = str .. string.format("0x%02X ", string.byte(onReadBuf, i))
      --end
      --print(str)
      
      command = string.sub(onReadBuf, 1, cmd_len)
      onReadBuf = string.sub(onReadBuf, cmd_len+1, -1)
      --print("#onReadBuf len after sub", #onReadBuf)

      if string.byte(command, 2) == 0xD3 then -- cfglist
	 local name, size, version, usgCnt, installCnt, isSystem
	 print("DFM-HUD onRead: cfgList response")
	 local i = 7 -- first char of cfg payload (see AL docs section 4.14)
	 local aviatorVersion = -1
	 local aviatorCurrentVersion = 1
	 repeat
	    name, size, version, usgCnt, installCnt, isSystem =
	       string.unpack(">zI4I4I1I1I1", command, i)
	    print(string.format("Name: %s Size %d Version %d", name, size, version))
	    if name == "aviator" then
	       aviatorVersion = version
	    end
	    i = i + #name + 1 + 11
	 until i >= cmd_len

	 if aviatorVersion ~= aviatorCurrentVersion then
	    sendState = state.CONNECTED --send the preparation info and font file
	 else
	    sendState = state.CONNECTED -- for testing .. do every time
	    --sendState = state.COMPLETE -- glasses have current info - good to go
	 end

      elseif string.byte(command, 2) == 0x05 then -- battery level
	 print("DFM-HUD Battery level (%)", string.byte(command, 7))
      elseif string.byte(command, 2) == 0x50 then -- font list
	 print("DFM-HUD onRead: font list response")
	 local id, height
	 local i = 7 -- first char of cfg payload (see AL docs section 4.14)
	 repeat
	    id, height = string.unpack(">I1I1", command, i)
	    print("id " .. id .. " height " .. height)
	    i = i + 2
	 until i >= cmd_len
      end
      
   end

   --if buffer has more commands, recurse to process
   
   if #onReadBuf > 0 then onRead("") end
   
   if true then return end
   
   --print("time since last onRead: ", system.getTime() - lastRead)
   --print("indata", indata)
   local data
   if savedData then
      data = savedData ..indata
      savedData = ""
   else
      data = indata
      savedData = ""
   end
   --print(data)
   --if data == "W" or (emflag ~= 0 and system.getInputs("SE") == 1) then
      --print("ENGO gesture")
      --system.messageBox("AL gesture logged")
      --gestureTime = system.getTimeCounter() + 1000
   --elseif string.find(data, "{") == 1 and string.find(data, "}") then
   if string.find(data, "{") == 1 and string.find(data, "}") then
      local callOK
      if emflag ~= 0 then
	 local swd = system.getInputs("SD") -- SD to print json only on emulator
	 if swd and swd == 1 then
	    print("status json: " .. data)
	 end
      end
      local testJsonT
      callOK, testJsonT = pcall(json.decode,data)
      if callOK then
	 if Glass.var.statusAL then
	    --print("Conf, GlassConf:", Glass.var.statusAL.Conf,Glass.var.statusAL.GlassConf)
	 end
	 
	 if testJsonT.mb then
	    system.messageBox(testJsonT.mb)
	 else
	    Glass.var.statusAL = testJsonT
	    Glass.var.statusTime = system.getTimeCounter()
	 end

	 if Glass.var.statusAL and Glass.var.statusAL.Gesture == 1 then
	    print("ENGO gesture")
	    system.messageBox("AL gesture received")
	    gestureTime = system.getTimeCounter() + 1000
	 end
	 
	 lastRead = system.getTime()
      else
	 print("not callOK", data)
	 Glass.var.statusAL = nil -- too aggressive? .. leave at last value vs set to nil??
      end
   else
      if string.find(data, "{") == 1 and not string.find(data, "}") then
	 savedData = data
      else
	 local ss = ""
	 for i=1,#data,1 do
	    ss = ss .. string.format("%02x ", string.byte(data,i))
	 end
	 
	 print("serial data received: ", ss)
	 --print("logFileFP", logFileFP)
	 if (logFileFP) then
	    io.write(logFileFP, data, "\n")
	 end
	 savedData = ""
      end
   end
end

local function gestureCB()
   if gestureTime ~= 0 and system.getTimeCounter() < gestureTime then
      --print("logging 1")
      return 1
   else
      gestureTime = 0
      return 0
   end
end

local function init()

   local fn
   local fmtNumber

   --print("CPU Entry ", system.getCPU())
   
   initTime = system.getTime()
   --tenSecTimer = initTime
   
   sendState = state.DISCONNECTED
   jsonHoldTime = system.getTimeCounter()-- + 10 * WAIT_TIME

   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(Glass)
   
   system.registerForm(1, MENU_APPS, "Glass", initForm, keyPressed, printForm)

   fn = prefix() .. pathJson .. "instr.jsn"
      
   local file = io.readall(fn)
   cfgimg = {}
   if file then
      cfgimg = json.decode(file)
      print("Glass - Reading avail instruments from ", fn)
   else
      system.messageBox("Glass: Cannot read " .. fn)
      return
   end

   fn = prefix() .. pathJson .. "instrESP.jsn"
      
   file = io.readall(fn)
   cfgimgESP = {}
   if file then
      cfgimgESP = json.decode(file)
      print("Glass - Reading avail instruments (ESP) from ", fn)
   else
      system.messageBox("Glass: Cannot read " .. fn)
      return
   end

   --print("CPU 0: ", system.getCPU())

   local ratio = 144 / 160 -- ratio of "small" images to jeti screen height
   id2avail = {}
   local im, ims
   for i,img in ipairs(cfgimg.instruments) do
      if img.imageID > 0 then --img.BMPname ~= "" then
	 local imn = string.format("Image%02d", img.imageID)
	 --im = prefix() .. pathImages .. img.BMPname .. "-small.png"
	 im = prefix() .. pathImages .. imn  .. "-small.png"	 
	 ims = prefix() .. pathImages .. imn .. "-smaller.png"      
	 --print("loading images im, ims:", im, ims)
	 img.loadImage = lcd.loadImage(im)
	 --print("lcd.loadImage ret", img.loadImage)
	 img.loadImageSmaller = lcd.loadImage(ims)
	 img.imageWidth = img.loadImage.width
	 img.imageHeight = img.loadImage.height
	 --print("* i, img.formID", i, img.formID)
	 
	 img.origWidth = cfgimg.forms[img.formID + 1].width --img.width
	 img.origHeight = cfgimg.forms[img.formID + 1].height --img.height
      else
	 local ww = cfgimg.forms[img.formID + 1].width
	 local hh = cfgimg.forms[img.formID + 1].height
	 img.origWidth = ww or 0
	 img.origHeight = hh or 0
	 img.imageWidth = (ww or 0) * ratio
	 img.imageHeight = (hh or 0) * ratio
      end
      if img.imageID > 0 then -- prob can remove .. is is2avail identity matrix now?
	 id2avail[img.imageID] = i
      end
   end

   --[[
   for k,v in pairs(id2avail) do
      print("id2avail k,v", k,v)
   end
   --]]
   
   fn = prefix() .. pathImages .. "glasses.png"
   glassesIcon = lcd.loadImage(fn)
   fn = prefix() .. pathImages .. "redcross.png"
   redcrossIcon = lcd.loadImage(fn)
   fn = prefix() .. pathImages .. "greencheck.png"
   greencheckIcon = lcd.loadImage(fn)   
   fn = prefix() .. pathImages .. "battery.png"   
   batteryIcon = lcd.loadImage(fn)   
   fn = prefix() .. pathImages .. "yellowpause.png"
   yellowpauseIcon = lcd.loadImage(fn)      
   --print("CPU 1: ", system.getCPU())

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
      success, descr = serial.onRead(sidSerial,onRead)   
      if success then
	 --print("Glass: Callback registered")
      else
	 print("Glass: Error setting callback", descr)
      end
   else
      print("Glass - Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "Glasses Display", 4, printTele)
   system.registerTelemetry(2, "Glasses Status", 1, printTeleSmall)   

   local function initG()
      print("Glass - No saved state")

      Glass.page = {}
      pageMax = #Glass.page
      pageNumber = 0
      gaugeNumber = 1

      Glass.settings = {}
      Glass.settings.latId = 0
      Glass.settings.latPa = 0
      Glass.settings.lngId = 0
      Glass.settings.lngPa = 0

      Glass.timers = {}
      Glass.timers.stateSTOP = 0
      Glass.timers.stateRUN = 1
      Glass.timers.timer1 = {state = Glass.timers.stateSTOP, time=0, start=0,
			     target=0, initial = 300 * 1000}
      Glass.timers.timer2 = {state = Glass.timers.stateSTOP, time=0, start=0,
			     target=0, initial = 300 * 1000}
   end

   --print("CPU 2", system.getCPU())   

   local GGtbl = {}
   fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"
   file = io.readall(fn)
   if file then
      GGtbl = json.decode(file)      
      Glass.page = GGtbl.page
      Glass.settings = GGtbl.settings
      Glass.timers  = GGtbl.timers
      Glass.switchInfo = GGtbl.switchInfo
      if #Glass.page > 0 then
	 pageNumber = 1
	 pageMax = #Glass.page
      end
      gaugeNumber = 1
      if not Glass.timers then Glass.timers = {} end
      Glass.timers.timer1.time = 0
      Glass.timers.timer2.time = 0   
      Glass.timers.stateSTOP = 0
      Glass.timers.stateRUN = 1
   else
      initG()
   end

   if not Glass.switchInfo then Glass.switchInfo = {} end
      
   if not Glass.settings then Glass.settings = {} end
   if not Glass.settings.jsnVersion or Glass.settings.jsnVersion ~= JSNVERSION then
      print("old JSON in "..fn.. " - starting with no saved state")
      initG()
      system.messageBox("App settings were reset")
   end
   
   if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
   
   -- put hex strings back into numbers for Id and Pa
   for k, v in pairs(Glass.page) do
      for kk,vv in pairs(v) do
	 for kkk, vvv in pairs(vv) do
	    if  kkk == "sensorId" or kkk == "sensorPa" or kkk == "sensorId2" or kkk == "sensorPa2" then
	       vv[kkk] = tonumber(vvv)
	    end
	 end
      end
   end

   for k,v in pairs(Glass.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa" then
	 Glass.settings[k] = tonumber(v)
      end
   end

   --print("CPU 3: ", system.getCPU())
      
   Glass.gpsReads = 0
   Glass.initPos = nil
   Glass.curPos = nil
   Glass.zeroPos = nil
   
   Glass.timers.timer1.state = Glass.timers.stateSTOP
   Glass.timers.timer2.state = Glass.timers.stateSTOP

   if not Glass.timers.timer1.initial then
      Glass.timers.timer1.start = 0
      Glass.timers.timer1.initial = 300 * 1000 -- 5:00 in ms
      Glass.timers.timer1.time = 300 * 1000
   else
      Glass.timers.timer1.start = 0
      Glass.timers.timer1.time = Glass.timers.timer1.initial
   end
   if not Glass.timers.timer1.target then
      Glass.timers.timer1.target = 0 -- 0:00
   end
   
   if not Glass.timers.timer2.initial then
      Glass.timers.timer2.start = 0
      Glass.timers.timer2.initial = 300 * 1000 -- 5:00 in ms
      Glass.timers.timer2.time = 300 * 1000
   else
      Glass.timers.timer2.start = 0
      Glass.timers.timer2.time = Glass.timers.timer2.initial
   end
   if not Glass.timers.timer2.target then
      Glass.timers.timer2.target = 0 -- 0:00
   end

   for k, swi in pairs(Glass.switchInfo) do
      local t = string.sub(swi.name,1,1)
      --print("k, swi", k, swi.name, swi.mode, swi.activeOn)
      switchItems[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
   end

   if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
   
   updateConfigIDs()
   if not Glass.settings.configIDs or Glass.settings.configVersion == 0 then
      Glass.settings.configIDs = {}
   end
   setpNT()
   
   writeInst() --- will also get done in loop() based on tenSecTimer

   --gpio 6 drives the D2 pin on the ESP32 for reboot
   --gpio 5 drives the D0 pin on the ESP32 for OTA start
   --gpio 7 drives the power-on circuit via P3-3 (IO7)
   
   gpio.mode(5, "out-pp");
   gpio.mode(6, "out-pp");
   gpio.mode(7, "out-pp");
   
   gpio.write(5,0) -- set to 1 to start OTA
   gpio.write(6,0) -- set to 1 to reboot
   gpio.write(7,1) -- turn power on
   
   if not Glass.settings.logSeq then
      Glass.settings.logSeq = 1
   else
      Glass.settings.logSeq = Glass.settings.logSeq + 1
      if Glass.settings.logSeq > 10 then Glass.settings.logSeq = 1 end
   end
   
   local lfn = string.format("logfile%d.txt", Glass.settings.logSeq)
   --print("lfn", lfn)
   logFileFP = io.open(prefix() .. pathJson .. lfn, "w")

   system.registerLogVariable("ALGesture", "", gestureCB) 

   print("CPU end init(): ", system.getCPU())

   -- for testing: Glass.settings.rebootDisco = nil

   --[[
   print("===> cfgimg.config")
   for k,v in pairs(cfgimg.config) do
      print("cfgimg.config 1", k,v)
      for kk,vv in pairs(v) do
	 print("cfgimg.config 2", kk,vv)
	 for kkk,vvv in pairs(vv) do
	    print("cfgimg.config 3", kkk, vvv)
	 end
      end
   end

   print("===> cfgimg.forms")
   for k,v in pairs(cfgimg.forms) do
      print("cfgimg.forms 1", k,v)
      for kk,vv in pairs(v) do
	 print("cfgimg.forms 2", kk,vv)
      end
   end

   print("===> Glass.page")
   for k,v in pairs(Glass.page) do
      print("Glass.page 1", k,v)
      for kk,vv in pairs(v) do
	 print("Glass.page 2", kk, vv)
	 for kkk,vvv in pairs(vv) do
	    print("Glass.page 3", kkk, vvv)
	 end
      end
   end
   --]]

   
   local bw, xx

   bw = serial.write(sidSerial, 0xFF, 0X01, 0x00, 0x05, 0xAA) -- clear
   bw = serial.write(sidSerial, 0xFF, 0X39, 0x00, 0x06, 0xFF, 0xAA) -- flush and reset
   --bw = serial.write(sidSerial, 0xFF, 0x05, 0x02, 0x07, 0x01, 0x01, 0xAA) -- read batt
   -- select "aviator" app
   --bw = serial.write(sidSerial, 0xFF, 0xD2, 0x00, 0x0D, 'a', 'v', 'i', 'a', 't', 'o', 'r', 0x00, 0xAA)
   --bw = serial.write(sidSerial, 0xFF, 0x50, 0x02, 0x07, 0x01, 0x02, 0xAA) -- read fonts
  
end

return {init=init, loop=loop, author="DFM", destroy=destroy, version="1.00", name=appName}
