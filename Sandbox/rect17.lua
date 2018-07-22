-- Rectangles

local ytable = {}
local oldTime = 0
local mrs = math.random(1,59)
local ww

local function printForm()        

  lcd.drawRectangle(2,15,300,40)
  lcd.drawLine(100+2, 15, 100+2, 54)
  lcd.drawLine(200+2, 15, 200+2, 54)
  
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
  
  if (system.getTime() ~= oldTime) then
    oldTime = system.getTime()
    mrs = 0.85 * mrs + 0.15 * math.random(1,59)
    table.insert(ytable, #ytable+1, mrs)

    if #ytable > 60 then
      table.remove(ytable, 1)
    end
  end
  
  lcd.drawRectangle(2, 70, 300, 60)

  local iv = 70
  local ivd = 4
  local ivdt

  while iv <= 130 do
    if iv + ivd > 130 then
      ivdt = 130 - 1
    else
      ivdt = iv + ivd - 1
    end
    
    lcd.drawLine(75+2, iv, 75+2, ivdt)
    lcd.drawLine(150+2, iv, 150+2, ivdt)
    lcd.drawLine(225+2, iv, 225+2, ivdt)
    
    iv = iv + 2*ivd
  end

  local ih = 2
  local ihd = 4
  local ihdt

  while ih <= 300 do
     if ih + ihd > 300 then
       ihdt = 300
     else
       ihdt = ih + ihd
     end
     lcd.drawLine(ih, 70+60/2, ihdt, 70+60/2)
     ih = ih + 2*ihd
  end

  local ss = string.format("Altitude: %d", ytable[#ytable]*1000/59)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText((300-ww)/2,70-13, ss, FONT_MINI)

  local ss = string.format("Scale: %d ft", 1000)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(75+(75-ww)/2+1,70+1, ss, FONT_MINI)

  local ss = string.format("Timeline %s", "1:25")
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(150+(75-ww)/2+2,70+1, ss, FONT_MINI)
  
  lcd.setColor(200,0,0)

  for ix = 0, #ytable-1, 1 do
    local iy = ytable[ix+1]
    lcd.drawFilledRectangle(2+5*ix, 130-iy, 5, iy, 127)
  end

  lcd.setColor(0,0,0)

  lcd.drawRectangle(2, 133, 150, 10)
  lcd.drawRectangle(3+150, 133, 149, 10)

  lcd.setColor(200,0,0)

  ww = ytable[#ytable]/59*146
  lcd.drawFilledRectangle(4, 135, ww, 6, 159)

  lcd.drawFilledRectangle(300-ww, 135, ww+1, 6, 159)
  
  lcd.setColor(0,0,0)

  -- ss = string.format("Batt 1 Current (ma): %3.2f", 1.250)
  -- ww = lcd.getTextWidth(FONT_MINI,ss)
  -- lcd.drawText(5+(150-ww)/2+1,130+2,ss, FONT_MINI)

  -- ss = string.format("Batt 2 Current (ma): %3.2f", 1.350)
  -- ww = lcd.getTextWidth(FONT_MINI,ss)
  -- lcd.drawText(150+5+(150-ww)/2+1,130+2,ss, FONT_MINI)
  

  collectgarbage()
 
end   


local function init() 
  system.registerForm(1,MENU_MAIN,"Test 17 - Rectangles",nil, nil,printForm) 
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}

