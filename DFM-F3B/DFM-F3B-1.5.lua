--[[

   ----------------------------------------------------------------------------
   DFM-F3B.lua released under MIT license by DFM 2022

   This app was originally created at the suggestion of Tim Bischoff. It is
   intended to facilitate practice flights for the new F3G electric glider
   competition

   This is the basic F3B version with minimal function per requirements 
   from Jeroen Smits
   ----------------------------------------------------------------------------
   
--]]

local F3BVersion = "1.5"

local telem = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

local sens = {
   {var="lat",  label="Latitude"},
   {var="lng",  label="Longitude"}
}

local ctl = {
   {var="arm", label="Arming"}
}

local distAB
local gpsScale

local flightZone
local lastFlightZone
local zone = {[0]=1,[1]=2,[3]=3}

local curDist
local curBear
local curPos
local zeroPos
local zeroLatString
local zeroLngString
local initPos
local curX, curY
local lastX, lastY
local rotA

local detA, detB
local dA, dB, dd
local perpA, perpB

local early = 0
local gotTelemetry, gotLast

local function readSensors(tbl)
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    table.insert(tbl.Lalist, ">> "..sensor.label)
	    table.insert(tbl.Idlist, 0)
	    table.insert(tbl.Palist, 0)
	 else
	    table.insert(tbl.Lalist, sensor.label)
	    table.insert(tbl.Idlist, sensor.id)
	    table.insert(tbl.Palist, sensor.param)
	 end
      end
   end
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function keyForm(key)
   if key == KEY_1 then
      zeroPos = curPos
      if zeroPos then
	 zeroLatString, zeroLngString = gps.getStrig(zeroPos)
      else
	 system.messageBox("No Current Position")
      end
   elseif key == KEY_2 then
      if curBear then
	 rotA = math.rad(curBear-90)
	 --system.pSave("rotA", rotA*1000)
	 gpsScale = 1.0
	 system.messageBox("GPS scale factor reset to 1.0")
      else
	 system.messageBox("No Current Position")
      end
   elseif key == KEY_4 then
      if gpsScale ~= 1.0 then
	 system.messageBox("Do DirB first")
	 return
      end
      if curX and curY then
	 gpsScale = 150.0/math.sqrt(curX^2 + curY^2)
      end
   end

   if zeroLatString and zeroLngString and rotA and gpsScale and (key >= KEY_1) and (key <= KEY_4) then
      local save = {}
      save.zeroLatString = zeroLatString
      save.zeroLngString = zeroLngString
      save.rotA = rotA * 1000
      save.gpsScale = gpsScale * 1000
      local fp = io.open(prefix() .. 'Apps/DFM-F3B/GPS.jsn', "w")
      if fp then
	 io.write(fp, json.encode(save), "\n")
	 io.close(fp)
      end
   end
end

local function ctlChanged(val, ctbl, v)
   local ss = system.getSwitchInfo(val)
   if ss.assigned == false then
      ctbl[v] = nil
   else
      ctbl[v] = val
   end
   system.pSave(v.."Ctl", ctbl[v])
end

local function telemChanged(val, stbl, v, ttbl)
   stbl[v].Se = val
   stbl[v].SeId = ttbl.Idlist[val]
   stbl[v].SePa = ttbl.Palist[val]
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", stbl[v].SeId)
   system.pSave(v.."SePa", stbl[v].SePa)
end

local function initForm(sf)
   if sf == 1 then
      form.setTitle("F3B Practice")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(4, "C 150", ENABLED)

      for i in ipairs(sens) do
	 form.addRow(2)
	 form.addLabel({label=sens[i].label,width=140})
	 form.addSelectbox(telem.Lalist, sens[sens[i].var].Se, true,
			   (function(x) return telemChanged(x, sens, sens[i].var, telem) end),
			   {width=180, alignRight=false})
      end

      for i in ipairs(ctl) do
	 form.addRow(2)
	 form.addLabel({label=ctl[i].label, width=220})
	 form.addInputbox(ctl[ctl[i].var], true, (function(x) return ctlChanged(x, ctl, ctl[i].var) end) )
      end
      
      form.addRow(1)
      form.addLink((function()
	       initPos = nil
	       curPos = nil
	       zeroPos = nil
	       zeroLatString = nil
	       zeroLngString = nil
	       gpsScale = 1
	       rotA = nil
	       curDist = nil
	       curBear = nil
	       --curX = nil
	       --curY = nil
	       --perpA = nil
	       --perpB = nil
	       io.remove(prefix() .. 'Apps/DFM-F3B/GPS.jsn')
	       system.messageBox("GPS data reset")
	       form.reinit(1)
		   end),
	 {label = "Reset saved GPS info"})
   end
