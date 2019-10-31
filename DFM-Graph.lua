--[[

   DFM-Graph.lua

   Graphs Telemetry Sensors
   Demonstrator for sensorEmulator.lua but also generally useful
   
   Currently set for time span of 100s, derived from 100 histogram
   bars, one histogram bar per second. Each histogram bar is 3 pixels
   wide giving a 300 pixel wide window.

   Can also graph as points or as a line with anti-aliased polyline

   Discovered that with 150 points the renderer has issues .. backed
   off to 100 points

   xbox is the width of the main screen in pixels
   ybox is the height of the main screen in pixels
   xboxWidth is the width of the histogram bars in pixels
   maxPoints is the number of histogram bars on the screen

   To Do:

   Two sensor implementation is awful/literal - consider cleaner
   update to n sensors. Interesting challenge on dynamically extending
   form as each sensor is added - always need "one more" menu item for
   sensor N+1

   Released by DFM 10/2019 MIT License

--]]

local pcallOK, emulator

local graphVersion = "1.0"
local appName = "Sensor Graph"
local appDir = "DFM-Graph"
local appAuthor = "DFM"

local graphStyle = {"Histogram", "Point", "Line", "Hazel"}
local graphStyleIdx

local graphSe, graphSeId, graphSePa
local graphSe2, graphSeId2, graphSePa2

local graphScale
local graphScale2
local graphValue
local graphValue2
local graphName
local graphName2
local graphUnit = '---'
local graphUnit2 = '---'

local histogram = {} -- table of values for "chart recorder" graph
local histogram2 = {} -- table of values for "chart recorder" graph

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters

local oldModSec 
local runningTime 
local startTime

local tpCPU = 0
local lpCPU = 0

local sensorLbl = "***"

local xbox = 300 -- main box width
local ybox = 150 -- main box height
local maxPoints = 60
local xboxWidth = 5 -- pixel width of histograms

local function readSensors()

   local sensors = system.getSensors()

   for i, sensor in ipairs(sensors) do
      --print(i, type(sensor.id), type(sensor.param), type(sensor.label))
      --print(i, sensor.id, sensor.param, sensor.label)
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
   end
end

local function graphScaleChanged(value)
   graphScale = value
   system.pSave("graphScale", value)
end

local function graphScale2Changed(value)
   graphScale2 = value
   system.pSave("graphScale2", value)
end

local function graphSensorChanged(value)
   graphSe = value
   graphSeId = sensorIdlist[graphSe]
   graphSePa = sensorPalist[graphSe]
   if (graphSeId == "...") then
      graphSeId = 0
      graphSePa = 0 
      graphUnit = " "
      graphValue = nil
   end
   graphName = sensorLalist[graphSe]
   system.pSave("graphSe", value)
   system.pSave("graphSeId", graphSeId)
   system.pSave("graphSePa", graphSePa)
   system.pSave("graphName", graphName)
   system.pSave("graphScale", graphScale)
   system.pSave("graphUnit", graphUnit)
   -- clear histograms so both sensors will have same time origin
   histogram = {}
   histogram2 = {}

   oldModSec = 0
   startTime = system.getTimeCounter() / 1000
   runningTime = startTime
end


local function graphSensor2Changed(value)
   graphSe2 = value
   graphSeId2 = sensorIdlist[graphSe2]
   graphSePa2 = sensorPalist[graphSe2]
   if (graphSeId2 == "...") then
      graphSeId2 = 0
      graphSePa2 = 0
      graphUnit2 = " "
      graphValue2 = nil
   end
   graphName2 = sensorLalist[graphSe2]
   system.pSave("graphSe2", value)
   system.pSave("graphSeId2", graphSeId2)
   system.pSave("graphSePa2", graphSePa2)
   system.pSave("graphName2", graphName2)
   system.pSave("graphScale2", graphScale2)
   system.pSave("graphUnit2", graphUnit2)
   -- clear histograms so both sensors will have same time origin
   histogram = {}
   histogram2 = {}

   oldModSec = 0
   startTime = system.getTimeCounter() / 1000
   runningTime = startTime
end

local function graphStyleChanged(value)
   graphStyleIdx = value
   system.pSave("graphStyleIdx", graphStyleIdx)
end

local function initForm()
   form.addRow(2)
   form.addLabel({label="Select Sensor 1", width=170})
   form.addSelectbox(sensorLalist, graphSe, true, graphSensorChanged)
   
   form.addRow(2)
   form.addLabel({label="Vertical Scale 1", width=220})
   form.addIntbox(graphScale, 1, 10000, 100, 0, 1, graphScaleChanged)

   form.addRow(2)
   form.addLabel({label="Select Sensor 2", width=170})
   form.addSelectbox(sensorLalist, graphSe2, true, graphSensor2Changed)

   form.addRow(2)
   form.addLabel({label="Vertical Scale 2", width=220})
   form.addIntbox(graphScale2, 1, 10000, 100, 0, 1, graphScale2Changed)

   form.addRow(2)
   form.addLabel({label="Style", width=170})
   form.addSelectbox(graphStyle, graphStyleIdx, true, graphStyleChanged)
   
   form.addRow(1)
   form.addLabel({label="DFM - v."..graphVersion.." ", font=FONT_MINI, alignRight=true})
