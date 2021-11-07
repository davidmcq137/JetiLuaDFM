--CTU-Dashboard Twin engine version
-- v1.11 DFM 02-Dec-19 Added cache value if fuel level temporarily not valid

local wVersion="1.11"
local wAppname="CTU-Twin Dashboard"
local rootDir="/Apps"

-- Locals for the application

local wBrand="digitech"
local wbRPMParam = {}
local wbEGTParam = {}
local wbFuelParam = {}
local wbBattParam = {}
local wbPumpParam = {}
local wbStatusParam = {}
local sensorList = {"CTU","CTU#1"}
local wbSensorID = {}
local wbECUType = {}
local wbLastECUTypeFromStatus = {}
local wbStatusText = {}
local wbStatusPrev = {}
local eStatus = {}
local lFuel = {}
local lBatt = {}
local lPump = {}
local lPumpUnit = ""
local eRPM = {}
local lEGT = {}
local catalog
local gauge_c = {}
local gauge_f = {}
local maxRPM = 1
local maxEGT = 1
local cfgScheme = 1 -- Red
local fuelWarnEnabled = false
local fuelVoiceEnabled = false
local fuelThreshold = 20
local fuelVibration = 4
local fuelRepeat = 15
local fuelWarnTrigger = system.getTime()
local fuelWarnFormItem
local fuelVoiceFormItem
local fuelLowFile
local lastValidFuel
local lastValidFuelTime = 0
local fuelValid = false
local zeroFuelDelay = 4000
local cfgLang="en"
local textMessage={}
local langList={}
local langCode={}
local cfgLangIdx=1

local msgActive = {}
local lastEngineMessage=""
local lastMessageTime=""

local schemeOptions = {"Red" , "Blue" , "Green" ,"Black"}
local schemeColors = {{255,0,0},{0,0,255},{0,255,0},{0,0,0}}
local vibrationOptions = {"Left","Right","Both","None"}

local ENGINE_CHANGE_TIMEOUT=5

------------------------------------------------------------------------
-- Load images arrays
local function loadImages()
  local idx
  for idx = 0, 20, 1 do
    imgName = string.format("%s/%s/images/Twin/"..schemeOptions[cfgScheme].."/c-%.3d.png",rootDir, wBrand, idx * 5)
    gauge_c[idx] = lcd.loadImage(imgName)
  end
  for idx = 0, 20, 1 do
    imgName = string.format("%s/%s/images/Twin/"..schemeOptions[cfgScheme].."/f-%.3d.png", rootDir, wBrand, idx * 5)
    gauge_f[idx] = lcd.loadImage(imgName)
  end
end

------------------------------------------------------------------------
-- Load text Messages
local function loadLang()
  local content,e

  -- print(string.format("Lang %s", cfgLang))
  local file = io.readall(string.format("%s/%s/text/%s.jsn", rootDir, wBrand, cfgLang)) -- read the correct config file
  if (file) then
    textMessage = json.decode(file)
  end
  for e = 1,4,1 do
    vibrationOptions[e]=textMessage.message.vibrationOptions[tostring(e)]
  end

  langList={}
  langCode={}

  for name, filetype, size in  dir(string.format("%s/%s/text", rootDir, wBrand)) do

    if(string.sub(name,1,1)==".") then

    else
      local f = io.readall(string.format("%s/%s/text/%s", rootDir, wBrand, name)) -- read the correct config file
      if (f) then
        content = json.decode(f)
      end
      if(content.lang~=nil) then
        table.insert(langList,content.lang)
        table.insert(langCode,content.code)
        if(cfgLang==content.code) then cfgLangIdx=#langCode end
        print("Language "..content.lang.." detected")
      end
    end
  end
  collectgarbage()
end

