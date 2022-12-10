local M = {}

local function readSensors(tbl)
   --local sensorLbl = "***"
   
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    --sensorLbl = sensor.label
	    table.insert(tbl.Lalist, ">> "..sensor.label)
	    table.insert(tbl.Idlist, 0)
	    table.insert(tbl.Palist, 0)
	 else
	    table.insert(tbl.Lalist, sensor.label)
	    --table.insert(tbl.Lalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	 end
      end
   end
end

local function telemChanged(val, stbl, v, ttbl)
   --print("val", val, type(val))
   if val ~= 1 then
      stbl[v].Se = math.floor(val)
      stbl[v].SeId = math.floor(ttbl.Idlist[val])
      stbl[v].SePa = math.floor(ttbl.Palist[val])
   else
      stbl[v].Se = 1
      stbl[v].SeId = 0
      stbl[v].SePa = 0
   end
   
   --print("pSave", v.."Se", stbl[v].Se)
   --print("pSave", v.."SeId", (stbl[v].SeId))
   --print("pSave", v.."SePa", (stbl[v].SePa))   
   
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", (stbl[v].SeId))   system.pSave(v.."SePa", (stbl[v].SePa))
end

local function initForm(sf, F3X)

   print("iFT", collectgarbage("count"))
   if sf == 1 then
      form.setTitle("F3X Telemetry Sensors")
      readSensors(F3X.telem)
      for i in ipairs(F3X.sens) do
	 form.addRow(2)
	 form.addLabel({label=F3X.sens[i].label,width=140})
	 form.addSelectbox(F3X.telem.Lalist, F3X.sens[F3X.sens[i].var].Se, true,
			   (function(x) return telemChanged(x, F3X.sens, F3X.sens[i].var, F3X.telem) end),
			   {width=180, alignRight=false})
      end
   end
end

function  M.teleCmd(F3X)
   system.registerForm(2, 0, "F3X Sensors", (function(x) return initForm(x, F3X) end))
end

return M
