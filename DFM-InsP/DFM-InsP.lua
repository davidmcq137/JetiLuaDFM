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

local messages = { "Turbine status: Ready",
		   "Turbine status: Starting",
		   "Turbine status: Running",
		   "Turbine status: Idle",
		   "Turbine status: Cooling",
		   "Turbine status: Off"}

msgidx = 1
nextTime =0

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

local function drawTextCenter(x, y, str, font)
   if not font then font = FONT_NORMAL end
   lcd.drawText(x - lcd.getTextWidth(font, str)/2,
		y - lcd.getTextHeight(font)/2, str, font)
end

local function drawShape(col, row, shape, f, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()
   local fw = f^0.55
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + (fw*point[1] * cosShape - f*point[2] * sinShape + 0.5),
	 row + (fw*point[1] * sinShape + f*point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end


local function loop()

end

local function printForm(wi, he)

   if InsP.backImg  then lcd.drawImage(0, 0, InsP.backImg) end
   if InsP.panelImg then lcd.drawImage(0, 0, InsP.panelImg) end

   local ctlr = system.getInputs("P5")
   local ctl = (ctlr+1)/2
   local rot = -0.75*math.pi * (1-ctl) + 0.75*math.pi*(ctl)
   local factor = 1.0

   
   ip = InsP.panels[1]
   for i, widget in ipairs(ip) do
      --print(widget.type)

      if widget.type == "roundGauge" then
	 lcd.setColor(255,255,255)
	 factor = widget.radius / 65.0
	 drawShape(widget.x0, widget.y0, needle_poly_large, factor, rot + math.pi)
	 local val = widget.min + (widget.max-widget.min) * ctl
	 if widget.radius > 30 then
	    drawTextCenter(widget.x0, widget.y0 + 1.0 * widget.radius - 15, "Testing", FONT_NORMAL)
	    --rawTextCenter(widget.x0, widget.y0 + 1.0 * widget.radius, "(mA)", FONT_MINI)
	    drawTextCenter(widget.x0, widget.y0 + 0.17 * widget.radius,
			   string.format("%.1f", val), FONT_MINI)
	 elseif widget.radius >= 20 then
	    drawTextCenter(widget.x0, widget.y0 + 0.25 * widget.radius,
			   string.format("%.1f", val), FONT_MINI)	    
	    drawTextCenter(widget.x0, widget.y0 + 1.0 * widget.radius - 8, "Test", FONT_MINI)
	 end

      elseif widget.type == "horizontalBar" then

	 lcd.setColor(0,0,0)
	 --lcd.setColor(200,200,200)
	 local hPad = widget.height / 4
	 local vPad = widget.height / 8
	 local start = widget.x0 - widget.width / 2 + hPad
	 local w = math.floor(widget.width - 2 * hPad + 0.5)
	 local h = math.floor(widget.height - 2 * vPad + 0.5)
	 local cellMult = 0.4
	 local cellOff = math.floor((1-cellMult) / 2 * h + 0.5)
	 lcd.drawFilledRectangle(start + ctl*(w+1)+1*(1-ctl), -1+widget.y0 - h/2 + cellOff,
				 math.floor((1-ctl)*(w+1)+0.5), math.floor(h*cellMult+0.5)+2)
	 lcd.setColor(255,255,255)
	 drawTextCenter(widget.x0, widget.y0+h/2-hPad/5, "Fuel Remaining", FONT_MINI)
      elseif widget.type == "textBox" then

	 lcd.setColor(0,0,0)
	 if system.getTimeCounter() > nextTime then
	    msgidx = msgidx + 1
	    if msgidx > #messages then msgidx = 1 end
	    nextTime = system.getTimeCounter() + 1000*2
	 end
	 
	 local str = messages[msgidx]
	 lcd.drawText(widget.x0 - lcd.getTextWidth(FONT_BOLD, str)/2,
		      widget.y0 - lcd.getTextHeight(FONT_BOLD)/2, str, FONT_BOLD)
	 
      else
      end
   end
end

local function prtForm(w,h)
   print(w,h)
   printForm(w,h)
   form.setTitle("")
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
	       --print("inserting panel", fn)
	       table.insert(InsP.panels, fn)
	       io.close(file)
	    end
	 end
      end
   end

   table.sort(InsP.panels)

   -- FOR TESTING  .. hardwire one test file .. json and image
   
   fn = pDir .. "/panel320.jsn"
   local file = io.readall(fn)
   InsP.panels[1] = json.decode(file)
   
   InsP.panelImg = lcd.loadImage(pDir .. "/panel320.png")
   InsP.backImg = lcd.loadImage(pDir .. "/cfimage.png")

   readSensors(InsP)

   system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm, prtForm)
   system.registerTelemetry(1, "Instrument Panel", 4, printForm)

   --if foo > 37 then print("foo") else print("bar") end
   
end

return {init=init, loop=loop, author="DFM", version="0", name="DFM-InsP", destroy=destroy}


