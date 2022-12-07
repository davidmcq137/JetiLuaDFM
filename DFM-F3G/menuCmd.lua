local M = {}

local subForm = 0
local savedRow
--[[
local function readSensors(tbl)
   --local sensorLbl = "***"
   
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    --sensorLbl = sensor.label
	    table.insert(tbl.Lalist, ">> "..sensor.label)
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
--]]
local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      print("keyExit", k, subForm)
      return true
   else
      return false
   end
end

local function ctlChanged(val, ctbl, v)
   local tt = system.getSwitchInfo(val)
   if tt.assigned == true then
      ctbl[v] = val
   else
      ctbl[v] = nil
   end
   system.pSave(v.."Ctl", ctbl[v])
end

--[[
local function changedDist(val)
   F3G.gpsP.distAB = val
   system.pSave("F3G.gpsP.distAB", F3G.gpsP.distAB)
   print("DFM-F3G: gcc " .. collectgarbage("count"))
end
--]]

--[[
local function telemChanged(val, stbl, v, ttbl)
   stbl[v].Se = math.floor(val)
   stbl[v].SeId = math.floor(ttbl.Idlist[val])
   stbl[v].SePa = math.floor(ttbl.Palist[val])
   
   print("pSave", v.."Se", stbl[v].Se)
   print("pSave", v.."SeId", (stbl[v].SeId))
   print("pSave", v.."SePa", (stbl[v].SePa))   
   
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", (stbl[v].SeId))   system.pSave(v.."SePa", (stbl[v].SePa))
end
--]]

local function modeChanged(val, F3G, resetFlight)
   F3G.flightMode = val
   system.pSave("flightMode", F3G.flightMode)
   resetFlight()
end

function M.printTele(w,h,F3G)

   local text, text2
   
   if subForm ~= 1 then return end
   text = string.format("Rotate: %d", math.deg(F3G.gpsP.rotA))
   lcd.drawText(230,120, text)
   if F3G.gpsP.curPos then
      text, text2 = gps.getStrig(F3G.gpsP.curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end


function M.keyForm(key, F3G, resetFlight)

   print("M.keyForm", key)
   
   if subForm ~= 1 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   else
      if keyExit(key) then
	 print("exit with SF 1")
	 return true
      end
   end
   
   if subForm == 1 then
      if key == KEY_1 then
	 F3G.gpsP.zeroPos = F3G.gpsP.curPos
	 if F3G.gpsP.zeroPos then
	    F3G.gpsP.zeroLatStr, F3G.gpsP.zeroLngStr = gps.getStrig(F3G.gpsP.zeroPos)
	    system.pSave("zeroLatString", F3G.gpsP.zeroLatStr)
	    system.pSave("zeroLngString", F3G.gpsP.zeroLngStr)
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if F3G.gpsP.curBear then
	    F3G.gpsP.rotA = math.rad(F3G.gpsP.curBear-90)
	    system.pSave("rotA", F3G.gpsP.rotA*1000)
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_3 then
	 resetFlight()
      end
   end
   return false
end

function M.menuCmd(sf, F3G, resetFlight)

   subForm = sf
   
   if sf == 1 then
      form.setTitle("F3G Practice")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)   

      --[[
      form.addRow(2)
      form.addLabel({label="Telemetry >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(3)
	       form.waitForRelease()
      end))      
      --]]
      form.addRow(2)
      form.addLabel({label="Controls >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Flight Mode", width=220})
      form.addSelectbox({"F3G", "F3B", "Basic"}, F3G.flightMode, true,
	 (function(x) return modeChanged(x, F3G, resetFlight) end))
      
      --[[
      form.addRow(2)
      form.addLabel({label="Course Length", width=220})      
      form.addIntbox(F3G.gpsP.distAB, 20, 200, 150, 0, 1, changedDist)
      --]]
      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1
   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)
      --[[
   elseif sf == 3 then
      form.setTitle("Telemetry Sensors")
      readSensors(F3G.telem)
      for i in ipairs(F3G.sens) do
	 form.addRow(2)
	 form.addLabel({label=F3G.sens[i].label,width=140})
	 form.addSelectbox(F3G.telem.Lalist, F3G.sens[F3G.sens[i].var].Se, true,
			   (function(x) return telemChanged(x, F3G.sens, F3G.sens[i].var, F3G.telem) end),
			   {width=180, alignRight=false})
      end
      --]]
   elseif sf == 4 then
      form.setTitle("Controls")
      for i in ipairs(F3G.ctl) do
	 form.addRow(2)
	 form.addLabel({label=F3G.ctl[i].label, width=220})
	 form.addInputbox(F3G.ctl[F3G.ctl[i].var], true,
			  (function(x) return ctlChanged(x, F3G.ctl, F3G.ctl[i].var) end) )
      end
   end
end

return M
