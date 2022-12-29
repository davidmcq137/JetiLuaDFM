--[[
   ----------------------------------------------------------------------
   DFM-InsP.lua released under MIT license by DFM 2022
   
   This app is intended to render instrument panels where a json and image file
   are produced on Russell's dynamic content app creation/distribution website
   ----------------------------------------------------------------------
--]]


local InsPVersion = 0.1
local InsP = {}
InsP.panels = {}
InsP.panelImages = {}
InsP.sensorLalist = {"..."}
InsP.sensorLslist = {"..."}
InsP.sensorIdlist = {0}
InsP.sensorPalist = {0}
InsP.sensorUnlist = {"-"}
InsP.sensorDplist = {0}

local teleSensors, txTeleSensors
local txSensorNames = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		       "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		       "rxBVoltage", "rxBPercent", "photoValue"}
local txSensorUnits = {"V", "%", "mA", "mAh", "%", "V", "%", "V", "V", "%", " "}
local txSensorDP    = { 1,   0,    0,     0,   0,   1,   0,   1,   1,   0,   0}
local txSensorsMax
local txRSSINames = {"rx1Ant1", "rx1Ant2", "rx2Ant1", "rx2Ant2",
		     "rxBAnt1", "rxBAnt2"}

InsP.settings = {}
InsP.settings.switchInfo = {}

local switches = {}
local stateSw = {}

local edit = {}
edit.ops = {"Center", "Value", "Label", "Range"}
edit.dir = {"X", "Y", "Font"}
edit.fonts = {"Mini", "Normal", "Bold", "Big", "None"}
edit.fcode = {Mini=FONT_MINI, Normal=FONT_NORMAL, Bold=FONT_BOLD, Big=FONT_BIG, None=-1}
edit.icode = {Mini=1, Normal=2, Bold=3, Big=4, None=5}
edit.gaugeName = {roundGauge="RndG", horizontalBar="HBar", textBox="Text"}

local lua = {}
lua.chunk = {}
lua.env = {string=string, math=math, table=table, print=print,
	   tonumber=tonumber, tostring=tostring,pairs=pairs, ipairs=ipairs}
lua.index = 0
lua.txTelLastUpdate = 0
lua.txTel = {}
lua.completePass = false

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

local appStartTime

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

--[[
local hSlider = {
   {0,0},
   {6,6},
   {-6,6}
}
--]]

local triangle = {
   {-7,1},
   {0,-9},
   {7,1}
}

local function getSensorByID(SeId, SePa)
   if SeId ~= 0 then
      return system.getSensorByID(SeId, SePa)
   elseif SePa > 0 then -- txTel named
      local sensor={}
      sensor.value = lua.txTel[txSensorNames[SePa]] 
      sensor.unit  = InsP.sensorUnlist[teleSensors + SePa]
      sensor.decimals = InsP.sensorDplist[teleSensors + SePa]
      -- TX reports 0 until it has good data for txTel .. ruins max/min
      if system.getTimeCounter() - appStartTime > 200 then
	 sensor.valid = true
      else
	 sensor.valid = false
      end
      return sensor
   elseif SePa < 0 then -- txTel RSSI
      local NePa = -SePa
      local sensor = {}
      sensor.value = lua.txTel.RSSI[NePa]
      sensor.unit  = InsP.sensorUnlist[txTeleSensors + NePa]
      sensor.decimals = InsP.sensorDplist[txTeleSensors + NePa]
      -- TX reports 0 until it has good data for txTel .. ruins max/min
      if system.getTimeCounter() - appStartTime > 200 then
	 sensor.valid = true
      else
	 sensor.valid = false
      end
      return sensor
   end
end

local function readSensors(tt)
   local sensorLbl = "***"
   local l1, l2
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    table.insert(tt.sensorLalist, l1 .. "_" .. l2)
	    table.insert(tt.sensorLslist, sensor.label)	    
	    table.insert(tt.sensorIdlist, sensor.id)
	    table.insert(tt.sensorPalist, sensor.param)
	    table.insert(tt.sensorUnlist, sensor.unit)
	    table.insert(tt.sensorDplist, sensor.decimals)
	 end
      end
   end
   teleSensors = #tt.sensorLalist

   l1 = "txTel"
   for i, label in ipairs(txSensorNames) do
      table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, i)
      table.insert(tt.sensorUnlist, txSensorUnits[i])
      table.insert(tt.sensorDplist, txSensorDP[i])
   end
   txTeleSensors = #tt.sensorLalist

   l1 = "txRSSI"
   for i, label in ipairs(txRSSINames) do
   table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, -i)
      table.insert(tt.sensorUnlist, " ")
      table.insert(tt.sensorDplist, 0)
   end

