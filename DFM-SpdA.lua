--[[
	---------------------------------------------------------
    SpdAnnouncer makes voice announcement of speed with
    variable intevals when model goes faster or slower
    or on final approach 
    Originally adapted/derived from RCT's AltA
    
    Requires transmitter firmware 4.22 or higher.
    
	---------------------------------------------------------
	Released under MIT-license by DFM 2018
	---------------------------------------------------------
--]]

collectgarbage()

--------------------------------------------------------------------------------

-- Locals for application

local trans11
local spdSwitch
local contSwitch
local spdSe
local spdSeId
local spdSePa
local maxSpd, VrefSpd, VrefCall
local spdInter
local selFt
local selFtIndex
local shortAnn, shortAnnIndex

local ovrSpd = false
local aboveVref = false
local aboveVref_ever = false
local stall_warn=false
local nextAnnTC = 0
local lastAnnTC = 0
local lastAnnSpd = 0
local sgTC
local sgTC0
local airspeedCal
local round_spd
local SpdAnnVersion

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

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
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLalist, sensor.label)
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
      end
   end
end

----------------------------------------------------------------------

-- Actions when settings changed

local function spdSwitchChanged(value)
   spdSwitch = value
   system.pSave("spdSwitch", spdSwitch)
end

local function contSwitchChanged(value)
   contSwitch = value
   system.pSave("contSwitch", contSwitch)
end

local function spdInterChanged(value)
   spdInter = value
   if spdInter == 99 then DEBUG = true end
   if spdInter == 98 then DEBUG = false end
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

local function airCalChanged(value)
   airspeedCal = value
   system.pSave("airspeedCal", value)
end

