local M = {}

local LiFe={
   {s=100.00,v=3.59},
   {s=95.71,v=3.32},
   {s=91.47,v=3.316},
   {s=87.09,v=3.313},
   {s=82.85,v=3.306},
   {s=78.54,v=3.304},
   {s=74.18,v=3.29},
   {s=69.92,v=3.28},
   {s=65.61,v=3.278},
   {s=61.31,v=3.276},
   {s=57.05,v=3.274},
   {s=52.74,v=3.272},
   {s=48.46,v=3.269},
   {s=44.14,v=3.266},
   {s=39.83,v=3.263},
   {s=35.55,v=3.25},
   {s=31.24,v=3.24},
   {s=26.87,v=3.23},
   {s=22.59,v=3.22},
   {s=18.24,v=3.20},
   {s=13.88,v=3.19},
   {s=9.63,v=3.17},
   {s=5.35,v=3.12},
   {s=1.01,v=2.90}
}

function M.LiFeV(SOC)

   local ds

   if SOC >= LiFe[1].s then return LiFe[1].v end
   if SOC <= LiFe[#LiFe].s then return LiFe[#LiFe].v end

   for i=1, #LiFe-1 do
      if SOC >= LiFe[i+1].s and SOC <=LiFe[i].s then
	 ds = (SOC - LiFe[i+1].s) / (LiFe[i].s - LiFe[i+1].s)
	 return LiFe[i+1].v + ds * (LiFe[i].v - LiFe[i+1].v)
      end
   end
end

function M.LiFeS(Volt)

   local dv
   
   if Volt >= LiFe[1].v then return LiFe[1].s end
   if Volt <= LiFe[#LiFe].v then return LiFe[#LiFe].s end

   for i=1, #LiFe-1 do
      if Volt >= LiFe[i+1].v and Volt <=LiFe[i].v then
	 dv = (Volt - LiFe[i+1].v) / (LiFe[i].v - LiFe[i+1].v)
	 return LiFe[i+1].s + dv * (LiFe[i].s - LiFe[i+1].s)
      end
   end
end

return M

