--[[

   ----------------------------------------------------------------------------
   DFM-GPS.lua released under MIT license by DFM 2022

   Simple GPS display app .. no maps!

   drawTape() inspired by Jeti's Artificial Horizon app
   ----------------------------------------------------------------------------
   
--]]

local GPSVersion = "0.1"

local subForm = 0
--local emFlag

local telem

local sens = {
   {var="lat", label="Latitude"},
   {var="lng", label="Longitude"},
   {var="alt", label="Altitude"},
   {var="spd", label="Speed"}
}

--[[
local ctl = {
   {var="thr", label="Throttle"},
}
--]]
--[[
local Prop = {
   {-1,-6},
   {-2,-2},
   {-11,-2},
   {-11,1},	
   {-2,2},	
   {-1,8},
   {-5,8}, 
   {-5,11},
   {5,11},
   {5,8},
   {1,8},
   {2,2},
   {11,1},
   {11,-2},
   {2,-2},
   {1,-6}
}
--]]

local Glider =  {
   {0,-7},
   {-1,-2},
   {-14,0},
   {-14,2},	
   {-1,2},	
   {-1,8},
   {-4,8},
   {-4,10},
   {0,10},
   {4,10},
   {4,8},
   {1,8},
   {1,2},
   {14,2},
   {14,0},
   {1,-2}
}

--[[
local Jet = {
   {0,-20},
   {-3,-6},
   {-10,0},
   {-10,2},
   {-2,2},
   {-2,4},
   {-6,8},
   {-6,10},
   {0,10},
   {6,10},
   {6,8},
   {2,4},
   {2,2},
   {10,2},
   {10,0},
   {3,-6}
}
--]]

local curDist
local curBear
local curPos
local zeroPos
local zeroLatString
local zeroLngString
local initPos
local curX, curY
local lastX, lastY
local heading
local rotA
local distAB
local savedPos = {}
local savedXP = {}
local savedYP = {}
local gpsReads = 0

local mapScale = {100, 250, 500, 750, 1000, 1500, 2000}
local mapScaleIdx
local xmin, xmax, ymin, ymax

local altitude
local altUnit
local speed
local spdUnit

local MAXSAVED=20

local savedRow

local function readSensors(tbl)
   local sensorLbl = "***"
   --print("readSensors")
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    sensorLbl = sensor.label
	    table.insert(tbl.Lalist, "-->"..sensor.label)
	    table.insert(tbl.Idlist, 0)
	    table.insert(tbl.Palist, 0)
	 else
	    table.insert(tbl.Lalist, sensor.label)
	    --table.insert(tbl.Lalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	 end
      end
   end
end

local function clearPos()
   savedPos = {}
   savedXP = {}
   savedYP = {}
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   if subForm ~= 1 then
      if keyExit(key) then
	 form.preventDefault()
	 if subForm == 3 then
	    --print("release telem")
	    telem = nil
	 end
	 form.reinit(1)
	 return
      end
   end
   if subForm == 1 then
      if key == KEY_1 then
	 if initPos then
	    zeroPos = curPos
	    zeroLatString, zeroLngString = gps.getStrig(zeroPos)
	    system.pSave("zeroLatString", zeroLatString)
	    system.pSave("zeroLngString", zeroLngString)
	    clearPos()
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if curBear then
	    rotA = math.rad(curBear-90)
	    system.pSave("rotA", rotA*1000)
	    clearPos()
	 else
	    system.messageBox("No Current Position")
	 end
      end
   end
end

--[[
local function ctlChanged(val, ctbl, v)
   local tt = system.getSwitchInfo(val)
   if tt.assigned == true then
      ctbl[v] = val
   else
      ctbl[v] = nil
   end
   system.pSave(v.."Ctl", ctbl[v])
end
--]]

local function telemChanged(val, stbl, v, ttbl)
   stbl[v].Se = val
   stbl[v].SeId = ttbl.Idlist[val]
   stbl[v].SePa = ttbl.Palist[val]
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", stbl[v].SeId)
   system.pSave(v.."SePa", stbl[v].SePa)
end

local function initForm(sf)
   subForm = sf
   if sf == 1 then
      form.setTitle("GPS Display")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)

      form.addRow(2)
      form.addLabel({label="Telemetry >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(3)
	       form.waitForRelease()
      end))      

      form.addRow(2)
      form.addLabel({label="Controls >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))      
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
   elseif sf == 3 then
      if not telem then
	 telem = {
	    Lalist={"..."},
	    Idlist={"..."},
	    Palist={"..."}
	 }
	 readSensors(telem)
	 print("DFM-GPS rS: gcc " .. collectgarbage("count"))	
      end
      form.setTitle("Telemetry Sensors")
      for i in ipairs(sens) do
	 form.addRow(2)
	 form.addLabel({label=sens[i].label,width=140})
	 form.addSelectbox(telem.Lalist, sens[sens[i].var].Se, true,
			   (function(x) return telemChanged(x, sens, sens[i].var, telem) end),
			   {width=180, alignRight=false})
      end
      
   elseif sf == 4 then
      form.setTitle("Controls")
      for i in ipairs(ctl) do
	 form.addRow(2)
	 form.addLabel({label=ctl[i].label, width=220})
	 form.addInputbox(ctl[ctl[i].var], true, (function(x) return ctlChanged(x, ctl, ctl[i].var) end) )
      end
      --]]
   end
