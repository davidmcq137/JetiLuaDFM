local ren = lcd.renderer()
local SB_Config={}
local SBTDeviceID=16819270
local pcallOK, emulator
local screens={}
local screenIdx
local builtIn
local backGndImage
local screenConfig={}
local arcFile = {}

local SBT_Telem = {
   T1={SeId=0,SePa=0,value=0},
   T2={SeId=0,SePa=0,value=0},
   T3={SeId=0,SePa=0,value=0},
   T4={SeId=0,SePa=0,value=0},
   T5={SeId=0,SePa=0,value=0},
   T6={SeId=0,SePa=0,value=0},
   T7={SeId=0,SePa=0,value=0},
   T8={SeId=0,SePa=0,value=0},
}

local needle_poly_small = {
   {-2,12},
   {-1,26},
   {1,26},
   {2,12}
}

local function readSensors()
   local text
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.id == SBTDeviceID and sensor.param ~= 0 then
	    SBT_Telem[sensor.label].SeId = sensor.id
	    SBT_Telem[sensor.label].SePa = sensor.param
	    SBT_Telem[sensor.label].unit = sensor.unit
	 end
      end
   end
end

local function drawShape(col, row, shape, rotation, clr)
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
   lcd.setColor(clr.r,clr.g,clr.b)
   ren:renderPolygon()
   lcd.setColor(0, 0, 0)
end

local function drawTextCenter(font, txt, ox, oy)
    lcd.drawText(ox - lcd.getTextWidth(font, txt) / 2, oy, txt, font)
end

local function drawGauge(label, min, mid, max, temp, unit, ox, oy)

    local color={}
    
    if temp <= mid then
       color.r=255*(temp-min)/(mid-min)
       color.g=255
       color.b=0
    else
       color.r=255
       color.g=255*(1-(temp-mid)/(max-mid))
       color.b=0
    end

    drawTextCenter(FONT_MINI, label, ox+25, oy+38)
    lcd.setColor(0,0,255)
    drawTextCenter(FONT_BOLD, string.format("%d", temp), ox+25, oy+16)
    lcd.setColor(120,120,120)
    if min ~= 0 then
       drawTextCenter(FONT_MINI,
		      string.format("%d", min) .. " - " .. string.format("%d", max) .. unit,
		      ox + 25, oy+52)
    else
       drawTextCenter(FONT_MINI,
		      string.format("%d", max) .. unit,
		      ox + 25, oy+52)
    end
    
    lcd.setColor(0,0,0)
    
    temp = math.min(max, math.max(temp, min))
    theta = math.pi - math.rad(135 - 2 * 135 * (temp - min) / (max - min) )
    
    if arcFile ~= nil then
       lcd.drawImage(ox, oy, arcFile)
       drawShape(ox+25, oy+26, needle_poly_small, theta, color)
    end
end

local function loop()
   local sensor
   for k,v in pairs(SBT_Telem) do
      if v.SeId and v.SeId ~= 0 then
	 sensor = system.getSensorByID(v.SeId, v.SePa)
      end
      if sensor and sensor.valid then
	 v.value = sensor.value
      end
   end
end


local function teleBuiltIn()
   local x0=12
   local y0=12
   local idx
   local k
   
   for i=1,4,1 do
      for j=1,2,1 do
	 idx = i+4*(j-1)	 
	 k="T"..idx
	 drawGauge(SB_Config.Probes[idx].Name,
		   SB_Config.Probes[idx].Min,
		   SB_Config.Probes[idx].Mid,
		   SB_Config.Probes[idx].Max,
		   SBT_Telem[k].value or 0,
		   SBT_Telem[k].unit or "",
		   x0+(i-1)*80, y0+(j-1)*80)
      end
   end
end

