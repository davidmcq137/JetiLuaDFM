--[[

----------------------------------------------------------------------------

   DFM-Temp 17-Dec-2022 Derived from SB-Temp .. allow for arbitrary temp sensors

   (was: SB-Temp Display -- makes a Telemetry Window for Carsten Groen's SB-Temp
   sensor)

   Implements one fullscreen telemetry windows and one menu for editing parms
   or settable items

   Borrows some display code from Daniel's excellent CTU.lua program

   Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------

   Released under MIT-license

   Copyright (c) 2019 DFM

   Permission is hereby granted, free of charge, to any person 
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:
   
   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.
   
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.

--]]

----------------------------------------------------------------------------

local appShort   = "DFM-Temp"
local appName    = "Temp Display"
local appAuthor  = "DFM"
local appVersion = "1.1"
local appDir = "Apps/DFM-Temp/"
local transFile  = appDir .. "Trans.jsn"
local savedForm = 1

local SBTDeviceID=42054 -- 0xA446 so device 0 is 0x0100a446 = 16819270
local SBTDeviceNumber
local SBTChannelsActive

----------------------------------------------------------------------------

local ren = lcd.renderer()
local screens={}
local arcFile = {}
local screenConfig={}
local screenIdx, screenString
local builtIn
local maxBuiltIn
local backGndImage
local jsnFileName
local dx1, dx2 = 0, 0
local idNonTemp = {}
local paramNonTemp = {}
local blackText

local allGreenEn, allGreenEnIndex, allGreenEver
local hotWarnEn, hotWarnEnIndex
local hotWarnAnnounced={}

local SBT_Telem = {
   T1={SeId=0,SePa=0, unit=" "},
   T2={SeId=0,SePa=0, unit=" "},
   T3={SeId=0,SePa=0, unit=" "},
   T4={SeId=0,SePa=0, unit=" "},
   T5={SeId=0,SePa=0, unit=" "},
   T6={SeId=0,SePa=0, unit=" "},
   T7={SeId=0,SePa=0, unit=" "},
   T8={SeId=0,SePa=0, unit=" "},
}

local sensorLalist = { "..." }  -- sensor labels with device prefix
local sensorLslist = { "..." }  -- sensor labels without device prefix
local sensorIdlist = {0}  -- sensor IDs
local sensorPalist = {0}  -- sensor parameters
local telemSelected = {}

local needle_poly_small = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}

local function setTextColor()
   local is = system.getProperty("Color")
   if is == 7 or is == 9 or is == 10 or is == 11 then
      lcd.setColor(255,255,255)
   else
      lcd.setColor(0,0,0)
   end
end

local function readSensors()
   local text
   local sensors
   local sensorCode
   local sensorNumber
   local saveLabel="***"
   local ii = 0

   
   sensors = system.getSensors()
   --print("sensors:", sensors)
   
   for _, sensor in ipairs(sensors) do
      -- first check if a SBTemp sensor .. keep track of all those
      if (sensor.label ~= "" and sensor.id & 0xFFFF == 0xA446) then
	 sensorNumber = ((sensor.id >> 16) & 0xF0) >> 4
	 if not sensorCode then print("SB-Temp device: ", sensorNumber) end
	 sensorCode = sensor.id & 0xFFFF
	 --print("hex sensor.id:"..string.format("%x", sensor.id))
	 --print("sensorCode: "..string.format("%x", sensorCode))
	 --print("sensorNumber: "..string.format("%x", sensorNumber))
	 if sensorCode == SBTDeviceID and sensorNumber == SBTDeviceNumber and sensor.param ~= 0 then
	    ii = ii + 1
	    SBT_Telem[sensor.label].SeId = sensor.id
	    SBT_Telem[sensor.label].SePa = sensor.param
	    SBT_Telem[sensor.label].unit = sensor.unit
	 end
      end
      -- next save the list of all non-SBTemp sensors for possible use with gauges
      if sensor.label ~= "" and (sensor.id & 0xFFFF) ~= 0xA446 then
	 --print("not SBT:", sensor.label)
	 if sensor.param == 0 then saveLabel = sensor.label else
	    table.insert(sensorLalist, saveLabel .. "-> " .. sensor.label)
	    table.insert(sensorLslist, sensor.label)	    
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    idNonTemp[sensor.label] = math.floor(sensor.id)
	    paramNonTemp[sensor.label] = math.floor(sensor.param)
	 end
      end
   end

   --SBTChannelsActive = ii -- remember how many sensors we found
   SBTChannelsActive = 8 -- remember how many sensors we found   
