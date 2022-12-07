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
   print("val", val, type(val))
   if val ~= 1 then
      stbl[v].Se = math.floor(val)
      stbl[v].SeId = math.floor(ttbl.Idlist[val])
      stbl[v].SePa = math.floor(ttbl.Palist[val])
   else
      stbl[v].Se = 1
      stbl[v].SeId = 0
      stbl[v].SePa = 0
   end
   
   print("pSave", v.."Se", stbl[v].Se)
   print("pSave", v.."SeId", (stbl[v].SeId))
   print("pSave", v.."SePa", (stbl[v].SePa))   
   
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", (stbl[v].SeId))   system.pSave(v.."SePa", (stbl[v].SePa))
end

local function initForm(sf, F3G)

   if sf == 1 then
      form.setTitle("F3G Telemetry Sensors")
      readSensors(F3G.telem)
      for i in ipairs(F3G.sens) do
	 form.addRow(2)
	 form.addLabel({label=F3G.sens[i].label,width=140})
	 form.addSelectbox(F3G.telem.Lalist, F3G.sens[F3G.sens[i].var].Se, true,
			   (function(x) return telemChanged(x, F3G.sens, F3G.sens[i].var, F3G.telem) end),
			   {width=180, alignRight=false})
      end
   end
end

local function foo()
   print("FOO!")
end

function  M.teleCmd(F3G)
   system.registerForm(2, 0, "F3G Sensors", (function(x) return initForm(x, F3G) end), nil, nil, foo)
end

return M
