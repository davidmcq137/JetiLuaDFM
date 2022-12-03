local M = {}

local savedTime = {}
local savedXP =  {}
local savedYP =  {}
local savedPos = {}
local futurePos = {}
local rgbHist =  {}
local maxSaved = 0
local MAXSAVEDLIMIT = 1000
local heading
local rgb = {}
local rgbLast
local ribbon = {}
local lastTime
local lastX0, lastY0
local CPUPanic = false
local CPUAvg = 0
local CPUHigh = 0
local iStart, iEnd = 0, 0
local mapScale = {100, 250, 500, 750, 1000, 1500, 2000}
local curX, curY
local lastX, lastY
local xmin, xmax, ymin, ymax
local mapScaleIdx = 1
local lastNoFly

local shapes = {}
shapes.Glider =  {
   {0,-7},
   {-1,-2},
   {-14,0},
   {-14,2},	
   {-1,2},	
   {-1,8},
   {-4,8},
   {-4,10},
   {0,10},
   {4,10},
   {4,8},
   {1,8},
   {1,2},
   {14,2},
   {14,0},
   {1,-2}
}
shapes.Prop = {
   {-1,-6},
   {-2,-2},
   {-11,-2},
   {-11,1},	
   {-2,2},	
   {-1,8},
   {-5,8}, 
   {-5,11},
   {5,11},
   {5,8},
   {1,8},
   {2,2},
   {11,1},
   {11,-2},
   {2,-2},
   {1,-6}
}
shapes.Jet = {
   {0,-20},
   {-3,-6},
   {-10,0},
   {-10,2},
   {-2,2},
   {-2,4},
   {-6,8},
   {-6,10},
   {0,10},
   {6,10},
   {6,8},
   {2,4},
   {2,2},
   {10,2},
   {10,0},
   {3,-6}
}
shapes.delta = {
   {0,-6},
   {-4,6},
   {0,6},
   {4,6}
}

function M.fieldStr()
   return string.format("[%dx%d]",xmax-xmin, ymax-ymin)
end

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

function M.getXP(x)
   return xp(x)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

function M.getYP(y)
   return yp(y)
end

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
end

function M.readTele(sensIdPa, mapV)
   local sensor
   local loadReq

   loadReq = false
   
   sensor = system.getSensorByID(sensIdPa.alt.SeId, sensIdPa.alt.SePa)
   if sensor and sensor.valid then
      mapV.altitude = sensor.value
      mapV.altunit = sensor.unit
      loadReq = true
   end

   sensor = system.getSensorByID(sensIdPa.spd.SeId, sensIdPa.spd.SePa)
   if sensor and sensor.valid then
      mapV.speed = sensor.value
      mapV.spdUnit = sensor.unit
      loadReq = true
   end
   return loadReq
end


-- convert no fly polygon coords from lat,lng to x,y in current frame
function M.noFlyCalc(settings, mapV, nfz)
   local pt, cD, cB, x, y
   for i in ipairs(nfz) do
      if not nfz[i].xy then nfz[i].xy = {} end
      for j in ipairs(nfz[i].path) do
	 pt = gps.newPoint(nfz[i].path[j].lat,nfz[i].path[j].lng)
	 cD = gps.getDistance(mapV.zeroPos, pt)
	 cB = gps.getBearing(mapV.zeroPos, pt)
	 x = cD * math.cos(math.rad(cB+270))
	 y = cD * math.sin(math.rad(cB+90))
	 x,y = rotateXY(x, y, (settings.rotA or 0))
	 nfz[i].xy[j] = {x=x,y=y}
	 if x > mapV.maxPolyX then mapV.maxPolyX = x end
      end
   end
   mapV.needCalcXY = false
end

local function setMapScale(s)
   local mm = mapScale[s]
   return -mm, mm, -0.5*mm/2, 1.5*mm/2
end

function M.drawInit()
   mapScaleIdx = 1
   xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)

   local rp = 10
   for k = 1, rp, 1 do
      rgb[k] = {}
      rgb[k].r = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp)) / 2)
      rgb[k].g = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 2*math.pi/3)) / 2)
      rgb[k].b = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 4*math.pi/3)) / 2)
   end
end

