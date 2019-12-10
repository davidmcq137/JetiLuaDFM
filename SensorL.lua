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

One caveat .. until I figure out a better way..

Processing the log file header takes a long time for an aircraft with
a complex setup, and that process has to complete before other apps
ask for the sensor list via system.getSensors(). If we don't work
around this issue the other lua files won't get the emulated sensors.
We also have an issue where the script is killed for log files
containing many telemetry sensors since it requires too much CPU
time. Since co-routines are not part of Jeti's lua build, we have to
take some other action on that.

SensorL.lua, when first run with a new logfile in
Apps/SensorL/SensorL.jsn processes the log headerfile and writes out
some intermediate .jsn files so that when run again with the same log
file it starts up quickly. It will them post a system message box
asking that you reload lua, which starts the emulator with the
pre-processed files. This works around the script killed issue for
now.

We have observed in some cases that we can clear out all user apps and
start SensorL.lua first, then load other programs and everything works
as expected. In some cases, the lua runtime re-orders the apps and
starts other lua programs first, which are expecting that SensorL ran
first and set up the emulation. In these cases, regrettably, you will
have to modify the lua scripts that run with SensorL and use its
emulation. You need to move the call to system.getSensors into your
main loop() (not in init() ), and put in a short timedelay (2-3 secs
is fine) and only call system.getSensors after that delay (and only
once!).

Since this is meant to be used on the emulator, all the config
information is in the configuration json file Apps/SensorL/SensorL.jsn
where it is assumed it is easy to edit/change the file. A sample
SensorL.jsn is included below. Place in that config file the name of
the log file to process and the names of the telemetry log variables
you want to make available (formatted as shown with name and label).

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

local appShort="SensorL"
local appName="Sensor LogFile Emulator"
local appDir="Apps/" .. appShort .. "/"
local appVersion="1.00"
local appAuthor="DFM"

local sensorTbl={}
local sensorDir

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
local logHeaderPos
local lastLogHeaderPos

local sensorCache={}
local activeSensors={}
local selKeysStr

logItems.cols={}
logItems.vals={}

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

-- great mystery: why are device ID numbers in Jeti log files so many digits?
-- they cause a lot of headaches trying to store in a 32-bit int
-- so (gulp) truncate 4 high order digits and hope they are still unique

local function toID(logstr)
   return tonumber(string.sub(logstr,5))
end

------------------------------------------------------------

local function readLogHeader()

   local ff
   local uid
   local iid

   if not fd then return false end
   if rlhDone then return rlhDone end

   if rlhCount == 0 then
      -- read the comment line and toss .. assume one comment line only (!)      
      logHeaderPos = logHeaderPos + #io.readline(fd) + 1
   end
   rlhCount = rlhCount + 1

   -- process logfile header 4 rows at a time so it keep cpu usage below cutoff
   -- do 4 rows each call to loop()

   for _ = 1, 4, 1 do
      lastLogHeaderPos = logHeaderPos
      logItems.line = io.readline(fd, true) -- true param removes newline
      logHeaderPos = logHeaderPos + #logItems.line + 1
      if not logItems.line then
	 print("SensorL: Read eror on log header file")
	 rlhDone=true
	 return rlhDone
      end

      logItems.cols = split(logItems.line, ";")

      logItems.timestamp = tonumber(logItems.cols[1])
      if logItems.timestamp ~= 0 then -- this must be the first real data line... 
	 rlhDone = true
	 logTime0 = logItems.timestamp
	 sysTime0 = system.getTimeCounter()
	 
	 -- for convenience, write a file with the names of all the sensors
	 -- and for future use the two sensor tables
	 
	 jsonText = json.encode(allSensors)
	 ff = io.open(appDir .. "AllSensorNames.jsn", "w")
	 io.write(ff, jsonText)
	 io.close(ff)

	 --print("lastLogHeaderPos:", lastLogHeaderPos, logHeaderPos)
	 
	 jsonText = json.encode(logSensorByID)
	 ff = io.open(appDir .. "logSensorByID.jsn", "w")
	 io.write(ff, jsonText)
	 io.close(ff)
	 
	 jsonText = json.encode(logSensorByName)
	 ff = io.open(appDir .. "logSensorByName.jsn", "w")
	 io.write(ff, jsonText)
	 io.close(ff)	 

	 jsonText = json.encode({logFile=config.logFile, seekTo=lastLogHeaderPos,
				 selKeysStr=selKeysStr})
	 ff = io.open(appDir .. "logSensorInfo.jsn", "w")
	 io.write(ff, jsonText)
	 io.close(ff)	 

	 print("SensorL: Wrote all jsn files")
	 
	 system.messageBox("Log sensors ready - please Reload Lua", 4)
	 
	 return rlhDone
      end
      
      if logItems.cols[3] == "0" then
	 logItems.sensorName=logItems.cols[4]
      else
	 logItems.cols[4] = string.gsub(logItems.cols[4], " ", "_")
	 uid = sensorFullName(logItems.sensorName, logItems.cols[4])
	 table.insert(allSensors, uid)
	 if config.selectedSensors[uid] then
	    logSensorByName[uid] = {}
	    iid = sensorFullID(toID(logItems.cols[2]), tonumber(logItems.cols[3]) )
	    logSensorByID[iid] = {}
	    logSensorByName[uid].label = logItems.cols[4]
	    logSensorByID[iid].label = logItems.cols[4]	    
	    logSensorByName[uid].sensorName = logItems.sensorName
	    logSensorByID[iid].sensorName = logItems.sensorName
	    logSensorByName[uid].unit = logItems.cols[5]
	    logSensorByID[iid].unit = logItems.cols[5]
	    logSensorByName[uid].id = toID(logItems.cols[2])
	    logSensorByID[iid].id = toID(logItems.cols[2])
	    logSensorByName[uid].param = tonumber(logItems.cols[3])
	    logSensorByID[iid].param = tonumber(logItems.cols[3])
	 end
      end
   end
   return rlhDone
