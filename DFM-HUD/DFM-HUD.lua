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
--local logFileFP
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
	       COMPLETE=7, SELECT=8, ALMOST=9}
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
--local currentConfigIDs
local serialBytesSent = 0
--local totalSendBytes
local serialFileName
local lastRead = 0
local resetGlasses

--local gtbl = {}

local initTime
local LOOPTIME = 80

local savedSerial = {}
local savedSerialReset = {}
local teleSerial = {}
local teleSerialReset = {}
local sendIndex = 0
local splashScreen
local pos3D = {}
pos3D.x = {}
pos3D.y = {}
pos3D.z = {}

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
--local ALisBlack = false

local function resetOn()
   resetState = true
end
local function resetOff()
   resetState = false
end

local function sendUSB(text)
   print("sendUSB: " .. text)
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

local function encodeBuf(str)
   local ret
   ret = str:gsub("(%x%x)", (function(s) return string.char(tonumber(s,16)) end))
   return ret
end

local greyB = 0

local function decodeAL(ps, rr, xoffset, yoffset, wid, hgt)
   local gw = 304
   local gh = 256
   local str
   local x1, y1, x2, y2
   local x1j, y1j, x2j, y2j
   local r, f, c, t, r1, r2
   local b = string.byte(ps, 2)
   local q = string.byte(ps, 3)
   local qr
   local xt = {}
   local yt = {}
   local xtj = {}
   local ytj={}

   if q~=0 and q~=2 then -- if need other command fmts need to support here - see AL docs sec 3.1
      return
   end
   
   local function Xa2jc(x)
      return math.floor(rr * ((wid - x) - wid / 2)) + xoffset
   end

   local function Ya2jc(y)
      return math.floor(rr * ((hgt - y) - hgt / 2)) + yoffset
   end
   
   -- set persisted Jeti color
   lcd.setColor(greyB, greyB, greyB)
      
   if b == 0x30 then --color
      local grey = string.byte(ps, 5)
      greyB = grey | grey<<4
      lcd.setColor(greyB, greyB, greyB)
      
   elseif b == 0x31 then -- point
      if q == 0 then
	 x1, y1 = string.unpack(">i2i2", ps, 5)
      elseif q == 2 then
	 qr, x1, y1 = string.unpack(">I2i2i2", ps, 5)	 
      end
      x1j = Xa2jc(x1)
      y1j = Ya2jc(y1)
      lcd.drawPoint(x1j, y1j)
      
   elseif b == 0x32 then --line
      if q == 0 then
	 x1, y1, x2, y2 = string.unpack(">i2i2i2i2", ps, 5)
      elseif q == 2 then
	 qr, x1, y1, x2, y2 = string.unpack(">I2i2i2i2i2", ps, 5)	 
      end
      x1j = Xa2jc(x1) --math.floor(math.floor(rr*(gw - x1)) + xoffset)
      y1j = Ya2jc(y1) --math.floor(rr*(gh - y1) + yoffset)
      x2j = Xa2jc(x2) --math.floor(math.floor(rr*(gw - x2)) + xoffset)
      y2j = Ya2jc(y2) --math.floor(rr*(gh - y2) + yoffset)
      lcd.drawLine(x1j, y1j, x2j, y2j)
      
   elseif b == 0x33 then --rect
      if q == 0 then
	 x1, y1, x2, y2 = string.unpack(">i2i2i2i2", ps, 5)
      elseif q == 2 then
	 qr, x1, y1, x2, y2 = string.unpack(">I2i2i2i2i2", ps, 5)
      end
      x1j = Xa2jc(x1) --math.floor(math.floor(rr*(gw - x1)) + xoffset)
      y1j = Ya2jc(y1) --math.floor(rr*(gh - y1) + yoffset)
      x2j = Xa2jc(x2) --math.floor(math.floor(rr*(gw - x2)) + xoffset)
      y2j = Ya2jc(y2) --math.floor(rr*(gh - y2) + yoffset)
      --print("###>rect", x1, y1, x2, y2)
      --print("R",math.min(x1j, x2j), math.min(y1j, y2j),
      --math.abs(x2j - x1j), math.abs(y2j - y1j))
      -- the +1 on width and height looks like a bug in the lua api?
      lcd.drawRectangle(math.min(x1j, x2j), math.min(y1j, y2j),
			math.abs(x2j - x1j) + 1, math.abs(y2j - y1j) + 1)
      --print("###>rect", math.min(y1j, y2j), math.abs(y2j-y1j))      
   elseif b == 0x34 then --rectf
      if q == 0 then
	 x1, y1, x2, y2 = string.unpack(">i2i2i2i2", ps, 5)
      elseif q == 2 then
	 qr, x1, y1, x2, y2 = string.unpack(">I2i2i2i2i2", ps, 5)
      end
      
      x1j = Xa2jc(x1) --math.floor(math.floor(rr*(gw - x1)) + xoffset)
      y1j = Ya2jc(y1) --math.floor(rr*(gh - y1) + yoffset)
      x2j = Xa2jc(x2) --math.floor(math.floor(rr*(gw - x2)) + xoffset)
      y2j = Ya2jc(y2) --math.floor(rr*(gh - y2) + yoffset)
      lcd.drawFilledRectangle(math.min(x2j,x1j), math.min(y2j,y1j),
			      math.abs(x2j - x1j), math.abs(y2j - y1j))
      --print("###>rectf", math.min(y1j, y2j), math.abs(y2j-y1j))
      
   elseif b == 0x37 then --text
      if q == 0 then
	 x1, y1, r, f, c, str = string.unpack(">i2i2I1I1I1z", ps, 5)
      elseif q == 2 then
	 qr, x1, y1, r, f, c, str = string.unpack(">I2i2i2I1I1I1z", ps, 5)
      end
      
      str = string.sub(str,1, -2)
      --print(str, x1, y1, wid, hgt)
      x1j = Xa2jc(x1) --math.floor(rr*(gw - x1) + xoffset)
      y1j = Ya2jc(y1) --math.floor(rr*(gh - y1) + yoffset)
      --print(x1j, y1j)
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
      if q == 0 then
	 t, r1, r2, start = string.unpack(">i1i1i1", ps, start)
      elseif q == 2 then
	 qr, t, r1, r2, start = string.unpack(">I2i1i1i1", ps, start)
      end
      
      --print("t, r1, r2, start", t, r1, r2, start, len)
      for i=1,(len-8) / 4 do -- 7 bytes of preamble plus ending "0xAA"
	 xt[i], yt[i], start = string.unpack(">i2i2", ps, start)
	 xtj[i] = Xa2jc(xt[i]) --math.floor(rr * (gw - xt[i]) + xoffset)
	 ytj[i] = Ya2jc(yt[i]) --math.floor(rr * (gh - yt[i]) + yoffset)
	 ren:addPoint(xtj[i], ytj[i])
      end
      ren:renderPolyline(2)
   elseif b == 0x35 or b == 0x36 then --circle
      local rad
      local ren = lcd.renderer()
      ren:reset()
      if q == 0 then
	 x1, y1, rad = string.unpack(">i2i2I1", ps, 5)
      elseif q == 2 then
	 qr, x1, y1, rad = string.unpack(">I2i2i2I1", ps, 5)
      end
      x1j = Xa2jc(x1) --math.floor(rr*(gw - x1) + xoffset)
      y1j = Ya2jc(y1) --math.floor(rr*(gh - y1) + yoffset)
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
      if q == 0 then
	 x1, y1, rad, as, ae, th = string.unpack(">i2i2I1i2i2I1", ps, 5)
      elseif q == 2 then
	 qr, x1, y1, rad, as, ae, th = string.unpack(">I2i2i2I1i2i2I1", ps, 5)
      end
      
      x1j = Xa2jc(x1) --math.floor(rr*(gw - x1) + xoffset)
      y1j = Ya2jc(y1) --math.floor(rr*(gh - y1) + yoffset)
      drawArc(math.rad(ae-as), x1j, y1j, math.rad(as + 180), math.rad(ae), rr*(rad), rr*(rad + th), 18, 1)
   elseif b == 0x39 or b == 0x05 or b == 0x01 or b == 0xD3 or b == 0xD2 then
      
   else
      print("###> "..string.format("0x%02x", b))
   end

   lcd.setColor(255,255,255)
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
   --local str = ""
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
   --print("writeInst()")
   resetGlasses = 1
   serialWriteDirect(sidSerial, encodeBuf(bufClr)) -- clear screen
   savedSerial = {}
   savedSerialReset = {}
   teleSerial = {}
   teleSerialReset = {}
   sendIndex = 0
