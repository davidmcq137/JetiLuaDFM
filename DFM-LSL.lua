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
local baroAlt
local GPSAlt
local heading = 0
local altitude = 0
local speed = 0
local SpeedGPS
local SpeedNonGPS = 0
local vario=0
-- local DistanceGPS

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
variables.magneticVar = 0

-- local controls  = {"Throttle", "Brake"}

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
local modelProps={}

local takeoff={}; takeoff.Complete={}; takeoff.Start={}
takeoff.NeverAirborne = true
takeoff.BrakeReleaseTime = 0
takeoff.oldBrake = 0
takeoff.oldThrottle = 0

-- these lists are the non-GPS senggors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }

local sysTimeStart = system.getTimeCounter()

local DEBUG = false -- if set to <true> will generate flightpath automatically for demo purposes
local debugTime = 0
local debugNext = 0

local fieldPNG={}
local maxImage
local currentImage
local textColor = {}
textColor.main = {red=0, green=0, blue=0}
textColor.comp = {red=255, green=255, blue=255}

-- "globals" for log reading
local logItems={}
logItems.cols={}
logItems.vals={}
logItems.selectedSensors = {MGPS_Latitude  =1, -- keyvalues irrelevant for now, just need to be true
			    MGPS_Longitude =2,
			    CTU_Altitude   =3,
			    MSPEED_Velocity=4,
			    MGPS_Course    =5}
local logSensorNameByID = {}


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
   

