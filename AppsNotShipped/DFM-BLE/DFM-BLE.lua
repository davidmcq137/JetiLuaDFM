--[[

   DFM-BLE.lua -- sends the transmitter's telemetry over serial to the
   dfmBleESP ESP32, which passes it on over Bluetooth LE in JETI's own
   format. JETI Studio Mobile on an iPhone (and later our own iOS app) then
   shows it as if it came from a DS-24 II.

   Every sensor value the TX knows about is sent, like a DS-24 II does.
   The TX's own controls go out too, as two sensors of our own (see
   "TX controls" below), because a DS-24 II's BLE sends only sensors.

   Serial frames (see dfmBleESP lib/DfmLink/src/DfmLink.h):
     0xEE cmd fmt len payload [crc16] 0xBB
       len = the whole frame, numbers little-endian. fmt 0x20 = a CRC-16
       (system.crc, CRC-16/KERMIT) of 0xEE..payload follows, low byte first.
       Made by system.crc when the TX has it (firmware 5.04 on), else by a
       table-driven CRC in Lua; either must pass a self-check at start, or
       frames go out with fmt 0x00 and no CRC.
     0x20 Reset     version
     0x21 Model     "model_name;model_file"
     0x22 Describe  id(i4) param type dec labelLen label unitLen unit
     0x23 Values    id(i4) count, count x [param dec raw(i4)]
   The ESP32 answers with 0xFF 0xA2 0x00 0x06 code 0xAA:
     0x20 phone connected, 0x21 no phone, 0x22 phone receiving (these three
     also every 5 s as a heartbeat), 0x23 link error, 0x24 ESP32 started.

   Derived from DFM-HUD (serial set-up, sensor list, GPIO control).

   History:
     0.5  CRC-16 on serial frames via system.crc
     0.6  CRC-16 in Lua when the TX has no (working) system.crc
     0.7  TX controls (P1-P8) and up to 8 switches sent as two EX sensors
     0.8  those sensors move from EX 0xA400:1-2 to 0xA41F:0xDF01-0xDF02
     0.9  the TX's own timers 1-10 as a third sensor, 0xA41F:0xDF03
          (timer library, firmware 6.05 on, DC/DS-24 II only)
     0.10 TXs without the timer library (DS-24 I, older firmware) get two
          timers of DFM-BLE's own, on the same sensor

   -----------------------------------------------------------------------------
   Released under MIT license by DFM 2026
   -----------------------------------------------------------------------------

--]]

local appName = "DFM-BLE"
local appVersion = "0.10"

local HEAD, FOOT = 0xEE, 0xBB
local CMD_RESET, CMD_MODEL, CMD_DESCRIBE, CMD_VALUES = 0x20, 0x21, 0x22, 0x23
local PROTOCOL_VERSION = 1
local FMT_CRC = 0x20

local ST_CONNECTED, ST_NO_PHONE, ST_RECEIVING = 0x20, 0x21, 0x22
local ST_LINK_ERROR, ST_STARTED = 0x23, 0x24

local BAUD = 115200
local SEND_MS = 200         -- values, about JETI's sensor update rate
local DESCRIBE_MS = 10000   -- labels again, so a rebooted ESP32 recovers
local RESCAN_EMPTY_MS = 5000 -- look for sensors again while there are none
local ESP_TIMEOUT_MS = 12000 -- no heartbeat for this long: ESP32 not answering
local MAX_VALUES = 32       -- per sensor, the size of the ESP32's table
local MAX_LABEL, MAX_UNIT = 31, 7

