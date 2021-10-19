local ff
local count = 0
local sgTC0
local line
local done = false

local function loop()

   if done then return end
   
   for i = 1, 1000, 1 do
      line = io.readline(ff)
      count = count + 1
      if not line then break end
   end

   print(count, system.getCPU())
   
   if not line then
      done = true
      print("time:", (system.getTimeCounter() - sgTC0) / 1000) 
   end
end

local function printForm()

end

local function init()

   ff = io.open("Log/20210528/07-43-21.log", "r")
   print("ff:", ff)
   sgTC0 = system.getTimeCounter()
   system.registerForm(1, MENU_APPS, "test", initForm, nil, printForm)
   
end



return {init=init, loop=loop, author="DFM", version="1", name="x.lua"}


