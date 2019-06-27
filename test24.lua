
--------------------------------------------------------------------
local appName="Test 24 - Mode" 
local mode=1
--------------------------------------------------------------------
 
local function checkButtons()
  form.setButton(1,"1)",mode==1 and HIGHLIGHTED or ENABLED)
  form.setButton(2,"2)",mode==2 and HIGHLIGHTED or ENABLED)
  form.setButton(3,"3)",mode==3 and HIGHLIGHTED or ENABLED)
  form.setButton(4,"4)",mode==4 and HIGHLIGHTED or ENABLED)
end 
--------------------------------------------------------------------
local function initForm(formID)  
  form.setButton(5,"Test",ENABLED)
  checkButtons()
end 
 
--------------------------------------------------------------------
local function keyPressed(key) 
  if(key==KEY_1) then     
    mode=1 
  elseif(key == KEY_2) then 
    mode=2 
  elseif(key == KEY_3) then 
    mode=3
  elseif(key == KEY_4) then 
    mode=4 
  elseif(key == KEY_5) then 
    form.preventDefault() 
    local text,state = form.getButton(5) 
    form.setButton(5,text,(state == HIGHLIGHTED) and ENABLED or HIGHLIGHTED)      
  end  
  checkButtons()
end  

local function printForm() 
  lcd.drawText(10,50,"Tx Mode: "..mode,FONT_MAXI)       
end 
 
--------------------------------------------------------------------
-- Init function
local function init()
  system.registerForm(1,MENU_MAIN,appName,initForm,keyPressed,printForm); 
end 
--------------------------------------------------------------------

return { init=init, author="JETI model", version="1.00",name=appName}