end

local function setMapScale(s)
   local mm = mapScale[s]
   return -mm, mm, -0.5*mm/2, 1.5*mm/2
end

local function drawShape(col, row, shape, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   for i, _ in pairs(shape) do
      if i < #shape then
	 lcd.drawLine(
	    col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	    row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5),
	    col + (shape[i+1][1]*cosShape - shape[i+1][2]*sinShape + 0.5),
	    row + (shape[i+1][1] * sinShape + shape[i+1][2] * cosShape + 0.5)	    
	 )
      end
   end
   lcd.drawLine(
      col + (shape[#shape][1]*cosShape - shape[#shape][2]*sinShape + 0.5),
      row + (shape[#shape][1] * sinShape + shape[#shape][2] * cosShape + 0.5),
      col + (shape[1][1]*cosShape - shape[1][2]*sinShape + 0.5),
      row + (shape[1][1] * sinShape + shape[1][2] * cosShape + 0.5)
   )

end

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function loop()
   
   local sensor

   sensor = system.getSensorByID(sens.alt.SeId, sens.alt.SePa)
   if sensor and sensor.valid then
      altitude = sensor.value
      altUnit = sensor.unit
   end

   sensor = system.getSensorByID(sens.spd.SeId, sens.spd.SePa)
   if sensor and sensor.valid then
      speed = sensor.value
      spdUnit = sensor.unit
   end

   curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)   

   if curPos and not initPos then gpsReads = gpsReads + 1 end
   
   if gpsReads > 9 then
      if not initPos then
	 initPos = curPos
	 if not zeroPos then zeroPos = curPos end
      end
      
      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))

      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, rotA)

      local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)
      
      if curX ~= lastX or curY ~= lastY then -- and dist > 5 then -- new point
	 heading = math.atan(curX-lastX, curY - lastY)
	 if #savedPos+1 > MAXSAVED then
	    table.remove(savedPos, 1)
	    table.remove(savedXP, 1)
	    table.remove(savedYP, 1)
	 else
	    table.insert(savedPos, curPos)
	    table.insert(savedXP, xp(curX))
	    table.insert(savedYP, yp(curY))
	 end
	 lastX = curX
	 lastY = curY
      end
      
   end
end

local nLine = {
  {-72, 7, 30},  -- +30
  {-60, 3},      -- +25
  {-48, 7, 20},  -- +20
  {-36, 3},      -- +15
  {-24, 7, 10},  --  +10
  {-12 , 3},      --  +5
  {   0 , 7, 0},        --   0
  {12, 3},       --  -5
  {24, 7, -10}, -- -10
  {36, 3},      -- -15
  {48, 7, -20}, -- -20
  {60, 3},      -- -25
  {72, 7, -30}  -- -30
}

