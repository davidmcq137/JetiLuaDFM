--[[

   ----------------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition

   It can also be used for F3B

   ----------------------------------------------------------------------------
   
--]]

local F3GVersion = "0.3"

local subForm = 0
--local emFlag

local telem = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

local sens = {
   {var="lat",  label="Latitude"},
   {var="lng",  label="Longitude"},
   {var="volt", label="Motor Voltage"},
   {var="amp",  label="Motor Current"},
   {var="alt",  label="Altitude"},
   {var="puls", label="Pulse"}
}

local ctl = {
   {var="thr", label="Throttle"},
   {var="arm", label="Arming"},
   {var="ele", label="Elevator"},
   {var="rst", label="Reset Flight"}
}

local elePullTime
local elePullLog
local swrLast
local swaLast
local preAnnEnabled
local preAnnIdx
local preBeep
local preBeepDone
local preBeepStr = {"...", "P5", "P6", "P7", "P8", "P9", "P10"}
local preBeepVal

local flightState
local fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
local fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}
local distAB
local lvP
local lvD
local lvT, beepOn
local lvX, lvY

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
--local heading
local rotA
local altitude
local pulse
local perpAnn = {40,30,20}
local perpIdx

local motorAnn = {15,20,25}
local motorIdx

local detA, detB
local dA, dB, dd
local perpA, perpB

local savedRow

--[[
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
--]]

