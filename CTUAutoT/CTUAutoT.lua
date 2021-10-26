--[[

----------------------------------------------------------------------------

   AutoThrottle UI and Speed Announcer. Implements user interface for
   Digitech's CTU device's auththrottle. Also Makes voice announcement
   of speed with variable intevals when model goes faster or slower or
   on final approach when speed < Vref. Stall warning (stick shaker)
   triggers below Vref/1.3
   
   Borrowed some display code from Daniel M's excellent CTU app
   
----------------------------------------------------------------------------

   Released under MIT-license

   Copyright (c) 2019 DFM

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:
   
   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.
   
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.

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
local MAXSPEEDMPH = 200
local MAXSPEEDKPH = 320
local MAXSPEEDKT  = 180 
local gaugeMaxSpeed
local shortAnn, shortAnnIndex

local speedUnitsIdx
local speedUnits = {"mph", "kmh", "knots"}
local gaugeMaxSpeedArr = {MAXSPEEDMPH, MAXSPEEDKPH, MAXSPEEDKT}

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
local sensorIdlist = {0}
local sensorPalist = {0}

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
local locale

local function setLanguage()

   local obj
   local fp
   local langFile

   locale = system.getLocale()
   fp = io.readall(transFile)
   if not fp then -- translation does not exist yet .. literal string
      error(appShort..": Missing "..transFile)
   else
      obj = json.decode(fp)
   end
   if obj then
      langFile = obj[locale] or obj.en
   end
   fp = io.readall(appDir..langFile)
   if not fp then
      error(appShort..": Missing "..appDir..langFile)      
   else
      lang = json.decode(fp)
   end
end

--------------------------------------------------------------------------------

local function playFile(filename, parm)
   local slash
   if DEBUG then slash="" else slash="/" end
   if locale == 'en' then prefix = slash..appDir else
      prefix = slash..appDir..locale.."-"
   end
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

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

local function speedUnitsIdxChanged(value)
   speedUnitsIdx = value
   system.pSave("speedUnitsIdx", value)
   gaugeMaxSpeed = gaugeMaxSpeedArr[value]
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
   form.addLabel({label=lang.menuSpeedUnits, width=220})
   form.addSelectbox(speedUnits, speedUnitsIdx, false, speedUnitsIdxChanged)
   
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
    local txt
    local textSpeed

    textSpeed = string.format("%d", math.floor(speed + 0.5))

    if speedUnitsIdx == 1 then
       txt = lang.labelMPH
    elseif speedUnitsIdx == 2 then
       txt = lang.labelKPH
    else
       txt = lang.labelKT
    end
    
    lcd.drawText(ox + 66 - lcd.getTextWidth(FONT_NORMAL, txt)/2,
		    oy + 100, txt, FONT_NORMAL)
    
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textSpeed) / 2, oy + 40,
		 textSpeed, FONT_MAXI)

    local thetaThr = math.pi - math.rad(135 - 2 * 135 * speed / gaugeMaxSpeed)
    local thetaSet = math.pi - math.rad(135 - 2 * 135 * set_speed * (airspeedCal / 100) / gaugeMaxSpeed)

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
    
    text = string.format("%d", math.floor((set_speed+0.5) * airspeedCal / 100))
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
   if speedUnitsIdx == 1 then
      return s * 2.23694 -- m/s to mph
   elseif speedUnitsIdx == 2 then
      return s * 3.6 -- m/s to km/hr
   else
      return s * 1.94384 -- m/s to kt
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
	 offThrottle = thrRingBuf[(thrSeq + 1) % MAXRING + 1] or 0 -- oldest val or 0 if ~full
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
      
   -- read pitot airspeed from CTU
   
   if ATAirspeedSeId and ATAirspeedSeId ~= 0 then
      sensor = system.getSensorByID(ATAirspeedSeId, ATAirspeedSePa)
   end
   if (sensor and sensor.valid) then
      speed = convertSpeed(sensor.value) * airspeedCal / 100.0
   else
      if DEBUG then
	 speed = gaugeMaxSpeed/2 * (1 + system.getInputs("P6"))
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
	 if DEBUG then print("Set speed stable at", set_speed) end
	 playFile('ATSetPointStable.wav', AUDIO_QUEUE)
	 if speedUnitsIdx == 1 then
	    uuu = "mph"
	 elseif speedUnitsIdx == 2 then
	    uuu = "km/h"
	 else
	    uuu = "kt."
	 end
	 system.playNumber(math.floor( (set_speed+0.5) * airspeedCal / 100), 0, uuu)
	 system.messageBox(lang.labelSetPtSpd..math.floor((set_speed+0.5) * airspeedCal / 100)) -- goes in log 
      end
   end

   last_set = set_speed

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

   -- Puzzle: would be good to make sure turbine is on (that is, not in "user off" state with
   -- the trim low) and flag an error if the AT is turned on and the engine is not enabled
   -- but we don't know what switch the CTU uses to turn AT on an off...
   -- should we be checking RPM perhaps?
   
   if sensor and sensor.valid and ATState and ATState > 1 then
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

      if (speed <= VrefSpd) or (swc and swc == 1) then -- override if < Vref or cont ann is on
	 nextAnnTC = lastAnnTC + VrefCall * 1000 -- at and < Vref .. ann every VrefCall secs
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
	 if speedUnitsIdx == 1 then
	    uuu = "mph"
	 elseif speedUnitsIdx == 2 then
	    uuu = "km/h"
	 else
	    uuu = "kt."
	 end

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
      end
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
   if speedUnitsIdx == 1 then
      u = lang.labelMPH
   elseif speedUnitsIdx == 2 then
      u = lang.labelKPH
   else
      u = lang.labelKT
   end
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
   speedUnitsIdx = system.pLoad("speedUnitsIdx", 1)
   shortAnn = system.pLoad("shortAnn", "false")

   gaugeMaxSpeed = gaugeMaxSpeedArr[speedUnitsIdx]
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
 
