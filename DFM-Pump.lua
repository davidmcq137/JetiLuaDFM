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
local eCNT
local fCLK
local cBAD

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
local graphStyleIdx = 3

local graphScaleIdx = 4
local graphScaleRange =  {0.05,    0.1,    0.2,    0.5,     1,   2,   5,  10}
local graphScaleFormat = {"%.2f", "%.1f", "%.1f", "%.1f", "%d","%d","%d","%d"}
local graphScale = graphScaleRange[graphScaleIdx]
local graphFmt = graphScaleFormat[graphScaleIdx]

local graphScale2Idx = 4
local graphScale2Range =  {0.05,    0.1,    0.2,    0.5,     1,   2,   5,  10}
local graphScale2Format = {"%.2f", "%.1f", "%.1f", "%.1f", "%d","%d","%d","%d"}
local graphScale2 = graphScale2Range[graphScale2Idx]
local graphFmt2 = graphScale2Format[graphScale2Idx]

--local p1High, p1Low
--local p2High, p2Low

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

-- xboxWidth, maxPoints, xbox, ybox must be integers
-- must have xbox = maxPoints * xboxWidth

local xbox = 300 -- main box width
local ybox = 80 -- main box height
local maxPoints = 150
local xboxWidth = 2 -- pixel width of histograms

local timeline = 120
local nextsgTC 
--local deltasg = 200
local deltasg = timeline * 1000 / maxPoints

local histogram = {} -- table of values for "chart recorder" graph
local penDown = {}
local histogram2 = {} -- table of values for "chart recorder" graph
local penDown2 = {}
local x0, y0

local demoMode = false
local thr = 100
local thrLast = 100
local thrNonZero = false

local pumpActive = true
local dev, emflag
local tankCapacity
local tankOverfill = 10
local Boxcar={}
local boxAvgShort = 0
local boxAvgLong = 0
local boxAvgNShort = 12
local boxAvgNLong = 60
local Boxlen = boxAvgNLong
local boxAvg = 2
local boxAvg2 = 3
local boxRMS = 0

local ssid
local pwd

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
   elseif lcol == "green" then
      lcd.setColor(0,255,0)
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

   --print("cw:", str)
   
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

   --count = count + 1

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
	 if graphStyle[graphStyleIdx] == "Hazel" or  graphStyle[graphStyleIdx] == "Point" then
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
				    yp, 3, 3, 160)
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
   

   if pumpState == "Autofill" then
      lcd.setColor(200,0,0)
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
	 ren:reset()
      end
      
      lastDown = true
      x0, y0 = nil, nil

      for ix = 1, #histogram2, 1 do
	 if graphStyle[graphStyleIdx] == "Hazel" or  graphStyle[graphStyleIdx] == "Point" then
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
				    yp, 3, 3, 160)
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

