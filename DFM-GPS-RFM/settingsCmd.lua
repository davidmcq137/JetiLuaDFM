local M = {}

local function changedMax(val, settings, setmax, mapV, xp, yp, rotateXY)
   print("changedMax", val, settings, setmax)
   settings.maxRibbon = val
   setmax(val, xp, yp, mapV, settings, rotateXY)
   print("back from setmax")
end

local function changedVal(val, settings, cc)
   if cc == "CS" then
      settings.colorSelect = val
   elseif cc == "ms" then
      settings.msMinSpacing = val
   elseif cc == "m" then
      settings.mMinSpacing = val
      settings.mMinSpacing2 = val^2
   end
end

function M.settings(savedRow, settings, setmax, mapV, xp, yp, rotateXY)

   print("settings", setmax, xp, yp)
   -- this table is replicated in drawColor.lua ... must change both places
   local colorSelect = {
      "None",  "Altitude", "Speed",  "Rx1 Q",  "Rx1 A1",
      "Rx1 A2","Rx2 Q",    "Rx2 A1", "Rx2 A2", "P4"
   }	 

   form.setTitle("History ribbon settings")

   form.addRow(2)
   form.addLabel({label="Max points in ribbon", width=220})
   form.addIntbox(settings.maxRibbon, 0,1000,15,0,1,
		  (function(x) return changedMax(x, settings, setmax, mapV, xp, yp, rotateXY) end))

   form.addRow(2)
   form.addLabel({label="Min ribbon time spacing", width=240})
   form.addIntbox(settings.msMinSpacing, 0,10000,0,0,10,
		  (function(x) return changedVal(x, settings, "ms") end), {label=" ms"})

   form.addRow(2)
   form.addLabel({label="Min ribbon distance spacing", width=240})
   form.addIntbox(settings.mMinSpacing, 0,1000,3,0,1,
		  (function(x) return changedVal(x, settings,  "m") end), {label=" m"})

   form.addRow(2)
   form.addLabel({label="Ribbon color source", width=220})
   form.addSelectbox(colorSelect, settings.colorSelect, true,
		     (function(x) return changedVal(x, settings, "CS") end))

   savedRow = 1
   return savedRow
end

return M

