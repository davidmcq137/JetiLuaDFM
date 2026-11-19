--[[
   GlobW.lua - writer half of a throwaway declareGlobal test (with GlobR.lua)

   Questions:
   1. declareGlobal(name, localTable): does the global hold that same table,
      or a copy? (GT_Init)
   2. Are changes made in place through the writer's local seen by other
      apps? (GT_Init.n, GT_Assign.n)
   3. Reassigning a number, as DFM-Rscu does (GT_Num), and a table
      assigned after declaring, as DFM-Maps does (GT_Assign)

   Every second the writer bumps a counter and writes it four ways;
   GlobR prints what another app sees. Both stop printing after 30 s.
--]]

--luacheck: globals declareGlobal GT_Init GT_Assign GT_Num GT_Fresh

local tInit = {n = 0}          -- passed to declareGlobal as the initial value
local tAssign = {n = 0}        -- assigned to the global after declaring it
local count, nextT, t0 = 0, 0, 0

local function loop()
   local now = system.getTimeCounter()
   if now < nextT or now - t0 > 30000 then return end
   nextT = now + 1000
   count = count + 1
   tInit.n = count             -- in place, through the local
   tAssign.n = count           -- in place, through the local
   if declareGlobal then
      GT_Num = count           -- reassign a number
      GT_Fresh = {n = count}   -- a new table each time
   end
   print(string.format("GlobW %2d: wrote %d; here GT_Init is tInit: %s, GT_Assign is tAssign: %s",
		       count, count, tostring(rawequal(GT_Init, tInit)),
		       tostring(rawequal(GT_Assign, tAssign))))
end

local function init()
   t0 = system.getTimeCounter()
   local dev, emu = system.getDeviceType()
   print("GlobW: " .. tostring(dev) .. (emu == 1 and " (emulator)" or "") ..
	 ", declareGlobal " .. (declareGlobal and "present" or "MISSING"))
   if declareGlobal then
      declareGlobal("GT_Init", tInit)
      declareGlobal("GT_Assign", 0)
      GT_Assign = tAssign
      declareGlobal("GT_Num", 0)
      declareGlobal("GT_Fresh", 0)
   end
end

return {init = init, loop = loop, author = "DFM", version = "0.1", name = "GlobW"}