end

local function drawShape(col, row, shape, rotation, clr)
   local sinShape, cosShape

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for index, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   lcd.setColor(clr.r,clr.g,clr.b)
   ren:renderPolygon()
   setTextColor()
   --lcd.setColor(0, 0, 0)
end

local function drawTextCenter(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end

local function drawHistogram(label, min, mid, max, temp, unit, ox, oy)

   local color={}
   local hgt
   
   if temp < min then
      color.r = 0
      color.g = 0
      color.b = 255
   else
      if temp <= mid then
	 color.r=255*(temp-min)/(mid-min)
	 color.g=255
	 color.b=0
      elseif temp < max then
	 color.r=255
	 color.g=255*(1-(temp-mid)/(max-mid))
	 color.b=0
      else
	 color.r = 255
	 color.g = 0
	 color.b = 0
      end
   end
   
   drawTextCenter(FONT_MINI, label, ox+15, oy+0)

   --lcd.setColor(lcd.getFgColor())
   --lcd.setColor(0,0,255)
   setTextColor()
   drawTextCenter(FONT_BOLD, string.format("%d", temp), ox+15, oy+16)
   
   lcd.setColor(120,120,120)
   if min ~= 0 then
      drawTextCenter(FONT_MINI,
		     string.format("%d", min) .. " - " .. string.format("%d", max) .. unit,
		     ox + 25, oy+48)
   else
      drawTextCenter(FONT_MINI,
		     string.format("%d", max) .. unit,
		     ox + 25, oy+48)
   end

   --lcd.setColor(lcd.getFgColor())
   --lcd.setColor(0,0,0)
   
   temp = math.min(max, math.max(temp, min))
   
   hgt = 50* ( (temp - min) / (max - min) )


   lcd.setColor(color.r, color.g, color.b)
   lcd.drawRectangle(ox+35, oy-5, 10, 50)
   lcd.drawRectangle(ox+34, oy-6, 12, 52)   
   lcd.drawFilledRectangle(ox+35, oy+25-hgt+20, 10, hgt)

   setTextColor()
   --lcd.setColor(lcd.getFgColor())
   --lcd.setColor(0,0,0)
   
end

local function drawGauge(label, min, mid, max, tmp, unit, ox, oy)
   
   local color={}
   local theta
   local temp
   
   temp = tmp or min

   if temp < min then
      color.r = 0
      color.g = 0
      color.b = 255
   else
      if temp <= mid then
	 color.r=255*(temp-min)/(mid-min)
	 color.g=255
	 color.b=0
      elseif temp <= max then
	 color.r=255
	 color.g=255*(1-(temp-mid)/(max-mid))
	 color.b=0
      else
	 color.r = 255
	 color.g = 0
	 color.b = 0
      end
   end

   if not unit then
      color.r=0
      color.g=0
      color.b=255
   end
   
   drawTextCenter(FONT_MINI, label, ox+25, oy+38)

   setTextColor()
   --lcd.setColor(lcd.getFgColor())
   --lcd.setColor(0,0,255)
   
   if tmp then
      drawTextCenter(FONT_BOLD, string.format("%d", temp), ox+25, oy+16)
   end
   lcd.setColor(120,120,120)
   
   if unit and tmp then
      if min ~= 0 then
	 drawTextCenter(FONT_MINI,
			string.format("%d", min) .. " - " .. string.format("%d", max) .. unit,
			ox + 25, oy+52)
      else
	 drawTextCenter(FONT_MINI,
			string.format("%d", max) .. unit,
			ox + 25, oy+52)
      end
   end
   
   lcd.setColor(lcd.getFgColor())
   --lcd.setColor(0,0,0)
   
   temp = math.min(max, math.max(temp, min))
   theta = math.pi - math.rad(135 - 2 * 135 * (temp - min) / (max - min) )
   
   if arcFile ~= nil then
      lcd.drawImage(ox, oy, arcFile)
   end

   if tmp then -- don't draw needle if value passed in is nil
      drawShape(ox+25, oy+26, needle_poly_small, theta, color)
   end
end

local function jsnWrite()
   local fp
   local text

   --print("jsnWrite", jsnFileName)
   
   fp = io.open(jsnFileName, "w")
   text=json.encode(screenConfig)
   text = string.gsub(text, "%[", "\r\n[\r\n")
   text = string.gsub(text, "},", "},\r\n")
   text = string.gsub(text, "}%]", "}\r\n]\r\n")
   text = string.gsub(text, "%]\r\n,", "],\r\n")
   text = string.gsub(text, "\r\n,", ",\r\n")
   io.write(fp, text)
   io.close(fp)
end

local function screenInit(reset)
   local text
   local ext

   --print("screenInit: reset", reset)
   if reset == true then
      ext = ".json"
      dx1, dx2 = 0, 0
   else
      ext = ".jsn"
   end
   --print("ext:", ext)
   
   if screenIdx <= maxBuiltIn then
      --print("builtin")
      builtIn = true
      jsnFileName = appDir.."BuiltInScreens/"..
	 string.sub(screens[screenIdx], 2)
      --print("jsnFileName:", jsnFileName)
      text = io.readall(jsnFileName..ext)
      --print("readall:", text)
      jsnFileName = jsnFileName..".jsn"
      screenConfig = json.decode(text)
      if ext == ".json" then jsnWrite() end
      form.reinit(1)
   else
      --print("image", #screens, maxBuiltIn, screenIdx)
      if #screens > maxBuiltIn then
	 builtIn = false
	 jsnFileName = appDir.."ImageScreens/"..screens[screenIdx]
	 --print("jsnFileName:", jsnFileName)
	 text = io.readall(jsnFileName..ext)
	 --print("readall:", text)
	 jsnFileName = jsnFileName..".jsn"
	 screenConfig = json.decode(text)
	 backGndImage = lcd.loadImage(appDir.."ImageScreens/"..screenConfig.Image)
	 if ext == ".json" then jsnWrite() end
	 form.reinit(1)
      else
	 system.messageBox("No Image Screens Available", 3)
      end
   end
end


local function SBTDeviceNumberChanged(value)
   SBTDeviceNumber = value
   system.pSave("SBTDeviceNumber", value)
end
local function SBTChannelsActiveChanged(value)
   SBTChannelsActive = value
   system.pSave("SBTChannelsActive", value)
end

local function screenIdxChanged(value)
   screenIdx = value
   system.pSave("screenString", screens[screenIdx])
   screenInit()
   form.reinit(1)
end

local function jsnChanged(value, k, elem)
   screenConfig.Probes[k][elem] = value
   jsnWrite()
end

local function allGreenClicked(value)
   allGreenEn = not value
   form.setValue(allGreenEnIndex, allGreenEn)
   system.pSave("allGreenEn", tostring(allGreenEn))
end

local function hotWarnClicked(value)
   hotWarnEn = not value
   form.setValue(hotWarnEnIndex, hotWarnEn)
   system.pSave("hotWarnEn", tostring(hotWarnEn))
end

local function sensorChanged(val, i)
   telemSelected[i] = val -- this is only valid during a run and must be populated on startup
   SBT_Telem["T"..i].SeId = sensorIdlist[val]
   SBT_Telem["T"..i].SePa = sensorPalist[val]
   system.pSave("SBT_TelemSeId"..i, SBT_Telem["T"..i].SeId)
   system.pSave("SBT_TelemSePa"..i, SBT_Telem["T"..i].SePa)   
end

local function gaugeChanged(val, scg, ig)
   scg[ig].Sensor = sensorLslist[val] 
   jsnWrite()
end

local function gaugeMinMaxChanged(val, scg, ig, mm)
   if mm == "Min" then
      scg[ig].Min = val
   else
      scg[ig].Max = val
   end
   jsnWrite()
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ESC then
      return true else return false end
end

local function keyPressed(key)
   local ans
   if savedForm == 1 then
      if key == KEY_1 then
	 ans = form.question("Reset config data to default?",
			     "Display: "..screens[screenIdx],
			     "",4000, false, 0)
	 if ans == 1 then screenInit(true) end
      end
   elseif savedForm > 1 and savedForm < 100 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(101)
      end      
   else -- savedForm >= 100 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
      end
   end
end

local function initForm(subForm)
   savedForm = subForm
   if subForm == 1 then
      form.setTitle(appName)
      form.setButton(1, "RstAll", ENABLED)

      --[[
      form.addRow(2)
      form.addLabel({label="SB-Temp Device Number", width=220})
      form.addIntbox(SBTDeviceNumber,0,7,1,0,1,SBTDeviceNumberChanged)

      form.addRow(2)
      form.addLabel({label="SB-Temp Channels Active", width=220})
      form.addIntbox(SBTChannelsActive,1,8,8,0,1,SBTChannelsActiveChanged)
      --]]

      form.addLink((function() form.reinit(100) end), {label="Temp Probe Setup >>"})

      form.addLink((function() form.reinit(101) end), {label="Temp Probe Edit >>"})      

      if screenConfig.Gauges then
	 form.addLink((function() form.reinit(102) end), {label="Gauge Setup >>"})
      end
      

      form.addRow(2)
      form.addLabel({label="Select Display Screen", width=200})
      form.addSelectbox(screens, screenIdx, true, screenIdxChanged)

      form.addRow(2)
      form.addLabel({label='Enable "All Green" Announcement', width=270})
      allGreenEnIndex = form.addCheckbox(allGreenEn, allGreenClicked)

      form.addRow(2)
      form.addLabel({label="Enable Overheat Announcements", width=270})
      hotWarnEnIndex = form.addCheckbox(hotWarnEn, hotWarnClicked)

      form.addRow(1)
      form.addLabel({label=appShort,font=FONT_MINI, alignRight=true})      

   elseif subForm == 100 then
      form.setTitle("Editing Probe Sensors")
      for i=1,8,1 do
	 form.addRow(2)
	 form.addLabel({label=string.format("Probe %d", i), width=100})
	 form.addSelectbox(sensorLalist, telemSelected[i] or 0, true,
			   (function(x) return sensorChanged(x, i) end), {width=220})
      end
      form.addLink((function() form.reinit(1) end), {label="<< Back"})
   elseif subForm == 101 then
      form.setTitle("Editing Probes")
      for j=1, math.min(SBTChannelsActive, #screenConfig.Probes),1 do
	 form.addRow(2)
	 form.addLink((function() form.reinit(j+1) end),
	    {label="Probe "..j.." ("..screenConfig.Probes[j].Name ..") >>"})
      end
   elseif subForm == 102 then
      if screenConfig.Gauges then
	 for ig = 1, #screenConfig.Gauges do
	    if screenConfig.Gauges[ig].Name then
	       form.addRow(2)
	       form.addLabel({label="Sensor for ".. screenConfig.Gauges[ig].Name, width=120})
	       local idx=0
	       for k=1, #sensorLslist, 1 do
		  if screenConfig.Gauges[ig].Sensor == sensorLslist[k] then idx = k break end
	       end
	       
	       form.addSelectbox(sensorLalist, idx, true,
				 (function(x) return gaugeChanged(x, screenConfig.Gauges, ig) end),
				 {width=200} )
	       form.addRow(2)
	       form.addLabel({label="Gauge min for ".. screenConfig.Gauges[ig].Name, width=160})
	       form.addIntbox(screenConfig.Gauges[ig].Min, -10000,10000,0,0,1,
			      (function(x) return
				    gaugeMinMaxChanged(x, screenConfig.Gauges, ig, "Min") end),
			      {width=160})
	       form.addRow(2)
	       form.addLabel({label="Gauge max for ".. screenConfig.Gauges[ig].Name, width=160})
	       form.addIntbox(screenConfig.Gauges[ig].Max, -10000,10000,0,0,1,
			      (function(x) return
				    gaugeMinMaxChanged(x, screenConfig.Gauges, ig, "Max") end),
			      {width=160})			      
	    end
	 end
      end
   else
      
      local k=subForm-1

      form.setTitle("Editing Probe #"..k)
      form.addLink((function() form.reinit(101) end), {label="<< Back"})

      form.addRow(2)
      form.addLabel({label="Probe name", width=220})
      form.addTextbox(screenConfig.Probes[k].Name, 6, 
		      (function(x) return jsnChanged(x, k, "Name") end))
      form.addRow(2)
      form.addLabel({label="Temperature limit Green", width=220})
      form.addIntbox(screenConfig.Probes[k].Green,0,1000,1,0,1,
		     (function(x) return jsnChanged(x, k, "Green") end))      

      form.addRow(2)
      form.addLabel({label="Temperature limit Yellow", width=220})
      form.addIntbox(screenConfig.Probes[k].Yellow,0,1000,1,0,1,
		     (function(x) return jsnChanged(x, k, "Yellow") end))
		     
      form.addRow(2)
      form.addLabel({label="Temperature limit Red", width=220})
      form.addIntbox(screenConfig.Probes[k].Red,0,1000,1,0,1,
		     (function(x) return jsnChanged(x, k, "Red") end))

      form.addRow(1)
      form.addLabel({label=appShort.."SF",font=FONT_MINI, alignRight=true})
   end
end

local function loop()
   local sensor
   local kk
   local green
   local greenMsg = "All temperatures in the green"
   local redMsg   = "Over temperature sensor number"
   local fn
   local degF = string.sub("°F", 2, 3) -- convert unicode to utf-8

   for k,v in pairs(SBT_Telem) do
      if v.SeId and v.SeId ~= 0 and v.SePa and v.SePa ~= 0 then
	 sensor = system.getSensorByID(v.SeId, v.SePa)
	 v.value = nil
	 if sensor and sensor.valid then
	    if sensor.unit == degF then
	       v.value = 32 + (9.0/5.0) * sensor.value
	    else -- assume degC if not deg F
	       --print(k, v.SePa, v.SeId, sensor.label, sensor.value)
	       v.value = sensor.value
	    end
	 end
      end
   end

   green = 0
   local count = 0
   for k = 1, #screenConfig.Probes do
      kk = "T"..k
      if SBT_Telem[kk].value then 
	 if (SBT_Telem[kk].value >= screenConfig.Probes[k].Green) and
	 (SBT_Telem[kk].value < screenConfig.Probes[k].Yellow) then
	    green = green + 1
	 end
	 count = count + 1
	 if SBT_Telem[kk].value >= screenConfig.Probes[k].Red then
	    if hotWarnAnnounced[k] ~= true then
	       system.messageBox(redMsg .. " " .. k)
	       if hotWarnEn then
		  fn = string.gsub("/" .. appDir .. redMsg .. ".wav", " ", "_")
		  --print("SB-Temp playing ".. fn  .. " " .. k)
		  system.playFile(fn)
		  system.playNumber(k, 0)
	       end
	       hotWarnAnnounced[k] = true
	    end
	 else
	    hotWarnAnnounced[k] = false
	 end
      end
   end

   --if green == #screenConfig.Probes and allGreenEver == false then
   if green == count and allGreenEver == false then   
      system.messageBox(greenMsg)
      if allGreenEn then
	 fn = string.gsub("/" .. appDir .. greenMsg .. ".wav", " ", "_")
	 system.playFile(fn)
      end
      allGreenEver = true
   end
   
end


local function teleBuiltIn()
   local x0=12
   local y0=12
   local idx
   local k

   if screens[screenIdx] == "#Gauge" then
      for i=1,4,1 do
	 for j=1,2,1 do
	    idx = i+4*(j-1)	 
	    if idx > SBTChannelsActive then
	       break
	    end
	    k="T"..idx
	    drawGauge(screenConfig.Probes[idx].Name,
		      screenConfig.Probes[idx].Green,
		      screenConfig.Probes[idx].Yellow,
		      screenConfig.Probes[idx].Red,
		      SBT_Telem[k].value,
		      SBT_Telem[k].unit or "",
		      x0+(i-1)*80, y0+(j-1)*80)
	 end
      end
   elseif screens[screenIdx] == "#Histogram" then
      for i=1,4,1 do
	 for j=1,2,1 do
	    idx = i+4*(j-1)	 
	    if idx > SBTChannelsActive then
	       break
	    end
	    k="T"..idx
	    drawHistogram(screenConfig.Probes[idx].Name,
		      screenConfig.Probes[idx].Green,
		      screenConfig.Probes[idx].Yellow,
		      screenConfig.Probes[idx].Red,
		      SBT_Telem[k].value or 0,
		      SBT_Telem[k].unit or "",
		      x0+(i-1)*80, y0+(j-1)*80)
	 end
      end
   end
   
end

local function teleImage()
   local midW=160
   local midH=80
   local maxH=159
   local x,y
   local xp, yp
   local xt, yt
   local r,g,b
   local text
   local fontSize, textSize
   local sensor, val
   local kk
   
   lcd.drawImage( (310-backGndImage.width)/2+2+60, 10, backGndImage)

   local fonts = {FONT_MINI=FONT_MINI, FONT_NORMAL=FONT_NORMAL, FONT_BOLD=FONT_BOLD,
		  FONT_BIG=FONT_BIG, FONT_MAXI=FONT_MAXI}

   if not screenConfig.XTFont then textSize = FONT_NORMAL else
      textSize = fonts[screenConfig.XTFont]
   end
   if not screenConfig.XPFont then fontSize = FONT_NORMAL else
      fontSize = fonts[screenConfig.XPFont]
   end

   for k = 1, #screenConfig.Probes do
      x=screenConfig.Probes[k].XP
      y=screenConfig.Probes[k].YP

      -- coord system for image (140x140 px) is relative to top left corner of image
      -- fine adjustments here to make sure alignment is perfect
      
      x = x + midW - 11
      y = y + 10
	 
      kk = "T"..k
      --r,g,b = 0,0,0
      r,g,b = lcd.getFgColor()
      if SBT_Telem[kk].value then
	 if SBT_Telem[kk].value < screenConfig.Probes[k].Green then
	    r,g,b = 0,0,255
	    lcd.setColor(r,g,b)
	 elseif SBT_Telem[kk].value >= screenConfig.Probes[k].Green and
	 SBT_Telem[kk].value < screenConfig.Probes[k].Yellow then
	    r,g,b = 25,255,45
	    lcd.setColor(r,g,b)
	 elseif SBT_Telem[kk].value >= screenConfig.Probes[k].Yellow and
	 SBT_Telem[kk].value < screenConfig.Probes[k].Red then
	    r,g,b = 245,210,50
	    lcd.setColor(r,g,b)
	 elseif SBT_Telem[kk].value >= screenConfig.Probes[k].Red then
	    r,g,b = 255,0,0
	    lcd.setColor(r,g,b)
	 end
      end
      
      -- coord system for xp, yp is native screen coords,
      -- relative to top left corner of screen

      local fh = lcd.getTextHeight(fontSize)
      local fw = lcd.getTextWidth(fontSize, screenConfig.Probes[k].Name)
      xp = x - fw/2
      yp = y - fh/2
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(xp, yp, fw, fh)
      lcd.setColor(r,g,b)
      lcd.drawText(xp,yp, screenConfig.Probes[k].Name, fontSize)

      local ffx = FONT_MINI
      xt=screenConfig.Probes[k].XT
      yt=screenConfig.Probes[k].YT
      text = screenConfig.Probes[k].Name.."("..kk.."): "
      dx1 = math.max(dx1,lcd.getTextWidth(textSize, text))
      setTextColor()
      lcd.drawText(xt, yt, text, textSize)
      lcd.setColor(r,g,b)
      if SBT_Telem[kk].value then
	 text = string.format("%.1f", SBT_Telem[kk].value)
	 lcd.drawText(xt+dx1, yt, text, textSize)
      end
      setTextColor()
      --lcd.setColor(lcd.getFgColor())
      --lcd.setColor(0,0,0)
      if SBT_Telem[kk].unit then
	 dx2 = math.max(dx2, lcd.getTextWidth(textSize, text))
	 lcd.drawText(xt+dx1+dx2+3, yt, SBT_Telem[kk].unit, textSize)
      end

   end

   -- Loop over all Gauges in the jsn file
   -- First check if sensor is defined for this gauge in jsn file
   -- If so, check for value id and parameter from readSensors()
   -- Then get value and see if valid

   if screenConfig.Gauges then
      for ig = 1, #screenConfig.Gauges do
	 val = nil
	 --print(ig, screenConfig.Gauges[ig].Sensor)
	 if screenConfig.Gauges[ig].Sensor then
	    if idNonTemp[screenConfig.Gauges[ig].Sensor] and
	    paramNonTemp[screenConfig.Gauges[ig].Sensor] then
	       sensor = system.getSensorByID(idNonTemp[screenConfig.Gauges[ig].Sensor],
					     paramNonTemp[screenConfig.Gauges[ig].Sensor])
	       if sensor and sensor.valid then
		  val = sensor.value
	       end
	    end
	 end
	 
	 drawGauge(screenConfig.Gauges[ig].Name,
		   screenConfig.Gauges[ig].Min,
		   screenConfig.Gauges[ig].Max, -- no mid, just put max
		   screenConfig.Gauges[ig].Max,
		   val,  -- sensor value or nil
		   nil,  -- signal no units to be shown
		   screenConfig.Gauges[ig].XG,
		   screenConfig.Gauges[ig].YG)		
      end
   end

end

local function tele()
   if builtIn then teleBuiltIn() else teleImage() end
end

local function teleSmall()

   local r,g,b
   local kk
   local ibox = 0
   
   for k = 1, #screenConfig.Probes do
      kk = "T"..k
      if SBT_Telem[kk].value then
	 if SBT_Telem[kk].value < screenConfig.Probes[k].Green then
	    r,g,b = 0,0,255
	 elseif SBT_Telem[kk].value >= screenConfig.Probes[k].Green and
	 SBT_Telem[kk].value < screenConfig.Probes[k].Yellow then
	    r,g,b = 25,255,45
	 elseif SBT_Telem[kk].value >= screenConfig.Probes[k].Yellow and
	 SBT_Telem[kk].value < screenConfig.Probes[k].Red then
	    r,g,b = 245,210,50
	 elseif SBT_Telem[kk].value >= screenConfig.Probes[k].Red then
	    r,g,b = 255,0,0
	 end
	 lcd.setColor(r,g,b)
	 ibox = ibox + 1
	 lcd.drawFilledRectangle(6+18*(ibox-1), 6, 12, 12)
      else
	 --lcd.setColor(200,200,200)
	 --lcd.drawRectangle(6+18*(k-1), 6, 12, 12)
      end
   end
end

local function init()

   local imgName
   local dev
   local emFlag
   local prefix
   local sf
   
   dev, emFlag = system.getDeviceType()   

   
   SBTDeviceNumber = system.pLoad("SBTDeviceNumber", 0)
   SBTChannelsActive = system.pLoad("SBTChannelsActive", 8)

   readSensors()

   for i = 1, SBTChannelsActive, 1 do
      SBT_Telem["T"..i].SeId = system.pLoad("SBT_TelemSeId"..i, 0)
      SBT_Telem["T"..i].SePa = system.pLoad("SBT_TelemSePa"..i, 0)
      for k = 1, #sensorLalist, 1 do
	 if SBT_Telem["T"..i].SeId == sensorIdlist[k] 
	 and SBT_Telem["T"..i].SePa == sensorPalist[k] then
	    telemSelected[i] = k
	 end
      end
   end

   imgName = appDir.."c-000.png"
   arcFile = lcd.loadImage(imgName)

   system.registerForm(1, MENU_APPS, appName, initForm, keyPressed)
   system.registerTelemetry(1,appShort, 4, tele)
   system.registerTelemetry(2,appShort.." Summary", 1, teleSmall)   

   if emFlag == 1 then prefix = "" else prefix="/" end

   for name, filetype, size in dir(prefix..appDir.."BuiltInScreens") do
      sf = string.find(name, ".jsn")
      if filetype == "file" and sf then
	 table.insert(screens, "#"..string.sub(name,1, sf-1))
      end
   end

   table.sort(screens)
   maxBuiltIn = #screens

   local fileScreens = {}
   for name, filetype, size in dir(prefix..appDir.."ImageScreens") do
      --print("name:", name)
      sf = string.find(name, ".jsn")      
      if filetype == "file" and string.find(name, ".jsn") then
	 table.insert(fileScreens, string.sub(name,1, sf-1))
      end
   end

   table.sort(fileScreens)

   for k,v in ipairs(fileScreens) do table.insert(screens, v) end

   screenString = system.pLoad("screenString", "")
   screenIdx = 1
   
   for k,v in ipairs(screens) do
      if v == screenString then screenIdx = k break end
   end
   
   fileScreens = nil
   
   screenInit()

   allGreenEn = system.pLoad("allGreenEn", "true") -- default is to enable all green ann
   allGreenEn  = (allGreenEn == "true")            -- convert back to boolean
   allGreenEver = false
   
   hotWarnEn = system.pLoad("hotWarnEn", "true") -- default is to enable hot warnings
   hotWarnEn  = (hotWarnEn == "true")            -- convert back to boolean   


end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name=appName, author=appAuthor, version=appVersion}
