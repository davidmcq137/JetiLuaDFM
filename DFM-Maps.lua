--[[

   ---------------------------------------------------------------------------------------
   DFM-Maps.lua -- GPS map display and triangle racing app

   Derived from Twizard.lua and DFM-TriR.lua and DFM-LSO.lua --
   "Landing Signal Officer" -- GPS Map and "ILS"/GPS RNAV system
   derived from DFM's Speed and Time Announcers, which were turn was
   derived from Tero's RCT's Alt Announcer Borrowed and modified code
   from Jeti's AH example for tapes and heading indicator.  New code
   to project Lat/Long via simple equirectangular projection to XY
   plane, and to compute heading from the projected XY plane track for
   GPS sensors that don't have this feature
    
   Developed on DS-24, only tested on DS-24

   ---------------------------------------------------------------------------------------
   Released under MIT license by DFM 2020
   ---------------------------------------------------------------------------------------

   Bug/Work list:

   --reset gps origin makes a mess .. no images
   --"no sats" displayed for gps's that have no satcount (e.g. pb gps II)
   --pylon zone line length proportional to tri length? (looks funny on A74)
   --allow baro/pitot sensors as optional?
   --imperial units?
   --make it work with no maps as it did before? how zoom out?

--]]

local appInfo={}
appInfo.Name = "DFM-Maps"
appInfo.Maps = "DFM-Maps"
appInfo.menuTitle = "GPS Maps"
appInfo.Dir  = "Apps/" .. appInfo.Name .. "/"
appInfo.Fields = "Apps/" .. appInfo.Maps .. "/Maps/Fields.jsn"
appInfo.SaveData = true

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

local variables = {}

local xtable = {}
local ytable = {}
local MAXTABLE = 5
local map={}

local path={}
local bezierPath = {}

local shapes = {}
local pylon = {}
local nfc = {}
local nfp = {}
local tri = {}
local rwy = {}
local maxpolyX = 0.0
local Field = {}
local Fields = {}
local activeField
local xPHist={}
local yPHist={}
local xHistLast=0
local yHistLast = 0
local latHist={}
local lngHist={}
local rgbHist={}
local countNoNewPos = 0
local rgb = {}

local metrics={}
metrics.currMaxCPU = 0
metrics.loopCPU = 0
metrics.loopCPUMax = 0
metrics.loopCPUAvg = 0

local gotInitPos = false
local annTextSeq = 1
local preTextSeq = 1
local titleText
local subtitleText
local lastgetTime = 0
local inZone = {}
local currentGPSread = 0


-- these lists are the non-GPS sensors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }
local absAltGPS

local checkBox = {}
local checkBoxIndex = {}

--local triEnabled
--local triEnabledIndex
--local noflyEnabled
--local noflyEnabledIndex
--local noFlyWarnEnabled
--local noFlyWarnIndex

local pointSwitch
local zoomSwitch
local triASwitch
local startSwitch
local colorSwitch
local lastswc = -2
local swcCount = 0

local browse = {}
browse.Idx = 1
browse.List = {}
browse.OrignalFieldName = nil
browse.FieldName = nil
browse.MapDisplayed = false
browse.opTable = {"X","Y","R","L"}
browse.opTableIdx = 1

local colorSelect = {"None", "Altitude", "Speed", "Laps", "Switch",
	  "Rx1 Q", "Rx1 A1", "Rx1 A2", "Rx1 Volts",
	  "Rx2 Q", "Rx2 A1", "Rx2 A2", "Rx2 Volts"}	 

local savedRow = 1
local savedSubform

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

local dotImage = {}

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

local function jFilename()
   return appInfo.Dir .. "M-" .. string.gsub(system.getProperty("Model")..".jsn", " ", "_")
end

local function jLoadInit(fn)
   local fj
   local config
   fj = io.readall(fn)
   if fj then
      config = json.decode(fj)
   end
   if not config then
      print("Did not read jLoad file "..fn)
      config = {}
   else
      --print("Success reading jLoad file "..fn)
   end
   
   return config
end

local function jLoadFinal(fn, config)
   local ff
   ff = io.open(fn, "w")
   if not ff then
      return false
   end
   if not io.write(ff, json.encode(config)) then
      return false
   end
   io.close(ff)
   return true
end

local function jLoad(config, var, def)
   if not config then return nil end
   if config[var] == nil then
      config[var] = def
   end
   
   if type(config[var]) == "userdata" then print("var: userdata", var) end
	   
   if type(config[var]) == "table" and #config[var] == 0 then -- getSwitchInfo table
      return system.createSwitch(string.upper(config[var].label), config[var].mode, 1)
   end
   return config[var]
end

local function jSave(config, var, val)
   if type(val) == "userdata" then -- switchItem
      config[var]= system.getSwitchInfo(val)
      --print("jSave", config[var].label, config[var].value,
      --  config[var].proportional, config[var].assigned, config[var].mode)
   else
      config[var] = val
   end
end

local function destroy()
   if appInfo.SaveData then
      if jLoadFinal(jFilename(), variables) then
	 --print("jLoad successful write")
      else
	 --print("jLoad failed write")
      end
   end
end

local function readSensors()
   
   local jt, paramGPS
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

	    param = paramGPS[sensor.sensorName][sensor.label].param
	    label  = paramGPS[sensor.sensorName][sensor.label].telem
	    print("sensorName, param, label:", sensor.sensorName, param, label)
	    
	    if param and label then
	       if label == "SatCount" then
		  satCountID = sensor.id
		  satCountPa = param
	       elseif label == "SatQuality" then
		  satQualityID = sensor.id
		  satQualityPa = param
	       elseif label == "Altitude" then
		  if paramGPS and paramGPS[sensor.sensorName][sensor.label].AltType == "Rel" then
		     absAltGPS = false
		  else
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

local function xminImg(iM)
   return -0.50 * Field.imageWidth[iM]
end

local function xmaxImg(iM)
   return 0.50 * Field.imageWidth[iM]
end

local function yminImg(iM)
   if form.getActiveForm() then
      return -0.50 * Field.imageWidth[iM] / 1.8 -- 1.8 empirically determined  
   else
      return -0.50 * Field.imageWidth[iM] / 2.0
   end
end

local function ymaxImg(iM)
   if form.getActiveForm() then
      return 0.50 * Field.imageWidth[iM] / 1.8
   else
      return 0.50 * Field.imageWidth[iM] / 2.0
   end
end

local function graphInit(im)

   -- im or 1 construct allows im to be nil and if so selects images[1]
   -- print("graphInit: iField, im", iField, im)
   
   if Field.imageWidth and Field.imageWidth[im or 1] then
      map.Xmin = xminImg(im or 1)
      map.Xmax = xmaxImg(im or 1)
      map.Ymin = yminImg(im or 1)
      map.Ymax = ymaxImg(im or 1)
   else
      --print("**** graphInit hand setting 20/40")
      map.Xmin, map.Xmax = -40, 40
      map.Ymin, map.Ymax = -20, 20
   end

   map.Xrange = map.Xmax - map.Xmin
   map.Yrange = map.Ymax - map.Ymin
   
   path.xmin, path.xmax, path.ymin, path.ymax = map.Xmin, map.Xmax, map.Ymin, map.Ymax

end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function ll2xy(lat, lng)
   local tx, ty
   tx, ty = rotateXY(rE*(lng-lng0)*coslat0/rad,
		     rE*(lat-lat0)/rad,
		     math.rad(variables.rotationAngle))
   return {x=tx, y=ty}
end

local function rwy2XY()
	    
   rwy = {}
   if Field.runway then
      for j=1, #Field.runway.path, 1 do
	 rwy[j] = ll2xy(Field.runway.path[j].lat, Field.runway.path[j].lng)
	 --print("j, rwy.x, rwy.y:", j, rwy[j].x, rwy[j].y)
      end
      rwy.heading = Field.runway.heading
      --print("rwy heading:", rwy.heading)
   end
	    
end

local function tri2XY()
   tri = {}
   pylon = {}
   if Field.triangle then
      for j=1, #Field.triangle.path, 1 do
	 tri[j] = ll2xy(Field.triangle.path[j].lat, Field.triangle.path[j].lng)
      end
      tri.center = ll2xy(Field.triangle.center.lat, Field.triangle.center.lng)
   end
end

