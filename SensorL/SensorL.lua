--[[

SensorL.lua

Read a Jeti log file and replay selected sensor data via sensor
emulation in software.

This is a lua app, usable only on the Jeti DC/DS-24 emulator, which
creates a replacement for all the system telemetry routines that
return sensor readings from a log file. This applies to all other lua
apps running with it. It replays the log file at "real" speed .. the
same time scale as the recorded logfile.

System routines replaced are:

      system.getSensors()
      system.getSensorByID()
      system.getSensorValueByID()
      system.getTxTelemetry()

Note as of 10/8/2021 .. no need for prior gymnastics on spreading out
the init over the first calls to the app's loop() .. just the call to
getSensors() is fine .. all processing for the log header reading is
all handled inside the emulator's init code. This is possible because
Jeti gave us a new API to turn off the "kill" for too much CPU that
was happening sometimes on large log headers. Since this is only
intended for the emulator, no issue turning that feature off during
log file header reading.

Since this sensor emulator is meant to be used only on the DC/DS-24
emulator, all the config information is in the configuration json file
Apps/SensorL/SensorL.jsn where it is assumed it is easy to edit/change
the file. A sample SensorL.jsn is included below. Place in SensorL.jsn
the file the name of the log file to process and the names of the
telemetry log variables you want to make available (formatted as shown
with sensor name and label and spaces replaced by underscores).

Note that in some setups there can be duplicate names on telem sensor
texts (IDs are still unique of course) and in these cases we will
disambiguate the names with (1) (2) etc and if we want to use those
telem signals, they would have to be referred to by those names in the
jsn file.

Todo/ideas:

1) Consider a "speed up" option to playback at faster than real
time. Quick experiment shows that if we run as fast as we can we go
about 3x speed .. so that's the limit. So maybe it's just realtime or
max speed .. 1x or 3x. In the experiment, we missed all the telem
signals since we did not speed up the 200 ms sampling time of the main
app's telemetry read .. so maybe this is not so useful... Update: we
can zoom ahead a lot faster than that .. I figured that out when
implementing fast forward, so it should be possible to put a fast
forward feature in. Perhaps since this is meant only for the emulator,
we can use the controls (e.g. P1 or P3) or the <<left and >> right
buttons .. e.g.  <<left is a fast rewind (would require marking file
position and re-positioning file like we are already doing on log
header reading .. perhaps every second save the file pointer and jump
back n seconds?) >>right is fast foward, and enter is pause? hmm
.. that sounds like fun. Could even do multiple >> or << pushes to
speed up 3x 10x 30x etc.

2) perhaps if we want to also playback switch actuation (or maybe even
control actuation?) we can create in the app to be tested a log entry
for each desired control, then identify those switches/controls in the
SensorL.jsn file as controls so we can watch them, and actuate them
during playback.

3) we should check for the signal loss (device code all 0s) and
perhaps print warning

4) maybe there is a way to do a user menu vs. a json file for setup to
make it easier for non-experts to use .. put in a menu, select a log
file, write out a new json file, prompt user to "reload lua" should be
good...

5) Most log files have a long period of inactivity with engine startup
etc .. would be good to "zoom ahead" to the actual flight portion
DONE: see fastForward


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

-- code to detect writing or reading of globals

local sensorE_Global = {emulator_init=true, emulator_vibration=true, emulator_playFile=true,
		  emulator_playNumber=true, emulator_getSensors=true,
		  emulator_getSensorValueByID=true,emulator_getSensorByID=true,
		  emulator_getPosition=true, emulator_getTxTelemetry=true,
		  emulator_init=true}

setmetatable(_G, {
		__newindex = function (t, n, v)
		   if not sensorE_Global[n] then
		      error("SensorE: Write to undeclared variable "..n, 2)
		   else
		      rawset(t, n, v)
		   end
		   
		end,
		__index = function (_, n)
		   if not sensorE_Global[n] then
		      error("SensorE: Read from undeclared variable "..n, 2)
		   end
		end,
})


local appShort="SensorL"
local appName="Sensor LogFile Emulator"
local appDir="Apps/" .. appShort .. "/"
local appVersion="1.00"
local appAuthor="DFM"

local sensorTbl={}

-- "globals" for log reading

local fd
local rlhCount=0
local rlhDone=false
local logSensorByID = {}
local logSensorByName = {}
local allSensors = {}
local logItems={}
local logTime0
local sysTime0
local config = {}
local lastTimeBlock = 0
local uniqueSensorNames={}

