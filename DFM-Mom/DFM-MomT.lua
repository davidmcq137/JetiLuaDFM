--[[
	---------------------------------------------------------
   Adapted from momentary to toggle program by Tero of RC Thoughts

   Acts as a SR Flip Flop .. one switch turns a channel on, a second switch turns it off
	
   For example, instead of momentary to toggle controlling smoke by saying "smoke" and having each reco of "smoke" 
   change the smoke channel state (toggling) from ON to OFF, you set up "smoke on" and "smoke off" commands so the
   channnel is in a known state
   
	Switch 1 ON-OFF makes Momentary switch 1 to ON
	next time used it will be turned off:
	Switch 1 ON-OFF makes Momentary switch 1 to OFF
	
	Time between changes needs to be min. 2 seconds
	If activating switch is held in ON position app-switch
	will switch state every 2 seconds.
	
	All momentary switches are OFF when model is loaded.
	
	Localisation-file has to be as /Apps/Lang/...
    
    Requires DC/DS-14/16/24 firmware 4.22 or up
	
	French translation courtesy from Daniel Memim
	---------------------------------------------------------
	Momentary application is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2016
	---------------------------------------------------------
        Modified to toggle one channel on and off using two momentaries
	---------------------------------------------------------
	Released under MIT-license by DFM 2018
        
--]]
collectgarbage()
--------------------------------------------------------------------------------
-- Locals for the application
local switch1, switch2, switch3, switch4, switch5
local state1, state2, state3, state4, state5 = 0, 0, 0, 0, 0
local tStamp1, tStamp2, tStamp3, tStamp4, tStamp5 = 0, 0, 0, 0, 0 
--------------------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng=system.getLocale()
    local file = io.readall("Apps/Lang/DFM-MomFF.jsn")
    local obj = json.decode(file)
    if(obj) then
        trans4 = obj[lng] or obj[obj.default]
    end
end
--------------------------------------------------------------------------------
-- Store changed switch selections
local function switch1Changed(value)
	switch1 = value
	system.pSave("switch1",value)
end

local function switch2Changed(value)
	switch2 = value
	system.pSave("switch2",value)
end

local function switch3Changed(value)
	switch3 = value
	system.pSave("switch3",value)
end

local function switch4Changed(value)
	switch4 = value
	system.pSave("switch4",value)
    end

local function switch5Changed(value)
	switch5 = value
	system.pSave("switch5",value)
end
--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm()
	form.addRow(1)
	form.addLabel({label="---         Dave's Jeti Tools          ---",font=FONT_BIG})
	
	form.addRow(2)
	form.addLabel({label=trans4.swi1,font=FONT_NORMAL})
	form.addInputbox(switch1, true, switch1Changed) 
	
	form.addRow(2)
	form.addLabel({label=trans4.swi2,font=FONT_NORMAL})
	form.addInputbox(switch2, true, switch2Changed)
	
	form.addRow(2)
	form.addLabel({label=trans4.swi3,font=FONT_NORMAL})
	form.addInputbox(switch3, true, switch3Changed)
	
	form.addRow(2)
	form.addLabel({label=trans4.swi4,font=FONT_NORMAL})
	form.addInputbox(switch4, true, switch4Changed)
	
--	form.addRow(2)
--	form.addLabel({label=trans4.swi5,font=FONT_NORMAL})
--	form.addInputbox(switch5, true, switch5Changed)
	
	form.addSpacer(100, 10)
	form.addRow(1)
	form.addLabel({label="DFM v."..momtVersion.." ",font=FONT_MINI, alignRight=true})
end
--------------------------------------------------------------------------------
-- Draw latching statuses to application interface
local function printForm()
	lcd.drawText(135,31,trans4.latchSts1,FONT_MINI)
	lcd.drawNumber(205,31, state1, FONT_MINI)
	
--	lcd.drawText(135,53,trans4.latchSts,FONT_MINI)
--	lcd.drawNumber(205,53, state2, FONT_MINI)
	
	lcd.drawText(135,75,trans4.latchSts3,FONT_MINI)
	lcd.drawNumber(205,75, state3, FONT_MINI)
	
