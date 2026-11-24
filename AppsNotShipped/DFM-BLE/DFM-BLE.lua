--[[

   DFM-BLE.lua -- sends the transmitter's telemetry over serial to the
   dfmBleESP ESP32, which passes it on over Bluetooth LE in JETI's own
   format. JETI Studio Mobile on an iPhone (and later our own iOS app) then
   shows it as if it came from a DS-24 II.

   Every sensor value the TX knows about is sent, like a DS-24 II does.

   Serial frames (see dfmBleESP lib/DfmLink/src/DfmLink.h):
     0xEE cmd fmt len payload [crc16] 0xBB
       len = the whole frame, numbers little-endian. fmt 0x20 = a CRC-16
       (system.crc, CRC-16/KERMIT) of 0xEE..payload follows, low byte first.
       Sent when the TX has system.crc (firmware 5.04 on) and it passes a
       self-check at start; otherwise fmt 0x00 and no CRC.
     0x20 Reset     version
     0x21 Model     "model_name;model_file"
     0x22 Describe  id(i4) param type dec labelLen label unitLen unit
     0x23 Values    id(i4) count, count x [param dec raw(i4)]
   The ESP32 answers with 0xFF 0xA2 0x00 0x06 code 0xAA:
     0x20 phone connected, 0x21 no phone, 0x22 phone receiving (these three
     also every 5 s as a heartbeat), 0x23 link error, 0x24 ESP32 started.

   Derived from DFM-HUD (serial set-up, sensor list, GPIO control).

   -----------------------------------------------------------------------------
   Released under MIT license by DFM 2026
   -----------------------------------------------------------------------------

--]]

local appName = "DFM-BLE"
local appVersion = "0.5"

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

local emulator = false
local useCrc = false  -- set in init by checkCrc()
local sid             -- serial port id, nil when closed
local portName
local sensors = {}    -- {id=, name=, values={{param=, label=, unit=, dec=, type=}}}
local sensorKey = ""  -- the sensor list as a string, to notice changes
local nValues = 0
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

-- system.crc runs in the firmware, so a CRC on every frame costs almost
-- nothing from the Lua time budget (a CRC loop in Lua would not).
local function checkCrc()
   if not system.crc then return false end
   local ok, c = pcall(system.crc, "123456789", 0, "crc16")
   -- 0x2189 is CRC-16/KERMIT's check value, which the ESP32 computes
   return ok and c == 0x2189
end

local function frame(cmd, payload)
   if not useCrc then
      return string.char(HEAD, cmd, 0x00, #payload + 5) .. payload .. string.char(FOOT)
   end
   local body = string.char(HEAD, cmd, FMT_CRC, #payload + 7) .. payload
   local c = system.crc(body, 0, "crc16")
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

local function readSensors()
   local list, byId, keys, count = {}, {}, {}, 0
   for _, s in ipairs(system.getSensors()) do
      local pid = packId(s.id)
      if pid then
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

local function sendValues()
   for _, e in ipairs(sensors) do
      local parts, n = {}, 0
      for _, v in ipairs(e.values) do
	 local s = system.getSensorByID(e.id, v.param)
	 v.lastRaw = nil -- what was sent, for the values page
	 if s and s.valid then
	    local raw, dec = rawValue(s)
	    raw = math.tointeger(raw)
	    if raw then
	       n = n + 1
	       parts[n] = string.pack("<BBi4", v.param, dec & 0xFF, raw)
	       v.lastRaw, v.lastDec, v.lastType = raw, dec, s.type
	    end
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
			useCrc and ", CRC" or "")
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

-- Rows for the values page: a heading per sensor, then its values
local function valueRows()
   local rows = {}
   for _, e in ipairs(sensors) do
      rows[#rows + 1] = {head = (e.name ~= "" and e.name or "(no name)")}
      for _, v in ipairs(e.values) do
	 rows[#rows + 1] = {label = v.label, text = valueText(v)}
      end
   end
   return rows
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
   for i = 0, fit - 1 do
      local r = rows[valueTop + i]
      if not r then break end
      local y = i * fh
      if r.head then
	 lcd.drawText(4, y, r.head, FONT_BOLD)
      else
	 lcd.drawText(16, y, r.label, FONT_NORMAL)
	 lcd.drawText(w - 4 - lcd.getTextWidth(FONT_NORMAL, r.text), y, r.text,
		      FONT_NORMAL)
      end
   end
end

local function keyForm(key)
   if formPage ~= 2 then return end
   if key == KEY_ESC or key == KEY_5 then
      form.preventDefault()
      form.reinit(1)
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
   rescanWanted = true -- opening the menu also picks up new sensors

   form.addRow(1)
   form.addLink(function()
	 valueTop = 1
	 form.reinit(2)
   end, {label = "Values sent >>"})

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
   if not sid then return end

   -- system.getSensors() only when needed: under SensorE in the emulator
   -- every call reloads SensorE's config (and prints its start-up lines)
   if rescanWanted or (#sensors == 0 and now - lastScan >= RESCAN_EMPTY_MS) then
      readSensors()
      rescanWanted, lastScan = false, now
   end

   if needReset or now - lastDescribe >= DESCRIBE_MS then
      if needReset then
	 sendReset()
	 needReset = false
      end
      sendDescribes()
      lastDescribe = now
   end

   if now - lastSend >= SEND_MS then
      lastSend = now
      sendValues()
   end

   if now - valueCountStart >= 1000 then
      stats.valuesPerSec = valueCount * 1000 // (now - valueCountStart)
      valueCount, valueCountStart = 0, now
   end
end

local function init()
   local _, emflag = system.getDeviceType()
   emulator = emflag ~= 0
   useCrc = checkCrc()
   print(appName .. " " .. appVersion .. ": serial CRC " ..
	    (useCrc and "on" or "off (no system.crc, or it failed the check)"))

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
