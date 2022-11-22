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

local nfk = {type=1, shape=2, lat=1, lng=2,
	     selType={"Inside", "Outside"},  inside=1, outside=2,
	     selShape={"Circle", "Polygon"}, circle=1, polygon=2
}

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
--local zeroLatString
--local zeroLngString
local initPos
local curX, curY
local lastX, lastY
local heading
--local rotA
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
local needCalcXY = true
local maxPolyX = 0
local lastNoFly

local function writeJSON()
   local fp
   local save={}
   save.nfz = nfz
   save.settings = settings
   save.sens = sens
   if writeBD then
      fp = io.open(fileBD, "w")
      if fp then
	 --print("writing "..fileBD, #nfz)
	 --print(json.encode(save))
	 io.write(fp, json.encode(save), "\n") 
	 io.close(fp)
      end
   end
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
	 x,y = rotateXY(x, y, settings.rotA)
	 nfz[i].xy[j] = {x=x,y=y}
	 if x > maxPolyX then maxPolyX = x end
	 --print(i,j,x,y)
	 --print(#nfz[i].xy)
      end
   end
   needCalcXY = false
end

local function readSensors(tbl)
   local sensorLbl = "***"
   --print("readSensors")
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
	    --system.pSave("zeroLatString", zeroLatString)
	    --system.pSave("zeroLngString", zeroLngString)
	    clearPos()
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if curBear then
	    settings.rotA = math.rad(curBear-90)
	    --system.pSave("rotA", rotA*1000)
	    clearPos()
	 else
	    system.messageBox("No Current Position")
	 end
      end
   elseif subForm == 3 or subForm == 4 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
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
   end
end
   
local function zoneChanged(val, sel, i)
   if sel == nfk.type then
      nfz[i].type = val
   else
      nfz[i].shape = val
   end
   form.reinit(5)
end

local function radiusChanged(val, i)
   nfz[i].radius = val
end

local function telemChanged(val, stbl, v, ttbl)
   stbl[v].Se = val
   stbl[v].SeId = ttbl.Idlist[val]
   stbl[v].SePa = ttbl.Palist[val]
   --system.pSave(v.."Se",   stbl[v].Se)
   --system.pSave(v.."SeId", stbl[v].SeId)
   --system.pSave(v.."SePa", stbl[v].SePa)
end

local function pointChanged(val, sel, gp, i, ff)
   if sel == nfk.lat then
      gp[i].lat = val
   else
      gp[i].lng = val
   end
   form.reinit(ff)
end

local function initForm(sf)
   subForm = sf
   if sf == 1 then
      form.setTitle("GPS Display")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)

      form.addRow(2)
      form.addLabel({label="Telemetry >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(3)
	       form.waitForRelease()
      end))      

      --[[
      form.addRow(2)
      form.addLabel({label="Controls >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))
      --]]

      form.addRow(2)
      form.addLabel({label="No Fly Zones >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(5)
	       form.waitForRelease()
      end))
      
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
   elseif sf == 3 then
      if not telem then
	 telem = {
	    Lalist={"..."},
	    Idlist={"..."},
	    Palist={"..."}
	 }
	 readSensors(telem)
      end
      form.setTitle("Telemetry Sensors")
      for i in ipairs(sens) do
	 form.addRow(2)
	 form.addLabel({label=sens[i].label,width=140})
	 form.addSelectbox(telem.Lalist, sens[sens[i].var].Se, true,
			   (function(x) return telemChanged(x, sens, sens[i].var, telem) end),
			   {width=180, alignRight=false})
      end
      
   elseif sf == 4 then
      form.setTitle("Controls")
      for i in ipairs(ctl) do
	 form.addRow(2)
	 form.addLabel({label=ctl[i].label, width=220})
	 form.addInputbox(ctl[ctl[i].var], true, (function(x) return ctlChanged(x, ctl, ctl[i].var) end) )
      end
      --]]
   elseif sf == 5 then
      form.setTitle("No Fly Zones")
      --form.setButton(1, "Clear", 1)
      form.setButton(2, ":add", 1)
      form.setButton(3, ":edit", 1)
      form.setButton(4, ":delete", 1)
      if not nfz then
	 form.addRow(1)
	 form.addLabel({label="No No-Fly Zones"})
	 return
      end
      for i,z in ipairs(nfz) do
	 if nfz[i].shape == nfk.circle then
	    form.addRow(5)
	 else
	    form.addRow(3)
	 end
	 
	 form.addLabel({label=string.format("%d", i), width=20})
	 form.addSelectbox(nfk.selType,  nfz[i].type,  true,
			   (function(x) return zoneChanged(x, nfk.type, i)  end), {width=85})
	 form.addSelectbox(nfk.selShape, nfz[i].shape, true,
			   (function(x) return zoneChanged(x, nfk.shape, i) end), {width=85})
	 if nfz[i].shape == nfk.circle then
	    form.addLabel({label="Rad", width=50})
	    form.addIntbox((nfz[i].radius or 0), 0, 10000, 100, 0, 1,
	       (function(x) return radiusChanged(x, i) end), {width=60})
	 end
	 
      end
      if savedZone then form.setFocusedRow(savedZone) end
   elseif sf == 51 then
      form.setTitle("Edit Polygon No Fly Zone " .. savedZone)
      form.setButton(2, ":add", 1)
      if #nfz[savedZone].path == 0 then
	 for i=1,3,1 do
	    table.insert(nfz[savedZone].path, {lat=0,lng=0})
	    table.insert(nfz[savedZone].xy, {x=0,y=0})
	 end
      end

      for i,gpsP in ipairs(nfz[savedZone].path) do
	 form.addRow(5)
	 form.addLabel({label=string.format("%d", i), width=20})
	 local lat = string.format("%.6f", gpsP.lat)
	 local lng = string.format("%.6f", gpsP.lng)
	 form.addLabel({label="Lat", width=35})
	 form.addTextbox(lat, 10,
			 (function(x) return pointChanged(x, nfk.lat, nfz[savedZone].path, i, 51) end),
			 {width=110})
	 form.addLabel({label="Lng", width=35})
	 form.addTextbox(lng, 10,
			 (function(x) return pointChanged(x, nfk.lng, nfz[savedZone].path, i, 51) end),
			 {width=110})
      end
      form.setFocusedRow(1)
   elseif sf == 52 then
      form.setTitle("Edit Circle No Fly Zone " .. savedZone)
      if #nfz[savedZone].path == 0 then
	 table.insert(nfz[savedZone].path, {lat=0,lng=0})
	 table.insert(nfz[savedZone].xy, {x=0,y=0})
      end
      form.addRow(4)
      local lat = string.format("%.6f", nfz[savedZone].path[1].lat)
      local lng = string.format("%.6f", nfz[savedZone].path[1].lng)
      form.addLabel({label="Lat", width=35})
      form.addTextbox(lat, 10,
		      (function(x) return pointChanged(x, nfk.lat, nfz[savedZone].path, 1, 52) end),
		      {width=110})
      form.addLabel({label="Lng", width=35})
      form.addTextbox(lng, 10,
		      (function(x) return pointChanged(x, nfk.lng, nfz[savedZone].path, 1, 52) end),
		      {width=110})
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


local function loop()

   if not sens then return end
   
   local sensor
   sensor = system.getSensorByID(sens.alt.SeId, sens.alt.SePa)
   if sensor and sensor.valid then
      altitude = sensor.value
      altUnit = sensor.unit
   end
   
   sensor = system.getSensorByID(sens.spd.SeId, sens.spd.SePa)
   if sensor and sensor.valid then
      speed = sensor.value
      spdUnit = sensor.unit
   end
   
   curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)   

   if curPos and not initPos then gpsReads = gpsReads + 1 end
   
   if gpsReads > 9 then
      if not initPos then
	 initPos = curPos
	 if not zeroPos then zeroPos = curPos end
      end
      
      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)
      
      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))

      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, settings.rotA)

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


