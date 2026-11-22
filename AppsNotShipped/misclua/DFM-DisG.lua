--[[

   DFM-DisG.lua

   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - Sept 2020

   Created and tested on DC/DS-24 emulator, tested on DS-24 TX

--]]

local appName = "Gyro Display"
local appVersion= 0.1

local switch
local emFlag
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
   form.addLabel({label="Select Gyro on/off Switch", width=220})
   form.addInputbox(switch, true, switchChanged)

   form.addRow(2)
   form.addLabel({label="Select Gyro Gain Channel", width=220})
   form.addIntbox(gChan, 1, 24, 1, 0, 1, gChanChanged)
   
   form.addRow(1)
   form.addLabel({label="DFM-DisG.lua Version "..appVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local function telePrint()
   if (gChan > 0) and (system.getInputsVal(switch) == 1) then
      lcd.drawText(5,0,"Gyro gain "..string.format("%d%%", system.getInputs("O"..gChan)*100))
   end
end

local function init()

   emFlag = (select(2,system.getDeviceType()) == 1)

   switch   = system.pLoad("switch")
   gChan    = system.pLoad("gChan", 1)
   
   system.registerForm(1, MENU_APPS, appName, initForm)
   system.registerTelemetry(1, appName, 1, telePrint)
   
end

return {init=init, loop=nil, author="DFM", version=tostring(appVersion), name=appName}
