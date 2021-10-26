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
local crowCurve

local lastTrim = 0
local lastIdx = 0
local lastSegment = 0
local lastControl = 0

local swcVal
local swcIdx
local mixVal
local segment
local trimVal

local shortAnn, shortAnnIndex

local swc

local function allSet()
   for i=1, #crowCurve, 1 do
      if crowCurveSet[i] == false then return false end
   end
   return true
end

local function crowCtrlChanged(value)
   crowCtrl = value
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
   
   form.addRow(1)
   form.addLabel({label="DFM-Crow.lua Version "..crowVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local sg = 0
local flMode = 0
local lastMode = 0
local i=0
local lastswp=0

local function loop()

   local info, tv

   local swp
      
   info = system.getSwitchInfo(crowCtrl)
   if info then
      swc, tv = system.getInputs(info.label, "O24")
      trimVal = tv * 100
   end

   swp = system.getInputs("SI")

   if swp and swp ~= 0 and lastswp == 0 then
      if swp == 1 and lastswp ~= 1 then
	 print("swp1")
      elseif swp == -1 and lastswp ~= -1 then
	 print("swp-1")
      end
   end

   lastswp = swp

   if swc then

      swcVal = (swc+1)*50

      segment = math.min(math.floor(swcVal / 25) + 1, 4) -- don't jump to 5 at 100 .. stay at 4
      swcIdx = math.floor((swcVal + 37.5) / 25)
      
      if swcVal < 10 then flMode = 0 else flMode = segment end
      
      if segment > 0 and swcVal >= 10 then
	 --print("segment, trimVal", segment, trimVal)
	 crowCurve[segment] = trimVal
      end

      mixVal = crowCurve[segment-1] +
	 (crowCurve[segment] - crowCurve[segment-1]) *
	 (swcVal - (segment-1)*25) / 25

      if lastMode ~= flMode then
	 sg = system.getTimeCounter()
	 if lastMode >= 1 then
	    --print("lower", lastMode)
	    system.setControl(lastMode, -1, 0)
	 end
	 if flMode > 0 then
	    --print("raise", flMode)
	    system.setControl(flMode, 1, 0)
	 end
	 
      end
      lastMode = flMode

      system.setControl(5, mixVal / 100.0, 50)

   end
end

local function teleWindow(w,h)

   local allset
   
   if system.getTimeCounter() - sg < 10 then return end
   
   --lcd.drawText(5,5,"seg ".. (segment or "...") .. " trm " .. (trimVal or "...") ..
		   --" mix " .. (mixVal or "..."), FONT_MINI)
   if swc then
      if segment > 0 then
	 lcd.drawRectangle(4 + (segment) * 35 - 5 + 1, 35 - crowCurve[segment]/2 - 5, 10, 10)
      end
      if mixVal then
	 lcd.drawRectangle(4 + (swcVal * 140 / 100) - 3 + 1, 35 - mixVal/2 - 3, 6, 6)
      end
   end

   lcd.drawLine(4,35,144,35)

   for i=1, 5, 1 do
      lcd.drawCircle(4 + (i-1) * 35, 35 - crowCurve[i-1] / 2, 4)
      if i < 5 then
	 lcd.drawLine(4 + (i-1) * 35, 35 - crowCurve[i-1] / 2, 4 + (i) * 35, 35 - crowCurve[i]/2)
      end
   end
   
end

local function keyForm(key)
   print("key: " .. key)
end

local function init()

   local rc
   
   crowCtrl    = system.pLoad("crowCtrl")
   shortAnn    = system.pLoad("shortAnn", "false")
   shortAnn = (shortAnn == "true") -- convert back to boolean here

   system.registerForm(1, MENU_APPS, "Adaptive Crow Mixer", initForm, keyForm)
   system.registerTelemetry(1, "Mix Curve", 2, teleWindow)

   for i=1,4,1 do
      rc = system.registerControl(i, "Adaptive Crow FM "..i, "AC"..i)
      if not rc then print("DFM-Crow: Could not register control FM "..i) end
      system.setControl(i, -1, 0)
   end

   rc = system.registerControl(5, "Adaptive Crow Val", "ACV")
   if not rc then print("DFM-Crow: Could not register ACV control") end
   system.setControl(5,0,0)

   crowCurve = {0,0,0,0}
   crowCurve[0] = 0

end

return {init=init, loop=loop, author="DFM", version=tostring(crowVersion),
	name="Adaptive Crow Mixer"}
