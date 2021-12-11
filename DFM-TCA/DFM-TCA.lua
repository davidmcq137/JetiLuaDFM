--[[

   TCA - Telemetry Central App

   10-Dec-2021 D. McQueeney
   Released 12/2021 MIT license

   Keep a copy of all the relevant info for all the telemetry windows running on
   the TX. Display them with the forms interface so that one app can be left
   running while in flight and shift between all tele windows and give each one
   access to all the TX controls (e.g. screen softkeys, esc an menu, 3D
   wheel). Only implemented for full screen windows initially. After copying
   tele window information from system.registerTelemetry, passes the call along
   to the real system routine so that the apps all work as normal from the
   displayed telemetry interface. Passes input from TX controls to the app via
   an extra call parameter to the draw routine.

--]]

local originalregisterTelemetry

local teleWin = {}

local currentWindow
local key = 0
local lastKey = key
local activeForm = 0
local focusedRow = 1
local neverSorted = true

local function tsort(i1, i2)
   return i1.seq < i2.seq 
end

local function teleSort()
   table.sort(teleWin, tsort)
   for i in ipairs(teleWin) do
      system.pSave(teleWin[i].label, i)
   end
end

function registerTelemetry(nn, lbl, sz, cb)

   local wid = 0
   local hgt = 0
   -- only do full screen tele windows for now
   if sz == 4 then
      wid = 319
      hgt = 159
   elseif sz == 1 then
      --wid = 151
      --hgt = 24
   elseif sz == 2 then
      --wid = 151
      --hgt = 69
   else
      wid = 0
      hgt = 0
   end

   if wid ~= 0 and hgt ~= 0 then
      seq = #teleWin + 1
      table.insert(teleWin, {num=nn, width=wid, height=hgt, label=lbl, size=sz, callback=cb, seq=seq})
      if not currentWindow then currentWindow = 1 end
   end

   originalregisterTelemetry(nn, lbl, sz, cb)
end

originalregisterTelemetry = system.registerTelemetry
system.registerTelemetry = registerTelemetry

local function initForm(fm)
   --print("initForm", fm)

   if neverSorted then
      local i=1
      while i <= #teleWin do
	 local pseq = system.pLoad(teleWin[i].label) or i
	 if pseq == 0 then
	    table.remove(teleWin, i)
	 else
	    teleWin[i].seq = pseq
	    i=i+1
	 end
      end
      teleSort()
      neverSorted = false
   end
   
   activeForm = fm
   if activeForm == 1 then
      form.setButton(1, "Menu", 1)
      form.setButton(2, ":left", 1)
      form.setButton(3, ":right", 1)
      form.setButton(4, " ", 1)
      form.setButton(5, "Exit", 1)
      form.setTitle("")
   elseif activeForm == 2 then
      form.setButton(1, ":down", 1)
      form.setButton(2, ":up", 1)
      form.setButton(3, " ", 1)
      form.setButton(4, ":delete", 1)
      form.setButton(5, "OK", 1)
      form.setTitle("Telemetry Central")
      for i = 1, #teleWin, 1 do
	 if teleWin[i].seq ~= 0 then
	    form.addRow(1)
	    form.addLabel({label=string.format("%d  ", i) .. teleWin[i].label, width=200})
	 end
      end
      form.setFocusedRow(focusedRow)
   end
end

local function prtForm()
   if activeForm ~= 1 then return end
   if currentWindow and teleWin[currentWindow].callback then
      local wid = teleWin[currentWindow].width
      local hgt = teleWin[currentWindow].height
      -- if key is available, pass along to the app as an extra parameter
      teleWin[currentWindow].callback(wid, hgt, key)
      key = 0
   end
   lcd.setColor(lcd.getFgColor())
   lcd.drawFilledRectangle(0,160,320,20)
   lcd.setColor(lcd.getBgColor())
   local lbl = teleWin[currentWindow].label
   lcd.drawText(5,162,string.format("(%d)  %s", (currentWindow or 0), lbl), FONT_MINI)
   end

local function keyForm(k)
   form.waitForRelease()
   if activeForm == 1 then
      if k == KEY_1 then
	 lastKey = 0
	 initForm(2)
      elseif k == KEY_2 then
	 currentWindow = math.max(currentWindow - 1, 1)
	 lastKey = 0
      elseif k == KEY_3 then
	 currentWindow = math.min(currentWindow + 1, #teleWin)
	 lastKey = 0
      elseif k == KEY_RELEASED then -- save last pressed key to send to tele window
	 key = lastKey
      else
	 lastKey = k
      end
   elseif activeForm == 2 then
      local fr = form.getFocusedRow()
      local temp
      form.preventDefault()
      if k == KEY_1 then -- down
	 if (fr ~= #teleWin) and (#teleWin ~= 1) then
	    teleWin[fr].seq = fr + 1
	    teleWin[fr+1].seq = fr
	    --table.sort(teleWin, tsort)
	    teleSort()
	    focusedRow = fr + 1
	    form.reinit(2)
	 end
      elseif k == KEY_2 then -- up
	 if (fr ~= 1) and (#teleWin ~= 1) then
	    teleWin[fr].seq = fr - 1
	    teleWin[fr-1].seq = fr
	    --table.sort(teleWin, tsort)
	    teleSort()
	    focusedRow = fr - 1
	    form.reinit(2)
	 end
      elseif k == KEY_4 then -- delete
	 system.pSave(teleWin[fr].label, 0)
	 table.remove(teleWin, fr)
	 focusedRow = 1
	 currentWindow = 1
	 form.reinit(2)
      elseif k == KEY_5 or k == KEY_ESC then
	 teleSort()
	 form.reinit(1)
      end
   end
end



local function tele1(w,h)
   lcd.drawText(0,0,"Tele Test 1")
end

local function init()
   system.registerForm(1, 0, "Telemetry Central App", initForm, keyForm, prtForm)
   --system.registerTelemetry(1, "Test 1", 2, tele1)
end

return {init=init, loop=loop, author="DFM", version="1", name="DFM-TCA"}
