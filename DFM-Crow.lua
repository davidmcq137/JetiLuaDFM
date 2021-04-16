--[[

   DFM-Crow.lua

   Adaptive crow trim offset, JETI adaptation of the orgininal open TX
   app done by Mike Shellim at the suggestion of Harry Curzon

   ---------------------------------------------------------
   Released under MIT-license by DFM 2021
   ---------------------------------------------------------
   
   Version 0.1 - Apr  3, 2021 using digital trim
   Version 0.2 - Apr  9, 2021 no use of digital trim
   Version 0.3 -         Digital trim is back!
   Version 0.4 - Apr 14, Autocrow (like autotrim) added

--]]

local crowVersion= 0.4

local crowCtrl
local acvCtrl
local luaTrimCtrl=1
local fmCtrl
local luaModeCtrl=2
local elevCtrl
local autoCtrl
local autoAnnounce = 0
local autoCrowRate
   
local tPoints
local trimCurveX
local trimCurveY
local trimCurveU
local trimPoint
local lastTrimPoint = 0

local trimCtrl
local swc
local swa

local reverseCrow
local reverseCrowIndex

local reverseTrim
local reverseTrimIndex

local announcePoints
local announcePointsIndex

local trimStep

local lastswt=0

local swcVal
local mixVal

local pressHold = 200
local pressTime

local function initCrow()

   local savedY
   local savedU

   if trimCurveY and #trimCurveY ~= 0 then
      savedY = true
   else
      savedY = false
      trimCurveY = {}
   end
   
   if trimCurveU and #trimCurveU ~= 0 then
      savedU = true
   else
      savedU = false
      trimCurveU = {}
   end   

   local ioff = 2
   local x0 = 100*(1+ioff)*(1+ioff)/( (tPoints+ioff) * (tPoints+ioff) )
   local xP = 100 - x0

   trimCurveX = {}
   for i=1,tPoints,1 do
      trimCurveX[i] = (100*(i+ioff)*(i+ioff)/((tPoints+ioff) * (tPoints+ioff)) - x0) * 100 / xP
      if not savedY then trimCurveY[i] = 0 end
      if not savedU then trimCurveU[i] = 0 end
      --print(i, trimCurveX[i])
   end

   trimCurveU[1] = 1

end


local function crowCtrlChanged(value)
   local info
   crowCtrl = value
   info = system.getSwitchInfo(crowCtrl)
   if not info.proportional then
      system.messageBox("Please set Crow control to Proportional")
   else
      system.pSave("crowCtrl", crowCtrl)
   end
end

local function trimCtrlChanged(value)
   local info
   trimCtrl = value
   info = system.getSwitchInfo(trimCtrl)
   if not info.proportional then
      system.messageBox("Please set Trim control to Proportional")
   end
   system.pSave("trimCtrl", trimCtrl)
end

local function elevCtrlChanged(value)
   local info
   elevCtrl = value
   info = system.getSwitchInfo(elevCtrl)
   if not info.proportional then
      system.messageBox("Please set Elev control to Proportional")
   end
   system.pSave("elevCtrl", elevCtrl)
end

local function autoCtrlChanged(value)
   autoCtrl = value
   system.pSave("autoCtrl", autoCtrl)
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

local function trimStepChanged(value)
   trimStep = value
   system.pSave("trimStep", trimStep)
end

local function autoCrowRateChanged(value)
   autoCrowRate = value
   system.pSave("autoCrowRate", autoCrowRate)
end

local function tPointsChanged(value)
   tPoints = value
   trimCurveY = nil
   trimCurveU = nil
   initCrow()
   system.pSave("tPoints", tPoints)
   system.pSave("trimCurveY", trimCurveY)
   system.pSave("trimCurveU", trimCurveU)	 
end

