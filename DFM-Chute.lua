--[[

----------------------------------------------------------------------------
   DFM-Chute.lua
   
   Manages deployment of a braking parachute with safety features to prevent
   unintended deployment. Inspired by the stand-alone product once produced 
   by Dan Gill
    
   Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------
	Released under MIT-license by DFM 2019
----------------------------------------------------------------------------

--]]

collectgarbage()

--------------------------------------------------------------------------------

-- Locals for application

--local trans11

local chuteCCVersion

local depSwitch, swd -- deploy
local relSwitch, swr -- jettison

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local RPMSe
local RPMSeId
local RPMSePa

local RPMHighLimit
local RPMLowLimit
local MPHHighLimit
local MPHLowLimit
local defaultWheelDia = 6.0 -- inches

local mphLogIdx

local deployHalfFlap
local doorDelay
local testDelay

local deployIdx, deployControl
local jettisonIdx, jettisonControl
local doorIdx, doorControl

local loadOverRide
local deployTest, deployTestStart

local longName = {"ChuteDoor", "ChuteDeploy", "ChuteJettison"}
local shortName = {"C01", "C02", "C03"}

local modelProps = {}

local throttleAuth, brakeAuth, flapAuth, gearAuth, RPMAuth, allAuth, allAuthEver
local flapUpState
local wheelRPM, wheelRPMMax

local nLoop = 0
local appStartTime
local baseLineLPS, loopsPerSecond = 47, 47

local DEBUG
--------------------------------------------------------------------------------

-- Read and set translations

local function setLanguage()
--[[
   local lng=system.getLocale()
   local file = io.readall("Apps/Lang/RCT-SpdA.jsn")
   local obj = json.decode(file)
   if(obj) then
      trans11 = obj[lng] or obj[obj.default]
   end
--]]
end

--------------------------------------------------------------------------------

local function wheelRPM2MPH()
   -- 0.002975 = (pi * 60) / (12 * 5280)
   return (wheelRPM or 0) * (modelProps.wheelDiameter or 0) * 0.002975   
end

local function wheelMPH2RPM(wmph)
   return wmph / ( (modelProps.wheelDiameter or defaultWheelDia) * 0.002975)
end

--------------------------------------------------------------------------------

-- Actions when settings changed

local function depSwitchChanged(value)
   depSwitch = value
   system.pSave("depSwitch", depSwitch)
end

local function relSwitchChanged(value)
   relSwitch = value
   system.pSave("relSwitch", relSwitch)
end


local function testDelayChanged(value)
   testDelay = value
   system.pSave("testDelay", value)
end

local function doorDelayChanged(value)
   doorDelay = value
   system.pSave("doorDelay", value)
end

local function halfFlapChanged(value)
  local dhf
  deployHalfFlap = not value
  form.setValue(halfFlapIndex,deployHalfFlap)
  if deployHalfFlap then dhf = "true" else dhf = "false" end
  system.pSave("deployHalfFlap", dhf)
end

local function MPHHighLimitChanged(value)
   MPHHighLimit = value
   RPMHighLimit = wheelMPH2RPM(value)
   print("rpm high limit set to: ", RPMHighLimit)
   system.pSave("MPHHighLimit", value)
end

local function MPHLowLimitChanged(value)
   MPHLowLimit = value
   RPMLowLimit = wheelMPH2RPM(value)
   print("rpm low limit set to: ", RPMLowLimit)
   system.pSave("MPHLowLimit", value)   
end

local function sensorChanged(value)
   RPMSe = value
   RPMSeId = sensorIdlist[RPMSe]
   RPMSePa = sensorPalist[RPMSe]
   if (RPMSeId == "...") then
      RPMSeId = 0
      RPMSePa = 0 
   end
   system.pSave("RPMSe", RPMSe)
   system.pSave("RPMSeId", RPMSeId)
   system.pSave("RPMSePa", RPMSePa)
end

local function testTerminated()
   deployTest = false
   --system.messageBox("Chute Armed -  Test Terminated")
   form.setButton(2, "Test", ENABLED)
end

local function loadTerminated()
   loadOverRide = false
   --system.messageBox("Chute Armed -  Load Terminated")
   form.setButton(1, "Load", ENABLED)
end


