--[[

   sensorEmulator.lua

   This module is intended to be used with the Jeti DC/DS-24
   emulator. It reads a file (sensorEmulator.jsn) that defines a set
   of "pseudosensors" that can be created from the proportional
   controls (e.g. sliders) in the emulator. You can define a simple
   linear range of telemetry signal values that behave as standard
   telemetry sensors as the sliders move. A sample JSON file is
   included below.
   
   Future enhancements might include other than linear outputs,
   e.g. polynomial or exponential, time-dependent waveforms (e.g. sine,
   triangle, squarewave with settable period and amplitude). Other
   enhacements could be the addition of switches to emulate the behavior
   of table entry sensor.valid

   At present, several less common table entries (see source code) are
   not implemented e.g. date and time and GPS. Also, min and max
   return 0 and should be properly implemented at some point.

   The module file sensorEmulator.lua is intended to be in the /Apps
   directory along with the lua source files. The sensorEmulator.jsn
   file is expected to be lua-program-specific so it resides in the
   lua program's own directory, e.g. Apps/DFM-Smoke/sensorEmulator.jsn
   for the lua program /Apps/DFM-Smoke.lua

   Usage: At the top of your source file (just below all the "global"
   locals) include the lines:

   local emulator
   emulator = require("./sensorEmulator")

   Then, in the init() routine for your lua code, just add this line:

   if emulator then emulator.init("DFM-Smoke") end

   This makes sure the emulator init function is only called if the
   <require> was done to load the emulator module

   You can put this line where you like, but do be sure it is before
   you call system.getSensors(), which is also typically called from
   init()

   Upon startup in the emulator of a lua program that includes the
   module, it asks if you want to use the pseudosensors or not,
   default if no key pressed is "no".

   If you press "yes" and do elect to use the module, the
   emulator.init() routine automatically changes the system function
   calls for system.getSensors() and system.getSensorById() to instead
   be handled by the emulator module functions with the pseudosensor
   functionality. Your sourcecode does not change and still has the
   calls to the system names in any case which is very convenient for
   debugging.

   The <require> statements and call to emulator.init() can be left in
   production code. When calling emulator.init() on the actual
   transmitter, it returns immediately, does not read the JSON file
   and leaves the system routines in place.

   Released under MIT license by DFM 2019

--]]

local emulator={}

local sensorTbl
local sensorDir

--[[
function emulator.check(sd)
   
   -- If on emulator, see if we should emulate the telem sensors from a jsn file
   -- only return true if on the emulator and the lua and jsn files exist
   
   local dev, emflag
   local efg, jfg

   sensorDir = sd
   dev, emflag = system.getDeviceType()

   if emflag == 1 then
      local efg = io.open("Apps/sensorEmulator.lua", "r")
      local jfg = io.open("Apps/"..sensorDir.."/sensorEmulator.jsn", "r")
      print("efg, jfg:", efg, jfg)
      if efg then
	 io.close(efg)
	 if jfg then
	    io.close(jfg)
	    return true
	 end
      end
   end
   return false
end
--]]

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

function emulator.getSensorByID(ID, Param)
   local c
   --print("emulator.getSensorById", ID, Param)
   for k,v in ipairs(sensorTbl) do
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
	 returnTbl.value = v.controlmin + (v.controlmax - v.controlmin) * ((c+1)/2)
	 returnTbl.min = 0
	 returnTbl.max = 0
	 --print("ctl, value, valid:", returnTbl.control, returnTbl.value, returnTbl.valid)
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
{"id":1,"param":1,"decimals":0,"type":1,"sensorName":"PS1(P5)","label":"EGT","unit":" ","control":"P5", "controlmin":0, "controlmax":1000,"value":0},
{"id":2,"param":0,"sensorName":"", "label":"PS2(P6)"},
{"id":2,"param":1,"decimals":0,"type":1,"sensorName":"PS2(P6)", "label":"Airspeed","unit":" ", "control":"P6", "controlmin":0, "controlmax":200,"value":0},
{"id":3,"param":0,"sensorName":"", "label":"PS3(P7)"},
{"id":3,"param":1,"decimals":0,"type":1,"sensorName":"PS3(P7)","label":"Altitude","unit":" ", "control":"P7", "controlmin":0, "controlmax":400,"value":0}
]

--]]
