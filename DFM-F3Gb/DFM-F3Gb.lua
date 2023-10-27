--[[

   ----------------------------------------------------------------------------
   DFM-F3Gb.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition

   It can also be used for F3B

   This is the Basic (DFM-F3Gb) version with minimal function
   ----------------------------------------------------------------------------
   
--]]

local F3GVersion = "0.7"

local subForm = 0

local telem = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

local sens = {
   {var="lat",  label="Latitude"},
   {var="lng",  label="Longitude"}
}

local ctl = {
   {var="arm", label="Arming"}
}

--local elePullTime
--local elePullLog
--local swrLast
local swaLast

--local lvP
--local lvX
--local lvY
--local lvD
--local lvT

--local flightState
--local fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
--local fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}
local distAB
local gpsScale

--local motorTime
--local motorStart
--local motorPower
--local motorWattSec
--local motorOffTime
--local lastPowerTime
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
--local heading
local rotA
local altitude

local detA, detB
local dA, dB, dd
local perpA, perpB

local savedRow
local early = 0

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
   --flightState = fs.Idle
   --motorStart = 0
   --motorTime = 0
   --motorPower = 0
   --motorWattSec = 0
   --flightTime = 0
   taskStartTime = nil
   --system.setControl(1,1,0)
end

--[[
local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end
--]]

local function keyForm(key)
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
	 gpsScale = 1.0
	 system.pSave("gpsScale", gpsScale*1000)
	 system.messageBox("GPS scale factor reset to 1.0")
      else
	 system.messageBox("No Current Position")
      end
   elseif key == KEY_3 then
      resetFlight()
   elseif key == KEY_4 then
      if gpsScale ~= 1.0 then
	 system.messageBox("Do DirB first")
	 return
end
      if curX and curY then
	 gpsScale = 150.0/math.sqrt(curX^2 + curY^2)
	 print("curX, gpsScale", curX, curY, gpsScale)
	 system.pSave("gpsScale", gpsScale*1000)
      end
   end
end

--[[
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
	    gpsScale = 1.0
	    system.pSave("gpsScale", gpsScale*1000)
	    system.messageBox("GPS scale factor reset to 1.0")
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_3 then
	 resetFlight()
      elseif key == KEY_4 then
	 if gpsScale ~= 1.0 then
	    system.messageBox("Do DirB first")
	    return
	 end
	 if curX and curY then
	    gpsScale = 150.0/math.sqrt(curX^2 + curY^2)
	    print("curX, gpsScale", curX, curY, gpsScale)
	    system.pSave("gpsScale", gpsScale*1000)
	 end
      end
   end
   end

--]]

