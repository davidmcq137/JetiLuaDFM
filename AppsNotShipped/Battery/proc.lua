ww = io.open("LiFePO_C2.csv", "w")
io.output(ww)
last=0
lastT=0
line=0
lw=0
for l in io.lines("LiFePO_C.csv") do
   --print(l)
   o = {}
   for w in string.gmatch(l, "([^,]+)") do
      if w then table.insert(o, w) end
   end
   o[3] = last + (o[1]-lastT)*o[3]/3600
   if line%300==0 then
      lw = lw + 1
      out = string.format("%d,%3.2f,%3.2f\r\n",lw, 100*(2.4-o[3])/2.4, o[2]/3)
      io.write(out)
   end
   line=line+1
   last = o[3]
   lastT=o[1]
		       
end

