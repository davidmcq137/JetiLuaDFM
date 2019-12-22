local function init()
   print("init")
end

local result = 0

system.registerLogVariable("Virtual Var","Cnt",(function(index) result = result + 1 return result end))

return {init=init, author="JETI model", version="1.0"}
