--[[

   ----------------------------------------------------------------------------
   DFM-GPS.lua released under MIT license by DFM 11/2022

   Simple GPS display app .. no maps! Nofly zone json files made by www,jetiluadfm.app

   drawTape() inspired by Jeti's Artificial Horizon app
   ----------------------------------------------------------------------------
   
--]]

local GPSVersion = "0.5"

local subForm = 0

local sensIdPa
local settings
local nfz
local fields
local mapV = {}
local monoTx

-- permanently loaded modules (NF is required in drawColor.lua)
local DT, NF, DR, MM, GS

local savedRow
local fileBD, writeBD

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
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

local function unrequire(m)
   package.loaded[m] = nil
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
	    if not monoTx then DR.recalcXY(settings, mapV) end
	    mapV.gpsCalA = true
	    mapV.needCalcXY = true
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if mapV.curBear then
	    settings.rotA = math.rad(mapV.curBear-90)
	    if not monoTx then DR.recalcXY(settings, mapV) end
	    mapV.gpsCalB = true
	    mapV.needCalcXY = true	    
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_3 then
	 system.messageBox("GC: " .. collectgarbage("count"))
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
   --print("iF", sf)
   print("iF) gcc: " .. collectgarbage("count"))
   for k,_ in pairs(package.loaded) do
      if string.find(k, "DFM") then print("iF) module loaded: " ..k) end
   end
   if sf == 1 then
      if monoTx then
	 local a1 = collectgarbage("count")
	 local M = require "DFM-GPS/mainMenuCmd"
	 savedRow = M.mainMenu(savedRow, monoTx)
	 local a2 = collectgarbage("count")
	 print("initCmd", a1, a2, a2-a1)
	 unrequire("DFM-GPS/mainMenuCmd")
	 M = nil
	 collectgarbage()
      else -- must leave loaded for nested menus on color TX
	 MM = require "DFM-GPS/mainMenuCmd"
	 savedRow = MM.mainMenu(savedRow, monoTx)
      end
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
   elseif sf == 3 then
      if mapV.initPos and monoTx then
	 system.messageBox("Not available with GPS connected")
	 return
      end
      local a1 = collectgarbage("count")
      local M = require "DFM-GPS/selTeleCmd"
      sensIdPa = M.selTele(sensIdPa)
      local a2 = collectgarbage("count")
      print("selTeleCmd", a1, a2, a2-a1)
      unrequire("DFM-GPS/selTeleCmd")
      M = nil
      collectgarbage()
   elseif sf == 4 then
      local M = require "DFM-GPS/settingsCmd"
      M.settings(settings, mapV, DR.setMAX)
      unrequire("DFM-GPS/settingsCmd")
      M = nil
      collectgarbage()
   elseif sf == 5 then
      GS = require "DFM-GPS/genSettingsCmd"
      GS.genSettings(settings, mapV)
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
   unrequire("DFM-GPS/selFieldCmd")
   M = nil
   collectgarbage()

   if nfz and #nfz > 0 then
      DR.noFlyCalc(settings, mapV, nfz)
   end
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

   local needDT
   if not sensIdPa then return end

   if not DR then
      print("gc 1", collectgarbage("count"))
      DR = require "DFM-GPS/drawMono"
      print("gc 2", collectgarbage("count"))
      DR.drawInit()
      DR.setMAX(settings.maxRibbon, settings, mapV)
   end
   
   needDT = DR.readTele(sensIdPa, mapV)
   if needDT and (not DT) then
      local a1 = collectgarbage("count")
      DT = require "DFM-GPS/drawTape"
         local a2 = collectgarbage("count")
	 print("dT", a1, a2, a2-a1)
   end

   DR.readGPS(sensIdPa, settings, mapV, initGPS, keyGPS)
end

local function mapTele()

   --print("mapTele")
   
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

   NF = DR.checkNoFly(settings, mapV, nfz, NF, monoTx)

   lcd.drawText(130, 145, DR.fieldStr(), FONT_MINI)
   
   lcd.drawLine(50, DR.getYP(0), 260, DR.getYP(0))

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
   collectgarbage()
   local aa1 = collectgarbage("count")
   
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
   
   local M = require "DFM-GPS/initCmd"
   settings, sensIdPa, fields, writeBD, fileBD = M.initCmd(mapV, prefix)
   unrequire("DFM-GPS/initCmd")
   M = nil
   collectgarbage()

   local aa2 = collectgarbage("count")
   
   if monoTx then
      print("Mono")
      settings.nfzBeeps = true
      --DR = require "DFM-GPS/drawMono"
   else
      print("Color")
      DR = require "DFM-GPS/drawColor"
      DR.drawInit()
      DR.setMAX(settings.maxRibbon, settings, mapV)
   end

   --DR = require "DFM-GPS/drawMono"
   --DR.drawInit()
   --DR.setMAX(settings.maxRibbon, settings, mapV)

   system.registerForm(1, MENU_APPS, "DFM-GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"DFM-GPS Flight Display",4, mapTele)

   collectgarbage()
   local aa3 = collectgarbage("count")
   print("gc", aa1, aa2, aa3)
end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="DFM-GPS", destroy=writeJSON}