--------------------------------------------------------------------
-- Get the ID of the CTU Sensor
function getWBSensorID()
  local tmpSensorID = {}

  for index, sensor in ipairs(system.getSensors()) do
    if (sensor.param == 0) then
      print("Sensor Name: ", sensor.label)
      hexSensorID = string.format("%x", sensor.id & 0xFFFF)
      hexSensorIndex = string.format("%x", math.floor(sensor.id/2^16))
      print(string.format("Sensor ID: %s, Index: %s",hexSensorID,hexSensorIndex))
      if (catalog.device[sensor.label] ~= nil) then
        print(string.format("Brand:%s - Model:%s - Version %s",catalog.device[sensor.label].brand,catalog.device[sensor.label].model,catalog.device[sensor.label].version))
        tmpSensorID[sensor.label] = sensor.id
        wbRPMParam[sensor.label] = tonumber(catalog.device[sensor.label].RPM)
        wbEGTParam[sensor.label] = tonumber(catalog.device[sensor.label].EGT)
        wbFuelParam[sensor.label] = tonumber(catalog.device[sensor.label].Fuel)
        wbBattParam[sensor.label] = tonumber(catalog.device[sensor.label].Batt)
        wbPumpParam[sensor.label] = tonumber(catalog.device[sensor.label].Pump)
        wbStatusParam[sensor.label] = tonumber(catalog.device[sensor.label].Status)
        collectgarbage()
      end
    end
  end
  collectgarbage()
  return tmpSensorID
end

local config = {}  -- complete turbine config object read from file with manufaWBrer name

--------------------------------------------------------------------
-- Fuel Alarms
local function fuelAlarm(percentage)
  if(fuelWarnEnabled) then
    local trigger=false
    for n,i in pairs(sensorList) do
      if(percentage[i]~=nil) then
        if(percentage[i]<fuelThreshold) then
          trigger=true
        end
      end
    end
    if(trigger) then
      if(fuelWarnTrigger<system.getTime()) then
        fuelWarnTrigger=system.getTime()+fuelRepeat
        if(fuelVoiceEnabled) then
          local fuelLowFile=string.format("%s/%s/audio/%s-low_fuel.wav", rootDir, wBrand, cfgLang)
          system.playFile(fuelLowFile, AUDIO_IMMEDIATE)
        end
        if(fuelVibration~=4) then
          if(fuelVibration==2 or fuelVibration==3) then
            system.vibration(true,2)
          end
          if(fuelVibration==1 or fuelVibration==3) then
            system.vibration(false,2)
          end
        end
      end
    else
      fuelWarnTrigger=system.getTime()
    end
  end
end

--------------------------------------------------------------------
-- Fuel Gauge
local function DrawFuelGauge(percentage)

  local ox, oy, num

  ox={182,182+60}
  oy={2,2}
  num=1

  for n,i in pairs(sensorList) do
    if(percentage[i]~=nil) then
      value = percentage[i] / 5
      upValue = math.ceil(value)
      downValue = math.floor(value)

      if math.abs(value - upValue) > math.abs(value - downValue) then
        value = downValue
      else
        value = upValue
      end

      if (percentage[i] < fuelThreshold and system.getTime() % 2 == 0) then
        value = 0
      end
      textFuel=string.format("%d%%",percentage[i])
      lcd.drawText(ox[num]+25-lcd.getTextWidth(FONT_NORMAL, textFuel)/2, oy[num]+16, textFuel, FONT_NORMAL)
      lcd.drawText(ox[num]+18, oy[num]+40, string.format("#%d",num), FONT_MINI)
      lcd.drawImage(ox[num], oy[num], gauge_f[value])
      num=num+1
    end
  end
  if not fuelValid then
     lcd.setColor(200,200,200)
  end
  lcd.drawText((ox[1]+ox[2])/2+15, oy[1]+45, "FUEL", FONT_MINI)
  lcd.setColor(0,0,0)
end
--------------------------------------------------------------------
-- RPM Gauge
local function DrawRpmGauge(iRPM)

  local value, upValue, downValue, textRPM, ox, oy, num

  ox={1,1+73}
  oy={2,2}
  num=1
  engName={"x1000 #1","x1000 #2"}
  engNameSize={FONT_MINI,FONT_MINI}
  engNameLen={lcd.getTextWidth(engNameSize[1], engName[1]),lcd.getTextWidth(engNameSize[2], engName[2])}


  for n,i in pairs(sensorList) do
    if(iRPM[i]~= nil) then
      value = iRPM[i] / (maxRPM * 1000) * 20
      if value>20 then value=20 end
      upValue = math.ceil(value)
      downValue = math.floor(value)

      if math.abs(value - upValue) > math.abs(value - downValue) then
        value = downValue
      else
        value = upValue
      end

      textRPM = string.format("%d", iRPM[i] / 1000)

      lcd.drawRectangle(ox[num]+39, oy[num]+16, 30, 18)
      lcd.drawText(ox[num] + 36 - engNameLen[num]/2, oy[num] + 38, engName[num], engNameSize[num])
      lcd.drawText(ox[num] + 68 - lcd.getTextWidth(FONT_NORMAL, textRPM) , oy[num] + 15, textRPM, FONT_NORMAL)

      if gauge_c[value] ~= nil then
        lcd.drawImage(ox[num], oy[num], gauge_c[value])
      end
      num=num+1
    end
  end
  lcd.drawText((ox[1]+ox[2])/2 + 21, oy[1] + 62, "RPM", FONT_NORMAL)
