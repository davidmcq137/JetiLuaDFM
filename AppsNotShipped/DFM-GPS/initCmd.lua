local M = {}

function M.initCmd(mapV, fields, prefix)

   local file
   local mn
   local decoded
   local monoDev = {"JETI DC-16", "JETI DS-16", "JETI DC-14", "JETI DS-14"}

   local dev = system.getDeviceType()

   mapV.monoTx = false
   for _,v in ipairs(monoDev) do
      if dev == v then mapV.monoTx = true break end
   end

   -- on emulator set to B+W color scheme to force Mono TX behavior
   if select(2, system.getDeviceType()) == 1 then 
      system.getSensors() -- needed to jumpstart emulator
      if system.getProperty("Color") == 0 then
	 mapV.monoTx = true
      end
   end

   mapV.settings = {}
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   mapV.fileBD = prefix() .. "Apps/DFM-GPS/GG_" .. mn .. ".jsn"
   file = io.readall(mapV.fileBD)
   if file then
      print("Read file", mapV.fileBD)
      decoded = json.decode(file)
      mapV.settings = decoded.settings
      mapV.sensIdPa = decoded.sensIdPa
      for k,v in pairs(mapV.sensIdPa) do
	 for kk,vv in pairs(v) do
	    if kk == "SeId" then v[kk] = tonumber(vv);print(kk,vv, tonumber(vv)) end
	 end
      end
   end
   mapV.writeBD = true

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
      if mapV.settings[k] == nil then
	 mapV.settings[k] = v
      end
   end
   
   mapV.gpsCalA = false
   mapV.gpsCalB = false
   mapV.selField = nil
   mapV.needCalcXY = true
   mapV.maxPolyX = 0
   mapV.gpsReads = 0
   mapV.SFdone = false
   mapV.STdone = false
   
   return 

end

return M

