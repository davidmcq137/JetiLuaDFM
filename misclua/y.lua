local img, gimg, cfimg

local messages = { "Turbine status: Ready",
		   "Turbine status: Starting",
		   "Turbine status: Running",
		   "Turbine status: Idle",
		   "Turbine status: Cooling",
		   "Turbine status: Off"}

msgidx = 1
nextTime =0

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

local hSlider = {
   {0,0},
   {6,6},
   {-6,6}
}

local function drawShape(col, row, shape, f, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      --print(col, row, f, point[1], point[2])
      ren:addPoint(
	 col + (f*point[1] * cosShape - f*point[2] * sinShape + 0.5),
	 row + (f*point[1] * sinShape + f*point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

local function loop()

end

local function printForm()

   if cfimg then lcd.drawImage(0, 0, cfimg) end
   if gimg then lcd.drawImage(0, 0, gimg) end

   --print("gimg width", gimg.width)

   local ctl = system.getInputs("P5")

   ctl = (ctl+1)/2

   local rot = -0.75*math.pi * (1-ctl) + 0.75*math.pi*(ctl)

   --print("ctl, rot", ctl, math.deg(rot))

   --if true then return end
      
   lcd.setColor(255,255,255)

   local factor = 0.7
   drawShape(60,60, needle_poly_large, factor, rot + math.pi)

   factor = 0.6
   drawShape(160,45, needle_poly_large, factor, rot + math.pi)

   factor = 0.65
   drawShape(265,50, needle_poly_large, factor, rot + math.pi)
   drawShape(265,105, needle_poly_large, factor, rot + math.pi)   

   local sld = system.getInputs("P6")
   
   factor=1.3
   rot = 0.0
   drawShape(160 +sld*50, 90, hSlider, factor, rot + math.pi)      
   
   lcd.setColor(0,0,0)
   if system.getTimeCounter() > nextTime then
      msgidx = msgidx + 1
      if msgidx > #messages then msgidx = 1 end
      nextTime = system.getTimeCounter() + 1000*2
   end
   
   local str = messages[msgidx]
   lcd.drawText(160 - lcd.getTextWidth(FONT_BOLD, str)/2, 140 - lcd.getTextHeight(FONT_BOLD)/2, str, FONT_BOLD)

   lcd.setColor(255,255,255)
   --print("rot", math.deg(rot+math.pi))
   str = string.format("%.1f", ctl*100)
   lcd.drawText(60 - lcd.getTextWidth(FONT_MINI, str)/2, 90, str, FONT_MINI)
   str = "Power"
   lcd.drawText(60 - lcd.getTextWidth(FONT_NORMAL, str)/2, 100, str, FONT_NORMAL)
   --lcd.drawLine(80, 160, 80, 0)
   --lcd.drawLine(0, 80, 320,80)
   
end

local function init()

   print(system.registerTelemetry(1, "test window", 4, printForm))

   cfimg = lcd.loadImage("Apps/Gauges/cfimage.png")
   print("cfimg=", cfimg)
   --gimg = lcd.loadImage("Apps/misclua/roundG.png")
   gimg = lcd.loadImage("Apps/Gauges/panel320.png")   
   print("gimg=", gimg)

end

return {init=init, loop=loop, author="DFM", version="1", name="y.lua"}


