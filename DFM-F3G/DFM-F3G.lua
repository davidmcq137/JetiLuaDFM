--[[

   ----------------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition

   It can also be used for F3B

   ----------------------------------------------------------------------------
   
--]]

local F3GVersion = "0.53"

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

local flightState
local fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
local fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}
local distAB
local lvP
local lvD
local lvT, beepOn
local lvX, lvY
local preBeep

local luaCtl = {MOT=1, BPP=2, TSK=3}
local luaTxt = {MOT="Motor", BPP="Beep", TSK="Task"}

local motorTime
local motorStart
local motorPower
local motorWattSec
local motorOffTime
local motorStatus
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

local detA, detB
local dA, dB, dd
local perpA, perpB

local savedRow

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

local function resetFlight()
   local swt, thr
   flightState = fs.Idle
   motorStart = 0
   motorTime = 0
   motorPower = 0
   motorWattSec = 0
   flightTime = 0
   taskStartTime = nil
   taskLaps = nil
   preBeep = false
   swt = system.getSwitchInfo(ctl.thr)
   if swt then print(swt.label, swt.value, swt.proportional, swt.assigned, swt.mode) else print("swt nil") end
   if swt then thr = system.getInputs(swt.label) end
   print("thr, gIV", thr, system.getInputsVal(ctl.thr))
   
   if swt and swt.value and swt.value <= -0.99 then
      system.setControl(luaCtl.MOT,  1, 0)
      motorStatus = true
   else
      system.setControl(luaCtl.MOT, -1, 0)
      motorStatus = false
   end
   system.setControl(luaCtl.BPP, -1, 0)
   system.setControl(luaCtl.TSK, -1, 0)
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
   if subForm == 1 then
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
   local tt = system.getSwitchInfo(val)
   if tt.assigned == true then
      ctbl[v] = val
   else
      ctbl[v] = nil
   end
   system.pSave(v.."Ctl", ctbl[v])
end

--[[
local function changedDist(val)
   distAB = val
   system.pSave("distAB", distAB)
   print("DFM-F3G: gcc " .. collectgarbage("count"))
end
--]]

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

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)   

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
      --[[
      form.addRow(2)
      form.addLabel({label="Course Length", width=220})      
      form.addIntbox(distAB, 20, 200, 150, 0, 1, changedDist)
      --]]
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)   
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

   if beepOffTime and now > beepOffTime then
      system.setControl(luaCtl.BPP,-1,0)
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

   -- play the beep and count the lap as soon as we know we're there
   
   if (flightZone == 3 and lastFlightZone == 2) or (flightZone == 1 and lastFlightZone == 2) then
      system.playBeep(0,440,500)
      print("Beep")
      system.setControl(luaCtl.BPP,1,0)
      beepOn = 1
      beepOffTime = now + 1000
      -- one transit AtoB or BtoA is a "lap"
      if taskLaps and flightState == fs.AtoB or flightState == fs.BtoA then
	 taskLaps = taskLaps + 1
	 --system.playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
	 --system.playNumber(taskLaps,0)
      end
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
	 print("swa and swt ok, motorstatus:", motorstatus)
	 if motorStatus then
	    motorStart = now
	    motorWattSec = 0
	    flightState = fs.MotorOn
	    lastPowerTime = now
	    flightStart = now
	    system.playFile("/Apps/DFM-F3G/motor_run_started.wav", AUDIO_QUEUE)
	 else
	    -- this will keep getting called, leaving the message up till throttle is off
	    system.messageBox("Throttle to 0, then Reset Flight", 1)
	 end
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

      if swt and swt < 1 then
	 flightState = fs.MotorOff
	 system.setControl(luaCtl.MOT, -1, 0)
	 motorStatus = false
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_manual.wav", AUDIO_QUEUE)
      end
      if motorTime > 30*1000 then
	 flightState = fs.MotorOff
	 system.setControl(luaCtl.MOT, -1, 0)
	 motorStatus = false
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_time.wav", AUDIO_QUEUE)
      elseif motorWattSec / 60 > 350 then
	 flightState = fs.MotorOff
	 system.setControl(luaCtl.MOT, -1, 0)
	 motorStatus = false
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
	 taskStartTime = now
	 taskLaps = 0
	 system.playFile("/Apps/DFM-F3G/task_started.wav", AUDIO_QUEUE)
	 system.setControl(luaCtl.TSK, 1, 0)
      end
   end

   if flightState == fs.AtoB then
      if flightZone == 3 and lastFlightZone == 2 then
	 flightState = fs.BtoA
	 preBeep = false
      end
      if perpB <= 20 and not preBeep and flightZone == 2 then
	 system.playBeep(1,880,300)
	 preBeep = true
	 print("BeepBeepA", perpB, perpA)
      end
   elseif flightState == fs.BtoA then
      if flightZone == 1 and lastFlightZone == 2 then
	 if elePullTime then
	    --system.playFile("/Apps/DFM-F3G/pull_latency.wav", AUDIO_QUEUE)
	    --system.playNumber( (now - elePullTime)/1000, 1)
	    elePullLog = now - elePullTime
	    elePullTime = nil
	 end
	 flightState = fs.AtoB
	 preBeep = false
      end
      if perpA <= 20 and not preBeep and flightZone == 2 then
	 system.playBeep(1,880,300)
	 preBeep = true
	 print("BeepBeepB", perpA, perpB)
      end
      if swe and swe == 1 and perpA < 20 and (not elePullTime) then
	 --print("elePullTime now")
	 elePullTime = now
      end
   end

   if flightState ~= fs.Done and taskStartTime and (( now - taskStartTime) > 240*1000) then
      flightState = fs.Done
      flightDone = flightTime
      taskDone = now - taskStartTime
      system.playFile("/Apps/DFM-F3G/task_complete.wav", AUDIO_QUEUE)
      system.setControl(luaCtl.TSK, -1, 0)
   end
   
   lastFlightZone = flightZone
