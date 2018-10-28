--[[

   --------------------------------------------------------------------------------------------------
   DFM-LSO.lua -- "Landing Signal Officer" -- GPS Map and "ILS"/GPS RNAV system

   Derived from DFM's Speed and Time Announcers, which were turn was derived from Tero's RCT's Alt Announcer
   Borrowed and modified code from Jeti's AH example for tapes and heading indicator.
   New code to project Lat/Long via simple equirectangular projection to XY plane, and to
   compute heading from the projected XY plane track for GPS sensors that don't have this feature 
   and create an map of flightpath and an  ILS "localizer" based on GPS (e.g a model version of GPS RNAV)
    
   Requires transmitter firmware 4.22 or higher.
    
   Developed on DS-24, only tested on DS-24

   --------------------------------------------------------------------------------------------------
   DFM-LSO.lua released under MIT license by DFM 2018
   --------------------------------------------------------------------------------------------------

   Work items:

   - initialization of map to +/- 200 x +/- 400 -- seems to happen in several places. rationalize
   - rotationAngle not working correctly with selected iField .. set to 90 and set back .. messes up 
     north pointer, does not rotate runway. do we want to do both iField and manual rotation...
   - figure out a nicer way to do log file replays
   - any optimization of CPU% possible? 20% seems high. only 8% with no GPS data to plot

--]]

collectgarbage()

------------------------------------------------------------------------------

-- Persistent and global variables for entire progrem

local LSOVersion = "1.2"

local latitude
local longitude
local courseGPS
local courseNonGPS
local course
local baroAlt
local GPSAlt
local DistanceGPS
local distance
local heading = 0
local speedGPS = 0
local speedNonGPS = 0
local altitude = 0
local speed = 0
local vario=0

local telem={"Latitude", "Longitude",   "Altitude",  "SpeedNonGPS",
	     "SpeedGPS", "DistanceGPS", "CourseGPS", "BaroAlt"
            }
telem.Latitude={}
telem.Longitude={}
telem.Altitude={}
telem.SpeedNonGPS={}
telem.SpeedGPS={}
telem.DistanceGPS={}
telem.CourseGPS={}
telem.BaroAlt={}

local variables = {"magneticVar", "rotationAngle"}
local controls  = {"Throttle", "Brake"}

local xtable = {}
local ytable = {}
local MAXTABLE = 5
local map={}

local path={}
local bezierPath = {}

local shapes = {}
local rwy = {}
local poi = {}
local geo = {}
local iField

local takeoff={}; takeoff.Complete={}; takeoff.Start={}
takeoff.NeverAirborne = true
takeoff.BrakeReleaseTime = 0
takeoff.oldBrake = 0
takeoff.oldThrottle = 0

-- these lists are the non-GPS sensors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }

local sysTimeStart = system.getTimeCounter()

local DEBUG = true -- if set to <true> will generate flightpath automatically for demo purposes
local debugTime = 0
local debugNext = 0
local DEBUGLOG = true -- persistent state var for debugging (e.g. to print something in a loop only once)

--[[

-- Read and set translations (out for now till we have translations, simplifies install)

local trans11

local function setLanguage()
   
   local lng=system.getLocale()
   local file = io.readall("Apps/DFM-LSO/Languages.jsn")
   local obj = json.decode(file)cd 
   if(obj) then
      trans11 = obj[lng] or obj[obj.default]
   end
end

--]]
   

--[[

-- function to show all global variables .. uncomment for debug .. called from reset origin menu

local seen={}
function dump(t,i)
	seen[t]=true
	local s={}
	local n=0
	for k in pairs(t) do
		n=n+1 s[n]=k
	end
	table.sort(s)
	for k,v in ipairs(s) do
		print(i,v)
		v=t[v]
		if type(v)=="table" and not seen[v] then
			dump(v,i.."\t")
		end
	end
end

--]]

-- Read available sensors for user to select - done once at startup
-- Make separate lists for GPS lat and long sensors since they require different processing
-- Other GPS sensors (also if type 9, but diff params) are treated like non GPS sensors
-- The labels and values for sensor.param work for the Jeti MGPS .. 
-- Other GPSs have to be selected manually via the screen

local satCountID = 0
local satCountPa = 0
local satCount

local satQualityID = 0
local satQualityPa = 0
local satQuality

