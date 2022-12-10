local M = {}

local cI={}

local function markChanged(_, mapV, name, cn)
   mapV.settings[name] = not mapV.settings[name]
   form.setValue(cI[cn], mapV.settings[name])
end

local function shapeChanged(val, mapV, icons)
   mapV.settings.planeShape = icons[val]
end

function M.genSettings(mapV)
   
   local icons = {"Glider", "Jet", "Prop"}
   
   form.setTitle("General settings")

   form.addRow(2)
   form.addLabel({label="Show GPS Point markers", width=275})
   cI[1] = form.addCheckbox(mapV.settings.showMarkers,
			    (function(x) return markChanged(x, mapV, "showMarkers", 1) end))

   form.addRow(2)
   form.addLabel({label="No Fly entry/exit beeps", width=275})
   cI[2] = form.addCheckbox(mapV.settings.nfzBeeps,
			    (function(x) return markChanged(x, mapV, "nfzBeeps", 2) end))   
   
   form.addRow(2)
   form.addLabel({label="No Fly entry/exit announcements", width=275})
   cI[3] = form.addCheckbox(mapV.settings.nfzWav,
			    (function(x) return markChanged(x, mapV, "nfzWav", 3) end))
   local idx = 0
   for i, icon in ipairs(icons) do
      if mapV.settings.planeShape == icon then
	 idx = i; break
      end
   end

   form.addRow(2)
   form.addLabel({label="Aircraft Icon", width=220})
   form.addSelectbox(icons, idx, true, (function(x) return shapeChanged(x, mapV, icons) end))

   return
end

return M

