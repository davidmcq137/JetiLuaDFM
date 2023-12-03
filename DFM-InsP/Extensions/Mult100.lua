local M = {}

function M.value(ptr, v)
   local val
   if v and type(v) == "number" then val = v else val = 0 end
   return val * 100.
end

return M