local function readSensors()

   local labelTxt

   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then

	 --[[
	    Note:
	    Digitech CTU Altitude is type 1, param 13 (vs. MGPS Altitude type 1, param 6)
	    MSpeed Velocity (airspeed) is type 1, param 1
	 
	    Code below will put sensor names in the choose list and auto-assign the relevant
	    selections for the Jeti MGPS, Digitech CTU and Jeti MSpeed
	 --]]

	 if sensor.param == 0 then -- it's a label
	    labelTxt = sensor.label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)	    
	 elseif sensor.type == 9 then  -- lat/long
	    table.insert(GPSsensorLalist, sensor.label)
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)
	    if (sensor.label == 'Longitude' and sensor.param == 3) then
	       telem.Longitude.Se = #GPSsensorLalist
	       telem.Longitude.SeId = sensor.id
	       telem.Longitude.SePa = sensor.param
	    end
	    if (sensor.label == 'Latitude' and sensor.param == 2) then
	       telem.Latitude.Se = #GPSsensorLalist
	       telem.Latitude.SeId = sensor.id
	       telem.Latitude.SePa = sensor.param
	    end
	 elseif sensor.type == 5 then -- date - ignore
	   
	 else  -- "regular" numeric sensor

	    table.insert(sensorLalist, sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)

	    if sensor.label == 'Velocity' and sensor.param == 1 then
  	       telem.SpeedNonGPS.Se = #sensorLalist
	       telem.SpeedNonGPS.SeId = sensor.id
	       telem.SpeedNonGPS.SePa = sensor.param
	    end
	    if sensor.label == 'Altitude' and sensor.param == 13 then
  	       telem.BaroAlt.Se = #sensorLalist
	       telem.BaroAlt.SeId = sensor.id
	       telem.BaroAlt.SePa = sensor.param
	    end	    
	    if sensor.label == 'Altitude' and sensor.param == 6 then
  	       telem.Altitude.Se = #sensorLalist
	       telem.Altitude.SeId = sensor.id
	       telem.Altitude.SePa = sensor.param
	    end
	    if sensor.label == 'Distance' and sensor.param == 7 then
	       telem.DistanceGPS.Se = #sensorLalist
	       telem.DistanceGPS.SeId = sensor.id
	       telem.DistanceGPS.SePa = sensor.param
	    end
	    if sensor.label == 'Speed' and sensor.param == 8 then
	       telem.SpeedGPS.Se = #sensorLalist
	       telem.SpeedGPS.SeId = sensor.id
	       telem.SpeedGPS.SePa = sensor.param
	    end
	    if sensor.label == 'Course' and sensor.param == 10 then
	       telem.CourseGPS.Se = #sensorLalist
	       telem.CourseGPS.SeId = sensor.id
	       telem.CourseGPS.SePa = sensor.param
	    end
	    if sensor.label == 'SatCount' and sensor.param == 5 then -- remember these last two separately
	       satCountID = sensor.id
	       satCountPa = sensor.param
	    end
	    if sensor.label == 'Quality' and sensor.param == 4 then
	       satQualityID = sensor.id
	       satQualityPa = sensor.param
	    end	    
	    
	 end
      end
   end
end

----------------------------------------------------------------------

-- Actions when settings changed

local function sensorChanged(value, str, isGPS)

   telem[str].Se = value
   
   if isGPS then
      telem[str].SeId = GPSsensorIdlist[telem[str].Se]
      telem[str].SePa = GPSsensorPalist[telem[str].Se]
   else
      telem[str].SeId = sensorIdlist[telem[str].Se]
      telem[str].SePa = sensorPalist[telem[str].Se]
   end
   
   if (telem[str].SeId == "...") then
      telem[str].SeId = 0
      telem[str].SePa = 0 
   end

   system.pSave("telem."..str..".Se", value)
   system.pSave("telem."..str..".SeId", telem[str].SeId)
   system.pSave("telem."..str..".SePa", telem[str].SePa)
end

local function controlChanged(value, ctl)
   controls[ctl] = value
   system.pSave(ctl, value)
end

local function variableChanged(value, var)
   variables[var] = value
   system.pSave(var, value)
end

local resetOrigin=false
local resetClick=false
local resetCompIndex

