--[[
Copyright (c) 2021 LeonAirRC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local currForm

local abs = math.abs
local estimateCheckboxIndex, algorithmLabelIndex, numericBearingIndex, announceAltitudeIndex

local minSequenceLength
local maxSequenceLength
local bestSequenceLength
local enableSwitch
local latSensorIndex
local lonSensorIndex
local sensorIndices
local delay
local sensorMode
local readingInterval
local interval
local estimateClimb
local circleRadius
local algorithm = 2
local algorithmSwitch
local appModeSwitch
local numericBearing
local announceAltitude

local zoom = 1
local switchOn
local bestPoint
local bestClimb

local gpsSensorIDs
local gpsSensorParams
local otherSensorIDs
local otherSensorParams
local gpsSensorLabels
local otherSensorLabels

local gpsReadings
local sensorReadings
local avgPoint
local lastTime
local lastAnnouncement
local lastAltitude

local text = io.readall("Apps/ThermalAssist/lang.jsn")
assert(text ~= nil, "The file ThermalAssist/lang.jsn is missing")
text = json.decode(text)
local lang = text[system.getLocale()] or text["en"]
text = nil

local bearingFilenames = {"north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"}
local renderer -- also used as an indicator whether the transmitter has a color display
local planeShape


local function reset()
    gpsReadings = {}
    sensorReadings = {}
    avgPoint = nil
    bestPoint = nil
    bestClimb = nil
    lastTime = system.getTimeCounter()
    lastAnnouncement = lastTime
    lastAltitude = nil
end

---------------------
-- callback functions
---------------------

local function onSensorModeChanged(value)
    sensorMode = value
    reset()
    system.pSave("smode", sensorMode)
end

local function onLatSensorChanged(value)
    latSensorIndex = value - 1
    system.pSave("lat", latSensorIndex)
end

local function onLonSensorChanged(value)
    lonSensorIndex = value - 1
    system.pSave("lon", lonSensorIndex)
end

local function onOtherSensorChanged(value, index)
    sensorIndices[index] = value - 1
    system.pSave("sensi", sensorIndices)
end

local function onDelayChanged(value)
    delay = value
    reset()
    system.pSave("delay", delay)
end

local function onEnableSwitchChanged(value)
    enableSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("enable", enableSwitch)
end

local function onAppModeSwitchChanged(value)
    appModeSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("amodesw", appModeSwitch)
end

local function onMinSequenceLengthChanged(value)
    minSequenceLength = value
    reset()
    system.pSave("minseq", minSequenceLength)
end

local function onMaxSequenceLengthChanged(value)
    maxSequenceLength = value
    reset()
    system.pSave("maxseq", maxSequenceLength)
end

local function onBestSequenceLengthChanged(value)
    bestSequenceLength = value
    reset()
    system.pSave("bestseq", bestSequenceLength)
end

local function onReadingIntervalChanged(value)
    readingInterval = value
    reset()
    system.pSave("rint", readingInterval)
end

local function onIntervalChanged(value)
    interval = value
    reset()
    system.pSave("aint", interval)
end

local function onEstimateClimbChanged(value)
    estimateClimb = not value
    form.setValue(estimateCheckboxIndex, estimateClimb)
    system.pSave("estclmb", estimateClimb and 1 or 0)
end

local function onCircleRadiusChanged(value)
    circleRadius = value
    system.pSave("rad", circleRadius)
end

local function onAlgorithmSwitchChanged(value)
    local info = value and system.getSwitchInfo(value) or nil
    algorithmSwitch = (info and info.assigned) and value or nil
    system.pSave("algsw", algorithmSwitch)
end

local function onNumericBearingChanged(value)
    numericBearing = not value
    form.setValue(numericBearingIndex, numericBearing)
    system.pSave("numbear", numericBearing and 1 or 0)
end

local function onAnnounceAltitudeChanged(value)
    announceAltitude = not value
    form.setValue(announceAltitudeIndex, announceAltitude)
    system.pSave("annalt", announceAltitude and 1 or 0)
end

-------------------------------------------------------------------------
-- shortens the sequence of gps points and the associated sensor readings
-- returns true if and only if a turn of at least 360° was detected
-------------------------------------------------------------------------
local function filterReadings()
    while #sensorReadings > maxSequenceLength do
        table.remove(gpsReadings)
        table.remove(sensorReadings)
    end
    if system.getInputsVal(appModeSwitch) == 1 then
        return false
    end

    local i = 2
    local sum = 0
    while i < #gpsReadings and abs(sum) < 360 do
        local angle = gps.getBearing(gpsReadings[i], gpsReadings[i - 1]) - gps.getBearing(gpsReadings[i + 1], gpsReadings[i])
        if angle < -180 then angle = angle + 360
        elseif angle > 180 then angle = angle - 360 end
        sum = sum + angle
        i = i + 1
    end
    for _ = 1, #gpsReadings - math.max(i, minSequenceLength) do
        table.remove(gpsReadings)
        table.remove(sensorReadings)
    end
    collectgarbage()
    print("sum:", #gpsReadings, sum, sum//360, sum%360)
    return sum >= 360
end

-------------------------------------------------------------------------------------------------------
-- Announcement of the bearing and distance to the optimal point.
-- The expected climb rate at that point is also annouced if the best-subsequence algorith is selected.
-------------------------------------------------------------------------------------------------------
local function voiceOutput()
    if avgPoint and bestPoint then
        local relPoint = system.getInputsVal(appModeSwitch) == 1 and gpsReadings[1] or avgPoint
        local bearing = gps.getBearing(relPoint, bestPoint)
        local distance = gps.getDistance(relPoint, bestPoint)
        if numericBearing then
            system.playNumber(bearing, 0, string.char(176))
        else
            system.playFile(string.format("/Apps/ThermalAssist/%s-%s.wav", bearingFilenames[((bearing + 22.4) % 360) // 45 + 1], lang.bearingLang), AUDIO_QUEUE)
        end
        system.playNumber(distance, 0, "m")
        if bestClimb then
            system.playNumber(bestClimb, 1, "m/s")
        end
        if announceAltitude and sensorIndices[2] ~= 0 then
            local altitude = system.getSensorValueByID(otherSensorIDs[sensorIndices[2]], otherSensorParams[sensorIndices[2]])
            if altitude and altitude.valid then
                system.playNumber(altitude.value, 0, "m", lang.altLabel)
            end
        end
        collectgarbage()
    end
end

---------------------------------------------------------------------------------
-- Estimates the climb rate at the given point based on the existing data points.
-- Uses the inverse square of distances to the point as a weight.
---------------------------------------------------------------------------------
local function estimateClimbRate(point)
    local sum = 0
    local weightSum = 0
    for i = 1, #gpsReadings - delay do
        local dist = gps.getDistance(point, gpsReadings[i + delay])
        if dist < 0.1 then
            return sensorReadings[i]
        end
        local weight = 1 / (dist * dist)
        weightSum = weightSum + weight
        sum = sum + weight * sensorReadings[i]
    end
    return sum / weightSum
end

--------------------------------------------------------
-- sets 'bestPoint' according to the selected algorithm
-- and calls 'estimateClimbRate' if enabled
--------------------------------------------------------
local function calcBestPoint(fullTurn)
    collectgarbage()
    local alg1 = system.getInputsVal(appModeSwitch) == 1
    if (algorithm == 1 or alg1) and #sensorReadings >= math.max(minSequenceLength, bestSequenceLength) + delay then

        local sums = {}
        sums[1] = 0
        for i = 1, bestSequenceLength do
            sums[1] = sums[1] + sensorReadings[i]
        end
        for i = 2, #sensorReadings - bestSequenceLength + 1 do
            table.insert(sums, i, sums[i - 1] + sensorReadings[i + bestSequenceLength - 1] - sensorReadings[i - 1])
        end
        if fullTurn then
            for i = #sensorReadings - bestSequenceLength + 2, #sensorReadings do
                table.insert(sums, i, sums[i - 1] + sensorReadings[i + bestSequenceLength - 1 - #sensorReadings] - sensorReadings[i - 1])
            end
        end
        local best = 1
        for i = 2, #sums do
            if sums[i] > sums[best] then best = i end
        end
        if fullTurn and best + delay + (bestSequenceLength - 1 // 2) > #sensorReadings then
            bestPoint = gpsReadings[best + delay + (bestSequenceLength - 1) // 2 - #sensorReadings]
        else
            bestPoint = gpsReadings[best + delay + (bestSequenceLength - 1) // 2]
        end
        bestClimb = sums[best] / bestSequenceLength

    elseif algorithm == 2 and (not alg1) and #sensorReadings >= minSequenceLength + delay then

        local varioSum = 0
        for i = 1, #sensorReadings - delay do
            varioSum = varioSum + abs(sensorReadings[i])
        end
        if varioSum == 0.0 then
            bestPoint = avgPoint
        else
            local latSum, lonSum = 0,0
            local centerLat, centerLon = gps.getValue(avgPoint)
            for i = 1, #gpsReadings - delay do
                local lat,lon = gps.getValue(gpsReadings[i + delay])
                latSum = latSum + sensorReadings[i] * (lat - centerLat)
                lonSum = lonSum + sensorReadings[i] * (lon - centerLon)
            end
            bestPoint = gps.newPoint(centerLat + latSum / varioSum, centerLon + lonSum / varioSum)
        end
        bestClimb = estimateClimb and estimateClimbRate(bestPoint) or nil

    elseif algorithm == 3 and (not alg1) and #sensorReadings >= minSequenceLength then

        local bias = 0
        local varioSum = 0
        for i = 1, #sensorReadings - delay do
            if sensorReadings[i] < bias then
                bias = sensorReadings[i]
            end
            varioSum = varioSum + sensorReadings[i]
        end
        if varioSum == 0.0 then
            bestPoint = avgPoint
        else
            bias = -bias
            varioSum = varioSum + (#sensorReadings - delay) * bias
            local latSum, lonSum = 0,0
            for i = 1, #gpsReadings - delay do
                local lat,lon = gps.getValue(gpsReadings[i + delay])
                local weight = sensorReadings[i] + bias
                latSum = latSum + lat * weight
                lonSum = lonSum + lon * weight
            end
            bestPoint = gps.newPoint(latSum / varioSum, lonSum / varioSum)
        end
        bestClimb = estimateClimb and estimateClimbRate(bestPoint) or nil
    end
    collectgarbage()
end

-----------------------------------------------------------------------------------------------
-- set the zoom value to the biggest value so that all points in 'gpsReadings' are in the frame
-----------------------------------------------------------------------------------------------
local function calcAutozoom(width, height)
    local centerLat, centerLon = gps.getValue(avgPoint)
    local maxLatPoint = gpsReadings[1]
    local maxLonPoint = gpsReadings[1]
    local maxLatVal, maxLonVal = gps.getValue(gpsReadings[1])
    maxLatVal = abs(maxLatVal - centerLat)
    maxLonVal = abs(maxLonVal - centerLon)
    for i = 2, #gpsReadings do
        local lat,lon = gps.getValue(gpsReadings[i])
        if abs(lat - centerLat) > maxLatVal then
            maxLatPoint = gpsReadings[i]
            maxLatVal = abs(lat - centerLat)
        end
        if abs(lon - centerLon) > maxLonVal then
            maxLonPoint = gpsReadings[i]
            maxLonVal = abs(lon - centerLon)
        end
    end
    local autozoom = math.min(zoom, 20) + 2
    repeat
        autozoom = autozoom - 1
        local _,y1 = gps.getLcdXY(maxLatPoint, avgPoint, autozoom)
        local x2,_ = gps.getLcdXY(maxLonPoint, avgPoint, autozoom)
    until autozoom < 2 or autozoom < zoom or (abs(y1) + 4 < height / 2 and abs(x2) + 4 < width / 2) -- 4 pixel margin
    zoom = autozoom
    collectgarbage()
end

------------------------------------------------------------------------------------------------------------
-- Prints the telemetry.
-- Each gps point is displayed as a circle with the radius proportional to the climb rate or as a small dot.
-- Depending on the selected algorithm, the best point is displayed as a square.
------------------------------------------------------------------------------------------------------------
local function printTelemetry(width, height)
    local hWidth = width // 2
    local hHeight = height // 2
    if gpsReadings and avgPoint and #gpsReadings > 0 then
        calcAutozoom(width, height)

        local x,y = gps.getLcdXY(gpsReadings[1], avgPoint, zoom)
        local rotation = math.rad(#gpsReadings >= 2 and gps.getBearing(gpsReadings[2], gpsReadings[1]) or 0)
        local sin, cos = math.sin(rotation), math.cos(rotation)
        if not renderer then
            for i = 1, #planeShape - 1 do
                lcd.drawLine(hWidth + x + cos * planeShape[i][1] - sin * planeShape[i][2], hHeight + y + cos * planeShape[i][2] + sin * planeShape[i][1],
                            hWidth + x + cos * planeShape[i + 1][1] - sin * planeShape[i + 1][2], hHeight + y + cos * planeShape[i + 1][2] + sin * planeShape[i + 1][1])
            end
        else
            renderer:reset()
            for _,point in ipairs(planeShape) do
                renderer:addPoint(hWidth + x + point[1] * cos - point[2] * sin, hHeight + y + point[1] * sin + point[2] * cos)
            end
            renderer:renderPolygon()
        end

        for i = 1, #gpsReadings do
            if i > delay and (sensorReadings[i - delay] > 0 or gpsReadings[i] == bestPoint) then
                x,y = gps.getLcdXY(gpsReadings[i], avgPoint, zoom)
                if gpsReadings[i] == bestPoint then
                    local size = math.max(math.ceil(circleRadius * bestClimb), 2)
                    lcd.drawRectangle(hWidth + x - size, hHeight + y - size, size + size, size + size)
                else
                    local radius = math.floor(circleRadius * sensorReadings[i - delay]) + 1
                    lcd.drawCircle(hWidth + x, hHeight + y, radius)
                end
            elseif i ~= 1 then
                x,y = gps.getLcdXY(gpsReadings[i], avgPoint, zoom)
                lcd.drawFilledRectangle(x + hWidth - 1, y + hHeight - 1, 2, 2)
            end
        end
        if bestPoint and algorithm ~= 1 and system.getInputsVal(appModeSwitch) ~= 1 then
            x,y = gps.getLcdXY(bestPoint, avgPoint, zoom)
            local size = (estimateClimb and bestClimb) and math.max(math.ceil(bestClimb * circleRadius), 3) or 3
            lcd.drawFilledRectangle(hWidth + x - size, hHeight + y - size, size + size, size + size, 100)
        end
        collectgarbage()
    end

    lcd.drawLine(hWidth, hHeight - 3, hWidth, hHeight + 3)
    lcd.drawLine(hWidth - 3, hHeight, hWidth + 3, hHeight)
    if enableSwitch and system.getInputsVal(enableSwitch) ~= 1 and system.getTime() % 2 == 0 then
        lcd.drawText((width - lcd.getTextWidth(FONT_BOLD, "disabled")) / 2, 3, "disabled", FONT_BOLD)
    end
end

--------------------------------------------------------------------------------------
-- key event callback function
--------------------------------------------------------------------------------------
local function onKeyPressed(keyCode)
    if currForm ~= 1 and (keyCode == KEY_ESC or keyCode == KEY_5) then
        form.preventDefault()
        form.reinit(1)
    end
end

--------------------------------------------------------------------------------------

local function loop()
    if enableSwitch and system.getInputsVal(enableSwitch) ~= 1 then
        switchOn = false
    elseif not switchOn then
        switchOn = true
        reset()
    end
    local alg = algorithmSwitch and math.floor(system.getInputsVal(algorithmSwitch)) + 2 or 2
    if alg ~= algorithm then
        algorithm = alg
        if currForm == 3 then
            form.setProperties(algorithmLabelIndex, { label = lang.algorithSelectionText[algorithm] })
        end
    end
    if switchOn and latSensorIndex ~= 0 and lonSensorIndex ~= 0 and sensorIndices[sensorMode] ~= 0 then
        local time = system.getTimeCounter()
        if time >= lastTime + readingInterval then
            local gpsPoint = gps.getPosition(gpsSensorIDs[latSensorIndex], gpsSensorParams[latSensorIndex], gpsSensorParams[lonSensorIndex])
            local sensorReading = system.getSensorValueByID(otherSensorIDs[sensorIndices[sensorMode]],
                                                            otherSensorParams[sensorIndices[sensorMode]])
            if gpsPoint and sensorReading and sensorReading.valid then
                if sensorMode == 1 then
                    table.insert(gpsReadings, 1, gpsPoint)
                    table.insert(sensorReadings, 1, sensorReading.value)
                elseif lastAltitude then
                    table.insert(gpsReadings, 1, gpsPoint)
                    table.insert(sensorReadings, 1, (sensorReading.value - lastAltitude) * 1000 / readingInterval)
                    lastAltitude = sensorReading.value
                else
                    lastAltitude = sensorReading.value
                end
                if #gpsReadings > 0 then
                    local fullTurn = filterReadings()
                    local latSum, lonSum = gps.getValue(gpsReadings[1])
                    for i = 2, #gpsReadings do
                        local lat, lon = gps.getValue(gpsReadings[i])
                        latSum = latSum + lat
                        lonSum = lonSum + lon
                    end
                    avgPoint = gps.newPoint(latSum / #gpsReadings, lonSum / #gpsReadings)
                    calcBestPoint(fullTurn)
                end
            elseif #gpsReadings > 0 then
                reset()
            else
                lastTime = time
                lastAnnouncement = time
                lastAltitude = nil
            end
            lastTime = lastTime + readingInterval
        end
        if gpsReadings and time >= lastAnnouncement + 1000 * interval then
            voiceOutput()
            lastAnnouncement = lastAnnouncement + 1000 * interval
        end
    end
    collectgarbage()
end

local function initForm(formID)
    collectgarbage()
    if not formID or formID == 1 then

        form.setTitle(lang.appName)
        form.addRow(2)
        form.addLabel({ label = lang.enableSwitchText })
        form.addInputbox(enableSwitch, false, onEnableSwitchChanged)
        form.addRow(1)
        form.addLink(function () form.reinit(2) end, { label = lang.sensorsFormTitle .. " >>" })
        form.addRow(1)
        form.addLink(function () form.reinit(3) end, { label = lang.algorithmsFormTitle .. " >>" })
        form.addRow(1)
        form.addLink(function () form.reinit(4) end, { label = lang.voiceFormTitle .. " >>" })
        form.addRow(1)
        form.addLink(function () form.reinit(5) end, { label = lang.telemetryFormTitle .. " >>" })
        form.addRow(2)
        form.addLabel({ label = lang.searchModeText, width = 250 })
        form.addInputbox(appModeSwitch, false, onAppModeSwitchChanged)
        form.setFocusedRow(currForm or 1)

    elseif formID == 2 then

        form.setTitle(lang.sensorsFormTitle)
        form.addRow(2)
        form.addLabel({ label = lang.latInputText })
        form.addSelectbox(gpsSensorLabels, latSensorIndex + 1, true, onLatSensorChanged)
        form.addRow(2)
        form.addLabel({ label = lang.lonInputText })
        form.addSelectbox(gpsSensorLabels, lonSensorIndex + 1, true, onLonSensorChanged)
        form.addRow(2)
        form.addLabel({ label = lang.sensorModeText, width = 100 })
        form.addSelectbox(lang.modeSelectionText, sensorMode, false, onSensorModeChanged, { width = 220 })
        form.addRow(2)
        form.addLabel({ label = lang.varioInputText, width = 110 })
        form.addSelectbox(otherSensorLabels, sensorIndices[1] + 1, true, function(value) onOtherSensorChanged(value, 1) end, { width = 210 })
        form.addRow(2)
        form.addLabel({ label = lang.altitudeInputText, width = 110 })
        form.addSelectbox(otherSensorLabels, sensorIndices[2] + 1, true, function(value) onOtherSensorChanged(value, 2) end, { width = 210 })
        form.addRow(2)
        form.addLabel({ label = lang.readingsText })
        form.addIntbox(readingInterval, 500, 5000, 1000, 0, 100, onReadingIntervalChanged)
        form.addRow(2)
        form.addLabel({ label = lang.delayText })
        form.addIntbox(delay, 0, 5, 0, 0, 1, onDelayChanged)
        form.setFocusedRow(1)

    elseif formID == 3 then

        form.setTitle(lang.algorithmsFormTitle)
        form.addRow(2)
        form.addLabel({ label = lang.algorithmText, width = 100 })
        algorithmLabelIndex = form.addLabel({ label = lang.algorithSelectionText[algorithm], alignRight = true, width = 220 })
        form.addRow(2)
        form.addLabel({ label = lang.enableSwitchText })
        form.addInputbox(algorithmSwitch, true, onAlgorithmSwitchChanged)
        form.addRow(2)
        form.addLabel({ label = lang.minSequenceLengthText, width = 250 })
        form.addIntbox(minSequenceLength, 5, 60, 5, 0, 1, onMinSequenceLengthChanged)
        form.addRow(2)
        form.addLabel({ label = lang.maxSequenceLengthText, width = 250 })
        form.addIntbox(maxSequenceLength, 5, 60, 20, 0, 1, onMaxSequenceLengthChanged)
        form.addRow(2)
        form.addLabel({ label = lang.bestSequenceLengthText, width = 250 })
        form.addIntbox(bestSequenceLength, 1, 20, 3, 0, 1, onBestSequenceLengthChanged)
        form.addRow(2)
        form.addLabel({ label = lang.estimateClimbText, width = 280 })
        estimateCheckboxIndex = form.addCheckbox(estimateClimb, onEstimateClimbChanged)
        form.setFocusedRow(1)

    elseif formID == 4 then

        form.setTitle(lang.voiceFormTitle)
        form.addRow(2)
        form.addLabel({ label = lang.intervalText, width = 250 })
        form.addIntbox(interval, 3, 30, 10, 0, 1, onIntervalChanged)
        form.addRow(2)
        form.addLabel({ label = lang.numericBearingText, width = 280 })
        numericBearingIndex = form.addCheckbox(numericBearing, onNumericBearingChanged)
        form.addRow(2)
        form.addLabel({ label = lang.announceAltitudeText, width = 280 })
        announceAltitudeIndex = form.addCheckbox(announceAltitude, onAnnounceAltitudeChanged)
        form.setFocusedRow(1)

    else

        form.setTitle(lang.telemetryFormTitle)
        form.addRow(2)
        form.addLabel({ label = lang.circleRadiusText, width = 250 })
        form.addIntbox(circleRadius, 1, 50, 15, 0, 1, onCircleRadiusChanged)
        form.setFocusedRow(1)

    end
    currForm = formID
    collectgarbage()
end

local function init()
    collectgarbage()
    gpsSensorLabels = {"..."}
    otherSensorLabels = {"..."}
    gpsSensorIDs = {}
    gpsSensorParams = {}
    otherSensorIDs = {}
    otherSensorParams = {}
    local sensors = system.getSensors()
    for _,sensor in ipairs(sensors) do
        if sensor.param ~= 0 then --and sensor.type == 9 then
            gpsSensorLabels[#gpsSensorLabels+1] = string.format("%s: %s", sensor.sensorName, sensor.label)
            gpsSensorIDs[#gpsSensorIDs+1] = sensor.id
            gpsSensorParams[#gpsSensorParams+1] = sensor.param
	end
	
        if sensor.param ~= 0 and sensor.type ~= 5 then
            otherSensorLabels[#otherSensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            otherSensorIDs[#otherSensorIDs+1] = sensor.id
            otherSensorParams[#otherSensorParams+1] = sensor.param
        end
        collectgarbage()
    end
    minSequenceLength = system.pLoad("minseq", 5)
    maxSequenceLength = system.pLoad("maxseq", 40)
    bestSequenceLength = system.pLoad("bestseq", 3)
    enableSwitch = system.pLoad("enable")
    latSensorIndex = system.pLoad("lat", 0)
    lonSensorIndex = system.pLoad("lon", 0)
    sensorIndices = system.pLoad("sensi") or {0, 0}
    delay = system.pLoad("delay", 0)
    if latSensorIndex > #gpsSensorIDs then latSensorIndex = 0 end
    if lonSensorIndex > #gpsSensorIDs then lonSensorIndex = 0 end
    if sensorIndices[1] > #otherSensorIDs then sensorIndices[1] = 0 end
    if sensorIndices[2] > #otherSensorIDs then sensorIndices[2] = 0 end
    sensorMode = system.pLoad("smode", 1)
    readingInterval = system.pLoad("rint", 1000)
    interval = system.pLoad("aint", 10)
    estimateClimb = (system.pLoad("estclmb", 1) == 1)
    circleRadius = system.pLoad("rad", 10)
    algorithmSwitch = system.pLoad("algsw")
    appModeSwitch = system.pLoad("amodesw")
    numericBearing = (system.pLoad("numbear", 1) == 1)
    announceAltitude = (system.pLoad("annalt", 0) == 1)
    system.registerForm(1, MENU_APPS, lang.appName, initForm, onKeyPressed)
    system.registerTelemetry(2, lang.appName, 4, printTelemetry)

    pcall(function() renderer = lcd.renderer() end)
    if renderer then
        planeShape = {{0, -8}, {-0.5, -7.7}, {-1.1, -5.8}, {-1.1, -1.6}, {-7.1, 2.2}, {-7.1, 3.7}, {-1.1, 1.8}, {-1.1, 6}, {-2.6, 7.1}, {-2.6, 8.2}, {0, 7.4},
                    {2.6, 8.2}, {2.6, 7.1}, {1.1, 6}, {1.1, 1.8}, {7.1, 3.7}, {7.1, 2.2}, {1.1, -1.6}, {1.1, -5.8}, {0.5, -7.7}}
    else
        planeShape = {{0, -7}, {-6, 7}, {0, 4}, {6, 7}, {0, -7}}
    end

    reset()
    collectgarbage()
end

local function destroy()
    system.unregisterTelemetry(2)
    collectgarbage()
end

collectgarbage()
return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.4.2", name = lang.appName }
