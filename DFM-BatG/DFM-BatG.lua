--[[
   ----------------------------------------------------------------------
   DFM-BatG.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local BattVersion = "0.2"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0
local emFlag
   
local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters

local NUMSLOT=12
local Battery={}
local selectedSlot
local gblBattery={}
local lastSlot
local seenRX = false
local warnAnn = false
local warn2Ann = false
local stickToShake
local stickToShake2
local shakePattern
local shakePattern2
local battmAh
local battmAhSe, battmAhSeId, battmAhSePa
local warnSound
local warn2Sound
local fileBD
local writeBD = true
local fileBDG
local writeBDG = true

local lastmAh = 0

local savedRow

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

local function resetGbl(i)
   gblBattery[i].cap = 0
   gblBattery[i].cyc = 0
   gblBattery[i].warn = 0
   gblBattery[i].warn2 = 0
   gblBattery[i].text = ".."
end

local function wcDelete(pathIn, pre, typ)

   local dd, fn, ext
   local path

   if select(2, system.getDeviceType()) ~= 1 then
      path = "/" .. pathIn
   else
      path = pathIn
   end      

   for name, filetype, size in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == string.lower(typ) and string.find(fn, pre) == 1 then
	    local ff = path .. "/" .. fn .. "." .. ext
	    if not io.remove(ff) then
	       print("failed to delete " .. ff)
	    end
	 end
      end
   end
end

local function key0(key)

   local row = form.getFocusedRow()

   if key == KEY_5 or key == KEY_ENTER then
      form.preventDefault()
      selectedSlot = 0
      if row >= 1 and row <= #Battery  then
	 selectedSlot = row
	 if selectedSlot > 0 and Battery[selectedSlot] > 0 then
	    gblBattery[Battery[selectedSlot]].cyc =
	       gblBattery[Battery[selectedSlot]].cyc + 1
	    system.playFile('/Apps/DFM-BatG/selected_battery.wav', AUDIO_IMMEDIATE)
	    system.playNumber(Battery[selectedSlot], 0)
	 else
	    system.playFile('/Apps/DFM-BatG/no_battery_selected.wav', AUDIO_IMMEDIATE)	    
	 end
	 form.close(2)
      end
   end

   if key == KEY_ESC or (key == KEY_5 and row < 1) then
      form.preventDefault()
      local ans
      ans = form.question("Exit without selecting a battery?", nil, nil, 0, false, 5)
      if ans == 1 then
	 form.close(2)
	 system.playFile('/Apps/DFM-BatG/no_battery_selected.wav', AUDIO_IMMEDIATE)
      else
	 form.reinit(2)
      end
   end
end

local function close0()
end


local function initForm0()
   local str
   local row = 0
   local focusRow = 1
   print("initForm0, #Battery", #Battery)
   for i=1,#Battery,1 do
      if (Battery[i] >= 1 and Battery[i] <= #gblBattery) and
	 (gblBattery[Battery[i]].cap > 0 or gblBattery[Battery[i]].warn > 0
	  or gblBattery[Battery[i]].warn2 > 0) then
	 row = row + 1
	 if i == lastSlot then
	    focusRow = row
	 end
	 form.addRow(1)
	 local str
	 local gB = gblBattery[Battery[i]]
	 str = string.format("Battery %d  [", Battery[i]) ..
	    string.format("Cap %d ", gB.cap) ..
	    string.format("W1 %d%% ", gB.warn) ..
	    string.format("W2 %d%% ", gB.warn2) .. 
	    string.format("Cyc %d]", gB.cyc)
	 form.addLabel({label=str, width=320, alignRight=false})
      end
   end
   if row == 0 then
      form.addRow(1)
      form.addLabel({label="No batteries defined"})
   end
   
   form.setFocusedRow(focusRow)
end

local function textBattChanged(value, i)
   Battery[i] = value - 1
end

local function gblBattChanged(value, i, sub)
   gblBattery[i][sub] = value
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

local function warnChanged(value)
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


local function textChanged(value, i)
   gblBattery[savedRow].text = value
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   local row = form.getFocusedRow()
   if subForm == 2 and key == KEY_1 and row >= 1 and row <= #Battery then
      Battery[row] = 0
      if row == selectedSlot then
	 selectedSlot = 0
	 seenRX = false
	 system.messageBox("Warning: Cleared selected battery")
      end
      form.reinit(2)
   end

   if subForm == 2 and key == KEY_2 then
      Battery[#Battery + 1] = 0
      form.reinit(2)
   end
   
   if subForm == 2 and keyExit(key)  then
      form.preventDefault()
      form.reinit(1)
   end

   if subForm == 3 and keyExit(key) then
      form.preventDefault()
      form.reinit(1)
   end
   if subForm == 4 then row = row - 1 end -- sf 4 has labels at top
   if subForm == 4 and key == KEY_1 and row >= 1 and row  <= #gblBattery then
      resetGbl(row)
      form.reinit(4)
   end

   if subForm == 4 and key == KEY_2 then
      local i = #gblBattery + 1
      gblBattery[i] = {}
      resetGbl(i)
      form.reinit(4)
   end

   if subForm == 4 and key == KEY_3 and row > 0 then
      savedRow = row
      form.reinit(5)
   end
   
   if subForm == 4 and keyExit(key) then
      form.preventDefault()
      form.reinit(1)
   end

   if subForm == 6 and keyExit(key) then
      form.preventDefault()
      form.reinit(1)
   end

   if subForm == 5 and keyExit(key) then
      form.preventDefault()
      form.reinit(4)
   end

end

local function initForm(sf)
   local str
   subForm = sf
   if sf == 1 then
      form.setTitle("Battery Tracker")
      form.addRow(2)
      form.addLink((function() form.reinit(2) end), {label="Model Setup>>"})

      form.addRow(2) 
      form.addLink((function() form.reinit(4) end), {label="Battery Setup>>"})
      
      form.addRow(2) 
      form.addLink((function() form.reinit(6) end), {label="Warnings>>"})

      form.addRow(2)
      form.addLink((function() form.reinit(3) end), {label="Settings>>"})      

      form.addRow(1)
      form.addLabel({label="DFM - v."..BattVersion.." ", font=FONT_MINI, alignRight=true})
   elseif sf == 2 then
      form.setTitle("Selected Batteries")
      form.setButton(1, "Clr", 1)
      form.setButton(2, ":add", 1)
      local intTbl = {}
      intTbl[1] = "..."
      for j=1,#gblBattery, 1 do
	 local str
	 intTbl[j+1] = string.format("Battery %2d   ", j) .. 
	    string.format("[Capacity %4d  ", gblBattery[j].cap) .. 
	    string.format("Cycles %3d]", gblBattery[j].cyc)
      end
      for i=1,#Battery,1 do
	 
	 form.addRow(1)		
	 form.addSelectbox(intTbl, Battery[i] + 1, true, function(x) textBattChanged(x, i) end,
			   {width=320, alignRight=false,font=FONT_NORMAL})
	 
      end
   elseif sf == 3 then
      form.setTitle("Settings")
      form.addRow(2)
      form.addLabel({label="Battery mAh sensor", width=220})
      form.addSelectbox(sensorLalist, battmAhSe, true, battmAhSensorChanged)


      form.addRow(2)
      form.addLink((function()
	       system.messageBox("Battery selection cleared")
	       selectedSlot = 0
	       seenRX = false
	       form.reinit(3)
		   end),
	 {label="Re-select battery"})

      form.addRow(2)
      form.addLink((function()
	       io.remove(fileBD)
	       writeBD = false
	       selectedSlot = 0
	       --seenRX = false
	       system.messageBox("Model data cleared - restart App")
	       form.reinit(3)
		   end),
	 {label="Clear model battery data", width=220})
      
      form.addRow(2)
      form.addLink((function()
	       local ans
	       ans = form.question("Are you sure?", "Delete global battery entries?", "(also deletes all model battery data)", 0, false, 5)
	       if ans ~= 1 then
		  form.reinit(3)
	       else
		  writeBDG = false
		  gblBattery = {}
		  gblBattery[1] = {}
		  resetGbl(1)
		  writeBD = false
		  selectedSlot = 0
		  wcDelete("Apps/DFM-BatG", "BD_", "jsn")
		  system.messageBox("Battery info cleared - restart App")
		  form.reinit(3)
	       end
		   end),
	 {label="Clear global battery data", width=220})
      
   elseif sf == 4 then
      form.setTitle("Battery Setup")
      form.setButton(1, "Clr", 1)
      form.setButton(2, ":add", 1)
      form.setButton(3, ":edit", 1)
      form.addRow(4)
      form.addLabel({label="Batt", width=40, alignRight=true, font=FONT_MINI})
      form.addLabel({label="Cap (mAh)", width=80, alignRight=true, font=FONT_MINI})
      form.addLabel({label="Warn 1 Warn 2 % Left  ", width=140, alignRight=true, font=FONT_MINI})
      form.addLabel({label="Cycles", width=80, alignRight=true, font=FONT_MINI})

      for i=1,#gblBattery,1 do
	 form.addRow(5)
	 form.addLabel({label=i.."  ", width=40, alignRight=true, font=FONT_NORMAL})
	 form.addIntbox(gblBattery[i].cap, 0, 9999, 5000, 0, 10,
			(function(x) return gblBattChanged(x, i, "cap") end),
			{width=80, font=FONT_NORMAL})
	 form.addIntbox(gblBattery[i].warn, 0, 100, 50, 0, 1,
			(function(x) return gblBattChanged(x, i, "warn") end),
			{width=60, font=FONT_NORMAL})
	 if not gblBattery[i].warn2 then gblBattery[i].warn2 = 0 end
	 form.addIntbox(gblBattery[i].warn2, 0, 100, 50, 0, 1,
			(function(x) return gblBattChanged(x, i, "warn2") end),
			{width=60, font=FONT_NORMAL})      	 
	 form.addIntbox(gblBattery[i].cyc, 0, 999, 1, 0, 1,
			(function(x) return gblBattChanged(x, i, "cyc") end),			
			{width=80, font=FONT_NORMAL})
      end
   elseif sf == 5 then

      form.setTitle(string.format("Battery %d", savedRow))
      form.addRow(2)
      form.addLabel({label="Label Text", width = 80})
      form.addTextbox(gblBattery[savedRow].text, 63,
		      (function(x) return textChanged(x, savedRow) end),
		      {width=240, alignRight=false})
      local fn = string.format("Img/BatG%02d.PNG", savedRow)
      local ft = io.open(fn, "r")
      if ft then io.close(ft) end
      if ft then
	 form.addIcon(fn, {height=100})
      else
	 form.addLabel({label="File " .. fn .. " not found"})
      end
      
   elseif sf == 6 then
      form.setTitle("Warnings")
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
   
   saveBatt.lastSlot = selectedSlot
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
      if fp then
	 io.write(fp, json.encode(saveBatt), "\n") 
	 io.close(fp)
      end
   end

   if writeBDG then
      fp = io.open(fileBDG, "w")
      if fp then io.write(fp, json.encode(gblBattery), "\n")
	 io.close(fp)
      end
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

local hmin, hmax

local function fooPrint(w,h)

   local max = 1000
   local theta
   local x0, y0 = 40, 34
   local ri = 22
   local ro = 30
   local val
   local a0d = -35
   local a0 = math.rad(a0d)
   local aRd = -a0d*2 + 180
   local aR = math.rad(aRd)
   local ren = lcd.renderer()
   

   val = max / 2.0 * (1 + system.getInputs("P1"))

   if not hmin then
      hmin = val
   else
      if val < hmin then hmin = val end
   end
   
   if not hmax then
      hmax = val
   else
      if val > hmax then hmax = val end
   end

   theta = aR * val/max 
	 
   ren:reset()

   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   

   local im = 20
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*aR/im), y0 - ro * math.sin(a0 + i*aR/im))
   end

   ren:addPoint(x0 - ro * math.cos(a0+aR), y0 - ro * math.sin(a0+aR))
   ren:addPoint(x0 - ri * math.cos(a0+aR), y0 - ri * math.sin(a0+aR))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*aR/im), y0 - ri * math.sin(a0+i*aR/im))
   end

   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   
   ren:renderPolyline(1, 0.3)

   ren:reset()
   
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   

   local im = 15
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*theta/im), y0 - ro * math.sin(a0 + i*theta/im))
   end

   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*theta/im), y0 - ri * math.sin(a0+i*theta/im))
   end
   lcd.setColor(lcd.getFgColor())
   ren:renderPolygon()


   ren:reset()
   theta = aR * hmax/max 
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   ren:renderPolyline(3)
   
   lcd.setColor(255,255,0)

   ren:reset()
   theta = aR * hmin/max 
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   ren:renderPolyline(3)

   lcd.setColor(0,0,0)
   
   local text
   text = string.format("%4.2f", val)
   lcd.drawText(x0 - lcd.getTextWidth(FONT_BOLD, text) / 2, y0+14, text, FONT_BOLD)

   text = string.format("%4.2f", hmax)
   lcd.drawText(x0 + 42, y0 - 25, text, FONT_BIG)
   --lcd.drawImage(x0 + 32, y0-25, ":up")
   
   text = string.format("%4.2f", hmin)
   --lcd.drawImage(x0 + 32, y0, ":down")   
   lcd.drawText(x0 + 42, y0, text, FONT_BIG)   
   
