--[[

   ----------------------------------------------------------------------------
   DFM-GPS.lua released under MIT license by DFM 2022

   Simple GPS display app .. no maps!

   drawTape() inspired by Jeti's Artificial Horizon app
   ----------------------------------------------------------------------------
   
--]]

local GPSVersion = "0.3"

local subForm = 0

local telem
local sensIdPa
local settings
local nfz
local fields
   
local nfk = {type=1, shape=2, lat=1, lng=2,
	     selType={"Inside", "Outside"},  inside=1, outside=2,
	     selShape={"Circle", "Polygon"}, circle=1, polygon=2
}

local sens = {
   {var="lat", label="Latitude"},
   {var="lng", label="Longitude"},
   {var="alt", label="Altitude"},
   {var="spd", label="Speed"}
}

local DT
local NF

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

local mapV = {}

local mapScale = {100, 250, 500, 750, 1000, 1500, 2000}

local curX, curY
local lastX, lastY
local heading
local savedPos = {}
local savedXP = {}
local savedYP = {}
local gpsReads = 0

local altitude
local altUnit
local speed
local spdUnit

local MAXSAVED=20

local savedRow, savedZone
local fileBD, writeBD

local needCalcXY = true
local maxPolyX = 0
local lastNoFly

local function unrequire(m)
   package.loaded[m] = nil
end

local function prefix()
   local emFlag
   local pf
   emFlag = select(2, system.getDeviceType()) == 1
   if emFlag then pf = "" else pf = "/" end
   return pf
end

local function writeJSON()
   local fp
   local save={}
   if writeBD then
      save.settings = settings
      save.sensIdPa = sensIdPa
      fp = io.open(fileBD, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
end

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
end


local function loadNF()
   NF = require "DFM-GPS/compGeo"
end

-- convert no fly polygon coords from lat,lng to x,y in current frame
local function noFlyCalc()
   local pt, cD, cB, x, y
   if not NF then loadNF() end
   for i in ipairs(nfz) do
      for j in ipairs(nfz[i].path) do
	 pt = gps.newPoint(nfz[i].path[j].lat,nfz[i].path[j].lng)
	 cD = gps.getDistance(mapV.zeroPos, pt)
	 cB = gps.getBearing(mapV.zeroPos, pt)
	 x = cD * math.cos(math.rad(cB+270))
	 y = cD * math.sin(math.rad(cB+90))
	 x,y = rotateXY(x, y, (settings.rotA or 0))
	 nfz[i].xy[j] = {x=x,y=y}
	 if x > maxPolyX then maxPolyX = x end
      end
   end
   needCalcXY = false
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
   if subForm == 1 then
      if key == KEY_1 then
	 if mapV.initPos then
	    mapV.zeroPos = mapV.curPos
	    settings.zeroLatString, settings.zeroLngString = gps.getStrig(mapV.zeroPos)
	    clearPos()
	    mapV.gpsCalA = true
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if mapV.curBear then
	    settings.rotA = math.rad(mapV.curBear-90)
	    clearPos()
	    mapV.gpsCalB = true
	 else
	    system.messageBox("No Current Position")
	 end
      end
   elseif subForm == 3 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   end
end

local function initForm(sf)
   subForm = sf
   collectgarbage()
   print("sF) gcc: " .. collectgarbage("count"))
   for k,v in pairs(package.loaded) do
      if string.find(k, "DFM") then print("sF) module loaded: " ..k) end
   end

   if sf == 1 then
      local M = require "DFM-GPS/mainMenuCmd"
      savedRow = M.mainMenu(savedRow)
      unrequire("DFM-GPS/mainMenuCmd")
      M = nil
      collectgarbage()
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
   elseif sf == 3 then
      local M = require "DFM-GPS/selTeleCmd"
      telem, savedRow = M.selTele(telem, sens, sensIdPa, savedRow)
      unrequire("DFM-GPS/selTeleCmd")
      M = nil
      collectgarbage()
   elseif sf == 6 then
      io.remove(fileBD)
      writeBD = false
      system.messageBox("Data deleted .. restart App")
      form.reinit(1)
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
   return 320 * (x - mapV.xmin) / (mapV.xmax - mapV.xmin)
end

local function yp(y)
   return 160 *(1 -  (y - mapV.ymin) / (mapV.ymax - mapV.ymin))
end

local function keyGPS(key)
   local M = require "DFM-GPS/selFieldCmd"
   nfz = M.keyField(key, mapV, settings)
   unrequire("DFM-GPS/selFieldCmd")
   M = nil
   collectgarbage()
end

local function initGPS()
   form.setTitle("Press Esc to exit with no field")
   local M = require "DFM-GPS/selFieldCmd"
   M.selField(fields, nil, mapV.zeroPos)
   unrequire("DFM-GPS/selFieldCmd")
   M = nil
   collectgarbage()
end

local function loadDT()
   DT = require "DFM-GPS/drawTape"
end

local function loop()

   if not sens then return end
   
   local sensor
   sensor = system.getSensorByID(sensIdPa.alt.SeId, sensIdPa.alt.SePa)
   if sensor and sensor.valid then
      altitude = sensor.value
      altUnit = sensor.unit
      if not DT then loadDT() end
   end
   
   sensor = system.getSensorByID(sensIdPa.spd.SeId, sensIdPa.spd.SePa)
   if sensor and sensor.valid then
      speed = sensor.value
      spdUnit = sensor.unit
      if not DT then loadDT() end
   end
   
   mapV.curPos = gps.getPosition(sensIdPa.lat.SeId, sensIdPa.lat.SePa, sensIdPa.lng.SePa)   

   if mapV.curPos and not mapV.initPos then gpsReads = gpsReads + 1 end
   
   if gpsReads > 9 then
      if not mapV.initPos then
	 mapV.initPos = mapV.curPos
	 if not mapV.zeroPos then mapV.zeroPos = mapV.curPos end
	 system.registerForm(2, 0, "DFM-GPS Field Selection", initGPS, keyGPS)
      end

      mapV.curDist = gps.getDistance(mapV.zeroPos, mapV.curPos)
      mapV.curBear = gps.getBearing(mapV.zeroPos, mapV.curPos)
      
      curX = mapV.curDist * math.cos(math.rad(mapV.curBear+270)) -- why not same angle X and Y??
      curY = mapV.curDist * math.sin(math.rad(mapV.curBear+90))

      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, settings.rotA or 0)

      --local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)
      
      if curX ~= lastX or curY ~= lastY then -- and dist > 5 then -- new point
	 heading = math.atan(curX-lastX, curY - lastY)
	 if #savedPos+1 > MAXSAVED then
	    table.remove(savedPos, 1)
	    table.remove(savedXP, 1)
	    table.remove(savedYP, 1)
	 else
	    table.insert(savedPos, mapV.curPos)
	    table.insert(savedXP, xp(curX))
	    table.insert(savedYP, yp(curY))
	 end
	 lastX = curX
	 lastY = curY
      end
      
   end
