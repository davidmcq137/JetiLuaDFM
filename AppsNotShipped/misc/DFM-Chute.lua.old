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

local depSwitch, swd
local relSwitch, swr

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local wheelSe
local wheelSeId
local wheelSePa

local doorDelay

local deployIdx, deployControl
local releaseIdx, releaseControl
local doorIdx, doorControl

local modelProps = {}

local nLoop = 0
local appStartTime
local baseLineLPS, loopsPerSecond = 47, 47

local DEBUG = false
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

-- Actions when settings changed

local function depSwitchChanged(value)
   depSwitch = value
   system.pSave("depSwitch", depwitch)
end

local function relSwitchChanged(value)
   relSwitch = value
   system.pSave("relSwitch", relSwitch)
end

local function doorDelayChanged(value)
   doorDelay = value
   system.pSave("doorDelay", value)
end


local function sensorChanged(value)
   wheelSe = value
   wheelSeId = sensorIdlist[wheelSe]
   wheelSePa = sensorPalist[wheelSe]
   if (wheelSeId == "...") then
      wheelSeId = 0
      wheelSePa = 0 
   end
   system.pSave("wheelSe", wheelSe)
   system.pSave("wheelSeId", wheelSeId)
   system.pSave("wheelSePa", wheelSePa)
end



