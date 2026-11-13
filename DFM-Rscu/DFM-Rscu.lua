--[[

   -----------------------------------------------------------------------------------------
   DFM-Rscu "rescue/return to home" .. Conceived by Harry Curzon, coded by DFM. Initially 
   copied from DFM-HUD.lua as starting point

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-Rscu.lua released under MIT license by DFM 2026
   -----------------------------------------------------------------------------------------

--]]

local appName = "DFM-Rscu"
local pathApp = "Apps/"..appName.."/"
local RTH = {}
local buttonText =  {{"-","+","Steer","Turn","Erase"},{"Pt A","Pt B","","",""}}
local buttonSet = 1
local config = {}
local flyingOutbound
local calibrating
--local armed = false
--local everEnabled = false
local lastSec
local announceTime
local lastSwO = -1
local annSeq = 1
local CMULT = 1.33 --circleMax = CMULT * circleMin
local iPindex = 1
local iPMAX
local ixP = {}
local iyP = {}
local Screen = {}
local xmin = {}
local xmax = {}
local ymin = {}
local ymax = {}
local initHalfWid = 500
--local BDALat, BDALng, BDBLat, BDBLng, BDA, BDB, BDZ
local fieldRotation
local pointA
local pointB
local pointZ
local drawRibbon
local distAB
local greenCircle, redCircle
local pointsToRender = 0
local Fields
local savedRow = 1

local steerMode = {petals=1,racetrack=2,leftright=3}
local turnMode = {left=1,right=2,random=3}
local magVal = {1, 1.4, 2, 2.8, 4}
local magIdx

local rescueOnTime
local rescueOnDelay
local holdTurn
local eleDelay

--[[
local testLatControl
local testLatTime
local testLatOut
local testLatMin
local testLatMax
local testLatRun
--]]

RTH.sensorLalist = {"..."}
RTH.sensorLslist = {"..."}
RTH.sensorIdlist = {0}
RTH.sensorPalist = {0}
RTH.sensorUnlist = {"-"}
RTH.sensorDplist = {0}
RTH.sensorTylist = {0}

RTH.gpsLalist = {"..."}
RTH.gpsLslist = {"..."}
RTH.gpsIdlist = {0}
RTH.gpsPalist = {0}

RTH.settings = {}
RTH.timers = {}
RTH.switchInfo = {}
RTH.var = {}

RTH.convertStr = {"None", "m to ft", "m/s to mph", "m/s to km/h", "°C to °F", "/1000"}
RTH.convertVal = {{1,0}, {3.28084,0}, {2.23694,0} , {3.6,0}, {1.8,32}, {.001,0}}
RTH.convertUnits = {"-", "ft", "mph", "km/h", "°F", "-"}
local rollVal, pitchVal = 0,0
local ixL = {}
local iyL = {}
local xLast
local yLast

local renShape
--local ren = lcd.renderer()

--local barShape = {
--   {-40,-2},
--   {-40,2},
--   {40, 2},
--   {40, -2}
--}


--[[
local homeShape = {
 { 0, -15},
 {-12, 12},
 { 0, 6},
 { 12, 12}
}
--]]

local emflag

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function scanGPSFiles(cp, F)

   if not cp then -- just scan and return table of fields
      local FF = {}
      local file, fn, ext, dd, ff
      local path = prefix() .. pathApp.."Fields"
      if dir(path) then
	 --print("dir(path) true for")
	 for name, _, _ in dir(path) do
	    dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
	    --print("name, dd, fn, ext", name, dd, fn, ext)
	    if fn and ext then
	       if string.lower(ext) == "gps" then
		  ff = path .. "/" .. fn .. "." .. ext
		  file = io.readall(ff)
		  if file then
		     local dc = json.decode(file)
		     table.insert(FF, dc)
		  end
	       end
	    end
	 end
      else
	 print(appName..": Bad path to dir - "..path)      
      end
      return FF
   else -- look for a match to gps point cp
      local matchDist = 500 -- meters
      local retZ, retA, retB
      for _,v in pairs(F) do
	 local tp = gps.newPoint(v.zeroPos[1], v.zeroPos[2])
	 local gd = gps.getDistance(cp, tp)
	 if gd < matchDist then
	    retZ = gps.newPoint(v.zeroPos[1], v.zeroPos[2])
	    retA = gps.newPoint(v.pointA[1], v.pointA[2])
	    retB = gps.newPoint(v.pointB[1], v.pointB[2])
	 end
      end
      return retZ, retA, retB
   end
end

--Sample file name: R41339N74431W
--Sample json:
--{
--"pointA":[41.33979,-74.43162],
--"pointB":[41.33947,-74.43153],
--"zeroPos":[41.33979,-74.43162]
--}

--[[ -- handled by scan function
local function readGPSFile(fn)
   print("read", fn)
   local jtext = io.readall(fn)
   print("jtext", jtext)
   local dat = json.decode(jtext)
   local field0 = gps.newPoint(dat.zeroPos[1], dat.zeroPos[2])
   local ptA = gps.newPoint(dat.pointA[1], dat.pointA[2])
   local ptB = gps.newPoint(dat.pointB[1], dat.pointB[2])
   print("zero", gps.getString(field0))
   print("A", gps.getString(ptA))
   print("B", gps.getString(ptB))
   return field0, ptA, ptB
end
--]]

local function writeGPSFile(field0, ptA, ptB)
   local lat,lng = gps.getValue(field0)
   local ns, ew
   if lat >= 0 then ns = "N" else ns = "S" end
   if lng >= 0 then ew = "E" else ew = "W" end
   lats = string.format("%4d"..ns, math.floor(math.abs(lat)*1000))
   lngs = string.format("%4d"..ew, math.floor(math.abs(lng)*1000))
   local fn = "R"..lats..lngs..".gps"
   local dat = {}
   dat.zeroPos = {lat, lng}
   lat,lng = gps.getValue(ptA)
   dat.pointA = {lat, lng}
   lat, lng = gps.getValue(ptB)
   dat.pointB = {lat, lng}
   local jtext = json.encode(dat)
   local ffn = prefix()..pathApp.."Fields/"..fn
   local f = io.open(ffn, "w")
   if not f then return nil end
   io.write(f, jtext, "\n")
   io.close(f)
   return ffn
end

local function setGPSField(zP, ptA, ptB)
   if not zP or not ptA or not ptB then return end
   
   fieldRotation = math.rad(gps.getBearing(ptA, ptB) - 90)
         
   system.messageBox(string.format("Field rotation set to %d°", math.deg(fieldRotation)))
   -- 60m is distance behind pilot to bottom of screen
   ptZ = gps.getDestination(ptA, 60, gps.getBearing(ptA, ptB) + 90)
   
   local bb = gps.getBearing(zP, ptZ)
   local dd = gps.getDistance(zP, ptZ)
   local xBottom = dd * math.sin(math.rad(bb))
   local yBottom = dd * math.cos(math.rad(bb))

   xBottom, yBottom = rotateXY(xBottom, yBottom, fieldRotation)

   --print("xBottom, yBottom", xBottom, yBottom)
   
   for i,_ in ipairs(magVal) do
      xmin[i] = xBottom - magVal[i] * initHalfWid
      xmax[i] = xBottom + magVal[i] * initHalfWid
      ymin[i] = yBottom - 80
      ymax[i] = yBottom - 80 + 2 * Screen.height / Screen.width * magVal[i] * initHalfWid
   end

   --save this location to a file for next time. filename encodes position not using
   --too many digits of lat and lng ..so should not create too many copies

   pointA = ptA
   pointB = ptB
   pointZ = ptZ
   writeGPSFile(zP, ptA, ptB)
   
end

local function setMag(idx)
   if idx < 1 or idx > #magVal then return end
   ixP = {}
   iyP = {}
   iPindex = 1
end


local function inv(t)
   local rt = {}
   if not t then return rt end
   for k,v in pairs(t) do
      rt[v] = k
   end
   return rt
end

local function drawX(xxp, yyp, d)
   lcd.drawLine(xxp - d, yyp + d, xxp + d, yyp - d)
   lcd.drawLine(xxp - d, yyp - d, xxp + d, yyp + d)
end

local function playNumberCompass(val)
   local ns = string.format("%03d", math.floor(val))
   for digit in string.gmatch(ns, "%d") do
      system.playNumber(tonumber(digit), 0)
   end
end

local function playNumberInt(val)
   system.playNumber(math.floor(val + 0.5), 0)
end


local function mixOut(mix, val)
   local np = #mix.points
   local mg = mix.gain / 100
   if val <= mix.points[1].x / 100 then
      return mg * mix.points[1].y / 100 
   end
   
   if val >= mix.points[np].x / 100 then
      return mg * mix.points[np].y / 100
   end
   
   for i=2,np,1 do
      if val <= mix.points[i].x / 100 then
	 return mg * (mix.points[i-1].y + (mix.points[i].y - mix.points[i-1].y) *
			    (val * 100 - mix.points[i-1].x) / (mix.points[i].x - mix.points[i-1].x)) / 100
      end
   end
   
   return 0 -- should not happen
end

