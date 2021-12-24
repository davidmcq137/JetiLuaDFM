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
local rpm1, rpm2 = 0,0
local rpm1Last, rpm2Last = 0,0
local temp1, temp2 = 0,0
local syncSwitch
local syncMix

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

--local spdTable={}
local syncTable={}
local timTable={}
local MAXTABLE=20
local errsig = 0
local syncOn = false
--local autoOn = false
local syncIdx
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
   for k, sensor in ipairs(sensors) do
      print(k,sensor.label, sensor.id, sensor.param)
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

local function syncSwitchChanged(value)
   syncSwitch = value
   system.pSave("syncSwitch", syncSwitch)
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
      form.addInputbox(eng[1].Control, true, (function(x) return engControlChanged(x, 1) end) )

      form.addRow(2)
      form.addLabel({label="Right Engine Throttle Control", width=220})
      form.addInputbox(eng[2].Control, true, (function(x) return engControlChanged(x, 2) end) )      

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
      form.addLabel({label="Sync Enable Switch", width=220})
      form.addInputbox(syncSwitch, false, syncSwitchChanged)

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

      --[[
      form.addRow(2)
      form.addLabel({label="PID Derivative gain", width=220})
      form.addIntbox(dGainInput, 0, 100, 1, 0, 1, dGainChanged)
      
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

    --rpm1 = 6000 * (1 + system.getInputs("P7"))/2
    --print("O24", system.getInputs("O24"))
    rpm2 = 5500 * system.getInputs("O24")

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

    if math.abs(rpm1-rpm2) <=1 then rpm2 = rpm1 end -- stop flickering
    
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
    DrawRectGaugeCenter(158, 145, 40, 10, -0.5, 0.5, syncMix)
    DrawErrsig(0,0)
end

local function getTemps()
   local sensor

   if (eng[1].Temp.SeId ~= 0) then
      sensor = system.getSensorByID(eng[1].Temp.SeId, eng[1].Temp.SePa)
   end
   if (sensor and sensor.valid) then
      temp1 = sensor.value
   end

   if (eng[2].Temp.SeId ~= 0) then
      sensor = system.getSensorByID(eng[2].Temp.SeId, eng[2].Temp.SePa)
   end
   if (sensor and sensor.valid) then
      temp2 = sensor.value
   end
   
end

local function getRPMs()

   local sensor, slp

   if (eng[1].RPM.SeId ~= 0) then
      sensor = system.getSensorByID(eng[1].RPM.SeId, eng[1].RPM.SePa)
      if (sensor and sensor.valid) then
	 rpm1 = sensor.value
      end
   end

   if (eng[2].RPM.SeId ~= 0) then
      sensor = system.getSensorByID(eng[2].RPM.SeId, eng[2].RPM.SePa)
      if (sensor and sensor.valid) then
	 rpm2 = sensor.value
      end
   end
   
   if rpm1 ~= 0 and rpm2 ~= 0 then
      syncDelta = rpm1 - rpm2
      lastValid = system.getTimeCounter()
   else
      syncDelta = 0
   end
   
end

local function logCB(idx)

   --print("logCB", idx)

   --print(throttle, set_speed, errLogIdx)

   ---[[
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
   --]]
   return 0
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
   local swi, swc, swa, sws
   local throttle_stick
   
   -- gather some stats on loop times so we can normalize integrator performance
   
   if not appStartTime then appStartTime = system.getTimeCounter() end
      
   -- first read the configuration from the switches that have been assigned

   swi = system.getInputsVal(spdSwitch)  -- enable normal speed announce vary by delta speed
   swc = system.getInputsVal(contSwitch) -- enable continuous annonucements
   sws = system.getInputsVal(syncSwitch) -- enable RPM sync

   syncOn = false
   if sws and sws == 1 then syncOn = true end
   
   getTemps()
   
   getRPMs()

   errsig = errsig / 1000.
   --print("minSyncRPM", engineParams.minSyncRPM)
   
   if syncOn and rpm1 > engineParams.minSyncRPM and rpm2 > engineParams.minSyncRPM then
      pGain = pGainInput / 5000.0
      iGain = iGainInput / 500.0 -- * baseLineLPS / loopsPerSecond
      if not slAvg then
	 slAvg = slope
      end
      pTerm  = errsig * pGain
      iTerm  = math.max(-1, math.min(iTerm + errsig * iGain, 1))
      syncMix = pTerm + iTerm
      syncMix = math.max(-1, math.min(syncMix, 1))
      --need to check here that syncMix won't drive throttle below 0
      --local thr = system.getInputs("P4")
      --print(thr, syncMix*0.20)
      system.setControl(syncIdx, syncMix * 0.20, 0)
   else
      iTerm = 0
      pTerm = 0
      syncMix = 0
      system.setControl(syncIdx, 0, 0)
   end

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
   syncSwitch = system.pLoad("syncSwitch")
   setPtControl = system.pLoad("setPtControl")
   spdInter = system.pLoad("spdInter", 10)
   VrefSpd = system.pLoad("VrefSpd", 60)
   VrefCall = system.pLoad("VrefCall", 2)
   maxSpd = system.pLoad("maxSpd", 200)
   pGainInput = system.pLoad("pGainInput", 20)
   iGainInput = system.pLoad("iGainInput", 100)
   dGainInput = system.pLoad("dGainInput", 0)   
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
   --system.registerTelemetry(2, "Calibrated Airspeed", 1, calAirspeed)

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
   
   print("calling readSensors()")
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
   
   syncIdx = system.registerControl(1, "TwinThrMix", "T01")

   --system.playFile('/Apps/DFM-Auto/AT_Active.wav', AUDIO_QUEUE)
   
end

--------------------------------------------------------------------------------

setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=FltEVersion,
	name="Flight Engineer"}
