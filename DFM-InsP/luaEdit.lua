local M = {}

local fAvailable = {}
local fIndex = {}
local fResult = {}

function M.luaEditPrint(cond, condIdx)

   local condition = cond.luastring

   if not condition[condIdx] then
      condition[condIdx] = ""
   end
   
   if cond.result and cond.result[condIdx] then
      local res = cond.result[condIdx]
      local str
      if type(res) == "number" then
	 str = string.format("Lua value: %.2f",cond.result[condIdx])
      else
	 str = "---"
      end
      lcd.drawText(lcd.width - 10 - lcd.getTextWidth(FONT_BIG,str),120,str, FONT_BIG)
   end
   
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

function M.luaEditKey(cond, condIdx, key, pnl, gau, idx, eval, chunk)

   local condition = cond.luastring

   --print("luaEditKey, cond", condition[condIdx])
   
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
   if chunk and chunk[pnl] and chunk[pnl][gau] and chunk[pnl][gau][idx] then
      chunk[pnl][gau][idx] = nil
   end
   
   local res = eval("E", condition[condIdx], pnl, gau, idx)
   if not cond.result then cond.result = {} end
   cond.result[condIdx] = res
end

function M.luaEdit(vars)
   
   local fA = { "*","/","+","-","^","(","%",
		"0","1","2","3","4","5","6","7","8","9",
		"abs("
   }

   -- rebuilt the expression element string from the
   -- latest info

   print("luaEdit", vars, #vars)
   
   fAvailable = {}

   for i,v in ipairs(vars) do
      print("adding to fAv", i, v.name)
      fAvailable[i] = v.name
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
