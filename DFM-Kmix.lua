--[[

   DFM-Kmix.lua

   Adaptive crow trim offset, JETI adaptation of the orgininal open TX
   app done by Mike Shellim at the suggestion of Harry Curzon

   Copied/forked from DFM-Crow after V 1.5


   ---------------------------------------------------------
   Released under MIT-license by DFM 2021
   ---------------------------------------------------------
   
   Version 0.1 - Apr  3, 2021 using digital trim
   Version 0.2 - Apr  9, 2021 no use of native digital trim buttons
   Version 0.3 -         2021 digital trim is back!
   Version 0.4 - Apr 14, 2021 autocrow (like autotrim) added
   Version 0.5 - Apr 26, 2021 final tuning of defaults from HC testing
   Version 0.6 - Apr 26, 2021 looks for free lua controls, starting at 5
   Version 0.7 - Apr 27, 2021 limited support for mono display TXs
   Version 0.8 - May 07, 2021 supports mono/limited lua and other TXs
   Version 0.9 - May 08, 2021 unset points track highest point set, not current point
   Version 1.0 - May 09, 2021 persist crow curve by model name, remove crow controls, purely autocrow
   Version 1.1 - May 12, 2021 add language support
   Version 1.2 - May 18, 2021 improve language support to only read one lang file, add deadCrow
   Version 1.3 - May 19, 2021 add some translated strings that were missed, remove flight mode ctrl
   Version 1.4 - May 31, 2021 edits to the language jsn files, add de-auto_crow.wav file

   Version 1.5 - Jul 25, 2021 fix bug that prevented use of logical sw/ctrl for crow
                              change speaking of crow points to indiv wav files

   Fork to DFM-Kmix

   Version 1.0 - Sep 28,2021  first version .. incorporates one-sided (0-100%) or (-100% to 100%)
                              inputs. Adds second output control.

   Limitations: 
   
   1) Does not account for variability of loops/second which can
   impact the autocrow rate

   2) Fixes lua controls at #1 and #2 for monochrome TXs which can only have two controls

   Acknowledgements:

   de.jsn file contributed by Alois Hahn

--]]

local crowVersion= 1.5
local appShort="DFM-Kmix"
local appDir = "Apps/"..appShort.."/"

local monoChrome

local crowCtrl
local acvEleCtrl
local acvAilCtrl
local fmCtrl
local elevCtrl
local ailCtrl
local autoCtrl
local autoAnnounce = 0
local autoCrowRate
local luaControlMax = 0.50

local crowConfig={}
crowConfig.jsnVersion = 1.1 -- version of saved data file

local modelFile

local trimCtrl
local swc
local swa

local reverseCrow
local reverseCrowIndex

local reverseTrim
local reverseTrimIndex

local announcePoints
local announcePointsIndex

local oneSidedInputIndex
local oneSidedInput

local trimStep

local lastswt=0

local swcVal
local mixValE, mixValA

local pressHold = 200
local pressTime

local autoCrowSens 
local autoCrowSpacing

local lang
local locale

local function setLanguage()

   local obj
   local fp
   local transFile

   locale = system.getLocale()
   --locale = "de"

   --print("locale: " .. locale)

   transFile = appDir .. locale .. ".jsn"

   --print("transFile: " .. transFile)
   
   fp = io.readall(transFile)

   if not fp then
      system.messageBox("DFM-Crow: Missing " .. transFile)
      -- try for English if no locale support
      transFile = appDir .. "en.jsn"
      fp = io.readall(transFile)
      if not fp then
	 error("No English language file")
      end
   end

   lang = json.decode(fp)

end

