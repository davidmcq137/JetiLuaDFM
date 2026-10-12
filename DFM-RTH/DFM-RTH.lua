--[[

   -----------------------------------------------------------------------------------------
   DFM-RTH "Return to home" .. Conceived by Harry Curzon, coded by DFM. Initially copied from
   DFM-HUD.lua as starting point

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-RTH.lua released under MIT license by DFM 2026
   -----------------------------------------------------------------------------------------

--]]

local appName = "DFM-RTH"
local pathApp = "Apps/"..appName.."/"
local JSNVERSION = 1
local RTH = {}

RTH.sensorLalist = {"..."}
RTH.sensorLslist = {"..."}
RTH.sensorIdlist = {0}
RTH.sensorPalist = {0}
RTH.sensorUnlist = {"-"}
RTH.sensorDplist = {0}
RTH.sensorTylist = {0}

RTH.gpsLalist = {"..."}
RTH.gpsLslist = {"..."}
RTH.gpsIdlist = {0}
RTH.gpsPalist = {0}

RTH.settings = {}
RTH.timers = {}
RTH.switchInfo = {}
RTH.var = {}

RTH.convertStr = {"None", "m to ft", "m/s to mph", "m/s to km/h", "°C to °F", "/1000"}
RTH.convertVal = {{1,0}, {3.28084,0}, {2.23694,0} , {3.6,0}, {1.8,32}, {.001,0}}
RTH.convertUnits = {"-", "ft", "mph", "km/h", "°F", "-"}

--RTH.switches = {}

local swtCI = {}
local switchItems = {}

local emflag
local modelName
local state = {DISCONNECTED=1, WAITING=2, CONNECTED=3, SENDHEADER=4, SENDFILE=5, SENDFOOTER=6,
	       COMPLETE=7, SELECT=8, ALMOST=9}

local initTime
local pos3D = {}
pos3D.x = {}
pos3D.y = {}
pos3D.z = {}
local pos2D = {}
pos2D.x = {}
pos2D.y = {}


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

local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
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
	 RTH.switchInfo[switchName] = {} 
	 RTH.switchInfo[switchName].name = swInfo.label
	 if swTyp == "L" or swTyp =="M" then
	    RTH.switchInfo[switchName].activeOn = 0
	 else
	    local ao = system.getInputs(string.upper(swInfo.label))
	    RTH.switchInfo[switchName].activeOn = ao
	 end
	 RTH.switchInfo[switchName].mode = swInfo.mode
      else
	 system.messageBox("Error - do not move switch when assigning")
	 --print("CS zeroing")
	 form.setValue(swtCI[switchName], nil)
	 switchItems[switchName] = nil
	 RTH.switchInfo[switchName] = nil	 
      end
   else
      if RTH.switchInfo[switchName] then
	 --print("CS zeroing - not assigned")
	 switchItems[switchName] = nil
	 RTH.switchInfo[switchName] = nil
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

local lastSec

