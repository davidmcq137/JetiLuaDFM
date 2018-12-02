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
local round_spd = 0
local SpdAnnCCVersion

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local gauge_c={}
local gauge_s={}
local throttle=0
local tgt_speed = 0
local set_speed = 0
local round_spd = 0
local iTerm = 0
local pTerm = 0
local dTerm = 0
local spdTable={}
local timTable={}
local MAXTABLE=100
local errsig = 0
local autoOn = false
local lastAuto = false
local autoForceOff = false
local throttleDownTime = 0
local lastValid = 0
local throttlePosAtOn

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
    
    if gauge_c ~= nil then
       lcd.setColor(255, 0, 0)
       lcd.drawImage(ox-gauge_s.width//2, oy-gauge_s.width//2, gauge_s)
       drawShape(ox, oy, needle_poly_small_small, theta)
       lcd.drawFilledRectangle(ox, oy-24, 2, 20) -- should be ox-1 but roundoff problem?
       lcd.setColor(0,0,0)
    end
    
end

--------------------------------------------------------

local function DrawThrottle()

    local ox, oy = 1, 8
    
    local textThrottle = string.format("%d", math.floor(throttle + 0.5))

    lcd.drawText(ox + 33, oy + 100, "%Throttle", FONT_NORMAL)
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textThrottle) // 2,
		 oy + 40, textThrottle, FONT_MAXI)

    local thetaThr = math.pi - math.rad(135 - 2 * 135 * throttle // 100)
    
    if gauge_c ~= nil then

       lcd.setColor(255, 0, 0)
       lcd.drawImage(ox, oy, gauge_c)    
       drawShape(ox+65, oy+60, needle_poly_large, thetaThr)
       lcd.setColor(0,0,0)
    end
    
end

--------------------------------------------------------

local function DrawSpeed()

    local ox, oy = 186, 8

    local textSpeed = string.format("%d", math.floor(round_spd + 0.5))

    lcd.drawText(ox + 50, oy + 100, "MPH", FONT_NORMAL)
    if autoOn then lcd.setColor(255,0,0) end
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textSpeed) / 2, oy + 40,
		 textSpeed, FONT_MAXI)

    local thetaThr = math.pi - math.rad(135 - 2 * 135 * round_spd / 200)
    local thetaSet = math.pi - math.rad(135 - 2 * 135 * set_speed / 200)

    if gauge_c ~= nil then
       lcd.drawImage(ox, oy, gauge_c)
       lcd.setColor(0,255,0)
       drawShape(ox+65, oy+60, needle_poly_xlarge, thetaSet)       
       lcd.setColor(255,0,0)
       drawShape(ox+65, oy+60, needle_poly_large, thetaThr)
       lcd.setColor(0, 0, 0)
    end
    
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
    
    text = string.format("%d", set_speed)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 7, text, FONT_BOLD)

    text = string.format("%d", iTerm)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, text)) / 2, oy + 30, text, FONT_BOLD)

    if math.abs(errsig) < .01 then ierr = 0.0 else ierr = errsig end
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

   local sensor, slope, spd

   if (spdSeId ~= 0) then
      sensor = system.getSensorByID(spdSeId, spdSePa)
   else
      if not DEBUG then return end
   end

   if (sensor and sensor.valid) then
      speed = sensor.value * airspeedCal/100.0
      lastValid = system.getTimeCounter()
   else
      if DEBUG then
	 spd = round_spd
	 lastValid = system.getTimeCounter()
	 --spd = (system.getInputs("P8")+1) * 160.0 * airspeedCal / 100. -- make P8 go from 0 to 320
      else
	 return 
      end
   end

   if not DEBUG then
      if selFt then
	 if sensor.unit == "m/s" then
	    spd = speed * 2.23694 -- m/s to mph
	 end
	 if sensor.unit == "kmh" or sensor.unit == "km/h" then
	    spd = speed * 0.621371 -- km/hr to mph
	 end
      else
	 if sensor.unit == "m/s" then
	    spd = speed * 3.6 -- km/hr
	 end
      end
   end

   if maxSpd and (spd <= maxSpd) then ovrSpd = false end
   
   if #spdTable+1 > MAXTABLE then
      table.remove(spdTable, 1)
      table.remove(timTable, 1)
   end
   table.insert(spdTable, spd - set_speed)
   table.insert(timTable, system.getTimeCounter()/1000.)

   slope, _ = fslope(timTable, spdTable)

   if (spd > VrefSpd) then
      aboveVref = true
      aboveVref_ever = true
   end

   if (spd > VrefSpd/1.3) then -- re-arm it
      stall_warn = false
   end

   return spd, slope

end

--------------------------------------------------------

