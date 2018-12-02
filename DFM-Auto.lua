--[[

----------------------------------------------------------------------------
    AutoThrottle and Speed Announcer  makes voice announcement of speed with
    variable intevals when model goes faster or slower
    or on final approach. Also implements PID controlled autothrottle.
    Originally adapted/derived from RCT's AltA
    
    Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------
	Released under MIT-license by DFM 2018
----------------------------------------------------------------------------

--]]

collectgarbage()

--------------------------------------------------------------------------------

-- Locals for application

local trans11
local spdSwitch
local contSwitch
local autoSwitch
local setPtControl
local spdSe
local spdSeId
local spdSePa
local maxSpd, VrefSpd, VrefCall
local spdInter
local selFt
local selFtIndex
local shortAnn, shortAnnIndex

local ovrSpd = false
local aboveVref = false
local aboveVref_ever = false
local stall_warn=false
local nextAnnTC = 0
local lastAnnTC = 0
local lastAnnSpd = 0
local sgTC
local sgTC0
local airspeedCal
local SpdAnnCCVersion

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local gauge_c={}
local gauge_s={}
local throttle=0
local speed = 0
local tgt_speed = 0
local set_speed = 0
local iTerm = 0
local pTerm = 0
local dTerm = 0
local spdTable={}
local timTable={}
local MAXTABLE=20
local errsig = 0
local autoOn = false
local lastAuto = false
local autoForceOff = false
local throttleDownTime = 0
local lastValid = 0
local throttlePosAtOn
local pGain
local iGain
local dGain
local autoOffTime = 0
local offThrottle
local lastSetThr
local playedBeep = true
local slAvg

local DEBUG = true
--------------------------------------------------------------------------------

-- Read and set translations

local function setLanguage()
--[[
   local lng=system.getLocale()
   local file = io.readall("Apps/Lang/RCT-SpdA.jsn")
   local obj = json.decode(file)
   if(obj) then
      trans11 = obj[lng] or obj[obj.default]
   end
--]]
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLalist, sensor.label)
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
      end
   end
end

----------------------------------------------------------------------

-- Actions when settings changed

local function spdSwitchChanged(value)
   spdSwitch = value
   system.pSave("spdSwitch", spdSwitch)
end

local function contSwitchChanged(value)
   contSwitch = value
   system.pSave("contSwitch", contSwitch)
end

local function autoSwitchChanged(value)
   autoSwitch = value
   system.pSave("autoSwitch", autoSwitch)
end

local function setPtControlChanged(value)
    setPtControl= value
   system.pSave("setPtControl", setPtControl)
end

local function spdInterChanged(value)
   spdInter = value
   if spdInter == 99 then DEBUG = true end
   if spdInter == 98 then DEBUG = false end
   system.pSave("spdInter", spdInter)
end

local function VrefSpdChanged(value)
   VrefSpd = value
   system.pSave("VrefSpd", VrefSpd)
end

local function VrefCallChanged(value)
   VrefCall = value
   system.pSave("VrefCall", VrefCall)
end

local function maxSpdChanged(value)
   maxSpd = value
   system.pSave("maxSpd", maxSpd)
end

local function pGainChanged(value)
   pGainInput = value
   system.pSave("pGainInput", pGainInput)
end

local function iGainChanged(value)
   iGainInput = value
   system.pSave("iGainInput", iGainInput)
end

local function dGainChanged(value)
   dGainInput = value
   system.pSave("dGainInput", dGainInput)
end


local function airCalChanged(value)
   airspeedCal = value
   system.pSave("airspeedCal", value)
end

local function sensorChanged(value)
   spdSe = value
   spdSeId = sensorIdlist[spdSe]
   spdSePa = sensorPalist[spdSe]
   if (spdSeId == "...") then
      spdSeId = 0
      spdSePa = 0 
   end
   system.pSave("spdSe", spdSe)
   system.pSave("spdSeId", spdSeId)
   system.pSave("spdSePa", spdSePa)
end

