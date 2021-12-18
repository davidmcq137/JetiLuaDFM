 --[[
	---------------------------------------------------------
    Warns if a sensor fails to report sensor data
	---------------------------------------------------------
	abdulaziz1@me.com - Abdulaziz Al-Khater
	---------------------------------------------------------
 
 	License: MIT License
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
--]]

local formTable = {["n"] = 0}
local sensorLalist = {"..."}
local sensorIdlist = {"..."}
local sensorPalist = {"..."}

----------------------------------------------------------------------
-- Read available sensors for user to select
local function loadSensors()
	
	local sysSensors = system.getSensors()
	
	for i,sensor in ipairs(sysSensors) do
		
		if (sensor.label ~= "") then
			
			table.insert(sensorLalist, string.format("%s", sensor.label))
			table.insert(sensorIdlist, string.format("%s", sensor.id))
			table.insert(sensorPalist, string.format("%s", sensor.param))
			
		end
		
	end

end

----------------------------------------------------------------------
-- Identify the sensor item by form row
local function idSensor(row)

	if row > 5 then
		local idx = math.floor(row / 5) + 1
		return idx
	else
		return 1
	end
	
end

----------------------------------------------------------------------
-- Save user settings
local function saveSettings()

	for idx = 1, formTable.n do
		local sensorLabel = "sensor" .. tostring(idx)
		
		system.pSave("Entries", formTable.n)
		
		system.pSave(sensorLabel .. "Idx", formTable[idx].sensor) -- The index of the sensor in the sensor list
		system.pSave(sensorLabel .. "Id", formTable[idx].sensorId)
		system.pSave(sensorLabel .. "paramId", formTable[idx].paramId)
		system.pSave(sensorLabel .. "ActiveSw", formTable[idx].activeSw)
		system.pSave(sensorLabel .. "Audio", formTable[idx].audio)
		system.pSave(sensorLabel .. "Repeat", formTable[idx].audioRepeat)
	
	end
	
	collectgarbage()
end

----------------------------------------------------------------------
-- Handle user selection
local function sensorSelected(value)
	
	-- Identify the sensor record to modify
	local idx = idSensor(form.getFocusedRow())
	formTable[idx].sensor = value
	formTable[idx].sensorId = string.format("%s", sensorIdlist[value])
	formTable[idx].paramId = string.format("%s", sensorPalist[value])
	
	saveSettings()
	
end

local function sensorActiveSwChanged(value)
	
	-- Identify the sensor record to modify
	local idx = idSensor(form.getFocusedRow())

	formTable[idx].activeSw = value
	
	
	
end

local function audioChanged(value)

	-- Identify the sensor record to modify
	local idx = idSensor(form.getFocusedRow())
	formTable[idx].audio = value
	
	saveSettings()
	
end

local function repeatClicked(value)
	
	-- Identify the sensor record to modify
	local idx = idSensor(form.getFocusedRow())
	
	if formTable[idx].audioRepeat == 0 then
		
			formTable[idx].audioRepeat = 1
			form.setValue(formTable[idx].repeatCheckBoxIndex, true)
			form.setProperties(formTable[idx].repeat3xIndex, {visible = false})
			
	elseif formTable[idx].audioRepeat == 1 then
		
		formTable[idx].audioRepeat = 3
		form.setValue(formTable[idx].repeatCheckBoxIndex, true)
		form.setProperties(formTable[idx].repeat3xIndex, {visible = true})
		
	elseif formTable[idx].audioRepeat == 3 then
			
		formTable[idx].audioRepeat = 0
		form.setValue(formTable[idx].repeatCheckBoxIndex, false)
		form.setProperties(formTable[idx].repeat3xIndex, {visible = false})
		
	end
		
	saveSettings()
	
end