--------------------------------------------------------------------------------

local function keyPressed(key)
   local depSw

   --print("key pressed: ", key)
   if key == KEY_1 then
      if loadOverRide then
	 loadTerminated()
	 return
      end
      
      depSw = system.getInputsVal(depSwitch)

      --print("DepSw: ", depSw)      
      if depSw and depSw == 1 then
        system.messageBox("Cannot load - Deploy Armed")
        loadOverRide = false -- just in case!
      end
      if deployTest then
	 system.messageBox("Cannot load - Test enabled")
	 return
      end
      
      if depSw and depSw == -1 then
        loadOverRide = true
        --system.messageBox("Load Chute")
        form.setButton(1, "Load", HIGHLIGHTED)
      end
      if not depSw then
         system.messageBox("Cannot load - No deploy switch assigned")
      end
   end
   if key == KEY_2 then
      if deployTest then
	 testTerminated()
	 return
      end
      
      depSw = system.getInputsVal(depSwitch)

      --print("DepSw: ", depSw)      
      if depSw and depSw == 1 then
        system.messageBox("Cannot test - Deploy Armed")
        deployTest = false -- just in case!
      end
      if loadOverRide then
	 system.messageBox("Cannot test - Load enabled")
	 return
      end
      if depSw and depSw == -1 then
	 deployTest = true
	 doorOpenTime = system.getTimeCounter()
	 --system.messageBox("Starting Chute Deploy Test")
	 form.setButton(2, "Test", HIGHLIGHTED)
      end
      if not depSw then
         system.messageBox("Cannot test - No deploy switch assigned")
      end
      
      --[[
      if not loadOverRide then
         system.messageBox("Cannot test unless loading")
      else
         system.messageBox("Testing Deploy for " .. testDelay .. " ms")
         deployTestTime = system.getTimeCounter() + testDelay
         deployTest = true
      end
      --]]
   end

end

-- Draw the main form (Application inteface)

local function initForm(subForm)

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then

      if subForm == 1 then
	 form.addRow(2)
	 form.addLink((function() form.reinit(2) end), {label="Load/Test >>"})
	 
	 form.addRow(2)
	 form.addLabel({label="Select Deploy Switch", width=220})
	 form.addInputbox(depSwitch, false, depSwitchChanged)
	 
	 form.addRow(2)
	 form.addLabel({label="Select Jettison Switch", width=220})
	 form.addInputbox(relSwitch, false, relSwitchChanged)
	 
	 form.addRow(2)
	 form.addLabel({label="Select Wheel Sensor", width=200})
	 form.addSelectbox(sensorLalist, RPMSe, true, sensorChanged)
	 
	 form.addRow(2)
	 form.addLabel({label="Door Open to Deploy (ms)", width=220})
	 form.addIntbox(doorDelay, 100, 1000, 100, 0, 100, doorDelayChanged)

	 form.addRow(2)
	 form.addLabel({label="MPH High Limit", width=220})
	 form.addIntbox(MPHHighLimit, 10, 100, 50, 0, 1, MPHHighLimitChanged)

	 form.addRow(2)
	 form.addLabel({label="MPH Low Limit", width=220})
	 form.addIntbox(MPHLowLimit, 10, 100, 40, 0, 1, MPHLowLimitChanged)	 
	 
	 --form.addRow(2)
	 --form.addLabel({label="Jettison Test Time (ms)", width=220})
	 --form.addIntbox(testDelay, 100, 5000, 500, 0, 100, testDelayChanged)
	 
	 form.addRow(2)
	 form.addLabel({label="Deploy Chute at Mid Flap",width=270}) 
	 halfFlapIndex = form.addCheckbox(deployHalfFlap,halfFlapChanged)
	 
	 form.addRow(1)
	 form.addLabel({label="DFM-Chute.lua Version "..chuteCCVersion.." ", font=FONT_MINI, alignRight=true})
      else
	 --form.addLabel({label="Load/Test SubMenu", font=FONT_BIG})
	 form.addLink((function() form.reinit(1) end), {label="<< Back"})
	 form.setButton(1, "Load", ENABLED)
	 form.setButton(2, "Test", ENABLED)
      end
      
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end

end


