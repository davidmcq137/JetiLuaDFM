--[[
   TestMitter: a fake JETI DC/DS firmware, so Lua apps (and UIDriver scripts)
   run off-target, faster than real time, e.g. in GitHub Actions.

   Run with the JETI-like desktop Lua (LUA_32BITS, LUA_FLOORN2I, type()
   fixed) from the parent of Apps, as the emulator does:
     cd ~/.config/JETI-Studio/Emulator
     ~/lua-5.3.1-Jeti-typefix/src/lua Apps/TestMX/testmx.lua [options] App ...
   Options:
     -p <profile>   device profile (default emu-ds24ii-606); -p list lists them
     -t <seconds>   run time after init (default 0: init only, then one frame)
     --paced        run in real time (sleep so wall time keeps up)
     --seed <n>     seed for loop jitter and math.random (default 1)
     --mult <pct>   CPU budget multiplier, 100..300 (default 100)
   Apps load from Apps/<App>.lua (or .lc). The exit code is 0 when no app
   raised an error and no driver called FW.fail, else 1.

   As a module: local FW = dofile("Apps/TestMX/testmx.lua"), then
   FW.setup{profile=..., seed=...}; FW.load{"A", "B"}; FW.initApps();
   FW.run(ms); FW.finish() (prints the report and returns the exit code).
   Hooks for drivers: FW.onFrame(f), FW.onDrawText, FW.onQuestion,
   FW.onPrint; FW.openForm(label), FW.key(code), FW.controls, FW.sensors.

   Needs TestMX/testmx_c.so (TestMX/build.sh) for gps (doubles, as on the
   TX) and the wall clock.

   What is modelled (see the TestMitter API inventory doc for the evidence):
   - Device profiles: version, device name, emulator flag, screen and
     window sizes, gps.getString (6.06) vs gps.getStrig (5.08),
     declareGlobal (6.05+ DS-24 II), off-screen rendering (DS-24 II fw 6),
     red/blue swap in images (DS-24 II TX), libraries hidden on a TX
     (debug, os, coroutine).
   - Each app has its own globals (as on 6.05+, see dumpGlobalVars);
     declareGlobal names are shared. Profiles without declareGlobal share
     one global table between apps.
   - A virtual clock: the scheduler owns now_ms; getTimeCounter, getTime
     and getDateTime read it. Inside a callback an instruction-count hook
     and per-call costs move it forward, so time passes while Lua runs.
   - A CPU cost model in report mode: each callback's charged ms against
     10 ms x multiplier; getCPU reports it; overruns are listed, nothing is
     killed. The instruction rate and image costs are NOT calibrated
     against a TX yet (Harry's prof.log and ImgTest runs are the plan).
--]]

local FW = {}
local base = {}              -- what every app environment starts from

-- host libraries, kept before any app can see or change anything
local rio, ros, rdebug, rstring, rmath, rtable = io, os, debug, string, math, table
local sethook, traceback = rdebug.sethook, rdebug.traceback
local hostPrint, hostLoadfile, hostLoad = print, loadfile, load
local fmt, floor = rstring.format, rmath.floor
local pack, unpack = rtable.pack, rtable.unpack

local HERE = (debug.getinfo(1, "S").source:match("^@(.*/)") or "./")

local C
do
   local open, err = package.loadlib(HERE .. "testmx_c.so", "luaopen_testmx_c")
   if not open then
      error("TestMitter: can't load " .. HERE .. "testmx_c.so (run TestMX/build.sh): " .. tostring(err))
   end
   C = open()
end
FW.C = C

--------------------------------------------------------------------------------
-- device profiles
--------------------------------------------------------------------------------

-- sizes: form = form print canvas; tele[size] = telemetry canvas per
-- registerTelemetry size (1 small, 2 big, 3/4 full screen). Values marked
-- (?) are not measured yet.
FW.profiles = {
   -- JETI Studio emulator 6.06 as a DS-24 II (EnvDump, GpsTest)
   ["emu-ds24ii-606"] = {
      device = "JETI DS-24 II", version = "6.06", emulator = 1,
      lcdW = 480, lcdH = 480,
      form = {320, 240},                                     -- (?)
      tele = {{157, 60}, {157, 127}, {320, 260}, {320, 260}}, -- small (?)
      gpsName = "getString", declareGlobal = true, offscreen = true,
      imageSwapRB = false, hide = {},
      collate = "en_US.UTF-8",    -- string < is case-insensitive there
      fonts = "emu-ds24ii-606",
      -- the emulator's getTimeCounter() often starts negative (the TX's
      -- starts small and positive): only differences are safe, never a
      -- compare against 0 or "or 0"
      counterStart = -1000000000,
      packagePath = "./Apps/?.lc;./Apps/?/init.lc;./Apps/?.lc2;./Apps/?/init.lc2;" ..
	 "./Apps/?.lua;./Apps/?/init.lua;./Apps/lib/?.lua;./Apps/lib/?/init.lua;",
   },
   -- real DS-24 II on 6.06: EnvDump and FontDump on Harry's TX, 2026-11-22
   -- (TestMX/test/envdump-ds24ii-606.txt, fontdump-ds24ii-606.txt): no
   -- debug/os/coroutine, its own fonts (FONT_NORMAL 8 .. FONT_MAXI 12, 17 px
   -- high where the emulator's is 16); images swap red/blue
   ["ds24ii-606"] = {
      device = "JETI DS-24 II", version = "6.06", emulator = 0,
      lcdW = 480, lcdH = 480,
      form = {316, 240},                                     -- (?)
      tele = {{150, 32}, {150, 68}, {316, 159}, {316, 159}}, -- small (?)
      gpsName = "getString", declareGlobal = true, offscreen = true,
      imageSwapRB = true, hide = {debug = true, os = true, coroutine = true},
      collate = "C",                                         -- (?) as DS-24 5.08
      const = {FONT_NORMAL = 8, FONT_BOLD = 9, FONT_MINI = 10, FONT_BIG = 11,
	       FONT_MAXI = 12},
      fonts = "ds24ii-606",
      packagePath = "/Apps/?.lc;/Apps/?/init.lc;/Apps/?.lc2;/Apps/?/init.lc2;" ..
	 "/Apps/?.lua;/Apps/?/init.lua;/Apps/lib/?.lua;/Apps/lib/?/init.lua;",
   },
   -- real DS-24 on 5.08: EnvDump on the pilot's DS-24, 2026-11-21
   -- (TestMX/test/envdump-ds24-508.txt). Fonts and KEY_UP/KEY_DOWN differ
   -- from 6.06, and the 6.x additions are missing
   ["ds24-508"] = {
      device = "JETI DS-24", version = "5.08", emulator = 0,
      lcdW = 320, lcdH = 240,
      form = {316, 240},                                     -- (?)
      tele = {{150, 32}, {150, 68}, {316, 159}, {316, 159}}, -- small (?)
      gpsName = "getStrig", declareGlobal = false, offscreen = false,
      imageSwapRB = false, hide = {debug = true, os = true, coroutine = true},
      collate = "C",
      packagePath = "/Apps/?.lc;/Apps/?/init.lc;/Apps/?.lc2;/Apps/?/init.lc2;" ..
	 "/Apps/?.lua;/Apps/?/init.lua;/Apps/lib/?.lua;/Apps/lib/?/init.lua;",
      const = {FONT_NORMAL = 0, FONT_BOLD = 1, FONT_BIG = 2, FONT_MINI = 3,
	       FONT_MAXI = 4, FONT_REVERSED = 8, FONT_GRAYED = 16, FONT_XOR = 32,
	       FONT_OR = 64, FONT_AND = 128, KEY_UP = 256, KEY_DOWN = 512},
      fontMask = 7, fonts = "ds24-508",
      remove = {"COLOR_", "timer", "system.setTelemetryButton", "lcd.drawArc",
		"lcd.getColor"},
   },
   -- a mono DS-16 on 5.06 (pilot's TX, EnvDump 1.7 and FontDump 1.3,
   -- 2026-11-21): as the DS-24 on 5.08 without gpio, serial, lcd.renderer
   -- and system.unregisterLogVariable, its own font, and ROM libraries
   -- (rom: the globals pairs(_G) lists; see makeEnv)
   ["ds16-506"] = {
      device = "JETI DS-16", version = "5.06", emulator = 0,
      lcdW = 320, lcdH = 240,
      form = {316, 240},                                     -- (?)
      tele = {{150, 32}, {150, 68}, {316, 159}, {316, 159}}, -- (?) as DS-24
      gpsName = "getStrig", declareGlobal = false, offscreen = false,
      imageSwapRB = false, hide = {debug = true, os = true, coroutine = true},
      collate = "C",                                         -- (?) as DS-24
      packagePath = "/Apps/?.lc;/Apps/?/init.lc;/Apps/?.lc2;/Apps/?/init.lc2;" ..
	 "/Apps/?.lua;/Apps/?/init.lua;/Apps/lib/?.lua;/Apps/lib/?/init.lua;",
      const = {FONT_NORMAL = 0, FONT_BOLD = 1, FONT_BIG = 2, FONT_MINI = 3,
	       FONT_MAXI = 4, FONT_REVERSED = 8, FONT_GRAYED = 16, FONT_XOR = 32,
	       FONT_OR = 64, FONT_AND = 128, KEY_UP = 256, KEY_DOWN = 512},
      fontMask = 7, fonts = "ds16-506",
      remove = {"COLOR_", "timer", "system.setTelemetryButton", "lcd.drawArc",
		"lcd.getColor", "gpio", "serial", "lcd.renderer",
		"system.unregisterLogVariable"},
      rom = {"_G", "_VERSION", "assert", "collectgarbage", "dir", "dofile",
	     "error", "getmetatable", "io", "ipairs", "load", "loadfile", "next",
	     "package", "pairs", "pcall", "print", "rawequal", "rawget", "rawlen",
	     "rawset", "require", "select", "setmetatable", "string", "table",
	     "tonumber", "tostring", "type", "utf8", "xpcall"},
   },
}

-- timing and cost defaults, per profile unless overridden in setup
local TIMING = {
   loopMs = 20, loopJitterMs = 10,   -- loop every 20-30 ms (community notes)
   printMs = 40,                     -- form/telemetry redraw period (?)
   budgetMs = 10,                    -- per callback at 100%
   hookN = 1000,                     -- instructions per hook call
   nsPerInstr = 50,                  -- (?) not calibrated: 20 M instr/s
}

-- per-call costs in ms (report mode). loadImage: fit to the emulator's
-- ImgTest run (0-37 ms); recalibrate against the TX run.
FW.costs = {
   loadImage = function(w, h, bytes) return 2.08e-5 * w * h + 1.39e-4 * bytes end,
}

--------------------------------------------------------------------------------
-- constants (emulator 6.06, EnvDump 2026-11-21)
--------------------------------------------------------------------------------

local CONST = {
   KEY_1 = 1, KEY_2 = 2, KEY_3 = 4, KEY_4 = 8, KEY_5 = 16, KEY_ESC = 32,
   KEY_ENTER = 64, KEY_MENU = 128, KEY_DOWN = 256, KEY_UP = 512,
   KEY_RELEASED = -2147483648,
   MENU_NONE = 0, MENU_MAIN = 1, MENU_FINE = 2, MENU_ADVANCED = 3,
   MENU_TELEMETRY = 4, MENU_APPS = 5, MENU_SYSTEM = 6, MENU_GAMES = 7,
   FONT_NORMAL = 21, FONT_BOLD = 22, FONT_MINI = 23, FONT_BIG = 24, FONT_MAXI = 25,
   FONT_REVERSED = 2048, FONT_GRAYED = 4096, FONT_XOR = 8192, FONT_OR = 16384,
   FONT_AND = 32768,
   AUDIO_BACKGROUND = 1, AUDIO_IMMEDIATE = 2, AUDIO_QUEUE = 3,
   COLOR_BG = 0, COLOR_BG_TEXT = 1, COLOR_ACTIVE = 2, COLOR_ACTIVE_TEXT = 3,
   COLOR_INACTIVE = 4, COLOR_INACTIVE_TEXT = 5, COLOR_DISABLED = 6,
   COLOR_DISABLED_TEXT = 7, COLOR_ALERT = 8, COLOR_ALERT_TEXT = 9,
   COLOR_HIGHLIGHTED = 10, COLOR_HIGHLIGHTED_TEXT = 11, COLOR_BUTTON = 12,
   COLOR_BUTTON_TEXT = 13, COLOR_HEADER = 14, COLOR_BATTERY = 15,
   DISABLED = 0, ENABLED = 1, HIGHLIGHTED = 2, SYSTEM = 1, MODEL = 2,
   SOUND_START = 0, SOUND_BOUND = 1, SOUND_LOWTXVOLT = 2, SOUND_LOWSIGNAL = 3,
   SOUND_RANGETEST = 5, SOUND_AUTOTRIM = 6, SOUND_INACT = 7, SOUND_BKUP = 9,
   SOUND_RXRESET = 10, SOUND_TELEMLOSS = 11,
}
-- text metrics: TestMX/fonts.lua, generated from FontDump runs by
-- TestMX/test/fontfit.py; a profile names its table (P.fonts). A font code
-- is the base font in the low bits (code & fontMask) plus style flags,
-- which don't change the width
local FONTS = dofile(HERE .. "fonts.lua")
local FONTNAMES = {"FONT_NORMAL", "FONT_BOLD", "FONT_MINI", "FONT_BIG", "FONT_MAXI"}

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local P                      -- the active profile (with timing merged in)
local apps, appByName = {}, {}
local stack = {}             -- callback records, innermost last
local now, frac = 0, 0.0     -- virtual ms (integer) and the fraction carried
local counter0 = 0           -- getTimeCounter() at now = 0 (profile counterStart)
local frameEnd = 0           -- virtual time the current frame's work may run to
local wall0                  -- wall ms at start (paced mode)
local failures, errors = {}, {}
local cpu = {}               -- per "app what": calls, max, over, total
local overLog = 0
local rng = 1                -- loop jitter generator (own, not math.random)
local frameHooks = {}
local superNames, superVals = {}, {}
local sharedEnv              -- profiles without declareGlobal
local startSec2000           -- getTime at now = 0

FW.controls = {}             -- name -> -1..1 (P1.., SA..), read by getInputs
FW.sensors = {}              -- list of getSensors entries (with values)
FW.txTelemetry = {txVoltage = 8.2, txBattPercent = 90, txCurrent = 200,
   txCapacity = 0, rx1Percent = 100, rx1Voltage = 5.0, rx2Percent = 0,
   rx2Voltage = 0, rxBVoltage = 0, rxBPercent = 0, photoValue = 2000,
   RSSI = {30, 30, 0, 0, 0, 0}}
FW.question = {answer = 1, frames = 3}   -- default: "yes" after 3 frames
FW.paced = false

local function out(s) (FW.onPrint or hostPrint)(s) end
local function fwlog(s) out("[FW] " .. s) end

function FW.fail(msg)
   failures[#failures + 1] = msg
   fwlog("FAIL: " .. tostring(msg))
end

function FW.now() return now end
-- a declareGlobal value, as the apps see it
function FW.superglobal(k) return superVals[k] end

--------------------------------------------------------------------------------
-- clock and cost model
--------------------------------------------------------------------------------

local function charge(ms)
   local rec = stack[#stack]
   if rec then rec.cost = rec.cost + ms end
   frac = frac + ms
   if frac >= 1 then
      local whole = floor(frac)
      now = now + whole
      frac = frac - whole
   end
end
FW.charge = charge

local hookMs
local function hook() charge(hookMs) end

local function currentApp()
   local rec = stack[#stack]
   return rec and rec.app
end

-- call an app callback with cost accounting; an error kills the app
local function call(app, what, f, ...)
   if not f or app.dead then return end
   local rec = {app = app, what = what, cost = 0.0}
   stack[#stack + 1] = rec
   sethook(hook, "", P.hookN)
   local r = pack(xpcall(f, traceback, ...))
   stack[#stack] = nil
   if #stack == 0 then sethook() end
   local key = app.name .. " " .. what:gsub(" .*", "")
   local c = cpu[key]
   if not c then c = {calls = 0, max = 0, over = 0, total = 0}; cpu[key] = c end
   c.calls, c.total = c.calls + 1, c.total + rec.cost
   if rec.cost > c.max then c.max = rec.cost end
   local budget = P.budgetMs * P.mult / 100
   if rec.cost > budget then
      c.over = c.over + 1
      overLog = overLog + 1
      if overLog <= 30 then
	 fwlog(fmt("CPU T=%d %s %s: %.1f ms > %.1f ms budget (report only)",
		   now, app.name, what, rec.cost, budget))
      end
   end
   if not r[1] then
      app.dead = true
      errors[#errors + 1] = app.name .. " " .. what .. ": " .. tostring(r[2])
      fwlog("ERROR in " .. app.name .. " " .. what .. " (app stopped): " .. tostring(r[2]))
      return
   end
   return unpack(r, 2, r.n)
end
FW.call = call

-- seconds since 2000-01-01 (local) <-> civil date; integer arithmetic only
local function days2000(y, m, d)
   y = m <= 2 and y - 1 or y
   local era = (y >= 0 and y or y - 399) // 400
   local yoe = y - era * 400
   local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
   local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
   return era * 146097 + doe - 730425        -- 730425 = days 0000-03-01..2000-01-01
end
local function civil(days)
   local z = days + 730425
   local era = (z >= 0 and z or z - 146096) // 146097
   local doe = z - era * 146097
   local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
   local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
   local mp = (5 * doy + 2) // 153
   local d = doy - (153 * mp + 2) // 5 + 1
   local m = mp < 10 and mp + 3 or mp - 9
   local y = yoe + era * 400 + (m <= 2 and 1 or 0)
   return y, m, d
end

local function getTime() return startSec2000 + now // 1000 end
local function getDateTime()
   local s = getTime()
   local y, m, d = civil(s // 86400)
   local r = s % 86400
   return {year = y, mon = m, day = d, hour = r // 3600, min = r % 3600 // 60,
	   sec = r % 60, dst = false}
end

--------------------------------------------------------------------------------
-- json (JETI's decode returns floats for all numbers)
--------------------------------------------------------------------------------

local json = {}
local ESC = {['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
	     ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'}
local function jstr(s)
   return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or fmt("\\u%04x", c:byte()) end) .. '"'
end
function json.encode(v)
   local t = type(v)
   if t == "table" then
      local n = #v
      if n > 0 or next(v) == nil then
	 local o = {}
	 for i = 1, n do o[i] = json.encode(v[i]) end
	 return "[" .. table.concat(o, ",") .. "]"
      end
      local o, keys = {}, {}
      for k in pairs(v) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      for _, k in ipairs(keys) do
	 local x = v[k]
	 if x == nil then x = v[tonumber(k)] end
	 o[#o + 1] = jstr(k) .. ":" .. json.encode(x)
      end
      return "{" .. table.concat(o, ",") .. "}"
   elseif t == "string" then return jstr(v)
   elseif t == "number" then
      if math.type(v) == "integer" then return tostring(v) end
      if v ~= v or v == math.huge or v == -math.huge then return "null" end
      if v == floor(v) then return fmt("%d", v) end
      return fmt("%.7g", v)
   elseif t == "boolean" then return tostring(v)
   else return "null" end
end
function json.decode(s)
   if type(s) ~= "string" then return nil end
   local i = 1
   local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
   local function err() error("json.decode: bad json at " .. i, 0) end
   local val
   local function str()
      local o, j = {}, i + 1
      while true do
	 local c = s:sub(j, j)
	 if c == "" then err() end
	 if c == '"' then i = j + 1; return table.concat(o) end
	 if c == "\\" then
	    local e = s:sub(j + 1, j + 1)
	    if e == "u" then
	       local cp = tonumber(s:sub(j + 2, j + 5), 16) or err()
	       o[#o + 1] = utf8.char(cp); j = j + 6
	    else
	       o[#o + 1] = ({b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"})[e] or e
	       j = j + 2
	    end
	 else
	    o[#o + 1] = c; j = j + 1
	 end
      end
   end
   function val()
      ws()
      local c = s:sub(i, i)
      if c == "{" then
	 local o = {}; i = i + 1; ws()
	 if s:sub(i, i) == "}" then i = i + 1; return o end
	 while true do
	    ws(); if s:sub(i, i) ~= '"' then err() end
	    local k = str(); ws()
	    if s:sub(i, i) ~= ":" then err() end
	    i = i + 1
	    o[k] = val(); ws()
	    local d = s:sub(i, i); i = i + 1
	    if d == "}" then return o end
	    if d ~= "," then err() end
	 end
      elseif c == "[" then
	 local o = {}; i = i + 1; ws()
	 if s:sub(i, i) == "]" then i = i + 1; return o end
	 while true do
	    o[#o + 1] = val(); ws()
	    local d = s:sub(i, i); i = i + 1
	    if d == "]" then return o end
	    if d ~= "," then err() end
	 end
      elseif c == '"' then return str()
      elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
      elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
      elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
      else
	 local j = s:find("[^%-%d%.eE+]", i) or #s + 1
	 local n = tonumber(s:sub(i, j - 1)) or err()
	 i = j
	 return n + 0.0
      end
   end
   return val()
end

--------------------------------------------------------------------------------
-- io and dir (JETI's simplified io; paths relative to the Emulator folder)
--------------------------------------------------------------------------------

-- the Emulator folder stands in for the SD card: an absolute path (what
-- apps use on a TX, e.g. "/Apps/X/...") is taken from there
local function sd(p)
   p = tostring(p)
   if p:sub(1, 1) == "/" then return "." .. p end
   return p
end
FW.sdPath = sd

-- With a fixture (FW.setup{fixture = ...}, or {sandbox = true} for the
-- layers without one) app file access goes through
-- three layers, so a test never sees or changes the pilot's working data:
--   1. the run folder (a temp folder): everything the run writes, read first
--   2. the fixture(s), TestMX/fixtures/<name>/, laid out like the SD card
--   3. the Emulator folder, but under Apps/ only files git doesn't ignore
--      (code, Lang, audio, App.json; not M-*.jsn, maps, logs ...), so a
--      test sees the same files here as in CI
-- Without a fixture, files are read and written in place, as before.
local FS = {}            -- run, fixtures, visible, visDirs, deleted, trace, keep

-- "./Apps/X/../Y//z" -> "Apps/Y/z"
local function norm(p)
   p = sd(p):gsub("\\", "/")
   local parts = {}
   for seg in p:gmatch("[^/]+") do
      if seg == ".." then parts[#parts] = nil
      elseif seg ~= "." then parts[#parts + 1] = seg end
   end
   return table.concat(parts, "/")
end

-- a file, not a folder: "path/." opens only for a folder
local function isFile(path)
   local f = rio.open(path, "rb")
   if not f then return false end
   f:close()
   local d = rio.open(path .. "/.", "rb")
   if d then d:close(); return false end
   return true
end

local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- not gitignored (or outside Apps/, e.g. Log/ for SensorL)
local function visible(rel)
   if not FS.visible then return true end
   if rel:sub(1, 5) ~= "Apps/" then return true end
   return FS.visible[rel:sub(6)] or false
end
local function visibleDir(rel)
   if not FS.visible then return true end
   if rel == "Apps" or rel:sub(1, 5) ~= "Apps/" then return true end
   return FS.visDirs[rel:sub(6)] or false
end

local function trace(what, rel, where)
   if FS.trace then out("[FW] file " .. what .. " " .. rel .. " (" .. where .. ")") end
end

-- the file to read for an app path, or nil
local function readPath(p)
   if not FS.run then return sd(p) end
   local rel = norm(p)
   if FS.deleted[rel] then trace("read", rel, "deleted"); return nil end
   local r = FS.run .. "/" .. rel
   if isFile(r) then trace("read", rel, "run"); return r end
   for _, fx in ipairs(FS.fixtures) do
      local f = fx.dir .. "/" .. rel
      if isFile(f) then trace("read", rel, "fixture " .. fx.name); return f end
   end
   if visible(rel) and isFile(rel) then trace("read", rel, "apps"); return rel end
   trace("read", rel, isFile(rel) and "hidden" or "missing")
   return nil
end

local madeDirs = {}
local function mkdirp(d)
   if madeDirs[d] then return end
   ros.execute("mkdir -p " .. shq(d))
   madeDirs[d] = true
end

-- the file to write for an app path (always in the run folder)
local function writePath(p)
   if not FS.run then return sd(p) end
   local rel = norm(p)
   FS.deleted[rel] = nil
   local w = FS.run .. "/" .. rel
   mkdirp(w:match("^(.*)/[^/]*$"))
   trace("write", rel, "run")
   return w, rel
end

local function copyFile(from, to)
   local f = rio.open(from, "rb"); if not f then return false end
   local s = f:read("a"); f:close()
   local g = rio.open(to, "wb"); if not g then return false end
   g:write(s); g:close()
   return true
end

local jio = {
   open = function(p, m)
      m = m or "r"
      if not FS.run then return rio.open(sd(p), m) end
      if m:find("[wa+]") then
	 local r = (m:find("[a+]") and not m:find("w")) and readPath(p)
	 local w = writePath(p)
	 if r and r ~= w then copyFile(r, w) end   -- append/update a lower file
	 return rio.open(w, m)
      end
      local r = readPath(p)
      if not r then return nil end
      return rio.open(r, m)
   end,
   close = function(f) return f:close() end,
   read = function(f, n) return f:read(n) or "" end,
   readall = function(p)
      local r = readPath(p)
      if not r then return nil end
      local f = rio.open(r, "rb"); if not f then return nil end
      local s = f:read("a"); f:close(); return s
   end,
   readline = function(f, skipEOL)
      local l = f:read(skipEOL and "l" or "L")
      if l and skipEOL then l = l:gsub("\r$", "") end
      return l
   end,
   write = function(f, ...)
      local a = pack(...)
      for i = 1, a.n do a[i] = tostring(a[i]) end
      return f:write(unpack(a, 1, a.n))
   end,
   seek = function(f, off, mode)
      if mode == nil then return f:seek("set", off) and 0 or 1 end
      return f:seek(mode, off)
   end,
   rename = function(a, b)
      if not FS.run then return ros.rename(sd(a), sd(b)) end
      local r = readPath(a)
      if not r then return nil end
      local w = writePath(b)
      if not copyFile(r, w) then return nil end
      ros.remove(FS.run .. "/" .. norm(a))
      FS.deleted[norm(a)] = true
      return true
   end,
   remove = function(p)
      if not FS.run then return ros.remove(sd(p)) end
      local existed = readPath(p) ~= nil
      ros.remove(FS.run .. "/" .. norm(p))
      FS.deleted[norm(p)] = true
      return existed or nil
   end,
   mkdir = function(p)
      if not FS.run then return ros.execute("mkdir -p " .. shq(sd(p))) and true or nil end
      mkdirp(FS.run .. "/" .. norm(p))
      return true
   end,
}

-- one folder's entries: name -> {type, size}
local function listDir(path, into, keep)
   local h = rio.popen("find " .. shq(path) .. " -mindepth 1 -maxdepth 1 -printf '%f\\t%y\\t%s\\n' 2>/dev/null")
   for l in h:lines() do
      local n, ty, sz = l:match("^(.-)\t(%a)\t(%d+)$")
      if n and not into[n] and (not keep or keep(n, ty == "d")) then
	 into[n] = {ty == "d" and "folder" or "file", ty == "d" and 0 or tonumber(sz)}
      end
   end
   h:close()
end

local function jdir(p)
   local entries = {}
   if not FS.run then
      listDir(sd(p), entries)
   else
      local rel = norm(p)
      local function notDeleted(n) return not FS.deleted[rel .. "/" .. n] end
      listDir(FS.run .. "/" .. rel, entries, notDeleted)
      for _, fx in ipairs(FS.fixtures) do listDir(fx.dir .. "/" .. rel, entries, notDeleted) end
      listDir(rel, entries, function(n, isDir)
	 local q = rel .. "/" .. n
	 return notDeleted(n) and (isDir and visibleDir(q) or not isDir and visible(q))
      end)
   end
   local names = {}
   for n in pairs(entries) do names[#names + 1] = n end
   table.sort(names)
   local i = 0
   return function()
      i = i + 1
      local n = names[i]
      if n then return n, entries[n][1], entries[n][2] end
   end
end

-- for runners: read and write app files through the same layers
function FW.readFile(p)
   local r = readPath(p)
   if not r then return nil end
   local f = rio.open(r, "rb"); if not f then return nil end
   local s = f:read("a"); f:close(); return s
end
function FW.writeFile(p, s)
   local f = assert(jio.open(p, "wb")); f:write(s); f:close()
end
function FW.runDir() return FS.run end

-- start the layers: a run folder, the fixtures, the visible-file list
local function startFS(opts)
   FS = {fixtures = {}, deleted = {}, trace = opts.trace, keep = opts.keep}
   if not opts.fixture and not opts.sandbox then return end
   local list = type(opts.fixture) == "table" and opts.fixture or {opts.fixture}
   for _, name in ipairs(list) do
      local dir = HERE .. "fixtures/" .. name
      local h = rio.popen("test -d " .. shq(dir) .. " && echo ok")
      local ok = h:read("l"); h:close()
      if ok ~= "ok" then error("TestMitter: no fixture " .. dir) end
      FS.fixtures[#FS.fixtures + 1] = {name = name, dir = dir}
   end
   local h = rio.popen("mktemp -d -t testmx-run-XXXXXX")
   FS.run = h:read("l"); h:close()
   assert(FS.run and FS.run ~= "", "TestMitter: mktemp failed")
   -- what git doesn't ignore under Apps/ (tracked, or new and not ignored)
   local g = rio.popen("git -C Apps ls-files --cached --others --exclude-standard 2>/dev/null")
   local vis, dirs, n = {}, {}, 0
   for l in g:lines() do
      vis[l] = true; n = n + 1
      local d = l:match("^(.*)/[^/]*$")
      while d and not dirs[d] do dirs[d] = true; d = d:match("^(.*)/[^/]*$") end
   end
   g:close()
   if n > 0 then FS.visible, FS.visDirs = vis, dirs
   else out("[FW] git ls-files gave nothing: the Apps folder is not hidden") end
   out("[FW] run folder " .. FS.run .. ", fixture " ..
       (#list > 0 and table.concat(list, ", ") or "none"))
end

-- remove the run folder unless asked to keep it
function FW.cleanup()
   if not FS.run then return end
   if FS.keep then out("[FW] run folder kept: " .. FS.run)
   else ros.execute("rm -rf " .. shq(FS.run)) end
   FS.run = nil
end

-- image size from a PNG or JPEG header (0, 0 if unknown)
local function imageSize(s)
   if s:sub(2, 4) == "PNG" then
      return rstring.unpack(">I4I4", s, 17)
   end
   local i = 3
   while i < #s do
      if s:byte(i) ~= 0xFF then break end
      local m = s:byte(i + 1)
      local len = rstring.unpack(">I2", s, i + 2)
      if m >= 0xC0 and m <= 0xCF and m ~= 0xC4 and m ~= 0xC8 and m ~= 0xCC then
	 local h, w = rstring.unpack(">I2I2", s, i + 5)
	 return w, h
      end
      i = i + 2 + len
   end
   return 0, 0
end

--------------------------------------------------------------------------------
-- lcd
--------------------------------------------------------------------------------

local function noop() end
local lcd = {
   setColor = noop, drawPoint = noop, drawLine = noop, drawRectangle = noop,
   drawFilledRectangle = noop, drawCircle = noop, drawArc = noop,
   drawEllipse = noop, drawNumber = noop, drawImage = noop,
   setClipping = noop, resetClipping = noop,
   getBgColor = function() return 255, 255, 255 end,
   getFgColor = function() return 0, 0, 0 end,
   getColor = function() return 0, 0, 0 end,
}
function lcd.drawText(x, y, text, font)
   if FW.onDrawText then FW.onDrawText(x, y, text, font) end
end
local function fontTable(font)
   local t = FONTS[P.fonts]
   local code = (font or base.FONT_NORMAL) & (P.fontMask or 0xFF)
   for _, n in ipairs(FONTNAMES) do
      if base[n] == code then return t, n end
   end
   return t, "FONT_NORMAL"
end
function lcd.getTextHeight(font)
   local t, n = fontTable(font)
   return t.h[n]
end
-- floor(sum of native glyph advances / scale), then the cap. Glyphs:
-- ASCII and (where FontDump measured it) U+00A0..U+00FF from the table;
-- the degree sign always has its own width; anything else gets the width
-- of "o". A byte that isn't valid UTF-8 (sensor units' lone 0xB0) is
-- handled as measured: "stop" (emulator 6.06) counts only the text before
-- it; otherwise each byte is one Latin-1 glyph
function lcd.getTextWidth(font, text)
   local t, n = fontTable(font)
   local w, lat = t.w[n], t.lat and t.lat[n]
   local o, deg = w[("o"):byte() - 31], t.deg[n]
   local function glyph(c)
      if c >= 32 and c <= 126 then return w[c - 31] end
      if c == 0xB0 then return deg end
      if lat and c >= 0xA0 and c <= 0xFF then return lat[c - 0x9F] end
      return o
   end
   text = tostring(text)
   local len, bad = utf8.len(text)
   local sum = 0
   if len then
      for _, c in utf8.codes(text) do sum = sum + glyph(c) end
   elseif t.badByte == "stop" then
      for _, c in utf8.codes(text:sub(1, bad - 1)) do sum = sum + glyph(c) end
   else
      for i = 1, #text do sum = sum + glyph(text:byte(i)) end
   end
   local r = floor(sum / t.scale + 1e-6)
   if t.cap and r > t.cap then r = t.cap end
   return r
end
function lcd.loadImage(p)
   local s = jio.readall(p)
   if not s then return nil end
   local w, h = imageSize(s)
   charge(FW.costs.loadImage(w, h, #s))
   return {width = w, height = h, path = p}
end
function lcd.createImage(w, h)
   return {width = w, height = h}
end
-- renderer: every method a no-op; into an image only where supported
local rendererMT = {__index = function() return noop end}
function lcd.renderer(img)
   if img ~= nil and not P.offscreen then return nil end
   return setmetatable({}, rendererMT)
end

--------------------------------------------------------------------------------
-- forms and telemetry windows
--------------------------------------------------------------------------------

local active                 -- {app, n, f = registration, comps, ...}
local closeReq, prevented = false, false
local questionOpen = false

-- component indexes as the emulator returns them (UIDriver listing,
-- 2026-11-22): every add* call takes the next one, rows and spacers too,
-- counting from 0 (addRow, addLabel, addLink = 0, 1, 2; then 3, 4, 5)
local function add(c)
   if not active then return nil end
   local idx = active.nextIdx
   active.comps[idx] = c
   active.nextIdx = idx + 1
   return idx
end

local form = {}
function form.addRow()
   if not active then return nil end
   active.rows = active.rows + 1
   return add({kind = "row"})
end
function form.addSpacer(w, h, p) return add({kind = "spacer", p = p}) end
function form.addLabel(p) return add({kind = "label", p = p}) end
function form.addIcon(i, p) return add({kind = "icon", p = p}) end
function form.addLink(cb, p) return add({kind = "link", cb = cb, p = p}) end
function form.addIntbox(v, mn, mx, d, dec, st, cb, p)
   return add({kind = "int", v = v, mn = mn, mx = mx, cb = cb, p = p})
end
-- the items are copied, as the firmware reads them when the box is made
function form.addSelectbox(vals, cur, en, cb, p)
   local copy = {}
   for i, v in ipairs(vals or {}) do copy[i] = v end
   return add({kind = "sel", vals = copy, v = cur, cb = cb, p = p})
end
function form.addCheckbox(c, cb, p) return add({kind = "chk", v = c, cb = cb, p = p}) end
function form.addTextbox(t, mx, cb, p) return add({kind = "text", v = t, cb = cb, p = p}) end
function form.addInputbox(sw, prop, cb, p) return add({kind = "input", v = sw, cb = cb, p = p}) end
function form.addAudioFilebox(f, cb, p) return add({kind = "audio", v = f, cb = cb, p = p}) end
-- intbox: clamps and fires the change callback when the value changes
-- (emulator, UIDriver spike)
function form.setValue(i, v)
   local c = active and active.comps[i]
   if not c then return end
   if c.kind == "int" then
      v = math.max(c.mn, math.min(c.mx, v))
      local changed = c.v ~= v
      c.v = v
      if changed and c.cb then c.cb(v) end
   else
      c.v = v
   end
end
function form.getValue(i)
   local c = active and active.comps[i]
   return c and c.v
end
function form.setProperties(i, p)
   local c = active and active.comps[i]
   if c then c.p = p end
end
function form.setButton(n, label, state)
   if active then active.buttons[n] = {label = label, state = state} end
end
function form.getButton(n)
   local b = active and active.buttons[n]
   return b and b.label, b and b.state
end
function form.setTitle(t) if active then active.title = t end end
function form.preventDefault() prevented = true end
function form.waitForRelease() end
function form.setFocusedRow(r) if active then active.focused = r end end
function form.getFocusedRow() return active and active.focused or 1 end
function form.getActiveForm()
   local app = currentApp()
   if active and (not app or active.app == app) then return active.n end
   return nil
end
function form.close() closeReq = true end
-- reinit runs initForm right away, as the emulator can (UIDriver notes)
function form.reinit(sub)
   if not active then return end
   active.comps, active.nextIdx, active.rows, active.sub = {}, 0, 0, sub or 1
   call(active.app, "initForm", active.f.init, active.sub)
end

local runFrame                -- forward

-- blocks; meanwhile the firmware keeps calling every app's loop and
-- print callbacks (emulator); a second question can't open
function form.question(bold, l1, l2)
   if questionOpen then fwlog("second question refused: " .. tostring(bold)); return -1 end
   questionOpen = true
   local answer, frames = FW.question.answer, FW.question.frames
   if FW.onQuestion then answer, frames = FW.onQuestion(bold, l1, l2) end
   fwlog("question: [" .. tostring(bold) .. "] [" .. tostring(l1 or "") .. "] [" ..
	 tostring(l2 or "") .. "] -> " .. (answer == 1 and "yes" or "no"))
   -- the asking callback is paused: the frames' callbacks carry their own cost
   for _ = 1, frames or 3 do runFrame() end
   questionOpen = false
   return answer
end

-- open a registered form by label (Lua pattern) or app name
function FW.openForm(which, sub)
   for _, app in ipairs(apps) do
      for n, f in pairs(app.forms) do
	 if app.name == which or (f.label or ""):find(which) then
	    active = {app = app, n = n, f = f, comps = {}, nextIdx = 0, rows = 0, sub = sub or 1,
		      buttons = {}, focused = 1}
	    call(app, "initForm", f.init, active.sub)
	    call(app, "keyForm", f.key, CONST.KEY_RELEASED)   -- measured
	    return true
	 end
      end
   end
   return false, "no form " .. tostring(which)
end
function FW.activeForm() return active end

local function closeActive()
   local a = active
   active, closeReq = nil, false
   if a then call(a.app, "closeForm", a.f.close) end
end

-- a key press: keyForm(code), then KEY_RELEASED; ESC/KEY_5 close the
-- form unless the app called form.preventDefault
function FW.key(code)
   if not active then return false end
   prevented = false
   call(active.app, "keyForm", active.f.key, code)
   if active then call(active.app, "keyForm", active.f.key, CONST.KEY_RELEASED) end
   if (code == CONST.KEY_ESC or code == CONST.KEY_5) and not prevented then closeReq = true end
   if closeReq then closeActive() end
   return true
end

--------------------------------------------------------------------------------
-- system
--------------------------------------------------------------------------------

local system = {}
system.getTimeCounter = function() return counter0 + now end
system.getTime = getTime
system.getDateTime = getDateTime
system.getCPU = function()
   local rec = stack[#stack]
   if not rec then return 0 end
   local pct = floor(rec.cost * 100 / (P.budgetMs * P.mult / 100))
   return pct > 100 and 100 or pct
end
system.getVersion = function() return P.version end
system.getDeviceType = function() return P.device, P.emulator end
system.getLocale = function() return "en" end
system.getUserName = function() return "" end
system.getSerialCode = function() return "TESTMX" end
system.getTxTelemetry = function() return FW.txTelemetry end
system.getIMU = function() return 0, 0, 0 end
system.getRawIMU = function() return 0, 0, 0, 0, 0, 0 end
system.getServos = function() return {} end
system.getDevices = function() return {} end
system.getDeviceInfo = function() return nil end
system.crc = function(s)
   local crc = 0
   for i = 1, #tostring(s) do
      crc = crc ~ tostring(s):byte(i)
      for _ = 1, 8 do crc = (crc & 1 == 1) and ((crc >> 1) ~ 0x8408) or (crc >> 1) end
   end
   return crc
end
system.isPlayback = function() return false end
system.openExternal = function() return nil end

local props = {}
system.getProperty = function(k) return props[k] or 0 end
system.setProperty = function(k, v) props[k] = v end

-- pSave/pLoad: per app; the TX keeps no floats (notes), so log them
system.pLoad = function(k, d)
   local app = currentApp()
   local v = app and app.saved[k]
   if v == nil then return d end
   return v
end
system.pSave = function(k, v)
   local app = currentApp()
   if not app then return end
   if math.type(v) == "float" then fwlog(app.name .. " pSave(" .. tostring(k) .. ") of a float; the TX stores no floats") end
   app.saved[k] = v
end

-- a message box is one centred line, clipped at both ends when too long:
-- about 26 characters fit a DS-24 (320 px), 42 a DS-24 II. An app ships
-- to every TX, so longer ones are reported (not failed) on any profile
FW.maxMessage = 26
FW.longMessages = {}
system.messageBox = function(m, t)
   m = tostring(m)
   fwlog("messageBox: " .. m)
   if #m > FW.maxMessage and not FW.longMessages[m] then
      local app = currentApp()
      FW.longMessages[m] = (app and app.name or "?")
      FW.longMessages[#FW.longMessages + 1] = m
      fwlog("WARN messageBox is " .. #m .. " characters, over " .. FW.maxMessage ..
	    " (clipped on a DS-24): " .. m)
   end
end
system.playFile = function(f, t) fwlog("playFile " .. tostring(f)) end
system.playNumber = function(v, d) fwlog("playNumber " .. tostring(v)) end
system.playBeep = function(r, h, l) fwlog("playBeep") end
system.playSystemSound = function(n) fwlog("playSystemSound " .. tostring(n)) end
system.stopPlayback = noop
system.vibration = function(r, p) fwlog("vibration " .. tostring(r) .. " " .. tostring(p)) end
system.setVario = noop

system.registerForm = function(n, parent, label, init, key, prt, close)
   local app = currentApp()
   if not app then return nil end
   app.forms[n] = {label = label, parent = parent, init = init, key = key, print = prt, close = close}
   return n
end
system.unregisterForm = function(n)
   local app = currentApp()
   if app then app.forms[n] = nil end
end
system.registerTelemetry = function(n, label, size, prt, key)
   local app = currentApp()
   if not app then return nil end
   app.tels[n] = {label = label, size = size, print = prt, key = key}
   return n
end
system.unregisterTelemetry = function(n)
   local app = currentApp()
   if app then app.tels[n] = nil end
end
system.setTelemetryButton = noop

local ctrls = {}
system.registerControl = function(n, label, sw) ctrls[n] = {label = label, sw = sw, v = 0}; return n end
system.setControl = function(n, v, d) if ctrls[n] then ctrls[n].v = v end; return true end
system.unregisterControl = function(n) ctrls[n] = nil end
FW.luaControls = ctrls
system.registerLogVariable = function(label, unit, f) return 1 end
system.unregisterLogVariable = noop

-- sticks and switches from FW.controls (unset ones read 0)
system.getInputs = function(...)
   local r, n = {}, select("#", ...)
   for i = 1, n do r[i] = FW.controls[select(i, ...)] or 0 end
   return unpack(r, 1, n)
end
system.createSwitch = function(name, mode, on)
   local known = name ~= nil and name ~= "" and name ~= "XX"
   mode = mode or "S"
   return setmetatable({}, {__name = "SwitchItem", sw = name, mode = mode, on = on or 0,
      info = {label = known and (name:sub(1, 1) .. name:sub(2):lower()) or "",
	      assigned = known, mode = mode, activeOn = (on or 0) + 0.0,
	      proportional = mode:find("P") ~= nil}})
end
-- a switch item's value, as measured in the emulator (UIDriver's evalSwitch
-- has the same rules): S or E in the mode means switch evaluation, even
-- with P ("PS"): 1 when active, else -1. A two/three-position switch
-- (SA..SP) is active at its activeOn position, other controls when they
-- reach activeOn. P alone passes the position through; I inverts it and C
-- maps it to 0..1
local function itemValue(m)
   local raw = FW.controls[m.sw] or 0
   local mode = m.mode:upper()
   local inv = mode:find("I") ~= nil
   if mode:find("P") and not mode:find("S") and not mode:find("E") then
      local v = inv and -raw or raw
      if mode:find("C") then v = (v + 1) / 2 end
      return v
   end
   local on, active = m.on or 0
   if m.sw:match("^S%a$") then
      active = math.abs(raw - on) < 0.5
   elseif on >= 0 then
      active = raw >= on
   else
      active = raw <= on
   end
   if inv then active = not active end
   return active and 1 or -1
end

-- getSwitchInfo: a fresh table each call, with "value" the item's current
-- value (what getInputsVal returns): DFM-Path reads a PC control's 0..1
-- from it
system.getSwitchInfo = function(sw)
   local m = sw and getmetatable(sw)
   if not (m and m.info) then return nil end
   local t = {}
   for k, v in pairs(m.info) do t[k] = v end
   if m.info.assigned then t.value = itemValue(m) end
   return t
end
system.getInputsVal = function(...)
   local r, n = {}, select("#", ...)
   for i = 1, n do
      local sw = select(i, ...)
      local m = sw and getmetatable(sw)
      if m and m.info and m.info.assigned then r[i] = itemValue(m) end
   end
   return unpack(r, 1, n)
end

-- sensors from FW.sensors: {id, param, label, unit, type, decimals, value, valid, ...}
system.getSensors = function()
   local r = {}
   for i, s in ipairs(FW.sensors) do
      local c = {}
      for k, v in pairs(s) do c[k] = v end
      r[i] = c
   end
   return r
end
system.getSensorByID = function(id, param)
   for _, s in ipairs(FW.sensors) do
      if s.id == id and s.param == param then
	 local c = {}
	 for k, v in pairs(s) do c[k] = v end
	 return c
      end
   end
   return nil
end
system.getSensorValueByID = system.getSensorByID

--------------------------------------------------------------------------------
-- gps, timer, gpio, serial
--------------------------------------------------------------------------------

local gps = {}
for k, v in pairs(C.gps) do gps[k] = v end
-- getPosition from a GPS sensor's valGPS: degrees << 16 | minutes * 1000;
-- decimals is the hemisphere (0..3 = N, E, S, W), as SensorE decodes it
function gps.getPosition(id, pLat, pLon)
   -- through the app-visible system table, which SensorE/SensorL replace into
   local a, b = base.system.getSensorByID(id, pLat), base.system.getSensorByID(id, pLon)
   if not (a and b and a.valid and b.valid and a.valGPS and b.valGPS) then return nil end
   local function deg(s, neg)
      local d = ((s.valGPS >> 16) & 0xFF) + (s.valGPS & 0xFFFF) * 0.001 / 60
      if s.decimals == neg then d = -d end
      return fmt("%.8f", d)
   end
   return C.gps.newPoint(deg(a, 2), deg(b, 3))
end

local function stubs(names)
   local t = {}
   for n in names:gmatch("%S+") do t[n] = noop end
   return t
end
local timer = stubs("create delete getByID getByName getName getRawTime getRoundCount getType isRunning restart start stop")
local gpio = stubs("mode read write")
-- serial as a null device: any port opens, writes are accepted (the
-- byte count comes back) and thrown away, nothing is ever read. So an app
-- like DFM-HUD runs as if its device were plugged in. FW.serialBytes
-- counts what was written, per port name.
-- A device model can be attached to a port name before the apps start:
--   FW.serialDevice("ttyUSB0", dev)
-- dev.write(bytes) sees each write; dev.attach(api) is called once, with
-- api.send(bytes) (queued for the app's onRead callback, delivered at the
-- start of the next frame, as the TX does from its own loop), api.now()
-- (virtual ms) and api.log(text). dev.frame(now), if present, runs every
-- frame (timed replies, disconnects ...)
local serial = {}
local serialPorts = {}     -- handle -> {name, app, onRead, rx = {...}}
local serialDevs = {}      -- port name -> device model
FW.serialBytes = {}
function FW.serialDevice(name, dev)
   serialDevs[name] = dev
   dev.attach({
      send = function(bytes)
	 for _, p in pairs(serialPorts) do
	    if p.name == name then p.rx[#p.rx + 1] = bytes end
	 end
      end,
      now = function() return now end,
      log = function(t) fwlog(name .. ": " .. tostring(t)) end,
   })
end
function serial.getPorts() return {} end
function serial.init(port)
   local h = #serialPorts + 1
   serialPorts[h] = {name = tostring(port), app = currentApp(), rx = {}}
   FW.serialBytes[serialPorts[h].name] = FW.serialBytes[serialPorts[h].name] or 0
   return h, serialPorts[h].name
end
function serial.deinit(h)
   local ok = serialPorts[h] ~= nil
   serialPorts[h] = nil
   return ok
end
function serial.setBaudrate(h) return serialPorts[h] ~= nil end
function serial.onRead(h, f)
   local p = serialPorts[h]
   if not p then return false, "port not open" end
   p.onRead = f
   return true
end
function serial.write(h, s)
   local p = serialPorts[h]
   if not p then return nil, "port not open" end
   s = tostring(s or "")
   FW.serialBytes[p.name] = FW.serialBytes[p.name] + #s
   local dev = serialDevs[p.name]
   if dev and dev.write then dev.write(s) end
   return #s
end
-- once a frame: device timers, then what devices sent, to onRead
local function serialFrame()
   for _, dev in pairs(serialDevs) do
      if dev.frame then dev.frame(now) end
   end
   for _, p in pairs(serialPorts) do
      if #p.rx > 0 then
	 local data = table.concat(p.rx)
	 p.rx = {}
	 if p.onRead and p.app then call(p.app, "onRead", p.onRead, data) end
      end
   end
end

--------------------------------------------------------------------------------
-- app environments
--------------------------------------------------------------------------------

local STD = {"assert", "collectgarbage", "error", "getmetatable", "ipairs", "next",
   "pairs", "pcall", "print", "rawequal", "rawget", "rawlen", "rawset", "select",
   "setmetatable", "tonumber", "tostring", "type", "xpcall", "_VERSION"}
local STDLIB = {"string", "table", "math", "utf8", "coroutine", "debug", "os", "package"}

local APPPATH = "./Apps/?.lc;./Apps/?/init.lc;./Apps/?.lc2;./Apps/?/init.lc2;" ..
   "./Apps/?.lua;./Apps/?/init.lua;./Apps/lib/?.lua;./Apps/lib/?/init.lua;"

local function buildBase()
   for k in pairs(base) do base[k] = nil end
   for _, k in ipairs(STD) do base[k] = _G[k] end
   for _, k in ipairs(STDLIB) do
      if not P.hide[k] then base[k] = _G[k] end
   end
   -- JETI's math has no LUA_COMPAT_MATHLIB functions (EnvDump)
   local m = {}
   for k, v in pairs(math) do m[k] = v end
   for n in ("atan2 cosh frexp ldexp log10 pow sinh tanh"):gmatch("%S+") do m[n] = nil end
   base.math = m
   if base.package then
      local pk = {}
      for k, v in pairs(package) do pk[k] = v end
      pk.path = P.packagePath
      base.package = pk
   end
   for k, v in pairs(CONST) do base[k] = v end
   for k, v in pairs(P.const or {}) do base[k] = v end
   -- the libraries are copies, so a profile can leave members out
   local function copy(t) local c = {}; for k, v in pairs(t) do c[k] = v end; return c end
   base.system, base.form, base.lcd, base.json = copy(system), copy(form), copy(lcd), json
   -- system.TestMX: true only here, for test tools (UIDriver runs on a TX
   -- profile). In a metatable, so pairs() and EnvDump don't list it
   setmetatable(base.system, {__index = {TestMX = true}})
   base.io, base.dir, base.timer, base.gpio, base.serial = jio, jdir, timer, gpio, serial
   base.lcd.width, base.lcd.height = P.lcdW, P.lcdH
   base.gps = copy(gps)
   base.gps.getString = nil
   base.gps[P.gpsName] = C.gps.getString
   -- remove: "NAME" a global, "lib.member", "PREFIX_" every global starting so
   for _, r in ipairs(P.remove or {}) do
      local lib, mem = r:match("^(%w+)%.(%w+)$")
      if lib then base[lib][mem] = nil
      elseif r:sub(-1) == "_" then
	 for k in pairs(CONST) do if k:sub(1, #r) == r then base[k] = nil end end
      else base[r] = nil end
   end
   if P.declareGlobal then
      base.declareGlobal = function(name, v)
	 if v == nil then v = false end
	 superNames[name], superVals[name] = true, v
	 for _, a in ipairs(apps) do rawset(a.env, name, nil) end
      end
      base.dumpGlobalVars = function()
	 for k in pairs(superNames) do out(k .. ": " .. tostring(superVals[k])) end
      end
   end
end

-- 5.06 (DS-16): the libraries and constants live in ROM tables. pairs(_G)
-- lists only the globals in P.rom; the rest are found by name (__index).
-- type() of a ROM library is "rotable" and of its functions
-- "lightfunction", and pairs() of a ROM library is an error. Not modelled:
-- on the TX lib[name] with a name in a variable is nil, only lib.name
-- written in the code works (EnvDump 1.7 "check member").
local function romEnv(env)
   local visible, hidden, romLib, romFn = {}, {}, {}, {}
   for _, k in ipairs(P.rom) do visible[k] = true end
   for k, v in pairs(env) do
      if not visible[k] then
	 hidden[k] = v
	 if type(v) == "table" then
	    romLib[v] = true
	    for _, f in pairs(v) do if type(f) == "function" then romFn[f] = true end end
	 end
      end
   end
   for k in pairs(hidden) do env[k] = nil end
   local mt = getmetatable(env)
   local old = mt.__index
   mt.__index = function(t, k)
      local v = hidden[k]
      if v ~= nil then return v end
      return old(t, k)
   end
   local rtype, rpairs, rnext = type, pairs, next
   env.type = function(v)
      if romLib[v] then return "rotable" end
      if romFn[v] then return "lightfunction" end
      return rtype(v)
   end
   local function check(t)
      if romLib[t] then
	 error("bad argument #1 to 'for iterator' (table expected, got rotable)", 3)
      end
   end
   env.pairs = function(t) check(t); return rpairs(t) end
   env.next = function(t, k) check(t); return rnext(t, k) end
end

local function makeEnv(app)
   if not P.declareGlobal and sharedEnv then return sharedEnv end
   -- the base globals are copied in, so pairs(_G) lists them as on the
   -- emulator; declared superglobals are kept out and read through __index
   local env = {}
   for k, v in pairs(base) do if not superNames[k] then env[k] = v end end
   setmetatable(env, {
      __index = function(_, k)
	 if superNames[k] then return superVals[k] end
      end,
      __newindex = function(t, k, v)
	 if superNames[k] then superVals[k] = v else rawset(t, k, v) end
      end,
   })
   env._G = env
   if P.declareGlobal then env.scriptID = app.index end
   if P.rom then romEnv(env) end
   local function lf(p, mode, e)
      local r = readPath(p)
      if not r then return nil, "cannot open " .. tostring(p) end
      return hostLoadfile(r, mode or "bt", e or env)
   end
   env.loadfile = lf
   env.load = function(s, name, mode, e) return hostLoad(s, name, mode or "bt", e or env) end
   env.dofile = function(p) local f = assert(lf(p)); return f() end
   -- require loads modules into the app's own globals
   local loaded = {}
   env.require = function(name)
      if loaded[name] ~= nil then return loaded[name] end
      local path
      for tpl in APPPATH:gmatch("[^;]+") do
	 local c = tpl:gsub("%?", (name:gsub("%.", "/")))
	 if readPath(c) then path = c; break end
      end
      if not path then error("module '" .. name .. "' not found", 2) end
      local f = assert(lf(path))
      local r = f(name)
      if r == nil then r = true end
      loaded[name] = r
      return r
   end
   if not P.declareGlobal then sharedEnv = env end
   return env
end

--------------------------------------------------------------------------------
-- setup, loading, the scheduler
--------------------------------------------------------------------------------

-- opts: profile, seed, mult (CPU multiplier %), startDate {year, mon, day,
-- hour, min, sec} (local; default 2026-11-21 12:00:00), plus any TIMING key
function FW.setup(opts)
   opts = opts or {}
   local prof = FW.profiles[opts.profile or "emu-ds24ii-606"]
   if not prof then error("TestMitter: no profile " .. tostring(opts.profile)) end
   P = {name = opts.profile or "emu-ds24ii-606"}
   for k, v in pairs(prof) do P[k] = v end
   for k, v in pairs(TIMING) do P[k] = v end
   for k, v in pairs(opts) do if TIMING[k] ~= nil then P[k] = v end end
   P.mult = opts.mult or 100
   hookMs = P.hookN * P.nsPerInstr / 1e6
   rng = opts.seed or 1
   math.randomseed(opts.seed or 1)
   local sd = opts.startDate or {year = 2026, mon = 11, day = 21, hour = 12, min = 0, sec = 0}
   startSec2000 = days2000(sd.year, sd.mon, sd.day) * 86400 + sd.hour * 3600 + sd.min * 60 + sd.sec
   -- the virtual clock starts at 0; apps see it from counterStart
   now, frac, frameEnd = 0, 0.0, 0
   counter0 = opts.counterStart or P.counterStart or 0
   wall0 = C.ms()
   FW.paced = opts.paced or false
   if not ros.setlocale(P.collate, "collate") then
      fwlog("can't set collation " .. P.collate .. "; string order may differ from the device")
   end
   if opts.model then props.Model = opts.model end
   -- getProperty("ModelFile"): the model's file in Model/ ("0001Aaa.jsn"),
   -- which apps like DFM-SWT read. Model/ is outside Apps/, so it's read in
   -- place, or from a fixture that has Model/<file>
   if opts.modelFile then props.ModelFile = opts.modelFile end
   startFS(opts)
   buildBase()
   return P
end
function FW.profile() return P end

-- load apps by name (Apps/<name>.lua or .lc) in this order
function FW.load(names)
   for _, name in ipairs(names) do
      local app = {name = name, index = #apps + 1, forms = {}, tels = {}, saved = {}}
      app.env = makeEnv(app)
      local path
      for _, ext in ipairs({".lua", ".lc"}) do
	 local f = rio.open("Apps/" .. name .. ext)
	 if f then f:close(); path = "Apps/" .. name .. ext; break end
      end
      if not path then error("TestMitter: no Apps/" .. name .. ".lua or .lc") end
      local chunk, err = hostLoadfile(path, "bt", app.env)
      if not chunk then error("TestMitter: " .. err) end
      apps[#apps + 1] = app
      appByName[name] = app
      app.t = call(app, "load", chunk)
      if type(app.t) ~= "table" then
	 if not app.dead then
	    app.dead = true
	    errors[#errors + 1] = name .. ": did not return an app table"
	    fwlog(name .. " did not return an app table")
	 end
      end
   end
end
function FW.app(name) return appByName[name] end
function FW.apps() return apps end

-- init in load order, or in the order given (the emulator's order can't be
-- relied on; see the community notes)
function FW.initApps(order)
   local list = apps
   if order then
      list = {}
      for _, n in ipairs(order) do list[#list + 1] = appByName[n] end
   end
   for _, app in ipairs(list) do
      if app.t then call(app, "init", app.t.init, 0) end
   end
end

function FW.onFrame(f) frameHooks[#frameHooks + 1] = f end

local function jitter()
   rng = (rng * 1103515245 + 12345) % 2147483648
   return (rng >> 8) % (P.loopJitterMs + 1)
end

local lastPrint = -1e9

-- one firmware frame: advance the clock, frame hooks, every app's loop,
-- then the form or the telemetry windows when a redraw is due
function runFrame()
   local start = frameEnd > now and frameEnd or now
   now, frac = start, 0.0
   frameEnd = start + P.loopMs + jitter()
   for _, f in ipairs(frameHooks) do f(now) end
   serialFrame()
   for _, app in ipairs(apps) do
      if app.t and app.t.loop then call(app, "loop", app.t.loop) end
   end
   if now - lastPrint >= P.printMs then
      lastPrint = now
      if active then
	 call(active.app, "printForm", active.f.print, P.form[1], P.form[2])
	 if closeReq then closeActive() end
      else
	 for _, app in ipairs(apps) do
	    for n, t in pairs(app.tels) do
	       local sz = P.tele[(t.size == 1 or t.size == 2 or t.size == 3) and t.size or 4]
	       if t.size == 0 then sz = P.tele[2] end
	       call(app, "printTele " .. n, t.print, sz[1], sz[2])
	    end
	 end
      end
   end
   if active and closeReq then closeActive() end
   if FW.paced then
      local behind = (now - (C.ms() - wall0))
      if behind > 0 then C.sleep(behind) end
   end
end
FW.runFrame = runFrame

-- run frames until ms more virtual time has passed, or until() is true
function FW.run(ms, untilf)
   local stop = now + (ms or 0)
   repeat
      runFrame()
      if untilf and untilf() then break end
   until now >= stop
end

-- the report; returns the exit code (0 ok, 1 errors or failures)
-- the apps' destroy, as the TX calls it when the model changes or the app
-- is removed (apps save their settings there); FW.finish calls it when the
-- file layers are on, so it can't write the working data
function FW.destroyApps()
   for _, app in ipairs(apps) do
      if app.t then call(app, "destroy", app.t.destroy) end
   end
end

function FW.finish()
   if FS.run then FW.destroyApps() end
   out(fmt("[FW] ---- TestMitter report: profile %s, T=%d ms, multiplier %d%% ----", P.name, now, P.mult))
   local keys = {}
   for k in pairs(cpu) do keys[#keys + 1] = k end
   table.sort(keys)
   out(fmt("[FW] %-28s %7s %8s %8s %6s", "callback", "calls", "max ms", "avg ms", "over"))
   for _, k in ipairs(keys) do
      local c = cpu[k]
      out(fmt("[FW] %-28s %7d %8.2f %8.3f %6d", k, c.calls, c.max, c.total / c.calls, c.over))
   end
   for port, n in pairs(FW.serialBytes) do
      out(string.format("[FW] serial %s (null device): %d bytes written", port, n))
   end
   out("[FW] cost model not calibrated against a TX yet; CPU overruns are reported, not failed")
   for _, m in ipairs(FW.longMessages) do
      out(fmt("[FW] warning: %s messageBox over %d characters (%d): %s",
	      FW.longMessages[m], FW.maxMessage, #m, m))
   end
   for _, e in ipairs(errors) do out("[FW] app error: " .. e) end
   for _, f in ipairs(failures) do out("[FW] failure: " .. f) end
   local code = (#errors > 0 or #failures > 0) and 1 or 0
   out(fmt("[FW] RESULT: %s (%d app errors, %d failures)", code == 0 and "PASS" or "FAIL", #errors, #failures))
   FW.cleanup()
   return code
end

--------------------------------------------------------------------------------
-- command line
--------------------------------------------------------------------------------

local function main(argv)
   local opts, names, secs = {}, {}, 0
   local i = 1
   while i <= #argv do
      local a = argv[i]
      if a == "-p" then opts.profile = argv[i + 1]; i = i + 1
      elseif a == "-t" then secs = tonumber(argv[i + 1]); i = i + 1
      elseif a == "--paced" then opts.paced = true
      elseif a == "--seed" then opts.seed = math.tointeger(tonumber(argv[i + 1])); i = i + 1
      elseif a == "--mult" then opts.mult = math.tointeger(tonumber(argv[i + 1])); i = i + 1
      else names[#names + 1] = a end
      i = i + 1
   end
   if opts.profile == "list" then
      for k, p in pairs(FW.profiles) do hostPrint(k, p.device, p.version) end
      return 0
   end
   if #names == 0 then
      hostPrint("usage: lua Apps/TestMX/testmx.lua [-p profile] [-t seconds] [--paced] [--seed n] [--mult pct] App ...")
      return 2
   end
   FW.setup(opts)
   FW.load(names)
   FW.initApps()
   FW.run(floor(secs * 1000))
   return FW.finish()
end

if arg and arg[0] and arg[0]:match("testmx%.lua$") then
   ros.exit(main(arg))
end

return FW
