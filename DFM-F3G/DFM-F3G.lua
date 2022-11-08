--[[

   ----------------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition

   ----------------------------------------------------------------------------
   
--]]

local trans11
local F3GVersion = "0.11"

local subForm = 0
local emFlag
local loopCPU

local sensorLalist = { "..." }  -- sensor labels (long)
local sensorLslist = { "..." }  -- sensor labels (short)
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor units

local latSe, latSeId, latSePa
local lngSe, lngSeId, lngSePa
local voltSe, voltSeId, voltSePa
local ampSe, ampSeId, ampSePa
local altSe, altSeId, altSePa
local pulsSe, pulsSeId, pulsSePa

local thrCtl
local armCtl
local eleCtl
local elePullTime
local rstCtl
local swrLast
local swaLast
local preAnnEnabled
local preAnnIdx

local flightState
local fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
local fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}
local distAB

local appStartTime, appRunTime

local motorTime
local motorStart
local motorPower
local motorWattSec
local motorOffTime
local lastPowerTime
local flightTime
local flightStart
local flightDone
local flightZone
local taskStartTime
local taskDone
local taskLaps
local lastFlightZone
local zone = {[0]=1,[1]=2,[3]=3}
local beepOffTime
local beepOnTime
local pulseDelay
local rndOnTime

local curDist
local curBear
local curPos
local zeroPos
local zeroLatString
local zeroLngString
local initPos
local curX, curY
local lastX, lastY
local heading
local rotA
local altitude
local pulse
local perpAnn = {40,30,20}
local perpIdx

local motorAnn = {15,20,25}
local motorIdx

local detA, detB, detC
local dA, dB, dC, dd
local perpA, perpB

local savedRow
local savedRow2
local savedRow3

local Glider = { 
   {0,-7},
   {-1,-2},
   {-14,0},
   {-14,2},	
   {-1,2},	
   {-1,8},
   {-4,8},
   {-4,10},
   {0,10},
   {4,10},
   {4,8},
   {1,8},
   {1,2},
   {14,2},
   {14,0},
   {1,-2}
}

local function setLanguage()
   local lng, file, obj
   lng=system.getLocale()
   file = io.readall("Apps/Lang/DFM-F3G.jsn")
   if file then
      obj = json.decode(file)
   end
   if(obj) then
      trans11 = obj[lng] or obj[obj.default]
   end
end

local function drawShape(col, row, shape, rotation)
   local sinShape, cosShape
   local ren=lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

local function readSensors()
   local sensorLbl = "***"
   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    local ii = #sensorLalist+1
	    table.insert(sensorLslist, sensor.label) -- .. "[" .. ii .. "]")
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label) -- .. "["..ii.."]")
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	 end
      end
   end
end

local function drawShape(col, row, shape, rotation)
   local sinShape, cosShape
   local ren = lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(col + (point[1] * cosShape - point[2] * sinShape + 0.5),
		   row + (point[1] * sinShape + point[2] * cosShape + 0.5)) 
   end
   ren:renderPolygon()
end

local function resetFlight()
   flightState = fs.Idle
   motorStart = 0
   motorTime = 0
   motorPower = 0
   motorWattSec = 0
   flightTime = 0
   taskStartTime = nil
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   local row = form.getFocusedRow()
   if keyExit(key) then
   end
   if key == KEY_1 then
      zeroPos = curPos
      if zeroPos then
	 zeroLatString, zeroLngString = gps.getStrig(zeroPos)
	 system.pSave("zeroLatString", zeroLatString)
	 system.pSave("zeroLngString", zeroLngString)
      else
	 system.messageBox("No Current Position")
      end
      
   elseif key == KEY_2 then
      if curBear then
	 rotA = math.rad(curBear-90)
	 system.pSave("rotA", rotA*1000)
      else
	 system.messageBox("No Current Position")
      end
   elseif key == KEY_3 then
      resetFlight()
   end
end

local function latSensorChanged(val)
   latSe = val
   latSeId = sensorIdlist[latSe]
   latSePa = sensorPalist[latSe]
   system.pSave("latSe", latSe)
   system.pSave("latSeId", latSeId)
   system.pSave("latSePa", latSePa)
end

local function lngSensorChanged(val)
   lngSe = val
   lngSeId = sensorIdlist[lngSe]
   lngSePa = sensorPalist[lngSe]
   system.pSave("lngSe", lngSe)
   system.pSave("lngSeId", lngSeId)
   system.pSave("lngSePa", lngSePa)
end

