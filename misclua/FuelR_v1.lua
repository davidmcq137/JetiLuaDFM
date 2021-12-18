-- #############################################################################                      
-- # V1 - Initial Release
-- #############################################################################
--
-- Locals for the application

local appName = "Xicoy Fuel Remaining"
local appVer = "v1"
local Alarm={}
local UnitOptions={}
local nAlarms, nLines, nAlarmsOld
local UnitType, Units, FuelRemain, sensorvalue, sensorvalid
local TankCapacity, switch, switchVal
local newTime, time1, AlarmVoice, AlarmVoiceVal, Arow, componentIndex
local sensorID, sensorParam
 
-- #############################################################################

-------------------------
local device, emFlag

--local function playNumber(val, dec, unit, lab)
--   system.playNumber(val, dec, unit, lab)
--   if emFlag == 1 then
--      print("Number:", val, dec, unit, lab)
--   end
--end

--local function playFile(fn, type)
--   system.playFile(fn, type)
--   if emFlag == 1 then
--      print("File:", fn, type)
--   end
--end
------------------------

-- Input Form and Save Persistent Data  

local function AlarmChanged(value)	 
local Alm
	  Arow=form.getFocusedRow ()	  
	  Alarm[Arow]=value	  
	  Alarm[Arow+2]=1
	  Alm= (string.format("%s%s", "Alarm",Arow))	
	  system.pSave(Alm,value)	
end


local function TankCapacityChanged(value)
  TankCapacity=value
  system.pSave("TankCapacity",value) 
end


local function switchChanged(value)
  switch=value
  system.pSave("switch",value) 
end
 

local function nAlarmsChanged(value)
  nAlarms=value
  system.pSave("nAlarms",value) 
  
  if (nAlarms > nAlarmsOld) then
	for i=((nAlarmsOld*nLines)+1), (nAlarms*nLines), nLines do 
		Alarm[i]=0
		Alarm[i+1]=""
		Alarm[i+2]=1
	end
	
	elseif(nAlarms < nAlarmsOld) then
	
	for i=((nAlarms*nLines)+1), (nAlarmsOld*nLines), nLines do 
		Alarm[i]=0
		Alarm[i+1]=""
		Alarm[i+2]=1
	end

	else
  end

nAlarmsOld=nAlarms
end

 
local function AlarmVoiceChanged(value)
  AlarmVoice= not value
  
	if (AlarmVoice==true) then
		AlarmVoiceVal=1
	else
		AlarmVoiceVal=0
	end
  	
  form.setValue(componentIndex, AlarmVoice)
  system.pSave("AlarmVoiceVal",AlarmVoiceVal) 
end 
 

 local function UnitChanged(value)
 local Alm4

  if (UnitType~=value)then
  
	UnitType=value
   
		if (UnitType==1) then
			TankCapacity = math.floor((TankCapacity * 29.57352956)+0.5)
	
			for i=1,(nAlarms*nLines),nLines do 
			  Alm4= (string.format("%s%s", "Alarm",i))		 
			  Alarm[i]=math.floor((Alarm[i] * 29.57352956)+0.5) 		  
			  system.pSave(Alm4,Alarm[i])  			  
			end		
			
			Units="ml"
			
		elseif (UnitType==2) then
				TankCapacity = math.floor((TankCapacity * 0.03381402)+0.5)
			
			for i=1,(nAlarms*nLines),nLines do 
			  Alm4= (string.format("%s%s", "Alarm",i))		 
			  Alarm[i]=math.floor((Alarm[i] * 0.03381402)+0.5) 
			  system.pSave(Alm4,Alarm[i])  
			end
			
			Units="Floz"
		
		end
		
	system.pSave("TankCapacity",TankCapacity) 
	system.pSave("UnitType",value)
  
  end
	
  form.reinit(2)
  
end
 

-- Form initialization
local function initForm(subform)

	if(subform == 1) then		
-- If we are on first app build the form for display

		form.setButton(1,":tools",ENABLED)
		form.setButton(3,"Alarm",HIGHLIGHTED)
				
		formID = 1

	 for i=1,(nAlarms*nLines),nLines do
		form.addRow(3)
		form.addLabel({label="Alarm When Fuel <", width=160})
		form.addIntbox(Alarm[i],0,10000,0,0,1,AlarmChanged)
		form.addLabel({label=Units, alignRight=true})
		
		form.addRow(2)
		form.addLabel({label="Select file"})
		form.addAudioFilebox(Alarm[i+1] or "", AlarmChanged)
		
		form.addSpacer(10,10)
	  end

	elseif(subform == 2) then