--local logHeaderPos
--local lastLogHeaderPos

local sensorCache={}
local activeSensors={}
--local selKeysStr

--local startUpTime
local dev, emFlag

local egsCPU
local egsIdCPU

logItems.cols={}
logItems.vals={}

local Rx1ID, Rx1QParam, Rx1A1Param, Rx1A2Param, Rx1UParam
local Rx2ID, Rx2QParam, Rx2A1Param, Rx2A2Param, Rx2UParam
-- note no "Q" for RxB
local RxBID, RxBA1Param, RxBA2Param, RxBUParam

-- Utility functions --------------------------------------

local function split(str, ch)
   local index, acc = 0, {}
   while index do
      local nindex = string.find(str, ch, 1+index)
      if not nindex then
	 table.insert(acc, str:sub(index))
	 break
      end
      table.insert(acc, str:sub(index, nindex-1))
      index = 1+nindex
   end
   return acc
end

------------------------------------------------------------

-- sensor name is human readable
-- e.g. CTU_Altitude
local function sensorFullName(device_name, param_name)
   return device_name .. "_" .. param_name 

end

------------------------------------------------------------

-- sensor ID is machine readable
-- e.g. 60025613 (13 concat to 600256)
-- note that this assumes the devID and devParam are left as strings!
local function sensorFullID(devID, devParm)
   return tostring(math.floor(devID))..tostring(math.floor(devParm))
end

------------------------------------------------------------

-- The Jeti logfile stores the device ID as two concatenated strings
-- one for the upper 16 bit value and one for the lower 16 bit values of the ID
-- e.g. device ID 4204600256 might show up in the log file. Jeti Studio
-- shows it as 42046:00256. In hex this would be A43E:0100
-- but there is an endian issue .. on the Intel Linux system this should
-- really be 0100A43E. So isolate the two 5-char strings, convert to numbers
-- swap and reconstruct the ID in the right order (16819262 in this case)
-- dealing with the native order causes headaches with ints greater than 2^31

local function toID(logstr)
   return (tonumber(string.sub(logstr, 6))<<16) +  tonumber(string.sub(logstr, 1, 5))
end

------------------------------------------------------------

