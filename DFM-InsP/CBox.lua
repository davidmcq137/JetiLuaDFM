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

local dC = {LiFe=LiFe}

function M.Volt(SOC, batt)

   local ds

   if not dC[batt] then return "no curve for " .. batt end
   if SOC >= dC[batt][1].s then return dC[batt][1].v end
   if SOC >= dC[batt][1].s then return dC[batt][1].v end
   if SOC <= dC[batt][#dC[batt]].s then return dC[batt][#dC[batt]].v end

   for i=1, #dC[batt]-1 do
      if SOC >= dC[batt][i+1].s and SOC <=dC[batt][i].s then
	 ds = (SOC - dC[batt][i+1].s) / (dC[batt][i].s - dC[batt][i+1].s)
	 return dC[batt][i+1].v + ds * (dC[batt][i].s - dC[batt][i+1].v)
      end
   end
end

function M.SOC(Volt, batt)

   local dv

   if not dC[batt] then return "rt: no curve for " .. batt end
   if Volt >= dC[batt][1].v then return dC[batt][1].s end
   if Volt <= dC[batt][#dC[batt]].v then return dC[batt][#dC[batt]].s end

   for i=1, #dC[batt]-1 do
      if Volt >= dC[batt][i+1].v and Volt <=dC[batt][i].v then
	 dv = (Volt - dC[batt][i+1].v) / (dC[batt][i].v - dC[batt][i+1].v)
	 return dC[batt][i+1].s + dv * (dC[batt][i].s - dC[batt][i+1].s)
      end
   end
end

function M.text(env, line, battType)
   local _ENV = env

   if line == 1 then
      return string.format("Batt1 %.2fV  SOC: %d%%",
			   CBOX200_UAccu1, M.SOC(CBOX200_UAccu1 / 2, battType))
   elseif line == 2 then
      return string.format("Batt2 %.2fV  SOC: %d%%",
			   CBOX200_UAccu2, M.SOC(CBOX200_UAccu2 / 2, battType))
   elseif line == 3 then
      return string.format("Batt1 Cap %d maH", CBOX200_Capacity1)
   elseif line == 4 then
      return string.format("Batt2 Cap %d maH", CBOX200_Capacity2)
   end
end

return M

