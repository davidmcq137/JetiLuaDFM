local M = {}

function M.keyField(kkey, mapV, settings, fields, prefix)

   local file
   local nfz
   local decode
   local key = kkey
   if key == KEY_5 or key == KEY_ENTER then
      form.preventDefault()
      mapV.gpsCalA = false
      mapV.gpsCalB = false
      if not fields or #fields < 1 then
	 key = KEY_ESC
      else
	 mapV.selField = fields[form.getFocusedRow()].short
	 local fn = prefix().."Apps/DFM-GPS/FF_"..mapV.selField..".jsn"
	 file = io.readall(fn)
	 if file then
	    decode = json.decode(file)
	    nfz = decode.nfz
	 end
	 mapV.zeroPos = gps.newPoint(decode.lat, decode.lng)
	 settings.rotA = math.rad(decode.rotation)
	 mapV.gpsCalA = true
	 mapV.gpsCalB = true
	 form.close(2)
      end
   end
   if key == KEY_ESC or key == KEY_1 then
      form.preventDefault()
      mapV.selField = ""
      mapV.gpsCalA = false
      mapV.gpsCalB = false
      if settings.zeroLatString and settings.zeroLngString then
	 mapV.gpsCalA = true
      end
      if mapV.gpsCalA and settings.rotA then
	 mapV.gpsCalB = true
      end
      --local pp = gps.newPoint(settings.zeroLatString, settings.zeroLngString)
      local dd = gps.getDistance(mapV.zeroPos, mapV.curPos)
      local uu = "m"
      if dd > 1000 then dd = dd / 1000.0; uu = "km" end
      if mapV.gpsCalA and mapV.gpsCalB then
	 system.messageBox(string.format("Using saved lat/lng. Dist = %.1f %s", dd, uu))
      end
      form.close(2)
   end
   if key == KEY_2 then
      fields.showAll = not fields.showAll
      form.reinit(1)
   end
   
   return nfz
end

function M.selField(fields, savedRow, zeroPos)
   
   form.setButton(1, "Esc", ENABLED)
   form.setButton(2, "Show", ENABLED)
   
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

      local pp = gps.newPoint(fields[i].lat, fields[i].lng)
      local dd = gps.getDistance(zeroPos, pp) or 0
      local viz = true
      if dd > 1000 and (not fields.showAll) then viz = false end

      form.addRow(4)
      form.addLabel({label=fields[i].short, width=65, font=FONT_MINI, visible=viz})
      form.addLabel({label=string.format("[%.6f,%.6f]", fields[i].lat, fields[i].lng),
		     width=130, font=FONT_MINI, visible=viz})
      form.addLabel({label=string.format("%d°", math.deg(fields[i].rotation)), width=40,
		     font=FONT_MINI, visible=viz})
      local ss
      if dd < -10 then -- disable for now
	 ss = "Dist < 10 m"
      elseif dd > 10000 then
	 ss = string.format("Dist %d km", dd/1000)
      elseif fields[i].lat == 0 and fields[i].lng == 0 then
	 ss = ""
      else
	 ss = string.format("Dist %.1f m", dd)
      end
      form.addLabel({label = ss, width=85, font=FONT_MINI, visible=viz})
   end
   return savedRow
end

return M