local function sensorChanged(value)
   spdSe = value
   spdSeId = sensorIdlist[spdSe]
   spdSePa = sensorPalist[spdSe]
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
   system.pSave("selFt", tostring(selFt))
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then
        
      form.addRow(2)
      form.addLabel({label="Select Speed Sensor", width=220})
      form.addSelectbox(sensorLalist, spdSe, true, sensorChanged)
      
      form.addRow(2)
      form.addLabel({label="Select Enable Switch", width=220})
      form.addInputbox(spdSwitch, true, spdSwitchChanged)

      form.addRow(2)
      form.addLabel({label="Select Continuous Ann Switch", width=220})
      form.addInputbox(contSwitch, true, contSwitchChanged)       
      
      form.addRow(2)
      form.addLabel({label="Speed change scale factor", width=220})
      form.addIntbox(spdInter, 1, 100, 10, 0, 1, spdInterChanged)
      
      form.addRow(2)
      form.addLabel({label="Vref (1.3 Vs0)", width=220})
      form.addIntbox(VrefSpd, 0, 1000, 0, 0, 1, VrefSpdChanged)

      form.addRow(2)
      form.addLabel({label="Call Speed < Vref every (sec)", width=220})
      form.addIntbox(VrefCall, 1, 10, 3, 0, 1, VrefCallChanged)
        
      form.addRow(2)
      form.addLabel({label="Speed Max Warning", width=220})
      form.addIntbox(maxSpd, 0, 10000, 200, 0, 1, maxSpdChanged)

      form.addRow(2)
      form.addLabel({label="Airspeed Calibration Multiplier (%)", width=220})
      form.addIntbox(airspeedCal, 1, 200, 100, 0, 1, airCalChanged)
        
      form.addRow(2)
      form.addLabel({label="Use mph or km/hr (x)", width=270})
      selFtIndex = form.addCheckbox(selFt, selFtClicked)
      
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

   local spd
   local speed
   local deltaSA
   local sensor

   local swi  = system.getInputsVal(spdSwitch)
   local swc  = system.getInputsVal(contSwitch)
   
   if (swi and swi < 1) and (swc and swc < 1) then return end
   
   if (spdSeId ~= 0) then
      sensor = system.getSensorByID(spdSeId, spdSePa)
   else
      if not DEBUG then return end
   end

   if (sensor and sensor.valid) then
      speed = sensor.value * airspeedCal/100.
   else
      if DEBUG then
	 spd = (system.getInputs("P8")+1) * 160.0 * airspeedCal / 100. -- make P8 go from 0 to 320
      else
	 return 
      end
   end
   
   
      
   if not DEBUG then
      if selFt then
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
   end

   if maxSpd and (spd <= maxSpd) then ovrSpd = false end

   if (spd > VrefSpd) then
      aboveVref = true
      aboveVref_ever = true
   end

   if (spd > VrefSpd/1.3) then -- re-arm it
      stall_warn = false
   end


   if (swi and swi == 1) or (swc and swc == 1) then
      
      if (spd > maxSpd and not ovrSpd) then
	 ovrSpd = true
	 system.playFile('/Apps/DFM-SpdA/overspeed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("Overspeed!") end
	 system.vibration(true, 3) -- 2x vibrations on right stick
      end

      if (spd <= VrefSpd and aboveVref) then
	 aboveVref = false
	 system.playFile('/Apps/DFM-SpdA/V_ref_speed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("At Vref") end
      end

      if ((spd <= VrefSpd/1.3) and (not stall_warn) and aboveVref_ever) then
	 stall_warn = true
	 system.playFile('/Apps/DFM-SpdA/stall_warning.wav', AUDIO_IMMEDIATE)
	 system.vibration(true, 4) -- 4 short pulses on right stick
	 if DEBUG then print("Stall warning!") end
      end

      -- multiplier is scaled by spdInter, over range of 0.5 to 10 (20:1)
      deltaSA = math.min(math.max(math.abs((spd-lastAnnSpd) / spdInter), 0.5), 10)
      
      nextAnnTC = lastAnnTC + (VrefCall * 1000 * 10 / deltaSA) 

      if (spd <= VrefSpd) or (swc and swc == 1) then -- override if below Vref or cont ann is on
	 nextAnnTC = lastAnnTC + VrefCall * 1000 -- at and below Vref .. ann every VrefCall secs
      end

      if not sgTC0 then sgTC0 = system.getTimeCounter() end
      
      sgTC = system.getTimeCounter()

      if (sgTC > nextAnnTC) and ( (spd > VrefSpd / 4) or (swc and swc == 1) ) then

	 round_spd = math.floor(spd + 0.5)
	 lastAnnSpd = round_spd

	 lastAnnTC = sgTC -- note the time of this announcement
	 
	 local sss = string.format("%.0f", round_spd)
	 if (selFt) then
	    if (shortAnn or not aboveVref or (swc and swc == 1) ) then
	       system.playNumber(round_spd, 0)
	       if DEBUG then
		  print("(s)speed: ", sss, " mph")
		  print("time: ", (sgTC-sgTC0)/1000)
	       end
	    else
	       system.playNumber(round_spd, 0, "mph", "Speed")
	       if DEBUG then
		  print("speed: ", sss, " mph")
		  print("time: ", (sgTC-sgTC0)/1000)		  
	       end
	    end
	 else
	    if (shortAnn or not aboveVref or (swc and swc == 1) ) then
	       system.playNumber(round_spd, 0)
	       if DEBUG then
		  print("(s)speed: ", sss, " km/hr")
		  print("time: ", (sgTC-sgTC0)/1000)
	       end
	    else
	       system.playNumber(round_spd, 0, "km/h", "Speed")
	       if DEBUG then
		  print("speed: ", sss, " km/hr")
		  print("time: ", (sgTC-sgTC0)/1000)
	       end
	    end
	 end
      end
   end
end
--------------------------------------------------------------------------------
local function init()

   spdSwitch = system.pLoad("spdSwitch")
   contSwitch = system.pLoad("contSwitch")
   spdInter = system.pLoad("spdInter", 10)
   VrefSpd = system.pLoad("VrefSpd", 60)
   VrefCall = system.pLoad("VrefCall", 2)
   maxSpd = system.pLoad("maxSpd", 200)
   airspeedCal = system.pLoad("airspeedCal", 100)
   spdSe = system.pLoad("spdSe", 0)
   spdSeId = system.pLoad("spdSeId", 0)
   spdSePa = system.pLoad("spdSePa", 0)
   selFt = system.pLoad("selFt", "true")
   shortAnn = system.pLoad("shortAnn", "false")

   selFt = (selFt == "true") -- can't pSave and pLoad booleans...store as text 
   shortAnn = (shortAnn == "true") -- convert back to boolean here

   system.registerForm(1, MENU_APPS, "Speed Announcer", initForm)
   system.playFile('/Apps/DFM-SpdA/Spd_ann_act.wav', AUDIO_QUEUE)
   readSensors()

end

--------------------------------------------------------------------------------

SpdAnnVersion = "1.6"
setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=SpdAnnVersion, name="Speed Announcer"}
