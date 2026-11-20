local appName="Renderer Test"
local im1
local im2
local heading = 0
local ren
local renShape
local homeShape
--------------------------------------------------------------------
-- Draw a shape
--------------------------------------------------------------------
local function drawShape(col, row, shape, rotation)
   local sinShape = math.sin(rotation)
   local cosShape = math.cos(rotation)
   renShape:reset()
   for index, point in pairs(shape) do
      renShape:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      )
   end
   renShape:renderPolygon()
end
--------------------------------------------------------------------
-- Init-Form function
--------------------------------------------------------------------
local function initForm(formId)
end
--------------------------------------------------------------------
-- Print function
--------------------------------------------------------------------
local function printTele(w,h)
   lcd.setColor(lcd.getFgColor())
   ren:renderPolyline(4)
   drawShape(200, 80, homeShape, math.rad(heading))
   lcd.drawImage(0,0,im1)
   lcd.drawImage(0,0,im2)
end
local function loop()
   heading = (heading + 1) % 360
end
--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function init()
   system.registerTelemetry(1, "Tele", 4, printTele)
   -- Create a polyline
   im1 = lcd.createImage(320,160)
   print("im1 width height", im1.width, im1.height, type(im1.data))
   ren=lcd.renderer(im1)
   ren:reset()
   ren:addPoint(5,75)
   ren:addPoint(10,50)
   ren:addPoint(20,100)
   ren:addPoint(30,75)
   ren:addPoint(50,75)
   -- Create an arrow
   im2 = lcd.createImage(320, 160)
   print("im2 width height", im2.width, im2.height, type(im2.data))
   renShape=lcd.renderer(im2)
   renShape:reset()
   homeShape = {
      { 0, -50},
      {-40, 40},
      { 0, 20},
      { 40, 40}
   }
   heading = 0
end
return { init=init, loop=loop, author="JETI model", version="1.00",name=appName}
