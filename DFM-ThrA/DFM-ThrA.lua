--[[

   ThrA - throttle announcer. Speaks throttle % when it changes, makes more 
   or less frequent announcements according to parameters set in menu

   Adapted from DFM-SpdA.lua which was
   originally adapted/derived from RCT's AltA
   
   Requires transmitter firmware 4.22 or higher.
   
   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 1.0 - May 26, 2020
   
--]]

-- Locals for application

local thrSwitch
local contSwitch
local annMaxTime
local thrInter
local shortAnn, shortAnnIndex
local nextAnnTC = 0
local lastAnnTC = 0
local lastAnnThrottle = 0
local sgTC
local sgTC0
local roundThr
local ThrAnnVersion
local TrefCall = 2
local lastThr = 0
local sameThr = 0

-- Actions when settings changed

local function thrSwitchChanged(value)
   thrSwitch = value
   system.pSave("thrSwitch", thrSwitch)
end

local function contSwitchChanged(value)
   contSwitch = value
   system.pSave("contSwitch", contSwitch)
end

local function thrInterChanged(value)
   thrInter = value
   system.pSave("thrInter", thrInter)
end

local function annMaxTimeChanged(value)
   annMaxTime = value
   system.pSave("annMaxTime", annMaxTime)
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then
        
      form.addRow(2)
      form.addLabel({label="Select Enable Switch", width=220})
      form.addInputbox(thrSwitch, true, thrSwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Select Continuous Ann Switch", width=220})
      form.addInputbox(contSwitch, true, contSwitchChanged)       
      
      form.addRow(2)
      form.addLabel({label="Throttle change scale factor", width=220})
      form.addIntbox(thrInter, 1, 100, 10, 0, 1, thrInterChanged)
      
      form.addRow(2)
      form.addLabel({label="Max Ann Interval (sec)", width=220})
      form.addIntbox(annMaxTime, 10, 40, 40, 0, 1, annMaxTimeChanged)
      
      form.addRow(2)
      form.addLabel({label="Short Announcements", width=270})
      shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
      
      form.addRow(1)
      form.addLabel({label="DFM-ThrA.lua Version "..ThrAnnVersion.." ",
		     font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end
end

--------------------------------------------------------------------------------

local function loop()

   local thr
   local throttle
   local deltaSA
   local sensor
   local sss, uuu

   local swi  = system.getInputsVal(thrSwitch)
   local swc  = system.getInputsVal(contSwitch)

   if (swi and swi < 1) and (swc and swc < 1) then return end
   
   throttle = 50 * (1 + system.getInputs("P4"))

   if throttle ~= lastThr then -- stick is moving
      lastThr = throttle
      sameThr = 0
      return
   else
      sameThr = sameThr + 1
      if sameThr < 10 then
	 return
      end
   end
   

   if (swi and swi == 1) or (swc and swc == 1) then
      
      -- multiplier is scaled by thrInter, over range of 0.5 to 10 (20:1)
      deltaSA = math.min(math.max(math.abs((throttle-lastAnnThrottle) / thrInter), 0.5), 10)
      
      nextAnnTC = lastAnnTC + math.min(TrefCall * 1000 * 10 / deltaSA, annMaxTime * 1000) 

      if swc and swc == 1 then -- override if cont ann is on
	 nextAnnTC = lastAnnTC + TrefCall * 1000 -- at and below Vref .. ann every TrefCall secs
      end

      sgTC = system.getTimeCounter()
      if not sgTC0 then sgTC0 = sgTC end
      
      -- added isPlayback() so that we don't create a backlog of
      -- messages if it takes longer than TrefCall time
      -- to speak the speed .. was creating a "bow wave" of pending
      -- announcements. Wait till speaking is done, catch
      -- it at the next call to loop()

      if (not system.isPlayback()) and ( (sgTC > nextAnnTC) ) then

	 roundThr = math.floor(throttle + 0.5)
	 lastAnnThrottle = roundThr

	 lastAnnTC = sgTC -- note the time of this announcement
	 
	 sss = string.format("%.0f", roundThr)
	 uuu = "%"
	 
	 if (shortAnn or (swc and swc == 1) ) then
	    system.playNumber(roundThr, 0)
	 else
	    system.playNumber(roundThr, 0, uuu)
	 end
      end -- if (not system...)
   end
end

local function init()

   local fg
   
   thrSwitch   = system.pLoad("thrSwitch")
   contSwitch  = system.pLoad("contSwitch")
   thrInter    = system.pLoad("thrInter", 2)
   annMaxTime  = system.pLoad("annMaxTime", 20)
   shortAnn    = system.pLoad("shortAnn", "false")

   shortAnn = (shortAnn == "true") -- convert back to boolean here

   system.registerForm(1, MENU_APPS, "Throttle Announcer", initForm)

end

ThrAnnVersion = "1.0"

return {init=init, loop=loop, author="DFM", version=ThrAnnVersion, name="Throttle Announcer"}
