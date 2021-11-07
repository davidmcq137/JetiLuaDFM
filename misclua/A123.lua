local A123 = {}

local LiFe={}
LiFe[1]={s=100.00,v=3.59}
LiFe[2]={s=95.71,v=3.32}
LiFe[3]={s=91.47,v=3.31}
LiFe[4]={s=87.09,v=3.31}
LiFe[5]={s=82.85,v=3.30}
LiFe[6]={s=78.54,v=3.30}
LiFe[7]={s=74.18,v=3.29}
LiFe[8]={s=69.92,v=3.28}
LiFe[9]={s=65.61,v=3.27}
LiFe[10]={s=61.31,v=3.27}
LiFe[11]={s=57.05,v=3.27}
LiFe[12]={s=52.74,v=3.27}
LiFe[13]={s=48.46,v=3.26}
LiFe[14]={s=44.14,v=3.26}
LiFe[15]={s=39.83,v=3.26}
LiFe[16]={s=35.55,v=3.25}
LiFe[17]={s=31.24,v=3.24}
LiFe[18]={s=26.87,v=3.23}
LiFe[19]={s=22.59,v=3.22}
LiFe[20]={s=18.24,v=3.20}
LiFe[21]={s=13.88,v=3.19}
LiFe[22]={s=9.63,v=3.17}
LiFe[23]={s=5.35,v=3.12}
LiFe[24]={s=1.01,v=2.90}


function A123.Volt(SOC)

   --print("a123: SOC", SOC)
   if SOC >= LiFe[1].s then return LiFe[1].v end
   if SOC <= LiFe[#LiFe].s then return LiFe[#LiFe].v end

   for i=1, #LiFe-1 do
      if SOC >= LiFe[i+1].s and SOC <=LiFe[i].s then
	 ds = (SOC - LiFe[i+1].s) / (LiFe[i].s - LiFe[i+1].s)
	 --print("a123: ret:", LiFe[i+1].v + ds * (LiFe[i].v - LiFe[i+1].v))
	 return LiFe[i+1].v + ds * (LiFe[i].v - LiFe[i+1].v)
      end
   end
end

return A123