local function resetOriginChanged(value)
   resetClick = value
   if not resetClick then
      resetClick = true
      form.setValue(resetCompIndex, resetClick)
      resetOrigin=true
      timeRO = system.getTimeCounter()
      print("GC Memory before: ", collectgarbage("count"))
      collectgarbage()
      print("GC Memory after: ", collectgarbage("count"))
   end
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

  if (tonumber(system.getVersion()) >= 4.22) then

     local menuInput = {Throttle = "Select Throttle Control", Brake = "Select Brake Control"}

     for var, txt in pairs(menuInput) do
	form.addRow(2)
	form.addLabel({label=txt, width=220})
	form.addInputbox(controls.Throttle, true,
			 (function(x) return controlChanged(x, var) end) )
     end
     
     local menuSelectGPS = { -- for lat/long only
	Longitude="Select GPS Longitude Sensor",
	Latitude ="Select GPS Latitude Sensor",
     }

     local menuSelect1 = { -- not from the GPS sensor
	SpeedNonGPS="Select Pitot Speed Sensor",
	BaroAlt="Select Baro Altimeter Sensor",
     }

     local menuSelect2 = { -- non lat/long but still from GPS sensor
	Altitude ="Select GPS Altitude Sensor",
	SpeedGPS="Select GPS Speed Sensor",
	DistanceGPS="Select GPS Distance Sensor",
	CourseGPS="Select GPS Course Sensor",
     }     
     
     for var, txt in pairs(menuSelect1) do
	form.addRow(2)
	form.addLabel({label=txt, width=220})
	form.addSelectbox(sensorLalist, telem[var].Se, true,
		       (function(x) return sensorChanged(x, var, false) end) )
     end

     for var, txt in pairs(menuSelectGPS) do
	form.addRow(2)
	form.addLabel({label=txt, width=220})
	form.addSelectbox(GPSsensorLalist, telem[var].Se, true,
		       (function(x) return sensorChanged(x, var, true) end) )
     end

     for var, txt in pairs(menuSelect2) do
	form.addRow(2)
	form.addLabel({label=txt, width=220})
	form.addSelectbox(sensorLalist, telem[var].Se, true,
		       (function(x) return sensorChanged(x, var, false) end) )
     end


     -- not worth it do to a loop with a menu item table for Intbox due to the
     -- variation in defaults etc nor for addCheckbox due to specialized nature
     
     form.addRow(2)
     form.addLabel({label="Map Rotation (\u{B0}CCW)", width=220})
     form.addIntbox(variables.rotationAngle, 0, 359, 0, 0, 1,
		    (function(x) return variableChanged(x, "rotationAngle") end) )
     
     -- decomission magneticVar for now .. reconsider if we want this functionality
     -- let if default to zero
     
     --    form.addRow(2)
     --    form.addLabel({label="Local Magnetic Var (\u{B0}W)", width=220})
     --    form.addIntbox(variables.magneticVar, -30, 30, -13, 0, 1,
     --                   (function(x) return variableChanged(x, "magneticVar") end) )

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

-- Telemetry window draw functions

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


-- Various shape and polyline functions using the anti-aliasing renderer

local ren=lcd.renderer()

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

local txtr, txtg, txtb = 0,0,0

local function drawDistance()

   lcd.setColor(txtr,txtg,txtb)
--[[
   if distance and distance > 0 then
      text =  string.format("%dm",distance)
      lcd.drawText(colAH + 16 - lcd.getTextWidth(FONT_NORMAL,text), rowAH + 10, text)
   end
--]]
   lcd.setColor(lcd.getFgColor())
   drawShape(colAH, rowAH+20, shapes.T38, math.rad(heading-variables.magneticVar))
end

-- Draw altitude indicator


-- Vertical line parameters

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

local baroAltZero = 0

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

-- Draw speed indicator

local function drawSpeed() 
  lcd.setColor(txtr,txtg,txtb)
  delta = speed % 10
  deltaY = 1 + math.floor(2.4 * delta)
  lcd.drawText(colSpeed-30, heightAH+2, "mph", FONT_MINI)
  lcd.setClipping(colSpeed-37,0,45,heightAH)
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
  lcd.setColor(255-txtr,255-txtg,255-txtb)
  lcd.drawText(35 - lcd.getTextWidth(FONT_NORMAL,text), rowAH-8, text, FONT_NORMAL | FONT_XOR)
  lcd.resetClipping() 
end

-- Draw heading indicator

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
      lcd.drawFilledRectangle(colVario-4,rowVario-math.floor(vario/16.66 + 0.5),
			      10,math.floor(vario/16.66+0.5),170)
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

-- persistent and shared (with mapPrint) variables for ilsPrint

