local M = {}

function M.value(ptr, v)
   local val
   if v and type(v) == "number" then val = v else val = 0 end
   return val * 1000.
end

return M

