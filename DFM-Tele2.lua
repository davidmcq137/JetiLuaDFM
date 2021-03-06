--[[

   -----------------------------------------------------------------------------------------
   DFM-Tele.lua -- write telemetry values to the serial link

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-Tele.lua released under MIT license by DFM 2019
   -----------------------------------------------------------------------------------------

--]]

-- Persistent and global variables for entire progrem

local TeleVersion = "0.0"

local pcallOK, emulator
local sidSerial
local serialbb = 0
local serialii = 0
local sidTime0 = 0
local firstTelem
local failedInit = false

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
local fuelRem = 0
local RPM = 0
local EGT = 0

-- local DistanceGPS

local serialFile
local teleSeq = 0
local lastWriteTime = 0
local lastStickWrite = 0
local P1, P2, P3, P4 = 0,0,0,0
local lastP1, lastP2, lastP3, lastP4 = 0,0,0,0
local DEBUG = false
local device, emflag

local CTU_ID = 16819262    -- Digitech CTU, params: 5=fuel rem, 12=G, 13=baro alt
                           -- 1=RPM, 3=EGT
local GPS_ID = 0           -- Jeti MGPS, params: 2=lat,3=long,8=speed,9=AltRelat
local MSP_ID = 0           -- Jeti MSPEED, params: 1=velocity

local telem_list= {
   ["RPM"]            = {id=0,name="CTU",   param=1},
   ["EGT"]            = {id=0,name="CTU",   param=3},
   ["Fuel_remaining"] = {id=0,name="CTU",   param=5},
   ["G_Force"]        = {id=0,name="CTU",   param=12},
   ["Baro_Altitude"]  = {id=0,name="CTU",   param=13},
   ["Latitude"]       = {id=0,name="MGPS",  param=2},
   ["Longitude"]      = {id=0,name="MGPS",  param=3},
   ["GPS_Speed"]      = {id=0,name="MGPS",  param=8},
   ["GPS_AltRelat"]   = {id=0,name="MGPS",  param=9},
   ["CTU_Pitot_Speed"]= {id=0,name="Autothrottle",param=3},
   ["Pitot_Speed"]    = {id=0,name="MSPEED",param=1},   
}

local telem= {
   ["RPM"]            = {id=0,param=0,val=0,lastval=0},
   ["EGT"]            = {id=0,param=0,val=0,lastval=0},      
   ["Fuel_remaining"] = {id=0,param=0,val=0,lastval=0},
   ["G_Force"]        = {id=0,param=0,val=0,lastval=0},
   ["Baro_Altitude"]  = {id=0,param=0,val=0,lastval=0},
   ["Latitude"]       = {id=0,param=0,val=0,lastval=0},
   ["Longitude"]      = {id=0,param=0,val=0,lastval=0},
   ["GPS_Speed"]      = {id=0,param=0,val=0,lastval=0},
   ["GPS_AltRelat"]   = {id=0,param=0,val=0,lastval=0},
   ["CTU_Pitot_Speed"]= {id=0,param=0,val=0,lastval=0},
   ["Pitot_Speed"]    = {id=0,param=0,val=0,lastval=0},   
}

local modelProps={}

local countNoNewPos = 0

local sysTimeStart=0
local timeBack = 0

local strCount=0
local lastStrCount = 0
local lastTime = system.getTime()
local zeroTime = lastTime
local cnt
local bps

local usedCPU
local maxCPU

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

local function tele4()
   local ss
   lcd.drawText(5, 5, "(Seq:" .. math.floor(teleSeq)..")" .. " maxCPU: " .. (maxCPU or 0) ..
		   " Curr CPU: "..(usedCPU or 0) )
   ss = string.format("(Tim:%.2f)", (system.getTimeCounter() - sysTimeStart)/1000)
   lcd.drawText(5,25, ss)
   if not timeBack then
      --print("bad timeback in tele4")
   end
   ss = string.format("deltaT:%.2f",
		      (timeBack or 0) - (system.getTimeCounter() - sysTimeStart)/1000)
   lcd.drawText(135, 25, ss)
   ss = string.format("baud:%.2f", 10*(bps or 0))
   lcd.drawText(240, 25, ss)
   ss = string.format("(Lat:%4.6f)", latitude or 0)
   lcd.drawText(5,45, ss)
   ss = string.format("(Frm:%2.2f)", fuelRem or -99)
   lcd.drawText(135,45, ss)
   ss = string.format("(Lon:%4.6f)", longitude or 0)
   lcd.drawText(5,65, ss)
   ss = string.format("(EGT:%2.2f)", EGT or -99)
   lcd.drawText(135,65, ss)
   ss = string.format("(RPM:%2.2f)", RPM or -99)
   lcd.drawText(240,65, ss)      
   ss = string.format("(Alt:%4.2f)", altitude or -99)
   lcd.drawText(5,85, ss)
   ss = string.format("baroAlt: %2.2f", baroAlt or -99)
   lcd.drawText(85,85, ss)
   ss = string.format("GPSAlt: %2.2f", GPSAlt or -99)
   lcd.drawText(205,85, ss)      
   ss = string.format("(Spd:%4.2f)", speed or -99)
   lcd.drawText(5,105, ss)
   ss = string.format("SpeedGPS: %2.2f", SpeedGPS or -99)
   lcd.drawText(135,105, ss)
    ss = string.format("(Ctl:%2.2f$%2.2f$%2.2f$%2.2f)", P1, P2, P3, P4)
   lcd.drawText(5,125, ss)   