local function ampSensorChanged(val)
   ampSe = val
   ampSeId = sensorIdlist[ampSe]
   ampSePa = sensorPalist[ampSe]
   system.pSave("ampSe", ampSe)
   system.pSave("ampSeId", ampSeId)
   system.pSave("ampSePa", ampSePa)
end

local function voltSensorChanged(val)
   voltSe = val
   voltSeId = sensorIdlist[voltSe]
   voltSePa = sensorPalist[voltSe]
   system.pSave("voltSe", voltSe)
   system.pSave("voltSeId", voltSeId)
   system.pSave("voltSePa", voltSePa)
end

local function altSensorChanged(val)
   altSe = val
   altSeId = sensorIdlist[altSe]
   altSePa = sensorPalist[altSe]
   system.pSave("altSe", altSe)
   system.pSave("altSeId", altSeId)
   system.pSave("altSePa", altSePa)
end

local function pulsSensorChanged(val)
   pulsSe = val
   pulsSeId = sensorIdlist[pulsSe]
   pulsSePa = sensorPalist[pulsSe]
   system.pSave("pulsSe", pulsSe)
   system.pSave("pulsSeId", pulsSeId)
   system.pSave("pulsSePa", pulsSePa)
end

local function thrCtlChanged(val)
   thrCtl = val
   system.pSave("thrCtl", thrCtl)
end

local function armCtlChanged(val)
   armCtl = val
   system.pSave("armCtl", armCtl)
end

local function eleCtlChanged(val)
   eleCtl = val
   system.pSave("eleCtl", eleCtl)
end

local function rstCtlChanged(val)
   rstCtl = val
   system.pSave("rstCtl", rstCtl)
end

local function preAnnChanged(val)
   preAnnEnabled = not val
   system.pSave("preAnnEnabled", tostring(preAnnEnabled))
   form.setValue(preAnnIdx, preAnnEnabled)
end

local function changedDist(val)
   distAB = val
   system.pSave("distAB", distAB)
end

