--[[

   Originally made for voice control, also works for "manual" smoke
   control, e.g. controlled by a knob or slider or switch. Oct 2019
   added a symbol string mode, a morse code mode and a
   telemetry-controlled duty cycle mode

   For voice control the program can act as an SR Flip Flop - one
   voice command turns smoke on, a second command turns it off

   Can have pump off value set to -100 or 0. Pump full-on is +100. Can
   be changed in Tx servo setup if needed

   Uses a lua control (default is 5, settable). Control (SMK) must be
   linked to a Rx output to the pump via usual Tx programming

   if a variable pump speed/volume control is defined (e.g. propo
   slider), it determines the speed of the pump when on

   Prevents startup with smoke on

   When run on the Jeti Emulator, P5 simulates the telemetry channel

   Released under MIT-license by DFM 2019
        
--]]

local smokeVersion = "1.0"
local smokeName = "Smoke Controller"

local smV, smOut
local smokeOnSw, smokeOffSw, smokeEnableSw, smokeOnVal, smokeOffVal
local smokeThrMin
local smokeVol
local startUp = true
local startUpMessage = false
local thrCtl

local sensorLalist = { "..." }
local sensorIdlist = { 0 }
local sensorPalist = { 0 }

local selFt, selFtIndex

local smokeModeIdx
local smokeModeString = {"Manual", "Symbol", "Morse", "Telem"}
local smokeModeIndex =  { Manual=1, Symbol=2, Morse=3, Telem=4}

local smokeInterval

local EGTSe, EGTPa, EGTId, EGTLa
local smokeEGTOff
local currentEGT

local runTime, runStep, lastTime

local smokeSymbol, smokeMorse, MorseCode
local smokeDutyCycle
local smokeDutyCycleIdx

local smokeSymbolIdx
local smokeMorseIdx
local smokeMorseOut = {}
local smokeLetterOut = {}

local smokeTelemSe, smokeTelemPa, smokeTelemId, smokeTelemLa
local smokeLowTelem
local smokeHighTelem
local telemReading, telemReadingRaw, telemReadingLast, telemReadingUnit
local persistOn
local loopIdx, loopChar
local smokeControl
local sensorLbl
local smokeStateON
local emulator


-- If on emulator, see if we should emulate the telem sensors from a jsn file
emulator = require('./sensorEmulator')

local function setLanguage() end

-- Read available sensors for user to select

local function readSensors()
   local k=1
   local sensors
   
   sensors = system.getSensors()
   
   for _, sensor in ipairs(sensors) do
      -- print("k,lbl,id,pa, name:",
      -- k, sensor.label, sensor.id, sensor.param, sensor.sensorName, sensor.type)

      -- print(sensor.control, sensor.controlmin, sensor.controlmax)
      
      k=k+1
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
   end
end

local function smokeOnSwChanged(value)
   smokeOnSw = value
   system.pSave("smokeOnSw",value)
end

local function smokeOffSwChanged(value)
   smokeOffSw = value
   system.pSave("smokeOffSw",value)
end

local function smokeOffValChanged(value)
   smokeOffVal = value
   system.pSave("smokeOffVal",value)
end

local function smokeEnableSwChanged(value)
   smokeEnableSw = value
   system.pSave("smokeEnableSw",value)
end

local function smokeThrMinChanged(value)
   smokeThrMin = value
   system.pSave("smokeThrMin", value)
end

local function smokeVolChanged(value)
   smokeVol = value
   system.pSave("smokeVol", value)
end

local function smokeModeChanged(value)
   smokeModeIdx = value
   system.pSave("smokeModeIdx", value)
   loopIdx = 1
end

local function smokeIntervalChanged(value)
   smokeInterval = value
   system.pSave("smokeInterval", value)
end