---[[

-- function to show all global variables .. uncomment for debug .. called from reset origin menu

--[[

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

--local function controlChanged(value, ctl)
--   controls[ctl] = value
--   system.pSave(ctl, value)
--end

local function variableChanged(value, var)
   variables[var] = value
   system.pSave(var, value)
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
   DEBUG = not DEBUG -- in case we forget and ship a version with DEBUG = true to the TX!
end

local dirSelectEntries={}
local fileSelectEntries={}

--local function logFileChanged(value, fn)
   --print("Saving: ", string.match(fn[value], "(%S+)"))
--   system.pSave("logPlayBack", string.match(fn[value], "(%S+)")) -- remove file size from string
--   fns.selectedDir=fn[value]
--end

--------------------------------------------------------------------------------
local function dir(type)

   local dirnames={"20180909",
		   "20180922",
		   "20180927",
		   "20180926",
		   "20180928",
		   "20180929",
		   "20181007",
		   "20181010",
		   "20181013",
		   "20181019",
		   "20181020",
		   "20181101",
		   "20181102",
		   "20181103",
		   "20181104",
		   "20181115"}
   local filenames={"13-47-48.log",
		    "16-50-25.log",
		    "17-19-00.log",
		    "18-09-31.log",
		    "18-22-25.log",
		    "21-16-47.log",
		    "21-19-30.log"}
   local idir, ifile=0,0
   return function()
      print("in iterator - type, idir, ifile:", type, idir, ifile)
      if type=="/Log" then

	 print("in /Log")
	 idir = idir + 1
	 if idir > #dirnames then return nil end
	 print("returning", idir, dirnames[idir])
	 return dirnames[idir], "folder", 0
      else
	 ifile = ifile + 1
	 if ifile > #filenames then return nil end
	 return filenames[ifile], "file", 1024+128*ifile
      end
   end
end

-- Draw the main form (Application inteface)

local function initForm(subform)

   if subform == 1 then

      if (tonumber(system.getVersion()) >= 4.22) then
	 --[[ throttle and brake not in model-specific jsn file
	 local menuInput = {Throttle = "Select Throttle Control", Brake = "Select Brake Control"}
      
	 for var, txt in pairs(menuInput) do
	    form.addRow(2)
	    form.addLabel({label=txt, width=220})
	    form.addInputbox(controls.Throttle, true,
			     (function(x) return controlChanged(x, var) end) )
	 end
	 --]] 
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
	 form.addIntbox(variables.rotationAngle, -359, 359, 0, 0, 1,
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
      

	 form.addLink((function() form.reinit(2) end), {label="Select File for Replay on next Startup"})
	 
	 
	 form.addRow(1)
	 form.addLabel({label="DFM - v."..LSOVersion.." ", font=FONT_MINI, alignRight=true})
      else
	 
	 form.addRow(1)
	 form.addLabel({label="Please update, min. fw 4.22 required"})
	 
      end
   elseif subform == 2 then
 
      form.addLink((function() form.reinit(1) end), {label = "Back to main menu",font=FONT_BOLD})
      local i = 0
      
      for fname, ftype, fsize in dir("/Log") do
	 print("in subform 2", fname, ftype, fsize)
	 if ftype == 'folder' then
	    i = i + 1
	    dirSelectEntries[i] = string.format("%s", fname)
	    print("+", i, dirSelectEntries[i])
	 end
      end

      form.addRow(2)
      form.addLabel({label="Select Log dir"})
      print("$", #dirSelectEntries, dirSelectEntries[1], dirSelectEntries[#dirSelectEntries])
      table.sort(dirSelectEntries, function(a,b) return a>b end)
      dirSelectEntries.selectedDir = dirSelectEntries[1]

      form.addSelectbox(dirSelectEntries, 1, true,
			(function(value) dirSelectEntries.selectedDir = dirSelectEntries[value] end))

      form.addLink((function() form.reinit(3) end), {label = "Select file >>"})
      
   elseif subform == 3 then
      form.addLink((function()
	       system.pSave("logPlayBack",fileSelectEntries.selectedFile)
	       form.reinit(1)
		   end),
	 {label = "<< Back to main menu",font=FONT_BOLD})

      form.addLink((function()
 	       system.pSave("logPlayBack",fileSelectEntries.selectedFile)
	       form.reinit(2)
		   end),
	 {label = "<< Back to folder select menu",font=FONT_BOLD})
      
      local i = 0
      local baseDir="/Log".."/"..dirSelectEntries.selectedDir.."/"
      for fname, ftype, fsize in dir(baseDir) do
	 print("in subform 3", fname, ftype, fsize)
	 if ftype == 'file' then
	    i = i + 1
	    --add code here to open each file and read first line to get model name
	    fileSelectEntries[i] = string.format("%s    %s    %s", fname, "TH ViperJet", fsize)
	    print("+", i, fileSelectEntries[i])
	 end
      end
      table.sort(fileSelectEntries, function(a,b) return a>b end)      
      fileSelectEntries.selectedFile = nil -- no default, second parm of addSelectBox is 0 for same reason
      -- fix pSaves in case this var is nil
      form.addRow(2)
      form.addLabel({label="Select Log File", width=195})
      form.addSelectbox(fileSelectEntries, 0, true,
			(function(value)
			      fileSelectEntries.selectedFile = baseDir..fileSelectEntries[value] 
			      print("@",baseDir..fileSelectEntries[value])
			end), {width=118})
      
   end
end

-- Telemetry window draw functions

local delta, deltaX, deltaY

local colAH = 110 + 50
local rowAH = 63

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
   for _, point in pairs(shape) do
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
   for _, point in pairs(shape) do
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
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
end


local function setColorILS()
   -- default to foreground color if no map loaded .. change later if so
   -- default complement color to 255 - fg color
   textColor.main.red, textColor.main.green, textColor.main.blue = lcd.getFgColor()
   -- indulge a personal preference when fg color is Jeti blue scheme
   -- to use a white text as complementary color
   if textColor.main.red == 30 and textColor.main.green == 48 and textColor.main.blue == 106 then
      textColor.comp.red   = 255
      textColor.comp.green = 255
      textColor.comp.blue  = 255
   else
      textColor.comp.red   = 255 - textColor.main.red
      textColor.comp.green = 255 - textColor.main.green
      textColor.comp.blue  = 255 - textColor.main.blue
   end
end

local function setColorMap()
   -- when text and graphics overlayed on a map, best to use yellow
   -- set comp color to 255-fg
   if fieldPNG[currentImage] then   
      textColor.main.red, textColor.main.green, textColor.main.blue = 255, 255,   0
      textColor.comp.red, textColor.comp.green, textColor.comp.blue =   0,   0, 255
   else
      setColorILS()
   end
end


local function setColorMain()
   lcd.setColor(textColor.main.red, textColor.main.green, textColor.main.blue)
end

local function setColorComp()
   lcd.setColor(textColor.comp.red, textColor.comp.green, textColor.comp.blue)
end

--[[
local function drawDistance()

   drawShape(colAH, rowAH+20, shapes.T38, math.rad(heading-variables.magneticVar))
end
--]]

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
   setColorMain()
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
   
   lcd.drawFilledRectangle(11,rowAH-8,42,lcd.getTextHeight(FONT_NORMAL))
   
   setColorComp()
   lcd.drawText(12, rowAH-8, string.format("%d",altitude-baroAltZero), FONT_NORMAL | FONT_XOR)
   lcd.resetClipping()
end
 
-- Draw speed indicator

local text

local function drawSpeed() 
   setColorMain()
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
   setColorComp()
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

   local dispHeading
   
   ii = ii + 1

   setColorMain()

   lcd.drawFilledRectangle(colHeading-70, rowHeading, 140, 2)
   lcd.drawFilledRectangle(colHeading+65, rowHeading-20, 6,22)
   lcd.drawFilledRectangle(colHeading-65-6, rowHeading-20, 6,22)

   dispHeading = (heading + variables.rotationAngle) % 360

   for index, point in pairs(parmHeading) do
      wrkHeading = point[1] - dispHeading
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

   text = string.format("%03d",dispHeading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   setColorMain()
   lcd.drawFilledRectangle(colHeading - w/2, rowHeading-30, w, lcd.getTextHeight(FONT_NORMAL))
   setColorComp()
   lcd.drawText(colHeading - w/2,rowHeading-30,text,  FONT_XOR)
   
   lcd.resetClipping()
end

--- draw Vario (vvi) 

local rowVario = 80
local colVario = 260

local function drawVario()

   setColorMain()
   
   for i = -60, 60, 30 do
      lcd.drawLine(colVario-7, rowVario+i, colVario+8, rowVario+i)
   end
   lcd.drawFilledRectangle(colVario-9, rowVario, 20, 3)

   lcd.drawText(colVario-10, heightAH+2, "fpm", FONT_MINI)

   if(vario > 1200) then vario = 1200 end
   if(vario < -1200) then vario = -1200 end
   if (vario > 0) then 
      lcd.drawFilledRectangle(colVario-4,rowVario-math.floor(vario/16.66 + 0.5),
			      10,math.floor(vario/16.66+0.5),170)
   elseif(vario < 0) then 
      lcd.drawFilledRectangle(colVario-4,rowVario+1,10,math.floor(-vario/16.66 + 0.5), 170)
   end

   lcd.drawFilledRectangle(colVario-48,rowAH-8,38,lcd.getTextHeight(FONT_NORMAL))
   setColorComp()
   text = string.format("%d", math.floor(vario*0.1+0.5)/0.1)
   lcd.drawText(colVario-12- lcd.getTextWidth(FONT_NORMAL,text), rowAH-8, text, FONT_NORMAL | FONT_XOR)
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
    local theta, tt, slope
    
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
   local hyp, perpd, d2r
   local dr, dl, dc
   local dx, dy
   local vA=0
   local dd
   local rA

   setColorILS()
   
   setColorMain()
   
   lcd.drawImage( (310-glideSlopePNG.width)/2+1,10, glideSlopePNG)
   lcd.drawLine (60, yc, 250, yc) -- horiz axis
   lcd.drawLine (xc,1,xc,159)  -- vert axis

   drawSpeed()
   drawAltitude()
   drawVario()   

   setColorMain()
   
   local x = xtable[#xtable] or 0
   local y = ytable[#ytable] or 0
   
   text=string.format("X,Y = %4d,%4d", x, y)
   lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-60, heightAH-17, text, FONT_MINI)

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
   
      -- draw no bars if not in the ILS zone

      if dl >= 0 and dr <= 0 then
	 -- first the horiz bar
	 lcd.setColor(255,0,0) -- red bars for now
	 lcd.drawFilledRectangle(xc-55, yc-2+dy, 110, 4)
	 -- now vertical bar and glideslope angle display
	 text = string.format("%.0f", math.floor(vA/0.01+5)*.01)
	 lcd.drawFilledRectangle(52,rowAH-8,lcd.getTextWidth(FONT_NORMAL, text)+8,
				 lcd.getTextHeight(FONT_NORMAL))
	 lcd.drawFilledRectangle(xc-2+dx,yc-55, 4, 110)
	 lcd.setColor(255,255,255) -- white text for vertical angle box
	 lcd.drawText(56, rowAH-8, text, FONT_NORMAL | FONT_XOR)

      end
   end
      
   
   setColorMain()
   text = string.format("%03d",heading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   lcd.drawFilledRectangle(xc - w/2,0 , w, lcd.getTextHeight(FONT_NORMAL))
   setColorComp()
   lcd.drawText(xc - w/2,0,text,  FONT_XOR)

   if takeoff.RunwayHeading then
      setColorMain()
      local distFromTO = math.sqrt( (xtable[#xtable] - takeoff.Start.X)^2 +
	    (ytable[#ytable] - takeoff.Start.Y)^2)
      text = string.format("%d",distFromTO)
      w = lcd.getTextWidth(FONT_NORMAL,text) 
      lcd.drawFilledRectangle(xc - w/2,143 , w, lcd.getTextHeight(FONT_NORMAL))
      lcd.setColorComp()
      lcd.drawText(xc - w/2,143,text,  FONT_XOR)
   end
end

local binomC = {} -- array of binomial coefficients for n=MAXTABLE-1, indexed by k

local function binom(n, k)
   
   -- compute binomial coefficients to then compute the Bernstein polynomials for Bezier
   -- n will always be MAXTABLE-1 once past initialization
   -- as we compute for each k, remember in a table and save
   -- for MAXTABLE = 5, there are only ever 3 values needed in steady state: (4,0), (4,1), (4,2)
   
   if k > n then return nil end  -- error .. let caller die
   if k > n/2 then k = n - k end -- because (n k) = (n n-k) by symmetry
   
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
   local t
   local ti, oti
   local n = #xtable-1

   for j = 0, numT, 1 do
      t = j / numT
      px, py = 0, 0
      ti = 1 -- first loop t^i = 0^0 which lua says is 1
      for i = 0, n do
	 -- px = px + binom(n, i)*t^i*(1-t)^(n-i)*xtable[i+1]
	 -- py = py + binom(n, i)*t^i*(1-t)^(n-i)*ytable[i+1]
	 oti = (1-t)^(n-i)
	 px = px + binom(n, i)*ti*oti*xtable[i+1]
	 py = py + binom(n, i)*ti*oti*ytable[i+1]
	 ti = ti * t
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

local fd
local timSstr = "-:-"
   
local function mapPrint(windowWidth, windowHeight)

   local xRW, yRW
   local scale
   local lRW
   local phi
   local dr, dl
   
   setColorMap()
   
   setColorMain()
   
   if fieldPNG[currentImage] then
      lcd.drawImage(0,0,fieldPNG[currentImage], 255)
   end

   drawSpeed()
   drawAltitude()
   drawHeading()
   drawVario()
   
   -- in case the draw functions left color set to their specific values
   setColorMain()
   
   if takeoff.Start.X and not fd then
      lcd.drawCircle(toXPixel(takeoff.Start.X, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(takeoff.Start.Y, map.Ymin, map.Yrange, windowHeight), 4)
   end
   
   if takeoff.Complete.X then

      if not iField then
	 lcd.drawCircle(toXPixel(takeoff.Complete.X, map.Xmin, map.Xrange, windowWidth),
			toYPixel(takeoff.Complete.Y, map.Ymin, map.Yrange, windowHeight), 4)
      end

      xRW = (takeoff.Complete.X - takeoff.Start.X)/2 + takeoff.Start.X 
      yRW = (takeoff.Complete.Y - takeoff.Start.Y)/2 + takeoff.Start.Y
      lRW = math.sqrt((takeoff.Complete.X-takeoff.Start.X)^2 + (takeoff.Complete.Y-takeoff.Start.Y)^2)

      scale = (lRW/map.Xrange)*(windowWidth/40) -- rw shape is 40 units long


      if (not iField) and takeoff.RunwayHeading then
	 drawShapePL(toXPixel(xRW, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(yRW, map.Ymin, map.Yrange, windowHeight),
		     shapes.runway, math.rad(takeoff.RunwayHeading-variables.magneticVar), scale, 2, 255)
      end
	 
      if takeoff.RunwayHeading then
	 lcd.setColor(0,240,0) -- temporarily set to green for ILS path
	 drawILS (toXPixel(takeoff.Start.X, map.Xmin, map.Xrange, windowWidth),
		  toYPixel(takeoff.Start.Y, map.Ymin, map.Yrange, windowHeight),
		  math.rad(takeoff.RunwayHeading-variables.magneticVar), scale)
	 setColorMain()
      end

      text=string.format("Map: %d x %d    Rwy: %dT", map.Xrange, map.Yrange,
			 math.floor(( (takeoff.RunwayHeading+variables.rotationAngle)/10+.5) ) )

      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH-10, text, FONT_MINI)

      if iField then
	 text=geo.fields[iField].name
      else
	 text='Unknown Field'
      end
      
      if fd then text = text .."   "..timSstr end
      
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)

   else
      text=string.format("Map: %d x %d", map.Xrange, map.Yrange)
      
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH-10, text, FONT_MINI)

      if iField then
	 text=geo.fields[iField].name
      else
	 text='Unknown Field'
      end

      if iField then
	 text = text..string.format("  Rwy: %dT", math.floor(( (geo.fields[iField].runway.trueDir)/10+.5) ) )
      end
      if fd then text = text .."   "..timSstr end
      
      lcd.drawText(colAH-lcd.getTextWidth(FONT_MINI, text)/2-1, heightAH+2, text, FONT_MINI)
   end

   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, "N") / 2, 14, "N", FONT_MINI)
   drawShape(70, 20, shapes.arrow, math.rad(-1*variables.rotationAngle))
   lcd.drawCircle(70, 20, 7)

   if satCount then
      text=string.format("%2d", satCount)
      lcd.drawText(70-lcd.getTextWidth(FONT_MINI, text) / 2, 28, text, FONT_MINI)
   end

   text=string.format("%d", system.getCPU())
   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, text) / 2, 42, text, FONT_MINI)
   
   -- if satQuality then
   --    text=string.format("%.1f", satQuality)
   --    lcd.drawText(70-lcd.getTextWidth(FONT_MINI, text) / 2, 42, text, FONT_MINI)   
   -- end
   
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

      if not iField then
	 lcd.drawCircle(toXPixel(xr1, map.Xmin, map.Xrange, windowWidth),
			toYPixel(yr1, map.Ymin, map.Yrange, windowHeight), 3)      
	 lcd.drawCircle(toXPixel(xl1, map.Xmin, map.Xrange, windowWidth),
			toYPixel(yl1, map.Ymin, map.Yrange, windowHeight), 3)
	 lcd.drawCircle(toXPixel(xr2, map.Xmin, map.Xrange, windowWidth),
			toYPixel(yr2, map.Ymin, map.Yrange, windowHeight), 3)      
	 lcd.drawCircle(toXPixel(xl2, map.Xmin, map.Xrange, windowWidth),
			toYPixel(yl2, map.Ymin, map.Yrange, windowHeight), 3)
      end

   end
   
   for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute 
      
      -- First compute determinants to see what side of the right and left lines we are on
      -- ILS course is between them

      setColorMain()
      
      if takeoff.RunwayHeading then
	 dr = (xtable[i]-xr1)*(yr2-yr1) - (ytable[i]-yr1)*(xr2-xr1)
	 dl = (xtable[i]-xl1)*(yl2-yl1) - (ytable[i]-yl1)*(xl2-xl1)
     
	 if (dl >= 0 and dr <= 0) and (not takeoff.NeverAirborne) then
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

   drawBezier(windowWidth, windowHeight)
   drawGeo(windowWidth, windowHeight)

end

local function graphScale(x, y)

   if not map.Xmax then
      print("BAD! -- setting max and min in graphScale")
      map.Xmax=   400
      map.Xmin = -400
      map.Ymax =  200
      map.Ymin = -200
   end
   
   if x > path.xmax then path.xmax = x end
   if x < path.xmin then path.xmin = x end
   if y > path.ymax then path.ymax = y end
   if y < path.ymin then path.ymin = y end

   -- if we have an image then scale factor comes from the image
   -- check each image scale .. maxs and mins are precomputed
   -- starting from most zoomed in image (the first one), stop
   -- when the path fits within the window or at max image size

   if currentImage then 
      for j = 1, maxImage, 1 do
	 currentImage = j
	 if path.xmax <= geo.fields[iField].images[j].xmax and
	    path.ymax <= geo.fields[iField].images[j].ymax and
	    path.xmin >= geo.fields[iField].images[j].xmin and
	    path.ymin >= geo.fields[iField].images[j].ymin
	 then
	    break
	 end
      end
      map.Xmin = geo.fields[iField].images[currentImage].xmin
      map.Xmax = geo.fields[iField].images[currentImage].xmax
      map.Ymin = geo.fields[iField].images[currentImage].ymin
      map.Ymax = geo.fields[iField].images[currentImage].ymax
      map.Xrange = map.Xmax - map.Xmin
      map.Yrange = map.Ymax - map.Ymin
      
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

local function graphInit()

   -- if we have an image of the field, then use the precomputed min max value from
   -- the first image (assumed to be the most zoomed-in) to set the initial scale
   
   if iField and geo.fields[iField].images[1] then
      map.Xmin = geo.fields[iField].images[1].xmin
      map.Xmax = geo.fields[iField].images[1].xmax
      map.Ymin = geo.fields[iField].images[1].ymin
      map.Ymax = geo.fields[iField].images[1].ymax
   else
      map.Xmin, map.Xmax = -400, 400
      map.Ymin, map.Ymax = -200, 200
   end

   map.Xrange = map.Xmax - map.Xmin
   map.Yrange = map.Ymax - map.Ymin
   
   path.xmin, path.xmax, path.ymin, path.ymax = map.Xmin, map.Xmax, map.Ymin, map.Ymax

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
	       for j=1, #geo.fields[iField].POI,1 do
		  poi[j] = {x=rE*(geo.fields[iField].POI[j].long-long0)*coslat0/rad,
			    y=rE*(geo.fields[iField].POI[j].lat-lat0)/rad}
		  poi[j].x, poi[j].y = rotateXY(poi[j].x, poi[j].y, math.rad(variables.rotationAngle))
		  -- graphScale(poi[j].x, poi[j].y) -- maybe note in POI coords jsn if should autoscale or not?
	       end
	    end
	    
	    --[[
	    if geo.fields[iField].images then
	       for j=1, #geo.fields[iField].images, 1 do
		  print(j, geo.fields[iField].images[j].filename, geo.fields[iField].images[j].xrange)
	       end
	    end
	    --]]
	    
	    if (geo and iField) then -- if we read the jsn file then extract the info from it
	       
	       -- build the rectangle for the runway, make a closed shape, scale to 2x size

	       for k,j in ipairs({ {x=-1,y=-1},{x=-1,y=1},{x=1,y=1},{x=1,y=-1},{x=-1,y=-1} }) do
		  rwy[k] = {x=j.x * geo.fields[iField].runway.length/2,
			    y=j.y * geo.fields[iField].runway.width/2}
		  graphScale(2*rwy[k].x, 2*rwy[k].y)
	       end
	       -- new code
	       takeoff.Start.X, takeoff.Start.Y = rwy[3].x, 0 -- end of rwy arrival end
	       takeoff.Complete.X, takeoff.Complete.Y = rwy[1].x, 0  -- end of rwy departure end
	       takeoff.Start.Z = altitude - baroAltZero
	       takeoff.RunwayHeading = geo.fields[iField].runway.trueDir-variables.rotationAngle
	       -- print('takeoff.RunwayHeading = ', takeoff.RunwayHeading)
	       -- end new code

	       setColorMap()
	       setColorMain()
	    end   
	    break
	 end
      end
   end
   if iField then
      system.messageBox("Current location: " .. geo.fields[iField].name, 2)
      maxImage = #geo.fields[iField].images
      if maxImage ~= 0 then
	 for j=1, maxImage, 1 do
	    fieldPNG[j] = lcd.loadImage("Apps/DFM-LSO/"..geo.fields[iField].images[j].filename)
	    if fieldPNG[j] then
	       -- precompute left, right, top, bottom for each image
	       -- the runway center is at x,y=0,0
	       -- set the window so that the runway is centered left-to-right
	       -- and is 1/4 of the way up from the bottom of the screen
	       -- image only specifies x range (total width of window), set y range to xrange/2
	       geo.fields[iField].images[j].xmin = -geo.fields[iField].images[j].xrange/2
	       geo.fields[iField].images[j].xmax =  geo.fields[iField].images[j].xrange/2
	       local yrange = geo.fields[iField].images[j].xrange/2
	       geo.fields[iField].images[j].ymin =  -0.25 * yrange
	       geo.fields[iField].images[j].ymax =   0.75 * yrange
	       
	    else
	       print("failed to load image", "Apps/DFM-LSO/"..geo.fields[iField].images[j].filename)
	    end
	 end
	 currentImage = 1
	 graphInit() -- re-init graph scales with images loaded
      end
   else
      system.messageBox("Current location: not a known field", 2)
   end
end

local function split(str, ch)
   local index, acc = 0, {}
   while index do
      local nindex = string.find(str, ch, 1+index)
      if not nindex then
	 table.insert(acc, str:sub(index))
	 break
      end
      table.insert(acc, str:sub(index, nindex-1))
      index = 1+nindex
   end
   return acc
end

local function sensorName(device_name, param_name)
   return device_name .. "_" .. param_name -- sensor name is human readable e.g. CTU_Altitude
end

local function sensorID(devID, devParm)
   return devID..devParm -- sensor ID is machine readable e.g. 420460025613 (13 concat to 4204600256)
end

-- local function packAngle(angle)
--    local d, m = math.modf(angle)
--    return math.floor(m*60000+0.5) + (math.floor(d) << 16) -- math.floor forces to int
-- end

local function unpackAngle(packed)
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end

local rlhCount=0
local rlhDone=false

local function readLogHeader()

   if rlhCount == 0 then
      io.readline(fd) -- read the comment line and toss .. assume one comment line only (!)
   end
   rlhCount = rlhCount + 1
   print ("rlh", rlhCount, system.getCPU())
   for i=1, 4, 1 do -- process log file header 4 rows at a time
      logItems.line = io.readline(fd, true) -- true param removes newline
      logItems.cols = split(logItems.line, ";")
      logItems.timestamp = tonumber(logItems.cols[1])
      if logItems.timestamp ~= 0 then
	 rlhDone = true
	 return
      end
      if logItems.cols[3] == "0" then
	 logItems.prefix=logItems.cols[4]
      else
	 logItems.name  = sensorName(logItems.prefix, logItems.cols[4])
	 if logItems.selectedSensors[logItems.name] then
	    logSensorNameByID[sensorID(logItems.cols[2], logItems.cols[3])] = logItems.name
	 end
      end
   end
   return
end

-----------------------------------------------------------------------------------------------------
local function readLogTimeBlock()

   logItems.timestamp = logItems.cols[1]
   logItems.deviceID = tonumber(logItems.cols[2])

   repeat
      if logItems.deviceID ~= 0 then -- if logItems.deviceID == 0 then it's a message
	 for i = 3, #logItems.cols, 4 do
	    if logItems.timestamp == "000087425" then print(logItems.deviceID, system.getCPU()) end
	    local sn = logSensorNameByID[sensorID(logItems.cols[2], logItems.cols[i])]
	    if sn then
	       logItems.encoding = tonumber(logItems.cols[i+1])
	       logItems.decimals = tonumber(logItems.cols[i+2])
	       logItems.value    = tonumber(logItems.cols[i+3])
	       if logItems.encoding == 9 then
		  local latlong = unpackAngle(logItems.value)
		  if logItems.cols[i] == "3" then
		     if logItems.decimals == 3 then -- "West" .. make it - (NESW coded in dec plcs as 0,1,2,3)
			logItems.vals[sn] = -latlong
		     else
			logItems.vals[sn] = latlong
		     end
		  elseif logItems.cols[i] == "2" then
		     if logItems.decimals == 2 then -- "South" .. make it negative
			logItems.vals[sn] = -latlong
		     else
			logItems.vals[sn] = latlong
		     end
		  end
	       else
		  logItems.vals[sn] = logItems.value / 10^logItems.decimals
	       end
	    end
	 end
      else
	 system.messageBox(logItems.cols[6], 2)	 
      end
      
      logItems.line = io.readline(fd, true)

      if not logItems.line then
	 return nil
      end

      logItems.cols = split(logItems.line, ';')

      if (logItems.cols[1] ~= logItems.timestamp) then -- new time block, dump vals and reset
	 return logItems.vals
      end
   until false
end

-----------------------------------------------------------------------------------------------------
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
local vvi
local xd1, yd1
local xd2, yd2
local td1, td2
local lineAvgPts = 4  -- number of points to linear fit to compute course
local vviSlopeTime = 0
local speedTime = 0
local numGPSreads = 0
local newPosTime = 0
local ff
local timSn = 0

local function loop()

   local minutes, degs
   local x, y
   local MAXVVITABLE = 5 -- points to fit to compute vertical speed
   local PATTERNALT = 200
   local tt, dd
   local hasPitot
   local hasCourseGPS
   local sensor
   local goodlat, goodlong 
   local brk, thr
   local newpos
   local deltaPosTime = 100 -- min sample interval in ms
   local latS, lonS, altS, spdS, hdgS
   local _

   if not rlhDone and fd then
      readLogHeader()
   end
   
   goodlat = false
   goodlong = false

   -- keep the checkmark on the menu for 300 msec
   
   if resetOrigin and (system.getTimeCounter() > (timeRO+300)) then
      gotInitPos = false
      resetOrigin=false
      resetClick = false
      form.setValue(resetCompIndex, resetClick) -- prob should double check same form still displayed...

      -- reset map window too
      graphInit()
      
      -- reset baro alt zero too
      baroAltZero = altitude

      print("Reset origin and barometric altitude. New baroAltZero is ", baroAltZero)
      -- dump(_G,"") -- print all globals for debugging
      
      -- if ff then io.close(ff) end
   end

   if DEBUG then
      debugTime =debugTime + 0.01*(system.getInputs("P7")+1)
--      speed = 40 + 80 * (math.sin(.3*debugTime) + 1)
      altitude = 20 + 200 * (math.cos(.3*debugTime)+1) + baroAltZero
      x = 900*math.sin(2*debugTime)
      y = 400*math.cos(3*debugTime)
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

   if fd and rlhDone then
      if (system.getTimeCounter() - logItems.sysStartTime) >= (tonumber(timS) - timSn)/10. and blocked then
	 blocked = false
	 goto fileInputLatLong
      end

      if blocked then return end

      local timS0 = timS -- blocked initialized to false, will flow to here first time

      if readLogTimeBlock() then
	 timS      =  logItems.timestamp -- remember timS is a string, not a number
	 latitude  =  logItems.vals['MGPS_Latitude'] or 0
	 longitude =  logItems.vals['MGPS_Longitude'] or 0
	 altitude  =  logItems.vals['CTU_Altitude'] or 0
	 speed     =  logItems.vals['MSPEED_Velocity'] or 0
	 
	 if timS0 == "0" then
	    timSn = tonumber(timS) -- first line in file even if t ~= 0 becomes time origin
	 end
	 local timSd60 = tonumber(timS)/(60000) -- to mins from ms
	 local min, sec = math.modf(timSd60)
	 sec = sec * 60
	 timSstr = string.format("%02d:%02d", min, sec)
	 blocked = true
	 return
      else
	 io.close(fd)
	 print('Closing log reply file')
	 fd = nil
      end
   end   
      
   --    tt = io.readline(fd)
   --    if tt then
   -- 	 timS, latS, lonS, altS, spdS, hdgS = string.match(tt, -- next string reads csv data -- really! :-)
   -- 							   "(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)%s*%,%s*(%-*%d+.%d+)"
   -- 	 )
   -- 	 latitude = tonumber(latS)
   -- 	 longitude = tonumber(lonS)
   -- 	 altitude = tonumber(altS)
   -- 	 speed = tonumber(spdS)
   -- 	 if speed > 1000 then speed = speed / 100 end -- hack: had x100 bug in files from nov 4
   -- 	 --heading = tonumber(hdgS) -- don't use saved heading for now --
   -- 	 if timS0 == "0" then
   -- 	    timSn = tonumber(timS) -- first line in file even if t ~= 0 becomes time origin
   -- 	 end
   -- 	 local timSd60 = tonumber(timS)/60
   -- 	 local min, sec = math.modf(timSd60)
   -- 	 sec = sec * 60
   -- 	 timSstr = string.format("%02d:%02d", min, sec)
	 
   -- 	 blocked = true
   -- 	 return
   --    else
   -- 	 io.close(fd)
   -- 	 print('Closing csv file')
   -- 	 fd = nil
   --    end
   -- end
   
   if fd then return end -- ok to get here if waiting for log file header to be read

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
	 SpeedNonGPS = sensor.value * 0.621371 * modelProps.pitotCal/100. -- unit conversion to mph
      end
      if sensor.unit == "m/s" then
	 SpeedNonGPS = sensor.value * 2.23694 * modelProps.pitotCal
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

--[[   

   sensor = system.getSensorByID(telem.DistanceGPS.SeId, telem.DistanceGPS.SePa)
   
   if(sensor and sensor.valid) then
      DistanceGPS = sensor.value*3.2808
   end      
--]]
   
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
   
   
   -- if ff then
   --    io.write(ff, string.format("%.4f, %.8f , %.8f , %.2f , %.2f , %.2f\n",
   -- 				 (system.getTimeCounter()-sysTimeStart)/1000.,
   -- 				 latitude, longitude, altitude, speed, (heading-variables.magneticVar) ) )
   -- end
   
   if (latitude == lastlat and longitude == lastlong) or (system.getTimeCounter() < newPosTime) then
      newpos = false
   else
      newpos = true
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

   -- defend against random bad points ... 1/6th degree is about 10 mi

   if (math.abs(longitude-long0) > 1/6) or (math.abs(latitude-lat0) > 1/6) then
      print('Bad lat/long: ', latitude, longitude, satCount, satQuality)
      return
   end
   
   x = rE*(longitude-long0)*coslat0/rad
   y = rE*(latitude-lat0)/rad
   
   -- update overall min and max for drawing the GPS
   -- maintain same pixel size (in feet) in X and Y (telem screen is 320x160)
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
	 _, compcrs = fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
				   table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {}))
      else
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
      
      vvi, _ = fslope(vviTim, vviAlt)
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
   else -- elseif not fd then -- if fd we are doing a replay .. heading read from the file .. leave it alone
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

   --[[
   if (controls.Brake) then
      brk = system.getInputsVal(controls.Brake)
   end
   if brk and brk < 0 and takeoff.oldBrake > 0 then
      takeoff.BrakeReleaseTime = system.getTimeCounter()
      print("Brake release")
      system.playFile("/Apps/DFM-LSO/brakes_released.wav", AUDIO_QUEUE)
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
   --]]

   if (modelProps.brakeChannel) then
      if modelProps.brakeOn > 0 then
	 brk = system.getInputs(modelProps.brakeChannel) > modelProps.brakeOn
      else
	 brk = system.getInputs(modelProps.brakeChannel) < modelProps.brakeOn
      end
      
   end

   if brk and not takeoff.oldBrake then
      takeoff.BrakeReleaseTime = system.getTimeCounter()
      print("Brake release")
      system.playFile("/Apps/DFM-LSO/brakes_released.wav", AUDIO_QUEUE)
   end

   if not brk then
      takeoff.BrakeReleaseTime = 0
      takeoff.Start.X = nil  -- erase the runway when the brakes go back on
      takeoff.Complete.X = nil
      takeoff.RunwayHeading = nil
      takeoff.NeverAirborne = true
      xr1 = nil -- recompute ILS points when new rwy coords
   end

   takeoff.oldBrake = brk
   
   if DEBUG and brk  then altitude = altitude + .15 end ------------------- DEBUG only

   
   --
   
   if (modelProps.throttleChannel) then
      if modelProps.throttleFull > 0 then
	 thr = (system.getInputs(modelProps.throttleChannel) > modelProps.throttleFull)
      else
	 thr = (system.getInputs(modelProps.throttleChannel) < modelProps.throttleFull)
      end
   end

   if thr and not takeoff.oldThrottle then
      print("Throttle up")
      if system.getTimeCounter() - takeoff.BrakeReleaseTime < 5000 then
	 takeoff.Start.X = x
	 takeoff.Start.Y = y
	 takeoff.Start.Z = altitude-baroAltZero
	 takeoff.ReleaseHeading = compcrsDeg + variables.magneticVar
	 print("Takeoff Start")
	 system.playFile("/Apps/DFM-LSO/starting_takeoff_roll.wav", AUDIO_QUEUE)
      end
   end

   takeoff.oldThrottle = thr

   -- if field is defined (iField has a value) then we already set takeoff start and complete to
   -- runway endpoints .. just note takeoff complete when altitude exceeds triggerpoint
   
   if iField and takeoff.NeverAirborne and (altitude - baroAltZero) - takeoff.Start.Z > PATTERNALT/4 then
      takeoff.NeverAirborne = false
   end
   
   -- if no field is defined...we have to compute the runway parameters
   
   if thr and takeoff.Start.X and takeoff.NeverAirborne and (not iField) then
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
	 system.playFile("/Apps/DFM-LSO/takeoff_complete.wav", AUDIO_QUEUE)
	 system.playNumber(heading, 0, "\u{B0}")
      end
   end
end

local function init()

   local fname
   local line

--[[
 
if the menu item to select a replay log file was used, the file is persisted by pSave in logPlayBacl
but this only works correctly on the TX .. the emulator's dir() iterator does not work. So if we are
running on the emulator, we check for the "magic name" of DFM-LSO.log -- if it exists we open it for
replay

--]]
   
   fname = system.pLoad("logPlayBack", "...")

   if fname ~= "..." then fd=io.open("Log/"..fname, "r") else
      fname = "DFM-LSO.log" -- try magic name if running on emulator since dir() does not work there%^&$%@
      fd = io.open("Apps/DFM-LSO/"..fname, "r")
      print("fd is", fd)
   end
   

   if fd then
      if form.question("Start replay?", "log file "..fname, "---",2500, false, 0) == 1 then
	 print("Opened log file "..fname.." for reading")
	 system.pSave("logPlayBack", "...")

	 readLogHeader()
	 print("rlh done")
	 logItems.logStartTime = tonumber(logItems.timestamp)
	 print("log ST:", logItems.logStartTime)
	 logItems.sysStartTime = system.getTimeCounter()
	 print("sys ST:", logItems.sysStartTime)
	 logItems.timeDelta = logItems.sysStartTime - logItems.logStartTime
	 DEBUG = false
      else
	 print("No replay")
	 io.close(fd)
	 fd = nil
      end
   end

   
   local fg = io.readall("Apps/DFM-LSO/Shapes.jsn")
   if fg then
      shapes = json.decode(fg)
   else
      print("Could not open Apps/DFM-LSO/Shapes.jsn")
   end

   fg = io.readall("Apps/DFM-LSO/Fields.jsn")
   if fg then
      geo = json.decode(fg)
   end

   setColorILS() -- this sets to a simple color scheme with fg color and complement color
   setColorMain()-- if a map is present it will change color scheme later
   
   graphInit()




















   for i, j in ipairs(telem) do
      telem[j].Se   = system.pLoad("telem."..telem[i]..".Se", 0)
      telem[j].SeId = system.pLoad("telem."..telem[i]..".SeId", 0)
      telem[j].SePa = system.pLoad("telem."..telem[i]..".SePa", 0)
   end

--   for i, j in ipairs(controls) do
--      controls[j] = system.pLoad("controls."..controls[i])
--   end
   
   for i, j in ipairs(variables) do
      variables[j] = system.pLoad("variables."..variables[i], 0)
   end
   
   system.registerForm(1, MENU_APPS, "Landing Signal Officer", initForm, nil, nil)
   system.registerTelemetry(1, "LSO Map", 4, mapPrint)
   system.registerTelemetry(2, "LSO ILS", 4, ilsPrint)
   glideSlopePNG = lcd.loadImage("Apps/DFM-LSO/glideslope.png")
   
   -- print("Model: ", system.getProperty("Model"))
   -- print("Model File: ", system.getProperty("ModelFile"))

   -- replace spaces in filenames with underscore
   -- print("reading: ", "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   
   fg = nil

   -- set default for pitotCal in case no "DFM-model.jsn" file

   modelProps.pitotCal = 100
   
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   if fg then
      modelProps=json.decode(fg)
   end

   -- print("mP.brakeChannel: ", modelProps.brakeChannel, "mP.brakeOn: ", modelProps.brakeOn)
   -- print("mP.throttleChannel", modelProps.throttleChannel, "mP.throttleFull", modelProps.throttleFull)
   
   system.playFile('/Apps/DFM-LSO/L_S_O_active.wav', AUDIO_QUEUE)
   
   if DEBUG then
      print('L_S_O_Active.wav')
   end

   readSensors()
   collectgarbage()
end


-- setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=LSOVersion, name="GPS LSO"}
