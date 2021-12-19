--[[

   Test app to play with TCA app .. create multiple copies to demo/test multiple tele windows

   17-Dec-2021 D. McQueeney
   Released 12/2021 MIT license

--]]

local sn

if not sharedNum then
   sharedNum = 1
else
   sharedNum = sharedNum + 1
end

sn = sharedNum

local r=60
local vx=6
local theta = 0
local dt = 2*math.pi / vx
local dp = 0
local icol = 1
local show = true
local rgb={}

local function telePrint(wx, wy, key)
   if key == KEY_DOWN then
      dp = dp - math.pi / 50 
   elseif key == KEY_UP then
      dp = dp + math.pi / 50
   elseif key == KEY_1 then
      dp = 0
      icol = 1
   elseif key == KEY_2 then
      vx = vx + 1
      if vx > 12 then vx = 12 end
      dt = 2*math.pi/vx
   elseif key == KEY_3 then
      vx = vx - 1
      if vx < 3 then vx = 3 end
      dt = 2*math.pi/vx
   elseif key == KEY_4 then
      icol = icol + 1
      if icol > 10 then icol = 1 end
   elseif key == KEY_ENTER then
      show = not show
   elseif key and key ~= 0 then
      print("key:", key)
   end

   lcd.setColor(rgb[icol].r, rgb[icol].g, rgb[icol].b)
   
   local dt = 2*math.pi / vx 
   while theta <= 2*math.pi - dt do
      p1x = 310/2 + r * math.cos(theta + dp)
      p1y = 160/2 + r * math.sin(theta + dp)
      p2x = 310/2 + r * math.cos(theta + dt + dp)
      p2y = 160/2 + r * math.sin(theta + dt + dp)
      lcd.drawLine(p1x, p1y, p2x, p2y)
      theta = theta + dt
   end
   theta = 0
   if show then
      lcd.setColor(0,0,0)
      lcd.drawText(10,10, "Edges: " .. vx)
      lcd.drawText(10,30, "Theta: " .. string.format("%.2f", dp * 360 / math.pi))
      lcd.drawText(10,140, "3D wheel to rotate")
   end

   return "Edges: " .. vx .. "  Theta: " .. string.format("%.2f", dp * 360 / math.pi)
end

local function loop()
end

local function init()
   system.registerTelemetry(1, "Tele Test"..sn, 4, telePrint, {"RST", "E+", "E-", "RGB"})

   --create a nice color gradient with <rp> levels
   
   local rp = 10
   for k = 1, rp, 1 do
      rgb[k] = {}
      rgb[k].r = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp)) / 2)
      rgb[k].g = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 2*math.pi/3)) / 2)
      rgb[k].b = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 4*math.pi/3)) / 2)
   end

   print("sharedNum:", sharedNum, sn)
end

icol = 1 + sn % 10
vx = sn + 2

return {init=init, loop=loop, author="DFM", version="1", name="Test " .. sn}
