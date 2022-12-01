--[[

   ----------------------------------------------------------------------------
   DFM-GPS.lua released under MIT license by DFM 11/2022

   Simple GPS display app .. no maps! Nofly zone json files made by www,jetiluadfm.app

   drawTape() inspired by Jeti's Artificial Horizon app
   ----------------------------------------------------------------------------
   
--]]

local GPSVersion = "0.5"

local subForm = 0

--local telem
local sensIdPa
local settings
local nfz
local fields
local mapV = {}
local monoTx

local sens = {
   {var="lat", label="Latitude"},
   {var="lng", label="Longitude"},
   {var="alt", label="Altitude"},
   {var="spd", label="Speed"}
}

-- permanently loaded modules
local DT, NF, DR, MM, GS

local mapScale = {100, 250, 500, 750, 1000, 1500, 2000}

local curX, curY
local lastX, lastY
local heading

local savedRow
local fileBD, writeBD

local lastNoFly

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

local function setMapScale(s)
   local mm = mapScale[s]
   return -mm, mm, -0.5*mm/2, 1.5*mm/2
end

local function xp(x)
   return 320 * (x - mapV.xmin) / (mapV.xmax - mapV.xmin)
end

local function yp(y)
   return 160 *(1 -  (y - mapV.ymin) / (mapV.ymax - mapV.ymin))
end

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
end

local function unrequire(m)
   package.loaded[m] = nil
end

local function loadNF()
   NF = require "DFM-GPS/compGeo"
end

local function loadDT()
   DT = require "DFM-GPS/drawTape"
end

-- convert no fly polygon coords from lat,lng to x,y in current frame
local function noFlyCalc()
   local pt, cD, cB, x, y
   if not NF then loadNF() end
   for i in ipairs(nfz) do
      if not nfz[i].xy then nfz[i].xy = {} end
      for j in ipairs(nfz[i].path) do
	 pt = gps.newPoint(nfz[i].path[j].lat,nfz[i].path[j].lng)
	 cD = gps.getDistance(mapV.zeroPos, pt)
	 cB = gps.getBearing(mapV.zeroPos, pt)
	 x = cD * math.cos(math.rad(cB+270))
	 y = cD * math.sin(math.rad(cB+90))
	 x,y = rotateXY(x, y, (settings.rotA or 0))
	 nfz[i].xy[j] = {x=x,y=y}
	 if x > mapV.maxPolyX then mapV.maxPolyX = x end
      end
   end
   mapV.needCalcXY = false
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true else return false end
end

local function keyForm(key)
   if subForm == 1 then
      if key == KEY_1 then
	 if mapV.initPos then
	    mapV.zeroPos = mapV.curPos
	    settings.zeroLatString, settings.zeroLngString = gps.getStrig(mapV.zeroPos)
	    DR.clearPos(xp, yp, mapV, settings, rotateXY)
	    mapV.gpsCalA = true
	    mapV.needCalcXY = true
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if mapV.curBear then
	    settings.rotA = math.rad(mapV.curBear-90)
	    DR.clearPos(xp, yp, mapV, settings, rotateXY)
	    mapV.gpsCalB = true
	    mapV.needCalcXY = true	    
	 else
	    system.messageBox("No Current Position")
	 end
      end
   elseif subForm == 3 or subForm == 4 or subForm == 5 then
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
   print("iF", sf)
   print("iF) gcc: " .. collectgarbage("count"))
   for k,v in pairs(package.loaded) do
      if string.find(k, "DFM") then print("iF) module loaded: " ..k) end
   end
   if sf == 1 then
      if monoTx then
	 local M = require "DFM-GPS/mainMenuCmd"
	 savedRow = M.mainMenu(savedRow, monoTx)
	 unrequire("DFM-GPS/mainMenuCmd")
	 M = nil
	 collectgarbage()
      else
	 MM = require "DFM-GPS/mainMenuCmd"
	 savedRow = MM.mainMenu(savedRow, monoTx)
      end
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
   elseif sf == 3 then
      local M = require "DFM-GPS/selTeleCmd"
      savedRow = M.selTele(sens, sensIdPa, savedRow)
      unrequire("DFM-GPS/selTeleCmd")
      M = nil
      collectgarbage()
   elseif sf == 4 then
      local M = require "DFM-GPS/settingsCmd"
      M.settings(savedRow, settings, DR.setMAX, mapV, xp, yp, rotateXY)
      unrequire("DFM-GPS/settingsCmd")
      M = nil
      collectgarbage()
   elseif sf == 5 then
      GS = require "DFM-GPS/genSettingsCmd"
      savedRow = GS.genSettings(savedRow, settings, mapV)
   elseif sf == 6 then
      io.remove(fileBD)
      writeBD = false
      system.messageBox("Data deleted .. restart App")
      form.reinit(1)
   end
end

local function keyGPS(key)
   local M = require "DFM-GPS/selFieldCmd"
   nfz = M.keyField(key, mapV, settings, fields, prefix)
   if nfz and #nfz > 0 then noFlyCalc() end
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

