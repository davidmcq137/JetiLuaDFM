
--------------------------------------------------------------------
local appName="Test 23 - Buttons" 
local intIdx,timeIdx
--------------------------------------------------------------------

local function valueChanged(val)
  if(val==0) then
    form.setButton(1,"<<",DISABLED)
    form.setButton(2,">>",ENABLED)
  elseif(val==100) then
    form.setButton(1,"<<",ENABLED)
    form.setButton(2,">>",DISABLED)
  else
    form.setButton(1,"<<",ENABLED)
    form.setButton(2,">>",ENABLED)
  end
end
--------------------------------------------------------------------
local function initForm(formID)
  form.addRow(2)
  form.addLabel({label="Select value"}) 
  intIdx = form.addIntbox(0,0,100,0,0,1,valueChanged)  
  
  form.addRow(2)
  form.addLabel({label="Timestamp"}) 
  timeIdx = form.addIntbox(0,0,32000,0,0,1,nil,{enabled=false}) 
  
  form.setButton(1,"<<",DISABLED)
  form.setButton(2,">>",ENABLED)
end  
--------------------------------------------------------------------
local function keyPressed(key)
  local val = form.getValue(intIdx)
  if(key==KEY_1) then     
    if(val>0) then
      val=val-1
      form.setValue(intIdx,val)
    end
  elseif(key == KEY_2) then 
    if(val<100) then
      val=val+1
      form.setValue(intIdx,val)   
    end
  end  
end  

local function printForm(key)
  local value = form.getValue(intIdx)
  lcd.drawText(10,50,value.."%",FONT_MAXI)       
end 
 
--------------------------------------------------------------------
-- Init function
local function init()
  system.registerForm(1,MENU_MAIN,appName,initForm,keyPressed,printForm); 
end

local function loop()
  if(timeIdx) then
    form.setValue(timeIdx,system.getTimeCounter()//1000)
  end 
end 
--------------------------------------------------------------------

return { init=init, loop=loop, author="JETI model", version="1.00",name=appName}
