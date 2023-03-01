local output_dir = "release-output/compiled-apps"

local function os_execute(cmd)
   io.stderr:write(string.format("[ %s exec] %s\n", arg[0], cmd))
   return os.execute(cmd)
end

local function resample_wav(path)
   assert(os_execute(string.format("sox %s -r 16000 -c 1 %s/%s", path, output_dir, path)),
          "sox failure on " .. path)
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
  ['DFM-InsP'] = {no_strip = true}
}

local function make_lc(lua_source, lc_out, no_strip)
   assert(
      os_execute(
         string.format('%sc %s -o %s %s',
                       arg[-1],
		       no_strip,
                       lc_out,
                       lua_source)))
end

local function build_app(app)
   os_execute(string.format("cp -r %s %s/%s", app, output_dir, app))

   -- Find and load the lua source
   local lua_source = string.format('%s.lua', app)
   local app_chunk, err = loadfile(lua_source)
   if not app_chunk then
      lua_source = string.format('%s/%s.lua', app, app)
      app_chunk, err = loadfile(lua_source)
   end
   if not app_chunk then
      print(string.format("Cannot load: %s ", app))
      return nil
   end
   
   -- Compile main module if we are supposed to (it goes in the root)
   local lua_artifact = nil
   local ns
   if not (app_settings[app] and app_settings[app].no_strip) then
      ns = "-s"
   else
      ns = ""
   end
   if not (app_settings[app] and app_settings[app].no_lc) then
     lua_artifact = string.format('%s.lc', app)
     make_lc(lua_source, string.format("%s/%s", output_dir, lua_artifact), ns)
   else
     lua_artifact = string.format('%s.lua', app)
     assert(os_execute(string.format('cp %s %s/%s', lua_source, output_dir, lua_artifact)))
   end
   
   -- Compile secondary modules if there are any (they remain in app dir)
   local modules = listing(app)
   for _, f in ipairs(modules) do
      v = string.format('%s/%s', app, f)
      if v:sub(-4) == ".lua" and f ~= lua_source then
         make_lc(v, string.format("%s/%s.lc", output_dir,v:sub(1, -5)), ns)
      end
   end

   -- Run the chunk to get the returned table 
   local info = app_chunk()

   -- Add the version and release date to App.json "in place"
   local json_filename = string.format('%s/App.json', app)
   assert(
      os_execute(
         string.format(
            "jq '. + {version: %q, releaseDate: %q}' %s >%s/%s",
            info.version,
            os.date("%a %e %b %Y %H:%M:%S %z"),
            json_filename,
            output_dir,
            json_filename)))

   -- Produce the zip
   os_execute(string.format("mkdir -p %s", output_dir))
   zip_name = string.format('%s-v%s.zip', app, info.version)
   assert(
      os_execute(
         string.format(
            'cd %s && zip -r %s %s %s %s',
            output_dir,
            --&&
            zip_name,
            lua_artifact,
            json_filename,
            app)))

   return {
      app = app,
      version = info.version,
      name = info.name,
      author = info.author,
      zip = zip_name
   }
end

local function rpad(s, l, c)
  return s .. string.rep(c or ' ', l - #s)
end

local function mkdirs(xs)
   local dirs = {}
   for k, v in ipairs(xs) do
      dirs[v:match('(.*/)')] = true
   end
   assert(not dirs[nil], "unparseable path")
   for k, _ in pairs(dirs) do
      assert(os_execute(string.format("mkdir -p %s/%s", output_dir, k)))
   end
end

local function main()
   assert(os_execute(string.format("rm -rvf %s", output_dir)))
   assert(os_execute(string.format("mkdir -p %s", output_dir)))

   -- Find and resample all the wav files 
   local xs = listing("DFM-Maps/Lang/*/Audio/*.wav") or listing("DFM-Maps/Audio/*.wav") 

   mkdirs(xs)

   for k, v in ipairs(xs) do
      resample_wav(v)
   end
   
   local rs = {}
   local go = function(a) 
      table.insert(rs, assert(build_app(a)))
   end

   go('DFM-Maps')
   go('DFM-Amix')
   go('DFM-GPS')
   go('DFM-InsP')

   io.stderr:write("===========================================================================\n")
   for _, r in ipairs(rs) do
      io.stderr:write(string.format("%s%s%s\n",
                                    rpad(r.name, 20),
                                    rpad(tostring(r.version), 8),
                                    r.zip))
   end

   -----------
   local mf = io.open(string.format("%s/manifest.txt", output_dir), "w")
   for _, r in ipairs(rs) do
      mf:write(string.format("%s\n", r.zip))
   end
   mf:close()

end

main()
