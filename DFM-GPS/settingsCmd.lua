local M = {}

local function changedMax(val, settings, setmax)
   settings.maxRibbon = val
   setmax(val)
end

function M.settings(savedRow, settings, setmax)
   form.setTitle("Settings")

   form.addRow(2)
   form.addLabel({label="Max points in ribbon", width=220})
   form.addIntbox(settings.maxRibbon, 0,1000,15,0,1,(function(x) return changedMax(x, settings, setmax) end))

   savedRow = 1
   return savedRow
end

return M

