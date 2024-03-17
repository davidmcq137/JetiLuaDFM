json = require "cjson" -- same json encode/decode as Jeti uses, loaded via luarocks

config = {}

fn = "./Images/instrESP.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("Read "..fn)
fp:close()
config = json.decode(file).config

lenarray = {}
lenuniq = {}
lenmap = {}
lu = 0
for i, screen in ipairs(config) do
   for j, window in ipairs(screen) do
      window.xlr = math.floor(window.xlr)
      window.ylr = math.floor(window.ylr)
      idx = "x"..tostring(window.xlr).."y"..tostring(window.ylr)
      if not lenuniq[idx] then
	 lu = lu + 1
	 print("creating", lu, idx)
	 lenuniq[idx] = lu
	 if not lenmap[i] then lenmap[i] = {} end
	 lenmap[i][j] = lu
	 lenarray[lu] = {xlr=window.xlr, ylr = window.ylr}
      else
	 if not lenmap[i] then lenmap[i] = {} end
	 lenmap[i][j] = lenuniq[idx]
      end
   end
end

print("#lenarray", #lenarray)

for k,v in ipairs(lenarray) do
   print(k, v.xlr, v.ylr)
end

for k,v in ipairs(lenmap) do
   for kk,vv in ipairs(v) do
      print(k, kk, vv)
   end
end


