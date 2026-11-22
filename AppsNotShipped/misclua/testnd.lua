local colornames = {"BG", "BGText", "Active", "ActiveText", "Inactive",
		    "InactiveText", "Disabled", "DisabledText", "Alert", "AlertText", "Highlighted",
		    "HighlightedText", "Button", "ButtonText", "Header", "Battery"}

local function printTelem(x,y)
   local xStep = x/4
   local yStep = y/4
   local color = 0
   for i = 0,3 do
      for j = 0,3 do
	 local r,g,b,a = lcd.getColor(color)
	 lcd.setColor(r,g,b,a)
	 lcd.drawFilledRectangle(i*xStep,j*yStep,
				 xStep,yStep)
	 if (color%2==0) then
	    r,g,b,a= lcd.getColor(color+1)
	 else
	    r,g,b,a=lcd.getColor(color-1)
	 end
	 lcd.setColor(r,g,b,a)
	 lcd.drawText(i*xStep,j*yStep,colornames
		      [color+1])
	 color = color + 1
	 local i = math.floor(system.getInputs("P4")*10)
	 local j = math.floor(system.getInputs("P3")*10) 

	 lcd.drawText(20,25, x+j)
	 lcd.drawText(20,45, y+i)
	 lcd.drawRectangle(0,0,x+j,y+i)

      end
   end
end

local function keyPress(k)
   print("keyPress", k)
   form.preventDefault()
   for k=1,5 do
      print("k, getButton", k, form.getButton(k))
   end
end

local function init()
   local btext={"one", "two", "three", "four", "five"}
   
   system.setProperty("NativeDraw",1)
   system.registerTelemetry(2,"Colors",4, printTelem, keyPress)
   for k=1,5 do
      print(k, btext[k])
      system.setTelemetryButton(2, k, btext[k],1)
   end
end
return { init=init, author=" JETI model ", version="0.01",name="Colors"}
