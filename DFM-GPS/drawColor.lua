local M = {}

local function setTextColor()
   local colorCode = system.getProperty("Color")
   if colorCode <= 6 or colorCode == 8 then
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
end

local function setColor(type)
   local colorCode = system.getProperty("Color")
   if colorCode <= 6 then -- white bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(0,255,0)
      end
   elseif colorCode == 7 then -- blue bg
      if type == "In" then
	 lcd.setColor(255,160,16)
      else
	 lcd.setColor(96,255,128)
      end
   elseif colorCode == 8 then -- yellow bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(96,255,128)
      end
   else -- black bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(0,192,0)
      end
   end
end

function M.drawShape(col, row, shape, rotation, type)
   local sinShape, cosShape
   local ren = lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   setColor(type)
   ren:reset()
   for i, _ in pairs(shape) do
      ren:addPoint(
	 col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	 row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5)
      )
   end
   ren:renderPolygon()
   setTextColor()
end

function M.drawNFZ(nfz, mapV, xp, yp)
   local ren = lcd.renderer()
   local n
   local x0,y0,r
   local npc=30
   for i in ipairs(nfz) do
      if nfz[i].type == "inside" then
	 setColor("In")
      else
	 setColor("Out")
      end
      if nfz[i].shape == "polygon" then
	 n = #nfz[i].xy
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j = 1, n+1, 1 do 
	    ren:addPoint(xp(nfz[i].xy[j % n + 1].x),
			 yp(nfz[i].xy[j % n + 1].y))
	 end
	 ren:renderPolyline(2,1.0)
      elseif nfz[i].shape == "circle" then
	 x0 = xp(nfz[i].xy[1].x)
	 y0 = yp(nfz[i].xy[1].y)
	 r = 320*nfz[i].radius/(mapV.xmax-mapV.xmin)
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j=0,npc,1 do
	    ren:addPoint(x0 + r * math.sin(2*math.pi*j/npc),
			 y0 + r * math.cos(2*math.pi*j/npc))
	 end
	 ren:renderPolyline(2,1.0)
      end
   end
   setTextColor()
end

function M.drawRibbon(savedXP, savedYP, xp, yp, curX, curY)
   local ren = lcd.renderer()
   lcd.setColor(lcd.getFgColor())
   ren:reset()
   for i=2,#savedXP do
      ren:addPoint(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
   end
   ren:addPoint(xp(curX), yp(curY))
   ren:renderPolyline(1,0.7)
   setTextColor()
end

return M
