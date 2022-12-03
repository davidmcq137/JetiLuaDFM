local M = {}

local savedXP = {}
local savedYP = {}
local MAXSAVED
local heading
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

function M.setMAX() --max, settings, mapV)
   MAXSAVED = 15
   return MAXSAVED
end

function M.recalcXY()
   savedXP = {}
   savedYP = {}
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
end

local function savePoints() --settings, mapV)

   if curX ~= lastX or curY ~= lastY then -- and dist > 5 then -- new point
      heading = math.atan(curX-lastX, curY - lastY)
      if #savedXP+1 > MAXSAVED then
	 table.remove(savedXP, 1)
	 table.remove(savedYP, 1)
      else
	 table.insert(savedXP, xp(curX))
	 table.insert(savedYP, yp(curY))
      end
      lastX = curX
      lastY = curY
   end
   
   return lastX, lastY, heading
end

local function drawShape(col, row, shapename, rotation)
   
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   --local shape = shapes[shapename]
   local shape = shapes.Glider -- monoTX fixed icon
   if not shape then return end
   for i, _ in pairs(shape) do
      if i < #shape then
	 lcd.drawLine(
	    col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	    row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5),
	    col + (shape[i+1][1]*cosShape - shape[i+1][2]*sinShape + 0.5),
	    row + (shape[i+1][1] * sinShape + shape[i+1][2] * cosShape + 0.5)	    
	 )
      end
   end
   lcd.drawLine(
      col + (shape[#shape][1]*cosShape - shape[#shape][2]*sinShape + 0.5),
      row + (shape[#shape][1] * sinShape + shape[#shape][2] * cosShape + 0.5),
      col + (shape[1][1]*cosShape - shape[1][2]*sinShape + 0.5),
      row + (shape[1][1] * sinShape + shape[1][2] * cosShape + 0.5)
   )

end

local function drawNFZ(nfz)
   for i in ipairs(nfz) do
      if nfz[i].shape == "polygon" then
	 local n = #nfz[i].xy
	 if n > 3 then
	    for j=1,n-1 do
	       lcd.drawLine(xp(nfz[i].xy[j].x),yp(nfz[i].xy[j].y),xp(nfz[i].xy[j+1].x),yp(nfz[i].xy[j+1].y))
	    end
	    lcd.drawLine(xp(nfz[i].xy[n].x),yp(nfz[i].xy[n].y),xp(nfz[i].xy[1].x),yp(nfz[i].xy[1].y))
	 end
      else
	 if nfz[i].xy and #nfz[i].xy > 0 then
	    lcd.drawCircle(xp(nfz[i].xy[1].x), yp(nfz[i].xy[1].y), 320*nfz[i].radius/(xmax-xmin))
	 end
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
      
      if mapV.curPos then
	 mapV.curDist = gps.getDistance(mapV.zeroPos, mapV.curPos)
	 mapV.curBear = gps.getBearing(mapV.zeroPos, mapV.curPos)
	 
	 curX = mapV.curDist * math.cos(math.rad(mapV.curBear+270)) -- why not same angle X and Y??
	 curY = mapV.curDist * math.sin(math.rad(mapV.curBear+90))
	 
	 if not lastX then lastX = curX end
	 if not lastY then lastY = curY end
	 
	 curX, curY = rotateXY(curX, curY, settings.rotA or 0)
	 savePoints(settings, mapV)
      end
   end
end

local function drawRibbon() --settings, mapV)
   if #savedXP < 3 then return end
   for i=2,#savedXP do
      lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
   end
   lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
end

function M.checkNoFly(settings, mapV, nfz, NF, monoTx)

   if not NF then
      print("gc NF1", collectgarbage("count"))
      NF = require "DFM-GPS/compGeo"
      print("gc NF2", collectgarbage("count"))
   end
   
   if nfz and #nfz > 0 and mapV.zeroPos and nfz[1].xy then
      if mapV.needCalcXY then
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
	    --if settings.nfzWav then
	    --   system.playFile("/Apps/DFM-GPS/enter_no_fly.wav")
	    --end
	 end
	 if not noFly and lastNoFly then
	    if settings.nfzBeeps then
	       system.playBeep(0, 600, 400)
	    end
	    --if settings.nfzWav then
	    --   system.playFile("/Apps/DFM-GPS/exit_no_fly.wav")
	    --end
	 end
	 lastNoFly = noFly
      else
	 noFly = false
      end
      
      drawRibbon(settings, mapV)
      
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
