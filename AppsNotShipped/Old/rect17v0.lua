-- Rectangles

local ytable = {}
local oldTime = 0
local mrs = math.random(1,59)
local ww

local function printForm()        

  lcd.drawRectangle(2,15,300,40)
  lcd.drawLine(100+2, 15, 100+2, 54)
  lcd.drawLine(200+2, 15, 200+2, 54)
  
  -- lcd.setColor(200,0,0)
  -- lcd.drawRectangle(10,40,300,20,5) 
  -- lcd.setColor(0,200,0)
  -- lcd.drawRectangle(10,70,300,40,20) 


  ww = lcd.getTextWidth(FONT_MAXI, "04:00")
  lcd.drawText(5+(100-ww)/2-1,15,"04:00", FONT_MAXI)

  ww = lcd.getTextWidth(FONT_MAXI, "94")
  lcd.drawText(100+5+(100-ww)/2-1,15,"94", FONT_MAXI)
  
  ww = lcd.getTextWidth(FONT_MAXI, "525")
  lcd.drawText(200+5+(100-ww)/2-1,15,"525", FONT_MAXI)

  ww = lcd.getTextWidth(FONT_MINI, "Flt Time (min)")
  lcd.drawText(5+(100-ww)/2,2,"Flt Time (min)", FONT_MINI)
  
  ww = lcd.getTextWidth(FONT_MINI, "Fuel Left (%)")
  lcd.drawText(100+5 + (100-ww)/2,2,"Fuel Left (%)", FONT_MINI)

  ww = lcd.getTextWidth(FONT_MINI, "Batt Used (maH)")
  lcd.drawText(200+5+(100-ww)/2,2,"Batt Used (maH)", FONT_MINI)
  
  
--  lcd.drawText(5,40,"Fuel Left (p): 100", FONT_MAXI)
--  lcd.drawText(5,75,"Batt used: 525 maH", FONT_MAXI)


  if (system.getTime() ~= oldTime) then
    oldTime = system.getTime()
    mrs = 0.85 * mrs + 0.15 * math.random(1,59)
    table.insert(ytable, #ytable+1, mrs)

    if #ytable > 60 then
      table.remove(ytable, 1)
    end
  end
  
  lcd.drawRectangle(2, 70, 300, 60)
  local ss = string.format("Scale: %d ft -- Timeline 1:00", 60)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(5+(300-ww)/2,70-13, ss, FONT_MINI)
  
  lcd.setColor(200,0,0)

   
  
  for ix = 0, #ytable-1, 1 do
    local iy = ytable[ix+1]
    lcd.drawFilledRectangle(2+5*ix, 130-iy, 5, iy)
  end
  collectgarbage()
 
end   


local function init() 
  system.registerForm(1,MENU_MAIN,"Test 17 - Rectangles",nil, nil,printForm) 
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}
