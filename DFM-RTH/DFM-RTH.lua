--[[

   -----------------------------------------------------------------------------------------
   DFM-RTH "Return to home" .. Conceived by Harry Curzon, coded by DFM. Initially copied from
   DFM-HUD.lua as starting point

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   DFM-RTH.lua released under MIT license by DFM 2026
   -----------------------------------------------------------------------------------------

--]]

if not sharedVar then sharedVar = {} end

local appName = "DFM-RTH"
local pathApp = "Apps/"..appName.."/"
local pathImages = pathApp.."Images/"
local pathConfigs = pathApp.."Configs/"
local pathJson = pathApp.."Json/"
local JSNVERSION = 1
local loopCPU = 0	 
local wasEverGreen = false
local Glass = {}
local otaTimer = 0
local restartTimer = 0
local powerDownTimer = 0
local gestureTime = 0

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

--RTH.switches = {}

local swtCI = {}
local switchItems = {}

local pageNumber = 0
local pageMax = 0
local pageLimit = 3
local pageNumberTele
local subForm
local savedRow = 0
local gaugeNumber = 0
local gaugeMax = 10 -- max # gauges in a format
local emflag
local sidSerial
local lastWrite = 0
local editImgs = {}
local imageNum
local imageMax
local modelName
local state = {DISCONNECTED=1, WAITING=2, CONNECTED=3, SENDHEADER=4, SENDFILE=5, SENDFOOTER=6,
	       COMPLETE=7, SELECT=8, ALMOST=9}
local sendState = state.DISCONNECTED
local startingTime = 0
local WAIT_TIME = 200
local sendFP --, sendFPser
local writeJSON = true
local jsonHoldTime = 0
--local tempCall
--local sendFPtemp
local cfgimg = {}
local cfgimgESP = {}
local glassesIcon
local redcrossIcon
local greencheckIcon
local batteryIcon
local yellowpauseIcon
--local configIDs
--local currentConfigIDs
local serialBytesSent = 0
--local totalSendBytes
local serialFileName
local lastRead = 0
local resetGlasses

local initTime
local LOOPTIME = 100

local savedSerial = {}
local savedSerialReset = {}
local teleSerial = {}
local teleSerialReset = {}
local sendIndex = 0
local splashScreen
local pos3D = {}
pos3D.x = {}
pos3D.y = {}
pos3D.z = {}
local pos2D = {}
pos2D.x = {}
pos2D.y = {}


local resetState = false

local function resetOn()
   resetState = true
end
local function resetOff()
   resetState = false
end

local function sendUSB(text)
   print("sendUSB: " .. text)
end


local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function ll2xy(rp)
   local x, y
   local brg = gps.getBearing(RTH.var.Field.center, rp)
   brg = brg - RTH.var.Field.heading
   local dist = gps.getDistance(RTH.var.Field.center,rp)
   x = dist * math.sin(math.rad(brg))
   y = dist * math.cos(math.rad(brg))
   return {x=x,y=y}
end

local function nfz2XY()
	    
   local rp

   RTH.var.nfc = {}
   RTH.var.nfp = {}
   
   if RTH.var.Field.nofly then
      for j = 1, #RTH.var.Field.nofly, 1 do
	 if RTH.var.Field.nofly[j].type == "circle" then
	    local rp = gps.newPoint(RTH.var.Field.nofly[j].lat,
				    RTH.var.Field.nofly[j].lng)
	    local tt = ll2xy(rp)
	    tt.r = RTH.var.Field.nofly[j].diameter / 2
	    tt.inside = RTH.var.Field.nofly[j].inside_or_outside == "inside"
	    table.insert(RTH.var.nfc, tt)
	 elseif RTH.var.Field.nofly[j].type == "polygon" then
	    local pp = {}
	    for k = 1, #RTH.var.Field.nofly[j].path, 1 do
	       rp = gps.newPoint(RTH.var.Field.nofly[j].path[k].lat,
				       RTH.var.Field.nofly[j].path[k].lng)
	       table.insert(pp,ll2xy(rp))
	    end
	    table.insert(RTH.var.nfp,
			 {inside=(RTH.var.Field.nofly[j].inside_or_outside == "inside"),
			  path = pp})
	 end
      end
   end
end

local function rwy2XY()
   local rPos
   RTH.var.rwy = {}
   if RTH.var.Field.runway then
      for j=1, #RTH.var.Field.runway.path, 1 do
	 rPos = gps.newPoint(RTH.var.Field.runway.path[j].lat, RTH.var.Field.runway.path[j].lng)
	 RTH.var.rwy[j] = ll2xy(rPos)
	 --print("j, rwy.x, rwy.y:", j, RTH.var.rwy[j].x, RTH.var.rwy[j].y)
      end
      RTH.var.rwy.heading = RTH.var.Field.runway.heading
      --print("rwy heading:", RTH.var.rwy.heading)
   end
end


local function drawArc(theta, x0, y0, a0, aR, ri, ro, im, alp)

   local ren = lcd.renderer()

   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*theta/im), y0 - ro * math.sin(a0 + i*theta/im))
   end
   
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*theta/im), y0 - ri * math.sin(a0+i*theta/im))
   end

   ren:renderPolygon(alp)
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function sv(dec, val)
   local fms
   --if not dec or (dec < 0) or (dec > 2) then return nil end
   if dec == 0 then
      fms = "%.0f"
   elseif dec == 1 then
      fms = "%.2f"
   else
      fms = "%.3f"
   end
   
   if val then 
      return string.format(fms, val)
   else
      return nil
   end
end

local function encodeBuf(str)
   local ret
   ret = str:gsub("(%x%x)", (function(s) return string.char(tonumber(s,16)) end))
   return ret
end

local function drawTextCenter(x, y, strIn, font)
   local str
   if not strIn then str = "---" else str = strIn end
   local w = lcd.getTextWidth(font, str)
   local h = lcd.getTextHeight(font, str)
   lcd.drawText(x - w/2, y - h/2, str, font)
end

local function changedSwitch(val, switchName)
   --print("changedSwitch", val, switchName)
   local Invert = 1.0
   local swInfo = system.getSwitchInfo(val)
   local swTyp = string.sub(swInfo.label,1,1)
   if swInfo.assigned then
      if string.sub(swInfo.mode,-1,-1) == "I" then Invert = -1.0 end
      -- note: swInfo.mode will be "PS" for normal sw eval, "P" for proportional
      local prop = (string.find(swInfo.mode, "S") == nil)
      --print("cS, prop, swTyp", prop, swTyp, swInfo.mode, Invert, swInfo.value)
      if prop or (swInfo.value == Invert) or swTyp == "L" or swTyp =="M" then
	 --print("CS assigning")
	 switchItems[switchName] = val
	 RTH.switchInfo[switchName] = {} 
	 RTH.switchInfo[switchName].name = swInfo.label
	 if swTyp == "L" or swTyp =="M" then
	    RTH.switchInfo[switchName].activeOn = 0
	 else
	    local ao = system.getInputs(string.upper(swInfo.label))
	    RTH.switchInfo[switchName].activeOn = ao
	 end
	 RTH.switchInfo[switchName].mode = swInfo.mode
      else
	 system.messageBox("Error - do not move switch when assigning")
	 --print("CS zeroing")
	 form.setValue(swtCI[switchName], nil)
	 switchItems[switchName] = nil
	 RTH.switchInfo[switchName] = nil	 
      end
   else
      if RTH.switchInfo[switchName] then
	 --print("CS zeroing - not assigned")
	 switchItems[switchName] = nil
	 RTH.switchInfo[switchName] = nil
      end
   end
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

local function readSensors(tt)
   local sensorLbl = "***"
   local l1, l2
   local GPStype = 9
   
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    if sensor.type ~= GPStype then
	       --print("GPS", sensor.id, sensor.param)
	       table.insert(tt.sensorLalist, l1 .. "_" .. l2)
	       table.insert(tt.sensorLslist, sensor.label)	    
	       table.insert(tt.sensorIdlist, sensor.id)
	       table.insert(tt.sensorPalist, sensor.param)
	       table.insert(tt.sensorUnlist, sensor.unit)
	       table.insert(tt.sensorDplist, sensor.decimals)
	       table.insert(tt.sensorTylist, sensor.type)
	    else
	       table.insert(tt.gpsLalist, l1 .. "_" .. l2)	       
	       table.insert(tt.gpsLslist, sensor.label)	    
	       table.insert(tt.gpsIdlist, sensor.id)
	       table.insert(tt.gpsPalist, sensor.param)
	    end
	 end
      end
   end
   -- Special sensors (values come from other than telemetry sensors)
   --
   -- Id = -1
   --
   -- Pa = 1  GPS Distance
   -- Pa = 2  GPS Bearing To
   -- Pa = 3  GPS Bearing From
   -- Pa = 4  Timer 1
   -- Pa = 5  Timer 2
   -- Pa = 6  Timer 1 percentage of time/(initial-target)
   -- Pa = 7  Timer 2 percentage of time/(initial-target)   
   
   local function insertSp(tbl, id, pa, la, ls, un)
      table.insert(tbl.sensorLalist, la)
      table.insert(tbl.sensorLslist, ls)
      table.insert(tbl.sensorIdlist, id)
      table.insert(tbl.sensorPalist, pa)
      table.insert(tbl.sensorUnlist, un)      
   end

   --[[
   insertSp(tt, -1, 1, "GPS_Distance", "Distance", "m")
   insertSp(tt, -1, 2, "GPS_BearingTo", "BearingTo", "°")
   insertSp(tt, -1, 3, "GPS_BearingFrom", "BearingFrom", "°")
   insertSp(tt, -1, 4, "GPS_Heading", "Heading", "°")   
   insertSp(tt, -1, 5, "T_Timer1", "Timer1Secs", "s")
   insertSp(tt, -1, 6, "T_Timer2", "Timer2Secs", "s")
   insertSp(tt, -1, 7, "T_Timer1Pct", "Timer1Pct", "%")
   insertSp(tt, -1, 8, "T_Timer2Pct", "Timer2Pct", "%")
   insertSp(tt, -1, 9, "P_ControlP1", "P1", "")
   insertSp(tt, -1,10, "P_ControlP2", "P2", "")
   insertSp(tt, -1,11, "P_ControlP3", "P3", "")
   insertSp(tt, -1,12, "P_ControlP4", "P4", "")
   insertSp(tt, -1,13, "TG_Remaining", "TG_R", "s")
   insertSp(tt, -1,14, "TG_Elapsed", "TG_E", "s")         
   --]]
end

local oldPageNumber = 0

local function setpNT()
      local sw = system.getInputsVal(switchItems.pageChange) or -1
      local pp = sw + 2 -- -1, 0, 1 --> 1,2,3
      pp = math.min(pp, pageMax)
      pageNumberTele = pp
      if pp ~= oldPageNumber then
	 writeInst()
      end
      oldPageNumber = pp
end

local function encdp(dp, val)
   if dp == 2 then
      return string.format("%.2f", val)
   elseif dp == 1 then
      return string.format("%.1f", val)
   else
      return string.format("%.0f", val)
   end
end

local lastSend = 0
local linecount = 0
local enterWaiting = 0
local oncePerSecond = 0
local lastTakeoffSw = 0
local lastGearUpSw = 0
local lastScreen = 0
local lastMapScreen = 0

--local startUp = system.getTimeCounter()

