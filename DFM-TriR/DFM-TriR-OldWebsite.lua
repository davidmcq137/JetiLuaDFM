--[[

   ---------------------------------------------------------------------------------------
   DFM-TriR.lua -- GPS triangle racing in a Jeti app

   Derived from DFM-LSO.lua -- "Landing Signal Officer" -- GPS Map and
   "ILS"/GPS RNAV system derived from DFM's Speed and Time Announcers,
   which were turn was derived from Tero's RCT's Alt Announcer
   Borrowed and modified code from Jeti's AH example for tapes and
   heading indicator.  New code to project Lat/Long via simple
   equirectangular projection to XY plane, and to compute heading from
   the projected XY plane track for GPS sensors that don't have this
   feature
    
   Developed on DS-24, only tested on DS-24

   ---------------------------------------------------------------------------------------
   Released under MIT license by DFM 2020
   ---------------------------------------------------------------------------------------

   Bug/Work list:

   --reset gps origin makes a mess .. no images

   --"no sats" displayed for gps's that have no satcount (e.g. pb gps II)

   --pylon zone line length proportional to tri length? (looks funny on A74)

   --alt (field elev) somehow persistent? was reading 160ish when telem was 0

   --allow baro/pitot sensors as optional?

--]]

local appInfo={}
appInfo.Name = "DFM-TriR"
appInfo.Maps = "DFM-TriM"
appInfo.Dir  = "Apps/" .. appInfo.Name .. "/"
appInfo.Fields = "Apps/" .. appInfo.Maps -- .."/"

--appInfo.Fields = appInfo.Dir .. "Fields/"


local latitude
local longitude 
local courseGPS = 0
local GPSAlt = 0
local heading = 0
local altitude = 0
local speed = 0
local SpeedGPS = 0
local binomC = {} -- array of binomial coefficients for n=MAXTABLE-1, indexed by k
local lng0, lat0, coslat0
-- 6378137 radius of earth in m
local rE = 6378137
local rad = 180/math.pi
local relBearing
local nextPylon=0
local arcFile
local lapAltitude
local distance
local x, y
   
local telem={"Latitude", "Longitude",   "Altitude",  "SpeedNonGPS",
	     "SpeedGPS", "DistanceGPS", "CourseGPS", "BaroAlt"}

telem.Latitude={}
telem.Longitude={}
telem.Altitude={}
telem.SpeedNonGPS={}
telem.SpeedGPS={}
telem.DistanceGPS={}
telem.CourseGPS={}
telem.BaroAlt={}

local variables = {"rotationAngle", "histSample", "histMax", "maxCPU",
		   "triLength", "maxSpeed", "maxAlt", "elev", "histDistance",
		   "raceTime", "aimoff", "flightStartAlt", "flightStartSpd"}

local xtable = {}
local ytable = {}
local MAXTABLE = 5
local map={}

local path={}
local bezierPath = {}

local shapes = {}
--local poi = {}
local pylon = {}
local nfc = {}
local nfp = {}
local tri = {}
local rwy = {}
local maxpolyX = 0.0
local Field = {}
local xHist={}
local yHist={}
local xHistLast=0
local yHistLast = 0
local countNoNewPos = 0
local currMaxCPU = 0
local gotInitPos = false
local annText
local annTextSeq = 1
local preText
local preTextSeq = 1
local titleText
local subtitleText
local lastgetTime = 0
local inZone = {}
local currentGPSread = 0
local lastGPSread = 0

-- these lists are the non-GPS sensors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }

local triEnabled
local triEnabledIndex
local noflyEnabled
local noflyEnabledIndex

local pointSwitch
local zoomSwitch
local triASwitch
local startSwitch

local raceParam = {}
raceParam.startToggled = false
raceParam.startArmed = false
raceParam.racing = false
raceParam.racingStartTime = 0
raceParam.lapStartTime = 0
raceParam.lapsComplete = 0
raceParam.lastLapTime = 0
raceParam.lastLapSpeed = 0
raceParam.avgSpeed = 0
raceParam.raceFinished = false
raceParam.raceEndTime = 0
raceParam.rawScore = 0
raceParam.penaltyPoints=0
raceParam.flightStarted=0
raceParam.flightLandTime=0

local fieldPNG={}
local maxImage
local currentImage
local textColor = {}
textColor.main = {red=0, green=0, blue=0}
textColor.comp = {red=255, green=255, blue=255}

local blueDotImage, greenDotImage, redDotImage
local emFlag

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

   
   local jt, paramGPS
   local sensorName = "..."
   local sensors = system.getSensors()
   local seSeq, param, label
   
   jt = io.readall(appInfo.Dir.."JSON/paramGPS.jsn")
   paramGPS = json.decode(jt)
   
   for _, sensor in ipairs(sensors) do
      --print("for loop:", sensor.sensorName, sensor.label, sensor.param, sensor.id)
      if (sensor.label ~= "") then
	 if sensor.param == 0 then -- it's a label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)
	 elseif sensor.type == 9 then  -- lat/long
	    table.insert(GPSsensorLalist, sensor.label)
	    seSeq = #GPSsensorLalist
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)
	 elseif sensor.type == 5 then -- date - ignore
	 else -- regular numeric sensor
	    table.insert(sensorLalist, sensor.label)
	    seSeq = #sensorLalist
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	 end

	 -- if it's not a label, and it's a sensor we have in the auto-assign table...
	 
	 if sensor.param ~= 0 and
	    paramGPS and
	    paramGPS[sensor.sensorName] and
	    paramGPS[sensor.sensorName][sensor.label]
	 then

	    --print("n,l,pG", sensor.sensorName, sensor.label, paramGPS[sensor.sensorName][sensor.label].telem, paramGPS[sensor.sensorName][sensor.label].param)
	    
	    param = paramGPS[sensor.sensorName][sensor.label].param
	    label  = paramGPS[sensor.sensorName][sensor.label].telem
	    --print("param, label:", param, label)
	    
	    if param and label then
	       if label == "SatCount" then
		  satCountID = sensor.id
		  satCountPa = param
	       elseif label == "SatQuality" then
		  satQualityID = sensor.id
		  satQualityPa = param
	       elseif label == "Altitude" then
		  --print("Altitude", paramGPS[sensor.sensorName][sensor.label].telem)
		  --print("AltType", paramGPS[sensor.sensorName][sensor.label].AltType)
		  if paramGPS and paramGPS[sensor.sensorName][sensor.label].AltType == "Rel" then
		     print("Rel!")
		     absAltGPS = false
		  else
		     print("Abs!")
		     absAltGPS = true
		  end
		  telem[label].Se = seSeq
		  telem[label].SeId = sensor.id
		  telem[label].SePa = param
	       else
		  telem[label].Se = seSeq
		  telem[label].SeId = sensor.id
		  telem[label].SePa = param
	       end
	    end
	 end
      end
   end
end


--[[
local function readSensors()

   local sensors = system.getSensors()

   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then

   --Note:
   --Digitech CTU Altitude is type 1, param 13 (vs. MGPS Altitude type 1, param 6)
   --MSpeed Velocity (airspeed) is type 1, param 1
	 
   --Code below will put sensor names in the choose list and auto-assign the relevant
   --selections for the Jeti MGPS, Digitech CTU and Jeti MSpeed

	 if sensor.param == 0 then -- it's a label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)
	 elseif sensor.type == 9 then  -- lat/long
	    table.insert(GPSsensorLalist, sensor.label)
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)
	    -- first two ifs are for MGPS, next two for RCT-GPS
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
	    if (sensor.label == 'Longitude' and sensor.param == 2) then
	       telem.Longitude.Se = #GPSsensorLalist
	       telem.Longitude.SeId = sensor.id
	       telem.Longitude.SePa = sensor.param
	    end
	    if (sensor.label == 'Latitude' and sensor.param == 1) then
	       telem.Latitude.Se = #GPSsensorLalist
	       telem.Latitude.SeId = sensor.id
	       telem.Latitude.SePa = sensor.param
	    end
	 --elseif sensor.type == 5 then
	    -- date - ignore
	 else  -- "regular" numeric sensor

	    table.insert(sensorLalist, sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)

	    if sensor.sensorName == "MSpeed" and sensor.param == 1 then
	       telem.SpeedNonGPS.Se = #sensorLalist
	       telem.SpeedNonGPS.SeId = sensor.id
	       telem.SpeedNonGPS.SePa = sensor.param
	    end
	    if sensor.sensorName == "CTU" and sensor.param == 13 then
	      telem.BaroAlt.Se = #sensorLalist
	      telem.BaroAlt.SeId = sensor.id
	      telem.BaroAlt.SePa = sensor.param
	    end

	    -- ADD any other baro alt sensors other than CTU here .. 

	    if (sensor.label == "Altitude" and sensor.param == 6) or
	       (sensor.label == "Altitude" and sensor.param == 5) then
	       telem.Altitude.Se = #sensorLalist
	       telem.Altitude.SeId = sensor.id
	       telem.Altitude.SePa = sensor.param
	    end
	    if (sensor.label == "Distance" and sensor.param == 7) then
	       telem.DistanceGPS.Se = #sensorLalist
	       telem.DistanceGPS.SeId = sensor.id
	       telem.DistanceGPS.SePa = sensor.param
	    end
	    if (sensor.label == "Speed" and sensor.param == 8) or
	       (sensor.label == "Speed" and sensor.param == 3) then
	       telem.SpeedGPS.Se = #sensorLalist
	       telem.SpeedGPS.SeId = sensor.id
	       telem.SpeedGPS.SePa = sensor.param
	    end
	    if (sensor.label == "Course" and sensor.param == 10) then
	       telem.CourseGPS.SeId = sensor.id
	       telem.CourseGPS.SePa = sensor.param
	    end
	    if (sensor.label == "SatCount" and sensor.param == 5) or
	       (sensor.label == "Satellites" and sensor.param == 10) then
	       satCountID = sensor.id
	       satCountPa = sensor.param
	    end
	    if (sensor.label == "Quality" and sensor.param == 4) or
	       (sensor.label == "HDOP" and sensor.param == 11) then
	       satQualityID = sensor.id
	       satQualityPa = sensor.param
	    end	    
	 end
      end
   end
end

--]]
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

local function variableChanged(value, var)
   variables[var] = value
   system.pSave("variables."..var, value)
end

local resetOrigin=false
local resetClick=false
local resetCompIndex
local timeRO = 0

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

local function pointSwitchChanged(value)
   pointSwitch = value
   system.pSave("pointSwitch", pointSwitch)
end

local function zoomSwitchChanged(value)
   zoomSwitch = value
   system.pSave("zoomSwitch", zoomSwitch)
end

local function triASwitchChanged(value)
   triASwitch = value
   system.pSave("triASwitch", triASwitch)
end

local function startSwitchChanged(value)
   startSwitch = value
   system.pSave("startSwitch", startSwitch)
end

--local function fieldIdxChanged(value)
--   print("please make fieldIdxChanged work again")
--   --fieldIdx = value
--   --iField = nil
--   gotInitPos = false
--end

local function triLengthChanged(value)
   variables.triLength = value
   system.pSave("variables.triLength", variables.triLength)
   pylon = {}
   --if Field then
   --   Field.triangle = value
   --   pylon = {}
   --end
end

local function raceTimeChanged(value)
   variables.raceTime = value
   system.pSave("variables.raceTime", variables.raceTime)
   print("racetime:", variables.raceTime)
end

local function maxSpeedChanged(value)
   variables.maxSpeed = value
   system.pSave("variables.maxSpeed", variables.maxSpeed)
   --if Field then Field.startMaxSpeed = value end
end

local function maxAltChanged(value)
   variables.maxAlt = value
   system.pSave("variables.maxAlt", variables.maxAlt)
   --if Field then Field.startMaxAltitude = value end
end

