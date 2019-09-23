--[[

   --------------------------------------------------------------------------------------------------
   DFM-Tele.lua -- write telemetry values to the  serial link

   Requires transmitter firmware 4.22 or higher.
    
   Developed on DS-24, only tested on DS-24

   --------------------------------------------------------------------------------------------------
   DFM-Tele.lua released under MIT license by DFM 2019
   --------------------------------------------------------------------------------------------------

--]]

collectgarbage()

------------------------------------------------------------------------------

-- Persistent and global variables for entire progrem

local TeleVersion = "0.0"

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
-- local DistanceGPS

local lastlonW=0
local lastlatW=0
local lastaltW=0
local lastspdW=0
local P1, P2, P3, P4 = 0,0,0,0
local lastP1, lastP2, lastP3, lastP4 = 0,0,0,0
local serialFile
local teleSeq = 0

local telem= {}

telem.Latitude={}
telem.Latitude.Format="%4.8f"
telem.Latitude.updateTime = 200

telem.Longitude={}
telem.Longitude.Format="%4.8f"
telem.Longitude.updateTime = 200

telem.Altitude={}
telem.Altitude.Format="%4.2f"
telem.Altitude.updateTime = 200

telem.BaroAlt={}
telem.BaroAlt.Format="%4.2f"
telem.BaroAlt.updateTime = 200

telem.Speed={}
telem.Speed.Format="%4.2f"
telem.Speed.updateTime = 200

telem.SpeedGPS={}
telem.SpeedGPS.Format="%4.2f"
telem.SpeedGPS.updateTime = 200

telem.SpeedNonGPS={}
telem.SpeedNonGPS.Format="%4.2f"
telem.SpeedNonGPS.updateTime = 200

telem.Distance={}
telem.Distance.Format="%4.2f"
telem.Distance.updateTime = 200

telem.DistanceGPS={}
telem.DistanceGPS.Format="%4.2f"
telem.DistanceGPS.updateTime = 200

telem.Heading={}
telem.Heading.Format="%4.2f"
telem.Heading.updateTime = 200

telem.CourseGPS={}
telem.CourseGPS.Format="%4.2f"
telem.CourseGPS.updateTime = 200

local modelProps={}

local countNoNewPos = 0

-- these lists are the non-GPS senggors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }

local sysTimeStart=0


local DEBUG = false -- if set to <true> will generate flightpath automatically for demo purposes

--dumps a table in human-readable format (sort of)
--kills the script sometimes for a really big table!

local function dumpt(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then
	    k = '"'..k..'"'
	 end
	 s = s .. '['..k..'] = ' .. dumpt(v) .. ','
      end
      return s .. '}\r\n\r\n '
   else
      return tostring(o)
   end
end

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

local currentLabel

local function tele4()
   local ss
   lcd.drawText(5, 5, "(Seq:" .. math.floor(teleSeq)..")" .. " CPU: " .. system.getCPU())
   ss = string.format("(Tim:%.2f)", (system.getTimeCounter() - sysTimeStart)/1000)
   lcd.drawText(5,25, ss)
   ss = string.format("(Lat:%4.6f)", latitude)
   lcd.drawText(5,45, ss)
   ss = string.format("(Lon:%4.6f)", longitude)
   lcd.drawText(5,65, ss)
   ss = string.format("(Alt:%4.2f)", altitude)
   lcd.drawText(5,85, ss)
   ss = string.format("(Spd:%4.2f)", speed)
   lcd.drawText(5,105, ss)
   ss = string.format("(Ctl:%2.2f$%2.2f$%2.2f$%2.2f)", P1, P2, P3, P4)
   lcd.drawText(5,125, ss)   
end

local function readSensors()

   local fr

   print("In readSensors()")
   
   for k,_ in pairs(telem) do
      telem[k].nextRead = 0
      telem[k].currentVal = 0.0
      telem[k].lastVal = 0.0
   end
   
   
   local sensors = system.getSensors()
   local dumped = dumpt(sensors)

   fr = io.open("sensord.tbl", "w")

   print("fr:", fr)
   
   if fr then
      io.write(fr, dumped)
      io.close(fr)
   else
      print("readSensors: Could not open write file for dump")
   end
   
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then

	 --[[
	    Note:
	    Digitech CTU Altitude is type 1, param 13 (vs. MGPS Altitude type 1, param 6)
	    MSpeed Velocity (airspeed) is type 1, param 1
	 
	    Code below will put sensor names in the choose list and auto-assign the relevant
	    selections for the Jeti MGPS, Digitech CTU and Jeti MSpeed
	 --]]

	 if sensor.param == 0 then -- it's a label
	    currentLabel = sensor.label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)	    
	 elseif sensor.type == 9 then  -- lat/long
	    table.insert(GPSsensorLalist, sensor.label)
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)
	    if (sensor.label == 'Longitude' and sensor.param == 3) then
	       telem.Longitude.label = currentLabel
	       telem.Longitude.Se = #GPSsensorLalist
	       telem.Longitude.SeId = sensor.id
	       telem.Longitude.SePa = sensor.param
	    end
	    if (sensor.label == 'Latitude' and sensor.param == 2) then
	       telem.Latitude.label = currentLabel
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
	       telem.SpeedNonGPS.label = currentLabel
	       telem.SpeedNonGPS.Se = #sensorLalist
	       telem.SpeedNonGPS.SeId = sensor.id
	       telem.SpeedNonGPS.SePa = sensor.param
	    end
	    if sensor.label == 'Altitude' and sensor.param == 13 then
	       telem.BaroAlt.label = currentLabel
	       telem.BaroAlt.Se = #sensorLalist
	       telem.BaroAlt.SeId = sensor.id
	       telem.BaroAlt.SePa = sensor.param
	    end	    
	    if sensor.label == 'Altitude' and sensor.param == 6 then
	       telem.Altitude.label = currentLabel
	       telem.Altitude.Se = #sensorLalist
	       telem.Altitude.SeId = sensor.id
	       telem.Altitude.SePa = sensor.param
	    end
	    if sensor.label == 'Distance' and sensor.param == 7 then
	       telem.DistanceGPS.label = currentLabel
	       telem.DistanceGPS.Se = #sensorLalist
	       telem.DistanceGPS.SeId = sensor.id
	       telem.DistanceGPS.SePa = sensor.param
	    end
	    if sensor.label == 'Speed' and sensor.param == 8 then
	       telem.SpeedGPS.label = currentLabel
	       telem.SpeedGPS.Se = #sensorLalist
	       telem.SpeedGPS.SeId = sensor.id
	       telem.SpeedGPS.SePa = sensor.param
	    end
	    if sensor.label == 'Course' and sensor.param == 10 then
	       telem.CourseGPS.label = currentLabel
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

