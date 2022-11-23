local M = {}

function M.selField(fields)
   
   local function nameChanged(val, i)
      fields[i].name = val
   end
   
   form.setButton(2, ":add", 1)
   form.setButton(4, ":delete", 1)
   if not fields or #fields == 0 then
      form.addRow(1)
      form.addLabel({label="No Fields"})
      return
   end
   
   for i in ipairs(fields) do
      form.addRow(2)
      form.addTextbox(fields[i].name, 3, (function(x) return nameChanged(x,i) end), {width=60})
      local lat = string.format("%.5f", fields[i].lat)
      local lng = string.format("%.5f", fields[i].lng)
      form.addLabel({label=string.format("Lat %.6f   Lng %.6f  %d°",
					 fields[i].lat, fields[i].lng,
					 fields[i].rotation), width=260})
   end
   return savedRow
end

return M