local function drawTape(x0, y0, xh, yh, tele, lbl, unit, onLeft)
   local delta = (tele or 0) % 10
   local deltaY = 1 + math.floor(2.4 * delta)
   local xoff
   local pMult
   local yoff = 0
   local xnum
   local xbox
   local yfh = lcd.getTextHeight(FONT_NORMAL)/2
   local text
   if onLeft then
      xoff = 27
      pMult = 1
      xnum = 0
      xbox = 0
   else
      xoff = 22
      pMult = -1
      xnum = xh/2+2
      xbox = 5
   end
   lcd.drawText(x0+xh/2-pMult*8-lcd.getTextWidth(FONT_MINI, lbl)/2, yh+4, lbl, FONT_MINI)
   lcd.drawText(x0+xh/2-pMult*8-lcd.getTextWidth(FONT_MINI, unit)/2, yh+14, unit, FONT_MINI)
   lcd.setClipping(x0,y0,xh,yh)
   lcd.drawLine(xoff, 0, xoff, yh)
   for _, line in pairs(nLine) do
      lcd.drawLine(xoff, line[1]+deltaY+yh/2+yoff, xoff+pMult*line[2], line[1]+deltaY+yh/2+yoff)
      if line[3] then
	 local dd = (tele or 0) + line[3] - delta
	 text = string.format("%d",dd)
	 if (dd >= 0.0) and (dd <= 1000.0) then
	    lcd.drawText(xnum + xoff - lcd.getTextWidth(FONT_NORMAL,text)-2, line[1]+deltaY+yh/2+yoff-yfh, text)
	 end
      end
   end
   text = string.format("%d", (tele or 0))
   lcd.setColor(255,255,255)
   lcd.drawFilledRectangle(xnum-xbox, yh/2 + yoff-yfh,28,lcd.getTextHeight(FONT_NORMAL))
   lcd.setColor(0,0,0)
   lcd.drawRectangle(xnum-xbox, yh/2 + yoff-yfh,28,lcd.getTextHeight(FONT_NORMAL))
   lcd.drawText(xnum+xoff - lcd.getTextWidth(FONT_NORMAL,text)-2, yh/2+yoff-yfh, text, FONT_NORMAL|FONT_XOR)
   lcd.resetClipping() 
end

local function mapTele()
   if curX and curY then

      if curX < xmin or curX > xmax or curY < ymin or curY > ymax then
	 if mapScaleIdx + 1 <= #mapScale then
	    mapScaleIdx = mapScaleIdx + 1
	    xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)
	    clearPos()
	 end
      end
      
      drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      if savedXP and #savedXP > 1 then
	 for i=2,#savedXP do
	    lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
	 end
	 lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
      end
   end

   lcd.drawText(125, 145, string.format("[%dx%d]", xmax-xmin, ymax-ymin), FONT_MINI)
   
   lcd.drawLine(50,yp(0), 260, yp(0))

   if altitude then
      drawTape(0, 0, 50, 130, altitude, "Alt", "["..(altUnit or "---").."]", true)
   end
   if speed then
      drawTape(265, 0, 50, 130, speed, "Speed", "["..(spdUnit or "---").."]", false)
   end
   
end

local function printTele()

   local text, text2
   
   if subForm ~= 1 then return end
   text = string.format("Rot: %d  G: %d", math.deg(rotA), gpsReads)
   lcd.drawText(210,120, text)
   if initPos then
      text, text2 = gps.getStrig(curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end

local function init()
   
   --local pf
   
   emFlag = select(2, system.getDeviceType()) == 1
   --if emFlag then pf = "" else pf = "/" end

   zeroLatString = system.pLoad("zeroLatString")
   zeroLngString = system.pLoad("zeroLngString")

   for i in ipairs(sens) do
      local v = sens[i].var
      if not sens[v] then sens[v] = {} end
      sens[v].Se   = system.pLoad(v.."Se", 0)
      sens[v].SeId = system.pLoad(v.."SeId", 0)
      --print(v.."SeId: ", sens[v].SeId)
      sens[v].SePa = system.pLoad(v.."SePa", 0)
      --print(v.."SePa: ", sens[v].SePa)
   end
   
   distAB = system.pLoad("distAB", 150)
   
   rotA = system.pLoad("rotA", 0)
   rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   mapScaleIdx = 1
   xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)

   system.registerForm(1, MENU_APPS, "GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"GPS Flight Display",4, mapTele)

   if emFlag then -- needed to jumpstart emulator
      telem = {
	 Lalist={"..."},
	 Idlist={"..."},
	 Palist={"..."}
      }
      readSensors(telem)
      telem = nil
   end

   print("DFM-GPS: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="GPS"}
