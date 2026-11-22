hx711.init(2,0)

local calib = 11010.8 -- measured against commercial scale
local numzero = 5
local numread = 5
local outlier = 0

local zero = 0

for i = 1, numzero, 1 do
   local zz = hx711.read(0)
   if i == 0 then print("zz=", zz) end
   zero = zero + zz
   tmr.delay(100) -- hx711.read needs a small delay. no idea why. 100 usec seems sufficient
end

zero = zero / numzero

print("Scale zeroed")

while true do

  local raw_reading_sum = 0

  for j=1,numread,1 do   
     local rr = hx711.read(0)
     raw_reading_sum = raw_reading_sum + rr
     tmr.delay(100)
  end
  
  local raw_reading = raw_reading_sum / numread
  
  local reading = raw_reading - zero

  local weight = reading / calib

  if not maxweight then maxweight = weight end
  if not minweight then minweight = weight end

  if weight > maxweight then maxweight = weight end
  if weight < minweight then minweight = weight end

  if math.abs(weight) > 0.1 then outlier = outlier + 1 end
     
  local text = string.format("%4.2f lbs -  min: %4.2f max: %4.2f out: %d",
			     math.floor(100*(weight) + 0.5)/100.,
			     minweight, maxweight, outlier)
  
  print(text)
  
  tmr.delay(200000)

end
