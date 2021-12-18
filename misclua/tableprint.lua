--PrettyPrint = require 'PrettyPrint'

--local function init()

   --sensors = system.getSensors()
   --print("#sensors: ", #sensors)
   --pretty_output = PrettyPrint(sensors)
   --json_output = json.encode(sensors)

   --print("Pretty:")
   --print(pretty_output)
   --print("json:")
   --print(json_output)

--------------------------------------------------------------------------------
local function init()
   
   local sensors = system.getSensors()
   for i,sensor in ipairs(sensors) do
      if (sensor.type == 5) then
	 if (sensor.decimals == 0) then
	    -- Time
	    print (string.format("%s = %d:%02d:%02d", sensor.label, sensor.valHour,
				 sensor.valMin, sensor.valSec))
	 else
	    -- Date
	    print (string.format("%s = %d-%02d-%02d", sensor.label, sensor.valYear,
				 sensor.valMonth, sensor.valDay))
	 end
      elseif (sensor.type == 9) then
	 -- GPS coordinates
	 local nesw = {"N", "E", "S", "W"}
	 local minutes = (sensor.valGPS & 0xFFFF) * 0.001
	 local degs = (sensor.valGPS >> 16) & 0xFF
	 print (string.format("%s = %d° %f' %s", sensor.label,
			      degs, minutes, nesw[sensor.decimals+1]))
      else
	 if(sensor.param == 0) then
	    -- Sensor label
	    print (string.format("%s:",sensor.label))
	 else
	    -- Other numeric value
	    print (string.format("%s = %.1f %s (min: %.1f, max: %.1f)", sensor.label,
				 sensor.value, sensor.unit, sensor.min, sensor.max))
	 end
      end
      print("Sensor id, param, type: ", sensor.id, sensor.param, sensor.type)
   end
end

return {init=init, author="JETI model", version="1.0"}
