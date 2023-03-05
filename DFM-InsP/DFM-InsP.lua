--[[
   --------------------------------------------------------------------------------

   DFM-InsP.lua released under MIT license by DFM 2022
   
   This app is intended to render instrument panels where a json and image file
   are produced on Russell's dynamic content app creation/distribution website

   Started Dec 2022

   Version 0.2  01/12/23 - synch with near-final json format from the website panel maker
   Version 0.3  01/23/23 - lua integrated in sensors and text strings
   Version 0.4  02/01/23 - integrated with uppdates to website for font size quantization
   Version 0.41 02/02/23 - fixed some bugs in horizBar and arcGauge
   Version 0.50 02/14/23 - added tapes and AH, expanded web editor functions and templates
   Version 0.51 02/16/23 - fixed bugs in seq text box
   Version 0.52 02/17/23 - more minor tweaks
   Version 0.53 02/17/23 - yet more tweaks
   Version 0.54 02/19/23 - ported new chartRecorder widget to TX, added logging of lua variables
   Version 0.55 02/20/23 - tweaking font size/spacing for stacked text boxes, reworked rawText
   Version 0.56 02/22/23 - more size/spacing tweaking, fixed chart recorder not recording if not on screen
   Version 0.60 02/23/23 - per HC, tossed S, H, Alt in favor of new simpler two window scheme
   Version 0.61 02/24/23 - Fixed crash in sequencer on "*" ... added "+". changed window start defaults
   Version 0.62 02/24/23 - Added background color to settings
   Version 0.63 02/25/23 - Added widget color to settings
   Version 0.64 02/26/23 - Added sqrt to lua expr editor, added glideslope extension
   Version 0.65 02/27/23 - added gslope ext func, protected calls to dir() with bad paths
   Version 0.70 03/02/23 - added support for units: temperature, distance, speed, stick shake min/max

   *** Don't forget to go update DFM-InsP.html with the new version number ***

   --------------------------------------------------------------------------------
--]]



local InsPVersion = 0.70

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

local jsnVersion = 2

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

local units = {}

units.typeList =  {
   temp   = {"°C","°F"},
   dist={"m", "ft",    "km",  "mi.",    "yd."},
   speed  = {"m/s", "ft./s", "km/h", "kmh", "kt.",   "mph"},
   volume = {"ml", "l", "hl", "floz", "gal"},
   flow   = {"ml/m", "l/m", "oz/m", "gpm"}
}

units.typeName = {
   {dist="Distance"},
   {flow="Flow Rate"},
   {speed="Speed"},
   {temp = "Temperature"},
   {volume="Volume"}
}

units.toNative = {
   temp = {["°C"]=0, ["°F"]=0}, -- these are special cased in the conversions
   dist = {m=1,   ft=0.3048,  km=1000,  ["mi."] = 1609.34 , ["yd."] = 0.9144},
   speed = {["m/s"]=1, ["ft./s"]=0.3048, ["km/h"] = 0.2778, kmh = 0.2778,
      ["kt."] = 0.51444, ["yd."] = 0.4407 },
   volume = {ml=1, l=1000, hl = 100000, floz=29.5735, gal=3785.41},
   flow = {["ml/m"] = 1, ["l/m"] = 1000, ["oz/m"] = 29.5735, gpm=3785.41}
}

units.type = {
   ["°C"]="temp", ["°F"]="temp",
   m="dist", ft="dist", km="dist", ["mi."]="dist", ["yd."]="dist",
   ["m/s"]="speed", ["ft./s"]="speed", ["km/h"]="speed", kmh = "speed", ["kt."]="speed", mph="s",
   ml="volume", l = "volume", hl = "volume", floz="volume", gal="volume",
   ["ml/m"]="flow", ["l/m"]="flow", ["oz/m"]="flow", gpm="flow"
}


local edit = {}
edit.ops = {"Center", "Value", "Label", "Text", "MMLbl", "TicLbl", "TicSpc", "MinMx", "Tape", "Chart"}
edit.dir = {"X", "Y", "Font", "DecPt"}
edit.fonts = {"Mini", "Normal", "Bold", "Big", "Maxi", "None"}
edit.fcode = {Mini=FONT_MINI, Normal=FONT_NORMAL, Bold=FONT_BOLD, Big=FONT_BIG, Maxi=FONT_MAXI,
	      None=-1}
edit.icode = {Mini=1, Normal=2, Bold=3, Big=4, Maxi=5, None=6}

-- sn field is short name for edit window disp
-- en field is 1 (ENABLED) or 0 (DISABLED) appearance for edit button 2 depending on gauge type
-- en elements follow edit.ops

edit.gaugeName = {
   roundNeedleGauge={sn="NdlG", en={0,1,1,0,1,1,1,1,0,0}},
   roundArcGauge=   {sn="ArcG", en={0,1,1,0,1,0,0,1,0,0}},
   virtualGauge=    {sn="VirG", en={1,1,1,0,0,0,0,1,0,0}},
   horizontalBar=   {sn="HBar", en={0,0,1,0,0,1,1,0,0,0}},
   sequencedTextBox={sn="SeqT", en={0,0,1,1,0,0,0,0,0,0}},
   stackedTextBox=  {sn="StkT", en={0,0,1,1,0,0,0,0,0,0}},
   panelLight=      {sn="PnlL", en={1,0,1,0,0,0,0,0,0,0}},
   rawText=         {sn="RawT", en={1,0,0,1,0,0,0,0,0,0}},
   verticalTape=    {sn="VerT", en={0,1,1,0,0,0,0,0,1,0}},
   artHorizon=      {sn="ArtH", en={0,1,1,0,0,0,0,0,0,0}},
   chartRecorder=   {sn="ChtR", en={0,0,1,0,0,0,0,1,0,1}}   
}

local stampIndex = {t30 = 1, t60 = 2, t120= 3, t240 = 4, t480 = 5}
local stampVals  = {"t30", "t60", "t120", "t240", "t480"}
local stampTimes = {"0:30", "1:00", "2:00", "4:00", "8:00"}

local lua = {}
--lua.chunk = {}
lua.env = {string=string, math=math, table=table, print=print,
	   tonumber=tonumber, tostring=tostring, pairs=pairs,
	   require=require, ipairs=ipairs, type=type, abs=math.abs, sqrt=math.sqrt,
	   getSensorByID=(function(a1,a2) return system.getSensorByID(a1,a2) end)
}

lua.index = 0
lua.txTelLastUpdate = 0
lua.txTel = {}
lua.completePass = false

local subForm = 0
local pDir = "Apps/DFM-InsP/Panels"
local bDir = "Apps/DFM-InsP/Backgrounds"
local fDir = "Apps/DFM-InsP/Functions"
local fmDir = "DFM-InsP/Functions"
local xDir  = "Apps/DFM-InsP/Extensions"
local xmDir = "DFM-InsP/Extensions"

local instImg1, instImg2
local backImg1, backImg2
local lastPanel1, lastPanel2 = 0, 0
local dispWindow, dispWindowLast, dispSave = 0, 0, 0

local savedRow = 1
local savedRow2 = 1
local savedRow3 = 1
local mmCI
local swtCI ={}

--local auxWin = 1
--local auxWinLast = 0

local appStartTime
local loopCPU = 0
local editText
local editWidget
local editWidgetType

local formN = {main=1, settings=102, inputs=100, editpanel=103, editgauge=104,
	       editlinks = 105, luavariables=108, resetall=101,
	       editlua = 107, panels=106, editpanelsub=110, backcolors=111, widgetcolors=112,
	       units=113,colors=114}

local formS = {[1]="main", [102]="settings", [100]="inputs", [103]="editpanel", [104]="editgauge",
   [105] = "editlinks", [108] = "luavariables", [101] = "resetall",
   [107] = "editlua", [106] = "panels", [110] = "editpanelsub", [111] = "backcolors",
   [112] = "widgetcolors", [113] = "units", [114] = "colors"}

local MAXSAMPLE = 160
local modSample = 0

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

local function setColorRGB(rgb)
   lcd.setColor(rgb.r, rgb.g, rgb.b)
end

local function makeRGB(t)
   return string.format("%s - rgb(%d,%d,%d)", t.colorname, t.red, t.green, t.blue)
end

local function showExternal(ff)

   local locale = "EN"
   local fn = formS[ff]

   if not fn then return end
   
   if tonumber(system.getVersion()) > 5.01 then
      if select(2, system.getDeviceType()) == 1 then
	 system.openExternal("DOCS/DFM-INSP/"..string.upper(locale).."-"..
				string.upper(fn) ..".HTML")
      else
	 system.openExternal("Apps/DFM-InsP/Docs/"..locale.."-"..fn..".html")
      end
      return
   end
end

local function getSensorByID(SeId, SePa)
   if not SeId or not SePa then return nil end
   --print("SeId, SePa", SeId, SePa)
   if SeId ~= 0 then
      local sensor
      sensor = system.getSensorByID(SeId, SePa)
      if not (sensor and sensor.value and sensor.unit) then return sensor end
      
      if string.byte(string.sub(sensor.unit, 1, 1)) == 176 then
	 sensor.unit = string.char(194) .. sensor.unit
      end

      --print("sensor in",
      --sensor.label, sensor.value, sensor.unit, units.type[sensor.unit])

      local function convertUnits(sensor)
	 local typ = units.type[sensor.unit]      
	 if typ then
	    for k,v in pairs(units.typeList) do
	       -- special case temp since it's not a simple propo
	       if k == "temp" and typ == "temp" then 
		  if sensor.unit ~= InsP.settings.units[k] then
		     if sensor.unit == "°F" then -- convert to °C
			sensor.value = 5/9 * (sensor.value - 32)
			sensor.unit = "°C"
		     else  -- convert to °F
			sensor.value = 9/5 * sensor.value + 32
			sensor.unit = "°F"
		     end
		  end
	       elseif k == typ then
		  if sensor.unit ~= InsP.settings.units[k] then
		     sensor.value = sensor.value * units.toNative[k][sensor.unit]
		     sensor.value = sensor.value / units.toNative[k][InsP.settings.units[k]]
		     --print("converting units", sensor.label, sensor.unit, InsP.settings.units[k])
		     sensor.unit = InsP.settings.units[k]
		  end
	       end
	    end
	 end
	 return
      end

      if sensor and sensor.value and sensor.unit then 
	 convertUnits(sensor)
      end
      --print("sensor out", sensor.value, sensor.unit)
      return sensor
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
      if not lua.txTel or not lua.txTel.RSSI then
	 print("DFM-InsP: RSSI nil", lua.txTel, lua.txTel.RSSI, NePa)
	 sensor.value = 0
	 sensor.unit = ""
	 sensor.decimals = 0
      else
	 sensor.value = lua.txTel.RSSI[NePa]
	 sensor.unit  = InsP.sensorUnlist[txTeleSensors + NePa]
	 sensor.decimals = InsP.sensorDplist[txTeleSensors + NePa]
      end
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
   --tbl.panelImages[1].auxWin = 1
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function drawFilledBezel(xc,yc,w,h,z)
   local x = xc - w/2
   local y = yc - h/2
   --print(xc, yc, x, y, w, h, z)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x, y+z)
   ren:addPoint(x+z, y)
   ren:addPoint(x+w-z, y)
   ren:addPoint(x+w, y+z)
   ren:addPoint(x+w, y+h-z)
   ren:addPoint(x+w-z, y+h)
   ren:addPoint(x+z, y+h)
   ren:addPoint(x, y+h-z)
   ren:renderPolygon()

end

local function drawTextCenter(x, y, str, font)
   if font and font < 0 then return end -- an "invisible" font :-)
   if not font then
      font = FONT_NORMAL
   end
   
   lcd.drawText(math.floor(x - lcd.getTextWidth(font, str)/2 + 0.5),
		math.floor(y - lcd.getTextHeight(font)/2 + 0.5), str, font)
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

