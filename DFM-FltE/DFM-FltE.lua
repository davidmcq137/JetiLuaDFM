--[[

----------------------------------------------------------------------------
   DFM-FltE.lua

   Flight Engineer to assist with twin-engine aircraft
    
    Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------
	Released under MIT-license by DFM 2021
----------------------------------------------------------------------------

--]]

local FltEVersion = "0.0"

--local trans11
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

local engT = {
   {Name="Left",  RPM={"Se", "SeId", "SePa"}, Temp={"Se", "SeId", "SePa"}},
   {Name="Right", RPM={"Se", "SeId", "SePa"}, Temp={"Se", "SeId", "SePa"}}
}

local eng = {}
local engineParams={}
local syncDelta = 0
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
local modelProps = {}
local gauge_c={}
local gauge_s={}
local blackCircle={}
local throttle=0
local speed = 0
local slope = 0
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
local pGainInput
local iGainInput
local dGainInput
local autoOffTime = 0
local offThrottle
local lastSetThr
local playedBeep = true
local slAvg
local set_stable = 0
local last_set = 0
local nLoop = 0
local appStartTime
local baseLineLPS, loopsPerSecond = 47, 47
local autoWarn = false
local autoIdx
local thrLogIdx, setLogIdx, errLogIdx

--CARSTEN .. "global" variables inside this prog..
local wt={}
local jTerm = 0
local kTerm = 0
local yrun = 0
local linfitden
--CARSTEN


local DEBUG = false
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
      spdSe = 0
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

local function engSensorChanged(value, num, name)
   eng[num][name].Se = value
   eng[num][name].SeId = sensorIdlist[value]
   eng[num][name].SePa = sensorPalist[value]
   if eng[num][name].SeId == "..." then
      eng[num][name].Se = 0
      eng[num][name].SeId = 0
      eng[num][name].SePa = 0
   end
   system.pSave("eng"..num..name.."Se", eng[num][name].Se)
   system.pSave("eng"..num..name.."SeId", eng[num][name].SeId)
   system.pSave("eng"..num..name.."SePa", eng[num][name].SePa)   
end

local function engControlChanged(value, num)
   if value == "..." then
      eng[num].Control = nil
   else
      eng[num].Control = value
   end
   system.pSave("eng"..num.."Control", eng[num].Control)
end