end

--------------------------------------------------------------------
-- EGT Gauge
local function DrawEgtGauge(iEGT)
  local value, upValue, downValue, textEGT, ox, oy, num

  ox={1,1+73}
  oy={80,80}
  num=1

  engName={"°C #1","°C #2"}
  engNameSize={FONT_MINI,FONT_MINI}
  engNameLen={lcd.getTextWidth(engNameSize[1], engName[1]),lcd.getTextWidth(engNameSize[2], engName[2])}

  for n,i in pairs(sensorList) do
    if(iEGT[i]~=nil) then
      value = iEGT[i] / maxEGT * 20
      if value>20 then value=20 end
      upValue = math.ceil(value)
      downValue = math.floor(value)
      textEGT = string.format("%d", iEGT[i])

      if math.abs(value - upValue) > math.abs(value - downValue) then
        value = downValue
      else
        value = upValue
      end

      lcd.drawRectangle(ox[num]+37, oy[num]+16, 32, 18)
      lcd.drawText(ox[num] + 36-engNameLen[num]/2, oy[num] + 38, engName[num], engNameSize[num])
      lcd.drawText(ox[num] + 68 - lcd.getTextWidth(FONT_NORMAL, textEGT) , oy[num] + 15, textEGT, FONT_NORMAL)


      if gauge_c[value] ~= nil then
        lcd.drawImage(ox[num], oy[num], gauge_c[value])
      end
      num=num+1
    end
  end
  lcd.drawText((ox[1]+ox[2])/2 + 21, oy[1] + 62, "EGT", FONT_NORMAL)
end
--------------------------------------------------------------------
-- Trubine Status
local function DrawTurbineStatus(iStatus)
  local ox, oy, H, W, num

  ox= {160,160}
  oy= {119,139}
  num=1
  H = 20
  W = 159

  engName={"Eng1","Eng2"}
  engNameSize={FONT_NORMAL,FONT_NORMAL}
  engNameLen={lcd.getTextWidth(engNameSize[1], engName[1]),lcd.getTextWidth(engNameSize[2], engName[2])}

  lcd.drawRectangle(ox[1], oy[1], W, oy[2]-oy[1]+H)

  for n,i in pairs(sensorList) do
    if(iStatus[i]~=nil) then
      statusText=engName[num]..":"..iStatus[i]
      lcd.drawText(ox[num]+2, oy[num]+1, statusText, FONT_NORMAL)
      num=num+1
    end
  end
