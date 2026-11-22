--[[
	---------------------------------------------------------
    "Super timer" - calls 30 second intervals with time from gear
    retract and fuel capacity remaining
    
    Derived from Spd Announcer, which in turn was derived from RCT's Alt Announcer
    
    Requires transmitter firmware 4.22 or higher.
    
    Works in DC/DS-14/16/24
    
	---------------------------------------------------------
	Localisation-file has to be as /Apps/Lang/RCT-TimA.jsn
	---------------------------------------------------------
	Derived from AltAnnouncer - a part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	AltAnnouncer released under MIT-license by Tero @ RC-Thoughts.com 2017
	---------------------------------------------------------
--]]
collectgarbage()
--------------------------------------------------------------------------------
-- Locals for application
local trans11
local gearSwitch
local thrControl
local TimSe, TimSeId, TimSePa
local shortAnn, shortAnnIndex, shortAnnSt = false

local oldswi = 0
local old_mod_sec = 0
local running_time = 0
local next_ann_time = 0
local start_time = 0
local fuel_pct

local ytable = {}
local mrs = math.random(1,59) -- if needed to create fake debug data
local DEBUG = false -- if set to <true> will print to console the speech files and output


local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
--------------------------------------------------------------------------------
-- Read and set translations
local function setLanguage()
    local lng=system.getLocale()
    local file = io.readall("Apps/Lang/DFM-TimA.jsn")
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

local function gearSwitchChanged(value)
    local pSave = system.pSave
	gearSwitch = value
	pSave("gearSwitch", value)
end

local function thrControlChanged(value)
    local pSave = system.pSave
	thrControl = value
	pSave("thrControl", value)
end

local function sensorChanged(value)
    local pSave = system.pSave
    local format = string.format
    TimSe = value
    TimSeId = format("%s", sensorIdlist[TimSe])
    TimSePa = format("%s", sensorPalist[TimSe])
    if (TimSeId == "...") then
        TimSeId = 0
        TimSePa = 0 
    end
    pSave("TimSe", value)
    pSave("TimSeId", TimSeId)
    pSave("TimSePa", TimSePa)
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
        addLabel({label="---          Dave's Jeti Tools      ---",font=FONT_BIG})

        addRow(2)
        addLabel({label=trans11.timSensor, width=220})
        addSelectbox(sensorLalist, TimSe, true, sensorChanged)

        addRow(2)
        addLabel({label=trans11.sw, width=220})
        addInputbox(gearSwitch, true, gearSwitchChanged)

	addRow(2)
	addLabel({label=trans11.thr, width=220})
	addInputbox(thrControl, true, thrControlChanged)
        
        form.addRow(2)
        addLabel({label=trans11.shortAnn, width=270})
        shortAnnIndex = addCheckbox(shortAnn, shortAnnClicked)
        
        addRow(1)
        addLabel({label="Thanks to RC-Thoughts.com - v."..TimAnnVersion.." ", font=FONT_MINI, alignRight=true})
    else
        local addRow, addLabel = form.addRow ,form.addLabel
        addRow(1)
        addLabel({label="Please update, min. fw 4.22 required!"})
    end

end
--------------------------------------------------------------------------------

-- Telemetry window draw functions

