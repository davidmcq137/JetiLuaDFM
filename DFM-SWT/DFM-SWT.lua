--[[

   DFM-SWT.lua

   Requested by H. Curzon. Counts presses on momentary switch. Can
   announce a telemetry value or pulse a virtual function for
   sequences of counted short presses or one long press.

   Can count from 1..maxPressCount short presses, and one long
   press. Assign one telem value or one virtual function to each of
   the short press counts or the long press to announce that telemetry
   value or pulse that function from -1 to 1 to -1 in 100ms.

   Virtual function is SL1 .. SLN for N short pulses, and SLL for the
   long pulse. After setting up in the DFM-SWT menu, look in the TX
   menu for single voice announcements. Create a new line with "+",
   then when you assign the switch look for the SL* names on the User
   Applications sub-menu.

   Value t1 controls time limit for sequential pulses being part of same
   count, t2 controls time to wait to define end of pulse train.
 
   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - Sept 2020
   Version 0.2 - Sept 2020
   Version 0.3 - Oct  2020
   Version 0.4 - Apr  2022

   Created and tested on DC/DS-24 emulator, tested on DS-24 TX

   TO DO: some telem names (e.g. "Rel. Alt" "Abs. Alt" from MVARIO)
   have embedded spaces and dots. I am replacing the spaces with "_"
   but not doing anything with the dots and this is likely an issue
   with some systems e.g. it makes filenames like Rel._Alt.wav .. so
   need to deal with the dots somehow. Probably can just remove them?

   See line 357:

   fn = "/Apps/DFM-SWT/"..locale .."/"..string.gsub(teleSeLs[pC], " ", "_")..".wav"

--]]

if not sharedVar then sharedVar = {} end

local appName = "Short/Long Switch"
local SWTVersion= 0.5
local currSwitchState
local lastSwitchState
local switch
local t1, t2
local emFlag
local ctrlOffTime = {}
local vCtrl = {}

local teleSe
local teleSeId
local teleSePa
local teleSeUn
local teleSeLs
local teleSeLa
local teleSeDp

-- unit tables in same order as Jeti UnitIDX parameter in model file

local lengthUnit = {"m", "km", "ft.", "yd.", "mi."}
local lengthMult = {1.0, 0.001, 3.2808, 1.0936, 0.0006214}
local speedUnit  = {"m/s", "km/h", "ft/s", "mph", "kt."}
local speedMult  = {1.0, 3.6, 3.2800, 2.2369, 1.9438}

local UnIDX = {}

local maxPressCount = 3
local locale

local sensorLalist = { "...", "<Function>"}
local sensorLslist = { "...", "<F>"}
local sensorIdlist = { "...", 0}
local sensorPalist = { "...", 0}
local sensorUnlist = { "...", ""}
local sensorDplist = { "...", 0}

local txTelem = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		 "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		 "rxBVoltage", "rxBPercent", "photoValue"}

local txTelemUn = {"V", "%", "mA", "mAh",
		   "%", "V", "%", "V",
		   "V", "%", ""}

local txTelemDp = {2, 0, 0, 0,
		   0, 2, 0, 2,
		   2, 0, 0}

local txTRSSI = {"rx1A1", "rx1A2", "rx2A1",
		 "rx2A2", "rxBA1", "rxBA2"}

local txTRSSIUn = {"", "", "",
		   "", "", ""}

local txTRSSIDp = {0,0,0,
		   0,0,0}

		      
local maxTele
local maxTxTele
local maxRSSITele
local maxAPPTele

local startUp = true
local upTime = 0
local pressCount = 0
local lastUpTime = 0

local function switchChanged(value)
   switch = value
   system.pSave("switch", switch)
end

local function unitChanged(value, idx)
   teleSeUd[idx] = value
   system.pSave("teleSeUd", teleSeUd)
end

local function dpChanged(value, idx)
   teleSeDp[idx] = value
   system.pSave("teleSeDp", teleSeDp)
end