local function readLogHeader()

   local uid
   local iid
   local hdr
   local logData
   local logHeaderPos = 0
   local lastHeaderPos = 0
   local needHead=true
   
   if not fd then return false end
   if rlhDone then return rlhDone end   

   -- read a large enough number of bytes so that we are sure we have the whole header
   -- it is typically < 3K even in complex models...


   -- NOTE: Jeti seems to have added a second # file at the top of the log file
   -- that contains the time/date info .. I hacked it below but best to fix it properly.
   
   logData = io.read(fd, 8192)

   local icnt=0
   
   for ll in string.gmatch(logData, "[^\r\n]+") do
      icnt = icnt + 1
      --print("icnt, ll", icnt, ll)
      --print("icnt, CPU:", icnt, system.getCPU())
      logItems.line = ll
      lastHeaderPos = logHeaderPos
      logHeaderPos = logHeaderPos + #ll + 1
      if not ll then
	 print("SensorL: Read eror on log header file")
	 rlhDone=true
	 return rlhDone
      end
      --if needHead and string.find(ll, "#") == 1 then
      if string.find(ll, "#") == 1 then	 
	 print("SensorL: Header line: "..ll)
	 --needHead = false
	 goto continue
      end

      logItems.cols={}
      for w in string.gmatch(logItems.line, "[^;]+") do
	 --print(">", w)
	 table.insert(logItems.cols, w)
      end
      
      logItems.timestamp = tonumber(logItems.cols[1])
      --print("logItems.timestamp", logItems.timestamp)
      -- if not logItems.timestamp then -- this is the hack .. the second # line triggers this
      -- 	 print("tonumber of timestamp is nil", logItems.cols[1])
      -- 	 goto continue
      -- end
      if logItems.timestamp ~= 0 then -- this must be the first real data line...
	 rlhDone = true
	 logTime0 = logItems.timestamp
	 sysTime0 = system.getTimeCounter()
	 io.seek(fd, lastHeaderPos)
	 return rlhDone
      end
      
      if logItems.cols[3] == "0" then
	 logItems.sensorName=logItems.cols[4]
	 local stem
	 for i=1,10,1 do -- defensive .. prob won't have 10 dupes .. but don't iterate forever
	    if uniqueSensorNames[logItems.sensorName] then
	       if i == 1 then stem = logItems.sensorName end
	       print("SensorL: Duplicate sensor name ", stem)
	       logItems.sensorName = stem .. "(" .. i .. ")"
	    else
	       if i ~= 1 then
		  print("SensorL: Using " .. logItems.sensorName .." for " .. logItems.cols[2])
	       end
	       uniqueSensorNames[logItems.sensorName] = true
	       break
	    end
	 end
      else
	 --print("prior:", logItems.cols[4])
	 logItems.cols[4] = string.gsub(logItems.cols[4], " ", "_")
	 --print("Post:", logItems.cols[4])
	 logItems.sensorName = string.gsub(logItems.sensorName, " ", "_")
	 --print("logItems.sensorName before uid call", logItems.sensorName)
	 uid = sensorFullName(logItems.sensorName, logItems.cols[4])
	 --print("$$$", logItems.sensorName, logItems.cols[4])
	 table.insert(allSensors, uid)
	 --print("uid, c.sS", uid, config.selectedSensors[uid])
	 --if selectedSensors is not present as a key in the json file then
	 --read all sensors. if selectedSensors is present, only read the telemetry
	 --values specified
	 if not config.selectedSensors or config.selectedSensors[uid] then
	    --logSensorByName[uid] = {}
	    iid = sensorFullID(toID(logItems.cols[2]), tonumber(logItems.cols[3]) )
	    logSensorByID[iid] = {}
	    --logSensorByName[uid].label = logItems.cols[4]
	    logSensorByID[iid].label = logItems.cols[4]	    
	    --logSensorByName[uid].sensorName = logItems.sensorName
	    logSensorByID[iid].sensorName = logItems.sensorName
	    --logSensorByName[uid].unit = logItems.cols[5]
	    logSensorByID[iid].unit = logItems.cols[5]
	    --logSensorByName[uid].id = toID(logItems.cols[2])
	    logSensorByID[iid].id = toID(logItems.cols[2])
	    --logSensorByName[uid].param = tonumber(logItems.cols[3])
	    logSensorByID[iid].param = tonumber(logItems.cols[3])
	    logSensorByName[uid] = logSensorByID[iid]
	 end
      end
      ::continue::
   end
   return rlhDone
end

------------------------------------------------------------
local first = true

local function readLogTimeBlock()

   local sn, sl, sf
   
   logItems.timestamp = logItems.cols[1]

   -- read the time block (consecutive group of lines with same time stamp)
   -- load the data into the results table logSensorByID
   
   repeat
      logItems.deviceID = toID(logItems.cols[2])
      if logItems.deviceID ~= 0 then -- if logItems.deviceID == 0 it's a message
	 for i = 3, #logItems.cols, 4 do
	    sf = sensorFullID(toID(logItems.cols[2]), tonumber(logItems.cols[i]))
	    if logSensorByID[sf] then
	       sn = logSensorByID[sf].sensorName
	       sl = logSensorByID[sf].label
	       if not config.selectedSensors or config.selectedSensors[sn.."_"..sl] then
		  logSensorByID[sf].value = tonumber(logItems.cols[i+3])
		  logSensorByID[sf].valGPS = tonumber(logItems.cols[i+3])		  
		  logSensorByID[sf].decimals = tonumber(logItems.cols[i+2])
		  logSensorByID[sf].type = tonumber(logItems.cols[i+1])
		  logSensorByID[sf].max = logSensorByID[sf].max or logSensorByID[sf].value
		  if logSensorByID[sf].value > logSensorByID[sf].max then
		     logSensorByID[sf].max = logSensorByID[sf].value
		  end
		  logSensorByID[sf].min = logSensorByID[sf].min or logSensorByID[sf].value
		  if logSensorByID[sf].value < logSensorByID[sf].min then
		     logSensorByID[sf].min = logSensorByID[sf].value
		  end
		  logSensorByID[sf].lastUpdate = system.getTimeCounter()
	       end
	    end
	 end
      else
	 system.messageBox(logItems.cols[6], 2)	 
      end

      logItems.line = io.readline(fd, true)
      --if first then print(logItems.line);first=false end
      --print("logItems.line", logItems.line)
      
      if not logItems.line then
	 return nil
      end

      logItems.cols = split(logItems.line, ';')

      -- check for a new time block, if so dump vals and reset
      if (logItems.cols[1] ~= logItems.timestamp) then 
	 return logItems.timestamp
      end
   until false