end
--------------------------------------------------------------------
-- Voltages
local function DrawVoltages(u_pump, u_ecu)

  local ox,oy,num

  local W = 78
  local H = 20
  local rF,gF,bF=lcd.getFgColor()
  local rB,gB,bB=lcd.getBgColor()

  pumpLabel={"PUMP #1","PUMP #2"}
  pumpLabelLen={lcd.getTextWidth(FONT_MINI,pumpLabel[1]),lcd.getTextWidth(FONT_MINI,pumpLabel[2])}
  ecuLabel={"ECU #1","ECU #2"}
  ecuLabelLen={lcd.getTextWidth(FONT_MINI,ecuLabel[1]),lcd.getTextWidth(FONT_MINI,ecuLabel[2])}

  num=1

  ox={160,160+80}
  oy={60,60}

  for n,i in pairs(sensorList) do
    if(u_pump[i]~=nil) then
      lcd.setColor(math.abs(rF-rB)/2,math.abs(gF-gB)/2,math.abs(gF-gB)/2)
      lcd.drawRectangle(ox[num], oy[num]+7, W, H)
      lcd.drawRectangle(ox[num], oy[num]+H+15, W, H)
      lcd.setColor(rB,gB,bB)
      lcd.drawFilledRectangle(ox[num]+(W-pumpLabelLen[num])/2,oy[num],pumpLabelLen[num]+4,10)
      lcd.drawFilledRectangle(ox[num]+(W-ecuLabelLen[num])/2,oy[num]+H+9,ecuLabelLen[num]+4,10)
      lcd.setColor(rF,gF,bF)
      lcd.drawText(ox[num]+(W-pumpLabelLen[num])/2+2, oy[num], pumpLabel[num], FONT_MINI)
      lcd.drawText(ox[num]+(W-ecuLabelLen[num])/2+2, oy[num]+H+9, ecuLabel[num], FONT_MINI)

      if (lPumpUnit == "V") then
        textPump = string.format("%.2f V", u_pump[i])
      else
        textPump = string.format("%d", u_pump[i])
      end
      textPumpLen=lcd.getTextWidth(FONT_NORMAL,textPump)
      lcd.setColor(schemeColors[cfgScheme][1],schemeColors[cfgScheme][2],schemeColors[cfgScheme][3])
      lcd.drawText(ox[num]+(W-textPumpLen)/2+2, oy[num]+9, textPump, FONT_NORMAL)

      textECU = string.format("%.1f V", u_ecu[i])
      textECULen=lcd.getTextWidth(FONT_NORMAL,textECU)
      lcd.setColor(schemeColors[cfgScheme][1],schemeColors[cfgScheme][2],schemeColors[cfgScheme][3])
      lcd.drawText(ox[num]+(W-textECULen)/2+2, oy[num]+18+H, textECU, FONT_NORMAL)

      num=num+1
      lcd.setColor(rF,gF,bF)
    end
  end
end

--------------------------------------------------------------------
-- Get Telemetry values
local function wbTele(w,h)
  DrawFuelGauge(lFuel)
  DrawRpmGauge(eRPM)
  DrawEgtGauge(lEGT)
  DrawTurbineStatus(eStatus)
  DrawVoltages(lPump, lBatt)
end

------------------------------------------------------------------------
-- Register Telemetry form
local function registerTelemetryForm()
  system.registerTelemetry(1, wAppname, 4, wbTele)
end

--------------------------------------------------------------------
-- Read messages file
local function readCatalog()
  local file = io.readall(string.format("%s/%s/catalog.jsn",rootDir, wBrand)) -- read the catalog config file
  if (file) then
    catalog = json.decode(file)
  end
  collectgarbage()
end
--------------------------------------------------------------------
-- Read messages file
local function readConfig(wECUType)
  print(string.format("ECU Type %s", wECUType))
  local file = io.readall(string.format("%s/%s/%s", rootDir, wBrand, catalog.ecu[tostring(wECUType)].file)) -- read the correct config file
  if (file) then
    config = json.decode(file)
  end
  collectgarbage()
end

------------------------------------------------------------------------
-- Get the text corresponding to the status and speak
local function getStatusText(wEng,statusSensorID,wStatusParam)
  local lStatus = ""
  local value = 0 -- sensor value
  local ecuStatus = 0
  local switch
  local lSpeech
  local sensor = system.getSensorByID(statusSensorID, wStatusParam)

  if (sensor and sensor.valid) then
    value = string.format("%s", math.floor(sensor.value))
    -- print("Status Sensor Id",statusSensorID)
    -- wbLastECUTypeFromStatus[system.getSensorByID(statusSensorID, 0).label] = value >> 8
    wbLastECUTypeFromStatus[wEng] = value >> 8
    ecuStatus = value & 0xFF

    if (ecuStatus ~= wbStatusPrev[wEng]) then
      print(string.format("Engine %s Status %d",wEng,ecuStatus))
      if (config.message[tostring(ecuStatus)] ~= nil) then
        lStatus = config.message[tostring(ecuStatus)].text
        if (lStatus == nil) then
          lStatus = "[unknown]"
        end
        if(config.message[tostring(ecuStatus)].active) then
          lSpeech=config.message[tostring(ecuStatus)][cfgLang]
          -- print("Lang:",cfgLang)
          -- print("Status audio file (localized):",lSpeech)
          if(lSpeech==nil) then
            lSpeech = config.message[tostring(ecuStatus)].speech
            -- print("Status audio file (default):",lSpeech)
          end
          if (lSpeech ~= nil) then
            if(wEng~=lastEngineMessage or system.getTime()-lastMessageTime>ENGINE_CHANGE_TIMEOUT) then
              system.playFile(string.format("%s/%s/audio/%s-engine_%s.wav", rootDir, wBrand,cfgLang,wEng), AUDIO_QUEUE)
              lastEngineMessage=wEng
              lastMessageTime=system.getTime()
            end
            -- print(string.format("Status  %s", tostring(lSpeech)))
            system.playFile(string.format("%s/%s/audio/%s", rootDir, wBrand, lSpeech), AUDIO_QUEUE)
          end
        end
      end
      wbStatusText[wEng] = lStatus
      wbStatusPrev[wEng] = ecuStatus
    else
      lStatus = wbStatusText[wEng]
    end
  else
    lStatus = "          -- "
  end

  return lStatus
