local M = {}

function M.polyPt(nfk, nfz, savedZone)
   
   local function pointChanged(val, sel, gp, i, ff)
      if sel == nfk.lat then
	 gp[i].lat = val
      else
	 gp[i].lng = val
      end
      form.reinit(ff)
   end
   form.setTitle("Edit Polygon No Fly Zone " .. savedZone)
   form.setButton(2, ":add", 1)
   if #nfz[savedZone].path == 0 then
      for i=1,3,1 do
	 table.insert(nfz[savedZone].path, {lat=0,lng=0})
	 table.insert(nfz[savedZone].xy, {x=0,y=0})
      end
   end
   
   for i,gpsP in ipairs(nfz[savedZone].path) do
      form.addRow(5)
      form.addLabel({label=string.format("%d", i), width=20})
      local lat = string.format("%.6f", gpsP.lat)
      local lng = string.format("%.6f", gpsP.lng)
      form.addLabel({label="Lat", width=35})
      form.addTextbox(lat, 10,
		      (function(x) return pointChanged(x, nfk.lat, nfz[savedZone].path, i, 51) end),
		      {width=110})
      form.addLabel({label="Lng", width=35})
      form.addTextbox(lng, 10,
		      (function(x) return pointChanged(x, nfk.lng, nfz[savedZone].path, i, 51) end),
		      {width=110})
   end
   form.setFocusedRow(1)
end

return M
