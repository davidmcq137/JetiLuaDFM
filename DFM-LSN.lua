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
local baroAlt, GPSAlt
local DistanceGPS, distance
local magneticVar
local rotationAngle

local xtable = {}
local ytable = {}
local MAXTABLE = 5
local bezierPath = {{x,y}}
local rwy = {{x,y}}
local poi = {{x,y}}
local geo = {}
local iField

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
local debugNext = 0
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

local TakeoffStart
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

local lastlat = 0
local lastlong = 0
local gotInitPos = false
local baroAltZero = 0
local long0, lat0, coslat0
local rE = 21220539.7  -- 6371*1000*3.28084 radius of earth in ft, fudge factor of 1/0.985
local rad = 180/math.pi
local compcrs
local heading, compcrsDeg = 0, 0
local vario=0
local lineAvgPts = 4  -- number of points to linear fit to compute course
local vviSlopeTime = 0
local speedTime = 0
local numGPSreads = 0
local timeRO = 0

local ren=lcd.renderer()

local txtr, txtg, txtb = 0,0,0

local ff, fd
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
  system.pSave("BaroAltSeId", BaroAltSeId)
  system.pSave("BaroAltSePa", BaroAltSePa)
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

local function rotationAngleChanged(value)
   rotationAngle = value
   system.pSave("rotationAngle", value)
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
    form.addLabel({label="Rotation (\u{B0}CCW)", width=220})
    form.addIntbox(rotationAngle, 0, 359, 0, 0, 1, rotationAngleChanged)    
    
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
 

local colAlt = colAH + 73 + 45
local colSpeed = colAH - 73 - 45
local heightAH = 145

local colHeading = colAH
local rowHeading = 30 -- 160

local shapes={} -- prob should move the shapes out to a jsn file

