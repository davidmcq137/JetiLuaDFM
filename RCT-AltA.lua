--[[
	---------------------------------------------------------
    AltAnnouncer makes voice announcement of altitude with
    by user set intevals when model goes up or up and down.
    
    App is a request for glider-towing.
    
    Requires transmitter firmware 4.22 or higher.
    
    Works in DC/DS-14/16/24
    
    Czech translation by Michal Hutnik
    German translation by Norbert Kolb
	---------------------------------------------------------
	Localisation-file has to be as /Apps/Lang/RCT-AltA.jsn
	---------------------------------------------------------
	AltAnnouncer is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2017
	---------------------------------------------------------
--]]
collectgarbage()
--------------------------------------------------------------------------------
-- Locals for application
local trans11, inter, altSwitch, altSe, altSeId, altSePa, maxAlt, minAlt
local selFt, step, oldStep, alt, selFtIndex, selFtSt = false, 0, 0, 0
local shortAnn, shortAnnIndex, shortAnnSt = false
local annDn, annDnIndex, annDnSt = false
local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
--------------------------------------------------------------------------------
-- Read and set translations
local function setLanguage()
    local lng=system.getLocale()
    local file = io.readall("Apps/Lang/RCT-AltA.jsn")
    local obj = json.decode(file)
    if(obj) then
        trans11 = obj[lng] or obj[obj.default]
    end
end
--------------------------------------------------------------------------------
-- Read available sensors for user to select
local function readSensors()
    local sensors = system.getSensors()
    local format = string.format
    local insert = table.insert
    for i, sensor in ipairs(sensors) do
        if (sensor.label ~= "") then
            insert(sensorLalist, format("%s", sensor.label))
            insert(sensorIdlist, format("%s", sensor.id))
            insert(sensorPalist, format("%s", sensor.param))
        end
    end
end
----------------------------------------------------------------------
-- Actions when settings changed
local function altSwitchChanged(value)
    local pSave = system.pSave
	altSwitch = value
	pSave("altSwitch", value)
end

local function interChanged(value)
    local pSave = system.pSave
	inter = value
	pSave("inter", value)
end

local function minAltChanged(value)
    local pSave = system.pSave
	minAlt = value
	pSave("minAlt", value)
end

local function maxAltChanged(value)
    local pSave = system.pSave
	maxAlt = value
	pSave("maxAlt", value)
end

local function sensorChanged(value)
    local pSave = system.pSave
    local format = string.format
    altSe = value
    altSeId = format("%s", sensorIdlist[altSe])
    altSePa = format("%s", sensorPalist[altSe])
    if (altSeId == "...") then
        altSeId = 0
        altSePa = 0 
    end
    pSave("altSe", value)
    pSave("altSeId", altSeId)
    pSave("altSePa", altSePa)
end

local function annDnClicked(value)
    local pSave = system.pSave
    annDn = not value
    form.setValue(annDnIndex, annDn)
    if(annDn) then
        pSave("annDnSt", 1)
        else
        pSave("annDnSt", 0)
    end
end

local function selFtClicked(value)
    local pSave = system.pSave
    selFt = not value
    form.setValue(selFtIndex, selFt)
    if(selFt) then
        pSave("selFtSt", 1)
        else
        pSave("selFtSt", 0)
    end
end

local function shortAnnClicked(value)
    local pSave = system.pSave
    shortAnn = not value
    form.setValue(shortAnnIndex, shortAnn)
    if(shortAnn) then
        pSave("shortAnnSt", 1)
        else
        pSave("shortAnnSt", 0)
    end