end

------------------------------------------------------------

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
	       if config.selectedSensors[sn.."_"..sl] then
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
   
   local ans
   local dev, emflag
   local text, jfile
   local fg
   local logSensorInfo
   local savedLogFile
   local selKeys={}

   
   jfile = appDir .. appShort .. ".jsn"
   fg = io.readall(jfile)

   if not fg then print("SensorL: Cannot read " .. jfile) else
      config=json.decode(fg)
   end

   for k,_ in pairs(config.selectedSensors) do
      table.insert(selKeys, k)
   end
   table.sort(selKeys)
   for _,v in pairs(selKeys) do
      if not selKeysStr then selKeysStr = v else selKeysStr = selKeysStr..v end
   end
   selKeysStr = selKeysStr..config.logFile
   
   text = io.readall(appDir .. "logSensorInfo.jsn", "r")
   if not text then
      print("SensorL: logSensorInfo.jsn not available")
   else
      logSensorInfo = json.decode(text)
   end

   -- check to see if sensors and logfile name still the same as last time
   if logSensorInfo and logSensorInfo.selKeysStr == selKeysStr then
      print("SensorL: Using logSensor saved files")
      text = io.readall(appDir .. "logSensorByID.jsn", "r")
      if not text then
	 print("SensorL: logSensorByID.jsn not available")
	 logSensorByID = {}
      else
	 logSensorByID = json.decode(text)
      end
      
      text = io.readall(appDir .. "logSensorByName.jsn", "r")
      if not text then
	 print("SensorL: logSensorByName.jsn not available")
	 logSensorByName = {}
      else
	 logSensorByName = json.decode(text)
      end
   end

   text = config.logFile
   fd = io.open(text, "r")
   if not fd then print("SensorL: Cannot read logfile: " .. text) return end
   logHeaderPos = 0

   -- do we have valid json serializations?
   if (next(logSensorByName) and next(logSensorByID)) then 
      if logSensorInfo.seekTo then io.seek(fd, logSensorInfo.seekTo) end
      -- readLogTimeBlock expects first real data line read and split into items
      logItems.line = io.readline(fd, true)
      if not logItems.line then return nil end
      logItems.cols = split(logItems.line, ';')
      rlhDone = true
      logItems.timestamp = tonumber(logItems.cols[1])
      logTime0 = logItems.timestamp
      sysTime0 = system.getTimeCounter()
   else
      print("SensorL: Reading log header")
      readLogHeader()
   end

   dev, emflag = system.getDeviceType()
   
   if emflag == 1 then
      print("SensorL: Using Sensor Emulator, logFile: "..config.logFile)
      system.getSensors = emulator_getSensors
      system.getSensorByID = emulator_getSensorByID
      system.getSensorValueByID = emulator_getSensorValueByID
   else
      print("SensorL: Using Native Sensors")
   end
end

