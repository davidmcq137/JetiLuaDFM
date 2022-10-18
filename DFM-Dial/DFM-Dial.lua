--[[
   ----------------------------------------------------------------------
   DFM-Dial.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local DialVersion = "0.4"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0
local emFlag
   
local fileBD
local writeBD = true
local loopCPU = 0

local sensorLalist = { "..." }  -- sensor labels (long)
local sensorLslist = { "..." }  -- sensor labels (short)
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor units

local tele = {}

local nSens = {1,2,3,3,4}

local teleSelect = {"Double (1)", "Full Screen (2)", "Full Screen (3R)",
		    "Full Screen (3L)", "Full Screen (4)"}

local MAXSAMPLE = 150

local needle_poly_small = {
   {-3,0},
   {-1,28},
   {1,28},
   {3,0}
}

local needle_poly_large = {
   {-1,0},
   {-2,1},
   {-4,4},
   {-1,58},
   {1,58},
   {4,4},
   {2,1},
   {1,0}
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
	    table.insert(sensorLslist, sensor.label) -- .. "[" .. ii .. "]")
	    table.insert(sensorLalist, sensorLbl .. "-> " .. sensor.label) -- .. "["..ii.."]")
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

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, hmin, hmax, val, str, rgb)

   local d, d1, d2
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

   d1 = math.max(math.min((hmin/(max-min))*w, w), 0)

   d2 = math.max(math.min((hmax/(max-min))*w, w), 0)   
   
   lcd.setColor(255,255,0)
   lcd.drawFilledRectangle(oxc-w//2+ d1-1, oyc-h//2, 2, h)
   lcd.setColor(lcd.getFgColor())
   lcd.drawFilledRectangle(oxc-w//2+ d2-1, oyc-h//2, 2, h)
   
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
   lcd.setColor(0,0,0)
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

local function drawChart(x0, xl, y0, yl, min, max, val)
   local ren = lcd.renderer()
   ren:reset()
   for i=1,#val,1 do
      --print(x0+i, y0 - yl*(val[i]-min)/(max-min))
      ren:addPoint(x0+i, y0 + yl*(val[i]-min)/(max-min))
   end
   lcd.setColor(0,0,0)
   ren:renderPolyline(2, 0.4)
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

local function formatD(val)
   if math.abs(val) > 1000 then
      return string.format("%4.0f", val)
   elseif math.abs(val) > 100 then
      return string.format("%4.1f", val)
   else
      return string.format("%3.2f", val)      
   end
end


local function dialPrint(w,h,win)

   local theta
   local a0d = -35
   local a0 = math.rad(a0d)
   local aRd = -a0d*2 + 180
   local aR = math.rad(aRd)

   local x0 = { {40}, {80,237}, {50,50,236}, {80,201,201}, {50,201,50,201} }
   local y0 = { {34}, {96,96},  {44,123,96}, {96,123,44}, {44,44,123,123} }   
   local ro = { {30}, {62,62},  {30,30,62},  {62,30,30},   {30,30,30,30} }
   local ri = { {22}, {44,44},  {22,22,44},  {44,22,22},   {22,22,22,22} }

   local rx = { {0}, {5,161}, {5,5,161}, {5,161,161}, {5,161,5,161} }   
   local ry = { {0}, {10,10}, {10,89,10}, {10,10,89}, {10,10,89,89} }   

   local rxs = { {151}, {151,151}, {151,151,151}, {151,151,151}, {151,151,151,151}}
   local rys = { {69}, {148,148}, {69,69,148}, {148,69,69}, {69,69,69,69} }
      
   local ratio, theta, val, max, min, xz, yz, rI, rO, ovld, sg, np
   for i=1, nSens[tele[win].screen],1 do
      val = tele[win].sensorValue[i]
      if tele[win].sensor[i] < 2 then return end
      if not val then print("val nil", win, i) return end
      min = tele[win].sensorMin[i] * tele[win].sensorMinMult[i]
      max = tele[win].sensorMax[i] * tele[win].sensorMaxMult[i]
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
      if rI < 30 then
	 sg = 15
	 np = needle_poly_small
      else
	 sg = 20
	 np = needle_poly_large
      end

      local text, f1, f2, y1, y2, y3, y4, x0, x1, x2, x3, bh, bw

      if tele[win].sensorStyle[i] < 3 then
	 if rI < 30 then
	    f1 = FONT_BOLD
	    f2 = FONT_BIG
	    y1 = 14
	    y2 = 25
	    y3 = 0
	    x0 = 0
	    x1 = 70
	    x2 = 70
	    x3 = 0
	 else
	    f1 = FONT_MAXI
	    f2 = FONT_BIG
	    y1 = 24
	    y2 = 85
	    y3 = 85
	    x0 = 0
	    x1 = 40
	    x2 = -40
	    x3 = 0
	 end
      else
	 if rys[tele[win].screen][i] < 70 then
	    f1 = FONT_BOLD
	    f2 = FONT_BOLD
	    y1 = 16
	    y2 = 36
	    y3 = 36
	    y4 = 0
	    x0 = 25
	    x1 = 80
	    x2 = -20
	    x3 = 30
	    bw = 140
	    bh = 34
	 else
	    f1 = FONT_MAXI
	    f2 = FONT_BIG
	    y1 = 14
	    y2 = 56
	    y3 = 56
	    y4 = -10
	    x0 = 3
	    x1 = 45
	    x2 = -45
	    x3 = 0
	    bw = 140
	    bh = 42
	 end
      end

      if tele[win].sensorStyle[i] == 1 then --Arc
	 drawBackArc(xz, yz, a0, aR, rI, rO, sg, 0.12)
	 drawArc(theta, xz, yz, a0, aR, rI, rO, sg, 1.0)
	 drawMaxMin(tele[win].sensorVmax[i], tele[win].sensorVmin[i], max, min, xz, yz, a0, aR, rI, rO)
      elseif tele[win].sensorStyle[i] == 2 then --Dial
	 drawBackArc(xz, yz, a0, aR, rI, rO, sg, 0.2)
	 drawShape(xz,yz, np, theta - math.pi - aR/2)
	 drawMaxMin(tele[win].sensorVmax[i], tele[win].sensorVmin[i], max, min, xz, yz, a0, aR, rI, rO)
      elseif tele[win].sensorStyle[i] == 3 then --HBar
	 local v1, v2
	 v1 = ( (tele[win].sensorVmin[i] or 0) - min)/(max-min)*100
	 v2 = ( (tele[win].sensorVmax[i] or 0)- min)/(max-min)*100	 
	 drawRectGaugeAbs(xz+x3, yz+y4, bw, bh, 0, 100, v1, v2, (val-min)/(max-min)*100, "")
      elseif tele[win].sensorStyle[i] == 4 then --Chart
	 --print("type", type(tele[win].sensorSample[i]))
	 --print(rx[tele[win].screen][i], rxs[tele[win].screen][i],
	 --      ry[tele[win].screen][i], rys[tele[win].screen][i])
	 drawChart(rx[tele[win].screen][i], rxs[tele[win].screen][i],
		   ry[tele[win].screen][i], rys[tele[win].screen][i],
		   min, max, tele[win].sensorSample[i])
      end
      

      lcd.setColor(0,0,0)
      text = formatD(val)
      if ovld then lcd.setColor(255,0,0) end 
      lcd.drawText(xz + x0 - lcd.getTextWidth(f1, text) / 2, yz+y1, text, f1)
      lcd.setColor(0,0,0)      
      text = formatD(tele[win].sensorVmax[i] or 0)
      lcd.drawText(xz + x1 - lcd.getTextWidth(f2, text)/2, yz - y2, text, f2)
      text = formatD(tele[win].sensorVmin[i] or 0)
      lcd.drawText(xz + x2 - lcd.getTextWidth(f2, text)/2, yz - y3, text, f2)
      
      if tele[win].screen > 1 then
	 lcd.setColor(160,160,160)
	 lcd.drawRectangle(rx[tele[win].screen][i], ry[tele[win].screen][i],
			   rxs[tele[win].screen][i],rys[tele[win].screen][i])
      end

      lcd.setColor(0,0,0)

      
      lcd.drawText(rx[tele[win].screen][i],
		   ry[tele[win].screen][i]-12,
		   sensorLslist[tele[win].sensor[i]] ..
		      " (" .. sensorUnlist[tele[win].sensor[i]] .. ") " ..
		      string.format("  [%.1f-%.1f]",
				    tele[win].sensorMin[i] * tele[win].sensorMinMult[i],
				    tele[win].sensorMax[i] * tele[win].sensorMaxMult[i]),
		   FONT_MINI)

   end

   if emFlag then
      lcd.drawText(295, 145, system.getCPU(), FONT_MINI)
      lcd.drawText(265, 145, loopCPU, FONT_MINI)      
   end

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

   if subForm == 1 and key == KEY_1 then
      local ans
      ans = form.question("Are you sure?", "Delete all tele window data?",
			  "",
			  0, false, 5)
      if ans == 1 then
	 writeBD = false
	 wcDelete("Apps/DFM-Dial", "DD_", "jsn")
	 system.messageBox("Saved data cleared - restart App")
      end
   end

   if subForm == 13 and key == KEY_3 then
      savedRow2 = row
      form.reinit(103)
   end

end

local function teleWinChanged(val, i)
   tele[i].screen = val
   local ii, str
   if val == 1 then
      ii = 2
      str = string.format("%d) ", i) .. sensorLslist[tele[i].sensor[1]] ..
	 " (" .. sensorUnlist[tele[i].sensor[1]] .. ") " ..
	 string.format("  [%.1f-%.1f]",
		       tele[i].sensorMin[1] * tele[i].sensorMinMult[1],
		       tele[i].sensorMax[1] * tele[i].sensorMaxMult[1])
   else
      ii = 4
      str = string.format("Dial Window %d - %s", i, teleSelect[tele[i].screen])
   end
   
   system.unregisterTelemetry(i)
   system.registerTelemetry(i, str, ii,
			    (function(x,y) return dialPrint(x,y,i) end))
end

local function teleSensorChanged(val,i,j)
   tele[i].sensor[j] = val
end

local function sensorMinChanged(val, i, j)
   tele[i].sensorMin[j] = val / 100.0
end

local function sensorMinMultChanged(val, i, j)
   if val == 1 then tele[i].sensorMinMult[j] = 1 else tele[i].sensorMinMult[j] = 1000 end
end

local function sensorMaxChanged(val, i, j)
   tele[i].sensorMax[j] = val / 100.0
end

local function sensorMaxMultChanged(val, i, j)
   if val == 1 then tele[i].sensorMaxMult[j] = 1 else tele[i].sensorMaxMult[j] = 1000 end
end

local function sensorStyleChanged(val, i, j)
   tele[i].sensorStyle[j] = val
end

local function sensorChartTimeChanged(val, i, j)
   tele[i].sensorChartTime[j] = 2^(val-1)*200 -- 200msec x 150 pts = 0:30 timespan
end

local function initForm(sf)
   local str
   subForm = sf
   
   if sf == 1 then
      form.setButton(3, ":edit", 1)
      form.setButton(1, ":tools", 1)
      form.setTitle("Telemetry Window Setup")
      for i=1,2,1 do
	 form.addRow(2)
	 form.addLabel({label=string.format("%d", i), width=60})
	 form.addSelectbox(teleSelect, tele[i].screen, true,
			   (function(x) return teleWinChanged(x,i) end), {width=260, alignRight=false})	 
      end
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 13 then
      form.setButton(3, ":edit", 1)
      form.setTitle(string.format("Edit Telemetry Window %d", savedRow))
      for i=1, nSens[tele[savedRow].screen],1 do
	 form.addRow(2)
	 form.addLabel({label=string.format("Sensor %d:", i), width=80})
	 form.addSelectbox(sensorLalist, tele[savedRow].sensor[i], true,
			   (function(x) return teleSensorChanged(x,savedRow,i) end),
			   {width=240, alignRight=false})
      end
      if savedRow2 then form.setFocusedRow(savedRow2) end
      savedRow2= 1
   elseif sf == 103 then
      form.setTitle("Edit sensor dial " .. sensorLslist[tele[savedRow].sensor[savedRow2]])

      form.addRow(2)
      form.addLabel({label="Minimum value"})
      local mm
      form.addIntbox(tele[savedRow].sensorMin[savedRow2]*100, -9999, 9999, 0, 2, 1,
		     (function(x) return sensorMinChanged(x, savedRow, savedRow2) end))

      form.addRow(2)
      form.addLabel({label="Minimum multiplier"})
      if tele[savedRow].sensorMinMult[savedRow2] == 1 then mm = 1 else mm = 2 end
      form.addSelectbox({"1x", "1000x"}, mm, true,
		     (function(x) return sensorMinMultChanged(x, savedRow, savedRow2) end))

      form.addRow(2)
      form.addLabel({label="Maximum value"})
      form.addIntbox(tele[savedRow].sensorMax[savedRow2]*100, -9999, 9999, 1000, 2, 1,
		     (function(x) return sensorMaxChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLabel({label="Maximum multiplier"})
      if tele[savedRow].sensorMaxMult[savedRow2] == 1 then mm = 1 else mm = 2 end
      form.addSelectbox({"1x", "1000x"}, mm, true,
		     (function(x) return sensorMaxMultChanged(x, savedRow, savedRow2) end))

      form.addRow(2)
      form.addLabel({label="Style"})      
      form.addSelectbox({"Arc", "Needle", "HBar", "Chart"}, tele[savedRow].sensorStyle[savedRow2], true, 
	 (function(x) return sensorStyleChanged(x, savedRow, savedRow2) end))

      form.addRow(2)
      form.addLabel({label="Time span for Chart"})
      local dt = math.log(tele[savedRow].sensorChartTime[savedRow2]/200) / math.log(2) + 1
      form.addSelectbox({"0:30", "1:00", "2:00", "4:00", "8:00"},
	 dt, true, 
	 (function(x) return sensorChartTimeChanged(x, savedRow, savedRow2) end))
      
      form.setFocusedRow(1)
   end
end

--------------------------------------------------------------------------------

local function writeTele()
   local fp
   local save = {}

   -- don't save chart samples
   for i=1,2,1 do
      for j=1,4,1 do
	 tele[i].sensorSample[j] = {}
      end
   end
   
   save.tele = tele
   
   if writeBD then
      fp = io.open(fileBD, "w")
      if fp then
	 print("writing", fileBD)
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
end


local function loop()
   local idx, sensor, value, sample
   local timeNow
   
   
   for i=1,2,1 do
      for j=1,nSens[tele[i].screen],1 do
	 timeNow = system.getTimeCounter()
	 idx = tele[i].sensor[j]
	 if idx > 1 then
	    sensor = system.getSensorByID(sensorIdlist[idx], sensorPalist[idx])
	    if sensor and sensor.valid then
	       value = sensor.value
	       tele[i].sensorValue[j] = value
	       if timeNow >= tele[i].sensorChartLast[j] + tele[i].sensorChartTime[j] then
		  sample = true
		  tele[i].sensorChartLast[j] = timeNow
	       end 
	       if sample and tele[i].sensorStyle[j] == 4 then
		  if #tele[i].sensorSample[j] + 1 > MAXSAMPLE then
		     table.remove(tele[i].sensorSample[j], 1)
		  end
		  table.insert(tele[i].sensorSample[j], value)
		  sample = false
		  --print("insert", #tele[i].sensorSample[j], value)
	       end
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
   loopCPU = system.getCPU()
   sample = false
end

local function init()

   local pf
   local mn
   local file
   local decoded
   local jsnVersion = 4
   
   emFlag = select(2, system.getDeviceType()) == 1
   if emFlag then pf = "" else pf = "/" end
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fileBD = pf .. "Apps/DFM-Dial/DD_" .. mn .. ".jsn"

   file = io.readall(fileBD)

   if file then
      decoded = json.decode(file)
      tele = decoded.tele
   end
   
   if not file or tele[1].jsnVersion ~= jsnVersion then
      if not file then
	 system.messageBox("No Model data read: initializing")
	 print("No Model data read: initializing")
      else
	 system.messageBox("Old data format: re-initializing")
	 print("Old data format: re-initializing")
      end
      
      --
      -- DON'T FORGET to update jsnVersion when changing the format of tele{} data!
      --
      
      for i=1,2,1 do
	 tele[i] = {}
	 tele[i].jsnVersion = jsnVersion
	 tele[i].screen = 1 -- default to double tele window (one value)
	 tele[i].sensor = {}
	 tele[i].sensorMin = {}
	 tele[i].sensorMinMult = {}	 
	 tele[i].sensorMax = {}
	 tele[i].sensorMaxMult = {}
	 tele[i].sensorStyle = {}
	 tele[i].sensorValue = {}
	 tele[i].sensorVmin = {}
	 tele[i].sensorVmax = {}
	 tele[i].sensorSample = {}
	 tele[i].sensorChartTime = {}
	 tele[i].sensorChartLast = {}
	 for j=1,4,1 do
	    tele[i].sensor[j] = 1 -- default to "..."
	    tele[i].sensorMin[j] = 0
	    tele[i].sensorMinMult[j] = 1	    
	    tele[i].sensorMax[j] = 10
	    tele[i].sensorMaxMult[j] = 1    
	    tele[i].sensorStyle[j] = 1 -- default to Arc
	    tele[i].sensorSample[j] = {}
	    tele[i].sensorChartTime[j] = 800
	    tele[i].sensorChartLast[j] = 0
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
   
   readSensors()
   
   system.registerForm(1, MENU_APPS, "Dial Display", initForm, keyForm)

   for i=1,2,1 do
      local ii, str
      if tele[i].screen == 1 then
	 ii = 2
	 if tele[i].sensor[1] > 1 then
	    str = string.format("%d) ", i) .. sensorLslist[tele[i].sensor[1]] ..
	       " (" .. sensorUnlist[tele[i].sensor[1]] .. ") " ..
	       string.format("  [%.1f-%.1f]", tele[i].sensorMin[1], tele[i].sensorMax[1])
	 else
	    str = string.format("Dial Window %d - %s", i, teleSelect[tele[i].screen])
	 end
      else
	 ii = 4
	 str = string.format("Dial Window %d - %s", i, teleSelect[tele[i].screen])
      end
      system.registerTelemetry(i, str, ii,
			       (function(x,y) return dialPrint(x,y,i) end))
   end
   
   
   setLanguage()

   print("DFM-Dial: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=DialVersion, name="Dial Display", destroy=writeTele}
