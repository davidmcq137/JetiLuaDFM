-- CTU-Dashboard.lua

local wVersion="1.5"
local wAppname="CTU"

local DEBUG

-- Locals for the application

local wBrand="digitech"
local wbRPMParam = 2
local wbEGTParam = 3
local wbFuelParam = 1
local wbBattParam = 5
local wbPumpParam = 6
local wbStatusParam = 9
local modelProps={}

local ren = lcd.renderer()

local wbSensorID = nil
local wbECUType = nil
local wbECUTypePrev = nil
local wbStatusText = nil
local wbStatusPrev = nil
local lStatus = ""
local lFuel = 0
local lBatt = 0
local lPump = 0
local lPumpUnit = ""
local lRPM = 0
local lEGT = 0
local catalog
local gauge_c = {"..."}
local gauge_f = {"..."}
local maxRPM = 1
local maxEGT = 1
local cfgSize = 1 -- Compact
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
local zeroFuelDelay = 4000
local fuelValid = false

local cfgLang="en"
local textMessage={".."}
local langList={".."}
local langCode={".."}
local cfgLangIdx=1

local msgActive = {".."}


local sizeOptions = {"Compact","Large"}
local schemeOptions = {"Red" , "Blue" , "Green" ,"Black"}
local vibrationOptions = {"Left","Right","Both","None"}


------------------------------------------------------------------------
-- Load images arrays
local function loadImages()
    local sizeOpt = {"Compact","Large"}
    local idx = 0
    local wBrand="digitech"
    imgName = string.format("Apps/%s/images/"..sizeOpt[cfgSize].."/"..
			       schemeOptions[cfgScheme].."/c-%.3d.png", wBrand, idx * 5)
    -- print("loading image: ", imgName)
    gauge_c[idx] = lcd.loadImage(imgName)

end

------------------------------------------------------------------------
-- Load text Messages
local function loadLang()
    local content,e

    -- print(string.format("Lang %s", cfgLang))
    local file = io.readall(string.format("Apps/%s/text/%s.jsn", wBrand, cfgLang)) -- read the correct config file
    if (file) then
        textMessage = json.decode(file)
    end
    for e = 1,4,1 do
        vibrationOptions[e]=textMessage.message.vibrationOptions[tostring(e)]
    end
    for e = 1,2,1 do
        sizeOptions[e]=textMessage.message.sizeOptions[tostring(e)]
    end
 
    langList={}
    langCode={}

    for name, filetype, size in  dir(string.format("Apps/%s/text", wBrand)) do
        
        if(string.sub(name,1,1)==".") then
            
        else
            local f = io.readall(string.format("Apps/%s/text/%s", wBrand, name)) -- read the correct config file
            if (f) then
                content = json.decode(f)
            end
            if(content.lang~=nil) then
                table.insert(langList,content.lang)
                table.insert(langCode,content.code)
                if(cfgLang==content.code) then cfgLangIdx=#langCode end
                --print("Language "..content.lang.." detected")
            end
        end
    end
    collectgarbage()
end

--------------------------------------------------------------------
-- Get the ID of the WB Sensor
local function getWBSensorID()
    local tmpSensorID = nil

    for index, sensor in ipairs(system.getSensors()) do
        if (sensor.param == 0) then
            print("Sensor Name: ", sensor.label)
            hexSensorID = string.format("%x", sensor.id & 0xFFFF)
            hexSensorIndex = string.format("%x", math.floor(sensor.id/2^16))
            print(string.format("Sensor ID: %s, Index: %s",hexSensorID,hexSensorIndex))
            if (catalog.device[sensor.label] ~= nil) then
                print(string.format("Brand:%s - Model:%s - Version %s",catalog.device[sensor.label].brand,catalog.device[sensor.label].model,catalog.device[sensor.label].version))
                tmpSensorID = sensor.id
                wbRPMParam = tonumber(catalog.device[sensor.label].RPM)
                wbEGTParam = tonumber(catalog.device[sensor.label].EGT)
                wbFuelParam = tonumber(catalog.device[sensor.label].Fuel)
                wbBattParam = tonumber(catalog.device[sensor.label].Batt)
                wbPumpParam = tonumber(catalog.device[sensor.label].Pump)
                wbStatusParam = tonumber(catalog.device[sensor.label].Status)
                collectgarbage()
                return tmpSensorID
            end
        end
    end
    collectgarbage()
    return tmpSensorID
end

local config  -- complete turbine config object read from file with manufaWBrer name

