
local function onRead(data)
   print(data)
end

local last=0
local ii=0

local function loop()
   local sgtc
   sgtc = system.getTimeCounter()
   if sgtc - last > 2000 then
      ii = ii + 1
      last = sgtc
      --if ii < 4 then print("ii", ii) end
      if ii == 1 then
	 serial.write(sidSerial, "+++\r\n")
      elseif ii == 2 then
	 --serial.write(sidSerial,"ATI\n")	 
	 serial.write(sidSerial,"AT+BLEPOWERLEVEL=4\r\n")
      elseif ii == 3 then
	 serial.write(sidSerial, "AT+BLEGETADDR\r\n")
      elseif ii == 4 then
	 serial.write(sidSerial, "AT+BLEGETRSSI\r\n")
      elseif ii == 5 then
	 serial.write(sidSerial, "AT+BLEPOWERLEVEL\r\n")	 	 
      elseif ii == 6 then
	 serial.write(sidSerial, "+++\r\n")	 
      end
   end
end


local function init()

   local emflag = true
   local portList
   local portStr
   local port
   
   if emflag then
      portList = serial.getPorts()
      if #portList > 0 then
	 portStr = portList[1]
	 for i=2, #portList, 1 do
	    portStr = portStr .. ", " .. portList[i]
	 end
	 print("Ports available - " .. portStr)
	 port = portList[1] -- edit if required
      else
	 print("No ports available")
      end
   else
      port = "COM1"
   end

   if port then
      sidSerial, descr = serial.init(port ,9600)
      if sidSerial then   
	 print("Initialized " .. port)
	 local success, descr = serial.onRead(sidSerial,onRead)   
	 if success then
	    print("Callback registered")
	 else
	    print("Error setting callback:", descr)
	 end
      else
	 print("Serial init failed <"..descr..">")
      end
   end

end


return {init=init, loop=loop, author="DFM", version=PumpVersion, name="Setbaud", destroy=destroy}
