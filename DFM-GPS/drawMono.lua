local M = {}

local savedXP = {}
local savedYP = {}
local MAXSAVED
local heading

local shapes = {}
shapes.Glider =  {
   {0,-7},
   {-1,-2},
   {-14,0},
   {-14,2},	
   {-1,2},	
   {-1,8},
   {-4,8},
   {-4,10},
   {0,10},
   {4,10},
   {4,8},
   {1,8},
   {1,2},
   {14,2},
   {14,0},
   {1,-2}
}

function M.setMAX(max)
   MAXSAVED = 15
   return MAXSAVED
end

function M.clearPos()
   --savedPos = {}
   savedXP = {}
   savedYP = {}
end

function M.savePoints(mapV, curX, curY, lastX, lastY, xp, yp)

   --local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)

   if curX ~= lastX or curY ~= lastY then -- and dist > 5 then -- new point
      heading = math.atan(curX-lastX, curY - lastY)
      if #savedXP+1 > MAXSAVED then
	 --table.remove(savedPos, 1)
	 table.remove(savedXP, 1)
	 table.remove(savedYP, 1)
      else
	 --table.insert(savedPos, mapV.curPos)
	 table.insert(savedXP, xp(curX))
	 table.insert(savedYP, yp(curY))
      end
      lastX = curX
      lastY = curY
   end
   
   return lastX, lastY, heading
end

function M.drawShape(col, row, shapename, rotation, color)
   
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   --local shape = shapes[shapename]
   local shape = shapes.Glider -- monoTX fixed icon
   if not shape then print("DFM-GPS: bad shape", shapename); return end
   for i, _ in pairs(shape) do
      if i < #shape then
	 lcd.drawLine(
	    col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	    row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5),
	    col + (shape[i+1][1]*cosShape - shape[i+1][2]*sinShape + 0.5),
	    row + (shape[i+1][1] * sinShape + shape[i+1][2] * cosShape + 0.5)	    
	 )
      end
   end
   lcd.drawLine(
      col + (shape[#shape][1]*cosShape - shape[#shape][2]*sinShape + 0.5),
      row + (shape[#shape][1] * sinShape + shape[#shape][2] * cosShape + 0.5),
      col + (shape[1][1]*cosShape - shape[1][2]*sinShape + 0.5),
      row + (shape[1][1] * sinShape + shape[1][2] * cosShape + 0.5)
   )

end

function M.drawNFZ(nfz, mapV, xp, yp)
   for i in ipairs(nfz) do
      if nfz[i].shape == "polygon" then
	 local n = #nfz[i].xy
	 if n > 3 then
	    for j=1,n-1 do
	       lcd.drawLine(xp(nfz[i].xy[j].x),yp(nfz[i].xy[j].y),xp(nfz[i].xy[j+1].x),yp(nfz[i].xy[j+1].y))
	    end
	    lcd.drawLine(xp(nfz[i].xy[n].x),yp(nfz[i].xy[n].y),xp(nfz[i].xy[1].x),yp(nfz[i].xy[1].y))
	 end
      else
	 if nfz[i].xy and #nfz[i].xy > 0 then
	    lcd.drawCircle(xp(nfz[i].xy[1].x), yp(nfz[i].xy[1].y), 320*nfz[i].radius/(mapV.xmax-mapV.xmin))
	 end
      end
   end
end

function M.drawRibbon(xp, yp, curX, curY)
   if #savedXP < 3 then return end
   for i=2,#savedXP do
      lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
   end
   lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
end

return M
