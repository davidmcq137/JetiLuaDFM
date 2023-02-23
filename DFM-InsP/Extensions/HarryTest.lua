local M = {}

local ecuMessage = {

   [-1]= {
      ["text"]= "Trim Low",
    },
   [0]= {
      ["text"]= "Code 0",
    },
   [1]= {
      ["text"]= "Run",
    }
}

function M.text(ptr, val)
   local ecuCode = val 
   if ecuCode and ecuMessage[ecuCode] then
      -- could take other actions here e.g. play wav files
      local msg = {ecuMessage[ecuCode].text}
      return msg
   else
      return "No message for status " .. tostring(val)
   end
end

return M