local function xytopixel(x, y, imag)
   local i = magIdx
   if imag then i = imag end
   --if imag then print("imag", imag) end
   local w, h = Screen.width, Screen.height --320, 160
   local ix = w * (x - xmin[i]) / (xmax[i] - xmin[i])
   local iy = h - h * (y - ymin[i]) / (ymax[i] - ymin[i])
   return ix,iy
end

--[[
local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
end

local function ms(ival)
   local val
   if not ival then val = 0 else val = ival / 1000 end
   local sign
   if val > 0 then sign = "+" elseif val < 0 then sign = "-" else sign = " " end
   local aval = math.abs(val)
   local mins = aval // 60
   local secs = math.floor(aval - mins * 60)
   return mins, secs, sign
end
--]]

local function readSensors(tt)
   local sensorLbl = "***"
   local l1, l2, l3
   local GPStype = 9

   local sn = {lat = "Latitude", lng = "Longitude", hdg = "Heading", alt = "Altitude",
	       roll = "Roll", pitch = "Pitch"}

   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    l3 = string.gsub(sensor.unit, "%W", "")
	    if emflag == 1 then
	       for k,v in pairs(sn) do
		  if l2 == v then
		     RTH.settings[k.."Id"] = sensor.id
		     RTH.settings[k.."Pa"] = sensor.param
		  end
	       end
	    end
	    if sensor.type ~= GPStype then
	       table.insert(tt.sensorLalist, l1 .. "_" .. l2 .. " [" .. l3 .. "]")
	       table.insert(tt.sensorLslist, sensor.label)	    
	       table.insert(tt.sensorIdlist, sensor.id)
	       table.insert(tt.sensorPalist, sensor.param)
	       table.insert(tt.sensorUnlist, sensor.unit)
	       table.insert(tt.sensorDplist, sensor.decimals)
	       table.insert(tt.sensorTylist, sensor.type)
	    else
	       table.insert(tt.gpsLalist, l1 .. "_" .. l2 .. " [" .. l3 .. "]")
	       table.insert(tt.gpsLslist, sensor.label)	    
	       table.insert(tt.gpsIdlist, sensor.id)
	       table.insert(tt.gpsPalist, sensor.param)
	    end
	 end
      end
   end
end

--[[
local function encdp(dp, val)
   if dp == 2 then
      return string.format("%.2f", val)
   elseif dp == 1 then
      return string.format("%.1f", val)
   else
      return string.format("%.0f", val)
   end
end
--]]

local nsHoldVal
local nsHoldTime
local turnTime

