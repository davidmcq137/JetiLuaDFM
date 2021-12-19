--[[

   ---------------------------------------------------------------------------------------
   DFM-Maps.lua -- GPS map display and triangle racing app

   This app displays the track of an aircraft on the TX display,
   reading a GPS telemetry device. The flight path is optionally
   overlaid on a google maps image set of the flying site. Map sets
   are created with the website www.jetiluadfm.app.  This website can
   create a dynamic repository of the app as well as all required map
   files, and download it to the TX using Jeti Studio's Lua App
   manager.

   The app can also run a GPS traingle race following a simplified set
   of the official triangle racing rules.

   DFM-Maps was orginally developed as DFM-LSO, which had a gps and
   map display capability as well as an RNAV-like landing guidance
   system. This then evolved to a triangle racing program as suggested
   by Harry Curzon which was called T-Wizard, then split into DFM-TriR
   (the racing app) and DFM-TriM (the map browser). Finally, TriR and
   TriM were combined into DFM-Maps.

   This app owes a debt to some very early ideas in Tero's RCT Alt
   announcer, the Jeti Artificial Horizon app, and the Jeti Virtual
   sensor app.

   We use a simple equirectangular projection of the map to the screen.

   Developed on DS-24, only tested on DS-24

   ---------------------------------------------------------------------------------------
   Released under MIT license by DFM 2021
   ---------------------------------------------------------------------------------------
   
   Thoughts for future releases:

   1) handle the Z dimension in tri racing. thermalling screen? Leon's thermal assist? integrate vario
   in some way?

   2) separate "no GPS fix" from "no Maps" on startup. Supply animation waiting for GPS. let the app
   operate without a map (zero point on startup, screen centered on zero since we don't have a 
   direction, use standard mag levels, and light or dark background)

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
local vario=0
local altimeter=0
local tekvario=0

local binomC = {} -- array of binomial coefficients for Bezier
local lng0, lat0, coslat0
-- rE is radius of earth in m (WGS84)
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

local telem={"Latitude", "Longitude",   "Altitude", "SpeedGPS", "Vario", "Altimeter", "TEKVario"}
telem.Latitude={}
telem.Longitude={}
telem.Altitude={}
telem.SpeedGPS={}
telem.Vario={}
telem.Altimeter={}
telem.TEKVario={}

local variables = {}

local xtable = {}
local ytable = {}
local MAXTABLE = 5
local map={}

local path={}
local bezierPath = {}

local shapes = {}
local colors = {}
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
local lastgetTime = 0
local inZone = {}
local ribbon = {}
ribbon.currentFormat = "%.f"

-- these lists are the non-GPS sensors

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units
local sensorNalist = { "..." }  -- sensor Names

-- these lists are the GPS sensors that have to be processed differently

local GPSsensorLalist = { "..." }
local GPSsensorIdlist = { "..." }
local GPSsensorPalist = { "..." }
local GPSsensorNalist = { "..." }

local checkBox = {}
local checkBoxIndex = {}
local checkBoxSubform = {}

local switchItems = {}
local lastswc = -2
local swcCount = 0

local browse = {}
browse.Idx = 1
browse.List = {}
browse.OrignalFieldName = nil
browse.FieldName = nil
browse.MapDisplayed = false
browse.opTable = {"X","Y","R","L","O"}
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
raceParam.runningStartTime = system and system.getTimeCounter() or 0
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
raceParam.usedThrottle = false
raceParam.exceedMaxAlt = false

local fieldPNG={}
local maxImage
local currentImage

local dotImage = {}

local emFlag

local auxSensors = {}
auxSensors.satCountID = 0
auxSensors.satCountPa = 0
auxSensors.satQualityID = 0
auxSensors.satQualityPa = 0
auxSensors.satCount = 0
auxSensors.satQuality = 0

