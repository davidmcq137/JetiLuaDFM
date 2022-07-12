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
   DFM-TimG.lua released under MIT license by DFM 2021
   ----------------------------------------------------------------------
   
   Note: original version was 30 secs hardcoded interval, now set to 60 seconds

   Idea to expand functionality and consolidate an app:

   Log various paramaters at begin and end of flight, be able to reset maH counter on CBox 
   by detecting voltage jumping up if batt charging has happened.

   if voltage of (either? both?) Rx batts bumps up from last end
   value, detect that charging has happened and pulse a selected
   channel to reset cumulative mah reading on CBox

   After a few flights when there is a good average fuel consumption rate logged
   then can estimate time to empty before 50% of flight complete?
   
   Variables to log:

   flight count (increment)
   flight time from gear up to turbine shutdown
   fuel used %
   fuel consumption rate at 50% elapsed time (to be logged for use in future flights)
   begin mah cumulative Rx1 batt
   begin mah cumulative Rx2 batt
   end mah cumulative Rx1 batt
   end mah cumulative Rx2 batt
   begin volt Rx1 batt
   begin volt Rx2 batt
   end volt Rx1 batt
   end volt Rx2 batt
   begin volt ECU batt
   end volt ECU batt
   
   Also maybe integrate speed announcer into this app so it becomes a
   general flight status announcer -- it already does fuel state and
   estimated time to empty

   
--]]

--local trans11
local TimAnnVersion = "1.0"
local gearSwitch
local thrControl

local FuelSe, FuelSeId, FuelSePa

local shortAnn, shortAnnIndex, shortAnnSt = false

local oldswi = 0
local runningTime = 0
local runningTime50 
local nextAnnTime = 0
local forceAnn = false
local startTime = 0
local fuelPct = 0
local fuelMax
local fuelQty
local fuelPct50
local fuelPctGearUp
local remainingTime
local burnRate
local bingoTime
local bingoAnnounced = false
local emptyAnnounced = false

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units
local sensorTylist = { "..." }  -- sensor Type

local digitMap = {
   [0]="zero",[1]="one",   [2]="two",   [3]="three", [4]="four", [5]="five",
   [6]="six", [7]="seven", [8]="eight", [9]="nine",  [":"]="colon"
}