end

------------------------------------------------------------

local function emulator_init()
   
   local text, jfile
   local fg
   --local logSensorInfo
   --local savedLogFile

   
   jfile = appDir .. appShort .. ".jsn"
   --print("in emulator_init with jfile=", jfile)
   fg = io.readall(jfile)

   if not fg then print("SensorL: Cannot read " .. jfile) else
      config=json.decode(fg)
   end

   --print("config.fastForward:", config.fastForward)
   
   text = config.logFile
   fd = io.open(text, "r")
   if not fd then print("SensorL: Cannot read logfile: " .. text) return end

   --print("SensorL: Reading log header")

   system.setProperty("CpuLimit", 1)
   local rlb = false
   rlb = readLogHeader()
   repeat
      --print("tick")
   until rlb == true
   
   system.setProperty("CpuLimit", 0)

   --print("SensorL: Done reading log header")
   
   --dev, emflag = system.getDeviceType()
   
   print("SensorL: Using Log file: "..config.logFile)
   
   system.getSensors = emulator_getSensors
   system.getSensorByID = emulator_getSensorByID
   system.getSensorValueByID = emulator_getSensorValueByID
   system.getTxTelemetry = emulator_getTxTelemetry
   gps.getPosition = emulator_getPosition
   system.playFile = emulator_playFile
   system.playNumber = emulator_playNumber
   system.vibration = emulator_vibration
   
   
end


function emulator_vibration(lr, prof)
   local lrText
   local profText = {"Long Pulse", "Short Pulse", "2x Short Pulse", "3x Short Pulse", "Other"}
   if lr then lrText = "Right" else lrText = "Left" end
   if prof < 1 or prof > 5 then
      i = 5
   else
      i = prof
   end
   print(string.format("SensorL - vibration: %s" .. " stick - Profile: %s", lrText, profText[i]))
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
   print(string.format("SensorL - playFile: <%s> type: %s", fn, ss))
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
	 ("SensorL - playNumber: %s unit: %s label: %s", vf, unit, lab))
   return rr
end


alreadyCalled=false
annDone=false

function emulatorSensorsReady(fcn)
   if emFlag ~= 1 then return true end
   if alreadyCalled then return true end
   if not rlhDone then
      if not annDone then
	 print("SensorL: Waiting for emulated sensors")
	 annDone=true
      end
      return false
   else
      print("SensorL: Emulator ready")
      if fcn then fcn() end
      alreadyCalled=true
   end
end

