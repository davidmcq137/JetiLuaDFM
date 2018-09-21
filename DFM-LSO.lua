--[[

   --------------------------------------------------------------------------------------------------
   DFM-LSO.lua -- "Landing Signal Officer" -- GPS Map and "ILS"/GPS RNAV system

   Derived from DFM's Speed and Time Announcers, which were turn was derived from RCT's Alt Announcer
   Borrowed and modified code from Jeti's AH example for tapes and heading indicator.
   New code to project Lat/Long via simple equirectangular projection to XY plane, and to
   compute heading from the projected XY plane track for GPS sensors that don't have this feature 
   and create an map of flightpath and an  ILS "localizer" based on GPS (e.g a model version of GPS RNAV)
    
   Requires transmitter firmware 4.22 or higher.
    
   Works in DS-24

   --------------------------------------------------------------------------------------------------
   DFM-LSO.lua released under MIT license by DFM 2018
   --------------------------------------------------------------------------------------------------

--]]

collectgarbage()

------------------------------------------------------------------------------

-- Locals for application

-- local trans11

local LatitudeSe, LatitudeSeId, LatitudeSePa
local LongitudeSe, LongitudeSeId, LongitudeSePa
local AltitudeSe , AltitudeSeId , AltitudeSePa
local SpeedNonGPSSe, SpeedNonGPSId, SpeedNonGPSPa
local SpeedGPSSe, SpeedGPSSeId, SpeedGPSSePa
local DistanceGPSSe, DistanceGPSSeId, DistanceGPSSePa
local CourseGPSSe, CourseGPSSeId, CourseGPSSePa
local BaroAltSe, BaroAltSeId, BaroAltSePa
local latitude, longitude
local speedGPS, speedNonGPS = 0,0
local courseGPS, courseNonGPS, course
local altitude, speed = 0,0
local DistanceGPS, distance
local magneticVar

local xtable = {}
local ytable = {}
--local ztable = {}

local vviAlt = {}
local vviTim = {}
local vvi, va
local ivvi = 1
local xd1, yd1
local xd2, yd2
local td1, td2

local mapXmin, mapXmax = -200, 200
local mapYmin, mapYmax = -100, 100
local xmin, xmax, ymin, ymax = mapXmin, mapXmax, mapYmin, mapYmax
local mapXrange = mapXmax - mapXmin
local mapYrange = mapYmax - mapYmin

local DEBUG = true -- if set to <true> will print to console the speech files and output
local debugTime = 0
local DEBUGLOG = true -- persistent state var for debugging (e.g. to print something in a loop only once)

-- these lists are the non-GPS sensors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }

local throttleControl
local brakeControl
local brakeReleaseTime = 0
local oldBrake = 0
local oldThrottle=0

local xTakeoffStart
local yTakeoffStart
local zTakeoffStart

local xTakeoffComplete
local yTakeoffComplete
local zTakeoffComplete

local TakeoffHeading
local ReleaseHeading
local RunwayHeading

local neverAirborne=true

local resetOrigin=false
local resetClick=false
local resetCompIndex

local lastLoopTime = 0
local avgLoopTime = 0
local loopCount = 0

local lastlat = 0
local lastlong = 0
local gotInitPos = false
local baroAltZero = 0
local L0, y0
local long0, lat0, coslat0
local rE = 21220539.7  -- 6371*1000*3.28084 radius of earth in ft, fudge factor of 1/0.985
local rEff = 0.74 -- fudge factor to get x,y calcs to match google earth
local rad = 180/math.pi
local compcrs
local heading, compcrsDeg = 0, 0
local vario=0
local lineAvgPts = 4  -- number of points to linear fit to compute course
local vviSlopeTime = 0
local speedTime = 0
local oldx, oldy=0,0
local numGPSreads = 0
local timeRO = 0

local ren=lcd.renderer()
local ren2=lcd.renderer()

local txtr, txtg, txtb = 0,0,0

local ff
local qq
local sysTimeStart = system.getTimeCounter()
local newPosTime = 0

local glideSlopePNG

--------------------------------------------------------------------------------

--------------------
-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimA.jsn")
  local obj = json.decode(file)cd 
  if(obj) then
    trans11 = obj[lng] or obj[obj.default]
  end
--]]
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select - done once at startup
-- Make separate lists for GPS (type 9) sensors since they require different processing

local function readSensors()

   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.type ~= 9 then
	    table.insert(sensorLalist, sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
-- don't auto assign gps alt
--	    if sensor.label == 'Altitude' and sensor.param == 6 then -- 
--	       AltitudeSe = #sensorLalist
--	       AltitudeSeId = sensor.id
--	       AltitudeSePa = sensor.param
--	    end	    	    
	 else
	    table.insert(GPSsensorLalist, sensor.label)
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)
	    -- these labels and params work for the Jeti MGPS .. not sure if params are same for the Xicoy FC
	    -- it uses GPSLat, GPSLon and GPSAlt as labels .. need to check the params and do the same for it
	    if sensor.label == 'Longitude' and sensor.param == 3 then
	       LongitudeSe = #GPSsensorLalist
	       LongitudeSeId = sensor.id
	       LongitudeSePa = sensor.param
	    end
	    if sensor.label == 'Latitude' and sensor.param == 2 then
	       LatitudeSe = #GPSsensorLalist
	       LatitudeSeId = sensor.id
	       LatitudeSePa = sensor.param
	    end
	    if sensor.label == 'Speed' and sensor.param == 8 then
	       SpeedGPSSe = #GPSsensorLalist
	       SpeedGPSSeId = sensor.id
	       SpeedGPSSePa = sensor.param
	    end
	    if sensor.label == 'Distance' and sensor.param == 7 then
	       DistanceGPSse = #GPSsensorLalist
	       DistanceGPSSeId = sensor.id
	       DistanceGPSSePa = sensor.param
	    end
	    if sensor.label == 'Course' and sensor.param == 10 then
	       CourseGPSse = #GPSsensorLalist
	       CourseGPSSeId = sensor.id
	       CourseGPSSePa = sensor.param
	    end
	 end
      end
   end
end

----------------------------------------------------------------------

-- Actions when settings changed


local function LatitudeSensorChanged(value)
   LatitudeSe = value
   LatitudeSeId = GPSsensorIdlist[LatitudeSe]
   LatitudeSePa = GPSsensorPalist[LatitudeSe]
   if (LatitudeSeId == "...") then
      LatitudeSeId = 0
      LatitudeSePa = 0 
   end
   system.pSave("LatitudeSe", value)
   system.pSave("LatitudeSeId", LatitudeSeId)
   system.pSave("LatitudeSePa", LatitudeSePa)
end

