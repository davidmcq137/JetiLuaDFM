--[[
	---------------------------------------------------------
    "Super timer" - calls 30 second intervals with time from gear
    retract and fuel capacity remaining
    
    Derived from DFM's Speed Announcer, which in turn was derived from RCT's Alt Announcer
    
    Requires transmitter firmware 4.22 or higher.
    
    Works in DS-24
    
	----------------------------------------------------------------------
	Localisation-file has to be as /Apps/Lang/DFM-TimA.jsn if used
	----------------------------------------------------------------------
	Derived from AltAnnouncer - a part of RC-Thoughts Jeti Tools.
	----------------------------------------------------------------------
	AltAnnouncer released under MIT-license by Tero @ RC-Thoughts.com 2017
	----------------------------------------------------------------------
	DFM-TimA.lua released under MIT license by DFM 2018
	----------------------------------------------------------------------

    Todo items: selft -- hard coded now to convert m to ft -- put choice in menu
                make 30 second interval settable?
		
--]]

collectgarbage()

------------------------------------------------------------------------------

-- Locals for application

--local trans11
local gearSwitch
local thrControl

local FuelSe, FuelSeId, FuelSePa

local GraphSe, GraphSeId, GraphSePa

local GraphScale = 1000
local GraphValue = 0
local GraphName = '---'
local GraphUnit = '---'

local shortAnn, shortAnnIndex, shortAnnSt = false

local oldswi = 0
local old_mod_sec = 0
local running_time = 0
local next_ann_time = 0
local start_time = 0
local fuel_pct
local mrs = math.random(1, 999) -- for debugging

local ytable = {} -- table of values for "chart recorder" graph

local DEBUG = false -- if set to <true> will print to console the speech files and output

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

local batt_id   = {0,0,0,0} -- hardcoded IDs for sensors related to batt current and mah
local batt_pa   = {0,0,0,0}
local batt_val  = {0,0,0,0}

--------------------------------------------------------------------------------

-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimA.jsn")
  local obj = json.decode(file)cd 
  if(obj) then
    trans11 = obj[lng] or obj[obj.default]
  end
--]]
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select - done once at startup
-- Capture battery sensor IDs as specified in batt_info
-- Additionally look for the telemetry labels in <batt_info>, note id & param

local function readSensors()

  local batt_info = {"I Accu 1", "I Accu 2", "Capacity 1", "Capacity 2"}

  local sensors = system.getSensors()
  for i, sensor in ipairs(sensors) do
    if (sensor.label ~= "") then
      -- print(sensor.label,",",sensor.id, ",", sensor.param, ",", sensor.unit)
      table.insert(sensorLalist, sensor.label)
      for j, name in ipairs(batt_info) do 
        if sensor.label == batt_info[j] then
          batt_id[j] = sensor.id
          batt_pa[j] = sensor.param
        end
      end
      table.insert(sensorIdlist, sensor.id)
      table.insert(sensorPalist, sensor.param)
      table.insert(sensorUnlist, sensor.unit)
    end
  end
end

----------------------------------------------------------------------

-- Actions when settings changed

local function gearSwitchChanged(value)
  gearSwitch = value
  system.pSave("gearSwitch", value)
end

local function thrControlChanged(value)
  thrControl = value
  system.pSave("thrControl", value)
end

local function graphscaleChanged(value)
  GraphScale = value
  system.pSave("GraphScale", value)
end

local function fuelsensorChanged(value)
  FuelSe = value
  FuelSeId = sensorIdlist[FuelSe]
  FuelSePa = sensorPalist[FuelSe]
  if (FuelSeId == "...") then
    FuelSeId = 0
    FuelSePa = 0 
  end
  system.pSave("FuelSe", value)
  system.pSave("FuelSeId", FuelSeId)
  system.pSave("FuelSePa", FuelSePa)
end