local function selFtClicked(value)
   selFt = not value
   form.setValue(selFtIndex, selFt)
   system.pSave("selFt", tostring(selFt))
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then
        
      form.addRow(2)
      form.addLabel({label="Select Speed Sensor", width=220})
      form.addSelectbox(sensorLalist, spdSe, true, sensorChanged)
      
      form.addRow(2)
      form.addLabel({label="Select Enable Switch", width=220})
      form.addInputbox(spdSwitch, false, spdSwitchChanged)

      form.addRow(2)
      form.addLabel({label="Select Continuous Ann Switch", width=220})
      form.addInputbox(contSwitch, false, contSwitchChanged)

      form.addRow(2)
      form.addLabel({label="Select Autothr Switch", width=220})
      form.addInputbox(autoSwitch, false, autoSwitchChanged)

      form.addRow(2)
      form.addLabel({label="Select Autothr SetPt PropCtl", width=220})
      form.addInputbox(setPtControl, true, setPtControlChanged)       
      
      form.addRow(2)
      form.addLabel({label="Speed change scale factor", width=220})
      form.addIntbox(spdInter, 1, 100, 10, 0, 1, spdInterChanged)
      
      form.addRow(2)
      form.addLabel({label="Vref (1.3 Vs0)", width=220})
      form.addIntbox(VrefSpd, 0, 1000, 0, 0, 1, VrefSpdChanged)

      form.addRow(2)
      form.addLabel({label="Call Speed < Vref every (sec)", width=220})
      form.addIntbox(VrefCall, 1, 10, 3, 0, 1, VrefCallChanged)
        
      form.addRow(2)
      form.addLabel({label="Speed Max Warning", width=220})
      form.addIntbox(maxSpd, 0, 10000, 200, 0, 1, maxSpdChanged)

      form.addRow(2)
      form.addLabel({label="Airspeed Calibration Multiplier (%)", width=220})
      form.addIntbox(airspeedCal, 1, 200, 100, 0, 1, airCalChanged)
        
      form.addRow(2)
      form.addLabel({label="PID Proportional gain", width=220})
      form.addIntbox(pGainInput, 0, 100, 1, 0, 1, pGainChanged)

      form.addRow(2)
      form.addLabel({label="PID Integral gain", width=220})
      form.addIntbox(iGainInput, 0, 100, 1, 0, 1, iGainChanged)

      form.addRow(2)
      form.addLabel({label="PID Derivative gain", width=220})
      form.addIntbox(dGainInput, 0, 100, 1, 0, 1, dGainChanged)
      
      form.addRow(2)
      form.addLabel({label="Use mph or km/hr (x)", width=270})
      selFtIndex = form.addCheckbox(selFt, selFtClicked)
      
      form.addRow(2)
      form.addLabel({label="Short Announcement", width=270})
      shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
      
      form.addRow(1)
      form.addLabel({label="DFM-Auto.lua Version "..SpdAnnCCVersion.." ", font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end
end

--------------------------------------------------------------------------------

local needle_poly_large = {
   {-4,28},
   {-2,65},
   {2,65},
   {4,28}
}

local needle_poly_xlarge = {
   {-4,28},
   {-2,70},
   {2,70},
   {4,28}
}

local needle_poly_small = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}

local needle_poly_small_small = {
   {-2,2},
   {-1,20},
   {1,20},
   {2,2}
}

--------------------------------------------------------------------------------

local function drawShape(col, row, shape, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for index, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

--------------------------------------------------------

local function DrawRectGaugeCenter(oxc, oyc, w, h, min, max, val, str)

   local d

   lcd.setColor(0, 0, 255)
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)
   lcd.drawLine(oxc, oyc-h//2, oxc, oyc+h//2-1 )

   if val > 0 then
      d = math.max(math.min((val/max)*(w/2), w/2), 0)
         lcd.drawFilledRectangle(oxc, oyc-h/2, d, h)
   else
      d = math.max(math.min((val/min)*(w/2), w/2), 0)
      
      lcd.drawFilledRectangle(oxc-d+1, oyc-h/2, d, h)
   end

   lcd.setColor(0,0,0)

   if str then
      lcd.drawText(oxc - lcd.getTextWidth(FONT_MINI, str)//2, oyc+7, str, FONT_MINI)

   end
end

--------------------------------------------------------

local function DrawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str)

   local d
   
   lcd.setColor(0, 0, 255)
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)

   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h/2, d, h)
   lcd.setColor(0,0,0)

   if str then
      lcd.drawText(oxc - lcd.getTextWidth(FONT_MINI, str)//2, oyc+7, str, FONT_MINI)
   end
   
end

--------------------------------------------------------

local function DrawErrsig()

    local ox, oy = 158, 110
    local ierr = math.min(math.max(errsig, -100), 100)
    local theta = math.rad(135 * ierr / 100) - math.pi

    if not autoOn then return end
       
    lcd.setColor(255, 0, 0)
    if gauge_s then lcd.drawImage(ox-gauge_s.width//2, oy-gauge_s.width//2, gauge_s) end
    drawShape(ox, oy, needle_poly_small_small, theta)
    lcd.drawFilledRectangle(ox, oy-24, 2, 20)
    lcd.setColor(0,0,0)
    lcd.drawText(ox - lcd.getTextWidth(FONT_MINI, "Err") // 2, oy + 7, "Err", FONT_MINI)

end

--------------------------------------------------------

local function DrawThrottle()

    local ox, oy = 1, 8
    local thetaThr, thetaOffThr
    
    local textThrottle = string.format("%d", math.floor(throttle + 0.5))

    lcd.drawText(ox + 33, oy + 100, "%Throttle", FONT_NORMAL)
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textThrottle) // 2,
		 oy + 40, textThrottle, FONT_MAXI)

    thetaThr = math.pi - math.rad(135 - 2 * 135 * throttle // 100)

    lcd.setColor(255, 0, 0)
    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    drawShape(ox+65, oy+60, needle_poly_large, thetaThr)
    if autoOn == false and system.getTimeCounter() - autoOffTime < 5000 then
       if math.abs(throttle-offThrottle) < 2 and playedBeep == false then
	  print("BEEP!")
	  system.playBeep(2, 3000, 100)
	  playedBeep = true
       end
       thetaOffThr = math.pi - math.rad(135 - 2 * 135 * offThrottle // 100)
       lcd.setColor(0, 0, 255)
       drawShape(ox+65, oy+60, needle_poly_large, thetaOffThr)
    end
    lcd.setColor(0,0,0)
    
end

--------------------------------------------------------

local function DrawSpeed()

    local ox, oy = 186, 8

    local textSpeed = string.format("%d", math.floor(speed + 0.5))

    lcd.drawText(ox + 50, oy + 100, "MPH", FONT_NORMAL)
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textSpeed) / 2, oy + 40,
		 textSpeed, FONT_MAXI)

    local thetaThr = math.pi - math.rad(135 - 2 * 135 * speed / 200)
    local thetaSet = math.pi - math.rad(135 - 2 * 135 * set_speed / 200)

    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    lcd.setColor(0,255,0)
    drawShape(ox+65, oy+60, needle_poly_xlarge, thetaSet)       
    lcd.setColor(255,0,0)
    drawShape(ox+65, oy+60, needle_poly_large, thetaThr)
    lcd.setColor(0, 0, 0)
    
end

--------------------------------------------------------

local function DrawCenterBox()

    local W = 44
    local H = 70
    local ox, oy = 137, 3
    local text
    local ierr
    
    lcd.drawRectangle(ox, oy, W, H)

    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"SetPt")) / 2, oy,    "SetPt", FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Integ")) / 2, oy+23, "Integ", FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Error")) / 2, oy+46, "Error", FONT_MINI)

    lcd.drawLine(ox, oy + 23, ox + W - 1, oy + 23)
    lcd.drawLine(ox, oy + 46, ox + W - 1, oy + 46)
    
    text = string.format("%d", math.floor(set_speed+0.5))
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 7, text, FONT_BOLD)

    text = string.format("%d", math.floor(iTerm + 0.5))
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 30, text, FONT_BOLD)

    if math.abs(errsig) < .015 then ierr = 0.0 else ierr = errsig end
    if ierr > 99 then ierr = 99 end
    if ierr < -99 then ierr = -99 end
    text = string.format("%2.2f", ierr)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 53, text, FONT_BOLD)