end


local function timePrint(width, height)
   local str, strCap
   local rgb={}
   local rs,gs,bs

   if selectedSlot < 1 or selectedSlot > #Battery then
      str = "No Battery"
   else
      if battmAh and (Battery[selectedSlot] >= 1 and Battery[selectedSlot] <= #gblBattery) then
	 str = string.format("Battery %d   %d mAh", Battery[selectedSlot],
			     gblBattery[Battery[selectedSlot]].cap - battmAh)
	 local battPct = 100 * (gblBattery[Battery[selectedSlot]].cap - battmAh) /
	    gblBattery[Battery[selectedSlot]].cap
	 if  battPct <= gblBattery[Battery[selectedSlot]].warn then
	    rgb = {r=255,g=0,b=0}
	 else
	    rgb = {r=0,g=0,b=255}
	 end
	 drawRectGaugeAbs(75, 33, 140, 25, 0, 100, battPct,"", rgb)
	 strCap = string.format("Cap %4d  Warn %4d %4d",
				gblBattery[Battery[selectedSlot]].cap,
				gblBattery[Battery[selectedSlot]].cap *
				   gblBattery[Battery[selectedSlot]].warn / 100,
				gblBattery[Battery[selectedSlot]].cap *
				   gblBattery[Battery[selectedSlot]].warn2 / 100)	 

      else
	 str = "No mAh sensor"
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

   if (selectedSlot >= 1 and selectedSlot <= #Battery) and
      (Battery[selectedSlot] >= 1 and Battery[selectedSlot] <= #gblBattery)
      and sensor and sensor.valid then
      battmAh = sensor.value
      if not battmAh then battmAh = 0 end
      if battmAh < lastmAh then warnAnn = false end -- mui can reset to 0 after current flows
      lastmAh = battmAh
      local battPct = 100 * (gblBattery[Battery[selectedSlot]].cap - battmAh) /
	 gblBattery[Battery[selectedSlot]].cap
      
      if selectedSlot >=1 and selectedSlot <= #Battery 
	 and battPct <= gblBattery[Battery[selectedSlot]].warn
	 and gblBattery[Battery[selectedSlot]].warn ~= 0
         and not warnAnn then
	    warnAnn = true
	    if warnSound == "..." then
	       system.playFile('/Apps/DFM-BatG/Low_Battery.wav', AUDIO_IMMEDIATE)
	    else
	       system.playFile(warnSound, AUDIO_IMMEDIATE)
	    end
	    if shakePattern > 1 then
 	       system.vibration( (stickToShake == 2), shakePattern - 1)
	    end
      end

      if selectedSlot >=1 and selectedSlot <= #Battery 
	 and battPct <= gblBattery[Battery[selectedSlot]].warn2
	 and gblBattery[Battery[selectedSlot]].warn2 ~= 0
         and not warn2Ann then
	    warn2Ann = true
	    if warn2Sound == "..." then
	       system.playFile('/Apps/DFM-BatG/low_battery_land_now.wav', AUDIO_IMMEDIATE)
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
   fileBD = pf .. "Apps/DFM-BatG/BD_" .. mn .. ".jsn"

   file = io.readall(fileBD)

   if file then
      decoded = json.decode(file)
      Battery = decoded.array
      if not Battery then
	 Battery = {}
	 Battery[1] = 0
      end
      lastSlot = decoded.lastSlot
      battmAhSe = decoded.battmAhSe or 0
      battmAhSeId = tonumber(decoded.battmAhSeId) or 0
      battmAhSePa = decoded.battmAhSePa or 0
      warnSound = decoded.warnSound
      warn2Sound = decoded.warn2Sound or "..."
      stickToShake = decoded.stickToShake or 1
      shakePattern = decoded.shakePattern or 1
      stickToShake2 = decoded.stickToShake2 or 1
      shakePattern2 = decoded.shakePattern2 or 1
   else
      system.messageBox("No Model data read: initializing")
      print("No Model data read: initializing")      
      Battery={}
      Battery[1] = 0
      battmAhSe = 0
      battmAhSeId = 0
      battmAhSePa = 0
      lastSlot = 0
      warnSound = "..."
      warn2Sound = "..."
      stickToShake = 1
      shakePattern = 1
      stickToShake2 = 1
      shakePattern2 = 1
   end

   fileBDG = pf .. "Apps/DFM-BatG/BD_Global.jsn"
   file = io.readall(fileBDG)
   
   if file then
      gblBattery = json.decode(file)
      for i=1,#gblBattery, 1 do
	 if not gblBattery[i] then
	    gblBattery[i] = {} 
	    resetGbl(i)
	 end
	 if not gblBattery[i].text then gblBattery[i].text = ".." end
      end
   else
      system.messageBox("Initializing global battery table")
      print("Initializing global battery table")
      gblBattery[1] = {}
      resetGbl(1)
   end

   -- do we need this ... ? should not happen if we delete all model files
   if #Battery > #gblBattery then
      print("#B > #G .. clearing model Battery list")
      Battery = {}
      Battery[1] = 0
   end
   
   if not warnSound then warnSound = "..." end
   if not warn2Sound then warn2Sound = "..." end   
   
   selectedSlot = 0 -- won't be assigned till popup selects a batt
   
   system.registerForm(1, MENU_APPS, "Battery Tracker", initForm, keyForm)
   system.registerTelemetry(1, "Battery Tracker", 2, timePrint)
   system.registerTelemetry(2, "Foo", 2, fooPrint)
   
   readSensors()
   setLanguage()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=BattVersion, name="Battery Tracker G", destroy=destroy}
