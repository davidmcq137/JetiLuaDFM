--[[

   DFM-Crow.lua

   Adaptive crow trim offset, JETI adaptation of the orgininal open TX
   app done by Mike Shellim at the suggestion of Harry Curzon

   ---------------------------------------------------------
   Released under MIT-license by DFM 2021
   ---------------------------------------------------------
   
   Version 0.1 - Apr 3, 2021 using digital trim
   Version 0.2 - Apr 9, 2021 no use of digital trim

--]]

local crowVersion= 0.2

local crowCtrl

local tPoints
local trimCurveX = {}
local trimCurveY
local trimCurveU
local trimPoint
local lastTrimPoint = 0

local trimCtrl
local trimFunc=1
local swc

local reverseCrow
local reverseCrowIndex

local reverseTrim
local reverseTrimIndex

local lastswt=0

local swcVal
local mixVal

local pressHold = 200
local pressTime

local function crowCtrlChanged(value)
   crowCtrl = value
   system.pSave("crowCtrl", crowCtrl)
end

local function trimCtrlChanged(value)
   trimCtrl = value
   system.pSave("trimCtrl", trimCtrl)
end

local function reverseCrowChanged(value)
   reverseCrow = not value
   form.setValue(reverseCrowIndex, reverseCrow)
   system.pSave("reverseCrow", tostring(reverseCrow))
end

local function reverseTrimChanged(value)
   reverseTrim = not value
   form.setValue(reverseTrimIndex, reverseTrim)
   system.pSave("reverseTrim", tostring(reverseTrim))
end

local function rstCurve()
   for i=1, #trimCurveX do
      trimCurveY[i]=0
      trimCurveU[i]=0
   end
   trimCurveU[1]=1