function emulator_getSensors()

   local st={}
   local vv
   local ll

   -- put in by hand sensor types for MGPS. Should do for others if required. These are based
   -- experimenting with MGPS hardware. Undefined keys get 1 if null (see use of sensorType)
   -- local sensorType={MGPS=0, MGPS_Quality=0, MGPS_SatCount=0, MGPS_Latitude=9,MGPS_Longitude=9,
   -- 		     MGPS_Date=5, MGPS_TimeStamp=5, MGPS_Trip=4, MGPS_Distance=4,
   -- 		     ["RCT-GPS_Distance"]=4,
   -- 		     ["RCT-GPS_Latitude"]=9, ["RCT-GPS_Longitude"]=9}

   if not rlhDone then
      print("SensorL: Called getSensors before log header completely read")
      sensorTbl = {}
      return sensorTbl
   end

   -- this function is tasked with building the sensor table that would
   -- have been created for the subset of sensors we have chosen in the
   -- SensorL.jsn file
   
   -- we have to be careful to traverse the sensors so that each name and its
   -- labels are grouped together and we have to make a kind of a header for
   -- each one with the param=0 and sensorName="" record
   
   -- so ... first sort the keys

   for k in pairs(logSensorByName) do
      table.insert(st,k)
   end
   table.sort(st)

   -- print("st table")
   -- for k,v in pairs(st) do
   --    print(k,v)
   -- end

   -- now traverse the table in the order of the sorted keys and produce
   -- one param=0 record for each sensor name, each of which can contain
   -- multiple sensor labels. 

   ll=nil
   for _,v in ipairs(st) do
      vv = logSensorByName[v]
      --print("k,v,vv", k,v,vv)
      -- how does jeti return type from getSensors? It's not in the log header..
      -- must be a data table per sensor that I can't see ..fake it for now... see
      -- sensorType table above
      --print("v, sensorType[v]", v, sensorType[v])

      -- changed .. for now set type to 1, correct later when we know it
      
      styp = 1 --sensorType[v] or 1 -- type 9 for gps, 5 for date/time, 1 for general
      if type(vv) ~= "table"  then
	 print("SensorL: sensor not found in log header: "..v)
	 ll=nil
      else
	 if vv.sensorName ~= ll  then
	    table.insert(sensorTbl,
			 {id=tonumber(vv.id),param=0,sensorName="",
			  label=vv.sensorName,type=styp, unit=vv.unit})
	 end
	 table.insert(sensorTbl,
		      {id=tonumber(vv.id),param=tonumber(vv.param),
		       sensorName=vv.sensorName,
	 label=string.gsub(vv.label, "_", " "), type=styp, unit=vv.unit})
	 ll = vv.sensorName -- see if next sensor is a different one
      end
      --print("Label,Unit, type:", vv.label, vv.unit, styp)
   end
   --print("ret: sensorTbl, #, type:", sensorTbl, #sensorTbl, type(sensorTbl))
   -- find RX tele sensors to set up for getTxTelemetry()
   local sensN
   for k,v in pairs(sensorTbl) do
      local bot = v.id & 0XFFFF
      local top = v.id >> 16
      local text = string.format("0X%X", v.id)
      --print('#', v.label, v.param, v.id, text, bot, top)
      if v.param == 0 then sensN = string.match(v.label, "^(%P+)") end
      if sensN == "Rx" or sensN == "Rx1" then
	 Rx1ID = v.id
	 if v.label == "Q" then
	    Rx1QParam = v.param
	 elseif v.label == "A1" then
	    Rx1A1Param = v.param
	 elseif v.label == "A2" then
	    Rx1A2Param = v.param
	 elseif v.label == "U Rx" or v.label == "U Rx1" then
	    Rx1UParam = v.param
	 end
      end
      if sensN == "Rx2" then
	 Rx2ID = v.id
	 if v.label == "Q" then
	    Rx2QParam = v.param
	 elseif v.label == "A1" then
	    Rx2A1Param = v.param
	 elseif v.label == "A2" then
	    Rx2A2Param = v.param
	 elseif v.label == "U Rx2" then
	    Rx2UParam = v.param
	 end
      end
      if sensN == "RxB" then
	 RxBID = v.id
	 if v.label == "A1" then
	    RxBA1Param = v.param
	 elseif v.label == "A2" then
	    RxBA2Param = v.param
	 elseif v.label == "U RxB" then
	    RxBUParam = v.param
	 end
      end
   end
   --print("Rx1 ID, params:", Rx1ID, Rx1QParam, Rx1A1Param, Rx1A2Param)
   --print("Rx2 ID, params:", Rx2ID, Rx2QParam, Rx2A1Param, Rx2A2Param)   
   
   egsCPU = system.getCPU()
   return sensorTbl
end


function emulator_getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator_getSensorByID(ID, Param)
end

local nwait = 0
local lastwait = 0
local ffOffset = 0

function emulator_getSensorByID(ID, Param)
   
   local returnTbl
   local sf
   local etS, etL
   local ic
   local timSd60
   local min, sec
   local timstr
   
   -- defend against bad inputs or invalid sensor
   if (not ID) or (not Param) then
      --print("not ID or not Param")
      return nil
   end
   sf = sensorFullID(ID, Param)
   --print(sf, logSensorByID[sf], ID, Param)
   if not logSensorByID[sf] then
      --print("not logSensorByID", ID, Param)
      return nil
   end
   
   -- log file still open? read log header done?
   if fd and rlhDone then
      -- only read the time block if it is time to do so...
      etS = system.getTimeCounter() - sysTime0
      etL = lastTimeBlock - logTime0
      
      --print("etS - etL", etS / 1000 - etL/1000)
      
      timSd60 = tonumber(etL)/(60000) -- to mins from ms
      min, sec = math.modf(timSd60)
      sec = sec * 60
      timstr = string.format("%02d:%02.2f", min, sec)
      
      -- if the fastForward option is set in the jsn file then zoom ahead at max speed
      -- the 100 is just plugged as an experiment to get smoother playback
      
      if ffOffset == 0 and config.fastForward and etL/1000 > config.fastForward then
	 ffOffset = etL - etS
	 --print("trigger: ffOffset=", ffOffset/1000, etS/1000, etL/1000)
      end
      
      --print(etS/1000, etL/1000, config.fastForward, (etS + ffOffset) / 1000)
      
      -- read new time block, otherwise use stored data
      if ffOffset ~= 0 and math.abs( (etS + ffOffset) - etL) > 1000 then
	 print("time mismatch", etL/1000, etS/1000, ffOffset)
      end
      
      local limit
      
      if etS + ffOffset >= etL or (config.fastForward and (etL/1000 <= config.fastForward)) then 
	 --print("waited "..nwait .. " delay " .. (system.getTimeCounter() - lastwait))
	 lastwait = system.getTimeCounter()
	 nwait = 0
	 ic = 0
	 repeat
	    ic =ic + 1
	    if ic > 1 then
	       --was warning
	    end
	    lastTimeBlock = readLogTimeBlock()
	    if not lastTimeBlock then
	       print("SensorL: done at time " .. timstr)
	       io.close(fd)
	       print('SensorL: Closing log replay file')
	       fd = nil
	       return nil
	    end
	    if config.fastForward then
	       limit = math.floor(config.fastForward*1000)
	    else
	       limit = etS
	    end
	 until etL > limit or ic > 100
	 --print(system.getCPU())
      else
	 nwait = nwait + 1
      end
   else
      return nil
   end
   
   -- if zooming ahead, don't bother to return a value
   
   if config.fastForward and etL then
      if config.fastForward and etL/1000 <= config.fastForward then return nil end
   end
   
   -- create the return table
   
   for k,v in ipairs(sensorTbl) do
      if v.id == ID and v.param == Param then
	 sf = sensorFullID(ID, Param)
	 returnTbl = {}
	 -- first copy the info that does not change - loaded from log header
	 returnTbl.id         = ID
	 returnTbl.param      = Param
	 returnTbl.sensorName = logSensorByID[sf].sensorName
	 returnTbl.label      = logSensorByID[sf].label
	 returnTbl.unit       = logSensorByID[sf].unit
	 -- now get varying signals, be careful if not set yet
	 if logSensorByID[sf].lastUpdate then -- ever updated?
	    local dtt = system.getTimeCounter() - logSensorByID[sf].lastUpdate 
	    if dtt > 2000 then
	       --    print("sensor age over 2000 ms Name: "..
	       -- 		logSensorByID[sf].sensorName.."-->"..logSensorByID[sf].label..
	       -- 		"  "..dtt.." ms"
	       --     )
	       returnTbl.valid = false
	    else
	       returnTbl.valid   = true
	    end
	 else
	    -- we have not seen this sensor yet .. note that we looked at it
	    -- but return valid = false
	    -- print("SensorL: Sensor not valid - Name: "..logSensorByID[sf].label..
	    -- 	     "  ID: "..ID.."  Param: "..Param.."  Log File Time:  "
	    -- 	     ..lastTimeBlock)
	    logSensorByID[sf].lastUpdate = system.getTimeCounter()
	    returnTbl.valid   = false
	 end
	 -- be defensive ..even if valid=false, set  values that won't cause error
	 returnTbl.type       = logSensorByID[sf].type or 1
	 returnTbl.decimals   = tonumber(logSensorByID[sf].decimals or 0)
	 returnTbl.value      = tonumber(logSensorByID[sf].value or 0)
	 if returnTbl.type == 9 then
	    returnTbl.valGPS     = tonumber(logSensorByID[sf].value or 0)
	 end
	 if returnTbl.type == 5 then -- time and date
	    if returnTbl.decimals == 0 then -- time
	       returnTbl.valSec = returnTbl.value & 0xFF
	       returnTbl.valMin = (returnTbl.value & 0xFF00) >> 8
	       returnTbl.valHour = (returnTbl.value & 0xFF0000) >> 16
	       --print(string.format("%d:%02d:%02d", returnTbl.valHour, returnTbl.valMin, returnTbl.valSec))
	    else
	       returnTbl.valYear = returnTbl.value & 0xFF
	       returnTbl.valMonth = (returnTbl.value & 0xFF00) >> 8
	       returnTbl.valDay = (returnTbl.value & 0xFF0000) >> 16
	       --print(string.format("%d-%02d-%02d", returnTbl.valYear, returnTbl.valMonth, returnTbl.valDay))
	    end
	 end
	 if returnTbl.decimals ~= 0 and returnTbl.type ~= 5 and returnTbl.type ~= 9 then
	    returnTbl.value = returnTbl.value / 10^returnTbl.decimals
	 end
	 returnTbl.max        = logSensorByID[sf].max or 0
	 returnTbl.min        = logSensorByID[sf].min or 0
	 
	 for kk,vv in pairs(returnTbl) do
	    if not sensorCache[k] then
	       table.insert(activeSensors, k)
	       sensorCache[k]={}
	    end
	    sensorCache[k][kk] = vv
	 end
	 egsIdCPU = system.getCPU()
	 return returnTbl
      end
   end
   return nil
end

function emulator_getTxTelemetry()

   local txTel = {}
   txTel.RSSI = {}
   local RxSens = {}
   
   if Rx1ID then -- config.getTxTelRx1 and Rx1ID then
      if Rx1QParam then
	 RxSens = emulator_getSensorByID(Rx1ID, Rx1QParam)
	 if RxSens and RxSens.valid then
	    txTel.rx1Percent = RxSens.value or 0
	 end
      end

      if Rx1A1Param then
	 RxSens = emulator_getSensorByID(Rx1ID, Rx1A1Param)
	 if RxSens and RxSens.valid then
	    txTel.RSSI[1] = (RxSens.value or 0) * 10
	 end
      end

      if Rx1A2Param then
	 RxSens = emulator_getSensorByID(Rx1ID, Rx1A2Param)
	 if RxSens and RxSens.valid then
	    txTel.RSSI[2] = (RxSens.value or 0) * 10
	 end
      end            

      if Rx1UParam then
	 RxSens = emulator_getSensorByID(Rx1ID, Rx1UParam)
	 if RxSens and RxSens.valid then
	    txTel.rx1Voltage = (RxSens.value or 0)
	 end
      end            
   end
   
   if Rx2ID then -- config.getTxTelRx2 and Rx2ID then
      if Rx2QParam then
	 RxSens = emulator_getSensorByID(Rx2ID, Rx2QParam)
	 if RxSens and RxSens.valid then
	    txTel.rx2Percent = RxSens.value or 0
	 end
      end

      if Rx2A1Param then
	 RxSens = emulator_getSensorByID(Rx2ID, Rx2A1Param)
	 if RxSens and RxSens.valid then
	    txTel.RSSI[3] = (RxSens.value or 0) * 10
	 end
      end

      if Rx2A2Param then
	 RxSens = emulator_getSensorByID(Rx2ID, Rx2A2Param)
	 if RxSens and RxSens.valid then
	    txTel.RSSI[4] = (RxSens.value or 0) * 10
	 end
      end            

      if Rx2UParam then
	 RxSens = emulator_getSensorByID(Rx2ID, Rx2UParam)
	 if RxSens and RxSens.valid then
	    txTel.rx2Voltage = (RxSens.value or 0)
	 end
      end            
   end

   if RxBID then -- config.getTxTelRx2 and Rx2ID then

      if RxBA1Param then
	 RxSens = emulator_getSensorByID(RxBID, RxBA1Param)
	 if RxSens and RxSens.valid then
	    txTel.RSSI[5] = (RxSens.value or 0) * 10
	 end
      end

      if RxBA2Param then
	 RxSens = emulator_getSensorByID(RxBID, RxBA2Param)
	 if RxSens and RxSens.valid then
	    txTel.RSSI[6] = (RxSens.value or 0) * 10
	 end
      end            

      if RxBUParam then
	 RxSens = emulator_getSensorByID(RxBID, RxBUParam)
	 if RxSens and RxSens.valid then
	    txTel.rxBVoltage = (RxSens.value or 0)
	 end
      end            
   end
   
   
   -- make sure we don't return any nil values since we don't populate all fields

   for k,v in pairs(txTel) do
      if not v then txTel[k] = 0 end
   end

   for k = 1,6,1 do
      if not txTel.RSSI[k] then txTel.RSSI[k] = 0 end
   end
   
   return txTel

end

function emulator_getPosition(sensID, parmLat, parmLng)

   local sensor
   local minutes, degs, latitude, longitude
   
   sensor = emulator_getSensorByID(sensID, parmLng)
   if sensor and sensor.valid then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative (NESW coded in decimal places as 0,1,2,3)
	 longitude = longitude * -1
      end      
   else
      return nil
   end
   
   sensor = emulator_getSensorByID(sensID, parmLat)
   if sensor and sensor.valid then
      minutes = (sensor.valGPS & 0xFFFF) * 0.001
      degs = (sensor.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
      if sensor.decimals == 2 then -- "South" .. make it negative (NESW coded in decimal places as 0,1,2,3)
	 latitude = latitude * -1
      end      
   else
      return nil
   end

   return gps.newPoint(latitude, longitude)
   
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
	    lcd.drawText(cs+cs*col, ls*2+ss*sec, string.format("%.4f'",min), font)	    
	 else -- other numeric
	    lcd.drawText(cs + cs*col, ls*2+ss*sec,
			 string.format("%3.1f", sensorCache[k].value or 0), font)
	    lcd.drawText(cs + cs*col, ls*3+ss*sec,
			 string.format("%3.1f", sensorCache[k].max or 0), font)
	    lcd.drawText(cs + cs*col, ls*4+ss*sec,
			 string.format("%3.1f", sensorCache[k].min or 0), font)
	 end
	 if sensorCache[k].type ~= 9 then
	    if sensorCache[k].unit ~= " " then
	       lcd.drawText(cs + cs*col, ls+ss*sec, "("..(sensorCache[k].unit or "")..")", font)
	    end
	 else
	    lcd.drawText(cs + cs*col, ls+ss*sec, string.format("%d°", deg), font)
	 end
      end
      col=col+1
      if col > 3 then
	 col = 0
	 sec = sec + 1
      end
   end

   if lastTimeBlock then -- will be nil when done
      local etL = lastTimeBlock - logTime0
      local timSd60 = tonumber(etL)/(60000) -- to mins from ms
      local min, sec = math.modf(timSd60)
      sec = sec * 60
      local timstr = string.format("%02d:%02.2f", min, sec)
      
      lcd.drawText(180,148, string.format("Logfile time: " .. timstr), FONT_MINI)
      -- lcd.drawText(260,125, string.format("T: %02d", system.getCPU()), FONT_MINI)
      -- lcd.drawText(260,135, string.format("egs: %02d", egsCPU or 0), FONT_MINI)
      -- lcd.drawText(260,145, string.format("egsId: %02d", egsIdCPU or 0), FONT_MINI)
   end
end

local function initForm(sf)
   print("initForm - sf:", sf)
end

local function keyForm(k)
   print("keyForm - k:", k)
end

local function prtForm()
end


local function init()
   --print("SensorL init()")
   system.registerTelemetry(1, appName, 4, telePrint, {"SL1", "SL2", "SL3", "SL4"})
   system.registerForm(1, MENU_APPS, "Log File Player", initForm, keyForm, prtForm)
   
   dev, emFlag = system.getDeviceType()
   --startUpTime = system.getTimeCounter()
   --print("before emulator_init")
   emulator_init()
   --print("after emulator_init")
   
end

return {init=init, loop=nil, author=appAuthor, version=appVersion, name=appName}

--[[

The configuration file SensorL.jsn
----------------------------------

Note: if the key "selectedSensors" and its associated table of values
is not present, then SensorL will read/use ALL telemetry channels. If there
is a very large number of sensors and you only want to use some, the
subset to be used can be described as shown below.

Note: If you choose to use selectedSensors, separate sensor name
(e.g. MGPS) and label (e.g. Latitude) with underscore. Also replace
any spaces in labels with underscores.

Note: if you want the log file to zoom ahead to when the interesting
part of the flight happens, specify a time in seconds to "fastForward"
and it will fast forward thru that many seconds before it starts
normal playback.

---- Sample file Apps/SensorL/SensorL.jsn  ------
{
"logFile":"Log/20190926/16-56-45.log",
"fastForward": 0
"selectedSensors":
   {
   "MGPS_Latitude":      true,
   "MGPS_Longitude":     true,
   "MGPS_AltRelat.":     true,
   "CTU_Altitude":       true,
   "CTU_G_Force":        true,
   "CTU_Fuel_remaining": true,
   "MSPEED_Velocity":    true,
   "MGPS_Speed":         true,
   "MGPS_TimeStamp":     true,   
   "MGPS_Date":          true
   }
}

---- Minimal file ------------------------------

{
"logFile":"Log/20190926/16-56-45.log",
}

-------------------------------------------------
--]]