local function smokeEGTSensorChanged(value)
   EGTSe = value
   EGTPa = sensorPalist[EGTSe]
   EGTId = sensorIdlist[EGTSe]
   EGTLa = sensorLalist[EGTSe]
   if EGTLa == "..." then
      EGTSe = 0
      EGTId = 0
      EGTPa = 0
   end
   system.pSave("EGTSe", EGTSe)   
   system.pSave("EGTId", EGTId)
   system.pSave("EGTPa", EGTPa)
end

local function smokeEGTOffChanged(value)
   smokeEGTOff = value
   system.pSave("smokeEGTOff", value)
end

local function smokeTelemSeChanged(value)
   smokeTelemSe = value
   smokeTelemPa = sensorPalist[smokeTelemSe]
   smokeTelemId = sensorIdlist[smokeTelemSe]
   smokeTelemLa = sensorLalist[smokeTelemSe]
   if smokeTelemLa == "..." then
      smokeTelemSe = 0
      smokeTelemId = 0
      smokeTelemPa = 0
   end
   system.pSave("smokeTelemSe", smokeTelemSe)
   system.pSave("smokeTelemId", smokeTelemId)   
   system.pSave("smokeTelemPa", smokeTelemPa)
end

local function smokeLowTelemChanged(value)
   smokeLowTelem = value
   system.pSave("smokeLowTelem", value)
   loopIdx = 1
end

local function smokeHighTelemChanged(value)
   smokeHighTelem = value
   system.pSave("smokeHighTelem", value)
end

local function smokeSymbolChanged(value)
   smokeSymbolIdx = value
   system.pSave("smokeSymbolIdx", value)
   loopIdx = 1
end

local function smokeMorseChanged(value)
   smokeMorseIdx = value
   system.pSave("smokeMorseIdx", value)
   loopIdx = 1
end

local function smokeControlChanged(value)
   smokeControl = value
   system.pSave("smokeControl", value)
end

local function selFtClicked(value)
   selFt = not value
   form.setValue(selFtIndex, selFt)
   system.pSave("selFt", tostring(selFt))
end

-- Draw the main form (Application inteface)

