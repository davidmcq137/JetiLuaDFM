-- ############################################################################# 
-- #
-- # Companion announcement system for the V-Sensor app.
-- #
-- # Copyright (c) 2022, DFM
-- # All rights reserved
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
-- # Initially created 04/13/22 DFM
-- #
-- #############################################################################

local Ann = {}

local lang, locale
local currForm 
local result
local resultName

local irow
local selResult 
local annType 
local annPeriod 
local annAutoMin
local annAutoMax
local annAutoSF
local annDecimal
local annResultWav
local annUnitWav
local annEdgeDir
local annFiles
local annEnableSw
local annNextTime
local annLastResult
local annLastTime
local annBuzzPulse
local annBuzzSide
local stickSide
local stickForm

local default = {Period=10, AutoMin=5, AutoMax=40, AutoSF=10, Decimal=0}
	    
local annTypes
local edgeTypes
local buzzTypes
local buzzSides

local function setLanguage()
   locale=system.getLocale()
   local tf1 = "Apps/V-SensXF/Lang/"
   local tf2 = "-localeAnn.jsn"
   local file = io.readall(tf1..locale..tf2)
   if not file then
      locale = "en"
      file = io.readall(tf1..locale..tf2)
   end
   if not file then print("No V-Ann language file found") else
      local obj = json.decode(file)
      if(obj) then
	 lang = obj[locale]
      end
   end
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

local function playNumber(num, dec)
   local sign, playNum
   if num >= 0 then sign = 1 else sign = -1 end
   playNum = sign * math.floor(math.abs(num) * (10^dec) + 0.5) / (10^dec)
   system.playNumber(playNum, dec)
end

local function playResult(k, ff)
   local fn = "/Apps/V-SensXF/Audio/" .. system.getLocale().."/"
   if (not annResultWav[k]) or (annResultWav[k] == 1) then
      system.playFile(fn.."Result.wav", AUDIO_QUEUE)
      system.playNumber(k, 0)
      if ff then
	 system.playFile(ff, AUDIO_QUEUE)
      end
   else
      system.playFile(fn..annFiles[annResultWav[k]], AUDIO_QUEUE)
   end
end

local function resultChanged(val, k)
   print("selResult, k, val", k, val)
   selResult[k] = val
   system.pSave("selResult", selResult)
end

local function typeChanged(val, k)
   annType[k] = val
   system.pSave("annType", annType)
end

local function perChanged(val,k)
   annPeriod[k] = val
   system.pSave("annPeriod", annPeriod)
end

local function minChanged(val, k)
   annAutoMin[k] = val
   system.pSave("annAutoMin", annAutoMin)
end

local function maxChanged(val, k)
   annAutoMax[k] = val
   system.pSave("annAutoMax", annAutoMax)
end

local function SFChanged(val, k)
   annAutoSF[k] = val
   system.pSave("annAutoSF", annAutoSF)
end

local function decimalChanged(val,k)
   annDecimal[k] = val
   system.pSave("annDecimal", annDecimal)
end

local function edgeChanged(val, k)
   annEdgeDir[k] = val
   system.pSave("annEdgeDir", annEdgeDir)
end

local function unitWavChanged(val,k)
   annUnitWav[k] = val
   system.pSave("annUnitWav", annUnitWav)
end

local function resultWavChanged(val,k)
   annResultWav[k] = val
   system.pSave("annResultWav", annResultWav)
end

local function enableChanged(val, k)
   annEnableSw[k] = val
   local ret = system.pSave("annEnableSw"..k, annEnableSw[k])
end

local function sideChanged(val, k)
   annBuzzSide[k] = val
   system.pSave("annBuzzSide", annBuzzSide)
end

local function pulseChanged(val, k)
   annBuzzPulse[k] = val
   system.pSave("annBuzzPulse", annBuzzPulse)
end

local time0 = system.getTimeCounter()

