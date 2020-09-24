--[[

   DFM-SWT.lua

   Requested by H. Curzon. Counts presses on momentary switch. Can
   announce a telemetry value or pulse a virtual function for
   sequences of counted short presses or one long press.

   Can count from 1..maxPressCount short presses, and one long
   press. Assign one telem value or one virtual function to each of
   the short press counts or the long press to announce that telemetry
   value or pulse that function from -1 to 1 to -1 in 100ms.

   Virtual function is SL1 .. SLN for N short pulses, and SLL for the
   long pulse. After setting up in the DFM-SWT menu, look in the TX
   menu for single voice announcements. Create a new line with "+",
   then when you assign the switch look for the SL* names on the User
   Applications sub-menu.

   Value t1 controls time limit for sequential pulses being part of same
   count, t2 controls time to wait to define end of pulse train.
 
   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - Sept 2020
   Version 0.2 - Sept 2020

   Created and tested on DC/DS-24 emulator, tested on DS-24 TX

--]]

local appName = "Short/Long Switch"
local SWTVersion= 0.2
local currSwitchState
local lastSwitchState
local switch
local t1, t2
local emFlag
local ctrlOffTime = {}
local vCtrl = {}

local teleSe
local teleSeId
local teleSePa
local teleSeUn
local teleSeLs
local teleSeLa

local imperialUnits
local imperialUnitsClicked
local imperialUnitsIndex

local maxPressCount = 3
local pressFunc = {}
local locale

local sensorLalist = { "...", "<Function>" }
local sensorLslist = { "...", "<F>" }
local sensorIdlist = { "...", 0  }
local sensorPalist = { "...", 0  }
local sensorUnlist = { "...", "" }

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

   local ss
   
   if value > 2 then -- a telem sensor
      teleSe[idx] = value
      teleSeId[idx] = sensorIdlist[value]
      teleSePa[idx] = sensorPalist[value]
      teleSeUn[idx] = sensorUnlist[value]
      teleSeLs[idx] = sensorLslist[value]
      
      if (teleSeId[idx] == "...") then
	 teleSeId[idx] = 0
	 teleSePa[idx] = 0
      end

      if vCtrl[idx] ~= 0 then
	 system.unregisterControl(vCtrl[idx])
	 vCtrl[idx] = 0
      end
      
   elseif value == 2 then -- <function>
      teleSe[idx] = value
      vCtrl[idx] = 0
      if idx <= maxPressCount then ss = tostring(idx) else ss = "L" end      
      vCtrl[idx] = system.registerControl(idx, "Press "..ss, "SL"..ss)
      if not vCtrl[idx] then
	 print("DFM-SWT: cannot register control", idx, "Press "..idx, "SW"..idx)
      end
      if vCtrl[idx] ~= 0 then
	 system.setControl(vCtrl[idx], -1, 0)
	 ctrlOffTime[idx] = 0
      else
	 print("DFM-SWT: Control not registered", idx)
      end

   elseif value == 1 then -- "..." unassign
      teleSe[idx] = 0
      if vCtrl[idx] ~= 0 then
	 system.unregisterControl(vCtrl[idx])
	 vCtrl[idx] = 0
      end
   end

   system.pSave("teleSe", teleSe)
   system.pSave("teleSeId", teleSeId)
   system.pSave("teleSePa", teleSePa)
   system.pSave("teleSeUn", teleSeUn)
   system.pSave("teleSeLa", teleSeLa)
   system.pSave("teleSeLs", teleSeLs)
   system.pSave("vCtrl", vCtrl)
   
end

local function imperialUnitsClicked(value)
   imperialUnits = not value
   form.setValue(imperialUnitsIndex, imperialUnits)
   system.pSave("imperialUnits", tostring(imperialUnits))
end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Switch", width=220})
   form.addInputbox(switch, true, switchChanged)

   for i = 1, maxPressCount, 1 do
      form.addRow(2)
      form.addLabel({label=tostring(i) .." Press Sensor/Fcn", width=155})
      form.addSelectbox(sensorLalist, teleSe[i], true,
			(function(x) return teleChanged(x, i) end) )
   end

   form.addRow(2)
   form.addLabel({label="L Press Sensor/Fcn", width=155})
   form.addSelectbox(sensorLalist, teleSe[maxPressCount + 1], true,
		     (function(x) return teleChanged(x, maxPressCount + 1) end) )

   form.addRow(2)
   form.addLabel({label="Imperial or metric (x) units", width=270})
   imperialUnitsIndex = form.addCheckbox(imperialUnits, imperialUnitsClicked)
   
   --form.addRow(2)
   --form.addLabel({label="t1 (ms)"})
   --form.addIntbox(t1, 100, 1000, 500, 0, 50, t1Changed)

   --form.addRow(2)
   --form.addLabel({label="t2 (ms)"})
   --form.addIntbox(t2, 200, 2000, 1000, 0, 50, t2Changed)   
   
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
   --for i, sensor in ipairs(sensorLalist) do
   --   print(i, sensor, "#", sensorLslist[i])
   --end
   
