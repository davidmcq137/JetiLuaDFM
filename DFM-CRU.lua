--[[

----------------------------------------------------------------------------

   CRU Telemetry Window

   Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------
   Released under MIT-license by DFM 2019
----------------------------------------------------------------------------

--]]

local emFlag

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
local currentLabel

local red_circle={}
local green_circle={}
local blue_circle={}

local small_red_circle={}
local small_green_circle={}
local small_blue_circle={}

-- scale of motor and brake bargraphs .. 0 to maxXXXCurr (presumed to be in ma) - adj as preferred
-- leave minMotCurr alone

local maxMotCurr = 1000
local maxBrkCurr = 1000

local minMotCurr = 1

local lastgs = 0

local mtable={"M1","M2","M3"}
local btable={"B1","B2","B3"}

local lightPosFull ={M1={x=114,y=121}, M2={x=144,y=83}, M3={x=174,y=121}}
local lightPosLarge={M1={x=69, y=31},  M2={x=54, y=51}, M3={x=84, y=51}}

local MBartbl
local BBartbl

local MBartbl4={M1={x=66, y=140,w=70,h=16,color='blue'},
		M2={x=158,y=50, w=70,h=16,color='blue'},
		M3={x=252,y=140,w=70,h=16,color='blue'}
	       }

local MBartbl2={M1={x=30, y=60,w=35,h=8,color='blue'},
		M2={x=76,y=25, w=35,h=8,color='blue'},
		M3={x=123,y=60,w=35,h=8,color='blue'}
	       }

local BBartbl4={B1={x=66, y=110,w=70,h=16,color='red'},
		B2={x=158,y=20, w=70,h=16,color='red'},
		B3={x=252,y=110,w=70,h=16,color='red'}
	       }

local BBartbl2={B1={x=30, y=50,w=35,h=8,color='red'},
		B2={x=76,y=15, w=35,h=8,color='red'},
		B3={x=123,y=50,w=35,h=8,color='red'}
	       }

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
		    
--------------------------------------------------------------------------------

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then -- it's a label
	    currentLabel = sensor.label
	    table.insert(sensorLalist, '--> '..sensor.label)
	    table.insert(sensorIdlist, 0)
	    table.insert(sensorPalist, 0)
	 end
	 table.insert(sensorLalist, sensor.label)
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
      end
      -- special case code for CRU Sensors defined in CRU_Telem{}
      -- search for the device name, label and parameter matching the desired device and
      -- put it into the table of sensors so that user does not have to select them
      for k,v in pairs(CRU_Telem) do
	 if currentLabel == "CRU" and sensor.label == k and sensor.param == v.index then
	    v.SeId = sensor.id
	    v.SePa = sensor.param
	 end
      end
   end
end


--------------------------------------------------------

