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
      os.execute(string.format("sox %s -r 16000 -c 1 %s.out.wav", path, path)),
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

local app_settings = {
  ['DFM-Maps'] = {no_lc = true},   
}

local function build_app(app)
   -- Find and load the lua source
   local lua_source = string.format('%s.lua', app)
   local chunk, err = loadfile(lua_source)
   if not chunk then
      lua_source = string.format('%s/%s.lua', app, app)
      chunk, err = loadfile(lua_source)
   end
   if not chunk then
      print(string.format("Cannot load: %s ", app))
      return nil
   end
   
   local lua_artifact = nil
   if not (app_settings[app] and app_settings[app].no_lc) then
     lua_artifact = string.format('%s.lc', app)
     local lc_out = io.open(lua_artifact, "wb")
     lc_out:write(string.dump(chunk))
     io.close(lc_out)
   else
     lua_artifact = string.format('%s.lua', app)
     if lua_source ~= lua_artifact then
       assert(os.execute(string.format('cp %s %s', lua_source, lua_artifact)))
     end
   end
   
   -- Run the chunk to get the returned table 
   local info = chunk()

   -- Add the version and release date to App.json "in place"
   local json_filename = string.format('%s/App.json', app)
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
            'zip -r %s %s %s',
            zip_name,
            --lua_artifact,
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