function Ann.init(r,rN)
   result = r
   resultName = rN

   annTypes  = {lang.prc, lang.aut, lang.edg}
   edgeTypes = {lang.ris, lang.fal}
   buzzTypes = {lang.non, lang.lp, lang.sp, lang.sp2, lang.sp3}
   buzzSides = {lang.lef, lang.rig}

   selResult    = system.pLoad("selResult",    {})
   annType      = system.pLoad("annType",      {})
   annPeriod    = system.pLoad("annPeriod",    {})
   annAutoMin   = system.pLoad("annAutoMin",   {})
   annAutoMax   = system.pLoad("annAutoMax",   {})
   annAutoSF    = system.pLoad("annAutoSF",    {})
   annDecimal   = system.pLoad("annDecimal",   {})
   annResultWav = system.pLoad("annResultWav", {})
   annUnitWav   = system.pLoad("annUnitWav",   {})
   annEdgeDir   = system.pLoad("annEdgeDir",   {})
   annEnableSw = {}
   for k in ipairs(selResult) do
      annEnableSw[k] = system.pLoad("annEnableSw"..k)
   end
   annBuzzPulse = system.pLoad("annBuzzPulse",  {})
   annBuzzSide  = system.pLoad("annBuzzSide",   {})   

   annNextTime = {}
   annLastTime = {}
   annLastResult = {}
   
   local path
   local dd, fn, ext

   path = "Apps/V-SensXF/Audio/"
   
   if select(2, system.getDeviceType()) ~= 1 then
      path = "/" .. path
   end      

   path = path .. system.getLocale()
   
   annFiles = {}
   
   for name, filetype, size in dir(path) do
      dd, fn, ext = string.match(name, "(.-)([^/]-)%.([^/]+)$")
      if fn and ext then
	 if string.lower(ext) == "wav" then
	    table.insert(annFiles, fn .. "." .. ext)
	 end
      end
   end
   
   if #annFiles < 1 then
      --system.messageBox("No wav files found")
   else
      table.sort(annFiles, function(a,b) return a<b end)
   end

   table.insert(annFiles, 1, "...")
   
end

