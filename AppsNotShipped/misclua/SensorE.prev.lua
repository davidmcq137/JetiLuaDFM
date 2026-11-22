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

   If Apps/SensorE.jsn does not exist, we will try to read
   Apps/SensorEmulator.jsn

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

local appName="Sensor Emulator"
--local appShort="SensorE"
--local appDir=appShort.."/"
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

local LiFe={}
LiFe[1]={s=100.00,v=3.59}
LiFe[2]={s=95.71,v=3.32}
LiFe[3]={s=91.47,v=3.31}
LiFe[4]={s=87.09,v=3.31}
LiFe[5]={s=82.85,v=3.30}
LiFe[6]={s=78.54,v=3.30}
LiFe[7]={s=74.18,v=3.29}
LiFe[8]={s=69.92,v=3.28}
LiFe[9]={s=65.61,v=3.27}
LiFe[10]={s=61.31,v=3.27}
LiFe[11]={s=57.05,v=3.27}
LiFe[12]={s=52.74,v=3.27}
LiFe[13]={s=48.46,v=3.26}
LiFe[14]={s=44.14,v=3.26}
LiFe[15]={s=39.83,v=3.26}
LiFe[16]={s=35.55,v=3.25}
LiFe[17]={s=31.24,v=3.24}
LiFe[18]={s=26.87,v=3.23}
LiFe[19]={s=22.59,v=3.22}
LiFe[20]={s=18.24,v=3.20}
LiFe[21]={s=13.88,v=3.19}
LiFe[22]={s=9.63,v=3.17}
LiFe[23]={s=5.35,v=3.12}
LiFe[24]={s=1.01,v=2.90}

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
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

local GTbl={}

local function globalInit(i, v)
   if not GTbl[i] then
      GTbl[i] = v
   end
   return 0
end

function emulator_getSensors()

   local fg, text
   local SEjsn={}
   local initStr
   local env = {}
   local chunk, err, result, status
   
   text = "Apps/SensorE.jsn"
   fg = io.readall(text)

   if not fg then
      print("Cannot read " .. text)
      SEjsn.configDir = "Apps"
   else
      SEjsn=json.decode(fg)
   end

   text = SEjsn.configDir .. "/sensorEmulator.jsn"
   fg = io.readall(text)
   if not fg then print("Cannot read " .. text) else
      print("Sensor config: "..text)
      sensorTbl=json.decode(fg)
      initStr = sensorTbl[1].initString
      if initStr and initStr ~= "" then
	 --print("initStr", initStr)
	 env.GInit = globalInit -- put only one thing into the env .. GInit
	 chunk, err = load("return "..initStr,"","t",env)
	 if err then
	    print("sensorEmulator: lua functionString load error, returning 0 - "..err)
	    result = 0
	 else
	    if chunk then
	       status, result = pcall(chunk)
	       result = result or 0
	       if not status then
		  print("Bad status - result:", result)
	       end
	    else
	       result = 0 
	    end
	 end
	 -- print("result from initString:", result)
	 -- result contains return from initString here .. no need for it?
      end
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

local function A123Volt(SOC)

   --print("a123: SOC", SOC)
   if SOC >= LiFe[1].s then return LiFe[1].v end
   if SOC <= LiFe[#LiFe].s then return LiFe[#LiFe].v end

   for i=1, #LiFe-1 do
      if SOC >= LiFe[i+1].s and SOC <=LiFe[i].s then
	 ds = (SOC - LiFe[i+1].s) / (LiFe[i].s - LiFe[i+1].s)
	 --print("a123: ret:", LiFe[i+1].v + ds * (LiFe[i].v - LiFe[i+1].v))
	 return LiFe[i+1].v + ds * (LiFe[i].v - LiFe[i+1].v)
      end
   end
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

local function cosPerOne(T) -- cos with period 1
   local t
   t = T * math.pi * 2
   return math.cos(t)
end

local function tanPerOne(T) -- tan with period 1
   local t
   t = T * math.pi * 2
   return math.tan(t)
end

-- moved global init function up above init routine...

local function globalSet(i, v)
   GTbl[i]=v
   return v
end

local function globalRead(i, undef)
   if GTbl[i] then return GTbl[i] end
   if undef then return undef else return 0 end
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
   return emulator_getSensorByID(ID, Param)
end

local lastT = {}
local deltaT = {}

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
      s  = 0,
      t  = 0,
      dt = 0,
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
      G     = globalRead,
      GInit = globalInit,
      GSet  = globalSet,
      A123  = A123Volt,
   }

   if not sensorTbl then return nil end
   if not ID or not Param then return nil end
   if ID == 0 or Param == 0 then return nil end
   if system.getTimeCounter() < 0 then print("time negative") end
   --print(env.t, lastT, 1000*env.dt)
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
	 
	 uid = tostring(math.floor(ID))..tostring(math.floor(Param))
	 env.t = ((system.getTimeCounter() - time0)/1000)
	 if lastT[uid] then
	    deltaT[uid] = env.t - lastT[uid]
	 else
	    deltaT[uid] = 0
	 end
	 env.dt = deltaT[uid]
	 lastT[uid] = env.t
	 --if uid == "1681927210" then
	 --   print(uid, env.t, lastT[uid], env.dt)
	 --end
	 
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

	 if GPSparms and GPSparms.startTime then
	    env.t = env.t + GPSparms.startTime
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
		     if not status then
			print("Bad status - result:", result)
		     end
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
		  if not status then
		     print("Bad status - result:", result)
		     print("in funcString: "..(v.funcString or "nil"))
		  end
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

   -- arrange into a 4 col 2 row (max) table
   
   for kk=0, math.min(math.floor(#activeSensors/5), 1) do
      lcd.drawText(5, ls+ss*kk,   "Unit", font)
      lcd.drawText(5, ls*2+ss*kk, "Val",  font)
      lcd.drawText(5, ls*3+ss*kk, "Max",  font)
      lcd.drawText(5, ls*4+ss*kk, "Min",  font)
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

local function init()

   system.registerTelemetry(1, appName, 4, telePrint)
   
   emulator_init()
   
end


local function loop()
end

return {init=init, loop=loop, author=appAuthor, version=appVersion, name=appName}
