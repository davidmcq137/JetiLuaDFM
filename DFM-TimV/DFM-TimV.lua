--[[

   ----------------------------------------------------------------------------
   DFM-TimV.lua released under MIT license by DFM 2022

   Variable Countdown Timer .. or as Harry says "Time Dilation" timer

   ----------------------------------------------------------------------------
   
--]]

local TimVVersion = "0.5"
local appStr = "Variable Countdown Timer"

local savedForm, savedRow

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

local stickToShake
local shakePattern

local countDownSecs
local countDownNext

local thrLimit

local function compExp(timExp)
   local thrExp
   local expFac = 40
   if timExp == 0 then thrExp = 1 end
   if timExp >  0 then thrExp = 1 + timExp/expFac end
   if timExp <  0 then thrExp = expFac / (expFac - timExp) end
   return thrExp
end
      
local function tickToMinSec(tick)
   local ff = tick / 1000.0
   local fm = ff // 60.0
   local fs = math.floor(ff - fm * 60.0)
   local ss = string.format("%d:%02d", fm, fs)
   --if ff > 0 then print(ss, ff, fm, fs) end
   return ss, fm, fs
end

local function changedVal(val, hm)
   local tt
   if hm == "M" then
      startMins = val
      system.pSave("startMins", startMins)
      fTimeT = (startMins*60 + startSecs) * 1000.0
   elseif hm == "S" then
      startSecs = val
      system.pSave("startSecs", startSecs)
      fTimeT = (startMins*60 + startSecs) * 1000.0
   elseif hm == "W" then
      startStop = val
      system.pSave("startStop", startStop)
   elseif hm == "T" then
      tt = system.getSwitchInfo(val)
      if not tt.proportional then
	 system.messageBox("Throttle Control must be proportional")
	 form.reinit(1)
	 return
      end
      print("tt", tt)
      print("tt.mode", tt.mode)
      if tt.mode and string.find(tt.mode, "C") then
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
      print("timerExp, throttleExp set to", timerExp, throttleExp)
      system.pSave("timerExp", timerExp)
   elseif hm == "R" then
      resetSw = val
      system.pSave("resetSw", resetSw)
   elseif hm == "Sts" then
      stickToShake = val
      system.pSave("stickToShake", stickToShake)
   elseif hm == "Sp" then
      shakePattern =  val
      system.pSave("shakePattern", shakePattern)
   elseif hm == "Cd" then
      countDownSecs = val
      system.pSave("countDownSecs", countDownSecs)
   elseif hm == "Tl" then
      thrLimit = val
      system.pSave("thrLimit", thrLimit)
   end
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyPress(key)
   if savedForm and savedForm > 1 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   end
end

local function initForm(sf)

   savedForm = sf
   if not savedRow then savedRow = 1 end
   
   if sf == 1 then
      form.setTitle(appStr)
      
      form.addRow(4)
      form.addLabel({label="Start Mins: ", width=85})
      form.addIntbox(startMins, 0, 99, 10, 0, 1, (function(x) return changedVal(x, "M") end), {width=75} )
      form.addLabel({label="Start Secs: ", width=85})
      form.addIntbox(startSecs, 0, 59, 0, 0, 1, (function(x) return changedVal(x, "S") end), {width=75} )
      
      form.addRow(2)
      form.addLabel({label="Timer settings >>", width=240})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(2)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Throttle settings >>", width=240})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(3)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Announcements and haptics >>", width=240})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))

      if savedRow then form.setFocusedRow(savedRow) end
	 
      form.addRow(1)
      form.addLabel({label="DFM-TimV - version "..TimVVersion.." ", font=FONT_MINI, alignRight=true})

   elseif sf == 2 then
      form.setTitle("Timer Settings")
      form.addRow(2)
      form.addLabel({label="Countdown secs", width=240})
      form.addIntbox(countDownSecs, 0,10, 0, 0, 1, (function(x) return changedVal(x, "Cd") end) )

      form.addRow(2)
      form.addLabel({label="Timer start/stop switch", width=240})
      form.addInputbox(startStop, false, (function(x) return changedVal(x, "W") end) )
      
      form.addRow(2)
      form.addLabel({label="Timer reset switch", width=240})
      form.addInputbox(resetSw, false, (function(x) return changedVal(x, "R") end) )
      form.setFocusedRow(1)

   elseif sf == 3 then
      form.setTitle("Throttle Settings")
      form.addRow(2)
      form.addLabel({label="Throttle control", width=240})
      form.addInputbox(thrControl, true, (function(x) return changedVal(x, "T") end) )
      
      form.addRow(2)
      form.addLabel({label="Throttle timer expo", width=240})
      form.addIntbox(timerExp, -100,100,0, 0, 1, (function(x) return changedVal(x, "X") end) )
      
      form.addRow(2)
      form.addLabel({label="Throttle idle min %", width=240})
      form.addIntbox(thrLimit, 0, 100, 0, 0, 1, (function(x) return changedVal(x, "Tl") end) )
      form.setFocusedRow(1)
   elseif sf == 4 then
      form.setTitle("Announcements and haptics")
      form.addRow(2)
      form.addLabel({label="Variable rate timer (top) ann", width=240})
      form.addInputbox(annFull, false, (function(x) return changedVal(x, "F") end) )
      
      form.addRow(2)
      form.addLabel({label="Variable duration timer (bot) ann", width=260})
      form.addInputbox(annVar, false, (function(x) return changedVal(x, "V") end) )      
      
      form.addRow(2)
      form.addLabel({label="Stick to shake at t=0"})      
      form.addSelectbox({"Left", "Right"}, stickToShake, (function(x) return changedVal(x,"Sts") end) )   
      
      form.addRow(2)
      form.addLabel({label="Stick Shake Pattern"})      
      form.addSelectbox({"None", "Long", "Short", "2xShort", "3xShort"},      
	 shakePattern, true, (function(x) return changedVal(x, "Sp") end) )      
      form.setFocusedRow(1)
   end
