local M = {}


function M.doubleTele(loopV)

   local text
   lcd.setColor(lcd.getFgColor())
   
   lcd.drawText(0,0,"State: " .. loopV.fsTxt[loopV.flightState], FONT_BIG)

   if loopV.flightState == loopV.fs.Idle or loopV.flightState == loopV.fs.MotorOn then
      text = string.format("%.2f s", loopV.motorTime/1000)
      lcd.drawText(0,20,text)
      if loopV.curX and loopV.curY then
	 text = string.format("X: %.1f", loopV.curX)
	 lcd.drawText(90, 20, text)
	 text = string.format("Y: %.1f", loopV.curY)
	 lcd.drawText(90, 35, text)
      end
      
      text = string.format("%.2f W", loopV.motorPower)
      lcd.drawText(0,35,text)
      text = string.format("%.2f W-m", loopV.motorWattSec/60)
      lcd.drawText(0,50,text)
   else
      if loopV.taskStartTime then
	 if loopV.flightState ~= loopV.fs.Done then
	    text = string.format("T: %.2f s", (system.getTimeCounter() - loopV.taskStartTime)/1000)
	 else
	    text = string.format("T: %.2f s", loopV.taskDone/1000) ..
	       string.format(" F: %.2f s", loopV.flightDone/1000)
	 end
      else
	 text = string.format("T: %.2f s", loopV.flightTime/1000)	 
      end
      lcd.drawText(0,20,text)

      if loopV.taskLaps then
	 text = string.format("%d Laps", loopV.taskLaps)
      else
	 text = string.format("Alt: %.1f m", loopV.altitude or 0)	 
      end
      lcd.drawText(0,35,text)
      
      if loopV.perpA then
	 text = string.format("%.2f m from A", loopV.perpA)
	 lcd.drawText(0,50,text)
      end
   end
   
end

return M
