local M = {}

function M.initCmd(F3G, initForm, keyForm, printTele, doubleTele, fullTele, resetFlight, logWriteCB)

   print(type(F3G), F3G)
   F3G.gpsP.zeroLatStr = system.pLoad("zeroLatString")
   F3G.gpsPzeroLngStr = system.pLoad("zeroLngString")

   print("#F3G.sens", #F3G.sens)
   
   for i in ipairs(F3G.sens) do
      local v = F3G.sens[i].var
      print("i, v", i, v)
      for k,v in pairs(F3G.sens[i]) do
	 print(k,v)
      end
      print("F3G.sens[v]", F3G.sens[v])
      if not F3G.sens[v] then F3G.sens[v] = {}; print("{}") end
      print("pLoad from", v.."Se", 0)
      F3G.sens[v].Se   = system.pLoad(v.."Se", 0)
      F3G.sens[v].SeId = system.pLoad(v.."SeId", 0)
      F3G.sens[v].SePa = system.pLoad(v.."SePa", 0)
   end
   
   for i in ipairs(F3G.ctl) do
      local v = F3G.ctl[i].var
      F3G.ctl[v] = system.pLoad(v.."Ctl")
   end

   F3G.gpsP.distAB = system.pLoad("distAB", 150)
   
   F3G.gpsP.rotA = system.pLoad("rotA", 0)
   F3G.gpsP.rotA = F3G.gpsP.rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   
   if F3G.gpsP.zeroLatString and F3G.gpsP.zeroLngString then
      F3G.gpsP.zeroPos = gps.newPoint(F3G.gpsP.zeroLatString, F3G.gpsP.zeroLngString)
   end

   --system.registerForm(1, MENU_APPS, "F3G", initForm, (function(x) return keyForm(x,foo) end), printTele)
   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm, printTele)
   system.registerTelemetry(1, "F3G Status", 2, doubleTele)
   system.registerTelemetry(2, "F3G Map", 4, fullTele)   

   for cn, cv in pairs(F3G.lv.luaCtl) do
      F3G.lv.luaCtl[cn] = system.registerControl(cv, F3G.lv.luaTxt[cn], cn)
   end
   
   F3G.lv.P = system.registerLogVariable("elePullTime", "ms", logWriteCB)
   F3G.lv.X = system.registerLogVariable("courseX", "m", logWriteCB)
   F3G.lv.Y = system.registerLogVariable("courseY", "m", logWriteCB)   
   F3G.lv.D = system.registerLogVariable("perpDistA", "m", logWriteCB)
   F3G.lv.T = system.registerLogVariable("beep", "s", logWriteCB)

   resetFlight()

   print("woohoo")
   return F3G
end

return M
