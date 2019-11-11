--[[

   sensorEmulator.lua

   See sensorEmulator.txt for a full description.

   Usage: 

   Put the sourcecode file sensorEmulator.lua in the /Apps directory
   so it is available to all lua programs

   Put a copy of the sensorEmulator.jsn file into the directory for
   the lua function that is going to use it, and edit it as required
   for that lua app.

   The funcString capability is inspired by Jeti's V-sensor.lua app

   Released under MIT license by DFM 2019


--]]

local emulator={}

local sensorTbl
local sensorDir
local GPSparms
local coslat0
local lastGPScalc=0
local latVal
local lonVal
local latDecimals
local lonDecimals
local time0

--local function sign(x)
--   if x > 0 then return 1
--   elseif x < 0 then return -1
--   else return 0
--   end
--end


local function rotateXY(x, y, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (x * cosShape - y * sinShape), (x * sinShape + y * cosShape)
end

-- include this for compatibility with sensorLogEm

local didfcn = false
function emulator.startUp(fcn)
   if not didfcn then
      --print("calling fcn")
      fcn()
      didfcn=true
   end
   return false
end

function emulator.init(dir)
   
   local ans
   local dev, emflag
   
   if dir then sensorDir = dir else sensorDir = '' end
   
   dev, emflag = system.getDeviceType()
   
   ans = form.question("Use sensor emulator",
		       " Apps/" .. sensorDir .. "/sensorEmulator.jsn ?",
		       "---",3500, false, 0)
   if ans == 1 and emflag == 1 then
      print("Using Sensor Emulator")
      system.getSensors = emulator.getSensors
      system.getSensorByID = emulator.getSensorByID
      system.getSensorValueByID = emulator.getSensorValueByID
   else
      print("Using Native Sensors")
   end
end

function emulator.getSensors()

   local fg, text

   if not sensorDir then
      print("invalid sensorDir")
      return nil
   end
   
   text = "Apps/" .. sensorDir .."/sensorEmulator.jsn"
   fg = io.readall(text)
   if not fg then print("Cannot read " .. text) else
      sensorTbl=json.decode(fg)
   end

   text = "Apps/" .. sensorDir .."/sensorEmulatorGPS.jsn"
   fg = io.readall(text)
   if not fg then print("Cannot read " .. text) else
      GPSparms=json.decode(fg)
      coslat0 = math.cos(math.rad(GPSparms.lat0))
   end

   
   --[[
   print("GPSparms.lat0", GPSparms.lat0)
   print("GPSparms.lon0", GPSparms.lon0)
   print("GPSparms.rE", GPSparms.rE)
   print("GPSparms.trueDir", GPSparms.trueDir)
   print("GPSparms.xString", GPSparms.xString)
   print("GPSparms.yString", GPSparms.yString)   
   --]]

   --print("sensorTbl:")
   --for k,v in pairs(sensorTbl) do
   --   print(k,v.id, v.param, v.sensorName, v.label)
   --end

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

function emulator.getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator.getSensorById(ID, Param)
end

function emulator.getSensorByID(ID, Param)
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
      cos   = math.cos,
      tan   = math.tan,
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
   }

   if not sensorTbl then return nil end
   if not ID or not Param then return nil end
   if ID == 0 or Param == 0 then return nil end
   if system.getTimeCounter() < 0 then print("time negative") end
   for _,v in ipairs(sensorTbl) do
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
	    if v.controlmin and c.controlmax then
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

	 env.t = ((system.getTimeCounter() - time0)/1000) + GPSparms.startTime

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
	 
	 return returnTbl
      end
   end
   return nil
end

return emulator

--[[

Sample sensorEmulator.jsn

[

{"id":1,"param":0,"sensorName":"", "label":"PS1(P5)"},
{"id":1,"param":1,
"decimals":0,
"type":1,
"sensorName":"PS1(P5)",
"label":"EGT",
"unit":"°C",
"control":"P5",
"auxcontrol":["P6","P7"],
"controlmin":0,
"controlmax":800,
"funcString":"s / 2 * sin(2*pi*t / ( 30*(S7+1) ) ) + s / 2"
},
{"id":1,"param":2,
"decimals":0,
"type":1,
"sensorName":"PS1(P5)",
"label":"Foo",
"unit":"Bar",
"control":"P5",
"auxcontrol":["P6","P7"],
"controlmin":0,
"controlmax":800,
"funcString":"s / 2 * sin(2*pi*t / ( 30*(S7+1) ) ) + s / 2"
},

{"id":1,"param":3,
"decimals":0,
"type":1,
"sensorName":"PS1(P5)",
"label":"Baz",
"unit":"U",
"control":"P5",
"auxcontrol":["P6","P7"],
"controlmin":0,
"controlmax":800,
"funcString":"s / 2 * sin(2*pi*t / ( 30*(S7+1) ) ) + s / 2"
},
    
{"id":2,"param":0,"sensorName":"", "label":"PS2(P6)"},
{"id":2,
"param":1,
"decimals":0,
"type":1,
"sensorName":"PS2(P6)",
"label":"Airspeed",
"unit":"m/s",
"control":"P6",
"auxcontrol":["P7"],
"controlmin":0,
"controlmax":200,
"funcString":"s / 2 * sq(t / (30*(S7+1) ) ) + s / 2 + s / 5 * rand() + s / 5"
},

{"id":3,"param":0,"sensorName":"", "label":"MGPS"},
{"id":3,
"param":2,
"decimals":0,
"type":9,
"auxcontrol":["P5","P6","P7"],
"sensorName":"MGPS",
"label":"Latitude",
"unit":""
},
{"id":3,
"param":3,
"decimals":0,
"type":9,
"auxcontrol":["P5","P6","P7"],
"sensorName":"MGPS",
"label":"Longitude",
"unit":""
}

]

--]]
