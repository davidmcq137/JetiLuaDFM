## -------------------------------------------------------
## In Fw version 3.6.7 and previous versions
## data sent on USB are in ascii format
## -------------------------------------------------------

from time import sleep

import serial.tools.list_ports
import serial

from . import utils
from .com import Com

class ComMixed(Com):
    ## constructor
    def __init__(self, verbose = True):
        super().__init__(verbose)
        
    ## decode received frame
    ## return : {'ret', 'cmdId', 'data'}
    def __decodFrame(self, frame):
        ## frame received are in ascii showing hexvalue
        ## Example: '0xffa2000d0100000000080d00aa\r\n'

        ## convert bytes to string
        frameStr = frame.decode('ascii')

        # remove '0x' at the start of the string
        prefix = '0x'
        if frameStr.startswith(prefix):
            frameStr = frameStr[len(prefix):]
        else:
            self.printFrameError("remove prefix", frame)
            return {'ret': False, 'cmdId': 0, 'data': 0}

        ## convert hex string to int
        bin = bytes.fromhex(frameStr)
        
        ## test header
        if bin[0] != self.FRAME_HEADER:
            self.printFrameError("wrong header", frame)
            return {'ret': False, 'cmdId': 0, 'data': 0}
        
        ## test footer
        if bin[len(bin) - 1] != self.FRAME_FOOTER:
            self.printFrameError("wrong footer", frame)
            return {'ret': False, 'cmdId': 0, 'data': 0}
        
        cmdId = bin[1]
        fmt = bin[2]
        dataIdx = 0
        if fmt < self.FRAME_FMT_LEN_2BYTES:
            frameLen = bin[3]
            dataIdx = 4
        else:
            frameLen = utils.listToUShort([bin[3], bin[5]])
            dataIdx = 5
        
        if frameLen != len(bin):
            self.printFrameError(f"wrong len, read : {frameLen} received : {len(bin)}", frame)
            return {'ret': False, 'cmdId': cmdId, 'data': 0}

        ## data
        dataBin = bin[dataIdx:(len(bin) - 1)]
        data = []
        for value in dataBin:
            data.append(value)
        
        return {'ret': True, 'cmdId': cmdId, 'data': data}

    ##
    def __asyncData(self, data):
        ret = False
        str = data.decode('ascii')
        if str == "QUEUE FULL !!!\r\n":
            ret = True
        elif str ==  "power off\r\n":
            ret = True
        elif str == "SWIPE\r\n":
            ret = True
        elif str.startswith("Image saved # "):
            ret = True
        elif str == "memory erased\r\n":
            ret = True
        elif str.startswith("Test "):
            ret = True

        if ret:
            print(f"async data: {str}")

        return ret
    
    ## send data over serial
    def __sendData(self, data):
        self.__ser.reset_input_buffer()
        self.__ser.write(data)
        self.printFrame("Send Frame", data)
    
    ## Look for com port with active look VID PID
    def findDevice(self):
        ports = serial.tools.list_ports.comports()
        for p in ports:
            if (p.vid == 0xFFFE) and (p.pid == 0x1112):
                return p.device

        return 

    ## open serial
    def open(self, device):
        self.device = device
        self.__ser = serial.Serial(device, timeout=1.75)

    ##
    def close(self):
        self.__ser.close()
    
    ##
    def sendFrame(self, cmdId, data, queryId=[]):
        frame = self.formatFrame(cmdId, data, queryId)
        self.__sendData(frame)

    ## return : {'ret', 'cmdId', 'data'}
    def receiveFrame(self, cmdId):
        line = self.__ser.readline()
        while self.__asyncData(line):
            line = self.__ser.readline()
        res = self.__decodFrame(line)

        if res['cmdId'] != cmdId:
            print(f"receiveFrame receive cmdId ({res['cmdId']:02x}) don't match expected cmdId ({cmdId:02x})")
            return False

        self.printFrame("Rcv Frame", res['rawFrame'])
        return res

    ## receive answer to cmd
    def receiveAck(self):
        ack = bytes([ord('\r'), ord('\n'), ord(']')])
        data = self.__ser.read(3)
        if ack == data:
            return True
        else:
            line = self.__ser.readline()
            data += line
            if self.__asyncData(data):
                return self.receiveAck()
            else:
                self.printFrameError("Wrong ack", data)
                return False
        sleep(0.15)
        return True

    ##
    def receiveUsbMsg(self):
        return self.__ser.readline().decode('ascii')

    ## send data
    def sendRawData(self, bin):
        self.__sendData(bin)

    ## get commands data max size
    def getDataSizeMax(self):
        return 128

    ## set read timeout
    def setTimeout(self, val):
        self.__ser.timeout = val

    ## get read timeout
    def getTimeout(self):
        return self.__ser.timeout