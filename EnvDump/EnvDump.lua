--[[
   EnvDump: write what a JETI Lua app can see, for TestMitter's device profiles

   In init: the firmware version and device, getTime/getDateTime/
   getTimeCounter (to pin down the getTime epoch), then every global that
   pairs(_G) lists, sorted by name: numbers with their value and math.type,
   tables with each member (numbers with values), so the constants (KEY_*,
   MENU_*, FONT_*, ...) and the visible libraries can be copied into TestMitter.

   Older firmware (DS-16 on 5.06) keeps the libraries and constants in ROM
   tables ("rotable") that pairs() doesn't list, and pairs() of one is an
   error that pcall doesn't catch. So EnvDump also looks up by name the
   globals and library members listed in EnvDump/probe.txt (the names seen
   on the emulator 6.06 and a DS-24 on 5.08; TestMX/test/envprobe.py makes
   it), and writes the ones pairs() missed as P (global) and PM (member)
   lines. Where pairs() sees everything there are none. A name _G[name]
   doesn't give is tried as compiled code too (load("return " .. name)),
   the lookup an app's own code does: 1.4 found nothing on the DS-16. The
   "check" and "probe" lines say what worked. On 5.06 _G["math"] finds
   the ROM table although rawget(_G, "math") is nil and _G has no
   metatable, so EnvDump's own tables are read with rawget only, in case
   that fallback applies to every table (1.5 wrote no P lines there).
   1.6 found the ROM libraries but none of their members by v[name], so a
   member v[name] doesn't give is tried as compiled "return lib.name" too,
   at most LOADS of those per loop call (compiling is slow).

   The DS-16 also has very little Lua memory, so the first loop writes the
   init lines, and each later loop reads 25 names from probe.txt and
   appends what it finds; nothing big is ever held at once.
   Output: Apps/EnvDump/envdump.out

   On a TX: unzip EnvDump.zip into the TX's Apps folder, add EnvDump in
   Applications (any model), wait a few seconds for "EnvDump: written" on
   the console, then copy Apps/EnvDump/envdump.out back.

   Coded by Claude Code with guidance from D. McQueeney
--]]

local outFile = "Apps/EnvDump/envdump.out"
local probeFile = "Apps/EnvDump/probe.txt"
local BATCH = 25
local LOADS = 8

local function val(v)
   if type(v) == "number" then
      return string.format("%s %.9g", math.type and math.type(v) or "number", v)
   end
   return type(v)
end

