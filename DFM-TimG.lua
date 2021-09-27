--[[

   "Super timer" - calls 60 second intervals with time from gear
   retract and fuel capacity remaining
    
   This is the "geriatric" version with large image-based numbers on the timer

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
    
   Note: original version was 30 secs hardcoded interval, now set to 60 seconds

--]]

--local trans11
local TimAnnVersion = "1.0"
local gearSwitch
local thrControl

local FuelSe, FuelSeId, FuelSePa

local shortAnn, shortAnnIndex, shortAnnSt = false

local oldswi = 0
local old_mod_sec = 0
local running_time = 0
local running_time_50 
local next_ann_time = 0
local start_time = 0
local fuel_pct = 0
local fuel_max
local fuel_qty
local fuel_pct_50
local fuel_pct_gearup
local remainingTime
local burnRate

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units
local sensorTylist = { "..." }  -- sensor Type

local digitMap = {
   [0]="zero",[1]="one",   [2]="two",   [3]="three", [4]="four", [5]="five",
   [6]="six", [7]="seven", [8]="eight", [9]="nine",  [":"]="colon"
}

local charMap = {["0"]=0, ["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5,
   ["6"]=6, ["7"]=7, ["8"]=8, ["9"]=9, [":"]=":"}

   
local digitImageTimer = {}
local digitImageEmpty = {}

-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimG.jsn")
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

local sensorLbl = "***"

local function readSensors()

   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	    table.insert(sensorTylist, sensor.type)
	 end
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

   form.addRow(2)
   form.addLabel({label="Select Fuel Sensor", width=220})
   form.addSelectbox(sensorLalist, FuelSe, true, fuelsensorChanged)
   
   
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
   form.addLabel({label="DFM - v."..TimAnnVersion.." ", font=FONT_MINI, alignRight=true})
   
end
--------------------------------------------------------------------------------

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str)

   local d
   
   lcd.setColor(0, 0, 255)
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)

   
   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h//2, d, h)
   lcd.setColor(0,0,0)

   if str then
      lcd.drawText(oxc - lcd.getTextWidth(FONT_MINI, str)//2, oyc+7, str, FONT_MINI)
   end
   
end

-- Telemetry window draw functions


local function timePrint(width, height)

   local fstr
   local mm, rr
   local pts
   local rts
   
   mm,rr = math.modf(running_time/60)
   pts = string.format("%02d:%02d", math.floor(mm), math.floor(rr*60))

  if remainingTime then
     mm, rr = math.modf(remainingTime/60)
     rts = string.format("%02d:%02d", math.floor(mm), math.floor(rr*60))
  else
     rts = ""
  end
  
  if (fuel_pct and FuelSeId ~= 0) then
    fstr = string.format("%d", math.floor(fuel_pct)) -- make sure it's an int if applying %d
  else
    fstr = ":::"
  end

  local len
  local char

  len = 0
  for i = 1, #pts do
     char = pts:sub(i,i)
     len = len + digitImageTimer[charMap[char]].width
  end

  local vPix = 10
  local hPix = width/2 - len/2

  for i = 1, #pts do
     char = pts:sub(i,i)
     lcd.drawImage(hPix, vPix, digitImageTimer[charMap[char]])
     hPix = hPix + digitImageTimer[charMap[char]].width
  end

  len = 0
  for i = 1, #rts do
     char = rts:sub(i,i)
     len = len + digitImageEmpty[charMap[char]].width
  end

  hPix = width/2 - len/2
  vPix = 65

  for i = 1, #rts do
     char = rts:sub(i,i)
     lcd.drawImage(hPix, vPix, digitImageEmpty[charMap[char]])
     hPix = hPix + digitImageEmpty[charMap[char]].width
  end

  drawRectGaugeAbs(width/2, height-14, 300, 24, 0, 100, fuel_pct)

  lcd.drawText(10,10, remainingTime or "---")
  
end

--------------------------------------------------------------------------------

local function loop()

   local sensor = system.getSensorByID(FuelSeId, FuelSePa)
   
   local sgTC = system.getTimeCounter()
   local tim = sgTC / 1000
   if start_time > 0 then
      running_time = tim-start_time
   end
   local mod_sec, rem_sec = math.modf(running_time)

   if(sensor and sensor.valid) then
      fuel_qty = sensor.value
      -- odd behavior .. sensor.max tracking with sensor.value??
      -- for now, just set fuel_max once at first reading till we figure it out
      if not fuel_max then
	 print("DFM-TimG: fuel_qty, sensor.max", fuel_qty, sensor.max)
	 fuel_max = fuel_qty
      end
      if fuel_max and fuel_qty  and (fuel_max ~= 0) then -- double check!
	 fuel_pct = 100 * fuel_qty / fuel_max
      else
	 fuel_pct = 0
      end
   end

   -- think about: what if fuel reset to 100% on CTU when piss tank removed
   -- how do we reset fuel max?
   
   if fuel_pct < 50 and start_time > 0 and fuel_pct_gearup then
      if not fuel_pct_50 then
	 fuel_pct_50 = fuel_pct
	 running_time_50 = running_time
	 print("fuel_pct_50:", fuel_pct_50)
	 print("running_time_50", running_time_50)
	 print("fuel pct gearup", fuel_pct_gearup)
	 -- long term average from gear up to now (just at 50% fuel)
	 -- should be defensive aboute gear up with < 50% fuel, touch+goes, etc
	 burnRate = (fuel_pct_gearup  - fuel_pct_50) / running_time_50
	 print("at 50%: burn rate:", burnRate)
      end
      if burnRate > 0 then
	 remainingTime = fuel_pct / burnRate      -- estimated time on fuel that is left
      else
	 remainingTime = 0
      end
   end
   
   -- now read the retract/gear switch ... when put "up" for first time, start timer
    
   local swi  = system.getInputsVal(gearSwitch) 

   if (swi and swi ~= oldswi) then
      oldswi = swi
      if (swi == 1 and start_time == 0) then -- when the gear retracted first time, startup
	 start_time = system.getTimeCounter()/1000       -- convert from ms to seconds
	 fuel_pct_gearup = fuel_pct
	 print("fuel_pct_gearup:", fuel_pct_gearup)
	 next_ann_time = start_time + 60                 -- next announce in 60 seconds
	 system.playFile('/Apps/DFM-TimG/Sup_Tim_Start.wav', AUDIO_QUEUE)
      end
      if ( swi and swi == -1) then
	 system.playFile('/Apps/DFM-TimG/Landing_Gear_Extended.wav')
      end
   end

   
   if (start_time > 0) then
      running_time = tim - start_time
      local turbine_state = system.getInputsVal(thrControl)
      if (turbine_state and turbine_state > 0) then -- turbine is off .. stop timer
	 start_time = 0
	 system.messageBox("Turbine shut down, timer stopped")
      end
   end

   -- now see if the next interval is passed
   -- start_time is also used for state info ... it's zero if timer has never started or has
   -- been stopped by shutting down turbine
    
   if (start_time > 0 and tim > next_ann_time) then    -- we are running and it's time to announce

      next_ann_time = next_ann_time + 60                -- schedule next ann 60 seconds in future
      local min_time = running_time / 60
      local mod_min, rem_min = math.modf(min_time)
      system.playFile('/Apps/DFM-TimG/Sup_Tim_Tim.wav', AUDIO_QUEUE)   -- "Time Elapsed"

      if mod_min > 0 then
	 system.playNumber(mod_min, 0, 'min')
      end

      if rem_min > 0.1 then
	 system.playNumber(30, 0, 's')
      end
      
      if not shortAnn and FuelSeId ~= 0 then
	 system.playFile('/Apps/DFM-TimG/Sup_Tim_Fuel.wav', AUDIO_QUEUE)  -- "Fuel Remaining"
      end
      if (fuel_pct and FuelSeId ~= 0) then
	 system.playNumber(fuel_pct, 0, '%')
      end

      if fuel_pct < 50 and start_time > 0 and fuel_pct_gearup then
	 min_time = remainingTime / 60
	 mod_min, rem_min = math.modf(min_time)
	 rem_min = rem_min * 60
	 system.playFile('/Apps/DFM-TimG/Fuel_flight_time_remaining.wav', AUDIO_QUEUE)
	 system.playNumber(math.floor(mod_min), 0, 'min')
	 system.playNumber(math.floor(rem_min), 0, 's')
      end
   end
end
--------------------------------------------------------------------------------
local function init()

   --local digitMap = {[0]="zero,[1]="one",[2]="two", [3]="three, [4]="four", [5]="five",
   -- [6]="six", [7]="seven", [8]="eight", [9]="nine", [":"]="colon}

   local imagePix = 64
   local imageColorTimer = "blue"
   local imageColorEmpty = "red"
   local fn
   
   for k,v in pairs(digitMap) do
      fn = "Apps/DFM-TimG/" .. v .. "-" .. tostring(imagePix) .. "-" .. imageColorTimer .. ".png"
      print("k,v,fn:", k, v, fn)
      digitImageTimer[k] = lcd.loadImage(fn)
      print(k, digitImageTimer[k].width, digitImageTimer[k].height)
   end
   
   for k,v in pairs(digitMap) do
      fn = "Apps/DFM-TimG/" .. v .. "-" .. tostring(imagePix) .. "-" .. imageColorEmpty .. ".png"
      print("k,v,fn:", k, v, fn)
      digitImageEmpty[k] = lcd.loadImage(fn)
      print(k, digitImageEmpty[k].width, digitImageEmpty[k].height)
   end

   gearSwitch = system.pLoad("gearSwitch")
   thrControl = system.pLoad("thrControl")
   
   FuelSe      = system.pLoad("FuelSe", 0)
   FuelSeId    = system.pLoad("FuelSeId", 0)
   FuelSePa    = system.pLoad("FuelSePa", 0)
   
   shortAnnSt = system.pLoad("shortAnnSt", 0)
   
   if(shortAnnSt == 1) then
      shortAnn = true
   else
      shortAnn = false
   end
   
   system.registerForm(1, MENU_APPS, "Geriatric Time Announcer", initForm, keypress, printform)
   system.registerTelemetry(1, "Geriatric Timer", 4, timePrint)
   system.playFile('/Apps/DFM-TimG/Tim_Ann_Act.wav', AUDIO_IMMEDIATE)
   
   readSensors()
end
--------------------------------------------------------------------------------
setLanguage()

return {init=init, loop=loop, author="DFM", version=TimAnnVersion, name="Super Time Announcer"}