end

--------------------------------------------------------------------------------

local function wbTele(w,h)
    DrawThrottle(0,0)
    DrawSpeed(0,0)
    DrawCenterBox(0,0,0,0)
    DrawRectGaugeCenter( 66, 140, 70, 16, -100, 100, pTerm*10, "Proportional")
    DrawRectGaugeAbs(158, 140, 70, 16, 0, 100, iTerm, "Integral")
    DrawRectGaugeCenter(252, 140, 70, 16, -100, 100, dTerm*100, "Derivative")
    DrawErrsig(0,0)
end

--------------------------------------------------------------------------------

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

--------------------------------------------------------

local function get_speed_from_sensor()

   local sensor, slope, sensor_speed, spd, tgt_speed

   if (spdSeId ~= 0) then
      sensor = system.getSensorByID(spdSeId, spdSePa)
   else
      if not DEBUG then return end
   end

   if (sensor and sensor.valid) then
      sensorSpeed = sensor.value * airspeedCal/100.0
      lastValid = system.getTimeCounter()
   else
      if DEBUG then
	 tgt_speed = (throttle/100)^2 * 200 -- simulate plane's response
	 speed = speed + 0.008 * (tgt_speed - speed) -- give it a time lag
	 lastValid = system.getTimeCounter() -- pretent we read a sensor and it was valid
	 spd = speed -- so we return the correct variable
      else
	 return 
      end
   end

   if not DEBUG then
      if selFt then
	 if sensor.unit == "m/s" then
	    spd = sensorSpeed * 2.23694 -- m/s to mph
	 end
	 if sensor.unit == "kmh" or sensor.unit == "km/h" then
	    spd = sensorSpeed * 0.621371 -- km/hr to mph
	 end
      else
	 if sensor.unit == "m/s" then
	    spd = sensorSpeed * 3.6 -- km/hr
	 end
      end
   end

   
   if #spdTable+1 > MAXTABLE then
      table.remove(spdTable, 1)
      table.remove(timTable, 1)
   end
   table.insert(spdTable, speed - set_speed)
   table.insert(timTable, system.getTimeCounter()/1000.)

   slope, _ = fslope(timTable, spdTable)


   return spd, slope

