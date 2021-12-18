
local function loop()

end

local function init()

   local sensorLalist={}
   local sensorIdlist={}
   local sensorPalist={}
   local sensorLbl="***"
   
   local sensors = system.getSensors()
   print("sensors:", sensors)

   for i, sensor in ipairs(sensors) do
      --print(string.format("i:%d sensor.id:%d sensor.param:%d label:%s", i, sensor.id, sensor.param, sensor.label))
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
   end
   
   local json = json.encode(sensors)
   print("json:", json)
   local fg = io.open("sensorlog.jsn","w")
   print("fg:", fg)
   io.write(fg, json)
   io.close(fg)

end




--------------------------------------------------------------------------------

return {init=init, loop=loop, name="jsonlog", author="DFM", version="1.0"}