local function nfz2XY()
	    
   nfc = {}
   nfp = {}
   
   if Field.nofly then
      for j = 1, #Field.nofly, 1 do
	 if Field.nofly[j].type == "circle" then
	    local tt = ll2xy(Field.nofly[j].lat, Field.nofly[j].lng)
	    tt.r = Field.nofly[j].diameter / 2
	    tt.inside = Field.nofly[j].inside_or_outside == "inside"
	    table.insert(nfc, tt)
	 elseif Field.nofly[j].type == "polygon" then
	    local pp = {}
	    for k = 1, #Field.nofly[j].path, 1 do
	       table.insert(pp,ll2xy(Field.nofly[j].path[k].lat,Field.nofly[j].path[k].lng))
	       -- keep track of min bounding rectangle
	       if k == 1 then
	       	  pp.xmin = pp[1].x
	       	  pp.xmax = pp[1].x	       
	       	  pp.ymin = pp[1].y	       
	       	  pp.ymax = pp[1].y
	       else
	       	  if pp[k].x < pp.xmin then pp.xmin = pp[k].x end
	       	  if pp[k].x > pp.xmax then pp.xmax = pp[k].x end
	       	  if pp[k].y < pp.ymin then pp.ymin = pp[k].y end
	       	  if pp[k].y > pp.ymax then pp.ymax = pp[k].y end	       	       
	       end
	       -- we know 0,0 is at center of the image ... need an "infinity x" point for the
	       -- no fly region computation ... keep track of largest positive x ..
	       -- later we will double it to make sure it is well past the no fly polygon
	       if pp[#pp].x > maxpolyX then maxpolyX = pp[#pp].x end
	    end
	    -- compute bounding circle around the bounding rectangle
	    pp.xc = (pp.xmin + pp.xmax) / 2.0
	    pp.yc = (pp.ymin + pp.ymax) / 2.0
	    pp.r2 = ( (pp.ymax - pp.yc) * (pp.ymax - pp.yc) + (pp.xmax - pp.xc) * (pp.xmax - pp.xc))
	    pp.r  = math.sqrt(pp.r2) 
	    table.insert(nfp, {inside=(Field.nofly[j].inside_or_outside == "inside"),
			       path = pp,
			       xmin=pp.xmin, xmax=pp.xmax, ymin=pp.ymin, ymax = pp.ymax,
			       xc=pp.xc, yc=pp.yc, r=pp.r, r2 = pp.r2})
	 end
      end
   end
end

local function setColorMap()
   if fieldPNG[currentImage] then
      lcd.setColor(255,255,0)
   else
      lcd.setColor(0,0,0)
   end
end

local function setColorNoFlyInside()
   lcd.setColor(255,0,0)
end

local function setColorNoFlyOutside()
   lcd.setColor(0,255,0)
end

local function setColorMain()
   if fieldPNG[currentImage] then
      lcd.setColor(255,255,0)
   else
      lcd.setColor(0,0,0)
   end
end

local function setColorLabels()
   lcd.setColor(255,255,0)
end

local function setColorRunway()
   lcd.setColor(255,255,0)
end

local function setColorTriangle()
   lcd.setColor(100,255,255)
end

local function setColorTriRot()
   lcd.setColor(255,100,0)
end

local function setField(sname)

   Field = Fields[sname]
   Field.imageWidth = {}
   Field.lat = Field.images[1].center.lat
   Field.lng = Field.images[1].center.lng
   fieldPNG={}
   
   for k,v in ipairs(Field.images) do
      Field.imageWidth[k] = math.floor(v.meters_per_pixel * 320 + 0.5)
   end

   lng0 = Field.lng -- reset to origin to coords in jsn file
   lat0  = Field.lat
   coslat0 = math.cos(math.rad(lat0))
   variables.rotationAngle  = Field.images[1].heading
   tri2XY()
   rwy2XY()
   nfz2XY()
   
   setColorMap()
   setColorMain()
end

local function triReset()
   pylon = {}
end

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

local function variableChanged(value, var, fcn)
   if fcn then fcn() end
   variables[var] = value
   jSave(variables, var, value)
   --system.pSave("variables."..var, value)
end

local function validAnn(val, str)
   if string.find(str, val) then
      system.messageBox("Invalid Character(s)")
      return false
   else
      return true
   end
end

local function pointSwitchChanged(value)
   pointSwitch = value
   jSave(variables, "switchesSet", "true")
   system.pSave("pointSwitch", pointSwitch)
end

local function colorSwitchChanged(value)
   colorSwitch = value
   jSave(variables, "switchesSet", "true")
   system.pSave("colorSwitch", colorSwitch)
end

--local function zoomSwitchChanged(value)
--   zoomSwitch = value
--   jSave(variables, "switchesSet", "true")
--   --system.pSave("zoomSwitch", zoomSwitch)
--end

local function triASwitchChanged(value)
   triASwitch = value
   jSave(variables, "switchesSet", "true")
   system.pSave("triASwitch", triASwitch)
end

local function startSwitchChanged(value)
   startSwitch = value
   jSave(variables, "switchesSet", "true")
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
   jSave(variables, "triLength", value)
   --system.pSave("variables.triLength", variables.triLength)
   pylon = {}
end

local function raceTimeChanged(value)
   variables.raceTime = value
   jSave(variables, "raceTime", value)
   --system.pSave("variables.raceTime", variables.raceTime)
end

local function maxSpeedChanged(value)
   variables.maxSpeed = value
   jSave(variables, "maxSpeed", value)
   --system.pSave("variables.maxSpeed", variables.maxSpeed)
end

local function maxAltChanged(value)
   variables.maxAlt = value
   jSave(variables, "maxAlt", value)
   --system.pSave("variables.maxAlt", variables.maxAlt)
end

local function aimoffChanged(value)
   variables.aimoff = value
   jSave(variables, "aimoff", value)
   --system.pSave("variables.aimoff", variables.aimoff)
   pylon={}
end

local function flightStartAltChanged(value)
   variables.flightStartAlt = value
   jSave(variables, "flightStartAlt", value)
   --system.pSave("variables.flightStartAlt", variables.flightStartAlt)
end

local function flightStartSpdChanged(value)
   variables.flightStartSpd = value
   jSave(variables, "flightStartSpd", value)
   --system.pSave("variables.flightStartSpd", variables.flightStartSpd)
end

local function elevChanged(value)
   variables.elev = value
   jSave(variables, "elev", value)
   --system.pSave("variables.elev", variables.elev)
end

local function annTextChanged(value)
   if validAnn("[^cCdDpPtTaAsS%-]", value) then
      variables.annText = value
      jSave(variables, "annText", value)
   end
   form.reinit(7)
end

local function preTextChanged(value)
   if validAnn("[^aAsS%-]", value) then
      variables.preText = value
      jSave(variables, "preText", value)
   end
   form.reinit(8)
end

-- local function noFlyShakeEnabledClicked(value)
--    print("nFSEC", value)
--    checkBox.noFlyShakeEnabled = not value
--    jSave(variables, "noFlyShakeEnabled", not value)
--    form.setValue(checkBox.noFlyShakeIndex, checkBox.noFlyShakeEnabled)
-- end

-- local function noFlyWarningEnabledClicked(value)
--    print("nFWEC", value)
--    checkBox.noFlyWarningEnabled = not value
--    jSave(variables, "noFlyWarningEnabled", not value)
--    form.setValue(checkBox.noFlyWarningIndex, checkBox.noFlyWarningEnabled)
-- end

-- local function triEnabledClicked(value)
--    print("triEnabledClicked: value:", value)
--    checkBox.triEnabled = not value
--    jSave(variables, "triEnabled", not value)
--    form.setValue(checkBox.triEnabledIndex, checkBox.triEnabled)
-- end

-- local function noflyEnabledClicked(value)
--    print("nfEC", value)
--    checkBox.noflyEnabled = not value
--    jSave(variables, "noflyEnabled", not value)
--    form.setValue(checkBox.noflyEnabledIndex, checkBox.noflyEnabled)

-- end

local function checkBoxClicked(value, box)
   checkBox[box] = not value
   jSave(variables, box, not value)
   form.setValue(checkBoxIndex[box], checkBox[box])
end

--------------------------------------------------------------------------------

local function pngLoad(j)
   local pfn
   pfn = Field.images[j].file
   fieldPNG[j] = lcd.loadImage(pfn)
   
   if not fieldPNG[j] then
      print(appInfo.Name .. ": Failed to load image", j, pfn)
      return
   end

   -- get here if image file opened successfully
   
   Field.lat = Field.images[j].center.lat
   Field.lng = Field.images[j].center.lng
   lat0 = Field.lat
   lng0 = Field.lng
   coslat0 = math.cos(math.rad(lat0))
   rwy2XY()
   tri2XY()
   nfz2XY()
   xtable={}
   ytable={}
   xHistLast=0
   yHistLast = 0
   
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

local function triRot(ao)

   if #tri ~= 3 then return end

   -- adjust size from Fields file (Field.triangle.size) to menu (variables.triLength)
   -- and scale and rotate the triangle according to menu options

   --print("scale ratio:", (variables.triLength / Field.triangle.size))
   
   for i=1,3,1 do
      tri[i].dx = (variables.triLength / Field.triangle.size)*(tri[i].x - tri.center.x)
      tri[i].dy = (variables.triLength / Field.triangle.size)*(tri[i].y - tri.center.y )
      tri[i].dx, tri[i].dy = rotateXY(tri[i].dx, tri[i].dy, math.rad(variables.triRotation))
   end
   
   pylon[1] = {x = tri[2].dx + tri.center.x + variables.triOffsetX,
	       y = tri[2].dy + tri.center.y + variables.triOffsetY, aimoff=(ao or 0)}
   
   pylon[2] = {x=tri[1].dx + tri.center.x + variables.triOffsetX,
	       y=tri[1].dy + tri.center.y + variables.triOffsetY, aimoff=(ao or 0)}
   
   pylon[3] = {x=tri[3].dx + tri.center.x + variables.triOffsetX,
	       y=tri[3].dy + tri.center.y + variables.triOffsetY,aimoff=(ao or 0)}      
end

local function keyForm(key)
   local inc
   --print("key:", key, KEY_UP, KEY_DOWN)
   if (key == KEY_UP or key == KEY_DOWN) and savedSubform == 10 and
   browse.FieldName == browse.OriginalFieldName then
      if key == KEY_UP then inc = -1 else inc = 1 end
      if browse.opTable[browse.opTableIdx] == "X" then
	 variables.triOffsetX = variables.triOffsetX + -2*inc
	 browse.dispText = string.format("X %4d", variables.triOffsetX)
	 jSave(variables, "triOffsetX", variables.triOffsetX)	 	 
	 --system.pSave("variables.triOffsetX", variables.triOffsetX)	 
      elseif browse.opTable[browse.opTableIdx] == "Y" then
	 variables.triOffsetY = variables.triOffsetY + -2*inc
	 browse.dispText = string.format("Y %4d", variables.triOffsetY)
	 jSave(variables, "triOffsetY", variables.triOffsetY)	 
	 --system.pSave("variables.triOffsetY", variables.triOffsetY)
      elseif browse.opTable[browse.opTableIdx] == "R" then
	 variables.triRotation = variables.triRotation + inc
	 browse.dispText = string.format("R %4d", variables.triRotation)
	 jSave(variables, "triRotation", variables.triRotation)	 
	 --system.pSave("variables.triRotation", variables.triRotation)
      else -- L (length)
	 variables.triLength = variables.triLength + -5*inc
	 browse.dispText = string.format("L %4d", variables.triLength)
	 --print("triLength:", variables.triLength)
	 jSave(variables, "triLength", variables.triLength)	 
	 --system.pSave("variables.triLength", variables.triLength)
      end
      triRot(0)
   end
   
   if key == KEY_2 or key == KEY_3 or key == KEY_4 then

      if key == KEY_3 or key == KEY_4 then
	 if key == KEY_3 then inc = -1 else inc = 1 end
	 browse.Idx = browse.Idx + inc
	 browse.Idx = math.max(math.min(browse.Idx, #Fields[browse.FieldName].images), 1)
	 currentImage = browse.Idx
	 pngLoad(currentImage)
	 graphScaleRst(currentImage)
	 triRot(0) -- rotate and translate triangle to pylons
      else -- KEY_2
	 if savedSubform == 9 then
	    if not browse.OriginalFieldName then
	       --print("setting orig:", browse.OriginalFieldName, Field.shortname, activeField)
	       browse.OriginalFieldName = activeField
	    end
	    if browse.FieldName then
	       --print("setField to", browse.FieldName)
	       setField(browse.FieldName)
	       currentImage = 1
	       browse.Idx = 1
	       pngLoad(currentImage)
	       graphInit(currentImage)
	       graphScaleRst(currentImage)
	       triRot(0)
	    end
	    browse.MapDisplayed = true
	    form.reinit(10)
	 elseif savedSubform == 10 then
	    browse.opTableIdx = browse.opTableIdx + 1
	    if browse.opTableIdx > #browse.opTable then
	       browse.opTableIdx = 1
	    end
	    --print(browse.opTable[browse.opTableIdx])
	    form.reinit(10)
	 end
	 
      end
   end
   if key == KEY_1 or key == KEY_5 or key == KEY_ESC then
      --print("1/5/E", key, savedSubform)
      if savedSubform == 9 or savedSubform == 10 then
	 form.preventDefault()
	 if savedSubform == 10 then
	    browse.MapDisplayed = false
	 end
	 if key == KEY_1 then
	    --print("reinit 9")
	    form.reinit(9)
	 else
	    --print("resetting Field")
	    Field = {}
	    rwy = {}
	    nfc = {}
	    nfp = {}
	    tri = {}
	    fieldPNG={}
	    --browse.OriginalFieldName = nil
	    gotInitPos = false
	    xPHist = {}
	    yPHist = {}
	    latHist = {}
	    lngHist = {}
	    rgbHist = {}
	    form.reinit(1)
	    savedRow = 6
	    browse.Idx = 1
	    form.setTitle(appInfo.menuTitle)
	 end
      end
   end
end

local function browseFieldClicked(i)
   browse.Idx = i
   browse.FieldName = browse.List[i]
end

local function clearData()
   if form.question("Clear all data?",
		    "Press Yes to clear, timeout is No",
		    "Restart App after pressing Yes",
		    6000, false, 0) == 1 then
      io.remove(jFilename())
      appInfo.SaveData = false
   end
end

local function checkBoxAdd(lab, box)
   
   form.addRow(2)
   form.addLabel({label=lab, width=270})
   checkBoxIndex[box] =
      form.addCheckbox(checkBox[box],
		       	  (function(z) return checkBoxClicked(z, box) end) )
end

-- Draw the main form (Application inteface)


local function initForm(subform)

   savedSubform = subform
   
   if subform == 1 then
      form.setTitle("GPS Maps")
      
      form.addLink((function() form.reinit(2) end),
	 {label = "Telemetry Sensors >>"})

      form.addLink((function() form.reinit(3) end),
	 {label = "Race Parameters >>"})

      form.addLink((function() form.reinit(4) end),
	 {label = "Triangle Parameters >>"})

      form.addLink((function() form.reinit(5) end),
	 {label = "Track History >>"})

      form.addLink((function() form.reinit(6) end),
	 {label = "Settings >>"})            

      form.addLink((function() form.reinit(7) end),
	 {label = "Map Browser >>"})            

      --form.addRow(1)
      --form.addLabel({label="DFM", font=FONT_MINI, alignRight=true})

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
	 {label = "<<< Back to main menu",font=FONT_BOLD})
      
      form.setFocusedRow(1)      
   elseif subform == 3 then
      savedRow = subform-1

      checkBoxAdd("Enable Triangle Racecourse", "triEnabled")

      form.addRow(2)
      form.addLabel({label="Triangle racing ann switch", width=220})
      form.addInputbox(triASwitch, false, triASwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Triangle racing START switch", width=220})
      form.addInputbox(startSwitch, false, startSwitchChanged)
     
      form.addRow(2)
      form.addLabel({label="Triangle race time (m)", width=220})
      form.addIntbox(variables.raceTime, 1, 60, 30, 0, 1, raceTimeChanged)
      
      form.addRow(2)
      form.addLabel({label="Max Start Speed (km/h)", width=220})
      form.addIntbox(variables.maxSpeed, 10, 500, 100, 0, 10, maxSpeedChanged)
      
      form.addRow(2)
      form.addLabel({label="Max Start Alt (m)", width=220})
      form.addIntbox(variables.maxAlt, 10, 500, 100, 0, 10, maxAltChanged)
      
      form.addRow(2)
      form.addLabel({label="Flight Start Speed (km/h)", width=220})
      form.addIntbox(variables.flightStartSpd, 0, 100, 20, 0, 1, flightStartSpdChanged)

      form.addRow(2)
      form.addLabel({label="Flight Start Altitude (m)", width=220})
      form.addIntbox(variables.flightStartAlt, 0, 100, 20, 0, 1, flightStartAltChanged)

      form.addLink((function() form.reinit(8) end),
	 {label = "Racing announce sequence >>"})            

      form.addLink((function() form.reinit(9) end),
	 {label = "Racing pre-announce sequence >>"})            

      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})

      form.setFocusedRow(1)

   elseif subform == 4 then
      savedRow = subform-1
      
      form.addRow(2)
      form.addLabel({label="Triangle leg", width=220})
      form.addIntbox(variables.triLength, 10, 1000, 250, 0, 1, triLengthChanged)
      
      form.addRow(2)
      form.addLabel({label="Turn point aiming offset (m)", width=220})
      form.addIntbox(variables.aimoff, 0, 500, 50, 0, 1, aimoffChanged)
      
      form.addRow(2)
      form.addLabel({label="Triangle Rotation (deg CCW)", width=220})
      form.addIntbox(variables.triRotation, -180, 180, 0, 0, 1,
		     (function(xx) return variableChanged(xx, "triRotation", triReset) end) )
      
      form.addRow(2)
      form.addLabel({label="Triangle Left (-) / Right(+) (m)", width=220})
      form.addIntbox(variables.triOffsetX, -1000, 1000, 0, 0, 1,
		     (function(xx) return variableChanged(xx, "triOffsetX", triReset) end) )
      
      form.addRow(2)
      form.addLabel({label="Triangle Up(+) / Down(-) (m)", width=220})
      form.addIntbox(variables.triOffsetY, -1000, 1000, 0, 0, 1,
		     (function(xx) return variableChanged(xx, "triOffsetY", triReset) end) )

      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})

      form.setFocusedRow(1)


   elseif subform == 5 then
      savedRow = subform-1
      -- not worth it do to a loop with a menu item table for Intbox due to the
      -- variation in defaults etc nor for addCheckbox due to specialized nature
      
      form.addRow(2)
      form.addLabel({label="History Sample Time (ms)", width=220})
      form.addIntbox(variables.histSample, 1000, 10000, 1000, 0, 100,
		     (function(z) return variableChanged(z, "histSample") end) )
      
      form.addRow(2)
      form.addLabel({label="Number of History Samples", width=220})
      form.addIntbox(variables.histMax, 0, 600, 300, 0, 10,
		     (function(z) return variableChanged(z, "histMax") end) )
      
      form.addRow(2)
      form.addLabel({label="Min Hist dist to new pt", width=220})
      form.addIntbox(variables.histDistance, 1, 10, 3, 0, 1,
		     (function(z) return variableChanged(z, "histDistance") end) )
      
      --form.addRow(2)
      --form.addLabel({label="Max CPU usage permitted (%)", width=220})
      --form.addIntbox(variables.maxCPU, 0, 100, 80, 0, 1,
      --	     (function(z) return variableChanged(z, "maxCPU") end) )
      
      form.addRow(2)
      form.addLabel({label="Flight path points on/off sw", width=220})
      form.addInputbox(pointSwitch, false, pointSwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Ribbon Color Source", width=200})
      form.addSelectbox(
	 colorSelect,
	 variables.ribbonColorSource, true,
	 (function(z) return variableChanged(z, "ribbonColorSource") end) )
      
      form.addRow(2)
      form.addLabel({label="Ribbon Color Increment sw", width=220})
      form.addInputbox(colorSwitch, false, colorSwitchChanged)

      form.addLink((function() form.reinit(11) end), {label = "View Color Gradient>>"})
	 
      -- form.addRow(2)
      -- form.addLabel({label="History ribbon width", width=220})
      -- form.addIntbox(variables.ribbonWidth, 1, 4, 2, 0, 1,
      -- 		     (function(z) return variableChanged(z, "ribbonWidth") end) )

      -- form.addRow(2)
      -- form.addLabel({label="History ribbon density", width=220})
      -- form.addIntbox(variables.ribbonAlpha, 1, 10, 4, 0, 1,
      -- 		     (function(z) return variableChanged(z, "ribbonAlpha") end) )

      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})
      
      form.setFocusedRow(1)
      
   elseif subform == 6 then
      savedRow = subform-1

      form.addRow(2)
      form.addLabel({label="Future position (msec)", width=220})
      form.addIntbox(variables.futureMillis, 0, 10000, 2000, 0, 10,
		     (function(xx) return variableChanged(xx, "futureMillis") end) )

      checkBoxAdd("Show No Fly Zones", "noflyEnabled")
      -- form.addRow(2)
      -- form.addLabel({label="Show NoFly Zones", width=270})
      -- checkBox.noflyEnabledIndex = form.addCheckbox(checkBox.noflyEnabled, noflyEnabledClicked)

      checkBoxAdd("Announce No Fly Entry/Exit", "noFlyWarningEnabled")
      -- form.addRow(2)
      -- form.addLabel({label="Announce NoFly Entry/Exit", width=270})
      -- checkBox.noFlyWarningIndex =
      -- 	 form.addCheckbox(checkBox.noFlyWarningEnabled, noFlyWarningEnabledClicked)
      
      checkBoxAdd("Stick Shake on No Fly Entry", "noFlyShakeEnabled")
      -- form.addRow(2)
      -- form.addLabel({label="Stick Shake on NoFly Entry", width=270})
      -- checkBox.noFlyShakeIndex =
      -- 	 form.addCheckbox(checkBox.noFlyShakeEnabled, noFlyShakeEnabledClicked)

      form.addRow(2)
      form.addLabel({label="Field elevation adjustment (m)", width=220})
      form.addIntbox(variables.elev, -1000, 1000, 0, 0, 1, elevChanged)
      
      
      --form.addRow(2)
      --form.addLabel({label="Zoom reset sw", width=220})
      --form.addInputbox(zoomSwitch, false, zoomSwitchChanged)

      --form.addRow(2)
      --form.addLabel({label="Reset GPS origin and Baro Alt", width=274})
      --resetCompIndex=form.addCheckbox(resetClick, resetOriginChanged)
      
      form.addLink(clearData, {label = "Clear all data and settings"})
      
      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})

      form.setFocusedRow(1)

      
   elseif subform == 7 then
      savedRow = subform-1
      ----------
      form.setTitle("")
      form.setButton(2, "Show", 1)
      
      browse.List = {}
      for k,_ in pairs(Fields) do
	 table.insert(browse.List, k)
      end
      table.sort(browse.List, function(a,b) return a<b end)
      browse.Idx = 1

      for k,v in ipairs(browse.List) do
	 if activeField == v then
	    browse.Idx = k
	 end 
      end

      if #browse.List > 0 then      
	 browse.FieldName = Fields[browse.List[browse.Idx]].shortname
      end

      form.addRow(2)
      form.addLabel({label="Select Field to Browse"})
      form.addSelectbox(browse.List, browse.Idx, true, browseFieldClicked)
      form.addRow(1)
      form.addLabel({label=""})      
      form.addRow(1)
      form.addLabel({label="<Show> to browse maps of selected field", font=FONT_NORMAL})
      --form.addRow(1)
      --form.addLabel({label=""})      
      form.addRow(1)
      form.addLabel({label="If you browse the currently active field:", font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label="On the map image screen, edit the optional triangle", font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label="racing course using transmitter's 3D control dial", font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label="Press button 2 to cycle through the settable parameters", font=FONT_MINI})
      form.addRow(1)      
      form.addLabel({label="X: left/right Y: Up/Down R: Rotation CW/CCW L: Length", font=FONT_MINI})
      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})
      
      form.setFocusedRow(1)

   elseif subform == 8 or subform == 9 then
      if subform == 8 then
	 form.addRow(1)
	 form.addLabel({label="c/C: Course correction (° Left/Right)", width=220, font=FONT_MINI})
	 form.addRow(1)
	 form.addLabel({label="d/D: Distance to next pylon (m)", width=220, font=FONT_MINI})
	 form.addRow(1)
	 form.addLabel({label="p/P: Perpendicular distance to triangle leg (m)", width=220, font=FONT_MINI})
	 form.addRow(1)
	 form.addLabel({label="t/T: Time to pylon (s)", width=220, font=FONT_MINI})
      end
      form.addRow(1)
      form.addLabel({label="a/A: Altitude (m)", width=220, font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label="s/S: Speed (km/h)", width=220, font=FONT_MINI})
      form.addRow(2)
      local temp
      if subform == 8 then
	 form.addLabel({label="Racing announce sequence", width=220})
	 temp = variables.annText
	 form.addTextbox(temp, 30, annTextChanged)
      else
	 form.addLabel({label="Pre-race announce sequence", width=220})
	 form.addTextbox(variables.preText, 30, preTextChanged)
      end
      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})

   elseif subform == 10 then
      --print("savedRow to", subform-1)
      browse.MapDisplayed = true
      if browse.FieldName == browse.OriginalFieldName then
	 form.setButton(2, browse.opTable[browse.opTableIdx], 1)
      end
      form.setTitle("")
      form.setButton(1, ":backward", 1)
      form.setButton(3, ":down" , 1)            
      form.setButton(4, ":up", 1)
   elseif subform == 11 then
      savedRow = 4
      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu", font=FONT_BOLD})
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



