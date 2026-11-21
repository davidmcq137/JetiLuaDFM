--[[
   fakefw-uid: play an app's UIDriver script under FakeFW, unattended

   Loads UIDriver, a sensor app (SensorE by default) and the target app,
   opens the target's form at 1 s (the "human" of waitForm), and plays the
   script until UIDriver logs DONE or STOPPED. confirm steps are skipped
   (selection.jsn "unattended"), never passed: nobody is there to look.

   The run uses FakeFW's file layers: what it writes goes to a temp run
   folder, it reads a fixture (FakeFW/fixtures/<name>/, laid out like the
   SD card) and the files git doesn't ignore, so the pilot's working data
   (M-*.jsn, maps, logs, selection.jsn ...) is neither seen nor changed.

   Run from the parent of Apps (the Emulator folder):
     ~/lua-5.3.1-Jeti-typefix/src/lua Apps/FakeFW/fakefw-uid.lua \
        --app DFM-Maps --script maps-smoke.jsn --fixture maps-bds458 --model FakeFW
   --fixture takes several, comma-separated, e.g. maps-tri,maps-bds458: a
   file in an earlier one hides the same file in a later one (settings
   presets first, then the field data).
   Options: -p profile (default emu-ds24ii-606), --sensor SensorE|SensorL|none,
   --form <label pattern> (default the app), --minutes n (TX time, default 20),
   --model <name> (system.getProperty("Model")), --seed n, --keep (keep and
   print the run folder), --trace (log every file access), --out <file>
   (copy the result log there).
   Exit code 0 only when the script ends DONE with 0 FAIL and no app errored.
--]]

local FW = dofile("Apps/FakeFW/fakefw.lua")

local o = {profile = "emu-ds24ii-606", sensor = "SensorE", minutes = 20, seed = 1}
local i = 1
while i <= #arg do
   local a, v = arg[i], arg[i + 1]
   if a == "-p" then o.profile = v; i = i + 1
   elseif a == "--app" then o.app = v; i = i + 1
   elseif a == "--script" then o.script = v; i = i + 1
   elseif a == "--fixture" then   -- one, or several "a,b": the first wins
      o.fixture = {}
      for f in v:gmatch("[^,]+") do o.fixture[#o.fixture + 1] = f end
      i = i + 1
   elseif a == "--model" then o.model = v; i = i + 1
   elseif a == "--sensor" then o.sensor = v; i = i + 1
   elseif a == "--form" then o.form = v; i = i + 1
   elseif a == "--minutes" then o.minutes = tonumber(v); i = i + 1
   elseif a == "--seed" then o.seed = math.tointeger(tonumber(v)); i = i + 1
   elseif a == "--out" then o.out = v; i = i + 1
   elseif a == "--keep" then o.keep = true
   elseif a == "--trace" then o.trace = true
   else io.stderr:write("fakefw-uid: unknown option " .. a .. "\n"); os.exit(2) end
   i = i + 1
end
if not o.app or not o.script then
   io.stderr:write("usage: fakefw-uid.lua --app App --script script.jsn [--fixture name] [--model name] ...\n")
   os.exit(2)
end

local RESULT = "Apps/" .. o.app .. "/UIDriver/result.log"

local ok, code = pcall(function()
   FW.setup{profile = o.profile, seed = o.seed, fixture = o.fixture, sandbox = true,
	    model = o.model, keep = o.keep, trace = o.trace}
   FW.writeFile("Apps/UIDriver/selection.jsn", string.format(
      '{"app":"%s","script":"%s","mode":"play","unattended":true}', o.app, o.script))
   local names, init = {"UIDriver"}, {}
   if o.sensor ~= "none" then names[#names + 1] = o.sensor; init[#init + 1] = o.sensor end
   names[#names + 1] = o.app
   init[#init + 1] = "UIDriver"; init[#init + 1] = o.app
   FW.load(names)
   FW.initApps(init)

   local opened = false
   FW.onFrame(function(now)
      if not opened and now >= 1000 then
	 opened = true
	 if not FW.openForm(o.form or o.app) then FW.fail("can't open the form of " .. (o.form or o.app)) end
      end
   end)

   local nextCheck, done = 0, nil
   FW.run(o.minutes * 60 * 1000, function()
      if FW.now() < nextCheck then return false end
      nextCheck = FW.now() + 5000
      local s = FW.readFile(RESULT) or ""
      done = s:match("[=#]+ DONE:[^\n]*") or s:match("[=#]+ STOPPED[^\n]*")
      return done ~= nil
   end)
   local s = FW.readFile(RESULT) or ""
   if o.out then local f = assert(io.open(o.out, "wb")); f:write(s); f:close() end
   for l in s:gmatch("[^\n]+") do
      if l:find("^%s+FAILED ") or l:find("^%s+check failed") or l:find(" SKIP ") then print(l) end
   end
   if not done then
      FW.fail("UIDriver did not finish " .. o.script .. " in " .. o.minutes .. " TX minutes")
   else
      print(done)
      local fails = tonumber(done:match("(%d+) FAIL"))
      local checkFails = tonumber(done:match("(%d+) failed"))
      if not done:find("DONE") or fails ~= 0 or checkFails ~= 0 then FW.fail("UIDriver: " .. done) end
   end
   return FW.finish()
end)

if not ok then FW.cleanup(); print("fakefw-uid: " .. tostring(code)); os.exit(1) end
os.exit(code)