local lang
local locale

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function IGC(cmd, str)

   if not checkBox.recordIGC then return end
   
   if not variables.triEnabled then return end
   
   if cmd ~= "Open" and not raceParam.IGCFile then return end
   
   local function xy2lat(n)
      local xx, yy
      local tx, ty
      local lt
      if n > 0 then
	 xx, yy = pylon[n].x, pylon[n].y
      else
	 xx, yy = tri.center.x + variables.triOffsetX, tri.center.y + variables.triOffsetY
      end
      tx, ty = rotateXY(xx, yy, -math.rad(variables.rotationAngle))
      lt = lat0 + (ty * rad) / (rE)
      return lt
   end
   
   local function xy2lng(n)
      local xx, yy
      local tx, ty
      local lg
      if n > 0 then
	 xx, yy = pylon[n].x, pylon[n].y
      else
	 xx, yy = tri.center.x + variables.triOffsetX, tri.center.y + variables.triOffsetY
      end
      tx, ty = rotateXY(xx, yy, -math.rad(variables.rotationAngle))
      lg = lng0 + (tx * rad) / (rE * coslat0)
      return lg
   end

   local function to1char(num)
      if num < 10 then
	 return tostring(num)
      elseif num < 36 then
	 return string.char(string.byte("A") + num - 9)
      else
	 return nil
      end
   end

   local function hms(dti)
      local dt
      local tt, ss, mm, ss, hh, mm
      -- emulator getDateTime() does not work correctly, fake it using system timer
      if emFlag then
	 tt = system.getTimeCounter() - raceParam.runningStartTime
	 ss = tt / 1000.0
	 mm = ss // 60.0
	 ss = math.floor(ss - mm * 60 + 0.5)
	 hh = math.floor(mm // 60.0)
	 mm = math.floor(mm - hh * 60 + 0.5)
      else
	 if dti then
	    dt = dti
	 else
	    dt = system.getDateTime()
	 end
	 hh = dt.hour
	 mm = dt.min
	 ss = dt.sec
      end
      return string.format("%02d%02d%02d", hh, mm, ss)
   end
   
   local function dmy(dti)
      local dt, str
      if not dti then
	 dt = system.getDateTime()
	 str = string.format("%02d%02d%02d", dt.day, dt.mon, dt.year % 100)      	 
      else
	 str = string.format("%02d%02d%02d", dti.day, dti.mon, dti.year % 100)      	 	 
      end
      return str
   end

   local function ll2dms(ll)
      local deg, min = math.modf(ll)
      min = min * 60
      return deg, math.floor(min*1000)
   end
   
   local function IGClat(lat)
      local dir
      local deg, min
      if lat < 0 then dir = "S" else dir = "N" end
      deg, min = ll2dms(math.abs(lat))
      return string.format("%02d%05d%s", deg, min, dir)
   end

   local function IGClng(lng)
      local dir
      local deg, min
      if lng < 0 then dir = "W" else dir = "E" end
      deg, min = ll2dms(math.abs(lng))
      return string.format("%03d%05d%s", deg, min, dir)
   end


   --following code adapted from
   --https://github.com/cloudwu/skynet/blob/master/lualib/skynet/db/redis/crc16.lua

   local XMODEMCRC16Lookup = {
      0x0000,0x1021,0x2042,0x3063,0x4084,0x50a5,0x60c6,0x70e7,
      0x8108,0x9129,0xa14a,0xb16b,0xc18c,0xd1ad,0xe1ce,0xf1ef,
      0x1231,0x0210,0x3273,0x2252,0x52b5,0x4294,0x72f7,0x62d6,
      0x9339,0x8318,0xb37b,0xa35a,0xd3bd,0xc39c,0xf3ff,0xe3de,
      0x2462,0x3443,0x0420,0x1401,0x64e6,0x74c7,0x44a4,0x5485,
      0xa56a,0xb54b,0x8528,0x9509,0xe5ee,0xf5cf,0xc5ac,0xd58d,
      0x3653,0x2672,0x1611,0x0630,0x76d7,0x66f6,0x5695,0x46b4,
      0xb75b,0xa77a,0x9719,0x8738,0xf7df,0xe7fe,0xd79d,0xc7bc,
      0x48c4,0x58e5,0x6886,0x78a7,0x0840,0x1861,0x2802,0x3823,
      0xc9cc,0xd9ed,0xe98e,0xf9af,0x8948,0x9969,0xa90a,0xb92b,
      0x5af5,0x4ad4,0x7ab7,0x6a96,0x1a71,0x0a50,0x3a33,0x2a12,
      0xdbfd,0xcbdc,0xfbbf,0xeb9e,0x9b79,0x8b58,0xbb3b,0xab1a,
      0x6ca6,0x7c87,0x4ce4,0x5cc5,0x2c22,0x3c03,0x0c60,0x1c41,
      0xedae,0xfd8f,0xcdec,0xddcd,0xad2a,0xbd0b,0x8d68,0x9d49,
      0x7e97,0x6eb6,0x5ed5,0x4ef4,0x3e13,0x2e32,0x1e51,0x0e70,
      0xff9f,0xefbe,0xdfdd,0xcffc,0xbf1b,0xaf3a,0x9f59,0x8f78,
      0x9188,0x81a9,0xb1ca,0xa1eb,0xd10c,0xc12d,0xf14e,0xe16f,
      0x1080,0x00a1,0x30c2,0x20e3,0x5004,0x4025,0x7046,0x6067,
      0x83b9,0x9398,0xa3fb,0xb3da,0xc33d,0xd31c,0xe37f,0xf35e,
      0x02b1,0x1290,0x22f3,0x32d2,0x4235,0x5214,0x6277,0x7256,
      0xb5ea,0xa5cb,0x95a8,0x8589,0xf56e,0xe54f,0xd52c,0xc50d,
      0x34e2,0x24c3,0x14a0,0x0481,0x7466,0x6447,0x5424,0x4405,
      0xa7db,0xb7fa,0x8799,0x97b8,0xe75f,0xf77e,0xc71d,0xd73c,
      0x26d3,0x36f2,0x0691,0x16b0,0x6657,0x7676,0x4615,0x5634,
      0xd94c,0xc96d,0xf90e,0xe92f,0x99c8,0x89e9,0xb98a,0xa9ab,
      0x5844,0x4865,0x7806,0x6827,0x18c0,0x08e1,0x3882,0x28a3,
      0xcb7d,0xdb5c,0xeb3f,0xfb1e,0x8bf9,0x9bd8,0xabbb,0xbb9a,
      0x4a75,0x5a54,0x6a37,0x7a16,0x0af1,0x1ad0,0x2ab3,0x3a92,
      0xfd2e,0xed0f,0xdd6c,0xcd4d,0xbdaa,0xad8b,0x9de8,0x8dc9,
      0x7c26,0x6c07,0x5c64,0x4c45,0x3ca2,0x2c83,0x1ce0,0x0cc1,
      0xef1f,0xff3e,0xcf5d,0xdf7c,0xaf9b,0xbfba,0x8fd9,0x9ff8,
      0x6e17,0x7e36,0x4e55,0x5e74,0x2e93,0x3eb2,0x0ed1,0x1ef0
   }
   
   local function crc16init()
      raceParam.crc16 = {0,0,0,0,0,0}
   end
   
   local function crc16add(str)
      -- compute a crc16 for columns 1-10, 11-20, 21-30, 31-40, 41-50, 51-60
      local b
      local crc = raceParam.crc16
      for j=1, 6 do
	 for i=(j-1)*10+1,j*10  do
	    b = string.byte(str,i,i) or 0
	    crc[j] = ((crc[j]<<8) & 0xffff) ~ XMODEMCRC16Lookup[(((crc[j]>>8)~b) & 0xff) + 1]
	    --print(str)
	    --print(string.format("%04X|%04X|%04X|%04X|%04X|%04X",
				--crc[1], crc[2], crc[3], crc[4], crc[5], crc[6]))
	 end
      end
      return
   end

   local function crc16final()
      local crc = raceParam.crc16
      local r = string.format("%04X", crc[1])
      for i=2,6 do
	 r = r .. string.format("%04X", crc[i])
      end
      return r
   end

   local function IGCw(str)
      if raceParam.IGCFile then
	 --print("IGCw <" .. str .. ">")
	 crc16add(str)
	 io.write(raceParam.IGCFile, str .."\r\n")
      end
   end
   
   -- I05 3637SIU 3840GSP 4143ENL 4446SUS 4751VAR 5256VAT
   
   local function IGCb()
      --print("IGCb altitude", altitude)
      IGCw("B".. hms() .. IGClat(latitude) .. IGClng(longitude) ..
	      "A"   .. string.format("%05d", altimeter) .. string.format("%05d", altitude) ..
	      "00"  .. string.format("%03d", SpeedGPS) .. "000" ..
	      "000" .. string.format("%05d", vario) .. string.format("%05d", tekvario)
      )
   end
   
   if cmd == "Open" then
      -- work from TX system date for now, should be UTC later
      -- filename format is YMDCXXXF.IGC
      -- https://xp-soaring.github.io/igc_file_format/igc_format_2008.html#link_4.5
      local dt = system.getDateTime()
      --print("dt", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec)
      local yy = string.format("%04d", dt.year)
      local mm = string.format("%02d", dt.mon)
      local dd = string.format("%02d", dt.day)
      local ssn = system.getSerialCode()
      local sn = string.sub(ssn, -3)

      local fname
      for i=1, 35, 1 do
	 fname = yy .. "-" .. dd .. "-" .. mm .. "-XDM-" .. sn .. "-" ..string.format("%02d", i) .. ".igc"
	 --print("fname: " .. fname)
	 local fr = io.open(appInfo.Dir .. "IGC/" .. fname, "r")
	 if fr then
	    io.close(fr)
	 else
	    raceParam.IGCFile = io.open(appInfo.Dir .. "IGC/" .. fname, "w")
	    if raceParam.IGCFile then
	       print(appInfo.Name .. ": Opening igc file " .. appInfo.Dir .. "IGC/" .. fname)
	       crc16init()
	       break
	    else
	       print(appInfo.Name .. ": Cannot open igc file")
	       return
	    end
	 end
      end

      IGCw( "AXDM"..sn)

      IGCw( "HFDTE" ..dmy(dt))
      IGCw( "HFPLTPILOTINCHARGE:" .. system.getUserName())
      IGCw( "HFCM2CREW2:" .. system.getDeviceType())
      IGCw( "HFGTYGLIDERTYPE:" .. system.getProperty("Model"))
      IGCw( "HFGIDGLIDERID:" .. system.getProperty("ModelFile"))
      IGCw( "HSCIDCOMPETITIONID:NA")
      IGCw( "HFDTMGPSDATUM:WG84")
      local txt
      if GPSsensorNalist[telem.Latitude.Se] and GPSsensorLalist[telem.Latitude.Se] then
	 txt = GPSsensorNalist[telem.Latitude.Se] .. "." .. GPSsensorLalist[telem.Latitude.Se]
      else
	 txt = "NA"
      end
      IGCw( "HFGPSRECEIVER:".. txt)
      if sensorNalist[telem.Altimeter.Se] and sensorLalist[telem.Altimeter.Se] then
	 txt = sensorNalist[telem.Altimeter.Se] .. "." .. sensorLalist[telem.Altimeter.Se]
      else
	 txt = "NA"
      end
      IGCw("HFPRSPRESSALTSENSOR:" .. txt)
      IGCw("HFRDEVICESN:".. ssn)
      IGCw("HFRFWFIRMWAREVERSION:0")
      IGCw("HFRHWHARDWAREVERSION:0")
      IGCw("HFFTYFRTYPE:DFM-Maps")
      IGCw("HFRLOGGERVERSION:1")
     
      IGCw("I053637SIU3840GSP4143ENL4446SUS4751VAR5256VAT")

      IGCw("LPilotID:" .. system.getUserName())
      IGCw("LProotocolVersion02.0")
      IGCw("LTSK:V:02.0")

      if pylon and #pylon == 3 and tri and #tri == 3 and tri.center and tri.center.x then
	 IGCw("C" .. dmy(dt) .. hms(dt) .. "10000000000003Gps Triangle")
	 IGCw("C" .. IGClat(xy2lat(0)) .. IGClng(xy2lng(0)) .. Field.shortname)
	 IGCw("C" .. IGClat(xy2lat(0)) .. IGClng(xy2lng(0)) .. "Start")      
	 IGCw("C" .. IGClat(xy2lat(1)) .. IGClng(xy2lng(1)) .. "Pylon 1")
	 IGCw("C" .. IGClat(xy2lat(2)) .. IGClng(xy2lng(2)) .. "Pylon 2")
	 IGCw("C" .. IGClat(xy2lat(3)) .. IGClng(xy2lng(3)) .. "Pylon 3")      
	 IGCw("C" .. IGClat(xy2lat(0)) .. IGClng(xy2lng(0)) .. "Finish")
	 IGCw("C" .. IGClat(xy2lat(0)) .. IGClng(xy2lng(0)) .. Field.shortname)      
      else
	 IGCw("C" .. dmy(dt) .. hms(dt) .. "10000000000000")
	 IGCw("C" .. IGClat(lat0 or 0) .. IGClng(lng0 or 0) .. Field.shortname)	 
	 IGCw("C" .. IGClat(lat0 or 0) .. IGClng(lng0 or 0) .. "Start")
	 IGCw("C" .. IGClat(lat0 or 0) .. IGClng(lng0 or 0) .. "Finish")
	 IGCw("C" .. IGClat(lat0 or 0) .. IGClng(lng0 or 0) .. Field.shortname)
      end
      
   elseif cmd == "Close"   then
      --print("Close - raceParam.IGCFile:", raceParam.IGCFile)
      if raceParam.IGCFile then
	 IGCw("G" .. crc16final() .. "\r\n")
	 io.close(raceParam.IGCFile)
      end
      raceParam.IGCFile = nil
   elseif cmd == "Brecord" then
      IGCb()
   elseif cmd == "Erecord" then
      IGCw("E"..hms()..str)
      IGCb()
   elseif cmd == "Lrecord" then
      IGCw("L"..hms()..str)
      IGCb()
   else
   end
   
end

local function setLanguage()

   local obj
   local fp
   local transFile

   locale = system.getLocale()

   --locale = "de" ------------------------------- TEST ------------------------
   
   transFile = appInfo.Dir .. "Lang/" .. locale .. "/Text/Text.jsn"
   fp = io.readall(transFile)

   
   --print("DFM-Maps: locale " .. locale)

   if not fp then
      system.messageBox("DFM-Maps: No Tranlation for locale " .. locale)
      print("DFM-Maps: No Tranlation for locale " .. locale)      
      -- try for English if no locale support
      locale = "en"
      transFile = appInfo.Dir .."Lang/" .. locale .. "/Text/Text.jsn"
      fp = io.readall(transFile)
      if not fp then
	 error("DFM-Maps: FATAL - Could not open language file")
      else
	 print("DFM-Maps: Using locale en")
      end
   end

   lang = json.decode(fp)

   if not lang then
      error("DFM-Maps: FATAL - Could not decode language file")
   end

end

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
   ribbon.currentValue  = inval
   if mod then val = (inval-1) % mod + 1 else val = inval end
   bin = math.floor(((bins - 1) * math.max(math.min((val - min) / (max-min),1),0) + 1) + 0.5)   
   ribbon.currentBin = bin
   return bin
end

local function kFilename()
   return appInfo.Dir .. "MF-" ..
      string.gsub(system.getProperty("Model")..".jsn", " ", "_") ..
      "-" .. Field.shortname .. ".jsn"
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

   return config[var]
end

local function jSave(config, var, val)
   config[var] = val
end

local function destroy()
   if raceParam.IGCFile then
      io.close(raceParam.IGCFile)
   end
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
   local sensName = ""
   
   jt = io.readall(appInfo.Dir.."JSON/paramGPS.jsn")
   paramGPS = json.decode(jt)
   
   for i, sensor in ipairs(sensors) do
      --print("for loop:", i, sensor.sensorName, sensor.label, sensor.param, sensor.type)
      if (sensor.label ~= "") then
	 if sensor.param == 0 then -- it's a label
	    sensName = sensor.label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)
	    table.insert(sensorUnlist, 0)
	    table.insert(sensorNalist, 0)
	 elseif sensor.type == 9 then  -- lat/long
	    --print("inserting", sensor.param, sensor.label)
	    table.insert(GPSsensorLalist, sensor.label)
	    seSeq = #GPSsensorLalist
	    table.insert(GPSsensorIdlist, sensor.id)
	    table.insert(GPSsensorPalist, sensor.param)
	    table.insert(GPSsensorNalist, sensName)
	 elseif sensor.type == 5 then -- date - ignore
	 else -- regular numeric sensor
	    table.insert(sensorLalist, sensor.label)
	    seSeq = #sensorLalist
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	    table.insert(sensorNalist, sensName)
	    --print("sensorNalist", #sensorNalist, sensName, sensor.label,sensor.param, sensor.unit)
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
		  auxSensors.satCountID = sensor.id
		  auxSensors.satCountPa = param
	       elseif label == "SatQuality" then
		  auxSensors.satQualityID = sensor.id
		  auxSensors.satQualityPa = param
	       elseif label == "Altitude" then

		  if paramGPS and paramGPS[sensor.sensorName][sensor.label].AltType == "Rel" then
		     variables.absAltGPS = false
		  else
		     variables.absAltGPS = true
		  end
		  telem[label].Se = seSeq
		  telem[label].SeId = sensor.id
		  telem[label].SePa = param
	       elseif telem[label] then -- check if this is one we want
		  telem.selectedGPS = sensor.sensorName
		  --print("GPS: " .. telem.selectedGPS)
		  --print("seSeq", seSeq)
		  --print("sensor.id", sensor.id)
		  --print("param", param)
		  --print("label", label)
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
   local lx, ly
   tri = {}
   pylon = {}
   if Field.triangle then
      for j=1, #Field.triangle.path, 1 do
	 tri[j] = ll2xy(Field.triangle.path[j].lat, Field.triangle.path[j].lng)
      end
      tri.center = ll2xy(Field.triangle.center.lat, Field.triangle.center.lng)
      lx = tri[1].x - tri.center.x
      ly = tri[1].y - tri.center.y
      tri[1].x = tri.center.x + (variables.triHeightScale / 100.0) * lx
      tri[1].y = tri.center.y + (variables.triHeightScale / 100.0) * ly
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

local function setColor(type, mode)
   local cc
   if type == "Map" and mode == "Image" and not fieldPNG[currentImage] then
      cc = colors["Light"]["Map"]
   else
      cc = colors[mode][type]
   end
   lcd.setColor(cc.r, cc.g, cc.b)
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

   ------------------------------------------------------------
   local triT

   local tfn = kFilename()

   local jsn = io.readall(tfn)
   
   if jsn then triT = json.decode(jsn) end

   if triT then
      variables.triOffsetX  = triT.dx or 0
      variables.triOffsetY  = triT.dy or 0
      if Field.triangle then
	 variables.triLength   = triT.L  or Field.triangle.size
	 variables.aimoff      = triT.O  or Field.triangle.size / 20
      end
      variables.triRotation = triT.r  or 0
   else
      variables.triOffsetX  = 0
      variables.triOffsetY  = 0
      if Field.triangle then
	 variables.triLength   = Field.triangle.size
	 variables.aimoff      = Field.triangle.size / 20
      end
      variables.triRotation = 0
   end

   lng0 = Field.lng -- reset to origin to coords in jsn file
   lat0  = Field.lat
   coslat0 = math.cos(math.rad(lat0))
   variables.rotationAngle  = Field.images[1].heading
   tri2XY()
   rwy2XY()
   nfz2XY()
   
   if variables.triEnabled then
      setColor("Map", variables.triColorMode)
   else
      setColor("Map", "Image")
   end
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

   jSave(variables, "telem_"..str.."_Se", value)
   jSave(variables, "telem_"..str.."_SeId", string.format("%0X", telem[str].SeId))
   jSave(variables, "telem_"..str.."_SePa", telem[str].SePa)
   
end

local function variableChanged(value, var, fcn)
   variables[var] = value
   jSave(variables, var, value)
   if fcn then fcn() end
end

local function validAnn(val, str)
   if string.find(str, val) then
      system.messageBox("Invalid Character(s)")
      return false
   else
      return true
   end
end

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
	 
   switchItems[swname] = createSw(shapes.switchNames[variables[swname .. "SwitchName"]],
		     variables[swname .."SwitchDir"])
   checkBox[swname .."Switch"] = system.getInputsVal(switchItems[swname]) == 1
end

local function triLengthChanged(value)
   variables.triLength = value
   jSave(variables, "triLength", value)
   pylon = {}
end

local function raceTimeChanged(value)
   variables.raceTime = value
   jSave(variables, "raceTime", value)
end

local function maxSpeedChanged(value)
   variables.maxSpeed = value
   jSave(variables, "maxSpeed", value)
end

local function maxAltChanged(value)
   variables.maxAlt = value
   jSave(variables, "maxAlt", value)
end

local function aimoffChanged(value)
   variables.aimoff = value
   jSave(variables, "aimoff", value)
   pylon={}
end

local function flightStartAltChanged(value)
   variables.flightStartAlt = value
   jSave(variables, "flightStartAlt", value)
end

local function flightStartSpdChanged(value)
   variables.flightStartSpd = value
   jSave(variables, "flightStartSpd", value)
end

local function elevChanged(value)
   variables.elev = value
   jSave(variables, "elev", value)
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

local function triColorModeChanged(value)
   local t = {"Light", "Dark", "Image"}
   variables.triColorMode = t[value]
   jSave(variables, "triColorMode", t[value])
end

local function airplaneIconChanged(value)
   variables.airplaneIcon = value
   --print("value, airplaneIcons[value]:", value, shapes.airplaneIcons[value])
   shapes.airplaneIcon = shapes[shapes.airplaneIcons[value]]
   jSave(variables, "airplaneIcon", value)
end

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

      local ii = 1
      for k,v in ipairs(matchFields) do
	 if variables.lastMatchField == v then ii = k end
      end
      
      setField(matchFields[ii])

      -- see if file <model_name>_icon.jsn exists
      -- if so try to read airplane icon
      
      local fg = io.readall("Apps/"..appInfo.Maps .."/JSON/"..
			       string.gsub(system.getProperty("Model")..
					      "_icon.jsn", " ", "_"))
      if fg then
	 shapes.airplaneIcon = json.decode(fg).icon
      end
   end
   
   if Field and Field.name then
      system.messageBox("Current location: " .. Field.name, 2)
      activeField = Field.shortname

      maxImage = #Field.images
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
      elseif browse.opTable[browse.opTableIdx] == "Y" then
	 variables.triOffsetY = variables.triOffsetY + -2*inc
	 browse.dispText = string.format("Y %4d", variables.triOffsetY)
	 jSave(variables, "triOffsetY", variables.triOffsetY)	 
      elseif browse.opTable[browse.opTableIdx] == "R" then
	 variables.triRotation = variables.triRotation + inc
	 browse.dispText = string.format("R %4d", variables.triRotation)
	 jSave(variables, "triRotation", variables.triRotation)	 
      elseif browse.opTable[browse.opTableIdx] == "O" then 
	 --print("variables.aimoff", variables.aimoff)
	 variables.aimoff = variables.aimoff - inc
	 browse.dispText = string.format("O %4d", variables.aimoff)
	 jSave(variables, "aimoff", variables.aimoff)	 
      else -- L (length)
	 variables.triLength = variables.triLength + -5*inc
	 browse.dispText = string.format("L %4d", variables.triLength)
	 --print("triLength:", variables.triLength)
	 jSave(variables, "triLength", variables.triLength)	 
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
	    
	    -- Save the potential changes to the triangle in a file named by both the field
	    -- AND the model so the re-reading only happens with the same combination of
	    -- model and field
	    -- finally, only save if the field just browsed is the active field

	    if Field.shortname == browse.OriginalFieldName then
	       local triT = {dx=variables.triOffsetX, dy=variables.triOffsetY,
			     r=variables.triRotation, L = variables.triLength,
			     O = variables.aimoff}
	       local tfn = kFilename()
	       --print("Saving", tfn)
	       local tft = io.open(tfn, "w")
	       if tft then io.write(tft, json.encode(triT), "\n") end
	       io.close(tft)
	    end
	    
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
      io.remove(kFilename())
      appInfo.SaveData = false
   end
end

local function checkBoxAdd(lab, box)
   
   form.addRow(2)
   form.addLabel({label=lab, width=270})
   if not checkBox[box] then checkBox[box] = variables[box] end
   checkBoxIndex[box] =
      form.addCheckbox(checkBox[box],
		       (function(z) return checkBoxClicked(z, box) end) )
end

local function selectFieldClicked(value)
   lat0 = Fields[browse.List[value]].images[1].center.lat
   lng0 = Fields[browse.List[value]].images[1].center.lng
   coslat0 = math.cos(math.rad(lat0))
   gotInitPos = true
   variables.lastMatchField = Fields[browse.List[value]].shortname
   initField(Fields[browse.List[value]].shortname)
end

local function switchAdd(lbl, swname, sf)
   form.addRow(5)
   form.addLabel({label=lbl, width=80})
   form.addSelectbox(shapes.switchNames, variables[swname .. "SwitchName"], true,
		     (function(z) return switchNameChanged(z, true, swname) end),
		     {width=60})
   form.addLabel({label=lang.UpMidDown, width=94})
   form.addSelectbox({lang.UpL,lang.MidL,lang.DnL}, variables[swname .. "SwitchDir"], true,
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
      form.setTitle(lang.formTitle)
      
      form.addLink((function() form.reinit(2) end),
	 {label = lang.teleMenu})

      form.addLink((function() form.reinit(3) end),
	 {label = lang.raceMenu})

      form.addLink((function() form.reinit(5) end),
	 {label = lang.histMenu})

      form.addLink((function() form.reinit(6) end),
	 {label = lang.settingsMenu})            

      form.addLink((function() form.reinit(7) end),
	 {label = lang.browserMenu})

      form.addLink((function() form.reinit(12) end),
	 {label = lang.fieldMenu})      

      form.setFocusedRow(savedRow)

   elseif subform == 2 then
      savedRow = subform-1
      if telem.selectedGPS then
	 form.setTitle("GPS: " .. telem.selectedGPS)
      else
	 form.setTitle("Sensors")
      end
      
      local menuSelectGPS = { -- for lat/long only
	 Longitude= lang.selectLong,
	 Latitude = lang.selectLat
      }
      
      local menuSelect1 = { -- not from the GPS sensor
	 Vario = lang.selectVario,
	 Altimeter = lang.selectAltimeter,
	 TEKVario = lang.TEKVario
      }
      
      local menuSelect2 = { -- non lat/long but still from GPS sensor
	 Altitude = lang.selectAlt,
	 SpeedGPS= lang.selectSpeed
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

      checkBoxAdd(lang.selectGPSMode, "absAltGPS")

      for var, txt in pairs(menuSelect1) do
	 form.addRow(2)
	 form.addLabel({label=txt, width=220})
	 form.addSelectbox(sensorLalist, telem[var].Se, true,
			   (function(z) return sensorChanged(z, var, false) end) )
      end
      
      
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain, font=FONT_BOLD})
      
      form.setFocusedRow(1)      
   elseif subform == 3 then
      savedRow = subform-1

      checkBoxAdd(lang.enableTri, "triEnabled")

      switchAdd(lang.swStart, "start", subform)

      switchAdd(lang.swAnnounce, "triA", subform)

      switchAdd(lang.swThrottle, "throttle", subform)
      
      form.addRow(2)
      form.addLabel({label=lang.raceTime, width=220})
      form.addIntbox(variables.raceTime, 1, 60, 30, 0, 1, raceTimeChanged)
      
      form.addRow(2)
      form.addLabel({label=lang.maxStartSpd, width=220})
      form.addIntbox(variables.maxSpeed, 10, 500, 100, 0, 10, maxSpeedChanged)
      
      form.addRow(2)
      form.addLabel({label=lang.maxStartAlt, width=220})
      form.addIntbox(variables.maxAlt, 10, 500, 100, 0, 10, maxAltChanged)
      
      form.addRow(2)
      form.addLabel({label=lang.flightStartSpd, width=220})
      form.addIntbox(variables.flightStartSpd, 0, 100, 20, 0, 1, flightStartSpdChanged)

      form.addRow(2)
      form.addLabel({label=lang.flightStartAlt, width=220})
      form.addIntbox(variables.flightStartAlt, 0, 100, 20, 0, 1, flightStartAltChanged)

      form.addRow(2)
      form.addLabel({label=lang.maxTriAlt, width=220})
      form.addIntbox(variables.maxTriAlt, 100, 1000, 500, 0, 10,
		     (function(z) return
			   variableChanged(z, "maxTriAlt") end))

      form.addRow(2)
      form.addLabel({label=lang.triHeightScl, width=220})
      form.addIntbox(variables.triHeightScale, 1, 400, 100, 0, 10,
		     (function(z) return
			      variableChanged(z, "triHeightScale",
					      (function() tri2XY() end)) end) )

      local rev = {Light=1, Dark=2, Image=3}
      form.addRow(2)
      form.addLabel({label=lang.screenMode, width=220})
      form.addSelectbox({lang.modeLight, lang.modeDark, lang.modeImage},
	 rev[variables.triColorMode], true, triColorModeChanged)
      
      form.addLink((function() form.reinit(8) end),
	 {label = lang.raceAnn})            

      form.addLink((function() form.reinit(9) end),
	 {label = lang.racepreAnn})            

      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain,font=FONT_BOLD})

      form.setFocusedRow(1)

   elseif subform == 4 then
      --[[  now is done with the browser menu
      savedRow = subform-1
      
      form.addRow(2)
      form.addLabel({label="Triangle leg", width=220})
      form.addIntbox(variables.triLength, 10, 1000, 250, 0, 1,
		     triLengthChanged)
      
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
      --]]

   elseif subform == 5 then
      savedRow = subform-1
      -- not worth it do to a loop with a menu item table for Intbox due to the
      -- variation in defaults etc nor for addCheckbox due to specialized nature
      
      form.addRow(2)
      form.addLabel({label=lang.histSample, width=220})
      form.addIntbox(variables.histSample, 1000, 10000, 1000, 0, 100,
		     (function(z) return variableChanged(z, "histSample") end) )
      
      form.addRow(2)
      form.addLabel({label=lang.histPoints, width=220})
      form.addIntbox(variables.histMax, 0, 600, 300, 0, 10,
		     (function(z) return variableChanged(z, "histMax") end) )
      
      form.addRow(2)
      form.addLabel({label=lang.histDist, width=220})
      form.addIntbox(variables.histDistance, 1, 10, 3, 0, 1,
		     (function(z) return variableChanged(z, "histDistance") end) )
      
      form.addRow(2)
      form.addLabel({label=lang.triHistPoints, width=220})
      form.addIntbox(variables.triHistMax, 0, 40, 20, 0, 1,
		     (function(z) return variableChanged(z, "triHistMax") end) )

      form.addRow(2)
      form.addLabel({label=lang.triViewScl, width=220})
      form.addIntbox(variables.triViewScale, 100, 1000, 300, 0, 10,
		     (function(z) return variableChanged(z, "triViewScale") end) )

      switchAdd(lang.swPoints, "point", subform)

      form.addRow(2)
      form.addLabel({label=lang.ribbonColor, width=220})
      form.addSelectbox(
	 colorSelect,
	 variables.ribbonColorSource, true,
	 (function(z) return variableChanged(z, "ribbonColorSource") end) )

      switchAdd(lang.swColor, "color", subform)

      form.addLink((function() form.reinit(11) end), {label = lang.viewGrad})
	 
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain, font=FONT_BOLD})
      
      form.setFocusedRow(1)
      
   elseif subform == 6 then
      savedRow = subform-1

      form.addRow(2)
      form.addLabel({label=lang.futurePos, width=220})
      form.addIntbox(variables.futureMillis, 0, 10000, 2000, 0, 10,
		     (function(xx) return variableChanged(xx, "futureMillis") end) )

      checkBoxAdd(lang.showNoFly, "noflyEnabled")

      form.addRow(2)
      form.addLabel({label=lang.airplaneIcon, width=220})
      form.addSelectbox(lang.airplaneIcons, variables.airplaneIcon, true, airplaneIconChanged)
      
      checkBoxAdd(lang.annNoFly, "noFlyWarningEnabled")
      
      checkBoxAdd(lang.shakeNoFly, "noFlyShakeEnabled")

      switchAdd(lang.swNoFly, "noFly", subform)

      form.addRow(2)
      form.addLabel({label=lang.fieldElev, width=220})
      form.addIntbox(variables.elev, -1000, 1000, 0, 0, 1, elevChanged)
      
      checkBoxAdd(lang.recordIGC, "recordIGC")
      
      form.addLink(clearData, {label = lang.clearAll})
      
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain, font=FONT_BOLD})

      form.setFocusedRow(1)

      
   elseif subform == 7 then
      savedRow = subform-1
      ----------
      form.setTitle("")
      form.setButton(2, lang.buttonShow, 1)
      
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
      form.addLabel({label=lang.selField})
      form.addSelectbox(browse.List, browse.Idx, true, browseFieldClicked)
      form.addRow(1)
      form.addLabel({label=""})      
      form.addRow(1)
      form.addLabel({label=lang.showtoBrowse, font=FONT_NORMAL})
      form.addRow(1)
      form.addLabel({label=lang.ifyouBrowse, font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label=lang.ontheMap, font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label=lang.racingCourse, font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label=lang.pressButton2, font=FONT_MINI})
      form.addRow(1)      
      form.addLabel({label=lang.XYRL, font=FONT_MINI})
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain,font=FONT_BOLD})
      
      form.setFocusedRow(1)

   elseif subform == 8 or subform == 9 then
      if subform == 8 then
	 form.addRow(1)
	 form.addLabel({label=lang.courseCorr, width=220, font=FONT_MINI})
	 form.addRow(1)
	 form.addLabel({label=lang.distNext, width=220, font=FONT_MINI})
	 form.addRow(1)
	 form.addLabel({label=lang.perpDist, width=220, font=FONT_MINI})
	 form.addRow(1)
	 form.addLabel({label=lang.timePylon, width=220, font=FONT_MINI})
      end
      form.addRow(1)
      form.addLabel({label=lang.aAltitude, width=220, font=FONT_MINI})
      form.addRow(1)
      form.addLabel({label=lang.sSpeed, width=220, font=FONT_MINI})
      form.addRow(2)
      local temp
      if subform == 8 then
	 form.addLabel({label=lang.raceAnnSeq, width=220})
	 temp = variables.annText
	 form.addTextbox(temp, 30, annTextChanged)
      else
	 form.addLabel({label=lang.racePreSeq, width=220})
	 form.addTextbox(variables.preText, 30, preTextChanged)
      end
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain,font=FONT_BOLD})

   elseif subform == 10 then
      --print("savedRow to", subform-1)
      browse.MapDisplayed = true
      if browse.FieldName == browse.OriginalFieldName then
	 form.setButton(2, browse.opTable[browse.opTableIdx], 1)
	 form.setButton(5, lang.buttonSave, 1) -- otherwise it will be "Ok"
      end
      form.setTitle("")
      form.setButton(1, ":backward", 1)
      form.setButton(3, ":down" , 1)            
      form.setButton(4, ":up", 1)
   elseif subform == 11 then
      savedRow = 4
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain, font=FONT_BOLD})
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
      form.addLabel({label=lang.selFld})
      form.addSelectbox(browse.List, browse.Idx, true, selectFieldClicked)
      
      form.addLink((function() form.reinit(1) end),
	 {label = lang.backMain,font=FONT_BOLD})
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

