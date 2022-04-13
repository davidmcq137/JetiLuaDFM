function pack_angle(angle)
   local d, m = math.modf(angle)
   return math.floor(m*60000+0.5) + (math.floor(d) << 16) -- math.floor forces to int
end


-- function pack_angle(angle)
--    d, m = math.modf(angle)
--    d = math.floor(d) -- math.floor forces to int
--    mk = math.floor(m*60000+0.5)
--    --print("d,mk: ", d, mk)
   
--    val = mk + (d << 16)
--    --print("val: ", val)
--    --print(string.format("m*1000 %04X, (d<<16) %04X", mk, (d<<16)))

--    return val
-- end

function unpack_angle(packed)

   --print(string.format("packed: %08X", packed))
   --print(string.format("packed>>16 & 0xFF: %04X", (packed>>16)& 0xFF))
   --print(string.format("packed & 0xFFFF: %04X", (packed & 0xFFFF)))
   --print( (packed >> 16) & 0xFF, (packed & 0xFFFF) )
   
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end
