local M = {}

--Projet turbine codes:

--Dev. Delay -30
--Emergency -10
--Off 0
--Cool Down 10
--Slow Down 20
--Standby 30
--Prop Ignit 31
--Prop Heat 32
--Pump Start 33
--Burner On 34
--Fuel Ignit 35
--Fuel Heat 36
--Ramp Delay 37
--Ramp Up 38
--Steady 40
--Cal Idle 41
--Calibrate 42
--Wait Acc 43
--Go Idle 44
--Auto 50
--Auto HC 51

--   [0]= {
--      ["text"]= "Stop",
--    },

local ecuMessage = {
   
   [-30] = {
      ["text"] = "Dev. Delay"
   },
   [-10] = {
      ["text"] = "Emergency"
   },
   [0] = {
      ["text"] = "Off"
   },
   [10] = {
      ["text"] = "Cool Down"
   },
   [20] = {
      ["text"] = "Slow Down"
   },
   [30] = {
      ["text"] = "Standby"
   },
   [31] = {
      ["text"] = "Prop Ignit"
   },
   [32] = {
      ["text"] = "Prop Heat"
   },
   [33] = {
      ["text"] = "Pump Start"
   },
   [34] = {
      ["text"] = "Burner On"
   },
   [35] = {
      ["text"] = "Fuel Ignit"
   },
   [36] = {
      ["text"] = "Fuel Heat"
   },
   [37] = {
      ["text"] = "Ramp Delay"
   },
   [38] = {
      ["text"] = "Ramp Up"
   },
   [40] = {
      ["text"] = "Steady"
   },
   [41] = {
      ["text"] = "Cal Idle"
   },
   [42] = {
      ["text"] = "Calibrate"
   },
   [43] = {
      ["text"] = "Wait Acc"
   },
   [44] = {
      ["text"] = "Go Idle"
   },
   [50] = {
      ["text"] = "Auto"
   },
   [51] = {
      ["text"] = "Auto HC"
   }
}

function M.text(ptr, val)
   local ecuCode = val
   if not val or type(val) ~= "number" then return "Invalid:" .. tostring(val) end
   if ecuCode and ecuMessage[ecuCode] then
      -- could take other actions here e.g. play wav files
      local msg = {ecuMessage[ecuCode].text}
      return msg
   else
      return "Status" .. tostring(val)
   end
end

return M

