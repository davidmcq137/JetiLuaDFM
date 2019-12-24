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
local appVersion = "0.10"
local appDir = "Apps/digitechIBP/"
--local transFile  = appDir .. "Trans.jsn"

local IBPDeviceID=42056 -- 0xA448 so device 0 is 0x0100a448 = 16819272

----------------------------------------------------------------------------

local battImage
local IBP_Telem = {}
local IBP_DispT = {
   SOC             = {"%",     "",     1, "%d",    FONT_NORMAL, 0},
   Pack            = {"V",     "",  1000, "%2.1f", FONT_NORMAL, 1},
   Supply          = {"",     "V",  1000, "%2.1f", FONT_MINI,   0},
   ["Cell 1"]      = {"",     "V",  1000, "%2.1f", FONT_MINI,   0},
   ["Cell 2"]      = {"",     "V",  1000, "%2.1f", FONT_MINI,   0},
   ["Cell 3"]      = {"",     "V",  1000, "%2.1f", FONT_MINI,   0},
   ["Cap. left"]   = {"Cr",    "",     1, "%d",    FONT_MINI,   2},
   ["Cap. total"]  = {"Ct",    "",     1, "%d",    FONT_MINI,   3},
   Temperature     = {"T",   "°C",     1, "%d",    FONT_MINI,   4}
}

local IBP_DispS = { 
   SOC             = {"SOC",        "%",   1,    "%d",    FONT_MINI,   0},
   Pack            = {"Pack",       "V",   1000, "%2.1f", FONT_MINI,   1},
   Supply          = {"Supply",     "V",   1000, "%2.1f", FONT_MINI,   2},
   ["Cell 1"]      = {"Cell 1",     "V",   1000, "%2.1f", FONT_MINI,   3},
   ["Cell 2"]      = {"Cell 2",     "V",   1000, "%2.1f", FONT_MINI,   4},
   ["Cell 3"]      = {"Cell 3",     "V",   1000, "%2.1f", FONT_MINI,   5},
   ["Cap. left"]   = {"Cap rem",    "mAh", 1,    "%d",    FONT_MINI,   6},
   ["Cap. total"]  = {"Cap total",  "mAh", 1,    "%d",    FONT_MINI,   7},
   Temperature     = {"Temp",       "°C",  1,    "%d",    FONT_MINI,   8}
}

local maxPacks=6
local battNames = {}
local battDev = {}
local lCPU=0
local tCPU=0
local dev
local emFlag
local formShowing
local teleSelectItems = {
   "Two Full Screen",
   "Two Double Size",
   "Pack 1-3 Full, Pack 4-6 Double",
   "Pack 1-3 Double, Pack 4-6 Full",
   "Pack 1-3 Full, Pack 1-3 Double"
}

local teleSelect

local function readSensors()
   local sensors
   local sensorCode
   local sensorNumber
   local packNo
   local lastSensorNumber = -1
   
   sensors = system.getSensors()
   
   packNo = 0
   
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 sensorNumber = ((sensor.id >> 16) & 0xF0) >> 4
	 sensorCode = sensor.id & 0xFFFF
	 if sensorCode == IBPDeviceID and sensor.param ~= 0 then
	    if sensorNumber ~= lastSensorNumber and IBP_Telem[packNo + 1] == nil then
	       packNo = packNo + 1
	       IBP_Telem[packNo] = {}
	       battDev[packNo] = sensorNumber + 1
	       lastSensorNumber = sensorNumber
	    end
	    if #IBP_Telem <= maxPacks then
	       IBP_Telem[packNo][sensor.label]={}
	       IBP_Telem[packNo][sensor.label].SeId = sensor.id
	       IBP_Telem[packNo][sensor.label].SePa = sensor.param
	       IBP_Telem[packNo][sensor.label].unit = sensor.unit
	       IBP_Telem[packNo][sensor.label].value = 0
	    end
	 end
      end
   end
   for packNo in ipairs(IBP_Telem) do
      if not battNames[packNo] then
	 battNames[packNo] =
	    "Dev"..battDev[packNo].."("..(IBP_Telem[packNo]["Cell 3"] and "2S)" or "3S)")
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
   
   if battImage then lcd.drawImage(ix+10, iy+12, battImage) end
   lcd.drawRectangle(ix+10, iy+12, 50, 130, 7)   
   lcd.drawRectangle(ix+26, iy+3, 20, 10, 2)
   
   for k,v in pairs(IBP_Telem[packNo]) do
      if k and IBP_DispT[k][1] ~= "" then
	 if ix < 50 then
	    lcd.setColor(0,0,150)
	    lcd.drawText(ix-20, iy+18+25*IBP_DispT[k][6],
			 IBP_DispT[k][1]..IBP_DispT[k][2], IBP_DispT[k][5])
	 end
	 lcd.setColor(50,50, 255)
	 drawTextRight(IBP_DispT[k][5],string.format(IBP_DispT[k][4],
						     v.value/IBP_DispT[k][3]),
		       ix+90, iy+18+25*IBP_DispT[k][6])
      end
   end
   
   lcd.setColor(0,0,0)
   drawTextCenter(FONT_NORMAL, name, ix+10+50/2+1, iy+141)
   lcd.setColor(0,255,0)
   soc = IBP_Telem[packNo].SOC.value
   if soc <= 50 and soc > 25 then lcd.setColor(255,255,0) end
   if soc <= 25 and soc >  0 then lcd.setColor(255,0,0) end
   if soc > 15 or system.getTime() % 2 == 0 then
      lcd.drawFilledRectangle(ix+42, iy+130-soc*1.1, 13, soc*1.1)
   end
   lcd.setColor(160,160,160)
   lcd.drawRectangle(ix+42, iy+130-100*1.1, 13, 100*1.1)
   lcd.drawLine(ix+42, iy+130-25*1.1, ix+42+12, iy+130-25*1.1)   
   lcd.drawLine(ix+42, iy+130-50*1.1, ix+42+12, iy+130-50*1.1)
   lcd.drawLine(ix+42, iy+130-75*1.1, ix+42+12, iy+130-75*1.1)
   lcd.setColor(0,0,0)
