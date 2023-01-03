--[[
   ----------------------------------------------------------------------
   DFM-Dial.lua released under MIT license by DFM 2022
   ----------------------------------------------------------------------
   
--]]

--local trans11
local DialVersion = "1.0"

local runningTime = 0
local startTime = 0
local remainingTime
local subForm = 0
local emFlag
   
local fileBD
local writeBD = true
local loopCPU = 0
local lcdBG
local mmAdd

local sensorLalist = { "..." }  -- sensor labels (long)
local sensorLslist = { "..." }  -- sensor labels (short)
local sensorIdlist = { "..." }  -- sensor IDs
local sensorPalist = { "..." }  -- sensor parameters
local sensorUnlist = { "..." }  -- sensor units

local txSel =  {"rx1Percent", "rx1Voltage", "rx2Percent", "rx2Voltage", "rxBPercent", "rxBVoltage"}
local txRSSI = {"rx1-A1", "rx1-A2", "rx2-A1", "rx2-A2", "rxB-A1", "rxB-A2"}
local txUnit = {"%",          "V",          "%",          "V",          "V",          "%"}

local tele = {}

local nSens = {1,2,3,3,4,4}

local teleSelect = {"Double (1)", "Full Screen (2)", "Full Screen (3R)",
		    "Full Screen (3L)", "Full Screen (4)", "Full Screen Chart (4)"}

local chartTime = {"0:30", "1:00", "2:00", "4:00", "8:00"}

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
local savedRow3

local minWarn
local maxWarn

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


local function readSensors()

   local sensorLbl = "***"
   
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

   sensorLbl = "txTel"

   for i, sensor in ipairs(txSel) do
      table.insert(sensorLslist, sensor) -- .. "[" .. ii .. "]")
      table.insert(sensorLalist, sensorLbl .. "-> " .. sensor) -- .. "["..ii.."]")
      table.insert(sensorIdlist, 0)
      table.insert(sensorPalist, 0)
      table.insert(sensorUnlist, txUnit[i])
   end

   sensorLbl = "RSSI"
   
   for i, sensor in ipairs(txRSSI) do
      table.insert(sensorLslist, sensor) -- .. "[" .. ii .. "]")
      table.insert(sensorLalist, sensorLbl .. "-> " .. sensor) -- .. "["..ii.."]")
      table.insert(sensorIdlist, 0)
      table.insert(sensorPalist, i)
      table.insert(sensorUnlist, "")
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

