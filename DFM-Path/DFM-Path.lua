--[[

   -----------------------------------------------------------------------------------------
   DFM-Path .. fly along a path, using Harry and Russell's mechanisms
   copied from DFM-Rscu.lua as starting point

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-Path.lua released under MIT license by DFM 2026
   -----------------------------------------------------------------------------------------
   --
--]]

local appName = "DFM-Path"
local pathApp = "Apps/"..appName.."/"
local RTH = {}
local config = {}
local Path = {}
Path.gps = {}
Path.alt = {}
local pathIndex
local flyIndex
local flyingOutbound
--local calibrating
--local armed = false
--local everEnabled = false
local lastSec
local announceTime
local lastSwO = -1
--local annSeq = 1
local CMULT = 1.33 --circleMax = CMULT * circleMin
local iPindex = 1
local iPMAX = 120
local ixP = {}
local iyP = {}
local inRange = 30 -- meters to target gps point to consider arrived
local xmin, xmax, ymin, ymax
--local origGet
local manAltSetLastVal
local manAltSetLastTime
local steerMode = {petals=1,racetrack=2,leftright=3}
local turnMode = {left=1,right=2,random=3}
local magVal = {0.5, 1, 2, 4, 8}
local magIdx
local DCDS24II

--local rescueOnTime
--local rescueOnDelay
--local holdTurn
local pGain

--[[
local testLatControl
local testLatTime
local testLatOut
local testLatMin
local testLatMax
local testLatRun
--]]

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
local rollVal, pitchVal = 0,0

local renShape
local emflag

--[[
local function inv(t)
   local rt = {}
   if not t then return rt end
   for k,v in pairs(t) do
      rt[v] = k
   end
   return rt
end
--]]

local function drawX(xxp, yyp, d)
   lcd.drawLine(xxp - d, yyp + d, xxp + d, yyp - d)
   lcd.drawLine(xxp - d, yyp - d, xxp + d, yyp + d)
end

local function playNumberCompass(val)
   local ns = string.format("%03d", math.floor(val))
   for digit in string.gmatch(ns, "%d") do
      system.playNumber(tonumber(digit), 0)
   end
end

local function playNumberInt(val)
   system.playNumber(math.floor(val + 0.5), 0)
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function mixOut(mix, val)
   local np = #mix.points
   local mg = mix.gain / 100
   if val <= mix.points[1].x / 100 then
      return mg * mix.points[1].y / 100 
   end
   
   if val >= mix.points[np].x / 100 then
      return mg * mix.points[np].y / 100
   end
   
   for i=2,np,1 do
      if val <= mix.points[i].x / 100 then
	 return mg * (mix.points[i-1].y + (mix.points[i].y - mix.points[i-1].y) *
			    (val * 100 - mix.points[i-1].x) / (mix.points[i].x - mix.points[i-1].x)) / 100
      end
   end
   
   return 0 -- should not happen
end

--[[
local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
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
--]]

local function readSensors(tt)
   local sensorLbl = "***"
   local l1, l2, l3
   local GPStype = 9
   
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    l3 = string.gsub(sensor.unit, "%W", "")
	    if sensor.type ~= GPStype then
	       --print("GPS", sensor.id, sensor.param)
	       table.insert(tt.sensorLalist, l1 .. "_" .. l2 .. " [" .. l3 .. "]")
	       table.insert(tt.sensorLslist, sensor.label)	    
	       table.insert(tt.sensorIdlist, sensor.id)
	       table.insert(tt.sensorPalist, sensor.param)
	       table.insert(tt.sensorUnlist, sensor.unit)
	       table.insert(tt.sensorDplist, sensor.decimals)
	       table.insert(tt.sensorTylist, sensor.type)
	    else
	       table.insert(tt.gpsLalist, l1 .. "_" .. l2 .. " [" .. l3 .. "]")
	       table.insert(tt.gpsLslist, sensor.label)	    
	       table.insert(tt.gpsIdlist, sensor.id)
	       table.insert(tt.gpsPalist, sensor.param)
	    end
	 end
      end
   end
   --[[
   table.insert(tt.sensorLalist, "P8 0-100")
   table.insert(tt.sensorLslist, "")	    
   table.insert(tt.sensorIdlist, 1) --sensor.id)
   table.insert(tt.sensorPalist, 8) --sensor.param)
   table.insert(tt.sensorUnlist, "m") --sensor.unit)
   table.insert(tt.sensorDplist, 0) --sensor.decimals)
   table.insert(tt.sensorTylist, 100) --sensor.type)
   --]]
end

--[[
local function encdp(dp, val)
   if dp == 2 then
      return string.format("%.2f", val)
   elseif dp == 1 then
      return string.format("%.1f", val)
   else
      return string.format("%.0f", val)
   end
end
--]]

--local nsHoldVal
--local nsHoldTime
--local turnTime

