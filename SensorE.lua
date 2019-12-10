--[[

   SensorE.lua

   See SensorE.txt for a full description.

   Usage: 

   This is a stand-alone lua app intended to be run on the Jeti
   DC/DS-24 emulator. It creates a set of software "virtual sensors"
   that are specified in a json file sensorEmulator.jsn. It is
   expected that individual copies of this jsn file will exist in
   various app directories. Thus an indirection convention is employed
   with a file Apps/SensorE.jsn.  This file contains the directory in
   which to find sensorEmulator.jsn. You are of course free to specify
   configDir to be Apps which puts the config file in the directory
   with all the lua apps.

   Start this app first, and then when subsequent apps are started they
   will have their system telemetry routines redirected to the
   emulator.

   System routines replaced are:

      system.getSensors()
      system.getSensorByID()
      system.getSensorValueByID()

   The funcString capability is inspired by Jeti's V-sensor.lua app

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

local appShort="SensorE"
local appName="Sensor Emulator"
local appDir=appShort.."/"
local appVersion="1.00"
local appAuthor="DFM"

local sensorTbl={}
local sensorCache={}
local activeSensors={}
local GPSparms
local coslat0
local lastGPScalc=0
local latVal
local lonVal
local latDecimals
local lonDecimals
local time0
local rlhDone=true

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
end

-- include this for compatibility with SensorL.lua
local called = false
function emulator_ready(fcn)
   if rlhDone and not called then
      fcn()
      called = true
   end
   return(rlhDone)
end
   
function emulator_init()

   local dev, emflag
   
   dev, emflag = system.getDeviceType()
   
   if emflag == 1 then      
      system.getSensors = emulator_getSensors
      system.getSensorByID = emulator_getSensorByID
      system.getSensorValueByID = emulator_getSensorValueByID
      system.messageBox("SensorE: Using emulated sensors", 3)
   else
      system.messageBox("SensorE: Using native sensors", 3)
   end
end

function emulator_getSensors()

   local fg, text
   local SEjsn

   text = "Apps/SensorE.jsn"
   fg = io.readall(text)

   if not fg then print("Cannot read " .. text) else
      SEjsn=json.decode(fg)
   end

   text = SEjsn.configDir .. "/sensorEmulator.jsn"
   fg = io.readall(text)
   if not fg then print("Cannot read " .. text) else
      sensorTbl=json.decode(fg)
   end

   text = SEjsn.configDir .. "/sensorEmulatorGPS.jsn"
   fg = io.readall(text)
   if not fg then print("Info: No GPS file " .. text) else
      GPSparms=json.decode(fg)
      coslat0 = math.cos(math.rad(GPSparms.lat0))
   end

   time0 = system.getTimeCounter()
   
   return sensorTbl
end

local function triangleWave(T)
   local t
   t = T % 1
   if t <= 0.25 then
      return 4*t
   elseif t > 0.25 and t < 0.75 then
      return 1-4*(t-0.25)
   else
      return -1+4*(t-.75)
   end
end

local function squareWave(T)
   local t
   t = T % 1
   if t <= 0.5 then return 1 else return -1 end
end

local function sequencer(T, seq)
   local t, tn
   t = T % 1
   if seq and #seq ~= 0 then
      tn = 1 / #seq
      ti = math.floor(t / tn)
   else
      return 0
   end
   return(seq[ti+1])
end

local function sinPerOne(T) -- sin with period 1
   local t
   t = T * math.pi * 2
   return math.sin(t)
end

local function cosPerOne(T) -- sin with period 1
   local t
   t = T * math.pi * 2
   return math.cos(t)
end

local function tanPerOne(T) -- sin with period 1
   local t
   t = T * math.pi * 2
   return math.tan(t)
end



local function printFcn(...)
   print(...)
   return 0
end

--[[

add'l functions to consider

not implemented: valSec, valMin, valHour
not implemented: valYear, valMonth, valDay

date/time would be easy .. derive from system clock
details on bit packing for date and time are in sensorLogEm.lua

--]]

function emulator_getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator.getSensorById(ID, Param)
end

function emulator_getSensorByID(ID, Param)
   local c
   local chunk, err, status, result
   local returnTbl
   local xCart, yCart
   local lat, lon
   local latDeg, latFrac, latMin
   local lonDeg, lonFrac, lonMin
   local GPSdt
   
   local env = {
      s = 0,
      t = 0,
      sin   = math.sin,
      sin1  = sinPerOne,
      cos   = math.cos,
      cos1  = cosPerOne,
      tan   = math.tan,
      tan1  = tanPerOne,
      abs   = math.abs,
      min   = math.min,
      max   = math.max,
      ceil  = math.ceil,
      floor = math.floor,
      sqrt  = math.sqrt,
      exp   = math.exp,
      log   = math.log,
      rand  = math.random,
      pi    = math.pi,
      rad   = math.rad,
      tri   = triangleWave,
      sq    = squareWave,
      prt   = printFcn,
      seq   = sequencer,
   }

   if not sensorTbl then return nil end
   if not ID or not Param then return nil end
   if ID == 0 or Param == 0 then return nil end
   if system.getTimeCounter() < 0 then print("time negative") end
   for k,v in ipairs(sensorTbl) do
      if v.id == ID and v.param == Param then
	 returnTbl = {}
	 returnTbl.id = v.id
	 returnTbl.param = v.param
	 returnTbl.decimals = v.decimals -- might change later...
	 returnTbl.type = v.type
	 returnTbl.label = v.label
	 returnTbl.unit = v.unit
	 returnTbl.valid = true
	 returnTbl.sensorName = v.sensorName
	 if v.control then
	    c=system.getInputs(v.control)
	    env[v.control] = c -- can also get raw -1 to 1 by using name e.g. "P5"
	    env[string.gsub(v.control, "P", "S")] = (c+1)/2 -- and raw 0 to 1 e.g. "S5"
	    if v.controlmin and v.controlmax then
	       env.s = v.controlmin + (v.controlmax - v.controlmin) * ((c+1)/2)
	    end
	 end
	 if v.auxcontrol and #v.auxcontrol > 0 then
	    for i=1,#v.auxcontrol,1 do
	       c = system.getInputs(v.auxcontrol[i]) -- e.g P6 = <-1..1>
	       env[v.auxcontrol[i]] = c
	       env[string.gsub(v.auxcontrol[i], "P", "S")] = (1 + c) / 2 -- e.g. S6 = <0,1> 
	    end
	 end

	 env.t = ((system.getTimeCounter() - time0)/1000)
	 if GPSParms and GPSParms.startTime then
	    env.t = env.t + GPSParms.startTime
	 end
	 

	 -- if we have GPS values spec'd, then load the GPS auxcontrols, env variables
	 -- and evaluate the lua strings
	 
	 GPSdt = system.getTimeCounter() - lastGPScalc
	 if GPSparms and v.type == 9 and (v.param == 2 or v.param == 3) and GPSdt > 200 then
	    if GPSparms.auxcontrol and #GPSparms.auxcontrol > 0 then
	       for i = 1,#GPSparms.auxcontrol,1 do
		  c = system.getInputs(GPSparms.auxcontrol[i]) -- e.g P6 = <-1..1>
		  env[GPSparms.auxcontrol[i]] = c
		  env[string.gsub(GPSparms.auxcontrol[i],"P","S")] = (1 + c) / 2
	       end
	    end
	    
	    if GPSparms.lat0 then env.Lat0 = GPSparms.lat0 end
	    if GPSparms.lon0 then env.Lon0 = GPSparms.lon0 end
	    if GPSparms.lon0 then env.Lon0 = GPSparms.lon0 end
	    if GPSparms.rE   then env.rE   = GPSparms.rE   end

	    -------------------
	    
	    if GPSparms.xString and GPSparms.xString ~= "" then
	       chunk, err = load("return "..GPSparms.xString,"","t",env)
	       if err then
		  print("sensorEmulator: lua functionString load error, returning 0 - "..err)
		  result = 0
	       else
		  if chunk then
		     status, result = pcall(chunk)
		     result = result or 0
		     if not status then print("Bad status - result:", result) end
		  else
		     result = 0 
		  end
	       end
	       xCart = result
	    end

	    if GPSparms.yString and GPSparms.yString ~= "" then
	       chunk, err = load("return "..GPSparms.yString,"","t",env)
	       if err then
		  print("sensorEmulator: lua functionString load error, returning 0 - "..err)
		  result = 0
	       else
		  if chunk then
		     status, result = pcall(chunk)
		     result = result or 0
		     if not status then print("Bad status - result:", result) end
		  else
		     result = 0 
		  end
	       end
	       yCart = result
	    end

	    --print("xCart, yCart:", xCart, yCart)
	    
	    -- at this point, we have the xCart and yCart (Cartesian)
	    -- values in preferred units (determined by rE) that are
	    -- offsets from the lat0, lon0 point and we have to create
	    -- the encoded values for GPS lat and GPS lon
	    -- solve x,y equations for lat and long

	    -- if true direction of runway is supplied, rotate x,y coords to be parallel
	    -- to the runway .. else leave as-is
	    
	    if GPSparms.trueDir then
	       xCart, yCart = rotateXY(xCart, yCart, math.rad(270-GPSparms.trueDir))
	    end
	    
	    -- these will be lat and lon in radians
	    lat = yCart/GPSparms.rE + math.rad(GPSparms.lat0)
	    lon = xCart/(GPSparms.rE * coslat0) + math.rad(GPSparms.lon0)
	    
	    -- now convert to degrees
	    lat = math.deg(lat)
	    lon = math.deg(lon)
	    
	    -- note sign, work with positive values, put sign back later
	    if lat > 0 then latDecimals = 4 else
	       latDecimals = 2
	       lat = -1 * lat
	    end
	    
	    if lon > 0 then lonDecimals = 1 else
	       lonDecimals = 3
	       lon = -1 * lon
	    end

	    latDeg, latFrac = math.modf(lat)
	    lonDeg, lonFrac = math.modf(lon)

	    latMin = latFrac * 60
	    lonMin = lonFrac * 60

	    lonVal = 0
	    latVal = 0
	    
	    lonVal = lonDeg << 16
	    lonVal = lonVal + 1000 * lonMin

	    latVal = latDeg << 16
	    latVal = latVal + 1000 * latMin

	    lastGPScalc = system.getTimeCounter()
	 end
	 
	 if v.funcString and v.funcString ~= "" then
	    chunk, err = load("return "..v.funcString,"","t",env)
	    
	    if err then
	       print("sensorEmulator: lua functionString load error, returning 0 - "..err)
	       result = 0
	    else
	       if chunk then
		  status, result = pcall(chunk)
		  result = result or 0
		  if not status then print("Bad status - result:", result) end
	       else
		  result = 0 
	       end
	    end
	    returnTbl.value = result
	 else
	    returnTbl.value = env.s
	 end
	 
	 -- now that funcString is applied, we can compute new min and max
	 
	 if not v.max then
	    v.max = returnTbl.value
	    returnTbl.max = v.max
	 else
	    if returnTbl.value > v.max then v.max = returnTbl.value end
	 end
	 if not v.min then
	    v.min = returnTbl.value
	    returnTbl.min = v.min
	 else
	    if returnTbl.value < v.min then v.min = returnTbl.value end
	 end
	 returnTbl.max = v.max
	 returnTbl.min = v.min

	 if returnTbl.type == 9 then
	    if returnTbl.param == 2 then
	       returnTbl.valGPS = latVal
	       returnTbl.decimals = latDecimals
	    elseif returnTbl.param == 3 then
	       returnTbl.valGPS = lonVal
	       returnTbl.decimals = lonDecimals
	    else
	       print("SHOULD NOT BE HERE!")
	    end

	 end

	 for kk,vv in pairs(returnTbl) do
	    if not sensorCache[k] then
	       table.insert(activeSensors, k)
	       sensorCache[k]={}
	    end
	    sensorCache[k][kk] = vv
	 end

	 return returnTbl
      end
   end
   return nil
end

local function telePrint()

   local text
   local ll
   local col, sec
   local k
   local font=FONT_MINI
   local ls = 15 -- line spacing
   local cs = 65 -- col spacing
   local ss = 80 -- section spacing
   local deg, min

   -- note: this code only works for "typical" sensors .. not GPS, time etc .. need
   -- to at least protect against other types or implement them properly!
   
   -- arrange into a 4 col 2 row (max) table
   
   for k=0, math.min(math.floor(#activeSensors/5), 1) do
      lcd.drawText(5, ls+ss*k,   "Unit", font)
      lcd.drawText(5, ls*2+ss*k, "Val",  font)
      lcd.drawText(5, ls*3+ss*k, "Max",  font)
      lcd.drawText(5, ls*4+ss*k, "Min",  font)
   end

   col=0
   sec=0
   for j=1,math.min(#activeSensors, 8),1 do
      k = activeSensors[j]
      if sensorCache[k] then
	 text = string.format("%s", sensorCache[k].label)
	 ll = lcd.getTextWidth(font, text)
	 lcd.drawText(cs + 12 - ll/2 + cs*col,  0+ss*sec, text, font)
	 lcd.drawText(cs + cs*col, ls+ss*sec, "("..(sensorCache[k].unit or "")..")", font)
	 if sensorCache[k].type == 5 then -- time or date
	    if sensorCache[k].decimals == 0 then -- time
	       text = string.format("%d:%02d:%02d", sensorCache[k].valHour,
				  sensorCache[k].valMin, sensorCache[k].valSec)
	    else -- date
	       text = string.format("%d-%02d-%02d", sensorCache[k].valYear,
				    sensorCache[k].valMonth, sensorCache[k].valDay)
	    end
	    lcd.drawText(cs+cs*col, ls*2+ss*sec, text, font)
	 elseif sensorCache[k].type == 9 then -- gps
	    min = (sensorCache[k].valGPS & 0xFFFF) * 0.001
	    deg = (sensorCache[k].valGPS >> 16) & 0xFF
	    if sensorCache[k].decimals == 3 or sensorCache[k].decimals == 2 then deg = -deg end
	    lcd.drawText(cs+cs*col, ls*2+ss*sec, string.format("%d° %f'", deg, min), font)	    
	 else -- other numeric
	    lcd.drawText(cs + cs*col, ls*2+ss*sec,
			 string.format("%3.1f", sensorCache[k].value or 0), font)
	    lcd.drawText(cs + cs*col, ls*3+ss*sec,
			 string.format("%3.1f", sensorCache[k].max or 0), font)
	    lcd.drawText(cs + cs*col, ls*4+ss*sec,
			 string.format("%3.1f", sensorCache[k].min or 0), font)
	 end
      end
      col=col+1
      if col > 3 then
	 col = 0
	 sec = sec + 1
      end
   end
end

--[[
local function dirTableIdxChanged(value)
   dirTableIdx = value
   system.pSave("dirTableIdx", value)
   dirName = dirTable[dirTableIdx]
   system.pSave("dirName", dirName)
   if dirName then
      system.messageBox("Initializing in App directory "..dirName, 3)
      emulator_init(dirName)
   end
end

local function initForm()

   form.addRow(2)
   form.addLabel({label="Select App Directory", width=170})
   form.addSelectbox(dirTable, dirTableIdx, true, dirTableIdxChanged)

   form.addRow(1)
   form.addLabel({label=appName.." v"..appVersion.." ("..appAuthor..")",
		  font=FONT_MINI, alignRight=true})
end
--]]

local function init()

   local ff

   --system.registerForm(1, MENU_APPS, appName, initForm)
   system.registerTelemetry(1, appName, 4, telePrint)
   
   emulator_init()
   
end


local function loop()
end

return {init=init, loop=loop, author=appAuthor, version=appVersion, name=appName}