end

--[[
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
--]]


local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
end

--[[
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
--]]


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

--[[
local function dpFmt(x)
   if math.abs(x) - math.floor(math.abs(x)) == 0 then
      return "%d"
   end
   if math.abs(10*x) - math.floor(math.abs(10*x)) == 0 then
      return "%.1f"
   end
   return "%.2f"
end
--]]

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
	       --print("GPS", sensor.id, sensor.param)
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
   -- miserable hack to make "---" center properly when tele is null
   -- better approach would be to write a python program to measure all roboto-light
   -- chars and do this function properly. one of these days...
   local mm
   if str == "---" then mm = 0.4 else mm = 1.0 end 
   return math.floor( (20/36) * font * #str * mm + 0.5 )
end

local function RLhgt(str, font)
   local mm = 1.4
   if str == "---" then return mm * font else return font end
end

local function ALBattCheck()
   local pattern = ">BBBI1B"
   serialWriteDirect(sidSerial, string.pack(pattern, 0xFF, 0x05, 0x00, 0x05, 0xAA))
end

local function ALColor(color)
   local pattern=">BBBI1I1B"
   --if color == 0x00 then ALisBlack = true else ALisBlack = false end
   serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x30, 0x00, 0x06, color & 0xF, 0xAA))
end

local function ALColorBlack()
   ALColor(0x00);
end

local function ALColorGray()
  ALColor(0x08);
end

local function ALColorWhite() 
   ALColor(0x0F);
end

local function ALClear()
   local pattern = ">BBBI1B"
   serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x01, 0x00, 0x05, 0xAA))
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

local function ALFlushReset(wait)
   local pattern
   if wait then
      pattern = ">BBBI1I1I1I1B"
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x39, 0x02, 0x08, 0x00, 0x00, 0xFF, 0xAA))
   else
      pattern = ">BBBI1I1B"
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x39, 0x00, 0x06, 0xFF, 0xAA))
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
      pattern = ">BBBI1i2i2i2i2B"
      len = string.packsize(pattern)
      if (x0 < 0 or y0 < 0 or x1 < 0 or y1 < 0) then
	 --print("& ALDrawRect", x0, y0, x1, y1, rCode)
      end
      
      serialWrite(sidSerial,string.pack(pattern, 0xFF, rCode, 0x00, len,
					math.floor(x0), math.floor(y0),
					math.floor(x1), math.floor(y1), 0xAA))
   else
      pattern = ">BBBI1I1I1i2i2i2i2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial,string.pack(pattern, 0xFF, rCode, 0x02, len, 0, 0, x0, y0, x1, y1, 0xAA))
   end
   
   return (len);
end


local function ALDrawCircF(xc, yc, rad, wait)
   local pattern, len
   if not wait then
      pattern = ">BBBI1i2i2I1B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x36, 0x00, len, xc, yc, rad, 0xAA))
   else
      pattern = ">BBBI1I1I1i2i2I1B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x36, 0x02, len, 0x00, 0x00, xc, yc, rad, 0xAA))
   end
end

local function ALDrawCirc(xc, yc, rad, wait)
   local pattern, len
   if not wait then
      pattern = ">BBBI1i2i2I1B"
      len = string.packsize(pattern)
      --print("ALDrawCirc", xc, yc, len, rad, wait)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x35, 0x00, len, xc, yc, rad, 0xAA))
   else
      pattern = ">BBBI1I1I1i2i2I1B"
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
      pattern = string.format(">BBBI1I1I1i2i2I1I1I1c%dB", #str)
      len = string.packsize(pattern)
      ps = string.pack(pattern, 0xFF, 0x37, 0x02, len, 0, 0, xp, yp, textDir, fontCode,
			  textColor, str, 0xAA)
   else
      pattern = string.format(">BBBI1i2i2I1I1I1c%dB", #str)
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
   local yt = yp + RLhgt(str, fh) / 2
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
      pattern = ">BBBI1I1I1i2i2I1i2i2I1B"
      len = string.packsize(pattern)
      waitReply = 0x02
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x3C, waitReply, len, 0, 0, x, y, r,
					 arcStart, arcEnd, thk, 0xAA))
   else
      pattern = ">BBBI1i2i2I1i2i2I1B"
      len = string.packsize(pattern)      
      waitReply = 0x00
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x3C, waitReply, len, x, y, r,
				      arcStart, arcEnd, thk, 0xAA))
   end
   
   
end

local function ALDrawPoint(x1, y1, wait)

local pattern, len

   if not wait then
      pattern = ">BBBI1i2i2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x31, 0x00, len,
					 math.floor(x1), math.floor(y1), 0xAA))
   else
      pattern = ">BBBI1I1I1i2i2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x31, 0x02, len, 0, 0, x1, y1, 0xAA))
   end

end

local function ALDrawLine(x1, y1, x2, y2, wait)
   
   local pattern, len

   if not wait then
      pattern = ">BBBI1i2i2i2i2B"
      len = string.packsize(pattern)
      serialWrite(sidSerial, string.pack(pattern, 0xFF, 0x32, 0x00, len,
					 math.floor(x1), math.floor(y1),
					 math.floor(x2), math.floor(y2), 0xAA))
   else
      pattern = ">BBBI1I1I1i2i2i2i2B"
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
   pattern = ">BBBI1i2i2i2i2B"
   len = string.packsize(pattern)
   serialWrite(sidSerial, string.pack(pattern, 0xFF, rCode, 0x00, len,
				      math.max(xc - width/2,0), math.max(yc - height/2, 0),
				      xc + width/2, yc + height/2, 0xAA))

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

local vbarLowXprev = {0,0,0,0,0}
local vbarLowYprev = {0,0,0,0,0}
local vbarUpXprev =  {0,0,0,0,0}
local vbarUpYprev =  {0,0,0,0,0}
local vbarPctPrev =  {0,0,0,0,0}

local function ALVbar (reset, seq, ccfg, cff, cid, inval, val2, minV, maxV, mk, dd) 
  
  local x = ccfg.xlr;
  local y = ccfg.ylr;
  
  local width = ccfg.width;
  --local height = ccfg.height;

  local x0 = cff.x0;
  local y0 = cff.y0;

  local barW = cff.wid;
  local barH = cff.hgt;

  local scale = cid.scale;
  local val = inval or 0
  
  if seq == 0 then
     x = 0
     y = 0
     val = 0
     mk = 0
     seq = #vbarPctPrev
  end

  local xlmin, ylmin, xlmax, ylmax, xlbl, ylbl;
  if (scale == "variable") then
     xlmin = x + cff.xlmin;
     xlmax = x + cff.xlmax;
     ylmin = y + cff.ylmin;
     ylmax = y + cff.ylmax;
     xlbl  = x + cff.xlbl;
     ylbl  = y + cff.ylbl;
  end


  local inpct, pct
  
  inpct = (val - minV) / (maxV - minV);
  pct = math.max(0, math.min(inpct, 1)) --clip(0.0, 1.0, inpct);

  local lowX, lowY, upX, upY

  --uint8_t img = dW.im;
  
  local maxText, minText, lblVal;
  
  if (scale == "variable") then
     minText = encdp(dd, minV);
     maxText = encdp(dd, maxV);
     lblVal = encdp(dd, val or 0);
  end

  if not inval then lblVal = "---" end
  
  ALHold();

  if (reset == 1) then
     resetOn()
     ALDrawTextC(minText, 16, xlmin, ylmin, false);
     ALDrawTextC(maxText, 16, xlmax, ylmax, false);
     if (scale == "variable") then
	ALDrawTextC(lblVal, 16, xlbl, ylbl, false);
     end
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
  end
  
  local markY;
  local mpct
  if mk then
     mpct = (mk - minV) / (maxV - minV);
  else
     mk = 0
     mpct = 0
  end

  if (mpct> 0.0 and mpct < 1.0) then
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
  
  --local dy = barH / 5;
  --for i = 1, 4, 1 do
  --ALDrawLine(x+x0, y+y0-i*dy, x+x0-barW+3, y+y0-i*dy, false); --+3 fudge. roundoff?
  --end
  
  if (scale == "variable") then
     ALDrawTextC(lblVal, 16, xlbl, ylbl, false);
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

