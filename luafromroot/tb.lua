
binomC = {} -- array of binomial coefficients for n=MAXTABLE-1, indexed by k
MAXTABLE=5

function binom(n, k)
   
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

function computeBezier(numT)

   -- compute Bezier curve points using control points in xtable[], ytable[]
   -- with numT points over the [0,1] interval
   
   local px, py
   local t
   local ti, oti
   local n = #xtable-1

   for j = 0, numT, 1 do
      t = j / numT
      px, py = 0, 0
      ti = 1 -- first loop t^i = 0^0 which lua says is 1
      for i = 0, n do
	 -- px = px + binom(n, i)*t^i*(1-t)^(n-i)*xtable[i+1]
	 -- py = py + binom(n, i)*t^i*(1-t)^(n-i)*ytable[i+1]
	 oti = (1-t)^(n-i)
	 px = px + binom(n, i)*ti*oti*xtable[i+1]
	 py = py + binom(n, i)*ti*oti*ytable[i+1]
	 ti = ti * t
      end
      bezierPath[j+1] = {x=px, y=py}
   end
end
