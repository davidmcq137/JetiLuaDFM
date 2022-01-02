--[[

   ----------------------------------------------------------------------------
   DFM-FltE.lua
   
   Flight Engineer to assist with twin-engine aircraft
   
   Requires transmitter firmware 5.0 or higher

   0.0 12/30/2021 Initial Version
   0.1 12/31/2021 Menus to edit V speeds
   0.2 01/01/2022 Menus to edit RPMs and Temps 

   ----------------------------------------------------------------------------
               Released under MIT-license by DFM Dec 2021
   ----------------------------------------------------------------------------

--]]

local FltEVersion = "0.3"
local appDir = "Apps/DFM-FltE/"

local spdSwitch
local contSwitch
local spdSe
local spdSeId
local spdSePa
local spdInter
local shortestAnn
local longestAnn
local selFt
local selFtIndex
local shortAnn, shortAnnIndex
local emFlag

local engT = {
   {Name="Left",  RPM={"Se", "SeId", "SePa"}, Temp={"Se", "SeId", "SePa"}},
   {Name="Right", RPM={"Se", "SeId", "SePa"}, Temp={"Se", "SeId", "SePa"}}
}

local eng = {}
local def = {}
local syncDelta = 0
local RPM={}
RPM[1]=0
RPM[2]=0
local CHT={}
CHT[1]=0
CHT[2]=0
local lastCHT={}
lastCHT[1]=""
lastCHT[2]=""
local GaugeTempRange
local GaugeMaxRPM
local RPMRunning
local engineName
local minSyncRPM
local hyst

local syncSwitch
local syncMix=0
local thrOKMessage = false
local VSpeedsUp
local VSpeedsDn

local controls = {
   "...",
   "P1",   "P2",  "P3",  "P4",  "P5",  "P6",  "P7",  "P8",  "P9", "P10",
   "SA",   "SB",  "SC",  "SD",  "SE",  "SF",  "SG",  "SH",  "SI",  "SJ",
   "SK",   "SL",  "SM",  "SN",  "SO",  "SP",  "O1",  "O2",  "O3",  "O4",
   "O5",   "O6",  "O7",  "O8",  "O9", "O10", "O11", "O12", "O13", "O14",
   "O15", "O16", "O17", "O18", "O19", "O20", "O21", "O22", "O23", "O24"
}

local pumpOn = {}
local startOn = {}

local ctlIdx = {}
local controlSnapshots = {}
local ctlSe
local ctlSeId
local ctlSePa
local snapSwitch
local lastSnapSwitch

local nextAnnTC = 0
local lastAnnTC = 0
local lastAnnSpd = 0
local sgTC
local sgTC0

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }

local gauge_c={}
local gauge_s={}
local speed = 0
local iTerm = 0
local pTerm = 0

local errsig = 0
local syncOn = false

local syncIdx
local pGain
local iGain
local pGainInput
local iGainInput
local appStartTime