--------------------------------------------------------------------------------


local function initForm(subform)

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
   
   form.addRow(1)
   
end

local function sensorName(device_name, param_name)
   return device_name .. "_" .. param_name -- sensor name is human readable e.g. CTU_Altitude
end

local function sensorID(devID, devParm)
   return devID..devParm -- sensor ID is machine readable e.g. 420460025613 (13 concat to 4204600256)
end

local function unpackAngle(packed)
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end

-- presistent and global variables for loop()

local lastlat = 0
local lastlong = 0
local compcrsDeg = 0
local numGPSreads = 0
local newPosTime = 0
local hasCourseGPS

local function loop()

   local minutes, degs
   local hasPitot
   local sensor
   local goodlat, goodlong 
   local newpos
   local deltaPosTime = 100 -- min sample interval in ms

   goodlat = false
   goodlong = false

   if telem.Longitude.SeId and telem.Longitude.SeId ~= 0 then
      sensor = system.getSensorByID(telem.Longitude.SeId, telem.Longitude.SePa)
      if(sensor and sensor.valid) then
	 minutes = (sensor.valGPS & 0xFFFF) * 0.001
	 degs = (sensor.valGPS >> 16) & 0xFF
	 longitude = degs + minutes/60
	 if sensor.decimals == 3 then -- "West" .. make it negative (NESW coded in dec. places as 0,1,2,3)
	    longitude = longitude * -1
	 end
	 goodlong = true
      end
   end
   
   
   if telem.Latitude.SeId and telem.Latitude.SeId ~= 0 then
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
   end

   -- throw away first 10 GPS readings to let unit settle
   if numGPSreads <= 10 then 
      -- print("Discarding reading: ", numGPSreads, latitude, longitude, goodlat, goodlong)
      return
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

   if telem.Altitude.SeId and telem.Altitude.SeId ~= 0 then
      sensor = system.getSensorByID(telem.Altitude.SeId, telem.Altitude.SePa)
      if(sensor and sensor.valid) then
	 GPSAlt = sensor.value*3.28084 -- convert to ft, telem apis only report native values
      end
   end

   if telem.SpeedNonGPS.SeId and telem.SpeedNonGPS.SeId ~= 0 then
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
   end
   
   if telem.BaroAlt.SeId and telem.BaroAlt.SeId ~= 0 then
      sensor = system.getSensorByID(telem.BaroAlt.SeId, telem.BaroAlt.SePa)
      if(sensor and sensor.valid) then
	 baroAlt = sensor.value * 3.28084 -- unit conversion m to ft
      end
   end
   
   if telem.SpeedGPS.SeId and telem.SpeedGPS.SeId ~= 0 then
      sensor = system.getSensorByID(telem.SpeedGPS.SeId, telem.SpeedGPS.SePa)
      if(sensor and sensor.valid) then
	 if sensor.unit == "kmh" or sensor.unit == "km/h" then
	    SpeedGPS = sensor.value * 0.621371 -- unit conversion to mph
	 end
	 if sensor.unit == "m/s" then
	    SpeedGPS = sensor.value * 2.23694
	 end
      end
   end

   if telem.CourseGPS and telem.CourseGPS ~= 0 then
      hasCourseGPS = false
      sensor = system.getSensorByID(telem.CourseGPS.SeId, telem.CourseGPS.SeId)
      if sensor and sensor.valid then
	 courseGPS = sensor.value
	 hasCourseGPS = true
      end
   end
   
   if satCountID ~= 0 then
      sensor = system.getSensorByID(satCountID, satCountPa)
      if sensor and sensor.valid then
	 satCount = sensor.value
      end
   end

   if satQualityID ~= 0 then
      sensor = system.getSensorByID(satQualityID, satQualityPa)
      if sensor and sensor.valid then
	 satQuality = sensor.value
      end   
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
      if hasPitot and (SpeedNonGPS ~= nil) then
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
   
   if (latitude == lastlat and longitude == lastlong) or
      (math.abs(system.getTimeCounter()) < newPosTime) -- mac emulator had sgTC negative???
   then
      countNoNewPos = countNoNewPos + 1
      newpos = false
   else
      newpos = true
      lastlat = latitude
      lastlong = longitude
      newPosTime = system.getTimeCounter() + deltaPosTime
      countNoNewPos = 0
   end

   
