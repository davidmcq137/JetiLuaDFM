## -------------------------------------------------------
## In Fw version 3.7.0 and next versions
## data sent on USB are in binary format
## -------------------------------------------------------

from time import sleep, time

import serial.tools.list_ports
import serial

from . import utils
from .com import Com

class ComBin(Com):
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
        ## macOs users can't send more than 375 bytes in a single write
        ## work around, split data
        size = len(data)
        i = 0
        while i < size:
            subLen = size
            if subLen > 375:
                subLen = 375
            self.__ser.write(data[i : i + subLen])
            i += subLen
        self.printFrame("Send Frame", data)
    
    ## read data
    def __read(self, size=1):
        retry  = 20
        lastError = None

        while retry > 0:
            try:
                return self.__ser.read(size)
            except serial.SerialException as err:
                ## this can happen on linux after device reboot
                ## device reports readiness to read but returned no data (device disconnected or multiple access on port?)
                sleep(0.2)
                retry -= 1
                lastError = err

        raise lastError

    ## Look for com port with active look VID PID
    def findDevice(self, timeout=15):
        t1 = time()
        while abs(time()-t1) < timeout:
            ports = serial.tools.list_ports.comports()
            for p in ports:
                if (p.vid == 0xFFFE) and (p.pid == 0x1112) and (p.device != ''):
                    return p.device

        return 

    def findDeviceBySerialId(self, serId, timeout=15):
        t1 = time()
        while abs(time()-t1) < timeout:
            ports = serial.tools.list_ports.comports()
            for p in ports:
                if (p.vid == 0xFFFE) and (p.pid == 0x1112) and (p.serial_number == serId) and (p.device != ''):
                    return p.device

        return 

    ## open serial
    def open(self, device):
        self.device = device
        retry = 30
        connected = False

        ## retry are for reconnection just after windows detection
        while (retry > 0) and not connected:
            try:
                self.__ser = serial.Serial(device, timeout=10.0)
                connected = True
            except serial.SerialException:
                retry -= 1
                sleep(1)

        if retry == 0 or not connected:
            raise serial.SerialException


    ## wait Com port to be colsed by device
    def waitForDeviceClose(self, timeout=20):
            start = time()
            while time() - start < timeout:
                try:
                    isinstance(self.__ser.in_waiting, int)
                except:
                    ## on failure the device is closed
                    return
            assert False, "Timeout on waiting for device disconnect"


    ## find device et open port when new driver is installed
    def reopenChangeID(self, serialId):
        ## wait for disconnect
        self.waitForDeviceClose()
        self.close()

        ## reopen
        device = self.findDeviceBySerialId(serialId)
        assert device, "device not connected"
        self.open(device)


    ## find device et open when restart but no new driver installed
    def reopen(self):
        ## wait for disconnect
        self.waitForDeviceClose()
        self.close()

        ## reopen
        device = self.findDevice()
        assert device, "device not connected"
        self.open(device)


    ##
    def close(self):
        self.__ser.close()
        
    ##
    def sendFrame(self, cmdId, data, queryId=[]):
        frame = self.formatFrame(cmdId, data, queryId)
        self.__sendData(frame)

    ## return : {'ret', 'cmdId', 'data'}
    def receiveFrame(self, cmdId):
        nack = bytes([0xF1])

        while 1:
            b = self.__read(1)
            if len(b) != 1:
                ## Timeout
                return  {'ret': False, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}

            if self.__rcvState == self.__RCV_STATE_START:
                if b == nack:
                    print("received NACK")
                    return  {'ret': False, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}
            
            if self.__rcvByte(b[0]):
                if self.__rcvCmdId == cmdId:
                    return  {'ret': True, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}
                else:
                    if not self.__asyncData():
                        self.printFrameError("wrong cmd Id received", self.__rcvRawFrame)
                        return  {'ret': False, 'cmdId': self.__rcvCmdId, 'data': self.__rcvData, 'query': self.__rcvQuery}

    ## receive answer to cmd
    def receiveAck(self):
        return self.receive()

    ## receive answer to cmd
    def receive(self):
        ack = bytes([0xF0])
        nack = bytes([0xF1])

        while 1:
            data = self.__read(1)

            if len(data) != 1:
                ## timeout
                return False
            else:
                if self.__rcvState == self.__RCV_STATE_START:
                    if data == ack:
                        return True
                    elif data == nack:
                        print("received NACK")
                        return False
                if self.__rcvByte(data[0]):
                    if not self.__asyncData():
                        self.printFrameError("Wrong ack", self.__rcvRawFrame)

    ##
    def receiveUsbMsg(self):
        ack = bytes([0xF0])
        nack = bytes([0xF1])

        while 1:
            data = self.__read(1)

            if len(data) != 1:
                ## timeout
                return ""
            else:
                if self.__rcvState == self.__RCV_STATE_START:
                    if data == ack:
                        return ""
                    elif data == nack:
                        print("received NACK")
                        return ""

                if self.__rcvByte(data[0]):
                    if self.__rcvCmdId == 0xB4:
                        return utils.listToStr(self.__rcvData)
                    if not self.__asyncData():
                        self.printFrameError("Wrong ack", self.__rcvRawFrame)

    ## send data
    def sendRawData(self, bin):
        self.__sendData(bin)
    
    ## set read timeout
    def setTimeout(self, val):
        self.__ser.timeout = val

    ## get read timeout
    def getTimeout(self):
        return self.__ser._timeout
