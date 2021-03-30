--[[

   -----------------------------------------------------------------------------------------
   DFM-Pump.lua 

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-Pump.lua released under MIT license by DFM 2021
   -----------------------------------------------------------------------------------------

--]]

-- Persistent and global variables for entire progrem

local PumpVersion = "0.0"
local appName = "Fuel Station Display"
local appMenu = "Fuel Station Settings"
local appShort = "DFM-Pump"
local appDir = "Apps/"..appShort.."/"
local modelFile
local ren = lcd.renderer()

local sidSerial
local bps
local cnt

local longData = 0

local strCount=0
local lastStrCount = 0
local lastTime = system.getTime()
local lastKey = -1
local infoMsg = ""

local rTIM, pPSI, rPWM, fCNT, fRAT, Batt, pSTP, fDEL, fDET, Curr, pPWM, eCNT, fCLK, cBAD

local deltaCLK=0

local rTIMmins=0
local rTIMsecs=0
local pumpState = "Off"
local pumpOnline = false
local lastPumpRead = 0
local lowBattAnn = false
local showPump = true

local graphStyle = {"Line","Hazel","Point","Histogram"}
local graphStyleIdx = 3

-- note: some code below assumes metric and imperial tables (range and fmt) have same length
local graphScaleRange =  { {  0.5, 1,    2,   5,  10,  20,  50},
   {0.02, 0.05, 0.1, 0.2, 0.5, 1, 2} }
local graphScaleFormat = { {"%.1f", "%.0f", "%.0f","%.0f","%.0f","%.0f","%.0f"},
   {"%.2f", "%.2f", "%.1f", "%.1f", "%.1f", "%.1f", "%.1f"} }
local graphScale2Range =  graphScaleRange
local graphScale2Format = graphScaleFormat
local graphScaleIdx = #graphScaleRange[1]
local graphScale2Idx = #graphScale2Range[1]
local graphScale
local graphFmt
local graphScale2
local graphFmt2

local graphValue = 0
local graphValue2 = 0

local flowUnitRate = {"oz/m", "L/m"}
local flowUnit = {"floz", "L"}
local flowMult = {1,0.02957}
local flowFmt  = {"%.0f", "%.2f"}
local flowFmtF = {"%.1f", "%.2f"}
local flowFmtC = {"%.2f", "%.4f"}
local flowDecPl = {0,2}
local lastFlowAnn = 0

local highY, lowY
local highY2, lowY2

local oldModSec 
local runningTime 
local startTime

-- xboxWidth, maxPoints, xbox, ybox must be integers
-- must have xbox = maxPoints * xboxWidth

local maxPoints = 120
local xboxWidth = 2 -- pixel width of histograms

local timeline = 120
local nextsgTC 
local deltasg = timeline * 1000 / maxPoints

local histogram = {} -- table of values for "chart recorder" graph
local visible = {}
local penDown = {}
local histogram2 = {} -- table of values for "chart recorder" graph
local visible2 = {}
local penDown2 = {}
local x0, y0
local yLow, yLow2, yHigh, yHigh2

local demoMode = false
local thr = 100
local thrLast = 100
local thrNonZero = false

local pumpActive = true
local dev, emflag

local Boxcar={}
local boxAvgShort = 0
local boxAvgLong = 0
local boxAvgNShort = 8
local boxAvgNLong = 6 * boxAvgNShort
local Boxlen = boxAvgNLong
local boxAvg = 2
local boxAvg2 = 3
local boxRMS = 0
--local flowVals={}
--local flowValsMax = 8

local pumpConfig = {}
local pumpConfigGbl = {}
local unsavedConfig

local subForm
local subSub = {1,2,3,4}
local isubSub = 1

local dataStreamLen = 0
local dataStreamMax = 0

local deltaStable
local armStable = 6
local ratioHigh
local fillStop = 0

local nextAnn = 0
local readNest = 0
--local histFile

local arcFile={}

local needle_poly={}

needle_poly.S = {
   {-2,13},
   {-1,25},
   {1,25},
   {2,13}
}

needle_poly.C = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}

needle_poly.L = {
   {-4,36},
   {-2,65},
   {2,65},
   {4,36}
}

needle_poly.xlarge = {
   {-4,36},
   {-2,70},
   {2,70},
   {4,36}
}

local marker_poly_small = {
   {-3,26},
   { 3,26},
   { 1,16},
   {-1,16}
}


local function drawTextCenter(font, txt, ox, oy)
   --if not font or not txt then print("f,t", font, txt) end
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
   if clr then
      lcd.setColor(clr.r,clr.g,clr.b)
   end
   ren:renderPolygon()
   lcd.setColor(0, 0, 0)
end


local function vertHistogram(x0, y0, val, scale, hgt, wid, vald)

   local a
   
   lcd.setColor(0,0,0)
   
   lcd.drawRectangle(x0 - wid/2, y0 - hgt, wid, 2*hgt - 1)
   --lcd.drawLine(x0 - wid/2, y0, x0 + wid/2 - 1, y0)
   
   a =  math.max(0, math.min(val / scale, 1))

   lcd.setColor(255,0,0)
   lcd.drawFilledRectangle(x0 - wid/2, y0 - hgt + 2 * hgt * (1-a), wid, 2*hgt*a-1)
   lcd.drawText(x0 + wid - 2, y0 - 6, string.format("%.1f", math.max(val,0)), FONT_MINI)
   
   lcd.setColor(0,0,0)

   --if vald then
      --lcd.drawText(x0+wid, y0 -lcd.getTextHeight(FONT_BOLD)/2, string.format("%4.1f m", vald), FONT_BOLD)
   --end
   
   --lcd.drawText(x0 + wid - 5, y0 - hgt, string.format("+%dm", scale), FONT_MINI)
   --lcd.drawText(x0 + wid - 5, y0 + hgt - lcd.getTextHeight(FONT_MINI), string.format("-%dm", scale), FONT_MINI)   
   
end


local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str)

   local d
   
   lcd.setColor(0, 0, 255)
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)

   
   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h/2, d, h)
   lcd.setColor(0,0,0)

   if str then
      lcd.drawText(oxc - lcd.getTextWidth(FONT_MINI, str)//2, oyc+7, str, FONT_MINI)
   end
   
end

local function drawSpd()

   local ox, oy = 155, 100
   local spd = 0.1 * math.floor( ((rPWM or 0) / pumpConfig.maxPWM)*1000 + 0.5)

   if pumpState == "Empty" then
      spd = -spd
   elseif pumpState == "Off" then
      spd = 0
   end
   
   local theta = math.rad(135 * spd / 100) - math.pi
   
   if arcFile.S then lcd.drawImage(ox-arcFile.S["width"]//2, oy-arcFile.S["width"]//2, arcFile.S) end
   drawShape(ox, oy, needle_poly.S, theta)
   --lcd.drawFilledRectangle(ox-1, oy-32, 2, 8)
   drawTextCenter(FONT_MINI, string.format("%.1f", math.abs(spd)), ox+0, oy-5) 
   lcd.drawText(ox - lcd.getTextWidth(FONT_MINI, "Pump") // 2, oy + 14, "Pump", FONT_MINI)
   
end

local function drawCenterBox()

    local W = 44
    local H = 70
    local ox, oy = 133, 0
    local text
    local temp
    
    lcd.drawRectangle(ox, oy, W, H)

    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Time")) / 2, oy,    "Time", FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Prs Set")) / 2, oy+23, "Prs Set", FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Batt")) / 2, oy+46, "Batt", FONT_MINI)

    lcd.drawLine(ox, oy + 23, ox + W - 1, oy + 23)
    lcd.drawLine(ox, oy + 46, ox + W - 1, oy + 46)
    
    if rTIMmins < 1 then
       text = string.format("%.1f", rTIMsecs)
    else
       text = string.format("%d:%02d", rTIMmins, rTIMsecs)
    end

    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 7, text, FONT_BOLD)

    text = string.format("%.2f", pumpConfig.pressSetpoint)    
    
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 30, text, FONT_BOLD)

    lcd.setColor(0,0,0)
    if Batt then
       text = string.format("%.2f", Batt)
    else
       text = "---"
    end
    
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 53, text, FONT_BOLD)

end


