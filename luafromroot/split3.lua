function split(str, ch)
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

function sensorName(device_name, param_name)
   return device_name .. "_" .. param_name -- sensor name is human readable e.g. CTU_Altitude
end

function sensorID(devID, devParm)
   return devID..devParm -- sensor ID is machine readable e.g. 420460025613 (13 concat to 4204600256)
end

function packAngle(angle)
   local d, m = math.modf(angle)
   return math.floor(m*60000+0.5) + (math.floor(d) << 16) -- math.floor forces to int
end

function unpackAngle(packed)
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end

-- "globals" for log reading
local logItems={}
logItems.cols={}
logItems.vals={}
logItems.selectedSensors = {MGPS_Latitude  =1, -- keyvalues irrelevant for now, just need to be true
			    MGPS_Longitude =2,
			    CTU_Altitude   =3,
			    MSPEED_Velocity=4,
			    MGPS_Course    =5}
local logSensorNameByID = {}


function readLogHeader()

   io.read("l") -- read the comment line and toss .. assume one comment line only (!)
   while true do
      logItems.line = io.read("l") ---------------change to Jeti readline fcn here -------------
      logItems.cols = split(logItems.line, ";")
      logItems.timestamp = tonumber(logItems.cols[1])
      if logItems.timestamp ~= 0 then break end
      if logItems.cols[3] == "0" then
	 logItems.prefix=logItems.cols[4]
      else
	 logItems.name  = sensorName(logItems.prefix, logItems.cols[4])
	 if logItems.selectedSensors[logItems.name] then
	    logSensorNameByID[sensorID(logItems.cols[2], logItems.cols[3])] = logItems.name
	 end
      end
   end
   -- for debug print out the selected sensors
   for k, v in pairs(logSensorNameByID) do
      print (k, v)
   end
end

function readLogTimeBlock()

   logItems.timestamp = logItems.cols[1]
   logItems.deviceID = tonumber(logItems.cols[2])

   repeat
      if logItems.deviceID ~= 0 then -- if logItems.deviceID == 0 then it's a message .. implement later
	 for i = 3, #logItems.cols, 4 do
	    local sn = logSensorNameByID[sensorID(logItems.cols[2], logItems.cols[i])]
	    if sn then
	       logItems.encoding = tonumber(logItems.cols[i+1])
	       logItems.decimals = tonumber(logItems.cols[i+2])
	       logItems.value    = tonumber(logItems.cols[i+3])
	       if logItems.encoding == 9 then
		  local latlong = unpackAngle(logItems.value)
		  if logItems.cols[i] == "3" then
		     if logItems.decimals == 3 then -- "West" .. make it - (NESW coded in dec plcs as 0,1,2,3)
			logItems.vals[sn] = -latlong
		     else
			logItems.vals[sn] = latlong
		     end
		  elseif logItems.cols[i] == "2" then
		     if logItems.decimals == 2 then -- "South" .. make it negative
			logItems.vals[sn] = -latlong
		     else
			logItems.vals[sn] = latlong
		     end
		  end
	       else
		  logItems.vals[sn] = logItems.value / 10^logItems.decimals
	       end
	    end
	 end
      else
	 print("Message:", logItems.cols[6])
      end
      
      logItems.line = io.read("l")

      if not logItems.line then
	 return nil
      end

      logItems.cols = split(logItems.line, ';')

      if logItems.cols[1] ~= logItems.timestamp then -- new time block, dump vals and reset
	 return logItems.vals
      end
   until false
end

local fp = assert(io.input("14-06-50.log", "r"))
local prtlabel = false

readLogHeader()

repeat
   local rltb = readLogTimeBlock()
   if rltb then
      local out = string.format("%15f, ", tonumber(logItems.timestamp)/1000.)
      local lbl = string.format("%15s, ", "time")
      
      for k,v in pairs(logItems.vals) do
	 lbl = lbl ..string.format("%15s", k)..", "
	 if logItems.vals[k] then
	    out = out .. string.format("%15f", logItems.vals[k]) ..", "
	 else
	    out = out .. string.format("%15s", "---") .. ", "
	 end
      end
      if not printlbl then
	 print(lbl)
	 printlbl = true
      end
      
      print(out)
   end
until not rltb





