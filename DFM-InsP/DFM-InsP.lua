local InsP = {}

InsP.panels = {}
InsP.panelImages = {}
InsP.sensorLalist = {"..."}
InsP.sensorLslist = {"..."}
InsP.sensorIdlist = {0}
InsP.sensorPalist = {0}
InsP.settings = {}
InsP.settings.switchInfo = {}

local switches = {}

local edit = {}
edit.ops = {"Center", "Value", "Label", "Range"}
edit.dir = {"X", "Y", "Font"}
edit.fonts = {"Mini", "Normal", "Bold", "Big", "None"}
edit.fcode = {Mini=FONT_MINI, Normal=FONT_NORMAL, Bold=FONT_BOLD, Big=FONT_BIG, None=-1}
edit.icode = {Mini=1, Normal=2, Bold=3, Big=4, None=5}
edit.gaugeName = {roundGauge="RndG", horizontalBar="HBar", textBox="Text"}

local subForm = 0
local pDir = "Apps/DFM-InsP/Panels"
local bDir = "Apps/DFM-InsP/Backgrounds"
local panelImg
local backImg
local savedRow = 1
local savedRow2 = 1
local savedRow3 = 1
local mmCI
local swtCI ={}

local needle = {
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

local triangle = {
   {-7,1},
   {0,-9},
   {7,1}
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
   if font < 0 then return end -- an "invisible" font :-)
   if not font then font = FONT_NORMAL end
   lcd.drawText(x - lcd.getTextWidth(font, str)/2,
		y - lcd.getTextHeight(font)/2, str, font)
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end

local function drawShape(col, row, shape, f, rotation, x0, y0, r, g, b)

   local sinShape, cosShape
   local ren = lcd.renderer()
   local fw = f^0.55
   if not x0 then x0 = 0 end
   if not y0 then y0 = 0 end
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + ((fw*point[1]+x0) * cosShape - (f*point[2]+y0) * sinShape + 0.5),
	 row + ((fw*point[1]+x0) * sinShape + (f*point[2]+y0) * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
   if r and g and b then
      lcd.setColor(r,g,b)
      ren:renderPolyline(2)
   end
end

local function keyForm(key)
   local ip
   
   if subForm == 1 then
      local is = InsP.settings
      local ip = InsP.panels
      local sp = is.selectedPanel
      if key == KEY_1 then
	 if not sp then return end
	 print("is.selectedPanel, #ip", sp, #ip)
	 local temp = sp
	 temp = temp + 1
	 if temp > #ip  then is.selectedPanel = 1 else is.selectedPanel = temp end
	 print("keyForm selectedPanel", is.selectedPanel)

	 local pv = InsP.panelImages[is.selectedPanel].instImage
	 print("selectedPanelName set to", pv)
	 InsP.settings.selectedPanelName = pv
	 
	 if pv then
	    panelImg = lcd.loadImage(pDir .. "/"..pv..".png")
	 else
	    panelImg = nil
	 end
	 
	 local bv = InsP.panelImages[is.selectedPanel].backImage
	 if bv then
	    backImg =  lcd.loadImage(bDir .. "/"..bv..".png")
	 else
	    backImg = nil
	 end

	 form.reinit(1)
      end
      if key == KEY_2 then
	 print("key 2", #InsP.panels)
	 local ii = #InsP.panels+1
	 InsP.panels[ii] = {}
	 InsP.panelImages[ii] = {}
	 --table.insert(InsP.panels, {})
	 --should we select the one just created?
	 is.selectedPanel = #InsP.panels
	 is.selectedPanelName = "" -- don't know name till it's set in settings
	 --ip.selPanel = nil
	 form.reinit(1)
      end
   end
   
   if subForm == 100 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 then -- edit
	 savedRow2 = form.getFocusedRow()
	 savedRow3 = form.getFocusedRow()
	 form.reinit(104)
      end
   end

   if subForm == 102 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   end

   if subForm == 104 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(100)
	 return
      end
   end
   
   if subForm == 103 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      local ip = InsP.panels[InsP.settings.selectedPanel]
      if key == KEY_1 then
	 edit.gauge = edit.gauge + 1
	 if edit.gauge > #ip then edit.gauge = 1 end
      elseif key == KEY_2 then
	 edit.opsIdx = edit.opsIdx + 1
	 if edit.opsIdx > #edit.ops then edit.opsIdx = 1 end
	 form.setButton(2, string.format("%s", edit.ops[edit.opsIdx]), ENABLED)
      elseif key == KEY_3 then
	 edit.dirIdx = edit.dirIdx + 1
	 if edit.dirIdx > #edit.dir then edit.dirIdx = 1 end
	 form.setButton(3, string.format("%s", edit.dir[edit.dirIdx]), ENABLED)	 
      elseif key == KEY_UP or key == KEY_DOWN then
	 local inc
	 if key == KEY_UP then inc = 1 else inc = -1 end
	 local ipeg = ip[edit.gauge] 
	 local eo = edit.ops[edit.opsIdx]
	 local ed = edit.dir[edit.dirIdx]
	 if ed == "X" then
	    if eo == "Value" and ipeg.xV then
	       ipeg.xV = ipeg.xV + inc
	    end
	    
	    if eo == "Label" and ipeg.xL then
	       ipeg.xL = ipeg.xL + inc
	    end

	    if eo == "Range" and ipeg.xLV and ipeg.xRV then
	       ipeg.xLV = ipeg.xLV + inc
	       ipeg.xRV = ipeg.xRV - inc
	    end

	 elseif ed == "Y" then
	    if eo == "Value" and ipeg.yV then
	       ipeg.yV = ipeg.yV + inc
	    end
	    
	    if eo == "Label" and ipeg.yL then
	       ipeg.yL = ipeg.yL + inc	       
	    end

	    if eo == "Range" and ipeg.yLV and ipeg.yRV then
	       ipeg.yLV = ipeg.yLV + inc
	       ipeg.yRV = ipeg.yRV + inc
	    end

	 elseif ed == "Font" then
	    if eo == "Value" and ipeg.fV then
	       local i = edit.icode[ipeg.fV]
	       i = i + inc
	       --i = math.min(math.max(i, 1), #edit.fonts)
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       ipeg.fV = edit.fonts[i]
	    end
	    if eo == "Label" and ipeg.fL then
	       local i = edit.icode[ipeg.fL]
	       i = i + inc
	       --i = math.min(math.max(i, 1), #edit.fonts)
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       ipeg.fL = edit.fonts[i]
	    end
	    if eo == "Range" and ipeg.fLRV then
	       local i = edit.icode[ipeg.fLRV]
	       i = i + inc
	       --i = math.min(math.max(i, 1), #edit.fonts)
	       if i > #edit.fonts then i = 1 end	       
	       if i < 1 then i = #edit.fonts end
	       ipeg.fLRV = edit.fonts[i]
	    end
	 end
      end
   end
end

local function changedSensor(val, i, ip)
   ip[i].SeId = InsP.sensorIdlist[val]
   ip[i].SePa = InsP.sensorPalist[val]
end

local function panelChanged(val)
   local fn
   local pv = InsP.settings.panels[val]
   local sp = InsP.settings.selectedPanel

   if val ~= 1 then
      fn = pDir .. "/"..pv..".jsn"
      local file = io.readall(fn)
      local bi = InsP.panelImages[sp].backImage
      InsP.panels[sp] = json.decode(file)
      panelImg = lcd.loadImage(pDir .. "/"..pv..".png")
      InsP.panelImages[sp].instImage = pv
      InsP.panelImages[sp].backImage = bi
   else
      panelImg = nil
      InsP.panelImages[sp].instImage = nil
   end
end

local function backGndChanged(val)
   local bv = InsP.settings.backgrounds[val]
   local sp = InsP.settings.selectedPanel
   if val ~= 1 then
      backImg = lcd.loadImage(bDir .. "/"..bv..".png")
      InsP.panelImages[sp].backImage = bv
   else
      backImg = nil
      InsP.panelImages[sp].backImage = nil
   end
end

local function changedSwitch(val, switchName)
   local Invert = 1.0

   local swInfo = system.getSwitchInfo(val)

   local swTyp = string.sub(swInfo.label,1,1)
   if swInfo.assigned then
      if string.sub(swInfo.mode,-1,-1) == "I" then Invert = -1.0 end
      if swInfo.value == Invert or swTyp == "L" or swTyp =="M" then
	 switches[switchName] = val
	 InsP.settings.switchInfo[switchName] = {} 
	 InsP.settings.switchInfo[switchName].name = swInfo.label
	 if swTyp == "L" or swTyp =="M" then
	    InsP.settings.switchInfo[switchName].activeOn = 0
	 else
	    local ao = system.getInputs(string.upper(swInfo.label))
	    InsP.settings.switchInfo[switchName].activeOn = ao
	    if ao > -1.0 and ao < 1.0 and swInfo.mode == "S" then swInfo.mode = "P" end
	 end
	 InsP.settings.switchInfo[switchName].mode = swInfo.mode
      else
	 system.messageBox("Error - do not move switch when assigning")
	 if switches[switchName] then
	    form.setValue(swtCI[switchName], switches[switchName])
	 else
	    form.setValue(swtCI[switchName],nil)
	 end
      end
   else
      if InsP.settings.switchInfo[switchName] then
	 switches[switchName] = nil
	 InsP.settings.switchInfo[switchName] = nil
      end
   end
end

--(function(x) return changedMinMax(x, "min", ip[ig]) end), {width=80})

local function changedMinMax(val, sel, ipig)
   if sel == "min" then
      ipig.min = val
   else
      ipig.max = val
   end
end

local function changedLabel(val, ipig, f)
   val = string.gsub(val, "''", "'")
   val = string.gsub(val, "'d", "°")
   ipig.label = val
   form.reinit(f)
end

--      mmCI = form.addCheckbox(isel, (function(x) return changedShowMM(x, ip[ig]) end) )

local function changedShowMM(val, ipig)
   ipig.showMM = tostring(not val)
   form.setValue(mmCI, not val)
end

local function initForm(sf)

   subForm = sf

   if sf == 1 then
      local val
      if InsP.settings.selectedPanel > 0 then
      	 val = string.format(" %d", InsP.settings.selectedPanel)
      else
	 val = " (none selected)"
      end

      form.setButton(1, "Select", ENABLED)
      form.setButton(2, ":add", ENABLED)
      form.setButton(3, ":delete", ENABLED)
      
      form.setTitle(string.format("Instrument Panel%s of %d", val, #InsP.panels))
      
      form.addRow(2)
      form.addLabel({label="Settings >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(102)
	       form.waitForRelease()
      end))      
      
      form.addRow(2)
      form.addLabel({label="Sensors >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(100)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Edit Panel >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(103)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Reset App data >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(101)
	       form.waitForRelease()
      end))
      
      form.setFocusedRow(savedRow)
   elseif sf == 100 then

      local ip = InsP.panels[InsP.settings.selectedPanel]
      form.setTitle("Assign sensors to gauges")

      form.setButton(1, ":edit", ENABLED)
      
      if not ip or #ip == 0 then
	 form.addRow(1)
	 form.addLabel({label="No instrument panel defined"})
	 form.addRow(1)
	 form.addLabel({label="Use the settings menu to select a panel"})
	 return
      end
      
      for i, widget in ipairs(ip) do
	 form.addRow(3)
	 local str
	 if widget.label then str = "  "..widget.label else str = "" end
	 local typ = edit.gaugeName[widget.type]
	 if not typ then typ = "---" end
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
      form.setFocusedRow(savedRow2)
   elseif sf == 101 then
      io.remove(InsP.settings.fileBD)
      InsP.settings.writeBD = false
      system.messageBox("Data deleted .. restart App")
      form.reinit(1)
   elseif sf == 102 then
      
      form.setTitle("Settings")

      form.addRow(2)
      local sp = InsP.settings.selectedPanel
      local pnl = InsP.panelImages[sp].instImage
      form.addLabel({label="Instrument Panel " .. sp })
      local isel = 0
      if InsP.settings.panels then
	 for i, p in ipairs(InsP.settings.panels) do
	    if p == pnl then
	       isel = i
	       break
	    end
	 end
      end
      form.addSelectbox(InsP.settings.panels, isel, true, panelChanged)

      form.addRow(2)
      form.addLabel({label="Background Image " .. sp})
      local bak = InsP.panelImages[sp].backImage
      local isel = 0
      for i, p in ipairs(InsP.settings.backgrounds) do
	 if p == bak then
	    isel = i
	    break
	 end
      end
      form.addSelectbox(InsP.settings.backgrounds, isel, true, backGndChanged)      

      form.addRow(2)
      form.addLabel({label="Switch to reset min/max markers", width=240})
      swtCI.resetMinMax = form.addInputbox(switches.resetMinMax, false,
			      (function(x) return changedSwitch(x, "resetMinMax") end))

      form.addRow(2)
      form.addLabel({label="Switch to rotate panels", width=240})
      swtCI.rotatePanels = form.addInputbox(switches.rotatePanels, false,
			      (function(x) return changedSwitch(x, "rotatePanels") end))

      form.setFocusedRow(savedRow2)
   elseif sf == 103 then
      form.setTitle("")
      edit.gauge = 1
      edit.opsIdx = 1
      edit.dirIdx = 2 -- default to "Y"
      form.setButton(1, "Select", ENABLED)
      form.setButton(2, string.format("%s", edit.ops[edit.opsIdx]), ENABLED)
      form.setButton(3, string.format("%s", edit.dir[edit.dirIdx]), ENABLED)
      --form.setButton(4, string.format("%s", edit.fonts[edit.fontIdx), ENABLED)      
   elseif sf == 104 then -- edit item on sensor menu
      local ig = savedRow3
      local ip = InsP.panels[InsP.settings.selectedPanel]
      form.setTitle("Edit Gauge "..ig.."  ("..ip[ig].label..")", savedRow3)

      form.addRow(4)
      form.addLabel({label="Min"})
      if ip[ig].subdivs == 0 then
	 form.addIntbox(ip[ig].min, -32768, 32767, 0, 0, 1,
			(function(x) return changedMinMax(x, "min", ip[ig]) end),
			{width=80})
      else
	 form.addLabel({label=string.format("%d", ip[ig].min), width=80, alignRight=true})
      end
      form.addLabel({label="Max"})
      if ip[ig].subdivs == 0 then
	 form.addIntbox(ip[ig].max, -32768, 32767, 0, 0, 1,
			(function(x) return changedMinMax(x, "max", ip[ig]) end),
			{width=80})
      else
	 form.addLabel({label=string.format("%d", ip[ig].max), width=80, alignRight=true})
      end

      form.addRow(2)
      form.addLabel({label="Label", width=60})
      form.addTextbox(ip[ig].label, 63,
		      (function(x) return changedLabel(x, ip[ig], sf) end),
		      {width=245})

      form.addRow(2)
      form.addLabel({label="Enable min/max markers", width=270})
      local isel = ip[ig].showMM == "true"
      mmCI = form.addCheckbox(isel, (function(x) return changedShowMM(x, ip[ig]) end), {width=60} )
      form.setFocusedRow(savedRow2)
   end
end

local swrLast
local swpLast
local function loop()

   local sensor
   local swr, swp

   local isp = InsP.panels[InsP.settings.selectedPanel]
   if not isp then return end

   -- see if we need to rotate panels
   swp = system.getInputsVal(switches.rotatePanels)
   if not swpLast then swpLast = swp end
   local is = InsP.settings
   local ip = InsP.panels
   if swp and swp == 1 and swpLast ~= 1 then
      local temp = is.selectedPanel
      temp = temp + 1
      if temp > #ip  then is.selectedPanel = 1 else is.selectedPanel = temp end
      print("rotate to", is.selectedPanel)
      local pv = InsP.panelImages[is.selectedPanel].instImage
      print("selectedPanelName set to", pv)
      InsP.settings.selectedPanelName = pv
      if pv then
	 panelImg = lcd.loadImage(pDir .. "/"..pv..".png")
      else
	 panelImg = nil
      end
      
      local bv = InsP.panelImages[is.selectedPanel].backImage
      if bv then
	 backImg =  lcd.loadImage(bDir .. "/"..bv..".png")
      else
	 backImg = nil
      end
   end
   swpLast = swp
   
   -- see if the reset min/max switch has moved
   
   swr = system.getInputsVal(switches.resetMinMax)
   if not swrLast then swrLast = swr end
   if swr and swr == 1 and swrLast ~= 1 then
      for i,widget in ipairs(ip) do
	 for k,v in pairs(widget) do
	    if k == "minval" or k == "maxval" then widget[k] = nil end
	 end
      end
   end
   swrLast = swr

   -- update min and max values
   
   for i, widget in ipairs(ip) do
      sensor = system.getSensorByID(widget.SeId, widget.SePa)	 
      if sensor and sensor.valid then
	 -- text box does not have min or max
	 if not widget.min then widget.min = 0 end
	 if not widget.max then widget.max = 1 end

	 if not widget.minval then
	    widget.minval = sensor.value
	 end
	 if sensor.value < widget.minval then widget.minval = sensor.value end

	 if not widget.maxval then
	    widget.maxval = sensor.value
	 end
	 if sensor.value > widget.maxval then widget.maxval = sensor.value end
      end
   end
end

local function printForm(wi, he)

   local ctl, ctlmin, ctlmax
   local rot, rotmin, rotmax
   local factor = 1.0
   local sensor
   local ip = InsP.panels[InsP.settings.selectedPanel]

   if backImg  then
      lcd.drawImage(0, 0, backImg)
   else
      lcd.drawFilledRectangle(0,0,319,158)
   end

   if panelImg then
      lcd.drawImage(0, 0, panelImg)
   else
      lcd.setColor(255,255,255)
      lcd.drawText(100, 70, "No Panel Image", FONT_BOLD)
   end

   if not ip or #ip == 0 then
      drawTextCenter(160, 60, "No instrument panel json defined", FONT_BOLD)
      return
   end

   for i, widget in ipairs(ip) do
      sensor = system.getSensorByID(widget.SeId, widget.SePa)
      ctl = nil
      if sensor and sensor.valid then
	 if widget.min and widget.max then
	    ctl = math.min(math.max((sensor.value - widget.min) / (widget.max - widget.min), 0), 1)
	    rot = -0.75*math.pi * (1-ctl) + 0.75*math.pi*(ctl)
	 end
	 if widget.min and widget.max and widget.minval then
	    ctlmin = math.min(math.max((widget.minval - widget.min) / (widget.max - widget.min), 0), 1)
	    rotmin = -0.75*math.pi * (1-ctlmin) + 0.75*math.pi*(ctlmin)end
	 if widget.min and widget.max and widget.maxval then
	    ctlmax = math.min(math.max((widget.maxval - widget.min) / (widget.max - widget.min), 0), 1)
	    rotmax = -0.75*math.pi * (1-ctlmax) + 0.75*math.pi*(ctlmax)
	 end
      end
      if widget.type == "roundGauge" then
	 local val
	 lcd.setColor(255,255,255)
	 
	 if ctl then
	    factor = widget.radius / 65.0
	    drawShape(widget.x0, widget.y0, needle, factor, rot + math.pi)
	    if rotmin and widget.showMM == "true" then
	       drawShape(widget.x0, widget.y0, triangle, factor, rotmin + math.pi, 0,
			 widget.radius, 0, 0, 0)
	    end
	    
	    lcd.setColor(255,255,255)
	    if rotmax and widget.showMM == "true" then
	       drawShape(widget.x0, widget.y0, triangle, factor, rotmax + math.pi, 0,
			 widget.radius, 0, 0, 0)
	    end
	    
	    lcd.setColor(255,255,255)
	    val = string.format("%.1f", sensor.value)
	 else
	    val = "---"
	 end
	 local str
	 if widget.label then str = widget.label else str = "Gauge"..i end

	 if not widget.fL then
	    widget.fL = "Mini"
	 end

	 if not widget.fV then
	    widget.fV = "Mini"
	 end

	 if not widget.fLRV then
	    widget.fLRV = "Mini"
	 end
	 
	 if widget.radius > 30 then
	    if not widget.xL then
	       widget.xL = widget.x0
	       widget.yL = widget.y0 + 1.0 * widget.radius - 15
	    end

	    drawTextCenter(widget.xL, widget.yL, str, edit.fcode[widget.fL])
	    
	    if not widget.xV then
	       widget.xV = widget.x0
	       widget.yV = widget.y0 + 0.17 * widget.radius
	    end

	    drawTextCenter(widget.xV, widget.yV, string.format("%s", val), edit.fcode[widget.fV])
	    
	    if widget.subdivs == 0 then
	       if not widget.xLV then
		  widget.xLV = widget.x0 - 0.55 * widget.radius
		  widget.xRV = widget.x0 + 0.55 * widget.radius
		  widget.yLV = widget.y0 + 0.9 * widget.radius
		  widget.yRV = widget.y0 + 0.9 * widget.radius
	       end
	       val = string.format("%d", widget.min)
	       drawTextCenter(widget.xLV, widget.yRV, string.format("%s", val), edit.fcode[widget.fLRV])
	       val = string.format("%d", widget.max)
	       drawTextCenter(widget.xRV, widget.yRV, string.format("%s", val), edit.fcode[widget.fLRV])
	    end
	 elseif widget.radius >= 20 then
	    if not widget.xV then
	       widget.xV = widget.x0
	       widget.yV = widget.y0 + 0.25 * widget.radius
	    end
	    drawTextCenter(widget.xV, widget.yV,
			   string.format("%s", val), edit.fcode[widget.fV])	    
	    if not widget.xL then
	       widget.xL = widget.x0
	       widget.yL = widget.y0 + 1.0 * widget.radius - 9
	    end
	    drawTextCenter(widget.xL, widget.yL, str, edit.fcode[widget.fL])

	    if widget.subdivs == 0 then
	       if not widget.xLV then
		  widget.xLV = widget.x0 - 0.55 * widget.radius
		  widget.xRV = widget.x0 + 0.55 * widget.radius
		  widget.yLV = widget.y0 + 1.0 * widget.radius
		  widget.yRV = widget.y0 + 1.0 * widget.radius
	       end
	       --print(widget.radius, widget.x0, widget.y0, widget.xLV, widget.yLV)
	       val = string.format("%d", widget.min)
	       drawTextCenter(widget.xLV, widget.yLV, string.format("%s", val), edit.fcode[widget.fLRV])
	       val = string.format("%d", widget.max)
	       drawTextCenter(widget.xRV, widget.yRV, string.format("%s", val), edit.fcode[widget.fLRV])
	    end
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
	 if widget.label then str = widget.label else str = "Gauge"..i end
	 if not widget.fL then
	    widget.fL = "Mini"
	 end
	 if not widget.xL then
	    widget.xL = widget.x0
	    widget.yL = widget.y0 + h / 2 - hPad / 5
	 end
	 
	 drawTextCenter(widget.xL, widget.yL, str, edit.fcode[widget.fL])
	 
      elseif widget.type == "textBox" then

	 lcd.setColor(0,0,0)
	 if sensor and sensor.valid then
	    msgidx = math.max(math.min(sensor.value, #messages), 1)
	 else
	    msgidx = 1
	 end
	 if not widget.fL then
	    widget.fL = "Bold"
	 end

	 local str = messages[msgidx]

	 if not widget.xL then
	    widget.xL = widget.x0 
	    widget.yL = widget.y0
	 end
	 
	 lcd.drawText(widget.xL - lcd.getTextWidth(edit.fcode[widget.fL], str)/2,
		      widget.yL - lcd.getTextHeight(edit.fcode[widget.fL])/2,
		      str, edit.fcode[widget.fL])
	 
      else
      end
   end
end

local function prtForm(w,h)
   if subForm == 103 and InsP.panels[InsP.settings.selectedPanel] then
      printForm(318,159)
      local ip = InsP.panels[InsP.settings.selectedPanel]
      lcd.setColor(180,180,180)
      lcd.drawFilledRectangle(0, 158, 318, 20)
      lcd.setColor(0,0,0)
      local ipeg = ip[edit.gauge]
      if not ipeg then return end
      local xx, yy = ipeg.x0, ipeg.y0 -- default for Center
      local ff
      local ii = edit.ops[edit.opsIdx]
      if (ii == "Value") and ipeg.xV then
	 xx = ipeg.xV
	 yy = ipeg.yV
	 ff = ipeg.fV
      elseif (ii == "Label") and ipeg.xL then
	 xx = ipeg.xL
	 yy = ipeg.yL
	 ff = ipeg.fL
      elseif (ii == "Range") and ipeg.xLV then
	 xx = (ipeg.xLV + ipeg.xRV) / 2
	 yy = ipeg.yLV
	 ff = ipeg.fLRV
      end
      --[[
      local strN, strX
      if ipeg.min then strN = string.format("%d", ipeg.min) else strN = "---" end
      if ipeg.max then strX = string.format("%d", ipeg.max) else strX = "---" end      
      --]]
      local typ = edit.gaugeName[ipeg.type]
      if not typ then typ = "---" end
      
      local fn
      if ff then fn = "Font: " else fn = ""; ff = "" end
      
      lcd.drawText(10, 157,
		   string.format("Gauge %d Type: %s  [%d,%d]  %s %s",
				 edit.gauge, typ, xx, yy, fn, ff))
      local ip = InsP.panels[InsP.settings.selectedPanel]
      lcd.setColor(180,180,180)
      lcd.drawLine(0, yy, w, yy)
      lcd.drawLine(xx, 0, xx, h)      
   end
end

local function destroy()
   local fp
   local save = {}
   if InsP.settings.writeBD then
      save.panels = InsP.panels
      save.panelImages = InsP.panelImages
      save.settings = InsP.settings
      -- convert Id to hex, otherwise it comes in as a float and loss of precision
      -- creates invalid result on read
      if save.panels then
	 for i in ipairs(save.panels) do
	    if not save.panels[i] then print("nil panel", i) end
	    for k,v in ipairs(save.panels[i]) do
	       for kk,vv in pairs(v) do
		  if kk == "SeId" then v[kk] = string.format("0X%X", vv) end
	       end
	    end
	 end
      end
      -- don't save the list of panels and background images, read new each time we start
      if save.settings then
	 for k,v in pairs(save.settings) do
	    --print("k,v", k, v)
	    if k == "panels" then save.settings.panels = {} end
	    if k == "backgrounds" then save.settings.backgrounds = {} end	       
	 end
      end
      --print("save.settings.panels", save.settings.panels)
      --print("save.settings.backgrounds", save.settings.backgrounds)      
      fp = io.open(InsP.settings.fileBD, "w")
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
   local ff = prefix() .. "Apps/DFM-InsP/II_" .. mn .. ".jsn"

   file = io.readall(ff)
   if file then
      decoded = json.decode(file)
      if not decoded then
	 decoded = {}
	 decoded.panels = {}
	 decoded.panels[1] = {}
	 decoded.panelImages = {}
	 decoded.panelImages[1] = {}
      end
      for i=1, #decoded.panels do
	 InsP.panels[i] = decoded.panels[i]
      end
      for i=1, #decoded.panelImages do
	 InsP.panelImages[i] = decoded.panelImages[i]
      end
      InsP.settings = decoded.settings
      if not InsP.settings then InsP.settings = {} end

      for i in ipairs(InsP.panels) do
	 for k,v in ipairs(InsP.panels[i]) do
	    for kk,vv in pairs(v) do
	       if kk == "SeId" then v[kk] = tonumber(vv) end
	       if kk == "minval"  then v[kk] = nil end
	       if kk == "maxval"  then v[kk] = nil end
	    end
	 end
      end
   else
      print("DFM-InsP: Did not read any jsn panel file")
      InsP.panels = {}
      InsP.panels[1] = {}
      InsP.panelImages = {}
      InsP.panelImages[1] = {}
   end
   InsP.settings.fileBD = ff
   InsP.settings.writeBD = true

   -- Populate a table with all the panel json files
   -- in the Panels/ directory

   InsP.settings.panels = {'...'}
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

   -- the list of panels may have changed, re-find selectedPanel if in the list
   
   local isel = 0
   local pp = InsP.settings.selectedPanelName 
   for i, p in ipairs(InsP.settings.panels) do
      print(i,p,pp)
      if p == pp then isel = i break end
   end

   print("isel loop done", isel)
   if isel == 0 then
      InsP.settings.selectedPanel = 1 -- InsP.panels inits to {}
      --InsP.settings.selPanel = nil -- but no json or image
   else
      InsP.settings.selectedPanel = isel - 1 -- account for "..." in [1]
      --InsP.settings.selPanel = InsP.settings.panels[isel+1]
   end
   
   print("init: selectedPanel", InsP.settings.selectedPanel, InsP.settings.selectedPanelName)
   
   -- Populate a table with all the background image files
   -- in the Backgrounds/ directory
   
   InsP.settings.backgrounds = {"..."}
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

   local is = InsP.settings
   local ip = InsP.panels

   if InsP.panelImages[is.selectedPanel].instImage then
      panelImg = lcd.loadImage(pDir .. "/" .. InsP.panelImages[is.selectedPanel].instImage .. ".png")
   end
   
   if InsP.panelImages[is.selectedPanel].backImage then
      backImg = lcd.loadImage(bDir .. "/" .. InsP.panelImages[is.selectedPanel].backImage .. ".png")
   end
      
   --[[
   if InsP.settings.selPanel then
      print("loadImage", InsP.settings.selPanel)
      panelImg = lcd.loadImage(pDir .. "/"..InsP.settings.selPanel..".png")
   end
   if InsP.settings.selBack then
      print("loadImage", InsP.settings.selBack)
      backImg = lcd.loadImage(bDir .. "/"..InsP.settings.selBack..".png")
   end
   --]]
   
   
   for k, swi in pairs(InsP.settings.switchInfo) do
      print("k, sw", k, swi.name, swi.mode, swi.activeOn)
      --if swi.activeOn > -1 and swi.activeOn < 1 then print("swi.mode", swi.mode)  swi.mode = "P" end
      switches[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
   end
   
   readSensors(InsP)

   system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm, prtForm)
   system.registerTelemetry(1, "Instrument Panel", 4, printForm)

end

return {init=init, loop=loop, author="DFM", version="0", name="DFM-InsP", destroy=destroy}

