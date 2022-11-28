local M = {}

local function setTextColor()
   local bgr, bgg, bgb = lcd.getBgColor()
   if bgr + bgg + bgb > 384 then
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
end

local function setBgMixColor(r,g,b,alpha)
   local bgr, bgg, bgb = lcd.getBgColor()
   local alphaDot = 1 - alpha
   lcd.setColor(bgr*alphaDot + r*alpha, bgg*alphaDot + g*alpha, b*alphaDot + bgb*alpha)
end

local function setMixColor(alpha)
   local bgr, bgg, bgb = lcd.getBgColor()
   if bgr+bgg+bgb > 384 then
      bgr, bgg, bgb = 0, 0, 0
   else
      bgr, bgg, bgb =255, 255, 255
   end
   local r,g,b = lcd.getFgColor()
   --r,g,b = 255-r, 255-g, 255-b
   local alphaDot = 1 - alpha
   print(alpha, alphaDot, bgr*alphaDot + r*alpha, bgg*alphaDot + g*alpha, bgb*alphaDot + b*alpha)
   lcd.setColor(bgr*alphaDot + r*alpha, bgg*alphaDot + g*alpha, bgb*alphaDot + b*alpha)
end

local function setFgMixColor(r,g,b,alpha)
   local bgr, bgg, bgb = lcd.getFgColor()
   local alphaDot = 1 - alpha 
   lcd.setColor(bgr*alphaDot + r*alpha, bgg*alphaDot + g*alpha, b*alphaDot + bgb*alpha)
end

function M.drawShape(col, row, shape, rotation, r, g, b, alpha)
   local sinShape, cosShape
   local ren = lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   if alpha then
      setBgMixColor(r, g, b, alpha)
   else
      lcd.setColor(lcd.getFgColor())
   end
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
   for i in ipairs(nfz) do
      print(i, nfz[i].type)
      if nfz[i].type == "inside" then
	 setMixColor((system.getInputs("P4") + 1) / 2)
      else
	 setMixColor((system.getInputs("P1") + 1) / 2)	 
      end
      if nfz[i].shape == "polygon" then
	 n = #nfz[i].xy
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j = 1, n+1, 1 do 
	    ren:addPoint(xp(nfz[i].xy[j % n + 1].x),
			 yp(nfz[i].xy[j % n + 1].y))
	 end
	 ren:renderPolyline(2,0.5)
      elseif nfz[i].shape == "circle" then
	 x0 = xp(nfz[i].xy[1].x)
	 y0 = yp(nfz[i].xy[1].y)
	 r = 320*nfz[i].radius/(mapV.xmax-mapV.xmin)
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j=0,20,1 do
	    ren:addPoint(x0 + r * math.sin(2*math.pi*j/20),
			 y0 + r * math.cos(2*math.pi*j/20))
	 end
	 ren:renderPolyline(2,1.0)
      end
   end
   setTextColor()
end

function M.drawRibbon(savedXP, savedYP, xp, yp, curX, curY)
   local ren = lcd.renderer()
   ren:reset()
   for i=2,#savedXP do
      ren:addPoint(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
   end
   ren:addPoint(xp(curX), yp(curY))
   ren:renderPolyline(1,1)
   setTextColor()
end

return M