local function ctlChanged(val, ctbl, v)
   local ss = system.getSwitchInfo(val)
   if ss.assigned == false then
      ctbl[v] = nil
   else
      ctbl[v] = val
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
      form.setTitle("F3G Practice/Basic")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)   
      form.setButton(4, "C 150", ENABLED)

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
      form.addLabel({label="Course/GPS Setup >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(2)
	       form.waitForRelease()
      end))
      --]]
      
      --form.addRow(2)
      --form.addLabel({label="Course Length", width=220})      
      --form.addIntbox(distAB, 20, 200, 150, 0, 1, changedDist)
      
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
   local swy
   local now
   local volt, amp
   
   now = system.getTimeCounter()
   --early = 5 * ((system.getInputsVal(ctl.pre) or -1) + 1)

   --print("sens.lat.SeId", sens.lat.SeId, type(sens.lat.SeId))
   if type(sens.lat.SeId) ~= "number" or type(sens.lat.SePa) ~= "number" then
      --print("string in SeId, SePa")
   else
      --print("Id, Pa", sens.lat.SeId, sens.lat.SePa)
      curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)
   end
   

   if curPos then
      if not initPos then
	 initPos = curPos
	 if not zeroPos then zeroPos = curPos end
      end
      
      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))

      --print(math.sqrt(curX^2 + curY^2))
      
      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, rotA)

      if gpsScale then
	 curX = curX * gpsScale
      end
      
      --local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)
      
      if curX ~= lastX or curY ~= lastY then --and dist > 5 then -- new point
	 --heading = math.atan(curX-lastX, curY - lastY)
	 lastX = curX
	 lastY = curY
      end
      
      detA = det(0,-50,0,50,curX,curY)
      detB = det(distAB-early,-50, distAB-early, 50,curX,curY)
      --detC = det(-75,0,225,0,curX,curY)
      
      if detA > 0 then dA = 1 else dA = 0 end
      if detB > 0 then dB = 1 else dB = 0 end
      --if detC > 0 then dC = 1 else dC = 0 end
      
      dd = dA + 2*dB
      
      perpA = pDist(0,-50,0,50,curX, curY)
      perpB = pDist(distAB-early,-50,distAB-early, 50, curX, curY)
      
      if detA < 0 then perpA = -perpA end
      if detB > 0 then perpB = -perpB end
      
      if dd then
	 flightZone = zone[dd]
	 if not lastFlightZone then lastFlightZone = flightZone end
      end
   end

   --[[
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
   --]]
   
   swa = system.getInputsVal(ctl.arm)

   --[[
   swt = system.getInputsVal(ctl.thr)
   swe = system.getInputsVal(ctl.ele)   
   swr = system.getInputsVal(ctl.rst)
   --]]
   
   if (flightZone == 3 and lastFlightZone == 2) or (flightZone == 1 and lastFlightZone == 2) then
      if not swa or swa == 1 then
	 system.playBeep(0,440,500)
	 print("Beep")
      end
   end

   --[[
   if not swrLast then swrLast = swr end
   if swr and swr == 1 and swrLast == -1 then
      resetFlight()
   end
   swrLast = swr
   
   if flightState == fs.Idle then
      if swa == 1 and swaLast == -1 then
	 --system.playFile("/Apps/DFM-F3G/start_armed.wav", AUDIO_QUEUE)
      end
      swaLast = swa
   
      if (not swa or swa == 1) and (swt and swt == 1) then
	 motorStart = now
	 motorWattSec = 0
	 flightState = fs.Ready -- fs.MotorOn
	 lastPowerTime = now
	 flightStart = now
	 --system.playFile("/Apps/DFM-F3G/motor_run_started.wav", AUDIO_QUEUE)
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
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 --system.playFile("/Apps/DFM-F3G/motor_off_manual.wav", AUDIO_QUEUE)
      end
      if motorTime > 30*1000 then
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 --system.playFile("/Apps/DFM-F3G/motor_off_time.wav", AUDIO_QUEUE)
      elseif motorWattSec / 60 > 350 then
	 flightState = fs.MotorOff
	 system.setControl(1, -1, 0)
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_wattmin.wav", AUDIO_QUEUE)
      end
   end
   
   if flightState == fs.MotorOff then
      if now > motorOffTime + 10*1000 then
	 --system.playFile("/Apps/DFM-F3G/start_altitude.wav", AUDIO_QUEUE)
	 if altitude then
	    system.playNumber(altitude, 0)
	 else
	    --system.playFile("/Apps/DFM-F3G/unavailable.wav", AUDIO_QUEUE)
	 end
	 flightState = fs.Altitude
      end
   end
      
   if flightState == fs.Altitude then
      if flightTime / 1000 > 40 then
	 --system.playFile("/Apps/DFM-F3G/40_seconds.wav", AUDIO_QUEUE)
	 flightState = fs.Ready
      end
   end

   if flightState == fs.Ready then
      if flightZone == 2 and lastFlightZone == 1 then
	 flightState = fs.AtoB
	 taskStartTime = now
	 taskLaps = 0
	 system.playFile("/Apps/DFM-F3Gb/task_started.wav", AUDIO_QUEUE)
      end
   end

   if flightState == fs.AtoB then
      if flightZone == 3 and lastFlightZone == 2 then
	 flightState = fs.BtoA
      end
   end

   if flightState == fs.BtoA then
      if flightZone == 1 and lastFlightZone == 2 then
	 taskLaps = taskLaps + 1
	 if elePullTime then
	    system.playFile("/Apps/DFM-F3Gb/pull_latency.wav", AUDIO_QUEUE)
	    system.playNumber( (now - elePullTime)/1000, 1)
	    elePullLog = now - elePullTime
	    elePullTime = nil
	 end
	 --system.playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
	 --system.playNumber(taskLaps,0)
	 flightState = fs.AtoB
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
      --system.playFile("/Apps/DFM-F3G/task_complete.wav", AUDIO_QUEUE)
   end
   --]]
   
   lastFlightZone = flightZone
