local Ann = {}

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

local annTypes = {"Periodic", "Auto", "Edge"}

local function resultChanged(val, k)
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


function Ann.init(r, rN)
   result = r
   resultName = rN
   selResult = system.pLoad("selResult", {})
   annType = system.pLoad("annType", {})
   annPeriod = system.pLoad("annPeriod", {})
   annAutoMin = system.pLoad("annAutoMin", {})
   annAutoMax = system.pLoad("annAutoMax", {})
   annAutoSF = system.pLoad("annAutoSF", {})
   annDecimal = system.pLoad("annDecimal", {})
   
   return
end

function Ann.cmd(formIdx)

   currForm = formIdx
   
   if formIdx == 100 then
      if #selResult == 0 then
	 form.addRow(1)
	 form.addLabel({label="No Results to announce"})
	 form.addRow(1)
	 form.addLabel({label="Press + to create"})	 
      else
	 for k in ipairs(selResult) do
	    if not selResult[k] then selResult[k] = -1 end
	    if not annType[k] then annType[k] = -1 end
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
      form.setButton(3, "Reset", ENABLED)
      form.setButton(4, "Edit", ENABLED)
   elseif formIdx == 101 then -- Periodic
      print("101 - irow", irow)
      form.addRow(2)
      form.addLabel({label="Period (secs)"})
      if not annPeriod[irow] then annPeriod[irow] = 10 end
      form.addIntbox(annPeriod[irow], 2, 1000, 10, 0, 1,
		     (function(x) return perChanged(x, irow) end))
      form.addRow(2)
      form.addLabel({label="Decimal places"})
      if not annDecimal[irow] then annDecimal[irow] = 0 end
      form.addIntbox(annDecimal[irow], 0, 2, 0, 0, 1,
		     (function(x) return decimalChanged(x, irow) end))
      
   elseif formIdx == 102 then -- Auto
      form.addRow(2)
      form.addLabel({label="Min Interval (sec)"})
      if not annAutoMin[irow] then annAutoMin[irow] = 2 end
      form.addIntbox(annAutoMin[irow], 2, 100, 2, 0, 1,
		     (function(x) return minChanged(x, irow) end))

      form.addRow(2)
      form.addLabel({label="Max Interval (sec)"})
      if not annAutoMax[irow] then annAutoMax[irow] = 2 end
      form.addIntbox(annAutoMax[irow], 30, 1000, 30, 0, 1,
		     (function(x) return maxChanged(x, irow) end))

      form.addRow(2)
      form.addLabel({label="Change Scale Factor"})
      if not annAutoSF[irow] then annAutoSF[irow] = 2 end
      form.addIntbox(annAutoSF[irow], 1, 10000, 100, 0, 1,
		     (function(x) return SFChanged(x, irow) end))
   end
end

function Ann.key(key, formIdx)
   --print("Ann.key " .. key, formIdx)
   if formIdx == 100 then
      if key == KEY_5 or key == KEY_ESC then
	 form.reinit(1)
	 form.preventDefault()
      elseif key == KEY_1 then
	 print("help")
      elseif key == KEY_3 or key == KEY_2 then
	 if key == KEY_2 then
	    print("add")
	    table.insert(annType, 1)
	    table.insert(selResult, -1)
	    table.insert(annPeriod, 10)
	    table.insert(annAutoMin, 2)
	    table.insert(annAutoMax, 40)
	    table.insert(annAutoSF, 100)
	    table.insert(annDecimal, 0)
	 elseif key == KEY_3 then
	    print("Reset")
	    annType = {}
	    selResult = {}
	    annPeriod = {}
	    annAutoMax = {}
	    annAutoMin = {}
	    annAutoSF = {}
	    annDecimal = {}
	 end
	 print("saving")
	 system.pSave("annType", annType)
	 system.pSave("selResult", selResult)
	 system.pSave("annPeriod", annPeriod)
	 system.pSave("annAutoMax", annAutoMax)
	 system.pSave("annAutoMin", annAutoMin)
	 system.pSave("annAutoSF", annAutoSF)
	 system.pSave("annDecimal", annDecimal)	 	 
	 form.reinit(100)
      elseif key == KEY_4 then
	 print("edit")
	 irow = form.getFocusedRow()
	 print("irow", irow)
	 if annType[irow] == 1 then
	    form.reinit(101)
	 elseif annType[irow] == 2 then
	    form.reinit(102)
	 elseif annType[irow] == 3 then
	    
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
   end
   return
end

function Ann.loop()
   return
end

return Ann
