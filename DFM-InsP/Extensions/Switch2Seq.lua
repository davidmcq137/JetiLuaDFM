local M = {}

function M.value(ptr, v)
   local val
   if v and type(v) == "number" then val = v else val = 0 end
   if val > 0.5 then return 3 elseif val < -0.5 then return 1 else return 2 end 
end

return M