end

local x0, y0

local function timePrint()

   local xoff =     10 -- x offset from 0,0
   local yoff =      5 -- y offset from 0,0
   
   local mm, rr
   local ww, ss
   local xp, yp
   local yh
   local gv
   local ren = lcd.renderer()
   
   -- make sure we are set to black
   lcd.setColor(0,0,0)

   -- draw graph titles - scale, time, sensor info
   mm, rr = math.modf(runningTime/60)
   ss = string.format("Mode: %s  Runtime: %02d:%02d  Timeline 2:00",
		      graphStyle[graphStyleIdx], math.floor(mm), math.floor(rr*60))
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(xoff + xbox/2-ww/2+1,yoff+2, ss, FONT_MINI)

   lcd.setColor(120,120,120)

   ss = string.format("tpCPU, lpCPU: %02d%% %02d%%", tpCPU, lpCPU)
   lcd.drawText(180, 140, ss, FONT_MINI)

   if graphSeId ~= 0 then
      lcd.setColor(0,0,200)
      if graphValue then gv = string.format("%3.1f", graphValue) else gv = "---" end
      ss = string.format("%s: %s %s  Scale: %d",
			 graphName or " ",
			 gv, graphUnit or " ",
			 graphScale)
      
      ww = lcd.getTextWidth(FONT_MINI, ss)
      lcd.drawText(xoff + (xbox-ww)/2-1,yoff+17,ss, FONT_MINI)
   end

   if graphSeId2 ~= 0 then
      lcd.setColor(0,200,0)
      if graphValue2 then gv = string.format("%3.1f", graphValue2) else gv = "---" end
      ss = string.format("%s: %s %s  Scale: %d",
			 graphName2 or " ",
			 gv, graphUnit2 or " ",
			 graphScale2)
      
      ww = lcd.getTextWidth(FONT_MINI, ss)
      lcd.drawText(xoff + (xbox-ww)/2-1,yoff+32,ss, FONT_MINI)
   end
   
   -- draw main box for graph, double width lines
   -- absolute max: lcd.drawRectangle(0,1,318,158)

   lcd.setColor(0,0,0)
   lcd.drawRectangle(xoff, yoff, xbox, ybox)
   lcd.drawRectangle(xoff-1, yoff-1, xbox+2, ybox+2)

   -- draw vertical dashed lines in light gray
   lcd.setColor(200,200,200)
   local iv = 2
   local ivd = 4
   local ivdt
   while iv <= ybox do
      if iv + 2*ivd > ybox then
	 ivdt = ybox - 2
      else
	 ivdt = iv + ivd
      end
      lcd.drawLine(  xbox/4+xoff, iv+yoff, xbox/4+xoff  , ivdt+yoff)
      lcd.drawLine(  xbox/2+xoff, iv+yoff, xbox/2+xoff  , ivdt+yoff)
      lcd.drawLine(3*xbox/4+xoff, iv+yoff, 3*xbox/4+xoff, ivdt+yoff)
      iv = iv + 2*ivd
   end

   -- and horizontal dashed lines
   local ih = 2
   local ihd = 4
   local ihdt
   while ih <= xbox do
      if ih + 2*ihd > xbox then
	 ihdt = xbox - 2
      else
	 ihdt = ih + ihd
      end
      lcd.drawLine(ih+xoff, yoff+ybox/2, ihdt+xoff, yoff+ybox/2)
      ih = ih + 2*ihd
   end
   
   -- now draw graph
   lcd.setColor(0,0,200)

   if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
      --ren:reset()
   end

   for ix = 1, #histogram, 1 do
      if histogram[ix] ~= -999 then
	 if graphStyle[graphStyleIdx] == "Hazel" then
	    yh = histogram[ix] % graphScale
	 else
	    yh = histogram[ix]
	 end
	 local iy = yh / graphScale*ybox
	 if iy > ybox then iy=ybox end
	 if iy < 1  then iy=1  end
	 yp = ybox - iy + yoff
	 yp = math.min(ybox + yoff, math.max(yoff, yp))      
      else
	 yp = -999
      end
      xp = xoff + xboxWidth*(ix-1)*maxPoints/(maxPoints-1)
      xp = math.min(xbox + xoff, math.max(xoff, xp))
      if yp ~= -999 then
	 if graphStyle[graphStyleIdx] == "Histogram" then
	    lcd.drawFilledRectangle(xp, yp, xboxWidth, iy, 160)
	 elseif graphStyle[graphStyleIdx] == "Point" then
	    lcd.drawFilledRectangle(xp, yp, xboxWidth, xboxWidth, 160)
	 else -- Line or Hazel
	    if yp == -999 then
	       x0 = nil
	       y0 = nil
	    end
	    if x0 and y0 then
	       lcd.drawLine(x0, y0, xp, yp)
	    end
	    if yp ~= -999 then
	       x0 = xp
	       y0 = yp
	    end
	    --ren:addPoint(xp, yp)
	 end
      end
   end

   if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then 
      --ren:renderPolyline(2, 0.7)
   end
      

   if graphSeId2 ~= 0 then
      lcd.setColor(0,200,0)
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
	 ren:reset()
      end
      
      for ix = 1, #histogram2, 1 do
	 if histogram2[ix] ~= -999 then
	    if graphStyle[graphStyleIdx] == "Hazel" then
	       yh = histogram2[ix] % graphScale2
	    else
	       yh = histogram2[ix]
	    end
	    local iy = yh / graphScale2*ybox
	    if iy > ybox then iy=ybox end
	    if iy < 1  then iy=1  end
	    yp = ybox - iy + yoff
	    yp = math.min(ybox + yoff, math.max(yoff, yp))      
	 else
	    yp = -999
	 end
	 
	 xp = xoff + xboxWidth*(ix-1)*maxPoints/(maxPoints-1)
	 xp = math.min(xbox + xoff, math.max(xoff, xp))

	 if yp ~= -999 then
	    if graphStyle[graphStyleIdx] == "Histogram" then
	       lcd.drawFilledRectangle(xp, yp, xboxWidth, iy, 160)
	    elseif graphStyle[graphStyleIdx] == "Point" then
	       lcd.drawFilledRectangle(xp, yp, xboxWidth, xboxWidth, 160)
	    else -- Line or Hazel
	       ren:addPoint(xp, yp)
	    end
	 end
      end
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then 
	 ren:renderPolyline(2, 0.7)
      end
   end
   
   
   lcd.setColor(0,0,0)
   tpCPU = system.getCPU()
