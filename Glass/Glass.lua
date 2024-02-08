--[[

   -----------------------------------------------------------------------------------------
   Glass.lua -- write telemetry values to the serial link for AR glasses

   Requires transmitter firmware 4.22 or higher
    
   Developed on DS-24, only tested on DS-24

   -----------------------------------------------------------------------------------------
   Glass.lua released under MIT license by DFM 2024
   -----------------------------------------------------------------------------------------

--]]

local appName = "Glass"
local pathApp = "Apps/"..appName.."/"
local pathImages = pathApp.."Images/"
local pathConfigs = pathApp.."Configs/"
local pathJson = pathApp.."Json/"
local JSNVERSION = 4

local Glass = {}

Glass.sensorLalist = {"..."}
Glass.sensorLslist = {"..."}
Glass.sensorIdlist = {0}
Glass.sensorPalist = {0}
Glass.sensorUnlist = {"-"}
Glass.sensorDplist = {0}
Glass.sensorTylist = {0}

Glass.gpsLalist = {"..."}
Glass.gpsLslist = {"..."}
Glass.gpsIdlist = {0}
Glass.gpsPalist = {0}

Glass.settings = {}
Glass.timers = {}
Glass.switchInfo = {}
Glass.var = {}

--Glass.switches = {}

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
local encodedImgs = {}
local id2avail = {}
local editImgs = {}
local imageNum
local imageMax
local modelName
local state = {IDLE = 1, STANDBY = 2,SENDHEADER = 3, SENDFONTS = 4, SENDIMGS = 5,
	       SENDFOOTER = 6, SENDACTIVE = 7, SENDFMTS = 8, WAITING = 9}
local sendState = state.IDLE
local startingTime = 0
local WAIT_TIME = 200
local sendCtrlCount
local sendFP, sendFPser
local sendImgs
local sendImgsIdx
local sendAA
local sendFF
local sendTime
local sendLast = 0
local cpu = 0
local configLine
local writeJSON = true
local jsonHoldTime = 0
local tempCall
local sendFPtemp
local cfgimg = {}
local glassesIcon
local redcrossIcon
local greencheckIcon
local batteryIcon
local configIDs
local currentConfigIDs
local serialBytesSent = 0

--[[
local teleSensors
local txTeleSensors
local txSensorNames = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		       "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		       "rxBVoltage", "rxBPercent", "photoValue"}
local txSensorUnits = {"V", "%", "mA", "mAh", "%", "V", "%", "V", "V", "%", " "}
local txSensorDP    = { 1,   0,    0,     0,   0,   1,   0,   1,   1,   0,   0}
local txRSSINames = {"rx1Ant1", "rx1Ant2", "rx2Ant1", "rx2Ant2",
		     "rxBAnt1", "rxBAnt2"}
--]]

local function updateConfigIDs()
   -- note the current configuration of which imageIDs are used.
   -- redo whenver we hit a key so it's always current
   local iid 
   currentConfigIDs = {}
   for p,v in ipairs(Glass.page) do
      for g in ipairs(v) do
	 iid = math.floor(Glass.page[p][g].imageID)
	 if Glass.page[p][g].imageID >= 0 then
	    table.insert(currentConfigIDs, iid)
	 end
      end
   end
end

local function sortUniq(tt, ttc)
   local inc
   local outk = 1
   ttc[outk] = tt[1]
   for k in ipairs(tt) do
      for j = 1, #ttc, 1 do
	 inc = false
	 if (tt[k] == ttc[j]) then
	    inc = true
	    break
	 end
      end
      if not inc then
	 outk = outk + 1
	 ttc[outk] = tt[k]
      end
   end
   table.sort(ttc)
end

   
local function matchConfigID(t1, t2)

   --if not t1 or not t2 or (#t1 ~= #t2) then return false end
   local t1c, t2c = {}, {}

   sortUniq(t1, t1c)
   sortUniq(t2, t2c)

   local s = ""
   for k,v in ipairs(t1c) do
      s = s..v.." "
   end
   print("t1c " .. s)

   s = ""
   for k,v in ipairs(t2c) do
      s = s..v.." "
   end
   print("t2c " .. s)


   local ret = true
   for k in ipairs(t2) do
      if t1c[k] ~= t2c[k] then
	 ret = false
	 break
      end
   end
   print("matchConfigID ret",  ret)
   return ret
end

local function drawImage(x,y,imgt, key)

   --if type(imgt[key]) ~= "table" then
   --   print("loading image " .. imgt[key])
   --   imgt[key] = lcd.loadImage(imgt[key])
   --end
   
   return lcd.drawImage(x,y,imgt[key])
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
      print("cS, prop, swTyp", prop, swTyp, swInfo.mode, Invert, swInfo.value)
      if prop or (swInfo.value == Invert) or swTyp == "L" or swTyp =="M" then
	 print("CS assigning")
	 switchItems[switchName] = val
	 Glass.switchInfo[switchName] = {} 
	 Glass.switchInfo[switchName].name = swInfo.label
	 if swTyp == "L" or swTyp =="M" then
	    Glass.switchInfo[switchName].activeOn = 0
	 else
	    local ao = system.getInputs(string.upper(swInfo.label))
	    Glass.switchInfo[switchName].activeOn = ao
	 end
	 Glass.switchInfo[switchName].mode = swInfo.mode
      else
	 system.messageBox("Error - do not move switch when assigning")
	 print("CS zeroing")
	 form.setValue(swtCI[switchName], nil)
	 switchItems[switchName] = nil
	 Glass.switchInfo[switchName] = nil	 
      end
   else
      if Glass.switchInfo[switchName] then
	 print("CS zeroing - not assigned")
	 switchItems[switchName] = nil
	 Glass.switchInfo[switchName] = nil
      end
   end
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function drawTextCenter(x, y, str, font)
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

local function hms(ival)
   local val
   if not ival then val = 0 else val = ival / 1000 end
   local sign
   if val > 0 then sign = "+" elseif val < 0 then sign = "-" else sign = " " end
   local aval = math.abs(val)
   local hrs = aval // (3600)
   local mins = (aval - hrs * 3600) // 60
   local secs = math.floor(aval - hrs * 3600 - mins * 60)
   return hrs, mins, secs, sign
end

local function dpFmt(x)
   if math.abs(x) - math.floor(math.abs(x)) == 0 then
      return "%d"
   end
   if math.abs(10*x) - math.floor(math.abs(10*x)) == 0 then
      return "%.1f"
   end
   return "%.2f"
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
   
   local function insertSp(tbl, id, pa, la, ls)
      table.insert(tbl.sensorLalist, la)
      table.insert(tbl.sensorLslist, ls)
      table.insert(tbl.sensorIdlist, id)
      table.insert(tbl.sensorPalist, pa)
   end

   insertSp(tt, -1, 1, "GPS_Distance", "Distance")
   insertSp(tt, -1, 2, "GPS_BearingTo", "BearingTo")
   insertSp(tt, -1, 3, "GPS_BearingFrom", "BearingFrom")   
   insertSp(tt, -1, 4, "T_Timer1", "Timer1Secs")
   insertSp(tt, -1, 5, "T_Timer2", "Timer2Secs")
   insertSp(tt, -1, 6, "T_Timer1Pct", "Timer1Pct")
   insertSp(tt, -1, 7, "T_Timer2Pct", "Timer2Pct")   

   --[[
   teleSensors = #tt.sensorLalist
   l1 = "txTel"
   for i, label in ipairs(txSensorNames) do
      table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, i)
      table.insert(tt.sensorUnlist, txSensorUnits[i])
      table.insert(tt.sensorDplist, txSensorDP[i])
   end
   txTeleSensors = #tt.sensorLalist

   l1 = "txRSSI"
   for i, label in ipairs(txRSSINames) do
   table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, -i)
      table.insert(tt.sensorUnlist, " ")
      table.insert(tt.sensorDplist, 0)
   end
   --]]
end

local function sendCtrl(cc, nn)

   local bw = serial.write(sidSerial, string.rep(cc, nn))
   if not bw then
      print("Glass: Serial write error")
      sendState = state.IDLE
      return false
   end
   serialBytesSent = serialBytesSent + bw
   return bw
end