local function loop()

   if not sens then return end
   
   local sensor
   sensor = system.getSensorByID(sensIdPa.alt.SeId, sensIdPa.alt.SePa)
   if sensor and sensor.valid then
      mapV.altitude = sensor.value
      mapV.altunit = sensor.unit
      if not DT then loadDT() end
   end
   
   sensor = system.getSensorByID(sensIdPa.spd.SeId, sensIdPa.spd.SePa)
   if sensor and sensor.valid then
      mapV.speed = sensor.value
      mapV.spdUnit = sensor.unit
      if not DT then loadDT() end
   end
   
   mapV.curPos = gps.getPosition(sensIdPa.lat.SeId, sensIdPa.lat.SePa, sensIdPa.lng.SePa)   

   if mapV.curPos and not mapV.initPos then mapV.gpsReads = mapV.gpsReads + 1 end
   
   if mapV.gpsReads > 9 then
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
      lastX, lastY, heading = DR.savePoints(mapV, curX, curY, lastX, lastY, xp, yp, settings)
   end

end

local function mapTele()

   if not mapV.initPos then
      lcd.drawText(0,10,"No GPS position", FONT_BIG)
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
      if mapV.needCalcXY then noFlyCalc() end
      DR.drawNFZ(nfz, mapV, xp, yp)
   end
   
   if curX and curY then

      if curX < mapV.xmin or curX > mapV.xmax or curY < mapV.ymin or curY > mapV.ymax then
	 if mapV.mapScaleIdx + 1 <= #mapScale then
	    mapV.mapScaleIdx = mapV.mapScaleIdx + 1
	    mapV.xmin, mapV.xmax, mapV.ymin, mapV.ymax = setMapScale(mapV.mapScaleIdx)
	    DR.clearPos(xp, yp, mapV, settings, rotateXY)
	 end
      end

      local noFly
      if nfz and #nfz > 0 and NF then
	 local txy = {x=curX,y=curY}
	 local noFlyP = false
	 local noFlyC = false
	 for i in ipairs(nfz) do 
	    if nfz[i].shape == "polygon" then
	       noFlyP = noFlyP or NF.isNoFlyP(nfz[i], txy, mapV.maxPolyX)
	    else
	       noFlyC = noFlyC or NF.isNoFlyC(nfz[i], txy)
	    end
	 end
	 noFly = noFlyP or noFlyC
	 if lastNoFly == nil then lastNoFly = noFly end
	 if noFly and not lastNoFly then
	    if settings.nfzBeeps then
	       system.playBeep(1, 1200, 800)
	    end
	    if settings.nfzWav then
	       system.playFile("/Apps/DFM-GPS/enter_no_fly.wav")
	    end
	 end
	 if not noFly and lastNoFly then
	    if settings.nfzBeeps then
	       system.playBeep(0, 600, 400)
	    end
	    if settings.nfzWav then
	       system.playFile("/Apps/DFM-GPS/exit_no_fly.wav")
	    end
	 end
	 lastNoFly = noFly
      else
	 noFly = false
      end

      DR.drawRibbon(xp, yp, curX, curY, settings, mapV, rotateXY)

      if noFly then
	 if monoTx then
	    lcd.drawCircle(xp(curX), yp(curY), 4)
	 else
	    DR.drawShape(xp(curX), yp(curY), settings.planeShape, (heading or 0), "In")
	 end
      else
	 DR.drawShape(xp(curX), yp(curY), settings.planeShape, (heading or 0), "Out")
      end
      
   end

   lcd.drawText(130, 145, string.format("[%dx%d]", mapV.xmax-mapV.xmin, mapV.ymax-mapV.ymin), FONT_MINI)
   
   lcd.drawLine(50,yp(0), 260, yp(0))

   if mapV.altitude and DT then
      DT.drawTape(0, 0, 50, 130, mapV.altitude, "Alt", "["..(mapV.altunit or "---").."]", true)
   end
   if mapV.speed and DT then
      DT.drawTape(265, 0, 50, 130, mapV.speed, "Speed", "["..(mapV.spdUnit or "---").."]", false)
   end
end

local function printTele()

   local text, text2

   if subForm == 1 then
      if settings.rotA then text = string.format("%d", math.deg(settings.rotA)) else text = "---" end
      text = string.format("Rot: %s  G: %d", text, mapV.gpsReads)
      lcd.drawText(210,120, text)
      if mapV.initPos then
	 text, text2 = gps.getStrig(mapV.curPos)
	 lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
      else
	 lcd.drawText(10,120,"-No GPS-")   
      end
   elseif subForm == 4 then
      DR.drawColors()
   end
end

local function init()

   local M = require "DFM-GPS/initCmd"
   settings, sensIdPa, fields, writeBD, fileBD = M.initCmd(sens, mapV, prefix, setMapScale)
   unrequire("DFM-GPS/initCmd")
   M = nil
   collectgarbage()

   local monoDev = {"JETI DC-16", "JETI DS-16", "JETI DC-14", "JETI DS-14"}
   local dev = system.getDeviceType()

   monoTx = false
   for _,v in ipairs(monoDev) do
      if dev == v then monoTx = true break end
   end

   -- on emulator set to B+W color scheme to force Mono TX behavior
   if select(2, system.getDeviceType()) == 1 then 
      system.getSensors() -- needed to jumpstart emulator
      if system.getProperty("Color") == 0 then
	 monoTx = true
      end
   end

   if monoTx then
      print("Mono")
      settings.nfzBeeps = true
      DR = require "DFM-GPS/drawMono"
   else
      print("Color")
      DR = require "DFM-GPS/drawColor"
   end

   DR.setMAX(settings.maxRibbon, xp, yp, mapV,settings,rotateXY)

   system.registerForm(1, MENU_APPS, "DFM-GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"DFM-GPS Flight Display",4, mapTele)

   
end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="DFM-GPS", destroy=writeJSON}
