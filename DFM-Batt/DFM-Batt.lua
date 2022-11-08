--[[
   ----------------------------------------------------------------------
   DFM-Batt.lua released under MIT license by DFM 2022
   
   There was an original model-specific app called DFM-Batt. This one was created to
   handle global groups, and for a time was called DFM-BatG .. now this one is DFM-Batt
   ----------------------------------------------------------------------
   
--]]

--local trans11
local BattVersion = "2.2"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0
local emFlag
   
local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters

local Battery={}
local BatteryGroupName={}
local selectedGroup
local selectedBattery
local lastGroup, lastBattery
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

local function resetGroup(i)
   BatteryGroupName[i] = string.format("Group %d", i)
   Battery[i] = {}
end

local function resetBattery(sr, i)
   Battery[sr][i].cap = 0
   Battery[sr][i].cyc = 0
   Battery[sr][i].warn = 0
   Battery[sr][i].warn2 = 0
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

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str, rgb)

   local d
   local txt
   local font = FONT_BIG
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

local function timePrint(width, height)
   local str, strCap
   local rgb={}
   local rs,gs,bs

   --lcd.setColor(255,255,255)
   --lcd.drawFilledRectangle(0,0,width-1,height-1)

   rs,gs,bs = lcd.getFgColor()
   
   if selectedGroup < 1 or selectedGroup > #Battery then
      str = "No Battery Group"
   elseif selectedBattery < 1 or selectedBattery > #Battery[selectedGroup] then
      str = "No Battery Selected"
   elseif not battmAh then
      str = "No mAh sensor"
   else
      local sGsB = Battery[selectedGroup][selectedBattery]
      str = string.format("Battery %d   %d mAh", selectedBattery,
			  sGsB.cap - battmAh)
      local battPct = 100 * (sGsB.cap - battmAh) / sGsB.cap
      if  battPct <= sGsB.warn then
	 --rgb = {r=255,g=0,b=0}
	 --rgb = {r=255-rs,g=255-gs,b=255-bs}
	 rgb = {r=(rs+170)%255,g=(gs+170)%255,b=(bs+170)%255}	 
      else
	 --rgb = {r=0,g=0,b=255}
	 rgb = {r=rs,g=gs,b=bs}	 
      end
      drawRectGaugeAbs(75, 33, 140, 25, 0, 100, battPct,"", rgb)
      
      strCap = string.format("Cap %4d  Warn %4d %4d",
			     sGsB.cap,
			     sGsB.cap * sGsB.warn  / 100,
			     sGsB.cap * sGsB.warn2 / 100)	 
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

--local ikk
local selBatt = {}

