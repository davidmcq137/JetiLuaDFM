local function binom(n, k)
    if k > n then return nil end
    if k > n/2 then k = n - k end       --   (n k) = (n n-k)
 
    numer, denom = 1, 1
    for i = 1, k do
        numer = numer * ( n - i + 1 )
        denom = denom * i
    end
    return numer / denom
end

local function drawBezier(Px, Py, mapXmin, mapXrange, mapYmin, mapYrange, windowWidth, windowHeight, numT)

local n = #Px-1
local px, py
local t

ren:reset()

for j = 0, numT, 1 do
   t = j / numT
   px, py = 0, 0
   for i = 0, n do
      px = px + binom(n, i)*t^i*(1-t)^(n-i)*Px[i+1]
      py = py + binom(n, i)*t^i*(1-t)^(n-i)*Py[i+1]
   end
   ren:addPoint(toXpixel(px, mapXmin, mapXrange, windowWidth),
		toYpixel(py, mapYmin, mapYrange, windowHeight))
end

ren:renderPolyline(2)
