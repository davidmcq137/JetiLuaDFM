--[[

   DFM-Graph.lua

   Graphs Telemetry Sensors
   Demonstrator for sensorEmulator.lua but also generally useful
   
   Can also graph as points or as a line with anti-aliased polyline

   Discovered that with 150 points the renderer has issues .. backed
   off to 60 points which gives adequate resolution

   xbox is the width of the main screen in pixels
   ybox is the height of the main screen in pixels
   xboxWidth is the width of the histogram bars in pixels
   maxPoints is the number of histogram bars on the screen
   timeline is the span of the x axis in seconds

   To Do:

   Two sensor implementation is awful/literal - consider cleaner
   update to n sensors. Interesting challenge on dynamically extending
   form as each sensor is added - always need "one more" menu item for
   sensor N+1 ... but ... might run into "script killed" issue since
   usage for 2 graphs gets close to 50%. So perhaps 2 is a good place
   to sit for now.

   Released by DFM 10/2019 MIT License

--]]

--local pcallOK, emulator

local graphVersion = "1.0"
local appName = "Sensor Graph"
local appDir = "DFM-Graph"
local appAuthor = "DFM"

local graphStyle = {"Line", "Hazel","Point", "Histogram"}
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

local timeline

local histogram = {} -- table of values for "chart recorder" graph
local penDown = {}
local histogram2 = {} -- table of values for "chart recorder" graph
local penDown2 = {}
local x0, y0

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters

local oldModSec 
local runningTime 
local startTime
local nextsgTC 
local deltasg = 2000

local tpCPU = 0
local lpCPU = 0

local sensorLbl = "***"

-- xboxWidth, maxPoints, xbox, ybox must be integers
-- must have xbox = maxPoints * xboxWidth

local xbox = 300 -- main box width
local ybox = 150 -- main box height
local maxPoints = 60
local xboxWidth = 5 -- pixel width of histograms