local function key0(key)
   local row = form.getFocusedRow()
   if key == KEY_3 then
      for j=1,#selBatt do
	 if selBatt[j] == row then
	    system.messageBox("Battery already selected")
	    form.reinit(2)
	    return
	 end
      end
      table.insert(selBatt, row)
      form.reinit(2)
   end

   if key == KEY_5 or key == KEY_ENTER then
      form.preventDefault()
      selectedBattery = 0
      if selectedGroup > 0 and row >= 1 and row <= #Battery[selectedGroup]  then
	 -- don't double-select an already-selected battery
	 local skip
	 for j=1,#selBatt do
	    if selBatt[j] == row then skip = true else skip = false end
	 end
	 if not skip then
	    table.insert(selBatt, row)
	 end
	 --selectedBattery = row
	 selectedBattery = selBatt[1]
      end

      --print("5 or Enter", row, selectedBattery)
      
      if selectedBattery > 0 then
	 for j=1, #selBatt do
	    Battery[selectedGroup][selBatt[j]].cyc =
	       Battery[selectedGroup][selBatt[j]].cyc + 1
	    system.playFile('/Apps/DFM-Batt/selected_battery.wav', AUDIO_IMMEDIATE)
	    system.playNumber(selBatt[j], 0)
	 end

	 --if ikk > 0 and ikk ~= selectedBattery then
	 --   Battery[selectedGroup][ikk].cyc =
	 --      Battery[selectedGroup][ikk].cyc + 1
	 --end
	 
	 system.unregisterTelemetry(1)
	 system.registerTelemetry(1, BatteryGroupName[selectedGroup], 2, timePrint)
      else
	 system.playFile('/Apps/DFM-Batt/no_battery_selected.wav', AUDIO_IMMEDIATE)	    
      end
      form.close(2)
   end


   if key == KEY_ESC or (key == KEY_5 and row < 1) or key == KEY_1 then
      form.preventDefault()
      local ans
      ans = form.question("Exit without selecting a battery?", nil, nil, 0, false, 5)
      if ans == 1 then
	 form.close(2)
	 system.playFile('/Apps/DFM-Batt/no_battery_selected.wav', AUDIO_IMMEDIATE)
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
   local prefix
      
   if not selBatt then selBatt = {} end
   
   if #Battery > 0 and selectedGroup < 1 then
      form.addRow(1)
      form.addLabel({label="No battery group selected for model"})
   elseif #Battery < 1 then
      form.addRow(1)
      form.addLabel({label="No battery groups"})
   else
      form.setTitle(BatteryGroupName[selectedGroup])
      form.setButton(1, "Esc", 1)
      form.setButton(3, "+Batt", 1)

      for i=1,#Battery[selectedGroup],1 do
	 if Battery[selectedGroup][i].cap ~= 0 then
	    row = row + 1
	    if i == lastBattery then
	       focusRow = row
	    end
	    form.addRow(1)
	    local str
	    local bb = Battery[selectedGroup][i]
	    prefix=""
	    for j=1, #selBatt do
	       if i == selBatt[j] then
		  if j == 1 then
		     prefix = "[P] "
		  else
		     prefix = string.format("[%d] ", j)
		  end
	       end
	    end
	    str = string.format(prefix .. "Batt %d  [", i) ..
	       string.format("Cap %d ", bb.cap) ..
	       string.format("W1 %d%% ", bb.warn) ..
	       string.format("W2 %d%% ", bb.warn2) .. 
	       string.format("Cyc %d]", bb.cyc)
	    form.addLabel({label=str, width=320, alignRight=false})
	 end
      end
      if row == 0 then
	 form.addRow(1)
	 form.addLabel({label=string.format("No configured batteries in Group %d", selectedGroup)})
	 selectedBattery = 0
      end
   end
   --[[
   if row == 0 then
      form.addRow(1)
      form.addLabel({label="No battery in group"})
   end
   --]]
   if selBatt and #selBatt > 0 then
      focusRow = selBatt[#selBatt] 
   end
   form.setFocusedRow(focusRow)
end

local function battGroupChanged(value)
   selectedGroup = value
end

local function BattChanged(value, i, j, sub)
   Battery[i][j][sub] = value
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
  BatteryGroupName[i] = value
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
      if row == selectedGroup then
	 selectedGroup = 0
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

   if subForm == 4 and key == KEY_1 and row >= 1 and row  <= #Battery then
      resetGroup(row) 
      form.reinit(4)
   end

   if subForm == 4 and key == KEY_2 then
      local i = #Battery + 1
      Battery[i] = {}
      resetGroup(i)
      form.reinit(4)
   end

   if subForm == 4 and key == KEY_3 and row > 0 then
      savedRow = row
      form.reinit(7)
   end

   if subForm == 4 and key == KEY_4 and row > 0 then
      table.remove(Battery, row)
      table.remove(BatteryGroupName, row)
      if row == selectedGroup then
	 system.messageBox("Removed selected group")
	 selectedGroup = 0
      end
      form.reinit(4)
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

   if subForm == 7 and keyExit(key) then
      form.preventDefault()
      form.reinit(4)
   end

   if subForm == 7 and key == KEY_2 then
      local i = #Battery[savedRow] + 1
      Battery[savedRow][i] = {}
      resetBattery(savedRow, i)
      form.reinit(7)
   end
      
end

local function initForm(sf)
   local str
   subForm = sf

   if sf == 1 then
      form.setTitle("Battery Tracker")
      form.addRow(2)
      form.addLink((function() form.reinit(2) end), {label="Model Battery Group>>", width=320})

      form.addRow(2) 
      form.addLink((function() form.reinit(4) end), {label="Battery Group Setup>>", width=320})
      
      form.addRow(2) 
      form.addLink((function() form.reinit(6) end), {label="Warnings>>", width=320})

      form.addRow(2)
      form.addLink((function() form.reinit(3) end), {label="Settings>>", width=320})      

      form.addRow(1)
      form.addLabel({label="DFM - v."..BattVersion.." ", font=FONT_MINI, alignRight=true})
   elseif sf == 2 then
      form.setTitle("Model Group Selection")

      if #Battery < 1 then
	 form.addRow(1)
	 form.addLabel({label="No Battery Groups defined"})
      else
	 
	 local temp = {}
	 for j=1,#Battery,1 do
	    temp[j] = BatteryGroupName[j]
	 end
	 
	 form.addRow(1)
	 form.addSelectbox(temp, selectedGroup, true, battGroupChanged,
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
	       selectedGroup = 0
	       seenRX = false
	       form.reinit(3)
		   end),
	 {label="Re-select battery"})

      form.addRow(2)
      form.addLink((function()
	       io.remove(fileBD)
	       writeBD = false
	       selectedGroup = 0
	       --seenRX = false
	       system.messageBox("Model settings cleared - restart App")
	       form.reinit(3)
		   end),
	 {label="Clear all model settings", width=220})
      
      form.addRow(2)
      form.addLink((function()
	       local ans
	       ans = form.question("Are you sure?", "Delete battery group entries?",
				   "(also deletes selected group for this model)",
				   0, false, 5)
	       if ans ~= 1 then
		  form.reinit(3)
	       else
		  writeBDG = false
		  writeBD = false
		  selectedGroup = 0
		  wcDelete("Apps/DFM-Batt", "BD_", "jsn")
		  system.messageBox("Battery groups cleared - restart App")
		  form.reinit(3)
	       end
		   end),
	 {label="Clear battery groups", width=220})
      
   elseif sf == 4 then
      form.setTitle("Battery Group Setup")
      form.setButton(1, "Clr", 1)
      form.setButton(2, ":add", 1)
      form.setButton(3, ":edit", 1)
      form.setButton(4, ":delete", 1)
      
      if #Battery == 0 then
	 form.addRow(1)
	 form.addLabel({label="No Battery Groups", width=320, alignRight=false, font=FONT_NORMAL})
      else
	 for i=1,#Battery,1 do
	    form.addRow(2)
	    form.addLabel({label=string.format("%d", i), alignRight=false})
	    form.addTextbox(BatteryGroupName[i], 24,
		      (function(x) return textChanged(x, i) end),
		      {alignRight=true})

	 end
      end

      form.setFocusedRow(savedRow or 1)

   elseif sf == 5 then
      --[[
      form.addRow(2)
      form.addLabel({label="Label Text", width = 80})
      form.addTextbox(gblBattery[savedRow].text, 63,
		      (function(x) return textChanged(x, savedRow) end),
		      {width=240, alignRight=false})
      local fn = string.format("Img/Batt%02d.PNG", savedRow)
      local ft = io.open(fn, "r")
      if ft then io.close(ft) end
      if ft then
	 form.addIcon(fn, {height=100})
      else
	 form.addLabel({label="File " .. fn .. " not found"})
      end
      --]]
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

   elseif sf == 7 then
      form.setTitle(BatteryGroupName[savedRow])
      form.setButton(1, "Clr", 1)
      form.setButton(2, ":add", 1)

      if #Battery[savedRow] < 1 then
	 form.addRow(1)
	 form.addLabel({label="No batteries in group"})
      else
	 form.addRow(4)
	 form.addLabel({label="Batt", width=40, alignRight=true, font=FONT_MINI})
	 form.addLabel({label="Cap (mAh)", width=80, alignRight=true, font=FONT_MINI})
	 form.addLabel({label="Warn 1 Warn 2 % Left  ",width=140,alignRight=true,font=FONT_MINI})
	 form.addLabel({label="Cycles", width=80, alignRight=true, font=FONT_MINI})
	 
	 for i=1,#Battery[savedRow],1 do
	    form.addRow(5)
	    form.addLabel({label=i.."  ", width=40, alignRight=true, font=FONT_NORMAL})
	    form.addIntbox(Battery[savedRow][i].cap, 0, 9999, 5000, 0, 10,
			   (function(x) return BattChanged(x, savedRow, i, "cap") end),
			   {width=80, font=FONT_NORMAL})
	    form.addIntbox(Battery[savedRow][i].warn, 0, 100, 50, 0, 1,
			   (function(x) return BattChanged(x, savedRow, i, "warn") end),
			   {width=60, font=FONT_NORMAL})
	    if not Battery[savedRow][i].warn2 then Battery[savedRow][i].warn2 = 0 end
	    form.addIntbox(Battery[savedRow][i].warn2, 0, 100, 50, 0, 1,
			   (function(x) return BattChanged(x, savedRow, i, "warn2") end),
			   {width=60, font=FONT_NORMAL})      	 
	    form.addIntbox(Battery[savedRow][i].cyc, 0, 999, 1, 0, 1,
			   (function(x) return BattChanged(x, savedRow, i, "cyc") end),						      {width=80, font=FONT_NORMAL})
	 end
      end
   end
