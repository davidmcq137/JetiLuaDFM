local M = {}

function M.circPt(nfk, nfz, savedZone)
   local function pointChanged(val, sel, gp, i, ff)
      if sel == nfk.lat then
	 gp[i].lat = val
      else
	 gp[i].lng = val
      end
      form.reinit(ff)
   end
   form.setTitle("Edit Circle No Fly Zone " .. savedZone)
   if #nfz[savedZone].path == 0 then
      table.insert(nfz[savedZone].path, {lat=0,lng=0})
      table.insert(nfz[savedZone].xy, {x=0,y=0})
   end
   form.addRow(4)
   local lat = string.format("%.6f", nfz[savedZone].path[1].lat)
   local lng = string.format("%.6f", nfz[savedZone].path[1].lng)
   form.addLabel({label="Lat", width=35})
   form.addTextbox(lat, 10,
		   (function(x) return pointChanged(x, nfk.lat, nfz[savedZone].path, 1, 52) end),
		   {width=110})
   form.addLabel({label="Lng", width=35})
   form.addTextbox(lng, 10,
		   (function(x) return pointChanged(x, nfk.lng, nfz[savedZone].path, 1, 52) end),
		   {width=110})
end

return M

