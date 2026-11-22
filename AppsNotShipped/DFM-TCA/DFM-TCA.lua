--[[

   TCA - Telemetry Central App

   10-Dec-2021 D. McQueeney
   Released 12/2021 MIT license

   App to allow all running apps to interact with TX controls (F1-F5, 3D wheel
   and button etc) while their tele window is displayed. Also allows lua control
   of which tele window is displayed.

   How it works: We keep a copy of all the relevant info for all the telemetry
   windows running on the TX. Display them with the forms interface of this app
   so that this one app can be left running while in flight and shift between
   all tele windows and give each one access to all the TX controls (e.g. screen
   softkeys, esc an menu, 3D wheel). Only implemented for full screen windows
   initially. After copying tele window information from
   system.registerTelemetry(), passes the call along to the real system routine so
   that the apps all work as normal from the displayed telemetry interface.

   Passes input from TX controls (key presses) to another app via an extra call
   parameter to the tele window draw routine. Apps pass key labels to this app
   as extra params to system.registerTelemetry(). App can send back a string
   from the tele draw callback to be displayed on the status bar.

   Pilots can define switches/controls that change displayed tele window for
   creating automatic context switching of tele windows to match phase of
   flight.

   Pilots can define wav file to play as a new tele window is displayed.

--]]

local originalregisterTelemetry

local teleWin = {}
local stateSw = {}

local currentWindow
local key = 0
local lastKey = key
local activeForm = 0
local focusedRow = 1
local neverSorted = true
local txT
local lastTime = 0

local function tsort(i1, i2)
   return i1.seq < i2.seq 
end

local function teleSave()
   --save in format "002foo.wav" and parse it out when it comes back in
   for i in ipairs(teleWin) do
      system.pSave(teleWin[i].label, string.format("%03d", teleWin[i].seq) .. teleWin[i].wavFile)
   end
end

local function teleLoad()
   local i=1
   while i <= #teleWin do
      local pL = system.pLoad(teleWin[i].label) or string.format("%03d*.wav", i)
      local pseq, pwav = string.match(pL, "(%d%d%d)(.+)")
      if pseq == 0 then
	 table.remove(teleWin, i)
      else
	 teleWin[i].seq = tonumber(pseq) or i
	 teleWin[i].wavFile = pwav
	 i=i+1
      end
   end
end

local function teleSort()
   table.sort(teleWin, tsort)
   teleSave()
end

function registerTelemetry(nn, lbl, sz, cb, bt)

   local wid = 0
   local hgt = 0
   -- only do full screen tele windows for now
   local btn = {}

   --print("nn, lbl, sz, cb, bt", nn, lbl, sz, cb, bt)
   
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
   
   if not bt then
      for i=1,5,1 do
	 btn[i] = ""
      end
   else
      for i=1,5,1 do
	 btn[i] = bt[i] or ""
      end
   end
   
   if wid ~= 0 and hgt ~= 0 then
      seq = #teleWin + 1
      table.insert(teleWin,
		   {num=nn, width=wid, height=hgt, label=lbl,
		    size=sz, callback=cb, seq=seq, button=btn,
		    wavFile = "*.wav"})
      if not currentWindow then currentWindow = 1 end
   end
   local ret = originalregisterTelemetry(nn, lbl, sz, cb)
   return ret
end

-- these statements are outside a function and wil get executed before and init() (I hope!)

originalregisterTelemetry = system.registerTelemetry
system.registerTelemetry = registerTelemetry

local function stateSave()
   local from   = {}
   local to     = {}
   local switch = {}
   local time   = {}
   local dir    = {}
   for i in ipairs(stateSw) do
      from  [i] = stateSw[i].from
      to    [i] = stateSw[i].to
      switch[i] = stateSw[i].switch
      time  [i] = stateSw[i].time
      dir   [i] = stateSw[i].dir
   end
   system.pSave("from"  , from)
   system.pSave("to"    , to)
   for i in ipairs(switch) do
      system.pSave("switch"..i, switch[i])
   end
   system.pSave("time"  , time)
   system.pSave("dir"   , dir)
end

