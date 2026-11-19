--[[
   GlobR.lua - reader half of the throwaway declareGlobal test; see GlobW.lua.
   Prints, once a second for 30 s, what this app sees of GlobW's globals.
--]]

--luacheck: globals GT_Init GT_Assign GT_Num GT_Fresh

local nextT, t0 = 0, 0

local function show(v)
   if type(v) == "table" then return "table n=" .. tostring(v.n) end
   return tostring(v)
end

local function loop()
   local now = system.getTimeCounter()
   if now < nextT or now - t0 > 30000 then return end
   nextT = now + 1000
   print(string.format("GlobR: GT_Num=%s  GT_Init=%s  GT_Assign=%s  GT_Fresh=%s",
		       show(GT_Num), show(GT_Init), show(GT_Assign), show(GT_Fresh)))
end

local function init()
   t0 = system.getTimeCounter()
end

return {init = init, loop = loop, author = "DFM", version = "0.1", name = "GlobR"}