--	lcd.drawText(135,97,trans4.latchSts,FONT_MINI)
--	lcd.drawNumber(205,97, state4, FONT_MINI)
	
--	lcd.drawText(135,124,trans4.latchSts,FONT_MINI)
--	lcd.drawNumber(205,124, state5, FONT_MINI)
end
--------------------------------------------------------------------------------
-- Runtime functions, read switches, set latching status and control latching switches (outputs)
local function loop()
	local tStamp = system.getTimeCounter()
	local switch1, switch2, switch3, switch4, switch5  = system.getInputsVal(switch1, switch2, switch3, switch4, switch5)
	
	if (switch1 == 1 and state1 == 0 and tStamp > tStamp1) then
		tStamp1 = tStamp + 2000
		state1 = 1
		system.setControl(3, 1, 0, 0)
	end
	if (switch2 == 1 and state1 == 1 and tStamp > tStamp2) then
		tStamp2 = tStamp + 2000
		state1 = 0
		system.setControl(3, 0, 0, 0)
	end
	--[[
	if (switch2 == 1 and state2 == 0 and tStamp > tStamp2) then
		tStamp2 = tStamp + 2000
		state2 = 1
		system.setControl(4, 1, 0, 0)
	end
	if (switch2 == 1 and state2 == 1 and tStamp > tStamp2) then
		tStamp2 = tStamp + 2000
		state2 = 0
		system.setControl(4, 0, 0, 0)
	end
	--]]
	if (switch3 == 1 and state3 == 0 and tStamp > tStamp3) then
		tStamp3 = tStamp + 2000
		state3 = 1
		system.setControl(4, 1, 0, 0)
	end
	if (switch4 == 1 and state3 == 1 and tStamp > tStamp4) then
		tStamp4 = tStamp + 2000
		state3 = 0
		system.setControl(4, 0, 0, 0)
	end
	--[[
	if (switch4 == 1 and state3 == 0 and tStamp > tStamp4) then
		tStamp4 = tStamp + 2000
		state3 = 1
		system.setControl(6, 1, 0, 0)
	end
	if (switch4 == 1 and state4 == 1 and tStamp > tStamp4) then
		tStamp4 = tStamp + 2000
		state4 = 0
		system.setControl(6, 0, 0, 0)
	end
	if (switch5 == 1 and state5 == 0 and tStamp > tStamp5) then
		tStamp5 = tStamp + 2000
		state5 = 1
		system.setControl(7, 1, 0, 0)
	end
	if (switch5 == 1 and state5 == 1 and tStamp > tStamp5) then
		tStamp5 = tStamp + 2000
		state5 = 0
		system.setControl(7, 0, 0, 0)
	end
	--]]
    collectgarbage()
end
--------------------------------------------------------------------------------
-- Application initialization
local function init()
    local registerForm,registerControl = system.registerForm,system.registerControl
    local pLoad,setControl = system.pLoad, system.setControl
	registerForm(1,MENU_APPS, trans4.appName,initForm, nil,printForm)
	registerControl(3,trans4.latchSw1,trans4.swCntr1)
	--registerControl(4,trans4.latchSw2,trans4.swCntr2)
	registerControl(5,trans4.latchSw3,trans4.swCntr3)
	--registerControl(6,trans4.latchSw4,trans4.swCntr4)
	--registerControl(7,trans4.latchSw5,trans4.swCntr5)
	switch1 = pLoad("switch1")
	switch2 = pLoad("switch2")
	switch3 = pLoad("switch3")
	switch4 = pLoad("switch4")
	switch5 = pLoad("switch5")
	setControl(3, 0, 0, 0)
	--setControl(4, 0, 0, 0)
	setControl(5, 0, 0, 0)
	--setControl(6, 0, 0, 0)
	--setControl(7, 0, 0, 0)
    collectgarbage()
end
--------------------------------------------------------------------------------
momFFVersion = "1.0"
setLanguage()
collectgarbage()
--------------------------------------------------------------------------------
return {init=init, loop=loop, author="DFM", version=momFFVersion, name=trans4.appName}