end
------------------------------------------------------------------------
-- Get the ECU Type
local function getWBECUType(statusSensorID,wStatusParam)
  local validECU
  local value = 0 -- sensor value
  local ecuType = nil
  local sensor = system.getSensorByID(statusSensorID, tonumber(wStatusParam))

  if (sensor and sensor.valid) then
    value = sensor.value
    ecuType = value >> 8
    validECU = (catalog.ecu[tostring(ecuType)] ~= nil)
    if (validECU) then
      readConfig(ecuType)
    else
      ecuType = nil
    end
  else
    ecuType = nil
  end
  return ecuType
end
------------------------------------------------------------------------
-- Get EGT From telemtry data
local function getEGT(statusSensorID,wEGTParam)
  local value = 0 -- sensor value
  local sensor = system.getSensorByID(statusSensorID,wEGTParam)

  if (sensor and sensor.valid) then
    value = sensor.value
  else
    value = 0
  end
  return value
end
------------------------------------------------------------------------
-- Get RPM From telemtry data
local function getRPM(statusSensorID,wRPMParam)
  local value = 0 -- sensor value
  local sensor = system.getSensorByID(statusSensorID, wRPMParam)

  if (sensor and sensor.valid) then
    value = sensor.value
  else
    value = 0
  end
  return value
end
------------------------------------------------------------------------
-- Get Fuel remaining From telemtry data
local function getFuel(statusSensorID,wFuelParam)
  local value = 0 -- sensor value
  local sensor = system.getSensorByID(statusSensorID, wFuelParam)

    if (sensor and sensor.valid) then
       value = sensor.value
       lastValidFuel = value
       lastValidFuelTime = system.getTimeCounter()
       fuelValid = true
    else
       fuelValid = false
       if not lastValidFuel then
	  return 0
       end
       if system.getTimeCounter() - lastValidFuelTime < zeroFuelDelay then
	  return lastValidFuel
       else
	  lastValidFuel = nil
	  return 0
       end
    end
    return value

end
------------------------------------------------------------------------
-- Get Pump voltage/pw From telemtry data
local function getPump(statusSensorID,wPumpParam)
  local value = 0 -- sensor value
  local sensor = system.getSensorByID(statusSensorID, wPumpParam)

  if (sensor and sensor.valid) then
    value = sensor.value
    lPumpUnit = sensor.unit
  else
    value = 0
  end
  return value
end
------------------------------------------------------------------------
-- Get Battery voltage From telemtry data
local function getBatt(statusSensorID,wBattParam)
  local value = 0 -- sensor value
  local sensor = system.getSensorByID(statusSensorID, wBattParam)

  if (sensor and sensor.valid) then
    value = sensor.value
  else
    value = 0
  end
  return value
end

----------------------------------------------------------------------
-- Actions when settings changed
local function maxRPMChanged(value)
  local pSave = system.pSave
  pSave("maxRPM", value)
  maxRPM=value
end

local function maxEGTChanged(value)
  local pSave = system.pSave
  pSave("maxEGT", value)
  maxEGT=value
end

local function schemeChanged(value)
  system.pSave("cfgScheme",value)
  cfgScheme=value
  loadImages()
end

local function fuelWarnChanged(value)
  if(value) then system.pSave("cfgFuelWarn",1) else system.pSave("cfgFuelWarn",0) end
  fuelWarnEnabled=value