local function initCrow()

   local savedY
   local savedZ
   local savedU
   local ioff
   local x0
   local xP
   
   if crowConfig.trimCurveY and #crowConfig.trimCurveY ~= 0 then
      savedY = true
   else
      savedY = false
      crowConfig.trimCurveY = {}
   end
   
   if crowConfig.trimCurveZ and #crowConfig.trimCurveZ ~= 0 then
      savedZ = true
   else
      savedZ = false
      crowConfig.trimCurveZ = {}
   end

   if crowConfig.trimCurveU and #crowConfig.trimCurveU ~= 0 then
      savedU = true
   else
      savedU = false
      crowConfig.trimCurveU = {}
   end   

   crowConfig.trimCurveX = {}
   if autoCrowSpacing == 1 then -- linear
      for i = 1, crowConfig.tPoints, 1 do
	 if oneSidedInput then
	    crowConfig.trimCurveX[i] = (i-1) * 100 / (crowConfig.tPoints-1)
	 else
	    crowConfig.trimCurveX[i] = (i-5) * 200 / (crowConfig.tPoints-1)
	 end
	 if not savedY then crowConfig.trimCurveY[i] = 0 end
	 if not savedZ then crowConfig.trimCurveZ[i] = 0 end	 
	 if not savedU then crowConfig.trimCurveU[i] = 0 end
      end
   end

   crowConfig.trimCurveU[centerPoint] = 1

end

local function crowCtrlChanged(value)
   local info
   crowCtrl = value
   info = system.getSwitchInfo(crowCtrl)
   if not info.proportional then
      system.messageBox(lang.pleaseProp)
   else
      system.pSave("crowCtrl", crowCtrl)
   end
end

local function trimCtrlChanged(value)
   local info
   trimCtrl = value
   info = system.getSwitchInfo(trimCtrl)
   if not info.proportional then
      system.messageBox(lang.pleaseProp)
   end
   system.pSave("trimCtrl", trimCtrl)
end

local function elevCtrlChanged(value)
   local info
   elevCtrl = value
   info = system.getSwitchInfo(elevCtrl)
   if not info.proportional then
      system.messageBox(lang.pleaseProp)
   end
   system.pSave("elevCtrl", elevCtrl)
end

local function ailCtrlChanged(value)
   local info
   ailCtrl = value
   info = system.getSwitchInfo(ailCtrl)
   if not info.proportional then
      system.messageBox(lang.pleaseProp)
   end
   system.pSave("ailCtrl", ailCtrl)
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

local function autoCrowSensChanged(value)
   autoCrowSens = value
   system.pSave("autoCrowSens", autoCrowSens)
end

local function autoCrowSpacingChanged(value)
   autoCrowSpacing = value
   system.pSave("autoCrowSpacing", autoCrowSpacing)
   initCrow()
end

local function tPointsChanged(value)
   crowConfig.tPoints = value
   crowConfig.trimCurveY = nil
   crowConfig.trimCurveZ = nil
   crowConfig.trimCurveU = nil
   initCrow()
end

local function announcePointsChanged(value)
   announcePoints = not value
   form.setValue(announcePointsIndex, announcePoints)
   system.pSave("announcePoints", tostring(announcePoints))
end

local function oneSidedInputChanged(value)
   oneSidedInput = not value
   --print("oneSidedInput", oneSidedInput)
   form.setValue(oneSidedInputIndex, oneSidedInput)
   system.pSave("oneSidedInput", tostring(oneSidedInput))
   -- reset the curve if changing input types
   for i=1, #crowConfig.trimCurveX do
      crowConfig.trimCurveY[i]=0
      crowConfig.trimCurveZ[i]=0      
      crowConfig.trimCurveU[i]=0
   end
   if oneSidedInput == true then centerPoint = 5 else centerPoint = 1 end
   initCrow()
end

local function rstCurve()
   for i=1, #crowConfig.trimCurveX do
      crowConfig.trimCurveY[i]=0
      crowConfig.trimCurveZ[i]=0
      crowConfig.trimCurveU[i]=0
   end
   crowConfig.trimCurveU[centerPoint] = 1
end