----------------------------------------------------------------------
-- Add Fields to the form for sensors
local function addSensor()
	
	local newIndex = formTable.n + 1											-- formTable.n is where we store the number of entries
	
	-- Respect the 64 sensor limit
	if newIndex < 15 then
				
		local newSensor = { }
		form.addRow(2)
		newSensor.sensorLabel = "Sensor " .. tostring(newIndex)
		newSensor.repeatCounter = 0
		form.addLabel({label=newSensor.sensorLabel,font=FONT_BOLD})
		newSensor.selectBoxIndex = form.addSelectbox(sensorLalist,1,true, sensorSelected)
		form.setFocusedRow(newSensor.selectBoxIndex)
	
		form.addRow(2)
		form.addLabel({label="Activation"})
		newSensor.activeSwInputIdx = form.addInputbox(newSensor.activeSw, true, sensorActiveSwChanged)
	
		form.addRow(2)
		form.addLabel({label="Audio"})
		newSensor.audioBoxIndex = form.addAudioFilebox("", audioChanged)
	
		form.addRow(3)
		form.addLabel({label="Repeat", width=240})
		newSensor.repeat3xIndex = form.addLabel({label="3x", width=lcd.getTextWidth(FONT_MAXI,"3x")})
		form.setProperties(newSensor.repeat3xIndex, {visible = false})
		newSensor.audioRepeat = 0
		newSensor.repeatCheckBoxIndex = form.addCheckbox(false, repeatClicked)
		

		form.addSpacer(300, 5)
		
		-- Disable the add button at 14 sensors
		if newIndex == 14 then
			form.setButton(1, ":add", DISABLED)
		end
		
		-- Add the sensor rows to the form Table
		formTable[newIndex] = newSensor
		formTable.n = formTable.n + 1
		
		if formTable.n > 1 then
			form.setButton(2, ":delete", ENABLED)
		end
		
		saveSettings()
	end
	
	
	
end

----------------------------------------------------------------------
-- Remove Fields from the form for sensors
local function removeSensor()
	
	if formTable.n > 1 then
		
		local currentFocusIndex = form.getFocusedRow()
		local tableIndex = idSensor(currentFocusIndex)
		local result = form.question(formTable[tableIndex].sensorLabel .. "?",
									 "Are you sure",
								 	 "Stop tracking this sensor:", 0, false, 0)
		if result == 1 then

			formTable[tableIndex] = nil
			-- Shift the indicies after the deleted index down by one.
			for i = (tableIndex + 1), formTable.n do
				formTable[i-1] = formTable[i]
			end
			formTable[formTable.n] = nil
			formTable.n = formTable.n - 1
			
			--Re-enable the add button
			form.setButton(1, ":add", ENABLED)
			
			saveSettings()
			
			form.reinit(1)
		end
	end
	
	collectgarbage()
	
end

----------------------------------------------------------------------
-- Load Saved Table Entry
local function loadSavedEntry(item, idx)	
		
		form.addRow(2)
		
		item.sensorLabel = "Sensor " .. tostring(idx)
		form.addLabel({label=item.sensorLabel,font=FONT_BOLD})

		item.selectBoxIndex = form.addSelectbox(sensorLalist,item.sensor or 1,true, sensorSelected)
		form.setFocusedRow(item.selectBoxIndex)
	
		form.addRow(2)
		form.addLabel({label="Activation"})
		item.activeSwInputIdx = form.addInputbox(item.activeSw, true, sensorActiveSwChanged)
	
		form.addRow(2)
		form.addLabel({label="Audio"})
		item.audioBoxIndex = form.addAudioFilebox(item.audio or "", audioChanged)
	
		form.addRow(3)
		form.addLabel({label="Repeat", width=240})
		item.repeat3xIndex = form.addLabel({label="3x", width=lcd.getTextWidth(FONT_MAXI,"3x")})
		
		if item.audioRepeat == 3 then
			form.setProperties(item.repeat3xIndex, {visible = true})
		else
			form.setProperties(item.repeat3xIndex, {visible = false})
		end

		if (item.audioRepeat == 1 or item.audioRepeat == 3) then
			form.addCheckbox(true, repeatClicked)
		else
			form.addCheckbox(false, repeatClicked)
		end

		form.addSpacer(300, 5)	
	