local ALCompassBrgXprev = {0,0,0,0,0};
local ALCompassBrgYprev = {0,0,0,0,0};
local ALCompassRotPrev = {0,0,0,0,0};

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

   if seq == 0 then
      x = 0
      y = 0
      val = 0
      val2 = 0
      seq = #ALCompassBrgXprev
   end
   
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
local vertTapeValIntprev = {0,0,0,0,0};

local function ALVertTape (reset, seq, ccfg, cff, cid, inval)
   
   local x = ccfg.xlr;
   local y = ccfg.ylr;

   local x0 = cff.x0;
   local y0 = cff.y0;
   
   local barW = cff.wid;
   local barH = cff.hgt;

   local side = cid.side;

   local val = inval or 0
   
   if seq == 0 then
      x = 0
      y = 0
      val = 0
      seq = #vertTapeValIntprev
   end
   
   local valInt = math.floor(val + 0.5);

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
   local k1 = ((zp * nums) / step - (zp));
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
      valText = string.format("%g", yv)
      if (y + y0 - barH / 2 + ypi > 0 and y + y0 - barH / 2 + ypi < 256) then
	 count = count + 1;
	 if (count % 4 == 0) then
	    waitReply = true;
	 end
	 --print("VTL", x + x0 - 2 * barX, y + y0 - barH / 2 + ypi, x + x0 -2*barX + xtick,
	       --y + y0 - barH / 2 + ypi)
	 ALDrawLine(x + x0 - 2 * barX, y + y0 - barH / 2 + ypi, x + x0 -2*barX + xtick,
		    y + y0 - barH / 2 + ypi, false);
	 ALDrawTextC(valText, 16, x + x0 - barX - xnum, y + y0 - barH / 2 + ypi, waitReply);
	 waitReply = false;
      end 
      kdx = kdx + 1;
   until (kdx > k2);
   
   local blnk = 20;
   
   ALColorBlack();
   ALDrawRect(x+x0-barX, y+y0+0*1, x+x0-barX-barW, y+y0+blnk, 0x34, false); --erase above box
   ALDrawRect(x+x0-barX, y+y0-barH-1, x+x0-barX-barW, y+y0-barH-blnk, 0x34, false); -- erase below box
   ALDrawRectC(x + x0 - valX, y + y0 - barH / 2, barW, 26+4, 0x34); -- erase value box

   ALColorWhite();
   ALDrawLine(x + x0 - barW, y + y0 - barH / 2, x + x0 - barW - xtick,
	      y + y0 - barH / 2, false); --ref tick mark
   ALDrawRect(x+x0 - barX, y+y0, x+x0-barX - barW, y+y0-barH, 0x33, false); -- box outline
   --print("VTB", x+x0 - barX, y+y0, x+x0-barX - barW, y+y0-barH)
   ALDrawRectC(x + x0 - valX, y + y0 - barH / 2, barW, 26+4, 0x33); --value box outline
   valText = string.format("%d", valInt)
   if not inval then valText = "---" end
   ALDrawTextC(valText, 26, x + x0 - valX, y + y0 - barH / 2 + 1, false); ---value

   ALFlush(true);
   
   vertTapeValIntprev[seq] = valInt;

end

local ahGaugeAlphaDispInt = 0
local ahGaugeAlphaDispIntPrev = {0,0,0,0,0}

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

   if seq == 0 then
      x = 0
      y = 0
      val = 0
      val2 = 0
      seq = #ahGaugeAlphaDispIntPrev
   end

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
	 --print("reset", reset)
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

local ilsGaugeLocPrev = {0,0,0,0,0}
--local ilsGaugeGSPrev = {0,0,0,0,0}

local function ALILSGauge (reset, seq, ccfg, cff, cid, val, val2)

   --print("ALILSGauge", reset, seq, val, val2)
   
   local x = ccfg.xlr;
   local y = ccfg.ylr;
   
   local x0 = cff.x0;
   local y0 = cff.y0;
   
   local ww = ccfg.width;
   local hh = ccfg.height;

   val = val or 0;
   val2 = val2 or 0;

   local loc = 0
   local gs = 0

   local ilsLoc = Glass.var.ilsLoc
   local ilsGS = Glass.var.ilsGS
      
   if seq == 0 then
      x = 0
      y = 0
      val = 0
      val2 = 0
      ilsLoc = 0
      ilsGS = 0
      seq = #ilsGaugeLocPrev
   end
   
   local circX = x + x0;
   local circY = y + y0;

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

      if ilsLoc then
	 loc = math.floor(math.min(ilsLoc, 80))
	 ALDrawLine(circX - loc, circY - hh/2, circX - loc, circY + hh/2)
      end

      if ilsGS then
	 gs = math.min(math.max(10 * ilsGS, -80), 80)
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

local htextValPrev = {0,0,0,0,0}

local function ALHtext(ty, reset, seq, ccfg, cff, cid, inval, label, unit)

   local x = ccfg.xlr;
   local y = ccfg.ylr;
   
   local width = ccfg.width;
   local height = ccfg.height;
   
   local x0 = cff.x0;
   local y0 = cff.y0;

   local val = inval or 0

   local txtW = cff.wid;
   --local txtH = cff.hgt;
   
   local valText; 

   if seq == 0 then
      x = 0
      y = 0
      --val = 0
      seq = #htextValPrev
   end
   
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
   local valY = y + y0 - height / 2 + RLhgt(valText, 36) / 2;
   
   local valXc = x + x0 - width / 2; 
   local valYc = y + y0 - height / 2 + 2;
   
   local lblX = x + x0; -- + RLwid(label, 16); 
   local lblY = y + y0 - height / 2 + 8;

   local unitX = x + x0 - txtW + RLwid(unit, 16);
   local unitY = y + y0 - height / 2 + 8;

   
   if not inval then
      valText = "---"
   end

   if (reset == 1) then
      --htextFirst = true;
      resetOn()
      ALColorWhite()
      ALDrawText(label, 16, lblX, lblY, false)
      ALDrawText(unit, 16, unitX, unitY, false)
      ALDrawText(valText, 36, valX, valY, false)      
      resetOff()
   end
   
   if (htextValPrev[seq] ~= val ) or seq == #htextValPrev then
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

local hbarLowXprev = {0,0,0,0,0}
local hbarLowYprev = {0,0,0,0,0}
local hbarUpXprev = {0,0,0,0,0}
local hbarUpYprev = {0,0,0,0,0}
local hbarPctPrev = {0,0,0,0,0}


