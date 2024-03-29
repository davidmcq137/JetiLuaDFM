--[[

   ----------------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition

   It can also be used for F3B

   ----------------------------------------------------------------------------
   
--]]

local F3GVersion = "0.61"
local MM
local F3G = {}
local cross = {}
--local turnCircle = {}

local TT = {}
local lastCall={}
local savedXP = {}
local savedYP = {}
local MAXSAVED=30

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
   {var="rst", label="Reset Flight"},
   {var="bpo", label="Beep on"},
   {var="shr", label="Short 150"}
}

F3G.gpsP = {}

F3G.lv = {}
F3G.lv.luaCtl = {MOT=1, BPP=2, TSK=3}--
F3G.lv.luaTxt = {MOT="Motor", BPP="Beep", TSK="Task"}--

local elePullTime
local elePullLog
local swrLast
local swaLast

local fm = {F3G=1,F3B=2,Basic=3}
local preBeep, beepOn

local loopV = {}
loopV.fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
loopV.fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}

--local flightState
--local motorTime
--local motorStart
--local motorPower
--local motorWattSec
--local motorOffTime
--local motorStatus
--local lastPowerTime
--local flightTime
--local flightStart
--local flightDone
--local flightZone
--local taskStartTime
--local taskDone
--local taskLaps
--local lastFlightZone
local zone = {[0]=1,[1]=2,[3]=3}
--local beepOffTime

--local curDist
--local detA
--local detB
--local dA
--local dB
--local dd
--local perpA
--local perpB

--local initPos
--local curX
--local curY
--local lastX
--local lastY
--local altitude

local function playFile(...)
   if F3G.flightMode ~= fm.Basic then
      system.playFile(...)
   end
end

local function playNumber(...)
   if F3G.flightMode ~= fm.Basic then
      system.playNumber(...)
   end
end

local function resetFlight()
   local swt, thr
   print("resetFlight")
   loopV.flightState = loopV.fs.Idle
   loopV.morotStart = 0
   loopV.motorTime = 0
   loopV.motorPower = 0
   loopV.motorWattSec = 0
   loopV.flightTime = 0
   loopV.taskStartTime = nil
   loopV.taskLaps = nil
   preBeep = false
   swt = system.getSwitchInfo(F3G.ctl.thr)
   if swt then print(swt.label, swt.value, swt.proportional, swt.assigned, swt.mode) else print("swt nil") end
   if swt then thr = system.getInputs(swt.label) end
   print("thr, gIV", thr, system.getInputsVal(F3G.ctl.thr))
   
   if swt and swt.value and swt.value <= -0.99 then
      system.setControl(F3G.lv.luaCtl.MOT,  1, 0)
      loopV.motorStatus = true
   else
      system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
      loopV.motorStatus = false
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