local function loopP()
   local now
   local sensor
   local MINHDGDIST = 3
   local MINGPSREADS= 9
   local MINANNDIST = 5
   local info
   local SwO, SwC
   local altnow
   
   now = system.getTimeCounter()
   if not lastSec then lastSec = now end
   if not announceTime then announceTime = now end

   --if emflag ~= 0 and system.getTimeCounter() < 0 then
   --   print("system.getTimeCounter() wrapped. Restart emulator", system.getTimeCounter())
   --end

   sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
   if sensor and sensor.valid then
      --tele should only report in m but some devices can do other units .. be defensive
      if sensor.unit == "ft" or sensor.unit == "ft." then
	 altnow = sensor.value * 0.3048
      else
	 altnow = sensor.value
      end
      if not RTH.var.startTakeoffAlt then
	 if emflag ~= 0 then
	    RTH.var.startTakeoffAlt = 0
	 else
	    RTH.var.startTakeoffAlt = altnow
	 end
      end
      --print(emflag, altnow, RTH.var.startTakeoffAlt)
      RTH.altitude = altnow - RTH.var.startTakeoffAlt
   end

   --[[
   
   -- using alt to read voltmeter from Assist RX digi out .. reads 0 ot 3.3v
   --print("altnow, testLatOut", altnow, testLatOut)
   local dt
   if altnow then
      if altnow > 0.5 and testLatOut > 0 then
	 testLatOut = -1
	 system.setControl(testLatControl, testLatOut, 0)
	 dt = now - testLatTime
	 print("match > 1.5", dt, testLatMin, testLatMax, testLatRun)
	 testLatTime = now
	 if not testLatMin then testLatMin = dt testLatMax = dt testLatRun = dt end
	 if dt < testLatMin then testLatMin = dt end
	 if dt > testLatMax then testLatMax = dt end
	 testLatRun = testLatRun + (dt - testLatRun)/100
      elseif altnow < 0.5 and testLatOut < 0 then
	 testLatOut = 1
	 system.setControl(testLatControl, testLatOut, 0)
	 dt = now - testLatTime
	 if not testLatMin then testLatMin = dt testLatMax = dt testLatRun = dt end
	 print("match < 1.5", dt)
	 testLatTime = now
	 if dt < testLatMin then testLatMin = dt end
	 if dt > testLatMax then testLatMax = dt end
	 testLatRun = testLatRun + (dt - testLatRun)/100 
      end
   end
   

   --]]
   
   -- read heading here if GPS sensor has one
   local hdg
   
   sensor = system.getSensorByID(RTH.settings.hdgId, RTH.settings.hdgPa)
   if sensor and sensor.valid then
      hdg = sensor.value
   end

   rollVal = 0
   sensor = system.getSensorByID(RTH.settings.rollId, RTH.settings.rollPa)
   if sensor and sensor.valid then
     rollVal = sensor.value
   end
   
   pitchVal = 0
   sensor = system.getSensorByID(RTH.settings.pitchId, RTH.settings.pitchPa)
   if sensor and sensor.valid then
     pitchVal = sensor.value
   end

   local gs = RTH.settings
   local compHdg
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      if RTH.curPos then
	 if not RTH.lastPos then RTH.lastPos = RTH.curPos end
	 if gps.getDistance(RTH.curPos, RTH.lastPos) > MINHDGDIST then 
	    compHdg = gps.getBearing(RTH.lastPos, RTH.curPos)
	    --print(gps.getDistance(RTH.curPos, RTH.lastPos), compHdg)
	    RTH.lastPos = RTH.curPos
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
      if RTH.curPos and lt ~= 0 and lg ~= 0 and not RTH.zeroPos then
	 RTH.gpsReads = RTH.gpsReads + 1
      end
      if RTH.gpsReads > MINGPSREADS and not RTH.zeroPos then
	 system.messageBox(appName..": GPS and Alt zero set")
	 --print("DFM-Rscu: GPS and Alt zero set")
	 RTH.zeroPos = RTH.curPos
	 RTH.initPos = RTH.curPos
	 local pz, pa, pb = scanGPSFiles(RTH.zeroPos, Fields)
	 --print("scanGPS ret", pz, pa, pb)
	 if pz and pa and pb then setGPSField(pz, pa, pb) end
	 if altnow then
	    if emflag ~= 0 then
	       RTH.var.startTakeoffAlt = 0
	    else
	       RTH.var.startTakeoffAlt = altnow
	    end
	 end
	 if RscuCircleCenter then
	    RscuCircleCenter = RTH.zeroPos
	    RscuCircleInner = RTH.settings.circleMin
	    RscuCircleOuter = RTH.settings.circleMin * CMULT
	 end
      end
      if RTH.curPos and RTH.zeroPos then
	 RTH.gpsBearingFrom = gps.getBearing(RTH.curPos, RTH.zeroPos)
	 RTH.gpsBearingTo = gps.getBearing(RTH.zeroPos, RTH.curPos)
	 RTH.gpsDistance = gps.getDistance(RTH.curPos, RTH.zeroPos)
	 if hdg then
	    RTH.gpsHeading = hdg
	 else
	    if compHdg then
	       RTH.gpsHeading = compHdg
	    end
	 end
      end
   end

   -- read the switch for mixer calibration
   if RTH.settings.calSw then
      info = system.getSwitchInfo(RTH.settings.calSw)
      if info then
	 SwC = info.value
      else
	 SwC = -1
      end
   else
      SwC = -1
   end

   if lastSwC == -1 and SwC == 1 then 
      calibrating = true
      system.stopPlayback()
      system.messageBox(appName .. ": Mixer calibration active")
      system.playFile(prefix().. pathApp .. "Audio/mixercalactive.wav", AUDIO_IMMEDIATE)
   end

   if lastSwC == 1 and SwC == -1 and calibrating == true then -- just turned off
      calibrating = false
      system.stopPlayback()
      system.messageBox(appName .. ": Mixer calibration captured")
      system.playFile(prefix().. pathApp .. "Audio/mixercaldone.wav", AUDIO_IMMEDIATE)
      local si = system.getSwitchInfo(RTH.settings.elevInput)
      --print("si", si.label, si.value, si.proportional, si.assigned, si.mode)
      if si and si.proportional and si.assigned then
	 RTH.settings.maxElevGain = -100 * ( si.value)
	 system.pSave("maxElevGain", RTH.settings.maxElevGain)				       
	 system.playNumber(RTH.settings.maxElevGain, 0, "%")
      end
   end

   lastSwC = SwC

   -- read the switch for RTH steering on/off
   if RTH.settings.onoffSw then
      info = system.getSwitchInfo(RTH.settings.onoffSw)
      if info then
	 SwO = info.value
      else
	 SwO = -1
      end
   else
      SwO = -1
   end

   if lastSwO == -1 and SwO == 1 then
      system.stopPlayback()
      if RTH.gpsDistance and RTH.gpsDistance > RTH.settings.circleMin * CMULT then
	 system.playFile(prefix() .. pathApp .. "Audio/rthenabled.wav", AUDIO_IMMEDIATE)
	 --system.messageBox(appName..": Rescue enabled")
	 system.playBeep(0, 600, 200)
	 flyingOutbound = false
	 flyingToA = true
	 annSeq = 1
	 announceTime = now
	 --turnTime = now -- not working as intended due to turnon delay .. think more!
	 --set aim point on the bearing to the current a/c position, and twice the circleMax dist
	 --print("setting aimPosOutbound")
	 RTH.aimPosOutbound = gps.getDestination(RTH.zeroPos,
						 RTH.settings.circleMin * CMULT * 2,
						 RTH.gpsBearingTo)

	 RTH.aimPos0 = gps.getDestination(RTH.zeroPos,
						 RTH.settings.circleMin * CMULT,
						 RTH.gpsBearingTo)

	 RTH.aimPosA = gps.getDestination(RTH.aimPos0, RTH.settings.circleMin * CMULT,
					  RTH.gpsBearingTo + 90)
	 RTH.aimPosB = gps.getDestination(RTH.aimPos0, RTH.settings.circleMin * CMULT,
					  RTH.gpsBearingTo - 90)					  
	 RTH.settings.onoff = SwO
	 rescueOnTime = now
      else
	 system.playFile(prefix() .. pathApp .. "Audio/rthnotenabled.wav", AUDIO_IMMEDIATE)
	 --system.messageBox(appName ..": Rescue NOT enabled. Too close")
	 system.playBeep(4, 600, 200)
      end
   end

   if lastSwO == 1 and SwO == -1 then
      system.playFile(prefix() .. pathApp .. "Audio/rescuemodeoff.wav", AUDIO_IMMEDIATE)
      --system.messageBox(appName..": Rescue off")
      system.playBeep(3, 600, 200)
      flyingOutbound = false
      flyingToA = true
      RTH.settings.onoff = SwO
   end
   
   lastSwO = SwO

   -- if enabled, compute and set steering and elev controls
   -- and make announcements

   RTH.settings.steer = 0
   RTH.settings.elev = 0
   local validmix = false

   --local s1,s2,s3

   if calibrating then
      --print("calibrating", mixOut(config.Amix,-1))
      system.setControl(RTH.settings.steerCtrl, mixOut(config.Amix,-1), 1000, 1)
      system.setControl(RTH.settings.elevCtrl, mixOut(config.Emix,0), 1000, 1)
      --if RTH.settings.steerCtrl then system.setControl(RTH.settings.steerCtrl, -1, 0) end
      --if RTH.settings.elevCtrl then system.setControl(RTH.settings.elevCtrl, -1, 0) end
      validmix = true
   end

   if not rescueOnTime then rescueOnTime = now end --just in case
   
   if (RTH.settings.onoff > 0) and
      (now > (rescueOnTime + 1000*rescueOnDelay)) and
      (not calibrating) then

      --[[
      if RTH.gpsHeading and RTH.gpsBearingFrom and RTH.gpsBearingTo then
	 s1 = (-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180      
	 s2 = (-RTH.gpsHeading + RTH.gpsBearingTo + 180) % 360 - 180
	 s3 = (RTH.gpsHeading  - RTH.gpsBearingFrom + 180) % 360 - 180
	 print(s1,s2,s3)
      end
      --]]

      local holdZero = 1
      
      if RTH.settings.steerCtrl and RTH.settings.steer then

	 if RTH.gpsDistance then

	    if (RTH.settings.circStrat ~= steerMode.leftright) then
	       if RTH.gpsDistance >= RTH.settings.circleMin * CMULT then
		  if flyingOutbound then
		     system.stopPlayback()
		     system.playFile(prefix() .. pathApp .. "Audio/turninginbound.wav", AUDIO_IMMEDIATE)
		     system.playBeep(2, 600, 200)
		     --system.messageBox(appName..": Turning inbound")
		     announceTime = now + 2500 -- short delay then announce dist etc
		     turnTime = now		  
		     --annSeq = 1
		  end
		  flyingOutbound = false
	       end
	       
	       if (RTH.gpsDistance < RTH.settings.circleMin) then -- or flyingOutbound == true then
		  if flyingOutbound == false then
		     system.stopPlayback()
		     system.playFile(prefix() .. pathApp .. "Audio/turningoutbound.wav", AUDIO_IMMEDIATE)
		     system.playBeep(1, 600, 200)
		     --system.messageBox(appName ..": Turning outbound")
		     announceTime = now + 2500 -- short delay then announce dist etc
		     turnTime = now
		     --holdZero = 0.1
		     --turnTime = now - 1; nsHoldTime = 0 -- no delay on turn outbound
		  end
		  flyingOutbound = true
	       end
	       
	       if RTH.gpsHeading and RTH.gpsBearingFrom and RTH.gpsBearingTo then
		  if not flyingOutbound then
		     RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180
		  else
		     if RTH.settings.circStrat == steerMode.petals then
			RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingTo + 180) % 360 - 180
		     else
			RTH.gpsBearingOutbound = gps.getBearing(RTH.curPos, RTH.aimPosOutbound)
			RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingOutbound + 180) % 360 - 180
		     end
		  end
	       end
	    else -- left/right mode
	       if flyingToA then
		  if gps.getDistance(RTH.curPos, RTH.aimPosA) < RTH.settings.circleMin * 0.4 then
		     system.stopPlayback()
		     system.playFile(prefix() .. pathApp .. "Audio/turningaround.wav", AUDIO_IMMEDIATE)
		     system.playBeep(2, 600, 200)
		     --system.messageBox(appName..": Turning around")
		     announceTime = now + 2500 -- short delay then announce dist etc
		     --turnTime = now - 1; nsHoldTime = 0 -- no delay on turn
		     turnTime = now		  
		     flyingToA = false
		  end
	       else -- flying to B
		  if gps.getDistance(RTH.curPos, RTH.aimPosB) < RTH.settings.circleMin * 0.4 then
		     system.stopPlayback()
		     system.playFile(prefix() .. pathApp .. "Audio/turningaround.wav", AUDIO_IMMEDIATE)
		     system.playBeep(2, 600, 200)
		     --system.messageBox(appName..": Turning around")
		     announceTime = now + 2500 -- short delay then announce dist etc
		     --turnTime = now - 1; nsHoldTime = 0 -- no delay on turn
		     turnTime = now		  
		     flyingToA = true
		  end
	       end

	       if RTH.gpsHeading and RTH.gpsBearingFrom and RTH.gpsBearingTo then
		  if flyingToA then
		     RTH.gpsBearingToA = gps.getBearing(RTH.curPos, RTH.aimPosA)
		     RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingToA + 180) % 360 - 180
		  else
		     RTH.gpsBearingToB = gps.getBearing(RTH.curPos, RTH.aimPosB)
		     RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingToB + 180) % 360 - 180
		  end
	       end
	    end

	    local ns = RTH.settings.steer / 180 -- normalized to [-1..1]

	    --hold initial hard turn after turning in or out for 5 secs
	    --so turn does not flipflop

	    if not nsHoldTime then nsHoldTime = 0 end
	    
	    if (RTH.settings.turnDir ~= turnMode.random) and ((turnTime or 0) == now) then
	       if RTH.settings.turnDir == turnMode.left then
		  nsHoldVal = -1 --was ns (could be random) .. left
		  --print("hold -1")
	       else
		  nsHoldVal = 1 -- right
		  --print("hold 1")
	       end
	       nsHoldTime = now + holdZero * holdTurn * 1000
	       --print("set hold", now, now + holdTurn, now < nsHoldTime)
	    end

	    if RTH.settings.turnDir == turnMode.random then nsHoldTime = 0 end
	    
	    if (nsHoldTime ~= 0) and (now <= nsHoldTime) then
	       --print("holding", ns, nsHoldVal, now, nsHoldTime)
	       ns = nsHoldVal
	       RTH.settings.steer = ns * 180
	    else
	       nsHoldTime = 0
	    end
	    if holdZero ~= 1 then print("ns " .. ns) end
	    --print(ns, now, nsHoldTime)
	    system.setControl(RTH.settings.steerCtrl, mixOut(config.Amix,ns), 1000, 1)
	    system.setControl(RTH.settings.elevCtrl,
			      RTH.settings.maxElevGain / 100 * mixOut(config.Emix,ns), eleDelay*1000, 1)
	    validmix = true
	 end

	 --print(now, announceTime, now - announceTime)
	 --RTH.gpsBearingTo - math.deg(fieldRotation)
	 if now > announceTime  then
	    if RTH.gpsDistance and RTH.gpsDistance > MINANNDIST then 
	       if annSeq == 1 then
		  if RTH.gpsBearingTo then
		     system.playFile(prefix() .. pathApp .. "Audio/bearing.wav", AUDIO_QUEUE)
		     --playNumberInt(RTH.gpsBearingTo)
		     playNumberCompass(((RTH.gpsBearingTo - math.deg(fieldRotation)+360)%360))
		     if math.abs(fieldRotation) < 1 then
			system.playFile(prefix() .. pathApp .. "Audio/degreestrue.wav", AUDIO_QUEUE)
		     else
			system.playFile(prefix() .. pathApp .. "Audio/degrees.wav", AUDIO_QUEUE)
		     end
		  end
	       elseif annSeq == 2 then
		  if RTH.gpsDistance then
		     if RTH.settings.distUnits == 1 then --m
			system.playFile(prefix() .. pathApp .. "Audio/distance.wav", AUDIO_QUEUE)
			playNumberInt(RTH.gpsDistance)
			system.playFile(prefix() .. pathApp .. "Audio/meters.wav", AUDIO_QUEUE)
		     else
			system.playFile(prefix() .. pathApp .. "Audio/distance.wav", AUDIO_QUEUE)
			playNumberInt(RTH.gpsDistance * 3.2808)
			system.playFile(prefix() .. pathApp .. "Audio/feet.wav", AUDIO_QUEUE)
		     end
		  end
	       elseif annSeq == 3 then
		  if RTH.altitude then
		     if RTH.settings.distUnits == 1 then --m
			system.playFile(prefix() .. pathApp .. "Audio/altitude.wav", AUDIO_QUEUE)
			playNumberInt(RTH.altitude)
			system.playFile(prefix() .. pathApp .. "Audio/meters.wav", AUDIO_QUEUE)
		     else
			system.playFile(prefix() .. pathApp .. "Audio/altitude.wav", AUDIO_QUEUE)
			playNumberInt(RTH.altitude * 3.2808)
			system.playFile(prefix() .. pathApp .. "Audio/feet.wav", AUDIO_QUEUE)
		     end
		  end
	       end
	       announceTime = now + config.annDelay
	       annSeq = annSeq + 1
	       if annSeq > config.annMax then  -- allow empty slots to space anns
		  annSeq = 1
		  system.stopPlayback() -- empty queue in case backed up messages
	       end
	    --else
	       --system.playFile(prefix() .. pathApp.."Audio/flyingoutbound.wav", AUDIO_QUEUE)
	       --announceTime = now + config.annDelay * config.annMax
	    end
	 end
      end
   end
   --if for any reason mix was not done, set mix control to 0
   if not validmix then
      if RTH.settings.steerCtrl then system.setControl(RTH.settings.steerCtrl, 0, 0) end
      if RTH.settings.elevCtrl then system.setControl(RTH.settings.elevCtrl, 0, 0) end
   end

   ---[[
   if RTH.gpsBearingTo and RTH.gpsDistance then

      local x, y, ix, iy
      
      x = RTH.gpsDistance * math.sin(math.rad(RTH.gpsBearingTo))
      y = RTH.gpsDistance * math.cos(math.rad(RTH.gpsBearingTo))
      x, y = rotateXY(x, y, fieldRotation)
      ix, iy = xytopixel(x, y)

      local distXY
      if xLast then
	 distXY = math.sqrt((x-xLast)^2 + (y-yLast)^2)
	 --print("distXY", distXY)
      end

      local newpoint = false

      if RTH.renderer then dS = 5 else dS = 20 end
      
      if (not distXY) or (distXY > dS) then -- distXY in meters
	 newpoint =  true
	 ixP[iPindex] = ix
	 iyP[iPindex] = iy
	 if iPindex < iPMAX then
	    iPindex = iPindex + 1
	 else
	    iPindex = 1
	 end
      end
      local ptr = pointsToRender
      if RTH.renderer then
	 if newpoint and pointsToRender < 100 then
	    for i,_ in ipairs(magVal) do
	       local RR = RTH.renderer[i]
	       if pointsToRender == 0 then RR:reset() end
	       ix, iy = xytopixel(x, y, i)
	       if ixL[i] then
		  if pointsToRender == 0 then
		     RR:addPoint(ixL[i], iyL[i])
		  end
		  RR:addPoint(ix, iy)
		  --RR:renderPolyline(2) -- only in tele function
	       end
	       ixL[i] = ix
	       iyL[i] = iy
	    end
	    pointsToRender = pointsToRender + 1
	    --xLast = x
	    --yLast = y
	    --if pointsToRender > 2 then print("pointsToRender", pointsToRender) end
	 end
	 if pointsToRender == 100 and ptr == 99 then
	    system.messageBox(appName..": Flight path pts being dropped")
	 end
	 if pointsToRender >= 100 then
	    for i,_ in ipairs(magVal) do
	       ixL[i] = nil
	       xLast = nil
	    end
	 end
      end
      if newpoint then
	 xLast = x
	 yLast = y
      end
   end
   
   --]]