local function timePrint(width, height)

  local mm, rr = math.modf(running_time/60)
  local pts = string.format("%02d:%02d", mm, rr*60)
  local fstr = string.format("%d", fuel_pct)

  lcd.drawRectangle(2,15,300,40)
  lcd.drawLine(100+2, 15, 100+2, 54)
  lcd.drawLine(200+2, 15, 200+2, 54)

  local ww

  ww = lcd.getTextWidth(FONT_MAXI, pts)
  lcd.drawText(5+(100-ww)/2-1,15,pts, FONT_MAXI)

  ww = lcd.getTextWidth(FONT_MAXI, fstr)
  lcd.drawText(100+5+(100-ww)/2-1,15,fstr, FONT_MAXI)
  
  ww = lcd.getTextWidth(FONT_MAXI, "525")
  lcd.drawText(200+5+(100-ww)/2-1,15,"525", FONT_MAXI)

  ww = lcd.getTextWidth(FONT_MINI, "Flt Time (min)")
  lcd.drawText(5+(100-ww)/2,2,"Flt Time (min)", FONT_MINI)
  
  ww = lcd.getTextWidth(FONT_MINI, "Fuel Left (%)")
  lcd.drawText(100+5 + (100-ww)/2,2,"Fuel Left (%)", FONT_MINI)

  ww = lcd.getTextWidth(FONT_MINI, "Batt Used (maH)")
  lcd.drawText(200+5+(100-ww)/2,2,"Batt Used (maH)", FONT_MINI)
  
  lcd.drawRectangle(2, 70, 300, 60)

  local iv = 70
  local ivd = 4
  local ivdt

  while iv <= 130 do
    if iv + ivd > 130 then
      ivdt = 130 - 1
    else
      ivdt = iv + ivd - 1
    end
     
    lcd.drawLine(75+2, iv, 75+2, ivdt)
    lcd.drawLine(150+2, iv, 150+2, ivdt)
    lcd.drawLine(225+2, iv, 225+2, ivdt)
    
    iv = iv + 2*ivd
  end

  local ih = 2
  local ihd = 4
  local ihdt

  while ih <= 300 do
     if ih + ihd > 300 then
       ihdt = 300
     else
       ihdt = ih + ihd
     end
     lcd.drawLine(ih, 70+60/2, ihdt, 70+60/2)
     ih = ih + 2*ihd
  end

  local ss = string.format("Altitude: %d", ytable[#ytable]*1000/59)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText((300-ww)/2,70-13, ss, FONT_MINI)

  local ss = string.format("Scale: %d ft", 1000)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(75+(75-ww)/2+1,70+1, ss, FONT_MINI)

  local ss = string.format("Timeline %s", "1:25")
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(150+(75-ww)/2+2,70+1, ss, FONT_MINI)
  
  lcd.setColor(200,0,0)

  for ix = 0, #ytable-1, 1 do
    local iy = ytable[ix+1]
    lcd.drawFilledRectangle(2+5*ix, 130-iy, 5, iy, 127)
  end

  lcd.setColor(0,0,0)

  lcd.drawRectangle(2, 133, 150, 10)
  lcd.drawRectangle(3+150, 133, 149, 10)

  lcd.setColor(200,0,0)

  ww = ytable[#ytable]/59*146
  lcd.drawFilledRectangle(4, 135, ww, 6, 159)

  lcd.drawFilledRectangle(300-ww, 135, ww+1, 6, 159)
  
  lcd.setColor(0,0,0)

  collectgarbage()

end

--------------------------------------------------------------------------------
local function loop()

    -- first read fuel state from selected telemetry sensor
    
    local sensor = system.getSensorByID(TimSeId, TimSePa)

    if(sensor and sensor.valid) then
        fuel_pct = tonumber(string.format("%.0f", sensor.value))
    end
 
    -- now read the retract/gear switch ... when put "up" for first time, start timer
    
    local swi  = system.getInputsVal(gearSwitch)          -- read the retract switch

    if (swi and swi ~= oldswi) then
       oldswi = swi
       if (swi == 1 and start_time == 0) then             -- when the gear retracted first time, startup
	  start_time = system.getTimeCounter()/1000       -- convert from ms to seconds
	  next_ann_time = start_time + 30                 -- next announce in 30 seconds
	  system.playFile('Sup_Tim_Start.wav', AUDIO_QUEUE)
	  if DEBUG then print('Sup_Tim_Start.wav - Timer starting') end
       end
       if ( swi and swi == -1) then
           system.playFile('Landing_Gear_Extended.wav')
	   if DEBUG then print('Landing_Gear_Extended.wav') end
       end
    end


    
    local sgT = system.getTimeCounter()
    local tim = sgT / 1000
    local mod_sec, rem_sec = math.modf(tim - start_time)

    if mod_sec ~= old_mod_sec then
      old_mod_sec = mod_sec
      if (start_time > 0) then
    	 running_time = tim - start_time
	 local turbine_state = system.getInputsVal(thrControl)
         if (turbine_state and turbine_state > 0) then -- turbine is off .. stop timer
	   start_time = 0
	   system.messageBox("Turbine shut down, timer stopped")
	 end
      end

      if not fuel_pct then  -- for debug .. in prod just don't play fuel info if no sensor
         fuel_pct = 137
      end
      
      -- Now insert selected variable into table

      mrs = 0.85 * mrs + 0.15 * math.random(1,59)
      table.insert(ytable, #ytable+1, mrs)

      if #ytable > 60 then
        table.remove(ytable, 1)
      end

    end

    -- now see if the next interval is passed
    -- start_time is also used for state info ... it's zero if timer has never started or has
    -- been stopped by shutting down turbine
    
    if (start_time > 0 and tim > next_ann_time) then      -- we are running and it's time to announce

        next_ann_time = next_ann_time + 30                -- schedule next ann 30 seconds in future
	running_time = tim-start_time
	local min_time = running_time / 60
	local mod_min, rem_min = math.modf(min_time)
	system.playFile('Sup_Tim_Tim.wav', AUDIO_QUEUE)   -- "Time Elapsed"
	if DEBUG then print('Sup_Tim_Tim.wav - Time elapsed') end

	if mod_min > 0 then
	   system.playNumber(mod_min, 0, 'min')
	   if DEBUG then print(mod_min, 'min') end
        end

	if rem_min > 0.1 then
	   system.playNumber(30, 0, 's')
	   if DEBUG then print(30, 's') end
	end
	
        if not shortAnn then
           system.playFile('Sup_Tim_Fuel.wav', AUDIO_QUEUE)  -- "Fuel Remaining"
	   if DEBUG then print('Sup_Tim_Fuel.wav - Fuel Remaining') end
        end

        system.playNumber(fuel_pct, 0, '%')
        if DEBUG then print(fuel_pct, '%') end       

    end
    
    collectgarbage() -- really? in each loop every 30 ms?
end
--------------------------------------------------------------------------------
local function init()

    gearSwitch = system.pLoad("gearSwitch")
    thrControl = system.pLoad("thrControl")
    TimSe      = system.pLoad("TimSe", 0)
    TimSeId    = system.pLoad("TimSeId", 0)
    TimSePa    = system.pLoad("TimSePa", 0)
    shortAnnSt = system.pLoad("shortAnnSt", 0)
    
    if(shortAnnSt == 1) then
        shortAnn = true
        else
        shortAnn = false
    end
    system.registerForm(1, MENU_APPS, trans11.appName, initForm)
    system.registerTelemetry(1, "Super Timer", 4, timePrint)
    system.playFile('Tim_Ann_Act.wav', AUDIO_IMMEDIATE)
    if DEBUG then print('Tim_Ann_Act.wav') end
    readSensors()
    collectgarbage()
end
--------------------------------------------------------------------------------
TimAnnVersion = "1.0"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM/RCT        ", version=TimAnnVersion, name=trans11.appName}
