--[[

----------------------------------------------------------------------------

   AutoThrottle and Speed Announcer. Implements user interface for
   Digitech's CTU device's auththrottle. Also Makes voice announcement
   of speed with variable intevals when model goes faster or slower or
   on final approach
   
   Borrowed some display code from Daniel M's excellent CTU app
   
----------------------------------------------------------------------------
   Released under MIT-license by DFM 2019
----------------------------------------------------------------------------

--]]

-- Locals for application

local appShort= "CTUAutoT"
local appVersion = "1.0"
local appAuthor = "Digitech"
local appDir = "Apps/digitechAT/"
local transFile = appDir .. "Trans.jsn"

local spdSwitch
local contSwitch
local maxSpd, VrefSpd, VrefCall
local spdInter
local selFt
local selFtIndex
local MAXSPEEDMPH = 200
local MAXSPEEDKPH = 320
local gaugeMaxSpeed
local shortAnn, shortAnnIndex

local ATStateSeId
local ATStateSePa

local ATState

local ATPresetSeId
local ATPresetSePa

local ATAirspeedSeId
local ATAirspeedSePa

local ATengSeId
local ATengSePa

local CTUThrSeId
local CTUThrSePa

local ovrSpd = false
local aboveVref = false
local aboveVref_ever = false
local stall_warn=false
local nextAnnTC = 0
local lastAnnTC = 0
local lastAnnSpd = 0
local calSpd = 0
local sgTC
local sgTC0
local airspeedCal

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local gauge_c={}
local gauge_s={}

local throttle=0
local speed = 0
local set_speed = 0
local errsig = 0
local dropOutTime=0
local lastGoodThr=0

local iTerm = 0
local pTerm = 0
local dTerm = 0

local CTUpLogIdx
local CTUiLogIdx
local CTUdLogIdx

local autoOn = false
local autoOffTime = 0
local offThrottle
local playedBeep = true
local set_stable = 0
local last_set = 0
local appStartTime

local DEBUG = false
--------------------------------------------------------------------------------

-- Read and set translations
local lang
local lng
local function setLanguage()
   local obj
   lng=system.getLocale()
   --lng="nl"
   local file = io.readall(transFile)
   if file then
      obj = json.decode(file)
   end
   if obj then
      lang = obj[lng] or obj.default
   end
   if not lang then
      system.messageBox(appShort..lang.labelMissing..transFile)
   end
end

--------------------------------------------------------------------------------

local function playFile(filename, parm)
   if lng == 'en' then prefix = appDir else
      prefix = appDir..lng.."-"
   end
   print("calling playfile:", prefix..filename, parm)
   system.playFile(prefix..filename, parm)
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select

local currentLabel

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then -- it's a label
	    currentLabel = sensor.label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)
	 end
	 
	 table.insert(sensorLalist, sensor.label)
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
      end
      
      -- special case code for CTU Autothrottle sensors: State, Preset
      -- Speed and Airspeed plus CTU Throttle search for the device
      -- name, label and parameter matching the desired device and put
      -- it into the table of sensors so that user does not have to
      -- select them not filling in ATxxxSe since never need to use
      -- the sensor list in the menu

      if currentLabel == "Autothrottle" and sensor.label == 'State' and sensor.param == 1 then
	 ATStateSeId = sensor.id
	 ATStateSePa = sensor.param
      end

      if currentLabel == "Autothrottle" and sensor.label == 'Preset speed' and sensor.param == 2 then
	 ATPresetSeId = sensor.id
	 ATPresetSePa = sensor.param
      end
      
      if currentLabel == "Autothrottle" and sensor.label == 'Airspeed' and sensor.param == 3 then
	 ATAirspeedSeId = sensor.id
	 ATAirspeedSePa = sensor.param
      end      

      if currentLabel == "Autothrottle" and sensor.label == 'ATeng' and sensor.param == 4 then
	 ATengSeId = sensor.id
	 ATengSePa = sensor.param
      end
      
      if currentLabel == "CTU" and sensor.label == 'Throttle' and sensor.param == 11 then
	 CTUThrSeId = sensor.id
	 CTUThrSePa = sensor.param
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

