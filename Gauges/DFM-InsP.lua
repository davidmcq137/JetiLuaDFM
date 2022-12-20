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
   
   local dd, fn, ext
   local path = prefix().."Apps/DFM-InsP/Panels"
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "jsn" then
	    local ff = path .. "/" .. fn .. "." .. ext
	    file = io.open(ff)
	    if file then
	       print("inserting panel", fn)
	       table.insert(insP.panels, fn)
	       file.close(ff)
	    end
	 end
      end
   end

   
   system.registerTelemetry(1, "test window", 4, printForm)

end

return {init=init, loop=loop, author="DFM", version="0", name="DFM-InsP"}


