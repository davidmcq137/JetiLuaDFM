local M = {}

local fAvailable = {}
local fIndex = {}

function M.luaEditPrint(env)

   _ENV = env
   
   --local r = string.format("%s: %s",resultName[condIdx],formattedResult(condIdx))
   --lcd.drawText(lcd.width - 10 - lcd.getTextWidth(FONT_BIG,r),120,r, FONT_BIG)
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

function M.luaEditKey(env)

   _ENV = env

   if not fIndex[condIdx] then fIndex[condIdx] = 1 end
   
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
      --
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
   
end

function M.luaEdit(env)

   _ENV = env

   local fA = { "*","/","+","-","^","(","%",
		">", "<", ">=", "<=", "==","~=",
		" and ", " or ",
		"0","1","2","3","4","5","6","7","8","9",
		"abs(","sin(","cos(","atan(","rad(","deg(","sqrt(",
		"max(", "min(", "floor("
   }

   -- rebuilt the expression element string from the
   -- latest info
   
   local tt = {"t1", "t2", "t3"}
   
   fAvailable = {}

   for i in ipairs(tt) do
      fAvailable[i] = tt[i]
   end
   
   for i in ipairs(fA) do
      table.insert(fAvailable, fA[i])
   end
   
   form.setButton(4,":backspace",ENABLED)  
   form.setButton(1, ".", ENABLED)
   form.setButton(2, ",", ENABLED)
   form.setButton(3, ")", ENABLED)

end

return M