------------------------------------------------------------
local nLine = {
  {-72, 7, 30},  -- +30
  {-60, 3},      -- +25
  {-48, 7, 20},  -- +20
  {-36, 3},      -- +15
  {-24, 7, 10},  --  +10
  {-12 , 3},      --  +5
  {   0 , 7, 0},        --   0
  {12, 3},       --  -5
  {24, 7, -10}, -- -10
  {36, 3},      -- -15
  {48, 7, -20}, -- -20
  {60, 3},      -- -25
  {72, 7, -30}  -- -30
}

local function drawTape(x0, y0, xh, yh, tele, lbl, unit, onLeft)
   local delta = (tele or 0) % 10
   local deltaY = 1 + math.floor(2.4 * delta)
   local xoff
   local pMult
   local yoff = 0
   local xnum
   local xbox
   local yfh = lcd.getTextHeight(FONT_NORMAL)/2
   local text
   if onLeft then
      xoff = 27
      pMult = 1
      xnum = 0
      xbox = 0
   else
      xoff = 22
      pMult = -1
      xnum = xh/2+2
      xbox = 5
   end
   lcd.drawText(x0+xh/2-pMult*8-lcd.getTextWidth(FONT_MINI, lbl)/2, yh+4, lbl, FONT_MINI)
   lcd.drawText(x0+xh/2-pMult*8-lcd.getTextWidth(FONT_MINI, unit)/2, yh+14, unit, FONT_MINI)
   lcd.setClipping(x0,y0,xh,yh)
   lcd.drawLine(xoff, 0, xoff, yh)
   for _, line in pairs(nLine) do
      lcd.drawLine(xoff, line[1]+deltaY+yh/2+yoff, xoff+pMult*line[2], line[1]+deltaY+yh/2+yoff)
      if line[3] then
	 local dd = (tele or 0) + line[3] - delta
	 text = string.format("%d",dd)
	 if (dd >= 0.0) and (dd <= 1000.0) then
	    lcd.drawText(xnum + xoff - lcd.getTextWidth(FONT_NORMAL,text)-2, line[1]+deltaY+yh/2+yoff-yfh, text)
	 end
      end
   end
   text = string.format("%d", (tele or 0))
   lcd.setColor(255,255,255)
   lcd.drawFilledRectangle(xnum-xbox, yh/2 + yoff-yfh,28,lcd.getTextHeight(FONT_NORMAL))
   lcd.setColor(0,0,0)
   lcd.drawRectangle(xnum-xbox, yh/2 + yoff-yfh,28,lcd.getTextHeight(FONT_NORMAL))
   lcd.drawText(xnum+xoff - lcd.getTextWidth(FONT_NORMAL,text)-2, yh/2+yoff-yfh, text, FONT_NORMAL|FONT_XOR)
   lcd.resetClipping() 
