local swItem

local function loop()

end


local function ccb(var)
   print("ccb", var)
   swItem = var
   print("JSON:", json.encode(swItem))
end

local function initForm(sf)
   print("initForm", sf)
   form.addRow(2)
   form.addLabel({label="Switch test"})
   form.addInputbox(selSw, true, ccb)
end

local function init()
   print("init")
   local a = system.registerForm(1, MENU_APPS, "sw test form", initForm)
   print("a", a)
end

return {init=init, loop=loop, author="DFM", version="1", name="sw.lua"}


