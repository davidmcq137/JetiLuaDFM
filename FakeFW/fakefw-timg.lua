-- FakeFW prototype: a fake JETI firmware in Lua, so UIDriver scripts can run
-- outside JETI Studio (e.g. in GitHub Actions). Saved as-is from the
-- 2026-11-19 session's off-target checks; not cleaned up yet.
--
-- What it is: just enough of system/form/lcd/gps/json/io for UIDriver.lua,
-- SensorL.lua and DFM-TimG.lua, with a simulated clock (50 ms frames, 20
-- minutes) so a 13-minute flight runs in seconds. It reproduces what the
-- UIDriver spike measured in the emulator:
--   KEY_RELEASED = -2147483648; one KEY_RELEASED to keyForm when a form opens
--   intbox setValue clamps and fires the change callback when the value changes
--   telemetry windows aren't drawn while a form is open
-- It opens DFM-TimG's form at 1 s (the "human" of waitForm) and stands in
-- for DFM-HUD's "hudTimG" hook. The script it plays is the one in
-- Apps/UIDriver/selection.jsn, and it writes that app's UIDriver/result.log.
--
-- Run it with the JETI-built Lua (LUA_32BITS, LUA_FLOORN2I) so numbers
-- behave as on the TX; ~/lua-5.3.1-Jeti-typefix/src/lua also fixes type():
--   cd ~/.config/JETI-Studio/Emulator     (the parent of Apps)
--   lua Apps/FakeFW/fakefw-timg.lua Apps play
-- Verified: timg-test.jsn 26 PASS 0 FAIL, hud-test.jsn 18 PASS 0 FAIL, the
-- same results as the emulator.
--
-- Next (see the FakeFW plan): a reusable module instead of this TimG-only
-- runner; gps.* and SensorE for Rscu/Path; forms opened automatically from
-- the script; and a pass/fail exit code for CI.

local APPS, SCEN = arg[1], arg[2] or "play"
ANSWER = tonumber(arg[3])
local T = 0
KEY_1, KEY_2, KEY_3, KEY_4, KEY_5 = 1, 2, 4, 8, 16
KEY_ESC, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_MENU = 32, 64, 128, 256, 512
KEY_RELEASED = -2147483648
AUDIO_BACKGROUND, AUDIO_IMMEDIATE, AUDIO_QUEUE = 0, 1, 2
MENU_APPS, FONT_MINI, FONT_BOLD, FONT_NORMAL = 5, 0, 0, 0

