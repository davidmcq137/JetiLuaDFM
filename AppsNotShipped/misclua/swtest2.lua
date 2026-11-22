local appName = "Persistent Switch Test Version 2"

local sw
local swTable
local activeOn = 1
local rev
local iff

local function doSave()
   print("doSave")
   local f = io.open("Apps/swcfg.jsn", "w")
   if f then
      swTable.activeOn = activeOn
      print("swTable saving")
      for k,v in pairs(swTable) do
	 print(k,v)
      end
      io.write(f, json.encode(swTable))
      io.close(f)
  end
end

local function doRead()
   print("doRead")
   local f = io.readall("Apps/swcfg.jsn")
   if f then
      print("swcfg.jsn: " .. f)
      swTable = json.decode(f)
      if not swTable.activeOn then swTable.activeOn = 1 end
      --if swTable.label == "Sb" then activeOn = -1 else activeOn = 1 end
      print("createSwitch params: label = " .. swTable.label ..
	       " mode = " .. swTable.mode .. " activeOn = " .. swTable.activeOn)
      sw = system.createSwitch(swTable.label, swTable.mode, swTable.activeOn)
   end
end

local function switchChanged(value)
   sw = value
   swTable = system.getSwitchInfo(value)
   for k,v in pairs(swTable) do print(k,v) end
   doSave()
   print("reinit 1")
   ans = form.question("Please confirm switch direction","Click <Rev> if required","",5000,true,0)
   form.reinit(1)
end

local function checkClicked(value)
   print("checkClicked:", value)
   activeOn = activeOn * -1
   rev = activeOn == -1
   form.setValue(iff, rev)
   doSave()
   form.reinit(1)
end

local function initForm(subform)
   form.addRow(4)
   form.addLabel({label="Please Assign Switch 123", width=180})
   sw = nil
   print("initForm")
   doRead()
   form.addInputbox(sw, false, switchChanged, {width=60})
   form.addLabel({label="Rev",width=40})
   iff = form.addCheckbox(rev, checkClicked, {width=20})
end

local function init()
   system.registerForm(1,MENU_MAIN,appName,initForm)
   doRead()
end
----------------------------------------------------------------------
return { init=init,  author="JETI model and DFM",version="1.0", name=appName}
