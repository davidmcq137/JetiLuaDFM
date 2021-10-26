
local r,g,b

local function loop()

   local i8, i7, i6 = system.getInputs("P8", "P7", "P6")

   r = math.floor((i8+1)/2 * 255)
   g = math.floor((i7+1)/2 * 255)
   b = math.floor((i6+1)/2 * 255)

end

local function printForm()
   
   lcd.setColor(0,0,0)
   lcd.drawText(10,10, "r: " .. tostring(r) .. " g: " .. tostring(g) .. " b: " .. tostring(b))
   lcd.setColor(r,g,b)
   lcd.drawFilledRectangle(40,40,40,40)

end

local function init()
   system.registerForm(1, MENU_APPS, "RGB Display", initForm, nil, printForm)
end



return {init=init, loop=loop, author="DFM", version="1", name="DFM-RGB.lua"}


