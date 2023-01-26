local M = {}

-- https://blog.ampow.com/lipo-voltage-chart/

local LiPo={
   {s=100, v=4.2},
   {s=95,  v=4.15},
   {s=90,  v=4.11},
   {s=85,  v=4.08},
   {s=80,  v=4.02},
   {s=75,  v=3.98},
   {s=70,  v=3.95},
   {s=65,  v=3.91},
   {s=60,  v=3.87},
   {s=55,  v=3.85},
   {s=50,  v=3.84},
   {s=45,  v=3.82},
   {s=40,  v=3.80},
   {s=35,  v=3.79},
   {s=30,  v=3.77},
   {s=25,  v=3.75},
   {s=20,  v=3.73},
   {s=15,  v=3.71},
   {s=10,  v=3.69},
   {s= 5,  v=3.61},
   {s= 0,  v=3.27}
}

function M.LiPoV(SOC)

   local ds

   if SOC >= LiPo[1].s then return LiPo[1].v end
   if SOC <= LiPo[#LiPo].s then return LiPo[#LiPo].v end

   for i=1, #LiPo-1 do
      if SOC >= LiPo[i+1].s and SOC <=LiPo[i].s then
	 ds = (SOC - LiPo[i+1].s) / (LiPo[i].s - LiPo[i+1].s)
	 return LiPo[i+1].v + ds * (LiPo[i].v - LiPo[i+1].v)
      end
   end
end

function M.LiPoS(Volt)

   local dv
   
   if Volt >= LiPo[1].v then return LiPo[1].s end
   if Volt <= LiPo[#LiPo].v then return LiPo[#LiPo].s end

   for i=1, #LiPo-1 do
      if Volt >= LiPo[i+1].v and Volt <=LiPo[i].v then
	 dv = (Volt - LiPo[i+1].v) / (LiPo[i].v - LiPo[i+1].v)
	 return LiPo[i+1].s + dv * (LiPo[i].s - LiPo[i+1].s)
      end
   end
end

return M

