--[[

----------------------------------------------------------------------------

   CRU Display -- makes a Telemetry Window for the CRU

   Displays brake and retract motor current and indicates gear state
   for Carsten Groen's CRU device

   Implements two telemetry windows (large and fullscreen), no menus
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

----------------------------------------------------------------------------

--]]

local appShort   = "CRU"
local appName    = "CRU Display"
local appAuthor  = "DFM"
local appVersion = "1.02"
local appDir = "Apps/digitechCRU/"
local transFile  = appDir .. "Trans.jsn"
local pcallOK, emulator

local CRU_DeviceID = 16819268

----------------------------------------------------------------------------

local minMotCurr = 1
local emFlag
local gs, ds
local lastgs = 0
local gsCount = 0
local gsCountTimeout = 25 -- # loops before delcaring unknown state. 50 is approx 1 sec
local unkMsg = false
local doorMsg = false
local gearMoving = false
local downAudio
local upAudio

local downAudioIndex
local upAudioIndex

local retractAudio
local extendAudio

local retractAudioIndex
local extendAudioIndex

local pngFileNames = {large={red  ="red_circle",
			     green="green_circle",
			     blue ="blue_circle"},
		      small={red  ="small_red_circle",
			     green="small_green_circle",
			     blue ="small_blue_circle"}
		     }
local pngFiles ={}
pngFiles.large ={}
pngFiles.small ={}

local gsKey    ={"moveDown","downLock","moveUp","upLock"}
local gsString ={}
local gsStringL={}

local doorKey    ={"DoorOK","DoorOverload"}
local doorString ={}
local doorStringL={}

local battUnits = "V"
local doorUnits = "mA"