--------------------------------------------------------------------------------

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())

   if (fw >= 4.22) then
      
      form.addRow(2)
      form.addLabel({label="Left Engine Throttle Control", width=220})
      form.addInputbox(eng[1].Control, false, (function(x) return engControlChanged(x, 1) end) )

      form.addRow(2)
      form.addLabel({label="Right Engine Throttle Control", width=220})
      form.addInputbox(eng[2].Control, false, (function(x) return engControlChanged(x, 2) end) )      

      form.addRow(2)
      form.addLabel({label="Left Engine RPM Sensor", width=220})
      form.addSelectbox(sensorLalist, eng[1].RPM.Se, true,
			(function(x) return engSensorChanged(x,1,"RPM") end))

      form.addRow(2)
      form.addLabel({label="Right Engine RPM Sensor", width=220})
      form.addSelectbox(sensorLalist, eng[2].RPM.Se, true,
			(function(x) return engSensorChanged(x,2,"RPM") end))			
      
      form.addRow(2)
      form.addLabel({label="Left Engine Temp Sensor", width=220})
      form.addSelectbox(sensorLalist, eng[1].Temp.Se, true,
			(function(x) return engSensorChanged(x,1,"Temp") end))			

      form.addRow(2)
      form.addLabel({label="Right Engine Temp Sensor", width=220})
      form.addSelectbox(sensorLalist, eng[2].Temp.Se, true,
			(function(x) return engSensorChanged(x,2,"Temp") end))
      
      form.addRow(2)
      form.addLabel({label="Select Speed Sensor", width=220})
      form.addSelectbox(sensorLalist, spdSe, true, sensorChanged)
      
      --[[
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

      --]]
      form.addRow(2)
      form.addLabel({label="PID Proportional gain", width=220})
      form.addIntbox(pGainInput, 0, 100, 1, 0, 1, pGainChanged)

      form.addRow(2)
      form.addLabel({label="PID Integral gain", width=220})
      form.addIntbox(iGainInput, 0, 100, 1, 0, 1, iGainChanged)

      form.addRow(2)
      form.addLabel({label="PID Derivative gain", width=220})
      form.addIntbox(dGainInput, 0, 100, 1, 0, 1, dGainChanged)
      
      --[[
      form.addRow(2)
      form.addLabel({label="Use mph or km/hr (x)", width=270})
      selFtIndex = form.addCheckbox(selFt, selFtClicked)
      
      form.addRow(2)
      form.addLabel({label="Short Announcement", width=270})
      shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
      --]]
      form.addRow(1)
      form.addLabel({label="DFM-FltE.lua Version "..FltEVersion.." ", font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end
end

--------------------------------------------------------------------------------

local needle_poly_large = {
   {-4,28},
   {-2,64},
   {2,64},
   {4,28}
}

local needle_poly_xlarge = {
   {-4,28},
   {-2,70},
   {2,70},
   {4,28}
}

local tick_mark = {
   {-2,56},
   {-2,65},
   { 2,65},
   { 2,56}
}
--[[
local needle_poly_small = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}
--]]

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
    local ierr = math.min(math.max(syncDelta, -100), 100)
    local theta = math.rad(135 * ierr / 100) - math.pi

    --if not autoOn then return end
       
    lcd.setColor(255, 0, 0)
    if gauge_s then lcd.drawImage(ox-gauge_s.width//2, oy-gauge_s.width//2, gauge_s) end
    drawShape(ox, oy, needle_poly_small_small, theta)
    lcd.drawFilledRectangle(ox-1, oy-32, 2, 8)
    lcd.setColor(0,0,0)
    lcd.drawText(ox - lcd.getTextWidth(FONT_MINI, "Sync") // 2, oy + 13, "Sync", FONT_MINI)

end

--------------------------------------------------------
local function angle1(t, min, max)
   local tt
   if t < min then tt = min else tt=t end
   return math.pi - math.rad(135 - 128 * (tt-min) / (max-min))
end

local function angle2(t, min, max)
   if t < min then tt = min else tt=t end
   return math.pi - math.rad(128 * (tt-min) / (max-min) - 135)
end

local function DrawRPM()

    local ox, oy = 1, 8

    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_BIG,"RPM") / 2 , oy + 54,
		 "RPM", FONT_BIG)

    local minRPM = engineParams.RPMs[1]
    local maxRPM = engineParams.RPMs[#engineParams.RPMs]
    
    local rt = string.format("%d-%d/min", minRPM, maxRPM)
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MINI,rt) / 2 , oy + 105,
		 rt, FONT_MINI)

    local rpm1 = 6000 * (1 + system.getInputs("P7"))/2
    local rpm2 = 6000 * (1 + system.getInputs("P8"))/2

    syncDelta = rpm1 - rpm2
    
    local text1 = string.format("%.1f", 0.1*math.floor(rpm1/100 + 0.5))
    local text2 = string.format("%.1f", 0.1*math.floor(rpm2/100 + 0.5))

    
    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    lcd.setColor(255,255,255)
    lcd.drawFilledRectangle(ox+65-5, oy, 10, 20)

    lcd.setColor(160,160,160)
    for k,v in ipairs(engineParams.RPMs) do
       drawShape(ox+65, oy+65, tick_mark, angle1(v, minRPM, maxRPM))
       drawShape(ox+65, oy+65, tick_mark, angle2(v, minRPM, maxRPM))       
    end
    
    local theta1 = angle1(rpm1, minRPM, maxRPM) 
    local theta2 = angle2(rpm2, minRPM, maxRPM) 

    lcd.setColor(255,0,0)
    drawShape(ox+65, oy+65, needle_poly_large, theta1)       

    lcd.setColor(255,0,0)
    drawShape(ox+65, oy+65, needle_poly_large, theta2)

    lcd.setColor(0,0,0)

    text1 = string.format("%d", math.floor(rpm1 + 0.5))
    text2 = string.format("%d", math.floor(rpm2 + 0.5))

    lcd.drawText(ox + 30 - lcd.getTextWidth(FONT_BIG, text1) / 2, oy + 120,
		 text1, FONT_BIG)

    lcd.drawText(ox + 100 - lcd.getTextWidth(FONT_BIG, text2) / 2, oy + 120,
		 text2, FONT_BIG)    

end

--------------------------------------------------------