end

local errCnt = 0
local function loop()
   local s,e = pcall(loopP)
   if not s then
      errCnt = errCnt + 1
      if errCnt < 5 then 
	 print(appName..": Loop error - "..e)
      end
   end
end

local activeSf

local function keyPress(key)
   if activeSf ~= 2 then return end
   form.preventDefault()
   if key == KEY_ESC or key == KEY_5 then
      if RTH.settings.steerCtrl then system.setControl(RTH.settings.steerCtrl, 0, 0) end
      if RTH.settings.elevCtrl then system.setControl(RTH.settings.elevCtrl, 0, 0) end      
   end
end

local function keyPressGPS(key)
   if key == KEY_ENTER then
      if buttonSet == 1 then buttonSet = 2 elseif buttonSet == 2 then buttonSet = 1 end
      for b=1,5,1 do
	 system.setTelemetryButton(1, b, buttonText[buttonSet][b], 1)
      end
      return
   end
   
   if buttonSet == 1 then      
      if key == KEY_1 then
	 magIdx = magIdx + 1
	 if magIdx > #magVal then magIdx = #magVal end
	 setMag(magIdx)
      elseif key == KEY_2 then
	 magIdx = magIdx - 1
	 if magIdx < 1 then magIdx = 1 end
	 setMag(magIdx)
      elseif key == KEY_3 then
	 RTH.settings.circStrat = RTH.settings.circStrat + 1
	 if RTH.settings.circStrat > #inv(steerMode) then RTH.settings.circStrat = 1 end
	 system.pSave("RTHcircStrat", RTH.settings.circStrat)
      elseif key == KEY_4 then
	 RTH.settings.turnDir = RTH.settings.turnDir + 1
	 if RTH.settings.turnDir > #inv(turnMode) then RTH.settings.turnDir = 1 end
	 system.pSave("RTHturnDir", RTH.settings.turnDir)
      elseif key == KEY_5 then -- Erase ribbon
	 print("Erase ribbon")
	 RTH.ribbon[magIdx] = lcd.createImage(Screen.width, Screen.height)
	 RTH.renderer[magIdx] = lcd.renderer(RTH.ribbon[magIdx])
      end
   else
      if key == KEY_1 then -- Pt A
	 if emflag == 1 then
	    print("Emulator: BDS Pt A")
	    local BDALat = 41.339794
	    local BDALng = -74.431617
	    pointA = gps.newPoint(BDALat, BDALng)
	 else
	    if not RTH.curPos then
	       system.messageBox(appName..": no current GPS position")
	       return
	    end
	    pointA = RTH.curPos
	 end
	 -- reset any prior rotation and offset .. back to initial state but curPos as origin
	 pointB = nil
	 pointZ = nil
	 RTH.zeroPos = pointA
	 fieldRotation = 0
	 for i,_ in ipairs(magVal) do
	    xmin[i] = - magVal[i] * initHalfWid
	    xmax[i] = magVal[i] * initHalfWid
	    ymin[i] = -Screen.height / Screen.width * magVal[i] * initHalfWid
	    ymax[i] = Screen.height / Screen.width * magVal[i] * initHalfWid
	 end

      elseif key == KEY_2 then -- Pt B
	 if emflag == 1 then
	    print("Emulator: BDS Pt B")
	    local BDBLat = 41.339474
	    local BDBLng = -74.431536
	    pointB = gps.newPoint(BDBLat, BDBLng)
	 else
	    if not pointA then
	       system.messageBox(appName..": enter Pt A first")
	       return
	    end
	    if not RTH.curPos then
	       system.messageBox(appName..": no current GPS position")
	       return
	    end
	    distAB = gps.getDistance(pointA, RTH.curPos)
	    -- assume 5 m along rwy is enought to get a good rotation angle
	    if distAB < 5 then
	       system.messageBox(appName..": too close for Pt B")
	       return
	    end
	    pointB = RTH.curPos
	    RTH.zeroPos = pointA
	 end

	 if not RTH.curPos then
	    system.messageBox("No GPS data")
	    return
	 end

	 if not pointA then
	    system.messageBox("Enter Pt A first")
	    return
	 end

	 setGPSField(RTH.zeroPos, pointA, pointB)
	 
      end -- end pointB
   end
end