-- only plain tables: pairs() of a ROM table is an uncatchable error on 5.06
local function keys(t)
   local ks = {}
   if type(t) ~= "table" then return ks, false end
   local ok = pcall(function() for k in pairs(t) do ks[#ks+1] = tostring(k) end end)
   table.sort(ks)
   return ks, ok
end

local function get(t, k)
   local ok, v = pcall(function() return t[k] end)
   if ok then return v end
end

local function scalar(v)
   local t = type(v)
   return t == "number" or t == "string" or t == "boolean" or t == "function"
end

local lines = {}
local function w(...) lines[#lines+1] = table.concat({...}, " ") end

-- append the lines so far to the output, one write per line
local nLines = 0
local function flush(mode)
   local fh = io.open(outFile, mode)
   if not fh then print("EnvDump: could not open " .. outFile); return false end
   for i = 1, #lines do io.write(fh, lines[i], "\n") end
   io.close(fh)
   nLines = nLines + #lines
   lines = {}
   return true
end

local listed = {}        -- globals pairs(_G) listed
local found = {}         -- libraries found by name: lib -> value
local curLib, have       -- members pairs() listed for the library being probed
local np = 0
local nRead, nIndex, nLoad = 0, 0, 0   -- probe.txt lines; found by _G[k], by load
local nG, nM, nMfound = 0, 0, 0        -- G and M lines handled; members found
local nMload, batchLoads = 0, 0        -- members found by load; loads this call

-- a library member by name: v[name], else compiled "return lib.name"
local function member(v, lib, name)
   local mv = get(v, name)
   if mv ~= nil then return mv end
   if not (lib:match("^[%a_][%w_]*$") and name:match("^[%a_][%w_]*$")) then return nil end
   batchLoads = batchLoads + 1
   local f = load("return " .. lib .. "." .. name)
   if not f then return nil end
   local ok, r = pcall(f)
   if ok and r ~= nil then nMload = nMload + 1; return r end
end

-- a global by name: _G[k], else compiled "return k"
local function global(k)
   local v = get(_G, k)
   if v ~= nil then nIndex = nIndex + 1; return v end
   if not k:match("^[%a_][%w_]*$") then return nil end
   batchLoads = batchLoads + 1
   local f = load("return " .. k)
   if not f then return nil end
   local ok, r = pcall(f)
   if ok and r ~= nil then nLoad = nLoad + 1; return r end
end
local pf                 -- probe.txt, open while probing
local state = "write"    -- write -> probe -> done

local function init()
   w("version", tostring(system.getVersion()))
   local dev, emu = system.getDeviceType()
   w("device", tostring(dev), tostring(emu))
   w("_VERSION", tostring(_VERSION))
   w("getTime", val(system.getTime()), tostring(system.getTime()))
   w("getTimeCounter", val(system.getTimeCounter()))
   local dt = system.getDateTime()
   local dk = keys(dt)
   for _, k in ipairs(dk) do w("getDateTime", k, tostring(dt[k])) end
   if os and os.time then w("os.time", tostring(os.time())) end
   w("maxinteger", tostring(math.maxinteger))
   local gk, gok = keys(_G)
   w("globals", #gk, tostring(gok))
   for _, k in ipairs(gk) do
      rawset(listed, k, true)
      local v = _G[k]
      w("G", k, val(v))
      if type(v) == "table" and k ~= "_G" and k ~= "package" then
	 local mk, ok = keys(v)
	 if not ok then w("M", k, "(pairs failed)") end
	 for _, m in ipairs(mk) do w("M", k .. "." .. m, val(v[m])) end
      end
   end
   if package then w("package.path", tostring(package.path)) end
   -- how globals resolve: plain code, _G indexing, _ENV, a metatable
   w("check", "math", type(math), type(get(_G, "math")), type(rawget(_G, "math")),
     "env==G", tostring(_ENV == _G), "mt", type(getmetatable(_G)))
   -- does a missing key in any plain table fall back to the ROM tables?
   local empty = {}
   w("check", "plain", type(empty.math), type(empty.KEY_1), type(empty.abs))
   -- a ROM table's member: in code, by a variable key, through _G[name]
   local k, lib = "floor", "math"
   w("check", "member", type(math.floor), type(get(math, k)),
     type(get(get(_G, lib), k)), "same", tostring(rawequal(math, get(_G, lib))))
end

-- one probe.txt line: "G name" or "M lib member"
local function probeLine(l)
   local kind, a, b = l:match("^(%a)%s+(%S+)%s*(%S*)")
   if kind == "G" then
      nG = nG + 1
      local v = global(a)
      if v == nil then return end
      if not rawget(listed, a) then w("P", a, val(v)); np = np + 1 end
      if not scalar(v) and a ~= "package" then rawset(found, a, v) end
   elseif kind == "M" then
      nM = nM + 1
      local v = rawget(found, a)
      if v == nil then return end
      if curLib ~= a then
	 -- a new library: what pairs() lists for it (plain tables only)
	 curLib, have = a, {}
	 local mk = keys(v)
	 for _, m in ipairs(mk) do
	    rawset(have, m, true)
	    if not rawget(listed, a) then w("M", a .. "." .. m, val(get(v, m))) end
	 end
      end
      local mv = member(v, a, b)
      if mv ~= nil then nMfound = nMfound + 1 end
      if mv ~= nil and not rawget(have, b) then
	 w("PM", a .. "." .. b, val(mv)); np = np + 1
      end
   end
end

local function finish()
   if pf then io.close(pf); pf = nil end
   w("probe", "read", nRead, "byIndex", nIndex, "byLoad", nLoad,
     "G", nG, "M", nM, "Mfound", nMfound, "MbyLoad", nMload, "new", np)
   if np > 0 then w("probed", np) end
   flush("a")
   print("EnvDump: written " .. outFile .. " (" .. nLines .. " lines)")
   state = "done"
end

local function loop()
   if state == "done" then return end
   if state == "write" then
      if not flush("w") then state = "done"; return end
      pf = io.open(probeFile, "r")
      if not pf then
	 w("ERR", "no " .. probeFile)
	 finish()
	 return
      end
      state = "probe"
      return
   end
   -- probing: one batch per loop call; an error becomes an ERR line
   local ok, err = pcall(function()
      batchLoads = 0
      for _ = 1, BATCH do
	 if batchLoads >= LOADS then return end   -- the rest next call
	 local l = io.readline(pf, true)
	 if not l then return true end
	 nRead = nRead + 1
	 probeLine(l)
      end
   end)
   if not ok then
      w("ERR", "probe", tostring(err))
      finish()
   elseif err == true then
      finish()
   else
      flush("a")
   end
   collectgarbage()
end

return {init = init, loop = loop, author = "DFM", version = "1.7", name = "EnvDump"}
