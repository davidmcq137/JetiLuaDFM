--[[
	---------------------------------------------------------
    SpdAnnouncer makes voice announcement of speed with
    user set intevals when model goes faster or slower
    
    Adapted/derived from RCT's AltA
    
    Requires transmitter firmware 4.22 or higher.
    
	---------------------------------------------------------
	Released under MIT-license by DFM 2018
	---------------------------------------------------------
--]]

collectgarbage()

--------------------------------------------------------------------------------

-- Locals for application

local trans11, spdSwitch, spdSe
local spdSeId = 0
local spdSePa
local maxSpd, VrefSpd, VrefCall
local spdInter = 10
local selFt, selFtSt, mod_spd, oldStep = true, 1, 0, 0
local selFtIndex
local shortAnn, shortAnnIndex, shortAnnSt = false

local ovrSpd = false
local aboveVref = false
local aboveVref_ever = false
local stall_warn=false
local old_mod_sec = 0
local old_mod_spd = 0
local last_sgTC = 0
local pending_spd = 0

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

-- Locals for loop timing

local lastLoopTime = 0
local avgLoopTime = 0
local loopCount = 0

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

-- Read available sensors for user to select

local function readSensors()
   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLalist, string.format("%s", sensor.label))
	 table.insert(sensorIdlist, string.format("%s", sensor.id))
	 table.insert(sensorPalist, string.format("%s", sensor.param))
      end
   end
end

----------------------------------------------------------------------

-- Actions when settings changed

local function spdSwitchChanged(value)
   spdSwitch = value
   system.pSave("spdSwitch", spdSwitch)
end

local function spdInterChanged(value)
   spdInter = value
   if spdInter == 99 then DEBUG = true end
   if spdInter == 0  then DEBUG = false end
   system.pSave("spdInter", spdInter)
end

local function VrefSpdChanged(value)
   VrefSpd = value
   system.pSave("VrefSpd", VrefSpd)
end

local function VrefCallChanged(value)
   VrefCall = value
   system.pSave("VrefCall", VrefCall)
end

local function maxSpdChanged(value)
   maxSpd = value
   system.pSave("maxSpd", maxSpd)
end

