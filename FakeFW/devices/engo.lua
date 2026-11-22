--[[
   engo: FakeFW device model for DFM-HUD's serial port, standing for
   Russell's ESP32 bridge (~/rfmEngoESP: src/main.cpp, include/snooper.h)
   and the ActiveLook (Engo) glasses behind it.

   What HUD writes is split as the bridge's snooper does: FF .. AA frames
   are glasses commands (length on 1 or 2 bytes per the format byte), EE ..
   BB frames are private messages for the bridge (01 waitNext, 02 save the
   glasses serial, 03 forget it, 04 flush, 05 nop), other bytes are junk
   and skipped one at a time. Glasses replies follow the ActiveLook API
   (github.com/ActiveLook/Activelook-API-Documentation, ActiveLook_API.md):
     0xD3 cfgList  -> one entry per configuration on the glasses
     0xD0 cfgWrite -> remembered (name, version): the next cfgList shows it
     0xD2 cfgSet   -> the current configuration
     0x05 battery  -> FF 05 00 06 <level> AA
     0x06 vers     -> firmware 4.12.0, made 2024 week 1, serial 00 00 01
   A reply keeps the query ID of its command, as the glasses do. Every
   other command is accepted and counted. Bridge messages to HUD are
   FF A2 00 06 <code> AA: control values 1..6 from the glasses, 0x0a when
   the glasses disconnect, 0x0f on a touch.

   Use:  local engo = dofile("Apps/FakeFW/devices/engo.lua")
         local dev = engo.new{battery = 80, configs = {...}}
         FW.serialDevice("ttyUSB0", dev)
   Options: battery (0..100, default 85), configs (list of {name, version,
   size, system}; default one system config "ALooK"), connected (false: the
   bridge has no glasses, nothing answers; default true), events (list of
   {at = ms, disconnect = true} or {at = ms, control = n} or {at = ms,
   touch = true} or {at = ms, connect = true}), replyMs (delay from the
   command to its reply, default 30).
   dev.state() returns what the device saw, for UIDriver checks and reports.
--]]

local M = {}

local fmt = string.format

