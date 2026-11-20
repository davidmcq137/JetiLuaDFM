--[[
   UIDriver.lua -- drive another app's forms and telemetry keys from a
   script, as if a human were pressing the keys. Emulator use only.

   HOW IT WORKS (the same idea as SensorE)
   When this file's chunk loads, it replaces system.registerForm,
   system.registerTelemetry and several form.* functions in the shared
   tables. Every app that registers a form or telemetry window gets
   wrapped callbacks in place of its own (except UIDriver, SensorE and
   SensorL). For every app but the one chosen in UIDriver's menu the
   wrappers just call the app's callbacks. For the chosen app (the
   target) script steps run inside its own print callbacks, so every
   form.* call happens while the target's form is the active one. The
   emulator loads every app's chunk before calling any init(), so the
   order of the apps in the list doesn't matter.

   An app is named by its file: Apps/DFM-Maps.lua is "DFM-Maps", and its
   UIDriver folder is Apps/DFM-Maps/UIDriver/. Calls from other files in
   Apps/DFM-Maps/ count as DFM-Maps' too.

   INSTALL: like the other apps in this repo, the code lives in the app's
   folder and Apps/ has a symlink to it (top-level *.lua is gitignored):
     ln -s UIDriver/UIDriver.lua Apps/UIDriver.lua
     ln -s SpikeTgt/SpikeTgt.lua Apps/SpikeTgt.lua   (self-test target)

   THE MENU (Applications > UIDriver): pick the App to drive (the apps
   that registered a form or telemetry window), a Script from its
   UIDriver folder, and the Mode (off, play or record). The choice is
   applied when you leave the menu: a changed choice, or one whose run has
   finished, starts a fresh run; otherwise the run carries on. Then open
   the target's own menu as usual. The choice is saved in
   Apps/UIDriver/selection.jsn and applied again when the apps next load.

   FILES in each app's folder, Apps/<App>/UIDriver/:
     *.jsn          scripts (any .jsn but config.jsn)
     config.jsn     optional settings for this app; a script can also
                    carry its own {"config": {...}}, which wins:
       {"stepGap": 500,           -- pause after each step
        "stepTimeout": "10s",     -- default per-step timeout
                                  -- (durations: see DURATIONS below)
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
        "logControls": true,      -- log the target's setControl changes
        "logEvents": false,       -- log every uid.event
        "sensorConfig": "Apps/DFM-Maps/JSON",  -- optional: SensorE uses
                                  -- this config dir instead of the one in
                                  -- Apps/SensorE.jsn. SensorE reads it once,
                                  -- so after changing it restart the apps
        "sensorLog": "Log/20190926/16-56-45.log"}  -- optional: the log
                                  -- SensorL replays instead of SensorL.jsn's
                                  -- (read once too)
     result.log     the run's results (also echoed to the console as [UID])
     rec-<date>-<time>.jsn   a recording; it's a playable script, so
                    rename it to keep it (rec-*.jsn is gitignored)
   Apps/UIDriver/result.log gets the log lines while no app is chosen.

   SCRIPT: {"steps": [ ... ]}, each step one object
     {"waitForm": true}           wait until a human opens the target form
                                  (no timeout unless "timeout" is given)
     {"waitSub": 7}               wait until subform 7 is showing
     {"waitClosed": true}         wait until the form has closed
     {"wait": 1000}               pause: 1000 ms, or "2s", "1:30", ...
                                  (any length: the step timeout doesn't apply)
     {"set": "Race time (mins)", "value": 30}     intbox (raw integer)
     {"set": "Select Field to Browse", "value": "BDS"}  selectbox by text
     {"set": "Select Field to Browse", "value": 2}      ... or by index
     {"set": "Enable Triangle Racecourse", "value": true}   checkbox
     {"set": "Name", "value": "abc"}              textbox
     {"set": "Start Switch", "value": "SA"}       inputbox: a control
     {"set": "Start Switch", "value": {"switch": "SC", "mode": "S",
                                       "activeOn": -1}}  with mode and
                                  activeOn (createSwitch's modifiers:
                                  S P I C E); defaults: P1..P10 in a
                                  proportional inputbox "P", else "S",
                                  activeOn 1. false unassigns it. expect
                                  takes the same values (mode and
                                  activeOn are checked only if given).
                                  setInput on that control then makes
                                  getInputsVal return the switch's result
                                  (getSwitchInfo's .value too)
     {"restore": true}            put this subform's widgets back to the
                                  values they had when the driver first
                                  saw them (through the target's callbacks,
                                  so apps that pSave settings save them
                                  again); or {"restore": "label"}
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
                                  "look" (config "confirmLook", default
                                  "5s") before the form.question pop-up
     {"note": "Press ESC, then F1", "ms": 20000}   show instructions in
                                  the box on the target's form or telemetry
                                  window for ms (default 10000)
     {"waitTelem": 1}             wait until target telemetry window 1 is
                                  showing (no timeout unless "timeout")
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
                                  0.001); true for any; "min"/"max" for a
                                  range; "unit"/"label" too
     {"waitVibration": "left"}    "left", "right" or true; "profile": 3
     {"waitBeep": true}           playBeep (or a string the text contains)
   Add "absent": true and "for": "3s" to require that none comes for
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
     {"waitSensor": "Speed", "sensorName": "MGPS", "min": 15}  wait
                                  until the sensor reads >= 15 (as the
                                  target reads it, overrides included;
                                  invalid counts as not yet). "max" for
                                  <=, or "value" with "tol" (default 0.01);
                                  "sensorName" is needed when several
                                  sensors share the label; "as": "name"
                                  keeps the value for "$name".
                                  Works with SensorE, SensorL or real
                                  sensors. Set "timeout" for long waits
     {"expectSensor": "Fuel remaining", "max": 50}  the same, checked once
     {"expectControl": 1, "value": 0.5}  what the target last passed to
                                  setControl (number or registered label;
                                  "tol", default 0.01; or "min" (>=)
                                  and/or "max" (<=)). None of them: just
                                  log it
     {"waitControl": "Flaps", "value": 1}  wait until it is
   setInput/setSensor count as actions for the waits. Overrides stay
   until cleared. The wrappers are re-applied from loop() if SensorE
   replaces the functions after UIDriver loads.

   NUMBERS: expectState, waitSensor/expectSensor, waitControl/
   expectControl and waitNumber all take "value" (+ "tol"), "min" (>=)
   and "max" (<=); give both for a range. "$name" works in each.

   SENSORE / SENSORL: control the sensor emulator through system.SensorE
   (simulated flight) or system.SensorL (log replay); only one may run.
   Their state is exposed as "sensorE" / "sensorL": expectState
   "sensorE.t", "sensorE.x", "sensorL.t", "sensorL.done", ... and a FAIL
   line ends with the emulator's t (and SensorE's x, y). sensorPause,
   sensorTime and waitSensorTime work with either; for SensorL t is
   seconds of log time after the first data line, and sensorTime waits
   until SensorL has got there (forward or back). The other sensor*
   steps need SensorE.
     {"sensorPause": true}        freeze time and the GPS simulator
                                  (false resumes)
     {"sensorStep": 10}           while paused: run 10 simulator steps of
                                  200 ms each, and wait until they've run
                                  (SensorE steps when the target reads
                                  its GPS sensors)
     {"sensorTime": 30}           set SensorE's t (seconds)
     {"waitSensorTime": 40}       wait until t reaches 40 (set
                                  "timeout" if that's far off)
     {"sensorPosition": [120, -40]}  hold the GPS output at x, y from
                                  SensorE's origin, in its xString frame
                                  (false releases)
     {"sensorPosition": {"lat": "41.340050", "lon": "-74.430933",
                         "north": -3, "east": 5}}  hold it at a lat/lon,
                                  optionally offset in metres. Write
                                  lat/lon as strings: json numbers are
                                  float32 (about 0.5 m off). "$name"
                                  works; sensorE.latStr/lonStr give the
                                  current position as strings, and
                                  sensorE.x/y the matching x, y
     {"sensorVars": {"xp": 0, "yp": -100, "heading": 90}}  set the
                                  simulator's xp, yp, heading, zp, pitch
     {"sensorField": "DCRC Walt Good Field"}  GPS origin field (or index)
   SensorE loads its config on the first getSensors call; "sensorConfig"
   in the app's config.jsn picks the dir. setTime and setField need it loaded.

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
   "timeout". If a label isn't found, the log lists the labels that
   are on the form.

   DURATIONS ("timeout", "for", "look", "wait", and config "stepGap",
   "stepTimeout", "confirmLook"): a number is ms; a string carries its
   unit: "500ms", "90s", "7m", "1m30s", "1h", or minutes:seconds
   "2:55", "4:34.6" (and "1:02:03" for h:mm:ss). The old keys
   timeoutMs, forMs, lookMs, stepGapMs, stepTimeoutMs and confirmLookMs
   still work and take ms. A misspelt timeout key (timeoutMS,
   timeOut, ...) gets a WARN.

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
   - An inputbox "set" passes the target's callback a SwitchItem made
     with system.createSwitch (firmware 5.01), as the firmware does after
     a human assigns a control; it doesn't use the firmware's dialog.
--]]

