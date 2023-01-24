--[[
   --------------------------------------------------------------------------------

   DFM-InsP.lua released under MIT license by DFM 2022
   
   This app is intended to render instrument panels where a json and image file
   are produced on Russell's dynamic content app creation/distribution website

   Started Dec 2022

   Version 0.2 01/12/23 - synch with near-final json format from the website panel maker
   Version 0.3 01/23/23 - lua integrated in sensors and text strings

   --------------------------------------------------------------------------------
--]]


local InsPVersion = 0.3

local LE

local InsP = {}
InsP.panels = {}
InsP.panelImages = {}
InsP.sensorLalist = {"..."}
InsP.sensorLslist = {"..."}
InsP.sensorIdlist = {0}
InsP.sensorPalist = {0}
InsP.sensorUnlist = {"-"}
InsP.sensorDplist = {0}
InsP.sensorTable = {}
InsP.variables = {}
   
local teleSensors, txTeleSensors
local txSensorNames = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		       "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		       "rxBVoltage", "rxBPercent", "photoValue"}
local txSensorUnits = {"V", "%", "mA", "mAh", "%", "V", "%", "V", "V", "%", " "}
local txSensorDP    = { 1,   0,    0,     0,   0,   1,   0,   1,   1,   0,   0}
local txRSSINames = {"rx1Ant1", "rx1Ant2", "rx2Ant1", "rx2Ant2",
		     "rxBAnt1", "rxBAnt2"}

InsP.settings = {}
InsP.settings.switchInfo = {}

local dataSources = {"Sensor", "Control", "Lua"} --, "Extension"}
local switches = {}
local stateSw = {}

local edit = {}
edit.ops = {"Center", "Value", "Label", "Text", "Range"}
edit.dir = {"X", "Y", "Font"}
edit.fonts = {"Mini", "Normal", "Bold", "Big", "Maxi", "None"}
edit.fcode = {Mini=FONT_MINI, Normal=FONT_NORMAL, Bold=FONT_BOLD, Big=FONT_BIG, Maxi=FONT_MAXI,
	      None=-1}
edit.icode = {Mini=1, Normal=2, Bold=3, Big=4, Maxi=5, None=6}

-- sn field is short name for edit window disp
-- en field is 1 (ENABLED) or 0 (DISABLED) appearance for edit button 2 depending on gauge type
-- en elements follow edit.ops

edit.gaugeName = {
   roundNeedleGauge={sn="NdlG", en={0,1,1,0,1}},
   roundArcGauge=   {sn="ArcG", en={0,1,1,0,1}},
   virtualGauge=    {sn="VirG", en={1,0,0,0,0}},
   horizontalBar=   {sn="HBar", en={0,0,1,0,0}},
   sequencedTextBox={sn="SeqT", en={0,0,1,1,0}},
   stackedTextBox=  {sn="StkT", en={0,0,1,1,0}},
   panelLight=      {sn="PnlL", en={1,0,1,0,0}},
   rawText=         {sn="RawT", en={1,0,0,1,0}}
}

local lua = {}
--lua.chunk = {}
lua.env = {string=string, math=math, table=table, print=print,
	   tonumber=tonumber, tostring=tostring, pairs=pairs,
	   require=require, ipairs=ipairs, abs = math.abs, type=type,
	   getSensorByID=(function(a1,a2) return system.getSensorByID(a1,a2) end)
}

lua.ext = {}
lua.index = 0
lua.txTelLastUpdate = 0
lua.txTel = {}
lua.completePass = false

local subForm = 0
local pDir = "Apps/DFM-InsP/Panels"
local bDir = "Apps/DFM-InsP/Backgrounds"
local instImg, instImgA
local backImg, backImgA


local savedRow = 1
local savedRow2 = 1
local savedRow3 = 1
local mmCI
local swtCI ={}

local auxWin = 1
local auxWinLast = 0

local appStartTime
local loopCPU = 0
local editText

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
local rectangle = {
   {-2,  -4},
   { 2,  -4},
   { 2,  -10},
   {-2,  -10}
}
--[[
local triangle = {
   {-4,1},
   {0,-5},
   {4,1}
}
--]]

local function getSensorByID(SeId, SePa)
   if not SeId or not SePa then return nil end
   if SeId ~= 0 then
      return system.getSensorByID(SeId, SePa)
   end
   if SePa > 0 then -- txTel named
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

   for i,v in ipairs(tt.sensorLalist) do
      tt.sensorTable[v] = {SeId = tt.sensorIdlist[i], SePa = tt.sensorPalist[i],
			   SeUn = tt.sensorUnlist[i], SeDp = tt.sensorDplist[i]}
   end
   
end

local function initPanels(tbl)
   tbl.panels = {}
   tbl.panels[1] = {}
   tbl.panelImages = {}
   tbl.panelImages[1] = {}
   tbl.panelImages[1].instImage = "---"
   tbl.panelImages[1].backImage = "---"
   tbl.panelImages[1].auxWin = 1
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

local function drawArc(theta, x0, y0, a0, ri, ro, im, alp)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*theta/im), y0 - ro * math.sin(a0 + i*theta/im))
   end
   
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*theta/im), y0 - ri * math.sin(a0+i*theta/im))
   end
   ren:renderPolygon(alp)
end

local function setToPanel(iisp)
   local fn
   local isp = iisp
   if isp < 1 then isp = 1 end
   if isp > #InsP.panels then isp = #InsP.panels end
   InsP.settings.selectedPanel = isp

   if not InsP.panels[isp] then
      fn = pDir .. "/"..InsP.settings.panels[isp]..".json"
      local file = io.readall(fn)
      InsP.panels[isp] = json.decode(file)
   end

   local pv = InsP.panelImages[isp].instImage
   if pv then
      instImg = lcd.loadImage(pDir .. "/"..pv..".png")
   else
      instImg = nil
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
      setToPanel(isel)
   end
end


local pCallErr = 0
local luaLoadErr = 0