-- TX controls: two sensors of our own. Sensor id = device << 16 |
-- manufacturer; the ESP32 splits it that way. 0xA400-0xA41F is the EX
-- spec's range for ALL third-party makers, so it isn't ours alone: we use
-- its top, 0xA41F, with devices 0xDF.. ("DF" for DFM), which no one is
-- likely to pick. If JETI assigns DFM a manufacturer id, only these
-- constants change (and the iOS app's).
--   0xDF01 "TX controls": P1-P8 as params 1-8
--   0xDF02 "TX switches": the switches picked in the menu, box i = param i
--   0xDF03 "TX timers": the TX's timers 1-10, param = timer number, in
--          seconds with 1 decimal (int22, signed). Read only, with JETI's
--          timer library (6.05 on, DC/DS-24 II only; absent elsewhere).
-- The params are fixed (P3 is always param 3, even when P2 is missing)
-- because the iOS app links its variables by sensor + param. EX value ids
-- above 15 need an escape that is untested, so each sensor stays below 16.
-- On the TX (32-bit integers) these are negative; they still pack to the
-- right 4 bytes, 1F A4 01 DF and 1F A4 02 DF.
local CTL_PROP_ID, CTL_SWITCH_ID = 0xDF01A41F, 0xDF02A41F
local CTL_TIMER_ID = 0xDF03A41F
local CTL_PIDS = {[string.pack("<I4", CTL_PROP_ID)] = true,
		  [string.pack("<I4", CTL_SWITCH_ID)] = true,
		  [string.pack("<I4", CTL_TIMER_ID)] = true}
local N_TIMER = 10              -- native timers are ids 1-10 (11-20 are Lua's)
local TIMER_TYPE, TIMER_DEC = 4, 1 -- int22, tenths of a second
-- Without the timer library, DFM-BLE keeps timers of its own (as DFM-HUD
-- did) and sends them on the same sensor as params 1-2, so the iOS app
-- can't tell the difference. Set OWN_TIMERS_TEST to use them on a 24 II.
local N_OWN = 2
local OWN_TIMERS_TEST = false
local N_PROP, N_SWITCH = 8, 8
local CTL_TYPE, CTL_DEC = 1, 1 -- int14 with one decimal: -100.0 to 100.0 %

local emulator = false
local crcFn          -- function(data) -> CRC-16, or nil for no CRC; set in init
local crcSource = ""  -- "system.crc" or "Lua", for the console and status
local sid             -- serial port id, nil when closed
local portName
local sensors = {}    -- {id=, name=, values={{param=, label=, unit=, dec=, type=}}}
local sensorKey = ""  -- the sensor list as a string, to notice changes
local nValues = 0
local nReal = 0       -- real sensors (not TX controls), to rescan while none
local ctlOn = true    -- send the TX controls
local ctlSwitches = {} -- [i] = SwitchItem from the menu's switch box i, or nil
local timerEntry      -- the "TX timers" sensor, or nil if there are none
local timerKey = ""   -- its timers and labels as a string, to notice changes
-- DFM-BLE's own timers: on, start (s), down, run and reset switches (saved),
-- and elapsed (ms, held while stopped), since (clock when it last started
-- running, nil while stopped)
local ownTimers = {}
local needReset = true
local rescanWanted = true -- read the sensor list on the next loop
local lastSend, lastDescribe, lastScan

local esp = {seen = nil, phone = ST_NO_PHONE, errors = 0, starts = 0}
local stats = {sent = 0, writeErrors = 0, valuesPerSec = 0}
local valueCount, valueCountStart = 0, 0

local rxBuf = ""
local gpioTimer = {}  -- pin -> time to end its pulse

--------------------------------------------------------------------------------
-- frames

-- CRC-16/KERMIT (polynomial 0x1021 reflected, init 0). system.crc runs in
-- the firmware, so it costs almost nothing from the Lua time budget. Older
-- TXs get a table-driven version in Lua: one lookup per byte, and frames
-- are short (a Values frame is 30-60 bytes). A bit-by-bit loop would cost
-- 8 times as much; that kind of CRC is what pushed DFM-Maps' IGC CRC over
-- its limit.
local crcTable

local function luaCrc16(data)
   if not crcTable then
      crcTable = {}
      for i = 0, 255 do
	 local c = i
	 for _ = 1, 8 do
	    if c & 1 == 1 then c = (c >> 1) ~ 0x8408 else c = c >> 1 end
	 end
	 crcTable[i + 1] = c
      end
   end
   local c = 0
   for i = 1, #data do
      c = (c >> 8) ~ crcTable[((c ~ data:byte(i)) & 0xFF) + 1]
   end
   return c
end

local function sysCrc16(data)
   return system.crc(data, 0, "crc16")
end

-- 0x2189 is CRC-16/KERMIT's check value, which the ESP32 computes too.
local function crcWorks(fn)
   local ok, c = pcall(fn, "123456789")
   return ok and c == 0x2189
end

local function chooseCrc()
   if system.crc and crcWorks(sysCrc16) then return sysCrc16, "system.crc" end
   if crcWorks(luaCrc16) then return luaCrc16, "Lua" end
   return nil, ""
end

local function frame(cmd, payload)
   if not crcFn then
      return string.char(HEAD, cmd, 0x00, #payload + 5) .. payload .. string.char(FOOT)
   end
   local body = string.char(HEAD, cmd, FMT_CRC, #payload + 7) .. payload
   local c = crcFn(body)
   return body .. string.char(c & 0xFF, (c >> 8) & 0xFF, FOOT)
end

local function send(str)
   if not sid then return end
   local cc = serial.write(sid, str)
   if cc then
      stats.sent = stats.sent + cc
   else
      stats.writeErrors = stats.writeErrors + 1
      if stats.writeErrors == 1 then
	 print(appName .. ": serial write failed: " .. tostring(select(2, serial.write(sid, ""))))
      end
   end
end

-- Lua's sensor id as 4 little-endian bytes, or nil if it isn't an integer
local function packId(id)
   local i = math.tointeger(id)
   if not i then return nil end
   return string.pack("<i4", i)
end

local function cut(str, n)
   str = str or ""
   if #str > n then return string.sub(str, 1, n) end
   return str
end

local function describeFrame(pid, param, exType, dec, label, unit)
   label, unit = cut(label, MAX_LABEL), cut(unit, MAX_UNIT)
   return frame(CMD_DESCRIBE,
		pid .. string.char(param, exType & 0xFF, dec & 0xFF, #label) ..
		   label .. string.char(#unit) .. unit)
end

local function round(x)
   if x >= 0 then return math.floor(x + 0.5) end
   return -math.floor(-x + 0.5)
end

-- The raw integer and decimals the EX protocol carries for one reading
local function rawValue(s)
   -- a whole number: under SensorE (json.decode) decimals arrive as 1.0
   local dec = math.floor(s.decimals or 0)
   if s.type == 9 then -- GPS: the coded value; decimals = N/S/E/W bits
      return s.valGPS, dec
   elseif s.type == 5 then -- time or date; decimals bit 0 = date
      if dec % 2 == 1 then
	 local yy = s.valYear
	 if yy >= 2000 then yy = yy - 2000 end
	 -- day at the top, year at the bottom: what JETI Studio Mobile reads
	 -- (the EX spec text says the reverse; tested 2026-11-22)
	 return (s.valDay << 16) | (s.valMonth << 8) | yy, dec
      end
      return (s.valHour << 16) | (s.valMin << 8) | s.valSec, dec
   end
   if dec > 3 then dec = 3 end -- EX carries at most 3 decimals
   return round(s.value * 10 ^ dec), dec
end

--------------------------------------------------------------------------------
-- sensors

-- Adds the TX controls sensors to the list; returns how many values
local function addControls(list, keys)
   if not ctlOn then return 0 end
   local prop = {id = CTL_PROP_ID, pid = string.pack("<I4", CTL_PROP_ID),
		 name = "TX controls", values = {}, ctl = "prop"}
   for i = 1, N_PROP do
      prop.values[i] = {param = i, label = "P" .. i, unit = "%", dec = CTL_DEC,
			type = CTL_TYPE}
   end
   list[#list + 1] = prop
   keys[#keys + 1] = "ctl"
   local sw = {id = CTL_SWITCH_ID, pid = string.pack("<I4", CTL_SWITCH_ID),
	       name = "TX switches", values = {}, ctl = "switch"}
   for i = 1, N_SWITCH do
      local item = ctlSwitches[i]
      local info = item and system.getSwitchInfo(item)
      -- unassigned boxes are left out; the others keep their param
      if info and info.assigned then
	 local label = (info.label and info.label ~= "") and info.label or ("Sw" .. i)
	 sw.values[#sw.values + 1] = {param = i, label = label, unit = "%",
				      dec = CTL_DEC, type = CTL_TYPE}
	 keys[#keys + 1] = "sw" .. i .. ":" .. label
      end
   end
   if #sw.values > 0 then list[#list + 1] = sw end
   return N_PROP + #sw.values
end

local function hasTimerLib()
   return timer and timer.getByID and not OWN_TIMERS_TEST
end

-- A switch box is on when its reading is above the middle. A timer with
-- no run switch always runs, as the TX's own timers do.
local function switchOn(item, default)
   if not item then return default end
   local v = system.getInputsVal(item)
   return v ~= nil and v > 0
end

-- Runs DFM-BLE's own timers: called every loop, so a switch flip counts at
-- once. Reset works while running too (it starts counting again from the
-- start time).
local function updateOwnTimers(now)
   for _, t in ipairs(ownTimers) do
      if t.on then
	 local run = switchOn(t.runSw, true)
	 if run and not t.since then
	    t.since = now
	 elseif not run and t.since then
	    t.elapsed, t.since = t.elapsed + (now - t.since), nil
	 end
	 if switchOn(t.resetSw, false) then
	    t.elapsed = 0
	    if t.since then t.since = now end
	 end
      end
   end
end

-- An own timer's time now in ms: counting down it goes negative past zero,
-- as the TX's timers do
local function ownTime(t, now)
   local e = t.elapsed + (t.since and (now - t.since) or 0)
   if t.down then return t.start * 1000 - e end
   return t.start * 1000 + e
end

-- Looks for the TX's timers (on the Describe cycle, so a new or renamed
-- timer shows up within 10 s). Swaps the "TX timers" sensor in the list
-- and returns true if anything changed.
local function scanTimers()
   local entry, keys = nil, {}
   if ctlOn and not hasTimerLib() then
      entry = {id = CTL_TIMER_ID, pid = string.pack("<I4", CTL_TIMER_ID),
	       name = "TX timers", values = {}, ctl = "timer"}
      for n, t in ipairs(ownTimers) do
	 if t.on then
	    entry.values[#entry.values + 1] = {param = n, label = "T" .. n, unit = "s",
					       dec = TIMER_DEC, type = TIMER_TYPE,
					       own = t}
	    keys[#keys + 1] = n .. ":own"
	 end
      end
      if #entry.values == 0 then entry = nil end
   elseif ctlOn and timer and timer.getByID then
      entry = {id = CTL_TIMER_ID, pid = string.pack("<I4", CTL_TIMER_ID),
	       name = "TX timers", values = {}, ctl = "timer"}
      for n = 1, N_TIMER do
	 local h = timer.getByID(n)
	 if h then
	    local name = timer.getName(h) or ""
	    local label = "T" .. n
	    if name ~= "" and name ~= label then label = label .. " " .. name end
	    entry.values[#entry.values + 1] = {param = n, label = label, unit = "s",
					       dec = TIMER_DEC, type = TIMER_TYPE,
					       handle = h}
	    keys[#keys + 1] = n .. ":" .. label
	 end
      end
      if #entry.values == 0 then entry = nil end
   end
   local key = table.concat(keys, ",")
   if key == timerKey then return false end
   for i = #sensors, 1, -1 do
      if sensors[i].ctl == "timer" then table.remove(sensors, i) end
   end
   if timerEntry then nValues = nValues - #timerEntry.values end
   timerEntry, timerKey = entry, key
   if entry then
      sensors[#sensors + 1] = entry
      nValues = nValues + #entry.values
      for _, v in ipairs(entry.values) do
	 print(string.format("%s: timer %d \"%s\" (%s)", appName, v.param, v.label,
			     v.own and "DFM-BLE's own" or tostring(timer.getType(v.handle))))
      end
   end
   return true
end

local function readSensors()
   local list, byId, keys, count = {}, {}, {}, 0
   for _, s in ipairs(system.getSensors()) do
      local pid = packId(s.id)
      -- a real sensor with one of our ids is dropped: ours win
      if pid and not CTL_PIDS[pid] then
	 local e = byId[s.id]
	 if not e then
	    e = {id = s.id, pid = pid, name = "", values = {}}
	    byId[s.id] = e
	    list[#list + 1] = e
	 end
	 if s.param == 0 then
	    e.name = s.label
	 elseif #e.values < MAX_VALUES then
	    e.values[#e.values + 1] = {param = s.param, label = s.label,
				       unit = s.unit, dec = math.floor(s.decimals or 0),
				       type = s.type}
	    keys[#keys + 1] = s.id .. ":" .. s.param .. ":" .. s.label
	    count = count + 1
	 end
      end
   end
   nReal = #list
   count = count + addControls(list, keys)
   if timerEntry then
      list[#list + 1] = timerEntry
      count = count + #timerEntry.values
   end
   local key = table.concat(keys, ",")
   if key ~= sensorKey then
      sensors, sensorKey, nValues = list, key, count
      needReset = true
      print(string.format("%s: %d sensors, %d values", appName, #list, count))
   end
end

local function sendReset()
   send(frame(CMD_RESET, string.char(PROTOCOL_VERSION)))
   local model = (system.getProperty("Model") or "") .. ";" ..
      (system.getProperty("ModelFile") or "")
   send(frame(CMD_MODEL, cut(model, 64)))
end

local function sendDescribes()
   for _, e in ipairs(sensors) do
      send(describeFrame(e.pid, 0, 0, 0, e.name, ""))
      for _, v in ipairs(e.values) do
	 send(describeFrame(e.pid, v.param, v.type or 0, v.dec or 0, v.label, v.unit))
      end
   end
end

-- A TX control's reading (-1 to 1) as raw, decimals and type, or nil
local function ctlRaw(x)
   if not x then return nil end
   return round(x * 1000), CTL_DEC, CTL_TYPE
end

local function sendValues(now)
   local props -- P1-P8, read once per round
   for _, e in ipairs(sensors) do
      local parts, n = {}, 0
      for _, v in ipairs(e.values) do
	 local raw, dec, typ
	 if e.ctl == "prop" then
	    props = props or {system.getInputs("P1", "P2", "P3", "P4",
					       "P5", "P6", "P7", "P8")}
	    raw, dec, typ = ctlRaw(props[v.param])
	 elseif e.ctl == "switch" then
	    -- the item from the menu now, in case it changed since the scan
	    local item = ctlSwitches[v.param]
	    raw, dec, typ = ctlRaw(item and system.getInputsVal(item))
	 elseif e.ctl == "timer" and v.own then
	    raw, dec, typ = round(ownTime(v.own, now) / 100), TIMER_DEC, TIMER_TYPE
	 elseif e.ctl == "timer" then
	    -- The API doc says "T", milliseconds without a lap id, but the
	    -- 6.06 emulator returns "R" with milliseconds (2026-11-26), so
	    -- either is taken as the time now in ms. It is the time the TX
	    -- shows: a count-down gives the time left, and goes negative
	    -- past zero; a stopped timer holds its time.
	    local kind, ms = timer.getRawTime(v.handle)
	    if (kind == "T" or kind == "R") and ms then
	       raw, dec, typ = round(ms / 100), TIMER_DEC, TIMER_TYPE
	    end
	 else
	    local s = system.getSensorByID(e.id, v.param)
	    if s and s.valid then
	       raw, dec = rawValue(s)
	       typ = s.type
	    end
	 end
	 v.lastRaw = nil -- what was sent, for the values page
	 raw = raw and math.tointeger(raw)
	 if raw then
	    n = n + 1
	    parts[n] = string.pack("<BBi4", v.param, dec & 0xFF, raw)
	    v.lastRaw, v.lastDec, v.lastType = raw, dec, typ
	 end
      end
      if n > 0 then
	 send(frame(CMD_VALUES, e.pid .. string.char(n) .. table.concat(parts)))
	 valueCount = valueCount + n
      end
   end
end

--------------------------------------------------------------------------------
-- replies from the ESP32

local function handleStatus(code)
   esp.seen = system.getTimeCounter()
   if code == ST_CONNECTED or code == ST_NO_PHONE or code == ST_RECEIVING then
      esp.phone = code
   elseif code == ST_LINK_ERROR then
      esp.errors = esp.errors + 1
   elseif code == ST_STARTED then
      esp.starts = esp.starts + 1
      needReset = true -- it has an empty table: send everything again now
   end
end

-- Finds 0xFF 0xA2 0x00 0x06 code 0xAA frames, skipping anything else (on
-- USB in the emulator, the ESP32's log text arrives on the same port).
local function onRead(data)
   rxBuf = rxBuf .. data
   while true do
      local i = string.find(rxBuf, "\xFF\xA2\x00\x06", 1, true)
      if not i then
	 if #rxBuf > 5 then rxBuf = string.sub(rxBuf, -5) end
	 return
      end
      if #rxBuf < i + 5 then
	 rxBuf = string.sub(rxBuf, i)
	 return
      end
      local code, foot = string.byte(rxBuf, i + 4, i + 5)
      rxBuf = string.sub(rxBuf, i + 6)
      if foot == 0xAA then handleStatus(code) end
   end
end

--------------------------------------------------------------------------------
-- serial port

local function choosePort()
   if not emulator then return "COM1" end
   local ports = serial.getPorts() or {}
   local saved = system.pLoad("port")
   for _, p in ipairs(ports) do if p == saved then return p end end
   for _, p in ipairs(ports) do if string.find(p, "ACM") then return p end end
   for _, p in ipairs(ports) do if string.find(p, "USB") then return p end end
   return ports[1]
end

local function openPort(name)
   if sid then
      serial.deinit(sid)
      sid = nil
   end
   portName = name
   if not name then return end
   local id, descr = serial.init(name, BAUD)
   if not id then
      print(appName .. ": cannot open " .. name .. ": " .. tostring(descr))
      return
   end
   sid = id
   local ok, err = serial.onRead(sid, onRead)
   if not ok then print(appName .. ": serial.onRead failed: " .. tostring(err)) end
   rxBuf = ""
   needReset = true
   print(appName .. ": serial port " .. name)
end

--------------------------------------------------------------------------------
-- GPIO lines to the ESP32 board (as in DFM-HUD)
--   6 -> ESP32 D0 = reboot, 5 -> ESP32 D2 = OTA: a 500 ms high pulse
--   7 -> board power: a 500 ms low pulse cycles it
-- Pins as DFM-HUD uses them with the HUD board. DFM-HUD's comment names
-- D2 for reboot, but the working HUD firmware restarts on D0 and starts
-- OTA on D2, so that comment has the pin names swapped.

local function pulse(pin, level)
   gpio.write(pin, level)
   gpioTimer[pin] = system.getTimeCounter() + 500
end

local function endPulses(now)
   for pin, t in pairs(gpioTimer) do
      if now - t >= 0 then
	 gpio.write(pin, pin == 7 and 1 or 0)
	 gpioTimer[pin] = nil
      end
   end
end

--------------------------------------------------------------------------------
-- status text

local function espText()
   if not sid then return "no serial port" end
   if not esp.seen then return "no reply yet" end
   local age = system.getTimeCounter() - esp.seen
   if age > ESP_TIMEOUT_MS then
      return string.format("no reply for %d s", age // 1000)
   end
   if esp.errors > 0 then return string.format("OK, %d errors", esp.errors) end
   return "OK"
end

local function phoneText()
   if not esp.seen then return "-" end
   if esp.phone == ST_RECEIVING then return "receiving" end
   if esp.phone == ST_CONNECTED then return "connected" end
   return "not connected"
end

--------------------------------------------------------------------------------
-- menu

local formPage = 1
local statusIds -- label ids of the live status rows while the menu is open
local lastStatus = 0

local function serialOutText()
   return string.format("%d bytes, %d errors%s", stats.sent, stats.writeErrors,
			crcFn and ", CRC" or "")
end
local function sendingText()
   return string.format("%d sensors, %d values", #sensors, nValues)
end
-- filled in below, once espText and phoneText exist
local statusRows

local function updateStatus(now)
   if not statusIds or now - lastStatus < 500 then return end
   lastStatus = now
   for i, r in ipairs(statusRows) do
      form.setProperties(statusIds[i], {label = r[2]()})
   end
end

local function closeForm()
   statusIds = nil
end
local valueTop = 1 -- first row shown on the values page

-- A value as it was sent, for the values page
local function valueText(v)
   local raw, dec = v.lastRaw, v.lastDec or 0
   if not raw then return "--" end
   if v.lastType == 5 then
      local a, b, c = (raw >> 16) & 0x1F, (raw >> 8) & 0xFF, raw & 0xFF
      if dec % 2 == 1 then return string.format("20%02d-%02d-%02d", c, b, a) end
      return string.format("%02d:%02d:%02d", a, b, c)
   elseif v.lastType == 9 then
      local nesw = {"N", "E", "S", "W"}
      return string.format("%d\194\176 %.3f' %s", (raw >> 16) & 0xFF,
			   (raw & 0xFFFF) * 0.001, nesw[(dec & 3) + 1])
   end
   local unit = (v.unit and v.unit ~= "") and (" " .. v.unit) or ""
   if dec == 0 then return string.format("%d", raw) .. unit end
   return string.format("%." .. dec .. "f", raw / 10 ^ dec) .. unit
end

-- Rows for the values page: a heading per sensor, then its values.
-- DFM-BLE's own sensors (TX controls, switches, timers) first, as the iOS
-- app lists them.
local function valueRows()
   local rows = {}
   local function add(e)
      rows[#rows + 1] = {head = (e.name ~= "" and e.name or "(no name)")}
      for _, v in ipairs(e.values) do
	 rows[#rows + 1] = {label = v.label, text = valueText(v)}
      end
   end
   for _, e in ipairs(sensors) do if e.ctl then add(e) end end
   for _, e in ipairs(sensors) do if not e.ctl then add(e) end end
   return rows
end

local SCROLL_W = 4 -- the scroll bar at the right edge

-- A scroll bar when the rows don't all fit: the thumb's size and place
-- show how much of the list is on screen
local function drawScrollBar(w, h, top, fit, total)
   if total <= fit then return end
   local x = w - SCROLL_W
   lcd.drawRectangle(x, 0, SCROLL_W, h)
   local th = math.max(8, h * fit // total)
   local ty = (h - th) * (top - 1) // (total - fit)
   lcd.drawFilledRectangle(x, ty, SCROLL_W, th)
end

local function printForm(w, h)
   if formPage ~= 2 then return end
   local rows = valueRows()
   if #rows == 0 then
      lcd.drawText(4, 4, "No sensors yet", FONT_NORMAL)
      return
   end
   local fh = lcd.getTextHeight(FONT_NORMAL)
   local fit = h // fh
   if valueTop > #rows - fit + 1 then valueTop = math.max(1, #rows - fit + 1) end
   drawScrollBar(w, h, valueTop, fit, #rows)
   for i = 0, fit - 1 do
      local r = rows[valueTop + i]
      if not r then break end
      local y = i * fh
      if r.head then
	 lcd.drawText(4, y, r.head, FONT_BOLD)
      else
	 lcd.drawText(16, y, r.label, FONT_NORMAL)
	 lcd.drawText(w - 4 - SCROLL_W - lcd.getTextWidth(FONT_NORMAL, r.text), y, r.text,
		      FONT_NORMAL)
      end
   end
end

local function keyForm(key)
   if formPage == 1 then return end
   if key == KEY_ESC or key == KEY_5 then
      form.preventDefault()
      form.reinit(formPage == 4 and 3 or 1) -- Timers is under TX controls
   elseif key == KEY_UP then
      valueTop = math.max(1, valueTop - 1)
   elseif key == KEY_DOWN then
      valueTop = valueTop + 1
   end
end

statusRows = {{"ESP32", espText}, {"Phone", phoneText},
	      {"Serial out", serialOutText}, {"Sending", sendingText}}

local function initForm(sub)
   formPage = sub or 1
   statusIds = nil
   if formPage == 2 then
      form.setTitle("Values sent")
      form.setButton(5, "Back", ENABLED)
      return
   end
   if formPage == 3 then
      form.setTitle("TX controls")
      form.setButton(5, "Back", ENABLED)
      form.addRow(2)
      form.addLabel({label = "Send TX controls", width = 220})
      local box
      box = form.addCheckbox(ctlOn, function(value)
	    ctlOn = not value
	    form.setValue(box, ctlOn)
	    system.pSave("ctlOn", ctlOn and 1 or 0)
	    rescanWanted = true
      end)
      form.addRow(1)
      form.addLabel({label = "Sends P1-P8, plus these switches:", font = FONT_MINI})
      for i = 1, N_SWITCH do
	 form.addRow(2)
	 form.addLabel({label = "Switch " .. i})
	 form.addInputbox(ctlSwitches[i], true, function(item)
	       ctlSwitches[i] = item
	       system.pSave("ctlSw" .. i, item)
	       rescanWanted = true
	 end)
      end
      if not hasTimerLib() then
	 form.addRow(1)
	 form.addLink(function() form.reinit(4) end, {label = "Timers >>"})
      end
      return
   end
   if formPage == 4 then
      form.setTitle("Timers")
      form.setButton(5, "Back", ENABLED)
      form.addRow(1)
      form.addLabel({label = "This TX has no timers for Lua: DFM-BLE's own",
		     font = FONT_MINI})
      for n, t in ipairs(ownTimers) do
	 local function save(key, value) system.pSave("tm" .. n .. key, value) end
	 form.addRow(2)
	 form.addLabel({label = "Timer " .. n, font = FONT_BOLD, width = 220})
	 local box
	 box = form.addCheckbox(t.on, function(value)
	       t.on = not value
	       form.setValue(box, t.on)
	       save("On", t.on and 1 or 0)
	       needReset = true -- describe the change at once
	 end)
	 form.addRow(5)
	 form.addLabel({label = "Start", width = 80})
	 form.addIntbox(t.start // 60, 0, 99, 0, 0, 1, function(v)
	       t.start = v * 60 + t.start % 60
	       save("Start", t.start)
	 end, {width = 70})
	 form.addLabel({label = "min", width = 40})
	 form.addIntbox(t.start % 60, 0, 59, 0, 0, 1, function(v)
	       t.start = t.start - t.start % 60 + v
	       save("Start", t.start)
	 end, {width = 70})
	 form.addLabel({label = "s", width = 30})
	 form.addRow(2)
	 form.addLabel({label = "Counts"})
	 form.addSelectbox({"up", "down"}, t.down and 2 or 1, false, function(i)
	       t.down = i == 2
	       save("Down", t.down and 1 or 0)
	 end)
	 form.addRow(2)
	 form.addLabel({label = "Run switch (none: always)"})
	 form.addInputbox(t.runSw, true, function(item)
	       t.runSw = item
	       save("Run", item)
	 end)
	 form.addRow(2)
	 form.addLabel({label = "Reset switch"})
	 form.addInputbox(t.resetSw, true, function(item)
	       t.resetSw = item
	       save("Reset", item)
	 end)
      end
      return
   end
   form.setTitle(appName) -- the sub-pages change it
   rescanWanted = true -- opening the menu also picks up new sensors

   form.addRow(1)
   form.addLink(function()
	 valueTop = 1
	 form.reinit(2)
   end, {label = "Values sent >>"})

   form.addRow(1)
   form.addLink(function() form.reinit(3) end, {label = "TX controls >>"})

   if emulator then
      local ports = serial.getPorts() or {}
      local idx = 1
      for i, p in ipairs(ports) do if p == portName then idx = i end end
      form.addRow(2)
      form.addLabel({label = "Serial port"})
      form.addSelectbox(ports, idx, true, function(i)
			   openPort(ports[i])
			   system.pSave("port", ports[i])
      end)
   end

   statusIds = {}
   for i, r in ipairs(statusRows) do
      form.addRow(2)
      form.addLabel({label = r[1]})
      statusIds[i] = form.addLabel({label = r[2](), alignRight = true})
   end

   form.addRow(1)
   form.addLink(function()
	 pulse(6, 1)
	 system.messageBox("Rebooting ESP32")
   end, {label = "Reboot ESP32 >>"})

   form.addRow(1)
   form.addLink(function()
	 pulse(7, 0)
	 system.messageBox("Cycling ESP32 power")
   end, {label = "Cycle ESP32 power >>"})

   form.addRow(1)
   form.addLink(function()
	 pulse(5, 1)
	 system.messageBox("ESP32 OTA started")
   end, {label = "Start ESP32 OTA >>"})

   form.addRow(1)
   form.addLabel({label = appName .. " " .. appVersion, font = FONT_MINI,
		  alignRight = true})
end

--------------------------------------------------------------------------------
-- telemetry window

local function printTele(w, h)
   local line1 = "ESP32 " .. espText()
   local line2 = "Phone " .. phoneText()
   local line3 = string.format("%d values, %d/s", nValues, stats.valuesPerSec)
   if h < 40 then
      lcd.drawText(4, (h - lcd.getTextHeight(FONT_MINI)) // 2,
		   (esp.phone == ST_RECEIVING and "Phone receiving" or line1),
		   FONT_MINI)
      return
   end
   local fh = lcd.getTextHeight(FONT_NORMAL)
   lcd.drawText(4, 2, line1, FONT_NORMAL)
   lcd.drawText(4, 2 + fh, line2, FONT_NORMAL)
   lcd.drawText(4, 2 + 2 * fh, line3, FONT_NORMAL)
end

--------------------------------------------------------------------------------

local function loop()
   local now = system.getTimeCounter()
   endPulses(now)
   updateStatus(now)
   updateOwnTimers(now)
   if not sid then return end

   -- system.getSensors() only when needed: under SensorE in the emulator
   -- every call reloads SensorE's config (and prints its start-up lines)
   if rescanWanted or (nReal == 0 and now - lastScan >= RESCAN_EMPTY_MS) then
      readSensors()
      rescanWanted, lastScan = false, now
   end

   local describeDue = needReset or now - lastDescribe >= DESCRIBE_MS
   if describeDue and scanTimers() then needReset = true end
   if describeDue then
      if needReset then
	 sendReset()
	 needReset = false
      end
      sendDescribes()
      lastDescribe = now
   end

   if now - lastSend >= SEND_MS then
      lastSend = now
      sendValues(now)
   end

   if now - valueCountStart >= 1000 then
      stats.valuesPerSec = valueCount * 1000 // (now - valueCountStart)
      valueCount, valueCountStart = 0, now
   end
end

local function init()
   local _, emflag = system.getDeviceType()
   emulator = emflag ~= 0
   crcFn, crcSource = chooseCrc()
   ctlOn = system.pLoad("ctlOn", 1) == 1
   for i = 1, N_SWITCH do ctlSwitches[i] = system.pLoad("ctlSw" .. i) end
   for n = 1, N_OWN do
      local function load(key, default) return system.pLoad("tm" .. n .. key, default) end
      ownTimers[n] = {on = load("On", 0) == 1, start = load("Start", 0),
		      down = load("Down", 0) == 1, runSw = load("Run"),
		      resetSw = load("Reset"), elapsed = 0}
   end
   print(appName .. " " .. appVersion .. ": serial CRC " ..
	    (crcFn and ("on (" .. crcSource .. ")") or "off (failed its self-check)"))

   local now = system.getTimeCounter()
   -- relative to the clock, never to 0: the emulator's counter can start negative
   lastSend, lastDescribe, valueCountStart = now, now - DESCRIBE_MS, now
   lastScan = now - RESCAN_EMPTY_MS

   gpio.mode(5, "out-pp")
   gpio.mode(6, "out-pp")
   gpio.mode(7, "out-pp")
   gpio.write(5, 0)
   gpio.write(6, 0)
   gpio.write(7, 1) -- ESP32 board power on

   openPort(choosePort())

   system.registerForm(1, MENU_APPS, appName, initForm, keyForm, printForm,
		       closeForm)
   system.registerTelemetry(1, appName, 0, printTele)
end

local function destroy()
   if sid then serial.deinit(sid) end
   sid = nil
end

return {init = init, loop = loop, destroy = destroy, author = "DFM",
	version = appVersion, name = appName}
