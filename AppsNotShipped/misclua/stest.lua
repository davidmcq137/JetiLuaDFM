-- Writes “Hello world” to the serial port
-- and then prints number of bytes written.
local time
local sid

local function serialInput(data)
   print("callback data: "..data)
end

local function loop()

   if system.getTimeCounter() - time > 1000 then
      time = system.getTimeCounter()
      local written = serial.write(sid,"Hello world\r\n")
      if written then
	 print("Number of bytes written: ", written)
      else
	 print("Error writing to serial port")
      end
   end
end

local function init()

   time = system.getTimeCounter()
   
   sid = serial.init("COM1",9600)

   if not sid then
      print ("Error opening COM1")
   else
      local written = serial.write(sid,"Hello world\r\n")
      if written then
	 print("Number of bytes written: ", written)
      else
	 print("Error writing to serial port")
      end
   end
   local success, descr = serial.onRead(sid, serialInput)
   if success then
      print("Callback registered")
   else
      print("Error setting callback", descr)
   end
end

-- Other possibilities, how to call the function - example:
-- serial.write(sid, 0xFF, 0x00, "Text1","Text2")
return {init=init, loop=loop, author="DFM", version="1", name="stest"}
