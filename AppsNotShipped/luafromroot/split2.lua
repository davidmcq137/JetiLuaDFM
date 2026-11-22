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

-- sensor name is human readable e.g. CTU_Altitude
-- sensor ID is machine readable e.g. 420460025613 (13 concat to 4204600256)

function sensorName(device_name, param_name)
   return device_name .. "_" .. param_name
end

function sensorID(devID, devParm)
   return devID..devParm
end

function pack_angle(angle)
   local d, m = math.modf(angle)
   return math.floor(m*60000+0.5) + (math.floor(d) << 16) -- math.floor forces to int
end

function unpack_angle(packed)
   return ((packed >> 16) & 0xFF)
          + ((packed & 0xFFFF) * 0.001)/60
end

function contains2(tbl1, tbl2, val1, val2)
   local foundk = 0
   for k = 1, #tbl1, 1 do
      if tbl1[k] == val1 and tbl2[k] == val2 then
	 foundk=k
      end
   end
   return foundk
end

local fp = assert(io.input("14-06-50.log", "r"))

local items = {}
local line

local sensorNameByID = {}

local prefix

local selectedSensors = {MGPS_Latitude=1, MGPS_Longitude=2, CTU_Altitude=3, MSPEED_Velocity=4, MGPS_Course=5}

line = io.read("l")

while true do

   line = io.read("l")
   items = split(line, ";")
   
   local timestamp = tonumber(items[1])
   if timestamp ~= 0 then break end
   if items[3] == "0" then
      prefix=items[4]
   else
      local name  = sensorName(prefix, items[4])
      if selectedSensors[name] then
	 sensorNameByID[sensorID(items[2], items[3])] = name
      end
   end
end

-- for debug print out the selected sensors

for k, v in pairs(sensorNameByID) do
      print (k, v)
end

--arrive here with first line of real data (not header) in variable <line> and split into table <items>

local prtlabel = false
local vals={}

repeat 

   local timestamp = tonumber(items[1])

   if device_id ~= 0 then -- argh this is wrong .. device_id not set so null .. should be items[2]
      for i = 3, #items, 4 do
	 local sn = sensorNameByID[sensorID(items[2], items[i])]
	 if  sn then

	    local encoding = tonumber(items[i+1])
	    local decimals = tonumber(items[i+2])
	    local value    = tonumber(items[i+3])
	 

	    if encoding == 9 then
	       local latlong = unpack_angle(value)
	       if items[i] == "3" then
		  if decimals == 3 then -- "West" .. make it - (NESW coded in decimal places as 0,1,2,3)
		     vals[sn] = -latlong
		  else
		     vals[sn] = latlong
		  end
	       elseif items[i] == "2" then
		  if decimals == 2 then -- "South" .. make it negative
		     vals[sn] = -latlong
		  else
		     vals[sn] = latlong
		  end
	       end
	    else
	       vals[sn] = value / 10^decimals
	    end
	 end
      end
   end
   
   
   line = io.read("l")
   if not line then break end

   items = split(line, ';')

   if items[1] ~= timestamp then -- new time block, dump vals and reset

      local out = string.format("%15d, ", timestamp)
      local lbl = string.format("%15s, ", "time")

      for k,v in pairs(selectedSensors) do
	 lbl = lbl ..string.format("%15s", k)..", "
	 if vals[k] then
	    out = out .. string.format("%15f", vals[k]) ..", "
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

until false


