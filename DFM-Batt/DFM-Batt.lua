--[[

   ----------------------------------------------------------------------
   DFM-Batt.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local BattVersion = "0.1"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0

local sensorLalist = { "..." }  -- sensor labels
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor Units
local sensorTylist = { "..." }  -- sensor Type

local NUMBAT=6
local Battery={}
local selectedBatt = 0
local seenRX = false

-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimG.jsn")
  local obj = json.decode(file)cd 
  if(obj) then
    trans11 = obj[lng] or obj[obj.default]
  end
--]]
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select - done once at startup

local sensorLbl = "***"

local function readSensors()

   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	    table.insert(sensorTylist, sensor.type)
	 end
      end
   end
end

local function key0(key)
   local row = form.getFocusedRow() - 1
   if key == KEY_5 then
      form.preventDefault()
      if row >= 1 and row <= NUMBAT then
	 print("incrementing cyc for bat", row)
	 Battery[row].cyc = Battery[row].cyc + 1
	 selectedBatt = row
	 form.close(2)
      end
   end
   if key == KEY_ESC or (key == KEY_5 and row < 1) then
      form.preventDefault()
      local ans
      ans = form.question("Exit without selecting a battery?", nil, nil, 0, false, 5)
      print("ans", ans)
      if ans == 1 then form.close(2) else form.reinit(2) end
   end
end

local function close0()
   print("close0", form.getFocusedRow())
end

local function initForm0()
   local str
   form.addRow(4)
   form.addLabel({label="Battery", width=70, alignRight=true})
   form.addLabel({label="Cap (mAh)", width=80, alignRight=true})
   form.addLabel({label="Warning %", width=100, alignRight=true})
   form.addLabel({label="Cycles", width=60, alignRight=true})
   for i=1,NUMBAT,1 do
      if Battery[i].cap > 0 or Battery[i].warn > 0 then
	 form.addRow(4)
	 form.addLabel({label=i.."     ",      width=70,  alignRight=true})
	 str = string.format("%4d  ", Battery[i].cap)
	 form.addLabel({label=str,  width=80,  alignRight=true})
	 str = string.format("%3d   ", Battery[i].warn)
	 form.addLabel({label=str, width=100, alignRight=true})
	 str = string.format("%4d  ", Battery[i].cyc)
	 form.addLabel({label=str,  width=60,  alignRight=true})
      end
   end
end

local function battChanged(value, i, sub)
   Battery[i][sub] = value
end

local function keyForm(key)
   local row = form.getFocusedRow() - 1
   print("key, sf", key, subForm)
   print("row", row)
   if subForm == 2 and key == KEY_1 and row >= 1 and row <= NUMBAT then
      print("zeroing")
      Battery[row].cap = 0
      Battery[row].warn = 0
      Battery[row].cyc = 0
      form.reinit(2)
   end
end

local function initForm(sf)
   subForm = sf
   if sf == 1 then
      form.addRow(2)
      form.addLink((function() form.reinit(2) end), {label="Battery Setup>>"})

      form.addRow(2)
      form.addLink((function() form.reinit(3) end), {label="Settings>>"})      

      --form.addRow(2)
      --form.addLabel({label="Select Retract Switch (gear up)", width=220})
      --form.addInputbox(gearSwitch, true, gearSwitchChanged)
      form.addRow(1)
      form.addLabel({label="DFM - v."..BattVersion.." ", font=FONT_MINI, alignRight=true})
   elseif sf == 2 then
      form.setButton(1, "Clr", 1)
      form.addRow(4)
      form.addLabel({label="Battery", width=60, alignRight=true})
      form.addLabel({label="Cap (mAh)", width=80, alignRight=true})
      form.addLabel({label="Warning %", width=100, alignRight=true})
      form.addLabel({label="Cycles", width=60, alignRight=true})
      for i=1,NUMBAT,1 do
	 form.addRow(4)
	 form.addLabel({label=i.."     ", width=60, alignRight=true})
	 form.addIntbox(Battery[i].cap, 0, 9999, 5000, 0, 1,
			(function(x) return battChanged(x, i, "cap") end),
			{width=80})
	 form.addIntbox(Battery[i].warn, 0, 100, 50, 0, 1,
			(function(x) return battChanged(x, i, "warn") end),
			{width=80})      
	 form.addIntbox(Battery[i].cyc, 0, 999, 1, 0, 1,
			(function(x) return battChanged(x, i, "cyc") end),			
			{width=80})
      end
   elseif sf == 3 then
      form.addRow(1)
      form.addLabel({label="sf3"})
   end
end
--------------------------------------------------------------------------------

local function writeBattery()
   local fp
   local fn
   local mn
   local pf
   local emFlag

   emFlag = select(2, system.getDeviceType())
   if emFlag == 1 then pf = "" else pf = "/" end
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fn = pf .. "Apps/DFM-Batt/BD_" .. mn .. ".jsn"

   print("writeBattery:", fn)
   
   fp = io.open(fn, "w")
   if fp then io.write(fp, json.encode(Battery), "\n") end
   io.close(fp)
end

local function destroy()
   writeBattery()
end


-- Telemetry window draw functions

local function timePrint(width, height)

end

local function loop()

   local tim = system.getTimeCounter() / 1000
   
   if startTime > 0 then
      runningTime = tim-startTime
   end

   local txTel = system.getTxTelemetry()
   local emFlag = select(2, system.getDeviceType())

   if ( (emFlag ~= 1 and txTel.rx1Percent > 0) or (emFlag == 1 and system.getInputs("SA") == 1))
   and not seenRX then -- we see an RX
      system.registerForm(2, 0, "Select Flight Battery", initForm0, key0, nil, close0)
      startTime = system.getTimeCounter() / 1000.0
      seenRX = true
   end
end

local function init()

   local emFlag
   local pf
   local mn
   local fn
   local file

   emFlag = select(2, system.getDeviceType())
   if emFlag == 1 then pf = "" else pf = "/" end
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fn = pf .. "Apps/DFM-Batt/BD_" .. mn .. ".jsn"

   file = io.readall(fn)

   print("file:", file)

   if file then
      Battery = json.decode(file)
   else
      for i=1,NUMBAT,1 do
	 Battery[i] = {}
	 Battery[i].mAh = 0
	 Battery[i].cap = 0
	 Battery[i].cyc = 0
	 Battery[i].warn = 0
      end
      system.messageBox("No Battery data read: initializing")
   end
   
   system.registerForm(1, MENU_APPS, "Battery Tracker", initForm, keyForm)
   system.registerTelemetry(1, "Battery Tracker", 4, timePrint)

   readSensors()
   setLanguage()

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=BattVersion, name="Battery Tracker", destroy=destroy}