local function drawShapeXY(col, row, shape, f, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()
   local fw = f^0.55
   local x0,y0 = 0,0
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + ((fw*point.x+x0) * cosShape - (f*point.y+y0) * sinShape + 0.5),
	 row + ((fw*point.x+x0) * sinShape + (f*point.y+y0) * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
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

   --print("setToPanel", iisp)
   
   if isp < 1 then isp = 1 end
   if isp > #InsP.panels then isp = #InsP.panels end
   InsP.settings.selectedPanel = isp

   if not InsP.panels[isp] then
      fn = pDir .. "/"..InsP.settings.panels[isp]..".json"
      print("DFM-InsP: <setToPanel> reading " .. fn)
      local file = io.readall(fn)
      local decode = json.decode(file)
      if decode.panel then
	 InsP.panels[isp] = decode.panel
	 InsP.panelImages[isp].timestamp = decode.timestamp
	 print("DFM-InsP: New json format " .. decode.timestamp)	 
      else
	 InsP.panels[isp] = decode
	 print("DFM-InsP: Old json format - no timestamp")	 
      end
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

local function getPanelNumber(name)
   local num = 0
   for i, p in ipairs(InsP.panelImages) do
      if p.instImage == name then
	 num = i
	 break
      end
   end
   return num
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

   -- add in the external function modules
   
   for i,v in ipairs(lua.funcext) do
      if string.sub(v.name, -1) == "(" then -- func names have "foo(" for convenience
	 varenv[string.sub(v.name, 1, -2)] = v.func 
      else
	 varenv[v.name] = v.func
      end
   end

   -- and finally the special "var" and "ptr" variables
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

      lua.loadErr = err
      
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
   --print("setVariables")
   for i, var in ipairs(InsP.variables) do
      if InsP.variables[i].source == "Sensor" then
	 --local name = InsP.sensorLalist[var.sensor]
	 --InsP.variables[i].value = lua.env[name]
	 local id = InsP.sensorIdlist[var.sensor]
	 local pa = InsP.sensorPalist[var.sensor]
	 local sensor = getSensorByID(id, pa)
	 if sensor and sensor.value then InsP.variables[i].value = sensor.value end
      elseif InsP.variables[i].source == "Lua" then
	 InsP.variables[i].value = evaluateLua("E", InsP.variables[i].luastring[1])
	 if type(InsP.variables[i].value) ~= "number" then
	    InsP.variables[i].value = 0
	 end
	 --print("setV 2", InsP.variables[i].value, type(InsP.variables[i].value))
	 --print("setV 2", i, var.name, "*"..var.value.."*", InsP.variables[i].luastring[1])
      elseif InsP.variables[i].source == "Control" then -- control
	 local info = system.getSwitchInfo(switches[InsP.variables[i].control])
	 if info then InsP.variables[i].value = info.value end
      end
   end
end

local function evaluate(es, luastring, val)
   setVariables()
   return evaluateLua(es, luastring, val)
end

local function expandStr(stri, val, widget)

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
		  fmt = string.format("%%.%df", widget.SeDp or 1)
	       end
	       v = string.format(fmt, val)
	    else
	       v = "---"
	    end
	 elseif cc == 'u' then
	    if widget.SeUnDisp then
	       v = widget.SeUnDisp
	    elseif widget.SeUn then
	       v = widget.SeUn
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

   if key == KEY_MENU then
      form.preventDefault()
      showExternal(subForm)
      return
   end
   
   if subForm == formN.main then
      if key == KEY_1 then
	 showExternal(subForm)
      end
      
      if key == KEY_2 then
	 if not sp then return end
	 local temp = sp
	 temp = temp + 1
	 if temp > #ip  then is.selectedPanel = 1 else is.selectedPanel = temp end
	 setToPanel(is.selectedPanel)
	 form.reinit(1)
      end
   end

   if subForm == formN.luavariables then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end

      if key == KEY_3 then -- add variable
	 local l
	 local found
	 for i=1,1000,1 do
	    found = false
	    for k,v in ipairs(InsP.variables) do
	       if v.name == "S"..i then found = true break end
	    end
	    if not found then l = i break end
	 end
	 
	 table.insert(InsP.variables,
		      {name="S"..l, source = 1, luastring={}, sensor = 0, SeId = 0, SePa = 0, control = 0})
	 form.reinit(formN.luavariables)
	 return
      end

      if key == KEY_2 then -- remove variable
	 local row = form.getFocusedRow()
	 if not row or row > #InsP.variables or not InsP.variables[row] then return end
	 if InsP.variables[row].source == "Control" then
	    local cvarName = InsP.variables[row].control
	    if not cvarName then
	       print("InsP.variables[row].control nil for row", row)
	    else
	       switches[cvarName] = nil
	       InsP.settings.switchInfo[cvarName] = nil
	    end
	 end
	 table.remove(InsP.variables, row)
	 form.reinit(formN.luavariables)
	 return
      end
   end
   
   if subForm == formN.editlua then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end

      --print("formN.editlua, savedRow, savedRow2", savedRow, savedRow2)
      
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
   
   if subForm == formN.panels then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 then
	 InsP.settings.window1Panel = form.getFocusedRow() - 1
	 form.reinit(formN.panels)
      end
      if key == KEY_2 then
	 InsP.settings.window2Panel = form.getFocusedRow() - 1
	 form.reinit(formN.panels)
      end
      if key == KEY_3 then -- add panel
	 local ii = #InsP.panels+1
	 InsP.panels[ii] = {}
	 InsP.panelImages[ii] = {}
	 is.selectedPanel = #InsP.panels
	 InsP.panelImages[is.selectedPanel].instImage = "---"
	 InsP.panelImages[is.selectedPanel].backImage = "---"
	 lastPanel1 = 0 -- force reread of png files
	 lastPanel2 = 0
	 setToPanel(#InsP.panels)
	 form.reinit(formN.panels)
      end
      if key == KEY_4 then -- delete panel
	 local row = form.getFocusedRow() - 1
	 if row < 1 or  row > #InsP.panels then return end

	 -- remove switchInfo "soft switch" data for this panel
	 for k,v in pairs(InsP.settings.switchInfo) do
	    if  string.match(k, "(.+)%-") == InsP.panelImages[row].instImage then
	       InsP.settings.switchInfo[k] = nil
	       switches[k] = nil
	    end
	 end

	 local name1
	 --print("#InsP.panels", #InsP.panels)
	 --print("InsP.settings.window1Panel", InsP.settings.window1Panel)
	 if InsP.settings.window1Panel > 0 and InsP.settings.window1Panel <= #InsP.panels then
	    name1 = InsP.panelImages[InsP.settings.window1Panel].instImage
	 end
	 --print("name1 " .. tostring(name1))
	 
	 local name2
	 --print("InsP.settings.window2Panel", InsP.settings.window2Panel)
	 if InsP.settings.window2Panel > 0 and InsP.settings.window2Panel <= #InsP.panels then
	    name2 = InsP.panelImages[InsP.settings.window2Panel].instImage
	 end
	 --print("name2 ".. tostring(name2))
	 
	 table.remove(InsP.panels, row)
	 table.remove(InsP.panelImages, row)

	 if row == is.window1Panel then
	    system.messageBox("Window 1 Panel deleted")
	    is.window1Panel = 1
	 end
	 if row == is.window2Panel then
	    system.messageBox("Window 2 Panel deleted")
	    is.window2Panel = math.min(#InsP.panels, 2)
	 end

	 for i,p in ipairs(InsP.panelImages) do
	    if p.instImage == name1 then InsP.settings.window1Panel = i end
	    if p.instImage == name2 then InsP.settings.window2Panel = i end	    
	 end

	 if not name1 then InsP.settings.window1Panel = 1 end
	 if not name2 then InsP.settings.window2Panel = math.min(#InsP.panels, 2) end
	 
	 if row == is.selectedPanel then
	    --system.messageBox("Selected Panel deleted")
	    is.selectedPanel = 1
	 end
	 
	 if #InsP.panels < 1 then
	    initPanels(InsP)
	    is.window1Panel = 1
	    is.window2Panel = 0
	 end
	 setToPanel(is.selectedPanel)
	 form.reinit(formN.panels)
      end
   end
   
   if subForm == formN.inputs then
      if keyExit(key) and key ~= KEY_ENTER then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 or key == KEY_ENTER then -- edit
	 savedRow2 = form.getFocusedRow()
	 savedRow3 = form.getFocusedRow()
	 form.reinit(formN.editgauge) 
      end
   end

   if subForm == formN.settings then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   end

   if subForm == formN.editgauge then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(formN.inputs)
	 return
      end
   end

   if subForm == formN.editpanelsub then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(formN.editpanel)
	 return
      end
      if key == KEY_2 and editWidget.type == "sequencedTextBox" then
	 table.remove(editWidget.text, form.getFocusedRow())
	 if #editWidget.text < 1 then
	    editWidget.text = {"..."}
	 end
	 form.reinit(formN.editpanelsub)
      end
      if key == KEY_3 and editWidget.type == "sequencedTextBox" then
	 table.insert(editWidget.text, "...")
	 form.reinit(formN.editpanelsub)
      end
   end
   
   if subForm == formN.editpanel then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 InsP.settings.window1Panel = dispSave
	 dispSave = 0 -- ready for next time
	 lastPanel1 = 0 -- force re-read
	 return
      end

      local ipsp = InsP.panels[InsP.settings.selectedPanel]
      local ipeg = ipsp[edit.gauge]
      if not ipeg then return end
      
      local en = edit.gaugeName[ipeg.type].en[edit.opsIdx]
      local eo = edit.ops[edit.opsIdx]
      local ed = edit.dir[edit.dirIdx]
      local en4

      local et, editState
      if key ~= KEY_RELEASED then
	 et, editState = form.getButton(4)
      end
      
      if key == KEY_RELEASED then -- set up for next press
	 form.setButton(1, "Select", ENABLED)
	 form.setButton(2, string.format("%s", edit.ops[edit.opsIdx]), en)
	 form.setButton(3, string.format("%s", edit.dir[edit.dirIdx]), ENABLED)	 	 
	 if (eo == "Text" or eo == "MinMx" or eo == "Label" or eo == "Tape" or eo == "Chart")
	 and en == 1 then
	    en4 = ENABLED
	 else
	    en4 = DISABLED
	 end
	 form.setButton(4, "Edit", en4)
      elseif key == KEY_1 then
	 edit.gauge = edit.gauge + 1
	 if edit.gauge > #ipsp then edit.gauge = 1 end
	 ipeg = ipsp[edit.gauge] 
      elseif key == KEY_2  then
	 edit.opsIdx = edit.opsIdx + 1
	 if edit.opsIdx > #edit.ops then edit.opsIdx = 1 end
      elseif key == KEY_3  then
	 edit.dirIdx = edit.dirIdx + 1
	 if edit.dirIdx > #edit.dir then edit.dirIdx = 1 end
      elseif key == KEY_4 and editState ~= 0 then
	 editWidget = ipeg
	 editWidgetType = eo
	 --print("calling Edit", eo)
	 form.reinit(formN.editpanelsub)
      elseif key == KEY_UP or key == KEY_DOWN then
	 local inc
	 if key == KEY_UP then inc = 1 else inc = -1 end
	 -- hack: make TicSpc work with X or Y or Font
	 if eo == "TicSpc" then ed = "Font" end
	 
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
	    
	    if eo == "MMLbl" and ipeg.xLV and ipeg.xRV then
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
	    
	    if eo == "MMLbl" and ipeg.yLV and ipeg.yRV then
	       ipeg.yLV = ipeg.yLV + inc
	       ipeg.yRV = ipeg.yRV + inc
	    end

	    if eo == "Center" and ipeg.yPL then
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

	    if eo == "MMLbl" and ipeg.fLRV then
	       local i = edit.icode[ipeg.fLRV]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end	       
	       if i < 1 then i = #edit.fonts end
	       ipeg.fLRV = edit.fonts[i]
	    end

	    if eo == "TicLbl" and ipeg.fTL then
	       local i = edit.icode[ipeg.fTL]
	       i = i + inc
	       if i > #edit.fonts then i = 1 end	       
	       if i < 1 then i = #edit.fonts end
	       ipeg.fTL = edit.fonts[i]
	    end

	    if eo == "TicSpc" and ipeg.TS then
	       if ipeg.TS + inc > -100 and ipeg.TS + inc < 100 then
		  ipeg.TS = ipeg.TS + inc
	       end
	    end
	    
	 elseif ed == "DecPt" then
	    if eo == "TicLbl" and ipeg.dp then
	       if ipeg.dp + inc >= 0 and ipeg.dp + inc <= 2 then
		  ipeg.dp = ipeg.dp + inc
	       end
	    end
	 end
      end
   end

   if subForm == formN.editlinks then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_1 then
	 table.insert(stateSw, {switch=nil, dir=1, from="*", to="*", lastSw=0})
	 form.setFocusedRow(#stateSw + 1)
	 form.reinit(formN.editlinks)
      elseif key == KEY_2 then
	 local fr = form.getFocusedRow()
	 if fr - 1 > 0 then
	    stateSw[fr-1].switch = nil
	    switches["stateSwitch"..(fr-1)] = nil
	    table.remove(stateSw, fr - 1)
	 end
	 form.reinit(formN.editlinks)
      end
   end
   
   if subForm == formN.backcolors then
      if keyExit(key) then
	 form.preventDefault()
	 -- see if a new background color was set for a panel and update if so
	 for i,p in ipairs(InsP.panelImages) do
	    --print("exiting .. setting to", p.newBackImage)
	    if p.newBackImage then
	       InsP.panelImages[i].backImage = p.newBackImage
	       InsP.panelImages[i].newBackImage = nil
	       lastPanel1, lastPanel2 = 0, 0 -- force re-read of backgnd color
	    end
	 end
	 
	 form.reinit(1)
	 return
      end
      if key == KEY_2 then -- delete
	 local fr = form.getFocusedRow()
	 if fr - 1 > 0 then
	    table.remove(InsP.colors, fr - 1)
	    form.reinit(formN.backcolors)
	 end
      elseif key == KEY_3 then -- add
	 table.insert(InsP.colors, {colorname="newcolor", red=0, green=0, blue=0})
	 form.reinit(formN.backcolors)
      end
      return
   end

   if subForm == formN.widgetcolors then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
      if key == KEY_2 then -- delete
	 local fr = form.getFocusedRow()
	 if fr - 1 > 0 then
	    table.remove(InsP.widgetColors, fr - 1)
	    form.reinit(formN.widgetcolors)
	 end
      elseif key == KEY_3 then -- add
	 table.insert(InsP.widgetColors, {colorname="newcolor", red=0, green=0, blue=0})
	 savedRow2 = #InsP.widgetColors
	 form.reinit(formN.widgetcolors)
      end
      return
   end

   if subForm == formN.units then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(formN.settings)
	 return
      end
   end

   if subForm == formN.colors then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(formN.settings)
	 return
      end
   end
   
end

local function changedSensor(val, i, ip)
   ip[i].SeId = InsP.sensorIdlist[val]
   ip[i].SePa = InsP.sensorPalist[val]
   ip[i].SeUn = InsP.sensorUnlist[val]
   ip[i].SeDp = InsP.sensorDplist[val]
   ip[i].SeLa = InsP.sensorLalist[val]
   ip[i].SeUnDisp = nil
   form.reinit(formN.editgauge)
end

local function changedAHSensor(val, i, ip, rp)
   if rp == "roll" then
      ip[i].SeId = 0
      ip[i].SePa = 0      
      ip[i].rollSeId = InsP.sensorIdlist[val]
      ip[i].rollSePa = InsP.sensorPalist[val]
      ip[i].rollSeUn = InsP.sensorUnlist[val]
      ip[i].rollSeDp = InsP.sensorDplist[val]
      ip[i].rollSeLa = InsP.sensorLalist[val]
   elseif rp == "pitch" then
      ip[i].SeId = 0
      ip[i].SePa = 0      
      ip[i].pitchSeId = InsP.sensorIdlist[val]
      ip[i].pitchSePa = InsP.sensorPalist[val]
      ip[i].pitchSeUn = InsP.sensorUnlist[val]
      ip[i].pitchSeDp = InsP.sensorDplist[val]
      ip[i].pitchSeLa = InsP.sensorLalist[val]
   end
end

local function panelChanged(val, sp)
   local fn
   local decodedfile
   --local ii
   --local bi
   --local instImg
   local pv = InsP.settings.panels[val]
   if val ~= 1 then
      --ii = InsP.panelImages[sp].instImage
      --bi = InsP.panelImages[sp].backImage
      fn = pDir .. "/"..pv..".json"
      --print("panelChanged reading fn sp pv", fn, sp, pv)
      local file = io.readall(fn)

      decodedfile =  json.decode(file)
      if decodedfile.panel then
	 InsP.panels[sp] = decodedfile.panel
	 InsP.panelImages[sp].timestamp = decodedfile.timestamp
	 print("DFM-InsP: new json format " .. decodedfile.timestamp)
      else
	 InsP.panels[sp] = decodedfile
	 print("DFM-InsP: old json format - no timestamp")
      end
      InsP.panelImages[sp].instImage = pv
      -- force reload of panels
      lastPanel1 = 0
      lastPanel2 = 0
      --print("sp, #InsP.panels", sp, #InsP.panels)
      if sp == 1 and #InsP.panels == 1  then
	 InsP.settings.window1Panel = sp
      end
      if sp == 2 and #InsP.panels == 2 then
	 InsP.settings.window2Panel = sp
      end
   else
      if (InsP.settings.window1Panel or 0) == val then
	 InsP.settings.window1Panel = 1
      end
      if (InsP.settings.window2Panel or 0) == val then
	 InsP.settings.window2Panel = 0
      end
      --instImg = nil
      --InsP.panelImages[sp].instImage = nil
      InsP.panels[sp] = {}
      InsP.panelImages[sp].instImage = "---"
      InsP.panelImages[sp].backImage = "---"
      lastPanel1 = 0
      lastPanel2 = 0
   end
   form.reinit(formN.panels)
end

local function backGndChanged(val, sp, tbl)
   if val ~= 1 then
      InsP.panelImages[sp].backImage = tbl[val]
      --print("set Panel1Images["..sp.."].backImage to", tbl[val])
   else
      InsP.panelImages[sp].backImage = nil
   end
   -- force reread of backgrounds
   lastPanel1 = 0
   lastPanel2 = 0
end

local function changedSwitch(val, switchName, j, wid)
   local Invert = 1.0
   
   local swInfo = system.getSwitchInfo(val)

   system.pSave(switchName, val)
   
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
	    --print("if wid", switchName)
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
   form.reinit(formN.editgauge)
end

local function changedMultiplier(val, wid)
   wid.multiplier = val
end

local function changedModule(val, wid, ttb)
   wid.modext = val - 1 -- {"..."} is index 1
   wid.modextName = ttb[val]
   form.reinit(formN.editgauge)   
end

local function initForm(sf)

   subForm = sf

   if sf == 1 then
      form.setButton(1, ":help", ENABLED)
      form.setButton(2, "Select", ENABLED)
      
      local sp = InsP.panelImages[InsP.settings.selectedPanel].instImage
      form.setTitle(string.format("Selected Panel: %s", sp))
      
      form.addRow(2)
      form.addLabel({label="Panels >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(formN.panels)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Settings >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(formN.settings)
	       form.waitForRelease()
      end))      
      
      form.addRow(2)
      form.addLabel({label="Inputs >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(formN.inputs)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Edit Panel >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.setTitle("")
	       edit.gauge = 1
	       edit.opsIdx = 1
	       edit.dirIdx = 2 -- default to "Y"
	       form.reinit(formN.editpanel)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Edit Links >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       savedRow2 = 1
	       form.reinit(formN.editlinks)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Lua variables >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(formN.luavariables)
	       form.waitForRelease()
      end))


      form.setFocusedRow(savedRow)
   elseif sf == formN.inputs then

      local ip = InsP.panels[InsP.settings.selectedPanel]
      --print("ip", ip, #ip, InsP.settings.selectedPanel)
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
	 if widget.label then
	    str = "  "..widget.label
	 else
	    str = "  Widget"..i
	 end
	 local typ = edit.gaugeName[widget.type].sn
	 if not typ then typ = "---" end
	 --print("widget.type", widget.type, typ)
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
	    elseif InsP.sensorLslist[isel] == "..." and typ == "ArtH" then
	       form.addLabel({label="<AH>", width=100})
	    else
	       form.addLabel({label=InsP.sensorLslist[isel], width=100})
	    end
	 elseif widget.dataSrc == "Control" then
	    local info = system.getSwitchInfo(switches[widget.control])
	    if info then
	       --print("?? widget.control", widget.control)
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
   elseif sf == formN.resetall then
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
   elseif sf == formN.settings then
      
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
      form.addLabel({label="Units >>", width=220})
      form.addLink((function()
	       form.reinit(formN.units)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Colors >>", width=220})
      form.addLink((function()
	       form.reinit(formN.colors)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Reset all app data >>", width=220})
      form.addLink((function()
	       form.reinit(formN.resetall)
	       form.waitForRelease()
      end))
      
      form.setFocusedRow(savedRow2)
   elseif sf == formN.editpanel then
      form.setTitle("")
      keyForm(KEY_RELEASED)
   elseif sf == formN.editgauge then -- edit item on sensor menu
      local ig = savedRow3
      local isp = InsP.settings.selectedPanel
      local ip = InsP.panels[isp]
      local lbl = ip[ig].label or "Widget"..ig
      local pnl = InsP.panelImages[isp].instImage
      local widget = ip[ig]

      form.setTitle("Edit Widget "..ig.."  ("..lbl..")", savedRow3)

      if not widget.dataSrc then widget.dataSrc = "Sensor" end

      -- check for special case first: Artificial Horizon
      
      if widget.type == "artHorizon" then

	 local rollId = widget.rollSeId or 0
	 local rollPa = widget.rollSePa or 0
	 local pitchId = widget.pitchSeId or 0
	 local pitchPa = widget.pitchSePa or 0
	 
	 local rollSel = 1 -- index 1 is "..."
	 for k, _ in ipairs(InsP.sensorLalist) do
	    if rollId == InsP.sensorIdlist[k] and rollPa == InsP.sensorPalist[k] then
	       rollSel = k
	       break
	    end
	 end

	 local pitchSel = 1 -- index 1 is "..."
	 for k, _ in ipairs(InsP.sensorLalist) do
	    if pitchId == InsP.sensorIdlist[k] and pitchPa == InsP.sensorPalist[k] then
	       pitchSel = k
	       break
	    end
	 end

	 form.addRow(2)
	 form.addLabel({label="Roll Sensor", width=120})
	 form.addSelectbox(InsP.sensorLalist, rollSel, true,
			   (function(x) return changedAHSensor(x, ig, ip, "roll") end),
			   {width=240, alignRight=true})

	 form.addRow(2)
	 form.addLabel({label="Pitch Sensor", width=120})
	 form.addSelectbox(InsP.sensorLalist, pitchSel, true,
			   (function(x) return changedAHSensor(x, ig, ip, "pitch") end),
			   {width=240, alignRight=true})

	 form.setFocusedRow(1)
	 return
      end


      form.addRow(2)
      form.addLabel({label="Widget input source"})
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
	 local un = widget.SeUn or "---"
	 
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
	 form.addRow(3)
	 local typ = units.type[un]
	 local utl
	 if typ then
	    utl = units.typeList[typ][1]
	 else
	    utl = "..."
	 end
	 
	 form.addLabel({label="Sensor: " .. un .. "  Def: " .. utl, width=175})
	 form.addLabel({label="Display:", width=65})
	 --print("un, typ:", un, typ)
	 if not widget.SeUnDisp and typ then
	    --print("setting widget.SeUnDisp to", units.typeList[typ][1])
	    widget.SeUnDisp = units.typeList[typ][1]
	 end
	 local isel = 0
	 --print("before loop widget.SeUnDisp", widget.SeUnDisp)
	 if typ then
	    for i,v in ipairs(units.typeList[typ]) do
	       if v == widget.SeUnDisp then
		  isel = i
		  break
	       end
	    end
	 end

	 if typ then
	    utl = units.typeList[typ]
	 else
	    utl = {un}
	    isel = 1
	 end
	 
	 if widget.modext and widget.modext ~= 0 then
	    utl = {"f(x)"}
	    isel = 1
	 end
	 
	 form.addSelectbox(utl, isel, true,
			   (function(val)
				 if typ then
				    widget.SeUnDisp = units.typeList[typ][val]
				 end
			   end),
			   {width=70})
	 
      elseif widget.dataSrc == "Control" then
	 widget.SeUn = ""
	 form.addRow(2)
	 form.addLabel({label="Control", width=80})
	 
	 local ctrlName = pnl .. "-" .. string.gsub(lbl, "%W", "_") .."_"..system.getTime()
	 --print("check ctrlName " ..ctrlName .. " for uniqueness!")


	 --print("ctrlName", ctrlName, switches[ctrlName], widget.control)
	 if not widget.control then switches[ctrlName] = nil end
	 swtCI[ctrlName] = form.addInputbox(switches[ctrlName], true,
					    (function(x) return changedSwitch(x, ctrlName,
									      nil, widget) end),
					    {width=240, alignRight=true})
	 form.addRow(2)
	 form.addLabel({label="Control multiplier", width=240})
	 if not widget.multiplier then widget.multiplier = 100.0 end
	 form.addIntbox(widget.multiplier, -10000, 10000, 100, 0, 1,
			(function(x) return changedMultiplier(x, widget) end) )
	 
      elseif widget.dataSrc == "Lua" then
	 widget.SeUn = ""
	 form.addRow(1)
	 --form.addLabel({label="Edit lua >>", width=220})
	 form.addLink((function()
		  form.reinit(formN.editlua)
		  form.waitForRelease()
		      end), {label="Edit Lua>>"})
      end

      --form.addRow(2)
      --form.addLabel({label="Sensor units " .. widget.SeUn .. " Widget units, width=140})
      --form.addSelectbox()
      
      form.addRow(2)
      form.addLabel({label="Lua f(x) extension", width=140})
	 
      local ttbi = 0
      local ttb = {"..."}
      for i,v in ipairs(lua.modext) do
	 if widget.modext == i then ttbi = i+1 end
	 table.insert(ttb, v.name)
      end
      if not widget.modext then widget.modext = 0 end
      form.addSelectbox(ttb, ttbi, true,
			(function(x) return changedModule(x, widget, ttb) end), {width=180})

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

	 local stickShake = {"...", "Left 1 Long", "Left 1 Short", "Left 2 Short", "Left 3 Short",
			     "Right 1 Long", "Right 1 Short", "Right 2 Short", "Right 3 Short"}
	 --[[
	 local stickCode = {
	    {lr = false, vib = 0},
	    {lr = false, vib = 1}, {lr = false, vib = 2},
	    {lr = false, vib = 3}, {lr = false, vib = 4},
	    {lr = true, vib = 0},
	    {lr = true, vib = 1}, {lr = true, vib = 2},
	    {lr = true, vib = 3}, {lr = true, vib = 4}
	 }
	 --]]
	 form.addRow(2)
	 form.addLabel({label="Min warning stick shake", width=200})
	 if not ip[ig].minShake then ip[ig].minShake = 0 end
	 form.addSelectbox(stickShake, ip[ig].minShake, true,
			   (function(val) ip[ig].minShake = val end), {width=110})
				 
	 form.addRow(2)
	 form.addLabel({label="Max warning stick shake", width=200})
	 if not ip[ig].maxShake then ip[ig].maxShake = 0 end
	 form.addSelectbox(stickShake, ip[ig].maxShake, true,
			   (function(val) ip[ig].maxShake = val end), {width=110})
	 
      end
      
      form.setFocusedRow(1)
   elseif sf == formN.editlinks then
      local function dirChanged(val, j)
	 stateSw[j].dir = val
	 form.reinit(formN.editlinks)
      end

      local function fromChanged(val, j)
	 if val == 1 then
	    stateSw[j].from = "*"
	 else
	    stateSw[j].from = InsP.panelImages[val-1].instImage
	 end
	 form.reinit(formN.editlinks)
      end
      
      local function toChanged(val, j)
	 if val == 1 then
	    stateSw[j].to = "+"
	 else
	    stateSw[j].to = InsP.panelImages[val-1].instImage
	 end
	 form.reinit(formN.editlinks)
      end

      form.setTitle("Sequence switch setup")
      
      form.setButton(1, ":add", 1)
      form.setButton(2, ":delete", 1)
      form.addRow(1)
      form.addLabel({label="  Sw         Trig           From               To"})
      local ipi = InsP.panelImages
      local teleLabel={}
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
	 teleLabel[1] = "*"
	 form.addSelectbox(teleLabel, from, true,
			   (function(x) return fromChanged(x,j) end), {width=100})
	 teleLabel[1] = "+"
	 form.addSelectbox(teleLabel, to  , true,
			   (function(x) return toChanged(x,j)   end), {width=100})
      end
   elseif sf == formN.panels then
      form.setTitle("Edit Panels")

      form.setButton(1, "Win 1", ENABLED)
      form.setButton(2, "Win 2", ENABLED)
      form.setButton(3, ":add", ENABLED)
      form.setButton(4, ":delete", ENABLED)

      form.addRow(3)

      form.addLabel({label="Window", width=65})
      form.addLabel({label="Panel     ", width=130, alignRight = true})
      form.addLabel({label="Background  ", width=115, alignRight = true})

      for i in ipairs(InsP.panelImages) do
	 form.addRow(3)

	 local lbl="     "
	 if i == InsP.settings.window1Panel then
	    lbl = lbl .. "1  "
	 end
	 if i == InsP.settings.window2Panel then
	    lbl = lbl .. "2 "
	 end
	 form.addLabel({label=lbl, width=65})
	 
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
			   {width=130, alignRight = true})

	 local bgt = {}
	 for ii, p in ipairs(InsP.settings.backgrounds) do
	    table.insert(bgt, p)
	 end
	 for ii, p in ipairs(InsP.colors) do
	    --print("makeRGB(p)", makeRGB(p))
	    table.insert(bgt, makeRGB(p))
	 end
	 
	 local bak = InsP.panelImages[i].backImage
	 
	 isel = 0
	 for ii, p in ipairs(bgt) do
	    if p == bak then
	       isel = ii
	       break
	    end
	 end
	 form.addSelectbox(bgt, isel, true,
			   (function(x) return backGndChanged(x, i, bgt) end),
			   {width=115, alignRight = true})
      end

      local isp = InsP.settings.selectedPanel
      if isp > 1 then
	 form.setFocusedRow(isp + 1)
      else
	 form.setFocusedRow(2)
      end
      
   elseif sf == formN.editlua then
      --print("about to luaEdit", subForm, savedRow, savedRow2)
      LE.luaEdit(InsP.variables, lua.funcext, 0)--savedRow2)

   elseif sf == formN.luavariables then

      local varopts = {"Sensor", "Control", "Lua"}

      form.setTitle("Lua Variables")

      local function changedVariableName(val, i)
	 InsP.variables[i].name = val
	 form.reinit(formN.luavariables)
      end

      local function changedSensor2(val, i)
	 InsP.variables[i].sensor = val
	 InsP.variables[i].SeId = InsP.sensorIdlist[val]
	 InsP.variables[i].SePa = InsP.sensorPalist[val]
	 --print("Id, Pa", InsP.variables[i].SeId, InsP.variables[i].SePa)
	 form.reinit(formN.luavariables)
      end

      local function changedSource(val, i)
	 InsP.variables[i].source = varopts[val]
	 --print("set source to", varopts[val], val)
	 form.reinit(formN.luavariables)
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

	 form.addRow(3)
	 --form.addLabel({label="Name", width=50})
	 form.addTextbox(InsP.variables[i].name, 63,
			 (function(x) return changedVariableName(x, i) end), {width=80})
	 if not InsP.variables[i].source then InsP.variables[i].source = "Sensor" end

	 local iv = 0
	 if InsP.variables and #InsP.variables  > 0 then
	    for k,v in ipairs(varopts) do
	       if InsP.variables[i].source == v then
		  iv = k
		  break
	       end
	    end
	    if iv == 0 then InsP.variables[i].source = "Sensor"; iv = 1 end
	 end
	    
	 form.addSelectbox(varopts, iv, true,
			   (function(x) return changedSource(x, i) end), {width=80})	    
	 if InsP.variables[i].source == "Sensor" then
	    form.addSelectbox(InsP.sensorLalist, InsP.variables[i].sensor, true,
			      (function(x) return changedSensor2(x, i) end), {width=150, alignRight=false})
	 elseif InsP.variables[i].source == "Lua" then 
	    form.addLink((function()
		     savedRow2 = form.getFocusedRow()
		     --print("lua edit var, savedRow2", savedRow2)
		     form.waitForRelease()
		     form.reinit(formN.editlua)
			 end), {label="Edit Lua>>", width=150})
	 elseif InsP.variables[i].source == "Control" then
	    local cvarName
	    --print("top", i, InsP.variables[i].control)
	    if not InsP.variables[i].control or InsP.variables[i].control == 0 then
	       --print("searching for cvarName")
	       for k=1,1000,1 do
		  if not InsP.settings.switchInfo["var"..k.."ctl"] then
		     cvarName = "var"..k.."ctl"
		     break
		  end
	       end
	    else
	       cvarName = InsP.variables[i].control
	    end
	    
	    --print("before inputbox", cvarName)
	    swtCI[cvarName] = form.addInputbox(switches[cvarName], true,
					       (function(x)
						     return
							changedSwitch(x, cvarName,
								      nil, InsP.variables[i])
					       end),
					       {width=240, alignRight=true})
	 	 end
	 form.setFocusedRow(savedRow2)
	 
      end
      
      
   elseif sf == formN.editpanelsub then
      --[[
      local colors = {"black", "silver", "gray",   "white", "maroon",
		      "red",   "purple", "fuscia", "green", "lime",
		      "olive", "yellow", "navy", "blue", "teal",
		      "aqua"}
      local rgbColors = {
	 {0,0,0},     {192,192,192}, {128,128,128}, {255,255,255}, {128,0,0},
	 {255,0,0},   {128,0,128},   {255,0,255},   {0,128,0},     {0,255,0},
	 {128,128,0}, {255,255,0},   {0,0,128},     {0,0,255},     {0,128,128},
	 {0,255,255}

      }
      --]]
      local function editTextCB(val, i)
	 editWidget.text[i] = val 
      end
      local function editMinMaxCB(val, mm)
	 if mm == "min" then
	    editWidget.min = val / 10 
	 else
	    editWidget.max = val / 10
	 end
      end
      local function editLabelCB(val)
	 editWidget.label = val
      end
      local function editTapeCB(val, ns)
	 if ns == "numbers" then
	    editWidget.numbers = val
	 else
	    editWidget.step = val
	 end
      end
      local function editTimeCB(val)
	 --print("editTimeCB - resetting")
	 editWidget.timeSpan = stampVals[val]
	 editWidget.chartInterval = tonumber(string.sub(editWidget.timeSpan,2)) * 1000 / MAXSAMPLE
	 editWidget.chartSample = {}
	 editWidget.chartSamples = 0
	 editWidget.chartSampleYP = {}
	 editWidget.chartSampleXP = {}
	 editWidget.chartStartTime = system.getTimeCounter()
      end
      
      local function editTraceColorCB(val)
	 editWidget.chartTraceColor = InsP.widgetColors[val].colorname
	 editWidget.rgbChartTraceColor.r = InsP.widgetColors[val].red
	 editWidget.rgbChartTraceColor.g = InsP.widgetColors[val].green
	 editWidget.rgbChartTraceColor.b = InsP.widgetColors[val].blue
      end
      
      form.setTitle("Widget Editor")

      if editWidgetType == "Text" then
	 if not editWidget.text then return end
	 --print("#text", #editWidget.text, "type", editWidget.type)
	 if editWidget.type == "sequencedTextBox" then
	    form.setButton(3, ":add", ENABLED)
	    form.setButton(2, ":delete", ENABLED)
	 end
	 
	 for i, txt in ipairs(editWidget.text) do
	    --print(i, editWidget.text[i])
	    form.addRow(1)
	    if #editWidget.text[i] <= 63 then
	       form.addTextbox(editWidget.text[i], 63,
			       (function(v)
				     return editTextCB(v, i)
	       end))
	    else
		  form.addLabel({label="<Line too long to edit>", alignRight=true})
	    end
	    
	 end 
      elseif editWidgetType == "MinMx" then
	 form.addRow(2)
	 form.addLabel({label="Min"})
	 form.addIntbox(10*editWidget.min, -32768, 32767, 0, 1, 1,
			(function(v) return editMinMaxCB(v, "min") end))
	 form.addRow(2)	 
	 form.addLabel({label="Max"})	 
	 form.addIntbox(10*editWidget.max, -32768, 32767, 100, 1, 1,
			(function(v) return editMinMaxCB(v, "max") end))
      elseif editWidgetType == "Label" then
	 form.addRow(1)
	 if not editWidget.label then editWidget.label = '---' end
	 if #editWidget.label <= 63 then
	    form.addTextbox(editWidget.label, 63, editLabelCB)
	 else
	       form.addLabel({label="<Line too long to edit>", alignRight=true})
	 end
      elseif editWidgetType == "Tape" then
	 form.addRow(2)
	 form.addLabel({label="Numbers"})
	 form.addIntbox(editWidget.numbers, 1, 10, 6, 0, 1,
			(function(v) return editTapeCB(v, "numbers") end))
	 form.addRow(2)
	 form.addLabel({label="Step"})
	 form.addIntbox(editWidget.step, 1, 100, 10, 0, 1,
			(function(v) return editTapeCB(v, "step") end))
      elseif editWidgetType == "Chart" then
	 local tt = 0
	 for k,t in ipairs(stampVals) do
	    --print(t, editWidget.timeSpan)
	    if t == editWidget.timeSpan then
	       tt = k
	       break
	    end
	 end
	 form.addRow(1)
	 form.addLabel({label="NOTE: Ensure stacked chart time scales are the same", font=FONT_MINI})
	 form.addRow(2)
	 form.addLabel({label="Time scale"})
	 form.addSelectbox(stampTimes, tt, true, editTimeCB)
	 form.addRow(2)
	 form.addLabel({label="Trace Color"})
	 local cc = 0
	 --print("traceColor", editWidget.chartTraceColor)
	 for k,c in ipairs(InsP.widgetColors) do
	    if c.colorname == editWidget.chartTraceColor then
	       cc = k
	       break
	    end
	 end

	 local tmp = {}
	 if cc == 0 then
	    tmp[1] = string.format("rgb(%d,%d,%d)", editWidget.rgbChartTraceColor.r,
				   editWidget.rgbChartTraceColor.g, editWidget.rgbChartTraceColor.b)
	    cc = 1
	 end
	 
	 for i,c in ipairs(InsP.widgetColors) do
	    table.insert(tmp, c.colorname)
	 end
	 
	 form.addSelectbox(tmp, cc, true, editTraceColorCB)
      end

   elseif sf == formN.widgetcolors then
      form.setTitle("Define Widget Colors")
      
      form.setButton(3, ":add", ENABLED)
      form.setButton(2, ":delete", ENABLED)

      local function changedColorName(val, i)
	 InsP.widgetColors[i].colorname = val
      end

      local function changedColor(val, i, clr)
	 InsP.widgetColors[i][clr] = val
      end

      form.addRow(4)
      form.addLabel({label="Name    ", width=120, alignRight=true})
      form.addLabel({label="R", width=60})
      form.addLabel({label="G", width=60})
      form.addLabel({label="B", width=60})
	 
      for i,c in ipairs(InsP.widgetColors) do
	 form.addRow(4)
	 form.addTextbox(c.colorname, 16, (function(x) return changedColorName(x,i) end), {width=120})
	 form.addIntbox(c.red, 0, 255, 0, 0, 1,
			(function(x) return changedColor(x, i, "red") end), {width=60})
	 form.addIntbox(c.green, 0, 255, 0, 0, 1,
			(function(x) return changedColor(x, i, "green") end), {width=60})
	 form.addIntbox(c.blue, 0, 255, 0, 0, 1,
			(function(x) return changedColor(x, i, "blue") end), {width=60})	 
      end
      form.setFocusedRow(savedRow2 + 1)
      
   elseif sf == formN.backcolors then

      form.setTitle("Define Background Colors")
      
      form.setButton(3, ":add", ENABLED)
      form.setButton(2, ":delete", ENABLED)

      local oldColor
      local newColor
      
      local function checkColorChange(val, i)
	 --print("checkColorChange", oldColor, newColor, InsP.panelImages[i].backColor)
	 if InsP.panelImages[i].backImage == oldColor or InsP.panelImages[i].newBackImage == oldColor then
	    --print("newbackColor", newColor)
	    InsP.panelImages[i].newBackImage = newColor
	 end
      end
      
      local function changedColorName(val, i)
	 oldColor = makeRGB(InsP.colors[i])
	 InsP.colors[i].colorname = val
	 newColor = makeRGB(InsP.colors[i])
	 checkColorChange(val, i)
      end
      
      local function changedColor(val, i, clr)
	 --print("changedColor", val, i, clr)
	 oldColor = makeRGB(InsP.colors[i])
	 InsP.colors[i][clr] = val
	 newColor = makeRGB(InsP.colors[i])
	 checkColorChange(val, i)
      end

      --InsP.colors[1] = {colorname="red", red=255, green=0, blue=0}
      
      form.addRow(4)
      form.addLabel({label="Name    ", width=120, alignRight=true})
      form.addLabel({label="R", width=60})
      form.addLabel({label="G", width=60})
      form.addLabel({label="B", width=60})
	 
      for i,c in ipairs(InsP.colors) do
	 form.addRow(4)
	 form.addTextbox(c.colorname, 16, (function(x) return changedColorName(x,i) end), {width=120})
	 form.addIntbox(c.red, 0, 255, 0, 0, 1,
			(function(x) return changedColor(x, i, "red") end), {width=60})
	 form.addIntbox(c.green, 0, 255, 0, 0, 1,
			(function(x) return changedColor(x, i, "green") end), {width=60})
	 form.addIntbox(c.blue, 0, 255, 0, 0, 1,
			(function(x) return changedColor(x, i, "blue") end), {width=60})	 
      end

   elseif sf == formN.units then

      form.setTitle("Set Default Units")

      for k,v in pairs(units.typeName) do
	 local kk,vv = next(v)
	 form.addRow(2)
	 form.addLabel({label=vv, width=220})
	 local isel = 0
	 for i,u in ipairs(units.typeList[kk]) do
	    if u == InsP.settings.units[kk] then
	       isel = i
	       break
	    end
	 end
	 form.addSelectbox(units.typeList[kk], isel, true,
			   (function(val)
				 InsP.settings.units[kk] = units.typeList.temp[val]
			   end),
			   {width=90})
      end
   elseif sf == formN.colors then
      form.setTitle("Set Colors")
      form.addRow(2)
      form.addLabel({label="Widget Colors >>", width=220})
      form.addLink((function()
	       form.reinit(formN.widgetcolors)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Background Colors >>", width=220})
      form.addLink((function()
	       form.reinit(formN.backcolors)
	       form.waitForRelease()
      end))
   end
end

local swrLast
local swpLast
local lastindex = 0

local function loop()

   local sensor
   local swr, swp, swt

   -- see if sequencer has triggered a change

   local w1 = InsP.settings.window1Panel
   for i in ipairs(stateSw) do
      swt = system.getInputsVal(stateSw[i].switch)
      if not stateSw[i].lastSw then stateSw[i].lastSw = swt end
      if swt and stateSw[i] and stateSw[i].lastSw ~= 0 and (swt ~= stateSw[i].lastSw) then
	 -- "pos" is index 1 and "neg" is index 2
	 if (swt == 1 and stateSw[i].dir == 1) or (swt == -1 and stateSw[i].dir == 2) then
	    if stateSw[i].from == "*" or stateSw[i].from ==  InsP.panelImages[w1].instImage then
	       if stateSw[i].to ~= "+" then
		  system.messageBox("Window 1 switching to: " .. stateSw[i].to)
		  InsP.settings.window1Panel = getPanelNumber(stateSw[i].to)
	       else 
		  InsP.settings.window1Panel = InsP.settings.window1Panel + 1
		  if InsP.settings.window1Panel > #InsP.panels then
		     InsP.settings.window1Panel = 1
		  end
		  system.messageBox("Window 1 incrementing to " ..
				       InsP.panelImages[InsP.settings.window1Panel].instImage)
	       end
	    end
	 end
      end
      stateSw[i].lastSw = swt
   end

   -- set displayed window to 0 if not shown for 200ms or more
   
   if system.getTimeCounter() > dispWindowLast + 200 then
      dispWindow = 0
   end
   
   -- see if we need to rotate panels from the manual switch
   -- rotate the panel being looked at ... dispWindow times out to 0
   -- after 200ms
   swp = system.getInputsVal(switches.rotatePanels)
   if not swpLast then swpLast = swp end
   if swp and swp == 1 and swpLast ~= 1 then
      local is = InsP.settings
      if dispWindow == 1 then
	 is.window1Panel = is.window1Panel + 1
	 if is.window1Panel > #InsP.panels then
	    is.window1Panel = 1
	 end
      elseif dispWindow == 2 then
	 is.window2Panel = is.window2Panel + 1
	 if is.window2Panel > #InsP.panels then
	    is.window2Panel = 1
	 end
      end
   end
   swpLast = swp

   -- see if the reset min/max switch has moved
   swr = system.getInputsVal(switches.resetMinMax)
   if not swrLast then swrLast = swr end
   if swr and swr == 1 and swrLast ~= 1 then
      for _, panel in pairs(InsP.panels) do
	 for _, gauge in pairs(panel) do
	    gauge.minval = nil
	    gauge.maxval = nil
	 end
      end
   end
   swrLast = swr

   -- now loop over all panels and all widgets in panels to update min,max and keep
   -- chart data up to date even if not on the screen
   
   local val
   for pp, panel in ipairs(InsP.panels) do
      for _, widget in ipairs(panel) do
	 -- could special case for Art Horiz here .. but for now just ignore min and max for that
	 -- it has SeId and SePa set to 0,0
	 val = nil
	 if widget.dataSrc == "Sensor" then
	    sensor = getSensorByID(widget.SeId, widget.SePa)
	    if sensor and sensor.valid then val = sensor.value end
	 elseif widget.dataSrc == "Control" then
	    local info = system.getSwitchInfo(switches[widget.control])
	    if info then
	       val = (widget.multiplier or 100.0) * info.value
	    end
	 elseif widget.dataSrc == "Lua" and widget.luastring and widget.luastring[1] then
	    val = tonumber(evaluate("E", widget.luastring[1]))
	 end
	 
	 --[[
	 local stickShake = {"...", "Left 1 Long", "Left 1 Short", "Left 2 Short", "Left 3 Short",
			     "Right 1 Long", "Right 1 Short", "Right 2 Short", "Right 3 Short"}
	 --]]
	 local stickCode = {
	    {lr = false, vib = 0},
	    {lr = false, vib = 1}, {lr = false, vib = 2},
	    {lr = false, vib = 3}, {lr = false, vib = 4},
	    {lr = true,  vib = 1}, {lr = true,  vib = 2},
	    {lr = true,  vib = 3}, {lr = true,  vib = 4}
	 }

	 if val and widget.min then
	    if not widget.minval then
	       widget.minval = val
	    end
	    if val >= widget.minWarn then
	       widget.minvalArmed = true
	       widget.minvalCount = 0
	    end
	    if (val < widget.minWarn) and widget.minvalArmed == true then
	       if not widget.minvalCount then widget.minvalCount = 0 end
	       widget.minvalCount = math.min(widget.minvalCount + 1, 100)

	       if widget.minvalCount == 1 then
		  if widget.minShake and widget.minShake > 1 then
		     system.vibration(stickCode[widget.minShake].lr, stickCode[widget.minShake].vib)
		  end
	       end
	    end
	    if val < widget.minval then
	       widget.minval = val
	    end
	 end
	 
	 if val and widget.max then
	    if not widget.maxval then
	       widget.maxval = val
	    end
	    if val <= widget.maxWarn then
	       widget.maxvalArmed = true
	       widget.maxvalCount = 0
	    end
	    if (val > widget.maxWarn) and widget.maxvalArmed == true then
	       if not widget.maxvalCount then widget.maxvalCount = 0 end
	       widget.maxvalCount = math.min(widget.maxvalCount + 1, 100)

	       if widget.maxvalCount == 1 then
		  if widget.maxShake and widget.maxShake > 1 then
		     system.vibration(stickCode[widget.maxShake].lr, stickCode[widget.maxShake].vib)
		  end
	       end
	    end
	    if val > widget.maxval then
	       widget.maxval = val
	    end
	 end
	 
	 local xp, yc, fy, yp
	 local ymin, ymax = widget.min, widget.max
	 
	 if widget.type == "chartRecorder" then
	    local now = system.getTimeCounter()
	    if (not widget.chartInterval) or (#widget.chartSample < 1) then
	       widget.chartInterval = tonumber(string.sub(widget.timeSpan,2)) * 1000 / MAXSAMPLE
	       widget.chartSample = {}
	       widget.chartSamples = 0
	       widget.chartSampleYP = {}
	       widget.chartSampleXP = {}
	       widget.chartStartTime = now
	    end
	    if (now > (widget.chartStartTime + widget.chartInterval * widget.chartSamples)) and val then
	       --print("sample", widget.chartSamples)
	       widget.chartSamples = widget.chartSamples + 1
	       if #widget.chartSample + 1 > MAXSAMPLE then
		  table.remove(widget.chartSample, 1)
		  table.remove(widget.chartSampleYP, 1)
		  table.remove(widget.chartSampleXP, 1)
	       end
	       table.insert(widget.chartSample, val)
	       yc = math.max(ymin, math.min(val, ymax))
	       fy = (yc - ymin) / (ymax - ymin)	    
	       yp = widget.boxYL + (1 - fy) * widget.boxH
	       table.insert(widget.chartSampleYP, yp)
	       table.insert(widget.chartSampleXP, now)
	    end
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

   -- leave this off for now .. until we decide to have variables for all tele sensors
   -- which was the intent when this was done
   
   local doPerLoop = 0
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

local foo

local function printForm(ww0,hh0,tWin)

   local ctl, ctlmin, ctlmax
   local rot, rotmin, rotmax
   local factor
   local sensor

   local ip, pv, bv
   local isp1 = InsP.settings.window1Panel
   local isp2 = InsP.settings.window2Panel

   local backI, instI

   --[[
   local rgbt, bv
   local vs = string.match(val, "rgb%(")
   if vs then
      rgbt = {}
      rgbt.r,rgbt.g,rgbt.b = string.match(val, "(%d+),(%d+),(%d+)")
   end
   --]]
   
   dispWindow = tWin
   dispWindowLast = system.getTimeCounter()
   
   if tWin == 1 and isp1 and isp1 ~= 0 then
      if isp1 < 1 or isp1 > #InsP.panels then
	 --print("bad isp1", isp1)
	 InsP.settings.window1Panel = 1
	 isp1 = 1
      end
      if lastPanel1 ~= isp1 then
	 pv = InsP.panelImages[isp1].instImage
	 --print("win 1 loading panel " .. isp1 .. "  " .. pv)
	 if pv then
	    instImg1 = lcd.loadImage(pDir .. "/"..pv..".png")
	 else
	    --print("pv was nil")
	    instImg1 = nil
	 end
	 --print("instImg1, pv, lastPanel1", instImg1, pv, lastPanel1)
	 
	 bv = InsP.panelImages[isp1].backImage
	 if bv then
	    --print("bv", bv, string.match(bv, "rgb%("))
	    if string.match(bv, "rgb%(") then
	       backImg1 = {}
	       backImg1.r, backImg1.g, backImg1.b = string.match(bv, "(%d+),(%d+),(%d+)")
	       --print("backImg1 to {}", backImg1.r, backImg1.g, backImg1.b)
	    else
	       backImg1 =  lcd.loadImage(bDir .. "/"..bv..".png")
	    end
	 else
	    backImg1 = nil
	 end
	 lastPanel1 = isp1
      end
      ip = InsP.panels[isp1]
      instI = instImg1
      backI = backImg1
   end
   
   if tWin == 2 and isp2 and isp2 ~= 0 then
      if isp2< 1 or isp2 > #InsP.panels then
	 --print("bad isp2", isp2)
	 InsP.settings.window2Panel = 1
	 isp2 = 1
      end
      if lastPanel2 ~= isp2 then
	 pv = InsP.panelImages[isp2].instImage
	 --print("win 2 loading panel " .. isp2 .. " " ..pv)
	 if pv then
	    instImg2 = lcd.loadImage(pDir .. "/"..pv..".png")
	 else
	    instImg2 = nil
	 end
	 bv = InsP.panelImages[isp2].backImage
	 if bv then
	    if string.match(bv, "rgb%(") then
	       backImg2 = {}
	       backImg2.r, backImg2.g, backImg2.b = string.match(bv, "(%d+),(%d+),(%d+)")
	    else
	       backImg2 =  lcd.loadImage(bDir .. "/"..bv..".png")
	    end
	 else
	    backImg2 = nil
	 end
	 lastPanel2 = isp2
      end
      ip = InsP.panels[isp2]
      instI = instImg2
      backI = backImg2
   end
   
   if backI  then
      if backI.width then
	 lcd.drawImage(0, 0, backI)
      else
	 lcd.setColor(backI.r, backI.g, backI.b)
	 lcd.drawFilledRectangle(0,0,319,158)
      end
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

   lcd.setColor(255,255,255)
   if not ip or #ip == 0 then
      drawTextCenter(160, 60, "Window " .. tWin .. ": No inst panel assigned", FONT_BOLD)
      return
   end
   
   local sensorVal
   local sensorValNative
   local rollVal
   local pitchVal
   local textVal
   local modret
   
   for idxW, widget in ipairs(ip) do

      sensorVal = nil
      sensorValNative = nil
      
      if widget.dataSrc == "Sensor" then
	 if widget.type ~= "artHorizon" then
	    sensor = getSensorByID(widget.SeId, widget.SePa)
	    
	    --if sensor and sensor.value then sensorVal = sensor.value end
	    if sensor then
	       --print("widget.SeId, widget.SePa, sensor",
	       --widget.SeId, widget.SePa, sensor.value, sensor.unit, widget.type)
	    end

	    -- remember native value returned by getSensorByID before changing
	    -- to display units
	    
	    if sensor and sensor.value then sensorValNative = sensor.value end

	    local typ
	    if sensor and sensor.unit then typ = units.type[sensor.unit] end
	    if typ and not widget.SeUnDisp then widget.SeUnDisp = units.typeList[typ][1] end
	    if sensor and sensor.value and typ and sensor.unit ~= widget.SeUnDisp then
	       --print("~= sensor.unit, widget.SeUnDisp", sensor.unit, widget.SeUnDisp)
	       if typ == "temp" then
		  if sensor.unit == "°F" then -- convert to °C
		     sensor.value = 5/9 * (sensor.value - 32)
		     sensor.unit = "°C"
		  else  -- convert to °F
		     sensor.value = 9/5 * sensor.value + 32
		     sensor.unit = "°F"
		  end
	       else
		  sensor.value = sensor.value * units.toNative[typ][sensor.unit]
		  sensor.value = sensor.value / units.toNative[typ][widget.SeUnDisp]
		  sensor.unit = widget.SeUnDisp
	       end
	    end
	    if sensor and sensor.value then sensorVal = sensor.value end
	 else
	    rollVal = 0
	    pitchVal = 0
	    if widget.rollSeId and widget.rollSePa then
	       sensor = getSensorByID(widget.rollSeId, widget.rollSePa)
	       if sensor and sensor.value then rollVal = sensor.value end
	    end
	    if widget.pitchSeId and widget.pitchSePa then
	       sensor = getSensorByID(widget.pitchSeId, widget.pitchSePa)
	       if sensor and sensor.value then pitchVal = sensor.value end	       
	    end
	 end
      elseif widget.dataSrc == "Control" then
	 local info = system.getSwitchInfo(switches[widget.control])
	 --if idxW == 1 then print("widget.control", widget.control) end
	 if info then
	    sensorVal = (widget.multiplier or 100.0) * info.value
	 end
      elseif widget.dataSrc == "Lua" and widget.luastring and  widget.luastring[1] then
	 sensorVal = tonumber(evaluate("E", widget.luastring[1]))
      end

      textVal = nil
      if widget.modext and widget.modext > 0 then
	 --print("calling", idxW, widget.modext, lua.modext[widget.modext].name,
	 --lua.modext[widget.modext].func)
	 --print("sensorValNative", sensorValNative)
	 setVariables()
	 local modret = lua.modext[widget.modext].func(InsP, sensorValNative)
	 if type(modret) == "number" then
	    --print("modret number", ret)
	    sensorVal = modret
	 elseif type(modret) == "table" and type(modret[1]) == "string" then
	    textVal = modret
	 end
      end
      
      ctl = nil
      local minarc = -0.75 * math.pi
      local maxarc =  0.75 * math.pi

      --print("b",math.deg(minarc), math.deg(maxarc))

      --if widget.start then minarc = math.pi/2 + math.rad(widget.start) end
      if widget.start then minarc = math.rad(widget.start) end
      --if widget["end"] then maxarc = math.pi/2 + math.rad(widget["end"]) end
      if widget["end"] then maxarc = math.rad(widget["end"]) end      

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

	 if sensorVal and widget.maxWarn and widget.minWarn then
	    local hiwarn = false
	    local lowarn = false
	    if widget.maxWarn >= widget.minWarn then
	       if sensorVal > widget.maxWarn then hiwarn = true
	       elseif sensorVal < widget.minWarn then lowarn = true end
	    else
	       if sensorVal > widget.minWarn then hiwarn = true
	       elseif sensorVal < widget.maxWarn then lowarn = true end
	    end
	    if (hiwarn or lowarn) and (system.getTimeCounter() // 500) % 2 == 0 then
	       local ren = lcd.renderer()
	       ren:reset()
	       for th = 0, 2 * math.pi, 2 * math.pi / 20 do
		  ren:addPoint(
		     widget.x0 + 0.85 * widget.gaugeRadius * math.sin(th),
		     widget.y0 + 0.85 * widget.gaugeRadius * math.cos(th)
		  ) 
	       end
	       if hiwarn then
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
	    --factor = 0.90 * (widget.radius - 8) / 58
	    if widget.type == "roundNeedleGauge" or widget.type == "roundArcGauge" then
	       local ro = widget.ro or 0.87 * widget.radius
	       local ri = widget.ri or 0.85 * widget.radius
	       factor = 0.90 * ro / 58
	       if widget.type ~= "roundArcGauge" then
		  if not widget.TS then widget.TS = ri - 1.8 * (ro - ri) end
		  local rt = widget.TS
		  if not widget.dp then
		     local max = widget.max
		     local min = widget.min
		     if max and min and (max ~= min) then
			widget.dp = math.max(1-math.floor(math.log(math.abs((max - min)))/math.log(10)), 0)
		     else
			widget.dp = 0
		     end
		  end
		  
		  local dp = math.floor(widget.dp)
		  local fstr = "%."..dp.."f"
		  
		  if not widget.fTL then
		     --print("widget.fTL <"..tostring(widget.fTL)..">")
		     --print("widget.tickFont", widget.tickFont)
		     widget.fTL = widget.tickFont or "Mini"
		  end
		  local vv, vt
		  --print(widget.tickLabels, widget.subdivs, widget.majdivs, widget.fTL)
		  if widget.tickLabels and widget.subdivs > 0 and widget.majdivs > 0 and
		  widget.fTL ~= "None" then
		     --print(#widget.tickLabels)
		     for i,v in ipairs(widget.tickLabels) do
			vv = widget.min + (i - 1) * (widget.max - widget.min) / (widget.majdivs)
			vt = string.format(fstr, vv)
			--vt = tostring(vv)
			--print("widget.fTL, edit.fcode[widget.fTL]", widget.fTL, edit.fcode[widget.fTL])
			local vrt = widget.TS
			--print(vrt)
			drawTextCenter(widget.x0 + vrt * v.ca, widget.y0 + vrt * v.sa,
				       vt, edit.fcode[widget.fTL])
		     end
		  end
		  if widget.needleType ~= "None" then
		     lcd.setColor(255,255,255)
		     if widget.needle then
			drawShapeXY(widget.x0, widget.y0, widget.needle, factor, rot + math.pi)
		     end
		     if widget.inner then
			lcd.setColor(widget.rgbInnerFillColor.r,
				     widget.rgbInnerFillColor.g, widget.rgbInnerFillColor.b)
			drawShapeXY(widget.x0, widget.y0, widget.inner, factor, rot + math.pi)
		     end
		  end
	       else
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
		  local ratio = (rot - minarc) / math.abs(maxarc - minarc)		  
		  local arcNP
		  if widget.radius > 40 then
		     arcNP = 2 + ratio * 22
		  else
		     arcNP = 2 + ratio * 14
		  end
		  drawArc(rot - minarc, widget.x0, widget.y0, minarc + math.pi/2, ri, ro+1, arcNP, 1)
	       end
	    elseif widget.type == "virtualGauge" then

	       if not widget.xPL then
		  widget.xPL = widget.x0
		  widget.yPL = widget.y0
	       end

	       if widget.needle then
		  local shp = {}
		  for ii,v in ipairs(widget.needle) do
		     shp[ii] = {v.x, v.y}
		  end
		  drawShape(widget.xPL, widget.yPL, shp, factor, rot + math.pi)
	       end
	    end

	    lcd.setColor(255,255,255)
	    if rotmin and widget.showMM == "true" then
	       --print("rotmin")
	       drawShape(widget.x0, widget.y0, rectangle, factor, rotmin + math.pi, 0,
			 widget.ro+10, 255,255,255)
	    end
	    
	    if rotmax and widget.showMM == "true" then
	       --print("rotmax")
	       drawShape(widget.x0, widget.y0, rectangle, factor, rotmax + math.pi, 0,
			 widget.ro+10, 255,255,255)
	    end
	    lcd.setColor(255,255,255)
	    local fmt
	    if widget.dataSrc == "Sensor" and sensor.decimals == 0 then
	       fmt = "%.0f"
	    elseif widget.dataSrc == "Sensor" and sensor.decimals == 1 then
	       fmt = "%.1f"
	    else
	       local max = widget.max
	       local min = widget.min
	       local decims
	       if max and min and (max ~= min) then
		  decims = math.max(2 - math.floor(math.log(math.abs(max - min)) / math.log(10)), 0)
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
	 if widget.label then str = widget.label else str = "Widget"..idxW end

	 if not widget.fL then
	    widget.fL = widget.labelFont or "Mini"
	 end

	 if not widget.fV then
	    widget.fV = widget.valueFont or "Mini"
	 end
	 
	 if not widget.fLRV then
	    widget.fLRV = widget.tickFont or "Mini"
	 end
	 
	 if widget.gaugeRadius > 30 then -- really ought to consolidate with >= 20 code below
	    
	    if not widget.xL then
	       widget.xL = widget.x0
	       widget.yL = widget.y0 + 1.0 * widget.radius - 15
	    end

	    if widget.labelBoxColor and widget.labelBoxColor ~= "transparent" then
	       lcd.setColor(widget.rgbLabelBoxColor.r, widget.rgbLabelBoxColor.g, widget.rgbLabelBoxColor.b)
	       --drawFilledBezel(widget.xLB+14, widget.yLB+1, widget.wLB-28, widget.hLB, 2)
	       local lH = lcd.getTextHeight(edit.fcode[widget.fL]) - 2 -- 2 is a fudge
	       local lW = lcd.getTextWidth(edit.fcode[widget.fL], str)
	       drawFilledBezel(widget.xL, widget.yL, lW, lH, 2)	       
	    end

	    if widget.rgbLabelColor then
	       lcd.setColor(widget.rgbLabelColor.r, widget.rgbLabelColor.g, widget.rgbLabelColor.b)
	       drawTextCenter(widget.xL, widget.yL, str, edit.fcode[widget.fL])
	    end

	    if not widget.xV then
	       widget.xV = widget.x0
	       widget.yV = widget.y0-- + 0.17 * widget.radius
	    end

	    lcd.setColor(255,255,255)
	    if widget.fV ~= "None" then
	       drawTextCenter(widget.xV, widget.yV, string.format("%s", val), edit.fcode[widget.fV])
	    end
	    
	    if widget.subdivs == 0 and widget.fLRV ~= "None" then
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
	 elseif widget.gaugeRadius >= 20 then

	    if not widget.xV then
	       widget.xV = widget.x0
	       widget.yV = widget.y0 --+ 0.25 * widget.radius
	    end

	    lcd.setColor(255,255,255)
	    drawTextCenter(widget.xV, widget.yV,
			   string.format("%s", val), edit.fcode[widget.fV])	    

	    if not widget.xL then
	       widget.xL = widget.x0
	       widget.yL = widget.y0 + 1.0 * widget.radius - 9
	    end

	    if widget.labelBoxColor ~= "transparent" and widget.rgbLabelBoxColor then
	       lcd.setColor(widget.rgbLabelBoxColor.r, widget.rgbLabelBoxColor.g, widget.rgbLabelBoxColor.b)
	       drawFilledBezel(widget.xLB+12, widget.yLB+4, widget.wLB-24, widget.hLB-4, 2)
	    end

	    if widget.rgbLabelColor then
	       lcd.setColor(widget.rgbLabelColor.r, widget.rgbLabelColor.g, widget.rgbLabelColor.b)
	       drawTextCenter(widget.xL, widget.yL, str, edit.fcode[widget.fL])
	    end
	    

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
	 
	 if widget.backColor and (widget.backColor.t == "false") then
	    lcd.setColor(widget.backColor.r, widget.backColor.g, widget.backColor.b)
	    lcd.drawFilledRectangle(xc, yc, widget.barW, widget.barH)
	 end
	 
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
	 local vv, vt

	 if not widget.fTL then widget.fTL = widget.tickFont or "Mini" end
	 if not widget.TS then widget.TS = 0 end
	 
	 if sensorVal then
	    for i,v in ipairs(widget.hbarLabels) do
	       vv = widget.min + (i - 1) * (widget.max - widget.min) / (widget.majdivs)
	       vt = string.format("%d", vv)
	       drawTextCenter(v.x, v.y + widget.TS,
			      vt, edit.fcode[widget.fTL])
	    end
	 end
	 
	 if widget.label then str = widget.label else str = "Widget"..idxW end

	 if not widget.fL then
	    widget.fL = widget.labelFont or "Mini"
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
	    widget.fT = widget.textFont or "Mini"
	 end

	 if not widget.fL then
	    widget.fL = widget.labelFont or "Mini"
	 end

	 lcd.setColor(255,255,255)
	 
	 if widget.xL and widget.yL then
	    drawTextCenter(widget.xL, widget.yL, widget.label, edit.fcode[widget.fL])
	 end

	 lcd.setColor(0,0,0)
	 
	 local str
	 if textVal then
	    str = textVal
	 else
	    str = widget.text or {"..."}
	 end

	 if widget.type == "sequencedTextBox" then

	    local stro
	    if not widget.modext or widget.modext < 1 then
	       if string.find(str[1], "luaE:") == 1 or string.find(str[1], "luaS:") == 1 then
		  stro = expandStr(str[1], sensorVal, widget)
	       else
		  local idx, jj
		  if sensorVal then
		     jj = math.floor(sensorVal + 0.5)
		     if jj >= 1 and jj <= #str then
			idx = jj
		     end
		  end
		  if idx then
		     stro = str[idx]
		  else
		     if sensorVal and jj then
			stro = string.format("Index %.2f/%d", sensorVal, jj)
		     else
			stro = "<No Index>"
		     end
		  end
	       end
	    else
	       stro = str[1]
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
	       local yc = widget.y0 + 0.85 * txH - 0.5 * (.41 * txH) * (3 * #widget.text + 1)
	       local stro
	       for ii = 0, strL - 1 , 1 do

		  if not widget.modext or widget.modext < 1 then
		     stro = expandStr(str[ii + 1], sensorVal,
				      widget)
		  else
		     stro = str[ii+1]
		  end
		  		  
		  txW = lcd.getTextWidth(edit.fcode[widget.fT], stro)
		  drawTextCenter(widget.x0, yc + 1.16 * txH * ii, stro, edit.fcode[widget.fT])		  
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
	    widget.fL = widget.labelFont or "Mini"
	 end

	 ren:reset()
	 for th = 0, 2 * math.pi, 2 * math.pi / nS do
	    ren:addPoint(
	       widget.xPL + widget.radius * math.sin(th),
	       widget.yPL + widget.radius * math.cos(th)
	    ) 
	 end
	 --if idxW == 1 then print("pl", sensorVal, widget.max, widget.min) end

	 if sensorVal and sensorVal > (widget.max - widget.min) / 2  then
	    if widget.rgbLightColor then
	       lcd.setColor(widget.rgbLightColor.r, widget.rgbLightColor.g, widget.rgbLightColor.b)
	       ren:renderPolygon(1)
	    end
	 else
	    if widget.rgbBackColor and widget.backColor ~= "transparent" then
	       lcd.setColor(widget.rgbBackColor.r, widget.rgbBackColor.g, widget.rgbBackColor.b)
	       ren:renderPolygon(1)
	    end
	 end
	 	 
	 if widget.rgbBezelColor then
	    lcd.setColor(widget.rgbBezelColor.r, widget.rgbBezelColor.g, widget.rgbBezelColor.b)
	    ren:renderPolyline(2)
	 end

	 --print(widget.y0, widget.yL)
	 
	 lcd.setColor(255,255,255)

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
	    widget.fT = widget.textFont or "Mini"
	 end

	 local tJ
	 if widget.textJust then
	    tJ = widget.textJust
	 else
	    tJ = "center"
	 end

	 local str = widget.text or {"..."}

	 if widget.fT ~= "None" then
	    local strL = #str
	    local txH = lcd.getTextHeight(edit.fcode[widget.fT])
	    local hgt = strL * 0.94 * txH
	    local txW
	    local maxW = lcd.getTextWidth(edit.fcode[widget.fT], widget.text[1])
	    for ii = 2, strL, 1 do
	       if lcd.getTextWidth(edit.fcode[widget.fT], widget.text[ii]) > maxW then
		  maxW = lcd.getTextWidth(edit.fcode[widget.fT], widget.text[ii])
	       end
	    end

	    local xB = txH / 2
	    local yB = txH / 4
	    local xb0
	    if tJ == "center" then
	       xb0 = 0
	    elseif tJ == "left" then
	       xb0 = maxW / 2 
	    elseif tJ == "right" then
	       xb0 = -maxW / 2
	    end

	    if widget.backColor and widget.backColor ~= "transparent" then
	       setColorRGB(widget.rgbBackColor)
	       drawFilledBezel(widget.xRT + xb0, widget.yRT, maxW + 2 * xB, hgt + 2 * yB, 2)
	    end
	    
	    if widget.rgbTextColor then
	       setColorRGB(widget.rgbTextColor)
	    else
	       lcd.setColor(255,255,255)
	    end

	    local yc = math.floor(widget.yRT  - hgt / 2 + 0.5) + txH / 2 - 2
	    local stro
	    local x00
	    for ii = 0, strL - 1 , 1 do
	       if not widget.modext or widget.modext < 1 then
		  stro = expandStr(str[ii + 1], sensorVal,
				   widget)
	       else
		  stro = str[ii+1]
	       end
	       txW = lcd.getTextWidth(edit.fcode[widget.fT], stro)
	       if tJ == "center" then
		  x00 = 0
	       elseif tJ == "left" then
		  x00 = txW / 2
	       elseif tJ == "right" then
		  x00 = -txW / 2
	       end
	       drawTextCenter(widget.xRT + x00, yc + (0.94 * txH) * ii, stro,
			    edit.fcode[widget.fT])
	    end
	 end
      elseif widget.type == "verticalTape" then
	 
	 local ren = lcd.renderer()
	 local width = widget.width;
	 local height = widget.height;
	 local barW = width - 110;
	 local barH = height - 30;
	 
	 local val = sensorVal or 0
	 
	 local wH
	 if not widget.handed then wH = "left" else wH = widget.handed end

	 -- background rectangle
	 if (widget.backColor ~= "transparent") then
	    lcd.setColor(0,0,0)
	    if widget.rgbBackColor then
	       lcd.setColor(widget.rgbBackColor.r, widget.rgbBackColor.g, widget.rgbBackColor.b)
	    end
	    lcd.drawFilledRectangle(widget.x0 - barW/2, widget.y0 - barH/2, barW, barH);
	 end
	 
	 -- outline
	 lcd.setColor(255,255,255)
	 lcd.drawRectangle(widget.x0 - barW/2, widget.y0 - barH/2, barW, barH);
	 
	 -- draw label
	 
	 local fL
	 if not widget.labelFont then
	    fL = "Mini"
	 else
	    fL = widget.labelFont
	 end
	 
	 local xL, yL
	 if not widget.xL then
	    xL = widget.x0
	    yL = widget.y0 + barH / 2 + lcd.getTextHeight(edit.fcode[fL])
	 else
	    xL = widget.xL
	    yL = widget.yL
	 end
	 
	 if (widget.labelFont ~= "None") then
	    lcd.setColor(255,255,255)
	    drawTextCenter(xL, yL, widget.label, edit.fcode[fL]);
	 end

	 local pV
	 if not widget.valuePos then
	    pV = "side"
	 else
	    pV = widget.valuePos
	 end
	 
	 local xV
	 local yV
	 local fV
	 if not widget.valueFont then
	    fV = "Mini"
	 else
	    fV = widget.valueFont
	 end
	 
	 --draw value on top
	 if (pV == "Top") then
	    if not widget.xV then
	       xV = widget.x0
	       yV = widget.y0 - barH / 2 
	    end
	    if (widget.labelFont ~= "None") then
	       lcd.setColor(255,255,255)
	       lcd.drawText(string.format("%g", val), xV, yV, edit.fcode[fV])
	    end
	 end
	 
	 -- draw pointer triangle
	 local dx, dx1
	 
	 if (wH == "left") then
	    dx = barW / 2;
	    dx1 = -5;
	 else
	    dx = -barW / 2;
	    dx1 = 5;
	 end
	 
	 lcd.setColor(255,255,255)
	 
	 ren:reset()
	 ren:addPoint(widget.x0 + dx, widget.y0 + 5)
	 ren:addPoint(widget.x0 + dx, widget.y0 - 5)
	 ren:addPoint(widget.x0 + dx + dx1, widget.y0)
	 ren:addPoint(widget.x0 + dx, widget.y0 + 5)
	 ren:renderPolygon()
	 
	 -- draw side value label box and number
	 
	 if (pV == "Side") then
	    if (wH == "left") then
	       xV = widget.x0 + barW;
	    else 
	       xV = widget.x0 - barW;
	    end
	    yV = widget.y0 + .04 * lcd.getTextHeight(edit.fcode[fV])
	    lcd.setColor(0,0,0)
	    if (widget.backColor ~= "transparent") then
	       if widget.rgbBackColor then
		  lcd.setColor(widget.rgbBackColor.r, widget.rgbBackColor.g, widget.rgbBackColor.b)
	       end
	       if (wH == "left") then
		  lcd.drawFilledRectangle(widget.x0 + barW/2, widget.y0 - 10, barW, 20)
	       else
		  lcd.drawFilledRectangle(widget.x0 - 3 * barW/2, widget.y0 - 10, barW, 20)
	       end
	    end
	    
	    lcd.setColor(255,255,255)
	    
	    if (wH == "left") then
	       lcd.drawRectangle(widget.x0 + barW/2, widget.y0 - 10, barW, 20)
	    else
	       lcd.drawRectangle(widget.x0 - 3 * barW/2, widget.y0 - 10, barW, 20)
	    end
	    
	    lcd.setColor(255,255,255)
	    local str = string.format("%d", math.floor(val + 0.5))
	    --local dy = lcd.getTextHeight(edit.fcode[fV]) / 2 + 1
	    if (wH == "left") then
	       drawTextCenter(xV, yV - 1, str, edit.fcode[fV]);
	    else
	       drawTextCenter(xV, yV - 1, str, edit.fcode[fV])
	    end
	 end

	 local step = widget.step;
	 local delta = val % step;
	 local xp, yp, yv 
	 local nums = widget.numbers; -- # of numbers shown in tape
	 local zp = nums / 2;
	 local inc = step / nums;
	 local k1 = (zp * nums) / step - (zp+1); -- should be zp .. + 1 to make sure 
	 local k2 = (zp * nums) / step + (zp+1); -- we go past clip point on both ends

	 --print(step, delta, zp, inc, k1, k2)
	 
	 local fT
	 if not widget.tapeFont then
	    fT = "Mini"
	 else
	    fT = widget.tapeFont
	 end

	 if (wH == "left") then
	    xp = widget.x0 + barW/4 + 3;
	 else
	    xp = widget.x0 - barW/4 - 2;
	 end

	 -- draw the actual tape
	 lcd.setColor(255,255,255)
	 lcd.setClipping(widget.x0 - barW / 2, widget.y0 - barH / 2, barW, barH)

	 local xc0 = widget.x0 -  barW / 2 -- clip resets 0,0 to 
	 local yc0 = widget.y0 - barH / 2  -- top left of clip region
	 local idx
	 local kdx = k1
	 local str, dy
	 
	 repeat
	    --for kdx = k1, k2, 1 do
	    idx = kdx * inc
	    yp = widget.y0 - zp * (barH / step) + (barH/step) * (delta/step) * inc + (barH / step) * idx
	    yv = zp * step / inc - step * idx / inc  + (val - delta)
	    yv = math.floor(yv * 100 + 0.5) / 100
	    str = string.format("%g", yv)
	    dy = lcd.getTextHeight(edit.fcode[fT]) / 2
	    if wH == "left" then
	       lcd.drawText(xp - xc0 - lcd.getTextWidth(edit.fcode[fT], str), yp - yc0 - dy, str,
			    edit.fcode[fT])
	    else
	       lcd.drawText(xp - xc0, yp - yc0 - dy, str, edit.fcode[fT])
	    end
	    if (wH == "left") then
	       lcd.drawLine(widget.x0 - barW/2 - xc0, yp - yc0, widget.x0 - barW/2 + 7 - xc0, yp - yc0)
	    else
	       lcd.drawLine(widget.x0 + barW/2 - xc0, yp - yc0, widget.x0 + barW/2 - 7 - xc0, yp - yc0)
	    end
	    kdx = kdx + 1
	 until kdx > k2
	 lcd.resetClipping()

	 foo = (foo or 0) + 1
	 
	 -- draw the value in overlay mode
	 if (pV == "Overlay") then
	    if (widget.backColor ~= "transparent") then
	       lcd.setColor(widget.rgbBackColor.r, widget.rgbBackColor.g, widget.rgbBackColor.b)
	       lcd.drawFilledRectangle(widget.x0 - barW/2, widget.y0 - 14, barW, 28);
	    end
	    
	    lcd.drawRectangle(widget.x0 - barW/2, widget.y0 - 12, barW, 24);
	    
	    if not widget.xV then
	       xV = widget.x0 + 20;
	       yV = widget.y0;
	    else
	       xV = widget.xV
	       yV = widget.yV
	    end
	    
	    if (widget.valueFont ~= "None") then
	       str = string.format("%g", math.floor(val * 100 + 0.5) / 100)
	       lcd.drawText(str, xV - lcd.getTextWidth(edit.fcode[widget.valueFont], str) ,
			    yV, edit.fcode[widget.valueFont]);
	    end
	    --ctx.strokeStyle = "white";
	    --ctx.beginPath();
	    lcd.setColor(255,255,255)
	    lcd.drawRectangle(widget.x0 - barW/2, widget.y0 - barH/2, barW, barH);
	    --ctx.stroke();
	 end
      elseif widget.type == "artHorizon" then
	 
	 local HP = require 'DFM-InsP/hp1345a'
	 local function drawPitch(roll, pitch, pitchR, radAH, X0, Y0, scl)

	    local XH,YH,X1,X2,X3,Y1,Y2,Y3,X4,Y4
	    local pp, pps
	    local XHS = 18 * radAH / 70
	    local  XHL = 40 * radAH / 70
	    local  scale = scl * radAH / 70
	    
	    local sinRoll = math.sin(math.rad(-roll))
	    local cosRoll = math.cos(math.rad(-roll))
	    local delta = pitch % 15    
	    local ren = lcd.renderer()
	    
	    --for (let i = delta - 45; i < 45 + delta; i = i + 15) {

	    local i = delta - 45
	    repeat
	       --if (math.abs(pitch - i % 360) < 0.01) then
	       if math.abs(pitch - i) < 0.01 then
		  XH = XHL;
	       else
		  XH = XHS;
	       end
	       YH = pitchR * i                      
	       pp = pitch - i
	       pps = string.format("%d", math.floor(pp*10 + 0.5) / 10)
	       
	       X1 = -XH * cosRoll - YH * sinRoll;
	       Y1 = -XH * sinRoll + YH * cosRoll;
	       X2 = (XH - 0) * cosRoll - YH * sinRoll;
	       Y2 = (XH - 0) * sinRoll + YH * cosRoll;
	       X3 = (XH + 5) * cosRoll - (YH - 3) * sinRoll;
	       Y3 = (XH + 5) * sinRoll + (YH - 3) * cosRoll;	
	       X4 = (-XH - 18 * scale * #pps - 5) * cosRoll - (YH - 3) * sinRoll;
	       Y4 = (-XH - 18 * scale * #pps - 5) * sinRoll + (YH - 3) * cosRoll;	
	       
	       if( not ( (X1 < -radAH and X2 < -radAH) or  (X1 > radAH and X2 > radAH)
		      or (Y1 < -radAH and Y2 < -radAH) or  (Y1 > radAH and Y2 > radAH) ) ) then
		  lcd.setColor(255,255,255)
		  ren:reset()
		  ren:addPoint(X0 + radAH + X1, Y0 + radAH + Y1)
		  ren:addPoint(X0 + radAH + X2, Y0 + radAH + Y2)
		  ren:renderPolyline(2)
		  if (XH == XHS) then
		     HP.drawHP1345A(X0 + radAH + X3, Y0 + radAH + Y3, pps, scale,
				    math.rad(roll), 2);
		     HP.drawHP1345A(X0 + radAH + X4, Y0 + radAH + Y4, pps, scale,
				    math.rad(roll), 2);
		  end
	       end
	       i = i + 15
	    until i >= 45 + delta
	 end

	 --[[
	    function artHorizon is based on code in the Jeti Artificial Horizon App
	    
	    Copyright (c) 2016 JETI
	    Copyright (c) 2015 dandys.
	    Copyright (c) 2014 Marco Ricci.
	    
	    Use here conforms with the license terms
	 --]]
    
	 local pitch = pitchVal or 0 -- system.getInputs("P2") * 90
	 local roll = rollVal or 0 --system.getInputs("P3") * 180

	 local rowAH = widget.width / 2 - 20;
	 local radAH = widget.width / 2 - 20;
	 local pitchR = radAH / 25;

	 local tanRoll
	 local cosRoll
	 
	 local dPitch_1
	 local dPitch_2

	 local X0, Y0, X1, Y1, Y2, YH
	 local ren = lcd.renderer()

	 if pitch >= 0 then -- heaven knows why we have to do this
	    dPitch_1 = pitch % 180
	 else
	    dPitch_1 = -1*(-pitch % 180)
	 end
	 
	 --print(pitch, dPitch_1)
	 if (dPitch_1 > 90) then
	    dPitch_1 = 180 - dPitch_1
	 end
	 if (roll == 270) then
	    roll = 269.99;
	 end
	 if (roll == 90) then
	    roll = 89.99;
	 end
	 
	 cosRoll = 1 / math.cos(math.rad(roll))
	 
	 if (pitch > 270) then
	    dPitch_1 = -dPitch_1 * pitchR * cosRoll
	    dPitch_2 = radAH * cosRoll
	 elseif (pitch > 180) then
	    dPitch_1 = dPitch_1 * pitchR * cosRoll
	    dPitch_2 = -radAH * cosRoll
	 elseif (pitch > 90) then
		  dPitch_1 = -dPitch_1 * pitchR * cosRoll
		  dPitch_2 = -radAH * cosRoll
	 else
	    dPitch_1 = dPitch_1 * pitchR * cosRoll
	    dPitch_2 = radAH * cosRoll
	 end

	 --print(dPitch_1, dPitch_2)
	 
	 tanRoll = -math.tan(math.rad(roll))
	 
	 X1 = 0
	 YH = (-radAH) * tanRoll
	 Y1 = YH + dPitch_1
	 Y2 = YH + 1.5 * dPitch_2 
	 
	 -- define clipping region 
	 X0 = widget.x0 - radAH
	 Y0 = widget.y0 - radAH
	 lcd.setClipping(X0, Y0, 2 * radAH, 2 * radAH)
	 X0 = 0
	 Y0 = 0
	 -- draw sky over entire box
	 lcd.setColor(widget.rgbSkyColor.r, widget.rgbSkyColor.g, widget.rgbSkyColor.b)
	 lcd.drawFilledRectangle(X0, Y0, 2 * radAH + 1, 2 * radAH + 1);
	 
	 lcd.setColor(widget.rgbLandColor.r, widget.rgbLandColor.g, widget.rgbLandColor.b)
	 ren:reset()

	 if (Y1 < Y2) then
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
	 elseif (Y1 > Y2) then
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
	 end

	 X1 = 2 * radAH + 1
	 YH = (radAH) * tanRoll
	 Y1 = YH + dPitch_1
	 Y2 = YH + 1.5 * dPitch_2
	 
	 if (Y1 < Y2) then
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
	 elseif (Y1 > Y2) then
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y1)
	    ren:addPoint(X0 + X1, Y0 + rowAH + Y2)
	 end				       
	 ren:renderPolygon(1)
	 
	 lcd.setColor(255,255,255)
	 lcd.drawLine(X0, Y0, X0, Y0 + 2 * radAH + 1);
	 lcd.drawLine(X0 + 2 * radAH - 1, Y0, X0 + 2 * radAH - 1, Y0 + 2 * radAH - 1)
	 lcd.drawLine(X0, Y0 + 2 * radAH - 1, X0 + 2 * radAH - 1, Y0 + 2 * radAH - 1)
	 lcd.drawLine(X0, Y0, X0 + 2 * radAH, Y0)

	 lcd.drawLine(X0 + radAH - 0.7 * radAH, Y0 + radAH, X0 + radAH - 0.2 * radAH, Y0 + radAH);
	 lcd.drawLine(X0 + radAH - 0.2 * radAH, Y0 + radAH,
		      X0 + radAH - 0.2 * radAH, Y0 + radAH + radAH / 10);
	 lcd.drawLine(X0 + radAH + 0.7 * radAH, Y0 + radAH, X0 + radAH + 0.2 * radAH, Y0 + radAH);
	 lcd.drawLine(X0 + radAH + 0.2 * radAH, Y0 + radAH,
		      X0 + radAH + 0.2 * radAH, Y0 + radAH + radAH / 10);
	 drawPitch(roll, pitch, pitchR, radAH, X0, Y0, 0.4);
	 
	 lcd.resetClipping()

	 --X0 = widget.x0 - radAH
	 --Y0 = widget.y0 - radAH

	 local fL
	 if not widget.labelFont then
	    fL = "Mini"
	 else
	    fL = widget.labelFont
	 end
	 
	 if not widget.xL then
	    widget.xL = widget.x0
	    widget.yL = widget.y0 + radAH + lcd.getTextHeight(edit.fcode[fL])
	 end

	 lcd.setColor(255,255,255)
	 drawTextCenter(widget.xL, widget.yL, widget.label, edit.fcode[fL])
      elseif widget.type == "chartRecorder" then

	 --local chartOffsetXL = 12;
	 --local chartOffsetYT = 18;
	 --local chartOffsetYB = 20;
	 --local chartOffsetXV = 34;

	 local chartOffsetV = 13;
	 
	 local timeStamps = {
	    {"0:00", "0:05", "0:10", "0:15", "0:20", "0:25", "0:30"},
	    {"0:00", "0:10", "0:20", "0:30", "0:40", "0:50", "1:00"},
	    {"0:00", "0:20", "0:40", "1:00", "1:20", "1:40", "2:00"},
	    {"0:00", "0:40", "1:20", "2:00", "2:40", "3:20", "4:00"},
	    {"0:00", "1:20", "2:40", "4:00", "5:20", "6:40", "8:00"}
	 }
	 
	 local maxTraces = widget.maxTraces or 1
	 maxTraces = math.max(1, math.min(4, maxTraces));

	 local barOffset
	 local barWidth = 21;

	 local traceNumber = widget.traceNumber or 1
	 barOffset = (traceNumber - 1) *  (barWidth);
	 barOffset = math.max(0, math.min(3 * barWidth, barOffset));

	 --local chartOffsetXR = barWidth + maxTraces * barWidth;

	 local timeSpan = stampIndex[widget.timeSpan or "t60"]

	 --arrR.boxW = 2 * (arr.width / 2 - chartOffsetXR / 2 - chartOffsetXL / 2) + 4;
	 --arrR.boxH = arr.height - (chartOffsetYT + chartOffsetYB);
	 --arrR.boxXL = arr.x0 - arr.width/2 + chartOffsetXL;
	 --arrR.boxYL = arr.y0 - arr.height/2 + chartOffsetYT;
	 --arrR.vertX = arrR.boxXL + arrR.boxW + chartOffsetXV;
	 --arrR.vertYB = arrR.boxYL + arrR.boxH
	 --arrR.vertYT = arrR.boxYL
    
	 setColorRGB(widget.rgbBackColor)
	 
	 if (traceNumber == 1 and widget.backColor ~= "transparent" ) then
	    lcd.drawFilledRectangle(widget.x0 - widget.width/2,
				    widget.y0 - widget.height/2, widget.width, widget.height)
	    --lcd.setColor(255,0,0)
	    --lcd.drawRectangle(1,1,318,158)
	 end

	 lcd.setColor(255,255,255)
	 --print(widget.x0 - widget.width/2, widget.y0 - widget.height/2, widget.width, widget.height)
	 
	 --lcd.drawRectangle(widget.x0 - widget.width/2, widget.y0 - widget.height/2,
	 --widget.width, widget.height);
	 
	 setColorRGB(widget.rgbChartBackColor)
	 
	 if (traceNumber == 1) then
	    lcd.drawFilledRectangle(widget.boxXL, widget.boxYL, widget.boxW, widget.boxH);
	 end

	 lcd.setColor(255,255,255)
	 if (traceNumber == 1) then
	    lcd.drawRectangle(widget.boxXL, widget.boxYL, widget.boxW, widget.boxH);
	 end
	 
	 lcd.drawLine(widget.vertX + barOffset, widget.vertYB, widget.vertX + barOffset, widget.vertYT)
	 
	 local ticL = 6; 
	 for i=0,10,1 do 
	    local tl
	    if (i % 5 == 0) then tl = ticL else tl = ticL / 2 end
	    lcd.drawLine(widget.vertX + barOffset,
			 widget.vertYB + i * (widget.vertYT - widget.vertYB) / 10,
			 widget.vertX - tl + barOffset,
			 widget.vertYB + i * (widget.vertYT - widget.vertYB) / 10)	
	 end
	 
	 lcd.setColor(255,255,255)

	 -- set font to "Mini"
	 
	 local hh = lcd.getTextHeight(FONT_MINI) + 6

	 local str
	 str = string.format("%d", widget.min)
	 drawTextCenter(widget.vertX - chartOffsetV + barOffset, widget.vertYB + hh / 2 -2, str, FONT_MINI)
	 str = string.format("%d", widget.max)
	 drawTextCenter(widget.vertX - chartOffsetV + barOffset, widget.vertYT - hh / 2, str, FONT_MINI)

	 local xx

	 if (traceNumber == 1) then

	    local now
	    local timeS
	    local timeLine
	    local timeTic
	    local remTic
	    local intTic
	    
	    --local now = system.getTimeCounter()

	    if #widget.chartSample >= MAXSAMPLE then
	       now = system.getTimeCounter() -- widget.chartSampleXP[MAXSAMPLE]
	       timeS = (now - widget.chartStartTime) / 1000.0
	       timeLine = widget.chartInterval * MAXSAMPLE / 1000
	       timeTic = timeLine / 6
	       remTic = timeS % timeTic
	       intTic = (timeS // timeTic) * timeTic
	    end
	    
	    local mm, ss, str
	    --print(timeS, timeLine, #widget.chartSample)
	    for i=-1,6,1 do
	       xx = widget.boxXL + i * widget.boxW / 6
	       if i == 6 then xx = xx - 1 end
	       --if timeS < timeLine then
	       if #widget.chartSample < MAXSAMPLE then
		  --if #widget.chartSample < MAXSAMPLE then
		  --print("timeS, timeLine", timeS, timeLine)
		  if i >= 0 then
		     drawTextCenter(xx, widget.vertYB + hh - 6, timeStamps[timeSpan][i + 1], FONT_MINI)
		     lcd.drawLine(xx, widget.vertYB, xx, widget.vertYB + ticL)
		  end
	       else
		  --now = widget.chartSampleXP[MAXSAMPLE]
		  --timeS = (now - widget.chartStartTime) / 1000.0
		  --remTic = timeS % timeTic
		  --intTic = (timeS // timeTic) * timeTic
		  xx = widget.boxW - math.floor(remTic * widget.boxW / timeLine + 0.5)
				     - i * math.floor(widget.boxW / 6 + 0.5)
		  mm = (intTic - timeTic * i) // 60
		  ss = intTic - timeTic * i - mm * 60
		  str = string.format("%d:%02d", mm, ss)
		  lcd.setClipping(widget.boxXL, 0, widget.boxW, 160)
		  drawTextCenter(xx, widget.vertYB + hh - 6,
				 str, FONT_MINI)
		  lcd.drawLine(xx, widget.vertYB, xx, widget.vertYB + ticL)
		  lcd.resetClipping()
		  
		  --[[
		  -------------------------------------------
		  if 6 - i + 1 == 1 then
		     str = "Now"
		  else
		     str = "-" .. timeStamps[timeSpan][6 - i + 1]
		  end
		  drawTextCenter(xx, widget.vertYB + hh - 6, str, FONT_MINI)
		  lcd.drawLine(xx, widget.vertYB, xx, widget.vertYB + ticL)
		  -------------------------------------------
		  --]]

	       end
	    end
	 end

	 local xmin = 0;
	 local xmax = 2;
	 local ymin = 0;
	 local ymax = 100;
	 local x, xp, y, yp, fx, fy

	 setColorRGB(widget.rgbChartTraceColor)

	 local np = 0
	 local yc 
	 local ren = lcd.renderer()
	 if sensorVal and widget.chartSample and #widget.chartSample > 0 then
	    ren:reset()
	    local aa = widget.boxW / MAXSAMPLE
	    local bb = widget.boxXL
	    local cc = widget.chartSampleYP
	    for i, v in ipairs(widget.chartSample) do
	       --xp = widget.chartSampleXP[i]
	       yp = cc[i]
	       xp = bb + i * aa 
	       --yc = math.max(ymin, math.min(v, ymax))
	       --fy = (yc - ymin) / (ymax - ymin)	    
	       --yp = widget.boxYL + (1 - fy) * widget.boxH
	       if np < 127 then
		  ren:addPoint(xp, yp)
		  np = np + 1
	       else
		  ren:addPoint(xp, yp)
		  ren:renderPolyline(2)
		  ren:reset()
		  ren:addPoint(xp, yp)
		  np = 1
	       end
	    end
	 end
      	 ren:renderPolyline(2)

	 --[[
	 for t= 0,2,0.02 do
	    x = t;
	    y = 0.9 * math.sin(2 * math.pi * (t -  math.pi / 4 * (traceNumber - 1)));
	    fx = (x - xmin) / (xmax - xmin);
	    xp = widget.boxXL + fx * widget.boxW
	    fy = (y - ymin) / (ymax - ymin)
	    yp = widget.boxYL + (1 - fy) * widget.boxH
	    ren:addPoint(xp, yp);
	 end
	 ren:renderPolyline(2)
	 --]]

	 ymin = widget.min;
	 ymax = widget.max;

	 if sensorVal then
	    fy = (sensorVal - ymin) / (ymax - ymin);
	    fy = math.max(0, math.min(fy, 1));
	    lcd.drawFilledRectangle(widget.vertX - 3 * ticL + barOffset,
				    widget.vertYT + (1 - fy) * widget.boxH,
				    2 * ticL, fy * widget.boxH);
	    
	 end
	 hh = lcd.getTextHeight(FONT_MINI) + 2;
	 --print(hh)
	 local labelStep = 3 + widget.boxW / maxTraces;
	 local labelOffset = (traceNumber - 1) * labelStep - hh / 2
	 
	 lcd.setColor(255,255,255)
	 --local function drawFilledBezel(xc,yc,w,h,z)
	 --print(widget.boxYL, hh)
	 drawFilledBezel(widget.boxXL + labelOffset + hh / 2, widget.boxYL - hh/2 -1, hh-2, hh-2, 3)
	 --set font to "Mini"
	 --ctx.textAlign = "left";
	 lcd.drawText(widget.boxXL + labelOffset + hh + 2, widget.boxYL - hh - 1, widget.label, FONT_MINI)
	 setColorRGB(widget.rgbChartTraceColor)
	 --ctx.fillStyle = traceColor;
	 drawFilledBezel(widget.boxXL + labelOffset + hh/2, widget.boxYL - hh/2 - 1, hh - 4, hh - 4, 3)
      end
   end
   ---[[
   lcd.setColor(255,255,255)
   if select(2, system.getDeviceType()) == 1 then
      lcd.drawText(300,70, string.format("%02d", math.floor(loopCPU + 0.5)), FONT_MINI)   
      lcd.drawText(300,90, string.format("%02d", system.getCPU()), FONT_MINI)
   end
   --]]
end

local function prtForm(w,h)
   
   if subForm == formN.editlua then
      --print("prtForm formN.editlua", savedRow, savedRow2)
      --if lua.loadErr then
	 --print(lua.loadErr)
	 --lcd.drawText(5,0, lua.loadErr, FONT_MINI)
      --end
      --print("calling setVariables", savedRow)
      setVariables()
      if savedRow == 3 then
	 local sp = InsP.settings.selectedPanel
	 if not InsP.panels[sp][savedRow2].luastring then
	    InsP.panels[sp][savedRow2].luastring = {}
	    --InsP.panels[sp][savedRow2].luastring[1] = ""
	 end
	 LE.luaEditPrint(InsP.panels[sp][savedRow2], 1, evaluate)
      elseif savedRow == 6 then
	 LE.luaEditPrint(InsP.variables[savedRow2], 1, evaluate)	 
      end
      
   elseif subForm == formN.editpanel and InsP.panels[InsP.settings.selectedPanel] then
      local ip = InsP.panels[InsP.settings.selectedPanel]
      if dispSave == 0 then
	 dispSave = InsP.settings.window1Panel
      end
      InsP.settings.window1Panel = InsP.settings.selectedPanel
      printForm(318,159,1)
      lcd.setColor(180,180,180)
      lcd.drawFilledRectangle(0, 158, 318, 20)
      lcd.setColor(0,0,0)
      local ipeg = ip[edit.gauge]
      if not ipeg then return end
      local xx, yy = ipeg.x0, ipeg.y0 -- default for Center
      local ff
      local ss
      local mm
      local dd
      local ii = edit.ops[edit.opsIdx]
      if (ii == "Value") and ipeg.xV then
	 xx = ipeg.xV
	 yy = ipeg.yV
	 ff = ipeg.fV
      elseif (ii == "Label") and ipeg.xL then
	 xx = ipeg.xL
	 yy = ipeg.yL
	 ff = ipeg.fL
      elseif (ii == "Text") and (ipeg.xT or ipeg.xRT) then
	 if ipeg.xRT then
	    xx = ipeg.xRT
	    yy = ipeg.yRT
	    else
	    xx = ipeg.xT
	    yy = ipeg.yT
	 end
	 ff = ipeg.fT	 
      elseif (ii == "MMLbl") and ipeg.xLV and ipeg.xRV then
	 xx = (ipeg.xLV + ipeg.xRV) / 2
	 yy = ipeg.yLV
	 ff = ipeg.fLRV
      elseif (ii == "Center") and ipeg.xPL then
	 xx = ipeg.xPL
	 yy = ipeg.yPL
	 ff = ipeg.fL
      elseif (ii == "TicLbl") and ipeg.fTL then
	 ff = ipeg.fTL
	 dd = ipeg.dp
      elseif (ii == "TicSpc") and ipeg.TS then
	 ss = tonumber(math.floor(ipeg.TS))
      elseif (ii == "MinMx") then
	 mm = "Edit Min Max"
	 if ipeg.type == "chartRecorder" then
	    xx = ipeg.vertX - ipeg.barWidth / 2 + (ipeg.traceNumber - 1) * ipeg.barWidth
	    yy = (ipeg.vertYB + ipeg.vertYT) / 2
	    ff = "Mini"
	 end
	 
      end

      --print("typ", ipeg.type, edit.gaugeName[ipeg.type].sn)
      
      local typ = edit.gaugeName[ipeg.type].sn
      if not typ then typ = "---" end

      if not dd then dd = 0 end
      
      local fn
      if ff then fn = string.format("D: %d F: ", dd) else fn = ""; ff = "" end
      if ss then fn = "Spacing: "; ff=ss end
      if mm then fn = ""; ff = mm end
      
      lcd.drawText(10, 157,
		   string.format("Widget %d Type: %s  [%d,%d]  %s %s",
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
      save.colors = InsP.colors
      save.widgetColors = InsP.widgetColors      
      --print("saving jsnVersion", jsnVersion)
      save.jsnVersion = jsnVersion
      save.stateSw = stateSw
      for k,v in pairs(stateSw) do
	 -- remove switchItem keys
	 -- will reconstitute switchitem(s) on init since
	 -- we can't serialize them to json
	 v.switch = nil 
      end
      
      -- convert Id to hex, otherwise it comes in as a float and loss of precision
      -- creates invalid result on read
      if save.panels then
	 for i in ipairs(save.panels) do
	    if not save.panels[i] then print("nil panel", i) end
	    for k, v in ipairs(save.panels[i]) do
	       for kk,vv in pairs(v) do
		  if kk == "chartSample" then v[kk] = {} end
		  if kk == "chartSampleYP" then v[kk] = {} end
		  if kk == "chartSampleXP" then v[kk] = {} end		  		  
		  if kk == "SeId" or kk == "rollSeId" or kk == "pitchSeId" then
		     v[kk] = string.format("0X%X", vv)
		  end
	       end
	    end
	 end
      end

      if save.variables then
	 for i,v in ipairs(save.variables) do
	    if v.SeId then save.variables[i].SeId = string.format("0X%X", v.SeId) end
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

local function initNewer(sf, tbl)

   form.setTitle("Newer Panels are available")

   form.addRow(1)
   form.addLabel({label="Press OK then go to the Panels menu",
		  width=320, font=FONT_MINI})
   form.addRow(1)
   form.addLabel({label="Delete then re-read the panel(s)",
		  width=320, font=FONT_MINI})

   for i,v in ipairs(tbl) do
      form.addRow(3)
      form.addLabel({label = tostring(i)..".", width=30})      
      form.addLabel({label = v.fn, width=120})
      form.addLabel({label = string.sub(v.ts,1,19), width=160})
   end

   form.setFocusedRow(3)

end

local function luaLogCB(idx)
   setVariables()
   ret, dp = 0, 2
   for k,v in ipairs(InsP.variables) do
      if idx and v.logID and v.logID == idx then
	 ret = v.value
	 break
      end
   end
   return math.floor(ret * 100 +  0.5), dp
end

local function init()

   local decoded
   local mn
   local file

   local backColors = {
      {colorname="grey",        red=128, green=128, blue=128},
      {colorname="lavender",    red=230, green=230, blue=250},
      {colorname="lightgrey",   red=211, green=211, blue=211},
      {colorname="lightyellow", red=255, green=255, blue=224},
      {colorname="nightrider",  red=48,  green=48,  blue=48},
      {colorname="silver",      red=192, green=192, blue=192}
   }
   
   local widgetColors = {
      {colorname="aqua",  red=0,   green=255, blue=255},
      {colorname="black", red=0,   green=0,   blue=0},
      {colorname="blue",  red=0,   green=0,   blue=255},
      {colorname="fuscia",red=255, green=0,   blue=255},
      {colorname="gray",  red=128, green=128, blue=128},
      {colorname="green", red=0,   green=128, blue=0},
      {colorname="lime",  red=0,   green=255, blue=0},
      {colorname="maroon",red=128, green=0,   blue=0},
      {colorname="navy",  red=0,   green=0,   blue=128},
      {colorname="olive", red=128, green=128, blue=0},
      {colorname="orange",red=255, green=165, blue=0},
      {colorname="purple",red=128, green=0,   blue=128},
      {colorname="red",   red=255, green=0,   blue=0},
      {colorname="silver",red=192, green=192, blue=192},
      {colorname="teal",  red=0,   green=128, blue=128},
      {colorname="white", red=255, green=255, blue=255},
      {colorname="yellow",red=255, green=255, blue=0}
   }
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   local ff = prefix() .. "Apps/DFM-InsP/II_" .. mn .. ".jsn"

   file = io.readall(ff)
   if file then
      if string.find(file, "null") then print("DFM-InsP: Warning - null in JSON") end
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

      InsP.colors = decoded.colors -- see below if nil
      InsP.widgetColors = decoded.widgetColors -- see below if nil
      
      InsP.variables = decoded.variables
      if not InsP.variables then InsP.variables = {} end

      for i,v in ipairs(InsP.variables) do
	 if v.SeId then InsP.variables[i].SeId = tonumber(v.SeId) end
      end
      
      if decoded.jsnVersion then
	 jsnVersion = decoded.jsnVersion
      end

      --print("DFM-InsP reading jsnVersion "..jsnVersion)

      if decoded.stateSw then
	 stateSw = decoded.stateSw
      else
	 stateSw = {}
      end
      
      for i in ipairs(InsP.panels) do
	 for _ ,v in ipairs(InsP.panels[i]) do
	    for kk,vv in pairs(v) do
	       if kk == "SeId" or kk == "rollSeId" or kk == "pitchSeId" then
		  --print(v.type,kk,vv)
		  v[kk] = tonumber(vv) -- convert back from hex
	       end
	       if kk == "minval"  then v[kk] = nil end
	       if kk == "maxval"  then v[kk] = nil end
	    end
	 end
      end
   else
      print("DFM-InsP: Did not read any jsn panel file")
      initPanels(InsP)
   end

   --print("InsP.colors", InsP.colors)
   
   if not InsP.colors then
      InsP.colors = {}
      for k,v in pairs(backColors) do
	 InsP.colors[k] = v
      end
   end

   if not InsP.widgetColors then
      InsP.widgetColors = {}
      for k,v in pairs(widgetColors) do
	 InsP.widgetColors[k] = v
      end
   end
   
   InsP.settings.fileBD = ff
   InsP.settings.writeBD = true
   
   InsP.settings.window1Panel = 1
   if not InsP.settings.window2Panel then InsP.settings.window2Panel = 0 end
   if #InsP.panels > 1 then
      InsP.settings.window2Panel = 2
   end

   if not InsP.settings.selectedPanel then InsP.settings.selectedPanel = 1 end

   --print("InsP.settings.units", InsP.settings.units)
   
   if not InsP.settings.units  then
      InsP.settings.units  = {}
      for k,v in pairs(units.typeList) do
	 --print("#", k, v[1])
	 InsP.settings.units[k] = v[1]
      end
      --InsP.settings.units.temp  = units.temp[1] 
      --InsP.settings.units.dist  = units.dist[1]
      --InsP.settings.units.speed = units.speed[1]
   end
   
   -- Populate a table with all the panel json files
   -- in the Panels/ directory

   --local t1 = system.getTimeCounter()
   
   InsP.settings.panels = {'...'}
   local dd, fn, ext
   local newerPanels = {}
   local path = prefix() .. pDir
   if dir(path) then
      --print("dir(path) true for Panels")
      for name, _, _ in dir(path) do
	 dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
	 if fn and ext then
	    if string.lower(ext) == "json" then
	       ff = path .. "/" .. fn .. "." .. ext
	       file = io.readall(ff)
	       if file then
		  local dc = json.decode(file)
		  local ts = dc.timestamp
		  if ts then
		     for i in ipairs(InsP.panels) do
			if InsP.panelImages[i].instImage == fn then
			   if ts > (InsP.panelImages[i].timestamp or "0") then
			      table.insert(newerPanels, {fn = fn, ts = ts})
			   end
			   break
			end
		     end
		  end
		  if not InsP.settings.panels then InsP.settings.panels = {} end
		  table.insert(InsP.settings.panels, fn)
	       end
	    end
	 end
      end
   else
      system.messageBox("DFM-InsP: No panels directory")
      print("DFM-InsP: bad path to dir - "..path)      
   end
   

   if #newerPanels > 0 then
      system.registerForm(2, 0, "Newer Panels", (function(x) return initNewer(x, newerPanels) end))
   end
   
   table.sort(InsP.settings.panels)

   -- Populate a table with all the background image files
   -- in the Backgrounds/ directory
   
   InsP.settings.backgrounds = {"..."}
   --local dd, fn, ext
   path = prefix() .. bDir
   if dir(path) then
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
   else
      print("DFM-InsP: bad path to dir - "..path)      
   end
   
   table.sort(InsP.settings.backgrounds)

   local lostSw = ""
   for k, swi in pairs(InsP.settings.switchInfo) do
      local ud = system.pLoad(k)
      --print("switches", k, swi.name, swi.seqIdx, ud)
      if ud then
	 --print("Using switch userdata: " .. k)
	 switches[k] = ud
      else
	 --print("swi.name", swi.name)
	 local t = string.sub(swi.name,1,1)
	 -- we don't need userdata for controls, switches and log. switches
	 -- we do need it for more exotic controls .. mark them lost of the
	 -- userdata is missing
	 if t ~= "P" and t ~= "S" and t ~= "L" then
	    lostSw = lostSw .. " "..k
	 end
	 switches[k] = system.createSwitch(swi.name, swi.mode, swi.activeOn)
      end
      local iss = InsP.settings.switchInfo[k]
      if iss.seqIdx and iss.seqIdx <= #stateSw then
	 --print("iss.seqIdx", iss.seqIdx, stateSw, #stateSw)
	 stateSw[iss.seqIdx].switch = switches[k]
      end
   end

   if lostSw ~= "" then
      system.messageBox("See lua console to reassign switches")
      print("Please reassign "..lostSw)
   end

   --[[
   for _,v in ipairs(InsP.panelImages) do
      if not v.auxWin then v.auxWin = 1 end
   end
   --]]
   
   for k,v in ipairs(InsP.variables) do
      if v.source == "Lua" then
	 InsP.variables[k].logID = system.registerLogVariable(string.sub(v.name, 1, 14), "", luaLogCB)
	 --print("registerLog", v.name, v.source, v.luastring[1], InsP.variables[k].logID)
      end
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

   local dd, fn, ext, fr
   local path = prefix() .. fDir
   lua.funcmods = {}
   local ifunc = 0
   if dir(path) then
      for name, _, _ in dir(path) do
	 dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
	 if fn and ext then
	    if string.lower(ext) == "lua" then
	       ff = path .. "/" .. fn .. "." .. ext
	       file = io.open(ff)
	       if file then
		  io.close(file)
		  ifunc = ifunc + 1
		  fr = fmDir.."/"..fn
		  lua.funcmods[ifunc] = require(fr)
	       end
	    end
	 end
      end
   else
      print("DFM-InsP: bad path to dir - "..path)
   end
   

   lua.funcext = {}
   for i, m in ipairs(lua.funcmods) do
      for k,v in pairs(m) do
	 --print("i, k, v", i, k, v)
	 table.insert(lua.funcext, {idx=i, name=k.."(", func=v})
      end
   end

   print("DFM-InsP: function modules read: " .. #lua.funcext)

   local dd, fn, ext, fr
   local path = prefix() .. xDir
   lua.extmods = {}
   local modname = {}
   local imod = 0

   if dir(path) then
      for name, _, _ in dir(path) do
	 dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
	 if fn and ext then
	    if string.lower(ext) == "lua" then
	       ff = path .. "/" .. fn .. "." .. ext
	       file = io.open(ff)
	       if file then
		  io.close(file)
		  imod = imod + 1
		  fr = xmDir.."/"..fn
		  lua.extmods[imod] = require(fr)
		  --print("modname[imod]", fn)
		  modname[imod] = fn
	       end
	    end
	 end
      end
   else
      print("DFM-InsP: bad path to dir - "..path)      
   end
   

   lua.modext = {}
   for i, m in ipairs(lua.extmods) do
      for k,v in pairs(m) do
	 table.insert(lua.modext, {idx=i, name=modname[i].."_"..k.."()", func=v})
      end
   end

   -- Look for references to modules in all panel widgets in all panels
   -- Make sure the numeric reference is set to the correct name
   -- This is in case modules were deleted which would change numbering

   for i, panel in ipairs(InsP.panels) do
      for j, widget in ipairs(panel) do
	 if widget.modext then
	    --print(InsP.panelImages[i].instImage, widget.type, widget.modext, widget.modextName)
	    widget.modext = 0
	    for k, ext in ipairs(lua.modext) do
	       if widget.modextName == ext.name then
		  widget.modext = k
		  break
	       end
	    end
	    if widget.modext == 0 then
	       widget.modextName = nil
	       widget.modext = nil
	    end
	 end
      end
   end
   
   print(string.format("DFM-InsP: %d extension modules read with %d functions",
		       #lua.extmods, #lua.modext))

   print("DFM-InsP: Version " .. InsPVersion)
   
end

return {init=init, loop=loop, author="DFM", version=InsPVersion, name="DFM-InsP", destroy=destroy}