--------------------------------------------------------------------
-- Fuel Alarms
local function fuelAlarm(percentage)
    if(fuelWarnEnabled) then
        if(percentage < fuelThreshold) then
            if(fuelWarnTrigger<system.getTime()) then
                fuelWarnTrigger=system.getTime()+fuelRepeat
                if(fuelVoiceEnabled) then
                    local fuelLowFile=string.format("Apps/%s/audio/%s-low_fuel.wav",wBrand, cfgLang)
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
local function DrawFuelGauge(percentage,size)

    local ox, oy, textPct

    value = percentage / 20

    if DEBUG then
       value = 2.5 * (system.getInputs('P4')+1)
       if system.getInputs('P5') > 0 then
	  percentage = value * 20
	  lastValidFuel = value * 20
	  lastValidFuelTime = system.getTimeCounter()
	  fuelValid = true
	  --print("valid")
       else
	  fuelValid = false
	  if system.getTimeCounter() - lastValidFuelTime < zeroFuelDelay then
	     percentage = lastValidFuel
	     --print("cached")
	  else
	     lastValidFuel = nil
	     percentage = 0
	     --print("cache dead --> 0")
	  end
       end
    end
    
    upValue = math.ceil(value)
    downValue = math.floor(value)

    if math.abs(value - upValue) > math.abs(value - downValue) then
        value = downValue
    else
        value = upValue
    end

--    if (percentage < fuelThreshold and system.getTime() % 2 == 0) then
--        value = 0
--    end

    if(size==1) then
        ox=75
        oy=56
	if not fuelValid then
	   lcd.setColor(200,200,200)
	end
	lcd.drawText(ox, oy, "FUEL", FONT_MINI)
	lcd.setColor(0,0,0)
	
	if percentage > fuelThreshold or system.getTime() % 2 == 0 then
	   lcd.drawFilledRectangle(ox + 26, oy - 2, math.max(2, 48 * percentage/100), 12)
	end

	if percentage < 50 then
	   textPct = string.format("%d%%", percentage)
	   lcd.drawText(ox + 50 + 10 - lcd.getTextWidth(FONT_MINI, textPct)/2, oy - 2, textPct, FONT_MINI)
	end
	
	lcd.drawRectangle(ox + 26, oy-2, 48, 13)
	--for i = 1, 3, 1 do
	  --lcd.drawLine(ox + 26 + i * 12, oy - 2, ox + 26 + i * 12, oy + 3)
	--end

	
        -- lcd.drawImage(ox + 25, oy + 1, gauge_f[value])
    else
        ox=160
        oy=135

	if not fuelValid then
	   lcd.setColor(200,200,200)
	end
	lcd.drawText(ox+7, oy+2, "FUEL", FONT_BOLD)
	lcd.setColor(0,0,0)
	
	if percentage > fuelThreshold or system.getTime() % 2 == 0 then
	   lcd.drawFilledRectangle(ox + 46, oy-1, math.max(2, 110*percentage/100), 25)
	end

	if percentage < 50 then
	   textPct = string.format("%d%%", percentage)
	   lcd.drawText(ox + 100 + 30 - lcd.getTextWidth(FONT_BOLD, textPct)/2, oy + 2, textPct, FONT_BOLD)
	end
	
	lcd.drawRectangle(ox + 46, oy-1, 108, 25)
	for i = 1, 3, 1 do
	   lcd.drawLine(ox + 46 + i * 27, oy - 1, ox + 46 + i * 27, oy + 4)
	end

        --lcd.drawImage(ox + 49, oy + 1, gauge_f[value])
    end
end
--------------------------------------------------------------------
--

local needle_poly_large = {
   {-4,28},
   {-2,65},
   {2,65},
   {4,28}
}

local needle_poly_small = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}

local function drawShape(col, row, shape, rotation)
   local sinShape, cosShape

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for index, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   lcd.setColor(255, 0, 0)
   ren:renderPolygon()
   lcd.setColor(0, 0, 0)
end