local function spdInterChanged(value)
   spdInter = value
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

local function airCalChanged(value)
   airspeedCal = value
   system.pSave("airspeedCal", value)
end

local function selFtClicked(value)
   selFt = not value
   form.setValue(selFtIndex, selFt)
   if selFt then gaugeMaxSpeed = MAXSPEEDMPH else gaugeMaxSpeed = MAXSPEEDKPH end
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

   form.addRow(2)
   form.addLabel({label=lang.menuSelAnnEnable, width=220})
   form.addInputbox(spdSwitch, false, spdSwitchChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuSelContAnn, width=220})
   form.addInputbox(contSwitch, false, contSwitchChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuSpeedChgScl, width=220})
   form.addIntbox(spdInter, 1, 100, 10, 0, 1, spdInterChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuVref, width=220})
   form.addIntbox(VrefSpd, 0, 1000, 0, 0, 1, VrefSpdChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuCallSpeed, width=220})
   form.addIntbox(VrefCall, 1, 10, 3, 0, 1, VrefCallChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuSpeedMax, width=220})
   form.addIntbox(maxSpd, 0, 10000, 350, 0, 1, maxSpdChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuAirSpCal, width=220})
   form.addIntbox(airspeedCal, 1, 200, 100, 0, 1, airCalChanged)
   
   form.addRow(2)
   form.addLabel({label=lang.menuMPHorKPH, width=270})
   selFtIndex = form.addCheckbox(selFt, selFtClicked)
   
   form.addRow(2)
   form.addLabel({label=lang.menuShortAnn, width=270})
   shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   
   form.addRow(1)
   form.addLabel({label=lang.appName.." v"..appVersion, font=FONT_MINI, alignRight=true})

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
   for _, point in pairs(shape) do
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
   -- for debugging:
   --lcd.drawText((oxc-w//2) - 10, (oyc-h//2) - 15, string.format("%d", math.floor(val)), FONT_MINI)
   
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
   -- for debugging:
   --lcd.drawText((oxc-w//2) - 10, (oyc-h//2) - 15, string.format("%d", math.floor(val)), FONT_MINI)
   
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

    lcd.setColor(255, 0, 0)
    if gauge_s then lcd.drawImage(ox-gauge_s.width//2, oy-gauge_s.width//2, gauge_s) end
    drawShape(ox, oy, needle_poly_small_small, theta)
    lcd.drawFilledRectangle(ox-1, oy-32, 2, 8)
    lcd.setColor(0,0,0)
    lcd.drawText(ox - lcd.getTextWidth(FONT_MINI, lang.labelErr) // 2, oy + 0,
		 lang.labelErr, FONT_MINI)

end

--------------------------------------------------------

local function DrawThrottle()

    local ox, oy = 1, 8
    local thetaThr, thetaOffThr
    
    local textThrottle = string.format("%d", math.floor(throttle + 0.5))


    lcd.drawText(ox + 66 - lcd.getTextWidth(FONT_NORMAL, lang.labelPctThr)/2,
		 oy + 100, lang.labelPctThr, FONT_NORMAL)
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 66 - lcd.getTextWidth(FONT_MAXI, textThrottle) // 2,
		 oy + 40, textThrottle, FONT_MAXI)

    thetaThr = math.pi - math.rad(135 - 2 * 135 * throttle // 100)

    lcd.setColor(255, 0, 0)
    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    drawShape(ox+65, oy+60, needle_poly_large, thetaThr)
    if autoOn == false and offThrottle and system.getTimeCounter() - autoOffTime < 5000 then 
       if math.abs(throttle-offThrottle) < 2 and playedBeep == false then
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

    if selFt then
       lcd.drawText(ox + 66 - lcd.getTextWidth(FONT_NORMAL, lang.labelMPH)/2,
		    oy + 100, lang.labelMPH, FONT_NORMAL)
    else
       lcd.drawText(ox + 66 - lcd.getTextWidth(FONT_NORMAL, lang.labelKPH)/2,
		    oy + 100, lang.labelKPH, FONT_NORMAL)
    end
    
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textSpeed) / 2, oy + 40,
		 textSpeed, FONT_MAXI)

    local thetaThr = math.pi - math.rad(135 - 2 * 135 * speed / gaugeMaxSpeed)
    local thetaSet = math.pi - math.rad(135 - 2 * 135 * set_speed / gaugeMaxSpeed)

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
    
    lcd.drawRectangle(ox, oy, W, H)

    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI, lang.labelSetPt)) / 2, oy,
		 lang.labelSetPt, FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,lang.labelSpeed)) / 2, oy+23,
		 lang.labelSpeed, FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI, lang.labelState)) / 2, oy+46,
		 lang.labelState, FONT_MINI)

    lcd.drawLine(ox, oy + 23, ox + W - 1, oy + 23)
    lcd.drawLine(ox, oy + 46, ox + W - 1, oy + 46)
    
    text = string.format("%d", math.floor(set_speed+0.5))
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 7, text, FONT_BOLD)

    text = string.format("%d", math.floor(speed + 0.5))
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 30, text, FONT_BOLD)

    if ATState then
       text = string.format("%d", math.floor(ATState) )
    else
       text = "---"
    end
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 53, text, FONT_BOLD)    