local function loop()
   local now = system.getTimeCounter()
   local unow = system.getTimeCounter()
   local sensor, sval, sval2
   local stbl = {}
   local gtbl = {}
   local av
   local scale, widgetID
   local minV, maxV, lbl
   local LOOPTIME = 250
   local CTRLREP = 4
   local SEND_DELAY = 10
   local BUF_SIZE = 128
   local SEND_LOOPS = 20
   
   if system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
      barf()
   end
   
   if switchItems.pageChange then
      local sw = system.getInputsVal(switchItems.pageChange)
      local pp = sw + 2 -- -1, 0, 1 --> 1,2,3
      pp = math.min(pp, pageMax)
      pageNumberTele = pp
   end

   local gs = Glass.settings
   if gs.latId ~= 0 and gs.latPa ~= 0 and gs.lngId ~= 0 and gs.lngPa ~= 0 then
      Glass.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      local lt, lg = 0, 0
      if Glass.curPos then lt, lg = gps.getValue(Glass.curPos) end
      if Glass.curPos and lt ~= 0 and lg ~= 0 and not Glass.initPos then
	 Glass.gpsReads = Glass.gpsReads + 1
      end
      if Glass.gpsReads > 9 and not Glass.initPos then
	 system.messageBox("GPS zero point set")
	 Glass.initPos = Glass.curPos
	 if not Glass.zeroPos then Glass.zeroPos = Glass.curPos end
      end
   end

   local gt = Glass.timers
   local si, ud1, ud2
   local now = system.getTimeCounter()

   if (gt.timer1.target or 0) - (gt.timer1.initial or 0) < 0 then
      ud1 = "down"
   else
      ud1 = "up"
   end

   if switchItems.t1enable then
      si = system.getSwitchInfo(switchItems.t1enable)      
      if si and si.value == 1 then 
	 if gt.timer1.state == gt.stateSTOP then --prior sw position
	    if ud1 == "up" then
	       gt.timer1.start = now - gt.timer1.time
	    else
	       gt.timer1.start = now + gt.timer1.time
	    end
	 end
	 gt.timer1.state = gt.stateRUN
      else
	 gt.timer1.state = gt.stateSTOP
      end
   end

   if switchItems.t1reset then
      si = system.getSwitchInfo(switchItems.t1reset)
      if si and si.value == 1 then 
	 gt.timer1.time = gt.timer1.initial
      end
   end
   
   if (gt.timer2.target or 0) - (gt.timer2.initial or 0) < 0 then
      ud2 = "down"
   else
      ud2 = "up"
   end

   if switchItems.t2enable then
      si = system.getSwitchInfo(switchItems.t2enable)
      if si and si.value == 1 then -- current sw position
	 if gt.timer2.state == gt.stateSTOP then --prior sw position
	    if ud2 == "up" then
	       gt.timer2.start = now - gt.timer2.time
	    else
	       gt.timer2.start = now + gt.timer2.time
	    end
	 end
	 gt.timer2.state = gt.stateRUN
      else
	 gt.timer2.state = gt.stateSTOP
      end
   end

   if switchItems.t2reset then
      si = system.getSwitchInfo(switchItems.t2reset)      
      if si and si.value == 1 then
	 gt.timer2.time = gt.timer2.initial
      end
   end

   if sendState == state.IDLE and unow < jsonHoldTime then
      --print("Glass: Waiting to restart json...")
   end

   -- maybe consider letting the internal update (for the tele window) run at full speed
   -- and only throttling the sending of json for 200msec?

   if sendState == state.IDLE and system.getTimeCounter() > jsonHoldTime then
      if pageMax > 0 and (now > lastWrite + LOOPTIME) then

	 if Glass.curPos and Glass.zeroPos then
	    Glass.gpsBearingTo = gps.getBearing(Glass.curPos, Glass.zeroPos)
	    Glass.gpsBearingFrom = gps.getBearing(Glass.zeroPos, Glass.curPos)	    
	    Glass.gpsDistance = gps.getDistance(Glass.curPos, Glass.zeroPos)
	 end
	 
	 local p1 = math.floor(255 * (1 + system.getInputs("P1")) / 2)
	 local p2 = math.floor(255 * (1 + system.getInputs("P2")) / 2)

	 if (not switchItems.pageChange) then pageNumberTele = pageNumber end

	 if not pageNumberTele or pageNumberTele < 1 then return end
	 if not Glass.page[pageNumberTele] then return end
	 stbl = {page=pageNumberTele}
	 gtbl = {}
	 gtbl["p"] = pageNumberTele 
	 gtbl["f"] = Glass.page[pageNumberTele][1].fmtNumber - 1 --  convert lua convention to c++

	 for k,v in ipairs(Glass.page[pageNumberTele]) do
	    if v.imageID and v.imageID >= 0 then
	       av = id2avail[v.imageID]
	       if not av then print(k, v.imageID) end
	       widgetID = cfgimg.images[av].widgetID
	       scale = cfgimg.images[av].scale
	       if scale == "variable" then
		  minV = v.minV or cfgimg.images[av].minV -- if min/max not set pick up defaults
		  maxV = v.maxV or cfgimg.images[av].maxV
	       else
		  minV = cfgimg.images[av].minV
		  maxV = cfgimg.images[av].maxV
	       end

	       local now = system.getTimeCounter()
	       v.value = nil
	       sensor = {}
	       if (v.sensorId ~= 0) and (v.sensorPa ~= 0) then
		  if v.sensorId == -1 then -- special sensors, derived values
		     if v.sensorPa == 1 then
			if Glass.gpsDistance then
			   sensor.valid = true
			   sensor.value = Glass.gpsDistance
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa == 2 or v.sensorPa == 3 then -- bearing to or from
			if Glass.gpsBearingTo and v.sensorPa == 2 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingTo
			elseif Glass.gpsBearingFrom and v.sensorPa == 3 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingFrom
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa == 4 or v.sensorPa == 6 then -- t1sec and t1pct
			if Glass.timers.timer1.state == Glass.timers.stateSTOP then
			   if ud1 == "up" then
			      Glass.timers.timer1.start = now - Glass.timers.timer1.time
			   else
			      Glass.timers.timer1.start = now + Glass.timers.timer1.time
			   end
			end
			if ud1 == "up" then
			   Glass.timers.timer1.time = (now - Glass.timers.timer1.start)
			   sensor.tpct = 100 * Glass.timers.timer1.time /
			      (Glass.timers.timer1.target - Glass.timers.timer1.initial)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			else
			   Glass.timers.timer1.time = (Glass.timers.timer1.start - now)
			   sensor.tpct = 100 * Glass.timers.timer1.time /
			      (Glass.timers.timer1.initial - Glass.timers.timer1.target)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			end
			if v.sensorPa == 4 then
			   sensor.value = math.floor(100 * Glass.timers.timer1.time / 1000) / 100
			else
			   sensor.value = (sensor.tpct or 0)
			end

			sensor.valid = true
		     elseif v.sensorPa == 5 or v.sensorPa == 7 then --t2sec and t2pct
			if Glass.timers.timer2.state == Glass.timers.stateSTOP then
			   if ud2 == "up" then
			      Glass.timers.timer2.start = now - Glass.timers.timer2.time
			   else
			      Glass.timers.timer2.start = now + Glass.timers.timer2.time
			   end
			end
			if ud2 == "up" then
			   Glass.timers.timer2.time = (now - Glass.timers.timer2.start)
			   sensor.tpct = 100 * Glass.timers.timer2.time /
			      (Glass.timers.timer2.target - Glass.timers.timer2.initial)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			else
			   Glass.timers.timer2.time = (Glass.timers.timer2.start - now)
			   sensor.tpct = 100 * Glass.timers.timer2.time /
			      (Glass.timers.timer2.initial - Glass.timers.timer2.target)
			   sensor.tpct = math.floor(10 * math.min(math.max(sensor.tpct, 0), 100)) / 10
			end
			if v.sensorPa == 5 then
			   sensor.value = math.floor(100 * Glass.timers.timer2.time / 1000) / 100
			else
			   sensor.value = (sensor.tpct or 0)
			end
			sensor.valid = true
		     end
		  else
		     sensor = system.getSensorByID(v.sensorId, v.sensorPa)
		  end
		  if sensor and sensor.valid then
		     v.value = sensor.value
		     if not v.value then print("v.value nil") end
		  end
	       end

	       v.value2 = nil -- value2 can only be for compass now...
	       sensor = {}
	       if v.sensorId2 and v.sensorId2 ~= 0 and v.sensorPa2 and v.sensorPa2 ~= 0 then
		  if v.sensorId2 == -1 then -- special sensors, derived values
		     if v.sensorPa2 == 1 then
			if Glass.gpsDistance then
			   sensor.valid = true
			   sensor.value2 = Glass.gpsDistance
			else
			   sensor.valid = false
			end
		     elseif v.sensorPa2 == 2 or v.sensorPa2 == 3 then
			if Glass.gpsBearingTo and v.sensorPa2 == 2 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingTo
			elseif Glass.gpsBearingFrom and v.sensorPa2 == 3 then
			   sensor.valid = true
			   sensor.value = Glass.gpsBearingFrom
			else
			   sensor.valid = false
			end
		     else
			sensor = system.getSensorByID(v.sensorId2, v.sensorPa2)
		     end
		     if sensor and sensor.valid then
			v.value2 = sensor.value
		     end
		  end
	       end

	       local function sv(dec, val)
		  local fms
		  if not dec or (dec < 0) or (dec > 2) then return nil end
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

	       sval = sv(v.decimals, v.value)
	       sval2 = sv(v.decimals2, v.value2)
	       
	       if v.imageID >= 0 then
		  stbl[k] = {}
		  stbl[k].id = av - 1 --convert this value for c++ with array starting at 0
		  if sval then
		     stbl[k].v = tonumber(sval)
		  end
		  if sval and sval2 then
		     stbl[k].v2 = tonumber(sval2)
		  end
		  if scale == "variable" and sval then
		     stbl[k].nV = minV
		     stbl[k].xV = maxV		  
		     stbl[k].l=Glass.page[pageNumberTele][k].instName		  
		  end
	       end
	    end
	    gtbl["w"] = {}
	    for kk,vv in ipairs(stbl) do
	       gtbl["w"][kk] = vv
	    end
	 end

	 if true then --next(stbl) then
	 --   local espjson = json.encode(stbl)
	 local espjson = json.encode(gtbl)

	    if emflag ~= 0 then
	       local swa = system.getInputs("SA")
	       if swa and swa == 1 then
		  print(espjson)
	       end
	    end
	    
	    local count = serial.write(sidSerial, espjson, "\n")
	 end
	 lastWrite = now
      end

   end

   if unow <= jsonHoldTime then return end

   if sendState == state.WAITING then 
      --print("Glass: Waiting to send config...")
      if true then --system.getTimeCounter() > startingTime then
	 sendFP = io.open(prefix() .. pathJson .. "configimages.jsn", "r")
	 if not Glass.settings.configVersion then Glass.settings.configVersion = 0 end
	 sendFPser = io.open(prefix() .. pathConfigs ..
			     string.format("config%d.txt", Glass.settings.configVersion), "w")
	 if sendFP and sidSerial then
	    print("sending \\001 "..(system.getTimeCounter() - startingTime).." ms")
	    if not sendCtrl("\001", 1) then
	       sendState = state.IDLE
	       return
	    end
	    sendCtrlCount = sendCtrlCount + 1
	    --print("sendCtrlCount", sendCtrlCount, CTRLREP)
	    if sendCtrlCount > CTRLREP then
	       sendAA = 0
	       sendFF = 0
	       sendTime = system.getTimeCounter()
	       configLine = ""
	       sendState = state.SENDFMTS
	       sendCtrlCount = 0
	       print("Glass: Sending image json description")
	    else
	       jsonHoldTime = system.getTimeCounter() + WAIT_TIME
	       return
	    end
	 else
	    print("Glass: could not open file or serial port not open")
	    sendState = state.IDLE
	 end
      else
	 return
      end

   elseif sendState == state.SENDHEADER or sendState == state.SENDFOOTER then

      --[[
	 config.txt formatting overview

	 "FFD0001561766961746F72000000000000000001AA" config header for "aviator" with zero version, key 1
	 "FF51...AA" fonts (many lines)
	 "FF41...AA" images (many lines)
	 "FFD0001561766961746F72000000000200000001AA" config footer for "aviator" with version 2, key 1
	 "FFD2000D61766961746F7200AA" config set to "aviator"

      --]]
      
      local cfgVersion = Glass.settings.configVersion or 1
      local cfgKey = 1
      local bufPre = "FFD0001561766961746F7200"
      local bufSet = "FFD2000D61766961746F7200AA"
      local bufH = bufPre .. string.format("%08X%08X", 0, cfgKey) .. "AA\n"
      local bufF = bufPre .. string.format("%08X%08X", cfgVersion, cfgKey) .. "AA\n"..bufSet.."\n"
      local bw
      if sendState == state.SENDHEADER then

	 print("sending \\002 from header "..(system.getTimeCounter() - startingTime) .. " ms")
	 if not sendCtrl("\002", 1) then
	    sendState = state.IDLE
	    return
	 end
	 sendCtrlCount = sendCtrlCount + 1
	 --print("sendCtrlCount", sendCtrlCount, CTRLREP)
	 if sendCtrlCount <= CTRLREP then
	    jsonHoldTime = system.getTimeCounter() + WAIT_TIME
	    return
	 else
	    print("Glass: Sending config header")
	    bw = serial.write(sidSerial, bufH)
	    serialBytesSent = serialBytesSent + bw	    
	    io.write(sendFPser, bufH)
	 end
	 
	 if not bw then
	    print("Glass: serial write error header")
	 else
	    sendState = state.SENDFONTS
	    sendFP = io.open(prefix() .. pathConfigs .. "config-fonts.txt", "r")
	    if not sendFP then
	       print("Glass: cannot open font config")
	       sendState = state.IDLE
	    end
	 end
	 print("Glass: Sending font configs")
      elseif sendState == state.SENDFOOTER then
	 --print("send footer ", bufF)
	 bw = serial.write(sidSerial, bufF)
	 serialBytesSent = serialBytesSent + bw
	 io.write(sendFPser, bufF)
	 if not bw then print("Glass: serial write error on footer") end
      end
      if not bw or (sendState == state.SENDFOOTER) then
	 print("Glass: Sending config footer")
	 if sendFPser then io.close(sendFPser) end
	 print("sending \\000 " .. (system.getTimeCounter() - startingTime) .. " ms")
	 sendCtrl("\000", 1) -- back to normal mode
	 local dt = system.getTimeCounter() - startingTime
	 print(string.format("Send config done. Time: %.2f s", dt / 1000))
	 print(string.format("%d bytes sent. Aggregate data rate: %.1f kB/s",
			     serialBytesSent, serialBytesSent / dt))
	 if tempCall then io.close(sendFPtemp) end
	 for k in ipairs(currentConfigIDs) do
	    configIDs[k] = currentConfigIDs[k]	  -- remember that this config was sent last
	 end
	 jsonHoldTime = system.getTimeCounter() + WAIT_TIME * 5 -- extra long wait before restarting 200ms json
	 sendState = state.IDLE
      end
   elseif (sendState == state.SENDFONTS) or (sendState == state.SENDIMGS) or
      (sendState == state.SENDACTIVE) or (sendState == state.SENDFMTS) then
      local buf, start, before, after
      if system.getTimeCounter() - sendLast > SEND_DELAY then -- throttle send rate here
	 for k=1,SEND_LOOPS,1 do
	    buf = io.read(sendFP, BUF_SIZE)
	    start = string.find(buf, "\n")
	    if not start then
	       configLine = configLine .. buf
	    else
	       before = string.sub(buf, 1, start-1)
	       after = string.sub(buf, start+1)
	       configLine = configLine .. before
	       if string.find(configLine, "AA") then
		  sendAA = sendAA + 1
	       end
	       if string.find(configLine, "FF") then
		  sendFF = sendFF + 1
	       end
	       configLine = after
	    end
	    local bw
	    if sidSerial and buf and buf ~= "" then
	       sendLast = system.getTimeCounter()
	       bw = serial.write(sidSerial, buf)
	       serialBytesSent = serialBytesSent + bw
	       if (sendState == state.SENDFONTS) or (sendState == state.SENDIMGS) then
		  io.write(sendFPser, buf)
		  if not bw then
		     print("Glass: Serial write error")
		     buf = ""
		  end
	       end
	    end
	    if buf == "" then
	       if sendState == state.SENDFMTS then
		  io.close(sendFP)
		  print("sending \\000 " .. (system.getTimeCounter() - startingTime) .. " ms")
		  if not sendCtrl("\000", 1) then -- signify end
		     sendState = state.IDLE
		     return
		  end
		  --send 0x02 N times to indicate file #2
		  --print("sending \\002 from buf "..(system.getTimeCounter() - startingTime) .. " ms")
		 -- if not sendCtrl("\002", 1) then
		   --  sendState = state.IDLE
		  --   return
		  --end
		  --sendCtrlCount = sendCtrlCount + 1
		  --print("sendCtrlCount in buf empty", sendCtrlCount, CTRLREP)
		  sendState = state.SENDHEADER
		  sendCtrlCount = 0
		  jsonHoldTime = system.getTimeCounter() + WAIT_TIME
		  -- deal with the rest of the ctrl chars in SENDHEADER
		  break
		  --[[
	       elseif sendState == state.SENDACTIVE then
		  io.close(sendFP)
		  --send 0x03 three times to indicate sending config txt info
		  if not sendCtrl("\003",4) then
		     sendState = state.IDLE
		     return
		  end
		  sendState = state.SENDHEADER
		  break
		  --]]
	       elseif sendState == state.SENDFONTS then
		  io.close(sendFP)
		  sendImgsIdx = 1
		  print("Glass: Sending image file " ..sendImgs[sendImgsIdx])
		  sendFP = io.open(sendImgs[sendImgsIdx], "r")
		  if not sendFP then
		     print("Glass:cannot open image file "..sendImgsIdx)
		     sendState = state.IDLE
		     break
		  else
		     sendState = state.SENDIMGS
		  end
	       elseif sendState == state.SENDIMGS then
		  io.close(sendFP)
		  if sendImgsIdx < #sendImgs then
		     sendImgsIdx = sendImgsIdx + 1
		     print("Glass: Sending image file " ..sendImgs[sendImgsIdx])
		     sendFP = io.open(sendImgs[sendImgsIdx], "r")
		     if not sendFP then
			print("Glass: cannot open image file "..sendImgsIdx, sendImgs[sendImgsIdx])
			sendState = state.IDLE
			break
		     end
		  else
		     sendState = state.SENDFOOTER
		     break
		  end
	       end
	    end
	 end
      end
   end
   cpu = system.getCPU()
