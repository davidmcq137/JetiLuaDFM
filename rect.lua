PrettyPrint = require 'PrettyPrint'

local function init()

   sensors = system.getSensors()
   pretty_output = PrettyPrint(sensors)
   json_output = json.decode(sensors)

   print("Pretty:")
   print(pretty_output)
   print("json:")
   print(json_output)
end




--------------------------------------------------------------------------------

return {init=init, author="JETI model", version="1.0"}
