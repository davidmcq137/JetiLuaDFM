
from time import time

from .ble import Ble
from .bleClient import BleClient
from .com import Com

class ComBle(Com):
    _BLE_ADV_ALOOK_UUID  = '0000fe9f-0000-1000-8000-00805f9b34fb'

    __FRAME_FMT_QUERY_LEN_MSK = 0x0F

    __FRAME_HEADER_SIZE  = 1
    __FRAME_CMD_ID_SIZE  = 1
    __FRAME_FMT_SIZE     = 1
    __FRAME_FOOTER_SIZE  = 1

    __RCV_STATE_START    = 0
    __RCV_STATE_CMD_ID   = 1
    __RCV_STATE_FMT      = 2
    __RCV_STATE_LEN_MSB  = 3
    __RCV_STATE_LEN_LSB  = 4
    __RCV_STATE_QUERY    = 5
    __RCV_STATE_DATA     = 6
    __RCV_STATE_FOOTER   = 7

    ## constructor
    def __init__(self, verbose = True):
        super().__init__(verbose)
        
        self.__rcvState = self.__RCV_STATE_START
        self.__rcvCmdId = 0
        self.__rcvSizeLen = 0
        self.__rcvSize = 0
        self.__rcvQueryLen = 0
        self.__rcvQuery = []
        self.__rcvData = []
        self.__rcvDataLen = 0
        self.__rcvRawFrame = []
        self.__timeout = 4.0

    ## get frame datat size
    def __rcvGetHeaderSize(self):
        return self.__FRAME_HEADER_SIZE + self.__FRAME_CMD_ID_SIZE + self.__rcvSizeLen + self.__FRAME_FMT_SIZE + self.__rcvQueryLen

    ## get frame datat size
    def __rcvGetDataSize(self):
        return self.__rcvSize - self.__rcvGetHeaderSize() - self.__FRAME_FOOTER_SIZE

    ## decode received byte
    def __rcvByte(self, b):
        ret = False

        self.__rcvRawFrame += [b]

        if self.__rcvState == self.__RCV_STATE_START:
            if b == self.FRAME_HEADER:
                self.__rcvRawFrame = [b]
                self.__rcvSize = 0
                self.__rcvData = []
                self.__rcvQuery = []
                self.__rcvState = self.__RCV_STATE_CMD_ID
            else:
                self.printFrameError("Missing header", [b])

        elif self.__rcvState == self.__RCV_STATE_CMD_ID:
            self.__rcvCmdId = b
            self.__rcvState = self.__RCV_STATE_FMT

        elif self.__rcvState == self.__RCV_STATE_FMT:
            self.__rcvQueryLen = (b & self.__FRAME_FMT_QUERY_LEN_MSK)
            self.__rcvSize = 0
            if (b & self.FRAME_FMT_LEN_2BYTES) == self.FRAME_FMT_LEN_2BYTES:
                self.__rcvSizeLen = 2
                self.__rcvState = self.__RCV_STATE_LEN_MSB
            else:
                self.__rcvSizeLen = 1
                self.__rcvState = self.__RCV_STATE_LEN_LSB
            
        elif self.__rcvState == self.__RCV_STATE_LEN_MSB:
            self.__rcvSize = b << 8
            self.__rcvState = self.__RCV_STATE_LEN_LSB

        elif self.__rcvState == self.__RCV_STATE_LEN_LSB:
            self.__rcvSize |= b
            self.__rcvDataLen = self.__rcvGetDataSize()
            if self.__rcvQueryLen > 0:
                self.__rcvState = self.__RCV_STATE_QUERY
            elif self.__rcvDataLen > 0:
                self.__rcvState = self.__RCV_STATE_DATA
            else:
                self.__rcvState = self.__RCV_STATE_FOOTER

        elif self.__rcvState == self.__RCV_STATE_QUERY:
            self.__rcvQuery.append(b)
            if self.__rcvQueryLen == len(self.__rcvQuery):
                if self.__rcvDataLen > 0:
                    self.__rcvState = self.__RCV_STATE_DATA
                else:
                    self.__rcvState = self.__RCV_STATE_FOOTER
        
        elif self.__rcvState == self.__RCV_STATE_DATA:
            self.__rcvData.append(b)
            if self.__rcvDataLen == len(self.__rcvData):
                self.__rcvState = self.__RCV_STATE_FOOTER
        
        elif self.__rcvState == self.__RCV_STATE_FOOTER:
            if b == self.FRAME_FOOTER:
                ret = True
            else:
                self.printFrameError("Missing footer", self.__rcvRawFrame)
            self.__rcvState = self.__RCV_STATE_START

        else:
            ## failsafe
            self.__rcvState = self.__RCV_STATE_START

        return ret

    ##
    def __asyncData(self):
        ret = False
        if self.__rcvCmdId == 0xB4:
             ## USB text
             print(f"msg: {bytearray(self.__rcvData).decode('ascii')}")
             ret = True
        elif self.__rcvCmdId == 0x07:
            ## Command echo
            self.logRawAppend(bytearray(self.__rcvData))
            ret = True
        elif self.__rcvCmdId == 0xE2:
            ## error
            self._rcvError(self.__rcvQuery, self.__rcvData[0], self.__rcvData[1], self.__rcvData[2])
            ret = True

        return ret
    
    ## send data over serial
    def __sendData(self, data):
        ## Write size is limited by MTU
        ## work around, split data
        size = len(data)
        i = 0
        while i < size:
            subLen = size
            if subLen > self.__dev.getMtu():
                subLen = self.__dev.getMtu()
            self.__dev.write(data[i : i + subLen])
            i += subLen
        self.printFrame("Send Frame", data)
    
    ## Look for Ble device with "A.LooK " in name
    def findDevice(self):
        print("Scanning devices...")
        ble = Ble()
        return ble.scanBySrv(self._BLE_ADV_ALOOK_UUID)

    ## Look for Ble device who match name
    def findDeviceByName(self, name, timeout=30.0):
        print(f"Scanning for {name}...")
        ble = Ble()
        return ble.scanByName(name, timeout)

    ## Look for Ble device who match address
    def findDeviceByAddr(self, addr, timeout=30.0):
        ble = Ble()

        ## handle public and private address
        ## even if public address should not be used
        pub = "80:" + addr[3:]
        pvt = "C0:" + addr[3:]

        print(f"Scanning for {addr}...")
        d = ble.scanByAddr([pub, pvt], timeout)

        return d

    ## get RSSI of the device
    def getRssi(self, dev):
        return dev.rssi

    def getMtu(self):
        return self.__dev.getMtu()
    
    ## open serial
    def open(self, device):
        self.device = device
        self.__dev = BleClient()
        self.__dev.connect(device)

    ## 
    def close(self):
        if self.__dev != None:
            self.__dev.disconnect()

    ##
    def sendFrame(self, cmdId, data, queryId=[]):
        frame = self.formatFrame(cmdId, data, queryId)
        self.__sendData(frame)

    ## return : {'ret', 'cmdId', 'data'}
    def receiveFrame(self, cmdId):
        while 1:
            b = self.__dev.read(1, self.__timeout)
            if len(b) != 1:
                ## Timeout
                return  {'ret': False, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}

            if self.__rcvByte(b[0]):
                if self.__rcvCmdId == cmdId:
                    return  {'ret': True, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}
                else:
                    if not self.__asyncData():
                        return  {'ret': False, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}


    ## receive answer to cmd
    def receiveAck(self):
        ## flow control is acynchronous on BLE
        while 1:
            b = self.__dev.read(1, 0)
            if len(b) != 1:
                return True
            if self.__rcvByte(b[0]):
                self.__asyncData()


    ## receive answer to cmd
    def receive(self):
        while 1:
            data = self.__dev.read(1, self.__timeout)
            if len(data) != 1:
                ## timeout
                return False
            else:
                if self.__rcvByte(data[0]):
                    if not self.__asyncData():
                        self.printFrameError("Wrong ack", self.__rcvRawFrame)

    ## send data
    def sendRawData(self, bin):
        self.__sendData(bin)

    ## disable usage of control notification
    def setIgnoreCtrl(self, value):
        self.__dev.setIgnoreCtrl(value)

    ## get BLE name
    def getBleName(self):
        return  self.__dev.getDeviceName()

    ## set read timeout
    def setTimeout(self, val):
        self.__timeout = val

    ## get read timeout
    def getTimeout(self):
        return self.__timeout

    def getBleInfo(self):
        return self.__dev.getValueInfo()

    ## check if there was a swipe since the last call
    def isSwipe(self):
        return self.__dev.isSwipe()