local function initForm(sf)
   local str
   subForm = sf
   if sf == 1 then
      form.setTitle("F3G Practice")

      form.addRow(2)
      form.addLabel({label="Distance Task Display >>", width=220})
      form.addLink((function()
	       form.reinit(2)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Throttle Control", width=220})
      form.addInputbox(thrCtl, true, thrCtlChanged)

      form.addRow(2)
      form.addLabel({label="Arming switch", width=220})
      form.addInputbox(armCtl, true, armCtlChanged)

      form.addRow(2)
      form.addLabel({label="Elevator Control", width=220})
      form.addInputbox(eleCtl, true, eleCtlChanged)

      form.addRow(2)
      form.addLabel({label="Reset Flight Switch", width=220})
      form.addInputbox(rstCtl, true, rstCtlChanged)

      form.addRow(2)
      form.addLabel({label="Enable A/B approach announce", width=270})
      preAnnIdx = form.addCheckbox(preAnnEnabled, preAnnChanged, {alignRight=true})
      
      form.addRow(2)
      form.addLabel({label="Latitude Sensor", width=220})
      form.addSelectbox(sensorLalist, latSe, true, latSensorChanged)

      form.addRow(2)
      form.addLabel({label="Longitude Sensor", width=220})
      form.addSelectbox(sensorLalist, lngSe, true, lngSensorChanged)

      form.addRow(2)
      form.addLabel({label="Motor Voltage Sensor", width=220})
      form.addSelectbox(sensorLalist, voltSe, true, voltSensorChanged)

      form.addRow(2)
      form.addLabel({label="Motor Current Sensor", width=220})
      form.addSelectbox(sensorLalist, ampSe, true, ampSensorChanged)

      form.addRow(2)
      form.addLabel({label="Altitude Sensor", width=220})
      form.addSelectbox(sensorLalist, altSe, true, altSensorChanged)                  
      
      form.addRow(2)
      form.addLabel({label="Pulse Sensor", width=220})
      form.addSelectbox(sensorLalist, pulsSe, true, pulsSensorChanged)                  

      form.addRow(2)
      form.addLabel({label="Course Length", width=220})      
      form.addIntbox(distAB, 20, 200, 150, 0, 1, changedDist)
      
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 13 then
      form.setButton(3, ":edit", 1)
      form.setTitle(string.format("Level 2 menu %d", savedRow))

      if savedRow2 then form.setFocusedRow(savedRow2) end
      savedRow2 = 1
   elseif sf == 103 then
      form.setTitle(string.format("Level 3 menu %d", savedRow2))

      if savedRow3 then
	 form.setFocusedRow(savedRow3)
	 savedRow3 = nil
      else
	 form.setFocusedRow(1)
      end
   end
end

local function det(x1, y1, x2, y2, x, y)
   return (x-x1)*(y2-y1) - (y-y1)*(x2-x1)
end

local function pDist(x1, y1, x2, y2, x, y)
   return math.abs( (x2-x1)*(y1-y) - (x1-x)*(y2-y1) ) / math.sqrt( (x2-x1)^2 + (y2-y1)^2)
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function loop()
   
   local sensor
   local lat, lng
   local minutes, degs
   local swt
   local swa
   local swe
   local swr
   local now
   local volt, amp
   local sensor
   
   now = system.getTimeCounter()

   if now > rndOnTime then
      system.setControl(3,1,0)
   end
   
   if beepOffTime and now > beepOffTime then
      system.setControl(2,-1,0)
   end
   
   curPos = gps.getPosition(latSeId, latSePa, lngSePa)

   if curPos then
      if not initPos then
	 initPos = curPos
	 if not zeroPos then zeroPos = curPos end
      end
      
      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))
      
      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, rotA)

      local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)
      
      if curX ~= lastX or curY ~= lastY and dist > 5 then -- new point
	 heading = math.atan(curX-lastX, curY - lastY)
	 lastX = curX
	 lastY = curY
      end
      
      detA = det(0,-50,0,50,curX,curY)
      detB = det(distAB,-50, distAB, 50,curX,curY)
      detC = det(-75,0,225,0,curX,curY)
      
      if detA > 0 then dA = 1 else dA = 0 end
      if detB > 0 then dB = 1 else dB = 0 end
      if detC > 0 then dC = 1 else dC = 0 end
      
      dd = dA + 2*dB
      
      perpA = pDist(0,-50,0,50,curX, curY)
      perpB = pDist(distAB,-50,distAB, 50, curX, curY)
      
      if detA < 0 then perpA = -perpA end
      if detB > 0 then perpB = -perpB end
      
      if dd then
	 flightZone = zone[dd]
	 if not lastFlightZone then lastFlightZone = flightZone end
      end
   end

   -- play the beep as soon as we know we're there
   
   if (flightZone == 3 and lastFlightZone == 2) or (flightZone == 1 and lastFlightZone == 2) then
      system.playBeep(0,440,500)
      system.setControl(2,1,0)
      beepOffTime = now + 500
      beepOnTime = now
      print("Beep")
   end
   
   sensor = system.getSensorByID(pulsSeId, pulsSePa)
   if sensor and sensor.valid then
      pulse = sensor.value
   end

   if pulse and pulse > 1.0 and rndOnTime and now > rndOnTime then
      pulseDelay = now - rndOnTime
      system.setControl(3,-1,0)
      rndOnTime = now + 2000
   end
   
   sensor = system.getSensorByID(altSeId, altSePa)
   if sensor and sensor.valid then
      altitude = sensor.value
   end

   sensor = system.getSensorByID(ampSeId, ampSePa)
   if sensor and sensor.valid then
      amp = sensor.value
   end

   sensor = system.getSensorByID(voltSeId, voltSePa)
   if sensor and sensor.valid then
      volt = sensor.value
   end
   if volt and amp then
      motorPower = volt * amp
   end
   

   swt = system.getInputsVal(thrCtl)
   swa = system.getInputsVal(armCtl)
   swe = system.getInputsVal(eleCtl)   
   swr = system.getInputsVal(rstCtl)

   if not swrLast then swrLast = swr end
   if swr and swr == 1 and swrLast == -1 then
      resetFlight()
   end
   swrLast = swr
   
   if flightState == fs.Idle then
      if swa == 1 and swaLast == -1 then
	 system.playFile("/Apps/DFM-F3G/start_armed.wav", AUDIO_QUEUE)
      end
      swaLast = swa
   
      if (not swa or swa == 1) and (swt and swt == 1) then
	 motorStart = now
	 motorWattSec = 0
	 flightState = fs.MotorOn
	 lastPowerTime = now
	 flightStart = now
	 motorIdx = 1
	 system.playFile("/Apps/DFM-F3G/motor_run_started.wav", AUDIO_QUEUE)
      end
   else
      flightTime = now - flightStart
   end

   if flightState == fs.MotorOn then
      if volt and amp then
	 motorWattSec = motorWattSec + volt * amp * (now-lastPowerTime) / 1000
	 lastPowerTime = now
      end
      motorTime = now - motorStart

      if motorIdx <= #motorAnn and motorTime/1000 > motorAnn[motorIdx] then
	 system.playNumber(motorAnn[motorIdx], 0)
	 motorIdx = motorIdx + 1
      end

      if swt and swt < 1 then
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_manual.wav", AUDIO_QUEUE)
      end
      if motorTime > 30*1000 then
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_time.wav", AUDIO_QUEUE)
      elseif motorWattSec / 60 > 350 then
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_wattmin.wav", AUDIO_QUEUE)
      end

   end

   if flightState == fs.MotorOff then
      if now > motorOffTime + 10*1000 then
	 system.playFile("/Apps/DFM-F3G/start_altitude.wav", AUDIO_QUEUE)
	 if altitude then
	    system.playNumber(altitude, 0)
	 else
	    system.playFile("/Apps/DFM-F3G/unavailable.wav", AUDIO_QUEUE)
	 end
	 flightState = fs.Altitude
      end
   end
      
   if flightState == fs.Altitude then
      if flightTime / 1000 > 40 then
	 system.playFile("/Apps/DFM-F3G/40_seconds.wav", AUDIO_QUEUE)
	 flightState = fs.Ready
      end
   end

   if flightState == fs.Ready then
      if flightZone == 2 and lastFlightZone == 1 then
	 flightState = fs.AtoB
	 perpIdx = 1
	 taskStartTime = now
	 taskLaps = 0
	 system.playFile("/Apps/DFM-F3G/task_started.wav", AUDIO_QUEUE)
      end
   end

   if flightState == fs.AtoB then
      if flightZone == 3 and lastFlightZone == 2 then
	 flightState = fs.BtoA
	 perpIdx = 1
      end
      if perpIdx <= #perpAnn and perpB <= perpAnn[perpIdx]  then
	 perpIdx = perpIdx + 1
	 if preAnnEnabled then
	    system.playNumber(perpB, 1)
	 end
      end
   end

   if flightState == fs.BtoA then
      if flightZone == 1 and lastFlightZone == 2 then
	 taskLaps = taskLaps + 1
	 if elePullTime then
	    system.playFile("/Apps/DFM-F3G/pull_latency.wav", AUDIO_QUEUE)
	    system.playNumber( (now - elePullTime)/1000, 1)
	    elePullTime = nil
	 end
	 system.playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
	 system.playNumber(taskLaps,0)
	 flightState = fs.AtoB
	 perpIdx = 1
      end
      if perpIdx <= #perpAnn and perpA <= perpAnn[perpIdx] then
	 if perpIdx == 1 then elePullTime = nil end
	 perpIdx = perpIdx + 1
	 if preAnnEnabled then
	    system.playNumber(perpA, 1)
	 end
      end
      if swe and swe == 1 and perpA < 20 and (not elePullTime) then
	 elePullTime = now
      end
   end

   if flightState ~= fs.Done and taskStartTime and (( now - taskStartTime) > 240*1000) then
      flightState = fs.Done
      flightDone = flightTime
      taskDone = now - taskStartTime
      system.playFile("/Apps/DFM-F3G/task_complete.wav", AUDIO_QUEUE)
   end
   
   lastFlightZone = flightZone
   loopCPU = system.getCPU()
