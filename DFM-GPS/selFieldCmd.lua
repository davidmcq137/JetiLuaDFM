local M = {}

function M.selField(fields, savedRow, zeroPos, nameChanged, sel)
   

   form.setButton(2, ":add", 1)
   if sel ~= "P" then
      form.setButton(4, ":delete", 1)
   end
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
      form.addRow(4)
      if sel == "P" then
	 form.addLabel({label=fields[i].short, width=70, font=FONT_MINI})
      else
	 form.addTextbox(fields[i].short, 8, (function(x) return nameChanged(x,i,1) end),
			 {width=70, font=FONT_MINI})
      end
      
      --form.addTextbox(fields[i].longname or "...", 20, (function(x) return nameChanged(x,i,2) end),
      --	      {width=120, font=FONT_MINI})
      --print(i, fields[i].lat, fields[i].lng)
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
      form.addLabel({label = ss, width=80, font=FONT_MINI})

      --form.addLabel({label=string.format("[%.6f,%.6f]   %d°   ",
	--				 fields[i].lat, fields[i].lng,
	--				 math.deg(fields[i].rotation)) .. ss, width=220, font=FONT_MINI})
   end
   return savedRow
end

return M

