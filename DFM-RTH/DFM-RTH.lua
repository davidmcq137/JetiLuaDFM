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

local function loop()
   local now = system.getTimeCounter()
   local sensor
   local scale
   local minV, maxV
   local MINHDGDIST = 5
   local MINGPSREADS= 9
   
   if emflag ~= 0 and system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
   end

   sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
   if sensor and sensor.valid then
      if not RTH.var.startTakeoffAlt then
	 RTH.var.startTakeoffAlt = sensor.value
      end
      RTH.altitide = sensor.value - RTH.var.startTakeoffAlt
   end

   -- read heading here if GPS sensor has one
   local hdg
   
   sensor = system.getSensorByID(RTH.settings.hdgId, RTH.settings.hdgPa)
   if sensor and sensor.valid then
      hdg = sensor.value
   end

   
   local gs = RTH.settings
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      local temp
      temp = RTH.curPos
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      if RTH.curPos and temp then
	 if gps.getDistance(temp, RTH.curPos) > MINHDGDIST then 
	    RTH.lastPos = temp
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
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
	    if RTH.lastPos then
	       RTH.gpsHeading = gps.getBearing(RTH.lastPos, RTH.curPos)
	    end
	 end
      end
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

local function init()

   initTime = system.getTime()

   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(RTH)
   
   system.registerForm(1, MENU_APPS, "DFM-RTH", initForm, keyPressed, printForm)
   
   local device
   device, emflag = system.getDeviceType() 
   print("Device", device, "emflag", emflag)
   
   system.registerTelemetry(1, "DFM-RTH Display", 4, printTele)
   system.registerTelemetry(2, "DFM-RTH Status", 1, printTeleSmall)   

   local function initG()
      print("DFM-RTH: No saved state")

      RTH.settings = {}
      RTH.settings.latId = 0
      RTH.settings.latPa = 0
      RTH.settings.lngId = 0
      RTH.settings.lngPa = 0
      RTH.settings.altId = 0
      RTH.settings.altPa = 0
      RTH.settings.hdgId = 0
      RTH.settings.hdgPa = 0      
      
   end

   if not RTH.switchInfo then RTH.switchInfo = {} end
      
   if not RTH.settings then RTH.settings = {} end
   if not RTH.settings.jsnVersion or RTH.settings.jsnVersion ~= JSNVERSION then
      print("old JSON in "..fn.. " - starting with no saved state")
      initG()
      system.messageBox("DFM-RTH: settings reset")
   end
   
   RTH.gpsReads = 0
   RTH.initPos = nil
   RTH.curPos = nil
   RTH.zeroPos = nil
   
   for k, swi in pairs(RTH.switchInfo) do
      local t = string.sub(swi.name,1,1)
      --print("k, swi", k, swi.name, swi.mode, swi.activeOn)
      switchItems[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
   end

   ---[[
   if emflag ~= 0 then
      print("*** DFM-RTH: BDS Defaults being set")
      RTH.settings.latId = 3
      RTH.settings.latPa = 2
      RTH.settings.lngPa = 3
      RTH.var.startTakeoff = gps.newPoint(41.34062, -74.43160)
      RTH.var.gearUp = gps.newPoint(41.337295, -74.430496)
      RTH.var.zeroPos = gps.newPoint(41.33980, -74.43146)
      RTH.var.startTakeoffAlt = 0
   end
   --]]

end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.01", name=appName}
