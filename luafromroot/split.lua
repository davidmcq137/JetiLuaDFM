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
local items
local line


local sensor={}
sensor.time = {}
sensor.id =   {}
sensor.parm = {}
sensor.name = {}
sensor.unit = {}

local prefix

local selectedSensors=   { ["MGPS_Latitude"]  =true,
   ["MGPS_Longitude"] =true,
   ["CTU_Altitude"]   =true,
   ["MSPEED_Velocity"]=true,
   ["MGPS_Course"]    =true} 


line = io.read("l")

while true do

   line = io.read("l")
   items = split(line, ";")

   if tonumber(items[1]) ~= 0 then break end
   if tonumber(items[3]) == 0 then prefix=items[4] end

   if selectedSensors[prefix.."_"..items[4] ] then
      table.insert(sensor.time, tonumber(items[1]))
      table.insert(sensor.id, tonumber(items[2]))
      table.insert(sensor.parm, tonumber(items[3]))
      table.insert(sensor.name, prefix.."_"..items[4])
      table.insert(sensor.unit, items[5])

   end
   
end

-- for debug print out the selected sensors

for k=1, #sensor.id, 1 do
   print(k, sensor.time[k], sensor.id[k], sensor.parm[k], sensor.name[k], sensor.unit[k])
end

--arrive here with first line of real data (not header) in variable <line> and split into table <items>

local vals={}
local prtlabel = false

repeat 

   local timestamp = tonumber(items[1])
   
   for i = 3, #items, 4 do
      local cc = contains2(sensor.id, sensor.parm, tonumber(items[2]), tonumber(items[i]) )
      if cc ~= 0 then
	 if tonumber(items[i+1]) == 9 and tonumber(items[i]) == 3 then
	    minutes = (tonumber(items[i+3]) & 0xFFFF) * 0.001
	    degs = (tonumber(items[i+3]) >> 16) & 0xFF
	    local longitude = degs + minutes/60
	    if tonumber(items[i+1]) == 3 then -- "West" .. make it - (NESW coded in decimal places as 0,1,2,3)
	       longitude = longitude * -1
	    end
	    vals[sensor.name[cc]] = longitude
	 elseif tonumber(items[i+1]) == 9 and tonumber(items[i]) == 2 then
	    minutes = (tonumber(items[i+3]) & 0xFFFF) * 0.001
	    degs = (tonumber(items[i+3]) >> 16) & 0xFF
	    local latitude = degs + minutes/60
	    if tonumber(items[i+1]) == 2 then -- "South" .. make it negative
	       latitude = latitude * -1
	    end
	    vals[sensor.name[cc]] = latitude
	 else
	    vals[sensor.name[cc]] = items[i+3] / 10^items[i+2]
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


