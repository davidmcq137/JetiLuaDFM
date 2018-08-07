--[[
	---------------------------------------------------------
    ILS descr
    
    Derived from DFM's Speed and Time Announcers, which were turn was derived from RCT's Alt Announcer
    
    Requires transmitter firmware 4.22 or higher.
    
    Works in DS-24
    
	----------------------------------------------------------------------
	Localisation-file has to be as /Apps/Lang/DFM-TimA.jsn if used
	----------------------------------------------------------------------
	Derived from AltAnnouncer - a part of RC-Thoughts Jeti Tools.
	----------------------------------------------------------------------
	AltAnnouncer released under MIT-license by Tero @ RC-Thoughts.com 2017
	----------------------------------------------------------------------
	DFM-LSO.lua released under MIT license by DFM 2018
	----------------------------------------------------------------------

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

local latitude, longitude
local speedGPS, speedNonGPS = 0,0
local courseGPS, courseNonGPS, course
local altitude, speed = 0,0
local DistanceGPS, distance
local magneticVar

local xtable = {}
local ytable = {}
local ztable = {}

local mapXmin, mapXmax = -100, 100
local mapYmin, mapYmax = -50, 50
local mapXrange = mapXmax - mapXmin
local mapYrange = mapYmax - mapYmin

local DEBUG = true -- if set to <true> will print to console the speech files and output

-- these are the non-GPS sensors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these are the GPS sensors

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }
local mapXmin, mapXmax = -100, 100
local mapYmin, mapYmax = -50, 50
local mapXrange = mapXmax - mapXmin
local mapYrange = mapYmax - mapYmin

local throttleControl
local brakeControl
local brakeReleaseTime = 0
local oldBrake = 0

local xTakeoffStart
local yTakeoffStart
local zTakeoffStart

local xTakeoffComplete
local yTakeoffComplete
local zTakeoffComplete
local TakeoffHeading

local neverAirborne=true

local resetOrigin=false

local lastLoopTime = 0
local avgLoopTime = 0
local loopCount = 0

local lastlat = 0
local lastlong = 0
local gotInitPos = false
local L0, y0
local rE = 6371*1000
local rad = 180/math.pi
local compcrs
local heading, compcrsDeg = 0, 0
local lineAvgPts = 4  -- number of points to linear fit to compute course

local ren=lcd.renderer()
local txtr, txtg, txtb = 0,0,0

local ff
local qq

--------------------------------------------------------------------------------

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

	 -- if (sensor.label == "Altitude" or sensor.label == "Longitude" or sensor.label == "Latitude") then
	   -- print(sensor.label,",",sensor.id, ",", sensor.param, ",", sensor.unit, ",", sensor.type)
	 -- end

	 if sensor.type ~= 9 then
	    table.insert(sensorLalist, sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	    if sensor.label == 'Altitude' and sensor.param == 6 then
	       AltitudeSe = #sensorLalist
	       AltitudeSeId = sensor.id
	       AltitudeSePa = sensor.param
	    end	    	    
	 else
	    table.insert(GPSsensorLalist, sensor.label)
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)

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
   system.psave("magneticVar", value)
end

local function resetOriginChanged(value)
   resetOrigin = not value
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

  if (tonumber(system.getVersion()) >= 4.22) then

    form.addRow(2)
    form.addLabel({label="Select Pitot-Static Speed Sensor", width=220})
    form.addSelectbox(sensorLalist, SpeedNonGPSSe, true, SpeedNonGPSSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select Throttle Control", width=220})
    form.addInputbox(throttleControl, true, throttleControlChanged)

    form.addRow(2)
    form.addLabel({label="Select Brake Control", width=220})
    form.addInputbox(brakeControl, true, brakeControlChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Longitude Sensor", width=220})
    form.addSelectbox(GPSsensorLalist, LongitudeSe, true, LongitudeSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Latitude Sensor", width=220})
    form.addSelectbox(GPSsensorLalist, LatitudeSe, true, LatitudeSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Altitude Sensor", width=220})
    form.addSelectbox(sensorLalist, AltitudeSe, true, AltitudeSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Speed Sensor", width=220})
    form.addSelectbox(sensorLalist, SpeedGPSSe, true, SpeedGPSSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Distance", width=220})
    form.addSelectbox(sensorLalist, DistanceGPSSe, true, DistanceGPSSensorChanged)

    form.addRow(2)
    form.addLabel({label="Select GPS Course", width=220})
    form.addSelectbox(sensorLalist, CourseGPSSe, true, CourseGPSSensorChanged)    

    form.addRow(2)
    form.addLabel({label="Local Magnetic Variation (\u{B0}W)", width=220})
    form.addIntbox(magneticVar, -30, 30, -13, 0, 1, magneticVarChanged)
    
    form.addRow(2)
    form.addLabel({label="Reset GPS origin", width=274})
    form.addCheckbox(resetOrigin, resetOriginChanged)
        
    form.addRow(1)
    form.addLabel({label="DFM - v."..ILSVersion.." ", font=FONT_MINI, alignRight=true})

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

local homeShape = {
  { 0, -10},
  {-8,  8},
  { 0,  4},
  { 8,  8}
}

local coolShape = {
   {0,-10},
   {-2,-3},
   {-5,0},
   {-5,1},
   {-1,1},
   {-1,2},
   {-3,4},
   {-3,5},
   {0,5},
   {3,5},
   {3,4},
   {1,2},
   {1,1},
   {5,1},
   {5,0},
   {2,-3}
}

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

local function drawDistance()

   lcd.setColor(txtr,txtg,txtb)
--[[
   if distance and distance > 0 then
      text =  string.format("%dm",distance)
      lcd.drawText(colAH + 16 - lcd.getTextWidth(FONT_NORMAL,text), rowAH + 10, text)
   end
--]]
   lcd.setColor(lcd.getFgColor())
   drawShape(colAH, rowAH+20, T38Shape, math.rad(heading))
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
  delta = altitude % 10
  deltaY = 1 + math.floor(2.4 * delta)  
  lcd.drawText(colAlt+2, heightAH+2, "ft", FONT_MINI)
  lcd.setClipping(colAlt-7,0,45,heightAH)
  --print("dA clipping: ", colAlt-7, 0, 45, heightAH)
  lcd.drawLine(7, -1, 7, heightAH)
  
  for index, line in pairs(parmLine) do
    lcd.drawLine(6 - line[2], line[1] + deltaY, 6, line[1] + deltaY)
    if line[3] then
      lcd.drawNumber(11, line[1] + deltaY - 8, altitude+0.5 + line[3] - delta, FONT_NORMAL)
    end
  end

  text = string.format("%d",altitude)
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
  lcd.drawText(colSpeed-30, heightAH+2, "mph", FONT_MINI)
  lcd.setClipping(colSpeed-37,0,45,heightAH)
  --print("dS clipping: ", colSpeed-37, 0, 45, heightAH)
  
  lcd.drawLine(37, -1, 37, heightAH)
  for index, line in pairs(parmLine) do
    lcd.drawLine(38, line[1] + deltaY, 38 + line[2], line[1] + deltaY)
    if line[3] then
      text = string.format("%d",speed+0.5 + line[3] - delta)
      lcd.drawText(35 - lcd.getTextWidth(FONT_NORMAL,text), line[1] + deltaY - 8, text, FONT_NORMAL)
    end
  end

  text = string.format("%d",speed)
  lcd.drawFilledRectangle(0,rowAH-8,35,lcd.getTextHeight(FONT_NORMAL))
  --lcd.drawNumber(9, 1 + rowAH - 3, altitude, FONT_MINI)
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
   
   text = string.format("%03d",heading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   lcd.setColor(txtr,txtg,txtb)
   lcd.drawFilledRectangle(colHeading - w/2, rowHeading-30, w, lcd.getTextHeight(FONT_NORMAL))
   lcd.setColor(255-txtr,255-txtg,255-txtb)
   lcd.drawText(colHeading - w/2,rowHeading-30,text,  FONT_XOR)
   
   lcd.resetClipping()
end

---------------------------------------------------------------------------------

local function mapPrint(windowWidth, windowHeight)

   local xpix, ypix
   local r, g, b
   local ss, ww
   
   r, g, b = lcd.getFgColor()
   lcd.setColor(r, g, b)

   drawSpeed()
   drawAltitude()
   drawHeading()
   drawDistance()
   
   for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute 

      xpix = (xtable[i] - mapXmin)/mapXrange * windowWidth
      xpix = (xpix * 0.98125) + 3 -- keep a 3 pixel border buffer

      ypix = windowHeight-((ytable[i] - mapYmin)/mapYrange * windowHeight)
      ypix = (ypix * 0.98125) + 3 

      lcd.drawCircle(xpix, ypix, 1)

   end


 --[[   
   if compcrsDeg then
      ss = string.format("Magnetic Course: %d".."\u{B0}", compcrsDeg + magneticVar)
   else
      ss = "---"
   end
   

   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(2, 5, ss, FONT_NORMAL)

   if xpix then ss = string.format("x,xpix: %d,%d", xtable[#xtable], xpix) else ss = "---" end
   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(2, 20, ss, FONT_NORMAL)
      
   if ypix then ss = string.format("y,ypix: %d,%d", ytable[#ytable], ypix) else ss = "---" end 
   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(2, 35, ss, FONT_NORMAL)   

   
   ss= string.format("x:%d, y:%d, r:%d", mapXmin,mapYmin,mapXrange)
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(2, 140, ss, FONT_MINI)

   ss= string.format("x:%d, y:%d, r:%d", mapXmax,mapYmax,mapYrange)
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(windowWidth-ww-2, 5, ss, FONT_MINI)
--]]
   
--[[
  local ss = string.format("Scale: %d", GraphScale)
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(75+(75-ww)/2+1,70+1, ss, FONT_MINI)

  local ss = string.format("Timeline %s", "1:00")
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(150+(75-ww)/2+2,70+1, ss, FONT_MINI)

  local ss = string.format("Bat 1: %2.2f A", batt_val[1])
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(75+(75-ww)/2+1,70+15, ss, FONT_MINI)

  local ss = string.format("Bat 2: %2.2f A", batt_val[2])
  ww = lcd.getTextWidth(FONT_MINI, ss)
  lcd.drawText(150+(75-ww)/2+2,70+15, ss, FONT_MINI)
--]]
   
end

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
local debugTime = 0

local function loop()

   local minutes, degs
   local x, y, xyslope
   local oldXrange, oldYrange
   local MAXTABLE = 100
   local OFFGROUND = 10 -- units?
   local xExp, yExp
   local tt
   local hasPitot
   local hasCourseGPS
   local sensor
   
   if resetOrigin then
      gotInitPos = false
      resetOrigin = false
      --io.close(ff)
   end

   if DEBUG then

      debugTime = math.fmod(debugTime + .005, 2*math.pi)

      speed = math.fmod(speed + .3, 200)
      altitude = math.fmod(altitude + .2, 1000)
      --heading = math.fmod(heading + 2, 360)

      x = 600*math.sin(5*debugTime)
      y = 300*math.cos(7*debugTime)
      --print("x,y: ", x, y)
      
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
   else
      return
   end
   
   sensor = system.getSensorByID(LatitudeSeId, LatitudeSePa)

   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
      if sensor.decimals == 2 then -- "South" .. make it negative
	 latitude = latitude * -1
      end
   else
      return
   end
   
   sensor = system.getSensorByID(AltitudeSeId, AltitudeSePa)

   if(sensor and sensor.valid) then
      altitude = sensor.value
   else
      return
   end

   sensor = system.getSensorByID(SpeedNonGPSSeId, SpeedNonGPSSePa)

   hasPitot = false
   if(sensor and sensor.valid) then
      SpeedNonGPS = sensor.value
      hasPitot = true
   else
      return
   end

   sensor = system.getSensorByID(SpeedGPSSeId, SpeedGPSSePa)

   if(sensor and sensor.valid) then
      SpeedGPS = sensor.value
   else
      return
   end

   sensor = system.getSensorByID(DistanceGPSSeId, DistanceGPSSePa)

   if(sensor and sensor.valid) then
      DistanceGPS = sensor.value
   else
      return
   end      

   hasCourseGPS = false
   sensor = system.getSensorByID(CourseGPSSeId, CourseGPSSeId)
   if sensor.valid then
      courseGPS = sensor.value
      HasCourseGPS = true
   else
      return
   end
   
   -- if we got here, lat, long and alt are all valid
   -- so we can compute x, y and heading
   -- only recompute when lat and long have changed

   if latitude == lastlat and longitude == lastlong then return end
   
   lastlat = latitude
   lastlong = longitude

   if not gotInitPos then
      L0 = longitude
      y0 = rE*math.log(math.tan(( 45+latitude/2)/rad ) )
      gotInitPos = true
   end
   
   x = rE*(longitude-L0)/rad
   y = rE*math.log(math.tan(( 45+latitude/2)/rad ) ) - y0
   
   -- update overall min and max for drawing the GPS
   -- maintain same pixel size (in feet) in X and Y (screen is 320x160)
   -- map?xxxx are all in ft .. convert to pixels in telem draw function
   
   ::computedXY::   

   xExp = false
   yExp = false
   
   if x > mapXmax then
      mapXmax = x
      xExp = true
   end
   
   if x < mapXmin then
      mapXmin = x
      xExp = true
   end
   
   if y > mapYmax then
      mapYmax = y
      yExp = true
   end
   
   if y < mapYmin then
      mapYmin = y
      yExp = true
   end
   
   oldYrange = mapYrange
   oldXrange = mapXrange
   
   mapXrange = mapXmax - mapXmin
   mapYrange = mapYmax - mapYmin
   
   if xExp or yExp then
      if mapXrange > 2 * mapYrange and xExp then
	 mapYmin = mapYmin*mapXrange/oldXrange
	 mapYmax = mapYmax*mapXrange/oldXrange
      end
      if mapYrange > 0.5 * mapXrange and yExp then
	 mapXmin = mapXmin*mapYrange/oldYrange
	 mapXmax = mapXmax*mapYrange/oldYrange
      end
      mapYrange = mapYmax - mapYmin
      mapXrange = mapXmax - mapXmin
   end
   
   
   --tt = system.getTimeCounter()/1000
   --ss1 = string.format("%.2f, %.0f, %.0f, %.0f, %.0f, %.0f, %.0f", tt, mapXmin, mapXmax, mapYmin, mapYmax, mapXrange, mapYrange)
   --print(ss1)
   
   if #xtable+1 > MAXTABLE then
      table.remove(xtable, 1)
      table.remove(ytable, 1)
      table.remove(ztable, 1)
   end
   
   table.insert(xtable, x)
   table.insert(ytable, y)
   table.insert(ztable, altitude)
   
   if #xtable > lineAvgPts then
      xyslope, compcrs = fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
				table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {}))
   else
      xyslope = 0
      compcrs = math.pi/2
   end
   
   compcrsDeg = compcrs*180/math.pi
   
   if DEBUG then
      heading = compcrsDeg
   else
	 if hasCourseGPS then
	    heading = CourseGPS
	 else
	    heading = compcrsDeg
	 end
   end
   
   
   if not DEBUG then
      if hasPitot then
	 speed = SpeedNonGPS
      else
	 speed = SpeedGPS
      end
   end
   
   --ss2 = string.format("%.0f, %.0f, %.0f, %.0f, %.0f, %.0f", #xtable, x, y, altitude, course, compcrsDeg)
   --print(ss2)
   
   -- system.getInputs for thr and brake
   -- monitor brake release, throttle up, takeoff roll, actual takeoff
   
   if (brakeControl) then
      local brk = system.getInputsVal(brakeControl)
   end
   if brk and brk < 0 and oldBrake > 0 then
      brakeReleaseTime = system.getTimeCounter()
      print("Brake release time: ", brakeReleaseTime)
   end
   if brk and brk > 0 then
      brakeReleaseTime = 0
   end

   if brk then oldBrake = brk end
   
   if (throttleControl) then
      local thr = system.getInputsVal(throttleControl)
   end
   if thr and thr > 0 and oldThrottle < 0 then
      if system.getTimeCounter() - brakeReleaseTime < 5000 then
	 xTakeoffStart = x
	 yTakeoffStart = y
	 zTakeoffStart = altitide
	 print("Takeoff Start: ", brakeReleaseTime, x, y, altitude)
      end
   end
   
   if xTakeoffStart and neverAirborne then
      if altitude - zTakeoffStart > OFFGROUND then
	 neverAirborne = false
	 xTakeoffComplete = x
	 yTakeoffComplete = y
	 zTakeoffComplete = altitude
	 TakeoffHeading = compcrsDeg + magneticVar
	 print("Takeoff Complete:", system.getTimeCounter(), TakeoffHeading)
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

   resetOrigin     = false
   
   system.registerForm(1, MENU_APPS, "GPS ILS", initForm, nil, nil)
   system.registerTelemetry(1, "GPS ILS", 4, mapPrint)
    
   system.playFile('ILS_Active.wav', AUDIO_QUEUE)
   
   if DEBUG then
      print('ILS_Active.wav')
   end
    readSensors()
    collectgarbage()
end


ILSVersion = "1.0"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=ILSVersion, name="GPS ILS"}
