--[[
   JsonProbe: how does JETI's json library handle tables with holes, nil
   and null?

   DFM-Dial saves arrays that are sparse by design (no warning = nil), and
   sometimes its file gets a NULL that breaks reading it back. This app
   encodes and decodes the awkward cases once, in init(), and writes the
   results to Apps/JsonProbe/jsonprobe.out (and the console), so TestMitter's
   json can be made to match the real one.

   Lines:
     #,JsonProbe,version,firmware,device
     E,case,<json.encode result>          (or E,case,ERROR,<message>)
     D,case,<what json.decode returned>   (or D,case,ERROR,<message>)
     DONE
--]]

local appName = "JsonProbe"
local version = "1.0"
local outFile = "Apps/JsonProbe/jsonprobe.out"

local function out(...)
   local t = {...}
   for i = 1, #t do t[i] = tostring(t[i]) end
   local s = table.concat(t, ",")
   print(appName .. ": " .. s)
   local fh = io.open(outFile, "a")
   if fh then
      io.write(fh, s, "\n")
      io.close(fh)
   end
end

-- a readable dump of a decoded value: types, key types, nested tables
local function dump(v, depth)
   depth = depth or 0
   local t = type(v)
   if t == "table" then
      if depth > 3 then return "{...}" end
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local o = {}
      for _, k in ipairs(keys) do
	 o[#o + 1] = string.format("[%s %s]=%s", type(k), tostring(k), dump(v[k], depth + 1))
      end
      return "{" .. table.concat(o, " ") .. "} #" .. #v
   elseif t == "string" then
      return string.format("string %q", v)
   elseif t == "number" then
      return (math.type and math.type(v) or "number") .. " " .. tostring(v)
   else
      return t .. " " .. tostring(v)
   end
end

local function enc(name, v)
   local ok, r = pcall(json.encode, v)
   if ok then out("E", name, r) else out("E", name, "ERROR", r) end
end

local function dec(name, s)
   local ok, r = pcall(json.decode, s)
   if ok then out("D", name, dump(r)) else out("D", name, "ERROR", r) end
end

local function init()
   local fh = io.open(outFile, "w")
   if fh then io.close(fh) end
   out("#", appName, version, system.getVersion and system.getVersion() or "?",
       system.getDeviceType and system.getDeviceType() or "?")

   -- encode: arrays with holes, built the ways DFM-Dial builds them
   enc("full", {1.5, 2.5, 3.5, 4.5})
   enc("empty", {})
   enc("nil,5", {nil, 5.0})
   enc("1,nil,3", {1.0, nil, 3.0})
   enc("1,2,3,nil", {1.0, 2.0, 3.0, nil})
   local a = {}; a[2] = 5.0
   enc("[2]=5 only", a)
   local b = {}; b[4] = 7.0
   enc("[4]=7 only", b)
   local c = {1.0, 2.0, 3.0, 4.0}; c[2] = nil
   enc("4 then [2]=nil", c)
   local d = {1.0, 2.0, 3.0, 4.0}; d[4] = nil
   enc("4 then [4]=nil", d)
   local e = {1.0, 2.0, 3.0, 4.0}; e[1] = nil; e[2] = nil; e[3] = nil
   enc("4 then [1..3]=nil", e)
   enc("nested", {tele = {{w = {nil, 5.0}}, {w = {}}}})
   enc("int", {3})
   enc("bool", {true, false})
   enc("mixed keys", {1.0, x = 2.0})
   enc("string key 2", {["2"] = 5.0})

   -- decode: null in its spellings, and keys that look like numbers
   dec("[null,5]", "[null,5]")
   dec("[NULL,5]", "[NULL,5]")
   dec("[Null,5]", "[Null,5]")
   dec("{\"a\":null}", "{\"a\":null}")
   dec("{\"2\":5}", "{\"2\":5}")
   dec("[1,2,3]", "[1,2,3]")
   dec("[]", "[]")
   dec("{}", "{}")

   -- round trip of each hole case, as DFM-Dial does on the next start
   local f = {}; f[2] = 5.0
   local ok, s = pcall(json.encode, {w = f})
   if ok then dec("roundtrip [2]=5", s) else out("D", "roundtrip [2]=5", "ERROR", s) end
   ok, s = pcall(json.encode, {w = {nil, 5.0}})
   if ok then dec("roundtrip nil,5", s) else out("D", "roundtrip nil,5", "ERROR", s) end
   local g = {1.0, 2.0, 3.0, 4.0}; g[2] = nil
   ok, s = pcall(json.encode, {w = g})
   if ok then dec("roundtrip 4 then [2]=nil", s) else out("D", "roundtrip 4 then [2]=nil", "ERROR", s) end

   -- what json.null is, if there is one
   out("N", "json.null", type(json.null), tostring(json.null))
   out("DONE")
end

return {init = init, author = "DFM", version = version, name = appName}
