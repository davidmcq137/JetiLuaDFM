local M = {}

function M.initCmd(mapV, prefix)

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
	       tt = json.decode(file)
	    end
	    local nn = string.sub(fn, j+1)
	    table.insert(fields,
			 {short=nn, lat=(tt.lat or 0), lng=(tt.lng or 0),
			  rotation=math.rad(tt.rotation or 0)})
	 end
      end
   end
      
   local setT = {
      maxRibbon = 15,
      colorSelect = 1,
      msMinSpacing = 200,
      mMinSpacing = 3,
      mMinSpacing2 = 9,
      ribbonScale = 100,
      planeShape = "Glider",
      showMarkers = false,
      nfzBeeps = true,
      nfzWav = false
   }

   for k,v in pairs(setT) do
      if settings[k] == nil then
	 settings[k] = v
      end
   end
   
   mapV.gpsCalA = false
   mapV.gpsCalB = false
   mapV.selField = nil
   mapV.needCalcXY = true
   mapV.maxPolyX = 0
   mapV.gpsReads = 0
   
   return settings, sensIdPa, fields, writeBD, fileBD

end

return M

