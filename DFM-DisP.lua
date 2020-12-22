--[[

   DFM-DisP.lua

   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - Sept 2020

   Created and tested on DC/DS-24 emulator, tested on DS-24 TX

--]]

local appName = "Control Display"
local appVersion= 0.1
local currSwitchState
local lastSwitchState
local switch
local emFlag

local outputChannel = {}
local gChan

local function switchChanged(value)
   switch = value
   system.pSave("switch", switch)
end

local function gChanChanged(value)
   gChan = value
   system.pSave("gChan", gChan)
end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Switch", width=220})
   form.addInputbox(switch, true, switchChanged)

   form.addRow(2)
   form.addLabel({label="Select Gyro Gain Channel", width=220})
   form.addIntbox(gChan, 1, 24, 1, 0, 1, gChanChanged)
   
   form.addRow(1)
   form.addLabel({label="DFM-DisP.lua Version "..appVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local function loop()

   local now

   currSwitchState= system.getInputsVal(switch)
   now = system.getTimeCounter()

   lastSwitchState = currSwitchState

end

local function telePrint()
   local gg
   print(gChan, "O"..gChan, system.getInputs("O"..gChan)*100)
   print(system.getInputsVal(switch))
   if (gChan > 0) and (system.getInputsVal(switch) == 1) then
      lcd.drawText(5,5,"Gyro gain "..string.format("%d%%", system.getInputs("O"..gChan)*100))
   end
end

local function init()

   local ic
   local ss
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   switch   = system.pLoad("switch")
   gChan    = system.pLoad("gChan", 1)
   print("gChan:", gChan)
   
   system.registerForm(1, MENU_APPS, appName, initForm)
   system.registerTelemetry(1, appName, 1, telePrint)
   locale = system.getLocale()
   
end

return {init=init, loop=loop, author="DFM", version=tostring(appVersion),
	name=appName}
