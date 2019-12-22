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
   return sensorTbl
end

local returnTbl


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

-- not implemented: valSec, valMin, valHour
-- not implemented: valYear, valMonth, valDay
-- not implemented valGPS

function emulator.getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator.getSensorById(ID, Param)
end

function emulator.getSensorByID(ID, Param)
   local c
   local chunk, err, status, result
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

   for _,v in ipairs(sensorTbl) do
      if v.id == ID and v.param == Param then
	 returnTbl = {}
	 returnTbl.id = v.id
	 returnTbl.param = v.param
	 returnTbl.decimals = v.decimals
	 returnTbl.type = v.type
	 returnTbl.label = v.label
	 returnTbl.unit = v.unit
	 returnTbl.valid = true
	 returnTbl.sensorName = v.sensorName
	 c=system.getInputs(v.control)
	 env.s = v.controlmin + (v.controlmax - v.controlmin) * ((c+1)/2)
	 env[v.control] = c -- can also get raw -1 to 1 by using name e.g. "P5"
	 env[string.gsub(v.control, "P", "S")] = (c+1)/2 -- and raw 0 to 1 e.g. "S5"
	 if v.auxcontrol and #v.auxcontrol > 0 then
	    for i=1,#v.auxcontrol,1 do
	       --print(v.label, i, v.auxcontrol[i], system.getInputs(v.auxcontrol[i]))
	       c = system.getInputs(v.auxcontrol[i]) -- e.g P6 = <-1..1>
	       env[v.auxcontrol[i]] = c
	       env[string.gsub(v.auxcontrol[i], "P", "S")] = (1 + c) / 2 -- e.g. S6 = <0,1> 
	    end
	 end
	 
	 env.t = system.getTimeCounter()/1000

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
	 
	 return returnTbl
      end
   end
   
   return nil
end

return emulator

--[[

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
"funcString":"s / 2 * sin(2*pi*t / ( 30*(S6+1) ) ) + s / 2 + prt('S7',S7)"
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
"controlmin":0,
"controlmax":200,
"funcString":"s / 2 * sq(t / 30) + s / 2 + s / 5 * rand() + s / 5"
},

{"id":3,"param":0,"sensorName":"", "label":"PS3(P7)"},
{"id":3,
"param":1,
"decimals":0,
"type":1,
"sensorName":"PS3(P7)",
"label":"G Force",
"unit":"g",
"control":"P7",
"controlmin":-10,
"controlmax":10,
"funcString":"abs(s)"
}

]

--]]