end

local function det(x1, y1, x2, y2, x, y)
   return (x-x1)*(y2-y1) - (y-y1)*(x2-x1)
end

local function pDist(x1, y1, x2, y2, x, y)
   return math.abs( (x2-x1)*(y1-y) - (x1-x)*(y2-y1) ) / math.sqrt( (x2-x1)^2 + (y2-y1)^2)
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local popRows
local fields = {}

local function initPop(sf)
   form.setButton(1, ":down",  ENABLED)
   form.setButton(2, ":up", ENABLED)
   form.setButton(4, "Esc", ENABLED)

   local ss
   for i=1,#fields,1 do
      form.addRow(5)
      local b = math.deg(fields[i].rotA/1000) + 90
      form.addLabel({label=string.format("%-10s", fields[i].name) ,width=70, font=FONT_MINI})
      form.addLabel({label=string.format("%3.6f°", fields[i].Lat) ,width=70, font=FONT_MINI})
      form.addLabel({label=string.format("%3.6f°", fields[i].Lng) ,width=70, font=FONT_MINI})
      form.addLabel({label=string.format("%3.1f°", b), width=60, font=FONT_MINI})
      if fields[i].dist then
	 if fields[i].dist < 1000 then
	    ss = string.format("%3d m", fields[i].dist)
	 else
	    ss = ">1km"
	 end
      else
	 ss = "---"
      end
      form.addLabel({label=string.format("%5s", ss), width=60, font=FONT_MINI, alignRight=true})      
      
   end
   form.setFocusedRow(1)
   popRows = #fields
end

local function keyPop(key)
   
   if key == KEY_UP or key == KEY_1 then
      --print("DOWN")
      form.preventDefault()
      local r = form.getFocusedRow()
      r = math.min(r + 1, popRows)
      form.setFocusedRow(r)
   elseif key == KEY_DOWN or key == KEY_2 then
      --print("UP")
      form.preventDefault()
      local r = form.getFocusedRow()
      r = math.max(r - 1, 1)
      form.setFocusedRow(r)
   elseif key == KEY_ESC or key == KEY_4 then
      --print("key ESC")
      form.preventDefault()
      system.messageBox("No field selected from table")
      form.close(2)
   elseif key == KEY_ENTER or key == KEY_5 then
      --print("key ENTER or 5")
      form.preventDefault()
      local fr = form.getFocusedRow()
      --print("exiting with focrow", fr)
      --select the row from the table here
      if fr >= 1 and fr <= #fields then
	 system.messageBox("Selecting field " .. fields[fr].name)
	 zeroLatString = fields[fr].Lat
	 zeroLngString = fields[fr].Lng
	 gpsScale = fields[fr].gpsScale / 1000.0
	 rotA = fields[fr].rotA / 1000.0
      end
      
      form.close(2)
   end
   
end

