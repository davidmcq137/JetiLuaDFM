--[[

   -----------------------------------------------------------------------------------------
   DFM-Pump.lua 

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-Pump.lua released under MIT license by DFM 2019
   -----------------------------------------------------------------------------------------

--]]

-- Persistent and global variables for entire progrem

local PumpVersion = "0.0"
local appName = "Fuel Station Display"
local appMenu = "Fuel Station Settings"
local appShort = "DFM-Pump"
local appDir = "Apps/"..appShort.."/"
local ren = lcd.renderer()

local sidSerial
local bps
local cnt

--local sfp
local longData = 0

local strCount=0
local lastStrCount = 0
local lastTime = system.getTime()
local lastKey = -1
local infoMsg = ""

local rTIM, pPSI, rPWM, fCNT, fRAT, Batt, pSTP, fDEL, fDET, Curr, pPWM
local fCLK

local deltaCLK=0

local rTIMmins=0
local rTIMsecs=0
local CalE
local CalF
local maxPWM
local lowBattLimit
local pumpState = "Off"
local pumpOnline = false
local lastPumpRead = 0
local lowBattAnn = false
local pressSetpoint = 5.0
local showPump = true

local graphStyle = {"Line","Hazel","Point","Histogram"}
local graphStyleIdx = 2

local graphScaleIdx = 1
local graphScaleRange =    {5,  10,  20,  50}
local graphScaleFormat = {"%d","%d","%d","%d"}
local graphScale = graphScaleRange[4]
local graphFmt = graphScaleFormat[4]

local graphScale2Idx = 1
local graphScale2Range =    {0.2, 0.5,   1,   2,   5,  10}
local graphScale2Format = {"%.1f","%.1f","%d","%d","%d","%d"}
local graphScale2 = graphScale2Range[4]
local graphFmt2 = graphScale2Format[4]

local p1High, p1Low
local p2High, p2Low

local graphValue = 0
local graphValue2 = 0
local graphName = "gn1"
local graphName2 = "gn2"
local graphUnit = '---'
local graphUnit2 = '---'
local highY, lowY
local highY2, lowY2

local oldModSec 
local runningTime 
local startTime
local timeline = 120
local nextsgTC 
local deltasg = 200

-- xboxWidth, maxPoints, xbox, ybox must be integers
-- must have xbox = maxPoints * xboxWidth

local xbox = 300 -- main box width
local ybox = 80 -- main box height
local maxPoints = 60
local xboxWidth = 5 -- pixel width of histograms

local histogram = {} -- table of values for "chart recorder" graph
local penDown = {}
local histogram2 = {} -- table of values for "chart recorder" graph
local penDown2 = {}
local x0, y0

local demoMode = false


local needle_poly_small = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}

local marker_poly_small = {
   {-3,26},
   { 3,26},
   { 1,16},
   {-1,16}
}