local function loop()
   local now = system.getTimeCounter()
   local sensor
   local MINHDGDIST = 10
   local MINGPSREADS= 9
   
   if not lastSec then lastSec = now end
      
   if emflag ~= 0 and system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
   end

   --print("+", RTH.settings.altId, RTH.settings.altPa)
   sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
   --print("~", sensor, sensor.valid, sensor.value)
   if sensor and sensor.valid then
      --print("##", RTH.var.startTakeoffAlt, sensor.value)
      if not RTH.var.startTakeoffAlt then
	 RTH.var.startTakeoffAlt = sensor.value
      end
      RTH.altitude = sensor.value - RTH.var.startTakeoffAlt
      --print("RTH.altitude", RTH.altitude)
   end

   -- read heading here if GPS sensor has one
   local hdg
   
   sensor = system.getSensorByID(RTH.settings.hdgId, RTH.settings.hdgPa)
   if sensor and sensor.valid then
      hdg = sensor.value
   end
   
   local gs = RTH.settings
   local compHdg
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      --print("#", gs.latId, gs.latPa, gs.lngId, gs.lngPa)
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      --print("%", RTH.curPos)
      if RTH.curPos then
	 if not RTH.lastPos then RTH.lastPos = RTH.curPos end
	 if gps.getDistance(RTH.curPos, RTH.lastPos) > MINHDGDIST then 
	    compHdg = gps.getBearing(RTH.lastPos, RTH.curPos)
	    --print("compHdg", compHdg)
	    RTH.lastPos = RTH.curPos
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
      --print("$", lt, lg, RTH.initPos)
      if RTH.curPos and lt ~= 0 and lg ~= 0 and not RTH.initPos then
	 RTH.gpsReads = RTH.gpsReads + 1
	 print("DFM-RTH: RTH.gpsReads:", RTH.gpsReads)
      end
      if RTH.gpsReads > MINGPSREADS and not RTH.initPos then
	 system.messageBox("DFM-RTH: GPS zero set")
	 print("DFM-RTH: GPS zero set")
	 RTH.initPos = RTH.curPos
	 if not RTH.zeroPos then
	    RTH.zeroPos = RTH.curPos
	 end
	 if not RTH.var.zeroPos then
	    RTH.var.zeroPos = RTH.curPos
	 end
      end
      if RTH.curPos and RTH.zeroPos then
	 RTH.gpsBearingFrom = gps.getBearing(RTH.curPos, RTH.zeroPos)
	 RTH.gpsBearingTo = gps.getBearing(RTH.zeroPos, RTH.curPos)	    
	 RTH.gpsDistance = gps.getDistance(RTH.curPos, RTH.zeroPos)
	 if hdg then
	    RTH.gpsHeading = hdg
	 else
	    if compHdg then
	       RTH.gpsHeading = compHdg
	    end
	 end
      end
   end
   if now - lastSec > 2000 then
      print(RTH.gpsBearingFrom, RTH.gpsBearingTo, RTH.gpsDistance, RTH.gpsHeading, RTH.altitude)
      lastSec = now + 2000
   end
   
end