local function loop()
   local now
   local sensor
   local MINHDGDIST = 3
   local MINGPSREADS= 9
   --local MINANNDIST = 5
   local info
   local SwO, SwC
   local altnow
   
   now = system.getTimeCounter()
   if not lastSec then lastSec = now end
   if not announceTime then announceTime = now end

   --if emflag ~= 0 and system.getTimeCounter() < 0 then
   --   print("system.getTimeCounter() wrapped. Restart emulator", system.getTimeCounter())
   --end

   --[[
   if MapsAimPoint then
      for i,v in ipairs(MapsAimPoint) do
	 print(i, v.x, v.y)
      end
   end
   --]]
   
   sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
   --print("Sensor", RTH.settings.altId, RTH.settings.altPa, sensor.value)
   if sensor and sensor.valid then
      --print("Sensor", RTH.settings.altId, RTH.settings.altPa, sensor.value)
      --tele should only report in m but some devices can do other units .. be defensive
      if sensor.unit == "ft" or sensor.unit == "ft." then
	 altnow = sensor.value * 0.3048
      else
	 altnow = sensor.value
      end
      if not RTH.var.startTakeoffAlt then
	 if emflag ~= 0 then
	    RTH.var.startTakeoffAlt = 0
	 else
	    RTH.var.startTakeoffAlt = altnow
	 end
	 --print("altnow, RTH.var.startTakeoffAlt", altnow, RTH.var.startTakeoffAlt)
      end
      RTH.altitude = altnow - RTH.var.startTakeoffAlt

   end

   -- read heading here if GPS sensor has one
   local hdg
   
   sensor = system.getSensorByID(RTH.settings.hdgId, RTH.settings.hdgPa)
   if sensor and sensor.valid then
      hdg = sensor.value
   end

   rollVal = 0
   sensor = system.getSensorByID(RTH.settings.rollId, RTH.settings.rollPa)
   if sensor and sensor.valid then
     rollVal = sensor.value
   end
   
   pitchVal = 0
   sensor = system.getSensorByID(RTH.settings.pitchId, RTH.settings.pitchPa)
   if sensor and sensor.valid then
     pitchVal = sensor.value
   end

   local manAltSet

   -- If manual alt setting is enabled, read it and announce once after change when stable
   -- Assume 0-100% is 0-100m
   
   info = system.getSwitchInfo(RTH.settings.altInput)
   if info and info.assigned and info.proportional and string.find(info.mode, "C") then
      manAltSet = info.value * 100
      if manAltSetLastVal and manAltSet == manAltSetLastVal then
	 if manAltSetLastTime and now > manAltSetLastTime + 1000 then
	    system.playFile(prefix() .. pathApp .. "Audio/altitudeset.wav", AUDIO_QUEUE)      
	    playNumberInt(manAltSet)
	    system.playFile(prefix() .. pathApp .. "Audio/meters.wav", AUDIO_QUEUE)      	 
	    manAltSetLastTime = nil
	 end
      else
	 manAltSetLastVal = manAltSet
	 manAltSetLastTime = now
      end
   end
   
   local gs = RTH.settings
   local compHdg
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      if RTH.curPos then
	 if not RTH.lastPos then RTH.lastPos = RTH.curPos end
	 if gps.getDistance(RTH.curPos, RTH.lastPos) > MINHDGDIST then 
	    compHdg = gps.getBearing(RTH.lastPos, RTH.curPos)
	    --print(gps.getDistance(RTH.curPos, RTH.lastPos), compHdg)
	    RTH.lastPos = RTH.curPos
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
      if RTH.curPos and lt ~= 0 and lg ~= 0 and not RTH.zeroPos then
	 RTH.gpsReads = RTH.gpsReads + 1
      end
      if RTH.gpsReads > MINGPSREADS and not RTH.zeroPos then
	 RTH.zeroPos = RTH.curPos
	 if altnow then
	    if emflag ~= 0 then
	       RTH.var.startTakeoffAlt = 0
	       print("DFM-Path: GPS zero set, Alt zero not set (emulator)")
	    else
	       RTH.var.startTakeoffAlt = altnow
	       system.messageBox(appName..": GPS and Alt zero set")
	       --print("GPS and Alt zero set")
	    end
	    
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

   -- read the switch for mixer calibration
   if RTH.settings.calSw then
      info = system.getSwitchInfo(RTH.settings.calSw)
      if info then
	 SwC = info.value
      else
	 SwC = -1
      end
   else
      SwC = -1
   end

   if lastSwC == -1 and SwC == 1 then
      --calibrating = true
      if not pathIndex then pathIndex = 0 end
      pathIndex = pathIndex + 1
      Path.gps[pathIndex] = RTH.curPos
      Path.alt[pathIndex] = RTH.altitude
      altSetPoint = RTH.altitude
      
      system.messageBox(string.format("Captured Point %d - Alitude %d ", pathIndex, RTH.altitude or 0))

      system.playFile(prefix() .. pathApp .. "Audio/pointnumber.wav", AUDIO_QUEUE)
      playNumberInt(pathIndex)

      if RTH.altitude then
	 system.playFile(prefix() .. pathApp .. "Audio/altitude.wav", AUDIO_QUEUE)      
	 playNumberInt(RTH.altitude)
	 system.playFile(prefix() .. pathApp .. "Audio/meters.wav", AUDIO_QUEUE)      	 
      end
      --rescueOnTime = now
   end

   --if lastSwC == 1 and SwC == -1 and calibrating == true then -- just turned off
   --end

   lastSwC = SwC

   -- read the switch for RTH steering on/off
   if RTH.settings.onoffSw then
      info = system.getSwitchInfo(RTH.settings.onoffSw)
      if info then
	 SwO = info.value
      else
	 SwO = -1
      end
   else
      SwO = -1
   end

   if lastSwO == -1 and SwO == 1 then
      if pathIndex and pathIndex > 0 then
	 flyIndex = 1
	 system.playFile(prefix() .. pathApp .. "Audio/steeringtopoint.wav", AUDIO_QUEUE)
	 playNumberInt(flyIndex)
	 --compute bearing to next point
	 local gb = gps.getBearing(RTH.curPos, Path.gps[flyIndex])
	 system.playFile(prefix() .. pathApp .. "Audio/course.wav", AUDIO_QUEUE)
	 playNumberCompass(gb)
	 system.playFile(prefix() .. pathApp .. "Audio/degrees.wav", AUDIO_QUEUE)
      end
      RTH.settings.onoff = SwO
   end

   if lastSwO == 1 and SwO == -1 then
      flyIndex = 0
      RTH.settings.onoff = SwO
   end
   
   lastSwO = SwO

   RTH.settings.steer = 0
   RTH.settings.elev = 0
   
   local validmixA = false
   local validmixE = false
   
   local eleSet
   local ailSet

   if manAltSet then altSetPoint = manAltSet end
      
   if RTH.settings.onoff and RTH.settings.onoff > 0 then
      if flyIndex and flyIndex > 0 and not manAltSet then
	 altSetPoint = Path.alt[flyIndex]
      else
	 altSetPoint = manAltSet
      end
      
      if RTH.altitude and altSetPoint then
	 local rawsig = RTH.altitude - altSetPoint
	 local errsig = rawsig * (pGain or 0)
	 if errsig > 1 then errsig = 1 end
	 if errsig < -1 then errsig = -1 end
	 eleSet = errsig
	 --system.setControl(RTH.settings.elevCtrl, errsig, 1000, 1)
      else
	 eleSet = 0
	 --system.setControl(RTH.settings.elevCtrl, 0, 1000, 1)
      end
      validmixE = true
   end
   
   if RTH.settings.onoff and flyIndex and RTH.settings.onoff > 0 and flyIndex > 0 then

      -- Now steer
      
      RTH.bearingTo = gps.getBearing(RTH.curPos, Path.gps[flyIndex])
      RTH.distanceTo = gps.getDistance(RTH.curPos, Path.gps[flyIndex])
      RTH.settings.steer = (-RTH.gpsHeading + RTH.bearingTo + 180) % 360 - 180
      
      local ns = RTH.settings.steer / 180 -- normalized to [-1..1]
      
      ailSet = mixOut(config.Amix,ns)
      eleSet = eleSet + RTH.settings.maxElevGain / 100 * mixOut(config.Emix,ns)
      --print("eleSet", eleSet)
      
      validmixA = true
      validmixE = true
      
      -- Check if at next point now .. and if so advance
      
      if RTH.distanceTo < inRange then
	 local fCurrent = flyIndex
	 flyIndex = flyIndex + 1
	 if flyIndex > #Path.gps then flyIndex = 1 end

	 if fCurrent ~= flyIndex then -- they are equal when there is only one point 
	    system.messageBox(string.format(appName .. ": Steering to point %d", flyIndex))
	    system.playFile(prefix() .. pathApp .. "Audio/steeringtopoint.wav", AUDIO_QUEUE)
	    playNumberInt(flyIndex)
	    --compute bearing to next point
	    local gb = gps.getBearing(Path.gps[fCurrent], Path.gps[flyIndex])
	    system.playFile(prefix() .. pathApp .. "Audio/course.wav", AUDIO_QUEUE)
	    playNumberCompass(gb)
	    system.playFile(prefix() .. pathApp .. "Audio/degrees.wav", AUDIO_QUEUE)
	 end
      end
      
   end

   --If for any reason mix was not done, set mix controls to 0

   if not validmixA then
      if RTH.settings.steerCtrl then system.setControl(RTH.settings.steerCtrl, 0, 0) end
   else
      if RTH.settings.steerCtrl then system.setControl(RTH.settings.steerCtrl, ailSet, 100, 1) end
   end

   if not validmixE then
      if RTH.settings.elevCtrl then system.setControl(RTH.settings.elevCtrl, 0, 0) end
   else
      if RTH.settings.elevCtrl then system.setControl(RTH.settings.elevCtrl, eleSet, 100, 1) end
   end
   
