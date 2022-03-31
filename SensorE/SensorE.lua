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
      system.playFile()
      system.playNumber() 
      system.vibration()

   The capability to use lua code in the virtual sensors is inspired
   by Jeti's V-sensor.lua app

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

-- detect read or write to global .. will have to handle intentional globals at some point...

---[[
local sensorE_Global = {emulator_init=true, emulator_vibration=true, emulator_playFile=true,
		  emulator_playNumber=true, emulator_getSensors=true,
		  emulator_getSensorValueByID=true,emulator_getSensorByID=true,
		  emulator_init=true}
setmetatable(_G, {
		__newindex = function (t, n, v)
		   if not sensorE_Global[n] then
		      error("SensorE: Write to undeclared variable ".."<"..n..">", 2)
		   else
		      rawset(t, n, v)
		   end
		   
		end,
		__index = function (_, n)
		   if not sensorE_Global[n] then
		      error("SensorE: Read from undeclared variable ".."<"..n..">", 2)
		   end
		end,
})
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
local saveSwitch={}
local switchSeq
local geo = {}
local fieldnames = {}
local fieldIdx

local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
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

local function timeSequencer(T, seq)
   local t, tn, ti
   t = T % 1
   if seq and #seq ~= 0 then
      tn = 1 / #seq
      ti = math.floor(t / tn)
   else
      return 0
   end
   return(seq[ti+1])
end

local function switchSequencer(sw, seq)
   local s
   if #seq < 1 then return 0 end
   s = system.getInputs(sw)
   if not s then return 0 end
   if s ~= saveSwitch[sw] then
      saveSwitch[sw] = s
      switchSeq = switchSeq + 1
      if switchSeq > #seq then switchSeq = 1 end
   end
   return seq[switchSeq]
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

local function switch(sw)
   return system.getInputs("S"..sw)
end

local function propCtlP(t, min, max)
   -- if min and max defined, then range is min to max
   -- if min only defined, then range is 0 to min
   
   -- if no min and no max then -1 to 1
   -- print("propCtlP", t, min, max)
   if min and max then
      return min + (max - min) * (1 + system.getInputs("P"..t)) / 2
   elseif min then
      return min*(system.getInputs("P"..t) + 1)/2
   else
      return system.getInputs("P"..t)
   end
end

local function propCtlO(t, min, max)
   -- if min and max defined, then range is min to max
   -- if min only defined, then range is 0 to min
   -- if no min and no max then -1 to 1
   --print(t,min,max)
   if min and max then
      --print(min + (max - min) * (1 + system.getInputs("O"..t)) / 2)
      return min + (max - min) * (1 + system.getInputs("O"..t)) / 2
   elseif min then
      return min*(system.getInputs("O"..t) + 1)/2
   else
      return system.getInputs("O"..t)
   end
end

local function fieldIdxChanged(value)
   fieldIdx = value
   if GPSparms and geo then
      GPSparms.lat0 = geo.fields[fieldIdx].lat
      GPSparms.lon0 = geo.fields[fieldIdx].long
      GPSparms.trueDir = geo.fields[fieldIdx].runway.trueDir
   end
end


local function initForm()
   form.addRow(2)
   form.addLabel({label="Select Field for GPS Origin", width=220})
   form.addSelectbox(fieldnames, fieldIdx, true, fieldIdxChanged)
end


--[[

add'l functions to consider

not implemented: valSec, valMin, valHour
not implemented: valYear, valMonth, valDay

date/time would be easy .. derive from system clock
details on bit packing for date and time are in sensorLogEm.lua

--]]

local env = {
   t  = 0,
   dt = 0,
   P1  = (function(a1,a2) return propCtlP(1,a1,a2)  end),
   P2  = (function(a1,a2) return propCtlP(2,a1,a2)  end),
   P3  = (function(a1,a2) return propCtlP(3,a1,a2)  end),
   P4  = (function(a1,a2) return propCtlP(4,a1,a2)  end),
   P5  = (function(a1,a2) return propCtlP(5,a1,a2)  end),
   P6  = (function(a1,a2) return propCtlP(6,a1,a2)  end),
   P7  = (function(a1,a2) return propCtlP(7,a1,a2)  end),
   P8  = (function(a1,a2) return propCtlP(8,a1,a2)  end),
   O1  = (function(a1,a2) return propCtlO(1,a1,a2)  end),
   O2  = (function(a1,a2) return propCtlO(2,a1,a2)  end),
   O3  = (function(a1,a2) return propCtlO(3,a1,a2)  end),
   O4  = (function(a1,a2) return propCtlO(4,a1,a2)  end),
   O5  = (function(a1,a2) return propCtlO(5,a1,a2)  end),
   O6  = (function(a1,a2) return propCtlO(6,a1,a2)  end),
   O7  = (function(a1,a2) return propCtlO(7,a1,a2)  end),
   O8  = (function(a1,a2) return propCtlO(8,a1,a2)  end),
   O9  = (function(a1,a2) return propCtlO(9,a1,a2)  end),
   O10 = (function(a1,a2) return propCtlO(10,a1,a2)  end),
   O11 = (function(a1,a2) return propCtlO(11,a1,a2)  end),
   O12 = (function(a1,a2) return propCtlO(12,a1,a2)  end),
   O13 = (function(a1,a2) return propCtlO(13,a1,a2)  end),
   O14 = (function(a1,a2) return propCtlO(14,a1,a2)  end),
   O15 = (function(a1,a2) return propCtlO(15,a1,a2)  end),
   O16 = (function(a1,a2) return propCtlO(16,a1,a2)  end),
   O17 = (function(a1,a2) return propCtlO(17,a1,a2)  end),
   O18 = (function(a1,a2) return propCtlO(18,a1,a2)  end),
   O19 = (function(a1,a2) return propCtlO(19,a1,a2)  end),
   O20 = (function(a1,a2) return propCtlO(20,a1,a2)  end),
   O21 = (function(a1,a2) return propCtlO(21,a1,a2)  end),
   O22 = (function(a1,a2) return propCtlO(22,a1,a2)  end),
   O23 = (function(a1,a2) return propCtlO(23,a1,a2)  end),
   O24 = (function(a1,a2) return propCtlO(24,a1,a2)  end),
   SA  = (function() return switch("A") end),
   SB  = (function() return switch("B") end),
   SC  = (function() return switch("C") end),
   SD  = (function() return switch("D") end),
   SE  = (function() return switch("E") end),
   SF  = (function() return switch("F") end),
   SG  = (function() return switch("G") end),
   SH  = (function() return switch("H") end),
   SI  = (function() return switch("I") end),
   SJ  = (function() return switch("J") end),  
   print    = print,
   tonumber = tonumber,
   tostring = tostring,
   require  = require,
   pairs    = pairs,
   ipairs   = ipairs,
   math     = math,
   table    = table,
   string   = string,
   sin      = sinPerOne,
   cos      = cosPerOne,
   tan      = tanPerOne,
   tri      = triangleWave,
   sq       = squareWave,
   tseq     = timeSequencer,
   swseq    = switchSequencer,
}

function emulator_init()

   local dev, emflag
   
   dev, emflag = system.getDeviceType()
   
   if emflag == 1 then      
      system.getSensors = emulator_getSensors
      system.getSensorByID = emulator_getSensorByID
      system.getSensorValueByID = emulator_getSensorValueByID
      system.playFile = emulator_playFile
      system.playNumber = emulator_playNumber
      system.vibration = emulator_vibration
      --system.messageBox("SensorE: Using emulated sensors", 3)
   else
      --system.messageBox("SensorE: Using native sensors", 3)
   end
end

function emulator_vibration(lr, prof)
   local lrText, i
   local profText = {"Long Pulse", "Short Pulse", "2x Short Pulse", "3x Short Pulse", "Other"}
   if lr then lrText = "Right" else lrText = "Left" end
   if prof < 1 or prof > 5 then
      i = 5
   else
      i = prof
   end
   print(string.format("SensorE - vibration: %s" .. " stick - Profile: %s", lrText, profText[i]))
end

function emulator_playFile(fn, typ)
   local ss
   if typ == AUDIO_BACKGROUND then
      ss = "AUDIO_BACKGROUND"
   elseif typ == AUDIO_IMMEDIATE then
      ss = "AUDIO_IMMEDIATE"
   elseif typ == AUDIO_QUEUE then
      ss = "AUDIO_QUEUE"
   else
      ss = "Type Unknown: " .. (typ or "-nil-")
   end
   print(string.format("SensorE - playFile: <%s> type: %s", fn, ss))
end

function emulator_playNumber(val, dec, unit, lab)
   local fs, rr, vf

   
   if dec == 0 then
      fs = "%d"
   elseif dec == 1 then
      fs = "%.1f"
   elseif dec == 2 then
      fs = "%.2f"
   else -- not valid
      fs = "%f"
      rr = false
   end
   if val then
      vf = string.format(fs, val)
   else
      vf = "(nil)"
   end
   print(string.format
	 ("SensorE - playNumber: %s unit: %s label: %s", vf, unit, lab))
   return rr
end

function emulator_getSensors()

   local fg, text
   local SEjsn={}
   local initStr
   local chunk, err, result, status
   
   text = "Apps/SensorE.jsn"
   fg = io.readall(text)

   if not fg then
      print("Cannot read " .. text)
      SEjsn.configDir = "Apps"
   else
      SEjsn=json.decode(fg)
   end

   switchSeq = 1
   for c in string.gmatch("ABCDEFGHIJ",".") do
      saveSwitch["S"..c] = system.getInputs("S"..c)
   end
   
   text = SEjsn.configDir .. "/sensorEmulator.jsn"
   fg = io.readall(text)
   if not fg then print("Cannot read " .. text) else
      print("Sensor config: "..text)
      sensorTbl=json.decode(fg)
      initStr = sensorTbl[1].initString
      if initStr and initStr ~= "" then
	 --print("initStr", initStr)
	 chunk, err = load(initStr,"initString","t",env)
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
      print("GPS Config: "..text)
      --print("lat0:", GPSparms.lat0)
      --print("lon0:", GPSparms.lon0)
   end

   if GPSparms then
      for i=1, #geo.fields do
	 if  math.abs(geo.fields[i].lat  - GPSparms.lat0) < 1/60
	 and math.abs(geo.fields[i].long - GPSparms.lon0) < 1/60 then
	    fieldIdx = i
	 end
      end
   end
   
   time0 = system.getTimeCounter()
   
   return sensorTbl
end


function emulator_getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator_getSensorByID(ID, Param)
end

local lastT = {}
local deltaT = {}

function emulator_getSensorByID(ID, Param)
   local c
   local chunk, err, status, result
   local expResult, funcResult
   local returnTbl
   local xCart, yCart
   local lat, lon
   local latDeg, latFrac, latMin
   local lonDeg, lonFrac, lonMin
   local GPSdt
   local uid
   
   -- print("getSensorByID")
   -- for some reason json decode returns two chars for the degree symbol (code 176)
   -- detect that and correct it
   local degSym1 = string.char(176)   
   local degSym2 = string.char(194, 176)
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
	 returnTbl.unit = string.gsub(v.unit, degSym2, degSym1)
	 returnTbl.valid = true
	 returnTbl.sensorName = v.sensorName
	 uid = tostring(math.floor(ID)).."-"..tostring(math.floor(Param))
	 env.t = ((system.getTimeCounter() - time0)/1000)
	 if lastT[uid] then
	    deltaT[uid] = env.t - lastT[uid]
	 else
	    deltaT[uid] = 0
	 end
	 env.dt = deltaT[uid]
	 lastT[uid] = env.t
   
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
		     if not status then
			print("Bad status - result:", result)
			print("GPSparms.yString: ", GPSparms.yString)
		     end
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
	       --print("GPSparms.trueDir:", GPSparms.trueDir)
	       xCart, yCart = rotateXY(xCart, yCart, math.rad(360-GPSparms.trueDir))
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

	 --
	 if v.funcString then
	    v.luaExp = v.funcString
	    print("funcString changed to luaExp - please update jsn file")
	 end

	 funcResult = nil
	 expResult  = nil
	 
	 if v.luaFunc and v.luaFunc ~= "" then
	    chunk, err = load(v.luaFunc,"luaFunc: "..uid,"t",env)
	    
	    if err then
	       print("sensorEmulator: luaFunc load error, returning 0 - "..err)
	       funcResult = 0
	    else
	       if chunk then
		  status, funcResult = pcall(chunk)
		  if not status then
		     print("Bad status - result:", funcResult)
		     print("in luaFunc: "..(v.luaFunc or "nil"))
		     funcResult = nil
		  end
	       end
	    end
	 end

	 if v.luaExp and v.luaExp ~= "" then
	    chunk, err = load("return "..v.luaExp,"luaExp: "..uid,"t",env)
	    
	    if err then
	       print("sensorEmulator: lua load error, returning 0 - "..err)
	       expResult = 0
	    else
	       if chunk then
		  status, expResult = pcall(chunk)
		  if not status then
		     print("Bad status - result:", expResult)
		     print("in luaExp: "..(v.luaExp or "nil"))
		     expResult = nil
		  end
	       end
	    end
	 end

	 -- typically we will get a value from luaExp since we concatenate the luaExp string
	 -- with "return " .. e.g. "return S1(0,-4000)"
	 -- and will use luaFunc for generic lua code that when evaluated returns nil
	 -- e.g. "a=a+1". But can also specify a return value from luaFunc
	 -- e.g. "a=a+1; return S1(a,100)"
	 -- but warn user if they try to return values from both .. if they do that we take the
	 -- luaFunc return value as the result
	 
	 if expResult then -- take luaExp result if exists
	    returnTbl.value = expResult
	 elseif funcResult then -- if not fall back on luaFunc result if it exists
	    returnTbl.value = funcResult
	 else
	    returnTbl.value = 0 -- if no result return 0
	 end

	 if expResult and funcResult then
	    print("Warning -- Got return values from both luaFunc and luaExp")
	    print("Using luaExp result from "..v.luaExp)
	 end
	 
	 -- now that luaExp/luaFunc is applied, we can compute new min and max
	 
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

local function varPrint()

   -- this is a very basic tele window to show the lua variables active in env{}
   -- just shows them in a 2x9 line matrix, only shows the first 18
   -- needs some further work to more intelligently handle numbers and tables
   -- from a formatting/space point of view and possibly select subsets and sort order
   
   local col, line
   local ls = 15 -- line spacing
   local cs = 140 -- col spacing
   local font = FONT_MINI
   local full = false
   
   line=0
   col=0
   
   for k,v in pairs(env) do
      if type(v) == "number" and not full then
	    lcd.drawText(20+cs*col, 6+ls*line,
			 string.format("%s = %4.2f", k, v), font)
	    col = col + 1
	    if col > 1 then
	       col = 0
	       line = line + 1
	    end
	    if line > 9 then full = true end
	    
      elseif type(v) == "table" then
	 for i=1, #v do
	    if not full then
	       lcd.drawText(20+cs*col, 6+ls*line,
			    string.format("%s[%d] = %4.2f", k, i, v[i]), font)
	    col = col + 1
	    if col > 1 then
	       col = 0
	       line = line + 1
	    end
	    if line > 9 then full = true end
	    end
	 end
      end
   end
end

local function telePrint()

   -- shows the first (up to) 8 tele sensors with their associated data
   -- very basic, needs a way select from a longer list
   
   local text
   local ll
   local col, sec
   local k
   local font = FONT_MINI
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

   local fg
   
   fieldIdx = 0
   fg = io.readall("Apps/SensorFields.jsn")
   if fg then
      geo = json.decode(fg)
      if geo then
	 for i = 1, #geo.fields do
	    fieldnames[i] = geo.fields[i].name
	 end
      end
   else
      print("Info: Cannot open Apps/SensorFields.jsn")
   end
   
   if not fg then
      print("Info: SensorFields.jsn not decoded - creating default")
      geo.fields={}
      geo.fields[1] =  {lat=39.147398, long=-77.337639,runway={}}
      geo.fields[1].runway.trueDir=347.5
      fieldnames[1] = "DCRC Walt Good Field"
   else
      print("SensorFields.jsn decoded")
   end

   system.registerTelemetry(1, appName.." Sensors", 4, telePrint)
   system.registerTelemetry(2, appName.." Variables", 4, varPrint)
   system.registerForm(1, MENU_APPS, "Sensor Emulator", initForm, nil, nil)
   
   --emulator_init()
   
end


local function loop()
   if appVersion ~= "1.00" then
      --print("ERROR!!!!!") -- WTF??
   end
end

emulator_init()

return {init=init, loop=loop, author=appAuthor, version=appVersion, name=appName}
