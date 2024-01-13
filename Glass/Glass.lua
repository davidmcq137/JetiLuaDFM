
local image = {}
local imageNum = 0
local imageMax = 0

local Glass = {}
Glass.sensorLalist = {"..."}
Glass.sensorLslist = {"..."}
Glass.sensorIdlist = {0}
Glass.sensorPalist = {0}
Glass.sensorUnlist = {"-"}
Glass.sensorDplist = {0}
Glass.sensorTable = {}


local teleSensors, txTeleSensors
local txSensorNames = {"txVoltage", "txBattPercent", "txCurrent", "txCapacity",
		       "rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage",
		       "rxBVoltage", "rxBPercent", "photoValue"}
local txSensorUnits = {"V", "%", "mA", "mAh", "%", "V", "%", "V", "V", "%", " "}
local txSensorDP    = { 1,   0,    0,     0,   0,   1,   0,   1,   1,   0,   0}
local txRSSINames = {"rx1Ant1", "rx1Ant2", "rx2Ant1", "rx2Ant2",
		     "rxBAnt1", "rxBAnt2"}

-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
local function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
local function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function readSensors(tt)
   local sensorLbl = "***"
   local l1, l2
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    l1 = string.gsub(sensorLbl, "%W", "")
	    l2 = string.gsub(sensor.label, "%W", "")
	    table.insert(tt.sensorLalist, l1 .. "_" .. l2)
	    table.insert(tt.sensorLslist, sensor.label)	    
	    table.insert(tt.sensorIdlist, sensor.id)
	    table.insert(tt.sensorPalist, sensor.param)
	    table.insert(tt.sensorUnlist, sensor.unit)
	    table.insert(tt.sensorDplist, sensor.decimals)
	 end
      end
   end
   teleSensors = #tt.sensorLalist

   l1 = "txTel"
   for i, label in ipairs(txSensorNames) do
      table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, i)
      table.insert(tt.sensorUnlist, txSensorUnits[i])
      table.insert(tt.sensorDplist, txSensorDP[i])
   end
   txTeleSensors = #tt.sensorLalist

   l1 = "txRSSI"
   for i, label in ipairs(txRSSINames) do
   table.insert(tt.sensorLalist, l1 .. "_" .. label)
      table.insert(tt.sensorLslist, label)	    
      table.insert(tt.sensorIdlist, 0)
      table.insert(tt.sensorPalist, -i)
      table.insert(tt.sensorUnlist, " ")
      table.insert(tt.sensorDplist, 0)
   end

   for i,v in ipairs(tt.sensorLalist) do
      tt.sensorTable[v] = {SeId = tt.sensorIdlist[i], SePa = tt.sensorPalist[i],
			   SeUn = tt.sensorUnlist[i], SeDp = tt.sensorDplist[i]}
   end
   
end

local function loop()
end

local function throttleFullChanged(value)
   print("throttleFullChanged", value)
end

local function initForm(ff)

   local throttleFull = 0
   local throttleFullForm

   form.setButton(3, ":up", ENABLED)
   form.setButton(4, ":down", ENABLED)   
   
   form.addRow(2)
   form.addLabel({label="Test AAAAAAAAAAAAAA (%)", width=80, font=FONT_MINI})
   throttleFullForm = form.addIntbox(throttleFull, -100, 100, 90, 0, 1, throttleFullChanged, {width=50, font=FONT_MINI})

end

local function keyPressed(key)
   --print("keyPressed", key)
   if key == KEY_3 then
      imageNum = imageNum + 1
      if imageNum > imageMax then imageNum = 1 end
   elseif key == KEY_4 then
      imageNum = imageNum - 1
      if imageNum < 1 then imageNum = imageMax end      
   end
end

local function printForm(form)

   local offset = 320-144-10
   lcd.setColor(255,255,255)
   lcd.drawFilledRectangle(offset, 0, 144, 144)
   if imageNum > 0 then
      lcd.drawImage(offset,0,image[imageNum])
   end
end

local function init()

   local dd, fn, ext
   local ff
   
   system.registerForm(1, MENU_APPS, "G Test", initForm, keyPressed, printForm)

   local path = "Apps/Gtest/Images"

   imageMax = 0
   if dir(path) then
      for name, _, _ in dir(path) do
	 dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
	 if fn and ext then
	    if string.lower(ext) == "png" then
	       ff = path .. "/" .. fn .. "." .. ext
	       imageMax = imageMax + 1
	       print("loading " ..imageMax .." " .. ff)
	       image[imageMax] = lcd.loadImage(ff)
	    end
	 end
      end
   end

   if imageMax > 0 then imageNum = 1 else imageNum = 0 end
   
   local mysensor = {}

   mysensor[1] = {}
   mysensor[1].vario = {}
   mysensor[1].vario.type = 1
   mysensor[1].vario.unit = "m/s"
   mysensor[1].vario.value = 3.42
   
   mysensor[1].altitude = {}
   mysensor[1].altitude.type = 1
   mysensor[1].altitude.unit = "m"
   mysensor[1].altitude.value = 210.4

   print("json", json.encode(mysensor))

   local i=enc("1234")
   local j=enc(utf8.char(1,2,3,4))
   print("enc('1234')", i)
   print("enc(j)", j)
   print("dec(enc())", dec(i))
   print("dec(enc())", type(dec(j)), dec(j))

   local data = io.readall("Apps/DFM-Temp/ImageScreens/FiveCylinderRadial.png")
   print("type(data), #data", type(data), #data)
   local b64 = enc(data)
   print("type(b64), #b64", type(b64), #b64)   
   local orig = dec(b64)
   print("type(orig), #orig", type(orig), #orig)
   local f = io.open("Apps/DFM-Temp/ImageScreens/test.png", "w")
   if f then
      print("io.write", io.write(f, orig))
      io.close(f)
   else
      print("error on open w")
   end
   
   
end

return {init=init, loop=loop, author="DFM", version="0.0", name="Gtest"}
