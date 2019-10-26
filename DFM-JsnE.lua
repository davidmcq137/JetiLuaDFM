--[[

----------------------------------------------------------------------------
   DFM-JsnE.lua

   Edits model jsn file with model characteristics
    
   Requires transmitter firmware 4.22 or higher.
    
----------------------------------------------------------------------------
	Released under MIT-license by DFM 2019
----------------------------------------------------------------------------

--]]

collectgarbage()

--------------------------------------------------------------------------------

-- global

   newJSON = false -- global read by Chute program!

-- Locals for application

--local trans11

local jsonEditorVersion

local throttleChannel, throttleFull, throttleIdle, throttleCutoff, throttleIdx
local throttleFullForm, throttleIdleForm, throttleCutoffForm
local brakeChannel, brakeOn, brakeOff, brakeIdx
local brakeOnForm, brakeOffForm
local flapChannel, flapUp, flapFull, flapTakeoff, flapIdx
local flapUpForm, flapFullForm, flapTakeoffForm
local gearChannel, gearUp, gearDown, gearIdx
local gearUpForm, gearDownForm
local defaultWheelDia = 6.0 -- inches
local pitotCal, wheelDia
local turbineIdx, turbineIdxChanged

local controlInputs = {
   "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10",
   "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH",
   "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SP"
}

-- note: order of list significant .. index to list stored in modelProps jsn file

local tjson={}

local turbineList = {}
local turbineThrust= {}

local modelProps = {}
local jsonFile

local DEBUG = false
--------------------------------------------------------------------------------

-- Read and set translations

local function setLanguage()
--[[
   local lng=system.getLocale()
   local file = io.readall("Apps/Lang/RCT-SpdA.jsn")
   local obj = json.decode(file)
   if(obj) then
      trans11 = obj[lng] or obj[obj.default]
   end
--]]
end

local function getIdx(tbl, val)
   for k,v in ipairs(tbl) do
      if v == val then
	 return k
      end
   end
   return 0
end

--------------------------------------------------------------------------------

local function jsonSetLocals(ff)

   modelProps=json.decode(ff)
   
   if modelProps.throttleChannel then throttleChannel = modelProps.throttleChannel      end
   if modelProps.throttleFull    then throttleFull    = modelProps.throttleFull * 100   end
   if modelProps.throttleIdle    then throttleIdle    = modelProps.throttleIdle * 100   end
   if modelProps.throttleCutoff  then throttleCutoff  = modelProps.throttleCutoff * 100 end
   if modelProps.brakeChannel    then brakeChannel    = modelProps.brakeChannel         end
   if modelProps.brakeOn         then brakeOn         = modelProps.brakeOn * 100        end
   if modelProps.brakeOff        then brakeOff        = modelProps.brakeOff * 100       end
   if modelProps.flapChannel     then flapChannel     = modelProps.flapChannel          end
   if modelProps.flapUp          then flapUp          = modelProps.flapUp * 100         end
   if modelProps.flapTakeoff     then flapTakeoff     = modelProps.flapTakeoff * 100    end
   if modelProps.flapFull        then flapFull        = modelProps.flapFull * 100       end
   if modelProps.gearChannel     then gearChannel     = modelProps.gearChannel          end
   if modelProps.gearUp          then gearUp          = modelProps.gearUp * 100         end
   if modelProps.gearDown        then gearDown        = modelProps.gearDown * 100       end
   if modelProps.pitotCal        then pitotCal        = modelProps.pitotCal             end
   if modelProps.wheelDiameter   then wheelDia        = modelProps.wheelDiameter        end

   turbineIdx = getIdx(turbineList, modelProps.turbineName)
   if turbineIdx == 0 then turbineIdx = 1 end

   --print("json read - t list:", turbineList[1], turbineList[2], turbineList[3])
   --print("json read - t name:", modelProps.turbineName)
   --print("json read - turbineIdx:", turbineIdx)
end

local function jsonWriteFile()

   local fg, jsonText

   modelProps.throttleChannel    = throttleChannel
   modelProps.throttleFull       = throttleFull / 100
   modelProps.throttleIdle       = throttleIdle / 100
   modelProps.throttleCutoff     = throttleCutoff / 100
   modelProps.brakeChannel       = brakeChannel
   modelProps.brakeOn            = brakeOn / 100
   modelProps.brakeOff           = brakeOff / 100
   modelProps.flapChannel        = flapChannel
   modelProps.flapUp             = flapUp / 100
   modelProps.flapTakeoff        = flapTakeoff / 100   
   modelProps.flapFull           = flapFull / 100
   modelProps.gearChannel        = gearChannel
   modelProps.gearUp             = gearUp / 100
   modelProps.gearDown           = gearDown / 100
   modelProps.pitotCal           = pitotCal
   modelProps.wheelDiameter      = wheelDia
   modelProps.turbineName        = turbineList[turbineIdx]
   modelProps.turbineThrustTable = turbineThrust[turbineIdx]

   --print("idx, thrust cubic term:", turbineIdx, turbineThrust[turbineIdx][4])
	 
   jsonText = json.encode(modelProps)
   fg = io.open(jsonFile, "w")
   io.write(fg, jsonText)
   io.close(fg)
   print("JsnE setting newJSON to true")
   newJSON = true