end

--local xmin, xmax, ymin, ymax = -75, 225, -75, 75
local xmin, xmax, ymin, ymax = -110, 290, -100, 100

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function drawPylons()
   lcd.drawLine(xp(-50), yp(0), xp(200), yp(0))
   lcd.drawLine(xp(0), yp(-50), xp(0), yp(50))
   lcd.drawLine(xp(distAB), yp(-50), xp(distAB), yp(50))
end

local function printTele()

   local text, text2
   
   if subForm ~= 2 then return end

   form.setTitle("")
   form.setButton(1, "Pt A",  ENABLED)
   form.setButton(2, "Dir B", ENABLED)
   form.setButton(3, "Reset", ENABLED)   

   lcd.drawText(0,0,"["..fsTxt[flightState].."]")

   if flightState ~= fs.Done then
      text = string.format("F: %.2fs", flightTime/1000)
      lcd.drawText(0,15,text)
   else
      text = string.format("F: %.2fs", flightDone/1000)
      lcd.drawText(0,15,text)
   end
   

   if flightState == fs.AtoB or flightState == fs.BtoA then
      text = string.format("T: %.2fs", (system.getTimeCounter() - taskStartTime)/1000)
      lcd.drawText(0,30,text)
   end

   if flightState == fs.Done then
      text = string.format("T: %.2fs", taskDone/1000)
      lcd.drawText(0,30,text)
   end
   
   text = string.format("R: %.2f", motorTime/1000)
   lcd.drawText(245,0,text)
   text = string.format("P: %.2f", motorPower)
   lcd.drawText(245,15,text)
   text = string.format("E: %.2f", motorWattSec/60)
   lcd.drawText(245,30,text)
   
   if flightState == fs.AtoB or flightState == fs.BtoA or flightState == fs.Done then
      text = string.format("Laps: %d", (taskLaps or 0) )
      lcd.drawText(130,0,text)
   end

   if pulse then
      text = string.format("Pulse: %.2f", pulse or 0)
      lcd.drawText(220,150, text, FONT_MINI)
      
      text = string.format("Pulse delay: %d", pulseDelay or 0)
      lcd.drawText(220,160, text, FONT_MINI)
   end
   
   text = string.format("Theta: %d", math.deg(rotA))
   lcd.drawText(0,150, text, FONT_MINI)

   if curPos then
      text, text2 = gps.getStrig(curPos)
   else
      text, text2 = "---", "---"
   end

   lcd.drawText(0,160,"[" .. text .. "," .. text2 .. "]", FONT_MINI)
   

   if curX and curY then

      lcd.setColor(0,255,0)
      
      --lcd.drawText(140,140, string.format("%d %d %d", flightZone, dA, dB))
      
      if  detB > 0 then
	 lcd.setColor(255,0,0)
      elseif detA > 0 then
	 lcd.setColor(0,0,255)
      end
      
      drawShape(xp(curX), yp(curY), Glider, (heading or 0) )

      lcd.setColor(0,0,0)


      local text = string.format("%.2f", perpA)
      lcd.drawText( xp(0) - lcd.getTextWidth(FONT_NORMAL, text)/2 , yp(-60), text)
      text = string.format("%.2f", perpB)
      lcd.drawText( xp(distAB) - lcd.getTextWidth(FONT_NORMAL, text)/2, yp(-60), text)

   end

   lcd.setColor(0,0,0)
   
   drawPylons()

