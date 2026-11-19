--[[
   SpikeTgt.lua -- throwaway target app for the UI-driver spike.

   A plain form app with no knowledge of the driver. It shows the
   values its callbacks have seen, so you can watch what SpikeDrv
   injects. Every callback also prints a "[TGT]" line to the console.
--]]

local appName = "SpikeTgt"

local st = {
   intVal = 10, selIdx = 1, chk = false, int2 = 0,
   lastKey = "-", subform = 0, telemKey = "-",
   telKeyCount = 0,       -- telemetry key presses (releases not counted)
   telKeyLog = "",        -- the last telemetry key codes, newest last
   telButtons = "?",      -- whether setTelemetryButton exists here
}
local selItems = {"A", "B", "C"}
local chkIdx
local uid      -- system.UIDriver test hooks; nil on the TX
-- images for UIDriver's expectImage: the form shows red if Spike Chk is
-- on, green if off; the telemetry window shows blue
local dots = {}
local DOTDIR = "Apps/DFM-Maps/JSON/"

-- console + Apps/SpikeTgt.log (appended per line, so nothing is lost)
local LOGFILE = "Apps/UIDriver/SpikeTgt.log"
local function p(...)
   print("[TGT]", ...)
   local t = {}
   for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end
   local f = io.open(LOGFILE, "a")
   if f then io.write(f, table.concat(t, " ") .. "\n"); io.close(f) end
end
do local f = io.open(LOGFILE, "w"); if f then io.close(f) end end

