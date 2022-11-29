local M = {}

local function changedMax(val, settings, setmax)
   settings.maxRibbon = val
   setmax(val)
end

local function changedCS(val, settings)
   settings.colorSelect = val
end

function M.settings(savedRow, settings, setmax)

   local colorSelect = {
      "None",  "Altitude", "Speed",  "Rx1 Q",  "Rx1 A1",
      "Rx1 A2","Rx2 Q",    "Rx2 A1", "Rx2 A2", "P4"
   }	 

   form.setTitle("Settings")

   form.addRow(2)
   form.addLabel({label="Max points in ribbon", width=220})
   form.addIntbox(settings.maxRibbon, 0,1000,15,0,1,(function(x) return changedMax(x, settings, setmax) end))

   form.addRow(2)
   form.addLabel({label="Ribbon color source", width=220})
   form.addSelectbox(colorSelect, settings.colorSelect, true, (function(x) return changedCS(x, settings) end))

   savedRow = 1
   return savedRow
end

return M

