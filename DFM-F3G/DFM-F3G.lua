--[[

   ----------------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition

   It can also be used for F3B

   ----------------------------------------------------------------------------
   
--]]

local F3GVersion = "0.60"
local MM
local F3G = {}

F3G.telem = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

F3G.sens = {
   {var="lat",  label="Latitude"},
   {var="lng",  label="Longitude"},
   {var="volt", label="Motor Voltage"},
   {var="amp",  label="Motor Current"},
   {var="alt",  label="Altitude"},
}

F3G.ctl = {
   {var="thr", label="Throttle"},
   {var="arm", label="Arming"},
   {var="ele", label="Elevator"},
   {var="rst", label="Reset Flight"}
}

F3G.gpsP = {}

F3G.lv = {}
F3G.lv.luaCtl = {MOT=1, BPP=2, TSK=3}--
F3G.lv.luaTxt = {MOT="Motor", BPP="Beep", TSK="Task"}--


local initPos
local curX, curY
local lastX, lastY
local altitude
local early = 0

local elePullTime
local elePullLog
local swrLast
local swaLast

local flightState
local fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
local fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}

local preBeep, beepOn

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
local detA, detB
local dA, dB, dd
local perpA, perpB


local function resetFlight()
   local swt, thr
   print("resetFlight")
   flightState = fs.Idle
   motorStart = 0
   motorTime = 0
   motorPower = 0
   motorWattSec = 0
   flightTime = 0
   taskStartTime = nil
   taskLaps = nil
   preBeep = false
   swt = system.getSwitchInfo(F3G.ctl.thr)
   if swt then print(swt.label, swt.value, swt.proportional, swt.assigned, swt.mode) else print("swt nil") end
   if swt then thr = system.getInputs(swt.label) end
   print("thr, gIV", thr, system.getInputsVal(F3G.ctl.thr))
   
   if swt and swt.value and swt.value <= -0.99 then
      system.setControl(F3G.lv.luaCtl.MOT,  1, 0)
      motorStatus = true
   else
      system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
      motorStatus = false
   end
   system.setControl(F3G.lv.luaCtl.BPP, -1, 0)
   system.setControl(F3G.lv.luaCtl.TSK, -1, 0)
end

local function keyForm(key)
   print("keyForm", key, MM)
   print("kf1", collectgarbage("count"))
   local rel = MM.keyForm(key, F3G, resetFlight)
   if rel then print("releasing MM"); MM = nil; collectgarbage() end
   print("kf2", collectgarbage("count"))
end

local function printTele(w,h)
   --print("printTele", w, h, MM)
   MM.printTele(w,h,F3G)
end

local function initForm(sf)

   -- must leave MM loaded until menu exits
   -- (see keyForm in menuCmd.lua) and keyForm in this file

   print("DFM-F3G: A " .. collectgarbage("count"))      
   MM = require "DFM-F3G/menuCmd"
   print("DFM-F3G: B " .. collectgarbage("count"))
   MM.menuCmd(sf, F3G)
   collectgarbage()
   print("DFM-F3G: C " .. collectgarbage("count"))         
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
      system.setControl(F3G.lv.luaCtl.BPP,-1,0)
      beepOn = -1
   end
   
   F3G.gpsP.curPos = gps.getPosition(F3G.sens.lat.SeId, F3G.sens.lat.SePa, F3G.sens.lng.SePa)   

   if F3G.gpsP.curPos then
      if not initPos then
	 initPos = F3G.gpsP.curPos
	 if not F3G.gpsP.zeroPos then F3G.gpsP.zeroPos = F3G.gpsP.curPos end
      end
      
      curDist = gps.getDistance(F3G.gpsP.zeroPos, F3G.gpsP.curPos)
      F3G.gpsP.curBear = gps.getBearing(F3G.gpsP.zeroPos, F3G.gpsP.curPos)
      
      curX = curDist * math.cos(math.rad(F3G.gpsP.curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(F3G.gpsP.curBear+90))
      
      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, F3G.gpsP.rotA)

      local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)
      
      if curX ~= lastX or curY ~= lastY and dist > 5 then -- new point
	 --heading = math.atan(curX-lastX, curY - lastY)
	 lastX = curX
	 lastY = curY
      end
      
      detA = det(0,-50,0,50,curX,curY)
      detB = det(F3G.gpsP.distAB,-50, F3G.gpsP.distAB, 50,curX,curY)
      --detC = det(-75,0,225,0,curX,curY)
      
      if detA > 0 then dA = 1 else dA = 0 end
      if detB > 0 then dB = 1 else dB = 0 end
      --if detC > 0 then dC = 1 else dC = 0 end
      
      dd = dA + 2*dB
      
      perpA = pDist(0,-50,0,50,curX, curY)
      perpB = pDist(F3G.gpsP.distAB,-50,F3G.gpsP.distAB, 50, curX, curY)
      
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
      system.setControl(F3G.lv.luaCtl.BPP,1,0)
      beepOn = 1
      beepOffTime = now + 1000
      -- one transit AtoB or BtoA is a "lap"
      if taskLaps and flightState == fs.AtoB or flightState == fs.BtoA then
	 taskLaps = taskLaps + 1
	 --system.playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
	 --system.playNumber(taskLaps,0)
      end
   end
   
   sensor = system.getSensorByID(F3G.sens.alt.SeId, F3G.sens.alt.SePa)
   if sensor and sensor.valid then
      altitude = sensor.value
   end

   sensor = system.getSensorByID(F3G.sens.amp.SeId, F3G.sens.amp.SePa)
   if sensor and sensor.valid then
      amp = sensor.value
   end

   sensor = system.getSensorByID(F3G.sens.volt.SeId, F3G.sens.volt.SePa)
   if sensor and sensor.valid then
      volt = sensor.value
   end
   if volt and amp then
      motorPower = volt * amp
   end

   swt = system.getInputsVal(F3G.ctl.thr)
   swa = system.getInputsVal(F3G.ctl.arm)
   swe = system.getInputsVal(F3G.ctl.ele)   
   swr = system.getInputsVal(F3G.ctl.rst)

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
	 print("swa and swt ok, motorStatus:", motorStatus)
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
      if flightStart then
	 flightTime = now - flightStart
      end
      
   end

   if flightState == fs.MotorOn then
      if volt and amp then
	 motorWattSec = motorWattSec + volt * amp * (now-lastPowerTime) / 1000
	 lastPowerTime = now
      end
      motorTime = now - motorStart

      if swt and swt < 1 then
	 flightState = fs.MotorOff
	 system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
	 motorStatus = false
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_manual.wav", AUDIO_QUEUE)
      end
      if motorTime > 30*1000 then
	 flightState = fs.MotorOff
	 system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
	 motorStatus = false
	 motorOffTime = now
	 system.playFile("/Apps/DFM-F3G/motor_off_time.wav", AUDIO_QUEUE)
      elseif motorWattSec / 60 > 350 then
	 flightState = fs.MotorOff
	 system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
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
	 system.setControl(F3G.lv.luaCtl.TSK, 1, 0)
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
      system.setControl(F3G.lv.luaCtl.TSK, -1, 0)
   end
   
   lastFlightZone = flightZone
