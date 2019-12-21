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
local transFile  = appDir .. "Trans.jsn"
local pcallOK, emulator

local IBPDeviceID=42056 -- 0xA448 so device 0 is 0x0100a448 = 16819272

----------------------------------------------------------------------------

local battImage
local IBP_Telem = {}
local IBP_Sort = {
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

local maxPacks=3
local battNames = {"Rx1 (2S)", "Rx2 (2S)", "ECU (3S)"}
local lCPU=0
local tCPU=0
local dev
local emFlag

local function readSensors()
   local sensors
   local sensorCode
   local sensorNumber
   local packNo
   
   sensors = system.getSensors()

   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 sensorNumber = ((sensor.id >> 16) & 0xF0) >> 4
	 sensorCode = sensor.id & 0xFFFF
	 packNo = sensorNumber + 1
	 if sensorCode == IBPDeviceID and sensor.param ~= 0 then
	    if IBP_Telem[packNo] == nil then
	       IBP_Telem[packNo] = {}
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
   if IBP_Telem and #IBP_Telem > 0 then
      for k,v in pairs(IBP_Telem[packNo]) do
	 table.insert(IBP_Sort, k)
      end
      table.sort(IBP_Sort)
   end
end

local function drawTextCenter(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end

local function drawTextRight(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt), oy, txt, font)
end

local function initForm(subForm)
   if subForm == 1 then
      form.setTitle(appName)
      form.addRow(1)
      form.addLabel({label=appShort,font=FONT_MINI, alignRight=true})      
   else
      local k=subForm-1
   end
end

saveLoopIdx = 1
saveLoopKey = nil
saveTime = system.getTimeCounter()
local function loop()

   local sensor
   local k, v
   local dt

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
   lCPU = system.getCPU()
end


local function drawBattery(ix,iy,packNo,name)

   local soc

   if battImage then lcd.drawImage(ix+10, iy+12, battImage) end
   lcd.drawRectangle(ix+10, iy+12, 50, 130, 7)   
   lcd.drawRectangle(ix+26, iy+3, 20, 10, 2)
   
   for k,v in pairs(IBP_Telem[packNo]) do
      if k and IBP_Sort[k][1] ~= "" then
	 if ix < 50 then
	    lcd.setColor(0,0,150)
	    lcd.drawText(ix-20, iy+18+25*IBP_Sort[k][6],
			 IBP_Sort[k][1]..IBP_Sort[k][2], IBP_Sort[k][5])
	 end
	 lcd.setColor(50,50, 255)
	 drawTextRight(IBP_Sort[k][5],string.format(IBP_Sort[k][4],
						v.value/IBP_Sort[k][3]),
			ix+90, iy+18+25*IBP_Sort[k][6])
      end
   end

   lcd.setColor(0,0,0)
   drawTextCenter(FONT_NORMAL, name, ix+10+50/2+1, iy+142)
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

local function teleImage()
   local i = 0
   for k,_ in ipairs(IBP_Telem)  do
      if i + 1 <= maxPacks then
	 drawBattery(i*100+20,0, k, battNames[k])
      end
      i = i + 1
   end
   if emFlag == 1 then
      tCPU = system.getCPU()
      lcd.drawText(290,135, string.format("L: %02d", lCPU), FONT_MINI)
      lcd.drawText(290,145, string.format("T: %02d", tCPU), FONT_MINI)
   end
   
end

local function init()

   dev, emFlag = system.getDeviceType()   

   battImage = lcd.loadImage(appDir.."digitechV.png")

   readSensors()
   
   system.registerForm(1, MENU_APPS, appName, initForm, keyPressed)
   system.registerTelemetry(1,appName, 4, teleImage)

end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name=appName, author=appAuthor, version=appVersion}