local function announcePointsChanged(value)
   announcePoints = not value
   form.setValue(announcePointsIndex, announcePoints)
   system.pSave("announcePoints", tostring(announcePoints))
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
   form.addLabel({label="Trim step", width=260})
   form.addIntbox(trimStep, 1, 10, 2, 0, 1, trimStepChanged)

   form.addRow(2)
   form.addLabel({label="Number of Crow curve points", width=270})
   form.addIntbox(tPoints, 5, 9, 7, 0, 1, tPointsChanged)
   
   form.addRow(2)
   form.addLabel({label="AutoCrow on/off control", width=220})
   form.addInputbox(autoCtrl, true, autoCtrlChanged)

   form.addRow(2)
   form.addLabel({label="AutoCrow Rate", width=260})
   form.addIntbox(autoCrowRate, 10, 500, 10, 0, 1, autoCrowRateChanged)

   form.addRow(2)
   form.addLabel({label="Elevator Control for AutoCrow", width=220})
   form.addInputbox(elevCtrl, true, elevCtrlChanged)

   form.addRow(2)
   form.addLabel({label="Announce Unset Trim Points", width=270})
   announcePointsIndex = form.addCheckbox(announcePoints, announcePointsChanged)

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
   local swe
   local deadBand = 0.02
   
   info = system.getSwitchInfo(crowCtrl)
   if info then
      swc = system.getInputs(info.label)
   end

   info = system.getSwitchInfo(trimCtrl)
   if info then
      swt = info.value -- system.getInputs(string.upper(info.label))
      --print("swt: " .. swt)
      --print("info.label: " .. info.label .. " info.value: " .. info.value ..
	       --" info.proportional: "..tostring(info.proportional) .." info.mode: " .. info.mode)
   end

   info = system.getSwitchInfo(autoCtrl)
   if info then
      swa = info.value -- system.getInputsVal(autoCtrl)
   end
   
   info = system.getSwitchInfo(elevCtrl)
   if info then
      --print("info.label: " .. info.label .. " info.value: " .. info.value ..
      --" info.proportional: "..tostring(info.proportional) .." info.mode: " .. info.mode)
      swe = info.value
      --print(system.getInputsVal(elevCtrl))
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
	    if announcePoints then system.playNumber(trimPoint, 0) end
	 end
      end
      lastTrimPoint = trimPoint
      
      if swt then
	 if reverseTrim then swt = -swt end
	 if math.abs(swt) <= 0.25 then
	    swt = 0
	 end
	 incT = trimStep
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

	 if trimCurveY[trimPoint] == 0 then
	    system.playBeep(1, 1500, 100)
	 else
	    system.playBeep(0, 1500, 100)
	 end
	 
	 system.pSave("trimCurveY", trimCurveY)
	 system.pSave("trimCurveU", trimCurveU)	 
	 
      end
      lastswt = swt

      if autoCtrl and elevCtrl and swa == 1 and trimPoint ~= 1 then -- autotrim is on!
	 -- 10 chosen by experimentation	 
	 -- to traverse at same speed as real autotrim

	 if math.abs(swe) < deadBand then swe = 0 end

	 if swe >= 0 then -- put quadratic "expo" into autocrow
	    swe = swe * swe
	 else
	    swe = swe * swe * -1
	 end
	 
	 incT = (autoCrowRate / 10) * (swe / 10)
	 --print("swe, incT, trimPoint, tCY[]", swe, incT, trimPoint,trimCurveY[trimPoint])
	 trimCurveY[trimPoint] = trimCurveY[trimPoint] + incT
	 trimCurveY[trimPoint] = math.max(math.min(trimCurveY[trimPoint], 100), -100)
	 trimCurveU[trimPoint] = 1	 
	 for i = trimPoint+1, #trimCurveX, 1 do
	    if trimCurveU[i] == 0 then
	       trimCurveY[i] = trimCurveY[trimPoint]
	    end
	 end
	 if system.getTimeCounter() - autoAnnounce > 1500 then
	    system.playFile("/Apps/DFM-Crow/auto_crow.wav", AUDIO_QUEUE)
	    autoAnnounce = system.getTimeCounter() + 1500
	    system.pSave("trimCurveY", trimCurveY)
	    system.pSave("trimCurveU", trimCurveU)
	 end
      end

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
      if fmCtrl then -- set the flight mode control to 1 if on the crow curve, -1 if not
	 if swcVal >= trimCurveX[2]/2 then
	    system.setControl(fmCtrl, 1, 0)	    
	 else
	    system.setControl(fmCtrl,-1, 0)
	 end
      end
      if acvCtrl then
	 system.setControl(acvCtrl, mixVal / 100.0, 50)
      end
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
	    if autoCtrl and elevCtrl and swa == 1 then -- autotrim is on!
	       lcd.setColor(255,0,0)
	       lcd.drawText(40,5, "Auto", FONT_MINI)
	       lcd.setColor(0,0,0)
	    end
	    
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
   if acvCtrl then system.unregisterControl(acvCtrl) end
   if  fmCtrl then system.unregisterControl(fmCtrl)  end   
end

local function init()

   crowCtrl     = system.pLoad("crowCtrl")
   trimCurveY   = system.pLoad("trimCurveY")
   trimCurveU   = system.pLoad("trimCurveU")   
   trimCtrl     = system.pLoad("trimCtrl")
   trimStep     = system.pLoad("trimStep", 2)
   tPoints      = system.pLoad("tPoints", 7)   
   elevCtrl     = system.pLoad("elevCtrl")
   autoCtrl     = system.pLoad("autoCtrl")   
   autoCrowRate = system.pLoad("autoCrowRate", 10)
   
   reverseCrow = system.pLoad("reverseCrow", "false")
   reverseCrow = (reverseCrow == "true")

   reverseTrim = system.pLoad("reverseTrim", "false")
   reverseTrim = (reverseTrim == "true")

   announcePoints = system.pLoad("announcePoints", "true")
   announcePoints = (announcePoints == "true")      

   initCrow()

   system.registerForm(1, MENU_APPS, "Adaptive Crow Mixer", initForm)
   system.registerTelemetry(1, "Crow Mix Curve", 2, teleWindow)

   acvCtrl = system.registerControl(luaTrimCtrl, "Adaptive Crow Value", "ACV")
   if not acvCtrl then print("DFM-Crow: Could not register ACV control") else
      system.setControl(acvCtrl,0,0)
   end

   fmCtrl = system.registerControl(luaModeCtrl, "Crow Flight Mode", "CFM")
   if not fmCtrl then print("DFM-Crow: Could not register CFM control") else
      system.setControl(fmCtrl,0,0)
   end

end

return {init=init, loop=loop, author="DFM", version=tostring(crowVersion),
	name="Adaptive Crow Mixer", destroy=destroy}
