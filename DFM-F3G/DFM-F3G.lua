--[[
   ----------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local F3GVersion = "0.01"

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

local thrCtl

local flightState
local fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
local fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}

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
local perpAnn = {40,30,20}
local perpIdx

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


-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimG.jsn")
  local obj = json.decode(file)cd 
  if(obj) then
    trans11 = obj[lng] or obj[obj.default]
  end
--]]
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

--------------------------------------------------------------------------------

-- Read available sensors for user to select - done once at startup

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
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
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
      zeroLatString, zeroLngString = gps.getStrig(zeroPos)
      print("saving zeroLat/LngString")
      system.pSave("zeroLatString", zeroLatString)
      system.pSave("zeroLngString", zeroLngString)
   elseif key == KEY_2 then
      rotA = math.rad(curBear-90)
      system.pSave("rotA", rotA*1000)
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

local function thrCtlChanged(val)
   thrCtl = val
   system.pSave("thrCtl", thrCtl)
end

local function initForm(sf)
   local str
   subForm = sf
   if sf == 1 then
      form.setTitle("Level 1 menu")

      form.addRow(2)
      form.addLabel({label="Course display >>"})
      form.addLink((function()
	       form.reinit(2)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Throttle Control"})
      form.addInputbox(thrCtl, true, thrCtlChanged)

      form.addRow(2)
      form.addLabel({label="Latitude Sensor"})
      form.addSelectbox(sensorLalist, latSe, true, latSensorChanged)

      form.addRow(2)
      form.addLabel({label="Longitude Sensor"})
      form.addSelectbox(sensorLalist, lngSe, true, lngSensorChanged)

      form.addRow(2)
      form.addLabel({label="Motor Voltage Sensor"})
      form.addSelectbox(sensorLalist, voltSe, true, voltSensorChanged)

      form.addRow(2)
      form.addLabel({label="Motor Current Sensor"})
      form.addSelectbox(sensorLalist, ampSe, true, ampSensorChanged)

      form.addRow(2)
      form.addLabel({label="Altitude Sensor"})
      form.addSelectbox(sensorLalist, altSe, true, altSensorChanged)                  
      
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

--------------------------------------------------------------------------------
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
   local now
   local volt, amp
   local sensor
   
   curPos = gps.getPosition(latSeId, latSePa, lngSePa)
   
   if not curPos then return end
   
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
   --print("curDist, curBear", curDist, curBear)
   
   if curX ~= lastX or curY ~= lastY then -- new point
      heading = math.atan(curX-lastX, curY - lastY)
      lastX = curX
      lastY = curY
   end
   
   detA = det(0,-50,0,50,curX,curY)
   detB = det(150,-50, 150, 50,curX,curY)
   detC = det(-75,0,225,0,curX,curY)
   
   if detA > 0 then dA = 1 else dA = 0 end
   if detB > 0 then dB = 1 else dB = 0 end
   if detC > 0 then dC = 1 else dC = 0 end
   
   dd = dA + 2*dB
   
   perpA = pDist(0,-50,0,50,curX, curY)
   perpB = pDist(150,-50,150, 50, curX, curY)
   
   if detA < 0 then perpA = -perpA end
   if detB > 0 then perpB = -perpB end
   
   if dd then
      flightZone = zone[dd]
      if not lastFlightZone then lastFlightZone = flightZone end
   end
      
   sensor = system.getSensorByID(altSeId, altSePa)
   if sensor and sensor.valid then
      altitude = sensor.value
   end
   
   now = system.getTimeCounter()

   if flightState == fs.Idle then
      swt = system.getInputsVal(thrCtl)
      if swt and swt == 1 then
	 motorStart = now
	 motorWattSec = 0
	 flightState = fs.MotorOn
	 lastPowerTime = now
	 flightStart = now
      end
   else
      flightTime = now - flightStart
   end

   if flightState == fs.MotorOn then
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
	 motorWattSec = motorWattSec + volt * amp * (now-lastPowerTime) / 1000
	 lastPowerTime = now
      end
      motorTime = now - motorStart

      if motorTime > 30*1000 then
	 print("Motor > 30s")
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_time.wav", AUDIO_QUEUE)
      elseif motorWattSec / 60 > 350 then
	 print("Watt-Min > 350")
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_wattmin.wav", AUDIO_QUEUE)
      end

   end

   if flightState == fs.MotorOff then
      if now > motorOffTime + 10*1000 then
	 system.playFile("/Apps/DFM-F3G/start_altitude.wav", AUDIO_QUEUE)
	 system.playNumber(altitude, 0)
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
      end
   end

   if flightState == fs.AtoB then
      if perpIdx >= #perpAnn and perpB <= 0 then
	 print("Beep")
	 system.playBeep(0,440,500)
      end
      if perpIdx <= #perpAnn and perpB <= perpAnn[perpIdx]  then
	 print("perpIdx", perpIdx)
	 perpIdx = perpIdx + 1
	 system.playNumber(perpB, 0)
      end
      
      if flightZone == 3 and lastFlightZone == 2 then
	 flightState = fs.BtoA
	 perpIdx = 1
      end
   end

   if flightState == fs.BtoA then
      if perpIdx >= #perpAnn and perpA <= 0 then
	 print("Beep")
	 system.playBeep(0,440,500)
      end
      if perpIdx <= #perpAnn and perpA <= perpAnn[perpIdx] then
	 perpIdx = perpIdx + 1
	 system.playNumber(perpA, 0)
      end
      
      if flightZone == 1 and lastFlightZone == 2 then
	 taskLaps = taskLaps + 1
	 system.playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
	 system.playNumber(taskLaps,0)
	 flightState = fs.AtoB
	 perpIdx = 1
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

local xmin, xmax, ymin, ymax = -75, 225, -75, 75

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end


local function drawPylons()

   lcd.drawLine(xp(-50), yp(0), xp(200), yp(0))
   lcd.drawLine(xp(0), yp(-50), xp(0), yp(50))
   lcd.drawLine(xp(150), yp(-50), xp(150), yp(50))
   
end

local function printTele()

   local LEFT = 0
   local RIGHT = 3
   local MIDDLE = 1
   local text
   
   if subForm ~= 2 then return end

   form.setTitle("")
   form.setButton(1, "Pt A", ENABLED)
   form.setButton(2, "Dir B", ENABLED)

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
   text = string.format("E: %.2f", motorWattSec/60)
   lcd.drawText(245,15,text)
   
   if flightState == fs.AtoB or flightState == fs.BtoA then
      text = string.format("Laps: %d", (taskLaps or 0) )
      lcd.drawText(140,0,text)
   end
   

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
      lcd.drawText( xp(150) - lcd.getTextWidth(FONT_NORMAL, text)/2, yp(-60), text)

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

   thrCtl = system.pLoad("thrCtl")
   
   rotA = system.pLoad("rotA", 0)
   rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   print("rotA", rotA, math.deg(rotA))
   
   if zeroLatString and zeroLngString then
      print("zeroPos", zeroLatString, zeroLngString)
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end
   
   thrCtl =  system.pLoad("thrCtl")
   
   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm, printTele)
   --system.registerTelemetry(1, "F3G Display", 4, printTele)

   local cc = system.registerControl(1, "Motor Enable", "MOT")

   if not cc then
      print("Could not register control")
   else
      system.setControl(1, 1, 0)
   end
   
   readSensors()
   
   setLanguage()
   
   flightState = fs.Idle

   motorStart = 0
   motorTime = 0
   motorPower = 0
   motorWattSec = 0
   flightTime = 0
   
   appStartTime = system.getTimeCounter()
   appRunTime = 0
   
   print("gps", gps.getPosition(0,0,0))
	 
   print("DFM-F3G: gcc " .. collectgarbage("count"))
   
end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G"}
