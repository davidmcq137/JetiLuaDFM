local DT = {}

function DT.drawTape(x0, y0, xh, yh, tele, lbl, unit, onLeft)
   local nLine = {
      {-72, 7, 30},  -- +30
      {-60, 3},      -- +25
      {-48, 7, 20},  -- +20
      {-36, 3},      -- +15
      {-24, 7, 10},  --  +10
      {-12 , 3},      --  +5
      {   0 , 7, 0},        --   0
      {12, 3},       --  -5
      {24, 7, -10}, -- -10
      {36, 3},      -- -15
      {48, 7, -20}, -- -20
      {60, 3},      -- -25
      {72, 7, -30}  -- -30
   }
   local delta = (tele or 0) % 10
   local deltaY = 1 + math.floor(2.4 * delta)
   local xoff
   local pMult
   local yoff = 0
   local xnum
   local xbox
   local yfh = lcd.getTextHeight(FONT_NORMAL)/2
   local text
   local r,g,b = lcd.getBgColor()
   if r+b+g > 384 then 
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
   if onLeft then
      xoff = 27
      pMult = 1
      xnum = 0
      xbox = 0
   else
      xoff = 22
      pMult = -1
      xnum = xh/2+2
      xbox = 5
   end
   lcd.drawText(x0+xh/2-pMult*8-lcd.getTextWidth(FONT_MINI, lbl)/2, yh+4, lbl, FONT_MINI)
   lcd.drawText(x0+xh/2-pMult*8-lcd.getTextWidth(FONT_MINI, unit)/2, yh+14, unit, FONT_MINI)
   lcd.setClipping(x0,y0,xh,yh)
   lcd.drawLine(xoff, 0, xoff, yh)
   for _, line in pairs(nLine) do
      lcd.drawLine(xoff, line[1]+deltaY+yh/2+yoff, xoff+pMult*line[2], line[1]+deltaY+yh/2+yoff)
      if line[3] then
	 local dd = (tele or 0) + line[3] - delta
	 text = string.format("%d",dd)
	 if (dd >= 0.0) and (dd <= 1000.0) then
	    lcd.drawText(xnum + xoff - lcd.getTextWidth(FONT_NORMAL,text)-2, line[1]+deltaY+yh/2+yoff-yfh, text)
	 end
      end
   end
   text = string.format("%d", (tele or 0))
   lcd.setColor(lcd.getBgColor())
   lcd.drawFilledRectangle(xnum-xbox, yh/2 + yoff-yfh,28,lcd.getTextHeight(FONT_NORMAL))
   if r+b+g > 384 then 
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
   lcd.drawRectangle(xnum-xbox, yh/2 + yoff-yfh,28,lcd.getTextHeight(FONT_NORMAL))
   lcd.drawText(xnum+xoff - lcd.getTextWidth(FONT_NORMAL,text)-2, yh/2+yoff-yfh, text, FONT_NORMAL|FONT_XOR)
   lcd.resetClipping() 
end

return DT
