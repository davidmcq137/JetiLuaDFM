local M = {}

function M.initCmd(F3G, TT, initForm, keyForm, printTele, virtualTele, resetFlight, logWriteCB)

   
   for i in ipairs(F3G.sens) do
      local v = F3G.sens[i].var
      if not F3G.sens[v] then F3G.sens[v] = {} end
      F3G.sens[v].Se   = system.pLoad(v.."Se", 0)
      --print("pLoad from", v.."Se", F3G.sens[v].Se)
      F3G.sens[v].SeId = system.pLoad(v.."SeId", 0)
      --print("pLoad from", v.."SeId", F3G.sens[v].SeId)
      F3G.sens[v].SePa = system.pLoad(v.."SePa", 0)
      --print("pLoad from", v.."Se", F3G.sens[v].SePa)
   end
   
   for i in ipairs(F3G.ctl) do
      local v = F3G.ctl[i].var
      F3G.ctl[v] = system.pLoad(v.."Ctl")
   end

   F3G.gpsP.distAB = system.pLoad("distAB", 150)
   print("distAB", F3G.gpsP.distAB)
   
   F3G.gpsP.rotA = system.pLoad("rotA", 0)
   F3G.gpsP.rotA = F3G.gpsP.rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   print("rotA", F3G.gpsP.rotA)
   
   F3G.gpsP.zeroLatStr = system.pLoad("zeroLatString")
   F3G.gpsP.zeroLngStr = system.pLoad("zeroLngString")

   if F3G.gpsP.zeroLatStr and F3G.gpsP.zeroLngStr then
      F3G.gpsP.zeroPos = gps.newPoint(F3G.gpsP.zeroLatStr, F3G.gpsP.zeroLngStr)
   end

   F3G.flightMode = system.pLoad("flightMode", 3) -- start out basic by default

   --system.registerForm(1, MENU_APPS, "F3G", initForm, (function(x) return keyForm(x,foo) end), printTele)
   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm, printTele)
   system.registerTelemetry(1, "F3G Status", 2, (function(x) return virtualTele(TT, 2) end))
   system.registerTelemetry(2, "F3G Map", 4, (function(x) return virtualTele(TT, 4) end))

   for cn, cv in pairs(F3G.lv.luaCtl) do
      F3G.lv.luaCtl[cn] = system.registerControl(cv, F3G.lv.luaTxt[cn], cn)
   end
   
   F3G.lv.P = system.registerLogVariable("elePullTime", "ms", logWriteCB)
   F3G.lv.X = system.registerLogVariable("courseX", "m", logWriteCB)
   F3G.lv.Y = system.registerLogVariable("courseY", "m", logWriteCB)   
   F3G.lv.D = system.registerLogVariable("perpDistA", "m", logWriteCB)
   F3G.lv.T = system.registerLogVariable("beep", "s", logWriteCB)

   F3G.short150 = 0.0
   
   resetFlight()

   return F3G
end

return M
