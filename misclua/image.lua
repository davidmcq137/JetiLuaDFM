local imagepng, imagejpg
local function printForm()
   if(imagepng) then
      --print(imagepng.width, imagepng.height)
      lcd.drawImage((310-imagepng.width)/2, 0, imagepng)
      lcd.drawFilledRectangle(310/2-70, 20, 140, 5)
      lcd.drawFilledRectangle(310/2-40, 0, 5, 145)
   end
end
local function init()   system.registerForm(1,MENU_MAIN,"Test 19 - Images",nil, nil,printForm)
   imagepng = lcd.loadImage("Img/glideslope.png")
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}
