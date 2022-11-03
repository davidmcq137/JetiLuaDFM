--[[
   ----------------------------------------------------------------------
   DFM-F3G.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local F3GVersion = "0.01"

local subForm = 0
local emFlag
local loopCPU

local sensorLalist = { "..." }  -- sensor labels (long)
local sensorLslist = { "..." }  -- sensor labels (short)
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor units

local latSensor
local lngSensor

local savedRow
local savedRow2
local savedRow3

-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimG.jsn")
  local obj = json.decode(file)cd 
  if(obj) then
    trans11 = obj[lng] or obj[obj.default]
  end
--]]
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select - done once at startup

local function readSensors()

   local sensorLbl = "***"
   
   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    local ii = #sensorLalist+1
	    table.insert(sensorLslist, sensor.label) -- .. "[" .. ii .. "]")
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label) -- .. "["..ii.."]")
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	 end
      end
   end

end

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


local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   local row = form.getFocusedRow()
   if keyExit(key) then
   end
end

local function latSensorChanged(val)
   print("latSensor", val)
   latSensor = val
   system.pSave("latSensor", latSensor)
end

local function lngSensorChanged(val)
   print("lngSensor", val)
   lngSensor = val
   system.pSave("lngSensor", lngSensor)
end


local function initForm(sf)
   local str
   subForm = sf
   if sf == 1 then
      form.setTitle("Level 1 menu")

      form.addRow(2)
      form.addLabel({label="Latitude Sensor"})
      form.addSelectbox(sensorLalist, latSensor, true, latSensorChanged)

      form.addRow(2)
      form.addLabel({label="Longitude Sensor"})
      form.addSelectbox(sensorLalist, lngSensor, true, lngSensorChanged)
      
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 13 then
      form.setButton(3, ":edit", 1)
      form.setTitle(string.format("Level 2 menu %d", savedRow))

      if savedRow2 then form.setFocusedRow(savedRow2) end
      savedRow2 = 1
   elseif sf == 103 then
      form.setTitle(string.format("Level 3 menu %d", savedRow2))

      if savedRow3 then
	 form.setFocusedRow(savedRow3)
	 savedRow3 = nil
      else
	 form.setFocusedRow(1)
      end
   end
end

--------------------------------------------------------------------------------

local zeroPos
local curX, curY

local function loop()
   local sensor
   local curPos
   local lat, lng
   local minutes, degs
   local curDist, curBear

--local sensorLalist = { "..." }  -- sensor labels (long)
--local sensorLslist = { "..." }  -- sensor labels (short)
--local sensorIdlist = { "..." }  -- sensor IDs
--local sensorPalist = { "..." }  -- sensor parameters
--local sensorUnlist = { "..." }  -- sensor units

   if latSensor > 1 and lngSensor > 1 then

      curPos = gps.getPosition(sensorIdlist[latSensor], sensorPalist[latSensor], sensorPalist[lngSensor])
      if not zeroPos then zeroPos = curPos end

      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))
      --curX, curY = rotateXY(curX, curY, math.rad(variables.rotationAngle))
      --print("curDist, curBear", curDist, curBear)
      
   end

   loopCPU = system.getCPU()
end

local xmin, xmax, ymin, ymax = -800, 800, -400, 400

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function printTele()

   if curX and curY then
      --print(curX, curY)
      lcd.drawCircle(xp(curX), yp(curY), 4)
   end

   lcd.drawLine(xp(xmin), yp(0), xp(xmax), yp(0))
   lcd.drawLine(xp(0), yp(ymin), xp(0), yp(ymax))

end

local function init()
   
   local pf
   
   emFlag = select(2, system.getDeviceType()) == 1
   if emFlag then pf = "" else pf = "/" end

   latSensor = system.pLoad("latSensor", 1)
   lngSensor = system.pLoad("lngSensor", 1)
   
   system.registerForm(1, MENU_APPS, "F3G", initForm, keyForm)
   system.registerTelemetry(1, "F3G Display", 4, printTele)
   
   readSensors()
   
   setLanguage()
   
   print("DFM-F3G: gcc " .. collectgarbage("count"))
   
end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3GVersion, name="F3G"}