end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Crow Control", width=220})
   form.addInputbox(crowCtrl, true, crowCtrlChanged)

   form.addRow(2)
   form.addLabel({label="Reverse Crow Control", width=270})
   reverseCrowIndex = form.addCheckbox(reverseCrow, reverseCrowChanged)

   form.addRow(2)
   form.addLabel({label="Trim Control", width=220})
   form.addInputbox(trimCtrl, true, trimCtrlChanged)

   form.addRow(2)
   form.addLabel({label="Reverse Trim Control", width=270})
   reverseTrimIndex = form.addCheckbox(reverseTrim, reverseTrimChanged)

   form.addRow(2)
   form.addLink(rstCurve, {label="Reset mix curve"})
   
   form.addRow(1)
   form.addLabel({label="DFM-Crow.lua Version "..crowVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local function loop()

   local info
   local swt
   local dt
   local mpl, mph
   local tp1
   local incT
   
   info = system.getSwitchInfo(crowCtrl)
   if info then
      swc = system.getInputs(info.label)
   end

   info = system.getSwitchInfo(trimCtrl)
   if info then
      swt = system.getInputs(info.label)
   end
   
   if swc then
      if reverseCrow then swc = -swc end
      swcVal = (swc+1)*50
      
      trimPoint = 1
      for i = 2, #trimCurveX-1, 1 do
	 mpl = (trimCurveX[i-1] + trimCurveX[i]) / 2
	 mph = (trimCurveX[i] + trimCurveX[i+1]) / 2
	 if swcVal > mpl and swcVal <= mph then
	    trimPoint = i
	    break
	 end
      end
      if trimPoint == 1 and swcVal > mph then trimPoint = #trimCurveX end

      if trimPoint ~= lastTrimPoint then
	 if trimCurveU[trimPoint] == 0 then
	    system.playNumber(trimCurveY[trimPoint], 0)
	    --print("trimPoint: " .. trimPoint)
	 end
      end
      lastTrimPoint = trimPoint
      
      if swt then
	 if reverseTrim then swt = -swt end
	 if math.abs(swt) <= 0.25 then
	    swt = 0
	 end
	 
	 incT = 1
	 --[[
	 if math.abs(swt) > 0.75 then
	    incT = 3
	 elseif math.abs(swt) > 0.50 then
	    incT = 2
	 else
	    incT = 1
	 end
	 --]]
	 
	 if swt > 0.25 then swt = 1 elseif swt < -0.25 then swt = -1 end

      end

      dt = system.getTimeCounter() - (pressTime or 0)
      
      if swt and swt ~= 0 and (lastswt == 0 or dt > pressHold) and (swcVal >= trimCurveX[2]/2) then
	 pressTime = system.getTimeCounter()
	 if swt == 1 and (lastswt ~= 1 or dt > pressHold) and trimPoint > 1 then
	    trimCurveY[trimPoint] = math.min(trimCurveY[trimPoint] + incT, 100)
	    trimCurveU[trimPoint] = 1
	 elseif swt == -1 and (lastswt ~= -1 or dt > pressHold) and trimPoint > 1 then
	    trimCurveY[trimPoint] = math.max(trimCurveY[trimPoint] - incT, -100)
	    trimCurveU[trimPoint] = 1
	 end
	 for i = trimPoint+1, #trimCurveX, 1 do
	    if trimCurveU[i] == 0 then
	       trimCurveY[i] = trimCurveY[trimPoint]
	    end
	 end
	 system.pSave("trimCurveY", trimCurveY)
	 system.pSave("trimCurveU", trimCurveU)	 
	 
      end
      
      lastswt = swt

      if swcVal < trimCurveX[trimPoint] then
	 mixVal = trimCurveY[trimPoint-1] +
	    (trimCurveY[trimPoint] - trimCurveY[trimPoint-1]) *
	    (swcVal - trimCurveX[trimPoint-1]) / (trimCurveX[trimPoint] - trimCurveX[trimPoint-1])
      else
	 tp1 = math.min(trimPoint+1, #trimCurveX)
	 tp0 = tp1 - 1
	 mixVal = trimCurveY[tp0] +
	    (trimCurveY[tp1] - trimCurveY[tp0]) *
	    (swcVal - trimCurveX[tp0]) / (trimCurveX[tp1] - trimCurveX[tp0])
      end
      system.setControl(trimFunc, mixVal / 100.0, 50)
   end
end

local function xpix(x)
   return 4 + (x/100) * 140
end

local function ypix(y)
   return 35 - (y/4)
end

local function teleWindow()

   local sR = 6
   local lR = 10
   local ren = lcd.renderer()
   local dx
   
   if swc then
      if trimPoint > 0 then
	 lcd.drawRectangle(xpix(trimCurveX[trimPoint]) - lR/2 + 1,
				ypix(trimCurveY[trimPoint]) - lR/2,
				lR, lR)
	 if trimPoint > 1 then
	    if trimPoint < #trimCurveX then dx = 6 else dx = 9 end
	    lcd.drawText(xpix(trimCurveX[trimPoint])-dx,55,
			 string.format("%d", trimCurveY[trimPoint]), FONT_MINI)
	 end
      end
      if mixVal then
	 lcd.drawRectangle(xpix(swcVal) - sR/2 + 1, ypix(mixVal) - sR/2, sR, sR)
	 lcd.drawText(5,5,string.format("%.1f", mixVal), FONT_MINI)
      end
   end
   lcd.drawLine(4,35,144,35)
   ren:reset()
   for i=1, #trimCurveX, 1 do
      if trimCurveU[i] == 1 then lcd.setColor(0,0,255) else lcd.setColor(255,0,0) end
      lcd.drawCircle(xpix(trimCurveX[i]), ypix(trimCurveY[i]), 4)
      lcd.setColor(0,0,0)
      ren:addPoint(xpix(trimCurveX[i]), ypix(trimCurveY[i]))
      --[[
      if i < #trimCurveX then
	 lcd.drawLine(xpix(trimCurveX[i]), ypix(trimCurveY[i]),
		      xpix(trimCurveX[i+1]), ypix(trimCurveY[i+1]))
      end
      --]]
   end
   ren:renderPolyline(1)
end

local function destroy()
   system.pSave("timCurveY", trimCurveY)
   system.pSave("timCurveU", trimCurveU)
end

local function init()

   local rc
   local savedY
   local savedU
   
   crowCtrl    = system.pLoad("crowCtrl")
   trimCurveY  = system.pLoad("trimCurveY")
   trimCurveU  = system.pLoad("trimCurveU")   
   trimCtrl    = system.pLoad("trimCtrl")
   reverseCrow = system.pLoad("reverseCrow", "false")
   reverseCrow = (reverseCrow == "true")
   reverseTrim = system.pLoad("reverseTrim", "false")
   reverseTrim = (reverseTrim == "true")   

   tPoints = 7
   
   if trimCurveY and #trimCurveY ~= 0 then
      savedY = true else
	 savedY = false
	 trimCurveY = {}
   end
   if trimCurveU and #trimCurveU ~= 0 then
      savedU = true else
	 savedU = false
	 trimCurveU = {}
   end   
   
   local ioff = 2
   local x0 = 100*(1+ioff)*(1+ioff)/( (tPoints+ioff) * (tPoints+ioff) )
   local xP = 100 - x0

   trimCurveU[1] = 1
   for i=1,tPoints,1 do
      trimCurveX[i] = (100*(i+ioff)*(i+ioff)/((tPoints+ioff) * (tPoints+ioff)) - x0) * 100 / xP
      if not savedY then trimCurveY[i] = 0 end
      if not savedU then trimCurveU[i] = 0 end
      print(i, trimCurveX[i])
   end

   system.registerForm(1, MENU_APPS, "Adaptive Crow Mixer", initForm)
   system.registerTelemetry(1, "Crow Mix Curve", 2, teleWindow)

   rc = system.registerControl(trimFunc, "Adaptive Crow Val", "ACV")
   if not rc then print("DFM-Crow: Could not register ACV control") end
   system.setControl(trimFunc,0,0)

end

return {init=init, loop=loop, author="DFM", version=tostring(crowVersion),
	name="Adaptive Crow Mixer", destroy=destroy}
