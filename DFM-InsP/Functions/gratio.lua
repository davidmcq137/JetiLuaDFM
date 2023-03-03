local M = {}


function M.gratio(airspeed, vario)

   local glideRatio
   local arg
   local maxRatio = 1000

   print("M.gratio", airspeed, vario)
   if not airspeed or not vario then return 0 end
   if math.abs(airspeed / vario) < maxRatio then
      arg = airspeed*airspeed - vario*vario
      if arg > 0 then
	 glideRatio = math.sqrt(arg) / vario
      else
	 glideRatio = airspeed / vario
      end
   else
      glideRatio = maxRatio
   end
   print("return", glideRatio)
   return glideRatio
end

return M