end

local function initPanels(tbl)
   tbl.panels = {}
   tbl.panels[1] = {}
   tbl.panelImages = {}
   tbl.panelImages[1] = {}
   tbl.panelImages[1].instImage = "---"
   tbl.panelImages[1].backImage = "---"
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

local function setToPanel(iisp)
   --print("setToPanel", iisp)
   local isp = iisp
   if isp < 1 then isp = 1 end
   if isp > #InsP.panels then isp = #InsP.panels end
   InsP.settings.selectedPanel = isp
   
   local pv = InsP.panelImages[isp].instImage
   
   if pv then
      panelImg = lcd.loadImage(pDir .. "/"..pv..".png")
   else
      panelImg = nil
   end
   
   local bv = InsP.panelImages[InsP.settings.selectedPanel].backImage
   if bv then
      backImg =  lcd.loadImage(bDir .. "/"..bv..".png")
   else
      backImg = nil
   end
end

local function setToPanelName(pn)
   local isel = 0
   for i, p in ipairs(InsP.panelImages) do
      if p.instImage == pn then
	 isel = i
	 break
      end
   end
   if isel > 0 then
      --print("calling setToPanel", pn, isel)
      setToPanel(isel)
   else
      --print("nothing done", pn)
   end
end


local function keyForm(key)
   
   local is = InsP.settings
   local ip = InsP.panels
   local sp = is.selectedPanel

   if subForm == 1 then
      if key == KEY_1 then
	 if not sp then return end
	 local temp = sp
	 temp = temp + 1
	 if temp > #ip  then is.selectedPanel = 1 else is.selectedPanel = temp end
	 setToPanel(is.selectedPanel)
	 form.reinit(1)
      end
   end

   if subForm == 106 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 then
	 if not sp then return end
	 local temp = sp
	 temp = temp + 1
	 if temp > #ip  then is.selectedPanel = 1 else is.selectedPanel = temp end
	 setToPanel(is.selectedPanel)
	 form.reinit(106)
      end
      if key == KEY_2 then
	 if not sp then return end
	 local row = is.homePanel
	 row = row + 1
	 if row > #ip  then
	    is.homePanel = 1
	 else
	    is.homePanel = row
	 end
	 --print("home panel set to", is.homePanel)
	 form.reinit(106)
      end
      
      if key == KEY_3 then
	 local ii = #InsP.panels+1
	 InsP.panels[ii] = {}
	 InsP.panelImages[ii] = {}
	 is.selectedPanel = #InsP.panels
	 InsP.panelImages[is.selectedPanel].instImage = "---"
	 InsP.panelImages[is.selectedPanel].backImage = "---"
	 setToPanel(#InsP.panels)
	 form.reinit(106)
      end
      if key == KEY_4 then
	 local row = form.getFocusedRow() - 1
	 table.remove(InsP.panels, row)
	 table.remove(InsP.panelImages, row)
	 if row == is.homePanel then
	    system.messageBox("Home Panel deleted")
	    is.homePanel = 1
	 end
	 if row == is.selectedPanel then
	    system.messageBox("Selected Panel deleted")
	    is.selectedPanel = 1
	 end
	 
	 if #InsP.panels < 1 then
	    initPanels(InsP)
	 end
	 setToPanel(is.selectedPanel)
      	 form.reinit(106)
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
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       ipeg.fV = edit.fonts[i]
	    end
	    if eo == "Label" and ipeg.fL then
	       local i = edit.icode[ipeg.fL]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       ipeg.fL = edit.fonts[i]
	    end
	    if eo == "Range" and ipeg.fLRV then
	       local i = edit.icode[ipeg.fLRV]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end	       
	       if i < 1 then i = #edit.fonts end
	       ipeg.fLRV = edit.fonts[i]
	    end
	 end
      end
   end
   if subForm == 105 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 then
	 table.insert(stateSw, {switch=nil, dir=1, from="*", to="*", lastSw=0})
	 form.setFocusedRow(#stateSw + 1)
	 form.reinit(105)
      elseif key == KEY_2 then
	 local fr = form.getFocusedRow()
	 if fr - 1 > 0 then
	    stateSw[fr-1].switch = nil
	    switches["stateSwitch"..(fr-1)] = nil
	    table.remove(stateSw, fr - 1)
	 end
	 form.reinit(105)
      end
   end
end

local function changedSensor(val, i, ip)
   ip[i].SeId = InsP.sensorIdlist[val]
   ip[i].SePa = InsP.sensorPalist[val]
   ip[i].SeUn = InsP.sensorUnlist[val]
   ip[i].SeDp = InsP.sensorDplist[val]
end

local function panelChanged(val, sp)
   local fn
   local pv = InsP.settings.panels[val]

   if val ~= 1 then
      fn = pDir .. "/"..pv..".json"
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

local function backGndChanged(val,sp)
   local bv = InsP.settings.backgrounds[val]
   if val ~= 1 then
      backImg = lcd.loadImage(bDir .. "/"..bv..".png")
      InsP.panelImages[sp].backImage = bv
   else
      backImg = nil
      InsP.panelImages[sp].backImage = nil
   end
end

local function changedSwitch(val, switchName, j)
   local Invert = 1.0

   local swInfo = system.getSwitchInfo(val)

   local swTyp = string.sub(swInfo.label,1,1)
   if swInfo.assigned then
      if string.sub(swInfo.mode,-1,-1) == "I" then Invert = -1.0 end
      if swInfo.value == Invert or swTyp == "L" or swTyp =="M" then
	 switches[switchName] = val
	 InsP.settings.switchInfo[switchName] = {} 
	 if j then -- special adder for sequencer screen (sorry)
	    InsP.settings.switchInfo[switchName].seqIdx = j
	    stateSw[j].switch = val
	 end
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

local function changedMinMax(val, sel, ipig)
   ipig[sel] = val
end

local function changedLabel(val, ipig, f)
   val = string.gsub(val, "''", "'")
   val = string.gsub(val, "'d", "°")
   ipig.label = val
   form.reinit(f)
end

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
      
      local sp = InsP.panelImages[InsP.settings.selectedPanel].instImage
      form.setTitle(string.format("Selected Panel: %s", sp))
      
      form.addRow(2)
      form.addLabel({label="Panels >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(106)
	       form.waitForRelease()
      end))      

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
      form.addLabel({label="Edit Links >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(105)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Reset data >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(101)
	       form.waitForRelease()
      end))
      
      form.setFocusedRow(savedRow)
   elseif sf == 100 then

      local ip = InsP.panels[InsP.settings.selectedPanel]
      form.setTitle("Sensors for Panel " ..
		       InsP.panelImages[InsP.settings.selectedPanel].instImage)

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
	 local isel = 1
	 for k, _ in ipairs(InsP.sensorLalist) do
	    if id == InsP.sensorIdlist[k] and pa == InsP.sensorPalist[k] then
	       isel = k
	       break
	    end
	 end
	 form.addLabel({label=InsP.sensorLslist[isel], width=100})
      end
      form.setFocusedRow(savedRow2)
   elseif sf == 101 then
      io.remove(InsP.settings.fileBD)
      InsP.settings.writeBD = false
      system.messageBox("All data deleted .. Restart App")
      form.reinit(1)
   elseif sf == 102 then
      
      form.setTitle("Settings for all Panels ")

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
   elseif sf == 104 then -- edit item on sensor menu
      local ig = savedRow3
      local ip = InsP.panels[InsP.settings.selectedPanel]
      local lbl = ip[ig].label or "Gauge"..ig
      form.setTitle("Edit Gauge "..ig.."  ("..lbl..")", savedRow3)

      local widget = ip[ig]
      local id = widget.SeId
      local pa = widget.SePa
      local isel = 1
      for k, _ in ipairs(InsP.sensorLalist) do
	 if id == InsP.sensorIdlist[k] and pa == InsP.sensorPalist[k] then
	    isel = k
	    break
	 end
      end
      form.addRow(2)
      form.addLabel({label="Sensor", width=80})
      form.addSelectbox(InsP.sensorLalist, isel, true,
			(function(x) return changedSensor(x, ig, ip) end),
			{width=240, alignRight=true})

      form.addRow(4)
      form.addLabel({label="Gauge Min", width=90})
      if ip[ig].min then
	 if ip[ig].subdivs == 0 then
	    form.addIntbox(ip[ig].min, -32768, 32767, 0, 0, 1,
			   (function(x) return changedMinMax(x, "min", ip[ig]) end),
			   {width=70})
	 else
	    form.addLabel({label=string.format("%d", ip[ig].min), width=70, alignRight=true})
	 end
      else
	    form.addLabel({label="---", width=70, alignRight=true})
      end
      form.addLabel({label="Gauge Max", width=90})
      if ip[ig].max then
	 if ip[ig].subdivs == 0 then
	    form.addIntbox(ip[ig].max, -32768, 32767, 0, 0, 1,
			   (function(x) return changedMinMax(x, "max", ip[ig]) end),
			   {width=70})
	 else
	    form.addLabel({label=string.format("%d", ip[ig].max), width=70, alignRight=true})
	 end
      else
	 form.addLabel({label="---", width=70, alignRight=true})
      end

      form.addRow(2)
      form.addLabel({label="Label", width=60})
      form.addTextbox(lbl, 63,
		      (function(x) return changedLabel(x, ip[ig], sf) end),
		      {width=245})

      form.addRow(2)
      form.addLabel({label="Enable min/max value markers", width=270})
      local isel = ip[ig].showMM == "true"
      mmCI = form.addCheckbox(isel, (function(x) return changedShowMM(x, ip[ig]) end), {width=60} )

      if ip[ig].max and ip[ig].min then
	 form.addRow(2)
	 form.addLabel({label="Max warning value"})
	 if not ip[ig].maxWarn then ip[ig].maxWarn = ip[ig].max end
	 form.addIntbox(ip[ig].maxWarn, ip[ig].min, ip[ig].max, ip[ig].max, 0, 1,
			(function(x) return changedMinMax(x, "maxWarn", ip[ig]) end))
	 
	 form.addRow(2)
	 form.addLabel({label="Min warning value"})
	 if not ip[ig].minWarn then ip[ig].minWarn = ip[ig].min end
	 form.addIntbox(ip[ig].minWarn, ip[ig].min, ip[ig].max, ip[ig].min, 0, 1,
			(function(x) return changedMinMax(x, "minWarn", ip[ig]) end))
      end
      
      form.setFocusedRow(1)
   elseif sf == 105 then
      local function dirChanged(val, j)
	 stateSw[j].dir = val
	 form.reinit(105)
      end

      local function fromChanged(val, j)
	 stateSw[j].from = InsP.panelImages[val-1].instImage
	 form.reinit(105)
      end
      
      local function toChanged(val, j)
	 stateSw[j].to = InsP.panelImages[val-1].instImage
	 form.reinit(105)
      end

      form.setTitle("Sequence switch setup")
      
      form.setButton(1, ":add", 1)
      form.setButton(2, ":delete", 1)
      form.addRow(1)
      form.addLabel({label="  Sw         Trig           From               To"})
      local ipi = InsP.panelImages
      local teleLabel={}
      teleLabel[1] = "*"
      for i in ipairs(ipi) do
	 teleLabel[i+1] = ipi[i].instImage
      end
      for j in ipairs(stateSw) do
	 local to = 1
	 local from = 1
	 for i in ipairs(ipi) do
	    if ipi[i].instImage == stateSw[j].to then to = i+1 end
	    if ipi[i].instImage == stateSw[j].from then from = i+1 end
	 end
	 form.addRow(5)
	 local stateSwitchN = "stateSwitch"..j
	 swtCI[stateSwitchN] = form.addInputbox(switches[stateSwitchN], false,
					      (function(x)
						    return
						    changedSwitch(x, stateSwitchN, j)
					      end),
					      {width=50})
	 form.addSelectbox({"+", "-"}, stateSw[j].dir, false,
	    (function(x) return dirChanged(x,j)  end), {width=70})
	 form.addSelectbox(teleLabel, from, true,
			   (function(x) return fromChanged(x,j) end), {width=100})
	 form.addSelectbox(teleLabel, to  , true,
			   (function(x) return toChanged(x,j)   end), {width=100})
      end
   elseif sf == 106 then
      form.setTitle("Edit Panels")

      form.setButton(1, "Select", ENABLED)
      form.setButton(2, "Home", ENABLED)
      form.setButton(3, ":add", ENABLED)
      form.setButton(4, ":delete", ENABLED)

      form.addRow(4)
      form.addLabel({label=" ", width=40})
      form.addLabel({label="#", width=20})
      form.addLabel({label="Panel     ", width=110, alignRight = true})
      form.addLabel({label="Background", width=110, alighRight = true})
      
      for i, img in ipairs(InsP.panelImages) do
	 form.addRow(4)
	 local lbl=""
	 if i == InsP.settings.selectedPanel then
	    lbl = lbl .. "S"
	 end
	 if i == InsP.settings.homePanel then
	    lbl = lbl .. "H"
	 end
	 form.addLabel({label=lbl, width=40})

	 form.addLabel({label=i, width=20})

	 local sp = InsP.settings.selectedPanel
	 local pnl = InsP.panelImages[i].instImage
	 local isel = 0
	 if InsP.settings.panels then
	    for i, p in ipairs(InsP.settings.panels) do
	       if p == pnl then
		  isel = i
		  break
	       end
	    end
	 end
	 form.addSelectbox(InsP.settings.panels, isel, true,
			   (function(x) return panelChanged(x, i) end),
			   {width=110})
	 
	 local bak = InsP.panelImages[i].backImage
	 isel = 0
	 for i, p in ipairs(InsP.settings.backgrounds) do
	    if p == bak then
	       isel = i
	       break
	    end
	 end
	 form.addSelectbox(InsP.settings.backgrounds, isel, true,
			   (function(x) return backGndChanged(x, i) end),
			   {width=110})      
      end
      local isp = InsP.settings.selectedPanel
      if  isp >= 1 and isp <= #InsP.panelImages then
	 form.setFocusedRow(isp+1)
      end
   end
end

local swrLast
local swpLast
local lastindex = 0

local function loop()

   local sensor
   local swr, swp, swt

   local isp = InsP.panels[InsP.settings.selectedPanel]
   if not isp then return end

   -- see if sequencer has triggered a change
   
   local ipi = InsP.panelImages
   local sp  = InsP.settings.selectedPanel
   
   for i in ipairs(stateSw) do
      if not stateSw[i].lastSw then stateSw[i].lastSw = swt end
      local swt = system.getInputsVal(stateSw[i].switch)
      if swt and stateSw[i] and stateSw[i].lastSw ~= 0 and (swt ~= stateSw[i].lastSw) then
	 -- "pos" is index 1 and "neg" is index 2
	 if (swt == 1 and stateSw[i].dir == 1) or (swt == -1 and stateSw[i].dir == 2) then
	    if stateSw[i].from == "*" or stateSw[i].from == ipi[sp].instImage then
	       system.messageBox("Panel switching to: " .. stateSw[i].to)
	       setToPanelName(stateSw[i].to)
	    end
	 end
      end
      stateSw[i].lastSw = swt
   end
   
   -- see if we need to rotate panels from the manual switch

   swp = system.getInputsVal(switches.rotatePanels)
   if not swpLast then swpLast = swp end
   local is = InsP.settings
   local ip = InsP.panels
   if swp and swp == 1 and swpLast ~= 1 then
      local temp = is.selectedPanel
      temp = temp + 1
      if temp > #ip  then is.selectedPanel = 1 else is.selectedPanel = temp end

      setToPanel(is.selectedPanel)
   end
   swpLast = swp
   
   -- see if the reset min/max switch has moved
   
   swr = system.getInputsVal(switches.resetMinMax)
   if not swrLast then swrLast = swr end
   if swr and swr == 1 and swrLast ~= 1 then
      for _, widget in ipairs(ip) do
	 for k, _ in pairs(widget) do
	    if k == "minval" or k == "maxval" then widget[k] = nil end
	 end
      end
   end
   swrLast = swr

   -- update min and max values
   
   for _, widget in ipairs(ip) do
      sensor = getSensorByID(widget.SeId, widget.SePa)	 
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

   -- throttle the update rate of tele sensors by moving the upper loop index up and
   -- down to determine how many updates are done per Hollywood call

   if system.getTimeCounter() - lua.txTelLastUpdate > 200 then
      lua.txTel = system.getTxTelemetry()
      lua.txTelLastUpdate = system.getTimeCounter()
   end
   
   for k = 1, 10 do
      --[[
      if lua.index == 1 then
	 print("time", system.getTimeCounter() - lastindex)
	 lastindex = system.getTimeCounter()
      end
      --]]
      lua.index = lua.index + 1
      if lua.index <= #InsP.sensorLalist then
	 local SeId = InsP.sensorIdlist[lua.index]
	 local SePa = InsP.sensorPalist[lua.index]
	 local sensor = getSensorByID(SeId, SePa)
	 if sensor and sensor.valid then
	    lua.env[InsP.sensorLalist[lua.index]] = sensor.value
	 end
      else
	 lua.index = 1
	 lua.completePass = true
      end
   end
end


local function printForm()

   local ctl, ctlmin, ctlmax
   local rot, rotmin, rotmax
   local factor
   local sensor
   local sp = InsP.settings.selectedPanel
   local ip = InsP.panels[sp]

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

      sensor = getSensorByID(widget.SeId, widget.SePa)
      
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

      local luaStr = ""
      local err, status, result
      if widget.lua and lua.completePass then
	 if not lua.chunk[sp] then
	    lua.chunk[sp] = {}
	 end
	 if not lua.chunk[sp][i] then
	    lua.chunk[sp][i], err = load("return "..widget.lua,"","t",lua.env)
	    if err then
	       print("DFM-InsP - lua load error: " .. err)
	       luaStr = "Check lua console"
	    end
	 end
	 if not err then
	    --print("pcall", sp, i)
	    status, result = pcall(lua.chunk[sp][i])
	    if not status then
	       print("DFM-InsP - lua pcall error .. " .. result)
	       luaStr = "Check lua console"
	    else
	       luaStr = result
	    end
	 end
      end

      if widget.type == "roundGauge" then

	 local val

	 if sensor and sensor.valid then val = sensor.value end


	 if val and
	    ( (widget.maxWarn and val > widget.maxWarn) or
	    (widget.minWarn and val < widget.minWarn) ) then
	    if (system.getTimeCounter() // 500) % 2 == 0 then
	       local ren = lcd.renderer()
	       ren:reset()
	       for th = 0, 2 * math.pi, 2 * math.pi / 20 do
		  ren:addPoint(
		     widget.x0 + 0.85 * widget.radius * math.sin(th),
		     widget.y0 + 0.85 * widget.radius * math.cos(th)
		  ) 
	       end
	       if val > widget.maxWarn then
		  lcd.setColor(255,0,0)
	       else
		  lcd.setColor(0,0,255)
	       end
	       ren:renderPolygon(0.6)
	    end
	 end
	 
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

	 local val
	 if sensor and sensor.valid then
	    val = sensor.value
	 end

	 if not widget.xL then
	    widget.xL = widget.x0 
	    widget.yL = widget.y0
	 end

	 if not widget.xV then
	    widget.xV = widget.x0
	    widget.yV = widget.y0
	 end
	 
	 if not widget.fL then
	    widget.fL = "Bold"
	 end

	 local stro

	 if not widget.lua then
	    if i == 1 then
	       print("widget.value", widget.value, stro, widget.xL, widget.yL, widget.fL)
	    end
	    local str = widget.value or "---" 
	 	 if type(str) ~= "table" then
		    stro = str
		    for w in string.gmatch(str, "(%b'')") do
		       local q1, q2 = string.find(stro, w)
		       if q1 and q2 then
			  local v
			  local cc = string.sub(w,2,2)
			  if cc == 'v' then
			     if val then
				local fmt = string.format("%%.%df", widget.SeDp or 1)
				v = string.format(fmt, val)
			     else
				v = "---"
			     end
			  elseif cc == 'u' then
			     if widget.SeUn then
				v = widget.SeUn
			     else
				v = "--"
			     end
			  else
			     v = w
			  end
			  local b = string.sub(stro, 1, q1 - 1)
			  local a = string.sub(stro, q2 + 1, -1)
			  stro = b .. v .. a
		       end
		    end
		 else
		    local idx
		    if val then
		       idx = 1 + (val - 1) % #str -- 1,2,3,...#str....1,2,3,...#str
		    else
		       idx = 1
		    end
		    stro = str[idx]
		 end
	 else
	    stro = luaStr
	 end
	 
	 if i == 1 then
	    print("widget.value", widget.x0, widget.y0, widget.xL, widget.yL)
	 end
	 lcd.drawText(widget.xV - lcd.getTextWidth(edit.fcode[widget.fL], stro)/2,
		      widget.yV - lcd.getTextHeight(edit.fcode[widget.fL])/2,
		      stro, edit.fcode[widget.fL])
      end
   end
   lcd.drawText(300,140, system.getCPU(), FONT_MINI)
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

      local typ = edit.gaugeName[ipeg.type]
      if not typ then typ = "---" end
      
      local fn
      if ff then fn = "Font: " else fn = ""; ff = "" end
      
      lcd.drawText(10, 157,
		   string.format("Gauge %d Type: %s  [%d,%d]  %s %s",
				 edit.gauge, typ, xx, yy, fn, ff))
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
      save.stateSw = stateSw
      for k,v in pairs(stateSw) do
	 stateSw[k].switch = nil -- don't save switchitems .. reconstitute with other method
      end
      -- convert Id to hex, otherwise it comes in as a float and loss of precision
      -- creates invalid result on read
      if save.panels then
	 for i in ipairs(save.panels) do
	    if not save.panels[i] then print("nil panel", i) end
	    for _, v in ipairs(save.panels[i]) do
	       for kk,vv in pairs(v) do
		  if kk == "SeId" then v[kk] = string.format("0X%X", vv) end
	       end
	    end
	 end
      end
      -- don't save the list of panels and background images, read new each time we start
      if save.settings then
	 for k, _ in pairs(save.settings) do
	    if k == "panels" then save.settings.panels = {} end
	    if k == "backgrounds" then save.settings.backgrounds = {} end	       
	 end
      end
      fp = io.open(InsP.settings.fileBD, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
end

local function init()

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
	 initPanels(decoded)
	 decoded.stateSw = {}
      end
      for i=1, #decoded.panels do
	 InsP.panels[i] = decoded.panels[i]
      end
      for i=1, #decoded.panelImages do
	 InsP.panelImages[i] = decoded.panelImages[i]
      end
      InsP.settings = decoded.settings
      if not InsP.settings then InsP.settings = {} end

      stateSw = decoded.stateSw
      if not stateSw then stateSw = {} end

      decoded = nil
      
      for i in ipairs(InsP.panels) do
	 for _ ,v in ipairs(InsP.panels[i]) do
	    for kk,vv in pairs(v) do
	       if kk == "SeId" then v[kk] = tonumber(vv) end
	       if kk == "minval"  then v[kk] = nil end
	       if kk == "maxval"  then v[kk] = nil end
	    end
	 end
      end
   else
      print("DFM-InsP: Did not read any jsn panel file")
      initPanels(InsP)
      InsP.settings.homePanel = 1
   end
   InsP.settings.fileBD = ff
   InsP.settings.writeBD = true

   local is = InsP.settings
   is.selectedPanel = is.homePanel
   setToPanel(is.selectedPanel)
   
   -- Populate a table with all the panel json files
   -- in the Panels/ directory

   InsP.settings.panels = {'...'}
   local dd, fn, ext
   local path = prefix() .. pDir
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "json" then
	    ff = path .. "/" .. fn .. "." .. ext
	    file = io.open(ff)
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
   
   InsP.settings.backgrounds = {"..."}
   --local dd, fn, ext
   path = prefix() .. bDir
   for name, _, _ in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "png" then
	    ff = path .. "/" .. fn .. "." .. ext
	    file = io.open(ff)
	    if file then
	       if not InsP.settings.backgrounds then InsP.settings.backgrounds = {} end
	       table.insert(InsP.settings.backgrounds, fn)
	       io.close(file)
	    end
	 end
      end
   end

   table.sort(InsP.settings.backgrounds)

   for k, swi in pairs(InsP.settings.switchInfo) do
      switches[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
      local iss = InsP.settings.switchInfo[k]
      if iss.seqIdx and iss.seqIdx <= #stateSw then
	 stateSw[iss.seqIdx].switch = switches[k]
      end
   end
   
   readSensors(InsP)

   system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm, prtForm)
   system.registerTelemetry(1, "DFM-InsP - Instrument Panel", 4, printForm)

   appStartTime = system.getTimeCounter()

end

return {init=init, loop=loop, author="DFM", version=InsPVersion, name="DFM-InsP", destroy=destroy}