local charMap = {
   ["0"]=0, ["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5,
   ["6"]=6, ["7"]=7, ["8"]=8, ["9"]=9, [":"]=":"
}

   
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

local function bingoTimeChanged(value)
   bingoTime = value
   system.pSave("bingoTime", bingoTime)
end

local function shortAnnClicked(value)
  shortAnn = not value
  form.setValue(shortAnnIndex, shortAnn)
  system.pSave("shortAnn", tostring(shortAnn))
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
   form.addLabel({label="Bingo fuel (secs before empty)", width=220})
   form.addIntbox(bingoTime, 0, 600, 60, 0, 1, bingoTimeChanged)
   
   form.addRow(2)
   form.addLabel({label="Short Announcement", width=270})
   shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   
   form.addRow(1)
   form.addLabel({label="DFM - v."..TimAnnVersion.." ", font=FONT_MINI, alignRight=true})
   
end
--------------------------------------------------------------------------------

local function writeFuelState()
   local fp
   local ft={}
   local fn
   local mn
   local pf
   local emFlag

   if fuelPct == 100 then
      print("DFM-TimG: write fuel state 100% - no JSON written")
      return
   end

   emFlag = select(2, system.getDeviceType())
   if emFlag == 1 then pf = "" else pf = "/" end
   
   ft.lastFuel = fuelPct

   -- write time as hex so json converter does not make it a float
   
   ft.lastTime = string.format("0X%X", system.getTime())
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fn = pf .. "Apps/DFM-TimG/LF_" .. mn .. ".jsn"

   fp = io.open(fn, "w")
   if fp then io.write(fp, json.encode(ft), "\n") end
   io.close(fp)
end

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str, rgb)

   local d
   local txt
   local font = FONT_MAXI
   local r, g, b

   if val < 10 and system.getTime() % 2 == 0 then return end
   
   if rgb then
      r=rgb.r
      g=rgb.g
      b=rgb.b
   else
      r=0
      g=0
      b=255
   end
   
   lcd.setColor(r,g,b)
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)

   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h//2, d, h)

   if str then
      txt = str .. string.format("%.0f%%", val)
      lcd.setColor(255,255,255)
      -- note that for some reason, setClipping moves things to the right by the x coord
      -- of the clip region .. correct for that
      lcd.setClipping(oxc-w/2, 0, d, 160)
      lcd.drawText(oxc - lcd.getTextWidth(font, txt) / 2 - (oxc - w//2),
		   oyc - lcd.getTextHeight(font) / 2,
		   txt, font)
      lcd.setClipping(oxc -w/2 + d, 0, w-d, 160) 
      lcd.setColor(r,g,b)
      lcd.drawText(oxc - lcd.getTextWidth(font, txt) / 2 - (oxc - w//2 + d),
		   oyc - lcd.getTextHeight(font)//2,
		   txt, font)      
      lcd.resetClipping()
   end
end

-- Telemetry window draw functions

local function timePrint(width, height, key)

   local mm, rr
   local pts
   local rts

   -- compute running time and time to empty, create strings

   -- if we got a key 1 press, force update now

   if key == KEY_1 then -- "Ann" (see system.registerTelemetry call below)
      forceAnn = true
   end
   
   mm,rr = math.modf(runningTime/60)
   pts = string.format("%02d:%02d", math.floor(mm), math.floor(rr*60))

  if remainingTime and remainingTime ~= 0 then
     mm, rr = math.modf(remainingTime/60)
     rts = string.format("%02d:%02d", math.floor(mm), math.floor(rr*60))
  else
     rts = ""
  end

  -- translate the strings to sequences of images of the digits
  
  local len
  local char

  -- get lenth of images for timer
  
  len = 0
  for i = 1, #pts do
     char = pts:sub(i,i)
     if string.find(char, "[^%d^:]") then
	print("DFM-TimG: Illegal character", char)
	char = ":"
     end
     len = len + digitImageTimer[charMap[char]].width
  end

  local vPix = 5
  local hPix = width/2 - len/2

  -- draw digits for timer

  for i = 1, #pts do
     char = pts:sub(i,i)
     if string.find(char, "[^%d^:]") then
	print("DFM-TimG: Illegal character", char)
	char = ":"
     end
     lcd.drawImage(hPix, vPix, digitImageTimer[charMap[char]])
     hPix = hPix + digitImageTimer[charMap[char]].width
  end

  -- get lenth of time to empty

  len = 0
  for i = 1, #rts do
     char = rts:sub(i,i)
     if string.find(char, "[^%d^:]") then
	print("DFM-TimG: Illegal character", char)
	char = ":"
     end
     len = len + digitImageEmpty[charMap[char]].width
  end

  hPix = width/2 - len/2
  vPix = 62

  -- draw digits of time to empty

  for i = 1, #rts do
     char = rts:sub(i,i)
     if string.find(char, "[^%d^:]") then
	print("DFM-TimG: Illegal character", char)
	char = ":"
     end
     lcd.drawImage(hPix, vPix, digitImageEmpty[charMap[char]])
     hPix = hPix + digitImageEmpty[charMap[char]].width
  end

  -- bar graph for fuel state

  local rgb
  
  if bingoAnnounced then rgb = {r=255,g=0,b=0} else rgb = {r=0,g=0,b=255} end
     
  drawRectGaugeAbs(width/2, height-20, 300, 40, 0, 100, fuelPct, "", rgb)

  --lcd.drawText(10,100,string.format("F: %d M: %d", (fuelQty or -1), (fuelMax or -1) ))

end

--------------------------------------------------------------------------------
local fpAnn = false

local function loop()

   local sensor = system.getSensorByID(FuelSeId, FuelSePa)
   local tim = system.getTimeCounter() / 1000

   if startTime > 0 then
      runningTime = tim-startTime
   end

   if(sensor and sensor.valid) then
      -- seems that with the CTU, sensor.max not working correctly, but it is ok for Jetcat
      -- so let's just keep our own fuelMax and ignore sensor.max
      fuelQty = sensor.value or 0
      if not fuelMax then fuelMax = fuelQty end
      if fuelQty > fuelMax then fuelMax = fuelQty end

      if fuelMax > 0 then -- double check!
	 fuelPct = 100 * fuelQty / fuelMax 
      else
	 fuelPct = 0
      end
      if fuelPct > 100 and (not fpAnn) then
	 print("pct>100", fuelQty, fuelMax, sensor.max)
	 fpAnn = true
      end
   end

   if fuelPct < 50 and startTime > 0 and fuelPctGearUp then
      if not fuelPct50 then
	 fuelPct50 = fuelPct
	 runningTime50 = runningTime
	 -- long term average from gear up to now (just at 50% fuel)
	 burnRate = (fuelPctGearUp  - fuelPct50) / runningTime50
      end
      if burnRate > 0 then
	 remainingTime = fuelPct / burnRate      -- estimated time on fuel that is left
      else
	 remainingTime = 0
      end
   end

   if remainingTime and remainingTime < bingoTime and not bingoAnnounced then
      system.playFile('Apps/DFM-TimG/warning_bingo_fuel', AUDIO_IMMEDIATE)
      bingoAnnounced = true
   end

   if system.getTimeCounter() - (emptyAnnouncedTime or 0) > 10000 then emptyAnnounced = false end

   if remainingTime and remainingTime <= 0 and not emptyAnnounced then
      system.playFile('Apps/DFM-TimG/warning_fuel_empty', AUDIO_IMMEDIATE)
      emptyAnnounced = true
      emptyAnnouncedTime = system.getTimeCounter()
   end

   -- now read the retract/gear switch ... when put "up" for first time, start timer
   -- will ignore subsequent gear ups, e.g. touch and goes
    
   local swi  = system.getInputsVal(gearSwitch) 

   if (swi and swi ~= oldswi) then
      oldswi = swi
      -- when the gear retracted first time, startup
      if (swi == 1 and startTime == 0) then 
	 startTime = system.getTimeCounter() / 1000.0 
	 fuelPctGearUp = fuelPct
	 nextAnnTime = startTime + 60
	 system.playFile('/Apps/DFM-TimG/Sup_Tim_Start.wav', AUDIO_QUEUE)
      end
   end
   
   if (startTime > 0) then
      runningTime = tim - startTime
      local turbineState = system.getInputsVal(thrControl)
      if (turbineState and turbineState > 0) then -- turbine is off .. stop timer
	 startTime = 0
	 system.messageBox("Turbine shut down, timer stopped")
	 writeFuelState()
      end
   end

   -- now see if the next interval is passed
   -- startTime is also used for state info ... it's zero if timer has never started or has
   -- been stopped by shutting down turbine
    
   if (startTime > 0 and tim >= nextAnnTime) or forceAnn then -- we are running and it's time to announce

      if not forceAnn then
	 nextAnnTime = nextAnnTime + 60                -- schedule next ann 60 seconds in future
      end
      
      local minTime = runningTime / 60
      local modMin, remMin = math.modf(minTime)
            
      system.playFile('/Apps/DFM-TimG/Sup_Tim_Tim.wav', AUDIO_QUEUE)   -- "Time Elapsed"

      if modMin > 0 then
	 system.playNumber(math.floor(modMin), 0, 'min')
      end

      if forceAnn then
	 remMin = remMin * 60
	 system.playNumber(math.floor(remMin), 0, 's')
      end

      forceAnn = false
	 
      if not shortAnn and FuelSeId ~= 0 then
	 system.playFile('/Apps/DFM-TimG/Sup_Tim_Fuel.wav', AUDIO_QUEUE)  -- "Fuel Remaining"
      end
      if (fuelPct and FuelSeId ~= 0) then
	 system.playNumber(fuelPct, 0, '%')
      end

      if fuelPct < 50 and startTime > 0 and fuelPctGearUp then
	 minTime = remainingTime / 60
	 modMin, remMin = math.modf(minTime)
	 remMin = remMin * 60
	 system.playFile('/Apps/DFM-TimG/Fuel_flight_time_remaining.wav', AUDIO_QUEUE)
	 system.playNumber(math.floor(modMin), 0, 'min')
	 system.playNumber(math.floor(remMin), 0, 's')
      end
   end
end
--------------------------------------------------------------------------------
local function init()


   local imagePix = 64
   local imageColorTimer = "blue"
   local imageColorEmpty = "red"
   local fn
   
   for k,v in pairs(digitMap) do
      fn = "Apps/DFM-TimG/" .. v .. "-" .. tostring(imagePix) .. "-" .. imageColorTimer .. ".png"
      digitImageTimer[k] = lcd.loadImage(fn)
      if not  digitImageTimer[k] then
	 print("Cannot load timer image", k)
      end
   end
   
   for k,v in pairs(digitMap) do
      fn = "Apps/DFM-TimG/" .. v .. "-" .. tostring(imagePix) .. "-" .. imageColorEmpty .. ".png"
      digitImageEmpty[k] = lcd.loadImage(fn)
      if not  digitImageEmpty[k] then
	 print("Cannot load empty image", k)
      end
   end

   gearSwitch = system.pLoad("gearSwitch")
   thrControl = system.pLoad("thrControl")
   
   FuelSe      = system.pLoad("FuelSe", 0)
   FuelSeId    = system.pLoad("FuelSeId", 0)
   FuelSePa    = system.pLoad("FuelSePa", 0)
   
   -- can't pSave/load boolean .. translate back from string
   shortAnn = system.pLoad("shortAnn", 0) == "true"
   bingoTime = system.pLoad("bingoTime", 60)
   
   system.registerForm(1, MENU_APPS, "Geriatric Time Announcer", initForm)
   system.registerTelemetry(1, "Geriatric Timer", 4, timePrint, {"Ann", "G2", "G3", "G4"})

   readSensors()
   setLanguage()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=TimAnnVersion, name="Time Announcer"}