local function loop()
   local now = system.getTimeCounter()
   local unow = now 
   local sensor, sval, sval2
   local scale
   local minV, maxV
   
   local gotGPS
   local takeoff = system.getInputsVal(switchItems.takeoff) or 0      
   local gearUp = system.getInputsVal(switchItems.gearUp) or 0

   if RTH.settings.latId ~= 0 and RTH.settings.latPa ~= 0 and RTH.settings.lngPa ~= 0 then
      gotGPS = true
   else
      gotGPS = false
   end
   
   if takeoff ~= lastTakeoffSw and takeoff == 1 then
      if gotGPS then
	 RTH.var.startTakeoff = gps.getPosition(RTH.settings.latId, RTH.settings.latPa,
						  RTH.settings.lngPa)
	 if RTH.var.startTakeoff then
	    --print(RTH.var.startTakeoff)
	    local s1, s2 = gps.getStrig(RTH.var.startTakeoff)
	    print("Start takeoff:", s1, s2, RTH.var.startTakeoffAlt)
	 end
      end
      sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
      if sensor and sensor.valid then
	 RTH.var.startTakeoffAlt = sensor.value
      end
   end

   if gearUp ~= lastGearUpSw and gearUp == 1 then
      if gotGPS then
	 RTH.var.gearUP = gps.getPosition(RTH.settings.latId, RTH.settings.latPa,
					    RTH.settings.lngPa)
	 if RTH.var.gearUp then
	    --print(RTH.var.gearUp)
	    local s1, s2 = gps.getStrig(RTH.var.gearUp)
	    print("Gear up:", s1, s2)
	 end
      end
   end
   
   lastTakeoffSw = takeoff
   lastGearUpSw = gearUp
   
   if RTH.settings.latId ~= 0 and RTH.settings.latPa ~= 0 and RTH.settings.lngPa ~= 0 then
      RTH.var.currentPosition = gps.getPosition(RTH.settings.latId, RTH.settings.latPa,
						  RTH.settings.lngPa)
   end
      
   local alt = 0
   if gotGPS then
      sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
      if sensor and sensor.valid then
	 alt = sensor.value - (RTH.var.startTakeoffAlt or 0)
      end
   end

   local cometTailPts = 10 --max #points in comet tail
   
   if RTH.var.currentPosition and RTH.var.Field and now > lastMapScreen then
      local idx = #pos2D.x
      if idx >= cometTailPts then
	 table.remove(pos2D.x,1)
	 table.remove(pos2D.y,1)
      end
      local t = ll2xy(RTH.var.currentPosition)
      table.insert(pos2D.x, t.x)
      table.insert(pos2D.y, t.y)
      lastMapScreen = now + 1000 * RTH.settings.cometTailLength / cometTailPts
   end
   
   local historyPts = 40 -- making this larger causes too much CPU load in the tele draw callback
   
   if RTH.var.currentPosition and RTH.var.zeroPos and
      RTH.var.startTakeoff and RTH.var.gearUp and now > lastScreen then
      local zero2currB = gps.getBearing(RTH.var.currentPosition, RTH.var.zeroPos)
      local zero2currD = gps.getDistance(RTH.var.currentPosition, RTH.var.zeroPos)
      local gearUp2toB = gps.getBearing(RTH.var.startTakeoff, RTH.var.gearUp)
      local theta = zero2currB - gearUp2toB - 90
      --print("perp", gearUp2toB - 90)
      local idx = #pos3D.x
      if idx >= historyPts then
	 table.remove(pos3D.x,1)
	 table.remove(pos3D.y,1)
	 table.remove(pos3D.z,1)
      end
      table.insert(pos3D.x, zero2currD * math.sin(math.rad(theta)))
      table.insert(pos3D.y, zero2currD * math.cos(math.rad(theta)))
      table.insert(pos3D.z, alt)
      if idx > 1 and RTH.var.previousPosition then
	 RTH.var.heading = gps.getBearing(RTH.var.currentPosition, RTH.var.previousPosition)
	 local dd = (RTH.var.heading - gearUp2toB) % 360
	 local str
	 if dd > 90 and dd < 270 then
	    str = "L-R"
	    RTH.var.leftRight = 1
	 else
	    str = "R-L"
	    RTH.var.leftRight = -1
	 end
	 --print("runway heading, heading, h-z",
	 --gearUp2toB, RTH.var.heading, dd, str)
      end
      RTH.var.previousPosition = RTH.var.currentPosition
      --print("Gsh", RTH.settings.historyLength, historyPts, alt)
      lastScreen = now + 1000 * RTH.settings.historyLength / historyPts
   end
   
   if RTH.var.currentPosition and RTH.var.startTakeoff and RTH.var.gearUp then
      local GSdeg = 6
      local curr2gearUpB = gps.getBearing(RTH.var.currentPosition, RTH.var.gearUp)
      local gearUp2toB = gps.getBearing(RTH.var.startTakeoff, RTH.var.gearUp)
      --print("gearUp2toB", gearUp2toB)
      local curr2gearUpD = gps.getDistance(RTH.var.currentPosition, RTH.var.gearUp)
      local curr2toD = gps.getDistance(RTH.var.currentPosition, RTH.var.startTakeoff)
      local curr2toB = gps.getBearing(RTH.var.currentPosition, RTH.var.startTakeoff)
      local gearUp2toD = gps.getDistance(RTH.var.startTakeoff, RTH.var.gearUp)
      local deltaB = curr2gearUpB - gearUp2toB
      --local deltaD = curr2toD
      if math.abs(deltaB) < 10 then
	 RTH.var.ilsLoc = 10 * deltaB
	 --print("D", curr2toB - gearUp2toB)
	 if curr2toB - gearUp2toB > -45 and curr2toB - gearUp2toB < 45 then
	    RTH.var.ilsGS = 10 * (GSdeg - math.deg(math.atan(alt, math.abs(curr2toD))))
	 else
	    RTH.var.ilsGS = nil
	 end
      else
	 RTH.var.ilsLoc = nil
	 RTH.var.ilsGS = nil
      end
   else
      --print("no currentPosition")
   end
   
   if system.getTimeCounter() > oncePerSecond then -- and sendState == state.COMPLETE then --and
      --not form.getActiveForm() then
      --ALBattCheck()
      oncePerSecond = system.getTimeCounter() + 1000
   end

   if emflag ~= 0 then
      local P4 = system.getInputs("P4") -- to show json only on emulator
      if P4 then
	 LOOPTIME = 200*(P4 + 1)
	 --print("LOOPTIME", LOOPTIME)
      end
   end

   if system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
   end
   
   if switchItems.pageChange then setpNT() end

   local gs = RTH.settings
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      local temp
      temp = RTH.curPos
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      if RTH.curPos and temp then
	 if gps.getDistance(temp, RTH.curPos) > 5 then --5m dist min to compute heading
	    RTH.lastPos = temp
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
      if RTH.curPos and lt ~= 0 and lg ~= 0 and not RTH.initPos then
	 RTH.gpsReads = RTH.gpsReads + 1
      end
      if RTH.gpsReads > 9 and not RTH.initPos then
	 system.messageBox("DFM-RTH: GPS zero set")
	 print("DFM-RTH: GPS zero set")
	 RTH.initPos = RTH.curPos
	 if not RTH.zeroPos then
	    RTH.zeroPos = RTH.curPos
	 end
	 if not RTH.var.zeroPos then
	    RTH.var.zeroPos = RTH.curPos
	 end
	 initField(RTH.var.zeroPos) -- if maps info has been read, get the field
      end
   end

   if pageMax > 0 and (now > lastSend + LOOPTIME) then

      if RTH.curPos and RTH.zeroPos then
	 RTH.gpsBearingFrom = gps.getBearing(RTH.curPos, RTH.zeroPos)
	 RTH.gpsBearingTo = gps.getBearing(RTH.zeroPos, RTH.curPos)	    
	 RTH.gpsDistance = gps.getDistance(RTH.curPos, RTH.zeroPos)
	 if RTH.lastPos then
	    RTH.gpsHeading = gps.getBearing(RTH.lastPos, RTH.curPos)
	 end
      end

      if (not switchItems.pageChange) then pageNumberTele = pageNumber end

      if not pageNumberTele or pageNumberTele < 1 then return end
      if not RTH.page[pageNumberTele] then return end

      for k,v in ipairs(RTH.page[pageNumberTele]) do
	 if v.widgetID >= 0 then
	    if cfgimg.instruments[v.widgetID].wtype == "arcGauge" then
	       hasArcGauge = true
	    end
	    if cfgimg.instruments[v.widgetID].scale ~= "fixed" then
	       scale = "variable"
	    else
	       scale = "fixed"
	    end
	    if scale == "variable" then -- if min/max not set pick up defaults
	       minV = v.minV or cfgimg.instruments[v.widgetID].minV
	       maxV = v.maxV or cfgimg.instruments[v.widgetID].maxV
	    else
	       minV = cfgimg.instruments[v.widgetID].minV
	       maxV = cfgimg.instruments[v.widgetID].maxV 
	    end
	 end

	 v.value = nil
	 sensor = {}
	 if (v.sensorId ~= 0) and (v.sensorPa ~= 0) then
	    if v.sensorId == -1 then -- special sensors, derived values
	       if v.sensorPa == 1 then
		  if RTH.gpsDistance then
		     sensor.valid = true
		     sensor.value = RTH.gpsDistance
		  else
		     sensor.valid = false
		  end
	       elseif v.sensorPa == 2 or v.sensorPa == 3 or v.sensorPa == 4 then -- bearing to or from 
		  if RTH.gpsBearingTo and v.sensorPa == 2 then--                  or heading
		     sensor.valid = true
		     sensor.value = RTH.gpsBearingTo
		  elseif RTH.gpsBearingFrom and v.sensorPa == 3 then
		     sensor.valid = true
		     sensor.value = RTH.gpsBearingFrom
		  elseif RTH.gpsHeading and v.sensorPa == 4 then
		     sensor.valid = true
		     sensor.value = RTH.gpsHeading
		  else
		     sensor.valid = false
		  end
	       elseif v.sensorPa == 5 or v.sensorPa == 7 then -- t1sec and t1pct
		  if RTH.timers.timer1.state == RTH.timers.stateSTOP then
		     if ud1 == "up" then
			RTH.timers.timer1.start = now - RTH.timers.timer1.time
		     else
			RTH.timers.timer1.start = now + RTH.timers.timer1.time
		     end
		  end
		  if ud1 == "up" then
		     RTH.timers.timer1.time = (now - RTH.timers.timer1.start)
		     sensor.tpct = 100 * RTH.timers.timer1.time /
			(RTH.timers.timer1.target - RTH.timers.timer1.initial)
		     sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
		  else
		     RTH.timers.timer1.time = (RTH.timers.timer1.start - now)
		     sensor.tpct = 100 * RTH.timers.timer1.time /
			(RTH.timers.timer1.initial - RTH.timers.timer1.target)
		     sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
		  end
		  if v.sensorPa == 5 then
		     sensor.value = math.floor(100 * RTH.timers.timer1.time / 1000) / 100
		  else
		     sensor.value = (sensor.tpct or 0)
		  end

		  sensor.valid = true
	       elseif v.sensorPa == 6 or v.sensorPa == 8 then --t2sec and t2pct
		  if RTH.timers.timer2.state == RTH.timers.stateSTOP then
		     if ud2 == "up" then
			RTH.timers.timer2.start = now - RTH.timers.timer2.time
		     else
			RTH.timers.timer2.start = now + RTH.timers.timer2.time
		     end
		  end
		  if ud2 == "up" then
		     RTH.timers.timer2.time = (now - RTH.timers.timer2.start)
		     sensor.tpct = 100 * RTH.timers.timer2.time /
			(RTH.timers.timer2.target - RTH.timers.timer2.initial)
		     sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
		  else
		     RTH.timers.timer2.time = (RTH.timers.timer2.start - now)
		     sensor.tpct = 100 * RTH.timers.timer2.time /
			(RTH.timers.timer2.initial - RTH.timers.timer2.target)
		     sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
		  end
		  if v.sensorPa == 6 then
		     sensor.value = math.floor(100 * RTH.timers.timer2.time / 1000) / 100
		  else
		     sensor.value = (sensor.tpct or 0)
		  end
		  sensor.valid = true
	       elseif v.sensorPa == 9 then
		  sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P1")) / 2
		  sensor.valid = true
	       elseif v.sensorPa == 10 then
		  sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P2")) / 2
		  sensor.valid = true
	       elseif v.sensorPa == 11 then
		  sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P3")) / 2
		  sensor.valid = true
	       elseif v.sensorPa == 12 then
		  sensor.value = minV + (maxV - minV) * (1 + system.getInputs("P4")) / 2
		  sensor.valid = true
	       elseif v.sensorPa == 13 and sharedVar["DFM-TimG"] then -- remaining time
		  sensor.value = sharedVar["DFM-TimG"].remaining or 0
		  sensor.valid = true
	       elseif v.sensorPa == 14 and sharedVar["DFM-TimG"] then -- elapsed time
		  sensor.value = sharedVar["DFM-TimG"].elapsed or 0
		  sensor.valid = true
	       end
	    else
	       sensor = system.getSensorByID(v.sensorId, v.sensorPa)
	    end
	    if sensor and sensor.valid then
	       v.value = sensor.value
	       if v.convertIdx then
		  v.value = v.value * RTH.convertVal[v.convertIdx][1] +
		     RTH.convertVal[v.convertIdx][2]
	       end
	       if v.zeroOffset then
		  v.value = v.value - v.zeroOffset
	       end
	       if not v.value then print("v.value nil") end
	    end
	 end

	 v.value2 = nil -- value2 can only be for compass or ahGauge now...
	 sensor = {}
	 if v.sensorId2 and v.sensorId2 ~= 0 and v.sensorPa2 and v.sensorPa2 ~= 0 then
	    if v.sensorId2 == -1 then -- special sensors, derived values
	       if v.sensorPa2 == 1 then
		  if RTH.gpsDistance then
		     sensor.valid = true
		     sensor.value2 = RTH.gpsDistance
		  else
		     sensor.valid = false
		  end
	       elseif v.sensorPa2 == 2 or v.sensorPa2 == 3 or v.sensorPa2 == 4 then
		  if RTH.gpsBearingTo and v.sensorPa2 == 2 then
		     sensor.valid = true
		     sensor.value = RTH.gpsBearingTo
		  elseif RTH.gpsBearingFrom and v.sensorPa2 == 3 then
		     sensor.valid = true
		     sensor.value = RTH.gpsBearingFrom
		  elseif RTH.gpsHeading and v.sensorPa2 == 4 then
		     sensor.valid = true
		     sensor.value = RTH.gpsHeading
		  else
		     sensor.valid = false
		  end
	       elseif v.sensorPa2 == 9 then
		  sensor.value = 45 * system.getInputs("P1")
		  sensor.valid = true
	       elseif v.sensorPa2 == 10 then
		  sensor.value = 45 * system.getInputs("P2")
		  sensor.valid = true
	       elseif v.sensorPa2 == 11 then
		  sensor.value =  1 + system.getInputs("P3")
		  sensor.valid = true
	       elseif v.sensorPa2 == 12 then
		  sensor.value = 50 * (1 + system.getInputs("P4"))
		  sensor.valid = true
	       end
	       if sensor and sensor.valid then
		  v.value2 = sensor.value
	       end
	    else
	       sensor = system.getSensorByID(v.sensorId2, v.sensorPa2)
	       if sensor and sensor.valid then
		  v.value2 = sensor.value
	       end
	    end
	 end
      end
      
      -- if we don't match the glasses config, or there is a menu open don't
      -- send the 200 ms json to the glasses

      local sendJson = true
      if not RTH.var.statusAL then
	 --print("not statusAL")
	 sendJson = false
      else
	 if RTH.var.statusAL.Conn == 0 then
	    --print(".Conn is 0")
	    sendJson = false
	 end
	 if RTH.var.statusAL.Conf ~= RTH.var.statusAL.GlassConf then
	    --print(".Conf ~=")
	    sendJson = false
	 end 
	 if form.getActiveForm() then
	    --print("getActiveForm")
	    sendJson = false
	 end
	 if sendState ~= state.COMPLETE then
	    sendJson = false
	 end
      end
      
      loopCPU = system.getCPU()

      local fmt = RTH.page[pageNumberTele][1].fmtNumber
      local numInsts = #cfgimg.config[fmt]

      sendIndex = sendIndex + 1
      if sendIndex <= numInsts then
	 if not form.getActiveForm() then
	    sendAL(sendIndex, pageNumberTele)
	 end
      end

      if hasArcGauge then -- have to slow down update rate for fat arcs
	 --print("clamp looptime")
	 LOOPTIME = math.max(LOOPTIME, 280)
      end

      if sendIndex >= numInsts and now - lastSend > LOOPTIME then
	 local cc, err
	 --print("@@", system.getTimeCounter() - lastSend, LOOPTIME, hasArcGauge)
	 ALFlushReset(false) -- clear graphics engine hold state before sending new frame
	 teleSerial = {}
	 for k,v in ipairs(savedSerialReset) do
	    teleSerialReset[k] = v
	    if sendJson then
	       cc, err = serial.write(sidSerial, v)
	       if not cc then
		  print("DFM-RTH: serial write error " .. err)
	       else
		  serialBytesSent = serialBytesSent + cc
	       end
	    end
	 end
	 --print("#savedSerialReset", #savedSerialReset)
	 for k,v in ipairs(savedSerial) do
	    teleSerial[k] = v
	    if sendJson then
	       cc, err = serial.write(sidSerial, v)
	       if not cc then
		  print("DFM-RTH: serial write error " .. err)
	       else
		  serialBytesSent = serialBytesSent + cc
	       end
	    end
	 end
	 --print("#savedSerial", #savedSerial)
	 sendIndex = 0
	 savedSerial = {}
	 savedSerialReset = {} -- was sent once, don't send again
	 resetGlasses = 0

	 lastSend = now	 
      end
      --lastSend = now	 
   end

   if unow <= jsonHoldTime then return end

   local LINESPERLOOP = 1
   local line   
   local bw
   
   if sendState == state.DISCONNECTED then
      local bufCfg = "FFD302070101AA"
      --local imgCfg = "FF4702070102AA"
      --local fntCfg = "FF5002070103AA"
      --[[
      local bw = serialWriteDirect(sidSerial, encodeBuf(bufCfg)) -- read config
      if not bw then
	 print("DFM-RTH: cannot write config query")
      end
	 local bw = serialWriteDirect(sidSerial, encodeBuf(imgCfg)) -- read config
      if not bw then
	 print("DFM-RTH: cannot write image query")
      end

      local bw = serialWriteDirect(sidSerial, encodeBuf(fntCfg)) -- read config
      if not bw then
	 print("DFM-RTH: cannot write image query")
      end
      --]]
      --local bw = serialWriteDirect(sidSerial, encodeBuf(bufCfg..imgCfg..fntCfg)) -- read config
      local bw = serialWriteDirect(sidSerial, encodeBuf(bufCfg)) -- read config
      if not bw then
	 print("DFM-RTH: cannot write config query")
      end
      
      jsonHoldTime = unow + 1000
      sendState = state.WAITING -- wait for onRead to get config list
      enterWaiting = system.getTimeCounter()

   elseif sendState == state.WAITING then
      if system.getTimeCounter() - enterWaiting > 2000 then --no response to config request in 2 sec
	 sendState = state.DISCONNECTED
	 --print("DFM-RTH: No cfg response .. set DISCONNECTED and retry")
	 jsonHoldTime = unow + 1000 -- wait 1 more sec then try config request again
      end

   elseif sendState == state.ALMOST then
      print("DFM-RTH: state COMPLETE")
      sendState = state.COMPLETE
      splashScreen = nil -- don't redisplay it on reconnect
      writeInst()
      resetGlasses = 1


   elseif sendState == state.SELECT then
      local bufSet = "FFD2000D" .. appHex .. "00AA"      
      local bufClr = "FF010005AA"
      local bufFls = "FF390006FFAA"
      local bufDsp = "FF42000A0100000000AA"

      print("DFM-RTH: state SELECT")
      
      local bw1, bw2, bw3
      bw1 = serialWriteDirect(sidSerial, encodeBuf(bufSet)) -- set glasses to our app
      bw2 = serialWriteDirect(sidSerial, encodeBuf(bufClr)) -- clear screen
      bw3 = serialWriteDirect(sidSerial, encodeBuf(bufFls)) -- flush, set to known state
      
      if not bw1 or not bw2 or not bw3 then
	 print("DFM-RTH: cannot write select")
	 if sendFP then io.close(sendFP) end
	 sendState = state.DISCONNECTED
	 jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
      else
	 print("DFM-RTH: state ALMOST")
	 savedSerial = {}
	 savedSerialReset = {}
	 teleSerial = {}
	 teleSerialReset = {}
	 sendState = state.ALMOST
	 --writeInst()
	 serialWriteDirect(sidSerial, encodeBuf(bufDsp))
	 if splashScreen then
	    --aprint("SPLASH!")
	    jsonHoldTime = unow + 3000 -- wait 3s to allow setup, clear, flush and disp splash screen
	 end
	 --resetGlasses = 1
	 return
      end
   
   elseif sendState == state.CONNECTED then 
      --if not RTH.settings.configVersion then RTH.settings.configVersion = 0 end
      system.messageBox("DFM-RTH: Preparing Glasses")
      print("DFM-RTH: opening file " .. prefix() .. pathConfigs .. "config-fonts-images.txt")
      sendFP = io.open(prefix() .. pathConfigs .. "config-fonts-images.txt", "r")
      if not sendFP then
	 print("DFM-RTH: cannot open font and image config file")
	 sendState = state.DISCONNECTED
	 jsonHoldTime = unow + 1000
      else
	 print("DFM-RTH: opened config-fonts-images.txt")
	 sendState = state.SENDHEADER
      end
      linecount = 0
      serialBytesSent = 0
      startingTime = system.getTimeCounter()

   elseif (sendState == state.SENDHEADER) or (sendState == state.SENDFOOTER) then
      
      --if not RTH.settings.configVersion then RTH.settings.configVersion = 0 end
      
      local cfgKey = 1
      local bufPre = "FFD00015" .. appHex .. "00"
      local bufH = bufPre .. string.format("%08X%08X", 0, cfgKey) .. "AA"
      local bw
      
      if sendState == state.SENDHEADER then
	 print("DFM-RTH: sending config header")
	 bw = serialWriteDirect(sidSerial, encodeBuf(bufH))
	 if not bw then
	    print("DFM-RTH: cannot write header")
	    if sendFP then io.close(sendFP) end
	    sendState = state.DISCONNECTED
	    jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
	 else
	    jsonHoldTime = unow + 600
	    sendState = state.SENDFILE
	    RTH.var.rememberMe = system.getTimeCounter()
	 end
	 
      elseif sendState == state.SENDFOOTER then
	 local cfgVersion = RTH.var.statusAL.Conf -- read during init()
	 local cfgKey = 1
	 local bufPre = "FFD00015" .. appHex .. "00"
	 local bufF = bufPre .. string.format("%08X%08X", cfgVersion, cfgKey) .. "AA"
	 print("DFM-RTH: Sending config footer, cfgVersion", cfgVersion)
	 bw = serialWriteDirect(sidSerial, encodeBuf(bufF))
	 
	 if not bw then
	    print("DFM-RTH: cannot write footer")
	    if sendFP then io.close(sendFP) end
	    sendState = state.DISCONNECTED
	    jsonHoldTime = unow + 1000 -- wait one sec before possibly sending config request again  
	 else
	    print("DFM-RTH: state to SELECT")
	    sendState = state.SELECT
	 end
	 
	 local dt = system.getTimeCounter() - startingTime
	 serialFileName = string.format("Transfer complete. Time: %.2f s", dt / 1000.0)
	 print(string.format("Send config done. Time: %.2f s", dt / 1000))
	 print(string.format("%d bytes sent. Aggregate data rate: %.1f kB/s",
			     serialBytesSent, serialBytesSent / dt))
	 system.messageBox("DFM-RTH: Transfer complete")
	 RTH.settings.configIDs = {}
	 --for k in ipairs(currentConfigIDs) do -- remember that this config was sent last
	 --   RTH.settings.configIDs[k] = currentConfigIDs[k] 
	 --end
	 jsonHoldTime = system.getTimeCounter() + WAIT_TIME * 40 -- long (!) wait before restarting 200ms json
	 RTH.var.statusAL.GlassConf = RTH.var.statusAL.Conf
	 --RTH.settings.configVersion = 1
      end
      
   elseif sendState == state.SENDFILE then
      --print("sendState is SENDFILE")
      --print("Sendfile", system.getTimeCounter() - RTH.var.rememberMe)
      for i=1, LINESPERLOOP, 1 do
	 line = io.readline(sendFP, true)
	 linecount = linecount + 1
	 if linecount % 5 == 0 then
	    system.messageBox("DFM-RTH: Reading line " .. linecount,5)
	 end
	 if not line then
	    --print("io,readline EOF")
	    sendState = state.SENDFOOTER
	    if sendFP then io.close(sendFP) end
	    break
	 else
	    local ll
	    local ldx=1
	    local chunk = 20
	    repeat
	       ll = string.sub(line, ldx, ldx + chunk - 1)
	       ldx = ldx + chunk
	       --print("> "..ll)
	       bw = serialWriteDirect(sidSerial, encodeBuf(ll))
	       --print("write encoded line, bw", bw, #line)
	    until ldx >= #line
	    
	    if not bw then
	       print("DFM-RTH: cannot write line of config file")
	       if sendFP then io.close(sendFP) end
	       sendState = state.DISCONNECTED
	       jsonHoldTime = unow + 1000
	       break
	    end
	 end
	 jsonHoldTime = unow + 200
      end
   end
   
   --loopCPU = loopCPU + (system.getCPU() - loopCPU) / 10

   
end

local function changedSensor(value, inp, sf)
   --print("changedSensor: val, inp", value, inp)
   if inp ~= 2 then
      RTH.page[pageNumber][gaugeNumber].sensorId = RTH.sensorIdlist[value]
      RTH.page[pageNumber][gaugeNumber].sensorPa = RTH.sensorPalist[value]
      RTH.page[pageNumber][gaugeNumber].sensorLa = RTH.sensorLalist[value]
      RTH.page[pageNumber][gaugeNumber].sensorLs = RTH.sensorLslist[value]
      RTH.page[pageNumber][gaugeNumber].units    = RTH.sensorUnlist[value]
      RTH.page[pageNumber][gaugeNumber].nativeUnits    = RTH.sensorUnlist[value]   
      RTH.page[pageNumber][gaugeNumber].decimals = RTH.sensorDplist[value]
      RTH.page[pageNumber][gaugeNumber].wtype     = RTH.sensorTylist[value]
   else
      RTH.page[pageNumber][gaugeNumber].sensorId2 = RTH.sensorIdlist[value]
      RTH.page[pageNumber][gaugeNumber].sensorPa2 = RTH.sensorPalist[value]
      RTH.page[pageNumber][gaugeNumber].sensorLa2 = RTH.sensorLalist[value]
      RTH.page[pageNumber][gaugeNumber].sensorLs2 = RTH.sensorLslist[value]
      RTH.page[pageNumber][gaugeNumber].units2    = RTH.sensorUnlist[value]   
      RTH.page[pageNumber][gaugeNumber].decimals2 = RTH.sensorDplist[value]
      RTH.page[pageNumber][gaugeNumber].wtype2     = RTH.sensorTylist[value]
   end
   if inp == 0 then
      RTH.page[pageNumber][gaugeNumber].sensorId2 = 0
      RTH.page[pageNumber][gaugeNumber].sensorPa2 = 0
   end
   if sf then form.reinit(sf) end
end


local function changedName(value)
   --print("changedName instName", value, "page, gauge", pageNumber, gaugeNumber)
   RTH.page[pageNumber][gaugeNumber].instName = value
end

local function clearJSON()
   local fn = prefix() .. pathJson .. "GG_" .. modelName.. ".jsn"
   local ans
   ans = form.question("Are you sure?", "Reset all app settings?",
		       "",
		       0, false, 5)
   if ans == 1 then
      io.remove(fn)
      system.messageBox("DFM-RTH: Settings deleted .. Restart App")
      writeJSON = false
   end
   
end



local inpN

local function initForm(sf)

   subForm = sf
   if sf == 1 then
      form.setButton(1, ":add",   ENABLED)
      form.setButton(2, ":up",    ENABLED)
      form.setButton(3, "Edit",   ENABLED)
      form.setButton(4, ":tools", ENABLED)
      
      if not RTH.page or #RTH.page == 0 then
	 form.addRow(1)
	 form.addLabel({label="No pages defined", width = 220})
      else
	 for i in ipairs(RTH.page) do
	    form.addRow(1)
	    form.addLabel({label="Page " .. i, width = 220})
	 end
      end

      form.setFocusedRow(savedRow)

      form.setTitle("Display Pages")
      
      
   elseif sf == 10 then
      form.setButton(1, ":forward", ENABLED)
      form.setButton(2, ":up", ENABLED)

      if gaugeNumber == 0 then gaugeNumber = 1 end
      if pageNumber == 0 then pageNumber = 1 end
      if  #RTH.page < 1 then
	 form.addRow(1)
	 form.addLabel({label="No pages defined"})
	 return
      end
      
      if not RTH.page[pageNumber][gaugeNumber].instName then
	 RTH.page[pageNumber][gaugeNumber].instName = 'Gauge'..gaugeNumber
      end

      if RTH.page[pageNumber][1].fmtNumber < 1 then
	 RTH.page[pageNumber][1].fmtNumber = 1
	 --fmtNumber = 1
      end

      --sift thru avail images and find the ones that are the correct size
      --for this gauge in the selected format

      imageNum = nil
      local widgetID = RTH.page[pageNumber][gaugeNumber].widgetID
      --local imageID = RTH.page[pageNumber][gaugeNumber].imageID
      local fn = RTH.page[pageNumber][1].fmtNumber
      local wid = cfgimg.config[fn][gaugeNumber].width
      local hgt = cfgimg.config[fn][gaugeNumber].height
      --local label

      --print("$ fn, gaugeNumber wid hgt", fn, gaugeNumber, wid, hgt)
      
      editImgs = {}
      local origWidth
      local origHeight
      for i, img in ipairs(cfgimg.instruments) do
	 
	 origWidth = cfgimg.forms[img.formID + 1].width
	 origHeight = cfgimg.forms[img.formID + 1].height
	 
	 if (wid == origWidth) and (hgt == origHeight) then
	    table.insert(editImgs,
			 {widgetID = i, --imageID=img.imageID,
			  --loadImage=img.loadImage,
			  --loadImageSmaller = img.loadImageSmaller,
			  wid = wid, hgt = hgt,
			  --imageWidth=img.imageWidth, imageHeight = img.imageHeight,
			  wtype=img.wtype, inputs=img.inputs, scale = img.scale })
	    if widgetID == i then imageNum = #editImgs end
	 end
      end
      imageMax = #editImgs
      --print("imageMax", imageMax)
      if not imageNum then imageNum = 1 end

      -- isn't imageNum really widgetID??
      
      if widgetID <= 0 then
	 if #editImgs < 1 then
	    print("DFM-RTH: no images for", pageNumber, gaugeNumber)
	 else -- default to first image
	    --print("defaulting widgetID")
	    RTH.page[pageNumber][gaugeNumber].widgetID = editImgs[1].widgetID	    
	    --RTH.page[pageNumber][gaugeNumber].imageID = editImgs[1].imageID
	    RTH.page[pageNumber][gaugeNumber].wtype = editImgs[1].wtype
	 end
      end

      local function setinp(inp, ii)
	 if ii == 0 then inpN = 0 else inpN = inp end
	 form.reinit(12)
      end
      
      inpN = 0
      local inpS
      local ii
      if not editImgs[imageNum] then return end -- only happens if no gauges match this box size - config error

      for inp=1,editImgs[imageNum].inputs do
	 if editImgs[imageNum].inputs == 1 then
	    inpS = "Data source"
	    ii = 0
	 else
	    inpS = "Data source " .. tostring(inp)
	    if editImgs[imageNum].wtype == "ahGauge" then
	       if inp == 1 then
		  inpS = "Pitch"
	       elseif inp == 2 then
		  inpS = "Roll"
	       end
	    elseif editImgs[imageNum].wtype == "compass" then
	       if inp == 1 then
		  inpS = "Bearing"
	       elseif inp == 2 then
		  inpS = "Heading"
	       end
	    end
	    ii = inp
	 end
	 form.addRow(1)
	 form.addLink((function() return setinp(inp, ii) end), {label=inpS.." >"})
      end
      if editImgs[imageNum].wtype ~= "ahGauge" and editImgs[imageNum].wtype ~= "compass" 
	 and editImgs[imageNum].scale == "variable" then
	 
	 local function changedMMscl(value)
	    --print("changeMMscl", value)
	    RTH.page[pageNumber][gaugeNumber].scl = value
	 end
	 
	 local mmscl = {"+/- 10000", "+/- 1000", "+/- 100"}
	 if not RTH.page[pageNumber][gaugeNumber].scl then
	    RTH.page[pageNumber][gaugeNumber].scl = 1
	 end
	 local iscl = RTH.page[pageNumber][gaugeNumber].scl
	 
	 form.addRow(2)
	 form.addLabel({label="Min/Max Scale>"})
	 form.addSelectbox(mmscl, iscl, true, changedMMscl)

	 form.addRow(1)
	 form.addLink((function() form.reinit(13) end), {label="Min/Max >"})

      end
      
      form.setTitle("Page " .. pageNumber .. " Gauge " .. gaugeNumber)
      
      form.setFocusedRow(1)
   elseif sf == 11 then

      form.setTitle("Utilities")
      if emflag ~= 0 then -- emulator only: button to force serial send
	 --form.setButton(1, "USB",   ENABLED)
      end
      
      local function switchChanged(val, name)
	 local swInfo =system.getSwitchInfo(val)
	 if not swInfo.proportional then
	    system.messageBox("Please select as Proportional")
	    return
	 end
	 if not swInfo.assigned then
	    print("Sw unassigned")
	    --pageSw = nil
	    pageNumberTele = nil
	 end
	 changedSwitch(val, name)
      end
      

      

      form.addRow(2)
      form.addLabel({label="Page change switch"})
      swtCI.pageChange = form.addInputbox(switchItems.pageChange, true,
					  (function(x) return switchChanged(x, "pageChange") end)
      )

      form.addRow(1)
      form.addLink((function() form.reinit(20) return end),
	 {label="GPS and ILS setup>>"})

      form.addRow(1)
      form.addLink((function() form.reinit(14) return end), {label="Timer setup>>"})      

      form.addRow(1)
      form.addLink(clearJSON, {label="Reset app settings>>"})
      
      --form.addRow(1)
      --form.addLink((function() sendUSB("full") form.reinit(15) return end), {label="Set up AL Glasses>>"})
      form.addRow(1)
      form.addLink(
	 (
	    function()
	       otaTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       if RTH.settings.rebootDisco then
		  system.messageBox("DFM-RTH: Turn off reboot disconnect")
	       else
		  gpio.write(5,1)
		  print("gpio 5 set high")
		  system.messageBox("DFM-RTH: OTA update initialized")
		  RTH.var.timeOTA = system.getTimeCounter()
		  --form.reinit(11)
	       end
	       return
	 end), {label="Start OTA update>>"}
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       restartTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       gpio.write(6,1)
	       print("gpio 6 set high")
	       system.messageBox("DFM-RTH: Rebooting AL controller")
	       --form.reinit(11)
	       return
	 end), {label="Reboot AL controller>>"}
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       powerDownTimer = system.getTimeCounter() + 500 -- set high for 500ms
	       gpio.write(7,0)
	       print("gpio 7 set low")
	       system.messageBox("DFM-RTH: Cycling AL power")
	       --form.reinit(11)
	       return
	 end), {label="Cycle Power AL controller>>"}
      )

      form.addRow(2)
      form.addLabel({label="Reboot on disconnect", width=270})
      local rdIndex
      rdIndex = form.addCheckbox(RTH.settings.rebootDisco,
				 (function()
				       if not RTH.settings.rebootDisco then
					  RTH.settings.rebootDisco = true
				       else
					  RTH.settings.rebootDisco = not RTH.settings.rebootDisco
				       end
				       form.setValue(rdIndex, RTH.settings.rebootDisco)
				       print("rebootDisco", RTH.settings.rebootDisco)
				       return
				 end)
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       local appd = "DFM-RTH"
	       local pattern = string.format(">BBBI1c%dB", #appd)
	       local len = string.packsize(pattern)
	       serialWriteDirect(sidSerial, string.pack(pattern, 0xFF, 0xD5, 0x00, len,
							appd, 0xAA))
	       system.messageBox("DFM-RTH: Deleted " .. appd .. " from Glasses")
	       local bufCfg = "FFD302070101AA"
	       local bw = serialWriteDirect(sidSerial, encodeBuf(bufCfg)) -- read config
	       if not bw then
		  print("DFM-RTH: cannot write config query")
	       end
	       return
	 end), {label="Delete app from glasses >>"}
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       local pattern = ">BBBI1B"
	       local len = string.packsize(pattern)
	       serialWriteDirect(sidSerial, string.pack(pattern, 0xEE, 0x02, 0x00, len,
							0xBB))
	       system.messageBox("DFM-RTH: Bound")
	 end), {label="Bind these glasses >>"}
      )

      form.addRow(1)
      form.addLink(
	 (
	    function()
	       local pattern = ">BBBI1B"
	       local len = string.packsize(pattern)
	       serialWriteDirect(sidSerial, string.pack(pattern, 0xEE, 0x03, 0x00, len,
							0xBB))
	       system.messageBox("DFM-RTH: Unbound")
	 end), {label="Unbind glasses >>"}
      )

   elseif sf == 12 then

      local isel = 0
      for k = 1, #RTH.sensorLalist do
	 if inpN ~= 2 then
	    if (RTH.sensorIdlist[k] == RTH.page[pageNumber][gaugeNumber].sensorId) and
	       (RTH.sensorPalist[k] == RTH.page[pageNumber][gaugeNumber].sensorPa) then
	       isel = k
	       break
	    end
	 else
	    if (RTH.sensorIdlist[k] == RTH.page[pageNumber][gaugeNumber].sensorId2) and
	       (RTH.sensorPalist[k] == RTH.page[pageNumber][gaugeNumber].sensorPa2) then
	       isel = k
	       break
	    end
	 end
      end

      form.addRow(2)
      form.addLabel({label="Sensor:", font=FONT_NORMAL})
      form.addSelectbox(RTH.sensorLalist, isel, true,
			(function(x) return changedSensor(x, inpN, 12) end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      local sd = RTH.page[pageNumber][gaugeNumber].decimals or 0
      local txt = string.format("Sensor Decimals: %d", sd)
      form.addRow(1)
      form.addLabel({label=txt, font=FONT_NORMAL})

      local sc = RTH.page[pageNumber][gaugeNumber].units or '-'
      txt = string.format("Sensor Units: %s", sc)
      form.addRow(1)
      form.addLabel({label=txt, font=FONT_NORMAL})

      form.addRow(2)
      form.addLabel({label="Unit conversion:", font=FONT_NORMAL})

      if not RTH.page[pageNumber][gaugeNumber].convertIdx then
	 RTH.page[pageNumber][gaugeNumber].convertIdx = 1
      end

      local cvi = RTH.page[pageNumber][gaugeNumber].convertIdx

      local function changedConversion(val)
	 --print("pageNumber, gaugeNumber, val", pageNumber, gaugeNumber, val)
	 RTH.page[pageNumber][gaugeNumber].convertIdx =  val
	 if RTH.convertUnits[val] == "-" then --val == 1 then -- val is 1 means no conversion
	    if RTH.page[pageNumber][gaugeNumber].nativeUnits then
	       RTH.page[pageNumber][gaugeNumber].units =
		  RTH.page[pageNumber][gaugeNumber].nativeUnits
	    end
	 else
	    RTH.page[pageNumber][gaugeNumber].units = RTH.convertUnits[val]
	 end
	 form.reinit(12)
	 
      end

      form.addSelectbox(RTH.convertStr, cvi, true, changedConversion)

      form.addRow(2)
      form.addLabel({label="Displayed Decimals", font=FONT_NORMAL})

      if not RTH.page[pageNumber][gaugeNumber].dispdec then
	 RTH.page[pageNumber][gaugeNumber].dispdec = sd
      end
      
      local function changedDispDec(val)
	 RTH.page[pageNumber][gaugeNumber].dispdec = val
      end
      
      local dd = RTH.page[pageNumber][gaugeNumber].dispdec
      form.addIntbox(dd, 0, 2, sd, 0, 1, changedDispDec)

      local maj, majD
      local wid = RTH.page[pageNumber][gaugeNumber].widgetID
      local cid = cfgimgESP.instruments[wid]
      local fid = cid.formID + 1
      majD = cfgimgESP.forms[fid].major
      maj = RTH.page[pageNumber][gaugeNumber].major
      if not maj then maj = majD end
      
      if majD then -- if they key "major" exists (it's a gauge, not an arc or ...)
	 local function changedMajor(val)
	    RTH.page[pageNumber][gaugeNumber].major = val
	 end
	 form.addRow(2)
	 form.addLabel({label="Major divisions", font=FONT_NORMAL})      
	 form.addIntbox(maj, 2, 12, majD, 0, 1, changedMajor)
      end
      
      form.addRow(2)
      form.addLabel({label="Zero offset", font=FONT_NORMAL})

      if not RTH.page[pageNumber][gaugeNumber].zeroOffset then
	 RTH.page[pageNumber][gaugeNumber].zeroOffset = 0
      end
      
      local function changedZeroOffset(val)
	 RTH.page[pageNumber][gaugeNumber].zeroOffset = val
      end
      
      local zo = RTH.page[pageNumber][gaugeNumber].zeroOffset
      form.addIntbox(zo, -32768, 32767, 0, 0, 1, changedZeroOffset)

      form.addRow(2)
      form.addLabel({label="Marker value", font=FONT_NORMAL})

      local mk = RTH.page[pageNumber][gaugeNumber].marker or 0
      
      if not RTH.page[pageNumber][gaugeNumber].marker then
	 RTH.page[pageNumber][gaugeNumber].marker = mk
      end
      
      local function changedMarker(val)
	 RTH.page[pageNumber][gaugeNumber].marker = val
	 --print("marker", val)
      end
      
      form.addIntbox(mk, -32768, 32767, 0, 0, 1, changedMarker)
      
      form.addRow(2)
      form.addLabel({label="Gauge Name:", font=FONT_NORMAL})
      form.addTextbox(RTH.page[pageNumber][gaugeNumber].instName, 10,
		      (function(x) return changedName(x, inpN) end),
		      {width=155, font=FONT_NORMAL})

      
   elseif sf == 13 then

      local id, minV, maxV
      
      --fn = RTH.page[pageNumber][1].fmtNumber
      id = RTH.page[pageNumber][gaugeNumber].widgetID
      if id < 0 then
	 print("DFM-RTH: no images")
	 return
      end

      local scale = cfgimg.instruments[id].scale
      
      if scale == "fixed" or not RTH.page[pageNumber][gaugeNumber].minV then
	 minV = cfgimg.instruments[id].minV
      else
	 minV = RTH.page[pageNumber][gaugeNumber].minV
      end

      if scale == "fixed" or not RTH.page[pageNumber][gaugeNumber].maxV then
	 maxV = cfgimg.instruments[id].maxV
      else
	 maxV = RTH.page[pageNumber][gaugeNumber].maxV
      end      
      
      if cfgimg.instruments[id].scale == "variable" then
	 local scl = RTH.page[pageNumber][gaugeNumber].scl - 1
	 local mult = 10 ^ scl

	 local function minChanged(value)
	    RTH.page[pageNumber][gaugeNumber].minV = value / mult  --/ 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Min value"})
	 form.addIntbox(minV*mult, -10000, 10000, 0, scl, 1, minChanged)

	 local function maxChanged(value)
	    RTH.page[pageNumber][gaugeNumber].maxV = value / mult --/ 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Max value"})
	 form.addIntbox(maxV*mult, -10000, 10000, 10000, scl, 1, maxChanged)
      else
	 if not minV or not maxV then
	    form.addRow(1)
	    form.addLabel({label="Min/Max not applicable"})
	 else
	    form.addRow(2)
	    form.addLabel({label="Min value (fixed)"})
	    form.addLabel({label=string.format("%.1f", minV)})
	    form.addRow(2)
	    form.addLabel({label="Max value (fixed)"})
	    form.addLabel({label=string.format("%.1f", maxV)})	 	 
	 end
      end
   elseif sf == 14 then
      local hrs=0
      local mins, secs, sign      
            
      local function changedMS(val, tn, u, tm, tmud)
	 local tt = {hrs=hrs, mins=mins, secs=secs}
	 local tmsg = {timer1="Timer 1 ", timer2="Timer 2 "}
	 local umsg = {initial = "Initial Value ", target = "Target Value "} 
	 tt[u] = val
	 mins, secs, sign = ms(RTH.timers[tn][tm])
	 local ss = 1
	 if RTH.timers[tn][tmud] == "-" then ss = -1 end
	 RTH.timers[tn][tm] = ss * (tt.secs + 60 * tt.mins) * 1000
	 mins, secs, sign = ms(RTH.timers[tn][tm])
	 form.setTitle(string.format(tmsg[tn]..umsg[tm]..sign.."%02d:%02d", mins, secs))
      end

      local function timerPMChanged(x, tn, ud)
	 RTH.timers[tn][ud] = string.sub("+-", x, x)
	 sign = RTH.timers[tn][ud]
	 if sign == "-" then
	    RTH.timers[tn].initial = math.abs(RTH.timers[tn].initial) * -1
	 else
	    RTH.timers[tn].initial = math.abs(RTH.timers[tn].initial)	    
	 end
      end
      
      local plusminus = {"+", "-"}

      form.addRow(1)
            form.addLabel({label=string.rep(" ", 28) .. "Timer 1", font=FONT_BOLD})
      
      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      local isel = string.find("+-", (RTH.timers.timer1.initialUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer1", "initialUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(RTH.timers.timer1.initial)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer1", "mins", "initial", "initialUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer1", "secs", "initial", "initialUD") end),
		     {width=60}
      )
      
      form.addRow(8)
      form.addLabel({label="Target:", width=65})
      isel = string.find("+-", (RTH.timers.timer1.targetUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer1", "targetUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(RTH.timers.timer1.target)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer1", "mins", "target", "targetUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer1", "secs", "target", "targetUD") end),
		     {width=60}
      )

      form.addRow(4)
      form.addLabel({label="Run Sw", width=65})
      --local swe = "t1enable"
      swtCI.t1enable = form.addInputbox(switchItems.t1enable, true,
		       (function(x) return changedSwitch(x, "t1enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      --local swr = "t1reset"
      swtCI.t1reset = form.addInputbox(switchItems.t1reset, true,
		       (function(x) return changedSwitch(x, "t1reset") end),
		       {width=100}
      )

      -------------------------------------------------------------------------
      
      form.addRow(1)
      form.addLabel({label=string.rep(" ", 28) .. "Timer 2", font=FONT_BOLD})

      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      isel = string.find("+-", (RTH.timers.timer2.initialUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer2", "initialUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(RTH.timers.timer2.initial)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer2", "mins", "initial", "initialUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer2", "secs", "initial", "initialUD") end),
		     {width=60}
      )
      
      form.addRow(8)
      form.addLabel({label="Target:", width=65})
      isel = string.find("+-", (RTH.timers.timer2.targetUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer2", "targetUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(RTH.timers.timer2.target)

      form.addLabel({label="Mins", width=45})      
      form.addIntbox(mins, 0, 99, 10, 0, 1,
		     (function(x) return changedMS(x, "timer2", "mins", "target", "targetUD") end),
		     {width=60}
      )

      form.addLabel({label="Secs", width=45})
      
      form.addIntbox(secs, 0, 59, 0, 0, 1,
		     (function(x) return changedMS(x, "timer2", "secs", "target", "targetUD") end),
		     {width=60}
      )

      form.addRow(4)
      form.addLabel({label="Run Sw", width=65})
      --local swe = "t2enable"
      swtCI.t2enable = form.addInputbox(switchItems.t2enable, true,
		       (function(x) return changedSwitch(x, "t2enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      --local swr = "t2reset"
      swtCI.t2reset = form.addInputbox(switchItems.t2reset, true,
		       (function(x) return changedSwitch(x, "t2reset") end),
		       {width=100}
      )
      
      form.setFocusedRow(1)
      form.setTitle("Timer Setup")

   elseif sf == 15 then
      --form.addRow(1)
      --form.addLabel({label="sf15"})
      --form.setButton(1, "Exit",   ENABLED)
      --form.setTitle("Serial data transfer")
      
   elseif sf == 20 then -- GPS and ILS setup

      local latsel = 0
      local lngsel = 0
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
      
      local altsel = 0
      for k = 1, #RTH.sensorLalist do
	 if (RTH.sensorIdlist[k] == RTH.settings.altId) and
	    (RTH.sensorPalist[k] == RTH.settings.altPa) then
	    altsel = k
	 end
      end
      
      form.addRow(2)
      form.addLabel({label="Takeoff switch"})
      swtCI.takeoff = form.addInputbox(switchItems.takeoff, true,
					  (function(x) return  switchChanged(x, "takeoff") end)
      )
      
      form.addRow(2)
      form.addLabel({label="Gear up switch"})
      swtCI.gearUp = form.addInputbox(switchItems.gearUp, true,
					  (function(x) return  switchChanged(x, "gearUp") end)
      )

      form.addRow(2)
      form.addLabel({label="GPS Lat Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.gpsLalist, latsel, true,
			(function(i)
			      RTH.settings.latId = RTH.gpsIdlist[i]
			      RTH.settings.latPa = RTH.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="GPS Lng Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.gpsLalist, lngsel, true,
			(function(i)
			      RTH.settings.lngId = RTH.gpsIdlist[i]
			      RTH.settings.lngPa = RTH.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="Altitude Sensor", font=FONT_NORMAL})
      form.addSelectbox(RTH.sensorLalist, altsel, true,
			(function(i)
			      RTH.settings.altId = RTH.sensorIdlist[i]
			      RTH.settings.altPa = RTH.sensorPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})
      
      form.addRow(2)
      form.addLabel({label="Flt path timeline (s)", font=FONT_NORMAL})
      form.addIntbox(RTH.settings.historyLength, 10, 100, 20, 0, 1,
		     (function(x) RTH.settings.historyLength = x end))

      form.addRow(2)
      form.addLabel({label="Flt path perp dist (m)", font=FONT_NORMAL})
      form.addIntbox(RTH.settings.distMan, 10, 500, 100, 0, 1,
		     (function(x) RTH.settings.distMan = x end))

      form.addRow(2)
      form.addLabel({label="Flt path screen width (m)", font=FONT_NORMAL, width=250})
      form.addIntbox(RTH.settings.fltWidth, 10, 1000, 200, 0, 1,
		     (function(x) RTH.settings.fltWidth = x end), {width=60})

      form.addRow(2)
      form.addLabel({label="Map screen width (m)", font=FONT_NORMAL, width=250})
      form.addIntbox(RTH.settings.mapWidth, 100, 1000, 200, 0, 1,
		     (function(x) RTH.settings.mapWidth = x end), {width=60})


      form.addRow(2)
      form.addLabel({label="Map display dist/bearing", width=270})
      local dbIndex
      dbIndex = form.addCheckbox(RTH.settings.displayDB,
				 (function()
				       if not RTH.settings.displayDB then
					  RTH.settings.displayDB = true
				       else
					  RTH.settings.displayDB = not RTH.settings.displayDB
				       end
				       form.setValue(dbIndex, RTH.settings.displayDB)
				       print("displayDB", RTH.settings.displayDB)
				       return
				 end)
      )


      form.addRow(2)
      form.addLabel({label="Comet tail timeline (s)", font=FONT_NORMAL, width=250})
      form.addIntbox(RTH.settings.cometTailLength, 1, 60, 10, 0, 1,
		     (function(x) RTH.settings.cometTailLength = x end), {width=60})

      form.addRow(2)
      form.addLabel({label="Comet tail points", font=FONT_NORMAL})
      form.addIntbox(RTH.settings.cometPts, 1, 10, 7, 0, 1,
		     (function(x) RTH.settings.cometPts = x end))

   end
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end

local function clearPage(pn, gm)
   RTH.page[pn] = {}
   for k=1,gm do
      RTH.page[pn][k] = {}
      RTH.page[pn][k].sensorId = 0
      RTH.page[pn][k].sensorPa = 0	 
      RTH.page[pn][k].sensorLs = "..."
      RTH.page[pn][k].sensorLa = "..."	    
      RTH.page[pn][k].units = "-"
      RTH.page[pn][k].decimals = 0
      RTH.page[pn][k].dispdec = nil
      --RTH.page[pn][k].imageID = -1
      RTH.page[pn][k].widgetID = -1
      RTH.page[pn][k].value = 0.0
      RTH.page[pn][k].instName = "GG"..k
      RTH.page[pn][k].sensorId2 = 0
      RTH.page[pn][k].sensorPa2 = 0      
      RTH.page[pn][k].scl = 1
   end
   RTH.page[pn][1].fmtNumber = 1
end

local function keyPressed(key)

   local fmtNumber
   local iid
   if pageNumber < 1 or #RTH.page < 1 then
      fmtNumber = 1
   else
      fmtNumber = RTH.page[pageNumber][1].fmtNumber
   end

   --print("key pressed", key)
   --updateConfigIDs()

   if subForm == 1 then

      if keyExit(key) then
	 if key ~= KEY_ESC then
	    form.preventDefault()
	    savedRow = form.getFocusedRow()
	    form.reinit(1)
	 else
	    writeInst()
	 end
      end
   
      if key == KEY_1 then
	 if pageMax < pageLimit then
	    pageMax = pageMax + 1
	    clearPage(pageMax, gaugeMax)
	 end
	 form.reinit(1)
      elseif key == KEY_2 then
	 if pageNumber < 1 then
	    system.messageBox("DFM-RTH: No pages defined")
	    return
	 end
	 clearPage(pageNumber, gaugeMax)
	 fmtNumber = fmtNumber + 1
	 if fmtNumber > #cfgimg.config then fmtNumber = 1 end
	 RTH.page[pageNumber or 1][1].fmtNumber = fmtNumber
	 savedRow = form.getFocusedRow()
	 form.reinit(1)
	 return
      elseif key == KEY_3 or key == KEY_ENTER then
	 savedRow = form.getFocusedRow()
	 if savedRow > 0 then
	    pageNumber = savedRow
	    gaugeNumber = 1
	    teleSerial = {}
	    teleSerialReset = {}
	    form.reinit(10)
	 else
	    system.messageBox("DFM-RTH: No pages defined")
	    form.reinit(1)
	 end
      elseif key == KEY_4 then
	 form.reinit(11)
      end
   elseif subForm == 10 then
      if keyExit(key) then
	 form.preventDefault()
	 imageNum = nil
	 form.reinit(1)
      end
      if key == KEY_1 then
	 local fm = RTH.page[pageNumber][1].fmtNumber
	 local mx = #cfgimg.config[fm]
	 if gaugeNumber + 1 > mx then	 
	    gaugeNumber = 1
	 else
	    gaugeNumber = gaugeNumber + 1
	 end
	 imageNum = nil
	 form.reinit(10)
	 return
      elseif key == KEY_2 then
	 imageNum = imageNum + 1
	 if imageNum > imageMax then imageNum = 1 end
      end
      if key == KEY_2 then
	 iid = 0
	 local wid = 0
	 local min, max, wtype, inp
	 --print("key2: imageNum, editImgs[imageNum].widgetID", imageNum, editImgs[imageNum].widgetID)
	 
	 for i,img in ipairs(cfgimg.instruments) do
	    if i == editImgs[imageNum].widgetID then
	       --print("key2 match")
	    --if img.imageID == editImgs[imageNum].imageID then
	       wid = i
	       --iid = img.imageID
	       min = img.minV
	       max = img.maxV
	       wtype = img.wtype
	       inp = img.inputs
	    end
	 end
	 --print("key2 set widgetID", wid)
	 RTH.page[pageNumber][gaugeNumber].widgetID = wid	 
	 --RTH.page[pageNumber][gaugeNumber].imageID = iid
	 --RTH.page[pageNumber][gaugeNumber].minV = min -- may be nil
	 --RTH.page[pageNumber][gaugeNumber].maxV = max -- may be nil
	 RTH.page[pageNumber][gaugeNumber].wtype = wtype
	 --RTH.page[pageNumber][gaugeNumber].inputs = inp

	 form.reinit(10)
      end
   elseif subForm == 11 then
      if key == KEY_1 then
	 print("subForm 11 sendUSB full")
	 sendUSB("full")
	 form.reinit(15)
      end
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   elseif subForm == 12 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(10)
      end
   elseif subForm == 13 or subForm == 14 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   elseif subForm == 15 then
      if keyExit(key) or key == KEY_ENTER then
	 --print("sf 15, keyExit, key", keyExit(key), key)
	 form.preventDefault()
	 --form.reinit(1)
      elseif key == KEY_1 then
	 form.reinit(1)
      end
   end
end

local function drawRectangleGlass(x0, y0, xl, yl)
   local f = 0.55
   lcd.drawRectangle(f*x0 - f*xl / 2, f*y0 - f*yl / 2, f*xl, f*yl)
end

local function printForm(w,h)

   local fmtNumber
   local r = 144/160 -- jeti screen size vs. pixel ht on glasses
   local offset = w - 144
   --local fudge = 131 -- extra bytes sent that are not in files
   if subForm == 15 then
      lcd.setColor(0,0,255)
      --lcd.drawFilledRectangle(10, 20, (w-20) * serialBytesSent / (totalSendBytes + fudge), 30)
      lcd.setColor(0,0,0)
      lcd.drawText(10, 60, string.format("Bytes sent: %d", serialBytesSent))
      lcd.drawText(10, 80, serialFileName)
   elseif subForm == 10 then

      if imageNum and imageNum > 0 and editImgs[imageNum] then

	 local wid = editImgs[imageNum].wid
	 local hgt = editImgs[imageNum].hgt
	 local gpg = RTH.page[pageNumber][gaugeNumber]
	 --[[
	 gpg.widgetID = editImgs[imageNum].widgetID
	 gpg.imageID = editImgs[imageNum].imageID
	 --gpg.minV = editImgs[imageNum].minV
	 --gpg.maxX = editImgs[imageNum].maxV
	 gpg.wtype = editImgs[imageNum].wtype
	 --gpg.inputs = editImgs[imageNum].inputs
	 --]]
	 
	 local bw = w / 2
	 local bh = h
	 local rr
	 local xoffset -- = w / 2 + w / 4
	 local yoffset -- = h / 2

	 lcd.setColor(0,0,0)

	 if wid > 144 and hgt < 50 then  -- horiz gauges and text gauges
	    rr = 0.8
	    xoffset, yoffset = w / 2, 3 * h / 4
	    lcd.drawFilledRectangle(w / 8, h/2 , 3 * w / 4, h / 2)
	    --lcd.drawFilledRectangle(0, h/2 , w, h / 2)
	 else
	    rr = 0.6
	    xoffset, yoffset = w / 2 + w / 4, h / 2
	    lcd.drawFilledRectangle(w - bw, 0, bw, bh)
	 end

	 sendAL(gaugeNumber, pageNumber, 0)

	 for k,v in ipairs(savedSerialReset) do
	    teleSerialReset[k] = v
	 end
	 for k,v in ipairs(savedSerial) do
	    teleSerial[k] = v
	 end

	 for k,v in ipairs(teleSerialReset) do
	    decodeAL(v, rr, xoffset, yoffset, wid, hgt)
	 end
	 for k,v in ipairs(teleSerial) do
	    decodeAL(v, rr, xoffset, yoffset, wid, hgt)
	 end

	 savedSerialReset = {}
	 savedSerial = {}
	 teleSerialReset = {}
	 teleSerial = {}

      else
	 lcd.setColor(0,0,0)
	 --lcd.drawText(200,80, "imageNum " .. (imageNum or "nil") .." " .. #editImgs)
	 lcd.drawText(200,60, "No Image")
      end
   elseif subForm == 1 then
      local fr = form.getFocusedRow()
      if fr <= pageMax and fr > 0 then pageNumber =  fr end
      
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(310-167, 0, 167, 141)

      lcd.setColor(0,0,0)
      lcd.setClipping(310-167, 0, 167, 141)

      lcd.drawRectangle(0, 0, 167, 141)
      lcd.setColor(200,200,200)
      lcd.drawRectangle(33/2, 28/2, 134, 113)
      lcd.setColor(0,0,0)

      if pageNumber < 1 or not RTH.page[pageNumber] then return end
      
      fmtNumber = RTH.page[pageNumber][1].fmtNumber
      if fmtNumber > 0 then
	 local gp = cfgimg.config[fmtNumber]
	 for g,t in ipairs(gp) do
	    drawRectangleGlass(t.jxc, t.jyc, t.width, t.height)
	 end
      end
      lcd.drawText(2,0,string.format("%d", fmtNumber))
      lcd.resetClipping()
   end
end

local function printTeleSmall(w,h)
   if pageNumberTele and pageNumberTele > 0 then
      drawTextCenter(20, 10, string.format("Page %d", pageNumberTele), FONT_MINI)
   end

   lcd.drawImage(45, 3, glassesIcon)
   if not RTH.var.statusAL or system.getTime() - lastRead > 5 then
      lcd.drawImage(75, 3, redcrossIcon)
      return
   end

   if RTH.var.statusAL and RTH.var.statusAL.Conn then
      if RTH.var.statusAL.Conn == 1 then
	 drawTextCenter(110, 10, string.format("%d%%", RTH.var.statusAL.Batt), FONT_MINI)
	 if (RTH.var.statusAL.Conf == RTH.var.statusAL.GlassConf) then -- 
	    lcd.drawImage(75, 3, greencheckIcon)
	 else
	    lcd.drawImage(75, 3, yellowpauseIcon)	 
	 end
      else
	 lcd.drawImage(75, 3, yellowpauseIcon)	 
      end
   end
end

local function printTele(w,h)

   local fmt
   local gpp
   local sgc
   local r = 160/256 -- Jeti height / Glasses height
   local offset = (319 - r * 304) / 2 --  center glasses box on Jeti screen

   -- Select the appropriate page (controlled by assigned switch or line in menu)
   -- Individual dynamic widget info stored in RTH.page[pageNumber][gaugeNumber].property

   if not switchItems.pageChange  then pageNumberTele = pageNumber end

   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159) -- black background over entire window
   lcd.setColor(255,255,255)            -- rest of animation (needles, etc) is white

   if pageNumberTele and pageNumberTele > 0 then
      lcd.drawText(10, 10, string.format("Page %d", pageNumberTele))
   end

   local offline = RTH.var.statusAL.Conn ~= 1 -- system.getTime() - lastRead > 10

   lcd.drawImage(265, 15, glassesIcon)
   if not RTH.var.statusAL or offline then
      lcd.drawImage(295, 15, redcrossIcon)
   end

   if RTH.var.statusAL and RTH.var.statusAL.Conn and not offline then
      if RTH.var.statusAL.Conn == 1 then
	 lcd.drawImage(272,  40, batteryIcon)
	 drawTextCenter(287, 70, string.format("%d%%", RTH.var.statusAL.Batt), FONT_MINI)
	 if (RTH.var.statusAL.Conf == RTH.var.statusAL.GlassConf) then 
	    lcd.drawImage(295, 15, greencheckIcon)
	 else
	    lcd.drawImage(295, 15, yellowpauseIcon)	    
	 end
      else
	 lcd.drawImage(295, 15, yellowpauseIcon)	 
      end
      --drawTextCenter(287,120, string.format("C:%d", RTH.var.statusAL.Conf), FONT_MINI)
      --drawTextCenter(287,135, string.format("CG:%d", RTH.var.statusAL.GlassConf), FONT_MINI)
      drawTextCenter(287,135, string.format("%d", RTH.var.statusAL.Conf), FONT_MINI)
   end
      
   if RTH.var.statusAL and RTH.var.statusTime and RTH.var.statusAL.Conn == 1 and
      system.getTimeCounter() < RTH.var.statusTime + 5000 then
      drawTextCenter(287, 90, "G", FONT_MINI)
   else
      local now = system.getTime()
      drawTextCenter(287, 90, "Searching", FONT_MINI)
      if emflag ~= 0 then
	 lcd.drawText(10,50, sendState)
      end
      --print("state:", sendState)
   end

   --print("printTele", pageNumberTele)
   
   if not pageNumberTele or pageNumberTele < 1 then return end

   local xr, yr, xc, yc
   local min, max, val, val2, lbl
   local ccfg, cid, fid

   gpp = RTH.page[pageNumberTele]
   if not gpp then
      lcd.drawTextCenter(160, 80, "No pages defined")
      print("DFM-RTH: RTH.page[pageNumberTele] is nil")
      return
   end

   --local legacy = false
   
   if (sendState == state.ALMOST) and splashScreen then
      lcd.drawImage(offset + 20, 20, splashScreen)
      return
   end

   local rr = 160/256

   -- next params determined empirically
   
   --local xoffset = 253 --200 * (system.getInputs("P7") + 1) 
   --local yoffset = 153 --200 * (system.getInputs("P8") + 1)

   local wid, hgt = 0,0 --cfgimg.forms[fid].width, cfgimg.forms[fid].height)

   lcd.setClipping(offset, 0, 304*r, (256-7)*r)
   -- next params determined empirically
   -- to center map in glasses window
   local xoffset = 190
   local yoffset = 155

   --print("#teleSerialReset", #teleSerialReset)
   for k,v in ipairs(teleSerialReset) do
      decodeAL(v, rr, xoffset, yoffset, wid, hgt)
   end
   --print("#teleSerial", #teleSerial)
   for k,v in ipairs(teleSerial) do
      decodeAL(v, rr, xoffset, yoffset, wid, hgt)
   end
   --end

   lcd.resetClipping()
   
   lcd.drawRectangle(offset, 0, 304*r, (256-7)*r) -- draw scaled glasses hw screen as box

   
   --lcd.setColor(255,255,255)
   --local npts = #pos3D.x
   --if npts > 0 then
   --   lcd.drawText(80, 110, string.format("x: %.1f", pos3D.x[npts]), FONT_MINI)
   --   lcd.drawText(80, 120, string.format("y: %.1f", pos3D.y[npts]), FONT_MINI)
   --   lcd.drawText(80, 130, string.format("z: %.1f", pos3D.z[npts]), FONT_MINI)
   --end
   
   sgc = system.getCPU()

   if emflag ~= 0 then
      lcd.drawText(10,130, string.format("%d", sgc))
      lcd.drawText(10,110, string.format("%d", loopCPU))
      lcd.drawText(10, 90, string.format("%d", LOOPTIME))
   end
end

local function destroy()

   --print("closing")
   --if (logFileFP) then
   --   io.close(logFileFP)
   --end
   
   local fp
   local fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"

   if not writeJSON then
      return
   end

   --replace Id and Pa with hex values .. limited precision of JSON conversion
   --turning these (especially Id) into floats mangles them
   for k, v in pairs(RTH.page) do
      for kk,vv in pairs(v) do
	 for kkk, vvv in pairs(vv) do
	    if  kkk == "sensorId" or kkk == "sensorPa" or kkk == "sensorId2" or kkk == "sensorPa2" then
	       vv[kkk] = string.format("0X%X", math.floor(vvv)) 
	    end
	 end
      end
   end

   for k,v in pairs(RTH.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa"
	 or k == "altId" or k == "altPa" then
	 RTH.settings[k] = string.format("0X%X", math.floor(v))
      end
   end

   RTH.timers.timer1.start = 0 -- no need to save these
   RTH.timers.timer1.time = 0 
   
   RTH.timers.timer2.start = 0
   RTH.timers.timer2.time = 0
   
   local GGtbl = {}
   GGtbl.page = RTH.page
   GGtbl.settings = RTH.settings
   GGtbl.timers = RTH.timers
   GGtbl.settings.jsnVersion = JSNVERSION
   GGtbl.switchInfo = RTH.switchInfo
   
   fp = io.open(fn, "w")
   if fp then
      local jt = json.encode(GGtbl)
      if not jt then print("json encode error GGtbl") else
	 io.write(fp, json.encode(GGtbl), "\n")
	 io.close(fp)
      end
      print("DFM-RTH - State saved " .. fn)
   else
      print("DFM-RTH - Could not save state")
   end
end

--local savedData
local onReadBuf = ""

local function onRead(indata)

   local MAX_ALOOK_CMD = 533
   local cmd_len
   local command
   
   --local str = "indata ==> "
   --for i=1,#indata,1 do
   --   str = str .. string.format("0x%02X ", string.byte(indata, i))
   --end
   --print(str)

   --print("#onReadBuf", #onReadBuf)
   onReadBuf = onReadBuf .. indata

   local loops = 0
   
   ::start::

   loops = loops + 1
   
   if #onReadBuf < 1 or string.byte(onReadBuf, 1) ~= 0xFF then
      print("DFM-RTH: CS_INVALID - bad format")
      local str = "command: "
      for i=1,#indata,1 do
	 str = str .. string.format("0x%02X ", string.byte(indata, i))
      end
      print(str)
      onReadBuf = ""
      return
   end
   
   cmd_len = string.byte(onReadBuf, 4)
   --print("DFM-RTH: cmd_len", cmd_len)
   
   if not cmd_len then
      --print("too short")
      return
   end -- input too short to have len 
   
   if cmd_len > MAX_ALOOK_CMD then
      print("DFM-RTH: CS_INVALID - too long")
      onReadBuf = ""
      return
   end

   if #onReadBuf < cmd_len then -- incomplete .. wait for more data
      --print("waiting for more data")
      return
   end

   if string.byte(onReadBuf, cmd_len) == 0xAA then -- complete and valid Alook reply

      --str = "DFM-RTH onRead complete Cmd ==> "
      --for i=1,cmd_len,1 do
      -- str = str .. string.format("0x%02X ", string.byte(onReadBuf, i))
      --end
      --print(str)
      
      command = string.sub(onReadBuf, 1, cmd_len)
      onReadBuf = string.sub(onReadBuf, cmd_len+1, -1)
      --print("#onReadBuf len after sub", #onReadBuf)

      --print("onRead", string.format("0x%02x", string.byte(command,2)))
      
      if string.byte(command, 2) == 0xD3 then -- cfglist
	 local name, size, version, usgCnt, installCnt, isSystem
	 print("DFM-RTH onRead: cfgList response")
	 local i = 7 -- first char of cfg payload (see AL docs section 4.14)

	 -- RTH.var.statusAL.Conf is the version of the font file
	 -- (config-fonts-images.txt) which has the expected fonts and splash
	 -- screen and is built by the build system in
	 -- ~/JS/DFM-RTHBuild/makeHUD.py this is read during init() from
	 -- DFM-RTH/Json/config-version.jsn When required, increment this
	 -- version in DFM-RTHBuild/Configs/config-version.jsn
	 
	 repeat
	    name, size, version, usgCnt, installCnt, isSystem =
	       string.unpack(">zI4I4I1I1I1", command, i)
	    print(string.format("DFM-RTH ALOOK app: %s Size %d Version %d", name, size, version))
	    if name == "DFM-RTH" then
	       RTH.var.statusAL.GlassConf = version
	    end
	    i = i + #name + 1 + 11 -- 11 is 4+4+1+1+1 ("I4I4I1I1I1")
	 until i >= cmd_len

	 print("DFM-RTH: RTH.var.statusAL.GlassConf, RTH.var.statusAL.Conf",
	       RTH.var.statusAL.GlassConf, RTH.var.statusAL.Conf)
	 
	 if RTH.var.statusAL.GlassConf ~= RTH.var.statusAL.Conf then
	    sendState = state.CONNECTED --send the preparation info and font file
	 else
	    --sendState = state.CONNECTED -- for testing .. do every time
	    sendState = state.SELECT -- glasses have current info 
	 end
      elseif string.byte(command, 2) == 0x47 then -- image list
	 print("DFM-RTH onRead: image list response")
	 if cmd_len <= 7 then
	    print("DFM-RTH onRead: no images")
	 else
	    local i = 7
	    repeat
	       local id, height, width = 
		  string.unpack(">I1I2I2", command, i)
	       print(string.format("DFM-RTH ALOOK image: id %d height %d width %d", id, height, width))
	       i = i + 5 + 1 -- 5 is 1+2+2 ("I1I2I2")
	    until i >= cmd_len
	 end
      elseif string.byte(command, 2) == 0x05 then -- battery level
	 --print("DFM-RTH Battery level (%)", string.byte(command, 5))
	 RTH.var.statusAL.Batt = string.byte(command, 5)
	 RTH.var.statusAL.Conn = 1
	 lastRead = system.getTime()	 
	 RTH.var.statusTime = system.getTimeCounter()
      elseif string.byte(command, 2) == 0x50 then -- font list
	 print("DFM-RTH onRead: font list response")
	 local id, height
	 local i = 7 -- first char of cfg payload (see AL docs section 4.14)
	 repeat
	    id, height = string.unpack(">I1I1", command, i)
	    print("DFM-RTH ALOOK Font: id " .. id .. " height " .. height)
	    i = i + 2
	 until i >= cmd_len
      elseif string.byte(command,2) == 0xE2 then -- error
	 local cmdId, err, subErr = string.unpack(">I1I1I1", command, 5)
	 print(string.format("DFM-RTH: onRead -  cmdID 0x%02x, error 0x%02x, subErr 0x%02x",
			     cmdId, err, subErr))
      elseif string.byte(command, 2) == 0xA2 then -- use deprecated code 0xA2 for return ctrl msgs
	 local errTxt = {"Go", "Stop", "Message Error", "Overflow", "Missing cfgwrite", "Unknown state"}
	 if string.byte(command, 5) <= #errTxt then
	    print(string.format("DFM-RTH: onRead - ALOOK control says: " ..
				errTxt[string.byte(command, 5)]))
	    if string.byte(command, 5) == 2 then
	       print("DFM-RTH: Flow control delay")
	       lastSend = system.getTimeCounter() + 200
	    end
	 elseif string.byte(command, 5) == 0x0a then
	    print("DFM-RTH: Glasses Disconnected")
	    system.messageBox("DFM-RTH: Glasses Disconnected")
	    RTH.var.statusAL.Conn = 0
	    local now = system.getTimeCounter()
	    if now > initTime + 120 and wasEverGreen and RTH.settings.rebootDisco then
	       wasEverGreen = false
	       restartTimer = now + 500 -- set high for 500ms
	       gpio.write(6,1)
	       print("DFM-RTH: gpio 6 set high rebootDisco")
	       --system.messageBox("DFM-RTH: Rebooting AL controller")
	       system.playBeep(2, 440, 200)
	    end
	    sendState = state.DISCONNECTED
	    lastRead = 0
	 elseif string.byte(command, 5) == 0x0f then
	    print("DFM-RTH: Gesture received")
	    gestureTime = system.getTimeCounter() + 1000
	 end
      else
	 print("DFM-RTH: onRead - command[2]", string.format("0x%02x", string.byte(command,2)))
	 local str = "DFM-RTH: onRead full response: "
	 for i=1,#command,1 do
	    str = str .. string.format("0x%02X ", string.byte(command, i))
	 end
	 print(str)
      end
      
   end
   --print("onRead", #onReadBuf, loops)

   -- 4 is arbitrary ... to guard against inf loop if garbled data
   if #onReadBuf > 0 and loops < 4 then goto start end

end

local function gestureCB()
   if gestureTime ~= 0 and system.getTimeCounter() < gestureTime then
      --print("logging 1")
      return 1
   else
      gestureTime = 0
      return 0
   end
end

local function init()

   local fn

   RTH.var.statusAL = {}
   --RTH.var.statusAL.Conf = 1 -- this is the required version of the glasses config
   RTH.var.statusAL.GlassConf = 0
   RTH.var.statusAL.Conn = 0
   RTH.var.statusAL.Batt = 0
   
   initTime = system.getTime()
   --tenSecTimer = initTime
   
   sendState = state.DISCONNECTED
   jsonHoldTime = system.getTimeCounter()-- + 10 * WAIT_TIME

   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   --print("0", system.getCPU())
   
   readSensors(Glass)
   
   --print("0.1", system.getCPU())

   system.registerForm(1, MENU_APPS, "DFM-RTH", initForm, keyPressed, printForm)

   --[[
   fn = prefix() .. pathJson .. "instr.jsn"
   
   local file = io.readall(fn)
   cfgimg = {}
   if file then
      cfgimg = json.decode(file)
      print("DFM-RTH: Reading avail instruments from ", fn)
   else
      system.messageBox("DFM-RTH: Cannot read " .. fn)
      return
   end
   --]]
   
   print("CPU 1", system.getCPU())
   
   fn = prefix() .. pathJson .. "instrESP.jsn"
      
   file = io.readall(fn)
   cfgimgESP = {}
   if file then
      cfgimgESP = json.decode(file)
      cfgimg = cfgimgESP
      print("DFM-RTH: Reading avail instruments (ESP) from ", fn)
   else
      system.messageBox("DFM-RTH: Cannot read " .. fn)
      return
   end

   -- Read the version of the font and splash screen data that
   -- is contained in Configs/config-fonts-images.txt
   
   fn = prefix() .. pathJson .. "config-version.jsn"
      
   file = io.readall(fn)

   if file then
      RTH.var.statusAL.Conf = math.floor(json.decode(file).version)
      print("DFM-RTH: Reading data config from ", fn)
   else
      system.messageBox("DFM-RTH: Cannot read " .. fn)
      return
   end

   print("DFM-RTH: RTH.var.statusAL.Conf", RTH.var.statusAL.Conf)
   
   fn = prefix() .. pathImages .."DFML7Small.png"
   splashScreen = lcd.loadImage(fn)
   print("splashScreen", splashScreen)
   fn = prefix() .. pathImages .. "glasses.png"
   glassesIcon = lcd.loadImage(fn)
   fn = prefix() .. pathImages .. "redcross.png"
   redcrossIcon = lcd.loadImage(fn)
   fn = prefix() .. pathImages .. "greencheck.png"
   greencheckIcon = lcd.loadImage(fn)   
   fn = prefix() .. pathImages .. "battery.png"   
   batteryIcon = lcd.loadImage(fn)   
   fn = prefix() .. pathImages .. "yellowpause.png"
   yellowpauseIcon = lcd.loadImage(fn)      
   
   local device
   device, emflag = system.getDeviceType() 
   print("Device", device, "emflag", emflag)
   
   local success, descr
   local portlist = serial.getPorts()
   for k,v in pairs(portlist) do
      print("DFM-RTH: Available COM port "..k..": ".. v)
   end

   local baud = 115200
   
   if emflag ~= 0 then
      sidSerial, descr = serial.init("ttyUSB0", baud)
      os.setlocale("C")
   else
      sidSerial, descr = serial.init("COM1", baud)
   end
   
   if sidSerial then   
      print("DFM-RTH: Serial port init succeeded: ", sidSerial)
      serial.setBaudrate(sidSerial, baud)
      success, descr = serial.onRead(sidSerial,onRead)   
      if success then
	 --print("Glass: Callback registered")
      else
	 print("DFM-RTH: Error setting callback", descr)
      end
   else
      print("DFM-RTH: Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "DFM-RTH Display", 4, printTele)
   system.registerTelemetry(2, "DFM-RTH Status", 1, printTeleSmall)   

   local function initG()
      print("DFM-RTH: No saved state")

      RTH.page = {}
      pageMax = #RTH.page
      pageNumber = 0
      gaugeNumber = 1

      RTH.settings = {}
      RTH.settings.latId = 0
      RTH.settings.latPa = 0
      RTH.settings.lngId = 0
      RTH.settings.lngPa = 0
      RTH.settings.altId = 0
      RTH.settings.altPa = 0
      
      RTH.timers = {}
      RTH.timers.stateSTOP = 0
      RTH.timers.stateRUN = 1
      RTH.timers.timer1 = {state = RTH.timers.stateSTOP, time=0, start=0,
			     target=0, initial = 300 * 1000}
      RTH.timers.timer2 = {state = RTH.timers.stateSTOP, time=0, start=0,
			     target=0, initial = 300 * 1000}
   end

   print("CPU 2", system.getCPU())   

   local GGtbl
   fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"
   file = io.readall(fn)
   if file then
      GGtbl = json.decode(file)      
      RTH.page = GGtbl.page
      RTH.settings = GGtbl.settings
      RTH.timers  = GGtbl.timers
      RTH.switchInfo = GGtbl.switchInfo
      if #RTH.page > 0 then
	 pageNumber = 1
	 pageMax = #RTH.page
      end
      gaugeNumber = 1
      if not RTH.timers then RTH.timers = {} end
      RTH.timers.timer1.time = 0
      RTH.timers.timer2.time = 0   
      RTH.timers.stateSTOP = 0
      RTH.timers.stateRUN = 1
   else
      initG()
   end

   print("4", system.getCPU())
   
   if not RTH.switchInfo then RTH.switchInfo = {} end
      
   if not RTH.settings then RTH.settings = {} end
   if not RTH.settings.jsnVersion or RTH.settings.jsnVersion ~= JSNVERSION then
      print("old JSON in "..fn.. " - starting with no saved state")
      initG()
      system.messageBox("DFM-RTH: settings reset")
   end
   
   --if not RTH.settings.configVersion then RTH.settings.configVersion = 0 end
   if not RTH.settings.distMan then RTH.settings.distMan = 200 end
   if not RTH.settings.fltWidth then RTH.settings.fltWidth = 200 end
   if not RTH.settings.historyLength then RTH.settings.historyLength = 20 end
   if not RTH.settings.cometTailLength then RTH.settings.cometTailLength = 10 end
   if not RTH.settings.cometPts then RTH.settings.cometPts = 7 end
   if not RTH.settings.mapWidth then RTH.settings.mapWidth = 200 end
   if not RTH.settings.displayDB then RTH.settings.displayDB = true end      

   -- unHex the Pa and Id numbers (they get garbled if stored as floating point by the
   -- CJSON library)
   
   for k, v in pairs(RTH.page) do
      for kk,vv in pairs(v) do
	 if vv.sensorId then
	    vv.sensorId = tonumber(vv.sensorId)
	 end
	 if vv.sensorPa then
	    vv.sensorPa = tonumber(vv.sensorPa)
	 end
	 if vv.sensorId2 then
	    vv.sensorId2 = tonumber(vv.sensorId2)
	 end
	 if vv.sensorPa2 then
	    vv.sensorPa2 = tonumber(vv.sensorPa2)
	 end
      end
   end

   print("4.2", system.getCPU())

   for k,v in pairs(RTH.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa"
	 or k == "altId" or k == "altPa" then
	 RTH.settings[k] = tonumber(v)
      end
   end

   print("4.5", system.getCPU())
      
   RTH.gpsReads = 0
   RTH.initPos = nil
   RTH.curPos = nil
   RTH.zeroPos = nil
   
   RTH.timers.timer1.state = RTH.timers.stateSTOP
   RTH.timers.timer2.state = RTH.timers.stateSTOP

   if not RTH.timers.timer1.initial then
      RTH.timers.timer1.start = 0
      RTH.timers.timer1.initial = 300 * 1000 -- 5:00 in ms
      RTH.timers.timer1.time = 300 * 1000
   else
      RTH.timers.timer1.start = 0
      RTH.timers.timer1.time = RTH.timers.timer1.initial
   end
   if not RTH.timers.timer1.target then
      RTH.timers.timer1.target = 0 -- 0:00
   end
   
   if not RTH.timers.timer2.initial then
      RTH.timers.timer2.start = 0
      RTH.timers.timer2.initial = 300 * 1000 -- 5:00 in ms
      RTH.timers.timer2.time = 300 * 1000
   else
      RTH.timers.timer2.start = 0
      RTH.timers.timer2.time = RTH.timers.timer2.initial
   end
   if not RTH.timers.timer2.target then
      RTH.timers.timer2.target = 0 -- 0:00
   end

   print("4.6", system.getCPU())
   
   for k, swi in pairs(RTH.switchInfo) do
      local t = string.sub(swi.name,1,1)
      --print("k, swi", k, swi.name, swi.mode, swi.activeOn)
      switchItems[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
   end

   --if not RTH.settings.configVersion then RTH.settings.configVersion = 0 end
   
   --updateConfigIDs()
   --if not RTH.settings.configIDs or RTH.settings.configVersion == 0 then
   --   RTH.settings.configIDs = {}
   --end
   
   setpNT()

   print("5", system.getCPU())
   
   writeInst() --- will also get done in loop() based on tenSecTimer

   --gpio 6 drives the D2 pin on the ESP32 for reboot
   --gpio 5 drives the D0 pin on the ESP32 for OTA start
   --gpio 7 drives the power-on circuit via P3-3 (IO7)
   
   gpio.mode(5, "out-pp");
   gpio.mode(6, "out-pp");
   gpio.mode(7, "out-pp");
   
   gpio.write(5,0) -- set to 1 to start OTA
   gpio.write(6,0) -- set to 1 to reboot
   gpio.write(7,1) -- turn power on

   --[[
   if not RTH.settings.logSeq then
      RTH.settings.logSeq = 1
   else
      RTH.settings.logSeq = RTH.settings.logSeq + 1
      if RTH.settings.logSeq > 10 then RTH.settings.logSeq = 1 end
   end
   
   local lfn = string.format("logfile%d.txt", RTH.settings.logSeq)

   logFileFP = io.open(prefix() .. pathJson .. lfn, "w")
   --]]
   
   system.registerLogVariable("ALGesture", "", gestureCB) 

   --debugging GPS points for ILS at Black Dirt Field
   ---[[
   if emflag ~= 0 then
      RTH.settings.latId = 3
      RTH.settings.latPa = 2
      RTH.settings.lngPa = 3
      RTH.var.startTakeoff = gps.newPoint(41.34062, -74.43160)
      RTH.var.gearUp = gps.newPoint(41.337295, -74.430496)
      RTH.var.zeroPos = gps.newPoint(41.33980, -74.43146)
      RTH.var.startTakeoffAlt = 0
   end
   --]]

   file = io.readall(prefix() .. 'Apps/DFM-Maps/Maps/Fields.jsn')
   if file then
      RTH.var.Fields = json.decode(file)
   else
      RTH.var.Fields = nil
   end

   print("DFM-RTH: CPU end init(): ", system.getCPU())
   print("DFM-RTH: system.getSensorByID", system.getSensorByID)
   print("DFM-RTH: emulator_getSensorByID", emulator_getSensorByID)
   --dumpGlobalVars()
   
end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.01", name=appName}