---------------------------------------------------------------- mini json
json = {}
function json.encode(v)
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local o = {}
      for _, x in ipairs(v) do o[#o+1] = json.encode(x) end
      return "[" .. table.concat(o, ",") .. "]"
    end
    local o, keys = {}, {}
    for k in pairs(v) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do o[#o+1] = string.format("%q", k) .. ":" .. json.encode(v[k]) end
    return "{" .. table.concat(o, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  else return tostring(v) end
end
function json.decode(s)
  local i = 1
  local function ws() i = s:find("[^%s]", i) or #s + 1 end
  local val
  function val()
    ws()
    local c = s:sub(i, i)
    if c == "{" then
      local o = {}; i = i + 1; ws()
      if s:sub(i, i) == "}" then i = i + 1; return o end
      while true do
        local k = val(); ws(); i = i + 1 -- ':'
        o[k] = val(); ws()
        local d = s:sub(i, i); i = i + 1
        if d == "}" then return o end
      end
    elseif c == "[" then
      local o = {}; i = i + 1; ws()
      if s:sub(i, i) == "]" then i = i + 1; return o end
      while true do
        o[#o+1] = val(); ws()
        local d = s:sub(i, i); i = i + 1
        if d == "]" then return o end
      end
    elseif c == '"' then
      local j = s:find('"', i + 1, true)
      local r = s:sub(i + 1, j - 1); i = j + 1; return r
    elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
    elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
    elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
    else
      local j = s:find("[^%-%d%.eE+]", i) or #s + 1
      local n = tonumber(s:sub(i, j - 1)) + 0.0   -- JETI json.decode returns floats
      i = j; return n
    end
  end
  return val()
end

---------------------------------------------------------------- io
local rio = io
io = {
  open = function(p, m) return rio.open(p, m) end,
  write = function(f, ...) return f:write(...) end,
  close = function(f) return f:close() end,
  mkdir = function(p) return os.execute("mkdir -p " .. p) and true or nil end,
  readall = function(p) local f = rio.open(p); if not f then return nil end
    local s = f:read("a"); f:close(); return s end,
}

---------------------------------------------------------------- system / form / lcd
local forms, tels, active, comps, closeReq = {}, {}, nil, {}, false
local prevented
system = {
  getTimeCounter = function() return T end,
  getDateTime = function() return {year=2026, mon=11, day=19, hour=13, min=5, sec=T//1000 % 60} end,
  getCPU = function() return math.random(5, 40) end,
  getDeviceType = function() return "JETI DS-24 (fake)", 1 end,
  registerForm = function(n, parent, label, i, k, p, c)
    forms[label] = {i=i, k=k, p=p, c=c}; return n end,
  setTelemetryButton = function(w, n, t, st) end,
  messageBox = function(m, t) print("[FW] messageBox: " .. tostring(m)) end,
  playFile = function(f, t) print("[FW] playFile " .. tostring(f)) end,
  playNumber = function(v, d) print("[FW] playNumber " .. tostring(v)) end,
  vibration = function(r, p) print("[FW] vibration " .. tostring(r) .. " " .. tostring(p)) end,
  playBeep = function(r, h, l) print("[FW] playBeep") end,
  -- the "real" controls: sliders at fixed positions
  getInputs = function(...) local r = {}
    for i = 1, select("#", ...) do r[i] = ({P5 = -0.5, P6 = 0.1, SA = -1})[select(i, ...)] or 0 end
    return table.unpack(r, 1, select("#", ...)) end,
  createSwitch = function(name, mode, on)
    local known = name ~= "" and name ~= "XX"
    return setmetatable({}, {__name = "SwitchItem", sw = name, mode = mode or "S", on = on or 0,
      info = {label = known and (name:sub(1,1) .. name:sub(2):lower()) or "", assigned = known,
              mode = mode or "S", activeOn = (on or 0) + 0.0,
              proportional = (mode or "S"):find("P") ~= nil}}) end,
  getSwitchInfo = function(sw) return getmetatable(sw).info end,
  getInputsVal = function(...) local r = {}
    for i = 1, select("#", ...) do
      local sw = select(i, ...)
      local m = sw and getmetatable(sw)
      if m and m.info.assigned then
        local raw = ({P5 = -0.5, P6 = 0.1, SA = -1})[m.sw] or 0
        if m.mode:find("P") then r[i] = raw else r[i] = (math.abs(raw - m.on) < 0.5) and 1 or -1 end
      end
    end
    return table.unpack(r, 1, select("#", ...)) end,
  getSensors = function() return {{id=3, param=0, label="MGPS"},
    {id=3, param=2, type=9, label="Latitude"}, {id=3, param=3, type=9, label="Longitude"},
    {id=3, param=6, type=1, label="Altitude"}} end,
  getSensorByID = function(id, p) return {value = 0, valid = true} end,
  registerControl = function(n, l, s) return n end,
  setControl = function(n, v, d) return true end,
  registerTelemetry = function(n, label, size, p, k) tels[label .. "#" .. n] = {p=p, k=k}; return n end,
}
dir = function(p) local h = rio.popen("ls -p " .. p .. " 2>/dev/null"); local names = {}; for l in h:lines() do names[#names+1] = l end; h:close(); local i = 0; return function() i = i + 1; local n = names[i]; if not n then return nil end; if n:sub(-1) == "/" then return n:sub(1, -2), "folder", 0 end; return n, "file", 1 end end
local fwCreate = system.createSwitch   -- the firmware's own, as its dialog would use
local function add(c) comps[#comps+1] = c; return #comps end
form = {
  addRow = function() return 0 end,
  addLabel = function(p) return add({kind="label"}) end,
  addIntbox = function(v, mn, mx, d, dec, st, cb) return add({kind="int", v=v, mn=mn, mx=mx, cb=cb}) end,
  addSelectbox = function(vals, cur, en, cb) return add({kind="sel", v=cur, cb=cb}) end,
  addCheckbox = function(c, cb) return add({kind="chk", v=c, cb=cb}) end,
  addLink = function(cb, p) return add({kind="link", cb=cb}) end,
  addTextbox = function(t, mx, cb) return add({kind="text", v=t, cb=cb}) end,
  addInputbox = function(sw, prop, cb) return add({kind="input", v=sw, cb=cb}) end,
  setValue = function(i, v)
    local c = comps[i]
    if c.kind == "int" then
      v = math.max(c.mn, math.min(c.mx, v))
      local changed = c.v ~= v
      c.v = v
      if changed and c.cb then c.cb(v) end   -- emulator behaviour
    else
      c.v = v
    end
  end,
  getValue = function(i) return comps[i].v end,
  setButton = function() end,
  setTitle = function(t) print("[FW] title: " .. t) end,
  preventDefault = function() prevented = true end,
  -- like the emulator: while a question waits, loop() keeps being called;
  -- a second question can't open and returns -1
  question = function(b, l1, l2)
    if QOPEN then print("[FW] second question refused: " .. b); return -1 end
    QOPEN = true
    print("[FW] question shown to HUMAN: [" .. b .. "] [" .. (l1 or "") .. "] [" .. (l2 or "") .. "] -> yes")
    for _ = 1, 3 do T = T + 50; DRV.loop() end
    QOPEN = false
    return 1
  end,
  close = function() closeReq = true end,
  reinit = function(s) comps = {}; active.i(s) end,
}
lcd = {loadImage=function(p) if p:find("no%-such") then return nil end; return {width=8, height=8, data=p} end, drawImage=function() end, createImage=function(w, h) return {width=w, height=h} end, setColor=function() end, drawFilledRectangle=function() end, drawRectangle=function() end,
  drawText=function(x, y, t)
    if LOGTEXT and tostring(t):find("question in") then print(string.format("[LCD] T=%d %s", T, t)) end
    if tostring(t):find("F1 = Yes") then SAWKEYBOX = (SAWKEYBOX or 0) + 1 end
  end}
LOGTEXT = true

-- extra stubs for SensorL and DFM-TimG
-- JETI's string.format floors a float for %d; stock Lua errors
do local f = string.format
  string.format = function(fmt, ...)
    local ok, r = pcall(f, fmt, ...)
    if ok then return r end
    local a = table.pack(...)
    for i = 1, a.n do if math.type(a[i]) == "float" then a[i] = math.floor(a[i]) end end
    return f(fmt, table.unpack(a, 1, a.n))
  end
end
io.read = function(f, n) return f:read(n) end
io.readline = function(f) local l = f:read("l"); if l then l = l:gsub("\r$", "") end; return l end
io.seek = function(f, pos) return f:seek("set", pos) end
local saved = {}
system.pLoad = function(k, d) if saved[k] ~= nil then return saved[k] end return d end
system.pSave = function(k, v) saved[k] = v end
system.getTime = function() return 1700000000 + T // 1000 end
system.getProperty = function() return 0 end
system.setProperty = function() end
system.getLocale = function() return "en" end
lcd.setClipping = function() end; lcd.resetClipping = function() end
lcd.getTextWidth = function(f, t) return 6 * #tostring(t) end; lcd.getTextHeight = function() return 10 end
gps = {newPoint = function(a, b) return {lat = a, lon = b} end, getPosition = function() end}

---------------------------------------------------------------- run
local drv = dofile(APPS .. "/UIDriver.lua"); DRV = drv
local sl = dofile(APPS .. "/SensorL.lua")
local tg = dofile(APPS .. "/DFM-TimG.lua")
tg.init(); sl.init(); drv.init()
system.UIDriver.expose("hudTimG", function()   -- stand-in for DFM-HUD's hook
  local function v(pa) if type(DFM_TimG) ~= "table" then return nil end
    if pa == 13 then return DFM_TimG.remaining or 0 end return DFM_TimG.elapsed or 0 end
  return {remaining = v(13), elapsed = v(14)} end)     -- TimG's init first: the order that used to break SensorL
local F
for label, f in pairs(forms) do if label:find("Geriatric") then F = f end end
local function openForm() active = F; comps = {}; F.i(1); F.k(KEY_RELEASED) end
for frame = 1, 20 * 60 * 20 do       -- 20 minutes at 50 ms
  T = T + 50
  if T == (FORMAT or 1000) then openForm() end
  if active then F.p(320, 160); if closeReq then F.c(); active = nil; closeReq = false end end
  if T % 200 == 0 then tg.loop() end
  if sl.loop then sl.loop() end
  drv.loop()
end
print(string.format("DFM_TimG at the end: elapsed=%s remaining=%s", tostring(DFM_TimG and DFM_TimG.elapsed), tostring(DFM_TimG and DFM_TimG.remaining)))
