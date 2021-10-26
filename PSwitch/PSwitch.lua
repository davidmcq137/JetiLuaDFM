local appInfo={}
appInfo.Name = "PSwitch"
appInfo.Dir  = "Apps/" .. appInfo.Name .. "/"
appInfo.menuTitle = "Persistent Switch Test"
appInfo.SaveData = true

local variables = {}

local savedSubform

local checkBox = {}
local checkBoxIndex = {}
local checkBoxSubform = {}

local switchItems = {}
local switchNames = {
	"Sa",
	"Sb",
	"Sc",
	"Sd",
	"Se",
	"Sf",
	"Sg",
	"Sh",
	"Si",
	"Sj",
	"Sk",
	"Sl",
	"Sm",
	"Sn",
	"So",
	"Sp",
	"L1",
	"L2",
	"L3",
	"L4",
	"L5",
	"L6",
	"L7",
	"L8",
	"L9",
	"L10",
	"L11",
	"L12",
	"L13",
	"L14",
	"L15",
	"L16",
	"L17",
	"L18",
	"L19",
	"L21",
	"L22",
	"L23",
	"L24",
	"..."
}

local switchDirs = {Sa=-1, Sc=-1, Se= -1, Sg = -1}

local function clearData()
   if form.question("Clear all data?",
		    "Press Yes to clear, timeout is No",
		    "Restart App after pressing Yes",
		    6000, false, 0) == 1 then
      io.remove(jFilename())
      appInfo.SaveData = false
   end
end

local function createSw(name, dir)
   local activeOn = {1, 0, -1}
   if not name or not activeOn[dir] then
      return nil
   else
      return system.createSwitch(name, "S", (switchDirs[name] or 1) * activeOn[dir])
   end
end

local function jFilename()
   return appInfo.Dir .. "M-" .. string.gsub(system.getProperty("Model")..".jsn", " ", "_")
end

local function jLoadInit(fn)
   local fj
   local config
   fj = io.readall(fn)
   if fj then
      config = json.decode(fj)
   end
   if not config then
      print("Did not read jLoad file "..fn)
      config = {}
   end
   return config
end

local function jLoadFinal(fn, config)
   local ff
   ff = io.open(fn, "w")
   if not ff then
      return false
   end
   if not io.write(ff, json.encode(config)) then
      return false
   end
   io.close(ff)
   return true
end

local function jLoad(config, var, def)
   if not config then return nil end
   if config[var] == nil then
      config[var] = def
   end
   return config[var]
end

local function jSave(config, var, val)
   if type(val) == "userdata" then -- switchItem
      config[var]= system.getSwitchInfo(val)
   else
      config[var] = val
   end
end

local function destroy()
   if appInfo.SaveData then
      if jLoadFinal(jFilename(), variables) then
	 print("jLoad successful write")
      else
	 print("jLoad failed write")
      end
   end
end

local function switchNameChanged(value, name, swname)
   if name and switchNames[value] == "..." then
      jSave(variables, swname.."SwitchName", value)
      jSave(variables, swname.."SwitchDir", value)
      switchItems[swname] = nil
      checkBox[swname.."Switch"] = false
      return
   end
   if name then
      jSave(variables, swname .. "SwitchName", value)
   else
      jSave(variables, swname .. "SwitchDir", value)
   end
   switchItems[swname] = createSw(switchNames[variables[swname .. "SwitchName"]],
		     variables[swname .."SwitchDir"])
   checkBox[swname .."Switch"] = system.getInputsVal(switchItems[swname]) == 1
end

local function switchAdd(lbl, swname, sf)
   form.addRow(5)
   form.addLabel({label=lbl, width=80})
   form.addSelectbox(switchNames, variables[swname .. "SwitchName"], true,
		     (function(z) return switchNameChanged(z, true, swname) end),
		     {width=60})
   form.addLabel({label="Up/Mid/Dn", width=94})
   form.addSelectbox({"U","M","D"}, variables[swname .. "SwitchDir"], true,
      (function(z) return switchNameChanged(z, false, swname) end), {width=50})
   checkBoxIndex[swname .."Switch"] = form.addCheckbox(checkBox[swname.."Switch"],
						       nil, {width=15})
   checkBoxSubform[swname] = sf
end

local function initForm(subform)
   savedSubform = subform
   switchAdd("Start", "start", subform)
   switchAdd("Stop", "stop", subform)
end

local function prtForm(windowWidth, windowHeight)
   for k,v in pairs(switchItems) do
      if checkBoxSubform[k] == savedSubform then
	 checkBox[k.."Switch"] = system.getInputsVal(switchItems[k]) == 1
	 form.setValue(checkBoxIndex[k.."Switch"], checkBox[k.."Switch"])
      end
   end
end

local function init()

   variables = jLoadInit(jFilename())   
   
   variables.startSwitchName   = jLoad(variables, "startSwitchName", 0)
   variables.startSwitchDir    = jLoad(variables, "startSwitchDir", 0)
   variables.stopSwitchName    = jLoad(variables, "stopSwitchName", 0)
   variables.stopSwitchDir     = jLoad(variables, "stopSwitchDir", 0)

   system.registerForm(1, MENU_APPS, appInfo.menuTitle, initForm, keyForm, prtForm)

   switchItems = {start = 0, stop = 0}
   
   for k,v in pairs(switchItems) do
      switchItems[k] = createSw(switchNames[variables[k.."SwitchName"]],
				variables[k.."SwitchDir"])
      checkBox[k.."Switch"] = system.getInputsVal(switchItems[k]) == 1
   end
end


return {init=init, loop=loop, author="DFM", version="1.0", name=appInfo.Name, destroy=destroy}
