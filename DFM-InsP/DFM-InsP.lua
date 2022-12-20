local InsP = {}

InsP.panels = {}

local needle_poly_large = {
   {-1,0},
   {-2,1},
   {-4,4},
   {-1,58},
   {1,58},
   {4,4},
   {2,1},
   {1,0}
}

local hSlider = {
   {0,0},
   {6,6},
   {-6,6}
}

local function readSensors(tt)
   local sensorLbl = "***"
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(tt.sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(tt.sensorIdlist, sensor.id)
	    table.insert(tt.sensorPalist, sensor.param)
	 end
      end
   end
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function drawShape(col, row, shape, f, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + (f*point[1] * cosShape - f*point[2] * sinShape + 0.5),
	 row + (f*point[1] * sinShape + f*point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

local function loop()

end

local function printForm()

   --if cfimg then lcd.drawImage(0, 0, cfimg) end
   --if gimg then lcd.drawImage(0, 0, gimg) end

end

local function init()

   -- first populate the table with all the panel json files
   -- in the Panels/ directory

   local pDir = "Apps/DFM-InsP/Panels"
   local dd, fn, ext
   local path = prefix() .. pDir
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "jsn" then
	    local ff = path .. "/" .. fn .. "." .. ext
	    local file = io.open(ff)
	    if file then
	       print("inserting panel", fn)
	       table.insert(InsP.panels, fn)
	       io.close(file)
	    end
	 end
      end
   end

   table.sort(InsP.panels)

   -- FOR TESTING  .. hardwire one test file
   
   fn = pDir .. "/test" .. ".jsn"
   local file = io.readall(fn)
   InsP.panels[1] = json.decode(file)
      
   readSensors(InsP)

   system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm)
   system.registerTelemetry(1, "test window", 4, printForm)

end

return {init=init, loop=loop, author="DFM", version="0", name="DFM-InsP", destroy=destroy}


