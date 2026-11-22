
-- ############################################################################# 
-- # Jeti helper library
-- # Copyright (c) 2019, Markus Zipperer (Markus.Zipperer@onlinehome.de)
-- #
-- # Copyright (c) 2017, Original idea by Thomas Ekdahl (thomas@ekdahl.no)
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V0.5 - Initial release
-- ############################################################################# 

local fuelhelper = {}

----------------------------------------------------------------------
-- Calculates: config.fuellevel.tanksize and config.fuellevel.interval and fuelpercent
function fuelhelper.initFuelSetup(tmpCfg)

    -- Calculate TankSize and Level
    if(config.converter.fuel.countingdown and SensorT[tmpCfg.sensorname].sensor.value > config.fuel.tanksize) then
        -- As long as we get a higher fuel reading, we keep resetting the tanksize and intervals since tanksize is set in ECU when countingdown

        config.fuel.tanksize = SensorT[tmpCfg.sensorname].sensor.value -- new or max?
        TankSize             = config.fuel.tanksize 
        fuelAlarm.tanksizeset = true

    elseif(not fuelAlarm.tanksizeset) then
        -- counting up, have to subtract, only done until low value has passed, then forgotten. TankSize read from GUI
        config.fuel.tanksize = TankSize -- TankSize read from GUI not from ECU when counting up usage

        fuelAlarm.tanksizeset = true
    end 
end

----------------------------------------------------------------------
-- Calculate the fuel level in percent
function fuelhelper.calculateFuelPercent(tmpCfg)
    -- Calculate fuel percentage remaining
    if(config.fuel.tanksize > 0) then
        if(config.converter.fuel.countingdown) then
            return fuelhelper.calcPercent(SensorT[tmpCfg.sensorname].sensor.value, config.fuel.tanksize, 0)
        else
            return fuelhelper.calcPercent(config.fuel.tanksize - SensorT[tmpCfg.sensorname].sensor.value, config.fuel.tanksize, 0)
        end
    else
        return 0
    end
end

----------------------------------------------------------------------
-- Find the fuel threshold passed
function fuelhelper.FuelThresholdPassed(tmpCfg)
    local thresholdI, thresholdV = 0,100
    for i, tmp in pairs(tmpCfg.alarms) do
        if(tonumber(SensorT[tmpCfg.sensorname].percent) <= tonumber(tmp.value)) then
            thresholdI = i
            thresholdV = tonumber(tmp.value)
            break
        end
    end
    return thresholdI, thresholdV
end

----------------------------------------------------------------------
-- Calculate percent
function fuelhelper.calcPercent(current, high, low)

    local percent = ((current - low) / (high - low)) * 100
    if(percent < 0) then 
        percent = 0
    elseif(percent > 100) then 
        percent = 100
    end
    return percent
end

return fuelhelper