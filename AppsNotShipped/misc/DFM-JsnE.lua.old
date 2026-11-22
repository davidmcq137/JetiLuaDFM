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

-- Locals for application

--local trans11

local jsonEditorVersion

local throttleChannel, throttleFull, throttleIdle, throttleIdx
local throttleFullForm, throttleIdleForm
local brakeChannel, brakeOn, brakeOff, brakeIdx
local brakeOnForm, brakeOffForm
local flapChannel, flapUp, flapFull, flapTakeoff, flapIdx
local flapUpForm, flapDownForm, flapTakeoffForm
local gearChannel, gearUp, gearDown, gearIdx
local gearUpForm, gearDownForm

local pitotCal

local controlInputs = {
   "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10",
   "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH",
   "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SP"
}

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

--------------------------------------------------------------------------------
local function jsonSetLocals(ff)

   modelProps=json.decode(ff)
   
   throttleChannel = modelProps.throttleChannel
   throttleFull = modelProps.throttleFull * 100
   throttleIdle = modelProps.throttleIdle * 100
   brakeChannel = modelProps.brakeChannel
   brakeOn = modelProps.brakeOn * 100
   brakeOff = modelProps.brakeOff * 100
   flapChannel = modelProps.flapChannel 
   flapUp = modelProps.flapUp * 100
   flapTakeoff = modelProps.flapTakeoff * 100
   flapFull = modelProps.flapFull * 100
   gearChannel = modelProps.gearChanne 
   gearUp = modelProps.gearUp * 100
   gearDown = modelProps.gearDown * 100
   pitotCal = modelProps.pitotCal
   
end

local function jsonWriteFile()

   local fg, jsonText

   modelProps.throttleChannel = throttleChannel
   modelProps.throttleFull = throttleFull/100
   modelProps.throttleIdle = throttleIdle/100
   modelProps.brakeChannel = brakeChannel
   modelProps.brakeOn = brakeOn/100
   modelProps.brakeOff = brakeOff/100
   modelProps.flapChannel = flapChannel
   modelProps.flapUp = flapUp/100
   modelProps.flapTakeoff = flapTakeoff/100   
   modelProps.flapFull = flapFull/100
   modelProps.gearChannel = gearChannel
   modelProps.gearUp = gearUp/100
   modelProps.gearDown = gearDown/100
   modelProps.pitotCal = pitotCal
   
   jsonText = json.encode(modelProps)
   fg = io.open(jsonFile, "w")
   io.write(fg, jsonText)
   io.close(fg)
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
   system.pSave("PitotFactor", PitotFactor)
   jsonWriteFile()
end

--------------------------------------------------------------------------------
local function printForm()

   local fr, text, channel

   fr = form.getFocusedRow()
   
   if fr and fr >= 2 and fr <= 3 and throttleIdx > 0 then
      throttleChannel = controlInputs[throttleIdx]
      channel = throttleChannel
      text = string.format("%d", math.floor(system.getInputs(throttleChannel)*100))
   end

   if fr and fr >= 5 and fr <= 6 and brakeIdx > 0 then
      brakeChannel = controlInputs[brakeIdx]
      channel = brakeChannel
      text = string.format("%d", math.floor(system.getInputs(brakeChannel)*100))
   end

   if fr and fr >= 8 and fr <= 10 and flapIdx > 0 then
      flapChannel = controlInputs[flapIdx]
      channel = flapChannel
      text = string.format("%d", math.floor(system.getInputs(flapChannel)*100))
   end

   if fr and fr >= 12 and fr <= 13 and gearIdx > 0 then
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
   
   local fr, text

   --print("KeyPressed: ", key)
   
   if key ~= KEY_1 then return end

   fr = form.getFocusedRow()

   if fr and fr >= 2 and fr <= 3 and throttleIdx > 0 then
      if fr == 2 then
	 form.setValue(throttleFullForm, math.floor(system.getInputs(throttleChannel)*100))
      end
      if fr == 3 then
	 form.setValue(throttleIdleForm, math.floor(system.getInputs(throttleChannel)*100))
      end
      
      text = throttleChannel .. " value: " .. controlInputs[throttleIdx]
   end

   if fr and fr >= 5 and fr <= 6 and brakeIdx > 0 then
      if fr == 5 then
	 form.setValue(brakeOnForm, math.floor(system.getInputs(brakeChannel)*100))
      end
      if fr == 6 then
	 form.setValue(brakeOffForm, math.floor(system.getInputs(brakeChannel)*100))
      end
      text = brakeChannel .. " value: " .. controlInputs[brakeIdx]
   end
   
   if fr and fr >= 8 and fr <= 10 and flapIdx > 0 then
      if fr == 8 then
	 form.setValue(flapUpForm, math.floor(system.getInputs(flapChannel)*100))
      end
      if fr == 9 then
	 form.setValue(flapTakeoffForm, math.floor(system.getInputs(flapChannel)*100))
      end
      if fr == 10 then
	 form.setValue(flapFullForm, math.floor(system.getInputs(flapChannel)*100))
      end
      
      text = flapChannel .. " value: " .. controlInputs[flapIdx]
   end

   if fr and fr >= 12 and fr <= 13 and gearIdx > 0 then
      if fr == 12 then
	 form.setValue(gearUpForm, math.floor(system.getInputs(gearChannel)*100))
      end
      if fr == 13 then
	 form.setValue(gearDownForm, math.floor(system.getInputs(gearChannel)*100))
      end      

      text = gearChannel .. " value: " .. controlInputs[gearIdx]
   end

