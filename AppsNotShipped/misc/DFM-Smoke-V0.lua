--[[

   While originally made for voice control, also works for "manual" smoke control, 
   e.g. controlled by a slider. Smoke volume when on set by the slider. +100 if no slider
   set. -100 for off. If you need 0-100 instead you can use a freemix.

   For voice control the program acts as an  SR Flip Flop
   one voice command turns smoke on, a second command turns it off

   When using voice on/off .. if a volume control is defined, it determines the 
   on value

   Prevents startup with smoke on

   Optional master enable/disable switch

   Released under MIT-license by DFM 2019
        
--]]

local smokeState, smV
local smokeOnSw, smokeOffSw, smokeEnableSw, smokeOnVal, smokeOffVal
local smokeThrMin
local smokeVolControl
local smokeVolIdx
local startupOn = false
local thrCtl
local volString={"...", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10"}

-- using volString because addInputBox has a limitation. The input reads as nil if never assigned
-- but is not nil if assigned and then unassigned. this seems the only way to know. Same issue
-- with switchitems but no idea how to get around that with a 3-pos sw. 2-pos is nil if not
-- assigned, but returns 0 if assigned and unassigned .. that is ok since only +1 and -1 are
-- valid. With 3 pos no way to know if really 0 or unassigned. sigh.

local function setLanguage()
   --[[
   local lng=system.getLocale()
   print("lng:", lng)
   local file = io.readall("Apps/Lang/DFM-MomFF.jsn")
   print("file:", file)
   
   local obj
   if file then obj = json.decode(file) end
   print("obj:", obj)
   if(obj) then
      trans4 = obj[lng] or obj[obj.default]
   end
   --]]
end

local function smokeOnSwChanged(value)
   smokeOnSw = value
   system.pSave("smokeOnSw",value)
end

local function smokeOffSwChanged(value)
   smokeOffSw = value
   system.pSave("smokeOffSw",value)
end

local function smokeOnValChanged(value)
   smokeOnVal = value
   system.pSave("smokeOnVal",value)
end

local function smokeOffValChanged(value)
   smokeOffVal = value
   system.pSave("smokeOffVal",value)
end

local function smokeEnableSwChanged(value)
   smokeEnableSw = value
   system.pSave("smokeEnableSw",value)
end

local function smokeThrMinChanged(value)
   smokeThrMin = value
   system.pSave("smokeThrMin", value)
end

local function smokeVolControlChanged(value)
   smokeVolControl = value
   system.pSave("smokeVolControl", value)
end

local function smokeVolIdxChanged(value)
   smokeVolIdx = value
   --print("idx:", value)
   system.pSave("smokeVolIdx", value)
end

--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)

