json = require "cjson" -- same json encode/decode as Jeti uses, loaded via luarocks

fn = "./Images/instrESP.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("Read "..fn)
fp:close()
instrESP = json.decode(file)

formLen = #instrESP.forms
print("formLen is " .. formLen)

fk = {}
for k,v in ipairs(instrESP.forms) do
   for kk, vv in pairs(v) do
      if not fk[kk] then
	 fk[kk] = true
      end
   end
end
formsKeys = {}
for k,v in pairs(fk) do
   table.insert(formsKeys, k)
end
table.sort(formsKeys)

fn = "./Images/instrESP.h"
fp = assert(io.open(fn, "w"))

fp:write("typedef struct {\n")
for k,v in ipairs(formsKeys) do
   fp:write("   int16_t " .. v .. ";\n")
end
fp:write("} formItem;\n")

fp:write("formItem form["..formLen.."] = {\n")
fkl = #formsKeys
for k,v in ipairs(instrESP.forms) do
   fp:write("{ ")
   for kk,vv in ipairs(formsKeys) do
      fp:write(tostring((math.floor(v[vv] or 0))))
      if kk < fkl then 
	 fp:write(", ")
      end
   end
   if k < formLen then
      fp:write("},\n")
   else
      fp:write("}\n")
   end
end
fp:write("};\n")

instLen = #instrESP.instruments
print("instLen is " .. instLen)

ik = {}
for k,v in ipairs(instrESP.instruments) do
   for kk, vv in pairs(v) do
      if not ik[kk] then
	 if type(vv) == "string" then
	    ik[kk] = #vv
	 else
	    ik[kk] = type(vv)
	 end
      end
      if type(vv) == "string" then
	 if #vv > ik[kk] then
	    ik[kk] = #vv
	 end
      end
   end
end

instKeys = {}
for k,v in pairs(ik) do
   table.insert(instKeys, k)
end
table.sort(instKeys)

typeT = {minV = "float", maxV = "float", scale = "char", wtype = "char"} 
typeI = "uint16_t"

fp:write("typedef struct {\n")
for k,v in ipairs(instKeys) do
   tt = typeT[v]
   if not tt then tt = typeI end
   if tt == "char" then
      aa = "["..(ik[v]+1).."]"
   else
      aa = ""
   end
   fp:write("  " .. tt .. " " .. v .. aa ..";\n")
end
fp:write("} instItem;\n")

fp:write("instItem instruments["..instLen.."] = {\n")
ikl = #instKeys
for k,v in ipairs(instrESP.instruments) do
   fp:write("{ ")
   for kk,vv in ipairs(instKeys) do
      if not v[vv] then
	 fp:write("")
      else
	 if type(v[vv]) == "number" then
	    fp:write(tostring((math.floor(v[vv] or 0))))
	 else
	    fp:write('"'..v[vv]..'"')
	 end
      end
      if kk < ikl then 
	 fp:write(", ")
      end
   end
   if k < instLen then
      fp:write("},\n")
   else
      fp:write("}\n")
   end
end
fp:write("};\n")




fp:close()