local function drawGauge(gsize, label, lcol, min, mid, max, tmp, unit, fmt, ox, oy, marker)
   
   -- gsize = "S", "C" or "L" for small, compact, large
   
   local color={}
   local theta
   local temp

   local dx={}
   local dy={}

   local font={}
   font.C = FONT_MINI
   font.L = FONT_BOLD
   local numfont={}
   numfont.C = FONT_MINI
   numfont.L = FONT_MAXI
   
   
   temp = tmp or min
   
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

   dx.C=25
   dy.C=44
   dx.L=25+40
   dy.L=44+60
   --if not font[gsize] then print(gsize, font[gsize], label) end
   
   drawTextCenter(font[gsize], label, ox + dx[gsize], oy + dy[gsize]) 
   
   local tt
   if tmp then
      tt = math.abs(temp)
      dx.C=25
      dy.C=18
      dx.L=25+40
      dy.L=18+25
      drawTextCenter(numfont[gsize], string.format(fmt, tt), ox+dx[gsize], oy+dy[gsize]) 
   end
   lcd.setColor(120,120,120)
   
   if unit and gsize == "L" then
      dx.C = 25
      dy.C = 52
      dx.L = 25+40
      dy.L = 52+25
      drawTextCenter(FONT_NORMAL, unit, ox + dx[gsize], oy + dy[gsize])
   end
   
   --lcd.setColor(0,0,0)
   
   
   if arcFile[gsize] ~= nil then
      --lcd.drawImage(ox, oy, arcFile.S)      
      lcd.drawImage(ox, oy, arcFile[gsize])
   end
   
   if marker then
      if lcol == "red" then
	 color.r=255
	 color.g=120
	 color.b=120
      elseif lcol == "blue" then
	 color.r=120
	 color.g=120
	 color.b=255
      elseif lcol == "green" then
	 color.r=120
	 color.g=255
	 color.b=120
      end
      
      theta = math.pi - math.rad(135 - 2 * 135 * (marker - min) / (max - min) )
      dx.C = 25
      dy.C = 26
      dx.L = 25+40
      dy.L = 26+40
      if gsize == "S" then
	 drawShape(ox+dx[gsize], oy+dy[gsize], marker_poly_small, theta, color)
      elseif gsize == "L" then
	 drawShape(ox+dx[gsize], oy+dy[gsize], needle_poly.xlarge, theta, color)
      end
   end
   
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

   temp = math.min(max, math.max(temp, min))
   theta = math.pi - math.rad(135 - 2 * 135 * (temp - min) / (max - min) )
   
   if tmp then -- don't draw needle if value passed in is nil
      dx.C = 25
      dy.C = 26
      dx.L = 25+40
      dy.L = 26+40
      --lcd.drawCircle(ox+dx[gsize], oy+dy[gsize], 10)
      drawShape(ox+dx[gsize], oy+dy[gsize], needle_poly[gsize], theta, color)
   end
   
end

local function graphReset()
   histogram = {}
   penDown = {}
   histogram2 = {}
   penDown2 = {}
   visible = {}
   visible2 = {}
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
      --print("write: " .. str)
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

local function slope(pts)

    local xbar, ybar, sxy, sx2 = 0,0,0,0

    if #pts < 2 then return 0 end
    
    for i = 1, #pts do
       --print(i, pts[i].x, pts[i].y)
       xbar = xbar + pts[i].x
       ybar = ybar + pts[i].y
    end

    xbar = xbar/#pts
    ybar = ybar/#pts

    for i = 1, #pts do
        sxy = sxy + (pts[i].x-xbar)*(pts[i].y-ybar)
        sx2 = sx2 + (pts[i].x - xbar)^2
    end
    
    if sx2 < 1.0E-6 then -- would it be more proper to set slope to inf and let atan do its thing?
       sx2 = 1.0E-6      -- or just let it div0 and set to inf itself?
    end                  -- for now this is only a .00001-ish degree error
    
    
    return sxy/sx2
    
end

