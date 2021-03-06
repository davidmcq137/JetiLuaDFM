--[[

   DFM-Crow.lua

   Adaptive crow trim offset, JETI adaptation of the orgininal open TX
   app done by Mike Shellim at the suggestion of Harry Curzon

   ---------------------------------------------------------
   Released under MIT-license by DFM 2021
   ---------------------------------------------------------
   
   Version 0.1 - Apr 3, 2021

--]]

-- Locals for application

local crowVersion= 0.1

local crowCtrl
local crowCurve = {} -- {0,0,0,0,0}
local crowCurveSet = {} --{true, false, false, false, false}

local lastTrim = 0
local lastIdx = 0

local mixVal

local shortAnn, shortAnnIndex

local function allSet()
   for i=1, #crowCurve, 1 do
      if crowCurveSet[i] == false then return false end
   end
   return true
end

local function crowCtrlChanged(value)
   crowCtrl = value
   print("changed: crowCtrl =", crowCtrl)
   system.pSave("crowCtrl", crowCtrl)
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

-- Draw the main form (Application inteface)

local function rstCurve()
   print("reset curve")
   for i=1, #crowCurve do
      crowCurve[i]=0
      crowCurveSet[i] = false
   end
   crowCurveSet[1] = true
   system.messageBox("go reset digital trim")
end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Crow Control", width=220})
   form.addInputbox(crowCtrl, true, crowCtrlChanged)
   
   --form.addRow(2)
   --form.addLabel({label="Short Announcements", width=270})
   --shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)

   form.addRow(2)
   form.addLink(rstCurve, {label = "Reset curve"})
   
   form.addRow(1)
   form.addLabel({label="DFM-Crow.lua Version "..crowVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local function loop()

   local swc
   local swcInfo
   local swcVal
   local segment
   local trimVal
   
   swc = system.getInputsVal(crowCtrl)

   if swc and swc == 1 then
      swcInfo = system.getSwitchInfo(crowCtrl)
      swcVal = 100 * (1 + system.getInputs(swcInfo.label)) / 2
      segment = math.min(math.floor(swcVal / 25) + 1, 4) -- don't jump to 5 at 100 .. stay at 4
      mixVal = crowCurve[segment] +
	 (crowCurve[segment+1] - crowCurve[segment]) *
	 (swcVal - (segment-1)*25) / 25
      system.setControl(1, mixVal / 100.0, 0)
      
      swcIdx = math.floor((swcVal + 37.5) / 25)
      if swcIdx > 1  then
	 trimVal = 100 * system.getInputs("O24")
	 
	 if swcIdx ~= lastIdx and allSet() then mixOffset = crowCurve[swcIdx] -trimVal end

	 if not allSet() then
	    crowCurve[swcIdx] = trimVal
	    crowCurveSet[swcIdx] = true
	    system.pSave("crowCurve", crowCurve)
	 else
	    if trimVal ~= lastTrim then
	       crowCurve[swcIdx] = trimVal + (mixOffset or 0)
	    end
	 end
	 
	 lastTrim = trimVal
	 lastIdx = swcIdx
      end
   end
end

local function teleWindow(w,h)

   local swcInfo, swcVal, swc, trimVal
   
   --print(w,h) -- 151x69
   swc = system.getInputsVal(crowCtrl)
   if swc and swc == 1 then
      swcInfo = system.getSwitchInfo(crowCtrl)
      swcVal = 100 * (1 + system.getInputs(swcInfo.label)) / 2
      swcIdx = math.floor((swcVal + 37.5) / 25)
      trimVal = 100 * system.getInputs("O24")
      --print("trimVal " .. trimVal .. " swcIdx " .. swcIdx ..
      --" swcVal " .. swcVal .." mixVal " .. (mixVal or "---") )
      if swcIdx > 1 then
	 lcd.drawRectangle(4 + (swcIdx-1) * 35 - 5 + 1, 35 - (trimVal + (mixOffset or 0))/2 - 5, 10, 10)
      end
      if mixVal then
	 lcd.drawRectangle(4 + (swcVal * 140 / 100) - 3 + 1, 35 - mixVal/2 - 3, 6, 6)
      end
   end

   lcd.drawLine(4,35,144,35)
   for i=1, #crowCurve, 1 do
      lcd.drawCircle(4 + (i-1) * 35, 35 - crowCurve[i] / 2, 4)
      if i < #crowCurve then
	 lcd.drawLine(4 + (i-1) * 35, 35 - crowCurve[i] / 2, 4 + (i) * 35, 35 - crowCurve[i+1]/2)
      end
   end
end

local function keyForm(key)
   if key == 8192 then form.preventDefault()  end
   print("key: " .. key)
end

local function init()

   local rc
   local allZero = true
   local tt
   
   crowCtrl    = system.pLoad("crowCtrl")
   shortAnn    = system.pLoad("shortAnn", "false")
   shortAnn = (shortAnn == "true") -- convert back to boolean here

   print("crowCtrl:", crowCtrl)

   if crowCtrl then
      tt = system.getSwitchInfo(crowCtrl)
      for k,v in pairs(tt) do
	 print(k,v)
      end
   end
   
   trimVal = 100 * system.getInputs("O24")
   print("trimVal:", trimVal)
   
   crowCurve = system.pLoad("crowCurve", {0,0,0,0,0})

   for i=1,#crowCurve,1 do
      print("i, crowCurve[i] " .. i .. " " .. crowCurve[i])
   end
   
   for i=1, #crowCurve, 1 do
      if crowCurve[i] ~= 0 then
	 allZero = false
	 break
      end
   end

   if allZero then
      crowCurveSet[1] = true
      for i=2, #crowCurve, 1 do
	 crowCurveSet[i] = false
      end
   else
      for i=2, #crowCurve, 1 do
	 crowCurveSet[i] = true
      end
   end
   
   system.registerForm(1, MENU_APPS, "Adaptive Crow Mixer", initForm, keyForm)
   system.registerTelemetry(1, "Mix Curve", 2, teleWindow)

   rc = system.registerControl(1, "Adaptive Crow", "CRW")

   if not rc then print("Could not register control") end

   for k,v in pairs(_G) do
      print("Global key", k, "value", v)
      if k == "system" then
	 for k,v in pairs(v) do
	    print("System key", k, "value", v)
	 end
      end
   end
end

return {init=init, loop=loop, author="DFM", version=tostring(crowVersion),
	name="Adaptive Crow Mixer"}