local function ALHbar (reset, seq, ccfg, cff, cid, inval, val2, minV, maxV, mk, dd)
  
  local x = ccfg.xlr;
  local y = ccfg.ylr;
  
  local width = ccfg.width;
  local height = ccfg.height;

  local x0 = cff.x0;
  local y0 = cff.y0;

  local barW = cff.wid;
  local barH = cff.hgt;

  local scale = cid.scale;

  local val = inval or 0
  
  if seq == 0 then
     x = 0
     y = 0
     val = 0
     mk = 0
     seq = #hbarPctPrev
  end
  
  local xlmin, ylmin, xlmax, ylmax, xlbl, ylbl;
  if scale == "variable" then
    xlmin = x + cff.xlmin;
    xlmax = x + cff.xlmax;
    ylmin = y + cff.ylmin;
    ylmax = y + cff.ylmax;
    xlbl = x + cff.xlbl;
    ylbl = y + cff.ylbl;
  end

  local inpct, pct
  inpct = (val - minV) / (maxV - minV);
  pct = math.max(0, math.min(inpct, 1)) --clip(0.0, 1.0, inpct);

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

  if not inval then
     lblVal = "---"
  end

  ALHold();
  
  if (reset == 1) then
     resetOn()
     ALColorWhite()
     ALDrawTextC(minText, 16, xlmin, ylmin, false);
     ALDrawTextC(maxText, 16, xlmax, ylmax, false);
     if (scale == "variable") then
	ALDrawTextC(lblVal, 16, xlbl, ylbl, false);
     end
     resetOff()
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

  --draw bargraph filled box
  ALDrawRect(lowX, lowY, upX, upY, 0x34, false);

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


  -- save old values
  hbarPctPrev[seq] = inpct;
  hbarLowXprev[seq] = lowX;
  hbarLowYprev[seq] = lowY;
  hbarUpXprev[seq] = upX;
  hbarUpYprev[seq] = upY;
  
end

-- ****

local function ALMan(reset, seq, ccfg, cff, cid, inval, val2)

   local x0 = cff.x0
   local y0 = cff.y0
   local x = ccfg.xlr
   local y = ccfg.ylr
   local width = ccfg.width
   local height = ccfg.height
   local fw = Glass.settings.fltWidth
   local sxmin, sxmax, szmin, szmax = -fw * width/height, fw * width/height, 0, 2 * fw
   local refDist = Glass.settings.distMan -- "screen" dist (m) from pilot
   
   if seq == 0 then
      x = 0
      y = 0
   end

   ALHold()
   ALClear()
   ALColorGray()
   ALDrawLine(x+x0, 0, x+x0, height)
   ALDrawLine(0, y+y0, width, y+y0)
   ALDrawCirc(x+x0, y+y0, 10, false)
   ALColorWhite()
   local idx = #pos3D.y
   if idx > 0 and Glass.var.leftRight then
      local dev = width/2 + width/2 * 10 * Glass.var.leftRight *
	 (refDist - pos3D.y[idx]) / (sxmax - sxmin)
      local devPx = math.min(math.max(0, dev), width)
      ALDrawLine(devPx, y+y0 - height/4, devPx, y+y0 + height/4)
   end
      
   local sMult
   local npts = #pos3D.x
   local sx, sy, sz
   local px, pz

   if seq ~= 0 and #pos3D.x > 0 then
      for i=1, npts, 1 do
	 sMult = refDist / math.abs(pos3D.y[i])
	 sx = pos3D.x[i] * sMult
	 sz = pos3D.z[i] * sMult
	 --print("~", pos3D.y[i], sMult, sx, sz)
	 px = width - width * (sx - sxmin) / (sxmax - sxmin)
	 pz = height * (sz - szmin) / (szmax - szmin)
	 if px >= 0 and px <= width and pz >= 0 and pz <= height then 
	    ALDrawCircF(px, pz, 2, false)
	 end
      end
   end
   

   ALFlush()
   
end

local tipXprev = {0,0,0,0,0};
local tipYprev = {0,0,0,0,0};

local function ALGauge(reset, seq, ccfg, cff, cid, inval, val2, minV, maxV, mk, dp, lbl)

   local x0 = cff.x0
   local y0 = cff.y0
   local x = ccfg.xlr
   local y = ccfg.ylr
   local width = ccfg.width
   local height = ccfg.height
   local xlbl = cff.xlbl
   local ylbl = cff.ylbl
   local xlmin = cff.xlmin
   local ylmin = cff.ylmin
   local xlmax = cff.xlmax
   local ylmax = cff.ylmax	 	 
   --local rIn = cff.radiusIn
   --local rOut = cff.radiusOut
   local ro = cff.radius
   local degMin = cff.minA
   local degMax = cff.maxA	 
   local major = cff.major
   local minor = cff.minor
   local fine = cff.fine
   local scale = cid.scale

   local val = inval or 0
   
   if seq == 0 then
      x = 0
      y = 0
      val = 0
      mk = 0
      seq = #tipXprev
   end
   
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

  local valX = x + x0 --+ RLwid(valText, 26) / 2;
  local valY = ylbl + y  + 26 / 2 + 26;

  local sq
  if width == height then -- square gauge gets labels, half  gauges do not
     sq = true
  else
     sq = false
  end

  ALHold(false)


  local ww = RLwid("0000", 26);
  local hh = 26
  
  if (reset == 0) then
     ALColorBlack()
     ALDrawRectC(valX, valY, ww, 26, 0x34)
     ALDrawLine(tipXprev[seq], tipYprev[seq], centX, centY, false)
  end

  --value

  local valText = encdp(dp, val);

  if not inval then valText = "---" end

  ALColorWhite()
  
  if (reset == 1) then
     resetOn()
     ALDrawArc(centX, centY, ro, degMin - 90 - 1, degMax - 90, 4, false)
     ALDrawScale(x+x0, y+y0, degMin - 1, degMax + 1, degMin, degMax, ro, major, minor,
		 fine, minV, maxV, scale);
     if sq then
	ALDrawTextC(valText, 26, valX, valY, false)
     end
     
     ALDrawMinMaxLabel(x, y, x0, y0, lbl, xlbl, ylbl,
		       xlmin, ylmin, xlmax, ylmax,
		       val, dp, minV, maxV, sq);
     resetOff()
  end
  
  ALDrawLine(tipX, tipY, centX, centY, false)
  if ( (mpct > 0.0) and (mpct < 1.0)) then
     ALDrawCircF(mX, mY, (nlen*0.1), false);
  end

  if sq then -- square gauges only
     ALDrawTextC(valText, 26, valX, valY, false)
  end

  -- save old values
  tipXprev[seq] = tipX;
  tipYprev[seq] = tipY;
  --alphaDispXPrev[seq] = alphaDispX;

  --print("else", seq, tipX, tipXprev[seq], tipY, tipYprev[seq])
  --end

  ALFlush(true)

end


-- ****



local arcAnglePrev = {0,0,0,0,0}
local arcAngle = {0,0,0,0,0}

local function ALArcGauge(reset, seq, ccfg, cff, cid, inval, val2, nv, xv, mk, dd, lbl)

   local x0 = cff.x0
   local y0 = cff.y0
   local x = ccfg.xlr
   local y = ccfg.ylr
   local xlbl = cff.xlbl
   local ylbl = cff.ylbl
   local xlmin = cff.xlmin
   local ylmin = cff.ylmin
   local xlmax = cff.xlmax
   local ylmax = cff.ylmax	 	 
   local rIn = cff.radiusIn
   local rOut = cff.radiusOut
   local as = cff.arcStart
   local ae = cff.arcEnd
   local pct, markPct
   local markAngle
   local arcStart = math.floor(as)
   local arcEnd = math.floor(ae)
   local thk = rOut - rIn
   local lblX, lblY
   local valText
   local valX, valY
   local minText
   local xlMin, xlMax
   local maxText
   local ylMin, ylMax
   local arcErase

   local val = inval or 0
   
   if seq == 0 then
      x = 0
      y = 0
      val = xv
      mk = 0
      seq = #arcAngle
   end

   mk = mk or 0
   
   pct = (val - nv) / (xv - nv)
   
   markPct = (mk - nv) / (xv - nv)

   arcAngle[seq] = arcStart + pct * (arcEnd - arcStart)
   markAngle = arcStart + markPct * (arcEnd - arcStart)

   arcStart = arcStart - 90
   arcAngle[seq] = arcAngle[seq] - 90

   lblX = xlbl + x + RLwid(lbl, 16) / 2
   lblY = ylbl + y + 16 / 2

   valText = encdp(dd, val)
   if not inval then valText = "---" end
   
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

   ALHold(false)

   ALColorBlack()
   ALDrawRectC(valX, valY, RLwid("0000", 26), 26, 0x34)
   if reset ~= 1 then
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
end



