local M = {}

function M.initCmd(sens, mapV, prefix, setMapScale)

   local file
   local mn
   local decoded
   local fileBD, writeBD
   local settings = {}
   local fields={}
   local sensIdPa
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fileBD = prefix() .. "Apps/DFM-GPS/GG_" .. mn .. ".jsn"
   file = io.readall(fileBD)
   if file then
      decoded = json.decode(file)
      settings = decoded.settings
      sensIdPa = decoded.sensIdPa
   end
   writeBD = true

   if not sensIdPa then
      print("zeroing sensIdPa")
      sensIdPa = {}
      for i in ipairs(sens) do
	 local v = sens[i].var
	 sensIdPa[v] = {}
	 sensIdPa[v].Se   = 0
	 sensIdPa[v].SeId = 0
	 sensIdPa[v].SePa = 0
	 print(i,v, sensIdPa[v].SeId, sensIdPa[v].SePa)
      end
   end

   local dd, fn, ext, tt
   local path = prefix().."Apps/DFM-GPS"
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 local i,j = string.find(fn, "FF_")
	 if string.lower(ext) == "jsn" and i == 1 then
	    local ff = path .. "/" .. fn .. "." .. ext
	    file = io.readall(ff)
	    if file then
	       print("decoding", ff)
	       tt = json.decode(file)
	    end
	    local nn = string.sub(fn, j+1)
	    table.insert(fields,
			 {short=nn, lat=(tt.lat or 0), lng=(tt.lng or 0),
			  rotation=(tt.rotation or 0)})
	 end
      end
   end

      
   mapV.gpsCalA = false
   mapV.gpsCalB = false

   if settings and settings.zeroLatString and settings.zeroLngString then
      mapV.zeroPos = gps.newPoint(settings.zeroLatString, settings.zeroLngString)
      mapV.gpsCalA = true
   end

   if settings.rotA and mapV.gpsCalA then mapV.gpsCalB = true end

   mapV.mapScaleIdx = 1
   mapV.xmin, mapV.xmax, mapV.ymin, mapV.ymax = setMapScale(mapV.mapScaleIdx)

   mapV.selField = nil

   return settings, sensIdPa, fields, writeBD, fileBD

end

return M