end

local function drawBattery2(ix,iy,packNo,name)
   
   local soc

   lcd.drawRectangle(ix, iy+12, 19, 51, 3)   
   lcd.drawRectangle(ix+5, iy+10,  10, 3, 2)
   
   for k,v in pairs(IBP_Telem[packNo]) do
      if k and IBP_DispT[k][1] ~= "" then
	 if ix < 25 and (IBP_DispT[k][1] == "%" or IBP_DispT[k][1] == "V" or IBP_DispT[k][1] == "Cr") then
	    lcd.setColor(0,0,150)
	    lcd.drawText(ix-14, iy+18+15*IBP_DispT[k][6],
			 IBP_DispT[k][1]..IBP_DispT[k][2], FONT_MINI)
	 end
	 if IBP_DispT[k][1] == "%" or IBP_DispT[k][1] == "V" or IBP_DispT[k][1] == "Cr" then	 
	    lcd.setColor(50,50, 255)
	    lcd.drawText(ix+20, iy+18+15*IBP_DispT[k][6],
			 string.format(IBP_DispT[k][4], v.value/IBP_DispT[k][3]), FONT_MINI)
	 end
      end
   end
   lcd.setColor(0,0,0)
   drawTextCenter(FONT_MINI, name, ix+18/2+1, iy+63)
   lcd.setColor(0,255,0)
   soc = IBP_Telem[packNo].SOC.value
   if soc <= 50 and soc > 25 then lcd.setColor(255,255,0) end
   if soc <= 25 and soc >  0 then lcd.setColor(255,0,0) end
   if soc > 15 or system.getTime() % 2 == 0 then
      lcd.drawFilledRectangle(ix+3, iy+60-0.9*soc/2, 13, 0.9*soc/2)
   end
   lcd.setColor(160,160,160)
   lcd.drawRectangle(ix+3, iy+60-0.9*100/2, 13, 0.9*100/2)
   lcd.drawLine(ix+3, iy+60-25*0.9/2, ix+15, iy+60-25*0.9/2)   
   lcd.drawLine(ix+3, iy+60-50*0.9/2, ix+15, iy+60-50*0.9/2)
   lcd.drawLine(ix+3, iy+60-75*0.9/2, ix+15, iy+60-75*0.9/2)
   lcd.setColor(0,0,0)
end

