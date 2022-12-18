local img, gimg

local needle_poly_large = {
   {-1,0},
   {-2,1},
   {-4,4},
   {-1,58},
   {1,58},
   {4,4},
   {2,1},
   {1,0}
}

local function drawShape(col, row, shape, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

local function loop()

end

local function printForm()

   if cfimg then lcd.drawImage( (320-cfimg.width) / 2, 0, cfimg) end
   if gimg then lcd.drawImage( (320-gimg.width) / 2, 0, gimg) end

   local ctl = system.getInputs("P5")

   ctl = (ctl+1)/2

   local rot = -0.75*math.pi * (1-ctl) + 0.75*math.pi*(ctl)

   print("ctl, rot", ctl, math.deg(rot))

   lcd.setColor(255,255,255)
   drawShape(80,80, needle_poly_large, rot + math.pi)
   print("rot", math.deg(rot+math.pi))
   local str = string.format("%.1f", ctl*100)
   lcd.drawText(80 - lcd.getTextWidth(FONT_NORMAL, str)/2, 120, str)
   str = "Power"
   lcd.drawText(80 - lcd.getTextWidth(FONT_BOLD, str)/2, 137, str, FONT_BOLD)
   --lcd.drawLine(80, 160, 80, 0)
   --lcd.drawLine(0, 80, 320,80)
   
end

local function init()

   print(system.registerTelemetry(1, "test window", 4, printForm))

   cfimg = lcd.loadImage("Apps/misclua/cfimage.png")
   print("cfimg=", cfimg)
   --gimg = lcd.loadImage("Apps/misclua/roundG.png")
   gimg = lcd.loadImage("Apps/misclua/tripG.png")   
   print("gimg=", gimg)
   
end

return {init=init, loop=loop, author="DFM", version="1", name="y.lua"}


