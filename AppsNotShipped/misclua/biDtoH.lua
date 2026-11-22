-- biDtoH .. convert arbitrarily large decimal number to hex, string to string representation
-- borrowed from Dan Bystrom 
-- https://stackoverflow.com/questions/2652760/how-to-convert-a-gi-normous-integer-in-string-format-to-hex-format-c/2653006#2653006
-- translated to lua by DFM

function biDtoH(s)
   --sb=0xFFFA
   --s = string.format("%d", sb)
   print("s= "..s)
   result={0}
   
   for c in string.gmatch(s, ".") do
      val = string.byte(c) - string.byte("0")
      for i=1, #result, 1 do
	 digit = result[i] * 10 + val     
	 result[i] = digit & 0x0F
	 val = digit >> 4
      end
      if val ~= 0 then table.insert(result, val) end 
   end
   
   hex = ""
   for i = 1, #result do
      hex = string.sub("0123456789ABCDEF", result[i]+1, result[i]+1) .. hex
   end
   
   print("hex:", hex)
   
   return hex
   
end
