local M = {}

function M.selTele(sensIdPa)

   local telem = {}

   local sens = {
      {var="lat", label="Latitude"},
      {var="lng", label="Longitude"},
      {var="alt", label="Altitude"},
      {var="spd", label="Speed"}
   }
   
   if not sensIdPa or next(sensIdPa) == nil then
      sensIdPa = {}
      for i in ipairs(sens) do
	 local v = sens[i].var
	 sensIdPa[v] = {}
	 sensIdPa[v].Se   = 0
	 sensIdPa[v].SeId = 0
	 sensIdPa[v].SePa = 0
      end
   end

   local function readSensors(tbl)
      local sensors = system.getSensors()
      for _, sensor in ipairs(sensors) do
	 if (sensor.label ~= "") then
	    if sensor.param == 0 then
	       table.insert(tbl.Lalist, "-->"..sensor.label)
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
      stbl[v].SeId = ttbl.Idlist[val]
      stbl[v].SePa = ttbl.Palist[val]
   end

   if not telem or #telem == 0 then
      telem = {}
      telem.Lalist={"..."}
      telem.Idlist={"..."}
      telem.Palist={"..."}
      readSensors(telem)
   end

   form.setTitle("Telemetry Sensors")

   for i in ipairs(sens) do
      form.addRow(2)
      form.addLabel({label=sens[i].label,width=140})
      form.addSelectbox(telem.Lalist, sensIdPa[sens[i].var].Se, true,
			(function(x) return telemChanged(x, sensIdPa, sens[i].var, telem) end),
			{width=180, alignRight=false})
   end
   return sensIdPa

end

return M

