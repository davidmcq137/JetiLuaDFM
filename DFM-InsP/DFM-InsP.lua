local InsP = {}

InsP.panels = {}
InsP.sensorLalist = {"..."}
InsP.sensorLslist = {"..."}
InsP.sensorIdlist = {0}
InsP.sensorPalist = {0}
InsP.settings = {}

local subForm = 0
local pDir = "Apps/DFM-InsP/Panels"
local bDir = "Apps/DFM-InsP/Backgrounds"

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

local msgidx = 1
local nextTime =0

local function readSensors(tt)
   local sensorLbl = "***"
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(tt.sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(tt.sensorLslist, sensor.label)	    
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

local function changedSensor(val, i, ip)
   ip[i].SeId = InsP.sensorIdlist[val]
   ip[i].SePa = InsP.sensorPalist[val]
end

local function panelChanged(val)
   local fn
   InsP.settings.selPanel = InsP.settings.panels[val]
   fn = pDir .. "/"..InsP.settings.selPanel  ..".jsn"
   local file = io.readall(fn)
   InsP.panels[1] = json.decode(file)
   InsP.panelImg = lcd.loadImage(pDir .. "/"..InsP.settings.selPanel..".png")
end

local function backGndChanged(val)
   InsP.settings.selBack = InsP.settings.backgrounds[val]
   InsP.backImg = lcd.loadImage(bDir .. "/"..InsP.settings.selBack..".png")   
end

local function initForm(sf)

   subForm = sf

   if sf == 1 then

      form.addRow(2)
      form.addLabel({label="Sensor assignment >>", width=220})
      form.addLink((function()
	       form.reinit(100)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Settings >>", width=220})
      form.addLink((function()
	       form.reinit(102)
	       form.waitForRelease()
      end))      
      
      form.addRow(2)
      form.addLabel({label="Reset App data >>", width=220})
      form.addLink((function()
	       form.reinit(101)
	       form.waitForRelease()
      end))      

   elseif sf == 100 then

      local ip = InsP.panels[1]
      form.setTitle("Assign sensors to gauges")
      
      for i, widget in ipairs(ip) do
	 form.addRow(3)
	 local str
	 if widget.label then str = "  ("..widget.label..")" else str = "" end
	 local typ
	 if widget.type == "roundGauge" then
	    typ = "RndG"
	 elseif widget.type == "horizontalBar" then
	    typ = "HBar"
	 elseif widget.type == "textBox" then
	    typ = "Text"
	 else
	    typ = "---"
	 end
	 form.addLabel({label = string.format("%d %s", i, typ), width=60})
	 form.addLabel({label = string.format("%s", str), width=160})      
	 local id = widget.SeId
	 local pa = widget.SePa
	 local isel = 0
	 for k, _ in ipairs(InsP.sensorLalist) do
	    if id == InsP.sensorIdlist[k] and pa == InsP.sensorPalist[k] then
	       isel = k
	       break
	    end
	 end
	 form.addSelectbox(InsP.sensorLslist, isel, true,
			   (function(x) return changedSensor(x, i, ip) end),{width=100})
      end
   elseif sf == 101 then
      io.remove(InsP.fileBD)
      InsP.writeBD = false
      system.messageBox("Data deleted .. restart App")
      form.reinit(1)
   elseif sf == 102 then
      form.setTitle("Settings")
      form.addRow(2)
      form.addLabel({label="Instrument Panel"})
      local isel = 0
      if InsP.settings.panels then
	 for i, p in ipairs(InsP.settings.panels) do
	    if p == InsP.settings.selPanel then
	       isel = i
	       break
	    end
	 end
      else
	 InsP.settings.panels = {}
	 InsP.settings.panels[1] = "..."
      end
      
      form.addSelectbox(InsP.settings.panels, isel, true, panelChanged)

      form.addRow(2)
      form.addLabel({label="Background Image"})
      local isel = 0
      for i, p in ipairs(InsP.settings.backgrounds) do
	 if p == InsP.settings.selBack then
	    isel = i
	    break
	 end
      end
      form.addSelectbox(InsP.settings.backgrounds, isel, true, backGndChanged)      
   end
   
   
end


local function loop()

end

local function printForm(wi, he)

   if InsP.backImg  then
      lcd.drawImage(0, 0, InsP.backImg)
   else
      lcd.drawFilledRectangle(0,0,319,158)
   end

   if InsP.panelImg then lcd.drawImage(0, 0, InsP.panelImg) end

   local ctl 
   local rot 
   local factor = 1.0
   local sensor
   local ip = InsP.panels[1]
   
   for i, widget in ipairs(ip) do
      sensor = system.getSensorByID(widget.SeId, widget.SePa)
      if sensor and sensor.valid then
	 ctl = math.min(math.max((sensor.value - widget.min) / (widget.max - widget.min), 0), 1)
	 rot = -0.75*math.pi * (1-ctl) + 0.75*math.pi*(ctl)
      else
	 ctl = nil
      end
      if widget.type == "roundGauge" then
	 local val
	 lcd.setColor(255,255,255)
	 
	 if ctl then
	    factor = widget.radius / 65.0
	    drawShape(widget.x0, widget.y0, needle_poly_large, factor, rot + math.pi)
	    val = string.format("%.1f", widget.min + (widget.max-widget.min) * ctl)
	 else
	    val = "---"
	 end
	 local str
	 if widget.label then str = widget.label else str = "G#"..i end
	 if widget.radius > 30 then
	    drawTextCenter(widget.x0, widget.y0 + 1.0 * widget.radius - 15, str, FONT_MINI)
	    drawTextCenter(widget.x0, widget.y0 + 0.17 * widget.radius,
			   string.format("%s", val), FONT_MINI)
	 elseif widget.radius >= 20 then
	    drawTextCenter(widget.x0, widget.y0 + 0.25 * widget.radius,
			   string.format("%s", val), FONT_MINI)	    
	    drawTextCenter(widget.x0, widget.y0 + 1.0 * widget.radius - 8, str, FONT_MINI)
	 end

      elseif widget.type == "horizontalBar" and ctl then

	 lcd.setColor(0,0,0)
	 --lcd.setColor(200,200,200)
	 local hPad = widget.height / 4
	 local vPad = widget.height / 8
	 local start = widget.x0 - widget.width / 2 + hPad
	 local w = math.floor(widget.width - 2 * hPad + 0.5)
	 local h = math.floor(widget.height - 2 * vPad + 0.5)
	 local cellMult = 0.4
	 local cellOff = math.floor((1-cellMult) / 2 * h + 0.5)
	 if ctl then
	    lcd.drawFilledRectangle(start + ctl*(w+1)+1*(1-ctl), -1+widget.y0 - h/2 + cellOff,
				    math.floor((1-ctl)*(w+1)+0.5), math.floor(h*cellMult+0.5)+2)
	 end
	 lcd.setColor(255,255,255)
	 local str
	 if widget.label then str = widget.label else str = "G#"..i end
	 drawTextCenter(widget.x0, widget.y0+h/2-hPad/5, str, FONT_MINI)
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

local function keyForm(key)
end

local function prtForm(w,h)

end

local function destroy()
   local fp
   local save = {}

   if InsP.writeBD then
      save.panel1 = InsP.panels[1]
      save.settings = InsP.settings
      for k,v in ipairs(save.panel1) do
	 for kk,vv in pairs(v) do
	    if kk == "SeId" then v[kk] = string.format("0X%X", vv) end
	 end
      end
      fp = io.open(InsP.fileBD, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
end

local function init()

   -- First see if there is a saved file that has prior modification and additions
   
   local decoded
   local mn
   local file

   mn = string.gsub(system.getProperty("Model"), " ", "_")
   InsP.fileBD = prefix() .. "Apps/DFM-InsP/II_" .. mn .. ".jsn"
   file = io.readall(InsP.fileBD)
   if file then
      decoded = json.decode(file)
      InsP.panels[1] = decoded.panel1
      InsP.settings = decoded.settings
      if not InsP.settings then InsP.settings = {} end
      for k,v in ipairs(InsP.panels[1]) do
	 for kk,vv in pairs(v) do
	    if kk == "SeId" then v[kk] = tonumber(vv) end
	 end
      end
      InsP.panelImg = lcd.loadImage(pDir .. "/"..InsP.settings.selPanel..".png")
      if not InsP.panelImg then
	 print("DFM-InsP: Could not read panel png file")
      end
   else
      print("DFM-InsP: Did not read any jsn panel file")
      InsP.panels[1] = {}
   end
   InsP.writeBD = true

   -- Populate a table with all the panel json files
   -- in the Panels/ directory

   InsP.settings.panels = {}
   local dd, fn, ext
   local path = prefix() .. pDir
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "jsn" then
	    local ff = path .. "/" .. fn .. "." .. ext
	    local file = io.open(ff)
	    if file then
	       if not InsP.settings.panels then InsP.settings.panels = {} end
	       table.insert(InsP.settings.panels, fn)
	       io.close(file)
	    end
	 end
      end
   end

   table.sort(InsP.settings.panels)

   -- Populate a table with all the background image files
   -- in the Backgrounds/ directory
   
   InsP.settings.backgrounds = {}
   local dd, fn, ext
   local path = prefix() .. bDir
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "png" then
	    local ff = path .. "/" .. fn .. "." .. ext
	    local file = io.open(ff)
	    if file then
	       if not InsP.settings.backgrounds then InsP.settings.backgrounds = {} end
	       table.insert(InsP.settings.backgrounds, fn)
	       io.close(file)
	    end
	 end
      end
   end

   table.sort(InsP.settings.backgrounds)

   if InsP.settings.selBack then
      InsP.backImg = lcd.loadImage(bDir .. "/"..InsP.settings.selBack..".png")
   else
      InsP.backImg = nil
   end

   readSensors(InsP)

   system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm, prtForm)
   system.registerTelemetry(1, "Instrument Panel", 4, printForm)

end

return {init=init, loop=loop, author="DFM", version="0", name="DFM-InsP", destroy=destroy}


