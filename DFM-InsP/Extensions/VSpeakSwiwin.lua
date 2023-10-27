local M = {}

--VSpeak Swiwin turbine codes:

--Off 0

--Stop 0 
--Cooling 1 
--TestGlowPlug 5 
--TestFuelValve 6 
--TestGasValve 7 
--TestPump 8 
--TestStarter 9 
--Ready 10 
--Ignition 11 
--Preheat 12 
--Fuelramp 13 
--Running 20 
--Restart 21 

--   [0] = {
--      ["text"] = "Off"
--   },

local ecuMessage = {

   [0] = {
      ["text"] = "Stop"
   },
   [1] = {
      ["text"] = "Cooling"
   },
   [5] = {
      ["text"] = "TestGlowPlug"
   },
   [6] = {
      ["text"] = "TestFuelValve"
   },
   [7] = {
      ["text"] = "TestGasValve"
   },
   [8] = {
      ["text"] = "TestPump"
   },
   [9] = {
      ["text"] = "TestStarter"
   },
   [10] = {
      ["text"] = "Ready"
   },
   [11] = {
      ["text"] = "Ignition"
   },
   [12] = {
      ["text"] = "Preheat"
   },
   [13] = {
      ["text"] = "Fuelramp"
   },
   [20] = {
      ["text"] = "Running"
   },
   [21] = {
      ["text"] = "Restart"
   }

}

function M.text(ptr, val)
   local msg
   local ecuCode = val
   --print("Input Val", val, type(val))
   if not val or type(val) ~= "number" then
      --print("error return", val, tostring(val))
      msg = {"Invalid:" .. tostring(val)}
      return msg
   end
   if ecuCode and ecuMessage[ecuCode] then
      -- could take other actions here e.g. play wav files
      msg = {ecuMessage[ecuCode].text}
      --print("normal return", msg)
      return msg
   elseif ecuCode and ecuCode < 0 then
      msg = {"Error: " .. tostring(ecuCode)}
      return msg
   else
      msg = {"Status: " .. tostring(val)}
      return msg
   end
end

return M