--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then

      form.addRow(2)
      form.addLabel({label="Select Deploy Switch", width=220})
      form.addInputbox(depSwitch, false, depSwitchChanged)

      form.addRow(2)
      form.addLabel({label="Select Release Switch", width=220})
      form.addInputbox(relSwitch, false, relSwitchChanged)

      form.addRow(2)
      form.addLabel({label="Select Wheel Sensor", width=200})
      form.addSelectbox(sensorLalist, wheelSe, true, sensorChanged)

      form.addRow(2)
      form.addLabel({label="Door to Actuation Delay (ms)", width=220})
      form.addIntbox(doorDelay, 100, 1000, 100, 0, 100, doorDelayChanged)
      
      form.addRow(1)
      form.addLabel({label="DFM-Chute.lua Version "..chuteCCVersion.." ", font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end

end


--------------------------------------------------------------------------------

local throttleAuth, brakeAuth, flapAuth, gearAuth, wheelAuth
local swd, swr
local wheelState, wheelCount, lastValid

local function loop()

   local sensor
   
   if not appStartTime then appStartTime = system.getTimeCounter() end
      
   nLoop = nLoop + 1
   if nLoop >= 100 then
      loopsPerSecond = 1000 * nLoop / (system.getTimeCounter() - appStartTime)
      appStartTime = system.getTimeCounter()
      nLoop = 0
      --print("Loops per second:", loopsPerSecond)
   end
   
   -- first read the configuration from the switches that have been assigned

   swd = system.getInputsVal(depSwitch)
   swr = system.getInputsVal(relSwitch)

   --if nLoop == 1 then print("swd, swr:", swd, swr) end

   -- next read the wheel sensor if defined

   if wheelSeId ~= 0 then
      sensor = system.getSensorByID(wheelSeId, wheelSePa)
   end

   if sensor and sensor.valid then
      lastValid = system.getTimeCounter()
      if not wheelState then wheelState = sensor.value end
      if wheelState ~= sensor.value then
	 if not wheelCount then wheelCount = 0 else wheelCount = wheelCount + 1 end
	 print("wheelCount:", wheelCount)
	 wheelState = sensor.value
      end
   end
   
   -- next check all defined "auth" channels
   
   if modelProps.throttleChannel then
      if modelProps.throttleIdle > 0 then
	 throttleAuth = system.getInputs(modelProps.throttleChannel) > modelProps.throttleIdle
      else
	 throttleAuth = system.getInputs(modelProps.throttleChannel) < modelProps.throttleIdle
      end
   else
      throttleAuth = true
   end

   if modelProps.brakeChannel then
      if modelProps.brakeOn > 0 then
	 brakeAuth = system.getInputs(modelProps.brakeChannel) > modelProps.brakeOn
      else
	 brakeAuth = system.getInputs(modelProps.brakeChannel) < modelProps.brakeOn
      end
   else
      brakeAuth = true
   end
   
   if modelProps.flapChannel then
      if modelProps.flapFull > 0 then
	 flapAuth = system.getInputs(modelProps.flapChannel) > modelProps.flapFull
      else
	 flapAuth = system.getInputs(modelProps.flapChannel) < modelProps.flapFull
      end
   else
      flapAuth = true
   end

   if modelProps.gearChannel then
      if modelProps.gearDown > 0 then
	 gearAuth = system.getInputs(modelProps.gearChannel) > modelProps.gearDown
      else
	 gearAuth = system.getInputs(modelProps.gearChannel) < modelProps.gearDown
      end
      if not gearAuth then wheelCount = 0 end
   else
      gearAuth = true
   end

   -- this is just for testing .. need to be replaced with correct logic
   if wheelCount then wheelAuth = wheelCount > 10 else wheelAuth = false end

   -- if no wheel sensor...
   if wheelSeId == 0 then wheelAuth = true end
   
   allAuth = throttleAuth and brakeAuth and flapAuth and gearAuth and wheelAuth and swd == 1

   if not flapAuth then
      if not swr or swr == 1 then
	 releaseControl = 1
      end
   else
      releaseControl = -1
   end
   system.setControl(releaseIdx, releaseControl, 0)
   
   if allAuth then
      if doorControl and doorControl == -1 then
	 doorOpenTime = system.getTimeCounter()
	 system.playFile('/Apps/DFM-Chute/Chute_deploying.wav', AUDIO_QUEUE)	 
	 print("Chute deploying")
      end
      doorControl = 1
   else
      doorControl = -1
      doorOpenTime = nil
   end
   system.setControl(doorIdx, doorControl, 0)

   if doorOpenTime and system.getTimeCounter() - doorOpenTime > doorDelay then
      deployControl = 1
   else
      deployControl = -1
   end
   system.setControl(deployIdx, deployControl, 0)
   
end

local longName = {"ChuteDeploy", "ChuteRelease", "ChuteDoor"}
local shortName = {"C01", "C02", "C03"}

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

local function drawState(x,y,ctl)
   if ctl then lcd.setColor(0, 255, 0) else lcd.setColor(255, 0, 0) end
   lcd.drawImage(x,y+3, (ctl and ":ok" or ":cross") )
   lcd.setColor(0,0,0)
end

local function chuteCB(w,h)

   lcd.drawText(5, 5, "Deploy Switch: ")
   drawState(115,5, swd == 1)

   lcd.drawText(5,20, "Release Switch: ")
   drawState(115, 20, swr == 1)
   
   lcd.drawText(5, 40, "Throttle: ")
   drawState(70, 40, throttleAuth)

   lcd.drawText(5, 55, "Flap: ")
   drawState(70, 55, flapAuth)

   lcd.drawText(5, 70, "Brake: ")
   drawState(70,70, brakeAuth)

   lcd.drawText(5, 85, "Gear: ")
   drawState(70, 85, gearAuth)

   lcd.drawText(5, 105, longName[1] .. " (" .. shortName[1] .. ")")
   drawChan(150, 105, deployControl)
		   
   lcd.drawText(5, 120, longName[2] .. " (" .. shortName[2] .. ")")
   drawChan(150, 120, releaseControl)

   lcd.drawText(5, 135, longName[3] .. " (" .. shortName[3] .. ")")
   drawChan(150, 135, doorControl)

   if wheelSeId ~= 0 then
      if wheelCount then lcd.drawText(195, 5, "Count: " .. wheelCount) else lcd.drawText(195,5,"---") end
   else
      lcd.drawText(195,5, "No Sensor")
   end
   
   
end

local function chute2CB(w,h)
   if wheelSeId ~= 0 then
      if wheelCount then lcd.drawText(5, 5, wheelCount) else lcd.drawText(5,5,"---") end
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

   local fg, text
   
   depSwitch = system.pLoad("depSwitch")
   relSwitch = system.pLoad("relSwitch")
   wheelSe   = system.pLoad("wheelSe", 0)
   wheelSeId = system.pLoad("wheelSeId", 0)
   wheelSePa = system.pLoad("wheelSePa", 0)   
   doorDelay = system.pLoad("doorDelay",100)   

   -- note registerControl #1 reserved for auto throttle .. start at 2
   
   deployIdx  = system.registerControl(2, longName[1], shortName[1])
   releaseIdx = system.registerControl(3, longName[2], shortName[2])
   doorIdx    = system.registerControl(4, longName[3], shortName[3])   

   print("deployIdx:", deployIdx)
   print("releaseIdx:", releaseIdx)
   print("doorIdx:", doorIdx)

   system.registerForm(1, MENU_APPS, "AutoChute Controller", initForm)

   system.registerTelemetry(1, "AutoChute L", 4, chuteCB)
   system.registerTelemetry(2, "AutoChute S", 1, chute2CB)
   
   text = "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_")
   print("readall name:", text)
   fg = io.readall(text)
   print("fg:", fg)
   if fg then modelProps=json.decode(fg) end

   print("modelProps.brakeChannel:", modelProps.brakeChannel)
   
   readSensors()
   

   system.playFile('/Apps/DFM-Chute/Auto_chute_active.wav', AUDIO_QUEUE)
   
end

--------------------------------------------------------------------------------

chuteCCVersion = "0.1"
setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=chuteCCVersion,
	name="Auto Chute Controller"}
