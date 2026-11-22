--[[

   DFM-RMon.lua - Monitors RX signals

   ---------------------------------------------------------
   Released under MIT-license by DFM 2021
   ---------------------------------------------------------
   
   Version 0.1 - Jul 26, 2021

--]]

local rmonVersion= 0.1

local qWarn
local lastWarn = 0

local function qWarnChanged(val)
   qWarn = val
   system.pSave("qWarn", qWarn)
end

local function initForm()
   form.addRow(2)
   form.addLabel({label="Q warning limit (%)", width=220})
   form.addIntbox(qWarn, 0, 100, 100, 0, 1, qWarnChanged)

   form.addRow(1)
   form.addLabel({label="DFM-RMon.lua Version "..rmonVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local txTel = {}

local function loop()

   local warn = false
   
   txTel = system.getTxTelemetry()

   if not txTel or not txTel.RSSI then return end
   if not txTel.rx1Voltage or txTel.rx1Voltage == 0 then return end
   if not txTel.rx1Percent or txTel.rx1Percent == 0 then return end
   
   if txTel.rx1Percent  < qWarn then warn = true end
   if txTel.rx2Percent > 0 and txTel.rx2Percent < qWarn then warn = true end
   if txTel.rxBPercent > 0 and txTel.rxBPercent < qWarn then warn = true end   
   if warn and  system.getTimeCounter() - lastWarn > 3000 then
      system.playFile('/Apps/DFM-RMon/Warning_Low_Q.wav', AUDIO_IMMEDIATE)
      lastWarn = system.getTimeCounter()
   end

end

local function teleWindow()
   
   if not txTel or not txTel.RSSI then return end
	 
   lcd.drawText(15,8,string.format("Rx1: Q=%3d%%, A1/2=%2d/%2d", 
				   txTel.rx1Percent, txTel.RSSI[1],txTel.RSSI[2]),
		FONT_MINI)
   
   lcd.drawText(15,28,string.format("Rx2: Q=%3d%%, A1/2=%2d/%2d", 
				    txTel.rx2Percent, txTel.RSSI[3], txTel.RSSI[4]),
		FONT_MINI)
   
   lcd.drawText(15,48,string.format("RxB: Q=%3d%%, A1/2=%2d/%2d", 
				    txTel.rxBPercent, txTel.RSSI[5], txTel.RSSI[6]),
		FONT_MINI)
   
end

local function init()

   system.registerForm(1, MENU_APPS, "Receiver Monitor", initForm)
   system.registerTelemetry(2, "Receiver Signal", 0, teleWindow)
   qWarn = system.pLoad("qWarn", 100)
   
end

return {init=init, loop=loop, author="DFM", version=tostring(rmonVersion),
	name="Receiver Monitor"}
