-- ############################################################################# 
-- # DC/DS Virtual Sensor - Lua application for JETI DC/DS transmitters 
-- #
-- # Copyright (c) 2017, JETI model s.r.o.
-- # All rights reserved.
-- #
-- # Redistribution and use in source and binary forms, with or without
-- # modification, are permitted provided that the following conditions are met:
-- # 
-- # 1. Redistributions of source code must retain the above copyright notice, this
-- #    list of conditions and the following disclaimer.
-- # 2. Redistributions in binary form must reproduce the above copyright notice,
-- #    this list of conditions and the following disclaimer in the documentation
-- #    and/or other materials provided with the distribution.
-- # 
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- # ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- # WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- # DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- # ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- # (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- # LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- # ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- # SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- # 
-- # The views and conclusions contained in the software and documentation are those
-- # of the authors and should not be interpreted as representing official policies,
-- # either expressed or implied, of the FreeBSD Project.                    
-- #                       
-- # V1.0 - Initial release from Jeti V-Sensor.lua
-- # V1.1 - DFM 03/28/22 modified to add a lua control that tracks result and added some
-- #                     additional utility functions
-- # V1.2 - DFM 03/31/22 changing name to V-SensXF
-- # V2.0 - DFM 04/02/22 arb # tele, arb # results, help file on results screen
-- #
-- #############################################################################


--------------------------------------------------------------------
local sensorId = {}
local paramId = {}
local sensorVarName = {}
local resultName = {}
local resultUnit = {}
local resultUnitDisp = {}
local sensorsAvailable = {}
local sensorsAvailableGPS = {}
local highTele = {}
local lowTele = {}
local latIndex
local lngIndex
local latID, latParam
local lngID, lngParam
local currentGPS
local selectedGPS = {}
local gpsReads = 0
local value = {}
local condition  = {}
local conditionChanged = {}
local condIdx
local curIndex = {}
local env
local result = {}
local chunk = {}
local fAvailable = {}
local fIndex = {} 
local currentForm=1
local controlResult = {}
local resultControl = {}
local resultIdx = {}
local controlValue = {}
local logVariableID = {}
local unitChars = {["%.p"]="%%", ["%.o"]="°"}
local expTbl = {}
local variableName = {}
local variableValue = {}
local luaCtlMax
local logFileMax
local lang, locale

-- for testing on the old (4.28) version of the DS-16
---[[
if not gps then
   gps = {}
   function gps.newPoint() return 0 end
   function gps.getDistance() return 0 end
   function gps.getBearing() return 0 end
   function gps.getValue() return 0 end
end
--]]

local function setLanguage()
   locale=system.getLocale()
   local tf1 = "Apps/V-SensXF/Lang/"
   local tf2 = "-locale.jsn"
   local file = io.readall(tf1..locale..tf2)
   if not file then
      locale = "en"
      file = io.readall(tf1..locale..tf2)
   end
   if not file then print("No language file found") else
      local obj = json.decode(file)
      if(obj) then
	 lang = obj[locale]
      end
   end
end
   
local function recomputeCond()
   for k in ipairs(condition) do
      conditionChanged[k] = true
   end
end

local function updateValues()
   local ss
   local degs, minutes
   local lat, lng
   for k in ipairs(sensorId) do
      if(sensorId[k] and paramId[k]) then
	 ss = system.getSensorByID(sensorId[k],paramId[k])
      end
      if(ss and ss.valid) then
	 value[k] =  ss.value
      end   
   end
   if latID and lngID and latParam and lngParam then
      ss = system.getSensorByID(latID, latParam)
      if ss and ss.valid then
	 minutes = (ss.valGPS & 0xFFFF) *0.001
	 degs = (ss.valGPS >> 16) & 0xFF
	 lat = degs + minutes / 60.0
	 if ss.decimals == 2 then lat = lat * -1 end
      end
      ss = system.getSensorByID(lngID, lngParam)
      if ss and ss.valid then
	 minutes = (ss.valGPS & 0xFFFF) *0.001
	 degs = (ss.valGPS >> 16) & 0xFF
	 lng = degs + minutes / 60.0
	 if ss.decimals == 3 then lng = lng * -1 end
      end

      if lat and lng then
	 gpsReads = gpsReads + 1
	 currentGPS = gps.newPoint(lat, lng)
      end

      if gpsReads == 10 then
	 selectedGPS[1] = gps.newPoint(lat, lng)
	 --selectedGPS[1] = gps.newPoint(41.339975, -74.430895)
      end

      --[[
      if selectedGPS[1] then
	 print("distance", gps.getDistance(currentGPS, selectedGPS[1]),
	       "bearing", gps.getBearing(selectedGPS[1], currentGPS))
      end
      --]]
   end