local function sensorChanged(value)
   spdSe = value
   spdSeId = string.format("%s", sensorIdlist[spdSe])
   spdSePa = string.format("%s", sensorPalist[spdSe])
   if (spdSeId == "...") then
      spdSeId = 0
      spdSePa = 0 
   end
   system.pSave("spdSe", spdSe)
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
      form.addLabel({label="---           Dave's Jeti Tools         ---",font=FONT_BIG})
      
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
      form.addLabel({label="Vref (1.3 Vs0)", width=220})
      form.addIntbox(VrefSpd, 0, 1000, 0, 0, 1, VrefSpdChanged)

      form.addRow(2)
      form.addLabel({label="Call Speed < Vref every (sec)", width=220})
      form.addIntbox(VrefCall, 1, 10, 2, 0, 1, VrefCallChanged)
        
      form.addRow(2)
      form.addLabel({label="Speed Max Warning", width=220})
      form.addIntbox(maxSpd, 0, 10000, 200, 0, 1, maxSpdChanged)
        
      form.addRow(2)
      form.addLabel({label="Use km/hr (default mph)", width=270})
      selFtIndex = form.addCheckbox(not selFt, selFtClicked)
      
      form.addRow(2)
      form.addLabel({label="Short Announcement", width=270})
      shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
      
      form.addRow(1)
      form.addLabel({label="DFM-SpdA.lua Version "..SpdAnnVersion.." ", font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end
end

--------------------------------------------------------------------------------

local function loop()

   local mod_sec, rem_sec
   local rem_spd -- mod_spd defined at higher scope
   local mult
   local spd
   local speed
	 

   local swi  = system.getInputsVal(spdSwitch)
   if swi and swi < 1 then return end
   
   local sensor
   if (spdSeId ~= 0) then
      sensor = system.getSensorByID(spdSeId, spdSePa)
   else
      if not DEBUG then return end
   end

    --[[   
   loopCount = loopCount + 1
   if loopCount > 100 then
      loopCount = 0
      print("swi, VrefSpd, selFt: ", swi, VrefSpd, selFt)
      if sensor then
	 print("sensor.value: , sensor.valid", sensor.value, sensor.valid)
	 print("sensor.label, sensor.type, sensor.name, sensor.unit: ", sensor.label, sensor.type, sensor.name, sensor.unit) 
      else
	 print("no sensor selected")
	 return
      end
   end
--]]     

   
   if(sensor and sensor.valid) then
      speed = sensor.value
   else
      if DEBUG then
	 speed = (system.getInputs("P8")+1)*160.0 -- make P8 go from 0 to 320
      else
	 return 
      end
   end

   if (selFt) then
      if sensor.unit == "m/s" then
	 spd = speed * 2.23694 -- m/s to mph
      end
      if sensor.unit == "kmh" or sensor.unit == "km/h" then
	 spd = speed * 0.621371 -- km/hr to mph
      end
   else
      if sensor.unit == "m/s" then
	 spd = speed * 3.6 -- km/hr
      end
   end
   
   if maxspd and (spd <= maxSpd) then
      ovrSpd = false
   end
   if (spd > VrefSpd) then
      aboveVref = true
      aboveVref_ever = true
   end
   if (spd > VrefSpd/1.3) then -- re-arm it
      stall_warn = false
   end


   if(swi and swi < 1) then
      mod_spd = 0
      old_mod_spd = 0
   end

   if (swi and swi == 1) and (spd > VrefSpd / 4) then

      if (spd > maxSpd and not ovrSpd) then
	 ovrSpd = true
	 system.playFile('overspeed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("Overspeed!") end
	 system.vibration(true, 3) -- 2x vibrations on right stick
      end
      if (spd <= VrefSpd and aboveVref) then
	 aboveVref = false
	 system.playFile('V_ref_speed.wav', AUDIO_QUEUE)
	 if DEBUG then print("At Vref") end
      end
      if ((spd <= VrefSpd/1.3) and (not stall_warn) and aboveVref_ever) then
	 stall_warn = true
	 system.playFile('stall_warning.wav', AUDIO_IMMEDIATE)
	 system.vibration(true, 4) -- 4 short pulses on right stick
	 if DEBUG then print("Stall warning!") end
      end
 

      if spdInter ~= 0 then
	 mod_spd, rem_spd = math.modf(spd / spdInter) -- look at modulo to see if we need to re-announce
      end
      
      sgTC = system.getTimeCounter()
      mod_sec, rem_sec = math.modf(sgTC/(1000.0*VrefCall))

      --[[ 
        announce speed if: speed changes by "every" parameter (e.g. 10 mph) -- using modf on speed
                    or if: speed is below Vref, then for every "callout" time interval (e.g. 2 sec) -- using modf on time
        do not announce speed if below Vref/4
        always announce overspeed (e.g. 200 mph) and crossing Vref going down in speed (e.g. 60-59 mph)
      --]]
      
      if( (mod_spd ~= old_mod_spd) or (pending_spd > 0) or ((mod_sec ~= old_mod_sec) and (not aboveVref)) ) then

	 old_mod_sec = mod_sec
	 old_mod_spd = mod_spd
	 
	 -- if pending_spd > 0  then print("Pending_spd: ", pending_spd) end

	 -- if DEBUG then print("spd, mod_spd, rem_spd, old_mod_spd: ", spd, mod_spd, rem_spd, old_mod_spd) end

	 -- if DEBUG then print( spd, (sgTC - last_sgTC)/1000., VrefSpd, aboveVref) end
	 if aboveVref then mult = 1.5 else mult = 0.5 end
	 if (((sgTC - last_sgTC)/1000.> VrefCall*mult)) then -- min time interval even if alt changes

	    pending_spd = 0
	    old_mod_spd = mod_spd -- need this?
	    last_sgTC = sgTC
	    round_spd = math.floor(spd + 0.5)

	    local sss = string.format("%.0f", round_spd)
	    if (selFt) then
	       if(shortAnn or not aboveVref) then
		  system.playNumber(round_spd, 0)
		  if DEBUG then  print("(s)speed: ", sss, " mph") end
	       else
		  system.playNumber(round_spd, 0, "mph", "Speed")
		  if DEBUG then  print("speed: ", sss, " mph") end
	       end
	    else
	       if(shortAnn or not aboveVref) then
		  system.playNumber(round_spd, 0)
		  if DEBUG then  print("(s)speed: ", sss, " km/hr") end
	       else
		  system.playNumber(round_spd, 0, "km/h", "Speed")
		  if DEBUG then  print("speed: ", sss, " km/hr") end
	       end
	    end
	 else -- (sgTC - last_sgTC)
	    if aboveVref then pending_spd = spd end
	 end
      end
   end

--[[
   local newLoopTime = system.getTimeCounter()
   local loopDelta = newLoopTime - lastLoopTime
   lastLoopTime = newLoopTime
   if avgLoopTime ~=0 then
      avgLoopTime = avgLoopTime * 0.95 + 0.05* loopDelta
   else
      avgLoopTime = 1
   end
   loopCount = loopCount+1
   if loopCount > 100 then
      loopCount = 0
      print('SpdAnn: Avg Loop Time: ', avgLoopTime)
   end
--]]

   -- collectgarbage()
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
   selFtSt = system.pLoad("selFtSt", 1)
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

SpdAnnVersion = "1.1"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=SpdAnnVersion, name="Speed Announcer"}