-- this table is replicated in settingsCmd.lua ... must change in both places
local colorSelect = {"None", "Rx1 Q", "Rx1 A1","Rx1 A2","Rx2 Q", "Rx2 A1", "Rx2 A2", "P4"}

function M.drawColors()
   for i = 1, #rgb, 1 do
      lcd.setColor(rgb[i].r, rgb[i].g, rgb[i].b)
      lcd.drawFilledRectangle(-22 + 30*i, 117, 20, 20)
      lcd.setColor(255,255,255)
      local text = tostring(i)
      lcd.getTextWidth(FONT_NORMAL, text)
      lcd.drawText(-12-0.5*lcd.getTextWidth(FONT_MINI, text)+30*i, 120, text, FONT_MINI)
   end
end

function M.recalcXY(settings, mapV)

   --print("recalcXY")
   
   -- this function recalcs saved pixels if screen zooms
   local np = #savedPos
   
   -- do this recalc in 50 pts chunks so don't blow up CPU usage
   -- suspend drawing the ribbon while recomputing the pixel values
   local chunk = 50

   local cD, cB, cX, cY

   if iStart + iEnd == 0 then
      iStart = 1
      iEnd = math.min(np, chunk)
   end

   --print("np, iStart, iEnd", np, iStart, iEnd)
   
   for i = iStart, iEnd, 1 do
      cD = gps.getDistance(mapV.zeroPos, savedPos[i])
      cB = gps.getBearing(mapV.zeroPos, savedPos[i])
      cX = cD * math.cos(math.rad(cB+270)) -- why not same angle X and Y??
      cY = cD * math.sin(math.rad(cB+90))
      cX, cY = rotateXY(cX, cY, settings.rotA or 0)
      savedXP[i] = xp(cX)
      savedYP[i] = yp(cY)
   end

   if iEnd < np then
      iStart = iEnd + 1
      iEnd = iStart + chunk
      iEnd = math.min(iEnd, np)
   else
      iStart = 0
      iEnd = 0
   end
end

local function resetPos()
   savedTime = {}
   savedXP =  {}
   savedYP =  {}
   savedPos = {}
   rgbHist =  {}
end

function M.setMAX(max, settings, mapV)
   local ts = math.max(0, math.min(max, MAXSAVEDLIMIT))
   if ts ~= maxSaved then
      resetPos()
      CPUPanic = false
   end
   maxSaved = ts
   M.recalcXY(settings, mapV)

   return maxSaved
end

local function setTextColor()
   local colorCode = system.getProperty("Color")
   if colorCode <= 6 or colorCode == 8 then
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
end

local function setColor(type)
   local colorCode = system.getProperty("Color")
   if colorCode <= 6 then -- white bg
      if type == "In" then
	 lcd.setColor(220,0,0)
      else
	 lcd.setColor(0,180,20)
      end
   elseif colorCode == 7 then -- blue bg
      if type == "In" then
	 lcd.setColor(255,160,16)
      else
	 lcd.setColor(96,255,128)
      end
   elseif colorCode == 8 then -- yellow bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(96,255,128)
      end
   else -- black bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(0,192,0)
      end
   end
end

local function drawShape(col, row, shapename, rotation, type)
   local sinShape, cosShape
   local ren = lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   setColor(type)
   local shape = shapes[shapename]
   if not shape then print("DFM-GPS: bad shape"); return end
   ren:reset()
   for i, _ in pairs(shape) do
      ren:addPoint(
	 col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	 row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5)
      )
   end
   ren:renderPolygon()
   setTextColor()
end

local function drawNFZ(nfz)
   local ren = lcd.renderer()
   local n
   local x0,y0,r
   local npc=30
   for i in ipairs(nfz) do
      if nfz[i].type == "inside" then
	 setColor("In")
      else
	 setColor("Out")
      end
      if nfz[i].shape == "polygon" then
	 n = #nfz[i].xy
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j = 1, n+1, 1 do 
	    ren:addPoint(xp(nfz[i].xy[j % n + 1].x),
			 yp(nfz[i].xy[j % n + 1].y))
	 end
	 ren:renderPolyline(2,1.0)
      elseif nfz[i].shape == "circle" then
	 x0 = xp(nfz[i].xy[1].x)
	 y0 = yp(nfz[i].xy[1].y)
	 r = 320*nfz[i].radius/(xmax-xmin)
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j=0,npc,1 do
	    ren:addPoint(x0 + r * math.sin(2*math.pi*j/npc),
			 y0 + r * math.cos(2*math.pi*j/npc))
	 end
	 ren:renderPolyline(2,1.0)
      end
   end
   setTextColor()
