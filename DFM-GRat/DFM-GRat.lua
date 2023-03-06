--[[

   DFM-GRat.lua - computes and announces glide ratio

   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - July 22, 2020
   Version 0.2 - Mar  05, 2023 added kmh and km/hr conversion to m/s if required. fixed x10 log bug
   
--]]

-- Globals to share

if not sharedVar then sharedVar = {} end

sharedVar["DFM-GRat"]       = {}
sharedVar["DFM-GRat"].label = {}
sharedVar["DFM-GRat"].value = {}
sharedVar["DFM-GRat"].unit  = {}
sharedVar["DFM-GRat"].dp    = {}

-- Locals for application

local GRatVersion= 0.2

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
local spdSe, spdSeId, spdSePa
local varSe, varSeId, varSePa
local annSwitch
local shortAnn
local shortAnnIndex
local imperial
local imperialIndex
local glideRatio
local lastAnnTime
local maxRatio = 1000
local speed = 0
local vario = 0

local function annSwitchChanged(value)
   annSwitch = value
   system.pSave("annSwitch", annSwitch)
end

local function spdSensorChanged(value)
   spdSe = value
   spdSeId = sensorIdlist[spdSe]
   spdSePa = sensorPalist[spdSe]
   if (spdSeId == "...") then
      spdSeId = 0
      spdSePa = 0 
   end
   system.pSave("spdSe", spdSe)
   system.pSave("spdSeId", spdSeId)
   system.pSave("spdSePa", spdSePa)
end

local function varSensorChanged(value)
   varSe = value
   varSeId = sensorIdlist[varSe]
   varSePa = sensorPalist[varSe]
   if (varSeId == "...") then
      varSeId = 0
      varSePa = 0 
   end
   system.pSave("varSe", varSe)
   system.pSave("varSeId", varSeId)
   system.pSave("varSePa", varSePa)
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
   form.addLabel({label="Airspeed", width=177})
   form.addSelectbox(sensorLalist, spdSe, true, spdSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Vario"})
   form.addSelectbox(sensorLalist, varSe, true, varSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Announcement Switch", width=220})
   form.addInputbox(annSwitch, true, annSwitchChanged)
   
   form.addRow(2)
   form.addLabel({label="Short Announcements", width=270})
   shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   
   form.addRow(2)
   form.addLabel({label="Imperial / metric (x)", width=270})
   imperialIndex = form.addCheckbox(imperial, imperialClicked)

   form.addRow(1)
   form.addLabel({label="DFM-GRat.lua Version "..GRatVersion.." ",
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

   local swa
   local roundRat
   local spdSensor
   local varSensor
   local now
   local arg
   
   swa= system.getInputsVal(annSwitch)
   now = system.getTimeCounter()

   if spdSeId ~= 0 then
      spdSensor = system.getSensorByID(spdSeId, spdSePa)
   end
   
   if varSeId ~= 0 then
      varSensor = system.getSensorByID(varSeId, varSePa)
   end

   if spdSensor and varSensor and spdSensor.valid and varSensor.valid then
      speed = spdSensor.value
      if varSensor.unit == "m/s" and (spdSensor.unit == "km/h" or spdSensor.unit== "kmh") then
	 speed = speed / 3.6
      end
      vario = varSensor.value
      if math.abs(speed / vario) < maxRatio then
	 arg = speed*speed - vario*vario
	 if arg > 0 then
	    glideRatio = math.sqrt(arg) / vario
	    --print(spdSensor.value, varSensor.value, arg, glideRatio)
	 else
	    glideRatio = speed / vario
	 end
	 sharedVar["DFM-GRat"].value[1] = glideRatio
      else
	 glideRatio = maxRatio -- not sure best thing to do here - set to large #,don't announce
	 sharedVar["DFM-GRat"].value[1] = maxRatio
	 return
      end
   else
      sharedVar["DFM-GRat"].value[1] = 0.0
      return
   end
   
   --print(spdSensor.value, speed, vario, glideRatio)
   
   if glideRatio and swa == 1 and (system.getTimeCounter() - lastAnnTime > 2000) then
      lastAnnTime = now
      roundRat = rndInt(glideRatio)
      if (shortAnn) then
	 --print("Short ann: ", roundRat)
	 system.playNumber(roundRat, 0)
      else
	 --print("Long ann: ", roundRat)
	 system.playFile('/Apps/DFM-GRat/Ratio.wav', AUDIO_IMMEDIATE)	       
	 system.playNumber(roundRat, 0)
      end
   end
end

local function glideLog()
   local logval
   if not glideRatio then logval = 0 else logval = glideRatio end
   return logval * 10, 1
end

local function teleWindow(w,h)
   local gtext, stext, vtext
   if glideRatio and math.abs(glideRatio) < 1000 then
      gtext = string.format("Ratio %.1f", rndInt(glideRatio*10) / 10)
   else
      gtext = "---"
   end
   local sunit = imperial and "mph" or "m/s"
   local vunit = imperial and "ft/s" or "m/s"
   stext = string.format("Airspeed %.1f " .. sunit, speed * (imperial and 2.23694 or 1) )
   vtext = string.format("Vario %.1f " .. vunit, vario * (imperial and 3.28084 or 1) )
   lcd.drawText(5,3, gtext,FONT_BOLD)
   if h > 24 then
      lcd.drawText(5,23,stext,FONT_BOLD)
      lcd.drawText(5,43,vtext,FONT_BOLD)
   end
end

local function init()

   annSwitch   = system.pLoad("annSwitch")
   shortAnn    = system.pLoad("shortAnn", "false")
   imperial    = system.pLoad("imperial", "true")
   spdSe       = system.pLoad("spdSe", 0)
   spdSeId     = system.pLoad("spdSeId", 0)
   spdSePa     = system.pLoad("spdSePa", 0)
   varSe       = system.pLoad("varSe", 0)
   varSeId     = system.pLoad("varSeId", 0)
   varSePa     = system.pLoad("varSePa", 0)
   
   readSensors()

   shortAnn = (shortAnn == "true") -- convert back to boolean here
   imperial = (imperial == "true")
   
   lastAnnTime = 0
   
   system.registerLogVariable("GlideRatio", "", glideLog)
   system.registerForm(1, MENU_APPS, "Glide Ratio Announcer", initForm)
   system.registerTelemetry(1, "Glide Ratio", 0, teleWindow)

   table.insert(sharedVar["DFM-GRat"].label, "GlideRatio")
   table.insert(sharedVar["DFM-GRat"].value, 0.0)
   table.insert(sharedVar["DFM-GRat"].unit, "")
   table.insert(sharedVar["DFM-GRat"].dp, 0)

end

return {init=init, loop=loop, author="DFM", version=tostring(GRatVersion),
	name="Glide Ratio Announcer"}