-- If we are on second app build the form for display

		formID = 2
	
		form.setButton(1,":tools",HIGHLIGHTED)
		form.setButton(3,"Alarm",ENABLED)

		form.addRow(2)
		form.addLabel({label="Units"})
		form.addSelectbox(UnitOptions,UnitType or 1,false,UnitChanged)

		form.addRow(2)
		form.addLabel({label="Fuel Capacity"})
		form.addIntbox(TankCapacity,0,10000,0,0,1,TankCapacityChanged)

	  	form.addSpacer(10,10)
	
		form.addRow(2)
		form.addLabel({label="Voice Trigger"})
		form.addInputbox(switch,true,switchChanged)
	
		form.addSpacer(10,10)
			
		form.addRow(2)
		form.addLabel({label="Announce current value with Alarms", width=260})
		componentIndex=form.addCheckbox(AlarmVoice, AlarmVoiceChanged)

		form.addSpacer(10,10)
		
		form.addRow(2)
		form.addLabel({label="Number of Alarms"})
		form.addIntbox(nAlarms,1,32,3,0,1,nAlarmsChanged)
		
	end
  
  end
  
 
local function printValue(width, height) 
--   Writes Fuel Remaining in Displayed TM Window 
	lcd.drawText(145 - lcd.getTextWidth(FONT_BIG,sensorvalue),0,sensorvalue,FONT_BIG)
end 
 

local function keyPressed(key)
-- Re-init correct form if navigation buttons are pressed
	if(key==KEY_1) then
		form.reinit(2)
	elseif(key == KEY_3) then
		form.reinit(1)
	end
end
-- #############################################################################
 
 
local function main()

--local mem = collectgarbage('count')
--print("mem ", mem) 

newTime=system.getTimeCounter()
switchVal=system.getInputsVal(switch)
	

	if (sensorID~=0 and sensorParam~=0) then
		
		local sensors = system.getSensorByID(sensorID, sensorParam)
				
		if (sensors.valid == true) then  
			FuelRemain = (sensors.value/100) * TankCapacity
			sensorvalue= (string.format("%i %s", (math.floor(FuelRemain+0.5)), Units))	
			sensorvalid=1
		else	 
			sensorvalue= "-"
			sensorvalid=0
		end	
		
		else
		sensorvalue="Sensor Error"
		sensorvalid=0
		
	end


-- Voice Announcements		
-- Prevents multiple voice repeats - forces a 2sec wait between announcements

	if (switchVal and switchVal == 1 and sensorvalid==1) then
		if((newTime-time1)>2000) then
		   system.playNumber (math.floor(FuelRemain+0.5), 0, Units, "Fuel")
			time1=newTime		
		end
	end


-- Alarm Announcements
	
	if (FuelRemain and sensorvalue and sensorvalid == 1) then

		for i=1,(nAlarms*nLines),nLines do 
	
			if (FuelRemain < Alarm[i] and Alarm[i+1] and Alarm[i+2]==1 ) then
				system.playFile(Alarm[i+1],AUDIO_IMMEDIATE)
				Alarm[i+2]=0
				if (AlarmVoice==true) then
					system.playNumber (Alarm[i], 0, Units)	
				end
				
			elseif (FuelRemain >= Alarm[i] or sensorvalid == 0) then  
				Alarm[i+2]=1
			end
		end
	end

end
  

local function init() 

local Alm1, Alm2, Alm3

nLines=3	-- Number of display lines used per alarm, including the spacer. Do not reduce below 3.
FuelRemain=0
componentIndex=0
sensorvalue="-"
sensorvalid=0
switchVal=0
sensorID=0
sensorParam=0
UnitOptions={"ml", "Floz"}

local sensors = system.getSensors()
	
	for i,sensor in ipairs(sensors) do
		if (sensor.label == "Fuel") then  
			sensorID=sensor.id
			sensorParam=sensor.param
		end
	end

time1=system.getTimeCounter()

Units = system.pLoad("Units","Floz")
UnitType=system.pLoad("UnitsType",2)
switch = system.pLoad("switch")
TankCapacity = system.pLoad("TankCapacity",100)
AlarmVoiceVal = system.pLoad("AlarmVoiceVal",1)
nAlarms = system.pLoad("nAlarms",3)
nAlarmsOld=nAlarms

	if (AlarmVoiceVal==1) then
		AlarmVoice = true
	else
		AlarmVoice = false
	end

	for i=1,(nAlarms*nLines),nLines do 
		Alm1= (string.format("%s%s", "Alarm",i))	
		Alm2= (string.format("%s%s", "Alarm",(i+1)))
		Alm3= (string.format("%s%s", "Alarm",(i+2)))
		Alarm[i]=system.pLoad(Alm1,0)		-- Alarm Fuel Quantity
		Alarm[i+1]=system.pLoad(Alm2,"")	-- Alarm Audio File
		Alarm[i+2]=system.pLoad(Alm3,1)		-- Alarm Audio Arm
	end
	
system.registerTelemetry(1,"LUA: Fuel Remaining",1,printValue)
system.registerForm(1,MENU_APPS,appName,initForm,keyPressed) 

---------------------------
device, emFlag = system.getDeviceType()
---------------------------

end
--------------------------------------------------------------------------------
return {init=init, loop = main, author="Paul Bloxham", version=appVer, name = appName}
