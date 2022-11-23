local M = {}

function M.noFly(nfk, nfz, savedZone)
   
   local function zoneChanged(val, sel, i)
      if sel == nfk.type then
	 nfz[i].type = val
      else
	 nfz[i].shape = val
      end
      form.reinit(5)
   end
   local function radiusChanged(val, i)
      nfz[i].radius = val
   end
   form.setTitle("No Fly Zones")
   form.setButton(2, ":add", 1)
   form.setButton(3, ":edit", 1)
   form.setButton(4, ":delete", 1)
   if not nfz then
      form.addRow(1)
      form.addLabel({label="No No-Fly Zones"})
      return
   end
   for i,z in ipairs(nfz) do
      if nfz[i].shape == nfk.circle then
	 form.addRow(5)
      else
	 form.addRow(3)
      end
      
      form.addLabel({label=string.format("%d", i), width=20})
      form.addSelectbox(nfk.selType,  nfz[i].type,  true,
			(function(x) return zoneChanged(x, nfk.type, i)  end), {width=85})
      form.addSelectbox(nfk.selShape, nfz[i].shape, true,
			(function(x) return zoneChanged(x, nfk.shape, i) end), {width=85})
      if nfz[i].shape == nfk.circle then
	 form.addLabel({label="Rad", width=50})
	 form.addIntbox((nfz[i].radius or 0), 0, 10000, 100, 0, 1,
	    (function(x) return radiusChanged(x, i) end), {width=60})
      end
      
   end
   if savedZone then form.setFocusedRow(savedZone) end
end

return M