end

--------------------------------------------------------------------------------

local function wbTele()
   if not DEBUG and ATState and ATState > 1 and dropOutTime > 0 then
      lcd.drawText(5,5,string.format("%d", dropOutTime), FONT_MINI)
   else
      dropOutTime = 0
   end
   
   DrawThrottle()
   DrawSpeed()
   DrawCenterBox(0,0,0,0)
   DrawRectGaugeCenter( 66, 140, 70, 16, -100, 100, pTerm, lang.labelProp)
   DrawRectGaugeAbs(158, 140, 70, 16,    0, 100, iTerm, lang.labelInteg)
   DrawRectGaugeCenter(252, 140, 70, 16,  -20,  20, dTerm, lang.labelDeriv)
   DrawErrsig()
end

--------------------------------------------------------------------------------

local function convertSpeed(s)
   -- telemetry comes in with native units (m/s)
   if selFt then
      return s * 2.23694 -- m/s to mph
   else
      return s * 3.6 -- m/s to km/hr
   end
end

--------------------------------------------------------------------------------

local function logCB(idx)

   if idx == CTUpLogIdx then
      return math.floor(pTerm), 0
   elseif idx == CTUiLogIdx then
      return math.floor(iTerm), 0
   elseif idx == CTUdLogIdx then
      return math.floor(dTerm), 0
   else
      return 0, 0
   end

end

--------------------------------------------------------------------------------

-- persistent vars to keep ring buffer of last MAXRING throttle settings
-- for 20 msec loop time, 10 entries spans a 200msec telem update interval
-- need to "look back" at throttle setting in case throttle telem value set to
-- zero before it can be noted by the lua program

local thrRingBuf = {}
local thrSeq = 0
local MAXRING = 20

