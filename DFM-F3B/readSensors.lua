local M = {}

local tbl = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

local function telemChanged(val, stbl, v)
   stbl[v].Se = val
   stbl[v].SeId = tbl.Idlist[val]
   stbl[v].SePa = tbl.Palist[val]
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", stbl[v].SeId)
   system.pSave(v.."SePa", stbl[v].SePa)
end

local function initForm(sf, sens)
   for i in ipairs(sens) do
      form.addRow(2)
      form.addLabel({label=sens[i].label,width=140})
      form.addSelectbox(tbl.Lalist, sens[sens[i].var].Se or 0, true,
			(function(x) return telemChanged(x, sens, sens[i].var) end),
			{width=180, alignRight=false})
   end
end

local function keyForm(key)

   form.preventDefault()
   if key == KEY_5 then
      form.close(2)
   end
end

function M.readSensors(sens)

   local sensors = system.getSensors()
   print("gcc read", collectgarbage("count"))
   if not sens then return end -- for emulator, have to  call system.getSensors() to wake it up
   
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    table.insert(tbl.Lalist, ">> "..sensor.label)
	    table.insert(tbl.Idlist, 0)
	    table.insert(tbl.Palist, 0)
	 else
	    table.insert(tbl.Lalist, sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	 end
      end
   end

   system.registerForm(2, 0, "Sensor Selection", (function(x) return initForm(x, sens) end), keyForm)   
   
end

return M

