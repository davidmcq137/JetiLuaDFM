--[[

   sensorLogEm.lua

   Read a Jeti log file and replay selected sensor data with a sensor emulation

   Usage: 

   Put this declaration at the top of your lua file before any function declarations:

   ------------------------------------------------------------
   local pcallOK, emulator
   ------------------------------------------------------------

   Put this code snippet into init() near the top of the file:

   ------------------------------
   pcallOK, emulator = pcall(require, "sensorLogEm")
   if not pcallOK then print("pcall error: ", emulator) end
   if pcallOK and emulator then emulator.init("sensorLogEm.jsn") end
   ------------------------------

   You can supply whatever jsn file name you like in the call to
   emulator.init. Inside the function, it is prepended with
   "Apps/". Default if nil is passed is "sensorLogEm.jsn".

   Do not call readSensors() / system.getSensors() from the init file
   as usual practice would dictate

   Put this code snippet into loop() at the top: Assuming
   readSensors() is a local wrapper that calls system.getSensors()

   ------------------------------
   if pcallOK and emulator then
      if emulator.startUp(readSensors) then return end
   end
   ------------------------------

   The reason for all of these gymnastics is that for a log file with
   a lot (>40) of telemetry sensors in its header, we will use too
   much CPU to process them and kill the script. The processing has to
   be done in smaller chunks in successive calls to loop()

   Maybe Jeti would give us an option to turn off the cpu throttle on
   the emulator for stuff like this that is never meant to run on the
   TX...

   Since this is meant to be used on the emulator, all the config
   information is in the configuration json file Apps/sensorLogEm.jsn
   where it is assumed it is easy to edit/change the file. Sample
   included below. Place in that config file the name of the log file
   to process and the names of the telemetry log variables you want to
   make available

   To Do: when sensor not valid, we set the value to -999 and then
   don't put into the renderer (which is kind of bs...). End result is
   similar to what Jeti studio does except we don't show the curve
   dotted while not valid. Should be nil and we should not plot
   anything .. should just show a gap. But this will take a bunch of
   work to put nils in the histogram[] since then will have to keep
   length separately. Then will have to figure out how to do line
   segments with the renderer for line mode... ugg. Too bad there is
   not a "pen up" and "pen down" capability on the renderer!


   Released under MIT license by DFM 2019

--]]

local emulator={}

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
local config
local lastTimeBlock = 0

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
-- e.g. 420460025613 (13 concat to 4204600256)
-- note that this assumes the devID and devParam are left as strings!
local function sensorFullID(devID, devParm)
   return tostring(devID)..tostring(devParm)
end

------------------------------------------------------------
local readSenDone=false
function emulator.startUp(readSen)

   if not emulator.readLogHeader() then return true end
   if not readSenDone then
      readSen(0)
      readSenDone = true
   end
   
end

------------------------------------------------------------

function emulator.readLogHeader()

   local ff
   local uid
   local iid

   if not fd then return false end
   if rlhDone then return rlhDone end

   if rlhCount == 0 then
      io.readline(fd) -- read the comment line and toss .. assume one comment line only (!)
   end
   rlhCount = rlhCount + 1

   -- process logfile header 4 rows at a time so it keep cpu usage below cutoff
   -- do 4 rows each call to loop()

   for _ = 1, 4, 1 do
      logItems.line = io.readline(fd, true) -- true param removes newline
      if not logItems.line then
	 print("Read eror on log header file")
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
	 
	 jsonText = json.encode(allSensors)
	 ff = io.open("Apps/sensorLogEmAll.jsn", "w")
	 io.write(ff, jsonText)
	 io.close(ff)

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
	    iid = sensorFullID(tonumber(logItems.cols[2]), tonumber(logItems.cols[3]) )
	    logSensorByID[iid] = {}
	    logSensorByName[uid].label = logItems.cols[4]
	    logSensorByID[iid].label = logItems.cols[4]	    
	    logSensorByName[uid].sensorName = logItems.sensorName
	    logSensorByID[iid].sensorName = logItems.sensorName
	    logSensorByName[uid].unit = logItems.cols[5]
	    logSensorByID[iid].unit = logItems.cols[5]
	    logSensorByName[uid].id = tonumber(logItems.cols[2])
	    logSensorByID[iid].id = tonumber(logItems.cols[2])
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
      logItems.deviceID = tonumber(logItems.cols[2])
      if logItems.deviceID ~= 0 then -- if logItems.deviceID == 0 it's a message
	 for i = 3, #logItems.cols, 4 do
	    sf = sensorFullID(tonumber(logItems.cols[2]), tonumber(logItems.cols[i]))
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

