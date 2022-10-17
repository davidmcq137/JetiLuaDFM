--[[
   ----------------------------------------------------------------------
   DFM-Dial.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local DialVersion = "0.1"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0
local emFlag
   
local fileBD
local fileBDG
local writeBD = true
local writeBDG = false

local sensorLalist = { "..." }  -- sensor labels (long)
local sensorLslist = { "..." }  -- sensor labels (short)
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor units

local MAXDIAL = 8
local dial = {}
local tele = {}

local nSens = {1,2,3,3,4}

local dial1
local dial1Se, dial1SeId, dial1SePa
local dial1min, dial1max
local dial1style

local dial2
local dial2Se, dial2SeId, dial2SePa
local dial2min, dial2max
local dial2style

local needle_poly_small = {
   {-3,0},
   {-1,28},
   {1,28},
   {3,0}
}


local savedRow
local savedRow2

-- Read and set translations (out for now till we have translations, simplifies install)

local function setLanguage()
--[[
    local lng=system.getLocale()
  local file = io.readall("Apps/Lang/DFM-TimG.jsn")
  local obj = json.decode(file)cd 
  if(obj) then
    trans11 = obj[lng] or obj[obj.default]
  end
--]]
end

--------------------------------------------------------------------------------

-- Read available sensors for user to select - done once at startup

local sensorLbl = "***"

local function readSensors()

   local sensors = system.getSensors()
   for i, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then sensorLbl = sensor.label else
	    local ii = #sensorLalist+1
	    table.insert(sensorLslist, sensor.label)
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label .. "["..ii.."]")
	    --print(sensorLalist[#sensorLalist])
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	    table.insert(sensorUnlist, sensor.unit)
	 end
      end
   end
end

local function wcDelete(pathIn, pre, typ)

   local dd, fn, ext
   local path

   if select(2, system.getDeviceType()) ~= 1 then
      path = "/" .. pathIn
   else
      path = pathIn
   end      

   for name, filetype, size in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == string.lower(typ) and string.find(fn, pre) == 1 then
	    local ff = path .. "/" .. fn .. "." .. ext
	    if not io.remove(ff) then
	       print("failed to delete " .. ff)
	    end
	 end
      end
   end
end

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, val, str, rgb)

   local d
   local txt
   local font = FONT_NORMAL
   local r, g, b

   if not val then return end
   --if val < 10 and system.getTime() % 2 == 0 then return end
   
   if rgb then
      r=rgb.r
      g=rgb.g
      b=rgb.b
   else
      r=0
      g=0
      b=255
   end
   
   lcd.setColor(r,g,b)
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)

   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h//2, d, h)

   if str then
      txt = str .. string.format("%.0f%%", val)
      lcd.setColor(255,255,255)
      -- note that for some reason, setClipping moves things to the right by the x coord
      -- of the clip region .. correct for that
      lcd.setClipping(oxc-w/2, 0, d, 160)
      lcd.drawText(oxc - lcd.getTextWidth(font, txt) / 2 - (oxc - w//2),
		   oyc - lcd.getTextHeight(font) / 2,
		   txt, font)
      lcd.setClipping(oxc -w/2 + d, 0, w-d, 160) 
      lcd.setColor(r,g,b)
      lcd.drawText(oxc - lcd.getTextWidth(font, txt) / 2 - (oxc - w//2 + d),
		   oyc - lcd.getTextHeight(font)//2,
		   txt, font)      
      lcd.resetClipping()
   end
end

local function timePrint(width, height)

end

-- Telemetry window draw functions

local function drawShape(col, row, shape, rotation)

   local sinShape, cosShape
   local ren = lcd.renderer()

   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   ren:reset()
   for _, point in pairs(shape) do
      ren:addPoint(
	 col + (point[1] * cosShape - point[2] * sinShape + 0.5),
	 row + (point[1] * sinShape + point[2] * cosShape + 0.5)
      ) 
   end
   ren:renderPolygon()
end

local function drawBackArc(x0, y0, a0, aR, ri, ro, im, alp)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*aR/im), y0 - ro * math.sin(a0 + i*aR/im))
   end
   ren:addPoint(x0 - ro * math.cos(a0+aR), y0 - ro * math.sin(a0+aR))
   ren:addPoint(x0 - ri * math.cos(a0+aR), y0 - ri * math.sin(a0+aR))
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*aR/im), y0 - ri * math.sin(a0+i*aR/im))
   end
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:renderPolygon(alp)
end