end

local function printTele()

   local text, text2
   
   if subForm ~= 1 then return end
   text = string.format("Rotate: %d", math.deg(rotA))
   lcd.drawText(230,120, text)
   if curPos then
      text, text2 = gps.getStrig(curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end

local function raceTele()

   local text
   lcd.setColor(lcd.getFgColor())

   lcd.drawText(0,0,"State: " .. fsTxt[flightState], FONT_BIG)

   if flightState == fs.Idle or flightState == fs.MotorOn then
      text = string.format("%.2f s", motorTime/1000)
      lcd.drawText(0,20,text)
      if curX and curY then
	 text = string.format("X: %.1f", curX)
	 lcd.drawText(90, 20, text)
	 text = string.format("Y: %.1f", curY)
	 lcd.drawText(90, 35, text)
      end
      
      text = string.format("%.2f W", motorPower)
      lcd.drawText(0,35,text)
      text = string.format("%.2f W-m", motorWattSec/60)
      lcd.drawText(0,50,text)
   else
      if taskStartTime then
	 if flightState ~= fs.Done then
	    text = string.format("T: %.2f s", (system.getTimeCounter() - taskStartTime)/1000)
	 else
	    text = string.format("T: %.2f s", taskDone/1000) .. string.format(" F: %.2f s", flightDone/1000)
	 end
      else
	 text = string.format("T: %.2f s", flightTime/1000)	 
      end
      lcd.drawText(0,20,text)

      if taskLaps then
	 text = string.format("%d Laps", taskLaps)
      else
	 text = string.format("Alt: %.1f m", altitude or 0)	 
      end
      lcd.drawText(0,35,text)
      
      text = string.format("%.2f m from A", perpA)
      lcd.drawText(0,50,text)
   end
   
end

local function logWriteCB(idx)
   if idx == lvP then
      if elePullLog then
	 return elePullLog, 0
      else
	 return 0,0
      end
   elseif idx == lvD then
      if perpA then
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
   
   rotA = system.pLoad("rotA", 0)
   rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm, printTele)
   system.registerTelemetry(1, "F3G Status", 2, raceTele)

   for cn, cv in pairs(luaCtl) do
      luaCtl[cn] = system.registerControl(cv, luaTxt[cn], cn)
   end
   
   lvP = system.registerLogVariable("elePullTime", "ms", logWriteCB)
   lvX = system.registerLogVariable("courseX", "m", logWriteCB)
   lvY = system.registerLogVariable("courseY", "m", logWriteCB)   
   lvD = system.registerLogVariable("perpDistA", "m", logWriteCB)
   lvT = system.registerLogVariable("beep", "s", logWriteCB)

   readSensors(telem)

   resetFlight()
   
   print("DFM-F3G: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G"}