local function initForm(sF)

   if sF == 1 then

      form.addRow(2)
      form.addLabel({label="Main control (Crow or Rudder)", width=220})
      form.addInputbox(crowCtrl, true, crowCtrlChanged)
      
      form.addRow(2)
      form.addLabel({label="Main control 0-100% mode", width=280})
      oneSidedInputIndex = form.addCheckbox(oneSidedInput, oneSidedInputChanged)

      form.addRow(2)
      form.addLabel({label="Main control reverse", width=280})
      reverseCrowIndex = form.addCheckbox(reverseCrow, reverseCrowChanged, {alignRight=true})
      
      --form.addRow(2)
      --form.addLabel({label="Trim Control", width=220})
      --form.addInputbox(trimCtrl, true, trimCtrlChanged)
      
      --form.addRow(2)
      --form.addLabel({label="Reverse Trim Control", width=270})
      --reverseTrimIndex = form.addCheckbox(reverseTrim, reverseTrimChanged)

      form.addRow(2)
      form.addLabel({label="Automix on/off control", width=230})
      form.addInputbox(autoCtrl, true, autoCtrlChanged, {width=90,alignRight=true})
      
      form.addRow(2)
      form.addLabel({label="Automix Elevator control", width=220})
      form.addInputbox(elevCtrl, true, elevCtrlChanged, {width=100, alignRight=true})

      form.addRow(2)
      form.addLabel({label="Automix Aileron Control", width=220})
      form.addInputbox(ailCtrl, true, ailCtrlChanged, {width=100, alignRight=true})      

      --form.addRow(2)
      --form.addLink((function() form.reinit(3) end), {label = "AutoCrow Menu >>"})

      form.addRow(2)
      form.addLink((function() form.reinit(2) end), {label = "App settings" .. ">>", width=220})
	 
      form.addRow(1)
      form.addLabel({label= appShort..".lua " .. lang.version .. " " .. crowVersion .." ",
		     font=FONT_MINI, alignRight=true})
      
   elseif sF == 2 then
   
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain,font=FONT_BOLD})
      
      --form.addRow(2)
      --form.addLabel({label="Trim step", width=260})
      --form.addIntbox(trimStep, 1, 10, 2, 0, 1, trimStepChanged)

      --form.addRow(2)
      --form.addLabel({label=lang.numCrow, width=270})
      --form.addIntbox(crowConfig.tPoints, 5, 9, 7, 0, 1, tPointsChanged)
      
      --form.addRow(2)
      --form.addLabel({label=lang.crowCurvePoint, width=220})
      --form.addSelectbox({lang.linear, lang.log}, autoCrowSpacing, false, autoCrowSpacingChanged)
      
      form.addRow(2)
      form.addLabel({label=lang.crowCurveRate, width=220})
      form.addIntbox(autoCrowRate, 10, 1000, 300, 0, 1, autoCrowRateChanged)
      
      -- form.addRow(2)
      -- form.addLabel({label=lang.crowExpo, width=220})
      -- form.addSelectbox({lang.linear, lang.mExpo, lang.pExpo},
      -- 	 autoCrowSens, false, autoCrowSensChanged)   
      

      --print("oneSidedInput, oneSidedInputIndex:", oneSidedInput, oneSidedInputIndex)
      
      form.addRow(2)
      form.addLabel({label=lang.unset, width=270})
      announcePointsIndex = form.addCheckbox(announcePoints, announcePointsChanged)

      form.addRow(2)
      form.addLink(rstCurve, {label=lang.reset ..">>", width=220})
      
      form.setFocusedRow(1)
      
   else
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain,font=FONT_BOLD})

      
   end
end

local function playNumber(num)
   local fn
   if num >= 1 and num <= 9 then
      fn = locale .. "-" .. tostring(num) .. ".wav"
      --print("fn:", fn)
      system.playFile("/" .. appDir .. fn, AUDIO_IMMEDIATE)
   end
end

