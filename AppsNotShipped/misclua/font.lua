
local function loop()

end

local function printForm()

   fs = {FONT_MINI, FONT_NORMAL, FONT_BOLD, FONT_BIG, FONT_MAXI}
   fstr = {"FONT_MINI", "FONT_NORMAL", "FONT_BOLD", "FONT_BIG", "FONT_MAXI"}

   lcd.drawRectangle(0,0,318,159)
   lcd.setColor(255,255,255)
   --lcd.drawLine(0,0,318,0)
   lcd.setColor(0,0,0)
   
   for i=1,5,1 do
      lcd.drawText(10,22*(i-1), fstr[i] .. " H: " ..lcd.getTextHeight(fs[i]) .." Font Test xyzwXYZW 123$%^ " , fs[i])
   end
   
end

local function init()

   system.registerForm(1, MENU_APPS, "test", initForm, nil, nil)
   system.registerTelemetry(1, "test", 4, printForm)

end



return {init=init, loop=loop, author="DFM", version="1", name="font.lua"}


