-- #############################################################################                      
-- # V1.0 - Initial Release
-- #############################################################################
--
-- Locals for the application

local appName = "Announce Max Nz"
local appVer = "v1.0"
local Nzmaxenable={}
local Nzmaxenableval
local Nzmaxvalid
local Nzlog, NzMax, Nzann, Nz
local Nzlogd, Nzannd
local time1, newTime
local sensorID, sensorParam
 
-- ############################################################################# 

local function EnableChanged(value)
	Nzmaxenableval=value
	system.pSave("Nzmaxenableval",value) 
end


local function NzlogChanged(value)
	Nzlogd=value
	Nzlog=Nzlogd/10
	system.pSave("Nzlog",value) 
end


local function NzannChanged(value)
	Nzannd=value
	Nzann=Nzannd/10
	system.pSave("Nzann",value) 
end


-- Form initialization
local function initForm(subform)

		form.addRow(2)
		form.addLabel({label="Enable Audio Max Nz", width=160})
		form.addSelectbox(Nzmaxenable,Nzmaxenableval or 1,false,EnableChanged)

		form.addSpacer(10,10)
		
		form.addRow(2)
		form.addLabel({label="Log Max Nz > ", width=160})
		form.addIntbox(Nzlogd,10,160,60,1,1,NzlogChanged)

	  	form.addSpacer(10,10)
	
		form.addRow(2)
		form.addLabel({label="Announce Max Nz < ", width=160})
		form.addIntbox(Nzannd,10,160,30,1,1,NzannChanged)
		
  end
  
-- #############################################################################
 
 
local function main()

--local mem = collectgarbage('count')
--print("mem ", mem) 

	newTime=system.getTimeCounter()

	if (Nzmaxenableval==1) then

		if (sensorID~=0 and sensorParam~=0) then
			
			local sensors = system.getSensorByID(sensorID, sensorParam)
					
			if (sensors.valid == true) then  
				Nzmaxvalid=1
				Nz = sensors.value

					if (Nz > Nzmax) then
						Nzmax = Nz
					end
			else		
				Nzmaxvalid=0
			end	

		end
			
			-- Voice Announcements		
			-- Prevents multiple voice repeats - forces a 2sec wait between announcements
	
		if (Nz and Nz < Nzann and Nzmax > Nzlog and Nzmaxvalid==1) then
		
			if((newTime-time1)>2000) then
				system.playNumber ((math.floor(Nzmax*10+0.5))/10, 1,"G")
				time1=newTime	
				Nzmax=Nzlog
				Nzmaxvalid=0			
			end

		end

	end
end
  

local function init() 

Nzlog=6
Nzann=3
Nzlogd=60
Nzannd=30
Nzmax=1
Nzmaxvalid=0
Nzmaxenableval=1

Nzmaxenable={"Y","N"}

sensorID=0
sensorParam=0

Nzmaxenableval = system.pLoad("Nzmaxenableval",1)
Nzlogd = system.pLoad("Nzlog",60)
Nzannd = system.pLoad("Nzann",30)
Nzlog=Nzlogd/10
Nzann=Nzannd/10

local sensors = system.getSensors()
	
	for i,sensor in ipairs(sensors) do
		if (sensor.label == "Nz (Filtered)") then  
			sensorID=sensor.id
			sensorParam=sensor.param
		end
	end

time1=system.getTimeCounter()

system.registerForm(1,MENU_APPS,appName,initForm,keyPressed) 

end
--------------------------------------------------------------------------------
return {init=init, loop = main, author="Paul Bloxham", version=appVer, name = appName}