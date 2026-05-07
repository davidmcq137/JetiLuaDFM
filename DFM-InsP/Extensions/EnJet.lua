local M = {}

--Enjet turbine codes:

-- 0 Downtime
-- 1 Starting
-- 2 Running
-- 3 Cold machine
-- 4 Flameout Restart
-- 7 Component Test
-- 8 Remote Control Calibration
-- 9 Flameout Restart
-- 11 Engine Ready
-- 33 Startup Stage 1
-- 34 Startup Stage 2
-- 35 Startup Stage 3
-- 36 Startup Stage 4
-- 37 Startup Stage 5
-- 38 Startup Stage 6

local ecuMessage = {

   [0]= {
      ["text"]= "Downtime"
    },
   [1]= {
      ["text"]= "Starting"
    },
   [2]= {
      ["text"]= "Running"
    },
   [3]= {
      ["text"]= "Cold machine"
    },
   [4]= {
      ["text"]= "Flameout restart"
    },
   [7]= {
      ["text"]= "Component test"
    },
   [8]= {
      ["text"]= "Remote control calibration"
   },
   [9]= {
      ["text"]= "Flameout restart"
   },
   [11]= {
      ["text"]= "Engine ready"
   },
   [33]= {
      ["text"]= "Startup stage 1"
   },
   [34]= {
      ["text"]= "Startup stage 2"
   },
   [35]= {
      ["text"]= "Startup stage 3"
   },
   [36]= {
      ["text"]= "Startup stage 4"
   },
   [37]= {
      ["text"]= "Startup stage 5"
   },
   [38]= {
      ["text"]= "Startup stage 6"
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