--------------------------------------------------------------------------------
local function readJSON()

   local text, fg

   text = "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_")
   print("readall name:", text)
   fg = io.readall(text)
   print("fg:", fg)
   if fg then modelProps=json.decode(fg) end

end

local function drawState(x,y,ctl)
   if ctl then lcd.setColor(0, 255, 0) else lcd.setColor(255, 0, 0) end
   lcd.drawImage(x,y+3, (ctl and ":ok" or ":cross") )
   lcd.setColor(0,0,0)
end

local function drawChan(x,y,ctl)
   lcd.setColor(0,0,255)
   if ctl == 1 then
      lcd.drawFilledRectangle(x+48, y+4, 48, 14)
      lcd.drawRectangle(x, y+4, 96, 14)
   else
      lcd.drawFilledRectangle(x, y+4, 48,14)
      lcd.drawRectangle(x, y+4, 96, 14)
   end
   lcd.setColor(0,0,0)
end

local function drawChuteChan(deltaY)

   if loadOverRide then
      lcd.setColor(255,0,0)
      lcd.drawText(150, 90-deltaY, "Chute Loading")
      lcd.setColor(0,0,0)
   end

   if deployTest then
      lcd.setColor(255,0,0)
      lcd.drawText(150, 90-deltaY, "Deploy testing")
      lcd.setColor(0,0,0)
   end

   lcd.drawText(5, 105-deltaY, longName[1] .. " (" .. shortName[1] .. ")")
   drawChan(150, 105-deltaY, doorControl)
		   
   lcd.drawText(5, 120-deltaY, longName[2] .. " (" .. shortName[2] .. ")")
   drawChan(150, 120-deltaY, deployControl)

   lcd.drawText(5, 135-deltaY, longName[3] .. " (" .. shortName[3] .. ")")
   drawChan(150, 135-deltaY, jettisonControl)

end




local function printForm()
   local text, state = form.getButton(1)
   
   if text == "Load" then
      lcd.drawText(5, 30, "Deploy Switch: ")
      drawState(115,30, swd == 1)

      lcd.drawText(5,45, "Jettison Switch: ")
      drawState(115, 45, swr == 1)

      drawChuteChan(40)
   end
end

