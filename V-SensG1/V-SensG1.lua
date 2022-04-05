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
-- # V1.0 - Initial release from Jeti
-- # V1.1 - DFM 03/28/22 modified to add a lua control that tracks result and added some
-- #                     additional utility functions
-- # V1.2 - DFM 03/31/22 changing name to V-SensXF
-- #
-- #############################################################################


--------------------------------------------------------------------
local sensor1Id, param1Id
local sensor2Id, param2Id
local paramName, paramUnit
local sensorsAvailable = {}
local value1, value2
local condition  = ""
local conditionChanged=false
local fAvailable = {
   "t1", "t2",
   "*","/","+","-","(",
   ">", "<", ">=", "<=", "==","~=",
   "0","1","2","3","4","5","6","7","8","9",
   "abs(","sin(","cos(","atan(","rad(","deg(","step(","box(","pc("
}
local fIndex = 1
local result = ""
local currentForm=1
local linkIdx=0
local resultIdx
local controlValue

local function updateValues()
   local sensorData
   if(sensor1Id and param1Id) then
      sensorData = system.getSensorByID(sensor1Id,param1Id)
      if(sensorData and sensorData.valid) then
	 value1 =  sensorData.value
      end   
   end  
   if(sensor2Id and param2Id) then
      sensorData = system.getSensorByID(sensor2Id,param2Id)  
      if(sensorData and sensorData.valid) then
	 value2 =  sensorData.value
      end 
   end
end

local function sensor1Changed(value)
  if value>0 then
    sensor1Id=sensorsAvailable[value].id
    param1Id=sensorsAvailable[value].param
    system.pSave("sensor1",sensor1Id)
    system.pSave("param1",param1Id)
  end      
end
local function sensor2Changed(value)
  if value>0 then
    sensor2Id=sensorsAvailable[value].id
    param2Id=sensorsAvailable[value].param
    system.pSave("sensor2",sensor2Id)
    system.pSave("param2",param2Id)
  end      
end

local function textChanged(value)
   paramName = value
   system.pSave("name",value)      
end
local function unitChanged(value)
   paramUnit = value
   system.pSave("unit",value)      
end