shapes.T38 = {
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

shapes.runway = {
   {-2,-20},
   {-2, 20},
   { 2, 20},
   { 2,-20},
   {-2,-20}
}

shapes.ILS = {
   {0,0,0,20},
   {0,0,-2,2},
   {0,0, 2,2},
   {0,2,-2,4},
   {0,2, 2,4},
   {0,4,-2,6},
   {0,4, 2,6}
}

shapes.origin = {
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

shapes.arrow = {
   {-3, -9},
   {0, -18},
   {3, -9}
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
   ren:reset()
   for index, point in pairs(shape) do
      ren:addPoint(
	 col + (scale*point[1] * cosShape - scale*point[2] * sinShape),
	 row + (scale*point[1] * sinShape + scale*point[2] * cosShape))
   end
   ren:renderPolyline(width, alpha)
end

local function drawILS(col, row, rotation, scale)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   for index, point in pairs(shapes.ILS) do
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
   drawShape(colAH, rowAH+20, shapes.T38, math.rad(heading-magneticVar))
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
local ii=0

local function drawHeading()

   ii = ii + 1

   lcd.setColor(txtr,txtg,txtb)

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
   return pix
end


local function toYPixel(coord, min, range, height)
   local pix
   pix = height-(coord - min)/range * height
   return pix
end

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
 

      dr = (xtable[#xtable]-xr1)*(yr2-yr1) - (ytable[#ytable]-yr1)*(xr2-xr1)
      dl = (xtable[#xtable]-xl1)*(yl2-yl1) - (ytable[#ytable]-yl1)*(xl2-xl1)
      dc = (xtable[#xtable]-xTakeoffStart)*(yTakeoffComplete-yTakeoffStart) -
	 (ytable[#ytable]-yTakeoffStart)*(xTakeoffComplete-xTakeoffStart)
      
      hyp = math.sqrt( (ytable[#ytable]-yTakeoffComplete)^2 + (xtable[#xtable]-xTakeoffComplete)^2 )

      if dl >= 0 and dr <= 0 and math.abs(hyp) > 0.1 then

	 perpd  = math.abs((yTakeoffComplete-yTakeoffStart)*xtable[#xtable] -
	       (xTakeoffComplete-xTakeoffStart)*ytable[#ytable]+xTakeoffComplete*yTakeoffStart-
	       yTakeoffComplete*xTakeoffStart) / hyp
	 dd = hyp^2 - perpd^2
	 if dd < 0.1 then dd = 0.1 end
	 d2r = math.sqrt(dd)
	 rA = math.deg(math.atan(perpd, d2r))
	 vA = math.deg(math.atan(altitude-baroAltZero, d2r))

	 if vA > 89.9 then vA = 89.9 end
	 if vA < -89.9 then vA = -89.9 end
	 if rA > 89.9 then rA = 89.9 end
	 if rA < -89.9 then rA = -89.9 end
	    
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
	 lcd.drawFilledRectangle(52,rowAH-8,lcd.getTextWidth(FONT_NORMAL, text)+8,
				 lcd.getTextHeight(FONT_NORMAL))
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

local function binom(n, k)
   
   -- compute binomial coefficients to then compute the Bernstein polynomials for Bezier

   if k > n then return nil end
   if k > n/2 then k = n - k end -- because (n k) = (n n-k) by symmetry
   
   numer, denom = 1, 1
   for i = 1, k do
      numer = numer * ( n - i + 1 )
      denom = denom * i
   end
   return numer / denom
end

local function computeBezier(numT)

   -- compute Bezier curve points using control points in xtable[], ytable[]
   -- with numT points over the [0,1] interval
   
   local px, py
   local t
   local n = #xtable-1
   
   for j = 0, numT, 1 do
      t = j / numT
      px, py = 0, 0
      for i = 0, n do
	 px = px + binom(n, i)*t^i*(1-t)^(n-i)*xtable[i+1]
	 py = py + binom(n, i)*t^i*(1-t)^(n-i)*ytable[i+1]
      end
      bezierPath[j+1] = {x=px, y=py}
   end
end

local function drawBezier(windowWidth, windowHeight)

   -- draw Bezier curve points computed in computeBezier()

   if not bezierPath[1].x  then return end

   ren:reset()

   for j=1, #bezierPath do
      ren:addPoint(toXPixel(bezierPath[j].x, mapXmin, mapXrange, windowWidth),
		   toYPixel(bezierPath[j].y, mapYmin, mapYrange, windowHeight))
   end
   ren:renderPolyline(3)

end

local function drawGeo(windowWidth, windowHeight)

   if not rwy[1].x then return end

   ren:reset()

   for j=1, #rwy do
      ren:addPoint(toXPixel(rwy[j].x, mapXmin, mapXrange, windowWidth),
		   toYPixel(rwy[j].y, mapYmin, mapYrange, windowHeight))
   end

   ren:renderPolyline(2)

   if not poi[1].x then return end
   
   for j=1, #poi do
      drawShape(toXPixel(poi[j].x, mapXmin, mapXrange, windowWidth),
		toYPixel(poi[j].y, mapYmin, mapYrange, windowHeight),
		shapes.origin, 0)
   end

end

   
local function mapPrint(windowWidth, windowHeight)

   local r, g, b
   local ss, ww
   local d1, d2
   local xRW, yRW
   local scale
   local lRW
   local phi
   local text
   
   r, g, b = lcd.getFgColor()
   lcd.setColor(r, g, b)

   drawSpeed()
   drawAltitude()
   drawHeading()
   drawVario()

   if xTakeoffStart then
      lcd.drawCircle(toXPixel(xTakeoffStart, mapXmin, mapXrange, windowWidth),
		     toYPixel(yTakeoffStart, mapYmin, mapYrange, windowHeight), 4)
   end
   
   if xTakeoffComplete then

      lcd.drawCircle(toXPixel(xTakeoffComplete, mapXmin, mapXrange, windowWidth),
		     toYPixel(yTakeoffComplete, mapYmin, mapYrange, windowHeight), 4)

      xRW = (xTakeoffComplete - xTakeoffStart)/2 + xTakeoffStart 
      yRW = (yTakeoffComplete - yTakeoffStart)/2 + yTakeoffStart
      lRW = math.sqrt((xTakeoffComplete-xTakeoffStart)^2 + (yTakeoffComplete-yTakeoffStart)^2)

      scale = (lRW/mapXrange)*(windowWidth/40) -- rw shape is 40 units long

      lcd.setColor(0,240,0)

      drawShapePL(toXPixel(xRW, mapXmin, mapXrange, windowWidth),
		  toYPixel(yRW, mapYmin, mapYrange, windowHeight),
		  shapes.runway, math.rad(RunwayHeading-magneticVar), scale, 2, 255)
      
      drawILS (toXPixel(xTakeoffStart, mapXmin, mapXrange, windowWidth),
	       toYPixel(yTakeoffStart, mapYmin, mapYrange, windowHeight),
	       math.rad(RunwayHeading-magneticVar), scale)


      lcd.setColor(r,g,b)

      text=string.format("Map: %d x %d    Rwy: %d", mapXrange, mapYrange, math.floor(RunwayHeading/10+.5) )
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)

   else

      local x = xtable[#xtable] or 0
      local y = ytable[#ytable] or 0

      text=string.format("Map: %d x %d", mapXrange, mapYrange)
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH-10, text, FONT_MINI)

      if iField then
	 text=geo.fields[iField].name
      else
	 text='Unknown Field'
      end
      
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)
            

   end

      
   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, "N") / 2, 14, "N", FONT_MINI)
   drawShape(70, 20, shapes.arrow, math.rad(-1*rotationAngle))
   lcd.drawCircle(70, 20, 7)

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
      
      lcd.drawCircle(toXPixel(xr1, mapXmin, mapXrange, windowWidth),
		     toYPixel(yr1, mapYmin, mapYrange, windowHeight), 3)      
      lcd.drawCircle(toXPixel(xl1, mapXmin, mapXrange, windowWidth),
		     toYPixel(yl1, mapYmin, mapYrange, windowHeight), 3)
      lcd.drawCircle(toXPixel(xr2, mapXmin, mapXrange, windowWidth),
		     toYPixel(yr2, mapYmin, mapYrange, windowHeight), 3)      
      lcd.drawCircle(toXPixel(xl2, mapXmin, mapXrange, windowWidth),
		     toYPixel(yl2, mapYmin, mapYrange, windowHeight), 3)

   end
   
   for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute 
      
      -- First compute determinants to see what side of the right and left lines we are on
      -- ILS course is between them

      lcd.setColor(lcd.getFgColor())
      
      if RunwayHeading then
	 dr = (xtable[i]-xr1)*(yr2-yr1) - (ytable[i]-yr1)*(xr2-xr1)
	 dl = (xtable[i]-xl1)*(yl2-yl1) - (ytable[i]-yl1)*(xl2-xl1)
     
	 if dl >= 0 and dr <= 0 then
	    lcd.setColor(0,255,0) -- Green!
	 end
      end

      if i == #xtable then
 	 drawShape(toXPixel(xtable[i], mapXmin, mapXrange, windowWidth),
		   toYPixel(ytable[i], mapYmin, mapYrange, windowHeight),
		   shapes.T38, math.rad(heading-magneticVar))
      else
	 lcd.drawCircle(toXPixel(xtable[i], mapXmin, mapXrange, windowWidth),
			toYPixel(ytable[i], mapYmin, mapYrange, windowHeight),
			2)
      end
   end

   lcd.setColor(lcd.getFgColor())
   drawBezier(windowWidth, windowHeight)
   drawGeo(windowWidth, windowHeight)

end

local function graphScale(x, y)

   if not mapXmax then
      mapXmax=   200
      mapXmin = -200
      mapYmax =  100
      mapYmin = -100
   end
   
   if x > xmax then xmax = x end
   if x < xmin then xmin = x end
   if y > ymax then ymax = y end
   if y < ymin then ymin = y end
   
   mapXrange = math.floor((xmax-xmin)/200 + .5) * 200 -- telemetry screens are 320x160 or 2:1
   mapYrange = math.floor((ymax-ymin)/100 + .5) * 100
   
   if mapYrange > mapXrange/(2) then
      mapXrange = mapYrange*(2)
   end
   if mapXrange > mapYrange*(2) then
      mapYrange = mapXrange/(2)
   end
   
   mapXmin = xmin - (mapXrange - (xmax-xmin))/2
   mapXmax = xmax + (mapXrange - (xmax-xmin))/2
   
   mapYmin = ymin - (mapYrange - (ymax-ymin))/2
   mapYmax = ymax + (mapYrange - (ymax-ymin))/2
   
end

local function initField()

   -- this function uses the GPS coords to see if we are near a known flying field in the jsn file
   -- and if it finds one, imports the field's properties 
   
   if long0 and lat0 then -- if location was detected by the GPS system
      for i=1, #geo.fields, 1 do -- see if we are near a known field (lat and long within ~ a mile)
	 if (math.abs(lat0 - geo.fields[i].runway.lat) < 1/60)
	 and (math.abs(long0 - geo.fields[i].runway.long) < 1/60) then
	    iField = i
	    long0 = geo.fields[iField].runway.long -- reset to origin to coords in jsn file
	    lat0  = geo.fields[iField].runway.lat
	    coslat0 = math.cos(math.rad(lat0))
	    rotationAngle = geo.fields[iField].runway.trueDir-270
	    for i=1, #geo.fields[iField].POI,1 do
	       poi[i] = {x=rE*(geo.fields[iField].POI[i].long-long0)*coslat0/rad,
			 y=rE*(geo.fields[iField].POI[i].lat-lat0)/rad}
	       poi[i].x, poi[i].y = rotateXY(poi[i].x, poi[i].y, math.rad(rotationAngle))
	       -- graphScale(poi[i].x, poi[i].y) -- maybe note in POI coords jsn if should autoscale or not?
	    end
	    
	    if (geo and iField) then -- if we read the jsn file then extract the info from it
      
	       rwy[1] = {x=-geo.fields[iField].runway.width/2,  y=-geo.fields[iField].runway.length/2}
	       rwy[2] = {x=-geo.fields[iField].runway.width/2,  y= geo.fields[iField].runway.length/2}
	       rwy[3] = {x= geo.fields[iField].runway.width/2,  y= geo.fields[iField].runway.length/2}
	       rwy[4] = {x= geo.fields[iField].runway.width/2,  y=-geo.fields[iField].runway.length/2}
	       rwy[5] = {x=-geo.fields[iField].runway.width/2,  y=-geo.fields[iField].runway.length/2}
	       
	       for i=1, 5, 1 do
		  rwy[i].x, rwy[i].y  =
		     rotateXY(rwy[i].x, rwy[i].y, math.rad(90) )
		  graphScale(2*rwy[i].x, 2*rwy[i].y)
	       end
	    end   
	    break
	 end
      end
   end
   if iField then
      system.messageBox("Current location: " .. geo.fields[iField].name, 2)
   else
      system.messageBox("Current location: not a known field", 2)
   end
end

local blocked = false
local timS = "0"

local function loop()

   local minutes, degs
   local x, y, xyslope
   local MAXVVITABLE = 5 -- points to fit to compute vertical speed
   local PATTERNALT = 200
   local tt
   local hasPitot
   local hasCourseGPS
   local sensor
   local goodlat, goodlong 
   local brk, thr
   local newpos
   local deltaPosTime = 100 -- min sample interval in ms
   local latS, lonS, altS, spdS
   
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
      
      if ff then io.close(ff) end
   end

   if DEBUG then
      debugTime =debugTime + 0.01*(system.getInputs("P7")+1)
--      speed = 40 + 80 * (math.sin(.3*debugTime) + 1)
      altitude = 20 + 200 * (math.cos(.3*debugTime)+1)
      x = 600*math.sin(2*debugTime)
      y = 300*math.cos(3*debugTime)
      if system.getTimeCounter() > debugNext then
	 debugNext = system.getTimeCounter() + 100
	 goto computedXY
      else
	 return
      end
   end
      
   
   -- if fd ~nil then we have a file open for reading a csv file
   -- wait until realtime is equal to recorded time to plot the point
   -- denominator under tonumber(timS) is acceleration factor for replay

   if fd then
      if ( (system.getTimeCounter() - sysTimeStart)/1000.) >= tonumber(timS)/10. and blocked then
	 blocked = false
	 goto fileInputLatLong
      end

      if blocked then return end
      
      tt = io.readline(fd, tt)
      if tt then
	 timS, latS, lonS, altS, spdS = string.match(tt,
	 "(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)"
	 )
	 latitude = tonumber(latS)
	 longitude = tonumber(lonS)
	 altitude = tonumber(altS)
	 speed = tonumber(spdS)
	 blocked = true
	 return
      else
	 io.close(fd)
	 print('Closing csv file')
	 fd = nil
      end
   end

   if fd then print('Should not get here with fd true!') end

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
      -- print('returning: goodlat, goodlong: ', goodlat, goodlong)
      return
   end

   -- if no GPS or pitot then code further below will compute speed from delta dist
   
   if not DEBUG then
      if hasPitot and SpeedNonGPS ~= nil then
	 speed = SpeedNonGPS
      elseif SpeedGPS ~= nil then
	 speed = SpeedGPS
      end
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
   if numGPSreads <= 10 then 
      print("Discarding reading: ", numGPSreads, latitude, longitude, goodlat, goodlong)
      return
   end
   
   ::fileInputLatLong::
   
   
   if (latitude == lastlat and longitude == lastlong) or (system.getTimeCounter() < newPosTime) then
      newpos = false
   else
      newpos = true
      
      if ff then
	 io.write(ff, string.format("%.4f, %.8f , %.8f , %.2f , %.2f\n",
				    (system.getTimeCounter()-sysTimeStart)/1000.,
				    latitude, longitude, altitude, speed))
      end
      
      lastlat = latitude
      lastlong = longitude
      newPosTime = system.getTimeCounter() + deltaPosTime
   end

   
   if not gotInitPos then

      if not iField then       -- if field not selected yet
	 long0 = longitude     -- set long0, lat0, coslat0 in case not near a field
	 lat0 = latitude       -- initField will reset if we are
	 coslat0 = math.cos(math.rad(lat0))	 
      end

      initField() -- use this lat/long to see if we are at a known flying field
      gotInitPos = true

   end

   
   x = rE*(longitude-long0)*coslat0/rad
   y = rE*(latitude-lat0)/rad
   
   -- update overall min and max for drawing the GPS
   -- maintain same pixel size (in feet) in X and Y (screen is 320x160)
   -- map?xxxx are all in ft .. convert to pixels in telem draw function
   
   ::computedXY::   

   x, y = rotateXY(x, y, math.rad(rotationAngle)) -- q+d for now .. rotate path only add ILS+RW later
   
   if newpos or DEBUG then -- only enter a new xy in the "comet tail" if lat/lon changed
      
      if #xtable+1 > MAXTABLE then
	 table.remove(xtable, 1)
	 table.remove(ytable, 1)
      end
      
      table.insert(xtable, x)
      table.insert(ytable, y)

      graphScale(x, y)
      
      if #xtable == 1 then
	 xmin = mapXmin
	 xmax = mapXmax
	 ymin = mapYmin
	 ymax = mapYmax
      end
      
      if #xtable > lineAvgPts then
	 xyslope, compcrs = fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
				   table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {}))
      else
	 xyslope = 0
	 compcrs = 0
      end
   
      compcrsDeg = compcrs*180/math.pi
   end

   computeBezier(MAXTABLE+3)
      
   
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
      if (altitude - baroAltZero) - zTakeoffStart > PATTERNALT/4 then
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
end


local function init()

   -- try opening the csv file for debugging .. if it exists assume we are
   -- doing a playback. If it does exist then, we are actually running, open a file for logging


   fd=io.open("DFM-LSO.csv", "r")

   if fd then
      form.question("Start replay?", "log file DFM-LSO.csv", "---", 0, true, 0)
      print("Opened log file DFM-LSO.csv for reading")
   else
      if DEBUG == false then
	 local dt = system.getDateTime()
	 local fn = string.format("GPS-LSO-%d%02d%02d-%d%02d%02d.csv",
				  dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec)
	 ff=io.open(fn, "w")
	 print("Opening for writing csv log file: ", fn)
      end
   end

   local fg = io.readall("Apps/DFM-LSO.jsn")
   if fg then
      geo = json.decode(fg)
   end

   LatitudeSe      = system.pLoad("LatitudeSe", 0)
   LatitudeSeId    = system.pLoad("LatitudeSeId", 0)
   LatitudeSePa    = system.pLoad("LatitudeSePa", 0)
   
   LongitudeSe     = system.pLoad("LongitudeSe", 0)
   LongitudeSeId   = system.pLoad("LongitudeSeId", 0)
   LongitudeSePa   = system.pLoad("LongitudeSePa", 0)
   
   AltitudeSe      = system.pLoad("AltitudeSe", 0) -- this is the GPS altitute -- cf BaroAlt...
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
   if not rotationAngle then   rotationAngle   = system.pLoad("rotationAngle", 0) end
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


LSOVersion = "1.1"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=LSOVersion, name="GPS LSO"}
