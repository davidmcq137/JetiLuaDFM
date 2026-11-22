--[[

   DFM-GRat.lua - computes and announces glide ratio

   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - July 22, 2020
   
--]]

-- Globals to share

--[[
if not sharedVar then sharedVar = {} end

sharedVar["DFM-GRat"]       = {}
sharedVar["DFM-GRat"].label = {}
sharedVar["DFM-GRat"].value = {}
sharedVar["DFM-GRat"].unit  = {}
sharedVar["DFM-GRat"].dp    = {}
--]]

-- Locals for application

local GRatVersion= 0.1

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
local spdSe, spdSeId, spdSePa
local varSe, varSeId, varSePa
local runSwitch
local annSwitch
local shortAnn
local shortAnnIndex
local imperial
local imperialIndex
local glideRatio
local lastAnnTime
local maxRatio = 1000
local speed = 0
local vario = 0

local runData = {}
local runStartTime = 0
local runCounter = 0
local runTime
local lastTime = 0
local x = {}
local y = {}
local runLength
local elevTrimCtrl
local elevServo
local elevTrim
local runPoints = 50
local runFinished = false

local appInfo = {}
appInfo.Name = "DFM-Polr"
appInfo.Dir = "Apps/" .. appInfo.Name .. "/"

local function writeCSV()
   
   -- filename format is YYDDMMxx.csv
   local dt = system.getDateTime()
   local yy = string.format("%04d", dt.year)
   local mm = string.format("%02d", dt.mon)
   local dd = string.format("%02d", dt.day)
   local ssn = system.getSerialCode()
   local sn = string.sub(ssn, -3)
   
   local fname, fp
   for i=1, 35, 1 do
      fname = yy .. "-" .. dd .. "-" .. mm .. "-" ..string.format("%02d", i) .. ".csv"
      --print("fname: " .. fname)
      local fr = io.open(appInfo.Dir .. fname, "r")
      --print("fname, fr", fname, fr)
      if fr then
	 io.close(fr)
      else
	 fp = io.open(appInfo.Dir .. fname, "w")
	 if fp  then
	    print(appInfo.Name .. ": Opening csv file " .. appInfo.Dir .. fname)
	    break
	 else
	    print(appInfo.Name .. ": Cannot open csv file")
	    return
	 end
      end
   end

   
   --table.insert(runData, {count=runCounter, time=runTime, speed = speed, vario = vario,
   --                       elevPos = elevPos, elevTrim = elevTrim})

   print("fp, #runData:", fp, #runData)
   if fp then
      io.write(fp, "Run,RunTime,Speed,Vario,Elev Pos,Elev Trim\r\n")
      for i, line in ipairs(runData) do
	 io.write(fp, string.format("%d,%.4f,%.4f,%.4f,%.4f,%.4f\r\n",
				line.count, line.time, line.speed, line.vario,
				line.elevPos, line.elevTrim))
      end
   end

   io.close(fp)
   
end

local function annSwitchChanged(value)
   annSwitch = value
   system.pSave("annSwitch", annSwitch)
end

local function runSwitchChanged(value)
   runSwitch = value
   system.pSave("runSwitch", runSwitch)
end

local function spdSensorChanged(value)
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

local function varSensorChanged(value)
   varSe = value
   varSeId = sensorIdlist[varSe]
   varSePa = sensorPalist[varSe]
   if (varSeId == "...") then
      varSeId = 0
      varSePa = 0 
   end
   system.pSave("varSe", varSe)
   system.pSave("varSeId", varSeId)
   system.pSave("varSePa", varSePa)
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

local function imperialClicked(value)
   imperial = not value
   form.setValue(imperialIndex, imperial)
   system.pSave("imperial", tostring(imperial))
end

local function runLengthChanged(value)
   runLength = value / 10.0
   system.pSave("runLength", value)
end

-- Draw the main form (Application inteface)

local function initForm()

   form.addRow(2)
   form.addLabel({label="Airspeed", width=177})
   form.addSelectbox(sensorLalist, spdSe, true, spdSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Vario"})
   form.addSelectbox(sensorLalist, varSe, true, varSensorChanged, {alignRight=true})
   

   local outputs = {"O1", "O2", "O3", "O4", "O5", "O6", "O7", "O8", "O9", "O10", "O11",
		    "O12", "O13", "O14", "O15", "O16", "O17", "O18", "O19", "O20", "O21",
		    "O22", "O23", "O24"}
   local iout = 0
   for i in ipairs(outputs) do
      if outputs[i] == elevServo then
	 iout = i
	 break
      end
   end
   
   form.addRow(2)
   form.addLabel({label="Elevator Servo", width=220})
   form.addSelectbox(outputs, iout, true,
		     (function(val)
			   elevServo = outputs[val]
			   system.pSave("elevServo", elevServo) end))

   form.addRow(2)
   form.addLabel({label="Announcement Switch", width=220})
   form.addInputbox(annSwitch, true, annSwitchChanged)

   form.addRow(2)
   form.addLabel({label="Initiate Run Switch", width=220})
   form.addInputbox(runSwitch, true, runSwitchChanged)

   form.addRow(2)
   form.addLabel({label="Run length (secs)", width=220})
   form.addIntbox(runLength*10, 100, 1000, 300, 1, 1, runLengthChanged)

   form.addRow(2)
   form.addLabel({label="Short Announcements", width=270})
   shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   
   form.addRow(2)
   form.addLabel({label="Imperial / metric (x)", width=270})
   imperialIndex = form.addCheckbox(imperial, imperialClicked)

end

local dev = ""
local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    dev = sensor.label
	 else
	    table.insert(sensorLalist, dev.."-->"..sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
      
   end
end

local function rndInt(a)
   -- rounds to nearest int handles neg same as pos
   local sign = (a >= 0 and 1 or -1)
   return math.floor(a*sign + 0.5) * sign
end

local swrLast = 0

local function loop()

   local swa, swr
   local roundRat
   local spdSensor
   local varSensor
   local now
   local arg
   
   swa = system.getInputsVal(annSwitch)
   swr = system.getInputsVal(runSwitch)
   now = system.getTimeCounter()

   if now < 0 then print("now < 0") end
   
   if spdSeId ~= 0 then
      spdSensor = system.getSensorByID(spdSeId, spdSePa)
   end
   
   if varSeId ~= 0 then
      varSensor = system.getSensorByID(varSeId, varSePa)
   end

   --print("varSensor, spdSensor", varSensor.value, spdSensor.value)
   
   if spdSensor and varSensor and spdSensor.valid and varSensor.valid then
      speed = spdSensor.value
      vario = varSensor.value

      if swr and swr == 1 then
	 if swrLast ~= 1 then
	    runStartTime = now
	    runCounter = runCounter + 1
	    runTime = 0
	    lastTime = 0
	    print("starting run", runCounter)
	 end

	 local maxTrim = 0.5

	 if runTime and elevTrimCtrl then
	    elevTrim = maxTrim * runTime / runLength
	    system.setControl(elevTrimCtrl, elevTrim, 0)	    
	 end

	 local runDelta = runLength * 1000 / runPoints
	 --print("runTime, runStartTime, runDelta", runTime, runStartTime, runDelta)
	 if runTime then runTime = (now - runStartTime) / 1000.0 end
	 if runTime and (now > lastTime + runDelta) then
	    --if #runData < runPoints then
	    if runTime < runLength then
	       local elevPos
	       if elevServo then
		  elevPos = (system.getInputs(elevServo) or 0) * 100
	       else
		  elevPos = 0
	       end
	       
	       table.insert(runData, {count=runCounter, time=runTime, speed = speed, vario = vario,
	       elevPos = elevPos, elevTrim = elevTrim})
	       print("insert point", #runData, runTime, speed, vario, elevPos, elevTrim)
	       table.insert(x, speed)
	       table.insert(y, vario)
	       lastTime = now
	    else
	       print("run finished", runTime, runLength)
	       runFinished = true
	       runTime = nil
	       system.setControl(elevTrimCtrl, 0, 0)
	    end
	 end
      end
      swrLast = swr
      
      if math.abs(spdSensor.value / varSensor.value) < maxRatio then
	 arg = spdSensor.value*spdSensor.value - varSensor.value*varSensor.value
	 if arg > 0 then
	    glideRatio = math.sqrt(arg) / varSensor.value
	    --print(spdSensor.value, varSensor.value, arg, glideRatio)
	 else
	    glideRatio = spdSensor.value / varSensor.value
	 end
	 --sharedVar["DFM-GRat"].value[1] = glideRatio
      else
	 glideRatio = maxRatio -- not sure best thing to do here - set to large #,don't announce
	 --sharedVar["DFM-GRat"].value[1] = maxRatio
	 return
      end
   else
      --sharedVar["DFM-GRat"].value[1] = 0.0
      return
   end
   
   if glideRatio and swa == 1 and (system.getTimeCounter() - lastAnnTime > 2000) then
      lastAnnTime = now
      roundRat = rndInt(glideRatio)
      if (shortAnn) then
	 --print("Short ann: ", roundRat)
	 system.playNumber(roundRat, 0)
      else
	 --print("Long ann: ", roundRat)
	 system.playFile('/Apps/DFM-GRat/Ratio.wav', AUDIO_IMMEDIATE)	       
	 system.playNumber(roundRat, 0)
      end
   end


   
end

local function glideLog()
   local logval
   if not glideRatio then logval = 0 else logval = glideRatio end
   return logval, 1
end

local xmin, xmax = 10, 20
local ymin, ymax = -3,0

local xx = {46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70}
local yy = {-1.6,-1.45,-1.3,-1.15,-1.05,-0.95,-0.9,-0.85,-0.85,-0.85,-0.9,-0.925,
	      -0.95,-0.97,-1,-1.05,-1.15,-1.2,-1.3,-1.45,-1.65,-1.9,-2.2,-2.5,-2.8}

local function det3x3(mat)
   local det = 0
   det = det + mat[1][1] * (mat[2][2] * mat[3][3] - mat[2][3] * mat[3][2])
   det = det - mat[1][2] * (mat[2][1] * mat[3][3] - mat[2][3] * mat[3][1])
   det = det + mat[1][3] * (mat[2][1] * mat[3][2] - mat[2][2] * mat[3][1])
   return det
end

local function cp3x3(mt)
   local rt = { {}, {}, {} }
   for i=1,3 do
      for k=1,3 do
	 rt[i][k] = mt[i][k]
      end
   end
   return rt
end

local function parabFit(x, y)
   
   local sumx, sumy, sumx2, sumx3, sumx4, sumxy, sumx2y = 0,0,0,0,0,0,0
   local d1, d2, d3

   for i, xi in ipairs(x) do
      sumx = sumx + x[i]
      sumy = sumy + y[i]
      sumx2 = sumx2 + x[i]*x[i]
      sumx3 = sumx3 + x[i] * x[i] * x[i]
      sumx4 = sumx4 + x[i] * x[i] * x[i] * x[i]
      sumxy = sumxy + x[i]*y[i]
      sumx2y = sumx2y + x[i] * x[i] * y[i]
   end
   local mt = { {#x, sumx, sumx2}, {sumx, sumx2, sumx3}, {sumx2, sumx3, sumx4}}
   local dxt = cp3x3(mt)
   dxt[1][1] = sumy
   dxt[2][1] = sumxy
   dxt[3][1] = sumx2y
   d1 = det3x3(dxt) / det3x3(mt)
   dxt = cp3x3(mt)
   dxt[1][2] = sumy
   dxt[2][2] = sumxy
   dxt[3][2] = sumx2y
   d2 = det3x3(dxt) / det3x3(mt)
   dxt = cp3x3(mt)
   dxt[1][3] = sumy
   dxt[2][3] = sumxy
   dxt[3][3] = sumx2y
   d3 = det3x3(dxt) / det3x3(mt)
   return d1, d2, d3
end


local function parab(x, d1, d2, d3)
   if d1 and d2 and d3 then
      return d1 + d2 * x + d3 * x * x
   else
      return -1
   end
end

local function parabD(x, d1, d2, d3)
   if d1 and d2 and d3 then
      return d2 + 2*d3*x
   else
      return -1
   end
end

local function xp(v)
   local val = v --math.min(xmax, math.max(v, xmin))
   return 20 + 290 * (val - xmin) / (xmax - xmin)
end

local function yp(v)
   local val = v --math.min(ymax, math.max(v, ymin))  
   return 150 - 130 * (val - ymin) / (ymax - ymin)
end

local lastFit = 0
local d1, d2, d3
local dataMinX, dataMaxX

local function teleWindow(w,h)
   
   lcd.drawLine(20, 20, 20, 160)
   lcd.drawLine(20, 20, 320, 20)

   ---[[
   local str
   for v=xmin, xmax, 1 do
      str = string.format("%d", v)
      lcd.drawText(xp(v) - lcd.getTextWidth(FONT_MINI, str) /2, 5, str, FONT_MINI)
      lcd.drawLine(xp(v), 20, xp(v), 25)
   end

   for v = ymax, ymin, -0.5 do
      str = string.format("%.1f", v)
      lcd.drawText(15 - lcd.getTextWidth(FONT_MINI, str), yp(v) - lcd.getTextHeight(FONT_MINI)/ 2,
		   str, FONT_MINI)
      lcd.drawLine(20, yp(v), 25, yp(v))
   end

   
   if runCounter and runCounter > 0 then
      lcd.drawText(30,125, string.format("Run number: %d", runCounter), FONT_MINI)
   end

   if runTime then
      lcd.drawText(30,140, string.format("Running: %.1f/%d", runTime, runLength), FONT_MINI)
      local lx, ly = #x, #y
      if lx > 1 and ly > 1 then
	 lcd.drawText(130, 140, string.format("S: %.1f km/h, V: %.1f m/s", 3.6*x[lx], y[lx]), FONT_MINI)
      end

      lcd.drawFilledRectangle(310, 40, 2, 80)
      if elevTrim then
	 lcd.drawFilledRectangle(300, 40+elevTrim * 160, 10,2)
      end
   end
   
   --]]

   --[[
   for i,d in ipairs(runData) do
      lcd.drawFilledRectangle(xp(d.speed) - 2, yp(d.vario) - 2, 4, 4) 
   end
   --]]
   
   ---[[

   ---[[
   lcd.setColor(0,0,255)

   for i in ipairs(x) do
      if not dataMinX then dataMinX = x[i] end
      if not dataMaxX then dataMaxX = x[i] end      
      if x[i] < dataMinX then dataMinX = x[i] end
      if x[i] > dataMaxX then dataMaxX = x[i] end      
      
      lcd.drawRectangle(xp(x[i]) - 2, yp(y[i]) - 2, 4, 4)
      --if i == 25 then print(x[i], xp(x[i])) end
   end
   --]]
   local dv = 10 * system.getInputs("P1")
   local now = system.getTimeCounter()
   if runFinished == true then
      d1, d2, d3 = parabFit(x, y)
      print("Fit performed:", #x,  d1, d2, d3)
      lastFit = now
      runFinished = false
   end
   
   ---[[
   if d1 and d2 and d3 then

      local ren = lcd.renderer()
      ren:reset()
      lcd.setColor(120,120,120)
      local xl = dataMinX
      local yl = parab(xl, d1, d2, d3)
      --for a = xmin, xmax, (xmax-xmin) / 50 do
      local a = dataMinX
      local da = (dataMaxX - dataMinX) / 50
      while a <= dataMaxX + da do
	 ren:addPoint(xp(a), yp(parab(a, d1, d2, d3)))
	 --lcd.drawLine(xp(xl), yp(yl), xp(a), yp(parab(a, d1, d2, d3)))
	 --xl = a
	 --yl = parab(a, d1, d2, d3)
	 a = a + da
      end
      lcd.setColor(0,0,255)
      ren:renderPolyline(3)
      --]]
      
      local h = -d2 / (2 * d3)
      local k = parab(h, d1, d2, d3)
      local d = 0
      local stf = math.sqrt((d1-d)/d3)
      local m = 2*d3*stf + d2
      local x0 = 0
      local stfx = math.sqrt((d3*x0*x0 - d2*x0 + d1)/d3)
      local mx = 2*d3*stfx + d2 -2*d3*x0
      --print("stfx, mx", stfx, mx)
      local xw = -d/m
      
      lcd.setColor(0,0,0)
      lcd.drawText(30, 110, string.format("STF %.2f km/h", stf * 3.6), FONT_MINI)

      lcd.setColor(160,160,160)

      --draw vertex line vert
      lcd.drawLine(xp(h), 20, xp(h), 160)
      --draw vertex line horiz
      lcd.drawLine(20, yp(k), 320, yp(k))
      lcd.drawLine(20, yp(0), 320, yp(0))
      
      --draw stf line
      lcd.setColor(0,0,128)
      lcd.drawLine(xp(stf), 20, xp(stf), 160)
      
      --draw tangent line
      lcd.setColor(128,0,0)
      local xt = stf
      local yt = parab(stf)
      ren:reset()
      ren:addPoint(xp(xmin), yp(m*xmin+d))
      ren:addPoint(xp(xmax), yp(m*xmax+d))
      ren:renderPolyline(1)
      --lcd.drawLine(xp(xmin), yp(m*xmin + d), xp(xmax), yp(m*xmax+d))
   end
   
   --]]

   --[[
   local gtext, stext, vtext
   if glideRatio and math.abs(glideRatio) < 1000 then
      gtext = string.format("Ratio %.1f", rndInt(glideRatio))
   else
      gtext = "---"
   end
   local sunit = imperial and "mph" or "m/s"
   local vunit = imperial and "ft/s" or "m/s"
   stext = string.format("Airspeed %.1f " .. sunit, speed * (imperial and 2.23694 or 1) )
   vtext = string.format("Vario %.1f " .. vunit, vario * (imperial and 3.28084 or 1) )
   lcd.drawText(5,3, gtext,FONT_BOLD)
   if h > 24 then
      lcd.drawText(5,23,stext,FONT_BOLD)
      lcd.drawText(5,43,vtext,FONT_BOLD)
   end
   --]]
   local cc = system.getCPU()
   lcd.drawText(300, 140, cc, FONT_MINI)
end

local function destroy()
   print("DFM-Polr: destroy called")
   writeCSV()
end

local function init()

   annSwitch   = system.pLoad("annSwitch")
   runSwitch   = system.pLoad("runSwitch")   
   shortAnn    = system.pLoad("shortAnn", "false")
   imperial    = system.pLoad("imperial", "true")
   spdSe       = system.pLoad("spdSe", 0)
   spdSeId     = system.pLoad("spdSeId", 0)
   spdSePa     = system.pLoad("spdSePa", 0)
   varSe       = system.pLoad("varSe", 0)
   varSeId     = system.pLoad("varSeId", 0)
   varSePa     = system.pLoad("varSePa", 0)
   runLength   = system.pLoad("runLength", 300)
   runLength = runLength / 10.0
   elevServo   = system.pLoad("elevServo")
   
   readSensors()

   shortAnn = (shortAnn == "true") -- convert back to boolean here
   imperial = (imperial == "true")
   
   lastAnnTime = 0
   
   system.registerLogVariable("GlideRatio", "", glideLog)
   system.registerForm(1, MENU_APPS, "Glide Ratio Announcer", initForm)
   system.registerTelemetry(1, "Glide Ratio", 4, teleWindow)

   --table.insert(sharedVar["DFM-GRat"].label, "GlideRatio")
   --table.insert(sharedVar["DFM-GRat"].value, 0.0)
   --table.insert(sharedVar["DFM-GRat"].unit, "")
   --table.insert(sharedVar["DFM-GRat"].dp, 0)

   --[[
   local noise = 0.0
   for i in ipairs(xx) do
      x[i] = xx[i] * 10/36 + noise * (math.random() - 0.5)
      y[i] = yy[i] + noise * (math.random() - 0.5)
      print(i, x[i], y[i])
   end
   --]]
   
   for i=1,10,1 do
      elevTrimCtrl = system.registerControl(1, "Polar Elevator Trim", "PolE")
      if elevTrimCtrl then
	 system.setControl(elevTrimCtrl, 0, 0)
	 break
      end
   end

   if elevTrimCtrl then
      print("DFM-Polr: Elevator trim control " .. elevTrimCtrl)
   else
      print("DFM-Polr: Could not assign elevator trim control")
   end
   
end

return {init=init, loop=loop, author="DFM", version=tostring(GRatVersion),
	name="Glide Polar Analyzer", destroy=destroy}
