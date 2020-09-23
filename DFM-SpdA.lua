--[[
    ---------------------------------------------------------
    SpdAnnouncer makes voice announcement of speed with
    variable intevals when model goes faster or slower
    with continuous ann on final approach (below Vref)
    and stall warning at Vref/1.3

    Originally adapted/derived from RCT's AltA
    
    Requires transmitter firmware 4.22 or higher.
    
    ---------------------------------------------------------
    Released under MIT-license by DFM 2018, 2019
    ---------------------------------------------------------

    Version 1.7 - May 14, 2019
      Added "airspeed alive" announcement when above Vref/4 for first time
      Added read of model jsn file to get airspeed cal without using menu
      Announces cal factor if not 100% to infom pilot (note Jeti MSPEED Velicity 
      reading seems to require 90% cal factor .. it reads high compared to all 
      other pitot systems)

    Version 1.8 - May 29, 2019

       Added max time between callouts as settable paramater

    Note: For calibration purposes, pitot speed in mph is 45.504 * sqrt(P) where P 
    is measured in inches of water

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
local maxSpd, VrefSpd, VrefCall, annMaxTime
local Vs0Spd
local spdInter
local unitsIdx
local unitsList={"mph", "km/h", "kt.", "m/s", "ft./s"}
local unitsMult={2.23694, 3.6, 1.94384, 1.0, 3.28084}
local shortAnn, shortAnnIndex

local ovrSpd = false
local aboveVref = false
local aboveVref_ever = false
local stall_warn=false
local airspeedAlive = false
local nextAnnTC = 0
local lastAnnTC = 0
local lastAnnSpd = 0
local calSpd
local sgTC
local sgTC0
local airspeedCal
local round_spd
local SpdAnnVersion

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local modelProps = {}

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

local function Vs0SpdChanged(value)
   Vs0Spd = value
   system.pSave("Vs0Spd", Vs0Spd)
end

local function VrefCallChanged(value)
   VrefCall = value
   system.pSave("VrefCall", VrefCall)
end

local function annMaxTimeChanged(value)
   annMaxTime = value
   system.pSave("annMaxTime", annMaxTime)
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

local function unitsIdxChanged(value)
   print("unitsIdxChanged", value)
   unitsIdx = value
   system.pSave("unitsIdx", unitsIdx)
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
      form.addLabel({label="Reference speed (Vref)", width=220})
      form.addIntbox(VrefSpd, 0, 1000, 0, 0, 1, VrefSpdChanged)

      form.addRow(2)
      form.addLabel({label="Stall speed (Vs0)", width=220})
      form.addIntbox(Vs0Spd, 0, 1000, 0, 0, 1, Vs0SpdChanged)

      form.addRow(2)
      form.addLabel({label="Call Speed < Vref every (sec)", width=220})
      form.addIntbox(VrefCall, 1, 10, 3, 0, 1, VrefCallChanged)

      form.addRow(2)
      form.addLabel({label="Call Speed at least every (sec)", width=220})
      form.addIntbox(annMaxTime, 10, 40, 40, 0, 1, annMaxTimeChanged)
        
      form.addRow(2)
      form.addLabel({label="Speed Max Warning", width=220})
      form.addIntbox(maxSpd, 0, 10000, 200, 0, 1, maxSpdChanged)

      form.addRow(2)
      form.addLabel({label="Airspeed Calibration Multiplier (%)", width=220})
      form.addIntbox(airspeedCal, 1, 200, 100, 0, 1, airCalChanged)
        
      form.addRow(2)
      form.addLabel({label="Select speed units", width=220})
      form.addSelectbox(unitsList, unitsIdx, false, unitsIdxChanged)
      
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
   local sss, uuu

   local swi  = system.getInputsVal(spdSwitch)
   local swc  = system.getInputsVal(contSwitch)
   
   if (swi and swi < 1) and (swc and swc < 1) then return end
   
   if (spdSeId ~= 0) then
      sensor = system.getSensorByID(spdSeId, spdSePa)
   else
      return
   end

   if (sensor and sensor.valid) then
      speed = sensor.value * airspeedCal/100.
   else
      return
   end
      
   spd = speed * unitsMult[unitsIdx] -- getSensorByID always returns native units (m/s)

   calSpd = spd

   if maxSpd and (spd <= maxSpd) then ovrSpd = false end
   
   if (spd > VrefSpd) then
      aboveVref = true
      aboveVref_ever = true
   end

   if (spd > Vs0Spd) then -- re-arm it
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
	 --system.playFile('/Apps/DFM-SpdA/V_ref_speed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("At Vref") end
      end

      if ((spd <= Vs0Spd) and (not stall_warn) and aboveVref_ever) then
	 stall_warn = true
	 system.playFile('/Apps/DFM-SpdA/stall_warning.wav', AUDIO_IMMEDIATE)
	 system.vibration(true, 4) -- 4 short pulses on right stick
	 if DEBUG then print("Stall warning!") end
      end

      if ( (spd > (VrefSpd / 2)) and (not airspeedAlive) ) then
	 airspeedAlive = true
	 system.playFile('/Apps/DFM-SpdA/airspeed_alive.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("Airspeed Alive") end
      end
      
      -- multiplier is scaled by spdInter, over range of 0.5 to 10 (20:1)
      deltaSA = math.min(math.max(math.abs((spd-lastAnnSpd) / spdInter), 0.5), 10)
      
      nextAnnTC = lastAnnTC + math.min(VrefCall * 1000 * 10 / deltaSA, annMaxTime * 1000) 

      if (spd <= VrefSpd) or (swc and swc == 1) then -- override if below Vref or cont ann is on
	 nextAnnTC = lastAnnTC + VrefCall * 1000 -- at and below Vref .. ann every VrefCall secs
      end

      sgTC = system.getTimeCounter()
      if not sgTC0 then sgTC0 = sgTC end
      
      
      -- added isPlayback() so that we don't create a backlog of
      -- messages if it takes longer than VrefCall time to speak the
      -- speed .. was creating a "bow wave" of pending
      -- announcements. Wait till speaking is done, catch it at the
      -- next call to loop()

      if (not system.isPlayback()) and
	 ( (sgTC > nextAnnTC) and
	       ( (spd > VrefSpd / 2) or
		  (swc and swc == 1) ) ) then

	 round_spd = math.floor(spd + 0.5)
	 lastAnnSpd = round_spd

	 lastAnnTC = sgTC -- note the time of this announcement
	 
	 sss = string.format("%.0f", round_spd)
	 uuu = unitsList[unitsIdx]
	 
	 if (shortAnn or not aboveVref or (swc and swc == 1) ) then
	    system.playNumber(round_spd, 0)
	    if DEBUG then
	       print("(s)speed: ", sss)
	       print("time: ", (sgTC-sgTC0)/1000)
	    end
	 else
	    system.playNumber(round_spd, 0, uuu, "Speed")
	    if DEBUG then
	       print("speed: ", sss, uuu)
	       print("time: ", (sgTC-sgTC0)/1000)		  
	    end
	 end
      end -- if (not system...)
   end
end
--------------------------------------------------------------------------------

local function calAirspeed(w,h)
   local u,ss
   if not calSpd then ss = "---" else ss = string.format("%d", math.floor(calSpd + 0.5)) end
   u = unitsList[unitsIdx]
   lcd.drawText(5, 5, ss .. " " .. u .. "     Vs0 " ..Vs0Spd .. u, FONT_BOLD)
end

local function init()

   local fg
   
   spdSwitch   = system.pLoad("spdSwitch")
   contSwitch  = system.pLoad("contSwitch")
   spdInter    = system.pLoad("spdInter", 10)
   VrefSpd     = system.pLoad("VrefSpd", 60)
   Vs0Spd     = system.pLoad("Vs0Spd", 45)   
   VrefCall    = system.pLoad("VrefCall", 2)
   annMaxTime  = system.pLoad("annMaxTime", 40)
   maxSpd      = system.pLoad("maxSpd", 200)
   airspeedCal = system.pLoad("airspeedCal", 100)
   spdSe       = system.pLoad("spdSe", 0)
   spdSeId     = system.pLoad("spdSeId", 0)
   spdSePa     = system.pLoad("spdSePa", 0)
   shortAnn    = system.pLoad("shortAnn", "false")
   unitsIdx    = system.pLoad("unitsIdx", 1)
   
   shortAnn = (shortAnn == "true") -- convert back to boolean here

   -- set default for pitotCal in case no "DFM-model.jsn" file

   modelProps.pitotCal = airspeedCal -- start with the pLoad default
   
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   if fg then
      modelProps=json.decode(fg)
      airspeedCal = modelProps.pitotCal
   end

   system.registerForm(1, MENU_APPS, "Speed Announcer", initForm)

   system.registerTelemetry(1, "Calibrated Airspeed", 1, calAirspeed)

   DEBUG = (select(2,system.getDeviceType()) == 1)-- true if on emulator

   --after adding stall speed announcement don't really need this one anymore...
   --system.playFile('/Apps/DFM-SpdA/Spd_ann_act.wav', AUDIO_QUEUE)
   
   if airspeedCal ~= 100 then
      system.playFile('/Apps/DFM-SpdA/airspeed_cal_factor.wav', AUDIO_QUEUE)
      system.playNumber(airspeedCal, 0, "%")
   end
   
   system.playFile('/Apps/DFM-SpdA/stall_speed_warning_at.wav', AUDIO_QUEUE)
   if DEBUG then
      print("DFM-SpdA playing stall_speed_warning_at.wav")
      print("Vs0Spd, units", Vs0Spd, unitsList[unitsIdx])
   end
   system.playNumber(Vs0Spd, 0, unitsList[unitsIdx])
   
   readSensors()

end

--------------------------------------------------------------------------------

SpdAnnVersion = "2.1"
setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=SpdAnnVersion, name="Speed Announcer"}
