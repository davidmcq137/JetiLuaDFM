local M = {}

local popRows
local fields = {}

local function initPop(sf, cp)
   form.setButton(1, ":down",  ENABLED)
   form.setButton(2, ":up", ENABLED)
   form.setButton(4, "Esc", ENABLED)

   local ss
   for i=1,#fields,1 do
      form.addRow(5)
      local b
      if fields[i].rotA then
	 b = math.deg(fields[i].rotA/1000) + 90
      elseif fields[i].LatB and fields[i].LngB then
	 local pA = gps.newPoint(fields[i].Lat, fields[i].Lng)
	 local pB = gps.newPoint(fields[i].LatB, fields[i].LngB)
	 b = gps.getBearing(pA, pB)
      else
	 b = 0
      end
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

local function keyPop(key, CB)
   
   if key == KEY_UP or key == KEY_1 then
      form.preventDefault()
      local r = form.getFocusedRow()
      r = math.min(r + 1, popRows)
      form.setFocusedRow(r)
   elseif key == KEY_DOWN or key == KEY_2 then
      form.preventDefault()
      local r = form.getFocusedRow()
      r = math.max(r - 1, 1)
      form.setFocusedRow(r)
   elseif key == KEY_ESC or key == KEY_4 then
      form.preventDefault()
      system.messageBox("No field selected from table")
      form.close(2)
   elseif key == KEY_ENTER or key == KEY_5 then
      form.preventDefault()
      local fr = form.getFocusedRow()
      if fr >= 1 and fr <= #fields then
	 system.messageBox("Selecting field " .. fields[fr].name)
	 CB(fields[fr])
      end
      
      form.close(2)
   end
   
end

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end


function M.fieldPopUp(curPos, CB)
   local pos
   local jtext = io.readall(prefix() .. 'Apps/DFM-F3B/Fields.jsn')
   local OK, msg
   if jtext then
      OK, fields= pcall(json.decode, jtext)
      --print("pcall", OK, fields)
      if not OK then
	 print("DFM-F3B: Error in file Fields.jsn")
	 print("DFM-F3B: ".. fields)
	 system.messageBox("Fields.jsn error. See console")
	 return
      end
      for i = 1, #fields, 1 do
	 pos = gps.newPoint(fields[i].Lat, fields[i].Lng)
	 if pos and curPos then
	    fields[i].dist = gps.getDistance(pos, curPos)
	    --print("i, fields[i].name, dist", i, fields[i].name, fields[i].dist)
	 end
      end
      --sort fields table by distance to current position
      table.sort(fields, (function(a,b) return a.dist < b.dist end))
   else
      return
   end
   system.registerForm(2, 0, "Field selection", (function(x) return initPop(x, curPos) end),
		       (function(x) return keyPop(x,CB) end))
   print("gcc pop", collectgarbage("count"))
end

return M