local function unassignTele(idx)
   teleSe[idx] = 0
   teleSeId[idx] = 0
   teleSePa[idx] = 0
   teleSeLa[idx] = ""
   teleSeLs[idx] = ""
   teleSeUn[idx] = ""
   teleSeDp[idx] = 0
end

local function teleChanged(value, idx)

   local ss

   if type(value) ~= "number" then
      print("DFM-SWT - teleChanged - value not number type", type(value))
   end
      
   if value > 2 then -- a telem sensor
      --print("teleChanged value, idx", value, idx)
      teleSe[idx] = value
      teleSeId[idx] = sensorIdlist[value]
      teleSePa[idx] = sensorPalist[value]
      teleSeUn[idx] = sensorUnlist[value]
      teleSeUd[idx] = 1 -- native units
      teleSeLs[idx] = sensorLslist[value]
      teleSeLa[idx] = sensorLalist[value]      
      teleSeDp[idx] = sensorDplist[value]

      if vCtrl[idx] and vCtrl[idx] ~= 0 then
	 system.unregisterControl(vCtrl[idx])
	 vCtrl[idx] = 0
      end

      --print("teleSeLa[idx], teleSeUn[idx], UnIDX[teleSeLa[idx]",
	--    teleSeLa[idx], teleSeUn[idx], UnIDX[teleSeLa[idx]])

      -- Jeti uses the parameter UnitIDX in the model file to record non-native units.
      -- A value of 0 indicates native units, which is the first entry in our unit
      -- tables (lengtUnit and speedUnit) hence the 1 + ...
      -- if UnIDX is nil (should not be) be defensive and use native units ( .. or 0)

      if value <= maxRSSITele then -- if from another app, set to native units
	 teleSeUd[idx] = 1 + (UnIDX[teleSeLa[idx]] or 0)
      else
	 teleSeUd[idx] = 1
      end
      
   elseif value == 2 then -- <function>
      unassignTele(idx)
      teleSe[idx] = value
      vCtrl[idx] = 0
      if idx <= maxPressCount then ss = tostring(idx) else ss = "L" end
      for k=1,10,1 do
	 local used = false
	 for j in ipairs(vCtrl) do
	    if vCtrl[j] == k then used = true end
	 end
	 if not used then
	    vCtrl[idx] = system.registerControl(k, "Press "..ss, "SL"..ss)	 
	    if vCtrl[idx] then break end
	 end
      end
      if not vCtrl[idx] then
	 system.messageBox("DFM-SWT cannot register control SW" .. ss)
	 print("DFM-SWT: cannot register control", idx, "Press "..idx, "SW"..idx)
      else
	 print("DFM-SWT: Control SW".. ss .." reg to " .. vCtrl[idx])
      end
      if vCtrl[idx] and vCtrl[idx] ~= 0 then
	 system.setControl(vCtrl[idx], -1, 0)
	 ctrlOffTime[idx] = 0
      end

   elseif value == 1 then -- "..." unassign
      unassignTele(idx)
      if vCtrl[idx] and vCtrl[idx] ~= 0 then
	 system.unregisterControl(vCtrl[idx])
	 --print("DFM-SWT: unregister", idx, vCtrl[idx])
	 vCtrl[idx] = 0
      end
   end

   --print("pSave - teleSe")
   --for k,v in ipairs(teleSe) do
   --   print(k,v, teleSeLa[k])
   --end
   
   system.pSave("teleSe", teleSe)
   system.pSave("teleSeId", teleSeId)
   system.pSave("teleSePa", teleSePa)
   system.pSave("teleSeUn", teleSeUn)
   system.pSave("teleSeUd", teleSeUd)
   system.pSave("teleSeDp", teleSeDp)
   system.pSave("teleSeLa", teleSeLa)
   system.pSave("teleSeLs", teleSeLs)
   system.pSave("vCtrl", vCtrl)

   form.reinit(1)
   
end

