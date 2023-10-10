local M = {}

-- VSpeak evoJet turbine codes:

--stop 0
--run 10
--rel 20
--glow 25
--spin 30
--fire 40
--ignt 45
--heat 50
--acce 60
--cal. 65
--idle 70
--lock -1
--cool -10
--off -20
--error -30

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
   [25] = {
      ["text"] = "TH:glow"
   },
   [30] = {
      ["text"] = "TH:spin"
   },
   [40] = {
      ["text"] = "TH:fire"
   },
   [45] = {
      ["text"] = "TH:ignt"
   },
   [50] = {
      ["text"] = "TH:heat"
   },
   [60] = {
      ["text"] = "TH:acce"
   },
   [65] = {
      ["text"] = "TH:cal."
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
      ["text"] = "TH:error"
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