local function aimoffChanged(value)
   variables.aimoff = value
   system.pSave("variables.aimoff", variables.aimoff)
   --if Field then Field.aimoff = value end
   pylon={}
end

local function flightStartAltChanged(value)
   variables.flightStartAlt = value
   system.pSave("variables.flightStartAlt", variables.flightStartAlt)
end

local function flightStartSpdChanged(value)
   variables.flightStartSpd = value
   system.pSave("variables.flightStartSpd", variables.flightStartSpd)
end

local function elevChanged(value)
   if Field then Field.elevation = value end
end

local function annTextChanged(value)
   annText = value
   system.pSave("annText", annText)
end

local function preTextChanged(value)
   preText = value
   system.pSave("preText", preText)
end

local function triEnabledClicked(value)
   triEnabled = not value
   form.setValue(triEnabledIndex, triEnabled)
   system.pSave("triEnabled", tostring(triEnabled))
end

local function noflyEnabledClicked(value)
   noflyEnabled = not value
   form.setValue(noflyEnabledIndex, noflyEnabled)
   system.pSave("noflyEnabled", tostring(noflyEnabled))
end

--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)

local savedRow = 1

local function initForm(subform)
   if subform == 1 then

      form.addLink((function() form.reinit(2) end),
	 {label = "Telemetry Sensors >>"})

      form.addLink((function() form.reinit(3) end),
	 {label = "Race Parameters >>"})

      form.addLink((function() form.reinit(4) end),
	 {label = "Track History >>"})

      form.addLink((function() form.reinit(5) end),
	 {label = "Settings >>"})            

      form.addRow(1)
      form.addLabel({label="DFM - v 0.4", font=FONT_MINI, alignRight=true})

      form.setFocusedRow(savedRow)

   elseif subform == 2 then
      savedRow = subform-1
      local menuSelectGPS = { -- for lat/long only
	 Longitude="Select GPS Longitude Sensor",
	 Latitude ="Select GPS Latitude Sensor",
      }
      
      local menuSelect1 = { -- not from the GPS sensor
	 --SpeedNonGPS="Select Pitot Speed Sensor",
	 --BaroAlt="Select Baro Altimeter Sensor",
      }
      
      local menuSelect2 = { -- non lat/long but still from GPS sensor
	 Altitude ="Select GPS Altitude Sensor",
	 SpeedGPS="Select GPS Speed Sensor",
	 DistanceGPS="Select GPS Distance Sensor",
	 CourseGPS="Select GPS Course Sensor",
      }     
      
      for var, txt in pairs(menuSelectGPS) do
	 form.addRow(2)
	 form.addLabel({label=txt, width=220})
	 form.addSelectbox(GPSsensorLalist, telem[var].Se, true,
			   (function(z) return sensorChanged(z, var, true) end) )
      end
      
      
      for var, txt in pairs(menuSelect2) do
	 form.addRow(2)
	 form.addLabel({label=txt, width=220})
	 form.addSelectbox(sensorLalist, telem[var].Se, true,
			   (function(z) return sensorChanged(z, var, false) end) )
      end

      for var, txt in pairs(menuSelect1) do
	 form.addRow(2)
	 form.addLabel({label=txt, width=220})
	 form.addSelectbox(sensorLalist, telem[var].Se, true,
			   (function(z) return sensorChanged(z, var, false) end) )
      end
      
      form.addLink((function() form.reinit(1) end),
	 {label = "Back to main menu",font=FONT_BOLD})
      
   elseif subform == 4 then
      savedRow = subform-1
      -- not worth it do to a loop with a menu item table for Intbox due to the
      -- variation in defaults etc nor for addCheckbox due to specialized nature
      
      form.addRow(2)
      form.addLabel({label="History Sample Time (ms)", width=220})
      form.addIntbox(variables.histSample, 1000, 10000, 1000, 0, 100,
		     (function(z) return variableChanged(z, "histSample") end) )
      
      form.addRow(2)
      form.addLabel({label="Number of History Samples", width=220})
      form.addIntbox(variables.histMax, 0, 400, 240, 0, 10,
		     (function(z) return variableChanged(z, "histMax") end) )
      
      form.addRow(2)
      form.addLabel({label="Min Hist dist to new pt", width=220})
      form.addIntbox(variables.histDistance, 1, 10, 3, 0, 1,
		     (function(z) return variableChanged(z, "histDistance") end) )
      
      form.addRow(2)
      form.addLabel({label="Max CPU usage permitted (%)", width=220})
      form.addIntbox(variables.maxCPU, 0, 100, 80, 0, 1,
		     (function(z) return variableChanged(z, "maxCPU") end) )
      
      form.addRow(2)
      form.addLabel({label="Flight path points on/off sw", width=220})
      form.addInputbox(pointSwitch, false, pointSwitchChanged)
      
      form.addLink((function() form.reinit(1) end),
	 {label = "Back to main menu",font=FONT_BOLD})
      
   elseif subform ==3 then
      savedRow = subform-1

      form.addRow(2)
      form.addLabel({label="Enable Triangle Racecourse", width=270})
      triEnabledIndex = form.addCheckbox(triEnabled, triEnabledClicked)

      form.addRow(2)
      form.addLabel({label="Triangle racing ann switch", width=220})
      form.addInputbox(triASwitch, false, triASwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Triangle racing START switch", width=220})
      form.addInputbox(startSwitch, false, startSwitchChanged)
      
      --form.addRow(2)
      --form.addLabel({label="Triangle leg", width=220})
      --if Field and Field.triangle then variables.triLength = Field.triangle end 
      --form.addIntbox(variables.triLength, 10, 1000, 500, 0, 10, triLengthChanged)
      
      form.addRow(2)
      form.addLabel({label="Triangle race time (m)", width=220})
      form.addIntbox(variables.raceTime, 1, 60, 30, 0, 1, raceTimeChanged)
      
      form.addRow(2)
      form.addLabel({label="Max Start Speed (km/h)", width=220})
      --if Field and Field.startMaxSpeed then variables.maxSpeed = Field.startMaxSpeed end
      form.addIntbox(variables.maxSpeed, 10, 500, 100, 0, 10, maxSpeedChanged)
      
      form.addRow(2)
      form.addLabel({label="Max Start Alt (m)", width=220})
      --if Field and Field.startMaxAltitude then variables.maxAlt = Field.startMaxAltitude end
      form.addIntbox(variables.maxAlt, 10, 500, 100, 0, 10, maxAltChanged)
      
      form.addRow(2)
      form.addLabel({label="Turn point aiming offset (m)", width=220})
      --if Field and Field.aimoff then variables.aimoff = Field.aimoff end
      form.addIntbox(variables.aimoff, 0, 500, 50, 0, 1, aimoffChanged)

      form.addRow(2)
      form.addLabel({label="Flight Start Speed (km/h)", width=220})
      form.addIntbox(variables.flightStartSpd, 0, 100, 20, 0, 1, flightStartSpdChanged)

      form.addRow(2)
      form.addLabel({label="Flight Start Altitude (m)", width=220})
      form.addIntbox(variables.flightStartAlt, 0, 100, 20, 0, 1, flightStartAltChanged)

      form.addRow(2)
      form.addLabel({label="Racing announce sequence", width=220})
      form.addTextbox(annText, 30, annTextChanged)
      
      form.addRow(2)
      form.addLabel({label="Pre-race announce sequence", width=220})
      form.addTextbox(preText, 30, preTextChanged)

      form.addLink((function() form.reinit(1) end),
	 {label = "Back to main menu",font=FONT_BOLD})

   elseif subform == 5 then
      savedRow = subform-1
      form.addRow(2)
      form.addLabel({label="Show NoFly Zones", width=270})
      noflyEnabledIndex = form.addCheckbox(noflyEnabled, noflyEnabledClicked)

      form.addRow(2)
      form.addLabel({label="Field elev (m)", width=220})
      form.addIntbox(variables.elev, 0, 1000, 100, 0, 1, elevChanged)
      
      form.addRow(2)
      form.addLabel({label="Zoom reset sw", width=220})
      form.addInputbox(zoomSwitch, false, zoomSwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Reset GPS origin and Baro Alt", width=274})
      resetCompIndex=form.addCheckbox(resetClick, resetOriginChanged)
      
      form.addLink((function() form.reinit(1) end),
	 {label = "Back to main menu",font=FONT_BOLD})
   end
end

-- Various shape and polyline functions using the anti-aliasing renderer


local function drawShape(col, row, shape, rotation)
   local sinShape, cosShape
   local ren=lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

--local function drawShapePL(col, row, shape, rotation, scale, width, alpha)
--   local sinShape, cosShape
--   local ren=lcd.renderer()
--   sinShape = math.sin(rotation)
--   cosShape = math.cos(rotation)
--   ren:reset()
--   for _, point in pairs(shape) do
--      ren:addPoint(
--	 col + (scale*point[1] * cosShape - scale*point[2] * sinShape),
--	 row + (scale*point[1] * sinShape + scale*point[2] * cosShape))
--   end
--   ren:renderPolyline(width, alpha)
--end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function setColorMap()
   -- when text and graphics overlayed on a map, best to use yellow
   -- set comp color to 255-fg
   if fieldPNG[currentImage] then   
      textColor.main.red, textColor.main.green, textColor.main.blue = 255, 255,   0
      textColor.comp.red, textColor.comp.green, textColor.comp.blue =   0,   0, 255
   end
   lcd.setColor(textColor.main.red, textColor.main.green, textColor.main.blue)   
end

local function setColorNoFlyInside()
   lcd.setColor(255,0,0)
end

local function setColorNoFlyOutside()
   lcd.setColor(0,255,0)
end

local function setColorMain()
   lcd.setColor(textColor.main.red, textColor.main.green, textColor.main.blue)
end

--local function setColorComp()
--   lcd.setColor(textColor.comp.red, textColor.comp.green, textColor.comp.blue)
--end


local text

local function playFile(fn, as)
   if emFlag then
      local fp = io.open(fn)
      if not fp then
	 print("Cannot open file "..fn)
      else
	 io.close(fp)
	 --print("Playing file "..fn.." status: "..as)
      end
   end
   if as == AUDIO_IMMEDIATE then
      system.stopPlayback()
   end
   system.playFile("/"..fn, as)
end

local function playNumber(n, dp)
   system.playNumber(n, dp)
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

local function fslope(xx, yy)

    local xbar, ybar, sxy, sx2 = 0,0,0,0
    local theta, tt, slope
    
    for i = 1, #xx do
       xbar = xbar + xx[i]
       ybar = ybar + yy[i]
    end

    xbar = xbar/#xx
    ybar = ybar/#yy

    for i = 1, #xx do
        sxy = sxy + (xx[i]-xbar)*(yy[i]-ybar)
        sx2 = sx2 + (xx[i] - xbar)^2
    end
    
    if sx2 < 1.0E-6 then -- would it be more proper to set slope to inf and let atan do its thing?
       sx2 = 1.0E-6      -- or just let it div0 and set to inf itself?
    end                  -- for now this is only a .00001-ish degree error
    
    slope = sxy/sx2
    
    theta = math.atan(slope)

    if xx[1] < xx[#xx] then
       tt = math.pi/2 - theta
    else
       tt = math.pi*3/2 - theta
    end
 
    return slope, tt
end

--local function slope_to_deg(yy, xx)
--   return math.deg(math.atan(yy, xx))
--end

local function binom(n, k)
   
   -- compute binomial coefficients to then compute the Bernstein polynomials for Bezier
   -- n will always be MAXTABLE-1 once past initialization
   -- as we compute for each k, remember in a table and save
   -- for MAXTABLE = 5, there are only ever 3 values needed in steady state: (4,0), (4,1), (4,2)
   
   if k > n then return nil end  -- error .. let caller die
   if k > n/2 then k = n - k end -- because (n k) = (n n-k) by symmetry

   --print("binom: n,k=", n, k)
   
   if (n == MAXTABLE-1) and binomC[k] then return binomC[k] end

   local numer, denom = 1, 1

   for i = 1, k do
      numer = numer * ( n - i + 1 )
      denom = denom * i
   end

   if n == MAXTABLE-1 then
      binomC[k] = numer / denom
      return binomC[k]
   else
      return numer / denom
   end
   
end

local function computeBezier(numT)


      -- compute Bezier curve points using control points in xtable[], ytable[]
      -- with numT points over the [0,1] interval
   
   local px, py
   local t, bn
   local ti, oti
   local n = #xtable-1

   for j = 0, numT, 1 do
      t = j / numT
      px, py = 0, 0
      --dx, dy = 0, 0

      ti = 1 -- first loop t^i = 0^0 which lua says is 1
      for i = 0, n do
	 -- see: https://pages.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/bezier-der.html
	 -- for Bezier derivatives
	 -- 11/30/18 was not successful in getting bezier derivatives to improve heading calcs
	 -- code commented out
	 oti = (1-t)^(n-i)
	 bn = binom(n, i)*ti*oti
	 px = px + bn * xtable[i+1]
	 py = py + bn * ytable[i+1]
	 ti = ti * t
      end
      bezierPath[j+1]  = {x=px,   y=py}
      
   end
end

local function drawBezier(windowWidth, windowHeight, yoff)

      
   local ren=lcd.renderer()   
   -- draw Bezier curve points computed in computeBezier()

   if not bezierPath[1]  then return end

   ren:reset()

   for j=1, #bezierPath do
      ren:addPoint(toXPixel(bezierPath[j].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(bezierPath[j].y, map.Ymin, map.Yrange, windowHeight)+yoff)
   end
   ren:renderPolyline(3)

end

local function m3(i)
   return (i-1)%3 + 1
end

--local function m4(i)
--   return (i-1)%4 + 1
--end

--local function mN(i, N)
--   return (i-1)%N + 1
--end

local function perpDist(x0, y0, np)
   local pd
   local det
   local nextP = m3(np)
   local lastP = m3(nextP + 2)
   --print("nextP, lastP:", nextP, lastP)
   
   pd = math.abs(
         (pylon[nextP].y-pylon[lastP].y) * x0 -
	 (pylon[nextP].x-pylon[lastP].x)*y0 +
	  pylon[nextP].x*pylon[lastP].y -
	  pylon[nextP].y*pylon[lastP].x) /
          math.sqrt( (pylon[nextP].y-pylon[lastP].y)^2 +
	  (pylon[nextP].x-pylon[lastP].x)^2)
   --print("pd:", pd)
   det = (x0-pylon[lastP].x)*(pylon[nextP].y-pylon[lastP].y) -
      (y0-pylon[lastP].y)*(pylon[nextP].x-pylon[lastP].x)
   --print("det:", det)
   
   if det >= 0 then return pd else return -pd end
end

local function vertHistogram(x0, y0, val, scale, hgt, wid, vald)

   lcd.setColor(0,0,0)
   
   lcd.drawRectangle(x0 - wid/2, y0 - hgt, wid, 2*hgt - 1)
   lcd.drawLine(x0 - wid/2, y0, x0 + wid/2 - 1, y0)
   
   local a = math.min(math.abs(val) / scale, 1)

   if val > 0 then
      lcd.setColor(0,255,0)
      lcd.drawFilledRectangle(x0 - wid/2, y0 - hgt * a+1, wid, hgt * a)
   else
      lcd.setColor(255,0,0)
      lcd.drawFilledRectangle(x0 - wid/2, y0, wid, hgt * a)
   end
   lcd.setColor(0,0,0)

   if vald then
      lcd.drawText(x0+wid, y0 -lcd.getTextHeight(FONT_BOLD)/2, string.format("%4.1f m", vald), FONT_BOLD)
   end
   
   lcd.drawText(x0 + wid - 5, y0 - hgt, string.format("+%dm", scale), FONT_MINI)
   lcd.drawText(x0 + wid - 5, y0 + hgt - lcd.getTextHeight(FONT_MINI), string.format("-%dm", scale), FONT_MINI)   
   
		
   
end

local lastsws
local lastdetS1 = -1
--local lastMin=0
local inZoneLast = {}

local function drawTriRace(windowWidth, windowHeight)

   local ren=lcd.renderer()

   if not triEnabled then return end
   if not pylon[1] then return end
   
   setColorMap()

   for j=1, #pylon do
      local txt = string.format("%d", j)
      lcd.drawText(
      toXPixel(pylon[j].x, map.Xmin, map.Xrange, windowWidth) -
	 lcd.getTextWidth(FONT_MINI,txt)/2,
      toYPixel(pylon[j].y, map.Ymin, map.Yrange, windowHeight) -
	 lcd.getTextHeight(FONT_MINI)/2 + 15,txt, FONT_MINI)
   end

   setColorMain()
   -- draw line from airplane to the aiming point
   if raceParam.racing then
      lcd.setColor(255,20,147) -- magenta ... like a flight director..
      lcd.drawLine(toXPixel(xtable[#xtable], map.Xmin, map.Xrange, windowWidth),
		   toYPixel(ytable[#ytable], map.Ymin, map.Yrange, windowHeight),
	   toXPixel(pylon[m3(nextPylon)].xt, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[m3(nextPylon)].yt, map.Ymin, map.Yrange, windowHeight) )
   end
   

   lcd.setColor(153,153,255)
   
   -- draw the triangle race course
   ren:reset()
   for j = 1, #pylon + 1 do

      ren:addPoint(toXPixel(pylon[m3(j)].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[m3(j)].y, map.Ymin, map.Yrange, windowHeight) )
   end
   ren:renderPolyline(2, 0.7)
   
   -- draw the startline
   ren:reset()
   ren:addPoint(toXPixel(pylon[2].x, map.Xmin, map.Xrange, windowWidth),
		toYPixel(pylon[2].y, map.Ymin, map.Yrange, windowHeight))
   ren:addPoint(toXPixel(pylon.start.x, map.Xmin, map.Xrange, windowWidth),
		toYPixel(pylon.start.y,map.Ymin,map.Yrange,windowHeight))
   ren:renderPolyline(2,0.7)

   setColorMain()

   -- draw the turning zones and the aiming points. The zones turn red when the airplane
   -- is in them .. the aiming point you are flying to is red.
   
   for j = 1, #pylon do
      if raceParam.racing and inZone[j] then lcd.setColor(255,0,0) end
      lcd.drawLine(toXPixel(pylon[j].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[j].y, map.Ymin, map.Yrange, windowHeight),
		   toXPixel(pylon[j].zxl,map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[j].zyl,map.Ymin, map.Yrange, windowHeight) )
      lcd.drawLine(toXPixel(pylon[j].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[j].y, map.Ymin, map.Yrange, windowHeight),
		   toXPixel(pylon[j].zxr, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[j].zyr, map.Ymin, map.Yrange, windowHeight) )
      if raceParam.racing and inZone[j] then setColorMain() end
      if raceParam.racing and j > 0 and j == m3(nextPylon) then lcd.setColor(255,0,0) end
      --if region[code] == j 
      lcd.drawCircle(toXPixel(pylon[j].xt, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(pylon[j].yt, map.Ymin, map.Yrange, windowHeight),
		     4)
      lcd.drawCircle(toXPixel(pylon[j].xt, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(pylon[j].yt, map.Ymin, map.Yrange, windowHeight),
		     2)
      if raceParam.racing and j > 0 and j == m3(nextPylon) then setColorMain() end
      --if region[code] == j 
   end

   if titleText then
      lcd.drawText((310 - lcd.getTextWidth(FONT_BOLD, titleText))/2, 0,
	 titleText, FONT_BOLD)
   end
   
   if subtitleText then
      lcd.drawText((310 - lcd.getTextWidth(FONT_MINI, subtitleText))/2, 17,
	 subtitleText, FONT_MINI)
   end
   

   if raceParam.flightStarted ~= 0 then
      lcd.drawImage(5, 100, greenDotImage)
   else
      lcd.drawImage(5,100, redDotImage)
   end

   if raceParam.startArmed then
      if raceParam.racing then
	 lcd.drawImage(25, 100, blueDotImage)
      else
	 lcd.drawImage(25, 100, greenDotImage)
      end
   else
      if startSwitch then lcd.drawImage(25, 100, redDotImage) end
   end
   
   lcd.drawText(5, 120, "Spd: "..math.floor(speed), FONT_MINI)
   lcd.drawText(5, 130, "Alt: ".. math.floor(altitude), FONT_MINI)
   lcd.drawText(5, 140, string.format("Map: %d", map.Xrange), FONT_MINI)

   --lcd.drawText(265, 35, string.format("NxtP %d (%d)", region[code], code), FONT_MINI)
   --lcd.drawText(265, 45, string.format("Dist %.0f", distance), FONT_MINI)
   --lcd.drawText(265, 55, string.format("Hdg  %.1f", heading), FONT_MINI)
   --lcd.drawText(265, 65, string.format("TCrs %.1f", vd), FONT_MINI)
   --lcd.drawText(265, 75, string.format("RelB %.1f", relBearing), FONT_MINI)
   --if speed ~= 0 then
   --   lcd.drawText(265, 85, string.format("Time %.1f", distance / speed), FONT_MINI)
   --end

end

local function calcTriRace()

   local detS1
   local ao

   if not Field or not Field.name then return end
   if not triEnabled then return end
   
   if Field then
      ao = variables.aimoff
   else
      ao = 0
   end

   --print("ao=", ao)
   
   --if Field and Field.aimoff then
   --   ao = Field.aimoff
   --else
   --   ao = 0
   --end
   
   -- if no course computed yet, start by defining the pylons

   if #pylon < 1 and Field.name then -- need to confirm with RFM order of vertices
      pylon[1] = {x=tri[2].x ,y=tri[2].y,aimoff=ao}
      if Field.extend then
	 pylon[2] = {x=tri[1].x,y=tri[1].y + Field.extend,aimoff=ao}
      else
	 pylon[2] = {x=tri[1].x,y=tri[1].y,aimoff=ao}
      end
      pylon[3] = {x=tri[3].x,y=tri[3].y,aimoff=ao}
   end

   -- extend startline below hypotenuse of triangle  by 0.8x inside length
   pylon.start = {x=tri.center.x + 0.8 * (tri.center.x - pylon[2].x) ,
		  y=tri.center.y + 0.8 * (tri.center.y - pylon[2].y)}

   --local region={2,3,3,1,2,1,0}

   -- first time thru, compute all the ancillary data that goes with each pylon
   -- xm, ym is midpoint of opposite side from vertex
   -- xe, ye is the extension of the midpoint to vertex line
   -- xt, yt is the "target" or aiming point
   -- z*, y* are the left and right sides of the turning zones
   
   if (#pylon > 0) and (not pylon[1].xm) then
      for j=1, #pylon do
	 local zx, zy
	 local rot = {math.rad(-112.5), 0, math.rad(112.5)}
	 pylon[j].xm = (pylon[m3(j+1)].x + pylon[m3(j+2)].x ) / 2.0
	 pylon[j].ym = (pylon[m3(j+1)].y + pylon[m3(j+2)].y ) / 2.0
	 pylon[j].xe = 2 * pylon[j].x - pylon[j].xm
	 pylon[j].ye = 2 * pylon[j].y - pylon[j].ym
	 pylon[j].alpha = pylon[j].aimoff /
	    math.sqrt( (pylon[j].x - pylon[j].xm)^2 + (pylon[j].y - pylon[j].ym)^2 )
	 pylon[j].xt = (1+pylon[j].alpha) * pylon[j].x - pylon[j].alpha*pylon[j].xm
	 pylon[j].yt = (1+pylon[j].alpha) * pylon[j].y - pylon[j].alpha*pylon[j].ym
	 zx, zy = rotateXY(-0.4 * variables.triLength, 0.4 * variables.triLength, rot[j])
	 pylon[j].zxl = zx + pylon[j].x
	 pylon[j].zyl = zy + pylon[j].y
	 zx, zy = rotateXY(0.4 * variables.triLength, 0.4 * variables.triLength, rot[j])
	 pylon[j].zxr = zx + pylon[j].x
	 pylon[j].zyr = zy + pylon[j].y
	 inZoneLast[j] = false
      end
   end
   
   -- compute determinants off the turning zone left and right lines
   -- to see if the aircraft is in one of the turning zones

   local detL = {}
   local detR = {}
   for j=1, #pylon do
      detL[j] = (xtable[#xtable]-pylon[j].x)*(pylon[j].zyl-pylon[j].y) -
	 (ytable[#ytable]-pylon[j].y)*(pylon[j].zxl-pylon[j].x)
      detR[j] = (xtable[#xtable]-pylon[j].x)*(pylon[j].zyr-pylon[j].y) -
	 (ytable[#ytable]-pylon[j].y)*(pylon[j].zxr-pylon[j].x)
      inZone[j] = detL[j] >= 0 and detR[j] <= 0
      if inZone[j] ~= inZoneLast[j] and j == nextPylon and raceParam.racing then
	 if inZone[j] == true then
	    --playFile(appInfo.Dir.."Audio/inside_sector.wav", AUDIO_IMMEDIATE)
	    --playNumber(j, 0)
	    system.vibration(false, 1)
	    system.playBeep(m3(j)-1, 800, 400)
	    playFile(appInfo.Dir.."Audio/next_pylon.wav", AUDIO_IMMEDIATE)
	    playNumber(m3(j+1), 0)
	 end
	 inZoneLast[j] = inZone[j]
      end
   end

   -- now compute determinants off the midpoint to vertext lines to find
   -- out which of the six zones around the triangle the plane is in
   -- use a binary code to number the zones
   
   local det = {}
   for j=1, #pylon do
      det[j] = (xtable[#xtable]-pylon[j].x)*(pylon[j].ye-pylon[j].y) -
	 (ytable[#ytable]-pylon[j].y)*(pylon[j].xe-pylon[j].x)
   end
   
   local p2=1
   local code=0
   for j = 1, #pylon do
      code = code + (det[j] >= 0 and 0 or 1)*p2
      p2 = p2 * 2
   end

   if code < 1 or code > 6 then
      print("code out of range")
      return
   end

   if #xtable < 1 then -- no points yet...
      return
   end
   
   -- see if we have taken off

   if speed  > variables.flightStartSpd and
   altitude > variables.flightStartAlt and raceParam.flightStarted == 0 then
      raceParam.flightStarted = system.getTimeCounter()
      playFile(appInfo.Dir.."Audio/flight_started.wav", AUDIO_IMMEDIATE)      
   end

   -- see if we have landed
   -- we need to see if it stays in this state for more than 5s (5000 ms)
   
   if raceParam.flightStarted ~= 0  and altitude < 20 and speed < 5 and not raceParam.raceFinished then
      if raceParam.flightLandTime == 0 then
	 raceParam.flightLandTime = system.getTimeCounter()
      end
      --print(system.getTimeCounter() - raceParam.flightLandTime)
      if system.getTimeCounter() - raceParam.flightLandTime  > 5000 then
	 playFile(appInfo.Dir.."Audio/flight_ended.wav", AUDIO_QUEUE)
	 raceParam.racing = false
	 raceParam.raceFinished = true
	 raceParam.raceEndTime = system.getTimeCounter()
	 raceParam.startArmed = false
      end
   else
      raceParam.flightLandTime = 0
   end

-- start zone is left half plane divided by start line
   detS1 = xtable[#xtable]

   local inStartZone
   if detS1 <= 0 then inStartZone = true else inStartZone = false end
   
   -- read the start switch
   
   local sws
   
   if startSwitch then
      sws = system.getInputsVal(startSwitch)
   end

   if startSwitch and sws then
      if sws ~= lastsws then
	 if sws == 1 then
	    raceParam.startToggled = true
	 else
	    raceParam.startToggled = false
	    raceParam.startArmed = false
	 end
      end
      lastsws = sws
   end

   -- see if racer wants to abort e.g. penalty start rejected
   if raceParam.racing and not raceParam.startToggled then
      raceParam.racing = false
      --raceParam.raceFinished = true
      raceParam.startArmed = false
      --raceParam.raceEndTime = system.getTimeCounter()
   end
   
   
   -- see if we are ready to start
   if raceParam.startToggled and not raceParam.startArmed then --and not raceParam.raceFinished then
      if inStartZone and raceParam.flightStarted ~= 0 then
	 playFile(appInfo.Dir.."Audio/ready_to_start.wav", AUDIO_IMMEDIATE)
	 raceParam.startArmed = true
	 nextPylon = 0
	 raceParam.lapsComplete = 0
      else
	 --playFile(appInfo.Dir.."Audio/bad_start.wav", AUDIO_IMMEDIATE)
	 if not inStartZone and not raceParam.raceFinished then
	    playFile(appInfo.Dir.."Audio/outside_zone.wav", AUDIO_QUEUE)
	 end
	 if raceParam.flightStarted == 0 then
	    playFile(appInfo.Dir.."Audio/flight_not_started.wav", AUDIO_QUEUE)
	 end
	 -- could there be other reasons (altitude/nofly zones?) .. they go here
	 raceParam.startArmed = false
	 raceParam.startToggled = false
      end
   end

   -- this if determines we just crossed the start/finish line
   -- now just left of origin ... does not have to be below hypot.
   
   if lastdetS1 <= 0 and detS1 >= 0 then
      if raceParam.racing then
	 if nextPylon > 3 then -- lap complete
	    system.playBeep(0, 800, 400)
	    playFile(appInfo.Dir.."Audio/lap_complete.wav", AUDIO_IMMEDIATE)
	    raceParam.lapsComplete = raceParam.lapsComplete + 1
	    raceParam.rawScore = raceParam.rawScore + 200.0
	    raceParam.lastLapTime = system.getTimeCounter() - raceParam.lapStartTime
	    lapAltitude = altitude
	    -- lap speed in km/h is 3.6 * speed in m/s
	    local perim = (variables.triLength * 2 * (1 + math.sqrt(2))) 
	    raceParam.lastLapSpeed = 3.6 * perim / (raceParam.lastLapTime / 1000)
	    raceParam.avgSpeed = 3.6*perim*raceParam.lapsComplete /
	       ((system.getTimeCounter()-raceParam.racingStartTime) / 1000)
	    raceParam.lapStartTime = system.getTimeCounter()
	    nextPylon = 1
	 end
      end
      
      if not raceParam.racing and raceParam.startArmed then
	 if speed  > variables.maxSpeed or altitude > variables.maxAlt then
	    playFile(appInfo.Dir.."Audio/start_with_penalty.wav", AUDIO_QUEUE)	    
	    if speed  > variables.maxSpeed then
	       playFile(appInfo.Dir.."Audio/over_max_speed.wav", AUDIO_QUEUE)
	       print("speed, variables.maxSpeed", speed, variables.maxSpeed)
	    end
	    if altitude > variables.maxAlt then
	       playFile(appInfo.Dir.."Audio/over_max_altitude.wav", AUDIO_QUEUE)
	    end
	    raceParam.penaltyPoints = 50 + 2 * math.max(speed - variables.maxSpeed, 0) + 2 *
	       math.max(altitude - variables.maxAlt, 0)
	    playFile(appInfo.Dir.."Audio/penalty_points.wav", AUDIO_QUEUE)
	    playNumber(math.floor(raceParam.penaltyPoints+0.5), 0)
	 else
	    playFile(appInfo.Dir.."Audio/task_starting.wav", AUDIO_QUEUE)
	    raceParam.penaltyPoints = 0
	    lapAltitude = altitude
	 end
	 raceParam.racing = true
	 raceParam.raceFinished = false
	 raceParam.racingStartTime = system.getTimeCounter()
	 nextPylon = 1
	 raceParam.lapStartTime = system.getTimeCounter()
	 raceParam.lapsComplete = 0
	 raceParam.rawScore = 0
      end
   end

   lastdetS1 = detS1
   
   local sgTC = system.getTimeCounter()

   --print( (sgTC - raceParam.racingStartTime) / 1000, variables.raceTime*60)
   if raceParam.racing and (sgTC - raceParam.racingStartTime) / 1000 >= variables.raceTime*60 then
      playFile(appInfo.Dir.."Audio/race_finished.wav", AUDIO_IMMEDIATE)	    	 
      raceParam.racing = false
      raceParam.raceFinished = true
      raceParam.startArmed = false
      raceParam.raceEndTime = sgTC
   end

   if raceParam.racing then
      if inZone[nextPylon] then
	 --print("incr nextPylon")
	 nextPylon = nextPylon + 1 -- will go to "4" after passing pylon 3
      end
   end

   if raceParam.racing or (raceParam.raceFinished and raceParam.lapsComplete > 0) then

      if raceParam.raceFinished and raceParam.lapsComplete > 0 then
	 sgTC = raceParam.raceEndTime
      else
	 sgTC = system.getTimeCounter()
      end
      
      local tsec = (sgTC - raceParam.racingStartTime) / 1000.0
      
      local tmin = tsec // 60
      --if tmin ~= lastMin and tmin > 0 then
	 -- no mins announcement for now .. maybe on a switch/on demand, speech? tilt?
	 --playNumber(tmin, 0)
	 --if tmin == 1 then
	 --   playFile(appInfo.Dir.."Audio/minutes.wav", AUDIO_QUEUE)
	 --else
	 --   playFile(appInfo.Dir.."Audio/minutes.wav", AUDIO_QUEUE)
	 --end
      --end
      --lastMin = tmin
      
      tsec = tsec - tmin*60
      titleText = string.format("%02d:%04.1f / ", tmin, tsec)
      
      
      tsec = (sgTC - raceParam.lapStartTime) / 1000.0
      tmin = tsec // 60
      tsec = tsec - tmin*60      
      titleText = titleText ..string.format("%02d:%04.1f / ",
				  tmin, tsec)

      tsec = raceParam.lastLapTime / 1000.0
      tmin = tsec // 60
      tsec = tsec - tmin*60
      titleText = titleText .. string.format("%02d:%04.1f / ", tmin, tsec)

      titleText = titleText .. string.format("%.1f / ", raceParam.avgSpeed)

      titleText = titleText .. string.format("%.1f", raceParam.lastLapSpeed)

      
      --lcd.drawText((310 - lcd.getTextWidth(FONT_BOLD, tstr))/2, 0,
      --tstr, FONT_BOLD)

      subtitleText = string.format("Laps: %d, Net Score: %d, Penalty: %d",
			   raceParam.lapsComplete, math.floor(raceParam.rawScore - raceParam.penaltyPoints + 0.5),
			   math.floor(raceParam.penaltyPoints + 0.5))
      --lcd.drawText((310 - lcd.getTextWidth(FONT_MINI, tstr))/2, 17, tstr, FONT_MINI)
   end

   -- compute dist and relative bearing to aim point
   
--   local distance = math.sqrt( (xtable[#xtable] - pylon[region[code]].xt)^2 +
--	 (ytable[#ytable] - pylon[region[code]].yt)^2 )

--   local xt = {xtable[#xtable], pylon[region[code]].xt}
--   local yt = {ytable[#ytable], pylon[region[code]].yt}

   distance = math.sqrt( (xtable[#xtable] - pylon[m3(nextPylon)].xt)^2 +
	 (ytable[#ytable] - pylon[m3(nextPylon)].yt)^2 )

   local xt = {xtable[#xtable], pylon[m3(nextPylon)].xt}
   local yt = {ytable[#ytable], pylon[m3(nextPylon)].yt}

   local perpD = perpDist(xtable[#xtable], ytable[#ytable], nextPylon)
   
   local vd
   --_, vd = fslope(xt, yt)
   vd = select(2, fslope(xt, yt))
   vd = vd * 180 / math.pi
   relBearing = (heading - vd)
   if relBearing < -360 then relBearing = relBearing + 360 end
   if relBearing > 360 then relBearing = relBearing - 360 end
   if relBearing < -180 then relBearing = 360 + relBearing end
   if relBearing >  180 then relBearing = relBearing - 360 end

   local swa
   
   if triASwitch then
      swa = system.getInputsVal(triASwitch)
   end
   
   local sChar
   local now = system.getTime()

   if now ~= lastgetTime and swa and swa == 1 then -- once a sec
      --print(m3(nextPylon+2), inZone[m3(nextPylon+2)] )
      if raceParam.racing then
	 annTextSeq = annTextSeq + 1
	 if annTextSeq > #annText then
	    annTextSeq = 1
	 end
	 sChar = annText:sub(annTextSeq,annTextSeq)
      else
	 preTextSeq = preTextSeq + 1
	 if preTextSeq > #preText then
	    preTextSeq = 1
	 end
	 sChar = preText:sub(preTextSeq,preTextSeq)
      end
      if (sChar == "C" or sChar == "c") and raceParam.racing then
	 if relBearing < -6 then
	    if sChar == "C" then
	       playFile(appInfo.Dir.."Audio/turn_right.wav", AUDIO_QUEUE)
	       playNumber(-relBearing, 0)
	    else
	       playFile(appInfo.Dir.."Audio/right.wav", AUDIO_QUEUE)
	       playNumber(-relBearing, 0)
	    end
	 elseif relBearing > 6 then
	    if sChar == "C" then
	       playFile(appInfo.Dir.."Audio/turn_left.wav", AUDIO_QUEUE)
	       playNumber(relBearing, 0)
	    else
	       playFile(appInfo.Dir.."Audio/left.wav", AUDIO_QUEUE)
	       playNumber(relBearing, 0)
	    end
	 else
	    system.playBeep(0, 1200, 200)		  
	 end
      elseif sChar == "D" or sChar == "d" and raceParam.racing then
	 if sChar == "D" then
	    playFile(appInfo.Dir.."Audio/distance.wav", AUDIO_QUEUE)
	    playNumber(distance, 0)
	 else
	    playFile(appInfo.Dir.."Audio/dis.wav", AUDIO_QUEUE)
	    playNumber(distance, 0)
	 end
      elseif (sChar == "P" or sChar == "p") and raceParam.racing and not inZone[m3(nextPylon+2)] then
	 if perpD < 0 then
	    if sChar == "P" then
	       playFile(appInfo.Dir.."Audio/inside.wav", AUDIO_QUEUE)
	       playNumber(-perpD, 0)
	    else
	       playFile(appInfo.Dir.."Audio/in.wav", AUDIO_QUEUE)
	       playNumber(-perpD, 0)
	    end
	 else
	    if sChar == "P" then
	       playFile(appInfo.Dir.."Audio/outside.wav", AUDIO_QUEUE)
	       playNumber(perpD, 0)
	    else
	       playFile(appInfo.Dir.."Audio/out.wav", AUDIO_QUEUE)
	       playNumber(perpD, 0)
	    end
	 end
      elseif sChar == "T" or sChar == "t" and raceParam.racing then
	 if speed ~= 0 then
	    playFile(appInfo.Dir.."Audio/time.wav", AUDIO_QUEUE)
	    playNumber(distance/speed, 1)	  
	 end
      elseif sChar == "S" or sChar == "s" then
	 playFile(appInfo.Dir.."Audio/speed.wav", AUDIO_QUEUE)
	 playNumber(math.floor(speed+0.5), 0)
      elseif sChar == "A" or sChar == "a" then
	 if sChar == "A" then
	    playFile(appInfo.Dir.."Audio/altitude.wav", AUDIO_QUEUE)
	    playNumber(math.floor(altitude+0.5), 0)
	 else
	    playFile(appInfo.Dir.."Audio/alt.wav", AUDIO_QUEUE)
	    playNumber(math.floor(altitude+0.5), 0)
	 end
      end
   end
   lastgetTime = now

   --lastregion = region[code]

end

-- next set of function acknowledge
-- https://www.geeksforgeeks.org/how-to-check-if-a-given-point-lies-inside-a-polygon/
-- ported to lua D McQ 7/2020

local function onSegment(p, q, r)
   if (q.x <= math.max(p.x, r.x) and q.x >= math.min(p.x, r.x) and 
            q.y <= math.max(p.y, r.y) and q.y >= math.min(p.y, r.y)) then
      return true
   else
      return false
   end
end

-- To find orientation of ordered triplet (p, q, r). 
-- The function returns following values 
-- 0 --> p, q and r are colinear 
-- 1 --> Clockwise 
-- 2 --> Counterclockwise 
local function orientation(p, q, r) 
   local val
   val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
   if (val == 0) then return 0 end  -- colinear 
   return val > 0 and 1 or 2
end

-- The function that returns true if line segment 'p1q1' 
-- and 'p2q2' intersect. 
local function doIntersect(p1, q1, p2, q2) 
   -- Find the four orientations needed for general and 
   -- special cases
   local o1, o2, o3, o4
   o1 = orientation(p1, q1, p2)
   o2 = orientation(p1, q1, q2) 
   o3 = orientation(p2, q2, p1) 
   o4 = orientation(p2, q2, q1) 
   
   -- General case 
   if (o1 ~= o2 and o3 ~= o4) then return true end
   
   -- Special Cases 
   -- p1, q1 and p2 are colinear and p2 lies on segment p1q1 
   if (o1 == 0 and onSegment(p1, p2, q1)) then return true end
   
   -- p1, q1 and p2 are colinear and q2 lies on segment p1q1 
   if (o2 == 0 and onSegment(p1, q2, q1)) then return true end
  
   -- p2, q2 and p1 are colinear and p1 lies on segment p2q2 
   if (o3 == 0 and onSegment(p2, p1, q2)) then return true end
  
   -- p2, q2 and q1 are colinear and q1 lies on segment p2q2 
   if (o4 == 0 and onSegment(p2, q1, q2)) then return true end 
  
    return false -- Doesn't fall in any of the above cases 
end

local function isNoFlyC(nn, p)
   local d
   d = math.sqrt( (nn.x-p.x)^2 + (nn.y-p.y)^2)
   --if d <= nn.r then
      --print(nn.x, p.x, nn.y, p.y, nn.inside, d, nn.r)
   --end
   if nn.inside == true then
      if d <= nn.r then return true end
   else
      if d >= nn.r then return true end
   end
   return false
end

-- Returns true if the point p lies inside the polygon[] with n vertices 
local function isNoFlyP(pp, io, p) 

   local isInside
   
   -- There must be at least 3 vertices in polygon[]

   if (#pp < 3)  then return false end
   
   --Create a point for line segment from p to infinite 
   extreme = {x=2*maxpolyX, y=p.y}; 
  
   -- Count intersections of the above line with sides of polygon 
   local count = 0
   local i = 1
   local n = #pp
   
   repeat
      local next = i % n + 1
      if (doIntersect(pp[i], pp[next], p, extreme)) then 
	 -- If the point 'p' is colinear with line segment 'i-next', 
	 -- then check if it lies on segment. If it lies, return true, 
	 -- otherwise false 
	 if (orientation(pp[i], p, pp[next]) == 0) then 
	    return onSegment(pp[i], p, pp[next])
	 end
	 count = count + 1 
      end
      
      i = next
   until (i == 1)
   
   -- Point inside polygon: true if count is odd, false otherwise
   isInside = (count % 2 == 1)

   if io == true then
      return isInside
   else
      return not isInside
   end
   
end

local function xminImg(iM)
   return -0.50 * Field.images[iM]
end

local function xmaxImg(iM)
   return 0.50 * Field.images[iM]
end

local function yminImg(iM)
   local yrange = Field.images[iM] / 2
   if not Field.View or Field.View == "Standard" then
      return -0.25 * yrange
   else
      return -0.50 * yrange
   end
end

local function ymaxImg(iM)
   local yrange = Field.images[iM] / 2 
   if not Field.View or Field.View == "Standard" then
      return 0.75 * yrange
   else
      return 0.50 * yrange
   end
end

local function graphScaleRst(i)
   if not currentImage then return end
   currentImage = i
   map.Xmin = xminImg(currentImage)
   map.Xmax = xmaxImg(currentImage)
   map.Ymin = yminImg(currentImage)
   map.Ymax = ymaxImg(currentImage)
   map.Xrange = map.Xmax - map.Xmin
   map.Yrange = map.Ymax - map.Ymin
   path.xmin = map.Xmin
   path.xmax = map.Xmax
   path.ymin = map.Ymin
   path.ymax = map.Ymax
end

--------------------------

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
local colHeading = 160
local rowHeading = 30

local function drawHeading()

   local dispHeading
   
   ii = ii + 1

   lcd.drawFilledRectangle(colHeading-70, rowHeading, 140, 2)
   lcd.drawFilledRectangle(colHeading+65, rowHeading-20, 6,22)
   lcd.drawFilledRectangle(colHeading-65-6, rowHeading-20, 6,22)

   --dispHeading = (heading + variables.rotationAngle) % 360
   dispHeading = (heading) % 360

   for _, point in pairs(parmHeading) do
      wrkHeading = point[1] - dispHeading
      if wrkHeading > 180 then wrkHeading = wrkHeading - 360 end
      if wrkHeading < -180 then wrkHeading = wrkHeading + 360 end
      deltaX = math.floor(wrkHeading / 1.6 + 0.5) - 1 -- was 2.2
      
      if deltaX >= -64 and deltaX <= 62 then -- was 31
	 if point[3] then
	    lcd.drawText(colHeading + deltaX - 4, rowHeading - 16, point[3], FONT_MINI)
	 end
	 if point[2] > 0 then
	    lcd.drawLine(colHeading + deltaX, rowHeading - point[2],
			 colHeading + deltaX, rowHeading)
	 end
      end
   end 

   text = string.format(" %03d",dispHeading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   lcd.drawFilledRectangle(colHeading - w/2, rowHeading-30, w, lcd.getTextHeight(FONT_MINI))
   lcd.setColor(255,255,255)
   lcd.drawText(colHeading - w/2,rowHeading-30,text,  FONT_MINI)
   
   lcd.resetClipping()
end

--------------------------

local function drawTextCenter(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end

local function drawGauge(label, min, _, max, temp, _, ox, oy)
   local theta
   drawTextCenter(FONT_MINI, label, ox+25, oy+38)
   drawTextCenter(FONT_BOLD, string.format("%d", temp), ox+25, oy+16)
    temp = math.min(max, math.max(temp, min))
   theta = math.pi - math.rad(135 - 2 * 135 * (temp - min) / (max - min) )
    if arcFile ~= nil then
      lcd.drawImage(ox, oy, arcFile)
      drawShape(ox+25, oy+26, shapes.needle_poly_small, theta)
   end
end


--------------------------

local function dirPrint()
   local xa, ya
   local xp, yp
   local theta
   local dotpng

   xa = 160
   ya = 90
   --lcd.drawLine(160,160,160, 0)
   lcd.setColor(160,160,160)
   lcd.drawFilledRectangle(xa-2, ya-50, 4, 100)
   lcd.drawFilledRectangle(xa-50, ya-2, 100, 4)
   lcd.drawCircle(xa, ya, 50)
   lcd.drawCircle(xa, ya, 51)      

   if raceParam.racing then
      theta = math.rad(180 - (relBearing or 0))
   else
      theta = math.rad(180)
   end
   
   lcd.setColor(255,200,0)
   drawShape(xa, ya, shapes.bigArrow, theta )

   if raceParam.racing then
      
      if m3(nextPylon) == 1 then lcd.setColor(200,0,0)
      elseif m3(nextPylon) == 2 then lcd.setColor(0,150,0)
      elseif m3(nextPylon) == 3 then lcd.setColor(0,0,200)
      end
      
      txt = string.format("Pylon %d: %dm, %ds", m3(nextPylon), distance, distance/speed)
      lcd.drawText(xa - lcd.getTextWidth(FONT_BOLD, txt)/2, ya+52, txt, FONT_BOLD)
   end
      
   --lcd.drawText(265, 35, string.format("NxtP %d", m3(nextPylon)), FONT_MINI)
   --lcd.drawText(265, 45, string.format("Dist %.0f", distance), FONT_MINI)
   --lcd.drawText(265, 55, string.format("Hdg  %.1f", heading), FONT_MINI)
   --lcd.drawText(265, 65, string.format("TCrs %.1f", vd), FONT_MINI)
   --lcd.drawText(265, 75, string.format("RelB %.1f", relBearing or 0), FONT_MINI)
   --if speed ~= 0 then
     -- lcd.drawText(265, 85, string.format("Time %.1f", distance / speed), FONT_MINI)
   --end

   lcd.setColor(0,0,255)
   if distance and raceParam.racing then
      xp, yp = rotateXY(0, 50 * distance / variables.triLength, theta)
      if m3(nextPylon) == 1 then dotpng = redDotImage
      elseif m3(nextPylon) == 2 then dotpng = greenDotImage
      elseif m3(nextPylon) == 3 then dotpng = blueDotImage
      end
      lcd.drawImage((xp+xa-7), (yp+ya-7), dotpng)
      --lcd.drawCircle(xp+xa, yp+ya,5)
   else
      lcd.drawImage(xa-7, ya-7, redDotImage)
      --lcd.drawCircle(xa, ya,5)
   end
   
      
   drawHeading()
   lcd.setColor(0,0,0)
   drawGauge("Alt", 0, 50, 100, altitude, "m", 250, 30)
   drawGauge("Spd", 0, 50, 100, speed, "km/hr", 250,100)

   if lapAltitude then
      vertHistogram(25, ya, altitude - lapAltitude, 100, 60, 20, lapAltitude)
   else
      vertHistogram(25, ya, 0, 100, 60, 20)
   end


   lcd.drawText(80-lcd.getTextWidth(FONT_MINI, string.format("#xHist %d", #xHist)) / 2,
		100, text, FONT_MINI)
   
   lcd.drawText(80-lcd.getTextWidth(FONT_MINI, string.format("NNP %d", countNoNewPos)) / 2,
		110, text, FONT_MINI)

   lcd.drawText(80-lcd.getTextWidth(FONT_MINI, string.format("(%d,%d)", x or 0, y or 0)) / 2,
		120, text, FONT_MINI)

end

local noFlyLast = false
local noFlyLastF = false

local function checkNoFly(xt, yt, future)
   
   local noFly, noFlyF, noFlyP, noFlyC, txy

   txy = {x=xt, y=yt}

   noFlyP = false
   for i=1, #nfp, 1 do
      noFlyP = noFlyP or isNoFlyP(nfp[i].path, nfp[i].inside, txy)
   end

   --print("noFlyP:", noFlyP)
   
   noFlyC = false
   for i=1, #nfc, 1 do
      noFlyC = noFlyC or isNoFlyC(nfc[i], txy)
   end

   --print("noFlyC:", noFlyC)

   if not future then
      noFly = noFlyP or noFlyC
   else
      noFlyF = noFlyP or noFlyC
   end
   
   if noFly ~= noFlyLast and not future then
      if noFly then
	 print("Enter no fly")
	 playFile(appInfo.Dir.."Audio/Warning_No_Fly_Zone.wav", AUDIO_IMMEDIATE)
	 system.vibration(false, 3) -- left stick, 2x short pulse
      else
	 print("Exit no fly")
	 playFile(appInfo.Dir.."Audio/Leaving_no_fly_zone.wav", AUDIO_QUEUE)
      end
      noFlyLast = noFly
   end

   if noFlyF ~= noFlyLastF and future then
      if noFlyF then
	 print("Enter Future no fly")
	 playFile(appInfo.Dir.."Audio/no_fly_ahead.wav", AUDIO_IMMEDIATE)
	 --system.vibration(false, 3) -- left stick, 2x short pulse
      else
	 print("Exit Future no fly")
	 --playFile(appInfo.Dir.."Audio/Leaving_no_fly_zone.wav", AUDIO_QUEUE)
      end
      noFlyLastF = noFlyF
   end

   if not future then
      return noFly
   else
      return noFlyF
   end
   
end

local swzTime = 0
local panic = false

local function mapPrint(windowWidth, windowHeight)

   local swp
   local swz
   local offset
   local ren=lcd.renderer()
   
   setColorMap()
   
   setColorMain()
   
   if fieldPNG[currentImage] then
      lcd.drawImage(0,0,fieldPNG[currentImage], 255)
   else
      local txt = "No GPS signal or no Image"
      lcd.drawText((310 - lcd.getTextWidth(FONT_BIG, txt))/2, 90, txt, FONT_BIG)
   end
   

   -- check tape switch (for display of speed, alt tapes)
   -- if not defined, then show them
   -- if defined, then use switch to decide

   if zoomSwitch then
      swz = system.getInputsVal(zoomSwitch)
   end

   if zoomSwitch and (swz and swz == 1) then
      if system.getTimeCounter() - swzTime > 2000 then
	 graphScaleRst(1)
	 swzTime = system.getTimeCounter()
      end
   end
      
   -- in case the draw functions left color set to their specific values
   setColorMain()
   
   lcd.drawText(30-lcd.getTextWidth(FONT_MINI, "N") / 2, 34, "N", FONT_MINI)
   drawShape(30, 40, shapes.arrow, math.rad(-1*variables.rotationAngle))
   lcd.drawCircle(30, 40, 7)

   if satCount then
      text=string.format("%2d Sats", satCount)
      lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 48, text, FONT_MINI)
   else
      text = "No Sats"
      lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 48, text, FONT_MINI)
   end
   
   text=string.format("%d/%d %d%%", #xHist, variables.histMax, currMaxCPU)
   lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 62, text, FONT_MINI)

   if currentGPSread and lastGPSread then
      text = string.format("GPS dt %d", currentGPSread - lastGPSread)
      lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 76, text, FONT_MINI)
   end
   
   --text=string.format("NNP %d", countNoNewPos)
   --lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 76, text, FONT_MINI)
   
   -- if satQuality then
   --    text=string.format("%.1f", satQuality)
   --    lcd.drawText(70-lcd.getTextWidth(FONT_MINI, text) / 2, 42, text, FONT_MINI)   
   -- end
   

   if pointSwitch then
      swp = system.getInputsVal(pointSwitch)
   end
   
   if not pointSwitch or (swp and swp == 1) then

      --check if we need to panic .. xHist got too big while we were off screen
      --and we are about to get killed
      
      if panic then
	 offset = #xHist - 200 -- only draw last 200 points .. should be safe
	 if offset < 0 then -- should not happen .. if so dump and start over
	    print("dumped history")
	    xHist={}
	    yHist={}
	 end
      else
	 offset = 0
      end

      ren:reset()
      for i=2 + offset, #xHist do

	 if system.getCPU() < variables.maxCPU then
	    ren:addPoint(toXPixel(xHist[i-1], map.Xmin, map.Xrange, windowWidth ),
			 toYPixel(yHist[i-1], map.Ymin, map.Yrange, windowHeight) + 0)
	    --[[
	    lcd.drawLine(toXPixel(xHist[i-1], map.Xmin, map.Xrange, windowWidth ),
			 toYPixel(yHist[i-1], map.Ymin, map.Yrange, windowHeight) + 0,
			 toXPixel(xHist[i], map.Xmin, map.Xrange,    windowWidth),
			 toYPixel(yHist[i], map.Ymin, map.Yrange,   windowHeight) + 0)
	    --]]
	 else
	    print("CPU panic", #xHist, system.getCPU(), variables.maxCPU)
	    panic = true
	    break
	 end
	 
      end

      if variables.histMax > 0 and #xHist > 0 and #xtable > 0 then
	 ren:addPoint( toXPixel(xtable[#xtable], map.Xmin, map.Xrange,    windowWidth),
		       toYPixel(ytable[#ytable], map.Ymin, map.Yrange,    windowHeight) + 0)
	 --[[
	    lcd.drawLine(toXPixel(xHist[#xHist], map.Xmin, map.Xrange,    windowWidth),
	    toYPixel(yHist[#yHist], map.Ymin, map.Yrange,   windowHeight) + 0,
	    toXPixel(xtable[#xtable], map.Xmin, map.Xrange,    windowWidth),
	    toYPixel(ytable[#ytable], map.Ymin, map.Yrange,    windowHeight) + 0)
	 --]]

      end
      
      ren:renderPolyline(2,0.6)
   end

   -- draw the runway if defined
   
   if #rwy == 4 then
      ren:reset()
      for j = 1, 5, 1 do
	 ren:addPoint(toXPixel(rwy[j%4+1].x, map.Xmin, map.Xrange, windowWidth),
		      toYPixel(rwy[j%4+1].y, map.Ymin, map.Yrange, windowHeight))
      end
      ren:renderPolyline(2,0.7)
   end

   -- draw the polygon no fly zones if defined

   if noflyEnabled then
      for i = 1, #nfp, 1 do
	 ren:reset()
	 if nfp[i].inside then
	    setColorNoFlyInside()
	 else
	    setColorNoFlyOutside()
	 end
	 for j = 1, #nfp[i].path+1, 1 do
	    ren:addPoint(toXPixel(nfp[i].path[j % (#nfp[i].path) + 1].x,
				  map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].path[j % (#nfp[i].path) + 1].y,
				  map.Ymin, map.Yrange, windowHeight))
	    
	 end
	 ren:renderPolyline(2,0.5)
      end
      
      for i = 1, #nfc, 1 do
	 if i == i then
	    if nfc[i].inside then
	       setColorNoFlyInside()
	    else
	       setColorNoFlyOutside()
	    end
	    
	    lcd.drawCircle(toXPixel(nfc[i].x, map.Xmin, map.Xrange, windowWidth),
			   toYPixel(nfc[i].y, map.Ymin, map.Yrange, windowHeight),
			   nfc[i].r * windowWidth/map.Xrange)
	 end
      end
   end

   setColorMap()
   setColorMain()
   
   drawTriRace(windowWidth, windowHeight)

   --lcd.drawText(250, 20, "sT: "..tostring(raceParam.startToggled), FONT_MINI)
   --lcd.drawText(250, 30, "sA: "..tostring(raceParam.startArmed), FONT_MINI)
   --lcd.drawText(250, 40, "rF: "..tostring(raceParam.raceFinished), FONT_MINI)

   for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute 
      
      setColorMain()

      drawBezier(windowWidth, windowHeight, 0)

      setColorMain()
      
      -- defensive moves for squashing the indexing nil variable that Harry saw
      -- had to do with getting here (points in xtable) but no field selected
      -- checks in Field being nil should take care of that
      
      if i == #xtable then

	 if checkNoFly(xtable[#xtable], ytable[#ytable], false) then
	    setColorNoFlyInside()
	 else
	    setColorMap()
	 end
 
	 drawShape(toXPixel(xtable[i], map.Xmin, map.Xrange, windowWidth),
		   toYPixel(ytable[i], map.Ymin, map.Yrange, windowHeight) + 0,
		   shapes.T38, math.rad(heading))

	 variables.futureMillis = 2000 -- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXx
	 
	 if variables.futureMillis > 0 then
	    xf = xtable[i] - speed * (variables.futureMillis / 1000.0) *
	       math.cos(math.rad(270-heading))
	    yf = ytable[i] - speed * (variables.futureMillis / 1000.0) *
	       math.sin(math.rad(270-heading))

	    setColorMap()
	    
	    if checkNoFly(xtable[#xtable] - speed * (variables.futureMillis / 1000.0) *
			     math.cos(math.rad(270-heading)),
			  ytable[#ytable] - speed * (variables.futureMillis / 1000.0) *
			  math.sin(math.rad(270-heading)), true) then
	       setColorNoFlyInside()
	    else
	       setColorMap()
	    end

	    -- only draw future if projected position more than 10m ahead (~10 mph for 2s)
	    if speed * variables.futureMillis > 10000 then
	       drawShape(toXPixel(xf, map.Xmin, map.Xrange, windowWidth),
			 toYPixel(yf, map.Ymin, map.Yrange, windowHeight) + 0,
			 shapes.delta, math.rad(heading))
	    end
	 end
      end
   end

   currMaxCPU = system.getCPU()
   if currMaxCPU >= variables.maxCPU then
      variables.histMax = #xHist -- no more points .. cpu nearing cutoff
   end
   
end


local function pngLoad(j)
   local pfn
   --print("pngLoad - j:", j)
   pfn = appInfo.Fields .. '/' .. Field.shortname .. "/" ..
      tostring(math.floor(Field.images[j])) ..".png"
   --print("pngLoad - j, pfn:", j, pfn)
   fieldPNG[j] = lcd.loadImage(pfn)
   if not fieldPNG[j] then
      print("Failed to load image", j, pfn)
   end
end

local function graphScale(xx, yy)

   if not map.Xmax then
      print("BAD! -- setting max and min in graphScale")
      map.Xmax=   400
      map.Xmin = -400
      map.Ymax =  200
      map.Ymin = -200
   end
   
   if xx > path.xmax then path.xmax = xx end
   if xx < path.xmin then path.xmin = xx end
   if yy > path.ymax then path.ymax = yy end
   if yy < path.ymin then path.ymin = yy end

   -- if we have an image then scale factor comes from the image
   -- check each image scale .. maxs and mins are precomputed
   -- starting from most zoomed in image (the first one), stop
   -- when the path fits within the window or at max image size

   if currentImage then 
      for j = 1, maxImage, 1 do
	 currentImage = j
	 if path.xmax <= xmaxImg(j) and
	    path.ymax <= ymaxImg(j) and
	    path.xmin >= xminImg(j) and
	    path.ymin >= yminImg(j)
	 then
	    break
	 end
      end

      if not fieldPNG[currentImage] then
	 pngLoad(currentImage)
      end
      
      --print("graphScale: currentImage", currentImage)
            
      graphScaleRst(currentImage)
   else
      -- if no image then just scale to keep the path on the map
      -- round Xrange to nearest 200', Yrange to nearest 100' maintain 2:1 aspect ratio
      map.Xrange = math.floor((path.xmax-path.xmin)/200 + .5) * 200
      map.Yrange = math.floor((path.ymax-path.ymin)/100 + .5) * 100
      
      if map.Yrange > map.Xrange/2 then
	 map.Xrange = map.Yrange*2
      end
      if map.Xrange > map.Yrange*2 then
	 map.Yrange = map.Xrange/2
      end
      
      map.Xmin = path.xmin - (map.Xrange - (path.xmax-path.xmin))/2
      map.Xmax = path.xmax + (map.Xrange - (path.xmax-path.xmin))/2
      
      map.Ymin = path.ymin - (map.Yrange - (path.ymax-path.ymin))/2
      map.Ymax = path.ymax + (map.Yrange - (path.ymax-path.ymin))/2
   end
   
--   print("Xmin,Xmax,Ymin,Ymax", map.Xmin, map.Xmax, map.Ymin, map.Ymax)
end

local function graphInit(im)

   -- im or 1 construct allows im to be nil and if so selects images[1]
   -- print("graphInit: iField, im", iField, im)
   
   if Field.images and Field.images[im or 1] then
      map.Xmin = xminImg(im or 1)
      map.Xmax = xmaxImg(im or 1)
      map.Ymin = yminImg(im or 1)
      map.Ymax = ymaxImg(im or 1)
   else
      map.Xmin, map.Xmax = -400, 400
      map.Ymin, map.Ymax = -200, 200
   end

   map.Xrange = map.Xmax - map.Xmin
   map.Yrange = map.Ymax - map.Ymin
   
   path.xmin, path.xmax, path.ymin, path.ymax = map.Xmin, map.Xmax, map.Ymin, map.Ymax

end

local function ll2xy(lat, lng)
   local tx, ty
   tx, ty = rotateXY(rE*(lng-lng0)*coslat0/rad,
		     rE*(lat-lat0)/rad,
		     math.rad(variables.rotationAngle))
   return {x=tx, y=ty}
end


local function initField()

   local fp, fn, af

   fieldDirs={}

   if not emFlag then af = "/" .. appInfo.Fields else af = appInfo.Fields end

   --print("appInfo.Fields:", af)
   
   for fname, ftype, _ in dir(af) do
      if ftype == "folder" and fname ~= "." and fname ~= ".."  then
	 table.insert(fieldDirs, fname)
      end
   end
   --print("initfield: lat0, lng0:", lat0, lng0)
   
   if lng0 and lat0 then -- if location was detected by the GPS system
      --for fname, ftype, fsize in dir(basedir) do
      for _,fname in ipairs(fieldDirs) do
	 --print("fname:", fname)
	 fn = appInfo.Fields..'/'..fname.."/field.jsn"
	 --print("fn", fn)
	 fp = io.readall(fn)
	 if fp then
	    Field = json.decode(fp)
	    if not Field then
	       print("Failed to decode field" .. fn)
	       return
	    end
	 else
	    print("Cannot open ", fn)
	    return
	 end

	 Field.images = {250, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000}

	 --print("before atfield in initField:", lat0, lng0)
	 
	 local atField = (math.abs(lat0 - Field.lat) < 1/60) and
	 (math.abs(lng0 - Field.lng) < 1/60) 

	 Field.name = nil
	 
	 --if (not iF and atField) then -- then or (iF and iF == i)then
	 if (atField) then -- then or (iF and iF == i)then
	    Field.name = fname
	    lng0 = Field.lng -- reset to origin to coords in jsn file
	    lat0  = Field.lat
	    --print("atField: Field.lat, Field.lng", Field.lat, Field.lng)
	    
	    coslat0 = math.cos(math.rad(lat0))
	    variables.rotationAngle = Field.runway.heading-270 -- draw rwy along x axis
	    if Field.raceTime then
	       variables.raceTime = Field.raceTime
	    else
	       variables.raceTime = 30
	    end
	    -- see if file <model name>_icon.jsn exists
	    -- if so try to read airplane icon
	    print("Looking for Apps/"..system.getProperty("Model").."_icon.jsn")
	    local fg = io.readall("Apps/"..system.getProperty("Model").."_icon.jsn")
	    if fg then
	       shapes.T38 = json.decode(fg).icon
	    end

	    --print("#Field.triangle.path", #Field.triangle.path)

	    tri = {}
	    for j=1, #Field.triangle.path, 1 do
	       tri[j] = ll2xy(Field.triangle.path[j].lat, Field.triangle.path[j].lng)
	       --print("j, tri.x, tri.y:", j, tri[j].x, tri[j].y)
	    end
	    tri.center = ll2xy(Field.triangle.center.lat, Field.triangle.center.lng)
	    --print("tri.center.x, tri.center.y:", tri.center.x, tri.center.y)
	    --print("#Field.runway.path", #Field.triangle.path)	    

	    rwy = {}
	    for j=1, #Field.runway.path, 1 do
	       rwy[j] = ll2xy(Field.runway.path[j].lat, Field.runway.path[j].lng)
	       --print("j, rwy.x, rwy.y:", j, rwy[j].x, rwy[j].y)
	    end
	    rwy.heading = Field.runway.heading
	    print("rwy heading:", rwy.heading)
	       
	    nfc = {}
	    nfp = {}

	    for j = 1, #Field.nofly, 1 do
	       if Field.nofly[j].type == "circle" then
		  local tt = ll2xy(Field.nofly[j].lat, Field.nofly[j].lng)
		  tt.r = Field.nofly[j].diameter / 2
		  tt.inside = Field.nofly[j].inside_or_outside == "inside"
		  table.insert(nfc, tt)
		  --print("tt.x, tt.y", tt.x, tt.y)
		  --print("#nfc, x,y,r", #nfc, nfc[#nfc].x, nfc[#nfc].y, nfc[#nfc].r, nfc[#nfc].inside)
	       elseif Field.nofly[j].type == "polygon" then
		  local pp = {}
		  for k =1, #Field.nofly[j].path, 1 do
		     table.insert(pp,ll2xy(Field.nofly[j].path[k].lat,Field.nofly[j].path[k].lng))
		  -- we know 0,0 is at center of runway ... need an "infinity x" point for the
		  -- no fly region computation ... keep track of largest positive x ..
		  -- later we will double it to make sure it is well past the no fly polygon
		     if pp[#pp].x > maxpolyX then maxpolyX = pp[#pp].x end		     
		  end
		  table.insert(nfp, {inside=(Field.nofly[j].inside_or_outside == "inside"),
				     path = pp})
	       end
	    end
	    if (Field) then -- if we read the jsn file then extract the info from it
	       setColorMap()
	       setColorMain()
	    end   
	    break
	 end
      end
   end
   
   if Field and Field.name then
      system.messageBox("Current location: " .. Field.name, 2)
      maxImage = #Field.images
      if maxImage ~= 0 then
	 pngLoad(1)
	 currentImage = 1
	 graphInit(currentImage) -- re-init graph scales with images loaded
      end
   else
      system.messageBox("Current location: not a known field", 2)
      --print("not a known field: lat0, lng0", lat0, lng0)
      gotInitPos = false -- reset and try again with next gps lat long
   end
end

--local function split(str, ch)
--   local index, acc = 0, {}
--   while index do
--      local nindex = string.find(str, ch, 1+index)
--      if not nindex then
--	 table.insert(acc, str:sub(index))
--	 break
--      end
--      table.insert(acc, str:sub(index, nindex-1))
--      index = 1+nindex
--  end
--   return acc
--end


--local function manhat_xy_from_latlng(latitude1, longitude1, latitude2, longitude2)
--   if not coslat0 then return 0 end
--   return math.abs(rE * math.rad(longitude1 - longitude2) * coslat0) +
--          math.abs(rE * math.rad(latitude1 - latitude2))
--end

------------------------------------------------------------

-- presistent and global variables for loop()

local lastlat = 0
local lastlng = 0
local compcrs
local compcrsDeg = 0
local lineAvgPts = 4  -- number of points to linear fit to compute course
local numGPSreads = 0
local newPosTime = 0
local hasCourseGPS

local lastHistTime=0

local function loop()

   local minutes, degs
   --local hasPitot
   local sensor
   local goodlat, goodlng 
   local newpos
   local deltaPosTime = 100 -- min sample interval in ms

   --if select(2, system.getDeviceType()) == 1 then
   --   if not emulatorSensorsReady or not emulatorSensorsReady(readSensors) then return end
   --end
   

   goodlat = false
   goodlng = false

   -- keep the checkmark on the menu for 300 msec when user does reset
   
   if resetOrigin and (system.getTimeCounter() > (timeRO+300)) then
      --gotInitPos = false

      resetOrigin=false
      resetClick = false

      form.setValue(resetCompIndex, resetClick) -- prob should double check same form still displayed...
      
      if currentImage then -- if we have an image, allow user to cycle thru image mags one by one
	 currentImage = currentImage + 1
	 if currentImage > maxImage then currentImage = 1 end
      end -- must graphinit() after this!

      graphInit(currentImage)      -- reset map window too
      
      --baroAltZero = altitude      -- reset baro alt zero 

      --print("Reset origin and barometric altitude. New baroAltZero is ", baroAltZe)
      print("Reset origin")      
   end

   -- start reading all the relevant sensors
   
   sensor = system.getSensorByID(satCountID, satCountPa)
   if sensor and sensor.valid then
      satCount = sensor.value
   end

   sensor = system.getSensorByID(satQualityID, satQualityPa)
   if sensor and sensor.valid then
      satQuality = sensor.value
   end   

   sensor = system.getSensorByID(telem.Longitude.SeId, telem.Longitude.SePa)

   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative (NESW coded in decimal places as 0,1,2,3)
	 longitude = longitude * -1
      end
      goodlng = true
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
      numGPSreads = numGPSreads + 1
   end

   -- throw away first 10 GPS readings to let unit settle
   if numGPSreads <= 10 then 
      -- print("Discarding reading: ", numGPSreads, latitude, longitude, goodlat, goodlng)
      return
   end
   
   -- Xicoy FC sends a lat/long of 0,0 on startup .. don't use it
   if math.abs(latitude) < 1 then
      -- print("Latitude < 1: ", latitude, longitude, goodlat, goodlng)
      return
   end

   -- Jeti MGPS sends a reading of 240N, 48E on startup .. don't use it
   if latitude > 239 then
      -- print("Latitude > 239: ", latitude, longitude, goodlat, goodlng)
      return
   end 

   sensor = system.getSensorByID(telem.Altitude.SeId, telem.Altitude.SePa)

   if(sensor and sensor.valid) then
      GPSAlt = sensor.value
   end
 
   --sensor = system.getSensorByID(telem.SpeedNonGPS.SeId, telem.SpeedNonGPS.SePa)
   
   --hasPitot = false
   --if(sensor and sensor.valid) then
      --SpeedNonGPS = sensor.value 
      --hasPitot = true
   --end
   
   --sensor = system.getSensorByID(telem.BaroAlt.SeId, telem.BaroAlt.SePa)
   
   --if(sensor and sensor.valid) then
      --baroAlt = sensor.value
   --end
   
   
   sensor = system.getSensorByID(telem.SpeedGPS.SeId, telem.SpeedGPS.SePa)
   
   if(sensor and sensor.valid) then
      --print("unit:", sensor.unit)
      if sensor.unit == "m/s" then -- speed will be km/hr
	 SpeedGPS = sensor.value * 3.6
      elseif sensor.unit == "km/h" then
	 SpeedGPS = sensor.value
      elseif sensor.unit == "mph" then
	 SpeedGPS = sensor.value * 1.609344
      else -- what on earth units are these .. set to 0
	 SpeedGPS = 0
      end
      
   end

--[[   
   sensor = system.getSensorByID(telem.DistanceGPS.SeId, telem.DistanceGPS.SePa)
   if(sensor and sensor.valid) then
      DistanceGPS = sensor.value
   end      
--]]
   
   hasCourseGPS = false
   sensor = system.getSensorByID(telem.CourseGPS.SeId, telem.CourseGPS.SeId)
   if sensor and sensor.valid then
      courseGPS = sensor.value
      hasCourseGPS = true
   end

   
   -- only recompute when lat and long have changed
   
   if not latitude or not longitude then
      --print('returning: lat or long is nil')
      return
   end
   if not goodlat or not goodlng then
      --print('returning: goodlat, goodlng: ', goodlat, goodlng)
      return
   end

   -- if no GPS or pitot then code further below will compute speed from delta dist

   --[[
      -- this is the original LSO code that "prefers" the pitot speed .. here for
      -- tri racing we want only to use the GPS speed for the speed variable
   if hasPitot and (SpeedNonGPS ~= nil) then
      speed = SpeedNonGPS
   elseif SpeedGPS ~= nil then
      speed = SpeedGPS
   end
   --]]
   
   -- relpacement code for Tri racing:
   if SpeedGPS ~= nil then speed = SpeedGPS end


   --[[
      -- ditto for altitude (see speed code above)
if GPSAlt then
      if Field and Field.elevation then
	 altitude = GPSAlt - Field.elevation
      else
	 altitude = GPSAlt
      end
   end
   if baroAlt then -- let baroAlt "win" if both defined
      altitude = baroAlt
   end
   --]]

   -- replacement code for Tri race
   if not GPSAlt then GPSAlt = 0 end
   
   if Field and Field.elevation then
      altitude = GPSAlt  - Field.elevation
   else
      altitude = GPSAlt
   end
   
   if (latitude == lastlat and longitude == lastlng) or
   (math.abs(system.getTimeCounter()) < newPosTime) then
	 countNoNewPos = countNoNewPos + 1
	 newpos = false
   else
      newpos = true
      lastlat = latitude
      lastlng = longitude
      newPosTime = system.getTimeCounter() + deltaPosTime
      countNoNewPos = 0
      lastGPSread = currentGPSread
      currentGPSread = system.getTimeCounter()
      --print(lastGPSread)
   end
 
   if newpos and not gotInitPos then
      --print("newpos and not gotInitPos: lat0, lng0", lat0, lng0)
      lng0 = longitude     -- set lng0, lat0, coslat0 in case not near a field
      lat0 = latitude       -- initField will reset if we are
      --print("after set: lat0, lng0", lat0, lng0)
      coslat0 = math.cos(math.rad(lat0)) 
      gotInitPos = true
      initField()
   end

   -- defend against random bad points ... 1/6th degree is about 10 mi

   if ( (math.abs(longitude-lng0) > 1/6) or (math.abs(latitude-lat0) > 1/6) ) and Field.name then
      --print("bad latlong")
      -- perhaps sensor emulator changed fields .. reinit...
      -- do reset only if running on emulator
      if select(2, system.getDeviceType()) == 1  then
	 print("emulator - new field")
	 lat0 = latitude
	 lng0 = longitude
	 fieldPNG={}
	 initField()
	 xHist = {}
	 yHist = {}
      else
	 print('Bad lat/long: ', latitude, longitude, satCount, satQuality)
      end
      return
   end
   
   x = rE * (longitude - lng0) * coslat0 / rad
   y = rE * (latitude - lat0) / rad
   
   -- update overall min and max for drawing the GPS
   -- maintain same pixel size in X and Y (telem screen is 320x160)
   -- map?
   

   x, y = rotateXY(x, y, math.rad(variables.rotationAngle))
   
   if newpos then -- only enter a new xy in the "comet tail" if lat/lon changed

      -- keep a max of variables.histMax points
      -- only record if moved variables.histDistance meters (Manhattan dist) 

      if variables.histMax > 0 and
	 (system.getTimeCounter() - lastHistTime > variables.histSample) and
         (math.abs(x-xHistLast) + math.abs(y - yHistLast) > variables.histDistance) then 
	 if #xHist+1 > variables.histMax then
	    table.remove(xHist, 1)
	    table.remove(yHist, 1)
	 end
	 table.insert(xHist, x)
	 table.insert(yHist, y)
	 xHistLast = x
	 yHistLast = y
	 lastHistTime = system.getTimeCounter()
      end

      if #xtable+1 > MAXTABLE then
	 table.remove(xtable, 1)
	 table.remove(ytable, 1)
      end
      
      table.insert(xtable, x)
      table.insert(ytable, y)

      graphScale(x, y)
      
      checkNoFly(x, y) -- call also from here in loop() so it checks even if not displayed
      
      --print("x,y:", x, y)
      
      if #xtable == 1 then
	 path.xmin = map.Xmin
	 path.xmax = map.Xmax
	 path.ymin = map.Ymin
	 path.ymax = map.Ymax
      end
      -- maybe this should be a bezier curve calc .. which we're already doing ..
      -- just differentiate the polynomial at the endpoint????
      if #xtable > lineAvgPts then -- we have at least 4 points...
	 -- make sure we have a least 15' of manhat dist over which to compute compcrs
	 if (math.abs(xtable[#xtable]-xtable[#xtable-lineAvgPts+1]) +
	     math.abs(ytable[#ytable]-ytable[#ytable-lineAvgPts+1])) > 15 then
	 
	      compcrs = select(2,fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
					table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {})))
	 end
      else
	 compcrs = 0
      end
   
      compcrsDeg = compcrs*180/math.pi
   end

   computeBezier(MAXTABLE+3)
   
--   print("compcrsDEG, bezierPath.slope", compcrsDeg, bezierPath.slope)
--   compcrsDeg = bezierPath.slope
   
   if hasCourseGPS and courseGPS then
      heading = courseGPS
   else
      if compcrsDeg then
	 heading = compcrsDeg
      else
	 heading = 0
      end
   end

   calcTriRace()
   
end

local function init()

   local fg = io.readall(appInfo.Dir.."JSON/Shapes.jsn")
   if fg then
      shapes = json.decode(fg)
   else
      print("Could not open "..appInfo.Dir.."JSON/Shapes.jsn")
   end

   blueDotImage = lcd.loadImage(appInfo.Dir.."/JSON/small_blue_circle.png")
   greenDotImage = lcd.loadImage(appInfo.Dir.."/JSON/small_green_circle.png")   
   redDotImage = lcd.loadImage(appInfo.Dir.."/JSON/small_red_circle.png")

   --print(blueDotImage, greenDotImage, redDotImage)
   
   setColorMain()  -- if a map is present it will change color scheme later
   
   graphInit(currentImage)  -- ok that currentImage is not yet defined

   for i, j in ipairs(telem) do
      telem[j].Se   = system.pLoad("telem."..telem[i]..".Se", 0)
      telem[j].SeId = system.pLoad("telem."..telem[i]..".SeId", 0)
      telem[j].SePa = system.pLoad("telem."..telem[i]..".SePa", 0)
   end

   --local vdef
   
   for i, j in ipairs(variables) do
      idef = 0
      if j == "histSample"     then idef = 1000 end
      if j == "histMax"        then idef =    0 end
      if j == "maxCPU"         then idef =   80 end
      if j == "triLength"      then idef =  250 end
      if j == "maxSpeed"       then idef =  100 end
      if j == "maxAlt"         then idef =  200 end
      if j == "elev"           then idef =    0 end
      if j == "histDistance"   then idef =    3 end
      if j == "raceTime"       then idef =   30 end
      if j == "aimoff"         then idef =   20 end
      if j == "flightStartSpd" then idef =   20 end
      if j == "flightStartAlt" then idef =   20 end
      
      variables[j] = system.pLoad("variables."..variables[i], idef)
   end

   pointSwitch = system.pLoad("pointSwitch")
   zoomSwitch  = system.pLoad("zoomSwitch")
   triASwitch  = system.pLoad("triASwitch")      
   startSwitch = system.pLoad("startSwitch")
   annText     = system.pLoad("annText", "c-d----")
   preText     = system.pLoad("preText", "s-a----")   
   triEnabled = system.pLoad("triEnabled", "true") -- default to enabling racing
   triEnabled  = (triEnabled  == "true") -- convert back to boolean
   noflyEnabled = system.pLoad("noflyEnabled", "true") -- default to enabling racing
   noflyEnabled  = (noflyEnabled  == "true") -- convert back to boolean

   system.registerForm(1, MENU_APPS, "GPS Triangle Racing", initForm, nil, nil)
   system.registerTelemetry(1, appInfo.Name.." Racecourse Map", 4, mapPrint)
   system.registerTelemetry(2, appInfo.Name.." Flight Director", 4, dirPrint)   
   
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   arcFile = lcd.loadImage(appInfo.Dir .. "JSON/c-000.png")

   playFile(appInfo.Dir.."Audio/triangle_racing_active.wav", AUDIO_QUEUE)
   
   readSensors()

end

return {init=init, loop=loop, author="DFM", version="0.3", name=appInfo.Name}