local function graphPrint(xbox, ybox, xoff, yoff)

   --local xoff =     5 -- x offset from 0,0
   --local yoff =     62 -- y offset from 0,0
   
   local mm, rr
   local mmm, rrr
   local ww, ss
   local yh
   local gv
   local ren = lcd.renderer()
   local xp, yp, lastDown
   local xup, yup, xdown, ydown
   local fmt
   local bt, btMins, btSecs
   
   --print("graphPrint", #histogram)
   
   -- make sure we are set to black
   lcd.setColor(0,0,0)

   -- draw graph titles - scale, time, sensor info
   mm, rr = math.modf(runningTime/60)
   mmm, rrr = math.modf(timeline/60)

   lcd.setColor(120,120,120)

   -- draw main box for graph, double width lines
   -- absolute max: lcd.drawRectangle(0,1,318,158)

   lcd.drawRectangle(xoff, yoff, xbox, ybox)
   --lcd.drawRectangle(xoff-1, yoff-1, xbox+2, ybox+2)

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
      lcd.drawText(xoff - ll - 2, yoff + ybox - 10, ff,  FONT_MINI)
      --lcd.drawText(10, yoff + ybox - 32, ff,  FONT_MINI)      
      ff = string.format(graphFmt, yHigh)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      lcd.drawText(xoff - ll - 2, yoff-4, ff, FONT_MINI)      
   end
   
   --local limit = boxAvgLong * (1 - (pumpConfig.autoParm / 1000.0))
   local limit = boxAvgLong - pumpConfig.autoParm * boxRMS   
   local limith = limit % graphScale
   local limiti = limith / graphScale*ybox
   local limitp = ybox - limiti + yoff
   if yLow and yHigh then
      if pumpState == "Autofill" and  deltaStable >= armStable then
	 --print(boxAvgShort, limit, limith, limiti, limitp)
	 --lcd.drawLine(xoff, limitp, xoff+xbox, limitp)
      end
   end
   
   rTIMmins = (rTIM or 0) // 60
   rTIMsecs = (rTIM or 0) - rTIMmins*60

   if rTIMmins and (pumpState == "Fill" or  pumpState == "Autofill" or pumpState == "Empty") then
      drawTextCenter(FONT_MINI,string.format("%d:%02d", rTIMmins, rTIMsecs),
		     xoff + math.min((#histogram - 1), maxPoints) * xboxWidth, yoff+ybox)

      bt = math.max((rTIM or 0) - timeline, 0)
      btMins = bt // 60
      btSecs = bt - btMins * 60
      if (rTIM or 0) > 20 then
	 btMins = math.floor(bt) // 60
	 btSecs = bt - btMins*60
	 drawTextCenter(FONT_MINI,string.format("%d:%02d", btMins, btSecs),
			xoff, yoff+ybox)      
      end
      
      
   end
   
   if yLow2 and yHigh2 then
      lcd.setColor(255,0,0)
      ff = string.format(graphFmt2, yLow2)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      --lcd.drawText(0 + xbox - ll, yoff + ybox - 16, ff,  FONT_MINI)
      lcd.drawText(xoff+xbox+9, yoff + ybox - 10, ff,  FONT_MINI)      
      ff = string.format(graphFmt2, yHigh2)
      ll = lcd.getTextWidth(FONT_MINI,ff)
      lcd.drawText(xoff+xbox+9, yoff -4, ff, FONT_MINI)
   end

   --local function vertHistogram(x0, y0, val, scale, hgt, wid, vald)

   if isubSub == 2 then
      vertHistogram(11, 62, pPSI or 0, 10, 48, 10, 0)     
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
	    if visible[ix] then
	       lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				       yp, 3, 3, 160)
	    end
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

	 if ix == #histogram2 then
	    -- autofill target
	    --[[
	    if pumpState == "Autofill" then
	       lcd.setColor(0,0,0)
	       lcd.drawText(xoff + xbox - 80, yoff +  5,
			    string.format("dA %.4f",math.abs(boxAvgShort-boxAvgLong)),
			    FONT_MINI)
	       lcd.drawText(xoff + xbox - 80, yoff + 15,
			    string.format("pA %.4f",pumpConfig.autoParm * boxRMS),
			    FONT_MINI)	       
	       lcd.drawText(xoff + xbox - 80, yoff + 25,
			    string.format("rm %.4f", boxRMS), FONT_MINI)
	       lcd.drawText(xoff + xbox - 80, yoff + 35,
			    string.format("pW %d/%d", deltaStable, armStable ), FONT_MINI)
	       lcd.drawText(xoff + xbox - 80, yoff + 45, string.format("%d", (rPWM or 0)), FONT_MINI)
	       lcd.setColor(200,0,0)
	    end
	    --]]
	    
	    if pumpState == "Autofill" and  deltaStable >= armStable then
	       --print(boxAvgShort, limit, limith, limiti, limitp)
	       lcd.setColor(0,0,200)
	       --lcd.drawCircle(xp, limitp, 4)
	       lcd.drawRectangle(xp-4, limitp-4, 9, 9)
	       lcd.drawLine(xp-6, limitp, xp+6, limitp)
	       lcd.drawLine(xp, limitp-6, xp, limitp+6)
	       --ff = string.format(graphFmt2, limit)
	       ff = string.format("%.2f", limit)	       
	       ll = lcd.getTextWidth(FONT_MINI,ff)
	       if limitp > 10 and limitp < ybox - 10 then
		  lcd.drawText(xoff+xbox+9, limitp-5, ff,  FONT_MINI)
	       end
	       lcd.setColor(200,0,0)
	    end
	 end

	 if graphStyle[graphStyleIdx] == "Histogram" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, iy, 160)
	 elseif graphStyle[graphStyleIdx] == "Point" then
	    if visible2[ix] then
	       lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				       yp, 3, 3, 160)
	    end
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
   local tVOL, uVOL
   local sum
   local formax
   local pastBox
   
   if k == "rTIM" then
      rTIM = tonumber(v) or 0
      rTIMmins = math.floor(rTIM) // 60
      rTIMsecs = rTIM - rTIMmins*60
   elseif k == "pPSI" then
      pPSI = tonumber(v) 
   elseif k == "rPWM" then
      rPWM = tonumber(v)
   elseif k == "fCNT" then
      fCNT = tonumber(v)
      
      tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
      uVOL = tVOL * flowMult[pumpConfigGbl.flowIdx]
      if (pumpConfig.announceInt > 0) and (pumpState == "Fill" or pumpState == "Autofill") and
      ((uVOL // pumpConfig.announceInt) >= nextAnn) then
	 --print("fCNT: uVOL, uVOL//, nextAnn:", uVOL, uVOL // pumpConfig.announceInt, nextAnn)
	 --system.playFile("/"..appDir.."volume.wav", AUDIO_QUEUE)
	 if system.getTimeCounter() - lastFlowAnn > 10000 then
	    system.playNumber(pumpConfig.announceInt * nextAnn, flowDecPl[pumpConfigGbl.flowIdx],
			      flowUnit[pumpConfigGbl.flowIdx], "Flow")
	    lastFlowAnn = system.getTimeCounter()
	 end
	 nextAnn = nextAnn + 1
      end
   
      if ( (pumpState == "Fill") or (pumpState == "Autofill") )
      and (uVOL > fillStop) then
	 countedWrite("(Off)\n")
	 pumpState = "Off"
	 infoMsg = "Pump stopped - Overfill"
	 system.playFile("/"..appDir.."pump_off_at.wav", AUDIO_QUEUE)
	 system.playNumber(tVOL * flowMult[pumpConfigGbl.flowIdx], flowDecPl[pumpConfigGbl.flowIdx],
			   flowUnit[pumpConfigGbl.flowIdx])
      end

      if (pumpState == "Autofill") then
	 --print("pC.aH", pumpConfig.autoHoldoff, tVOL, deltaStable)
	 
	 if ((math.abs(boxAvgShort - boxAvgLong) / math.abs(boxAvgLong) ) <
	       (pumpConfig.autoParm * boxRMS / boxAvgLong))       and
	 (#Boxcar == boxAvgNLong) and tVOL >= pumpConfig.autoHoldoff then
	    deltaStable = deltaStable + 1
	    if deltaStable == armStable then -- >= might be preferred but only want 1 announcement
	       system.messageBox("Autofill Armed", 5)
	       system.playFile("/"..appDir.."autofill_armed.wav", AUDIO_QUEUE)	       
	       infoMsg = "Autofill Armed"
	    end
	 end
	 
	 if #Boxcar == boxAvgNLong and deltaStable >= armStable then
	    --if (math.abs(boxAvgShort - boxAvgLong) / math.abs(boxAvgLong) ) >
	    --(pumpConfig.autoParm / 1000) then 
	    if ( (boxAvgLong - boxAvgShort) / boxAvgLong ) > (pumpConfig.autoParm * boxRMS / boxAvgLong) then 
	       system.playFile("/"..appDir.."autofill_detected_at.wav", AUDIO_QUEUE)
	       system.playNumber(uVOL, flowDecPl[pumpConfigGbl.flowIdx], flowUnit[pumpConfigGbl.flowIdx])
	       if pumpConfig.tankOverfill > 0 then
		  pumpState = "Fill"
		  fillStop = uVOL + pumpConfig.tankOverfill
		  infoMsg = "Autofill detected - Overfilling"
	       else
		  countedWrite("(Off)\n")
		  pumpState = "Off"
		  infoMsg = "Pump stopped - Autofill"
	       end
	    end
	 end
      end
      
   elseif k == "eCNT" then
      eCNT = tonumber(v)
      tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
      uVOL = tVOL * flowMult[pumpConfigGbl.flowIdx]
      --print("tVOL, uVOL, nextAnn, uV/..:", tVOL, uVOL, nextAnn, uVOL // pumpConfig.announceInt)
      if (pumpConfig.announceInt > 0) and (pumpState == "Empty") and
      ((uVOL // pumpConfig.announceInt) <= nextAnn) then
	 --print("eCNT: uVOL, uVOL//, nextAnn:", uVOL, uVOL // pumpConfig.announceInt, nextAnn)
	 --system.playFile("/"..appDir.."volume.wav", AUDIO_QUEUE)
	 system.playNumber(pumpConfig.announceInt * (nextAnn+1), flowDecPl[pumpConfigGbl.flowIdx],
			   flowUnit[pumpConfigGbl.flowIdx], "Flow")
	 nextAnn = nextAnn - 1
      end
      
   elseif k == "fRAT" then
      fRAT = tonumber(v)
      if not fRAT then fRAT = 0 end
      
      -----------------------------------------------
      if (pumpState ~= "Fill") and (pumpState ~= "Autofill") and (pumpState ~= "Empty") then return end

      if #Boxcar + 1 > Boxlen then
	 table.remove(Boxcar, 1)
      end

      table.insert(Boxcar, #Boxcar+1, fRAT * flowMult[pumpConfigGbl.flowIdx]) -- YYYYYY

      if pumpState ~= "Off" then --#Boxcar >= boxAvgNLong then

	 -- compute long term average up to <pastBox> samples ago
	 -- so the running value of boxAvgLong is "delayed" by <pastBox> samples
	 -- making is miss the initial dip of the short term average for a little while

	 pastBox = math.floor(1.5 * boxAvgNShort)
	 
	 sum = 0
	 if #Boxcar > pastBox then
	    for i = 1, #Boxcar - pastBox do
	       sum = sum + Boxcar[i]
	    end
	    boxAvgLong = sum / (#Boxcar - pastBox)
	 else
	    for i = 1, #Boxcar do
	       sum = sum + Boxcar[i]
	    end
	    boxAvgLong = sum / #Boxcar
	 end
	 sum = 0
	 if #Boxcar > pastBox then
	    for i = 1, #Boxcar - pastBox do
	       sum = sum + (Boxcar[i] - boxAvgLong) * (Boxcar[i] - boxAvgLong)
	    end
	    boxRMS = math.sqrt(sum) / math.sqrt(#Boxcar - pastBox)
	 else
	    for i = 1, #Boxcar do
	       sum = sum + (Boxcar[i] - boxAvgLong) * (Boxcar[i] - boxAvgLong)
	    end
	    boxRMS = math.sqrt(sum) / math.sqrt(#Boxcar)
	 end
	 
	 sum = 0
	 formax = math.min(#Boxcar, boxAvgNShort)
	 --print(#Boxcar - (formax-1), #Boxcar)
	 for i = #Boxcar - (formax -1), #Boxcar do
	    sum = sum + Boxcar[i]
	 end
	 boxAvgShort = sum / formax
      else
	 boxAvgShort = fRAT
	 boxAvgLong  = fRAT
      end
   elseif k == "fDEL" then
   elseif k == "fDET" then
   elseif k == "Batt" then
      if not tonumber(v) then print("bad Batt?") end
      Batt = 7.504 * (tonumber(v) or 0)
      if Batt < pumpConfigGbl.lowBattLimit and not lowBattAnn then
	 system.messageBox("Auto pump power off. Low battery")
	 print("Low Batt power off", Batt, pumpConfigGbl.lowBattLimit)
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
      print("k=OTA, v:", v)
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

   if k == "fCNT" or k == "eCNT" then

      --print("rP,pS,fR, rH", rPWM, pumpState, fRAT, ratioHigh)
      
      if (rPWM and (rPWM ~= 0)) and (pumpState ~= "Off") and (math.abs(fRAT or 0) >= 0) then --running
	 --print("running. rTIM", rTIM)
	 if not rTIM then rTIM = 0 end
	 if math.abs(fRAT or 0) == 0 then
	    if (math.abs(rPWM) ~= 0) and (rTIM > 10) then
	       ratioHigh = ratioHigh + 1
	       --print("1: ratioHigh:", ratioHigh)
	    end
	 elseif ( (math.abs(rPWM) / math.abs(fRAT or 0) ) > 120) and (rTIM > 10) then	 
	    ratioHigh = ratioHigh + 1
	    --print("2: ratioHigh:", ratioHigh)
	 end
	 --if ratioHigh > 5 then print("ratioHigh > 5", ratioHigh) end
	 if ratioHigh == 5 then -- >= safer but don't want mult ann
	    tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
	    countedWrite("(Off)\n")
	    pumpState = "Off"
	    infoMsg = "Pump stopped - Low flow"
	    system.playFile("/"..appDir.."pump_off_at.wav", AUDIO_QUEUE)
	    system.playNumber(tVOL * flowMult[pumpConfigGbl.flowIdx],
			      flowDecPl[pumpConfigGbl.flowIdx], flowUnit[pumpConfigGbl.flowIdx])
	 end
      end
   end
end

local dataStream=""
local iimax = 0

local function onRead(data)

   -- called back here with commands coming in from app
   -- commands of the form "(Command:Val)\n"
   -- pickup one per callback cycle and execute it

   local k,v
   local oI, cI
   local ss
   local ii
   
   readNest = readNest + 1
   
   --print("data: #" .. data.."#")
   
   if #data > longData then
      longData = #data
   end
   
   lastPumpRead = system.getTimeCounter()
   if pumpOnline == false then -- really should move this out to the loop .. this is an isr (sortof)
      system.playFile("/"..appDir.."pump_bluetooth_connected.wav", AUDIO_QUEUE)
   end
   
   pumpOnline = true
   
   dataStream = dataStream .. data

   dataStreamLen = #dataStream
   if dataStreamLen > dataStreamMax then dataStreamMax = dataStreamLen end
   
   ii = 0

   repeat
      ii = ii + 1
      oI = string.find(dataStream, "%(") 
      cI = string.find(dataStream, "%)")
      
      if not oI or not cI then -- keep accumulating data if we got a partial
	 --print("no oI or cI")
	 --print("dataStream: "..dataStream)
	 readNest = readNest - 1
	 return
      end
      
      ss = string.sub(dataStream, oI, cI)
      
      if ss == "" then break end

      k,v = string.match(ss, "(%a+)%p(.+)%p")
      
      if k and v then
	 --print("k,v:", k,v)
	 execCmd(k,v)
      else
	 if ss == nil then ss = "-nil-" end
	 if ss == "" then ss = "-qs-" end
	 print("k or v nil:", k, v, "#"..ss.."#")
      end
      
      dataStream = string.sub(dataStream, cI+1)
      if not dataStream then
	 dataStream = ""
      end
      if ii > iimax then
	 iimax = ii
	 --print("iimax", iimax, dataStream)
      end
      if ii > 100 then
	 print("ii>100, breaking")
	 break
      end
      
   until dataStream == ""

   readNest = readNest - 1

   if readNest > 1 then print("readNest:", readNest) end
   
end

----------------------------------------------------------------------

local function stopSerial()
   pumpActive = false
   gpio.write(8,0) -- power BLE off
   print("BLE powered off")
   serial.onRead(sidSerial, nil) -- just in case deinit does not do this
   serial.deinit(sidSerial)
   system.setProperty("CpuLimit", 1)	 
   form.close()
end



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
      stopSerial()
      system.messageBox("Airplane On - Pump App Exiting")
      system.playFile("/"..appDir.."airplane_powered_on_pump_exiting.wav", AUDIO_QUEUE)
      return
   end

   sgTC = system.getTimeCounter()
   tim = sgTC / 1000
   runningTime = tim - startTime
   modSec, remSec = math.modf(runningTime / 2) --2 secs per step
   --print(runningTime, modSec, remSec, oldModSec)
   
   if sgTC - lastPumpRead > 1000 then
      pumpOnline = false
   end

   if demoMode and pumpState ~= "Off" then
      if ( (pumpState == "Fill") or (pumpState == "Autofill") ) then
	 fRAT = 42.5 + 0.1 * math.random(-1,1) -- (1 + math.sin(runningTime / 4))
      else
	 fRAT = -42.5 + 0.1 * math.random(-1,1) -- (1 + math.sin(runningTime / 4))
      end
      
      if not fCNT then fCNT = 0 end
      if not eCNT then eCNT = 0 end
      
      if pumpState ~= "Empty" then
	 fCNT = fCNT + 1
      else
	 eCNT = eCNT + 1
      end
      
      --if fRAT > 40 then fRAT = 80 end
      --if fRAT <= 40 then fRAT = 0 end
      --pPSI = 2.5 * (1 + math.cos(runningTime / 4)) -- + 0.1 * math.random(-1,1)
      
      rPWM = 60 * math.cos(runningTime / 4)
      pPSI = 5*(1+system.getInputs("P7"))/2 + 0.1 * math.random(-1,1) +  runningTime/1000
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
      --fCNT = 0
      --eCNT = 0
   end

   if (demoMode and sgTC - lastLoop > 200) and (pumpState ~= "Off")  then -- Argon sends pPSI once per 200 msec
      lastLoop = sgTC
      --print("bar", fCNT, pPSI)
      onRead(string.format("(pPSI:%4.2f)", pPSI))
      onRead(string.format("(fRAT:%4.2f)", fRAT))
      if pumpState == "Fill" or pumpState == "Autofill" then
	 onRead(string.format("(fCNT:%4.2f)", fCNT or 0))
      end
      
      if pumpState == "Empty" then
	 onRead(string.format("(eCNT:%4.2f)", eCNT or 0))
      end
   end

   thrpct = 50 * (system.getInputs("P4") + 1)

   if thrpct > 10 then thrNonZero = true end
      
   ------------------- TEST ---------------------
   --if thrpct >= 50 then
      --gpio.write(8,1)
   --else
      --gpio.write(8,0)
   --end
   -------------------END TEST ------------------
   
   
   if not thrNonZero then -- if stick left at 0, leave at 100%
      thr = 100
   else
      thr = thrpct
   end

   -- code on hold .. adjust speed by throttle stick
   
   --if thr ~= thrLast then
   --   countedWrite(string.format("(Spd: %.1f)\n", thr))	    
   --   thrLast = thr
   --end
   
   if (sgTC > nextsgTC)  and ( (pumpState == "Fill") or (pumpState == "Autofill") or (pumpState == "Empty")) then

      nextsgTC = nextsgTC + deltasg
      oldModSec = modSec

      if #histogram + 1 > maxPoints then
	 table.remove(histogram, 1)
	 table.remove(penDown, 1)
	 table.remove(visible, 1)
      end

      local tt
      if boxAvg == 1 then
	 tt = fRAT or 0
      elseif boxAvg == 2 then
	 tt = boxAvgShort
      elseif boxAvg == 3 then
	 tt = boxAvgLong
      end
      
      table.insert(histogram, #histogram+1, math.abs(tt) or 0)
      --io.write(histFile, sgTC, ",", (rTIM or 0), ",", (fRAT or 0), ",", boxAvgShort, ",", (fCNT or 0), ",", (eCNT or 0), "\n")

      graphValue = math.abs(tt)
      --print(fRAT, boxAvg, tt, #histogram)
      if true then
	 table.insert(visible, #visible+1, true)
      else
	 table.insert(visible, #visible+1, false)
      end
      
      if graphValue then
	 table.insert(penDown, #penDown+1, true)
      else
	 table.insert(penDown, #penDown+1, false)
      end
      
      if boxAvg2 == 1 then
	 tt = fRAT or 0
      elseif boxAvg2 == 2 then
	 tt = boxAvgShort
      elseif boxAvg2 == 3 then
	 tt = boxAvgLong
      end

      if #histogram2 + 1 > maxPoints then
	 table.remove(histogram2, 1)
	 table.remove(penDown2, 1)
	 table.remove(visible2, 1)
      end

      table.insert(histogram2, #histogram2+1, math.abs(tt) or 0)
      graphValue2 = math.abs(tt)
      if (deltaStable or 0) > armStable then
	 --print(#histogram2, "v2 = true", deltaStable, armStable)
	 table.insert(visible2, #visible2+1, true)
      else
	 --print(#histogram2, "v2 = false", deltaStable, armStable)
	 table.insert(visible2, #visible2+1, false) 
      end
      
      if graphValue2 then
	 table.insert(penDown2, #penDown2+1, true)
      else
	 table.insert(penDown2, #penDown2+1, false)
      end

      --if #histogram ~= #histogram2 then print("#h not equal") end
      
   end
end

local function pumpTele()
end

local function prtPump()
   local temp
   local tVOL
   local afTgt
   
   if not pumpActive then return end
   
   if subForm ~= 1 then return end

   if isubSub == 1 or isubSub == 3 then
      if pumpOnline then
	 lcd.setColor(0,255,0)
      else
	 lcd.setColor(255,0,0)
      end
      lcd.drawFilledRectangle(0,4,8,8)
      lcd.setColor(0,0,0)
   end

   tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
   --print("tVOL", tVOL, tVOL * flowMult[pumpConfigGbl.flowIdx])
   if fCNT then
      form.setTitle(string.format("Flow: " ..
				     flowFmtF[pumpConfigGbl.flowIdx] .. " %s " ..
				     "    Tank: " .. flowFmt[pumpConfigGbl.flowIdx] .. " %s ",
				  tVOL * flowMult[pumpConfigGbl.flowIdx],
				  flowUnit[pumpConfigGbl.flowIdx],
				  pumpConfig.tankCapacity,
				  flowUnit[pumpConfigGbl.flowIdx]))
   end
      if subSub[isubSub] == 1 then
      --if (pumpState == "Fill") or (pumpState == "Autofill") then
	-- temp = (fRAT or 0) 
      --else
	-- temp = (fRAT or 0) 
      --end
      temp = fRAT or 0
      
      drawRectGaugeAbs(155, 136, 280, 14, 0, pumpConfig.tankCapacity,
		       (tVOL or 0) * flowMult[pumpConfigGbl.flowIdx], "")
      drawCenterBox()
      drawSpd()
      -- if appropriate, display autofill target

      if pumpState == "Autofill" and  deltaStable >= armStable then  
	 afTgt = math.max(boxAvgShort - 10 * pumpConfig.autoParm * boxRMS) -- 10 is arbitrary theatrics
      else
	 afTgt = nil
      end

      --print("p, tgt:", temp, afTgt) 
     
      drawGauge("L", "Flowrate", "blue", -60 * flowMult[pumpConfigGbl.flowIdx], 0,
		60 * flowMult[pumpConfigGbl.flowIdx], temp * flowMult[pumpConfigGbl.flowIdx],
		flowUnitRate[pumpConfigGbl.flowIdx], flowFmtF[pumpConfigGbl.flowIdx], 0,  0, afTgt)

      
      drawGauge("L", "Pressure","red", 0, 5, 10, math.max((pPSI or 0), 0),
		"psi", "%.1f", 180, 0, pumpConfig.pressSetpoint)

      if infoMsg ~= "" then
	 lcd.setColor(140,140,140)	 
	 lcd.drawText((310 - lcd.getTextWidth(FONT_MINI, infoMsg)) / 2, 130, infoMsg, FONT_MINI)
	 lcd.setColor(0,0,0)
      end

   elseif subSub[isubSub] == 2 then
   
      --lcd.drawText(20,30, string.format("LT,ST: %.2f %.2f", boxAvgLong, boxAvgShort))
      --lcd.drawText(20,45, string.format("#Boxcar: %d", #Boxcar))
      --lcd.drawText(20,60, string.format("Delta pct: %.2f",
      --				100 * math.abs(boxAvgShort - boxAvgLong) / math.abs(boxAvgLong)))
      --graphPrint(240,120, 35, 2)
      graphPrint(240,120, 35, 2)            

   elseif subSub[isubSub] == 3 then 
   
      --tVOL = fCNT
      
      --print("tVOL, fCNT, eCNT, pPSI", tVOL, fCNT, eCNT, pPSI)
      
      
      if fCLK then
	 --lcd.drawText(200,60,string.format("deltaT %.1f", fCLK - system.getTimeCounter() - deltaCLK), FONT_MINI)
	 
	 --lcd.drawText(200,60,string.format("deltaT %.1f ld: %d", deltaAVG, longData), FONT_MINI)
      end
      
      
      --lcd.drawText(100,0,"Total Flow (oz) 120.2", FONT_BIG)
      --if rPWM then
      --   lcd.drawText(200,0,string.format("Pump Speed: %d%%", 100 * rPWM / pumpConfig.maxPWM), FONT_BOLD)
      --else
      --   lcd.drawText(200,0, "Pump Speed: ---", FONT_BOLD)
      --end
      
      if rTIM then
	 if rTIMmins < 1 then
	    lcd.drawText(200,10,string.format("Time: %.1f s", rTIMsecs), FONT_BIG)
	 else
	    lcd.drawText(200,10,string.format("Time: %d:%02d", rTIMmins, rTIMsecs), FONT_BIG)
	 end
	 
      else
	 lcd.drawText(200, 10,"Time: ---", FONT_BIG)      
      end
      
      if Batt then
	 lcd.drawText(202,40,string.format("Batt: %.2f V", Batt))
      else
	 lcd.drawText(202,40,"Batt: ---")
      end
      
      
      if true then --rPWM then
	 if rPWM then
	    temp = 100 * rPWM / pumpConfig.maxPWM
	    if pumpState == "Empty" then
	       temp = -temp
	    elseif pumpState == "Off" then
	       temp = 0
	    end
	 else
	    temp = nil
	 end
	 drawGauge("C", "Speed", "black", -100, 0, 100, temp, nil, "%.1f", 10,  0, thr)
      end
      if true then
	 --if (pumpState == "Fill") or (pumpState == "Autofill") then
	   -- temp = (fRAT or 0) 
	 --else
	   -- temp = (fRAT or 0) 
	 --end
	 temp = fRAT or 0


	 drawGauge("C", "Flow", "blue", -80 * flowMult[pumpConfigGbl.flowIdx], 0,
		   80 * flowMult[pumpConfigGbl.flowIdx], temp * flowMult[pumpConfigGbl.flowIdx],
		   nil, flowFmt[pumpConfigGbl.flowIdx], 70,  0)
      end
      
      if true then 
	 drawGauge("C", string.format("P ["..string.format("%.1f", pumpConfig.pressSetpoint)).."]",
		   "blue", 0, 5,  10, math.max((pPSI or 0), 0) , nil, "%.1f", 130, 0, pumpConfig.pressSetpoint)
      end
      
      graphPrint(240, 80, 35, 62)
   elseif subSub[isubSub] == 4 then
      lcd.drawText(0,00, string.format("fCNT: %d eCNT: %d", fCNT or 0, eCNT or 0)) 
      lcd.drawText(0,15, string.format("RA %d/%d", boxAvg, boxAvg2))
      lcd.drawText(0,30, string.format("LT,ST: %.4f %.4f %.4f, %.4f %.4f", boxAvgLong, boxAvgShort,math.abs(boxAvgShort - boxAvgLong) / math.abs(boxAvgLong), pumpConfig.autoParm / 1000, boxRMS))

      lcd.drawText(0,45, string.format("#Boxcar %d", #Boxcar))
      lcd.drawText(0,60, string.format("Delta: %.2f", math.abs(boxAvgShort - boxAvgLong)))
      lcd.drawText(0,75, string.format("pPSI: %.2f Curr: %.2f", pPSI or 0, Curr or 0))
      lcd.drawText(0,90, string.format("dsLen, dsLenmax,longData, iimax: %d %d %d %d",
				       dataStreamLen, dataStreamMax, longData, iimax))
      lcd.drawText(0,105,string.format("t %d, ratio %.2f",
				       (rTIM or 0), math.abs(rPWM or 0) / math.abs(fRAT or 0)))   end
   
end

local function jLoad(config, var, def)
   if not config then return nil end
   if not config[var] then
      config[var] = def
   end
   --print("jLoad returning " .. var .. " = " .. config[var])
   return config[var]
end

local function jSave(config, var, val)
   config[var] = val
   unsavedConfig = true
end
      
local function maxPWMChanged(value)
   jSave(pumpConfig, "maxPWM", value)
end

local function lowBattLimitChanged(value)
   jSave(pumpConfigGbl, "lowBattLimit", value / 10.0)
end

local function CalEChanged(value)
   jSave(pumpConfigGbl, "CalE", value / 100.0)
   form.setTitle("Empty: " ..
		    string.format(flowFmtC[pumpConfigGbl.flowIdx] .. " " ..
				     flowUnit[pumpConfigGbl.flowIdx]..", %.2f g",
				  flowMult[pumpConfigGbl.flowIdx] * (eCNT or 0) / pumpConfigGbl.CalE,
				  23.659 * (eCNT or 0) / pumpConfigGbl.CalE))
end

local function CalFChanged(value)
   jSave(pumpConfigGbl, "CalF", value / 100.0)
   form.setTitle("Fill: " ..
		    string.format(flowFmtC[pumpConfigGbl.flowIdx] .. " " ..
				     flowUnit[pumpConfigGbl.flowIdx]..", %.2f g",
				  flowMult[pumpConfigGbl.flowIdx] * (fCNT or 0) / pumpConfigGbl.CalF,
				  23.659 * (fCNT or 0) / pumpConfigGbl.CalF))
end

local function tankCapacityChanged(value)
   if pumpConfigGbl.flowIdx == 1 then -- Imperial
      jSave(pumpConfig, "tankCapacity", value)
   else
      jSave(pumpConfig, "tankCapacity", value / 100.0)
   end
end

local function pressureChanged(value)
   jSave(pumpConfig, "pressSetpoint", value / 10.0)
end

local function ssidChanged(value)
   jSave(pumpConfigGbl, "ssid", value)
end

local function pwdChanged(value)
   jSave(pumpConfigGbl, "pwd", value)
end

local function autoParmChanged(value)
   jSave(pumpConfig, "autoParm",value / 10.0)
end

local function maxRevSpdChanged(value)
   jSave(pumpConfig, "maxRevSpd", value)
end

local function tankOverfillChanged(value)
   if pumpConfigGbl.flowIdx == 1 then -- Imperial
      jSave(pumpConfig, "tankOverfill", value)
   else
      jSave(pumpConfig, "tankOverfill", value / 100.0)
   end
end

local function flowUnitChanged(value)
   jSave(pumpConfigGbl, "flowIdx", value)
   system.messageBox("Converting tank volumes", 2)
   if value == 2 then -- oz to L
      pumpConfig.tankCapacity = math.floor(pumpConfig.tankCapacity * 29.5735 + 0.5) / 1000.0 
      pumpConfig.tankOverfill = math.floor(pumpConfig.tankOverfill * 29.5735 + 0.5) / 1000.0 
      pumpConfig.autoHoldoff  = math.floor(pumpConfig.autoHoldoff  * 29.5735 + 0.5) / 1000.0 
      pumpConfig.announceInt  = math.floor(pumpConfig.announceInt  * 29.5735 + 0.5) / 1000.0
      countedWrite("(Met)\n")  
   else -- L to oz
      pumpConfig.tankCapacity = math.floor(pumpConfig.tankCapacity * 33.8140 + 0.5)
      pumpConfig.tankOverfill = math.floor(pumpConfig.tankOverfill * 33.8140 + 0.5)
      pumpConfig.autoHoldoff  = math.floor(pumpConfig.autoHoldoff  * 33.8140 + 0.5)
      pumpConfig.announceInt  = math.floor(pumpConfig.announceInt  * 33.8140 + 0.5)
      countedWrite("(Imp)\n")      
   end
   form.reinit(2)
end

local function autoHoldoffChanged(value)
   if pumpConfigGbl.flowIdx == 1 then -- Imperial
      jSave(pumpConfig, "autoHoldoff", value)
   else
      jSave(pumpConfig, "autoHoldoff", value / 100.0)      
   end
   
end

local function announceIntChanged(value)
   if pumpConfigGbl.flowIdx == 1 then -- Imperial
      jSave(pumpConfig, "announceInt", value)
   else
      jSave(pumpConfig, "announceInt", value / 100.0)
   end
   
end

local function updateOTA(value)
   print("updateOTA", value)
   if pumpConfigGbl.ssid == "" or pumpConfigGbl.pwd == "" then
      system.messageBox("Warning: Wifi SSID or Pwd blank",3)
   end
   countedWrite("ssid:"..pumpConfigGbl.ssid.."\n")
   print("sent ssid: "..pumpConfigGbl.ssid)
   countedWrite("pwd:"..pumpConfigGbl.pwd.."\n")
   print("sent pwd: "..pumpConfigGbl.pwd)
   countedWrite("update:0\n")
   print("sent update:0")
end

local function unpairBLE(value)
   print("about to send unpair command")
   countedWrite("unpair:0" .. "\n")
end

local function saveParms()
   local ff

   ff = io.open(modelFile, "w") 
   if not ff then
      system.messageBox("Cannot open local parameter file")
      return
   end
   if not io.write(ff,json.encode(pumpConfig)) then
      system.messageBox("Cannot write local parameter file")
      return
   end
   io.close(ff)

   ff = io.open(appDir .. "PumpGlobal.jsn", "w") 
   if not ff then
      system.messageBox("Cannot open global parameter file")
      return
   end
   if not io.write(ff,json.encode(pumpConfigGbl)) then
      system.messageBox("Cannot write global parameter file")
      return
   end

   io.close(ff)

   countedWrite(string.format("(CalE: %.2f)\n", pumpConfigGbl.CalE))
   countedWrite(string.format("(CalF: %.2f)\n", pumpConfigGbl.CalF))	 
   countedWrite(string.format("(pMAX: %d)\n", pumpConfig.maxPWM)) 
   countedWrite(string.format("(Prs: %.2f)\n", pumpConfig.pressSetpoint))
   countedWrite(string.format("(Spd: %d)\n", pumpConfig.maxRevSpd))
   if pumpConfigGbl.flowIdx == 1 then
      countedWrite("(Imp)\n")
   else
      countedWrite("(Met)\n")	    
   end

   countedWrite("(Sav: 0)\n")
   
   system.messageBox("Pump parameters saved", 2)
   unsavedConfig = false
end

local savedRow = 1

local function initPump(sF)

   subForm = sF

   if subForm == 1 then
      --print("setting buttons")
      if unsavedConfig then
	 system.messageBox("You have unsaved parameters")
      end
      
      if infoMsg == "" then infoMsg = "Press 3D button to reset  -  Exit for main menu" end
      --form.setTitle(appName)
      form.setTitle("Fuel Station: " .. system.getProperty("Model"))
      form.setButton(1, ":backward",1)
      form.setButton(2, ":stop", 2)
      form.setButton(3, ":forward", 1)
      form.setButton(4, ":tools", 1)
      if isubSub == 1 then
	 form.setButton(5, ":graphBig", 1)
      else
	 form.setButton(5, ":left", 1)
      end
   elseif subForm == 2 then

      if unsavedConfig then
	 system.messageBox("You have unsaved parameters")
      end

      form.setTitle(appMenu)
      form.setButton(1, "Back",1)
      form.setButton(3, "Save", 1)
      form.setButton(5, "Exit", 1)

      form.addRow(2)
      form.addLink((function() form.reinit(3) end),
	 {label="Fuel System>>"})

      form.addRow(2)
      form.addLink((function() form.reinit(4) end),
	 {label="Pump properties>>"})

      form.addRow(2)
      form.addLink((function() form.reinit(5) end),
	 {label="Communications>>"})

      form.addRow(2)
      --form.addLabel({label="Save pump paramaters", width=220})
      form.addLink((function() saveParms() end), {label="Save parameters"})

      form.addRow(1)
      form.addLabel({label=appShort,font=FONT_MINI, alignRight=true})      

      form.setFocusedRow(savedRow)
      
   elseif subForm == 3 then -- Fuel-related parameters
      savedRow = subForm-2   
      
      form.setButton(1, "Back",1)
      form.setButton(3, "Save", 1)
      form.setButton(5, "Exit", 1)

      form.addRow(2)
      form.addLink((function() form.reinit(2) end),
      {label="<< Back"})

      form.addRow(2)
      form.addLabel({label="Delivery Pressure (psi)", width=220})
      form.addIntbox(pumpConfig.pressSetpoint*10,0,150,50,1,1,pressureChanged)

      form.addRow(2)
      form.addLabel({label="Fuel Tank Capacity"
			.. " (" ..flowUnit[pumpConfigGbl.flowIdx]..")", width=220})
      if pumpConfigGbl.flowIdx == 1 then -- Imperial
	 form.addIntbox(pumpConfig.tankCapacity,0,1000,100,0,1,tankCapacityChanged)
      else --Metric
	 form.addIntbox(pumpConfig.tankCapacity*100,0,3000,300,2,1,tankCapacityChanged)
      end

      form.addRow(2)
      form.addLabel({label="Fuel Tank Overfill"
			.. " (" ..flowUnit[pumpConfigGbl.flowIdx]..")", width=220})
      if pumpConfigGbl.flowIdx == 1 then -- Imperial
	 form.addIntbox(pumpConfig.tankOverfill,0,100,10,0,1,tankOverfillChanged)
      else
	 form.addIntbox(pumpConfig.tankOverfill*100,0,300,30,2,1,tankOverfillChanged)	 
      end

      form.addRow(2)
      form.addLabel({label="Autofill holdoff"
			.. " (" ..flowUnit[pumpConfigGbl.flowIdx]..")", width=220})
      
      if pumpConfigGbl.flowIdx == 1 then -- Imperial
	 form.addIntbox(pumpConfig.autoHoldoff,0,200,35,0,1,autoHoldoffChanged)
      else
	 form.addIntbox(pumpConfig.autoHoldoff*100,0,1000,30,2,1,autoHoldoffChanged)
      end

      form.addRow(2)
      form.addLabel({label="Announce Interval"
			.. " (" ..flowUnit[pumpConfigGbl.flowIdx]..")", width=220})
      
      if pumpConfigGbl.flowIdx == 1 then -- Imperial
	 form.addIntbox(pumpConfig.announceInt,0,1000,10,0,1,announceIntChanged)
      else
	 form.addIntbox(pumpConfig.announceInt*100,0,3000,50,2,1,announceIntChanged)
      end
      

      form.setFocusedRow(1)

   elseif subForm == 4 then -- config

      savedRow = subForm-2
      form.setButton(1, "Back",1)
      form.setButton(3, "Save", 1)
      form.setButton(5, "Exit", 1)

      form.addRow(2)
      form.addLink((function() form.reinit(2) end),
      {label="<< Back"})

      form.addRow(2)
      form.addLabel({label="Low Battery Shutdown (V)", width=220})
      form.addIntbox(pumpConfigGbl.lowBattLimit*10,0,100,85,1,1,lowBattLimitChanged)

      form.addRow(2)
      form.addLabel({label="Autofill Parameter", width=220})
      form.addIntbox(pumpConfig.autoParm*10,10,100,20,1,1,autoParmChanged)

      form.addRow(2)
      form.addLabel({label="Flow unit", width=220})
      form.addSelectbox(flowUnit, pumpConfigGbl.flowIdx, true, flowUnitChanged)

      form.addRow(2)
      form.addLabel({label="Max Reverse Speed (%)", width=220})
      form.addIntbox(pumpConfig.maxRevSpd,10,100,100,0,1,maxRevSpdChanged)      
      
      form.addRow(2)
      form.addLabel({label="Fill Cal Factor", width=220})
      form.addIntbox(pumpConfigGbl.CalF*100,5000,20000,8000,2,1,CalFChanged)

      form.addRow(2)
      form.addLabel({label="Empty Cal Factor", width=220})
      form.addIntbox(pumpConfigGbl.CalE*100,5000,20000,8000,2,1,CalEChanged)

      form.addRow(2)
      form.addLabel({label="Maximum PWM", width=220})
      form.addIntbox(pumpConfig.maxPWM,100,1023,1023,0,1,maxPWMChanged)

      form.setFocusedRow(1)

   elseif subForm == 5 then -- communications
      
      savedRow = subForm-2

      form.setButton(1, "Back",1)
      form.setButton(2, "RstPW", 1)
      form.setButton(3, "Save", 1)
      form.setButton(5, "Exit", 1)

      form.addRow(2)
      form.addLink((function() form.reinit(2) end),
      {label="<< Back"})
      
      form.addRow(2)
      form.addLabel({label="WiFi SSID", width=220})
      form.addTextbox(pumpConfigGbl.ssid, 63, ssidChanged)

      form.addRow(2)
      form.addLabel({label="WiFi PW", width=220})
      local pwv = (pumpConfigGbl.pwd == "")
      --print("pwv:", pwv)
      form.addTextbox(pwv and pumpConfigGbl.pwd or "***", 63, pwdChanged, {visible=true})
      
      form.addRow(2)
      form.addLabel({label="OTA Update", width=220})
      form.addLink((function() updateOTA() end), {label="Update >>"})

      form.addRow(2)
      form.addLabel({label="Unpair Bluetooth", width=220})
      form.addLink((function() unpairBLE() end), {label="Unpair >>"})

      form.setFocusedRow(1)

   else
   end
   
end

local function keyPump(key)
	 
   local KEY_RTR = 2048
   local KEY_RTL = 4096
   local KEY_RTU = 8192
   local KEY_RTD = 16384
   local KEY_LTR = 32768
   local KEY_LTL = 65536
   local KEY_LTU = 131072
   local KEY_LTD = 262144
   local tVOL
   
   local text, state = form.getButton(1)

   --print("key, text, state", key, text, state)
   --print(KEY_1, KEY_2, KEY_MENU, KEY_ESC, KEY_ENTER, KEY_UP)
   
   if not pumpActive then return end
   
   if text ~= "Back" then -- is this the main pump screen?
     
      if key == KEY_ESC then
	 form.preventDefault()
	 print("ESC Key pressed")
	 if form.question("Really exit?", "Pump control will be shut down",
			  "", 4000, false, 500) == 1  then
	    stopSerial()
	 end
	 
      elseif key == KEY_1 then
	 --print("Key 1 pressed")
	 form.setButton(1, ":backward", 2)	 
	 form.setButton(2, ":stop", 1)
	 countedWrite(string.format("(CalE: %.2f)\n", pumpConfigGbl.CalE))
	 countedWrite(string.format("(CalF: %.2f)\n", pumpConfigGbl.CalF))	 
	 countedWrite(string.format("(pMAX: %d)\n", pumpConfig.maxPWM)) 
	 countedWrite(string.format("(Prs: %.2f)\n", pumpConfig.pressSetpoint))
	 --countedWrite("(Spd: 100.0)\n")
	 countedWrite(string.format("(Spd: %d)\n", pumpConfig.maxRevSpd))
	 if pumpConfigGbl.flowIdx == 1 then
	    countedWrite("(Imp)\n")
	 else
	    countedWrite("(Met)\n")	    
	 end
	 Boxcar = {}
	 histogram = {}
	 histogram2 = {}
	 visible = {}
	 visible2 = {}
	 --histFile = io.open("Apps/DFM-Pump/Empty.dat", "w")
	 countedWrite("(Empty)\n")
	 nextsgTC = system.getTimeCounter()
	 pumpState = "Empty"
	 infoMsg = "Empty"
	 ratioHigh = 0
	 tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
	 nextAnn = -1 + ((tVOL * flowMult[pumpConfigGbl.flowIdx]) // pumpConfig.announceInt)
	 --print("key1, tVOL. nextAnn:", tVOL, nextAnn)
      elseif key == KEY_2 then
	 --print("Key 2 pressed")
	 form.setButton(1, ":backward", 1)	 
	 form.setButton(2, ":stop", 2)
	 form.setButton(3, ":forward", 1)
	 countedWrite("(Off)\n")
	 pumpState = "Off"
	 tVOL = 0
	 infoMsg = "Pump stopped"
	 --io.close(histFile)
      elseif key == KEY_3 then
	 --print("Key 3 pressed")
	 if pumpState == "Fill" then
	    system.messageBox("Autofill ready to arm", 2)
	    system.playFile("/"..appDir.."autofill_ready_to_arm.wav", AUDIO_QUEUE)
	    infoMsg = "Autofill ready to arm"
	    pumpState = "Autofill"
	    deltaStable = 0
	    Boxcar = {}
	 elseif pumpState ~= "Autofill" then
	    tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
	    nextAnn = 1 + (tVOL * flowMult[pumpConfigGbl.flowIdx]) // pumpConfig.announceInt
	    --print("key3, tVOL,nextAnn:", tVOL, nextAnn)
	    form.setButton(2, ":stop", 1)
	    form.setButton(3, ":forward", 2)
	    countedWrite(string.format("(CalF: %.2f)\n", pumpConfigGbl.CalF))
	    countedWrite(string.format("(CalE: %.2f)\n", pumpConfigGbl.CalE))	    
	    --countedWrite("(pMAX: 1023)\n")
	    countedWrite(string.format("(pMAX: %d)\n", pumpConfig.maxPWM))
	    countedWrite(string.format("(Prs: %.2f)\n", pumpConfig.pressSetpoint))
	    countedWrite("(Spd: 100)\n")
	    Boxcar = {}
	    histogram = {}
	    histogram2 = {}
	    visible = {}
	    visible2 = {}
	    --Boxcar = {}
	    --histogram = {}
	    --histogram2 = {}
	    countedWrite("(Fill)\n")
	    nextsgTC = system.getTimeCounter()
	    infoMsg = "Fill - Press >> again for AutoFill"
	    pumpState = "Fill"
	    ratioHigh = 0
	    fillStop = pumpConfig.tankCapacity + pumpConfig.tankOverfill
	    --histFile = io.open("Apps/DFM-Pump/Fill.dat", "w")
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
      elseif key == KEY_5 then 
	 form.preventDefault()
	 --print("Key 5 pressed")
	 if isubSub == 1 then
	    isubSub = isubSub + 1
	    if isubSub > #subSub then
	       isubSub = 1
	    end
	    form.setButton(5, ":left", 1)
	 elseif isubSub == 2 then
	    isubSub = isubSub - 1
	    if isubSub < 1 then
	       isubSub = 1
	    end
	    form.setButton(5, ":graphBig", 1)
	 end
	    
	 --if form.question("Really exit?", "Pump control will be shut down", "", 4000, false, 500) == 1  then
	    --pumpActive = false
	    --system.setProperty("CpuLimit", 1)	 
	    --form.close()
	 --end
	 
      elseif key == KEY_DOWN then
	 --print("key down", isubSub)
	 if isubSub == 1 then
	    pumpConfig.pressSetpoint = math.max(0, pumpConfig.pressSetpoint - 0.1)
	 elseif isubSub == 2 then
	    graphScaleIdx = graphScaleIdx + 1
	    graphScaleIdx = math.max(math.min(graphScaleIdx, #graphScaleRange[1]), 1)
	    graphScale = graphScaleRange[pumpConfigGbl.flowIdx][graphScaleIdx]
	    graphFmt = graphScaleFormat[pumpConfigGbl.flowIdx][graphScaleIdx]
	    graphScale2Idx = graphScale2Idx + 1
	    graphScale2Idx = math.max(math.min(graphScale2Idx, #graphScale2Range[1]), 1)
	    graphScale2 = graphScale2Range[pumpConfigGbl.flowIdx][graphScale2Idx]
	    graphFmt2 = graphScale2Format[pumpConfigGbl.flowIdx][graphScale2Idx]
	    --print("D", pumpConfigGbl.flowIdx, graphScale, graphFmt)
	    
	 end
	 --unsavedConfig = true -- maybe only save if changed from menu?
	 --system.pSave("pressSetpoint", pressSetpoint)	 
	 countedWrite(string.format("(Prs: %.2f)\n", pumpConfig.pressSetpoint))
	 --print("Key down")
      elseif key == KEY_UP then
	 --print("key up", isubSub)
	 if isubSub == 1 then
	    pumpConfig.pressSetpoint = math.min(10, pumpConfig.pressSetpoint + 0.1)
	 elseif isubSub == 2 then
	    graphScaleIdx = graphScaleIdx - 1
	    graphScaleIdx = math.max(math.min(graphScaleIdx, #graphScaleRange[1]), 1)
	    graphScale = graphScaleRange[pumpConfigGbl.flowIdx][graphScaleIdx]
	    graphFmt = graphScaleFormat[pumpConfigGbl.flowIdx][graphScaleIdx]
	    graphScale2Idx = graphScale2Idx - 1
	    graphScale2Idx = math.max(math.min(graphScale2Idx, #graphScale2Range[1]), 1)
	    graphScale2 = graphScale2Range[pumpConfigGbl.flowIdx][graphScale2Idx]
	    graphFmt2 = graphScale2Format[pumpConfigGbl.flowIdx][graphScale2Idx]
	    --print("U", pumpConfigGbl.flowIdx, graphScale, graphFmt)
	 end
	 --unsavedConfig = true
	 --system.pSave("pressSetpoint", pressSetpoint)
	 countedWrite(string.format("(Prs: %.2f)\n", pumpConfig.pressSetpoint))
	 --print("Key up")
      elseif key == KEY_ENTER then
	 if subForm == 1 then
	    system.messageBox("Clear - values reset ", 2)
	    graphReset()
	    if fCNT then fCNT = 0 end
	    fRAT = 0
	    eCNT = 0
	    rTIMmins = 0
	    rTIMsecs = 0	 
	    Boxcar={}
	    dataStreamMax=0
	    longData=0
	    iimax=0
	    countedWrite("(Clear)\n")
	 end
      end
   else
      if key == KEY_1 then
	 --print("key1")
	 form.reinit(1)
      elseif key == KEY_2 then
	 pumpConfigGbl.pwd = ""
	 form.reinit(2)
      elseif key == KEY_3 then
	 saveParms()
      elseif key == KEY_5 or key == KEY_ESC then
	 form.preventDefault()
	 --print("Key 5 pressed")
	 if form.question("Really exit?", "Pump control will be shut down", "",
			  4000, false, 500) == 1  then
	    stopSerial()
	 end
      end
   end
   if key ~= KEY_RELEASED then
      lastKey = key
   --else
   --  lastKey = -1
   end
   
end

local function destroy()
   --[[
   local test = {CTUPctFuel=90, sysTime=system.getTime()}
   local ff = io.open(appDir .. "S-"..system.getProperty("ModelFile"), "w") 

   print("Destroy! " ..system.getTime())

   if not ff then
      system.messageBox("Cannot open S file")
      return
   end
   if not io.write(ff,json.encode(test)) then
      system.messageBox("Cannot write S file")
   end
   io.close(ff)
   system.messageBox("S file saved", 2)
   --]]
end

local function logCB()
   local tVOL, uVOL
   tVOL = ( ( (fCNT or 0) / pumpConfigGbl.CalF) - ( (eCNT or 0) / pumpConfigGbl.CalE) )
   uVOL = tVOL * flowMult[pumpConfigGbl.flowIdx]
   print("logCB", tVOL, uVOL)
   return math.floor(uVOL*100 + 0.5), 2
end

local function init()

   local dt
   local port
   local portList
   local portStr
   local fj
   local file
   local ctu
   local time, ltime
   
   system.setProperty("CpuLimit", 0)
   dt = system.getDateTime()
   -- if we ever want to make our own log files?
   -- = string.format("Tele_%02d%02d_%d%02d%02d.dat", dt.mon, dt.day, dt.hour, dt.min, dt.sec)

   dev, emflag = system.getDeviceType()
   emflag = (emflag == 1)

   if emflag then demoMode = true else demoMode = false end
   print("demoMode:", demoMode)
   
   if emflag then
      portList = serial.getPorts()
      if #portList > 0 then
	 portStr = portList[1]
	 for i=2, #portList, 1 do
	    portStr = portStr .. ", " .. portList[i]
	 end
	 print("DFM-Pump: Ports available - " .. portStr)
	 port = portList[2] -- edit if required
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
	 print("DFM-Pump: Serial init to " ..port .." failed <"..descr..">")
      end
   end

   local foo=gpio.mode(8,"out-pp")
   print("gpio.mode:", foo)
   gpio.write(8,1)   
   print("BLE powered on")
   
   system.registerForm(1, 0, "Fuel Station Control", initPump, keyPump, prtPump)
   
   system.registerTelemetry(1,"Pump", 4, pumpTele)

   arcFile.C = lcd.loadImage(appDir .. "c-000.png")
   arcFile.S = lcd.loadImage(appDir .. "s-000.png")   
   arcFile.L = lcd.loadImage(appDir .. "l-000.png")



   -- First, get model-specific pump config info
   modelFile = appDir .. "P-" .. string.gsub(system.getProperty("Model")..".jsn", " ", "_")
   --print("modelFile: " .. modelFile)
   fj = io.readall(modelFile)
   --print("fj: ", fj)
   if fj then pumpConfig = json.decode(fj) end
   if not pumpConfig then pumpConfig = {} end

   -- Then the "global" (non-model-specific) info
   
   fj = io.readall(appDir .. "PumpGlobal.jsn")
   --print("fj from PumpGlobal.jsn:", fj)
   if fj then pumpConfigGbl = json.decode(fj) end
   --print("type of pumpConfigGbl", type(pumpConfigGbl))
   --print("pumpConfigGbl:", pumpConfigGbl)
   if not pumpConfigGbl or type(pumpConfigGbl) ~= "table" then
      --print("setting pumpConfigGbl to {}")
      pumpConfigGbl = {}
   end

   -- Local paramaters

   pumpConfig.tankCapacity  = jLoad(pumpConfig, "tankCapacity", 100)
   pumpConfig.pressSetpoint = jLoad(pumpConfig, "pressSetpoint", 5)   
   pumpConfig.maxPWM        = jLoad(pumpConfig, "maxPWM", 1023)
   pumpConfig.maxPWM        = math.max(math.min(pumpConfig.maxPWM, 1023), 100)
   pumpConfig.autoParm      = jLoad(pumpConfig, "autoParm", 2.5)
   pumpConfig.maxRevSpd     = jLoad(pumpConfig, "maxRevSpd", 100)
   pumpConfig.tankOverfill  = jLoad(pumpConfig, "tankOverfill", 10)
   pumpConfig.autoHoldoff   = jLoad(pumpConfig, "autoHoldoff", 0)
   pumpConfig.announceInt   = jLoad(pumpConfig, "announceInt", 0)   

   -- Global parameters
   
   pumpConfigGbl.CalE         = jLoad(pumpConfigGbl, "CalE",  80)
   pumpConfigGbl.CalF         = jLoad(pumpConfigGbl, "CalF", 80)
   pumpConfigGbl.flowIdx      = jLoad(pumpConfigGbl, "flowIdx", 1)
   pumpConfigGbl.lowBattLimit = jLoad(pumpConfigGbl, "lowBattLimit", 9.0)
   pumpConfigGbl.ssid         = jLoad(pumpConfigGbl, "ssid", "")
   pumpConfigGbl.pwd          = jLoad(pumpConfigGbl, "pwd", "")

   unsavedConfig = false

   graphScale = graphScaleRange[pumpConfigGbl.flowIdx][graphScaleIdx]
   graphFmt   = graphScaleFormat[pumpConfigGbl.flowIdx][graphScaleIdx]

   graphScale2 = graphScale2Range[pumpConfigGbl.flowIdx][graphScale2Idx]
   graphFmt2   = graphScale2Format[pumpConfigGbl.flowIdx][graphScale2Idx]
   
   graphReset()

   system.registerLogVariable("Flow", flowUnit[pumpConfigGbl.flowIdx], logCB)

    file = io.readall("Apps/digitech/lastfuel.jsn") 
    if (file) then
        ctu = json.decode(file)
	print("ctu.lastFuel: " .. ctu.lastFuel)
	print("ctu.lastTime: " .. ctu.lastTime)
	time = system.getTime()
	print("current time: " .. time)
	ltime = tonumber(ctu.lastTime)
	print("decoded lastTime: " .. ltime)
	print("delta T: " .. (time - ltime))
    end
   
   
end



return {init=init, loop=loop, author="DFM", version=1, name="PumpControl", destroy=destroy}
