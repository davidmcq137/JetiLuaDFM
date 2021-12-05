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
      os.execute(string.format("sox %s -r 11000 -c 1 %s.out.wav", path, path)),
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

local function build_app(app)
   -- Find and load the lua source
   chunk, err = loadfile(string.format('%s.lua', app)) or loadfile(string.format('%s/%s.lua', app, app))
   if not chunk then
      print(string.format("Cannot load: %s ", app))
      return nil
   end
   
   -- Produce lc file
   lc_buffer = string.dump(chunk)
   lc_filename = string.format('%s.lc', app)
   lc_out = io.open(lc_filename, "wb")
   lc_out:write(lc_buffer)
   io.close(lc_out)
   
   -- Run the chunk to get the returned table
   info = chunk()

   -- Add the version and release date to App.json "in place"
   json_filename = string.format('%s/App.json', app)
   assert(
      os.execute(
         string.format(
            ">%s.out jq '. + {version: %q, releaseDate: %q}' %s && mv %s.out %s",
            json_filename,
            info.version,
            os.date("%a %e %b %Y %H:%M:%S %z"),
            json_filename,
            json_filename,
            json_filename)))

   -- Produce the zip
   output_dir = "release-output"
   os.execute("mkdir -p release-output")
   zip_name = string.format('%s/%s-v%s.zip', output_dir, app, info.version)
   assert(
      os.execute(
         string.format(
            'zip -r %s %s %s %s',
            zip_name,
            lc_filename,
            json_filename,
            app)))
   return info
end

local function main()
   -- Find and resample all the wav files 
   xs = listing("DFM-Maps/Lang/*/Audio/*.wav") or listing("DFM-Maps/Audio/*.wav") 
   for k, v in ipairs(xs) do
      resample_wav(v)
   end

   dfm_maps_info = assert(build_app('DFM-Maps'))
   -- Use github's hacky in-band signaling to pass the version string to the release upload step
   print("::set-output name=dfm_maps_version::" .. dfm_maps_info.version)
   
   assert(build_app('DFM-Amix'))
end

main()