end
--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm()
    local fw = tonumber(string.format("%.2f", system.getVersion()))
    if(fw >= 4.22)then
        local form, addRow, addLabel = form, form.addRow ,form.addLabel
        local addIntbox, addCheckbox = form.addIntbox, form.addCheckbox
        local addSelectbox, addInputbox = form.addSelectbox, form.addInputbox
        
        addRow(1)
        addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})
        
        addRow(2)
        addLabel({label=trans11.altSensor, width=220})
        addSelectbox(sensorLalist, altSe, true, sensorChanged)
        
        addRow(2)
        addLabel({label=trans11.sw, width=220})
        addInputbox(altSwitch, true, altSwitchChanged) 
        
        addRow(2)
        addLabel({label=trans11.inter, width=220})
        addIntbox(inter, -0, 1000, 0, 0, 1, interChanged)
        
        addRow(2)
        addLabel({label=trans11.minAltTr, width=220})
        addIntbox(minAlt, -0, 10000, 0, 0, 1, minAltChanged)
        
        addRow(2)
        addLabel({label=trans11.maxAltTr, width=220})
        addIntbox(maxAlt, -0, 10000, 0, 0, 1, maxAltChanged)
        
        form.addRow(2)
        addLabel({label=trans11.annDn, width=270})
        annDnIndex = addCheckbox(annDn, annDnClicked)
        
        form.addRow(2)
        addLabel({label=trans11.selFeet, width=270})
        selFtIndex = addCheckbox(selFt, selFtClicked)
        
        form.addRow(2)
        addLabel({label=trans11.shortAnn, width=270})
        shortAnnIndex = addCheckbox(shortAnn, shortAnnClicked)
        
        addRow(1)
        addLabel({label="Powered by RC-Thoughts.com - v."..altAnnVersion.." ", font=FONT_MINI, alignRight=true})
        else
        local addRow, addLabel = form.addRow ,form.addLabel
        addRow(1)
        addLabel({label="Please update, min. fw 4.22 required!"})
    end
end
--------------------------------------------------------------------------------
local function loop()
	local swi  = system.getInputsVal(altSwitch)
    local sensor = system.getSensorByID(altSeId, altSePa)
    if(sensor and sensor.valid) then
        local alt = tonumber(string.format("%.0f", sensor.value))
        if(swi and swi < 1) then
            step = 0
            oldStep = 0
        end
        if(swi and swi == 1 and alt >= minAlt and alt <= maxAlt) then
            local step = math.modf(alt / inter)
            if(step > oldStep) then
                oldStep = step
                if(selFt) then
                    if(shortAnn) then
                        system.playNumber(alt, 0, "ft")
                        else
                        system.playNumber(alt, 0, "ft", "Altitude")
                    end
                    else
                    if(shortAnn) then
                        system.playNumber(alt, 0, "m")
                        else
                        system.playNumber(alt, 0, "m", "Altitude")
                    end
                end
            end
            if(annDn and step < oldStep and alt > 1) then
                oldStep = step
                if(selFt) then
                    if(shortAnn) then
                        system.playNumber(alt, 0, "ft")
                        else
                        system.playNumber(alt, 0, "ft", "Altitude")
                    end
                    else
                    if(shortAnn) then
                        system.playNumber(alt, 0, "m")
                        else
                        system.playNumber(alt, 0, "m", "Altitude")
                    end
                end
            end
        end
    end
    collectgarbage()
end
--------------------------------------------------------------------------------
local function init()
    local pLoad = system.pLoad
	altSwitch = pLoad("altSwitch")
    altSwitch2 = pLoad("altSwitch2")
    inter = pLoad("inter", 0)
    minAlt = pLoad("minAlt", 0)
    maxAlt = pLoad("maxAlt", 0)
    altSe = pLoad("altSe", 0)
    altSeId = pLoad("altSeId", 0)
    altSePa = pLoad("altSePa", 0)
    annDnSt = pLoad("annDnSt", 0)
    selFtSt = pLoad("selFtSt", 0)
    shortAnnSt = pLoad("shortAnnSt", 0)
    if(annDnSt == 1) then
        annDn = true
        else
        annDn = false
    end
    if(selFtSt == 1) then
        selFt = true
        else
        selFt = false
    end
    if(shortAnnSt == 1) then
        shortAnn = true
        else
        shortAnn = false
    end
    system.registerForm(1, MENU_APPS, trans11.appName, initForm)
    readSensors()
    collectgarbage()
end
--------------------------------------------------------------------------------
altAnnVersion = "1.7"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="RC-Thoughts", version=altAnnVersion, name=trans11.appName}
