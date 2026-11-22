local M = {}

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

function M.initVars(sens, ctl)

   for i in ipairs(ctl) do
      local v = ctl[i].var
      ctl[v] = system.pLoad(v.."Ctl")
   end
   
   local p1, p2
   p1, p2 = system.getInputs("P1", "P2")

   local forceTeleInit 

   if p1 < -0.8 and p2 < -0.8 then forceTeleInit = true else forceTeleInit = false end

   local gotSe = 0
   
   for i in ipairs(sens) do
      local v = sens[i].var
      if not sens[v] then sens[v] = {} end
      sens[v].Se = system.pLoad(v.."Se", 0)
      sens[v].SeId = system.pLoad(v.."SeId", 0)
      sens[v].SePa = system.pLoad(v.."SePa", 0)
      --print(i, sens[v].Se, sens[v].SeId, sens[v].SePa)
      if sens[v].SeId ~= "..." and sens[v].SeId ~= 0 and sens[v].SePa ~= 0 then gotSe = gotSe + 1 end
   end

   local zeroLatString, zeroLngString
   local gpsScale, rotA, zeroPos

   local jtext = io.readall(prefix() .. 'Apps/DFM-F3B/GPS.jsn')

   if jtext then
      local jj = json.decode(jtext)
      if jj then
	 system.messageBox("Reading globally saved GPS data")
	 zeroLatString = jj.zeroLatString
	 zeroLngString = jj.zeroLngString
	 gpsScale = jj.gpsScale / 1000.0
	 rotA = jj.rotA / 1000.0
      end
   else
      zeroLatString = nil
      zeroLngString = nil
      gpsScale = 1 
      rotA = nil
   end
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   if forceTeleInit then gotSe = 0 end
   return zeroLatString, zeroLngString, gpsScale, rotA, zeroPos, gotSe
   
end

return M
