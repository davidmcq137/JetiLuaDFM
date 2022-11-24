--[[

   ----------------------------------------------------------------------------
   DFM-GPS.lua released under MIT license by DFM 2022

   Simple GPS display app .. no maps!

   drawTape() inspired by Jeti's Artificial Horizon app
   ----------------------------------------------------------------------------
   
--]]

local GPSVersion = "0.2"

local subForm = 0
--local emFlag

local telem
local sens
local settings
local nfz
local fields
local selField
local gpsCalA
local gpsCalB

   
local nfk = {type=1, shape=2, lat=1, lng=2,
	     selType={"Inside", "Outside"},  inside=1, outside=2,
	     selShape={"Circle", "Polygon"}, circle=1, polygon=2
}

local DT

--[[
local Prop = {
   {-1,-6},
   {-2,-2},
   {-11,-2},
   {-11,1},	
   {-2,2},	
   {-1,8},
   {-5,8}, 
   {-5,11},
   {5,11},
   {5,8},
   {1,8},
   {2,2},
   {11,1},
   {11,-2},
   {2,-2},
   {1,-6}
}
--]]

local Glider =  {
   {0,-7},
   {-1,-2},
   {-14,0},
   {-14,2},	
   {-1,2},	
   {-1,8},
   {-4,8},
   {-4,10},
   {0,10},
   {4,10},
   {4,8},
   {1,8},
   {1,2},
   {14,2},
   {14,0},
   {1,-2}
}

--[[
local Jet = {
   {0,-20},
   {-3,-6},
   {-10,0},
   {-10,2},
   {-2,2},
   {-2,4},
   {-6,8},
   {-6,10},
   {0,10},
   {6,10},
   {6,8},
   {2,4},
   {2,2},
   {10,2},
   {10,0},
   {3,-6}
}
--]]

local curDist
local curBear
local curPos
local zeroPos
local initPos
local curX, curY
local lastX, lastY
local heading
local savedPos = {}
local savedXP = {}
local savedYP = {}
local gpsReads = 0

local mapScale = {100, 250, 500, 750, 1000, 1500, 2000}
local mapScaleIdx
local xmin, xmax, ymin, ymax

local altitude
local altUnit
local speed
local spdUnit

local MAXSAVED=20

local savedRow, savedZone
local fileBD, writeBD
local fieldFn
local writeFld
local noFlyFn
local writeNoFly

local needCalcXY = true
local maxPolyX = 0
local lastNoFly

local function prefix()
   local emFlag
   local pf
   emFlag = select(2, system.getDeviceType()) == 1
   if emFlag then pf = "" else pf = "/" end
   return pf
end

local function fixKeys(tt)
   for k,v in pairs(tt) do
      if type(k) == "string" and tonumber(k) then
	 tt[tonumber(k)] = v
      end
   end
end

