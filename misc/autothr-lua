-- Rectangles

local ytable = {}
local oldTime = 0
local mrs = 0 -- math.random(-1,1)
local mrs2 = math.random(0,1)
local ww

local function printForm()        

  lcd.drawRectangle(2,20+2,300,40)

 
  ww = lcd.getTextWidth(FONT_NORMAL, "Delta V")
  lcd.drawText(5+(300-ww)/2-1,2,"Delta V", FONT_NORMAL)

  ww = lcd.getTextWidth(FONT_MINI, "-10 mph")
  lcd.drawText(5,5,"-10 mph", FONT_MINI)

  ww = lcd.getTextWidth(FONT_MINI, "+10 mph")
  lcd.drawText(300-ww+5,5,"+10 mph", FONT_MINI)

--[[ 
  if (system.getTime() ~= oldTime) then
    oldTime = system.getTime()
    mrs = 0.85 * mrs + 0.15 * math.random(1,59)
    table.insert(ytable, #ytable+1, mrs)

    if #ytable > 60 then
      table.remove(ytable, 1)
    end
  end
--]]

  local a = .00015
  local b = 35
  mrs = (1-a) * mrs + a * math.random(-1*b, b)
  if mrs <  0 then
    lcd.drawFilledRectangle(2+((300-4)/2)*(mrs+1), 20+2+2, 2+((300-4)/2)*(-1.0*mrs), 40-2*2)
  else
    lcd.drawFilledRectangle(2+((300-4)/2), 20+2+2, 2+((300-4)/2)*mrs, 40-2*2)
  end
    
  local a2 = 0.005
  mrs2 = (1-a2)*mrs2 + a2*math.random(0,1)

  lcd.drawRectangle(2, 90, 300, 40)

  ww = lcd.getTextWidth(FONT_MINI, "Idle")
  lcd.drawText(5,90-20,"Idle", FONT_MINI)

  ww = lcd.getTextWidth(FONT_MINI, "Full")
  lcd.drawText(300-ww+5,90-20,"Full", FONT_MINI)

  ww = lcd.getTextWidth(FONT_NORMAL, "Throttle")
  lcd.drawText(5+(300-ww)/2-1,90-20,"Throttle", FONT_NORMAL)

  lcd.drawFilledRectangle(2+2, 90+2, (300-4)*mrs2, 40-2*2)


  collectgarbage()
 
end   


local function init() 
  system.registerForm(1,MENU_MAIN,"Auto Throttle",nil, nil,printForm) 
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}


