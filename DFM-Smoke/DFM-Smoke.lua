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

   This is because autothrottle uses control #1, and the chute
   controller uses 2,3,4

   if a variable pump speed/volume control is defined (e.g. propo
   slider), it determines the speed of the pump when on

   Prevents startup with smoke on

   Released under MIT-license by DFM 2019
        
--]]

local smokeName    = "Smoke Controller"
local smokeVersion = "1.0"
local smokeAuthor  = "DFM"

local modelProps

local smV, smOut
local smokeOnSw, smokeOffSw, smokeEnableSw, smokeContSw
local smokeOnVal, smokeOffVal
local smokeThrMin
local smokeVol
local startUp = true
local startUpMessage = false
local safetyOff
local thrCtl

local sensorLalist = { "..." }
local sensorIdlist = { 0 }
local sensorPalist = { 0 }
local formMode

local selFt, selFtIndex

local smokeModeIdx
local smokeModeString = {"Manual", "Symbol", "Morse", "Telem"}
local smokeModeIndex =  { Manual=1, Symbol=2, Morse=3, Telem=4}
local smokeModeAvail =  { Manual=true, Symbol = false, Morse = false, Telem = false}

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
local smokeState

local function setLanguage() end

-- Read available sensors for user to select

local function readSensors()

   local sensors
   
   sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
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
   startUp = true
   startUpMessage = false
end

local function smokeContSwChanged(value)
   smokeContSw = value
   system.pSave("smokeContSw",value)
   startUp = true
   startUpMessage = false
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
   if smokeModeAvail[smokeModeString[value]]  then
      smokeModeIdx = value
      system.pSave("smokeModeIdx", value)
      loopIdx = 1
   else
      smokeModeIdx = 1
      form.setValue(formMode, smokeModeIdx)
      system.pSave("smokeModeIdx", 1)
   end
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
   smokeLowTelem = value / 10
   system.pSave("smokeLowTelem", value)
   loopIdx = 1
end