end

-- Actions when settings changed

local function throttleChannelChanged(value)
   throttleIdx = value
   throttleChannel = controlInputs[throttleIdx]
   system.pSave("throttleChannel", throttleChannel)
   jsonWriteFile()
end

local function throttleFullChanged(value)
   throttleFull = value
   system.pSave("throttleFull", throttleFull)
   jsonWriteFile()
end

local function throttleIdleChanged(value)
   throttleIdle = value
   system.pSave("throttleIdle", throttleIdle)
   jsonWriteFile()
end

local function throttleCutoffChanged(value)
   throttleCutoff = value
   system.pSave("throttleCutoff", throttleCutoff)
   jsonWriteFile()
end

local function brakeChannelChanged(value)
   brakeIdx = value
   brakeChannel = controlInputs[brakeIdx]
   system.pSave("brakeChannel", brakeChannel)
   jsonWriteFile()
end

local function brakeOnChanged(value)
   brakeOn = value
   system.pSave("brakeOn", brakeOn)
   jsonWriteFile()
end

local function brakeOffChanged(value)
   brakeOff = value
   system.pSave("brakeOff", brakeOff)
   jsonWriteFile()
end

local function flapChannelChanged(value)
   flapIdx = value
   flapChannel = controlInputs[flapIdx]
   system.pSave("flapChannel", flapChannel)
   jsonWriteFile()
end

local function flapUpChanged(value)
   flapUp = value
   system.pSave("flapUp", flapUp)
   jsonWriteFile()
end

local function flapTakeoffChanged(value)
   flapTakeoff = value
   system.pSave("flapTakeoff", flapTakeoff)
   jsonWriteFile()
end

local function flapFullChanged(value)
   flapFull = value
   system.pSave("flapFull", flapFull)
   jsonWriteFile()
end

local function gearChannelChanged(value)
   gearIdx = value
   gearChannel = controlInputs[gearIdx]
   system.pSave("gearChannel", gearChannel)
   jsonWriteFile()
end

local function gearUpChanged(value)
   gearUp = value
   system.pSave("gearUp", gearUp)
   jsonWriteFile()
end

local function gearDownChanged(value)
   gearDown = value
   system.pSave("gearDown", gearDown)
   jsonWriteFile()
end

local function pitotCalChanged(value)
   pitotCal = value
   system.pSave("pitotCal", pitotCal)
   jsonWriteFile()
end

local function wheelDiaChanged(value)
   wheelDia = value / 10.0
   --print("value, wheelDia", value, wheelDia)
   system.pSave("wheelDia", wheelDia)
   jsonWriteFile()
end

local function turbineIdxChanged(value)
   turbineIdx = value
   system.pSave("turbineIdx", value)
   jsonWriteFile()
end

--------------------------------------------------------------------------------
local function printForm()

   local fr, text, channel

   fr = form.getFocusedRow()
   
   -- NB: if changing form, need to change fr limits in keyPressed and in printForm

   if fr and fr >= 2 and fr <= 4 and throttleIdx > 0 then
      throttleChannel = controlInputs[throttleIdx]
      channel = throttleChannel
      text = string.format("%d", math.floor(system.getInputs(throttleChannel)*100))
   end

   if fr and fr >= 6 and fr <= 7 and brakeIdx > 0 then
      brakeChannel = controlInputs[brakeIdx]
      channel = brakeChannel
      text = string.format("%d", math.floor(system.getInputs(brakeChannel)*100))
   end

   if fr and fr >= 9 and fr <= 11 and flapIdx > 0 then
      flapChannel = controlInputs[flapIdx]
      channel = flapChannel
      text = string.format("%d", math.floor(system.getInputs(flapChannel)*100))
   end

   if fr and fr >= 13 and fr <= 14 and gearIdx > 0 then
      gearChannel = controlInputs[gearIdx]
      channel = gearChannel
      text = string.format("%d", math.floor(system.getInputs(gearChannel)*100))
   end

   if not text or not channel or not fr then
      form.setTitle(jsonFile)
   else
      form.setTitle("Input " .. channel .. " value: " .. text)
   end
   
