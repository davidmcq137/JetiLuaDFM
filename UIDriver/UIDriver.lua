--[[
   UIDriver.lua -- drive another app's forms and telemetry keys from a
   script, as if a human were pressing the keys. Emulator use only.

   HOW IT WORKS (the same idea as SensorE)
   When this file's chunk loads, it replaces system.registerForm,
   system.registerTelemetry and several form.* functions in the shared
   tables. When the target app registers its form or telemetry windows,
   UIDriver registers wrapped callbacks in their place. Script steps then
   run inside the target's own print callbacks, so every form.* call
   happens while the target's form is the active one. The emulator loads
   every app's chunk before calling any init(), so the order of the apps
   in the list doesn't matter.

   INSTALL: like the other apps in this repo, the code lives in the app's
   folder and Apps/ has a symlink to it (top-level *.lua is gitignored):
     ln -s UIDriver/UIDriver.lua Apps/UIDriver.lua
     ln -s UIDriver/SpikeTgt.lua Apps/SpikeTgt.lua   (self-test target)

   FILES (in Apps/UIDriver/)
     UIDriver.lua   this app
     SpikeTgt.lua   a small form + telemetry app to self-test UIDriver
                    against (spike-test.jsn, tele-*.jsn); logs to
                    SpikeTgt.log here
     config.jsn     what to do; read when the chunk loads, so restart
                    the apps after changing it:
       {"mode": "play",           -- "play", "record" or "off"
        "target": "DFM-Maps",     -- registerForm label; telemetry windows
                                  -- whose label starts with "<target> " match too
        "script": "maps-smoke.jsn",
        "stepGapMs": 500,         -- pause after each step
        "stepTimeoutMs": 10000,   -- default per-step timeout
        "stopOnFail": true,
        "overlay": true,          -- step counter: true = appended to the
                                  -- form title ("GPS Maps  [UID 12/55]"),
                                  -- "box" = white box at the top right,
                                  -- false = none
        "recordRotary": false,    -- record KEY_UP/KEY_DOWN too (DFM-Maps'
                                  -- map browser uses them)
        "logAnnouncements": true, -- log the target's announcements
        "suppressMessageBox": false,  -- true: log the target's message
                                  -- boxes but don't show them
        "recordAnnouncements": false, -- record mode: add a wait step for
                                  -- each announcement
        "logControls": true}      -- log the target's setControl changes
     result.log     play results (also echoed to the console as [UID])
     recorded.jsn   written in record mode; it's a playable script

   SCRIPT: {"steps": [ ... ]}, each step one object
     {"waitForm": true}           wait until a human opens the target form
                                  (no timeout unless "timeoutMs" is given)
     {"waitSub": 7}               wait until subform 7 is showing
     {"waitClosed": true}         wait until the form has closed
     {"wait": 1000}               pause (ms)
     {"set": "Race time (mins)", "value": 30}     intbox (raw integer)
     {"set": "Select Field to Browse", "value": "BDS"}  selectbox by text
     {"set": "Select Field to Browse", "value": 2}      ... or by index
     {"set": "Enable Triangle Racecourse", "value": true}   checkbox
     {"set": "Name", "value": "abc"}              textbox
     {"link": "Map Browser >>"}   click a link (follow with waitSub)
     {"key": "KEY_2"}             press and release a key in the form;
                                  KEY_5/KEY_ESC close the form unless the
                                  target calls form.preventDefault, as
                                  the firmware does
     {"button": "Show"}           press the F key whose label is "Show"
     {"telemKey": "KEY_3", "win": 1}   key into target telemetry window
                                  1 (only while that window is showing)
     {"telemButton": "NoFly", "win": 1}   press a telemetry user button
                                  by its label (setTelemetryButton, DS-24 II);
                                  FAILs if the button is hidden. Works
                                  whether or not the user buttons are
                                  showing (ESC); the key goes straight to
                                  the app
     {"expectTelemButton": "NFAnn", "win": 1, "state": 2}   check a button:
                                  state 0 disabled, 1 enabled, 2 highlighted,
                                  3+ hidden (or "disabled"/"enabled"/
                                  "highlighted"/"hidden"); "text" checks a
                                  label instead, using a number 1-5 for the
                                  button. Record mode records telemetry
                                  presses as telemButton by label
     {"answer": true}             answer the next form.question (yes/no)
     {"expect": "Race time (mins)", "value": 30}  check a widget's value
     {"expectSub": 10}            check which subform is showing
     {"close": true}              form.close(), then wait for it to close
     {"log": "text"}              write a line to the log
     {"expectState": "browse.Idx", "value": 2}   check app internals
                                  (see APP HOOKS); "min"/"max" for a
                                  range, "tol" for float tolerance, or no
                                  value at all to just log it
     {"remember": "checkBox.noflyEnabled", "as": "nf"}   save a value;
                                  later {"expectState": "...", "value": "$nf"}
                                  checks it's back, or "notValue": "$nf"
                                  checks it changed
     {"waitEvent": "imageLoaded"} wait for the app to report an event
                                  caused by the last action step (set,
                                  link, key, button, telemKey,
                                  telemButton, close): it counts events
                                  since that action started, however many
                                  waits come between. "value" to match its
                                  value, "anyTime": true to accept an
                                  earlier one. Each event satisfies only
                                  one waitEvent
     {"confirm": "Did the map zoom in?"}   ask the tester yes/no with
                                  form.question; yes = PASS, no = FAIL.
                                  The text is wrapped onto the question's
                                  two normal-size lines ("confirmWidth" in
                                  config.jsn, default 30 chars each, so
                                  keep it under ~60); the large bold line
                                  shows "title" (default "Check (Yes = OK)").
                                  While the target form is open there's no
                                  pop-up: the text shows in a box at the
                                  bottom of the form ("bannerTop": true for
                                  the top) and the tester answers F1 = Yes,
                                  F2 = No. Meanwhile every key is kept from
                                  the target and can't close the form. With
                                  no form open, the box counts down for
                                  "lookMs" (config "confirmLookMs", default
                                  5000) before the form.question pop-up
     {"note": "Press ESC, then F1", "ms": 20000}   show instructions in
                                  the box on the target's form or telemetry
                                  window for ms (default 10000)
     {"waitTelem": 1}             wait until target telemetry window 1 is
                                  showing (no timeout unless "timeoutMs")
     {"cpuStart": true}           start tracking the target's peak CPU
     {"cpuCheck": 80}             stop tracking; FAIL if the peak was over
                                  80%. {"cpuCheck": true} only reports it
       system.getCPU() resets before every Lua call the firmware makes,
       so it's read inside the target's callbacks: after each form or
       telemetry print, and around each key (injected keys run inside a
       print, so the key's own cost is the difference). The target's
       loop() and init() can't be measured. On the DS-24 II emulator the
       numbers aren't real runtime; only the TX tells you for sure.
     {"repeat": 5, "steps": [ ... ]}   repeat a block

   ANNOUNCEMENTS: the target's calls to system.messageBox, playFile,
   playNumber, vibration and playBeep are logged ("announce audio: ...")
   and passed on, to SensorE's versions if it has replaced them. Calls
   from other apps are ignored. Like waitEvent, the waits count what
   happened since the last action step started (or "anyTime": true),
   each announcement satisfies one wait, and they PASS when it comes:
     {"waitMessage": "Restart app"}   messageBox text contains this
     {"waitAudio": "nofly"}       playFile name contains this
     {"waitNumber": 3}            playNumber value (within "tol", default
                                  0.001); true for any; "unit"/"label" too
     {"waitVibration": "left"}    "left", "right" or true; "profile": 3
     {"waitBeep": true}           playBeep (or a string the text contains)
   Add "absent": true and "forMs": 3000 to require that none comes for
   that long (a match is a FAIL). Text matches ignore case. A timeout
   lists what the app did announce. If SensorE loads after UIDriver,
   announcements made before the driver's first loop() can be missed.

   INPUTS, SENSORS AND CONTROLS
     {"setInput": "P6", "value": 0.5}   getInputs("P6") returns 0.5, for
                                  the target AND SensorE (so a script can
                                  move SensorE's sliders and "fly");
                                  "for": "target" to leave SensorE alone.
                                  getInputsVal(item) is scripted by the
                                  control the item reads (getSwitchInfo
                                  label), and returns the value as given
                                  (the item's inversion/activeOn aren't
                                  applied)
     {"clearInput": "P6"}         back to the real control (true: all)
     {"setSensor": "Altitude", "value": 120}   the target's
                                  getSensorByID/getSensorValueByID of that
                                  sensor return 120 ("sensorName" to pick
                                  one, or "id" and "param"; "$name" works)
     {"setSensor": "Latitude", "valid": false}  a sensor fault; while the
                                  lat or lon sensor is faulted, the
                                  target's gps.getPosition returns nil
     {"clearSensor": "Altitude"}  back to normal (true: all)
     {"expectControl": 1, "value": 0.5}  what the target last passed to
                                  setControl (number or registered label;
                                  "tol", default 0.01). No "value": just
                                  log it
     {"waitControl": "Flaps", "value": 1}  wait until it is
   setInput/setSensor count as actions for the waits. Overrides stay
   until cleared. The wrappers are re-applied from loop() if SensorE
   replaces the functions after UIDriver loads.

   TEXT ON SCREEN: what the target draws with lcd.drawText and
   lcd.drawNumber. Steps look at the next frame of the form, or of a
   telemetry window with "win": 2 ("win": "form" for the form; default
   the form if it's open, else telemetry window 1). Text matches ignore
   case and match part of the text ("exact": true for all of it);
   "region": [x, y, w, h] limits it to text drawn starting in that box.
     {"expectText": "Loading"}    PASS if on the next frame, else FAIL
                                  (the log lists what is on screen)
     {"expectNoText": "Error"}    the reverse
     {"waitText": "Lap 2"}        PASS when a frame shows it; timeout FAIL
     {"dumpText": true}           log every text of the next frame with
                                  its x,y; handy for writing scripts
   The text can be "$name", a value saved by a remember step.
     {"expectImage": "BDS458/17.png"}   images drawn with lcd.drawImage,
     {"expectNoImage": "red_circle"}    named by the file lcd.loadImage
     {"waitImage": "16.5.png"}          loaded them from; same options.
                                  lcd.createImage ones are named
                                  "created 480x320". dumpText lists the
                                  images too. A failed load by the target
                                  is logged as a WARN
   The recording versions of drawText/drawNumber/drawImage are swapped in only
   around the target's print callback while a text step is waiting, so
   other apps' text isn't seen and the target pays nothing otherwise.
   An app that keeps its own copy (local drawText = lcd.drawText) can't
   be seen.

   Widgets are found by the label in their row (form.addLabel), or by
   the text of a link. Add "nth": 2 for the second widget with the same
   label, or use "#12" for component index 12. Any step can carry
   "timeoutMs". If a label isn't found, the log lists the labels that
   are on the form.

   APP HOOKS: let the app under test show its internals
   UIDriver publishes system.UIDriver when its chunk loads, in every
   mode including "off". On the TX, or without UIDriver, it's nil, so
   guarded calls cost one nil test and their arguments aren't built:

     local uid = system.UIDriver          -- read it in init()
     if uid then uid.expose("browse", function() return browse end) end
     if uid then uid.check(browse.Idx >= 1, "browse.Idx in range") end
     if uid then uid.event("imageLoaded", currentImage) end

     expose(name, getter)  scripts read getter().a.b via expectState
                           "name.a.b"; the getter runs only when asked
     check(cond, msg)      a false cond is a FAIL charged to the step
                           that was running, logged with a traceback.
                           Each message is logged once (repeats are
                           counted). With no script playing, it also
                           pops up a system.messageBox
     event(name, value)    for waitEvent; "logEvents": true in
                           config.jsn logs every event
   Keep checks free of side effects (they don't run on the TX) and out
   of tight drawing loops (they count toward the app's CPU).

   LIMITS
   - Nobody can open the target form from Lua (registering with parent 0
     at init didn't work), so a human opens it once; begin with waitForm.
   - Script steps feed values through each widget's change callback, the
     way the firmware reports a human edit. They don't turn the rotary
     knob or move the focus, so the firmware's own editing isn't tested.
   - The emulator's form.setValue on an intbox calls its callback when
     the value changes; selectbox and checkbox don't. UIDriver calls the
     callback itself only if setValue didn't, so it never runs twice.
   - Inputboxes (switch assignment) aren't supported yet.
--]]

local appName = "UIDriver"
local DIR = "Apps/UIDriver/"

local cfg = {
   mode = "off", target = "", script = "", stepGapMs = 500,
   stepTimeoutMs = 10000, stopOnFail = true, overlay = true,
   recordRotary = false, confirmWidth = 30, confirmLookMs = 5000,
   logAnnouncements = true, suppressMessageBox = false,
   recordAnnouncements = false, logControls = true,
}

--------------------------------------------------------------------------------
-- logging
--------------------------------------------------------------------------------

local LOGFILE = DIR .. "result.log"

local function log(...)
   local t = {}
   for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end
   local s = table.concat(t, " ")
   print("[UID] " .. s)
   local f = io.open(LOGFILE, "a")
   if f then io.write(f, s .. "\n"); io.close(f) end
end

--------------------------------------------------------------------------------
-- keys
--------------------------------------------------------------------------------

local KEYNAMES = {"KEY_1", "KEY_2", "KEY_3", "KEY_4", "KEY_5", "KEY_ESC",
		  "KEY_ENTER", "KEY_UP", "KEY_DOWN", "KEY_MENU", "KEY_POWER"}

local function keyCode(k)
   if type(k) == "number" then return k end
   if type(k) == "string" then return _ENV[k] end
end

local function keyName(code)
   for _, n in ipairs(KEYNAMES) do
      if _ENV[n] ~= nil and _ENV[n] == code then return n end
   end
   return code
end

local function isCloseKey(code)
   return code == KEY_5 or code == KEY_ESC or (KEY_POWER ~= nil and code == KEY_POWER)
end

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local orig = {}            -- the real system/form functions
local T = {tel = {}}       -- the target's real callbacks
local comps, buttons = {}, {}
local curSub, formOpen = nil, false
local capturing, injecting, prevented = false, false, false
local lastLabel
local answers = {}         -- queued form.question answers (1/0)
local titleShown           -- the title text last set, with the step counter
local telButtons = {}      -- [win][n] = {text, state}, from setTelemetryButton

local recording = false
local rec = {}             -- recorded steps
local cbDepth = 0          -- >0 while a human-driven callback is running
local recAfter = {}        -- steps to record after that callback's own step

local steps, si, stepT0, nextAt
local finished = false
local counts = {pass = 0, fail = 0, ok = 0, checks = 0, checkFails = 0}

-- events and announcements are numbered; waits count those after the
-- last action step (set, link, key, ...) started
local seq, actionSeq, actionMarked = 0, 0, nil
local ACTIONS = {set = true, link = true, key = true, button = true, telemKey = true,
		 setInput = true, clearInput = true, setSensor = true, clearSensor = true,
		 telemButton = true, close = true}
local anns = {}            -- announcements: {kind, text, value, seq, used}
local textArm              -- {key, at}: a text step wants the next frame of key
local frameNo = 0          -- frames captured so far
local frames = {}          -- key ("form", "telem1") -> {n, items = {kind, text, x, y}}
-- image -> the file it was loaded from ("created WxH" for lcd.createImage);
-- weak keys, so images the app drops are still freed
local imageName = setmetatable({}, {__mode = "k"})

local exposed = {}         -- name -> getter, from uid.expose
local vars = {}            -- remembered values, for "$name" in expectState
local events = {}          -- name -> {n, value, step, used}, from uid.event
local checkSeen = {}       -- failed check message -> times failed

local function now() return system.getTimeCounter() end

-- x as an integer if it is a whole number, else nil. Not math.tointeger
-- alone: JETI's Lua is built with LUA_FLOORN2I = 1, so there
-- math.tointeger(0.5) is 0, not nil
--
-- The same build also floors a float when comparing it with an integer:
-- 0.5 == 0 and 2.7 == 2 are true there (float == float is exact). So
-- whole numbers are tested float-to-float, and values are compared with
-- same() below
local function whole(x)
   if math.type(x) == "integer" then return x end
   if math.type(x) == "float" and x % 1 == 0.0 then return math.tointeger(x) end
end

-- a == b, but numbers of different kinds are compared as floats
local function same(a, b)
   local ta, tb = math.type(a), math.type(b)
   if ta and tb and ta ~= tb then return a + 0.0 == b + 0.0 end
   return a == b
end

-- whose function f is, for the log: "the firmware's" or "SensorE.lua's"
local function owner(f)
   local info = debug and debug.getinfo and debug.getinfo(f, "S")
   if not info or info.what == "C" then return "the firmware's" end
   local src = tostring(info.short_src or info.source or "?")
   return (src:match("([^/\\]+)$") or src) .. "'s"
end

--------------------------------------------------------------------------------
-- CPU tracking (between cpuStart and cpuCheck)
--------------------------------------------------------------------------------

local cpuWin               -- nil, or {peaks = {source = max%}, n = samples}

local function getCPU()
   return system.getCPU and system.getCPU() or 0
end

local function cpuSample(src, v)
   if not cpuWin or type(v) ~= "number" then return end
   local p = cpuWin.peaks
   if not p[src] or v > p[src] then p[src] = v end
   cpuWin.n = cpuWin.n + 1
end

local function isTarget(label)
   if type(label) ~= "string" or cfg.target == "" then return false end
   return label == cfg.target or label:sub(1, #cfg.target + 1) == cfg.target .. " "
end

--------------------------------------------------------------------------------
-- recording
--------------------------------------------------------------------------------

local function saveRec()
   local f = io.open(DIR .. "recorded.jsn", "w")
   if f then
      io.write(f, json.encode({target = cfg.target, steps = rec}))
      io.close(f)
   end
end

local function recStep(s)
   rec[#rec+1] = s
   log("REC", json.encode(s))
   saveRec()
end

-- run a human-driven target callback, then record its step. A subform
-- change it causes (form.reinit can run initForm right away) is held
-- back so its waitSub lands after the click; a form.question it raises
-- is recorded straight away, so the answer comes before the click
local function recAround(fn, stepFn, ...)
   cbDepth = cbDepth + 1
   local ok, r = pcall(fn, ...)
   cbDepth = cbDepth - 1
   local s = stepFn()
   if s then recStep(s) end
   if cbDepth == 0 then
      for _, a in ipairs(recAfter) do recStep(a) end
      recAfter = {}
   end
   if not ok then error(r, 0) end
   return r
end

local function widgetStep(c, v)
   local s
   if c.kind == "link" then
      s = {link = c.label}
   elseif c.kind == "chk" then
      s = {set = c.label, value = c.value}
   elseif c.kind == "sel" then
      s = {set = c.label, value = (c.values and c.values[v]) or v}
   else
      s = {set = c.label, value = v}
   end
   if c.nth > 1 then s.nth = c.nth end
   return s
end

--------------------------------------------------------------------------------
-- form.* wrappers: record the components the target creates
--------------------------------------------------------------------------------

local function newComp(kind, extra)
   local c = extra or {}
   c.kind = kind
   c.label = c.label or lastLabel
   local n = 0
   for _, o in ipairs(comps) do
      if o.label == c.label then n = n + 1 end
   end
   c.nth = n + 1
   return c
end

local function addComp(c, idx)
   if not capturing then return end
   c.idx = idx
   if not c.label then c.label = "#" .. tostring(idx) end
   comps[#comps+1] = c
end

-- wraps a widget's callback: notes that it fired (so we never call it
-- twice) and records human edits in record mode
local function wrapCb(c, cb)
   if not cb then return nil end
   c.cb = cb
   c.wcb = function(v, ...)
      c.fired = true
      if c.kind ~= "chk" and c.kind ~= "link" then c.value = v end
      if not (recording and not injecting and not capturing) then
	 return cb(v, ...)
      end
      return recAround(cb, function()
			  if c.kind == "chk" and type(c.value) ~= "boolean" then c.value = not v end
			  return widgetStep(c, v)
		       end, v, ...)
   end
   return c.wcb
end

local function wrapForm()
   if not form or orig.addRow then return end
   for _, n in ipairs({"addRow", "addLabel", "addIntbox", "addSelectbox",
		       "addCheckbox", "addLink", "addTextbox", "setValue",
		       "getValue", "setButton", "preventDefault", "question",
		       "close", "setTitle"}) do
      orig[n] = form[n]
   end

   form.addRow = function(...)
      if capturing then lastLabel = nil end
      return orig.addRow(...)
   end
   form.addLabel = function(p, ...)
      local idx = orig.addLabel(p, ...)
      if capturing and p and p.label and p.label ~= "" then lastLabel = p.label end
      return idx
   end
   form.addIntbox = function(v, mn, mx, def, dec, step, cb, p)
      if not capturing then return orig.addIntbox(v, mn, mx, def, dec, step, cb, p) end
      local c = newComp("int", {value = v, min = mn, max = mx})
      local idx = orig.addIntbox(v, mn, mx, def, dec, step, wrapCb(c, cb), p)
      addComp(c, idx)
      return idx
   end
   form.addSelectbox = function(vals, cur, en, cb, p)
      if not capturing then return orig.addSelectbox(vals, cur, en, cb, p) end
      local c = newComp("sel", {value = cur, values = vals})
      local idx = orig.addSelectbox(vals, cur, en, wrapCb(c, cb), p)
      addComp(c, idx)
      return idx
   end
   form.addCheckbox = function(chk, cb, p)
      if not capturing then return orig.addCheckbox(chk, cb, p) end
      local c = newComp("chk", {value = chk})
      local idx = orig.addCheckbox(chk, wrapCb(c, cb), p)
      addComp(c, idx)
      return idx
   end
   form.addLink = function(cb, p)
      if not capturing then return orig.addLink(cb, p) end
      local c = newComp("link", {label = p and p.label})
      local idx = orig.addLink(wrapCb(c, cb), p)
      addComp(c, idx)
      return idx
   end
   form.addTextbox = function(txt, mx, cb, p)
      if not capturing then return orig.addTextbox(txt, mx, cb, p) end
      local c = newComp("text", {value = txt})
      local idx = orig.addTextbox(txt, mx, wrapCb(c, cb), p)
      addComp(c, idx)
      return idx
   end
   -- track values the target sets itself (checkbox toggles, etc.)
   form.setValue = function(idx, v)
      orig.setValue(idx, v)
      if formOpen or capturing then
	 for _, c in ipairs(comps) do
	    if c.idx == idx then c.value = v end
	 end
      end
   end
   form.setButton = function(n, text, ...)
      if formOpen or capturing then buttons[n] = text end
      return orig.setButton(n, text, ...)
   end
   -- remember the target's own title, so the step counter can be appended
   form.setTitle = function(t, ...)
      if formOpen or capturing then
	 T.title = t
	 titleShown = nil          -- re-append the counter on the next frame
      end
      return orig.setTitle(t, ...)
   end
   form.preventDefault = function(...)
      prevented = true
      return orig.preventDefault(...)
   end
   form.question = function(bold, ...)
      if #answers > 0 then
	 local a = table.remove(answers, 1)
	 log("question '" .. tostring(bold) .. "' answered " .. (a == 1 and "yes" or "no"))
	 return a
      end
      local r = orig.question(bold, ...)
      if recording and not injecting then recStep({answer = (r == 1)}) end
      return r
   end
end

-- find a component by "#idx", label (+nth), or case-insensitive label
local function find(label, nth, kind)
   nth = nth or 1
   if type(label) == "string" and label:sub(1, 1) == "#" then
      local idx = tonumber(label:sub(2))
      for _, c in ipairs(comps) do
	 if c.idx == idx then return c end
      end
   end
   local function scan(match)
      local n = 0
      for _, c in ipairs(comps) do
	 if match(c) and (not kind or c.kind == kind) then
	    n = n + 1
	    if n == nth then return c end
	 end
      end
   end
   local c = scan(function(c) return c.label == label end)
   if c then return c end
   local function norm(s) return tostring(s):lower():gsub("^%s+", ""):gsub("%s+$", "") end
   local want = norm(label)
   c = scan(function(c) return norm(c.label) == want end)
   if c then return c end
   local have = {}
   for _, o in ipairs(comps) do have[#have+1] = o.kind .. ":'" .. tostring(o.label) .. "'" end
   return nil, "no " .. (kind or "widget") .. " '" .. tostring(label) ..
      "' on subform " .. tostring(curSub) .. "; have " .. table.concat(have, ", ")
end

--------------------------------------------------------------------------------
-- injection
--------------------------------------------------------------------------------

local function injectKey(code)
   if not T.key then return false, "target form has no key callback" end
   injecting, prevented = true, false
   local c0 = getCPU()
   local ok, err = pcall(T.key, code)
   cpuSample("key " .. keyName(code), getCPU() - c0)
   pcall(T.key, KEY_RELEASED)
   injecting = false
   if not ok then return false, "target keyForm error: " .. tostring(err) end
   if isCloseKey(code) and not prevented then
      pcall(form.close)
      return "ok", keyName(code) .. " sent; not prevented, so the form closes (firmware default)"
   end
   return "ok", keyName(code) .. " sent"
end

local function toInt(v)
   if type(v) ~= "number" then return nil end
   return whole(v) or math.floor(v + 0.5)
end

-- set a widget like a human edit: setValue, then the change callback
-- unless setValue already called it
local function setWidget(c, v)
   local want
   if c.kind == "int" then
      want = toInt(v)
      if not want then return false, "intbox needs a number" end
      if want < c.min or want > c.max then
	 local cl = math.max(c.min, math.min(c.max, want))
	 log("WARN", c.label, "value", want, "outside", c.min .. ".." .. c.max,
	     "-> clamped to", cl, "(a human can't enter it)")
	 want = cl
      end
   elseif c.kind == "sel" then
      if type(v) == "string" then
	 for i, s in ipairs(c.values or {}) do if s == v then want = i end end
	 if not want then return false, "selectbox has no item '" .. v .. "'" end
      else
	 want = toInt(v)
	 if not want or want < 1 or want > #(c.values or {}) then
	    return false, "selectbox index out of range: " .. tostring(v)
	 end
      end
   elseif c.kind == "text" then
      if type(v) ~= "string" then return false, "textbox needs a string" end
      want = v
   elseif c.kind == "chk" then
      if type(v) ~= "boolean" then return false, "checkbox needs true/false" end
      if c.value == v then return true, "already " .. tostring(v) end
      injecting = true
      local ok, err = pcall(c.wcb, c.value)
      injecting = false
      if not ok then return false, "target callback error: " .. tostring(err) end
      if c.value ~= v then return false, "target didn't toggle the checkbox" end
      return true, "checkbox -> " .. tostring(v)
   else
      return false, "can't set a " .. c.kind
   end

   local before = orig.getValue(c.idx)
   if same(before, want) then return true, "already " .. tostring(want) end
   injecting, c.fired = true, false
   local ok, err = pcall(function()
	 form.setValue(c.idx, want)
	 if not c.fired and c.wcb then c.wcb(want) end
   end)
   injecting = false
   if not ok then return false, "target callback error: " .. tostring(err) end
   local got = orig.getValue(c.idx)
   return same(got, want), string.format("%s -> %s (getValue %s)", tostring(before),
				     tostring(want), tostring(got))
end

--------------------------------------------------------------------------------
-- step handlers: run(s, elapsedMs, win) returns status[, msg]
--   status nil = not done yet, true = pass, false = fail, "ok" = done
--------------------------------------------------------------------------------

local H = {}

H.waitForm   = {ctx = "any", run = function()
		   if formOpen then return "ok", "form open, subform " .. tostring(curSub) end
end}
H.waitSub    = {ctx = "any", run = function(s)
		   if formOpen and curSub == s.waitSub then return "ok", "subform " .. curSub end
end}
H.waitClosed = {ctx = "any", run = function()
		   if not formOpen then return "ok", "form closed" end
end}
H.wait       = {ctx = "any", run = function(s, el)
		   if el >= s.wait then return "ok" end
end}
H.log        = {ctx = "any", run = function(s) return "ok", s.log end}
H.answer     = {ctx = "any", run = function(s)
		   answers[#answers+1] = s.answer and 1 or 0
		   return "ok", "next question will be answered " .. (s.answer and "yes" or "no")
end}
H.expectSub  = {ctx = "any", run = function(s)
		   return curSub == s.expectSub and formOpen,
		   "subform is " .. tostring(curSub) .. ", expected " .. s.expectSub
end}

H.set = {ctx = "form", run = function(s)
	    local c, err = find(s.set, s.nth)
	    if not c then return false, err end
	    local st, msg = setWidget(c, s.value)
	    return st, c.label .. ": " .. tostring(msg)
end}

H.link = {ctx = "form", run = function(s)
	     local c, err = find(s.link, s.nth, "link")
	     if not c then return false, err end
	     injecting = true
	     local ok, e = pcall(c.wcb)
	     injecting = false
	     if not ok then return false, "target link error: " .. tostring(e) end
	     return "ok", "clicked " .. c.label
end}

H.key = {ctx = "form", run = function(s)
	    local code = keyCode(s.key)
	    if code == nil then return false, "unknown key " .. tostring(s.key) end
	    return injectKey(code)
end}

H.button = {ctx = "form", run = function(s)
	       for n = 1, 5 do
		  if buttons[n] == s.button then return injectKey(_ENV["KEY_" .. n]) end
	       end
	       local have = {}
	       for n = 1, 5 do if buttons[n] then have[#have+1] = n .. "='" .. buttons[n] .. "'" end end
	       return false, "no F key labelled '" .. s.button .. "'; have " .. table.concat(have, ", ")
end}

local function injectTelKey(win, code)
   local w = T.tel[win]
   if not w or not w.key then return false, "telemetry window " .. win .. " has no key callback" end
   injecting = true
   local c0 = getCPU()
   local ok, e = pcall(w.key, code)
   cpuSample("telemetry " .. win .. " key " .. keyName(code), getCPU() - c0)
   pcall(w.key, KEY_RELEASED)
   injecting = false
   if not ok then return false, "target telemetry key error: " .. tostring(e) end
   return "ok", keyName(code) .. " sent to telemetry window " .. win
end

H.telemKey = {ctx = "telem", run = function(s, _, win)
		 local code = keyCode(s.telemKey)
		 if code == nil then return false, "unknown key " .. tostring(s.telemKey) end
		 return injectTelKey(win, code)
end}

local STATE = {[0] = "disabled", "enabled", "highlighted"}
local function stateName(st) return STATE[st] or "hidden" end

local function listTelButtons(win)
   local have = {}
   for n = 1, 5 do
      local b = (telButtons[win] or {})[n]
      if b then have[#have+1] = string.format("F%d '%s' %s", n, b.text, stateName(b.state)) end
   end
   return #have > 0 and table.concat(have, ", ") or "none (no setTelemetryButton calls seen)"
end

-- a telemetry user button by label (or 1-5): returns n, button
local function findTelButton(win, which)
   local bs = telButtons[win] or {}
   if type(which) == "number" then return which, bs[which] end
   for n = 1, 5 do
      if bs[n] and bs[n].text == which then return n, bs[n] end
   end
end

H.telemButton = {ctx = "telem", run = function(s, _, win)
		    local n, b = findTelButton(win, s.telemButton)
		    if not b then
		       return false, "no telemetry button '" .. tostring(s.telemButton) ..
			  "' on window " .. win .. "; have " .. listTelButtons(win)
		    end
		    if b.state >= 3 then
		       return false, "button F" .. n .. " '" .. b.text .. "' is hidden; a human can't press it"
		    end
		    -- some apps (DFM-Maps' NoFly) use "disabled" to mean "toggle
		    -- off" and still take the key, so just note it
		    local st, msg = injectTelKey(win, _ENV["KEY_" .. n])
		    return st, msg .. " (button '" .. b.text .. "'" ..
		       (b.state == 0 and ", shown disabled" or "") .. ")"
end}

H.expectTelemButton = {ctx = "any", run = function(s)
			  local win = s.win or 1
			  local n, b = findTelButton(win, s.expectTelemButton)
			  if not b then
			     return false, "no telemetry button '" .. tostring(s.expectTelemButton) ..
				"' on window " .. win .. "; have " .. listTelButtons(win)
			  end
			  local shown = string.format("F%d '%s' %s (%d)", n, b.text, stateName(b.state), b.state)
			  if s.state ~= nil then
			     local want = s.state
			     if type(want) == "string" then
				-- "hidden" matches any state 3..255
				return stateName(b.state) == want, shown .. ", expected " .. want
			     end
			     return b.state == want, shown .. ", expected state " .. tostring(want)
			  end
			  if s.text ~= nil then
			     return b.text == s.text, shown .. ", expected label '" .. s.text .. "'"
			  end
			  return "ok", shown
end}

H.expect = {ctx = "form", run = function(s)
	       local c, err = find(s.expect, s.nth)
	       if not c then return false, err end
	       local got
	       if c.kind == "chk" then got = c.value
	       else
		  got = orig.getValue(c.idx)
		  if c.kind == "sel" and type(s.value) == "string" then
		     got = c.values and c.values[got]
		  end
	       end
	       return same(got, s.value), string.format("%s = %s, expected %s", c.label,
						    tostring(got), tostring(s.value))
end}

-- "browse.Idx" -> exposed.browse().Idx ; numeric parts also try integer keys
local function resolve(path)
   local parts = {}
   for p in tostring(path):gmatch("[^%.]+") do parts[#parts+1] = p end
   local getter = exposed[parts[1]]
   if not getter then
      local have = {}
      for k in pairs(exposed) do have[#have+1] = k end
      table.sort(have)
      return false, "nothing exposed as '" .. tostring(parts[1]) .. "'; have " ..
	 (#have > 0 and table.concat(have, ", ") or "none (no uid.expose calls yet)")
   end
   local v = getter()
   for i = 2, #parts do
      if type(v) ~= "table" then
	 return false, table.concat(parts, ".", 1, i - 1) .. " is " .. type(v) .. ", not a table"
      end
      local k = parts[i]
      if v[k] == nil and tonumber(k) then k = whole(tonumber(k)) or tonumber(k) end
      v = v[k]
   end
   return true, v
end

-- "$name" means a value saved by a remember step
local function deref(x)
   if type(x) == "string" and x:sub(1, 1) == "$" then return vars[x:sub(2)] end
   return x
end

H.remember = {ctx = "any", run = function(s)
		 local ok, v = resolve(s.remember)
		 if not ok then return false, v end
		 local as = s.as or s.remember
		 vars[as] = v
		 return "ok", "$" .. as .. " = " .. s.remember .. " = " .. tostring(v)
end}

H.expectState = {ctx = "any", run = function(s)
		    for _, x in ipairs({s.value, s.notValue}) do
		       if type(x) == "string" and x:sub(1, 1) == "$" and vars[x:sub(2)] == nil then
			  return false, "nothing remembered as " .. x .. " (needs a remember step first)"
		       end
		    end
		    local ok, v = resolve(s.expectState)
		    if not ok then return false, v end
		    if s.notValue ~= nil then
		       local nv = deref(s.notValue)
		       return not same(v, nv), s.expectState .. " = " .. tostring(v) ..
			  ", must not be " .. tostring(nv)
		    end
		    s = {expectState = s.expectState, value = deref(s.value), min = s.min,
			 max = s.max, tol = s.tol}
		    local shown = s.expectState .. " = " .. tostring(v)
		    if type(v) == "table" then   -- list its keys, to help write checks
		       local keys = {}
		       for k in pairs(v) do keys[#keys+1] = tostring(k) end
		       table.sort(keys)
		       if #keys > 20 then keys[21] = "... " .. (#keys - 20) .. " more"; for i = #keys, 22, -1 do keys[i] = nil end end
		       shown = s.expectState .. " = table {" .. table.concat(keys, ", ") .. "}"
		    end
		    if s.min or s.max then
		       if type(v) ~= "number" then return false, shown .. " (not a number)" end
		       local good = (not s.min or v >= s.min) and (not s.max or v <= s.max)
		       return good, shown .. ", range " .. tostring(s.min) .. ".." .. tostring(s.max)
		    elseif s.value ~= nil then
		       local good = same(v, s.value)
		       if not good and s.tol and type(v) == "number" and type(s.value) == "number" then
			  good = math.abs(v - s.value) <= s.tol
		       end
		       return good, shown .. ", expected " .. tostring(s.value)
		    end
		    return "ok", shown
end}

H.waitEvent = {ctx = "any", run = function(s)
		  local e = events[s.waitEvent]
		  if e and e.n > e.used and (s.anyTime or e.seq > actionSeq)
		  and (s.value == nil or same(e.value, s.value)) then
		     e.used = e.n
		     return "ok", s.waitEvent .. " (value " .. tostring(e.value) .. ")"
		  end
end}

-- split text into lines of at most width chars, at spaces where possible
local function wrap(text, width)
   local lines, cur = {}, ""
   for word in tostring(text):gmatch("%S+") do
      while #word > width do              -- a word longer than a line
	 if cur ~= "" then lines[#lines+1] = cur; cur = "" end
	 lines[#lines+1] = word:sub(1, width)
	 word = word:sub(width + 1)
      end
      if cur == "" then cur = word
      elseif #cur + 1 + #word <= width then cur = cur .. " " .. word
      else lines[#lines+1] = cur; cur = word end
   end
   if cur ~= "" then lines[#lines+1] = cur end
   return lines
end

-- the confirm text shown in a box on the form:
--   {lines, keys = true}  answer with F1/F2 while the form stays visible
--   {lines, at = t}       countdown before form.question (no form open)
local confirmBanner
local confirmAnswer        -- set by wKey while a keyed confirm waits: 1 or 0

H.confirm = {ctx = "loop", run = function(s, el)
		-- form open: no form.question at all. It covers the form, and the
		-- key that answers it can also reach the form (F5 closed it).
		-- Show the question in a box and take the answer from F1/F2;
		-- wKey swallows every key meanwhile
		if formOpen then
		   if not confirmBanner then
		      confirmBanner = {lines = wrap(s.confirm, 40), keys = true, top = s.bannerTop}
		      confirmAnswer = nil
		   end
		   if confirmAnswer == nil then return nil end
		   local a = confirmAnswer
		   confirmBanner, confirmAnswer = nil, nil
		   return a == 1, "tester answered " .. (a == 1 and "yes" or "no") ..
		      " (key): " .. s.confirm
		end
		if confirmBanner and confirmBanner.keys then
		   -- the form closed while waiting for a key
		   confirmBanner, confirmAnswer = nil, nil
		   return false, "form closed before the tester answered: " .. s.confirm
		end
		-- no form open: give the tester time to look, then form.question
		local look = s.lookMs or cfg.confirmLookMs
		if el < look then
		   if not confirmBanner then
		      confirmBanner = {lines = wrap(s.confirm, 40), at = now() + look - el,
				       top = s.bannerTop}
		   end
		   return nil
		end
		confirmBanner = nil
		-- the bold first line is large, so it gets a short title; the
		-- question goes on the two normal-size lines underneath
		local lines = wrap(s.confirm, cfg.confirmWidth)
		if #lines > 2 then
		   log("WARN confirm text needs " .. #lines .. " lines of " .. cfg.confirmWidth ..
			  " chars; only 2 fit, so it's cut: shorten it")
		end
		-- the real question, not the scripted-answer queue
		local q = orig.question or form.question
		local r = q(s.title or "Check (Yes = OK)", lines[1] or "", lines[2] or "", 0, false, 0)
		if r == 1 then return true, "tester answered yes: " .. s.confirm end
		if r == 0 then return false, "tester answered no: " .. s.confirm end
		return false, "question couldn't be shown (form.question returned " ..
		   tostring(r) .. "): " .. s.confirm
end}

-- instructions for the tester, in the box on the target's form or
-- telemetry window, for ms milliseconds
H.note = {ctx = "any", run = function(s, el)
	     local ms = s.ms or 10000
	     if el < ms then
		if not confirmBanner then
		   confirmBanner = {lines = wrap(s.note, 40), at = now() + ms - el,
				    note = true, top = s.bannerTop}
		end
		return nil
	     end
	     confirmBanner = nil
	     return "ok", s.note
end}

-- wait until the target's telemetry window "win" is showing
H.waitTelem = {ctx = "telem", run = function(s, _, win)
		  return "ok", "telemetry window " .. win .. " is showing"
end}

H.cpuStart = {ctx = "any", run = function()
		 cpuWin = {peaks = {}, n = 0}
		 return "ok", "CPU tracking started"
end}

H.cpuCheck = {ctx = "any", run = function(s)
		 if not cpuWin then return false, "cpuCheck without cpuStart" end
		 local srcs, peak = {}, 0
		 for src, v in pairs(cpuWin.peaks) do
		    srcs[#srcs+1] = src
		    if v > peak then peak = v end
		 end
		 table.sort(srcs)
		 local parts = {}
		 for _, src in ipairs(srcs) do parts[#parts+1] = src .. " " .. cpuWin.peaks[src] .. "%" end
		 local dev, emu = system.getDeviceType()
		 local where = tostring(dev) .. (emu == 1 and " emulator" or "")
		 local msg = string.format("peak %d%% over %d samples on %s: %s", peak, cpuWin.n,
					   where, #parts > 0 and table.concat(parts, ", ") or "no samples")
		 if emu == 1 and tostring(dev):find("II") then
		    msg = msg .. " (DS-24 II emulator: not real runtime, check on the TX)"
		 end
		 cpuWin = nil
		 if type(s.cpuCheck) == "number" then
		    return peak <= s.cpuCheck, msg .. ", limit " .. s.cpuCheck .. "%"
		 end
		 return "ok", msg
end}

H.close = {ctx = "form", run = function()
	      local ok, e = pcall(form.close)
	      if not ok then return false, "form.close error: " .. tostring(e) end
	      return "ok", "close requested"
end}

local VERBS = {"waitForm", "waitSub", "waitClosed", "wait", "log", "answer",
	       "expectSub", "set", "link", "key", "button", "telemKey",
	       "expect", "close", "cpuStart", "cpuCheck", "expectState",
	       "waitEvent", "confirm", "note", "waitTelem", "telemButton",
	       "expectTelemButton", "remember", "waitMessage", "waitAudio",
	       "waitNumber", "waitVibration", "waitBeep", "expectText",
	       "expectNoText", "waitText", "dumpText", "expectImage",
	       "expectNoImage", "waitImage", "setInput", "clearInput",
	       "setSensor", "clearSensor", "expectControl", "waitControl"}

local function verbOf(s)
   for _, v in ipairs(VERBS) do
      if s[v] ~= nil then return v end
   end
end

local function flatten(list, out, errs)
   for _, s in ipairs(list or {}) do
      if s["repeat"] then
	 for _ = 1, s["repeat"] do flatten(s.steps, out, errs) end
      else
	 -- JETI's json.decode returns floats (42.0), on the TX too. A human
	 -- edit hands the callback an integer, so pass whole numbers as ints
	 for k, x in pairs(s) do
	    if type(x) == "number" then s[k] = whole(x) or x end
	 end
	 local v = verbOf(s)
	 if not v then errs[#errs+1] = json.encode(s) end
	 if s.absent and not s.timeoutMs then
	    s.timeoutMs = (s.forMs or 3000) + 5000
	 end
	 if v == "waitTelem" and not s.win then
	    s.win = type(s.waitTelem) == "number" and s.waitTelem or 1
	 end
	 s._verb = v
	 out[#out+1] = s
	 if v == "close" then out[#out+1] = {waitClosed = true, _verb = "waitClosed"} end
      end
   end
   return out
end

--------------------------------------------------------------------------------
-- step machine
--------------------------------------------------------------------------------

local function finish(why)
   finished = true
   log(string.format("==== %s: %d steps run, %d PASS, %d FAIL, %d ok; " ..
			"app checks: %d passed, %d failed ====",
		     why, si - 1, counts.pass, counts.fail, counts.ok,
		     counts.checks, counts.checkFails))
   for msg, n in pairs(checkSeen) do
      log("   check failed " .. n .. "x: " .. msg)
   end
end

local function report(s, st, msg)
   local tag
   if st == true then tag = "PASS"; counts.pass = counts.pass + 1
   elseif st == false then tag = "FAIL"; counts.fail = counts.fail + 1
   else tag = "ok"; counts.ok = counts.ok + 1 end
   log(string.format("%3d %-4s %-10s %s", si, tag, s._verb, msg or ""))
   s._text, textArm = nil, nil
   si, stepT0 = si + 1, nil
   nextAt = now() + (s._verb == "wait" and 0 or cfg.stepGapMs)
   if st == false and cfg.stopOnFail then
      finish("STOPPED on failure")
   elseif si > #steps then
      finish("DONE")
   end
end

local running = false      -- a step is in progress (it may be blocked in a question)

local function runSteps(ctx, win)
   -- form.question blocks, and meanwhile the emulator keeps calling loop()
   -- and print callbacks; without this guard the same step runs again
   if running then return end
   if cfg.mode ~= "play" or not steps or finished then return end
   local t = now()
   if nextAt and t < nextAt then return end
   local s = steps[si]
   if not s then return finish("DONE") end
   local h = H[s._verb]
   if not stepT0 then stepT0 = t end

   if h.ctx == ctx or h.ctx == "any" then
      if h.ctx ~= "telem" or win == (s.win or 1) then
	 -- mark where an action starts, so waits after it only count
	 -- events/announcements it caused
	 if ACTIONS[s._verb] and actionMarked ~= si then
	    actionSeq, actionMarked = seq, si
	 end
	 running = true
	 local ok, st, msg = pcall(h.run, s, t - stepT0, win)
	 running = false
	 if not ok then return report(s, false, "driver error: " .. tostring(st)) end
	 if st ~= nil then return report(s, st, msg) end
      end
   end

   -- timeouts are checked from the driver's loop
   if ctx == "loop" then
      local limit = s.timeoutMs
	 or ((s._verb == "waitForm" or s._verb == "confirm" or s._verb == "note"
	      or s._verb == "waitTelem") and 0)
	 or cfg.stepTimeoutMs
      if limit > 0 and t - stepT0 > limit then
	 local need = h.ctx == "form" and " (needs the target form open)"
	    or h.ctx == "telem" and (" (needs target telemetry window " .. (s.win or 1) .. " showing)")
	    or ""
	 local extra = h.onTimeout and h.onTimeout(s) or ""
	 report(s, false, "timed out after " .. limit .. " ms" .. need .. extra)
      end
   end
end

--------------------------------------------------------------------------------
-- wrapped target callbacks
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- text on screen: expectText, expectNoText, waitText, dumpText
--------------------------------------------------------------------------------

-- Run a target print callback. Only while a text step is waiting for
-- this window are lcd.drawText/drawNumber swapped for recording ones,
-- and they're put back as soon as the target's print returns; so only
-- the target's own text is seen, and otherwise nothing is added
local function capturePrint(key, fn, w, h)
   if not (textArm and textArm.key == key and lcd and lcd.drawText) then
      return fn(w, h)
   end
   local items = {}
   local dt, dn, di = lcd.drawText, lcd.drawNumber, lcd.drawImage
   lcd.drawText = function(x, y, text, ...)
      items[#items+1] = {kind = "text", text = tostring(text), x = x, y = y}
      return dt(x, y, text, ...)
   end
   if dn then
      lcd.drawNumber = function(x, y, num, ...)
	 items[#items+1] = {kind = "text", text = tostring(whole(num) or num), x = x, y = y}
	 return dn(x, y, num, ...)
      end
   end
   if di then
      lcd.drawImage = function(x, y, img, ...)
	 local name = img == nil and "nil image" or imageName[img] or "unknown image"
	 items[#items+1] = {kind = "image", text = name, x = x, y = y}
	 return di(x, y, img, ...)
      end
   end
   local ok, err = pcall(fn, w, h)
   lcd.drawText, lcd.drawNumber, lcd.drawImage = dt, dn, di
   frameNo = frameNo + 1
   frames[key] = {n = frameNo, items = items}
   if not ok then error(err, 0) end
end

local function textKey(s)
   if s.win == "form" then return "form" end
   if s.win then return "telem" .. tostring(s.win) end
   return formOpen and "form" or "telem1"
end

local function whereName(key)
   return key == "form" and "the form" or ("telemetry window " .. key:sub(6))
end

-- the latest frame of the step's window drawn after the step started
local function frameFor(s)
   if not s._text then s._text = {key = textKey(s), at = frameNo} end
   textArm = s._text
   local f = frames[s._text.key]
   if f and f.n > s._text.at then return f end
end

-- the text a step looks for; "$name" is a remembered value
local function textWant(s, field)
   local w = s[field]
   if type(w) == "string" and w:sub(1, 1) == "$" then
      if vars[w:sub(2)] == nil then
	 return nil, "nothing remembered as " .. w .. " (needs a remember step first)"
      end
      return tostring(vars[w:sub(2)])
   end
   return w
end

local function num(v) return tostring(whole(v) or v) end

local function textMatches(it, s, want)
   local r = s.region
   if type(r) == "table" then
      if not (it.x and it.y and it.x >= r[1] and it.x < r[1] + r[3]
	      and it.y >= r[2] and it.y < r[2] + r[4]) then return false end
   end
   want = tostring(want)
   if s.exact then return it.text == want end
   return it.text:lower():find(want:lower(), 1, true) ~= nil
end

local function findText(f, s, want, kind)
   for _, it in ipairs(f.items) do
      if it.kind == (kind or "text") and textMatches(it, s, want) then return it end
   end
end

local function screenList(f, kind)
   kind = kind or "text"
   local t, n = {}, 0
   for _, it in ipairs(f.items) do
      if it.kind == kind then
	 n = n + 1
	 if n <= 15 then t[#t+1] = "'" .. it.text .. "'" end
      end
   end
   if n > 15 then t[#t+1] = "... " .. (n - 15) .. " more" end
   return #t > 0 and table.concat(t, ", ") or ("no " .. kind)
end

local function textTimeout(s)
   local key = s._text and s._text.key or textKey(s)
   local f = frames[key]
   if not (f and s._text and f.n > s._text.at) then
      return "; " .. whereName(key) .. " wasn't drawn (is it showing?)"
   end
   return "; on screen: " .. screenList(f)
end

-- expect / expectNo / wait steps for one kind of item ("text" or "image")
local function screenSteps(kind, expectV, noV, waitV)
   local function timeout(s)
      local r = textTimeout(s)
      if kind == "text" or r:sub(1, 13) ~= "; on screen: " then return r end
      local f = frames[s._text.key]
      return "; images on screen: " .. screenList(f, kind)
   end
   local function at(it) return "'" .. it.text .. "' at " .. num(it.x) .. "," .. num(it.y) end
   H[expectV] = {ctx = "any", onTimeout = timeout, run = function(s)
		    local want, err = textWant(s, expectV)
		    if not want then return false, err end
		    local f = frameFor(s)
		    if not f then return end
		    local it = findText(f, s, want, kind)
		    if it then return true, at(it) end
		    return false, "'" .. tostring(want) .. "' not on " ..
		       whereName(s._text.key) .. "; on screen: " .. screenList(f, kind)
   end}
   H[noV] = {ctx = "any", onTimeout = timeout, run = function(s)
		local want, err = textWant(s, noV)
		if not want then return false, err end
		local f = frameFor(s)
		if not f then return end
		local it = findText(f, s, want, kind)
		if it then return false, at(it) .. " is on " .. whereName(s._text.key) end
		return true, "'" .. tostring(want) .. "' not on " .. whereName(s._text.key)
   end}
   H[waitV] = {ctx = "any", onTimeout = timeout, run = function(s)
		  local want, err = textWant(s, waitV)
		  if not want then return false, err end
		  local f = frameFor(s)
		  if not f then return end
		  local it = findText(f, s, want, kind)
		  if it then return true, at(it) end
   end}
end
screenSteps("text", "expectText", "expectNoText", "waitText")
screenSteps("image", "expectImage", "expectNoImage", "waitImage")

H.dumpText = {ctx = "any", onTimeout = textTimeout, run = function(s)
		 local f = frameFor(s)
		 if not f then return end
		 local nt = 0
		 for _, it in ipairs(f.items) do
		    if it.kind == "text" then nt = nt + 1 end
		    log(string.format("   %-5s %6s,%-6s '%s'", it.kind, num(it.x), num(it.y), it.text))
		 end
		 return "ok", nt .. " texts, " .. (#f.items - nt) .. " images on " .. whereName(s._text.key)
end}

--------------------------------------------------------------------------------

local function wInit(sub)
   comps, buttons, lastLabel = {}, {}, nil
   titleShown = nil                -- a rebuilt form may have reset the title
   capturing = true
   local ok, err = pcall(T.init, sub)
   capturing = false
   curSub, formOpen = sub, true
   local list = {}
   for _, c in ipairs(comps) do list[#list+1] = c.kind .. ":'" .. tostring(c.label) .. "'" end
   log("subform " .. tostring(sub) .. ": " .. table.concat(list, ", "))
   if recording then
      if cbDepth > 0 then recAfter[#recAfter+1] = {waitSub = sub}
      else recStep({waitSub = sub}) end
   end
   if not ok then error(err, 0) end
end

local function wKey(key)
   -- a keyed confirm is waiting: every key is the tester's answer or is
   -- ignored; none reach the target, and none may close the form
   if confirmBanner and confirmBanner.keys and not injecting then
      pcall(orig.preventDefault or form.preventDefault)
      if key == KEY_1 then confirmAnswer = 1
      elseif key == KEY_2 then confirmAnswer = 0 end
      return
   end
   if not T.key then return end
   if injecting then return T.key(key) end
   prevented = false
   local r
   if recording and key ~= KEY_RELEASED and key ~= KEY_ENTER
   and (cfg.recordRotary or (key ~= KEY_UP and key ~= KEY_DOWN)) then
      r = recAround(T.key, function() return {key = keyName(key)} end, key)
   else
      r = T.key(key)
   end
   -- a human key is its own firmware call, so getCPU() is the key's cost
   if key ~= KEY_RELEASED then cpuSample("key " .. keyName(key), getCPU()) end
   return r
end

local function drawBanner(w, h)
   local b = confirmBanner
   if not b then return end
   local lines = {}
   for i = 1, math.min(#b.lines, 5) do lines[#lines+1] = b.lines[i] end
   if b.keys then
      lines[#lines+1] = "F1 = Yes      F2 = No"
   elseif b.note then
      lines[#lines+1] = "(continues in " .. math.max(0, (b.at - now()) // 1000 + 1) .. " s)"
   else
      local secs = math.max(0, (b.at - now()) // 1000 + 1)
      lines[#lines+1] = "Look now - question in " .. secs .. " s"
   end
   local lh = 12
   local bh = #lines * lh + 4
   local y = b.top and 18 or (h - bh - 2)
   lcd.setColor(255, 255, 255)
   lcd.drawFilledRectangle(2, y, w - 4, bh)
   lcd.setColor(0, 0, 0)
   lcd.drawRectangle(2, y, w - 4, bh)
   for i, l in ipairs(lines) do
      lcd.drawText(6, y + 2 + (i - 1) * lh, l, FONT_MINI)
   end
end

local function statusTag()
   if cfg.mode == "play" and steps then
      return finished and string.format("UID %dP %dF", counts.pass, counts.fail)
	 or string.format("UID %d/%d", math.min(si, #steps), #steps)
   elseif recording then
      return "UID REC " .. #rec
   end
end

-- "title" mode: the target's own title plus [UID 12/55]. setTitle is only
-- called when the text changes
local function updateTitle()
   if not orig.setTitle then return end
   local tag = statusTag()
   if not tag then return end
   local t = (T.title or T.label or "") .. "  [" .. tag .. "]"
   if t ~= titleShown then
      titleShown = t
      pcall(orig.setTitle, t)
   end
end

local function overlay(w)
   local txt = statusTag()
   if not txt then return end
   lcd.setColor(255, 255, 255)
   lcd.drawFilledRectangle(w - 72, 2, 70, 13)
   lcd.setColor(0, 0, 0)
   lcd.drawText(w - 70, 3, txt, FONT_MINI)
end

local function wPrint(w, h)
   if T.print then capturePrint("form", T.print, w, h) end
   cpuSample("form print", getCPU())   -- before the driver adds its own work
   runSteps("form")
   drawBanner(w, h)
   if cfg.overlay == "box" then overlay(w)
   elseif cfg.overlay then updateTitle() end
end

local function wClose()
   formOpen = false
   if T.close then return T.close() end
end

--------------------------------------------------------------------------------
-- hooks, installed when the chunk loads
--------------------------------------------------------------------------------

-- Did the target's own file call the wrapper this is used in? Other apps
-- call the same system functions. Level 1 is this function, 2 the
-- wrapper, 3 its caller; C frames (pcall) are skipped
local function callerIsTarget()
   if not (debug and debug.getinfo) then return true end
   for lvl = 3, 8 do
      local info = debug.getinfo(lvl, "S")
      if not info then return true end
      if info.what ~= "C" then
	 local src = info.source or ""
	 if src == "" or src == "=?" then return true end  -- no debug info: assume target
	 return src:find(cfg.target, 1, true) ~= nil
      end
   end
   return true
end

--------------------------------------------------------------------------------
-- announcements: messageBox, playFile, playNumber, vibration, playBeep
--------------------------------------------------------------------------------

local AUDIOTYPE = {}
local function audioType(t)
   if not next(AUDIOTYPE) then
      for _, n in ipairs({"AUDIO_BACKGROUND", "AUDIO_IMMEDIATE", "AUDIO_QUEUE"}) do
	 if _ENV[n] then AUDIOTYPE[_ENV[n]] = n end
      end
   end
   return t == nil and "AUDIO_QUEUE" or AUDIOTYPE[t] or tostring(t)
end

-- what each call says: kind, text for the log, and fields the waits match
local ANN = {
   messageBox = function(msg, tmo)
      msg = tostring(msg)
      return {kind = "message", match = msg, text = msg}
   end,
   playFile = function(fn, typ)
      fn = tostring(fn)
      return {kind = "audio", match = fn, text = fn .. " (" .. audioType(typ) .. ")"}
   end,
   playNumber = function(v, dec, unit, label)
      local text = tostring(v) .. (unit and (" " .. tostring(unit)) or "") ..
	 (label and (" [" .. tostring(label) .. "]") or "")
      return {kind = "number", value = tonumber(v), unit = unit, label = label,
	      match = text, text = text .. ", " .. tostring(dec) .. " decimals"}
   end,
   vibration = function(right, prof)
      local side = right and "right" or "left"
      return {kind = "vibration", right = right and true or false, profile = prof,
	      match = side, text = side .. " stick, profile " .. tostring(prof)}
   end,
   playBeep = function(rep, hz, len)
      local text = string.format("%s repeats, %s Hz, %s ms",
				 tostring(rep), tostring(hz), tostring(len))
      return {kind = "beep", match = text, text = text}
   end,
}
local KINDVERB = {message = "waitMessage", audio = "waitAudio", number = "waitNumber",
		  vibration = "waitVibration", beep = "waitBeep"}
local annWrapper = {}      -- name -> our current wrapper

local function announced(a)
   seq = seq + 1
   a.seq = seq
   anns[#anns+1] = a
   if #anns > 200 then table.remove(anns, 1) end
   if cfg.logAnnouncements then log("announce " .. a.kind .. ": " .. a.text) end
   if recording and cfg.recordAnnouncements then
      local st = {}
      if a.kind == "audio" then st.waitAudio = a.match:match("([^/]+)$") or a.match
      elseif a.kind == "number" then st.waitNumber = a.value or true
      elseif a.kind == "vibration" then st.waitVibration = a.match; st.profile = a.profile
      elseif a.kind == "message" then st.waitMessage = a.match
      else st[KINDVERB[a.kind]] = true end
      if cbDepth > 0 then recAfter[#recAfter+1] = st else recStep(st) end
   end
end

-- Wrap whatever is in system.<name> now. SensorE replaces playFile,
-- playNumber, vibration and playBeep when its chunk loads, which may be
-- after this one, so the driver's loop() calls this again and wraps the
-- replacement; calls still go on to it
local function wrapAnnouncements()
   for name, describe in pairs(ANN) do
      local under = system[name]
      if under and under ~= annWrapper[name] then
	 log((annWrapper[name] and "system." .. name .. " was replaced; wrapping " or
	      "system." .. name .. ": wrapping ") .. owner(under) .. " version")
	 local w = function(...)
	    if callerIsTarget() then
	       local ok, a = pcall(describe, ...)
	       if ok then announced(a) end
	       if name == "messageBox" and cfg.suppressMessageBox then return end
	    end
	    return under(...)
	 end
	 annWrapper[name] = w
	 system[name] = w
      end
   end
end

local function annMatches(a, s, v)
   local want = s[v]
   if a.kind == "number" then
      if type(want) == "number" and
	 not (a.value and math.abs(a.value - want) <= (s.tol or 0.001)) then return false end
      if s.unit and a.unit ~= s.unit then return false end
      if s.label and a.label ~= s.label then return false end
      return true
   end
   if a.kind == "vibration" and s.profile and a.profile ~= s.profile then return false end
   if type(want) == "string" then
      return a.match:lower():find(want:lower(), 1, true) ~= nil
   end
   return true
end

local function findAnn(s, v, kind)
   for _, a in ipairs(anns) do
      if a.kind == kind and not a.used and (s.anyTime or a.seq > actionSeq)
      and annMatches(a, s, v) then
	 return a
      end
   end
end

local function annWait(v, kind)
   return {ctx = "any",
	   run = function(s, el)
	      local a = findAnn(s, v, kind)
	      if s.absent then
		 local forMs = s.forMs or 3000
		 if a then
		    a.used = true
		    return false, "unexpected " .. kind .. ": " .. a.text
		 end
		 if el >= forMs then
		    return true, "no matching " .. kind .. " in " .. forMs .. " ms"
		 end
		 return
	      end
	      if a then
		 a.used = true
		 return true, kind .. ": " .. a.text
	      end
	   end,
	   -- on a timeout, say what the app did announce
	   onTimeout = function(s)
	      local seen = {}
	      for _, a in ipairs(anns) do
		 if a.kind == kind and (s.anyTime or a.seq > actionSeq) then
		    seen[#seen+1] = a.text .. (a.used and " (used)" or "")
		 end
	      end
	      if #seen == 0 then return "; no " .. kind .. " since the last action" end
	      return "; " .. kind .. " since the last action: " .. table.concat(seen, ", ")
	   end}
end

for v, kind in pairs({waitMessage = "message", waitAudio = "audio",
		      waitNumber = "number", waitVibration = "vibration",
		      waitBeep = "beep"}) do
   H[v] = annWait(v, kind)
end

--------------------------------------------------------------------------------
-- scripted inputs, sensor overrides and faults, controls
--------------------------------------------------------------------------------

local inputs, nInputs = {}, 0      -- "P6" -> {value, targetOnly}
local switchName = setmetatable({}, {__mode = "k"})  -- SwitchItem -> "SA" (false: unknown)
local sensorOv, nSensorOv = {}, 0  -- "id-param" -> {value, valid, label}
local controls = {}                -- control number -> {label, value, at, logged}

local function idKey(id, param)
   return tostring(whole(id) or id) .. "-" .. tostring(whole(param) or param)
end

-- the control a SwitchItem reads, from system.getSwitchInfo; cached
local function itemName(sw)
   if sw == nil then return nil end
   local nm = switchName[sw]
   if nm == nil then
      nm = false
      if system.getSwitchInfo then
	 local ok, info = pcall(system.getSwitchInfo, sw)
	 if ok and type(info) == "table" and info.label and info.assigned ~= false then
	    nm = tostring(info.label):upper()
	 end
      end
      switchName[sw] = nm
   end
   return nm or nil
end

-- getInputs("P6", ...) and getInputsVal(item, ...): scripted values replace
-- the real ones. With no setInput active they cost one test. SensorE's
-- reads go through here too, so a script can move its sliders
local function inputsWrapper(under, byItem)
   return function(...)
      if nInputs == 0 then return under(...) end
      local n = select("#", ...)
      local vals = table.pack(under(...))
      local tgt
      for i = 1, n do
	 local a = select(i, ...)
	 local nm = byItem and itemName(a) or (a ~= nil and tostring(a):upper())
	 local o = nm and inputs[nm]
	 if o then
	    if o.targetOnly and tgt == nil then tgt = callerIsTarget() end
	    if not o.targetOnly or tgt then vals[i] = o.value end
	 end
      end
      return table.unpack(vals, 1, n)
   end
end

-- getSensorByID / getSensorValueByID: overrides apply to the target's
-- reads only; the entry is copied so the sensor's own table isn't changed
local function sensorWrapper(under)
   return function(id, param, ...)
      local r = under(id, param, ...)
      if nSensorOv == 0 or type(r) ~= "table" then return r end
      local o = sensorOv[idKey(id, param)]
      if not o or not callerIsTarget() then return r end
      local c = {}
      for k, v in pairs(r) do c[k] = v end
      if o.value ~= nil then c.value = o.value end
      if o.valid ~= nil then c.valid = o.valid end
      return c
   end
end

-- gps.getPosition: nil while the target's lat or lon sensor is faulted
-- (SensorE's own version reads them as SensorE, so it isn't affected)
local function positionWrapper(under)
   return function(id, pLat, pLon, ...)
      if nSensorOv > 0 then
	 local a, b = sensorOv[idKey(id, pLat)], sensorOv[idKey(id, pLon)]
	 if ((a and a.valid == false) or (b and b.valid == false)) and callerIsTarget() then
	    return nil
	 end
      end
      return under(id, pLat, pLon, ...)
   end
end

local function control(n)
   local c = controls[n]
   if not c then c = {}; controls[n] = c end
   return c
end

local function registerControlWrapper(under)
   return function(n, label, short, ...)
      if callerIsTarget() then
	 control(n).label = label
	 log("control " .. tostring(n) .. " registered: '" .. tostring(label) .. "'")
      end
      return under(n, label, short, ...)
   end
end

-- setControl is often called every loop, so a change is logged at most
-- once a second per control; the latest value is always kept
local function setControlWrapper(under)
   return function(n, value, delay, ...)
      if callerIsTarget() then
	 local c = control(n)
	 local t = now()
	 if value ~= c.value then
	    c.value, c.at = value, t
	    if cfg.logControls and (not c.logged or t - c.logged >= 1000) then
	       c.logged = t
	       log(string.format("control %s%s = %s (delay %s ms)", tostring(n),
				 c.label and (" '" .. c.label .. "'") or "", tostring(value),
				 tostring(delay)))
	    end
	 end
      end
      return under(n, value, delay, ...)
   end
end

-- {table getter, function name, wrapper maker}; wrapped whatever is there,
-- re-wrapped from loop() if another app (SensorE) replaces one later
local HOOKS = {
   {function() return system end, "getInputs", function(u) return inputsWrapper(u, false) end},
   {function() return system end, "getInputsVal", function(u) return inputsWrapper(u, true) end},
   {function() return system end, "getSensorByID", sensorWrapper},
   {function() return system end, "getSensorValueByID", sensorWrapper},
   {function() return gps end, "getPosition", positionWrapper},
   {function() return system end, "registerControl", registerControlWrapper},
   {function() return system end, "setControl", setControlWrapper},
}
local hookWrapper = {}

local function wrapHooks()
   for i, h in ipairs(HOOKS) do
      local tbl = h[1]()
      local under = tbl and tbl[h[2]]
      if under and under ~= hookWrapper[i] then
	 log((hookWrapper[i] and h[2] .. " was replaced; wrapping " or h[2] .. ": wrapping ") ..
	     owner(under) .. " version")
	 hookWrapper[i] = h[3](under)
	 tbl[h[2]] = hookWrapper[i]
      end
   end
end

-- find sensors by label (and "sensorName") or "id"/"param"; "$name" works
local function findSensors(s, field)
   local want = s[field]
   if type(want) == "string" and want:sub(1, 1) == "$" then
      want = vars[want:sub(2)]
      if want == nil then return nil, "nothing remembered as " .. s[field] end
   end
   if s.id then
      return {{key = idKey(s.id, s.param or 1),
	       label = (type(want) == "string" and want) or idKey(s.id, s.param or 1)}}
   end
   if not system.getSensors then return nil, "system.getSensors isn't available" end
   local ok, list = pcall(system.getSensors)
   if not ok or type(list) ~= "table" then return nil, "system.getSensors failed" end
   local found, labels = {}, {}
   for _, e in ipairs(list) do
      if e.param and e.param ~= 0 then
	 labels[#labels+1] = tostring(e.label)
	 if tostring(e.label):lower() == tostring(want):lower()
	 and (not s.sensorName or e.sensorName == s.sensorName) then
	    found[#found+1] = {key = idKey(e.id, e.param), label = tostring(e.label)}
	 end
      end
   end
   if #found == 0 then
      return nil, "no sensor labelled '" .. tostring(want) .. "'; have " ..
	 (#labels > 0 and table.concat(labels, ", ") or "none")
   end
   return found
end

H.setInput = {ctx = "any", run = function(s)
		 local nm = tostring(s.setInput):upper()
		 local v = tonumber(s.value)
		 if not v then return false, "setInput needs a number \"value\" (-1..1)" end
		 if v < -1 or v > 1 then log("WARN setInput " .. nm .. " value " .. v .. " is outside -1..1") end
		 if not inputs[nm] then nInputs = nInputs + 1 end
		 inputs[nm] = {value = v, targetOnly = s["for"] == "target"}
		 return "ok", nm .. " = " .. tostring(v) ..
		    (s["for"] == "target" and " (target only)" or " (target and SensorE)")
end}

H.clearInput = {ctx = "any", run = function(s)
		   if s.clearInput == true then
		      inputs, nInputs = {}, 0
		      return "ok", "all inputs back to the real controls"
		   end
		   local nm = tostring(s.clearInput):upper()
		   if inputs[nm] then inputs[nm] = nil; nInputs = nInputs - 1 end
		   return "ok", nm .. " back to the real control"
end}

H.setSensor = {ctx = "any", run = function(s)
		  if s.value == nil and s.valid == nil then
		     return false, "setSensor needs \"value\" and/or \"valid\""
		  end
		  local found, err = findSensors(s, "setSensor")
		  if not found then return false, err end
		  local names = {}
		  for _, f in ipairs(found) do
		     if not sensorOv[f.key] then nSensorOv = nSensorOv + 1 end
		     sensorOv[f.key] = {value = s.value, valid = s.valid, label = f.label}
		     names[#names+1] = f.label .. " (" .. f.key .. ")"
		  end
		  local what = {}
		  if s.value ~= nil then what[#what+1] = "value " .. tostring(s.value) end
		  if s.valid ~= nil then what[#what+1] = "valid " .. tostring(s.valid) end
		  return "ok", table.concat(names, ", ") .. ": " .. table.concat(what, ", ")
end}

H.clearSensor = {ctx = "any", run = function(s)
		    if s.clearSensor == true then
		       sensorOv, nSensorOv = {}, 0
		       return "ok", "all sensors back to normal"
		    end
		    local found, err = findSensors(s, "clearSensor")
		    if not found then return false, err end
		    for _, f in ipairs(found) do
		       if sensorOv[f.key] then sensorOv[f.key] = nil; nSensorOv = nSensorOv - 1 end
		    end
		    return "ok", tostring(s.clearSensor) .. " back to normal"
end}

-- a control by number or registered label
local function findControl(which)
   if type(which) == "number" then return controls[which], tostring(which) end
   for n, c in pairs(controls) do
      if c.label and tostring(c.label):lower() == tostring(which):lower() then
	 return c, tostring(n) .. " '" .. c.label .. "'"
      end
   end
   return nil, "'" .. tostring(which) .. "'"
end

local function controlCheck(s, v, waiting)
   local c, name = findControl(s[v])
   if not c or c.value == nil then
      if waiting then return end
      return false, "control " .. name .. " hasn't been set by the target"
   end
   local want = deref(s.value)
   if want == nil then return "ok", "control " .. name .. " = " .. tostring(c.value) end
   local good = type(c.value) == "number" and math.abs(c.value - want) <= (s.tol or 0.01)
   if good then return true, "control " .. name .. " = " .. tostring(c.value) end
   if waiting then return end
   return false, "control " .. name .. " = " .. tostring(c.value) .. ", expected " .. tostring(want)
end

H.expectControl = {ctx = "any", run = function(s) return controlCheck(s, "expectControl", false) end}
H.waitControl = {ctx = "any", run = function(s) return controlCheck(s, "waitControl", true) end,
		 onTimeout = function(s)
		    local c = findControl(s.waitControl)
		    return "; last value " .. tostring(c and c.value)
		 end}

-- remember which file each image came from, for expectImage. Called at
-- chunk load, before any app's init() loads its images
local function wrapImages()
   if not lcd then return end
   local load, create = lcd.loadImage, lcd.createImage
   if load then
      lcd.loadImage = function(path, ...)
	 local img = load(path, ...)
	 if img ~= nil then
	    imageName[img] = tostring(path)
	 elseif callerIsTarget() then
	    log("WARN the target's lcd.loadImage failed: " .. tostring(path))
	 end
	 return img
      end
   end
   if create then
      lcd.createImage = function(w, h, ...)
	 local img = create(w, h, ...)
	 if img ~= nil then imageName[img] = "created " .. tostring(w) .. "x" .. tostring(h) end
	 return img
      end
   end
end

local function install()
   orig.registerForm = system.registerForm
   orig.registerTelemetry = system.registerTelemetry

   system.registerForm = function(n, parent, label, i, k, p, c)
      if not isTarget(label) or T.init then
	 return orig.registerForm(n, parent, label, i, k, p, c)
      end
      wrapForm()   -- in case form was nil when the chunk loaded
      T.init, T.key, T.print, T.close = i, k, p, c
      T.label = label              -- the title until the target sets one
      log("hooked form '" .. label .. "'")
      return orig.registerForm(n, parent, label, wInit, wKey, wPrint, wClose)
   end

   system.registerTelemetry = function(n, label, size, p, k)
      if not isTarget(label) then
	 return orig.registerTelemetry(n, label, size, p, k)
      end
      T.tel[n] = {print = p, key = k, label = label}
      log("hooked telemetry window " .. n .. " '" .. label .. "'")
      local wp = function(w, h)
	 if p then capturePrint("telem" .. n, p, w, h) end
	 cpuSample("telemetry " .. n .. " print", getCPU())
	 runSteps("telem", n)
	 drawBanner(w, h)
      end
      local wk = k and function(key)
	 if recording and not injecting and key ~= KEY_RELEASED then
	    -- record the button's label as it was when pressed (the
	    -- callback may relabel it); a plain key if it has none
	    local label
	    for i = 1, 5 do
	       if _ENV["KEY_" .. i] == key then
		  local b = (telButtons[n] or {})[i]
		  label = b and b.text
	       end
	    end
	    return recAround(k, function()
				if label then return {telemButton = label, win = n} end
				return {telemKey = keyName(key), win = n}
			     end, key)
	 end
	 return k(key)
      end
      return orig.registerTelemetry(n, label, size, wp, wk)
   end

   -- telemetry user buttons (6.05, DS-24 II only). Other apps call this
   -- too, so only calls from the target's own file are recorded; the
   -- emulator's debug library says which file called
   if system.setTelemetryButton then
      orig.setTelemetryButton = system.setTelemetryButton
      system.setTelemetryButton = function(win, n, text, state, ...)
	 if callerIsTarget() then
	    telButtons[win] = telButtons[win] or {}
	    telButtons[win][n] = {text = text, state = state or 0}  -- API default: DISABLED
	 end
	 return orig.setTelemetryButton(win, n, text, state, ...)
      end
   end

   wrapForm()
   wrapAnnouncements()
   wrapImages()
   wrapHooks()
end

local function loadConfig()
   local txt = io.readall(DIR .. "config.jsn")
   if not txt then
      print("[UID] no " .. DIR .. "config.jsn; UIDriver is off")
      return
   end
   local c = json.decode(txt)
   if type(c) ~= "table" then
      print("[UID] can't decode " .. DIR .. "config.jsn; UIDriver is off")
      return
   end
   for k, v in pairs(c) do
      if type(v) == "number" then v = whole(v) or v end  -- json gives floats
      cfg[k] = v
   end
end

local function loadScript()
   local txt = io.readall(DIR .. cfg.script)
   if not txt then log("can't read script " .. DIR .. cfg.script); return end
   local sc = json.decode(txt)
   if type(sc) ~= "table" or type(sc.steps) ~= "table" then
      log("script " .. cfg.script .. " has no \"steps\" list"); return
   end
   local errs = {}
   local out = flatten(sc.steps, {}, errs)
   if #errs > 0 then
      for _, e in ipairs(errs) do log("unknown step: " .. e) end
      return
   end
   steps, si = out, 1
   log("script " .. cfg.script .. ": " .. #steps .. " steps")
end

--------------------------------------------------------------------------------
-- the app-hook API, published as system.UIDriver
--------------------------------------------------------------------------------

local function playing()
   return cfg.mode == "play" and steps ~= nil and not finished
end

local api = {}

function api.expose(name, getter)
   if type(getter) == "function" then
      exposed[name] = getter
      log("app exposed '" .. tostring(name) .. "'")
   end
end

function api.check(cond, msg)
   if cond then
      counts.checks = counts.checks + 1
      return true
   end
   msg = tostring(msg or "check")
   local seen = checkSeen[msg]
   checkSeen[msg] = (seen or 0) + 1
   counts.checkFails = counts.checkFails + 1
   if seen then return false end      -- log each message once
   counts.fail = counts.fail + 1      -- each distinct failing check is a FAIL
   local where = playing() and string.format("during step %d (%s)", si,
					     steps[si] and steps[si]._verb or "?")
      or "no script playing"
   local tb = debug and debug.traceback and debug.traceback("", 2) or ""
   log("CHECK FAIL " .. where .. ": " .. msg .. tb)
   if playing() then
      if cfg.stopOnFail then finish("STOPPED on app check failure") end
   else
      pcall(system.messageBox, "Check failed: " .. msg, 5)
   end
   return false
end

function api.event(name, value)
   local e = events[name] or {n = 0, used = 0}
   seq = seq + 1
   e.n, e.value, e.seq = e.n + 1, value, seq
   events[name] = e
   if cfg.logEvents then log("event " .. tostring(name) .. " " .. tostring(value)) end
end

local function start()
   pcall(loadConfig)
   local f = io.open(LOGFILE, "w")
   if f then io.close(f) end
   system.UIDriver = api          -- in every mode, so checks work by hand too
   if cfg.mode ~= "play" and cfg.mode ~= "record" then return end
   log(appName .. " mode=" .. cfg.mode .. " target=" .. cfg.target)
   install()
   if cfg.mode == "play" then
      loadScript()
   else
      recording = true
      rec = {}
      recStep({waitForm = true})
   end
end

local okStart, errStart = pcall(start)
if not okStart then print("[UID] start failed: " .. tostring(errStart)) end

--------------------------------------------------------------------------------
-- the driver's own app callbacks
--------------------------------------------------------------------------------

local function statusPrint(w, h)
   local line
   if cfg.mode == "play" then
      if not steps then line = "play: no script"
      elseif finished then line = string.format("done %dP %dF", counts.pass, counts.fail)
      else line = string.format("step %d/%d  %dP %dF", si, #steps, counts.pass, counts.fail) end
   elseif cfg.mode == "record" then
      line = "rec: " .. #rec .. " steps"
   else
      line = "off"
   end
   lcd.drawText(4, 2, "UIDriver " .. cfg.target, FONT_MINI)
   lcd.drawText(4, 14, line, FONT_NORMAL)
end

local function init()
   system.registerTelemetry(1, appName, 1, statusPrint)
end

local function loop()
   if cfg.mode == "play" or cfg.mode == "record" then wrapAnnouncements(); wrapHooks() end
   runSteps("loop")
end

return {init = init, loop = loop, author = "DFM", version = "0.1", name = appName}