local function teleImage4(w,h,num)

   for k = 1 + 3*(num-1), math.min(3+3*(num-1), #IBP_Telem) do
      drawBattery4((k-1-3*(num-1))*100+20,0, k, battNames[k])
   end
   if emFlag == 1 then
      tCPU = system.getCPU()
      lcd.drawText(290,135, string.format("L: %02d", lCPU), FONT_MINI)
      lcd.drawText(290,145, string.format("T: %02d", tCPU), FONT_MINI)
   end
end

local function teleImage2(w,h,num)
   for k = 1 + 3*(num-1), math.min(3+3*(num-1), #IBP_Telem) do
      drawBattery2((k-1-3*(num-1))*45+14,-7, k, battNames[k])
   end
end

local function packNameChanged(param, idx)
   --print("param, idx:", param, idx)
   battNames[idx] = param
   system.pSave("battNames", battNames)
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
   teleSelect = param
   system.pSave("teleSelect", param)
   teleRegister(param)
end


local function initForm(subForm)
   if subForm == 1 then
      formShowing = subForm
      form.setTitle(appName)

      form.addRow(2)
      form.addLabel({label="Telemetry Windows to Draw", width=220})
      form.addSelectbox(teleSelectItems, teleSelect, true, teleSelectChanged)
      
      form.addRow(2)
      form.addLink((function() form.reinit(2) end),
	 {label="System Status >>"})
      
      form.addRow(2)
      form.addLink((function() form.reinit(3) end),
	 {label="Pack Names >>"})

      form.addRow(1)
      form.addLabel({label=appShort,font=FONT_MINI, alignRight=true})      
   elseif subForm == 2 then
      formShowing = subForm
      form.setTitle("IBP System Status")
      form.addLink((function() form.reinit(1) end), {label="<< Back"})
   elseif subForm == 3 then
      formShowing = subForm
      form.setTitle("Pack Names")
      form.addLink((function() form.reinit(1) end), {label="<< Back"})

      for j = 1, #IBP_Telem, 1 do
	 form.addRow(2)
	 form.addLabel({label="Pack "..j.." (Device "..battDev[j]..") name", width=220})
	 form.addTextbox(battNames[j], 8, (function(p) return packNameChanged(p, j) end) )
      end
      
   end
   
end

saveLoopIdx = 1
saveLoopKey = nil
--local saveTime = system.getTimeCounter()
local function loop()

   local sensor
   local k, v
   --local dt

   -- decided to "uroll" the nested loops, this code was taking way too much CPU time
   -- so instead of refreshing every telem param from every IBP on every loop(), we just
   -- do one item per loop() call using next() instead of a pairs() loop. This gives an
   -- overall refresh time of about 0.6 secs on the emulator which is totally reasonable
   -- for batteries. should do to CRU too...
   
   if not IBP_Telem or #IBP_Telem < 1 then return end
   k,v = next(IBP_Telem[saveLoopIdx], saveLoopKey)
   saveLoopKey = k
   if not saveLoopKey then
      saveLoopIdx = saveLoopIdx + 1
      if saveLoopIdx > #IBP_Telem then
	 saveLoopIdx = 1
	 --dt = system.getTimeCounter() - saveTime
	 --saveTime = system.getTimeCounter()
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
   lCPU = system.getCPU()
end


local function keyPress(key)
end

local function systemStatus(w,h)
   local ii = 0
   local ix=20
   local iy=5
   local vv
   
   if formShowing == 2 then

      for packNo = 1, math.min(#IBP_Telem, 4), 1 do
	 lcd.setColor(0,0,150)
	 lcd.drawText(ix+70 + 58*(packNo-1), iy+12, battNames[packNo], FONT_MINI)
	 for k,_ in pairs(IBP_DispS) do
	    vv = IBP_Telem[packNo][k]
	    lcd.setColor(0,0,150)
	    if packNo == 1 then
	       lcd.drawText(ix-14 + 60*(packNo-1), iy+25+12*IBP_DispS[k][6],
			    IBP_DispS[k][1].." ("..IBP_DispS[k][2]..")", IBP_DispS[k][5])
	    end
	    lcd.setColor(50,50, 255)
	    if vv and vv.value then -- cell 3 absent on 2S packs
	       lcd.drawText(ix+80 + 58*(packNo-1), iy+25+12*IBP_DispS[k][6],
			string.format(IBP_DispS[k][4], (vv.value) / IBP_DispS[k][3]), IBP_DispS[k][5])
	    end
	    ii = ii + 1
	 end
      end
   end
end


local function init()

   dev, emFlag = system.getDeviceType()   

   battImage = lcd.loadImage(appDir.."digitechV.png")
   battNames = system.pLoad("battNames", {})
   teleSelect = system.pLoad("teleSelect", 1)
   
   readSensors()
   
   system.registerForm(1, MENU_APPS, appName, initForm, keyPress, systemStatus)

   teleRegister(teleSelect)

end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name=appName, author=appAuthor, version=appVersion}
