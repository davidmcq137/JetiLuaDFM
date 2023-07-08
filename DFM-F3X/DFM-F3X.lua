--[[

   ----------------------------------------------------------------------------
   DFM-F3X.lua released under MIT license by DFM 2022

   This app was created at the suggestion of Tim Bischoff. It is intended to
   facilitate practice flights for the new F3G electric glider competition and can
   also handle F3B

   ----------------------------------------------------------------------------
   
--]]

local F3XVersion = "0.70"
local MM
local F3X = {}
local cross = {}
--local turnCircle = {}

local TT = {}
local lastCall={}
local savedXP = {}
local savedYP = {}
local MAXSAVED=30

F3X.telem = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

F3X.sens = {
   {var="lat",  label="Latitude"},
   {var="lng",  label="Longitude"},
   {var="volt", label="Motor Voltage"},
   {var="amp",  label="Motor Current"},
   {var="alt",  label="Altitude"},
}

F3X.ctl = {
   {var="thr", label="Throttle"},
   {var="arm", label="Arming"},
   {var="ele", label="Elevator"},
   {var="rst", label="Reset Flight"},
   {var="bpo", label="Beep on"},
   {var="shr", label="Short 150"}
}

F3X.gpsP = {}

F3X.lv = {}
F3X.lv.luaCtl = {MOT=1, BPP=2, TSK=3}--
F3X.lv.luaTxt = {MOT="Motor", BPP="Beep", TSK="Task"}--

local elePullTime
local elePullLog
local swrLast
local swaLast

local fm = {F3X=1,F3B=2,Basic=3}
local preBeep, beepOn

local loopV = {}
loopV.fs = {Idle=1,MotorOn=2,MotorOff=3,Altitude=4,Ready=5, AtoB=6,BtoA=7, Done=8}
loopV.fsTxt = {"Idle", "Motor On", "Motor Off", "Altitude", "Ready", "A to B", "B to A", "Done"}

local zone = {[0]=1,[1]=2,[3]=3}

local function playFile(...)
   if F3X.flightMode ~= fm.Basic then
      system.playFile(...)
   end
end

local function playNumber(...)
   if F3X.flightMode ~= fm.Basic then
      system.playNumber(...)
   end
end

local function resetFlight()
   local swt, thr
   --print("resetFlight")
   loopV.flightState = loopV.fs.Idle
   loopV.morotStart = 0
   loopV.motorTime = 0
   loopV.motorPower = 0
   loopV.motorWattSec = 0
   loopV.flightTime = 0
   loopV.taskStartTime = nil
   loopV.taskLaps = nil
   preBeep = false
   cross = {}
   savedXP = {}
   savedYP = {}

   swt = system.getSwitchInfo(F3X.ctl.thr)
   if swt then thr = system.getInputs(swt.label) end

   if swt and swt.value and swt.value <= -0.99 then
      system.setControl(F3X.lv.luaCtl.MOT,  1, 0)
      loopV.motorStatus = true
   else
      system.setControl(F3X.lv.luaCtl.MOT, -1, 0)
      loopV.motorStatus = false
   end

   system.setControl(F3X.lv.luaCtl.BPP, -1, 0)
   system.setControl(F3X.lv.luaCtl.TSK, -1, 0)
end

local function keyForm(key)
   -- return value lets us know if menu is exiting and we can release memory
   local rel = MM.keyForm(key, F3X, loopV, resetFlight)
   if rel then MM = nil; collectgarbage() end
end

local function printTele(w,h)
   MM.printTele(w,h,F3X)
end

local xmin, xmax, ymin, ymax = -110, 290, -30, 170

local function xyAdj()
   local f = 1.1
   --print("Adjusting", loopV.curX, loopV.curY)
   xmin, xmax, ymin, ymax = xmin*f, xmax*f, ymin*f, ymax*f
   F3X.xlen = xmax - xmin
   F3X.yhgt = ymax
   print(xmin, xmax, ymin, ymax)