end

local function changedSensor(value, inp)
   --print("changedSensor: val, inp", value, inp)
   if inp ~= 2 then
      Glass.page[pageNumber][gaugeNumber].sensorId = Glass.sensorIdlist[value]
      Glass.page[pageNumber][gaugeNumber].sensorPa = Glass.sensorPalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLa = Glass.sensorLalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLs = Glass.sensorLslist[value]
      Glass.page[pageNumber][gaugeNumber].units    = Glass.sensorUnlist[value]   
      Glass.page[pageNumber][gaugeNumber].decimals = Glass.sensorDplist[value]
      Glass.page[pageNumber][gaugeNumber].type     = Glass.sensorTylist[value]
   else
      Glass.page[pageNumber][gaugeNumber].sensorId2 = Glass.sensorIdlist[value]
      Glass.page[pageNumber][gaugeNumber].sensorPa2 = Glass.sensorPalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLa2 = Glass.sensorLalist[value]
      Glass.page[pageNumber][gaugeNumber].sensorLs2 = Glass.sensorLslist[value]
      Glass.page[pageNumber][gaugeNumber].units2    = Glass.sensorUnlist[value]   
      Glass.page[pageNumber][gaugeNumber].decimals2 = Glass.sensorDplist[value]
      Glass.page[pageNumber][gaugeNumber].type2     = Glass.sensorTylist[value]
   end
   if inp == 0 then
      Glass.page[pageNumber][gaugeNumber].sensorId2 = 0
      Glass.page[pageNumber][gaugeNumber].sensorPa2 = 0
   end
