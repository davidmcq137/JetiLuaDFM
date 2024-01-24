import struct

from .command import Command
from . import utils
from . import fontAdd

import numpy as np

class CommandPub(Command):

    def __init__(self, com):
        Command.__init__(self, com)

    ## set the power of display and initialize display
    def powerDisplayOn(self):
        data = [1]
        self._Command__com.sendFrame(0x00, data)
        return self._Command__com.receiveAck()
    
    ## disable the power of display
    def powerDisplayOff(self):
        data = [0]
        self._Command__com.sendFrame(0x00, data)
        return self._Command__com.receiveAck()

    ## Clear the display memory (black screen)
    def clear(self):
        data = []
        self._Command__com.sendFrame(0x01, data)
        return self._Command__com.receiveAck()

    ## Set the whole display memory to the corresponding grey level
    def grey(self, grey):
        data = [grey]
        self._Command__com.sendFrame(0x02, data)
        return self._Command__com.receiveAck()

    ## Display demonstration pattern
    def demo(self, id):
        data = [id]
        self._Command__com.sendFrame(0x03, data)
        return self._Command__com.receiveAck()

    ## Return the battery level on the bas service
    def battery(self):
        cmdId = 0x05
        name = self.battery.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, 0)

        data = rcv['data']

        ## decod data
        battLevel = data[0]

        print(f"{name}: {battLevel}%")
        return (True, battLevel)

    ## Get the board ID and firmware version.
    def vers(self):
        cmdId = 0x06
        name = self.vers.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [0, 0, 0, 0], [0, 0, 0])

        data = rcv['data']

        ## decod data
        versMajor = data[0]
        versMinor = data[1]
        versPatch = data[2]
        versChar = data[3]
        versYear = data[4]
        versWeek = data[5]
        versNumber= (data[6] << 16) | (data[7] << 8) | data[8]

        version = [versMajor, versMinor, versPatch, versChar]
        serial = [versYear, versWeek, versNumber]

        print(f"{name}: {versMajor}.{versMinor}.{versPatch}{chr(versChar)} {versYear:02d}{versWeek:02d}{versNumber:06d} ({versYear:02d}/{versWeek:02d} {versNumber:06d})")
        return (True, version, serial)

    ## Activate/deactivate green led: 0 = OFF, 1 = ON, 2 = toggle
    def led(self, mode):
        data = [mode]
        self._Command__com.sendFrame(0x08, data)
        return self._Command__com.receiveAck()

    ## Shift all subsequent displayed object of (x,y) pixels
    def shift(self, x, y):
        x = utils.clamp(x,-128,127)
        y = utils.clamp(y,-128,127)
        data = utils.sShortToList(x)
        data += utils.sShortToList(y)
        self._Command__com.sendFrame(0x09, data)
        return self._Command__com.receiveAck()

    ## Return the user parameters used (shift, luma, sensor)
    def settings(self):
        cmdId = 0x0A
        name = self.settings.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, 0, 0, 0, False, False)

        data = rcv['data']

        ## decod data
        x = np.byte(data[0])
        y = np.byte(data[1])
        luma = data[2]
        if data[3] != 0:
            als = True
        else:
            als = False
        if data[4] != 0:
            gesture = True
        else:
            gesture = False

        print(f"{name}: x: {x}, y: {y}, luma: {luma}, als: {als}, gesture: {gesture}")
        return (True, x, y, luma, als, gesture)

    ## set luminance
    def luma(self, luma):
        data = [luma]
        self._Command__com.sendFrame(0x10, data)
        return self._Command__com.receiveAck()

    ##
    def enableSensor(self, enable):
        data = [enable]
        self._Command__com.sendFrame(0x20, data)
        return self._Command__com.receiveAck()

    ##
    def enableGesture(self, enable):
        data = [enable]
        self._Command__com.sendFrame(0x21, data)
        return self._Command__com.receiveAck()

    ##
    def enableAls(self, enable):
        data = [enable]
        self._Command__com.sendFrame(0x22, data)
        return self._Command__com.receiveAck()

    ## set greylevel: 0x00 to 0x0F
    def color(self, greyLevel):
        name = self.color.__name__
        if 0x00 <= greyLevel <= 0x0F:
            data = [greyLevel]
            self._Command__com.sendFrame(0x30, data)
            return self._Command__com.receiveAck()
        else:
            print(f'{name}: greylevel out of range : 0x00 <= greyLevel <= 0x0F')
            return False

    ## Set a pixel on at the corresponding coordinates
    def point(self, x0, y0):
        data = utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        self._Command__com.sendFrame(0x31, data)
        return self._Command__com.receiveAck()
    
    ## 	Draw a line at the corresponding coordinates
    def line(self, x0, y0, x1, y1):
        data = utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += utils.sShortToList(x1)
        data += utils.sShortToList(y1)
        self._Command__com.sendFrame(0x32, data)
        return self._Command__com.receiveAck()
    
    ## draw rectangle
    def rect(self, x0, y0, x1, y1):
        data = utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += utils.sShortToList(x1)
        data += utils.sShortToList(y1)
        self._Command__com.sendFrame(0x33, data)
        return self._Command__com.receiveAck()

    ## draw full rectangle
    def rectFull(self, x0, y0, x1, y1):
        data = utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += utils.sShortToList(x1)
        data += utils.sShortToList(y1)
        self._Command__com.sendFrame(0x34, data)
        return self._Command__com.receiveAck()

    ## Draw an empty circle at the corresponding coordinates
    def circ(self, x, y, r):
        data = utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += [r]
        self._Command__com.sendFrame(0x35, data)
        return self._Command__com.receiveAck()

    ## Draw an full circle at the corresponding coordinates
    def circFull(self, x, y, r):
        data = utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += [r]
        self._Command__com.sendFrame(0x36, data)
        return self._Command__com.receiveAck()

    ## display txt
    def txt(self, x0, y0, rot, font, color, str):
        data = utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += [rot, font, color]
        data += utils.strToList(str)
        self._Command__com.sendFrame(0x37, data)
        return self._Command__com.receiveAck()

    ## 	Draw multiples lines at the corresponding coordinates
    def polyline(self, coords = [[0, 0], [10, 10]], thickness=1):
        data = []
        data += [thickness, 0, 0]    # thickness and properties
        for x, y in coords:
            data += utils.sShortToList(x)
            data += utils.sShortToList(y)

        self._Command__com.sendFrame(0x38, data)
        return self._Command__com.receiveAck()

    ## 	Hold display
    def dispHold(self):
        data = [0]
        self._Command__com.sendFrame(0x39, data)
        return self._Command__com.receiveAck()

    ## 	Flush display
    def dispFlush(self):
        data = [1]
        self._Command__com.sendFrame(0x39, data)
        return self._Command__com.receiveAck()

    ##
    def imgListDeprecated(self):
        cmdId = 0x40
        name = self.imgListDeprecated.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)
        
        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [])

        data = rcv['data']

        imgData = []
        strImgData = ""

        bin = bytearray(data)
        if len(bin):
            fmt = ">%dH" % (len(bin) / 2)
            listUShort = struct.unpack(fmt, bin)
            grp = zip(*[iter(listUShort)]*2)
            for y, x in grp:
                imgData.append([x, y])
                strImgData += f" (x: {x}, y: {y})"
        
        print(f"{name}: nbBmp {len(imgData)}{strImgData}")
        return (True, imgData)

    ##
    def imgDisplay(self, id, x, y):
        data = [id]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        self._Command__com.sendFrame(0x42, data)
        return self._Command__com.receiveAck()

    ## Erase all bitmaps with numbers >= bmpId
    def imgDeleteDeprecated(self, id = 0):
        data = [id]
        self._Command__com.sendFrame(0x43, data)
        return self._Command__com.receiveAck()

    ## Erase a bitmap,  0xFF will delete all bitmaps
    def imgDelete(self, id):
        data = [id]
        self._Command__com.sendFrame(0x46, data)
        return self._Command__com.receiveAck()

    ##
    def imgList(self):
        cmdId = 0x47
        name = self.imgList.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)
        
        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [])

        data = rcv['data']

        imgData = []
        strImgData = ""

        i = 0
        while i < len(data):
            id = data[i]
            y = utils.listToShort(data[i + 1:i + 3])
            x = utils.listToShort(data[i + 3:i + 5])

            imgData.append([id, x, y])
            strImgData += f" (Id: {id}, x: {x}, y: {y})"

            i += 5

        print(f"{name}: nbImg {len(imgData)}{strImgData}")
        return (True, imgData)

    ## Font functions 

    def fontList(self):
        cmdId = 0x50
        name = self.fontList.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)
        rcv = self.rcvAnswer(name, cmdId)
        
        if not rcv['ret']:
            return (False, [])

        data = rcv['data']
        
        fontData = []
        i = 0
        while i < len(data):
            id = data[i]
            height = data[i+1]
            fontData.append([id, height])
            i +=2

        return (True, fontData)


    def fontSave(self, id, height, path, firstChar, lastChar, newFormat=True, widthDict={}, baseline=0.25):
        cmdId = 0x51
        if newFormat:
            fmt = 0x02
        else:
            fmt = 0x01

        data = fontAdd.getFontData(height, path, firstChar, lastChar, fmt, widthDict, baseline)
        size = len(data)

        ## first chunk init id and size
        header =  [id] + utils.uShortToList(size)
        self._Command__com.sendFrame(cmdId, header)
        if not self._Command__com.receiveAck():
            return False

        max = self._Command__com.getDataSizeMax()
        i = 0
        while size > 0:
            chunkSize = size
            if chunkSize > max:
                chunkSize = max
            chunck = data[i : i + chunkSize]

            self._Command__com.sendFrame(cmdId, chunck)
            if not self._Command__com.receiveAck():
                return False
            
            i += chunkSize
            size -= chunkSize

        return True


    def fontSelect(self, font):
        cmdId = 0x52
        data = [font]
        self._Command__com.sendFrame(cmdId, data)
        return self._Command__com.receiveAck()


    def fontDelete(self, font):
        cmdId = 0x53
        data = [font]
        self._Command__com.sendFrame(cmdId, data)
        return self._Command__com.receiveAck()


    ## predefined layout ID
    LAYOUT_BOOT_ID =               0
    LAYOUT_CONNECT_DEVICE_ID =     2
    LAYOUT_CONNECTED_ID =          3
    LAYOUT_CONNECTION_LOST_ID =    4
    LAYOUT_BYE_BYE_ID =            5
    LAYOUT_BATTERY_ID =            7
    LAYOUT_SUOTA_ID =              9

    ## format layout bitmap additional command
    def layoutCmdImg(self, id, x, y):
        data = [0x00, id]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        return data

    ## format layout circle additional command
    def layoutCmdCircle(self, x, y, r):
        data = [0x01]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += utils.uShortToList(r)
        return data
    
    ## format layout full circle additional command
    def layoutCmdCircleFull(self, x, y, r):
        data = [0x02]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += utils.uShortToList(r)
        return data

    ## format layout grey level additional command
    def layoutCmdGreyLvl(self, level):
        data = [0x03, level]
        return data

    ## format layout font additional command
    def layoutCmdFont(self, font):
        data = [0x04, font]
        return data

    ## format layout line additional command
    def layoutCmdLine(self, x0, y0, x1, y1):
        data = [0x05]
        data += utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += utils.sShortToList(x1)
        data += utils.sShortToList(y1)
        return data

    ## format layout point additional command
    def layoutCmdPoint(self, x, y):
        data = [0x06]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        return data

    ## format layout rectangle additional command
    def layoutCmdRect(self, x0, y0, x1, y1):
        data = [0x07]
        data += utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += utils.sShortToList(x1)
        data += utils.sShortToList(y1)
        return data
    
    ## format layout full rectangle additional command
    def layoutCmdRectFull(self, x0, y0, x1, y1):
        data = [0x08]
        data += utils.sShortToList(x0)
        data += utils.sShortToList(y0)
        data += utils.sShortToList(x1)
        data += utils.sShortToList(y1)
        return data

    ## format layout text additional command
    def layoutCmdText(self, x, y, txt):
        data = [0x09]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += [len(txt)]
        data += [ord(char) for char in txt] ## convert string to list
        return data

    ## format layout gauge additional command
    def layoutCmdGauge(self, gaugeId):
        data = [0x0A, gaugeId]
        return data

    ## format layout animation display additional command
    def layoutCmdAnimDisplay(self, handlerId, id, delay, repeat, x, y):
        data = [0x0B, handlerId, id]
        data += utils.uShortToList(delay)
        data += [repeat]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        return data
    
    def layoutCmdPolyLine(self, points, thickness=1):
        data = [0x0C]
        data += [len(points)]
        data += [thickness, 0, 0]    # thickness and properties
        for point in points:
            data += utils.sShortToList(point[0])
            data += utils.sShortToList(point[1])
        return data
    
    ## save layout with text only
    ## foreColor: 0 to 0xF
    def layoutSave(self, id, x0, y0, width, height, foreColor, backColor, font, txtX0, txtY0, txtRot, txtOpacity, usetxt = True, cmd = []):
        name = self.layoutSave.__name__

        if not 0x00 <= foreColor <= 0x0F:
                print(f"{name}: foreColor out of range, need to be 0 <= {foreColor} <= 15")
        if not 0x00 <= backColor <= 0x0F:
                print(f"{name}: backColor out of range, need to be 0 <= {backColor} <= 15")

        textValid = 0
        if (usetxt):
            textValid = 1

        data = [id, len(cmd)]
        data += utils.uShortToList(x0)
        data += [y0]
        data += utils.uShortToList(width)
        data += [height, foreColor, backColor, font, textValid]
        data += utils.uShortToList(txtX0)
        data += [txtY0, txtRot, txtOpacity]
        data += cmd

        self._Command__com.sendFrame(0x60, data)
        return self._Command__com.receiveAck()

    ## erase layout
    def layoutDelete(self, id):
        data = [id]
        self._Command__com.sendFrame(0x61, data)
        return self._Command__com.receiveAck()

    ## display layout
    def layoutDisplay(self, id, str):
        data = [id]
        data += utils.strToList(str)
        self._Command__com.sendFrame(0x62, data)
        return self._Command__com.receiveAck()

    ## clear layout
    def layoutClear(self, id):
        data = [id]
        self._Command__com.sendFrame(0x63, data)
        return self._Command__com.receiveAck()

    ## list layout
    ## return : {'ret', 'layoutIdx'}
    def layoutList(self):
        cmdId = 0x64
        name = self.layoutList.__name__
        self._Command__com.sendFrame(cmdId, [])
        
        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [])

        ids = rcv['data']

        print(f"{name}: nb {len(ids)}: {ids}")
        return (True, ids)

    ## change layout position
    def layoutPos(self, id, x, y):
        data = [id]
        data += utils.uShortToList(x)
        data += [y]
        self._Command__com.sendFrame(0x65, data)
        return self._Command__com.receiveAck()

    ## display layout
    def layoutEx(self, id, x, y, str, extra_cmd=[]):
        data = [id]
        data += utils.uShortToList(x)
        data += [y]
        data += utils.strToList(str)
        data += extra_cmd
        self._Command__com.sendFrame(0x66, data)
        return self._Command__com.receiveAck()
    
    ## list layout
    ## return : {'ret', 'layoutIdx'}
    def layoutGet(self, layoutId):
        cmdId = 0x67
        name = self.layoutGet.__name__
        data = [layoutId]
        self._Command__com.sendFrame(cmdId, data)
        
        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, [])

        data = rcv['data']
        size = data[0]
        x = utils.listToUShort(data[1:3])
        y =  data[3]
        width = utils.listToUShort(data[4:6])
        height = data[6]
        foreColor = data[7]
        backColor = data[8]
        font = data[9]
        textValid = data[10]
        txtX0 = utils.listToUShort(data[11:13])
        txtY0 = data[13]
        txtRot = data[14]
        txtOpacity = data[15]
        cmd = data[16:]

        print(f"layout #{layoutId} x: {x}, y: {y}, width: {width}, height: {height}, foreColor: {foreColor}, backColor: {backColor}, font: {font}, textValid: {textValid}, txtX0: {txtX0}, txtY0: {txtY0}, txtRot: {txtRot}, txtOpacity: {txtOpacity}")
        
        return (True, size, x, y, width, height, foreColor, backColor, font, textValid, txtX0, txtY0, txtRot, txtOpacity, cmd)

    ## clear a layout at a specific position
    def layoutClearEx(self, id, x, y):
        data = [id]
        data += utils.uShortToList(x)
        data += [y]
        self._Command__com.sendFrame(0x68, data)
        return self._Command__com.receiveAck()

    ## clear and display layout
    def layoutClearAndDisplay(self, id, str):
        data = [id]
        data += utils.strToList(str)
        self._Command__com.sendFrame(0x69, data)
        return self._Command__com.receiveAck()

    ## display layout
    def layoutClearAndDisplayEx(self, id, x, y, str, extra_cmd=[]):
        data = [id]
        data += utils.uShortToList(x)
        data += [y]
        data += utils.strToList(str)
        data += extra_cmd
        self._Command__com.sendFrame(0x6A, data)
        return self._Command__com.receiveAck()

    ## Display value (in percentage) of the gauge
    def gaugeDisplay(self, id, value):
        data = [id, value]
        self._Command__com.sendFrame(0x70, data)
        return self._Command__com.receiveAck()

    ## Save the parameters for the gauge nb
    def gaugeSave(self, id, x, y, rExt, rIn, startCoord, endCoord, clockWise):
        clockWiseNum = 1 if clockWise else 0
        data = [id]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += utils.uShortToList(rExt)
        data += utils.uShortToList(rIn)
        data += [startCoord, endCoord, clockWiseNum]
        self._Command__com.sendFrame(0x71, data)
        return self._Command__com.receiveAck()

    ## delete a gauge, 0xFF delete all gauges
    def gaugeDelete(self, id):
        data = [id]
        self._Command__com.sendFrame(0x72, data)
        return self._Command__com.receiveAck()

    ##
    def gaugeList(self):
        cmdId = 0x73
        name = self.gaugeList.__name__
        self._Command__com.sendFrame(cmdId, [])

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [])

        ids = rcv['data']

        print(f"{name}: {ids}")
        return (True, ids)

    ##
    def gaugeGet(self, id):
        cmdId = 0x74
        name = self.gaugeGet.__name__
        self._Command__com.sendFrame(cmdId, [id])

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, 0,  0, 0, 0, 0, 0, False)

        data = rcv['data']

        x = utils.listToShort(data[0:2])
        y = utils.listToShort(data[2:4])
        r = utils.listToUShort(data[4:6])
        rIn = utils.listToUShort(data[6:8])
        start = data[8]
        end = data[9]
        clockWise = bool(data[10])

        print(f"{name}: #{id} x: {x}, y: {y}, r: {r}, rIn: {rIn}, start: {start}, end: {end}, clockWise: {clockWise}")
        return (True, x, y, r, rIn, start, end, clockWise)

    ##
    def pageSave(self, id, layouts = [[0x01, 0, 0]]):
        data = [id]
        for layoutId, x, y in layouts:
            data += [layoutId]
            data += utils.uShortToList(x)
            data += [y]
        
        self._Command__com.sendFrame(0x80, data)
        return self._Command__com.receiveAck()
    
    ##
    def pageGet(self, id):
        cmdId = 0x81
        name = self.pageGet.__name__
        self._Command__com.sendFrame(cmdId, [id])

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, -1, [])

        data = rcv['data']

        layouts = []
        msg = ""

        id = data[0]
        for i in range(1, len(data), 4):
            layoutId = data[i]
            i += 1
            x = utils.listToUShort(data[i:i+2])
            i += 2
            y = data[i]
            layouts.append([layoutId, x, y])
            msg += f" (id: {layoutId}, x: {x}, y: {y})"

        print(f"{name}: #{id}{msg}")
        return (True, id, layouts)

    ##
    def pageDelete(self, id):
        data = [id]
        self._Command__com.sendFrame(0x82, data)
        return self._Command__com.receiveAck()
    
    ##
    def pageDisplay(self, id, strings = ["1", "2"]):
        data = [id]
        for s in strings:
            data += utils.strToList(s)
        self._Command__com.sendFrame(0x83, data)
        return self._Command__com.receiveAck()

    ##
    def pageClear(self, id):
        data = [id]
        self._Command__com.sendFrame(0x84, data)
        return self._Command__com.receiveAck()

    ##
    def pageList(self):
        cmdId = 0x85
        name = self.pageList.__name__
        self._Command__com.sendFrame(cmdId, [])

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [])

        ids = rcv['data']

        print(f"{name}: {ids}")
        return (True, ids)

    ##
    def pageClearAndDisplay(self, id, strings = ["1", "2"]):
        data = [id]
        for s in strings:
            data += utils.strToList(s)
        self._Command__com.sendFrame(0x86, data)
        return self._Command__com.receiveAck()

    ## Delete an animation
    def animDelete(self, id):
        data = [id]
        self._Command__com.sendFrame(0x96, data)
        return self._Command__com.receiveAck()

    ## Display animation
    def animDisplay(self, handlerId, id, delay, repeat, x, y):
        data = [handlerId, id]
        data += utils.uShortToList(delay)
        data += [repeat]
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        self._Command__com.sendFrame(0x97, data)
        return self._Command__com.receiveAck()

    ## Stop and clear the screen of the corresponding animation
    def animClear(self, handlerId):
        data = [handlerId]
        self._Command__com.sendFrame(0x98, data)
        return self._Command__com.receiveAck()

    ##
    def animList(self):
        cmdId = 0x99
        name = self.animList.__name__
        self._Command__com.sendFrame(cmdId, [])

        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, [])

        ids = rcv['data']

        print(f"{name}: {ids}")
        return (True, ids)
    
    ## write config ID
    def cfgWriteDeprecated(self, cfgIdx, cfgId, nbBmp, nblayout, nbFont):
        data = [cfgIdx]
        data += utils.intToList(cfgId)
        data += [nbBmp, nblayout, nbFont]
        self._Command__com.sendFrame(0xA1, data)
        return self._Command__com.receiveAck()

    ## read config ID
    ## return : ('ret', 'cfgIdx', 'cfgId', 'nbBmp', 'nblayout', 'nbFont')
    def cfgReadDeprecated(self, id):
        cmdId = 0xA2
        name = self.cfgReadDeprecated.__name__
        data = [id]
        self._Command__com.sendFrame(cmdId, data)
        
        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, 0, 0, 0, 0, 0)

        data = rcv['data']

        ## decod data
        version = utils.listToUInt(data[1:5])
        nbBmp = data[5]
        nblayout = data[6]
        nbFont = data[7]

        print(f"{name}: id: {id} version: {version:x} nbBmp: {nbBmp} nblayout: {nblayout} nbFont {nbFont}")
        return (True, id, version, nbBmp, nblayout, nbFont)

    ## set config
    def cfgSetDeprecated(self, cfgidx):
        data = [cfgidx]
        self._Command__com.sendFrame(0xA3, data)
        return self._Command__com.receiveAck()

    ## Get number of pixel activated on display
    def pixelCount(self, verb=True):
        cmdId = 0xA5
        name = self.pixelCount.__name__
        data = []
        self._Command__com.sendFrame(cmdId, data)
        
        rcv = self.rcvAnswer(name, cmdId)
        if not rcv['ret']:
            return (False, 0)

        data = rcv['data']

        ## decod data
        count = utils.listToUInt(data)
        if verb:
            print(f"{name}: {count}")
        return (True, count)

    ## Write configuration
    def cfgWrite(self, name, version, password):
        data = utils.strToList(name, self.CFG_NAME_LEN)
        data += utils.intToList(version)
        data += utils.intToList(password)
        self._Command__com.sendFrame(0xD0, data)
        return self._Command__com.receiveAck()

    ## Read configuration
    def cfgRead(self, name):
        bak = self._Command__com.getTimeout()
        self._Command__com.setTimeout(self.longTimeout)

        cmdId = 0xD1
        funcName = self.cfgRead.__name__
        data = utils.strToList(name, self.CFG_NAME_LEN)
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(funcName, cmdId)
        if not rcv['ret']:
            return (False, 0, 0, 0, 0, 0, 0)

        self._Command__com.setTimeout(bak)

        version = utils.listToUInt(rcv['data'][0:4])
        nbImg = rcv['data'][4]
        nbLayout = rcv['data'][5]
        nbFont = rcv['data'][6]
        nbPage = rcv['data'][7]
        nbGauge = rcv['data'][8]

        print(f"{funcName}: version: {version}, nbImg: {nbImg}, nbLayout: {nbLayout}, nbFont: {nbFont}, nbPage: {nbPage}, nbGauge: {nbGauge}")
        
        return (True, version, nbImg, nbLayout, nbFont, nbPage, nbGauge)

    ## Select the current configuration used to display layouts, images, etc
    def cfgSet(self, name):
        data = utils.strToList(name, self.CFG_NAME_LEN)
        self._Command__com.sendFrame(0xD2, data)
        return self._Command__com.receiveAck()

    ## List configurations in memory
    def cfgList(self):
        bak = self._Command__com.getTimeout()
        self._Command__com.setTimeout(self.longTimeout)

        cmdId = 0xD3
        data = []
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(self.cfgList.__name__, cmdId)
        if not rcv['ret']:
            return (False, [])

        self._Command__com.setTimeout(bak)
        
        i = 0
        data = rcv['data']
        lst = []
        while i < len(data):
            cfg = {'name': "", 'size': 0, 'version': 0, 'usgCnt': 0, 'installCnt': 0, 'isSystem': 0}

            cfg['name'] = utils.listToStr(data[i:], self.CFG_NAME_LEN)
            nameLen = len(cfg['name'])
            if nameLen < self.CFG_NAME_LEN:
                i += nameLen + 1 ## ignore '\0'
            else:
                i += self.CFG_NAME_LEN
            
            cfg['size'] = utils.listToUInt(data[i:i+4])
            i += 4

            cfg['version'] = utils.listToUInt(data[i:i+4])
            i += 4

            cfg['usgCnt'] = data[i]
            i += 1

            cfg['installCnt'] = data[i]
            i += 1

            cfg['isSystem'] = data[i]
            i += 1

            lst.append(cfg)
            print(f"cfg: {cfg['name']: <12} size: {cfg['size'] // 1024: >3} kb, version: {cfg['version']: >5}, usgCnt: {cfg['usgCnt']}, installCnt: {cfg['installCnt']}, isSystem: {cfg['isSystem']}")

        return (True, lst)

    ## rename a configuration
    def cfgRename(self, oldName, newName, password):
        data = utils.strToList(oldName, self.CFG_NAME_LEN)
        data += utils.strToList(newName, self.CFG_NAME_LEN)
        data += utils.intToList(password)
        self._Command__com.sendFrame(0xD4, data)
        return self._Command__com.receiveAck()

    ## delete a configuration
    def cfgDelete(self, name, usePassword = False, password = 0):
        bak = self._Command__com.getTimeout()
        self._Command__com.setTimeout(self.longTimeout)

        data = utils.strToList(name, self.CFG_NAME_LEN)
        if usePassword:
            data += utils.intToList(password)
        self._Command__com.sendFrame(0xD5, data)
        ret = self._Command__com.receiveAck()

        self._Command__com.setTimeout(bak)

        return ret

    ## 	Delete the configuration that has not been used for the longest time
    def cfgDeleteLessUsed(self):
        bak = self._Command__com.getTimeout()
        self._Command__com.setTimeout(self.longTimeout)

        data = []
        self._Command__com.sendFrame(0xD6, data)
        ret = self._Command__com.receiveAck()

        self._Command__com.setTimeout(bak)

        return ret

    ## get free space available
    def cfgFreeSpace(self):
        bak = self._Command__com.getTimeout()
        self._Command__com.setTimeout(self.longTimeout)

        cmdId = 0xD7
        data = []
        self._Command__com.sendFrame(cmdId, data)
        
        rcv = self.rcvAnswer(self.cfgFreeSpace.__name__, cmdId)
        if not rcv['ret']:
            return (False, 0, 0)

        self._Command__com.setTimeout(bak)

        totalSize = utils.listToUInt(rcv['data'][0:4])
        freeSpace = utils.listToUInt(rcv['data'][4:8])

        print(f"Cfg: totalSize: {totalSize // 1024} kB, freeSpace: {freeSpace // 1024} kB, usedSpace: {(totalSize - freeSpace) // 1024} kB")

        return (True, totalSize, freeSpace)

    ## get number of config
    def cfgGetNb(self):
        cmdId = 0xD8
        data = []
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(self.cfgGetNb.__name__, cmdId)
        if not rcv['ret']:
            return (False, 0)

        nb = rcv['data'][0]

        print(f"Cfg: nb:{nb}")

        return (True, nb)

    ## Shutdown the device
    def shutdown(self):
        data = [0x6F, 0x7F, 0xC4, 0xEE]
        self._Command__com.sendFrame(0xE0, data)
        return self._Command__com.receiveAck()

    ## Reset the device
    def reset(self):
        data = [0x5C, 0x1E, 0x2D, 0xE9]
        self._Command__com.sendFrame(0xE1, data)
        return self._Command__com.receiveAck()
    
    ## Read device info parameter
    PROD_PARAM_ID_HW_PLATFORM = 0
    PROD_PARAM_ID_MANUFACTURER = 1
    PROD_PARAM_ID_MFR_ID = 2
    PROD_PARAM_ID_MODEL = 3
    PROD_PARAM_ID_SUB_MODEL = 4
    PROD_PARAM_ID_FW_VERSION = 5
    PROD_PARAM_ID_SERIAL_NUMBER = 6
    PROD_PARAM_ID_BATT_MODEL = 7
    PROD_PARAM_ID_LENS_MODEL = 8
    PROD_PARAM_ID_DISPLAY_MODEL = 9
    PROD_PARAM_ID_DISPLAY_ORIENTATION = 10
    PROD_PARAM_ID_CERTIF_1 = 11
    PROD_PARAM_ID_CERTIF_2 = 12
    PROD_PARAM_ID_CERTIF_3 = 13
    PROD_PARAM_ID_CERTIF_4 = 14
    PROD_PARAM_ID_CERTIF_5 = 15
    PROD_PARAM_ID_CERTIF_6 = 16
    def rdDevInfo(self, paramId):
        cmdId = 0xE3
        data = [paramId]
        self._Command__com.sendFrame(cmdId, data)

        rcv = self.rcvAnswer(self.rdDevInfo.__name__, cmdId)
        if not rcv['ret']:
            return (False, [])

        data =  rcv['data']

        intFmt = ', '.join(str(i) for i in data)
        hexFmt = ', '.join(f'0x{x:02X}' for x in data)
        strFmt = ''.join(chr(c) for c in data)

        idName = ["HW_PLATFORM", "MANUFACTURER", "MFR_ID", "PRODUCT_TYPE", "SUB_MODEL", "FW_VERSION", "SERIAL_NUMBER", "BATT_MODEL", "LENS_MODEL", "DISPLAY_MODEL", "DISPLAY_ORIENTATION", "CERTIF_1", "CERTIF_2", "CERTIF_3", "CERTIF_4", "CERTIF_5", "CERTIF_6"]
        print(f"{idName[paramId]}:\n\tint: [{intFmt}]\n\thex: [{hexFmt}]\n\tstr: [{strFmt}]")

        return (True, data)
