local M = {}

local telem = {}
telem.Lalist = {}
telem.Idlist = {}
telem.Palist = {}
telem.Unlist = {}

-- this table is replicated in drawColor.lua ... must change both places
local colorSelect = {"None", "Rx1 Q", "Rx1 A1","Rx1 A2","Rx2 Q", "Rx2 A1", "Rx2 A2", "P4"}	 
local csFixed = #colorSelect

-- Have to re-read sensors since we swapped out selTeleCmd

local function readSensors(tbl)
   local sensors = system.getSensors()
   for idx, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param ~= 0 and sensor.type ~=9 and sensor.type ~=5 then
	    table.insert(tbl.Lalist, sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	    table.insert(tbl.Unlist, sensor.unit)
	 end
      end
   end
end

local function changedMax(val, settings, mapV, setMAX)
   settings.maxRibbon = val
   setMAX(val, settings, mapV)
end

local function changedVal(val, settings, cc)
   if cc == "CS" then
      settings.colorSelect = val
      if val > csFixed then
	 settings.csId = telem.Idlist[val-csFixed]
	 settings.csPa = telem.Palist[val-csFixed]
	 settings.csLa = telem.Lalist[val-csFixed]
	 settings.csUn = telem.Unlist[val-csFixed]
      else
	 settings.csId = 0
	 settings.csPa = 0
	 settings.csLa = ""
	 settings.csUn = ""
      end
      print("cs", settings.csId, settings.csPa, settings.csLa, settings.csUn)
   elseif cc == "ms" then
      settings.msMinSpacing = val
   elseif cc == "m" then
      settings.mMinSpacing = val
      settings.mMinSpacing2 = val^2
   elseif cc == "RS" then
      settings.ribbonScale = val
   end
end

function M.settings(settings, mapV, setMAX)

   readSensors(telem)

   for idx, label in ipairs(telem.Lalist) do
      table.insert(colorSelect, label)
   end
   
   form.setTitle("History ribbon settings")

   form.addRow(2)
   form.addLabel({label="Max points in ribbon", width=220})
   form.addIntbox(settings.maxRibbon, 0,1000,15,0,1,
		  (function(x) return changedMax(x, settings, mapV, setMAX) end))

   form.addRow(2)
   form.addLabel({label="Min ribbon time spacing", width=220})
   form.addIntbox(settings.msMinSpacing, 0,10000,0,0,10,
		  (function(x) return changedVal(x, settings, "ms") end), {label=" ms", width=100})

   form.addRow(2)
   form.addLabel({label="Min ribbon distance spacing", width=240})
   form.addIntbox(settings.mMinSpacing, 0,1000,3,0,1,
		  (function(x) return changedVal(x, settings,  "m") end), {label=" m"})

   form.addRow(2)
   form.addLabel({label="Ribbon color source", width=220})
   form.addSelectbox(colorSelect, settings.colorSelect, true,
		     (function(x) return changedVal(x, settings, "CS") end))

   form.addRow(2)
   form.addLabel({label="Ribbon color source scale", width=220})
   form.addIntbox(settings.ribbonScale, 1,10000,100,0,1,
		  (function(x) return changedVal(x, settings,  "RS") end))


   return
end

return M