local function fieldPop()
   --print("fieldPop")
   local pos
   local jtext = io.readall(prefix() .. 'Apps/DFM-F3B/Fields.jsn')
   if jtext then
      fields = json.decode(jtext)
      if fields then
	 --print("#fields", #fields, fields[1].name, fields[1].Lat,fields[1].Lng, type(fields[1].Lat))
      else
	 return
      end
      for i = 1, #fields, 1 do
	 pos = gps.newPoint(fields[i].Lat, fields[i].Lng)
	 if pos and curPos then
	    fields[i].dist = gps.getDistance(pos, curPos)
	 end
      end
      --sort fields table by distance to current position
      table.sort(fields, (function(a,b) return a.dist < b.dist end))
   else
      return
   end
   system.registerForm(2, 0, "Field selection", initPop, keyPop)
end

local function loop()
   
   local swa
   
   if type(sens.lat.SeId) == "number" and type(sens.lat.SePa) == "number" then
      curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)
      if curPos then gotTelemetry = true end
   else
      gotTelemetry = false
   end

   if gotTelemetry and not gotLast then
      fieldPop()
   end
   
   gotLast = gotTelemetry
   
   if curPos and zeroPos then
      if not initPos then
	 initPos = curPos
	 --if not zeroPos then zeroPos = curPos end
      end

      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)

      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))

      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, rotA or 0)

      if gpsScale then
	 curX = curX * gpsScale
      end
      
      if curX ~= lastX or curY ~= lastY then
	 lastX = curX
	 lastY = curY
      end
      
      detA = det(0,-50,0,50,curX,curY)
      detB = det(distAB-early,-50, distAB-early, 50,curX,curY)
      
      if detA > 0 then dA = 1 else dA = 0 end
      if detB > 0 then dB = 1 else dB = 0 end
      
      dd = dA + 2*dB
      
      perpA = pDist(0,-50,0,50,curX, curY)
      perpB = pDist(distAB-early,-50,distAB-early, 50, curX, curY)
      
      if detA < 0 then perpA = -perpA end
      if detB > 0 then perpB = -perpB end
      
      if dd then
	 flightZone = zone[dd]
	 if not lastFlightZone then lastFlightZone = flightZone end
      end
   end

   swa = system.getInputsVal(ctl.arm)

   if (flightZone == 3 and lastFlightZone == 2) or (flightZone == 1 and lastFlightZone == 2) then
      if not swa or swa == 1 then
	 system.playBeep(0,440,500)
	 print("Beep")
      end
   end

   lastFlightZone = flightZone
end

local function getAB()
   local pa, pb
   local z = zeroLatString and zeroLngString   

   if rotA and perpA and z then
      pa = string.format("A %.2f", perpA)
   else
      pa = "A ---"
   end
   
   if rotA and perpB and z then
      pb = string.format("B %.2f", perpB)
   else
      pb = "B ---"
   end
   return pa, pb
end

local function formTele()
   local pa, pb
   pa, pb = getAB()
   local ss
   local lt, lg
   if curPos then
      lt, lg = gps.getStrig(curPos)
      ss = "["..lt .. ","..lg.."]"
   else
      ss = ""
   end
   
   if curDist and curBear then
      ss = string.format("Dist %.2f Bearing %.0f° ", curDist, curBear) .. ss
      lcd.drawText(10, 120, ss, FONT_MINI)
   else
      lcd.drawText(10, 120, "Dist --- Bearing --- " .. ss, FONT_MINI)
   end
   lcd.drawText(10,100, pa .. "  "..pb)
end

local function printTele()
   local pa
   local pb
   pa, pb = getAB()
   lcd.drawText(0,0,pa, FONT_MAXI)
   lcd.drawText(0,35, pb, FONT_MAXI)
end

local function init()
   
   for i in ipairs(sens) do
      local v = sens[i].var
      if not sens[v] then sens[v] = {} end
      sens[v].Se   = system.pLoad(v.."Se", 0)
      sens[v].SeId = system.pLoad(v.."SeId", 0)
      sens[v].SePa = system.pLoad(v.."SePa", 0)
   end
   
   for i in ipairs(ctl) do
      local v = ctl[i].var
      ctl[v] = system.pLoad(v.."Ctl")
   end

   distAB = 150

   local jtext = io.readall(prefix() .. 'Apps/DFM-F3B/GPS.jsn')

   if jtext then
      local jj = json.decode(jtext)
      if jj then
	 system.messageBox("Reading globally saved GPS data")
	 zeroLatString = jj.zeroLatString
	 zeroLngString = jj.zeroLngString
	 gpsScale = jj.gpsScale / 1000.0
	 rotA = jj.rotA / 1000.0
      end
   else
      zeroLatString = nil
      zeroLngString = nil
      gpsScale = 1 
      rotA = nil
   end
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   system.registerForm(1, MENU_APPS, "F3B", initForm, keyForm, formTele)
   system.registerTelemetry(1, "F3B Status", 2, printTele)

   gotTelemetry = false
   gotLast = false
   
   readSensors(telem)

   print("DFM-F3B: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3BVersion, name="F3B"}
