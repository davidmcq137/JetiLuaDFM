

local function main()

   dfm_maps_chunk, err = loadfile('DFM-Maps.lua') or loadfile('DFM-Maps/DFM-Maps.lua')
   if not dfm_maps_chunk then
      print("Cannot load lua file")
      return
   end

   lc_buffer = string.dump(dfm_maps_chunk)

   lc_filename = 'DFM-Maps.lc'
   lc_out = io.open(lc_filename, "wb")
   lc_out:write(lc_buffer)
   io.close(lc_out)
   
   dfm_maps =  dfm_maps_chunk()

   -- Use github hacky in-band signaling to pass version to release upload step
   print("::set-output name=dfm_maps_version::" .. dfm_maps.version)

   zip_name = "release-output/DFM-Maps-v" .. dfm_maps.version .. ".zip"
   
   os.execute("zip -r " .. zip_name .. "  " .. lc_filename .. " DFM-Maps" )
   
end


main()