local text

local function playFile(fn, as)
   if emFlag then
      local fp = io.open(fn)
      if not fp then
	 print(appInfo.Name .. ": Cannot open file "..fn)
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
   return pix --math.min(math.max(pix, 0), width)
end

local function toYPixel(coord, min, range, height)
   local pix
   pix = height-(coord - min)/range * height
   return pix --math.min(math.max(pix, 0), height)
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
   
   pd = math.abs(
         (pylon[nextP].y-pylon[lastP].y) * x0 -
	 (pylon[nextP].x-pylon[lastP].x)*y0 +
	  pylon[nextP].x*pylon[lastP].y -
	  pylon[nextP].y*pylon[lastP].x) /
          math.sqrt( (pylon[nextP].y-pylon[lastP].y)^2 +
	  (pylon[nextP].x-pylon[lastP].x)^2)
   det = (x0-pylon[lastP].x)*(pylon[nextP].y-pylon[lastP].y) -
      (y0-pylon[lastP].y)*(pylon[nextP].x-pylon[lastP].x)
   
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
local inZoneLast = {}

local function drawTriRace(windowWidth, windowHeight)

   local ren=lcd.renderer()

   --print("variables.triEnabled", variables.triEnabled)

   --print("pylon[1], pylon.finished", pylon[1], pylon.finished)
   
   if not variables.triEnabled then return end
   if not pylon[1] then return end
   if not pylon.finished then return end
   
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
   if #pylon == 3 and pylon.start then
      ren:reset()
      ren:addPoint(toXPixel(pylon[2].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[2].y, map.Ymin, map.Yrange, windowHeight))
      ren:addPoint(toXPixel(pylon.start.x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon.start.y,map.Ymin,map.Yrange,windowHeight))
      ren:renderPolyline(2,0.7)
   end


   setColorMain()

   -- draw the turning zones and the aiming points. The zones turn red when the airplane
   -- is in them .. the aiming point you are flying to is red.
   for j = 1, #pylon do
      if raceParam.racing and inZone[j] then lcd.setColor(255,0,0) end
      --print(j, pylon[j].x, pylon[j].y, pylon[j].zyl, pylon[j].zyr, pylon.finished)
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
      lcd.drawImage(5, 100, dotImage.green)
   else
      lcd.drawImage(5,100, dotImage.red)
   end

   if raceParam.startArmed then
      if raceParam.racing then
	 lcd.drawImage(25, 100, dotImage.blue)
      else
	 lcd.drawImage(25, 100, dotImage.green)
      end
   else
      if startSwitch then lcd.drawImage(25, 100, dotImage.red) end
   end
   
   lcd.drawText(5, 120, "Alt: ".. math.floor(altitude), FONT_MINI)
   lcd.drawText(5, 130, "Spd: "..math.floor(speed), FONT_MINI)
   --lcd.drawText(5, 140, string.format("Map Width %d m", map.Xrange), FONT_MINI)
   if variables.ribbonColorSource ~= 1 then
      lcd.drawText(5, 140, string.format("R: %s ",
					 colorSelect[variables.ribbonColorSource]), FONT_MINI)
   end
   
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

   if not Field or not Field.name or not Field.triangle then return end
   if not variables.triEnabled then return end
   if #xtable == 0 or #ytable == 0 then return end
   
   if Field then
      ao = variables.aimoff
   else
      ao = 0
   end

   -- if no course computed yet, start by defining the pylons
   --print("#pylon, Field.name", #pylon, Field.name)
   if (#pylon < 3) and Field.name then -- need to confirm with RFM order of vertices
      triRot(ao) -- handle rotation and tranlation of triangle course 
      -- extend startline below hypotenuse of triangle  by 0.8x inside length
      pylon.start = {x=tri.center.x + variables.triOffsetX +
			0.8 * (tri.center.x + variables.triOffsetX- pylon[2].x),
		     y=tri.center.y + variables.triOffsetY +
			0.8 * (tri.center.y + variables.triOffsetY - pylon[2].y)}
   end

   --local region={2,3,3,1,2,1,0}

   -- first time thru, compute all the ancillary data that goes with each pylon
   -- xm, ym is midpoint of opposite side from vertex
   -- xe, ye is the extension of the midpoint to vertex line
   -- xt, yt is the "target" or aiming point
   -- z*, y* are the left and right sides of the turning zones
   
   if (#pylon ==3) and (not pylon[1].xm) then
      --print("calcTriRace .xm")
      for j=1, #pylon do
	 local zx, zy
	 local rot = {
	    math.rad(-112.5) + math.rad(variables.triRotation) -
	       math.rad(Field.triangle.heading - Field.images[1].heading),
	    math.rad(variables.triRotation) -
	       math.rad(Field.triangle.heading - Field.images[1].heading),
	    math.rad(112.5) + math.rad(variables.triRotation) -
	       math.rad(Field.triangle.heading - Field.images[1].heading)
	 }
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
	 pylon.finished = true
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
   -- https://math.stackexchange.com/questions/274712/
   -- calculate-on-which-side-of-a-straight-line-is-a-given-point-located   
   
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
      print(appInfo.Name .. ": code out of range")
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

   if #pylon == 3 and pylon.start then
      detS1 = (xtable[#xtable] - tri.center.x) * (pylon.start.y - tri.center.y) -
	 (ytable[#ytable] - tri.center.y) * (pylon.start.x - tri.center.x)
   end
   

   local inStartZone
   if not detS1 then print("not detS1") end
   if detS1 and detS1 >= 0 then inStartZone = true else inStartZone = false end
   
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
   
   if lastdetS1 >= 0 and detS1 <= 0 then
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
	       --print("speed, variables.maxSpeed", speed, variables.maxSpeed)
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

   if detS1 then lastdetS1 = detS1 end
   
   local sgTC = system.getTimeCounter()

   --print( (sgTC - raceParam.racingStartTime) / 1000, variables.raceTime*60)
   if raceParam.racing and (sgTC - raceParam.racingStartTime) / 1000 >= variables.raceTime*60 then
      print("FINISHED")
      playFile(appInfo.Dir.."Audio/race_finished.wav", AUDIO_IMMEDIATE)	    	 
      raceParam.racing = false
      raceParam.raceFinished = true
      raceParam.startArmed = false
      raceParam.startToggled = false
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
				   raceParam.lapsComplete,
				   math.floor(raceParam.rawScore - raceParam.penaltyPoints + 0.5),
			   math.floor(raceParam.penaltyPoints + 0.5))
      --lcd.drawText((310 - lcd.getTextWidth(FONT_MINI, tstr))/2, 17, tstr, FONT_MINI)
   end

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
	 if annTextSeq > #variables.annText then
	    annTextSeq = 1
	 end
	 sChar = variables.annText:sub(annTextSeq,annTextSeq)
      else
	 preTextSeq = preTextSeq + 1
	 if preTextSeq > #variables.preText then
	    preTextSeq = 1
	 end
	 sChar = variables.preText:sub(preTextSeq,preTextSeq)
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

--local function isNoFlyP(pp, io, p)
--noFlyP = noFlyP or isNoFlyP(nfp[i].path, nfp[i].inside, txy)

local function isNoFlyP(nn,p) 

   local isInside
   local next

   -- There must be at least 3 vertices in polygon[]

   if (#nn.path < 3)  then return false end

   --first see if we are inside the bounding circle
   --if so, isInside is false .. jump to end
   --else run full algorithm

   if ((p.x - nn.xc) * (p.x - nn.xc) + (p.y - nn.yc) * (p.y - nn.yc)) > nn.r2 then
      isInside = false
   else
      --Create a point for line segment from p to infinite 
      extreme = {x=2*maxpolyX, y=p.y}; 
      
      -- Count intersections of the above line with sides of polygon 
      local count = 0
      local i = 1
      local n = #nn.path
      
      repeat
	 next = i % n + 1
	 if (doIntersect(nn.path[i], nn.path[next], p, extreme)) then 
	    -- If the point 'p' is colinear with line segment 'i-next', 
	    -- then check if it lies on segment. If it lies, return true, 
	    -- otherwise false 
	    if (orientation(nn.path[i], p, nn.path[next]) == 0) then 
	       return onSegment(nn.path[i], p, nn.path[next])
	    end
	    count = count + 1 
	 end
	 
	 i = next
      until (i == 1)
      
      -- Point inside polygon: true if count is odd, false otherwise
      isInside = (count % 2 == 1)
   end
   
   if nn.inside == true then
      return isInside
   else
      return not isInside
   end
   
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
local function prtForm(windowWidth, windowHeight)

   
   --print(form.getActiveForm() or "---", savedRow)
   
   --if not form.getActiveForm() then return end
   --if not browse.MapDisplayed then return end
   
   setColorMap()
   
   setColorMain()
   
   -- if fieldPNG[currentImage] then
   --    lcd.drawImage(0,0,fieldPNG[currentImage], 255)
   -- else
   --    local txt = "No browse image"
   --    lcd.drawText((310 - lcd.getTextWidth(FONT_BIG, txt))/2, 90, txt, FONT_BIG)
   -- end

   if savedSubform == 11 then 
      for i = 1, #shapes.gradient, 1 do
	 lcd.setColor(rgb[i].r, rgb[i].g, rgb[i].b)
	 lcd.drawFilledRectangle(-5 + 30*i, 40, 25, 25)
	 lcd.setColor(0,0,0)
	 lcd.drawText(2+30*i, 70, tostring(i))
      end
      
   elseif savedSubform == 10 then
      if not browse.MapDisplayed then return end
      if #browse.List < 1 then return end
      local ren=lcd.renderer()

      --lcd.setColor(0,41,15)
      --lcd.drawFilledRectangle(0,0,windowWidth, windowHeight)

      -- tele window images are 0-319 x 0-159 (2:1)
      -- forms window images are 0-310 x 0-143 (2.159:1)
      lcd.drawImage(-5,8,fieldPNG[currentImage],255)-- -5 and 15 (175-160??) determined empirically (ugg)      
      --lcd.drawImage(-5,15,fieldPNG[currentImage],255)-- -5 and 15 (175-160??) determined empirically (ugg)
      if Field then
	 --lcd.drawCircle(0,0,10)
	 setColorLabels()
	 lcd.drawText(10,10, Field.images[currentImage].file, FONT_NORMAL)	 
	 --[[
	 lcd.drawText(10,25,Field.shortname .." - " ..Field.name, FONT_MINI)
	 lcd.drawText(10,35,"Width: " ..  Field.imageWidth[currentImage] .." m", FONT_MINI)
	 lcd.drawText(10,45,"Lat: " ..  string.format("%.6f", lat0) .. "°", FONT_MINI)
	 lcd.drawText(10,55,"Lon: " ..  string.format("%.6f", lng0) .. "°", FONT_MINI)
	 if Field.elevation then
	   lcd.drawText(10,65,"Elev: " .. math.floor(Field.elevation.elevation+0.5) .." m",
	 		 FONT_MINI)
	 end
	 --]]
	 
	 lcd.drawText(80,145,(browse.dispText or ""), FONT_NORMAL)	 
	 --lcd.setClipping(0,15,310,160)

	 setColorRunway()
	 if #rwy == 4 then
	    ren:reset()
	    for j = 1, 5, 1 do
	       if j == 1 then
	       end
	       ren:addPoint(toXPixel(rwy[j%4+1].x, map.Xmin, map.Xrange, windowWidth),
			    toYPixel(rwy[j%4+1].y, map.Ymin, map.Yrange, windowHeight))
	    end
	    ren:renderPolyline(2,0.7)
	 end

	 if #tri == 3 then
	    ren:reset()
	    for j= 1, 4, 1 do
	       ren:addPoint(toXPixel(tri[j%3+1].x, map.Xmin, map.Xrange, windowWidth),
			    toYPixel(tri[j%3+1].y, map.Ymin, map.Yrange, windowHeight))
	    end
	    setColorTriangle()
	    ren:renderPolyline(2,0.7)
	 else
	    --print("#tri:", #tri)
	 end

	 if browse.FieldName == browse.OriginalFieldName then
	    if #pylon == 3 then
	       ren:reset()
	       for j= 1, 4, 1 do
		  ren:addPoint(toXPixel(pylon[j%3+1].x, map.Xmin, map.Xrange, windowWidth),
			       toYPixel(pylon[j%3+1].y, map.Ymin, map.Yrange, windowHeight))
	       end
	       setColorTriRot()
	       ren:renderPolyline(2,0.7)
	    end
	 end
	 
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
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(0, 166, 320,20)
      lcd.drawFilledRectangle(0, 0, 320,8)      
      setColorMain()
   end
end


local function dirPrint()
   local xa, ya
   local xp, yp
   local theta
   local dotpng

   if form.getActiveForm() then return end

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
      if m3(nextPylon) == 1 then dotpng = dotImage.red
      elseif m3(nextPylon) == 2 then dotpng = dotImage.green
      elseif m3(nextPylon) == 3 then dotpng = dotImage.blue
      end
      lcd.drawImage((xp+xa-7), (yp+ya-7), dotpng)
      --lcd.drawCircle(xp+xa, yp+ya,5)
   else
      lcd.drawImage(xa-7, ya-7, dotImage.red)
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


   lcd.drawText(80-lcd.getTextWidth(FONT_MINI, string.format("#xPHist %d", #xPHist)) / 2,
		100, text, FONT_MINI)
   
   lcd.drawText(80-lcd.getTextWidth(FONT_MINI, string.format("NNP %d", countNoNewPos)) / 2,
		110, text, FONT_MINI)

   lcd.drawText(80-lcd.getTextWidth(FONT_MINI, string.format("(%d,%d)", x or 0, y or 0)) / 2,
		120, text, FONT_MINI)

end

local noFlyHist = {}
noFlyHist.Last = false
noFlyHist.LastF = false
noFlyHist.LastTime = 0
noFlyHist.LastFTime = 0
noFlyHist.LastX = 0.0
noFlyHist.LastY = 0.0
noFlyHist.LastFX = 0.0
noFlyHist.LastFY = 0.0

local function checkNoFly(xt, yt, future, warn)
   
   local noFly, noFlyF, noFlyP, noFlyC, txy

   -- if we have a result within 1 sec and 1 meter, return the prior cached value

   if not future then
      if (system.getTimeCounter() - noFlyHist.LastTime) < 1000
      and math.abs(xt - noFlyHist.LastX) < 1 and math.abs(yt - noFlyHist.LastY) < 1 then
	 return noFlyHist.Last
      end
   else
      if (system.getTimeCounter() - noFlyHist.LastFTime) < 1000
      and math.abs(xt - noFlyHist.LastFX) < 1 and math.abs(yt - noFlyHist.LastFY) < 1 then
	 return noFlyHist.LastF
      end
   end

   if not future then
      txy = {x=xt, y=yt}
   else
      if xtable.xf and ytable.yf then
	 txy = {x=xtable.xf, y=ytable.yf}
      else -- maybe not set yet .. ignore
	 return false
      end
   end

   noFlyP = false
   for i=1, #nfp, 1 do
      noFlyP = noFlyP or isNoFlyP(nfp[i], txy)      
   end
   
   noFlyC = false
   for i=1, #nfc, 1 do
      noFlyC = noFlyC or isNoFlyC(nfc[i], txy)
   end

   if not future then
      noFly = noFlyP or noFlyC
   else
      noFlyF = noFlyP or noFlyC
   end
   
   if noFly ~= noFlyHist.Last and not future then
      if noFly then
	 if checkBox.noFlyWarningEnabled and warn then
	    playFile(appInfo.Dir.."Audio/Warning_No_Fly_Zone.wav", AUDIO_IMMEDIATE)
	 end
	 if checkBox.noFlyShakeEnabled and warn then
	    system.vibration(false, 3) -- left stick, 2x short pulse
	 end
      else
	 if checkBox.noFlyWarningEnabled and warn then
	    playFile(appInfo.Dir.."Audio/Leaving_no_fly_zone.wav", AUDIO_QUEUE)
	 end
      end
   end
   
   if noFlyF ~= noFlyHist.LastF and future then
      if noFlyF then
	 if not noFly and warn then -- only warn of future nfz if not already in nfz
	    playFile(appInfo.Dir.."Audio/no_fly_ahead.wav", AUDIO_IMMEDIATE)
	    --system.vibration(false, 3) -- left stick, 2x short pulse
	 end
      end
   end

   if not future then
      noFlyHist.Last = noFly
      noFlyHist.LastTime = system.getTimeCounter()
      noFlyHist.LastX = xt
      noFlyHist.LastY = yt
      return noFly
   else
      noFlyHist.LastF = noFlyF
      noFlyHist.LastFTime = system.getTimeCounter()
      noFlyHist.LastFX = xtable.xf
      noFlyHist.LastFY = ytable.yf
      return noFlyF
   end
   
end

local recalcPixels = false
local recalcCount = 0

local function recalcDone()
   local i

   if recalcPixels == false then return true end
   
   for j = 1, 50, 1 do
      i = j+recalcCount
      if i > #latHist then
	 recalcPixels = false
	 recalcCount = 0
	 return true
      end
      xPHist[i], yPHist[i] = rotateXY(rE*(lngHist[i]-lng0)*coslat0/rad,
				      rE*(latHist[i]-lat0)/rad,
				      math.rad(variables.rotationAngle))
      xPHist[i] = toXPixel(xPHist[i], map.Xmin, map.Xrange, 319)
      yPHist[i] = toYPixel(yPHist[i], map.Ymin, map.Yrange, 159)
   end
   recalcCount = i
   if recalcCount >= #latHist then
      recalcPixels = false
      recalcCount = 0
      return true
   else
      return false
   end
end

local function graphScale(xx, yy)

   if not xx or not yy then return end
   
   if not map.Xmax then
      print("BAD! -- setting max and min in graphScale")
      map.Xmax=   40
      map.Xmin = -40
      map.Ymax =  20
      map.Ymin = -20
   end
   
   if xx > path.xmax then
      --print("path.xmax:", map.Xmax, xx, yy, Field.name)
      path.xmax = xx
   end
   if xx < path.xmin then
      --print("path.xmin:", map.Xmin, xx, yy, Field.name)
      path.xmin = xx
   end
   if yy > path.ymax then
      --print("path.ymax:", map.Ymax, xx, yy, Field.name)
      path.ymax = yy
   end
   if yy < path.ymin then
      --print("path.ymin:", map.Ymin, xx, yy, Field.name)
      path.ymin = yy
   end

   -- if we have an image then scale factor comes from the image
   -- check each image scale .. maxs and mins are precomputed
   -- starting from most zoomed in image (the first one), stop
   -- when the path fits within the window or at max image size
   
   if currentImage then
      if path.xmin < xminImg(currentImage) or
	 path.xmax > xmaxImg(currentImage) or
	 path.ymin < yminImg(currentImage) or
	 path.ymax > ymaxImg(currentImage)
      then
	 currentImage = math.min(currentImage+1, maxImage)
      end

      if not fieldPNG[currentImage] then
	 pngLoad(currentImage)
	 graphScaleRst(currentImage)
	 recalcPixels =  true
	 recalcCount = 0
      end
   else
      --print("** graphScale else clause **")
      -- if no image then just scale to keep the path on the map
      -- round Xrange to nearest 60 m, Yrange to nearest 30 m maintain 2:1 aspect ratio
      map.Xrange = math.floor((path.xmax-path.xmin)/60 + .5) * 60
      map.Yrange = math.floor((path.ymax-path.ymin)/30 + .5) * 30
      
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
   
end

local swzTime = 0
local panic = false

local function mapPrint(windowWidth, windowHeight)

   local swp
   local swz
   local offset
   local ren=lcd.renderer()
   
   if form.getActiveForm() then return end
   
   if recalcDone() then
      graphScale(xtable[#xtable], ytable[#ytable])
   end
   
   setColorMap()
   
   setColorMain()

   if fieldPNG[currentImage] then
      lcd.drawImage(0,0,fieldPNG[currentImage], 255)
   else
      lcd.drawText((320 - lcd.getTextWidth(FONT_BIG, "No GPS fix or no Image"))/2, 40,
	 "No GPS fix or no Image", FONT_BIG)
   end
   
   -- in case the draw functions left color set to their specific values
   setColorMain()

   --lcd.drawCircle(160, 80, 5) -- circle in center of screen
   
   lcd.drawText(20-lcd.getTextWidth(FONT_MINI, "N") / 2, 34, "N", FONT_MINI)
   drawShape(20, 40, shapes.arrow, math.rad(-1*variables.rotationAngle))
   lcd.drawCircle(20, 40, 7)

   if satCount then
      text=string.format("%2d Sats", satCount)
      --lcd.drawText(35-lcd.getTextWidth(FONT_MINI, text) / 2, 50, text, FONT_MINI)
      lcd.drawText(5, 50, text, FONT_MINI)
   else
      text = "No Sats"
      --lcd.drawText(35-lcd.getTextWidth(FONT_MINI, text) / 2, 50, text, FONT_MINI)
      lcd.drawText(5, 50, text, FONT_MINI)      
   end

   -- if satQuality then
   --    text=string.format("SatQ %.0f", satQuality)
   --    --lcd.drawText(35-lcd.getTextWidth(FONT_MINI, text) / 2, 62, text, FONT_MINI)
   --    lcd.drawText(5, 62, text, FONT_MINI)      
   -- end

   if emFlag then
      text=string.format("%d/%d %d%%", #xPHist, variables.histMax, metrics.currMaxCPU)
      lcd.drawText(5, 74, text, FONT_MINI)   
   end
   
   if emFlag then
      text=string.format("LA %02d%% LM %02d%% L %d%%",
			 metrics.loopCPUAvg, metrics.loopCPUMax, metrics.loopCPU)
      lcd.drawText(5, 86, text, FONT_MINI)      
   end

   if emFlag then
      text=string.format("Loop: %.2f Mem: %.1f", metrics.loopTimeAvg or 0, metrics.memory or 0)
      lcd.drawText(190, 0, text, FONT_MINI)      
   end

   -- if currentGPSread and lastGPSread then
   --    text = string.format("GPS dt %d", currentGPSread - lastGPSread)
   --    lcd.drawText(280-lcd.getTextWidth(FONT_MINI, text) / 2, 140, text, FONT_MINI)
   -- end

   --text = string.format("%.6f %.6f", lat0 or 0, lng0 or 0)
   --lcd.drawText(60-lcd.getTextWidth(FONT_MINI, text) / 2, 90, text, FONT_MINI)

   --text = string.format("%d %d", xtable[#xtable] or 0, ytable[#ytable] or 0)
   --lcd.drawText(200, 10, text, FONT_MINI)

   --text = string.format("%d %d %d %d", map.Xmin, map.Xmax, map.Ymin, map.Ymax)
   --lcd.drawText(200, 25, text, FONT_MINI)
   
   --text=string.format("NNP %d", countNoNewPos)
   --lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 76, text, FONT_MINI)

   if pointSwitch then
      swp = system.getInputsVal(pointSwitch)
   end

   if not pointSwitch or (swp and swp == 1) then

      --check if we need to panic .. xPHist got too big while we were off screen
      --and we are about to get killed
      
      if panic then
	 offset = #xPHist - 100 -- only draw last 200 points .. should be safe
	 if offset < 0 then -- should not happen .. if so dump and start over
	    print(appInfo.Name .. ": dumped history")
	    xPHist={}
	    yPHist={}
	    latHist={}
	    lngHist={}
	    rgbHist={}
	 end
      else
	 offset = 0
      end

      if #rgbHist == 0 then
	 --print("#0")
	 return
      end
      
      rgb.last = -1 --rgbHist[1+(offset or 0)].rgb

      local kk

      -- only paint as many points as have been re-calculated if we are redoing the pixels
      -- because of a recent zoom change
      
      --AA--ren:reset()
      --AA--for i=1 + offset, (recalcPixels and recalcCount or #xPHist) do

      local ii = variables.ribbonColorSource
      
      for i=2 + offset, (recalcPixels and recalcCount or #xPHist) do
	 kk = i
	 --AA--ren:addPoint(xPHist[i], yPHist[i])
	 ----[[
	 if ii ~= 1 then
	    if (rgb.last ~= rgbHist[i].rgb) then
	       lcd.setColor(rgbHist[i].r, rgbHist[i].g, rgbHist[i].b)
	       rgb.last = rgbHist[i].rgb
	    end
	 else -- solid/monochrome ribbon
	    lcd.setColor(140,140,80)
	 end
	 
	 --]]
	 lcd.drawLine(xPHist[i-1], yPHist[i-1], xPHist[i], yPHist[i])
	 if i & 0X7F == 0 then -- fast mod 128 (127 = 0X7F)
	    if system.getCPU() >= variables.maxCPU then
	       print(appInfo.Name .. ": CPU panic", #xPHist, system.getCPU(), variables.maxCPU)
	       panic = true
	       break
	    end
	    --AA--ren:renderPolyline(variables.ribbonWidth,variables.ribbonAlpha/10.0) 
	    if i ~= (recalcPixels and recalcCount or #xPHist) then
	       --AA--ren:reset()
	       --AA--ren:addPoint(xPHist[i], yPHist[i])
	    end
	 end
      end
      
      if variables.histMax > 0 and #xPHist > 0 and #xtable > 0 and kk then
	 --AA--ren:addPoint( toXPixel(xtable[#xtable], map.Xmin, map.Xrange, windowWidth),
		 --AA--      toYPixel(ytable[#ytable], map.Ymin, map.Yrange, windowHeight))
	 lcd.drawLine(xPHist[kk], yPHist[kk],
		      toXPixel(xtable[#xtable], map.Xmin, map.Xrange, windowWidth),
		      toYPixel(ytable[#ytable], map.Ymin, map.Yrange, windowHeight))		      
      end
      setColorMain()
      --AA--ren:renderPolyline(variables.ribbonWidth,variables.ribbonAlpha/10.0)
      ------------------------------
   end

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

      -- this section for debugging enclosing box and circle for polygons
      --[[
	 for i = 1, #nfp, 1 do
	    --print(i, nfp[i].xmin, nfp[i].xmax, nfp[i].ymin, nfp[i].ymax)
	    ren:reset()
	    if nfp[i].inside then
	       setColorNoFlyInside()
	    else
	       setColorNoFlyOutside()
	    end
	    ren:addPoint(toXPixel(nfp[i].xmin, map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].ymin, map.Ymin, map.Yrange, windowHeight))
	    ren:addPoint(toXPixel(nfp[i].xmin, map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].ymax, map.Ymin, map.Yrange, windowHeight))
	    ren:addPoint(toXPixel(nfp[i].xmax, map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].ymax, map.Ymin, map.Yrange, windowHeight))
	    ren:addPoint(toXPixel(nfp[i].xmax, map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].ymin, map.Ymin, map.Yrange, windowHeight))
	    ren:addPoint(toXPixel(nfp[i].xmin, map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].ymin, map.Ymin, map.Yrange, windowHeight))	    	    

	    -- for j = 1, #nfp[i].path+1, 1 do
	    --    ren:addPoint(toXPixel(nfp[i].path[j % (#nfp[i].path) + 1].x,
	    -- 			     map.Xmin, map.Xrange, windowWidth),
	    -- 		    toYPixel(nfp[i].path[j % (#nfp[i].path) + 1].y,
	    -- 			     map.Ymin, map.Yrange, windowHeight))
	       
	    -- end
	    ren:renderPolyline(2,0.3)

	    lcd.drawCircle(toXPixel(nfp[i].xc, map.Xmin, map.Xrange, windowWidth),
			   toYPixel(nfp[i].yc, map.Ymin, map.Yrange, windowHeight), 
			   nfp[i].r * windowWidth/map.Xrange)
	 end
	 --]]

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

   --for i=1, #xtable do -- if no xy data #table is 0 so loop won't execute

   if #xtable > 0 then

      setColorMain()

      if variables.histMax == 0 then
	 drawBezier(windowWidth, windowHeight, 0)
      end
      

      setColorMain()
      
      -- defensive moves for squashing the indexing nil variable that Harry saw
      -- had to do with getting here (points in xtable) but no field selected
      -- checks in Field being nil should take care of that
      
      if checkNoFly(xtable[#xtable], ytable[#ytable], false, false) then
	 setColorNoFlyInside()
      else
	 setColorMap()
      end
      
      drawShape(toXPixel(xtable[#xtable], map.Xmin, map.Xrange, windowWidth),
		toYPixel(ytable[#xtable], map.Ymin, map.Yrange, windowHeight) + 0,
		shapes.T38, math.rad(heading))
      
      if variables.futureMillis > 0 then
	 setColorMap()
	 if checkNoFly(xtable[#xtable], ytable[#xtable], true, false) then
	    setColorNoFlyInside()
	 else
	    setColorMap()
	 end
	 -- only draw future if projected position more than 10m ahead (~10 mph for 2s)
	 if speed * variables.futureMillis > 10000 and xtable.xf and ytable.yf then
	    drawShape(toXPixel(xtable.xf, map.Xmin, map.Xrange, windowWidth),
		      toYPixel(ytable.yf, map.Ymin, map.Yrange, windowHeight) + 0,
		      shapes.delta, math.rad(heading))
	 end
      end      
   end

   metrics.currMaxCPU = system.getCPU()
   if metrics.currMaxCPU >= variables.maxCPU then
      variables.histMax = #xPHist -- no more points .. cpu nearing cutoff
   end
   
end


local function initField()

   local atField
   
   Field = {}
   
   if lng0 and lat0 then -- if location was detected by the GPS system
      
      for sname, _ in pairs(Fields) do

	 -- Use the highest mag image to determine if we are at this field
	 -- Russell is sorting the images from highest to lowest zoom
	 -- using the meters_per_pixel value so I can remove my sort
	 
	 --table.sort(Field.images, function(a,b) return a.meters_per_pixel < b.meters_per_pixel end)

	 atField = (math.abs(lat0 - Fields[sname].images[1].center.lat) < 1/60) and
	    (math.abs(lng0 - Fields[sname].images[1].center.lng) < 1/60) 

	 if (atField) then 

	    setField(sname)
	    -- see if file <model name>_icon.jsn exists
	    -- if so try to read airplane icon

	    local fg = io.readall("Apps/"..appInfo.Maps .."/JSON/"..
				     string.gsub(system.getProperty("Model")..
						    "_icon.jsn", " ", "_"))
	    if fg then
	       shapes.T38 = json.decode(fg).icon
	    end
	    break
	 end
      end
   end

   if Field and Field.name then
      system.messageBox("Current location: " .. Field.name, 2)
      activeField = Field.shortname
      --print("activeField:", activeField)

      maxImage = #Field.images
      --print("maxImage:", maxImage)
      if maxImage ~= 0 then
	 currentImage = 1
	 graphInit(currentImage) -- re-init graph scales with images loaded
      end
   else
      system.messageBox("Current location: not a known field", 2)
      print("not a known field: lat0, lng0", lat0, lng0)
      gotInitPos = false -- reset and try again with next gps lat long
   end
end

------------------------------------------------------------
local function gradientIndex(val, min, max, bins)
   -- for a value val, maps to the gradient rgb index for val from min to max
   --print(val, math.floor(((bins - 1) * math.max(math.min((val - min) / (max-min),1),0) + 1) + 0.5))
   return math.floor(((bins - 1) * math.max(math.min((val - min) / (max-min),1),0) + 1) + 0.5)
end


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
   local sensor
   local goodlat, goodlng 
   local newpos
   local deltaPosTime = 100 -- min sample interval in ms
   local jj
   local swc = -2
   
   -- don't loop menu is up on screen
   if form.getActiveForm() then return end
   
   metrics.loopCount = metrics.loopCount + 1

   if metrics.loopCount & 31 == 1 then -- about every 750 msec
      calcTriRace()
   end

   if metrics.loopCount & 63 == 1 then -- about every 1.5 secs
      metrics.memory = collectgarbage("count")
      collectgarbage()
   end
   
   metrics.loopTime = system.getTimeCounter() - metrics.lastLoopTime
   metrics.lastLoopTime = system.getTimeCounter()
   metrics.loopTimeAvg = metrics.loopTimeAvg + (metrics.loopTime - metrics.loopTimeAvg)/100.0

   metrics.loopCPU = system.getCPU()
   if metrics.loopCPU > metrics.loopCPUMax then metrics.loopCPUMax = metrics.loopCPU end
   metrics.loopCPUAvg = metrics.loopCPUAvg + (metrics.loopCPU - metrics.loopCPUAvg) / 100.0

   if colorSwitch then
      swc = system.getInputsVal(colorSwitch)
   end

   if colorSwitch and (swc ~= lastswc) and swc == 1 then
      swcCount = swcCount + 1
   end
   lastswc = swc

   goodlat = false
   goodlng = false

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
      if sensor.unit == "ft" then
	 GPSAlt = sensor.value * 0.3048
      elseif sensor.unit == "km" then
	 GPSAlt = sensor.value * 1000.0	 
      elseif sensor.unit == "mi." then
	 GPSAlt = sensor.value * 1609.344
      elseif sensor.unit == "yd." then
	 GPSAlt = sensor.value * 0.9144
      else -- meters
	 GPSAlt = sensor.value
      end
   end
 
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
   
   -- relpacement code for Tri racing:
   if SpeedGPS ~= nil then speed = SpeedGPS end

   -- replacement code for Tri race
   if not GPSAlt then GPSAlt = 0 end
   
   if Field and Field.elevation and absAltGPS  then
      altitude = GPSAlt  - Field.elevation.elevation - variables.elev
   else
      altitude = GPSAlt - variables.elev
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
      --lastGPSread = currentGPSread
      currentGPSread = system.getTimeCounter()
   end
   
   -- set lng0, lat0, coslat0 in case not near a field
   -- initField will reset if we are

   if newpos and not gotInitPos then
      lng0 = longitude     
      lat0 = latitude      
      coslat0 = math.cos(math.rad(lat0)) 
      gotInitPos = true
      initField()
   end

   x = rE * (longitude - lng0) * coslat0 / rad
   y = rE * (latitude - lat0) / rad

   x, y = rotateXY(x, y, math.rad(variables.rotationAngle))
   

   if (math.abs(x) > 10000.) or (math.abs(y) > 10000.) then
      print("bad point:", x,y,latitude, longitude)
      return
   end
   
   if newpos then -- only enter a new xy in the "comet tail" if lat/lon changed

      -- keep a max of variables.histMax points
      -- only record if moved variables.histDistance meters (Manhattan dist)

      -- keep hist of lat/lng too since images don't have same lat0 and lng0 we need to recompute
      -- x and y when the image changes. that is done in graphScale()

      if variables.histMax > 0 and
	 (system.getTimeCounter() - lastHistTime > variables.histSample) and
         (math.abs(x-xHistLast) + math.abs(y - yHistLast) > variables.histDistance) then 
	 if #xPHist+1 > variables.histMax then
	    table.remove(xPHist, 1)
	    table.remove(yPHist, 1)
	    table.remove(latHist, 1)
	    table.remove(lngHist, 1)
	    table.remove(rgbHist, 1)
	 end
	 table.insert(xPHist, toXPixel(x, map.Xmin, map.Xrange, 319))
	 table.insert(yPHist, toYPixel(y, map.Ymin, map.Yrange, 159))
	 xHistLast = x
	 yHistLast = y
	 table.insert(latHist, latitude)
	 table.insert(lngHist, longitude)
	 --
	 -- compute map from color params to rgb here
	 --local function gradientIndex(val, min, max, bins)

	 if variables.ribbonColorSource == 1 then -- none
	    jj = #shapes.gradient // 2 -- mid of gradient - right now this is sort of a yellow color
	 elseif variables.ribbonColorSource == 2 then -- altitude 0-500m
	    jj = gradientIndex(altitude, 0, 500, #shapes.gradient)
	 elseif variables.ribbonColorSource == 3 then -- speed 0-300 km/hr
	    jj = gradientIndex(speed, 0, 300, #shapes.gradient)
	 elseif variables.ribbonColorSource == 4 then -- triRace Laps
	    jj = gradientIndex(raceParam.lapsComplete % #shapes.gradient,
			       0, #shapes.gradient-1, #shapes.gradient)
	 elseif variables.ribbonColorSource == 5 then -- switch
	    jj = gradientIndex(swcCount % #shapes.gradient,
			       0, #shapes.gradient-1, #shapes.gradient)	    
	 elseif variables.ribbonColorSource == 6 then -- Rx1 Q
	    jj = gradientIndex(system.getTxTelemetry().rx1Percent, 0, 100,  #shapes.gradient)
	 elseif variables.ribbonColorSource == 7 then -- Rx1 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[1],    0,   9,  #shapes.gradient)
	 elseif variables.ribbonColorSource == 8 then -- Rx1 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[2],    0,   9,  #shapes.gradient)
	 elseif variables.ribbonColorSource == 9 then -- Rx1 V
	    jj = gradientIndex(system.getTxTelemetry().rx1Voltage, 0,   8,  #shapes.gradient)	    
	 elseif variables.ribbonColorSource == 10 then -- Rx2 Q
	    jj = gradientIndex(system.getTxTelemetry().rx2Percent, 0, 100,  #shapes.gradient)
	 elseif variables.ribbonColorSource == 11 then -- Rx2 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[3],    0,   9,  #shapes.gradient)
	 elseif variables.ribbonColorSource == 12 then -- Rx2 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[4],    0,   9,  #shapes.gradient)
	 elseif variables.ribbonColorSource == 13 then -- Rx2 V
	    jj = gradientIndex(system.getTxTelemetry().rx2Voltage, 0,   8,  #shapes.gradient)	    
	 else
	    print("ribbon color bad idx")
	 end

	 --jj = (#shapes.gradient - 1) * math.max(math.min ((altitude - 20) / (200-20),1),0) + 1
	 --jj = math.floor(jj+0.5)
	 --print(altitude, #latHist, jj)
	 --print("#", math.floor((#latHist/1)-1)%9 + 1)
	 --local jj = math.floor((#latHist/5)-1) % #shapes.gradient + 1

	 table.insert(rgbHist, {r=rgb[jj].r,
				g=rgb[jj].g,
				b=rgb[jj].b,
				rgb = rgb[jj].r*256*256 + rgb[jj].g*256 + rgb[jj].b})
	 --print("#latHist, r,g,b:", #latHist, rgbHist[#latHist].r,
	   --    rgbHist[#latHist].g,rgbHist[#latHist].b)
		      
	 lastHistTime = system.getTimeCounter()
      end

      if #xtable+1 > MAXTABLE then
	 table.remove(xtable, 1)
	 table.remove(ytable, 1)
      end
      
      table.insert(xtable, x)
      table.insert(ytable, y)

      xtable.xf = xtable[#xtable] - speed * (variables.futureMillis / 1000.0) *
	 math.cos(math.rad(270-heading))
      ytable.yf = ytable[#xtable] - speed * (variables.futureMillis / 1000.0) *
	 math.sin(math.rad(270-heading))
      
      if #xtable == 1 then
	 --print("resetting path", path.xmin, path.xmax, path.ymin, path.ymax)
	 path.xmin = map.Xmin
	 path.xmax = map.Xmax
	 path.ymin = map.Ymin
	 path.ymax = map.Ymax
	 --print("reset path", path.xmin, path.xmax, path.ymin, path.ymax)
      end

      --move this to mapPrint
      --graphScale(x, y)
      
      checkNoFly(x, y, false, true)
      if variables.futureMillis > 0 then
	 checkNoFly(x, y, true,  true)
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

   if variables.histMax == 0 then
      computeBezier(MAXTABLE+3)
   end
   
   if hasCourseGPS and courseGPS then
      heading = courseGPS
   else
      if compcrsDeg then
	 heading = compcrsDeg
      else
	 heading = 0
      end
   end
end

local function init()

   --local emptySw = system.getSwitchInfo(system.createSwitch("??", ""))
   local fg = io.readall(appInfo.Dir.."JSON/Shapes.jsn")

   if fg then
      shapes = json.decode(fg)
   else
      print(appInfo.Name .. ": Could not open "..appInfo.Dir.."JSON/Shapes.jsn")
   end

   --A nice 9-point and 10-point RGB gradient that looks good on top of the map
   --From: https://learnui.design/tools/gradient-generator.html
   
   --#ff4d00, #ff6b00, #ffb900, #d7ff01, #5aff01, #02ff27, #03ff95, #03ffe2, #03ffff);
   --#ff4d00, #ff6500, #ffa400, #ffff01, #93ff01, #21ff02, #02ff4e, #03ffa9, #03ffe8, #03ffff);
      
   for k,v in ipairs(shapes.gradient) do
      rgb[k] = {}
      rgb[k].r, rgb[k].g, rgb[k].b =  string.match(v, ("(%w%w)(%w%w)(%w%w)"))
      rgb[k].r = (tonumber(rgb[k].r, 16) or 0)
      rgb[k].g = (tonumber(rgb[k].g, 16) or 0)
      rgb[k].b = (tonumber(rgb[k].b, 16) or 0)       
      --print(k, rgb[k].r, rgb[k].g, rgb[k].b)
   end
   
   dotImage.blue = lcd.loadImage(appInfo.Dir.."/JSON/small_blue_circle.png")
   dotImage.green = lcd.loadImage(appInfo.Dir.."/JSON/small_green_circle.png")   
   dotImage.red = lcd.loadImage(appInfo.Dir.."/JSON/small_red_circle.png")

   setColorMain()  -- if a map is present it will change color scheme later
   
   graphInit(currentImage)  -- ok that currentImage is not yet defined

   for i, j in ipairs(telem) do
      telem[j].Se   = system.pLoad("telem."..telem[i]..".Se", 0)
      telem[j].SeId = system.pLoad("telem."..telem[i]..".SeId", 0)
      telem[j].SePa = system.pLoad("telem."..telem[i]..".SePa", 0)
   end
   
   variables = jLoadInit(jFilename())
   
   variables.rotationAngle     = jLoad(variables, "rotationAngle",   0)
   variables.histSample        = jLoad(variables, "histSample",   1000)
   variables.histMax           = jLoad(variables, "histMax",         0)
   variables.maxCPU            = jLoad(variables, "maxCPU",         80)
   variables.triLength         = jLoad(variables, "triLength",     250)
   variables.maxSpeed          = jLoad(variables, "maxSpeed",      100)
   variables.maxAlt            = jLoad(variables, "maxAlt",        200)
   variables.elev              = jLoad(variables, "elev",            0)
   variables.histDistance      = jLoad(variables, "histDistance",    3)
   variables.raceTime          = jLoad(variables, "raceTime",       30)
   variables.aimoff            = jLoad(variables, "aimoff",         20)
   variables.flightStartSpd    = jLoad(variables, "flightStartSpd", 20)
   variables.flightStartAlt    = jLoad(variables, "flightStartAlt", 20)
   variables.futureMillis      = jLoad(variables, "futureMillis", 2000)
   variables.triRotation       = jLoad(variables, "triRotation",     0)
   variables.triOffsetX        = jLoad(variables, "triOffsetX",      0)
   variables.triOffsetY        = jLoad(variables, "triOffsetY",      0)
   variables.ribbonWidth       = jLoad(variables, "ribbonWidth",     1)
   variables.ribbonAlpha       = jLoad(variables, "ribbonAlpha",     5)
   variables.switchesSet       = jLoad(variables, "switchesSet")
   variables.annText           = jLoad(variables, "annText", "c-d----")   
   variables.preText           = jLoad(variables, "preText", "s-a----")      
   variables.ribbonColorSource = jLoad(variables, "ribbonColorSource", 1)

   checkBox.triEnabled = jLoad(variables, "triEnabled", false)
   checkBox.noflyEnabled = jLoad(variables, "noflyEnabled", true)
   variables.noflyEnabled = checkBox.noflyEnabled
   checkBox.noFlyWarningEnabled = jLoad(variables, "noFlyWarningEnabled", true)   
   checkBox.noFlyShakeEnabled = jLoad(variables, "noFlyShakeEnabled", true)   

   pointSwitch = system.pLoad("pointSwitch")
   print("pLoad .. pointSwitch", pointSwitch)
   
   triASwitch  = system.pLoad("triASwitch")
   print("pLoad .. triASwitch", triASwitch)
   
   startSwitch = system.pLoad("startSwitch")
   print("pLoad .. startSwitch", startSwitch)

   colorSwitch = system.pLoad("colorSwitch")
   print("pLoad .. colorSwitch", colorSwitch)
   
   if variables.switchesSet and not pointSwitch and not triASwitch and not startSwitch then
      system.messageBox("Please reset switches in menu")
      print("please reset switches")
      variables.switchesSet = nil
   end
   
   system.registerForm(1, MENU_APPS, appInfo.menuTitle, initForm, keyForm, prtForm)
   system.registerTelemetry(1, appInfo.Name.." Overhead View", 4, mapPrint)
   system.registerTelemetry(2, appInfo.Name.." Flight Director", 4, dirPrint)   
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   arcFile = lcd.loadImage(appInfo.Dir .. "JSON/c-000.png")

   local fp, fn

   if not emFlag then fn = "/" .. appInfo.Fields else fn = appInfo.Fields end

   fp = io.readall(fn)

   if fp then
      Fields = json.decode(fp)
      if not Fields then
   	 print(appInfo.Name .. ": Failed to decode " .. fn)
   	 return
      end
   else
      print(appInfo.Name .. ": Cannot open ", fn)
      return
   end

   -- for k,v in pairs(system.getTxTelemetry()) do
   --    print(k,v)
   -- end

   readSensors()

   metrics.loopCount = 0
   metrics.lastLoopTime = system.getTimeCounter()
   metrics.loopTimeAvg = 0
end

return {init=init, loop=loop, author="DFM", version="7.11", name=appInfo.Name, destroy=destroy}
