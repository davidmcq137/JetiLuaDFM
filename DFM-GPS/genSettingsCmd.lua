local M = {}

local cI={}

local function markChanged(val, settings, name, ci)
   settings[name] = not settings[name]
   form.setValue(ci, settings[name])
end

local function shapeChanged(val, settings, icons)
   settings.planeShape = icons[val]
end

function M.genSettings(savedRow, settings, mapV)
   
   local icons = {"Glider", "Jet", "Prop"}
   
   form.setTitle("General settings")

   form.addRow(2)
   form.addLabel({label="Show GPS Point markers", width=275})
   cI[1] = form.addCheckbox(settings.showMarkers,
			    (function(x) return markChanged(x, settings, "showMarkers", cI[1]) end))

   form.addRow(2)
   form.addLabel({label="No Fly entry/exit beeps", width=275})
   cI[2] = form.addCheckbox(settings.nfzBeeps,
			    (function(x) return markChanged(x, settings, "nfzBeeps", cI[2]) end))   
   
   form.addRow(2)
   form.addLabel({label="No Fly entry/exit announcements", width=275})
   cI[3] = form.addCheckbox(settings.nfzWav,
			    (function(x) return markChanged(x, settings, "nfzWav", cI[3]) end))
   local idx = 0
   for i, icon in ipairs(icons) do
      if settings.planeShape == icon then
	 idx = i; break
      end
   end

   form.addRow(2)
   form.addLabel({label="Aircraft Icon", width=220})
   form.addSelectbox(icons, idx, true, (function(x) return shapeChanged(x, settings, icons) end))

   savedRow = 1
   return savedRow
end

return M

