
local binomC = {} -- array of binomial coefficients for n=MAXTABLE-1, indexed by k

local function binom(n, k)
   
   -- compute binomial coefficients to then compute the Bernstein polynomials for Bezier
   -- n will always be MAXTABLE-1 once past initialization
   -- as we compute for each k, remember in a table and save
   -- for MAXTABLE = 5, there are only ever 3 values needed in steady state: (4,0), (4,1), (4,2)
   
   if k > n then return nil end  -- error .. let caller die
   if k > n/2 then k = n - k end -- because (n k) = (n n-k) by symmetry
   
   if (n == MAXTABLE-1) and binomC[k] then return binomC[k] end

   local numer, denom = 1, 1

   for i = 1, k do
      numer = numer * ( n - i + 1 )
      denom = denom * i
   end

   if n == MAXTABLE-1 then
      binomC[k] = numer / denom
      return binomC[k]
   else
      return numer / denom
   end
   
end

local function computeBezier(numT)

   -- compute Bezier curve points using control points in xtable[], ytable[]
   -- with numT points over the [0,1] interval
   
   local px, py
   local dx, dy
   local t, bn
   local ti, oti
   local n = #xtable-1

   for j = 0, numT, 1 do
      t = j / numT
      px, py = 0, 0
      dx, dy = 0, 0

      ti = 1 -- first loop t^i = 0^0 which lua says is 1
      for i = 0, n do
	 -- px = px + binom(n, i)*t^i*(1-t)^(n-i)*xtable[i+1]
	 -- py = py + binom(n, i)*t^i*(1-t)^(n-i)*ytable[i+1]
	 -- see: https://pages.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/bezier-der.html
	 -- for Bezier derivatives
	 -- 11/30/18 was not successful in getting bezier derivatives to improve heading calcs
	 -- code commented out
	 --
	 -- if i > 0 and j == (numT-1) then
	 --    dx = dx + bn * n * (xtable[i+1]-xtable[i]) -- this is really the "n-1" bn as req'd
	 --    dy = dy + bn * n * (ytable[i+1]-ytable[i])
	 --    --print(j, i, n, bn, ti, oti, dy, dx)
	 -- end
	 oti = (1-t)^(n-i)
	 bn = binom(n, i)*ti*oti
	 px = px + bn * xtable[i+1]
	 py = py + bn * ytable[i+1]
	 ti = ti * t
      end
      bezierPath[j+1]  = {x=px,   y=py}
      
      -- if j == (numT-1) then
      -- 	 bezierPath.slope = slope_to_deg(dy, dx)
      -- end
   end

   -- using alt approach of computing slope oflast two or three points of bezier curve also not
   -- helful in smoothing out heading noise in taxi
   --
   -- local bx = {bezierPath[#bezierPath-2].x, bezierPath[#bezierPath-1].x, bezierPath[#bezierPath].x}
   -- local by = {bezierPath[#bezierPath-2].y, bezierPath[#bezierPath-1].y, bezierPath[#bezierPath].y}

   -- _, bezierHeading= fslope(bx, by)
   -- bezierHeading = math.deg(bezierHeading)

end

local function drawBezier(windowWidth, windowHeight)

   -- draw Bezier curve points computed in computeBezier()

   if not bezierPath[1]  then return end

   ren:reset()

   for j=1, #bezierPath do
      ren:addPoint(toXPixel(bezierPath[j].x, map.Xmin, map.Xrange, windowWidth),
		   toYPixel(bezierPath[j].y, map.Ymin, map.Yrange, windowHeight))
   end
   ren:renderPolyline(3)

end