local function writeJSON()
   local fp
   local save={}
   if writeBD then
      save.settings = settings
      save.sens = sens
      fp = io.open(fileBD, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
   save = {}
   
   if writeNoFly then
      if zeroPos and gpsCalA then
	 nfz.lat, nfz.lng = gps.getValue(zeroPos)
      end
      if settings.rotA and gpsCalB then
	 nfz.rotation = settings.rotA
      end
      j=0
      for i,f in ipairs(fields) do
	 if f.short == selField then
	    nfz.longname = f.longname
	    break
	 end
      end
      print("sav#fields", #fields)
      print("noFlyFn", noFlyFn)
      save.nfz = nfz
      fp = io.open(noFlyFn, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n")
	 io.close(fp)
      end
   end
   --[[
   save = {}
   if writeFld then
      save.fields = fields
      fp = io.open(fieldFn, "w")
      if fp then
	 io.write(fp, json.encode(save), "\n")
	 io.close(fp)
      end
   end
   --]]
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

-- convert no fly polygon coords from lat,lng to x,y in current frame

local function noFlyCalc()
   local pt, cD, cB, x, y
   for i in ipairs(nfz) do
      for j in ipairs(nfz[i].path) do
	 pt = gps.newPoint(nfz[i].path[j].lat,nfz[i].path[j].lng)
	 cD = gps.getDistance(zeroPos, pt)
	 cB = gps.getBearing(zeroPos, pt)
	 x = cD * math.cos(math.rad(cB+270))
	 y = cD * math.sin(math.rad(cB+90))
	 x,y = rotateXY(x, y, (settings.rotA or 0))
	 nfz[i].xy[j] = {x=x,y=y}
	 if x > maxPolyX then maxPolyX = x end
      end
   end
   needCalcXY = false
end

local function readSensors(tbl)
   local sensorLbl = "***"
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    sensorLbl = sensor.label
	    table.insert(tbl.Lalist, "-->"..sensor.label)
	    table.insert(tbl.Idlist, 0)
	    table.insert(tbl.Palist, 0)
	 else
	    table.insert(tbl.Lalist, sensor.label)
	    --table.insert(tbl.Lalist, sensorLbl .. "-> " .. sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	 end
      end
   end
end

local function clearPos()
   savedPos = {}
   savedXP = {}
   savedYP = {}
end

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      return true
   else
      return false
   end
end

local function keyForm(key)
   if subForm == 1 then
      if key == KEY_1 then
	 if initPos then
	    zeroPos = curPos
	    settings.zeroLatString, settings.zeroLngString = gps.getStrig(zeroPos)
	    clearPos()
	    gpsCalA = true
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if curBear then
	    settings.rotA = math.rad(curBear-90)
	    clearPos()
	    gpsCalB = true
	 else
	    system.messageBox("No Current Position")
	 end
      end
   elseif subForm == 3 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   elseif subForm == 4 then
      savedZone = form.getFocusedRow()
      if key == KEY_2 then
	 if not fields then fields={} end
	 local lat, lng = gps.getValue(curPos)
	 print("lat,lng", lat, lng)
	 table.insert(fields, {short="NewField", longname="New Field Name", lat=lat, lng=lng, rotation=0})
	 form.reinit(4)
      elseif key == KEY_4 then
	 table.remove(fields, savedZone)
	 form.reinit(4)
      end
   elseif subForm == 5 then
      if keyExit(key) then
	 form.preventDefault()
	 needCalcXY = true
	 form.reinit(1)
	 return
      end
      savedZone = form.getFocusedRow()
      if key == KEY_2 then -- add
	 if not nfz then nfz = {} end
	 table.insert(nfz, {shape=nfk.polygon, type=nfk.inside, radius=0, path={}, xy={}})
	 needCalcXY = true
	 form.reinit(5)
      elseif key == KEY_3 then --edit
	 if not nfz or #nfz < 1 then return end
	 if nfz[savedZone].shape == nfk.polygon then
	    form.reinit(51)
	 else
	    form.reinit(52)
	 end
      elseif key == KEY_4 then --delete
	 table.remove(nfz, savedZone)
	 needCalcXY = true
	 form.reinit(5)
      end
   elseif subForm == 51 then
      if keyExit(key) then
	 form.preventDefault()
	 needCalcXY = true
	 form.reinit(5)
	 return
      end
      if key == KEY_2 then
	 table.insert(nfz[savedZone].path, {lat=0,lng=0})
	 table.insert(nfz[savedZone].xy, {x=0,y=0})
	 needCalcXY = true
	 form.reinit(51)
      end
   elseif subForm == 52 then
      if keyExit(key) then
	 form.preventDefault()
	 needCalcXY = true
	 form.reinit(5)
	 return
      end
      if key == KEY_2 then
	 table.insert(nfz[savedZone].path, {lat=0,lng=0})
	 table.insert(nfz[savedZone].xy, {x=0,y=0})
	 needCalcXY = true
	 form.reinit(52)
      end
   end
end

local function initForm(sf)
   subForm = sf
   collectgarbage()
   print("sF) DFM-GPS: gcc " .. collectgarbage("count"))
   if sf == 1 then
      local M = require "DFM-GPS/mainMenuCmd"
      savedRow = M.mainMenu(savedRow)
      M = nil
      collectgarbage()
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
   elseif sf == 3 then
      local M = require "DFM-GPS/selTeleCmd"
      savedRow = M.selTele(telem, sens, readSensors, savedRow)
      M = nil
      collectgarbage()
   elseif sf == 4 then
      local M  = require "DFM-GPS/selFieldCmd"
      savedRow = M.selField(fields, savedRow)
      M = nil
      collectgarbage()
   elseif sf == 5 then
      local M = require "DFM-GPS/noFlyCmd"
      M.noFly(nfk, nfz, savedZone)
      M = nil
      collectgarbage()
   elseif sf == 51 then
      local M = require "DFM-GPS/polyPtCmd"
      M.polyPt(nfk, nfz, savedZone)
      M = nil
      collectgarbage()
   elseif sf == 52 then
      local M = require "DFM-GPS/circPtCmd"
      M.circPt(nfk, nfz, savedZone)
      M = nil
      collectgarbage()
   elseif sf == 6 then
      print("removing", fileBD)
      io.remove(fileBD)
      writeBD = false
      --print("removing", fieldFn)
      --io.remove(fieldFn)
      --writeFld = false
      --io.remove(noFlyFn) --really should delete them all...
      system.messageBox("App data deleted .. restart App")
      form.reinit(1)
   end
end

local function setMapScale(s)
   local mm = mapScale[s]
   return -mm, mm, -0.5*mm/2, 1.5*mm/2
end

local function drawShape(col, row, shape, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   for i, _ in pairs(shape) do
      if i < #shape then
	 lcd.drawLine(
	    col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	    row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5),
	    col + (shape[i+1][1]*cosShape - shape[i+1][2]*sinShape + 0.5),
	    row + (shape[i+1][1] * sinShape + shape[i+1][2] * cosShape + 0.5)	    
	 )
      end
   end
   lcd.drawLine(
      col + (shape[#shape][1]*cosShape - shape[#shape][2]*sinShape + 0.5),
      row + (shape[#shape][1] * sinShape + shape[#shape][2] * cosShape + 0.5),
      col + (shape[1][1]*cosShape - shape[1][2]*sinShape + 0.5),
      row + (shape[1][1] * sinShape + shape[1][2] * cosShape + 0.5)
   )

end

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function keyGPS(key)
   local file
   local decoded
   
   if key == KEY_5 or key == KEY_ENTER then
      form.preventDefault()
      selField = fields[form.getFocusedRow()].short
      print("selField", selField)
      noFlyFn = prefix().."Apps/DFM-GPS/FF_"..selField..".jsn"
      file = io.readall(noFlyFn)
      if file then
	 decoded = json.decode(file)
	 nfz = decoded.nfz
      end
      fixKeys(nfz)
      print("#nfz", #nfz)
      writeNoFly = true
      if zeroPos then
	 nfz.lat, nfz.lng = gps.getValue(zeroPos)
	 if nfz.lat and nfz.lng then gpsCalA = true else gpsCalA = false end
      end
      if settings.rotA then
	 nfz.rotation = settings.rotA
	 if nfz.rotation then gpsCalB = true else gpsCalB = false end
      end
      form.close(2)
   elseif key == KEY_ESC then
      form.preventDefault()
      selField = ""
      form.close(2)
   elseif key == KEY_2 then
      if not fields then fields={} end
      table.insert(fields, {short="NewField", longname="New Field Name"})
      print("k2#fields", #fields)
      gpsCalA = false
      gpsCalB = false
      form.reinit(1)
   elseif key == KEY_4 then
      table.remove(fields, form.getFocusedRow())
      form.reinit(1)
   end
end

local function initGPS()
   form.setTitle("DFM-GPS Field Selection")
   local M = require "DFM-GPS/selFieldCmd"
   M.selField(fields)
   M = nil
   collectgarbage()
end

local function loadDT()
   DT = require "DFM-GPS/drawTape"
end

local function loop()

   if not sens then return end
   
   local sensor
   sensor = system.getSensorByID(sens.alt.SeId, sens.alt.SePa)
   if sensor and sensor.valid then
      altitude = sensor.value
      altUnit = sensor.unit
      if not DT then loadDT() end
   end
   
   sensor = system.getSensorByID(sens.spd.SeId, sens.spd.SePa)
   if sensor and sensor.valid then
      speed = sensor.value
      spdUnit = sensor.unit
      if not DT then loadDT() end
   end
   
   curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)   

   if curPos and not initPos then gpsReads = gpsReads + 1 end
   
   if gpsReads > 9 then
      if not initPos then
	 initPos = curPos
	 if not zeroPos then zeroPos = curPos end
	 system.registerForm(2, 0, "DFM-GPS Field Selection", initGPS, keyGPS)
      end

      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))

      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, settings.rotA or 0)

      local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)
      
      if curX ~= lastX or curY ~= lastY then -- and dist > 5 then -- new point
	 heading = math.atan(curX-lastX, curY - lastY)
	 if #savedPos+1 > MAXSAVED then
	    table.remove(savedPos, 1)
	    table.remove(savedXP, 1)
	    table.remove(savedYP, 1)
	 else
	    table.insert(savedPos, curPos)
	    table.insert(savedXP, xp(curX))
	    table.insert(savedYP, yp(curY))
	 end
	 lastX = curX
	 lastY = curY
      end
      
   end
end
------------------------------------------------------------


-- next set of function acknowledge
-- https://www.geeksforgeeks.org/how-to-check-if-a-given-point-lies-inside-a-polygon/
-- ported to lua D McQ 7/2020

local function onSegment(p, q, r)
   if (q.x <= math.max(p.x, r.x) and q.x >= math.min(p.x, r.x) and 
            q.y <= math.max(p.y, r.y) and q.y >= math.min(p.y, r.y)) then
      return true
   else
      return false
   end
end

-- To find orientation of ordered triplet (p, q, r). 
-- The function returns following values 
-- 0 --> p, q and r are colinear 
-- 1 --> Clockwise 
-- 2 --> Counterclockwise 
local function orientation(p, q, r) 
   local val
   val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
   if (val == 0) then return 0 end  -- colinear 
   return val > 0 and 1 or 2
end

-- The function that returns true if line segment 'p1q1' 
-- and 'p2q2' intersect. 
local function doIntersect(p1, q1, p2, q2) 
   -- Find the four orientations needed for general and 
   -- special cases
   local o1, o2, o3, o4
   o1 = orientation(p1, q1, p2)
   o2 = orientation(p1, q1, q2) 
   o3 = orientation(p2, q2, p1) 
   o4 = orientation(p2, q2, q1) 
   
   -- General case 
   if (o1 ~= o2 and o3 ~= o4) then return true end
   
   -- Special Cases 
   -- p1, q1 and p2 are colinear and p2 lies on segment p1q1 
   if (o1 == 0 and onSegment(p1, p2, q1)) then return true end
   
   -- p1, q1 and p2 are colinear and q2 lies on segment p1q1 
   if (o2 == 0 and onSegment(p1, q2, q1)) then return true end
  
   -- p2, q2 and p1 are colinear and p1 lies on segment p2q2 
   if (o3 == 0 and onSegment(p2, p1, q2)) then return true end
  
   -- p2, q2 and q1 are colinear and q1 lies on segment p2q2 
   if (o4 == 0 and onSegment(p2, q1, q2)) then return true end 
  
    return false -- Doesn't fall in any of the above cases 
end

local function isNoFlyC(nn, p)
   local d
   d = math.sqrt( (nn.xy[1].x-p.x)^2 + (nn.xy[1].y-p.y)^2)
   if nn.type == nfk.inside then
      if d <= nn.radius then return true end
   else
      if d >= nn.radius then return true end
   end
   return false
end

-- Returns true if the point p lies inside the polygon[] with n vertices 

local function isNoFlyP(nn,p) 

   local isInside
   local next
   local extreme

   -- There must be at least 3 vertices in polygon[]

   if (#nn.xy < 3)  then return false end

   --first see if we are inside the bounding circle
   --if so, isInside is false .. jump to end
   --else run full algorithm

   if false then --((p.x - nn.xc) * (p.x - nn.xc) + (p.y - nn.yc) * (p.y - nn.yc)) > nn.r2 then
      isInside = false
   else
      --Create a point for line segment from p to infinite 
      extreme = {x=2*maxPolyX, y=p.y}; 
      
      -- Count intersections of the above line with sides of polygon 
      local count = 0
      local i = 1
      local n = #nn.xy
      
      repeat
	 next = i % n + 1
	 if (doIntersect(nn.xy[i], nn.xy[next], p, extreme)) then 
	    -- If the point 'p' is colinear with line segment 'i-next', 
	    -- then check if it lies on segment. If it lies, return true, 
	    -- otherwise false 
	    if (orientation(nn.xy[i], p, nn.xy[next]) == 0) then 
	       return onSegment(nn.xy[i], p, nn.xy[next])
	    end
	    count = count + 1 
	 end
	 
	 i = next
      until (i == 1)
      
      -- Point inside polygon: true if count is odd, false otherwise
      isInside = (count % 2 == 1)
   end
   
   if nn.type == nfk.inside then
      return isInside
   else
      return not isInside
   end
end

local function mapTele()

   if not selField then
      lcd.drawText(0,10,"No Field Selected", FONT_BIG)
      return
   end
   
   if not gpsCalA then
      lcd.drawText(0,10,"GPS Point A not set", FONT_BIG)
      return
   end

   if not gpsCalB then
      lcd.drawText(0,10,"GPS Point B not set", FONT_BIG)
      return
   end
   
   if nfz and #nfz > 0 and zeroPos and nfz[1].xy then
      if needCalcXY then noFlyCalc() end
      for i in ipairs(nfz) do
	 if nfz[i].shape == nfk.polygon then
	    local n = #nfz[i].xy
	    if n > 3 then
	       for j=1,n-1 do
		  lcd.drawLine(xp(nfz[i].xy[j].x),yp(nfz[i].xy[j].y),xp(nfz[i].xy[j+1].x),yp(nfz[i].xy[j+1].y))
	       end
	       lcd.drawLine(xp(nfz[i].xy[n].x),yp(nfz[i].xy[n].y),xp(nfz[i].xy[1].x),yp(nfz[i].xy[1].y))
	    end
	 else
	    if nfz[i].xy and #nfz[i].xy > 0 then
	       lcd.drawCircle(xp(nfz[i].xy[1].x), yp(nfz[i].xy[1].y), 320*nfz[i].radius/(xmax-xmin))
	    end
	 end
      end
   end
   
   if curX and curY then

      if curX < xmin or curX > xmax or curY < ymin or curY > ymax then
	 if mapScaleIdx + 1 <= #mapScale then
	    mapScaleIdx = mapScaleIdx + 1
	    xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)
	    clearPos()
	 end
      end

      local noFly
      if nfz and #nfz > 0 then
	 local txy = {x=curX,y=curY}
	 local noFlyP = false
	 local noFlyC = false
	 for i in ipairs(nfz) do
	    if nfz[i].shape == nfk.polygon then
	       noFlyP = noFlyP or isNoFlyP(nfz[i], txy)
	    else
	       noFlyC = noFlyC or isNoFlyC(nfz[i], txy)
	    end
	 end
	 noFly = noFlyP or noFlyC
	 if lastNoFly == nil then lastNoFly = noFly end
	 if noFly and not lastNoFly then
	    system.playBeep(1, 1200, 800)
	 end
	 if not noFly and lastNoFly then
	    system.playBeep(0, 600, 400)
	 end
	 lastNoFly = noFly
      else
	 noFly = false
      end

      if noFly then
	 lcd.drawCircle(xp(curX), yp(curY), 4)
      else
	 drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      end
      
      if savedXP and #savedXP > 1 then
	 for i=2,#savedXP do
	    lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
	 end
	 lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
      end
   end

   lcd.drawText(125, 145, string.format("[%dx%d]", xmax-xmin, ymax-ymin), FONT_MINI)
   
   lcd.drawLine(50,yp(0), 260, yp(0))

   if altitude and DT then
      DT.drawTape(0, 0, 50, 130, altitude, "Alt", "["..(altUnit or "---").."]", true)
   end
   if speed and DT then
      DT.drawTape(265, 0, 50, 130, speed, "Speed", "["..(spdUnit or "---").."]", false)
   end
   
end

local function printTele()

   local text, text2
   
   if subForm ~= 1 then return end
   if settings.rotA then text = string.format("%d", math.deg(settings.rotA)) else text = "---" end
   text = string.format("Rot: %s  G: %d", text, gpsReads)
   lcd.drawText(210,120, text)
   if initPos then
      text, text2 = gps.getStrig(curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end

local function init()
   local file
   local mn
   local decoded
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fileBD = prefix() .. "Apps/DFM-GPS/GG_" .. mn .. ".jsn"
   file = io.readall(fileBD)
   --if file then print("GG_", file) end
   if file then
      decoded = json.decode(file)
      settings = decoded.settings
      sens = decoded.sens
   end
   writeBD = true

   fields = {}
   local dd, fn, ext
   local path = prefix().."Apps/DFM-GPS"
   for name, filetype, size in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      --print(dd, fn, ext)
      if fn and ext then
	 local i,j = string.find(fn, "FF_")
	 if string.lower(ext) == string.lower("jsn") and i == 1 then
	    local ff = path .. "/" .. fn .. "." .. ext
	    print(ff)
	    file = io.readall(ff)
	    if file then
	       decoded = json.decode(file)
	    end
	    local nn = string.sub(fn, j+1)
	    local tt = decoded.nfz
	    table.insert(fields, {short=nn, longname=tt.longname, lat=tt.lat, lng=tt.lng, rotation=tt.rotation})
	    print("tt.lat, tt.lng, tt.longname", tt.lat, tt.lng, tt.longname)
	 end
      end
   end

   --[[
   fieldFn = prefix().."Apps/DFM-GPS/Fields.jsn"
   file = io.readall(fieldFn)
   if file then print("Fields.jsn", file) end
   if file then
      decoded = json.decode(file)
      fields = decoded.fields
   end
   writeFld = true
   --]]
   
   if not sens then
      sens = {
	 {var="lat", label="Latitude"},
	 {var="lng", label="Longitude"},
	 {var="alt", label="Altitude"},
	 {var="spd", label="Speed"}
      }
      for i in ipairs(sens) do
	 local v = sens[i].var
	 if not sens[v] then sens[v] = {} end
	 sens[v].Se   = 0
	 sens[v].SeId = 0
	 sens[v].SePa = 0
      end
   else -- fix "1" instead of 1 for keys (json converter)
      fixKeys(sens)
   end
   
   gpsCalA = false
   gpsCalB = false

   if not settings then
      settings = {}
   end

   if settings and settings.zeroLatString and settings.zeroLngString then
      zeroPos = gps.newPoint(settings.zeroLatString, settings.zeroLngString)
      gpsCalA = true
   end

   if settings.rotA and gpsCalA then gpsCalB = true end

   mapScaleIdx = 1
   xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)

   system.registerForm(1, MENU_APPS, "GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"GPS Flight Display",4, mapTele)

   if select(2, system.getDeviceType()) == 1 then -- needed to jumpstart emulator
      telem = {
	 Lalist={"..."},
	 Idlist={"..."},
	 Palist={"..."}
      }
      readSensors(telem)
      telem = nil
   end

   selField = nil

   print("DFM-GPS: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="GPS", destroy=writeJSON}
