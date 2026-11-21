--[[
   fakefw-timg: play a DFM-TimG UIDriver script under FakeFW

   Loads UIDriver, SensorL and DFM-TimG on the emulator profile (UIDriver
   only runs when getDeviceType says emulator), opens DFM-TimG's form at
   1 s (the "human" of waitForm), stands in for DFM-HUD's "hudTimG" hook,
   and plays the script until UIDriver logs DONE or 20 minutes pass.
   Exit code 0 only when the script ends with 0 FAIL and no app errored.

   Run from the parent of Apps, with the JETI-like Lua:
     ~/lua-5.3.1-Jeti-typefix/src/lua Apps/FakeFW/fakefw-timg.lua [script.jsn]
   (default timg-test.jsn; also hud-test.jsn). It writes the script choice
   to Apps/UIDriver/selection.jsn for the run and puts the old file back
   afterwards; the result is in Apps/DFM-TimG/UIDriver/result.log.

   Acceptance (2026-11-21): timg-test 26 PASS 0 FAIL, hud-test 18 PASS
   0 FAIL, the same as the emulator.
--]]

local FW = dofile("Apps/FakeFW/fakefw.lua")

local script = arg[1] or "timg-test.jsn"
local SEL = "Apps/UIDriver/selection.jsn"
local RESULT = "Apps/DFM-TimG/UIDriver/result.log"

local function readFile(p)
   local f = io.open(p, "rb")
   if not f then return nil end
   local s = f:read("a"); f:close(); return s
end
local function writeFile(p, s)
   local f = assert(io.open(p, "wb")); f:write(s); f:close()
end

local oldSel = readFile(SEL)
writeFile(SEL, string.format('{"app":"DFM-TimG","script":"%s","mode":"play"}', script))

local ok, code = pcall(function()
   FW.setup{profile = "emu-ds24ii-606", seed = 1}
   -- the real controls: sliders at fixed positions
   FW.controls = {P5 = -0.5, P6 = 0.1, SA = -1}
   FW.sensors = {
      {id = 3, param = 0, label = "MGPS"},
      {id = 3, param = 2, type = 9, label = "Latitude", value = 0, valid = true},
      {id = 3, param = 3, type = 9, label = "Longitude", value = 0, valid = true},
      {id = 3, param = 6, type = 1, label = "Altitude", value = 0, valid = true},
   }
   -- the question pop-up and the key box, as UIDriver draws them
   FW.onDrawText = function(x, y, t)
      if tostring(t):find("question in") then print(string.format("[LCD] T=%d %s", FW.now(), t)) end
   end

   FW.load{"UIDriver", "SensorL", "DFM-TimG"}
   -- TimG's init first: the order that used to break SensorL
   FW.initApps{"DFM-TimG", "SensorL", "UIDriver"}

   -- stand-in for DFM-HUD's hook
   local uid = FW.app("UIDriver").env.system.UIDriver
   assert(uid and uid.expose, "UIDriver did not set up system.UIDriver")
   uid.expose("hudTimG", function()
      local t = FW.superglobal("DFM_TimG")
      local function v(pa)
	 if type(t) ~= "table" then return nil end
	 if pa == 13 then return t.remaining or 0 end
	 return t.elapsed or 0
      end
      return {remaining = v(13), elapsed = v(14)}
   end)

   local opened = false
   FW.onFrame(function(now)
      if not opened and now >= 1000 then
	 opened = true
	 assert(FW.openForm("Geriatric"))
      end
   end)

   local nextCheck, done = 0, nil
   FW.run(20 * 60 * 1000, function()
      if FW.now() < nextCheck then return false end
      nextCheck = FW.now() + 5000
      local s = readFile(RESULT) or ""
      done = s:match("==== DONE:[^\n]*") or s:match("==== STOPPED[^\n]*")
      return done ~= nil
   end)
   local s = readFile(RESULT) or ""
   done = s:match("==== DONE:[^\n]*") or s:match("==== [^\n]*")
   local t = FW.superglobal("DFM_TimG")
   print(string.format("DFM_TimG at the end: elapsed=%s remaining=%s",
		       tostring(type(t) == "table" and t.elapsed), tostring(type(t) == "table" and t.remaining)))
   if not done then
      FW.fail("UIDriver did not finish the script")
   else
      print(done)
      local fails = tonumber(done:match("(%d+) FAIL"))
      if fails ~= 0 then FW.fail("UIDriver: " .. done) end
   end
   return FW.finish()
end)

if oldSel then writeFile(SEL, oldSel) end
if not ok then print("fakefw-timg: " .. tostring(code)); os.exit(1) end
os.exit(code)