end


local function keyPressed(key)
   
   local fr
   --local text

   --print("KeyPressed: ", key)
   
   if key ~= KEY_1 then return end

   fr = form.getFocusedRow()

   -- NB: if changing form, need to change fr limits in keyPressed and in printForm
   
   if fr and fr >= 2 and fr <= 4 and throttleIdx > 0 then
      if fr == 2 then
	 form.setValue(throttleFullForm, math.floor(system.getInputs(throttleChannel)*100))
      end
      if fr == 3 then
	 form.setValue(throttleIdleForm, math.floor(system.getInputs(throttleChannel)*100))
      end
      if fr == 4 then
	 form.setValue(throttleCutoffForm, math.floor(system.getInputs(throttleChannel)*100))
      end
      
      --text = throttleChannel .. " value: " .. controlInputs[throttleIdx]
   end

   if fr and fr >= 6 and fr <= 7 and brakeIdx > 0 then
      if fr == 6 then
	 form.setValue(brakeOnForm, math.floor(system.getInputs(brakeChannel)*100))
      end
      if fr == 7 then
	 form.setValue(brakeOffForm, math.floor(system.getInputs(brakeChannel)*100))
      end
      --text = brakeChannel .. " value: " .. controlInputs[brakeIdx]
   end
   
   if fr and fr >= 9 and fr <= 11 and flapIdx > 0 then
      if fr == 9 then
	 form.setValue(flapUpForm, math.floor(system.getInputs(flapChannel)*100))
      end
      if fr == 10 then
	 form.setValue(flapTakeoffForm, math.floor(system.getInputs(flapChannel)*100))
      end
      if fr == 11 then
	 form.setValue(flapFullForm, math.floor(system.getInputs(flapChannel)*100))
      end
      
      --text = flapChannel .. " value: " .. controlInputs[flapIdx]
   end

   if fr and fr >= 13 and fr <= 14 and gearIdx > 0 then
      if fr == 13 then
	 form.setValue(gearUpForm, math.floor(system.getInputs(gearChannel)*100))
      end
      if fr == 14 then
	 form.setValue(gearDownForm, math.floor(system.getInputs(gearChannel)*100))
      end      

      --text = gearChannel .. " value: " .. controlInputs[gearIdx]
   end