--------------------------------------------------------------------
-- RPM Gauge
local function DrawRpmGauge(iRPM, size)

    local textRPM, ox, oy, theta

    ox=1
    oy=2

    textRPM = string.format("%d", iRPM / 1000)

    if(size==1) then
        lcd.drawText(ox + 14, oy + 38, "RPM", FONT_MINI)
        lcd.drawText(ox + 25 - lcd.getTextWidth(FONT_BOLD, textRPM) / 2, oy + 16, textRPM, FONT_BOLD)
    else
        lcd.drawText(ox + 48, oy + 100, "RPM", FONT_NORMAL)
        lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textRPM) / 2, oy + 40, textRPM, FONT_MAXI)
    end

    theta = math.pi - math.rad(135 - 2*135*iRPM / (maxRPM * 1000))

    if gauge_c[0] ~= nil then
       if size == 1 then
	  lcd.drawImage(ox, oy, gauge_c[0])
	  drawShape(ox+25, oy+26, needle_poly_small, theta)
       else
	  lcd.drawImage(ox, oy, gauge_c[0])    
	  drawShape(ox+65, oy+60, needle_poly_large, theta)
       end
    end
    
end

--------------------------------------------------------------------
-- EGT Gauge
local function DrawEgtGauge(iEGT, size)
    local textEGT, ox, oy, jEGT

    jEGT = iEGT
    if DEBUG then
       jEGT = 400*(system.getInputs('P4')+1)
    end 
    
    textEGT = string.format("%d", jEGT)

    if(size==1) then
        ox=99
        oy=2
        lcd.drawText(ox + 15, oy + 38, "EGT", FONT_MINI)
        lcd.drawText(ox + 25 - lcd.getTextWidth(FONT_BOLD, textEGT) / 2, oy + 16, textEGT, FONT_BOLD)
    else
        ox=186
        oy=2
        lcd.drawText(ox + 52, oy + 100, "EGT", FONT_NORMAL)
        lcd.drawText(ox + 65 - lcd.getTextWidth(FONT_MAXI, textEGT) / 2, oy + 40, textEGT, FONT_MAXI)
    end

    theta = math.pi - math.rad(135 - 2*135*jEGT / maxEGT)

    if gauge_c[0] ~= nil then
       if size == 1 then
	  lcd.drawImage(ox, oy, gauge_c[0])
	  drawShape(ox+25, oy+26, needle_poly_small, theta)
       else
	  lcd.drawImage(ox, oy, gauge_c[0])    
	  drawShape(ox+65, oy+60, needle_poly_large, theta)
       end
    end
end
--------------------------------------------------------------------
-- Turbine Status
local function DrawTurbineStatus(status, size)
    local ox, oy, H, W, wFont, pstatus

    if(size==1) then
        ox= 0
        oy= 56
        H = 11
        W = 72
        wFont=FONT_MINI
    else
        ox= 0
        oy= 135
        H = 24
        W = 160
        wFont=FONT_BOLD
    end

    lcd.drawFilledRectangle(ox, oy, W, H)
    lcd.setColor(255, 255, 255)

    if #status == 0 then
       pstatus = "---"
    else
       pstatus = status
    end
    
    lcd.drawText(ox + (W - lcd.getTextWidth(wFont, pstatus)) / 2, oy, pstatus, wFont)
    lcd.setColor(0, 0, 0)
end
--------------------------------------------------------------------
-- Voltages
local function DrawVoltages(u_pump, u_ecu, u_rpm, size)

    local ox,oy
    local u_thr
    local u_rpmK
    
    local W = 44
    local H

    if(size==1) then
       H=47
       ox=53
       oy=5
    else
       H = 70
       ox=137
       oy=3
    end

    lcd.drawRectangle(ox, oy, W, H)
    lcd.drawText(8 + ox, oy, "PUMP", FONT_MINI)
    lcd.drawText(1 + ox, 23 + oy, "THRUST", FONT_MINI)
    lcd.drawLine(ox, oy + 23, ox + W - 1, oy + 23)
    if size ~= 1 then
       lcd.drawText(12 + ox, 46 + oy, "ECU", FONT_MINI)
       lcd.drawLine(ox, oy + 46, ox + W - 1, oy + 46)
    end
    

    if (lPumpUnit == "V") then
        textPump = string.format("%.2f", u_pump)
    else
        textPump = string.format("%d", u_pump)
    end
    
    lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, textPump)) / 2, oy + 7, textPump, FONT_BOLD)

    if size ~= 1 then
       textEcu = string.format("%.1f%s", u_ecu, "v")
       lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, textEcu)) / 2, oy + 53, textEcu, FONT_BOLD)
    end
    
    if DEBUG then
       u_rpm = 57000*(system.getInputs('P4')+1)
       lRPM = u_rpm
       u_rpmK = u_rpm / 1000.
    end
       
    if u_rpm then u_rpmK = u_rpm / 1000. end
    if u_rpmK and u_rpmK  > 30 then
       if modelProps.turbineName ~= "Unknown" then
	  u_thr = modelProps.turbineThrustTable[4] * u_rpmK^3
	     + modelProps.turbineThrustTable[3] * u_rpmK^2
	     + modelProps.turbineThrustTable[2] * u_rpmK
	     + modelProps.turbineThrustTable[1]
       end
    else
       u_thr = 0
    end
    if u_thr ~= 0 then
       textThr = string.format("%.1f%s", u_thr, "#")
       lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, textThr)) / 2, oy + 30, textThr, FONT_BOLD)
    else
       lcd.drawText(ox + (W - lcd.getTextWidth(FONT_BOLD, '---')) / 2, oy + 30, '---', FONT_BOLD)	  
    end
