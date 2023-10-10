local M = {}

-- CTU Projet turbine codes:
-- From Carsten's CTU Docs, engine type 0x00
-- 20200625 Digitech/Carsten G

--Off 0
--Standby 1
--Auto 2
--Ignition 5
--Ramp Up 7
----- 8
--Slow Down 9
--Cool Down 10
--Calibrate 11
--Cal. Idle 12
--Gi Idle 13
----- 14
--Burner On 15
--Auto HHC 16
--Wait Acc 18
--Preheat 23
--Burn Out 25
--Steady 26

local ecuMessage = {

   [0] = {
      ["text"] = "Off"
   },
   [1] = {
      ["text"] = "Standby"
   },
   [2] = {
      ["text"] = "Auto"
   },
   [5] = {
      ["text"] = "Ignition"
   },
   [7] = {
      ["text"] = "Ramp Up"
   },
   [8] = {
      ["text"] = "---"
   },
   [9] = {
      ["text"] = "Slow Down"
   },
   [10] = {
      ["text"] = "Cool Down"
   },
   [11] = {
      ["text"] = "Calibrate"
   },
   [12] = {
      ["text"] = "Cal. Idle"
   },
   [13] = {
      ["text"] = "Gi Idle"
   },
   [14] = {
      ["text"] = "---"
   },
   [15] = {
      ["text"] = "Burner On"
   },
   [16] = {
      ["text"] = "Auto HHC"
   },
   [18] = {
      ["text"] = "Wait Acc"
   },
   [23] = {
      ["text"] = "Preheat"
   },
   [25] = {
      ["text"] = "Burn Out"
   },
   [26] = {
      ["text"] = "Steady"
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