end

-- Draw the main form (Application inteface)

local function initForm()

   local fw = tonumber(system.getVersion())
   local idx
   local txt
   
   form.setButton(1, "Enter", ENABLED)
   
   if (fw >= 4.22) then
      
      form.addRow(2)
      form.addLabel({label="Select Throttle Channel", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, throttleIdx, true, throttleChannelChanged) 
      
      form.addRow(2)
      form.addLabel({label="Throttle Full Value (%)", width=220})
      throttleFullForm = form.addIntbox(throttleFull, -100, 100, 90, 0, 1, throttleFullChanged)

      form.addRow(2)
      form.addLabel({label="Throttle Idle Value (%)", width=220})
      throttleIdleForm = form.addIntbox(throttleIdle, -100, 100, -90, 0, 1, throttleIdleChanged)      
      form.addRow(2)
      form.addLabel({label="Select Brake Channel", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, brakeIdx, true, brakeChannelChanged)

      form.addRow(2)
      form.addLabel({label="Brake On Value (%)", width=220})
      brakeOnForm = form.addIntbox(brakeOn, -100, 100, 90, 0, 1, brakeOnChanged)

      form.addRow(2)
      form.addLabel({label="Brake Off Value (%)", width=220})
      brakeOffForm = form.addIntbox(brakeOff, -100, 100, -90, 0, 1, brakeOffChanged)      
      
      form.addRow(2)
      form.addLabel({label="Select Flaps Channel", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, flapIdx, true, flapChannelChanged)

      form.addRow(2)
      form.addLabel({label="Flaps Up (%)", width=220})
      flapUpForm = form.addIntbox(flapUp, -100, 100, 100, 0, 1, flapUpChanged)

      form.addRow(2)
      form.addLabel({label="Flaps Takeoff (%)", width=220})
      flapTakeoffForm = form.addIntbox(flapTakeoff, -100, 100, 0, 0, 1, flapTakeoffChanged)

      form.addRow(2)
      form.addLabel({label="Flaps Down (%)", width=220})
      flapFullForm = form.addIntbox(flapFull, -100, 100, -90, 0, 1, flapFullChanged)      

      form.addRow(2)
      form.addLabel({label="Select Gear Channel", width=220, font=FONT_BOLD})
      form.addSelectbox(controlInputs, gearIdx, true, gearChannelChanged)

      form.addRow(2)
      form.addLabel({label="Gear Up (%)", width=220})
      gearUpForm = form.addIntbox(gearUp, -100, 100, 100, 0, 10, gearUpChanged)

      form.addRow(2)
      form.addLabel({label="Gear Down (%)", width=220})
      gearDownForm = form.addIntbox(gearDown, -100, 100, 100, 0, 10, gearDownChanged)      

      form.addRow(2)
      form.addLabel({label="Pitot Calibration Factor (%)", width=220})
      form.addIntbox(pitotCal, 1, 200, 100, 0, 1, pitotCalChanged)
      
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

local function getIdx(tbl, val)
   for k,v in ipairs(tbl) do
      if v == val then
	 return k
      end
   end
   return 0
end


local function init()

   local fg
   
   throttleChannel = system.pLoad("throttleChannel", "P4")
   throttleIdx = getIdx(controlInputs, throttleChannel)
   throttleFull = system.pLoad("throttleFull", 90)
   throttleIdle = system.pLoad("throttleIdle", -90)
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

   system.registerForm(1, MENU_APPS, "Config File Editor", initForm, keyPressed, printForm)

   jsonFile = "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_")
   --print("jsonFile:", jsonFile)
   
   fg = io.readall(jsonFile)
   --print("return from io.readall:", fg)

   -- if model file exists, read it .. if not create it
   
   if fg then
      --print("file read, decoding")
      --modelProps=json.decode(fg)
      jsonSetLocals(fg)
   else
      --print("writing file")
      jsonWriteFile()
   end
   

   --readSensors()
   
end

--------------------------------------------------------------------------------

jsonEditorVersion = "0.0"
setLanguage()

collectgarbage()

return {init=init, loop=loop, author="DFM", version=jsonEditorVersion,
	name="Config File Editor"}