end


----------------------------------------------------------------------
-- Load Saved Parameters
local function loadParameters()
	
	formTable.n = system.pLoad("Entries", 0)

	
	for i = 1, formTable.n do
		local loadedSensor = {}
		local sensorLabel = "sensor" .. tostring(i)
		
		local sensorIdxKey = sensorLabel .. "Idx"
		
		loadedSensor.sensor = system.pLoad(sensorIdxKey, 0)
		loadedSensor.sensorId = system.pLoad(sensorLabel .. "Id", 0)
		loadedSensor.paramId = system.pLoad(sensorLabel .. "paramId", 0)
		loadedSensor.activeSw = system.pLoad(sensorLabel .. "ActiveSw", nil)
		loadedSensor.audio = system.pLoad(sensorLabel .. "Audio", nil	)
		loadedSensor.audioRepeat = system.pLoad(sensorLabel .. "Repeat", 0)
		
		formTable[i] = loadedSensor
		loadSavedEntry(loadedSensor, i)
		
		-- Disable the delete button if we have only one entry
		if formTable.n < 2 then
			form.setButton(2, ":delete", DISABLED)
		end
		
		-- Disable the add button if we have 14 entries
		if formTable.n == 14 then
			form.setButton(1, ":add", DISABLED)
		end
		
	end
	
	-- Handle first run
	if #formTable == 0 then
		addSensor()
		form.setButton(2, ":delete", DISABLED)
	end
	
end


----------------------------------------------------------------------
-- Form Initialization
local function initForm()
	
	loadSensors()
	form.setButton(1, ":add", ENABLED)
	form.setButton(2, ":delete", ENABLED)
	loadParameters()
		
end

----------------------------------------------------------------------
-- Form keyPressed Function
local function keyPressed(key)
	
	if(key==KEY_1) then
		addSensor()
	elseif(key==KEY_2) then
		removeSensor()
	end
	
end

local function alert(sensor)
	
	if sensor.audio ~= nil then													-- Has an audio file been specified?
	
		-- Play audio file based on chosen repeat conditions
		if sensor.audioRepeat == 1 then
			system.playFile(sensor.audio, AUDIO_QUEUE)
		elseif (sensor.audioRepeat == 3 and sensor.repeatCounter < 3) then
			system.playFile(sensor.audio, AUDIO_QUEUE)
			sensor.repeatCounter = sensor.repeatCounter + 1
		elseif (sensor.audioRepeat == 0 and sensor.repeatCounter < 1) then
			system.playFile(sensor.audio, AUDIO_QUEUE)
			sensor.repeatCounter = sensor.repeatCounter + 1
		end
		
	end
	
end


----------------------------------------------------------------------
-- Loop function is called in regular intervals
local function loop()
	
	-- Get the active switch status for each sensor tracked
	
	for i,item in ipairs(formTable) do
		if item.sensor ~= nil then
			
			local sensorActive = system.getInputsVal(item.activeSw)
			local sensorValue = system.getSensorByID(item.sensorId, item.paramId)
			
			-- Reset the repeat counter if the sensor data is valid
			if sensorValue ~= nil then
				
				if sensorValue.valid then
					item.repeatCounter = 0
				end
				
				-- Alert if sensor tracking is active and sensor data is invalid
				if (sensorValue.valid ~= true and sensorActive == 1) then
					alert(item)
				end
				
			end
			
		end
	end
	
end

----------------------------------------------------------------------
-- Runtime functions, read sensor
local function init(code)
	
	
	loadSensors()
	system.registerForm(1,MENU_APPS,"Sensor Fail Warning",initForm,keyPressed)
	
end

-- Application interface

return {init=init, loop=loop, author="Aziz Al-Khater", version="1.0", name="Sensor Fail Warning"}