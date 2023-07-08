local M = {}


function M.doubleTele(loopV, F3X)

   local fm = {F3X=1,F3B=2,Basic=3}
   local text
   lcd.setColor(lcd.getFgColor())

   if F3X.flightMode == fm.Basic then
      text = "Status: No Position"
      if F3X.gpsP.curPos then text = "Status: " .. "Pos " end
      if F3X.gpsP.zeroLatStr then text = text .. "Pt A " end
      if F3X.gpsP.rotA then text = text .. "Pt B " end
      lcd.drawText(0, 0, text, FONT_MINI)   
      
      text = "State: " .. loopV.fsTxt[loopV.flightState]
      lcd.drawText(0, 10, text, FONT_MINI)
   else
      text = "State: " .. loopV.fsTxt[loopV.flightState]
      lcd.drawText(0, 10, text, FONT_NORMAL)
   end

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
      if F3X.flightMode ~= fm.Basic then
	 lcd.drawText(0,20,text)
      end

      if loopV.taskLaps then
	 text = string.format("%d Laps", loopV.taskLaps)
      else
	 text = string.format("Alt: %.1f m", loopV.altitude or 0)	 
      end
      if F3X.flightMode ~= fm.Basic then
	 lcd.drawText(0,35,text)
      end
      
      if loopV.perpA then
	 text = string.format("%.2f", loopV.perpA)
	 if F3X.flightMode ~= fm.Basic then
	    lcd.drawText(0,50,text.." m from A")
	 else
	    lcd.drawText(60 - lcd.getTextWidth(FONT_BIG, text)/2,25,text,FONT_MAXI)
	 end
      end
   end
   
   --lcd.drawText(120, 55, string.format("%.1f", collectgarbage("count")), FONT_MINI)
   
end

return M
