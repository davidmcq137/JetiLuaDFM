local M = {}

local subForm = 0
local savedRow

local function keyExit(k)
   if k == KEY_5 or k == KEY_ENTER or k == KEY_ESC then
      --print("keyExit", k, subForm)
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

local function modeChanged(val, F3X, resetFlight)
   F3X.flightMode = val
   system.pSave("flightMode", F3X.flightMode)
   resetFlight()
end

function M.printTele(w,h,F3X)

   local text, text2
   
   if subForm ~= 1 then return end
   text = string.format("Rotate: %d", math.deg(F3X.gpsP.rotA))
   lcd.drawText(230,120, text)
   if F3X.gpsP.curPos then
      text, text2 = gps.getStrig(F3X.gpsP.curPos)
      lcd.drawText(0,120,"[" .. text .. "," .. text2 .. "]")
   else
      lcd.drawText(10,120,"-No GPS-")   
   end
end

function M.keyForm(key, F3X, resetFlight)

   if subForm ~= 1 then
      if keyExit(key) then
	 form.preventDefault()
	 form.reinit(1)
	 return
      end
   else
      if keyExit(key) then
	 --print("exit with SF 1")
	 return true
      end
   end
   
   if subForm == 1 then
      if key == KEY_1 then
	 F3X.gpsP.zeroPos = F3X.gpsP.curPos
	 if F3X.gpsP.zeroPos then
	    F3X.gpsP.zeroLatStr, F3X.gpsP.zeroLngStr = gps.getStrig(F3X.gpsP.zeroPos)
	    system.pSave("zeroLatString", F3X.gpsP.zeroLatStr)
	    system.pSave("zeroLngString", F3X.gpsP.zeroLngStr)
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_2 then
	 if F3X.gpsP.curBear then
	    F3X.gpsP.rotA = math.rad(F3X.gpsP.curBear-90)
	    system.pSave("rotA", F3X.gpsP.rotA*1000)
	 else
	    system.messageBox("No Current Position")
	 end
      elseif key == KEY_3 then
	 resetFlight()
      end
   end
   return false
end

function M.menuCmd(sf, F3X, resetFlight)

   subForm = sf
   
   if sf == 1 then
      form.setTitle("F3X Practice for F3B/F3G")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)   

      form.addRow(2)
      form.addLabel({label="Controls >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))

      form.addRow(2)
      form.addLabel({label="Flight Mode", width=220})
      form.addSelectbox({"F3G", "F3B", "Basic"}, F3X.flightMode, true,
	 (function(x) return modeChanged(x, F3X, resetFlight) end))

      --[[
      form.addRow(2)
      form.addLabel({label="Memory >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(3)
	       form.waitForRelease()
      end))
      --]]
      
      --[[
      form.addRow(2)
      form.addLabel({label="Course Length", width=220})      
      form.addIntbox(F3X.gpsP.distAB, 20, 200, 150, 0, 1, changedDist)
      --]]

      if savedRow then form.setFocusedRow(savedRow) end
      savedRow = 1

   elseif sf == 2 then
      form.setTitle("")
      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Reset", ENABLED)

   elseif sf == 3 then
      print("gcc: ", collectgarbage("count"))
      form.reinit(1)
      
   elseif sf == 4 then
      form.setTitle("Controls")
      for i in ipairs(F3X.ctl) do
	 form.addRow(2)
	 form.addLabel({label=F3X.ctl[i].label, width=220})
	 form.addInputbox(F3X.ctl[F3X.ctl[i].var], true,
			  (function(x) return ctlChanged(x, F3X.ctl, F3X.ctl[i].var) end) )
      end
   end
end

return M