local function sendAL(g, pN, seq)

   local gpp
   local ccfg, cid, fid, fmt, cff, ccf
   local min, max
   local mk
   local dd
   local val, val2
   local lbl, units

   --
   -- REMINDER: USE cfgimgESP table to send to the glasses!!!
   --

   gpp = Glass.page[pN]
   if not gpp then
      print("sendAL: Glass.page[pN] is nil")
      return
   end
   
   if not gpp[1].fmtNumber then gpp[1].fmtNumber = 1 end
   fmt = gpp[1].fmtNumber
   ccf =  cfgimgESP.config[fmt]
   local t = gpp[g]
   
   if t.widgetID > 0 then --and t.imageID >= 0 then        -- if there is a value to animate
      if not seq then
	 seq = g
      else
	 seq = 0
	 resetGlasses = 1
      end

      local rst
      rst = resetGlasses
      
      ccfg = ccf[g]                 -- this is the "config" key for this page and this widget
      cid = cfgimgESP.instruments[t.widgetID]
      fid = cid.formID + 1
      cff = cfgimgESP.forms[fid]
      mk = t.marker
      if t.dispdec then
	 dd = t.dispdec
      else
	 dd = t.decimals
      end
      
      if cid.scale and cid.scale == "fixed" then
	 min = cid.minV
	 max = cid.maxV
      else  -- be defensive in case of missing minV/maxV
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
      end
      lbl = t.instName or "..." --.instName is named .label in the 200ms json 
      units = t.units
      val = t.value
      val2 = t.value2

      --print("sendAL: g, pN, t.widgetID, cid.type", g, pN, t.widgetID, cid.wtype)
      
      if cid.wtype == "gauge" then
	 ALGauge(rst, seq, ccfg, cff, cid, val, val2, min, max, mk, dd, lbl)
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
	 ALArcGauge(rst, seq, ccfg, cff, cid, val, val2, min, max, mk, dd, lbl)
      elseif cid.wtype == "ahGauge" then
	 ALAhGauge (rst, seq, ccfg, cff, cid, val, val2)
      elseif cid.wtype == "vltape" then
	 ALVertTape (rst, seq, ccfg, cff, cid, val)	       
      elseif cid.wtype == "ils" then
	 ALILSGauge (rst, seq, ccfg, cff, cid, val, val2)
      elseif cid.wtype == "man" then
	 ALMan (rst, seq, ccfg, cff, cid, val, val2)
      else
	 print("DFM-HUD: unrecognized wtype:", cid.wtype)
      end
   end
end


local lastSend = 0
local linecount = 0
local enterWaiting = 0
local oncePerSecond = 0
local lastTakeoffSw = 0
local lastGearUpSw = 0
local lastScreen = 0