local function evaluateLua(es, luastring, val)
   local luaReturn = ""
   local err, status, result
   local varenv = {}

   -- for now, copy the std env and add the variables each time we are called
   -- inefficient but can improve later
   -- assume that setVariables has been called first so that all variables are
   -- up-to-date
   
   for k,v in pairs(lua.env) do
      varenv[k] = v
   end

   --local sn
   for i,v in ipairs(InsP.variables) do
      --sn = InsP.sensorLalist[v.sensor]
      --InsP.variables[i].value = lua.env[sn]
      varenv[v.name] = v.value
   end

   varenv["ptr"] = InsP
   if val then varenv["val"] = val end
   
   if luastring and lua.completePass then
      if es == "E" then
	 lua.chunk, err = load("return "..luastring,"","t", varenv)
      elseif es == "S" then
	 lua.chunk, err = load(luastring,"","t", varenv)
      else
	 err = "lua exp or stmt not present"
      end
      
      if err then
	 luaLoadErr = luaLoadErr + 1
	 if luaLoadErr < 10 then
	    print("DFM-InsP - lua load error: " .. err)
	 end
	 luaReturn = "Check lua console"
      end
      
      if not err then
	 status, result = pcall(lua.chunk)
	 if not status then
	    pCallErr = pCallErr + 1
	    if pCallErr < 10 then
	       print("DFM-InsP - pcall error: " .. result)
	       print("DFM-InsP - lua: ", luastring)
	    end
	    
	    luaReturn = "Check lua console"
	 else
	    luaReturn = result
	 end
      end
   end
   return luaReturn or "<lua return nil>"
end

local function setVariables()
   for i, var in ipairs(InsP.variables) do
      if InsP.variables[i].source == 1 then
	 local name = InsP.sensorLalist[var.sensor]
	 --print("setV 1", i, var, name, lua.env[name])
	 InsP.variables[i].value = lua.env[name]
      elseif InsP.variables[i].source == 2 then
	 InsP.variables[i].value = evaluateLua("E", InsP.variables[i].luastring[1])
	 if type(InsP.variables[i].value) ~= "number" then
	    InsP.variables[i].value = 0
	 end
	 --print("setV 2", InsP.variables[i].value, type(InsP.variables[i].value))
	 --print("setV 2", i, var.name, "*"..var.value.."*", InsP.variables[i].luastring[1])
      end
   end
end

local function evaluate(es, luastring, val)
   setVariables()
   return evaluateLua(es, luastring, val)
end

local function expandStr(stri, val, SeDp, SeUn)

   local str, stro
   
   if not stri then return "" end
   
   -- first check if it's lua expression

   if string.find(stri, "luaE:") == 1 then
      return evaluate("E", string.sub(stri, 6, -1), val)
   end

   if string.find(stri, "luaS:") == 1 then
      return evaluate("S", string.sub(stri, 6, -1), val)
   end

   -- or an escaped :luaE or :luaS
   
   if string.find(stri, "%%luaE:") == 1 or string.find(stri, "%%luaS:") == 1 then 
      str = string.sub(stri, 2, -1)
   else
      str = stri
   end

   -- if not .. substitute sensor value for 'v', sensor unit for 'u'
   
   stro = str
   for ww in string.gmatch(str, "(%b'')") do
      local q1, q2 = string.find(stro, ww)
      if q1 and q2 then
	 local v
	 local bb,aa
	 local fmt
	 local cc = string.sub(ww,2,2)
	 local dd = string.sub(ww,2,-2)
	 bb,aa = string.match(dd, "(.+)%.(.+)")
	 if aa and (aa == "0") then fmt = "%.0f" end
	 if aa and (aa == "1") then fmt = "%.1f" end
	 if aa and (aa == "2") then fmt = "%.2f" end
	 if cc == 'v' then
	    if val then
	       if not fmt then
		  fmt = string.format("%%.%df", SeDp or 1)
	       end
	       v = string.format(fmt, val)
	    else
	       v = "---"
	    end
	 elseif cc == 'u' then
	    if SeUn then
	       v = SeUn
	    else
	       v = ""
	    end
	 else -- see if the single quoted item is a variable .. else leave it in
	    setVariables()
	    cc = string.sub(ww, 2, -2)
	    v = ww
	    --print("ww,cc", ww, cc, bb, aa, fmt)
	    if aa then cc = bb end
	    for i,var in ipairs(InsP.variables) do
	       if cc == var.name then
		  --print("match", cc, var.value)
		  if var.value then
		     --print("var.value", var.value, type(var.value))
		     if type(var.value) == "number" then
			if fmt then
			   v = string.format(fmt, var.value)
			else
			   v = string.format("%.2f", var.value)
			end
		     else
			v="---"
		     end
		  else
		     v = ww
		  end
		  break
	       end
	    end
	 end
	 local b = string.sub(stro, 1, q1 - 1)
	 local a = string.sub(stro, q2 + 1, -1)
	 stro = b .. v .. a
      end
   end
   return stro
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

   if subForm == 108 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end

      if key == KEY_3 then -- add variable
	 local l = #InsP.variables + 1
	 table.insert(InsP.variables,
		      {name="S"..l, source = 1, luastring={}, sensor = 0, SeID = 0, SePa = 0})
	 form.reinit(108)
	 return
      end

      if key == KEY_2 then -- remove variable
	 local row = form.getFocusedRow()
	 table.remove(InsP.variables, row)
	 form.reinit(108)
	 return
      end
   end
   
   if subForm == 107 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end

      --print("107, savedRow, savedRow2", savedRow, savedRow2)
      
      if savedRow == 3 then -- sensors top level command
	 local sp = InsP.settings.selectedPanel
	 --print("sp, savedRow, savedRow2", sp, savedRow, savedRow2)
	 if not InsP.panels[sp][savedRow2].luastring then
	    InsP.panels[sp][savedRow2].luastring = {}
	 end
	 LE.luaEditKey(InsP.panels[sp][savedRow2], 1, key, evaluate)
      elseif savedRow == 6 then -- lua variables top level command
	 --print("about to editkey", InsP.variables[savedRow2].name)
	 LE.luaEditKey(InsP.variables[savedRow2], 1, key, evaluate)	 
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
	 InsP.panelImages[is.selectedPanel].auxWin = 1
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
	 --lua.chunk = {} -- will need to re-read all lua chunks 
	 form.reinit(106)
      end
   end
   
   if subForm == 100 then
      if keyExit(key) and key ~= KEY_ENTER then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 or key == KEY_ENTER then -- edit
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

   if subForm == 110 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(103)
	 return
      end
   end
   
   if subForm == 103 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      local ipsp = InsP.panels[InsP.settings.selectedPanel]
      local ipeg = ipsp[edit.gauge] 
      local en
      if key == KEY_1 then
	 edit.gauge = edit.gauge + 1
	 if edit.gauge > #ipsp then edit.gauge = 1 end
	 ipeg = ipsp[edit.gauge] 
	 en = edit.gaugeName[ipeg.type].en[edit.opsIdx]
	 form.setButton(2, string.format("%s", edit.ops[edit.opsIdx]), en)
	 local en4
	 if ipeg.text then en4 = ENABLED else en4 = DISABLED end
	 form.setButton(4, "Edit", en4)
      elseif key == KEY_2 then
	 edit.opsIdx = edit.opsIdx + 1
	 if edit.opsIdx > #edit.ops then edit.opsIdx = 1 end
	 en = edit.gaugeName[ipeg.type].en[edit.opsIdx]
	 --print("ipeg", ipeg, ipeg.type, edit.opsIdx, en)
	 form.setButton(2, string.format("%s", edit.ops[edit.opsIdx]), en)
      elseif key == KEY_3 then
	 edit.dirIdx = edit.dirIdx + 1
	 if edit.dirIdx > #edit.dir then edit.dirIdx = 1 end
	 form.setButton(3, string.format("%s", edit.dir[edit.dirIdx]), ENABLED)	 
      elseif key == KEY_4 then
	 editText = ipeg
	 form.reinit(110)
      elseif key == KEY_UP or key == KEY_DOWN then
	 local inc
	 if key == KEY_UP then inc = 1 else inc = -1 end
	 local eo = edit.ops[edit.opsIdx]
	 local ed = edit.dir[edit.dirIdx]
	 if ed == "X" then
	    if eo == "Value" and ipeg.xV then
	       ipeg.xV = ipeg.xV + inc
	    end
	    
	    if eo == "Label" and ipeg.xL then
	       ipeg.xL = ipeg.xL + inc
	    end

	    if eo == "Text" and ipeg.xT then
	       ipeg.xT = ipeg.xT + inc
	    end
	    
	    if eo == "Range" and ipeg.xLV and ipeg.xRV then
	       ipeg.xLV = ipeg.xLV + inc
	       ipeg.xRV = ipeg.xRV - inc
	    end

	    if eo == "Center" and ipeg.xPL then
	       ipeg.xPL = ipeg.xPL + inc
	    end

	    if eo == "Center" and ipeg.xRT then
	       ipeg.xRT = ipeg.xRT + inc
	    end

	 elseif ed == "Y" then
	    if eo == "Value" and ipeg.yV then
	       ipeg.yV = ipeg.yV + inc
	    end
	    
	    if eo == "Label" and ipeg.yL then
	       ipeg.yL = ipeg.yL + inc	       
	    end

	    if eo == "Text" and ipeg.yT then
	       ipeg.yT = ipeg.yT + inc
	    end
	    
	    if eo == "Range" and ipeg.yLV and ipeg.yRV then
	       ipeg.yLV = ipeg.yLV + inc
	       ipeg.yRV = ipeg.yRV + inc
	    end

	    if eo == "Center" and ipeg.xPL then
	       ipeg.yPL = ipeg.yPL + inc
	    end

	    if eo == "Center" and ipeg.yRT then
	       ipeg.yRT = ipeg.yRT + inc
	    end

	 elseif ed == "Font" then
	    if eo == "Value" and ipeg.fV then
	       local i = edit.icode[ipeg.fV]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       --print("Setting .fV")
	       ipeg.fV = edit.fonts[i]
	    end
	    
	    if eo == "Label" and ipeg.fL then
	       local i = edit.icode[ipeg.fL]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       ipeg.fL = edit.fonts[i]
	    end

	    if eo == "Text" and ipeg.fT then
	       local i = edit.icode[ipeg.fT]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end
	       if i < 1 then i = #edit.fonts end
	       ipeg.fT = edit.fonts[i]
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
   ip[i].SeLa = InsP.sensorLalist[val]
   --print("i, SeLa", i, InsP.sensorLalist[val])
