local val, st, dt
local function loop()

   val = system.getInputs("P2")
   st = system.getInputs("SA")
   dt = system.getInputs("SB")

end

local function printTele()
   lcd.setColor(0,0,0)
   lcd.drawRectangle(10,10,50+1,100+1)
   
   for i=1,9 do
      lcd.drawLine(10 + i*5, 110, 10 + i*5, 100)
   end

   for i=1,9 do
      lcd.drawLine(10, 10 + i*10, 20, 10 + i*10)
   end

   --lcd.drawLine(60, 0, 60, 120)
end

local function printForm()

end

local function init()

   print("enter init")
   system.registerTelemetry(1, "Tele 1", 4, printTele)
   
end

return {init=init, loop=loop, author="DFM", version="1", name="v.lua"}