local function drawTextCenter(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end


local function drawShape(col, row, shape, rotation, clr)
   local sinShape, cosShape

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for index, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   lcd.setColor(clr.r,clr.g,clr.b)
   ren:renderPolygon()
   lcd.setColor(0, 0, 0)
end

local function drawGauge(label, lcol, min, mid, max, tmp, unit, ox, oy, marker)
   
   local color={}
   local theta
   local temp

   temp = tmp or min
   
   if temp <= mid then
      color.r=255*(temp-min)/(mid-min)
      color.g=255
      color.b=0
   else
      color.r=255
      color.g=255*(1-(temp-mid)/(max-mid))
      color.b=0
   end

   if not unit then
      color.r=0
      color.g=0
      color.b=255
   end
   
   if lcol == "red" then
      lcd.setColor(255,0,0)
   elseif lcol == "blue" then
      lcd.setColor(0,0,255)
   else
      lcd.setColor(0,0,0)
   end

   drawTextCenter(FONT_MINI, label, ox+25, oy+44) -- was 38
   
   local tt
   if tmp then
      if temp < 0 then
	 lcd.setColor(255,0,0)
	 tt = -temp
      else
	 lcd.setColor(0,0, 255)
	 tt = temp
      end
      drawTextCenter(FONT_MINI, string.format("%.1f", tt), ox+25, oy+18) -- was oy + 16
   end
   lcd.setColor(120,120,120)
   
   if unit and tmp then
      if min ~= 0 then
	 drawTextCenter(FONT_MINI,
			string.format("%d", min) .. " - " .. string.format("%d", max) .. unit,
			ox + 25, oy+52)
      else
	 drawTextCenter(FONT_MINI,
			string.format("%d", max) .. unit,
			ox + 25, oy+52)
      end
   end
   
   lcd.setColor(0,0,0)
   
   temp = math.min(max, math.max(temp, min))
   theta = math.pi - math.rad(135 - 2 * 135 * (temp - min) / (max - min) )
   
   if arcFile ~= nil then
      lcd.drawImage(ox, oy, arcFile)
   end

   if tmp then -- don't draw needle if value passed in is nil
      drawShape(ox+25, oy+26, needle_poly_small, theta, color)
   end

   --marker = 5 * (1 + system.getInputs("P5"))
   
   if marker then
      if lcol == "red" then
	 color.r = 255
	 color.g = 0
	 color.b = 0
      elseif lcol == "blue" then
	 color.r = 0
	 color.g = 0
	 color.b = 255
      else
	 color.r = 0
	 color.g = 0
	 color.b = 0
      end
      theta = math.pi - math.rad(135 - 2 * 135 * (marker - min) / (max - min) )
      drawShape(ox+25, oy+26, marker_poly_small, theta, color)
   end
   
end

local function graphReset()
   histogram = {}
   penDown = {}
   histogram2 = {}
   penDown2 = {}
   
   oldModSec = 0
   nextsgTC = system.getTimeCounter()
   startTime = nextsgTC / 1000
   runningTime = startTime
end

local function countedWrite(str)

   local time
   strCount = strCount + #str

   time = system.getTime()
   if time - lastTime > 10 then
      --print("time, total count, rate in last min:",
      --time-zeroTime, strCount, (strCount-lastStrCount) / (time-lastTime) )
      bps = (strCount - lastStrCount) / (time-lastTime)
      lastStrCount = strCount
      lastTime = time
   end
   if sidSerial then
      cnt = serial.write(sidSerial, str)
   end
   
end
local function dashLine(xp0, yp0, xp1, yp1)

   local d, ratio
   local xd0, xd1, yd0, yd1
   local dlen = 12
   ren = lcd.renderer()

   --d = math.abs(xp1-xp0) + math.abs(yp1-yp0)
   d = math.sqrt( (xp1-xp0)^2 + (yp1-yp0)^2 )
   ratio = d / dlen

   dx = (xp1-xp0) / ratio
   dy = (yp1-yp0) / ratio

   count = count + 1

   if d < dlen*.7 then -- 0.7 arbitrary chose to look best
      return
   end

   ren:reset()
   for i=1, math.floor(ratio+0.9), 1 do
      xd0 = xp0 + (i-1) * dx
      yd0 = yp0 + (i-1) * dy
      xd1 = xd0 + dx/2
      yd1 = yd0 + dy/2
      --xd1 = math.min(xp1, xd1)
      --yd1 = math.min(yp1, yd1)
      --print(i, d, ratio, xd0, yd0, xd1, yd1)
      ren:addPoint(xd0, yd0)
      ren:addPoint(xd1, yd1)
      ren:renderPolyline(2,0.4)
      ren:reset()
   end
end

local function graphPrint()

   local xoff =     5 -- x offset from 0,0
   local yoff =     62 -- y offset from 0,0
   
   local mm, rr
   local mmm, rrr
   local ww, ss
   local yh
   local gv
   local ren = lcd.renderer()
   local xp, yp, lastDown
   local xup, yup, xdown, ydown
   local fmt

   --print("graphPrint", #histogram)
   
   -- make sure we are set to black
   lcd.setColor(0,0,0)

   -- draw graph titles - scale, time, sensor info
   mm, rr = math.modf(runningTime/60)
   mmm, rrr = math.modf(timeline/60)
   --ss = string.format("Mode: %s  Runtime: %02d:%02d  Timeline %02d:%02d",
	--	      graphStyle[graphStyleIdx], math.floor(mm), math.floor(rr*60),
	--	      math.floor(mmm), math.floor(rrr*60) )
   --ww = lcd.getTextWidth(FONT_MINI, ss)
   --lcd.drawText(xoff + xbox/2-ww/2+1,yoff+2, ss, FONT_MINI)

   lcd.setColor(120,120,120)

   --ss = string.format("tpCPU, lpCPU: %02d%% %02d%%", tpCPU, lpCPU)
   --lcd.drawText(180, 140, ss, FONT_MINI)

   if false then --graphSeId ~= 0 then
      lcd.setColor(0,0,200)
      if graphValue then gv = string.format("%3.1f", graphValue) else gv = "---" end
      ss = string.format("%s: %s %s  Scale: %d",
			 graphName or " ",
			 gv, graphUnit or " ",
			 graphScale)
      
      ww = lcd.getTextWidth(FONT_MINI, ss)
      lcd.drawText(xoff + (xbox-ww)/2-1,yoff+17,ss, FONT_MINI)
   end

   if false then --graphSeId2 ~= 0 then
      lcd.setColor(0,200,0)
      if graphValue2 then gv = string.format("%3.1f", graphValue2) else gv = "---" end
      ss = string.format("%s: %s %s  Scale: %d",
			 graphName2 or " ",
			 gv, graphUnit2 or " ",
			 graphScale2)
      
      ww = lcd.getTextWidth(FONT_MINI, ss)
      lcd.drawText(xoff + (xbox-ww)/2-1,yoff+32,ss, FONT_MINI)
   end
   
   -- draw main box for graph, double width lines
   -- absolute max: lcd.drawRectangle(0,1,318,158)

   lcd.setColor(0,0,0)
   --lcd.setClipping(xoff-1, yoff-1, xbox+4, ybox+4)
   --print(xoff, yoff, xbox, ybox)
   lcd.drawRectangle(xoff, yoff, xbox, ybox)
   lcd.drawRectangle(xoff-1, yoff-1, xbox+2, ybox+2)

   lcd.setColor(140,140,140)
   
   if infoMsg ~= "" then
      lcd.drawText((310 - lcd.getTextWidth(FONT_MINI, infoMsg)) / 2, 130, infoMsg, FONT_MINI)
   end
   
   -- draw vertical dashed lines in light gray
   lcd.setColor(200,200,200)
   local iv = 2
   local ivd = 4
   local ivdt
   while iv <= ybox do
      if iv + 2*ivd > ybox then
	 ivdt = ybox - 2
      else
	 ivdt = iv + ivd
      end
      lcd.drawLine(  xbox/4+xoff, iv+yoff, xbox/4+xoff  , ivdt+yoff)
      lcd.drawLine(  xbox/2+xoff, iv+yoff, xbox/2+xoff  , ivdt+yoff)
      lcd.drawLine(3*xbox/4+xoff, iv+yoff, 3*xbox/4+xoff, ivdt+yoff)
      iv = iv + 2*ivd
   end

   -- and horizontal dashed lines
   local ih = 2
   local ihd = 4
   local ihdt
   local ll, ff
   while ih <= xbox do
      if ih + 2*ihd > xbox then
	 ihdt = xbox - 2
      else
	 ihdt = ih + ihd
      end
      lcd.drawLine(ih+xoff, yoff+ybox/2, ihdt+xoff, yoff+ybox/2)
      ih = ih + 2*ihd
   end

   if yLow and yHigh then
      lcd.setColor(0,0,255)
      ff = string.format(graphFmt, yLow)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      lcd.drawText(10, yoff + ybox - 16, ff,  FONT_MINI)
      ff = string.format(graphFmt, yHigh)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      lcd.drawText(10, yoff, ff, FONT_MINI)      
   end
   
   if yLow2 and yHigh2 then
      lcd.setColor(255,0,0)
      ff = string.format(graphFmt2, yLow2)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      lcd.drawText(0 + xbox - ll, yoff + ybox - 16, ff,  FONT_MINI)
      ff = string.format(graphFmt2, yHigh2)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      lcd.drawText(0 + xbox - ll, yoff, ff, FONT_MINI)      
   end

   -- now draw graph
   
   if true then --graphSeId ~= 0 then
      lcd.setColor(0,0,200)

      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
	 ren:reset()
      end

      lastDown = true
      x0, y0 = nil, nil
      
      for ix = 1, #histogram, 1 do
	 if graphStyle[graphStyleIdx] == "Hazel" then
	    yh = (histogram[ix] % graphScale)
	    yLow = (histogram[ix] // graphScale) * graphScale
	    yHigh = yLow + graphScale
	 else
	    yh = histogram[ix]
	 end
	 local iy = yh / graphScale*ybox
	 if iy > ybox then iy=ybox end
	 if iy < 1  then iy=1  end
	 yp = ybox - iy + yoff
	 yp = math.min(ybox + yoff, math.max(yoff, yp))      
	 xp = xoff + xboxWidth*(ix-1)*maxPoints/(maxPoints-1)
	 xp = math.min(xbox + xoff, math.max(xoff, xp))
	 --squeeze so it fits .. otherwise last histogram box would go past xbox
	 if graphStyle[graphStyleIdx] == "Histogram" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, iy, 160)
	 elseif graphStyle[graphStyleIdx] == "Point" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, xboxWidth, 160)
	 else -- Line or Hazel
	    if penDown[ix] then
	       if lastDown == false then
		  lcd.drawCircle(xp, yp, 2) -- pen just went down after being up
		  xdown = xp
		  ydown = yp
		  if xup and yup then
		     dashLine(xup, yup, xdown, ydown)
		  end
	       end
	       ren:addPoint(xp, yp)
	    else
	       if lastDown then
		  if x0 and y0 then
		     lcd.drawCircle(x0, y0, 2)
		  end --pen just came up
		  ren:renderPolyline(2, 0.7)
		  ren:reset()
		  xup = x0
		  yup = y0
	       end
	    end
	    lastDown = penDown[ix]
	    x0 = xp
	    y0 = yp
	 end
      end
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then 
	 ren:renderPolyline(2, 0.7)
      end
   end
   

   if true then --graphSeId2 ~= 0 then
      lcd.setColor(200,0,0)
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
	 ren:reset()
      end
      
      lastDown = true
      x0, y0 = nil, nil

      for ix = 1, #histogram2, 1 do
	 if graphStyle[graphStyleIdx] == "Hazel" then
	    yh = histogram2[ix] % graphScale2
	    yLow2 = (histogram2[ix] // graphScale2) * graphScale2
	    yHigh2 = yLow2 + graphScale2	    
	 else
	    yh = histogram2[ix]
	 end
	 local iy = yh / graphScale2*ybox
	 if iy > ybox then iy=ybox end
	 if iy < 1  then iy=1  end
	 yp = ybox - iy + yoff
	 yp = math.min(ybox + yoff, math.max(yoff, yp))      
	 xp = xoff + xboxWidth*(ix-1)*maxPoints/(maxPoints-1)
	 xp = math.min(xbox + xoff, math.max(xoff, xp))
	 --squeeze so it fits .. otherwise last histogram box would go past xbox
	 if graphStyle[graphStyleIdx] == "Histogram" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, iy, 160)
	 elseif graphStyle[graphStyleIdx] == "Point" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, xboxWidth, 160)
	 else -- Line or Hazel
	    if penDown2[ix] then
	       if lastDown == false then
		  lcd.drawCircle(xp, yp, 2) -- pen just went down after being up
		  xdown = xp
		  ydown = yp
		  if xup and yup then
		     dashLine(xup, yup, xdown, ydown)
		  end
	       end
	       ren:addPoint(xp, yp)
	    else
	       if lastDown then
		  if x0 and y0 then
		     lcd.drawCircle(x0, y0, 2)
		  end --pen just came up
		  ren:renderPolyline(2, 0.7)
		  ren:reset()
		  xup = x0
		  yup = y0
	       end
	    end
	    lastDown = penDown2[ix]
	    x0 = xp
	    y0 = yp
	 end
      end
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then 
	 ren:renderPolyline(2, 0.7)
      end
   end

   lcd.setColor(0,0,0)
