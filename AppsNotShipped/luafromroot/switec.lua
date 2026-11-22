print("starting")
a = switec.setup(0,5,6,7,8)
print("setup returns:", a)

--print("resetting")
--switec.reset(0)

print("while loop")

while true do
   local p = switec.getpos()
   print("getpos", p)
   if p == 0 then break end
end

print("moveto 0")

switec.moveto(0, 0)

print("moveto 500")

switec.moveto(0, 500)

print("moveto 1000")

switec.moveto(0, 1000)

print("moveto 0")

switec.moveto(0, 0)

print("closing")

switec.close(0)

