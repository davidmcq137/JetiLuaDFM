--[[

   ----------------------------------------------------------------------
   DFM-Batt.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local BattVersion = "1.1"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0
local emFlag
   
local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters

local NUMBAT=12
local Battery={}
local selectedBatt
local lastBatt
local seenRX = false
local warnAnn = false
local warn2Ann = false
local stickToShake
local stickToShake2
local shakePattern
local shakePattern2
local battmAh
local battmAhSe, battmAhSeId, battmAhSePa
local row2batt={}
local warnSound
local warn2Sound
local fileBD
local writeBD = true
local lastmAh = 0

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
	 end
      end
   end
end

local function key0(key)
   local row = form.getFocusedRow() - 1
   if key == KEY_5 or key == KEY_ENTER then
      form.preventDefault()
      
      if row >= 1 and row <= NUMBAT then
	 selectedBatt = row2batt[row]
	 Battery[selectedBatt].cyc = Battery[selectedBatt].cyc + 1
	 system.playFile('/Apps/DFM-Batt/selected_battery.wav', AUDIO_QUEUE)
	 system.playNumber(selectedBatt, 0)
	 form.close(2)
      end
   end
   if key == KEY_ESC or (key == KEY_5 and row < 1) then
      form.preventDefault()
      local ans
      ans = form.question("Exit without selecting a battery?", nil, nil, 0, false, 5)
      if ans == 1 then
	 form.close(2)
	 system.playFile('/Apps/DFM-Batt/no_battery_selected.wav', AUDIO_QUEUE)
	 --seenRX = false
	 --selectedBatt = 0
      else
	 form.reinit(2)
      end
   end
end

local function close0()
end

local function initForm0()
   local str
   form.addRow(4)
   form.addLabel({label="Batt", width=40, alignRight=true, font=FONT_MINI})
   form.addLabel({label="Cap (mAh)", width=80, alignRight=true, font=FONT_MINI})
   form.addLabel({label="Warn 1 Warn 2 % Left", width=140, alignRight=true, font=FONT_MINI})
   form.addLabel({label="Cycles", width=80, alignRight=true, font=FONT_MINI})
   local row = 0
   local focusRow = 1
   for i=1,NUMBAT,1 do
      if Battery[i].cap > 0 or Battery[i].warn > 0 or Battery[i].warn2 > 0 then
	 row = row + 1
	 row2batt[row] = i
	 if i == lastBatt then
	    focusRow = 1 + row
	 end
	 form.addRow(5)
	 form.addLabel({label=i, width=40, alignRight=true})
	 str = string.format("%4d  ", Battery[i].cap)
	 form.addLabel({label=str,  width=80,  alignRight=true})
	 str = string.format("%3d   ", Battery[i].warn)
	 form.addLabel({label=str, width=60, alignRight=true})
	 str = string.format("%3d   ", Battery[i].warn2)
	 form.addLabel({label=str, width=60, alignRight=true})
	 str = string.format("%4d  ", Battery[i].cyc)
	 form.addLabel({label=str,  width=80,  alignRight=true})
      end
   end
   form.setFocusedRow(focusRow)
end

local function battChanged(value, i, sub)
   Battery[i][sub] = value
end

local function battmAhSensorChanged(value)
   battmAhSe = value
   battmAhSeId = sensorIdlist[battmAhSe]
   battmAhSePa = sensorPalist[battmAhSe]
   if battmAhSeId == "..." then
      battmAhSeId = 0
      battmAhSePa = 0
   end
end

local function warnChanged(value, num)
   warnSound = value
end

local function warn2Changed(value)
   warn2Sound = value
end

local function stickChanged(value)
   stickToShake = value
end

local function shakeChanged(value)
   shakePattern = value
end

local function stick2Changed(value)
   stickToShake2 = value
end

local function shake2Changed(value)
   shakePattern2 = value
end

local function keyForm(key)
   local row = form.getFocusedRow() - 1
   if subForm == 2 and key == KEY_1 and row >= 1 and row <= NUMBAT then
      Battery[row].cap = 0
      Battery[row].warn = 0
      Battery[row].warn2 = 0      
      Battery[row].cyc = 0
      if row == selectedBatt then
	 selectedBatt = 0
	 seenRX = false
	 system.messageBox("Warning: Cleared selected battery")
      end
      form.reinit(2)
   end

   if subForm > 1 and (key == KEY_5 or key == KEY_ENTER) then
      form.preventDefault()
      form.reinit(1)
   end
   
end

local function initForm(sf)
   subForm = sf
   if sf == 1 then
      form.addRow(2)
      form.addLink((function() form.reinit(2) end), {label="Battery Setup>>"})

      form.addRow(2)
      form.addLink((function() form.reinit(5) end), {label="Warnings>>"})      

      form.addRow(2)
      form.addLink((function() form.reinit(3) end), {label="Settings>>"})
      
      form.addRow(1)
      form.addLabel({label="DFM - v."..BattVersion.." ", font=FONT_MINI, alignRight=true})
   elseif sf == 2 then
      form.setButton(1, "Clr", 1)
      --[[
      form.addRow(4)
      form.addLabel({label="Battery", width=60, alignRight=true})
      form.addLabel({label="Cap (mAh)", width=80, alignRight=true})
      form.addLabel({label="Warn % Left", width=110, alignRight=true})
      form.addLabel({label="Cycles", width=60, alignRight=true})
      --]]
      form.addRow(4)
      form.addLabel({label="Batt", width=40, alignRight=true, font=FONT_MINI})
      form.addLabel({label="Cap (mAh)", width=80, alignRight=true, font=FONT_MINI})
      form.addLabel({label="Warn 1 Warn 2 % Left  ", width=140, alignRight=true, font=FONT_MINI})
      form.addLabel({label="Cycles", width=80, alignRight=true, font=FONT_MINI})

      for i=1,NUMBAT,1 do
	 --[[
	 form.addRow(4)
	 form.addLabel({label=i.."     ", width=60, alignRight=true})
	 form.addIntbox(Battery[i].cap, 0, 9999, 5000, 0, 10,
			(function(x) return battChanged(x, i, "cap") end),
			{width=80})
	 form.addIntbox(Battery[i].warn, 0, 100, 50, 0, 1,
			(function(x) return battChanged(x, i, "warn") end),
			{width=80})      
	 form.addIntbox(Battery[i].cyc, 0, 999, 1, 0, 1,
			(function(x) return battChanged(x, i, "cyc") end),			
			{width=80})
	 --]]
	 form.addRow(5)
	 form.addLabel({label=i.."  ", width=40, alignRight=true, font=FONT_NORMAL})
	 form.addIntbox(Battery[i].cap, 0, 9999, 5000, 0, 10,
			(function(x) return battChanged(x, i, "cap") end),
			{width=80, font=FONT_NORMAL})
	 form.addIntbox(Battery[i].warn, 0, 100, 50, 0, 1,
			(function(x) return battChanged(x, i, "warn") end),
			{width=60, font=FONT_NORMAL})
	 if not Battery[i].warn2 then Battery[i].warn2 = 0 end
	 form.addIntbox(Battery[i].warn2, 0, 100, 50, 0, 1,
			(function(x) return battChanged(x, i, "warn2") end),
			{width=60, font=FONT_NORMAL})      	 
	 form.addIntbox(Battery[i].cyc, 0, 999, 1, 0, 1,
			(function(x) return battChanged(x, i, "cyc") end),			
			{width=80, font=FONT_NORMAL})
	 
      end
   elseif sf == 3 then
      form.addRow(2)
      form.addLabel({label="Battery mAh sensor", width=220})
      form.addSelectbox(sensorLalist, battmAhSe, true, battmAhSensorChanged)
      form.addRow(2)
      form.addLink((function()
	       system.messageBox("Battery selection cleared")
	       selectedBatt = 0
	       seenRX = false
	       form.reinit(3)
		   end),
	 {label="Re-select battery"})
      form.addRow(2)
      form.addLink((function()
	       io.remove(fileBD)
	       writeBD = false
	       selectedBatt = 0
	       seenRX = false
	       system.messageBox("Data cleared - please restart App")
	       form.reinit(3)
		   end),
	 {label="Clear saved data"})
   elseif sf == 5 then
      form.addRow(2)
      form.addLabel({label="Warn 1 sound"})
      form.addAudioFilebox(warnSound or "...", warnChanged)

      form.addRow(2)
      form.addLabel({label="Warn 1 vibrate"})      
      form.addSelectbox({"Left", "Right"}, stickToShake, true, stickChanged)

      form.addRow(2)
      form.addLabel({label="Warn 1 pattern"})      
      form.addSelectbox({"None", "Long", "Short", "2x Short", "3x Short"},
	 shakePattern, true, shakeChanged)    

      form.addRow(2)
      form.addLabel({label="Warn 2 sound"})
      form.addAudioFilebox(warn2Sound or "...", warn2Changed)

      form.addRow(2)
      form.addLabel({label="Warn 2 vibrate"})      
      form.addSelectbox({"Left", "Right"}, stickToShake2, true, stick2Changed)

      form.addRow(2)
      form.addLabel({label="Warn 2 pattern"})      
      form.addSelectbox({"None", "Long", "Short", "2x Short", "3x Short"},
	 shakePattern2, true, shake2Changed)    
      
   end
end
--------------------------------------------------------------------------------

local function writeBattery()
   local fp
   local saveBatt = {}

   saveBatt.lastBatt = selectedBatt
   saveBatt.array = Battery
   saveBatt.battmAhSe = battmAhSe
   saveBatt.battmAhSeId = string.format("0X%x", battmAhSeId)
   saveBatt.battmAhSePa = battmAhSePa
   saveBatt.warnSound = warnSound
   saveBatt.warn2Sound = warn2Sound   
   saveBatt.stickToShake = stickToShake
   saveBatt.shakePattern = shakePattern
   saveBatt.stickToShake2 = stickToShake2
   saveBatt.shakePattern2 = shakePattern2
   if writeBD then
      fp = io.open(fileBD, "w")
      if fp then io.write(fp, json.encode(saveBatt), "\n") end
      io.close(fp)
   end

end

local function destroy()
   writeBattery()
end

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str, rgb)

   local d
   local txt
   local font = FONT_NORMAL
   local r, g, b

   if not val then return end
   --if val < 10 and system.getTime() % 2 == 0 then return end
   
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

local function timePrint(width, height)
   local str, strCap
   local rgb={}
   local rs,gs,bs

   if selectedBatt < 1 or selectedBatt > NUMBAT then
      str = "No Battery"
   else
      if battmAh then
	 str = string.format("Battery %d   %d mAh", selectedBatt, Battery[selectedBatt].cap - battmAh)
	 local battPct = 100 * (Battery[selectedBatt].cap - battmAh) / Battery[selectedBatt].cap
	 if  battPct <= Battery[selectedBatt].warn then
	    rgb = {r=255,g=0,b=0}
	 else
	    rgb = {r=0,g=0,b=255}
	 end
	 drawRectGaugeAbs(75, 33, 140, 25, 0, 100, battPct,"", rgb)
	 strCap = string.format("Cap %4d  Warn %4d %4d",
				Battery[selectedBatt].cap,
				Battery[selectedBatt].cap * Battery[selectedBatt].warn / 100,
				Battery[selectedBatt].cap * Battery[selectedBatt].warn2 / 100)	 

      else
	 str = "No mAh sensor"
	 --lcd.drawText(5,20,tostring(battmAhSeId) .." "..tostring(battmAhSePa).." "..
	 --tostring(battmAh))
      end
   end

   rs,gs,bs = lcd.getBgColor()
   if rs == 0 and gs == 0 and bs == 0 then
      lcd.setColor(255,255,255)
   else
      lcd.setColor(0,0,0)
   end

   if strCap then lcd.drawText(8,50, strCap, FONT_MINI) end
   lcd.drawText(4,0,str)

end

local function loop()

   local tim = system.getTimeCounter() / 1000
   
   if startTime > 0 then
      runningTime = tim-startTime
   end

   -- read current from emulated sensor to simulate discharge
   if emFlag == 1 then system.getSensorByID(battmAhSeId, 9) end
   
   local sensor = system.getSensorByID(battmAhSeId, battmAhSePa)

   if (selectedBatt >= 1 and selectedBatt <= NUMBAT) and sensor and sensor.valid then
      battmAh = sensor.value
      if not battmAh then battmAh = 0 end
      if battmAh < lastmAh then warnAnn = false end -- mui can reset to 0 after current flows
      lastmAh = battmAh
      local battPct = 100 * (Battery[selectedBatt].cap - battmAh) / Battery[selectedBatt].cap
      if selectedBatt >=1 and selectedBatt <= NUMBAT 
	 and battPct <= Battery[selectedBatt].warn
	 and Battery[selectedBatt].warn > 0
         and not warnAnn then
	    warnAnn = true
	    
	    if warnSound == "..." then
	       system.playFile('/Apps/DFM-Batt/Low_Battery.wav', AUDIO_IMMEDIATE)
	    else
	       system.playFile(warnSound, AUDIO_IMMEDIATE)
	    end
	    if shakePattern > 1 then
 	       system.vibration( (stickToShake == 2), shakePattern - 1)
	    end
      end

      if selectedBatt >=1 and selectedBatt <= NUMBAT 
	 and battPct <= Battery[selectedBatt].warn2
	 and Battery[selectedBatt].warn2 > 0      
         and not warn2Ann then
	    warn2Ann = true
	    if warn2Sound == "..." then
	       system.playFile('/Apps/DFM-Batt/low_battery_land_now.wav', AUDIO_IMMEDIATE)
	    else
	       system.playFile(warn2Sound, AUDIO_IMMEDIATE)
	    end
	    if shakePattern2 > 1 then
	       system.vibration( (stickToShake2 == 2), shakePattern2 - 1)
	    end
      end

   end
   
   local txTel = system.getTxTelemetry()

   if ( (emFlag ~= 1 and txTel.rx1Percent > 0) or (emFlag == 1 and system.getInputs("SA") == 1))
   and not seenRX then -- we see an RX
      system.registerForm(2, 0, "Select Flight Battery", initForm0, key0, nil, close0)
      startTime = system.getTimeCounter() / 1000.0
      seenRX = true
   end
end

local function init()

   local pf
   local mn
   local file
   local decoded

   emFlag = select(2, system.getDeviceType())
   if emFlag == 1 then pf = "" else pf = "/" end
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fileBD = pf .. "Apps/DFM-Batt/BD_" .. mn .. ".jsn"

   file = io.readall(fileBD)

   if file then
      decoded = json.decode(file)
      Battery = decoded.array
      lastBatt = decoded.lastBatt
      battmAhSe = decoded.battmAhSe or 0
      battmAhSeId = tonumber(decoded.battmAhSeId) or 0
      battmAhSePa = decoded.battmAhSePa or 0
      warnSound = decoded.warnSound
      warn2Sound = decoded.warn2Sound or "..."
      stickToShake = decoded.stickToShake or 1
      shakePattern = decoded.shakePattern or 1
      stickToShake2 = decoded.stickToShake2 or 1
      shakePattern2 = decoded.shakePattern2 or 1
      for i=1,NUMBAT,1 do
	 if not Battery[i] then
	    Battery[i] = {} 
	    Battery[i].cap = 0
	    Battery[i].cyc = 0
	    Battery[i].warn = 0
	    Battery[i].warn2 = 0
	 end
      end
   else
      system.messageBox("No Battery data read: initializing")
      for i=1,NUMBAT,1 do
	 Battery[i] = {}
	 Battery[i].cap = 0
	 Battery[i].cyc = 0
	 Battery[i].warn = 0
	 Battery[i].warn2 = 0	 
      end
      battmAhSe = 0
      battmAhSeId = 0
      battmAhSePa = 0
      lastBatt = 0
      warnSound = "..."
      warn2Sound = "..."
      stickToShake = 1
      shakePattern = 1
      stickToShake2 = 1
      shakePattern2 = 1
   end
   
   if not warnSound then warnSound = "..." end
   if not warn2Sound then warn2Sound = "..." end   
   
   selectedBatt = 0 -- won't be assigned till popup selects a batt
   
   system.registerForm(1, MENU_APPS, "Battery Tracker", initForm, keyForm)
   system.registerTelemetry(1, "Battery Tracker", 2, timePrint)

   readSensors()
   setLanguage()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=BattVersion, name="Battery Tracker", destroy=destroy}
