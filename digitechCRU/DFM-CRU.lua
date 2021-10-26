--[[

----------------------------------------------------------------------------

   CRU Telemetry Window

   Displays brake and retract motor current and indicates gear state
   for Carsten Groen's CRU device

   Implements two telemetry windows (large and fullscreen), no menus
   or settable items

   Borrows some display code from Daniel's excellent CTU.lua program

   Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------
   Released under MIT-license by DFM 2019
----------------------------------------------------------------------------

--]]

local appShort   = "DFM-CRU"
local appName    = "CRU Telemetry"
local appAuthor  = "DFM"
local appVersion = "0.01"
local transFile  = "Apps/DFM-CRU/Trans.jsn"

local pcallOK, emulator

local CRU_DeviceID = 16819268

-- scale of motor and brake bargraphs .. 0 to maxXXXCurr (presumed to be in mA) - adj as preferred
-- leave minMotCurr alone

local maxMotCurr = 1000
local maxBrkCurr = 1000

----------------------------------------------------------------------------

local minMotCurr = 1
local emFlag
local lastgs = 0

local pngFileNames = {large={red="red_circle",green="green_circle",blue="blue_circle"},
		      small={red="small_red_circle", green="small_green_circle", blue="small_blue_circle"}
		     }
local pngFiles = {}
pngFiles.large={}
pngFiles.small={}

