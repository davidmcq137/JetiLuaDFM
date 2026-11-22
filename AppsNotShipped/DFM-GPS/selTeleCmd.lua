local M = {}

function M.selTele(mapV)

   local telem

   local sens = {
      {var="lat", label="Latitude"},
      {var="lng", label="Longitude"},
      {var="alt", label="Altitude"},
      {var="spd", label="Speed"}
   }
   

   local function readSensors(tbl)
      local sensors = system.getSensors()
      for _, sensor in ipairs(sensors) do
	 if (sensor.label ~= "") then
	    if sensor.param == 0 then
	       table.insert(tbl.Lalist, sensor.label)
	       table.insert(tbl.Idlist, 0)
	       table.insert(tbl.Palist, 0)
	    else
	       table.insert(tbl.Lalist, sensor.label)
	       table.insert(tbl.Idlist, sensor.id)
	       table.insert(tbl.Palist, sensor.param)
	    end
	 end
      end
   end
   
   local function telemChanged(val, stbl, v, ttbl)
      stbl[v].Se = val
      --print("val", val, ttbl.Idlist[val], ttbl.Palist[val], ttbl.Lalist[val])
      if val == 1 then ttbl.Idlist[val] = 0; ttbl.Palist[val] = 0 else
	 stbl[v].SeId = ttbl.Idlist[val]; stbl[v].SePa = ttbl.Palist[val]
      end
   end

   telem = {}
   telem.Lalist={"..."}
   telem.Idlist={0}
   telem.Palist={0}
   readSensors(telem)

   if not mapV.sensIdPa or next(mapV.sensIdPa) == nil then
      mapV.sensIdPa = {}
      for i in ipairs(sens) do
	 local v = sens[i].var
	 mapV.sensIdPa[v] = {}
	 mapV.sensIdPa[v].Se   = 0
	 mapV.sensIdPa[v].SeId = 0
	 mapV.sensIdPa[v].SePa = 0
      end
   end

   --form.setTitle("Telemetry Sensors")

   for i in ipairs(sens) do
      form.addRow(2)
      form.addLabel({label=sens[i].label,width=140})
      form.addSelectbox(telem.Lalist, mapV.sensIdPa[sens[i].var].Se, true,
			(function(x) return telemChanged(x, mapV.sensIdPa, sens[i].var, telem) end),
			{width=180, alignRight=false})
   end
   return

end

return M

