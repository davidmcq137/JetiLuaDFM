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

   if not speed then return -9000 end
   if not vario then return -9001 end

   print("speed, vario", speed, vario)
   
   if math.abs(speed / vario) < maxRatio then
      arg = speed*speed - vario*vario
      if arg > 0 then
	 glideRatio = math.sqrt(arg) / vario
      else
	 glideRatio = speed / vario
      end
   else
      if speed / vario >= 0 then
	 glideRatio = maxRatio
      else
	 glideRatio = -maxRatio
      end
   end
   return glideRatio
end

return M

