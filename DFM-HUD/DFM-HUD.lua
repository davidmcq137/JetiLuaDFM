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
local appHex = "44464D2D485544" -- "DFM-HUD" in hex
local pathApp = "Apps/"..appName.."/"
local pathImages = pathApp.."Images/"
local pathConfigs = pathApp.."Configs/"
local pathJson = pathApp.."Json/"
local JSNVERSION = 5
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
local editImgs = {}
local imageNum
local imageMax
local modelName
local state = {DISCONNECTED=1, WAITING=2, CONNECTED=3, SENDHEADER=4, SENDFILE=5, SENDFOOTER=6,
	       COMPLETE=7, SELECT=8}
local sendState = state.DISCONNECTED
local startingTime = 0
local WAIT_TIME = 200
local sendFP --, sendFPser
local writeJSON = true
local jsonHoldTime = 0
--local tempCall
--local sendFPtemp
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
--local totalSendBytes
local serialFileName
local lastRead = 0
local resetGlasses

local gtbl = {}

local initTime
local LOOPTIME = 250

local savedSerial = {}
local savedSerialReset = {}
local teleSerial = {}
local teleSerialReset = {}
local sendIndex = 0

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

local resetState = false
local ALisBlack = false

local function resetOn()
   resetState = true
end
local function resetOff()
   resetState = false
end

local function sendUSB(text)
   print("sendUSB: " .. text)
end

local function drawRectangleCenter(x,y,w,h)
   lcd.drawRectangle(x-w/2, y-h/2, w, h)
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function drawArc(theta, x0, y0, a0, aR, ri, ro, im, alp)
   --aR not used?
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

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
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

local function encodeBuf(str)
   local ret
   ret = str:gsub("(%x%x)", (function(s) return string.char(tonumber(s,16)) end))
   return ret
end

local function decodeAL(ps, dest)
   local gw = 304
   local gh = 256
   local rr = 160/256
   local offset = math.floor((320 - rr * 304) / 2) -- center the shrunk glasses space on the TX screen   
   local str
   
   --str = ""
   --for i=1,#ps,1 do
   --   str = str .. string.format("0x%02x ", string.byte(ps, i))
   --end
   --if string.byte(ps, 2) ~= 0x05 then
      --print("###> " .. str)
   --end
   
   local x1, y1, x2, y2
   local x1j, y1j, x2j, y2j
   local r, f, c, t, r1, r2
   local b = string.byte(ps, 2)
   local xt = {}
   local yt = {}
   local xtj = {}
   local ytj={}

   if b == 0x30 then --color
      local grey = string.byte(ps, 5)
      local greyB = grey | grey<<4
      lcd.setColor(greyB, greyB, greyB)

   elseif b == 0x32 then --line
      x1, y1, x2, y2 = string.unpack(">i2i2i2i2", ps, 5)
      x1j = math.floor(math.floor(rr*(gw - x1)) + offset)
      y1j = math.floor(rr*(gh - y1))
      x2j = math.floor(math.floor(rr*(gw - x2)) + offset)
      y2j = math.floor(rr*(gh - y2))
      lcd.drawLine(x1j, y1j, x2j, y2j)

      --if x1j == x2j then
	-- if math.abs(y1j - y2j) ~= 12.5 then
	--    print(math.abs(y1j - y2j))
	 --end
	 --print("y1j, y2j", y1j, y2j, math.abs(y1j-y2j))
      --end
      
      --print("###>line", x1, y1, x2, y2)
   elseif b == 0x33 then --rect
      x1, y1, x2, y2 = string.unpack(">i2i2i2i2", ps, 5)
      x1j = math.floor(math.floor(rr*(gw - x1)) + offset)
      y1j = math.floor(rr*(gh - y1))
      x2j = math.floor(math.floor(rr*(gw - x2)) + offset)
      y2j = math.floor(rr*(gh - y2))
      --print("###>rect", x1, y1, x2, y2)
      lcd.drawRectangle(math.min(x1j, x2j), math.min(y1j, y2j),
			math.abs(x2j - x1j), math.abs(y2j - y1j))
      --print("###>rect", math.min(y1j, y2j), math.abs(y2j-y1j))      
   elseif b == 0x34 then --rectf
      x1, y1, x2, y2 = string.unpack(">i2i2i2i2", ps, 5)
      x1j = math.floor(math.floor(rr*(gw - x1)) + offset)
      y1j = math.floor(rr*(gh - y1))
      x2j = math.floor(math.floor(rr*(gw - x2)) + offset)
      y2j = math.floor(rr*(gh - y2))
      lcd.drawFilledRectangle(math.min(x2j,x1j), math.min(y2j,y1j),
			      math.abs(x2j - x1j), math.abs(y2j - y1j))
      --print("###>rectf", math.min(y1j, y2j), math.abs(y2j-y1j))
      
   elseif b == 0x37 then --text
      x1, y1, r, f, c, str = string.unpack(">i2i2I1I1I1z", ps, 5)
      x1j = math.floor(rr*(gw - x1) + offset)
      y1j = math.floor(rr*(gh - y1))
      str = string.sub(str,1, -2)
      --print("x1, y1, r, f, c, str", x1, y1, r, f, c, str)
      --local grey = string.byte(ps, 5)
      --local greyB = grey | grey<<4
      --lcd.setColor(greyB, greyB, greyB)
      local font
      if f == 4 then -- 16 point
	 font = FONT_MINI
      elseif f == 5 then --36 point
	 font = FONT_BIG
      elseif f == 6 then -- 26 point
	 font = FONT_NORMAL
      end
      lcd.drawText(x1j, y1j, str, font)
      
   elseif b == 0x38 then --polyline
      local ren = lcd.renderer()
      local len
      ren:reset()
      len = string.byte(ps, 4)
      local start = 5
      t, r1, r2, start = string.unpack(">i1i1i1", ps, start)
      --print("t, r1, r2, start", t, r1, r2, start, len)
      for i=1,(len-8) / 4 do -- 7 bytes of preamble plus ending "0xAA"
	 xt[i], yt[i], start = string.unpack(">i2i2", ps, start)
	 xtj[i] = math.floor(rr * (gw - xt[i]) + offset)
	 ytj[i] = math.floor(rr * (gh - yt[i]))
	 ren:addPoint(xtj[i], ytj[i])
      end
      ren:renderPolyline(2)
   elseif b == 0x35 or b == 0x36 then --circle
      local rad
      local ren = lcd.renderer()
      ren:reset()
      x1, y1, rad = string.unpack(">i2i2I1", ps, 5)
      x1j = math.floor(rr*(gw - x1) + offset)
      y1j = math.floor(rr*(gh - y1))
      if b == 0x35 then
	 lcd.drawCircle(x1j, y1j, rr*rad)
      else
	 for i = 1, 10 do
	    ren:addPoint(x1j + rr * rad * math.sin(i * 2 * math.pi / 10),
			 y1j + rr * rad * math.cos(i * 2 * math.pi / 10))
	 end
	 ren:renderPolygon()
      end
      
   elseif b == 0x3c then -- arc
      local rad, as, ae, th
      x1, y1, rad, as, ae, th = string.unpack(">i2i2I1i2i2I1", ps, 5)
      x1j = math.floor(rr*(gw - x1) + offset)
      y1j = math.floor(rr*(gh - y1))
      drawArc(math.rad(ae-as), x1j, y1j, math.rad(as + 180), math.rad(ae), rr*(rad), rr*(rad + th), 18, 1)
   elseif b == 0x39 or b == 0x05 or b == 0x01 or b == 0xD3 or b == 0xD2 then
      
   else
      print("###> "..string.format("0x%02x", b))
   end
      
end

local function serialWrite(port, packedStr)
   local cc, err

   
   --[[ cannot check these because sending of fonts chunks the line
      local ll = string.byte(packedStr, 4)
      if ll ~= #packedStr then
      print("serialWrite: length mismatch")
      cc = nil
      return
      end
      if string.byte(packedStr, #packedStr) ~= 0xAA then
      print("serialWrite: no 0xAA at end")
      cc = nil
      return
      end
      if string.byte(packedStr, 1) ~= 0xFF then
      print("serialWrite: no 0xFF at begin")
      cc = nil
      return
      end
   --]]
   --if Glass.var.output ~= "Jeti" then
   --cc, err = serial.write(port, packedStr)
   --if not cc then
   -- print("DFM-HUD: serial write error " .. err)
   --else
   -- serialBytesSent = serialBytesSent + cc
   --end
   if resetState then
      table.insert(savedSerialReset, packedStr)
   else
      table.insert(savedSerial, packedStr)
   end
   --end
   cc = 0
   return cc
end

local function serialWriteDirect(port, packedStr)
   local cc, err
   --print("serialWriteDirect")
   local str = ""
   --for k=1,#packedStr do
   --   str = str .. string.format("0x%02x ", string.byte(packedStr, k))
   --				 end
   --print("$$$:" .. str)
   cc, err = serial.write(sidSerial, packedStr)
   if not cc then
      print("DFM-HUD: serial write error " .. err)
   else
      --print("cc:", cc)
      serialBytesSent = serialBytesSent + cc
   end
   return cc
end

local function writeInst()
   local bufClr = "FF010005AA"   
   print("writeInst()")
   resetGlasses = 1
   serialWriteDirect(sidSerial, encodeBuf(bufClr)) -- clear screen
   savedSerial = {}
   savedSerialReset = {}
   teleSerial = {}
   teleSerialReset = {}
   sendIndex = 0
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
   
local function drawImage(x,y,imgt, key)
   return lcd.drawImage(x,y,imgt[key])
end

local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
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

   --print("drawPitch", roll, sinRoll, cosRoll)
   
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
      
      for j = 1, 4, 1 do
	 xp[j] = -xw[j] * cosRoll - yw[j] * sinRoll
	 yp[j] = -xw[j] * sinRoll + yw[j] * cosRoll
      end
      for j = 3, 1, -1 do
	 xp[8-j] = xw[j] * cosRoll - yw[j] * sinRoll
	 yp[8-j] = xw[j] * sinRoll + yw[j] * cosRoll
      end
      if( not ( (xp[1] < -radAH and xp[7] < -radAH) or  (xp[1] > radAH and xp[7] > radAH)
	     or (yp[1] < -radAH and yp[7] < -radAH) or  (yp[1] > radAH and yp[7] > radAH) ) ) then
	 lcd.setColor(255,255,255)
	 ren:reset()
	 if (XH == XHL) then
	    for j = 1, #xp, 1 do
	       ren:addPoint(X0 + radAH + xp[j], Y0 + radAH + yp[j])
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

local function drawILSGauge(x, y, r, hh, ww, pp, rr)
   local cc = {24, 36, 48, 60}
   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(x - ww/2, y - hh/2, ww, hh)
   lcd.setColor(255,255,255)
   lcd.drawCircle(x,y,12)
   for k=1,4 do
      lcd.drawCircle(x + cc[k], y, 3)
      lcd.drawCircle(x - cc[k], y, 3)
   end
   for k=1,4 do
      lcd.drawCircle(x, y + cc[k], 3)
      lcd.drawCircle(x, y - cc[k], 3)
   end
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
	       print("GPS", sensor.id, sensor.param)
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

local oldPageNumber = 0

local function setpNT()
      local sw = system.getInputsVal(switchItems.pageChange) or -1
      local pp = sw + 2 -- -1, 0, 1 --> 1,2,3
      pp = math.min(pp, pageMax)
      pageNumberTele = pp
      if pp ~= oldPageNumber then
	 writeInst()
      end
      oldPageNumber = pp
end

local function RLwid(str, font)
   return math.floor( (20/36) * font * #str + 0.5 )
end

local function ALBattCheck()
   local pattern = ">BBBI1B"
   serialWriteDirect(sidSerial, string.pack(pattern, 0xFF, 0x05, 0x00, 0x05, 0xAA))
end

local function ALColor(color)
   local pattern=">BBBI1I1B"
   if color == 0x00 then ALisBlack = true else ALisBlack = false end
   serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x30, 0x00, 0x06, color & 0xF, 0xAA))