end


local function changedName(value)
   print("changedName instName", value, "page, gauge", pageNumber, gaugeNumber)
   Glass.page[pageNumber][gaugeNumber].instName = value
end

local function clearJSON()
   local fn = prefix() .. pathJson .. "GG_" .. modelName.. ".jsn"
   local ans
   ans = form.question("Are you sure?", "Reset all app settings?",
		       "",
		       0, false, 5)
   if ans == 1 then
      io.remove(fn)
      system.messageBox("All settings deleted .. Restart App")
      writeJSON = false
   end
   
end

local function tempWrite(a,b)
   io.write(sendFPtemp, b)
   return tempCall(a,b)
end

local function sendUSB()

   -- go thru all pages, and gauges to find imageIDs that are referenced
   -- and put them in a table to set up the data transmission


   --[[ test code to capture serialout stream by hihacking the system call
   print("NOTE **** CREATING config-serialout.txt  ******")
   if not tempCall then
      tempCall = serial.write
      serial.write = tempWrite
   end
   
   sendFPtemp = io.open(prefix() .. pathConfigs .. "config-serialout.txt", "w")
   print("sendFPtemp", sendFPtemp)
   --]]

   -- create the list of config-imgs fragments that must be uploaded
   
   sendImgs = {}
   local av

   -- loop over all imageIDs referenced in the current pages and formats
   -- note the filenames for each image
   
   for k,v in ipairs(currentConfigIDs) do
      if v >= 0 then
	 av = id2avail[v]
      else
	 av = nil
      end
      if av then
	    local fn = prefix() .. pathConfigs .. "config-imgs-" .. cfgimg.images[av].BMPname .. ".txt"
	    local included = false
	    for kk,vv in pairs(sendImgs) do
	       if fn == vv then included = true end
	    end
	    if not included and cfgimg.images[av].BMPname ~= "" then table.insert(sendImgs, fn) end
      end
   end
   
   if #sendImgs < 1 then
      print("Glass: no image files referenced")
      --return -- ok if no images (e.g. only a timer widget sent)
   end

   -- transmission protocol:
   --
   -- stop "200ms" json .. wait for n*200ms
   -- ascii 0x01 four times: here comes file 1
   -- ascii 0x02 four times: close file 1, here comes file 2
   -- ascii 0x03 four times: close file 2, here comes file 3
   -- ascii 0x00 four times: close file 3, back to normal
   -- wait for n*200ms
   --
   -- note:
   -- file 1 is configformats.jsn
   -- file 2 is the streaming config.txt info
   
   --First, send 0x01 4 times to indicate file #1

   startingTime = system.getTimeCounter()
   jsonHoldTime = startingTime + WAIT_TIME
   sendState = state.WAITING
   sendCtrlCount = 0
   serialBytesSent = 0
end

local inpN

