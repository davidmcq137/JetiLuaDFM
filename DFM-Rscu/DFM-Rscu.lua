--[[

   -----------------------------------------------------------------------------------------
   DFM-Rscu "rescue/return to home" .. Conceived by Harry Curzon, coded by DFM. Initially copied 
   from DFM-HUD.lua as starting point

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-Rscu.lua released under MIT license by DFM 2026
   -----------------------------------------------------------------------------------------

--]]

local appName = "DFM-Rscu"
local pathApp = "Apps/"..appName.."/"
local RTH = {}
local config = {}
local MIN_DISTANCE
local MIN_ALTITUDE
local circling
local armed = false
local everEnabled = false
local lastSec
local announceTime
local lastSwO = -1
local annSeq = 1

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

local renShape = lcd.renderer()
local ren = lcd.renderer()

local homeShape = {
 { 0, -15},
 {-12, 12},
 { 0, 6},
 { 12, 12}
}
local emflag


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
   local now
   local sensor
   local MINHDGDIST = 2
   local MINGPSREADS= 9
   local info
   local SwO
   local altnow

   now = system.getTimeCounter()
   if not lastSec then lastSec = now end
   if not announceTime then announceTime = now end
   
   if emflag ~= 0 and system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
   end

   sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
   if sensor and sensor.valid then
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
      end
      --print(emflag, altnow, RTH.var.startTakeoffAlt)
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

   local gs = RTH.settings
   local compHdg
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      if RTH.curPos then
	 if not RTH.lastPos then RTH.lastPos = RTH.curPos end
	 if gps.getDistance(RTH.curPos, RTH.lastPos) > MINHDGDIST then 
	    compHdg = gps.getBearing(RTH.lastPos, RTH.curPos)
	    RTH.lastPos = RTH.curPos
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
      if RTH.curPos and lt ~= 0 and lg ~= 0 and not RTH.zeroPos then
	 RTH.gpsReads = RTH.gpsReads + 1
      end
      if RTH.gpsReads > MINGPSREADS and not RTH.zeroPos then
	 system.messageBox("DFM-Rscu: GPS and Alt zero set")
	 print("DFM-Rscu: GPS and Alt zero set")
	 RTH.zeroPos = RTH.curPos
	 if altnow then
	    if emflag ~= 0 then
	       RTH.var.startTakeoffAlt = 0
	    else
	       RTH.var.startTakeoffAlt = altnow
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

   --[[
   -- when switch is turned on, arm rescue mode .. but don't enable yet
   if not armed and lastSwO == -1 and SwO == 1 then
      system.playFile(prefix() .. pathApp .. "Audio/rtharmed.wav", AUDIO_QUEUE)
      armed = true
      --circling = false
      --announceTime = now
   end

   lastSwO = SwO

   -- if armed and we pass beyond circleMax, then enable
   if not everEnabled and armed and ((RTH.gpsDistance or 0) > RTH.settings.circleMax) then
      circling = false
      announceTime = now
      system.playFile(prefix() .. pathApp .. "Audio/rthenabled.wav", AUDIO_QUEUE)
      everEnabled = true
   end
   
   if everEnabled then
      RTH.settings.onoff = SwO
   else
      RTH.settings.onoff = -1
   end
   --]]
   
   if lastSwO == -1 and SwO == 1 then
      system.stopPlayback()
      system.playFile(prefix() .. pathApp .. "Audio/rthenabled.wav", AUDIO_IMMEDIATE)
      system.playBeep(0, 600, 200)
      circling = false
      annSeq = 1
      announceTime = now
   end

   lastSwO = SwO

   RTH.settings.onoff = SwO

   -- if enabled, compute and set steering and elev controls
   -- and make announcements

   RTH.settings.steer = 0
   RTH.settings.elev = 0
   local validmix = false
   if RTH.settings.onoff > 0 then
      if RTH.gpsHeading and RTH.gpsBearingFrom then
	 RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180
      end
      if RTH.settings.steerCtrl and RTH.settings.steer then
	 local ns = RTH.settings.steer / 180 -- normalized to [-1..1]
	 if RTH.gpsDistance then
	    if RTH.gpsDistance >= RTH.settings.circleMax then
	       if circling then
		  system.stopPlayback()
		  system.playFile(prefix() .. pathApp .. "Audio/circterm.wav", AUDIO_IMMEDIATE)
		  system.playBeep(2, 600, 200)
		  announceTime = 0 -- force immed ann of bearing
		  annSeq = 1
	       end
	       circling = false
	    end
	 end
	 if RTH.gpsDistance then
	    if (RTH.gpsDistance < RTH.settings.circleMin) or circling == true then
	       if circling == false then -- start circling now
		  system.stopPlayback()
		  system.playFile(prefix() .. pathApp .. "Audio/begincircling.wav", AUDIO_IMMEDIATE)
		  system.playBeep(1, 600, 200)
		  announceTime = now + config.annDelay * config.annMax
	       end
	       circling = true
	       system.setControl(RTH.settings.steerCtrl, -1, 1000, 1)
	       system.setControl(RTH.settings.elevCtrl, -1, 1000, 1)
	    else
	       system.setControl(RTH.settings.steerCtrl, mixOut(config.Amix,ns), 1000, 1)
	       system.setControl(RTH.settings.elevCtrl, mixOut(config.Emix,ns), 1000, 1)
	    end
	 end
	 validmix = true

	 if now > announceTime then
	    if not circling then
	       if annSeq == 1 then
		  if RTH.gpsBearingTo then
		     system.playFile(prefix() .. pathApp .. "Audio/bearing.wav", AUDIO_QUEUE)
		     system.playNumber(RTH.gpsBearingTo, 0)
		     system.playFile(prefix() .. pathApp .. "Audio/degrees.wav", AUDIO_QUEUE)
		  end
	       elseif annSeq == 2 then
		  if RTH.gpsDistance then
		     if RTH.settings.distUnits == 1 then --m
			system.playFile(prefix() .. pathApp .. "Audio/distance.wav", AUDIO_QUEUE)
			system.playNumber(RTH.gpsDistance, 1)
			system.playFile(prefix() .. pathApp .. "Audio/meters.wav", AUDIO_QUEUE)
		     else
			system.playFile(prefix() .. pathApp .. "Audio/distance.wav", AUDIO_QUEUE)
			system.playNumber(RTH.gpsDistance * 3.2808, 0)
			system.playFile(prefix() .. pathApp .. "Audio/feet.wav", AUDIO_QUEUE)
		     end
		  end
	       elseif annSeq == 3 then
		  if RTH.altitude then
		     if RTH.settings.distUnits == 1 then --m
			system.playFile(prefix() .. pathApp .. "Audio/altitude.wav", AUDIO_QUEUE)
			system.playNumber(RTH.altitude, 1)
			system.playFile(prefix() .. pathApp .. "Audio/meters.wav", AUDIO_QUEUE)
		     else
			system.playFile(prefix() .. pathApp .. "Audio/altitude.wav", AUDIO_QUEUE)
			system.playNumber(RTH.altitude * 3.2808, 0)
			system.playFile(prefix() .. pathApp .. "Audio/feet.wav", AUDIO_QUEUE)
		     end
		  end
	       end
	       announceTime = now + config.annDelay
	       annSeq = annSeq + 1
	       if annSeq > config.annMax then  -- allow empty slots to space anns
		  annSeq = 1
		  system.stopPlayback() -- empty queue in case backed up messages
	       end
	    else
	       system.playFile(prefix() .. pathApp.."Audio/tooclose.wav", AUDIO_QUEUE)
	       announceTime = now + config.annDelay * config.annMax
	    end
	 end
      end
   end
   --if for any reason mix was not done, set mix control to 0
   if not validmix then
      system.setControl(RTH.settings.steerCtrl, 0, 0)
      system.setControl(RTH.settings.elevCtrl, 0, 0)
   end
