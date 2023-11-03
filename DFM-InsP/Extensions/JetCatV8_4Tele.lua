local M = {}

--JetCat ECU telem converter v 8.4 and upwards turbine codes:

--Off 0
--Wait for RPM 1
--Ignite 2
--Accelerate 3
--Stabilize 4
--Not used 5
--Learn LO 6
--Not used 7
--Slow Down 8
--Not used 9
--AutoOff 10
--Run (reg.) 11
--Acceleration Delay 12
--SpeedReg 13
--TwoShaftReg 14
--PreHeat1 15
--Preheat2  16
--Not used 17
--Not used 18
--Keros.FullOn 19
--Shutdown RC -1
--Over Temp -2
--IgnitionTimeout -3
--Acceleration Timeout -4
-- Acceleration Too Slow -5
--Over RPM -6
--Low RPM Off -7
--Low Battery -8--Auto Off -9
--Low Temp Off -10
--High temp Off -11
--Glow Plug defective -12
--WatchDog timer -13
--Failsafe Off -14
--Manual Off via GSU -15
--Battery Fail -16
--Temp sensor fail -17
--Fuel fail -18
--Prop Fail -19
--2nd engine fail -20
--2nd engine diff too high -21
--2nd engine no communication -22
--No oil -23
--Over current -24
--No fuel pump connected/found -25
--Wrong fuel pump connected -26
--Fuelpump comms error -27
--Out of fuel shutdown -28
--LoRPM shutdown (pump fail?) -29
--LoRPM shutdown (board failure?) -30
--StartClutch not decoupling -31
--ECU reboot due new engine -32
--Shutdown, no CANBus -33
--No RC pulse -34
--Rotor Blocked -35
--Safety Pin signal -36

local ecuMessage = {

   [0] = {
      ["text"] = "Off"
   },
   [1] = {
      ["text"] = "Wait for RPM"
   },
   [2] = {
      ["text"] = "Ignite"
   },
   [3] = {
      ["text"] = "Accelerate"
   },
   [4] = {
      ["text"] = "Stabilise"
   },
   [5] = {
      ["text"] = ""
   },
   [6] = {
      ["text"] = "LearnLO"
   },
   [7] = {
      ["text"] = ""
   },
   [8] = {
      ["text"] = "Slow Down"
   },
   [9] = {
      ["text"] = ""
   },
   [10] = {
      ["text"] = "Auto Off"
   },
   [11] = {
      ["text"] = "Run (reg.)"
   },
   [12] = {
      ["text"] = "Acceleration delay"
   },
   [13] = {
      ["text"] = "Speed Reg"
   },
   [14] = {
      ["text"] = "TwoShaftReg"
   },
   [15] = {
      ["text"] = "PreHeat 1"
   },
 [16] = {
      ["text"] = "PreHeat 2"
   },
 [19] = {
      ["text"] = "Keros FullOn"
   },
   [-1] = {
      ["text"] = "Shutdown by RC"
   },
   [-2] = {
      ["text"] = "Over Temp"
   },
   [-3] = {
      ["text"] = "Ignition TimeOut"
   },
   [-4] = {
      ["text"] = "Accel. TimeOut"
   },
   [-5] = {
      ["text"] = "Accel. TooSlow"
   },
   [-6] = {
      ["text"] = "Over RPM"
   },
   [-7] = {
      ["text"] = "LowRPM Off"
   },
   [-8] = {
      ["text"] = "Low Battery"
   },
   [-9] = {
      ["text"] = "Auto Off"
   },
   [-10] = {
      ["text"] = "LowTemp Off"
   },
   [-11] = {
      ["text"] = "Hi Temp Off"
   },
   [-12] = {
      ["text"] = "GlowPlug defective"
   },
   [-13] = {
      ["text"] = "WatchDog Timer"
   },
   [-14] = {
      ["text"] = "Failsafe Off"
   },
   [-15] = {
      ["text"] = "Manual Off by GSU"
   },
   [-16] = {
      ["text"] = "Power Fail"
   },
   [-17] = {
      ["text"] = "Temp Sensor fail"
   },
   [-18] = {
      ["text"] = "Fuel fail"
   },
   [-19] = {
      ["text"] = "Prop fail"
   },
   [-20] = {
      ["text"] = "2nd engine fail"
   },
   [-21] = {
      ["text"] = "2nd engine diff high"
   },
   [-22] = {
      ["text"] = "2nd engine no comms"
   },
   [-23] = {
      ["text"] = "No oil"
   },
   [-24] = {
      ["text"] = "Over Current"
   },
   [-25] = {
      ["text"] = "NoFuelPump found"
   },
   [-26] = {
      ["text"] = "WrongFuelPump"
   },
   [-27] = {
      ["text"] = "FuelPump comm error"
   },
   [-28] = {
      ["text"] = "OutOfFuel shutdown"
   },
   [-29] = {
      ["text"] = "LowRPM Shutdown"
   },
   [-30] = {
      ["text"] = "LowRPM shutdown"
   },
   [-31] = {
      ["text"] = "Clutch Fail"
   },
   [-32] = {
      ["text"] = "ECU reboot, new engine"
   },
   [-33] = {
      ["text"] = "No CAN Bus"
   },
   [-34] = {
      ["text"] = "No RC Pulse"
   },
   [-35] = {
      ["text"] = "Rotor Blocked"
   },
   [-36] = {
      ["text"] = "Safety Pin Signal"
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