local function LongitudeSensorChanged(value)
   LongitudeSe = value
   LongitudeSeId = GPSsensorIdlist[LongitudeSe]
   LongitudeSePa = GPSsensorPalist[LongitudeSe]
   if (LongitudeSeId == "...") then
      LongitudeSeId = 0
      LongitudeSePa = 0 
   end
   system.pSave("LongitudeSe", value)
   system.pSave("LongitudeSeId", LongitudeSeId)
   system.pSave("LongitudeSePa", LongitudeSePa)
end

local function AltitudeSensorChanged(value)
  AltitudeSe = value
  AltitudeSeId = sensorIdlist[AltitudeSe]
  AltitudeSePa = sensorPalist[AltitudeSe]
  if (AltitudeSeId == "...") then
    AltitudeSeId = 0
    AltitudeSePa = 0 
  end
  system.pSave("AltitudeSe", value)
  system.pSave("AltitudeSeId", AltitudeSeId)
  system.pSave("AltitudeSePa", AltitudeSePa)
end

local function SpeedNonGPSSensorChanged(value)
  SpeedNonGPSSe = value
  SpeedNonGPSSeId = sensorIdlist[SpeedNonGPSSe]
  SpeedNonGPSSePa = sensorPalist[SpeedNonGPSSe]
  if (SpeedNonGPSSeId == "...") then
    SpeedNonGPSSeId = 0
    SpeedNonGPSSePa = 0 
  end
  system.pSave("SpeedNonGPSSe", value)
  system.pSave("SpeedNonGPSSeId", SpeedNonGPSSeId)
  system.pSave("SpeedNonGPSSePa", SpeedNonGPSSePa)
end

local function SpeedGPSSensorChanged(value)
  SpeedGPSSe = value
  SpeedGPSSeId = sensorIdlist[SpeedGPSSe]
  SpeedGPSSePa = sensorPalist[SpeedGPSSe]
  if (SpeedGPSSeId == "...") then
    SpeedGPSSeId = 0
    SpeedGPSSePa = 0 
  end
  system.pSave("SpeedGPSSe", value)
  system.pSave("SpeedGPSSeId", SpeedGPSSeId)
  system.pSave("SpeedGPSSePa", SpeedGPSSePa)
end

local function DistanceGPSSensorChanged(value)
  DistanceGPSSe = value
  DistanceGPSSeId = sensorIdlist[DistanceGPSSe]
  DistanceGPSSePa = sensorPalist[DistanceGPSSe]
  if (DistanceGPSSeId == "...") then
    DistanceGPSSeId = 0
    DistanceGPSSePa = 0 
  end
  system.pSave("DistanceGPSSe", value)
  system.pSave("DistanceGPSSeId", DistanceGPSSeId)
  system.pSave("DistanceGPSSePa", DistanceGPSSePa)
end

local function CourseGPSSensorChanged(value)
  CourseGPSSe = value
  CourseGPSSeId = sensorIdlist[CourseGPSSe]
  CourseGPSSePa = sensorPalist[CourseGPSSe]
  if (CourseGPSSeId == "...") then
    CourseGPSSeId = 0
    CourseGPSSePa = 0 
  end
  system.pSave("CourseGPSSe", value)
  system.pSave("CourseGPSSeId", CourseGPSSeId)
  system.pSave("CourseGPSSePa", CourseGPSSePa)
end

local function BaroAltSensorChanged(value)
  BaroAltSe = value
  BaroAltSeId = sensorIdlist[BaroAltSe]
  BaroAltSePa = sensorPalist[BaroAltSe]
  if (BaroAltSeId == "...") then
    BaroAltSeId = 0
    BaroAltSePa = 0 
  end
  system.pSave("BaroAltSe", value)
  system.pSave("BaroAltSeId", SpeedNonGPSSeId)
  system.pSave("BaroAltSePa", SpeedNonGPSSePa)
end

local function throttleControlChanged(value)
   throttleControl = value
   print("Throttle Control: ", throttleControl)
   system.pSave("throttleControl", value)
end

local function brakeControlChanged(value)
   brakeControl = value
   print("Brake Control: ", brakeControl)
   system.pSave("brakeControl", value)
end

local function magneticVarChanged(value)
   magneticVar = value
   system.pSave("magneticVar", value)
end

