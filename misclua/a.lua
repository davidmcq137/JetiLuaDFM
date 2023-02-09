local tID 
origgdi = system.getDeviceInfo

function mygdi(id)
   print("mygdi, id", id)
end

local done = false
local function loop()

   local tttt
   local ttt = system.getDevices()
   if ttt then
      for k,v in pairs(ttt) do
	 if type(v) == "table" then
	    print(k, v.hw, v.name, v.id)
	    tttt = system.getDeviceInfo(v.id)
	    if tttt then
	       local str = ""
	       for kk,vv in pairs(tttt) do
		  --print(kk,vv)
		  str = str .." " ..kk.." "..tostring(vv)
	       end
	       print(str)
	    end
	 end
      end
   end
   
end

local function printForm()

end

local function init()

   local lbl
   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if sensor.param == 0 then
	 --print("lbl", sensor.label)
	 lbl = sensor.label
      end
      if lbl == "Turbine" then
	 --print(i,lbl, sensor.id, sensor.param)
	 tID = sensor.id
      end
   end


   --[[
   ttt = system.getDeviceInfo(1448520677)
   if ttt then
      print("got ttt")
      for k,v in pairs(ttt) do
	 print("1", k,v)
	 if type(v) == "table" then
	    for kk,vv in pairs(v) do
	       print("2", kk, vv)
	    end
	 end
      end
   else
      print("ttt is nil")
   end
   --]]



end

return {init=init, loop=loop, author="DFM", version="1", name="a.lua"}