end

local isens
local sensors

local function readSensorsX()

   local sensors
   sensors = system.getSensors()
   --print("#sensors:", #sensors)
   for i, sensor in ipairs(sensors) do
      --print(i, type(sensor.id), type(sensor.param), type(sensor.label))
      --print(i, sensor.id, sensor.param, sensor.label)
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
   end
end

local function readSensors(is)

   --this version intended to process one sensor per call ... repeat calls till returns nil
   --intended to reduce processor usage at startup esp if plane has lots of sensors

   local sensor, kfound

   --print("IN readSensors", is)
   
   if not is or is == 0 then
      sensors = system.getSensors()
      --print("Number of sensors returned from system.getSensors: "..#sensors)
      for k,v in pairs(sensors) do
	 --print("k: "..k.."  v.param "..v.param.."  v.id "..v.id.."  v.label "..
		--v.label.."  v.sensorName "..v.sensorName)
      end
      
      isens = 0

   end

   if isens + 1 > #sensors then
      --print("telem")
      for k,v in pairs(telem) do
	 --print("***",k,v.id, v.param, v.val, v.lastval)
      end
      --print("readsensors returning nil")
      return nil
   end

   isens = isens + 1
   sensor = sensors[isens]

   if sensor.param == 0 then
      --print("Sensor ID, label:",sensor.id, sensor.label)
   end

   if (sensor.label ~= "") then
      kfound=nil
      for k,v in pairs(telem_list) do
	 --print("loop: isens, k,v, sensor.param, sensor.label",isens, k,v, sensor.param, sensor.label) 
	 if sensor.param == 0 and sensor.label == v.name then
	    v.id = sensor.id
	 elseif v.id == sensor.id and v.param == sensor.param then
	    telem[k].id=sensor.id
	    telem[k].param=sensor.param
	    kfound=k
	 end
      end
      if kfound then
	 telem_list[kfound]=nil
      end
   end
   --print("readsensors returning", isens)
   return isens
end

----------------------------------------------------------------------

local function unpackAngle(packed)
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end

----------------------------------------------------------------------

local function countedWrite(ff, str)

   local time

   -- if we've never written, and we're being asked to, then set up the serial port
   -- hopefully the Pump program has let it go if it had it.
   
   strCount = strCount + #str

   time = system.getTime()
   if time - lastTime > 10 then
      --print("time, total count, rate in last min:", time-zeroTime, strCount, (strCount-lastStrCount) / (time-lastTime) )
      bps = (strCount - lastStrCount) / (time-lastTime)
      lastStrCount = strCount
      lastTime = time
      maxCPU = 0
   end

   --if ff then io.write(ff, str) end

   if (not sidSerial) and (not failedInit) and firstTelem and ( (system.getTimeCounter() - firstTelem) > 1000) then
      
      print("DFM-Tele2: About to serial init")
      local descr
      if emflag ~= 0 then
	 sidSerial, descr = serial.init("ttyUSB0",9600)
      else
	 sidSerial, descr = serial.init("COM1",9600)
      end
      
      
      if sidSerial then   
	 print("DFM-Tele2: sid succeeded: ", sidSerial)
	 sidTime0 = system.getTimeCounter()
	 gpio.mode(8,"out-pp")      
	 gpio.write(8,1) -- if serial succeeded, turn on BLE device .. see also in loop()
      else
	 print("DFM-Tele2: sid failed", sidSerial, descr)
	 failedInit = true -- don't keep trying once it fails
      end 
      
      --for testing, don't interrupt on read
      
      local success, descr = serial.onRead(sidSerial,onRead)   
      if success then
	 print("DFM-Tele2: Callback registered")
      else
	 print("DFM-Tele2: Error setting callback", descr)
      end
      
   end


   if sidSerial then
      cnt = serial.write(sidSerial, str)
      --print("str, cnt=", str,cnt)
   end
   
   
end



----------------------------------------------------------------------
-- presistent and global variables for loop()

local lastlat = 0
local lastlong = 0
local compcrsDeg = 0
local numGPSreads = 0
local newPosTime = 0
local hasCourseGPS
local rsdone=false
local iii=0
local rsStatus=true

local function loop()

   local sensor
   local minutes, degs
   local hasPitot = false
   local goodlat, goodlong 
   local newpos
   local ss, now
   local Tchg, Pchg
   local deltaPosTime = 100 -- min sample interval in ms

   if rsStatus then
      rsStatus = readSensors(isens)
   end
   
   --if pcallOK and emulator then
   --   if emulator.startUp(readSensors) then -- returns true when it has to keep going
	-- iii = iii + 1
	-- print("iii:", iii)
	-- if iii > 40 then
	--    foo.bar()
	-- end
	 
	-- return
      --end
   --end

   goodlat = false
   goodlong = false
   
   if system.getInputs("SM") == 1 then
      gpio.write(8,1)
   else
      gpio.write(8,0)
   end
   
   --shouldn't we compare param instead of name? equiv func but faster?

   for name, sens in pairs(telem) do
      --print("name, sens, sens.id, sens.param:", name, sens, sens.id, sens.param)
      if sens.id ~= 0 and sens.param ~= 0 then
	 sensor = system.getSensorByID(sens.id, sens.param)
	 --[[
	 if not sensor then
	    print("not sensor: sens.id", sens.id)
	    print("not sensor: sens.param", sens.param)
	    print("closing serialFile")
	    if serialFile then io.close(serialFile) end
	 end

	 if not sensor.valid then
	    print("not sensor valid: sens.id", sens.id)
	    print("not sensor valid: sens.param", sens.param)
	 end
	 --]]
	 --print("sensor.value", sensor.value)
	 
	 
	 if sensor and sensor.valid then

	    -- record time of first telemetry signal in case
	    -- we have to wait for pump pgm to clear out
	    -- see countedWrite()
	    
	    if not firstTelem then firstTelem = system.getTimeCounter() end
	    
	    if sens.id == sensor.id and  name == "Longitude" then
	       sens.val = sensor.valGPS
	       minutes = (sensor.valGPS & 0xFFFF) * 0.001
	       degs = (sensor.valGPS >> 16) & 0xFF
	       longitude = degs + minutes/60
	       if sensor.decimals == 3 then  --"West" make it negative
		  longitude = longitude * -1 -- (NESW coded in dec. places as 0,1,2,3)
	       end
	       goodlong = true
	    elseif sens.id == sensor.id and name == "Latitude" then
	       sens.val = sensor.valGPS
	       minutes = (sensor.valGPS & 0xFFFF) * 0.001
	       degs = (sensor.valGPS >> 16) & 0xFF
	       latitude = degs + minutes/60
	       if sensor.decimals == 2 then -- "South" .. make it negative
		  latitude = latitude * -1
	       end
	       goodlat = true
	       numGPSreads = numGPSreads + 1
	    elseif sens.id == sensor.id and name == "GPS_AltRelat" then
	       sens.val = sensor.value
	       GPSAlt = sensor.value*3.28084 -- to ft - telem apis only report native values
	    elseif sens.id == sensor.id and
	    (name == "Pitot_Speed" or name == "CTU_Pitot_Speed")  then
	       sens.val = sensor.value
	       SpeedNonGPS = sensor.value * 2.23694 * modelProps.pitotCal / 100.
	       hasPitot = true
	    elseif sens.id == sensor.id and name == "Baro_Altitude"  then
	       sens.val = sensor.value
	       --print("Baro_Altitude:", sensor.value)
	       baroAlt = sensor.value * 3.28084 -- unit conversion m to ft
	    elseif sens.id == sensor.id and name == "GPS_Speed" then
	       sens.val = sensor.value
	       SpeedGPS = sensor.value * 2.23694
	    elseif sens.id == sensor.id and name == "Fuel_remaining" then
	       sens.val = sensor.value
	       fuelRem = sensor.value
	    elseif sens.id == sensor.id and name == "RPM" then
	       sens.val = sensor.value
	       RPM = sensor.value / 1000.0
	    elseif sens.id == sensor.id and name == "EGT" then
	       sens.val = sensor.value
	       EGT = sensor.value
	    else
	       --print("bad sensor?")
	    end
	 end
      end
   end
   
   -- throw away first 10 GPS readings to let unit settle
   if numGPSreads <= 10 then 
      -- print("Discarding reading: ", numGPSreads, latitude, longitude, goodlat, goodlong)
      goodlat = false
   end
   
   -- Xicoy FC sends a lat/long of 0,0 on startup .. don't use it
   if latitude and math.abs(latitude) < 1 then
      -- print("Latitude < 1: ", latitude, longitude, goodlat, goodlong)
      goodlat= false
   end
   
   -- Jeti MGPS sends a reading of 240N, 48E on startup .. don't use it
   if latitude and latitude > 239 then
      -- print("Latitude > 239: ", latitude, longitude, goodlat, goodlong)
      goodlat = false
   end 
   
   -- if no GPS or pitot then code further below will compute speed from delta dist
   
   if hasPitot and (SpeedNonGPS ~= nil) then
      speed = SpeedNonGPS
   elseif SpeedGPS ~= nil then
      speed = SpeedGPS
   end
   
   if GPSAlt then
      altitude = GPSAlt
   end
   if baroAlt then -- let baroAlt "win" if both defined
      altitude = baroAlt
   end

   if latitude and longitude then
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
   end

   -- need to determine how best to do this with ipad since we don't know
   -- lat0 and long0 in all cases
   -- e.g. when there is no known flying field
   -- should we grab first valid latlong and set to lat0, long0?
   --
   -- defend against random bad points ... 1/6th degree is about 10 mi
   --   if (math.abs(longitude-long0) > 1/6) or (math.abs(latitude-lat0) > 1/6) then
   --      print('Bad lat/long: ', latitude, longitude, satCount, satQuality)
   --      return
   --   end
   
   if hasCourseGPS and courseGPS then
      heading = courseGPS
   else
      if compcrsDeg then
	 heading = compcrsDeg
      else
	 heading = 0
      end
   end

   
   P1, P2, P3, P4 = system.getInputs("P1", "P2", "P3", "P4")

   --print(P1,P2,P3,P4,lastP1,lastP2,lastP3,lastP4)
   
   now = system.getTimeCounter()
   if now - lastWriteTime < 50 then
      return
   end 
   
   Tchg = false
   for name,sens in pairs(telem) do
      if sens.val ~= sens.lastval then Tchg = true end
      sens.lastval = sens.val
   end
   
   Pchg = false

   --if lastP1 ~= P1 or lastP2 ~= P2 or lastP3 ~= P3 or lastP4 ~= P4 then Pchg = true end
   local deltaP = 0.05
   
   if math.abs(lastP1-P1) > deltaP or math.abs(lastP2-P2) > deltaP or math.abs(lastP3-P3) > deltaP or math.abs(lastP4-P4) > deltaP then Pchg = true end
      
   --if Pchg then
     -- if lastP1 ~= P1 then print("P1:", lastP1, P1, (lastP1-P1)/P1) end
     -- if lastP2 ~= P2 then print("P2:", lastP2, P2, (lastP2-P2)/P2) end
     -- if lastP3 ~= P3 then print("P3:", lastP3, P3, (lastP3-P3)/P3) end
     -- if lastP4 ~= P4 then print("P4:", lastP4, P4, (lastP4-P4)/P4) end      
   --end

   if (now - lastWriteTime) > 250 then
      Pchg = true
      Tchg = true
   end
   
   if Pchg or Tchg  then
      teleSeq = teleSeq + 1
      ss = string.format("(Seq:%d)", teleSeq)
      --countedWrite(serialFile, ss)
      --if emflag == 1 then print(ss) end
      ss = string.format("(Tim:%d)", (system.getTimeCounter() - sysTimeStart)/1000)
      --print(ss)
      countedWrite(serialFile, ss)
      --print("delta T", (timeBack or 0) - (system.getTimeCounter() - sysTimeStart)/1000)
      --if emflag == 1 then print(ss) end
      if Tchg then
	 if newpos then
	    ss = string.format("(Pos:%4.8f$%4.8f)", latitude, longitude)
	    countedWrite(serialFile, ss)
	    --if emflag == 1 then print(ss) end
	 end

	 local tsec = (system.getTimeCounter() - sysTimeStart) / 1000.0
	 --altitude = 200 + 200*math.sin(2*math.pi*tsec/300)
	 ss = string.format("(Alt:%4.2f)", altitude)
	 countedWrite(serialFile, ss)
	 --if emflag == 1 then print(ss) end

	 --speed = 100 + 100*math.cos(2*math.pi*tsec/300)
	 ss = string.format("(Spd:%4.2f)", speed)
	 countedWrite(serialFile, ss)
	 --if emflag == 1 then print(ss) end

	 --fuelRem = 50 + 50*math.cos(2*math.pi*tsec/100)
	 --fuelRem = fuelRem - 0.8
	 if fuelRem < 0 then fuelRem = 100 end
	 
	 
	 ss = string.format("(Frm:%4.2f)", fuelRem)
	 countedWrite(serialFile, ss)

	 --EGT = 800 * (1+math.sin(2*math.pi*tsec/100)) / 2
	 ss = string.format("(EGT:%4.2f)", EGT)
	 countedWrite(serialFile, ss)

	 --RPM = 150 * (1+math.cos(2*math.pi*tsec/100)) / 2
	 ss = string.format("(RPM:%4.2f)", RPM)
	 countedWrite(serialFile, ss)

	 --local escale = system.getInputs("P8")
	 --escale = (1 + escale) / 2
	 escale = 1
	 xp = 2500 * escale * math.sin(2*math.pi*tsec/50)
	 yp = 1000 * escale * (1 + math.cos(2*math.pi*tsec/50))
	 ss = string.format("(XYP:%4.2f$%4.2f)", xp, yp)
	 --print(xp, yp)
	 countedWrite(serialFile, ss)
	 
      end

      if Pchg and ((now - lastStickWrite) > 200) then
	 ss = string.format("(Ctl:%1.2f$%1.2f$%1.2f$%1.2f)", P1, P2, P3, P4)
	 countedWrite(serialFile, ss)
	 lastStickWrite = now
      end

      countedWrite(serialFile, "\r\n")
            
      lastWriteTime = system.getTimeCounter()
   end
   lastP1, lastP2, lastP3, lastP4 = P1, P2, P3, P4
   usedCPU = system.getCPU()
   maxCPU = maxCPU or usedCPU
   if usedCPU  > maxCPU then maxCPU = usedCPU end
   
end

local lastTB = 0

local function onRead(data)
   --print("onRead:", data)
   local i
   i = tonumber(data)
   if not i then
      --print("bad time:", data)
      return
   end
   if i < lastTB then
      --print("backwards time?")
      return
   end
   timeBack = i
   lastTB = timeBack
end

local function init()

   local fg, fn

   print("tele2 init")
   --pcallOK, emulator = pcall(require, "sensorLogEm")
   --print("pcallOK, emulator:", pcallOK, emulator)
   --if not pcallOK then print("pcall error: ", emulator) end
   --if pcallOK and emulator then emulator.init("sensorLogEm.jsn") end

   --system.registerForm(1, MENU_APPS, "Telemetry to Serial", initForm, nil, nil)
   system.registerTelemetry(1, "Tele2 Sequence", 4, tele4)
   
   --print("Model: ", system.getProperty("Model"))
   --print("Model File: ", system.getProperty("ModelFile"))

   -- replace spaces in filenames with underscore
   print("reading: ", "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   
   -- set default for pitotCal in case no "DFM-model.jsn" file

   modelProps.pitotCal = 100
   
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   --print("fg:", fg)
   if fg then
      modelProps=json.decode(fg)
   end

   --print("mP.brakeChannel: ", modelProps.brakeChannel, "mP.brakeOn: ", modelProps.brakeOn)
   --print("mP.throttleChannel", modelProps.throttleChannel, "mP.throttleFull", modelProps.throttleFull)

   local dt = system.getDateTime()
   --fn = string.format("Tele_%02d%02d_%d%02d%02d.dat", dt.mon, dt.day, dt.hour, dt.min, dt.sec)
   --print("fn:", fn)

   --serialFile = io.open(fn, "w")
   --print("serialFile: ", serialFile)

   serialFile = nil
   
   device, emflag = system.getDeviceType()
   
   
   --system.playFile('/Apps/DFM-LSO/L_S_O_active.wav', AUDIO_QUEUE)
   if DEBUG then
      --print('L_S_O_Active.wav')
   end
   


   sysTimeStart = system.getTimeCounter()
   --print("dumping telem")
   --print(dumpt(telem))
   --print("done")

   --print("Device: "..device)
   
   --readSensors()
end


-- setLanguage()
return {init=init, loop=loop, author="DFM", version=TeleVersion, name="Tele to Serial"}
