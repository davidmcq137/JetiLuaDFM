--[[

   DFM-SWT.lua

   Requested by H. Curzon. Counts presses on momentary switch. Does
   telemetry announcements for sequences of short presses and pulses a
   virtual function for a long press

   Can count from 1..maxTele short presses, and one long press. Assign
   one telem value to each of the short press counts to announce that
   telemetry value. Assign one virtual function (name "LPF", assigned to
   slot <longPressFunc> ) for long press

   Value t1 controls time limit for sequential pulses being part of same
   count, t2 controls time to wait to define end of pulse train.
 
   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - Sept 2020

   Created and tested on DC/DS-24 emulator, tested on DS-24 TX
   
--]]

local appName = "Short/Long Switch"
local SWTVersion= 0.1
local currSwitchState
local lastSwitchState
local switch
local t1, t2
local emFlag
local ctrlIdx
local lpOffTime = 0

local teleSe
local teleSeId
local teleSePa
local teleSeUn
local teleSeLs

local maxTele = 3
local longPressFunc = 1
local locale

local sensorLalist = { "..." }
local sensorLslist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
local sensorUnlist = { "..." }

local startUp = true
local upTime = 0
local pressCount = 0
local lastUpTime = 0

local function switchChanged(value)
   switch = value
   system.pSave("switch", switch)
end

local function t1Changed(value)
   t1 = value
   system.pSave("t1", t1)
end

local function t2Changed(value)
   t2 = math.max(value, 2*t1)
   system.pSave("t2", t2)
end

local function teleChanged(value, idx)

   teleSe[idx] = value
   teleSeId[idx] = sensorIdlist[value]
   teleSePa[idx] = sensorPalist[value]
   teleSeUn[idx] = sensorUnlist[value]
   teleSeLs[idx] = sensorLslist[value]
   
   if (teleSeId[idx] == "...") then
      teleSeId[idx] = 0
      teleSePa[idx] = 0
   end

   system.pSave("teleSe", teleSe)
   system.pSave("teleSeId", teleSeId)
   system.pSave("teleSePa", teleSePa)
   system.pSave("teleSeUn", teleSeUn)
   system.pSave("teleSeLs", teleSeLs)   

end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Switch", width=220})
   form.addInputbox(switch, true, switchChanged)

   form.addRow(2)
   form.addLabel({label="1 Press Sensor", width=155})
   form.addSelectbox(sensorLalist, teleSe[1], true,
		     (function(x) return teleChanged(x, 1) end) )

   form.addRow(2)
   form.addLabel({label="2 Press Sensor", width=155})
   form.addSelectbox(sensorLalist, teleSe[2], true,
		     (function(x) return teleChanged(x, 2) end) )

   form.addRow(2)
   form.addLabel({label="3 Press Sensor", width=155})
   form.addSelectbox(sensorLalist, teleSe[3], true,
		     (function(x) return teleChanged(x, 3) end) )

   form.addRow(2)
   form.addLabel({label="t1 (ms)"})
   form.addIntbox(t1, 100, 1000, 500, 0, 50, t1Changed)

   form.addRow(2)
   form.addLabel({label="t2 (ms)"})
   form.addIntbox(t2, 200, 2000, 1000, 0, 50, t2Changed)   
   
   form.addRow(1)
   form.addLabel({label="DFM-SWT.lua Version "..SWTVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local dev = ""
local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    dev = sensor.label
	 else
	    table.insert(sensorLalist, dev.."."..sensor.label)
	    table.insert(sensorLslist, sensor.label)	    
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	 end
      end
   end
end

local function loop()

   local now
   local sensor
   
   currSwitchState= system.getInputsVal(switch)
   now = system.getTimeCounter()
   
   if lpOffTime ~= 0 then
      if now > lpOffTime then
	 system.setControl(longPressFunc, -1, 0)
	 lpOffTime = 0
      end
   end
   
   if now - lastUpTime > t2 then
      if pressCount > 0 then
	 if emFlag then print("pressCount:", pressCount) end
	 if pressCount <= maxTele then
	    sensor = system.getSensorByID(teleSeId[pressCount], teleSePa[pressCount])
	    if sensor and sensor.valid then
	       if emFlag then
		  print("ls:", teleSeLs[pressCount])
		  print("playFile: /Voice/"..locale.."/"..teleSeLs[pressCount]..".wav")
		  print("playNumber:", sensor.value, sensor.decimals, sensor.unit)
	       end
	       -- if the wav file exists for this tele name, play it
	       --print("locale:", locale)
	       --print("Ls:", teleSeLs[pressCount])
	       --print("playFile: /Voice/"..locale.."/"..teleSeLs[pressCount]..".wav")
	       system.playFile("/Voice/"..locale.."/"..teleSeLs[pressCount]..".wav",
			       AUDIO_QUEUE)
	       system.playNumber(sensor.value, sensor.decimals, sensor.unit)
	    end
	 end
      end
      lastUpTime = 0
      upTime = 0
      pressCount = 0
   end
   
   if currSwitchState ~= lastSwitchState then
      if currSwitchState == 1 then
	 startUp = false
	 if upTime == 0 then
	    upTime = now
	 end
	 lastUpTime = now
      end
      if currSwitchState == -1 then
	 if now - lastUpTime < t1 then
	    pressCount = pressCount + 1
	    lastUpTime = now
	 else
	    if not startUp then
	       if emFlag then print("long press") end
	       system.setControl(longPressFunc, 1, 0)
	       lpOffTime = now + 100
	    end
	    upTime = 0
	    lastUpTime = 0
	    pressCount = 0
	 end
      end
      lastSwitchState = currSwitchState
   end
end

local function init()

   emFlag = (select(2,system.getDeviceType()) == 1)

   switch   = system.pLoad("switch")
   t1       = system.pLoad("t1", 500)
   t2       = system.pLoad("t2", 1000)   
   teleSe   = system.pLoad("teleSe", {})
   teleSeId = system.pLoad("teleSeId", {})
   teleSePa = system.pLoad("teleSePa", {})
   teleSeUn = system.pLoad("teleSeUn", {})
   teleSeLs = system.pLoad("teleSeLs", {})   
   
   for i=1, maxTele, 1 do
      if not teleSe[i] then
	 teleSe[i] = 0
      end
   end
   
   readSensors()

   ctrlIdx = system.registerControl(longPressFunc, "Long Press", "LPF")

   if ctrlIdx then
      system.setControl(longPressFunc, -1, 0)
      lpOffTime = 0
   else
      print("DFM-SWT: Control not registered")
   end
   
   system.registerForm(1, MENU_APPS, appName, initForm)
   locale = system.getLocale()
   print("DFM-SWT: Locale", locale)
   
end

return {init=init, loop=loop, author="DFM", version=tostring(SWTVersion),
	name=appName}
