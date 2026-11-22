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
logItems.lastRead={}
local start_time

logItems.selectedSensors = {MGPS_Latitude  =1, -- keyvalues irrelevant for now, just need to be true
			    MGPS_Longitude =2,
			    CTU_Altitude   =3,
			    ["CBOX400_U Accu 1"]=10,
			    ["Rx1 REX10_Q"]=11,
			    ["Rx2 REX12 Q"]=12,
			    ["MUI-30_Current"]=13,
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
   start_time = tonumber(logItems.cols[1])
   local m,s=math.modf(start_time/60000)
   s=math.floor(s*60)
   print("Start time is", start_time, string.format("%d:%02d", m, s))
end

function readLogTimeBlock()

   logItems.timestamp = logItems.cols[1]

   repeat
      logItems.deviceID = tonumber(logItems.cols[2])
      
      if tonumber(logItems.timestamp) == 525036 or tonumber(logItems.timestamp) == 524410 then
       	 print("Message: logItems.cols:", logItems.cols[1],logItems.cols[2],logItems.cols[6])
       	 print("Message: timestamp, deviceID", logItems.timestamp, logItems.deviceID)
      end
      
      if logItems.deviceID ~= 0 then -- if logItems.deviceID == 0 then it's a message
	 for i = 3, #logItems.cols, 4 do
	    local sn = logSensorNameByID[sensorID(logItems.cols[2], logItems.cols[i])]
	    if sn then
	       --print("+", sn, logItems.timestamp, logItems.lastRead[sn])
	       if logItems.lastRead[sn] then
		  --print(tonumber(logItems.timestamp), logItems.lastRead[sn])
		  if tonumber(logItems.timestamp) - logItems.lastRead[sn] >= 3500 then
		     local m,s=math.modf( (tonumber(logItems.lastRead[sn]) - start_time )/60000)
		     s=math.floor(s*60)
		     print("Message: >=3.5s on", sn, "delta=", -- JETI apparently considers no signal for 3.5s
			   tonumber(logItems.timestamp) - logItems.lastRead[sn], -- to be a gap as observed
			   "at",string.format("%d:%02d", m, s))                  -- in the JETI studio app
		  end
	       end
	       logItems.lastRead[sn]=tonumber(logItems.timestamp)
	       --print("*", sn, logItems.lastRead[sn])
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
	 local m,s=math.modf( (tonumber(logItems.timestamp) - start_time)/60000)
	 s=math.floor(s*60)
	 print("Message:", logItems.cols[6], "at", string.format("%d:%02d", m, s), logItems.timestamp)
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