end

local function gradientIndex(inval, inmin, inmax, bins, mod)
   -- for a value val, maps to the gradient rgb index for val from min to max
   local bin, val
   local min, max
   if mod then min, max = 0, mod else min, max = inmin, inmax end
   ribbon.currentValue  = inval
   if mod then val = inval % mod else val = inval end
   bin = math.floor(((bins - 1) * math.max(math.min((val - min) / (max-min),1),0) + 1) + 0.5)   
   ribbon.currentBin = bin
   return bin
end

local function savePoints(settings, mapV)

   local jj
   local dist2
   local now
   local dt

   if not lastX0 then lastX0 = -1 end --lastX - 0.01 end
   if not lastY0 then lastY0 = -1 end --lastY - 0.01 end

   if mapV.selField and (curX ~= lastX0 or curY ~= lastY0) then
      
      heading = math.atan(curX - lastX0, curY - lastY0)
      now = system.getTimeCounter()
      dist2 = (curX - lastX)^2 + (curY - lastY)^2
      lastX0 = curX
      lastY0 = curY

      if not lastTime then lastTime = now end
      dt = now - lastTime

      if (not CPUPanic) and dt > settings.msMinSpacing and dist2 > settings.mMinSpacing2 then
	 
	 ribbon.currentFormat = "%.f"
	 if settings.colorSelect == 1 then -- none
	    jj = #rgb // 2 -- mid of gradient - right now this is sort of a yellow color
	 elseif settings.colorSelect == 2 then -- Rx1 Q
	    jj = gradientIndex(system.getTxTelemetry().rx1Percent, 0, 100,  #rgb)
	 elseif settings.colorSelect == 3 then -- Rx1 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[1],    0, 100,  #rgb)
	 elseif settings.colorSelect == 4 then -- Rx1 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[2],    0, 100,  #rgb)
	 elseif settings.colorSelect == 5 then -- Rx2 Q
	    jj = gradientIndex(system.getTxTelemetry().rx2Percent, 0, 100,  #rgb)
	 elseif settings.colorSelect == 6 then -- Rx2 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[3],    0, 100,  #rgb)
	 elseif settings.colorSelect == 7 then -- Rx2 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[4],    0, 100,  #rgb)
	 elseif settings.colorSelect == 8 then -- P4
	    jj = gradientIndex((1+system.getInputs("P4"))*50, 0,   100,  #rgb)	   
	 else
	    local val = 0
	    local sensor = system.getSensorByID(settings.csId, settings.csPa)
	    if sensor and sensor.valid then
	       val = sensor.value
	    end
	    jj = gradientIndex(val, 0, 100, #rgb, settings.ribbonScale)	   	    
	 end

	 if #savedXP+1 > maxSaved then
	    table.remove(savedTime, 1)
	    table.remove(savedPos, 1)
	    table.remove(savedXP, 1)
	    table.remove(savedYP, 1)
	    table.remove(rgbHist, 1)
	 else
	    table.insert(savedTime, now)
	    table.insert(savedPos, mapV.curPos)
	    table.insert(savedXP, xp(curX))
	    table.insert(savedYP, yp(curY))
	    table.insert(rgbHist, {r=rgb[jj].r, g=rgb[jj].g, b=rgb[jj].b,
				   rgb = rgb[jj].r*256*256+ rgb[jj].g*256 + rgb[jj].b})
	 end
	 lastTime = now
	 lastX = curX
	 lastY = curY
      end
   end
end

function M.readGPS(sensIdPa, settings, mapV, initGPS, keyGPS)

   mapV.curPos = gps.getPosition(sensIdPa.lat.SeId, sensIdPa.lat.SePa, sensIdPa.lng.SePa)   
   
   if mapV.curPos and not mapV.initPos then mapV.gpsReads = mapV.gpsReads + 1 end
   
   if mapV.gpsReads > 9 then
      if not mapV.initPos then
	 mapV.initPos = mapV.curPos
	 if not mapV.zeroPos then mapV.zeroPos = mapV.curPos end
	 system.registerForm(2, 0, "DFM-GPS Field Selection", initGPS, keyGPS)
      end

      
      mapV.curDist = gps.getDistance(mapV.zeroPos, mapV.curPos)
      mapV.curBear = gps.getBearing(mapV.zeroPos, mapV.curPos)
      
      curX = mapV.curDist * math.cos(math.rad(mapV.curBear+270)) -- why not same angle X and Y??
      curY = mapV.curDist * math.sin(math.rad(mapV.curBear+90))
      
      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, settings.rotA or 0)
      savePoints(settings, mapV)
      return 
   end
end



local function drawRibbon(settings, mapV)

   local rh
   local polyW, polyA = 2, 1

   if iStart + iEnd > 0 then M.recalcXY(settings, mapV); return end
   
      if maxSaved <= 9999 then
      local ren = lcd.renderer()
      ren:reset()
      rgbLast = -1
      local is = 0
      for i=1,#savedXP do

	 
				       
	 rh = rgbHist[i]
	 if i == 1 then lcd.setColor(rh.r, rh.g, rh.b); rgbLast = rh.rgb end
	 if settings.showMarkers then
	    lcd.drawCircle(savedXP[i], savedYP[i], 2)
	 end

	 -- max points in renderPolyline is 127,
	 -- check if we have to render and reset new segment
	 if is+1 > 127 then
	    ren:addPoint(savedXP[i], savedYP[i])
	    ren:renderPolyline(polyW, polyA)
	    ren:reset()
	    ren:addPoint(savedXP[i], savedYP[i])
	    is = 1
	 end

	 if rh.rgb ~= rgbLast then
	    if rh.rgb ~= rgbLast and settings.colorSelect ~= 1 then
	       ren:addPoint(savedXP[i], savedYP[i])
	       ren:renderPolyline(polyW, polyA)
	       lcd.setColor(rh.r, rh.g, rh.b)
	       rgbLast = rh.rgb
	       ren:reset()
	       ren:addPoint(savedXP[i], savedYP[i])	       
	       is = 1
	    end
	 end

	 ren:addPoint(savedXP[i], savedYP[i])
	 is = is + 1
	 
      end

      if not CPUPanic then ren:addPoint(xp(curX), yp(curY)) end
      ren:renderPolyline(polyW, polyA)
   else 
      -- this code uses regular lines not anti-alias. can set the 9999 to something smaller
      -- so that it switches to regular lines at some point (perhaps 500-600?) and lets the max
      -- ribbon be larger. for now leave it on AA all the time.
      if #savedXP > 1 then
	 rgbLast = -1
	 for i=2,#savedXP do
	    rh = rgbHist[i-1]
	    if rh.rgb ~= rgbLast and settings.colorSelect ~= 1 then
	       lcd.setColor(rh.r, rh.g, rh.b)
	       rgbLast = rh.rgb
	    end
	    lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
	    if settings.showMarkers then
	       lcd.drawCircle(savedXP[i-1], savedYP[i-1], 3)
	    end
	 end
	 if settings.showMarkers then
	    lcd.drawCircle(savedXP[#savedXP], savedYP[#savedYP], 3)
	 end
	 if not CPUPanic then
	    lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
	 end
      end
   end
   if settings.colorSelect > 1 and rgb and ribbon.currentBin then
      lcd.setColor(rgb[ribbon.currentBin].r, rgb[ribbon.currentBin].g, rgb[ribbon.currentBin].b)
      lcd.drawFilledRectangle(195 , 148, 6,6)
      setTextColor()
      local ss
      if settings.colorSelect <= #colorSelect then
	 ss = colorSelect[settings.colorSelect]
      else
	 ss = string.format("%s", settings.csLa)
      end
      
      lcd.drawText(205, 145,
		   string.format("%s %.2f", ss, ribbon.currentValue), FONT_MINI)
   end
   setTextColor()

   if settings.msMinSpacing > 0 or settings.mMinSpacing > 0 then
      local pp = #savedXP
      if pp > 1 then
	 local dd = gps.getDistance(savedPos[pp], savedPos[pp-1])
	 local tt = savedTime[pp] - savedTime[pp-1]
	 lcd.drawText(35, 145, string.format("D: %d m T: %.2f s", dd, tt/1000), FONT_MINI)
      end
   end
      
   local cc = system.getCPU()
   CPUAvg = (cc - CPUAvg) / 3.0 + CPUAvg
   if cc > CPUHigh then CPUHigh = cc end
   if CPUAvg > 70 and not CPUPanic then
      print("DFM-GPS: CPU panic", cc)
      system.messageBox("CPU limit on history ribbon")
      CPUPanic = true
   end
   
   local nn
   if savedXP then nn = #savedXP else nn = 0 end
   if select(2, system.getDeviceType()) == 1 then
      lcd.drawText(35, 0, string.format("P: %d  CPU: %d",
					nn, cc), FONT_MINI)      
      --lcd.drawText(32, 0, "P: "..nn.."/"..maxSaved.."   CPU: "..system.getCPU(), FONT_MINI)
   end
end

function M.checkNoFly(settings, mapV, nfz, NF, monoTx)

   if not NF then
      NF = require "DFM-GPS/compGeo"
   end
   
   if nfz and #nfz > 0 and mapV.zeroPos and nfz[1].xy then
      if mapV.needCalcXY then
	 --print("before drawNFZ")
	 M.noFlyCalc(settings, mapV, nfz)
      end
      drawNFZ(nfz)
   end
   
   if curX and curY then
      
      if curX < xmin or curX > xmax or curY < ymin or curY > ymax then
	 if mapScaleIdx + 1 <= #mapScale then
	    mapScaleIdx = mapScaleIdx + 1
	    xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)
	    M.recalcXY(settings, mapV)
	 end
      end
      
      local noFly
      if nfz and #nfz > 0 and NF then
	 local txy = {x=curX,y=curY}
	 local noFlyP = false
	 local noFlyC = false
	 for i in ipairs(nfz) do 
	    if nfz[i].shape == "polygon" then
	       noFlyP = noFlyP or NF.isNoFlyP(nfz[i], txy, mapV.maxPolyX)
	    else
	       noFlyC = noFlyC or NF.isNoFlyC(nfz[i], txy)
	    end
	 end
	 noFly = noFlyP or noFlyC
	 if lastNoFly == nil then lastNoFly = noFly end
	 if noFly and not lastNoFly then
	    if settings.nfzBeeps then
	       system.playBeep(1, 1200, 800)
	    end
	    if settings.nfzWav then
	       system.playFile("/Apps/DFM-GPS/enter_no_fly.wav")
	    end
	 end
	 if not noFly and lastNoFly then
	    if settings.nfzBeeps then
	       system.playBeep(0, 600, 400)
	    end
	    if settings.nfzWav then
	       system.playFile("/Apps/DFM-GPS/exit_no_fly.wav")
	    end
	 end
	 lastNoFly = noFly
      else
	 noFly = false
      end
      
      drawRibbon(settings, mapV)

      --print(heading, settings.rotA)
      local hdg = heading or 0
      local df
      if mapV.speed then
	 df = mapV.speed * 4
      else
	 df = 100
      end
      --print(mapV.speed, df)
      local fP = gps.getDestination(mapV.curPos, df, math.deg(hdg+settings.rotA))
      local cD = gps.getDistance(mapV.zeroPos, fP)
      local cB = gps.getBearing(mapV.zeroPos, fP)
      local cx = cD * math.cos(math.rad(cB+270))
      local cy = cD * math.sin(math.rad(cB+90))
      cx, cy = rotateXY(cx, cy, (settings.rotA or 0))
      drawShape(xp(cx), yp(cy),
		"delta", hdg+settings.rotA-math.pi/2+math.rad(10), "In")--10 degrees? wtf!      

      if noFly then
	 if monoTx then
	    lcd.drawCircle(xp(curX), yp(curY), 4)
	 else
	    drawShape(xp(curX), yp(curY), settings.planeShape, (heading or 0), "In")
	 end
      else
	 drawShape(xp(curX), yp(curY), settings.planeShape, (heading or 0), "Out")
      end
   end

   return NF
end

return M