local function initForm(subform)

   local lab
   local idef
   
   if subform == 1 then

      form.setTitle(appName..": Main")
      form.addRow(2)
      form.addLabel({label="Switch", width=220})
      form.addInputbox(switch, true, switchChanged)

      for i = 1, maxPressCount, 1 do
	 if teleSe[i] == 2  then
	    lab = i.." Press - Func SL"..i
	 else
	    lab = i .. " Press - Sensor"
	 end
	 form.addRow(2)
	 --print("* i, teleSe[i]", i, teleSe[i], maxRSSITele)
	 if teleSe[i] > maxRSSITele then
	    --print(">maxRSSITele", maxRSSITele+1, maxAPPTele)
	    idef = 1
	    for j=maxRSSITele+1, maxAPPTele, 1 do
	       --print(i,j,teleSeLa[i], sensorLalist[j])
	       if teleSeLa[i] == sensorLalist[j] then
		  --print("match at", j)
		  idef = j
		  break
	       end
	    end
	    if idef == 1 then print("no match") end
	 else
	    idef = teleSe[i]
	 end

	    
	 form.addLabel({label=lab, width=155})	 
	 form.addSelectbox(sensorLalist, idef, true,
			   (function(x) return teleChanged(x, i) end) , {alignRight=true})
      end
      form.addRow(2)
      
      if teleSe[maxPressCount+1] == 2  then
	 lab = "L Press - Func SLL"
      else
	 lab = "L Press - Sensor"
      end

      if teleSe[maxPressCount+1] > maxRSSITele then
	 idef = 1
	 for j=maxRSSITele+1, maxAPPTele, 1 do
	    --print("L", j, teleSeLa[maxPressCount+1], sensorLalist[j])
	    if teleSeLa[maxPressCount+1] == sensorLalist[j] then
	       --print("match at", j)
	       idef = j
	       break
	    end
	 end
	 if idef == 1 then print("no match") end	 
      else
	 idef = teleSe[maxPressCount + 1]
      end
      
      
      form.addLabel({label=lab, width=155})
      form.addSelectbox(sensorLalist, idef, true,
			(function(x) return teleChanged(x, maxPressCount + 1) end) , {alighRight=true})
      
      form.addLink((function() form.reinit(2) end), {label = "Units >>", width=140})
      form.addRow(2)
      
      form.addLink((function() form.reinit(3) end), {label = "Decimals >>", width=140})
      form.addRow(2)

      form.addRow(1)
      form.addLabel({label="DFM-SWT.lua Version "..SWTVersion.." ",
		     font=FONT_MINI, alignRight=true})
   elseif subform == 2 then

      form.setTitle(appName..": Units")
      for i = 1, maxPressCount + 1, 1 do
	 form.addRow(2)
	 if teleSe[i] == 2  then
	    lab = "Function SL"..i
	 elseif teleSe[i] > 2 then
	    lab = teleSeLa[i]
	    --print("sf2 .. lab: " .. lab)
	 else
	    if i == maxPressCount + 1 then
	       lab = "L Press Units"
	    else
	       lab = tostring(i) .." Press Units"
	    end
	 end
	 
	 form.addLabel({label=lab, width=220}) -- was 155
	 if teleSeUn[i] == "m" and teleSe[i] <= maxTele then
	    form.addSelectbox(lengthUnit, teleSeUd[i], true,
			      (function(x) return unitChanged(x, i) end) )
	 elseif teleSeUn[i] == "m/s" and teleSe[i] <= maxTele then
	    form.addSelectbox(speedUnit, teleSeUd[i], true,
			      (function(x) return unitChanged(x, i) end) )
	 elseif teleSe[i] <= maxTele then
	    form.addSelectbox({teleSeUn[i]}, 1, true)			     
	 elseif teleSe[i] > maxTele then -- display but cannot change SYS telem units
	    form.addSelectbox({teleSeUn[i]}, 1, true)
	 end
	 
      end
      
      form.addRow(2)
      form.addLink((function() form.reinit(1) end),
	 {label = "Back to main menu",font=FONT_BOLD})

   elseif subform == 3 then

      form.setTitle(appName..": Decimals")

      for i = 1, maxPressCount + 1, 1 do
	 form.addRow(2)
	 if teleSe[i] == 2 then
	    lab = "Function SL"..i
	 elseif teleSe[i] > 2 then
	    lab = teleSeLa[i]
	 else
	    if i == maxPressCount + 1 then
	       lab = "L Press Decimals"
	    else
	       lab = tostring(i) .." Press Decimals"
	    end
	 end
	 form.addLabel({label=lab, width=220}) -- was 155
	 if teleSeDp and teleSeDp[i] and teleSe[i] > 2 then
	    form.addIntbox(teleSeDp[i], 0, 2, 0, 0, 1,
			   (function(x) return dpChanged(x, i) end) )
	 end
      end
      
      form.addRow(2)
      form.addLink((function() form.reinit(1) end),
	 {label = "Back to main menu",font=FONT_BOLD})
   end

