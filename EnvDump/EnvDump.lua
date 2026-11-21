--[[
   EnvDump: write what a JETI Lua app can see, for FakeFW's device profiles

   In init, once: the firmware version and device, getTime/getDateTime/
   getTimeCounter (to pin down the getTime epoch), then every global sorted
   by name: numbers with their value and math.type, tables with each member
   (numbers with values), so the constants (KEY_*, MENU_*, FONT_*, ...) and
   the visible libraries can be copied into FakeFW.
   Output: Apps/EnvDump/envdump.out

   On a TX: unzip EnvDump.zip into the TX's Apps folder, add EnvDump in
   Applications (any model), wait a few seconds for "EnvDump: written" on
   the console, then copy Apps/EnvDump/envdump.out back. Init only collects
   the lines; the first loop writes them in one call, so neither callback
   comes near the CPU limit.
--]]

local outFile = "Apps/EnvDump/envdump.out"

local function val(v)
   if type(v) == "number" then
      return string.format("%s %.9g", math.type and math.type(v) or "number", v)
   end
   return type(v)
end

local function keys(t)
   local ks = {}
   local ok = pcall(function() for k in pairs(t) do ks[#ks+1] = tostring(k) end end)
   table.sort(ks)
   return ks, ok
end

local lines

local function init()
   lines = {}
   local function w(...) lines[#lines+1] = table.concat({...}, " ") end
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
      local v = _G[k]
      w("G", k, val(v))
      if type(v) == "table" and k ~= "_G" and k ~= "package" then
	 local mk, ok = keys(v)
	 if not ok then w("M", k, "(pairs failed)") end
	 for _, m in ipairs(mk) do w("M", k .. "." .. m, val(v[m])) end
      end
   end
   if package then w("package.path", tostring(package.path)) end
end

local function loop()
   if not lines then return end
   local fh = io.open(outFile, "w")
   if fh then
      io.write(fh, table.concat(lines, "\n"), "\n")
      io.close(fh)
      print("EnvDump: written " .. outFile .. " (" .. #lines .. " lines)")
   else
      print("EnvDump: could not open " .. outFile)
   end
   lines = nil
end

return {init = init, loop = loop, author = "DFM", version = "1.1", name = "EnvDump"}
