local M = {}

local function keyField(kkey, mapV, fields, nfz, prefix)

   local file
   local decode
   local key = kkey
   --print("keyField", key)
   if key == KEY_5 or key == KEY_ENTER then
      form.preventDefault()
      mapV.gpsCalA = false
      mapV.gpsCalB = false
      print("keyField", #fields)
      if not fields or #fields < 1 then
	 key = KEY_ESC
      else
	 mapV.selField = fields[form.getFocusedRow()].short
	 local fn = prefix().."Apps/DFM-GPS/FF_"..mapV.selField..".jsn"
	 print("reading field file", fn)
	 file = io.readall(fn)
	 if file then
	    decode = json.decode(file)
	    for k,v in pairs(decode.nfz) do
	       print("k,v",k,v)
	       nfz[k]={}
	       nfz[k].type = v.type
	       print("v.type", v.type)
	       nfz[k].shape = v.shape
	       print("v.shape", v.shape)
	       nfz[k].radius = v.radius
	       nfz[k].path = {}
	       nfz[k].xy = {}
	       for kk,vv in pairs(v.path) do
		  print("kk,vv",kk,vv)
		  nfz[k].path[kk] = {}
		  nfz[k].path[kk].lat = vv.lat
		  nfz[k].path[kk].lng = vv.lng		  
	       end
	    end
	    --nfz = decode.nfz
	 end
	 print("decode done", nfz, #nfz)
	 mapV.zeroPos = gps.newPoint(decode.lat, decode.lng)
	 mapV.settings.rotA = math.rad(decode.rotation)
	 mapV.gpsCalA = true
	 mapV.gpsCalB = true
	 mapV.needCalcXY = true
	 form.close(2)
      end
   end
   if key == KEY_ESC or key == KEY_1 then
      form.preventDefault()
      mapV.selField = ""
      mapV.gpsCalA = false
      mapV.gpsCalB = false
      if mapV.settings.zeroLatString and mapV.settings.zeroLngString then
	 mapV.gpsCalA = true
      end
      if mapV.gpsCalA and mapV.settings.rotA then
	 mapV.gpsCalB = true
      end
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
   
   return

end

local function initForm(_, mapV, fields)
      
   form.setButton(1, "Esc", ENABLED)
   form.setButton(2, "Show", ENABLED)

   form.setTitle("DFM-GPS: Esc to exit without field")
   
   if not fields or #fields == 0 then
      form.addRow(1)
      form.addLabel({label="No Fields"})
      return
   end
   
   --print("dist zero", gps.getStrig(mapV.zeroPos))

   local pp, dd
   
   for i in ipairs(fields) do
      pp = gps.newPoint(fields[i].lat, fields[i].lng)
      dd = gps.getDistance(mapV.zeroPos, pp) or 0
      fields[i].distance = dd
   end

   table.sort(fields, (function(f1,f2) return f1.distance < f2.distance end) ) 

   for i in ipairs(fields) do
      pp = gps.newPoint(fields[i].lat, fields[i].lng)
      dd = gps.getDistance(mapV.zeroPos, pp) or 0
      --print("@",i,dd)
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
   return
end

function M.selField(mapV, fields, nfz, prefix)
   print("registering Field form")
   system.registerForm(2, 0, "DFM-GPS: Esc to exit without field",
		       (function(x) return initForm(x, mapV, fields) end),
		       (function(x) return keyField(x, mapV, fields, nfz, prefix) end),
		       nil,
		       (function()
			     print("field form killed")
			     mapV.SFdone = true
			     collectgarbage()
   end) )
end

return M