end

--------------------------------------------------------------------------------

local function writeBattery()
   local fp
   local saveBatt = {}
   
   saveBatt.lastGroup = selectedGroup
   saveBatt.lastBattery = selectedBattery   
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

   saveBatt = {}
   saveBatt.Array = Battery
   saveBatt.Name = BatteryGroupName
   
   if writeBDG then
      fp = io.open(fileBDG, "w")
      if fp then io.write(fp, json.encode(saveBatt), "\n")
	 io.close(fp)
      end
   end
end

local function destroy()
   writeBattery()
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



local function loop()

   local tim = system.getTimeCounter() / 1000
   
   if startTime > 0 then
      runningTime = tim-startTime
   end

   -- read current from emulated sensor to simulate discharge
   if emFlag == 1 then system.getSensorByID(battmAhSeId, 9) end
   
   local sensor = system.getSensorByID(battmAhSeId, battmAhSePa)

   if (selectedGroup >= 1 and selectedGroup <= #Battery) and
      (selectedBattery >= 1 and selectedBattery <= #Battery[selectedGroup])
   and sensor and sensor.valid then
      battmAh = sensor.value
      if not battmAh then battmAh = 0 end
      if battmAh < lastmAh then warnAnn = false end -- mui can reset to 0 after current flows
      lastmAh = battmAh
      local battPct = 100 * (Battery[selectedGroup][selectedBattery].cap - battmAh) /
	 Battery[selectedGroup][selectedBattery].cap
      
      if battPct <= Battery[selectedGroup][selectedBattery].warn
	 and Battery[selectedGroup][selectedBattery].warn ~= 0
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

      if battPct <= Battery[selectedGroup][selectedBattery].warn2
	 and Battery[selectedGroup][selectedBattery].warn2 ~= 0
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
      selectedGroup = decoded.lastGroup
      battmAhSe = decoded.battmAhSe or 0
      battmAhSeId = tonumber(decoded.battmAhSeId) or 0
      battmAhSePa = decoded.battmAhSePa or 0
      --lastGroup = decoded.lastGroup
      lastBattery = decoded.lastBattery
      warnSound = decoded.warnSound
      warn2Sound = decoded.warn2Sound or "..."
      stickToShake = decoded.stickToShake or 1
      shakePattern = decoded.shakePattern or 1
      stickToShake2 = decoded.stickToShake2 or 1
      shakePattern2 = decoded.shakePattern2 or 1
   else
      system.messageBox("No Model data read: initializing")
      print("No Model data read: initializing")      
      battmAhSe = 0
      battmAhSeId = 0
      battmAhSePa = 0
      lastGroup = 0
      lastBattery = 0
      warnSound = "..."
      warn2Sound = "..."
      stickToShake = 1
      shakePattern = 1
      stickToShake2 = 1
      shakePattern2 = 1
   end

   fileBDG = pf .. "Apps/DFM-Batt/BD_Global.jsn"
   file = io.readall(fileBDG)

   local temp
   
   if file then
      temp = json.decode(file)
      Battery = temp.Array
      BatteryGroupName = temp.Name
      --[[
      print("Battery", Battery, #Battery)
      for i = 1, #Battery, 1 do
	 for j = 1, #Battery[i] do
	    print(i,j,Battery[i][j])
	 end
      end
      --]]
   else
      system.messageBox("Initializing global battery table")
      print("Initializing global battery table")
      Battery = {}
   end

   if not warnSound then warnSound = "..." end
   if not warn2Sound then warn2Sound = "..." end   
   
   selectedBattery = 0
   if not selectedGroup then selectedGroup = 0 end
   
   system.registerForm(1, MENU_APPS, "Battery Tracker", initForm, keyForm)
   system.registerTelemetry(1, "Battery Tracker", 2, timePrint)
   --system.registerTelemetry(2, "Foo", 2, fooPrint)
   
   readSensors()
   setLanguage()

   collectgarbage()
   print("DFM-Batt: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=BattVersion, name="Battery Tracker", destroy=destroy}