end

local xmin, xmax, ymin, ymax = -110, 290, -100, 100

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

--[[
local function drawPylons()
   lcd.drawLine(xp(-50), yp(0), xp(200), yp(0))
   lcd.drawLine(xp(0), yp(-50), xp(0), yp(50))
   lcd.drawLine(xp(distAB), yp(-50), xp(distAB), yp(50))
   if early > 0.1 then
      lcd.setColor(200,200,200)
      lcd.drawLine(xp(distAB-early), yp(-50), xp(distAB-early), yp(50))
      lcd.setColor(0,0,0)
   end
end
--]]

local function printTele()
   local pa
   local pb

   if perpA then
      pa = string.format("A %.2f", perpA)
   else
      pa = "---"
   end
   
   if perpB then
      pb = string.format("B %.2f", perpB)
   else
      pb = "---"
   end
   
   
   lcd.drawText(0,0,pa, FONT_MAXI)
   lcd.drawText(0,35, pb, FONT_MAXI)
end

--[[

local function printTele()
   local text, text2
   
   if subForm ~= 2 then return end

   form.setTitle("")
   form.setButton(1, "Pt A",  ENABLED)
   form.setButton(2, "Dir B", ENABLED)
   form.setButton(3, "Reset", ENABLED)   
   form.setButton(4, "C 150", ENABLED)

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
   text = string.format("B: %.2f", early)
   lcd.drawText(245,45,text)
   
   if flightState == fs.AtoB or flightState == fs.BtoA or flightState == fs.Done then
      text = string.format("Laps: %d", (taskLaps or 0) )
      lcd.drawText(130,0,text)
   end

   text = string.format("Theta: %d   GPS Scale: %.6f", math.deg(rotA), gpsScale)
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
--]]

--[[
local function elePullCB()
   if elePullLog then
      return elePullLog, 0
   else
      return 0,0
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
	 return curX*100, 2
      else
	 return 0,0
      end
   elseif idx == lvY then
      if curY then
	 return curY*100, 2
      else
	 return 0,0
      end      
   end
end
--]]

local function init()
   
   --local pf
   
   --emFlag = select(2, system.getDeviceType()) == 1
   --if emFlag then pf = "" else pf = "/" end

   for i in ipairs(sens) do
      local v = sens[i].var
      if not sens[v] then sens[v] = {} end
      sens[v].Se   = system.pLoad(v.."Se", 0)
      sens[v].SeId = system.pLoad(v.."SeId", 0)
      sens[v].SePa = system.pLoad(v.."SePa", 0)
      --print("sens", v, sens[v].Se, type(sens[v].Se), sens[v].SeId, type(sens[v].SeId), sens[v].SePa,
      --    type(sens[v].SePa))
   end
   
   for i in ipairs(ctl) do
      local v = ctl[i].var
      ctl[v] = system.pLoad(v.."Ctl")
   end

   distAB = system.pLoad("distAB", 150)

   zeroLatString = system.pLoad("zeroLatString")
   zeroLngString = system.pLoad("zeroLngString")

   gpsScale = system.pLoad("gpsScale", 1000)
   gpsScale = gpsScale / 1000.0
   
   rotA = system.pLoad("rotA", 0)
   rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   system.registerForm(1, MENU_APPS, "F3Gb", initForm, keyForm)
   system.registerTelemetry(1, "F3Gb Status", 2, printTele)
   
   --[[
   local cc = system.registerControl(1, "Motor Enable", "MOT")

   if not cc then
      system.messageBox("Could not register MOT control")
   else
      system.setControl(1, 1, 0)
   end
   --]]
   
   --system.registerLogVariable("elePullTime", "ms", elePullCB)
   readSensors(telem)

   --lvP = system.registerLogVariable("elePullTime", "ms", logWriteCB)
   --lvX = system.registerLogVariable("courseX", "m", logWriteCB)
   --lvY = system.registerLogVariable("courseY", "m", logWriteCB)   
   --lvD = system.registerLogVariable("perpDistA", "m", logWriteCB)
   --lvT = system.registerLogVariable("beep", "s", logWriteCB)

   resetFlight()
   
   print("DFM-F3G: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3Gb"}