local function readSensors(tbl)
   --local sensorLbl = "***"
   
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    --sensorLbl = sensor.label
	    table.insert(tbl.Lalist, ">> "..sensor.label)
	    table.insert(tbl.Idlist, 0)
	    table.insert(tbl.Palist, 0)
	 else
	    table.insert(tbl.Lalist, sensor.label)
	    --table.insert(tbl.Lalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	 end
      end
   end
end

--[[
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
--]]

local function resetFlight()
   flightState = fs.Idle
   motorStart = 0
   motorTime = 0
   motorPower = 0
   motorWattSec = 0
   flightTime = 0
   taskStartTime = nil
   system.setControl(1, 1, 0)
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   if subForm ~= 1 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   end
   if subForm == 2 then
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
end

local function ctlChanged(val, ctbl, v)
   ctbl[v] = val
   system.pSave(v.."Ctl", ctbl[v])
end

local function preAnnChanged(val)
   preAnnEnabled = not val
   system.pSave("preAnnEnabled", tostring(preAnnEnabled))
   form.setValue(preAnnIdx, preAnnEnabled)
end

local function changedDist(val)
   distAB = val
   system.pSave("distAB", distAB)
   print("DFM-F3G: gcc " .. collectgarbage("count"))
end

local function preBeepChanged(val)
   preBeep = val
   system.pSave("preBeep", preBeep)
end

local function telemChanged(val, stbl, v, ttbl)
   stbl[v].Se = val
   stbl[v].SeId = ttbl.Idlist[val]
   stbl[v].SePa = ttbl.Palist[val]
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", stbl[v].SeId)
   system.pSave(v.."SePa", stbl[v].SePa)
end

local function initForm(sf)
   subForm = sf
   if sf == 1 then
      form.setTitle("F3G Practice")

      form.addRow(2)
      form.addLabel({label="Telemetry >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(3)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Controls >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Course/GPS Setup >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(2)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Enable A/B approach announce", width=270})
      preAnnIdx = form.addCheckbox(preAnnEnabled, preAnnChanged, {alignRight=true})

      form.addRow(2)
      form.addLabel({label="Course Length", width=220})      
      form.addIntbox(distAB, 20, 200, 150, 0, 1, changedDist)
      
      form.addRow(2)
      form.addLabel({label="Pre-beep control", width=220})
      form.addSelectbox(preBeepStr, preBeep, true, preBeepChanged)

      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 3 then
      form.setTitle("Telemetry Sensors")
      for i in ipairs(sens) do
	 form.addRow(2)
	 form.addLabel({label=sens[i].label,width=140})
	 form.addSelectbox(telem.Lalist, sens[sens[i].var].Se, true,
			   (function(x) return telemChanged(x, sens, sens[i].var, telem) end),
			   {width=180, alignRight=false})
      end
   elseif sf == 4 then
      form.setTitle("Controls")
      for i in ipairs(ctl) do
	 form.addRow(2)
	 form.addLabel({label=ctl[i].label, width=220})
	 form.addInputbox(ctl[ctl[i].var], true, (function(x) return ctlChanged(x, ctl, ctl[i].var) end) )
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
   local swt
   local swa
   local swe
   local swr
   local now
   local volt, amp
   
   now = system.getTimeCounter()

   
   if rndOnTime and now > rndOnTime then
      system.setControl(3,1,0)
   end
   
   if beepOffTime and now > beepOffTime then
      system.setControl(2,-1,0)
      beepOn = -1
   end

   curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)   

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
	 --heading = math.atan(curX-lastX, curY - lastY)
	 lastX = curX
	 lastY = curY
      end
      
      detA = det(0,-50,0,50,curX,curY)
      detB = det(distAB,-50, distAB, 50,curX,curY)
      --detC = det(-75,0,225,0,curX,curY)
      
      if detA > 0 then dA = 1 else dA = 0 end
      if detB > 0 then dB = 1 else dB = 0 end
      --if detC > 0 then dC = 1 else dC = 0 end
      
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

   if preBeep > 1 then
      preBeepVal = 20 * (system.getInputs(preBeepStr[preBeep]) + 1)/2 -- 0 to 20
   end
   
   -- play the beep and count the lap as soon as we know we're there
   
   if (flightZone == 3 and lastFlightZone == 2) or (flightZone == 1 and lastFlightZone == 2) then
      system.playBeep(0,440,500)
      system.setControl(2,1,0)
      beepOn = 1
      beepOffTime = now + 1000
      -- one transit AtoB or BtoA is a "lap"
      taskLaps = taskLaps + 1
      system.playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
      system.playNumber(taskLaps,0)
      print("Beep")
   end
   
   sensor = system.getSensorByID(sens.puls.SeId, sens.puls.SePa)
   if sensor and sensor.valid then
      pulse = sensor.value
   end

   if pulse and pulse > 1500 and rndOnTime and now > rndOnTime then
      pulseDelay = now - rndOnTime
      system.setControl(3,-1,0)
      rndOnTime = now + 2000
   end
   
   sensor = system.getSensorByID(sens.alt.SeId, sens.alt.SePa)
   if sensor and sensor.valid then
      altitude = sensor.value
   end

   sensor = system.getSensorByID(sens.amp.SeId, sens.amp.SePa)
   if sensor and sensor.valid then
      amp = sensor.value
   end

   sensor = system.getSensorByID(sens.volt.SeId, sens.volt.SePa)
   if sensor and sensor.valid then
      volt = sensor.value
   end
   if volt and amp then
      motorPower = volt * amp
   end

   swt = system.getInputsVal(ctl.thr)
   swa = system.getInputsVal(ctl.arm)
   swe = system.getInputsVal(ctl.ele)   
   swr = system.getInputsVal(ctl.rst)

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
	 preBeepDone = false
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
      if preBeepVal and perpB < preBeepVal and not preBeepDone then
	 print("preBeep")
	 system.playBeep(1,880,200)
	 preBeepDone = true
      end
   end

   if flightState == fs.BtoA then
      if flightZone == 1 and lastFlightZone == 2 then
	 if elePullTime then
	    system.playFile("/Apps/DFM-F3G/pull_latency.wav", AUDIO_QUEUE)
	    system.playNumber( (now - elePullTime)/1000, 1)
	    elePullLog = now - elePullTime
	    elePullTime = nil
	 end
	 flightState = fs.AtoB
	 preBeepDone = false
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
	 print("elePullTime now")
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
end

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

   if preBeepVal then
      text = string.format("PreBeep: %.1fm", preBeepVal or 0)
      lcd.drawText(220,165, text, FONT_MINI)      
   end
   
   if pulse then
      text = string.format("Pulse: %.2f", pulse or 0)
      lcd.drawText(220,145, text, FONT_MINI)
      text = string.format("Pulse delay: %d", pulseDelay or 0)
      lcd.drawText(220,155, text, FONT_MINI)
   end
   
   text = string.format("Theta: %d", math.deg(rotA))
   lcd.drawText(0,155, text, FONT_MINI)

   if curPos then
      text, text2 = gps.getStrig(curPos)
   else
      text, text2 = "---", "---"
   end

   lcd.drawText(0,165,"[" .. text .. "," .. text2 .. "]", FONT_MINI)

   if curX and curY then
      lcd.setColor(0,255,0)
      if  detB > 0 then
	 lcd.setColor(255,0,0)
      elseif detA > 0 then
	 lcd.setColor(0,0,255)
      end
      --lcd.drawImage(xp(curX)-6, yp(curY)-6, ":rec")
      lcd.drawFilledRectangle(xp(curX)-3, yp(curY)-3, 6, 6)
      --drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      lcd.setColor(0,0,0)
      text = string.format("%.2f", perpA)
      lcd.drawText( xp(0) - lcd.getTextWidth(FONT_NORMAL, text)/2 , yp(-60), text)
      text = string.format("%.2f", perpB)
      lcd.drawText( xp(distAB) - lcd.getTextWidth(FONT_NORMAL, text)/2, yp(-60), text)
   end

   lcd.setColor(0,0,0)
   drawPylons()