local function loop()

   local info
   local swt
   local dt
   local mpl, mph
   local tp1
   local incT
   local swe, swl
   local deadBand = 0.02
   local deadCrow = 0.02
   local highestSet
   local lowestSet
   
   info = system.getSwitchInfo(crowCtrl)
   if info then
      --swc = system.getInputs(info.label) -- fails when switch is logical
      swc = info.value
   end

   info = system.getSwitchInfo(trimCtrl)
   if info then
      swt = info.value
   end

   info = system.getSwitchInfo(autoCtrl)
   if info then
      swa = info.value
   end
   
   info = system.getSwitchInfo(elevCtrl)
   if info then
      swe = info.value
   end
   
   info = system.getSwitchInfo(ailCtrl)
   if info then
      swl = info.value
   end

   if swc then
      if reverseCrow then swc = -swc end
      if oneSidedInput then
	 swcVal = (swc+1)*50
      else
	 swcVal = 100 * swc
      end
      
      --print("swcVal:", swcVal)
      
      if math.abs(swcVal) < deadCrow*100 then
	 swcVal = 0
      end
      
      crowConfig.trimPoint = centerPoint
      for i = 1 + centerPoint, #crowConfig.trimCurveX-1, 1 do
	 mpl = (crowConfig.trimCurveX[i-1] + crowConfig.trimCurveX[i]) / 2
	 mph = (crowConfig.trimCurveX[i] + crowConfig.trimCurveX[i+1]) / 2
	 if swcVal > mpl and swcVal <= mph then
	    crowConfig.trimPoint = i
	    break
	 end
      end
      if crowConfig.trimPoint == centerPoint and swcVal > mph then
	 crowConfig.trimPoint = #crowConfig.trimCurveX
      end

      --print("trimPoint1:", crowConfig.trimPoint, swcVal, centerPoint)

      if swcVal < 0.0 then
	 crowConfig.trimPoint = centerPoint
	 for i = centerPoint-1, 2, -1 do
	    mpl = (crowConfig.trimCurveX[i-1] + crowConfig.trimCurveX[i]) / 2
	    mph = (crowConfig.trimCurveX[i] + crowConfig.trimCurveX[i+1]) / 2
	    if swcVal > mpl and swcVal <= mph then
	       crowConfig.trimPoint = i
	       break
	    end
	 end
	 if crowConfig.trimPoint == centerPoint and swcVal <= mpl then
	    crowConfig.trimPoint = 1
	 end
      end
      --print("trimPoint2:", crowConfig.trimPoint)
      
      --print("trimPoint2", crowConfig.trimPoint)      

      if crowConfig.trimPoint ~= crowConfig.lastTrimPoint then
	 if crowConfig.trimCurveU[crowConfig.trimPoint] == 0 then
	    if announcePoints then
	       --print("playNumber:", crowConfig.trimPoint-1, 0)
	       --system.playNumber((crowConfig.trimPoint-1), 0)
	       playNumber(crowConfig.trimPoint-1) -- avoid DS-12 upgrade .. no system.playNumber
	    end
	 end
      end
      crowConfig.lastTrimPoint = crowConfig.trimPoint

      --print("crowConfig.trimPoint3", crowConfig.trimPoint)
      
      dt = system.getTimeCounter() - (pressTime or 0)

      -- is auto mode on?
      
      if autoCtrl and (elevCtrl or ailCtrl) and swa == 1 and
      crowConfig.trimPoint ~= centerPoint then

	 if math.abs(swe) < deadBand then
	    swe = 0
	 end

	 if elevCtrl then
	    if swe >= 0 then
	       if autoCrowSens == 2 then
		  swe = math.sqrt(swe)
	       elseif autoCrowSens == 3 then
		  swe = swe * swe
	       end
	    else
	       if autoCrowSens == 2 then
		  swe = -math.sqrt(-swe)
	       elseif autoCrowSens == 3 then
		  swe = swe * swe * -1
	       end
	    end
	 end
	 
	 if ailCtrl then
	    if swl >= 0 then
	       if autoCrowSens == 2 then
		  swl = math.sqrt(swl)
	       elseif autoCrowSens == 3 then
		  swl = swl * swl
	       end
	    else
	       if autoCrowSens == 2 then
		  swl = -math.sqrt(-swl)
	       elseif autoCrowSens == 3 then
		  swl = swl * swl * -1
	       end
	    end
	 end

	 if elevCtrl then
	    incT = (autoCrowRate / 10) * ((swe or 0) / 10)
	    crowConfig.trimCurveY[crowConfig.trimPoint] =
	       crowConfig.trimCurveY[crowConfig.trimPoint] + incT
	    crowConfig.trimCurveY[crowConfig.trimPoint] =
	       math.max(math.min(crowConfig.trimCurveY[crowConfig.trimPoint], 100), -100)
	 end

	 if ailCtrl then
	    incT = (autoCrowRate / 10) * ((swl or 0) / 10)
	    crowConfig.trimCurveZ[crowConfig.trimPoint] =
	       crowConfig.trimCurveZ[crowConfig.trimPoint] + incT
	    crowConfig.trimCurveZ[crowConfig.trimPoint] =
	       math.max(math.min(crowConfig.trimCurveZ[crowConfig.trimPoint], 100), -100)
	 end
	 
	 crowConfig.trimCurveU[crowConfig.trimPoint] = 1	 

	 highestSet = centerPoint
	 for i = centerPoint+1, #crowConfig.trimCurveX, 1 do
	    if crowConfig.trimCurveU[i] ~= 0 then highestSet = i end
	 end

	 --print("highestSet: " .. highestSet)

	 lowestSet = centerPoint
	 for i = centerPoint-1, 1, -1 do
	    if crowConfig.trimCurveU[i] ~= 0 then lowestSet = i end
	 end

	 --print("lowestSet", lowestSet)
	 --print("crowConfig.trimPoint", crowConfig.trimPoint)
	 
	 if swcVal >= 0.0 then
	    for i = crowConfig.trimPoint+1, #crowConfig.trimCurveX, 1 do
	       if crowConfig.trimCurveU[i] == 0 then
		  crowConfig.trimCurveY[i] = crowConfig.trimCurveY[highestSet]
		  crowConfig.trimCurveZ[i] = crowConfig.trimCurveZ[highestSet]		  
	       end
	    end
	 else
	    for i = crowConfig.trimPoint-1, 1, -1 do
	       if crowConfig.trimCurveU[i] == 0 then
		  crowConfig.trimCurveY[i] = crowConfig.trimCurveY[lowestSet]
		  crowConfig.trimCurveZ[i] = crowConfig.trimCurveZ[lowestSet]		  
	       end
	    end	    
	 end
      end

      if autoCtrl and elevCtrl and swa == 1 then
	 if system.getTimeCounter() - autoAnnounce > 1500 then
	    system.playFile("/" .. appDir .. locale .. "-auto_crow.wav", AUDIO_QUEUE)
	    autoAnnounce = system.getTimeCounter() + 1500
	    --system.pSave("trimCurveY", trimCurveY)
	    --system.pSave("trimCurveU", trimCurveU)
	 end
      end

      --print("crowConfig.trimPoint", crowConfig.trimPoint)

      --for k,v in pairs(crowConfig.trimCurveX) do
      --print(k,v)
      --end
      
      if swcVal < crowConfig.trimCurveX[crowConfig.trimPoint] then
	 mixValE = crowConfig.trimCurveY[crowConfig.trimPoint-1] +
	    (crowConfig.trimCurveY[crowConfig.trimPoint] -
		crowConfig.trimCurveY[crowConfig.trimPoint-1]) *
	    (swcVal - crowConfig.trimCurveX[crowConfig.trimPoint-1]) /
	    (crowConfig.trimCurveX[crowConfig.trimPoint] -
		crowConfig.trimCurveX[crowConfig.trimPoint-1])

	 mixValA = crowConfig.trimCurveZ[crowConfig.trimPoint-1] +
	    (crowConfig.trimCurveZ[crowConfig.trimPoint] -
		crowConfig.trimCurveZ[crowConfig.trimPoint-1]) *
	    (swcVal - crowConfig.trimCurveX[crowConfig.trimPoint-1]) /
	    (crowConfig.trimCurveX[crowConfig.trimPoint] -
		crowConfig.trimCurveX[crowConfig.trimPoint-1])
	 
      else
	 tp1 = math.min(crowConfig.trimPoint+1, #crowConfig.trimCurveX)
	 tp0 = tp1 - 1
	 mixValE = crowConfig.trimCurveY[tp0] +
	    (crowConfig.trimCurveY[tp1] - crowConfig.trimCurveY[tp0]) *
	    (swcVal - crowConfig.trimCurveX[tp0]) /
	    (crowConfig.trimCurveX[tp1] - crowConfig.trimCurveX[tp0])

	 mixValA = crowConfig.trimCurveZ[tp0] +
	    (crowConfig.trimCurveZ[tp1] - crowConfig.trimCurveZ[tp0]) *
	    (swcVal - crowConfig.trimCurveX[tp0]) /
	    (crowConfig.trimCurveX[tp1] - crowConfig.trimCurveX[tp0])
	 
      end

      if acvEleCtrl then
	 system.setControl(acvEleCtrl, luaControlMax * mixValE / 100.0, 50)
      end

      if acvAilCtrl then
	 system.setControl(acvAilCtrl, luaControlMax * mixValA / 100.0, 50)
      end      
   end
end

local function xpix(x)
   if not x then print("############################################") return end
   if oneSidedInput then
      return 4 + (x/100) * 140
   else
      return 4 + (x+100)/200 * 140
   end
   
end

local function ypix(y)
   if not y then print("***********************************************") return end
   return 35 - (y/4)
end

local function teleWindowE()

   local sR = 6
   local lR = 10
   local ren
   local dx
   
   if not monoChrome then
      ren = lcd.renderer()
   end
   
   if swc then
      --print("crowConfig.trimPoint TeleE", crowConfig.trimPoint)
      if crowConfig.trimPoint > 0 then
	 lcd.drawRectangle(xpix(crowConfig.trimCurveX[crowConfig.trimPoint]) - lR/2 + 1,
				ypix(crowConfig.trimCurveY[crowConfig.trimPoint]) - lR/2,
				lR, lR)
	 if crowConfig.trimPoint ~= centerPoint then
	    if crowConfig.trimPoint < #crowConfig.trimCurveX then dx = 6 else dx = 9 end
	    if crowConfig.trimPoint == 1 then dx = 3 end 
	    lcd.drawText(xpix(crowConfig.trimCurveX[crowConfig.trimPoint])-dx,55,
			 string.format("%d", crowConfig.trimCurveY[crowConfig.trimPoint]), FONT_MINI)
	    if autoCtrl and elevCtrl and swa == 1 then -- autotrim is on!
	       lcd.setColor(255,0,0)
	       lcd.drawText(40,5, lang.auto, FONT_MINI)
	       lcd.setColor(0,0,0)
	    end
	 end
      end
      if mixValE then
	 lcd.drawRectangle(xpix(swcVal) - sR/2 + 1, ypix(mixValE) - sR/2, sR, sR)
	 lcd.drawText(5,5,string.format("%.1f", mixValE), FONT_MINI)
      end
   end

   lcd.drawLine(4,35,144,35)

   if not oneSidedInput then
      lcd.drawLine(74,55,74,15)
   end
   
   if monoChrome then
      for i=1, #crowConfig.trimCurveX, 1 do
	 if crowConfig.trimCurveU[i] == 1 then
	    lcd.setColor(0,0,255)
	    iSize = 4
	 else
	    lcd.setColor(255,0,0)
	    iSize = 3
	 end
	 lcd.drawCircle(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveY[i]), iSize)
	 lcd.setColor(0,0,0)
	 if i < #crowConfig.trimCurveX then
	    lcd.drawLine(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveY[i]),
			 xpix(crowConfig.trimCurveX[i+1]), ypix(crowConfig.trimCurveY[i+1]))
	 end
      end
   else
      ren:reset()
      for i=1, #crowConfig.trimCurveX, 1 do
	 if crowConfig.trimCurveU[i] == 1 then
	    lcd.setColor(0,0,255)
	    iSize = 4
	 else
	    lcd.setColor(255,0,0)
	    iSize = 4
	 end
	 lcd.drawCircle(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveY[i]), iSize)
	 lcd.setColor(0,0,0)
	 ren:addPoint(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveY[i]))
      end
      ren:renderPolyline(1)
   end
