--[[
   ----------------------------------------------------------------------
   DFM-Batt.lua released under MIT license by DFM 2022
   
   There was an original model-specific app called DFM-Batt. This one was created to
   handle global groups, and for a time was called DFM-BatG .. now this one is DFM-Batt

   Version 2.4 21-Apr-2023 Increase max mAh on packs to 32767 from 9999 per HC request

   ----------------------------------------------------------------------
   
--]]

--local trans11
local BattVersion = "2.4"

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

local locale, lang

local function setLanguage()
   locale=system.getLocale()
   --print("locale: " .. locale)
   local tf1 = "Apps/DFM-Batt/Lang/"
   local tf2 = "-locale.jsn"
   local file = io.readall(tf1..locale..tf2)
   if not file then
      locale = "en"
      file = io.readall(tf1..locale..tf2)
   end
   if not file then print("No language file found") else
      local obj = json.decode(file)
      if(obj) then
	 lang = obj[locale]
      end
   end
end

local sensorLbl = "***"

local function readSensors()

   local sensors = system.getSensors()
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

local function resetGroup(i)
   BatteryGroupName[i] = string.format(lang.group.." %d", i)
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

   for name, _, _ in dir(path) do
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

local function timePrint()
   local str, strCap
   local rgb
   local rs,gs,bs

   --lcd.setColor(255,255,255)
   --lcd.drawFilledRectangle(0,0,width-1,height-1)

   rs,gs,bs = lcd.getFgColor()
   
   if selectedGroup < 1 or selectedGroup > #Battery then
      str = lang.noGroup
   elseif selectedBattery < 1 or selectedBattery > #Battery[selectedGroup] then
      --print("selectedBattery", selectedBattery)
      str = lang.noBattery
   elseif not battmAh then
      str = lang.nomAh
   else
      local sGsB = Battery[selectedGroup][selectedBattery]
      str = string.format(lang.battery.." %d  %d mAh", selectedBattery,
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
      
      strCap = string.format(lang.cap .. " %5d " .. lang.warn .. " %5d %5d",
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
   lcd.drawText(2,0,str)

end

--local ikk
local selBatt = {}

local function key0(key)
   local row = form.getFocusedRow()
   if key == KEY_3 then
      for j=1,#selBatt do
	 if selBatt[j] == row then
	    system.messageBox(lang.battAlready)
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
	 selectedBattery = selBatt[1]
      end
      
      if selectedBattery > 0 then
	 for j=1, #selBatt do
	    Battery[selectedGroup][selBatt[j]].cyc =
	       Battery[selectedGroup][selBatt[j]].cyc + 1
	    system.playFile('/Apps/DFM-Batt/Lang/'..locale..'/selected_battery.wav', AUDIO_QUEUE)
	    system.playNumber(selBatt[j], 0)
	 end
	 
	 system.unregisterTelemetry(1)
	 system.registerTelemetry(1, BatteryGroupName[selectedGroup], 2, timePrint)
      else
	 system.playFile('/Apps/DFM-Batt/Lang/'..locale..'/no_battery_selected.wav', AUDIO_QUEUE)	    
      end
      form.close(2)
   end


   if key == KEY_ESC or (key == KEY_5 and row < 1) or key == KEY_1 then
      form.preventDefault()
      local ans
      ans = form.question(lang.exitWithout, nil, nil, 0, false, 5)
      if ans == 1 then
	 form.close(2)
	 system.playFile('/Apps/DFM-Batt/Lang/'..locale..'/no_battery_selected.wav', AUDIO_QUEUE)
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
      form.addLabel({label=lang.noBatteryModel})
   elseif #Battery < 1 then
      form.addRow(1)
      form.addLabel({label=lang.noBatteryGroups})
   else
      form.setTitle(BatteryGroupName[selectedGroup])
      form.setButton(1, lang.esc, 1)
      form.setButton(3, lang.plusBatt, 1)

      for i=1,#Battery[selectedGroup],1 do
	 if Battery[selectedGroup][i].cap ~= 0 then
	    row = row + 1
	    if i == lastBattery then
	       focusRow = row
	    end
	    form.addRow(1)
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
	    str = string.format(prefix .. lang.batt .." %d  [", i) ..
	       string.format(lang.cap.." %d ", bb.cap) ..
	       string.format(lang.w1.." %d%% ", bb.warn) ..
	       string.format(lang.w2.." %d%% ", bb.warn2) .. 
	       string.format(lang.cyc.." %d]", bb.cyc)
	    form.addLabel({label=str, width=320, alignRight=false})
	 end
      end
      if row == 0 then
	 form.addRow(1)
	 form.addLabel({label=string.format(lang.noConfigBatt .." %d", selectedGroup)})
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
	 system.messageBox(lang.warnClear)
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
	 system.messageBox(lang.removeSel)
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
   --local str
   subForm = sf

   if sf == 1 then
      form.setTitle(lang.appname)
      form.addRow(2)
      form.addLink((function() form.reinit(2) end), {label=lang.modelBattGrp..">>", width=320})

      form.addRow(2) 
      form.addLink((function() form.reinit(4) end), {label=lang.battGrpSetup..">>", width=320})
      
      form.addRow(2) 
      form.addLink((function() form.reinit(6) end), {label=lang.warnings..">>", width=320})

      form.addRow(2)
      form.addLink((function() form.reinit(3) end), {label=lang.settings..">>", width=320})      

      form.addRow(1)
      form.addLabel({label="DFM - v."..BattVersion.." ", font=FONT_MINI, alignRight=true})
   elseif sf == 2 then
      form.setTitle(lang.modGrpSel)

      if #Battery < 1 then
	 form.addRow(1)
	 form.addLabel({label=lang.noBattDef})
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
      form.setTitle(lang.settings)
      form.addRow(2)
      form.addLabel({label=lang.mahsensor, width=220})
      form.addSelectbox(sensorLalist, battmAhSe, true, battmAhSensorChanged)


      form.addRow(2)
      form.addLink((function()
	       system.messageBox(lang.battClear)
	       selectedGroup = 0
	       seenRX = false
	       form.reinit(3)
		   end),
	 {label=lang.reSel})

      form.addRow(2)
      form.addLink((function()
	       io.remove(fileBD)
	       writeBD = false
	       selectedGroup = 0
	       --seenRX = false
	       system.messageBox(lang.restart)
	       form.reinit(3)
		   end),
	 {label=lang.clearAll, width=220})
      
      form.addRow(2)
      form.addLink((function()
	       local ans
	       ans = form.question(lang.ays, lang.delBattEnt,
				   lang.also,
				   0, false, 5)
	       if ans ~= 1 then
		  form.reinit(3)
	       else
		  writeBDG = false
		  writeBD = false
		  selectedGroup = 0
		  wcDelete("Apps/DFM-Batt", "BD_", "jsn")
		  system.messageBox(lang.restart2)
		  form.reinit(3)
	       end
		   end),
	 {label=lang.clearG, width=220})
      
   elseif sf == 4 then
      form.setTitle(lang.battGrpSetup)
      form.setButton(1, lang.clr, 1)
      form.setButton(2, ":add", 1)
      form.setButton(3, ":edit", 1)
      form.setButton(4, ":delete", 1)
      
      if #Battery == 0 then
	 form.addRow(1)
	 form.addLabel({label=lang.noBatteryGroups, width=320, alignRight=false, font=FONT_NORMAL})
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

   --elseif sf == 5 then
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
      form.setTitle(lang.warnings)
      form.addRow(2)
      form.addLabel({label=lang.warn1.." "..lang.snd})
      form.addAudioFilebox(warnSound or "...", warnChanged)

      form.addRow(2)
      form.addLabel({label=lang.warn1.." "..lang.vib})      
      form.addSelectbox({lang.left, lang.right}, stickToShake, true, stickChanged)

      form.addRow(2)
      form.addLabel({label=lang.warn1.." "..lang.patt})      
      form.addSelectbox({lang.none, lang.long, lang.short, lang.short2, lang.short3},
	 shakePattern, true, shakeChanged)    

      form.addRow(2)
      form.addLabel({label=lang.warn2.." "..lang.snd})
      form.addAudioFilebox(warn2Sound or "...", warn2Changed)

      form.addRow(2)
      form.addLabel({label=lang.warn2.." "..lang.vib})      
      form.addSelectbox({lang.left, lang.right}, stickToShake2, true, stick2Changed)

      form.addRow(2)
      form.addLabel({label=lang.warn2.." "..lang.patt})      
      form.addSelectbox({lang.none, lang.long, lang.short, lang.short2, lang.short3},
	 shakePattern2, true, shake2Changed)    

   elseif sf == 7 then
      form.setTitle(BatteryGroupName[savedRow])
      form.setButton(1, lang.clr, 1)
      form.setButton(2, ":add", 1)

      if #Battery[savedRow] < 1 then
	 form.addRow(1)
	 form.addLabel({label=lang.noBattGrp})
      else
	 form.addRow(4)
	 form.addLabel({label=lang.batt, width=40, alignRight=true, font=FONT_MINI})
	 form.addLabel({label=lang.cap.." (mAh)", width=80, alignRight=true, font=FONT_MINI})
	 form.addLabel({label=lang.warn1.." "..lang.warn2.." % "..lang.left ,
			width=140,alignRight=true,font=FONT_MINI})
	 form.addLabel({label=lang.cycles, width=80, alignRight=true, font=FONT_MINI})
	 
	 for i=1,#Battery[savedRow],1 do
	    form.addRow(5)
	    form.addLabel({label=i.."  ", width=40, alignRight=true, font=FONT_NORMAL})
	    form.addIntbox(Battery[savedRow][i].cap, 0, 32767, 5000, 0, 10,
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

local function loop()

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
	       system.playFile('/Apps/DFM-Batt/Lang/'..locale..'/Low_Battery.wav', AUDIO_IMMEDIATE)
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
	       system.playFile('/Apps/DFM-Batt/Lang'..locale..'/low_battery_land_now.wav', AUDIO_IMMEDIATE)
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
      system.registerForm(2, 0, lang.selFltBatt, initForm0, key0, nil, close0)
      seenRX = true
   end
end

local function init()

   local pf
   local mn
   local file
   local decoded

   setLanguage()

   emFlag = select(2, system.getDeviceType())
   if emFlag == 1 then pf = "" else pf = "/" end

   if emFlag == 1 and system.getInputs("SA") ~= 1 then
      system.messageBox("Emulator: Set SA to 1 to run init dialog")
   end
   
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
      system.messageBox(lang.noModelData)
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

   lastGroup = lastGroup
   
   fileBDG = pf .. "Apps/DFM-Batt/BD_Global.jsn"
   file = io.readall(fileBDG)

   local temp
   
   if file then
      temp = json.decode(file)
      Battery = temp.Array
      BatteryGroupName = temp.Name
   else
      system.messageBox(lang.initTable)
      print("Initializing global battery table")
      Battery = {}
   end

   if not warnSound then warnSound = "..." end
   if not warn2Sound then warn2Sound = "..." end   
   
   selectedBattery = 0
   if not selectedGroup then selectedGroup = 0 end
   
   system.registerForm(1, MENU_APPS, lang.appname, initForm, keyForm)
   system.registerTelemetry(1, lang.appname, 2, timePrint)
   
   readSensors()

   collectgarbage()
   print("DFM-Batt: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=BattVersion, name="DFM-Batt", destroy=destroy}
