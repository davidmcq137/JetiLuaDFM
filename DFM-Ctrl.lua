--[[

   DFM-Ctrl.lua

   Exercise all flight controls while monitoring current drawn, alert
   pilot to potential issues such as control binding or improper
   motion.

   One full screen telemetry window to display live readings and a
   histogram of current draw

   Reads self-describing data file DFM-ModelName.lcs for control
   definitions and sequence of the test (example below)

   Released under MIT license by DFM 2019

   Todo: 
   
   Reminder to go to high rates before pushing button to start test?
   Put rate switch in model file so it can remind automatically?

   Incorporate a pre-flight check list? Encoded in lcs file? e.g. add'l tags 
   beyond dt? Challenge via audio file, respond w/button?

   TX info e.g. RSSI for all antennas? other info from system.getTxTelemetry()

   Other telemetry? Fuel state? Onboard batteries?

--]]

local appShort   = "DFM-Ctrl"
local appName    = "Controls AutoTest"
local appAuthor  = "DFM"
local appVersion = "1.1"

local lastStep
local step
local deltaTStep
local running

local stepName
local lastStepName
local maxAmps
local lastMaxAmps

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units
local sensorTylist = { "..." }  -- sensor Type

local batt_info = {"I Accu 1", "I Accu 2"}

local batt_id   = {0,0} -- hardcoded IDs for sensors related to batt current and mah
local batt_pa   = {0,0}
local batt_val  = {0,0}

local totalSumI
local totalN
local totalMaxI
local sampleSumI
local sampleMaxI

local startTime
local runningTime
local runningTimeSeconds
local totalTime
local graphScale
local redLineAmps

local xtable={}
local ytable={}
local wtable={}
local labels={}
local amps={}
local overamps={}
local exactX={}

local ctrlName={}
local ctrlMaxa={}
local ctrlValue={}
local ctrlStart={}
local ctrlDeltaT={}
local ctrlLastValue={}

local histogramWidth
local histogramX
local sumHisto

local checkIndex={}
local checkShow={}

-- We will use self-describing data per Lua book, 4th Ed chapter 15
-- These are the callback functions for the code in the .lcs file
-- (really just a lua file but with a unique name "lua control sequence"  - lcs)
-- the lcs is read in and executed with loadfile() in the init() function below

local CTRL_checkList = {}
function CTRL_cl(e)
   for k,v in ipairs(e) do CTRL_checkList[k] = v end
end

local CTRL_list = {}
function CTRL_l(e)
   for k,v in ipairs(e) do CTRL_list[k] = v end
end

local CTRL_name = {}
function CTRL_n(e)
   for k,v in ipairs(e) do CTRL_name[k] = v end
end

local CTRL_shortName = {}
function CTRL_sn(e)
   for k,v in ipairs(e) do CTRL_shortName[k] = v end
end

local CTRL_lines = {}
local CTRL_steps = {}
function CTRL_st(e)
   for k,v in ipairs(e) do CTRL_lines[k] = v end
end

-- Read available sensors for user to select - done once at startup
-- Capture battery sensor IDs as specified in batt_info
-- Additionally look for the telemetry labels in <batt_info>, note id & param

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLalist, sensor.label)
	 for j, _ in ipairs(batt_info) do 
	    if sensor.label == batt_info[j] then
	       batt_id[j] = sensor.id
	       batt_pa[j] = sensor.param
	    end
	 end
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
	 table.insert(sensorUnlist, sensor.unit)
	 table.insert(sensorTylist, sensor.type)
      end
   end
end

-- main forms interface callbacks

local function testStartSwChanged(value)
   testStartSw = value
   system.pSave("testStartSw",value)
end

local function graphScaleChanged(value)
   graphScale = value / 10
   system.pSave("graphScale", value)
end

local function redLineAmpsChanged(value)
   redLineAmps = value / 10
   maxAmps = redLineAmps
   --print("set maxAmps to:", maxAmps)
   system.pSave("redLineAmps", value)
end

-- Draw the main form (Application inteface)

