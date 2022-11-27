local M = {}

function M.selField(fields, savedRow, zeroPos)
   

   if not fields or #fields == 0 then
      form.addRow(1)
      form.addLabel({label="No Fields"})
      return
   end

   for i in ipairs(fields) do
      local pp = gps.newPoint(fields[i].lat, fields[i].lng)
      local dd = gps.getDistance(zeroPos, pp) or 0
      fields[i].distance = dd
   end

   table.sort(fields, (function(f1,f2) return f1.distance < f2.distance end) ) 
   
   for i in ipairs(fields) do
      --print("##", i, fields[i].short)
      form.addRow(4)
      form.addLabel({label=fields[i].short, width=65, font=FONT_MINI})
      local pp = gps.newPoint(fields[i].lat, fields[i].lng)
      local dd = gps.getDistance(zeroPos, pp) or 0
      form.addLabel({label=string.format("[%.6f,%.6f]", fields[i].lat, fields[i].lng),
		     width=130, font=FONT_MINI})
      form.addLabel({label=string.format("%d°", math.deg(fields[i].rotation)), width=40, font=FONT_MINI})
      local ss
      if dd < -10 then
	 ss = "Dist < 10 m"
      elseif dd > 10000 then
	 ss = string.format("Dist %d km", dd/1000)
      elseif fields[i].lat == 0 and fields[i].lng == 0 then
	 ss = ""
      else
	 ss = string.format("Dist %.1f m", dd)
      end
      form.addLabel({label = ss, width=85, font=FONT_MINI})
   end
   return savedRow
end

return M