local function readSensors()
   local prefix
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      --print(k,sensor.label, sensor.id, sensor.param)
      if sensor.param == 0 then prefix = sensor.label else
	 if (sensor.label ~= "") then
	    table.insert(sensorLalist, prefix .. "->"..sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
   end
end

local function spdSwitchChanged(value)
   spdSwitch = value
   system.pSave("spdSwitch", spdSwitch)
end

local function contSwitchChanged(value)
   contSwitch = value
   system.pSave("contSwitch", contSwitch)
end

local function syncSwitchChanged(value)
   syncSwitch = value
   system.pSave("syncSwitch", syncSwitch)
end

local function snapSwitchChanged(value)
   snapSwitch = value
   system.pSave("snapSwitch", snapSwitch)
end

local function spdInterChanged(value)
   spdInter = value
   system.pSave("spdInter", spdInter)
end

local function  shortestAnnChanged(value)
   shortestAnn = value
   system.pSave("shortestAnn", shortestAnn)
end

local function  longestAnnChanged(value)
   longestAnn = value
   system.pSave("longestAnn", longestAnn)
end
				 
local function pGainChanged(value)
   pGainInput = value
   system.pSave("pGainInput", pGainInput)
end

local function iGainChanged(value)
   iGainInput = value
   system.pSave("iGainInput", iGainInput)
end

local function maxRPMChanged(value)
   GaugeMaxRPM = value
   system.pSave("GaugeMaxRPM", GaugeMaxRPM)
end

local function engineNameChanged(value)
   engineName = value
   system.pSave("engineName", value)
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

local function ctlSensorChanged(value)
   ctlSe = value
   ctlSeId = sensorIdlist[ctlSe]
   ctlSePa = sensorPalist[ctlSe]
   if (ctlSeId == "...") then
      ctlSe = 0
      ctlSeId = 0
      ctlSePa = 0 
   end
   system.pSave("ctlSe", ctlSe)
   system.pSave("ctlSeId", ctlSeId)
   system.pSave("ctlSePa", ctlSePa)
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
   --print("eng sensor pSave", value, num, name)
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
   local tt = system.getSwitchInfo(eng[num].Control)
   if not (tt and tt.proportional and tt.assigned and tt.mode == "PC") then
	 system.messageBox("Must be set Proportional and not Centered")
	 eng[num].Control = nil
   end
   system.pSave("eng"..num.."Control", eng[num].Control)
end

local function VSpeedChanged(value, num, name, field, dir)
   --print("VSpeedChanged", value, num, name, dir)
   if dir == "up" then
      VSpeedsUp[num][name][field] = value
      --print("saving as ".. "UP"..num..name..field, value)
      system.pSave("UP"..num..name..field, value)
   else
      VSpeedsDn[num][name][field] = value
      --print("saving as ".. "DN"..num..name..field, value)
      system.pSave("DN"..num..name..field, value)      
   end
end

local function ShakeChanged(value, num, name, field, dir)
   stickMap = {0, -1, -2, -3, -4, 1, 2, 3, 4}
   if dir == "up" then
      VSpeedsUp[num][name][field] = stickMap[value]
      --print("saving as " .. "UP" ..num .. name .. field, value)
      system.pSave("UP"..num..name..field, stickMap[value])
   else
      VSpeedsDn[num][name][field] = stickMap[value]
      --print("saving as " .. "DN" ..num .. name .. field, value)
      system.pSave("DN"..num..name..field, stickMap[value])      
   end
end

local function WavChanged(value, num, name, field, dir)
   if dir == "up" then
      VSpeedsUp[num][name][field] = value - 1
      --print("pSave UP" .. num .. name ..field, value-1)
      system.pSave("UP"..num..name..field, value-1)
   else
      VSpeedsDn[num][name][field] = value - 1
      system.pSave("DN"..num..name..field, value-1)      
   end
end

local function controlsSelectedChanged(value, ii)
   --print("%", value, ii)
   ctlIdx[ii] = value
   system.pSave("ctlIdx"..ii, value)
end

local function TempRangeChanged(value, key)
   GaugeTempRange[key] = value
   system.pSave("TempRange"..key, value)
end

local function onChanged(value, ps, lr)
   print("onChanged", value, ps, lr)
   if ps == "start" then
      startOn[lr] = value
      system.pSave("startOn"..lr, value)
   else
      pumpOn[lr] = value
      system.pSave("pumpOn"..lr, value)
   end
end

local function initForm(subForm)
   
   local stickVibIdx
   stickVib = {"No Shake", "L 1 Long" , "L 1 Short" , "L 2 Short" , "L 3 Short",
	       "R 1 Long", "R 1 Short", "R 2 Short", "R 3 Short"}

   local wavIdx
   local wavPlay = {"No Audio", "Audio"}

      
   if tonumber(system.getVersion()) < 5.0 then
      form.addRow(1)
      form.addLabel({label="Minimum TX Version is 5.0", width=220, font=FONT_NORMAL})
      return
   end

   if subForm == 1 then
      
      form.addLink((function() form.reinit(2) end), {label = "V speeds >>"})        -- 2
      form.addLink((function() form.reinit(3) end), {label = "Sensors >>"})         -- 3
      form.addLink((function() form.reinit(4) end), {label = "Controls >>"})        -- 4 
      form.addLink((function() form.reinit(5) end), {label = "Settings >>"})        -- 5
      form.addLink((function() form.reinit(6) end), {label = "Speed Announcer >>"}) -- 6
      form.addLink((function() form.reinit(7) end), {label = "Snapshot >>"})        -- 7
      form.addLink((function() form.reinit(8) end), {label = "Temps >>"})           -- 8
      form.addRow(1)
      form.addLabel({label="DFM-FltE.lua Version "..FltEVersion.." ", font=FONT_MINI, alignRight=true})
      
   elseif subForm == 2 then -- V Speeds
      form.addLink((function() form.reinit(1) end), {label = "<< Return"})      
      form.addRow(1)
      form.addLabel({label="Overspeed Warnings", font=FONT_BOLD})
      for k,v in ipairs(def.VSpeedsUp) do
	 for kk,_ in pairs(v) do
	    form.addRow(4)
	    form.addLabel({label=kk, width=55})
	    form.addIntbox(VSpeedsUp[k][kk].S, 10, 200, 60, 0, 1,
			   (function(x) return VSpeedChanged(x, k, kk, "S", "up") end),
			   {width=60})
	    if VSpeedsUp[k][kk].shake > 0 then -- right stick
	       stickVibIdx = VSpeedsUp[k][kk].shake + 5
	    else
	       stickVibIdx = -VSpeedsUp[k][kk].shake + 1
	    end
	    form.addSelectbox(stickVib, stickVibIdx, true,
			      (function(x) return ShakeChanged(x, k, kk, "shake", "up") end),
			      {width=100})
	    wavIdx = 1 + VSpeedsUp[k][kk].wav
	    form.addSelectbox(wavPlay, wavIdx, true,
			      (function(x) return WavChanged(x, k, kk, "wav", "up") end),
			      {width=105})
	 end
      end

      form.addRow(1)
      form.addLabel({label="Underspeed Warnings", font=FONT_BOLD})
      for k,v in ipairs(def.VSpeedsDn) do
	 for kk,_ in pairs(v) do
	    form.addRow(4)
	    form.addLabel({label=kk, width=55})
	    form.addIntbox(VSpeedsDn[k][kk].S, 10, 200, 60, 0, 1,
			   (function(x) return VSpeedChanged(x, k, kk, "S", "dn") end),
			   {width=60})
	    if VSpeedsDn[k][kk].shake > 0 then -- right stick
	       stickVibIdx = VSpeedsDn[k][kk].shake + 5
	    else
	       stickVibIdx = -VSpeedsDn[k][kk].shake + 1
	    end
	    form.addSelectbox(stickVib, stickVibIdx, true,
			      (function(x) return ShakeChanged(x, k, kk, "shake", "dn") end),
			      {width=100})

	    wavIdx = 1 + VSpeedsDn[k][kk].wav
	    form.addSelectbox(wavPlay, wavIdx, true,
			      (function(x) return WavChanged(x, k, kk, "wav", "dn") end),
			      {width=105})
	 end
      end
   elseif subForm == 3 then -- Sensors

      form.addLink((function() form.reinit(1) end), {label = "<< Return"})

      form.addRow(2)
      form.addLabel({label="Left RPM", width=120})
      form.addSelectbox(sensorLalist, eng[1].RPM.Se, true,
			(function(x) return engSensorChanged(x,1,"RPM") end), {width=190})
      
      form.addRow(2)
      form.addLabel({label="Right RPM", width=120})
      form.addSelectbox(sensorLalist, eng[2].RPM.Se, true,
			(function(x) return engSensorChanged(x,2,"RPM") end), {width=190})
      
      form.addRow(2)
      form.addLabel({label="Left Temp", width=120})
      form.addSelectbox(sensorLalist, eng[1].Temp.Se, true,
			(function(x) return engSensorChanged(x,1,"Temp") end), {width=190})	
      
      form.addRow(2)
      form.addLabel({label="Right Temp", width=120})
      form.addSelectbox(sensorLalist, eng[2].Temp.Se, true,
			(function(x) return engSensorChanged(x,2,"Temp") end), {width=190})

   elseif subForm == 4 then -- Controls
      form.addLink((function() form.reinit(1) end), {label = "<< Return"})      

      form.addRow(2)
      form.addLabel({label="Throttle Control", width=220})
      form.addInputbox(eng[1].Control, true, (function(x) return engControlChanged(x, 1) end) )
      
      --form.addRow(2)
      --form.addLabel({label="Right Engine Throttle Control", width=220})
      --form.addInputbox(eng[2].Control, true, (function(x) return engControlChanged(x, 2) end) )      
      
      form.addRow(2)
      form.addLabel({label="Sync Enable Switch", width=220})
      form.addInputbox(syncSwitch, false, syncSwitchChanged)

   elseif subForm == 5 then -- Settings
      form.addLink((function() form.reinit(1) end), {label = "<< Return"})
      
      form.addRow(2)
      form.addLabel({label="Sync PID Prop gain", width=220})
      form.addIntbox(pGainInput, 0, 100, 1, 0, 1, pGainChanged)
      
      form.addRow(2)
      form.addLabel({label="Sync PID Int gain", width=220})
      form.addIntbox(iGainInput, 0, 100, 1, 0, 1, iGainChanged)

      form.addRow(2)
      form.addLabel({label="Max Gauge RPM", width=220})
      form.addIntbox(GaugeMaxRPM, 1000, 10000, 6000, 0, 100, maxRPMChanged)
      
      form.addRow(2)
      form.addLabel({label="Engine Name", width=60})
      form.addTextbox(engineName, 20, engineNameChanged, {width=260})

      form.addLink((function() form.reinit(51) end), {label = "Indicators >>"})
      
   elseif subForm == 51 then
      form.addLink((function() form.reinit(5) end), {label = "<< Return"})

      form.addRow(4)
      form.addLabel({label="Left Pump", width=90})
      form.addInputbox(pumpOn[1], true,
			      (function(x) return onChanged(x,  "pump", 1) end),
			      {width=70})
      form.addLabel({label="Left Start", width=90})
      form.addInputbox(startOn[1], true,
			      (function(x) return onChanged(x, "start", 1) end),
			      {width=70})      

      form.addRow(4)
      form.addLabel({label="Right Pump", width=90})
      form.addInputbox(pumpOn[2], true,
			      (function(x) return onChanged(x,  "pump", 2) end),
			      {width=70})
      form.addLabel({label="Right Start", width=90})
      form.addInputbox(startOn[2], true,
			      (function(x) return onChanged(x, "start", 2) end),
			      {width=70})      
      
   elseif subForm == 6 then -- Speed Announcer
      form.addLink((function() form.reinit(1) end), {label = "<< Return"})   

      form.addRow(2)
      form.addLabel({label="Speed Ann Enable Switch", width=220})
      form.addInputbox(spdSwitch, false, spdSwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Cont. Speed Ann Switch", width=220})
      form.addInputbox(contSwitch, false, contSwitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Airspeed Sensor", width=120})
      form.addSelectbox(sensorLalist, spdSe, true, sensorChanged, {width=190})

      form.addRow(2)
      form.addLabel({label="Speed change scale factor", width=220})
      form.addIntbox(spdInter, 1, 100, 10, 0, 1, spdInterChanged)

      form.addRow(2)
      form.addLabel({label="Shortest announce time", width=220})
      form.addIntbox(shortestAnn, 1, 10, 2, 0, 1, shortestAnnChanged)

      form.addRow(2)
      form.addLabel({label="Longest announce time", width=220})
      form.addIntbox(longestAnn, 10, 40, 20, 0, 1, longestAnnChanged)

   elseif subForm == 7 then
      form.addLink((function() form.reinit(1) end), {label = "<< Return"})
      form.addLink((function() form.reinit(8) end), {label = "Display Snapshots >>", width=170})
      
      form.addRow(2)
      form.addLabel({label="Snapshot Switch", width=220})
      form.addInputbox(snapSwitch, false, snapSwitchChanged)

      form.addRow(1)
      form.addLink(
	 (function() system.messageBox("Snapshots Reset") controlSnapshots={} form.reinit(71) end),
	 {label = "Reset Snapshots ("..#controlSnapshots..") >>", width=180}
      )         

      form.addRow(2)
      form.addLabel({label="Sensor", width=100})
      form.addSelectbox(sensorLalist, ctlSe, true, ctlSensorChanged, {width=220})

      form.addRow(5)
      form.addLabel({label="Ctrl", width=60})
      for j=1,4,1 do
	 --print(j, ctlIdx[j])
	 form.addSelectbox(controls, ctlIdx[j], true,
			   (function(x) return controlsSelectedChanged(x,j) end), {width=65})
      end

   elseif subForm == 71 then
      form.addLink((function() form.reinit(7) end), {label = "<< Return"})

      local snapC = #controlSnapshots
      local line, lbl

      lbl = "Time   Sensor          "
      for i=1,4,1 do
	 lbl = lbl .. controls[ctlIdx[i]] .."       "
      end
      form.addRow(1)
      form.addLabel({label=lbl})
      for i=1,snapC,1 do
	 form.addRow(1)
	 --local snap = {time=ctstr, sensor=sval, controls=cval}
	 line = controlSnapshots[i]
	 lbl = line.time.."  " .. line.sensor.."   "
	 for j=1,4,1 do
	    lbl = lbl .. "   " .. line.controls[j]
	 end
	 form.addLabel({label=lbl, width=320})
      end

   elseif subForm == 8 then
      form.addLink((function() form.reinit(1) end), {label = "<< Return"})
      local gaugeTbl={}
      for k in pairs(GaugeTempRange) do
	 table.insert(gaugeTbl, k)
      end
      table.sort(gaugeTbl, function(a,b) return GaugeTempRange[a] > GaugeTempRange[b] end)
      
      for k,v in pairs(gaugeTbl) do
	 form.addRow(2)
	 form.addLabel({label=v, width=240})
	 --form.addIntbox(VSpeedsDn[k][kk].S, 10, 200, 60, 0, 1,
	 --(function(x) return VSpeedChanged(x, k, kk, "S", "dn") end),
	 --{width=60})
	 form.addIntbox(GaugeTempRange[v], 10, 500, 100, 0, 1, 
			(function(x) return TempRangeChanged(x, v) end),
			   {width=60})
      end
   elseif subForm == 99 then -- these are parked for the moment
      form.addRow(2)
      form.addLabel({label="Use mph or km/hr (x)", width=270})
      selFtIndex = form.addCheckbox(selFt, selFtClicked)
      
      form.addRow(2)
      form.addLabel({label="Short Announcement", width=270})
      shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   else
      print("Bad subForm "..subForm)
   end
end

local needle_poly_large = {
   {-4,28},
   {-2,64},
   {2,64},
   {4,28}
}

local tick_mark = {
   {-2,56},
   {-2,65},
   { 2,65},
   { 2,56}
}

local needle_poly_small_small = {
   {-2,2},
   {-1,20},
   {1,20},
   {2,2}
}

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

local function DrawErrsig()
    local ox, oy = 158, 110
    local ierr = math.min(math.max(syncDelta, -100), 100)
    local theta = math.rad(135 * ierr / 100) - math.pi
    lcd.setColor(255, 0, 0)
    if gauge_s then lcd.drawImage(ox-gauge_s.width//2, oy-gauge_s.width//2, gauge_s) end
    drawShape(ox, oy, needle_poly_small_small, theta)
    lcd.drawFilledRectangle(ox-1, oy-32, 2, 8)
    lcd.setColor(0,0,0)
    lcd.drawText(ox - lcd.getTextWidth(FONT_MINI, "Sync") // 2, oy + 13, "Sync", FONT_MINI)
end

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
    local minRPM = 0
    local maxRPM = GaugeMaxRPM
    local rt = string.format("%d-%d/min", minRPM, maxRPM)
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MINI,rt) / 2 , oy + 105,
		 rt, FONT_MINI)
    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    lcd.setColor(255,255,255)
    lcd.drawFilledRectangle(ox+65-5, oy, 10, 20)
    lcd.setColor(160,160,160)
    local RPMstep = GaugeMaxRPM / 4
    for v=0,GaugeMaxRPM, RPMstep do
       drawShape(ox+65, oy+65, tick_mark, angle1(v, minRPM, maxRPM))
       drawShape(ox+65, oy+65, tick_mark, angle2(v, minRPM, maxRPM))       
    end
    local r1,r2 = math.max(math.min(RPM[1], maxRPM), minRPM), math.max(math.min(RPM[2], maxRPM), minRPM)
    local theta1 = angle1(r1, minRPM, maxRPM) 
    local theta2 = angle2(r2, minRPM, maxRPM) 

    lcd.setColor(255,0,0)
    drawShape(ox+65, oy+65, needle_poly_large, theta1)       
    lcd.setColor(255,0,0)
    drawShape(ox+65, oy+65, needle_poly_large, theta2)
    lcd.setColor(0,0,0)
    if math.abs(RPM[1]-RPM[2]) <=1 then RPM[2] = RPM[1] end -- stop flickering
    local text1 = string.format("%d", math.floor(RPM[1] + 0.5))
    local text2 = string.format("%d", math.floor(RPM[2] + 0.5))
    lcd.drawText(ox + 30 - lcd.getTextWidth(FONT_BIG, text1) / 2, oy + 120,
		 text1, FONT_BIG)
    lcd.drawText(ox + 100 - lcd.getTextWidth(FONT_BIG, text2) / 2, oy + 120,
		 text2, FONT_BIG)    
end

--------------------------------------------------------


local function DrawTemp()

    local ox, oy = 186, 8

    if emFlag then
       local spdText = "Airspeed "..string.format("%d", math.floor(speed + 0.5))
       lcd.drawText(160 - lcd.getTextWidth(FONT_MINI, spdText)/2,148,spdText, FONT_MINI)
    end
    

    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_BIG,"CHT") / 2 , oy + 54,
		 "CHT", FONT_BIG)

    local minTemp = GaugeTempRange.Min -- def.Temps[1]
    local maxTemp = GaugeTempRange.Max -- def.Temps[#def.Temps]

    local rt = string.format("%d-%d°C", minTemp, maxTemp)
    lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MINI,rt) / 2 , oy + 105,
		 rt, FONT_MINI)

    --local CHT[1] = 300 * (1 + system.getInputs("P5"))/2
    --local CHT[2] = 300 * (1 + system.getInputs("P6"))/2
    local text1 = string.format("%d", math.floor(CHT[1] + 0.5))
    local text2 = string.format("%d", math.floor(CHT[2] + 0.5))

    local theta1 = angle1(CHT[1], minTemp, maxTemp)
    local theta2 = angle2(CHT[2], minTemp, maxTemp)

    if gauge_c then lcd.drawImage(ox, oy, gauge_c) end
    lcd.setColor(255,255,255)
    lcd.drawFilledRectangle(ox+65-5, oy, 10, 20)

    lcd.setColor(160,160,160)
    
    --for _,v in ipairs(def.Temps) do
    --drawShape(ox+65, oy+65, tick_mark, angle1(v, minTemp, maxTemp))
    --drawShape(ox+65, oy+65, tick_mark, angle2(v, minTemp, maxTemp))       
    --end
    
    for k,v in pairs(GaugeTempRange) do
       drawShape(ox+65, oy+65, tick_mark, angle1(v, minTemp, maxTemp))
       drawShape(ox+65, oy+65, tick_mark, angle2(v, minTemp, maxTemp))              
    end
    
    for i=1,2,1 do
       if CHT[i] < GaugeTempRange.Normal then
	  lcd.setColor(0,0,255)
       elseif CHT[i] >= GaugeTempRange.Normal and CHT[i] < GaugeTempRange.Warning then
	  lcd.setColor(0,255,0)
       elseif CHT[i] >= GaugeTempRange.Warning and CHT[i] < GaugeTempRange.Overheat then
	  lcd.setColor(255,255,0)
       else
	  lcd.setColor(255,0,0)
       end
       if i == 1 then
	  drawShape(ox+65, oy+65, needle_poly_large, theta1)       
       else
	  drawShape(ox+65, oy+65, needle_poly_large, theta2)
       end
    end

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

    lcd.drawRectangle(ox, oy, W, H)

    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Start")) / 2, oy,    "Start", FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Pump")) / 2, oy+23, "Pump", FONT_MINI)
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_MINI,"Run")) / 2, oy+46, "Run", FONT_MINI)

    lcd.drawLine(ox, oy + 23, ox + W - 1, oy + 23)
    lcd.drawLine(ox, oy + 46, ox + W - 1, oy + 46)

    local oxx = {ox+8, ox + W - 16}

    for i=1,2,1 do
       if system.getInputsVal(startOn[i]) == 1 then
	  lcd.setColor(0,0,255)
       else
	  lcd.setColor(255,255,255) -- white/blank
       end
       lcd.drawFilledRectangle(oxx[i], oy + 13, 8, 8)
    end
    
    for i=1,2,1 do
       if system.getInputsVal(pumpOn[i]) == 1 then
	  lcd.setColor(0,255,0)
       else
	  lcd.setColor(255,0,0)
       end
       lcd.drawFilledRectangle(oxx[i], oy + 36,  8, 8)
    end

    for i=1,2,1 do
       if RPM[i] > RPMRunning then
	  lcd.setColor(0,255,0)
       else
	  lcd.setColor(255,0,0)
       end
       lcd.drawFilledRectangle(oxx[i], oy + 59, 8,8)
    end
    