local function DrawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str, color, maxval, avgval, winw)

   local d
   local ct = {red={r=255,g=0,b=0}, green={r=0,g=255,b=0}, blue={r=0,g=0,b=255}}

   if not ct[color] then
      lcd.setColor(0, 0, 0)
   else
      lcd.setColor(ct[color].r, ct[color].g,ct[color].b)
   end
   
   -- first draw outline of entire bar graph
   
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)

   if winw > 160 then -- only put numbers on full screen graph
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

   -- then a 2-pixel vertical line to note max value
   -- but only if maxval > 0
   
   if maxval > 0 then
      d = math.max(math.min((maxval/(max-min))*w, w), 0)
      lcd.drawFilledRectangle(oxc-w//2 + d - 1, oyc-h/2, 2, h)
   end

   if avgval > 0 then
      lcd.setColor(164,147,147) -- nice gray
      d = math.max(math.min((avgval/(max-min))*w, w), 0)
      lcd.drawFilledRectangle(oxc-w//2 + d - 1, oyc-h/2, 2, h)
   end
   
   lcd.setColor(0,0,0)

   -- finally draw title text if full screen
   
   if str and winw > 160 then
      lcd.drawText(oxc - lcd.getTextWidth(FONT_MINI, str)//2, oyc+7, str, FONT_MINI)
   end
   
end

--------------------------------------------------------

local function CRUTele(w)

   local sensor, gs, icol
   
   if w > 160 then -- fullscreen telemetry window
      MBartbl = MBartbl4
      BBartbl = BBartbl4
   else            -- large telemetry window
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
   
   -- draw misc telem values

   if w > 160 then
      lcd.drawText(220, 10, string.format("Batt: %2.2f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(220, 30, string.format("Gear State: %d", gs), FONT_MINI)
      lcd.drawText(220, 50, string.format("Doors: %d", math.floor(CRU_Telem.Doors.value)), FONT_MINI)
   else
      lcd.drawText(2, 5,  string.format("Bat: %2.1f", CRU_Telem.Batt.value), FONT_MINI)
      lcd.drawText(2, 15, string.format("State: %d", gs), FONT_MINI)
      lcd.drawText(2, 25, string.format("Doors: %d", math.floor(CRU_Telem.Doors.value)), FONT_MINI)
   end
   

   -- compute state of the three lights
   -- assume gs = 1 is moving down, gs = 2 is down, gs = 3 is moving up, gs = 4 is up
   -- up is blue, down is green, moving is red

   if gs == 0 then -- no signal / unknown
      if w > 160 then
	 lcd.drawCircle(160-2,80+17, 12)
	 lcd.drawCircle(160-30-2, 120+16, 12)
	 lcd.drawCircle(160+30-2, 120+16, 12)
      else
	 lcd.drawCircle(76,32+6, 6)
	 lcd.drawCircle(76-15, 52+6, 6)
	 lcd.drawCircle(76+15, 52+6, 6)
      end
      
      
   end

   if emFlag == 1 then gs = 1 end
   
   if (gs == 1 and lastgs ~= 1)  or (gs == 3 and lastgs ~= 3) then -- just started to move down/up
      for _,v in pairs(mtable) do -- reset max and avg, clear moved flag
	 CRU_Telem[v].max = 0
	 CRU_Telem[v].nsample=0
	 CRU_Telem[v].sum = 0
	 CRU_Telem[v].avg = 0
	 CRU_Telem[v].moved = false
      end
   end

   -- preset correct light color for end of travel
   
   if gs == 1 or gs == 2 then
      if w > 160 then
	 icol = green_circle
      else
	 s_icol = small_green_circle
      end
   elseif gs == 3 or gs == 4 then
      if w > 160 then
	 icol = blue_circle
      else
	 s_icol = small_blue_circle
      end
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
	    
	    if w > 160 then
	       for _,vv in pairs(lightPosFull) do
		  lcd.drawImage(vv.x, vv.y, icol)
	       end
	    else
	       for _,vv in pairs(lightPosLarge) do
		  lcd.drawImage(vv.x, vv.y, s_icol)
	       end
	    end
	 else
	    if w > 160 then
	       for _,vv in pairs(lightPosFull) do
		  lcd.drawImage(vv.x, vv.y, red_circle)
	       end
	    else
	       for _,vv in pairs(lightPosLarge) do
		  lcd.drawImage(vv.x, vv.y, small_red_circle)
	       end
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
      if w > 160 then
	 for _,v in pairs(lightPosFull) do
	    lcd.drawImage(v.x, v.y, icol)
	 end
      else
	 for _,v in pairs(lightPosLarge) do
	    lcd.drawImage(v.x, v.y, s_icol)
	 end
      end
   end

   lastgs = gs
   
   -- draw bar graphs for each M and B with current value max and avg if applicable
   
   for k,v in pairs(MBartbl) do
      DrawRectGaugeAbs(v.x, v.y, v.w, v.h, 0,maxMotCurr, CRU_Telem[k].value, k, v.color,
		       CRU_Telem[k].max, CRU_Telem[k].avg, w)
   end

   for k,v in pairs(BBartbl) do
      DrawRectGaugeAbs(v.x, v.y, v.w, v.h, 0, maxBrkCurr, CRU_Telem[k].value, k, v.color,
		       CRU_Telem[k].max, 0, w)
   end   

end

--------------------------------------------------------------------------------

local function loop()

end

--------------------------------------------------------------------------------

local function loadImages()
   
    red_circle   = lcd.loadImage("Apps/DFM-CRU/red_circle.png")
    green_circle = lcd.loadImage("Apps/DFM-CRU/green_circle.png")
    blue_circle  = lcd.loadImage("Apps/DFM-CRU/blue_circle.png")

    small_red_circle   = lcd.loadImage("Apps/DFM-CRU/small_red_circle.png")
    small_green_circle = lcd.loadImage("Apps/DFM-CRU/small_green_circle.png")
    small_blue_circle  = lcd.loadImage("Apps/DFM-CRU/small_blue_circle.png")
    
    if not red_circle or not green_circle or not blue_circle then
       print("Filled circle images(s) not loaded")
    end

    if not small_red_circle or not small_green_circle or not small_blue_circle then
       print("Small filled circle images(s) not loaded")
    end    
end

--------------------------------------------------------------------------------

local function init()

   local dev
   
   system.registerTelemetry(1, "CRU Telemetry FS", 4, CRUTele)
   system.registerTelemetry(2, "CRU Telemetry", 2, CRUTele)
   
   readSensors()
   loadImages()

   dev, emFlag = system.getDeviceType()
   print("Device Type: ", dev)
   
end

--------------------------------------------------------------------------------

CRUVersion = "0.01"

collectgarbage()

return {init=init, loop=loop, author="DFM", version=CRUVersion,
	name="CRU Telemetry"}
 
