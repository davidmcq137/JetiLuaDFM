--[[

   DFM-Watt.lua - computes and announces power draw from battery

   ---------------------------------------------------------
   Released under MIT-license by DFM 2021
   ---------------------------------------------------------
   
   Version 0.1 - Jan 29, 2021
   Version 0.2 - Jan 30, 2021
   Version 0.3 - Apr 18, 2021

--]]

if not sharedVar then sharedVar = {} end

sharedVar["DFM-Watt"]       = {}
sharedVar["DFM-Watt"].label = {}
sharedVar["DFM-Watt"].value = {}
sharedVar["DFM-Watt"].unit  = {}
sharedVar["DFM-Watt"].dp    = {}

-- Locals for application

local wattVersion= 0.3

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
local curSe, curSeId, curSePa
local vltSe, vltSeId, vltSePa
local annSwitch
local rstSwitch
local shortAnn
local shortAnnIndex
local imperial
local imperialIndex
local battWatts
local battWattsMax = 0
local current = 0
local voltage = 0
local lastswa = 0

local function rstSwitchChanged(value)
   rstSwitch = value
   system.pSave("rstSwitch", rstSwitch)
end

local function annSwitchChanged(value)
   annSwitch = value
   system.pSave("annSwitch", annSwitch)
end

local function curSensorChanged(value)
   curSe = value
   curSeId = sensorIdlist[curSe]
   curSePa = sensorPalist[curSe]
   if (curSeId == "...") then
      curSeId = 0
      curSePa = 0 
   end
   system.pSave("curSe", curSe)
   system.pSave("curSeId", curSeId)
   system.pSave("curSePa", curSePa)
end

local function vltSensorChanged(value)
   vltSe = value
   vltSeId = sensorIdlist[vltSe]
   vltSePa = sensorPalist[vltSe]
   if (vltSeId == "...") then
      vltSeId = 0
      vltSePa = 0 
   end
   system.pSave("vltSe", vltSe)
   system.pSave("vltSeId", vltSeId)
   system.pSave("vltSePa", vltSePa)
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

local function imperialClicked(value)
   imperial = not value
   form.setValue(imperialIndex, imperial)
   system.pSave("imperial", tostring(imperial))
end

-- Draw the main form (Application inteface)

