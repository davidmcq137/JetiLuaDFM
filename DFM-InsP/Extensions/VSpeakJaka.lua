local M = {}

--Jakadofsky turbine codes:

--TH:stop 0
--TH:run 10 
--TH:rel 20
--TH:spin 30
--TH:fire 40
--TH:heat 50
--TH:acce 60
--TH:idle 70
--TH:lock -1
--TH:cool -10
--TH:off -20
--Error -30

--   [0]= {
--      ["text"]= "Stop",
--    },

local ecuMessage = {
   
   [0] = {
      ["text"] = "TH:stop"
   },
   [10] = {
      ["text"] = "TH:run"
   },
   [20] = {
      ["text"] = "TH:rel"
   },
   [30] = {
      ["text"] = "TH:spin"
   },
   [40] = {
      ["text"] = "TH:fire"
   },
   [50] = {
      ["text"] = "TH:heat"
   },
   [60] = {
      ["text"] = "TH:acce"
   },
   [70] = {
      ["text"] = "TH:idle"
   },
   [-1] = {
      ["text"] = "TH:lock"
   },
   [-10] = {
      ["text"] = "TH:cool"
   },
   [-20] = {
      ["text"] = "TH:off"
   },
   [-30] = {
      ["text"] = "Error -30"
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

