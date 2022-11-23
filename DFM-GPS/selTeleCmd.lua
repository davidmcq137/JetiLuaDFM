local M = {}

function M.selTele(telem, sens, readSensors, savedRow)

   local function telemChanged(val, stbl, v, ttbl)
      stbl[v].Se = val
      stbl[v].SeId = ttbl.Idlist[val]
      stbl[v].SePa = ttbl.Palist[val]
      if v == "alt" or v == "spd" then
	 --the require and init for tape display would go here
      end
   end
   if not telem then
      telem = {
	 Lalist={"..."},
	 Idlist={"..."},
	 Palist={"..."}
      }
      readSensors(telem)
   end
   form.setTitle("Telemetry Sensors")
   print("#sens", #sens)
   for i in ipairs(sens) do
      form.addRow(2)
      form.addLabel({label=sens[i].label,width=140})
      form.addSelectbox(telem.Lalist, sens[sens[i].var].Se, true,
			(function(x) return telemChanged(x, sens, sens[i].var, telem) end),
			{width=180, alignRight=false})
   end
   return savedRow
end

return M