end

local function convertUnits(sv, su)
   if not imperialUnits then
      return sv, su
   else   
      if su == "m" then
	 return 3.2808 * sv, "ft."
      elseif su == "m/s" then
	 return 3.2808 * sv, "ft/s"
      elseif su == "km/h" then
	 return 0.6214 * sv , "mph"
      else
	 return sv, su
      end
   end
end

-- °C
local function pressAction(pC)

   local now
   local value, unit
   local fn
   
   --print("pA: pC, teleSe, vCtrl", pC, teleSe[pC], vCtrl[pC])

   now = system.getTimeCounter()
   if teleSe[pC] > 2 then -- telemetry channel selected
      sensor = system.getSensorByID(teleSeId[pC], teleSePa[pC])

      if sensor and sensor.valid then
	 local degC =  "°C"
	 --if sensor.unit == degC then print("deg c", pC) end
	 value, unit = convertUnits(sensor.value, sensor.unit)
	 --if unit == degC then print("deg c", pC) end
	 fn = "/Apps/DFM-SWT/"..string.gsub(teleSeLs[pC], " ", "_")..".wav"
	 print("teleSeLs[pC], fn:", teleSeLs[pC], fn, value, unit)
	 if emFlag then
	    print("playFile:", fn)
	    print("playNumber:", value, sensor.decimals, unit)
	 end
	 system.playFile(fn, AUDIO_QUEUE)
	 system.playNumber(value, sensor.decimals, unit)
      end
   elseif teleSe[pC] == 2 then -- channel selected
      system.setControl(vCtrl[pC], 1, 0)
      ctrlOffTime[pC] = now + 100
   else
      print("DFM-SWT: Nothing set on pressAction - pC = ", pC)
   end

end

local function loop()

   local now
   local sensor
   
   currSwitchState= system.getInputsVal(switch)
   now = system.getTimeCounter()

   for i=1, maxPressCount+1 do
      if ctrlOffTime[i] and ctrlOffTime[i] ~= 0 then
	 if now > ctrlOffTime[i] then
	    system.setControl(vCtrl[i], -1, 0)
	    ctrlOffTime[i] = 0
	 end
      end
   end
   
   if now - lastUpTime > t2 then -- N presses done
      if pressCount > 0 then
	 if emFlag then print("pressCount:", pressCount) end
	 if pressCount <= maxPressCount then
	    pressAction(pressCount)
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
	       if emFlag then print("Long press") end
	       pressAction(maxPressCount + 1)
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

   local ic
   local ss
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   switch   = system.pLoad("switch")
   t1       = system.pLoad("t1",      300)
   t2       = system.pLoad("t2",      600)   
   teleSe   = system.pLoad("teleSe",   {})
   teleSeId = system.pLoad("teleSeId", {})
   teleSePa = system.pLoad("teleSePa", {})
   teleSeUn = system.pLoad("teleSeUn", {})
   teleSeLs = system.pLoad("teleSeLs", {})
   teleSeLa = system.pLoad("teleSeLa", {})      
   vCtrl    = system.pLoad("vCtrl",    {})

   imperialUnits = system.pLoad("imperialUnits", "true")
   
   imperialUnits = (imperialUnits == "true") -- convert back to boolean here
			   
   --make sure no nil entries in tables .. will cause problems on save/restore
   
   for i=1, maxPressCount + 1, 1 do
      if not teleSe[i] then
	 teleSe[i] = 0
      end
      if not teleSeId[i] then
	 teleSeId[i] = 0
      end
      if not teleSePa[i] then
	 teleSePa[i] = 0
      end
      if not teleSeUn[i] then
	 teleSeUn[i] = ""
      end
      if not teleSeLs[i] then
	 teleSeLs[i] = ""
      end
      if not teleSeLa[i] then
	 teleSeLa[i] = ""
      end
      if not vCtrl[i] then
	 vCtrl[i] = 0
      end
   end

   for i=1, maxPressCount+1, 1 do
      if vCtrl[i] ~= 0 then
	 if i <= maxPressCount then ss = tostring(i) else ss = "L" end
	 ic = system.registerControl(vCtrl[i], "Press "..ss, "SL"..ss)
	 if ic ~= i then print("ic ~= i??", ic, i) end
	 if ic then
	    system.setControl(vCtrl[i], -1, 0)
	    ctrlOffTime[i] = 0
	 else
	    print("DFM-SWT: Control not registered", vCtrl[i])
	 end
      end
   end
         
   readSensors()
   
   system.registerForm(1, MENU_APPS, appName, initForm)
   locale = system.getLocale()
   
end

return {init=init, loop=loop, author="DFM", version=tostring(SWTVersion),
	name=appName}