end

local dev = ""
local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    dev = sensor.label
	 else
	    table.insert(sensorLalist, dev.."."..sensor.label)
	    table.insert(sensorLslist, sensor.label)	    
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	    table.insert(sensorDplist, sensor.decimals)
	    --print("label, units", sensor.label, sensor.unit)
	 end
      end
   end
end

local function convertUnits(pC, sv, su)

   local rv, ru
   
   if teleSeUn[pC] == "m" then
      rv = sv * lengthMult[teleSeUd[pC]]
      ru = lengthUnit[teleSeUd[pC]]
   elseif teleSeUn[pC] == "m/s" then
      rv = sv * speedMult[teleSeUd[pC]]
      ru = speedUnit[teleSeUd[pC]]
   else
      rv = sv
      ru = su
   end

   return rv, ru
end

local function pressAction(pC)

   local now
   local value, unit, dp
   local fn
   local sensor
   local txTele, txRSSI
   
   --print("pA: pC, teleSe, vCtrl", pC, teleSe[pC], vCtrl[pC])

   now = system.getTimeCounter()
   fn = "/Apps/DFM-SWT/"..locale .."/"..string.gsub(teleSeLs[pC], " ", "_")..".wav"
   if emFlag then print("Filename: "..fn) end
   if teleSe[pC] == 2 then -- channel selected
      if emFlag then print("DFM-SWT <em>: pC, teleSe[pC]:", pC, teleSe[pC]) end
      if vCtrl[pC] and vCtrl[pC] > 0 then
	 system.setControl(vCtrl[pC], 1, 0)
	 ctrlOffTime[pC] = now + 100
	 fn = nil
      end
   elseif teleSe[pC] > 2 and teleSe[pC] <= maxTele then -- telemetry channel selected
      sensor = system.getSensorByID(teleSeId[pC], teleSePa[pC])
      if sensor and sensor.valid then
	 value, unit = convertUnits(pC, sensor.value, sensor.unit)
	 dp = teleSeDp[pC]
      end
   elseif teleSe[pC] > maxTele and teleSe[pC] <= maxTxTele then -- Tx tele selected
      txTele = system.getTxTelemetry()
      --print("SYS Tele - teleSe[pC] - maxTele:", teleSe[pC] - maxTele, teleSeLs[pC])
      value = txTele[teleSeLs[pC]]
      unit = teleSeUn[pC]
      dp   = teleSeDp[pC]
   elseif teleSe[pC] > maxTxTele and teleSe[pC] <= maxRSSITele then -- Tx RSSI tele selected
      txTele = system.getTxTelemetry()
      txRSSI = txTele["RSSI"]
      --print("RSSI Tele - teleSe[pC] - maxTxTele:", teleSe[pC] - maxTxTele, teleSeLs[pC])
      value = txRSSI[teleSe[pC] - maxTxTele]
      unit = teleSeUn[pC]
      dp   = teleSeDp[pC]
   elseif teleSe[pC] > maxRSSITele and teleSe[pC] <= maxAPPTele then
	 --print(teleSe[pC], sensorLslist[teleSe[pC]])
	 local appname = string.match(sensorLslist[teleSe[pC]], "(.-)%.")
	 local senname = string.match(sensorLslist[teleSe[pC]], "%.(.*)")
	 --print("app", appname)
	 --print("sensor", senname)

	 --for k,v in pairs(sharedVar) do
	 --   print("$", k,v)
	 --   for kk,vv in pairs(v) do
	 --      print(kk,vv)
	 --   end
	 --end
	 --print("1", sharedVar[appname])
	 --print("2", sharedVar[appname].value)
	 --print("3", sharedVar[appname].value[1])	 

	 local imatch = 0
	 
	 for k,v in pairs(sharedVar[appname].label) do
	    --print("v, senname:", v, senname)
	    if v == senname then
	       imatch = k
	       break
	    end
	 end
	 --print("imatch:", imatch)
	 --print("val:",  sharedVar[appname].value[imatch])
	 --print("unit:", sharedVar[appname].unit[imatch])
	 --print("dp:",   sharedVar[appname].dp[imatch])	 

	 value = sharedVar[appname].value[imatch]
	 unit  = sharedVar[appname].unit[imatch]	 
	 dp    = sharedVar[appname].dp[imatch]
	 
   else   
      print("DFM-SWT: Nothing set on pressAction - pC = ", pC)
   end

   if fn and teleSe[pC] > 1 then
      if emFlag then
	 --print("DFM-SWT: playFile:", fn)
	 --print("DFM-SWT: playNumber:", value, dp, unit)
      end
      if fn then -- and value then -- and dp and unit then
	 system.playFile(fn, AUDIO_QUEUE)
	 system.playNumber((value or 0), (dp or 0), unit) -- not ok for dp to be nil, ok for unit to be nil
      else
	 print("DFM-SWT: Some play vals nil:")
	 print(fn, value, dp, unit)
      end
   end
   
