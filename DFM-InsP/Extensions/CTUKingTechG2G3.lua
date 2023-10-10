local M = {}

-- CTU Kingtech turbine codes:
-- From Carsten's CTU Docs, engine type 0x06
-- 20200625 Digitech/Carsten G

--Trim Low 1536
--Ready 1537
--StickLo! 1538
--GlowTest 1539
--Start On 1540
--Ignition 1541
--Preheat 1542
--FuelRamp 1543
--Running 1544
--Stop 1545
--Cooling 1546
--GlowBad 1547
--StartBad 1548
--Low RPM 1549
--HighTemp 1550
--FlameOut 1551
--PrimeVap 1552
--Stage1 1553
--Stage2 1554
--Stage3 1555
--BurnerOn 1556
--Low Batt 1557
--SpeedLow 1558
--Restart 1559
--Glow Bad 1560

local ecuMessage = {

   [1536] = {
      ["text"] = "Trim Low"
   },
   [1537] = {
      ["text"] = "Ready"
   },
   [1538] = {
      ["text"] = "StickLo!"
   },
   [1539] = {
      ["text"] = "GlowTest"
   },
   [1540] = {
      ["text"] = "Start On"
   },
   [1541] = {
      ["text"] = "Ignition"
   },
   [1542] = {
      ["text"] = "Preheat"
   },
   [1543] = {
      ["text"] = "FuelRamp"
   },
   [1544] = {
      ["text"] = "Running"
   },
   [1545] = {
      ["text"] = "Stop"
   },
   [1546] = {
      ["text"] = "Cooling"
   },
   [1547] = {
      ["text"] = "GlowBad"
   },
   [1548] = {
      ["text"] = "StartBad"
   },
   [1549] = {
      ["text"] = "Low RPM"
   },
   [1550] = {
      ["text"] = "HighTemp"
   },
   [1551] = {
      ["text"] = "FlameOut"
   },
   [1552] = {
      ["text"] = "PrimeVap"
   },
   [1553] = {
      ["text"] = "Stage1"
   },
   [1554] = {
      ["text"] = "Stage2"
   },
   [1555] = {
      ["text"] = "Stage3"
   },
   [1556] = {
      ["text"] = "BurnerOn"
   },
   [1557] = {
      ["text"] = "Low Batt"
   },
   [1558] = {
      ["text"] = "SpeedLow"
   },
   [1559] = {
      ["text"] = "Restart"
   },
   [1560] = {
      ["text"] = "Glow Bad"
   }
}

function M.text(ptr, val)
   local ecuCode = val
   if not val or type(val) ~= "number" then return "Invalid: " .. tostring(val) end
   if ecuCode and ecuMessage[ecuCode] then
      -- could take other actions here e.g. play wav files
      local msg = {ecuMessage[ecuCode].text}
      return msg
   else
      return "Status " .. tostring(val)
   end
end

return M