local CRU_Telem = {
   ["Batt"]=        {index=1,SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["M1"]  =        {index=2,SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["M2"]  =        {index=3,SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["M3"]  =        {index=4,SeId=0,SePa=0,value=0,max=0,avg=0,sum=0,nsample=0,moved=false},
   ["B1"]  =        {index=5,SeId=0,SePa=0,value=0,max=0},
   ["B2"]  =        {index=6,SeId=0,SePa=0,value=0,max=0},
   ["B3"]  =        {index=7,SeId=0,SePa=0,value=0,max=0},
   ["Doors"] =      {index=8,SeId=0,SePa=0,value=0,max=0,avg=0,nsample=0,moved=false},
   ["Gear State"] = {index=9,SeId=0,SePa=0,value=0}
}

local lightPosFull ={M1={x=114,y=121},M2={x=144,y=83},M3={x=174,y=121}}
local lightPosLarge={M1={x=69, y=31}, M2={x=54, y=51},M3={x=84, y=51}}

-- code 4 is full screen, code 2 is double window

local MBartbl4={M1={x=66, y=140,w=70,h=16,typ='M'},
		M2={x=158,y=50, w=70,h=16,typ='M'},
		M3={x=252,y=140,w=70,h=16,typ='M'}
	       }

local MBartbl2={M1={x=30, y=60,w=35,h=8,typ='M'},
		M2={x=76, y=25,w=35,h=8,typ='M'},
		M3={x=123,y=60,w=35,h=8,typ='M'}
	       }

local BBartbl4={B1={x=66, y=110,w=70,h=16,typ='B'},
		B2={x=158,y=20, w=70,h=16,typ='B'},
		B3={x=252,y=110,w=70,h=16,typ='B'}
	       }

local BBartbl2={B1={x=30, y=50,w=35,h=8,typ='B'},
		B2={x=76, y=15,w=35,h=8,typ='B'},
		B3={x=123,y=50,w=35,h=8,typ='B'}
	       }

local mtable={"M1","M2","M3"}
local btable={"B1","B2","B3"}

local MBartbl
local BBartbl

--------------------------------------------------------------------------------

local function setLanguage()
   local obj
   local lng=system.getLocale()
   --lng="fr"
   local file = io.readall(transFile)
   if file then
      obj = json.decode(file)
   end
   if obj then
      trans11 = obj[lng] or obj.default
   end
   if not trans11 then
      system.messageBox(appShort..": missing "..transFile)
   end
end

--------------------------------------------------------------------------------

-- function to show all global variables

--[[
local seen={}

local function dump(t,i)
   seen[t]=true
   local s={}
   local n=0
   for k in pairs(t) do
      n=n+1 s[n]=k
   end
   table.sort(s)
   for _,v in ipairs(s) do
      print(i,v)
      v=t[v]
      if type(v)=="table" and not seen[v] then
	 dump(v,i.."\t")
      end
   end
end
--]]

--------------------------------------------------------------------------------

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.id == CRU_DeviceID and sensor.param ~= 0 then
	    print(sensor.label, sensor.id, sensor.param)
	    CRU_Telem[sensor.label].SeId = sensor.id
	    CRU_Telem[sensor.label].SePa = sensor.param
	 end
      end
   end
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
      lcd.drawText(x1, (oyc-h//2) + 2, string.format("%d", math.floor(val)), FONT_MINI)
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

local function CRUTele(w)

   local sensor, gs, icol
   
   if w > 160 then -- fullscreen telemetry window
      MBartbl = MBartbl4
      BBartbl = BBartbl4
   else            -- large (2-box) telemetry window
      MBartbl = MBartbl2
      BBartbl = BBartbl2
   end
   
   -- get all the sensor data and plug it into the CRU_Telem tables
   
   for k,v in pairs(CRU_Telem) do
      if v.SeId and v.SeId ~= 0 then
	 sensor = system.getSensorByID(v.SeId, v.SePa)
      end
      if sensor and sensor.valid then
	 v.value = sensor.value
      elseif emFlag == 1 then
	 if k == "B1" or k == "B2" or k == "B3" then
	    v.value = 500 * (system.getInputs("P6") + 1)
	 else
	    v.value = 500 * (system.getInputs("P5") + 1)
	 end
      end
   end

   gs = math.floor(CRU_Telem["Gear State"].value)

   -- check and possibly store largest brake values
   
   for _,v in pairs(btable) do
      if CRU_Telem[v].value > CRU_Telem[v].max then
	 CRU_Telem[v].max = CRU_Telem[v].value
      end
   end
   
   -- draw misc telem values as text

   if w > 160 and trans11 then
      lcd.drawText(220, 10, string.format(trans11.Battery..": %2.2f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(220, 30, string.format(trans11.State..": %d", gs), FONT_MINI)
      lcd.drawText(220, 50, string.format(trans11.Doors..": %d",
					  math.floor(CRU_Telem.Doors.value)),FONT_MINI)
      if emFlag == 1 then lcd.drawText(220,70, string.format("CPU%%: %d", system.getCPU()), FONT_MINI) end
   elseif trans11 then
      lcd.drawText(2, 5,  string.format(trans11.BatteryL..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 15, string.format(trans11.StateL..": %d", gs), FONT_MINI)
      lcd.drawText(2, 25, string.format(trans11.DoorsL..": %d",
					math.floor(CRU_Telem.Doors.value)), FONT_MINI)
   else
      lcd.drawText(2, 5,  string.format("No "..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 15, string.format("Trans.jsn "..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 25, string.format("file "..": %2.1f", CRU_Telem.Batt.value), FONT_MINI)      
   end

   -- compute state of the three lights
   -- assume gs = 1 is moving down, gs = 2 is down, gs = 3 is moving up, gs = 4 is up
   -- up is blue, down is green, moving is red

   if gs == 0 then -- no signal / unknown draw open black circles to indicate no gs
      for _,v in pairs(w > 160 and lightPosFull or lightPosLarge) do
	 drawImage(v.x, v.y, nil, w)
      end
   end
      
   if emFlag == 1 then gs = 1 end -- for testing
   
   if (gs == 1 and lastgs ~= 1)  or (gs == 3 and lastgs ~= 3) then -- just started to move down/up
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

   -- preset correct light color for end of travel
   
   if gs == 1 or gs == 2 then
      icol = w > 160 and pngFiles.large.green or pngFiles.small.green
   elseif gs == 3 or gs == 4 then
      icol = w > 160 and pngFiles.large.blue or pngFiles.small.blue
   else
      icol = nil
   end
   
   -- take actions based on gear state
   
   if gs == 1 or gs == 3 then -- moving down/up - turn each Mn to green/blue as it locks, red otherwise
      for _,v in pairs(mtable) do
	 if CRU_Telem[v].value > minMotCurr then
	    CRU_Telem[v].moved = true
	    CRU_Telem[v].nsample = CRU_Telem[v].nsample + 1
	    CRU_Telem[v].sum = CRU_Telem[v].sum + CRU_Telem[v].value
	    if CRU_Telem[v].value > CRU_Telem[v].max then
	       CRU_Telem[v].max = CRU_Telem[v].value
	    end
	 end
	 if CRU_Telem[v].value <= minMotCurr and CRU_Telem[v].moved == true then -- only if moved & stopped
	    if emFlag == 1 then
	       if CRU_Telem[v].nsample > 0 then
		  CRU_Telem[v].avg = CRU_Telem[v].sum / CRU_Telem[v].nsample
	       else
		  CRU_Telem[v].avg = 0
	       end
	    end
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

   if gs == 2 or gs == 4 then -- all up and locked (4) or down and locked (2)
      for _,v in pairs(mtable) do
	 if CRU_Telem[v].nsample > 0 then
	    CRU_Telem[v].avg = CRU_Telem[v].sum / CRU_Telem[v].nsample
	 else
	    CRU_Telem[v].avg = 0
	 end
      end
      for _,v in pairs(w > 160 and lightPosFull or lightPosLarge) do
	 drawImage(v.x, v.y, icol, w)
      end
   end

   lastgs = gs
   
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
end

--------------------------------------------------------------------------------

local function loadImages()
   local missing = false
   local ll
   local fn
   
   for k,v in pairs(pngFileNames) do
      for kk,_ in pairs(v) do
	 fn = "Apps/DFM-CRU/"..v[kk]..".png"
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

   pcallOK, emulator = pcall(require, "sensorEmulator")
   print("1", pcallOK, emulator)
   if not pcallOK then print("pcall error: ", emulator) end
   if pcallOK and emulator then emulator.init("DFM-CRU") end
   
   system.registerTelemetry(1, appName.." FS", 4, CRUTele) -- fullscreen
   system.registerTelemetry(2, appName, 2, CRUTele)        -- large (2-box) tele window  

   readSensors()
   loadImages()
   setLanguage()
   
   dev, emFlag = system.getDeviceType()

   emFlag = 0 -- override to use sensor emulator
   
   --uncomment next line to check dump of global variables
   --if emFlag == 1 then dump(_G, "") end -- dump globals
   
end

--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author=appAuthor, version=appVersion,
	name=appName}
 
