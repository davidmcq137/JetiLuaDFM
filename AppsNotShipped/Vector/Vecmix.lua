--[[

 Vecmix.lua DFM 01/06/2021

 Mix vector thrust tube controls
 Creates two new controls (YV and PV) for yaw vector control and pitch vector control
 these new controls must be assigned to functions and servos in the usual way

 Warning: TOY APP -- Not Inteded for use in Flight!

 Developed on DS-24 emulator, only tested on DS-24

 Released under MIT license by DFM 2021

--]]

local emflag

local controlList = {"P1", "P2", "P3", "P4"}

local yawControl
local pitchControl
local yawVectorControl
local pitchVectorControl

local function pitchControlChanged(val)
   pitchControl = val
   system.pSave("pitchControl", pitchControl)
end

local function yawControlChanged(val)
   yawControl = val
   system.pSave("yawControl", yawControl)
end

local function initForm()
      form.addRow(2)
      form.addLabel({label="Pitch Control", width=220})
      form.addSelectbox(controlList, pitchControl, true, pitchControlChanged)
      
      form.addRow(2)
      form.addLabel({label="Yaw Control", width=220})
      form.addSelectbox(controlList, yawControl, true, yawControlChanged)
      
      form.addRow(1)
      form.addLabel({label="Vecmix.lua Version 1", font=FONT_MINI, alignRight=true})
end

local function radius(x,y)
   return math.sqrt( x^2 + y^2)
end

local function loop()
   local yaw, pitch, rad
   local yawVector, pitchVector

   if not (yawControl and pitchControl) then return end
   
   yaw, pitch = system.getInputs("P"..yawControl, "P"..pitchControl)

   if yaw and pitch then
      rad = radius(yaw, pitch)
      if rad <= 1.0 then
	 yawVector = yaw
	 pitchVector = pitch
      else
	 yawVector = yaw / rad
	 pitchVector = pitch / rad
      end
   else
      yawVector = 0
      pitchVector = 0
   end
   if yawControl and pitchControl then
      system.setControl(yawVectorControl, yawVector, 0)
      system.setControl(pitchVectorControl, pitchVector, 0)
   end
end


local function init()
   
   system.registerForm(1, MENU_APPS, "Vector Thrust Mixer", initForm)

   yawControl  = system.pLoad("yawControl",  3)
   pitchControl = system.pLoad("pitchControl", 2)

   yawVectorControl = system.registerControl(1, "Yaw Vector Ctrl", "YV")
   pitchVectorControl = system.registerControl(2, "Pitch Vector Ctrl", "PV")   
   
   if yawVectorControl and pitchVectorControl then
      system.messageBox("Vector Controls Assigned")
   else
      system.messageBox("Could not assign control(s)")      
   end
   
   emflag = (select(2,system.getDeviceType()) == 1)

end


return {init=init, loop=loop, author="DFM", version=1.0,name="Vector Mixer"}