local function loop()

   local deltaSA
   local sss, uuu
   local round_spd
   local swi, swc
   local isen
   local thrStick, thrIdx
   
   -- gather some stats on loop times so we can normalize integrator performance
   
   if not appStartTime then appStartTime = system.getTimeCounter() end
      
   thrStick = 50 * (system.getInputs("P4") + 1) -- 0 to 100% of stick movement .. ignores trim
   
   -- first get AT state from CTU. 0 is off, 1 is armed, waiting to turn on, 2 is on
   
   if ATStateSeId and ATStateSeId ~= 0 then
      sensor = system.getSensorByID(ATStateSeId, ATStateSePa)
   end

   if (sensor and sensor.valid) then
      ATState = sensor.value
      if autoOn == true and ATState < 2 then   -- it's just turning off
	 autoOffTime = system.getTimeCounter() -- note when it went off
	 --offThrottle = throttle                -- note it's last value (last time thru loop)
	 offThrottle = thrRingBuf[(thrSeq + 1) % MAXRING + 1] or 0 -- oldest value or 0 if buf not full
	 playedBeep = false                    -- make sure we only beep once
	 playFile('ATCancelled.wav', AUDIO_QUEUE)
	 if DEBUG then print("AutoThrottle Cancelled") end
	 system.messageBox(lang.labelATCancelled) -- also put in log file
      end

      if autoOn == false and ATState == 2 then  -- it's just turning on
	 playFile('ATEnabled.wav', AUDIO_QUEUE)
	 if DEBUG then print("AutoThrottle Enabled") end
	 system.messageBox(lang.labelATEnabled) -- also puts in log file
      end

      autoOn = ATState > 1
   end

   -- read the Preset Speed telemetry value from the CTU
   -- if DEBUG mode, read directly from the speed select control (assume P5)
   -- check if the speed select control is stable, if so announce value once
   
   if ATPresetSeId and ATPresetSeId ~= 0 then
      sensor = system.getSensorByID(ATPresetSeId, ATPresetSePa)
   end

   if (sensor and sensor.valid) then
      set_speed = convertSpeed(sensor.value)
   else
      if DEBUG then
	 set_speed = gaugeMaxSpeed/2 * (1 + system.getInputs("P5"))
      end
   end
      
   -- check to see if set speed has stopped changing. if so announce verbally one time only
   -- 40 loops is arbitrary .. picked because it created an appropriate delay time

   local sSC = 40
   
   if set_speed and last_set and set_stable then
      if math.abs(set_speed - last_set) < 2 then -- expt'g to find the right val for this abs
	 if set_stable < sSC then set_stable = set_stable + 1 end 
      else
	 set_stable = 1
      end
      if set_stable == sSC then
	 set_stable = sSC+1 -- only play the number once when stabilized
	 --if set_speed > VrefSpd / 1.3 then -- don't announce if setpoint below stall
	 if DEBUG then print("Set speed stable at", set_speed) end
	 playFile('ATSetPointStable.wav', AUDIO_QUEUE)      	    
	 if selFt then uuu = "mph" else uuu = "km/h" end
	 system.playNumber(math.floor(set_speed+0.5), 0, uuu)
	 system.messageBox(lang.labelSetPtSpd..math.floor(set_speed+0.5)) -- goes in log 
      end
   end

   last_set = set_speed

   -- read pitot airspeed from CTU
   
   if ATAirspeedSeId and ATAirspeedSeId ~= 0 then
      sensor = system.getSensorByID(ATAirspeedSeId, ATAirspeedSePa)
   end

   if (sensor and sensor.valid) then
      speed = convertSpeed(sensor.value) * airspeedCal / 100.0
   end

   -- get engineering parameters from the CTU (live PID loop term values)
   -- unpack the bytes. deriv in byte 0, Integ in byte 1, propo in byte 2
   
   if ATengSeId and ATengSeId ~= 0 then
      sensor = system.getSensorByID(ATengSeId, ATengSePa)
   end

   if (sensor and sensor.valid) then
      isen = math.floor(sensor.value)
      
      dTerm = isen & 0xFF
      isen = isen >> 8
      iTerm = isen & 0xFF
      isen = isen >> 8
      pTerm = isen & 0xFF

      -- "sign extend" the values .. -100 to 100 coded as 8 bits .. MSB is sign
    
      if dTerm > 127 then dTerm = dTerm - 256 end
      if iTerm > 127 then iTerm = iTerm - 256 end
      if pTerm > 127 then pTerm = pTerm - 256 end      

   end
   
   if CTUThrSeId and CTUThrSeId ~= 0 then
      sensor = system.getSensorByID(CTUThrSeId, CTUThrSePa)
   end

   if sensor and sensor.valid and ATState and ATState > 0 then
      throttle = sensor.value
      lastGoodThr = system.getTimeCounter()
   else -- TEST .. in case not valid don't set to value of thrStick (0)!
      if lastGoodThr == 0 then lastGoodThr = system.getTimeCounter() end
      dropOutTime = math.floor(system.getTimeCounter() - lastGoodThr) 
   end

   if not ATState or ATState == 0 then throttle = thrStick end

   thrSeq = thrSeq + 1
   thrIdx = thrSeq % MAXRING + 1 -- 1 ..MAXRING
   thrRingBuf[thrIdx] = throttle
   

   errsig = speed - set_speed
   
   ----------------------------------------------------------------------------------
   -- this is the speed announcer section, return if announce not on or on continuous
   -- first read the configuration from the switches that have been assigned
   ----------------------------------------------------------------------------------

   swi = system.getInputsVal(spdSwitch)  -- enable normal speed announce vary by delta speed
   swc = system.getInputsVal(contSwitch) -- enable continuous annonucements

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
	 playFile('ATOverspeed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("Overspeed!") end
	 system.vibration(true, 3) -- 2x vibrations on right stick
      end

      if (speed <= VrefSpd and aboveVref) then
	 aboveVref = false
	 playFile('ATV_Ref_Speed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("At Vref") end
      end

      if ((speed <= VrefSpd/1.3) and (not stall_warn) and aboveVref_ever) then
	 stall_warn = true
	 playFile('ATStall_Warning.wav', AUDIO_IMMEDIATE)
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
         ((sgTC > nextAnnTC) and ( (speed > VrefSpd / 2) or (swc and swc == 1))) then

	 lastAnnSpd = speed
	 round_spd = math.floor(speed+0.5)
	 
	 lastAnnTC = sgTC -- note the time of this announcement
	 
	 sss = string.format("%.0f", round_spd)
	 if (selFt) then uuu = "mph" else uuu = "km/h" end
	 
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
    gauge_c = lcd.loadImage("Apps/DFM-CTUat/c-000.png")
    gauge_s = lcd.loadImage("Apps/DFM-CTUat/s-000.png")
    if not gauge_c or not gauge_s then print(lang.labelNoGauges) end
end
--------------------------------------------------------------------------------

local function calAirspeed()
   local u
   if (selFt) then u = lang.labelMPH else u = lang.labelKPH end 
   lcd.drawText(5, 5, math.floor(calSpd+0.5) .. " " .. u)
end

local function init()

   local dev, em

   spdSwitch = system.pLoad("spdSwitch")
   contSwitch = system.pLoad("contSwitch")
   spdInter = system.pLoad("spdInter", 10)
   VrefSpd = system.pLoad("VrefSpd", 60)
   VrefCall = system.pLoad("VrefCall", 2)
   maxSpd = system.pLoad("maxSpd", 200)
   airspeedCal = system.pLoad("airspeedCal", 100)
   selFt = system.pLoad("selFt", "true")
   shortAnn = system.pLoad("shortAnn", "false")

   selFt = (selFt == "true") -- can't pSave and pLoad booleans...store as text 
   if selFt then gaugeMaxSpeed = MAXSPEEDMPH else gaugeMaxSpeed = MAXSPEEDKPH end
   shortAnn = (shortAnn == "true") -- convert back to boolean here
   
   system.registerForm(1, MENU_APPS, lang.appName, initForm)
   system.registerTelemetry(1, lang.appName, 4, wbTele)
   system.registerTelemetry(2, lang.labelCalAirSp, 1, calAirspeed)

   CTUpLogIdx = system.registerLogVariable("CTUpropo", "%", logCB)
   CTUiLogIdx = system.registerLogVariable("CTUinteg", "%", logCB)
   CTUdLogIdx = system.registerLogVariable("CTUderiv", "%", logCB)   

   dev, em = system.getDeviceType()
   DEBUG = (em == 1)

   readSensors()
   loadImages()

end

--------------------------------------------------------------------------------

setLanguage()

return {init=init, loop=loop, author=appAuthor, version=appVersion,
	name=lang.appName}
 