local function loop()
   local now = system.getTimeCounter()
   local unow = system.getTimeCounter()
   local sensor, sval, sval2
   local scale
   local minV, maxV
   local gotGPS
   local takeoff = system.getInputsVal(switchItems.takeoff) or 0      
   local gearUp = system.getInputsVal(switchItems.gearUp) or 0

   if Glass.settings.latId ~= 0 and Glass.settings.latPa ~= 0 and Glass.settings.lngPa ~= 0 then
      gotGPS = true
   else
      gotGPS = false
   end
   
   if takeoff ~= lastTakeoffSw and takeoff == 1 then
      if gotGPS then
	 Glass.var.startTakeoff = gps.getPosition(Glass.settings.latId, Glass.settings.latPa,
						  Glass.settings.lngPa)
      end
      sensor = system.getSensorByID(Glass.settings.altId, Glass.settings.altPa)
      if sensor and sensor.valid then
	 Glass.var.startTakeoffAlt = sensor.value
      end
	 
      local s1, s2 = gps.getStrig(Glass.var.startTakeoff)
      print("Start takeoff:", s1, s2, Glass.var.startTakeoffAlt)
   end

   if gearUp ~= lastGearUpSw and gearUp == 1 then
      if gotGPS then
	 Glass.var.gearUP = gps.getPosition(Glass.settings.latId, Glass.settings.latPa,
					    Glass.settings.lngPa)
	 local s1, s2 = gps.getStrig(Glass.var.gearUp)
	 print("Gear up:", s1, s2)
      end
   end
   
   lastTakeoffSw = takeoff
   lastGearUpSw = gearUp
   
   if Glass.settings.latId ~= 0 and Glass.settings.latPa ~= 0 and Glass.settings.lngPa ~= 0 then
      Glass.var.currentPosition = gps.getPosition(Glass.settings.latId, Glass.settings.latPa,
						  Glass.settings.lngPa)
   end
      
   local alt = 0
   if gotGPS then
      sensor = system.getSensorByID(Glass.settings.altId, Glass.settings.altPa)
      if sensor and sensor.valid then
	 alt = sensor.value - (Glass.var.startTakeoffAlt or 0)
      end
   end

   local historyPts = 40 -- making this larger causes too much CPU load in the tele draw callback
   
   if Glass.var.currentPosition and Glass.var.zeroPos and
      Glass.var.startTakeoff and Glass.var.gearUp and now > lastScreen then
      local zero2currB = gps.getBearing(Glass.var.currentPosition, Glass.var.zeroPos)
      local zero2currD = gps.getDistance(Glass.var.currentPosition, Glass.var.zeroPos)
      local gearUp2toB = gps.getBearing(Glass.var.startTakeoff, Glass.var.gearUp)
      local theta = zero2currB - gearUp2toB - 90
      local idx = #pos3D.x
      if idx >= historyPts then
	 table.remove(pos3D.x,1)
	 table.remove(pos3D.y,1)
	 table.remove(pos3D.z,1)
      end
      table.insert(pos3D.x, zero2currD * math.sin(math.rad(theta)))
      table.insert(pos3D.y, zero2currD * math.cos(math.rad(theta)))
      table.insert(pos3D.z, alt)
      if idx > 1 and Glass.var.previousPosition then
	 Glass.var.heading = gps.getBearing(Glass.var.currentPosition, Glass.var.previousPosition)
	 local dd = (Glass.var.heading - gearUp2toB) % 360
	 local str
	 if dd > 90 and dd < 270 then
	    str = "L-R"
	    Glass.var.leftRight = 1
	 else
	    str = "R-L"
	    Glass.var.leftRight = -1
	 end
	 --print("runway heading, heading, h-z",
	 --gearUp2toB, Glass.var.heading, dd, str)
      end
      Glass.var.previousPosition = Glass.var.currentPosition
      --print("Gsh", Glass.settings.historyLength, historyPts, alt)
      lastScreen = now + 1000 * Glass.settings.historyLength / historyPts
   end
   
   if Glass.var.currentPosition and Glass.var.startTakeoff and Glass.var.gearUp then
      local GSdeg = 6
      local curr2gearUpB = gps.getBearing(Glass.var.currentPosition, Glass.var.gearUp)
      local gearUp2toB = gps.getBearing(Glass.var.startTakeoff, Glass.var.gearUp)
      --print("gearUp2toB", gearUp2toB)
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
   
   if switchItems.pageChange then setpNT() end

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
	 system.messageBox("DFM-HUD: GPS zero set")
	 print("DFM-HUD: GPS zero set")
	 Glass.initPos = Glass.curPos
	 if not Glass.zeroPos then
	    Glass.zeroPos = Glass.curPos
	 end
	 if not Glass.var.zeroPos then
	    Glass.var.zeroPos = Glass.curPos
	 end
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


	 --stbl = {page=pageNumberTele}

	 --gtbl = {}
	 --gtbl.v = {}
	 --gtbl.v2 = {}
	 --gtbl["pg"] = pageNumberTele 
	 --gtbl["cfg"] = Glass.page[pageNumberTele][1].fmtNumber - 1 --  convert lua convention to c++

	 
	 for k,v in ipairs(Glass.page[pageNumberTele]) do
	    if true then --v.imageID and v.imageID >= 0 then
	       --if not v.imageID then print("imageID nil:", k, v.imageID) end
	       --if true then --v.imageID >= 0 then
	       if v.widgetID >= 0 then
		  ---print("@@@", v.widgetID)
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


	       --[[
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

	 

	 gtbl["n"] = #stbl

	 --]]

	    end
	 end
	    
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
	    if sendState ~= state.COMPLETE then
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

	    --never send with forms active
	    
	    if not form.getActiveForm() and (sendJson or forceSend) then 
	       sendIndex = sendIndex + 1
	       if sendIndex <= numInsts then
		  sendAL(sendIndex, pageNumberTele)
	       end
	       ALFlushReset(false) -- clear graphics engine hold state before sending new frame

	       if sendIndex >= numInsts and ((system.getTimeCounter() - lastSend) > LOOPTIME) then
		  local cc, err
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
		  savedSerial = {}
		  savedSerialReset = {} -- was sent once, don't send again
		  resetGlasses = 0
		  lastSend = system.getTimeCounter()
	       end
	    end
	 end
	 lastWrite = now
      end

   end

   if unow <= jsonHoldTime then return end

   if sendState == state.DISCONNECTED then
      --print("DFM-HUD: DISCONNECTED - sending config request")
      local bufCfg = "FFD302070101AA"
      --bw = serialWrite(sidSerial, 0xFF, 0xD3, 0x02, 0x07, 0x01, 0x01, 0xAA) -- read config
      local bw = serialWriteDirect(sidSerial, encodeBuf(bufCfg)) -- read config
      if not bw then
	 print("DFM-HUD: cannot write config query")
      end
      local imgCfg = "FF4702070102AA"
      local bw = serialWriteDirect(sidSerial, encodeBuf(imgCfg)) -- read config
      if not bw then
	 print("DFM-HUD: cannot write image query")
      end
      jsonHoldTime = unow + 1000
      --print("DFM-HUD: WAITING for Glasses")
      sendState = state.WAITING -- wait for onRead to get config list
      enterWaiting = system.getTimeCounter()
   end

   if sendState == state.WAITING then
      --just spin, when config is available, sendState will be set to CONNECTED
      --print("sendState WAITING")
      if system.getTimeCounter() - enterWaiting > 2000 then --no response to config request in 2 sec
	 sendState = state.DISCONNECTED
	 --print("DFM-HUD: No cfg response .. set DISCONNECTED and retry")
	 jsonHoldTime = unow + 1000 -- wait 1 more sec then try config request again
      end
   end

   if sendState == state.ALMOST then
      print("DFM-HUD: state COMPLETE")
      sendState = state.COMPLETE
      splashScreen = nil -- don't redisplay it on reconnect
      writeInst()
      resetGlasses = 1
   end

   if sendState == state.SELECT then
      local bufSet = "FFD2000D" .. appHex .. "00AA"      
      local bufClr = "FF010005AA"
      local bufFls = "FF390006FFAA"
      local bufDsp = "FF42000A0100000000AA"

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
	 print("DFM-HUD: state ALMOST")
	 savedSerial = {}
	 savedSerialReset = {}
	 teleSerial = {}
	 teleSerialReset = {}
	 sendState = state.ALMOST
	 --writeInst()
	 serialWriteDirect(sidSerial, encodeBuf(bufDsp))
	 if splashScreen then
	    jsonHoldTime = unow + 3000 -- wait 3s to allow setup, clear, flush and disp splash screen
	 end
	 --resetGlasses = 1
	 return
      end
   end
   
   if sendState == state.CONNECTED then 
      if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
      system.messageBox("DFM-HUD: Preparing Glasses")
      print("DFM-HUD: opening file " .. prefix() .. pathConfigs .. "config-fonts-images.txt")
      sendFP = io.open(prefix() .. pathConfigs .. "config-fonts-images.txt", "r")
      if not sendFP then
	 print("DFM-HUD: cannot open font and image config file")
	 sendState = state.DISCONNECTED
	 jsonHoldTime = unow + 1000
      else
	 print("DFM-HUD: opened config-fonts-images.txt")
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
	 --print("sending header")
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
	 system.messageBox("DFM-HUD: Transfer complete")
	 Glass.settings.configIDs = {}
	 --for k in ipairs(currentConfigIDs) do -- remember that this config was sent last
	 --   Glass.settings.configIDs[k] = currentConfigIDs[k] 
	 --end
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
	 if linecount % 20 == 0 then
	    system.messageBox("DFM-HUD: Reading line " .. linecount,5)
	 end
	 if not line then
	    --print("io,readline EOF")
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
	       --print("> "..ll)
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
      system.messageBox("DFM-HUD: Settings deleted .. Restart App")
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
      local origWidth
      local origHeight
      for i, img in ipairs(cfgimg.instruments) do
	 
	 origWidth = cfgimg.forms[img.formID + 1].width
	 origHeight = cfgimg.forms[img.formID + 1].height
	 
	 if (wid == origWidth) and (hgt == origHeight) then
	    table.insert(editImgs,
			 {widgetID = i, --imageID=img.imageID,
			  --loadImage=img.loadImage,
			  --loadImageSmaller = img.loadImageSmaller,
			  wid = wid, hgt = hgt,
			  --imageWidth=img.imageWidth, imageHeight = img.imageHeight,
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
	    --Glass.page[pageNumber][gaugeNumber].imageID = editImgs[1].imageID
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
      

      

      form.addRow(2)
      form.addLabel({label="Page change switch"})
      swtCI.pageChange = form.addInputbox(switchItems.pageChange, true,
					  (function(x) return switchChanged(x, "pageChange") end)
      )

      form.addRow(1)
      form.addLink((function() form.reinit(20) return end),
	 {label="GPS and ILS setup>>"})

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
		  system.messageBox("DFM-HUD: Turn off reboot disconnect")
	       else
		  gpio.write(5,1)
		  print("gpio 5 set high")
		  system.messageBox("DFM-HUD: OTA update initialized")
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
	       system.messageBox("DFM-HUD: Rebooting AL controller")
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
	       system.messageBox("DFM-HUD: Cycling AL power")
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
      --form.setButton(1, "Exit",   ENABLED)
      --form.setTitle("Serial data transfer")
      
   elseif sf == 20 then -- GPS and ILS setup

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
      form.addLabel({label="Takeoff switch"})
      swtCI.takeoff = form.addInputbox(switchItems.takeoff, true,
					  (function(x) return  switchChanged(x, "takeoff") end)
      )
      
      form.addRow(2)
      form.addLabel({label="Gear up switch"})
      swtCI.gearUp = form.addInputbox(switchItems.gearUp, true,
					  (function(x) return  switchChanged(x, "gearUp") end)
      )

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
      
      form.addRow(2)
      form.addLabel({label="History timeline (s)", font=FONT_NORMAL})
      form.addIntbox(Glass.settings.historyLength, 10, 100, 20, 0, 1,
		     (function(x) Glass.settings.historyLength = x end))

      form.addRow(2)
      form.addLabel({label="Dist to flt path (m)", font=FONT_NORMAL})
      form.addIntbox(Glass.settings.distMan, 10, 500, 100, 0, 1,
		     (function(x) Glass.settings.distMan = x end))

      form.addRow(2)
      form.addLabel({label="Flt path width (m)", font=FONT_NORMAL})
      form.addIntbox(Glass.settings.fltWidth, 10, 500, 100, 0, 1,
		     (function(x) Glass.settings.fltWidth = x end))
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
      --Glass.page[pn][k].imageID = -1
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
   --updateConfigIDs()

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
	    system.messageBox("DFM-HUD: No pages defined")
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
	    teleSerial = {}
	    teleSerialReset = {}
	    form.reinit(10)
	 else
	    system.messageBox("DFM-HUD: No pages defined")
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
	       --iid = img.imageID
	       min = img.minV
	       max = img.maxV
	       wtype = img.wtype
	       inp = img.inputs
	    end
	 end
	 --print("key2 set widgetID", wid)
	 Glass.page[pageNumber][gaugeNumber].widgetID = wid	 
	 --Glass.page[pageNumber][gaugeNumber].imageID = iid
	 --Glass.page[pageNumber][gaugeNumber].minV = min -- may be nil
	 --Glass.page[pageNumber][gaugeNumber].maxV = max -- may be nil
	 Glass.page[pageNumber][gaugeNumber].wtype = wtype
	 --Glass.page[pageNumber][gaugeNumber].inputs = inp

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

      if imageNum and imageNum > 0 and editImgs[imageNum] then

	 local wid = editImgs[imageNum].wid
	 local hgt = editImgs[imageNum].hgt
	 local gpg = Glass.page[pageNumber][gaugeNumber]
	 --[[
	 gpg.widgetID = editImgs[imageNum].widgetID
	 gpg.imageID = editImgs[imageNum].imageID
	 --gpg.minV = editImgs[imageNum].minV
	 --gpg.maxX = editImgs[imageNum].maxV
	 gpg.wtype = editImgs[imageNum].wtype
	 --gpg.inputs = editImgs[imageNum].inputs
	 --]]
	 
	 local bw = w / 2
	 local bh = h
	 local rr
	 local xoffset -- = w / 2 + w / 4
	 local yoffset -- = h / 2

	 lcd.setColor(0,0,0)

	 if wid > 144 and hgt < 50 then  -- horiz gauges and text gauges
	    rr = 0.8
	    xoffset, yoffset = w / 2, 3 * h / 4
	    lcd.drawFilledRectangle(w / 8, h/2 , 3 * w / 4, h / 2)
	    --lcd.drawFilledRectangle(0, h/2 , w, h / 2)
	 else
	    rr = 0.6
	    xoffset, yoffset = w / 2 + w / 4, h / 2
	    lcd.drawFilledRectangle(w - bw, 0, bw, bh)
	 end

	 sendAL(gaugeNumber, pageNumber, 0)

	 for k,v in ipairs(savedSerialReset) do
	    teleSerialReset[k] = v
	 end
	 for k,v in ipairs(savedSerial) do
	    teleSerial[k] = v
	 end

	 for k,v in ipairs(teleSerialReset) do
	    decodeAL(v, rr, xoffset, yoffset, wid, hgt)
	 end
	 for k,v in ipairs(teleSerial) do
	    decodeAL(v, rr, xoffset, yoffset, wid, hgt)
	 end

	 savedSerialReset = {}
	 savedSerial = {}
	 teleSerialReset = {}
	 teleSerial = {}

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

   local fmt
   local gpp
   local sgc
   local r = 160/256 -- Jeti height / Glasses height
   local offset = (319 - r * 304) / 2 --  center glasses box on Jeti screen

   -- Select the appropriate page (controlled by assigned switch or line in menu)
   -- Individual dynamic widget info stored in Glass.page[pageNumber][gaugeNumber].property

   if not switchItems.pageChange  then pageNumberTele = pageNumber end

   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159) -- black background over entire window
   lcd.setColor(255,255,255)            -- rest of animation (needles, etc) is white

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
	 system.messageBox("DFM-HUD: Rebooting AL controller")
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

   --local legacy = false
   
   if (sendState == state.ALMOST) and splashScreen then
      lcd.drawImage(offset + 20, 20, splashScreen)
      return
   end

   local rr = 160/256

   -- next params determined empirically
   
   local xoffset = 253 --200 * (system.getInputs("P7") + 1)
   local yoffset = 153 --200 * (system.getInputs("P8") + 1)

   local wid, hgt = 0,0 --cfgimg.forms[fid].width, cfgimg.forms[fid].height)
   
   for k,v in ipairs(teleSerialReset) do
      decodeAL(v, rr, xoffset, yoffset, wid, hgt)
   end
   for k,v in ipairs(teleSerial) do
      decodeAL(v, rr, xoffset, yoffset, wid, hgt)
   end
   --end

   lcd.drawRectangle(offset, 0, 304*r, (256-7)*r) -- draw scaled glasses hw screen as box
   
   -- ***
   --[[
   if (legacy) then
   if not gpp[1].fmtNumber then gpp[1].fmtNumber = 1 end
   fmt = gpp[1].fmtNumber --  string.format("p%d", gpp[1].fmtNumber)
   local ccf =  cfgimg.config[fmt]

   -- From here, everything referenced with "t." would come from the 200msec json if we
   -- were in the ESP. Make sure we only reference things that are sent that way so we're not
   -- cheating. Everything from "cid." is from the instruments section cfgimg.instruments

   for g,t in ipairs(gpp) do        -- loop over all gauges on this page with a valid imageID
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
	       
	    elseif cid.wtype == "hbar" then
	       --print(offset+r*xr, r*yr,  cfgimg.forms[fid].width, cfgimg.forms[fid].height)
				 
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       if val then
		  drawHbar(offset + r * xc, r * yc, min, max, val, r * cfgimg.forms[fid].wid,
			   r * cfgimg.forms[fid].hgt)
	       end
	    elseif cid.wtype == "vbar" then
	       --print(offset+r*xr, r*yr,  cfgimg.forms[fid].width, cfgimg.forms[fid].height)
				 
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       if val then
		  drawVbar(offset + r * xc, r * yc, min, max, val, r * cfgimg.forms[fid].wid,
			   r * cfgimg.forms[fid].hgt)
	       end
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

   --]]
   
   sgc = system.getCPU()

   if emflag ~= 0 then
      lcd.drawText(10,130, string.format("%d", sgc))
      lcd.drawText(10,110, string.format("%d", loopCPU))
      lcd.drawText(10, 90, string.format("%d", LOOPTIME))
   end