local function initForm(subform)

   
   activeSf = subform

   local function onoffChanged(value)
      RTH.settings.onoffSw = value
      system.pSave("RTHonoffSw", RTH.settings.onoffSw)
   end

   local function calChanged(value)
      RTH.settings.calSw = value
      system.pSave("RTHcalSw", RTH.settings.calSw)
   end

   local function ecChanged(value)
      local si = system.getSwitchInfo(value)
      --print("si", si.label, si.value, si.proportional, si.assigned, si.mode)
      if not si.proportional then
	 system.messageBox("Elevator control must be proportional")
	 RTH.settings.elevInput = nil
	 form.reinit(1)
      else
	 RTH.settings.elevInput = value
	 system.pSave("elevInput", value)
      end
   end

   local function egChanged(value)
      RTH.settings.maxElevGain = value
      system.pSave("maxElevGain", value)
   end
   
   if subform == 1 then

      form.addRow(1)
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(10) end), {label="App Settings", font=FONT_NORMAL})
      
      form.addRow(1)
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(11) end), {label="Rescue Settings", font=FONT_NORMAL})
      
      form.addRow(1)
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(12) end), {label="Telemetry Sensors", font=FONT_NORMAL})
      
      form.addRow(1)
      form.addLink((function()
	       savedRow = form.getFocusedRow()	       
	       form.reinit(13) end), {label="Field Settings", font=FONT_NORMAL})

      if savedRow then
	 --print("setting FocusedRow", savedRow)
	 form.setFocusedRow(savedRow)
      end

   elseif subform == 10 then

      form.addRow(2)
      form.addLabel({label="Rescue mode switch", width=155, font=FONT_NORMAL})
      form.addInputbox(RTH.settings.onoffSw, true, onoffChanged, {alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Mixer calibration switch", width=175, font=FONT_NORMAL})
      form.addInputbox(RTH.settings.calSw, true, calChanged,
		       {width=155, font=FONT_NORMAL, alignRight=false})
      
      
      form.addRow(2)
      form.addLabel({label="Elevator control", width=180, font=FONT_NORMAL})   
      form.addInputbox(RTH.settings.elevInput, true, ecChanged,
		       {width=155, font=FONT_NORMAL, alignRight=false})
      
      
      form.addRow(2)
      form.addLabel({label="Elevator mix percentage", font=FONT_NORMAL})   
      form.addIntbox(RTH.settings.maxElevGain, -100, 100, 0, 0, 1, egChanged,
		     {width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Distance units", font=FONT_NORMAL})
      form.addSelectbox({"m", "ft"}, RTH.settings.distUnits, true,
	 (function(i)
	       RTH.settings.distUnits = i
	       system.pSave("RTHdistUnits", RTH.settings.distUnits)
	       return end),
	 {width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(1)
      form.addLink((function()
	       form.reinit(1) end), {label="<<<Back to main menu", font=FONT_NORMAL})
      

   elseif subform == 11 then
      form.addRow(2)
      form.addLabel({label="Circling behavior", font=FONT_NORMAL})
      form.addSelectbox(inv(steerMode),
			RTH.settings.circStrat, true,
			(function(i)
			      RTH.settings.circStrat = i
			      system.pSave("RTHcircStrat", RTH.settings.circStrat)
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Perferred turn", font=FONT_NORMAL, width=155})
      form.addSelectbox(inv(turnMode),
			RTH.settings.turnDir, true,
			(function(i)
			      RTH.settings.turnDir = i
			      system.pSave("RTHturnDir", RTH.settings.turnDir)
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Rescue On Delay (s)", font=FONT_NORMAL})
      form.addIntbox(rescueOnDelay, 0, 10, 3, 0, 1,
		     (function(x)
			   rescueOnDelay = x
			   system.pSave("rescueOnDelay", x)
			   return end),
		     {width=155, font=FONT_NORMAL, algignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Init turn hold time (s)", font=FONT_NORMAL})
      form.addIntbox(holdTurn, 0, 10, 3, 0, 1,
		     (function(x)
			   holdTurn = x
			   system.pSave("holdTurn", x)
			   return end),
		     {width=155, font=FONT_NORMAL, algignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Elev control delay (s)", font=FONT_NORMAL})
      form.addIntbox(eleDelay, 0, 20, 2, 0, 1,
		     (function(x)
			   eleDelay = x
			   system.pSave("eleDelay", x)
			   return end),
		     {width=155, font=FONT_NORMAL, algignRight=false})

      form.addRow(1)
      form.addLink((function()
	       form.reinit(1) end), {label="<<<Back to main menu", font=FONT_NORMAL})
      
   elseif subform == 12 then
      
      local latsel = 0
      local lngsel = 0
      local altsel = 0
      local hdgsel = 0
      local rollsel = 0
      local pitchsel = 0

      for k = 1, #RTH.gpsLalist do
	 if (RTH.gpsIdlist[k] == RTH.settings.latId) and
	    (RTH.gpsPalist[k] == RTH.settings.latPa) then
	    latsel = k
	 end
	 if (RTH.gpsIdlist[k] == RTH.settings.lngId) and
	    (RTH.gpsPalist[k] == RTH.settings.lngPa) then
	    lngsel = k
	 end	 
      end
      
      for k = 1, #RTH.sensorLalist do
	 if (RTH.sensorIdlist[k] == RTH.settings.altId) and
	    (RTH.sensorPalist[k] == RTH.settings.altPa) then
	    altsel = k
	 end
	 if (RTH.sensorIdlist[k] == RTH.settings.hdgId) and
	    (RTH.sensorPalist[k] == RTH.settings.hdgPa) then
	    hdgsel = k
	 end
	 if (RTH.sensorIdlist[k] == RTH.settings.rollId) and
	    (RTH.sensorPalist[k] == RTH.settings.rollPa) then
	    rollsel = k
	 end
	 if (RTH.sensorIdlist[k] == RTH.settings.pitchId) and
	    (RTH.sensorPalist[k] == RTH.settings.pitchPa) then
	    pitchsel = k
	 end
      end

      form.addRow(2)
      form.addLabel({label="GPS Lat Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.gpsLalist, latsel, true,
			(function(i)
			      RTH.settings.latId = RTH.gpsIdlist[i]
			      RTH.settings.latPa = RTH.gpsPalist[i]
			      system.pSave("RTHlatId", RTH.settings.latId)
			      system.pSave("RTHlatPa", RTH.settings.latPa)
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="GPS Lng Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.gpsLalist, lngsel, true,
			(function(i)
			      RTH.settings.lngId = RTH.gpsIdlist[i]
			      RTH.settings.lngPa = RTH.gpsPalist[i]			      
			      system.pSave("RTHlngId", RTH.settings.lngId)
			      system.pSave("RTHlngPa", RTH.settings.lngPa)
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Heading Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.sensorLalist, hdgsel, true,
			(function(i)
			      RTH.settings.hdgId = RTH.sensorIdlist[i]
			      RTH.settings.hdgPa = RTH.sensorPalist[i]
			      system.pSave("RTHhdgId", RTH.settings.hdgId)
			      system.pSave("RTHhdgPa", RTH.settings.hdgPa)			   
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Altitude Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.sensorLalist, altsel, true,
			(function(i)
			      RTH.settings.altId = RTH.sensorIdlist[i]
			      RTH.settings.altPa = RTH.sensorPalist[i]
			      system.pSave("RTHaltId", RTH.settings.altId)
			      system.pSave("RTHaltPa", RTH.settings.altPa)			   
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Roll Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.sensorLalist, rollsel, true,
			(function(i)
			      RTH.settings.rollId = RTH.sensorIdlist[i]
			      RTH.settings.rollPa = RTH.sensorPalist[i]
			      system.pSave("RTHrollId", RTH.settings.rollId)
			      system.pSave("RTHrollPa", RTH.settings.rollPa)			   
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Pitch Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.sensorLalist, pitchsel, true,
			(function(i)
			      RTH.settings.pitchId = RTH.sensorIdlist[i]
			      RTH.settings.pitchPa = RTH.sensorPalist[i]
			      system.pSave("RTHpitchId", RTH.settings.pitchId)
			      system.pSave("RTHpitchPa", RTH.settings.pitchPa)			   
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(1)
      form.addLink((function()
	       form.reinit(1) end), {label="<<<Back to main menu", font=FONT_NORMAL})

   elseif subform == 13 then
      form.addRow(2)
      form.addLabel({label="Min Circling Dist (m)", font=FONT_NORMAL})
      form.addIntbox(RTH.settings.circleMin, 0, 10000, 100, 0, 1,
		     (function(x)
			   RTH.settings.circleMin = x
			   system.pSave("circleMin", x)
			   if RscuCircleInner then
			      RscuCircleInner = x
			      RscuCircleOuter = x * CMULT
			   end
			   return end),
		     {width=155, font=FONT_NORMAL, algignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Map zoom level", font=FONT_NORMAL})
      form.addIntbox(magIdx, 1, #magVal, 1, 0, 1,
		     (function(x)
			   magIdx = x
			   system.pSave("magIdx", magIdx)
			   return end),
		     {width=155, font=FONT_NORMAL, algignRight=false})
      
      form.addRow(1)
      form.addLink((function()
	       local save = buttonSet
	       buttonSet = 2
	       keyPressGPS(KEY_1)
	       buttonSet = save
	       form.reinit(1) end), {label="Set Point A", font=FONT_NORMAL})
      
      form.addRow(1)
      form.addLink((function()
	       local save = buttonSet
	       buttonSet = 2
	       keyPressGPS(KEY_2)
	       buttonSet = save
	       form.reinit(1) end), {label="Set Point B", font=FONT_NORMAL})
      
      form.addRow(1)
      form.addLink((function()
	       form.reinit(1) end), {label="<<<Back to main menu", font=FONT_NORMAL})
   end
   
   


   



end

local function drawShape(col, row, shape, rotation, mag)
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   renShape:reset()
   for _, point in pairs(shape) do
      renShape:addPoint(
	 col + mag*(point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + mag*(point[1] * sinShape + point[2] * cosShape + 0.5)
      )
   end
   renShape:renderPolygon()
end

local function drawLine(col, row, shape, rotation, lw)
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   renShape:reset()
   for _, point in pairs(shape) do
      renShape:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      )
   end
   renShape:renderPolyline(lw)
end

local function printForm()
   if pointsToRender > 2 then
      lcd.drawText(10, Screen.height - 60, "Flight points cached: "..pointsToRender.."/100", FONT_NORMAL)
   end
end

local function destroy()

end


local function printTeleMix()

   local x0,y0 = Screen.width - 100, 5
   local xl, yl = 1.23*80, 80
   local min, max = -100, 100
   
   local function xp(val)
      return x0 + xl * (val - min) / (max - min)
   end

   local function yp(val)
      return 130  - (y0 + yl * (val - min) / (max - min))
   end
   
   if not RTH.settings.steerCtrl or not RTH.settings.steer then
      lcd.drawText(5, 2, "No steering value", FONT_NORMAL)
      return
   end

   --print("steer", RTH.settings.steer)
   local ns = RTH.settings.steer / 180.0
   local am = mixOut(config.Amix, ns)
   local em = RTH.settings.maxElevGain / 100 * mixOut(config.Emix, ns)

   for i=2,#config.Amix.points,1 do
      lcd.setColor(0,0,255)
      lcd.drawLine(xp(config.Amix.points[i-1].x), yp(config.Amix.points[i-1].y),
		   xp(config.Amix.points[i].x), yp(config.Amix.points[i].y))
      lcd.setColor(255,0,0)
      lcd.drawLine(xp(config.Emix.points[i-1].x),
		   yp(RTH.settings.maxElevGain / 100 * config.Emix.points[i-1].y),
		   xp(config.Emix.points[i].x),
		   yp(RTH.settings.maxElevGain / 100 * config.Emix.points[i].y))

      lcd.setColor(0,0,255)
      lcd.drawCircle(xp(ns * 100), yp(am * 100), 4)
      lcd.setColor(255,0,0)
      drawX(xp(ns * 100), yp(em * 100), 4)      
      lcd.setColor(0,0,0)
   end
end

local function printTeleAH()

   --local xc = 50
   --local dx = 40

   local hLineShape = {
      {-40,0},
      {40,0}
   }

   local vLineShape = {
      {-40,-30},
      {-40, 30}
   }

   local hDashShape = {
      {-40, 0},
      {-30, 0}
   }
   local pitch = pitchVal or 0 -- system.getInputs("P2") * 90 -- pitchVal or 0 
   local roll = rollVal or 0 --system.getInputs("P3") * 180 -- rollVal or 0

   --print(roll)
   --print(pitch)
   drawLine(50, 85, hLineShape, math.rad(roll), 2)
   drawLine(50, 85, hLineShape, 0, 1)
   drawLine(50, 85, vLineShape, 0, 1)
   drawLine(50, 85 - pitch, hDashShape, 0, 2)
   
end

--[[
local function printTeleAHFancy()
   
   local HP = require 'DFM-Rscu/hp1345a'
   local function drawPitch(rr, roll, pitch, pitchR, radAH, X0, Y0, scl)

      local XH,YH,X1,X2,X3,Y1,Y2,Y3,X4,Y4
      local pp, pps
      local xxx = 70
      local XHS = 18 * radAH / xxx
      local  XHL = 40 * radAH / xxx
      local  scale = scl * radAH / xxx
      
      local sinRoll = math.sin(math.rad(-roll))
      local cosRoll = math.cos(math.rad(-roll))
      local delta = pitch % 15    
      --local ren = lcd.renderer()
      
      --for (let i = delta - 45; i < 45 + delta; i = i + 15) {

      local i = delta - 45
      repeat
	 --if (math.abs(pitch - i % 360) < 0.01) then
	 if math.abs(pitch - i) < 0.01 then
	    XH = XHL;
	 else
	    XH = XHS;
	 end
	 YH = pitchR * i                      
	 pp = pitch - i
	 pps = string.format("%d", math.floor(pp*10 + 0.5) / 10)
	 
	 X1 = -XH * cosRoll - YH * sinRoll;
	 Y1 = -XH * sinRoll + YH * cosRoll;
	 X2 = (XH - 0) * cosRoll - YH * sinRoll;
	 Y2 = (XH - 0) * sinRoll + YH * cosRoll;
	 X3 = (XH + 5) * cosRoll - (YH - 3) * sinRoll;
	 Y3 = (XH + 5) * sinRoll + (YH - 3) * cosRoll;	
	 X4 = (-XH - 18 * scale * #pps - 5) * cosRoll - (YH - 3) * sinRoll;
	 Y4 = (-XH - 18 * scale * #pps - 5) * sinRoll + (YH - 3) * cosRoll;	
	 
	 if( not ( (X1 < -radAH and X2 < -radAH) or  (X1 > radAH and X2 > radAH)
		or (Y1 < -radAH and Y2 < -radAH) or  (Y1 > radAH and Y2 > radAH) ) ) then
	    lcd.setColor(255,255,255)
	    rr:reset()
	    rr:addPoint(X0 + radAH + X1, Y0 + radAH + Y1)
	    rr:addPoint(X0 + radAH + X2, Y0 + radAH + Y2)
	    if (XH == XHL) then
	       rr:renderPolyline(2)
	    else
	       rr:renderPolyline(1)
	    end
	    
	    if (XH == XHS) then
	       HP.drawHP1345A(rr, X0 + radAH + X3, Y0 + radAH + Y3, pps, scale,
			      math.rad(roll), 2);
	       HP.drawHP1345A(rr, X0 + radAH + X4, Y0 + radAH + Y4, pps, scale,
			      math.rad(roll), 2);
	    end
	 end
	 i = i + 15
      until i >= 45 + delta
   end

   
   local pitch = pitchVal or 0 -- system.getInputs("P2") * 90 -- pitchVal or 0 
   local roll = rollVal or 0 --system.getInputs("P3") * 180 -- rollVal or 0
   --183
   local rowAH = 150 / 2 - 20; --widget.width / 2 - 20;
   local radAH = 150 / 2 - 20; --widget.width / 2 - 20;
   local pitchR = radAH / 25;

   local tanRoll
   local cosRoll
   
   local dPitch_1
   local dPitch_2

   local X0, Y0, X1, Y1, Y2, YH
   --local ren = lcd.renderer()

   if pitch >= 0 then -- heaven knows why we have to do this
      dPitch_1 = pitch % 180
   else
      dPitch_1 = -1*(-pitch % 180)
   end
   
   --print(pitch, dPitch_1)
   if (dPitch_1 > 90) then
      dPitch_1 = 180 - dPitch_1
   end
   if (roll == 270) then
      roll = 269.99;
   end
   if (roll == 90) then
      roll = 89.99;
   end
   
   cosRoll = 1 / math.cos(math.rad(roll))
   
   if (pitch > 270) then
      dPitch_1 = -dPitch_1 * pitchR * cosRoll
      dPitch_2 = radAH * cosRoll
   elseif (pitch > 180) then
      dPitch_1 = dPitch_1 * pitchR * cosRoll
      dPitch_2 = -radAH * cosRoll
   elseif (pitch > 90) then
      dPitch_1 = -dPitch_1 * pitchR * cosRoll
      dPitch_2 = -radAH * cosRoll
   else
      dPitch_1 = dPitch_1 * pitchR * cosRoll
      dPitch_2 = radAH * cosRoll
   end

   --print(dPitch_1, dPitch_2)
   
   tanRoll = -math.tan(math.rad(roll))
   
   X1 = 0
   YH = (-radAH) * tanRoll
   Y1 = YH + dPitch_1
   Y2 = YH + 1.5 * dPitch_2 
   
   -- define clipping region 
   --X0 160 Y0 79
   X0 = 50 - radAH --widget.x0 - radAH
   Y0 = 90 - radAH --widget.y0 - radAH
   lcd.setClipping(X0, Y0, 2 * radAH, 2 * radAH)
   X0 = 0
   Y0 = 0
   -- draw sky over entire box
   lcd.setColor(0,0,255)
   --lcd.setColor(widget.rgbSkyColor.r, widget.rgbSkyColor.g, widget.rgbSkyColor.b)
   lcd.drawFilledRectangle(X0, Y0, 2 * radAH + 1, 2 * radAH + 1);

   lcd.setColor(210,105,30)
   --lcd.setColor(widget.rgbLandColor.r, widget.rgbLandColor.g, widget.rgbLandColor.b)
   ren:reset()

   if (Y1 < Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
   elseif (Y1 > Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
   end

   X1 = 2 * radAH + 1
   YH = (radAH) * tanRoll
   Y1 = YH + dPitch_1
   Y2 = YH + 1.5 * dPitch_2
   
   if (Y1 < Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
   elseif (Y1 > Y2) then
      ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
      ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
   end
   ren:renderPolygon(1)
   
   lcd.setColor(255,255,255)
   lcd.drawLine(X0, Y0, X0, Y0 + 2 * radAH + 1);
   lcd.drawLine(X0 + 2 * radAH - 1, Y0, X0 + 2 * radAH - 1, Y0 + 2 * radAH - 1)
   lcd.drawLine(X0, Y0 + 2 * radAH - 1, X0 + 2 * radAH - 1, Y0 + 2 * radAH - 1)
   lcd.drawLine(X0, Y0, X0 + 2 * radAH, Y0)

   lcd.drawLine(X0 + radAH - 0.7 * radAH, Y0 + radAH, X0 + radAH - 0.2 * radAH, Y0 + radAH);
   lcd.drawLine(X0 + radAH - 0.2 * radAH, Y0 + radAH,
		X0 + radAH - 0.2 * radAH, Y0 + radAH + radAH / 10);
   lcd.drawLine(X0 + radAH + 0.7 * radAH, Y0 + radAH, X0 + radAH + 0.2 * radAH, Y0 + radAH);
   lcd.drawLine(X0 + radAH + 0.2 * radAH, Y0 + radAH,
		X0 + radAH + 0.2 * radAH, Y0 + radAH + radAH / 10);
   drawPitch(ren, roll, pitch, pitchR, radAH, X0, Y0, 0.5);
   
   lcd.resetClipping()

end
--]]

local function printTeleStatusP(w,h)

   -- Note: for two-box size: w = 223, h = 252 for 24-II, w = 151, h = 69 for legacy color TXs
   --           one-box size: w = 223, h =  55 for 24-II, w = 151, h = 24 for legacy color TXs
   
   if not RTH.gpsBearingTo then
      lcd.drawText(20, h/2, "No GPS Bearing")
      return
   end

   local nd = system.getProperty("NativeDraw")

   local font
   if h <= 24 then font = FONT_MINI else font = FONT_NORMAL end

   if h > 24 then
      lcd.drawText(21-lcd.getTextWidth(FONT_MINI, "N") / 2,
		   12 + 4 - lcd.getTextHeight(FONT_MINI, "N") / 2,
		   "N", FONT_MINI)
      
      drawShape(20, 12+4, config.arrow, -fieldRotation, 1)
      lcd.drawCircle(20, 12+4, 9)
   end
   
   local x00, y00
   x00 = nd == 1 and 20 or 10
   y00 = nd == 1 and 30 or 20

   if h <= 24 then y00 = 15 end
   lcd.drawText(x00, h - y00,
		string.format("Alt: %dm   Dist: %3dm",
			      (RTH.altitude or 0), (RTH.gpsDistance or 0)),
		font)

   local rb = math.floor(RTH.gpsBearingTo - math.deg(fieldRotation) + 0.5)
   rb = rb + 0 -- kill -0
   if rb == 0 then
      lcd.setColor(0,0,0)
   elseif rb > 0 then
      lcd.setColor(34,139,34)
   elseif rb < 0 then
      lcd.setColor(255,0,0)
   end

   local x0
   x0 = nd == 1 and 18 or 18
   local y0
   y0 = nd == 1 and 18 or -2

   if h <= 55 and nd == 1 then
      y0 = -28
   end

   if h <= 24 then y0 = -12 end   
   local cc = math.abs(fieldRotation) < 1 and "T" or "R"
   lcd.drawText(w/2-x0, h/2 + y0, string.format("%.3d°"..cc,
		(RTH.gpsBearingTo - math.deg(fieldRotation)+360)%360),
		font)

   if RTH.settings.onoff < 0 then
      lcd.drawImage(w-30, 8, redCircle)
   else
      lcd.drawImage(w-30, 8, greenCircle)
   end

   local mag
   
   
   mag = nd == 1 and 1.5 or 0.6
   lcd.setColor(0,0,255)
   local ofst
   ofst = nd == 1 and 25 or 15

   if math.abs(fieldRotation) < 1 then
      lcd.setColor(255,153,0)
   else
      lcd.setColor(0,0,255)
   end

   if h > 55 then
      drawShape(w/2, h/2 - ofst, config.homeshape,
		math.rad(RTH.gpsBearingTo) - fieldRotation, mag)
   end
   

   -- can render to image in this tele window or the full screen .. so long as one of them
   -- is on screen it keeps the image updated

   lcd.setColor(0,0,255)
   if RTH.renderer then
      if pointsToRender > 0 and drawRibbon then
	 for i,_ in ipairs(magVal) do
	    local RR = RTH.renderer[i]
	    RR:renderPolyline(2)
	 end
	 pointsToRender = 0
      end
   end

end


local errCntS = 0
local function printTeleStatus(w,h)
   --print("$", w,h)
   local s,e = pcall(printTeleStatusP, w, h)
   if not s then
      errCntS = errCntS + 1
      if errCntS < 5 then 
	 print(appName..": Tele Status Error - "..e)
      end
   end
end

--local count = 0

local function printTeleGPSP(w,h)

   if not RTH.gpsBearingTo then
      lcd.drawText(5,5, "No GPS signal")
      return
   end

   printTeleAH(w,h)
   printTeleMix(w,h)

   local x, y, ix, iy, ix0, iy0

   lcd.setColor(255,0,0)

   ix0, iy0 = xytopixel(0, 0)
   rc = Screen.width * RTH.settings.circleMin / (xmax[magIdx] - xmin[magIdx])
   lcd.drawCircle(ix0, iy0, rc)
   lcd.setColor(0,0,255)
   lcd.drawCircle(ix0, iy0, rc * CMULT)
   
   lcd.setColor(0,0,0)

   local function plotGPS(p1, p2, r)
      local bb, dd, xx, yy, iix, iiy
      bb = gps.getBearing(p1,p2)
      dd = gps.getDistance(p1,p2)
      xx = dd * math.sin(math.rad(bb))
      yy = dd * math.cos(math.rad(bb))
      xx,yy = rotateXY(xx, yy, fieldRotation)
      iix, iiy = xytopixel(xx, yy)
      local rad = 3
      if r then rad = r end
      drawX(iix, iiy, rad)
      lcd.drawCircle(iix, iiy, rad+1)
   end
   
   if (RTH.settings.circStrat == steerMode.racetrack or RTH.settings.circStrat == steerMode.leftright) 
      and RTH.aimPosOutbound and RTH.zeroPos and RTH.aimPosA and RTH.aimPosB then

      plotGPS(RTH.zeroPos, RTH.aimPosOutbound, 5)
      plotGPS(RTH.zeroPos, RTH.aimPosA)
      plotGPS(RTH.zeroPos, RTH.aimPosB)

      if pointA then lcd.setColor(255,0,0) plotGPS(RTH.zeroPos, pointA) end
      if pointB then lcd.setColor(0,255,0) plotGPS(RTH.zeroPos, pointB) end
      if pointZ then lcd.setColor(0,0,255) plotGPS(RTH.zeroPos, pointZ) end
      
   end

   if not RTH.gpsHeading or not RTH.gpsDistance or not RTH.gpsBearingTo then return end
   
   drawRibbon = true

   lcd.setColor(0,0,255)
   
   if RTH.renderer then
      if pointsToRender > 0 and drawRibbon then
	 for i,_ in ipairs(magVal) do
	    local RR = RTH.renderer[i]
	    RR:renderPolyline(2)
	 end
	 pointsToRender = 0
      end
      lcd.drawImage(0,0,RTH.ribbon[magIdx])
   else
      --print("not renderer", #ixP, ixP[1], iyP[1])
      for i=1, #ixP, 1 do
	 lcd.drawCircle(ixP[i], iyP[i], 1)
      end
   end


   if RTH.renderer then
      lcd.drawImage(0,0,RTH.ribbon[magIdx])
   else
      lcd.setColor(0,0,0)
      for i=1, #ixP, 1 do
	 --if i == 1 then print("Loop 1", ixP[1]) end
	 lcd.drawCircle(ixP[i], iyP[i], 1)
      end
   end
   
   x = RTH.gpsDistance * math.sin(math.rad(RTH.gpsBearingTo))
   y = RTH.gpsDistance * math.cos(math.rad(RTH.gpsBearingTo))
   x,y = rotateXY(x, y, fieldRotation)
   ix, iy = xytopixel(x, y)

   
   if RTH.settings.onoff < 1 then
      lcd.setColor(0,255,0)
   else
      if flyingOutbound then lcd.setColor(255,0,0) else lcd.setColor(0,0,255) end
   end

   local mag = 1.8
   if not RTH.renderer then mag = 1.2 end
   
   drawShape(ix,iy, config.Glider, math.rad(RTH.gpsHeading or 0) - fieldRotation, mag) 

   lcd.setColor(0,0,0)
   ix0 , iy0 = xytopixel(0, 0)
   lcd.drawCircle(ix0, iy0, 2)
   
   lcd.drawText(40, 5, string.format("[%d,%d,%d,%d]   steer: %s  turn: %s",
				      math.floor(xmin[magIdx] + 0.5),
				      math.floor(xmax[magIdx] + 0.5),
				      math.floor(ymin[magIdx] + 0.5),
				      math.floor(ymax[magIdx] + 0.5),
				      inv(steerMode)[RTH.settings.circStrat],
				      inv(turnMode)[RTH.settings.turnDir]), FONT_MINI)

   lcd.drawText(70, Screen.height - 25,
		string.format("D: %dm", RTH.gpsDistance), FONT_MINI)
   local cc = math.abs(fieldRotation) < 1 and "T" or "R"
   lcd.drawText(Screen.width - 100, Screen.height - 25,
		string.format("B: %.3d°"..cc,
			      (RTH.gpsBearingTo - math.deg(fieldRotation)+360) % 360),
		FONT_MINI)

   lcd.drawText(0, Screen.height - 25, string.format("CPU %d%%", system.getCPU()), FONT_MINI)

   lcd.drawText(21-lcd.getTextWidth(FONT_MINI, "N") / 2,
		12 + 4 - lcd.getTextHeight(FONT_MINI, "N") / 2,
		"N", FONT_MINI)
   drawShape(20, 12+4, config.arrow, -fieldRotation, 1)
   lcd.drawCircle(20, 12+4, 9)

   if RTH.renderer then -- only display on 24-II, not enought space on smaller screen
      if math.abs(fieldRotation) < 1 then
	 lcd.setColor(255,153,0)
      else
	 lcd.setColor(0,0,255)
      end
      
      drawShape(Screen.width - 60, Screen.height - 60, config.homeshape,
		math.rad(RTH.gpsBearingTo) - fieldRotation,0.8)
   end
end

local errCntT = 0
local function printTeleGPS()
   --print("$", w,h)
   local s,e = pcall(printTeleGPSP, Screen.width, Screen.height)
   if not s then
      errCntT = errCntT + 1
      if errCntT < 5 then 
	 print(appName..": Tele error - "..e)
      end
   end
end

local function logfileCB(idx)
   if idx == 1 then
      return RTH.gpsBearingFrom or 0
   elseif idx == 2 then
      return RTH.gpsBearingTo or 0      
   elseif idx == 3 then
      return 10 * (RTH.gpsDistance or 0), 1
   elseif idx == 4 then
      return RTH.gpsHeading or 0
   elseif idx == 5 then
      --print("##", RTH.settings.steer, RTH.settings.steer / 1.80)
      return (RTH.settings.steer or 0) / 1.80
   else
      return -999
   end
end



local function init()

   renShape   = lcd.renderer()
   
   system.registerForm(1, MENU_APPS, "DFM-Rscu", initForm, keyPress, printForm)
   
   local device
   device, emflag = system.getDeviceType() 
   
   system.registerTelemetry(1, "DFM-Rscu Map", 4, printTeleGPS, keyPressGPS)
   system.registerTelemetry(2, "DFM-Rscu Status", 0, printTeleStatus)
   --local buttonText =  {{"-","+","Steer","Turn","Erase"},{"Pt A","Pt B","","",""}}
   
   if system.setTelemetryButton then

      buttonSet = 1
      for b=1,5,1 do
	 system.setTelemetryButton(1, b, buttonText[buttonSet][b], 1)
      end
   else
      print(appName..": Cannot set Tele Buttons")
   end

   RTH.settings = {}
   

   RTH.settings.latId = system.pLoad("RTHlatId", 0)
   RTH.settings.latPa = system.pLoad("RTHlatPa", 0)

   RTH.settings.lngId = system.pLoad("RTHlngId", 0)
   RTH.settings.lngPa = system.pLoad("RTHlngPa", 0)

   RTH.settings.altId = system.pLoad("RTHaltId", 0)
   RTH.settings.altPa = system.pLoad("RTHaltPa", 0)

   RTH.settings.hdgId = system.pLoad("RTHhdgId", 0)
   RTH.settings.hdgPa = system.pLoad("RTHhdgPa", 0)   

   RTH.settings.rollPa = system.pLoad("RTHrollPa", 0)
   RTH.settings.rollId = system.pLoad("RTHrollId", 0)

   RTH.settings.pitchId = system.pLoad("RTHpitchId", 0)
   RTH.settings.pitchPa = system.pLoad("RTHpitchPa", 0)      

   RTH.settings.onoffSw = system.pLoad("RTHonoffSw")
   RTH.settings.calSw = system.pLoad("RTHcalSw")
   RTH.settings.elevInput = system.pLoad("elevInput")
   
   RTH.settings.distUnits = system.pLoad("RTHdistUnits", 1) -- meters is default
   RTH.settings.circStrat = system.pLoad("RTHcircStrat", steerMode.petals) -- "petals" default
   RTH.settings.turnDir = system.pLoad("RTHturnDir", turnMode.left)   -- "left" default
   
   RTH.settings.circleMin = system.pLoad("circleMin", 150)
   RTH.settings.maxElevGain = system.pLoad("maxElevGain", 0)

   readSensors(RTH)

   rescueOnDelay = system.pLoad("rescueOnDelay", 3)
   holdTurn = system.pLoad("holdTurn", 5)
   eleDelay = system.pLoad("eleDelay", 2)
   magIdx = system.pLoad("magIdx", 1)
   
   flyingOutbound = false
   calibrating = false
   
   RTH.gpsReads = 0
   RTH.curPos = nil
   RTH.zeroPos = nil

   RTH.settings.steerCtrl = nil
   local iRTS = 3
   RTH.settings.steerCtrl = system.registerControl(iRTS, "Rscu Steering", "RTS")

   RTH.settings.steer = 0
   RTH.settings.onoff = -1
   
   if RTH.settings.steerCtrl then
      print(appName ..": Steering registered to control "..RTH.settings.steerCtrl)
      system.setControl(RTH.settings.steerCtrl, RTH.settings.steer, 0)
   else
      print(appName .. ": Could not register steer control")
      system.messageBox(appName .. ": Could not register steer control")
   end

   RTH.settings.elevCtrl = nil
   local iRTE = 4
   RTH.settings.elevCtrl = system.registerControl(iRTE, "Rscu Elevator", "RTE")

   --[[
   testLatControl = system.registerControl(10, "Latency", "LAT")
   print("testLatControl", testLatControl)
   testLatOut = 1
   if not system.setControl(testLatControl, testLatOut, 0) then
      print("set control failed")
   end
   testLatTime = system.getTimeCounter()
   --]]
   
   RTH.settings.elev = 0
   
   if RTH.settings.elevCtrl then
      print(appName ..": Elevator registered to control "..RTH.settings.elevCtrl)
      system.setControl(RTH.settings.elevCtrl, RTH.settings.elev, 0)
   else
      print(appName .. ": Could not register elevator control")
      system.messageBox(appName .. ": Could not register elevator control")
   end
   
   system.registerLogVariable("RTHBrgFrom", "°", logfileCB)
   system.registerLogVariable("RTHBrgTo",   "°", logfileCB)
   system.registerLogVariable("RTHDst",     "m", logfileCB)
   system.registerLogVariable("RTHHdg",     "°", logfileCB)
   system.registerLogVariable("RTHStr",     "%", logfileCB)

   greenCircle = lcd.loadImage(prefix() .. pathApp .. "Images/small_green_circle.png")
   redCircle = lcd.loadImage(prefix() .. pathApp .. "Images/small_red_circle.png")

   local str = io.readall(prefix() .. pathApp.."Json/Config.jsn")
   if not str then
      print("DFM-Rscu: cannot read Config.jsn")
   end
   
   config = json.decode(str)

   --system.setProperty("NativeDraw", 1)
   --print("get", system.getProperty("NativeDraw"))

   system.setProperty("NativeDraw", 1)

   if system.getProperty("NativeDraw") == 1 then
      print(appName..": Using 24-II NativeDraw")
      Screen.width = 458
      Screen.height = 343
      RTH.ribbon = {}
      RTH.renderer = {}
      for i,_ in ipairs(magVal) do
	 RTH.ribbon[i] = lcd.createImage(Screen.width, Screen.height)
	 if not RTH.ribbon[i] then
	    print(appName..": Could not create ribbon image "..i)
	 end
	 if RTH.ribbon[i] then
	    RTH.renderer[i] = lcd.renderer(RTH.ribbon[i])
	 end
	 if not RTH.renderer[i] then print(appName..": Could not create renderer "..i) end
      end
      iPMAX = 2
   else
      Screen.width = 320
      Screen.height = 160
      iPMAX = 100
   end

   fieldRotation = 0

   setMag(magIdx)

   -- Set screen sizes, start at +/- initHalfWid m .. see parallel code in keyPressGPS()
   for i,_ in ipairs(magVal) do
      xmax[i] = magVal[i] * initHalfWid
      xmin[i] = -xmax[i]
      ymin[i] = -Screen.height / Screen.width * magVal[i] * initHalfWid
      ymax[i] = -ymin[i]
   end

   Fields = scanGPSFiles()
   drawRibbon = true

   if declareGlobal then
      print("setting globals")
      declareGlobal("RscuCircleCenter", 0)
      declareGlobal("RscuCircleInner", RTH.settings.circleMin)
      declareGlobal("RscuCircleOuter", RTH.settings.circleMin * CMULT)
      declareGlobal("RscuAimPoint", 0)
      dumpGlobalVars()
   end

   
end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.5", name=appName}