local function initForm()

   form.addRow(2)
   form.addLabel({label="Test start switch/button",font=FONT_NORMAL, width=220})
   form.addInputbox(testStartSw, false, testStartSwChanged)
   
   form.addRow(2)
   form.addLabel({label="Graph Scale (Amps)", width=220})
   form.addIntbox(graphScale*10, 0, 200, 100, 1, 1, graphScaleChanged)

   form.addRow(2)
   form.addLabel({label="Red line current (Amps)", width=220})
   form.addIntbox(redLineAmps*10, 0, 200, 100, 1, 1, redLineAmpsChanged)

   form.addRow(1)
   form.addLabel({label="Version " .. appVersion .." ",font=FONT_MINI, alignRight=true})

end

local function checkClicked(val, i)
   print("focused row:", form.getFocusedRow())
   checkShow[i] = not val
   form.setValue(checkIndex[i], checkShow[i])
   form.setFocusedRow(math.min(i+1, #CTRL_checkList))
   if i >= #CTRL_checkList then
      print("i>")
      form.close()
      system.unregisterForm(1)
      system.registerForm(1,MENU_APPS, appName, initForm, nil, nil)      
   end
   
end

local function initCheckListForm()
   for i = 1, #CTRL_checkList, 1 do
      checkShow[i] = false
      form.addRow(2)
      form.addLabel({label=i..".  "..CTRL_checkList[i].lbl .. " " .. CTRL_checkList[i].msg, width=270})
      checkIndex[i] = form.addCheckbox(checkShow[i], (function(x) return checkClicked(x,i) end))
   end
   form.addRow(1)
   form.addLabel({label="Version " .. appVersion .." ",font=FONT_MINI, alignRight=true})
end


-- convenience functions

local function pixFromAmps(a)
   return math.floor(math.max(math.min(a / (graphScale) * 60, 60), 0))
end

local function round1(x)
   return math.floor(x*10 + 0.5) / 10.0
end

local function vertHistogram(x0, y0, val, scale, hgt, wid, vald)

   lcd.setColor(0,0,0)
   
   lcd.drawRectangle(x0 - wid/2, y0 - hgt, wid, 2*hgt - 1)
   lcd.drawLine(x0 - wid/2, y0, x0 + wid/2 - 1, y0)
   
   local a = math.min(math.abs(val) / scale, 1)

   if val > 0 then
      lcd.setColor(0,255,0)
      lcd.drawFilledRectangle(x0 - wid/2, y0 - hgt * a+1, wid, hgt * a)
   else
      lcd.setColor(255,0,0)
      lcd.drawFilledRectangle(x0 - wid/2, y0, wid, hgt * a)
   end
   lcd.setColor(0,0,0)

   if vald then
      lcd.drawText(x0+wid, y0 -lcd.getTextHeight(FONT_BOLD)/2, string.format("%4.1f", vald), FONT_BOLD)
   end
   
   lcd.drawText(x0 + wid - 5, y0 - hgt, string.format("+%d", scale), FONT_MINI)
   lcd.drawText(x0 + wid - 5, y0 + hgt - lcd.getTextHeight(FONT_MINI), string.format("-%d", scale), FONT_MINI)   
   
end

-- Telemetry window draw functions

local ww1max, ww2max = 0, 0
local aa1max, aa2max = 0, 0

local function timePrint(wid, hgt, isel)

   local mm, rr
   local pts
   local fstr
   local ww, ss

   
   lcd.setColor(0,0,0)
   --lcd.drawText(10,10,isel)

   lcd.drawRectangle(2, 133, 150, 10)
   lcd.drawRectangle(3+150, 133, 149, 10)
   
   ww = math.floor(batt_val[1]/(graphScale/2)*149.0)
   ww = math.max(math.min(146, ww), 0)
   
   if ww > ww1max then ww1max = ww end
   if batt_val[1] > aa1max then aa1max = batt_val[1] end
   
   -- draw horizontal bar graphs for battery current
   lcd.setColor(0, 0, 200)
   lcd.drawFilledRectangle(4-1, 133, ww, 10, 200)
   lcd.setColor(200, 0, 0)
   lcd.drawFilledRectangle(4-1+ww1max, 133, 3, 10)
   
   lcd.setColor(0, 0, 0)
   ss = string.format("Bat 1 Max: %2.1f A", aa1max)
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(50+(50-ww)/2+1,145, ss, FONT_MINI)
   
   ww = math.floor(batt_val[2]/(graphScale/2)*149.0)
   ww = math.max(math.min(145, ww), 0)
   if ww > ww2max then ww2max = ww end
   if batt_val[2] > aa2max then aa2max = batt_val[2] end
   
   lcd.setColor(0, 0, 200)
   lcd.drawFilledRectangle(300-ww, 133, ww+1, 10, 200)
   lcd.setColor(200, 0, 0)
   lcd.drawFilledRectangle(300-ww2max-3, 133, 3, 10)
   lcd.setColor(0, 0, 0)
   ss = string.format("Bat 2 Max: %2.1f A", aa2max)
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(175+(75-ww)/2+2,145, ss, FONT_MINI)

   -- now compute and display runtime and steps
   if runningTimeSeconds and runningTimeSeconds > 0 then
      mm, rr = math.modf(runningTimeSeconds/60)
      pts = string.format("Time: %02d:%02d", math.floor(mm), math.floor(rr*60))
   else pts = string.format("---", 0, 0) end

   if running or step == totalSteps then
      fstr = string.format("Step: %d/%d", math.floor(step), math.floor(totalSteps))
   else
      fstr = '---'
   end

   -- first draw the three panel box at top of screen
   lcd.drawRectangle(2,15,300,40)
   lcd.drawLine(100+2, 15, 100+2, 54)
   lcd.drawLine(200+2, 15, 200+2, 54)
   
   ww = lcd.getTextWidth(FONT_NORMAL, pts)
   lcd.drawText(5+(100-ww)/2-1,15,pts, FONT_NORMAL)

   ww = lcd.getTextWidth(FONT_NORMAL, fstr)
   lcd.drawText(5+(100-ww)/2-1,15 + 18,fstr, FONT_NORMAL)
   
   if sampleSumI then
      ss = string.format("%.1f", sampleSumI)
   else ss = "---" end

   if sampleSumI and maxAmps and sampleSumI > maxAmps then
      lcd.setColor(255,0,0)
   else lcd.setColor(0,0,0) end
   
   ww = lcd.getTextWidth(FONT_MAXI, ss)
   lcd.drawText(100+5+(100-ww)/2-1,15,ss, FONT_MAXI)
   lcd.setColor(0,0,0)
   
   if totalN and totalN ~= 0 then
      ss = string.format("Avg: %.1f", round1(totalSumI / totalN) )
   else ss = "---" end
   
   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(200+5+(100-ww)/2-1,15,ss, FONT_NORMAL)

   if totalMaxI then
      ss = string.format("Max: %.1f", round1(totalMaxI) )
   else ss = "---" end
   
   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(200+5+(100-ww)/2-1,15 + 18,ss, FONT_NORMAL)

   ww = lcd.getTextWidth(FONT_MINI, "Time/Step")
   lcd.drawText(5+(100-ww)/2,2,"Time/Step", FONT_MINI)
   
   ww = lcd.getTextWidth(FONT_MINI, "Inst Current (A)")
   lcd.drawText(100+5 + (100-ww)/2,2,"Inst Current (A)", FONT_MINI)
   
   ww = lcd.getTextWidth(FONT_MINI, "Current (A)")
   lcd.drawText(200+5+(100-ww)/2,2,"Current (A)", FONT_MINI)
   
   if isel == 1 then
      -- now draw the large box for the bar graph
      lcd.drawRectangle(2, 70, 300, 60)
      
      local iv = 70
      local ivd = 4
      local ivdt
      
      -- draw vertical dashed lines
      while iv <= 130 do
	 if iv + ivd > 130 then ivdt = 130 - 1 else ivdt = iv + ivd - 1 end
	 lcd.drawLine(75+2, iv, 75+2, ivdt)
	 lcd.drawLine(150+2, iv, 150+2, ivdt)
	 lcd.drawLine(225+2, iv, 225+2, ivdt)
	 iv = iv + 2*ivd
      end
      
      -- draw horizontal dashed lines
      local ih = 2
      local ihd = 4
      local ihdt
      
      while ih <= 300 do
	 if ih + ihd > 300 then ihdt = 300 else ihdt = ih + ihd end
	 lcd.drawLine(ih, 70+60/2, ihdt, 70+60/2)
	 ih = ih + 2*ihd
      end
      
      ss = string.format("Graph Scale (A): %.1f", graphScale)
      ww = lcd.getTextWidth(FONT_MINI, ss)
      lcd.drawText(75 - ww/2,70-15, ss, FONT_MINI)
      
      if maxAmps then
	 ss = string.format("Hi Current Limit (A): %.1f", maxAmps)
	 ww = lcd.getTextWidth(FONT_MINI, ss)
	 lcd.drawText(225 - ww/2,70-15, ss, FONT_MINI)
      end
      
      lcd.setColor(0,0,200)
      
      local iy, xc
      --draw the current histogram
      for ix = 1, #ytable, 1 do
	 iy = pixFromAmps(ytable[ix])
	 -- make sure last histo lines up w/edge of window
	 if ix  == totalSteps then
	    xc = (xtable[ix] + wtable[ix]) - 300
	 else
	    xc = 0
	 end
	 if overamps[ix] == true then
	    lcd.setColor(255,0,0)
	 else
	    lcd.setColor(0,0,200)
	 end
	 lcd.drawFilledRectangle(2+xtable[ix], 130-iy, wtable[ix]-xc, iy, 200)
      end
      
      -- draw label for each step section if defined
      lcd.setColor(0,0,200)
      if #labels > 0 then
	 for i=1, #labels, 1 do
	    if labels[i].text ~= "---" then
	       lcd.drawText(labels[i].x + 0, labels[i].y, labels[i].text, FONT_MINI)
	    end
	 end
      end
      
      -- draw red line for max amps if defined for this step section
      lcd.setColor(200, 0, 0)
      if #amps > 0 and maxAmps < graphScale then
	 for i=1, #amps, 1 do
	    lcd.drawLine(2 + amps[i].x0, 130 - pixFromAmps(amps[i].y0),
			 math.min(2 + amps[i].x1, 300), 130 - pixFromAmps(amps[i].y1))
	 end
      end
      
      -- draw green line for average value
      lcd.setColor(0,200,0)
      if totalN and totalN ~= 0 then
	 iy = (totalSumI / totalN) / (graphScale) * 60
	 iy = math.max(math.min(iy, 60), 1)
	 lcd.drawLine(2, 130-iy, 300, 130-iy)
      end
   else
      local sp, l, v, dt, ss
      sp = math.floor(300 / (#CTRL_list+1))
      if true then
	 if (step < 1) or (not running) then ss = "(---)" else ss = "("..stepName..")" end
	 lcd.setColor(0,0,255)
	 lcd.drawText(150 - lcd.getTextWidth(FONT_MINI, ss)/2,145, ss, FONT_MINI)
	 lcd.setColor(0,0,0)
	 for i = 1, #CTRL_list, 1 do
	    if ctrlValue and ctrlValue[i] then
	       --v = ctrlValue[i]
	       dt = system.getTimeCounter() - ctrlStart[i]
	       if dt > ctrlDeltaT[i] then
		  v = ctrlValue[i]
	       else
		  v = ctrlLastValue[i] +
		     dt * (ctrlValue[i] - ctrlLastValue[i]) / ctrlDeltaT[i]
	       end
	    else
	       v = 0
	    end
	    vertHistogram(2  + sp*i, 90, v, 1, 30, 10)
	    l = lcd.getTextWidth(FONT_MINI, CTRL_shortName[i], 3)
	    lcd.drawText(2 + sp*i - l/2, 120, CTRL_shortName[i], FONT_MINI)
	 end
      end
   end
end

--------------------------------------------------------------------------------

local function loop()
   local now
   local sensor
   local lbl={}
   local ampxy={}
   local ex
   local dx
   
   sampleSumI = 0
   for i=1, #batt_id, 1 do
      if batt_id[i] ~= 0 then
	 sensor = system.getSensorByID(batt_id[i], batt_pa[i])
	 if (sensor and sensor.valid) then
	    batt_val[i] = sensor.value
	    sampleSumI = sampleSumI + sensor.value
	 end
      end
   end

   if running then
      if not totalMaxI then totalMaxI = 0 end
      if sampleSumI > sampleMaxI then sampleMaxI = sampleSumI end -- gloabal max
      if sampleSumI > totalMaxI then totalMaxI = sampleSumI end   -- max in this histo
      totalSumI = totalSumI + sampleSumI
      totalN = totalN + 1
   end

   if not running then
      if system.getInputsVal(testStartSw) == 1 then
	 running = true
	 step = 0
	 lastStep = system.getTimeCounter()
	 startTime = lastStep
	 totalSumI = 0
	 totalN = 0
	 totalMaxI = 0
	 sampleMaxI = 0
	 ytable={}
	 xtable={}
	 wtable={}
	 labels={}
	 amps={}
	 overamps={}
	 histogramX = 0
	 ww1max = 0
	 ww2max = 0
	 aa1max = 0
	 aa2max = 0
	 lastStepName=nil
	 lastMaxAmps=nil
	 maxAmps = redLineAmps -- set to this if nothing in lcs file
	 sumHisto = 0
	 system.playFile("/Apps/"..appShort.."/Test_Starting.wav", AUDIO_QUEUE)
	 system.playFile("/Apps/"..appShort.."/Steps.wav", AUDIO_QUEUE)
	 system.playNumber(totalSteps, 0)
      else
	 return
      end
   end
   
   now = system.getTimeCounter()
   runningTime = now - startTime
   runningTimeSeconds = runningTime / 1000

   if now > lastStep + deltaTStep and step + 1 <= totalSteps  then
      -- over-write max I to be the max in the step section that has just finished
      -- to make sure we got any peaks during the section
      if #ytable > 0 then
	 ytable[#ytable] = sampleMaxI
      end
      
      -- and record it for the drawing function
      -- note same code below at end of sequence to catch end of last section
      -- won't get there because step >= totalSteps+1
      -- need a better way to structure it...
      if sampleMaxI < (maxAmps or 1000) and #overamps > 0 then
	 overamps[#overamps] = false
      else
	 overamps[#overamps] = true
      end
      
      if CTRL_steps[step+1].dt then
	 step = step + 1
	 deltaTStep = CTRL_steps[step].dt
	 stepName = CTRL_steps[step].sn
	 if CTRL_steps[step].maxa then
	    maxAmps = CTRL_steps[step].maxa
	 end
	 
	 -- compute trial histogram width
	 histogramWidth = math.floor(0.5 + (deltaTStep / totalTime * 300) )

	 -- see if the runing sum of histogram widths is tracking with the exact sum
	 -- of dt's - the pixel counts for histos have to be integers and errors accumulate
	 -- so make small periodic adjustments of 1 pixel to keep them in line
	 -- see how we are doing up to the prior step, then adjust this histo width
	 
	 if step > 1 then
	    ex = math.floor(0.5 + (exactX[step-1] / totalTime * 300))
	    if ex > sumHisto then dx =  1 elseif ex < sumHisto then dx = -1 else dx = 0 end
	 else dx = 0 end

	 histogramWidth = histogramWidth + dx
	 sumHisto = sumHisto + histogramWidth
	 
	 table.insert(xtable, #xtable+1, histogramX)
	 table.insert(ytable, #ytable+1, sampleMaxI)
	 table.insert(wtable, #wtable+1, histogramWidth)
	 table.insert(overamps, #overamps+1, false) -- set to true as needed at end of section
	 
	 if stepName ~= lastStepName then
	    lbl.text = stepName
	    lbl.x = histogramX
	    lbl.y = 70
	    table.insert(labels, #labels+1, lbl)
	    lastStepName = stepName
	 end

	 if maxAmps ~= lastMaxAmps then
	    ampxy.x0 = histogramX
	    ampxy.y0 = maxAmps
	    ampxy.x1 = histogramX + histogramWidth
	    ampxy.y1 = maxAmps
	    table.insert(amps, #amps+1, ampxy)
	    lastMaxAmps = maxAmps
	 else
	    if #amps > 0 then
	       amps[#amps].x1 = histogramX + histogramWidth
	       amps[#amps].y1 = maxAmps
	    end
	 end
	 
	 for i = 1, #CTRL_list, 1 do
	    if CTRL_steps[step][CTRL_shortName[i]] then
	       if not ctrlValue[i] then
		  ctrlLastValue[i] = 0
	       else
		  ctrlLastValue[i] = ctrlValue[i]
	       end
	       ctrlValue[i] = CTRL_steps[step][CTRL_shortName[i]]
	       ctrlStart[i] = system.getTimeCounter()
	       ctrlDeltaT[i] = deltaTStep
	       --print(step, i, CTRL_shortName[i], ctrlLastValue[i], ctrlValue[i], deltaTStep)
	       system.setControl(CTRL_list[i],
				 CTRL_steps[step][CTRL_shortName[i]],
				 deltaTStep, 0)
	    else
	       --print("else:step", step, i, deltaTStep)
	    end
	 end
      end
     
      stepName = CTRL_steps[step].sn
      --print(step, stepName)

      if step + 1 > totalSteps then
	 -- code below repeated from above .. to catch end of sequence
	 -- needs a better design
	 if #ytable > 0 then
	    ytable[#ytable] = sampleMaxI
	 end
	 if sampleMaxI < (maxAmps or 1000) and #overamps > 0 then
	    overamps[#overamps] = false
	 else
	    overamps[#overamps] = true
	 end
	 running = false
	 system.playFile("/Apps/"..appShort.."/Test_Complete.wav", AUDIO_QUEUE)
	 system.playFile("/Apps/"..appShort.."/Maximum_current.wav", AUDIO_QUEUE)
	 system.playNumber(round1(totalMaxI), 1, "A")
	 system.playFile("/Apps/"..appShort.."/Average_current.wav", AUDIO_QUEUE)
	 system.playNumber(round1(totalSumI / totalN), 1, "A")	 
      else
	 sampleMaxI = 0
	 histogramX = histogramX + histogramWidth
	 lastStep = now
      end
   end
end

local function init()

   local ctl
   local ctrlFn
   local ctrlFile
   local ctrlFunc
   local ctrlError
   
   ctrlFn = string.gsub(system.getProperty("Model")..".lcs", " ", "_")
   ctrlFile = "Apps/"..appShort.."/"..ctrlFn
   system.messageBox("DFM-Ctrl: " .. ctrlFile)
   print("DFM-Ctrl: attempting to open " .. ctrlFile)

   local ctrlFunc, ctrlError = loadfile(ctrlFile) 

   if not ctrlFunc then
      local ll = string.match(ctrlError, ":(.-):")
      system.messageBox("Error in " .. ctrlFn .. " line " .. (ll or "??") .. " - See console")
      print("DFM-Ctrl: " .. ctrlError)
      return
   else
      print("DFM-Ctrl: calling lcs file")
      ctrlFunc()
   end

   readSensors()

   if #CTRL_checkList > 0 then
      system.registerForm(1,0, appName, initCheckListForm, nil, nil)
   else
      system.registerForm(1,MENU_APPS, appName, initForm, nil, nil)
   end
   
   testStartSw = system.pLoad("testStartSw")
   graphScale = system.pLoad("graphScale", 100) / 10
   redLineAmps = system.pLoad("redLineAmps", 100) / 10
   
   for i = 1, #CTRL_list, 1 do
      ctl = CTRL_list[i]
      system.registerControl(ctl, CTRL_name[i], CTRL_shortName[i])
   end

   running = false
   totalSumI = 0
   totalN = 0
   lastStep = 0
   histogramX = 0
   maxAmps = nil
   
   totalTime = 0
   totalSteps = 0
   sumHisto = 0
   stepName = "---"
   
   for i = 1, #CTRL_lines, 1 do
      if CTRL_lines[i].maxa then maxAmps = CTRL_lines[i].maxa end
      if CTRL_lines[i].sn then
	 stepName = CTRL_lines[i].sn
	 table.insert(ctrlName, #ctrlName+1, stepName)
	 table.insert(ctrlMaxa, #ctrlMaxa+1, maxAmps)
      end
      if CTRL_lines[i].dt then
	 totalSteps = totalSteps + 1
	 CTRL_steps[totalSteps] = CTRL_lines[i]
	 CTRL_steps[totalSteps].sn = stepName
	 CTRL_steps[totalSteps].maxa = maxAmps
	 totalTime = totalTime + CTRL_steps[totalSteps].dt
	 exactX[totalSteps] = totalTime
      end
   end

   step = 0
   deltaTStep = CTRL_steps[step+1].dt

   for i=1, #CTRL_checkList, 1 do
      print(i, CTRL_checkList[i].lbl, CTRL_checkList[i].msg, CTRL_checkList[i].audio)
   end
   

   --for i = 1, #CTRL_list, 1 do
   --   ctl = CTRL_list[i]
   --   if not CTRL_steps[step+1][CTRL_shortName[i]] then
   --	 system.setControl(ctl, 0, 0, 0)
   --   else
   --	 system.setControl(ctl, CTRL_steps[step+1][CTRL_shortName[i]], 0, 0)
   --    end
   --end

   --for i = 0, #CTRL_list, 1 do -- start at 0 so we have a prev val for step 1
   --	 ctrlLastValue[i] = 0
   --end
      
   --system.registerTelemetry(1, appName.." - Histogram for Model: "..system.getProperty("Model"), 4,
   system.registerTelemetry(1, appName.." - Histogram: ".. ctrlFn, 4,
			    (function(x,y) return timePrint(x, y, 1) end))
   system.registerTelemetry(2, appName.." - Controls: " .. ctrlFn, 4,
			    (function(x,y) return timePrint(x, y, 2) end))   
end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name=appName, author=appAuthor, version=appVersion}

--[[

--
-- DFM-Test.lcs
-- self-describing lua data for Jeti Lua App DFM-CTRL.lua
-- example for Yellow F-18
--

-- CTRL_l is the list of lua controls to use. controls must be between 1-10
-- but can start at other than 1, skip etc. For example {2,3,4,5,6} or {3,7,8,9,10}
-- to account for other lua programs having pre-defined controls
-- all CTRL_x list will be traversed in the same order as this list

CTRL_l {
   5,6,7,8,9,10
}

-- long names of controls .. whatever you like, 31 char limit

CTRL_n {
       "Aileron", "Flap", "Rudder1", "Rudder2", "Elevator1", "Elevator2"
}

-- short names of controls, 3 chars max, names must match up with CTRL_st names

CTRL_sn {
   "Ail", "Flp", "Ru1", "Ru2", "El1", "El2"
}

-- control states for each time step, dt in ms, states must be -1..1
-- dt is time to next step
-- only have to specify changes after first step
-- rows can be in any order, and all controls can move in each row
-- controls in a row can be in any order
-- make dt 2x as long for -1 to 1 as for 0 to 1
-- sn is step section name, displayed on screen
-- can also add maxa=3.4 to the table with sn, e.g. {sn="Ail", maxa=3.4}
-- so that max amps limit is settable per sn

CTRL_st {

   {dt=500, Ail=0, Flp=1, Ru1=0, Ru2=0, El1=0, El2=0},

   {sn="Ail"},
   {dt=200,Ail=1 },
   {dt=600},
   {dt=200,Ail=0 },
   {dt=600},
   {dt=200,Ail=-1},
   {dt=600},
   {dt=200,Ail=0 },
   {dt=1000},

   {sn="Flp"},
   {dt=500, Fl1=0 },
   {dt=500},
   {dt=1500, Flp=-1},
   {dt=500},
   {dt=1500,Flp=1 },
   {dt=1000},

   {sn="Rud"},
   {dt=200, Ru1=-1,Ru2=-1},
   {dt=200},
   {dt=400,Ru1=1, Ru2=1 },
   {dt=200},
   {dt=200, Ru1=0, Ru2=0 },
   {dt=400},
   
   {dt=200, Ru1=-1,Ru2=1},
   {dt=200},
   {dt=400,Ru1=1, Ru2=-1},
   {dt=200},
   {dt=200, Ru1=0, Ru2=0 },
   {dt=400},

   {sn="Ele"},
   {dt=200, El1=1, El2=-1 },
   {dt=600},
   {dt=200, El1=0, El2=0},
   {dt=600},
   {dt=200,El1=-1, El2=1},
   {dt=600},
   {dt=200, El1=0, El2=0 },
   {dt=1000},
   
   {dt=200, El1=1, El2=1 },
   {dt=600},
   {dt=200,El1=0, El2=0},
   {dt=600},
   {dt=200,El1=-1, El2=-1},   
   {dt=600},
   {dt=200, El1=0, El2=0 },
   {dt=1000},

   {sn="All"},
   {dt=200, Ail=1,  Flp=0,  Ru1=-1, Ru2=-1, El1=-1, El2=1},
   {dt=600},
   {dt=200, Ail=0,  Flp=-1, Ru1=0,  Ru2=0,  El1=0,  El2=0},
   {dt=600},
   {dt=200, Ail=-1, Flp=0,  Ru1=1,  Ru2=1,  El1=1,  El2=-1},
   {dt=600},
   {dt=200, Ail=0,  Flp=1,  Ru1=0,  Ru2=0,  El1=0,  El2=0},
}

--]]