end

local function panelChanged(val, sp)
   local fn
   local pv = InsP.settings.panels[val]
   if val ~= 1 then
      fn = pDir .. "/"..pv..".json"
      --print("panelChanged reading", fn, sp)
      local file = io.readall(fn)
      local bi = InsP.panelImages[sp].backImage
      InsP.panels[sp] = json.decode(file)
      --lua.chunk = {} -- need to compute any chunks for this panel
      if not instImg then
	 instImg = lcd.loadImage(pDir .. "/"..pv..".png")
      end
      InsP.panelImages[sp].instImage = pv
      InsP.panelImages[sp].backImage = bi
   else
      instImg = nil
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

local function auxWinChanged(val,sp)
   --print("twx", sp, val)
   InsP.panelImages[sp].auxWin = val
end

local function changedSwitch(val, switchName, j, wid)
   local Invert = 1.0

   local swInfo = system.getSwitchInfo(val)

   local swTyp = string.sub(swInfo.label,1,1)
   if swInfo.assigned then
      if string.sub(swInfo.mode,-1,-1) == "I" then Invert = -1.0 end
      local prop = string.find(swInfo.mode, "P")
      if prop or swInfo.value == Invert or swTyp == "L" or swTyp =="M" then
	 switches[switchName] = val
	 InsP.settings.switchInfo[switchName] = {} 
	 if j then -- special adder for sequencer screen (sorry)
	    InsP.settings.switchInfo[switchName].seqIdx = j
	    stateSw[j].switch = val
	 end
	 if wid then
	    wid.control = switchName
	 end
	 InsP.settings.switchInfo[switchName].name = swInfo.label
	 if swTyp == "L" or swTyp =="M" then
	    InsP.settings.switchInfo[switchName].activeOn = 0
	 else
	    local ao = system.getInputs(string.upper(swInfo.label))
	    InsP.settings.switchInfo[switchName].activeOn = ao
	    --if ao > -1.0 and ao < 1.0 and swInfo.mode == "S" then swInfo.mode = "P" end
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

local function changedDataSrc(val, wid)
   wid.dataSrc = dataSources[val]
   form.reinit(104)
end

local function changedMultiplier(val, wid)
   wid.multiplier = val
end