end

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function initForm(sf)

   -- must leave MM loaded until menu exits
   -- (see keyForm in menuCmd.lua) and keyForm in this file
   MM = require "DFM-F3X/menuCmd"
   MM.menuCmd(sf, F3X, resetFlight)
   collectgarbage()
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
	 package.loaded[TT[2]] = nil
	 TT[2] = nil
	 collectgarbage()
      end
   end

   if lastCall[4] then
      if TT[4] and (now -lastCall[4] > 200) then
	 package.loaded[TT[4]] = nil
	 TT[4] = nil
	 collectgarbage()
      end
   end
   
   
   if loopV.beepOffTime and now > loopV.beepOffTime then
      system.setControl(F3X.lv.luaCtl.BPP,-1,0)
      beepOn = -1
   end

   if F3X.ctl.shr then
      sws = system.getInputsVal(F3X.ctl.shr) + 1
   else
      sws = 0.0
   end
   
   if F3X.ctl.shr and sws then F3X.short150 = 5 * sws else F3X.short150 = 0.0 end

   F3X.gpsP.curPos = gps.getPosition(F3X.sens.lat.SeId, F3X.sens.lat.SePa, F3X.sens.lng.SePa)   
   
   if F3X.gpsP.curPos then
      if not loopV.initPos then
	 loopV.initPos = F3X.gpsP.curPos
	 if not F3X.gpsP.zeroPos then F3X.gpsP.zeroPos = F3X.gpsP.curPos end
      end
      
      loopV.curDist = gps.getDistance(F3X.gpsP.zeroPos, F3X.gpsP.curPos)
      F3X.gpsP.curBear = gps.getBearing(F3X.gpsP.zeroPos, F3X.gpsP.curPos)
      
      loopV.curX = loopV.curDist * math.cos(math.rad(F3X.gpsP.curBear+270)) -- why not same angle X and Y??
      loopV.curY = loopV.curDist * math.sin(math.rad(F3X.gpsP.curBear+90))
      
      
      if not loopV.lastX then loopV.lastX = loopV.curX end
      if not loopV.lastY then loopV.lastY = loopV.curY end

      if F3X.gpsP.rotA then
	 loopV.curX, loopV.curY = rotateXY(loopV.curX, loopV.curY, F3X.gpsP.rotA)
	 if F3X.gpsScale then
	    loopV.curX = loopV.curX * F3X.gpsScale
	 end
      end

      if loopV.curX < xmin or loopV.curX > xmax or loopV.curY < ymin or loopV.curY > ymax then
	 xyAdj()
	 savedXP = {}
	 savedYP = {}
      end

      local dist = math.sqrt( (loopV.curX - loopV.lastX)^2 + (loopV.curY - loopV.lastY)^2)

      if dist > 3 and cross[1] and loopV.flightState ~= loopV.fs.Done and
      (loopV.perpA > F3X.gpsP.distAB - F3X.short150 or loopV.perpA < 0) then -- new pt for ribbon
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
      loopV.detB = det(F3X.gpsP.distAB - F3X.short150,-50, F3X.gpsP.distAB - F3X.short150,
		       50,loopV.curX,loopV.curY)
      
      if loopV.detA > 0 then loopV.dA = 1 else loopV.dA = 0 end
      if loopV.detB > 0 then loopV.dB = 1 else loopV.dB = 0 end
      
      loopV.dd = loopV.dA + 2*loopV.dB
      
      loopV.perpA = pDist(0,-50,0,50,loopV.curX, loopV.curY)
      loopV.perpB = pDist(F3X.gpsP.distAB - F3X.short150,-50,F3X.gpsP.distAB - F3X.short150,
			  50, loopV.curX, loopV.curY)
      
      if loopV.detA < 0 then loopV.perpA = -loopV.perpA end
      if loopV.detB > 0 then loopV.perpB = -loopV.perpB end
      
      if loopV.dd then
	 loopV.flightZone = zone[loopV.dd]
	 if not loopV.lastFlightZone then loopV.lastFlightZone = loopV.flightZone end
      end
   end

   swb = system.getInputsVal(F3X.ctl.bpo)

   -- play the beep and count the lap as soon as we know we're there
   
   if (loopV.flightZone == 3 and loopV.lastFlightZone == 2) or
   (loopV.flightZone == 1 and loopV.lastFlightZone == 2) then
      if not swb or swb == 1 then
	 system.playBeep(0,440,500)
	 print("Beep")
	 system.setControl(F3X.lv.luaCtl.BPP,1,0)
	 beepOn = 1
	 loopV.beepOffTime = now + 1000
      end
      -- one transit AtoB or BtoA is a "lap"
      if loopV.taskLaps and loopV.flightState == loopV.fs.AtoB or loopV.flightState == loopV.fs.BtoA then
	 loopV.taskLaps = loopV.taskLaps + 1
	 --playFile("/Apps/DFM-F3X/lap.wav", AUDIO_QUEUE)
	 --playNumber(loopV.taskLaps,0)
      end
   end
   
   sensor = system.getSensorByID(F3X.sens.alt.SeId, F3X.sens.alt.SePa)
   if sensor and sensor.valid then
      loopV.altitude = sensor.value
   end

   sensor = system.getSensorByID(F3X.sens.amp.SeId, F3X.sens.amp.SePa)
   if sensor and sensor.valid then
      amp = sensor.value
   end

   sensor = system.getSensorByID(F3X.sens.volt.SeId, F3X.sens.volt.SePa)
   if sensor and sensor.valid then
      volt = sensor.value
   end
   if volt and amp then
      loopV.motorPower = volt * amp
   end

   swt = system.getInputsVal(F3X.ctl.thr)
   swa = system.getInputsVal(F3X.ctl.arm)
   swe = system.getInputsVal(F3X.ctl.ele)   
   swr = system.getInputsVal(F3X.ctl.rst)

   if not swrLast then swrLast = swr end
   if swr and swr == 1 and swrLast == -1 then
      resetFlight()
   end
   swrLast = swr

   if loopV.flightState == loopV.fs.Idle then
      if swa == 1 and swaLast == -1 then
	 playFile("/Apps/DFM-F3X/start_armed.wav", AUDIO_QUEUE)
      end
      swaLast = swa
      if F3X.flightMode == fm.F3X then
	 if (not swa or swa == 1) and (swt and swt == 1) then
	    if loopV.motorStatus then
	       loopV.morotStart = now
	       loopV.motorWattSec = 0
	       loopV.flightState = loopV.fs.MotorOn
	       loopV.lastPowerTime = now
	       loopV.flightStart = now
	       playFile("/Apps/DFM-F3X/motor_run_started.wav", AUDIO_QUEUE)
	    else
	       -- this will keep getting called, leaving the message up till throttle is off
	       system.messageBox("Throttle to 0, then Reset Flight", 1)
	    end
	 end
      elseif F3X.flightMode == fm.F3B then
	 loopV.flightStart = now
	 loopV.flightState = loopV.fs.Ready
      elseif F3X.flightMode == fm.Basic then
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
	 system.setControl(F3X.lv.luaCtl.MOT, -1, 0)
	 loopV.motorStatus = false
	 loopV.motorOffTime = now
	 playFile("/Apps/DFM-F3X/motor_off_manual.wav", AUDIO_QUEUE)
      end
      if loopV.motorTime > 30*1000 then
	 loopV.flightState = loopV.fs.MotorOff
	 system.setControl(F3X.lv.luaCtl.MOT, -1, 0)
	 loopV.motorStatus = false
	 loopV.motorOffTime = now
	 playFile("/Apps/DFM-F3X/motor_off_time.wav", AUDIO_QUEUE)
      elseif loopV.motorWattSec / 60 > 350 then
	 loopV.flightState = loopV.fs.MotorOff
	 system.setControl(F3X.lv.luaCtl.MOT, -1, 0)
	 loopV.motorStatus = false
	 loopV.motorOffTime = now
	 playFile("/Apps/DFM-F3X/motor_off_wattmin.wav", AUDIO_QUEUE)
      end
   end

   if loopV.flightState == loopV.fs.MotorOff then
      if now > loopV.motorOffTime + 10*1000 then
	 playFile("/Apps/DFM-F3X/start_altitude.wav", AUDIO_QUEUE)
	 if loopV.altitude then
	    playNumber(loopV.altitude, 0)
	 else
	    playFile("/Apps/DFM-F3X/unavailable.wav", AUDIO_QUEUE)
	 end
	 loopV.flightState = loopV.fs.Altitude
      end
   end
      
   if loopV.flightState == loopV.fs.Altitude then
      if loopV.flightTime / 1000 > 40 then
	 playFile("/Apps/DFM-F3X/40_seconds.wav", AUDIO_QUEUE)
	 loopV.flightState = loopV.fs.Ready
      end
   end

   if loopV.flightState == loopV.fs.Ready then
      if loopV.flightZone == 2 and loopV.lastFlightZone == 1 then
	 loopV.flightState = loopV.fs.AtoB
	 loopV.taskStartTime = now
	 loopV.taskLaps = 0
	 playFile("/Apps/DFM-F3X/task_started.wav", AUDIO_QUEUE)
	 system.setControl(F3X.lv.luaCtl.TSK, 1, 0)
      end
   end

   if loopV.flightState == loopV.fs.AtoB then
      if loopV.flightZone == 3 and loopV.lastFlightZone == 2 then
	 loopV.flightState = loopV.fs.BtoA
	 preBeep = false
	 cross = {}
	 savedXP = {}
	 savedYP = {}
	 if loopV.flightState ~= loopV.fs.Done then
	    cross[1] = {x=loopV.curX, y=loopV.curY}
	 end
      else
	 if loopV.flightState ~= loopV.fs.Done and cross[1] and not cross[2] then
	    cross[2] = {x=loopV.curX, y=loopV.curY}
	 end
	 if loopV.flightState ~= loopV.fs.Done and cross[2] and loopV.curX < cross[2].x then
	    cross[2].x = loopV.curX
	    cross[2].y = loopV.curY
	 end
	 if loopV.flightState ~= loopV.fs.Done and loopV.perpA >= 0 and
	 cross[1] and cross[2] and not cross[3] then
	    cross[3] = {x=loopV.curX, y=loopV.curY}
	    F3X.depth = math.abs(cross[1].x - cross[2].x)
	    F3X.width = math.abs(cross[3].y - cross[1].y)
	 end
      end
      if F3X.flightMode ~= fm.Basic and loopV.perpB <= 30 and not preBeep and loopV.flightZone == 2 then
	 if not swb or swb == 1 then
	    system.playBeep(1,880,300)
	    print("BeepBeepA", loopV.perpB, loopV.perpA)
	 end
	 preBeep = true

      end
   elseif loopV.flightState == loopV.fs.BtoA then
      if loopV.flightZone == 1 and loopV.lastFlightZone == 2 then
	 if elePullTime then
	    --playFile("/Apps/DFM-F3X/pull_latency.wav", AUDIO_QUEUE)
	    --playNumber( (now - elePullTimef)/1000, 1)
	    elePullLog = now - elePullTime
	    elePullTime = nil
	 end
	 loopV.flightState = loopV.fs.AtoB
	 cross={}
	 savedXP = {}
	 savedYP = {}
	 cross[1] = {x=loopV.curX, y=loopV.curY}
	 preBeep = false
      else
	 if loopV.flightState ~= loopV.fs.Done and cross[1] and not cross[2] then
	    cross[2] = {x=loopV.curX, y=loopV.curY}
	 end
	 if loopV.flightState ~= loopV.fs.Done and cross[2] and loopV.curX > cross[2].x then
	    cross[2].x = loopV.curX
	    cross[2].y = loopV.curY
	 end
	 if loopV.flightState ~= loopV.fs.Done and loopV.perpA <= F3X.gpsP.distAB - F3X.short150 and
	 cross[2] and cross[1] and not cross[3] then
	    cross[3] = {x=loopV.curX, y=loopV.curY}
	    F3X.depth = math.abs(cross[1].x - cross[2].x)
	    F3X.width = math.abs(cross[3].y - cross[1].y)
	 end
      end
      if F3X.flightMode ~= fm.Basic and loopV.perpA <= 30 and not preBeep and loopV.flightZone == 2 then
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

   if F3X.flightMode ~= fm.Basic and loopV.flightState ~= loopV.fs.Done
   and loopV.taskStartTime and (( now - loopV.taskStartTime) > 240*1000) then
      loopV.flightState = loopV.fs.Done
      loopV.flightDone = loopV.flightTime
      loopV.taskDone = now - loopV.taskStartTime
      playFile("/Apps/DFM-F3X/task_complete.wav", AUDIO_QUEUE)
      cross = {}
      savedXP = {}
      savedYP = {}
      system.setControl(F3X.lv.luaCtl.TSK, -1, 0)
   end
   loopV.lastFlightZone = loopV.flightZone
