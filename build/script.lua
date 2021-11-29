local function json_array_scalars(xs)
   str = "["
   for k,v in pairs(xs) do
      str = str .. tostring(v)
      if k == #xs then str = str .. "]"
      else str = str .. ','
      end
   end
   return str
end

local function resample_wav(path)
   assert(
      os.execute(string.format("sox %s -r 12000 -c 1 -e mu-law %s.out.wav", path, path)),
      "sox failure on " .. path)
   assert(os.execute(string.format("mv %s.out.wav %s", path, path)))
end

local function listing(path)
   f = assert(io.popen("ls -1 " .. path))
   s = {}
   for line in f:lines() do
      s[1+#s] = line
   end

   local _, _, exit_code = f:close()
   if exit_code == 0 then
      return s
   else
      return nil
   end
end

local function main()
   -- Find and resample all the wav files 
   xs = listing("DFM-Maps/Lang/*/Audio/*/wav") or listing("DFM-Maps/Audio/*.wav") 
   for k, v in ipairs(xs) do
      resample_wav(v)
   end

   -- Find and load the lua source
   dfm_maps_chunk, err = loadfile('DFM-Maps.lua') or loadfile('DFM-Maps/DFM-Maps.lua')
   if not dfm_maps_chunk then
      print("Cannot load lua file")
      return
   end
   
   -- Produce lc file 
   lc_buffer = string.dump(dfm_maps_chunk)
   lc_filename = 'DFM-Maps.lc'
   lc_out = io.open(lc_filename, "wb")
   lc_out:write(lc_buffer)
   io.close(lc_out)
   
   -- Run the chunk to get the returned table
   dfm_maps =  dfm_maps_chunk()

   -- Use github's hacky in-band signaling to pass the version string to the release upload step
   print("::set-output name=dfm_maps_version::" .. dfm_maps.version)

   -- Add the version and release date to App.json "in place"
   json_filename = 'DFM-Maps/App.json'
   assert(
      os.execute(
         string.format(
            ">%s.out jq '. + {version: %q, releaseDate: %q}' %s && mv %s.out %s",
            json_filename,
            dfm_maps.version,
            os.date("%a %e %b %Y %H:%M:%S %z"),
            json_filename,
            json_filename,
            json_filename)))

   -- Produce the zip
   zip_name = "release-output/DFM-Maps-v" .. dfm_maps.version .. ".zip"
   os.execute("mkdir -p release-output")
   os.execute("zip -r " .. zip_name .. "  " .. lc_filename .. " " .. json_filename .. " DFM-Maps" )
end

main()
