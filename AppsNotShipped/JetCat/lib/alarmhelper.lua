
-- ############################################################################# 
-- # Jeti helper library - supporting internal generic alarm format
-- #
-- # Copyright (c) 2017, Original idea by Thomas Ekdahl (thomas@ekdahl.no)
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V0.5 - Initial release
-- ############################################################################# 

local alarmhelper = {}


----------------------------------------------------------------------
-- 
function alarmhelper.All(tmpConfig,StatusText)
  alarmhelper.Message(tmpConfig.message, StatusText)
  alarmhelper.Haptic(tmpConfig.haptic)
  alarmhelper.Audio(tmpConfig.audio)

end

----------------------------------------------------------------------
-- 
function alarmhelper.Message(tmpConfig,StatusText)

    if(tmpConfig.enable and enableAlarmMessage) then
        system.messageBox(string.format("ECU: %s", StatusText),tmpConfig.seconds)
    end    
end

----------------------------------------------------------------------
-- 
function alarmhelper.Haptic(tmpConfig)

    if(tmpConfig.enable and enableAlarmHaptic) then
        -- If vibration/haptic associated with status, we vibrate
        if(tmpConfig.stick == 'left') then
            system.vibration(false, tmpConfig.vibrationProfile);
        end
        if(tmpConfig.stick == 'right') then
            system.vibration(true, tmpConfig.vibrationProfile);
        end
    end
end


----------------------------------------------------------------------
-- 
function alarmhelper.Audio(tmpConfig)

    if(tmpConfig.enable and enableAlarmAudio) then
        -- If audio file associated with status, we play it
        if(tmpConfig.file) then
            system.playFile(string.format("/Apps/JetCat/audio/%s", tmpConfig.file), AUDIO_QUEUE);

            if(io.open(string.format("/Apps/JetCat/audio/%s", tmpConfig.file), "r")) then

            else
                print(string.format("Missing Audio: %s", tmpConfig.file));
            end
        end
    end
end

return alarmhelper