end


local xmin, xmax, ymin, ymax = -110, 290, -30, 170

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function drawPylons()
   lcd.drawLine(xp(-50), yp(0), xp(200), yp(0))
   lcd.drawLine(xp(0), yp(-10), xp(0), yp(160))
   lcd.drawLine(xp(F3G.gpsP.distAB), yp(-10), xp(F3G.gpsP.distAB), yp(160))
   lcd.drawText(xp(0) - 4, yp(-10), "A")
   lcd.drawText(xp(F3G.gpsP.distAB) - 4, yp(-10), "B")
   if early > 0.1 then
      lcd.setColor(200,200,200)
      lcd.drawLine(xp(F3G.gpsP.distAB-early), yp(-10), xp(F3G.gpsP.distAB-early), yp(160))
      lcd.setColor(0,0,0)
   end
end

local function fullTele()

   drawPylons()
   if curX and curY then
      lcd.setColor(0,255,0)
      if  detB > 0 then
	 lcd.setColor(255,0,0)
      elseif detA > 0 then
	 lcd.setColor(0,0,255)
      end
      lcd.drawFilledRectangle(xp(curX)-3, yp(curY)-3, 6, 6)
      --drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      lcd.setColor(0,0,0)
      text = string.format("%.2f", perpA)
      lcd.drawText( xp(0) - lcd.getTextWidth(FONT_NORMAL, text)/2 , yp(-60), text)
      text = string.format("%.2f", perpB)
      lcd.drawText( xp(F3G.gpsP.distAB) - lcd.getTextWidth(FONT_NORMAL, text)/2, yp(-60), text)
   end
end

local function doubleTele()

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
   if idx == F3G.lv.P then
      if elePullLog then
	 return elePullLog, 0
      else
	 return 0,0
      end
   elseif idx == F3G.lv.D then
      if perpA then
	 return perpA*10, 1
      else
	 return 0,0
      end
   elseif idx == F3G.lv.T then
      if beepOn then
	 return beepOn, 0
      else
	 return 0,0
      end
   elseif idx == F3G.lv.X then
      if curX then
	 return curX*10, 1
      else
	 return 0,0
      end
   elseif idx == F3G.lv.Y then
      if curY then
	 return curY*10, 1
      else
	 return 0,0
      end      
   end
end

local function init()
   print("DFM-F3G: 1 " .. collectgarbage("count"))   
   local M = require "DFM-F3G/initCmd"
   F3G = M.initCmd(F3G, initForm, keyForm, printTele, doubleTele,  fullTele, resetFlight, logWriteCB)
   print("DFM-F3G: 2 " .. collectgarbage("count"))
   M = nil
   collectgarbage()
   print("DFM-F3G: 3 " .. collectgarbage("count"))
end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G"}