local appName = "UIDriver"

-- Emulator only. On a transmitter UIDriver would wrap every app's
-- functions and could feed a chosen app fake controls and sensors,
-- which could move real servos through that app's setControl outputs;
-- it's also large for the TX's memory. So on a TX it does nothing but
-- say so
do
   local dev, emu = system.getDeviceType()
   if emu ~= 1 then
      return {init = function()
		 print("UIDriver: runs only in the emulator; doing nothing on " .. tostring(dev))
		 system.messageBox("UIDriver runs only in the emulator", 5)
	      end,
	      loop = nil, author = "DFM", version = "0.2", name = appName}
   end
end

local HOME = "Apps/UIDriver/"
local SELFILE = HOME .. "selection.jsn"

-- apps never offered or wrapped: the driver and the sensor emulators
local SKIP = {UIDriver = true, SensorE = true, SensorL = true}

-- settings; each run starts from these, then the app's config.jsn, then
-- the script's "config"
local DEFAULTS = {
   stepGapMs = 500,
   stepTimeoutMs = 10000, stopOnFail = true, overlay = true,
   recordRotary = false, confirmWidth = 30, confirmLookMs = 5000,
   logAnnouncements = true, suppressMessageBox = false,
   recordAnnouncements = false, logControls = true, logEvents = false,
}
local cfg = {mode = "off", target = "", script = ""}
for k, v in pairs(DEFAULTS) do cfg[k] = v end

-- the run is live: a target chosen and play or record mode
local function active()
   return cfg.target ~= "" and (cfg.mode == "play" or cfg.mode == "record")
end

local function appDir(id) return "Apps/" .. id .. "/UIDriver/" end

--------------------------------------------------------------------------------
-- logging
--------------------------------------------------------------------------------

local LOGFILE = HOME .. "result.log"   -- the target's own once one is chosen

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
-- every wrapped app, by id: {id, label, registered, init, key, print,
-- close, tel = {[win] = {print, key, label}}, title}; T is the target's
local apps = {}
local function getApp(id)
   local a = apps[id]
   if not a then a = {id = id, tel = {}}; apps[id] = a end
   return a
end
local T = {tel = {}}       -- the target's record (a dummy while none is chosen)
local comps, buttons = {}, {}
local curSub, formOpen = nil, false
local capSub               -- the subform being built (during capture)
local originals = {}       -- "sub|label|nth" -> {v = first value seen}, for restore
local capturing, injecting, prevented = false, false, false
local lastLabel
local answers = {}         -- queued form.question answers (1/0)
local titleShown           -- the title text last set, with the step counter
local telButtons = {}      -- [win][n] = {text, state}, from setTelemetryButton
local telButtonsOf = {}    -- app id -> its telButtons (kept for every app)

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
		 restore = true,
		 sensorPause = true, sensorTime = true, sensorStep = true, sensorField = true,
		 sensorPosition = true, sensorVars = true,
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

-- A duration in ms. Strings carry their unit: "500ms", "90s", "7m",
-- "1m30s", "1h", or a clock time "2:55", "4:34.6", "1:02:03" (the
-- part before each ":" times 60, plus what follows). A plain number
-- (or a string of just a number) is ms. Returns nil and why if it's bad
local UNIT_MS = {ms = 1, s = 1000, m = 60000, h = 3600000}
local function durationMs(v)
   local secs
   if type(v) == "number" then
      return math.floor(v + 0.5)
   elseif type(v) ~= "string" then
      return nil, "not a duration: " .. tostring(v)
   end
   local str = string.gsub(v, "%s", "")
   if tonumber(str) then return math.floor(tonumber(str) + 0.5) end
   if string.find(str, ":", 1, true) then
      -- m:ss[.f] or h:mm:ss[.f]
      secs = 0
      for part in string.gmatch(str .. ":", "([^:]*):") do
	 local n = tonumber(part)
	 if not n or n < 0 then return nil, "bad time \"" .. v .. "\" (want m:ss or h:mm:ss)" end
	 secs = secs * 60 + n
      end
      return math.floor(secs * 1000 + 0.5)
   end
   local ms, rest = 0, str
   while rest ~= "" do
      local num, unit, after = string.match(rest, "^(%d*%.?%d+)(%a+)(.*)$")
      if not num or not UNIT_MS[unit] then
	 return nil, "bad duration \"" .. v .. "\" (want e.g. \"500ms\", \"90s\", \"7m\", \"1m30s\" or \"2:55\")"
      end
      ms = ms + tonumber(num) * UNIT_MS[unit]
      rest = after
   end
   return math.floor(ms + 0.5)
end

-- a duration for a log line: "250 ms", "90 s", "7 min", "4 min 34.6 s"
local function fmtMs(ms)
   if ms < 1000 then return ms .. " ms" end
   local m, sec = ms // 60000, (ms % 60000) / 1000
   local ss = sec % 1 == 0.0 and string.format("%d", sec) or string.format("%.1f", sec)
   if m == 0 then return ss .. " s" end
   if sec == 0.0 then return m .. " min" end
   return m .. " min " .. ss .. " s"
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

-- which app a chunk belongs to: "Apps/DFM-Maps.lua" and
-- "Apps/DFM-Maps/foo.lua" are both "DFM-Maps"
local function appOfSource(src)
   src = tostring(src or ""):gsub("\\", "/")
   return src:match("Apps/([^/]+)%.lua$") or src:match("Apps/([^/]+)/")
      or src:match("([^/]+)%.lua$") or src:match("([^/]+)%.lc$")
