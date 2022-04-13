hx711.init(5,6)


for j=1, 20, 1 do
   hx = hx711.read(0)
   print(j, hx)
   tmr.delay(2000)
end