local function loop()

   local sensor
   local saveAuth
   
   if newJSON then 
      print("Chute: New JSON") 
      readJSON()
      newJSON = false
   end

   if not appStartTime then appStartTime = system.getTimeCounter() end
      
   nLoop = nLoop + 1
   if nLoop >= 100 then
      loopsPerSecond = 1000 * nLoop / (system.getTimeCounter() - appStartTime)
      appStartTime = system.getTimeCounter()
      nLoop = 0
      --print("Loops per second:", loopsPerSecond)
      --print("brakeOn, brakeOff", modelProps.brakeOn, modelProps.brakeOff)
      --print("brake channel:", system.getInputs(modelProps.brakeChannel))
      --print("gear channel:", system.getInputs(modelProps.gearChannel))
      --print("gearUp, gearDown:", modelProps.gearUp, modelProps.gearDown)
   end
   
   -- first read the configuration from the switches that have been assigned

   swd = system.getInputsVal(depSwitch)
   swr = system.getInputsVal(relSwitch) -- rel switch is jettison switch by new nomenclature

   if swd and swd == 1 and loadOverRide then
      loadTerminated()
   end

   if swd and swd == 1 and deployTest then
      testTerminated()
   end

   -- if Load Override is set by pressing button on screen, then force controls to loading position
   -- load is cancelled as soon as chute is armed

   if loadOverRide then
      deployControl = -1
      system.setControl(deployIdx, deployControl, 0)
      jettisonControl = 1
      system.setControl(jettisonIdx, jettisonControl, 0)
      doorControl = 1
      system.setControl(doorIdx, doorControl, 0)
      return
   end

   -- if deploy test mode is set by pressing button on screen, then execute door to deploy seq
   -- test is cancelled as soon as chute is armed

   if deployTest then
      --print("deployTest activated")
      deployControl = -1 -- assume closed until delay runs after door opening

      if swr and swr == 1 then -- special case: jettison control when testing
	 --print("special case")
	 jettisonControl = 1
      else
	 --print("not special case")
	 jettisonControl = -1
      end
      
      system.setControl(jettisonIdx, jettisonControl, 0)
      if doorControl == -1 then
	 --print("Test: Door Opening")
      end
      doorControl = 1
      system.setControl(doorIdx, doorControl, 0)
      if system.getTimeCounter() - doorOpenTime > doorDelay then
	 if deployControl == -1 then
	    --print("Test: Deploying")
	    deployControl = 1
	 end
      end
      system.setControl(deployIdx, deployControl, 0)
      return
   end

   --if nLoop == 1 then print("swd, swr:", swd, swr) end

   -- next read the wheel RPM sensor if defined

   if RPMSeId ~= 0 then
      sensor = system.getSensorByID(RPMSeId, RPMSePa)
   end

   if sensor and sensor.valid then
      wheelRPM = sensor.value
      if not wheelRPMMax or wheelRPM > wheelRPMMax then
	 wheelRPMMax = wheelRPM
      end
   end

   if DEBUG then
      wheelRPM = 2500 * (system.getInputs("P6") + 1)
      if not wheelRPMMax or wheelRPM > wheelRPMMax then
	 wheelRPMMax = wheelRPM
      end
   end

   -- next check all defined "auth" channels
   
   if modelProps.throttleChannel then
      saveAuth = throttleAuth
      if modelProps.throttleIdle > 0 then
	 throttleAuth = system.getInputs(modelProps.throttleChannel) > modelProps.throttleIdle
      else
	 throttleAuth = system.getInputs(modelProps.throttleChannel) < modelProps.throttleIdle
      end
      if throttleAuth and not saveAuth then print("Throttle Auth becoming true") end
   else
      throttleAuth = true
   end

   if modelProps.brakeChannel then
      saveAuth = brakeAuth
      if modelProps.brakeOn > 0 then
	 brakeAuth = system.getInputs(modelProps.brakeChannel) > modelProps.brakeOn
      else
	 brakeAuth = system.getInputs(modelProps.brakeChannel) < modelProps.brakeOn
      end
      if brakeAuth and not saveAuth then print("Brake Auth becoming true") end
   else
      brakeAuth = true
   end
   
   if modelProps.flapChannel then
      saveAuth = flapAuth
      if modelProps.flapFull > 0 then
	 flapAuth = system.getInputs(modelProps.flapChannel) > modelProps.flapFull
      else
	 flapAuth = system.getInputs(modelProps.flapChannel) < modelProps.flapFull
      end
      
      -- next line will authorize deployment at half/takeoff flap .. maybe needs to be a menu option?

      if deployHalfFlap then
         flapAuth = flapAuth or math.abs(system.getInputs(modelProps.flapChannel) - modelProps.flapTakeoff) < 0.05
      end

      if modelProps.flapUp > 0 then
	 flapUpState = system.getInputs(modelProps.flapChannel) > modelProps.flapUp
      else
	 flapUpState = system.getInputs(modelProps.flapChannel) < modelProps.flapUp
      end
      if flapUpState then
	 --if wheelRPMMax then print("resetting wheelRPMMax, was:", wheelRPMMax) end
	 wheelRPMMax = nil -- when flaps are fully up, reset wheel max RPM
	 allAuthEver = false -- when flaps up, reset "have we ever had all auth"
      end
      if flapAuth and not saveAuth then print("Flap auth becoming true") end
   else
      flapAuth = true
   end

   if modelProps.gearChannel then
      saveAuth = gearAuth
      if modelProps.gearDown > 0 then
	 gearAuth = system.getInputs(modelProps.gearChannel) > modelProps.gearDown
      else
	 gearAuth = system.getInputs(modelProps.gearChannel) < modelProps.gearDown
      end
      if gearAuth and not saveAuth then print("Gear auth becoming true") end
   else
      gearAuth = true
   end

   if (RPMSeId ~= 0) or DEBUG then -- if there is an RPM sensor...
      saveAuth = RPMAuth
      --print("wheelRPM:", wheelRPM)
      --print("RPM Limits:", RPMHighLimit, RPMLowLimit)
      --print("wheelRPMMax:", wheelRPMMax)
      
      if wheelRPMMax and (wheelRPMMax > RPMHighLimit) and (wheelRPM < RPMLowLimit) then
	 RPMAuth = true
      else
	 RPMAuth = false
      end
      if RPMAuth and not saveAuth then print("RPMAuth becoming true") end
   else
      RPMAuth = true
   end

   saveAuth = allAuth

   allAuth = throttleAuth and brakeAuth and flapAuth and gearAuth and RPMAuth and swd == 1
   
   if allAuth and not saveAuth then
      allAuthEver = true
      print("AllAuth becoming true")
   end
   
   jettisonControl = -1 -- assume not jettisoning .. this is in case flaps not down
   
   if not flapAuth and allAuthEver then -- jettison if jet. enabled and flaps up after deploy 
   if not swr or swr == 1 then                     
	 jettisonControl = 1
      else
         jettisonControl = -1
      end
   else
      jettisonControl = -1
   end

   system.setControl(jettisonIdx, jettisonControl, 0)
   
   if allAuth then
      if doorControl and doorControl == -1 then
	 doorOpenTime = system.getTimeCounter()
	 system.playFile('/Apps/DFM-Chute/Chute_deploying.wav', AUDIO_QUEUE)	 
	 print("Chute deploying: Door opening")
      end
      doorControl = 1
   else
      if not allAuthEver then 
	 doorControl = -1
	 doorOpenTime = nil
      else
	 doorControl = 1 -- if we have deployed, then retracted flaps, keep door open
      end
   end

   if jettisonControl == 1 then doorControl = 1 end -- force door to stay open if jettisoning
   
   system.setControl(doorIdx, doorControl, 0)

   if doorOpenTime and system.getTimeCounter() - doorOpenTime > doorDelay then
      if deployControl == -1 then print("Chute deploying: Actuating") end
      deployControl = 1
   else
      deployControl = -1
   end
   system.setControl(deployIdx, deployControl, 0)
   
