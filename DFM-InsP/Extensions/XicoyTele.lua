local M = {}


local ecuMessage = {

   [18]= {
      ["text"]= "Low RPM",
      ["speech"]= "low-rpm.wav",
      ["active"]= true,
      ["de"]= "low-rpm-DE.wav"
    },
   [255]= {
      ["text"]= "ECU Offline",
      ["speech"]= "ecuoffline.wav",
      ["active"]= true,
      ["de"]= "ecuoffline-DE.wav"
    },
   [20]= {
      ["active"]= true,
      ["text"]= "RXPwFail"
    },
   [30]= {
      ["active"]= true,
      ["text"]= "PumpLimit"
    },
   [22]= {
      ["text"]= "Battery Low",
      ["fr"]= "fr-battlow.wav",
      ["es"]= "es-battlow.wav",
      ["speech"]= "ecubattlow.wav",
      ["de"]= "ecubattlow-DE.wav",
      ["active"]= true
    },
   [32]= {
      ["active"]= true,
      ["text"]= "PwrBoost"
    },
   [0]= {
      ["text"]= "High Temp",
      ["speech"]= "hightemp.wav",
      ["active"]= true,
      ["de"]= "hightemp-DE.wav"
    },
   [1]= {
      ["text"]= "Trim Low",
      ["fr"]= "fr-standby.wav",
      ["es"]= "es-standby.wav",
      ["speech"]= "STANDBY.wav",
      ["de"]= "standby-DE.wav",
      ["active"]= true
    },
   [2]= {
      ["text"]= "Set Idle!",
      ["speech"]= "setidle.wav",
      ["active"]= true,
      ["de"]= "setidle-DE.wav"
    },
   [7]= {
      ["text"]= "Running",
      ["speech"]= "turbineidle.wav",
      ["active"]= true,
      ["de"]= "turbineidle-DE.wav"
    },
   [29]= {
      ["active"]= true,
      ["text"]= "Cal.Pump"
    },
   [9]= {
      ["text"]= "Flameout",
      ["speech"]= "flameout2.wav",
      ["active"]= true,
      ["de"]= "flameout-DE.wav"
    },
   [27]= {
      ["active"]= true,
      ["text"]= "Starting"
    },
   [3]= {
      ["text"]= "Ready",
      ["speech"]= "ARMED.wav",
      ["active"]= true,
      ["de"]= "ARMED-DE.wav"
    },
   [15]= {
      ["text"]= "Start On",
      ["speech"]= "tbe.wav",
      ["active"]= true,
      ["de"]= "tbe-DE.wav"
    },
   [23]= {
      ["active"]= true,
      ["text"]= "Time Out"
    },
   [6]= {
      ["text"]= "Glow Test",
      ["speech"]= "Glow_test.wav",
      ["active"]= true,
      ["de"]= "Glow_test-DE.wav"
    },
   [17]= {
      ["text"]= "Failsafe",
      ["speech"]= "failsafe.wav",
      ["active"]= true,
      ["de"]= "failsafe-DE.wav"
    },
   [19]= {
      ["active"]= true,
      ["text"]= "Reset "
    },
   [11]= {
      ["text"]= "Cooling",
      ["speech"]= "cool_down.wav",
      ["active"]= true,
      ["de"]= "cool_down-DE.wav"
    },
   [31]= {
      ["active"]= true,
      ["text"]= "NoEngine"
    },
   [21]= {
      ["text"]= "Preheat",
      ["speech"]= "FUELHEAT.wav",
      ["active"]= true,
      ["de"]= "FUELHEAT-DE.wav"
    },
   [8]= {
      ["text"]= "Stop",
      ["speech"]= "turbineoff.wav",
      ["active"]= true,
      ["de"]= "turbineoff-DE.wav"
    },
   [5]= {
      ["text"]= "Fuelramp",
      ["speech"]= "RAMP-UP.wav",
      ["active"]= true,
      ["de"]= "RAMP-UP-DE.wav"
    },
   [4]= {
      ["text"]= "Ignition",
      ["speech"]= "FUELIGNIT.wav",
      ["active"]= true,
      ["de"]= "FULLIGNIT-DE.wav"
    },
   [25]= {
      ["text"]= "Ignition Fail",
      ["speech"]= "ignfailed.wav",
      ["active"]= true,
      ["de"]= "ignfailed-DE.wav"
    },
   [34]= {
      ["active"]= true,
      ["text"]= "Run-Max "
    },
   [10]= {
      ["active"]= true,
      ["text"]= "SpeedLow"
    },
   [36]= {
      ["active"]= true,
      ["text"]= "Error   "
    },
   [12]= {
      ["text"]= "Ignitor Bad",
      ["speech"]= "ignitorfailed.wav",
      ["active"]= true,
      ["de"]= "ignitorfailed-DE.wav"
    },
   [35]= {
      ["active"]= true,
      ["text"]= "Restart "
    },
   [13]= {
      ["text"]= "StarterFail",
      ["speech"]= "bad_start.wav",
      ["active"]= true,
      ["de"]= "bad-start-DE.wav"
    },
   [28]= {
      ["active"]= true,
      ["text"]= "SwitchOv"
    },
   [33]= {
      ["active"]= true,
      ["text"]= "Run-Idle"
    },
   [16]= {
      ["active"]= true,
      ["text"]= "UserOff"
    },
   [26]= {
      ["text"]= "Burner On",
      ["speech"]= "BURNER ON.wav",
      ["active"]= true,
      ["de"]= "BURNER ON-DE.wav"
    },
   [14]= {
      ["active"]= true,
      ["text"]= "AccelFail"
    },
   [24]= {
      ["active"]= true,
      ["text"]= "Overload"
    }
}

function M.text(ptr, val)
   local ecuCode = val 
   if ecuCode and ecuMessage[ecuCode] then
      -- could take other actions here e.g. play wav files
      local msg = {ecuMessage[ecuCode].text}
      return msg
   else
      return "No message for status " .. tostring(val)
   end
end

return M