local function smokeHighTelemChanged(value)
   smokeHighTelem = value / 10
   system.pSave("smokeHighTelem", value)
   loopIdx = 1
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
   form.addLabel({label="Sequence Enable Switch",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeEnableSw, false, smokeEnableSwChanged)

   form.addRow(2)
   form.addLabel({label="Continuous ON Switch",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeContSw, false, smokeContSwChanged)

   form.addRow(2)
   form.addLabel({label="Smoke Mode",font=FONT_NORMAL, width=220})
   formMode = form.addSelectbox(smokeModeString, smokeModeIdx, false, smokeModeChanged) 
   --print("formMode:", formMode)

   if smokeModeAvail.Symbol then
      form.addRow(2)
      form.addLabel({label="Symbol String",font=FONT_NORMAL, width=220})
      form.addSelectbox(smokeSymbol.List, smokeSymbolIdx, true, smokeSymbolChanged)
   end

   if smokeModeAvail.Morse then
      form.addRow(2)
      form.addLabel({label="Morse String",font=FONT_NORMAL, width=220})
      form.addSelectbox(smokeMorse.List, smokeMorseIdx, true, smokeMorseChanged)
   end

   if smokeModeAvail.Telem then
      form.addRow(2)
      form.addLabel({label="Telemetry Sensor",font=FONT_NORMAL, width=160})
      form.addSelectbox(sensorLalist, smokeTelemSe, true, smokeTelemSeChanged)
   end
   
   form.addRow(2)
   form.addLabel({label="Use mph/ft or kmh/m (x) for telem", width=270})
   selFtIndex = form.addCheckbox(selFt, selFtClicked)

   form.addRow(2)
   form.addLabel({label="Low Telemetry Limit",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeLowTelem*10, -10000, 10000, 0, 1, 1, smokeLowTelemChanged)

   form.addRow(2)
   form.addLabel({label="High Telemetry Limit",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeHighTelem*10, -10000, 10000, 0, 1, 1, smokeHighTelemChanged)

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

   --[[
   form.addRow(2)
   form.addLabel({label="ON Voice Control (V01...V15)",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeOnSw, false, smokeOnSwChanged) 
   
   form.addRow(2)
   form.addLabel({label="OFF Voice Control (V01...V15)",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeOffSw, false, smokeOffSwChanged)
   --]]
   
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

   local smOn, smOff, smEn, smEnSw, smCn, smCnSw
   local notEn, notCn
   local thr 
   local vol
   local stm
   local swtbl
   local sensor
   local negativeTime, runCond
   
   -- note smV always goes -100 to 100, smOut could be -100 to 100 or 0 to 100
   -- depending on value of smokeOffVal

   -- read the switches and the proportional value for vol
   
   smOn, smOff, smEn, smCn, vol =
      system.getInputsVal(smokeOnSw,smokeOffSw,smokeEnableSw, smokeContSw, smokeVol)

   -- check if switches still assigned .. nil if never assigned .. but have to check if
   -- they were assigned and then un-assigned
   
   swtbl = system.getSwitchInfo(smokeOnSw)
   if not swtbl or not swtbl.assigned then smOn = nil end

   swtbl = system.getSwitchInfo(smokeOffSw)
   if not swtbl or not swtbl.assigned then smOff = nil end

   swtbl = system.getSwitchInfo(smokeEnableSw)
   if not swtbl or not swtbl.assigned then smEn = nil end

   swtbl = system.getSwitchInfo(smokeContSw)
   if not swtbl or not swtbl.assigned then smCn = nil end   

   swtbl = system.getSwitchInfo(smokeVol)
   if not swtbl or not swtbl.assigned then vol = nil end

   --note and store position of enable and continouos switch if defined
   smEnSw = smEn
   smCnSw = smCn
   
   -- have we defined on and off momentary/toggle switches?   
   if smOn and smOff then  
      if smOn == 1 and smOff == -1 then
	 persistOn = true
      elseif smOff == 1 and smOn == -1 then
	 persistOn = false
      end
   end

   -- smoke off if no master enable switch is defined
   if not smEn then
      smEn = -1
   end
   
   -- but allow toggle on/off to override on/off switch
   --if persistOn then smEn = 1 end

   safetyOff = false
   
   -- see if throttle is below cutoff point for smoke on
   thr = system.getInputs(thrCtl)
   stm = smokeThrMin * 2 - 100
   if thr*100 < stm then
      smEn = -1
      safetyOff = true
   end

   -- if EGT sensor defined, is it hot enough for smoke?
   if EGTSe ~= 0 then
      sensor = system.getSensorByID(EGTId, EGTPa)
      if sensor and sensor.valid then currentEGT = sensor.value end
      if currentEGT < smokeEGTOff then
	 smEn = -1
	 safetyOff = true
      end
   end

   -- see if it's time to take another time step
   runTime = system.getTimeCounter()

   -- getTimeCounter() returns a signed long int .. so can wrap to negative number
   -- API doc says getTimeCounter counts from 0 at TX reset. Presumably this means powerup
   -- so no chance of this wrapping on an actual TX .. but can (and does) happen on
   -- the emulator. 

   if runTime < 0 then negativeTime = true end

   --if runTime % 10000 <= 30 then
      --print("time:", system.getTimeCounter(), "time to neg (d):", (2^31-system.getTimeCounter())/(1000*86400))
   --end
      
   if negativeTime then
      if runTime % 1000 <= 30 then print("Negative Time!") end
      runCond = math.abs(runTime) < math.abs(lastTime) - smokeInterval
   else
      runCond = runTime > lastTime + smokeInterval
   end
         
   if runCond and not startUp and (smEn == 1 or smCn == 1) then

      --if smEn == -1 and smCn == 1 then loopChar = "+" end -- continuous smoke mode
      if smCn == 1 then -- continuous smoke mode
	 loopChar = "+"
      elseif smokeModeIdx == smokeModeIndex.Symbol then
	 loopIdx = runStep % #smokeSymbol.List[smokeSymbolIdx] + 1
	 loopChar = string.sub(smokeSymbol.List[smokeSymbolIdx], loopIdx, loopIdx)
      elseif smokeModeIdx == smokeModeIndex.Morse then
	 loopIdx = runStep % #smokeMorseOut[smokeMorseIdx] + 1
	 loopChar = string.sub(smokeMorseOut[smokeMorseIdx], loopIdx, loopIdx)
	 --print("loopIdx, loopChar", loopIdx, loopChar)
	 local inaRow = 0
	 if loopIdx + 2 < #smokeMorseOut[smokeMorseIdx] then
	    for k = 0,2,1 do
	       if string.sub(smokeMorseOut[smokeMorseIdx], loopIdx+k, loopIdx+k) == "+" then
		  inaRow = inaRow + 1
	       end
	    end
	 end
	 if inaRow == 3 then
	    --print("3P")
	    system.playBeep(0, 800, smokeInterval*3)
	 end
	 -- note if loopIdx == 1 then string.sub with loopIdx -1 will return ""
	 -- so the loopIdx check will work correctly, it won't be "+"
	 -- if loopIdx == #smokeMorseOut[smokeMorseIdx] then string.sub with loopIdx + 1
	 -- will return "" and also work correctly. nice.
	 if loopChar == "+" and
	    string.sub(smokeMorseOut[smokeMorseIdx], loopIdx-1, loopIdx-1)~= "+" and
	    string.sub(smokeMorseOut[smokeMorseIdx], loopIdx+1, loopIdx+1)~= "+" then	    
	    --print("1P")
	    system.playBeep(0, 800, smokeInterval)
	 end
	 

      elseif smokeModeIdx == smokeModeIndex.Telem then
	 if smokeTelemSe ~= 0 then
	    sensor = system.getSensorByID(smokeTelemId, smokeTelemPa)
	    --print("sensor, sensor.valid, sensor.value", sensor, sensor.valid, sensor.value)
	    if sensor and sensor.valid then
	       telemReadingRaw = sensor.value
	       telemReadingUnit = sensor.unit
	       --print("sensor.unit:", sensor.unit)
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
	    end
	    -- clip to max and min the telem reading used to compute duty cycle
	    telemReading = math.max(math.min(telemReadingRaw, smokeHighTelem), smokeLowTelem)
	    --print("raw, read:", telemReadingRaw, telemReading)
	    telemReadingLast = system.getTimeCounter()
	    smokeDutyCycleIdx =
	       math.floor(1+10*(telemReading - smokeLowTelem) / (smokeHighTelem - smokeLowTelem))
	    --print(smokeDutyCycleIdx)
	    smokeDutyCycleIdx = math.min(11, math.max(1, smokeDutyCycleIdx)) -- defensive
	    loopIdx = runStep % #smokeDutyCycle.List[smokeDutyCycleIdx] + 1
	    loopChar = string.sub(smokeDutyCycle.List[smokeDutyCycleIdx], loopIdx, loopIdx)
	 else
	    telemReading = 0
	    telemReadingLast = 0
	    smokeDutyCycleIdx = 1
	    loopChar = '-' -- make sure smoke off if no sensor
	 end
      end
      runStep = runStep + 1
      lastTime = runTime
   end

   -- factor in variable speed pump if defined
   if smEn == 1 or smCn == 1 then
      if vol then smV = smokeOnVal * vol else smV = smokeOnVal end
   else
      smV = -1 * smokeOnVal
   end

   -- the '-' char represents pump off for seqence, morse and telem .. ignore for manual
   -- and for continuous
   --print("smokeModeIdx, smCn: ", smokeModeIdx, smCn)
   
   if smokeModeIdx ~= smokeModeIndex.Manual or smCn == -1 then
      if loopChar == '-' then smV = -1 * smokeOnVal end
   end

   -- check if smoke pump requires 0-100 vs -100 to 100 and adjust if needed
   
   smOut = smV
   
   if smokeOffVal == 0 then 
      smOut = (smV + 100) / 2
   end

   -- make sure if we are starting we get to pump off before allowing it to run
   -- if enable switch is defined, then it must be off (not smEnSw or smEnSw == -1)
   -- if contin switch is defined, then it must be off (not smCnSw or smCnSw == -1)

   if startUp then
      notEn = (smEn == -1) and (not smEnSw or smEnSw == -1)
      notCn = not smCnSw or smCnSw == -1
      if (notEn and notCn) then --and (not persistOn) then      
	 --if smEn == -1 and (not smEnSw or smEnSw == -1) and not persistOn then
	 --print("startUP false")
	 startUp = false
      else
	 smV = smokeOffVal
	 smOut = smokeOffVal
	 if not startUpMessage then
	    system.messageBox("Startup: Please turn off smoke", 3)
	    startUpMessage = true
	 end
      end
   else
      if safetyOff then -- last check on throttle pos and EGT
	 smV = smokeOffVal
	 smOut = smokeOffVal
      end
      
      system.setControl(smokeControl, smOut/100, 10, 0)
   end
   if not startUp then
      if smEn == 1 and smCn == -1 then
	 smokeState = 1
      elseif smCn == 1 then
	 smokeState = 2
      else
	 smokeState=0
      end
   end
end

local function smokeCBout()

   local y0 = 0
   local x0 = 10
   local xr0 = -6
   local y00 = 0

   lcd.setColor(lcd.getFgColor())
   lcd.drawRectangle(x0+xr0, y0+4, 96, 14)
   lcd.drawLine(x0+xr0+48, y0+4, x0+48+xr0, y0+17)

   local ss = smOut/100
   if ss >= 0 then
      lcd.drawFilledRectangle(x0+xr0+48, y0+4, ss*48, 14)
   else
      lcd.drawFilledRectangle(x0+xr0+48+math.floor(ss*48+.5), y0+4, math.floor(-48*ss+.5), 14)
   end

   if smokeState == 0 then
      lcd.drawText(103,y00, "Off", FONT_MINI)
      lcd.setColor(255,0,0) -- red
   elseif smokeState == 1 then
      lcd.drawText(103,y00, smokeModeString[smokeModeIdx], FONT_MINI)
      lcd.setColor(0,255,0) --green
   elseif smokeState == 2 then
      lcd.drawText(103,y00, "Cont", FONT_MINI)
      lcd.setColor(0,0,255) --blue
   end

   lcd.drawFilledRectangle(143, y0+y00+5, 5,5)
   
   if safetyOff then
      lcd.setColor(255,0,0)
      lcd.drawText(103, y00+9, "Safety", FONT_MINI)
   else
      lcd.setColor(lcd.getFgColor())
      lcd.drawText(103, y00+9, "Enabled", FONT_MINI)      
   end
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
   
   if smokeModeIdx == smokeModeIndex.Manual then
      lcd.drawText(x0, y0, "Manual Control", FONT_MINI)
   end
   
   if smokeModeIdx == smokeModeIndex.Telem then
      text = string.format("Duty Cycle: %d", 10 * math.floor(smokeDutyCycleIdx-1))
      lcd.drawText(x0, y0+4,text, FONT_MINI)
      if telemReadingRaw then
	 if (system.getTimeCounter() - telemReadingLast) < 2000 then
	    text = string.format("%3.1f %s", telemReadingRaw, telemReadingUnit)
	 else
	    text = '---'
	 end
	 lcd.drawText(x0+90 , y0+4,text, FONT_MINI)
      end
   end
   lcd.setColor(0,0,0)
end

local function init()

   local fg
   local mstr, char, lstr
   local pcallOK, pcallRet
   local emulator
   
--   pcallOK, emulator = pcall(require, "sensorEmulator")
--   print("pcallOK, emulator", pcallOK, emulator)
--   if pcallOK and emulator then emulator.init("DFM-Smoke") end
   
   system.registerForm(1,MENU_APPS, "Smoke Controller", initForm, nil, printForm)
   system.registerTelemetry(1, "Smoke Controller Sequence", 1, smokeCBseq)
   system.registerTelemetry(2, "Smoke Controller Out SMK", 1, smokeCBout)   

   smokeOnSw =      system.pLoad("smokeOnSw")
   smokeOffSw =     system.pLoad("smokeOffSw")
   smokeEnableSw =  system.pLoad("smokeEnableSw")
   smokeContSw =    system.pLoad("smokeContSw")   
   smokeOffVal =    system.pLoad("smokeOffVal", -100)
   smokeThrMin =    system.pLoad("smokeThrMin", 20)
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
   smokeLowTelem =  system.pLoad("smokeLowTelem", 0) / 10
   smokeHighTelem = system.pLoad("smokeHighTelem", 100) / 10
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
      pcallOK, pcallRet = pcall(json.decode, fg)
      if pcallOK then
	 smokeSymbol = pcallRet
	 smokeModeAvail.Symbol = true
      else
	 system.messageBox("Error decoding Symbol.jsn", 2)
	 print("Error decoding Apps/DFM-Smoke/Symbol.jsn: " .. (pcallRet or ''))
      end
   else
      system.messageBox("Cannot load Symbol.jsn", 2)
      print("Cannot load Apps/DFM-Smoke/Symbol.jsn")      
   end

   -- if we loaded the jsn files...
   -- leave only "+" and "-" in the symbol string
   if smokeModeAvail.Symbol then
      for i = 1, #smokeSymbol.List do
	 smokeSymbol.List[i] = string.gsub(smokeSymbol.List[i], '[^%+%-]', '')
      end
   end
   
   -- now read the Morse Code translation table
   fg = io.readall("Apps/DFM-Smoke/MorseCode.jsn")
   if fg then
      pcallOK, pcallRet = pcall(json.decode, fg)
      if pcallOK then
	 MorseCode = pcallRet
	 smokeModeAvail.Morse = true
      else
	 system.messageBox("Error decoding MorseCode.jsn", 2)
	 print("Error decoding Apps/DFM-Smoke/MorseCode.jsn: " .. (pcallRet or ''))
      end
   else
      system.messageBox("Cannot load MorseCode.jsn", 3)
      print("Cannot load Apps/DFM-Smoke/MorseCode.jsn")      
   end

   -- now read user Morse Code strings
   fg = io.readall("Apps/DFM-Smoke/Morse.jsn")
   if fg then
      pcallOK, pcallRet = pcall(json.decode, fg)
      if pcallOK then
	 smokeMorse = pcallRet
	 smokeModeAvail.Morse = smokeModeAvail.Morse and true -- need MorseCode.jsn and Morse.jsn
      else
	 system.messageBox("Error decoding DutyCycle.jsn", 2)
	 print("Error decoding Apps/DFM-Smoke/Morse.jsn: " .. (pcallRet or ''))
      end
   else
      system.messageBox("Cannot load Morse.jsn", 2)
      print("Cannot load Apps/DFM-Smoke/Morse.jsn")      
   end

   -- if we have loaded the two jsn files ...
   -- convert the strings to Morse Code. First, leave only letters, digits and spaces
   -- then upper-casify the letters
   
   if smokeModeAvail.Morse then
      for i = 1, #smokeMorse.List do

	 smokeMorse.List[i] = string.gsub(smokeMorse.List[i], '[^%a%s%d]', '')
	 smokeMorse.List[i] = string.upper(smokeMorse.List[i])
	 -- print(i, smokeMorse.List[i])
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
   end

   -- read in the +- strings for various duty cycles
   fg = io.readall("Apps/DFM-Smoke/DutyCycle.jsn")
   if fg then
      pcallOK, pcallRet = pcall(json.decode, fg)
      if pcallOK then
	 smokeDutyCycle = pcallRet
	 smokeDutyCycleIdx = 1
	 smokeModeAvail.Telem = true
      else
	 system.messageBox("Error decoding DutyCycle.jsn", 2)
	 print("Error decoding Apps/DFM-Smoke/DutyCycle.jsn: " .. (pcallRet or ''))
	 smokeDutyCycleIdx = 0
      end
   else
      system.messageBox("Cannot read DutyCycle.jsn", 2)
      print("Cannot load Apps/DFM-Smoke/DutyCycle.jsn")
      smokeDutyCycleIdx = 0
   end
   
   lastTime = 0
   runStep = 0
   persistOn = false
   telemReading = 0
   telemReadingRaw = 0   
   telemReadingLast = 0
   currentEGT = 0
   smokeState = 0
   sensorLbl = "***" -- to debug Gary's issue on the Havoc
   -- apparently it is possible to have an item at the top of the sensor list that is not
   -- preceeded by a header, so sensorLbl is nil the first time thru the loop. In Gary's
   -- case this was an RX input pin, so put "***" there just in case...
   
   readSensors()
   setLanguage()   

   --dump(_G,"") -- print all globals
   
   system.playFile('/Apps/DFM-Smoke/Smoke_Controller_Active.wav', AUDIO_QUEUE)

end

return {init=init, loop=loop, author=smokeAuthor, version=smokeVersion, name=smokeName}