end

local function ALColorBlack()
   ALColor(0x00);
end

--local function ALColorGray()
--  ALColor(0x08);
--end

local function ALColorWhite() 
   ALColor(0x0F);
end

local function ALHold(wait)
   local pattern
   if wait then
      pattern = ">BBBI1I1I1I1B"
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x39, 0x02, 0x08, 0x00, 0x00, 0x00, 0xAA))
   else
      pattern = ">BBBI1I1B"
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x39, 0x00, 0x06, 0x00, 0xAA))
   end
end

local function ALFlush(wait)
   local pattern
   if wait then
      pattern = ">BBBI1I1I1I1B"
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x39, 0x02, 0x08, 0x00, 0x00, 0x01, 0xAA))
   else
      pattern = ">BBBI1I1B"
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x39, 0x00, 0x06, 0x01, 0xAA))
   end
end

local function ALDrawRect(x0, y0, x1, y1, rCode, wait)
  
   -- {0xFF, 0x33, 0x00, 0xLL, x0_u, x0_l, x1_u, y1_k, valX_u, valX_l, valY_u, valY_l, 0xAA}
   --     1     2     3     4     5     6     7     8       9      10      11      12    13
   -- rCode 0X33 for empty rect
   -- rCode 0X34 for filled rect
   local pattern 
   local len
   if not wait then 
      pattern = ">BBBI1I2I2I2I2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial,string.pack(pattern, 0xFF, rCode, 0x00, len, x0, y0, x1, y1, 0xAA))
   else
      pattern = ">BBBI1I1I1I2I2I2I2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial,string.pack(pattern, 0xFF, rCode, 0x02, len, 0, 0, x0, y0, x1, y1, 0xAA))
   end
   
   return (len);
end


local function ALDrawCircF(xc, yc, rad, wait)
   local pattern, len
   if not wait then
      pattern = ">BBBI1I2I2I1B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x36, 0x00, len, xc, yc, rad, 0xAA))
   else
      pattern = ">BBBI1I1I1I2I2I1B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x36, 0x02, len, 0x00, 0x00, xc, yc, rad, 0xAA))
   end
end

local function ALDrawCirc(xc, yc, rad, wait)
   local pattern, len
   if not wait then
      pattern = ">BBBI1I2I2I1B"
      len = string.packsize(pattern)
      --print("ALDrawCirc", xc, yc, len, rad, wait)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x35, 0x00, len, xc, yc, rad, 0xAA))
   else
      pattern = ">BBBI1I1I1I2I2I1B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x35, 0x02, len, 0x00, 0x00, xc, yc, rad, 0xAA))
   end
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
      fontCode = 4
   end
   
   local pattern
   local len
   local ps
   if wait then
      pattern = string.format(">BBBI1I1I1I2I2I1I1I1c%dB", #str)
      len = string.packsize(pattern)
      ps = string.pack(pattern, 0xFF, 0x37, 0x02, len, 0, 0, xp, yp, textDir, fontCode,
			  textColor, str, 0xAA)
   else
      pattern = string.format(">BBBI1I2I2I1I1I1c%dB", #str)
      len = string.packsize(pattern)
      ps = string.pack(pattern, 0xFF, 0x37, 0x00, len, xp, yp, textDir, fontCode,
			  textColor, str, 0xAA)
   end

   serialWrite(sidSerial,ps)
   
   return len
end

local function ALDrawTextC(str, fh, xp, yp, wait)
   local tw = RLwid(str, fh)
   local xt = xp + tw / 2
   local yt = yp + fh / 2
   ALDrawText(str, fh, xt, yt, wait)
end


--sizeofArc = ALPackArc(drawArc, x + x0, y + y0, rOut, arcStart, arcErase, thk);

local function ALDrawArc(x, y, r, arcS, arcE, thk, wait)

   --0xFF, 0x3C, 0x00, 0x0F, x_u, x_l, y_u, y_l, r, as_u, as_l, ae_u, ae_l, thk, 0xAA
   --   0     1     2     3    4    5    6    7  8     9     A     B     C    D     E

   local arcStart, arcEnd

   --print("arcS, arcE", arcS, arcE)
   
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

   local pattern
   local len
   --print("ALDrawArc len, r, thk", len, r, thk, arcStart, arcEnd)
   local waitReply
   if wait then
      pattern = ">BBBI1I1I1I2I2I1i2i2I1B"
      len = string.packsize(pattern)
      waitReply = 0x02
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x3C, waitReply, len, 0, 0, x, y, r,
					 arcStart, arcEnd, thk, 0xAA))
   else
      pattern = ">BBBI1I2I2I1i2i2I1B"
      len = string.packsize(pattern)      
      waitReply = 0x00
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x3C, waitReply, len, x, y, r,
				      arcStart, arcEnd, thk, 0xAA))
   end
   
   
end

local function ALDrawLine(x1, y1, x2, y2, wait)
   
   local pattern, len

   if not wait then
      pattern = ">BBBI1I2I2I2I2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x32, 0x00, len, x1, y1, x2, y2, 0xAA))
   else
      pattern = ">BBBI1I1I1I2I2I2I2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x32, 0x02, len, 0, 0, x1, y1, x2, y2, 0xAA))
   end
					 
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


-- ****

local function ALDrawRectC(xc, yc, width, height, rCode)
   local pattern, len
   pattern = ">BBBI1I2I2I2I2B"
   len = string.packsize(pattern)
   serialWrite(sidSerial, string.pack(pattern, 0xFF, rCode, 0x00, len,
				      xc - width/2, yc - height/2, xc + width/2, yc + height/2, 0xAA))

end