end


----------------------------------------------------------------------
-- presistent and global variables for loop()

local function loop()


   local sgTC
   local tim
   local modSec, remSec
   local p1, p2
   
   sgTC = system.getTimeCounter()
   tim = sgTC / 1000
   runningTime = tim - startTime
   modSec, remSec = math.modf(runningTime / 2) --2 secs per step
   
   if sgTC - lastPumpRead > 500 then
      pumpOnline = false
   end
   
   if demoMode then
      fRAT = 40 * math.sin(runningTime / 30)
      pPSI = 5 * (1 + math.cos(runningTime / 30)) -- + 0.1 * math.random(-1,1)
      rPWM = 100 * math.cos(runningTime / 30)
      pumpOnline = true
      if fRAT > 0 then
	 pumpState = "Fill"
      else
	 pumpState = "Empty"
      end
      rTIM = runningTime
      rTIMmins = math.floor(rTIM) // 60
      rTIMsecs = rTIM - rTIMmins*60
      Batt = 10.12
   end

   --print(runningTime, modSec, remSec, oldModSec)

   p1 = system.getInputs("P1")

   if p1 > 0.25 then
      if p1High == false then
	 --print("+1")
	 p1High = true
	 graphScaleIdx = graphScaleIdx - 1
	 graphScaleIdx = math.max(math.min(graphScaleIdx, #graphScaleRange), 1)
	 graphScale = graphScaleRange[graphScaleIdx]
	 graphFmt = graphScaleFormat[graphScaleIdx]
      end
   else
      p1High = false
   end
   

   if p1 < -0.25 then
      if p1Low == false then
	 --print("-1")
	 p1Low = true
	 graphScaleIdx = graphScaleIdx + 1
	 graphScaleIdx = math.max(math.min(graphScaleIdx, #graphScaleRange), 1)
	 graphScale = graphScaleRange[graphScaleIdx]
	 graphFmt = graphScaleFormat[graphScaleIdx]
      end
   else
      p1Low = false
   end

   p2 = system.getInputs("P2")

   if p2 > 0.25 then
      if p2High == false then
	 --print("+1")
	 p2High = true
	 graphScale2Idx = graphScale2Idx - 1
	 graphScale2Idx = math.max(math.min(graphScale2Idx, #graphScale2Range), 1)
	 graphScale2 = graphScale2Range[graphScale2Idx]
	 graphFmt2 = graphScale2Format[graphScale2Idx]
      end
   else
      p2High = false
   end

   if p2 < -0.25 then
      if p2Low == false then
	 --print("-1")
	 p2Low = true
	 graphScale2Idx = graphScale2Idx + 1
	 graphScale2Idx = math.max(math.min(graphScale2Idx, #graphScale2Range), 1)
	 graphScale2 = graphScale2Range[graphScale2Idx]
	 graphFmt2 = graphScale2Format[graphScale2Idx]
      end
   else
      p2Low = false
   end
   
   if sgTC > nextsgTC  and pumpState ~= "Off" then
      nextsgTC = nextsgTC + deltasg
      oldModSec = modSec

      --print("#", #histogram)
      
      if #histogram + 1 > maxPoints then
	 table.remove(histogram, 1)
	 table.remove(penDown, 1)
      end
      
      table.insert(histogram, #histogram+1, fRAT or 0)
      graphValue = fRAT
      
      if graphValue then
	 table.insert(penDown, #penDown+1, true)
      else
	 table.insert(penDown, #penDown+1, false)
      end
      
      if #histogram2 + 1 > maxPoints then
	 table.remove(histogram2, 1)
	 table.remove(penDown2, 1)
      end

      table.insert(histogram2, #histogram2+1, pPSI or 0)
      graphValue2 = pPSI
      if graphValue2 then
	 table.insert(penDown2, #penDown2+1, true)
      else
	 table.insert(penDown2, #penDown2+1, false)
      end
   end

   
end

local function execCmd(k,v)
    
   if k == "rTIM" then
      rTIM = tonumber(v)
      rTIMmins = math.floor(rTIM) // 60
      rTIMsecs = rTIM - rTIMmins*60
   elseif k == "pPSI" then
      pPSI = tonumber(v) 
   elseif k == "rPWM" then
      rPWM = tonumber(v)
   elseif k == "fCNT" then
      fCNT = tonumber(v)
   elseif k == "fRAT" then
      fRAT = tonumber(v)
   elseif k == "fDEL" then
   elseif k == "fDET" then
   elseif k == "Batt" then
      Batt = 7.504 * tonumber(v)
      if Batt < lowBattLimit and not lowBattAnn then
	 system.messageBox("Auto pump power off. Low battery")
	 print("Low Batt power off", Batt, lowBattLimit)
	 countedWrite("(PwrOff)")
	 lowBattAnn = true
      end
   elseif k == "pSTP" then
      print("pSTP signal .. do something about it")
   elseif k == "Curr" then
      Curr = tonumber(v)
   elseif k == "Init" then
      print("Got init from pump")
   elseif k == "pPWM" then
      --print("Got pPWM from pump", tonumber(v))
   elseif k == "PowerDown" then
      system.messageBox("Pump timeout - auto power down")
      print("PowerDown signal")
   elseif k == "OTA" then
   elseif k == "fCLK" then
      if not fCLK then
	 fCLK = tonumber(v)
	 --print("xxx", fCLK, system.getTimeCounter())
	 deltaCLK = fCLK - system.getTimeCounter()
	 deltaAVG = 0
      else
	 fCLK = tonumber(v)
      end
      
      deltaAVG = deltaAVG + ((fCLK - system.getTimeCounter() - deltaCLK) - deltaAVG)/10
      --print("delta Clock: ", fCLK - system.getTimeCounter() - deltaCLK, deltaAVG)
   else
      print("bad command:", k,v)
   end

end

local dataStream=""

local function onRead(data)
   --print("onRead:", data)
   -- called back here with commands coming in from app
   -- commands of the form "(Command:Val)\n"
   -- pickup one per callback cycle and execute it
   local k,v
   local oI, cI
   local ss

   --io.write(sfp, data, "*\n")
   
   if #data > longData then
      --print("longData:", data, #data)
      longData = #data
   end
   
   lastPumpRead = system.getTimeCounter()
   pumpOnline = true
   
   dataStream = dataStream .. data

   local ii = 0
   repeat
      ii = ii + 1
      oI = string.find(dataStream, "%(") 
      cI = string.find(dataStream, "%)")
      
      if not oI or not cI then return end
      
      ss = string.sub(dataStream, oI, cI)
      
      --print(string.format("ss:%s:", ss))
      
      dataStream = string.sub(dataStream, cI+1)
      if not dataStream then
	 dataStream = ""
      end
      if ii > 100 then
	 print("ii>100")
	 break
      end
      if ii > 1 then
	 --print("ii:", ii)
	 --print("data:", data)
      end
      
   until dataStream == ""
   

   --if #dataStream > 10 then print("dataStream > 10", #dataStream) end
   k,v = string.match(ss, "(%a+)%p(.+)%p")

   --k,v = string.match(ss, "(%a+)%s*%p*%s*(%d*%.?%d+)")
   if k and v then execCmd(k,v) end
   
end

local function pumpTele()

end

local function prtPump()
   local temp

   local text, state = form.getButton(1) -- which screen are we on?

   --print(text)
   if text == "Back" then return end
   
   if fCNT then
      form.setTitle(string.format("Flow: %.1f oz      Tank: 2000 oz ", fCNT))
   end

   if fCLK then
      --lcd.drawText(200,60,string.format("deltaT %.1f", fCLK - system.getTimeCounter() - deltaCLK), FONT_MINI)

      lcd.drawText(200,60,string.format("deltaT %.1f ld: %d", deltaAVG, longData), FONT_MINI)
   end
   
   if pumpOnline then
      lcd.setColor(0,255,0)
   else
      lcd.setColor(255,0,0)
   end
   lcd.drawFilledRectangle(0,0,8,8)

   lcd.setColor(0,0,0)

   --lcd.drawText(100,0,"Total Flow (oz) 120.2", FONT_BIG)
   if rPWM then
      lcd.drawText(200,0,string.format("Pump Speed: %d%%", 100 * rPWM / maxPWM), FONT_MINI)
   else
      lcd.drawText(200,0, "Pump Speed: ---", FONT_MINI)
   end

   if rTIM then
      if rTIMmins < 1 then
	 lcd.drawText(200,20,string.format("Run Time: %.1f s", rTIMsecs), FONT_MINI)
      else
	 lcd.drawText(200,20,string.format("Run Time: %d:%02d", rTIMmins, rTIMsecs), FONT_MINI)
      end
      
   else
      lcd.drawText(200,20,"Run Time: ---", FONT_MINI)      
   end
   if Batt then
      lcd.drawText(200,40,string.format("Batt: %.2f V", Batt), FONT_MINI)
   else
      lcd.drawText(200,40,"Batt: ---", FONT_MINI)
   end

   if true then --rPWM then
      if rPWM then
	 temp = 100 * rPWM / maxPWM
	 if pumpState == "Empty" then
	    temp = -temp
	 end
      else
	 temp = nil
      end
      drawGauge("Pump Speed", "black", -100, 0, 100, temp, nil, 10,  0)
   end
   if true then 
      drawGauge("Flow", "blue", -40, 0,  40, fRAT, nil, 70,  0)
   end
   if true then 
      drawGauge("Pressure", "red", 0, 5,  10, pPSI , nil, 130, 0, pressSetpoint)
   end
   
   --lcd.drawRectangle(5, 60, 300, 80)

   --lcd.drawText(10,70,"XXX")   

   graphPrint()
   
end

local function maxPWMChanged(value)
   maxPWM = value
   system.pSave("maxPWM", maxPWM)
end

local function lowBattLimitChanged(value)
   lowBattLimit = value / 10.0
   system.pSave("lowBattLimit", lowBattLimit)
end

local function CalEChanged(value)
   CalE = value
   system.pSave("CalE", value)
end

local function CalFChanged(value)
   CalF = value
   system.pSave("CalF", value)
end

local function tankCapacityChanged(value)
   tankCapacity = value
   system.pSave("tankCapacity", value)
end

local function pressureChanged(value)
   pressSetpoint = value / 10.0
   print("value, pressSetpoint:", value, pressSetpoint)
   system.pSave("pressSetpoint", pressSetpoint)
end

local function initPump(subForm)

   --showPump = false
   --print("initPump - subForm:", subForm)
   
   if subForm == 1 then
      --print("setting buttons")
      infoMsg = "Hold Stop to reset  -  Exit for main menu"
      form.setTitle(appName)
      form.setButton(1, ":backward",1)
      form.setButton(2, ":stop", 2)
      form.setButton(3, ":forward", 1)
      form.setButton(4, "Menu", 1)
      form.setButton(5, "Exit", 1)
   elseif subForm == 2 then
      form.setTitle(appMenu)
      form.setButton(1, "Back",1)
      form.setButton(2, " ", 1)
      form.setButton(3, " ", 1)
      form.setButton(4, " ", 1)
      form.setButton(5, "Exit", 1)

      form.addRow(2)
      form.addLabel({label="Delivery Pressure", width=220})
      form.addIntbox(pressSetpoint*10,0,100,50,1,1,pressureChanged)

      form.addRow(2)
      form.addLabel({label="Fuel Tank Capacity", width=220})
      form.addIntbox(tankCapacity,0,30000,1000,0,1,tankCapacityChanged)

      form.addRow(2)
      form.addLabel({label="Low Battery Cutoff", width=220})
      form.addIntbox(lowBattLimit*10,0,100,85,1,1,lowBattLimitChanged)

      form.addRow(2)
      form.addLabel({label="Fill Cal Factor", width=220})
      form.addIntbox(CalF,500,1000,774,0,1,CalFChanged)

      form.addRow(2)
      form.addLabel({label="Empty Cal Factor", width=220})
      form.addIntbox(CalE,500,1000,774,0,1,CalEChanged)

      form.addRow(2)
      form.addLabel({label="Maximum PWM", width=220})
      form.addIntbox(maxPWM,100,1023,1023,0,1,maxPWMChanged)

      --form.addRow(2)
      --form.addLink((function() form.reinit(3) end),
	-- {label="Foo >>"})
      
      form.addRow(1)
      form.setFocusedRow(1)
      form.addLabel({label=appShort,font=FONT_MINI, alignRight=true})      

   elseif subForm == 3 then
      form.setTitle("Submenu")
      form.addLink((function() form.reinit(2) end), {label="<< Back"})
      form.addRow(1)
      form.setFocusedRow(1)
      form.addLabel({label=appShort,font=FONT_MINI, alignRight=true})
   else
   end
   
end

local function keyPump(key)
	 
   local text, state = form.getButton(1)
   --print("keyPump, text, state", key, text, state)
   
   if text ~= "Back" then -- is this the main pump screen?

      if key == KEY_1 then
	 --print("Key 1 pressed")
	 form.setButton(1, ":backward", 2)	 
	 form.setButton(2, ":stop", 1)
	 countedWrite(string.format("(CalE: %d)\n", CalE))
	 countedWrite("(pMAX: 1024)\n")
	 countedWrite("(Prs: 50)\n")
	 countedWrite("(Spd: 100.0)\n")
	 countedWrite("(Empty)\n")
	 nextsgTC = system.getTimeCounter()
	 pumpState = "Empty"
	 infoMsg = "Empty"
      elseif key == KEY_2 then
	 --print("Key 2 pressed")
	 form.setButton(1, ":backward", 1)	 
	 form.setButton(2, ":stop", 2)
	 form.setButton(3, ":forward", 1)
	 if lastKey == key then
	    --system.messageBox("OFF held .. Clear sent and graph reset ")
	    graphReset()
	    countedWrite("(Clear)\n")
	    print("Clear!")
	 end
	 countedWrite("(Off)\n")
	 pumpState = "Off"
	 infoMsg = "Pump stopped"
      elseif key == KEY_3 then
	 --print("Key 3 pressed")
	 form.setButton(2, ":stop", 1)
	 form.setButton(3, ":forward", 2)
	 countedWrite(string.format("(CalF: %d)\n", CalF))
	 countedWrite("(pMAX: 1024)\n")
	 countedWrite("(Prs: 50)\n")
	 countedWrite("(Spd: 100.0)\n")
	 countedWrite("(Fill)\n")
	 nextsgTC = system.getTimeCounter()
	 infoMsg = "Fill - Press >> again for AutoFill"
	 pumpState = "Fill"
      elseif key == KEY_4 then
	 --print("Key 4 pressed")
	 initPump(2)
      elseif key == KEY_5 then -- default (OK/Exit) is ok for key 5
	 --print("Key 5 pressed")
	 form.close()
      elseif key == KEY_DOWN then
	 pressSetpoint = math.max(0, pressSetpoint - 0.1)
	 system.pSave("pressSetpoint", pressSetpoint)	 
	 --print("Key down")
      elseif key == KEY_UP then
	 pressSetpoint = math.min(10, pressSetpoint + 0.1)
	 system.pSave("pressSetpoint", pressSetpoint)
	 --print("Key up")
      elseif key == KEY_MENU then
	 --print("Menu")
      end
   else
      --print("exit button not detected")
      --print("text:", text, key)
      if key == KEY_1 then
	 --print("key1")
	 form.reinit(1)
      end
      
      --foo
   end
   if key ~= KEY_RELEASED then
      lastKey = key
   else
      lastKey = -1
   end
   
end

local function init()

   local dt = system.getDateTime()
   local dev, emflag, port
   
   fn = string.format("Tele_%02d%02d_%d%02d%02d.dat", dt.mon, dt.day, dt.hour, dt.min, dt.sec)
   --print("fn:", fn)

   dev, emflag = system.getDeviceType()
   emflag = (emflag ~= 1)

   if emflag then port = "COM1" else port = "ttyUSB0" end
   
   --print("About to serial init. port: "..port)
   sidSerial = serial.init(port ,9600) 
   
   if sidSerial then   
      --print("sid succeeded: ", sidSerial)
   else
      print("sid failed", sidSerial)
   end 
      
   local success, descr = serial.onRead(sidSerial,onRead)   
   if success then
      --print("Callback registered")
   else
      print("Error setting callback:", descr)
   end

   system.registerForm(1, 0, "Fuel Station Control", initPump, keyPump, prtPump)
   
   system.registerTelemetry(1,"Pump", 4, pumpTele)

   imgName = appDir.."c-000.png"
   arcFile = lcd.loadImage(imgName)
   --print("arcFile:", arcFile)

   tankCapacity  = system.pLoad("tankCapacity", 1000)
   pressSetpoint = system.pLoad("pressSetpoint", 5)   
   CalE = system.pLoad("CalE", 774)
   CalF = system.pLoad("CalF", 774)
   lowBattLimit = system.pLoad("lowBattLimit", 8.5)
   maxPWM = system.pLoad("maxPWM", 1023)
   maxPWM = math.max(math.min(maxPWM, 1023), 100)
   
   graphReset()

   --print("KEY_MENU, KEY_ESC, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_RELEASED", KEY_MENU, KEY_ESC, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_RELEASED)
   --print(string.format("KEY_RELEASED: %0X", KEY_RELEASED))

   --initForm(1)
   --sfp = io.open("stream.txt", "w")
   --print("sfp:", sfp)

   local txTel = system.getTxTelemetry()

   --print("txTel.txVoltage:", txTel.txVoltage)
   --print("txTel.rx1Percent:", txTel.rx1Percent)
   --print("txTel.rx1Voltage:", txTel.rx1Voltage)       
   
end


return {init=init, loop=loop, author="DFM", version=PumpVersion, name="PumpControl"}