end

local function fuelThresholdChanged(value)
  system.pSave("cfgFuelThreshold",value)
  fuelWarnEnabled=value
end

local function fuelVoiceChanged(value)
  if(value) then  system.pSave("cfgFuelVoice",1) else system.pSave("cfgFuelVoice",0) end
  fuelVoiceEnabled=value
end

local function fuelRepeatChanged(value)
  system.pSave("cfgFuelRepeat",value)
  fuelRepeat=value
end

local function fuelVibrationChanged(value)
  system.pSave("cfgFuelVibration",value)
  fuelVibration=value
end

local function langChanged(value)
  system.pSave("cfgLang",langCode[value])
  cfgLang=langCode[value]
  loadLang()
  form.reinit(1)
end

------------------------------------------------------------------------
-- Save message config and exit
local function saveMsgConfig(i)
  local configEncoded
  configEncoded=json.encode(config)
  print(string.format("Saving ecu file %s/%s/%s",rootDir, wBrand, catalog.ecu[tostring(wbECUType[i])].file))
  local f = io.open(string.format("%s/%s/%s", rootDir, wBrand, catalog.ecu[tostring(wbECUType[i])].file),"w")
  io.write(f,configEncoded)
  io.close(f)
  form.reinit(1)
end

--------------------------------------------------------------------------------
-- App Config form
local function initForm(subForm)

  local form, addRow, addLabel = form, form.addRow, form.addLabel
  local addIntbox, addCheckbox = form.addIntbox, form.addCheckbox
  local addSelectbox, addInputbox = form.addSelectbox, form.addInputbox

  local fw = tonumber(string.format("%.2f", system.getVersion()))
  if (fw >= 4.22) then
    if(subForm==1) then

      addRow(2)
      addLabel({label = textMessage.message.menuLabelColour,width =220})
      addSelectbox(schemeOptions,cfgScheme,true,schemeChanged)

      addRow(2)
      addLabel({label = textMessage.message.menuLabelMaxRPM, width = 220})
      addIntbox(maxRPM, 1, 300, 1, 0, 1, maxRPMChanged)

      addRow(2)
      addLabel({label = textMessage.message.menuLabelMaxEGT, width = 220})
      addIntbox(maxEGT, 10, 1000, 0, 0, 10, maxEGTChanged)

      form.addLink((function() form.reinit(2) end), {label = textMessage.message.menuLabelConfMess})
      form.addLink((function() form.reinit(3) end), {label = textMessage.message.menuLabelFuelWarns})

      addRow(2)
      addLabel({label = textMessage.message.menuLabelLang,width =220})
      addSelectbox(langList,cfgLangIdx,true,langChanged)

      addRow(1)
      addLabel({label = wAppname .. " - v." .. WBDashVersion .. " ", font = FONT_MINI, alignRight = true})
    end

    if(subForm==2) then

      form.setButton(5,"Cancel",ENABLED)
      local i=sensorList[1]

      addRow(1)
      addLabel({label=textMessage.message.menuInfoForm2,enabled=false,font=FONT_MINI})

      if(wbECUType[i]==nil) then
        addRow(1)
        addLabel({label = string.format("%s (%s)",textMessage.message.menuInfoNoECU,i)})
        form.addLink((function() form.reinit(1) end), {label = textMessage.message.menuLabelBack,font=FONT_BOLD})
      else
        form.addLink((function() saveMsgConfig(i) end), {label = textMessage.message.menuLabelBackSave,font=FONT_BOLD})
        for s, n in pairs(config.message) do
          addRow(2)
          addLabel({label = n.text, width = 220})
          if(config.message[s].active==nil) then config.message[s].active=false end
          msgActive[s]=addCheckbox(config.message[s].active,(function(value) config.message[s].active=not value form.setValue(msgActive[s],not value) end))
        end
      end

    end

    if(subForm==3)then
      -- form.setButton(5,"Cancel",ENABLED)
      addRow(1)
      addLabel({label=textMessage.message.menuInfoForm3,enabled=false,font=FONT_MINI})

      addRow(1)
      form.addLink((function() form.reinit(1) end), {label = textMessage.message.menuLabelBack,font=FONT_BOLD})

      addRow(2)
      addLabel({label=textMessage.message.menuLabelEnableFuelWarn,width=220})
      fuelWarnFormItem=addCheckbox(fuelWarnEnabled,(function(value) fuelWarnEnabled=not value fuelWarnChanged(not value) form.setValue(fuelWarnFormItem,not value) end))

      addRow(2)
      addLabel({label=textMessage.message.menuLabelLowFuel,width=220})
      addIntbox(fuelThreshold, 0, 100, 10, 0, 10, fuelThresholdChanged)

      addRow(2)
      addLabel({label=textMessage.message.menuLabelFuelVoice,width=220})
      fuelVoiceFormItem=addCheckbox(fuelVoiceEnabled,(function(value) fuelVoiceEnabled=not value fuelVoiceChanged(not value) form.setValue(fuelVoiceFormItem,not value) end))

      addRow(2)
      addLabel({label = textMessage.message.menuLabelFuelVibration,width =220})
      addSelectbox(vibrationOptions,fuelVibration,true,fuelVibrationChanged)

      addRow(2)
      addLabel({label=textMessage.message.menuLabelFuelInterval,width=220})
      addIntbox(fuelRepeat, 5, 60, 10, 0, 5, fuelRepeatChanged)

    end
  else
    local addRow, addLabel = form.addRow, form.addLabel
    addRow(1)
    addLabel({label = "Please update, min. fw 4.22 required!"})
  end
