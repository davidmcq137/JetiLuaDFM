--[[

   ----------------------------------------------------------------------------
   DFM-TimV.lua released under MIT license by DFM 2022

   Variable Countdown Timer .. or as Harry says "Time Dilation" timer

   ----------------------------------------------------------------------------
   
--]]

local TimVVersion = "0.0"

local fTimeT
local lastfTimeT
local iTimeT

local startMins
local startSecs

local startStop

local annFull
local annVar

local thrControl
local thrFrc

local swfLast
local swvLast
local greater

local timerExp
local throttleExp

local resetSw
local swrLast

local function compExp(timExp)
   local thrExp
   local expFac = 40
   if timExp == 0 then thrExp = 1 end
   if timExp > 0  then thrExp = 1+timExp/expFac end
   if timExp < 0  then thrExp = expFac/(expFac-timExp) end
   return thrExp
end
      
local function tickToMinSec(tick)
   local ff = tick / 1000.0
   local fm = ff // 60.0
   local fs = ff - fm * 60.0
   local ss = string.format("%d:%02d", fm, fs)
   return ss, fm, fs
end

local function changedVal(val, hm)
   if hm == "M" then
      startMins = val
      system.pSave("startMins", startMins)
   elseif hm == "S" then
      startSecs = val
      system.pSave("startSecs", startSecs)
   elseif hm == "W" then
      startStop = val
      system.pSave("startStop", startStop)
   elseif hm == "T" then
      local tt = system.getSwitchInfo(val)
      if not tt.proportional then
	 system.messageBox("Throttle Control must be proportional")
	 form.reinit(1)
	 return
      end
      if string.find(tt.mode, "C") then
	 system.messageBox("Throttle Control must be set -100 to 100")
	 form.reinit(1)
	 return
      end
      thrControl = val
      system.pSave("thrControl", thrControl)
   elseif hm == "F" then
      annFull = val
      system.pSave("annFull", annFull)
   elseif hm == "V" then
      annVar = val
      system.pSave("annVar", annVar)
   elseif hm == "X" then
      timerExp = val
      throttleExp = compExp(timerExp)
      print("throttleExp", throttleExp)
      system.pSave("timerExp", timerExp)
   elseif hm == "R" then
      resetSw = val
      system.pSave("resetSw", resetSw)
   end
end

local function initForm(sf)

   form.addRow(4)
   form.addLabel({label="Mins: "})
   form.addIntbox(startMins, 0, 99, 10, 0, 1, (function(x) return changedVal(x, "M") end) )
   form.addLabel({label="Seconds: "})
   form.addIntbox(startSecs, 0, 59, 0, 0, 1, (function(x) return changedVal(x, "S") end) )
   
   form.addRow(2)
   form.addLabel({label="Throttle control"})
   form.addInputbox(thrControl, true, (function(x) return changedVal(x, "T") end) )

   form.addRow(2)
   form.addLabel({label="Throttle timer expo"})
   form.addIntbox(timerExp, -100,100,0, 0, 1, (function(x) return changedVal(x, "X") end) )

   form.addRow(2)
   form.addLabel({label="Start/Stop switch"})
   form.addInputbox(startStop, false, (function(x) return changedVal(x, "W") end) )
   
   form.addRow(2)
   form.addLabel({label="Timer Reset switch"})
   form.addInputbox(resetSw, false, (function(x) return changedVal(x, "R") end) )

   form.addRow(2)
   form.addLabel({label="Full throttle announce switch", width=240})
   form.addInputbox(annFull, false, (function(x) return changedVal(x, "F") end) )
   
   form.addRow(2)
   form.addLabel({label="Variable throttle announce switch", width=240})
   form.addInputbox(annVar, false, (function(x) return changedVal(x, "V") end) )      

end

local function loop()
   local swv, swf, swr
   local thrExp
   local thr
   local stopped

   local now = system.getTimeCounter()
   
   local swr = system.getInputsVal(resetSw)
   if swr and swr == 1 and swrLast ~= 1 then
      fTimeT = (startMins*60 + startSecs) * 1000.0
      iTimeT = nil
   end

   local sws = system.getInputsVal(startStop)
   if sws and sws ~= 1 then
      lastfTimeT = now
      stopped = true
   else
      stopped = false
   end
   
   local tt = system.getSwitchInfo(thrControl)
   if not tt or not tt.assigned then
      thr = 1
   else
      thr = tt.value
   end
   
   thrFrc = (thr + 1) / 2

   if not stopped then
      if not lastfTimeT then lastfTimeT = now end
      
      if fTimeT > 0 then
	 fTimeT = fTimeT - thrFrc * (now - lastfTimeT)
      end
      
      if fTimeT < 0 then
	 fTimeT = 0
	 system.playFile("/Apps/DFM-TimV/stopped.wav")
      end
      
      lastfTimeT = now
   end
   
   -- Division will get "inf" if thrFrc == 0, > 99*60 test still works   
   iTimeT = fTimeT / thrFrc
   if iTimeT / 1000.0  > 99*60 then
      iTimeT = 99*60*1000
      greater = ">"
   else
      greater = ""
   end

   swf = system.getInputsVal(annFull)
   if swf and swf == 1 and swfLast ~= 1 and fTimeT > 0 then
      system.playFile("/Apps/DFM-TimV/full.wav")
      local st, mm, ss = tickToMinSec(fTimeT)
      system.playNumber(mm, 0, "min")
      system.playNumber(ss, 0, "s")
   end
   swfLast = swf

   swv = system.getInputsVal(annVar)
   if swv and swv == 1 and swvLast ~= 1 and fTimeT > 0 then
      system.playFile("/Apps/DFM-TimV/variable.wav")
      local st, mm, ss = tickToMinSec(iTimeT)
      system.playNumber(mm, 0, "min")
      system.playNumber(ss, 0, "s")
   end
   swvLast = swv

end

local function timTele()
   local thrExp

   -- leave here in case pilot changes color while running
   
   local bgr, bgg, bgb = lcd.getBgColor()
   if bgr + bgg +bgb > 384 then
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
   
   if thrFrc then
	 thrExp = thrFrc^(throttleExp)
   end
   if thrFrc then lcd.drawNumber(120,42, 100 * thrFrc) end
   if thrExp then lcd.drawNumber(120,10, 100 * thrExp) end   
   if fTimeT then lcd.drawText(25, 0, tickToMinSec(fTimeT), FONT_MAXI) end
   if greater then lcd.drawText( 5,30, greater, FONT_MAXI) end
   if iTimeT then lcd.drawText(25,30, tickToMinSec(iTimeT), FONT_MAXI) end
end

local function init()

   system.registerForm(1, MENU_APPS, "Variable Countdown Timer", initForm)
   system.registerTelemetry(1,"DFM-TimV",2, timTele)

   startMins = system.pLoad("startMins", 5)
   startSecs = system.pLoad("startSecs", 0)
   startStop = system.pLoad("startStop")
   annFull = system.pLoad("annFull")
   annVar = system.pLoad("annVar")
   thrControl = system.pLoad("thrControl")
   timerExp = system.pLoad("timerExp", 0)
   throttleExp = compExp(timerExp)   
   resetSw = system.pLoad("resetSw")
   
   fTimeT = (startMins*60 + startSecs) * 1000.0

   print("DFM-TimV: gcc " .. collectgarbage("count"))

end



return {init=init, loop=loop, author="DFM", version=TimVVersion, name="DFM-TimV"}
