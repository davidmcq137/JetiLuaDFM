--[[

----------------------------------------------------------------------------

   IBP Display -- Display program for Carsten Groen's Intelligent Battery Pack

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

local appShort   = "IBP"
local appName    = "Intelligent Battery Pack"
local appAuthor  = "DFM"
local appVersion = "0.13"
local appDir = "Apps/digitechIBP/"
local transFile  = appDir .. "Trans.jsn"

local IBPDeviceID=42056 -- 0xA448 so device 0 is 0x0100a448 = 16819272

----------------------------------------------------------------------------

local IBP = {}
IBP.Packs = {}
IBP.Screens = {}

IBP.Screens.Sys = {}
IBP.Screens.Sys.SOC            =
   {sname="SOC",    unit="%",   scale=    1,  fmt="%d",    font=FONT_MINI, iy=0}
IBP.Screens.Sys.Pack           =
   {sname="Pack",   unit="V",   scale= 1000,  fmt="%2.1f", font=FONT_MINI, iy=1}
IBP.Screens.Sys.Current        =
   {sname="Curr",   unit="mA",  scale=-1000,  fmt="%2.1f", font=FONT_MINI, iy=2}
IBP.Screens.Sys.Supply         =
   {sname="Supp",   unit="V",   scale=    1,  fmt="%2.1f", font=FONT_MINI, iy=3}
IBP.Screens.Sys["Cell 1"]     =
   {sname="Cell 1", unit="V",   scale= 1000,  fmt="%2.1f", font=FONT_MINI, iy=4}
IBP.Screens.Sys["Cell 2"]     =
   {sname="Cell 2", unit="V",   scale= 1000,  fmt="%2.1f", font=FONT_MINI, iy=5}
IBP.Screens.Sys["Cell 3"]     =
   {sname="Cell 3", unit="V",   scale= 1000,  fmt="%2.1f", font=FONT_MINI, iy=6}
IBP.Screens.Sys["Cap. left"]  =
   {sname="Cap Rem",unit="mAh", scale=    1,  fmt="%d",    font=FONT_MINI, iy=7}
IBP.Screens.Sys["Cap. total"] =
   {sname="Cap Tot",unit="mAh", scale=    1,  fmt="%d",    font=FONT_MINI, iy=8}
IBP.Screens.Sys.Temperature    =
   {sname="Temp",   unit="°C",  scale=    1,  fmt="%d",    font=FONT_MINI, iy=9}

IBP.Screens.FS = {}
IBP.Screens.FS.SOC           = {sname="%",  scale= 1,    fmt="%d",    font=FONT_NORMAL, iy=0}
IBP.Screens.FS.Pack          = {sname="V",  scale= 1000, fmt="%2.1f", font=FONT_NORMAL, iy=1}
IBP.Screens.FS.Current       = {sname="I",  scale=-1000, fmt="%2.2f", font=FONT_NORMAL, iy=2}
IBP.Screens.FS["Cap. left"]  = {sname="Cr", scale= 1,    fmt="%d",    font=FONT_MINI,   iy=3}
IBP.Screens.FS["Cap. total"] = {sname="Ct", scale= 1,    fmt="%d",    font=FONT_MINI,   iy=4}
IBP.Screens.FS.Temperature   = {sname="T",  scale= 1,    fmt="%d",    font=FONT_MINI,   iy=5}

IBP.Screens.Dbl = {}
IBP.Screens.Dbl.SOC           = {sname="%",  scale= 1,    fmt="%d",    font=FONT_MINI, iy=0}
IBP.Screens.Dbl.Pack          = {sname="V",  scale= 1000, fmt="%2.1f", font=FONT_MINI, iy=1}
IBP.Screens.Dbl.Current       = {sname="I",  scale=-1000, fmt="%2.2f", font=FONT_MINI, iy=2}

IBP.Menu = {}

local maxPacks=6
local battImage
local packNames = {}
local lastCapLeft = {}
local lCPU=0
local tCPU=0
local dev
local emFlag
local lastRedLight = 0
local redLightOn

-- Read and set translations

local lang
local locale

local function setLanguage()

   local obj
   local fp
   local langFile

   locale = system.getLocale()
   fp = io.readall(transFile)
   if not fp then -- translation does not exist yet .. literal string
      error(appShort..": Missing "..transFile)
   else
      obj = json.decode(fp)
   end
   if obj then
      langFile = obj[locale] or obj.en
   end
   fp = io.readall(appDir..langFile)
   if not fp then
      error(appShort..": Missing "..appDir..langFile)      
   else
      lang = json.decode(fp)
   end
end

local function playFile(filename, parm)
   local slash, prefix
   if emFlag == 1 then slash="" else slash="/" end
   if locale == 'en' then prefix = slash..appDir else
      prefix = slash..appDir..locale.."-"
   end
   system.playFile(prefix..filename, parm)
end

local function readSensors()
   local sensors
   local sensorCode
   local sensorNumber
   local device
   local packNo
   local lastSensorNumber = -1
   local lastLabel
   
   sensors = system.getSensors()
   
   packNo = 0
   
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 sensorNumber = ((sensor.id >> 16) & 0xF0) >> 4
	 sensorCode = sensor.id & 0xFFFF
	 if sensorCode == IBPDeviceID and sensor.param ~= 0 then
	    if sensorNumber ~= lastSensorNumber and IBP.Packs[packNo + 1] == nil then
	       packNo = packNo + 1
	       IBP.Packs[packNo] = {}
	       device = sensorNumber + 1
	       IBP.Packs[packNo].Device = device
	       lastSensorNumber = sensorNumber
	       IBP.Packs[packNo].Label = {}
	       lastLabel = nil
	    end
	    if #IBP.Packs <= maxPacks then
	       if sensor.label ~= lastLabel then
		  IBP.Packs[packNo].Label[sensor.label] = {}
		  lastLabel = sensor.label
	       end
	       IBP.Packs[packNo].Label[sensor.label].SeId = sensor.id
	       IBP.Packs[packNo].Label[sensor.label].SePa = sensor.param
	       IBP.Packs[packNo].Label[sensor.label].unit = sensor.unit
	       IBP.Packs[packNo].Label[sensor.label].value = 0
	       if packNames[packNo] then
		  IBP.Packs[packNo].Name = packNames[packNo]
	       else
		  IBP.Packs[packNo].Name = lang.Dev..device..
		     "("..(IBP.Packs[packNo].Label["Cell 3"] and "2S)" or "3S)")
	       end
	       IBP.Packs[packNo].HiWater = {}
	       IBP.Packs[packNo].HiWater.Current = 0
	       IBP.Packs[packNo].HiWater.Red = false
	    end
	 end
      end
   end
end

local function drawTextCenter(font, txt, ox, oy)
   lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end

local function drawTextRight(font, txt, ox, oy)
   lcd.drawText(ox - lcd.getTextWidth(font, txt), oy, txt, font)
end

local function drawBattery4(ix,iy,packNo,name)
   
   local soc
   local cur
   local HiW
   
   if redLightOn then
      lcd.setColor(255,0,0)
      lcd.drawFilledRectangle(300,6,6,6)
      lcd.setColor(0,0,0)
   end
   
   if battImage then lcd.drawImage(ix+10, iy+12, battImage) end
   lcd.drawRectangle(ix+10, iy+12, 50, 130, 7)   
   lcd.drawRectangle(ix+26, iy+3, 20, 10, 2)
   
   for k,v in pairs(IBP.Screens.FS) do 
      if ix < 50 then
	 lcd.setColor(0,0,150)
	 lcd.drawText(ix-20, iy+18+21*v.iy,
		      v.sname, v.font)
      end
      lcd.setColor(50,50, 255)
      drawTextRight(v.font,
		    string.format(v.fmt, IBP.Packs[packNo].Label[k].value/v.scale),
		    ix+90, iy+18+21*v.iy)
   end
   
   lcd.setColor(0,0,0)
   drawTextCenter(FONT_NORMAL, name, ix+10+50/2+1, iy+141)
   lcd.setColor(0,255,0)

   soc = IBP.Packs[packNo].Label.SOC.value
   if soc <= 50 and soc > 25 then lcd.setColor(255,255,0) end
   if soc <= 25 and soc >  0 then lcd.setColor(255,0,0) end
   if soc > 15 or system.getTime() % 2 == 0 then
      lcd.drawFilledRectangle(ix+38+1, iy+130-soc*1.1, 13, soc*1.1)
   end
   lcd.setColor(160,160,160)
   lcd.drawRectangle(ix+38, iy+130-100*1.1, 14, 100*1.1)
   lcd.drawLine(     ix+38, iy+130- 25*1.1, ix+40+11, iy+130-25*1.1)   
   lcd.drawLine(     ix+38, iy+130- 50*1.1, ix+40+11, iy+130-50*1.1)
   lcd.drawLine(     ix+38, iy+130- 75*1.1, ix+40+11, iy+130-75*1.1)

   cur = -IBP.Packs[packNo].Label.Current.value
   HiW = IBP.Packs[packNo].HiWater
   if cur < 0 then cur = 0 end
   
   if cur <= IBP.Menu.maxCurrent then
      lcd.setColor(0,0,255)
   else
      lcd.setColor(255,0,0)
      cur = IBP.Menu.maxCurrent
   end
   if HiW.Current then
      if cur > HiW.Current then HiW.Current = cur end
   else
      HiW.Current = cur
   end
   if HiW.Current == IBP.Menu.maxCurrent then HiW.Red = true end
   lcd.drawFilledRectangle(ix+52, iy+130-math.floor(cur/(IBP.Menu.maxCurrent/100)*1.1-1)-2, 5,
			   math.min(math.floor(cur/(IBP.Menu.maxCurrent/100)*1.1+1), 130))
   if HiW.Red then lcd.setColor(255,0,0) end
   if HiW.Current > IBP.Menu.maxCurrent / 20 then
      lcd.drawFilledRectangle(ix+52,
			      iy+130-math.floor(HiW.Current/(IBP.Menu.maxCurrent/100)*1.1-1)-2, 5, 3)
   end

   lcd.setColor(0,0,0)
end

local function drawBattery2(ix,iy,packNo,name)
   
   local soc
   local cur
   local HiW

   lcd.drawRectangle(ix, iy+12, 19, 51, 3)   
   lcd.drawRectangle(ix+5, iy+10,  10, 3, 2)
   
   for k,v in pairs(IBP.Screens.Dbl) do
      if ix < 25 then
	 lcd.setColor(0,0,150)
	 lcd.drawText(ix-14, iy+18+15*v.iy,
		      v.sname, FONT_MINI)
      end
      lcd.setColor(50,50, 255)
      lcd.drawText(ix+20, iy+18+15*v.iy,
		   string.format(v.fmt, IBP.Packs[packNo].Label[k].value/v.scale), FONT_MINI)
   end
   lcd.setColor(0,0,0)
   drawTextCenter(FONT_MINI, name, ix+18/2+1, iy+63)
   lcd.setColor(0,255,0)
   soc = IBP.Packs[packNo].Label.SOC.value
   if soc <= 50 and soc > 25 then lcd.setColor(255,255,0) end
   if soc <= 25 and soc >  0 then lcd.setColor(255,0,0) end
   if soc > 15 or system.getTime() % 2 == 0 then
      lcd.drawFilledRectangle(ix+3, iy+60-0.9*soc/2, 8, 0.9*soc/2)
   end
   lcd.setColor(160,160,160)
   lcd.drawRectangle(ix+3, iy+60-100*0.9/2, 13,    0.9*100/2)
   lcd.drawLine(     ix+3, iy+60- 25*0.9/2, ix+15, iy+60-25*0.9/2)   
   lcd.drawLine(     ix+3, iy+60- 50*0.9/2, ix+15, iy+60-50*0.9/2)
   lcd.drawLine(     ix+3, iy+60- 75*0.9/2, ix+15, iy+60-75*0.9/2)

   cur = -IBP.Packs[packNo].Label.Current.value
   HiW = IBP.Packs[packNo].HiWater
   if cur < 0 then cur = 0 end
   if cur <= IBP.Menu.maxCurrent then
      lcd.setColor(0,0,255)
   else
      lcd.setColor(255,0,0)
      cur = IBP.Menu.maxCurrent
   end
   if HiW.Current then
      if cur > HiW.Current then HiW.Current = cur end
   else
      HiW.Current = cur
   end
   if HiW.Current == IBP.Menu.maxCurrent then HiW.Red[packNo] = true end

   lcd.drawFilledRectangle(ix+11, iy+60-0.9*cur/(IBP.Menu.maxCurrent/100)/2, 4, 0.9*cur/(IBP.Menu.maxCurrent/100)/2)

   if HiW.Red then lcd.setColor(255,0,0) end
   if HiW.Current > IBP.Menu.maxCurrent / 20 then
      lcd.drawFilledRectangle(ix+11, iy+60-0.9*HiW.Current/(IBP.Menu.maxCurrent/100)/2, 4,2)
   end
   
   lcd.setColor(0,0,0)
end

local function teleImage4(_,_,num)

   for k = 1 + 3*(num-1), math.min(3+3*(num-1), #IBP.Packs) do
      drawBattery4((k-1-3*(num-1))*100+20,0, k, IBP.Packs[k].Name)
   end
   if emFlag == 1 then
      tCPU = system.getCPU()
      lcd.drawText(290,135, string.format("L: %02d", lCPU), FONT_MINI)
      lcd.drawText(290,145, string.format("T: %02d", tCPU), FONT_MINI)
   end
end

local function teleImage2(_,_,num)
   for k = 1 + 3*(num-1), math.min(3+3*(num-1), #IBP.Packs) do
      drawBattery2((k-1-3*(num-1))*45+14,-7, k, IBP.Packs[k].Name)
   end
end

local function packNameChanged(param, idx)
   --print("Name changed - param, idx:", param, idx)
   IBP.Packs[idx].Name = param
   packNames[idx] = param
   system.pSave("packNames", packNames)
end

local function teleRegister(idx)

   system.unregisterTelemetry(1)
   system.unregisterTelemetry(2)   

   if idx == 1 then
      system.registerTelemetry(1,appName.." FS1", 4, (function(w,h) return teleImage4(w,h,1) end))
      system.registerTelemetry(2,appName.." FS2", 4, (function(w,h) return teleImage4(w,h,2) end))
   elseif idx == 2 then
      system.registerTelemetry(1,appName.." 1",   2, (function(w,h) return teleImage2(w,h,1) end))
      system.registerTelemetry(2,appName.." 2",   2, (function(w,h) return teleImage2(w,h,2) end))
   elseif idx == 3 then
      system.registerTelemetry(1,appName.." FS",  4, (function(w,h) return teleImage4(w,h,1) end))
      system.registerTelemetry(2,appName,         2, (function(w,h) return teleImage2(w,h,2) end))
   elseif idx == 4 then
      system.registerTelemetry(1,appName,         2, (function(w,h) return teleImage2(w,h,1) end))
      system.registerTelemetry(2,appName.." FS",  4, (function(w,h) return teleImage4(w,h,2) end))
   else
      system.registerTelemetry(1,appName.." FS",  4, (function(w,h) return teleImage4(w,h,1) end))
      system.registerTelemetry(2,appName,         2, (function(w,h) return teleImage2(w,h,1) end))
   end

end

local function teleSelectChanged(param)
   IBP.Menu.teleSelect = param
   system.pSave("teleSelect", param)
   teleRegister(param)
end

local function maxCurrentChanged(param)
   IBP.Menu.maxCurrent = param
   system.pSave("maxCurrent", param)
end

local function updateRateChanged(param)
   IBP.Menu.updateRate = param
   system.pSave("updateRate", param)
end

local function initForm(subForm)
   local cx
   
   if subForm == 1 then
      IBP.Menu.formShowing = subForm
      form.setTitle(appName)

      form.addRow(2)
      form.addLabel({label=lang.telemWindows, width=220})
      form.addSelectbox({
			lang.twoFull,
			lang.twoDbl,
			lang.fullDbl,
			lang.dblFull,
			lang.twoMix
			},
			IBP.Menu.teleSelect, true, teleSelectChanged)
      
      form.addRow(2)
      form.addLabel({label=lang.maxCurr, width=220})
      form.addIntbox(IBP.Menu.maxCurrent, 100, 10000, 4000, 0, 100, maxCurrentChanged)

      form.addRow(2)
      form.addLabel({label=lang.telemUpdate, width=220})
      form.addSelectbox({lang.updSlw, lang.updMed, lang.updFst},
	 IBP.Menu.updateRate, false, updateRateChanged)

      form.addRow(2)
      form.addLink((function() form.reinit(2) end),
	 {label=lang.sysStat13, width=220})

      form.addRow(2)
      form.addLink((function() form.reinit(3) end),
	 {label=lang.sysStat46, width=220})
      
      form.addRow(2)
      form.addLink((function() form.reinit(4) end),
	 {label=lang.packNames})

      form.addRow(1)
      form.addLabel({label=appName..lang.lVer..appVersion.." ("..appAuthor..")",
		     font=FONT_MINI, alignRight=true})      
   elseif subForm == 2 then
      IBP.Menu.formShowing = subForm
      form.setTitle(lang.sttl13)
      form.addLink((function() form.reinit(1) end), {label=lang.back})
   elseif subForm == 3 then
      IBP.Menu.formShowing = subForm
      form.setTitle(lang.sttl46)
      form.addLink((function() form.reinit(1) end), {label=lang.back})
   elseif subForm == 4 then
      IBP.Menu.formShowing = subForm
      form.setTitle(lang.packNames)
      cx = form.addLink((function() form.reinit(1) end), {label=lang.back})

      for j = 1, #IBP.Packs, 1 do
	 form.addRow(2)
	 form.addLabel({label=lang.lPack..j..lang.lDev..IBP.Packs[j].Device..lang.lName, width=220})
	 form.addTextbox(IBP.Packs[j].Name, 8, (function(p) return packNameChanged(p, j) end) )
      end
      form.setFocusedRow(cx)
   end
   
end

local saveLoopIdx = 1
local saveLoopKey = nil
local saveTime = system.getTimeCounter()
local lastpSave = saveTime
local firstTime = true

local function loop()

   local sensor
   local k, v
   local nLoop
   local dt
   local chg, cap
   local mult = 0.1 -- to make sure the change in capacity is above roundoff
   local nlt={1, 5, 10}
   local now
   
   -- decided to "uroll" the nested loops, this code was taking way too much CPU time
   -- so instead of refreshing every telem param from every IBP on every loop(), we just
   -- do one item per loop() call using next() instead of a pairs() loop. This gives an
   -- overall refresh time of about 0.6 secs on the emulator which is totally reasonable
   -- for batteries. should do to CRU too...
   -- next added back nLoop to be able to tune update rate vs. CPU.
   -- nLoop =  1 gives update rate around 920 ms
   -- nLoop =  5 gives update rate around 230 ms
   -- nLoop = 10 gives update rate around 140 ms
   -- above for 4 packs on Emulator
   
   if not IBP.Packs or #IBP.Packs < 1 then return end

   nLoop = nlt[IBP.Menu.updateRate]
   
   for _ = 1, nLoop, 1 do
      k,v = next(IBP.Packs[saveLoopIdx].Label, saveLoopKey)

      saveLoopKey = k
      if not saveLoopKey then
	 saveLoopIdx = saveLoopIdx + 1
	 if saveLoopIdx > #IBP.Packs then
	    saveLoopIdx = 1
	    dt = system.getTimeCounter() - saveTime
	    saveTime = system.getTimeCounter()
	    --print(dt)
	 end
	 return
      end
      if v.SeId and v.SeId ~= 0 then
	 sensor = system.getSensorByID(v.SeId, v.SePa)
      end
      if sensor and sensor.valid then
	 v.value = sensor.value
      end
   end
   now = system.getTimeCounter()

   if now - lastRedLight < 600 then
      redLightOn = true
   else
      redLightOn = false
   end
   
   if now - lastpSave > 10000 then
      if firstTime then
	 --print("firstTime")
	 for i = 1, #IBP.Packs do
	    if lastCapLeft[i] then
	       cap = math.floor(IBP.Packs[i].Label["Cap. left"].value)
	       chg = cap - lastCapLeft[i]
	       if chg > cap*mult then
		  print("IBP Speech: Battery pack " .. i .. " charged: " .. chg .. " mAh")
		  playFile("battery_pack.wav", AUDIO_QUEUE)
		  system.playNumber(i, 0)
		  playFile("charged.wav", AUDIO_QUEUE)
		  system.playNumber(chg, 0, "mAh")
	       end
	    end
	 end
	 firstTime = false
      end
      
      for i = 1, #IBP.Packs do
	 lastCapLeft[i] = math.floor(IBP.Packs[i].Label["Cap. left"].value)
	 lastpSave = now
	 lastRedLight = now
      end
      system.pSave("lastCapLeft", lastCapLeft)      
   end
   lCPU = system.getCPU()
end


local function keyPress(_)
end

local function systemStatus()
   local ii = 0
   local ix=20
   local iy=5
   local vv
   
   if IBP.Menu.formShowing == 2 or IBP.Menu.formShowing == 3 then
      for packNo = 1 + 3*(IBP.Menu.formShowing-2),
      math.min(3+3*(IBP.Menu.formShowing-2), #IBP.Packs) do
	 lcd.setColor(0,0,150)
	 lcd.drawText(ix+70 + 65*(packNo-1-(IBP.Menu.formShowing-2)*3),
		      iy+12, IBP.Packs[packNo].Name, FONT_MINI)
	 for k,v in pairs(IBP.Screens.Sys) do
	    vv = IBP.Packs[packNo].Label[k]
	    lcd.setColor(0,0,150)
	    if packNo == 1 or packNo == 4 then
	       lcd.drawText(ix-14 + 58*(packNo-1-(IBP.Menu.formShowing-2)*3), iy+25+11*v.iy,
			    v.sname.." ("..v.unit..")", v.font)
	    end
	    lcd.setColor(50,50, 255)
	    if vv and vv.value then -- cell 3 absent on 2S packs
	       lcd.drawText(ix+80 + 65*(packNo-1-(IBP.Menu.formShowing-2)*3), iy+25+11*v.iy,
			    string.format(v.fmt, (vv.value)) / v.scale, v.font)
	    end
	    ii = ii + 1
	 end
      end
   end
end


local function init()

   dev, emFlag = system.getDeviceType()   

   battImage   = lcd.loadImage(appDir.."digitechV.png")
   packNames   = system.pLoad("packNames", {})
   lastCapLeft = system.pLoad("lastCapLeft", {})
   IBP.Menu.teleSelect  = system.pLoad("teleSelect", 1)
   IBP.Menu.maxCurrent  = system.pLoad("maxCurrent", 4000)
   IBP.Menu.updateRate  = system.pLoad("updateRate", 2)
   
   --if lastCapLeft then print("IBP: Valid lastCapLeft[]") end
   --local jtext = json.encode(IBP)
   --local fp = io.open("Apps/IBP.jsn", "w")
   --io.write(fp, jtext)
   --io.close(fp)

   setLanguage()
   
   readSensors()
   
   system.registerForm(1, MENU_APPS, appName, initForm, keyPress, systemStatus)

   teleRegister(IBP.Menu.teleSelect)

end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name=appName, author=appAuthor, version=appVersion}
