
local function binom( n, k )
    if k > n then return nil end
    if k > n/2 then k = n - k end       --   (n k) = (n n-k)
 
    numer, denom = 1, 1
    for i = 1, k do
        numer = numer * ( n - i + 1 )
        denom = denom * i
    end
    return numer / denom
end

-- import matplotlib.pyplot as plt
-- from scipy.special import binom

-- P=(0,300),(0,600),(400,600),(800,300),(0,0),(0,300)
P = { {0, 300}, {0, 600}, {400, 600}, {800, 300}, {0, 0}, {0, 300}}

--[[ 
n = len(P)-1
Num_t=50
px, py = [None]*(Num_t+1),[None]*(Num_t+1)
--]]

local n = #P-1
local numT = 50
local px, py={}, {}
local t

for j = 0, numT, 1 do
   t = j / numT
   px[j], py[j] = 0, 0
   for i = 0, #P-1 do
      px[j] = px[j] + binom(n, i)*t^i*(1-t)^(n-i)*P[i+1][1]
      py[j] = py[j] + binom(n, i)*t^i*(1-t)^(n-i)*P[i+1][2]
   end
   print(px[j], ',', py[j])
end


--[[
for j in range(Num_t+1):
    t = j / float(Num_t)
    px[j],py[j]=0.0,0.0
    for i in range(len(P)):
        px[j] += binom(n,i)*t**i*(1-t)**(n-i)*P[i][0]
        py[j] += binom(n,i)*t**i*(1-t)**(n-i)*P[i][1]

xp=[None]*len(P)
yp=[None]*len(P)
for i in range(len(P)): xp[i],yp[i]=P[i]

plt.title('bezier curve')
plt.xlim([min(xp)-10,max(xp)+10])
plt.ylim([min(yp)-10,max(yp)+10])
plt.xlabel('x')
plt.ylabel('y')
plt.text(25,300,'P1,P6')
plt.text(15,575,'P2')
plt.text(375,575,'P3')
plt.text(750,300,'P4')
plt.text(15,25,'P5')
plt.plot(xp,yp,'-d',px,py,'.')
plt.grid()
plt.show()
--]]

--  lua binom code