function emulator_getSensors()

   local st={}
   local vv
   local ll

   -- put in by hand sensor types for MGPS. Should do for others if required. These are based
   -- experimenting with MGPS hardware. Undefined keys get 1 as observed.
   local sensorType={MGPS=0, MGPS_Quality=0, MGPS_SatCount=0, MGPS_Latitude=9,MGPS_Longitude=9,
		     MGPS_Date=5, MGPS_TimeStamp=5, MGPS_Trip=4, MGPS_Distance=4}

   if not rlhDone then
      print("SensorL: Called getSensors before log header read - reload lua")
      system.messageBox("SensorL: Please Reload Lua", 4)
      sensorTbl = {}
      return sensorTbl
   end

   -- this function is tasked with builting the sensor table that would
   -- have been created for the subset of sensors we have chosen in the
   -- sensorLogEm.jsn file
   
   -- we have to be careful to traverse the sensors so that each name and its
   -- labels are grouped together and we have to make a kind of a header for
   -- each one with the param=0 and sensorName="" record
   
   -- so ... first sort the keys

   for k in pairs(logSensorByName) do
      table.insert(st,k)
   end
   table.sort(st)

   -- now traverse the table in the order of the sorted keys and produce
   -- one param=0 record for each sensor name, each of which can contain
   -- multiple sensor labels. 

   ll=nil
   for k,v in ipairs(st) do
      vv = logSensorByName[v]
      --print("k,v,vv", k,v,vv)
      -- how does jeti return type from getSensors? It's not in the log header..
      -- must be a data table per sensor that I can't see ..fake it for now... see
      -- sensorType table above
      styp = sensorType[v] or 1 -- type 9 for gps, 5 for date/time, 1 for general
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
   return sensorTbl
end


function emulator_getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator_getSensorById(ID, Param)
end

function emulator_getSensorByID(ID, Param)
      
   local returnTbl
   local sf
   local etS, etL
   local ic
   --local timSd60
   --local min, sec
   --local timstr

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
      --timSd60 = tonumber(etL)/(60000) -- to mins from ms
      --min, sec = math.modf(timSd60)
      --sec = sec * 60
      --timstr = string.format("%02d:%02.2f", min, sec)
      if etS > etL then -- read new time block, otherwise use stored data
	 ic = 0
	 repeat
	    ic =ic + 1
	    if ic > 1 then print("ic > 1:", ic) end
	    lastTimeBlock = readLogTimeBlock()
	    if not lastTimeBlock then
	       io.close(fd)
	       print('SensorL: Closing log replay file')
	       fd = nil
	       return nil
	    end
	 until tonumber(lastTimeBlock) > etS
      end
   end
   
   -- create the return table
   for k,v in ipairs(sensorTbl) do
      if v.id == ID and v.param == Param then
	 sf = sensorFullID(ID, Param)
	 returnTbl = {}
	 -- first copy the info that does not change - loaded from log header
	 returnTbl.id         = ID
	 returnTbl.param      = param
	 returnTbl.sensorName = logSensorByID[sf].sensorName
	 returnTbl.label      = logSensorByID[sf].label
	 returnTbl.unit       = logSensorByID[sf].unit
	 -- now get varying signals, be careful if not set yet
	 if logSensorByID[sf].lastUpdate then -- ever updated?
	    local dtt = system.getTimeCounter() - logSensorByID[sf].lastUpdate 
	    if dtt > 2000 then
	       --print("sensor age over xxxx ms Name: "..
		--	logSensorByID[sf].sensorName.."-->"..logSensorByID[sf].label..
		--	"  "..dtt.." ms"
	        --)
	       returnTbl.valid = false
	    else
	       returnTbl.valid   = true
	    end
	 else
	    print("SensorL: Sensor not valid - Name: "..logSensorByID[sf].label..
		     "  ID: "..ID.."  Param: "..Param.."  Log File Time:  "
		     ..lastTimeBlock)
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
end


local function init()

   system.registerTelemetry(1, appName, 4, telePrint)   

   emulator_init()

end

local iloop=0
local function loop()
   -- readLogHeader() returns true when done
   if not readLogHeader() then
      iloop = iloop + 1
      return
   end
end

return {init=init, loop=loop, author=appAuthor, version=appVersion, name=appName}

--[[

Sample SensorE.jsn file

{
"logFile":"Log/20190926/16-56-45.log",
"selectedSensors":
   {
   "MGPS_Latitude":     true,
   "MGPS_Longitude":    true,
   "MGPS_AltRelat.":    true,
   "CTU_Altitude":      true,
   "CTU_G_Force":       true,
   "CTU_Fuel_remaining":true,
   "MSPEED_Velocity":   true,
   "MGPS_Speed":        true,
   "MGPS_TimeStamp":    true,   
   "MGPS_Date":         true
   }
}

--]]