local function initForm(formID)
  currentForm=formID
  fIndex = 1
  sensorsAvailable = {}
  if(currentForm == 1) then
    local available = system.getSensors()
    local list={}
    local cur1Index,cur2Index = -1, -1 
    for index,sensor in ipairs(available) do 
      if(sensor.param ~= 0) then 
        if(sensor.sensorName and string.len(sensor.sensorName) > 0) then
          list[#list+1]=string.format("%s - %s [%s]",sensor.sensorName,sensor.label,sensor.unit)
        else
          list[#list+1]=string.format("%s [%s]",sensor.label,sensor.unit)
        end
        sensorsAvailable[#sensorsAvailable+1] = sensor
        if(sensor.id==sensor1Id and sensor.param==param1Id) then
          cur1Index=#sensorsAvailable
        end
        if(sensor.id==sensor2Id and sensor.param==param2Id) then
          cur2Index=#sensorsAvailable
        end
      end 
    end 
    form.addRow(2)
    form.addLabel({label="Tele sensor 1 (t1)",width=130})
    form.addSelectbox (list, cur1Index,true,sensor1Changed,{width=180})
    form.addRow(2)
    form.addLabel({label="Tele sensor 2 (t2)",width=130})
    form.addSelectbox (list, cur2Index,true,sensor2Changed,{width=180})
    form.addRow(2)
    form.addLabel({label="Result name",width=130})
    form.addTextbox (paramName, 14,textChanged,{width=180})
    form.addRow(2)
    form.addLabel({label="Result unit",width=130})
    form.addTextbox (paramUnit, 4,unitChanged,{width=180})
    
    form.addSpacer(300,8)
    form.addLink((function() form.reinit(2);form.waitForRelease() end),{label=string.format("%s = %s >>","Result",condition),font=FONT_BOLD})
    form.setButton(4,":tools",ENABLED)
  else -- Form 2
    form.setButton(4,":backspace",ENABLED)  
    form.setButton(1, ".", ENABLED)
    form.setButton(2, ",", ENABLED)
    form.setButton(3, ")", ENABLED)
  end
end  

local function keyPressed(key)

   if currentForm == 1 then
    if(key == KEY_4) then 
      form.reinit(2)
    elseif(key == KEY_ESC or key == KEY_5) then
      sensorsAvailable = {} 
    end   
  else  --Current form = 2
    if(key == KEY_DOWN) then
      fIndex = fIndex-1
      if fIndex == 0 then fIndex = #fAvailable end
    elseif(key == KEY_UP) then
      fIndex = fIndex+1
      if fIndex == #fAvailable +1 then fIndex = 1 end
    elseif(key == KEY_ENTER) then
      condition = condition .. fAvailable[fIndex]
      conditionChanged = true
      system.pSave("cond",condition)
      form.waitForRelease()
    elseif (key == KEY_MENU) then
       form.preventDefault()
       condition = ""
       conditionChanged = true
       system.pSave("cond",condition)
    elseif (key == KEY_1) then
       condition = condition .. "." 
       conditionChanged = true
       system.pSave("cond",condition)
    elseif (key == KEY_2) then
       condition = condition .. ","
       conditionChanged = true
       system.pSave("cond",condition)
    elseif (key == KEY_3) then
      condition = condition .. ")"
      conditionChanged = true
      system.pSave("cond",condition)
    elseif(key == KEY_4) then 
      condition = string.sub(condition,1,-2)
      conditionChanged = true
      system.pSave("cond",condition)
    elseif(key == KEY_ESC or key == KEY_5) then
      form.reinit(1)
      form.preventDefault()                         
    end
   end

end  

local function formattedResult()
  if  type(result)=="number" then
    return string.format("%.2f %s",result,paramUnit)
  else
    return result or ""
  end    
end

local function printForm()
  local r = string.format("%s: %s",paramName,formattedResult())
  lcd.drawText(lcd.width - 10 - lcd.getTextWidth(FONT_BIG,r),120,r, FONT_BIG)
  if(currentForm==2)then                     
    lcd.drawText(10,20,condition or "",FONT_BIG) 
    --lcd.drawText(10+lcd.getTextWidth(FONT_BIG,condition),20,fAvailable[fIndex],FONT_BIG)
    local x=25
    for i = fIndex - 3, fIndex + 3,1 do
      if i < 1 then i = i+#fAvailable 
      elseif i > #fAvailable then i = i - #fAvailable
      end
      local font = i==fIndex and FONT_BIG or FONT_NORMAL
      lcd.drawText(x-lcd.getTextWidth(font,fAvailable[i])/2,50,fAvailable[i],font)
      x=x+43
    end
  end
  
end  

local function printTelemetry(width, height)
   -- Print current telemetry
   --lcd.setColor(lcd.getFgColor())
   local r = paramName or ""
   r = r .. ": " .. formattedResult()
   local font = height > 40 and FONT_MAXI or FONT_BIG
   if lcd.getTextWidth(font,r) > width then
      font = FONT_BIG
   end
   lcd.drawText(width/2-lcd.getTextWidth(font,r)/2,(height-lcd.getTextHeight(font))*0.15,r,font) 

   if height > 40 then
      r = "X01: "
      if controlValue then
	 r = r .. string.format("%.2f", controlValue)
      else
	 r = r .. "---"
      end
      font = FONT_BOLD
      lcd.drawText(width/2-lcd.getTextWidth(font,r)/2,(height-lcd.getTextHeight(font))*0.8,r,font)
   end
end 

local function propCtlP(t, min, max)
   -- if min and max defined, then range is min to max
   -- if min only defined, then range is 0 to min
   -- if no min and no max then -1 to 1
   local st = tostring(math.floor(t))
   if min and max then
      return min + (max - min) * (1 + system.getInputs("P"..st)) / 2
   elseif min then
      return min*(system.getInputs("P"..st) + 1)/2
   else
      return system.getInputs("P"..st)
   end
end

local env = {
  t1 = 0,
  t2 = 0,
  abs =  math.abs,
  sin =  math.sin, 
  cos =  math.cos, 
  rad =  math.rad,
  deg =  math.deg,
  atan = math.atan,
  step = (function(a1,a2,a3) if math.abs(a1-a2) <= math.abs(a3) then return 0 else return (a1-a2) / math.abs(a1-a2) end end),
  box = (function(a1,a2,a3) if math.abs(a1-a2) <= math.abs(a3) then return 0 else return 1 end end),
  pc = (function(a1,a2,a3) return propCtlP(a1, a2, a3) end)
} 

local chunk,err, status

local function loop() 
  updateValues()  
  env.t1 = value1 or 0 
  env.t2 = value2 or 0 

  if conditionChanged == true then
     chunk, err = load("return "..condition,"","t",env)
     if err then
	print("Result expression error: " .. string.sub(err, 15))
     else
	print("Result expression valid")
     end
     conditionChanged = false
  end
  if (chunk) then
     status,result = pcall(chunk)
     if type(result) == "number" or type(result) == "boolean" then
	if result == false then result = 0 end
	if result == true then result = 1 end
	result = result or ""
	--print("status, result" .. "s:"..tostring(status).." , r:".. result, env.t1, env.t2)
	if status and resultIdx and result ~= "" then
	   if result >= -1.0 and result <= 1.0 then
	      if system.setControl(resultIdx, result, 0) then
		 controlValue = result
	      end
	   end
	end
     else
	result = "N/A"
     end
     
     --if not status then print(result) end
  else
     result = "N/A"
  end
end



-- Init function
local function init()
  sensor1Id = system.pLoad("sensor1")
  param1Id = system.pLoad("param1")
  sensor2Id = system.pLoad("sensor2")
  param2Id = system.pLoad("param2")
  condition = system.pLoad("cond","")
  conditionChanged = true
  paramName = system.pLoad("name","")
  paramUnit = system.pLoad("unit","")

  --setLanguage()

  system.registerForm(1,MENU_APPS,"V-SensXF",initForm,keyPressed,printForm);
  system.registerTelemetry(1,"V-SensXF"..": "..paramName,0,printTelemetry); 
  if(system.getVersion() < "4.26") then return end
  system.registerLogVariable(paramName,paramUnit,(function(index) 
				   return type(result)=="number" and  result*10  or nil, 1   
  end))

  resultIdx = nil
  for i=1,10,1 do
     resultIdx = system.registerControl(i, "V-SensXF Ctrl", "X01")
     if resultIdx then
	print("X01 " .. resultIdx)
	break
     end
  end

  if not resultIdx then
     print("X01 error")
  end
  
  system.getSensors()

  local foo={1,2,3,4,"five", "six"}
  system.pSave("foo", foo)
  local bar = system.pLoad("foo")
  for k,v in ipairs(foo) do
     print(k, foo[k], bar[k])
  end
  

  print("memory:", collectgarbage("count"))
  
end


--------------------------------------------------------------------

return { init=init, loop=loop, author="JETI model", version="1.2",name="V-SensXF"}