local function teleImage()
   local midW=160
   local midH=80
   local maxH=159
   local x,y
   local xp, yp
   local xt, yt, dx
   local r,g,b
   local text
   
   lcd.drawImage( (310-backGndImage.width)/2+2+60, 10, backGndImage)

   for k = 1, #screenConfig.Locations do
      x=screenConfig.Locations[k].XP
      y=screenConfig.Locations[k].YP
      x = x + midW
      y = y + midH
      y=maxH-y
      y=y-15
      x=x-2+60
      
      kk = "T"..k
      if SBT_Telem[kk].value < screenConfig.Green then
	 r,g,b = 0,0,255
	 lcd.setColor(r,g,b)
      elseif SBT_Telem[kk].value >= screenConfig.Green and
      SBT_Telem[kk].value < screenConfig.Yellow then
	 r,g,b = 25,255,45
	 lcd.setColor(r,g,b)
      elseif SBT_Telem[kk].value >= screenConfig.Yellow and
      SBT_Telem[kk].value < screenConfig.Red then
	 r,g,b = 245,210,50
	 lcd.setColor(r,g,b)
      elseif SBT_Telem[kk].value >= screenConfig.Red then
	 r,g,b = 255,0,0
	 lcd.setColor(r,g,b)
      end

      xp = x - lcd.getTextWidth(FONT_NORMAL, screenConfig.Locations[k].Name)/2
      yp = y + lcd.getTextHeight(FONT_NORMAL)/2
      lcd.drawText(xp,yp, screenConfig.Locations[k].Name)

      lcd.setColor(0,0,0)
      
      xt=screenConfig.Locations[k].XT
      yt=screenConfig.Locations[k].YT
      text = screenConfig.Locations[k].Name.."("..kk.."): "
      dx = lcd.getTextWidth(FONT_NORMAL, text)
      lcd.drawText(xt, yt, text)
      lcd.setColor(r,g,b)
      text = string.format("%.1f", SBT_Telem[kk].value)
      lcd.drawText(xt+dx+2, yt, text)
      lcd.setColor(0,0,0)
      dx = dx + lcd.getTextWidth(FONT_NORMAL, text)
      lcd.drawText(xt+dx+2, yt, SBT_Telem[kk].unit)
      
   end
end

local function tele()
   if builtIn then teleBuiltin() else teleImage() end
end

local function init()

   local fp
   local imgName
   local dev
   local emFlag
   local prefix
   local sf
   
   dev, emFlag = system.getDeviceType()   

   pcallOK, emulator = pcall(require, "sensorEmulator")
   --if not pcallOK then print("pcall error: ", emulator) end
   if pcallOK and emulator then emulator.init("digitechSBT") end

   readSensors()

   imgName = "Apps/digitechSBT/c-000.png"
   arcFile = lcd.loadImage(imgName)

   system.registerTelemetry(1,"SB-Temp", 4, tele)

   if emFlag == 1 then prefix = "" else prefix="/" end

   for name, filetype, size in dir(prefix.."Apps/digitechSBT/BuiltInScreens") do
      sf = string.find(name, ".jsn")
      if filetype == "file" and sf then
	 table.insert(screens, "#"..string.sub(name,1, sf-1))
      end
   end

   for name, filetype, size in dir(prefix.."Apps/digitechSBT/ImageScreens") do
      --print("name:", name)
      sf = string.find(name, ".jsn")      
      if filetype == "file" and string.find(name, ".jsn") then
	 table.insert(screens, string.sub(name,1, sf-1))
      end
   end

   if emFlag == 1 then
      for k,v in pairs(screens) do
	 print(k,v)
      end
   end

   screenIdx = 2
   
   if screenIdx == 1 then
      builtIn = true
      --print("opening: ",
      --"Apps/digitechSBT/BuiltInScreens/"..string.sub(screens[1], 2)..".jsn")
      fp = io.readall("Apps/digitechSBT/BuiltInScreens/"..string.sub(screens[1], 2)..".jsn")
      SB_Config = json.decode(fp)
      if not SB_Config then print("Bad json decode") end
   end
   
   if screenIdx == 2 then
      builtIn = false
      --print("opening: ", "Apps/digitechSBT/ImageScreens/"..screens[2]..".jsn")
      fp = io.readall("Apps/digitechSBT/ImageScreens/"..screens[2]..".jsn")
      screenConfig = json.decode(fp)
      --print("screenConfig", screenConfig)
      --print("loading: ", screenConfig.Image)
      backGndImage = lcd.loadImage("Apps/digitechSBT/ImageScreens/"..screenConfig.Image)
      --print("backGndImage:", backGndImage)
   end
   
end

--------------------------------------------------------------------------------

return {init=init, loop=loop, name="SB-Temp", author="DFM", version="1.0"}
