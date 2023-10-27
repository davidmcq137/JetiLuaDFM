local M = {}

--JetCat turbine codes:

--Off 0
--Slow Down 1
--AutoOff 2
--Wait for RPM 3
--PreHeat1 4
--PreHeat2 5
--Ignite 6
--Accel Delay 7
--MainFStrt 8
--KeroFullOn 9
--Accelerate 10
--Stabilize 11
--Learn LO 12
--Run 13
--SpeedReg 14
--TwoShaftReg 15
--Shutdown RC -1
--Auto Off -2
--Manual Off -3

local ecuMessage = {

   [0] = {
      ["text"] = "Off"
   },
   [1] = {
      ["text"] = "Slow Down"
   },
   [2] = {
      ["text"] = "AutoOff"
   },
   [3] = {
      ["text"] = "Wait for RPM"
   },
   [4] = {
      ["text"] = "PreHeat1"
   },
   [5] = {
      ["text"] = "PreHeat2"
   },
   [6] = {
      ["text"] = "Ignite"
   },
   [7] = {
      ["text"] = "Accel Delay"
   },
   [8] = {
      ["text"] = "MainFStrt"
   },
   [9] = {
      ["text"] = "KeroFullOn"
   },
   [10] = {
      ["text"] = "Accelerate"
   },
   [11] = {
      ["text"] = "Stabilize"
   },
   [12] = {
      ["text"] = "Learn LO"
   },
   [13] = {
      ["text"] = "Run"
   },
   [14] = {
      ["text"] = "SpeedReg"
   },
   [15] = {
      ["text"] = "TwoShaftReg"
   },
   [-1] = {
      ["text"] = "Shutdown RC"
   },
   [-2] = {
      ["text"] = "Auto Off"
   },
   [-3] = {
      ["text"] = "Manual Off"
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
   elseif ecuCode and ecuCode < -3 then
      msg = {"Error: " .. tostring(ecuCode)}
      return msg
   else
      msg = {"Status: " .. tostring(val)}
      return msg
   end
end

return M