local function initForm()

   form.addRow(2)
   form.addLabel({label="ON/OFF Switch",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeEnableSw, false, smokeEnableSwChanged)

   form.addRow(2)
   form.addLabel({label="Smoke Mode",font=FONT_NORMAL, width=220})
   form.addSelectbox(smokeModeString, smokeModeIdx, false, smokeModeChanged) 
   
   form.addRow(2)
   form.addLabel({label="Symbol String",font=FONT_NORMAL, width=220})
   form.addSelectbox(smokeSymbol.List, smokeSymbolIdx, true, smokeSymbolChanged) 

   form.addRow(2)
   form.addLabel({label="Morse String",font=FONT_NORMAL, width=220})
   form.addSelectbox(smokeMorse.List, smokeMorseIdx, true, smokeMorseChanged)

   form.addRow(2)
   form.addLabel({label="Telemetry Sensor",font=FONT_NORMAL, width=160})
   form.addSelectbox(sensorLalist, smokeTelemSe, true, smokeTelemSeChanged)

   form.addRow(2)
   form.addLabel({label="Use mph/ft or kmh/m (x) for telem", width=270})
   selFtIndex = form.addCheckbox(selFt, selFtClicked)

   form.addRow(2)
   form.addLabel({label="Low Telemetry Limit",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeLowTelem, -1000, 1000, 0, 0, 1, smokeLowTelemChanged)

   form.addRow(2)
   form.addLabel({label="High Telemetry Limit",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeHighTelem, -1000, 1000, 0, 0, 1, smokeHighTelemChanged)

   form.addRow(2)
   form.addLabel({label="Base Interval time (ms)",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeInterval, 100, 2000, 0, 0, 1, smokeIntervalChanged)

   form.addRow(2)
   form.addLabel({label="Turbine EGT Sensor",font=FONT_NORMAL, width=160})
   form.addSelectbox(sensorLalist,EGTSe, true, smokeEGTSensorChanged)
   
   form.addRow(2)
   form.addLabel({label="Low EGT Cutoff",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeEGTOff, 0, 1000, 0, 0, 1, smokeEGTOffChanged)

   form.addRow(2)
   form.addLabel({label="Variable Pump Speed Control",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeVol, true, smokeVolChanged) 

   form.addRow(2)
   form.addLabel({label="Low throttle cutoff (0-100%)",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeThrMin, 0, 100, 0, 0, 1, smokeThrMinChanged)
   
   form.addRow(2)
   form.addLabel({label="ON Voice Control (V01...V15)",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeOnSw, false, smokeOnSwChanged) 
   
   form.addRow(2)
   form.addLabel({label="OFF Voice Control (V01...V15)",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeOffSw, false, smokeOffSwChanged)

   form.addRow(2)
   form.addLabel({label="Pump OFF Value (-100% or 0%)",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeOffVal, -100, 0, -100, 0, 100, smokeOffValChanged)

   form.addRow(2)
   form.addLabel({label="Lua Control Number for SMK",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeControl, 1, 10, 5, 0, 1, smokeControlChanged)   

   form.addRow(1)
   form.addLabel({label="Version " .. smokeVersion .." ",font=FONT_MINI, alignRight=true})
end

local function printForm() end

local function loop()

   local smOn, smOff, smEn, smEnSw
   local thr 
   local vol
   local stm
   local swtbl
   local sensor
   
   -- note smV always goes -100 to 100, smOut could be -100 to 100 or 0 to 100
   -- depending on value of smokeOffVal

   -- read the switches and the proportional value for vol
   
   smOn, smOff, smEn, vol = system.getInputsVal(smokeOnSw,smokeOffSw,smokeEnableSw, smokeVol)
   smEnSw = smEn
   
   -- check if switches still assigned .. nil if never assigned .. but have to check if
   -- they were assigned and then un-assigned
   
   swtbl = system.getSwitchInfo(smokeOnSw)
   if not swtbl or not swtbl.assigned then smOn = nil end

   swtbl = system.getSwitchInfo(smokeOffSw)
   if not swtbl or not swtbl.assigned then smOff = nil end

   swtbl = system.getSwitchInfo(smokeEnableSw)
   if not swtbl or not swtbl.assigned then smEn = nil end

   -- have we defined on and off momentary/toggle switches?   
   if smOn and smOff then  
      if smOn == 1 and smOff == -1 then
	 persistOn = true
      elseif smOff == 1 and smOn == -1 then
	 persistOn = false
      end
   end

   -- smoke off if no master enable switch is defined
   if not smEn then smEn = -1 end
   
   -- but allow toggle on/off to override on/off switch
   if persistOn then smEn = 1 end
   
   -- see if throttle is below cutoff point for smoke on
   thr = system.getInputs(thrCtl)
   stm = smokeThrMin * 2 - 100
   if thr*100 < stm then
      smEn = -1
   end

   -- if EGT sensor defined, is it hot enough for smoke?
   if EGTSe ~= 0 then
      sensor = system.getSensorByID(EGTId, EGTPa)
      if sensor and sensor.valid then currentEGT = sensor.value end
      if currentEGT < smokeEGTOff then smEn = -1 end
   end

   -- see if it's time to take another time step
   runTime = system.getTimeCounter()
   
   if runTime > lastTime + smokeInterval and not startUp and smEn == 1 then
      
      if smokeModeIdx == smokeModeIndex.Symbol then
	 loopIdx = runStep % #smokeSymbol.List[smokeSymbolIdx] + 1
	 loopChar = string.sub(smokeSymbol.List[smokeSymbolIdx], loopIdx, loopIdx)
      end
      if smokeModeIdx == smokeModeIndex.Morse then
	 loopIdx = runStep % #smokeMorseOut[smokeMorseIdx] + 1
	 loopChar = string.sub(smokeMorseOut[smokeMorseIdx], loopIdx, loopIdx)
      end
      if smokeModeIdx == smokeModeIndex.Telem then
	 if smokeTelemSe ~= 0 then
	    sensor = system.getSensorByID(smokeTelemId, smokeTelemPa)
	    if sensor and sensor.valid then telemReadingRaw = sensor.value end
	    telemReadingUnit = sensor.unit
	    if sensor.unit == "m/s" then
	       if selFt then
		  telemReadingRaw = telemReadingRaw * 2.23694  -- m/s to mph
		  telemReadingUnit = "mph"
	       else
		  telemReadingRaw = telemReadingRaw * 3.6 -- m/s to kmh
		  telemReadingUnit = "kmh"
	       end
	    end
	    if sensor.unit == "m" then
	       if selFt then
		  telemReadingRaw = telemReadingRaw * 3.28084 -- m to ft
		  telemReadingUnit = "ft"
	       else
		  telemReadingUnit = "m"
	       end
	    end
	    -- clip to max and min the telem reading used to compute duty cycle
	    telemReading = math.max(math.min(telemReadingRaw, smokeHighTelem), smokeLowTelem)
	    telemReadingLast = system.getTimeCounter()
	    smokeDutyCycleIdx =
	       math.floor(1+10*(telemReading - smokeLowTelem) / (smokeHighTelem - smokeLowTelem))
	    loopIdx = runStep % #smokeDutyCycle.List[smokeDutyCycleIdx] + 1
	    loopChar = string.sub(smokeDutyCycle.List[smokeDutyCycleIdx], loopIdx, loopIdx)
	 else
	    telemReading = 0
	    telemReadingLast = 0
	    smokeDutyCycleIdx = 1
	 end
	 
      end
      runStep = runStep + 1
      lastTime = runTime
   end

   -- factor in variable speed pump if defined
   if smEn == 1 then
      if vol then smV = smokeOnVal * vol else smV = smokeOnVal end
   else
      smV = smEn * smokeOnVal
   end

   -- the '-' char represents pump off for seqence, morse and telem .. ignore for manual
   if smokeModeIdx ~= smokeModeIndex.Manual then
      if loopChar == '-' then smV = -1 * smokeOnVal end
   end

   -- check if smoke pump requires 0-100 vs -100 to 100 and adjust if needed
   smOut = smV
   if smokeOffVal == 0 then 
      smOut = (smV + 100) / 2
   end
   
   -- make sure if we are starting we get to pump off before allowing it to run
   if startUp then
      if smEn == -1 and smEnSw == -1 and not persistOn then
	 startUp = false
      else
	 smV = smokeOffVal
	 smOut = smokeOffVal
	 if not startUpMessage then
	    system.messageBox("Startup: Please turn off smoke")
	    startUpMessage = true
	 end
      end
   else
      system.setControl(smokeControl, smOut/100, 10, 0)
   end
   if smEn ~= -1 and not startUp then smokeStateON = true else smokeStateON = false end
end

local function smokeCBout()

   local y0 = 0
   local x0 = 10
   local xr0 = -6

   lcd.setColor(lcd.getFgColor())
   lcd.drawRectangle(x0+xr0, y0+4, 96, 14)
   lcd.drawLine(x0+xr0+48, y0+4, x0+48+xr0, y0+17)
   
   ss = smOut/100
   if ss >= 0 then
      lcd.drawFilledRectangle(x0+xr0+48, y0+4, ss*48, 14)
   else
      lcd.drawFilledRectangle(x0+xr0+48+math.floor(ss*48+.5), y0+4, math.floor(-48*ss+.5), 14)
   end

   lcd.drawText(103,4, smokeModeString[smokeModeIdx], FONT_MINI)

   if smokeStateON then lcd.setColor(0,255,0) else lcd.setColor(255,0,0) end
   lcd.drawFilledRectangle(143, y0+8, 5,5)
   lcd.setColor(0,0,0)
end

local function smokeCBseq()

   local y0 = 5
   local x0 = 2
   local boxSize = 4
   local idx
   local char, letter
   local winWid = 151
   local text
   
   lcd.setColor(lcd.getFgColor())

   if smokeModeIdx == smokeModeIndex.Symbol then
      idx = runStep % #smokeSymbol.List[smokeSymbolIdx] + 1
   end

   if smokeModeIdx == smokeModeIndex.Morse then
      idx = runStep % #smokeMorseOut[smokeMorseIdx] + 1
   end

   if smokeModeIdx == smokeModeIndex.Telem then
      idx = runStep % #smokeDutyCycle.List[smokeDutyCycleIdx] + 1
   end   
   
   for i=0, (winWid-4)-boxSize, boxSize do

      if smokeModeIdx == smokeModeIndex.Symbol then
	 char = string.sub(smokeSymbol.List[smokeSymbolIdx],idx,idx)
	 if char == "+" then
	    lcd.drawFilledRectangle(x0+i,y0,boxSize,boxSize)
	 end
	 idx = idx + 1
	 if idx > #smokeSymbol.List[smokeSymbolIdx] then idx = 1 end
      end
      
      if smokeModeIdx == smokeModeIndex.Morse then
	 char = string.sub(smokeMorseOut[smokeMorseIdx],idx,idx)
	 letter = string.sub(smokeLetterOut[smokeMorseIdx],idx,idx)
	 if char == "+" then
	    lcd.drawFilledRectangle(x0+i,y0,boxSize,boxSize)
	    if letter ~= " " then lcd.drawText(x0+i, y0+3, letter, FONT_MINI) end
	 end
	 idx = idx + 1
	 if idx > #smokeMorseOut[smokeMorseIdx] then idx = 1 end
      end
      
      if smokeModeIdx == smokeModeIndex.Telem then
	 char = string.sub(smokeDutyCycle.List[smokeDutyCycleIdx],idx,idx)
	 if char == "+" then
	    lcd.drawFilledRectangle(x0+i,y0,boxSize,boxSize)
	 end
	 idx = idx + 1
	 if idx > #smokeDutyCycle.List[smokeDutyCycleIdx] then idx = 1 end
      end
   end
   
   if smokeModeIdx == smokeModeIndex.Telem then
      text = string.format("Duty Cycle: %d", 10 * math.floor(smokeDutyCycleIdx-1))
      lcd.drawText(x0, y0+4,text, FONT_MINI)
      if telemReadingRaw then
	 if (system.getTimeCounter() - telemReadingLast) < 2000 then
	    text = string.format("Telem: %3.1f", telemReadingRaw)
	 else
	    text = 'Telem: ---'
	 end
	 lcd.drawText(x0+80 , y0+4,text, FONT_MINI)
      end
   end
   lcd.setColor(0,0,0)
end

local function init()

   local fg
   local mstr, char, lstr
   
   system.registerForm(1,MENU_APPS, "Smoke Controller", initForm, nil, printForm)
   system.registerTelemetry(1, "Smoke Controller Sequence", 1, smokeCBseq)
   system.registerTelemetry(2, "Smoke Controller Out SMK", 1, smokeCBout)   

   smokeOnSw =      system.pLoad("smokeOnSw")
   smokeOffSw =     system.pLoad("smokeOffSw")
   smokeEnableSw =  system.pLoad("smokeEnableSw")
   smokeOffVal =    system.pLoad("smokeOffVal", -100)
   smokeThrMin =    system.pLoad("smokeThrMin", -100)
   smokeVol =       system.pLoad("smokeVol")
   smokeModeIdx =   system.pLoad("smokeModeIdx", 1)
   smokeInterval =  system.pLoad("smokeInterval", 400)
   smokeEGTOff =    system.pLoad("smokeEGTOff", 500)
   EGTSe =          system.pLoad("EGTSe", 0)
   EGTId =          system.pLoad("EGTId", 0)   
   EGTPa =          system.pLoad("EGTPa", 0)   
   smokeTelemSe =   system.pLoad("smokeTelemSe", 0)
   smokeTelemPa =   system.pLoad("smokeTelemPa", 0)
   smokeTelemId =   system.pLoad("smokeTelemId", 0)      
   smokeLowTelem =  system.pLoad("smokeLowTelem", 0)
   smokeHighTelem = system.pLoad("smokeHighTelem", 100)
   smokeSymbolIdx = system.pLoad("smokeSymbolIdx", 1)
   smokeMorseIdx =  system.pLoad("smokeMorseIdx", 1)
   smokeControl =   system.pLoad("smokeControl", 5)
   selFt =          system.pLoad("selFt", "true")

   selFt = (selFt == "true") -- can't use booleans with pSave/pLoad
   
   smokeOnVal = 100
   smV = -100
   smOut = smokeOffVal
   system.registerControl(smokeControl, "Smoke Control", "SMK")
   system.setControl(smokeControl, smokeOffVal, 0, 0)
   
   thrCtl = "P4"
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   if fg then
      modelProps=json.decode(fg)
      thrCtl = modelProps.throttleChannel
   end

   fg = io.readall("Apps/DFM-Smoke/Symbol.jsn")
   if fg then
      smokeSymbol = json.decode(fg)
   else
      system.messageBox("Cannot load Apps/DFM-Smoke/Symbol.jsn")
   end
   
   -- leave only "+" and "-" in the string
   
   for i = 1, #smokeSymbol.List do
      smokeSymbol.List[i] = string.gsub(smokeSymbol.List[i], '[^%+%-]', '')
   end
   
   fg = io.readall("Apps/DFM-Smoke/MorseCode.jsn")
   if fg then
      MorseCode = json.decode(fg)
   else
      system.messageBox("Cannot load DFM-Smoke/MorseCode.jsn")
   end
   
   fg = io.readall("Apps/DFM-Smoke/Morse.jsn")
   if fg then
      smokeMorse = json.decode(fg)
   else
      system.messageBox("Cannot load Apps/DFM-Smoke/Morse.jsn")
   end

   -- convert the strings to Morse Code. First, leave only letters and spaces
   -- then upper-casify the letters
   
   for i = 1, #smokeMorse.List do

      smokeMorse.List[i] = string.gsub(smokeMorse.List[i], '[^%a%s]', '')
      smokeMorse.List[i] = string.upper(smokeMorse.List[i])
      
      -- build the morse string and the letter to print below it

      mstr = ''
      lstr = ''

      for j = 1, #smokeMorse.List[i] do

	 char = string.sub(smokeMorse.List[i], j, j)

	 if char == " " then
	    mstr = mstr .. "-------"
	    lstr = lstr .. "       "
	 else
	    mstr = mstr .. MorseCode[char] .. "---"
	    lstr = lstr .. char .. string.rep(" ", #MorseCode[char]-1) .. "   "
	 end
	 
	 if j == #smokeMorse.List[i] then
	    mstr = mstr .. "-------"
	    lstr = lstr .. "       "
	 end
	 
      end
      smokeMorseOut[i] = mstr
      smokeLetterOut[i] = lstr
   end
   
   fg = io.readall("Apps/DFM-Smoke/DutyCycle.jsn")
   if fg then
      smokeDutyCycle = json.decode(fg)
      smokeDutyCycleIdx = 1
   else
      print("Cannot load Apps/DFM-Smoke/DutyCycle.jsn")
   end

   if emulator then emulator.init("DFM-Smoke") end

   lastTime = 0
   runStep = 0
   persistOn = false
   telemReading = 0
   telemReadingRaw = 0   
   telemReadingLast = 0
   currentEGT = 0
   smokeStateON = false
   
   readSensors()
   setLanguage()   
	 
   system.playFile('/Apps/DFM-Smoke/Smoke_Controller_Active.wav', AUDIO_QUEUE)

end

return {init=init, loop=loop, author="DFM", version=smokeVersion, name=smokeName}
