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
local appVersion = "1.0"

local lastStep
local step
local deltaTStep
local running

local stepName
local lastStepName

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

local xtable={}
local ytable={}
local wtable={}
local labels={}

local histogramWidth
local histogramX
local ctrlFile

-- read in self-describing data per Lua book, 4th Ed chapter 15
-- these are the callback functions for the code in the .lcs file

local CTRL_list = {}
function CTRL_l(e)
   for k,v in ipairs(e) do
      CTRL_list[k] = v
   end
end

local CTRL_name = {}
function CTRL_n(e)
   for k,v in ipairs(e) do
      CTRL_name[k] = v
   end
end

local CTRL_shortName = {}
function CTRL_sn(e)
   for k,v in ipairs(e) do
      CTRL_shortName[k] = v
   end
end

local CTRL_lines = {}
local CTRL_steps = {}
function CTRL_st(e)
   for k,v in ipairs(e) do
      CTRL_lines[k] = v
   end
end

-- get model name, form the appropriate lcs filename
-- could do with some better error checking here... e.g if files don't exist

ctrlFile = "Apps/DFM-"..string.gsub(system.getProperty("Model")..".lcs", " ", "_")
system.messageBox("Reading " .. ctrlFile)
print("Reading " .. ctrlFile)

-- read/execute the lcs file -- should change to pcall with errorcode?
-- maybe easier to just let system handle...
dofile(ctrlFile)

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

-- Draw the main form (Application inteface)
local function initForm()

   form.addRow(2)
   form.addLabel({label="Test start switch/button",font=FONT_NORMAL, width=220})
   form.addInputbox(testStartSw, false, testStartSwChanged)
   
   form.addRow(2)
   form.addLabel({label="Graph Scale (Amps)", width=220})
   form.addIntbox(graphScale*10, 0, 200, 100, 1, 1, graphScaleChanged)

   form.addRow(1)
   form.addLabel({label="Version " .. appVersion .." ",font=FONT_MINI, alignRight=true})

end

-- Telemetry window draw functions
local ww1max, ww2max = 0, 0
local aa1max, aa2max = 0, 0

