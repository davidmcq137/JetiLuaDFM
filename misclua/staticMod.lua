
local function staticMod()
   if #variableName == 0 then
      form.addRow(1)
      form.addLabel({label=lang.NoStat})
      form.addRow(1)
      form.addLabel({label=lang.PressC})
   end
   
   for k in ipairs(variableName) do
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

end

return staticMod
