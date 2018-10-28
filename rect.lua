local result = 0
local foo = 0

local function printForm()        
  lcd.drawRectangle(10,10,300,20)
  lcd.setColor(200,0,0)
  lcd.drawRectangle(10,40,300,20,5) 
  lcd.setColor(0,200,0)
  lcd.drawRectangle(10,70,300,40,20) 
end

local function logIndex(i)
   print("index: ", i)
   print("index result: ", result)
   result = result + 1
   return result, 0
end



print("here!")
print (foo)


local function init() 
  system.registerForm(1,MENU_MAIN,"Test 17 - Rectangles",nil, nil,printForm) 
  foo = system.registerLogVariable("Virtual Var","Cnt", logIndex)
  print("foo returned: ", foo)
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}