-- one of each announcement, for UIDriver's waitMessage/waitAudio/...
-- (pcall'd messageBox checks that UIDriver looks past C frames)
local function announceAll(why)
   p("announcing:", why)
   pcall(system.messageBox, "SpikeTgt says " .. why, 2)
   system.playFile("/Apps/DFM-Ctrl/Duration.wav", AUDIO_QUEUE)
   system.playNumber(77, 0)
   system.vibration(true, 2)
   system.playBeep(1, 1000, 200)
end

local swItem               -- the "Spike Switch" inputbox's SwitchItem

local function initForm(sub)
   st.subform = sub
   if uid then uid.event("sub", sub) end
   p("initForm", sub)
   if sub == 1 then
      form.addRow(2)
      form.addLabel({label="Spike Int"})
      form.addIntbox(st.intVal, 0, 100, 10, 0, 1,
		     function(v)
			if uid then uid.check(v >= 0 and v <= 100, "intVal in 0..100") end
			st.intVal = v; p("int cb", v)
			if v == 77 then announceAll("int 77") end
		     end)

      form.addRow(2)
      form.addLabel({label="Spike Sel"})
      form.addSelectbox(selItems, st.selIdx, false,
			function(i) st.selIdx = i; p("sel cb", i, selItems[i]) end)

      form.addRow(2)
      form.addLabel({label="Spike Chk"})
      -- usual JETI pattern: the callback gets the current state and the
      -- app toggles it itself
      chkIdx = form.addCheckbox(st.chk, function(v)
	    st.chk = not v
	    form.setValue(chkIdx, st.chk)
	    p("chk cb", v, "->", st.chk)
      end)

      -- an inputbox (switch assignment), for UIDriver's inputbox set/expect
      if form.addInputbox then
	 form.addRow(2)
	 form.addLabel({label="Spike Switch"})
	 form.addInputbox(swItem, true, function(v)
	       swItem = v
	       local info = v and system.getSwitchInfo and system.getSwitchInfo(v)
	       p("switch cb", info and info.label, info and info.mode,
		 info and info.activeOn, info and info.assigned)
	 end)
      end

      -- asks first, to test scripted form.question answers
      form.addLink(function()
	    local a = form.question("Go to subform 2?", "", "", 0, false, 0)
	    p("question answered", a)
	    if a == 1 then p("link -> sub 2"); form.reinit(2) end
		   end, {label="Sub 2 >>"})
   else
      form.addRow(2)
      form.addLabel({label="Spike Int2"})
      form.addIntbox(st.int2, -50, 50, 0, 0, 1,
		     function(v) st.int2 = v; p("int2 cb", v) end)
      form.addLink(function() p("link -> sub 1"); form.reinit(1) end,
		   {label="<< Back"})
   end
end

local function keyForm(key)
   p("keyForm raw", key, "KEY_RELEASED=", KEY_RELEASED)
   if key ~= KEY_RELEASED then
      st.lastKey = tostring(key)
      p("keyForm", key)
   end
end

-- status box: black text on white, so it reads on the emulator's blue form
local function prtForm(w, h)
   local l1 = string.format("int=%d sel=%d chk=%s int2=%d",
			    st.intVal, st.selIdx, tostring(st.chk), st.int2)
   local l2 = "lastKey=" .. st.lastKey .. " sub=" .. st.subform
   lcd.setColor(255, 255, 255)
   lcd.drawFilledRectangle(2, 2, 150, 26)
   lcd.setColor(0, 0, 0)
   lcd.drawText(4, 3, l1, FONT_MINI)
   lcd.drawText(4, 15, l2, FONT_MINI)
   local dot = st.chk and dots.red or dots.green
   if dot then lcd.drawImage(160, 4, dot) end
end

local function closeForm() p("closeForm") end

local function telPrint(w, h)
   lcd.drawText(4, 4, "SpikeTgt telemetry", FONT_BOLD)
   lcd.drawText(4, 24, "telemKey=" .. st.telemKey .. "  count=" .. st.telKeyCount,
		FONT_NORMAL)
   lcd.drawText(4, 42, "keys:" .. st.telKeyLog, FONT_MINI)
   lcd.drawText(4, 56, "user buttons (setTelemetryButton): " .. st.telButtons, FONT_MINI)
   if dots.blue then lcd.drawImage(260, 4, dots.blue) end
   lcd.drawText(4, 70, string.format("P6=%s SA=%s item=%s %s=%s valid=%s gpsNil=%s",
				     tostring(st.p6), tostring(st.sa), tostring(st.saVal),
				     tostring(st.sensLabel), tostring(st.sensVal),
				     tostring(st.sensValid), tostring(st.posNil)), FONT_MINI)
end

-- two groups of user buttons, switched with Enter as a "shift" key:
-- group 1 T1..T5 (T3 toggles T4, like DFM-Maps' NoFly), group 2 U1..U5
local function setTelButtons()
   if not system.setTelemetryButton then return end
   if (st.group or 1) == 1 then
      for i = 1, 5 do system.setTelemetryButton(1, i, "T" .. i, 1) end
      system.setTelemetryButton(1, 3, "T3", st.t3 and 2 or 1)
      system.setTelemetryButton(1, 4, "T4", st.t3 and 1 or 3)
   else
      for i = 1, 5 do system.setTelemetryButton(1, i, "U" .. i, 1) end
   end
end

local function telKey(key)
   p("telKey raw", key)
   if key ~= KEY_RELEASED then
      st.telemKey = tostring(key)
      st.telKeyCount = st.telKeyCount + 1
      st.telKeyLog = (st.telKeyLog .. " " .. tostring(key)):sub(-60)
      p("telKey", key)
      if uid then uid.event("telKey", key) end
      if key == KEY_ENTER then
	 st.group = (st.group or 1) == 1 and 2 or 1
	 setTelButtons()
	 p("shift: button group", st.group)
      elseif key == KEY_2 and (st.group or 1) == 1 then
	 announceAll("T2")
      elseif key == KEY_3 and (st.group or 1) == 1 then
	 st.t3 = not st.t3
	 setTelButtons()
	 p("T3 toggled", st.t3)
      end
   end
end

-- inputs, sensors and a control, for UIDriver's setInput/setSensor/
-- expectControl: loop() reads P6 and SA (getInputs, and getInputsVal
-- through a SwitchItem if createSwitch exists), the first numeric sensor
-- (Altitude if there is one) and the GPS position, and outputs P6 on
-- control 1 "SpikeCtl"
local saItem, sens, gpsSens

local function findSensors()
   if not system.getSensors then return end
   local ok, list = pcall(system.getSensors)
   if not ok or type(list) ~= "table" then return end
   local lat, lon
   for _, e in ipairs(list) do
      if e.param and e.param ~= 0 then
	 if e.type == 9 and e.label == "Latitude" then lat = e
	 elseif e.type == 9 and e.label == "Longitude" then lon = e
	 elseif e.type ~= 9 and e.type ~= 5 and (not sens or e.label == "Altitude") then sens = e end
      end
   end
   if lat and lon and lat.id == lon.id then
      gpsSens = {id = lat.id, lat = lat.param, lon = lon.param}
   end
   st.sensLabel = sens and sens.label or "none"
   p("sensor:", st.sensLabel, "gps:", gpsSens and "yes" or "no")
end

local function loop()
   if sens == nil and gpsSens == nil and not st.searched then
      st.searched = true
      findSensors()
   end
   st.p6, st.sa = system.getInputs("P6", "SA")
   if saItem then st.saVal = system.getInputsVal(saItem) end
   -- the inputbox's switch: what getSwitchInfo says, and its value
   st.swAssigned, st.swLabel, st.swMode, st.swVal, st.swRaw = false, "none", nil, nil, nil
   if swItem and system.getSwitchInfo then
      local info = system.getSwitchInfo(swItem)
      if info and info.assigned ~= false then
	 st.swAssigned, st.swLabel, st.swMode = true, info.label, info.mode
	 st.swRaw = info.value     -- getSwitchInfo's value (evaluated, like getInputsVal)
	 st.swVal = system.getInputsVal(swItem)
      end
   end
   if sens then
      local v = system.getSensorByID(sens.id, sens.param)
      st.sensVal = v and v.value
      st.sensValid = v and v.valid
   end
   if gpsSens and gps and gps.getPosition then
      st.posNil = gps.getPosition(gpsSens.id, gpsSens.lat, gpsSens.lon) == nil
   end
   if st.ctl and st.p6 then system.setControl(1, st.p6, 0) end
end

local function init()
   p("init: registerForm is", tostring(system.registerForm))
   uid = system.UIDriver
   p("init: system.UIDriver is", tostring(uid))
   if uid then uid.expose("tgt", function() return st end) end
   if system.createSwitch then saItem = system.createSwitch("SA", "S", 1) end
   st.ctl = system.registerControl and system.registerControl(1, "SpikeCtl", "SpC")
   if lcd.loadImage then
      for _, c in ipairs({"red", "green", "blue"}) do
	 dots[c] = lcd.loadImage(DOTDIR .. "small_" .. c .. "_circle.png")
      end
      lcd.loadImage("Apps/UIDriver/no-such-image.png")  -- UIDriver should WARN
   end
   system.registerForm(1, MENU_APPS, appName, initForm, keyForm, prtForm, closeForm)
   system.registerTelemetry(1, appName, 4, telPrint, telKey)
   -- user buttons T1..T5 (6.05, DS-24 II only); ESC on the full-screen
   -- window toggles between these and the system buttons
   if system.setTelemetryButton then
      setTelButtons()
      st.telButtons = "yes"
   else
      st.telButtons = "no"
   end
   p("setTelemetryButton available:", st.telButtons)
end

return {init=init, loop=loop, author="DFM", version="0.1", name=appName}