end

--------------------------------------------------------------------
-- Get Telemetry values
local function wbTele(w,h)
    DrawFuelGauge(lFuel, cfgSize)
    DrawRpmGauge(lRPM, cfgSize)
    DrawEgtGauge(lEGT, cfgSize)
    DrawTurbineStatus(lStatus, cfgSize)
    DrawVoltages(lPump, lBatt, lRPM, cfgSize)
end

------------------------------------------------------------------------
-- Register Telemetry form
local function registerTelemetryForm(size)
    if(size==1) then
       system.registerTelemetry(1, wAppname .. " - Turbine: " .. modelProps.turbineName,
				2, wbTele)
    end
    if(size==2) then
       system.registerTelemetry(1, wAppname .. " - Turbine: " .. modelProps.turbineName,
				4, wbTele)    
    end
end

--------------------------------------------------------------------
-- Read messages file
local function readCatalog()
    local file = io.readall(string.format("Apps/%s/catalog.jsn",wBrand)) -- read the catalog config file
    if (file) then
        catalog = json.decode(file)
    end
    collectgarbage()
end
--------------------------------------------------------------------
-- Read messages file
local function readConfig(wECUType)
    print(string.format("ECU Type %s", wECUType))
    local file = io.readall(string.format("Apps/%s/%s", wBrand, catalog.ecu[tostring(wECUType)].file)) -- read the correct config file
    if (file) then
        config = json.decode(file)
    end
    collectgarbage()
end

------------------------------------------------------------------------
-- Get the text corresponding to the status and speak
local function getStatusText(statusSensorID)
    local lStatus = ""
    local value = 0 -- sensor value
    local ecuStatus = 0
    local switch
    local lSpeech
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbStatusParam))

    if (sensor and sensor.valid) then
        value = string.format("%s", math.floor(sensor.value))
        wbECUTypePrev = value >> 8
        ecuStatus = value & 0xFF

        if (ecuStatus ~= wbStatusPrev) then
            print(string.format("ECU Status %d",ecuStatus))
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
                        -- print(string.format("Status  %s", tostring(lSpeech)))
                        system.playFile(string.format("Apps/%s/audio/%s", wBrand, lSpeech), AUDIO_IMMEDIATE)
                    end
                end
            end
            wbStatusText = lStatus
            wbStatusPrev = ecuStatus
        else
            lStatus = wbStatusText
        end
    else
        lStatus = "          XX "
    end

    return lStatus
end
------------------------------------------------------------------------
-- Get the ECU Type
local function getWBECUType(statusSensorID)
    local validECU
    local value = 0 -- sensor value
    local ecuType = nil
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbStatusParam))

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
    -- print("returning ECU type: ", ecuType)
    return ecuType
end
------------------------------------------------------------------------
-- Get EGT From telemtry data
local function getEGT(statusSensorID)
    local value = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbEGTParam))

    if (sensor and sensor.valid) then
        value = sensor.value
    else
        value = 0
    end
    return value
end
------------------------------------------------------------------------
-- Get RPM From telemtry data
local function getRPM(statusSensorID)
    local value = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbRPMParam))

    if (sensor and sensor.valid) then
        value = sensor.value
    else
        value = 0
    end
    return value
end
------------------------------------------------------------------------
-- Get Fuel remaining From telemtry data

local function getFuel(statusSensorID)
    local value = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbFuelParam))

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
local function getPump(statusSensorID)
    local value = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbPumpParam))

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
local function getBatt(statusSensorID)
    local value = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbBattParam))

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

