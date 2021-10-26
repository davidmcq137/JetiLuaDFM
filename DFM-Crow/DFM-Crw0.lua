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
local crowCurve = {}
local trimCtrl
local trimCtrlIdx
local trimFunc=1
local swc

local reverseCrow
local reverseCrowIndex

local lastswt=0

local swcVal
local mixVal
local segment
local trimVal

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

local function rstCurve()
   for i=1, #crowCurve do
      crowCurve[i]=0
   end
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
   form.addLink(rstCurve, {label="Reset mix curve"})
   
   form.addRow(1)
   form.addLabel({label="DFM-Crow.lua Version "..crowVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local function lPoly(x)

   local y={}
   lC = {}
   local sum
   local pN
   local pD

   y[0] = 0
   for i=1,4,1 do
      y[i] = crowCurve[i]
      --print(25*i, y[i])
   end

   sum = 0
   for i=0,4,1 do
      pN = 1
      pD = 1
      for j=0,4,1 do
	 if j ~= i then
	    pN = pN * (x - 25*j)
	    pD = pD * (25*i - 25*j)
	 end
      end
      sum = sum + y[i] * pN / pD
   end
   --print("lPoly:",x,sum)
   return sum
end

local yC
local np=20

local function compP()
   local x
   print("compP")
   yC = {}
   for i=0, np, 1 do
      x = i * 100 / np
      yC[i] = lPoly(x)
   end
end

local function loop()

   local info
   local swt
   local cc
   local dt
   
   info = system.getSwitchInfo(crowCtrl)
   if info then
      swc = system.getInputs(info.label)
   end
   
   if swc then
      if reverseCrow then swc = -swc end
      swcVal = (swc+1)*50
      --print(swc, swcVal)
      
      segment = math.min(math.floor(swcVal / 25) + 1, 4) -- don't jump to 5 at 100 .. stay at 4

      emFlag = false -- (select(2,system.getDeviceType()) == 1)
      if emFlag then
	 swt = system.getInputs("SI")
      else
	 swt = system.getInputsVal(trimCtrl)
      end

      print("swt:", swt)
      
      dt = system.getTimeCounter() - (pressTime or 0)
      
      if swt and swt ~= 0 and (lastswt == 0 or dt > pressHold) then
	 pressTime = system.getTimeCounter()
	 if swt == 1 and (lastswt ~= 1 or dt > pressHold) then
	    if crowCurve[segment] <= 48 then -- clamp to +/- 50
	       crowCurve[segment] = crowCurve[segment] + 2
	    end
	    system.pSave("crowCurve", crowCurve)
	    --compP()
	 elseif swt == -1 and (lastswt ~= -1 or dt > pressHold) then
	    if crowCurve[segment] >= -48 then
	       crowCurve[segment] = crowCurve[segment] - 2
	    end
	    system.pSave("crowCurve", crowCurve)
	    --compP()
 	 end
      end
      
      lastswt = swt

      if segment <= 1 then
	 cc = 0
      else
	 cc = crowCurve[segment-1]
      end
      
      mixVal = cc +
	 (crowCurve[segment] - cc) *
	 (swcVal - (segment-1)*25) / 25

      system.setControl(trimFunc, mixVal / 100.0, 50)

   end
end



local function teleWindow(w,h)
   local cc
   local x, x2
   if swc then
      if segment > 0 then
	 lcd.drawRectangle(4 + (segment) * 35 - 5 + 1, 35 - crowCurve[segment]/2 - 5, 10, 10)
	 lcd.drawText(35*segment-2,55,string.format("%d", crowCurve[segment]), FONT_MINI)
      end
      if mixVal then
	 lcd.drawRectangle(4 + (swcVal * 140 / 100) - 3 + 1, 35 - mixVal/2 - 3, 6, 6)
	 lcd.drawText(5,5,string.format("%.1f", mixVal), FONT_MINI)
	 --lcd.drawRectangle(4 + (swcVal * 140 / 100) - 3 + 1, 35 - lPoly(swcVal)/2 - 3, 6, 6)
	 --lcd.drawText(5,5,string.format("%.1f", lPoly(swcVal)), FONT_MINI)
      end
   end
   lcd.drawLine(4,35,144,35)
   for i=1, 5, 1 do
      if i == 1 then cc = 0 else cc = crowCurve[i-1] end
      lcd.drawCircle(4 + (i-1) * 35, 35 - cc / 2, 4)
      if i < 5 then
	 lcd.drawLine(4 + (i-1) * 35, 35 - cc / 2, 4 + (i) * 35, 35 - crowCurve[i]/2)
      end
      --[[
      for i=0, np, 1 do
	 x = i * 100 / np
	 x2 = (i+1) * 100 / np
	 if x2 <= 100 then
	    lcd.drawLine(4 + x*1.4, 35 - yC[i]/2, 4 + x2 *1.4, 35 - yC[i+1]/2)
	 end
      end
      --]]
   end
end

local function destroy()
   system.pSave("crowCurve", crowCurve)
end

local function init()

   local rc
   
   crowCtrl    = system.pLoad("crowCtrl")
   crowCurve   = system.pLoad("crowCurve", {0,0,0,0})
   trimCtrl    = system.pLoad("trimCtrl")
   reverseCrow   = system.pLoad("reverseCrow", "false")
   reverseCrow = (reverseCrow == "true")
   
   system.registerForm(1, MENU_APPS, "Adaptive Crow Mixer", initForm)
   system.registerTelemetry(1, "Crow Mix Curve", 2, teleWindow)

   rc = system.registerControl(trimFunc, "Adaptive Crow Val", "ACV")
   if not rc then print("DFM-Crow: Could not register ACV control") end
   system.setControl(trimFunc,0,0)

   --compP()
   
end

return {init=init, loop=loop, author="DFM", version=tostring(crowVersion),
	name="Adaptive Crow Mixer", destroy=destroy}