local function initForm(sf)

   subForm = sf

   if sf == 1 then
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
      form.addLabel({label="Lua variables >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(108)
	       form.waitForRelease()
      end))


      form.setFocusedRow(savedRow)
   elseif sf == 100 then

      local ip = InsP.panels[InsP.settings.selectedPanel]
      form.setTitle("Data for panel " ..
		       InsP.panelImages[InsP.settings.selectedPanel].instImage)

      form.setButton(1, ":edit", ENABLED)
      
      if not ip or #ip == 0 then
	 form.addRow(1)
	 form.addLabel({label="No instrument panel defined"})
	 form.addRow(1)
	 form.addLabel({label="Use Panels>> to select a panel"})
	 form.setFocusedRow(1)
	 return
      end
      
      for i, widget in ipairs(ip) do
	 form.addRow(3)
	 local str
	 if widget.label then str = "  "..widget.label else str = "" end
	 local typ = edit.gaugeName[widget.type].sn
	 if not typ then typ = "---" end
	 form.addLabel({label = string.format("%d %s", i, typ), width=60})
	 form.addLabel({label = string.format("%s", str), width=160})
	 if not widget.dataSrc then widget.dataSrc = "Sensor" end
	 if widget.dataSrc == "Sensor" then
	    local id = widget.SeId
	    local pa = widget.SePa
	    local isel = 1
	    for k, _ in ipairs(InsP.sensorLalist) do
	       if id == InsP.sensorIdlist[k] and pa == InsP.sensorPalist[k] then
		  isel = k
		  break
	       end
	    end
	    if InsP.sensorLslist[isel] == "..." and typ == "StkT" then
	       form.addLabel({label="<Text>", width=100})
	    else
	       form.addLabel({label=InsP.sensorLslist[isel], width=100})
	    end
	    
	 elseif widget.dataSrc == "Control" then
	    local info = system.getSwitchInfo(switches[widget.control])
	    if info then
	       form.addLabel({label="<C:"..info.label..">", width=100})
	    else
	       form.addLabel({label="<C:--->", width=100})	       
	    end
	 elseif widget.dataSrc == "Lua" then
	    form.addLabel({label="<Lua>"})
	 elseif widget.dataSrc == "Extension" then
	    form.addLabel({label="<Ext>"})
	 end
	 
      end
      form.setFocusedRow(savedRow2)
   elseif sf == 101 then
      local ans
      ans = form.question("Are you sure?", "Reset all app settings?",
			  "",
			  0, false, 5)
      if ans == 1 then
	 io.remove(InsP.settings.fileBD)
	 InsP.settings.writeBD = false
	 system.messageBox("All data deleted .. Restart App")
      end
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

      form.addRow(2)
      form.addLabel({label="Reset all app data >>", width=220})
      form.addLink((function()
	       form.reinit(101)
	       form.waitForRelease()
      end))
      
      form.setFocusedRow(savedRow2)
   elseif sf == 103 then
      form.setTitle("")
      edit.gauge = 1
      edit.opsIdx = 1
      edit.dirIdx = 2 -- default to "Y"
      form.setButton(1, "Select", ENABLED)
      local ipsp = InsP.panels[InsP.settings.selectedPanel]
      local ipeg = ipsp[edit.gauge] 
      local en = edit.gaugeName[ipeg.type].en[edit.opsIdx]
      form.setButton(2, string.format("%s", edit.ops[edit.opsIdx]), en)
      form.setButton(3, string.format("%s", edit.dir[edit.dirIdx]), ENABLED)
      local en4
      --[[
      print("type of ipeg.text", type(ipeg.text))
      if type(ipeg.text) == "string" then
	 print("ipeg.text", ipeg.text)
      elseif type(ipeg.text) == "table" then
	 print("ipeg.text[1]", ipeg.text[1])
      end
      --]]
      if ipeg.text then en4 = ENABLED else en4 = DISABLED end
      form.setButton(4, "Edit", en4)
   elseif sf == 104 then -- edit item on sensor menu
      local ig = savedRow3
      local isp = InsP.settings.selectedPanel
      local ip = InsP.panels[isp]
      local lbl = ip[ig].label or "Gauge"..ig
      local pnl = InsP.panelImages[isp].instImage

      form.setTitle("Edit Gauge "..ig.."  ("..lbl..")", savedRow3)

      local widget = ip[ig]

      if not widget.dataSrc then widget.dataSrc = "Sensor" end

      form.addRow(2)
      form.addLabel({label="Gauge input source"})
      local isel = 0
      for k in ipairs(dataSources) do
	 if widget.dataSrc == dataSources[k] then
	    isel = k
	    break
	 end
      end
      form.addSelectbox(dataSources, isel, true,
			(function(x) return changedDataSrc(x, widget) end) )

      if widget.dataSrc == "Sensor" then
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
      elseif widget.dataSrc == "Control" then
	 form.addRow(2)
	 form.addLabel({label="Control", width=80})
	 local ctrlName = pnl .. "-" .. string.gsub(lbl, "%W", "_") 
	 print("check ctrlName for uniqueness!")
	 --print("ctrlName", ctrlName)
	 swtCI[ctrlName] = form.addInputbox(switches[ctrlName], true,
					    (function(x) return changedSwitch(x, ctrlName,
									      nil, widget) end),
					    {width=240, alignRight=true})
	 form.addRow(2)
	 form.addLabel({label="Control multiplier", width=240})
	 if not widget.multiplier then print("init mult") widget.multiplier = 100.0 end
	 form.addIntbox(widget.multiplier, -10000, 10000, 100, 0, 1,
			(function(x) return changedMultiplier(x, widget) end) )
	 
      elseif widget.dataSrc == "Lua" then
	 form.addRow(1)
	 --form.addLabel({label="Edit lua >>", width=220})
	 form.addLink((function()
		  form.reinit(107)
		  form.waitForRelease()
		      end), {label="Edit Lua>>"})
      elseif widget.dataSrc == "Extension" then
	 print("Extension")
      end
      
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
      isel = ip[ig].showMM == "true"
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
	 swtCI[stateSwitchN] = form.addInputbox(switches[stateSwitchN], true,
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

      form.addRow(5)
      form.addLabel({label=" ", width=30})
      form.addLabel({label="#", width=20})
      form.addLabel({label="Panel     ", width=105, alignRight = true})
      form.addLabel({label="Background  ", width=105, alignRight = true})
      form.addLabel({label="Aux", width=50, alignRight = false})      
      
      local pp = {} 
      for k in ipairs(InsP.panelImages) do
	 pp[k] = tostring(k)
      end
      
      for i in ipairs(InsP.panelImages) do
	 form.addRow(5)
	 local lbl=""
	 if i == InsP.settings.selectedPanel then
	    lbl = lbl .. "S"
	 end
	 if i == InsP.settings.homePanel then
	    lbl = lbl .. "H"
	 end
	 form.addLabel({label=lbl, width=30})

	 form.addLabel({label=i, width=20})

	 --local sp = InsP.settings.selectedPanel
	 local pnl = InsP.panelImages[i].instImage
	 local isel = 0
	 if InsP.settings.panels then
	    for ii, p in ipairs(InsP.settings.panels) do
	       if p == pnl then
		  isel = ii
		  break
	       end
	    end
	 end
	 form.addSelectbox(InsP.settings.panels, isel, true,
			   (function(x) return panelChanged(x, i) end),
			   {width=105})
	 
	 local bak = InsP.panelImages[i].backImage
	 isel = 0
	 for ii, p in ipairs(InsP.settings.backgrounds) do
	    if p == bak then
	       isel = ii
	       break
	    end
	 end
	 form.addSelectbox(InsP.settings.backgrounds, isel, true,
			   (function(x) return backGndChanged(x, i) end),
			   {width=105})

	 isel = i + 1
	 if isel > #InsP.panelImages then isel = 1 end
	 form.addSelectbox(pp, isel, true,
	    (function(x) return auxWinChanged(x,i) end),
	    {width=50})
      end
      local isp = InsP.settings.selectedPanel
      if  isp >= 1 and isp <= #InsP.panelImages then
	 form.setFocusedRow(isp+1)
      end
   elseif sf == 107 then
      --print("about to luaEdit", savedRow, savedRow2)
      LE.luaEdit(InsP.variables, savedRow2)

   elseif sf == 108 then
      form.setTitle("Lua Variables")
      local function changedVariableName(val, i)
	 InsP.variables[i].name = val
      end

      local function changedSensor(val, i)
	 InsP.variables[i].sensor = val
	 InsP.variables[i].SeId = InsP.sensorIdlist[val]
	 InsP.variables[i].SePa = InsP.sensorPalist[val]
	 --print("Id, Pa", InsP.variables[i].SeId, InsP.variables[i].SePa)
      end

      local function changedSource(val, i)
	 InsP.variables[i].source = val
	 form.reinit(108)
      end
      
      form.setButton(3, ":add", ENABLED)
      form.setButton(2, ":delete", ENABLED)
      
      if #InsP.variables == 0 then
	 form.addRow(1)
	 form.addLabel({label="No lua variables defined"})
	 form.addRow(1)
	 form.addLabel({label="Press plus key to add new variables"})
	 form.setFocusedRow(1)
	 return
      end

      for i in ipairs(InsP.variables) do
	 form.addRow(4)
	 form.addLabel({label="Name", width=50})
	 form.addTextbox(InsP.variables[i].name, 63,
			 (function(x) return changedVariableName(x, i) end), {width=60})
	 if not InsP.variables[i].source then InsP.variables[i].source = 1 end
	 form.addSelectbox({"Sensor", "Lua"}, InsP.variables[i].source, true,
			   (function(x) return changedSource(x, i) end), {width=60})	    
	 if InsP.variables[i].source == 1 then
	    form.addSelectbox(InsP.sensorLalist, InsP.variables[i].sensor, true,
			      (function(x) return changedSensor(x, i) end), {width=150})
	 elseif InsP.variables[i].source == 2 then
	    form.addLink((function()
		     savedRow2 = form.getFocusedRow()
		     --print("lua edit var, savedRow2", savedRow2)
		     form.waitForRelease()
		     form.reinit(107)
			 end), {label="Edit Lua>>", width=120})
	 end

	 form.setFocusedRow(savedRow2)
	 
      end
      

   elseif sf == 110 then
      local function editCB(val, i)
	 editText.text[i] = val
      end
      form.setTitle("Text Editor")
      if type(editText.text) == "string" then -- isn't .text always an array?
	 form.addRow(1)
	 --print("#text", #editText.text)
	 if #editText.text <= 63 then
	    form.addTextbox(editText.text, 63,
			    (function(v)
				  editText.text = v
				  form.reinit(103)
			    end)
	    )
	 else
	    form.addLabel({label="Line too long to edit", alignRight=true})
	 end
	 
      else
	 for i, txt in ipairs(editText.text) do
	    form.addRow(1)
	    --print("#text", #editText.text[i])
	    if #editText.text[i] <= 63 then
	       form.addTextbox(editText.text[i], 63,
			       (function(v)
				     return editCB(v, i)
			       end)
	    ) else
		  form.addLabel({label="<Line too long to edit>", alignRight=true})
	    end
	    
	 end
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
      swt = system.getInputsVal(stateSw[i].switch)
      if not stateSw[i].lastSw then stateSw[i].lastSw = swt end
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
      for _, panel in pairs(ip) do
	 for _, gauge in pairs(panel) do
	    gauge.minval = nil
	    gauge.maxval = nil
	 end
      end
   end
   swrLast = swr
   
   -- update min and max values
   local ips = InsP.panels[sp]
   local val 
   for _, widget in ipairs(ips) do
      if widget.dataSrc == "Sensor" then
	 sensor = getSensorByID(widget.SeId, widget.SePa)
	 if sensor and sensor.valid then val = sensor.value end
      elseif widget.dataSrc == "Control" then
	 local info = system.getSwitchInfo(switches[widget.control])
	 if info then
	    val = (widget.multiplier or 100.0) * info.value
	 end
      end
      
      if val and widget.min and widget.max then
	 if not widget.minval then
	    widget.minval = val
	 end
	 if val < widget.minval then
	    widget.minval = val
	 end

	 if not widget.maxval then
	    widget.maxval = val
	 end
	 if val > widget.maxval then
	    widget.maxval = val
	 end
      end
   end

   -- keep txTel values up to date every 200 ms
   
   if system.getTimeCounter() - lua.txTelLastUpdate > 200 then
      lua.txTel = system.getTxTelemetry()
      lua.txTelLastUpdate = system.getTimeCounter()
   end
   
   local sens, SeId, SePa

   -- throttle the update rate of tele sensors by moving the upper loop index up and
   -- down to determine how many updates are done per Hollywood call

   local doPerLoop = 5
   for _ = 1, doPerLoop do -- 
      if lua.index == 1 then
	 --print("#s. time (ms)",#InsP.sensorLalist,  system.getTimeCounter() - lastindex)
	 lastindex = system.getTimeCounter()
      end
      lua.index = lua.index + 1
      if lua.index <= #InsP.sensorLalist then
	 SeId = InsP.sensorIdlist[lua.index]
	 SePa = InsP.sensorPalist[lua.index]
	 sens = getSensorByID(SeId, SePa)
	 if sens and sens.valid then
	    --print("InsP.sensorLalist[lua.index]", InsP.sensorLalist[lua.index], sens.value)
	    lua.env[InsP.sensorLalist[lua.index]] = sens.value
	 end
      else
	 lua.index = 1
	 lua.completePass = true
      end
   end
   loopCPU = loopCPU + (system.getCPU() - loopCPU) / 10
end

local function printForm(_,_,tWin)

   local ctl, ctlmin, ctlmax
   local rot, rotmin, rotmax
   local factor
   local sensor
   local sp = InsP.settings.selectedPanel
   local ip = InsP.panels[sp]
   local aw = InsP.panelImages[sp].auxWin
   
   --print("w,h,sp,tw,#", w,h,sp,InsP.panelImages[sp].auxWin, tWin)

   local np = #InsP.panelImages
   local backI, instI

   if not tWin or tWin < 1 or tWin > 2 then print("tWin ERROR") end
   
   if tWin == 1 then
      if aw and aw > 0 and aw <= np then
	 auxWin = aw
	 if auxWin ~= auxWinLast then
	    local pv = InsP.panelImages[auxWin].instImage
	    if pv then
	       instImgA = lcd.loadImage(pDir .. "/"..pv..".png")
	    else
	       instImgA = nil
	    end
	    
	    local bv = InsP.panelImages[auxWin].backImage
	    if bv then
	       backImgA =  lcd.loadImage(bDir .. "/"..bv..".png")
	       --print("load backImgA", bDir .. "/"..bv..".png", backImgA)
	    else
	       backImgA = nil
	    end
	 end
	 auxWinLast = auxWin
      end
      backI = backImg
      instI = instImg
   else
      if auxWin > 0 and auxWin <= np and backImgA and instImgA then
	 sp = auxWin
	 ip = InsP.panels[sp]
	 backI = backImgA
	 instI = instImgA
      else -- show the selected panel if no valid aux is assigned
	 backI = backImg
	 instI = instImg
      end
   end
   
   if backI  then
      lcd.drawImage(0, 0, backI)
   else
      lcd.setColor(0,0,0)
      lcd.drawFilledRectangle(0,0,319,158)
   end

   if instI then
      lcd.drawImage(0, 0, instI)
   else
      lcd.setColor(255,255,255)
      lcd.drawText(100, 70, "No Panel Image", FONT_BOLD)
   end

   if not ip or #ip == 0 then
      drawTextCenter(160, 60, "No instrument panel json defined", FONT_BOLD)
      return
   end

   local sensorVal 
   for idxW, widget in ipairs(ip) do

      sensorVal = nil
      if widget.dataSrc == "Sensor" then
	 sensor = getSensorByID(widget.SeId, widget.SePa)
	 if sensor and sensor.value then sensorVal = sensor.value end
      elseif widget.dataSrc == "Control" then
	 local info = system.getSwitchInfo(switches[widget.control])
	 if info then
	    sensorVal = (widget.multiplier or 100.0) * info.value
	 end
      elseif widget.dataSrc == "Lua" and widget.luastring and  widget.luastring[1] then
	 sensorVal = tonumber(evaluate("E", widget.luastring[1]))
      end
      
      ctl = nil
      local minarc = -0.75 * math.pi
      local maxarc =  0.75 * math.pi

      --print("b",math.deg(minarc), math.deg(maxarc))

      if widget.start then minarc = math.pi/2 + math.rad(widget.start) end
      if widget["end"] then maxarc = math.pi/2 + math.rad(widget["end"]) end

      --print("a",math.deg(minarc), math.deg(maxarc), widget.start, widget["end"])

      if sensorVal then
	 if widget.min and widget.max then
	    ctl = math.min(math.max((sensorVal - widget.min) / (widget.max - widget.min), 0), 1)
	    rot = minarc * (1-ctl) + maxarc * (ctl)
	    --print(ctl, math.deg(rot))
	 end
	 if widget.min and widget.max and widget.minval then
	    ctlmin = math.min(math.max((widget.minval - widget.min) / (widget.max - widget.min), 0), 1)
	    rotmin = minarc * (1-ctlmin) + maxarc * (ctlmin) end
	 if widget.min and widget.max and widget.maxval then
	    ctlmax = math.min(math.max((widget.maxval - widget.min) / (widget.max - widget.min), 0), 1)
	    rotmax = minarc * (1-ctlmax) + maxarc * (ctlmax)
	 end
      end


      if widget.type == "roundNeedleGauge" or widget.type == "roundArcGauge" or
      widget.type == "virtualGauge" then

	 if sensorVal and
	    ( (widget.maxWarn and sensorVal > widget.maxWarn) or
	    (widget.minWarn and sensorVal < widget.minWarn) ) then
	    if (system.getTimeCounter() // 500) % 2 == 0 then
	       local ren = lcd.renderer()
	       ren:reset()
	       for th = 0, 2 * math.pi, 2 * math.pi / 20 do
		  ren:addPoint(
		     widget.x0 + 0.85 * widget.radius * math.sin(th),
		     widget.y0 + 0.85 * widget.radius * math.cos(th)
		  ) 
	       end
	       if sensorVal > widget.maxWarn then
		  lcd.setColor(255,0,0)
	       else
		  lcd.setColor(0,0,255)
	       end
	       ren:renderPolygon(0.6)
	    end
	 end
	 
	 lcd.setColor(255,255,255)

	 local val
	 
	 if ctl then
	    factor = 0.90 * (widget.radius - 8) / 58
	    if widget.type == "roundNeedleGauge" or widget.type == "roundArcGauge" then
	       if widget.type ~= "roundArcGauge" then
		  drawShape(widget.x0, widget.y0, needle, factor, rot + math.pi/2)
	       else
		  --local function drawArc(theta, x0, y0, a0, ri, ro, im, alp) 
		  local ro = widget.ro or 0.87 * widget.radius
		  local ri = widget.ri or 0.85 * widget.radius
		  --lcd.setColor(0x80, 0x80, 0x80) -- same gray used on website.
		  --drawArc(maxarc - minarc, widget.x0, widget.y0, minarc,
			  --ri, ro, arcNP, 1)
		  local r,g,b = 255,255,255
		  if widget.TXspectrum then
		     local wmax = widget.TXspectrum[#widget.TXspectrum]
		     r,g,b = wmax.r, wmax.g, wmax.b		     
		     for _, tt in ipairs(widget.TXspectrum) do
			--print(i, tt.v, sensorVal)
			if tt.v >= sensorVal then
			   r,g,b = tt.r, tt.g, tt.b
			   break
			end
		     end
		  end
		  if widget.TXcolorvals then
		     local wmax = widget.TXcolorvals[#widget.TXcolorvals]
		     r,g,b = wmax.r, wmax.g, wmax.b
		     for _, tt in pairs(widget.TXcolorvals) do
			if tt.v >= sensorVal then
			   r,g,b = tt.r, tt.g, tt.b
			   break
			end
		     end
		  end
		  --print(sensorVal, math.deg(rot), r, g, b)
		  lcd.setColor(r, g, b)
		  local ratio = (rot + math.pi/4) / (maxarc - minarc)
		  local arcNP
		  if widget.radius > 40 then
		     arcNP = 2 + ratio * 18
		  else
		     arcNP = 2 + ratio * 12
		  end
		  drawArc(rot - minarc, widget.x0, widget.y0, minarc, ri, ro+1, arcNP, 1)
	       end
	    elseif widget.type == "virtualGauge" then
	       local shp = {}
	       for ii,v in ipairs(widget.needle) do
		  shp[ii] = {v.x, v.y}
	       end
	       drawShape(widget.x0, widget.y0, shp, factor, rot + math.pi)	       
	    end

	    lcd.setColor(255,255,255)
	    if rotmin and widget.showMM == "true" then
	       --print("rotmin")
	       drawShape(widget.x0, widget.y0, rectangle, factor, rotmin + math.pi/2, 0,
			 widget.radius, 255,255,255)
	    end
	    
	    if rotmax and widget.showMM == "true" then
	       --print("rotmax")
	       drawShape(widget.x0, widget.y0, rectangle, factor, rotmax + math.pi/2, 0,
			 widget.radius, 255,255,255)
	    end
	    lcd.setColor(255,255,255)
	    local fmt
	    if widget.datSrc == "Sensor" and sensor.decimals == 0 then
	       fmt = "%.0f"
	    elseif widget.dataSrc == "Sensor" and sensor.decimals == 1 then
	       fmt = "%.1f"
	    else
	       local max = widget.max
	       local min = widget.min
	       local decims
	       if max and min then
		  decims = math.max(2 - math.floor(math.log(max - min) / math.log(10)), 0)
	       else
		  decims = 1
	       end
	       fmt = string.format("%%.%df", decims) --
	    end
	    val = string.format(fmt, sensorVal)
	 else
	    val = "---"
	 end
	 local str
	 if widget.label then str = widget.label else str = "Gauge"..idxW end

	 if not widget.fL then
	    widget.fL = "Mini"
	 end

	 if not widget.fV then
	    if widget.type == "roundArcGauge" then
	       if widget.radius > 60 then
		  widget.fV = "Maxi"
	       elseif widget.radius > 40 then
		  widget.fV = "Bold"
	       else
		  widget.fV = "Mini"
	       end
	    else
	       widget.fV = "Mini"
	    end
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
	    --print(widget.fV, edit.fcode[widget.fV])
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

      elseif widget.type == "horizontalBar" then
	 local xc = widget.x0 - widget.barW // 2 - 2
	 local yc = widget.y0 - widget.barH // 2

	 if ctl then
	    lcd.setClipping(xc, yc, widget.barW * ctl + 2, widget.barH)
	    for _, p in ipairs(widget.rects) do
	       lcd.setColor(p.r, p.g, p.b)
	       local px, py, pw, ph = math.floor(p.x + 0.5), math.floor(p.y + 0.5),
	       math.floor(p.w + 0.5), math.floor(p.h + 0.5)
	       lcd.drawFilledRectangle(px - xc, py - yc, pw + 1, ph)
	    end
	 end
	 lcd.resetClipping()

	 lcd.setColor(255,255,255)
	 lcd.setClipping(xc, yc, widget.barW + 2, widget.barH)
	 for ii, p in ipairs(widget.rects) do
	    local px, py, ph = math.floor(p.x + 0.5), math.floor(p.y + 0.5),
	    math.floor(p.h + 0.5)
	    lcd.drawLine(p.x - xc, p.y - yc, p.x - xc, p.y - yc + ph)
	    if widget.subdivs > 0 and (ii - 1) % widget.subdivs == 0 then
	       lcd.drawFilledRectangle(px - xc - 1, py - yc, 2, ph)
	    end
	    if ii == #widget.rects and ii % widget.subdivs == 0 then
	       lcd.drawFilledRectangle(widget.x0 + widget.barW//2 - xc - 2, p.y - yc, 2, ph)
	    end
	 end
	 lcd.resetClipping()
	 
	 lcd.setColor(255,255,255)

	 local str
	 local hPad = widget.height / 4
	 local vPad = widget.height / 8
	 local hh = math.floor(widget.height - 2 * vPad + 0.5)

	 if widget.label then str = widget.label else str = "Gauge"..idxW end

	 if not widget.fL then
	    widget.fL = "Mini"
	 end
	 if not widget.xL then
	    widget.xL = widget.x0
	    widget.yL = widget.y0 + hh / 2 - hPad / 5
	 end
	 
	 drawTextCenter(widget.xL, widget.yL, str, edit.fcode[widget.fL])
	 
      elseif widget.type == "sequencedTextBox" or widget.type == "stackedTextBox" then

	 if not widget.xT then
	    widget.xT = widget.x0 
	    widget.yT = widget.y0
	 end

	 if not widget.fT then
	    widget.fT = "Mini"
	 end

	 if not widget.fL then
	    widget.fL = "Mini"
	 end

	 lcd.setColor(255,255,255)
	 
	 if widget.xL and widget.yL then
	    drawTextCenter(widget.xL, widget.yL, widget.label, edit.fcode[widget.fL])
	 end

	 lcd.setColor(0,0,0)

	 local str = widget.text or {"---"}
	 
	 if widget.type == "sequencedTextBox" then

	    local stro
	    
	    if string.find(str[1], "luaE:") == 1 or string.find(str[1], "luaS:") == 1 then
	       stro = expandStr(str[1], sensorVal, widget.SeDp, widget.SeUn)
	    else
	       local idx, jj
	       if sensorVal then
		  jj = math.floor(sensorVal + 0.5)
		  if jj >= 1 and jj <= #str then
		     idx = jj
		  end
	       end
	       if not idx then
		  if sensorVal and jj then
		     stro = string.format("Index %.2f/%d", sensorVal, jj)
		  else
		     stro = "<No Index>"
		  end
	       end
	    end
	    
	    if stro and widget.fT ~= "None" then
	       lcd.drawText(widget.xT - lcd.getTextWidth(edit.fcode[widget.fT], stro)/2,
			    widget.yT - lcd.getTextHeight(edit.fcode[widget.fT])/2 -1,
			    stro, edit.fcode[widget.fT])
	    end
	 else -- stackedTextBox
	    if widget.fT ~= "None" then
	       local strL = #str
	       local txH = lcd.getTextHeight(edit.fcode[widget.fT])
	       local txW
	       local yc = widget.y0 + 1.25 * txH - 0.5 * (txH / 2) * (3 * strL + 1)
	       local stro
	       for ii = 0, strL - 1 , 1 do

		  stro = expandStr(str[ii + 1], sensorVal,
				   widget.SeDp, widget.SeUn)

		  --print(str[ii+1], stro)
		  
		  txW = lcd.getTextWidth(edit.fcode[widget.fT], stro)
		  lcd.drawText(widget.x0 - txW / 2, yc + (ii - (strL % 2)*.7) * txH, stro,
			       edit.fcode[widget.fT])
	       end
	    end
	 end
      
      elseif widget.type == "panelLight" then
	 local nS = 18
	 local ren = lcd.renderer()

	 if not widget.xPL then
	    widget.xPL = widget.x0
	    widget.yPL = widget.y0
	 end

	 if not widget.xL then
	    widget.xL = widget.xPL;
	    widget.yL = widget.yPL + 12;
	 end

	 if not widget.fL then
	    widget.fL = "Mini"
	 end

	 ren:reset()
	 for th = 0, 2 * math.pi, 2 * math.pi / nS do
	    ren:addPoint(
	       widget.xPL + widget.radius * math.sin(th),
	       widget.yPL + widget.radius * math.cos(th)
	    ) 
	 end

	 if sensorVal and sensorVal > (widget.max - widget.min) / 2 then
	    if widget.rgbLightColor then
	       lcd.setColor(widget.rgbLightColor.r, widget.rgbLightColor.g, widget.rgbLightColor.b)
	    end
	 else
	    if widget.rgbOffColor then
	       lcd.setColor(widget.rgbOffColor.r, widget.rgbOffColor.g, widget.rgbOffColor.b)
	    end
	 end
	 ren:renderPolygon(1)
	 if widget.rgbLabelColor then
	    lcd.setColor(widget.rgbLabelColor.r, widget.rgbLabelColor.g, widget.rgbLabelColor.b)
	    ren:renderPolyline(2)
	 end

	 --print(widget.y0, widget.yL)
	 
	 if widget.xL and widget.fL ~= "None" then
	    lcd.drawText(widget.xL - lcd.getTextWidth(edit.fcode[widget.fL], widget.label) / 2,
			 widget.yL - lcd.getTextHeight(edit.fcode[widget.fL]) / 2,
			 widget.label, edit.fcode[widget.fL])
	 end
	 
      elseif widget.type == "rawText" then

	 if not widget.xRT then
	    widget.xRT = widget.x0
	    widget.yRT = widget.y0
	 end

	 if not widget.fT then
	    widget.fT = "Mini"
	 end

	 if widget.textColor then
	    lcd.setColor(widget.textColor.r, widget.textColor.g, widget.textColor.b)
	 end

	 local str
	 str = expandStr(widget.text[1], sensorVal,
				   widget.SeDp, widget.SeUn)

	 if widget.xRT and str and widget.fT ~= "None" then
	    lcd.drawText(widget.xRT - lcd.getTextWidth(edit.fcode[widget.fT], str) / 2,
			 widget.yRT - lcd.getTextHeight(edit.fcode[widget.fT]) / 2,
			 str, edit.fcode[widget.fT])
	 end
	 
      --else
	 --print("unknown widget", widget.type)
      end
   end

   if select(2, system.getDeviceType()) == 1 then
      lcd.drawText(300,70, math.floor(loopCPU + 0.5), FONT_MINI)   
      lcd.drawText(300,90, system.getCPU(), FONT_MINI)
   end
   
end

local function prtForm(w,h)
   if subForm == 107 then
      --print("prtForm 107", savedRow, savedRow2)
      if savedRow == 3 then
	 local sp = InsP.settings.selectedPanel
	 if not InsP.panels[sp][savedRow2].luastring then
	    InsP.panels[sp][savedRow2].luastring = {}
	    --InsP.panels[sp][savedRow2].luastring[1] = ""
	 end
	 LE.luaEditPrint(InsP.panels[sp][savedRow2], 1)
      elseif savedRow == 6 then
	 LE.luaEditPrint(InsP.variables[savedRow2], 1)	 
      end
      
   elseif subForm == 103 and InsP.panels[InsP.settings.selectedPanel] then
      printForm(318,159,1)
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
      elseif (ii == "Text") and ipeg.xT then
	 xx = ipeg.xT
	 yy = ipeg.yT
	 ff = ipeg.fT	 
      elseif (ii == "Range") and ipeg.xLV then
	 xx = (ipeg.xLV + ipeg.xRV) / 2
	 yy = ipeg.yLV
	 ff = ipeg.fLRV
      elseif (ii == "Center") and ipeg.xPL then
	 xx = ipeg.xPL
	 yy = ipeg.yPL
	 ff = ipeg.fL
      end

      local typ = edit.gaugeName[ipeg.type].sn
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
      save.variables = InsP.variables
      save.stateSw = {}
      --[[
      for k,_ in pairs(stateSw) do
	 stateSw[k].switch = nil -- don't save switchitems .. reconstitute with other method
      end
      --]]
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
	 print("Writing", InsP.settings.fileBD)
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
      if string.find(file, "null") then print("Warning: null in JSON") end
   end
   
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

      InsP.variables = decoded.variables
      if not InsP.variables then InsP.variables = {} end
      
      stateSw = {}
      
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

   for _,v in ipairs(InsP.panelImages) do
      if not v.auxWin then v.auxWin = 1 end
   end
   
   readSensors(InsP)

   system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm, prtForm)
   system.registerTelemetry(1, "DFM-InsP-1", 4,
			    (function(w,h) return printForm(w,h,1) end) )
   system.registerTelemetry(2, "DFM-InsP-2 ", 4,
			    (function(w,h) return printForm(w,h,2) end) )   

   appStartTime = system.getTimeCounter()

   LE = require 'DFM-InsP/luaEdit'

   if not LE then print("DFM-InsP: could not load lua editor") end

   local TT = {}
   TT[1] = require 'DFM-InsP/Functions/A123'
   TT[2] = require 'DFM-InsP/Functions/LiPo'
   
   for i in ipairs(TT) do
      for k,v in pairs(TT[i]) do
	 table.insert(lua.ext, {idx=1, name=k, func=v})
      end
   end
   
   print("A123V(50)", TT[1].A123V(50))
   print("A123S(3.3)", TT[1].A123S(3.3))

   print("LiPoV(50)", TT[2].LiPoV(50))
   print("LiPoS(3.8)", TT[2].LiPoS(3.8))   

end

return {init=init, loop=loop, author="DFM", version=InsPVersion, name="DFM-InsP", destroy=destroy}

