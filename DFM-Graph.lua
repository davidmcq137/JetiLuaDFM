--[[

   DFM-Graph.lua

   Graphs Telemetry Sensors

   Released by DFM 10/2019 MIT License

--]]

local graphVersion = "0.1"
local appName = "Sensor Graph"
local appDir = "DFM-Graph"

local graphSe, graphSeId, graphSePa

local graphScale
local graphValue
local graphName 
local graphUnit = '---'

local histogram = {} -- table of values for "chart recorder" graph

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters

local oldModSec 
local runningTime 
local startTime 

local lastLoopTime = 0
local avgLoopTime = 0
local loopCount = 0

local sensorLbl = "***"

local xbox =    300 -- main box width
local ybox =    150 -- main box height

local function readSensors()

   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
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

local function graphSensorChanged(value)

   graphSe = value
   graphSeId = sensorIdlist[graphSe]
   graphSePa = sensorPalist[graphSe]
   if (graphSeId == "...") then
      graphSeId = 0
      graphSePa = 0 
   end
   graphName = sensorLalist[graphSe]
   system.pSave("graphSe", value)
   system.pSave("graphSeId", graphSeId)
   system.pSave("graphSePa", graphSePa)
   system.pSave("graphName", graphName)
   system.pSave("graphScale", graphScale)
   system.pSave("graphUnit", graphUnit)
end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Select Sensor", width=220})
   form.addSelectbox(sensorLalist, graphSe, true, graphSensorChanged)
   
   form.addRow(2)
   form.addLabel({label="Vertical Scale", width=220})
   form.addIntbox(graphScale, 1, 10000, 100, 0, 1, graphScaleChanged)
   
   form.addRow(1)
   form.addLabel({label="DFM - v."..graphVersion.." ", font=FONT_MINI, alignRight=true})
end

local function timePrint()

   local xoff =     10 -- x offset from 0,0
   local yoff =      5 -- y offset from 0,0
   local xboxWidth = 2 -- pixel width of histograms

   local mm, rr
   local ww, ss

   -- make sure we are set to black
   lcd.setColor(0,0,0)

   -- draw graph titles - scale, time, sensor info
   ss = string.format("Vertical Scale: %d     Timeline 2:30",
		      math.floor(graphScale) )
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText(xbox/2-ww/2+1,yoff+2, ss, FONT_MINI)
   mm, rr = math.modf(runningTime/60)
   ss = string.format("Run Time: %02d:%02d   %s: %3.1f %s",
			     math.floor(mm), math.floor(rr*60),
			     graphName or " ", graphValue or 0, graphUnit or " ")
   ww = lcd.getTextWidth(FONT_MINI, ss)
   lcd.drawText((xbox-ww)/2-1,22,ss, FONT_MINI)
   
   -- draw main box for graph, double width lines
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
   
   -- now draw histogram
   lcd.setColor(0,0,200)
   for ix = 0, #histogram-1, 1 do
      local iy =histogram[ix+1]/graphScale*ybox
      if iy > ybox then iy=ybox end
      if iy < 1  then iy=1  end
      lcd.drawFilledRectangle(xoff+xboxWidth*ix, ybox-iy+yoff, xboxWidth, iy, 160)
   end 

   lcd.setColor(180,180,180)
   lcd.drawText(xbox-62, ybox-10, string.format("Loop time: %d", avgLoopTime), FONT_MINI)
   lcd.setColor(0,0,0)
   
end

local function keypress()
end

local function printform()
end

--------------------------------------------------------------------------------

local function loop()

   local sensor
   local sgTC, tim
   local modSec, remSec
   local maxPoints = 150
   
   sensor = system.getSensorByID(graphSeId, graphSePa)

   if sensor and sensor.valid then
      graphValue  = sensor.value
      graphUnit = sensor.unit
   end

   sgTC = system.getTimeCounter()
   tim = sgTC / 1000
   runningTime = tim - startTime
   modSec, remSec = math.modf(runningTime)
   
   if modSec ~= oldModSec then
      oldModSec = modSec
      if graphValue then
	 if #histogram + 1 > maxPoints then
	    table.remove(histogram, 1)
	 end
	 table.insert(histogram, #histogram+1, graphValue)
      end
   end
  
   local newLoopTime = system.getTimeCounter()
   local loopDelta = newLoopTime - lastLoopTime

   lastLoopTime = newLoopTime

   if avgLoopTime ~=0 then
      avgLoopTime = avgLoopTime * 0.95 + 0.05* loopDelta
   else
      avgLoopTime = 1
   end

   loopCount = loopCount+1

   if loopCount > 100 then
      loopCount = 0
   end
end
--------------------------------------------------------------------------------
local function init()

   local pcallOK, emulator

   pcallOK, emulator = pcall(require, "sensorEmulator")
   if pcallOK and emulator then emulator.init(appDir) end

   oldModSec = 0
   startTime = system.getTimeCounter() / 1000
   runningTime = startTime
   
   graphSe      = system.pLoad("graphSe", 0)
   graphSeId    = system.pLoad("graphSeId", 0)
   graphSePa    = system.pLoad("graphSePa", 0)
   
   graphScale   = system.pLoad("graphScale", 10)
   graphName    = system.pLoad("graphName", "---")
   graphUnit    = system.pLoad("graphUnit", " ")
   
   system.registerForm(1, MENU_APPS, appName, initForm, keypress, printform)
   system.registerTelemetry(1, appName, 4, timePrint)
   
   readSensors()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=graphVersion, name=appName}
