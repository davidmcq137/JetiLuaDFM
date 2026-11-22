n=6
xi={0.05,0.10,0.15,0.2,0.25,0.3}
yi={1,2,3,4,5,6}
dt = 0.05
for k,v in ipairs(xi) do
   v = v + 3.456 -- vary this to prove nothing depends on absolute x
end

function sumk(n) -- sum of i for i=1 to n
   return n*(n+1)/2
end

function sumk2(n) --sum of i^2 for i=1 to n
   return n*(n+1)*(2*n+1)/6
end

-- first "literal" computations

xbar = 0
for k,v in ipairs(xi) do
   xbar = xbar + v
end
xbar = xbar / n
print("xbar:", xbar)

ybar = 0
for k,v in ipairs(yi) do
   ybar = ybar + v
end
ybar = ybar / n
print("ybar:", ybar)

den=0
for k,v in ipairs(xi) do
   den = den + (v-xbar)^2
end
print("den:", den)

xy=0
for k,v in ipairs(xi) do
   xy = xy + (xi[k] - xbar) * (yi[k] - ybar)
end
print("xy:", xy)
m=xy/den
print("m:", m)

print("******")

--now the simplified computations

wt = {-2.5, -1.5, -0.5, 0.5, 1.5, 2.5}

xy=0
for k,v in ipairs(xi) do
   xy = xy + dt*wt[k] * (yi[k] - ybar)
end
print("xy:", xy)
print("sumk2(n):", sumk2(n))


den = dt*dt*(sumk2(n) - n*(n+1)*(n+1)/4)
print("n,den:", n, den)

print("******")

for k=1, 16, 1 do
   den = (sumk2(k) - sumk(k)*(k+1)/2)
   print(k, den)   
end