end

-- the app whose Lua code made the call that reached the wrapper this is
-- used in: the first Lua frame from level 3 up (1 is this function, 2 the
-- wrapper; C frames such as pcall are skipped), or from "from" when
-- called through a helper. nil if it can't be told
local function callerApp(from)
   if not (debug and debug.getinfo) then return nil end
   from = from or 3
   for lvl = from, from + 5 do
      local info = debug.getinfo(lvl, "S")
      if not info then return nil end
      if info.what ~= "C" then
	 local src = info.source or ""
	 if src == "" or src == "=?" then return nil end
	 return appOfSource(src) or false
      end
   end
   return nil
end

--------------------------------------------------------------------------------
-- recording
--------------------------------------------------------------------------------

local recFile              -- this recording's file, in the target's UIDriver folder

local function saveRec()
   if not recFile then return end
   local f = io.open(recFile, "w")
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

--------------------------------------------------------------------------------
-- switch items (inputboxes, getInputsVal)
--------------------------------------------------------------------------------

local inputs, nInputs = {}, 0      -- "P6" -> {value, targetOnly}

-- SwitchItem -> {name = "SA", mode = "S", activeOn = 1}, or false when it
-- isn't assigned. Filled by our createSwitch wrapper (which knows activeOn)
-- or from system.getSwitchInfo
local switchSpecs = setmetatable({}, {__mode = "k"})

local function switchInfo(sw)
   if sw == nil or not system.getSwitchInfo then return nil end
   local ok, info = pcall(system.getSwitchInfo, sw)
   if ok and type(info) == "table" then return info end
end

local function itemSpec(sw)
   if sw == nil then return nil end
   local sp = switchSpecs[sw]
   if sp == nil then
      sp = false
      local info = switchInfo(sw)
      if info and info.label and info.assigned ~= false then
	 sp = {name = tostring(info.label):upper(),
	       mode = info.mode or (info.proportional and "P" or "S"),
	       activeOn = info.activeOn}
      end
      switchSpecs[sw] = sp
   end
   return sp or nil
end

-- what getInputsVal returns for a switch item when its control is at raw.
-- Measured in the emulator: S (or E) in the mode means switch evaluation,
-- even with P ("PS" is what the firmware's dialog makes): 1 when active,
-- else -1. A two/three-position switch (SA..SP) is active at its activeOn
-- position; other controls when they reach activeOn. P alone passes the
-- position through (I inverts, C maps it to 0..1)
local function evalSwitch(sp, raw)
   if raw == nil or not sp then return raw end
   local m = (sp.mode or "S"):upper()
   local inv = m:find("I") ~= nil
   if m:find("P") and not m:find("S") and not m:find("E") then
      local v = inv and -raw or raw
      if m:find("C") then v = (v + 1) / 2 end
      return v
   end
   local on = sp.activeOn or 1
   local active
   if sp.name:match("^S%a$") then
      active = math.abs(raw - on) < 0.5
   elseif on >= 0.0 then
      active = raw >= on
   else
      active = raw <= on
   end
   if inv then active = not active end
   return active and 1 or -1
end

-- an inputbox value from a script: "SA", {"switch": "SA", "mode": "S",
-- "activeOn": 1} or false (unassigned). Defaults: mode "P" for P1..P10 in
-- a proportional inputbox, else "S"; activeOn 1 for switch modes
local function parseSwitch(v, prop)
   if v == false or v == "" then return {name = ""} end
   if type(v) == "string" then v = {switch = v} end
   if type(v) ~= "table" or type(v.switch) ~= "string" then return nil end
   local nm = v.switch:upper()
   local mode = v.mode and tostring(v.mode):upper() or
      ((prop and nm:match("^P%d+$")) and "P" or "S")
   local on = v.activeOn
   if on == nil then
      on = (mode:find("P") and not mode:find("S") and not mode:find("E")) and 0 or 1
   end
   return {name = nm, mode = mode, activeOn = on}
end

local function describeSwitch(sw)
   local sp = itemSpec(sw)
   if not sp then return "unassigned" end
   return string.format("%s mode %s activeOn %s", sp.name, tostring(sp.mode),
			tostring(sp.activeOn))
end

-- a recorded step's value for a switch item (the short form when it is
-- the default for that control)
local function switchStepValue(sw, prop)
   local sp = itemSpec(sw)
   if not sp then return false end
   local d = parseSwitch(sp.name, prop)
   if sp.mode == d.mode and (sp.activeOn == nil or same(sp.activeOn, d.activeOn)) then
      return sp.name
   end
   return {switch = sp.name, mode = sp.mode, activeOn = whole(sp.activeOn) or sp.activeOn}
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
   elseif c.kind == "input" then
      s = {set = c.label, value = switchStepValue(v, c.prop)}
      local info = switchInfo(v)
      if info then
	 log(string.format("inputbox '%s' assigned by hand; getSwitchInfo: label %s mode %s " ..
			   "activeOn %s proportional %s assigned %s value %s", c.label,
			   tostring(info.label), tostring(info.mode), tostring(info.activeOn),
			   tostring(info.proportional), tostring(info.assigned),
			   tostring(info.value)))
      end
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
   -- the first value seen for each widget, so "restore" can put it back
   if c.kind ~= "link" then
      c.key = tostring(capSub) .. "|" .. tostring(c.label) .. "|" .. tostring(c.nth)
      if originals[c.key] == nil then originals[c.key] = {v = c.value} end
   end
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
		       "addCheckbox", "addLink", "addTextbox", "addInputbox", "setValue",
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
   if orig.addInputbox then
      form.addInputbox = function(sw, prop, cb, p)
	 if not capturing then return orig.addInputbox(sw, prop, cb, p) end
	 local c = newComp("input", {value = sw, prop = prop and true or false})
	 local idx = orig.addInputbox(sw, prop, wrapCb(c, cb), p)
	 addComp(c, idx)
	 return idx
      end
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
   elseif c.kind == "input" then
      if not system.createSwitch then
	 return false, "setting an inputbox needs system.createSwitch (firmware 5.01)"
      end
      local sp = parseSwitch(v, c.prop)
      if not sp then
	 return false, 'inputbox needs "SA", {"switch": "SA", "mode": "S", ' ..
	    '"activeOn": 1} or false'
      end
      if sp.name ~= "" and not c.prop and sp.mode:find("P") and not sp.mode:find("S")
      and not sp.mode:find("E") then
	 log("WARN", c.label, "is switch-only; a human can't assign", sp.name,
	     "proportionally")
      end
      local before = describeSwitch(c.value)
      local okC, item = pcall(system.createSwitch, sp.name, sp.mode or "S", sp.activeOn or 0)
      if not okC or item == nil then
	 return false, "system.createSwitch failed: " .. tostring(item)
      end
      if sp.name ~= "" then
	 local info = switchInfo(item)
	 if info and info.assigned == false then
	    return false, "the firmware doesn't know the control " .. sp.name
	 end
	 switchSpecs[item] = sp
      else
	 switchSpecs[item] = false
      end
      injecting, c.fired = true, false
      -- the emulator may or may not take a SwitchItem in setValue; the
      -- callback is what tells the target, as a human assignment would
      pcall(orig.setValue, c.idx, item)
      local ok, err = pcall(function()
	    if not c.fired and c.wcb then c.wcb(item) end
      end)
      injecting = false
      if not ok then return false, "target callback error: " .. tostring(err) end
      c.value = item
      local info = sp.name ~= "" and switchInfo(item)
      local fw = ""
      if info then
	 fw = string.format(" (getSwitchInfo: label %s mode %s activeOn %s proportional %s value %s)",
			    tostring(info.label), tostring(info.mode),
			    tostring(info.activeOn), tostring(info.proportional),
			    tostring(info.value))
      end
      -- check our switch model against the firmware: with no setInput on
      -- this control, getInputsVal is the real one. Not for logical
      -- switches: getInputs("L2") is always 0 (measured), though
      -- getInputsVal and getSwitchInfo read them
      if sp.name ~= "" and not sp.name:match("^L%d+$") and nInputs == 0
      and system.getInputs and system.getInputsVal then
	 local okr, raw = pcall(system.getInputs, sp.name)
	 local okv, real = pcall(system.getInputsVal, item)
	 if okr and okv and raw ~= nil and real ~= nil then
	    local pred = evalSwitch(sp, raw)
	    fw = fw .. string.format(" [%s at %s: getInputsVal %s, model %s]", sp.name,
				     tostring(raw), tostring(real), tostring(pred))
	    if math.abs(pred - real) > 0.01 then
	       log("WARN UIDriver's switch model differs from the firmware for",
		   describeSwitch(item), "at", raw, ": firmware", real, "model", pred)
	    end
	 end
      end
      return true, before .. " -> " .. describeSwitch(item) .. fw
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