end
   
local function formattedResult(idx, u)
   if  type(result[idx])=="number" then
      if u then
	 return string.format("%.2f",result[idx])
      else
	 return string.format("%.2f %s",result[idx],(resultUnitDisp[idx] or ""))
      end
      
  else
     return lang.na
  end    
end

local function printTelemetry(width, height, idx)
   local r  = result[idx]

   local font
   local rf
   
   if height > 40 then
      font = FONT_MAXI
      rf = formattedResult(idx, 0)
   else
      font = FONT_BIG
      rf = formattedResult(idx)
   end
   
   --if type(r) ~= "number" then print("r not number", r) end
   
   if r and type(r) == "number" then
      if lowTele[idx] then
	 if r < lowTele[idx] then lowTele[idx] = r end
      else
	 lowTele[idx] = r
      end
   end
   if r and type(r) == "number" then
      if highTele[idx] then
	 if r > highTele[idx] then highTele[idx] = r end
      else
	 highTele[idx] = r
      end
   end
   
   lcd.drawText(width/2-lcd.getTextWidth(font,rf)/2,(height-lcd.getTextHeight(font))*0.02,rf,font)
   
   if height > 40 then
      r = "V"..string.format("%02d", idx)..": "
      if controlValue[idx] then
	 r = r .. string.format("%.2f", controlValue[idx])
      else
	 r = r .. "---"
      end
      font = FONT_BOLD
      lcd.drawText(width/2-lcd.getTextWidth(font,r)/2,(height-lcd.getTextHeight(font))*0.68,r,font)

      font = FONT_MINI
      if lowTele[idx] and highTele[idx] then
	 r = string.format("%.2f .. %.2f %s", lowTele[idx], highTele[idx],(resultUnitDisp[idx] or "%"))
      else
	 r = "---"
      end

      lcd.drawText(width/2 - lcd.getTextWidth(font,r)/2,(height-lcd.getTextHeight(font))*0.95,r,font)
      if luaCtlMax > 4 then -- looks awful on mono devices
	 lcd.drawImage(5, height*0.75, ":graph")
      end
   end
end 

local function regControl(num, name)
   local idx = 0
   local ctl = "V"..string.format("%02d", num)
   for i=1,luaCtlMax,1 do
      idx = system.registerControl(num, "V-SensXF " .. name, ctl)
      if idx then
	 print(ctl .. " "..idx .." "..name)
	 break
      end
   end
   return idx
end

local function regC(k)
   if k <= luaCtlMax and controlResult[k] > 0 then
      resultIdx[k] = regControl(k, resultName[controlResult[k]])
   end
end

local function regTL(k)
   if k <= 2 then
      local rN
      system.unregisterTelemetry(k)
      if resultName[k] == "" then rN = tostring(k) else rN = resultName[k] end
      system.registerTelemetry(k, "V-SensXF "..rN, 0,
			       (function(x,y) return printTelemetry(x,y,k) end))
   end
   if k <= logFileMax then
      logVariableID[k] = system.registerLogVariable(
	 resultName[k], resultUnit[k],
	 (function(index) return type(result[index]) == "number" and result[index] *100 or nil end),
	 2
      )
      if not logVariableID[k] then logVariableID[k] = 0 end
   end
end

local function unregC()
   for k in ipairs(resultIdx[k]) do
      if k <= luaCtlMax and resultIdx ~= 0 then
	 system.unregisterControl(resultIdx[k])
      end
   end
end

local function unregTL()
   for k in ipairs(condition) do
      --print(k, resultIdx[k], logVariableID[k])
      if k <= 2 then
	 system.unregisterTelemetry(k)
      end
      if k <= logFileMax then
	 if logVariableID[k] and logVariableID[k] ~= 0 then
	    system.unregisterLogVariable(logVariableID[k])
	    logVariableID[k] = 0
	 end
      end
   end
end

local function sensorChanged(val, idx)
   if val>0 then
      sensorId[idx]=sensorsAvailable[val].id
      paramId[idx]=sensorsAvailable[val].param
      system.pSave("sensorId",sensorId)
      system.pSave("paramId",paramId)
   end      
