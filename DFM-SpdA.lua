--[[
	---------------------------------------------------------
    SpdAnnouncer makes voice announcement of speed with
    user set intevals when model goes faster or slower
    
    Copied from AltA
    
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

local trans11, spdSwitch, spdSe, spdSeId, spdSePa, maxSpd, VrefSpd, VrefCall
local spdInter = 10
local selFt, mod_spd, oldStep, alt, selFtIndex, selFtSt = false, 0, 0, 0
local shortAnn, shortAnnIndex, shortAnnSt = false

local ovrSpd = false
local aboveVref = false
local old_mod_sec = 0
local old_mod_spd = 0
local last_sgTC = 0

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local DEBUG = true
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

local function spdSwitchChanged(value)
   spdSwitch = value
   system.pSave("spdSwitch", value)
end

local function spdInterChanged(value)
   spdInter = value
   system.pSave("spdInter", value)
end

local function VrefSpdChanged(value)
   VrefSpd = value
   system.pSave("VrefSpd", value)
end

local function VrefCallChanged(value)
   VrefCall = value
   system.pSave("VrefCall", value)
end

local function maxSpdChanged(value)
   maxSpd = value
   system.pSave("maxSpd", value)
end

local function sensorChanged(value)
   spdSe = value
   spdSeId = string.format("%s", sensorIdlist[spdSe])
   spdSePa = string.format("%s", sensorPalist[spdSe])
   if (spdSeId == "...") then
      spdSeId = 0
      spdSePa = 0 
   end
   system.pSave("spdSe", value)
   system.pSave("spdSeId", spdSeId)
   system.pSave("spdSePa", spdSePa)
end

local function selFtClicked(value)
   selFt = not value
   form.setValue(selFtIndex, selFt)
   if(selFt) then
      system.pSave("selFtSt", 1)
   else
      system.pSave("selFtSt", 0)
   end
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   if(shortAnn) then
      system.pSave("shortAnnSt", 1)
   else
      system.pSave("shortAnnSt", 0)
   end
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then
        
      form.addRow(1)
      form.addLabel({label="---         Dave's Jeti Tools       ---",font=FONT_BIG})
      
      form.addRow(2)
      form.addLabel({label="Select Speed Sensor", width=220})
      form.addSelectbox(sensorLalist, spdSe, true, sensorChanged)
      
      form.addRow(2)
      form.addLabel({label="Select Enable Switch", width=220})
      form.addInputbox(spdSwitch, true, spdSwitchChanged) 
      
      form.addRow(2)
      form.addLabel({label="Announce every (mph / km/hr)", width=220})
      form.addIntbox(spdInter, 0, 100, 10, 0, 1, spdInterChanged)
      
      form.addRow(2)
      form.addLabel({label="Vref", width=220})
      form.addIntbox(VrefSpd, 0, 1000, 0, 0, 1, VrefSpdChanged)

      form.addRow(2)
      form.addLabel({label="Call Speed < Vref every (sec)", width=220})
      form.addIntbox(VrefCall, 1, 10, 2, 0, 1, VrefCallChanged)
        
      form.addRow(2)
      form.addLabel({label="Speed Max Warning", width=220})
      form.addIntbox(maxSpd, 0, 10000, 200, 0, 1, maxSpdChanged)
        
      form.addRow(2)
      form.addLabel({label="Use mph (default km/hr)", width=270})
      selFtIndex = form.addCheckbox(selFt, selFtClicked)
      
      form.addRow(2)
      form.addLabel({label="Short Announcement", width=270})
      shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
      
      form.addRow(1)
      form.addLabel({label="Thanks to Tero/RCT. Version "..SpdAnnVersion.." ", font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end
end

--------------------------------------------------------------------------------

local function loop()


   local swi  = system.getInputsVal(spdSwitch)
   local sensor = system.getSensorByID(spdSeId, spdSePa)
   local mod_sec, rem_sec
   local rem_spd -- mod_spd defined at higher scope
   
   if(sensor and sensor.valid) then
      local spd = sensor.value
   else
      if DEBUG then
	 spd = (system.getInputs("P8")+1)*150.0 -- make P8 go from 0 to 300
      else
	 return
      end
   end
   
   if (selft) then
      spd = spd * 0.621371
   end
   if (spd <= maxSpd) then
      ovrSpd = false
   end
   if (spd > maxSpd and not ovrSpd) then
      ovrSpd = true
      system.playFile('overspeed.wav', AUDIO_QUEUE)
      if DEBUG then print("Overspeed!") end
   end
   if (spd > VrefSpd) then
      aboveVref = true
   end
   if (spd <= VrefSpd and aboveVref) then
      aboveVref = false
      system.playFile('V_ref_speed.wav', AUDIO_QUEUE)
      if DEBUG then print("At Vref") end
   end

   if(swi and swi < 1) then
      mod_spd = 0
      old_mod_spd = 0
   end
   if(swi and swi == 1) then
      mod_spd, rem_spd = math.modf(spd / spdInter) -- look at modulo to see if we need to re-announce
      sgTC = system.getTimeCounter()
      mod_sec, rem_sec = math.modf(sgTC/(1000.0*VrefCall))
      if(mod_spd ~= old_mod_spd) or ((mod_sec ~= old_mod_sec) and not aboveVref and spd > VrefSpd/2) then
	 -- if DEBUG then print("spd, mod_spd, rem_spd: ", spd, mod_spd, rem_spd) end
	 old_mod_spd = mod_spd
	 old_mod_sec = mod_sec
	 print( spd, (sgTC - last_sgTC)/1000, VrefCall)
	 if ((sgTC - last_sgTC)/1000 > VrefCall/2) then
	    last_sgTC = sgTC
	    if (selFt) then
	       if(shortAnn or not aboveVref) then
		  system.playNumber(spd, 0, "mph")
		  if DEBUG then  print("speed: ", spd, " mph") end
	       else
		  system.playNumber(spd, 0, "mph", "Speed")
		  if DEBUG then  print("speed: ", spd, " mph") end
	       end
	    else
	       if(shortAnn or not aboveVref) then
		  system.playNumber(spd, 0, "km/h")
		  if DEBUG then  print("speed: ", spd, " km/hr") end
	       else
		  system.playNumber(spd, 0, "km/h", "Speed")
		  if DEBUG then  print("speed: ", spd, " km/hr") end
	       end
	    end
	 end
      end
   end
   collectgarbage()
end
--------------------------------------------------------------------------------
local function init()

   spdSwitch = system.pLoad("spdSwitch")
   spdInter = system.pLoad("spdInter", 0)
   VrefSpd = system.pLoad("VrefSpd", 0)
   VrefCall = system.pLoad("VrefCall", 0)
   maxSpd = system.pLoad("maxSpd", 0)
   spdSe = system.pLoad("spdSe", 0)
   spdSeId = system.pLoad("spdSeId", 0)
   spdSePa = system.pLoad("spdSePa", 0)
   annDnSt = system.pLoad("annDnSt", 0)
   selFtSt = system.pLoad("selFtSt", 0)
   shortAnnSt = system.pLoad("shortAnnSt", 0)

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
   
   if VrefCall == 0 then VrefCall = 2 end
   if VrefSpd == 0 then VrefSpd = 60 end
   if maxSpd == 0 then maxSpd = 200 end
   if spdInter == 0 then spdInter = 10 end
   
      
   system.registerForm(1, MENU_APPS, "Speed Announcer", initForm)
   system.playFile('Spd_ann_act.wav', AUDIO_QUEUE)
   readSensors()
   collectgarbage()
end

--------------------------------------------------------------------------------

SpdAnnVersion = "1.0"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM/RC-Thoughts", version=SpdAnnVersion, name="Speed Announcer"}