end

--------------------------------------------------------------------------------

local function wbTele()
   lcd.setColor(255,255,255)
   lcd.drawFilledRectangle(0,0,320,170)
   lcd.setColor(0,0,0)
   DrawRPM(0,0)
   DrawTemp(0,0)
   DrawCenterBox(0,0,0,0)
   DrawRectGaugeCenter(158, 143, 40, 10, -0.2, 0.2, syncMix * 0.2)
   DrawErrsig(0,0)
end

local function getTemps()
   local sensor

   if (eng[1].Temp.SeId ~= 0) then
      sensor = system.getSensorByID(eng[1].Temp.SeId, eng[1].Temp.SePa)
   end
   if (sensor and sensor.valid) then
      CHT[1] = sensor.value
   end

   if (eng[2].Temp.SeId ~= 0) then
      sensor = system.getSensorByID(eng[2].Temp.SeId, eng[2].Temp.SePa)
   end
   if (sensor and sensor.valid) then
      CHT[2] = sensor.value
   end
   
end

local function getSpeed()
   local sensor
   spd = 0
   if spdSeId ~= 0 then
      sensor = system.getSensorByID(spdSeId, spdSePa)
      if (sensor and sensor.valid) then
	 spd = sensor.value
      else
	 return spd
      end
      
      --print("raw sensor:", spd)
      if selFt then
	 if sensor.unit == "m/s" then
	    spd = spd * 2.23694 -- m/s to mph
	 end
	 if sensor.unit == "kmh" or sensor.unit == "km/h" then
	    spd = spd * 0.621371 -- km/hr to mph
	 end
      else
	 if sensor.unit == "m/s" then
	    spd = spd * 3.6 -- km/hr
	 end
      end
   end
   return spd
