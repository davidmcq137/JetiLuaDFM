--[[

   DFM-Pong.lua released under MIT license by DFM 2022
   
   Started Apr 2023

--]]

local PongVersion = 0.77

local LE

local Pong = {}

local function drawShape(col, row, shape, f, rotation, x0, y0, r, g, b)

   local sinShape, cosShape
   local ren = lcd.renderer()
   local fw = f -- ^0.55
   if not x0 then x0 = 0 end
   if not y0 then y0 = 0 end
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + ((fw*point[1]+x0) * cosShape - (f*point[2]+y0) * sinShape + 0.5),
	 row + ((fw*point[1]+x0) * sinShape + (f*point[2]+y0) * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
   if r and g and b then
      lcd.setColor(r,g,b)
      ren:renderPolyline(2)
   end
end

local function initForm(sf)

   subForm = sf

   if sf == 1 then
   elseif sf == 2 then
   end

end

local function loop()
end


local xb, yb = 160, 80
local dxb, dyb = math.random(2,3),math.random(2,3)

local xp1, yp1 = 10, 80
local xp2, yp2 = 310, 80
local dyp1, dyp2 = 0,0
local dyp1Max, dyp2Max = 6, 6

local xmin, xmax = 0, 318
local ymin, ymax = 0, 159

local xmid = 160
local ymid = 80

local ph = 16
local pw = 3
local bh = 3
local bw = 3

local ball = {{-bw,-bh}, {-bw,bh}, {bw,bh}, {bw,-bh}}
local paddle = {{-pw,-ph}, {-pw,ph}, {pw,ph}, {pw,-ph}}

local p1s = 0
local p2s = 0
local resume = 0
local speed = 1

local function hitpaddle(xb, yb, xp, yp)

   if math.abs(xb - xp) < pw + bw and math.abs(yb - yp) < ph + bh then
      return true
   else
      return false
   end

end

local function resetball()
   xb, yb = 160, 80
   dxb = math.random(2,4) * speed
   repeat 
      dyb = math.random(-3,3) * speed
      print("%")
   until math.abs(dyb) > 1.2
   --yp1 = ymid
   resume = system.getTimeCounter() + 1000
end

local function printForm(ww0, hh0, ff0)

   lcd.setColor(0,0,0)

   local p1str = string.format("%d", p1s)
   local p2str = string.format("%d", p2s)

   local dd = 30
   lcd.drawText((xmid - dd) - lcd.getTextWidth(FONT_MAXI, p1str) / 2, 10, p1str, FONT_MAXI)
   lcd.drawText((xmid + dd) - lcd.getTextWidth(FONT_MAXI, p2str) / 2, 10, p2str, FONT_MAXI)   

   local nw = 2
   local nh = 20
   local nd = 8
   
   lcd.setColor(100,100,100)

   for k=0,5,1 do
      lcd.drawFilledRectangle(xmid-nw, 3 + k*(nh+nd), nw*2, nh)
   end
   

   local pp = system.getInputs("P2")   
   local rs = 1.5 + system.getInputs("P8")
   local speed = 2 + system.getInputs("P7")
   --print("speed", speed)
   
   --print(pp)

   local db = 0.05
   
   if pp > db  then
      dyp2 = -dyp2Max
   elseif pp < -db then
      dyp2 = dyp2Max
   else
      dyp2 = 0
   end

   yp2 = yp2 + dyp2

   
   if yb > yp1 + bh then
      dyp1 = rs--dyp1Max
   elseif yb < yp1 - bh then
      dyp1 = -rs ---dyp1Max
   else
      dyp1 = 0
   end

   if (xb > xmid) or (dxb > 0) then dyp1 = 0 end

   yp1 = yp1 + dyp1
   
   if yp2 + ph > ymax then
      yp2 = ymax - ph
   elseif yp2 - ph < ymin then
      yp2 = ymin + ph
   end

   if yp1 + ph > ymax then
      yp1 = ymax - ph
   elseif yp1 - ph < ymin then
      yp1 = ymin + ph
   end
   
   if hitpaddle(xb, yb, xp1, yp1) or hitpaddle(xb, yb, xp2, yp2) then
      system.playFile("/Apps/DFM-Pong/bliphigh.wav", AUDIO_IMMEDIATE)
      dxb = -1 * dxb
      if xb > xmid then xb = xb - bw else xb = xb + bw end
      dyb = dyb +  math.random(-100,100) / 50
   else

   end

   lcd.setColor(0,0,255)
   
   drawShape(xp1, yp1, paddle, 1, 0)
   drawShape(xp2, yp2, paddle, 1, 0)

   if system.getTimeCounter() < resume then return end
   
   local hitwall = false
   
   xb = xb + dxb
   yb = yb + dyb

   if xb > xmax then
      --xb = xmax
      --dxb = -1 * dxb
      --hitwall = true
      p1s = p1s + 1
      system.playFile("/Apps/DFM-Pong/ballout.wav", AUDIO_IMMEDIATE)
      resetball()
      return
   elseif xb < xmin then
      p2s = p2s + 1
      system.playFile("/Apps/DFM-Pong/ballout.wav", AUDIO_IMMEDIATE)
      resetball()
      --xb = xmin
      --dxb = -1 * dxb
      --hitwall = true
   end

   if yb > ymax then
      yb = ymax
      dyb = -1 * dyb
      hitwall = true
   elseif yb < ymin then
      yb = ymin
      dyb = -1 * dyb
      hitwall = true
   end
   --local function drawShape(col, row, shape, f, rotation, x0, y0, r, g, b)

   --print(xb, yb)

   if hitwall then
      system.playFile("/Apps/DFM-Pong/bliplow.wav", AUDIO_IMMEDIATE)      
      dxb = dxb * 1.01
      dyb = dyb * 1.01
   end

   lcd.setColor(255,0,0)
   drawShape(xb, yb, ball, 1, 0)


   
end


local function init(icode)

   --readSensors()

   system.registerForm(1, MENU_APPS, "Pong", initForm)
   system.registerTelemetry(1, "Pong", 4,
			    (function(w,h) return printForm(w,h,1) end) )
   resetball()

end

return {init=init, loop=loop, author="DFM", version=PongVersion, name="DFM-Pong"}