end

local function elePullCB(idx)
   if idx == lvP then
      if elePullLog then
	 --print("lvP", ePullLog)
	 return elePullLog, 0
      else
	 return 0,0
      end
   elseif idx == lvD then
      if perpA then
	 --print("lvD", perpA*10)
	 return perpA*10, 1
      else
	 return 0,0
      end
   elseif idx == lvT then
      if beepOn then
	 return beepOn, 0
      else
	 return 0,0
      end
   elseif idx == lvX then
      if curX then
	 return curX*10, 1
      else
	 return 0,0
      end
   elseif idx == lvY then
      if curY then
	 return curY*10, 1
      else
	 return 0,0
      end      
   end
end

local function init()
   
   --local pf
   
   --emFlag = select(2, system.getDeviceType()) == 1
   --if emFlag then pf = "" else pf = "/" end

   zeroLatString = system.pLoad("zeroLatString")
   zeroLngString = system.pLoad("zeroLngString")

   for i in ipairs(sens) do
      local v = sens[i].var
      if not sens[v] then sens[v] = {} end
      sens[v].Se   = system.pLoad(v.."Se", 0)
      sens[v].SeId = system.pLoad(v.."SeId", 0)
      sens[v].SePa = system.pLoad(v.."SePa", 0)
   end
   
   for i in ipairs(ctl) do
      local v = ctl[i].var
      ctl[v] = system.pLoad(v.."Ctl")
   end

   distAB = system.pLoad("distAB", 150)
   preBeep = system.pLoad("preBeep", 1)
   preAnnEnabled = system.pLoad("preAnnEnabled", "true") == "true"
   
   rotA = system.pLoad("rotA", 0)
   rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm, printTele)

   local cc = system.registerControl(1, "Motor Enable", "MOT")

   if not cc then
      system.messageBox("Could not register MOT control")
   else
      system.setControl(1, 1, 0)
   end
   --[[
   cc = system.registerControl(2, "Beep Pulse", "BPP")
   
   if not cc then
      system.messageBox("Could not register BPP control")
   else
      system.setControl(2, -1, 0)
   end

   cc = system.registerControl(3, "RoundTrip", "RND")
   
   if not cc then
      system.messageBox("Could not register RND control")
   else
      system.setControl(3, -1, 0)
      rndOnTime = system.getTimeCounter() + 2000
   end
   --]]

   lvP = system.registerLogVariable("elePullTime", "ms", elePullCB)
   lvX = system.registerLogVariable("courseX", "m", elePullCB)
   lvY = system.registerLogVariable("courseY", "m", elePullCB)   
   lvD = system.registerLogVariable("perpDistA", "m", elePullCB)
   lvT = system.registerLogVariable("beep", "s", elePullCB)
   
   readSensors(telem)

   resetFlight()
   
   print("DFM-F3G: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G"}