local function stateLoad()
   local from   = system.pLoad("from")   or {}
   local to     = system.pLoad("to")     or {}
   local time   = system.pLoad("time")   or {}
   local dir    = system.pLoad("dir")    or {}
   local imax = math.max(#from, #to, #time, #dir)
   for i = 1, imax, 1 do
      stateSw[i] = {}
      stateSw[i].from   = from  [i] or "*"
      stateSw[i].to     = to    [i] or "*"
      stateSw[i].switch = system.pLoad("switch"..i) 
      stateSw[i].time   = time  [i] or 0
      stateSw[i].dir    = dir   [i] or 1
      stateSw[i].lastSw = 0
      stateSw[i].timeout = 0
   end
end

local function fromChanged(val, j)
   stateSw[j].from = teleWin[val-1].label
   stateSave()
   form.reinit(4)
end

local function toChanged(val, j)
   stateSw[j].to = teleWin[val-1].label
   stateSave()
   form.reinit(4)
end

local function swChanged(val, j)
   stateSw[j].switch = val
   stateSave()
   --form.reinit(4)
end

local function timeChanged(val, j)
   stateSw[j].time = val
   stateSave()
   --form.reinit(4)
end

local function dirChanged(val, j)
   stateSw[j].dir = val
   stateSave()
   --form.reinit(4)
end

local function wavChanged(val, j, w)
   --print("wav changed", val, j, w[val])
   teleWin[j].wavFile = w[val]
   teleSave()
end

local function initForm(fm)
   -- first time through, get saved sequence numbers from pSave
   -- seq of 0 means it's deleted

   print("initForm", fm)
   
   if neverSorted then
      teleLoad()
      teleSort()
      neverSorted = false
   end
   
   activeForm = fm
   if activeForm == 1 then
      form.setButton(1, teleWin[currentWindow].button[1], 1)      
      form.setButton(2, teleWin[currentWindow].button[2], 1)
      form.setButton(3, teleWin[currentWindow].button[3], 1)
      form.setButton(4, teleWin[currentWindow].button[4], 1)
      form.setButton(5, ":right", 1)
      form.setTitle("")
   elseif activeForm == 2 then
      for i=1,4,1 do
	 form.setButton(i, "", 1)
      end
      form.setButton(5,"OK",1)
      form.addRow(1)
      form.addLink((function() form.reinit(3) end), {label = "Telemetry Windows>>", width=220})
      form.addRow(1)
      form.addLink((function() form.reinit(4) end), {label = "Sequence Switches>>", width=220})      

      form.setFocusedRow(1)
   elseif activeForm == 3 then
      form.setButton(1, ":down", 1)
      form.setButton(2, ":up", 1)
      form.setButton(3, " ", 1)
      --form.setButton(4, ":delete", 1)
      form.setButton(4, " ", 1)
      form.setButton(5, "OK", 1)
      form.setTitle("Telemetry Central")
      local wav={}
      local iwav=1
      table.insert(wav, "*.wav")
      for fn, ft, sz in dir("Apps/DFM-TCA/Audio") do
	 if string.sub(fn, -4) == ".wav" and ft == "file" then
	    table.insert(wav, fn)
	 end
      end

      table.sort(wav)
      
      for i = 1, #teleWin, 1 do
	 if teleWin[i].seq ~= 0 then
	    form.addRow(2)
	    local text = string.format("[%d]  ", i) .. teleWin[i].label
	    form.addLabel({label=text, width=210})
	    for j in ipairs(wav) do
	       if teleWin[i].wavFile == wav[j] then iwav = j end
	    end
	    form.addSelectbox(wav, iwav, true,
			      (function(x) return wavChanged(x,i,wav) end), {width=100} )
	 end
      end
   elseif activeForm == 4 then
      form.setButton(1, ":add", 1)
      form.setButton(2, ":delete", 1)
      form.addRow(1)
      form.addLabel({label="SW        Trig        From            To           t(s)"})
      local teleLabel={}
      teleLabel[1] = "*"
      for i in ipairs(teleWin) do
	 teleLabel[i+1] = teleWin[i].label
      end
      for j in ipairs(stateSw) do
	 local to = 1
	 local from = 1
	 for i in ipairs(teleWin) do
	    if teleWin[i].label == stateSw[j].to then to = i+1 end
	    if teleWin[i].label == stateSw[j].from then from = i+1 end
	 end
	 form.addRow(5)
	 form.addInputbox(stateSw[j].switch, false,
			  (function(x) return swChanged(x,j)   end), {width=50})
	 form.addSelectbox({"Pos", "Neg"}, stateSw[j].dir, false,
	    (function(x) return dirChanged(x,j)  end), {width=70})
	 form.addSelectbox(teleLabel, from, true,
			   (function(x) return fromChanged(x,j) end), {width=70})
	 form.addSelectbox(teleLabel, to  , true,
			   (function(x) return toChanged(x,j)   end), {width=70})
	 form.addIntbox(stateSw[j].time, 0, 60, 10, 0, 1,
			(function(x) return timeChanged(x,j) end), {width=50})
      end
      
   end
   --form.setFocusedRow(focusedRow)
end

local function tele1()
   if not txT then return end

   -- skeleton version of pre-flight screen .. will add bar graphs for current draw if a CBxxx
   -- is installed, with max current indication to confirm controls are free before flight
   
   str = "Model: " .. system.getProperty("Model") or "---"
   lcd.drawText(150 - 0.5 * lcd.getTextWidth(FONT_BIG, str), 5, str, FONT_BIG)

   lcd.drawText(10, 40, "TX Voltage: "  .. (txT.txVoltage or "---") .. " V" )
   lcd.drawText(10, 60, "TX Batt: "     .. (txT.txBattPercent or "---") .. "%")
   lcd.drawText(10, 80, "RX1 Percent: " .. (txT.rx1Percent or "---") .. "%")
   lcd.drawText(10,100, "RX1 Voltage: " .. (txT.rx1Voltage or "---") .. " V")  
end

local function prtForm()
   local ret
   if activeForm ~= 1 then return end
   if currentWindow and teleWin[currentWindow].callback then
      local wid = teleWin[currentWindow].width
      local hgt = teleWin[currentWindow].height
      -- if key is available, pass along to the app as an extra parameter
      -- receive possible return value as well
      ret = teleWin[currentWindow].callback(wid, hgt, key) -- the magic happens here :-)
      local keymap = {[1]=1,[2]=2, [4]=3, [8]=4} -- KEY_n are 2^(n-1)
      if key and key > 0 then
	 local keystr
	 if key <= KEY_4 then
	    keystr = teleWin[currentWindow].button[keymap[key]]
	 elseif key == KEY_5 then
	    keystr = "KEY_5"
	 elseif key == KEY_DOWN then
	    keystr = "Down"
	 elseif key == KEY_UP then
	    keystr = "Up"
	 elseif key == KEY_ESC then
	    keystr = "Esc"
	 elseif key == KEY_MENU then
	    keystr = "Menu"
	 elseif key == KEY_ENTER then
	    keystr = "Enter"
	 else
	    keystr = tostring(key)
	 end
	 print("Sending [" .. teleWin[currentWindow].label .. "] Key <" .. keystr .. ">")
      end
      key = 0
   end
   lcd.setColor(lcd.getFgColor())
   lcd.drawFilledRectangle(0,160,320,20)
   lcd.setColor(lcd.getBgColor())
   local lbl = teleWin[currentWindow].label
   lcd.drawText(5,162,string.format("[%d]  %s", (currentWindow or 0), lbl), FONT_MINI)
   lbl = "(esc to Exit)"
   lcd.drawText(305 - lcd.getTextWidth(FONT_MINI, lbl), 162, lbl, FONT_MINI)
   if ret then
      lcd.drawText(155 - 0.5*lcd.getTextWidth(FONT_MINI, ret), 162, ret, FONT_MINI)
   end
   