-- put widgets on this subform back to the values they had when the
-- driver first saw them (true: all of them; or one label)
H.restore = {ctx = "form", run = function(s)
		local done = {}
		for _, c in ipairs(comps) do
		   local o = c.key and originals[c.key]
		   if o and (s.restore == true or s.restore == c.label)
		   and c.kind ~= "link" and not same(c.value, o.v) then
		      local okr, msg
		      if c.kind == "input" then
			 if not c.wcb then
			    okr, msg = false, "no callback"
			 else
			    local before = describeSwitch(c.value)
			    injecting, c.fired = true, false
			    pcall(orig.setValue, c.idx, o.v)
			    local ok, err = pcall(c.wcb, o.v)
			    injecting = false
			    c.value = o.v
			    okr = ok
			    msg = ok and (before .. " -> " .. describeSwitch(o.v))
			       or ("target callback error: " .. tostring(err))
			 end
		      else
			 okr, msg = setWidget(c, o.v)
		      end
		      done[#done+1] = c.label .. ": " .. tostring(msg)
		      if not okr then return false, table.concat(done, "; ") end
		   end
		end
		if #done == 0 then
		   return true, (s.restore == true and "nothing to restore on this subform"
				    or ("nothing to restore for " .. tostring(s.restore)))
		end
		return true, table.concat(done, "; ")
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
	       if c.kind == "input" then
		  local want = parseSwitch(s.value, c.prop)
		  if not want then return false, "expect on an inputbox needs a switch value" end
		  local sp = itemSpec(c.value)
		  local desc = describeSwitch(c.value)
		  if want.name == "" then
		     return not sp, c.label .. " = " .. desc .. ", expected unassigned"
		  end
		  local okv = sp and sp.name == want.name
		  if okv and type(s.value) == "table" then
		     -- mode and activeOn are checked only when the script gives them
		     if s.value.mode and sp.mode then
			okv = sp.mode == tostring(s.value.mode):upper()
		     end
		     if okv and s.value.activeOn ~= nil and sp.activeOn ~= nil then
			okv = same(sp.activeOn, s.value.activeOn)
		     end
		  end
		  return okv and true or false, c.label .. " = " .. desc .. ", expected " ..
		     (type(s.value) == "table" and (want.name .. " mode " .. want.mode ..
						     " activeOn " .. tostring(want.activeOn))
		      or want.name)
	       end
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

-- numeric checks shared by the wait/expect steps: "value" (within
-- "tol"), "min" (>=) and "max" (<=), any of them, "$name" allowed.
-- Returns good (or nil, err for a bad step) and a "(want ...)" text
local function numWant(v, s, defTol)
   local conds, good = {}, true
   local want = deref(s.value)
   if type(want) ~= "number" then want = nil end   -- true etc. mean "any"
   if want ~= nil then
      local tol = s.tol or defTol
      conds[#conds+1] = "= " .. tostring(want) .. " (tol " .. tostring(tol) .. ")"
      good = good and math.abs(v - want) <= tol
   end
   for _, k in ipairs({"min", "max"}) do
      if s[k] ~= nil then
	 local lim = deref(s[k])
	 if type(lim) ~= "number" then
	    return nil, "\"" .. k .. "\" " .. tostring(s[k]) .. " isn't a number"
	 end
	 if k == "min" then
	    conds[#conds+1] = ">= " .. tostring(lim)
	    good = good and v + 0.0 >= lim + 0.0
	 else
	    conds[#conds+1] = "<= " .. tostring(lim)
	    good = good and v + 0.0 <= lim + 0.0
	 end
      end
   end
   return good, #conds > 0 and (" (want " .. table.concat(conds, " and ") .. ")") or ""
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
		    s = {expectState = s.expectState, value = deref(s.value), min = deref(s.min),
			 max = deref(s.max), tol = s.tol}
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
	       "setSensor", "clearSensor", "expectControl", "waitControl",
	       "sensorPause", "sensorTime", "sensorStep", "sensorField",
	       "sensorPosition", "sensorVars", "waitSensorTime", "restore",
	       "waitSensor", "expectSensor"}

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
	    if type(x) == "table" then
	       for k2, x2 in pairs(x) do
		  if type(x2) == "number" then x[k2] = whole(x2) or x2 end
	       end
	    end
	 end
	 local v = verbOf(s)
	 if not v then errs[#errs+1] = "unknown step: " .. json.encode(s) end
	 -- durations: "timeout", "for", "look" and "wait" (a number is ms,
	 -- a string carries its unit) become the ms keys used inside; the
	 -- old timeoutMs, forMs and lookMs still work
	 for _, d in ipairs({{"timeout", "timeoutMs"}, {"for", "forMs"},
			     {"look", "lookMs"}, {"wait", "wait"}}) do
	    local key, msKey = d[1], d[2]
	    -- ("for" is also setInput's "target"/"all"; "wait" a verb only)
	    if s[key] ~= nil and (key ~= "wait" or v == "wait")
	    and (key ~= "for" or s.absent) then
	       local ms, why = durationMs(s[key])
	       if ms then
		  s[msKey] = ms
	       else
		  errs[#errs+1] = "\"" .. key .. "\": " .. why .. ": " .. json.encode(s)
	       end
	    end
	 end
	 for k in pairs(s) do
	    local lk = string.lower(k)
	    if (string.find(lk, "^timeout") and k ~= "timeout" and k ~= "timeoutMs")
	    or ((lk == "forms" or lk == "lookms") and k ~= "forMs" and k ~= "lookMs") then
	       log("WARN step " .. #out + 1 .. ": unknown key \"" .. k ..
		   "\" (use \"timeout\": \"90s\", \"2:55\", ...); ignored")
	    end
	 end
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
   if st == false and system.SensorE and system.SensorE.getState then
      local ok, g = pcall(system.SensorE.getState)
      if ok and type(g) == "table" and g.t then
	 msg = (msg or "") .. string.format("  [SensorE t=%.1f x=%s y=%s]", g.t,
					    tostring(g.x and math.floor(g.x + 0.5)),
					    tostring(g.y and math.floor(g.y + 0.5)))
      end
   elseif st == false and system.SensorL and system.SensorL.getState then
      local ok, g = pcall(system.SensorL.getState)
      if ok and type(g) == "table" and g.t then
	 msg = (msg or "") .. string.format("  [SensorL t=%.1f]", g.t)
      end
   end
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
	      or s._verb == "waitTelem" or s._verb == "wait") and 0)
	 or cfg.stepTimeoutMs
      if limit > 0 and t - stepT0 > limit then
	 local need = h.ctx == "form" and " (needs the target form open)"
	    or h.ctx == "telem" and (" (needs target telemetry window " .. (s.win or 1) .. " showing)")
	    or ""
	 local extra = h.onTimeout and h.onTimeout(s) or ""
	 report(s, false, "timed out after " .. fmtMs(limit) .. need .. extra)
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
   capSub = sub
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
   if not active() then return false end
   if not (debug and debug.getinfo) then return true end
   for lvl = 3, 8 do
      local info = debug.getinfo(lvl, "S")
      if not info then return true end
      if info.what ~= "C" then
	 local src = info.source or ""
	 if src == "" or src == "=?" then return true end  -- no debug info: assume target
	 return appOfSource(src) == cfg.target
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
      if type(want) == "number" or s.min ~= nil or s.max ~= nil then
	 if not a.value then return false end
	 local good = numWant(a.value, {value = want, min = s.min, max = s.max, tol = s.tol}, 0.001)
	 if not good then return false end
      end
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
		    return true, "no matching " .. kind .. " in " .. fmtMs(forMs)
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

local sensorOv, nSensorOv = {}, 0  -- "id-param" -> {value, valid, label}
local controls = {}                -- control number -> {label, value, at, logged}
local controlsOf = {}              -- app id -> its controls (kept for every app)

local function idKey(id, param)
   return tostring(whole(id) or id) .. "-" .. tostring(whole(param) or param)
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
	 local sp = byItem and itemSpec(a)
	 local nm
	 if byItem then nm = sp and sp.name else nm = a ~= nil and tostring(a):upper() end
	 local o = nm and inputs[nm]
	 if o then
	    if o.targetOnly and tgt == nil then tgt = callerIsTarget() end
	    if not o.targetOnly or tgt then
	       -- a switch item gives the switch's result, not the raw position
	       vals[i] = byItem and evalSwitch(sp, o.value) or o.value
	    end
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

-- apps register controls in init, before a target is chosen, so every
-- app's are kept
local function registerControlWrapper(under)
   return function(n, label, short, ...)
      local id = callerApp()
      if id then
	 controlsOf[id] = controlsOf[id] or {}
	 local cs = controlsOf[id]
	 cs[n] = cs[n] or {}
	 cs[n].label = label
	 if id == cfg.target and active() then
	    log("control " .. tostring(n) .. " registered: '" .. tostring(label) .. "'")
	 end
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
	 -- same(), not ~=: JETI's Lua floors a float compared with an
	 -- integer, so 0.4 ~= 0 is false there and the change was lost
	 if not same(value, c.value) then
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

-- system.getSwitchInfo: while a script sets a control, .value follows it,
-- so apps reading sticks this way can be driven too ("for": "target" limits
-- it to the target's calls). Measured: .value is the evaluated value, like
-- getInputsVal (P2 "P" 0.758 -> "PC" 0.879), not the raw position
local function switchInfoWrapper(under)
   return function(sw, ...)
      local info = under(sw, ...)
      if nInputs == 0 or type(info) ~= "table" or not info.label then return info end
      local o = inputs[tostring(info.label):upper()]
      if not o or (o.targetOnly and not callerIsTarget()) then return info end
      local c = {}
      for k, v in pairs(info) do c[k] = v end
      c.value = evalSwitch({name = tostring(info.label):upper(),
			    mode = info.mode or (info.proportional and "P" or "S"),
			    activeOn = info.activeOn}, o.value)
      return c
   end
end

-- system.createSwitch: remember each item's control, mode and activeOn
-- (getSwitchInfo may not report activeOn)
local function createSwitchWrapper(under)
   return function(name, mods, on, ...)
      local sw = under(name, mods, on, ...)
      if sw ~= nil and type(name) == "string" then
	 switchSpecs[sw] = name ~= "" and {name = name:upper(),
					   mode = mods and tostring(mods):upper() or "S",
					   activeOn = on or 0} or false
      end
      return sw
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
   {function() return system end, "createSwitch", createSwitchWrapper},
   {function() return system end, "getSwitchInfo", switchInfoWrapper},
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
      return {{key = idKey(s.id, s.param or 1), id = s.id, param = s.param or 1,
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
	    found[#found+1] = {key = idKey(e.id, e.param), label = tostring(e.label),
			       id = e.id, param = e.param, sensorName = e.sensorName}
	 end
      end
   end
   if #found == 0 then
      return nil, "no sensor labelled '" .. tostring(want) .. "'; have " ..
	 (#labels > 0 and table.concat(labels, ", ") or "none")
   end
   return found
end

-- waitSensor / expectSensor: read a sensor as the target would (through
-- getSensorByID, so setSensor overrides apply) and compare its value
local function sensorCheck(s, field, waiting)
   local found, err = findSensors(s, field)
   if not found then
      if waiting then return nil end      -- the sensor list may not be up yet
      return false, err
   end
   if #found > 1 then
      local names = {}
      for _, f in ipairs(found) do names[#names+1] = tostring(f.sensorName or "?") end
      return false, #found .. " sensors labelled '" .. tostring(s[field]) ..
	 "'; add \"sensorName\" (one of " .. table.concat(names, ", ") .. ")"
   end
   local f = found[1]
   local name = (f.sensorName and (tostring(f.sensorName) .. " ") or "") .. f.label
   local ok, r = pcall(system.getSensorByID, f.id, f.param)
   if not ok or type(r) ~= "table" then
      if waiting then return nil end
      return false, name .. ": no reading"
   end
   if not r.valid then
      if waiting then s._last = name .. " invalid"; return nil end
      return false, name .. " is invalid"
   end
   local v = tonumber(r.value)
   if v == nil then
      if waiting then return nil end
      return false, name .. ": value " .. tostring(r.value)
   end
   s._last = name .. " = " .. tostring(v)
   local pass, want = numWant(v, s, 0.01)
   if pass == nil then return false, want end
   if s.as then vars[s.as] = v end
   local msg = name .. " = " .. tostring(v) .. want
   if pass then return true, msg end
   if waiting then return nil end
   return false, msg
end

H.expectSensor = {ctx = "any", run = function(s) return sensorCheck(s, "expectSensor", false) end}
H.waitSensor = {ctx = "any", run = function(s) return sensorCheck(s, "waitSensor", true) end,
		onTimeout = function(s) return "; last " .. tostring(s._last or "no reading") end}

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
   if s.value == nil and s.min == nil and s.max == nil then
      return "ok", "control " .. name .. " = " .. tostring(c.value)
   end
   if type(c.value) ~= "number" then
      if waiting then return end
      return false, "control " .. name .. " = " .. tostring(c.value) .. " (not a number)"
   end
   local good, want = numWant(c.value, s, 0.01)
   if good == nil then return false, want end
   local msg = "control " .. name .. " = " .. tostring(c.value) .. want
   if good then return true, msg end
   if waiting then return end
   return false, msg
end

H.expectControl = {ctx = "any", run = function(s) return controlCheck(s, "expectControl", false) end}
H.waitControl = {ctx = "any", run = function(s) return controlCheck(s, "waitControl", true) end,
		 onTimeout = function(s)
		    local c = findControl(s.waitControl)
		    return "; last value " .. tostring(c and c.value)
		 end}

--------------------------------------------------------------------------------
-- SensorE control, through system.SensorE
--------------------------------------------------------------------------------

-- the sensor emulator that's running: SensorE (simulated flight) or
-- SensorL (log replay); both have getState, pause and setTime
local function SE()
   local se, sl = system.SensorE, system.SensorL
   se = type(se) == "table" and se or nil
   sl = type(sl) == "table" and sl or nil
   if se and sl then
      return nil, "both SensorE and SensorL are running; keep only one in the model's apps"
   end
   if se then return se, "SensorE" end
   if sl then return sl, "SensorL" end
   return nil, "no sensor emulator running (SensorE or SensorL)"
end

-- run a SensorE/SensorL API call; its true/false+message becomes the step's
local function seCall(fname, okMsg, ...)
   local se, name = SE()
   if not se then return false, name end
   if type(se[fname]) ~= "function" then
      return false, name .. " can't do that (no " .. fname .. "); it needs " ..
	 (name == "SensorL" and "SensorE" or "SensorL")
   end
   local ok, res, msg = pcall(se[fname], ...)
   if not ok then return false, name .. " " .. fname .. " error: " .. tostring(res) end
   if res == false then return false, name .. ": " .. tostring(msg) end
   return "ok", okMsg and (name .. " " .. okMsg)
end

local function seState()
   local se = SE()
   if not se then return nil end
   local ok, g = pcall(se.getState)
   return ok and g or nil
end

H.sensorPause = {ctx = "any", run = function(s)
		    local on = s.sensorPause ~= false
		    return seCall("pause", on and "paused" or "running", on)
end}

-- SensorL takes a moment to get there (it reads the log up to that
-- time), so the step waits until it has
H.sensorTime = {ctx = "any", run = function(s)
		   if not s._asked then
		      local st, msg = seCall("setTime", "t = " .. tostring(s.sensorTime), s.sensorTime)
		      if st == false then return st, msg end
		      s._asked = msg
		   end
		   local g = seState()
		   if g and g.seeking then return end
		   local msg = s._asked
		   s._asked = nil
		   if g and g.t then msg = msg .. string.format(" (now %.1f)", g.t) end
		   return "ok", msg
		end,
		onTimeout = function(s)
		   s._asked = nil
		   local g = seState()
		   return "; still going there, at t = " .. tostring(g and g.t)
		end}

-- ask for n simulator steps, then wait until SensorE has run them (it
-- steps when the target reads its GPS sensors)
H.sensorStep = {ctx = "any", run = function(s)
		   if not s._asked then
		      local st, msg = seCall("step", nil, s.sensorStep)
		      if st == false then return st, msg end
		      s._asked = true
		      return
		   end
		   local g = seState()
		   if g and g.stepsPending == 0 then
		      s._asked = nil
		      return "ok", tostring(s.sensorStep) .. " steps, now t=" ..
			 string.format("%.1f", g.t or 0) .. " x=" .. tostring(g.x) .. " y=" .. tostring(g.y)
		   end
		end,
		onTimeout = function(s)
		   s._asked = nil
		   local g = seState()
		   return "; " .. tostring(g and g.stepsPending) ..
		      " steps not run (SensorE steps when the target reads its GPS sensors)"
		end}

H.sensorField = {ctx = "any", run = function(s)
		    return seCall("setField", "GPS origin field " .. tostring(s.sensorField),
				  s.sensorField)
end}

H.sensorPosition = {ctx = "any", run = function(s)
		       local p = s.sensorPosition
		       if p == false then
			  return seCall("setPosition", "GPS position released", nil)
		       end
		       if type(p) == "table" and p.lat ~= nil then
			  -- {lat, lon[, north, east]}; "$name" is a remembered value
			  local t = {north = p.north, east = p.east}
			  for _, k in ipairs({"lat", "lon"}) do
			     local v = p[k]
			     if type(v) == "string" and v:sub(1, 1) == "$" then
				if vars[v:sub(2)] == nil then
				   return false, "nothing remembered as " .. v
				end
				v = vars[v:sub(2)]
			     end
			     if type(v) == "number" then
				log("WARN sensorPosition " .. k .. " is a number; json makes it " ..
				    "float32 (about 0.5 m error). Write it as a string")
			     end
			     t[k] = v
			  end
			  local st, msg = seCall("setPosition", nil, t)
			  if st == false then return st, msg end
			  local g = seState() or {}
			  return "ok", string.format("SensorE GPS held at %s, %s%s = x %s, y %s",
						     tostring(t.lat), tostring(t.lon),
						     (t.north or t.east) and string.format(
							" + %s m N, %s m E", tostring(t.north or 0),
							tostring(t.east or 0)) or "",
						     tostring(g.x), tostring(g.y))
		       end
		       if type(p) ~= "table" or p[1] == nil or p[2] == nil then
			  return false, "sensorPosition needs [x, y], {\"lat\": , \"lon\": } or false"
		       end
		       return seCall("setPosition", "GPS held at " .. tostring(p[1]) ..
				     ", " .. tostring(p[2]), p[1], p[2])
end}

H.sensorVars = {ctx = "any", run = function(s)
		   if type(s.sensorVars) ~= "table" then
		      return false, "sensorVars needs an object, e.g. {\"xp\": 0, \"heading\": 90}"
		   end
		   local parts = {}
		   for k, v in pairs(s.sensorVars) do parts[#parts+1] = k .. "=" .. tostring(v) end
		   table.sort(parts)
		   return seCall("setVars", table.concat(parts, " "), s.sensorVars)
end}

H.waitSensorTime = {ctx = "any", run = function(s)
		       local se, name = SE()
		       if not se then return false, name end
		       local g = seState()
		       if g and g.t and g.t >= s.waitSensorTime then
			  return "ok", string.format("%s t = %.1f", name, g.t)
		       end
		       if g and g.done then
			  return false, string.format("%s reached the end of the log at t = %.1f",
						      name, g.t or 0)
		       end
		    end,
		    onTimeout = function()
		       local g = seState()
		       local _, name = SE()
		       return "; " .. tostring(name) .. " t = " .. tostring(g and g.t) ..
			  (g and g.paused and " (paused)" or "")
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

-- the app a registerForm/registerTelemetry call came from; the label
-- stands in if the emulator gives no debug info
local function registeringApp(label)
   local id = callerApp(4)   -- 3 is the registerForm/registerTelemetry wrapper
   if id == nil then id = tostring(label) end
   return id
end

local function install()
   orig.registerForm = system.registerForm
   orig.registerTelemetry = system.registerTelemetry

   -- every app's form gets wrappers; they act only while it's the target
   system.registerForm = function(n, parent, label, i, k, p, c)
      local id = registeringApp(label)
      if not id or SKIP[id] then
	 return orig.registerForm(n, parent, label, i, k, p, c)
      end
      wrapForm()   -- in case form was nil when the chunk loaded
      local app = getApp(id)
      app.registered = true
      app.init, app.key, app.print, app.close = i, k, p, c
      app.label = label            -- the title until the target sets one
      app.title = nil
      if app == T and active() then log("hooked form '" .. tostring(label) .. "'") end
      local function on() return app == T and active() end
      return orig.registerForm(n, parent, label,
	 function(sub)
	    if on() then return wInit(sub) end
	    if app.init then return app.init(sub) end
	 end,
	 function(key)
	    if on() then return wKey(key) end
	    if app.key then return app.key(key) end
	 end,
	 function(w, h)
	    if on() then return wPrint(w, h) end
	    if app.print then return app.print(w, h) end
	 end,
	 function()
	    if on() then return wClose() end
	    if app.close then return app.close() end
	 end)
   end

   system.registerTelemetry = function(n, label, size, p, k)
      local id = registeringApp(label)
      if not id or SKIP[id] then
	 return orig.registerTelemetry(n, label, size, p, k)
      end
      local app = getApp(id)
      app.registered = true
      app.tel[n] = {print = p, key = k, label = label}
      if app == T and active() then
	 log("hooked telemetry window " .. n .. " '" .. tostring(label) .. "'")
      end
      local function on() return app == T and active() end
      local wp = function(w, h)
	 if not on() then
	    if p then return p(w, h) end
	    return
	 end
	 if p then capturePrint("telem" .. n, p, w, h) end
	 cpuSample("telemetry " .. n .. " print", getCPU())
	 runSteps("telem", n)
	 drawBanner(w, h)
      end
      local wk = k and function(key)
	 if on() and recording and not injecting and key ~= KEY_RELEASED then
	    -- record the button's label as it was when pressed (the
	    -- callback may relabel it); a plain key if it has none
	    local blabel
	    for i = 1, 5 do
	       if _ENV["KEY_" .. i] == key then
		  local b = (telButtons[n] or {})[i]
		  blabel = b and b.text
	       end
	    end
	    return recAround(k, function()
				if blabel then return {telemButton = blabel, win = n} end
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
      -- kept for every app: apps set them in init, before a target is chosen
      system.setTelemetryButton = function(win, n, text, state, ...)
	 local id = callerApp()
	 if id then
	    local tb = telButtonsOf[id] or {}
	    telButtonsOf[id] = tb
	    tb[win] = tb[win] or {}
	    tb[win][n] = {text = text, state = state or 0}  -- API default: DISABLED
	 end
	 return orig.setTelemetryButton(win, n, text, state, ...)
      end
   end

   wrapForm()
   wrapAnnouncements()
   wrapImages()
   wrapHooks()
end

-- settings from a config.jsn or a script's "config"; mode, target and
-- script come only from the menu
local function applySettings(c, where)
   if type(c) ~= "table" then return end
   for k, v in pairs(c) do
      if k == "mode" or k == "target" or k == "script" then
	 log("WARN " .. where .. ": \"" .. k .. "\" is chosen in UIDriver's menu now; ignored")
      else
	 if type(v) == "number" then v = whole(v) or v end  -- json gives floats
	 local msKey = ({stepGap = "stepGapMs", stepTimeout = "stepTimeoutMs",
			 confirmLook = "confirmLookMs"})[k]
	 if msKey then
	    local ms, why = durationMs(v)
	    if ms then cfg[msKey] = ms
	    else log("WARN " .. where .. ": \"" .. k .. "\": " .. why .. "; ignored") end
	 else
	    cfg[k] = v
	 end
      end
   end
end

local function loadAppConfig()
   local path = appDir(cfg.target) .. "config.jsn"
   local txt = io.readall(path)
   if not txt then return end
   local c = json.decode(txt)
   if type(c) ~= "table" then log("WARN can't decode " .. path .. "; using defaults"); return end
   applySettings(c, path)
   log("settings from " .. path)
end

-- the scripts in an app's UIDriver folder, sorted
local function scriptsOf(id)
   local list = {}
   if not id or id == "" or not dir then return list end
   pcall(function()
      for name, kind in dir(appDir(id):sub(1, -2)) do
	 if kind == "file" and name:match("%.jsn$") and name ~= "config.jsn" then
	    list[#list+1] = name
	 end
      end
   end)
   table.sort(list)
   return list
end

local function loadScript()
   if cfg.script == "" then
      -- e.g. play was chosen before the app had any scripts
      local list = scriptsOf(cfg.target)
      if #list == 1 then
	 cfg.script = list[1]
	 log("no script chosen; using the only one, " .. cfg.script)
      else
	 log("WARN no script chosen; pick one in UIDriver's menu" ..
	     (#list > 0 and (" (have " .. table.concat(list, ", ") .. ")") or
	      (" (none in " .. appDir(cfg.target) .. ")")))
	 return
      end
   end
   local path = appDir(cfg.target) .. cfg.script
   local txt = io.readall(path)
   if not txt then log("can't read script " .. path); return end
   local sc = json.decode(txt)
   if type(sc) ~= "table" or type(sc.steps) ~= "table" then
      log("script " .. cfg.script .. " has no \"steps\" list"); return
   end
   if sc.config then applySettings(sc.config, cfg.script) end
   local errs = {}
   local out = flatten(sc.steps, {}, errs)
   if #errs > 0 then
      for _, e in ipairs(errs) do log(e) end
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

-- the menu's choice: {app, script, mode}, saved for the next start
local function loadSelection()
   local txt = io.readall(SELFILE)
   local c = txt and json.decode(txt)
   if type(c) ~= "table" then return end
   cfg.target = type(c.app) == "string" and c.app or ""
   cfg.script = type(c.script) == "string" and c.script or ""
   cfg.mode = (c.mode == "play" or c.mode == "record") and c.mode or "off"
end

local function saveSelection()
   local f = io.open(SELFILE, "w")
   if f then
      io.write(f, json.encode({app = cfg.target, script = cfg.script, mode = cfg.mode}))
      io.close(f)
   end
end

-- forget everything from the last run
local function resetRun()
   comps, buttons = {}, {}
   curSub, capSub = nil, nil
   originals = {}
   capturing, injecting, prevented = false, false, false
   lastLabel, titleShown = nil, nil
   answers = {}
   recording, rec, recFile = false, {}, nil
   cbDepth, recAfter = 0, {}
   steps, si, stepT0, nextAt = nil, nil, nil, nil
   finished, running = false, false
   counts = {pass = 0, fail = 0, ok = 0, checks = 0, checkFails = 0}
   seq, actionSeq, actionMarked = 0, 0, nil
   anns, textArm, frameNo, frames = {}, nil, 0, {}
   vars, events, checkSeen = {}, {}, {}
   cpuWin = nil
   inputs, nInputs = {}, 0
   sensorOv, nSensorOv = {}, 0
   confirmBanner, confirmAnswer = nil, nil
end

local function stamp()
   local ok, d = pcall(system.getDateTime)
   if ok and type(d) == "table" and d.year then
      return string.format("%04d%02d%02d-%02d%02d%02d", d.year, d.mon, d.day,
			   d.hour, d.min, d.sec)
   end
   return tostring(now())
end

-- start a run with what cfg.target/script/mode say (or stop, for "off")
local function activate()
   for k, v in pairs(DEFAULTS) do cfg[k] = v end
   cfg.sensorConfig, cfg.sensorLog = nil, nil
   resetRun()
   local id = cfg.target
   T = id ~= "" and getApp(id) or {tel = {}}
   -- the target's form may be open already; waitForm waits for it to reopen
   formOpen = false
   controlsOf[id] = controlsOf[id] or {}
   controls = controlsOf[id]
   telButtonsOf[id] = telButtonsOf[id] or {}
   telButtons = telButtonsOf[id]
   api.sensorConfig, api.sensorLog = nil, nil
   LOGFILE = id ~= "" and (appDir(id) .. "result.log") or (HOME .. "result.log")
   local f = io.open(LOGFILE, "w")
   if f then io.close(f)
   elseif id ~= "" then
      -- no UIDriver folder yet: make it (the console still gets the log)
      if io.mkdir then pcall(io.mkdir, appDir(id):sub(1, -2)) end
      f = io.open(LOGFILE, "w")
      if f then io.close(f) end
   end
   if not active() then
      log(appName .. " off" .. (id ~= "" and (" (app " .. id .. ")") or ""))
      return
   end
   log(appName .. " mode=" .. cfg.mode .. " target=" .. id ..
       (cfg.mode == "play" and (" script=" .. cfg.script) or ""))
   loadAppConfig()
   if cfg.mode == "play" then loadScript() end
   -- SensorE reads this when it loads its config (first getSensors),
   -- SensorL its log
   api.sensorConfig = cfg.sensorConfig
   api.sensorLog = cfg.sensorLog
   local se = system.SensorE
   local ok, g = pcall(function() return se and se.getState and se.getState() end)
   if cfg.sensorConfig and ok and type(g) == "table" and g.configDir
   and g.configDir ~= cfg.sensorConfig then
      log("WARN SensorE already loaded its config from " .. tostring(g.configDir) ..
	  ", not " .. cfg.sensorConfig .. "; restart the apps to change it")
   end
   local sl = system.SensorL
   local okL, gl = pcall(function() return sl and sl.getState and sl.getState() end)
   if cfg.sensorLog and okL and type(gl) == "table" and gl.logFile
   and gl.logFile ~= cfg.sensorLog then
      log("WARN SensorL already opened " .. tostring(gl.logFile) ..
	  ", not " .. cfg.sensorLog .. "; restart the apps to change it")
   end
   if cfg.mode == "record" then
      recording = true
      recFile = appDir(id) .. "rec-" .. stamp() .. ".jsn"
      log("recording to " .. recFile)
      recStep({waitForm = true})
   end
end

local function start()
   local f = io.open(HOME .. "result.log", "w")
   if f then io.close(f) end
   system.UIDriver = api          -- always, so checks work by hand too
   exposed.sensorE = function()
      local se = system.SensorE
      return type(se) == "table" and se.getState and se.getState() or nil
   end
   exposed.sensorL = function()
      local sl = system.SensorL
      return type(sl) == "table" and sl.getState and sl.getState() or nil
   end
   pcall(loadSelection)
   -- wrapped in every mode: the target can be chosen at any time
   install()
   activate()
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

--------------------------------------------------------------------------------
-- the menu: choose the app, script and mode; applied on leaving it
--------------------------------------------------------------------------------

local MODES = {"off", "play", "record"}
local menu                 -- the choice being edited

local function appIds()
   local list = {}
   for id, a in pairs(apps) do
      if a.registered and not SKIP[id] then list[#list+1] = id end
   end
   table.sort(list)
   return list
end

local function indexOf(list, v)
   for i, x in ipairs(list) do if x == v then return i end end
end

local function runText()
   if cfg.mode == "play" then
      if not steps then return "play: no script loaded"
      elseif finished then return string.format("finished: %dP %dF", counts.pass, counts.fail) end
      return string.format("playing step %d/%d", si, #steps)
   elseif cfg.mode == "record" then
      return "recording: " .. #rec .. " steps"
   end
   return "off"
end

local function menuInit()
   if not menu then
      menu = {app = cfg.target, script = cfg.script, mode = cfg.mode}
   end
   menu.apps = appIds()
   if not indexOf(menu.apps, menu.app) then menu.app = menu.apps[1] or "" end
   menu.scripts = scriptsOf(menu.app)
   if not indexOf(menu.scripts, menu.script) then menu.script = menu.scripts[1] or "" end

   form.setTitle("UIDriver")
   form.addRow(2)
   form.addLabel({label = "App", width = 80})
   if #menu.apps > 0 then
      form.addSelectbox(menu.apps, indexOf(menu.apps, menu.app), true, function(v)
	 menu.app = menu.apps[v]
	 menu.script = nil
	 form.reinit(1)
      end, {width = 230})
   else
      form.addLabel({label = "(no apps registered)", width = 230})
   end
   form.addRow(2)
   form.addLabel({label = "Script", width = 80})
   if #menu.scripts > 0 then
      form.addSelectbox(menu.scripts, indexOf(menu.scripts, menu.script), true, function(v)
	 menu.script = menu.scripts[v]
      end, {width = 230})
   else
      form.addLabel({label = "(none in " .. (menu.app ~= "" and menu.app or "?") .. "/UIDriver)",
		     width = 230, font = FONT_MINI})
   end
   form.addRow(2)
   form.addLabel({label = "Mode", width = 80})
   form.addSelectbox(MODES, indexOf(MODES, menu.mode) or 1, true, function(v)
      menu.mode = MODES[v]
   end, {width = 230})
   form.addRow(1)
   form.addLabel({label = "Now: " .. (cfg.target ~= "" and cfg.target or "-") .. "  " ..
		     runText(), font = FONT_MINI})
   form.addRow(1)
   form.addLabel({label = "Applied when you leave this menu", font = FONT_MINI})
end

-- a changed choice, or a finished (or unloaded) run, starts afresh
local function menuClose()
   local m = menu
   menu = nil
   if not m then return end
   local changed = m.app ~= cfg.target or m.mode ~= cfg.mode
      or (m.mode == "play" and m.script ~= cfg.script)
   local stale = (cfg.mode == "play" and (finished or not steps))
   if not (changed or stale) then return end
   cfg.target, cfg.script, cfg.mode = m.app or "", m.script or "", m.mode
   saveSelection()
   activate()
end

local function init()
   system.registerForm(1, MENU_APPS, appName, menuInit, nil, nil, menuClose)
   system.registerTelemetry(1, appName, 1, statusPrint)
end

local function loop()
   wrapAnnouncements(); wrapHooks()
   runSteps("loop")
end

return {init = init, loop = loop, author = "DFM", version = "0.2", name = appName}