local function DrawTemp()

    local ox, oy = 186, 8

    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_BIG,"CHT") / 2 , oy + 54,
		 "CHT", FONT_BIG)

    local minTemp = engineParams.Temps[1]
    local maxTemp = engineParams.Temps[#engineParams.Temps]

    local rt = string.format("%d-%d°C", minTemp, maxTemp)
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MINI,rt) / 2 , oy + 105,
		 rt, FONT_MINI)

    local temp1 = 300 * (1 + system.getInputs("P5"))/2
    local temp2 = 300 * (1 + system.getInputs("P6"))/2
    local text1 = string.format("%d", math.floor(temp1 + 0.5))
    local text2 = string.format("%d", math.floor(temp2 + 0.5))

    
    local theta1 = angle1(temp1, minTemp, maxTemp) --math.pi - math.rad(135 - 130 * temp1 / 300)
    local theta2 = angle2(temp2, minTemp, maxTemp) --math.pi - math.rad(130 * temp2 / 300 - 135)

    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    lcd.setColor(255,255,255)
    lcd.drawFilledRectangle(ox+65-5, oy, 10, 20)

    lcd.setColor(160,160,160)
    for k,v in ipairs(engineParams.Temps) do
       drawShape(ox+65, oy+65, tick_mark, angle1(v, minTemp, maxTemp))
       drawShape(ox+65, oy+65, tick_mark, angle2(v, minTemp, maxTemp))       
    end

    if temp1 < 150 then
       lcd.setColor(0,0,255)
    elseif temp1 < 250 then
       lcd.setColor(0,255,0)
    else
       lcd.setColor(255,0,0)
    end
    
    drawShape(ox+65, oy+65, needle_poly_large, theta1)       

    if temp2 < 150 then
       lcd.setColor(0,0,255)
    elseif temp2 < 250 then
       lcd.setColor(0,255,0)
    else
       lcd.setColor(255,0,0)
    end
    
    drawShape(ox+65, oy+65, needle_poly_large, theta2)

    --if blackCircle then lcd.drawImage(ox+58,oy+53,blackCircle) end

    --lcd.setColor(255,255,255)
    --lcd.drawFilledRectangle(ox+65-35, oy+62-8, 70, 16)

    lcd.setColor(0,0,0)
    
    lcd.drawText(ox + 30 - lcd.getTextWidth(FONT_BIG, text1) / 2, oy + 120,
		 text1, FONT_BIG)

    lcd.drawText(ox + 100 - lcd.getTextWidth(FONT_BIG, text2) / 2, oy + 120,
		 text2, FONT_BIG)    

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

local function wbTele()
    DrawRPM(0,0)
    DrawTemp(0,0)
    --DrawCenterBox(0,0,0,0)
    --DrawRectGaugeCenter( 66, 140, 70, 16, -100, 100, 5*pTerm, "Proportional")
    --DrawRectGaugeAbs(158, 140, 70, 16, 0, 100, iTerm, "Integral")
    --DrawRectGaugeCenter(252, 140, 70, 16, -100, 100, 5*dTerm, "Derivative")
    DrawErrsig(0,0)
end

--------------------------------------------------------------------------------

-- CARSTEN
-- this is the simplified slope calculator .. called once per inner loop

local function jslope(y)
   local sxy, jterm

   sxy=0
   for i=1,#y,1 do -- #y is always going to be MAXTABLE
      sxy = sxy + wt[i]*(y[i] - yrun)
   end

   jTerm = sxy/linfitden

   return jTerm
   
end
-- CARSTEN
-- what follows is the brute force computation