end

local function teleWindowA()

   local sR = 6
   local lR = 10
   local ren
   local dx

   if not monoChrome then
      ren = lcd.renderer()
   end
   
   if swc then
      if crowConfig.trimPoint > 0 then
	 lcd.drawRectangle(xpix(crowConfig.trimCurveX[crowConfig.trimPoint]) - lR/2 + 1,
				ypix(crowConfig.trimCurveZ[crowConfig.trimPoint]) - lR/2,
				lR, lR)
	 if crowConfig.trimPoint ~= centerPoint then
	    if crowConfig.trimPoint < #crowConfig.trimCurveX then dx = 6 else dx = 9 end
	    if crowConfig.trimPoint == 1 then dx = 3 end 
	    lcd.drawText(xpix(crowConfig.trimCurveX[crowConfig.trimPoint])-dx,55,
			 string.format("%d", crowConfig.trimCurveZ[crowConfig.trimPoint]), FONT_MINI)
	    if autoCtrl and ailCtrl and swa == 1 then -- autotrim is on!
	       lcd.setColor(255,0,0)
	       lcd.drawText(40,5, lang.auto, FONT_MINI)
	       lcd.setColor(0,0,0)
	    end
	 end
      end
      if mixValA then
	 lcd.drawRectangle(xpix(swcVal) - sR/2 + 1, ypix(mixValA) - sR/2, sR, sR)
	 lcd.drawText(5,5,string.format("%.1f", mixValA), FONT_MINI)
      end
   end

   lcd.drawLine(4,35,144,35)

   if not oneSidedInput then
      lcd.drawLine(74,55,74,15)
   end
   
   if monoChrome then
      for i=1, #crowConfig.trimCurveX, 1 do
	 if crowConfig.trimCurveU[i] == 1 then
	    lcd.setColor(0,255,0)
	    iSize = 4
	 else
	    lcd.setColor(0,255,0)
	    iSize = 3
	 end
	 lcd.drawCircle(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveZ[i]), iSize)
	 lcd.setColor(0,0,0)
	 if i < #crowConfig.trimCurveX then
	    lcd.drawLine(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveZ[i]),
			 xpix(crowConfig.trimCurveX[i+1]), ypix(crowConfig.trimCurveZ[i+1]))
	 end
      end
   else
      ren:reset()
      for i=1, #crowConfig.trimCurveX, 1 do
	 if crowConfig.trimCurveU[i] == 1 then
	    lcd.setColor(0,255,0)
	    iSize = 4
	 else
	    lcd.setColor(255,0,0)
	    iSize = 4
	 end
	 lcd.drawCircle(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveZ[i]), iSize)
	 lcd.setColor(0,0,0)
	 ren:addPoint(xpix(crowConfig.trimCurveX[i]), ypix(crowConfig.trimCurveZ[i]))
      end
      ren:renderPolyline(1)
   end