local function timePrint()

   local mm, rr
   local pts
   local fstr

   lcd.setColor(0,0,0)

   lcd.drawRectangle(2, 133, 150, 10)
   lcd.drawRectangle(3+150, 133, 149, 10)
   
   ww = math.floor(batt_val[1]/(graphScale/2)*149.0)
   ww = math.max(math.min(146, ww), 0)
   
   if ww > ww1max then
      ww1max = ww
   end
   if batt_val[1] > aa1max then
      aa1max = batt_val[1]
   end
   
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
   if ww > ww2max then
      ww2max = ww
   end
   if batt_val[2] > aa2max then
      aa2max = batt_val[2]
   end
   
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
   else
      pts = string.format("---", 0, 0)
   end

   if running or step == totalSteps then
      fstr = string.format("Step: %d/%d", math.floor(step), math.floor(totalSteps))
   else
      fstr = '---'
   end

   -- first draw the three panel box at top of screen
   lcd.drawRectangle(2,15,300,40)
   lcd.drawLine(100+2, 15, 100+2, 54)
   lcd.drawLine(200+2, 15, 200+2, 54)
   
   local ww, ss
   
   ww = lcd.getTextWidth(FONT_NORMAL, pts)
   lcd.drawText(5+(100-ww)/2-1,15,pts, FONT_NORMAL)

   ww = lcd.getTextWidth(FONT_NORMAL, fstr)
   lcd.drawText(5+(100-ww)/2-1,15 + 18,fstr, FONT_NORMAL)
   
   if sampleSumI then
      ss = string.format("%.1f", sampleSumI)
   else
      ss = "---"
   end

   ww = lcd.getTextWidth(FONT_MAXI, ss)
   lcd.drawText(100+5+(100-ww)/2-1,15,ss, FONT_MAXI)

   if totalN and totalN ~= 0 then
      ss = string.format("Avg: %.1f", totalSumI / totalN)
   else
      ss = "---"
   end
   
   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(200+5+(100-ww)/2-1,15,ss, FONT_NORMAL)

   if totalMaxI then
      ss = string.format("Max: %.1f", totalMaxI)
   else
      ss = "---"
   end
   
   ww = lcd.getTextWidth(FONT_NORMAL, ss)
   lcd.drawText(200+5+(100-ww)/2-1,15 + 18,ss, FONT_NORMAL)

   ww = lcd.getTextWidth(FONT_MINI, "Time/Step")
   lcd.drawText(5+(100-ww)/2,2,"Time/Step", FONT_MINI)
   
   ww = lcd.getTextWidth(FONT_MINI, "Inst Current (A)")
   lcd.drawText(100+5 + (100-ww)/2,2,"Inst Current (A)", FONT_MINI)
   
   ww = lcd.getTextWidth(FONT_MINI, "Current (A)")
   lcd.drawText(200+5+(100-ww)/2,2,"Current (A)", FONT_MINI)
   
   -- now draw the large box for the bar graph
   lcd.drawRectangle(2, 70, 300, 60)
   
   local iv = 70
   local ivd = 4
   local ivdt
   
   -- draw vertical dashed lines
   while iv <= 130 do
      if iv + ivd > 130 then
	 ivdt = 130 - 1
      else
	 ivdt = iv + ivd - 1
      end
      
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
      if ih + ihd > 300 then
	 ihdt = 300
      else
	 ihdt = ih + ihd
      end
      lcd.drawLine(ih, 70+60/2, ihdt, 70+60/2)
      ih = ih + 2*ihd
   end
   
   ss = string.format("Graph Scale: %.1f", graphScale)
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(150 - ww/2,70-15, ss, FONT_MINI)
   
   lcd.setColor(0,0,200)

   local iy, xc
   --draw the current histogram
   for ix = 0, #ytable-1, 1 do
      iy = ytable[ix+1] / (graphScale) * 60
      iy = math.floor(math.max(math.min(iy, 60), 0))
      -- print(ix+1, ytable[ix+1],iy)
      -- make sure last histo lines up w/edge of window
      if ix + 1 == totalSteps then 
	 xc = (2 + xtable[ix+1] + wtable[ix+1]) - 301
      else
	 xc = 0
      end
      lcd.drawFilledRectangle(2+xtable[ix+1], 130-iy, wtable[ix+1]-xc, iy, 150)
   end

   if #labels > 0 then
      for i=1, #labels, 1 do
	 if labels[i].text ~= "---" then
	    lcd.drawText(labels[i].x, labels[i].y, labels[i].text, FONT_MINI)
	 end
      end
   end

   -- draw green line for average value
   lcd.setColor(0,200,0)
   if totalN and totalN ~= 0 then
      iy = (totalSumI / totalN) / (graphScale) * 60
      iy = math.max(math.min(iy, 60), 1)
      lcd.drawLine(2, 130-iy, 300, 130-iy)
   end
   
end

--------------------------------------------------------------------------------