-- defend against random bad points ... 1/6th degree is about 10 mi

--   if (math.abs(longitude-long0) > 1/6) or (math.abs(latitude-lat0) > 1/6) then
--      print('Bad lat/long: ', latitude, longitude, satCount, satQuality)
--      return
--   end
   
   if DEBUG then
      heading = compcrsDeg    else
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


   -- if we get to this point we have a new and valid GPS position and should write to the
   -- serial port
   P1, P2, P3, P4 = system.getInputs("P1", "P2", "P3", "P4")
   
   local ss
   
   if lastlonW ~= longitude or lastlatW ~= latitude or lastaltW ~= altitude or lastspdW ~= speed
   or lastP1 ~= P1 or lastP2 ~= P2 or lastP3 ~= P3 or lastP4 ~= P4 then
      teleSeq = teleSeq + 1
      ss = string.format("(Seq:%d)", teleSeq)
      io.write(serialFile, ss)
      ss = string.format("(Tim:%d)", system.getTimeCounter() - sysTimeStart)
      io.write(serialFile, ss)
      ss = string.format("(Pos:%4.8f$%4.8f)", latitude, longitude)
      io.write(serialFile, ss)
      ss = string.format("(Alt:%4.2f)", altitude)
      io.write(serialFile, ss)
      ss = string.format("(Spd:%4.2f)", speed)
      io.write(serialFile, ss)
      ss = string.format("(Ctl:%2.2f$%2.2f$%2.2f$%2.2f)", P1, P2, P3, P4)
      io.write(serialFile, ss)
      --
      io.write(serialFile, "\r\n")
      lastlonW=longitude
      lastlatW=latitude
      lastaltW=altitude
      lastspdW=speed
      lastP1 = P1
      lastP2 = P2
      lastP3 = P3
      lastP4 = P4
   end

end

local function init()

--   for i, j in ipairs(telem) do
--      telem[j].Se   = system.pLoad("telem."..telem[i]..".Se", 0)
--      telem[j].SeId = system.pLoad("telem."..telem[i]..".SeId", 0)
--      telem[j].SePa = system.pLoad("telem."..telem[i]..".SePa", 0)
--   end

   local fg, fn
   
   system.registerForm(1, MENU_APPS, "Telemetry to Serial", initForm, nil, nil)
   system.registerTelemetry(1, "Sequence", 4, tele4)
   
   print("Model: ", system.getProperty("Model"))
   print("Model File: ", system.getProperty("ModelFile"))

   -- replace spaces in filenames with underscore
   print("reading: ", "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   
   -- set default for pitotCal in case no "DFM-model.jsn" file

   modelProps.pitotCal = 100
   
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   print("fg:", fg)
   if fg then
      modelProps=json.decode(fg)
   end

   print("mP.brakeChannel: ", modelProps.brakeChannel, "mP.brakeOn: ", modelProps.brakeOn)
   print("mP.throttleChannel", modelProps.throttleChannel, "mP.throttleFull", modelProps.throttleFull)

   local dt = system.getDateTime()
   fn = string.format("Tele_%02d%02d_%d%02d%02d.dat", dt.mon, dt.day, dt.hour, dt.min, dt.sec)
   print("fn:", fn)

   serialFile = io.open(fn, "w")
   print("serialFile: ", serialFile)
   
   --system.playFile('/Apps/DFM-LSO/L_S_O_active.wav', AUDIO_QUEUE)
   
   if DEBUG then
      --print('L_S_O_Active.wav')
   end

   readSensors()

   sysTimeStart = system.getTimeCounter()
   
--   print("dumping telem")
--   print(dumpt(telem))
--   print("done")
   
   collectgarbage()
end


-- setLanguage()
collectgarbage()
return {init=init, loop=loop, author="DFM", version=TeleVersion, name="Tele to Serial"}