end

local function keyForm(k)
   form.waitForRelease()
   if k ~= KEY_ESC then
      form.preventDefault()
   end
   if activeForm == 1 then
      if k == KEY_MENU then
	 lastKey = 0
	 initForm(2)
      elseif k == KEY_5 then
	 if currentWindow + 1 > #teleWin then currentWindow = 1 else currentWindow = currentWindow + 1 end
	 lastKey = 0
	 --swap over to this screen's buttons
	 for i = 1, 4 do
	    form.setButton(i, teleWin[currentWindow].button[i], 1)
	 end
      elseif k == KEY_RELEASED then -- save last pressed key to send to tele window
	 key = lastKey
      else
	 lastKey = k
      end
   elseif activeForm == 2 then
      form.preventDefault()
      if k == KEY_5 or k == KEY_ESC then
	 form.reinit(1)
      end
   elseif activeForm == 3 then
      local fr = form.getFocusedRow()
      local temp
      form.preventDefault()
      if k == KEY_1 then -- down
	 if (fr ~= #teleWin) and (#teleWin ~= 1) then
	    teleWin[fr].seq = fr + 1
	    teleWin[fr+1].seq = fr
	    teleSort()
	    form.setFocusedRow(fr+1)
	    --focusedRow = fr + 1
	    form.reinit(3)
	 end
      elseif k == KEY_2 then -- up
	 if (fr ~= 1) and (#teleWin ~= 1) then
	    teleWin[fr].seq = fr - 1
	    teleWin[fr-1].seq = fr
	    teleSort()
	    form.setFocusedRow(fr-1)
	    --focusedRow = fr - 1
	    form.reinit(3)
	 end
      elseif k == KEY_4 then -- delete
	 --[[ --remove delete for now
	 system.pSave(teleWin[fr].label, 0)
	 table.remove(teleWin, fr)
	 form.setFocusedRow(1)
	 --focusedRow = 1
	 currentWindow = 1
	 form.reinit(3)
	 --]]
      elseif k == KEY_5 or k == KEY_ESC then
	 teleSort()
	 form.reinit(2)
      end
   elseif activeForm == 4 then
      if k == KEY_1 then
	 print("gfr", form.getFocussedRow)
	 table.insert(stateSw, {switch=nil, dir=1, from="*", to="*", time=0, lastSw=0})
	 print("#stateSw+1", #stateSw+1)
	 form.setFocusedRow(#stateSw + 1)
	 --focusedRow = #stateSw + 1
	 form.reinit(4)
      elseif k == KEY_2 then
	 --print("delete")
	 local fr = form.getFocusedRow()
	 --print("del: fr", fr)
	 if fr - 1 > 0 then
	    table.remove(stateSw, fr - 1)
	 end
	 form.reinit(4)
      elseif k == KEY_5 or k == KEY_ESC then
	 form.reinit(2)
      end
   end
end

local function winNumber(label)
   local iwin = 1
   for i in ipairs(teleWin) do
      if label == teleWin[i].label then
	 iwin = i
	 break
      end
   end
   return iwin
end

local function loop()

   if (form.getActiveForm() ~= 0) then return end
   
   local time = system.getTimeCounter()
   if time - lastTime > 1000 then
      txT = system.getTxTelemetry()
      lastTime = time
   end
   
   for i in ipairs(stateSw) do
      local timeout = (stateSw[i].timeout or 0)
      
      if timeout ~= 0 and system.getTimeCounter() > timeout then
	 stateSw[i].timeout = 0
	 --before going back to orig state, see if we are still in the state we put it in
	 if teleWin[currentWindow].label == stateSw[i].to then
	    currentWindow = winNumber(stateSw[i].retlabel)
	    system.messageBox("Telemetry: ".. stateSw[i].retlabel)
	    system.playFile(teleWin[winNumber(stateSw[i].retlabel)].wavFile, AUDIO_QUEUE)
	 end
      end
      
      local swt = system.getInputsVal(stateSw[i].switch)

      if swt and stateSw[i] and stateSw[i].lastSw ~= 0 and (swt ~= stateSw[i].lastSw) then
	 -- "pos" is index 1 and "neg" is index 2
	 if (swt == 1 and stateSw[i].dir == 1) or (swt == -1 and stateSw[i].dir == 2) then
	    if stateSw[i].from == "*" or stateSw[i].from == teleWin[currentWindow].label then
	       if stateSw[i].time ~= 0 then
		  stateSw[i].timeout = system.getTimeCounter() + 1000 * stateSw[i].time
		  stateSw[i].retlabel = teleWin[currentWindow].label
	       end
	       currentWindow = winNumber(stateSw[i].to)
	       system.messageBox("Telemetry: " .. stateSw[i].to)
	       system.playFile(teleWin[winNumber(stateSw[i].to)].wavFile, AUDIO_QUEUE)
	    end
	 end
      end
      stateSw[i].lastSw = swt
   end
end

local function init()
   system.registerForm(1, 0, "Telemetry Central App", initForm, keyForm, prtForm)
   system.registerTelemetry(1, "Preflight", 4, tele1)
   stateLoad()
end

return {init=init, loop=loop, author="DFM", version="1", name="DFM-TCA"}