end

local function mapTele()

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
      
      local txy = {x=curX,y=curY}
      local noFly
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
			      
      if noFly then
	 lcd.drawCircle(xp(curX), yp(curY), 4)
      else
	 drawShape(xp(curX), yp(curY), Glider, (heading or 0) )
      end
      
      if lastNoFly == nil then lastNoFly = noFly end
      if noFly and not lastNoFly then
	 system.playBeep(0, 600, 800)
      end
      if not noFly and lastNoFly then
	 system.playBeep(1, 1200, 400)
      end

      lastNoFly = noFly
      
      if savedXP and #savedXP > 1 then
	 for i=2,#savedXP do
	    lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
	 end
	 lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
      end
   end

   lcd.drawText(125, 145, string.format("[%dx%d]", xmax-xmin, ymax-ymin), FONT_MINI)
   
   lcd.drawLine(50,yp(0), 260, yp(0))

   if altitude then
      drawTape(0, 0, 50, 130, altitude, "Alt", "["..(altUnit or "---").."]", true)
   end
   if speed then
      drawTape(265, 0, 50, 130, speed, "Speed", "["..(spdUnit or "---").."]", false)
   end
   
end

local function printTele()

   local text, text2
   
   if subForm ~= 1 then return end
   text = string.format("Rot: %d  G: %d", math.deg(settings.rotA), gpsReads)
   lcd.drawText(210,120, text)
   if initPos then
      text, text2 = gps.getStrig(curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end

local function init()
   local emFlag, file
   local pf, mn
   local decoded
   
   emFlag = select(2, system.getDeviceType()) == 1
   if emFlag then pf = "" else pf = "/" end
   
   mn = string.gsub(system.getProperty("Model"), " ", "_")
   fileBD = pf .. "Apps/DFM-GPS/GG_" .. mn .. ".jsn"
   file = io.readall(fileBD)
   if file then
      decoded = json.decode(file)
      nfz = decoded.nfz
      settings = decoded.settings
      sens = decoded.sens
   end
   writeBD = true

   if not settings then
      settings = {}
      settings.rotA = 0
   end

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
   end
   
   --zeroLatString = system.pLoad("zeroLatString")
   --zeroLngString = system.pLoad("zeroLngString")
   --[[
   --]]
   --rotA = system.pLoad("rotA", 0)
   --rotA = rotA / 1000.0 -- rotA was saved as *1000 since it has to be an int
   
   if settings and settings.zeroLatString and settings.zeroLngString then
      zeroPos = gps.newPoint(settings.zeroLatString, settings.zeroLngString)
   end

   mapScaleIdx = 1
   xmin, xmax, ymin, ymax = setMapScale(mapScaleIdx)

   system.registerForm(1, MENU_APPS, "GPS", initForm, keyForm, printTele)
   system.registerTelemetry(1,"GPS Flight Display",4, mapTele)

   if emFlag then -- needed to jumpstart emulator
      telem = {
	 Lalist={"..."},
	 Idlist={"..."},
	 Palist={"..."}
      }
      readSensors(telem)
      telem = nil
   end

   print("DFM-GPS: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

collectgarbage()

return {init=init, loop=loop, author="DFM", version=GPSVersion, name="GPS", destroy=writeJSON}