local function graphsensorChanged(value)
  GraphSe = value
  GraphSeId = sensorIdlist[GraphSe]
  GraphSePa = sensorPalist[GraphSe]
  if (GraphSeId == "...") then
    GraphSeId = 0
    GraphSePa = 0 
  end
  GraphName = sensorLalist[GraphSe]
  GraphUnit = sensorUnlist[GraphSe]
  system.pSave("GraphSe", value)
  system.pSave("GraphSeId", GraphSeId)
  system.pSave("GraphSePa", GraphSePa)
  system.pSave("GraphScale", GraphScale)
  system.pSave("GraphName", GraphName)
  system.pSave("GraphUnit", GraphUnit)
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

  if (tonumber(system.getVersion()) >= 4.22) then

    form.addRow(1)
    form.addLabel({label="---          Dave's Jeti Tools      ---",font=FONT_BIG})

    form.addRow(2)
    form.addLabel({label="Select Fuel Sensor", width=220})
    form.addSelectbox(sensorLalist, FuelSe, true, fuelsensorChanged)

    form.addRow(2)
    form.addLabel({label="Select Graphed Sensor", width=220})
    form.addSelectbox(sensorLalist, GraphSe, true, graphsensorChanged)

    form.addRow(2)
    form.addLabel({label="Graph Vertical Scale", width=220})
    form.addIntbox(GraphScale, 1, 10000, 1000, 0, 1, graphscaleChanged)

    form.addRow(2)
    form.addLabel({label="Select Retract Switch (gear up)", width=220})
    form.addInputbox(gearSwitch, true, gearSwitchChanged)

    form.addRow(2)
    form.addLabel({label="Select Throttle Cutoff (off)", width=220})
    form.addInputbox(thrControl, true, thrControlChanged)
  
    form.addRow(2)
    form.addLabel({label="Short Announcement", width=270})
    shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
        
    form.addRow(1)
    form.addLabel({label="Thanks to RC-Thoughts.com - v."..TimAnnVersion.." ", font=FONT_MINI, alignRight=true})

  else

    form.addRow(1)
    form.addLabel({label="Please update, min. fw 4.22 required"})
  end
end
--------------------------------------------------------------------------------

-- Telemetry window draw functions

local function timePrint(width, height)

  local mm, rr = math.modf(running_time/60)
  local pts = string.format("%02d:%02d", mm, rr*60)

  local fstr

  if (fuel_pct) then
    fstr = string.format("%d", fuel_pct)
  else
    fstr = "---"
  end

  lcd.drawRectangle(2,15,300,40)
  lcd.drawLine(100+2, 15, 100+2, 54)
  lcd.drawLine(200+2, 15, 200+2, 54)

  local ww

  ww = lcd.getTextWidth(FONT_MAXI, pts)
  lcd.drawText(5+(100-ww)/2-1,15,pts, FONT_MAXI)

  ww = lcd.getTextWidth(FONT_MAXI, fstr)
  lcd.drawText(100+5+(100-ww)/2-1,15,fstr, FONT_MAXI)

  local ss = string.format("%d", batt_val[3] + batt_val[4])
  ww = lcd.getTextWidth(FONT_MAXI, ss)
  lcd.drawText(200+5+(100-ww)/2-1,15,ss, FONT_MAXI)

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

    
  local ss

  if GraphName == '---' then
    ss = '---'
  else
    if GraphUnit == 'm' then -- ought to add "selft" to menu
      ss= string.format(GraphName .. ": %d " .. "ft", GraphValue*3.28084)
    else
      ss= string.format(GraphName .. ": %d " .. GraphUnit, GraphValue)
    end
  end

  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText((300-ww)/2+3,70-13, ss, FONT_MINI)

  local ss = string.format("Scale: %d", GraphScale)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(75+(75-ww)/2+1,70+1, ss, FONT_MINI)

  local ss = string.format("Timeline %s", "1:00")
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(150+(75-ww)/2+2,70+1, ss, FONT_MINI)

  local ss = string.format("Bat 1: %2.2f A", batt_val[1])
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(75+(75-ww)/2+1,70+15, ss, FONT_MINI)

  local ss = string.format("Bat 2: %2.2f A", batt_val[2])
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(150+(75-ww)/2+2,70+15, ss, FONT_MINI)

  lcd.setColor(0,0,200)

  for ix = 0, #ytable-1, 1 do
    local iy =ytable[ix+1]/GraphScale*60
    if iy > 60 then iy=60 end
    if iy < 1  then iy=1  end
    lcd.drawFilledRectangle(2+5*ix, 130-iy, 5, iy, 150)
  end 

  lcd.setColor(0,0,0)

  lcd.drawRectangle(2, 133, 150, 10)
  lcd.drawRectangle(3+150, 133, 149, 10)

  lcd.setColor(0,0,200)

  ww = math.floor(batt_val[1]/6.0*149.0)
  lcd.drawFilledRectangle(4, 135, ww, 6, 200)

  ww = math.floor(batt_val[2]/6.0*149.0)
  lcd.drawFilledRectangle(300-ww, 135, ww+1, 6, 200)
  
  lcd.setColor(0,0,0)

  collectgarbage()