local function initForm()

   form.addRow(2)
   form.addLabel({label="Battery Current"})
   form.addSelectbox(sensorLalist, curSe, true, curSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Battery Voltage"})
   form.addSelectbox(sensorLalist, vltSe, true, vltSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Announcement Switch", width=220})
   form.addInputbox(annSwitch, true, annSwitchChanged)
   
   form.addRow(2)
   form.addLabel({label="Max Reset Switch", width=220})
   form.addInputbox(rstSwitch, true, rstSwitchChanged)

   form.addRow(2)
   form.addLabel({label="Short Announcements", width=270})
   shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   
   --form.addRow(2)
   --form.addLabel({label="Imperial / metric (x)", width=270})
   --imperialIndex = form.addCheckbox(imperial, imperialClicked)

   form.addRow(1)
   form.addLabel({label="DFM-Watt.lua Version "..wattVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local dev = ""
local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    dev = sensor.label
	 else
	    table.insert(sensorLalist, dev.."-->"..sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
      
   end
end

local function rndInt(a)
   -- rounds to nearest int handles neg same as pos
   local sign = (a >= 0 and 1 or -1)
   return math.floor(a*sign + 0.5) * sign
end

local function loop()

   local roundWatts
   local curSensor
   local vltSensor
   local swa, swr
   local ann
   
   swa = system.getInputsVal(annSwitch)
   swr = system.getInputsVal(rstSwitch)
   
   if swa == 1 and lastswa ~= 1 then
      ann = true
   else
      ann = false
   end

   lastswa = swa

   if swr == 1 then
      battWattsMax = 0
   end
   
   if curSeId ~= 0 then
      curSensor = system.getSensorByID(curSeId, curSePa)
   end
   
   if vltSeId ~= 0 then
      vltSensor = system.getSensorByID(vltSeId, vltSePa)
   end

   if curSensor and vltSensor and curSensor.valid and vltSensor.valid then
      current = curSensor.value
      voltage = vltSensor.value
      battWatts = current * voltage
      if battWatts > battWattsMax then
	 battWattsMax = battWatts
      end

      -- do we want to switch to kW like we do in the tele window? let's try it .. it's cute

      if battWatts < 1000 then
	 sharedVar["DFM-Watt"].value[1] = battWatts
	 sharedVar["DFM-Watt"].unit[1] = "W"
	 sharedVar["DFM-Watt"].dp[1] = 0
      else
	 sharedVar["DFM-Watt"].value[1] = battWatts / 1000.0
	 sharedVar["DFM-Watt"].unit[1] = "kW"
	 if battWatts < 10000 then
	    sharedVar["DFM-Watt"].dp[1] = 2
	 else
	    sharedVar["DFM-Watt"].dp[1] = 1
	 end
      end

      
      if battWattsMax < 1000 then
	 sharedVar["DFM-Watt"].value[2] = battWattsMax
	 sharedVar["DFM-Watt"].unit[2] = "W"
	 sharedVar["DFM-Watt"].dp[2] = 0
      else
	 sharedVar["DFM-Watt"].value[2] = battWattsMax / 1000.0
	 sharedVar["DFM-Watt"].unit[2] = "kW"
	 if battWattsMax < 10000 then
	    sharedVar["DFM-Watt"].dp[2] = 2
	 else
	    sharedVar["DFM-Watt"].dp[2] = 1
	 end
      end
      
      
   end
   
   if battWatts and ann then
      roundWatts = rndInt(battWatts)
      if shortAnn then
	 system.playNumber(roundWatts, 0, "W")
      else
	 system.playNumber(roundWatts, 0, "W", "Power")	 
      end
      
   end
end

local function wattLog()
   local logval
   if not battWatts then logval = 0 else logval = battWatts end
   return logval, 1
end

local function teleWindow(w,h)
   local wtext, mtext

   if battWatts then
      if battWatts < 1000 then
	 wtext = string.format("%d W", rndInt(battWatts))
      elseif battWatts < 10000 then
	 wtext = string.format("%.2f kW", battWatts / 1000.0)
      else
	 wtext = string.format("%.1f kW", battWatts / 1000.0)
      end
   else
      wtext = "---"
   end
   
   if battWattsMax < 1000 then
      mtext = string.format("Max %d W", rndInt(battWattsMax))
   elseif battWattsMax < 10000 then
      mtext = string.format("Max %.2f kW", battWattsMax / 1000.0)
   else
      mtext = string.format("Max %.1f kW", battWattsMax / 1000.0)
   end -- battWattsMax is never nil

   if h > 24 then
      lcd.drawText(5,3, wtext,FONT_MAXI)
      lcd.drawText(5,43,mtext,FONT_BOLD)
   else
      lcd.drawText(5,3, wtext,FONT_BOLD)
   end
   
end

local function init()

   annSwitch   = system.pLoad("annSwitch")
   rstSwitch   = system.pLoad("rstSwitch")   
   shortAnn    = system.pLoad("shortAnn", "false")
   imperial    = system.pLoad("imperial", "true")
   curSe       = system.pLoad("curSe", 0)
   curSeId     = system.pLoad("curSeId", 0)
   curSePa     = system.pLoad("curSePa", 0)
   vltSe       = system.pLoad("vltSe", 0)
   vltSeId     = system.pLoad("vltSeId", 0)
   vltSePa     = system.pLoad("vltSePa", 0)
   
   readSensors()

   shortAnn = (shortAnn == "true") -- convert back to boolean here
   imperial = (imperial == "true")
   
   system.registerLogVariable("DFM-Watt", "W", wattLog)
   system.registerForm(1, MENU_APPS, "Watts Announcer", initForm)
   system.registerTelemetry(1, "Battery Power", 0, teleWindow)
   
   table.insert(sharedVar["DFM-Watt"].label, "BattWatts")
   table.insert(sharedVar["DFM-Watt"].label, "MaxBattWatts")
   
   table.insert(sharedVar["DFM-Watt"].value, 1.23)
   table.insert(sharedVar["DFM-Watt"].value, 2.34)

   table.insert(sharedVar["DFM-Watt"].unit, "W")
   table.insert(sharedVar["DFM-Watt"].unit, "W")

   table.insert(sharedVar["DFM-Watt"].dp, 0)
   table.insert(sharedVar["DFM-Watt"].dp, 0)
      
   --[[
   print("Watt")
   for k,v in pairs(sharedVar) do
      print(">", k,v)
      for kk,vv in pairs(sharedVar[k]) do
	 print(">>",kk,vv)
	 for kkk, vvv in pairs(sharedVar[k][kk]) do
	    print(">>>",kkk,vvv)
	 end
      end
   end
   --]]
end

return {init=init, loop=loop, author="DFM", version=tostring(wattVersion),
	name="Watts Announcer"}