local function drawRectGaugeAbs(oxc, oyc, w, h, min, max, hmin, hmax, val, str)

   local d, d1, d2
   local txt
   local font = FONT_BIG

   if not val then return end
   
   lcd.setColor(lcd.getFgColor())
   lcd.drawRectangle(oxc-w//2, oyc-h//2, w, h)
   d = math.max(math.min((val/(max-min))*w, w), 0)
   lcd.drawFilledRectangle(oxc-w//2, oyc-h//2, d, h)
   d1 = math.max(math.min((hmin/(max-min))*w, w), 0)
   d2 = math.max(math.min((hmax/(max-min))*w, w), 0)   
   lcd.setColor(lcd.getBgColor())
   lcd.drawFilledRectangle(oxc-w//2+ d1-1, oyc-h//2, 2, h)
   lcd.setColor(lcd.getFgColor())
   lcd.drawFilledRectangle(oxc-w//2+ d2-1, oyc-h//2, 2, h)
   
   if str then
      txt = str .. string.format("%.0f%%", val)
      lcd.setColor(255,255,255)
      -- note clipping changes coord system to the area inside the clip region
      lcd.setClipping(oxc-w/2, 0, d, 160)
      lcd.drawText(oxc - lcd.getTextWidth(font, txt) / 2 - (oxc - w//2),
		   oyc - lcd.getTextHeight(font) / 2,
		   txt, font)
      lcd.setClipping(oxc -w/2 + d, 0, w-d, 160) 
      lcd.setColor(lcd.getFgColor())
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
   lcd.setColor(200,200,200)
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

local function drawChart(x0, xl, y0, yl, min, max, val, rgb)
   local ren = lcd.renderer()
   local px, py, vv
   local px1, py1
   local xm
   if not val or #val < 1 then return end
   if xl >= 200 then xm = 2 else xm = 1 end
   lcd.setColor(table.unpack(rgb))
   ren:reset()
   local np = 0
   for i=#val,1,-1 do
      px = x0+xm*i
      vv = val[i]
      if vv > max then vv = max end
      if vv < min then vv = min end
      py = y0 + yl * (1 - (vv-min)/(max-min))
      if not px1 then px1 = px end
      if not py1 then py1 = py end
      if np < 127 then
	 ren:addPoint(px, py)
	 np = np + 1
      else
	 ren:addPoint(px, py)
	 ren:renderPolyline(2)
	 ren:reset()
	 ren:addPoint(px, py)
	 np = 1
      end
   end
   --if px1 and py1 then
   --   lcd.drawText(8,140, string.format("%3d %3d", px1, py1), FONT_MINI)
   --end
   ren:renderPolyline(2)
end

local function drawMaxMin(hmax, hmin, wmax, wmin, max, min, x0, y0, a0, aR, ri, ro)
   local ratio
   local theta
   local ren = lcd.renderer()
   local dr = (ro - ri) / 2

   if not hmax or not hmin then return end
   
   ren:reset()
   ratio = (hmax-min)/(max-min)
   ratio = math.max(math.min(ratio, 1), 0)
   theta = aR * ratio
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   lcd.setColor(lcd.getFgColor())
   ren:renderPolyline(3)

   if wmax and wmax <= max then
      ren:reset()
      ratio = (wmax-min)/(max-min)
      ratio = math.max(math.min(ratio, 1), 0)
      theta = aR * ratio
      ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
      ren:addPoint(x0 - (ri+dr) * math.cos(a0+theta), y0 - (ri+dr) * math.sin(a0+theta))
      lcd.setColor(lcd.getFgColor())
      ren:renderPolyline(3)
   end

   ren:reset()
   ratio = (hmin-min)/(max-min)
   ratio = math.max(math.min(ratio, 1), 0)
   theta = aR * ratio
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   lcd.setColor(lcd.getBgColor())
   ren:renderPolyline(3)

   if wmin and wmin >= min then
      ren:reset()
      ratio = (wmin-min)/(max-min)
      ratio = math.max(math.min(ratio, 1), 0)
      theta = aR * ratio
      ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
      ren:addPoint(x0 - (ri+dr) * math.cos(a0+theta), y0 - (ri+dr) * math.sin(a0+theta))
      lcd.setColor(lcd.getBgColor())
      ren:renderPolyline(3)
   end

end

local function formatD(vv)
   local suffix
   local val
   if not vv then return "---" end
   val = vv
   if math.abs(val) > 1000 then
      val = val / 1000
      suffix = "k"
   else
      suffix = ""
   end
   if math.abs(val) > 1000 then
      return string.format("%.0f", val) .. suffix
   elseif math.abs(val) > 100 then
      return string.format("%.1f", val) .. suffix
   else
      return string.format("%.2f", val) .. suffix
   end
end

local function formatE(vv)
   local suffix
   local val
   if not vv then return "---" end   
   val = vv
   if math.abs(val) > 1000 then
      val = val / 1000
      suffix = "k"
   else
      suffix = ""
   end
   return string.format("%.1f", val) .. suffix
end

local function dialPrint(w,h,win)

   local theta
   local a0d = -35
   local a0 = math.rad(a0d)
   local aRd = -a0d*2 + 180
   local aR = math.rad(aRd)

   local wmin, wmax

   local x0 = { {40}, {80,237}, {50,50,236}, {80,201,201}, {50,201,50,201},  {150,150,150,150}} -- 50
   local y0 = { {34}, {96,96},  {44,123,96}, {96,44,123},  {44,44,123,123},  {96,96,96,96}}  -- 44 
   local ro = { {32}, {62,62},  {32,32,62},  {62,32,32},   {32,32,32,32},    {62,62,62,62}}
   local ri = { {20}, {44,44},  {20,20,44},  {44,20,20},   {20,20,20,20},    {44,44,44,44}}

   local rx = { {0}, {5,161}, {5,5,161}, {5,161,161}, {5,161,5,161}, {8,8,8,8}}   
   local ry = { {0}, {10,10}, {10,89,10}, {10,10,89}, {10,10,89,89}, {20,20,20,20}}   

   local rxs = { {151}, {151,151}, {151,151,151}, {151,151,151}, {151,151,151,151}, {302,302,302,302}}
   local rys = { {69},  {148,148}, {69,69,148},   {148,69,69},   {69,69,69,69},     {138,138,138,138}}

   local rgbC
   rgbC = { {0,20,255}, {150,20,0}, {255,155,0}, {0,150,0} }	 

   -- put this here instead of init in case pilot changes colors while app running
   
   local rb, gb, bb = lcd.getBgColor()

   if rb == 0 and gb == 0 and bb == 0 then
      lcdBG = "D"
   else
      lcdBG = "L"
   end
      
   local ratio, theta, val, max, min, xz, yz, rI, rO, ovld, sg, np
   
   for i=1, nSens[tele[win].screen],1 do
      val = tele[win].sensorValue[i]
      if tele[win].sensor[i] > 1 then
	 --if not val then print("val nil", win, i) return end
	 min = tele[win].sensorMin[i] * tele[win].sensorMinMult[i]
	 max = tele[win].sensorMax[i] * tele[win].sensorMaxMult[i]
	 if val then
	    if val > max or val < min then ovld = true else ovld = false end
	 else
	    ovld = false
	 end
	 if val and tele[win].sensorMinWarn[i] then
	    if type(tele[win].sensorMinWarn[i]) == "number" then -- look for "arith with userdata" bug
	       --print(win,i)
	       wmin = tele[win].sensorMinWarn[i] * tele[win].sensorMinMult[i]
	    else
	       --print("not number type min", win, i)
	       wmin = val
	    end
	    if val < wmin then ovld = true end
	 end
	 if val and tele[win].sensorMaxWarn[i] then
	    if type(tele[win].sensorMaxWarn[i]) == "number" then
	       wmax = tele[win].sensorMaxWarn[i] * tele[win].sensorMaxMult[i]
	    else
	       --print("not number type max", win, i)
	       wmax = val
	    end
	    if val > wmax then ovld = true end
	 end
	 if val then
	    ratio = (val-min)/(max-min)
	 else
	    ratio = 0
	 end
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
	 
	 local text, f1, f2, y1, y2, y3, y4, x0, x1, x2, x3, bh, bw, ss
	 
	 ss = tele[win].sensorStyle[i]
	 
	 if ss < 3 then --Arc, Needle
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
	       if rxs[tele[win].screen][i] < 152 then
		  f1 = FONT_MAXI
		  f2 = FONT_BIG
		  y1 = 24
		  y2 = 85
		  y3 = 85
		  x0 = 0
		  x1 = 40
		  x2 = -40
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
	    end
	 else -- Bargraph, Chart
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
	       x3 = 35
	       bw = 140
	       bh = 34
	    else
	       if rxs[tele[win].screen][i] < 152 then
		  f1 = FONT_MAXI
		  f2 = FONT_BIG
		  y1 = 24
		  y2 = 85
		  y3 = 85
		  y4 = -10
		  x0 = 3
		  x1 = 45
		  x2 = -45
		  x3 = 0
		  bw = 140
		  bh = 42
	       else
		  f1 = FONT_MAXI
		  f2 = FONT_BIG
		  y1 = 24
		  y2 = 85
		  y3 = 85
		  y4 = -10
		  x0 = 5
		  x1 = 50
		  x2 = -40
		  x3 = 10
		  bw = 280
		  bh = 52
	       end
	    end
	 end
	 
	 if tele[win].screen > 1 then
	    if tele[win].screen ~= 6 then
	       lcd.setColor(160,160,160)
	       lcd.drawRectangle(rx[tele[win].screen][i], ry[tele[win].screen][i],
				 rxs[tele[win].screen][i],rys[tele[win].screen][i])
	    else
	       if i == 1 then
		  lcd.setColor(230,230,230)
		  lcd.drawFilledRectangle(rx[tele[win].screen][i], ry[tele[win].screen][i],
					  rxs[tele[win].screen][i],rys[tele[win].screen][i])
	       end
	    end
	 end
	 
	 if tele[win].sensorStyle[i] == 1 then --Arc
	    drawBackArc(xz, yz, a0, aR, rI, rO, sg, 1)
	    drawArc(theta, xz, yz, a0, aR, rI, rO, sg, 1)
	    drawMaxMin(tele[win].sensorVmax[i], tele[win].sensorVmin[i],
		       tele[win].sensorMaxWarn[i], tele[win].sensorMinWarn[i],
		       max, min, xz, yz, a0, aR, rI, rO)
	 elseif tele[win].sensorStyle[i] == 2 then --Dial
	    drawBackArc(xz, yz, a0, aR, rI, rO, sg, 1)
	    lcd.setColor(lcd.getFgColor())
	    drawShape(xz,yz, np, theta - math.pi - aR/2)
	    drawMaxMin(tele[win].sensorVmax[i], tele[win].sensorVmin[i],
		       tele[win].sensorMaxWarn[i], tele[win].sensorMinWarn[i],
		       max, min, xz, yz, a0, aR, rI, rO)
	 elseif tele[win].sensorStyle[i] == 3 then --HBar
	    local v1, v2, v3
	    v1 = ( (tele[win].sensorVmin[i] or 0) - min)/(max-min)*100
	    v2 = ( (tele[win].sensorVmax[i] or 0)- min)/(max-min)*100
	    if val then v3 = (val-min)/(max-min)*100 else v3 = 0 end
	    drawRectGaugeAbs(xz+x3, yz+y4, bw, bh, 0, 100, v1, v2, v3, "")
	 elseif tele[win].sensorStyle[i] == 4 then --Chart
	    drawChart(rx[tele[win].screen][i], rxs[tele[win].screen][i],
		      ry[tele[win].screen][i], rys[tele[win].screen][i],
		      min, max, tele[win].sensorSample[i], rgbC[i])
	 end
	 
	 
	 if tele[win].screen ~= 6 then
	    if lcdBG == "D" then
	       lcd.setColor(255,255,255)
	    else
	       lcd.setColor(0,0,0)
	    end
	    
	    text = formatD(val)
	    if ovld then lcd.setColor(255,0,0) end 
	    lcd.drawText(xz + x0 - lcd.getTextWidth(f1, text) / 2, yz+y1, text, f1)
	    
	    if lcdBG == "D" then
	       lcd.setColor(255,255,255)
	    else
	       lcd.setColor(0,0,0)
	    end
	    
	    text = formatD(tele[win].sensorVmax[i])
	    lcd.drawText(xz + x1 - lcd.getTextWidth(f2, text)/2, yz - y2, text, f2)
	    text = formatD(tele[win].sensorVmin[i])
	    lcd.drawText(xz + x2 - lcd.getTextWidth(f2, text)/2, yz - y3, text, f2)
	    
	 end
	 
	 local xc0, yc0
	 local xc00 = {10, 160, 10, 160}
	 local yc00 = {-10, -10, 0, 0}
	 
	 if tele[win].screen == 6 then
	    xc0 = xc00[i]
	    yc0 = yc00[i]
	    lcd.setColor(table.unpack(rgbC[i]))
	    lcd.drawFilledRectangle(rx[tele[win].screen][i]+xc0-10, ry[tele[win].screen][i]-12+yc0+3, 8, 8)
	 else
	    xc0, yc0 = 0, 0
	 end
	 
	 
	 if lcdBG == "D" then
	    lcd.setColor(255,255,255)
	 else
	    lcd.setColor(0,0,0)
	 end
	 
	 local m1 = formatE(tele[win].sensorMin[i] * tele[win].sensorMinMult[i])
	 local m2 = formatE(tele[win].sensorMax[i] * tele[win].sensorMaxMult[i])
	 
	 lcd.drawText(rx[tele[win].screen][i] + xc0,
		      ry[tele[win].screen][i]-12 + yc0,
		      sensorLslist[tele[win].sensor[i]] ..
			 " (" .. sensorUnlist[tele[win].sensor[i]] .. ") " ..
			 "[" ..m1 .. "-" .. m2 .."]", FONT_MINI)
	 --string.format("  [%.1f-%.1f]",
	 --tele[win].sensorMin[i] * tele[win].sensorMinMult[i],
	 --tele[win].sensorMax[i] * tele[win].sensorMaxMult[i]),
	 --FONT_MINI)
	 
      end
      
   end
   
   if emFlag then
      lcd.setColor(0,0,0)
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
	 if mmAdd then
	    form.reinit(103)
	 else
	    form.reinit(13)
	 end
	 
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

   -- set all styles to chart for this window if chart selected
   if val == 6 then
      for j = 1, nSens[6],1 do
	 --print("setting style to 4: val, i, j", val, i, j)
	 tele[i].sensorStyle[j] = 4 -- Chart
      end
   end

   system.unregisterTelemetry(i)
   system.registerTelemetry(i, str, ii,
			    (function(x,y) return dialPrint(x,y,i) end))
end

local function teleSensorChanged(val,i,j)
   tele[i].sensor[j] = val
end

local function sensorMinChanged(val, i, j)
   tele[i].sensorMin[j] = val / 10.0
   if minWarn and not tele[i].sensorMinWarn[j] then
      form.setValue(minWarn, val)
   end
end

local function sensorMinWarnChanged(val, i, j)
   tele[i].sensorMinWarn[j] = val / 10.0
end

local function sensorMinMultChanged(val, i, j)
   tele[i].sensorMinMult[j] = 10^(val-1)
end

local function sensorMaxChanged(val, i, j)
   tele[i].sensorMax[j] = val / 10.0
   if maxWarn and not tele[i].sensorMaxWarn[j] then
      form.setValue(maxWarn, val)
   end
end

local function sensorMaxWarnChanged(val, i, j)
   tele[i].sensorMaxWarn[j] = val / 10.0
end

local function sensorMaxMultChanged(val, i, j)
   tele[i].sensorMaxMult[j] = 10^(val-1)
end

local function sensorStyleChanged(val, i, j)
   tele[i].sensorStyle[j] = val
end

local function sensorChartTimeChanged(val, i, j)
   if j == 1 then
      for k=1, nSens[tele[i].screen],1 do
	 tele[i].sensorChartTime[k] = 2^(val-1)*200
      end
   end
end

local function sensorSmoothChanged(val, i, j)
   tele[i].sensorChartSmooth[j] = val
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
      savedRow2 = 1
   elseif sf == 103 then
      local mm
      mmAdd = false
      form.setTitle("Edit sensor dial " .. sensorLslist[tele[savedRow].sensor[savedRow2]])
      
      form.addRow(2)
      form.addLabel({label="Style"})
      if tele[savedRow].screen ~= 6 then
	 form.addSelectbox({"Arc", "Needle", "Bar", "Chart"}, tele[savedRow].sensorStyle[savedRow2], true, 
	    (function(x) return sensorStyleChanged(x, savedRow, savedRow2) end))
      else
	 tele[savedRow].sensorStyle[savedRow2] = 4
	 form.addLabel({label="Chart", alignRight=true})
      end
      
      form.addRow(2)
      form.addLabel({label="Minimum displayed value", width=220})
      form.addIntbox(tele[savedRow].sensorMin[savedRow2]*10, -9999, 9999, 0, 1, 1,
		     (function(x) return sensorMinChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLabel({label="Minimum warning value", width=220})
      mm = tele[savedRow].sensorMinWarn[savedRow2]
      if not mm then mm = tele[savedRow].sensorMin[savedRow2] end 
      minWarn = form.addIntbox(mm*10, -9999, 9999, 0, 1, 1,
			       (function(x) return sensorMinWarnChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLabel({label="Minimum multiplier", width=220})
      
      mm = math.log(tele[savedRow].sensorMinMult[savedRow2])/math.log(10) + 1
      form.addSelectbox({"1x", "10x", "100x", "1000x"}, mm, true,
	 (function(x) return sensorMinMultChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLabel({label="Maximum displayed value", width=220})
      form.addIntbox(tele[savedRow].sensorMax[savedRow2]*10, -9999, 9999, 1000, 1, 1,
		     (function(x) return sensorMaxChanged(x, savedRow, savedRow2) end))
      
      mm = tele[savedRow].sensorMaxWarn[savedRow2]
      if not mm then mm = tele[savedRow].sensorMax[savedRow2] end 
      form.addRow(2)
      form.addLabel({label="Maximum warning value", width=220})
      maxWarn = form.addIntbox(mm*10, -9999, 9999, 0, 1, 1,
			       (function(x) return sensorMaxWarnChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLabel({label="Maximum multiplier", width=220})
      mm = math.log(tele[savedRow].sensorMaxMult[savedRow2])/math.log(10) + 1
      form.addSelectbox({"1x", "10x", "100x", "1000x"}, mm, true,
	 (function(x) return sensorMaxMultChanged(x, savedRow, savedRow2) end))
      
      if tele[savedRow].screen ~= 6 or savedRow2 == 1 then
	 form.addRow(2)
	 form.addLabel({label="Time span for Chart"})
	 local dt = math.log(tele[savedRow].sensorChartTime[savedRow2]/200) / math.log(2) + 1
	 if savedRow2 == 1 then
	    form.addSelectbox(chartTime,
			      dt, true, 
			      (function(x) return sensorChartTimeChanged(x, savedRow, savedRow2) end))
	 else
	    form.addLabel({label = chartTime[dt], alignRight = true})
	 end
      end
      
      form.addRow(2)
      form.addLabel({label="Smoothing value for Chart", width=220})
      form.addIntbox(tele[savedRow].sensorChartSmooth[savedRow2], 1, 1000, 1, 0, 1,
		     (function(x) return sensorSmoothChanged(x, savedRow, savedRow2) end))
      
      form.addRow(2)
      form.addLink((function()
	       tele[savedRow].sensorMinWarn[savedRow2] = nil
	       tele[savedRow].sensorMaxWarn[savedRow2] = nil
	       mmAdd = true
		   end), {label="Reset min/max warnings>>", width=220})
      
      if savedRow3 then
	 form.setFocusedRow(savedRow3)
	 savedRow3 = nil
      else
	 form.setFocusedRow(1)
      end
      
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
   local txTel
   
   if #sensorIdlist < 2 then return end
   
   for i=1,2,1 do
      for j=1,nSens[tele[i].screen],1 do
	 timeNow = system.getTimeCounter()
	 idx = tele[i].sensor[j]
	 if idx > 1 then
	    if sensorIdlist[idx] == 0 then
	       sensor = {}
	       txTel = system.getTxTelemetry()
	       if sensorPalist[idx] == 0 then
		  sensor.value = txTel[sensorLslist[idx]]
	       else
		  sensor.value = txTel.RSSI[sensorPalist[idx]]
	       end
	       sensor.unit = sensorUnlist[idx]
	       --the TX sends 0 for these params before the RX is on -- defend against that
	       if timeNow - startTime > 1000 then -- wait 1 sec
		  sensor.valid = true
	       else
		  sensor.valid = false
	       end
	       --[[
	       if sensor.unit == "V" and sensor.value > 1 then
		  sensor.valid = true
	       elseif sensor.value > 20 then -- % and "" for RSSI
		  sensor.valid = true
	       end
	       --]]
	    else
	       sensor = system.getSensorByID(sensorIdlist[idx], sensorPalist[idx])
	    end
	    if sensor and sensor.valid then
	       value = sensor.value
	       tele[i].sensorValue[j] = value
	       if timeNow >= tele[i].sensorChartLast[j] + tele[i].sensorChartTime[j] then
		  sample = true
		  tele[i].sensorChartLast[j] = timeNow
	       end 
	       if sample and tele[i].sensorStyle[j] == 4 then
		  if tele[i].sensorSample[j] and #tele[i].sensorSample[j] + 1 > MAXSAMPLE then
		     table.remove(tele[i].sensorSample[j], 1)
		  end
		  if tele[i].sensorSample[j] then
		     local ls = tele[i].sensorSample[j][#tele[i].sensorSample[j]]
		     if #tele[i].sensorSample[j] > 0 then
			value = ls + (value - ls) / tele[i].sensorChartSmooth[j]
		     end
		  end
		  table.insert(tele[i].sensorSample[j], value)
		  sample = false
	       end
	       if value then
		  if tele[i].sensorVmin[j] and tele[i].sensorVmax[j] then
		     if value and value < tele[i].sensorVmin[j] then tele[i].sensorVmin[j] = value end
		     if value and value > tele[i].sensorVmax[j] then tele[i].sensorVmax[j] = value end
		  else
		     tele[i].sensorVmin[j] = value
		     tele[i].sensorVmax[j] = value
		  end
	       else
		  print("Trying to assign a nil value")
	       end
	    end
	 end
      end
   end
   loopCPU = system.getCPU()
end

local function init()
   
   local pf
   local mn
   local file
   local decoded
   local jsnVersion = 6
   
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
	 tele[i].sensorChartSmooth = {}
	 tele[i].sensorMinWarn = {}
	 tele[i].sensorMaxWarn = {}
	 tele[i].sensorMinWarnDone = {}
	 tele[i].sensorMaxWarnDone = {}
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
	    tele[i].sensorChartSmooth[j] = 1
	    tele[i].sensorMinWarnDone[j] = false
	    tele[i].sensorMaxWarnDone[j] = false
	 end
      end
   end
   
   -- clear out the items we don't want to remember from last run
   for i=1,2,1 do
      for k,v in pairs(tele[i]) do
	 print("k,v", k,v)
	 if k == "sensorVmax" then print("sensorVmax", v, type(v)) end
	 if k == "sensorVmin" then print("sensorVmin", v, type(v)) end	 
	 if type(v) == "userdata" and tostring(v) == "userdata: (nil)" then
	    tele[i][k] = nil
	    print("Found and fixed [userdata: (nil)] at", i, k)
	 end
	 if type(v) == "table" then
	    for kk,vv in pairs(v) do
	       if type(vv) == "userdata" and tostring(vv) == "userdata: (nil)" then
		  v[kk] = nil
		  print("Found and fixed [userdata: (nil)] at", i, k, kk)
	       end
	    end
	 end
      end
      for j=1,4,1 do
	 tele[i].sensorVmin[j] = nil
	 tele[i].sensorVmax[j] = nil
	 tele[i].sensorChartLast[j] = 0
	 tele[i].sensorValue[j] = nil
	 tele[i].sensorMinWarnDone[j] = false
	 tele[i].sensorMaxWarnDone[j] = false
	 tele[i].sensorSample[j] = {}
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

   startTime = system.getTimeCounter()
   
   print("DFM-Dial: gcc " .. collectgarbage("count"))
   
end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=DialVersion, name="Dial Display", destroy=writeTele}