end

--------------------------------------------------------------------------------
local function loop()


-- first read fuel state and graph item from selected telemetry sensors
    
  local sensor = system.getSensorByID(FuelSeId, FuelSePa)

  if(sensor and sensor.valid) then
    fuel_pct = sensor.value
  end

  local sensor = system.getSensorByID(GraphSeId, GraphSePa)

  if(sensor and sensor.valid) then
    GraphValue  = sensor.value
  end

  for i = 1, 4 do -- get "hard coded" batt properties
    if batt_id[i] ~= 0 then
      local sensor = system.getSensorByID(batt_id[i], batt_pa[i])
      if (sensor and sensor.valid) then
        batt_val[i] = sensor.value
      end
    end
  end
    
 -- now read the retract/gear switch ... when put "up" for first time, start timer
    
  local swi  = system.getInputsVal(gearSwitch) 

  if (swi and swi ~= oldswi) then
    oldswi = swi
    if (swi == 1 and start_time == 0) then            -- when the gear retracted first time, startup
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

  if mod_sec ~= old_mod_sec then -- the scope of this <if> is what is done once per second
    old_mod_sec = mod_sec
    if (start_time > 0) then
      running_time = tim - start_time
      local turbine_state = system.getInputsVal(thrControl)
      if (turbine_state and turbine_state > 0) then -- turbine is off .. stop timer
        start_time = 0
	system.messageBox("Turbine shut down, timer stopped")
      end
    end
  
    -- if not fuel_pct then  -- for debug .. in prod just don't play fuel info if no sensor
    --   fuel_pct = 137
    -- end
      
-- Now insert selected variable into table for graph

    if not GraphValue and DEBUG then -- for debug
      mrs = 0.85 * mrs + 0.15 * math.random(1,999) -- default scale is 1000
      table.insert(ytable, #ytable+1, mrs)
    else
      table.insert(ytable, #ytable+1, GraphValue)
    end

    if #ytable > 60 then
      table.remove(ytable, 1)
    end
  end
  
-- now see if the next interval is passed
-- start_time is also used for state info ... it's zero if timer has never started or has
-- been stopped by shutting down turbine
    
    if (start_time > 0 and tim > next_ann_time) then    -- we are running and it's time to announce

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
    if (fuel_pct) then
      system.playNumber(fuel_pct, 0, '%')
      if DEBUG then print(fuel_pct, '%') end
    else
      system.playNumber(0, 0, '%')
      if DEBUG then print(0, '-%-') end
    end
  end
  collectgarbage() -- really? in each loop every 30 ms?
end
--------------------------------------------------------------------------------
local function init()

    gearSwitch = system.pLoad("gearSwitch")
    thrControl = system.pLoad("thrControl")
    
    FuelSe      = system.pLoad("FuelSe", 0)
    FuelSeId    = system.pLoad("FuelSeId", 0)
    FuelSePa    = system.pLoad("FuelSePa", 0)

    GraphSe      = system.pLoad("GraphSe", 0)
    GraphSeId    = system.pLoad("GraphSeId", 0)
    GraphSePa    = system.pLoad("GraphSePa", 0)

    GraphScale   = system.pLoad("GraphScale", 1000)
    GraphName    = system.pLoad("GraphName", 0)
    GraphUnit    = system.pLoad("GraphUnit", 0)
    
    shortAnnSt = system.pLoad("shortAnnSt", 0)
    
    if(shortAnnSt == 1) then
        shortAnn = true
        else
        shortAnn = false
    end
    
    system.registerForm(1, MENU_APPS, "Super Time Announcer", initForm)
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
return {init=init, loop=loop, author="DFM/RCT        ", version=TimAnnVersion, name="Super Time Announcer"}