local function readSensors()
   local sensors
   sensors = system.getSensors()
   --print("DFM-Graph - #sensors:", #sensors)
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

local function timelineChanged(value)
   timeline = value
   deltasg = timeline * 1000 / maxPoints
   system.pSave("timeline", value)
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
   penDown = {}
   histogram2 = {}
   penDown2 = {}

   oldModSec = 0
   nextsgTC = system.getTimeCounter()
   startTime = nextsgTC / 1000
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
   penDown = {}
   histogram2 = {}
   penDown2 = {}
   
   oldModSec = 0
   nextsgTC = system.getTimeCounter()
   startTime = nextsgTC / 1000
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
   
   form.addRow(2)
   form.addLabel({label="Timeline (seconds)", width=220})
   form.addIntbox(timeline, 30, 10000, 60, 0, 1, timelineChanged)

   form.addRow(1)
   form.addLabel({label="DFM - v."..graphVersion.." ", font=FONT_MINI, alignRight=true})
end

local count=0

local function dashLine(xp0, yp0, xp1, yp1)

   local d, ratio
   local xd0, xd1, yd0, yd1
   local dlen = 12
   ren = lcd.renderer()

   --d = math.abs(xp1-xp0) + math.abs(yp1-yp0)
   d = math.sqrt( (xp1-xp0)^2 + (yp1-yp0)^2 )
   ratio = d / dlen

   dx = (xp1-xp0) / ratio
   dy = (yp1-yp0) / ratio

   count = count + 1

   if d < dlen*.7 then -- 0.7 arbitrary chose to look best
      return
   end

   ren:reset()
   for i=1, math.floor(ratio+0.9), 1 do
      xd0 = xp0 + (i-1) * dx
      yd0 = yp0 + (i-1) * dy
      xd1 = xd0 + dx/2
      yd1 = yd0 + dy/2
      --xd1 = math.min(xp1, xd1)
      --yd1 = math.min(yp1, yd1)
      --print(i, d, ratio, xd0, yd0, xd1, yd1)
      ren:addPoint(xd0, yd0)
      ren:addPoint(xd1, yd1)
      ren:renderPolyline(2,0.4)
      ren:reset()
   end
end

local function timePrint()

   local xoff =     10 -- x offset from 0,0
   local yoff =      5 -- y offset from 0,0
   
   local mm, rr
   local mmm, rrr
   local ww, ss
   local yh
   local gv
   local ren = lcd.renderer()
   local xp, yp, lastDown
   local xup, yup, xdown, ydown
   
   -- make sure we are set to black
   lcd.setColor(0,0,0)

   -- draw graph titles - scale, time, sensor info
   mm, rr = math.modf(runningTime/60)
   mmm, rrr = math.modf(timeline/60)
   ss = string.format("Mode: %s  Runtime: %02d:%02d  Timeline %02d:%02d",
		      graphStyle[graphStyleIdx], math.floor(mm), math.floor(rr*60),
		      math.floor(mmm), math.floor(rrr*60) )
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
   --lcd.setClipping(xoff-1, yoff-1, xbox+4, ybox+4)
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
   
   if graphSeId ~= 0 then
      lcd.setColor(0,0,200)

      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
	 ren:reset()
      end

      lastDown = true
      x0, y0 = nil, nil
      
      for ix = 1, #histogram, 1 do
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
	 xp = xoff + xboxWidth*(ix-1)*maxPoints/(maxPoints-1)
	 xp = math.min(xbox + xoff, math.max(xoff, xp))
	 --squeeze so it fits .. otherwise last histogram box would go past xbox
	 if graphStyle[graphStyleIdx] == "Histogram" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, iy, 160)
	 elseif graphStyle[graphStyleIdx] == "Point" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, xboxWidth, 160)
	 else -- Line or Hazel
	    if penDown[ix] then
	       if lastDown == false then
		  lcd.drawCircle(xp, yp, 2) -- pen just went down after being up
		  xdown = xp
		  ydown = yp
		  if xup and yup then
		     dashLine(xup, yup, xdown, ydown)
		  end
	       end
	       ren:addPoint(xp, yp)
	    else
	       if lastDown then
		  if x0 and y0 then
		     lcd.drawCircle(x0, y0, 2)
		  end --pen just came up
		  ren:renderPolyline(2, 0.7)
		  ren:reset()
		  xup = x0
		  yup = y0
	       end
	    end
	    lastDown = penDown[ix]
	    x0 = xp
	    y0 = yp
	 end
      end
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then 
	 ren:renderPolyline(2, 0.7)
      end
   end
   

   if graphSeId2 ~= 0 then
      lcd.setColor(0,200,0)
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then
	 ren:reset()
      end
      
      lastDown = true
      x0, y0 = nil, nil

      for ix = 1, #histogram2, 1 do
	 if graphStyle[graphStyleIdx] == "Hazel" then
	    yh = histogram2[ix] % graphScale
	 else
	    yh = histogram2[ix]
	 end
	 local iy = yh / graphScale2*ybox
	 if iy > ybox then iy=ybox end
	 if iy < 1  then iy=1  end
	 yp = ybox - iy + yoff
	 yp = math.min(ybox + yoff, math.max(yoff, yp))      
	 xp = xoff + xboxWidth*(ix-1)*maxPoints/(maxPoints-1)
	 xp = math.min(xbox + xoff, math.max(xoff, xp))
	 --squeeze so it fits .. otherwise last histogram box would go past xbox
	 if graphStyle[graphStyleIdx] == "Histogram" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, iy, 160)
	 elseif graphStyle[graphStyleIdx] == "Point" then
	    lcd.drawFilledRectangle(xoff + (xp-xoff)*xbox/(xbox+xboxWidth),
				    yp, xboxWidth, xboxWidth, 160)
	 else -- Line or Hazel
	    if penDown2[ix] then
	       if lastDown == false then
		  lcd.drawCircle(xp, yp, 2) -- pen just went down after being up
		  xdown = xp
		  ydown = yp
		  if xup and yup then
		     dashLine(xup, yup, xdown, ydown)
		  end
	       end
	       ren:addPoint(xp, yp)
	    else
	       if lastDown then
		  if x0 and y0 then
		     lcd.drawCircle(x0, y0, 2)
		  end --pen just came up
		  ren:renderPolyline(2, 0.7)
		  ren:reset()
		  xup = x0
		  yup = y0
	       end
	    end
	    lastDown = penDown2[ix]
	    x0 = xp
	    y0 = yp
	 end
      end
      
      if graphStyle[graphStyleIdx] == "Line" or graphStyle[graphStyleIdx] == "Hazel" then 
	 ren:renderPolyline(2, 0.7)
      end
   end

   lcd.setColor(0,0,0)
   tpCPU = system.getCPU()
