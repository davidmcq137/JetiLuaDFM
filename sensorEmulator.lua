--[[

   sensorEmulator.lua

   This module is intended to be used with the Jeti DC/DS-24
   emulator. It reads a file (sensorEmulator.jsn) that defines a set
   of "pseudosensors" that can be created from the proportional
   controls (e.g. sliders) in the emulator. You can define a simple
   linear range of telemetry signal values that behave as standard
   telemetry sensors as the sliders move. A sample JSON file is
   included below.
   
   For more complex sensor behavior, you can specify a function string
   (funcString) in the jsn file for each sensor which can be any valid
   lua expression that is executed each time the sensor is read. The
   environment in which that string is evaluated by the lua
   interpreter is set up so that variable name s is the raw sensor
   value, t is the system time in seconds (t = system.getTimeCounter()
   / 1000), and most of the lua math library is available - without
   the "math." prefix (see code below .. table env). Also available
   are a triangle wave function with a period of 1s - tri() and a square
   wave function with a period of 1s - sq(). The triangle and square
   wave functions have an amplitude of +/-1, as do sin and cos which
   have a period of 2*pi seconds as usual.

   For example "funcString": "s*sin(2*pi*t/10)" gives a 10 second
   period sine wave whose amplitude is set by the slider. Saying this
   another way, you are creating a function, call if f where
   pseudosensor output = f(s,t) with s = slider value and t = system
   time in seconds and funcString defines the body of the function.

   Future enhancements could be the addition of switches to emulate
   the behavior of table entry <sensor.valid>. Currently we always
   return sensor.value = true.

   At present, several less common table entries (see source code) are
   not implemented e.g. date and time and GPS. 

   The module file sensorEmulator.lua is intended to be in the /Apps
   directory along with the lua source files. The sensorEmulator.jsn
   file is expected to be lua-program-specific so it resides in the
   lua program's own directory, e.g. Apps/DFM-Smoke/sensorEmulator.jsn
   for the lua program /Apps/DFM-Smoke.lua

   Usage: 

   Put the sourcecode file sensorEmulator.lua in the /Apps directory
   so it is available to all lua programs

   Put a copy of the sensorEmulator.jsn file into the directory for
   the lua function that is going to use it, and edit it as required
   for that lua app.

   By putting the sensorEmulator.jsn file into the app's own
   directory each app can define its own sensor names, ranges, etc

   To use the sensor emulator, add to your init() function, assuming
   your app is called DFM-Test.lua, the following code:

   -- *** code snippet to add to init() ***

   local pcallOK, emulator

   pcallOK, emulator = pcall(require, "sensorEmulator")
   if pcallOK and emulator then emulator.init("DFM-Test") end
   
   -- *** end of code snippet to add to init() ***
   
   This makes sure the emulator init function is only called if the
   <require> was done to load the emulator module. 

   You can put these "require" lines where you like in init(), but it
   must be before you call system.getSensors(), which is also
   typically called from init().

   Upon startup in the emulator of a lua program that includes the
   module, it asks if you want to use the pseudosensors or not,
   default if no key pressed is "no".

   If you press "yes" and do elect to use the module, the
   emulator.init() routine automatically changes the system function
   calls for system.getSensors(), system.getSensorById() and
   system.getSensorValueById to instead be handled by the emulator
   module functions with the pseudosensor functionality. Your
   sourcecode does not change and still has the calls to the system
   names in any case which is very convenient for debugging.

   The <require> statements and call to emulator.init() can be left in
   production code. When calling emulator.init() on the actual
   transmitter, it returns immediately, does not read the JSON file
   and leaves the system routines in place. The sensorEmulator.lua and
   .jsn files are not intended to be put on the Tx .. they would not
   execute anyway...

   The funcString capability is inspired by Jeti's V-sensor.lua app

   Released under MIT license by DFM 2019

MIT License

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


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

-- note: need to implement max and min properly
-- not implemented: valSec, valMin, valHour
-- not implemented: valYear, valMonth, valDay
-- not implemented valGPS

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
   }

   for _,v in ipairs(sensorTbl) do
      if v.id == ID and v.param == Param then
	 --print("v.id, v.param, v.control:", v.id, v.param, v.control)
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
	 env.t = system.getTimeCounter()/1000

	 --print(v.funcString, env.s, env.t)
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
		  result = 0 -- hmm what else to do
	       end
	    end
	    --print("result", result)
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

Sample sensorEmulator.jsn file

[
{"id":1,"param":0,"sensorName":"", "label":"PS1(P5)"},
{"id":1,"param":1,"decimals":0,"type":1,"sensorName":"PS1(P5)","label":"EGT","unit":" ","control":"P5", "controlmin":0, "controlmax":1000,"value":0, "funcString": "s*sin(2*pi*t/10)+s"},
{"id":2,"param":0,"sensorName":"", "label":"PS2(P6)"},
{"id":2,"param":1,"decimals":0,"type":1,"sensorName":"PS2(P6)", "label":"Airspeed","unit":" ", "control":"P6", "controlmin":0, "controlmax":200,"value":0},
{"id":3,"param":0,"sensorName":"", "label":"PS3(P7)"},
{"id":3,"param":1,"decimals":0,"type":1,"sensorName":"PS3(P7)","label":"Altitude","unit":" ", "control":"P7", "controlmin":0, "controlmax":400,"value":0}
]

--]]