end

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())
   
   form.setButton(1, "Enter", ENABLED)

   -- NB: if changing form, need to change fr limits in keyPressed and in printForm
   
   if (fw >= 4.22) then
      
      form.addRow(2)
      form.addLabel({label="Select Throttle Control", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, throttleIdx, true, throttleChannelChanged) 
      
      form.addRow(2)
      form.addLabel({label="Throttle Full Value (%)", width=220})
      throttleFullForm = form.addIntbox(throttleFull, -100, 100, 90, 0, 1, throttleFullChanged)

      form.addRow(2)
      form.addLabel({label="Throttle Idle Value (%)", width=220})
      throttleIdleForm = form.addIntbox(throttleIdle, -100, 100, -90, 0, 1, throttleIdleChanged)      
      form.addRow(2)
      form.addLabel({label="Throttle Cutoff Value (%)", width=220})
      throttleCutoffForm = form.addIntbox(throttleCutoff, -100, 100, -100, 0, 1, throttleCutoffChanged)      
      form.addRow(2)
      form.addLabel({label="Select Brake Control", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, brakeIdx, true, brakeChannelChanged)

      form.addRow(2)
      form.addLabel({label="Brake On Value (%)", width=220})
      brakeOnForm = form.addIntbox(brakeOn, -100, 100, 90, 0, 1, brakeOnChanged)

      form.addRow(2)
      form.addLabel({label="Brake Off Value (%)", width=220})
      brakeOffForm = form.addIntbox(brakeOff, -100, 100, -90, 0, 1, brakeOffChanged)      
      
      form.addRow(2)
      form.addLabel({label="Select Flap Control or Switch", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, flapIdx, true, flapChannelChanged)

      form.addRow(2)
      form.addLabel({label="Flaps Up (%)", width=220})
      flapUpForm = form.addIntbox(flapUp, -100, 100, 100, 0, 1, flapUpChanged)
      --print("flapUpForm:", flapUpForm)
      
      form.addRow(2)
      form.addLabel({label="Flaps Mid (%)", width=220})
      flapTakeoffForm = form.addIntbox(flapTakeoff, -100, 100, 0, 0, 1, flapTakeoffChanged)

      form.addRow(2)
      form.addLabel({label="Flaps Full (%)", width=220})
      flapFullForm = form.addIntbox(flapFull, -100, 100, -90, 0, 1, flapFullChanged)      

      form.addRow(2)
      form.addLabel({label="Select Gear Control", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, gearIdx, true, gearChannelChanged)

      form.addRow(2)
      form.addLabel({label="Gear Up (%)", width=220})
      gearUpForm = form.addIntbox(gearUp, -100, 100, 100, 0, 10, gearUpChanged)

      form.addRow(2)
      form.addLabel({label="Gear Down (%)", width=220})
      gearDownForm = form.addIntbox(gearDown, -100, 100, 100, 0, 10, gearDownChanged)      

      form.addRow(2)
      form.addLabel({label="Other Model Parameters", width=220, font=FONT_BOLD})
      
      form.addRow(2)
      form.addLabel({label="Pitot Calibration Factor (%)", width=220})
      form.addIntbox(pitotCal, 1, 200, 100, 0, 1, pitotCalChanged)

      form.addRow(2)
      form.addLabel({label="Wheel Diameter (in)", width=220})
      if not wheelDia then wheelDia = defaultWheelDia end
      form.addIntbox(wheelDia*10, 0, 100, 60, 1, 1, wheelDiaChanged)

      form.addRow(2)
      form.addLabel({label="Turbine", width=170})
      form.addSelectbox(turbineList, turbineIdx, true, turbineIdxChanged) 
      
      form.addRow(1)
      form.addLabel({label="DFM-JsnE.lua Version "..jsonEditorVersion.." ", font=FONT_MINI, alignRight=true})
   else
      form.addRow(1)
      form.addLabel({label="Please update, min. fw 4.22 required!"})
   end

end


--------------------------------------------------------------------------------

-- Read available sensors for user to select

local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLalist, sensor.label)
	 table.insert(sensorIdlist, sensor.id)
	 table.insert(sensorPalist, sensor.param)
      end
   end
end

local function init()

   local fg
   
   throttleChannel = system.pLoad("throttleChannel", "P4")
   throttleIdx = getIdx(controlInputs, throttleChannel)
   throttleFull = system.pLoad("throttleFull", 90)
   throttleIdle = system.pLoad("throttleIdle", -90)
   throttleCutoff = system.pLoad("throttleCutoff", -100)
   brakeChannel = system.pLoad("brakeChannel", "P5")
   brakeIdx = getIdx(controlInputs, brakeChannel)
   brakeOn = system.pLoad("brakeOn", 90)
   brakeOff = system.pLoad("brakeOff", -90)
   flapChannel = system.pLoad("flapChannel", "SD")
   flapIdx = getIdx(controlInputs, flapChannel)
   flapUp = system.pLoad("flapUp", 90)
   flapTakeoff = system.pLoad("flapTakeoff", 0)
   flapFull = system.pLoad("flapFull", -90)
   gearChannel = system.pLoad("gearChannel", "SB")
   gearIdx = getIdx(controlInputs, gearChannel)   
   gearUp = system.pLoad("gearUp", 90)
   gearDown = system.pLoad("gearDown", -90)
   pitotCal = system.pLoad("pitotCal", 100)
   wheelDia = system.pLoad("wheelDia", 6.0)   
   turbineIdx = system.pLoad("turbineIdx", 1)

   system.registerForm(1, MENU_APPS, "Config File Editor", initForm, keyPressed, printForm)

   -- DFM-turbines.jsn contains a list of known turbines and their cubic polynomial
   -- coefficients for thrust as a fcn of RPM. terms in order of a,b,c,d where
   -- r = RPM and thrust = a + b*r + c*r^2 + d*r^3
   
   fg = io.readall("Apps/DFM-turbines.jsn")
   if fg then
      tjson = json.decode(fg)
   else
      print("Cannot open Apps/DFM-turbines.jsn")
   end
   
   -- populate local tables set up to use with menu
   for k,v in pairs(tjson) do
      table.insert(turbineList, k)
      table.insert(turbineThrust, v)
   end
      
   jsonFile = "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_")
   if form.question("Erase Contents?", "Model config file", jsonFile,3500, false, 0) == 1 then
      fg = io.open(jsonFile, "w")
      io.close(fg)
      fg = io.readall(jsonFile)
   end

   fg = io.readall(jsonFile)
   -- if model file exists, read it .. if not create it
   if fg then
      jsonSetLocals(fg)
   else
      jsonWriteFile()
   end

end


--------------------------------------------------------------------------------

jsonEditorVersion = "0.0"
setLanguage()

collectgarbage()

return {init=init, loop=nil, author="DFM", version=jsonEditorVersion,
	name="Config File Editor"}