end

--------------------------------------------------------

local function loop()

   local deltaSA
   local sss, uuu
   local slope
   local lowDelay = 6000
   local round_spd = 0
   local swi, swc, swa

   -- first read the configuration from the switches that have been assigned
   
   swi = system.getInputsVal(spdSwitch)  -- enable normal speed announce vary by delta speed
   swc = system.getInputsVal(contSwitch) -- enable continuous annonucements
   swa = system.getInputsVal(autoSwitch) -- enable/arm autothrottle
   
   -----------------------------------------------------------------------------------
   -- this first section is the PID AutoThrottle
   -----------------------------------------------------------------------------------

   if lastValid == 0 and swa and swa == 1 then
      autoOn = false
      autoForceOff = true
      print("Cannot startup with AutoThrottle enabled .. turn off and back on")
   end

   if swa and swa == -1 then -- if turned off, ok to re-enable if it was prohibited prev.
      autoForceOff = false
   end
   
   speed, slope = get_speed_from_sensor()

   if autoOn and (system.getTimeCounter() > lastValid + 10000.) then 
      print("AutoThrottle off because of invalid speed data > 10 s")
      autoOn = false
      autoForceOff = true -- force user to turn switch off then on again
   end
   
   if swa and swa == 1 and not autoForceOff then   
      if autoOn == false then print("AutoThrottle turned on by switch SWA") end
      autoOn = true
   else
      if autoOn == true then print("AutoThrottle turned off by switch SWA") end
      autoOn = false
   end

   -- note that endpoints are not precisely 0% and 100%, e.g. 0.137 and 99.8 on real TX sticks
   -- so need a small fudge factor especially on detecting zero .. set to 4% (see below)
   
   throttle_stick = 50 * (system.getInputs("P4") + 1)

   if not lastAuto and autoOn then -- auto throttle just turned on
      throttle = throttle_stick
      throttlePosAtOn = throttle_stick
      iTerm = throttle_stick -- precharge integrator to this thr setting
      throttleDownTime = system.getTimeCounter() + lowDelay -- # seconds to reduce thr to 0
   end

   if autoOn and math.abs(system.getTimeCounter() - throttleDownTime) < lowDelay then
      if throttle_stick > throttlePosAtOn + 4 then -- moved the stick up during the # secs...
	 print("AutoThrottle off .. moved stick up in the arming interval")
	 autoOn = false
	 autoForceOff = true
      end
   end
   
   if autoOn and system.getTimeCounter() > throttleDownTime and throttle_stick > 4 then
      print("AutoThrottle off -- throttle not at idle")
      autoOn = false
      autoForceOff = true -- can't re-enable till turn switch swa off then on again
   end

   if setPtControl then
      set_speed =  100 * (1 + system.getInputsVal(setPtControl))
   elseif autoOn then
      autoOn = false
      autoForceOff = true
      print("Attempt to arm AutoThrottle with no setpoint speed")
   end
   
   if autoOn then
      pGain = pGainInput / 50.0
      dGain = dGainInput / 500.0
      iGain = iGainInput / 5000.0

      errsig = set_speed - speed

      -- average the derivate .. slopes are noisy probably due to time jitter
      if not slAvg then slAvg = slope else slAvg = slAvg + 0.005*(slope - slAvg) end
	 
      pTerm  = errsig * pGain
      dTerm  = slAvg * dGain * -1
      iTerm  = math.max(0, math.min(iTerm + errsig * iGain, 100))
      
      throttle = pTerm + iTerm + dTerm
      throttle = math.max(0, math.min(throttle, 100))

      system.setControl(autoIdx, (throttle-50)/50, 0)
      lastSetThr = throttle
   else
      iTerm = 0
      pTerm = 0
      dTerm = 0
      throttle = throttle_stick
      system.setControl(autoIdx, -1, 0) -- when off mix to 0% throttle (-1 on -1,1 scale)
   end

   if autoOn == false and lastAuto == true then -- was just turned off
      autoOffTime = system.getTimeCounter()
      offThrottle = lastSetThr -- remember last steady-state throttle
      playedBeep = false
   end
   
      
   lastAuto = autoOn
   
   ----------------------------------------------------------------------------------
   -- this is the speed announcer section, return if announce not on or on continuous
   ----------------------------------------------------------------------------------

   if (swi and swi == 1) or (swc and swc == 1) then
      
      if maxSpd and (speed <= maxSpd) then ovrSpd = false end

      if (speed > VrefSpd) then
	 aboveVref = true
	 aboveVref_ever = true
      end
      
      if (speed > VrefSpd/1.3) then -- re-arm it
	 stall_warn = false
      end

      if (speed > maxSpd and not ovrSpd) then
	 ovrSpd = true
	 system.playFile('/Apps/DFM-SpdA/overspeed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("Overspeed!") end
	 system.vibration(true, 3) -- 2x vibrations on right stick
      end

      if (speed <= VrefSpd and aboveVref) then
	 aboveVref = false
	 system.playFile('/Apps/DFM-SpdA/V_ref_speed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("At Vref") end
      end

      if ((speed <= VrefSpd/1.3) and (not stall_warn) and aboveVref_ever) then
	 stall_warn = true
	 system.playFile('/Apps/DFM-SpdA/stall_warning.wav', AUDIO_IMMEDIATE)
	 system.vibration(true, 4) -- 4 short pulses on right stick
	 if DEBUG then print("Stall warning!") end
      end

      -- this line is the heart of the speed announcer, it determies update timing
      -- vs changes in speed
      -- time-spacing multiplier is scaled by spdInter, over range of 0.5 to 10 (20:1)

      deltaSA = math.min(math.max(math.abs((speed-lastAnnSpd) / spdInter), 0.5), 10)
      
      nextAnnTC = lastAnnTC + (VrefCall * 1000 * 10 / deltaSA) 

      if (speed <= VrefSpd) or (swc and swc == 1) then -- override if below Vref or cont ann is on
	 nextAnnTC = lastAnnTC + VrefCall * 1000 -- at and below Vref .. ann every VrefCall secs
      end

      sgTC = system.getTimeCounter()
      if not sgTC0 then sgTC0 = sgTC end

      -- Added isPlayback() so that we don't create a backlog of messages if it takes
      -- longer than VrefCall time to speak the speed
      -- This was creating a "bow wave" of pending announcements
      -- Wait till speaking is done, catch it at the next call to loop()

      if (not system.isPlayback()) and
         ((sgTC > nextAnnTC) and ( (speed > VrefSpd / 4) or (swc and swc == 1))) then

	 lastAnnSpd = speed
	 round_spd = math.floor(speed+0.5)
	 
	 lastAnnTC = sgTC -- note the time of this announcement
	 
	 sss = string.format("%.0f", round_spd)
	 if (selFt) then uuu = "mph" else uuu = "km/hr" end
	 
	 if (shortAnn or not aboveVref or (swc and swc == 1) ) then
	    system.playNumber(round_spd, 0)
	    if DEBUG then
	       print("(s)speed: ", sss)
	       print("time: ", (sgTC-sgTC0)/1000)
	    end
	 else
	    system.playNumber(round_spd, 0, uuu, "Speed")
	    if DEBUG then
	       print("speed: ", sss, uuu)
	       print("time: ", (sgTC-sgTC0)/1000)		  
	    end
	 end
      end -- if (not system...)
   end
end

--------------------------------------------------------------------------------
-- Load images arrays
local function loadImages()
    gauge_c = lcd.loadImage("Apps/digitech/images/Large/Blue/c-000.png")
    gauge_s = lcd.loadImage("Apps/digitech/images/Compact/Blue/c-000.png")
    if not gauge_c or not gauge_s then print("Gauge png images(s) not loaded") end
end
--------------------------------------------------------------------------------
local function init()


   spdSwitch = system.pLoad("spdSwitch")
   contSwitch = system.pLoad("contSwitch")
   autoSwitch = system.pLoad("autoSwitch")
   setPtControl = system.pLoad("setPtControl")
   spdInter = system.pLoad("spdInter", 10)
   VrefSpd = system.pLoad("VrefSpd", 60)
   VrefCall = system.pLoad("VrefCall", 2)
   maxSpd = system.pLoad("maxSpd", 200)
   pGainInput = system.pLoad("pGainInput", 40)
   iGainInput = system.pLoad("iGainInput", 30)
   dGainInput = system.pLoad("dGainInput", 30)   
   airspeedCal = system.pLoad("airspeedCal", 100)
   spdSe = system.pLoad("spdSe", 0)
   spdSeId = system.pLoad("spdSeId", 0)
   spdSePa = system.pLoad("spdSePa", 0)
   selFt = system.pLoad("selFt", "true")
   shortAnn = system.pLoad("shortAnn", "false")

   selFt = (selFt == "true") -- can't pSave and pLoad booleans...store as text 
   shortAnn = (shortAnn == "true") -- convert back to boolean here
 
   system.registerForm(1, MENU_APPS, "Speed Announcer and AutoThrottle", initForm)

   system.registerTelemetry(1, "Speed Announcer and AutoThrottle", 4, wbTele)    

   system.playFile('/Apps/DFM-Auto/AutoThrottle_act.wav', AUDIO_QUEUE)

   readSensors()
   loadImages()

   autoIdx = system.registerControl(1, "AutoThrottle", "A01")
   print("autoIdx:", autoIdx)
   
end

--------------------------------------------------------------------------------

SpdAnnCCVersion = "1.0"
setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=SpdAnnCCVersion,
	name="Speed Announcer and Cruise Control"}
