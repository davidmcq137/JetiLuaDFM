json = require "cjson" -- same json encode/decode as Jeti uses, loaded via luarocks

fn = "./Images/instrESP.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("header.lua reading "..fn)
fp:close()
instrESP = json.decode(file)

formLen = #instrESP.forms

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


print("formLen is " .. formLen)


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
typeI = "int16_t"

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
      if not v[vv] or type(v[vv]) == "number" then
	 fp:write(tostring((math.floor(v[vv] or 0))))
      else
	 fp:write('"'..v[vv]..'"')
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


ck = {}
wid = 0
for k,v in ipairs(instrESP.config) do
   if #v > wid then wid = #v end
   for kk, vv in pairs(v) do
      for kkk,vvv in pairs(vv) do
	 if not ck[kkk] then
	    ck[kkk] = true
	 end
      end
   end
end
configKeys = {}
for k,v in pairs(ck) do
   table.insert(configKeys, k)
end
table.sort(configKeys)

configLen = #instrESP.config
print("configLen is "..configLen)

fp:write("typedef struct {\n")
for k,v in ipairs(configKeys) do
   fp:write("   int16_t " .. v .. ";\n")
end
fp:write("} configItem;\n")

fp:write("configItem config["..configLen.."]["..wid.."] =\n")
ckl = #configKeys

fp:write("{\n")
for i=1, configLen, 1 do
   fp:write("   {\n")
   for m = 1, wid, 1 do
      fp:write("      {")
      for j = 1, wid, 1 do
	 if m <= #instrESP.config[i] then
	    fp:write(tostring(math.floor(instrESP.config[i][m][configKeys[j]])))
	 else
	    fp:write("0")
	 end
	 if j < wid then fp:write(", ") end 
      end

      if m < wid then fp:write("},\n") else fp:write("}\n") end
   end
   if i <  configLen then
      fp:write("   },\n")
   else
      fp:write("   }\n")
   end
end
fp:write("};\n")

print("header.lua writing " .. fn)

fp:close()