end

local function variableValChanged(val, idx)
   variableValue[idx] = tonumber(val) or "N/A"
   system.pSave("variableValue", variableValue)
   form.reinit(6)
end

local function variableNameChanged(val, idx)
   variableName[idx] = val
   system.pSave("variableName", variableName)
end

local function sensorVarNameChanged(val, idx)
   sensorVarName[idx] = val
   system.pSave("sensorVarName", sensorVarName)
end

local function sensorChangedGPS(val, idx)
   if val>0 then
      if idx == 1 then
	 latID=sensorsAvailableGPS[val].id
	 latParam=sensorsAvailableGPS[val].param
	 system.pSave("latID",latID)
	 system.pSave("latParam", latParam)
      else
	 lngID=sensorsAvailableGPS[val].id
	 lngParam=sensorsAvailableGPS[val].param
	 system.pSave("lngID",lngID)
	 system.pSave("lngParam", lngParam)
      end
   end      
end

local function gpsStrChanged(val, kk, idx)
   local lt, lg = gps.getValue(selectedGPS[kk])
   if idx == 1 then -- lat
      selectedGPS[kk] = gps.newPoint(val, lg)
   else -- lng
      selectedGPS[kk] = gps.newPoint(lt, val)
   end
end

local function textChanged(val, idx)
   resultName[idx] = val
   system.pSave("resultName",resultName)      
   form.reinit(3)
end

local function ctlResChanged(val, idx)
   controlResult[idx] = val
   local row = form.getFocusedRow()
   print("row:", row)
   regC(row)
   resultControl[val] = row
   system.pSave("controlResult", controlResult)
end

local function unitGsub(str)
   local s, n
   for k,v in pairs(unitChars) do
      s, n = string.gsub(str,k,v)
      if n > 0 then return s end
   end
   return str
end

local function unitChanged(val, idx)
   resultUnit[idx] = val
   resultUnitDisp[idx] = unitGsub(resultUnit[idx])
   system.pSave("resultUnit",resultUnit)
end
local function showExternal(fn)
   if tonumber(system.getVersion()) > 5.01 then
      if select(2, system.getDeviceType()) == 1 then
	 system.openExternal("DOCS/V-SENSXF/"..string.upper(locale).."-"..
				string.upper(fn) ..".HTML")
      else
	 system.openExternal("Apps/V-SensXF/Docs/"..locale.."-"..fn..".html")
      end
      return
   end
end

local function helpbutton()
   if(tonumber(system.getVersion()) >= 5.01) then
      form.setButton(1, ":help", ENABLED)
   end
end