end

local activeSf

local function keyPress(key)
   if activeSf ~= 2 then return end
   form.preventDefault()
   if key == KEY_ESC or key == KEY_5 then
      if RTH.settings.steerCtrl then system.setControl(RTH.settings.steerCtrl, 0, 0) end
      if RTH.settings.elevCtrl then system.setControl(RTH.settings.elevCtrl, 0, 0) end      
   end
end

local function initForm(subform)

   local latsel = 0
   local lngsel = 0
   local altsel = 0
   local hdgsel = 0
   local rollsel = 0
   local pitchsel = 0
   
   activeSf = subform
   
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

   for k = 1, #RTH.sensorLalist do
      if (RTH.sensorIdlist[k] == RTH.settings.altId) and
	 (RTH.sensorPalist[k] == RTH.settings.altPa) then
	 altsel = k
      end
      if (RTH.sensorIdlist[k] == RTH.settings.hdgId) and
	 (RTH.sensorPalist[k] == RTH.settings.hdgPa) then
	 hdgsel = k
      end
      if (RTH.sensorIdlist[k] == RTH.settings.rollId) and
	 (RTH.sensorPalist[k] == RTH.settings.rollPa) then
	 rollsel = k
      end
      if (RTH.sensorIdlist[k] == RTH.settings.pitchId) and
	 (RTH.sensorPalist[k] == RTH.settings.pitchPa) then
	 pitchsel = k
      end
   end

   local function onoffChanged(value)
      RTH.settings.onoffSw = value
      system.pSave("RTHonoffSw", RTH.settings.onoffSw)
   end
   
   form.addRow(2)
   form.addLabel({label="Path mode switch", width=155, font=FONT_NORMAL})
   form.addInputbox(RTH.settings.onoffSw, true, onoffChanged, {alignRight=false})
   
   local function calChanged(value)
      RTH.settings.calSw = value
      system.pSave("RTHcalSw", RTH.settings.calSw)
   end

   form.addRow(2)
   form.addLabel({label="Capture gps point switch", width=175, font=FONT_NORMAL})
   form.addInputbox(RTH.settings.calSw, true, calChanged,
		    {width=155, font=FONT_NORMAL, alignRight=false})

   
   local function acChanged(value)
      local si = system.getSwitchInfo(value)
      --print("si", si.label, si.value, si.proportional, si.assigned, si.mode)
      if not si.proportional or not string.find(si.mode, "C") then
	 system.messageBox("Control must be 0-100% proportional")
	 RTH.settings.altInput = nil
	 form.reinit(1)
      else
	 RTH.settings.altInput = value
	 system.pSave("altInput", value)
      end
   end
   
   form.addRow(2)
   form.addLabel({label="Man alt setpoint (0-100m)", width=180, font=FONT_NORMAL})   
   form.addInputbox(RTH.settings.altInput, true, acChanged,
		    {width=155, font=FONT_NORMAL, alignRight=false})

   local function egChanged(value)
      RTH.settings.maxElevGain = value
      system.pSave("maxElevGain", value)
   end
   
   form.addRow(2)
   form.addLabel({label="Elevator mix percentage", font=FONT_NORMAL})   
   form.addIntbox(RTH.settings.maxElevGain, -100, 100, 0, 0, 1, egChanged,
		  {width=155, font=FONT_NORMAL, alignRight=false})
   
   form.addRow(2)
   form.addLabel({label="GPS Lat Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.gpsLalist, latsel, true,
		     (function(i)
			   RTH.settings.latId = RTH.gpsIdlist[i]
			   RTH.settings.latPa = RTH.gpsPalist[i]
			   system.pSave("RTHlatId", RTH.settings.latId)
			   system.pSave("RTHlatPa", RTH.settings.latPa)
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})
   
   form.addRow(2)
   form.addLabel({label="GPS Lng Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.gpsLalist, lngsel, true,
		     (function(i)
			   RTH.settings.lngId = RTH.gpsIdlist[i]
			   RTH.settings.lngPa = RTH.gpsPalist[i]			      
			   system.pSave("RTHlngId", RTH.settings.lngId)
			   system.pSave("RTHlngPa", RTH.settings.lngPa)
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})
   
   form.addRow(2)
   form.addLabel({label="Heading Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.sensorLalist, hdgsel, true,
		     (function(i)
			   RTH.settings.hdgId = RTH.sensorIdlist[i]
			   RTH.settings.hdgPa = RTH.sensorPalist[i]
			   system.pSave("RTHhdgId", RTH.settings.hdgId)
			   system.pSave("RTHhdgPa", RTH.settings.hdgPa)			   
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})

   form.addRow(2)
   form.addLabel({label="Altitude Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.sensorLalist, altsel, true,
		     (function(i)
			   RTH.settings.altId = RTH.sensorIdlist[i]
			   RTH.settings.altPa = RTH.sensorPalist[i]
			   system.pSave("RTHaltId", RTH.settings.altId)
			   system.pSave("RTHaltPa", RTH.settings.altPa)			   
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})

   ---[[
   form.addRow(2)
   form.addLabel({label="Roll Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.sensorLalist, rollsel, true,
		     (function(i)
			   RTH.settings.rollId = RTH.sensorIdlist[i]
			   RTH.settings.rollPa = RTH.sensorPalist[i]
			   system.pSave("RTHrollId", RTH.settings.rollId)
			   system.pSave("RTHrollPa", RTH.settings.rollPa)			   
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})

   form.addRow(2)
   form.addLabel({label="Pitch Sensor", font=FONT_NORMAL})
   form.addSelectbox(RTH.sensorLalist, pitchsel, true,
		     (function(i)
			   RTH.settings.pitchId = RTH.sensorIdlist[i]
			   RTH.settings.pitchPa = RTH.sensorPalist[i]
			   system.pSave("RTHpitchId", RTH.settings.pitchId)
			   system.pSave("RTHpitchPa", RTH.settings.pitchPa)			   
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})
   --]]
   
   form.addRow(2)
   form.addLabel({label="Distance units", font=FONT_NORMAL})
   form.addSelectbox({"m", "ft"}, RTH.settings.distUnits, true,
		     (function(i)
			   RTH.settings.distUnits = i
			   system.pSave("RTHdistUnits", RTH.settings.distUnits)
			   return end),
		     {width=155, font=FONT_NORMAL, alignRight=false})

   form.addRow(2)
   form.addLabel({label="Alt Loop pGain", font=FONT_NORMAL})
   form.addIntbox(pGain*1000, -1000, 1000, 100, 3, 1,
		  (function(x)
			pGain = x / 1000.0
			system.pSave("pGain", pGain * 1000)
			return end),
		  {width=155, font=FONT_NORMAL, algignRight=false})

   form.addRow(1)
   form.addLink((
	 function()
	    local SPath = {}
	    local lats, lngs
	    SPath.gps = {}
	    SPath.alt = {}
	    -- have to create string representation .. can't serialize gpsPoints
	    for i,v in ipairs(Path.gps) do
	       lats, lngs = gps.getString(v) --Path.gps[i])
	       SPath.gps[i] = {}
	       SPath.gps[i].lat = lats
	       SPath.gps[i].lng = lngs
	       SPath.alt[i] = Path.alt[i]
	    end
	    local str = json.encode(SPath)
	    local f = io.open(prefix()..pathApp.."Json/Path.jsn", "w")
	    if f then
	       io.write(f, str, "\n")
	       io.close(f)
	       system.messageBox("Path file saved")
	    end
	 end), {label="Save Path >>", font=FONT_NORMAL})

   -- Should think about if enable has to be off to read a file of GPS points?
   
   form.addRow(1)
   form.addLink((
	 function()
	    local str = io.readall(prefix()..pathApp.."Json/Path.jsn", "r")
	    if not str then system.messageBox("No file read") end
	    if str then
	       Path = {}
	       Path.gps = {}
	       Path.alt = {}
	       flyIndex = 0
	       pathIndex = 0
	       local SPath = json.decode(str)
	       for i,v in ipairs(SPath.gps) do
		  --Path.gps[i] = gps.newPoint(SPath.gps[i].lat, SPath.gps[i].lng)
		  Path.gps[i] = gps.newPoint(v.lat, v.lng)		  
		  Path.alt[i] = SPath.alt[i]
	       end
	       pathIndex = #Path.gps
	       system.messageBox(string.format("Path file read, %d points", pathIndex))
	    end
	 end), {label="Load saved Path >>", font=FONT_NORMAL})
end


local function drawShape(col, row, shape, rotation)
   local dsc = 1.5
   local sinShape = math.sin(rotation)
   local cosShape = math.cos(rotation)
   renShape:reset()
   for _, point in pairs(shape) do
      renShape:addPoint(
	 col + (dsc*point[1] * cosShape - dsc*point[2] * sinShape + 0.5),
	 row + (dsc*point[1] * sinShape + dsc*point[2] * cosShape + 0.5)
      )
   end
   renShape:renderPolygon()
end

local function drawSideShape(col, row, shape, backshape, backhgt, azimuth, pitch)
   local dsc = 1.5
   local cosA = math.cos(azimuth + math.pi/2)
   local sinShape = math.sin(-pitch)
   local cosShape = math.cos(-pitch)   

   renShape:reset()
   local cc, rr
   -- glider back about 2 px wide, tail 7 px long, atan(2/7) is about 9 degrees
   -- but empirically 10-11 looks nicer when animated, use backhgt*1.5 as approximation
   if math.abs((math.deg(azimuth)%180 - 180)) < backhgt * 1.5 or
      math.abs((math.deg(azimuth)%180)) < backhgt * 1.5 then
      for _, point in pairs(backshape) do
	 renShape:addPoint(col + dsc*point[1] + cosA * backhgt,
			   row - dsc*point[2] + math.sin(pitch)*backhgt)
      end
   else
      for _, point in pairs(shape) do
	 cc = (dsc*point[1] * cosShape + dsc*point[2] * sinShape + 0.5)
	 rr = (dsc*point[1] * sinShape - dsc*point[2] * cosShape + 0.5) 
	 cc = -cc * cosA
	 rr = rr
	 renShape:addPoint(
	    col + cc,
	    row + rr
	 )
      end
   end
   
   renShape:renderPolygon()
end

local function drawLine(col, row, shape, rotation, lw)
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   renShape:reset()
   for _, point in pairs(shape) do
      renShape:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      )
   end
   renShape:renderPolyline(lw)
end

local function printForm()

end

local function destroy()

end


local function printTeleMix()

   local x0,y0 = 220, 5
   local xl, yl = 1.23*80, 80
   local min, max = -100, 100
   
   local function xp(val)
      return x0 + xl * (val - min) / (max - min)
   end

   local function yp(val)
      return 130  - (y0 + yl * (val - min) / (max - min))
   end

   
   if not RTH.settings.steerCtrl or not RTH.settings.steer then
      lcd.drawText(5, 2, "No steering value", FONT_NORMAL)
      return
   end

   --print("steer", RTH.settings.steer)
   local ns = RTH.settings.steer / 180.0
   local am = mixOut(config.Amix, ns)
   local em = RTH.settings.maxElevGain / 100 * mixOut(config.Emix, ns)

   for i=2,#config.Amix.points,1 do
      lcd.setColor(0,0,255)
      lcd.drawLine(xp(config.Amix.points[i-1].x), yp(config.Amix.points[i-1].y),
		   xp(config.Amix.points[i].x), yp(config.Amix.points[i].y))
      lcd.setColor(255,0,0)
      lcd.drawLine(xp(config.Emix.points[i-1].x),
		   yp(RTH.settings.maxElevGain / 100 * config.Emix.points[i-1].y),
		   xp(config.Emix.points[i].x),
		   yp(RTH.settings.maxElevGain / 100 * config.Emix.points[i].y))

      lcd.setColor(0,0,255)
      lcd.drawCircle(xp(ns * 100), yp(am * 100), 4)
      lcd.setColor(255,0,0)
      drawX(xp(ns * 100), yp(em * 100), 4)      
      lcd.setColor(0,0,0)
   end
   
end

--[[
local function printTeleBig()
   
   if not RTH.gpsBearingTo then
      lcd.drawText(5,  2, "No GPS signal", FONT_NORMAL)
      return
   end

   --if not RTH.settings.onoff or RTH.settings.onoff < 0 then
   --   lcd.drawText(5,  2, "Not enabled", FONT_NORMAL)
   --   return
   --end

   local conv, un

   if RTH.settings.distUnits ~= 1 then -- ft
      conv = 3.2808
      un = "ft"
   else
      conv = 1
      un = "m"
   end
         
   lcd.drawText(5,  2, string.format("Bearing: %.0f°", RTH.gpsBearingTo or 0), FONT_NORMAL)
   lcd.drawText(5, 20, string.format("Distance: %.0f"..un, conv*(RTH.gpsDistance or 0), FONT_NORMAL))
   lcd.drawText(5, 38, string.format("Altitude: %.1f"..un, conv*(RTH.altitude or 0), FONT_NORMAL))
   lcd.drawText(5, 54, string.format("Heading: %.0f°", RTH.gpsHeading or 0), FONT_NORMAL)   

   if RTH.gpsHeading and RTH.gpsBearingFrom then
      local steer = RTH.settings.steer
      local normSteer = steer / 180.0
      --normSteer = system.getInputs("P4")
      --print(normSteer)
      lcd.drawRectangle(20,75,120,20)
      if RTH.settings.onoff == 1 then lcd.setColor(255,0,0) else lcd.setColor(0,0,0) end
      lcd.drawFilledRectangle(79, 75, 2, 20)
      if normSteer >= 0 then
	 lcd.drawFilledRectangle(80,75, 60*normSteer, 20)
      else
	 local ns = math.floor(60*(1+normSteer))
	 lcd.drawFilledRectangle(20 + ns,75, 60-ns, 20)	 
      end
   end
   if RTH.gpsHeading then
      lcd.setColor(0,0,255)
      drawShape(120,20, homeShape, math.rad(RTH.gpsHeading)) 
   end
   
end
--]]

local function printTeleAH()

   --local xc = 50
   --local dx = 40

   local hLineShape = {
      {-40,0},
      {40,0}
   }

   local vLineShape = {
      {-40,-30},
      {-40, 30}
   }

   local hDashShape = {
      {-40, 0},
      {-30, 0}
   }
   local pitch = pitchVal or 0 -- system.getInputs("P2") * 90 -- pitchVal or 0 
   local roll = rollVal or 0 --system.getInputs("P3") * 180 -- rollVal or 0

   --print(roll)
   --print(pitch)
   drawLine(50, 85, hLineShape, math.rad(roll), 2)
   drawLine(50, 85, hLineShape, 0, 1)
   drawLine(50, 85, vLineShape, 0, 1)
   drawLine(50, 85 -pitch, hDashShape, 0, 2)
   
end


local function xytopixel(x, y)

   local w, h = 320, 160
   local ix = w * (x - xmin) / (xmax - xmin)
   local iy = h - h * (y - ymin) / (ymax - ymin)
   return ix,iy
end

local function printTeleGPS(w,h)
   if not RTH.gpsBearingTo then
      lcd.drawText(5,5, "No GPS signal")
      return
   end
   
   printTeleAH(w,h)
   
   printTeleMix(w,h)

   local x, y, ix, iy

   lcd.setColor(0,0,0)

   if pathIndex and pathIndex > 0 then
      local bb, dd
      for i=1, pathIndex, 1 do
	 bb = gps.getBearing(RTH.zeroPos, Path.gps[i])
	 dd = gps.getDistance(RTH.zeroPos, Path.gps[i])
	 x = dd * math.sin(math.rad(bb))
	 y = dd * math.cos(math.rad(bb))
	 ix, iy = xytopixel(x, y, w, h)
	 local ss = string.format("%d", i)
	 local ww = lcd.getTextWidth(FONT_MINI, ss)
	 local hh = lcd.getTextHeight(FONT_MINI, ss)
	 lcd.drawNumber(ix - ww/2, iy - hh/2, i, FONT_MINI)
	 --drawX(ix, iy, 3)
	 local rr = 320 * inRange / (xmax - xmin) 
	 lcd.drawCircle(ix, iy, rr)
      end
   end
   
   x = RTH.gpsDistance * math.sin(math.rad(RTH.gpsBearingTo))
   y = RTH.gpsDistance * math.cos(math.rad(RTH.gpsBearingTo))
   
   ix, iy = xytopixel(x, y, w, h)
   if RTH.settings.onoff < 1 then
      lcd.setColor(0,0,0)
   else
      if flyingOutbound then lcd.setColor(255,0,0) else lcd.setColor(0,0,255) end
   end

   drawShape(ix,iy, config.GliderTop, math.rad(RTH.gpsHeading or 0)) 

   local dist
   if iPindex > 1 then
      dist = math.sqrt((ix - ixP[iPindex-1])^2 + (iy - iyP[iPindex-1])^2)
   end

   if not dist or dist > 4 then --4m min point spacing
      ixP[iPindex] = ix
      iyP[iPindex] = iy
      if iPindex < iPMAX then
	 iPindex = iPindex + 1
      else
	 iPindex = 1
      end
   end
   --local pp = math.floor((pitchVal or 0) * 100 + 0.5) / 100
   if pitchVal == -0.0 then pitchVal = 0 end

   if DCDS24II then
      ix, iy = xytopixel(x, xmin + 35 + RTH.altitude*3, w, h)
      drawSideShape(ix, iy, config.GliderSide, config.GliderBack, 7,
		    math.rad(RTH.gpsHeading or 0), math.rad(pitchVal))
      --lcd.drawCircle(ix, iy, 4)
   end
   
   lcd.setColor(0,0,0)

   for i=1, #ixP, 1 do
      lcd.drawCircle(ixP[i], iyP[i], 1)
   end
   
   lcd.setColor(0,0,0)
   --local ix0 , iy0 = xytopixel(0, 0, w, h)
   --lcd.drawCircle(ix0, iy0, 2)
   
   lcd.drawText(10, 15, string.format("[%d,%d,%d,%d]", xmin, xmax, ymin, ymax), FONT_MINI)
   if flyIndex and flyIndex > 0 and RTH.bearingTo then
      lcd.drawText(150, 15, string.format("Steering %03d° to point %d dist %d",
					  RTH.bearingTo or 0,
					  flyIndex or 0,
					  RTH.distanceTo or 0), FONT_MINI)
   end
   

   --lcd.drawText(60, 145, string.format("Dist: %d", RTH.gpsDistance), FONT_MINI)
   --lcd.drawText(190, 145, string.format("BrgTo: %d", RTH.gpsBearingTo), FONT_MINI)

   local as
   if altSetPoint then as = string.format("%.1fm", altSetPoint) else as = "---" end
   local st = system.getServos()
   local eleS = 0
   for _, sv in pairs(st) do
      if sv.id == 267 then
	 eleS = sv.value * 100
	 break
      end
   end

   local cpu = system.getCPU()
   lcd.drawText(10, 145, string.format(
		   "Alt: %.1fm  Alt Set %s  Pitch %+.1f°  Ele Servo %+d%%  CPU %d%%",
		   RTH.altitude or 0, as, pitchVal or 0, eleS, cpu), FONT_MINI)
   
end

--[[
local function logfileCB(idx)
   if idx == 1 then
      return RTH.gpsBearingFrom or 0
   elseif idx == 2 then
      return RTH.gpsBearingTo or 0      
   elseif idx == 3 then
      return 10 * (RTH.gpsDistance or 0), 1
   elseif idx == 4 then
      return RTH.gpsHeading or 0
   elseif idx == 5 then
      --print("##", RTH.settings.steer, RTH.settings.steer / 1.80)
      return (RTH.settings.steer or 0) / 1.80
   else
      return -999
   end
end
--]]

local function setMag(idx)
   if idx < 1 or idx > #magVal then return end
   xmax = 2 * magVal[idx] * math.floor(RTH.settings.circleMin * CMULT + 0.5)
   xmin = -xmax
   ymax = magVal[idx] * math.floor(RTH.settings.circleMin * CMULT + 0.5)
   ymin = -ymax
   ixP = {}
   iyP = {}
   iPindex = 1
end

local function keyPressGPS(key)
   --print("key", key)
   if key == KEY_1 then
      magIdx = magIdx + 1
      if magIdx > #magVal then magIdx = #magVal end
      setMag(magIdx)
   elseif key == KEY_2 then
      magIdx = magIdx - 1
      if magIdx < 1 then magIdx = 1 end
      setMag(magIdx)
   elseif key == KEY_3 then
      iPindex = 1
      ixP = {}
      iyP = {}
   elseif key == KEY_4 then
      Path = {}
      Path.gps = {}
      Path.alt = {}
      system.setControl(RTH.settings.elevCtrl, 0, 0, 1)      
      flyIndex = 0
      pathIndex = 0
      altSetPoint = RTH.altitude
      --else -- key5
   end
end

--local function getSensorByID(id, pa)
--   return origGet(id, pa)
--end

local function init()

   renShape   = lcd.renderer()
   readSensors(RTH)
   
   system.registerForm(1, MENU_APPS, "DFM-Path", initForm, keyPress, printForm)
   
   local device
   device, emflag = system.getDeviceType() 
   --print("Device", device, "emflag", emflag)

--   if device == "JETI DS-24 II" or device == "JETI DC-24 II" then
--     do something different on new tx?      
--   end
   
   system.registerTelemetry(1, "Flight Path", 4, printTeleGPS, keyPressGPS)
   
   if system.setTelemetryButton then
      system.setTelemetryButton(1, 1, "-", 1)
      system.setTelemetryButton(1, 2, "+", 1)
      system.setTelemetryButton(1, 3, "Erase", 1)
      system.setTelemetryButton(1, 4, "Reset", 1)
      --system.setTelemetryButton(1, 5, "5", 1)      
   else
      print("not setting Button")
   end
   
   RTH.settings = {}
   RTH.settings.latId = system.pLoad("RTHlatId", 0)
   RTH.settings.latPa = system.pLoad("RTHlatPa", 0)

   RTH.settings.lngId = system.pLoad("RTHlngId", 0)
   RTH.settings.lngPa = system.pLoad("RTHlngPa", 0)

   RTH.settings.altId = system.pLoad("RTHaltId", 0)
   RTH.settings.altPa = system.pLoad("RTHaltPa", 0)

   RTH.settings.hdgId = system.pLoad("RTHhdgId", 0)
   RTH.settings.hdgPa = system.pLoad("RTHhdgPa", 0)   

   RTH.settings.rollPa = system.pLoad("RTHrollPa", 0)
   RTH.settings.rollId = system.pLoad("RTHrollId", 0)

   RTH.settings.pitchId = system.pLoad("RTHpitchId", 0)
   RTH.settings.pitchPa = system.pLoad("RTHpitchPa", 0)      

   RTH.settings.onoffSw = system.pLoad("RTHonoffSw")
   RTH.settings.calSw = system.pLoad("RTHcalSw")
   RTH.settings.altInput = system.pLoad("altInput")
   
   RTH.settings.distUnits = system.pLoad("RTHdistUnits", 1) -- meters is default
   RTH.settings.circStrat = system.pLoad("RTHcircStrat", steerMode.petals) -- "petals" default
   RTH.settings.turnDir = system.pLoad("RTHturnDir", turnMode.left)   -- "left" default
   
   RTH.settings.circleMin = system.pLoad("circleMin", 150)
   RTH.settings.maxElevGain = system.pLoad("maxElevGain", 0)
   --rescueOnDelay = system.pLoad("rescueOnDelay", 3)
   --holdTurn = system.pLoad("holdTurn", 5)
   pGain = system.pLoad("pGain", 100) / 1000
   
   flyingOutbound = false
   --calibrating = false

   magIdx = 3
   setMag(magIdx)
   
   RTH.gpsReads = 0
   RTH.curPos = nil
   RTH.zeroPos = nil

   RTH.settings.steerCtrl = nil
   local iRTS = 3
   RTH.settings.steerCtrl = system.registerControl(iRTS, "Path Steering", "RTS")

   RTH.settings.steer = 0
   RTH.settings.onoff = -1
   
   if RTH.settings.steerCtrl then
      print(appName ..": Steering registered to control "..RTH.settings.steerCtrl)
      system.setControl(RTH.settings.steerCtrl, RTH.settings.steer, 0)
   else
      print(appName .. ": Could not register steer control")
      system.messageBox(appName .. ": Could not register steer control")
   end


   --[[
   testLatControl = system.registerControl(10, "Latency", "LAT")
   print("testLatControl", testLatControl)
   testLatOut = 1
   if not system.setControl(testLatControl, testLatOut, 0) then
      print("set control failed")
   end
   testLatTime = system.getTimeCounter()
   --]]
   
   RTH.settings.elevCtrl = nil
   local iRTE = 4
   RTH.settings.elevCtrl = system.registerControl(iRTE, "Path Elevator", "RTE")
   RTH.settings.elev = 0
   
   if RTH.settings.elevCtrl then
      print(appName ..": Elevator registered to control "..RTH.settings.elevCtrl)
      system.setControl(RTH.settings.elevCtrl, RTH.settings.elev, 0)
   else
      print(appName .. ": Could not register elevator control")
      system.messageBox(appName .. ": Could not register elevator control")
   end
   
   --system.registerLogVariable("RTHBrgFrom", "°", logfileCB)
   --system.registerLogVariable("RTHBrgTo",   "°", logfileCB)
   --system.registerLogVariable("RTHDst",     "m", logfileCB)
   --system.registerLogVariable("RTHHdg",     "°", logfileCB)
   --system.registerLogVariable("RTHStr",     "%", logfileCB)
			      
   local str = io.readall(prefix() .. pathApp.."Json/Config.jsn")
   if not str then
      print("DFM-Path: cannot read Config.jsn")
   end
   
   config = json.decode(str)

   DCDS24II = (string.find(select(1, system.getDeviceType()), "24 II"))

   --system.setProperty("NativeDraw", 1)
   --print("get", system.getProperty("NativeDraw"))

   --origGet = system.getSensorByID
   --system.getSensorByID = getSensorByID

   --if dumpGlobalVars then dumpGlobalVars() end

   BDLatA = 41.340133
   BDLngA = -74.430933
   BDLatB = 41.339622
   BDLngB = -74.430819
   BDA = gps.newPoint(BDLatA, BDLngA)
   BDB = gps.newPoint(BDLatB, BDLngB)
   print(gps.getDistance(BDA, BDB), gps.getBearing(BDA, BDB))

end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.2", name=appName}