end

local function getRPMs()

   local sensor

   if (eng[1].RPM.SeId ~= 0) then
      sensor = system.getSensorByID(eng[1].RPM.SeId, eng[1].RPM.SePa)
      if (sensor and sensor.valid) then
	 RPM[1] = sensor.value
      end
   end

   if (eng[2].RPM.SeId ~= 0) then
      sensor = system.getSensorByID(eng[2].RPM.SeId, eng[2].RPM.SePa)
      if (sensor and sensor.valid) then
	 RPM[2] = sensor.value
      end
   end
   
   if RPM[1] ~= 0 and RPM[2] ~= 0 then
      syncDelta = RPM[1] - RPM[2]
   else
      syncDelta = 0
   end
   
end

local function shakeStk(shake)
   local leftright, vibe
   if shake ~= 0 then
      if shake < 0 then
	 leftright = false 
	 vibe = -shake
      else
	 leftright = true
	 vibe = shake
      end
      system.vibration(leftright, vibe)
   end
end

local function playAudio(name)
   system.playFile(appDir..name..".wav", AUDIO_IMMEDIATE)
end

local function playTemp(num, temp)
   system.playFile(appDir .."Eng"..num..temp..".wav", AUDIO_QUEUE)
end

local function loop()

   local deltaSA
   local uuu
   local round_spd
   local swi, swc, sws, swn
   
   -- gather some stats on loop times so we can normalize integrator performance
   
   if not appStartTime then appStartTime = system.getTimeCounter() end

   -- check if engines running, and with performance tolerance
   
   for i=1,2,1 do
      if RPM[i] < RPMRunning then
	 eng[i].Running = false
	 eng[i].Fail = true
      else
	 eng[i].Running = true
      end
      -- performance check goes here
   end
   
   
   -- check temperature ranges and warnings

   local currentCHT
   for i=1,2,1 do
      if CHT[i] < GaugeTempRange.Normal then
	 currentCHT = "Cold"
      elseif CHT[i] >= GaugeTempRange.Normal and CHT[i] < GaugeTempRange.Warning then
	 currentCHT = "Normal"
      elseif CHT[i] >= GaugeTempRange.Warning and CHT[i] < GaugeTempRange.Overheat then
	 currentCHT = "Warning"
      else
	 currentCHT = "Overheat"
      end
      if currentCHT ~= lastCHT[i] then
	 playTemp(i, currentCHT)
      end
      lastCHT[i] = currentCHT
   end
   
   -- first read the configuration from the switches that have been assigned

   if not lastSnapSwitch then lastSnapSwitch = system.getInputsVal(snapSwitch) end

   swi = system.getInputsVal(spdSwitch)  -- enable normal speed announce vary by delta speed
   swc = system.getInputsVal(contSwitch) -- enable continuous annonucements
   sws = system.getInputsVal(syncSwitch) -- enable RPM sync
   swn = system.getInputsVal(snapSwitch) -- snapshot switch

   
   local sval
   
   local ctimeMilli = system.getTimeCounter()

   if swn ~= lastSnapSwitch and swn == 1 then

      if ctlSeId ~= 0 then
	 sensor = system.getSensorByID(ctlSeId, ctlSePa)
	 if (sensor and sensor.valid) then
	    sval = sensor.value
	 end
      end
      
      local cval={}

      cval[1],cval[2],cval[3],cval[4] =
	 system.getInputs(controls[ctlIdx[1]], controls[ctlIdx[2]],
			     controls[ctlIdx[3]], controls[ctlIdx[4]])
      for i=1,4,1 do
	 if not cval[i] or ctlIdx[i] == 1 then
	    cval[i] = "     "
	 else 
	    cval[i] = string.format("%+.2f", cval[i])
	 end
      end
      
      if not sval then sval = "---" else sval = string.format("%.2f", sval) end
      local ctime = (ctimeMilli - appStartTime) / 1000
      local ctmin = ctime // 60
      local ctsec = ctime - ctmin * 60
      local ctstr = string.format("%02d:%02d", ctmin, ctsec)
      local snap = {time=ctstr, sensor=sval, controls=cval}
      table.insert(controlSnapshots, snap)
      system.messageBox("Snapshot at " .. ctstr)
   end

   lastSnapSwitch = swn

   
   syncOn = false
   if sws and sws == 1 then syncOn = true end
   
   local thrOK = false
   local tt = system.getSwitchInfo(eng[1].Control)
   if tt and tt.proportional and tt.assigned and tt.mode == "PC" then thrOK = true else
      if not thrOKMessage then
	 system.messageBox("Sync not enabled - Bad Throttle Control")
	 thrOKMessage = true
      end
   end

   if thrOK then thrOKMessage = false end
   
   getTemps()
   
   getRPMs()

   errsig = syncDelta / 1000.0
   
   if thrOK and syncOn and RPM[1] > def.minSyncRPM and RPM[2] > def.minSyncRPM then
      pGain = pGainInput / 50.0
      iGain = iGainInput / 50.0 
      pTerm  = errsig * pGain
      iTerm  = math.max(-1, math.min(iTerm + errsig * iGain, 1))
      syncMix = pTerm + iTerm
      syncMix = math.max(-1, math.min(syncMix, 1))
      --need to check here that syncMix won't drive throttle below 0 or above 1
      local thr = system.getInputsVal(eng[1].Control) or 0
      --print(thr, syncMix, thr+0.2*syncMix)
      if ( (thr + 0.2 * syncMix) >= 0) and ( (thr + 0.2 * syncMix) <= 1.05) then
	 system.setControl(syncIdx, syncMix * 0.2, 0)
      end
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
      
      speed = getSpeed()
      -- print("speed "..speed)
      -- first check all the overspeed conditions
      local vsu
      for k,v in ipairs(def.VSpeedsUp) do
	 for kk,_ in pairs(v) do
	    vsu = VSpeedsUp[k][kk]
	    if speed >= vsu.S then
	       if not vsu.active then
		  if vsu.shake ~= 0 then
		     shakeStk(vsu.shake)
		  end
		  if vsu.wav ~= 0 then
		     playAudio(kk)
		  end
		  vsu.active = true
	       end
	    else
	       if speed < vsu.S * def.hyst then
		  vsu.active = false
	       end
	    end
	 end
      end
      
      -- now check the underspeed conditions
      local vsd
      for k,v in ipairs(def.VSpeedsDn) do
	 for kk,_ in pairs(v) do
	    vsd = VSpeedsDn[k][kk]
	    if speed > vsd.S then
	       vsd.armed = true
	    end
	    if speed <= vsd.S and vsd.armed then
	       -- the cont ann below Vmca should only be when there is an engine out... we don't
	       -- have that indication yet...
	       if kk == "Vref" then --or kk == "Vmca" then -- force fast ann below Vmc or Vref
		  swc = 1
	       end
	       if not vsd.active then -- this block only happens once per trigger event
		  if (kk ~= "Vmca" and kk ~= "Vmcw") or eng[1].Fail or eng[2].Fail then
		     if vsd.shake ~= 0 then
			shakeStk(vsd.shake)
		     end
		     if vsd.wav ~= 0 then
			playAudio(kk)
		     end
		  end
		  vsd.active = true
	       end
	    else
	       if speed > vsd.S / def.hyst then
		  vsd.active = false
		  vsd.armed = true
	       end
	    end
	 end
      end

      -- this line is the heart of the speed announcer, it determies update timing
      -- vs changes in speed
      -- time-spacing multiplier is scaled by spdInter, over range of 0.5 to 10 (20:1)

      deltaSA = math.min(math.max(math.abs((speed-lastAnnSpd) / spdInter), 0.5), 10)
      
      nextAnnTC = lastAnnTC + math.min(shortestAnn * 1000 * 10 / deltaSA, longestAnn * 1000) 

      if (swc and swc == 1) then
	 nextAnnTC = lastAnnTC + shortestAnn * 1000 -- at and below Vref .. ann every shortestAnn secs
      end

      sgTC = system.getTimeCounter()
      if not sgTC0 then sgTC0 = sgTC end

      -- Added isPlayback() so that we don't create a backlog of messages if it takes
      -- longer than shortestAnn time to speak the speed
      -- This was creating a "bow wave" of pending announcements
      -- Wait till speaking is done, catch it at the next call to loop()

      if (not system.isPlayback()) and
      ((sgTC > nextAnnTC) and ( (speed > def.VSpeedsUp[1].Vaa.S) or (swc and swc == 1))) then

	 lastAnnSpd = speed
	 round_spd = math.floor(speed+0.5)
	 
	 lastAnnTC = sgTC -- note the time of this announcement
	 
	 if (selFt) then uuu = "mph" else uuu = "km/hr" end
	 
	 if (shortAnn or (swc and swc == 1) ) then
	    system.playNumber(round_spd, 0)
	 else
	    system.playNumber(round_spd, 0, uuu, "Speed")
	 end
      end -- if (not system...)
   end