local CRU_Telem = {
   ["Batt"]       ={index=1, SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["Gear L"]     ={index=2, SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["Gear F"]     ={index=3, SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["Gear R"]     ={index=4, SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["Brake L"]    ={index=5, SeId=0,SePa=0,value=0,max=0},
   ["Brake F"]    ={index=6, SeId=0,SePa=0,value=0,max=0},
   ["Brake R"]    ={index=7, SeId=0,SePa=0,value=0,max=0},
   ["Doors"]      ={index=8, SeId=0,SePa=0,value=0,max=0,avg=0,nsample=0,moved=false},
   ["Gear State"] ={index=9, SeId=0,SePa=0,value=0},
   ["Door State"] ={index=10,SeID=0,SePa=0,value=0}
}

local lightPosFull ={["Gear L"]={x=114,y=121},["Gear F"]={x=144,y=83},["Gear R"]={x=174,y=121}}
local lightPosLarge={["Gear L"]={x=69, y=31}, ["Gear F"]={x=54, y=51},["Gear R"]={x=84, y=51}}

-- code 4 is full screen, code 2 is double "big" window

local MBartbl4={
   ["Gear L"]={x=66, y=140,w=70,h=16,typ='M'},
   ["Gear F"]={x=158,y=50, w=70,h=16,typ='M'},
   ["Gear R"]={x=252,y=140,w=70,h=16,typ='M'}
}

local MBartbl2={
   ["Gear L"]={x=30, y=60,w=35,h=8,typ='M'},
   ["Gear F"]={x=76, y=25,w=35,h=8,typ='M'},
   ["Gear R"]={x=123,y=60,w=35,h=8,typ='M'}
}

local BBartbl4={
   ["Brake L"]={x=66, y=110,w=70,h=16,typ='B'},
   ["Brake F"]={x=158,y=20, w=70,h=16,typ='B'},
   ["Brake R"]={x=252,y=110,w=70,h=16,typ='B'}
}

local BBartbl2={
   ["Brake L"]={x=30, y=50,w=35,h=8,typ='B'},
   ["Brake F"]={x=76, y=15,w=35,h=8,typ='B'},
   ["Brake R"]={x=123,y=50,w=35,h=8,typ='B'}
}

local mtable={"Gear L","Gear F","Gear R"}
local btable={"Brake L","Brake F","Brake R"}

local MBartbl
local BBartbl

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------

local function playFile(filename, parm)
   local slash, prefix
   if emFlag == 1 then slash="" else slash="/" end
   if locale == 'en' then prefix = slash..appDir else
      prefix = slash..appDir..locale.."-"
   end

   --if emFlag == 1 then print("calling system.playFile with: "..prefix..filename) end
   
   system.playFile(prefix..filename, parm)
end

--------------------------------------------------------------------------------

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.id == CRU_DeviceID and sensor.param ~= 0 then
	    CRU_Telem[sensor.label].SeId = sensor.id
	    CRU_Telem[sensor.label].SePa = sensor.param
	    if sensor.label == "Batt" then battUnits = sensor.unit end
	    if sensor.label == "Doors" then doorUnits = sensor.unit end
	 end
      end
   end
end

--------------------------------------------------------------------------------

local function maxMotCurrChanged(value)
   maxMotCurr = value
   system.pSave("maxMotCurr", value)
end

local function maxBrkCurrChanged(value)
   maxBrkCurr = value
   system.pSave("maxBrkCurr", value)
end

local function downAudioClicked(value)
   downAudio = not value
   form.setValue(downAudioIndex, downAudio)
   system.pSave("downAudio", tostring(downAudio))
end

local function upAudioClicked(value)
   upAudio = not value
   form.setValue(upAudioIndex, upAudio)
   system.pSave("upAudio", tostring(upAudio))
end

local function extendAudioClicked(value)
   extendAudio = not value
   form.setValue(extendAudioIndex, extendAudio)
   system.pSave("extendAudio", tostring(extendAudio))
end

local function retractAudioClicked(value)
   retractAudio = not value
   form.setValue(retractAudioIndex, retractAudio)
   system.pSave("retractAudio", tostring(retractAudio))
end


--------------------------------------------------------------------------------

local function initForm()


   form.addRow(2)
   form.addLabel({label=lang.maxMotCurr, width=220})
   form.addIntbox(maxMotCurr, 0, 5000, 1000, 0, 100, maxMotCurrChanged)

   form.addRow(2)
   form.addLabel({label=lang.maxBrkCurr, width=220})
   form.addIntbox(maxBrkCurr, 0, 5000, 1000, 0, 100, maxBrkCurrChanged)

   form.addRow(2)
   form.addLabel({label=lang.downAudio, width=270})
   downAudioIndex = form.addCheckbox(downAudio, downAudioClicked)

   form.addRow(2)
   form.addLabel({label=lang.upAudio, width=270})
   upAudioIndex = form.addCheckbox(upAudio, upAudioClicked)
   
   form.addRow(2)
   form.addLabel({label=lang.retractAudio, width=270})
   retractAudioIndex = form.addCheckbox(retractAudio, retractAudioClicked)

   form.addRow(2)
   form.addLabel({label=lang.extendAudio, width=270})
   extendAudioIndex = form.addCheckbox(extendAudio, extendAudioClicked)
   
   form.addRow(1)
   form.addLabel({label=appName.." v"..appVersion, font=FONT_MINI, alignRight=true})

end

--------------------------------------------------------------------------------

local function drawHeavyRectangle(x,y,w,h,lw)
   --draw filled rectangles to form the overall rectangle: bot, right, top, left
   lcd.drawFilledRectangle(x,y,w,lw)
   lcd.drawFilledRectangle(x+w-lw,y,lw,h)
   lcd.drawFilledRectangle(x,y+h-lw,w,lw)
   lcd.drawFilledRectangle(x,y,lw,h)
end

--------------------------------------------------------------------------------

local function DrawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str, typ, maxval, avgval, winw)

   -- draws bar gauge for positive readings, from min to max
   
   local d
   local x1

   if typ == "M" then -- draw motor bargraphs in blue
      lcd.setColor(0,0,255)
   else 
      lcd.setColor(255,0,0) -- draw brake bargraphs red
   end
   
   -- first draw outline of entire bar graph

   drawHeavyRectangle(oxc-w//2, oyc-h//2, w, h, winw > 160 and 2 or 1)

   if winw > 160 then   -- only put numbers on full screen graph
      if oxc < 160 then -- place numbers on "outside" of bar graph
	 x1 = (oxc-w//2) - 30
      else
	 x1 = (oxc+w//w) + 40
      end
      lcd.drawText(x1, (oyc-h//2)+2, string.format("%d", math.floor(val)), FONT_MINI)
   end

   -- draw the filled part of the bar to represent the value (val)
   
   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h/2, d, h)

   -- draw a 2-pixel vertical line to note max value
   -- but only if maxval > 0
   
   if maxval > 0 then
      d = math.max(math.min((maxval/(max-min))*w, w), 0)
      lcd.drawFilledRectangle(oxc-w//2 + d - 1, oyc-h/2, 2, h)
   end

   -- then a 2-pixel vertical line to note avg value
   -- but only if avgval > 0

   if avgval > 0 then
      local ofst = winw > 160 and 1 or 0
      
      lcd.setColor(164,147,147) -- nice gray
      d = math.max(math.min((avgval/(max-min))*w, w), 0)
      lcd.drawFilledRectangle(oxc-w//2 + d - 1, (oyc-h/2)+ofst, 2, h-2*ofst)
   end
   
   lcd.setColor(0,0,0)

   -- finally draw title text if full screen
   
   if str and winw > 160 then
      lcd.drawText(oxc - lcd.getTextWidth(FONT_MINI, str)//2, oyc+7, str, FONT_MINI)
   end
   
end

--------------------------------------------------------------------------------

local function drawImage(x,y,img,w)
   local x0, y0, r0
   if w > 160 then
      x0,y0,r0=14,14,12
   else
      x0,y0,r0=7,7,6
   end
   if img then
      lcd.drawImage(x,y,img)
   else
      lcd.drawCircle(x+x0, y+y0, r0)
   end
end

--------------------------------------------------------------------------------

local lasticol = nil

local function CRUTele(w)

   local icol

   if w > 160 then -- fullscreen telemetry window
      MBartbl = MBartbl4
      BBartbl = BBartbl4
   else            -- big (2-box) telemetry window
      MBartbl = MBartbl2
      BBartbl = BBartbl2
   end

   -- draw misc telem values as text

   if w > 160 and lang then
      lcd.drawText(200, 10, string.format(lang.Battery..": %2.2f %s",
					  CRU_Telem.Batt.value, battUnits), FONT_MINI)
      if not gsString[gs] then
	 print("gsString[gs] is nil, gs:", gs)
      end
      
      lcd.drawText(200, 30, string.format(lang.State..": %s", gsString[gs] or "---"), FONT_MINI)
      lcd.drawText(200, 50, string.format(lang.Doors..": %d %s",
					  math.floor(CRU_Telem.Doors.value), doorUnits),FONT_MINI)
      lcd.drawText(200,70, string.format(lang.DoorState..": %s", doorString[ds]), FONT_MINI)
      
   elseif lang then
      lcd.drawText(2, 2,  string.format(lang.BatteryL..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 12, string.format(lang.StateL..": %s", gsStringL[gs]), FONT_MINI)
      lcd.drawText(2, 22, string.format(lang.DoorsL..": %d",
					math.floor(CRU_Telem.Doors.value)), FONT_MINI)
      lcd.drawText(2, 32, string.format(lang.DoorStateL..": %s", doorStringL[ds]), FONT_MINI)
   else
      lcd.drawText(2, 5,  string.format("No "..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 15, string.format("Trans.jsn "..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 25, string.format("file "..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)      
   end

   -- compute state of the three lights
   -- assume gs = 1 is moving down, gs = 2 is down, gs = 3 is moving up, gs = 4 is up
   -- up is blue, down is green, moving is red

   -- if gsCount exceeds threshold, then unknown state: draw open black circles
   -- only do this and print warning if this happens when gear are moving

   if (gsCount >= gsCountTimeout and gearMoving) or gs == 0 then 
      for _,v in pairs(w > 160 and lightPosFull or lightPosLarge) do
	 drawImage(v.x, v.y, nil, w)
      end
   end

   -- preset correct light color for end of travel
   
   if gs == 1 or gs == 2 then
      icol = w > 160 and pngFiles.large.green or pngFiles.small.green
   elseif gs == 3 or gs == 4 then
      icol = w > 160 and pngFiles.large.blue or pngFiles.small.blue
   else -- presumably gs == 0
      icol = nil
   end

   -- take actions based on gear state
   -- moving down/up - turn each Mn to green/blue as it locks, red otherwise

   if (gs == 1 or gs == 3)  then 
      for _,v in pairs(mtable) do
	 -- see if we moved and then stopped - actual motion
	 if CRU_Telem[v].value <= minMotCurr and CRU_Telem[v].moved == true then
	    for _,vv in pairs(w > 160 and lightPosFull or lightPosLarge) do
	       drawImage(vv.x, vv.y, icol, w)
	    end
	 else
	    for _,vv in pairs(w > 160 and lightPosFull or lightPosLarge) do
	       drawImage(vv.x, vv.y, w > 160 and pngFiles.large.red or pngFiles.small.red, w)
	    end
	 end
      end
   end
   
   -- all up and locked (4) or down and locked (2)

   if (gs == 2 or gs == 4) then 
      for _,v in pairs(w > 160 and lightPosFull or lightPosLarge) do
	 drawImage(v.x, v.y, icol, w)
      end
   end

   lasticol = icol
   
   -- draw bar graphs for each M and B with current(mA) max and avg if applicable
   
   for k,v in pairs(MBartbl) do
      DrawRectGaugeAbs(v.x, v.y, v.w, v.h, 0,maxMotCurr, CRU_Telem[k].value, k, v.typ,
		       CRU_Telem[k].max, CRU_Telem[k].avg, w)
   end

   for k,v in pairs(BBartbl) do
      DrawRectGaugeAbs(v.x, v.y, v.w, v.h, 0, maxBrkCurr, CRU_Telem[k].value, k, v.type,
		       CRU_Telem[k].max, 0, w)
   end   

   
end

--------------------------------------------------------------------------------

local function loop()

   local sensor
   
   -- get all the sensor data and plug it into the CRU_Telem tables
   for _,v in pairs(CRU_Telem) do
      if v.SeId and v.SeId ~= 0 then
	 sensor = system.getSensorByID(v.SeId, v.SePa)
      end
      if sensor and sensor.valid then
	 v.value = sensor.value
      end
   end
   gs = math.floor(CRU_Telem["Gear State"].value)
   ds = math.min(math.max(math.floor(CRU_Telem["Door State"].value) + 1, 1), 2)
   -- check and possibly store largest brake values
   for _,v in pairs(btable) do
      if CRU_Telem[v].value > CRU_Telem[v].max then
	 CRU_Telem[v].max = CRU_Telem[v].value
      end
   end
   -- check door state (ok or overload) -- error message and audio if overload
   if ds ~= 2 then doorMsg = false end
   if ds == 2 then
      if not doorMsg then
	 playFile("gear_door_overcurrent.wav", AUDIO_QUEUE)
	 if lang then system.messageBox(lang.DoorOvercurr, 3) end
	 doorMsg = true
      end
   end
   -- check for unknown state .. only do message and audio if it happens while moving
   -- and then only if it repeats (parameter gsCountTimeout)
   if gs ~= 0 then unkMsg = false end
   if gs == 0 then
      gsCount = gsCount + 1
   else
      gsCount = 0
   end
   if gsCount >= gsCountTimeout and gearMoving then 
      if not unkMsg then -- play once per gs == 0
	 playFile("gear_in_unknown_state.wav", AUDIO_QUEUE)
	 if lang then system.messageBox(lang.unknownState, 3) end
	 unkMsg = true
      end
   end
   -- gear just started to move down/up
   if (gs == 1 and lastgs ~= 1)  or (gs == 3 and lastgs ~= 3) then 
      gearMoving = true
      if gs == 1 then
	 if extendAudio then playFile("gear_extending.wav", AUDIO_QUEUE) end
      else
	 if retractAudio then playFile("gear_retracting.wav", AUDIO_QUEUE) end
      end
      for _,v in pairs(mtable) do -- reset max and avg, clear moved flag
	 CRU_Telem[v].max = 0
	 CRU_Telem[v].nsample=0
	 CRU_Telem[v].sum = 0
	 CRU_Telem[v].avg = 0
	 CRU_Telem[v].moved = false
      end
      if gs == 1 then
	 for _,v in pairs(btable) do -- reset max on brakes when gear starting down
	    CRU_Telem[v].max = 0
	 end
      end
   end
   -- gear is moving down/up 
   if gs == 1 or gs == 3 then 
      for _,v in pairs(mtable) do
	 if CRU_Telem[v].value > minMotCurr then
	    CRU_Telem[v].moved = true
	    CRU_Telem[v].nsample = CRU_Telem[v].nsample + 1
	    CRU_Telem[v].sum = CRU_Telem[v].sum + CRU_Telem[v].value
	    if CRU_Telem[v].value > CRU_Telem[v].max then
	       CRU_Telem[v].max = CRU_Telem[v].value
	    end
	 end
	 -- see if we moved and then stopped - actual motion
	 if CRU_Telem[v].value <= minMotCurr and CRU_Telem[v].moved == true then
	    if emFlag == 1 then
	       if CRU_Telem[v].nsample > 0 then
		  CRU_Telem[v].avg = CRU_Telem[v].sum / CRU_Telem[v].nsample
	       else
		  CRU_Telem[v].avg = 0
	       end
	    end
	 end
      end
   end
   -- gear are all up and locked (4) or all down and locked (2)
   if gs == 2 or gs == 4 then 
      gearMoving = false
      if gs == 2 and lastgs == 1 then
	 if downAudio then playFile("gear_down_and_locked.wav", AUDIO_QUEUE) end
      end
      if gs == 4 and lastgs == 3 then
	 if upAudio then playFile("gear_up_and_locked.wav", AUDIO_QUEUE) end
      end
      for _,v in pairs(mtable) do
	 if CRU_Telem[v].nsample > 0 then
	    CRU_Telem[v].avg = CRU_Telem[v].sum / CRU_Telem[v].nsample
	 else
	    CRU_Telem[v].avg = 0
	 end
      end
   end
   lastgs = gs
end
--------------------------------------------------------------------------------

local function loadImages()
   local missing = false
   local ll
   local fn
   
   for k,v in pairs(pngFileNames) do
      for kk,_ in pairs(v) do
	 fn = appDir..v[kk]..".png"
	 ll = lcd.loadImage(fn)
	 if not ll then missing = fn end
	 pngFiles[k][kk] = ll
      end
   end

   if missing then
      print("Missing: ", missing)
      system.messageBox(appShort..": Missing png file(s)")
   end
   
end

--------------------------------------------------------------------------------

local function init()

   local dev

   downAudio      = system.pLoad("downAudio", "true")
   upAudio        = system.pLoad("upAudio", "true")
   retractAudio   = system.pLoad("retractAudio", "false")
   extendAudio    = system.pLoad("extendAudio", "false")   
   maxMotCurr     = system.pLoad("maxMotCurr", 1000)
   maxBrkCurr     = system.pLoad("maxBrkCurr", 1000)   

   -- take checkbox items back from text to boolean
   downAudio    = (downAudio    == "true")
   upAudio      = (upAudio      == "true")
   extendAudio  = (extendAudio  == "true")
   retractAudio = (retractAudio == "true")
   
   system.registerForm(1, MENU_APPS, appName, initForm)
   system.registerTelemetry(1, appName.." (Full Screen)", 4, CRUTele)
   system.registerTelemetry(2, appName.." (2-Box)", 2, CRUTele)

   readSensors()
   loadImages()
   setLanguage()

   -- put the currect locale's translations into the strings
   for k,v in ipairs(gsKey) do
      if lang then
	 gsString[k] = lang[v]
	 gsStringL[k] = lang[v.."L"]	 
      end
   end

   for k,v in ipairs(doorKey) do
      if lang then
	 doorString[k] = lang[v]
	 doorStringL[k] = lang[v.."L"]	 
      end
   end

   dev, emFlag = system.getDeviceType()
   
end

--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author=appAuthor, version=appVersion,
	name=appName}
 