local function drawArc(theta, x0, y0, a0, aR, ri, ro, im, alp)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*theta/im), y0 - ro * math.sin(a0 + i*theta/im))
   end
   
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*theta/im), y0 - ri * math.sin(a0+i*theta/im))
   end
   lcd.setColor(lcd.getFgColor())
   ren:renderPolygon(alp)
end

local function drawMaxMin(hmax, hmin, max, min, x0, y0, a0, aR, ri, ro)
   local ratio
   local theta
   local ren = lcd.renderer()

   if not hmax or not hmin then return end
   
   ren:reset()
   ratio = (hmax-min)/(max-min)
   ratio = math.max(math.min(ratio, 1), 0)
   theta = aR * ratio
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   lcd.setColor(lcd.getFgColor())
   ren:renderPolyline(3)
   
   ren:reset()
   ratio = (hmin-min)/(max-min)
   ratio = math.max(math.min(ratio, 1), 0)
   theta = aR * ratio
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   lcd.setColor(255,255,0)
   ren:renderPolyline(3)
end

local function dialPrint(w,h,win)

   local theta
   local x0, y0 = 40, 34
   local ri = 22
   local ro = 30
   local a0d = -35
   local a0 = math.rad(a0d)
   local aRd = -a0d*2 + 180
   local aR = math.rad(aRd)

   local x0 = { {40}, {80,231}, {50,50,234}, {234,50,50}, {50,201,50,201} }
   local y0 = { {34}, {93,93},  {44,123,98}, {98,123,44}, {44,44,123,123} }
   local ro = { {30}, {60,60},  {30,30,65}, {65,30,30},   {30,30,30,30} }
   local ri = { {22}, {44,44},  {22,22,44}, {44,22,22},   {22,22,22,22} }

   local rx = { {0}, {5,161}, {5,5,161}, {161,5,5}, {5,161,5,161} }
   local ry = { {0}, {10,10}, {10,89,10}, {10,89,10}, {10,10,89,89} }

   local rxs = { {0}, {151,151}, {151,151,151}, {151,151,151}, {151,151,151,151}}
   local rys = { {0}, {140,140}, {69,69,148}, {148,69,69}, {69,69,69,69} }
      
   local ratio, theta, val, max, min, xz, yz, rI, rO, ovld, sg
   for i=1, nSens[tele[win].screen],1 do
      val = tele[win].sensorValue[i]
      if tele[win].sensor[i] < 2 then return end
      if not val then print("val nil", win, i) return end
      min = tele[win].sensorMin[i]
      max = tele[win].sensorMax[i]
      if val > max or val < min then ovld = true else ovld = false end
      ratio = (val-min)/(max-min) 
      ratio = math.max(math.min(ratio, 1), 0)
      if math.abs(max-min) < 1.E-6 then
	 theta = 0
      else
	 theta = aR * ratio
      end
      xz = x0[tele[win].screen][i]
      yz = y0[tele[win].screen][i]
      rI = ri[tele[win].screen][i]
      rO = ro[tele[win].screen][i]
      if rI < 30 then sg = 15 else sg = 20 end
      drawBackArc(xz, yz, a0, aR, rI, rO, sg, 0.3)
      if tele[win].sensorStyle[i] == 1 then
	 drawArc(theta, xz, yz, a0, aR, rI, rO, sg, 1.0)
      else
	 drawShape(xz,yz, needle_poly_small, theta - math.pi - aR/2)
      end

      drawMaxMin(tele[win].sensorVmax[i], tele[win].sensorVmin[i], max, min, xz, yz, a0, aR, rI, rO)
      
      local text, f1, y1, y2, y3, x1, x2
      
      if rI < 30 then
	 f1 = FONT_BOLD
	 y1 = 14
	 y2 = 25
	 y3 = 0
	 x1 = 42
	 x2 = 42
      else
	 f1 = FONT_BIG
	 y1 = 24
	 y2 = 85
	 y3 = 85
	 x1 = 22
	 x2 = -60
      end
      
      lcd.setColor(0,0,0)
      text = string.format("%4.2f", val)
      if ovld then lcd.setColor(255,0,0) end 
      lcd.drawText(xz - lcd.getTextWidth(f1, text) / 2, yz+y1, text, f1)
      lcd.setColor(0,0,0)      
      text = string.format("%4.2f", tele[win].sensorVmax[i] or 0)
      lcd.drawText(xz + x1, yz - y2, text, FONT_BIG)
      text = string.format("%4.2f", tele[win].sensorVmin[i] or 0)
      lcd.drawText(xz + x2, yz - y3, text, FONT_BIG)
      
      if tele[win].screen > 1 then
	 lcd.drawRectangle(rx[tele[win].screen][i], ry[tele[win].screen][i],
			   rxs[tele[win].screen][i],rys[tele[win].screen][i])
      end

      lcd.drawText(rx[tele[win].screen][i],
		   ry[tele[win].screen][i]-12,
		   sensorLslist[tele[win].sensor[i]] ..
		      string.format("  [%.1f-%.1f]", tele[win].sensorMin[i], tele[win].sensorMax[i]),
		   FONT_MINI)

   end

   lcd.drawText(295, 145, system.getCPU(), FONT_MINI)

