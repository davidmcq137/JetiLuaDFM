local appName="Renderer Test"
local imageInfo
-- Crete a polyline
local ren=lcd.renderer()
ren:addPoint(5,75)
ren:addPoint(10,50)
ren:addPoint(20,100)
ren:addPoint(30,75)
ren:addPoint(50,75)
-- Create an arrow
local renShape=lcd.renderer()
local homeShape = {
 { 0, -50},
 {-40, 40},
 { 0, 20},
 { 40, 40}
}
local heading = 0
--------------------------------------------------------------------
-- Draw a shape
--------------------------------------------------------------------
local function drawShape(col, row, shape, rotation)
 sinShape = math.sin(rotation)
 cosShape = math.cos(rotation)
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
local function printForm(x,y)
 print("F",x,y)
 lcd.setColor(lcd.getFgColor())
 ren:renderPolyline(4)
 drawShape(200, 80, homeShape, math.rad(heading))
 lcd.drawRectangle(0,0,309,142)
 lcd.drawRectangle(0,0,x-1,y-1)
 lcd.drawCircle(200,80,40)
 lcd.drawLine(0, 80, 309, 80)
 lcd.drawLine(200, 0, 200, 142)
end

local function printTele(x,y)

   lcd.setColor(255,255,0)
   lcd.drawImage(0,0,imageInfo)
 ren:renderPolyline(4)
 drawShape(200, 80, homeShape, math.rad(heading))
 lcd.drawRectangle(0,0,319,159)
 local i = math.floor(100*(1+system.getInputs("P4"))/2)
 --print("T", x,y,i, (y-i)-1)
 lcd.drawRectangle(0,0,x-1,(y-i)-1)
 lcd.drawCircle(200,80,40)
 lcd.drawLine(0, 80, 319, 80)
 lcd.drawLine(200, 0, 200, 159)
 local txt = string.format("w %d h %d i %d (y-i)-1 %d", x,y,i,(y-i)-1)
 lcd.drawText(10,10,txt)
end

local function loop()
 heading = (heading + 1) % 360
end

--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function init()
   system.registerForm(1,MENU_APPS,appName,initForm,nil,printForm)
   system.registerTelemetry(1, "Tele 1", 4, printTele)
   local ss, ii
   ss, ii = system.getDeviceType()
   print("ss,ii", ss, ii)
   
   imageInfo = lcd.loadImage("Apps/DFM-LSO/BDS_2000_ft.png")
   print("imageInfo", imageInfo, imageInfo.width, imageInfo.height)
end

return { init=init, loop=loop, author="JETI model", version="1.00",name=appName}
