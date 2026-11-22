local appName = "Persistent Switch Test"

local sw
local swTable
local activeOn = 1

local function doSave()
  local f = io.open("Apps/swcfg.jsn", "w")
  if f then
    io.write(f, json.encode(swTable))
    io.close(f)
  end
end

local function switchChanged(value)
   sw = value
   swTable = system.getSwitchInfo(value)
   for k,v in pairs(swTable) do print(k,v) end
   doSave()
end

local function initForm(subform)
   form.addRow(2)
   form.addLabel({label="Assign Switch"})
   form.addInputbox(sw, false, switchChanged)
end

local function init()
   system.registerForm(1,MENU_MAIN,appName,initForm)
   local f = io.readall("Apps/swcfg.jsn")
   if f then
      print("swcfg.jsn: " .. f)
      swTable = json.decode(f)
      if swTable.label == "Sb" then activeOn = -1 else activeOn = 1 end
      print("createSwitch params: label = " .. swTable.label ..
	       " mode = " .. swTable.mode .. " activeOn = " .. activeOn)
      sw = system.createSwitch(swTable.label, swTable.mode, activeOn)
   end
end
----------------------------------------------------------------------
return { init=init,  author="JETI model and DFM",version="1.0", name=appName}
