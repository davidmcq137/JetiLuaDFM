local items = {}
items.name2seq = {} 
items.seq2name = {} 
items.formStack={}

items.AddLink = function(sf, dest)
   if sf == 1 then items.formStack = {sf} end
   local numdest = #items.seq2name+1
   items.name2seq[dest] = {ret=sf, seq=numdest, fcn=dest}
   table.insert(items.seq2name, {fcn=dest, ret=sf,seq=numdest})
end

items.Dispatch = function(sf)
   if #items.seq2name == 0 and sf == 1 then items.AddLink(1, "mainmenu") end
   --print("Dispatching to sf "..sf, items.seq2name[sf].seq, items.seq2name[sf].ret)
   items[items.seq2name[sf].fcn](items.seq2name[sf].seq, items.seq2name[sf].ret)
end

items.Link = function (sf, dest, lbl)
   if not items.name2seq[dest] then
      items.AddLink(sf, dest)
   end
   form.addLink(
      (function() form.reinit(items.name2seq[dest].seq)
	    table.insert(items.formStack, items.name2seq[dest].seq) end),
      {label=lbl} )
   end

items.ReturnLink = function(ret)
   form.addLink(
      (function() form.reinit(ret)
	    table.remove(items.formStack, #items.formStack)
      end),
      {label = "<< Return"})
end

items.mainmenu = function(seq, ret)
   form.addLabel({label="seq="..seq.. "ret="..ret,
		  font=FONT_MINI, alignRight=true})
   local str=""
   for k,v in ipairs(items.formStack) do
      str = str .. "/" ..items.seq2name[v].fcn
   end
   form.addLabel({label="stack="..str,
		  font=FONT_MINI, alignRight=true})
   items.Link(seq, "vspeeds",  "V Speeds >>")
   items.Link(seq, "sensors",  "Sensors >>" )
   items.Link(seq, "controls", "Controls >>")
   items.Link(seq, "settings", "Settings >>")
end

items.vspeeds = function(seq, ret)
   form.addLabel({label="seq="..seq.. "ret="..ret,
		  font=FONT_MINI, alignRight=true})
   local str=""
   for k,v in ipairs(items.formStack) do
      str = str .. "/" ..items.seq2name[v].fcn
   end
   form.addLabel({label="stack="..str,
		  font=FONT_MINI, alignRight=true})
   items.ReturnLink(ret)
end

items.sensors = function(seq, ret)
   form.addLabel({label="seq="..seq.. "ret="..ret,
		  font=FONT_MINI, alignRight=true})
   local str=""
   for k,v in ipairs(items.formStack) do
      str = str .. "/" ..items.seq2name[v].fcn
   end
   form.addLabel({label="stack="..str,
		  font=FONT_MINI, alignRight=true})
   items.ReturnLink(ret)   
end

items.controls = function(seq, ret)
   form.addLabel({label="seq="..seq.. "ret="..ret,
		  font=FONT_MINI, alignRight=true})
   local str=""
   for k,v in ipairs(items.formStack) do
      str = str .. "/" ..items.seq2name[v].fcn
   end
   form.addLabel({label="stack="..str,
		  font=FONT_MINI, alignRight=true})
   items.ReturnLink(ret)
end

items.settings = function(seq,ret)
   items.ReturnLink(ret)

   form.addRow(1)
   form.addLabel({label="seq="..seq.. "ret="..ret,
		  font=FONT_MINI, alignRight=true})
   local str=""
   for k,v in ipairs(items.formStack) do
      str = str .. "/" ..items.seq2name[v].fcn
   end
   form.addLabel({label="stack="..str,
		  font=FONT_MINI, alignRight=true})

   items.Link(seq, "indicators", "Indicators >>") 
end

items.indicators = function(seq,ret)
   form.addRow(1)
   form.addLabel({label="seq "..seq.." ret="..ret,
		  font=FONT_MINI, alignRight=true})
   local str=""
   for k,v in ipairs(items.formStack) do
      str = str .. "/" ..items.seq2name[v].fcn
   end
   form.addLabel({label="stack="..str,
		  font=FONT_MINI, alignRight=true})
   items.ReturnLink(ret)
end

return items
