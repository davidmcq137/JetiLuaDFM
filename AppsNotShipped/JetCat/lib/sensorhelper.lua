
-- ############################################################################# 
-- # Jeti helper library
-- #
-- # Copyright (c) 2017, Original idea by Thomas Ekdahl (thomas@ekdahl.no)
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V0.5 - Initial release
-- ############################################################################# 

local sensorhelper = {}

--------------------------------------------------------------------
-- Generates a sensor menu, returns sensor table and index choice for GUI generation
function sensorhelper.getSensorParamTable(sensorID, sensorParam)
    local tmpSensorTable = {"..."}
    local tmpMenuTable   = {"..."}
    local tmpIndex       = 1
    local descr          = ""

    for index,sensor in ipairs(system.getSensors()) do 
        if(sensor.param == 0) then
            descr = sensor.label
        else
            tmpSensorTable[#tmpSensorTable+1] = sensor -- global sensor array
            tmpMenuTable[#tmpMenuTable+1]=string.format("%s - %s [%s]",descr,sensor.label,sensor.param) -- Menu table, added param for config purposes

            --print(string.format("SensorID: %s=%s, param: %s=%s", sensor.id, statusSensor1ID, sensor.param, tonumber(config.status.sensor.param)))
            if(sensor.id==sensorID and sensor.param==tonumber(sensorParam)) then
                tmpIndex=#tmpMenuTable
            end      
        end
    end
    collectgarbage()

    return tmpSensorTable, tmpMenuTable, tmpIndex
end

--------------------------------------------------------------------
-- Generates a sensor menu, returns sensor table and index choice for GUI generation
function sensorhelper.getSensorTable(sensorID)
    local tmpSensorTable = {"..."}
    local tmpMenuTable   = {"..."}
    local tmpIndex = 1

    for index,sensor in ipairs(system.getSensors()) do 
        if(sensor.param == 0) then

            tmpSensorTable[#tmpSensorTable+1] = sensor -- global sensor array
            tmpMenuTable[#tmpMenuTable+1]=string.format("%s",sensor.label) -- added param for config purposes

            if(sensor.id==sensorID) then
                tmpIndex=#tmpMenuTable
            end      
        end
    end
    collectgarbage()

    return tmpSensorTable, tmpMenuTable, tmpIndex
end


return sensorhelper