local function execCmd(k,v)
   local tVOL
   
   if k == "rTIM" then
      rTIM = tonumber(v) or 0
      rTIMmins = math.floor(rTIM) // 60
      rTIMsecs = rTIM - rTIMmins*60
   elseif k == "pPSI" then
      pPSI = tonumber(v) 
      if (pumpState ~= "Fill") and (pumpState ~= "Autofill") then return end
      
      if #Boxcar + 1 > Boxlen then
	 table.remove(Boxcar, 1)
      end
      table.insert(Boxcar, #Boxcar+1, pPSI)
      --print("pPSI, #, BL", pPSI, #Boxcar, Boxlen)
      local sum, formax
      if pumpState ~= "Off" then --#Boxcar >= boxAvgNShort then
	 sum = 0
	 formax = math.min(#Boxcar, boxAvgNShort)
	 --print(#Boxcar - (formax-1), #Boxcar)
	 for i = #Boxcar - (formax -1), #Boxcar do
	    sum = sum + Boxcar[i]
	 end
	 boxAvgShort = sum / formax
      else
	 boxAvgShort = pPSI
      end
      if pumpState ~= "Off" then --#Boxcar >= boxAvgNLong then
	 sum = 0
	 formax = math.min(#Boxcar, boxAvgNLong)	 
	 --print(#Boxcar - (formax-1), #Boxcar)
	 for i = #Boxcar - (formax -1), #Boxcar do
	    sum = sum + Boxcar[i]
	 end
	 boxAvgLong = sum / formax
	 sum = 0
	 formax = math.min(#Boxcar, boxAvgNLong)
	 for i = #Boxcar - (formax -1), #Boxcar do
	    sum = sum + (Boxcar[i] - boxAvgLong) * (Boxcar[i] - boxAvgLong)
	 end
	 boxRMS = math.sqrt(sum) / math.sqrt(formax)
      else
	 boxAvgLong = pPSI
	 boxRMS = 0
      end
      --print(boxAvgLong, boxAvgShort, math.abs(boxAvgLong-boxAvgShort), boxRMS)
   elseif k == "rPWM" then
      rPWM = tonumber(v)
   elseif k == "fCNT" then
      fCNT = tonumber(v)
      tVOL = ( (fCNT or 0) / (CalF / 10) ) - ( (eCNT or 0) / (CalE / 10))      
      if ( (pumpState == "Fill") or (pumpState == "Autofill") )
	 and (tVOL > (tankCapacity + tankOverfill)) then
	 countedWrite("(Off)\n")
	 countedWrite("(Off)\n") -- experiementing with race condition on pump controller (?)	 
	 pumpState = "Off"
	 infoMsg = "Pump stopped - Overfill"
	 --local appDir = "Apps/"..appShort.."/"
	 system.playFile("/"..appDir.."pump_off_at.wav", AUDIO_QUEUE)
	 system.playNumber(tVOL, 0, "floz")
      end
   elseif k == "eCNT" then
      eCNT = tonumber(v)
   elseif k == "fRAT" then
      fRAT = tonumber(v)
   elseif k == "fDEL" then
   elseif k == "fDET" then
   elseif k == "Batt" then
      if not tonumber(v) then print("bad Batt?") end
      Batt = 7.504 * (tonumber(v) or 0)
      if Batt < lowBattLimit and not lowBattAnn then
	 system.messageBox("Auto pump power off. Low battery")
	 print("Low Batt power off", Batt, lowBattLimit)
	 system.playFile("/"..appDir.."pump_off_at.wav", AUDIO_QUEUE)
	 system.playNumber(Batt, 2, "V")
	 countedWrite("(PwrOff)\n")
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
      if tonumber(v) == 1 then
	 system.messageBox("Pump received update cmd",2)
      elseif tonumber(v) == -1 then
	 system.messageBox("No WiFi connection for update",2)
      elseif tonumber(v) == 2 then
	 system.messageBox("WiFi connected for update", 2)
      elseif tonumber(v) == -30 then
	 system.messageBox("No Cloud connection for update",2)
      elseif tonumber(v) == 30 then
	 system.messageBox("Cloud connected. Ready to update",2)
      else
	 print("DFM-Pump: unknown OTA response", v)
      end
      
   elseif k == "fCLK" then
      if not fCLK then
	 fCLK = tonumber(v)
	 deltaCLK = fCLK - system.getTimeCounter()
	 deltaAVG = 0
      else
	 fCLK = tonumber(v)
      end
      
      deltaAVG = deltaAVG + ((fCLK - system.getTimeCounter() - deltaCLK) - deltaAVG)/10
   elseif k == "cBAD" then
      cBAD = v
      print("cBAD", cBAD)
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

----------------------------------------------------------------------
-- presistent and global variables for loop()

local lastLoop=0

local function loop()


   local sgTC
   local tim
   local modSec, remSec
   local p1, p2
   local thrpct
   
   if not pumpActive then return end

   local txTel = system.getTxTelemetry() -- if we see an RX kill the pump
   if not emflag and txTel.rx1Percent > 0 then
      pumpActive = false
      system.setProperty("CpuLimit", 1)      
      system.messageBox("Pump App Exiting")
      return
   end

   sgTC = system.getTimeCounter()
   tim = sgTC / 1000
   runningTime = tim - startTime
   modSec, remSec = math.modf(runningTime / 2) --2 secs per step
   --print(runningTime, modSec, remSec, oldModSec)
   
   if sgTC - lastPumpRead > 500 then
      pumpOnline = false
   end

   if demoMode and ( (pumpState == "Fill") or (pumpState == "Autofill") ) then
      fRAT = 42.5 + 0.1 * math.random(-1,1) -- (1 + math.sin(runningTime / 4))
      --if fRAT > 40 then fRAT = 80 end
      --if fRAT <= 40 then fRAT = 0 end
      --pPSI = 2.5 * (1 + math.cos(runningTime / 4)) -- + 0.1 * math.random(-1,1)
      
      pPSI = 5*(1+system.getInputs("P7"))/2 + 0.1 * math.random(-1,1) 
      rPWM = 60 * math.cos(runningTime / 4)
      pumpOnline = true
      if fRAT < 0 then
	 pumpState = "Empty"
      elseif pumpState ~= "Autofill" then
	 pumpState = "Fill"
      end
      rTIM = runningTime
      rTIMmins = math.floor(rTIM) // 60
      rTIMsecs = rTIM - rTIMmins*60
      Batt = 10.12
      fCNT = 0
      eCNT = 0
   end

   if demoMode and sgTC - lastLoop > 200 and ( (pumpState == "Fill") or (pumpState == "Autofill") ) then -- Argon sends pPSI once per 200 msec
      lastLoop = sgTC
      --print("bar", fCNT, pPSI)
      onRead(string.format("(pPSI:%4.2f)", pPSI))
      onRead(string.format("(fCNT:%4.2f)", fCNT or 0))      
   end

   thrpct = 50 * (system.getInputs("P4") + 1)

   if thrpct > 10 then thrNonZero = true end
      
   if not thrNonZero then
      thr = 100
   else
      thr = thrpct
   end
   
   if thr ~= thrLast then
      countedWrite(string.format("(Spd: %.1f)\n", thr))	    
      thrLast = thr
   end

   --[[
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

   --]]
   
   if (sgTC > nextsgTC)  and ( (pumpState == "Fill") or (pumpState == "Autofill") ) then

      nextsgTC = nextsgTC + deltasg
      oldModSec = modSec

      if #histogram + 1 > maxPoints then
	 table.remove(histogram, 1)
	 table.remove(penDown, 1)
      end

      local tt
      if boxAvg == 1 then
	 tt = pPSI
      elseif boxAvg == 2 then
	 tt = boxAvgShort
      elseif boxAvg == 3 then
	 tt = boxAvgLong
      end
      
      table.insert(histogram, #histogram+1, math.abs(tt) or 0)
      graphValue = math.abs(tt)
      
      if graphValue then
	 table.insert(penDown, #penDown+1, true)
      else
	 table.insert(penDown, #penDown+1, false)
      end
      
      if boxAvg2 == 1 then
	 tt = pPSI
      elseif boxAvg2 == 2 then
	 tt = boxAvgShort
      elseif boxAvg2 == 3 then
	 tt = boxAvgLong
      end

      if #histogram2 + 1 > maxPoints then
	 table.remove(histogram2, 1)
	 table.remove(penDown2, 1)
      end

      table.insert(histogram2, #histogram2+1, math.abs(tt) or 0)
      graphValue2 = math.abs(tt)
      if graphValue2 then
	 table.insert(penDown2, #penDown2+1, true)
      else
	 table.insert(penDown2, #penDown2+1, false)
      end
   end
end

local function pumpTele()
end

local function prtPump()
   local temp
   local tVOL
   
   local text, state = form.getButton(1) -- which screen are we on?

   --print(text)
   if text == "Back" then return end
   
   tVOL = ( (fCNT or 0) / (CalF / 10) ) - ( (eCNT or 0) / (CalE / 10))
   --tVOL = fCNT

   --print("tVOL, fCNT, eCNT, pPSI", tVOL, fCNT, eCNT, pPSI)
   
   if fCNT then
      form.setTitle(string.format("Pumped : %.1f oz    Tank: %d oz ", tVOL, tankCapacity))
   end

   if fCLK then
      --lcd.drawText(200,60,string.format("deltaT %.1f", fCLK - system.getTimeCounter() - deltaCLK), FONT_MINI)

      --lcd.drawText(200,60,string.format("deltaT %.1f ld: %d", deltaAVG, longData), FONT_MINI)
   end
   
   if pumpOnline then
      lcd.setColor(0,255,0)
   else
      lcd.setColor(255,0,0)
   end
   lcd.drawFilledRectangle(0,0,8,8)

   lcd.setColor(0,0,0)

   --lcd.drawText(100,0,"Total Flow (oz) 120.2", FONT_BIG)
   --if rPWM then
   --   lcd.drawText(200,0,string.format("Pump Speed: %d%%", 100 * rPWM / maxPWM), FONT_BOLD)
   --else
   --   lcd.drawText(200,0, "Pump Speed: ---", FONT_BOLD)
   --end

   if rTIM then
      if rTIMmins < 1 then
	 lcd.drawText(200,-5,string.format("Time: %.1f s", rTIMsecs), FONT_BIG)
      else
	 lcd.drawText(200,-5,string.format("Time: %d:%02d", rTIMmins, rTIMsecs), FONT_BIG)
      end
      
   else
      lcd.drawText(200, -5,"Time: ---", FONT_BIG)      
   end
   lcd.drawText(200,15,string.format("LT,ST: %.2f %.2f", boxAvgLong, boxAvgShort), FONT_MINI)
   lcd.drawText(200,25,string.format("RMS,#: %.2f %d", boxRMS, #Boxcar), FONT_MINI)
   lcd.drawText(200,35,string.format("Delta: %.2f", math.abs(boxAvgShort - boxAvgLong)), FONT_MINI)   
   --lcd.drawText(200,65,string.format("pPSI: %.2f", pPSI or 0), FONT_MINI)
		
   if Batt then
      lcd.drawText(200,44,string.format("Batt: %.2f V", Batt), FONT_MINI)
   else
      lcd.drawText(200,44,"Batt: ---", FONT_MINI)
   end

   lcd.drawText(270,44,string.format("RA %d/%d", boxAvg, boxAvg2), FONT_MINI)
   
   if true then --rPWM then
      if rPWM then
	 temp = 100 * rPWM / maxPWM
	 if pumpState == "Empty" then
	    temp = -temp
	 elseif pumpState == "Off" then
	    temp = 0
	 end
      else
	 temp = nil
      end
      drawGauge("Speed", "black", -100, 0, 100, temp, nil, 10,  0, thr)
   end
   if true then
      if (pumpState == "Fill") or (pumpState == "Autofill") then
	 temp = (fRAT or 0) 
      else
	 temp = (fRAT or 0) 
      end
      drawGauge("Flow", "blue", -80, 0,  80, temp, nil, 70,  0)
   end

   if true then 
      drawGauge(string.format("P ["..string.format("%.1f", pressSetpoint)).."]",
			      "blue", 0, 5,  10, pPSI , nil, 130, 0, pressSetpoint)
   end
   
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

local function ssidChanged(value)
   ssid = value
   system.pSave("ssid", ssid)
end

local function pwdChanged(value)
   pwd = value
   system.pSave("pwd", pwd)
   form.reinit(2)
end

local function updateOTA(value)
   print("updateOTA", value)
   countedWrite("ssid:"..ssid.."\n")
   print("sent ssid: "..ssid)
   countedWrite("pwd:"..pwd.."\n")
   print("sent pwd: "..pwd)
   countedWrite("update:0\n")
   print("sent update:0")
end

local function initPump(subForm)

   --showPump = false
   --print("initPump - subForm:", subForm)
   
   if subForm == 1 then
      --print("setting buttons")
      infoMsg = "Press 3D button to reset  -  Exit for main menu"
      form.setTitle(appName)
      form.setButton(1, ":backward",1)
      form.setButton(2, ":stop", 2)
      form.setButton(3, ":forward", 1)
      form.setButton(4, "Menu", 1)
      form.setButton(5, "Exit", 1)
   elseif subForm == 2 then
      form.setTitle(appMenu)
      form.setButton(1, "Back",1)
      form.setButton(2, "RstPW", 1)
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
      form.addIntbox(CalF,1,2000,900,0,1,CalFChanged)

      form.addRow(2)
      form.addLabel({label="Empty Cal Factor", width=220})
      form.addIntbox(CalE,1,2000,900,0,1,CalEChanged)

      form.addRow(2)
      form.addLabel({label="Maximum PWM", width=220})
      form.addIntbox(maxPWM,100,1023,1023,0,1,maxPWMChanged)

      --form.addRow(2)
      --form.addLink((function() form.reinit(3) end),
	-- {label="Foo >>"})
      form.addRow(2)
      form.addLabel({label="WiFi SSID", width=220})
      form.addTextbox(ssid, 63, ssidChanged)

      form.addRow(2)
      form.addLabel({label="WiFi PW", width=220})
      local pwv = (pwd == "")
      print("pwv:", pwv)
      form.addTextbox(pwv and pwd or "***", 63, pwdChanged, {visible=true})
      
      form.addRow(2)
      form.addLabel({label="OTA Update", width=220})
      form.addLink((function() updateOTA() end), {label="Go >>"})
      
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
	 
   local KEY_RTR = 2048
   local KEY_RTU = 8192
   local KEY_RTD = 16384
   local KEY_LTR = 32768
   local KEY_LTL = 65536
   local KEY_LTU = 131072
   local KEY_LTD = 262144
   
   local text, state = form.getButton(1)

   --print("key, text, state", key, text, state)
   --print(KEY_1, KEY_2, KEY_MENU, KEY_ESC, KEY_ENTER, KEY_UP)
   
   if text ~= "Back" then -- is this the main pump screen?

      if key == KEY_1 then
	 --print("Key 1 pressed")
	 form.setButton(1, ":backward", 2)	 
	 form.setButton(2, ":stop", 1)
	 countedWrite(string.format("(CalE: %d)\n", CalE))
	 countedWrite(string.format("(CalF: %d)\n", CalF))	 
	 countedWrite(string.format("(pMAX: %d)\n", maxPWM)) 
	 countedWrite(string.format("(Prs: %d)\n", math.floor(pressSetpoint * 10 + 0.5)))
	 if thr > 10 then
	    countedWrite(string.format("(Spd: %.1f)\n", thr))	    
	 else
	    countedWrite("(Spd: 100.0)\n")
	 end
	 Boxcar = {}
	 histogram = {}
	 histogram2 = {}
	 countedWrite("(Empty)\n")
	 nextsgTC = system.getTimeCounter()
	 pumpState = "Empty"
	 infoMsg = "Empty"
      elseif key == KEY_2 then
	 --print("Key 2 pressed")
	 form.setButton(1, ":backward", 1)	 
	 form.setButton(2, ":stop", 2)
	 form.setButton(3, ":forward", 1)
	 countedWrite("(Off)\n")
	 pumpState = "Off"
	 infoMsg = "Pump stopped"
      elseif key == KEY_3 then
	 --print("Key 3 pressed")
	 if pumpState == "Fill" then
	    system.messageBox("Autofill enabled", 2)
	    system.playFile("/"..appDir.."autofill_enabled.wav", AUDIO_QUEUE)
	    infoMsg = "Autofill enabled"
	    pumpState = "Autofill"
	    Boxcar = {}
	 elseif pumpState ~= "Autofill" then
	    form.setButton(2, ":stop", 1)
	    form.setButton(3, ":forward", 2)
	    countedWrite(string.format("(CalF: %d)\n", CalF))
	    countedWrite(string.format("(CalE: %d)\n", CalE))	    
	    countedWrite("(pMAX: 1023)\n")
	    countedWrite(string.format("(pMAX: %d)\n", maxPWM))
	    countedWrite(string.format("(Prs: %d)\n", math.floor(pressSetpoint * 10 + 0.5)))
	    if thr > 10 then
	       countedWrite(string.format("(Spd: %.1f)\n", thr))	    
	    else
	       countedWrite("(Spd: 100.0)\n")
	    end
	    --Boxcar = {}
	    --histogram = {}
	    --histogram2 = {}
	    countedWrite("(Fill)\n")
	    nextsgTC = system.getTimeCounter()
	    infoMsg = "Fill - Press >> again for AutoFill"
	    pumpState = "Fill"
	 else -- must be already autofill -- ignore
	    system.messageBox("Already in Autofill", 2)
	    --pumpState = "Fill"
	    --system.playFile("/"..appDir.."autofill_disabled.wav", AUDIO_QUEUE)
	    --infoMsg = "Autofill disabled"
	    --system.messageBox("Autofill disabled", 2)
	 end
	 
      elseif key == KEY_4 then
	 --print("Key 4 pressed")
	 initPump(2)
      elseif key == KEY_5 then -- default (OK/Exit) is ok for key 5
	 print("Key 5 pressed")
	 pumpActive = false
	 system.setProperty("CpuLimit", 1)	 
	 form.close()
      elseif key == KEY_DOWN then
	 pressSetpoint = math.max(0, pressSetpoint - 0.1)
	 system.pSave("pressSetpoint", pressSetpoint)	 
	 countedWrite(string.format("(Prs: %d)\n", math.floor(pressSetpoint * 10 + 0.5)))
	 --print("Key down")
      elseif key == KEY_UP then
	 pressSetpoint = math.min(10, pressSetpoint + 0.1)
	 system.pSave("pressSetpoint", pressSetpoint)
	 countedWrite(string.format("(Prs: %d)\n", math.floor(pressSetpoint * 10 + 0.5)))
	 --print("Key up")
      elseif key == KEY_ENTER then
	 system.messageBox("Clear - values reset ", 2)
	 graphReset()
	 if fCNT then fCNT = 0 end
	 fRAT = 0
	 eCNT = 0
	 rTIMmins = 0
	 rTIMsecs = 0	 
	 Boxcar={}
	 countedWrite("(Clear)\n")
      elseif key == KEY_RTU then -- right trim up
	 --print("RTU")
	 graphScale2Idx = graphScale2Idx - 1
	 graphScale2Idx = math.max(math.min(graphScale2Idx, #graphScale2Range), 1)
	 graphScale2 = graphScale2Range[graphScale2Idx]
	 graphFmt2 = graphScale2Format[graphScale2Idx]
      elseif key == KEY_RTD then -- right trim down
	 --print("RTD")
	 graphScale2Idx = graphScale2Idx + 1
	 graphScale2Idx = math.max(math.min(graphScale2Idx, #graphScale2Range), 1)
	 graphScale2 = graphScale2Range[graphScale2Idx]
	 graphFmt2 = graphScale2Format[graphScale2Idx]
      elseif key == KEY_LTU then -- left trim up
	 --print("LTU")
	 graphScaleIdx = graphScaleIdx - 1
	 graphScaleIdx = math.max(math.min(graphScaleIdx, #graphScaleRange), 1)
	 graphScale = graphScaleRange[graphScaleIdx]
	 graphFmt = graphScaleFormat[graphScaleIdx]
      elseif key == KEY_LTD then -- left trim down
	 --print("LTD")
	 graphScaleIdx = graphScaleIdx + 1
	 graphScaleIdx = math.max(math.min(graphScaleIdx, #graphScaleRange), 1)
	 graphScale = graphScaleRange[graphScaleIdx]
	 graphFmt = graphScaleFormat[graphScaleIdx]
      elseif key == KEY_LTR then -- hack for now select avg rates
	 boxAvg = boxAvg + 1
	 if boxAvg > 3 then boxAvg = 1 end
      elseif key == KEY_RTR then
	 boxAvg2 = boxAvg2 + 1
	 if boxAvg2 > 3 then boxAvg2 = 1 end
      end
   else
      --print("exit button not detected")
      --print("text:", text, key)
      if key == KEY_1 then
	 --print("key1")
	 form.reinit(1)
      elseif key == KEY_2 then
	 pwd = ""
	 form.reinit(2)
      end
      
      --foo
   end
   if key ~= KEY_RELEASED then
      lastKey = key
   --else
   --  lastKey = -1
   end
   
end

local function init()

   local dt
   local port
   local portList
   local portStr
   
   system.setProperty("CpuLimit", 0)
   dt = system.getDateTime()   
   fn = string.format("Tele_%02d%02d_%d%02d%02d.dat", dt.mon, dt.day, dt.hour, dt.min, dt.sec)
   --print("fn:", fn)

   dev, emflag = system.getDeviceType()
   emflag = (emflag == 1)

   if emflag then demoMode = true else demoMode = false end
   
   if emflag then
      portList = serial.getPorts()
      if #portList > 0 then
	 portStr = portList[1]
	 for i=2, #portList, 1 do
	    portStr = portStr .. ", " .. portList[i]
	 end
	 print("DFM-Pump: Ports available - " .. portStr)
	 port = portList[1] -- edit if required
      else
	 print("DFM-Pump: No ports available")
      end
   else
      port = "COM1"
   end

   if port then
      sidSerial, descr = serial.init(port ,9600)
      if sidSerial then   
	 print("DFM-Pump: Initialized " .. port)
	 local success, descr = serial.onRead(sidSerial,onRead)   
	 if success then
	    --print("Callback registered")
	 else
	    print("DFM-Pump: Error setting callback:", descr)
	 end
      else
	 print("DFM-Pump: Serial init failed <"..descr..">")
      end
   end

   system.registerForm(1, 0, "Fuel Station Control", initPump, keyPump, prtPump)
   
   system.registerTelemetry(1,"Pump", 4, pumpTele)

   imgName = appDir.."c-000.png"
   arcFile = lcd.loadImage(imgName)
   --print("arcFile:", arcFile)

   tankCapacity  = system.pLoad("tankCapacity", 1000)
   pressSetpoint = system.pLoad("pressSetpoint", 5)   
   CalE = system.pLoad("CalE", 900)
   CalF = system.pLoad("CalF", 900)
   lowBattLimit = system.pLoad("lowBattLimit", 8.5)
   maxPWM = system.pLoad("maxPWM", 1023)
   maxPWM = math.max(math.min(maxPWM, 1023), 100)
   ssid = system.pLoad("ssid", "")
   pwd = system.pLoad("pwd", "")
   
   graphReset()

end


return {init=init, loop=loop, author="DFM", version=PumpVersion, name="PumpControl"}