local function initForm(sf)

   subForm = sf
   if sf == 1 then
      form.setButton(1, ":add",   ENABLED)
      form.setButton(2, ":up",    ENABLED)
      form.setButton(3, "Edit",   ENABLED)
      form.setButton(4, ":tools", ENABLED)
      
      if not Glass.page or #Glass.page == 0 then
	 form.addRow(1)
	 form.addLabel({label="No pages defined", width = 220})
      else
	 for i in ipairs(Glass.page) do
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
      if  #Glass.page < 1 then
	 form.addRow(1)
	 form.addLabel({label="No pages defined"})
	 return
      end
      
      if not Glass.page[pageNumber][gaugeNumber].instName then
	 Glass.page[pageNumber][gaugeNumber].instName = 'Gauge'..gaugeNumber
      end

      if Glass.page[pageNumber][1].fmtNumber < 1 then
	 Glass.page[pageNumber][1].fmtNumber = 1
	 --fmtNumber = 1
      end

      --sift thru avail images and find the ones that are the correct size
      --for this gauge in the selected format

      imageNum = nil
      local imageID = Glass.page[pageNumber][gaugeNumber].imageID
      local fn = Glass.page[pageNumber][1].fmtNumber
      local wid = cfgimg.config[fn][gaugeNumber].width
      local hgt = cfgimg.config[fn][gaugeNumber].height
      local label
      
      editImgs = {}
      for i, img in ipairs(cfgimg.images) do
	 if (wid == img.origWidth) and (hgt == img.origHeight) then
	    table.insert(editImgs,
			 {widgetID=img.widgetID, loadImage=img.loadImage,
			  loadImageSmaller = img.loadImageSmaller,
			  imageWidth=img.imageWidth, imageHeight = img.imageHeight,
			  wtype=img.wtype, inputs=img.inputs})
	    if img.widgetID == imageID then
	       imageNum = #editImgs
	    end
	 end
      end
      imageMax = #editImgs
      if not imageNum then imageNum = 1 end

      --print("imageMax, imageNum", imageMax, imageNum)
      
      if imageID < 0 then
	 if #editImgs < 1 then
	    print("Glass: no images for", pageNumber, gaugeNumber)
	 else -- default to first image
	    Glass.page[pageNumber][gaugeNumber].imageID = editImgs[1].widgetID
	    Glass.page[pageNumber][gaugeNumber].wtype = editImgs[1].wtype
	 end
      end

      local function setinp(inp, ii)
	 if ii == 0 then inpN = 0 else inpN = inp end
	 form.reinit(12)
      end
      
      inpN = 0
      local inpS
      local ii
      for inp=1,editImgs[imageNum].inputs do
	 if editImgs[imageNum].inputs == 1 then inpS = "" ii = 0 else inpS = tostring(inp) ii = inp end
	 form.addRow(1)
	 form.addLink((function() return setinp(inp, ii) end), {label="Data source "..inpS.." >"})
      end

      form.addRow(1)
      form.addLink((function() form.reinit(13) end), {label="Min/Max >"})
      
      form.setTitle("Page " .. pageNumber .. " Gauge " .. gaugeNumber)
      
      form.setFocusedRow(1)
   elseif sf == 11 then

      local function pageSwChanged(val, name)
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
      

      local function cvchanged(val)
	 Glass.settings.configVersion = val
      end

      local latsel = 0
      local lngsel = 0
      for k = 1, #Glass.gpsLalist do
	 if (Glass.gpsIdlist[k] == Glass.settings.latId) and
	    (Glass.gpsPalist[k] == Glass.settings.latPa) then
	    latsel = k
	 end
	 if (Glass.gpsIdlist[k] == Glass.settings.lngId) and
	    (Glass.gpsPalist[k] == Glass.settings.lngPa) then
	    lngsel = k
	 end	 
      end

      form.addRow(2)
      form.addLabel({label="Page change switch"})
      swtCI.pageChange = form.addInputbox(switchItems.pageChange, true,
					  (function(x) return  pageSwChanged(x, "pageChange") end)
      )
      
      
      form.addRow(2)
      form.addLabel({label="Set config version"})
      form.addIntbox(Glass.settings.configVersion, 1, 32767, 1, 0, 1, cvchanged)

      form.addRow(2)
      form.addLabel({label="GPS Lat Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.gpsLalist, latsel, true,
			(function(i)
			      Glass.settings.latId = Glass.gpsIdlist[i]
			      Glass.settings.latPa = Glass.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="GPS Lng Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.gpsLalist, lngsel, true,
			(function(i)
			      Glass.settings.lngId = Glass.gpsIdlist[i]
			      Glass.settings.lngPa = Glass.gpsPalist[i]			      
			      return end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(1)
      form.addLink(sendUSB, {label="Send config on serial>>"})

      form.addRow(1)
      form.addLink((function() form.reinit(14) return end), {label="Timer setup>>"})      

      form.addRow(1)
      form.addLink(clearJSON, {label="Reset app settings>>"})
      
   elseif sf == 12 then

      local isel = 0
      for k = 1, #Glass.sensorLalist do
	 if inpN ~= 2 then
	    if (Glass.sensorIdlist[k] == Glass.page[pageNumber][gaugeNumber].sensorId) and
	       (Glass.sensorPalist[k] == Glass.page[pageNumber][gaugeNumber].sensorPa) then
	       isel = k
	       break
	    end
	 else
	    if (Glass.sensorIdlist[k] == Glass.page[pageNumber][gaugeNumber].sensorId2) and
	       (Glass.sensorPalist[k] == Glass.page[pageNumber][gaugeNumber].sensorPa2) then
	       isel = k
	       break
	    end
	 end
      end

      form.addRow(2)
      form.addLabel({label="Sensor:", font=FONT_NORMAL})
      form.addSelectbox(Glass.sensorLalist, isel, true,
			(function(x) return changedSensor(x, inpN) end),
			{width=155, font=FONT_NORMAL, alignRight=false})

      form.addRow(2)
      form.addLabel({label="Gauge Name:", font=FONT_NORMAL})
      form.addTextbox(Glass.page[pageNumber][gaugeNumber].instName, 10,
		      (function(x) return changedName(x, inpN) end),
		      {width=155, font=FONT_NORMAL})

   elseif sf == 13 then

      local id, fn, minV, maxV, av

      fn = Glass.page[pageNumber][1].fmtNumber
      id = Glass.page[pageNumber][gaugeNumber].imageID
      if id < 0 then
	 print("Glass: no images")
	 return
      end

      av = id2avail[id]

      local scale = cfgimg.images[av].scale
      
      if scale == "fixed" or not Glass.page[pageNumber][gaugeNumber].minV then
	 minV = cfgimg.images[av].minV
      else
	 minV = Glass.page[pageNumber][gaugeNumber].minV
      end

      if scale == "fixed" or not Glass.page[pageNumber][gaugeNumber].maxV then
	 maxV = cfgimg.images[av].maxV
      else
	 maxV = Glass.page[pageNumber][gaugeNumber].maxV
      end      
      
      if cfgimg.images[av].scale == "variable" then
	 local function minChanged(value)
	    Glass.page[pageNumber][gaugeNumber].minV = value / 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Min value"})
	 form.addIntbox(minV*10, -32768, 32767, 0, 1, 1, minChanged)

	 local function maxChanged(value)
	    Glass.page[pageNumber][gaugeNumber].maxV = value / 10.0
	 end

	 form.addRow(2)
	 form.addLabel({label="Max value"})
	 form.addIntbox(maxV*10, -32768, 32767, 100, 1, 1, maxChanged)
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
      local mins, secs, sign      
            
      local function changedMS(val, tn, u, tm, tmud)
	 local tt = {hrs=hrs, mins=mins, secs=secs}
	 local tmsg = {timer1="Timer 1 ", timer2="Timer 2 "}
	 local umsg = {initial = "Initial Value ", target = "Target Value "} 
	 tt[u] = val
	 mins, secs, sign = ms(Glass.timers[tn][tm])
	 local ss = 1
	 if Glass.timers[tn][tmud] == "-" then ss = -1 end
	 Glass.timers[tn][tm] = ss * (tt.secs + 60 * tt.mins) * 1000
	 mins, secs, sign = ms(Glass.timers[tn][tm])
	 form.setTitle(string.format(tmsg[tn]..umsg[tm]..sign.."%02d:%02d", mins, secs))
      end

      local function timerPMChanged(x, tn, ud)
	 Glass.timers[tn][ud] = string.sub("+-", x, x)
	 sign = Glass.timers[tn][ud]
	 if sign == "-" then
	    Glass.timers[tn].initial = math.abs(Glass.timers[tn].initial) * -1
	 else
	    Glass.timers[tn].initial = math.abs(Glass.timers[tn].initial)	    
	 end
      end
      
      local plusminus = {"+", "-"}

      form.addRow(1)
            form.addLabel({label=string.rep(" ", 28) .. "Timer 1", font=FONT_BOLD})
      
      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      local isel = string.find("+-", (Glass.timers.timer1.initialUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer1", "initialUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer1.initial)

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
      local isel = string.find("+-", (Glass.timers.timer1.targetUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer1", "targetUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer1.target)

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
      local swe = "t1enable"
      swtCI.t1enable = form.addInputbox(switchItems.t1enable, true,
		       (function(x) return changedSwitch(x, "t1enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      local swr = "t1reset"
      swtCI.t1reset = form.addInputbox(switchItems.t1reset, true,
		       (function(x) return changedSwitch(x, "t1reset") end),
		       {width=100}
      )

      -------------------------------------------------------------------------
      
      form.addRow(1)
      form.addLabel({label=string.rep(" ", 28) .. "Timer 2", font=FONT_BOLD})

      form.addRow(8)
      form.addLabel({label="Initial:", width=65})
      local isel = string.find("+-", (Glass.timers.timer2.initialUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer2", "initialUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer2.initial)

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
      local isel = string.find("+-", (Glass.timers.timer2.targetUD or "+"))
      form.addSelectbox(plusminus, isel, false,
		       (function(x) return timerPMChanged(x,"timer2", "targetUD") end),
		       {width=40}
      )

      mins, secs, sign = ms(Glass.timers.timer2.target)

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
      local swe = "t2enable"
      swtCI.t2enable = form.addInputbox(switchItems.t2enable, true,
		       (function(x) return changedSwitch(x, "t2enable") end),
		       {width=100}
      )
      form.addLabel({label="Rst Sw", width=65})
      local swr = "t2reset"
      swtCI.t2reset = form.addInputbox(switchItems.t2reset, true,
		       (function(x) return changedSwitch(x, "t2reset") end),
		       {width=100}
      )
      
      form.setFocusedRow(1)
      form.setTitle("Timer Setup")
   end
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end

local function clearPage(pn, gm)
   Glass.page[pn] = {}
   for k=1,gm do
      Glass.page[pn][k] = {}
      Glass.page[pn][k].sensorId = 0
      Glass.page[pn][k].sensorPa = 0	 
      Glass.page[pn][k].sensorLs = "..."
      Glass.page[pn][k].sensorLa = "..."	    
      Glass.page[pn][k].units = "-"
      Glass.page[pn][k].decimals = 0
      Glass.page[pn][k].imageID = -1
      Glass.page[pn][k].value = 0.0
      Glass.page[pn][k].instName = "Gauge"..k
      Glass.page[pn][k].sensorId2 = 0
      Glass.page[pn][k].sensorPa2 = 0      
   end
   Glass.page[pn][1].fmtNumber = 1
end

local function keyPressed(key)

   local fmtNumber
   local iid
   if pageNumber < 1 or #Glass.page < 1 then
      fmtNumber = 1
   else
      fmtNumber = Glass.page[pageNumber][1].fmtNumber
   end


   updateConfigIDs()
   

   if subForm == 1 then

      if keyExit(key) then
	 if key ~= KEY_ESC then
	    form.preventDefault()
	    savedRow = form.getFocusedRow()
	    form.reinit(1)
	 else
	    if not matchConfigID(configIDs, currentConfigIDs) then
	       system.messageBox("Need to send new config to Glasses")
	       -- send goes here --
	    end
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
	    system.messageBox("No pages defined")
	    return
	 end
	 clearPage(pageNumber, gaugeMax)
	 fmtNumber = fmtNumber + 1
	 if fmtNumber > #cfgimg.config then fmtNumber = 1 end
	 Glass.page[pageNumber or 1][1].fmtNumber = fmtNumber
	 savedRow = form.getFocusedRow()
	 form.reinit(1)
	 return
      elseif key == KEY_3 or key == KEY_ENTER then
	 savedRow = form.getFocusedRow()
	 if savedRow > 0 then
	    pageNumber = savedRow
	    gaugeNumber = 1
	    form.reinit(10)
	 else
	    system.messageBox("No pages defined to edit")
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
	 local fm = Glass.page[pageNumber][1].fmtNumber
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
	 local iid = 0
	 local min, max, wtype, inp
	 for i,img in ipairs(cfgimg.images) do
	    if img.widgetID == editImgs[imageNum].widgetID then
	       iid = img.widgetID
	       min = img.minV
	       max = img.maxV
	       wtype = img.wtype
	       inp = img.inputs
	    end
	 end
	 Glass.page[pageNumber][gaugeNumber].imageID = iid
	 Glass.page[pageNumber][gaugeNumber].minV = min -- may be nil
	 Glass.page[pageNumber][gaugeNumber].maxV = max -- may be nil
	 Glass.page[pageNumber][gaugeNumber].wtype = wtype
	 Glass.page[pageNumber][gaugeNumber].inputs = inp	 
	 form.reinit(10)
      end
   elseif subForm == 11 then
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
   end
end

local function drawRectangleGlass(x0, y0, xl, yl)
   local f = 0.55
   lcd.drawRectangle(f*x0 - f*xl / 2, f*y0 - f*yl / 2, f*xl, f*yl)
end

local function drawText(x0, y0, val, lbl, twid, thgt)
   local text = string.format(lbl .. ' ' .. "%.2f", val)
   local ww = lcd.getTextWidth(FONT_BIG, text)
   local hh = lcd.getTextHeight(FONT_BIG, text)
   lcd.drawText(x0 + (twid - ww)/2, y0 + (thgt - hh)/2, text, FONT_BIG)
end

local function drawTimer(x0, y0, val, lbl, twid, thgt)
   local sign, mins, secs
   mins, secs, sign = ms(val * 1000)
   local text = string.format(lbl .. ' ' .. "%s%02d:%02d", sign, mins, secs)
   local ww = lcd.getTextWidth(FONT_BIG, text)
   local hh = lcd.getTextHeight(FONT_BIG, text)
   lcd.drawText(x0 + (twid - ww)/2, y0 + (thgt - hh)/2, text, FONT_BIG)
end

local function printForm(w,h)

   local fmtNumber
   local offset = w - 144

   if subForm == 10 then
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(offset-5, 0, h+1+5, h+1)
      if imageNum and imageNum > 0 and editImgs[imageNum] then --and editImgs[imageNum].loadImage then
	 local xi, yi
	 if editImgs[imageNum].imageWidth > 144 then
	    xi, yi = w/2 - editImgs[imageNum].imageWidth/2, 80
	 else
	    xi, yi = offset, 0
	 end
	 --if editImgs[imageNum].loadImage then
	 if editImgs[imageNum].wtype == "gauge" or editImgs[imageNum].wtype == "compass" or
	    editImgs[imageNum].wtype == "hbar" then
	    drawImage(xi,yi,editImgs[imageNum], "loadImage") -- XXXXXX
	 elseif editImgs[imageNum].wtype == "htext" then
	    lcd.setColor(0,0,0)
	    lcd.drawRectangle(xi, yi, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	    local iN = Glass.page[pageNumber][gaugeNumber].instName
	    local vv = Glass.page[pageNumber][gaugeNumber].value or 0.0
	    drawText(xi, yi, vv, iN, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	 elseif editImgs[imageNum].wtype == "timer" then
	    lcd.setColor(0,0,0)
	    lcd.drawRectangle(xi, yi, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	    local iN = Glass.page[pageNumber][gaugeNumber].instName
	    local vv = Glass.page[pageNumber][gaugeNumber].value or 0.0
	    drawTimer(xi, yi, vv, iN, editImgs[imageNum].imageWidth, editImgs[imageNum].imageHeight)
	 end
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

      if pageNumber < 1 or not Glass.page[pageNumber] then return end
      
      fmtNumber = Glass.page[pageNumber][1].fmtNumber
      if fmtNumber > 0 then
	 local gp = cfgimg.config[fmtNumber]
	 for g,t in ipairs(gp) do
	    drawRectangleGlass(t.xc, t.yc, t.width, t.height)
	 end
      end
      lcd.drawText(2,0,string.format("%d", fmtNumber))
      lcd.resetClipping()
   end
end

local function drawNeedle(x0, y0, degMin, degMax, min, max, val, len)
   
   local ren = lcd.renderer()
   local sinpt, cospt
   local pct = (val - min) / (max - min)
   local deg = 180 + (degMin + pct * (degMax - degMin))

   sinpt = math.sin(math.rad(deg))
   cospt = math.cos(math.rad(deg))
   ren:reset()
   ren:addPoint(x0, y0)
   local x1 = 0
   local y1 = len
   ren:addPoint(x0 + x1 * cospt - y1 * sinpt, y0 + x1 * sinpt + y1 * cospt)
   ren:renderPolyline(1)

end

local function drawHbar(x0, y0, min, max, val, barW, barH)
   local bw = math.floor(barW * (val - min) / (max - min) + 0.5)
   bw = math.min(math.max(0, bw), barW+1)
   lcd.drawFilledRectangle(x0, y0, bw, barH)
end

local function printTeleSmall(w,h)
   if pageNumberTele and pageNumberTele > 0 then
      lcd.drawText(5, 3, string.format("Page %d", pageNumberTele), FONT_MINI)
   end

   lcd.drawImage(45, 3, glassesIcon)
   if not Glass.var.statusAL or Glass.var.statusAL.Conn == 0 then
      lcd.drawImage(75, 3, redcrossIcon)
   end

   if Glass.var.statusAL and Glass.var.statusAL.Conn == 1 then
      lcd.drawImage(75, 3, greencheckIcon)
      --lcd.drawImage(100,  0, batteryIcon)
      lcd.drawText(100, 3, string.format("Batt %d%%", Glass.var.statusAL.Batt), FONT_MINI)
   end
end

local function printTele(w,h)

--[[

   Sample json file structure (snipped from configconfig.jsn) 
   It contains just one object each for "configs" and "images" as an example of the data shape
   All position coordinates are in the ActivImage space .. origin at lower right
   The main table is cfgimg .. then cfgimg.config and cfgimg.images

{
    { "config": [ [ {"xlr": 72,"ylr": 48} ], [] ...] },
    { "images": [{"scale": "variable","xlmin": 140,"ylmin": 15,
      "ylmax": 15,"xlmax": 20,"x0": 80,"y0": 80,"nlen": 70,
      "maxA": 150, "inputs": 1,"minA": -150,"maxV": 100,
      "ylbl": 50,"wtype": "gauge","xlbl": 80,"widgetID": 10,
      "minV": 0},{} ... ] }
}

--]]
   
   local r = 160 / 256 -- show the glasses space (304x256) in Jeti screen (320x160) .. scale by 160/256
   local offset = (319 - r * 304) / 2 -- center the shrunk glasses space on the Jeti screen
   local fmt
   local gpp

   -- Select the appropriate page (controlled by assigned switch or line in menu)
   -- Individual dynamic widget info stored in Glass.page[pageNumber][gaugeNumber].property
   -- The Glass.page values are the ones that form the 200msec json
   
   if not switchItems.pageChange  then pageNumberTele = pageNumber end

   lcd.setColor(0,0,0)
   lcd.drawFilledRectangle(0,0,319,159) -- black background over entire window
   lcd.setColor(255,255,255)            -- rest of animation (needles, etc) is white
   lcd.drawRectangle(1+offset, 1, (304-2)*r, (256-4)*r) -- draw scaled glasses hw screen as box
   if pageNumberTele and pageNumberTele > 0 then
      lcd.drawText(10, 10, string.format("Page %d", pageNumberTele))
   end

   lcd.drawImage(265, 15, glassesIcon)
   if not Glass.var.statusAL or Glass.var.statusAL.Conn == 0 then
      lcd.drawImage(295, 15, redcrossIcon)
   end

   if Glass.var.statusAL and Glass.var.statusAL.Conn == 1 then
      lcd.drawImage(295, 15, greencheckIcon)
      lcd.drawImage(272,  40, batteryIcon)
      drawTextCenter(287, 70, string.format("%d%%", Glass.var.statusAL.Batt), FONT_MINI)
      drawTextCenter(287,120, string.format("C:%d", Glass.var.statusAL.Conf), FONT_MINI)
      drawTextCenter(287,135, string.format("CG:%d", Glass.var.statusAL.GlassConf), FONT_MINI)            
   end

   if not pageNumberTele or pageNumberTele < 1 then return end

   local xr, yr, xc, yc
   local min, max, val, lbl
   local ccfg, cid

   gpp = Glass.page[pageNumberTele]
   if not gpp[1].fmtNumber then gpp[1].fmtNumber = 1 end
   fmt = gpp[1].fmtNumber --  string.format("p%d", gpp[1].fmtNumber)
   local ccf =  cfgimg.config[fmt]

   -- From here, everything referenced with "t." would come from the 200msec json if we
   -- were in the ESP. Make sure we only reference things that are sent that way so we're not
   -- cheating. Everything from "cid." is from the images section cfgimg.images
   
   for g,t in ipairs(gpp) do        -- loop over all gauges on this page with a valid imageID
      ccfg = ccf[g]                 -- this is the "config" key for this page and this widget
      --id = g --t.imageID
      cid = cfgimg.images[id2avail[t.imageID]]
      if t.imageID >= 0 then        -- if there is a value to animate
	 xr = ccfg.xul
	 yr = ccfg.yul
	 xc = xr + cid.x0           -- for gauge, this is the pivot point of the needle
	 yc = yr + cid.y0
	 if t.value then
	    -- if scale "fixed" then scale comes from images, else from 200ms json
	    if cid.scale and cid.scale == "fixed" then
	       min = cid.minV
	       max = cid.maxV
	    else  -- be defensive in case of missing minV/maxV
	       min = t.minV or 0
	       max = t.maxV or 1
	    end
	    lbl = t.instName or "..." --.instName is named .label in the 200ms json 
	    val = t.value
	    if cid.wtype == "gauge" then
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       drawNeedle(offset + r * xc, r * yc, cid.minA, cid.maxA, min, max, val, r * cid.nlen)
	    elseif cid.wtype == "compass" then
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       drawNeedle(offset + r * xc, r * yc, 0, 360, 0, 360, val, r * cid.nlen1)
	       if t.value2 then
		  drawNeedle(offset + r * xc, r * yc, 0, 360, 0, 360, t,value2, r * cid.nlen2)
	       end
	    elseif cid.wtype == "hbar" then
	       drawImage(offset + xr * r, yr * r, cid, "loadImageSmaller")
	       drawHbar(offset + r * xc, r * yc, min, max, val, r * cid.barW, r * cid.barH)
	    elseif cid.wtype == "htext" then
	       drawText(offset + r * xc, r * yc, val, lbl, r * cid.txtW, r * cid.txtH)
	    elseif cid.wtype == "timer" then
	       drawTimer(offset + r * xc, r * yc, val, lbl, r * cid.txtW, r * cid.txtH)
	    end 
	    if (cid.wtype == "gauge" or cid.wtype == "hbar") and cid.scale == "variable" then
	       drawTextCenter(offset + xr * r + r * cid.xlmin, yr * r + r * cid.ylmin,
			      string.format(dpFmt(min), min), FONT_MINI)
	       drawTextCenter(offset + xr * r + r * cid.xlmax, yr * r + r * cid.ylmax,
			      string.format(dpFmt(max), max), FONT_MINI)
	       drawTextCenter(offset + xr * r + r * cid.xlbl, yr * r + r * cid.ylbl,
			      lbl, FONT_MINI)			      
	    end
	 end
      end
   end
end

local function destroy()

   local fp
   local fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"

   if not writeJSON then
      return
   end

   --replace Id and Pa with hex values .. limited precision of JSON conversion
   --turning these (especially Id) into floats mangles them
   for k, v in pairs(Glass.page) do
      for kk,vv in pairs(v) do
	 for kkk, vvv in pairs(vv) do
	    if  kkk == "sensorId" or kkk == "sensorPa" or kkk == "sensorId2" or kkk == "sensorPa2" then
	       vv[kkk] = string.format("0X%X", math.floor(vvv)) 
	    end
	 end
      end
   end

   for k,v in pairs(Glass.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa" then
	 Glass.settings[k] = string.format("0X%X", math.floor(v))
      end
   end

   Glass.timers.timer1.start = 0 -- no need to save these
   Glass.timers.timer1.time = 0 
   
   Glass.timers.timer2.start = 0
   Glass.timers.timer2.time = 0
   
   local GGtbl = {}
   GGtbl.page = Glass.page
   GGtbl.settings = Glass.settings
   GGtbl.timers = Glass.timers
   GGtbl.settings.jsnVersion = JSNVERSION
   GGtbl.switchInfo = Glass.switchInfo
   
   fp = io.open(fn, "w")
   if fp then
      local jt = json.encode(GGtbl)
      if not jt then print("json encode error GGtbl") else
	 io.write(fp, json.encode(GGtbl), "\n")
	 io.close(fp)
      end
      print("Glass - State saved " .. fn)
   else
      print("Glass - Could not save state")
   end
end

local savedData

local function onRead(indata)
   --print("indata", indata)
   local data
   if savedData then
      data = savedData ..indata
      savedData = ""
   else
      data = indata
      savedData = ""
   end
   if data == "W" then
      print("ENGO gesture") 
   elseif string.find(data, "{") == 1 and string.find(data, "}") then
      local callOK
      callOK, Glass.var.statusAL = pcall(json.decode,data)
      if callOK then
	 --print(Glass.var.statusAL.Conf,Glass.var.statusAL.GlassConf)
      else
	 Glass.var.statusAL = nil
      end
   else
      if string.find(data, "{") == 1 and not string.find(data, "}") then
	 savedData = data
      else
	 print("Unknown serial data: ", data)
	 savedData = ""
      end
   end
end

local function init()

   local fn
   local fmtNumber

   --print("CPU Entry ", system.getCPU())
   
   modelName = string.gsub(system.getProperty("Model"), " ", "_")

   readSensors(Glass)
   
   system.registerForm(1, MENU_APPS, "Glass", initForm, keyPressed, printForm)

   fn = prefix() .. pathJson .. "cfgimg.jsn"
      
   local file = io.readall(fn)
   cfgimg = {}
   if file then
      cfgimg = json.decode(file)
      print("Glass - Reading avail images from ", fn)
   else
      system.messageBox("Glass: Cannot read " .. fn)
      return
   end

   --print("CPU 0: ", system.getCPU())

   local ratio = 144 / 160 -- ratio of "small" images to jeti screen height
   id2avail = {}
   local im, ims
   for i,img in ipairs(cfgimg.images) do   
      if img.BMPname ~= "" then
	 im = prefix() .. pathImages .. img.BMPname .. "-small.png"
	 ims = prefix() .. pathImages .. img.BMPname .. "-smaller.png"      
	 img.loadImage = lcd.loadImage(im)
	 img.loadImageSmaller = lcd.loadImage(ims)
	 img.imageWidth = img.loadImage.width
	 img.imageHeight = img.loadImage.height
	 img.origWidth = img.width
	 img.origHeight = img.height
      else
	 img.origWidth = img.width
	 img.origHeight = img.height
	 img.imageWidth = img.width * ratio
	 img.imageHeight = img.height * ratio
      end
      id2avail[img.widgetID] = i
   end

   fn = prefix() .. pathImages .. "glasses.png"
   glassesIcon = lcd.loadImage(fn)
   fn = prefix() .. pathImages .. "redcross.png"
   redcrossIcon = lcd.loadImage(fn)
   fn = prefix() .. pathImages .. "greencheck.png"
   greencheckIcon = lcd.loadImage(fn)   
   fn = prefix() .. pathImages .. "battery.png"   
   batteryIcon = lcd.loadImage(fn)   

   --print("CPU 1: ", system.getCPU())

   local device
   device, emflag = system.getDeviceType() 
   
   local success, descr
   local portlist = serial.getPorts()
   for k,v in pairs(portlist) do
      print("Glass - Available COM port "..k..": ".. v)
   end

   local baud = 115200
   
   if emflag ~= 0 then
      sidSerial, descr = serial.init("ttyUSB0", baud)
      os.setlocale("C")
   else
      sidSerial, descr = serial.init("COM1", baud)
   end
   
   if sidSerial then   
      print("Glass - Serial port init succeeded: ", sidSerial)
      serial.setBaudrate(sidSerial, baud)
      success, descr = serial.onRead(sidSerial,onRead)   
      if success then
	 --print("Glass: Callback registered")
      else
	 print("Glass: Error setting callback", descr)
      end
   else
      print("Glass - Serial port init failed", sidSerial, descr)
   end 

   system.registerTelemetry(1, "Glasses Display", 4, printTele)
   system.registerTelemetry(2, "Glasses Status", 1, printTeleSmall)   

   local function initG()
      print("Glass - No saved state")

      Glass.page = {}
      pageMax = #Glass.page
      pageNumber = 0
      gaugeNumber = 1

      Glass.settings = {}
      Glass.settings.latId = 0
      Glass.settings.latPa = 0
      Glass.settings.lngId = 0
      Glass.settings.lngPa = 0

      Glass.timers = {}
      Glass.timers.stateSTOP = 0
      Glass.timers.stateRUN = 1
      Glass.timers.timer1 = {state = Glass.timers.stateSTOP, time=0, start=0,
			     target=0, initial = 300 * 1000}
      Glass.timers.timer2 = {state = Glass.timers.stateSTOP, time=0, start=0,
			     target=0, initial = 300 * 1000}
   end

   --print("CPU 2", system.getCPU())   

   local GGtbl = {}
   fn = prefix()..pathJson.."GG_" .. modelName.. ".jsn"
   file = io.readall(fn)
   if file then
      GGtbl = json.decode(file)      
      Glass.page = GGtbl.page
      Glass.settings = GGtbl.settings
      Glass.timers  = GGtbl.timers
      Glass.switchInfo = GGtbl.switchInfo
      if #Glass.page > 0 then
	 pageNumber = 1
	 pageMax = #Glass.page
      end
      gaugeNumber = 1
      if not Glass.timers then Glass.timers = {} end
      Glass.timers.timer1.time = 0
      Glass.timers.timer2.time = 0   
      Glass.timers.stateSTOP = 0
      Glass.timers.stateRUN = 1
   else
      initG()
   end

   if not Glass.switchInfo then Glass.switchInfo = {} end
      
   if not Glass.settings then Glass.settings = {} end
   if not Glass.settings.jsnVersion or Glass.settings.jsnVersion ~= JSNVERSION then
      print("old JSON in "..fn.. " - starting with no saved state")
      initG()
      system.messageBox("App settings were reset")
   end
   
   if not Glass.settings.configVersion then Glass.settings.configVersion = 1 end
   
   -- put hex strings back into numbers for Id and Pa
   for k, v in pairs(Glass.page) do
      for kk,vv in pairs(v) do
	 for kkk, vvv in pairs(vv) do
	    if  kkk == "sensorId" or kkk == "sensorPa" or kkk == "sensorId2" or kkk == "sensorPa2" then
	       vv[kkk] = tonumber(vvv)
	    end
	 end
      end
   end

   for k,v in pairs(Glass.settings) do
      if k == "latId" or k == "lngId" or k == "latPa" or k == "lngPa" then
	 Glass.settings[k] = tonumber(v)
      end
   end

   --print("CPU 3: ", system.getCPU())
      
   Glass.gpsReads = 0

   Glass.timers.timer1.state = Glass.timers.stateSTOP
   Glass.timers.timer2.state = Glass.timers.stateSTOP

   if not Glass.timers.timer1.initial then
      Glass.timers.timer1.start = 0
      Glass.timers.timer1.initial = 300 * 1000 -- 5:00 in ms
      Glass.timers.timer1.time = 300 * 1000
   else
      Glass.timers.timer1.start = 0
      Glass.timers.timer1.time = Glass.timers.timer1.initial
   end
   if not Glass.timers.timer1.target then
      Glass.timers.timer1.target = 0 -- 0:00
   end

   if not Glass.timers.timer2.initial then
      Glass.timers.timer2.start = 0
      Glass.timers.timer2.initial = 300 * 1000 -- 5:00 in ms
      Glass.timers.timer2.time = 300 * 1000
   else
      Glass.timers.timer2.start = 0
      Glass.timers.timer2.time = Glass.timers.timer2.initial
   end
   if not Glass.timers.timer2.target then
      Glass.timers.timer2.target = 0 -- 0:00
   end

   for k, swi in pairs(Glass.switchInfo) do
      local t = string.sub(swi.name,1,1)
      --print("k, swi", k, swi.name, swi.mode, swi.activeOn)
      switchItems[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
   end

   updateConfigIDs()
   configIDs = {} -- don't have info yet on what's on the glasses

   print("CPU end init(): ", system.getCPU())
end

return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.7", name=appName}