local function initForm(formID)

   if(tonumber(system.getVersion()) < 4.28) then
      form.addRow(1)
      form.addLabel({label=lang.fw4})
      return
   end

   print("Memory used:", collectgarbage("count"))
   
   currentForm=formID
   sensorsAvailable = {}
  
  if currentForm == 1 then --  main menu
     form.addRow(1)
     form.addLink((function() form.reinit(2); form.waitForRelease() end),
	{label=lang.TeleSen})

     form.addRow(1)
     form.addLink((function() form.reinit(6); form.waitForRelease() end),
	{label=lang.Var})

     form.addRow(1)
     form.addLink((function() form.reinit(3); form.waitForRelease() end),
	{label=lang.ResExp})	

     form.addRow(1)
     form.addLink((function() form.reinit(7); form.waitForRelease() end),
	{label="Lua functions >>"})

     form.addRow(1)
     form.addLink((function() form.reinit(4); form.waitForRelease() end),
	{label=lang.GPSSen})	

     form.addRow(1)
     form.addLink((function() form.reinit(5); form.waitForRelease() end),
	{label=lang.GPSPt})

     helpbutton()

  elseif currentForm == 2 then -- tele values
    local available = system.getSensors()
    local list = {}
    for index,sensor in ipairs(available) do 
       if(sensor.param ~= 0) then
	  if sensor.type ~= 9 then
	     if sensor.sensorName and string.len(sensor.sensorName) > 0 then
		list[#list+1]=string.format("%s - %s [%s]",sensor.sensorName,sensor.label,sensor.unit)
	     else
		list[#list+1]=string.format("%s [%s]",sensor.label,sensor.unit)
	     end
	     sensorsAvailable[#sensorsAvailable+1] = sensor
	  end
	  for k in ipairs(sensorId) do
	     if(sensor.id == sensorId[k] and sensor.param == paramId[k]) then
		curIndex[k]=#sensorsAvailable
	     end
	  end
       end 
    end
    if #sensorId == 0 then
       form.addRow(1)
       form.addLabel({label=lang.NoTele})
       form.addRow(1)
       form.addLabel({label=lang.PressC})
    end
    for k in ipairs(sensorId) do
       if not curIndex[k] then curIndex[k] = -1 end
       form.addRow(3)
       form.addLabel({label=tostring(k), width=20})
       if not sensorVarName[k] then
	  sensorVarName[k] = "t"..k
	  --print("$$$", #sensorId, k, sensorId[k])
       end
       form.addTextbox(sensorVarName[k], 8, (function(x) return sensorVarNameChanged(x,k) end))
       form.addSelectbox(list,curIndex[k],true,(function(x) return sensorChanged(x,k) end),{width=180})
    end
    form.setButton(2, ":add", ENABLED)
    form.setButton(3, lang.reset, ENABLED)
  elseif currentForm == 3 then -- results
     if #resultName == 0 then
	form.addRow(1)
	form.addLabel({label=lang.NoRes})
	form.addRow(1)
	form.addLabel({label=lang.PressC})
     end
     for k,v in ipairs(resultName) do
	form.addRow(4)
	--form.addLabel({label=lang.Result..k..lang.Name,width=120})
	form.addLabel({label=k,width=30})	
	form.addTextbox (resultName[k], 14,(function(x) return textChanged(x,k) end),{width=140})
	form.addLabel({label=lang.Unit,width=50})
	form.addTextbox (resultUnit[k] or "", 8,(function(x) return unitChanged(x,k) end),{width=100})
	local ss
	if #condition[k] > 23 then
	   ss = string.sub(condition[k], 1, 20) .. "..."
	else
	   ss = condition[k]
	end
	form.addLink((function() form.reinit(9);condIdx=k;form.waitForRelease() end),
	   {label=string.format("%s = %s >>",v,ss),font=FONT_BOLD})
	form.addRow(1)
	form.addLabel({label="-------"})
     end

     helpbutton()
     form.setButton(2, ":add", ENABLED)
     form.setButton(3, lang.reset, ENABLED)
  elseif currentForm == 4 then -- gps sensors
     if(tonumber(system.getVersion()) < 5.0) then
	form.addRow(1)
	form.addLabel({label=fw5})
	return
     end
     local available = system.getSensors()
     local list = {}
     for index,sensor in ipairs(available) do 
	if(sensor.param ~= 0) then
	   if sensor.type and sensor.type == 9 then
	      if sensor.sensorName and string.len(sensor.sensorName) > 0  then
		 list[#list+1]=string.format("%s - %s [%s]",sensor.sensorName,sensor.label,sensor.unit)
	      else
		 list[#list+1]=string.format("%s [%s]",sensor.label,sensor.unit)
	      end
	      sensorsAvailableGPS[#sensorsAvailableGPS+1] = sensor
	   end
	   if(sensor.id == latID and sensor.param == latParam) then
	      latIndex=#sensorsAvailableGPS
	   end
	   if(sensor.id == lngID and sensor.param == lngParam) then
	      lngIndex=#sensorsAvailableGPS
	   end	  
	end 
     end
     
     if not latIndex then latIndex = -1 end
     form.addRow(2)
     form.addLabel({label=lang.GPSLat,width=160})
     form.addSelectbox(list, latIndex,true,(function(x) return sensorChangedGPS(x,1) end),{width=180})
     
     if not lngIndex then lngIndex = -1 end
     form.addRow(2)
     form.addLabel({label=lang.GPSLng,width=160})
     form.addSelectbox(list,lngIndex,true,(function(x) return sensorChangedGPS(x,2) end),{width=180})
     
  elseif currentForm == 5 then -- gps points

     local latN, lngN, latS, lngS

     if(tonumber(system.getVersion()) < 5.0) then
	form.addRow(1)
	form.addLabel({label=fw5})
	return
     end

     if #selectedGPS == 0 then
	form.addRow(1)
	form.addLabel({label=lang.NoGPS})
	form.addRow(1)
	form.addLabel({label=lang.PressC})
     end

     for k,v in ipairs(selectedGPS) do
	if selectedGPS[k] then
	   latN, lngN = gps.getValue(selectedGPS[k])
	else
	   latN, lngN = 0, 0
	end
	latS = string.format("%2.6f", latN)
	lngS = string.format("%2.6f", lngN)
	form.addRow(5)
	form.addLabel({label=k, width=20})
	form.addLabel({label=lang.Lat, width = 40})
	form.addTextbox(latS, 9, (function(x) return gpsStrChanged(x,k,1) end), {width=110})
	form.addLabel({label=lang.Lng, width = 40})
	form.addTextbox(lngS, 9, (function(x) return gpsStrChanged(x,k,2) end), {width=110})
     end
     form.setButton(2, ":add", ENABLED)
     form.setButton(3, lang.reset, ENABLED)

  elseif currentForm == 6 then -- static variables

     if #variableName == 0 then
	form.addRow(1)
	form.addLabel({label=lang.NoStat})
	form.addRow(1)
	form.addLabel({label=lang.PressC})
     end

     for k,v in ipairs(variableName) do
	form.addRow(3)
	form.addLabel({label=tostring(k),width=20})
	form.addTextbox(variableName[k], 8,
			(function(x) return variableNameChanged(x,k) end),
			{width=120})
	local ss = tostring(variableValue[k])
	if ss == 'nil' then ss = lang.na end
	form.addTextbox(ss,8,
			(function(x) return variableValChanged(x, k) end),
			{width = 120})
     end
     form.setButton(2, ":add", ENABLED)
     form.setButton(3, lang.reset, ENABLED)

  elseif currentForm == 7 then -- lua functions

     if #controlResult == 0 then
	form.addRow(1)
	form.addLabel({label="No lua functions set"})
	form.addRow(1)
	form.addLabel({label=lang.PressC})
     end
     
     for k,v in ipairs(controlResult) do
	if not k then controlResult[k] = -1 end

	form.addRow(3)
	form.addLabel({label="Lua control"})
	form.addLabel({label="V"..string.format("%02d",k)})
	form.addSelectbox(resultName, controlResult[k], true,
			  (function(x) return ctlResChanged(x,k) end))	   
     end
     form.setButton(2, ":add", ENABLED)
     form.setButton(3, lang.reset, ENABLED)     

  elseif currentForm == 10 then
     local jsonOK
     local ff = io.readall("Apps/V-SensXF/Exp.jsn")
     expTbl = {}
     if ff then
	jsonOK, expTbl = pcall(json.decode, ff)

	if not jsonOK then
	   print(expTbl)
	   form.addRow(1)
	   form.addLabel({label=lang.jsnSyn})
	   form.addRow(1)
	   form.addLabel({label=lang.seeCon})	   
	   expTbl = {}
	   return
	end
     end
     
     for k,v in ipairs(expTbl) do
	form.addRow(4)
	form.addLabel({label=tostring(k),width=25})
	form.addLabel({label=v.name, width=80})
	form.addLabel({label=v.exp, width=160})
	form.addLabel({label="["..v.unit.."]", width=50})
     end

     helpbutton()
     
  elseif currentForm == 9 then -- edit expression
     local fA = { "*","/","+","-","^","(",
		  ">", "<", ">=", "<=", "==","~=",
		  "and", "or",
		  "0","1","2","3","4","5","6","7","8","9",
		  "abs(","sin(","cos(","atan(","rad(","deg(","sqrt(",
		  "max(", "min(", "floor(",
		  "sign(", "step(","box(","gpsd(", "gpsb(", "pc("
     }

     -- rebuilt the expression element string from the
     -- latest info
     
     fAvailable = {}
     
     for k in ipairs(sensorId) do
	fAvailable[k] = sensorVarName[k]
     end

     for k in ipairs(fA) do
	table.insert(fAvailable, fA[k])
     end

     for k in ipairs(variableName) do
	if variableValue[k] then
	   table.insert(fAvailable, variableName[k])
	end
     end
     
     for k in ipairs(condition) do
	table.insert(fAvailable, resultName[k])
     end
     
     form.setButton(4,":backspace",ENABLED)  
     form.setButton(1, ".", ENABLED)
     form.setButton(2, ",", ENABLED)
     form.setButton(3, ")", ENABLED)
  end
end  

local function keyPressed(key)

   if currentForm == 1 then -- main
      if key == KEY_1 then
	 showExternal("mainhelp")
      end
   elseif currentForm == 2 then -- tele
      if key == KEY_2 then -- plus .. add a tele variable
	 table.insert(sensorId, 0)
	 table.insert(paramId, 0)
	 table.insert(sensorVarName, "t"..#sensorId)
	 system.pSave("sensorId", sensorId)
	 system.pSave("paramId", paramId)
	 system.pSave("sensorVarName", sensorVarName)
	 curIndex[#sensorId] = -1
	 recomputeCond() --recompute everyting to be safe 
	 form.reinit(2)
      elseif key == KEY_3 then -- reset .. remove all variables
	 env = nil -- will recompute
	 sensorId = {}
	 paramId = {}
	 sensorVarName = {}
	 system.pSave("sensorId", sensorId)
	 system.pSave("paramId", paramId)
	 system.pSave("sensorVarName", sensorVarName)
	 recomputeCond()
	 form.reinit(2)
      elseif key == KEY_ESC or key == KEY_5 then
	 sensorsAvailable = {}
	 form.reinit(1)
	 form.preventDefault()
      end
   elseif currentForm == 3 then -- results
      if key == KEY_1 then
	 showExternal("reshelp")
	 
      elseif key == KEY_2 then -- plus .. add a result
	 table.insert(resultName, "Result " .. (#resultName+1))
	 table.insert(resultUnit, "")
	 system.pSave("resultName", resultName)
	 system.pSave("resultUnit", resultUnit)
	 table.insert(condition, "")
	 table.insert(conditionChanged, true)
	 system.pSave("condition", condition)
	 fIndex[#condition] = 1
	 regTL(#condition)
	 recomputeCond()
	 form.reinit(3)
      elseif key == KEY_3 then -- reset
	 env = nil -- will recompute
	 unregTL()
	 resultName = {}
	 resultUnit = {}
	 condition = {}
	 chunk = {}
	 fIndex = {}
	 system.pSave("condition", condition)
	 system.pSave("resultName", resultName)
	 system.pSave("resultUnit", resultUnit)
	 form.reinit(3)
      elseif key == KEY_5 or key == KEY_ESC then
	 form.reinit(1)
	 form.preventDefault()
      end
   elseif currentForm == 4 then
      if key == KEY_5 or key == KEY_ESC then
	 sensorsAvailableGPS = {}	 
	 form.reinit(1)
	 form.preventDefault()
      end
   elseif currentForm == 5 then
      if key == KEY_2 then
	 table.insert(selectedGPS, gps.newPoint(0,0))
	 system.pSave("selectedGPS", selectedGPS)
	 form.reinit(5)
      elseif key == KEY_3 then
	 env = nil -- will recompute
	 selectedGPS = {}
	 system.pSave("selectedGPS", selectedGPS)
	 gpsReads = 0
	 form.reinit(5)
      elseif key == KEY_5 or key == KEY_ESC then
	 form.reinit(1)
	 form.preventDefault()
      end
   elseif currentForm == 6 then
      if key == KEY_2 then
	 table.insert(variableName, "v"..(#variableName+1))
	 table.insert(variableValue, 0)
	 system.pSave("variableName", variableName)
	 system.pSave("variableValue", variableValue)
	 form.reinit(6)
      elseif key == KEY_3 then
	 variableName = {}
	 variableValue = {}
	 system.pSave("variableName", variableName)
	 system.pSave("variableValue", variableValue)
	 form.reinit(6)
      elseif key == KEY_5 or key == KEY_ESC then
	 form.reinit(1)
	 form.preventDefault()
      end
   elseif currentForm == 7 then
      if key == KEY_2 then
	 if #controlResult >= luaCtlMax then return end
	 table.insert(controlResult, -1)
	 system.pSave("controlResult", controlResult)
	 form.reinit(7)
      elseif key == KEY_3 then
	 unregC()
	 controlResult = {}
	 resultIdx = {}
	 system.pSave("controlResult", controlResult)
	 system.pSave("resultIdx", resultIdx)
	 form.reinit(7)
      elseif key == KEY_5 or key == KEY_ESC then
	 form.reinit(1)
	 form.preventDefault()
      end
   elseif currentForm == 9 then -- edit expression
      if(key == KEY_DOWN) then
	 fIndex[condIdx] = fIndex[condIdx]-1
	 if fIndex[condIdx] == 0 then fIndex[condIdx] = #fAvailable end
      elseif(key == KEY_UP) then
	 fIndex[condIdx] = fIndex[condIdx]+1
	 if fIndex[condIdx] == #fAvailable +1 then fIndex[condIdx] = 1 end
      elseif(key == KEY_ENTER) then
	 condition[condIdx] = condition[condIdx] .. fAvailable[fIndex[condIdx]]
	 form.waitForRelease()
      elseif (key == KEY_MENU) then
	 form.preventDefault()
	 form.reinit(10)
	 --condition = ""
      elseif (key == KEY_1) then
	 condition[condIdx] = condition[condIdx] .. "." 
      elseif (key == KEY_2) then
	 condition[condIdx] = condition[condIdx] .. ","
      elseif (key == KEY_3) then
	 condition[condIdx] = condition[condIdx] .. ")"
      elseif(key == KEY_4) then 
	 condition[condIdx] = string.sub(condition[condIdx],1,-2)
      elseif(key == KEY_ESC or key == KEY_5) then
	 form.reinit(3)
	 form.preventDefault()                         
      end
      system.pSave("condition",condition)      
      recomputeCond()
   elseif currentForm == 10 then
      local row = form.getFocusedRow()
      if key == KEY_1 and expTbl[row].help then
	 showExternal("exp-" .. expTbl[row].help)
      elseif key == KEY_ESC or key == KEY_5 then
	 form.reinit(9)
	 form.preventDefault()                         
      end
      if key == KEY_ENTER then
	 --local row = form.getFocusedRow()
	 if #expTbl == 0 then
	    form.reinit(9)
	    return
	 end
	 condition[condIdx] = expTbl[row].exp
	 resultName[condIdx] = expTbl[row].name
	 resultUnit[condIdx] = expTbl[row].unit
	 form.reinit(9)
      end
   end
end  

local function printForm()
   if currentForm == 9 then                     
      local r = string.format("%s: %s",resultName[condIdx],formattedResult(condIdx))
      lcd.drawText(lcd.width - 10 - lcd.getTextWidth(FONT_BIG,r),120,r, FONT_BIG)
      local len = #condition[condIdx]
      local ss = string.sub(condition[condIdx], math.max(len-30, 1), len)
      if len > 31 then
	 ss = "..." .. ss
      end
      
      lcd.drawText(10,20,ss or "",FONT_BIG) 
      local x=25
      local font, wid
      if not fIndex[condIdx] then fIndex[condIdx] = 1 end
      for i = fIndex[condIdx] - 3, fIndex[condIdx] + 3,1 do
	 if i < 1 then
	    i = i + #fAvailable 
	 elseif i > #fAvailable then
	    i = i - #fAvailable
	 end
	 if i == fIndex[condIdx] then font = FONT_BIG else font = FONT_NORMAL end
	 wid = lcd.getTextWidth(font, fAvailable[i])
	 lcd.drawText(x-wid/2,70 - lcd.getTextHeight(font)/2,fAvailable[i],font)
	 x = x + 36 + wid*.65 -- empirical
      end
   end
end  

local function propCtlP(t, min, max)
   -- if min and max defined, then range is min to max
   -- if min only defined, then range is 0 to min
   -- if no min and no max then range is -1 to 1
   local st = tostring(math.floor(t))
   if min and max then
      return min + (max - min) * (1 + system.getInputs("P"..st)) / 2
   elseif min then
      return min*(system.getInputs("P"..st) + 1)/2
   else
      return system.getInputs("P"..st)
   end
end

local err, status

local lastT

local function loop() 
   
   if not env then
      env = {
	 abs =  math.abs,
	 sin =  math.sin, 
	 cos =  math.cos, 
	 rad =  math.rad,
	 deg =  math.deg,
	 min = math.min,
	 max = math.max,
	 atan = math.atan,
	 sqrt = math.sqrt,
	 floor = math.floor,
	 step = (function(a1,a2,a3)
	       if math.abs(a1-a2) <= math.abs(a3) then
		  return 0 else
		     return (a1-a2) / math.abs(a1-a2) end end),
	 box = (function(a1,a2,a3)
	       if math.abs(a1-a2) <= math.abs(a3) then
		  return 0 else return 1 end end),
	 pc = (function(a1,a2,a3) return propCtlP(a1, a2, a3) end),
	 gpsd = (function(a1)
	       if currentGPS and selectedGPS[a1] then
		  return gps.getDistance(currentGPS, selectedGPS[a1]) or 0
	       else
		  return 0
		end end),
	 gpsb = (function(a1)
	       if currentGPS and selectedGPS[a1] then
		  return gps.getBearing(currentGPS, selectedGPS[a1]) or 0
	       else
		  return 0
		end end),
	 sign = (function(a1)
	       if a1 > 0 then return 1 elseif a1 < 0 then return -1 else return 0 end end)
      }
   end

   updateValues()  

   for k in ipairs(sensorId) do
      if sensorVarName[k] then
	 env[sensorVarName[k]] = value[k] or 0
      end
   end
   
   for k in ipairs(variableName) do
      if variableValue[k] then
	 env[variableName[k]] = variableValue[k]
      end
   end

   for k in ipairs(condition) do
      if conditionChanged[k] == true then
	 chunk[k], err = load("return "..condition[k],"","t",env)
	 if err then
	    print(lang.Result..k..lang.expErr .. string.sub(err, 15))
	 else
	    print(lang.Result..k..lang.expVal)
	 end
	 conditionChanged[k] = false
      end
   end

   for k in ipairs(condition) do
      if type(result[k]) == "number" then
	 env[resultName[k]] = result[k]
      end
   end
   
   for k in ipairs(condition) do
      if (chunk[k]) then
	 status,result[k] = pcall(chunk[k])
	 if type(result[k]) == "number" or type(result[k]) == "boolean" then
	    if result[k] == false then result[k] = 0 end
	    if result[k] == true then result[k] = 1 end
	    result[k] = result[k] or ""
	 else
	    result[k] = lang.na
	 end
      else
	 result[k] = lang.nc
      end
   end

   for k,v in ipairs(controlResult) do
      print("k,v,r[v]", k,v, result[v])
      if resultIdx[k] and type(result[v]) == "number" and result[v] ~= -1 then
	 if result[v] >= -1.0 and result[v] <= 1.0 then
	    print("sC", resultIdx[k], result[v])
	    if system.setControl(resultIdx[k], result[v], 0) then
	       controlValue[k] = result[k]
	    end
	 end
      end
   end

   --[[
   if system.getTime() ~= lastT then
      print(system.getCPU())
      lastT = system.getTime()
   end
   --]]
end

local function init()

   local monoDev = {"JETI DC-16", "JETI DS-16", "JETI DC-14", "JETI DS-14"}

   luaCtlMax = 10 -- assume not mono
   logFileMax = 24 -- ditto
   
   local dev = system.getDeviceType()

   for k,v in ipairs(monoDev) do
      if dev == v then luaCtlMax = 4; logFileMax = 8; print("Mono") break end
   end
   
   sensorId = system.pLoad("sensorId", {})
   paramId = system.pLoad("paramId", {})
   sensorVarName = system.pLoad("sensorVarName", {})
   variableName = system.pLoad("variableName", {})
   variableValue = system.pLoad("variableValue", {})
   controlResult = system.pLoad("controlResult", {})
   condition = system.pLoad("condition",{})

   latID = system.pLoad("latID")
   lngID = system.pLoad("lngID")
   latParam = system.pLoad("latParam")
   lngParam = system.pLoad("lngParam")
   
   recomputeCond()

   resultName = system.pLoad("resultName",{})
   resultUnit = system.pLoad("resultUnit",{})
   for k,v in ipairs(resultUnit) do
      resultUnitDisp[k] = unitGsub(v)
   end
   
   system.registerForm(1,MENU_APPS,"V-SensXF",initForm,keyPressed,printForm);

   for k in ipairs(condition) do
      regTL(k)
   end

   local mc = #controlResult
   for k=1,mc,1 do
      regC(k)
   end
   local mr = #resultIdx
   for k =1,mr,1 do
      for j = 1,mc,1 do
	 if controlResult[j] == k then print(j,k); resultControl[k] = j end
      end
   end

   for k,v in ipairs(controlResult) do
      print("cr",k,v)
   end
   for k,v in ipairs(resultControl) do
      print("rc",k,v)
   end
   
   
   system.getSensors()

   collectgarbage()
   
   print("Memory used:", collectgarbage("count"))
   
end

setLanguage()

--------------------------------------------------------------------

return { init=init, loop=loop, author="JETI model and DFM", version="2.3",name="V-SensXF"}