end

local function initForm()

   local latsel = 0
   local lngsel = 0
   local altsel = 0
   local hdgsel = 0
   local rollsel = 0
   local pitchsel = 0

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
   form.addLabel({label="RTH on/off switch", width=280})
   form.addInputbox(RTH.settings.onoffSw, true, onoffChanged, {alignRight=true})
   
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

   --[[
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
   form.addLabel({label="Start Circling Distance (m)", font=FONT_NORMAL})
   form.addIntbox(RTH.settings.circleMin, 0, 10000, 100, 0, 1,
		  (function(x)
			RTH.settings.circleMin = x
			system.pSave("circleMin", x)
			return end),
		  {width=155, font=FONT_NORMAL, algignRight=false})
   
   form.addRow(2)
   form.addLabel({label="Resume Steering Distance (m)", font=FONT_NORMAL})
   form.addIntbox(RTH.settings.circleMax, 0, 10000, 100, 0, 1,
		  (function(x)
			RTH.settings.circleMax = x
			system.pSave("circleMax", x)
			return end),
		  {width=155, font=FONT_NORMAL, algignRight=false})
end

local function drawShape(col, row, shape, rotation)
 sinShape = math.sin(rotation)
 cosShape = math.cos(rotation)
 renShape:reset()
 for _, point in pairs(shape) do
 renShape:addPoint(
 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
 )
 end
 renShape:renderPolygon()
end

local function printForm(w,h)
end

local function destroy()
end


local function printTeleMix(w,h)

   local x0,y0 = 15, 5
   local xl, yl = 1.23*80, 80
   local min, max = -100, 100
   
   local function xp(val)
      return x0 + xl * (val - min) / (max - min)
   end

   local function yp(val)
      return 90  - (y0 + yl * (val - min) / (max - min))
   end

   local function drawX(xp, yp, d)
      lcd.drawLine(xp - d, yp + d, xp + d, yp - d)
      lcd.drawLine(xp - d, yp - d, xp + d, yp + d)
   end
   
   if not RTH.settings.steerCtrl or not RTH.settings.steer then
      lcd.drawText(5, 2, "No steering value", FONT_NORMAL)
      return
   end

   local ns = RTH.settings.steer / 180.0
   local am = mixOut(config.Amix, ns)
   local em = mixOut(config.Emix, ns)

   for i=2,#config.Amix.points,1 do
      lcd.drawLine(xp(config.Amix.points[i-1].x), yp(config.Amix.points[i-1].y),
		   xp(config.Amix.points[i].x), yp(config.Amix.points[i].y))
      lcd.drawLine(xp(config.Emix.points[i-1].x), yp(config.Emix.points[i-1].y),
		   xp(config.Emix.points[i].x), yp(config.Emix.points[i].y))

      lcd.setColor(0,0,255)
      lcd.drawCircle(xp(ns * 100), yp(am * 100), 4)
      lcd.setColor(255,0,0)
      drawX(xp(ns * 100), yp(em * 100), 4)      
      lcd.setColor(0,0,0)
   end
   
end

local function printTeleBig(w,h)
   
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

local function printTeleAH()
   
   local HP = require 'DFM-Rscu/hp1345a'
   local function drawPitch(ren, roll, pitch, pitchR, radAH, X0, Y0, scl)

      local XH,YH,X1,X2,X3,Y1,Y2,Y3,X4,Y4
      local pp, pps
      local XHS = 18 * radAH / 70
      local  XHL = 40 * radAH / 70
      local  scale = scl * radAH / 70
      
      local sinRoll = math.sin(math.rad(-roll))
      local cosRoll = math.cos(math.rad(-roll))
      local delta = pitch % 15    
      --local ren = lcd.renderer()
      
      --for (let i = delta - 45; i < 45 + delta; i = i + 15) {

      local i = delta - 45
      repeat
	 --if (math.abs(pitch - i % 360) < 0.01) then
	 if math.abs(pitch - i) < 0.01 then
	    XH = XHL;
	 else
	    XH = XHS;
	 end
	 YH = pitchR * i                      
	 pp = pitch - i
	 pps = string.format("%d", math.floor(pp*10 + 0.5) / 10)
	 
	 X1 = -XH * cosRoll - YH * sinRoll;
	 Y1 = -XH * sinRoll + YH * cosRoll;
	 X2 = (XH - 0) * cosRoll - YH * sinRoll;
	 Y2 = (XH - 0) * sinRoll + YH * cosRoll;
	 X3 = (XH + 5) * cosRoll - (YH - 3) * sinRoll;
	 Y3 = (XH + 5) * sinRoll + (YH - 3) * cosRoll;	
	 X4 = (-XH - 18 * scale * #pps - 5) * cosRoll - (YH - 3) * sinRoll;
	 Y4 = (-XH - 18 * scale * #pps - 5) * sinRoll + (YH - 3) * cosRoll;	
	 
	 if( not ( (X1 < -radAH and X2 < -radAH) or  (X1 > radAH and X2 > radAH)
		or (Y1 < -radAH and Y2 < -radAH) or  (Y1 > radAH and Y2 > radAH) ) ) then
	    lcd.setColor(255,255,255)
	    ren:reset()
	    ren:addPoint(X0 + radAH + X1, Y0 + radAH + Y1)
	    ren:addPoint(X0 + radAH + X2, Y0 + radAH + Y2)
	    if (XH == XHL) then
	       ren:renderPolyline(2)
	    else
	       ren:renderPolyline(1)
	    end
	    
	    if (XH == XHS) then
	       HP.drawHP1345A(ren, X0 + radAH + X3, Y0 + radAH + Y3, pps, scale,
			      math.rad(roll), 1);
	       HP.drawHP1345A(ren, X0 + radAH + X4, Y0 + radAH + Y4, pps, scale,
			      math.rad(roll), 1);
	    end
	 end
	 i = i + 15
      until i >= 45 + delta
   end

   --[[
      function artHorizon is based on code in the Jeti Artificial Horizon App
      
      Copyright (c) 2016 JETI
      Copyright (c) 2015 dandys.
      Copyright (c) 2014 Marco Ricci.
      
      Use here conforms with the license terms
   --]]
   
   local pitch = pitchVal or 0 -- system.getInputs("P2") * 90 -- pitchVal or 0 
   local roll = rollVal or 0 --system.getInputs("P3") * 180 -- rollVal or 0
   --183
   local rowAH = 130 / 2 - 20; --widget.width / 2 - 20;
   local radAH = 130 / 2 - 20; --widget.width / 2 - 20;
   local pitchR = radAH / 25;

   local tanRoll
   local cosRoll
   
   local dPitch_1
   local dPitch_2

   local X0, Y0, X1, Y1, Y2, YH
   --local ren = lcd.renderer()

   if pitch >= 0 then -- heaven knows why we have to do this
      dPitch_1 = pitch % 180
   else
      dPitch_1 = -1*(-pitch % 180)
   end
   
   --print(pitch, dPitch_1)
   if (dPitch_1 > 90) then
      dPitch_1 = 180 - dPitch_1
   end
   if (roll == 270) then
      roll = 269.99;
   end
   if (roll == 90) then
      roll = 89.99;
   end
   
   cosRoll = 1 / math.cos(math.rad(roll))
   
   if (pitch > 270) then
      dPitch_1 = -dPitch_1 * pitchR * cosRoll
      dPitch_2 = radAH * cosRoll
   elseif (pitch > 180) then
      dPitch_1 = dPitch_1 * pitchR * cosRoll
      dPitch_2 = -radAH * cosRoll
   elseif (pitch > 90) then
      dPitch_1 = -dPitch_1 * pitchR * cosRoll
      dPitch_2 = -radAH * cosRoll
   else
      dPitch_1 = dPitch_1 * pitchR * cosRoll
      dPitch_2 = radAH * cosRoll
   end

   --print(dPitch_1, dPitch_2)
   
   tanRoll = -math.tan(math.rad(roll))
   
   X1 = 0
   YH = (-radAH) * tanRoll
   Y1 = YH + dPitch_1
   Y2 = YH + 1.5 * dPitch_2 
   
   -- define clipping region 
   --X0 160 Y0 79
   X0 = 80 - radAH --widget.x0 - radAH
   Y0 = 50 - radAH --widget.y0 - radAH
   lcd.setClipping(X0, Y0, 2 * radAH, 2 * radAH)
   X0 = 0
   Y0 = 0
   -- draw sky over entire box
   lcd.setColor(0,0,255)
   --lcd.setColor(widget.rgbSkyColor.r, widget.rgbSkyColor.g, widget.rgbSkyColor.b)
   lcd.drawFilledRectangle(X0, Y0, 2 * radAH + 1, 2 * radAH + 1);

   lcd.setColor(210,105,30)
   --lcd.setColor(widget.rgbLandColor.r, widget.rgbLandColor.g, widget.rgbLandColor.b)
   ren:reset()

   if (Y1 < Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
   elseif (Y1 > Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
   end

   X1 = 2 * radAH + 1
   YH = (radAH) * tanRoll
   Y1 = YH + dPitch_1
   Y2 = YH + 1.5 * dPitch_2
   
   if (Y1 < Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
   elseif (Y1 > Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
   end
   ren:renderPolygon(1)
   
   lcd.setColor(255,255,255)
   lcd.drawLine(X0, Y0, X0, Y0 + 2 * radAH + 1);
   lcd.drawLine(X0 + 2 * radAH - 1, Y0, X0 + 2 * radAH - 1, Y0 + 2 * radAH - 1)
   lcd.drawLine(X0, Y0 + 2 * radAH - 1, X0 + 2 * radAH - 1, Y0 + 2 * radAH - 1)
   lcd.drawLine(X0, Y0, X0 + 2 * radAH, Y0)

   lcd.drawLine(X0 + radAH - 0.7 * radAH, Y0 + radAH, X0 + radAH - 0.2 * radAH, Y0 + radAH);
   lcd.drawLine(X0 + radAH - 0.2 * radAH, Y0 + radAH,
		X0 + radAH - 0.2 * radAH, Y0 + radAH + radAH / 10);
   lcd.drawLine(X0 + radAH + 0.7 * radAH, Y0 + radAH, X0 + radAH + 0.2 * radAH, Y0 + radAH);
   lcd.drawLine(X0 + radAH + 0.2 * radAH, Y0 + radAH,
		X0 + radAH + 0.2 * radAH, Y0 + radAH + radAH / 10);
   drawPitch(ren, roll, pitch, pitchR, radAH, X0, Y0, 0.4);
   
   lcd.resetClipping()

end

local xmin, xmax = -600, 600
local ymin, ymax = -300, 300

local function xytopixel(x, y, ww, hh)

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
   --local tl = gps.newPoint(41.340733, -74.432382)
   --local x, y = gps.getLcdXY(RTH.curPos, tl, 14)


   local x, y, x1, y1, ix, iy, ix1, iy1

   lcd.drawRectangle(0,0,319,159)
   lcd.setColor(255,0,0)
   for i = 0, 360, 5 do
      x = RTH.settings.circleMin * math.sin(math.rad(i))
      y = RTH.settings.circleMin * math.cos(math.rad(i))

      x1 = RTH.settings.circleMin * math.sin(math.rad(i+5))
      y1 = RTH.settings.circleMin * math.cos(math.rad(i+5))      
      --print(w,h,ix,iy)
      ix, iy = xytopixel(x, y, w, h)
      ix1, iy1 = xytopixel(x1, y1, w, h)      
      
      lcd.drawLine(ix,iy, ix1, iy1)
   end
   lcd.setColor(0,0,255)
   for i = 0, 360, 5 do
      x = RTH.settings.circleMax * math.sin(math.rad(i))
      y = RTH.settings.circleMax * math.cos(math.rad(i))

      x1 = RTH.settings.circleMax * math.sin(math.rad(i+5))
      y1 = RTH.settings.circleMax * math.cos(math.rad(i+5))      
      --print(w,h,ix,iy)
      ix, iy = xytopixel(x, y, w, h)
      ix1, iy1 = xytopixel(x1, y1, w, h)      
      
      lcd.drawLine(ix,iy, ix1, iy1)
   end

   lcd.setColor(0,0,0)
   
   x = RTH.gpsDistance * math.sin(math.rad(RTH.gpsBearingTo))
   y = RTH.gpsDistance * math.cos(math.rad(RTH.gpsBearingTo))
   ix, iy = xytopixel(x, y, w, h)
   if RTH.settings.onoff < 1 then
      lcd.setColor(0,0,0)
      else
	 if circling then lcd.setColor(255,0,0) else lcd.setColor(0,0,255) end
      end
   lcd.drawCircle(ix, iy, 5)
   lcd.setColor(0,0,0)
   local ix0 , iy0 = xytopixel(0, 0, w, h)
   lcd.drawCircle(ix0, iy0, 2)
   lcd.drawText(20, 20, string.format("[%d,%d,%d,%d]", xmin, xmax, ymin, ymax), FONT_MINI)
   lcd.drawText(20, 40, string.format("gpsDistance: %.2f", RTH.gpsDistance), FONT_MINI)
   lcd.drawText(20, 60, string.format("gpsBearingTo: %.2f ", RTH.gpsBearingTo), FONT_MINI)
   lcd.drawText(20, 80, string.format("gpsBearingFrom: %.2f ", RTH.gpsBearingFrom), FONT_MINI)

   if RTH.gpsHeading then
      local ixh, iyh = ix + 20 * math.sin(math.rad(RTH.gpsHeading)),
	 iy - 20 * math.cos(math.rad(RTH.gpsHeading))
      lcd.drawLine(ix, iy, ixh, iyh)
      lcd.drawText(20, 100, string.format("gpsHeading: %.2f ", RTH.gpsHeading or 0), FONT_MINI)   

   end

   if RTH.gpsHeading and RTH.gpsBearingFrom then
      local steer = RTH.settings.steer --(-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180
      lcd.drawText(20, 120, string.format("Steer: %.2f ", steer), FONT_MINI)
      local ixs, iys = ix + 20 * math.sin(math.rad(steer)), iy - 20 * math.cos(math.rad(steer)) 
      --lcd.drawLine(ix, iy, ixs, iys)
      --[[
      local normSteer = steer / 180.0
      lcd.drawRectangle(60,120,200,30)
      --normSteer = system.getInputs("P4")
      lcd.drawFilledRectangle(159, 120, 2, 30) 
      if normSteer >= 0 then
	 lcd.drawFilledRectangle(160,120, 100*normSteer, 30)
      else
	 local ns = math.floor(100*(1+normSteer))
	 lcd.drawFilledRectangle(60 + ns,120, math.floor(100-ns+0.5), 30)	 
      end
      --]]
   end
end

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
      print("##", RTH.settings.steer, RTH.settings.steer / 1.80)
      return (RTH.settings.steer or 0) / 1.80
   else
      return -999
   end
end

local function init()

   readSensors(RTH)
   
   system.registerForm(1, MENU_APPS, "DFM-Rscu", initForm, nil, printForm)
   
   local device
   device, emflag = system.getDeviceType() 
   print("Device", device, "emflag", emflag)

   local ts = 4
   if device == "JETI DS-24 II" or device == "JETI DC-24 II" then
      ts = 2
   end
   
   system.registerTelemetry(1, "RScu Map North Up", 4, printTeleGPS)
   system.registerTelemetry(2, "Rscu Status", ts, printTeleBig)

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
   RTH.settings.distUnits = system.pLoad("RTHdistUnits", 1) -- meters is default
   
   RTH.settings.circleMin = system.pLoad("circleMin", 100)
   print("circleMin", RTH.settings.circleMin)
   RTH.settings.circleMax = system.pLoad("circleMax", 130)

   circling = false
   
   RTH.gpsReads = 0
   RTH.curPos = nil
   RTH.zeroPos = nil

   RTH.settings.steerCtrl = nil
   for i=1,10,1 do
      RTH.settings.steerCtrl = system.registerControl(i, "RTH Steering", "RTS")
      if RTH.settings.steerCtrl then break end
   end

   RTH.settings.steer = 0
   RTH.settings.onoff = -1
   
   if RTH.settings.steerCtrl then
      print(appName ..": Steering registered to control "..RTH.settings.steerCtrl)
      system.setControl(RTH.settings.steerCtrl, RTH.settings.steer, 0)
   else
      print(appName .. ": Could not register steer control")
      system.messageBox(appName .. ": Could not register steer control")
   end

   RTH.settings.elevCtrl = nil
   for i=1,10,1 do
      if i ~= RTH.settings.steerCtrl then
	 RTH.settings.elevCtrl = system.registerControl(i, "RTH Elevator", "RTE")
	 if RTH.settings.elevCtrl then break end
      end
   end

   RTH.settings.elev = 0

   if RTH.settings.elevCtrl then
      print(appName ..": Elevator registered to control "..RTH.settings.elevCtrl)
      system.setControl(RTH.settings.elevCtrl, RTH.settings.elev, 0)
   else
      print(appName .. ": Could not register elevator control")
      system.messageBox(appName .. ": Could not register elevator control")
   end
   
   system.registerLogVariable("RTHBrgFrom", "°", logfileCB)
   system.registerLogVariable("RTHBrgTo",   "°", logfileCB)
   system.registerLogVariable("RTHDst",     "m", logfileCB)
   system.registerLogVariable("RTHHdg",     "°", logfileCB)
   system.registerLogVariable("RTHStr",     "%", logfileCB)
			      
   local str = io.readall(prefix() .. pathApp.."Json/Config.jsn")
   if not str then
      print("DFM-Rscu: cannot read Config.jsn")
   end
   
   config = json.decode(str)

   --print("config", json.encode(config))

   --MIN_DISTANCE = config.minDist
   --MIN_ALTITUDE = config.minAlt

   --print(MIN_DISTANCE, MIN_ALTITUDE, config.annMax, config.annDelay)

end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.03", name=appName}
