local M = {}

--VSpeak AMT codes:

-- max rpm 7
-- running 6
-- auto stop 5
-- calibrated 4
-- started up 3
-- starting 2
-- start clearance 1
-- no start clearance 0
--  no serial input -1
--  rpm low error -2
--  switch fail -3
--  throttle fail -4
--  egt error -5
--  rpm high error -6
--  supply low error -7
--  supply ass low -8
--  error -20

local ecuMessage = {
   
   [7] = {
      ["text"] = "Max. RPM"
   },
   [6] = {
      ["text"] = "Running"
   },
   [5] = {
      ["text"] = "Auto stop"
   },
   [4] = {
      ["text"] = "Calibrated"
   },
   [3] = {
      ["text"] = "Started up"
   },
   [2] = {
      ["text"] = "Starting"
   },
   [1] = {
      ["text"] = "Start clearance"
   },
   [0] = {
      ["text"] = "No start clearance"
   },
   [-1] = {
      ["text"] = "No serial input"
   },
   [-2] = {
      ["text"] = "RPM low error"
   },
   [-3] = {
      ["text"] = "Switch fail"
   },
  [-4] = {
      ["text"] = "Throttle fail"
   },
  [-5] = {
      ["text"] = "EGT error"
   },
  [-6] = {
      ["text"] = "RPM high error"
   },
  [-7] = {
      ["text"] = "Supply low error"
   },
  [-8] = {
      ["text"] = "Supply ASS low"
   },
   [-20] = {
      ["text"] = "Error"
   }
}

function M.text(ptr, val)
   local msg
   local ecuCode = val
   --print("Input Val", val, type(val))
   if not val or type(val) ~= "number" then
      --print("error return", val, tostring(val))
      msg = {"Invalid: " .. tostring(val)}
      return msg
   end
   if ecuCode and ecuMessage[ecuCode] then
      -- could take other actions here e.g. play wav files
      msg = {ecuMessage[ecuCode].text}
      --print("normal return", msg, type(msg))
      return msg
   else
      msg = {"Status: " .. tostring(val)}
      return msg
   end
end

return M