local function initForm(sf)

   print("initForm, sf=", sf)
   
   local latsel = 0
   local lngsel = 0
   for k = 1, #RTH.gpsLalist do
      if (RTH.gpsIdlist[k] == RTH.settings.latId) and
	 (RTH.gpsPalist[k] == RTH.settings.latPa) then
	 latsel = k
      end
      if (RTH.gpsIdlist[k] == RTH.settings.lngId) and
	 (RTH.gpsPalist[k] == RTH.settings.lngPa) then
	 lngsel = k
      end	 
   end
   
   local altsel = 0
   for k = 1, #RTH.sensorLalist do
      if (RTH.sensorIdlist[k] == RTH.settings.altId) and
	 (RTH.sensorPalist[k] == RTH.settings.altPa) then
	 altsel = k
      end
   end
   
   local hdgsel = 0
   for k = 1, #RTH.sensorLalist do
      if (RTH.sensorIdlist[k] == RTH.settings.hdgId) and
	 (RTH.sensorPalist[k] == RTH.settings.hdgPa) then
	 hdgsel = k
      end
   end
   
   form.addRow(2)
   form.addLabel({label="GPS Lat Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.gpsLalist, latsel, true,
		     (function(i)
			   RTH.settings.latId = RTH.gpsIdlist[i]
			   RTH.settings.latPa = RTH.gpsPalist[i]			      
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})
   
   form.addRow(2)
   form.addLabel({label="GPS Lng Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.gpsLalist, lngsel, true,
		     (function(i)
			   RTH.settings.lngId = RTH.gpsIdlist[i]
			   RTH.settings.lngPa = RTH.gpsPalist[i]			      
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})
   
   form.addRow(2)
   form.addLabel({label="Heading Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.sensorLalist, hdgsel, true,
		     (function(i)
			   RTH.settings.hdgId = RTH.sensorIdlist[i]
			   RTH.settings.hdgPa = RTH.sensorPalist[i]			      
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})

   form.addRow(2)
   form.addLabel({label="Altitude Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.sensorLalist, altsel, true,
		     (function(i)
			   RTH.settings.altId = RTH.sensorIdlist[i]
			   RTH.settings.altPa = RTH.sensorPalist[i]			      
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})
   

end

local function drawRectangleGlass(x0, y0, xl, yl)
   local f = 0.55
   lcd.drawRectangle(f*x0 - f*xl / 2, f*y0 - f*yl / 2, f*xl, f*yl)
end

local function printForm(w,h)
end

local function printTeleSmall(w,h)
end

local function printTele(w,h)
end

local function destroy()
end

local function xytopixel(x, y, w, h)
   
   local xmin, xmax = -400, 400
   local ymin, ymax = -400, 400
   local ix = (w) * (x - xmin) / (xmax - xmin)
   local iy = h - (h) * (y - ymin) / (ymax - ymin)
   return ix,iy
end

local function printTele(w,h)
   if not RTH.gpsBearingTo then return end
   --local tl = gps.newPoint(41.340733, -74.432382)
   --local x, y = gps.getLcdXY(RTH.curPos, tl, 14)
   local x = RTH.gpsDistance * math.sin(math.rad(RTH.gpsBearingTo))
   local y = RTH.gpsDistance * math.cos(math.rad(RTH.gpsBearingTo))   

   local ix, iy = xytopixel(x, y, w, h)
   lcd.drawCircle(ix, iy, 10)
   local ix0 , iy0 = xytopixel(0, 0, w, h)
   lcd.setColor(0,0,255)
   lcd.drawCircle(ix0, iy0, 5)
   lcd.drawText(20, 20, string.format("gpsDistance: %.2f", RTH.gpsDistance), FONT_MINI)
   lcd.drawText(20, 40, string.format("gpsBearingTo: %.2f ", RTH.gpsBearingTo), FONT_MINI)
   lcd.drawText(20, 60, string.format("gpsBearingFrom: %.2f ", RTH.gpsBearingFrom), FONT_MINI)

   lcd.setColor(0,255,0)
   if RTH.gpsHeading then
      local ixh, iyh = ix + 20 * math.sin(math.rad(RTH.gpsHeading)),
	 iy - 20 * math.cos(math.rad(RTH.gpsHeading))
      lcd.drawLine(ix, iy, ixh, iyh)
      lcd.drawText(20, 80, string.format("gpsHeading: %.2f ", RTH.gpsHeading or 0), FONT_MINI)   

   end

   lcd.setColor(255,0,0)
   if RTH.gpsHeading and RTH.gpsBearingFrom then
      local steer = (-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180
      lcd.drawText(20, 100, string.format("Steer: %.2f ", steer), FONT_MINI)
      local ixs, iys = ix + 20 * math.sin(math.rad(steer)), iy - 20 * math.cos(math.rad(steer)) 
      lcd.drawLine(ix, iy, ixs, iys)
      local normSteer = steer / 180.0
      lcd.drawRectangle(60,180,200,30)
      --normSteer = system.getInputs("P4")
      if normSteer >= 0 then
	 lcd.drawFilledRectangle(160,180, 100*normSteer, 30)
      else
	 local ns = math.floor(100*(1+normSteer))
	 lcd.drawFilledRectangle(60 + ns,180, math.floor(100-ns+0.5), 30)	 
      end
      
   end
   
   
   
end

local function init()

   initTime = system.getTime()

   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(RTH)
   
   system.registerForm(1, MENU_APPS, "DFM-RTH", initForm, nil, printForm)
   
   local device
   device, emflag = system.getDeviceType() 
   print("Device", device, "emflag", emflag)
   
   system.registerTelemetry(1, "DFM-RTH Display", 4, printTele)
   system.registerTelemetry(2, "DFM-RTH Status", 1, printTeleSmall)   

   RTH.settings = {}
   RTH.settings.latId = 0
   RTH.settings.latPa = 0
   RTH.settings.lngId = 0
   RTH.settings.lngPa = 0
   RTH.settings.altId = 0
   RTH.settings.altPa = 0
   RTH.settings.hdgId = 0
   RTH.settings.hdgPa = 0      
      
   RTH.gpsReads = 0
   RTH.initPos = nil
   RTH.curPos = nil
   RTH.zeroPos = nil
   
   ---[[
   if emflag ~= 0 then
      print("*** DFM-RTH: BDS Defaults being set")
      RTH.settings.latId = 3
      RTH.settings.latPa = 2
      RTH.settings.lngId = 3
      RTH.settings.lngPa = 3
      RTH.settings.altId = 137
      RTH.settings.altPa = 1
	 
      RTH.var.startTakeoff = gps.newPoint(41.34062, -74.43160)
      RTH.var.gearUp = gps.newPoint(41.337295, -74.430496)
      --RTH.var.zeroPos = gps.newPoint(41.33980, -74.43146)
      RTH.var.startTakeoffAlt = 0
   end
   --]]

   system.registerTelemetry(1, "DFM-RTH Display", 4, printTele)
   system.registerTelemetry(2, "DFM-RTH Status", 1, printTeleSmall)   
   

end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.01", name=appName}
