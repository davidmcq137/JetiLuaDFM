--[[

   ----------------------------------------------------------------------------
   DFM-GPS.lua released under MIT license by DFM 11/2022

   Simple GPS display app .. no maps! Nofly zone json files made by www,jetiluadfm.app

   drawTape() inspired by Jeti's Artificial Horizon app
   ----------------------------------------------------------------------------

   Things to do:
   
   1. Finish or turn off the "future" feature for no fly ahead warnings. 
   2. Add enclosing circle optimization to nfz's on read .. compute the circle and uncomment the check
   3. Write a function for the gps position to xy .. used already in a few places!

--]]

local GPSVersion = "0.60"
local subForm = 0

local mapV = {}
local fields = {}
local nfz = {}

-- permanently loaded modules
local DT, NF, DR, MM, GS, SE

-- transient loaded modules
local ST, SF

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function writeJSON()
   local fp
   local save={}
   if mapV.writeBD then
      save.settings = mapV.settings
      save.sensIdPa = mapV.sensIdPa
      for k,v in pairs(save.sensIdPa) do
	 for kk,vv in pairs(v) do
	    if kk == "SeId" then v[kk] = string.format("0X%X", vv) end
	 end
      end
      fp = io.open(mapV.fileBD, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
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
	    mapV.settings.zeroLatString, mapV.settings.zeroLngString = gps.getStrig(mapV.zeroPos)
	    if not mapV.monoTx then DR.recalcXY(mapV) end
	    mapV.gpsCalA = true
	    mapV.needCalcXY = true
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if mapV.curBear then
	    mapV.settings.rotA = math.rad(mapV.curBear-90)
	    if not mapV.monoTx then DR.recalcXY(mapV) end
	    mapV.gpsCalB = true
	    mapV.needCalcXY = true	    
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_3 then
	 print("gcc: " .. collectgarbage("count"))
	 for k,_ in pairs(package.loaded) do
	    if string.find(k, "DFM") then print("module loaded: " ..k) end
	 end
      elseif key == KEY_4 then

      elseif subForm == 3 or subForm == 4 or subForm == 5 then
	 if keyExit(key) then
	    form.preventDefault()
	    form.reinit(1)
	    return
	 end
      end
   end
end

local function initForm(sf)
   subForm = sf
   collectgarbage()
   if sf == 1 then
      form.setTitle("GPS Display")
   
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Mem",   ENABLED)
      
      if not mapV.monoTx then
	 form.addRow(2)
	 form.addLabel({label="Settings >>", width=220})
	 form.addLink((function()
		  form.reinit(5)
		  form.waitForRelease()
	 end))
      end
      
      if not mapV.monoTx then
	 form.addRow(2)
	 form.addLabel({label="History ribbon >>", width=220})
	 form.addLink((function()
		  form.reinit(4)
		  form.waitForRelease()
	 end))
      end
      
      form.addRow(2)
      form.addLabel({label="Reset App data >>", width=220})
      form.addLink((function()
	       form.reinit(6)
	       form.waitForRelease()
      end))      
   elseif sf == 2 then
   elseif sf == 4 then -- only possible to get here if on color TX
      SE = require "DFM-GPS/settingsCmd"
      SE.settings(mapV, DR.setMAX)
   elseif sf == 5 then
      GS = require "DFM-GPS/genSettingsCmd"
      GS.genSettings(mapV)
   elseif sf == 6 then
      io.remove(mapV.fileBD)
      mapV.writeBD = false
      system.messageBox("Data deleted .. restart App")
      form.reinit(1)
   end
end

local function checkGPS()

   mapV.curPos = gps.getPosition(mapV.sensIdPa.lat.SeId, mapV.sensIdPa.lat.SePa, mapV.sensIdPa.lng.SePa)   
   local lt, lg = 0,0
   if mapV.curPos then lt, lg = gps.getValue(mapV.curPos) end
   if mapV.curPos and lt ~= 0 and lg ~= 0 and not mapV.initPos then mapV.gpsReads = mapV.gpsReads + 1 end
   if mapV.gpsReads > 9 then
      if not mapV.initPos then
	 mapV.initPos = mapV.curPos
	 if not mapV.zeroPos then mapV.zeroPos = mapV.curPos end
	 return true
      end
   end
   return false
end

local function loop()

   -- first see if telemetry selection popup is finished
   if mapV.STdone then
      ST = nil
      package.loaded["DFM-GPS/selTeleCmd"] = nil
      mapV.STdone = false
   end
   
   if ST then return end 
    
   -- then check if there are sensors defined
   if not mapV.sensIdPa then return end
   
   -- then see if we need to do popup for field selection (first time only)
   if not mapV.initPos and checkGPS() then
      SF = require "DFM-GPS/selFieldCmd"
      SF.selField(mapV, fields, nfz, prefix)
   end

   -- don't proceed till field selection is done and unloaded
   if  mapV.SFdone then
      SF = nil
      package.loaded["DFM-GPS/selFieldCmd"] = nil
      mapV.SFdone = false
      mapV.needCalcXY = true
   end
   
   if SF then return end

   -- now ready to draw .. load the draw routines if needed
   if not DR then
      if mapV.monoTx then
	 DR = require "DFM-GPS/drawMono"
      else
	 DR = require "DFM-GPS/drawColor"
      end
      DR.drawInit(mapV, nfz)
      DR.setMAX(mapV)
   end

   if DR then
      DR.readGPS(mapV)
   end
   
   -- see if tele channels for tapes are defined .. don't load unless they are
   -- drawTape routines called from tele closures
   local needDT
   needDT = DR.readTele(mapV)
   if needDT and (not DT) then
      DT = require "DFM-GPS/drawTape"
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

   if not NF then
      NF = require "DFM-GPS/compGeo"
   end
   
   DR.checkNoFly(mapV, nfz, NF)

   lcd.drawText(130, 145, DR.fieldStr(), FONT_MINI)
   
   lcd.drawLine(50, DR.getYP(0), 260, DR.getYP(0))

   if mapV.altitude and DT then
      DT.drawTape(0, 0, 50, 130, mapV.altitude, "Alt", "["..(mapV.altunit or "---").."]", true)
   end
   if mapV.speed and DT then
      DT.drawTape(265, 0, 50, 130, mapV.speed, "Speed", "["..(mapV.spdUnit or "---").."]", false)
   end

   lcd.drawText(250, 0, string.format("%.1f", collectgarbage("count")), FONT_MINI)   
   
end

local function printTele()

   local text, text2

   if subForm == 1 then
      if mapV.settings.rotA then text = string.format("%d", math.deg(mapV.settings.rotA)) else
	 text = "---" end
      text = string.format("Rot: %s  G: %d", text, mapV.gpsReads)
      lcd.drawText(210,120, text)
      if mapV.initPos then
	 if mapV.curPos then
	    text, text2 = gps.getStrig(mapV.curPos)
	 else
	    text, text2 = "---", "---"
	 end
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
   M.initCmd(mapV, fields, prefix)
   M = nil
   package.loaded["DFM-GPS/initCmd"] = nil
   collectgarbage()

   local s1,s2 = system.getInputs("P1", "P2")
   
   if (s1 < -0.8 and s2 < -0.8) or not mapV.sensIdPa or not
   (mapV.sensIdPa.lat.SeId > 0 and mapV.sensIdPa.lat.SePa > 0 and mapV.sensIdPa.lng.SePa > 0) then

      ST = require "DFM-GPS/selTeleCmd"
      system.registerForm(2, 0, "DFM-GPS Telemetery Sensors",
			  (function(x) return ST.selTele(mapV) end), nil, nil,
			  (function(x)
				print("tel form killed")
				mapV.STdone = true
				collectgarbage()
      end) )
   end

   if mapV.monoTx then
      print("Mono")
      mapV.settings.nfzBeeps = true
      --for the mono TX wait till last min to load drawing
      --to give more mem space for telemetry command
      --DR = require "DFM-GPS/drawMono"
   else
      print("Color")
      DR = require "DFM-GPS/drawColor"
      DR.drawInit()
      DR.setMAX(15, mapV)
   end

   system.registerForm(1, MENU_APPS, "DFM-GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"DFM-GPS Flight Display",4, mapTele)

   collectgarbage()

   print("gc", collectgarbage("count"))

end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="DFM-GPS", destroy=writeJSON}
