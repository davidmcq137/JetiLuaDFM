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
end

local function closeForm() p("closeForm") end

local function telPrint(w, h)
   lcd.drawText(4, 4, "SpikeTgt telemetry", FONT_BOLD)
   lcd.drawText(4, 24, "telemKey=" .. st.telemKey .. "  count=" .. st.telKeyCount,
		FONT_NORMAL)
   lcd.drawText(4, 42, "keys:" .. st.telKeyLog, FONT_MINI)
   lcd.drawText(4, 56, "user buttons (setTelemetryButton): " .. st.telButtons, FONT_MINI)
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
      elseif key == KEY_3 and (st.group or 1) == 1 then
	 st.t3 = not st.t3
	 setTelButtons()
	 p("T3 toggled", st.t3)
      end
   end
end

local function init()
   p("init: registerForm is", tostring(system.registerForm))
   uid = system.UIDriver
   p("init: system.UIDriver is", tostring(uid))
   if uid then uid.expose("tgt", function() return st end) end
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

return {init=init, loop=nil, author="DFM", version="0.1", name=appName}
