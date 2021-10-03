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

   -- vary # steps on color gradient
   -- telemetry values on ribbon color
   -- imperial units?

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
local lastHeading = 0
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

--[[
local telem={"Latitude", "Longitude",   "Altitude",  "SpeedNonGPS",
	     "SpeedGPS", "DistanceGPS", "CourseGPS", "BaroAlt"}
--]]
local telem={"Latitude", "Longitude",   "Altitude", "SpeedGPS"}
telem.Latitude={}
telem.Longitude={}
telem.Altitude={}
telem.SpeedGPS={}
--telem.SpeedNonGPS={}
--telem.DistanceGPS={}
--telem.CourseGPS={}
--telem.BaroAlt={}

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
local recalcPixels = false
local recalcCount = 0

local metrics={}
metrics.currMaxCPU = 0
metrics.loopCPU = 0
metrics.loopCPUMax = 0
metrics.loopCPUAvg = 0

local gotInitPos = false
local annTextSeq = 1
local preTextSeq = 1
--local titleText
--local subtitleText
local lastgetTime = 0
local inZone = {}
local currentRibbonValue
local currentRibbonBin

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
local checkBoxSubform = {}

--local triEnabled
--local triEnabledIndex
--local noflyEnabled
--local noflyEnabledIndex
--local noFlyWarnEnabled
--local noFlyWarnIndex

local switchItems = {}
--local pointSwitch
--local zoomSwitch
--local triASwitch
--local startSwitch
--local colorSwitch
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
	  "Rx2 Q", "Rx2 A1", "Rx2 A2", "Rx2 Volts",
	  "P4", "Distance", "Radial"}	 

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

local satCountID = 0
local satCountPa = 0
local satCount

local satQualityID = 0
local satQualityPa = 0
local satQuality


local function createSw(name, dir)
   local activeOn = {1, 0, -1}
   if not name or not activeOn[dir] then
      return nil
   else
      return system.createSwitch(name, "S", (shapes.switchDirs[name] or 1) * activeOn[dir])
   end
end

local function gradientIndex(inval, min, max, bins, mod)
   -- for a value val, maps to the gradient rgb index for val from min to max
   local bin, val
   currentRibbonValue  = inval
   if mod then val = (inval-1) % mod + 1 else val = inval end
   bin = math.floor(((bins - 1) * math.max(math.min((val - min) / (max-min),1),0) + 1) + 0.5)   
   currentRibbonBin = bin
   return bin
end

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

	 -- if it's not a label, and it's a sensor see we have in the auto-assign table...
	 
	 if sensor.param ~= 0 and
	    paramGPS and
	    paramGPS[sensor.sensorName] and
	    paramGPS[sensor.sensorName][sensor.label]
	 then

	    param = paramGPS[sensor.sensorName][sensor.label].param
	    label  = paramGPS[sensor.sensorName][sensor.label].telem
	    --print("sensorName, param, label:", sensor.sensorName, param, label)
	    
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
	       elseif telem[label] then -- check if this is one we want
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
   if Field and Field.imageWidth then
      return -0.50 * Field.imageWidth[iM]
   else
      return -150 -- 17 mag image is about 300m wide
   end
   
end

local function xmaxImg(iM)
   if Field and Field.imageWidth then
      return 0.50 * Field.imageWidth[iM]
   else
      return 150
   end
end

local function yminImg(iM)
   if form.getActiveForm() then
      if Field and Field.imageWidth then
	 return -0.50 * Field.imageWidth[iM] / 1.8 -- 1.8 empirically determined
      else
	 return -75
      end
   else
      if Field.imageWidth then
	 return -0.50 * Field.imageWidth[iM] / 2.0
      else
	 return -75
      end
   end
end

local function ymaxImg(iM)
   if form.getActiveForm() then
      if Field and Field.imageWidth then
	 return 0.50 * Field.imageWidth[iM] / 1.8
      else
	 return 75
      end
   else
      if Field and Field.imageWidth then
	 return 0.50 * Field.imageWidth[iM] / 2.0
      else
	 return 75
      end
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