function M.new(o)
   o = o or {}
   local dev = {}
   local api
   local inbuf = ""
   local connected = o.connected ~= false
   local battery = o.battery or 85
   local replyMs = o.replyMs or 30
   local configs = {}
   for _, c in ipairs(o.configs or {{name = "ALooK", version = 1, size = 0, system = true}}) do
      configs[#configs + 1] = {name = c.name, version = c.version or 0, size = c.size or 0,
			       system = c.system and true or false, usg = 0, inst = 0}
   end
   local events = {}
   for _, e in ipairs(o.events or {}) do events[#events + 1] = e end
   table.sort(events, function(a, b) return a.at < b.at end)
   local pending = {}     -- {at, bytes}
   local st = {frames = 0, privates = 0, junk = 0, bad = 0, counts = {},
	       current = nil, writes = {}, lastWrite = nil}
   local instCount = 0

   local function queue(bytes, delay)
      pending[#pending + 1] = {at = api.now() + (delay or replyMs), bytes = bytes}
   end
   local function bridgeMsg(code)
      queue(string.char(0xFF, 0xA2, 0x00, 0x06, code, 0xAA), 0)
   end

   -- a glasses reply: FF id format length [query ID] data AA
   local function reply(id, qid, data)
      local n = 1 + 1 + 1 + 1 + #qid + #data + 1
      local s
      if n <= 255 then
	 s = string.char(0xFF, id, #qid) .. string.char(n)
      else
	 n = n + 1
	 s = string.char(0xFF, id, 0x10 | #qid) .. string.pack(">I2", n)
      end
      queue(s .. qid .. data .. string.char(0xAA))
   end

   local function cstr(data, i, max)
      local z = data:find("\0", i, true)
      local e = z and z - 1 or #data
      if max and e - i + 1 > max then e = i + max - 1 end
      return data:sub(i, e), (z or #data) + 1
   end

   local function glasses(cmd)
      local id, f = cmd:byte(2), cmd:byte(3)
      local lenSize = (f & 0x10) ~= 0 and 2 or 1
      local qn = f & 0x0F
      local qid = cmd:sub(4 + lenSize, 3 + lenSize + qn)
      local data = cmd:sub(4 + lenSize + qn, -2)
      st.frames = st.frames + 1
      st.counts[id] = (st.counts[id] or 0) + 1
      if not connected then return end
      if id == 0xD3 then
	 local parts = {}
	 for _, c in ipairs(configs) do
	    parts[#parts + 1] = c.name .. "\0" .. string.pack(">I4I4I1I1I1", c.size, c.version,
							      c.usg, c.inst, c.system and 1 or 0)
	 end
	 reply(0xD3, qid, table.concat(parts))
      elseif id == 0xD0 then
	 local name, i = cstr(data, 1, 12)
	 local version, password = 0, 0
	 if #data >= i + 7 then version, password = string.unpack(">I4I4", data, i) end
	 local c
	 for _, x in ipairs(configs) do if x.name == name then c = x end end
	 if not c then
	    c = {name = name, size = 0, system = false, usg = 0}
	    configs[#configs + 1] = c
	 end
	 instCount = instCount + 1
	 c.version, c.inst, c.password = version, instCount, password
	 st.writes[#st.writes + 1] = {name = name, version = version, at = api.now()}
	 st.lastWrite = name .. " v" .. version
      elseif id == 0xD2 then
	 local name = cstr(data, 1, 12)
	 st.current = name
	 for _, x in ipairs(configs) do
	    if x.name == name then instCount = instCount + 1; x.usg = instCount end
	 end
      elseif id == 0x05 then
	 reply(0x05, qid, string.char(battery))
      elseif id == 0x06 then
	 reply(0x06, qid, string.char(4, 12, 0, 0, 24, 1, 0, 0, 1))
      end
   end

   -- the bridge's snooper: frames out of the byte stream
   local function parse()
      while #inbuf > 0 do
	 local h = inbuf:byte(1)
	 if h ~= 0xFF and h ~= 0xEE then
	    st.junk = st.junk + 1
	    inbuf = inbuf:sub(2)
	 else
	    if #inbuf < 4 then return end
	    local f = inbuf:byte(3)
	    local n
	    if (f & 0x10) ~= 0 then
	       if #inbuf < 5 then return end
	       n = string.unpack(">I2", inbuf, 4)
	    else
	       n = inbuf:byte(4)
	    end
	    if n < 5 or n > 533 then
	       st.bad = st.bad + 1
	       api.log(fmt("bad length %d in frame %02X %02X, byte dropped", n, h, inbuf:byte(2)))
	       inbuf = inbuf:sub(2)
	    else
	       if #inbuf < n then return end
	       local cmd = inbuf:sub(1, n)
	       inbuf = inbuf:sub(n + 1)
	       local foot = cmd:byte(n)
	       if h == 0xEE then
		  st.privates = st.privates + 1
		  if foot ~= 0xBB then st.bad = st.bad + 1 end
	       elseif foot ~= 0xAA then
		  -- the glasses ignore it and report a message error
		  st.bad = st.bad + 1
		  api.log(fmt("frame %02X without AA footer (%d bytes)", cmd:byte(2), n))
		  if connected then bridgeMsg(3) end
	       else
		  glasses(cmd)
	       end
	    end
	 end
      end
   end

   function dev.attach(a) api = a end
   function dev.write(bytes)
      inbuf = inbuf .. bytes
      parse()
   end
   function dev.frame(now)
      while events[1] and events[1].at <= now do
	 local e = table.remove(events, 1)
	 if e.disconnect then
	    connected = false
	    bridgeMsg(0x0a)
	    api.log("glasses disconnected")
	 elseif e.connect then
	    connected = true
	    api.log("glasses connected")
	 elseif e.control then
	    bridgeMsg(e.control)
	 elseif e.touch then
	    bridgeMsg(0x0f)
	 end
      end
      local keep = {}
      for _, p in ipairs(pending) do
	 if p.at <= now then api.send(p.bytes) else keep[#keep + 1] = p end
      end
      pending = keep
   end
   function dev.state()
      local cfg = {}
      for _, c in ipairs(configs) do cfg[c.name] = c.version end
      local counts = {}
      for id, n in pairs(st.counts) do counts[fmt("x%02X", id)] = n end
      return {connected = connected, battery = battery, frames = st.frames,
	      privates = st.privates, junk = st.junk, bad = st.bad, current = st.current,
	      configs = cfg, counts = counts, writes = #st.writes, lastWrite = st.lastWrite}
   end
   function dev.summary()
      local ids = {}
      for id in pairs(st.counts) do ids[#ids + 1] = id end
      table.sort(ids)
      local parts = {}
      for _, id in ipairs(ids) do parts[#parts + 1] = fmt("%02X:%d", id, st.counts[id]) end
      return fmt("%d frames (%s), %d private, %d junk bytes, %d bad; current config %s; last cfgWrite %s",
		 st.frames, table.concat(parts, " "), st.privates, st.junk, st.bad,
		 tostring(st.current), tostring(st.lastWrite))
   end
   return dev
end

return M