end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   local row = form.getFocusedRow()

   --print(key, subForm)
   
   if keyExit(key) then
      if subForm == 13 then
	 form.preventDefault()
	 form.reinit(1)
      elseif subForm == 103 then
	 form.preventDefault()
	 form.reinit(13)
      end
      return
   end

   if subForm == 1 and key == KEY_3 then
      savedRow = row
      form.reinit(13)
   end

   if subForm == 13 and key == KEY_3 then
      savedRow2 = row
      form.reinit(103)
   end

end

local function dial1SensorChanged(val)
   dial1Se = val
   dial1SeId = sensorIdlist[dial1Se]
   dial1SePa = sensorPalist[dial1Se]
   if dial1SeId == "..." then
      dial1SeId = 0
      dial1SePa = 0
   end
end

local function dial2SensorChanged(val)
   dial2Se = val
   dial2SeId = sensorIdlist[dial2Se]
   dial2SePa = sensorPalist[dial2Se]
   if dial2SeId == "..." then
      dial2SeId = 0
      dial2SePa = 0
   end
end

local function dial1minChanged(val)
   dial1min = val
end

local function dial1maxChanged(val)
   dial1max = val
end

local function dial2minChanged(val)
   dial2min = val
end

local function dial2maxChanged(val)
   dial2max = val
end

local function dial1styleChanged(val)
   dial1style = val
end

local function dial2styleChanged(val)
   dial2style = val
end

local function dialSensorChanged(val, i)
   --print("val, i", val, i, sensorLalist[val])
   dial[i].Se = val
end

local function teleWinChanged(val, i)
   print("tws", val, i)
   tele[i].screen = val
   local ii, str
   if val == 1 then
      ii = 2
      str = string.format("%d) ", i) .. sensorLslist[tele[i].sensor[i]] ..
	 string.format("  [%.1f-%.1f]", tele[i].sensorMin[1], tele[i].sensorMax[1])
      print("str:", str)
   else
      ii = 4
      str = string.format("Dial display %d", i)
   end
   
   system.unregisterTelemetry(i)
   system.registerTelemetry(i, str, ii,
			    (function(x,y) return dialPrint(x,y,i) end))
