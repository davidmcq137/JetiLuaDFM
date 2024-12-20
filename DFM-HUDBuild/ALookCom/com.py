import time

from . import utils

class Com:
    FRAME_HEADER =         0xFF
    FRAME_FOOTER =         0xAA
    FRAME_FMT_LEN_2BYTES = 0x10

    ## constructor
    def __init__(self, verbose = True):
        self.__logRawFilename = None
        self.__verbose = verbose

        self.error = (False, [], 0xFF, 0, 0)

    ## manage error in decodFrame
    def printFrameError(self, error, frame):
        if self.__verbose:
            frameLen = len(frame)
            shift = (frameLen - 1) * 8

            ## put the frame on a single integer
            val = 0
            for value in frame:
                val += (value << shift)
                shift -= 8
            
            print(f"Frame Error: {val:x}")

            if error:
                print(f"Error: {error}")
    
    ##
    def printFrame(self, strheader, frame):
        if self.__verbose:
            frameLen = len(frame)
            shift = (frameLen - 1) * 8

            ## put the frame on a single integer
            val = 0
            for value in frame:
                val += (value << shift)
                shift -= 8
            
            print(f"{strheader} [ {val:x} ]")

    ## format frame before sending
    def formatFrame(self, cmdId, data, queryId=[]):
        dataSize = len(data)
        querySize = len(queryId)
        assert(querySize <= 15)
        
        frameLen = 5 + dataSize + querySize ## 5 = header + cmdId + fmt + len + footer
        lenNbByte = 1
        if frameLen > 0xFF:
            frameLen += 1
            lenNbByte = 2

        frame = []
        frame.append(self.FRAME_HEADER)               ## header
        frame.append(cmdId)                           ## cmdId
        if lenNbByte == 1:
            fmt = querySize
            frame.append(fmt)                         ## fmt
            frame.append(frameLen)                    ## len
        else:
            fmt = self.FRAME_FMT_LEN_2BYTES | querySize
            frame.append(fmt)                         ## fmt
            frame += utils.uShortToList(frameLen)     ## len MSB + LSB

        if querySize > 0:
            frame += queryId
        
        frame += data

        frame.append(self.FRAME_FOOTER)               ## footer
        
        return bytes(frame)

    ## set log file name
    def setLogRawFilename(self, filename, truncate = False):
        self.__logRawFilename = filename

        if truncate:
            f = open(self.__logRawFilename, "w")
            f.close()
    
    ## append to log raw file
    def logRawAppend(self, data):
        if self.__logRawFilename:
            f = open(self.__logRawFilename, "a")
            f.write("{0};{1}\n".format(time.time(), data.hex()))
            f.close()

    ## log raw data
    def logRaw(self, filename):
        self.setLogRawFilename(filename)

        # erase file
        f = open(filename, "w")
        f.close()

        while 1:
            self.receive()

    ## used by sub class on error command
    def _rcvError(self, querryId, cmdId, err, subErr):
        msg = {
            0x0000: "No error",

            0x0100: "generic error",

            0x0200: "missing config write permission",

            0x0300: "memory error",
            0x0305: "Error during device operation",
            0x0354: "Corrupted",
            0x0302: "No directory entry",
            0x0311: "Entry already exists",
            0x0314: "Entry is not a dir",
            0x0315: "Entry is a dir",
            0x0327: "Dir is not empty",
            0x0309: "Bad file number",
            0x031B: "File too large",
            0x0316: "Invalid parameter",
            0x031C: "No space left on device",
            0x030C: "No more memory available",
            0x033D: "No data/attr available",
            0x0324: "File name too long",

            0x0400: "protocol decoding error",

            0x0500: "low battery error"
        }
        
        errCode = err << 8 | subErr
        if errCode not in msg:
            msg[errCode] = "Unknown Error"
        
        print(f"error: cmdId = 0x{cmdId:02X}, err = 0x{errCode:04X} ({msg[errCode]})")
        self.error = (True, querryId, cmdId, err, subErr)

    ## get last error
    def getLastError(self):
        err = self.error
        self.error = (False, [], 0xFF, 0, 0)
        return err
    
    ## Look for a connectable device, return the device
    def findDevice(self):
        raise NotImplementedError

    ## connect to device
    def open(self, device):
        raise NotImplementedError

    ## device disconnect
    def close(self):
        raise NotImplementedError

    ##
    def sendFrame(self, cmdId, data, queryId=[]):
        raise NotImplementedError

    ## return : {'ret', 'cmdId', 'data'}
    def receiveFrame(self, cmdId):
        raise NotImplementedError
    
    ## receive answer to cmd
    ## return True/False
    def receiveAck(self):
        raise NotImplementedError

    ## receive answer to cmd
    def receive(self):
        raise NotImplementedError

    ##
    def receiveUsbMsg(self):
        raise NotImplementedError

    ## send data
    def sendRawData(self, bin):
        raise NotImplementedError

    ## get commands data max size
    def getDataSizeMax(self):
        return 512

    ## set read timeout
    def setTimeout(self, val):
        raise NotImplementedError

    ## get read timeout
    def getTimeout(self):
        raise NotImplementedError