local xmin, xmax, ymin, ymax = -110, 290, -30, 170

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function initForm(sf)

   -- must leave MM loaded until menu exits
   -- (see keyForm in menuCmd.lua) and keyForm in this file

   print("DFM-F3G: A " .. collectgarbage("count"))      
   MM = require "DFM-F3G/menuCmd"
   print("DFM-F3G: B " .. collectgarbage("count"))
   MM.menuCmd(sf, F3G, resetFlight)
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
   local swb
   local sws
   local now
   local volt, amp
   
   now = system.getTimeCounter()

   if lastCall[2] then
      if TT[2] and (now - lastCall[2] > 200) then
	 print("unloading double", now - lastCall[2], TT)
	 collectgarbage()
	 print(collectgarbage("count"))
	 package.loaded[TT[2]] = nil
	 TT[2] = nil
	 collectgarbage()
	 print(collectgarbage("count"))
      end
   end

   if lastCall[4] then
      if TT[4] and (now -lastCall[4] > 200) then
	 print("unloading full", now - lastCall[4], TT)
	 collectgarbage()
	 print(collectgarbage("count"))
	 package.loaded[TT[4]] = nil
	 TT[4] = nil
	 collectgarbage()
	 print(collectgarbage("count"))
      end
   end
   
   
   if loopV.beepOffTime and now > loopV.beepOffTime then
      system.setControl(F3G.lv.luaCtl.BPP,-1,0)
      beepOn = -1
   end

   if F3G.ctl.shr then
      sws = system.getInputsVal(F3G.ctl.shr) + 1
   else
      sws = 0.0
   end
   
   if F3G.ctl.shr and sws then F3G.short150 = 5 * sws else F3G.short150 = 0.0 end

   F3G.gpsP.curPos = gps.getPosition(F3G.sens.lat.SeId, F3G.sens.lat.SePa, F3G.sens.lng.SePa)   
   
   if F3G.gpsP.curPos then
      if not loopV.initPos then
	 loopV.initPos = F3G.gpsP.curPos
	 if not F3G.gpsP.zeroPos then F3G.gpsP.zeroPos = F3G.gpsP.curPos end
      end
      
      loopV.curDist = gps.getDistance(F3G.gpsP.zeroPos, F3G.gpsP.curPos)
      F3G.gpsP.curBear = gps.getBearing(F3G.gpsP.zeroPos, F3G.gpsP.curPos)
      
      loopV.curX = loopV.curDist * math.cos(math.rad(F3G.gpsP.curBear+270)) -- why not same angle X and Y??
      loopV.curY = loopV.curDist * math.sin(math.rad(F3G.gpsP.curBear+90))
      
      if not loopV.lastX then loopV.lastX = loopV.curX end
      if not loopV.lastY then loopV.lastY = loopV.curY end
      
      loopV.curX, loopV.curY = rotateXY(loopV.curX, loopV.curY, F3G.gpsP.rotA)

      local dist = math.sqrt( (loopV.curX - loopV.lastX)^2 + (loopV.curY - loopV.lastY)^2)
      --print(dist)
      if dist > 3 and cross[1] and
      (loopV.perpA > F3G.gpsP.distAB - F3G.short150 or loopV.perpA < 0) then -- new pt for ribbon
	 --heading = math.atan(loopV.curX-loopV.lastX, loopV.curY - loopV.lastY)
	 if #savedXP+1 > MAXSAVED then
	    table.remove(savedXP, 1)
	    table.remove(savedYP, 1)
	 else
	    table.insert(savedXP, xp(loopV.curX))
	    table.insert(savedYP, yp(loopV.curY))
	 end
	 loopV.lastX = loopV.curX
	 loopV.lastY = loopV.curY
      end

      loopV.detA = det(0,-50,0,50,loopV.curX,loopV.curY)
      loopV.detB = det(F3G.gpsP.distAB - F3G.short150,-50, F3G.gpsP.distAB - F3G.short150,
		       50,loopV.curX,loopV.curY)
      --detC = det(-75,0,225,0,loopV.curX,loopV.curY)
      
      if loopV.detA > 0 then loopV.dA = 1 else loopV.dA = 0 end
      if loopV.detB > 0 then loopV.dB = 1 else loopV.dB = 0 end
      --if detC > 0 then dC = 1 else dC = 0 end
      
      loopV.dd = loopV.dA + 2*loopV.dB
      
      loopV.perpA = pDist(0,-50,0,50,loopV.curX, loopV.curY)
      loopV.perpB = pDist(F3G.gpsP.distAB - F3G.short150,-50,F3G.gpsP.distAB - F3G.short150,
			  50, loopV.curX, loopV.curY)
      
      if loopV.detA < 0 then loopV.perpA = -loopV.perpA end
      if loopV.detB > 0 then loopV.perpB = -loopV.perpB end
      
      if loopV.dd then
	 loopV.flightZone = zone[loopV.dd]
	 if not loopV.lastFlightZone then loopV.lastFlightZone = loopV.flightZone end
      end
   end

   swb = system.getInputsVal(F3G.ctl.bpo)

   -- play the beep and count the lap as soon as we know we're there
   
   if (loopV.flightZone == 3 and loopV.lastFlightZone == 2) or
   (loopV.flightZone == 1 and loopV.lastFlightZone == 2) then
      if not swb or swb == 1 then
	 system.playBeep(0,440,500)
	 print("Beep")
	 system.setControl(F3G.lv.luaCtl.BPP,1,0)
	 beepOn = 1
	 loopV.beepOffTime = now + 1000
      end
      -- one transit AtoB or BtoA is a "lap"
      if loopV.taskLaps and loopV.flightState == loopV.fs.AtoB or loopV.flightState == loopV.fs.BtoA then
	 loopV.taskLaps = loopV.taskLaps + 1
	 --playFile("/Apps/DFM-F3G/lap.wav", AUDIO_QUEUE)
	 --playNumber(loopV.taskLaps,0)
      end
   end
   
   sensor = system.getSensorByID(F3G.sens.alt.SeId, F3G.sens.alt.SePa)
   if sensor and sensor.valid then
      loopV.altitude = sensor.value
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
      loopV.motorPower = volt * amp
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

   if loopV.flightState == loopV.fs.Idle then
      if swa == 1 and swaLast == -1 then
	 playFile("/Apps/DFM-F3G/start_armed.wav", AUDIO_QUEUE)
      end
      swaLast = swa
      if F3G.flightMode == fm.F3G then
	 if (not swa or swa == 1) and (swt and swt == 1) then
	    print("swa and swt ok, loopV.motorStatus:", loopV.motorStatus)
	    if loopV.motorStatus then
	       loopV.morotStart = now
	       loopV.motorWattSec = 0
	       loopV.flightState = loopV.fs.MotorOn
	       loopV.lastPowerTime = now
	       loopV.flightStart = now
	       playFile("/Apps/DFM-F3G/motor_run_started.wav", AUDIO_QUEUE)
	    else
	       -- this will keep getting called, leaving the message up till throttle is off
	       system.messageBox("Throttle to 0, then Reset Flight", 1)
	    end
	 end
      elseif F3G.flightMode == fm.F3B then
	 loopV.flightStart = now
	 loopV.flightState = loopV.fs.Ready
      elseif F3G.flightMode == fm.Basic then
	 loopV.flightStart = now
	 loopV.flightState = loopV.fs.Ready
      end
      
   else
      if loopV.flightStart then
	 loopV.flightTime = now - loopV.flightStart
      end
   end

   if loopV.flightState == loopV.fs.MotorOn then
      if volt and amp then
	 loopV.motorWattSec = loopV.motorWattSec + volt * amp * (now-loopV.lastPowerTime) / 1000
	 loopV.lastPowerTime = now
      end
      loopV.motorTime = now - loopV.morotStart

      if swt and swt < 1 then
	 loopV.flightState = loopV.fs.MotorOff
	 system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
	 loopV.motorStatus = false
	 loopV.motorOffTime = now
	 playFile("/Apps/DFM-F3G/motor_off_manual.wav", AUDIO_QUEUE)
      end
      if loopV.motorTime > 30*1000 then
	 loopV.flightState = loopV.fs.MotorOff
	 system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
	 loopV.motorStatus = false
	 loopV.motorOffTime = now
	 playFile("/Apps/DFM-F3G/motor_off_time.wav", AUDIO_QUEUE)
      elseif loopV.motorWattSec / 60 > 350 then
	 loopV.flightState = loopV.fs.MotorOff
	 system.setControl(F3G.lv.luaCtl.MOT, -1, 0)
	 loopV.motorStatus = false
	 loopV.motorOffTime = now
	 playFile("/Apps/DFM-F3G/motor_off_wattmin.wav", AUDIO_QUEUE)
      end
   end

   if loopV.flightState == loopV.fs.MotorOff then
      if now > loopV.motorOffTime + 10*1000 then
	 playFile("/Apps/DFM-F3G/start_altitude.wav", AUDIO_QUEUE)
	 if loopV.altitude then
	    playNumber(loopV.altitude, 0)
	 else
	    playFile("/Apps/DFM-F3G/unavailable.wav", AUDIO_QUEUE)
	 end
	 loopV.flightState = loopV.fs.Altitude
      end
   end
      
   if loopV.flightState == loopV.fs.Altitude then
      if loopV.flightTime / 1000 > 40 then
	 playFile("/Apps/DFM-F3G/40_seconds.wav", AUDIO_QUEUE)
	 loopV.flightState = loopV.fs.Ready
      end
   end

   if loopV.flightState == loopV.fs.Ready then
      if loopV.flightZone == 2 and loopV.lastFlightZone == 1 then
	 loopV.flightState = loopV.fs.AtoB
	 loopV.taskStartTime = now
	 loopV.taskLaps = 0
	 playFile("/Apps/DFM-F3G/task_started.wav", AUDIO_QUEUE)
	 system.setControl(F3G.lv.luaCtl.TSK, 1, 0)
      end
   end

   if loopV.flightState == loopV.fs.AtoB then
      if loopV.flightZone == 3 and loopV.lastFlightZone == 2 then
	 loopV.flightState = loopV.fs.BtoA
	 preBeep = false
	 cross = {}
	 savedXP = {}
	 savedYP = {}
	 cross[1] = {x=loopV.curX, y=loopV.curY}
	 --print("cross[1]", cross[1].x, cross[1].y, loopV.flightState)
      else
	 if cross[1] and not cross[2] then
	    cross[2] = {x=loopV.curX, y=loopV.curY}
	    --print("2a", cross[2].x, cross[2].y)	    
	 end
	 if cross[2] and loopV.curX < cross[2].x then
	    cross[2].x = loopV.curX
	    cross[2].y = loopV.curY
	    --print("2b", cross[2].x, cross[2].y)
	 end
	 if loopV.perpA >= 0 and cross[1] and cross[2] and not cross[3] then
	    cross[3] = {x=loopV.curX, y=loopV.curY}
	    --print("3", cross[3].x, cross[3].y, loopV.flightState, #savedXP)
	 end
      end
      if F3G.flightMode ~= fm.Basic and loopV.perpB <= 20 and not preBeep and loopV.flightZone == 2 then
	 if not swb or swb == 1 then
	    system.playBeep(1,880,300)
	    print("BeepBeepA", loopV.perpB, loopV.perpA)
	 end
	 preBeep = true

      end
   elseif loopV.flightState == loopV.fs.BtoA then
      if loopV.flightZone == 1 and loopV.lastFlightZone == 2 then
	 if elePullTime then
	    --playFile("/Apps/DFM-F3G/pull_latency.wav", AUDIO_QUEUE)
	    --playNumber( (now - elePullTimef)/1000, 1)
	    elePullLog = now - elePullTime
	    elePullTime = nil
	 end
	 loopV.flightState = loopV.fs.AtoB
	 cross={}
	 savedXP = {}
	 savedYP = {}
	 cross[1] = {x=loopV.curX, y=loopV.curY}
	 --print("cross[1]", cross[1].x, cross[1].y, loopV.flightState)
	 --turnCircle = {}
	 preBeep = false
      else
	 if cross[1] and not cross[2] then
	    cross[2] = {x=loopV.curX, y=loopV.curY}
	    --print("2a", cross[2].x, cross[2].y)
	 end
	 if cross[2] and loopV.curX > cross[2].x then
	    cross[2].x = loopV.curX
	    cross[2].y = loopV.curY
	    --print("2b", cross[2].x, cross[2].y)
	 end
	 if loopV.perpA <= F3G.gpsP.distAB - F3G.short150 and cross[2] and cross[1] and not cross[3] then
	    cross[3] = {x=loopV.curX, y=loopV.curY}
	    --print("3", cross[3].x, cross[3].y, loopV.flightState, #savedXP)
	 end
      end
      if F3G.flightMode ~= fm.Basic and loopV.perpA <= 20 and not preBeep and loopV.flightZone == 2 then
	 if not swb or swb == 1 then
	    system.playBeep(1,880,300)
	    print("BeepBeepB", loopV.perpA, loopV.perpB)
	 end
	 preBeep = true

      end
      if swe and swe == 1 and loopV.perpA < 20 and (not elePullTime) then
	 --print("elePullTime now")
	 elePullTime = now
      end
   end

   if F3G.flightMode ~= fm.Basic and loopV.flightState ~= loopV.fs.Done
   and loopV.taskStartTime and (( now - loopV.taskStartTime) > 240*1000) then
      loopV.flightState = loopV.fs.Done
      loopV.flightDone = loopV.flightTime
      loopV.taskDone = now - loopV.taskStartTime
      playFile("/Apps/DFM-F3G/task_complete.wav", AUDIO_QUEUE)
      system.setControl(F3G.lv.luaCtl.TSK, -1, 0)
   end
   loopV.lastFlightZone = loopV.flightZone
end


local function virtualTele(tt, iTele)
   local now = system.getTimeCounter()
   if iTele == 4 then
      if not tt[4] then
	 if tt[2] and now - lastCall[2] < 300 then return end 
	 print("loading full", collectgarbage("count"))
	 tt[4] = require "DFM-F3G/fullTele"
	 print("loading full", collectgarbage("count"))	 
      end
      lastCall[4] = system.getTimeCounter()
      tt[4].fullTele(F3G, loopV, cross, savedXP, savedYP, xp, yp)
   elseif iTele == 2 then
      if not tt[2]  then
	 if tt[4] and now - lastCall[4] < 300 then return end
	 print("loading double", collectgarbage("count"))
	 tt[2] = require "DFM-F3G/doubleTele"
	 print("loading double", collectgarbage("count"))

      end
      lastCall[2] = system.getTimeCounter()
      tt[2].doubleTele(loopV)
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
      if loopV.perpA then
	 return loopV.perpA*10, 1
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
      if loopV.curX then
	 return loopV.curX*10, 1
      else
	 return 0,0
      end
   elseif idx == F3G.lv.Y then
      if loopV.curY then
	 return loopV.curY*10, 1
      else
	 return 0,0
      end      
   end
end

local function init()
   print("DFM-F3G: 1 " .. collectgarbage("count"))   
   local M = require "DFM-F3G/initCmd"
   F3G = M.initCmd(F3G, TT, initForm, keyForm, printTele, virtualTele, resetFlight, logWriteCB)
   print("DFM-F3G: 2 " .. collectgarbage("count"))
   M = nil
   collectgarbage()
   print("DFM-F3G: 3 " .. collectgarbage("count"))


   --(F3G.sens.lat.SeId, F3G.sens.lat.SePa, F3G.sens.lng.SePa)
   local s1,s2 = system.getInputs("P1", "P2")
   print(s1,s2, F3G.sens.lat.SeId)
   
   if (s1 < -0.8 and s2 < -0.8) or not
   (F3G.sens.lat.SeId > 0 and F3G.sens.lat.SePa > 0 and F3G.sens.lng.SePa > 0) then
      local M = require "DFM-F3G/teleCmd"
      M.teleCmd(F3G)
      print("DFM-F3G: 4 " .. collectgarbage("count"))
      M = nil
      collectgarbage()
   end
   
   print("DFM-F3G: 5 " .. collectgarbage("count"))
   
   if select(2, system.getDeviceType()) == 1 then
      system.getSensors()
   end
   
   
   
end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G"}
