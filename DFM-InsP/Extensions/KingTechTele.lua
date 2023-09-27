local M = {}

--Kingtech turbine codes:

--ReStart 22 
--Running 20
--Stage 3 14
--Stage 2 13
--Stage 1 12
--Ignition 11
--Start On 10
--Burner On 9
--Prime Vap 8
--Stick Lo 7
--Glow Test 6
--Gd Ready 5
--Ready 4
--Cooling 3
--Stop 2
--User Off 1
--Trim Low 0
--Glow Bad 1
--Ign Fail 2
--Timeout 3
--Weak Gas 4
--Start Bad 5
--Low Batt 6
--Overload 7
--Rx Pw Fail 8
--Failsafe 9
--Speed Low 10
--Temp High 11
--Flame Out 12
--CAB Lost 13
--Unknown 19
--Error 20

local ecuMessage = {

   [22 ] = {
      ["text"] = "Re-Start"
   },
   [20] = {
      ["text"] = "Running"
   },
   [14] = {
      ["text"] = "Stage 3"
   },
   [13] = {
      ["text"] = "Stage 2"
   },
   [12] = {
      ["text"] = "Stage 1"
   },
   [11] = {
      ["text"] = "Ignition"
   },
   [10] = {
      ["text"] = "Start On"
   },
   [9] = {
      ["text"] = "Burner On"
   },
   [8] = {
      ["text"] = "Prime Vap"
   },
   [7] = {
      ["text"] = "Stick Lo"
   },
   [6] = {
      ["text"] = "Glow Test"
   },
   [5] = {
      ["text"] = "Gd Ready"
   },
   [4] = {
      ["text"] = "Ready"
   },
   [3] = {
      ["text"] = "Cooling"
   },
   [2] = {
      ["text"] = "Stop"
   },
   [1] = {
      ["text"] = "User Off"
   },
   [0] = {
      ["text"] = "Trim Low"
   },
   [-1] = {
      ["text"] = "Glow Bad"
   },
   [-2] = {
      ["text"] = "Ign Fail"
   },
   [-3] = {
      ["text"] = "Timeout"
   },
   [-4] = {
      ["text"] = "Weak Gas"
   },
   [-5] = {
      ["text"] = "Start Bad"
   },
   [-6] = {
      ["text"] = "Low Batt"
   },
   [-7] = {
      ["text"] = "Overload"
   },
   [-8] = {
      ["text"] = "Rx Pw Fail"
   },
   [-9] = {
      ["text"] = "Failsafe"
   },
   [-10] = {
      ["text"] = "Speed Low"
   },
   [-11] = {
      ["text"] = "Temp High"
   },
   [-12] = {
      ["text"] = "Flame Out"
   },
   [-13] = {
      ["text"] = "CAB Lost"
   },
   [-19] = {
      ["text"] = "Unknown"
   },
   [-20] = {
      ["text"] = "Error"
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

