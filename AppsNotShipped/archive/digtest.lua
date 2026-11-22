local appName = "Number test"

local function prtClock()
   lcd.drawCircle(0,0,100,0)
   lcd.drawImage(0,0,png)
   lcd.drawImage(0,100,pngr)
   lcd.setColor(30,48,106)
   lcd.drawText(80,80, "Testing 123", FONT_MAXI)
end

local function init()

   system.registerTelemetry(1, "Clock", 4, prtClock)
   png =  lcd.loadImage("Apps/two.png")
   pngr = lcd.loadImage("Apps/two-red.png")
   print("imagewidth:", png.width)
   print("imageheight:", png.height)
   print("foreground:", lcd.getFgColor())
   print("background:", lcd.getBgColor())   
   
	 
   
   
end
----------------------------------------------------------------------
return { init=init,  author="JETI model and DFM",version="1.0", name=appName}

