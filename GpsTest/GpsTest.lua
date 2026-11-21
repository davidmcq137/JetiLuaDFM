--[[
   GpsTest: probe the JETI gps library to find out which formulas it uses

   Runs a fixed set of points through gps.getDistance, gps.getBearing,
   gps.getDestination and the Web Mercator calls (m2px, px2m, getLcdXY,
   getLL) once, in init, and writes one line per result to
   Apps/GpsTest/gpstest.out. GpsTest/compare.py then fits those numbers
   against the candidate formulas (haversine at several radii, flat earth,
   WGS84 Vincenty).

   Each call is in a pcall so a call the firmware rejects is logged as ERR
   and the rest still run. Points are made from strings to keep the inputs
   exact (Lua numbers are float32 on the TX and emulator).

   Output lines (comma separated):
     D,name,lat1,lng1,alt1,lat2,lng2,alt2,distance,bearing12,bearing21
     A,name,lat1,lng1,lat2,lng2,distance,bearing   (lat/lng-string form)
     X,name,lat,lng,distance,bearing,altarg,ptalt,destlat,destlng
     M,name,lat,lng,zoom,mx,my,px,py               (m2px of mx,my metres)
     P,name,lat,lng,zoom,px,py,mx,my               (px2m of px,py pixels)
     L,name,tllat,tllng,lat,lng,zoom,x,y,backlat,backlng (getLcdXY, getLL)
     ERR,name,message
--]]

local appName = "GpsTest"
local outFile = "Apps/GpsTest/gpstest.out"

local fh
local nOut, nErr = 0, 0

local function out(...)
   local t = {...}
   for i = 1, #t do t[i] = tostring(t[i]) end
   local s = table.concat(t, ",")
   if fh then io.write(fh, s, "\n") end
   nOut = nOut + 1
end

-- float32 has 24 bits, so 9 significant digits always round-trip
local function num(x)
   if type(x) ~= "number" then return tostring(x) end
   return string.format("%.9g", x)
end

-- gps.newPoint with the altitude only when there is one
local function newPt(lat, lng, alt)
   if alt then return gps.newPoint(lat, lng, alt) end
   return gps.newPoint(lat, lng)
end

local function try(name, f)
   local ok, err = pcall(f)
   if not ok then
      nErr = nErr + 1
      out("ERR", name, string.gsub(tostring(err), ",", ";"))
   end
end

-- distance and bearing pairs: name, lat1, lng1, lat2, lng2 [, alt]
local pairs_ = {
   {"eq_1N",      "0", "0", "1", "0"},
   {"eq_1E",      "0", "0", "0", "1"},
   {"45_1N",      "45", "0", "46", "0"},
   {"45_1E",      "45", "0", "45", "1"},
   {"60_1N",      "60", "0", "61", "0"},
   {"60_1E",      "60", "0", "60", "1"},
   {"80_1N",      "80", "0", "81", "0"},
   {"S33_1N",     "-33", "151", "-32", "151"},
   {"45_500kmNE", "45", "0", "48", "4.5"},
   {"NY_London",  "40.7128", "-74.006", "51.5074", "-0.1278"},
   {"antimerid",  "0", "179.5", "0", "-179.5"},
   {"41_1km_N",   "41", "-73", "41.009", "-73"},
   {"41_1km_E",   "41", "-73", "41", "-72.988"},
   {"41_100m_NE", "41", "-73", "41.000636", "-72.999157"},
   {"41_1m_E",    "41", "-73", "41", "-72.99998809"},
   {"41_10cm_N",  "41", "-73", "41.0000009", "-73"},
   {"field_diag", "41.3421", "-74.0021", "41.3437", "-73.9983"},
   {"alt_10km",   "45", "0", "46", "0", "10000"},
}

