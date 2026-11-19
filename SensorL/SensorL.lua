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
      gps.getPosition(), and playFile, playNumber, vibration and
      messageBox (which print to the console)

The log is read in 8 KB chunks as the playback clock reaches each line.
Every 10 s of log time a snapshot of all sensor values is kept, so
going back (or forward to a part already read) is quick.

Test driver API: system.SensorL (getState, pause, setTime), the same
names as SensorE's; see "system.SensorL" below. UIDriver's
sensorPause, sensorTime and waitSensorTime steps use it, and a target
app's Apps/<App>/UIDriver/config.jsn "sensorLog" picks the log.

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

-- disabled: a _G metatable no longer works with JETI's current Lua
-- (taken out of SensorE too)
--[==[
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
--]==]


local appShort="SensorL"
local appName="Sensor LogFile Emulator"
local appDir="Apps/" .. appShort .. "/"
local appVersion="1.00"
local appAuthor="DFM"

-- the system.messageBox there was when this chunk loaded (the firmware's,
-- or a test driver's wrapper of it)
local fwMessageBox = system.messageBox

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
local dataStart             -- file offset of the first data line
local uniqueSensorNames={}

--local logHeaderPos
--local lastLogHeaderPos

-- the telemetry window: sensors the apps read, then recently changing ones
local readOrder, readSet = {}, {}   -- full sensor ids in the order first read
local slots = {}                    -- full sensor id shown at each position
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
	 dataStart = lastHeaderPos
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
-- Reading the log. The file is read in 8 KB chunks with io.read and
-- split into lines here: one io.readline call per line was the slow part
-- of fast-forwarding. Lines are applied one at a time, up to a log time.

local CHUNK = 8192
local rd = {buf = "", bi = 1, bufOff = 0, eof = false}
local pend                  -- the next line, parsed but not applied: {cols, t}
local logT = 0              -- log time (ms after the first data line) applied so far
local done = false          -- the end of the log has been reached
local tEnd                  -- log time of the last line, once reached
local linesRead = 0
local idCache = {}          -- device id text in the log -> id

-- the next non-empty line and its file offset, or nil at the end
local function nextLine()
   while true do
      local e = string.find(rd.buf, "\n", rd.bi, true)
      if e then
	 local off = rd.bufOff + rd.bi - 1
	 local line = string.sub(rd.buf, rd.bi, e - 1)
	 rd.bi = e + 1
	 if string.sub(line, -1) == "\r" then line = string.sub(line, 1, -2) end
	 if line ~= "" then return line, off end
      elseif rd.eof then
	 if rd.bi <= #rd.buf then          -- a last line with no newline
	    local off = rd.bufOff + rd.bi - 1
	    local line = string.sub(rd.buf, rd.bi)
	    rd.bi = #rd.buf + 1
	    return line, off
	 end
	 return nil
      else
	 local more = io.read(fd, CHUNK)
	 rd.bufOff = rd.bufOff + rd.bi - 1
	 rd.buf = string.sub(rd.buf, rd.bi) .. (more or "")
	 rd.bi = 1
	 if not more or more == "" then rd.eof = true end
      end
   end
end

local messagesSkipped = 0
local takeSnapshot           -- defined below

-- apply one data line to the sensor values; quiet: don't show its message
local function applyCols(cols, quiet, t)
   local dev = idCache[cols[2]]
   if not dev then dev = toID(cols[2]); idCache[cols[2]] = dev end
   if dev == 0 then
      -- a message the transmitter showed during the logged flight
      if quiet then
	 messagesSkipped = messagesSkipped + 1
      else
	 print("SensorL - message in log: " .. tostring(cols[6]))
	 fwMessageBox(cols[6], 2)
      end
      return
   end
   for i = 3, #cols, 4 do
      local ls = logSensorByID[sensorFullID(dev, tonumber(cols[i]))]
      if ls and (not config.selectedSensors
		 or config.selectedSensors[ls.sensorName .. "_" .. ls.label]) then
	 local v = tonumber(cols[i+3])
	 if v ~= ls.value then ls.changed = t end
	 ls.value = v
	 ls.valGPS = v
	 ls.decimals = tonumber(cols[i+2])
	 ls.type = tonumber(cols[i+1])
	 if not ls.max or v > ls.max then ls.max = v end
	 if not ls.min or v < ls.min then ls.min = v end
      end
   end
end

-- Snapshots: JETI logs a value only when it changes, so the file can't
-- just be seeked into. Every SNAP_MS of log time the reader saves every
-- sensor's state and the file offset of the next line; a jump goes to
-- the nearest earlier snapshot and reads at most SNAP_MS from there.
-- Each part of the log is read in full only once.
local SNAP_MS = 10000
local snaps = {}            -- [log time // SNAP_MS] = {logT, off, vals}

-- called with pend = the next line, before it is applied
takeSnapshot = function()
   local k = pend.t // SNAP_MS
   if snaps[k] then return end
   local vals = {}
   for _, ls in pairs(logSensorByID) do
      if ls.value ~= nil then
	 vals[#vals+1] = {ls, ls.value, ls.decimals, ls.type, ls.max, ls.min}
      end
   end
   snaps[k] = {logT = logT, off = pend.off, vals = vals}
end

local function restoreSnapshot(sn)
   for _, ls in pairs(logSensorByID) do
      ls.value, ls.valGPS, ls.decimals, ls.type, ls.max, ls.min = nil, nil, nil, nil, nil, nil
      ls.changed = nil
   end
   for _, v in ipairs(sn.vals) do
      local ls = v[1]
      ls.value, ls.valGPS, ls.decimals, ls.type, ls.max, ls.min = v[2], v[2], v[3], v[4], v[5], v[6]
   end
   io.seek(fd, sn.off)
   rd = {buf = "", bi = 1, bufOff = sn.off, eof = false}
   pend, logT, done = nil, sn.logT, false
end

-- the latest snapshot at or before log time t
local function snapshotBefore(t)
   for k = t // SNAP_MS, 0, -1 do
      if snaps[k] then return snaps[k] end
   end
end

-- apply lines up to log time target (ms). budgetMs: stop after that long
-- (returns false); otherwise true when caught up or at the end
local function readUpTo(target, quiet, budgetMs)
   local t0 = budgetMs and system.getTimeCounter()
   local n = 0
   while true do
      if not pend then
	 local line, off = nextLine()
	 if not line then
	    if not done then
	       done = true
	       print(string.format("SensorL: end of the log at %d:%02d log time",
				   logT // 60000, logT // 1000 % 60))
	    end
	    return true
	 end
	 local cols = split(line, ";")
	 pend = {cols = cols, t = (tonumber(cols[1]) or 0) - logTime0, off = off}
      end
      if pend.t > target then return true end
      takeSnapshot()
      applyCols(pend.cols, quiet, pend.t)
      logT = pend.t
      pend = nil
      n = n + 1
      linesRead = linesRead + 1
      if budgetMs and n % 50 == 0 and system.getTimeCounter() - t0 > budgetMs then
	 return false
      end
   end
end

-- playback clock: log time = playBase + (now - wallBase) while playing
local playBase, wallBase = 0, 0
local seeking               -- {target, wall0, from, snap, lines0} while going to a time
local SEEK_BUDGET = 100     -- ms of reading per call while fast-forwarding

local paused = false

local function clock()
   if paused then return playBase end
   return playBase + (system.getTimeCounter() - wallBase)
end

-- go to log time t (ms), forward or back. A snapshot is used when going
-- back, or when one is further on than where the reader is now
local function seekTo(t)
   if t < 0 then t = 0 end
   local from, snapT = logT, nil
   local sn = snapshotBefore(t)
   if t < logT or (sn and sn.logT > logT) then
      if not sn then sn = {logT = 0, off = dataStart, vals = {}} end
      restoreSnapshot(sn)
      snapT = sn.logT
   end
   seeking = {target = t, wall0 = system.getTimeCounter(), from = from, snap = snapT,
	      lines0 = linesRead}
   messagesSkipped = 0
end

-- read whatever is due; called from the sensor functions and our loop()
local function pump()
   if not rlhDone or not fd or done then return end
   if seeking then
      if not readUpTo(seeking.target, true, SEEK_BUDGET) then return end
      local ms = system.getTimeCounter() - seeking.wall0
      local function mmss(t) return string.format("%d:%04.1f", t // 60000, (t % 60000) / 1000) end
      print(string.format("SensorL: went from %s to %s log time (%s; read %d lines, %d messages skipped) in %d ms",
			  mmss(seeking.from), mmss(logT),
			  seeking.snap and ("from the " .. mmss(seeking.snap) .. " snapshot") or "reading on",
			  linesRead - seeking.lines0, messagesSkipped, ms))
      playBase, wallBase = seeking.target, system.getTimeCounter()
      seeking = nil
      if done and not tEnd then tEnd = logT end
      return
   end
   readUpTo(clock(), false)
end

------------------------------------------------------------

local initTried = false

local function emulator_init()
   
   local text, jfile
   -- once only: called from init() and from the first sensor call, which
   -- may come from another app's init() before ours
   if initTried then return end
   initTried = true
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
   
   -- a test driver (UIDriver) can choose the log
   local drv = system.UIDriver
   if type(drv) == "table" and type(drv.sensorLog) == "string" then
      print("SensorL: log file from UIDriver: " .. drv.sensorLog)
      config = config or {}
      config.logFile = drv.sensorLog
   end
   text = config.logFile
   fd = io.open(text, "r")
   if not fd then print("SensorL: Cannot read logfile: " .. text) return end

   --print("SensorL: Reading log header")

   -- 0 turns the instruction limit off (the API doc: 1 = on, the
   -- default). The old code set 1 here and 0 after the header, so the
   -- limit has really been off ever since; it's left off on purpose for
   -- reading the log, which is time-limited instead (SEEK_BUDGET)
   system.setProperty("CpuLimit", 0)
   local rlb = false
   rlb = readLogHeader()
   repeat
      --print("tick")
   until rlb == true
   rd.bufOff = dataStart or 0
   wallBase = system.getTimeCounter()

   --print("SensorL: Done reading log header")
   
   --dev, emflag = system.getDeviceType()
   
   print("SensorL: Using Log file: "..config.logFile)
   -- "fastForward": seconds of log to skip at the start (0 or none: off)
   local ff = tonumber(config.fastForward)
   if rlhDone and ff and ff > 0 then seekTo(math.floor(ff * 1000)) end
   
   
end


-- the replacements for the system functions; local, so SensorL can't
-- clash with SensorE's globals of the same names (declared ahead because
-- some call others defined further down)
local emulator_vibration, emulator_playFile, emulator_playNumber, emulator_getSensors,
   emulator_getSensorValueByID, emulator_getSensorByID, emulator_getTxTelemetry, emulator_getPosition

function emulator_vibration(lr, prof)
   local lrText, i
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

   emulator_init()
   sensorTbl = {}   -- rebuilt on every call; it used to grow each time
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
      
      local styp = 1 --sensorType[v] or 1 -- type 9 for gps, 5 for date/time, 1 for general
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


function emulator_getSensorByID(ID, Param)
   
   local returnTbl
   local sf
   
   -- the sensor list is built by getSensors; build it if no app has
   -- called that yet
   if #sensorTbl == 0 then emulator_getSensors() end
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
   
   -- read what's due; nothing while fast-forwarding or after the end
   if not (fd and rlhDone) then return nil end
   pump()
   if seeking or done then return nil end
   
   -- create the return table
   
   for k,v in ipairs(sensorTbl) do
      if v.id == ID and v.param == Param then
	 sf = sensorFullID(ID, Param)
	 returnTbl = {}
	 -- first copy the info that does not change - loaded from log header
	 returnTbl.id         = ID
	 returnTbl.param      = Param
	 returnTbl.sensorName = logSensorByID[sf].sensorName
	 returnTbl.label      = (string.gsub(logSensorByID[sf].label, "_", " "))  -- as getSensors gives it
	 returnTbl.unit       = logSensorByID[sf].unit
	 -- now get varying signals, be careful if not set yet
	 -- Valid from the sensor's first value in the log until the log
	 -- ends. JETI logs a value only when it changes, so a gap in the log
	 -- doesn't mean the sensor was offline (CTU fuel has gaps of up to
	 -- 44 s in a normal flight); the old 2 s timeout made slow sensors
	 -- flicker invalid. How a real dropout shows in a log isn't known
	 -- yet, so dropouts aren't replayed
	 returnTbl.valid = logSensorByID[sf].value ~= nil
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
	 
	 if not readSet[sf] then
	    readSet[sf] = true
	    readOrder[#readOrder+1] = sf
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

-- JETI GPS value -> exact decimal degrees as a string. The log has whole
-- degrees in bits 16-23 and thousandths of a minute in bits 0-15 (about
-- 1.85 m), and the hemisphere in "decimals" (0..3 = N, E, S, W). The
-- digits are worked out in integers and passed to gps.newPoint as a
-- string: degs + minutes/60 in Lua's float32 added up to 0.5 m of error
local function gpsDegrees(sensor, negDecimals)
   local v = sensor.valGPS
   local deg = (v >> 16) & 0xFF
   local mth = v & 0xFFFF                -- thousandths of a minute
   deg = deg + mth // 60000              -- (never in a good log)
   mth = mth % 60000
   -- mth / 60000 degrees in units of 1e-7 degree, rounded
   local frac = (mth * 1000 + 3) // 6
   local sign = (sensor.decimals == negDecimals) and "-" or ""
   return string.format("%s%d.%07d", sign, deg, frac)
end

function emulator_getPosition(sensID, parmLat, parmLng)
   local lon = emulator_getSensorByID(sensID, parmLng)
   if not (lon and lon.valid and lon.valGPS) then return nil end
   local lat = emulator_getSensorByID(sensID, parmLat)
   if not (lat and lat.valid and lat.valGPS) then return nil end
   return gps.newPoint(gpsDegrees(lat, 2), gpsDegrees(lon, 3))  -- S, W negative
end

-- Which sensors the window shows (8 at most): first the ones the apps
-- have read, in the order they were first read; then SensorL.jsn's
-- "showSensors" ("MGPS_Speed", ... as in selectedSensors); the other
-- positions go to sensors whose value changed recently in the log.
-- Receivers (Rx...) and times/dates are left out of those: they change
-- all the time. A position is only taken over when its sensor hasn't
-- changed for HOLD_MS of log time, so the window doesn't flicker
local SLOTS, HOLD_MS = 8, 5000
local showList              -- full ids from showSensors
local dupLabel              -- [label] = true when several devices have it

local function busySensor(ls)
   return ls.type == 5 or string.match(ls.sensorName or "", "^Rx") ~= nil
end

-- the label for the window, with the device in front when another
-- device has the same label (A1, EGT, ...)
local function shownLabel(ls)
   if not dupLabel then
      local seen = {}
      dupLabel = {}
      for _, l in pairs(logSensorByID) do
	 if seen[l.label] and seen[l.label] ~= l.sensorName then dupLabel[l.label] = true end
	 seen[l.label] = l.sensorName
      end
   end
   local text = string.gsub(ls.label, "_", " ")
   if dupLabel[ls.label] then
      text = (string.match(ls.sensorName or "", "^(%S+)") or "?") .. " " .. text
   end
   return text
end

local function updateSlots()
   local new, used = {}, {}
   for _, sf in ipairs(readOrder) do
      if #new < SLOTS then new[#new+1] = sf; used[sf] = true end
   end
   if not showList then
      showList = {}
      local want = config and config.showSensors
      if type(want) == "table" then
	 local byKey = {}
	 for sf, ls in pairs(logSensorByID) do byKey[ls.sensorName .. "_" .. ls.label] = sf end
	 for _, key in ipairs(want) do
	    if byKey[key] then showList[#showList+1] = byKey[key]
	    else print("SensorL: showSensors: no sensor " .. tostring(key) .. " in the log") end
	 end
      end
   end
   for _, sf in ipairs(showList) do
      if #new < SLOTS and not used[sf] then new[#new+1] = sf; used[sf] = true end
   end
   local nPinned = #new
   -- keep the previous changing sensors where they were
   for i = nPinned + 1, SLOTS do
      local sf = slots[i]
      if sf and not used[sf] and logSensorByID[sf] and logSensorByID[sf].value ~= nil
      and not busySensor(logSensorByID[sf]) then
	 new[i] = sf; used[sf] = true
      end
   end
   -- the most recently changed sensors not shown yet, newest first
   local cands = {}
   for sf, ls in pairs(logSensorByID) do
      if not used[sf] and ls.changed and ls.value ~= nil and not busySensor(ls) then
	 cands[#cands+1] = sf
      end
   end
   table.sort(cands, function(a, b) return logSensorByID[a].changed > logSensorByID[b].changed end)
   local c = 1
   -- empty positions first
   for i = nPinned + 1, SLOTS do
      if not new[i] and cands[c] then new[i] = cands[c]; c = c + 1 end
   end
   -- then take over positions whose sensor has gone quiet, the quietest first
   while cands[c] and logT - logSensorByID[cands[c]].changed < HOLD_MS do
      local q, qt
      for i = nPinned + 1, SLOTS do
	 local ch = logSensorByID[new[i]].changed or -1
	 if logT - ch >= HOLD_MS and (not qt or ch < qt) then q, qt = i, ch end
      end
      if not q then break end
      new[q] = cands[c]; c = c + 1
   end
   slots = new
end

local function telePrint()
   local font = FONT_MINI
   local ls = 15 -- line spacing
   local cs = 65 -- col spacing
   local ss = 80 -- section spacing

   if rlhDone then updateSlots() end

   -- arrange into a 4 col 2 row (max) table
   for kk = 0, math.min((#slots - 1) // 4, 1) do
      lcd.drawText(5, ls+ss*kk,   "Unit", font)
      lcd.drawText(5, ls*2+ss*kk, "Val",  font)
      lcd.drawText(5, ls*3+ss*kk, "Max",  font)
      lcd.drawText(5, ls*4+ss*kk, "Min",  font)
   end

   for j = 1, #slots do
      local sn = logSensorByID[slots[j]]
      local col, sec = (j - 1) % 4, (j - 1) // 4
      local x, y = cs + cs*col, ss*sec
      local text = shownLabel(sn)
      if readSet[slots[j]] then text = text .. "*" end   -- an app reads it
      local ll = lcd.getTextWidth(font, text)
      lcd.drawText(x + 12 - ll/2, y, text, font)
      local v, typ, dec = sn.value or 0, sn.type or 1, sn.decimals or 0
      if typ == 5 then -- time or date
	 if dec == 0 then
	    text = string.format("%d:%02d:%02d", (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)
	 else
	    text = string.format("%d-%02d-%02d", v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF)
	 end
	 lcd.drawText(x, ls*2+y, text, font)
      elseif typ == 9 then -- gps: degrees on the unit line, minutes below
	 local deg = (v >> 16) & 0xFF
	 if dec == 3 or dec == 2 then deg = -deg end
	 lcd.drawText(x, ls+y, string.format("%d°", deg), font)
	 lcd.drawText(x, ls*2+y, string.format("%.4f'", (v & 0xFFFF) * 0.001), font)
      else -- other numeric
	 local scale = 10^dec
	 lcd.drawText(x, ls*2+y, string.format("%3.1f", v / scale), font)
	 lcd.drawText(x, ls*3+y, string.format("%3.1f", (sn.max or 0) / scale), font)
	 lcd.drawText(x, ls*4+y, string.format("%3.1f", (sn.min or 0) / scale), font)
      end
      if typ ~= 9 and sn.unit and sn.unit ~= " " then
	 lcd.drawText(x, ls+y, "(" .. sn.unit .. ")", font)
      end
   end

   if rlhDone then
      local timstr = string.format("%02d:%05.2f", logT // 60000, (logT % 60000) / 1000)
      if seeking then timstr = timstr .. " (fast-forward)"
      elseif done then timstr = timstr .. " (end)" end
      lcd.drawText(180,148, "Logfile time: " .. timstr, FONT_MINI)
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

--------------------------------------------------------------------------------
-- system.SensorL: lets a test driver (UIDriver) control the replay, with
-- the same names as system.SensorE. The functions return true, or false
-- and a message. Times are seconds of log time after the first data line.
--   getState()     {t, paused, seeking, target, done, tEnd, logFile}
--                  t: log time applied so far; tEnd once the end is known
--   pause(on)      freeze (true) or resume log time; sensors keep their
--                  values (and stay valid) while paused
--   setTime(sec)   go to that log time, forward or back. Sensors read as
--                  absent until it gets there (getState().seeking);
--                  a pause stays in force
--------------------------------------------------------------------------------

local SLapi = {version = 1}

function SLapi.getState()
   if done and not tEnd then tEnd = logT end
   return {t = logT / 1000, paused = paused, seeking = seeking ~= nil,
	   target = seeking and seeking.target / 1000 or nil,
	   done = done, tEnd = tEnd and tEnd / 1000 or nil,
	   logFile = config and config.logFile}
end

function SLapi.pause(on)
   on = on and true or false
   if on == paused then return true end
   if on then
      playBase = clock()     -- freeze where it is now
   else
      wallBase = system.getTimeCounter()   -- carry on from the frozen time
   end
   paused = on
   return true
end

function SLapi.setTime(sec)
   sec = tonumber(sec)
   if not sec then return false, "setTime needs seconds" end
   emulator_init()
   if not rlhDone or not fd then return false, "no log loaded" end
   seekTo(math.floor(sec * 1000))
   return true
end

system.SensorL = SLapi

-- message boxes from any app go to the console too, like playFile
local function emulator_messageBox(msg, tmo, ...)
   print("SensorL - messageBox: " .. tostring(msg))
   return fwMessageBox(msg, tmo, ...)
end

-- replace the system functions when the chunk loads, as SensorE does, so
-- apps whose init() runs before ours already get the log's sensors. The
-- emulator loads every app's chunk before calling any init()
system.getSensors = emulator_getSensors
system.getSensorByID = emulator_getSensorByID
system.getSensorValueByID = emulator_getSensorValueByID
system.getTxTelemetry = emulator_getTxTelemetry
gps.getPosition = emulator_getPosition
system.playFile = emulator_playFile
system.playNumber = emulator_playNumber
system.vibration = emulator_vibration
system.messageBox = emulator_messageBox

-- keeps the log moving (and fast-forwarding) even if no app reads a sensor
local function loop()
   pump()
end

return {init=init, loop=loop, author=appAuthor, version=appVersion, name=appName}

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

Note: SensorL's telemetry window shows up to 8 sensors: those the apps
read (marked *), then any listed in "showSensors" (same names as
selectedSensors, in the order wanted), then ones whose value changed
recently in the log (not receivers or times).

Note: if you want the log file to zoom ahead to when the interesting
part of the flight happens, specify a time in seconds to "fastForward"
and it will fast forward thru that many seconds before it starts
normal playback (0 = off). While it fast-forwards, sensors read as
absent and the log's messages aren't shown; the console then says how
long it took.

---- Sample file Apps/SensorL/SensorL.jsn  ------
{
"logFile":"Log/20190926/16-56-45.log",
"fastForward": 0,
"showSensors": ["MGPS_Speed", "CTU_EGT"],
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