end

local function dialminChanged(val, i)
   dial[i].min = val
end

local function dialmaxChanged(val, i)
   dial[i].max = val
end

local function dialstyleChanged(val, i)
   dial[i].style = val
end

local function teleSensorChanged(val,i,j)
   tele[i].sensor[j] = val
end

local function sensorMinChanged(val, i, j)
   tele[i].sensorMin[j] = val
end

local function sensorMaxChanged(val, i, j)
   tele[i].sensorMax[j] = val
end

local function sensorStyleChanged(val, i, j)
   tele[i].sensorStyle[j] = val
end

local function initForm(sf)
   local str
   subForm = sf
   --print("initForm: savedRow", savedRow)
   
   if sf == 1 then
      form.setButton(3, ":edit", 1)
      form.setTitle("Telemetry Window Setup")
      local teleSelect = {"Double (1)", "Full Screen (2)", "Full Screen (3R)",
			  "Full Screen (3L)", "Full Screen (4)"}
      for i=1,2,1 do
	 form.addRow(2)
	 form.addLabel({label=string.format("%d", i), width=60})
	 form.addSelectbox(teleSelect, tele[i].screen, true,
			   (function(x) return teleWinChanged(x,i) end), {width=260, alignRight=false})	 
      end
   elseif sf == 13 then
      form.setButton(3, ":edit", 1)
      local dials = {}
      local dialsNum = {}
      dials[1] = "..."
      dialsNum[1] = 1
      for i=1,MAXDIAL,1 do
	 if dial[i].Se > 1  then
	    table.insert(dials, sensorLalist[dial[i].Se])
	    table.insert(dialsNum, dial[i].Se)
	 end
      end
      
      form.setTitle(string.format("Edit Telemetry Window %d", savedRow))
      for i=1, nSens[tele[savedRow].screen],1 do
	 form.addRow(2)
	 form.addLabel({label=string.format("Sensor %d:", i), width=80})
	 form.addSelectbox(sensorLalist, tele[savedRow].sensor[i], true,
			   (function(x) return teleSensorChanged(x,savedRow,i) end),
			   {width=240, alignRight=false})
      end
   elseif sf == 103 then
      form.setTitle("Edit sensor dial " .. savedRow .." "..savedRow2)
      --print("savedRow, savedRow2", savedRow, savedRow2, #tele[savedRow].sensor)

      form.addRow(2)
      form.addLabel({label="Minimum value"})
      form.addIntbox(tele[savedRow].sensorMin[savedRow2], -32768, 32767, 0, 0, 1,
		     (function(x) return sensorMinChanged(x, savedRow, savedRow2) end))
      form.addRow(2)
      form.addLabel({label="Maximum value"})
      form.addIntbox(tele[savedRow].sensorMax[savedRow2], -32768, 32767, 0, 0, 1,
		     (function(x) return sensorMaxChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLabel({label="Style"})      
      form.addSelectbox({"Arc", "Needle"}, tele[savedRow].sensorStyle[savedRow2], true, 
	 (function(x) return sensorStyleChanged(x, savedRow, savedRow2) end))
   end
end

--------------------------------------------------------------------------------

local function writeBattery()
   local fp
   local save = {}

   save.dial = dial
   save.tele = tele
   
   if writeBD then
      fp = io.open(fileBD, "w")
      if fp then
	 print("writing", fileBD)
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end

   if writeBDG then
      fp = io.open(fileBDG, "w")
      if fp then io.write(fp, json.encode(save), "\n")
	 io.close(fp)
      end
   end
end

local function destroy()
   writeBattery()
end


local function loop()
   local idx, sensor, value
   for i=1,2,1 do
      for j=1,nSens[tele[i].screen],1 do
	 idx = tele[i].sensor[j]
	 if idx > 1 then
	    --print(idx, sensorIdlist[idx], sensorPalist[idx])
	    sensor = system.getSensorByID(sensorIdlist[idx], sensorPalist[idx])
	    if sensor and sensor.valid then
	       value = sensor.value
	       --print("value", value)
	       tele[i].sensorValue[j] = value
	       if not tele[i].sensorVmin[j] then
		  tele[i].sensorVmin[j] = value
	       else
		  if value < tele[i].sensorVmin[j] then tele[i].sensorVmin[j] = value end
	       end
	       if not tele[i].sensorVmax[j] then
		  tele[i].sensorVmax[j] = value
	       else
		  if value > tele[i].sensorVmax[j] then tele[i].sensorVmax[j] = value end
	       end
	    end
	 end
      end
   end
   
   for i=1,MAXDIAL,1 do
      if dial[i].Se > 1 then
	 sensor = system.getSensorByID(dial[i].SeId, dial[i].SePa)
	 if sensor and sensor.valid then
	    value = sensor.value
	    dial[i].value = value
	    if not dial[i].vmin then
	       dial[i].vmin = value
	    else
	       if value < dial[i].vmin then dial[i].vmin = value end
	    end
	    if not dial[i].vmax then
	       dial[i].vmax = value
	    else
	       if value > dial[i].vmax then dial[i].vmax = value end
	    end
	 end
      end
   end
end

local function init()

   local pf
   local mn
   local file
   local decoded

   emFlag = select(2, system.getDeviceType())
   if emFlag == 1 then pf = "" else pf = "/" end
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fileBD = pf .. "Apps/DFM-Dial/DD_" .. mn .. ".jsn"

   file = io.readall(fileBD)

   if file then
      decoded = json.decode(file)
      dial = decoded.dial
      tele = decoded.tele
   else
      system.messageBox("No Model data read: initializing")
      print("No Model data read: initializing")      

      for i=1,MAXDIAL,1 do
	 dial[i] = {}
	 dial[i].Se = 1
	 dial[i].SeId = 0
	 dial[i].SePa = 0
	 dial[i].min = 0
	 dial[i].max = 10
	 dial[i].style = 1
      end
      
      for i=1,2,1 do
	 tele[i] = {}
	 tele[i].screen = 1 -- default to double tele window (one value)
	 tele[i].sensor = {}
	 tele[i].sensorMin = {}
	 tele[i].sensorMax = {}
	 tele[i].sensorStyle = {}
	 tele[i].sensorValue = {}
	 tele[i].sensorVmin = {}
	 tele[i].sensorVmax = {}
	 for j=1,4,1 do
	    tele[i].sensor[j] = 1 -- default to "..."
	    tele[i].sensorMin[j] = 0
	    tele[i].sensorMax[j] = 10
	    tele[i].sensorStyle[j] = 1 -- default to Arc
	 end
      end
   end

   -- don't remember value min and max from run to run

   for i=1,2,1 do
      for j=1,4,1 do
	 tele[i].sensorVmin[j] = nil
	 tele[i].sensorVmax[j] = nil
      end
   end
   
   -- don't remember value min and max from run to run
   
   for i=1,MAXDIAL,1 do
      dial[i].vmin = nil
      dial[i].vmax = nil
   end

   readSensors()
   
   system.registerForm(1, MENU_APPS, "Dial Display", initForm, keyForm)

   for i=1,2,1 do
      local ii, str
      if tele[i].screen == 1 then
	 ii = 2
	 if tele[i].sensor[1] > 1 then
	    str = string.format("%d) ", i) .. sensorLslist[tele[i].sensor[1]] ..
	       string.format("  [%.1f-%.1f]", tele[i].sensorMin[1], tele[i].sensorMax[1])
	 else
	    str = string.format("Dial Display %d", i)
	 end
      else
	 ii = 4
	 str = string.format("Dial Display %d", i)	 
      end
      system.registerTelemetry(i, str, ii,
			       (function(x,y) return dialPrint(x,y,i) end))
   end
   
   
   setLanguage()

   print("DFM-Dial: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=DialVersion, name="Dial Display", destroy=destroy}
