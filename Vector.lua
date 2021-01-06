--
-- Vector.lua DFM 01/06/2021
--
-- Visualize vector thrust tube mixed from pitch and yaw for Harry
--
--

local emflag

local chanList = {}

local pitch  = 0
local yaw    = 0
local vpitch = 0
local vyaw   = 0

local lastSample = 0
local maxXY=200

local XX={}
local YY={}

local XV={}
local YV={}

local function chanPitchChanged(val)
   chanPitch = val
   system.pSave("chanPitch", chanPitch)
end

local function chanYawChanged(val)
   chanYaw = val
   system.pSave("chanYaw", chanYaw)
end

local function chanVPitchChanged(val)
   chanVPitch = val
   system.pSave("chanVPitch", chanVPitch)
end

local function chanVYawChanged(val)
   chanVYaw = val
   system.pSave("chanVYaw", chanVYaw)
end

local function initForm()
      form.addRow(2)
      form.addLabel({label="Pitch", width=220})
      form.addSelectbox(chanList, chanPitch, true, chanPitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Yaw", width=220})
      form.addSelectbox(chanList, chanYaw, true, chanYawChanged)
      
      form.addRow(2)
      form.addLabel({label="Vector Pitch", width=220})
      form.addSelectbox(chanList, chanVPitch, true, chanVPitchChanged)
      
      form.addRow(2)
      form.addLabel({label="Vector Yaw", width=220})
      form.addSelectbox(chanList, chanVYaw, true, chanVYawChanged)
      
      form.addRow(1)
      form.addLabel({label="Vector.lua Version 1", font=FONT_MINI, alignRight=true})
end

local sf = 72

local function xp(x)
   return x*sf+160
end

local function yp(y)
   return 80-y*sf
end

local function vecThr()

   pitch, yaw, vpitch, vyaw =
      system.getInputs("O"..chanPitch, "O"..chanYaw, "O"..chanVPitch, "O"..chanVYaw)

   lcd.setColor(0,0,0)
   lcd.drawLine(160-(sf+1),80, 160+sf-1, 80)
   lcd.drawLine(160, 80+sf-1, 160, 80-sf)
   lcd.drawRectangle(160-(sf+1), 80-(sf+1), 2*sf+1, 2*sf+1)
   lcd.drawCircle(159, 79, sf)
   lcd.setColor(255,0,0)
   lcd.drawCircle(xp(yaw), yp(pitch), 4)
   lcd.drawText(10, 10, "P: "..math.floor(pitch*100))
   lcd.drawText(10, 30, "Y: "..math.floor(yaw*100))
   lcd.drawText(10, 50, "R: "..math.floor(math.sqrt( (pitch*100)^2 + (yaw*100)^2 ) ) )
   lcd.setColor(0,0,255)
   lcd.drawCircle(xp(vyaw), yp(vpitch), 8)
   lcd.drawText(10,  90, "VP: "..math.floor(vpitch*100))
   lcd.drawText(10, 110, "VY: "..math.floor(vyaw*100))
   lcd.drawText(10, 130, "VR: "..math.floor(math.sqrt( (vpitch*100)^2 + (vyaw*100)^2 ) ) )   

   if system.getTimeCounter() -  lastSample  > 20 then
      if #XX + 1 > maxXY then
	 table.remove(XX, 1)
	 table.remove(YY, 1)
	 table.remove(XV, 1)
	 table.remove(YV,1)
      end
      table.insert(XX, xp(yaw))
      table.insert(YY, yp(pitch))
      table.insert(XV, xp(vyaw))
      table.insert(YV, yp(vpitch))

      lastSample = system.getTimeCounter()
   end

   lcd.setColor(255,0,0)
   for i=1,#XX,1 do
      lcd.drawCircle(XX[i], YY[i], 2)
   end
   lcd.setColor(0,0,255)
   for i=1,#XX,1 do
      lcd.drawCircle(XV[i], YV[i], 6)
   end
   
end

local function init()
   
   system.registerForm(1, MENU_APPS, "Vector Thrust Visualizer", initForm)

   system.registerTelemetry(1, "Vector Thrust Visualizer", 4, vecThr)

   emflag = (select(2,system.getDeviceType()) == 1)

   chanPitch  = system.pLoad("chanPitch",  2)
   chanYaw    = system.pLoad("chanYaw",    3)
   chanVPitch = system.pLoad("chanVPitch", 5)
   chanVYaw   = system.pLoad("chanVYaw",   6)
   
   for i=1, 24, 1 do
      chanList[i] = "Servo "..i
   end
   
end


return {init=init, loop=loop, author="DFM", version=1.0,name="Vector Visualizer"}