local function ll2xy(lat, lng, lat00, lng00, csl00)
   local tx, ty
   local ln0, lt0, cl0
   if not lat00 then lt0 = lat0 else lt0 = lat00 end
   if not lng00 then ln0 = lng0 else ln0 = lng00 end
   if not csl00 then cl0 = coslat0 else cl0 = csl00 end
   
   tx, ty = rotateXY(rE*(lng-ln0)*cl0/rad,
		     rE*(lat-lt0)/rad,
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
   local rb,gb,bb = lcd.getBgColor()
   
   if fieldPNG[currentImage] then
      lcd.setColor(255,255,0)
   else
      lcd.setColor(255-rb,255-gb, 255-bb)
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

-- local function pointSwitchChanged(value)
--    pointSwitch = value
--    jSave(variables, "switchesSet", "true")
--    system.pSave("pointSwitch", pointSwitch)
-- end

-- local function colorSwitchChanged(value)
--    colorSwitch = value
--    jSave(variables, "switchesSet", "true")
--    system.pSave("colorSwitch", colorSwitch)
-- end

--local function zoomSwitchChanged(value)
--   zoomSwitch = value
--   jSave(variables, "switchesSet", "true")
--   --system.pSave("zoomSwitch", zoomSwitch)
--end


-- local function triASwitchChanged(value)
--    triASwitch = value
--    jSave(variables, "switchesSet", "true")
--    system.pSave("triASwitch", triASwitch)
-- end

--local function startSwitchChanged(value)
--   startSwitch = value
--   jSave(variables, "switchesSet", "true")
--   system.pSave("startSwitch", startSwitch)
--end

local function checkBoxClicked(value, box)
   checkBox[box] = not value
   jSave(variables, box, not value)
   form.setValue(checkBoxIndex[box], checkBox[box])
end

local function switchNameChanged(value, name, swname)

   if name and shapes.switchNames[value] == "..." then
      jSave(variables, swname.."SwitchName", value)
      jSave(variables, swname.."SwitchDir", value)
      switchItems[swname] = nil
      checkBox[swname.."Switch"] = false
      return
   end

   if name then
      jSave(variables, swname .. "SwitchName", value)
   else
      jSave(variables, swname .. "SwitchDir", value)
   end
   --print("sNC: value, name, swname", value, name, swname)
	 
   switchItems[swname] = createSw(shapes.switchNames[variables[swname .. "SwitchName"]],
		     variables[swname .."SwitchDir"])
   checkBox[swname .."Switch"] = system.getInputsVal(switchItems[swname]) == 1
end

-- local function triASwitchNameChanged(value, name)
--    if name then
--       jSave(variables, "triASwitchName", value)
--    else
--       jSave(variables, "triASwitchDir", value)
--    end
--    print("triAchg", value, name)
--    triASwitch = createSw(shapes.switchNames[variables.triASwitchName],
-- 			  variables.triASwitchDir)
--    checkBox.triASwitch = system.getInputsVal(triASwitch) == 1
-- end

-- local function startSwitchNameChanged(value, name)
--    if name then
--       jSave(variables, "startSwitchName", value)
--    else
--       jSave(variables, "startSwitchDir", value)
--    end
--    startSwitch = createSw(shapes.switchNames[variables.startSwitchName],
-- 			  variables.startSwitchDir)
--    checkBox.startSwitch = system.getInputsVal(startSwitch) == 1
-- end

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


--------------------------------------------------------------------------------

local function pngLoad(j)
   local pfn

   if not Field or not Field.images then
      print(appInfo.Name .. " pngLoad - Field or Field.images not defined")
      return
   end
   
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

local function initField(fn)

   local atField
   
   Field = {}

   matchFields = {}
   
   -- Use the highest mag image to determine if we are at this field
   -- Russell is sorting the images from highest to lowest zoom
   -- using the meters_per_pixel value    

   if lng0 and lat0 then -- if location was detected by the GPS system
      if fn then
	 setField(fn)
      else
	 for sname, _ in pairs(Fields) do
	    atField = (math.abs(lat0 - Fields[sname].images[1].center.lat) < 1/60) and
	       (math.abs(lng0 - Fields[sname].images[1].center.lng) < 1/60) 
	    if (atField) then 
	       table.insert(matchFields, sname)
	    end
	 end
      end
   end

   if #matchFields > 0 then
      table.sort(matchFields, function(a,b) return a<b end)  
   
      setField(matchFields[1])
      -- see if file <model_name>_icon.jsn exists
      -- if so try to read airplane icon
      
      local fg = io.readall("Apps/"..appInfo.Maps .."/JSON/"..
			       string.gsub(system.getProperty("Model")..
					      "_icon.jsn", " ", "_"))
      if fg then
	 shapes.T38 = json.decode(fg).icon
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
      --system.messageBox("Current location: not a known field", 2)
      --print("not a known field: lat0, lng0", lat0, lng0)
      gotInitPos = false -- reset and try again with next gps lat long
   end
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
	 --print("key2, savedSubform", savedSubform)
	 if savedSubform == 7 then
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
	    form.reinit(7)
	 else
	    print("resetting Field: ", browse.OriginalFieldName)
	    if not browse.OriginalFieldName then
	       Field = {}
	    else
	       Field = browse.OriginalFieldName
	       setField(Field)
	       activeField = Field.shortname
	       maxImage = #Field.images	       
	    end
	    rwy = {}
	    nfc = {}
	    nfp = {}
	    tri = {}
	    currentImage = nil
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

local function selectFieldClicked(value)
   --print("sFC", value, browse.List[value])
   --print(Fields[browse.List[value]].shortname)
   lat0 = Fields[browse.List[value]].images[1].center.lat
   lng0 = Fields[browse.List[value]].images[1].center.lng
   coslat0 = math.cos(math.rad(lat0))
   gotInitPos = true
   initField(Fields[browse.List[value]].shortname)
end

local function switchAdd(lbl, swname, sf)
   form.addRow(5)
   form.addLabel({label=lbl, width=80})
   form.addSelectbox(shapes.switchNames, variables[swname .. "SwitchName"], true,
		     (function(z) return switchNameChanged(z, true, swname) end),
		     {width=60})
   form.addLabel({label="Up/Mid/Dn", width=94})
   form.addSelectbox({"U","M","D"}, variables[swname .. "SwitchDir"], true,
      (function(z) return switchNameChanged(z, false, swname) end), {width=50})
   checkBoxIndex[swname .."Switch"] = form.addCheckbox(checkBox[swname.."Switch"],
						       nil, {width=15})
   checkBoxSubform[swname] = sf
end

-- Draw the main form (Application inteface)

local function initForm(subform)

   if tonumber(system.getVersion()) < 5.0 then
      form.addRow(1)
      form.addLabel({label="Minimum TX Version is 5.0", width=220, font=FONT_NORMAL})
      return
   end
   
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
	 {label = "Flight History  >>"})

      form.addLink((function() form.reinit(6) end),
	 {label = "Settings >>"})            

      form.addLink((function() form.reinit(7) end),
	 {label = "Map Browser >>"})

      form.addLink((function() form.reinit(12) end),
	 {label = "Manual Field Selection >>"})      

      

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
	 --DistanceGPS="Select GPS Distance Sensor",
	 --CourseGPS="Select GPS Course Sensor",
	 
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

      switchAdd("Start", "start", subform)

      switchAdd("Announce", "triA", subform)
      
      -- form.addRow(5)
      -- form.addLabel({label="Start", width=80})
      -- form.addSelectbox(shapes.switchNames, variables.startSwitchName, true,
      -- 			(function(z) return startSwitchNameChanged(z, true) end),
      -- 			{width=60})
      -- form.addLabel({label="Up/Mid/Dn", width=94})
      -- form.addSelectbox({"U","M","D"}, variables.startSwitchDir, true,
      -- 	 (function(z) return startSwitchNameChanged(z,false) end), {width=50})
      -- checkBoxIndex.startSwitch = form.addCheckbox(checkBox.startSwitch, nil, {width=15})
      
      form.addRow(2)
      form.addLabel({label="Race time (mins)", width=220})
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


      
      -- form.addRow(5)
      -- form.addLabel({label="Announce", width=80})
      -- form.addSelectbox(shapes.switchNames, variables.triASwitchName, true,
      -- 			(function(z) return triASwitchNameChanged(z, true) end),
      -- 			{width=60})
      -- form.addLabel({label="Up/Mid/Dn", width=94})
      -- form.addSelectbox({"U","M","D"}, variables.triASwitchDir, true,
      -- 	 (function(z) return triASwitchNameChanged(z,false) end), {width=50})
      -- checkBoxIndex.triASwitch = form.addCheckbox(checkBox.triASwitch, nil, {width=15})

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
      
      switchAdd("Points", "point", subform)

      -- form.addRow(2)
      -- form.addLabel({label="Flight path points on/off sw", width=220})
      -- form.addInputbox(pointSwitch, false, pointSwitchChanged)

      ---[[
      form.addRow(2)
      form.addLabel({label="Ribbon Color Source", width=220})
      form.addSelectbox(
	 colorSelect,
	 variables.ribbonColorSource, true,
	 (function(z) return variableChanged(z, "ribbonColorSource") end) )
      --]]
      --[[
      local imax=300
      form.addRow(4)
      form.addLabel({label="Ribbon Color", width=100})
      form.addSelectbox(
	 colorSelect,
	 variables.ribbonColorSource, true,
	 (function(z) return variableChanged(z, "ribbonColorSource") end), {width=80} )
      form.addLabel({label="Max", width=70})
      form.addIntbox(imax, 0, 600, 300, 0, 1, nil, {width=60})
      --]]

      switchAdd("Color", "color", subform)
      -- form.addRow(2)
      -- form.addLabel({label="Ribbon Color Increment sw", width=220})
      -- form.addInputbox(colorSwitch, false, colorSwitchChanged)

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
      
      form.addRow(2)
      form.addLabel({label="Map Alpha", width=220})
      form.addIntbox(variables.mapAlpha, 0, 255, 255, 0, 1, 
		     (function(xx) return variableChanged(xx, "mapAlpha") end) )
      
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
   elseif subform == 12 then

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

      form.addRow(2)
      form.addLabel({label="Select Field"})
      form.addSelectbox(browse.List, browse.Idx, true, selectFieldClicked)
      
      form.addLink((function() form.reinit(1) end),
	 {label = "<<< Back to main menu",font=FONT_BOLD})
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
    

    --tt = math.deg(math.atan(sxy,sx2))

    --theta = math.atan(slope)
    theta = math.atan(sxy,sx2)
    if xx[1] < xx[#xx] then
       tt = math.pi/2 - theta
    else
       tt = math.pi*3/2 - theta
    end
    --print(math.deg(tt), math.deg(math.atan(slope)), math.deg(math.atan(sxy,sx2)))
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

--[[
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
--]]


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
      lcd.setColor(255,20,147)
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
   if raceParam.titleText then
      lcd.drawText((320 - lcd.getTextWidth(FONT_BOLD, raceParam.titleText))/2, 0,
	 raceParam.titleText, FONT_BOLD)
   end
   
   if raceParam.subtitleText then
      lcd.drawText((320 - lcd.getTextWidth(FONT_MINI, raceParam.subtitleText))/2, 17,
	 raceParam.subtitleText, FONT_MINI)
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
      if switchItems.start  then lcd.drawImage(25, 100, dotImage.red) end
   end
   
   lcd.drawText(5, 120, "Alt: ".. math.floor(altitude), FONT_MINI)
   lcd.drawText(5, 130, "Spd: "..math.floor(speed), FONT_MINI)
   --lcd.drawText(5, 140, string.format("Map Width %d m", map.Xrange), FONT_MINI)
   
   --lcd.drawText(265, 35, string.format("NxtP %d (%d)", region[code], code), FONT_MINI)
   --lcd.drawText(265, 45, string.format("Dist %.0f", distance), FONT_MINI)
   --lcd.drawText(265, 55, string.format("Hdg  %.1f", heading), FONT_MINI)
   --lcd.drawText(265, 65, string.format("TCrs %.1f", vd), FONT_MINI)
   --lcd.drawText(265, 75, string.format("RelB %.1f", relBearing), FONT_MINI)
   --if speed ~= 0 then
   --   lcd.drawText(265, 85, string.format("Time %.1f", distance / speed), FONT_MINI)
   --end
   local ll
   --sChar = variables.annText:sub(annTextSeq,annTextSeq)
   local swa
   if switchItems.triA then
      swa = system.getInputsVal(switchItems.triA)
   end
   if swa and swa == 1 then
      if raceParam.racing then
	 ll=lcd.getTextWidth(FONT_NORMAL, variables.annText)
	 lcd.drawText(310-ll, 130, variables.annText, FONT_NORMAL)
	 lcd.drawText(
	    310-ll - lcd.getTextWidth(FONT_MINI, "^")/2 +
	       lcd.getTextWidth(FONT_NORMAL, variables.annText:sub(1,annTextSeq)) -
	       lcd.getTextWidth(FONT_NORMAL, variables.annText:sub(annTextSeq, annTextSeq))/2, 
	    144, "^", FONT_MINI)      
      else
	 
	 ll=lcd.getTextWidth(FONT_NORMAL, variables.preText)
	 lcd.drawText(310-ll, 130, variables.preText, FONT_NORMAL)
	    lcd.drawText(
	       310-ll - lcd.getTextWidth(FONT_MINI, "^")/2 +
		  lcd.getTextWidth(FONT_NORMAL, variables.preText:sub(1,preTextSeq)) -
		  lcd.getTextWidth(FONT_NORMAL, variables.preText:sub(preTextSeq, preTextSeq))/2, 
	       144, "^", FONT_MINI)      
      end
   end
end

local function calcTriRace()

   local detS1
   local ao

   if not Field or not Field.name or not Field.triangle then return end
   if not variables.triEnabled then return end
   if #xtable == 0 or #ytable == 0 then return end
   
   --print(system.getTimeCounter() -lastgetTime)

   if Field then
      ao = variables.aimoff
   else
      ao = 0
   end
   -- XXX
   -- if no course computed yet, start by defining the pylons
   --print("#pylon, Field.name", #pylon, Field.name)
   if (#pylon < 3) and Field.name then -- need to confirm with RFM order of vertices
      triRot(ao) -- handle rotation and tranlation of triangle course 
      -- extend startline below hypotenuse of triangle  by 0.8x inside length
      --tri.center.x = tri.center.x + variables.triOffsetX
      --tri.center.y = tri.center.y + variables.triOffsetY
      pylon.start = {x=tri.center.x + variables.triOffsetX +
			0.8 * (tri.center.x + variables.triOffsetX- pylon[2].x),
		     y=tri.center.y + variables.triOffsetY +
			0.8 * (tri.center.y  + variables.triOffsetY - pylon[2].y)}
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
	 -- magic factor was 0.4 before modding for tele screen 2
	 zx, zy = rotateXY(-4.4 * variables.triLength, 4.4 * variables.triLength, rot[j])
	 pylon[j].zxl = zx + pylon[j].x
	 pylon[j].zyl = zy + pylon[j].y
	 zx, zy = rotateXY(4.4 * variables.triLength, 4.4 * variables.triLength, rot[j])
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
      detS1 =
	 (xtable[#xtable] - (tri.center.x + variables.triOffsetX)) *
	 (pylon.start.y   - (tri.center.y + variables.triOffsetY)) -
	 (ytable[#ytable] - (tri.center.y + variables.triOffsetY)) *
	 (pylon.start.x   - (tri.center.x + variables.triOffsetX))
   end
   

   local inStartZone
   if not detS1 then print("not detS1") end
   if detS1 and detS1 >= 0 then inStartZone = true else inStartZone = false end
   
   -- read the start switch
   
   local sws
   
   if switchItems.start then
      sws = system.getInputsVal(switchItems.start)
   end

   if switchItems.start and sws then
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
	    lapAltitude = altitude
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
      raceParam.titleText = string.format("%02d:%04.1f / ", tmin, tsec)
      
      
      tsec = (sgTC - raceParam.lapStartTime) / 1000.0
      tmin = tsec // 60
      tsec = tsec - tmin*60      
      raceParam.lapTimeText = string.format("%02d:%04.1f",  tmin, tsec)
      raceParam.titleText = raceParam.titleText ..raceParam.lapTimeText .. " / "

      tsec = raceParam.lastLapTime / 1000.0
      tmin = tsec // 60
      tsec = tsec - tmin*60
      raceParam.titleText = raceParam.titleText .. string.format("%02d:%04.1f / ", tmin, tsec)

      raceParam.titleText = raceParam.titleText .. string.format("%.1f / ", raceParam.avgSpeed)

      raceParam.titleText = raceParam.titleText .. string.format("%.1f", raceParam.lastLapSpeed)

      
      --lcd.drawText((310 - lcd.getTextWidth(FONT_BOLD, tstr))/2, 0,
      --tstr, FONT_BOLD)

      raceParam.subtitleText = string.format("Laps: %d, Net Score: %d, Penalty: %d",
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
   
   if switchItems.triA then
      swa = system.getInputsVal(switchItems.triA)
   end
   
   local sChar

   local now = system.getTimeCounter()

   -- instead of lastgetTime + 1000 we will empirically determine a number that allows for the
   -- inherent delays in the callback model to make a 1/sec step time
   
   if (now >= (lastgetTime + 850)) and swa and swa == 1 then -- once a sec
      --print(now-lastgetTime)
      lastgetTime = now
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

--[[
local function drawHeading()

   -- could speed optimize by putting this table in the jsn params table (shapes.jsn)
   
   local parmHeading = {
      {0, 2, "N"}, {30, 5}, {60, 5},
      {90, 2, "E"}, {120, 5}, {150, 5},
      {180, 2, "S"}, {210, 5}, {240, 5},
      {270, 2, "W"}, {300, 5}, {330, 5}
   }

   local dispHeading
   local text
   local dx=80
   local wrkHeading = 0
   local w
   local colHeading = 160
   local rowHeading = 30
   
   lcd.drawFilledRectangle(colHeading-70+dx, rowHeading, 140, 2)
   lcd.drawFilledRectangle(colHeading+65+dx, rowHeading-20, 6,22)
   lcd.drawFilledRectangle(colHeading-65-6+dx, rowHeading-20, 6,22)

   --dispHeading = (heading + variables.rotationAngle) % 360
   dispHeading = (heading) % 360

   for _, point in pairs(parmHeading) do
      wrkHeading = point[1] - dispHeading
      if wrkHeading > 180 then wrkHeading = wrkHeading - 360 end
      if wrkHeading < -180 then wrkHeading = wrkHeading + 360 end
      deltaX = math.floor(wrkHeading / 1.6 + 0.5) - 1 -- was 2.2
      
      if deltaX >= -64 and deltaX <= 62 then -- was 31
	 if point[3] then
	    lcd.drawText(colHeading + deltaX - 4+dx, rowHeading - 16, point[3], FONT_MINI)
	 end
	 if point[2] > 0 then
	    lcd.drawLine(colHeading + deltaX+dx, rowHeading - point[2],
			 colHeading + deltaX+dx, rowHeading)
	 end
      end
   end 

   text = string.format(" %03d",dispHeading)
   w = lcd.getTextWidth(FONT_NORMAL,text) 
   lcd.drawFilledRectangle(colHeading - w/2+dx, rowHeading-30, w, lcd.getTextHeight(FONT_MINI))
   lcd.setColor(255,255,255)
   lcd.drawText(colHeading - w/2+dx, rowHeading-30,text,  FONT_MINI)
   
   lcd.resetClipping()
end
--]]
--------------------------

--[[
local function drawTextCenter(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end
--]]
--[[
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
--]]

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

   for k,v in pairs(switchItems) do
      if checkBoxSubform[k] == savedSubform then
	 checkBox[k.."Switch"] = system.getInputsVal(switchItems[k]) == 1
	 --print(k, checkBoxIndex[k.."Switch"], checkBox[k.."Switch"])
	 form.setValue(checkBoxIndex[k.."Switch"], checkBox[k.."Switch"])
      end
   end

   if savedSubform == 11 then 
      for i = 1, #rgb, 1 do
	 lcd.setColor(rgb[i].r, rgb[i].g, rgb[i].b)
	 lcd.drawFilledRectangle(-25 + 30*i, 40, 25, 25)
	 lcd.setColor(0,0,0)
	 local text = tostring(i)
	 lcd.getTextWidth(FONT_NORMAL, text)
	 lcd.drawText(-12-0.5*lcd.getTextWidth(FONT_NORMAL, text)+30*i, 70, text)
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
	 --maybe should center this instead of fixed X position
	 lcd.drawText(70,145,(browse.dispText or ""), FONT_NORMAL)	 
	 --lcd.setClipping(0,15,310,160)

	 setColorRunway()
	 if #rwy == 4 then
	    ren:reset()
	    for j = 1, 5, 1 do
	       --if j == 1 then
	       --end
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

------------------------------------------------------------


--[[
enum Result {
    case circle(center: CGPoint, radius: CGFloat)
    case invalid
}

func circleTouching3Points(a: CGPoint, b: CGPoint, c: CGPoint) -> Result {
    let d1 = CGPoint(x: b.y - a.y, y: a.x - b.x)
    let d2 = CGPoint(x: c.y - a.y, y: a.x - c.x)
    let k: CGFloat = d2.x * d1.y - d2.y * d1.x
    guard k < -0.00001 || k > 0.00001 else {
        return Result.invalid
    }
    let s1 = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    let s2 = CGPoint(x: (a.x + c.x) / 2, y: (a.y + c.y) / 2)
    let l: CGFloat = d1.x * (s2.y - s1.y) - d1.y * (s2.x - s1.x)
    let m: CGFloat = l / k
    let center = CGPoint(x: s2.x + m * d2.x, y: s2.y + m * d2.y)
    let dx = center.x - a.x
    let dy = center.y - a.y
    let radius = sqrt(dx * dx + dy * dy)
    return Result.circle(center: center, radius: radius)
    }
--]]



------------------------------------------------------------
local function dirPrint()
   --local dx, dy, rx, ry
   local sC = variables.triLength * 3 -- scale factor for this tele window
   local xf = 0.40 -- center X is at 1-xf of width
   local yf = 0.65 -- center Y is at 1-yf of height
   local xmin, xmax=(-1+xf)*sC, xf*sC
   local xt = 320*(1-xf/2) -- X center of text location on rhs of screen
   local ymin, ymax=(-1+yf)*sC/2, yf*sC/2
   local xrange = xmax - xmin
   local yrange = ymax - ymin
   local ww = 320
   local wh = 160
   local ren=lcd.renderer()
   local hh

   if not xtable or not ytable then return end

   if not compcrs then
      lcd.drawText(40, 80, "Triangle View: No heading", FONT_BIG)
      return
   end
   
   lcd.setColor(0,0,255)
   
   --drawHeading()
   
   hh = heading - 180
   
   local xx, yy = xtable[#xtable], ytable[#ytable]
   
   
   local function ll2RX(ih)
      local xrr, yrr
      xrr, yrr = rE*(lngHist[ih]-lng0)*coslat0/rad, rE*(latHist[ih]-lat0)/rad
      xrr, yrr = rotateXY(xrr, yrr, math.rad(variables.rotationAngle))
      return xrr
   end

   local function ll2RY(ih)
      local xrr, yrr
      xrr, yrr = rE*(lngHist[ih]-lng0)*coslat0/rad, rE*(latHist[ih]-lat0)/rad
      xrr, yrr = rotateXY(xrr, yrr, math.rad(variables.rotationAngle))
      return yrr
   end   

   local function ll2RXr(lat, lng)
      local xrr, yrr
      xrr, yrr = rE*(lng-lng0)*coslat0/rad, rE*(lat-lat0)/rad
      xrr, yrr = rotateXY(xrr, yrr, math.rad(variables.rotationAngle))
      return xrr
   end

   local function ll2RYr(lat,lng)
      local xrr, yrr
      xrr, yrr = rE*(lng-lng0)*coslat0/rad, rE*(lat-lat0)/rad
      xrr, yrr = rotateXY(xrr, yrr, math.rad(variables.rotationAngle))
      return yrr
   end   

   --[[
   -- prior attempt .. code below works better
   local function circFit(j)
      local d1x = ll2RY(j-1) - ll2RY(j-2)
      local d1y = ll2RX(j-2) - ll2RX(j-1)
      local d2x = ll2RY(j) - ll2RY(j-2)
      local d2y = ll2RX(j-2) - ll2RX(j)
      local k = d2x * d1y - d2y*d1x
      -- if k < -0.00001 or k > 0.00001 then
      -- 	 return nil
      -- end
      local s1x = (ll2RX(j-2) + ll2RX(j-1)) / 2.0
      local s1y = (ll2RY(j-2) + ll2RY(j-1)) / 2.0
      local s2x = (ll2RX(j-2) + ll2RX(j)) / 2.0
      local s2y = (ll2RY(j-2) + ll2RY(j)) / 2.0
      local l = d1x * (s2y - s1y) - d1y * (s2x - s1x)
      local m = l/k
      local cx = s2x + m*d2x
      local cy = s2y + m*d2y
      local dx = cx - ll2RX(j-2)
      local dy = cy - ll2RY(j-2)
      local r  = math.sqrt(dx*dx + dy*dy)
      return cx, cy, r, k
   end
   --]]
   
   -- circFit2() tranlated from the swift file on:
   -- https://stackoverflow.com/questions/10407700/
   -- calculate-center-and-radius-of-circle-from-3-points-on-it
   --[[
   -- experiment to remove local vars and compute directly .. turns out this is much slower!
   -- 85% CPU vs. 70%
   local function circFit2(j)
      --local x1 = ll2RX(j-2)
      --local y1 = ll2RY(j-2)
      --local x2 = ll2RX(j-1)
      --local y2 = ll2RY(j-1)
      --local x3 = ll2RX(j)
      --local y3 = ll2RY(j)
      --local x3 = ll2RXr(latitude, longitude)
      --local y3 = ll2RYr(latitude, longitude)
      
      local A = ll2RX(j-2)*(ll2RY(j-1)-ll2RYr(latitude, longitude)) - ll2RY(j-2)*(ll2RX(j-1)-ll2RXr(latitude, longitude)) + ll2RX(j-1)*ll2RYr(latitude, longitude) - ll2RXr(latitude, longitude)*ll2RY(j-1)
      if math.abs(A) <= 1.0E-6 then
	 return nil
      end
      
      local B = (ll2RX(j-2)*ll2RX(j-2) + ll2RY(j-2)*ll2RY(j-2))*(ll2RYr(latitude, longitude)-ll2RY(j-1)) + (ll2RX(j-1)*ll2RX(j-1) + ll2RY(j-1)*ll2RY(j-1))*(ll2RY(j-2)-ll2RYr(latitude, longitude)) + (ll2RXr(latitude, longitude)*ll2RXr(latitude, longitude) + ll2RYr(latitude, longitude)*ll2RYr(latitude, longitude))*(ll2RY(j-1)-ll2RY(j-2))
      local C = (ll2RX(j-2)*ll2RX(j-2) + ll2RY(j-2)*ll2RY(j-2))*(ll2RX(j-1)-ll2RXr(latitude, longitude)) + (ll2RX(j-1)*ll2RX(j-1) + ll2RY(j-1)*ll2RY(j-1))*(ll2RXr(latitude, longitude)-ll2RX(j-2)) + (ll2RXr(latitude, longitude)*ll2RXr(latitude, longitude) + ll2RYr(latitude, longitude)*ll2RYr(latitude, longitude))*(ll2RX(j-2)-ll2RX(j-1))
      local D = (ll2RX(j-2)*ll2RX(j-2) + ll2RY(j-2)*ll2RY(j-2))*(ll2RXr(latitude, longitude)*ll2RY(j-1) - ll2RX(j-1)*ll2RYr(latitude, longitude)) + (ll2RX(j-1)*ll2RX(j-1) + ll2RY(j-1)*ll2RY(j-1))*(ll2RX(j-2)*ll2RYr(latitude, longitude) - ll2RXr(latitude, longitude)*ll2RY(j-2)) +
	 (ll2RXr(latitude, longitude)*ll2RXr(latitude, longitude) + ll2RYr(latitude, longitude)*ll2RYr(latitude, longitude))*(ll2RX(j-1)*ll2RY(j-2) -ll2RX(j-2)*ll2RY(j-1))

      local cx = -B / (2*A)
      local cy = -C / (2*A)
      local r = math.sqrt( (B*B + C*C - 4*A*D)/ (4*A*A) )
      return cx, cy, r, A
   end
   --]]
   
   ---[[
   local function circFit2(k)
      -- tradeoff to use jth point .. closer to real time but noisier when still
      -- very close to current point
      if true then --latHist[k] == latitude and lngHist[k] == lngHist[k] then
	 j=k-1
      else
	 j=k
      end
      local x1 = ll2RX(j-1)
      local x12 = x1*x1
      local y1 = ll2RY(j-1)
      local y12 = y1*y1
      local x2 = ll2RX(j)
      local x22 = x2*x2
      local y2 = ll2RY(j)
      local y22 = y2*y2
      --local x3 = ll2RX(j)
      --local y3 = ll2RY(j)
      local x3 = ll2RXr(latitude, longitude)
      local y3 = ll2RYr(latitude, longitude)
      local x32 = x3*x3
      local y32 = y3*y3
      
      local A = x1*(y2-y3) - y1*(x2-x3) + x2*y3 - x3*y2
      if math.abs(A) <= 1.0E-6 then
	 return nil
      end
      
      local B = (x12 + y12)*(y3-y2) + (x22 + y22)*(y1-y3) + (x32 + y32)*(y2-y1)
      local C = (x12 + y12)*(x2-x3) + (x22 + y22)*(x3-x1) + (x32 + y32)*(x1-x2)
      local D = (x12 + y12)*(x3*y2 - x2*y3) + (x22 + y22)*(x1*y3 - x3*y1) +
	 (x32 + y32)*(x2*y1 -x1*y2)

      local cx = -B / (2*A)
      local cy = -C / (2*A)
      local r = math.sqrt( (B*B + C*C - 4*A*D)/ (4*A*A) )
      return cx, cy, r, A
   end
   --]]
   
   -- local function rapN(x, y)
   --    local rx, ry
   --    rx, ry = rotateXY(x, y, math.rad(hh))
   --    rx, ry = toXPixel(rx, xmin, xrange, ww), toYPixel(ry, ymin, yrange, wh)
   --    ren:addPoint(rx, ry)
   -- end
   
   local function rap(x,y,d)
      local dx = xx - x
      local dy = yy - y
      local rx, ry = rotateXY(dx, dy, math.rad(hh))
      rx, ry = toXPixel(rx, xmin, xrange, ww), toYPixel(ry, ymin, yrange, wh)
      ren:addPoint(rx, ry)
      if d then
	 lcd.drawCircle(rx, ry, d)
      end
   end

   lcd.setColor(0,0,0)

   lcd.drawText(20-lcd.getTextWidth(FONT_MINI, "N") / 2, 6+4, "N", FONT_MINI)
   drawShape(20, 12+4, shapes.arrow, math.rad(-heading+variables.rotationAngle - 90))
   lcd.drawCircle(20, 12+4, 7)

   
   ren:reset()

   if not pylon or not pylon[3] then return end
   
   ren:reset()

   -- draw the triangle
   
   for j = 1, #pylon + 1 do
      rap(pylon[m3(j)].x, pylon[m3(j)].y)
   end


   lcd.setColor(240,115,0)
   ren:renderPolyline(2, 0.7)

   --draw the startline
   
   if #pylon == 3 and pylon.start then
      ren:reset()
      rap(pylon[2].x, pylon[2].y)
      rap(pylon.start.x, pylon.start.y)
      lcd.setColor(0,0,255)
      ren:renderPolyline(2,0.7)
   end

   -- draw the line to the next aim point

   if raceParam.racing then
      lcd.setColor(250,177,216)
      ren:reset()
      rap(xx,yy)
      rap(pylon[m3(nextPylon)].xt, pylon[m3(nextPylon)].yt)
      ren:renderPolyline(2, 0.7)
   end

   -- draw the turning zones
   
   for j = 1, #pylon do
      ren:reset()
      rap(pylon[j].x, pylon[j].y)
      rap(pylon[j].zxl, pylon[j].zyl)
      rap(pylon[j].zxr, pylon[j].zyr)
      rap(pylon[j].x, pylon[j].y)
      lcd.setColor(240,115,0)
      local alpha
      if raceParam.racing and m3(nextPylon) == j then
	 alpha = 0.8
      else
	 alpha = 0.2
      end
      ren:renderPolygon(alpha)
   end

   ------------------------------------------------------------

   -- now draw the history/ribbon
   
   local swp
   
   if switchItems.point then
      swp = system.getInputsVal(switchItems.point)
   end

   if not metrics.headingCount then metrics.headingCount = 0 end

   if hh ~= lastHeading then
      --print("rep:", metrics.headingCount)
      metrics.headingCount = 0
      lastHeading = hh
   else
      metrics.headingCount = metrics.headingCount + 1
   end
   
   if ( (not switchItems.point) or (swp and swp == 1) ) and (#xPHist > 0) then
      rgb.last = -1 
      local kk
      local ii = variables.ribbonColorSource
      local xrr, yrr
      local iend = #xPHist
      local istart = math.max(iend-50+1, 1)
      ren:reset()
      for i=istart, iend do
	 kk = i
	 if ii ~= 1 then
	    if (rgb.last ~= rgbHist[i].rgb) then
	       ren:renderPolyline(variables.ribbonWidth*2, variables.ribbonAlpha * 0.7)
	       ren:reset()
	       if xrr and yrr then rap(xrr, yrr, 2) end
	       lcd.setColor(rgbHist[i].r, rgbHist[i].g, rgbHist[i].b)
	       rgb.last = rgbHist[i].rgb
	    end
	 else -- solid/monochrome ribbon
	    lcd.setColor(140,140,80)
	 end
	 xrr, yrr = ll2RX(i), ll2RY(i)
	 rap(xrr, yrr, 2)
      end
      rap(xx, yy, 2)
      ren:renderPolyline(variables.ribbonWidth*3, variables.ribbonAlpha * 0.7)
   end
   
   ------------------------------------------------------------
   
   -- draw the airplane icon
   
   lcd.setColor(0,0,255)
   
   drawShape(toXPixel(0, xmin, xrange, ww),
   	     toYPixel(0, ymin, yrange, wh),
   	     shapes.T38, 0)

   -- draw the projected flight path
   
   -- ren:reset()
   -- ren:addPoint(toXPixel(0, xmin, xrange, ww), toYPixel(sC/12, ymin, yrange, wh))
   -- ren:addPoint(toXPixel(0, xmin, xrange, ww), toYPixel(sC/3.5, ymin, yrange, wh))
   -- ren:renderPolyline(3,0.7)

   -- major optimization needed: only call circFit when new hist point available
   
   if #latHist >= 5 then
      local cx, cy, r, A = circFit2(#latHist)
      if cx then
	 local t1 = math.atan( (ll2RX(#latHist-1) - cx), (ll2RY(#latHist-1) - cy))
	 local t0 = math.atan( (ll2RX(#latHist) - cx), (ll2RY(#latHist) - cy))
	 local tn
	 if latitude and longitude then
	    tn = math.atan( (ll2RXr(latitude, longitude) - cx), (ll2RYr(latitude, longitude) - cy))
	 else
	    print("NO LAT/LONG")
	    tn = 0
	 end
	 
	 local dt = t0 - t1
	 if math.deg(dt) > 180 then dt = dt - 2*math.pi end

	 dt = math.max(math.min(dt, math.pi/12), -math.pi/12)

	 if r > (sC / 20) then
	    ren:reset()
	    for i=1,10,1 do
	       rap(cx + r * math.sin(tn + 2.5*(i-1)*(dt)/9),
		   cy + r * math.cos(tn + 2.5*(i-1)*(dt)/9))
	    end
	    ren:renderPolyline(3,0.7)
	 else
	    --print(r, k)
	 end
      else
	 print("circFit2 failed")
      end
   end
   
   -- draw the telemetry values
   
   local text
   lcd.setColor(0,0,255)
   text = string.format("%d", math.floor(raceParam.lapsComplete))
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 5, text, FONT_BIG)
   text = "Laps"
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 5+20, text, FONT_MINI)

   text = raceParam.lapTimeText or "00:00.0"
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 42, text, FONT_BIG)
   text = "Lap Time"
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 42+20, text, FONT_MINI)

   text = string.format("%d", math.floor(altitude + 0.5))
   if lapAltitude then
      text = text .. string.format(" / %d", math.floor(lapAltitude + 0.5))
   end
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 79, text, FONT_BIG)
   text = "Altitude"
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 79+20, text, FONT_MINI)
   
   text = string.format("%d", math.floor(speed + 0.5))
   --if raceParam.lastLapSpeed and raceParam.lastLapSpeed ~= 0 then
   --   text = text ..string.format(" / %d", math.floor(raceParam.lastLapSpeed + 0.5))
   --end
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 116, text, FONT_BIG)
   text = "Speed"
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 116+20, text, FONT_MINI)   

   lcd.drawText(6,125, string.format("CPU: %d%%", system.getCPU()), FONT_MINI)
   if variables.ribbonColorSource ~= 1 and currentRibbonValue then
      lcd.drawText(18, 140, string.format("%s: %.0f",
					 colorSelect[variables.ribbonColorSource],
					 currentRibbonValue), FONT_MINI)
      lcd.setColor(rgb[currentRibbonBin].r, rgb[currentRibbonBin].g, rgb[currentRibbonBin].b)
      lcd.drawFilledRectangle(6,143,8,8)
   end

end

--[[
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

   local txt = string.format("#xP %d", #xPHist)
   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, txt ) / 2,
		100, txt, FONT_MINI)
   
   txt = string.format("NNP %d", countNoNewPos)
   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, txt) / 2,
		110, txt, FONT_MINI)

   txt = string.format("(%d,%d)", x or 0, y or 0)
   lcd.drawText(70-lcd.getTextWidth(FONT_MINI, txt ) / 2,
		120, txt, FONT_MINI)

end
--]]

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

local panic = false

local function mapPrint(windowWidth, windowHeight)

   local swp
   local offset
   local ren=lcd.renderer()
   
   if form.getActiveForm() then return end
   
   if recalcDone() then
      graphScale(xtable[#xtable], ytable[#ytable])
   end
   
   setColorMap()
   
   setColorMain()

   if fieldPNG[currentImage] then
      if variables.mapAlpha < 255 then
	 lcd.setColor(75,75,75)
	 lcd.drawFilledRectangle(0,0,320,160)
      else
	 lcd.drawImage(0,0,fieldPNG[currentImage])
      end
   else
      lcd.drawText((320 - lcd.getTextWidth(FONT_BIG, "No GPS fix or no Image"))/2, 20,
	 "No GPS fix or no Image", FONT_BIG)
   end
   
   -- in case the draw functions left color set to their specific values
   setColorMain()

   --lcd.drawCircle(160, 80, 5) -- circle in center of screen
   
   lcd.drawText(20-lcd.getTextWidth(FONT_MINI, "N") / 2, 6, "N", FONT_MINI)
   drawShape(20, 12, shapes.arrow, math.rad(-1*variables.rotationAngle))
   lcd.drawCircle(20, 12, 7)
   
   --[[
   if satCount then
      text=string.format("%2d Sats", satCount)
      --lcd.drawText(35-lcd.getTextWidth(FONT_MINI, text) / 2, 50, text, FONT_MINI)
      lcd.drawText(5, 50, text, FONT_MINI)
   else
      --text = "No Sats"
      --lcd.drawText(35-lcd.getTextWidth(FONT_MINI, text) / 2, 50, text, FONT_MINI)
      --lcd.drawText(5, 50, text, FONT_MINI)      
   end
   --]]
   -- if satQuality then
   --    text=string.format("SatQ %.0f", satQuality)
   --    --lcd.drawText(35-lcd.getTextWidth(FONT_MINI, text) / 2, 62, text, FONT_MINI)
   --    lcd.drawText(5, 62, text, FONT_MINI)      
   -- end

   --if emFlag then
   --   text=string.format("%d/%d %d%%", #xPHist, variables.histMax, metrics.currMaxCPU)
   --   lcd.drawText(5, 74, text, FONT_MINI)   
   --end
   
   -- if emFlag then
   --    text=string.format("LA %02d%% LM %02d%% L %d%%",
   -- 			 metrics.loopCPUAvg, metrics.loopCPUMax, metrics.loopCPU)
   --    lcd.drawText(5, 86, text, FONT_MINI)      
   -- end

   --if true then --emFlag then
   --   text=string.format("%.1f", metrics.loopTimeAvg or 0)
      --text=string.format("Loop: %.2f Mem: %.1f", metrics.loopTimeAvg or 0, metrics.memory or 0)
   --   lcd.drawText(290, 145, text, FONT_MINI)      
   --end

   if variables.ribbonColorSource ~= 1 and currentRibbonValue then
      lcd.drawText(18, 140, string.format("%s: %.0f",
					 colorSelect[variables.ribbonColorSource],
					 currentRibbonValue), FONT_MINI)
      lcd.setColor(rgb[currentRibbonBin].r, rgb[currentRibbonBin].g, rgb[currentRibbonBin].b)
      lcd.drawFilledRectangle(6,143,8,8)
   end

   --text = string.format("%.6f %.6f", lat0 or 0, lng0 or 0)
   --lcd.drawText(60-lcd.getTextWidth(FONT_MINI, text) / 2, 90, text, FONT_MINI)

   --text = string.format("%d %d", xtable[#xtable] or 0, ytable[#ytable] or 0)
   --lcd.drawText(200, 10, text, FONT_MINI)

   --text = string.format("%d %d %d %d", map.Xmin, map.Xmax, map.Ymin, map.Ymax)
   --lcd.drawText(200, 25, text, FONT_MINI)
   
   --text=string.format("NNP %d", countNoNewPos)
   --lcd.drawText(30-lcd.getTextWidth(FONT_MINI, text) / 2, 76, text, FONT_MINI)

   if switchItems.point then
      swp = system.getInputsVal(switchItems.point)
   end
   
   if ( (not switchItems.point) or (swp and swp == 1) ) and (#xPHist > 0) then

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
	 print("#0")
	 return
      end
      
      rgb.last = -1 --rgbHist[1+(offset or 0)].rgb

      -- only paint as many points as have been re-calculated if we are redoing the pixels
      -- because of a recent zoom change
      
      --AA--ren:reset()
      --AA--for i=1 + offset, (recalcPixels and recalcCount or #xPHist) do

      local kk
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
	 --lcd.drawCircle(xPHist[i], yPHist[i], 2)
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

   
   setColorMap()
   
   if #rwy == 4 then
      ren:reset()
      for j = 1, 5, 1 do
	 ren:addPoint(toXPixel(rwy[j%4+1].x, map.Xmin, map.Xrange, windowWidth),
		      toYPixel(rwy[j%4+1].y, map.Ymin, map.Yrange, windowHeight))
      end
      ren:renderPolyline(2,0.7)
   end
   
   -- draw the polygon no fly zones if defined
   if checkBox.noflyEnabled then
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

   -- diagnostic only
   -- if pylon.start then
   --    lcd.drawCircle(toXPixel(pylon.start.x, map.Xmin, map.Xrange, 320),
   -- 		     toYPixel(pylon.start.y, map.Ymin, map.Yrange, 160), 10)
   --end
   
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

local function distDiag()
   local hw,hh
   if Field and Field.images and currentImage then
      hw = Field.images[#Field.images].meters_per_pixel * 160
      hh = hw / 2.0
      --print("distDiag:" ,math.sqrt(hw*hw + hh*hh))
      return math.sqrt(hw*hw + hh*hh)
   else
      return 2300.0
   end
end

local function distHome()
   local xy0, xy1
   local lat00, lng00, coslatM

   -- compute x,y coords from the center of the most zoomed in image (Fields.images[1])
   -- the compute distance from that point in the frame of the least zoomed in (largest) image
   
   if Field and Field.images and currentImage then
      lat00 = Field.images[1].center.lat
      lng00 = Field.images[1].center.lng
      latM =  Field.images[#Field.images].center.lat
      lngM =  Field.images[#Field.images].center.lng
      coslatM = math.cos(math.rad(latM))
      xy0 = ll2xy(lat00, lng00, latM, lngM, coslatM)
      xy1 = ll2xy(latitude, longitude, latM, lngM, coslatM)
      --print(latitude, longitude, xy0.x,xy0.y, xy1.x, xy1.y)
      --print("distHome:", math.sqrt( (xy1.x-xy0.x)*(xy1.x-xy0.x) + (xy1.y-xy0.y)*(xy1.y-xy0.y) ))
      return math.sqrt( (xy1.x-xy0.x)*(xy1.x-xy0.x) + (xy1.y-xy0.y)*(xy1.y-xy0.y) )
   else
      return 0
   end
   
end

------------------------------------------------------------

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

   if metrics.loopCount & 3 == 1 then -- about every 4*30 msec
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

   if switchItems.color then
      swc = system.getInputsVal(switchItems.color)
   end

   if (switchItems.color) and (swc ~= lastswc) and swc == 1 then
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
   --[[
   sensor = system.getSensorByID(telem.CourseGPS.SeId, telem.CourseGPS.SeId)
   if sensor and sensor.valid then
      courseGPS = sensor.value
      hasCourseGPS = true
   end
   --]]
   
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
   
   --defend against silly points .. sometimes they come from the RCT GPS
   --hopefully this is larger than any field (mag 14 is about 2500m wide)
   
   if (math.abs(x) > 10000.) or (math.abs(y) > 10000.) or (math.abs(altitude) > 10000.) then
      --print("Bad point - discarded:", x,y,latitude,longitude,altitude)
      return
   end

   --special case .. seed the xtable with one point even if not moving to allow tri drawing
   if newpos or (#xtable == 0) then -- only include in history if new point

      -- keep a max of variables.histMax points
      -- only record if moved variables.histDistance meters (Manhattan dist)
      
      -- keep hist of lat/lng too since images don't have same lat0 and lng0 we need to recompute
      -- x and y when the image changes. that is done in graphScale()

      --print("x,y", x, y, variables.histMax)
      
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

	 --local sgTT = system.getTxTelemetry()
	 --print(sgTT.rx1Percent, sgTT.RSSI[1], sgTT.RSSI[2], sgTT.rx1Voltage)
	 
	 if variables.ribbonColorSource == 1 then -- none
	    jj = #rgb // 2 -- mid of gradient - right now this is sort of a yellow color
	 elseif variables.ribbonColorSource == 2 then -- altitude 0-500m
	    jj = gradientIndex(altitude, 0, 600, #rgb)
	 elseif variables.ribbonColorSource == 3 then -- speed 0-300 km/hr
	    jj = gradientIndex(speed, 0, 300, #rgb)
	 elseif variables.ribbonColorSource == 4 then -- triRace Laps
	    jj = gradientIndex(raceParam.lapsComplete,
			       0, #rgb-1, #rgb, #rgb)
	 elseif variables.ribbonColorSource == 5 then -- switch
	    jj = gradientIndex(swcCount,
			       0, #rgb-1, #rgb, #rgb)
	 elseif variables.ribbonColorSource == 6 then -- Rx1 Q
	    jj = gradientIndex(system.getTxTelemetry().rx1Percent, 0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 7 then -- Rx1 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[1],    0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 8 then -- Rx1 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[2],    0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 9 then -- Rx1 V
	    jj = gradientIndex(system.getTxTelemetry().rx1Voltage, 0,   8,  #rgb)
	 elseif variables.ribbonColorSource == 10 then -- Rx2 Q
	    jj = gradientIndex(system.getTxTelemetry().rx2Percent, 0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 11 then -- Rx2 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[3],    0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 12 then -- Rx2 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[4],    0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 13 then -- Rx2 V
	    jj = gradientIndex(system.getTxTelemetry().rx2Voltage, 0,   8,  #rgb)
	 elseif variables.ribbonColorSource == 14 then -- P4
	    jj = gradientIndex((1+system.getInputs("P4"))*50, 0,   100,  #rgb)	   
 	 elseif variables.ribbonColorSource == 15 then -- Distance
	    jj = gradientIndex(distHome(), 0, distDiag(),  #rgb)
	 elseif variables.ribbonColorSource == 16 then -- Radial
	    jj = gradientIndex((360+math.deg(math.atan(x,y)))%360,0, 360, #rgb)	    	    
	 else
	    print("ribbon color bad idx")
	 end

	 --jj = (#rgb - 1) * math.max(math.min ((altitude - 20) / (200-20),1),0) + 1
	 --jj = math.floor(jj+0.5)
	 --print(altitude, #latHist, jj)
	 --print("#", math.floor((#latHist/1)-1)%9 + 1)
	 --local jj = math.floor((#latHist/5)-1) % #rgb + 1

	 --print("jj", jj)
	 
	 table.insert(rgbHist, {r=rgb[jj].r,
				g=rgb[jj].g,
				b=rgb[jj].b,
				rgb = rgb[jj].r*256*256 + rgb[jj].g*256 + rgb[jj].b})
	 --print("#latHist, r,g,b:", #latHist, rgbHist[#latHist].r,
	   --    rgbHist[#latHist].g,rgbHist[#latHist].b)
		      
	 lastHistTime = system.getTimeCounter()
      end

---===
   ------------------------------------------------------------
   if #xtable+1 > MAXTABLE then
      table.remove(xtable, 1)
      table.remove(ytable, 1)
      --print("deltax,y:", xtable[#xtable] - x, ytable[#ytable] - y)
   end
   
   table.insert(xtable, x)
   table.insert(ytable, y)
   
   if #xtable == 1 then
      path.xmin = map.Xmin
      path.xmax = map.Xmax
      path.ymin = map.Ymin
      path.ymax = map.Ymax
   end
   
   if #xtable > lineAvgPts then -- we have at least 4 points...
      -- make sure we have a least 3m of manhat dist over which to compute compcrs
      if (math.abs(xtable[#xtable]-xtable[#xtable-lineAvgPts+1]) +
	  math.abs(ytable[#ytable]-ytable[#ytable-lineAvgPts+1])) > 3 then
	 
	 compcrs = select(2,fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
				   table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {})))
      end
   else
      compcrs = nil
   end
   compcrsDeg = (compcrs or 0)*180/math.pi
   ------------------------------------------------------------
   ---===

   xtable.xf = xtable[#xtable] - speed * (variables.futureMillis / 1000.0) *
	 math.cos(math.rad(270-heading))
      ytable.yf = ytable[#xtable] - speed * (variables.futureMillis / 1000.0) *
	 math.sin(math.rad(270-heading))

      checkNoFly(x, y, false, true)
      if variables.futureMillis > 0 then
	 checkNoFly(x, y, true,  true)
      end
      
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

   --[[
   for k,v in ipairs(shapes.gradient) do
      rgb[k] = {}
      rgb[k].r, rgb[k].g, rgb[k].b =  string.match(v, ("(%w%w)(%w%w)(%w%w)"))
      rgb[k].r = (tonumber(rgb[k].r, 16) or 0)
      rgb[k].g = (tonumber(rgb[k].g, 16) or 0)
      rgb[k].b = (tonumber(rgb[k].b, 16) or 0)       
      --print(k, rgb[k].r, rgb[k].g, rgb[k].b)
   end
   --]]

   ---[[
   -- overwrite rgb .. experiment
   -- trig functions approximate shapes of rgb ranbow color components ... cute 
   -- https://en.wikibooks.org/wiki/Color_Theory/Color_gradient  
   -- the 0.7 is so we don't wrap all the way back to the original color

   local rp = 10
   for k = 1, rp, 1 do
      rgb[k] = {}
      rgb[k].r = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp)) / 2)
      rgb[k].g = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 2*math.pi/3)) / 2)
      rgb[k].b = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 4*math.pi/3)) / 2)
      --print(k, rgb[k].r, rgb[k].g, rgb[k].b)
   end
   --]]

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
   variables.ribbonAlpha       = jLoad(variables, "ribbonAlpha",   1.0)
   variables.switchesSet       = jLoad(variables, "switchesSet")
   variables.annText           = jLoad(variables, "annText", "c-d----")   
   variables.preText           = jLoad(variables, "preText", "s-a----")      
   variables.ribbonColorSource = jLoad(variables, "ribbonColorSource", 1)
   variables.startSwitchName   = jLoad(variables, "startSwitchName", 0)
   variables.startSwitchDir    = jLoad(variables, "startSwitchDir", 0)
   variables.triASwitchName    = jLoad(variables, "triASwitchName", 0)
   variables.triASwitchDir     = jLoad(variables, "triASwitchDir", 0)
   variables.pointSwitchName   = jLoad(variables, "pointSwitchName", 0)
   variables.pointSwitchDir    = jLoad(variables, "pointSwitchDir", 0)
   variables.colorSwitchName   = jLoad(variables, "colorSwitchName", 0)
   variables.colorSwitchDir    = jLoad(variables, "colorSwitchDir", 0)            
   variables.mapAlpha          = jLoad(variables, "mapAlpha", 255)
   
   checkBox.triEnabled = jLoad(variables, "triEnabled", false)
   checkBox.noflyEnabled = jLoad(variables, "noflyEnabled", true)
   checkBox.noFlyWarningEnabled = jLoad(variables, "noFlyWarningEnabled", true)   
   checkBox.noFlyShakeEnabled = jLoad(variables, "noFlyShakeEnabled", true)   

   --pointSwitch = system.pLoad("pointSwitch")
   --print("pLoad .. pointSwitch", pointSwitch)
   
   --triASwitch  = system.pLoad("triASwitch")
   --print("pLoad .. triASwitch", triASwitch)
   
   --startSwitch = system.pLoad("startSwitch")
   --print("pLoad .. startSwitch", startSwitch)

   --colorSwitch = system.pLoad("colorSwitch")
   --print("pLoad .. colorSwitch", colorSwitch)
   
   -- if variables.switchesSet and not pointSwitch and not colorSwitch then
   --    system.messageBox(appInfo.Name .. ": please reassign switches")
   --    print("please reassign switches")
   --    variables.switchesSet = nil
   -- end
   
   metrics.loopCount = 0
   metrics.lastLoopTime = system.getTimeCounter()
   metrics.loopTimeAvg = 0

   system.registerForm(1, MENU_APPS, appInfo.menuTitle, initForm, keyForm, prtForm)
   system.registerTelemetry(1, appInfo.Name.." Map View", 4, mapPrint)
   system.registerTelemetry(2, appInfo.Name.." Triangle View", 4, dirPrint)   
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   --arcFile = lcd.loadImage(appInfo.Dir .. "JSON/c-000.png")

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

   switchItems = {point = 0, start = 0, triA = 0, color = 0}
   
   for k,v in pairs(switchItems) do
      switchItems[k] = createSw(shapes.switchNames[variables[k.."SwitchName"]],
				variables[k.."SwitchDir"])
      checkBox[k.."Switch"] = system.getInputsVal(switchItems[k]) == 1
   end
   
   -- ff = io.open("Apps/gbl.txt", "w")
   -- print("type:", type(_G))
   -- if ff then
   --    for k,v in pairs(_G) do
   -- 	 io.write(ff, tostring(k), tostring(v), "\n")
   --    end
   -- end
   -- io.close(ff)

end

return {init=init, loop=loop, author="DFM", version="7.25", name=appInfo.Name, destroy=destroy}