end

local function destroy()

   --print("closing")
   --if (logFileFP) then
   --   io.close(logFileFP)
   --end
   
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
      print("DFM-HUD - State saved " .. fn)
   else
      print("DFM-HUD - Could not save state")
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

   --print("#onReadBuf", #onReadBuf)
   onReadBuf = onReadBuf .. indata
   if #onReadBuf < 1 or string.byte(onReadBuf, 1) ~= 0xFF then
      print("DFM-HUD: CS_INVALID - bad format")
      local str = "command: "
      for i=1,#indata,1 do
	 str = str .. string.format("0x%02X ", string.byte(indata, i))
      end
      print(str)
      onReadBuf = ""
      return
   end
   
   cmd_len = string.byte(onReadBuf, 4)
   --print("DFM-HUD: cmd_len", cmd_len)
   
   if not cmd_len then
      --print("too short")
      return
   end -- input too short to have len 
   
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

	 -- DFMHUDCurrentVersion is the version of the font  file (config-fonts-images.txt) which
	 -- has the expected fonts and is built by the build system in ~/JS/GlassBuild
	 -- if changing/adding/deleting fonts, increment this value so that the app reloads
	 -- the fonts into the DFM-HUD ALook application
	 -- Future: could read the file config-fonts-images.json and get the list of font codes and sizes
	 -- and could add a version number to that file
	 
	 local DFMHUDCurrentVersion = 1
	 repeat
	    name, size, version, usgCnt, installCnt, isSystem =
	       string.unpack(">zI4I4I1I1I1", command, i)
	    print(string.format("DFM-HUD ALOOK app: %s Size %d Version %d", name, size, version))
	    if name == "DFM-HUD" then
	       DFMHUDVersion = version
	       Glass.var.statusAL.GlassConf = version
	    end
	    i = i + #name + 1 + 11 -- 11 is 4+4+1+1+1 ("I4I4I1I1I1")
	 until i >= cmd_len

	 if DFMHUDVersion ~= DFMHUDCurrentVersion then
	    sendState = state.CONNECTED --send the preparation info and font file
	 else
	    --sendState = state.CONNECTED -- for testing .. do every time
	    sendState = state.SELECT -- glasses have current info 
	 end
      elseif string.byte(command, 2) == 0x47 then -- image list
	 print("DFM-HUD onRead: image list response", cmd_len)
	 if cmd_len <= 7 then
	    print("DFM-HUD onRead: no images")
	 else
	    local i = 7
	    repeat
	       local id, height, width = 
		  string.unpack(">I1I2I2", command, i)
	       print(string.format("DFM-HUD ALOOK image: id %d height %d width %d", id, height, width))
	       i = i + 5 + 1 -- 5 is 1+2+2 ("I1I2I2")
	    until i >= cmd_len
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
      elseif string.byte(command, 2) == 0xA2 then -- use deprecated code 0xA2 for return ctrl msgs
	 local errTxt = {"Go", "Stop", "Message Error", "Overflow", "Missing cfgwrite", "Unknown state"}
	 if string.byte(command, 5) <= #errTxt then
	    print(string.format("DFM-HUD: onRead - ALOOK control says: " ..
				errTxt[string.byte(command, 5)]))
	    if string.byte(command, 5) == 2 then
	       print("DFM-HUD: Flow control delay")
	       lastSend = system.getTimeCounter() + 100
	    end
	 elseif string.byte(command, 5) == 0x0f then
	    print("DFM-HUD: Gesture received")
	    gestureTime = system.getTimeCounter() + 1000
	 end
      else
	 print("DFM-HUD: onRead - command[2]", string.format("0x%02x", string.byte(command,2)))
	 local str = "DFM-HUD: onRead full response: "
	 for i=1,#command,1 do
	    str = str .. string.format("0x%02X ", string.byte(command, i))
	 end
	 print(str)
      end
      
   end
   onReadBuf = "" -- assume no more commands (do we have to worry about this??)
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

   --print("0", system.getCPU())
   
   readSensors(Glass)
   
   --print("0.1", system.getCPU())

   system.registerForm(1, MENU_APPS, "DFM-HUD", initForm, keyPressed, printForm)

   fn = prefix() .. pathJson .. "instr.jsn"

   local file = io.readall(fn)
   cfgimg = {}
   if file then
      cfgimg = json.decode(file)
      print("DFM-HUD - Reading avail instruments from ", fn)
   else
      system.messageBox("DFM-HUD: Cannot read " .. fn)
      return
   end

   --print("1", system.getCPU())
   
   fn = prefix() .. pathJson .. "instrESP.jsn"
      
   file = io.readall(fn)
   cfgimgESP = {}
   if file then
      cfgimgESP = json.decode(file)
      print("DFM-HUD - Reading avail instruments (ESP) from ", fn)
   else
      system.messageBox("DFM-HUD: Cannot read " .. fn)
      return
   end

   --print("2", system.getCPU())
   
   fn = prefix() .. pathImages .."DFML7Small.png"
   splashScreen = lcd.loadImage(fn)

   --[[
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
	 --print("img.imageID, img.formID, #cfgimg.forms", img.imageID, img.formID, #cfgimg.forms)
	 local ww = cfgimg.forms[img.formID + 1].width
	 local hh = cfgimg.forms[img.formID + 1].height
	 img.origWidth = ww or 0
	 img.origHeight = hh or 0
	 img.imageWidth = (ww or 0) * ratio
	 img.imageHeight = (hh or 0) * ratio
      end
   end
   --]]
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

   --print("3", system.getCPU())
   
   local device
   device, emflag = system.getDeviceType() 
   
   local success, descr
   local portlist = serial.getPorts()
   for k,v in pairs(portlist) do
      print("DFM-HUD - Available COM port "..k..": ".. v)
   end

   local baud = 115200
   
   if emflag ~= 0 then
      sidSerial, descr = serial.init("ttyUSB0", baud)
      os.setlocale("C")
   else
      sidSerial, descr = serial.init("COM1", baud)
   end
   
   if sidSerial then   
      print("DFM-HUD - Serial port init succeeded: ", sidSerial)
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

   system.registerTelemetry(1, "DFM-HUD Display", 4, printTele)
   system.registerTelemetry(2, "DFM-HUD Status", 1, printTeleSmall)   

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

   local GGtbl
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

   --print("4", system.getCPU())
   
   if not Glass.switchInfo then Glass.switchInfo = {} end
      
   if not Glass.settings then Glass.settings = {} end
   if not Glass.settings.jsnVersion or Glass.settings.jsnVersion ~= JSNVERSION then
      print("old JSON in "..fn.. " - starting with no saved state")
      initG()
      system.messageBox("DFM-HUD: settings reset")
   end
   
   if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
   if not Glass.settings.distMan then Glass.settings.distMan = 200 end
   if not Glass.settings.fltWidth then Glass.settings.fltWidth = 300 end
   if not Glass.settings.historyLength then Glass.settings.historyLength = 20 end   

   -- unHex the Pa and Id numbers (they get garbled if stored as floating point by the
   -- CJSON library)
   
   for k, v in pairs(Glass.page) do
      for kk,vv in pairs(v) do
	 if vv.sensorId then
	    vv.sensorId = tonumber(vv.sensorId)
	 end
	 if vv.sensorPa then
	    vv.sensorPa = tonumber(vv.sensorPa)
	 end
	 if vv.sensorId2 then
	    vv.sensorId2 = tonumber(vv.sensorId2)
	 end
	 if vv.sensorPa2 then
	    vv.sensorPa2 = tonumber(vv.sensorPa2)
	 end
      end
   end

   --print("4.2", system.getCPU())

   for k,v in pairs(Glass.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa"
	 or k == "altId" or k == "altPa" then
	 Glass.settings[k] = tonumber(v)
      end
   end

   --print("4.5", system.getCPU())
      
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

   --print("4.6", system.getCPU())
   
   for k, swi in pairs(Glass.switchInfo) do
      local t = string.sub(swi.name,1,1)
      --print("k, swi", k, swi.name, swi.mode, swi.activeOn)
      switchItems[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
   end

   if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
   
   --updateConfigIDs()
   if not Glass.settings.configIDs or Glass.settings.configVersion == 0 then
      Glass.settings.configIDs = {}
   end
   
   setpNT()

   --print("5", system.getCPU())
   
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

   --logFileFP = io.open(prefix() .. pathJson .. lfn, "w")

   system.registerLogVariable("ALGesture", "", gestureCB) 

   print("DFM-HUD: CPU end init(): ", system.getCPU())

   --debugging GPS points for ILS at Black Dirt Field
   ---[[
   if emflag ~= 0 then
      Glass.settings.latId = 3
      Glass.settings.latPa = 2
      Glass.settings.lngPa = 3
      Glass.var.startTakeoff = gps.newPoint(41.34062, -74.43160)
      Glass.var.gearUp = gps.newPoint(41.33827, -74.43077)
      Glass.var.zeroPos = gps.newPoint(41.33980, -74.43146)
   end
   --]]
end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.00", name=appName}