end

local function keypress()
end

local function printform()
end

--------------------------------------------------------------------------------

local function loop()

   local sensor, sensor2
   local sgTC, tim
   local modSec, remSec

   if pcallOK and emulator then
      if emulator.startUp(readSensors) then return end
   end
   
   sensor = system.getSensorByID(graphSeId, graphSePa)
   sensor2 = system.getSensorByID(graphSeId2, graphSePa2)   

   if sensor and sensor.valid then
      graphValue  = sensor.value
      graphUnit = sensor.unit
   else
      graphValue = nil
   end
   

   if sensor2 and sensor2.valid then
      graphValue2  = sensor2.value
      graphUnit2 = sensor2.unit      
   else
      graphValue2 = nil
   end
   
   sgTC = system.getTimeCounter()
   tim = sgTC / 1000
   runningTime = tim - startTime
   modSec, remSec = math.modf(runningTime / 2) --2 secs per step

   --print(runningTime, modSec, remSec, oldModSec)
   --nextPoint
   if modSec ~= oldModSec then
      oldModSec = modSec
      if true then -- graphValue then
	 if #histogram + 1 > maxPoints then
	    table.remove(histogram, 1)
	 end
	 table.insert(histogram, #histogram+1, graphValue or -999)
      end
      if true then -- graphValue2 then
	 if #histogram2 + 1 > maxPoints then
	    table.remove(histogram2, 1)
	 end
	 table.insert(histogram2, #histogram2+1, graphValue2 or -999)
      end
      
   end
   lpCPU = system.getCPU()
end

--------------------------------------------------------------------------------

local function init()

   pcallOK, emulator = pcall(require, "sensorLogEm")
   if not pcallOK then print("pcall error: ", emulator) end
   if pcallOK and emulator then emulator.init("sensorLogEm.jsn") end

   oldModSec = 0
   startTime = system.getTimeCounter() / 1000
   runningTime = startTime

   graphStyleIdx = system.pLoad("graphStyleIdx", 1)
   graphSe       = system.pLoad("graphSe", 1)
   graphSeId     = system.pLoad("graphSeId", 0)
   graphSePa     = system.pLoad("graphSePa", 0)
  
   graphSe2      = system.pLoad("graphSe2", 1)
   graphSeId2    = system.pLoad("graphSeId2", 0)
   graphSePa2    = system.pLoad("graphSePa2", 0)

   graphScale    = system.pLoad("graphScale", 100)
   graphName     = system.pLoad("graphName", "---")
   graphUnit     = system.pLoad("graphUnit", " ")
   
   graphScale2   = system.pLoad("graphScale2", 100)
   graphName2    = system.pLoad("graphName2", "---")
   graphUnit2    = system.pLoad("graphUnit2", " ")

   system.registerForm(1, MENU_APPS, appName, initForm, keypress, printform)
   system.registerTelemetry(1, appName, 4, timePrint)
   
   
   --readSensors()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author=appAuthor, version=graphVersion, name=appName}
