




local function printForm()
   xr = 310 * (1+system.getInputs("P7")) / 2
   yr = 143 * (1+system.getInputs("P8")) / 2
   wr = 310 * (1+system.getInputs("P5")) / 2
   hr = 143 * (1+system.getInputs("P6")) / 2
   lcd.setColor(200,0,0)
   if xr+wr > 310 then wr=310-xr end
   if yr+hr > 143 then hr=143-yr end
   local str = string.format("xr=%d, yr=%d, wr=%d, hr=%d", xr, yr, wr, hr)
   lcd.drawText(100, 80, str)
   lcd.drawRectangle(xr,yr, wr, hr)
end


local function init()
   system.registerForm(1,MENU_MAIN,"Test 17 - Rectangles",nil, nil,printForm)
end
--------------------------------------------------------------------------------

return {init=init, author="JETI model", version="1.0"}