local function sizeChanged(value)
    system.unregisterTelemetry(1)
    registerTelemetryForm(value)
    system.pSave("cfgSize",value)
    cfgSize=value
    loadImages()
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
local function saveMsgConfig()
    local configEncoded
    configEncoded=json.encode(config)
    local f = io.open(string.format("Apps/%s/%s", wBrand, catalog.ecu[tostring(wbECUType)].file),"w")
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
            addLabel({label = textMessage.message.menuLabelDisplaySize,width =220})
            addSelectbox(sizeOptions,cfgSize,true,sizeChanged)

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

            addRow(1)
            addLabel({label=textMessage.message.menuInfoForm2,enabled=false,font=FONT_MINI})

            if(wbECUType==nil) then 
                addRow(1)
                addLabel({label = textMessage.message.menuInfoNoECU})
                form.addLink((function() form.reinit(1) end), {label = textMessage.message.menuLabelBack,font=FONT_BOLD})
            else
                form.addLink((function() saveMsgConfig() end), {label = textMessage.message.menuLabelBackSave,font=FONT_BOLD})
                for i, n in pairs(config.message) do
                    addRow(2)
                    addLabel({label = n.text, width = 220})
                    if(config.message[i].active==nil) then config.message[i].active=false end
                    msgActive[i]=addCheckbox(config.message[i].active,(function(value) config.message[i].active=not value form.setValue(msgActive[i],not value) end))
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
    local fg
    local jsonFile
    local dev, emflag

    dev, emflag = system.getDeviceType()
    if emflag == 1 then DEBUG = true else DEBUG = false end
    
    readCatalog()

    wBrand = catalog.config.brand
    -- print("wBrand: ", wBrand)
    
    wbSensorID = getWBSensorID()
    if not wbSensorID and DEBUG then wbSensorID = 1 end
    -- print("wbSensorID: ", wbSensorID)
    
    maxRPM = system.pLoad("maxRPM", 114)
    maxEGT = system.pLoad("maxEGT", 800)
    cfgSize = system.pLoad("cfgSize",2)
    cfgScheme = system.pLoad("cfgScheme",2)
    fuelThreshold = system.pLoad("cfgFuelThreshold",20)
    fuelWarnEnabled = system.pLoad("cfgFuelWarn",0)==1
    fuelVoiceEnabled = system.pLoad("cfgFuelVoice",0)==1
    fuelVibration = system.pLoad("cfgFuelVibration",4)
    fuelRepeat = system.pLoad("cfgFuelRepeat",15)
    cfgLang = system.pLoad("cfgLang","en")
    
    loadImages()
    loadLang()

    system.registerForm(1, MENU_APPS, wAppname .. " config", initForm)
    
    jsonFile = "Apps/DFM-"..string.gsub(system.getProperty("Model")..".jsn", " ", "_")
    fg = io.readall(jsonFile)
    modelProps = json.decode(fg)

    if not modelProps.turbineName then modelProps.turbineName = "Unknown" end
    --print("modelProps:", modelProps)
    --print("modelProps.turbineName:", modelProps.turbineName)
    --print("modelProps.turbineThrustTable[1]:", modelProps.turbineThrustTable[1])
    if modelProps.turbineName then print("Turbine: " .. modelProps.turbineName) end

    registerTelemetryForm(cfgSize)

    
end

------------------------------------------------------------------------
-- Main Loop function is called in regular intervals
local function loop()
    if (wbSensorID ~= nil and wbSensorID ~= 0 and wbECUType ~= nil) then

        -- check if status parameter is present (avoid crash when rescaning sensor)
        if(system.getSensorByID(wbSensorID,tonumber(wbStatusParam))~=nil) then
            if (wbECUType ~= wbECUTypePrev) then
                wbECUType = getWBECUType(wbSensorID)
            end

            local validData=system.getSensorByID(wbSensorID,tonumber(wbStatusParam)).valid

            if(validData) then
                lStatus = getStatusText(wbSensorID)
                lFuel = getFuel(wbSensorID)
                lPump = getPump(wbSensorID)
                lBatt = getBatt(wbSensorID)
                lRPM = getRPM(wbSensorID)
                lEGT = getEGT(wbSensorID)
                fuelAlarm(lFuel)
            end
        end
    else
        if (wbSensorID == nil) then
            wbSensorID = getWBSensorID()
        end
        if (wbECUType == nil and wbSensorID ~= nil) then
            wbECUType = getWBECUType(wbSensorID)
        end
    end
end

WBDashVersion = wVersion
-- Application interface
return {init = init, loop = loop, author = "DM", version = wVersion, name = wAppname}
