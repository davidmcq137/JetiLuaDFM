--[[

   polytest.lua - app to demonstrate polygon
   DFM 01/10/2023

   measured coords for overall shape were
   
   226,59
   231,41
   313,26
   302,226
   
   subtracted 200 from all the X's to get a local measurement for trap {}

--]]

local function loop()
end

local rgb = {}

local function drawShape(shape, xoff, mirror)

   local ren = lcd.renderer()
   
   local mult
   if mirror then mult = -1 else mult = 1 end

   ren:reset()
   for i,t in ipairs(shape) do
      ren:addPoint(xoff + mult * t.x, t.y)
   end
   ren:renderPolygon(alp)

end

local function printForm(w,h)

   trap = {
      {x=26,y=59},
      {x=31,y=41},
      {x=113,y=26},
      {x=102,y=62}
   }
   
   local ren = lcd.renderer()

   local alp = 1.0

   local midX = w/2
   local ctl = 0.5 * (1 + system.getInputs("P1"))

   -- doing the rendering "by hand"
   
   local cctl = 0.5 * (1 + system.getInputs("P2"))
   local idx = math.floor(1 + cctl * 9)
   lcd.setColor(rgb[idx].r, rgb[idx].g, rgb[idx].b)
   
   ren:reset()
   for i,t in ipairs(trap) do
      ren:addPoint(midX + t.x, t.y)
   end
   ren:renderPolygon(alp)

   -- doing it with a function (more convenient)
   
   lcd.setColor(0,255,0)
   drawShape(trap, midX, true)
   
   -- now do something fancier
   
   local tslope = (trap[2].y - trap[3].y) / (trap[2].x - trap[3].x)
   local tlenX  = trap[3].x - trap[2].x

   local bslope = (trap[1].y - trap[4].y) / (trap[1].x - trap[4].x)
   local blenX  = trap[4].x - trap[1].x
   
   lcd.setColor(255,0,0)
   ren:reset()
   ren:addPoint(midX + trap[1].x, trap[1].y + 60)
   ren:addPoint(midX + trap[2].x, trap[2].y + 60)
   ren:addPoint(midX + trap[2].x + ctl * tlenX, trap[2].y + ctl*tlenX*tslope + 60)
   ren:addPoint(midX + trap[1].x + ctl * blenX, trap[1].y + ctl*blenX*bslope + 60)         
   ren:renderPolygon(alp)

   lcd.setColor(255,255,0)
   ren:reset()
   ren:addPoint(midX - trap[1].x, trap[1].y + 60)
   ren:addPoint(midX - trap[2].x, trap[2].y + 60)
   ren:addPoint(midX - (trap[2].x + ctl * tlenX), trap[2].y + ctl*tlenX*tslope + 60)
   ren:addPoint(midX - (trap[1].x + ctl * blenX), trap[1].y + ctl*blenX*bslope + 60)         
   ren:renderPolygon(alp)

   lcd.setColor(0,0,0)
   
   str = string.format("CPU: %d%%", system.getCPU())
   lcd.drawText(240, 140, str)

end

local function init()

   system.registerTelemetry(1, "polytest window", 4, printForm)

   --A nice 9-point and 10-point RGB gradient that looks good on top of the map
   --
   --From: https://learnui.design/tools/gradient-generator.html
   --
   --(#ff4d00, #ff6b00, #ffb900, #d7ff01, #5aff01, #02ff27, #03ff95, #03ffe2, #03ffff)
   --(#ff4d00, #ff6500, #ffa400, #ffff01, #93ff01, #21ff02, #02ff4e, #03ffa9, #03ffe8, #03ffff)
   --to use these put in a table e.g.
   --
   -- gradient = {"ff4d00", "ff6b00", ...}
   --

   --[[
   for k,v in ipairs(gradient) do
      rgb[k] = {}
      rgb[k].r, rgb[k].g, rgb[k].b =  string.match(v, ("(%w%w)(%w%w)(%w%w)"))
      rgb[k].r = (tonumber(rgb[k].r, 16) or 0)
      rgb[k].g = (tonumber(rgb[k].g, 16) or 0)
      rgb[k].b = (tonumber(rgb[k].b, 16) or 0)       
      --print(k, rgb[k].r, rgb[k].g, rgb[k].b)
   end
   --]]

   
   -- trig functions approximate shapes of rgb ranbow color components ... cute 
   -- https://en.wikibooks.org/wiki/Color_Theory/Color_gradient  
   -- the 0.7 is so we don't wrap all the way back to the original color

   local rp = 10
   for k = 1, rp, 1 do
      rgb[k] = {}
      rgb[k].r = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp)) / 2)
      rgb[k].g = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 2*math.pi/3)) / 2)
      rgb[k].b = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 4*math.pi/3)) / 2)
   end

end

return {init=init, loop=loop, author="DFM", version="1", name="polytest.lua"}