local function loop()

   local spd
   local deltaSA
   local sss, uuu
   local slope

   local pGain = 0.8
   local iGain = 0.006
   local dGain = 0.05
   local lowDelay = 6000

   local swi = system.getInputsVal(spdSwitch)
   local swc = system.getInputsVal(contSwitch)
   local swa = system.getInputsVal(autoSwitch)
   
   -----------------------------------------------------------------------------------
   -- this first section is the autothrottle
   -----------------------------------------------------------------------------------

   if lastValid == 0 and swa and swa == 1 then
      autoOn = false
      autoForceOff = true
      print("Cannot startup with AutoThrottle enabled .. turn off and back on")
   end

   if swa and swa == -1 then
      autoForceOff = false
   end
   
   spd, slope = get_speed_from_sensor()

   if autoOn and not DEBUG and (system.getTimeCounter() > lastValid + 10000.) then 
      print("AutoThrottle off because of invalid speed data > 10 s")
      autoOn = false
      autoForceOff = true -- force user to turn switch off then on again
   end
   
   round_spd = spd

   if swa and swa == 1 and not autoForceOff then   
      if autoOn == false then print("AutoThrottle on by switch SWA") end
      autoOn = true
   else
      if autoOn == true then print("AutoThrottle off by switch SWA") end
      autoOn = false
   end


   throttle_stick = 50 * (system.getInputs("P4") + 1)

   if not lastAuto and autoOn then -- auto throttle just turned on
      --print("AutoThrottle turned on: throttle, throttle_stick", throttle, throttle_stick)
      throttle = throttle_stick
      throttlePosAtOn = throttle_stick
      iTerm = throttle_stick -- precharge integrator to this thr setting
      throttleDownTime = system.getTimeCounter() + lowDelay -- # seconds to reduce thr to 0
   end

   if autoOn and math.abs(system.getTimeCounter() - throttleDownTime) < lowDelay then
      if throttle_stick > throttlePosAtOn then -- moved the stick up during the # secs...
	 print("AutoThrottle off .. moved stick up in the arming interval")
	 autoOn = false
	 autoForceOff = true
      end
   end
   
   if autoOn and system.getTimeCounter() > throttleDownTime and throttle_stick > 0 then
      print("AutoThrottle off by low stick timeout -- throttle not taken to idle in required time")
      autoOn = false
      autoForceOff = true -- can't re-enable till turn switch swa off then on again
   end

   lastAuto = autoOn
   
   --------- next two lines simulate airplane response to throttle ------------
   
   tgt_speed = throttle * 2 -- simulate plane's response. 50% thr -> 100 mph, 100% thr -> 200 mph

   round_spd = round_spd + 0.008 * (tgt_speed - round_spd) -- give it a time lag

   if setPtControl then
      set_speed =  100 * (1 + system.getInputsVal(setPtControl))
   elseif autoOn then
      autoOn = false
      autoForceOff = true
      print("Attempt to arm AutoThrottle with no setpoint speed")
   end
   
   
   if autoOn then
      errsig = set_speed - round_spd

      pTerm = errsig * pGain
      dTerm = slope * dGain
      iTerm = math.max(0, math.min(iTerm + errsig * iGain, 100))
      
      throttle = pTerm + iTerm + dTerm
      throttle = math.max(0, math.min(throttle, 100))
   else
      throttle = throttle_stick
   end
      
   system.setControl(autoIdx, (throttle-50)/50, 0)
   
   ----------------------------------------------------------------------------------
   -- this is the speed announcer section, return if announce not on or on continuous
   ----------------------------------------------------------------------------------

   if (swi and swi == 1) or (swc and swc == 1) then
      
      if (spd > maxSpd and not ovrSpd) then
	 ovrSpd = true
	 system.playFile('/Apps/DFM-SpdA/overspeed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("Overspeed!") end
	 system.vibration(true, 3) -- 2x vibrations on right stick
      end

      if (spd <= VrefSpd and aboveVref) then
	 aboveVref = false
	 system.playFile('/Apps/DFM-SpdA/V_ref_speed.wav', AUDIO_IMMEDIATE)
	 if DEBUG then print("At Vref") end
      end

      if ((spd <= VrefSpd/1.3) and (not stall_warn) and aboveVref_ever) then
	 stall_warn = true
	 system.playFile('/Apps/DFM-SpdA/stall_warning.wav', AUDIO_IMMEDIATE)
	 system.vibration(true, 4) -- 4 short pulses on right stick
	 if DEBUG then print("Stall warning!") end
      end

      -- multiplier is scaled by spdInter, over range of 0.5 to 10 (20:1)
      deltaSA = math.min(math.max(math.abs((spd-lastAnnSpd) / spdInter), 0.5), 10)
      
      nextAnnTC = lastAnnTC + (VrefCall * 1000 * 10 / deltaSA) 

      if (spd <= VrefSpd) or (swc and swc == 1) then -- override if below Vref or cont ann is on
	 nextAnnTC = lastAnnTC + VrefCall * 1000 -- at and below Vref .. ann every VrefCall secs
      end

      sgTC = system.getTimeCounter()
      if not sgTC0 then sgTC0 = sgTC end
      
      
      -- added isPlayback() so that we don't create a backlog of messages if it takes
      -- longer than VrefCall time
      -- to speak the speed .. was creating a "bow wave" of pending announcements.
      -- Wait till speaking is done, catch
      -- it at the next call to loop()

      if (not system.isPlayback()) and
      ( (sgTC > nextAnnTC) and ( (spd > VrefSpd / 4) or (swc and swc == 1) ) ) then

	 --round_spd = math.floor(spd + 0.5) -- already set above
	 lastAnnSpd = round_spd

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

   --system.playFile('/Apps/DFM-SpdA/Spd_ann_act.wav', AUDIO_QUEUE)

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