end

--------------------------------------------------------------------------------

local function loop()

   local sensor, sensor2
   local sgTC, tim
   local modSec, remSec
   local minutes, degs, latitude, longitude
   local x, y

   local lat0 = 41.0
   local long0 = -73
   local rE = 21220529.7

   sensor = system.getSensorByID(graphSeId, graphSePa)
   sensor2 = system.getSensorByID(graphSeId2, graphSePa2)   

   local minlat, minlon
   
   if sensor and sensor.valGPS and sensor.type == 9 and sensor.param == 3 then
      print("1/3")
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      minlon = minutes
      degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative 
	 longitude = longitude * -1
      end
   end

   if sensor and sensor.valGPS and sensor.type == 9 and sensor.param == 2 then
      print("1/2")
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      minlat = minutes
      degs = (sensor.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
      if sensor.decimals == 2 then -- "South" .. make it negative
	 latitude = latitude * -1
      end
   end

   if sensor2 and sensor2.valGPS and sensor2.type == 9 and sensor2.param == 3 then
      print("2/3")
      print("sensor.decimals2", sensor2.decimals)
      minutes = (sensor2.valGPS & 0xFFFF) * 0.001
      minlon = minutes
      degs = (sensor2.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor2.decimals == 3 then -- "West" .. make it negative
	 longitude = longitude * -1
      end
   end

   if sensor2 and sensor2.valGPS and sensor2.type == 9 and sensor2.param == 2 then
      print("2/2")
      minutes = (sensor2.valGPS & 0xFFFF) * 0.001
      minlat = minutes
      degs = (sensor2.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
      if sensor2.decimals == 2 then -- "South" .. make it negative
	 latitude = latitude * -1
      end
   end

   if longitude and latitude and minlat and minlon then
      print("Graph: latitude, longitude", latitude, longitude, minlat, minlon)
      x = rE * (math.rad(longitude) - math.rad(long0)) * math.cos(math.rad(lat0))
      y = rE * (math.rad(latitude) - math.rad(lat0))
      print("Graph: x,y", x,y)
   end

   
   if sensor and sensor.valid then
      if not x then
	 graphValue  = sensor.value
      else
	 graphValue = x
      end
      graphUnit = sensor.unit
   else
      graphValue = nil
   end
   

   if sensor2 and sensor2.valid then
      if not y then
	 graphValue2  = sensor2.value
      else
	 graphValue2 = y
      end
      graphUnit2 = sensor2.unit      
   else
      graphValue2 = nil
   end
   
   sgTC = system.getTimeCounter()
   tim = sgTC / 1000
   runningTime = tim - startTime
   modSec, remSec = math.modf(runningTime / 2) --2 secs per step

   --print(runningTime, modSec, remSec, oldModSec)

   if sgTC > nextsgTC then
      nextsgTC = nextsgTC + deltasg
      oldModSec = modSec

      if #histogram + 1 > maxPoints then
	 table.remove(histogram, 1)
	 table.remove(penDown, 1)
      end

      table.insert(histogram, #histogram+1, graphValue or 0)

      if graphValue then
	 table.insert(penDown, #penDown+1, true)
      else
	 table.insert(penDown, #penDown+1, false)
      end
      
      if #histogram2 + 1 > maxPoints then
	 table.remove(histogram2, 1)
	 table.remove(penDown2, 1)
      end

      table.insert(histogram2, #histogram2+1, graphValue2 or 0)

      if graphValue2 then
	 table.insert(penDown2, #penDown2+1, true)
      else
	 table.insert(penDown2, #penDown2+1, false)
      end
   end

   lpCPU = system.getCPU()
end

--------------------------------------------------------------------------------

local function init()

   local testLog = false

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

   timeline      = system.pLoad("timeline", 120)

   deltasg = timeline * 1000 / maxPoints
   oldModSec = 0
   nextsgTC = system.getTimeCounter()
   startTime = nextsgTC / 1000
   runningTime = startTime

   system.registerForm(1, MENU_APPS, appName, initForm)
   system.registerTelemetry(1, appName, 4, timePrint)
   
   readSensors()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author=appAuthor, version=graphVersion, name=appName}