end

local function destroy()

   local ff

   if acvCtrl then system.unregisterControl(acvCtrl) end

   ff = io.open(modelFile, "w") 
   if not ff then
      system.messageBox(appShort .. ": " .. lang.cannotOpen)
      return
   end
   if not io.write(ff,json.encode(crowConfig)) then
      system.messageBox(appShort .. ": " .. lang.cannotWrite)
      return
   end
   io.close(ff)

end

local function init()

   local devType, emFlag
   local monoDev = {"JETI DC-16", "JETI DS-16", "JETI DC-14", "JETI-DS-14"}
   local ff

   setLanguage()
   
   -- Form autoCrow param file name from model name
   modelFile = appDir .. "C-" .. string.gsub(system.getProperty("Model")..".jsn", " ", "_")
   print("modelFile: " .. modelFile)
   ff = io.readall(modelFile)
   print("ff: ", ff)

   if ff then crowConfig = json.decode(ff) end

   if not crowConfig.trimCurveX then
      crowConfig.tPoints = 9
      system.messageBox(appShort .. lang.noSave)
   else
      -- here if populated crowConfig table
   end

   crowCtrl        = system.pLoad("crowCtrl")
   --trimCurveY      = system.pLoad("trimCurveY")
   --trimCurveU      = system.pLoad("trimCurveU")   
   trimCtrl        = system.pLoad("trimCtrl")
   trimStep        = system.pLoad("trimStep", 2)
   --tPoints         = system.pLoad("tPoints", 7)   
   elevCtrl        = system.pLoad("elevCtrl")
   ailCtrl         = system.pLoad("ailCtrl")
   autoCtrl        = system.pLoad("autoCtrl")   
   autoCrowRate    = system.pLoad("autoCrowRate", 300)
   autoCrowSens    = system.pLoad("autoCrowSens", 1)
   autoCrowSpacing = system.pLoad("autoCrowSpacing", 1)   
   
   reverseCrow = system.pLoad("reverseCrow", "false")
   reverseCrow = (reverseCrow == "true")

   reverseTrim = system.pLoad("reverseTrim", "false")
   reverseTrim = (reverseTrim == "true")

   announcePoints = system.pLoad("announcePoints", "true")
   announcePoints = (announcePoints == "true")      

   oneSidedInput = system.pLoad("oneSidedInput", "false")
   oneSidedInput = (oneSidedInput == "true")
   if oneSidedInput == true then centerPoint = 1 else centerPoint = 5 end

   devType, emFlag = system.getDeviceType()

   --devType = "JETI DS-16"

   print("devType: " .. devType)
   
   monoChrome = false
   
   for _,v in ipairs(monoDev) do
      if devType == v then
	 monoChrome = true
	 break
      end
   end

   if monoChrome then
      print(appShort .. ": Monochrome device " .. devType .. " detected")
   end

   initCrow()

   system.registerForm(1, MENU_APPS, "Adaptive Mixer", initForm)
   system.registerTelemetry(1, "Elevator Mix Curve", 2, teleWindowE) 
   system.registerTelemetry(2, "Aileron Mix Curve", 2, teleWindowA)   

   -- start searching for free lua controls
   -- fixed for DS-16 to controls 1 and 2
   -- for DS-24 start at 5
   
   if monoChrome then
      acvEleCtrl = system.registerControl(1, "Adaptive Mix Value Elevator", "AME")      
      acvAilCtrl = system.registerControl(1, "Adaptive Mix Value Aileron" , "AMA")      
   else
      for i=1,10,1 do
	 acvEleCtrl = system.registerControl(1+(i+3)%10, "Adaptive Mix Value Elevator", "AME")
	 acvAilCtrl = system.registerControl(1+(i+4)%10, "Adaptive Mix Value Elevator", "AMA")	 
	 if acvAilCtrl then break end
      end
   end
   
   if acvEleCtrl then
      print(appShort .. ": AME registered to control " .. acvEleCtrl)
      system.setControl(acvEleCtrl,0,0)      
   else
      print(appShort .. ": Could not register AME control")      
   end

   if acvAilCtrl then
      print(appShort .. ": AMA registered to control " .. acvAilCtrl)
      system.setControl(acvAilCtrl,0,0)      
   else
      print(appShort .. ": Could not register AMA control")      
   end

   if not acvEleCtrl or not acvAilCtrl then
      system.messageBox(appShort .. ": " .. lang.cannotReg)
   end

   print(appShort .. ": gc count " .. collectgarbage("count"))

end

return {init=init, loop=loop, author="DFM/HC", version=tostring(crowVersion),
	name="Adaptive Crow Mixer", destroy=destroy}