function Ann.cmd(formIdx)

   currForm = formIdx
   
   if formIdx == 100 then
      if #selResult == 0 then
	 form.addRow(1)
	 form.addLabel({label=lang.nores})
	 form.addRow(1)
	 form.addLabel({label=lang.plus})	 
      else
	 for k in ipairs(selResult) do
	    if not selResult[k] then
	       selResult[k] = resultName[k]
	    end
	    if not annType[k] then annType[k] = 1 end
	    form.addRow(4)
	    form.addLabel({label=k,width=30})
	    form.addSelectbox(resultName, selResult[k], true,
			      (function(x) return resultChanged(x,k) end),{width=120})
	    form.addLabel({label="Type",width=50})
	    form.addSelectbox(annTypes, annType[k], true,
			      (function(x) return typeChanged(x,k) end), {width=120})
	 end
      end
      form.setButton(1, ":help", ENABLED)
      form.setButton(2, ":add", ENABLED)
      form.setButton(3, lang.rst, ENABLED)
      form.setButton(4, lang.edi, ENABLED)
   elseif formIdx == 101 or formIdx == 102 or formIdx == 103 then

      form.addRow(2)
      form.addLabel({label=lang.ens, width=140})
      form.addInputbox(annEnableSw[irow], true,
		       (function(x) return enableChanged(x,irow) end), {width=180})
      
      form.addRow(2)
      form.addLabel({label=lang.rna, width=140})
      if not annResultWav[irow] then annResultWav[irow] = 1 end
      form.addSelectbox(annFiles, annResultWav[irow], true,
			(function(x) return resultWavChanged(x,irow) end), {width=180})

      if formIdx ~= 103 then
	 form.addRow(2)
	 form.addLabel({label=lang.una, width=140})      
	 if not annUnitWav[irow] then annUnitWav[irow] = 1 end
	 form.addSelectbox(annFiles, annUnitWav[irow], true,
			   (function(x) return unitWavChanged(x,irow) end), {width=180})
      end

      if formIdx == 101 or formIdx == 102 then
	 form.addRow(2)
	 form.addLabel({label=lang.dp})
	 if not annDecimal[irow] then annDecimal[irow] = 0 end
	 form.addIntbox(annDecimal[irow], 0, 2, 0, 0, 1,
			(function(x) return decimalChanged(x, irow) end))
      end
      
      if formIdx == 101 then 
	 form.addRow(2)
	 form.addLabel({label=lang.per})
	 if not annPeriod[irow] then annPeriod[irow] = 10 end
	 form.addIntbox(annPeriod[irow], 2, 1000, 10, 0, 1,
			(function(x) return perChanged(x, irow) end))
      elseif formIdx == 102 then
	 form.addRow(2)
	 form.addLabel({label=lang.min})
	 if not annAutoMin[irow] then annAutoMin[irow] = 2 end
	 form.addIntbox(annAutoMin[irow], 2, 100, 2, 0, 1,
			(function(x) return minChanged(x, irow) end))
	 
	 form.addRow(2)
	 form.addLabel({label=lang.max})
	 if not annAutoMax[irow] then annAutoMax[irow] = 2 end
	 form.addIntbox(annAutoMax[irow], 30, 1000, 30, 0, 1,
			(function(x) return maxChanged(x, irow) end))
	 
	 form.addRow(2)
	 form.addLabel({label=lang.csf})
	 if not annAutoSF[irow] then annAutoSF[irow] = 2 end
	 form.addIntbox(annAutoSF[irow], 1, 10000, 10, 0, 1,
			(function(x) return SFChanged(x, irow) end))
      elseif formIdx == 103 then
	 form.addRow(2)
	 form.addLabel({label=lang.etd, width=220})
	 if not annEdgeDir[irow] then annEdgeDir[irow] = 1 end
	 form.addSelectbox(edgeTypes, annEdgeDir[irow], true,
			   (function(x) return edgeChanged(x,irow) end),{width=120})

	 if not annBuzzPulse[irow] then annBuzzPulse[irow] = 1 end
	 if not annBuzzSide[irow] then annBuzzSide[irow] = 1 end
	 form.addRow(3)
	 form.addLabel({label=lang.stk, width=100})
	 form.addSelectbox(buzzSides, annBuzzSide[irow], true,
			   (function(x) return sideChanged(x,irow) end), {width=70})
	 form.addSelectbox(buzzTypes, annBuzzPulse[irow], true,
			   (function(x) return pulseChanged(x,irow) end), {width=150})
      end
   end
end

function Ann.key(key, formIdx)
   if formIdx == 100 then
      if key == KEY_5 or key == KEY_ESC then
	 form.reinit(1)
	 form.preventDefault()
      elseif key == KEY_1 then
	 showExternal("annhelp")
      elseif key == KEY_3 or key == KEY_2 then
	 if key == KEY_2 then
	    table.insert(annType, 1)
	    table.insert(selResult, -1)
	    table.insert(annPeriod, default.Period)
	    table.insert(annAutoMin, default.AutoMin)
	    table.insert(annAutoMax, default.AutoMax)
	    table.insert(annAutoSF, default.AutoSF)
	    table.insert(annDecimal, default.Decimal)
	    table.insert(annEdgeDir, 1)
	    table.insert(annBuzzSide, 1)
	    table.insert(annBuzzPulse, 1)
	 elseif key == KEY_3 then
	    annType      = {}
	    selResult    = {}
	    annPeriod    = {}
	    annAutoMax   = {}
	    annAutoMin   = {}
	    annAutoSF    = {}
	    annResultWav = {}
	    annUnitWav   = {}
	    annDecimal   = {}
	    annEdgeDir   = {}
	    annEnableSw  = {}
	    annNextTime  = {}
	    annBuzzSide  = {}
	    annBuzzPulse = {}
	 end
	 system.pSave("annType", annType)
	 system.pSave("selResult", selResult)
	 system.pSave("annPeriod", annPeriod)
	 system.pSave("annAutoMax", annAutoMax)
	 system.pSave("annAutoMin", annAutoMin)
	 system.pSave("annAutoSF", annAutoSF)
	 system.pSave("annDecimal", annDecimal)
	 system.pSave("annResultWav", annResultWav)
	 system.pSave("annUnitWav", annUnitWav)	 
	 system.pSave("annEdgeDir", annEdgeDir)
	 system.pSave("annBuzzSide", annBuzzSide)
	 system.pSave("annBuzzPulse", annBuzzPulse)
	 
	 for i in ipairs(annEnableSw) do
	    system.pSave("annEnableSw"..i, annEnableSw[i])
	 end
	 form.reinit(100)
      elseif key == KEY_4 then
	 irow = form.getFocusedRow()
	 --print("irow", irow)
	 if annType[irow] == 1 then
	    form.reinit(101)
	 elseif annType[irow] == 2 then
	    form.reinit(102)
	 elseif annType[irow] == 3 then
	    form.reinit(103)
	 end
      end
   elseif formIdx == 101 then
      if key == KEY_5 or key == KEY_ESC then
	 form.reinit(100)
	 form.preventDefault()
      end
   elseif formIdx == 102 then
      if key == KEY_5 or key == KEY_ESC then
	 form.reinit(100)
	 form.preventDefault()
      end
   elseif formIdx == 103 then
      if key == KEY_5 or key == KEY_ESC then
	 form.reinit(100)
	 form.preventDefault()
      end
   end