local xr1,yr1, xr2, yr2
local xl1,yl1, xl2, yl2
local glideSlopePNG


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

   local x = xtable[#xtable] or 0
   local y = ytable[#ytable] or 0
   
   text=string.format("X,Y = %4d,%4d", x, y)
   lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH, text, FONT_MINI)

   -- First compute determinants to see what side of the right and left lines we are on
   -- ILS course is between them -- also compute which side of the course we are on

   if #xtable >=1  and takeoff.RunwayHeading then
 
      dr = (xtable[#xtable]-xr1)*(yr2-yr1) - (ytable[#ytable]-yr1)*(xr2-xr1)
      dl = (xtable[#xtable]-xl1)*(yl2-yl1) - (ytable[#ytable]-yl1)*(xl2-xl1)
      dc = (xtable[#xtable]-takeoff.Start.X)*(takeoff.Complete.Y-takeoff.Start.Y) -
	 (ytable[#ytable]-takeoff.Start.Y)*(takeoff.Complete.X-takeoff.Start.X)
      
      hyp = math.sqrt( (ytable[#ytable]-takeoff.Complete.Y)^2 + (xtable[#xtable]-takeoff.Complete.X)^2 )

      if dl >= 0 and dr <= 0 and math.abs(hyp) > 0.1 then

	 perpd  = math.abs((takeoff.Complete.Y-takeoff.Start.Y)*xtable[#xtable] -
	       (takeoff.Complete.X-takeoff.Start.X)*ytable[#ytable]+takeoff.Complete.X*takeoff.Start.Y-
	       takeoff.Complete.Y*takeoff.Start.X) / hyp
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

   if takeoff.RunwayHeading then
      lcd.setColor(txtr,txtg,txtb)
      local distFromTO = math.sqrt( (xtable[#xtable] - takeoff.Start.X)^2 +
	    (ytable[#ytable] - takeoff.Start.Y)^2)
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

   if not bezierPath[1]  then return end

   ren:reset()

   for j=1, #bezierPath do
      ren:addPoint(toXPixel(bezierPath[j].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(bezierPath[j].y, map.Ymin, map.Yrange, windowHeight))
   end
   ren:renderPolyline(3)

end

local function drawGeo(windowWidth, windowHeight)

   if not rwy[1] then return end

   ren:reset()

   for j=1, #rwy do
      ren:addPoint(toXPixel(rwy[j].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(rwy[j].y, map.Ymin, map.Yrange, windowHeight))
   end

   ren:renderPolyline(2)

   if not poi[1] then return end
   
   for j=1, #poi do
      drawShape(toXPixel(poi[j].x, map.Xmin, map.Xrange, windowWidth),
		toYPixel(poi[j].y, map.Ymin, map.Yrange, windowHeight),
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

   if takeoff.Start.X then
      lcd.drawCircle(toXPixel(takeoff.Start.X, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(takeoff.Start.Y, map.Ymin, map.Yrange, windowHeight), 4)
   end
   
   if takeoff.Complete.X then

      lcd.drawCircle(toXPixel(takeoff.Complete.X, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(takeoff.Complete.Y, map.Ymin, map.Yrange, windowHeight), 4)

      xRW = (takeoff.Complete.X - takeoff.Start.X)/2 + takeoff.Start.X 
      yRW = (takeoff.Complete.Y - takeoff.Start.Y)/2 + takeoff.Start.Y
      lRW = math.sqrt((takeoff.Complete.X-takeoff.Start.X)^2 + (takeoff.Complete.Y-takeoff.Start.Y)^2)

      scale = (lRW/map.Xrange)*(windowWidth/40) -- rw shape is 40 units long

      lcd.setColor(0,240,0)

      drawShapePL(toXPixel(xRW, map.Xmin, map.Xrange, windowWidth),
		  toYPixel(yRW, map.Ymin, map.Yrange, windowHeight),
		  shapes.runway, math.rad(takeoff.RunwayHeading-variables.magneticVar), scale, 2, 255)
      
      drawILS (toXPixel(takeoff.Start.X, map.Xmin, map.Xrange, windowWidth),
	       toYPixel(takeoff.Start.Y, map.Ymin, map.Yrange, windowHeight),
	       math.rad(takeoff.RunwayHeading-variables.magneticVar), scale)


      lcd.setColor(r,g,b)

      text=string.format("Map: %d x %d    Rwy: %dT", map.Xrange, map.Yrange,
			 math.floor(takeoff.RunwayHeading/10+.5) )

      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)

   else
      local x = xtable[#xtable] or 0
      local y = ytable[#ytable] or 0

      text=string.format("Map: %d x %d", map.Xrange, map.Yrange)
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH-10, text, FONT_MINI)

      if iField then
	 text=geo.fields[iField].name
      else
	 text='Unknown Field'
      end
      
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)
   end

   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, "N") / 2, 14, "N", FONT_MINI)
   drawShape(70, 20, shapes.arrow, math.rad(-1*variables.rotationAngle))
   lcd.drawCircle(70, 20, 7)

   if satCount then
      text=string.format("%2d", satCount)
      lcd.drawText(70-lcd.getTextWidth(FONT_MINI, text) / 2, 28, text, FONT_MINI)
   end

   if satQuality then
      text=string.format("%.1f", satQuality)
      lcd.drawText(70-lcd.getTextWidth(FONT_MINI, text) / 2, 42, text, FONT_MINI)   
   end
   
   if takeoff.RunwayHeading then
      phi = (90-(takeoff.RunwayHeading-variables.magneticVar)+360)%360
      if not xr1 then -- do not recompute unless runway is reset noted by setting xr1 to nil
	 xr1 = takeoff.Complete.X - lRW/2 * math.cos(math.rad(phi-12))
	 yr1 = takeoff.Complete.Y - lRW/2 * math.sin(math.rad(phi-12))
      
	 xr2 = takeoff.Complete.X - lRW * math.cos(math.rad(phi-12))
	 yr2 = takeoff.Complete.Y - lRW * math.sin(math.rad(phi-12))
	 
	 xl1 = takeoff.Complete.X - lRW/2 * math.cos(math.rad(phi+12))
	 yl1 = takeoff.Complete.Y - lRW/2 * math.sin(math.rad(phi+12))
	 
	 xl2 = takeoff.Complete.X - lRW * math.cos(math.rad(phi+12))
	 yl2 = takeoff.Complete.Y - lRW * math.sin(math.rad(phi+12))
      end
      
      lcd.drawCircle(toXPixel(xr1, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(yr1, map.Ymin, map.Yrange, windowHeight), 3)      
      lcd.drawCircle(toXPixel(xl1, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(yl1, map.Ymin, map.Yrange, windowHeight), 3)
      lcd.drawCircle(toXPixel(xr2, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(yr2, map.Ymin, map.Yrange, windowHeight), 3)      
      lcd.drawCircle(toXPixel(xl2, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(yl2, map.Ymin, map.Yrange, windowHeight), 3)

   end
   
   for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute 
      
      -- First compute determinants to see what side of the right and left lines we are on
      -- ILS course is between them

      lcd.setColor(lcd.getFgColor())
      
      if takeoff.RunwayHeading then
	 dr = (xtable[i]-xr1)*(yr2-yr1) - (ytable[i]-yr1)*(xr2-xr1)
	 dl = (xtable[i]-xl1)*(yl2-yl1) - (ytable[i]-yl1)*(xl2-xl1)
     
	 if dl >= 0 and dr <= 0 then
	    lcd.setColor(0,255,0) -- Green!
	 end
      end

      if i == #xtable then
 	 drawShape(toXPixel(xtable[i], map.Xmin, map.Xrange, windowWidth),
		   toYPixel(ytable[i], map.Ymin, map.Yrange, windowHeight),
		   shapes.T38, math.rad(heading-variables.magneticVar))
      else
	 lcd.drawCircle(toXPixel(xtable[i], map.Xmin, map.Xrange, windowWidth),
			toYPixel(ytable[i], map.Ymin, map.Yrange, windowHeight),
			2)
      end
   end

   lcd.setColor(lcd.getFgColor())
   drawBezier(windowWidth, windowHeight)
   drawGeo(windowWidth, windowHeight)

end

local function graphScale(x, y)

   if not map.Xmax then
      map.Xmax=   400
      map.Xmin = -400
      map.Ymax =  200
      map.Ymin = -200
   end
   
   if x > path.xmax then path.xmax = x end
   if x < path.xmin then path.xmin = x end
   if y > path.ymax then path.ymax = y end
   if y < path.ymin then path.ymin = y end
   
   map.Xrange = math.floor((path.xmax-path.xmin)/200 + .5) * 200 -- use 2:1 aspect ratio
   map.Yrange = math.floor((path.ymax-path.ymin)/100 + .5) * 100
   
   if map.Yrange > map.Xrange/(2) then
      map.Xrange = map.Yrange*(2)
   end
   if map.Xrange > map.Yrange*(2) then
      map.Yrange = map.Xrange/(2)
   end
   
   map.Xmin = path.xmin - (map.Xrange - (path.xmax-path.xmin))/2
   map.Xmax = path.xmax + (map.Xrange - (path.xmax-path.xmin))/2
   
   map.Ymin = path.ymin - (map.Yrange - (path.ymax-path.ymin))/2
   map.Ymax = path.ymax + (map.Yrange - (path.ymax-path.ymin))/2
   
end

local long0, lat0, coslat0
local rE = 21220539.7  -- 6371*1000*3.28084 radius of earth in ft, fudge factor of 1/0.985
local rad = 180/math.pi

local function initField()

   -- this function uses the GPS coords to see if we are near a known flying field in the jsn file
   -- and if it finds one, imports the field's properties 
   if long0 and lat0 then -- if location was detected by the GPS system
      for i=1, #geo.fields, 1 do -- see if we are near a known field (lat and long within ~ a mile)
	 if (math.abs(lat0 - geo.fields[i].runway.lat) < 1/60) -- 1/60 = 1 minute of arc
	 and (math.abs(long0 - geo.fields[i].runway.long) < 1/60) then
	    iField = i
	    long0 = geo.fields[iField].runway.long -- reset to origin to coords in jsn file
	    lat0  = geo.fields[iField].runway.lat
	    coslat0 = math.cos(math.rad(lat0))
	    variables.rotationAngle = geo.fields[iField].runway.trueDir-270 -- draw rwy along x axis
	    if geo.fields[iField].POI then
	       for i=1, #geo.fields[iField].POI,1 do
		  poi[i] = {x=rE*(geo.fields[iField].POI[i].long-long0)*coslat0/rad,
			    y=rE*(geo.fields[iField].POI[i].lat-lat0)/rad}
		  poi[i].x, poi[i].y = rotateXY(poi[i].x, poi[i].y, math.rad(variables.rotationAngle))
		  -- graphScale(poi[i].x, poi[i].y) -- maybe note in POI coords jsn if should autoscale or not?
	       end
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

-- presistent and global variables for loop()

local lastlat = 0
local lastlong = 0
local gotInitPos = false
local blocked = false
local timS = "0"
local compcrs
local compcrsDeg = 0
local vviAlt = {}
local vviTim = {}
local vvi, va
local ivvi = 1
local xd1, yd1
local xd2, yd2
local td1, td2
local lineAvgPts = 4  -- number of points to linear fit to compute course
local vviSlopeTime = 0
local speedTime = 0
local numGPSreads = 0
local timeRO = 0
local newPosTime = 0

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
      map.Xmax=   400
      map.Xmin = -400
      map.Ymax =  200
      map.Ymin = -200
      
      path.xmin = map.Xmin
      path.xmax = map.Xmax
      path.ymin = map.Ymin
      path.ymax = map.Ymax
      
      --reset baro alt zero too
      baroAltZero = altitude

      print("Reset origin and barometric altitude. New baroAltZero is ", baroAltZero)

--    dump(_G,"") -- print all globals for debuging

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
	 timS, latS, lonS, altS, spdS = string.match(tt, -- next string reads csv data -- really! :-)
	 "(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)"
	 )
	 latitude = tonumber(latS)
	 longitude = tonumber(lonS)
	 altitude = tonumber(altS)
	 speed = tonumber(spdS)
	 -- add code here to read heading once magneticVar decided to be included or not
	 blocked = true
	 return
      else
	 io.close(fd)
	 print('Closing csv file')
	 fd = nil
      end
   end

   if fd then print('Should not get here with fd true!') end

   sensor = system.getSensorByID(telem.Longitude.SeId, telem.Longitude.SePa)

   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative (NESW coded in decimal places as 0,1,2,3)
	 longitude = longitude * -1
      end
      goodlong = true
   end
   
   sensor = system.getSensorByID(telem.Latitude.SeId, telem.Latitude.SePa)

   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
      if sensor.decimals == 2 then -- "South" .. make it negative
	 latitude = latitude * -1
      end
      goodlat = true
   end
   
   sensor = system.getSensorByID(telem.Altitude.SeId, telem.Altitude.SePa)

   if(sensor and sensor.valid) then
      GPSAlt = sensor.value*3.28084 -- convert to ft, telem apis only report native values
   end
   
   sensor = system.getSensorByID(telem.SpeedNonGPS.SeId, telem.SpeedNonGPS.SePa)
   
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
   
   sensor = system.getSensorByID(telem.BaroAlt.SeId, telem.BaroAlt.SePa)
   
   if(sensor and sensor.valid) then
      baroAlt = sensor.value * 3.28084 -- unit conversion m to ft
   end
   
   
   sensor = system.getSensorByID(telem.SpeedGPS.SeId, telem.SpeedGPS.SePa)
   
   if(sensor and sensor.valid) then
      if sensor.unit == "kmh" or sensor.unit == "km/h" then
	 SpeedGPS = sensor.value * 0.621371 -- unit conversion to mph
      end
      if sensor.unit == "m/s" then
	 SpeedGPS = sensor.value * 2.23694
      end
   end

   sensor = system.getSensorByID(telem.DistanceGPS.SeId, telem.DistanceGPS.SePa)
   
   if(sensor and sensor.valid) then
      DistanceGPS = sensor.value*3.2808
   end      
   
   hasCourseGPS = false
   sensor = system.getSensorByID(telem.CourseGPS.SeId, telem.CourseGPS.SeId)
   if sensor and sensor.valid then
      courseGPS = sensor.value
      hasCourseGPS = true
   end

   sensor = system.getSensorByID(satCountID, satCountPa)
   if sensor and sensor.valid then
      satCount = sensor.value
   end

   sensor = system.getSensorByID(satQualityID, satQualityPa)
   if sensor and sensor.valid then
      satQuality = sensor.value
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
      -- print("Discarding reading: ", numGPSreads, latitude, longitude, goodlat, goodlong)
      return
   end
   
   ::fileInputLatLong::
   
   
   if (latitude == lastlat and longitude == lastlong) or (system.getTimeCounter() < newPosTime) then
      newpos = false
   else
      newpos = true
      
      if ff then
	 io.write(ff, string.format("%.4f, %.8f , %.8f , %.2f , %.2f , %.2f\n",
				    (system.getTimeCounter()-sysTimeStart)/1000.,
				    latitude, longitude, altitude, speed, (heading-variables.magneticVar) ) )
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

   x, y = rotateXY(x, y, math.rad(variables.rotationAngle)) -- q+d for now .. rotate path only add ILS+RW later
   
   if newpos or DEBUG then -- only enter a new xy in the "comet tail" if lat/lon changed
      
      if #xtable+1 > MAXTABLE then
	 table.remove(xtable, 1)
	 table.remove(ytable, 1)
      end
      
      table.insert(xtable, x)
      table.insert(ytable, y)

      graphScale(x, y)
      
      if #xtable == 1 then
	 path.xmin = map.Xmin
	 path.xmax = map.Xmax
	 path.ymin = map.Ymin
	 path.ymax = map.Ymax
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
      heading = compcrsDeg + variables.magneticVar
   else
      if hasCourseGPS and courseGPS then
	 heading = courseGPS + variables.magneticVar
      else
	 if compcrsDeg then
	    heading = compcrsDeg + variables.magneticVar
	 else
	    heading = 0
	 end
	    
      end
   end
   
   if (controls.Brake) then
      brk = system.getInputsVal(controls.Brake)
   end
   if brk and brk < 0 and takeoff.oldBrake > 0 then
      takeoff.BrakeReleaseTime = system.getTimeCounter()
      print("Brake release")
      system.playFile("Apps/DFM-LSO/brakes_released.wav", AUDIO_QUEUE)
   end
   if brk and brk > 0 then
      takeoff.BrakeReleaseTime = 0
      takeoff.Start.X = nil  -- erase the runway when the brakes go back on
      takeoff.Complete.X = nil
      takeoff.RunwayHeading = nil
      takeoff.NeverAirborne = true
      xr1 = nil -- recompute ILS points when new rwy coords
   end
   if brk  then
      takeoff.oldBrake = brk
      if DEBUG and brk < 0 then altitude = altitude + .15 end ------------------- DEBUG only
   end
   
   if (controls.Throttle) then
      thr = system.getInputsVal(controls.Throttle)
   end
   if thr and thr > 0 and takeoff.oldThrottle < 0 then
      if system.getTimeCounter() - takeoff.BrakeReleaseTime < 5000 then
	 takeoff.Start.X = x
	 takeoff.Start.Y = y
	 takeoff.Start.Z = altitude-baroAltZero
	 takeoff.ReleaseHeading = compcrsDeg + variables.magneticVar
	 print("Takeoff Start")
	 system.playFile("Apps/DFM-LSO/starting_takeoff_roll.wav", AUDIO_QUEUE)
      end
   end
   if thr then takeoff.oldThrottle = thr end
   
   if thr and thr > 0 and takeoff.Start.X and takeoff.NeverAirborne then
      if (altitude - baroAltZero) - takeoff.Start.Z > PATTERNALT/4 then
	 takeoff.NeverAirborne = false
	 takeoff.Complete.X = x
	 takeoff.Complete.Y = y
	 takeoff.Complete.Z = altitude - baroAltZero
	 takeoff.Heading = compcrsDeg + variables.magneticVar
	 local _, rDeg  = fslope({takeoff.Start.X, takeoff.Complete.X}, {takeoff.Start.Y, takeoff.Complete.Y})
	 takeoff.RunwayHeading = math.deg(rDeg) + variables.magneticVar
	 print("Runway length: ", math.sqrt((takeoff.Complete.X-takeoff.Start.X)^2 +
		     (takeoff.Complete.Y-takeoff.Start.Y)^2))
	 system.playFile("Apps/DFM-LSO/takeoff_complete.wav", AUDIO_QUEUE)
	 system.playNumber(heading, 0, "\u{B0}")
      end
   end
end

local ff, fd

local function init()

   local fname
   map.Xmin, map.Xmax = -400, 400
   map.Ymin, map.Ymax = -200, 200
   map.Xrange = map.Xmax - map.Xmin
   map.Yrange = map.Ymax - map.Ymin
   path.xmin, path.xmax, path.ymin, path.ymax = map.Xmin, map.Xmax, map.Ymin, map.Ymax

--[[
 
try opening the csv file for debugging .. we just give it a magic name for now. if it exists assume we will
do a playback. this is a kludge .. experimenting with pSave/pLoad of last log file but how to best ask if it 
should be replayed? Always ask and default to no? Initiate from a menu (hard to do since already running 
at that point)

--]]
   
   fname = system.pLoad("LogFile","...")
   print("Saved LogFile: ", fname)
   
   fd=io.open("Apps/DFM-LSO/DFM-LSO.csv", "r") -- "magic" name

   if fd then
      form.question("Start replay?", "log file DFM-LSO.csv", "---", 0, true, 0)
      print("Opened log file DFM-LSO.csv for reading")
   else
      if DEBUG == false then
	 local dt = system.getDateTime()
	 local fn = string.format("Log/DFM-LSO-%d%02d%02d-%d%02d%02d.csv",
				  dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec)
	 ff=io.open(fn, "w")
	 print("Opening for writing csv log file: ", fn)
	 system.pSave("LogFile", fn)
      end
   end

   local fg = io.readall("Apps/DFM-LSO/Shapes.jsn")
   if fg then
      shapes = json.decode(fg)
   else
      print("Could not open Apps/DFM-LSO/Shapes.jsn")
   end

   local fg = io.readall("Apps/DFM-LSO/Fields.jsn")
   if fg then
      geo = json.decode(fg)
   end

   for i, j in ipairs(telem) do
      telem[j].Se   = system.pLoad("telem."..telem[i]..".Se", 0)
      telem[j].SeId = system.pLoad("telem."..telem[i]..".SeId", 0)
      telem[j].SePa = system.pLoad("telem."..telem[i]..".SePa", 0)
   end

   for i, j in ipairs(controls) do
      controls[j] = system.pLoad("controls."..controls[i])
   end
   
   for i, j in ipairs(variables) do
      variables[j] = system.pLoad("variables."..variables[i], 0)
   end
   
   system.registerForm(1, MENU_APPS, "Landing Signal Officer", initForm, nil, nil)
   system.registerTelemetry(1, "LSO Map", 4, mapPrint)
   system.registerTelemetry(2, "LSO ILS", 4, ilsPrint)
   glideSlopePNG = lcd.loadImage("Apps/DFM-LSO/glideslope.png")
   
   -- print("Model: ", system.getProperty("Model"))
   -- print("Model File: ", system.getProperty("ModelFile"))
    
   system.playFile('Apps/DFM-LSO/L_S_O_active.wav', AUDIO_QUEUE)
   
   if DEBUG then
      print('L_S_O_Active.wav')
   end
    readSensors()
    collectgarbage()
end


-- setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=LSOVersion, name="GPS LSO"}