end

local function chuteCB(w,h)

   local text
   
   lcd.drawText(5, 5, "Deploy Switch: ")
   drawState(115,5, swd == 1)

   lcd.drawText(5,20, "Jettison Switch: ")
   drawState(115, 20, swr == 1)
   
   lcd.drawText(5, 40, "Throttle: ")
   drawState(70, 40, throttleAuth)
   lcd.drawText(100, 43,string.format("%+2.1f%%",
				      100 * system.getInputs(modelProps.throttleChannel)),FONT_MINI)
   lcd.drawText(160, 43,string.format("(Idle: %+2.1f", 100 * modelProps.throttleIdle),FONT_MINI)
   lcd.drawText(215, 43,string.format("Full: %+2.1f)", 100 * modelProps.throttleFull),FONT_MINI)

   lcd.drawText(5, 55, "Flap: ")
   drawState(70, 55, flapAuth)
   lcd.drawText(100, 58, string.format("%+2.1f%%",
				       100 * system.getInputs(modelProps.flapChannel)), FONT_MINI)
   lcd.drawText(160, 58, string.format("(Up: %+2.1f", 100 * modelProps.flapUp),FONT_MINI)
   lcd.drawText(215, 58, string.format("Mid: %+2.1f", 100 * modelProps.flapTakeoff),FONT_MINI)
   lcd.drawText(265, 58, string.format("Full: %+2.1f)", 100 * modelProps.flapFull),FONT_MINI)   
   
   lcd.drawText(5, 70, "Brake: ")
   drawState(70,70, brakeAuth)
   lcd.drawText(100, 73, string.format("%+2.1f%%",
				       100 * system.getInputs(modelProps.brakeChannel)), FONT_MINI)
   lcd.drawText(160, 73, string.format("(Off: %+2.1f", 100 * modelProps.brakeOff),FONT_MINI)
   lcd.drawText(215, 73, string.format("On: %+2.1f)", 100 * modelProps.brakeOn),FONT_MINI)
   
   lcd.drawText(5, 85, "Gear: ")
   drawState(70, 85, gearAuth)
   lcd.drawText(100, 88, string.format("%+2.1f%%",
				       100 * system.getInputs(modelProps.gearChannel)), FONT_MINI)
   lcd.drawText(160, 88, string.format("(Up: %+2.1f", 100 * modelProps.gearUp),FONT_MINI)
   lcd.drawText(215, 88, string.format("Dn: %+2.1f)", 100 * modelProps.gearDown),FONT_MINI)

   
   drawChuteChan(0)

   if RPMSeId ~= 0 or DEBUG then
      if RPMAuth then
	 lcd.setColor(0, 255, 0)    -- green
      else
	 if wheelRPMMax and (wheelRPMMax > RPMHighLimit) then
	    lcd.setColor(0,0,255)   -- blue
	 else
	    lcd.setColor(255,0,0)   -- red
	 end
      end

      text = string.format("MPH: %3.1f", (wheelRPM2MPH(wheelRPM or 0)))
      lcd.drawText(195, 5, text)
      lcd.setColor(0,0,0)
      text = string.format("(MPH Hi/Lo: %3.1f, %3.1f)", MPHHighLimit, MPHLowLimit)
      lcd.drawText(195, 25, text, FONT_MINI)
      --text = string.format("MPH Low Limit: %3.1f", (MPHLowLimit))      
      --lcd.drawText(195, 35, text, FONT_MINI)      
   else
      lcd.drawText(195,5, "No RPM Sensor")
   end
   
   