local function playFile(ffn, as)
   local fn = appInfo.Dir .. "Lang/" .. locale .. "/Audio/" .. ffn
   --print("playFile: fn = ", fn)
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
   system.playFile("/".. fn, as)
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
    theta = math.atan(sxy,sx2)
    if xx[1] < xx[#xx] then
       tt = math.pi/2 - theta
    else
       tt = math.pi*3/2 - theta
    end

    return slope, tt
end

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

local lastsws
local lastdetS1 = -1
local inZoneLast = {}

local function drawTriRace(windowWidth, windowHeight)

   local ren=lcd.renderer()
   
   if not variables.triEnabled then return end
   if not pylon[1] then return end
   if not pylon.finished then return end
   
   setColor("Map", variables.triColorMode)

   for j=1, #pylon do
      local txt = string.format("%d", j)
      lcd.drawText(
      toXPixel(pylon[j].x, map.Xmin, map.Xrange, windowWidth) -
	 lcd.getTextWidth(FONT_MINI,txt)/2,
      toYPixel(pylon[j].y, map.Ymin, map.Yrange, windowHeight) -
	 lcd.getTextHeight(FONT_MINI)/2 + 15,txt, FONT_MINI)
   end

   
   -- draw line from airplane to the aiming point
   if raceParam.racing then
      setColor("AimPt", variables.triColorMode)
      lcd.drawLine(toXPixel(xtable[#xtable], map.Xmin, map.Xrange, windowWidth),
		   toYPixel(ytable[#ytable], map.Ymin, map.Yrange, windowHeight),
	   toXPixel(pylon[m3(nextPylon)].xt, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(pylon[m3(nextPylon)].yt, map.Ymin, map.Yrange, windowHeight) )
   end
   
   -- draw the triangle race course

   setColor("Triangle", variables.triColorMode)
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

   setColor("Map", variables.triColorMode)

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
      if raceParam.racing and inZone[j] then
	 setColor("Map", variables.triColorMode)
      end
      if raceParam.racing and j > 0 and j == m3(nextPylon) then
	 setColor("AimPt", variables.triColorMode)
      end
      lcd.drawCircle(toXPixel(pylon[j].xt, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(pylon[j].yt, map.Ymin, map.Yrange, windowHeight),
		     4)
      lcd.drawCircle(toXPixel(pylon[j].xt, map.Xmin, map.Xrange, windowWidth),
		     toYPixel(pylon[j].yt, map.Ymin, map.Yrange, windowHeight),
		     2)
      if raceParam.racing and j > 0 and j == m3(nextPylon) then
	 setColor("Map", variables.triColorMode)
      end
   end

   setColor("Label", variables.triColorMode)
   
   if raceParam.titleText then
      lcd.drawText((320 - lcd.getTextWidth(FONT_BOLD, raceParam.titleText))/2, 0,
	 raceParam.titleText, FONT_BOLD)
   end

   if raceParam.usedThrottle or raceParam.exceedMaxAlt then
      setColor("Error", variables.triColorMode)
   end
   
   if raceParam.subtitleText then
      lcd.drawText((320 - lcd.getTextWidth(FONT_MINI, raceParam.subtitleText))/2, 17,
	 raceParam.subtitleText, FONT_MINI)
   end

   setColor("Label", variables.triColorMode)
   
   if not raceParam.racing then
      if switchItems.throttle then
	 local swt
	 swt = system.getInputsVal(switchItems.throttle)
	 if swt then
	    if swt == 1 then
	       lcd.drawImage(5,80, dotImage.red)
	    else
	       lcd.drawImage(5,80, dotImage.green)
	    end
	 end
      end
   else
      if raceParam.usedThrottle == true then
	 lcd.drawImage(5,80, dotImage.red)
      else
	 if switchItems.throttle then
	    lcd.drawImage(5,80, dotImage.green)
	 end
      end
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
   
   lcd.drawText(5, 120, lang.Alt ..": ".. math.floor(altitude), FONT_MINI)
   lcd.drawText(5, 130, lang.Spd..": "..math.floor(speed), FONT_MINI)

   if metrics.index then
      local tlen = (variables.triLength * 2 * (1 + math.sqrt(2)))
      lcd.drawText(260, 140, string.format("Index: %03d", metrics.index), FONT_MINI)
   end
		
   local ll
   local swa

   if switchItems.triA then
      swa = system.getInputsVal(switchItems.triA)
   end
   if swa and swa == 1 then
      if raceParam.racing then
	 ll=lcd.getTextWidth(FONT_NORMAL, variables.annText)
	 lcd.drawText(310-ll, 115, variables.annText, FONT_NORMAL)
	 lcd.drawText(
	    310-ll - lcd.getTextWidth(FONT_MINI, "^")/2 +
	       lcd.getTextWidth(FONT_NORMAL, variables.annText:sub(1,annTextSeq)) -
	       lcd.getTextWidth(FONT_NORMAL, variables.annText:sub(annTextSeq, annTextSeq))/2, 
	    129, "^", FONT_MINI)      
      else
	 
	 ll=lcd.getTextWidth(FONT_NORMAL, variables.preText)
	 lcd.drawText(310-ll, 115, variables.preText, FONT_NORMAL)
	    lcd.drawText(
	       310-ll - lcd.getTextWidth(FONT_MINI, "^")/2 +
		  lcd.getTextWidth(FONT_NORMAL, variables.preText:sub(1,preTextSeq)) -
		  lcd.getTextWidth(FONT_NORMAL, variables.preText:sub(preTextSeq, preTextSeq))/2, 
	       129, "^", FONT_MINI)      
      end
   end
end

local function calcTriRace()

   local detS1
   local ao

   if not Field or not Field.name or not Field.triangle then return end
   if not variables.triEnabled then return end
   if #xtable == 0 or #ytable == 0 then return end

   if switchItems.throttle then
      local swt = system.getInputsVal(switchItems.throttle)
      if swt and swt == 1 and raceParam.racing then
	 raceParam.usedThrottle = true
      end
   end

   if altitude > variables.maxTriAlt then
      raceParam.exceedMaxAlt = true
   end
   
   --print(system.getTimeCounter() -lastgetTime)

   if Field then
      ao = variables.aimoff
   else
      ao = 0
   end
   -- if no course computed yet, start by defining the pylons
   --print("#pylon, Field.name", #pylon, Field.name)
   if tri and tri.center and (#pylon < 3) and Field.name then -- need to confirm with RFM order of vertices
      triRot(ao) -- handle rotation and tranlation of triangle course 
      -- extend startline below hypotenuse of triangle  by 0.8x inside length
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

   if (#pylon == 3) and (not pylon[1].xm) then
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
	 local zoneLen = 0.6 -- used to be 0.4
	 zx, zy = rotateXY(-zoneLen * variables.triLength, zoneLen * variables.triLength, rot[j])
	 pylon[j].zxl = zx + pylon[j].x
	 pylon[j].zyl = zy + pylon[j].y
	 zx, zy = rotateXY(zoneLen * variables.triLength, zoneLen * variables.triLength, rot[j])
	 pylon[j].zxr = zx + pylon[j].x
	 pylon[j].zyr = zy + pylon[j].y
	 pylon.finished = true
	 inZoneLast[j] = false
      end
      -- tri and pylon are recomputed each time we zoom .. make sure we only open once
      if not raceParam.IGCFile then
	 IGC("Open")
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
	    system.vibration(false, 1)
	    system.playBeep(m3(j)-1, 800, 400)
	    playFile("next_pylon.wav", AUDIO_IMMEDIATE)
	    playNumber(m3(j+1), 0)
	    IGC("Erecord", "TPC")
	    IGC("Lrecord", "Pylon "..tostring(m3(j)))
	    if m3(j) == 1 then IGC("Lrecord", "Pylon Zone 1") end
	    if m3(j) == 2 then IGC("Lrecord", "Pylon Zone 2") end
	    if m3(j) == 3 then IGC("Lrecord", "Pylon Zone 3") end	    
	    
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
      playFile("flight_started.wav", AUDIO_IMMEDIATE)
      IGC("Erecord", "STA")
      IGC("Lrecord", "Flight Started")
   end

   -- see if we have landed
   -- we need to see if it stays in this state for more than 5s (5000 ms)
   
   if raceParam.flightStarted ~= 0  and altitude < 20 and speed < 5 and not raceParam.raceFinished then
      if raceParam.flightLandTime == 0 then
	 raceParam.flightLandTime = system.getTimeCounter()
      end
      --print(system.getTimeCounter() - raceParam.flightLandTime)
      if system.getTimeCounter() - raceParam.flightLandTime  > 5000 then
	 playFile("flight_ended.wav", AUDIO_QUEUE)
	 raceParam.racing = false
	 raceParam.raceFinished = true
	 raceParam.raceEndTime = system.getTimeCounter()
	 raceParam.startArmed = false
	 IGC("Erecord", "STP")
	 IGC("Lrecord", "Landed")
	 IGC("Close")
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

   if not detS1 then
      print("DFM-Maps: Not detS1")
      return
   end

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
      --issue stop command to logger and close the file .. when pilot re-arms it will
      --open next file
      IGC("Erecord", "STP")
      IGC("Close")
   end
   
   
   -- see if we are ready to start
   if raceParam.startToggled and not raceParam.startArmed then --and not raceParam.raceFinished then
      if inStartZone and raceParam.flightStarted ~= 0 then
	 playFile("ready_to_start.wav", AUDIO_IMMEDIATE)
	 raceParam.startArmed = true
	 nextPylon = 0
	 raceParam.lapsComplete = 0
	 -- if this is a second race in a flight then the ICG file would have closed...
	 -- in this case, repopen it
	 --print("ready to start:", raceParam.IGCFile)
	 if not raceParam.IGCFile then
	    IGC("Open")
	 end
	 IGC("Erecord", "ARM")
      else
	 --playFile("bad_start.wav", AUDIO_IMMEDIATE)
	 if not inStartZone and not raceParam.raceFinished then
	    playFile("outside_zone.wav", AUDIO_QUEUE)
	 end
	 if raceParam.flightStarted == 0 then
	    playFile("flight_not_started.wav", AUDIO_QUEUE)
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
	    playFile("lap_complete.wav", AUDIO_IMMEDIATE)
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

	    
	    metrics.lapDist = metrics.distTrav
	    metrics.distTrav = 0
	    metrics.index = 100 * metrics.lapDist / perim
	    IGC("Erecord", "TPC")
	    IGC("Lrecord", "LSTARTSTARTTPC")
	    IGC("Lrecord", string.format("Index: %d", metrics.index))
	 end
      end
      
      if not raceParam.racing and raceParam.startArmed then
	 if speed  > variables.maxSpeed or altitude > variables.maxAlt then
	    playFile("start_with_penalty.wav", AUDIO_QUEUE)	    
	    if speed  > variables.maxSpeed then
	       playFile("over_max_speed.wav", AUDIO_QUEUE)
	       --print("speed, variables.maxSpeed", speed, variables.maxSpeed)
	    end
	    if altitude > variables.maxAlt then
	       playFile("over_max_altitude.wav", AUDIO_QUEUE)
	    end
	    raceParam.penaltyPoints = 50 + 2 * math.max(speed - variables.maxSpeed, 0) + 2 *
	       math.max(altitude - variables.maxAlt, 0)
	    lapAltitude = altitude
	    playFile("penalty_points.wav", AUDIO_QUEUE)
	    playNumber(math.floor(raceParam.penaltyPoints+0.5), 0)
	 else
	    playFile("task_starting.wav", AUDIO_QUEUE)
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
	 raceParam.usedythrottle = false
	 raceParam.maxTriAlt = false
	 metrics.distTrav = 0
	 metrics.lapDist = nil
	 metrics.index = nil
	 IGC("Erecord", "TPC")
	 IGC("Lrecord", "LSTARTSTARTTPC")
      end
   end

   if detS1 then lastdetS1 = detS1 end
   
   local sgTC = system.getTimeCounter()

   --print( (sgTC - raceParam.racingStartTime) / 1000, variables.raceTime*60)
   if raceParam.racing and (sgTC - raceParam.racingStartTime) / 1000 >= variables.raceTime*60 then
      playFile("race_finished.wav", AUDIO_IMMEDIATE)	    	 
      raceParam.racing = false
      raceParam.raceFinished = true
      raceParam.startArmed = false
      raceParam.startToggled = false
      raceParam.raceEndTime = sgTC
      IGC("Erecord", "STP")
      IGC("Close")
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
      raceParam.subtitleText = string.format(lang.LapTitle,
				   raceParam.lapsComplete,
				   math.floor(raceParam.rawScore - raceParam.penaltyPoints + 0.5),
				   math.floor(raceParam.penaltyPoints + 0.5))
      if raceParam.usedThrottle then
	 raceParam.subtitleText = raceParam.subtitleText .. " " .. lang.Thr
      end
      if raceParam.exceedMaxAlt then
	 raceParam.subtitleText = raceParam.subtitleText .. " " .. lang.Alt
      end
   end

   distance = math.sqrt( (xtable[#xtable] - pylon[m3(nextPylon)].xt)^2 +
	 (ytable[#ytable] - pylon[m3(nextPylon)].yt)^2 )

   local lastDist = math.sqrt( (xtable[#xtable] - pylon[m3(nextPylon+2)].xt)^2 +
	 (ytable[#ytable] - pylon[m3(nextPylon+2)].yt)^2 )

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
   
   if (now >= (lastgetTime + 850)) then -- once a sec
      --print(now-lastgetTime)
      lastgetTime = now
      IGC("Brecord")

      if swa and swa == 1 then
	 --print(m3(nextPylon+2), inZone[m3(nextPylon+2)] )
	 if raceParam.racing then
	    annTextSeq = annTextSeq + 1	 if annTextSeq > #variables.annText then
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
	 
	 
	 -- no announcements within 3 secs of turn (convert to m/s)
	 -- distance is dist to next pylon
	 -- lastDist is dist to prev pylon
	 -- former controls approach to pylon, latter departure from pylon
	 -- + 0.1 to guard against divide by zero
	 
	 local annZone = (distance / ( ( (speed or 0) + 0.1) / 3.6)) > 2.5
	 annZone = annZone and (lastDist / ( ( (speed or 0) + 0.1) / 3.6)) > 2.5
	 
	 if (sChar == "C" or sChar == "c") and raceParam.racing and annZone then
	    if relBearing < -6 then
	       if sChar == "C" then
		  playFile("turn_right.wav", AUDIO_QUEUE)
		  playNumber(-relBearing, 0)
	       else
		  playFile("right.wav", AUDIO_QUEUE)
		  playNumber(-relBearing, 0)
	       end
	    elseif relBearing > 6 then
	       if sChar == "C" then
		  playFile("turn_left.wav", AUDIO_QUEUE)
		  playNumber(relBearing, 0)
	       else
		  playFile("left.wav", AUDIO_QUEUE)
		  playNumber(relBearing, 0)
	       end
	    else
	       system.playBeep(0, 1200, 200)		  
	    end
	 elseif sChar == "D" or sChar == "d" and raceParam.racing then
	    if sChar == "D" then
	       playFile("distance.wav", AUDIO_QUEUE)
	       playNumber(distance, 0)
	    else
	       playFile("dis.wav", AUDIO_QUEUE)
	       playNumber(distance, 0)
	    end
	 elseif (sChar == "P" or sChar == "p") and raceParam.racing and not inZone[m3(nextPylon+2)] then
	    if perpD < 0 then
	       if sChar == "P" then
		  playFile("inside.wav", AUDIO_QUEUE)
		  playNumber(-perpD, 0)
	       else
		  playFile("in.wav", AUDIO_QUEUE)
		  playNumber(-perpD, 0)
	       end
	    else
	       if sChar == "P" then
		  playFile("outside.wav", AUDIO_QUEUE)
		  playNumber(perpD, 0)
	       else
		  playFile("out.wav", AUDIO_QUEUE)
		  playNumber(perpD, 0)
	       end
	    end
	 elseif sChar == "T" or sChar == "t" and raceParam.racing then
	    if speed ~= 0 then
	       playFile("time.wav", AUDIO_QUEUE)
	       playNumber(distance/speed, 1)	  
	    end
	 elseif sChar == "S" or sChar == "s" then
	    playFile("speed.wav", AUDIO_QUEUE)
	    playNumber(math.floor(speed+0.5), 0)
	 elseif sChar == "A" or sChar == "a" then
	    if sChar == "A" then
	       playFile("altitude.wav", AUDIO_QUEUE)
	       playNumber(math.floor(altitude+0.5), 0)
	    else
	       playFile("alt.wav", AUDIO_QUEUE)
	       playNumber(math.floor(altitude+0.5), 0)
	    end
	 end
      end
         --lastregion = region[code]
   end
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

local function prtForm(windowWidth, windowHeight)

   setColor("Map", "Image")

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

      lcd.drawImage(-5,8,fieldPNG[currentImage],255)-- -5 and 8 (175-160??) empirical? (ugg)      
      if Field then
	 setColor("Label", "Image")
	 lcd.drawText(10,10, Field.images[currentImage].file, FONT_NORMAL)	 
	 --maybe should center this instead of fixed X position
	 lcd.drawText(70,145,(browse.dispText or ""), FONT_NORMAL)	 
	 --lcd.setClipping(0,15,310,160)

	 setColor("Runway", "Image")
	 if #rwy == 4 then
	    ren:reset()
	    for j = 1, 5, 1 do
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
	    setColor("Triangle", "Image")
	    ren:renderPolyline(2,0.7)
	 end

	 if browse.FieldName == browse.OriginalFieldName then
	    if #pylon == 3 then
	       ren:reset()
	       for j= 1, 4, 1 do
		  ren:addPoint(toXPixel(pylon[j%3+1].x, map.Xmin, map.Xrange, windowWidth),
			       toYPixel(pylon[j%3+1].y, map.Ymin, map.Yrange, windowHeight))
	       end
	       setColor("TriRot", "Image")
	       ren:renderPolyline(2,0.7)
	       -- we don't have the aim points computed yet (pylon[].xt and .yt) so the code
	       -- to show them would go here
	    end
	 end
	 
	 for i = 1, #nfp, 1 do
	    ren:reset()
	    if nfp[i].inside then
	       setColor("NoFlyInside", "Image")
	    else
	       setColor("NoFlyOutside", "Image")
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
		  setColor("NoFlyInside", "Image")
	       else
		  setColor("NoFlyOutside", "Image")
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
      setColor("Map", "Image")
   end
end


local savedRx={}
local savedRy={}
local circFitCache={}

local function dirPrint(xw, xh, kk)
   local sC = variables.triLength * variables.triViewScale / 100 -- scale factor for this tele window
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
   local triColorMode

   --print("dp", xw, xh, kk, sC)

   if kk then
      --print("kk not nil!")
      if kk == 256 and variables.triViewScale >=105 then
	 variables.triViewScale = variables.triViewScale - 10
      elseif kk == 512 and variables.triViewScale <= 995 then
	 variables.triViewScale = variables.triViewScale + 10
      end
   end

   --metrics.dirPCount = metrics.dirPCount + 1

   --[[
   if system.getInputs("SH") == 1 then
      lcd.drawText(0,10,
		   "100 200 300 400 500 600 700 800 900 000 100 200 300 400 500",
		   FONT_MINI)
      return
   end
   --]]

   if not xtable or not ytable then return end

   --lcd.setClipping(0,0,320,160)
   --lcd.setColor(255,0,0)
   --lcd.drawRectangle(0,0,300,150)
   
   if variables.triColorMode == "Dark" then
      setColor("Background", "Image")
      lcd.drawFilledRectangle(0,0,320,160)      
   end

   if variables.triColorMode == "Image" then
      triColorMode = "Light"
   else
      triColorMode = variables.triColorMode
   end

   setColor("Label", triColorMode)

   if not variables.triEnabled then
      lcd.drawText(35, 20, lang.triNotEn, FONT_BIG)      
   end

   --[[
   if not compcrs then
      heading = 0
   end
   --]]
   
   ---[[
   if not compcrs then
      lcd.drawText(40, 20, lang.triNoHdg, FONT_BIG)
      return
   end
   --]]

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

   local function circFit(k)
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

   local function rap(x,y,d) -- rap for "ren:addPoint"
      local dx = xx - x
      local dy = yy - y
      local rx, ry = rotateXY(dx, dy, math.rad(hh))
      rx, ry = toXPixel(rx, xmin, xrange, ww), toYPixel(ry, ymin, yrange, wh)
      ren:addPoint(rx, ry)
      if d then
	 lcd.drawCircle(rx, ry, d)
      end
      return rx, ry
   end

   local function rapN(x,y,d) -- N for NoDraw
      local dx = xx - x
      local dy = yy - y
      local rx, ry = rotateXY(dx, dy, math.rad(hh))
      rx, ry = toXPixel(rx, xmin, xrange, ww), toYPixel(ry, ymin, yrange, wh)
      return rx, ry
   end

   local function rapC(rx,ry,d) -- C for cached
      ren:addPoint(rx, ry)
      if d then
	 lcd.drawCircle(rx, ry, d)
      end      
   end
   
   lcd.drawText(20-lcd.getTextWidth(FONT_MINI, "N") / 2, 6+4, "N", FONT_MINI)
   drawShape(20, 12+4, shapes.arrow, math.rad(-heading-variables.rotationAngle))
   lcd.drawCircle(20, 12+4, 7)
   
   if not pylon or not pylon[3] then return end
   
   ren:reset()

   -- draw the triangle
   
   setColor("Triangle", triColorMode)
   for j = 1, #pylon + 1 do
      rap(pylon[m3(j)].x, pylon[m3(j)].y)
   end
   ren:renderPolyline(2, 0.7)

   --draw the startline

   setColor("StartLine", triColorMode)
   if #pylon == 3 and pylon.start then
      ren:reset()
      rap(pylon[2].x, pylon[2].y)
      rap(pylon.start.x, pylon.start.y)
      --lcd.setColor(0,0,255)
      ren:renderPolyline(2,0.7)
   end

   -- draw the line to the next aim point
   setColor("AimPt", triColorMode)
   if raceParam.racing then
      --lcd.setColor(250,177,216)
      ren:reset()
      rap(xx,yy)
      rap(pylon[m3(nextPylon)].xt, pylon[m3(nextPylon)].yt)
      ren:renderPolyline(2, 0.7)
   end

   -- draw the turning zones
   setColor("TurnZone", triColorMode)
   for j = 1, #pylon do
      ren:reset()
      rap(pylon[j].x, pylon[j].y)
      rap(pylon[j].zxl, pylon[j].zyl)
      rap(pylon[j].zxr, pylon[j].zyr)
      rap(pylon[j].x, pylon[j].y)
      --lcd.setColor(240,115,0)
      local alpha
      if raceParam.racing and m3(nextPylon) == j then
	 alpha = 0.9
      else
	 alpha = 0.4
      end
      ren:renderPolygon(alpha)
   end

   ------------------------------------------------------------

   -- now draw the history/ribbon
   
   local swp
   
   if switchItems.point then
      swp = system.getInputsVal(switchItems.point)
   end

   if ( (not switchItems.point) or (swp and swp == 1) ) and (#xPHist > 0) then
      local kk
      local jj
      local ii = variables.ribbonColorSource
      local xrr, yrr
      local maxPts = variables.triHistMax
      local iend = #xPHist
      local istart = math.max(iend-maxPts+1, 1)
      local newH = (hh ~= lastHeading)

      -- for each heading, pre-compute pixels for history ribbon
      if newH then
	 for i=istart, iend do
	    xrr,yrr = ll2RX(i), ll2RY(i)
	    savedRx[i], savedRy[i] = rapN(xrr, yrr, 2)
	 end
      end
      ren:reset()
      rgb.last = -1
      -- display the history ribbon from the cached points, handle color changes
      for i=istart, iend do
	 -- in case we get unlucky on heading change timing, we might need to compute
	 -- some additional points from time to time. for speed just check savedRx
	 if not savedRx[i] then
	    xrr,yrr = ll2RX(i), ll2RY(i)
	    savedRx[i], savedRy[i] = rapN(xrr, yrr, 2)
	 end
	 if rgbHist[i] ~= rgb.last then
	    rgb.last = rgbHist[i]
	    rapC(savedRx[i], savedRy[i], 2)
	    ren:renderPolyline(variables.ribbonWidth*3, variables.ribbonAlpha * 0.7)
	    ren:reset()
	    if variables.ribbonColorSource == 1 then
	       setColor("Map", triColorMode)
	    else
	       lcd.setColor(rgbHist[i].r, rgbHist[i].g, rgbHist[i].b)
	    end
	 end
	 rapC(savedRx[i], savedRy[i], 2)
      end
      rap(xx,yy,2)
      ren:renderPolyline(variables.ribbonWidth*3, variables.ribbonAlpha * 0.7)
      
   end
   lastHeading = hh
   
   -- draw the airplane icon
   setColor("Label", triColorMode)
   --lcd.setColor(0,0,255)
   
   drawShape(toXPixel(0, xmin, xrange, ww),
   	     toYPixel(0, ymin, yrange, wh),
   	     shapes.airplaneIcon, 0)

   -- draw the projected flight path
   -- optimization needed: only call circFit when new hist point available otherwise cache

   local xx, cy, r, A
   local recomp
   local t0, t1, tn
   local dt
   
   if #latHist >= 5 then
      recomp = circFitCache.lastLat ~= latHist[#latHist] or circFitCache.lastLng ~= lngHist[#latHist]
      if recomp then
	 cx, cy, r, A = circFit(#latHist)
	 circFitCache.cx, circFitCache.cy, circFitCache.r, circFitCache.A = cx, cy, r, A
	 circFitCache.lastLat = latHist[#latHist]
	 circFitCache.lastLng = lngHist[#lngHist]
      else
	 cx,cy, r, A = circFitCache.cx, circFitCache.cy, circFitCache.r, circFitCache.A
      end
      if cx then
	 if recomp then
	    t1 = math.atan( (ll2RX(#latHist-1) - cx), (ll2RY(#latHist-1) - cy))
	    t0 = math.atan( (ll2RX(#latHist) - cx), (ll2RY(#latHist) - cy))
	    circFitCache.t1 = t1
	    circFitCache.t0 = t0
	 else
	    t0 = circFitCache.t0
	    t1 = circFitCache.t1	    
	 end
	 --can't cache tn since it varies with lat/long
	 if latitude and longitude then
	    tn = math.atan( (ll2RXr(latitude, longitude) - cx),
	       (ll2RYr(latitude, longitude) - cy))
	 else
	    tn = 0
	 end
	 dt = t0 - t1
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
	 --print("circFit2 failed")
      end
   end
   
   -- draw the telemetry values
   
   local text
   setColor("Label", triColorMode)
   --lcd.setColor(0,0,255)
   text = string.format("%d", math.floor(raceParam.lapsComplete))
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 5, text, FONT_BIG)
   text = lang.Laps
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 5+20, text, FONT_MINI)

   text = raceParam.lapTimeText or "00:00.0"
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 42, text, FONT_BIG)
   text = lang.LapTime
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 42+20, text, FONT_MINI)

   text = string.format("%d", math.floor(altitude + 0.5))
   if lapAltitude then
      text = text .. string.format(" / %d", math.floor(lapAltitude + 0.5))
   end
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 79, text, FONT_BIG)
   text = lang.LapAlt
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 79+20, text, FONT_MINI)
   
   text = string.format("%d", math.floor(speed + 0.5))
   --if raceParam.lastLapSpeed and raceParam.lastLapSpeed ~= 0 then
   --   text = text ..string.format(" / %d", math.floor(raceParam.lastLapSpeed + 0.5))
   --end
   lcd.drawText(xt - lcd.getTextWidth(FONT_BIG, text)/2, 116, text, FONT_BIG)
   text = lang.LapSpeed
   lcd.drawText(xt - lcd.getTextWidth(FONT_MINI, text)/2, 116+20, text, FONT_MINI)   

   if not metrics.maxCPU then metrics.maxCPU = 0 end
   if not metrics.avgCPU then metrics.avgCPU = 0 end

   metrics.avgCPU = metrics.avgCPU + (system.getCPU() - metrics.avgCPU) / 50
   
   if system.getCPU() > metrics.maxCPU then
      metrics.maxCPU = system.getCPU()
   end
   
   if variables.ribbonColorSource ~= 1 and ribbon.currentValue then
      lcd.drawText(18, 130, string.format("%s: " .. ribbon.currentFormat,
					 colorSelect[variables.ribbonColorSource],
					 ribbon.currentValue), FONT_MINI)
      lcd.setColor(rgb[ribbon.currentBin].r, rgb[ribbon.currentBin].g, rgb[ribbon.currentBin].b)
      lcd.drawFilledRectangle(6,133,8,8)
      if metrics.index then
	 setColor("Label", triColorMode)
	 lcd.drawText(5, 145, string.format("Index: %03d", metrics.index), FONT_MINI)	 
      end
      
   end

   collectgarbage()
   
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

local function checkNoFly(xt, yt, future, warnIn)
   
   local noFly, noFlyF, noFlyP, noFlyC, txy
   local warn
   local swn
   
   if switchItems.noFly then
      swn = system.getInputsVal(switchItems.noFly)
   end
   
   -- see if switch set to override warn settings
   
   if swn and swn < 0 then
      warn = false
   else
      warn = warnIn
   end
   
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
	    playFile("warning_no_fly_zone.wav", AUDIO_IMMEDIATE)
	 end
	 if checkBox.noFlyShakeEnabled and warn then
	    system.vibration(false, 3) -- left stick, 2x short pulse
	 end
      else
	 if checkBox.noFlyWarningEnabled and warn then
	    playFile("leaving_no_fly_zone.wav", AUDIO_QUEUE)
	 end
      end
   end
   
   if noFlyF ~= noFlyHist.LastF and future then
      if noFlyF then
	 if not noFly and warn then -- only warn of future nfz if not already in nfz
	    playFile("no_fly_ahead.wav", AUDIO_IMMEDIATE)
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

   --metrics.mapPCount = metrics.mapPCount + 1
   --[[
   local deltaC
   deltaC = metrics.xPCount - metrics.lastxPCount 
   if  deltaC > 0 then
      --print("metrics.xPCount, metrics.lastxPCount", metrics.xPCount, metrics.lastxPCount)
      metrics.lastxPCount = metrics.xPCount
   end
   --]]
   
   if not emFlag then
      if form.getActiveForm() then
	 return
      end
   end
   
   if recalcDone() then
      graphScale(xtable[#xtable], ytable[#ytable])
   end

   --lcd.setClipping(0,0,320,160)
   
   --[[
      -- started to separate no GPS from no map .. user sugggestion to show icon in motion or timer
      -- animation while waiting for GPS signal .. next logical step would be to let the app work with
      -- no map data ..about all we could do is put a marker at the init gps position, and orient to the 
      -- north since we'd have no direction data .. and then fabricate table entries for the screens 
      -- centered at 0,0 with the usual magnification factors. which is probably better than just 
      -- sitting there and not working as it does now!

   if not gotInitPos then
      setColor("Label", "Light")
      lcd.drawText((320 - lcd.getTextWidth(FONT_BIG, "No GPS fix"))/2, 20,
	 "No GPS fix", FONT_BIG)
   end
   
      -- some sort of animation or timer goes here between the two announcement lines

   if fieldPNG[currentImage] then
      if variables.triEnabled and (variables.triColorMode ~= "Image") then
	 setColor("Background", variables.triColorMode)
      	 lcd.drawFilledRectangle(0,0,320,160)
      else
      	 lcd.drawImage(0,0,fieldPNG[currentImage])
      end
   else
      setColor("Label", "Light")
      lcd.drawText((320 - lcd.getTextWidth(FONT_BIG, "No map for this position"))/2, 60,
	 "No Map for this position", FONT_BIG)
   end
   --]]

   if fieldPNG[currentImage] then
      if variables.triEnabled and (variables.triColorMode ~= "Image") then
	 setColor("Background", variables.triColorMode)
      	 lcd.drawFilledRectangle(0,0,320,160)
      else
      	 lcd.drawImage(0,0,fieldPNG[currentImage])
      end
   else
      setColor("Label", "Light")
      lcd.drawText((320 - lcd.getTextWidth(FONT_BIG, lang.noGPSfix))/2, 60,
	 lang.noGPSfix, FONT_BIG)
   end
   
   -- in case the draw functions left color set to their specific values

   if variables.triEnabled then
      setColor("Map", variables.triColorMode)
   else
      setColor("Map", "Image")
   end

   -- draw circle at 0,0 (for debugging)
   -- lcd.drawCircle(toXPixel(0, map.Xmin, map.Xrange, windowWidth),
   -- 		  toYPixel(0, map.Ymin, map.Yrange, windowHeight),
   -- 		  4)

   lcd.drawText(20-lcd.getTextWidth(FONT_MINI, "N") / 2, 6, "N", FONT_MINI)
   drawShape(20, 12, shapes.arrow, math.rad(-1*variables.rotationAngle))
   lcd.drawCircle(20, 12, 7)

   if variables.ribbonColorSource ~= 1 and ribbon.currentValue then
      lcd.drawText(18, 140, string.format("%s: " .. ribbon.currentFormat,
					 colorSelect[variables.ribbonColorSource],
					 ribbon.currentValue), FONT_MINI)
      lcd.setColor(rgb[ribbon.currentBin].r, rgb[ribbon.currentBin].g, rgb[ribbon.currentBin].b)
      lcd.drawFilledRectangle(6,143,8,8)
   end

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
	    if variables.triEnabled then
	       setColor("Map", variables.triColorMode)
	    else
	       setColor("Map", "Image")
	    end
	    --lcd.setColor(140,140,80)
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
      --setColorMain()
      if variables.triEnabled then
	 setColor("Map", variables.triColorMode)
      else
	 setColor("Map", "Image")
      end
      --AA--ren:renderPolyline(variables.ribbonWidth,variables.ribbonAlpha/10.0)
      ------------------------------
   end

   
   if variables.triEnabled then
      setColor("Runway", variables.triColorMode)
   else
      setColor("Runway", "Image")
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
   if checkBox.noflyEnabled then
      for i = 1, #nfp, 1 do
	 ren:reset()
	 if nfp[i].inside then
	    if variables.triEnabled then
	       setColor("NoFlyInside", variables.triColorMode)
	    else
	       setColor("NoFlyInside", "Image")
	    end
	 else
	    if variables.triEnabled then
	       setColor("NoFlyOutside", variables.triColorMode)
	    else
	       setColor("NoFlyOutside", "Image")
	    end
	 end
	 for j = 1, #nfp[i].path+1, 1 do
	    ren:addPoint(toXPixel(nfp[i].path[j % (#nfp[i].path) + 1].x,
				  map.Xmin, map.Xrange, windowWidth),
			 toYPixel(nfp[i].path[j % (#nfp[i].path) + 1].y,
				  map.Ymin, map.Yrange, windowHeight))
	    
	 end
	 --lcd.setClipping(0,0,310,160)
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
	       if variables.triEnabled then
		  setColor("NoFlyInside", variables.triColorMode)
	       else
		  setColor("NoFlyInside", "Image")
	       end
	    else
	       if variables.triEnabled then
		  setColor("NoFlyOutside", variables.triColorMode)
	       else
		  setColor("NoFlyOutside", "Image")
	       end
	    end
	    
	    lcd.drawCircle(toXPixel(nfc[i].x, map.Xmin, map.Xrange, windowWidth),
			   toYPixel(nfc[i].y, map.Ymin, map.Yrange, windowHeight),
			   nfc[i].r * windowWidth/map.Xrange)
	 end
      end
   end

   if variables.triEnabled then
      setColor("Map", variables.triColorMode)
   else
      setColor("Map", "Image")
   end
   
   drawTriRace(windowWidth, windowHeight)

   if #xtable > 0 then

      if variables.triEnabled then
	 setColor("Map", variables.triColorMode)
      else
	 setColor("Map", "Image")
      end

      if variables.histMax == 0 then
	 drawBezier(windowWidth, windowHeight, 0)
      end
      
      if variables.triEnabled then
	 setColor("Map", variables.triColorMode)
      else
	 setColor("Map", "Image")
      end
      
      -- defensive moves for squashing the indexing nil variable that Harry saw
      -- had to do with getting here (points in xtable) but no field selected
      -- checks in Field being nil should take care of that
      
      if checkNoFly(xtable[#xtable], ytable[#ytable], false, false) then
	 --setColorNoFlyInside()
	 if variables.triEnabled then
	    setColor("NoFlyInside", variables.triColorMode)
	 else
	    setColor("NoFlyInside", "Image")
	 end
      else
	 --setColorMap()
	 if variables.triEnabled then
	    setColor("Map", variables.triColorMode)
	 else
	    setColor("Map", "Image")
	 end
      end
      
      drawShape(toXPixel(xtable[#xtable], map.Xmin, map.Xrange, windowWidth),
		toYPixel(ytable[#xtable], map.Ymin, map.Yrange, windowHeight) + 0,
		shapes.airplaneIcon, math.rad(heading))
      
      if variables.futureMillis > 0 then
	 --setColorMap()
	 if variables.triEnabled then
	    setColor("Map", variables.triColorMode)
	 else
	    setColor("Map", "Image")
	 end
	 if checkNoFly(xtable[#xtable], ytable[#xtable], true, false) then
	    --setColorNoFlyInside()
	    if variables.triEnabled then
	       setColor("NoFlyInside", variables.triColorMode)
	    else
	       setColor("NoFlyInside", "Image")
	    end
	 else
	    --setColorMap()
	    if variables.triEnabled then
	       setColor("Map", variables.triColorMode)
	    else
	       setColor("Map", "Image")
	    end
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

   metrics.loopCount = metrics.loopCount + 1

   --metrics.dirPDelta = metrics.loopCount - metrics.dirPCount
   --metrics.mapPDelta = metrics.loopCount - metrics.mapPCount

   --print("lC, mapP, dirP, dPD, mPD", metrics.loopCount, metrics.dirPCount, metrics.mapPCount, metrics.dirPDelta, metrics.mapPDelta)
      
   -- don't loop menu is up on screen
   if form.getActiveForm() then return end

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

   sensor = system.getSensorByID(auxSensors.satCountID, auxSensors.satCountPa)
   
   if sensor and sensor.valid then
      auxSensors.satCount = sensor.value
   end

   sensor = system.getSensorByID(auxSensors.satQualityID, auxSensors.satQualityPa)
   if sensor and sensor.valid then
      auxSensors.satQuality = sensor.value
   end   

   sensor = system.getSensorByID(telem.Longitude.SeId, telem.Longitude.SePa)

   ---[[
   local sign, minstr, latstr, lngstr
   --]]
   
   if(sensor and sensor.valid) then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative (NESW coded in decimal places as 0,1,2,3)
	 longitude = longitude * -1
      end
      --[[ for test GPS lib
      if sensor.decimals == 3 then sign = "-" else sign = "" end             
      minstr = string.format("%d", math.floor(0.5 + minutes * 1666666.67)) -- 1E8/60
      lngstr = sign..string.format("%d", degs).."." .. minstr
      --]]      
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
      --[[ for test GPS lib
      if sensor.decimals == 2 then sign = "-" else sign = "" end             
      minstr = string.format("%d", math.floor(0.5 + minutes * 1666666.67)) -- 1E8/60
      latstr = sign..string.format("%d", degs).."." .. minstr
      --]]      
      goodlat = true
      numGPSreads = numGPSreads + 1
   end

   --[[ test gps libraray
   local zeroPos
   local curPos
   local curDist
   local curBear
   local curX
   local curY
   
   if Field.lat and Field.lng then
      zeroPos = gps.newPoint(Field.lat, Field.lng)
      --curPos = gps.getPosition(telem.Latitude.SeId, telem.Latitude.SePa, telem.Longitude.SePa)
      if latstr and lngstr then
	 --print("latstr, lngstr", latstr, lngstr)
	 curPos = gps.newPoint(latstr, lngstr)
      else
	 curPos = gps.newPoint(latitude, longitude)
      end
      --print("zeroPos, curPos:", gps.getStrig(zeroPos), gps.getStrig(curPos))
      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      --curX, curY = rotateXY(curX, curY, math.rad(variables.rotationAngle))
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))
      --print("curDist, curBear", curDist, curBear)
      --print("curX, curY", curX, curY)
   end
   --]]
   
   
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
      if sensor.unit == "ft" or sensor.unit == "ft." then
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
      elseif (sensor.unit == "km/h") or (sensor.unit == "kmh") then
	 SpeedGPS = sensor.value
      elseif sensor.unit == "mph" then
	 SpeedGPS = sensor.value * 1.609344
      else -- what on earth units are these .. set to 0
	 SpeedGPS = 0
      end
   end

   sensor = system.getSensorByID(telem.Vario.SeId, telem.Vario.SePa)
   
   if(sensor and sensor.valid) then -- assume units are m/s
      vario = sensor.value
   end

   sensor = system.getSensorByID(telem.TEKVario.SeId, telem.TEKVario.SePa)

   if(sensor and sensor.valid) then -- assume units are m/s
      tekvario = sensor.value
   end
   
   sensor = system.getSensorByID(telem.Altimeter.SeId, telem.Altimeter.SePa)

   if(sensor and sensor.valid) then -- assume units are m
      altimeter = sensor.value
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
   
   if Field and Field.elevation and variables.absAltGPS  then
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

   --[[
   --print("x,y:", x,y)

   if curX and curY then
      print("curX, curY", curX, curY)
      x,y = curX, curY
   end
   --]]
   
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

      if not metrics.distTrav then metrics.distTrav = 0 end

      -- play with: compute distance travelled.
      -- to do properly synched with start/finish line will be more challenging
      -- depending on how precise we need to be (e.g. interpolate start/end line from
      -- actual GPS points straddling it, and if we are to detect and remove thermalling?
      
      ---[[
      if #xtable > 2 then
	 local lp = #xtable
	 local np = lp -1
	 metrics.distTrav = metrics.distTrav +
	    math.sqrt( (xtable[lp] - xtable[np])^2 + (ytable[lp] - ytable[np])^2)
      end
      --]]

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
	 metrics.xPCount = metrics.xPCount + 1
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

	 ribbon.currentFormat = "%.f"
	 
	 if variables.ribbonColorSource == 1 then -- none
	    jj = #rgb // 2 -- mid of gradient - right now this is sort of a yellow color
	 elseif variables.ribbonColorSource == 2 then -- altitude 0-600m
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
	    ribbon.currentFormat = "%.2f"	    
	 elseif variables.ribbonColorSource == 10 then -- Rx2 Q
	    jj = gradientIndex(system.getTxTelemetry().rx2Percent, 0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 11 then -- Rx2 A1
	    jj = gradientIndex(system.getTxTelemetry().RSSI[3],    0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 12 then -- Rx2 A2
	    jj = gradientIndex(system.getTxTelemetry().RSSI[4],    0, 100,  #rgb)
	 elseif variables.ribbonColorSource == 13 then -- Rx2 V
	    jj = gradientIndex(system.getTxTelemetry().rx2Voltage, 0,   8,  #rgb)
	    ribbon.currentFormat = "%.2f"	    
	 elseif variables.ribbonColorSource == 14 then -- P4
	    jj = gradientIndex((1+system.getInputs("P4"))*50, 0,   100,  #rgb)	   
 	 elseif variables.ribbonColorSource == 15 then -- Distance
	    jj = gradientIndex(distHome(), 0, distDiag(),  #rgb)
	    ribbon.currentFormat = "%.1f"
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

   if #xtable > 3 then --lineAvgPts then -- we have at least 4 points...
      -- make sure we have a least 0.5m of manhat dist over which to compute compcrs
      
      local mhD =  (math.abs(xtable[#xtable]-xtable[#xtable-lineAvgPts+1]) +
		    math.abs(ytable[#ytable]-ytable[#ytable-lineAvgPts+1]))
      if mhD > 0.5 then
	 --[[ TEST TEST
	 print("#bp", #bezierPath)
	 local xbp = {}
	 local ybp = {}
	 local bpl = #bezierPath
	 xbp[1] = bezierPath[bpl-3].x
	 ybp[1] = bezierPath[bpl-3].y	 
	 xbp[2] = bezierPath[bpl].x
	 ybp[2] = bezierPath[bpl].y

	 compcrs = select(2, fslope(xbp, ybp))
	 --]]
	   compcrs = select(2,fslope(table.move(xtable, #xtable-lineAvgPts+1, #xtable, 1, {}),
				     table.move(ytable, #ytable-lineAvgPts+1, #ytable, 1, {})))
      else
	 --if emFlag then print("<=0.5 manhat", mhD) end
      end
   else
      compcrs = nil
   end
   compcrsDeg = (compcrs or 0)*180/math.pi

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

   --print("DFM-Maps init()")
   
   local fg = io.readall(appInfo.Dir.."JSON/Shapes.jsn")

   if fg then
      shapes = json.decode(fg)
   else
      print(appInfo.Name .. ": Could not open "..appInfo.Dir.."JSON/Shapes.jsn")
   end

   fg = io.readall(appInfo.Dir .."JSON/Colors.jsn")

   if fg then
      colors = json.decode(fg)
   else
      print(appInfo.Name .. ": Could not open" .. appInfo.Dir .. "JSON/Colors.jsn")
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

   --setColorMain()  -- if a map is present it will change color scheme later
   if variables.triEnabled then
      setColor("Map", variables.triColorMode)
   else
      setColor("Map", "Image")
   end
   
   graphInit(currentImage)  -- ok that currentImage is not yet defined

   
   variables = jLoadInit(jFilename())
   
   variables.rotationAngle     = jLoad(variables, "rotationAngle",   0)
   variables.histSample        = jLoad(variables, "histSample",   1000)
   variables.histMax           = jLoad(variables, "histMax",         0)
   variables.maxCPU            = jLoad(variables, "maxCPU",         80)
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
   variables.triLength         = jLoad(variables, "triLength",     250)
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
   variables.throttleSwitchName= jLoad(variables, "throttleSwitchName", 0)
   variables.throttleSwitchDir = jLoad(variables, "throttleSwitchDir", 0)
   variables.pointSwitchName   = jLoad(variables, "pointSwitchName", 0)
   variables.pointSwitchDir    = jLoad(variables, "pointSwitchDir", 0)
   variables.colorSwitchName   = jLoad(variables, "colorSwitchName", 0)
   variables.colorSwitchDir    = jLoad(variables, "colorSwitchDir", 0)            
   variables.noFlySwitchName   = jLoad(variables, "noFlySwitchName", 0)
   variables.noFlySwitchDir    = jLoad(variables, "noFlySwitchDir", 0)   
   variables.triColorMode      = jLoad(variables, "triColorMode", "Image")
   variables.airplaneIcon      = jLoad(variables, "airplaneIcon", 1)
   variables.triHistMax        = jLoad(variables, "triHistMax", 20)
   variables.triViewScale      = jLoad(variables, "triViewScale", 300)
   variables.triHeightFactor   = jLoad(variables, "triHeightScale", 100)
   variables.lastMatchField    = jLoad(variables, "lastMatchField", "")
   variables.maxTriAlt         = jLoad(variables, "maxTriAlt", 500)
   
   --------------------------------------------------------------------------------

   for i, j in ipairs(telem) do
      telem[j].Se   = jLoad(variables, "telem_"..j.."_Se", 0)
      telem[j].SeId = tonumber("0X" .. jLoad(variables, "telem_"..j.."_SeId", 0))
      telem[j].SePa = jLoad(variables, "telem_"..j.."_SePa", 0)
   end
   
   checkBox.triEnabled = jLoad(variables, "triEnabled", false)
   checkBox.noflyEnabled = jLoad(variables, "noflyEnabled", true)
   checkBox.noFlyWarningEnabled = jLoad(variables, "noFlyWarningEnabled", true)   
   checkBox.noFlyShakeEnabled = jLoad(variables, "noFlyShakeEnabled", true)   
   checkBox.absModeGPS = jLoad(variables, "absAltGPS", false)
   checkBox.recordIGC = jLoad(variables, "recordIGC", false)
   
   shapes.airplaneIcon = shapes[shapes.airplaneIcons[variables.airplaneIcon]]

   metrics.loopCount = 0
   metrics.lastLoopTime = system.getTimeCounter()
   metrics.loopTimeAvg = 0
   metrics.xPCount = 0
   metrics.dirPCount = 0
   metrics.mapPCount = 0
   metrics.lastxPCount = 0
   
   setLanguage()
   
   system.registerForm(1, MENU_APPS, appInfo.menuTitle, initForm, keyForm, prtForm)
   system.registerTelemetry(1, appInfo.Name.." "..lang.mapView, 4, mapPrint, {"MV1", "MV2", "MV3", "MV4"})
   system.registerTelemetry(2, appInfo.Name.." "..lang.triView, 4, dirPrint, {"TV1", "TV2", "TV3", "TV4"})   
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   -- if we are running on the TX, remove any old copies of DFM-Maps.lua which are
   -- left over .. they are confusing if we are now distributing as .lc
   
   --if not emFlag then
   --io.remove("./Apps/DFM-Maps.lua")
   --end
   
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
   
   switchItems = {point = 0, start = 0, triA = 0, throttle = 0, color = 0, noFly = 0}
   
   for k,v in pairs(switchItems) do
      switchItems[k] = createSw(shapes.switchNames[variables[k.."SwitchName"]],
				variables[k.."SwitchDir"])
      checkBox[k.."Switch"] = system.getInputsVal(switchItems[k]) == 1
   end

end

return {init=init, loop=loop, author="DFM", version="8.1", name=appInfo.Name, destroy=destroy}


