local M = {}

function M.initCmd(F3X, TT, initForm, keyForm, printTele, virtualTele, resetFlight, logWriteCB)

   
   for i in ipairs(F3X.sens) do
      local v = F3X.sens[i].var
      if not F3X.sens[v] then F3X.sens[v] = {} end
      F3X.sens[v].Se   = system.pLoad(v.."Se", 0)
      --print("pLoad from", v.."Se", F3X.sens[v].Se)
      F3X.sens[v].SeId = system.pLoad(v.."SeId", 0)
      --print("pLoad from", v.."SeId", F3X.sens[v].SeId)
      F3X.sens[v].SePa = system.pLoad(v.."SePa", 0)
      --print("pLoad from", v.."Se", F3X.sens[v].SePa)
   end
   
   for i in ipairs(F3X.ctl) do
      local v = F3X.ctl[i].var
      F3X.ctl[v] = system.pLoad(v.."Ctl")
   end

   F3X.gpsP.distAB = system.pLoad("distAB", 150)
   --print("distAB", F3X.gpsP.distAB)
   
   F3X.gpsP.rotA = system.pLoad("rotA", 0)
   F3X.gpsP.rotA = F3X.gpsP.rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   --print("rotA", F3X.gpsP.rotA)
   
   F3X.gpsP.zeroLatStr = system.pLoad("zeroLatString")
   F3X.gpsP.zeroLngStr = system.pLoad("zeroLngString")

   if F3X.gpsP.zeroLatStr and F3X.gpsP.zeroLngStr then
      F3X.gpsP.zeroPos = gps.newPoint(F3X.gpsP.zeroLatStr, F3X.gpsP.zeroLngStr)
   end

   F3X.width = 0
   F3X.depth = 0
   F3X.flightMode = system.pLoad("flightMode", 3) -- start out basic by default
   
   --system.registerForm(1, MENU_APPS, "F3X", initForm, (function(x) return keyForm(x,foo) end), printTele)
   system.registerForm(1, MENU_APPS, "F3X", initForm, keyForm, printTele)
   system.registerTelemetry(1, "F3X Status", 2, (function(x) return virtualTele(TT, 2) end))
   system.registerTelemetry(2, "F3X Map", 4, (function(x) return virtualTele(TT, 4) end))

   for cn, cv in pairs(F3X.lv.luaCtl) do
      F3X.lv.luaCtl[cn] = system.registerControl(cv, F3X.lv.luaTxt[cn], cn)
   end
   
   F3X.lv.P = system.registerLogVariable("elePullTime", "ms", logWriteCB)
   F3X.lv.X = system.registerLogVariable("courseX", "m", logWriteCB)
   F3X.lv.Y = system.registerLogVariable("courseY", "m", logWriteCB)   
   F3X.lv.D = system.registerLogVariable("perpDistA", "m", logWriteCB)
   F3X.lv.T = system.registerLogVariable("beep", "s", logWriteCB)
   F3X.lv.De = system.registerLogVariable("depth", "m", logWriteCB)
   F3X.lv.Wi = system.registerLogVariable("width", "m", logWriteCB)
   
   F3X.short150 = 0.0
   
   resetFlight()

   return F3X
end

return M
