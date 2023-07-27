local M = {}

--Swiwin turbine codes:

--Stop - 0
--Ready - 1
--Ignition - 3
--Preheat - 4
--Fuel Ramp -5
--Running - 11
--Cooling - 12
--Restart -13


local ecuMessage = {

   [0]= {
      ["text"]= "Stop",
    },
   [1]= {
      ["text"]= "Ready",
    },
   [3]= {
      ["text"]= "Ignition"
    },
   [4]= {
      ["text"]= "Preheat"
    },
   [5]= {
      ["text"]= "Fuel Ramp"
    },
   [11]= {
      ["text"]= "Running"
    },
   [12]= {
      ["text"]= "Cooling"
    },
   [13]= {
      ["text"]= "Restart"
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

