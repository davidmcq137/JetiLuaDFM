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

local appName = "DFM-RTH"
local pathApp = "Apps/"..appName.."/"
local RTH = {}

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

local renShape = lcd.renderer()
local ren = lcd.renderer()

local homeShape = {
 { 0, -15},
 {-12, 12},
 { 0, 6},
 { 12, 12}
}
local emflag

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

local lastSec
local fifteenSec
local lastonoff = -1

local function loop()
   local now = system.getTimeCounter()
   local sensor
   local MINHDGDIST = 2
   local MINGPSREADS= 9
   local info, onoff
   
   if not lastSec then lastSec = now end
   if not fifteenSec then fifteenSec = now end
   
   if emflag ~= 0 and system.getTimeCounter() < 0 then
      print("system.getTimeCounter() wrapped. Restart emulator")
   end

   --print("+", RTH.settings.altId, RTH.settings.altPa)
   sensor = system.getSensorByID(RTH.settings.altId, RTH.settings.altPa)
   --print("~", sensor, sensor.valid, sensor.value)
   if sensor and sensor.valid then
      --print("##", RTH.var.startTakeoffAlt, sensor.value)
      if not RTH.var.startTakeoffAlt then
	 RTH.var.startTakeoffAlt = sensor.value
      end
      RTH.altitude = sensor.value - RTH.var.startTakeoffAlt
      --print("RTH.altitude", RTH.altitude)
   end

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
      --print("#", gs.latId, gs.latPa, gs.lngId, gs.lngPa)
      RTH.curPos = gps.getPosition(gs.latId, gs.latPa, gs.lngPa)
      --print("%", RTH.curPos)
      if RTH.curPos then
	 if not RTH.lastPos then RTH.lastPos = RTH.curPos end
	 if gps.getDistance(RTH.curPos, RTH.lastPos) > MINHDGDIST then 
	    compHdg = gps.getBearing(RTH.lastPos, RTH.curPos)
	    --print("compHdg", compHdg)
	    RTH.lastPos = RTH.curPos
	 end
      end
      local lt, lg = 0, 0
      if RTH.curPos then lt, lg = gps.getValue(RTH.curPos) end
      --print("$", lt, lg, RTH.initPos)
      if RTH.curPos and lt ~= 0 and lg ~= 0 and not RTH.initPos then
	 RTH.gpsReads = RTH.gpsReads + 1
	 print("DFM-RTH: RTH.gpsReads:", RTH.gpsReads)
      end
      if RTH.gpsReads > MINGPSREADS and not RTH.initPos then
	 system.messageBox("DFM-RTH: GPS zero set")
	 print("DFM-RTH: GPS zero set")
	 RTH.initPos = RTH.curPos
	 if not RTH.zeroPos then
	    RTH.zeroPos = RTH.curPos
	 end
	 if not RTH.var.zeroPos then
	    RTH.var.zeroPos = RTH.curPos
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
   if now - lastSec > 2000 then
      --print(RTH.gpsBearingFrom, RTH.gpsBearingTo, RTH.gpsDistance, RTH.gpsHeading, RTH.altitude)
      lastSec = now + 2000
   end

   -- read the switch for RTH steering on/off
   if RTH.settings.onoffSw then
      info = system.getSwitchInfo(RTH.settings.onoffSw)
      if info then
	 onoff = info.value
      else
	 onoff = -1
      end
   end
   
   RTH.settings.onoff = onoff
   
   if lastonoff == -1 and onoff == 1 then
      system.playFile(pathApp .. "Audio/rthenabled.wav", AUDIO_QUEUE)
      fifteenSec = now
   end

   lastonoff = onoff
   
   -- if on, compute and set steering control
   -- and make 15 sec announcements when scheduled
   RTH.settings.steer = 0
   if onoff == 1 then
      if RTH.gpsHeading and RTH.gpsBearingFrom then
	 RTH.settings.steer = (-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180
	 --print("steer:", RTH.settings.steer)
      end
      if RTH.settings.steerCtrl and RTH.settings.steer then
	 system.setControl(RTH.settings.steerCtrl, RTH.settings.steer / 180.0, 1000, 1)
	 if now >= fifteenSec then
	    if RTH.gpsBearingFrom then
	       system.playFile(pathApp .. "Audio/bearing.wav", AUDIO_QUEUE)
	       system.playNumber(RTH.gpsBearingFrom, 0, "°")
	    end
	    if RTH.gpsDistance then
	       system.playFile(pathApp .. "Audio/distance.wav", AUDIO_QUEUE)
	       system.playNumber(RTH.gpsDistance, 0, "m")
	    end
	    if RTH.altitude then
	       system.playFile(pathApp .. "Audio/altitude.wav", AUDIO_QUEUE)
	       system.playNumber(RTH.altitude, 0, "m")
	    end
	    fifteenSec = now + 15000
	 end
      end
   end
end

local function initForm()

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
   
   local hdgsel = 0
   for k = 1, #RTH.sensorLalist do
      if (RTH.sensorIdlist[k] == RTH.settings.hdgId) and
	 (RTH.sensorPalist[k] == RTH.settings.hdgPa) then
	 hdgsel = k
      end
   end

   local rollsel = 0
   for k = 1, #RTH.sensorLalist do
      if (RTH.sensorIdlist[k] == RTH.settings.rollId) and
	 (RTH.sensorPalist[k] == RTH.settings.rollPa) then
	 rollsel = k
      end
   end
   
   local pitchsel = 0
   for k = 1, #RTH.sensorLalist do
      if (RTH.sensorIdlist[k] == RTH.settings.pitchId) and
	 (RTH.sensorPalist[k] == RTH.settings.pitchPa) then
	 pitchsel = k
      end
   end

   local function onoffChanged(value)
      RTH.settings.onoffSw = value
      system.pSave("RTHonoffSw", RTH.settings.onoffSw)
   end
   
   form.addRow(2)
   form.addLabel({label="RTH on/off switch", width=280})
   form.addInputbox(RTH.settings.onoffSw, true, onoffChanged, {alignRight=true})
   
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

end



local function drawShape(col, row, shape, rotation)
 sinShape = math.sin(rotation)
 cosShape = math.cos(rotation)
 renShape:reset()
 for _, point in pairs(shape) do
 renShape:addPoint(
 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
 )
 end
 renShape:renderPolygon()
end

local function printForm(w,h)
end

local function destroy()
end

local function xytopixel(x, y, w, h)
   
   local xmin, xmax = -400, 400
   local ymin, ymax = -400, 400
   local ix = (w) * (x - xmin) / (xmax - xmin)
   local iy = h - (h) * (y - ymin) / (ymax - ymin)
   return ix,iy
end

local function printTeleBig(w,h)
   if not RTH.gpsBearingTo then return end
   lcd.drawText(5,  2, string.format("Distance: %.0f", RTH.gpsDistance or 0), FONT_NORMAL)
   lcd.drawText(5, 20, string.format("Bearing: %.0f°", RTH.gpsBearingTo or 0), FONT_NORMAL)
   lcd.drawText(5, 38, string.format("Heading: %.0f°", RTH.gpsHeading or 0), FONT_NORMAL)   
   lcd.drawText(5, 54, string.format("Altitude: %.1f ", RTH.altitude or 0), FONT_NORMAL)

   if RTH.gpsHeading and RTH.gpsBearingFrom then
      local steer = RTH.settings.steer
      local normSteer = steer / 180.0
      --normSteer = system.getInputs("P4")
      --print(normSteer)
      lcd.drawRectangle(20,75,120,20)
      if RTH.settings.onoff == 1 then lcd.setColor(255,0,0) else lcd.setColor(0,0,0) end
      lcd.drawFilledRectangle(79, 75, 2, 20)
      if normSteer >= 0 then
	 lcd.drawFilledRectangle(80,75, 60*normSteer, 20)
      else
	 local ns = math.floor(60*(1+normSteer))
	 lcd.drawFilledRectangle(20 + ns,75, 60-ns, 20)	 
      end
   end
   if RTH.gpsHeading then
      lcd.setColor(0,0,255)
      drawShape(120,20, homeShape, math.rad(RTH.gpsHeading)) 
   end
   
end

local function printTeleAH()
   
   local HP = require 'DFM-RTH/hp1345a'
   local function drawPitch(roll, pitch, pitchR, radAH, X0, Y0, scl)

      local XH,YH,X1,X2,X3,Y1,Y2,Y3,X4,Y4
      local pp, pps
      local XHS = 18 * radAH / 70
      local  XHL = 40 * radAH / 70
      local  scale = scl * radAH / 70
      
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
	    ren:reset()
	    ren:addPoint(X0 + radAH + X1, Y0 + radAH + Y1)
	    ren:addPoint(X0 + radAH + X2, Y0 + radAH + Y2)
	    if (XH == XHL) then
	       ren:renderPolyline(2)
	    else
	       ren:renderPolyline(1)
	    end
	    
	    if (XH == XHS) then
	       HP.drawHP1345A(X0 + radAH + X3, Y0 + radAH + Y3, pps, scale,
			      math.rad(roll), 1);
	       HP.drawHP1345A(X0 + radAH + X4, Y0 + radAH + Y4, pps, scale,
			      math.rad(roll), 1);
	    end
	 end
	 i = i + 15
      until i >= 45 + delta
   end

   --[[
      function artHorizon is based on code in the Jeti Artificial Horizon App
      
      Copyright (c) 2016 JETI
      Copyright (c) 2015 dandys.
      Copyright (c) 2014 Marco Ricci.
      
      Use here conforms with the license terms
   --]]
   
   local pitch = pitchVal or 0 -- system.getInputs("P2") * 90 -- pitchVal or 0 
   local roll = rollVal or 0 --system.getInputs("P3") * 180 -- rollVal or 0
   --183
   local rowAH = 130 / 2 - 20; --widget.width / 2 - 20;
   local radAH = 130 / 2 - 20; --widget.width / 2 - 20;
   local pitchR = radAH / 25;

   local tanRoll
   local cosRoll
   
   local dPitch_1
   local dPitch_2

   local X0, Y0, X1, Y1, Y2, YH
   local ren = lcd.renderer()

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
   X0 = 80 - radAH --widget.x0 - radAH
   Y0 = 50 - radAH --widget.y0 - radAH
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
   drawPitch(roll, pitch, pitchR, radAH, X0, Y0, 0.4);
   
   lcd.resetClipping()

   lcd.setColor(255,255,255)
   --drawTextCenter(widget.xL, widget.yL, widget.label, edit.fcode[fL])
   drawTextCenter(0, 0, "wl", FONT_MINI)
   
end

local function printTele(w,h)
   if not RTH.gpsBearingTo then return end
   --local tl = gps.newPoint(41.340733, -74.432382)
   --local x, y = gps.getLcdXY(RTH.curPos, tl, 14)
   local x = RTH.gpsDistance * math.sin(math.rad(RTH.gpsBearingTo))
   local y = RTH.gpsDistance * math.cos(math.rad(RTH.gpsBearingTo))   

   local ix, iy = xytopixel(x, y, w, h)
   lcd.drawCircle(ix, iy, 10)
   local ix0 , iy0 = xytopixel(0, 0, w, h)
   lcd.setColor(0,0,255)
   lcd.drawCircle(ix0, iy0, 5)
   lcd.drawText(20, 20, string.format("gpsDistance: %.2f", RTH.gpsDistance), FONT_MINI)
   lcd.drawText(20, 40, string.format("gpsBearingTo: %.2f ", RTH.gpsBearingTo), FONT_MINI)
   lcd.drawText(20, 60, string.format("gpsBearingFrom: %.2f ", RTH.gpsBearingFrom), FONT_MINI)

   lcd.setColor(0,255,0)
   if RTH.gpsHeading then
      local ixh, iyh = ix + 20 * math.sin(math.rad(RTH.gpsHeading)),
	 iy - 20 * math.cos(math.rad(RTH.gpsHeading))
      lcd.drawLine(ix, iy, ixh, iyh)
      lcd.drawText(20, 80, string.format("gpsHeading: %.2f ", RTH.gpsHeading or 0), FONT_MINI)   

   end

   lcd.setColor(255,0,0)
   if RTH.gpsHeading and RTH.gpsBearingFrom then
      local steer = RTH.settings.steer --(-RTH.gpsHeading + RTH.gpsBearingFrom + 180) % 360 - 180
      lcd.drawText(20, 100, string.format("Steer: %.2f ", steer), FONT_MINI)
      local ixs, iys = ix + 20 * math.sin(math.rad(steer)), iy - 20 * math.cos(math.rad(steer)) 
      lcd.drawLine(ix, iy, ixs, iys)
      local normSteer = steer / 180.0
      lcd.drawRectangle(60,120,200,30)
      --normSteer = system.getInputs("P4")
      lcd.drawFilledRectangle(159, 120, 2, 30) 
      if normSteer >= 0 then
	 lcd.drawFilledRectangle(160,120, 100*normSteer, 30)
      else
	 local ns = math.floor(100*(1+normSteer))
	 lcd.drawFilledRectangle(60 + ns,120, math.floor(100-ns+0.5), 30)	 
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
      print("##", RTH.settings.steer, RTH.settings.steer / 1.80)
      return (RTH.settings.steer or 0) / 1.80
   else
      return -999
   end
end

local function init()

   readSensors(RTH)
   
   system.registerForm(1, MENU_APPS, "DFM-RTH", initForm, nil, printForm)
   
   local device
   device, emflag = system.getDeviceType() 
   print("Device", device, "emflag", emflag)
   
   system.registerTelemetry(1, "RTH Attitude", 2, printTeleAH)
   system.registerTelemetry(2, "RTH Status", 2, printTeleBig)

   RTH.settings = {}
   RTH.settings.latId = system.pLoad("RTHlatId", 0)
   RTH.settings.latPa = system.pLoad("RTHlatPa", 0)
   RTH.settings.lngId = system.pLoad("RTHlngId", 0)
   RTH.settings.lngPa = system.pLoad("RTHlngPa", 0)
   RTH.settings.altId = system.pLoad("RTHaltId", 0)
   RTH.settings.altPa = system.pLoad("RTHaltPa", 0)
   RTH.settings.hdgId = system.pLoad("RTHhdgId", 0)
   RTH.settings.rollPa = system.pLoad("RTHhdgPa", 0)
   RTH.settings.rollId = system.pLoad("RTHRollId", 0)
   RTH.settings.rollPa = system.pLoad("RTHRollPa", 0)
   RTH.settings.pitchId = system.pLoad("RTHPitchId", 0)
   RTH.settings.pitchPa = system.pLoad("RTHPitchPa", 0)      
   RTH.settings.onoffSw = system.pLoad("RTHonoffSw")
      
   RTH.gpsReads = 0
   RTH.initPos = nil
   RTH.curPos = nil
   RTH.zeroPos = nil

   RTH.settings.steerCtrl = nil
   for i=1,10,1 do
      RTH.settings.steerCtrl = system.registerControl(i, "RTH Steering", "RTH")
      if RTH.settings.steerCtrl then break end
   end

   RTH.settings.steer = 0

   if RTH.settings.steerCtrl then
      print(appName ..": Steering registered to control "..RTH.settings.steerCtrl)
      system.setControl(RTH.settings.steerCtrl, RTH.settings.steer, 0)
   else
      print(appName .. ": Could not register steer control")
      system.messageBox(appName .. ": Could not register steer control")
   end

   system.registerLogVariable("RTHBrgFrom", "°", logfileCB)
   system.registerLogVariable("RTHBrgTo",   "°", logfileCB)
   system.registerLogVariable("RTHDst",     "m", logfileCB)
   system.registerLogVariable("RTHHdg",     "°", logfileCB)
   system.registerLogVariable("RTHStr",     "%", logfileCB)
			      
--[[
   if emflag ~= 0 then
      print("*** DFM-RTH: BDS Defaults being set")
      RTH.settings.latId = 3
      RTH.settings.latPa = 2
      RTH.settings.lngId = 3
      RTH.settings.lngPa = 3
      RTH.settings.altId = 137
      RTH.settings.altPa = 1
   end
   --]]

end
   
return {init=init, loop=loop, author="DFM", destroy=destroy, version="0.02", name=appName}