-- ****
local function ALDrawPolyLine(lw, np, xp, yp, x0, y0, wait)
   local pp
   local sp1, sp2
   local len
   --print("ALDrawPolyLine", lw, np, #xp, #yp)
   --for i=1,np do
   --   print(xp[i], yp[i])
   --end

   if not wait then
      pp = ">BBBI1I1I1I1"
      len = string.packsize(pp.. string.rep("i2i2", np) .. "B")
      sp1 = string.pack(pp, 0xFF, 0x38, 0x00, len, lw, 0, 0)
      sp2 = ""
      for i=1,np,1 do
	 sp2 = sp2 .. string.pack(">i2i2", xp[i] + x0, yp[i] + y0)
      end
      serialWrite(sidSerial, sp1 .. sp2 .. string.pack(">B", 0xAA))
   else
      print("ALDrawPolyLine: NOT YET")
   end
end

-- ****
local function ALDrawScale(x0, y0, alphaStart, alphaEnd, minA, maxA, ro,
			   major, minor, fine, minV, maxV, scale)

   -- this version only does major ticks

   local ri, alpha, dA
   local xo, yo, xi, yi
   local sinA, cosA
   
   alpha = math.rad(minA)
   dA = (math.rad(maxA) - alpha) / major
   ri = ro * 0.85;
   
   for tick = 1, major + 1 do
      sinA = -math.sin(alpha);
      cosA = math.cos(alpha);
      xo = ro * sinA;
      yo = ro * cosA;
      xi = ri * sinA;
      yi = ri * cosA;
      ALDrawLine(xo + x0, yo + y0, xi + x0, yi + y0, false)
      alpha = alpha + dA
   end
   
end


local function ALDrawMinMaxLabel(x, y, x0, y0, label, xlbl, ylbl,
			       xlmin, ylmin, xlmax, ylmax, v, dp, minV, maxV, sq)

  -- label

   local lblX = xlbl + x + RLwid(label, 16) / 2;
   local lblY = ylbl + y + 16 / 2;

  -- min 
  
  local minText = encdp(dp, minV);
  local xlMin = xlmin + x + RLwid(minText, 16) / 2;
  local ylMin = ylmin + y + 16 / 2;

  -- max

  local maxText = encdp(dp, maxV);
  local xlMax = xlmax + x + RLwid(maxText, 16) / 2; 
  local ylMax = ylmax + y + 16 / 2;

  --print("ALDMML", label, lblX, lblY)
  if sq then
     ALDrawText(label, 16, lblX, lblY, false)
  end
  ALDrawText(minText, 16, xlMin, ylMin, false)
  ALDrawText(maxText, 16, xlMax, ylMax, false)  
end


-- ****

local vbarLowXprev = {0,0,0,0}
local vbarLowYprev = {0,0,0,0}
local vbarUpXprev =  {0,0,0,0}
local vbarUpYprev =  {0,0,0,0}
local vbarPctPrev =  {0,0,0,0}

local function ALVbar (reset, seq, ccfg, cff, cid, val, val2, minV, maxV, mk, dd) 
  
  local x = ccfg.xlr;
  local y = ccfg.ylr;
  
  local width = ccfg.width;
  --local height = ccfg.height;

  local x0 = cff.x0;
  local y0 = cff.y0;

  local barW = cff.wid;
  local barH = cff.hgt;

  local scale = cid.scale;

  local xlmin, ylmin, xlmax, ylmax, xlbl, ylbl;
  if (scale == "variable") then
     xlmin = x + cff.xlmin;
     xlmax = x + cff.xlmax;
     ylmin = y + cff.ylmin;
     ylmax = y + cff.ylmax;
     xlbl  = x + cff.xlbl;
     ylbl  = y + cff.ylbl;
  end

  if (maxV == minV) then return end
  
  local inpct, pct
  if (val) then
     inpct = (val - minV) / (maxV - minV);
     pct = math.max(0, math.min(inpct, 1)) --clip(0.0, 1.0, inpct);
  else
     pct = 0
  end

  local lowX, lowY, upX, upY

  --uint8_t img = dW.im;
  
  local maxText, minText, lblVal;
  
  if (scale == "variable") then
     minText = encdp(dd, minV);
     maxText = encdp(dd, maxV);
     lblVal = encdp(dd, val or 0);
  end
  
  ALHold();

  if true then -- (reset == 1 or (vbarPctPrev[seq] ~= inpct) ) then
     if (reset == 1) then
	resetOn()
	ALDrawTextC(minText, 16, xlmin, ylmin, false);
	ALDrawTextC(maxText, 16, xlmax, ylmax, false);
	resetOff()
     else
	ALColorBlack(); --erase prev bar and value
	ALDrawRect(vbarLowXprev[seq], vbarLowYprev[seq], vbarUpXprev[seq], vbarUpYprev[seq],
		   0x34, false);
	if (scale == "variable") then
	   ALDrawRectC(xlbl, ylbl, RLwid("0000", 16), 16, 0X34)
	end   
     end
     
     ALColorWhite();
    
    --draw bargraph filled box


    lowX = x + (width - x0) - 7;
    upX = lowX - barW + 0;
    upY = y + y0 - barH;

    if (maxV > 0 and minV < 0) or (maxV < 0 and minV > 0) then
       lowY = y + y0 - barH*(1-pct)

       upY = y + y0 - barH * (maxV / (maxV - minV))

       ALDrawRect(lowX, lowY, upX, upY, 0x34, false);       
    else
       lowY = y + y0 - barH*(1-pct); --(1 - pct) - barH;
       ALDrawRect(lowX, lowY, upX, upY, 0x34, false);
       --ALDrawCirc(x+x0,y+y0,10,false)
       --ALDrawCirc(upX,upY,7,false)
       --ALDrawCirc(lowX,lowY,3,false)
    end
    
    local markY;
    local mpct = (mk - minV) / (maxV - minV);
    --print("inpct, mpct", inpct, mpct)
    if (mpct> 0.0 and mpct < 1.0) then
       --markY = y + (height - y0);
       --markY = markY + barH * (1 - mpct);
       markY = y + y0;
       markY = markY - barH * (1-mpct);
       if (mk > 0 and maxV > minV) or (mk < 0 and minV > maxV)then
	  if (inpct > mpct) then
	     ALColorBlack();
	     ALDrawRect(lowX, markY-2, upX, markY+2, 0x34, false);
	     ALColorWhite();
	  else
	     ALDrawRect(lowX, markY-2, upX, markY+2, 0x34, false);
	  end
       elseif (mk < 0 and maxV > minV) or (mk > 0 and minV > maxV) then
	  if (inpct < mpct) then
	     ALColorBlack();
	     ALDrawRect(lowX, markY-2, upX, markY+2, 0x34, false);
	     ALColorWhite();
	  else
	     ALDrawRect(lowX, markY-2, upX, markY+2, 0x34, false);
	  end
       else
	  ALDrawLine(lowX, markY, upX, markY, false)
       end
       
       
    end
    
    --draw box outline
     ALDrawRect(x+x0, y+y0, x+x0-barW, y+y0-barH, 0x33, false);

    local dy = barH / 5;
    for i = 1, 4, 1 do
       --ALDrawLine(x+x0, y+y0-i*dy, x+x0-barW+3, y+y0-i*dy, false); --+3 fudge. roundoff?
    end

    if (scale == "variable") then
       ALDrawTextC(lblVal, 16, xlbl, ylbl, false);
    end
  end
  ALFlush(true);

  -- save old values
  vbarPctPrev[seq] = inpct;
  vbarLowXprev[seq] = lowX;
  vbarLowYprev[seq] = lowY;
  vbarUpXprev[seq] = upX;
  vbarUpYprev[seq] = upY;

end

-- ****

local ALCompassBrgXprev = {0,0,0,0};
local ALCompassBrgYprev = {0,0,0,0};
--local ALCompassAlphaDispXPrev = {0,0,0,0};
local ALCompassRotPrev = {0,0,0,0};

local function ALCompass (reset, seq, ccfg, cff, cid, val, val2, minV, maxV, label)
   
   local scale = cid.scale
   local rotdeg = math.rad( (val2 or 0));
   local minA = cff.minA;
   local maxA = cff.maxA;

   local degMin = minA; 
   local degMax = maxA; 

   --print("minA, maxA", minA, maxA)
   
   local degMinI = math.floor(degMin - 1.0);
   local degMaxI = math.floor(degMax + 1.0);
   
   local x = ccfg.xlr;
   local y = ccfg.ylr;
   
   local x0 = cff.x0;
   local y0 = cff.y0;
   
   local ro = cff.radius;
   local major = cff.major;
   local minor = cff.minor;
   local fine = cff.fine;
   
   local nlen = 0.75 * ro; 
   
   local xdelta = {  0, -16,   0,  16,   0};
   local ydelta = { 24, -24, -24, -24,  24};

   local xrr = {}
   local yrr = {}

   for i,_ in ipairs(xdelta) do
      xrr[i], yrr[i] = rotateXY(xdelta[i], ydelta[i], rotdeg);
   end
   
   local brgR = 6;
   
   val = val or 0
   local sinA = math.sin(math.rad(val))
   local cosA = math.cos(math.rad(val))
   
   local brgX = x + x0 - math.floor(sinA * nlen * 0.95);
   local brgY = y + y0 + math.floor(cosA * nlen * 0.95);
   
   if (reset == 1 or brgX ~= ALCompassBrgXprev[seq] or brgY ~= ALCompassBrgYprev[seq] or
       rotdeg ~= ALCompassRotPrev[seq]) then
      ALHold(false)
      ALColorBlack()
      
      -- draw prev here 
      
      if (reset == 0) then -- so that we have prev values saved
	 ALDrawCircF(ALCompassBrgXprev[seq], ALCompassBrgYprev[seq], brgR, false)
      end

      ALDrawRectC(x+x0, y+y0, 60, 60, 0x34)
      
      ALColorWhite()
      
      if (reset ~= 0) then
	 --print("compass is writing the scale");
	 ALDrawScale(x+x0, y+y0, degMinI, degMaxI, minA, maxA, ro, major, minor, fine,
		     minV, maxV, scale);
	 ALDrawArc(x+x0, y+y0, ro, minA, maxA, 3, false)	 
      else
	 -- leave this commented out for now .. we don't have any gauges with labels at the moment
      end
      
      --draw new here

      --print("ALDrawCircF", brgX, brgY, brgR)
      ALDrawCircF(brgX, brgY, brgR, false)
      
      --print("ALDrawPolyLine", 2, 5, false)
      ALDrawPolyLine(2, 5, xrr, yrr, x+x0, y+y0, false)
      
      --flush pending writes
      
      ALFlush(true)
      
      -- save old values
      
      ALCompassBrgXprev[seq] = brgX;
      ALCompassBrgYprev[seq] = brgY;
      ALCompassRotPrev[seq] = rotdeg;
   end

end



-- ****
local vertTapeValIntprev = {0,0,0,0};

local function ALVertTape (reset, seq, ccfg, cff, cid, val)
  
   --local scale = cid.scale;

  --local minV;
  --local maxV;
  --local label;
  --local dp;

  local x = ccfg.xlr;
  local y = ccfg.ylr;

  local x0 = cff.x0;
  local y0 = cff.y0;
  
  --local width = ccfg.width;
  --local height = ccfg.height;

  local barW = cff.wid;
  local barH = cff.hgt;

  local side = cid.side;

  val = val or 0
  
  local valInt = math.floor(val + 0.5);

  if (reset == 1 or valInt ~= vertTapeValIntprev[seq]) then

    local xtick;
    local xnum;
    local valX;
    local barX;

    if (side == "left") then
      barX = 0;
      valX = 3 * barW / 2;
      xtick = -5;
      xnum = 25 + 4;
    else
      barX = barW;
      valX = barW / 2;
      xtick = 5;
      xnum = barW / 2;
    end

    local nums = 6;
    local zp = nums / 2;
    local step = 10;
    local delta = val - math.floor(val / step) * step; -- this is equiv to v % step in lua
    local inc = step / nums;
    local k1 = ((zp * nums) / step - (zp+1));
    local k2 = ((zp * nums) / step + (zp-1));
    local kdx;
    local idx;
    local yp;
    local yv;
    local bar = barH;
    local valText;
    local ypi;
    local waitReply = false;
    local count = 0;

    ALHold();
    ALColorBlack();
    ALDrawRect(x+x0 - barX, y+y0, x+x0-barX - barW, y+y0-barH, 0x34, false); --erase last numbers in box
    ALColorWhite();

    kdx = k1;
    repeat
      idx = kdx * inc;
      yp = zp * (bar / step) - (bar / step) * (delta /step) * inc - (bar /step) * idx;
      ypi = math.floor(yp);
      yv = (zp * step / inc) - (step * idx / inc) + (val - delta);
      yv = math.floor(yv * 100.0 + 0.5) / 100.0;
      valText = string.format("%g", yv) --sprintf(valText, "%g", yv); 
      if (y + y0 - barH / 2 + ypi > 0 and y + y0 - barH / 2 + ypi < 256) then
        count = count + 1;
        if (count % 4 == 0) then
          waitReply = true;
        end
        ALDrawLine(x + x0 - 2 * barX, y + y0 - barH / 2 + ypi, x + x0 -2*barX + xtick,
		   y + y0 - barH / 2 + ypi, false);
        ALDrawTextC(valText, 16, x + x0 - barX - xnum, y + y0 - barH / 2 + ypi, waitReply);
        waitReply = false;
      end 
      kdx = kdx + 1;
    until (kdx > k2);
    
    local blnk = 30;
    
    ALColorBlack();
    
    ALDrawRect(x+x0-barX, y+y0+1, x+x0-barX-barW, y+y0+blnk, 0x34, false); --erase above box
    ALDrawRect(x+x0-barX, y+y0-barH-1, x+x0-barX-barW, y+y0-barH-blnk, 0x34, false); -- erase below box
    ALDrawRectC(x + x0 - valX, y + y0 - barH / 2, barW, 26+4, 0x34); -- erase value box

    ALColorWhite();
    ALDrawLine(x + x0 - barW, y + y0 - barH / 2, x + x0 - barW - xtick,
	       y + y0 - barH / 2, false); --ref tick mark
    ALDrawRect(x+x0 - barX, y+y0, x+x0-barX - barW, y+y0-barH, 0x33, false); -- box outline
    ALDrawRectC(x + x0 - valX, y + y0 - barH / 2, barW, 26+4, 0x33); --value box outline
    valText = string.format("%d", valInt) --sprintf(valText, "%d", valInt);
    ALDrawTextC(valText, 26, x + x0 - valX, y + y0 - barH / 2, false); ---value

    ALFlush(true);
    
    vertTapeValIntprev[seq] = valInt;
  end

end


-- ****

local ahGaugeAlphaDispInt = 0
local ahGaugeAlphaDispIntPrev = {0,0,0,0}

local function ALAhGauge (reset, seq, ccfg, cff, cid, val, val2)

   --print("ALAhGauge", reset, seq, val, val2)
   
   local x = ccfg.xlr;
   local y = ccfg.ylr;
   
   local x0 = cff.x0;
   local y0 = cff.y0;
   
   local ww = ccfg.width;
   --local hh = ccfg.height;

   val = val or 0;
   val2 = val2 or 0;
   
   local pitch = -val or 0 ---(val-50);
   local roll = -val2;

   --print("pitch, roll", pitch, roll)
   
   --horion markers on left and right sides of screen
   
   local BAR = (25 * ww / 160)
   local EE  = (5 * ww / 160)
   local xLH = {- (ww / 2 - BAR), - ww / 2 + EE, - ww / 2 + EE};
   local yLH = {0, 0, - EE};
   local xRH = {(ww / 2 - BAR), ww / 2 - EE, ww / 2 - EE};
   local yRH = {0, 0, - EE};
   local radAH = ww / 2;
   local radAC = ww / 2 - 2;
   local XH, YH;
   local XHS = 18 * radAH / 70;
   local XHL = 40 * radAH / 70;
   local pitchR = radAH / 25;
   
   local sinRoll = math.sin(-math.rad(roll));
   local cosRoll = math.cos(-math.rad(roll));
   
   --local drawW
   --local drawL
   
   local xp = {};
   local yp = {};
   local xs = {};
   local ys = {}; 
   
   local dxh; 
   
   local valaX = x + x0 - ww / 2 - 2;
   local valaY = y + y0 - ww / 2 - 2;
   
   local valbX = x + x0 + ww / 2 + 2;
   local valbY = y + y0 + ww / 2 + 2;
   
   local circX = x + x0;
   local circY = y + y0;
   
   ahGaugeAlphaDispInt = math.floor(roll + pitch);
   
   if true then -- (reset == 1 or ahGaugeAlphaDispIntPrev[seq] ~= ahGaugeAlphaDispInt) then
      
      
      ALHold()
      --ALColorBlack()
      --ALDrawRect(valaX, valaY, valbX, valbY, 0x34, false)
      ALColorWhite()
      ALDrawCirc(circX, circY, 5, false)
      
      if reset == 1 then
	 resetOn()
	 print("reset", reset)
	 ALDrawPolyLine(2, 3, xLH, yLH, x+x0, y+y0, false)
	 ALDrawPolyLine(2, 3, xRH, yRH, x+x0, y+y0, false)
	 resetOff()
      end
      
      local xw = {};
      local yw = {};
      
      local delta  = pitch - math.floor(pitch / 15) * 15;
      local i;
      i = delta - 45;
      
      repeat
	 if (math.abs(pitch - i) < 0.01) then
	    XH = XHL;
	 else
	    XH = XHS;
	 end
	 YH = pitchR * i;
	 dxh  = XH / 5;
	 
	 xw[1] = XH;
	 xw[2] = XH - 3 * dxh;
	 xw[3] = XH - 4 * dxh;
	 xw[4] = 0;
	 xw[5] = -xw[3];
	 xw[6] = -xw[2];
	 xw[7] = -xw[1];
	 
	 yw[1] = YH;
	 yw[2] = YH;
	 yw[3] = YH - dxh;
	 yw[4] = YH;
	 yw[5] = yw[3];
	 yw[6] = yw[2];
	 yw[7] = yw[1];
	 
	 for j = 1, 7, 1 do
	    xp[j] = math.floor(-xw[j] * cosRoll - yw[j] * sinRoll);
	    yp[j] = math.floor(-xw[j] * sinRoll + yw[j] * cosRoll); 
	 end
	 
	 xs[1] = xp[1];
	 ys[1] = yp[1];
	 xs[2] = xp[7];
	 ys[2] = yp[7];
	 
	 local inside = true;    
	 for j = 1, 7, 1 do
	    if (xp[j] > radAC or xp[j] < -radAC) then
	       inside = false;
	    end
	    if (yp[j] > radAC or yp[j] < -radAC) then
	       inside = false;
	    end
	 end
	 --print("inside, XH, XHL, radAC", inside, XH, XHL, radAC)

	 if (inside) then
	    if (XH == XHL) then
	       ALDrawPolyLine(3, 7, xp, yp, x+x0, y+y0, false)
	    else
	       ALDrawPolyLine(2, 2, xs, ys, x+x0, y+y0, false)
	    end
	 end
	 i = i + 15;
	 
      until i > 45 + delta;
      
      ALFlush(true)
      
   end
   
   -- save old value
   ahGaugeAlphaDispIntPrev[seq] = ahGaugeAlphaDispInt;
   
end

-- ****

local ilsGaugeLocPrev = {0,0,0,0}
local ilsGaugeGSPrev = {0,0,0,0}

local function ALILSGauge (reset, seq, ccfg, cff, cid, val, val2)

   --print("ALILSGauge", reset, seq, val, val2)
   
   local x = ccfg.xlr;
   local y = ccfg.ylr;
   
   local x0 = cff.x0;
   local y0 = cff.y0;
   
   local ww = ccfg.width;
   local hh = ccfg.height;

   local circX = x + x0;
   local circY = y + y0;

   --print("Glass.var.ilsLoc", Glass.var.ilsLoc)
   --print("Glass.var.ilsGS", Glass.var.ilsGS)
   
   val = val or 0;
   val2 = val2 or 0;

   local loc = 0
   local gs = 0
   
   if true then -- (reset == 1 or ahGaugeAlphaDispIntPrev[seq] ~= ahGaugeAlphaDispInt) then
      ALHold()
      ALColorBlack()
      if seq > 0 then
	 ALDrawLine(circX - ilsGaugeLocPrev[seq], circY - hh/2,
		    circX - ilsGaugeLocPrev[seq], circY + hh/2)
      end
      
      ALColorWhite()
      ALDrawCirc(circX, circY, 20, false)
      for k=1,4 do
	 ALDrawCirc(circX + 20 + k * 15, circY, 5, false)
	 ALDrawCirc(circX - 20 - k * 15, circY, 5, false)
      end

      if Glass.var.ilsLoc then
	 loc = math.floor(math.min(Glass.var.ilsLoc, 80))
	 ALDrawLine(circX - loc, circY - hh/2, circX - loc, circY + hh/2)
      end

      if Glass.var.ilsGS then
	 gs = math.min(math.max(10 * Glass.var.ilsGS, -80), 80)
   	 ALDrawLine(circX - ww/2, circY + gs, circX + ww/2, circY + gs)
      end
      
      if reset == 1 then
	 resetOn()
	 --print("ILS reset", reset)
	 --ALDrawPolyLine(2, 3, xLH, yLH, x+x0, y+y0, false)
	 --ALDrawPolyLine(2, 3, xRH, yRH, x+x0, y+y0, false)
	 resetOff()
      end
      ALFlush(true)
      
   end

   -- save old value
   ilsGaugeLocPrev[seq] = loc
   
end



-- ****

--local htextFirst = true

local htextValPrev = {0,0,0,0}

local function ALHtext(ty, reset, seq, ccfg, cff, cid, vv, label, unit)

   local x = ccfg.xlr;
   local y = ccfg.ylr;
   
   local width = ccfg.width;
   local height = ccfg.height;
   
   local x0 = cff.x0;
   local y0 = cff.y0;

   local val = vv or 0

   local txtW = cff.wid;
   --local txtH = cff.hgt;
   
   local valText; 
   if (ty == "ht") then
      valText = string.format("%.2f", val)
   else
      local secs;
      local plus = "+";
      local minus = "-";
      local spc = " ";
      local sign;
      local mins;
      local av = math.abs(val);
      local iv = math.floor(av);
      if (val > 0) then
	 sign = plus
      elseif (val < 0) then
	 sign = minus
      else
	 sign = spc
      end
      mins = math.floor(iv / 60)
      secs = iv - mins * 60;
      valText = string.format("%s%02d:%02d", sign, mins, secs);
   end
   
   local valX = x + x0 - width / 2 + RLwid(valText, 36) / 2;
   local valY = y + y0 - height / 2 + 18;
   
   local valXc = x + x0 - width / 2; 
   local valYc = y + y0 - height / 2;
   
   local lblX = x + x0; -- + RLwid(label, 16); 
   local lblY = y + y0 - height / 2 + 8;

   local unitX = x + x0 - txtW + RLwid(unit, 16);
   local unitY = y + y0 - height / 2 + 8;
   
   if (reset == 1) then
      --htextFirst = true;
      ALColorWhite()
      ALDrawText(label, 16, lblX, lblY, false)
      ALDrawText(unit, 16, unitX, unitY, false)
   end
   
   if (htextValPrev[seq] ~= val or seq == 0) then
      ALHold()
      ALColorBlack()
      ALDrawRectC(valXc, valYc, RLwid("000000", 36), 36, 0x34)
      ALColorWhite()
      ALDrawText(valText, 36, valX, valY, false)
      ALFlush()
   end
   
   -- save old values
   htextValPrev[seq] = val;
   --htextFirst = false;
   
end


-- ****

local hbarLowXprev = {0,0,0,0}
local hbarLowYprev = {0,0,0,0}
local hbarUpXprev = {0,0,0,0}
local hbarUpYprev = {0,0,0,0}
local hbarPctPrev = {0,0,0,0}

local function ALHbar (reset, seq, ccfg, cff, cid, val, val2, minV, maxV, mk, dd)
  
  local x = ccfg.xlr;
  local y = ccfg.ylr;
  
  local width = ccfg.width;
  --local height = ccfg.height;

  local x0 = cff.x0;
  local y0 = cff.y0;

  local barW = cff.wid;
  local barH = cff.hgt;

  local scale = cid.scale;

  local xlmin, ylmin, xlmax, ylmax, xlbl, ylbl;
  if scale == "variable" then
    xlmin = x + cff.xlmin;
    xlmax = x + cff.xlmax;
    ylmin = y + cff.ylmin;
    ylmax = y + cff.ylmax;
    xlbl = x + cff.xlbl;
    ylbl = y + cff.ylbl;
  end

  --print("xlmin, ylmin, xlmax, ylmax, xlbl, ylbl", xlmin, ylmin, xlmax, ylmax, xlbl, ylbl)
  
  local inpct, pct
  if val then
     inpct = (val - minV) / (maxV - minV);
     pct = math.max(0, math.min(inpct, 1)) --clip(0.0, 1.0, inpct);
  else
     pct = 0 -- hack for now, better to not draw value and bar if val is nil
  end
  
  --lower right
  local lowX = x + (width - x0);
  lowX = lowX + barW * (1 - pct);
  local lowY = y + y0;
  --upper left
  local upX = lowX + pct * barW;
  local upY = y + barH;

  --uint8_t img = dW.im;

  local maxText, minText, lblVal;

  if (scale == "variable") then
    minText = encdp(dd, minV);
    maxText = encdp(dd, maxV);
    lblVal = encdp(dd, val or 0);
  end

  --print("ALHbar, minV, maxV, val", minV, maxV, val, minText, maxText, lblVal)

  if (reset == 1 or hbarPctPrev[seq] ~= inpct) then

    ALHold();
    
    if (reset == 1) then
       --print("reset 1", xlmin, ylmin, minText, xlmax, ylmax, maxText)
      ALDrawTextC(minText, 16, xlmin, ylmin, false);
      ALDrawTextC(maxText, 16, xlmax, ylmax, false);
    elseif (reset == 0) then
      ALColorBlack(); --erase prev bar and value
      ALDrawRect(hbarLowXprev[seq], hbarLowYprev[seq], hbarUpXprev[seq], hbarUpYprev[seq],
		 0x34, false);
      if (scale == "variable") then
	 ALDrawRectC(xlbl, ylbl, RLwid("000000", 16), 16, 0X34)
      end
    end
    
    ALColorWhite();

    --draw box outline
    ALDrawRect(x+x0, y+y0, x+x0-barW, y+y0-barH, 0x33, false);
    --Serial.printf("mN %d mJ %d fine %d\n", dW.mN, dW.mJ, dW.f);

    local dx = barW / 4;
    for i = 1, 3, 1 do
      ALDrawLine(x+x0-i*dx, y+y0, x+x0-i*dx, y+y0-barH+3, false); --+3 fudge. roundoff errors?
    end

    
    --do not draw image in variable model
    --if (strcmp(scale, "variable") != 0) { 
    --  ALDrawScale(img, x, y);
    --}

    --draw bargraph filled box
    ALDrawRect(lowX, lowY, upX, upY, 0x34, false);

    --print("ALHbar: mk", mk)
    
    local markX;
    local mpct = ((mk or 0)- minV) / (maxV - minV);
    if (mpct> 0.0 and mpct < 1.0) then
      markX = x + (width - x0);
      markX = markX + barW * (1 - mpct);
      if (mpct > inpct) then
        --ALDrawRect(markX-1, lowY+4, markX+1, upY-4, 0x34, false);
        ALDrawRect(markX-2, lowY, markX+2, upY, 0x34, false);
      else
        ALColorBlack();
        ALDrawRect(markX-2, lowY, markX+2, upY, 0x34, false);
        ALColorWhite();
      end
    end
    
    if (scale == "variable") then
      ALDrawTextC(lblVal, 16, xlbl, ylbl, false);
    end

    ALFlush(true);
  end

  -- save old values
  hbarPctPrev[seq] = inpct;
  hbarLowXprev[seq] = lowX;
  hbarLowYprev[seq] = lowY;
  hbarUpXprev[seq] = upX;
  hbarUpYprev[seq] = upY;
  
end

-- ****

local tipXprev = {0,0,0,0};
local tipYprev = {0,0,0,0};
--local alphaDispXPrev= {0,0,0,0};

local function gaugeNew (seq, reset, x0, y0, x, y, minV, maxV, label, val, val2,
			 scale, mk, dp, xlbl, ylbl, width, height, rIn, rOut,
			 xlmin, ylmin, xlmax, ylmax, degMin, degMax,
			 ro, major, minor, fine, fm)

   val = val or 0
   mk = mk or 0
   
  local pct = (val - minV) / (maxV - minV);
  local mpct = (mk - minV) / (maxV - minV);

  local alphaDispF = 180 + (degMin + pct * (degMax - degMin));
  local alphaDispM = 180 + (degMin + mpct * (degMax - degMin));
  
  --local alphaDispX = (degMin + pct * (degMax - degMin));
  --local alphaDisp = math.floor(alphaDispF);

  local sinA = math.sin(math.rad(alphaDispF));
  local cosA = math.cos(math.rad(alphaDispF));

  local sinM = math.sin(math.rad(alphaDispM));
  local cosM = math.cos(math.rad(alphaDispM));
  
  local nlen = 0.75 * ro;

  local centX = x + x0;
  local centY = y + y0;

  -- tip of pointer
  local tipX = x + x0 + math.floor(sinA * nlen);
  local tipY = y + y0 - math.floor(cosA * nlen);

  local mX = x + x0 + math.floor(sinM * nlen);
  local mY = y + y0 - math.floor(cosM * nlen);



  ALHold(false)

  --try drawing every time to see if glasses can keep up .. needed for local display
  
  if true then --(reset == 1 or tipX ~= tipXprev[seq] or tipY ~= tipYprev[seq]) then

     local ww = RLwid("0000", 26);

    --local valX = xlbl + x + RLwid(valText, 26) / 2;
    --local valY = ylbl + y  + 26 / 2 + 26;
    
    if (reset == 0) then
       ALColorBlack()
       ALDrawRectC(xlbl + x, ylbl + y + 26, ww, 26, 0x34)
       ALDrawLine(tipXprev[seq], tipYprev[seq], centX, centY, false)
    end

    --value

    local valText = encdp(dp, val);
    
    ALColorWhite()

    --ALDrawRect(x + x0 - width/2, y + y0 - height/2, x + x0 + width/2, y + y0 + height/2, 0x33)
    
    if (reset == 1) then
       resetOn()
       --print("drawing scale and minmax labels", seq)

       ALDrawArc(centX, centY, ro, degMin - 90 - 1, degMax - 90, 4, false)
       --ALDrawCirc(centX, centY, ro, false)


       ALDrawScale(x+x0, y+y0, degMin - 1, degMax + 1, degMin, degMax, ro, major, minor,
		   fine, minV, maxV, scale);
       local sq
       if width == height then -- square gauge gets labels, half  gauges do not
	  sq = true
       else
	  sq = false
       end
       
       ALDrawMinMaxLabel(x, y, x0, y0, label, xlbl, ylbl,
			 xlmin, ylmin, xlmax, ylmax,
			 val, dp, minV, maxV, sq);
       resetOff()
    else
       -- leave this commented out for now .. we don't have any gauges with labels at the moment
    end

    ALDrawLine(tipX, tipY, centX, centY, false)
    if ( (mpct > 0.0) and (mpct < 1.0)) then
       ALDrawCircF(mX, mY, (nlen*0.1), false);
    end

    local valX = xlbl + x + RLwid(valText, 26) / 2;
    local valY = ylbl + y  + 26 / 2 + 26;

    if width == height then -- square gauges only
       ALDrawText(valText, 26, valX, valY, false)
    end

    -- save old values
    tipXprev[seq] = tipX;
    tipYprev[seq] = tipY;
    --alphaDispXPrev[seq] = alphaDispX;

     --print("else", seq, tipX, tipXprev[seq], tipY, tipYprev[seq])
  end

  ALFlush(true)

end


-- ****



local arcAnglePrev = {0,0,0,0}
--local arcFirstTime = {0,0,0,0}
local arcAngle = {0,0,0,0}

local function arcGauge(seq, reset, x0, y0, x, y, nv, xv, lbl, val, val2,
			as, ae, mk, dd, xlbl, ylbl, width, height, rIn, rOut,
			xlmin, ylmin, xlmax, ylmax)

   local pct, markPct
   local markAngle
   local arcStart = math.floor(as)
   local arcEnd = math.floor(ae)
   local thk = rOut - rIn
   --local sinM, cosM
   --local xm1, ym1, xm2, ym2
   local lblX, lblY
   local valText
   local valX, valY
   local minText
   local xlMin, xlMax
   local maxText
   local ylMin, ylMax
   --local valaX, valaY
   --local valbX, valbY
   local arcErase

   if not val then return end
   
   --local now = system.getTimeCounter()

   pct = (val - nv) / (xv - nv)
   markPct = (mk - nv) / (xv - nv)
   --ipct10 = math.floor(pct * 1000)

   arcAngle[seq] = arcStart + pct * (arcEnd - arcStart)
   markAngle = arcStart + markPct * (arcEnd - arcStart)

   arcStart = arcStart - 90
   arcAngle[seq] = arcAngle[seq] - 90

   --sinM = math.sin(math.rad(markAngle))
   --cosM = math.cos(math.rad(markAngle))
   
   --xm1 = x + x0 - sinM * (rIn - thk/4)
   --ym1 = y + y0 + cosM * (rIn - thk/4)
   --xm2 = x + x0 - sinM * rOut * 1.25
   --ym2 = y + y0 + cosM * rOut * 1.25

   lblX = xlbl + x + RLwid(lbl, 16) / 2
   lblY = ylbl + y + 16 / 2

   valText = encdp(dd, val)
   
   valX = xlbl + x
   valY = y + y0

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

   --valaX = x
   --valaY = y + y0 + 18

   --valbX = x + width
   --valbY = y + y0 - 18

   --****

   --local sbs = serialBytesSent
   ALHold(false)

   if true then -- reset == 1 or arcAnglePrev[seq] ~= arcAngle then
      ALColorBlack()
      ALDrawRectC(valX, valY, RLwid("0000", 26), 26, 0x34)
      ALDrawArc(x + x0, y + y0, rOut, arcStart, arcAnglePrev[seq], thk, false)
   end
   
   ALColorWhite()

   if reset == 1 then
      resetOn()
      ALDrawText(lbl, 16, lblX, lblY, false)
      ALDrawText(minText, 16, xlMin, ylMin, false)
      ALDrawText(maxText, 16, xlMax, ylMax, false)
      resetOff()
   end

   arcErase = arcAngle[seq]
   
   if (arcErase == arcStart) then
      arcErase = arcErase + 1;
   end
   
   ALDrawArc(x + x0, y + y0, rOut, arcStart, arcErase, thk, false)
   
   if ( (markPct > 0.0) and (markPct < 1.0) ) then
      if (markPct > pct) then
	 ALDrawArc(x + x0, y + y0, rOut, (markAngle - 2) - 90, (markAngle + 2) - 90, thk, false)
      else
	 ALColorBlack()
	 ALDrawArc(x + x0, y + y0, rOut, (markAngle - 2) - 90, (markAngle + 2) - 90, thk, false)
	 ALColorWhite()
      end
   end
   
   ALDrawTextC(valText, 26, valX, valY, false)
   ALFlush(false)
   
   arcAnglePrev[seq] = arcErase
   --print("serial bytes sent", serialBytesSent - sbs + 1)
end



local function sendAL(g)

   local gpp
   local ccfg, cid, fid, fmt, cff, ccf
   local min, max
   local xr, yr
   --local xc, yc
   local x0, y0
   local mk
   local dd
   local val, val2
   local xlbl, ylbl
   local width, height
   local xlmin, ylmin
   local xlmax, ylmax
   local lbl, units
   local minA, maxA
   local radius
   local major, minor, fine
   local rIn, rOut
   local seq

   --
   -- REMINDER: USE cfgimgESP table to send to the glasses!!!
   --

   gpp = Glass.page[pageNumberTele]
   if not gpp then
      print("sendAL: Glass.page[pageNumberTele] is nil")
      return
   end

   
   if not gpp[1].fmtNumber then gpp[1].fmtNumber = 1 end
   fmt = gpp[1].fmtNumber
   ccf =  cfgimgESP.config[fmt]

   --print("g", g)
   local t = gpp[g]
   
   --for g,t in ipairs(gpp) do        -- loop over all gauges on this page with a valid imageID
      --[[
	 if g <= 3  then
	 print("g, t.widgetID, t.imageID", g, t.widgetID, t.imageID)
      end
      --]]
      if t.widgetID > 0 and t.imageID >= 0 then        -- if there is a value to animate

	 --print("pageNumberTele, g", pageNumberTele, g)
	 
	 local rst
	 --if dest == "Jeti" then
	 --   seq = 0
	 --   rst = 1
	 --else
	 --   seq = g
	 --   rst = resetGlasses
	 --end

	 rst = resetGlasses
	 seq = g
	 
	 ccfg = ccf[g]                 -- this is the "config" key for this page and this widget
	 cid = cfgimgESP.instruments[t.widgetID]
	 fid = cid.formID + 1
	 cff = cfgimgESP.forms[fid]
	 --print("fid", fid)
	 xr = ccfg.xlr
	 yr = ccfg.ylr
	 width = ccfg.width
	 height = ccfg.height
	 --xc = xr + cfgimgESP.forms[fid].x0           -- for gauge, this is the pivot pt of the needle
	 --yc = yr + cfgimgESP.forms[fid].y0

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
	 rIn = cfgimgESP.forms[fid].radiusIn
	 rOut = cfgimgESP.forms[fid].radiusOut

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
	    units = t.units
	    val = t.value
	    val2 = t.value2
	    --local reset = 0
	    --print(g, cid.wtype,t.widgetID)

	    if cid.wtype == "oldgauge" then
	    elseif cid.wtype == "gauge" then
	       radius = cfgimgESP.forms[fid].radius
	       minA = cfgimgESP.forms[fid].minA
	       maxA = cfgimgESP.forms[fid].maxA	 
	       major = cfgimgESP.forms[fid].major
	       minor = cfgimgESP.forms[fid].minor
	       fine = cfgimgESP.forms[fid].fine
	       gaugeNew(seq, rst, x0, y0, xr, yr, min, max, lbl, val, val2,
			cid.scale, mk, dd, xlbl, ylbl, width, height, rIn, rOut,
			xlmin, ylmin, xlmax, ylmax, minA, maxA,
			radius, major, minor, fine)
	    elseif cid.wtype == "compass" then
	       ALCompass (rst, seq, ccfg, cff, cid, val, val2, min, max, lbl)
	    elseif cid.wtype == "hbar" then
	       ALHbar(rst, seq, ccfg, cff, cid, val, val2, min, max, mk, dd)
	    elseif cid.wtype == "vbar" then
	       ALVbar(rst, seq, ccfg, cff, cid, val, val2, min, max, mk, dd)	       
	    elseif cid.wtype == "htext" then
	       ALHtext ("ht", rst, seq, ccfg, cff, cid, val, lbl, units)
	    elseif cid.wtype == "timer" then
	       ALHtext ("ti", rst, seq, ccfg, cff, cid, val, lbl, units)
	    elseif cid.wtype == "arcGauge" then
	       local as = cfgimgESP.forms[fid].arcStart
	       local ae = cfgimgESP.forms[fid].arcEnd
	       arcGauge(seq, rst, x0, y0, xr, yr, min, max, lbl, val, val2,
			as, ae, mk, dd, xlbl, ylbl, width, height,
			rIn, rOut, xlmin, ylmin, xlmax, ylmax)
	    elseif cid.wtype == "ahGauge" then
	       ALAhGauge (rst, seq, ccfg, cff, cid, val, val2)
	    elseif cid.wtype == "vltape" then
	       ALVertTape (rst, seq, ccfg, cff, cid, val)	       
	    elseif cid.wtype == "ils" then
	       ALILSGauge (rst, seq, ccfg, cff, cid, val, val2)
	    end
	 end
      end
   --end
   --if dest == "Glass" then
      --resetGlasses = 0
   --end
   --print("#savedSerial", #savedSerial)
end


local lastSend = 0
local linecount = 0
local enterWaiting = 0
local oncePerSecond = 0

local function loop()
   local now = system.getTimeCounter()
   local unow = system.getTimeCounter()
   local sensor, sval, sval2
   local stbl = {}
   -- temporarily made global -- local gtbl = {}
   local scale
   local minV, maxV

   if Glass.settings.latId ~= 0 and Glass.settings.latPa ~= 0 and Glass.settings.lngPa ~= 0 then
      Glass.var.currentPosition = gps.getPosition(Glass.settings.latId,
						  Glass.settings.latPa, Glass.settings.lngPa)
   end
      
   local alt = 0
   if Glass.settings.altId ~= 0 and Glass.settings.altPa ~= 0 then
      sensor = system.getSensorByID(Glass.settings.altId, Glass.settings.altPa)
      if sensor and sensor.valid then
	 alt = sensor.value - (Glass.var.startTakeoffAlt or 0)
      end
   end
   
   --print("start->to Distance: ", gps.getDistance(Glass.var.startTakeoff, Glass.var.gearUp))
   --print("start->to Bearing: ", gps.getBearing(Glass.var.startTakeoff, Glass.var.gearUp))

   if Glass.var.currentPosition then
      --print("curr->start Distance: ", gps.getDistance(Glass.var.currentPosition, Glass.var.startTakeoff))
      --print("curr->start Bearing: ", gps.getBearing(Glass.var.currentPosition, Glass.var.startTakeoff))
      local GSdeg = 6
      local curr2gearUpB = gps.getBearing(Glass.var.currentPosition, Glass.var.gearUp)
      local gearUp2toB = gps.getBearing(Glass.var.startTakeoff, Glass.var.gearUp)
      local curr2gearUpD = gps.getDistance(Glass.var.currentPosition, Glass.var.gearUp)
      local curr2toD = gps.getDistance(Glass.var.currentPosition, Glass.var.startTakeoff)
      local curr2toB = gps.getBearing(Glass.var.currentPosition, Glass.var.startTakeoff)
      local gearUp2toD = gps.getDistance(Glass.var.startTakeoff, Glass.var.gearUp)
      local deltaB = curr2gearUpB - gearUp2toB
      --local deltaD = curr2toD
      if math.abs(deltaB) < 30 then
	 Glass.var.ilsLoc = -deltaB
	 if curr2toB - gearUp2toB > 0 and curr2toB - gearUp2toB < 90 then
	    Glass.var.ilsGS = math.deg(math.atan(alt, math.abs(curr2toD))) - GSdeg
	 else
	    Glass.var.ilsGS = nil
	 end
      else
	 Glass.var.ilsLoc = nil
	 Glass.var.ilsGS = nil
      end
   else
      --print("no currentPosition")
   end
   
   if system.getTimeCounter() > oncePerSecond and sendState == state.COMPLETE then
      --Glass.var.output = "Glass"
      ALBattCheck()
      oncePerSecond =system.getTimeCounter() + 1000
   end

   if emflag ~= 0 then
      local P4 = system.getInputs("P4") -- to show json only on emulator
      if P4 then
	 LOOPTIME = 250*(P4 + 1)
	 --print("LOOPTIME", LOOPTIME)
      end
   end

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
      Glass.var.statusAL.Conf == Glass.var.statusAL.GlassConf then 
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
   now = system.getTimeCounter()

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

   local swb = system.getInputs("SB") -- SB to force sending only on emulator
   local forceSend = (swb and swb == 1)

   if forceSend or sendState == state.COMPLETE and system.getTimeCounter() > jsonHoldTime then
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
	       now = system.getTimeCounter()
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
			--print("P2 minV maxV", minV, maxV)
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
		     if v.zeroOffset then
			v.value = v.value - v.zeroOffset
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
			--print("P1 minV maxV", minV, maxV)			
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
		  stbl[k].im = v.imageID
		  stbl[k].wd = v.widgetID - 1
		  stbl[k].fm = cfgimg.instruments[v.widgetID].formID
		  stbl[k].wt = string.sub(cfgimg.instruments[v.widgetID].wtype,0,2)
		  if sval then
		     stbl[k].v = tonumber(sval)
		     if cfgimg.instruments[v.widgetID].wtype == "htext" then
			stbl[k].u = Glass.page[pageNumberTele][k].units
			stbl[k].d = Glass.page[pageNumberTele][k].decimals
			stbl[k].l=Glass.page[pageNumberTele][k].instName
		     elseif cfgimg.instruments[v.widgetID].wtype == "arcGauge" then
			stbl[k].d = Glass.page[pageNumberTele][k].decimals
		     elseif cfgimg.instruments[v.widgetID].wtype == "timer" then
			stbl[k].u = ""
			stbl[k].l = Glass.page[pageNumberTele][k].instName
		     else
			stbl[k].u = nil
		     end
		  end
		  if sval and sval2 then
		     stbl[k].v2 = tonumber(sval2)
		  end
		  if scale == "variable" and sval then
		     stbl[k].nV = tonumber(sv(2, minV))
		     stbl[k].xV = tonumber(sv(2, maxV))
		     stbl[k].l = Glass.page[pageNumberTele][k].instName

		     stbl[k].mJ = Glass.page[pageNumberTele][k].major
		     stbl[k].mN = Glass.page[pageNumberTele][k].minor		     
		     stbl[k].f = Glass.page[pageNumberTele][k].fine
		     stbl[k].fM = Glass.page[pageNumberTele][k].ticfmt		     
		  end
	       end
	       gtbl.v[k] = tonumber(sval) or 0 -- avoid json "null" for unset v[]
	       gtbl.v2[k] = tonumber(sval2) or 0 -- avoid json "null" for unset v2[]
	    end

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
	    if form.getActiveForm() then
	       --print("getActiveForm")
	       sendJson = false
	    end
	 end
	 
	 if sendJson or (emflag ~= 0 and forceSend) then
	    
	    if emflag ~= 0 then
	       local swa = system.getInputs("SA") -- SA to show json only on emulator
	       if swa and swa == 1 then
		  --print(espjson) -- what happened to espjson?
	       end
	    end

	    loopCPU = system.getCPU()

	    local fmt = Glass.page[pageNumberTele][1].fmtNumber
	    local numInsts = #cfgimg.config[fmt]

	    if sendJson or forceSend then --system.getTimeCounter() - lastSend > (1*LOOPTIME) then
	       --print("=================> sendAL")
	       --Glass.var.output = "Glass"
	       sendIndex = sendIndex + 1
	       if sendIndex <= numInsts then
		  sendAL(sendIndex)
	       end
	       if sendIndex >= numInsts and ((system.getTimeCounter() - lastSend) > LOOPTIME) then
		  local cc, err
		  teleSerialReset = {}
		  teleSerial = {}
		  for k,v in ipairs(savedSerialReset) do
		     teleSerialReset[k] = v
		     cc, err = serial.write(sidSerial, v)
		     if not cc then
			print("DFM-HUD: serial write error " .. err)
		     else
		     serialBytesSent = serialBytesSent + cc
		     end
		  end
		  for k,v in ipairs(savedSerial) do
		     teleSerial[k] = v
		     cc, err = serial.write(sidSerial, v)
		     if not cc then
			print("DFM-HUD: serial write error " .. err)
		     else
		     serialBytesSent = serialBytesSent + cc
		     end
		  end
		  sendIndex = 0
		  --print(#savedSerialReset, #savedSerial)
		  savedSerial = {}
		  resetGlasses = 0
		  --print("delta t", (system.getTimeCounter() - (lastSend or 0))/1000)
		  lastSend = system.getTimeCounter()
	       end
	    end
	 end
	 lastWrite = now
      end

   end

   if unow <= jsonHoldTime then return end

   --Glass.var.output = "Glass" -- just in case...

   if sendState == state.DISCONNECTED then
      print("DFM-HUD: DISCONNECTED - sending config request")
      local bufCfg = "FFD302070101AA"
      --bw = serialWrite(sidSerial, 0xFF, 0xD3, 0x02, 0x07, 0x01, 0x01, 0xAA) -- read config
      local bw = serialWriteDirect(sidSerial, encodeBuf(bufCfg)) -- read config
      if not bw then
	 print("DFM-HUD: cannot write config query")
	 jsonHoldTime = unow + 1000
      end
      print("DFM-HUD: WAITING for Glasses")
      sendState = state.WAITING -- wait for onRead to get config list
      enterWaiting = system.getTimeCounter()
   end

   if sendState == state.WAITING then
      --just spin, when config is available, sendState will be set to CONNECTED
      --print("sendState WAITING")
      if system.getTimeCounter() - enterWaiting > 2000 then --no response to config request in 2 sec
	 sendState = state.DISCONNECTED
	 print("DFM-HUD: No cfg response .. set DISCONNECTED and retry")
	 jsonHoldTime = unow + 1000 -- wait 1 more sec then try config request again
      end
   end

   if sendState == state.SELECT then
      local bufSet = "FFD2000D" .. appHex .. "00AA"      
      local bufClr = "FF010005AA"
      local bufFls = "FF390006FFAA"

      print("DFM-HUD: Enter state SELECT")
      
      local bw1, bw2, bw3
      bw1 = serialWriteDirect(sidSerial, encodeBuf(bufSet)) -- set glasses to our app
      bw2 = serialWriteDirect(sidSerial, encodeBuf(bufClr)) -- clear screen
      bw3 = serialWriteDirect(sidSerial, encodeBuf(bufFls)) -- flush, set to known state
      
      if not bw1 or not bw2 or not bw3 then
	 print("DFM-HUD: cannot write select")
	 if sendFP then io.close(sendFP) end
	 sendState = state.DISCONNECTED
	 jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
      else
	 print("DFM-HUD: state COMPLETE")
	 sendState = state.COMPLETE
	 writeInst() 
	 jsonHoldTime = unow + 1000 -- wait 1s to allow setup, clear, flush
	 resetGlasses = 1
      end
   end
   
   if sendState == state.CONNECTED then 
      if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
      system.messageBox("Preparing Glasses for DFM-HUD")
      sendFP = io.open(prefix() .. pathConfigs .. "config-fonts.txt", "r")
      if not sendFP then
	 print("DFM-HUD: cannot open font config")
	 sendState = state.DISCONNECTED
	 jsonHoldTime = unow + 1000
      else
	 print("DFM-HUD: opened config-fonts.txt")
	 sendState = state.SENDHEADER
      end
      linecount = 0
      serialBytesSent = 0
      startingTime = system.getTimeCounter()
   end
   
   if (sendState == state.SENDHEADER) or (sendState == state.SENDFOOTER) then
      
      if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
      
      local cfgVersion = 1
      local cfgKey = 1
      local bufPre = "FFD00015" .. appHex .. "00"

      local bufH = bufPre .. string.format("%08X%08X", 0, cfgKey) .. "AA"
      local bufF = bufPre .. string.format("%08X%08X", cfgVersion, cfgKey) .. "AA"
      local bw
            
      if sendState == state.SENDHEADER then
	 print("sending header")
	 bw = serialWriteDirect(sidSerial, encodeBuf(bufH))
	 if not bw then
	    print("DFM-HUD: cannot write header")
	    if sendFP then io.close(sendFP) end
	    sendState = state.DISCONNECTED
	    jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
	 else
	    sendState = state.SENDFILE
	 end
      end

      if sendState == state.SENDFOOTER then
	 print("DFM-HUD: Sending config footer")
	 bw = serialWriteDirect(sidSerial, encodeBuf(bufF))

	 if not bw then
	    print("DFM-HUD: cannot write footer")
	    if sendFP then io.close(sendFP) end
	    sendState = state.DISCONNECTED
	    jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
	 else
	    print("set state to SELECT")
	    sendState = state.SELECT
	 end
	 
	 local dt = system.getTimeCounter() - startingTime
	 serialFileName = string.format("Transfer complete. Time: %.2f s", dt / 1000.0)
	 print(string.format("Send config done. Time: %.2f s", dt / 1000))
	 print(string.format("%d bytes sent. Aggregate data rate: %.1f kB/s",
			     serialBytesSent, serialBytesSent / dt))
	 system.messageBox("Complete " .. serialBytesSent .. " bytes sent")
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
   local bw
   if sendState == state.SENDFILE then
      --print("sendState is SENDFILE")
      
      for i=1, LINESPERLOOP, 1 do
	 line = io.readline(sendFP, true)
	 linecount = linecount + 1
	 if not line then
	    print("io,readline EOF")
	    sendState = state.SENDFOOTER
	    if sendFP then io.close(sendFP) end
	    break
	 else
	    local ll
	    local ldx=1
	    local chunk = 100
	    repeat
	       ll = string.sub(line, ldx, ldx + chunk - 1)
	       ldx = ldx + chunk
	       print("> "..ll)
	       bw = serialWriteDirect(sidSerial, encodeBuf(ll))
	       --print("write encoded line, bw", bw, #line)
	    until ldx >= #line
	    
	    if not bw then
	       print("DFM-HUD: cannot write line of config file")
	       if sendFP then io.close(sendFP) end
	       sendState = state.DISCONNECTED
	       jsonHoldTime = unow + 1000
	       break
	    end
	 end
	 jsonHoldTime = unow + 100
      end
   end

   --loopCPU = loopCPU + (system.getCPU() - loopCPU) / 10

   
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
      --local imageID = Glass.page[pageNumber][gaugeNumber].imageID
      local fn = Glass.page[pageNumber][1].fmtNumber
      local wid = cfgimg.config[fn][gaugeNumber].width
      local hgt = cfgimg.config[fn][gaugeNumber].height
      --local label

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
	    print("DFM-HUD: no images for", pageNumber, gaugeNumber)
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
	 --form.setButton(1, "USB",   ENABLED)
      end
      
      local function switchChanged(val, name)
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
      

      --local function cvchanged(val)
      --Glass.settings.configVersion = val
      --end

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
      
      local altsel = 0
      for k = 1, #Glass.sensorLalist do
	 if (Glass.sensorIdlist[k] == Glass.settings.altId) and
	    (Glass.sensorPalist[k] == Glass.settings.altPa) then
	    altsel = k
	 end
      end
      

      form.addRow(2)
      form.addLabel({label="Page change switch"})
      swtCI.pageChange = form.addInputbox(switchItems.pageChange, true,
					  (function(x) return switchChanged(x, "pageChange") end)
      )
      
      form.addRow(2)
      form.addLabel({label="Takeoff switch"})
      swtCI.takeoffChange = form.addInputbox(switchItems.takeoffChange, true,
					  (function(x) return  switchChanged(x, "takeoffChange") end)
      )
      
      form.addRow(2)
      form.addLabel({label="Gear up switch"})
      swtCI.gearUpChange = form.addInputbox(switchItems.gearUpChange, true,
					  (function(x) return  switchChanged(x, "gearUpChange") end)
      )

      --form.addRow(2)
      --form.addLabel({label="Set config version"})
      --form.addIntbox(Glass.settings.configVersion, 0, 32767, 1, 0, 1, cvchanged)

      form.addRow(2)
      form.addLabel({label="GPS Lat Sensor", font=FONT_NORMAL})
      form.addSelectbox(Glass.gpsLalist, latsel, true,
			(function(i)
			      Glass.settings.latId = Glass.gpsIdlist[i]
			      Glass.settings.latPa = Glass.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="GPS Lng Sensor", font=FONT_NORMAL})
      form.addSelectbox(Glass.gpsLalist, lngsel, true,
			(function(i)
			      Glass.settings.lngId = Glass.gpsIdlist[i]
			      Glass.settings.lngPa = Glass.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="Altitude Sensor", font=FONT_NORMAL})
      form.addSelectbox(Glass.sensorLalist, altsel, true,
			(function(i)
			      Glass.settings.altId = Glass.sensorIdlist[i]
			      Glass.settings.altPa = Glass.sensorPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      --form.addRow(1)
      --form.addLink((function() sendUSB() form.reinit(15) return end),
      --{label="Send config on serial>>"})

      form.addRow(1)
      form.addLink((function() form.reinit(14) return end), {label="Timer setup>>"})      

      form.addRow(1)
      form.addLink(clearJSON, {label="Reset app settings>>"})
      
      --form.addRow(1)
      --form.addLink((function() sendUSB("full") form.reinit(15) return end), {label="Set up AL Glasses>>"})
      form.addRow(1)
      form.addLink(
	 (
	    function()
	       otaTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       if Glass.settings.rebootDisco then
		  system.messageBox("Turn off reboot disconnect")
	       else
		  gpio.write(5,1)
		  print("gpio 5 set high")
		  system.messageBox("OTA update initialized")
		  Glass.var.timeOTA = system.getTimeCounter()
		  --form.reinit(11)
	       end
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
	 end), {label="Cycle Power AL controller>>"}
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
      form.addLabel({label="Zero offset", font=FONT_NORMAL})

      if not Glass.page[pageNumber][gaugeNumber].zeroOffset then
	 Glass.page[pageNumber][gaugeNumber].zeroOffset = 0
      end
      
      local function changedZeroOffset(val)
	 Glass.page[pageNumber][gaugeNumber].zeroOffset = val
      end
      
      local zo = Glass.page[pageNumber][gaugeNumber].zeroOffset
      form.addIntbox(zo, -32768, 32767, 0, 0, 1, changedZeroOffset)

      form.addRow(2)
      form.addLabel({label="Marker value", font=FONT_NORMAL})

      local mk = Glass.page[pageNumber][gaugeNumber].marker or 0
      
      if not Glass.page[pageNumber][gaugeNumber].marker then
	 Glass.page[pageNumber][gaugeNumber].marker = mk
      end
      
      local function changedMarker(val)
	 Glass.page[pageNumber][gaugeNumber].marker = val
	 --print("marker", val)
      end
      
      form.addIntbox(mk, -32768, 32767, 0, 0, 1, changedMarker)
      
      form.addRow(2)
      form.addLabel({label="Gauge Name:", font=FONT_NORMAL})
      form.addTextbox(Glass.page[pageNumber][gaugeNumber].instName, 10,
		      (function(x) return changedName(x, inpN) end),
		      {width=155, font=FONT_NORMAL})

      
   elseif sf == 13 then

      local id, minV, maxV
      
      --fn = Glass.page[pageNumber][1].fmtNumber
      id = Glass.page[pageNumber][gaugeNumber].widgetID
      if id < 0 then
	 print("DFM-HUD: no images")
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
      local hrs=0
      local mins, secs, sign      
            
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
      isel = string.find("+-", (Glass.timers.timer1.targetUD or "+"))
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
      --local swe = "t1enable"
      swtCI.t1enable = form.addInputbox(switchItems.t1enable, true,
		       (function(x) return changedSwitch(x, "t1enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      --local swr = "t1reset"
      swtCI.t1reset = form.addInputbox(switchItems.t1reset, true,
		       (function(x) return changedSwitch(x, "t1reset") end),
		       {width=100}
      )

      -------------------------------------------------------------------------
      
      form.addRow(1)
      form.addLabel({label=string.rep(" ", 28) .. "Timer 2", font=FONT_BOLD})

      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      isel = string.find("+-", (Glass.timers.timer2.initialUD or "+"))
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
      isel = string.find("+-", (Glass.timers.timer2.targetUD or "+"))
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
      --local swe = "t2enable"
      swtCI.t2enable = form.addInputbox(switchItems.t2enable, true,
		       (function(x) return changedSwitch(x, "t2enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      --local swr = "t2reset"
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
	 iid = 0
	 local wid = 0
	 local min, max, wtype, inp
	 --print("key2: imageNum, editImgs[imageNum].widgetID", imageNum, editImgs[imageNum].widgetID)
	 
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
   --local ww = lcd.getTextWidth(FONT_MINI, lbl)
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
   --local xb
   --local xs
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
   --local fudge = 131 -- extra bytes sent that are not in files
   if subForm == 15 then
      lcd.setColor(0,0,255)
      --lcd.drawFilledRectangle(10, 20, (w-20) * serialBytesSent / (totalSendBytes + fudge), 30)
      lcd.setColor(0,0,0)
      lcd.drawText(10, 60, string.format("Bytes sent: %d", serialBytesSent))
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
	    r = 144/160
	    --print(xi + ww / 2, yi + hh / 2, rr)
	    drawahGauge(xi + ww / 2 - 8, yi + hh / 2 - 8, r * rr, r * hh, r * ww)
	 elseif editImgs[imageNum].wtype == "ils" then
	    local id = editImgs[imageNum].widgetID
	    local fid = cfgimg.instruments[id].formID + 1	    
	    local hh, ww = cfgimg.forms[fid].height, cfgimg.forms[fid].width	    
	    local rr = ww / 2
	    r = 144/160
	    --print(xi + ww / 2, yi + hh / 2, rr)
	    drawILSGauge(xi + ww / 2 - 8, yi + hh / 2 - 8, r * rr, r * hh, r * ww)
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
	    r = 130/160
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
   local dR = (maxR - minR) / major
   local alpha
   local sinA, cosA
   local xo, yo, xi, yi
   local ri
   local ren=lcd.renderer()
   
   for tick = 0, major, 1 do
      ri = ro * 0.80
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
      --print(minA, maxA)
      --lcd.drawLine(x0 + xo, y0 + yo, x0 + xi, y0 + yi)
   end
   drawArc(math.rad(maxA + 90) - math.rad(minA + 90), x0, y0,
	   math.rad(minA + 90), math.rad(maxA + 90), ro - 2, ro, 20, 1)
end

local function drawScaleOld(x0, y0, minA, maxA, major, minor, fine, ro)
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
	 if (Glass.var.statusAL.Conf == Glass.var.statusAL.GlassConf) then -- 
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

   local r = 160 / 256 -- show the glasses space (304x256) in Jeti screen (320x160) .. scale by 160/256
   local offset = (319 - r * 304) / 2 -- center the shrunk glasses space on the Jeti screen
   local fmt
   local gpp
   local sgc

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
	 if (Glass.var.statusAL.Conf == Glass.var.statusAL.GlassConf) then 
	    lcd.drawImage(295, 15, greencheckIcon)
	 else
	    lcd.drawImage(295, 15, yellowpauseIcon)	    
	 end
      else
	 lcd.drawImage(295, 15, yellowpauseIcon)	 
      end
      --drawTextCenter(287,120, string.format("C:%d", Glass.var.statusAL.Conf), FONT_MINI)
      --drawTextCenter(287,135, string.format("CG:%d", Glass.var.statusAL.GlassConf), FONT_MINI)
      drawTextCenter(287,135, string.format("%d", Glass.var.statusAL.Conf), FONT_MINI)
   end
      
   if Glass.var.statusAL and Glass.var.statusTime and Glass.var.statusAL.Conn == 1 and
      system.getTimeCounter() < Glass.var.statusTime + 5000 then
      drawTextCenter(287, 90, "G", FONT_MINI)
   else
      local now = system.getTime()
      drawTextCenter(287, 90, "Searching", FONT_MINI)
      if now > initTime + 2 and wasEverGreen and Glass.settings.rebootDisco then
	 wasEverGreen = false
	 if Glass.var.statusAL then
	    Glass.var.statusAL.Conn = 0 -- note that we are no longer connected
	 end
	 restartTimer = system.getTimeCounter() + 500 -- set high for 500ms
	 gpio.write(6,1)
	 print("gpio 6 set high rebootDisco")
	 system.messageBox("Rebooting AL controller")
	 system.playBeep(2, 440, 200)
	 sendState = state.DISCONNECTED
      end
   end
   
   if not pageNumberTele or pageNumberTele < 1 then return end

   local xr, yr, xc, yc
   local min, max, val, val2, lbl
   local ccfg, cid, fid

   gpp = Glass.page[pageNumberTele]
   if not gpp then
      lcd.drawTextCenter(160, 80, "No pages defined")
      print("DFM-HUD: Glass.page[pageNumberTele] is nil")
      return
   end

   local legacy = false
   
   --Glass.var.output = "Jeti"
   --if (not legacy) then 
   --   sendAL("Jeti")
   --end

   if not legacy then
      for k,v in ipairs(teleSerialReset) do
	 decodeAL(v, "Jeti")
      end
      for k,v in ipairs(teleSerial) do
	 decodeAL(v, "Jeti")
      end
   end
   
   --Glass.var.output = "Glass"

   -- ***
   if (legacy) then
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

	       local xcc, ycc
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
	    elseif cid.wtype == "ils" then
	       local hh = cfgimg.forms[fid].width
	       local ww = cfgimg.forms[fid].height
	       if val then
		  drawILSGauge(offset + r * xc, r * yc, r * (ww - 10) / 2, r*hh, r*ww, val, val2)
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
   end -- if false
   -- ***
   
   sgc = system.getCPU()

   if emflag ~= 0 then
      lcd.drawText(10,130, string.format("%d", sgc))
      lcd.drawText(10,110, string.format("%d", loopCPU))
      lcd.drawText(10, 90, string.format("%d", LOOPTIME))
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
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa"
	 or k == "altId" or k == "altPa" then
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

--local savedData
local onReadBuf = ""

local function onRead(indata)

   local MAX_ALOOK_CMD = 533
   local cmd_len
   local command
   
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

      --print("onRead", string.format("0x%02x", string.byte(command,2)))
      
      if string.byte(command, 2) == 0xD3 then -- cfglist
	 local name, size, version, usgCnt, installCnt, isSystem
	 print("DFM-HUD onRead: cfgList response")
	 local i = 7 -- first char of cfg payload (see AL docs section 4.14)
	 local DFMHUDVersion = -1

	 -- DFMHUDCurrentVersion is the version of the font  file (config-fonts.txt) which
	 -- has the expected fonts and is built by the build system in ~/JS/GlassBuild
	 -- if changing/adding/deleting fonts, increment this value so that the app reloads
	 -- the fonts into the DFM-HUD ALook application
	 -- Future: could read the file config-fonts.json and get the list of font codes and sizes
	 -- and could add a version number to that file
	 
	 local DFMHUDCurrentVersion = 1
	 repeat
	    name, size, version, usgCnt, installCnt, isSystem =
	       string.unpack(">zI4I4I1I1I1", command, i)
	    print(string.format("Name: %s Size %d Version %d", name, size, version))
	    if name == "DFM-HUD" then
	       DFMHUDVersion = version
	       Glass.var.statusAL.GlassConf = version
	    end
	    i = i + #name + 1 + 11
	 until i >= cmd_len

	 if DFMHUDVersion ~= DFMHUDCurrentVersion then
	    sendState = state.CONNECTED --send the preparation info and font file
	 else
	    --sendState = state.CONNECTED -- for testing .. do every time
	    sendState = state.SELECT -- glasses have current info 
	 end

      elseif string.byte(command, 2) == 0x05 then -- battery level
	 --print("DFM-HUD Battery level (%)", string.byte(command, 5))
	 Glass.var.statusAL.Batt = string.byte(command, 5)
	 Glass.var.statusAL.Conn = 1
	 lastRead = system.getTime()	 
	 Glass.var.statusTime = system.getTimeCounter()
      elseif string.byte(command, 2) == 0x50 then -- font list
	 print("DFM-HUD onRead: font list response")
	 local id, height
	 local i = 7 -- first char of cfg payload (see AL docs section 4.14)
	 repeat
	    id, height = string.unpack(">I1I1", command, i)
	    print("id " .. id .. " height " .. height)
	    i = i + 2
	 until i >= cmd_len
      elseif string.byte(command,2) == 0xE2 then -- error
	 local cmdId, err, subErr = string.unpack(">I1I1I1", command, 5)
	 print(string.format("DFM-HUD: onRead -  cmdID 0x%02x, error 0x%02x, subErr 0x%02x",
			     cmdId, err, subErr))
      else
	 print("DFM-HUD: onRead - command[2]", string.format("0x%02x", string.byte(command,2)))
	 local str = "DFM-HUD: onRead full response: "
	 for i=1,#command,1 do
	    str = str .. string.format("0x%02X ", string.byte(command, i))
	 end
	 print(str)
      end
      
   end

   --if buffer has more commands, recurse to process
   
   if #onReadBuf > 0 then onRead("") end
   
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

   --print("CPU Entry ", system.getCPU())

   Glass.var.statusAL = {}
   Glass.var.statusAL.Conf = 1 -- this is the required version of the glasses config
   Glass.var.statusAL.GlassConf = 0
   Glass.var.statusAL.Conn = 0
   Glass.var.statusAL.Batt = 0
   
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
      system.messageBox("DFM-HUD: Cannot read " .. fn)
      return
   end

   fn = prefix() .. pathJson .. "instrESP.jsn"
      
   file = io.readall(fn)
   cfgimgESP = {}
   if file then
      cfgimgESP = json.decode(file)
      print("Glass - Reading avail instruments (ESP) from ", fn)
   else
      system.messageBox("DFM-HUD: Cannot read " .. fn)
      return
   end

   --print("CPU 0: ", system.getCPU())

   local ratio = 144 / 160 -- ratio of "small" images to jeti screen height
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
	 print("img.imageID, img.formID, #cfgimg.forms", img.imageID, img.formID, #cfgimg.forms)
	 local ww = cfgimg.forms[img.formID + 1].width
	 local hh = cfgimg.forms[img.formID + 1].height
	 img.origWidth = ww or 0
	 img.origHeight = hh or 0
	 img.imageWidth = (ww or 0) * ratio
	 img.imageHeight = (hh or 0) * ratio
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
	 print("DFM-HUD: Error setting callback", descr)
      end
   else
      print("DFM-HUD - Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "Glasses Display", 4, printTele)
   system.registerTelemetry(2, "Glasses Status", 1, printTeleSmall)   

   local function initG()
      print("DFM-HUD: - No saved state")

      Glass.page = {}
      pageMax = #Glass.page
      pageNumber = 0
      gaugeNumber = 1

      Glass.settings = {}
      Glass.settings.latId = 0
      Glass.settings.latPa = 0
      Glass.settings.lngId = 0
      Glass.settings.lngPa = 0
      Glass.settings.altId = 0
      Glass.settings.altPa = 0
      
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
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa"
	 or k == "altId" or k == "altPa" then
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

   --Glass.var.output = "Glass"

   --debugging GPS points for ILS at Black Dirt Field
   
   if emFlag ~= 0 then
      Glass.settings.latId = 3
      Glass.settings.latPa = 2
      Glass.settings.lngPa = 3
      Glass.var.startTakeoff = gps.newPoint(41.34062, -74.43160)
      Glass.var.gearUp = gps.newPoint(41.33827, -74.43077)
   end
      
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

   
  
end

return {init=init, loop=loop, author="DFM", destroy=destroy, version="1.00", name=appName}