end

function Ann.loop()

   local swe
   local now = system.getTimeCounter()
   local fn
   local ratio, delta
   
   for k,j in ipairs(selResult) do
      swe = system.getInputsVal(annEnableSw[k])
      if swe and swe == 1 and type(result[j]) == "number" then
	 if not annLastResult[k] then annLastResult[k] = result[j] end
	 if not annLastTime[k] then annLastTime[k] = 0 end
	 if not annNextTime[k] then annNextTime[k] = 0 end
	 if annType[k] == 1 or annType[k] == 2 then -- Periodic or Auto
	    if annType[k] == 2 then -- Auto
	       ratio = math.min(math.max(math.abs((result[j]-annLastResult[k])/annAutoSF[k]),
					 0.5), 10)
	       delta = math.min(annAutoMin[k]*10/ratio, annAutoMax[k])
	       annNextTime[k] = annLastTime[k] + delta * 1000
	    end
	    if (now > annNextTime[k]) and (not system.isPlayback()) then
	       fn = "/Apps/V-SensXF/Audio/" .. system.getLocale().."/"
	       playResult(k)
	       system.playNumber(result[j], annDecimal[k])
	       if annUnitWav[k] and annUnitWav[k] > 1 then
		  --print("units", annFiles[annUnitWav[k]])
		  system.playFile(fn ..annFiles[annUnitWav[k]], AUDIO_QUEUE)
	       end
	       if annType[k] == 1 then -- Periodic
		  annNextTime[k] = now + annPeriod[k] * 1000
	       end
	       annLastResult[k] = result[j]
	       annLastTime[k] = now
	    end
	 elseif annType[k] == 3 then --Edge
	    local rightStick
	    if annBuzzSide[k] == 1 then rightStick = false else rightStick = true end
	    if not annBuzzPulse[k] then annBuzzPulse[k] = 1 end
	    if annEdgeDir[k] == 1 then -- rising edge
	       if result[j] > 0.5 and annLastResult[k] < 0.5 then
		  annLastTime[k] = now
		  fn = "/Apps/V-SensXF/Audio/" .. system.getLocale().."/rising_edge.wav"
		  playResult(j, fn)
		  system.vibration(rightStick, annBuzzPulse[k]-1)
	       end
	    else -- falling edge
	       if result[j] < 0.5 and annLastResult[k] > 0.5 then
		  annLastTime[k] = now
		  fn = "/Apps/V-SensXF/Audio/" .. system.getLocale().."/falling_edge.wav"
		  playResult(j, fn)
		  system.vibration(rightStick, annBuzzPulse[k]-1)		  
	       end
	    end
	    annLastResult[k] = result[j]
	 end
      end
   end
end

setLanguage()

collectgarbage()

return Ann
