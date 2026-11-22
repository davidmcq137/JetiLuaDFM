
function pack_angle(angle)
   local d, m = math.modf(angle)
   return math.floor(m*60000+0.5) + (math.floor(d) << 16) -- math.floor forces to int
end

function unpack_angle(packed)
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end


maxdelta = 0

for i=1, 10000000, 1 do
   n = 90*math.random()
   packed = pack_angle(n)
   unpacked = unpack_angle(packed)

   delta = math.abs(unpacked - n)
   maxdelta = math.max(maxdelta, delta)
   --print(string.format("%15f %15d %15f (%05f)", n, packed, unpacked, delta))
   if delta > 0.00001 then
      print("!!! ", n, packed, unpacked, delta)
   end
end
print("ok checked 1m, maxdelta:", maxdelta)
