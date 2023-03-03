local M = {}

-- Extension lua f(x) to return glideslope. Requested by H. Curzon. You must set
-- the sensor for the widget to the be the airspeed, and then you must create a
-- lua variable attached to the vario sensor and MUST name the lua variable "vario"
-- (sorry!)

function M.val(ptr, val)

   local speed
   local vario
   local glideRatio
   local arg
   local maxRatio = 1000
   
   speed = val
   for i,v in ipairs(ptr.variables) do
      if v.name == "vario" then
	 vario = v.value
      end
   end
   if not speed or not vario then return 0 end
   if math.abs(speed / vario) < maxRatio then
      arg = speed*speed - vario*vario
      if arg > 0 then
	 glideRatio = math.sqrt(arg) / vario
      else
	 glideRatio = speed / vario
      end
   else
      glideRatio = maxRatio
   end
   return glideRatio
end

return M

