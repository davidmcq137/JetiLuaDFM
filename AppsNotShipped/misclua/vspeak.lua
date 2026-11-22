
-- ############################################################################# 
-- # Vspeak ECU Status converter - Lua application for JETI DC/DS transmitters
-- # Some Lua ideas copied from Jeti and TeroS
-- #
-- # Copyright (c) 2017, Original idea by Thomas Ekdahl (thomas@ekdahl.no) co-developed with Volker Weigt the maker of vspeak hardware.
-- # All rights reserved.
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V1.3 - Xicoy, Kolibri and JetCentral added
-- ############################################################################# 

-- Locals for the application
local statusSensor1In    = 0
local statusSensor1ID    = 0
local statusSensor1Pa    = 0
local VspeakStatus1ID    = 0
local statusSensor2In    = 0
local statusSensor2ID    = 0
local statusSensor2Pa    = 0
local VspeakStatus2ID    = 0

local lang      -- read from file
local status    -- read from file
local Status1Text
local Status2Text

local sensorListID      = {"..."}
local sensorListPa      = {"..."}
local sensorListLa      = {"..."}

local ECUTypeIn         = 1
local ECUTypeA = {
     [1] = 'JetCat',
     [2] = 'Jakadofsky',
     [3] = 'HORNET',
     [4] = 'PBS',
     [5] = 'evoJet',
     [6] = 'KingTech',
     [7] = 'Xicoy_Kolibri',
     [8] = 'JetCentral',
     [9] = 'AMT',
}

--------------------------------------------------------------------
-- Configure language settings
--------------------------------------------------------------------
local function setLanguage()
  local lng  = system.getLocale();
  local file = io.readall("Apps/vspeak/locale.jsn")
  local obj  = json.decode(file)  
  if(obj) then
    lang = obj[lng] or obj[obj.default]
  end
end

--------------------------------------------------------------------
-- Configure turbine status lookup
--------------------------------------------------------------------
local function setStatus()
  local file = io.readall("Apps/vspeak/status.jsn") -- hardcoded for now
  local obj  = json.decode(file)
  if(obj) then
    status = obj[ECUTypeA[ECUTypeIn]]
  end
end

----------------------------------------------------------------------
-- Read available sensors for user to select
local sensors = system.getSensors()
for i,sensor in ipairs(sensors) do
	if (sensor.label ~= "") then
		table.insert(sensorListID,  string.format("%s", sensor.id))
		table.insert(sensorListPa,  string.format("%s", sensor.param))
		table.insert(sensorListLa,  string.format("%s", sensor.label))
	end
end

----------------------------------------------------------------------
-- Store settings when changed by user

local function statusSensor1Changed(value)

    statusSensor1In  = value --The value is local to this function and not global to script, hence it must be set explicitly.

	statusSensor1ID  = string.format("%s", sensorListID[statusSensor1In])
	statusSensor1Pa  = string.format("%s", sensorListPa[statusSensor1In])
	
	if (statusSensor1ID == "...") then
		statusSensor1ID   = 0
		statusSensor1Pa   = 0
	end

	system.pSave("statusSensor1In",  statusSensor1In)	
	system.pSave("statusSensor1ID",  statusSensor1ID)
	system.pSave("statusSensor1Pa",  statusSensor1Pa)
end

local function statusSensor2Changed(value)

    statusSensor2In  = value --The value is local to this function and not global to script, hence it must be set explicitly.

	statusSensor2ID  = string.format("%s", sensorListID[statusSensor2In])
	statusSensor2Pa  = string.format("%s", sensorListPa[statusSensor2In])
	
	if (statusSensor2ID == "...") then
		statusSensor2ID   = 0
		statusSensor2Pa   = 0
	end

	system.pSave("statusSensor2In",  statusSensor2In)	
	system.pSave("statusSensor2ID",  statusSensor2ID)
	system.pSave("statusSensor2Pa",  statusSensor2Pa)
end

local function ECUTypeChanged(value)
    ECUTypeIn  = value --The value is local to this function and not global to script, hence it must be set explicitly.
	system.pSave("ECUTypeIn",  ECUTypeIn)
	setStatus() -- reload statuses if they are changed
end


----------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm(subform)

    form.addRow(2)
    form.addLabel({label=lang.selectECU, width=200})
    form.addSelectbox(ECUTypeA, ECUTypeIn, true, ECUTypeChanged)

    form.addRow(2)
    form.addLabel({label=lang.selectSensor1, width=200})
    form.addSelectbox(sensorListLa, statusSensor1In, true, statusSensor1Changed)

    form.addRow(2)
    form.addLabel({label=lang.selectSensor2, width=200})
    form.addSelectbox(sensorListLa, statusSensor2In, true, statusSensor2Changed)

end


----------------------------------------------------------------------
-- Re-init correct form if navigation buttons are pressed
local function keyPressed(key)
    form.reinit(1)
end

----------------------------------------------------------------------
-- 

local function readsensor(statusSensorID, statusSensorPa)
    local sensor
    local StatusText = "-"

    if (statusSensorID ~= 0) then
        sensor = system.getSensorByID(statusSensorID, statusSensorPa)
        if(sensor and sensor.valid) then
            StatusText = status[string.format("%s", math.floor(sensor.value))];
        end
    end
    return StatusText 
end

local function loop()
    Status1Text = readsensor(statusSensor1ID, statusSensor1Pa)
    Status2Text = readsensor(statusSensor2ID, statusSensor2Pa)
end

----------------------------------------------------------------------
--
local function VspeakStatusWindow1(width, height) 
    if (Status1Text == '-') then
        lcd.drawText(138,0, string.format("%s", Status1Text), FONT_BIG)
    else
        lcd.drawText(7,1, string.format("%s", Status1Text), FONT_BIG)
    end
end

local function VspeakStatusWindow2(width, height) 
    if (Status2Text == '-') then
        lcd.drawText(138,0, string.format("%s", Status2Text), FONT_BIG)
    else
        lcd.drawText(7,1, string.format("%s", Status2Text), FONT_BIG)
    end
end


----------------------------------------------------------------------
-- Application initialization
local function init()

   system.registerForm(1,MENU_APPS,lang.appName, initForm, keyPressed)
   
   statusSensor1In  = system.pLoad("statusSensor1In", 0)
   statusSensor1ID  = system.pLoad("statusSensor1ID", 0)
   statusSensor1Pa  = system.pLoad("statusSensor1Pa", 0)
   statusSensor2In  = system.pLoad("statusSensor2In", 0)
   statusSensor2ID  = system.pLoad("statusSensor2ID", 0)
   statusSensor2Pa  = system.pLoad("statusSensor2Pa", 0)
   ECUTypeIn        = system.pLoad("ECUTypeIn", 1)
   
   if(statusSensor2ID ~= 0) then -- Then we have two turbines, and give the telemetry windows name left and right
      system.registerTelemetry(1,string.format("%s %s", lang.window, lang.left),1,VspeakStatusWindow1)
      system.registerTelemetry(2,string.format("%s %s", lang.window, lang.right),1,VspeakStatusWindow2)
   else
      system.registerTelemetry(1,string.format("%s", lang.window),1,VspeakStatusWindow1)
   end
   
   setStatus()
end

----------------------------------------------------------------------
setLanguage()
return {init=init, loop=loop, author="Thomas Ekdahl - thomas@ekdahl.no", version='1.3', name=lang.appName} 