end

local function loadImages()
    gauge_c = lcd.loadImage(appDir.."cl-000.png")
    gauge_s = lcd.loadImage(appDir.."cc-000.png")
    if not gauge_c or not gauge_s then print("DFM-FltE: Gauge png images(s) not loaded") end
end

local function exists(fname)
   local fg
   fg = io.open(fname, "r")
   if fg then
      io.close(fg)
      return true
   else
      return false
   end
end

local function init()

   local fg
   
   spdSwitch   = system.pLoad("spdSwitch")
   contSwitch  = system.pLoad("contSwitch")
   syncSwitch  = system.pLoad("syncSwitch")
   spdInter    = system.pLoad("spdInter", 10)
   shortestAnn = system.pLoad("shortestAnn", 2)
   longestAnn  = system.pLoad("longestAnn", 40)
   pGainInput  = system.pLoad("pGainInput", 20)
   iGainInput  = system.pLoad("iGainInput", 50)
   spdSe       = system.pLoad("spdSe", 0)
   spdSeId     = system.pLoad("spdSeId", 0)
   spdSePa     = system.pLoad("spdSePa", 0)
   ctlSe       = system.pLoad("ctlSe", 0)
   ctlSeId     = system.pLoad("ctlSeId", 0)
   ctlSePa     = system.pLoad("ctlSePa", 0)
   selFt       = system.pLoad("selFt", "true")
   shortAnn    = system.pLoad("shortAnn", "false")
   snapSwitch  = system.pLoad("snapSwitch")
   for i=1,4,1 do
      ctlIdx[i] = system.pLoad("ctlIdx"..i, 1)
   end

   emFlag = select(2, system.getDeviceType()) == 1

   for ek,ev in ipairs(engT) do
      eng[ek] = {}
      for nk,nv in pairs(ev) do
	 if type(nv) == "table" then
	    eng[ek][nk] = {}
	    for _,sv in pairs(nv) do
	       eng[ek][nk][sv] = system.pLoad("eng"..ek..nk..sv, 0)
	       --print("eng"..ek..nk..sv ..": " .. eng[ek][nk][sv])
	    end
	 end
      end
   end

   engT = nil
   
   eng[1].Control = system.pLoad("eng1Control")
   eng[2].Control = system.pLoad("eng2Control")   

   eng[1].Fail = true
   eng[2].Fail = true

   eng[1].Running = false
   eng[2].Running = false
   
   selFt = (selFt == "true") -- can't pSave and pLoad booleans...store as text 
   shortAnn = (shortAnn == "true") -- convert back to boolean here

   -- load defaults from the FE-<model>.jsn file
   
   local FEname = appDir .. "FE-" ..
      string.gsub(system.getProperty("Model")..".jsn", " ", "_")

   print("DFM-FltE: Looking for defaults file " .. FEname)

   if not exists(FEname) then
      print("DFM-FltE could not open model defaults file "..FEname)
      FEname = appDir .. "FE-Model.jsn"
      print("DFM-FltE will use generic defaults file " .. FEname)
   end
   
   fg = io.readall(FEname)
   if fg then
      def = json.decode(fg)
      if not def then
	 print("DFM-FltE: Could not decode defaults file ".. FEname)
	 error("Fatal error")
      end
   else
      print("DFM-FltE: Could not open defaults file "..FEname)
      error("Fatal error")
   end

   GaugeTempRange = {}
   for k,_ in pairs(def.TempRange) do
      GaugeTempRange[k] = system.pLoad("TempRange"..k, def.TempRange[k])
   end

   GaugeMaxRPM = system.pLoad("GaugeMaxRPM", def.MaxRPM)
   --print("GaugeMaxRPM", GaugeMaxRPM, def.MaxRPM)
   
   RPMRunning = system.pLoad("RPMRunning", def.RPMRunning)
   engineName = system.pLoad("engineName", def.Engine)
   minSyncRPM = system.pLoad("minSyncRPM", def.minSyncRPM)
   hyst = system.pLoad("hyst", def.hyst)

   for i=1,2,1 do
      pumpOn[i] = system.pLoad("pumpOn"..i)
      startOn[i] = system.pLoad("startOn"..i)
   end
   
   VSpeedsUp = {}
   for k,v in ipairs(def.VSpeedsUp) do
      VSpeedsUp[k] = {}
      for kk,_ in pairs(v) do
	 VSpeedsUp[k][kk] = {}
	 --print("UP"..k..kk.."wav", def.VSpeedsUp[k][kk].wav)
	 VSpeedsUp[k][kk].S      = system.pLoad("UP"..k..kk.."S",     def.VSpeedsUp[k][kk].S or 999)
	 VSpeedsUp[k][kk].shake  = system.pLoad("UP"..k..kk.."shake", def.VSpeedsUp[k][kk].shake or 0)
	 VSpeedsUp[k][kk].wav    = system.pLoad("UP"..k..kk.."wav",   def.VSpeedsUp[k][kk].wav or 0)
	 VSpeedsUp[k][kk].active = false
      end
   end

   VSpeedsDn = {}
   for k,v in ipairs(def.VSpeedsDn) do
      VSpeedsDn[k] = {}
      for kk,_ in pairs(v) do
	 VSpeedsDn[k][kk] = {}
	 VSpeedsDn[k][kk].S      = system.pLoad("DN"..k..kk.."S",     def.VSpeedsDn[k][kk].S or 999)
	 VSpeedsDn[k][kk].shake  = system.pLoad("DN"..k..kk.."shake", def.VSpeedsDn[k][kk].shake or 0)
	 VSpeedsDn[k][kk].wav    = system.pLoad("DN"..k..kk.."wav",   def.VSpeedsDn[k][kk].wav or 0)
	 VSpeedsDn[k][kk].active = false
	 VSpeedsDn[k][kk].armed  = false
      end
   end

   local eName = ": " .. (engineName or "")
   system.registerTelemetry(1, "Flight Engineer"..eName, 4, wbTele)
   system.registerForm(1, MENU_APPS, "Flight Engineer", initForm)

   readSensors()
   loadImages()

   syncIdx = system.registerControl(1, "TwinThrMix", "T01")

end

--------------------------------------------------------------------------------


return {init=init, loop=loop, author="DFM", version=FltEVersion, name="Flight Engineer"}