end

local function loop()
   local swv, swf, swr
   local thr
   local stopped
   local tt
   local thrFrcE
   
   local now = system.getTimeCounter()
   
   swr = system.getInputsVal(resetSw)
   if swr and swr == 1 and swrLast ~= 1 then
      fTimeT = (startMins*60 + startSecs) * 1000.0
      iTimeT = nil
   end
   swrLast = swr
   
   local sws = system.getInputsVal(startStop)
   if sws and sws ~= 1 then
      lastfTimeT = now
      stopped = true
   else
      stopped = false
   end
      
   tt = system.getSwitchInfo(thrControl)
   if not tt or not tt.assigned then
      thr = 1
   else
      thr = tt.value
   end

   thrFrc = (thr + 1) / 2

   if thrFrc * 100.0 < thrLimit then thrFrc = thrLimit / 100.0 end

   thrFrcE = thrFrc^throttleExp
   
   --print("loop", thrLimit, tt.value, throttleExp, thrFrc, thrFrcE)
   
   if not stopped then
      if not lastfTimeT then lastfTimeT = now end
      
      if fTimeT > 0 then
	 fTimeT = fTimeT - thrFrcE * (now - lastfTimeT)
      end

      if fTimeT < 0 then
	 fTimeT = 0
	 if shakePattern > 1 then
	    system.vibration( (stickToShake == 2), shakePattern - 1)
	 end
	 system.playFile("/Apps/DFM-TimV/stopped.wav")
      end
      
      lastfTimeT = now
   end

   -- Division will get "inf" if thrFrc == 0, > 99*60 test still works

   if fTimeT == 0 and thrFrcE == 0 then
      iTimeT = 0
   else
      iTimeT = fTimeT / thrFrcE
   end

   local tOffset = 0.5
   
   if iTimeT / 1000.0 > countDownSecs + tOffset then
      countDownNext = countDownSecs + tOffset
   end

   if (iTimeT / 1000.0) < countDownNext and countDownNext > tOffset then
      system.playNumber(countDownNext, 0)
      countDownNext = countDownNext - 1
   end

   if iTimeT / 1000.0  > 99*60 then
      iTimeT = 99*60*1000
      greater = ">"
   else
      greater = ""
   end

   swf = system.getInputsVal(annFull)
   if swf and swf == 1 and swfLast ~= 1 and fTimeT > 0 then
      system.playFile("/Apps/DFM-TimV/top_time_remaining.wav")
      local st, mm, ss = tickToMinSec(fTimeT)
      system.playNumber(mm, 0, "min")
      system.playNumber(ss, 0, "s")
   end
   swfLast = swf

   swv = system.getInputsVal(annVar)
   if swv and swv == 1 and swvLast ~= 1 and fTimeT > 0 then
      system.playFile("/Apps/DFM-TimV/bottom_time_remaining.wav")
      local st, mm, ss = tickToMinSec(iTimeT)
      system.playNumber(mm, 0, "min")
      system.playNumber(ss, 0, "s")
   end
   swvLast = swv

end

local function timTele()
   local thrExp

   -- leave here instead of init in case pilot changes color while running
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
   if fTimeT then lcd.drawText(25, -2, tickToMinSec(fTimeT), FONT_MAXI) end
   if greater then lcd.drawText( 5,28, greater, FONT_MAXI) end
   if iTimeT then lcd.drawText(25,28, tickToMinSec(iTimeT), FONT_MAXI) end
end

local function init()

   system.registerForm(1, MENU_APPS, appStr, initForm, keyPress)
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
   stickToShake = system.pLoad("stickToShake", 1)
   shakePattern = system.pLoad("shakePattern", 1)
   countDownSecs = system.pLoad("countDownSecs", 0)
   thrLimit = system.pLoad("thrLimit", 0)

   fTimeT = (startMins*60 + startSecs) * 1000.0

   print("DFM-TimV: gcc " .. collectgarbage("count"))

end

return {init=init, loop=loop, author="DFM", version=TimVVersion, name="DFM-TimV"}