local function initForm()

   form.addRow(2)
   form.addLabel({label="Volume Control",font=FONT_NORMAL, width=220})
   form.addSelectbox(volString, smokeVolIdx, true, smokeVolIdxChanged) 
   
   form.addRow(2)
   form.addLabel({label="ON Voice Control (V01...V15)",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeOnSw, false, smokeOnSwChanged) 
   
   form.addRow(2)
   form.addLabel({label="OFF Voice Control (V01...V15)",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeOffSw, false, smokeOffSwChanged)

   --form.addRow(2)
   --form.addLabel({label="Smoke ON Value (%)",font=FONT_NORMAL, width=220})
   --form.addIntbox(smokeOnVal, -100, 100, 100, 0, 10, smokeOnValChanged)

   form.addRow(2)
   form.addLabel({label="OFF Value (-100% or 0%)",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeOffVal, -100, 0, -100, 0, 100, smokeOffValChanged)

   form.addRow(2)
   form.addLabel({label="Low throttle cutoff (0-100%)",font=FONT_NORMAL, width=220})
   form.addIntbox(smokeThrMin, 0, 100, 0, 0, 1, smokeThrMinChanged)   
   
   form.addRow(2)
   form.addLabel({label="Master Enable Switch",font=FONT_NORMAL, width=220})
   form.addInputbox(smokeEnableSw, false, smokeEnableSwChanged)
   
   form.addRow(1)
   form.addLabel({label="Version " .. smokeVersion .." ",font=FONT_MINI, alignRight=true})
end



local function printForm()
   local ss
   local text = smokeState == 1 and "ON" or "OFF"
   local y0 = 0
   local iV
   iV = math.floor(smV + 0.5)
  
   form.setTitle("Smoke Function (S01): " .. text .. " (" .. iV .. ")",FONT_NORMAL)
   --[[
	
   lcd.drawText(10,y0,"Smoke Function (S01): " .. text .. " (" .. smV .. ")",FONT_NORMAL)

   lcd.setColor(0,0,255)
   lcd.drawRectangle(195, y0+4, 96, 14)
   lcd.drawLine(195+48, y0+4, 195+48, y0+17)

   ss = smV/100
   if ss >= 0 then
      lcd.drawFilledRectangle(195+48, y0+4, ss*48, 14)
   else
      lcd.drawFilledRectangle(195+48+math.floor(ss*48+.5), y0+4, math.floor(-48*ss+.5), 14)
   end
   
   lcd.setColor(0,0,0)
   --]]
end

local function loop()

   local smOn, smOff, smEn
   local thr 
   local vol
   local stm
   local swtbl = {}
   
   smOn, smOff, smEn = system.getInputsVal(smokeOnSw,smokeOffSw,smokeEnableSw)

   thr = system.getInputs(thrCtl)

   if smokeVolIdx > 1 then
      vol= system.getInputs(volString[smokeVolIdx])
      --print("idx, vol:", smokeVolIdx, volString[smokeVolIdx])
   end

   -- if sm* never defined, it's nil. if defined and removed, it's 0
   -- valid settings are -1 and 1 .. so make 0 be the undefnied indicator
   -- good thing it's not 3 positions...

   -- here is the soln!
   
   --print("smokeOnSw: ", smokeOnSw)
   --if smokeOnSw then
   --   swtbl = system.getSwitchInfo(smokeOnSw)
   --   print("label: ", swtbl.label)
   --   print("value: ", swtbl.value)
   --   print("proportional: ", swtbl.proportional)
   ---  print("assigned: ", swtbl.assigned)
   --end
   

   if not smOn then smOn = 0 end
   if not smOff then smOff = 0 end
   if not smEn then smEn = 0 end
   
   -- startupOn is to make sure we don't start w/smoke on   

   if (smOn == 0 or smOn == -1) and (not vol or vol < -0.98) then startupOn = false end 
      
   if smOn ==1 and smOff == 1 then
      --
   elseif (smOn == 1 and smokeState == 0 and not startupOn) then
      smokeState = 1
      system.playFile('/Apps/DFM-Smoke/smoke_on.wav', AUDIO_IMMEDIATE)      
   elseif (smOff == 1 and smokeState == 1) then
      smokeState = 0
      system.playFile('/Apps/DFM-Smoke/smoke_off.wav', AUDIO_IMMEDIATE)
   end

   -- if no voice switches enabled but the volume control _is_ defined, use that as control
   -- no "smoke on" or "smoke off" announcement needed since we are moving a physical control

   if smOn == 0  and smOff == 0 and smokeVolIdx > 1 and not startupOn then
      smokeState = 1
   end

   if (smEn == -1)  then
      smokeState = 0
   end

   -- don't set smokeState to 0 when below min throttle .. so it can come back on
   -- smokeThrMin is 0-100%, stm is -100 to 100
   
   stm = smokeThrMin * 2 - 100
   
   if smokeState == 0 or (thr*100 < stm) then
      smV = smokeOffVal
   else
      if vol then smV = smokeOnVal * vol else smV = smokeOnVal end
      if smokeOffVal == 0 then -- if smoke pump requires 0-100 vs -100 to 100
	 smV = (smV + 100) / 2
      end
      
   end
   
   -- print("setting to: ", smV/100)
   
   system.setControl(5, smV/100, 10, 0)

end

local function smokeCB(w,h)

   local y0 = 0
   local x0 = 10

   if smokeState == 0 then
      lcd.drawText(x0,y0,"Smoke Off",FONT_NORMAL)
      return
   else
      lcd.drawText(x0,y0, math.floor(smV+0.5) ,FONT_NORMAL)
   end
   
   
   lcd.setColor(0,0,255)
   lcd.drawRectangle(x0+40, y0+4, 96, 14)
   lcd.drawLine(x0+40+48, y0+4, x0+48+40, y0+17)
   
   ss = smV/100
   if ss >= 0 then
      lcd.drawFilledRectangle(x0+40+48, y0+4, ss*48, 14)
   else
      lcd.drawFilledRectangle(x0+40+48+math.floor(ss*48+.5), y0+4, math.floor(-48*ss+.5), 14)
   end
   
   lcd.setColor(0,0,0)
end

local function smokeCBTxt(w,h)

   local text, isV

   isV = math.floor(smV + 0.5)
   
   if smokeState == 0 then
      text = "Smoke off"
   else
      if smV then text = "Smoke on " .. isV .. "%" end
   end

   lcd.drawText(5,5,text)

end

local function logCB(i)
   return 1,2
end

local function init()
   local fg
   
   system.registerForm(1,MENU_APPS, "Smoke Controller", initForm, nil, printForm)
   system.registerControl(5, "Smoke Control", "S01")
   system.registerTelemetry(1, "Smoke Controller", 1, smokeCB)
   smokeOnSw = system.pLoad("smokeOnSw")
   smokeOffSw = system.pLoad("smokeOffSw")

   smokeEnableSw = system.pLoad("smokeEnableSw")
   smokeOnVal = system.pLoad("smokeOnVal", 100)
   smokeOffVal = system.pLoad("smokeOffVal", -100)
   smokeThrMin = system.pLoad("smokeThrMin", -100)
   smokeVolControl = system.pLoad("smokeVolControl")
   smokeVolIdx = system.pLoad("smokeVolIdx", 1)
   
   if smokeVolIdx > 1 and system.getInputs(volString[smokeVolIdx]) > -0.98 then
      system.messageBox("Smoke Volume Ctl Not OFF")
      print("system.getInputs(volString[smokeVolIdx]): ", system.getInputs(volString[smokeVolIdx]))
      startupOn = true
   end
   
   if system.getInputsVal(smokeOnSw) == 1 then
      system.messageBox("Smoke enabled - forcing off")
      startupOn = true
   end

   smokeState = 0
   smV = smokeOffVal
   system.setControl(5, smokeOffVal, 0, 0)
   --system.setVario(1.2, true, false)
   --system.registerLogVariable("TestLogVar", "m", logCB)
   print("getDeviceType:", system.getDeviceType())

   thrCtl = "P4"
   
   fg = io.readall("Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_"))
   if fg then
      modelProps=json.decode(fg)
      thrCtl = modelProps.throttleChannel
      print("read thrCtl:", thrCtl)
   end

   system.playFile('/Apps/DFM-Smoke/Smoke_Controller_Active.wav', AUDIO_QUEUE)
   
   collectgarbage()
end

smokeVersion = "1.0"
setLanguage()
collectgarbage()

return {init=init, loop=loop, author="DFM", version=smokeVersion, name="Smoke Controller"}
