--deg={20,40,60,120,140,160,220,240,280,300,320}
--r=17.5
deg={0,120,240}
r=4.15
for i,d in ipairs(deg) do
   dd = deg[i] * math.pi / 180.0
   s=string.format("%3d, %04.4f, %04.4f, %04.4f", i, deg[i], -r * math.sin(dd), r * math.cos(dd))
   print(s)
end