local function resetOriginChanged(value)
   resetClick = value
   if not resetClick then
      resetClick = true
      form.setValue(resetCompIndex, resetClick)
      resetOrigin=true
      timeRO = system.getTimeCounter()
      print("mem before: ", collectgarbage("count"))
      collectgarbage()
      print("mem after: ", collectgarbage("count"))
   end
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

  if (tonumber(system.getVersion()) >= 4.22) then

    form.addRow(2)
    form.addLabel({label="Select Pitot Speed Sensor", width=220})
    form.addSelectbox(sensorLalist, SpeedNonGPSSe, true, SpeedNonGPSSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select Baro Alt Sensor", width=220})
    form.addSelectbox(sensorLalist, BaroAltSe, true, BaroAltSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select Throttle Control", width=220})
    form.addInputbox(throttleControl, true, throttleControlChanged)

    form.addRow(2)
    form.addLabel({label="Select Brake Control", width=220})
    form.addInputbox(brakeControl, true, brakeControlChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Long Sensor", width=220})
    form.addSelectbox(GPSsensorLalist, LongitudeSe, true, LongitudeSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Lat Sensor", width=220})
    form.addSelectbox(GPSsensorLalist, LatitudeSe, true, LatitudeSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Alt Sensor", width=220})
    form.addSelectbox(sensorLalist, AltitudeSe, true, AltitudeSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Spd Sensor", width=220})
    form.addSelectbox(sensorLalist, SpeedGPSSe, true, SpeedGPSSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Dist", width=220})
    form.addSelectbox(sensorLalist, DistanceGPSSe, true, DistanceGPSSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Course", width=220})
    form.addSelectbox(sensorLalist, CourseGPSSe, true, CourseGPSSensorChanged)    

    form.addRow(2)
    form.addLabel({label="Local Magnetic Var (\u{B0}W)", width=220})
    form.addIntbox(magneticVar, -30, 30, -13, 0, 1, magneticVarChanged)
    
    form.addRow(2)
    form.addLabel({label="Reset GPS origin and Baro Alt", width=274})
    resetCompIndex=form.addCheckbox(resetClick, resetOriginChanged)
        
    form.addRow(1)
    form.addLabel({label="DFM - v."..LSOVersion.." ", font=FONT_MINI, alignRight=true})

  else

    form.addRow(1)
    form.addLabel({label="Please update, min. fw 4.22 required"})

  end
end
--------------------------------------------------------------------------------

-- Telemetry window draw functions

---------------------------------------------------------------------------------

local delta, deltaX, deltaY
local text

local colAH = 110 + 50
local rowAH = 63
local radAH = 62
local pitchR = radAH / 25
 

local colAlt = colAH + 73 + 45
local colSpeed = colAH - 73 - 45
local heightAH = 145

local colHeading = colAH
local rowHeading = 30 -- 160
local rowDistance = rowAH + radAH + 3

local T38Shape = {
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

local runwayShape = {
   {-2,-20},
   {-2, 20},
   { 2, 20},
   { 2,-20},
   {-2,-20}
}

local ILSshape = {
   {0,0,0,20},
   {0,0,-2,2},
   {0,0, 2,2},
   {0,2,-2,4},
   {0,2, 2,4},
   {0,4,-2,6},
   {0,4, 2,6}
}

-- local originShape = {
--    {1,3},
--    {1,1},
--    {3,1},
--    {3,-1},
--    {1,-1},
--    {1,-3},
--    {-1,-3},
--    {-1,-1},
--    {-3,-1},
--    {-3,1},
--    {-1,1},
--    {-1,3}
-- }


local originShape = {
   {2,6},
   {2,2},
   {6,2},
   {6,-2},
   {2,-2},
   {2,-6},
   {-2,-6},
   {-2,-2},
   {-6,-2},
   {-6,2},
   {-2,2},
   {-2,6}
}

-- *****************************************************
-- Draw a shape
-- *****************************************************

local function drawShape(col, row, shape, rotation)
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
   ren:renderPolygon()
end

local function drawShapePL(col, row, shape, rotation,scale, width, alpha)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren2:reset()
   for index, point in pairs(shape) do
      ren2:addPoint(
	 col + (scale*point[1] * cosShape - scale*point[2] * sinShape),
	 row + (scale*point[1] * sinShape + scale*point[2] * cosShape))
   end
   ren2:renderPolyline(width, alpha)
end

local function drawILS(col, row, rotation, scale)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   for index, point in pairs(ILSshape) do
      lcd.drawLine(col + (scale*point[1] * cosShape - scale*point[2] * sinShape),
		   row + (scale*point[1] * sinShape + scale*point[2] * cosShape),
		   col + (scale*point[3] * cosShape - scale*point[4] * sinShape),
		   row + (scale*point[3] * sinShape + scale*point[4] * cosShape))      
      
   end
end

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   xr = (x * cosShape - y * sinShape)
   yr = (x * sinShape + y * cosShape)
   return xr, yr
end

local function drawDistance()

   lcd.setColor(txtr,txtg,txtb)
--[[
   if distance and distance > 0 then
      text =  string.format("%dm",distance)
      lcd.drawText(colAH + 16 - lcd.getTextWidth(FONT_NORMAL,text), rowAH + 10, text)
   end
--]]
   lcd.setColor(lcd.getFgColor())
   drawShape(colAH, rowAH+20, T38Shape, math.rad(heading-magneticVar))
end

-- *****************************************************
-- Draw altitude indicator
-- *****************************************************


-- *****************************************************
-- Vertical line parameters (to improve or supress)
-- *****************************************************

local parmLine = {
  {rowAH - 72, 7, 30},  -- +30
  {rowAH - 60, 3},      -- +25
  {rowAH - 48, 7, 20},  -- +20
  {rowAH - 36, 3},      -- +15
  {rowAH - 24, 7, 10},  --  +10
  {rowAH - 12 , 3},      --  +5
  {rowAH     , 7, 0},        --   0
  {rowAH + 12, 3},       --  -5
  {rowAH + 24, 7, -10}, -- -10
  {rowAH + 36, 3},      -- -15
  {rowAH + 48, 7, -20}, -- -20
  {rowAH + 60, 3},      -- -25
  {rowAH + 72, 7, -30}  -- -30
}

local function drawAltitude()
  lcd.setColor(txtr,txtg,txtb)
  delta = (altitude-baroAltZero) % 10
  deltaY = 1 + math.floor(2.4 * delta)  
  lcd.drawText(colAlt+2, heightAH+2, "ft", FONT_MINI)
  lcd.setClipping(colAlt-7,0,45,heightAH)
  --print("dA clipping: ", colAlt-7, 0, 45, heightAH)
  lcd.drawLine(7, -1, 7, heightAH)
  
  for index, line in pairs(parmLine) do
    lcd.drawLine(6 - line[2], line[1] + deltaY, 6, line[1] + deltaY)
    if line[3] then
      lcd.drawNumber(11, line[1] + deltaY - 8, altitude-baroAltZero+0.5 + line[3] - delta, FONT_NORMAL)
    end
  end

  text = string.format("%d",altitude-baroAltZero)
  lcd.drawFilledRectangle(11,rowAH-8,42,lcd.getTextHeight(FONT_NORMAL))

  lcd.setColor(255-txtr,255-txtg,255-txtb)
  lcd.drawText(12, rowAH-8, text, FONT_NORMAL | FONT_XOR)
  lcd.resetClipping()
end


-- *****************************************************
-- Draw speed indicator
-- *****************************************************

local function drawSpeed() 
  lcd.setColor(txtr,txtg,txtb)
  delta = speed % 10
  deltaY = 1 + math.floor(2.4 * delta)
--  print('speed, delta, deltaY', speed, delta, deltaY)
  lcd.drawText(colSpeed-30, heightAH+2, "mph", FONT_MINI)

  lcd.setClipping(colSpeed-37,0,45,heightAH)
  --print("dS clipping: ", colSpeed-37, 0, 45, heightAH)
  
  lcd.drawLine(37, -1, 37, heightAH)
  for index, line in pairs(parmLine) do
--     print ("l1+dy: ", line[1]+deltaY)
     
     lcd.drawLine(38, line[1] + deltaY, 38 + line[2], line[1] + deltaY)
     if line[3] then
	text = string.format("%d",speed+0.5 + line[3] - delta)
	lcd.drawText(35 - lcd.getTextWidth(FONT_NORMAL,text), line[1] + deltaY - 8, text, FONT_NORMAL)
     end
  end
  
  text = string.format("%d",speed)
  lcd.drawFilledRectangle(0,rowAH-8,35,lcd.getTextHeight(FONT_NORMAL))
  lcd.setColor(255-txtr,255-txtg,255-txtb)
  lcd.drawText(35 - lcd.getTextWidth(FONT_NORMAL,text), rowAH-8, text, FONT_NORMAL | FONT_XOR)
  lcd.resetClipping() 
end



-- *****************************************************
-- Draw heading indicator
-- *****************************************************

local parmHeading = {
  {0, 2, "N"}, {30, 5}, {60, 5},
  {90, 2, "E"}, {120, 5}, {150, 5},
  {180, 2, "S"}, {210, 5}, {240, 5},
  {270, 2, "W"}, {300, 5}, {330, 5}
}

local wrkHeading = 0
local w
local p1,p2,p3,p4
local c1,c2,c3,c4
local ii=0

local function drawHeading()

   ii = ii + 1

   lcd.setColor(txtr,txtg,txtb)

--[[
   p1,p2,p3,p4=system.getInputs("P5", "P6", "P7", "P8")

   c1 = math.floor((p1+1)*160)
   c2 = math.floor((p2+1)*80)
   c3 = math.floor((p3+1)*160)
   c4 = math.floor((p4+1)*80)
   
   lcd.setClipping(c1,c2,c3,c4)

   if ii > 50 then
      print(c1,c2,c3,c4)
      ii = 0
   end
--]]
   
   lcd.drawFilledRectangle(colHeading-70, rowHeading, 140, 2)
   lcd.drawFilledRectangle(colHeading+65, rowHeading-20, 6,22)
   lcd.drawFilledRectangle(colHeading-65-6, rowHeading-20, 6,22)

   for index, point in pairs(parmHeading) do
      wrkHeading = point[1] - heading
      if wrkHeading > 180 then wrkHeading = wrkHeading - 360 end
      if wrkHeading < -180 then wrkHeading = wrkHeading + 360 end
      deltaX = math.floor(wrkHeading / 1.6 + 0.5) - 1 -- was 2.2
      
      if deltaX >= -64 and deltaX <= 62 then -- was 31
	 if point[3] then
	    lcd.drawText(colHeading + deltaX - 4, rowHeading - 16, point[3], FONT_NORMAL)
	    --print("dT: ", colHeading + deltaX-4, rowHeading-16, point[3])
	 end
	 if point[2] > 0 then
	    lcd.drawLine(colHeading + deltaX, rowHeading - point[2], colHeading + deltaX, rowHeading)
	 end
      end
   end 
   
   local tyH = type(heading)
   if tyH ~= 'number' then
      print('non number type to format heading, type, heading')
      print(tyH, heading)
   end
   
   text = string.format("%03d",heading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   lcd.setColor(txtr,txtg,txtb)
   lcd.drawFilledRectangle(colHeading - w/2, rowHeading-30, w, lcd.getTextHeight(FONT_NORMAL))
   lcd.setColor(255-txtr,255-txtg,255-txtb)
   lcd.drawText(colHeading - w/2,rowHeading-30,text,  FONT_XOR)
   
   lcd.resetClipping()
end


local bgr,bgg,bgb
local alphadot
local function mixBgColor(r,g,b,alpha)
  bgr,bgg,bgb = lcd.getBgColor()
  alphadot = 1 - alpha
  r = bgr*alphadot + r*alpha
  g = bgg*alphadot + g*alpha
  b = bgb*alphadot + b*alpha
  return r,g,b
end

--- draw Vario (vvi) 

local rowVario = 80
local colVario = 260

local function drawVario()

   local r,g,b = lcd.getFgColor()
   lcd.setColor(r,g,b)

   for i = -60, 60, 30 do
      lcd.drawLine(colVario-7, rowVario+i, colVario+8, rowVario+i)
   end
   lcd.drawFilledRectangle(colVario-9, rowVario, 20, 3)

   lcd.drawText(colVario-10, heightAH+2, "fpm", FONT_MINI)

   lcd.drawFilledRectangle(colVario-48,rowAH-8,38,lcd.getTextHeight(FONT_NORMAL))
   lcd.setColor(255-txtr,255-txtg,255-txtb)
   local text = string.format("%d", math.floor(vario*0.1+0.5)/0.1)
   lcd.drawText(colVario-12- lcd.getTextWidth(FONT_NORMAL,text), rowAH-8, text, FONT_NORMAL | FONT_XOR)

   lcd.setColor(r,g,b)  
   if(vario > 1200) then vario = 1200 end
   if(vario < -1200) then vario = -1200 end
   if (vario > 0) then 
      lcd.drawFilledRectangle(colVario-4,rowVario-math.floor(vario/16.66 + 0.5),10,math.floor(vario/16.66+0.5),170)
   elseif(vario < 0) then 
      lcd.drawFilledRectangle(colVario-4,rowVario+1,10,math.floor(-vario/16.66 + 0.5), 170)
   end
end

local function toXPixel(coord, min, range, width)
   local pix
   pix = (coord - min)/range * width
--   pix = (pix*0.98125) + 3
   return pix
end


local function toYPixel(coord, min, range, height)
   local pix
   --print('toYP: ', coord, min, range, height)
   pix = height-(coord - min)/range * height
--   pix = (pix*0.98125) + 3
   return pix
end

-- 'local globals' shared by ilsPrint and mapPrint .. maybe just for testing?

--[[
local xr1,yr1, xr2, yr2 = xTakeoffStart, yTakeoffStart, 2*xTakeoffStart, yTakeoffStart - 50
local xl1,yl1, xl2, yl2 = xTakeoffStart, yTakeoffStart, 2*xTakeoffStart, yTakeoffStart + 50local xTSr, yTSr
local xTCr, yTCr
local xr1r, yr1r
local xr2r, yr2r
local xl1r, yl1r
local xl2r, yl2r
--]]

local function fslope(x, y)

    local xbar, ybar, sxy, sx2 = 0,0,0,0
    
    for i = 1, #x do
       xbar = xbar + x[i]
       ybar = ybar + y[i]
    end

    xbar = xbar/#x
    ybar = ybar/#y

    for i = 1, #x do
        sxy = sxy + (x[i]-xbar)*(y[i]-ybar)
        sx2 = sx2 + (x[i] - xbar)^2
    end
    
    if sx2 < 1.0E-6 then -- would it be more proper to set slope to inf and let atan do its thing?
       sx2 = 1.0E-6      -- or just let it div0 and set to inf itself?
    end                  -- for now this is only a .00001-ish degree error
    
    slope = sxy/sx2
    
    theta = math.atan(slope)
    tt=0
    if x[1] < x[#x] then
       tt = math.pi/2 - theta
    else
       tt = math.pi*3/2 - theta
    end
 
    return slope, tt
end

-- these variables are shared by mapPrint and ilsPrint

local xr1,yr1, xr2, yr2
local xl1,yl1, xl2, yl2


local function ilsPrint(windowWidth, windowHeight)

   local xc = 155
   local yc = 79
   local aa, mm
   local hyp, perpd, d2r, cdi
   local dr, dl
   local dx, dy=0,0
   local vA=0
   local rrad
   local dd
   
   r, g, b = lcd.getFgColor()
   lcd.setColor(r, g, b)
   
   lcd.drawImage( (310-glideSlopePNG.width)/2+1,10, glideSlopePNG)
   lcd.drawLine (60, yc, 250, yc) -- horiz axis
   lcd.drawLine (xc,1,xc,159)  -- vert axis

   drawSpeed()
   drawAltitude()
   drawVario()   

   -- First compute determinants to see what side of the right and left lines we are on
   -- ILS course is between them -- also compute which side of the course we are on

   if #xtable >=1  and RunwayHeading then
 
      xTS = xTakeoffStart -- redundant .. fix code below
      yTS = yTakeoffStart
      xTC = xTakeoffComplete
      yTC = yTakeoffComplete

      dr = (xtable[#xtable]-xr1)*(yr2-yr1) - (ytable[#ytable]-yr1)*(xr2-xr1)
      dl = (xtable[#xtable]-xl1)*(yl2-yl1) - (ytable[#ytable]-yl1)*(xl2-xl1)
      dc = (xtable[#xtable]-xTS)*(yTC-yTS) - (ytable[#ytable]-yTS)*(xTC-xTS)
      
      hyp = math.sqrt( (ytable[#ytable]-yTC)^2 + (xtable[#xtable]-xTC)^2 )

      if dl >= 0 and dr <= 0 and math.abs(hyp) > 0.1 then

	 perpd  = math.abs((yTC-yTS)*xtable[#xtable] - (xTC-xTS)*ytable[#ytable]+xTC*yTS-yTC*xTS) / hyp
	 dd = hyp^2 - perpd^2
	 if dd < 0.1 then dd = 0.1 end
	 d2r = math.sqrt(dd)
	 rA = math.deg(math.atan(perpd, d2r))
	 vA = math.deg(math.atan(altitude-baroAltZero, d2r))

	 if vA > 89.9 then vA = 89.9 end
	 if vA < -89.9 then vA = -89.9 end
	 if rA > 89.9 then rA = 89.9 end
	 if rA < -89.9 then rA = -89.9 end
	    
	
	 --print('d2r, altitude, vA', d2r, altitude, vA)
	 --print('hyp, perpd, d2r, rA: ', hyp, perpd, d2r, rA)
	 
	 if dc> 0 then dx = rA*-12 else dx=rA*12 end
	 dy = (vA-3)*12
	 if dy > 60 then dy = 60 end
	 if dy < -60 then dy = -60 end
      else
	 dx=0
	 dy=0
      end

            
      lcd.setColor(lcd.getFgColor())
   
      -- draw no bars if not in the ILS zone

      if dl >= 0 and dr <= 0 then
	 -- first the horiz bar
	 lcd.setColor(255,0,0) -- red bars for now
	 lcd.drawFilledRectangle(xc-55, yc-2+dy, 110, 4)
	 -- now vertical bar and glideslope angle display
	 local text = string.format("%.0f", math.floor(vA/0.01+5)*.01)
	 lcd.drawFilledRectangle(52,rowAH-8,lcd.getTextWidth(FONT_NORMAL, text)+8,lcd.getTextHeight(FONT_NORMAL))
	 lcd.drawFilledRectangle(xc-2+dx,yc-55, 4, 110)
	 lcd.setColor(255,255,255) -- white text for vertical angle box
	 lcd.drawText(56, rowAH-8, text, FONT_NORMAL | FONT_XOR)

      end
   end
      
   
   lcd.setColor(txtr,txtg,txtb)
   text = string.format("%03d",heading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   lcd.drawFilledRectangle(xc - w/2,0 , w, lcd.getTextHeight(FONT_NORMAL))
   lcd.setColor(255-txtr,255-txtg,255-txtb)
   lcd.drawText(xc - w/2,0,text,  FONT_XOR)

   if RunwayHeading then
      lcd.setColor(txtr,txtg,txtb)
      local distFromTO = math.sqrt( (xtable[#xtable] - xTakeoffStart)^2 + (ytable[#ytable] - yTakeoffStart)^2)
      text = string.format("%d",distFromTO)
      w = lcd.getTextWidth(FONT_NORMAL,text) 
      lcd.drawFilledRectangle(xc - w/2,143 , w, lcd.getTextHeight(FONT_NORMAL))
      lcd.setColor(255-txtr,255-txtg,255-txtb)
      lcd.drawText(xc - w/2,143,text,  FONT_XOR)
   end
end


   
local function mapPrint(windowWidth, windowHeight)

   local xpix, ypix
   local r, g, b
   local ss, ww
   local d1, d2
   local xRW, yRW
   local scale
   local lRW
   local phi
   local radpt
   
   r, g, b = lcd.getFgColor()
   lcd.setColor(r, g, b)

   drawSpeed()
   drawAltitude()
   drawHeading()
--   drawDistance()
   drawVario()

   -- lcd.drawCircle(toXPixel(0, mapXmin, mapXrange, windowWidth), toYPixel(0, mapYmin, mapYrange, windowHeight), 5)

   drawShape(toXPixel(0, mapXmin, mapXrange, windowWidth),
	     toYPixel(0, mapYmin, mapYrange, windowHeight),
	     originShape, 0)

	 
   if xTakeoffStart then
      lcd.drawCircle(toXPixel(xTakeoffStart, mapXmin, mapXrange, windowWidth),
		     toYPixel(yTakeoffStart, mapYmin, mapYrange, windowHeight), 4)
   end
   
   if xTakeoffComplete then
      lcd.drawCircle(toXPixel(xTakeoffComplete, mapXmin, mapXrange, windowWidth),
		     toYPixel(yTakeoffComplete, mapYmin, mapYrange, windowHeight), 4)
      xRW = (xTakeoffComplete - xTakeoffStart)/2 + xTakeoffStart 
      yRW = (yTakeoffComplete - yTakeoffStart)/2 + yTakeoffStart
      -- lcd.drawCircle(toXPixel(xRW, mapXmin, mapXrange, windowWidth), toYPixel(yRW, mapYmin, mapYrange, windowHeight), 2)
      lRW = math.sqrt((xTakeoffComplete-xTakeoffStart)^2 + (yTakeoffComplete-yTakeoffStart)^2)
      scale = (lRW/mapXrange)*(windowWidth/40) -- rw shape is 40 units long
      lcd.setColor(0,240,0)
      drawShapePL(toXPixel(xRW, mapXmin, mapXrange, windowWidth),
		  toYPixel(yRW, mapYmin, mapYrange, windowHeight), runwayShape, math.rad(RunwayHeading-magneticVar), scale, 2, 255)
      --local recipHDG = (RunwayHeading + 180)%360
      drawILS (toXPixel(xTakeoffStart, mapXmin, mapXrange, windowWidth),
	       toYPixel(yTakeoffStart, mapYmin, mapYrange, windowHeight), math.rad(RunwayHeading-magneticVar), scale)


      lcd.setColor(r,g,b)

      local text=string.format("Map: %d x %d    Rwy: %d", mapXrange, mapYrange, math.floor(RunwayHeading/10+.5) )
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)

   else

      local text=string.format("Map: %d x %d", mapXrange, mapYrange)
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)

   end

   if RunwayHeading then
      phi = (90-(RunwayHeading-magneticVar)+360)%360
      -- todo: pre-calculate these trig values .. do it once for efficiency  --
      xr1 = xTakeoffComplete - lRW/2 * math.cos(math.rad(phi-12))
      yr1 = yTakeoffComplete - lRW/2 * math.sin(math.rad(phi-12))
      
      xr2 = xTakeoffComplete - lRW * math.cos(math.rad(phi-12))
      yr2 = yTakeoffComplete - lRW * math.sin(math.rad(phi-12))

      xl1 = xTakeoffComplete - lRW/2 * math.cos(math.rad(phi+12))
      yl1 = yTakeoffComplete - lRW/2 * math.sin(math.rad(phi+12))
      
      xl2 = xTakeoffComplete - lRW * math.cos(math.rad(phi+12))
      yl2 = yTakeoffComplete - lRW * math.sin(math.rad(phi+12))
      
      lcd.drawCircle(toXPixel(xr1, mapXmin, mapXrange, windowWidth), toYPixel(yr1, mapYmin, mapYrange, windowHeight), 3)      
      lcd.drawCircle(toXPixel(xl1, mapXmin, mapXrange, windowWidth), toYPixel(yl1, mapYmin, mapYrange, windowHeight), 3)
      
      lcd.drawCircle(toXPixel(xr2, mapXmin, mapXrange, windowWidth), toYPixel(yr2, mapYmin, mapYrange, windowHeight), 3)      
      lcd.drawCircle(toXPixel(xl2, mapXmin, mapXrange, windowWidth), toYPixel(yl2, mapYmin, mapYrange, windowHeight), 3)

   end
   
   for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute 
      
      -- First compute determinants to see what side of the right and left lines we are on
      -- ILS course is between them
      if RunwayHeading then
	 dr = (xtable[i]-xr1)*(yr2-yr1) - (ytable[i]-yr1)*(xr2-xr1)
	 dl = (xtable[i]-xl1)*(yl2-yl1) - (ytable[i]-yl1)*(xl2-xl1)
     
	 if dl >= 0 and dr <= 0 then
	    lcd.setColor(0,255,0)
	 end
      end
      
      if i==#xtable then
	 lcd.setColor(lcd.getFgColor())
	 -- drawShape(colAH, rowAH+20, T38Shape, math.rad(heading-magneticVar))
	 drawShape(toXPixel(xtable[i], mapXmin, mapXrange, windowWidth),
		   toYPixel(ytable[i], mapYmin, mapYrange, windowHeight),
		   T38Shape, math.rad(heading-magneticVar))
      else
	 radpt = 1
	 lcd.drawCircle(toXPixel(xtable[i], mapXmin, mapXrange, windowWidth),
			toYPixel(ytable[i], mapYmin, mapYrange, windowHeight),
			radpt)
      end
      

      
      lcd.setColor(r, g, b)
      
   end
end


local function loop()

   local minutes, degs
   local x, y, xyslope
   local oldXrange, oldYrange
   local MAXTABLE = 20
   local MAXVVITABLE = 15 -- points to fit to compute vertical speed -- 3 seconds at 0.2 sec sample
   local PATTERNALT = 200
   local xExp, yExp, maxExp, minExp
   local tt
   local hasPitot
   local hasCourseGPS
   local sensor
   local adelta = 0.1
   local tA
   local goodlat, goodlong 
   local brk, thr
   local newpos
   local deltaPosTime = 1000 -- min sample interval in ms
   local baroAlt, GPSAlt
   
   goodlat = false
   goodlong = false
   
   if resetOrigin and (system.getTimeCounter() > (timeRO+300)) then
      gotInitPos = false
      resetOrigin=false
      resetClick = false
      form.setValue(resetCompIndex, resetClick) -- prob should double check same form still displayed...

      -- reset map window too
      mapXmax=   200
      mapXmin = -200
      mapYmax =  100
      mapYmin = -100
      
      xmin = mapXmin
      xmax = mapXmax
      ymin = mapYmin
      ymax = mapYmax
      
      --reset baro alt zero too
      baroAltZero = altitude

      print("Zero-d origin and baro alt. baroAltZero: ", baroAltZero)

      --io.close(ff)
   end

   if DEBUG then
      debugTime =debugTime + 0.01/2*(system.getInputs("P7")+1)
--      speed = 40 + 80 * (math.sin(.3*debugTime) + 1)
      altitude = 20 + 200 * (math.cos(.3*debugTime)+1)
      x = 600*math.sin(2*debugTime)
      y = 300*math.cos(3*debugTime)
      goto computedXY
   end
   
   sensor = system.getSensorByID(LongitudeSeId, LongitudeSePa)

   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative (NESW coded in decimal places as 0,1,2,3)
	 longitude = longitude * -1
      end
      goodlong = true
   end
   
   sensor = system.getSensorByID(LatitudeSeId, LatitudeSePa)

   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
      if sensor.decimals == 2 then -- "South" .. make it negative
	 latitude = latitude * -1
      end
      goodlat = true
   end
   
   sensor = system.getSensorByID(AltitudeSeId, AltitudeSePa)

   if(sensor and sensor.valid) then
      GPSAlt = sensor.value*3.28084 -- convert to ft, telem apis only report native values
   end
   
   sensor = system.getSensorByID(SpeedNonGPSSeId, SpeedNonGPSSePa)
   
   hasPitot = false
   if(sensor and sensor.valid) then
      if sensor.unit == "kmh" or sensor.unit == "km/h" then
	 SpeedNonGPS = sensor.value * 0.621371 -- unit conversion to mph
      end
      if sensor.unit == "m/s" then
	 SpeedNonGPS = sensor.value * 2.23694
      end
      
      hasPitot = true
   end
   
   sensor = system.getSensorByID(BaroAltSeId, BaroAltSePa)
   
   if(sensor and sensor.valid) then
      baroAlt = sensor.value * 3.28084 -- unit conversion m to ft
   end
   
   
   sensor = system.getSensorByID(SpeedGPSSeId, SpeedGPSSePa)
   
   if(sensor and sensor.valid) then
      if sensor.unit == "kmh" or sensor.unit == "km/h" then
	 SpeedGPS = sensor.value * 0.621371 -- unit conversion to mph
      end
      if sensor.unit == "m/s" then
	 SpeedGPS = sensor.value * 2.23694
      end
   end
   
   sensor = system.getSensorByID(DistanceGPSSeId, DistanceGPSSePa)
   
   if(sensor and sensor.valid) then
      DistanceGPS = sensor.value*3.2808
   end      
   
   hasCourseGPS = false
   sensor = system.getSensorByID(CourseGPSSeId, CourseGPSSeId)
   if sensor and sensor.valid then
      courseGPS = sensor.value
      hasCourseGPS = true
   end
   
   -- only recompute when lat and long have changed
   
   if not latitude or not longitude then
--      print('returning: lat or long is nil')
      return
   end
   if not goodlat or not goodlong then
--      print('returning: goodlat, goodlong: ', goodlat, goodlong)
      return
   end

   if not DEBUG then
      if GPSAlt then
	 altitude = GPSAlt
      end
      if baroAlt then -- let baroAlt "win" if both defined
	 altitude = baroAlt
      end
   end

   -- Xicoy FC sends a lat/long of 0,0 on startup .. don't use it
   if math.abs(latitude) < 1 then
      -- print("Latitude < 1: ", latitude, longitude, goodlat, goodlong)
      return
   end

   -- Jeti MGPS sends a reading of 240N, 48E on startup .. don't use it
   if latitude > 239 then
      -- print("Latitude > 239: ", latitude, longitude, goodlat, goodlong)
      return
   end 

   -- throw away first 10 GPS readings to let unit settle
   numGPSreads = numGPSreads + 1
   if numGPSreads < 10 then 
      print("Discarding reading: ", numGPSreads, latitude, longitude, goodlat, goodlong)
      return
   end
   
   if (latitude == lastlat and longitude == lastlong) or (system.getTimeCounter() < newPosTime) then
      newpos = false
   else
      newpos = true
      lastlat = latitude
      lastlong = longitude
      newPosTime = system.getTimeCounter() + deltaPosTime
   end
   
   if not gotInitPos then
      long0 = longitude
      lat0 = latitude
      coslat0 = math.cos(math.rad(lat0))
      gotInitPos = true
   end

   if newpos then
      if x and y then
	 oldx = x
	 oldy = y
      else
	 oldx=0
	 oldy=0
      end
   end
   
   x = rE*(longitude-long0)*coslat0/rad
   y = rE*(latitude-lat0)/rad
   
   -- update overall min and max for drawing the GPS
   -- maintain same pixel size (in feet) in X and Y (screen is 320x160)
   -- map?xxxx are all in ft .. convert to pixels in telem draw function
   
   ::computedXY::   

   -- print('lat,long,x,y: ', latitude, longitude, x, y)
   
-- was failing on startup .. fix at some point to defend against rogue points
--   if math.abs(oldx-x) > 10000 or math.abs(oldy-y) > 10000 then
--      print('bailing on bad xy')
--      return
--  end
      
   --tt = system.getTimeCounter()/1000
   --ss1 = string.format("%.2f, %.0f, %.0f, %.0f, %.0f, %.0f, %.0f", tt, mapXmin, mapXmax, mapYmin, mapYmax, mapXrange, mapYrange)
   --print(ss1)

   if newpos or DEBUG then -- only enter a new xy in the "comet tail" if lat/lon changed
      
      if #xtable+1 > MAXTABLE then
	 table.remove(xtable, 1)
	 table.remove(ytable, 1)
      end
      
      table.insert(xtable, x)
      table.insert(ytable, y)
      
      if not DEBUG then
	 print('long,lat, x, y, alt', longitude, latitude, x, y, altitude)
      end
      
      if not mapXmax then
	 mapXmax=   200
	 mapXmin = -200
	 mapYmax =  100
	 mapYmin = -100
      end

      if #xtable == 1 then
	 xmin = mapXmin
	 xmax = mapXmax
	 ymin = mapYmin
	 ymax = mapYmax
      end
      
      if x > xmax then xmax = x end
      if x < xmin then xmin = x end
      if y > ymax then ymax = y end
      if y < ymin then ymin = y end
      
      local xspan = (xmax-xmin) 
      local yspan = (ymax-ymin)

      mapXrange = math.floor(xspan/200 + .5) * 200 -- telemetry screens are 320x160 or 2:1
      mapYrange = math.floor(yspan/100 + .5) * 100
      
      if mapYrange > mapXrange/(2) then
	 mapXrange = mapYrange*(2)
      end
      if mapXrange > mapYrange*(2) then
	 mapYrange = mapXrange/(2)
      end
      
      mapXmin = xmin - (mapXrange - xspan)/2
      mapXmax = xmax + (mapXrange - xspan)/2
      
      mapYmin = ymin - (mapYrange - yspan)/2
      mapYmax = ymax + (mapYrange - yspan)/2 
   
      if #xtable > lineAvgPts then
	 xyslope, compcrs = fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
				   table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {}))
      else
	 xyslope = 0
	 compcrs = 0
      end
   
      compcrsDeg = compcrs*180/math.pi
   end
   
   tt = system.getTimeCounter() - sysTimeStart

   if tt > vviSlopeTime then
      if #vviTim + 1 > MAXVVITABLE then
	 table.remove(vviTim, 1)
	 table.remove(vviAlt, 1)
      end
      table.insert(vviTim, #vviTim+1, tt/60000.)
      table.insert(vviAlt, #vviAlt+1, altitude) -- no need to consider baroAltZero here, just a slope
      
      vvi, va = fslope(vviTim, vviAlt)
      --print('tt/60000, altitude, vvi, va: ', tt/60000., altitude, vvi, va)
      vario = 0.8*vario + 0.2*vvi -- light smoothing

      vviSlopeTime = tt + 300. -- next data point in 0.3 sec
   end

   if tt > speedTime then
      if not xd1 and not yd1 then
	 xd1=x
	 yd1=y
	 td1 =system.getTimeCounter()/1000
	 speed = 0
	 --print('init speed', xd1, yd1, td1)
	 speedTime = tt + 2000
      else
	 xd2=x
	 yd2=y
	 td2=system.getTimeCounter()/1000
	 dd = math.sqrt( (xd2-xd1)^2 + (yd2-yd1)^2 )
	 xd1=x
	 yd1=y
	 speed = 0.7*speed + 0.3*dd*0.681818/(td2-td1) -- speed is in ft/s .. convert to mph
	 td1 = td2
	 speedTime = tt + 2000 -- time to next reading in ms
      end
   end
   

   if DEBUG then
      heading = compcrsDeg + magneticVar
   else
      if hasCourseGPS and courseGPS then
	 heading = courseGPS + magneticVar
      else
	 if compcrsDeg then
	    heading = compcrsDeg + magneticVar
	 else
	    heading = 0
	 end
	    
      end
   end
   
   -- need to uppdate for speed computed from GPS
   
   if not DEBUG then
      if hasPitot and SpeedNonGPS ~= nil then
	 speed = SpeedNonGPS
      elseif SpeedGPS ~= nil then
	 speed = SpeedGPS
      end
   end
   
   -- ss2 = string.format("%.0f, %.0f, %.0f, %.0f, %.0f, %.0f", #xtable, x, y, altitude, heading, compcrsDeg)
   -- print(ss2)
   
   -- system.getInputs for thr and brake
   -- monitor brake release, throttle up, takeoff roll, actual takeoff

   if (brakeControl) then
      brk = system.getInputsVal(brakeControl)
   end
   if brk and brk < 0 and oldBrake > 0 then
      brakeReleaseTime = system.getTimeCounter()
      print("Brake release")
      system.playFile("brakes_released.wav", AUDIO_QUEUE)
   end
   if brk and brk > 0 then
      brakeReleaseTime = 0
      xTakeoffStart = nil  -- do we really want to erase the runway when the brakes go back on?
      xTakeoffComplete = nil
      RunwayHeading = nil
   end
   if brk  then
      oldBrake = brk
      if DEBUG and brk < 0 then altitude = altitude + .15 end ------------------- DEBUG only
   end
   
   if (throttleControl) then
      thr = system.getInputsVal(throttleControl)
   end
   if thr and thr > 0 and oldThrottle < 0 then
      if system.getTimeCounter() - brakeReleaseTime < 5000 then
	 xTakeoffStart = x
	 yTakeoffStart = y
	 zTakeoffStart = altitude-baroAltZero
	 ReleaseHeading = compcrsDeg + magneticVar
	 print("Takeoff Start")
--	 print("Brake Release Heading: ", ReleaseHeading)
	 system.playFile("starting_takeoff_roll.wav", AUDIO_QUEUE)
      end
   end
   if thr then oldThrottle = thr end
   
   if thr and thr > 0 and xTakeoffStart and neverAirborne then
      if (altitude - baroAltZero) - zTakeoffStart > PATTERNALT/2 then
	 neverAirborne = false
	 xTakeoffComplete = x
	 yTakeoffComplete = y
	 zTakeoffComplete = altitude - baroAltZero
	 TakeoffHeading = compcrsDeg + magneticVar
	 local _, rDeg  = fslope({xTakeoffStart, xTakeoffComplete}, {yTakeoffStart, yTakeoffComplete})
	 RunwayHeading = math.deg(rDeg) + magneticVar
--	 print("Takeoff Complete:", system.getTimeCounter(), TakeoffHeading, xTakeoffComplete, yTakeoffComplete)
--	 print("Takeoff Heading: ", TakeoffHeading)
--	 print("Runway heading: ", RunwayHeading)
	 print("Runway length: ", math.sqrt((xTakeoffComplete-xTakeoffStart)^2 + (yTakeoffComplete-yTakeoffStart)^2))
--	 print("atan2: ", math.deg(math.atan( (xTakeoffComplete-xTakeoffStart), (yTakeoffComplete-yTakeoffStart))))
	 system.playFile("takeoff_complete.wav", AUDIO_QUEUE)
	 system.playNumber(heading, 0, "\u{B0}")
      end
   end
   

   --if ff then
     -- io.write(ff,ss1..', '..ss2.."\n")
   --end

   local newLoopTime = system.getTimeCounter()
   local loopDelta = newLoopTime - lastLoopTime
   
   lastLoopTime = newLoopTime
   
   if avgLoopTime ~=0 then
      avgLoopTime = avgLoopTime * 0.95 + 0.05* loopDelta
   else
      avgLoopTime = 1
   end
   
   loopCount = loopCount+1
   
   if loopCount > 100 then
      loopCount = 0
      -- print('TimA: Avg Loop Time: ', avgLoopTime)
   end
end

local function init()

   --ff=io.open("gpsILS.dat", "w")
   --print("ff is: ", ff)

   LatitudeSe      = system.pLoad("LatitudeSe", 0)
   LatitudeSeId    = system.pLoad("LatitudeSeId", 0)
   LatitudeSePa    = system.pLoad("LatitudeSePa", 0)
   
   LongitudeSe     = system.pLoad("LongitudeSe", 0)
   LongitudeSeId   = system.pLoad("LongitudeSeId", 0)
   LongitudeSePa   = system.pLoad("LongitudeSePa", 0)
   
   AltitudeSe      = system.pLoad("AltitudeSe", 0)
   AltitudeSeId    = system.pLoad("AltitudeSeId", 0)
   AltitudeSePa    = system.pLoad("AltitudeSePa", 0)        

   SpeedNonGPSSe   = system.pLoad("SpeedNonGPSSe", 0)
   SpeedNonGPSSeId = system.pLoad("SpeedNonGPSSeId", 0)
   SpeedNonGPSSePa = system.pLoad("SpeedNonGPSSePa", 0)

   BaroAltSe   = system.pLoad("BaroAltSe", 0)
   BaroAltSeId = system.pLoad("BaroAltSeId", 0)
   BaroAltSePa = system.pLoad("BaroAltSePa", 0)
   
   SpeedGPSSe      = system.pLoad("SpeedGPSSe", 0)
   SpeedGPSSeId    = system.pLoad("SpeedGPSSeId", 0)
   SpeedGPSSePa    = system.pLoad("SpeedGPSSePa", 0)        

   DistanceGPSSe   = system.pLoad("DistanceGPSSe", 0)
   DistanceGPSSeId = system.pLoad("DistanceGPSSeId", 0)
   DistanceGPSSePa = system.pLoad("DistanceGPSSePa", 0)

   CourseGPSSe   = system.pLoad("CourseGPSSe", 0)
   CourseGPSSeId = system.pLoad("CourseGPSSeId", 0)
   CourseGPSSePa = system.pLoad("CourseGPSSePa", 0)        
   
   throttleControl = system.pLoad("throttleControl")
   brakeControl    = system.pLoad("brakeControl")
   magneticVar     = system.pLoad("magneticVar", 13)

   system.registerForm(1, MENU_APPS, "Landing Signal Officer", initForm, nil, nil)
   system.registerTelemetry(1, "LSO Map", 4, mapPrint)
   system.registerTelemetry(2, "LSO ILS", 4, ilsPrint)
   glideSlopePNG = lcd.loadImage("Img/glideslope.png")
    
   system.playFile('L_S_O_active.wav', AUDIO_QUEUE)
   
   if DEBUG then
      print('L_S_O_Active.wav')
   end
    readSensors()
    collectgarbage()
end


LSOVersion = "1.0"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=LSOVersion, name="GPS LSO"}