end

local function loop()

   local now
   
   currSwitchState= system.getInputsVal(switch)
   now = system.getTimeCounter()

   for i=1, maxPressCount+1 do
      if ctrlOffTime[i] and ctrlOffTime[i] ~= 0 then
	 if now > ctrlOffTime[i] then
	    system.setControl(vCtrl[i], -1, 0)
	    ctrlOffTime[i] = 0
	 end
      end
   end
   
   if now - lastUpTime > t2 then -- N presses done
      if pressCount > 0 then
	 if emFlag then print("DFM-SWT <en>: pressCount:", pressCount) end
	 if pressCount <= maxPressCount then
	    pressAction(pressCount)
	 end
      end
      lastUpTime = 0
      upTime = 0
      pressCount = 0
   end
   
   if currSwitchState ~= lastSwitchState then
      if currSwitchState == 1 then
	 startUp = false
	 if upTime == 0 then
	    upTime = now
	 end
	 lastUpTime = now
      end
      if currSwitchState == -1 then
	 if now - lastUpTime < t1 then
	    pressCount = pressCount + 1
	    lastUpTime = now
	 else
	    if not startUp then
	       if emFlag then print("DFM-SWT <en>: Long press") end
	       pressAction(maxPressCount + 1)
	    end
	    upTime = 0
	    lastUpTime = 0
	    pressCount = 0
	 end
      end
      lastSwitchState = currSwitchState
   end
end

