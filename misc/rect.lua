local testimage
local Images={}
local tempReadings={400, 600, 800, 450, 950, 500, 400, 300}
local tempProbes={1,2,3,4,5,6,7,8}

local function tele(w,h)
   local minW=0
   local midW=160
   local maxW=319
   local minH=0
   local midH=80
   local maxH=159
   local x,y
   local xp, yp
   local xt, yt
   
   lcd.drawImage( (310-testimage.width)/2+2+60, 10, testimage)
   for k = 1, #Images[1].Locations do
      --print(k,Images[1].Locations[k].Name, Images[1].Locations[k].XP, Images[1].Locations[k].YP)

      x=Images[1].Locations[k].XP
      y=Images[1].Locations[k].YP
      x = x + midW
      y = y + midH
      y=maxH-y
      y=y-15
      x=x-2+60

      if tempReadings[k] >= Images[1].Green and
      tempReadings[k] < Images[1].Yellow then
	 lcd.setColor(25,255,45)
      elseif tempReadings[k] >= Images[1].Yellow and
      tempReadings[k] < Images[1].Red then
	 lcd.setColor(245,210,50)
      elseif tempReadings[k] >= Images[1].Red then
	 lcd.setColor(255,0,0)
      end

      xp = x - lcd.getTextWidth(FONT_NORMAL, Images[1].Locations[k].Name)/2
      yp = y + lcd.getTextHeight(FONT_NORMAL)/2
      lcd.drawText(xp,yp, Images[1].Locations[k].Name)

      lcd.setColor(0,0,0)
      
      xt=Images[1].Locations[k].XT
      yt=Images[1].Locations[k].YT
      lcd.drawText(xt, yt,
		   Images[1].Locations[k].Name.."("..tempProbes[k]..") : "..
		      tempReadings[k].." "..Images[1].Units)
      
   end
   
end

local function init()
   local fp = io.readall("Apps/SB-Temp.jsn")
   Images = json.decode(fp)
   testimage = lcd.loadImage("Apps/"..Images[1].Name)
   system.registerTelemetry(1,"SB-Temp", 4, tele)
end





--------------------------------------------------------------------------------

return {init=init, loop=loop, name="SB-Temp", author="DFM", version="1.0"}
