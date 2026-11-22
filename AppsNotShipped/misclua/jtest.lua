local appName = "Test"

local teleSensors = {"T1 EGT", "T1 RPM", "T1 Pump", "T1 Batt", "T1 Status",
	      "T2 EGT", "T2 RPM", "T2 Pump", "T2 Batt", "T2 Status"
}

local teleNames = {"EGT", "RPM", "Pump", "Batt", "Status"}

local sensorID = { {EGT=0,RPM=0,Pump=0,Batt=0,Status=0}, {EGT=0,RPM=0,Pump=0,Batt=0,Status=0} }


local function tsCallback(idx, tt, nn)
   sensorID[tt][teleNames[nn]] = idx
   print(json.encode(sensorID))
end

local function initForm(formId)

   local numTurbines = 2
   local numNames = #teleNames

   for turbine = 1, numTurbines, 1 do
      for name = 1, #teleNames, 1 do
	 form.addRow(2)
	 form.addLabel({label=string.format("Turbine %d %s", turbine, teleNames[name])})
	 local ii = sensorID[turbine][teleNames[name]]
	 form.addSelectbox(teleSensors, ii, true, (function(x) return tsCallback(x, turbine, name) end))
      end
   end

end


local function loop()

end

--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function init()
   system.registerForm(1,MENU_APPS,appName,initForm)
end

return { init=init, loop=loop, author="DFM", version="1.00",name=appName}
