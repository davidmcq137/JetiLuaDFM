local M = {}

local function drawPylons(xp, yp, F3G)
   local early = 0
   lcd.drawLine(xp(-50), yp(0), xp(200), yp(0))
   lcd.drawLine(xp(0), yp(-10), xp(0), yp(160))
   lcd.setColor(200,200,200)
   lcd.drawLine(xp(F3G.gpsP.distAB) - F3G.short150, yp(-10), xp(F3G.gpsP.distAB)-F3G.short150, yp(160))
   lcd.setColor(0,0,0)
   lcd.drawLine(xp(F3G.gpsP.distAB), yp(-10), xp(F3G.gpsP.distAB), yp(160))
   lcd.drawText(xp(0) - 4, yp(-10), "A")
   lcd.drawText(xp(F3G.gpsP.distAB) - 4, yp(-10), "B")
   if early > 0.1 then
      lcd.setColor(200,200,200)
      lcd.drawLine(xp(F3G.gpsP.distAB-early), yp(-10), xp(F3G.gpsP.distAB-early), yp(160))
      lcd.setColor(0,0,0)
   end
end

--[[
local function circFit(cross)
   local x1 = cross[1].x
   local x12 = x1*x1
   local y1 = cross[1].y
   local y12 = y1*y1
   local x2 = cross[2].x
   local x22 = x2*x2
   local y2 = cross[2].y
   local y22 = y2*y2
   local x3 = cross[3].x
   local x32 = x3*x3
   local y3 = cross[3].y
   local y32 = y3*y3
   
   local A = x1*(y2-y3) - y1*(x2-x3) + x2*y3 - x3*y2
   if math.abs(A) <= 1.0E-6 then
      return nil
   end
   
   local B = (x12 + y12)*(y3-y2) + (x22 + y22)*(y1-y3) + (x32 + y32)*(y2-y1)
   local C = (x12 + y12)*(x2-x3) + (x22 + y22)*(x3-x1) + (x32 + y32)*(x1-x2)
   local D = (x12 + y12)*(x3*y2 - x2*y3) + (x22 + y22)*(x1*y3 - x3*y1) +
      (x32 + y32)*(x2*y1 -x1*y2)
   
   local cx = -B / (2*A)
   local cy = -C / (2*A)
   local r = math.sqrt( (B*B + C*C - 4*A*D)/ (4*A*A) )
   return cx, cy, r, A
end
--]]
function M.fullTele(F3G, loopV, cross, savedXP, savedYP, xp, yp)
   local text

   if #savedXP >= 2 then
      for i=2,#savedXP,1 do
	 lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
      end
      --lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(loopV.curX), yp(loopV.curY))
   end
   
   drawPylons(xp, yp, F3G)
   if loopV.curX and loopV.curY then
      lcd.setColor(0,255,0)
      if  loopV.detB > 0 then
	 lcd.setColor(255,0,0)
      elseif loopV.detA > 0 then
	 lcd.setColor(0,0,255)
      end
      lcd.drawFilledRectangle(xp(loopV.curX)-3, yp(loopV.curY)-3, 6, 6)
      --drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      lcd.setColor(0,0,0)
      for i=1,3,1 do
	 if cross[i] then
	    lcd.drawCircle(xp(cross[i].x), yp(cross[i].y), 4)
	 end
      end
      --[[
      if turnCircle.X then
	 --lcd.drawCircle(xp(turnCircle.X), yp(turnCircle.Y), 320 * turnCircle.R / (xmax-xmin))
	 local r = 320 * turnCircle.R / (xmax-xmin)
	 local xx1, yy1, xx2, yy2
	 for i = 1,30,1 do
	    xx1 = xp(turnCircle.X) + r*math.cos(2*math.pi*(i)/30)
	    yy1 = yp(turnCircle.Y) + r*math.sin(2*math.pi*(i)/30)
	    xx2 = xp(turnCircle.X) + r*math.cos(2*math.pi*(i+1)/30)
	    yy2 = yp(turnCircle.Y) + r*math.sin(2*math.pi*(i+1)/30)
	    if xx1 > xp(F3G.gpsP.distAB) and xx2 > xp(F3G.gpsP.distAB) then
	       lcd.drawLine(xx1,yy1,xx2,yy2)
	    end
	 end
      end
      --]]
      if #cross == 3 then
	 lcd.drawText(260, 10, string.format("D: %.1f", math.abs(cross[1].x - cross[2].x)))
	 lcd.drawText(260, 25, string.format("W: %.1f", math.abs(cross[3].y - cross[1].y)))
      end
      text = string.format("%.2f", loopV.perpA)
      lcd.drawText( xp(0) - lcd.getTextWidth(FONT_NORMAL, text)/2 , yp(-60), text)
      text = string.format("%.2f", loopV.perpB)
      lcd.drawText( xp(F3G.gpsP.distAB) - lcd.getTextWidth(FONT_NORMAL, text)/2, yp(-60), text)

      lcd.drawText(10,10, loopV.fsTxt[loopV.flightState], FONT_NORMAL)
      if loopV.perpA then
	 text = string.format("%.2f m", loopV.perpA)
	 lcd.drawText(10,25,text)
      end
   end
end

return M