end


------------------------------------------------------------------------
-- Application initialization.
local function init(code)
  local idx

  readCatalog()

  wBrand = catalog.config.brand

  wbSensorID = getWBSensorID()

  maxRPM = system.pLoad("maxRPM", 1)
  maxEGT = system.pLoad("maxEGT", 1)
  cfgScheme = system.pLoad("cfgScheme",1)
  fuelThreshold = system.pLoad("cfgFuelThreshold",20)
  fuelWarnEnabled = system.pLoad("cfgFuelWarn",0)==1
  fuelVoiceEnabled = system.pLoad("cfgFuelVoice",0)==1
  fuelVibration = system.pLoad("cfgFuelVibration",4)
  fuelRepeat = system.pLoad("cfgFuelRepeat",15)
  cfgLang = system.pLoad("cfgLang","en")

  loadImages()
  loadLang()

  lastEngineMessage=""
  lastMessageTime=system.getTime()-ENGINE_CHANGE_TIMEOUT

  registerTelemetryForm()

  system.registerForm(1, MENU_APPS, wAppname .. " config", initForm)
end

------------------------------------------------------------------------
-- Main Loop function is called in regular intervals
local function loop()
  for i, n in pairs(wbSensorID) do
    if (wbSensorID[i] ~= nil and wbSensorID[i] ~= 0 and wbECUType[i] ~= nil) then

      -- check if status parameter is present (avoid crash when rescaning sensor)
      if(system.getSensorByID(tonumber(wbSensorID[i]),tonumber(wbStatusParam[i]))~=nil) then
        if (wbECUType[i] ~= wbLastECUTypeFromStatus[i]) then
          wbECUType[i] = getWBECUType(wbSensorID[i],wbStatusParam[i])
        end

        local validData=system.getSensorByID(wbSensorID[i],tonumber(wbStatusParam[i])).valid

        if(validData) then
          eStatus[i] = getStatusText(i,wbSensorID[i],wbStatusParam[i])
          lFuel[i] = getFuel(wbSensorID[i],wbFuelParam[i])
          lPump[i] = getPump(wbSensorID[i],wbPumpParam[i])
          lBatt[i] = getBatt(wbSensorID[i],wbBattParam[i])
          eRPM[i] = getRPM(wbSensorID[i],wbRPMParam[i])
          lEGT[i] = getEGT(wbSensorID[i],wbEGTParam[i])
          fuelAlarm(lFuel)
        end
      end
    else
      if (wbSensorID[i] == nil) then
        wbSensorID = getWBSensorID()
      end
      if (wbECUType[i] == nil and wbSensorID[i] ~= nil) then
        wbECUType[i] = getWBECUType(wbSensorID[i],wbStatusParam[i])
      end
    end
  end
end

WBDashVersion = wVersion
-- Application interface
return {init = init, loop = loop, author = "DM", version = wVersion, name = wAppname}