local function fslope(x, y)

    local xbar, ybar, sxy, sx2 = 0,0,0,0
    local theta, tt, slp
    
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
    
    slp = sxy/sx2
    
    theta = math.atan(slp)

    if x[1] < x[#x] then
       tt = math.pi/2 - theta
    else
       tt = math.pi*3/2 - theta
    end
    kTerm = slp
    return slp, tt
end

--------------------------------------------------------

local function get_speed_from_sensor()

   local sensor, slp, sensorSpeed, spd, _

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
	 -- give the plane and engine response a time lag
	 speed = speed + (baseLineLPS / loopsPerSecond) * (tgt_speed - speed) / 125  
	 lastValid = system.getTimeCounter() -- pretend we read a sensor and it was valid
	 autoWarn = false -- reset warning for no data
	 spd = speed -- return the correct variable
      else
	 return  nil, nil
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

   calSpd = spd

   -- CARSTEN
   -- computes the running  average, with avg window matching stored value array
   yrun = yrun + (spd - yrun)/MAXTABLE

   if #spdTable+1 > MAXTABLE then
      table.remove(spdTable, 1)
      table.remove(timTable, 1)
   end
   table.insert(spdTable, speed - set_speed)
   table.insert(timTable, system.getTimeCounter()/1000.)

   --slp, _ = fslope(timTable, spdTable)

   -- now overwrite slp with the new calc
   
   if #spdTable ~= MAXTABLE then
      slp = 0
   else
      slp = jslope(spdTable)
   end
   -- CARSTEN
   
   return spd, slp

end

local function logCB(idx)

   --print("logCB", idx)

   --print(throttle, set_speed, errLogIdx)
	 
   if idx == thrLogIdx then
      return 100 * math.floor(throttle), 2
   elseif idx == setLogIdx then
      return 100 * math.floor(set_speed), 2
   elseif idx == errLogIdx then
      return 100 * math.floor(errsig), 2
   else
      print("bad idx in logCB",  idx)
      return 0, 0
   end

end

--------------------------------------------------------


local function loop()

   local deltaSA
   local sss, uuu
   local lowDelay = 6000
   local noDataWarn = 2000
   local noDataOff = 5000
   local retSpd, retSlp
   local round_spd
   local swi, swc, swa
   local throttle_stick
   
   -- gather some stats on loop times so we can normalize integrator performance
   
   if not appStartTime then appStartTime = system.getTimeCounter() end
      
   nLoop = nLoop + 1
   if nLoop >= 100 then
      loopsPerSecond = 1000 * nLoop / (system.getTimeCounter() - appStartTime)
      appStartTime = system.getTimeCounter()
      nLoop = 0
      --print("Loops per second:", loopsPerSecond)
   end
   
   -- first read the configuration from the switches that have been assigned

   swi = system.getInputsVal(spdSwitch)  -- enable normal speed announce vary by delta speed
   swc = system.getInputsVal(contSwitch) -- enable continuous annonucements
   swa = system.getInputsVal(autoSwitch) -- enable/arm autothrottle
   
   -----------------------------------------------------------------------------------
   -- this first section is the PID AutoThrottle
   -----------------------------------------------------------------------------------

   if swa and swa == -1 then -- if turned off, ok to re-enable if it was prohibited prev.
      autoForceOff = false
   end
   
   if lastValid == 0 and swa and swa == 1 then -- has to be called before get_speed_from_sensor()
      autoOn = false
      autoForceOff = true
      print("Cannot startup with AutoThrottle enabled .. turn off and back on")
      system.playFile('/Apps/DFM-Auto/ATCannotStartEnabled.wav', AUDIO_QUEUE)
      lastValid = -1 -- so it won't give this message again
   end

   retSpd, retSlp = get_speed_from_sensor()

   if retSpd then speed = retSpd end -- if no new data, nil is returned
   if retSlp then slope = retSlp end -- in this case hold last data in speed and slope

   -- warn if no valid data for noDataWarn/1000 seconds .. leave Autothrottle on .. hold values (below)
   
   if autoOn and (system.getTimeCounter() > lastValid + noDataWarn) and not autoWarn then 
      print("AutoThrottle warning: invalid speed data exceeds warning period")
      system.playFile('/Apps/DFM-Auto/ATNoDataWarning.wav', AUDIO_QUEUE)
      autoWarn = true -- remember we did the warning -- don't do again in this data gap
   end
   
   -- cancel if no valid data for noDataOff/1000 seconds
   
   if autoOn and (system.getTimeCounter() > lastValid + noDataOff) then 
      print("AutoThrottle off because of invalid speed data")
      system.playFile('/Apps/DFM-Auto/ATNoValidData.wav', AUDIO_QUEUE)
      autoOn = false
      autoForceOff = true -- force user to turn switch off then on again
   end
   
   if swa and swa == 1 and not autoForceOff then   
      if autoOn == false then
	 print("AutoThrottle turned on by switch SWA")
	 system.playFile('/Apps/DFM-Auto/ATEnabled.wav', AUDIO_QUEUE)
      end
      autoOn = true
   else
      if autoOn == true then
	 print("AutoThrottle turned off by switch SWA")
	 system.playFile('/Apps/DFM-Auto/ATCancelled.wav', AUDIO_QUEUE)
      end
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

   -- during the "put throttle stick low" interval after arming, can cancel by moving stick up
   -- from position at time of arming. not sure there is a better way to do this...
   
   if autoOn and system.getTimeCounter() - throttleDownTime < lowDelay then
      if throttle_stick > throttlePosAtOn + 4 then -- moved the stick up during the # secs...
	 print("AutoThrottle off .. moved stick up in the arming interval")
	 system.playFile('/Apps/DFM-Auto/ATCancelledThrUp.wav', AUDIO_QUEUE)
	 autoOn = false
	 autoForceOff = true
      end
   end

   -- cancel Autothrottle if stick moved off idle. use 4% as resolution level
   
   if autoOn and system.getTimeCounter() > throttleDownTime and throttle_stick > 4 then
      print("AutoThrottle off -- throttle not at idle")
      system.playFile('/Apps/DFM-Auto/ATCancelledThrNotIdle.wav', AUDIO_QUEUE)
      autoOn = false
      autoForceOff = true -- can't re-enable till turn switch swa off then on again
   end

   -- check if a speed setpoint is set
   
   if setPtControl then
      set_speed =  100 * (1 + system.getInputsVal(setPtControl)) -- this is 0-200
      if math.abs(set_speed - last_set) < 4 then
	 if set_stable < 50 then set_stable = set_stable + 1 end
      else
	 set_stable = 1
      end
      if set_stable == 50 then
	 set_stable = 51 -- only play the number once when stabilized
	 --if set_speed > VrefSpd / 1.3 then -- don't announce if setpoint below stall
	 --print("Set speed stable at", set_speed)
	 system.playFile('/Apps/DFM-Auto/ATSetPointStable.wav', AUDIO_QUEUE)      	    
	 system.playNumber(math.floor(set_speed+0.5), 0, "mph")
	 --end
      end
      last_set = set_speed
   elseif autoOn then -- no setpoint but trying to arm
      autoOn = false
      autoForceOff = true
      print("Attempt to arm AutoThrottle with no setpoint speed")
      system.playFile('/Apps/DFM-Auto/ATCannotArmNoSet.wav', AUDIO_QUEUE)      
   end

   --if setPtControl and set_speed < VrefSpd / 1.3 and autoOn then
      --autoOn = false
      --autoForceOff = true
      --print("Attempt to arm AutoThrottle with speed below stall: ", VrefSpd/1.3)
      --system.playFile('/Apps/DFM-Auto/ATSetBelowStall.wav', AUDIO_QUEUE)      
   --end
   
   -- interesting to consider: loop time on the emulator is about 47 loops per second
   -- if this app runs by itself, it's about 41 lps on the TX. With the LSO program also
   -- running, the emulator drops to 42 and the TX drops to 28. Derivatve is calculated as
   -- slope vs timestamps, so it won't change, propo not time dependent .. but integrator
   -- effective gain will decrease as loop time decreases ..
   -- scale iGain with lps to keep integrator response flat with sys load

   -- if all good, then apply PID algorithm

   errsig = set_speed - speed
   
   if autoOn then
      pGain = pGainInput / 50.0
      dGain = dGainInput / 20.0
      iGain = iGainInput / 5000.0 * baseLineLPS / loopsPerSecond

      --errsig = set_speed - speed

      -- average the derivate .. slopes are noisy probably due to time jitter
      
      if not slAvg then
	 slAvg = slope
      end

      slAvg = slAvg + (baseLineLPS / loopsPerSecond) * (slope - slAvg) / 200

	 
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
      if not autoForceOff then
	 system.setControl(autoIdx, -1, 0) -- when off mix to 0% throttle (-1 on -1,1 scale)
      else -- if we forced it off (e.g. throttle stick not taken to zero) then return control to stick
	 system.setControl(autoIdx, (throttle-50)/50, 0)
      end
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
         ((sgTC > nextAnnTC) and ( (speed > VrefSpd / 2) or (swc and swc == 1))) then

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
    blackCircle = lcd.loadImage("Apps/DFM-FltE/small_black_circle.png")
    if not gauge_c or not gauge_s or not blackCircle then print("Gauge png images(s) not loaded") end
end
--------------------------------------------------------------------------------

local function calAirspeed(w,h)
   local u
   if (selFt) then u = "mph" else u = "km/hr" end
   lcd.drawText(5, 5, math.floor(calSpd+0.5) .. " " .. u)
end

local function init()

   local dev, em, fg
   
   spdSwitch = system.pLoad("spdSwitch")
   contSwitch = system.pLoad("contSwitch")
   autoSwitch = system.pLoad("autoSwitch")
   setPtControl = system.pLoad("setPtControl")
   spdInter = system.pLoad("spdInter", 10)
   VrefSpd = system.pLoad("VrefSpd", 60)
   VrefCall = system.pLoad("VrefCall", 2)
   maxSpd = system.pLoad("maxSpd", 200)
   pGainInput = system.pLoad("pGainInput", 40)
   iGainInput = system.pLoad("iGainInput", 40)
   dGainInput = system.pLoad("dGainInput", 40)   
   airspeedCal = system.pLoad("airspeedCal", 100)
   spdSe = system.pLoad("spdSe", 0)
   spdSeId = system.pLoad("spdSeId", 0)
   spdSePa = system.pLoad("spdSePa", 0)
   selFt = system.pLoad("selFt", "true")
   shortAnn = system.pLoad("shortAnn", "false")

--local eng = {
--   {Name="Left",  RPM={"Se", "SeId", "SePa"}, Temp={"Se", "SeId", "SePa"}},
--   {Name="Right", RPM={"Se", "SeId", "SePa"}, Temp={"Se", "SeId", "SePa"}}
--}

   for ek,ev in ipairs(engT) do
      eng[ek] = {}
      for nk,nv in pairs(ev) do
	 if type(nv) == "table" then
	    eng[ek][nk] = {}
	    for sk,sv in pairs(nv) do
	       eng[ek][nk][sv] = system.pLoad("eng"..ek..nk..sv, 0)
	       print("eng"..ek..nk..sv ..": " .. eng[ek][nk][sv])
	    end
	 end
      end
   end

   engT = nil
   
   selFt = (selFt == "true") -- can't pSave and pLoad booleans...store as text 
   shortAnn = (shortAnn == "true") -- convert back to boolean here
 
   fg = io.readall("Apps/DFM-FltE/FE-Model.jsn")
   if fg then
      engineParams = json.decode(fg)
   end

   local eName = (": " .. engineParams.Engine) or ""
   
   system.registerForm(1, MENU_APPS, "Flight Engineer", initForm)

   system.registerTelemetry(1, "Flight Engineer"..eName, 4, wbTele)
   system.registerTelemetry(2, "Calibrated Airspeed", 1, calAirspeed)

   thrLogIdx = system.registerLogVariable("Throttle",  "%", logCB)
   setLogIdx = system.registerLogVariable("Set Speed", "%", logCB)
   errLogIdx = system.registerLogVariable("Error Sig", "%", logCB)   

   --print("thr,set,err LogIdx:", thrLogIdx, setLogIdx, errLogIdx)
   
   -- set default for pitotCal in case no "DFM-model.jsn" file

   modelProps.pitotCal = airspeedCal -- start with the pLoad default
   
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   if fg then
      modelProps=json.decode(fg)
      airspeedCal = modelProps.pitotCal
   end


   for k,v in pairs(engineParams.Temps) do
      print(k,v)
   end

   for k,v in pairs(engineParams.RPMs) do
      print(k,v)
   end   
   

   dev, em = system.getDeviceType()

   print("Device: ", dev)
   if em == 1 then
      print("DEBUG ON")
      DEBUG = true
   else
      print("DEBUG OFF")
   end
   
   readSensors()
   loadImages()


   -- CARSTEN

   -- First setup the weighting vector
   
   for i=1,MAXTABLE,1 do
      wt[i] = -(MAXTABLE+1)/2 + i
      --print("i, wt[i]:", i, wt[i])
   end
   
   -- handy function to compute sum of squares from 1-n
   local function sumk2(n)
      return n*(n+1)*(2*n+1)/6
   end

   -- approx dt from loop time is 20msec ... about 50hz
   local dt = 0.020
   linfitden = (sumk2(MAXTABLE) - MAXTABLE*(MAXTABLE+1)*(MAXTABLE+1)/4)
   print("N, denominator:", MAXTABLE, linfitden)
   linfitden = linfitden * dt

   -- linfitden is the denominator, a constant
   
   --print("linfitden*dt:", linfitden)

   --CARSTEN   
   
   autoIdx = system.registerControl(1, "TwinThrMix", "T01")

   --system.playFile('/Apps/DFM-Auto/AT_Active.wav', AUDIO_QUEUE)
   
end

--------------------------------------------------------------------------------

setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=FltEVersion,
	name="Flight Engineer"}