local function init()

   local ic
   local ss
   local sname
   local fullname
   local mf 
   local ff
   local mdl
   local sen
   local addSensor
   
   
   emFlag = (select(2,system.getDeviceType()) == 1)

   switch   = system.pLoad("switch")
   t1       = system.pLoad("t1",      300)
   t2       = system.pLoad("t2",      600)   
   teleSe   = system.pLoad("teleSe",   {})
   teleSeId = system.pLoad("teleSeId", {})
   teleSePa = system.pLoad("teleSePa", {})
   teleSeUn = system.pLoad("teleSeUn", {})
   teleSeUd = system.pLoad("teleSeUd", {})   
   teleSeLs = system.pLoad("teleSeLs", {})
   teleSeLa = system.pLoad("teleSeLa", {})
   teleSeDp = system.pLoad("teleSeDp", {})         
   vCtrl    = system.pLoad("vCtrl",    {})

   --print("pLoad: - teleSe")
   --for k,v in ipairs(teleSe) do
   --   print(k,v, teleSeLa[k])
   --end
   
   --[[
   system.pSave("teleSe", teleSe)
   system.pSave("teleSeId", teleSeId)
   system.pSave("teleSePa", teleSePa)
   system.pSave("teleSeUn", teleSeUn)
   system.pSave("teleSeUd", teleSeUd)
   system.pSave("teleSeDp", teleSeDp)
   system.pSave("teleSeLa", teleSeLa)
   system.pSave("teleSeLs", teleSeLs)
   system.pSave("vCtrl", vCtrl)
   --]]
   
   --make sure no nil entries in tables .. will cause problems on save/restore

   for i=1, maxPressCount + 1, 1 do
      if not teleSe[i] then
	 teleSe[i] = 0
      end
      if not teleSeId[i] then
	 teleSeId[i] = 0
      end
      if not teleSePa[i] then
	 teleSePa[i] = 0
      end
      if not teleSeUn[i] then
	 teleSeUn[i] = ""
      end
      if not teleSeUd[i] then
	 teleSeUd[i] = 1
      end      
      if not teleSeLs[i] then
	 teleSeLs[i] = ""
      end
      if not teleSeLa[i] then
	 teleSeLa[i] = ""
      end
      if not teleSeDp[i] then
	 teleSeDp[i] = 0
      end      
      if not vCtrl[i] then
	 vCtrl[i] = 0
      end
   end
   --[[
      for k=1,10,1 do
	 local used = false
	 for j in ipairs(vCtrl) do
	    if vCtrl[j] == k then used = true end
	 end
	 if not used then
	    vCtrl[idx] = system.registerControl(k, "Press "..ss, "SL"..ss)	 
	    if vCtrl[idx] then break end
	 end
      end

   --]]

   -- make a copy of the lua control assignments. assume they mapping to internal controls
   -- may be changed since last stored with pSave. Just need to remember which entries in vCtrl
   -- were non-zero, then we repopulate vCtrl
   
   kCtrl = {}
   for k in ipairs(vCtrl) do
      kCtrl[k] = vCtrl[k]
      vCtrl[k] = 0
   end
   
   for i=1, maxPressCount+1, 1 do
      if kCtrl[i] and kCtrl[i] ~= 0 then
	 if i <= maxPressCount then ss = tostring(i) else ss = "L" end
	 for k=1,10,1 do
	    local used = false
	    for j in ipairs(vCtrl) do
	       if vCtrl[j] == k then used = true end
	    end
	    if not used then
	       ic = system.registerControl(k, "Press "..ss, "SL"..ss)
	       if ic then break end
	    end
	 end
	 if ic then
	    vCtrl[i] = ic
	    print("DFM-SWT: Control SW"..i.." Registered to "..ic)
	    system.setControl(vCtrl[i], -1, 0)
	    ctrlOffTime[i] = 0
	 else
	    system.messageBox("DFM-SWT: control not registered ".. i, ic)
	    print("DFM-SWT: Control not registered", i, vCtrl[i])
	 end
      end
   end
         

   --print("maxTele, maxTxTele, maxRSSITele", maxTele, maxTxTele, maxRSSITele)
   
   system.registerForm(1, MENU_APPS, appName, initForm)

   locale = system.getLocale()
   
   if emFlag then
      mf =  "Model/" .. system.getProperty("ModelFile")
   else
      mf = "/Model/" .. system.getProperty("ModelFile")
   end
   
   print("DFM-SWT: Reading ModelFile:", mf)

   -- read the model file and decode into table form
   
   ff = io.readall(mf)

   if ff then
      mdl = json.decode(ff)
   end
  
   -- extract all the telem sensors in the file and check on their units displayed
   -- stored in UnitIDX value ... integer index into table of units

   if mdl then
      for k,_ in pairs(mdl["Telem-Detect"].Data) do
	 sen = {}
	 for kk,vv in pairs(mdl["Telem-Detect"].Data[k]) do
	    sen[kk] = vv
	 end
	 --print("sen.Param, sen.Label:", sen.Param, sen.Label)
	 if sen.Param == 0 then
	    sname = sen.Label
	 else
	    if not sname then
	       print("DFM-SWT - sname nil", sen.Param, sen.Label)
	       sname = "---"
	    end
	    fullname = sname .. "." .. sen.Label
	    UnIDX[fullname] = math.floor(sen.UnitIDX)
	 end
      end
   end
   
   --print("***")
   --for k,v in pairs(mdl.Global) do
   --   print(k,v)
   --end
   
   readSensors()

   maxTele = #sensorLalist

   -- TEST
   --mdl.Global["Receiver-ID1"] = 137
   
   for k,v in ipairs(txTelem) do
      addSensor = false
      if     string.find(v, "rx1") and mdl.Global["Receiver-ID1"] ~= 0 then
	 addSensor = true
      elseif string.find(v, "rx2") and mdl.Global["Receiver-ID2"] ~= 0 then
	 addSensor = true
      elseif string.find(v, "rxB") and mdl.Global["Rx-ID900"]     ~= 0 then
	 addSensor = true
      elseif not string.find(v, "rx") then
	 addSensor = true
      end
      if addSensor then
	 table.insert(sensorLalist, "SYS."..v)
	 table.insert(sensorLslist, v)
	 table.insert(sensorUnlist, txTelemUn[k])
	 table.insert(sensorDplist, txTelemDp[k])
	 table.insert(sensorIdlist, 0)
	 table.insert(sensorPalist, 0)
      end
   end

   maxTxTele = #sensorLalist

   for k,v in ipairs(txTRSSI) do
      addSensor = false
      if     string.find(v, "rx1") and mdl.Global["Receiver-ID1"] ~= 0 then
	 addSensor = true
      elseif string.find(v, "rx2") and mdl.Global["Receiver-ID2"] ~= 0 then
	 addSensor = true
      elseif string.find(v, "rxB") and mdl.Global["Rx-ID900"]     ~= 0 then
	 addSensor = true
      elseif not string.find(v, "rx") then
	 addSensor = true
      end
      if addSensor then
	 table.insert(sensorLalist, "RSSI."..v)
	 table.insert(sensorLslist, v)
	 table.insert(sensorUnlist, txTRSSIUn[k])
	 table.insert(sensorDplist, txTRSSIDp[k])
	 table.insert(sensorIdlist, 0)
	 table.insert(sensorPalist, 0)
      end
   end

   maxRSSITele = #sensorLalist

   --print("SWT")
   for k,v in pairs(sharedVar) do
      --print(">", k,v)
      for kk,vv in pairs(sharedVar[k]) do
	 --print(">>",kk,vv)
	 for kkk, vvv in pairs(sharedVar[k][kk]) do
	    --print(">>>",kkk,vvv)
	    if kk == "label" then
	       --print("SWT " .. k .. "-" .. vvv .. " kkk: ".. kkk)
	       --for k1,v1 in ipairs(teleSeLa) do
		 -- print("tSL:, k,v:", k1, v1)
	       --end
	       table.insert(sensorLalist, "App."..k.."."..vvv)
	       table.insert(sensorLslist, k.."."..vvv)
	       table.insert(sensorIdlist, 0) -- maybe store indexes of app + sensor in Id and Pa?
	       table.insert(sensorPalist, 0) -- so we don't have to string search them each time?
	    elseif kk == "unit" then
	       table.insert(sensorUnlist, vvv)
	    elseif kk == "dp" then
	       table.insert(sensorDplist, vvv)
	    end
	 end
      end
   end

   maxAPPTele = #sensorLalist

   
end

return {init=init, loop=loop, author="DFM", version=tostring(SWTVersion),
	name=appName}