function emulator.init(jtext)
   
   local ans
   local dev, emflag
   local text, jfile
   local fg

   if jtext then jfile = "Apps/" .. jtext else jfile = "Apps/sensorLogEm.jsn" end
   fg = io.readall(jfile)
   if not fg then print("Cannot read " .. jfile) else
      config=json.decode(fg)
   end

   for k,v in pairs(config.selectedSensors) do
      logSensorByName[k] = v
   end

   text = config.logFile
   fd = io.open(text, "r")
   if not fg then print("Cannot read " .. text) else emulator.readLogHeader() end
   
   dev, emflag = system.getDeviceType()
   
   ans = form.question(
      "Use sensor emulator?",
      "Log File "..config.logFile,
      "Config file /Apps/" .. jfile,
      3500, false, 0)
   
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

   local st={}
   local vv
   local ll
   
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
      if type(vv) ~= "table"  then
	 print("sensor not found in log header: "..v)
	 ll=nil
      else
	 if vv.sensorName ~= ll  then
	    table.insert(sensorTbl,
			 {id=tonumber(vv.id),param=0,sensorName="",
			  label=vv.sensorName})
	 end
	 table.insert(sensorTbl,
		      {id=tonumber(vv.id),param=tonumber(vv.param),
		       sensorName=vv.sensorName,
		       label=vv.label,unit=vv.unit})
	 ll = vv.sensorName -- see if next sensor is a different one
      end

   end
   
   return sensorTbl
end


function emulator.getSensorValueByID(ID, Param)
   -- fake it .. return the extra info anyway
   return emulator.getSensorById(ID, Param)
end

function emulator.getSensorByID(ID, Param)
      
   local returnTbl
   local sf
   local etS, etL
   local ic
   --local timSd60
   --local min, sec
   --local timstr

   -- defend against bad inputs or invalid sensor
   if (not ID) or (not Param) then return nil end
   sf = sensorFullID(ID, Param)
   if not logSensorByID[sf] then return nil end
   
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
	       print('Closing log replay file')
	       fd = nil
	       return nil
	    end
	 until tonumber(lastTimeBlock) > etS
      end
   end
   
   -- create the return table
   for _,v in ipairs(sensorTbl) do
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
	    print("Sensor not valid - Name: "..logSensorByID[sf].label..
		     "  ID: "..ID.."  Param: "..Param.."  Log File Time:  "
		     ..lastTimeBlock)
	    returnTbl.valid   = false
	 end
	 -- be defensive ..even if valid=false, set  values that won't cause error
	 returnTbl.decimals   = tonumber(logSensorByID[sf].decimals or 0)
	 returnTbl.value      = tonumber(logSensorByID[sf].value or 0)
	 returnTbl.valGPS     = tonumber(logSensorByID[sf].value or 0)	 
	 returnTbl.value      = returnTbl.value / 10^returnTbl.decimals
	 returnTbl.type       = logSensorByID[sf].type or 1
	 returnTbl.max        = logSensorByID[sf].max or 0
	 returnTbl.min        = logSensorByID[sf].min or 0
	 return returnTbl
      end
   end
   
   return nil
end

return emulator

--[[

Sample sensorLogEm.jsn file

{
"logFile":"Apps/DFM-LSO.log",
"selectedSensors":
   {
   "MGPS_Latitude":  true,
   "MGPS_Longitude": true,
   "CTU_Altitude":   true,
   "MSPEED_Velocity":true,
   "MGPS_Course":    true
   }
}

--]]