end

local function virtualTele(tt, iTele)
   local now = system.getTimeCounter()
   if iTele == 4 then
      if not tt[4] then
	 if tt[2] and now - lastCall[2] < 300 then return end 
	 tt[4] = require "DFM-F3X/fullTele"
      end
      lastCall[4] = system.getTimeCounter()
      tt[4].fullTele(F3X, loopV, cross, savedXP, savedYP, xp, yp)
   elseif iTele == 2 then
      if not tt[2]  then
	 if tt[4] and now - lastCall[4] < 300 then return end
	 tt[2] = require "DFM-F3X/doubleTele"
      end
      lastCall[2] = system.getTimeCounter()
      tt[2].doubleTele(loopV, F3X)
   end 
end

local function logWriteCB(idx)
   if idx == F3X.lv.P then
      if elePullLog then
	 return elePullLog, 0
      else
	 return 0,0
      end
   elseif idx == F3X.lv.D then
      if loopV.perpA then
	 return loopV.perpA*10, 1
      else
	 return 0,0
      end
   elseif idx == F3X.lv.T then
      if beepOn then
	 return beepOn, 0
      else
	 return 0,0
      end
   elseif idx == F3X.lv.X then
      if loopV.curX then
	 return loopV.curX*10, 1
      else
	 return 0,0
      end
   elseif idx == F3X.lv.Y then
      if loopV.curY then
	 return loopV.curY*10, 1
      else
	 return 0,0
      end      
   elseif idx == F3X.lv.De then
      if F3X.depth then
	 return F3X.depth*10, 1
      else
	 return 0,0
      end
   elseif idx == F3X.lv.Wi then
      if F3X.width then
	 return F3X.width*10, 1
      else
	 return 0,0
      end
   end
end

local function init()

   local M = require "DFM-F3X/initCmd"

   F3X = M.initCmd(F3X, loopV, TT, initForm, keyForm, printTele, virtualTele, resetFlight, logWriteCB)
   M = nil
   F3X.xlen = xmax - xmin
   F3X.yhgt = ymax
   
   collectgarbage()

   local s1,s2 = system.getInputs("P1", "P2")
   print("s1,s2", s1, s2)
   
   if (s1 < -0.8 and s2 < -0.8) or not
   (F3X.sens.lat.SeId > 0 and F3X.sens.lat.SePa > 0 and F3X.sens.lng.SePa > 0) then
      print("call teleCmd")
      local M = require "DFM-F3X/teleCmd"
      M.teleCmd(F3X)
      M = nil
      collectgarbage()
   end
   
   print("DFM-F3X: gcc " .. collectgarbage("count"))
   
   if select(2, system.getDeviceType()) == 1 then
      system.getSensors()
   end
   
end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=F3XVersion, name="F3X"}