end

local function mapTele()

   if not mapV.selField then
      lcd.drawText(0,10,"No Field Selected", FONT_BIG)
      return
   end
   
   if not mapV.gpsCalA then
      lcd.drawText(0,10,"GPS Point A not set", FONT_BIG)
      return
   end

   if not mapV.gpsCalB then
      lcd.drawText(0,10,"GPS Point B not set", FONT_BIG)
      return
   end
   
   if nfz and #nfz > 0 and mapV.zeroPos and nfz[1].xy and NF then
      if needCalcXY then noFlyCalc() end
      for i in ipairs(nfz) do
	 if nfz[i].shape == nfk.polygon then
	    local n = #nfz[i].xy
	    if n > 3 then
	       for j=1,n-1 do
		  lcd.drawLine(xp(nfz[i].xy[j].x),yp(nfz[i].xy[j].y),xp(nfz[i].xy[j+1].x),yp(nfz[i].xy[j+1].y))
	       end
	       lcd.drawLine(xp(nfz[i].xy[n].x),yp(nfz[i].xy[n].y),xp(nfz[i].xy[1].x),yp(nfz[i].xy[1].y))
	    end
	 else
	    if nfz[i].xy and #nfz[i].xy > 0 then
	       lcd.drawCircle(xp(nfz[i].xy[1].x), yp(nfz[i].xy[1].y), 320*nfz[i].radius/(mapV.xmax-mapV.xmin))
	    end
	 end
      end
   end
   
   if curX and curY then

      if curX < mapV.xmin or curX > mapV.xmax or curY < mapV.ymin or curY > mapV.ymax then
	 if mapV.mapScaleIdx + 1 <= #mapScale then
	    mapV.mapScaleIdx = mapV.mapScaleIdx + 1
	    mapV.xmin, mapV.xmax, mapV.ymin, mapV.ymax = setMapScale(mapV.mapScaleIdx)
	    clearPos()
	 end
      end

      local noFly
      if nfz and #nfz > 0 and NF then
	 local txy = {x=curX,y=curY}
	 local noFlyP = false
	 local noFlyC = false
	 for i in ipairs(nfz) do
	    if nfz[i].shape == nfk.polygon then
	       noFlyP = noFlyP or isNoFlyP(nfz[i], txy, maxPolyX)
	    else
	       noFlyC = noFlyC or isNoFlyC(nfz[i], txy)
	    end
	 end
	 noFly = noFlyP or noFlyC
	 if lastNoFly == nil then lastNoFly = noFly end
	 if noFly and not lastNoFly then
	    system.playBeep(1, 1200, 800)
	 end
	 if not noFly and lastNoFly then
	    system.playBeep(0, 600, 400)
	 end
	 lastNoFly = noFly
      else
	 noFly = false
      end

      if noFly then
	 lcd.drawCircle(xp(curX), yp(curY), 4)
      else
	 drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      end
      
      if savedXP and #savedXP > 1 then
	 for i=2,#savedXP do
	    lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
	 end
	 lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
      end
   end

   lcd.drawText(125, 145, string.format("[%dx%d]", mapV.xmax-mapV.xmin, mapV.ymax-mapV.ymin), FONT_MINI)
   
   lcd.drawLine(50,yp(0), 260, yp(0))

   if altitude and DT then
      DT.drawTape(0, 0, 50, 130, altitude, "Alt", "["..(altUnit or "---").."]", true)
   end
   if speed and DT then
      DT.drawTape(265, 0, 50, 130, speed, "Speed", "["..(spdUnit or "---").."]", false)
   end
   
end

local function printTele()

   local text, text2
   
   if subForm ~= 1 then return end
   if settings.rotA then text = string.format("%d", math.deg(settings.rotA)) else text = "---" end
   text = string.format("Rot: %s  G: %d", text, gpsReads)
   lcd.drawText(210,120, text)
   if mapV.initPos then
      text, text2 = gps.getStrig(mapV.curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end

local function init()

   local M = require "DFM-GPS/initCmd"

   settings, sensIdPa, fields, writeBD, fileBD = M.initCmd(sens, mapV, prefix, setMapScale)

   unrequire("DFM-GPS/initCmd")
   M = nil
   collectgarbage()
   
   system.registerForm(1, MENU_APPS, "GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"GPS Flight Display",4, mapTele)

   if select(2, system.getDeviceType()) == 1 then -- needed to jumpstart emulator
      system.getSensors()
   end

   print("DFM-GPS: gcc " .. collectgarbage("count"))


end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="GPS", destroy=writeJSON}