end

local function init()
   
   local pf
   
   emFlag = select(2, system.getDeviceType()) == 1
   if emFlag then pf = "" else pf = "/" end

   zeroLatString = system.pLoad("zeroLatString")
   zeroLngString = system.pLoad("zeroLngString")

   latSe = system.pLoad("latSe", 0)
   latSeId = system.pLoad("latSeId",0)
   latSePa = system.pLoad("latSePa",0)
   
   lngSe = system.pLoad("lngSe", 0)
   lngSeId = system.pLoad("lngSeId",0)
   lngSePa = system.pLoad("lngSePa",0)

   voltSe = system.pLoad("voltSe", 0)
   voltSeId = system.pLoad("voltSeId",0)
   voltSePa = system.pLoad("voltSePa",0)

   ampSe = system.pLoad("ampSe", 0)
   ampSeId = system.pLoad("ampSeId",0)
   ampSePa = system.pLoad("ampSePa",0)

   altSe = system.pLoad("altSe", 0)
   altSeId = system.pLoad("altSeId",0)
   altSePa = system.pLoad("altSePa",0)

   pulsSe = system.pLoad("pulsSe", 0)
   pulsSeId = system.pLoad("pulsSeId",0)
   pulsSePa = system.pLoad("pulsSePa",0)
   
   thrCtl = system.pLoad("thrCtl")
   armCtl = system.pLoad("armCtl")   
   eleCtl = system.pLoad("eleCtl")
   rstCtl = system.pLoad("rstCtl")   

   distAB = system.pLoad("distAB", 150)
   
   preAnnEnabled = system.pLoad("preAnnEnabled", true) == "true"
   
   rotA = system.pLoad("rotA", 0)
   rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   print("rotA", rotA, math.deg(rotA))
   
   if zeroLatString and zeroLngString then
      print("zeroPos", zeroLatString, zeroLngString)
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end
   
   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm, printTele)

   local cc = system.registerControl(1, "Motor Enable", "MOT")

   if not cc then
      system.messageBox("Could not register MOT control")
   else
      system.setControl(1, 1, 0)
   end
   
   cc = system.registerControl(2, "Beep Pulse", "BPP")
   print("cc", cc)
   
   if not cc then
      system.messageBox("Could not register BPP control")
   else
      system.setControl(2, -1, 0)
      beepOnTime = system.getTimeCounter() + 2000
   end

   cc = system.registerControl(3, "RoundTrip", "RND")
   print("cc", cc)
   
   if not cc then
      system.messageBox("Could not register RND control")
   else
      system.setControl(3, -1, 0)
      rndOnTime = system.getTimeCounter() + 2000
   end

   readSensors()
   setLanguage()
   resetFlight()
   appStartTime = system.getTimeCounter()
   appRunTime = 0
   
   print("DFM-F3G: gcc " .. collectgarbage("count"))
   
end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G Practice"}