-- destination tests: name, lat, lng, distance, bearing, altarg, ptalt
local dests = {
   {"d1km_0",     "41", "-73", 1000, 0},
   {"d1km_45",    "41", "-73", 1000, 45},
   {"d1km_90",    "41", "-73", 1000, 90},
   {"d1km_135",   "41", "-73", 1000, 135},
   {"d100km_90",  "41", "-73", 100000, 90},
   {"d1000km_45", "41", "-73", 1000000, 45},
   {"d1000km_90", "41", "-73", 1000000, 90},
   {"d100km_0eq", "0", "0", 100000, 0},
   {"d100km_altarg", "41", "-73", 100000, 90, 100000, nil},
   {"d100km_ptalt",  "41", "-73", 100000, 90, nil, "100000"},
}

-- Mercator scale tests: lat, zoom
local mercs = {
   {"0", 1}, {"0", 10}, {"0", 18}, {"45", 18}, {"60", 18}, {"41", 21},
}

local function runTests()

   for _, p in ipairs(pairs_) do
      local n = p[1]
      try("D " .. n, function()
	 local a = newPt(p[2], p[3], p[6])
	 local b = newPt(p[4], p[5], p[6])
	 local d = gps.getDistance(a, b)
	 local b12 = gps.getBearing(a, b)
	 local b21 = gps.getBearing(b, a)
	 out("D", n, p[2], p[3], p[6] or 0, p[4], p[5], p[6] or 0, num(d), num(b12), num(b21))
      end)
      try("A " .. n, function()
	 local a = gps.newPoint(p[2], p[3])
	 local d = gps.getDistance(a, p[4], p[5])
	 local br = gps.getBearing(a, p[4], p[5])
	 out("A", n, p[2], p[3], p[4], p[5], num(d), num(br))
      end)
   end

   for _, t in ipairs(dests) do
      local n = t[1]
      try("X " .. n, function()
	 local a = newPt(t[2], t[3], t[7])
	 local dp
	 if t[6] then
	    dp = gps.getDestination(a, t[4], t[5], t[6])
	 else
	    dp = gps.getDestination(a, t[4], t[5])
	 end
	 local la, lo = gps.getString(dp)
	 out("X", n, t[2], t[3], t[4], t[5], t[6] or "", t[7] or "", la, lo)
      end)
   end

   for _, m in ipairs(mercs) do
      local n = m[1] .. "_z" .. m[2]
      try("M " .. n, function()
	 local a = gps.newPoint(m[1], "0")
	 local px, py = gps.m2px(a, 1000, 1000, m[2])
	 out("M", n, m[1], 0, m[2], 1000, 1000, num(px), num(py))
      end)
      try("P " .. n, function()
	 local a = gps.newPoint(m[1], "0")
	 local mx, my = gps.px2m(a, 100, 100, m[2])
	 out("P", n, m[1], 0, m[2], 100, 100, num(mx), num(my))
      end)
   end

   -- LCD position of a point SE of the top-left corner, and back again
   local lcds = {
      {"41_z18", "41.0010", "-73.0020", "41.0000", "-73.0000", 18},
      {"41_z15", "41.0100", "-73.0200", "41.0000", "-73.0000", 15},
      {"0_z18",  "0.0010",  "-0.0020",  "0.0000",  "0.0000",   18},
   }
   for _, c in ipairs(lcds) do
      try("L " .. c[1], function()
	 local tl = gps.newPoint(c[2], c[3])
	 local p = gps.newPoint(c[4], c[5])
	 local x, y = gps.getLcdXY(p, tl, c[6])
	 local back = gps.getLL(x, y, tl, c[6])
	 local bla, blo = gps.getString(back)
	 out("L", c[1], c[2], c[3], c[4], c[5], c[6], num(x), num(y), bla, blo)
      end)
   end
end

local function init()
   fh = io.open(outFile, "w")
   if not fh then print(appName .. ": could not open " .. outFile) end
   out("#", appName, "1.0", system.getVersion and system.getVersion() or "?",
       system.getDeviceType and system.getDeviceType() or "?")
   runTests()
   if fh then io.close(fh) end
   print(string.format("%s: %d lines, %d errors, written to %s", appName, nOut, nErr, outFile))
end

local function loop() end

return {init=init, loop=loop, author="DFM", version="1.0", name=appName}
