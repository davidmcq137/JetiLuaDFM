
local function loop()

local function printForm()

end

local function init()
   local turbineID
   
   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if sensor.param == 0 and sensor.label == "Turbine" then
	 turbineID = sensor.id
	 print("turbine id", sensor.id)
      end
   end

   local table = system.getDeviceInfo(turbineID)
   for k,v in pairs(table) do
      print(k,v)
   end
   
end



return {init=init, loop=loop, author="DFM", version="1", name="x.lua"}


