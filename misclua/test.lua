local ren
local time=0
local radius = 100
local count = 0

local function initForm()
end

local function printForm()
end

local function closeForm()
end

local function loop()
end

local function destroy()
end

local newImage = {}
local lastx, lasty

local function printTele(w,h)

   count=count+1
   time = time + 0.1
   --radius = radius + 0.05
   local x = 2*radius*math.sin(5.11*time/10)
   local y = 1.2*radius*math.cos(7.43*time/10)
   --print(count,w/2+x,h/2+y)
   ren:reset()
   if lastx then
      ren:addPoint(w/2 + x, h/2 + y)
      ren:addPoint(w/2 + lastx, h/2 + lasty)
      lcd.setColor(0,0,255)
      ren:renderPolyline(2)
   end
   
   if newImage then
      lcd.drawImage(0,0,newImage)
   end

   lcd.setColor(0,0,0)
   lcd.drawNumber(10,10, count)
   lcd.drawNumber(10,30, system.getCPU())
   if lastx then
      lcd.drawText(10,50, string.format("%.2f", math.sqrt((x - lastx)^2 + (y-lasty)^2)))
   end
   
   lastx = x; lasty = y

   if radius > h/2 then radius = 10 end
   
end

local function init()
   system.registerForm(1, MENU_APPS, "Test", initForm, printForm, closeForm)
   system.registerTelemetry(1, "Tele", 4, printTele)
   newImage = lcd.createImage(460, 350)
   --newImage = lcd.loadImage("Apps/DFM-Maps/Maps/A74/16.png")
   if newImage then
      print("newImage.width, newImage.height", newImage.width, newImage.height)
      ren = lcd.renderer(newImage)
      --ren:reset()
   else
      print("lcd.createImage failed")
   end
   system.setProperty("NativeDraw", 1)
   
end


return {init=init, loop=loop,name="testapp",destroy=destroy}