local function loop()
   local now
   local sensor
   local lbl={}
   
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
	 histogramX = 0
	 ww1max = 0
	 ww2max = 0
	 aa1max = 0
	 aa2max = 0
	 lastStepName=nil
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

   if now > lastStep + deltaTStep and step < totalSteps + 1 then
      if CTRL_steps[step+1].dt then
	 step = step + 1
	 deltaTStep = CTRL_steps[step].dt
	 stepName = CTRL_steps[step].sn
	 histogramWidth = math.floor(0.5 + deltaTStep / totalTime * 300)
	 table.insert(xtable, #xtable+1, histogramX)
	 table.insert(ytable, #ytable+1, sampleMaxI)
	 table.insert(wtable, #wtable+1, histogramWidth)

	 if stepName ~= lastStepName then
	    print("new label:", stepName)
	    lbl.text = stepName
	    lbl.x = histogramX
	    lbl.y = 70
	    print("ix, lbl.x, lbl.y:", ix,lbl.x, lbl.y)
	    table.insert(labels, #labels+1, lbl)
	    print("#labels:", #labels)
	    lastStepName = stepName
	 end

	 for i = 1, #CTRL_list, 1 do
	    if CTRL_steps[step][CTRL_shortName[i]] then
	       system.setControl(CTRL_list[i],
				 CTRL_steps[step][CTRL_shortName[i]],
				 deltaTStep, 0)
	    end
	 end
      end

      stepName = CTRL_steps[step].sn
      print(step, stepName)

      if step + 1 > totalSteps then
	 running = false
	 system.playFile("/Apps/"..appShort.."/Test_Complete.wav", AUDIO_QUEUE)
	 system.playFile("/Apps/"..appShort.."/Maximum_current.wav", AUDIO_QUEUE)
	 system.playNumber(totalMaxI, 1, "A")
	 system.playFile("/Apps/"..appShort.."/Average_current.wav", AUDIO_QUEUE)
	 system.playNumber(totalSumI / totalN, 1, "A")	 
      else
	 sampleMaxI = 0
	 histogramX = histogramX + histogramWidth
	 lastStep = now
      end
   end
end

local function init()

   local pcallOK, ctl
   
   pcallOK, emulator = pcall(require, "sensorEmulator")
   if pcallOK and emulator then emulator.init(appShort) end

   readSensors()

   system.registerForm(1,MENU_APPS, appName, initForm, nil, nil)
   
   testStartSw = system.pLoad("testStartSw")
   graphScale = system.pLoad("graphScale", 100) / 10
   
   for i = 1, #CTRL_list, 1 do
      ctl = CTRL_list[i]
      system.registerControl(ctl, CTRL_name[i], CTRL_shortName[i])
   end

   running = false
   totalSumI = 0
   totalN = 0
   lastStep = 0
   histogramX = 0
   
   
   totalTime = 0
   totalSteps = 0
   stepName = "---"
   
   --print("#CL:", #CTRL_lines)
   for i = 1, #CTRL_lines, 1 do
      if CTRL_lines[i].sn then stepName = CTRL_lines[i].sn end
      if CTRL_lines[i].dt then
	 totalSteps = totalSteps + 1
	 CTRL_steps[totalSteps] = CTRL_lines[i]
	 CTRL_steps[totalSteps].sn = stepName
	 totalTime = totalTime + CTRL_steps[totalSteps].dt
	 print(i, totalSteps, CTRL_lines[i].dt, CTRL_steps[totalSteps].dt, CTRL_steps[totalSteps].sn)
      end
   end

   step = 0
   deltaTStep = CTRL_steps[step+1].dt

   for i = 1, #CTRL_list, 1 do
      ctl = CTRL_list[i]
      system.setControl(ctl, CTRL_steps[step+1][CTRL_shortName[i]], 0, 0)
   end

   system.registerTelemetry(1, appName, 4, timePrint)
   
end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name=appName, author=appAuthor, version=appVersion}

--[[

-- Example lcs file

--
-- DFM.Test.lcs
-- self-describing lua data for Jeti Lua App DFM-CTRL.lua
--

-- CTRL_l is the list of lua controls to use. controls must be between 1-10
-- but can start at other than 1, skip etc. For example {2,3,4,5,6} or {3,7,8,9,10}
-- to account for other lua programs having pre-defined controls
-- all CTRL_x lists will be traversed in the same order as this list

CTRL_l {
   6,7,8,9
}

-- long names of controls .. whatever you like, 31 char limit

CTRL_n {
       "Aileron", "Flap", "Rudder", "Elevator"
}

-- short names of controls, 3 chars max, names must match up with CTRL_st names
-- same order as CTRL_n

CTRL_sn {
   "Ail", "Flp", "Rud", "Ele"
}

-- control states for each time step, dt in ms, states must be -1..1
-- dt is time to next step
-- only have to specify changes after first step
-- rows can be in any order, and all controls can move in each row
-- controls in a row can be in any order
-- make dt 2x as long for -1 to 1 as for 0 to 1

CTRL_st {
   {dt=500, Ail=0, Flp=1, Rud=0, Ele=0},
   
   {dt=500, Ail=1 },
   {dt=500},
   {dt=1000,Ail=-1},
   {dt=500},
   {dt=500, Ail=0 },
   {dt=1000},

   {dt=500, Flp=0 },
   {dt=500},
   {dt=500, Flp=-1},
   {dt=500},
   {dt=1000,Flp=1 },
   {dt=1000},
   
   {dt=500, Rud=-1},
   {dt=500},
   {dt=1000,Rud=1 },
   {dt=500},
   {dt=500, Rud=0 },
   {dt=1000},
   
   {dt=500, Ele=1 },
   {dt=500},
   {dt=1000,Ele=-1},
   {dt=500},
   {dt=500, Ele=0 },
   {dt=1000},
}

--]]