end


local function mphCB()
   return wheelRPM2MPH(), 0
end

local function chute2CB(w,h)
   local ss, mph
   
   if RPMSeId ~= 0 or DEBUG then
      mph = wheelRPM2MPH()
      ss = string.format("Gnd Spd: %d mph", math.floor(mph))
      lcd.drawText(5, 5, ss)
   else
      lcd.drawText(5,5,"No sensor")
   end
end

-- Read available sensors for user to select

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLalist, sensor.label)
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
      end
   end
end


local function init()

   local dhf
   local dev, em
   
   depSwitch = system.pLoad("depSwitch")
   relSwitch = system.pLoad("relSwitch")
   RPMSe   = system.pLoad("RPMSe", 0)
   RPMSeId = system.pLoad("RPMSeId", 0)
   RPMSePa = system.pLoad("RPMSePa", 0)   
   MPHHighLimit = system.pLoad("MPHHighLimit", 40)
   MPHLowLimit = system.pLoad("MPHLowLimit", 30)
   doorDelay = system.pLoad("doorDelay",100)
   testDelay = system.pLoad("testDelay",500)
   dhf = system.pLoad("deployHalfFlap", "false")
   if dhf == "true" then deployHalfFlap = true else deployHalfFlap = false end

   --print("dhf, deployHalfFlap", dhf, deployHalfFlap)
   -- note registerControl #1 reserved for auto throttle .. start at 2
   
   doorIdx  = system.registerControl(2, longName[1], shortName[1])
   deployIdx = system.registerControl(3, longName[2], shortName[2])
   jettisonIdx = system.registerControl(4, longName[3], shortName[3])   

   deployTest = false
   allAuthEver = false
   
   print("deployIdx:", deployIdx)
   print("jettisonIdx:", jettisonIdx)
   print("doorIdx:", doorIdx)

   system.registerForm(1, MENU_APPS, "AutoChute Controller", initForm, keyPressed, printForm)

   system.registerTelemetry(1, "AutoChute Status", 4, chuteCB)
   system.registerTelemetry(2, "AutoChute Sensor", 1, chute2CB)

   readJSON()
   
   if not modelProps.wheelDiameter then modelProps.wheelDiameter = defaultWheelDia end

   print("modelProps.brakeChannel:", modelProps.brakeChannel)
   print("wheel dia: ", modelProps.wheelDiameter)

   RPMHighLimit = wheelMPH2RPM(MPHHighLimit)
   RPMLowLimit = wheelMPH2RPM(MPHLowLimit)
   
   readSensors()

   mphLogIdx = system.registerLogVariable("wheelMPH", "mph", mphCB)
   if not mphLogIdx then print("cannot register log var wheelMPH") end

   dev, em = system.getDeviceType()
   DEBUG = (em == 1)

   --if DEBUG then
   --   for k,v in pairs(_G) do
   --	 print("_G:", k,v)
   --     end
   --end

   system.playFile('/Apps/DFM-Chute/Auto_chute_active.wav', AUDIO_QUEUE)
   
end

--------------------------------------------------------------------------------

chuteCCVersion = "0.4"
setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=chuteCCVersion,
	name="Auto Chute Controller"}
