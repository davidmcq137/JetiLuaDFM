local M = {}

function M.drawShape(col, row, shape, rotation, color)
   
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
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

function M.drawRibbon(savedXP, xp, yp, curX, curY)
   for i=2,#savedXP do
      lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
   end
   lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
end

return M
