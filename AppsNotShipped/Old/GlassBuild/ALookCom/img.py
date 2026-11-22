import time

import cv2
import numpy as np
import heatshrink2 as hs

from . import utils
from . import imgMdp08
from . import imgMdp05
from . import imgFmt
from .commandPub import CommandPub

class Img:
    def __init__(self, com):
        self.cmd = CommandPub(com)
        self.com = com

    ## convert pixels to specific format without compression
    def convert(self, img, fmt = imgFmt.MONO_4BPP):
        if fmt == imgFmt.MONO_4BPP:
            return imgMdp05.convertDefault(img)
        elif fmt == imgFmt.MONO_1BPP:
            return imgMdp05.convert1Bpp(img)
        elif fmt == imgFmt.STREAM_1BPP:
            return imgMdp05.convert1Bpp(img)
        elif fmt == imgFmt.STREAM_4BPP_HEATSHRINK:
            return imgMdp05.convertDefault(img)
        elif fmt == imgFmt.RYYG:
            return imgMdp08.convertViaDistanceToRyyg(img)
        elif fmt == imgFmt.RRYG:
            return imgMdp08.convertViaDistanceToRryg(img)
        elif fmt == imgFmt.MONO_4BPP_HEATSHRINK:
            return imgMdp05.convertDefault(img)
        elif fmt == imgFmt.MONO_4BPP_HEATSHRINK_SAVE_COMP:
            return imgMdp05.convertDefault(img)
        elif fmt == imgFmt.MONOALPHA_8BPP:
            return imgMdp05.convert8Bpp(img)
        else:
            raise Exception("Unknown format")

    ## compress 4bpp img
    def compress4bpp(self, img):
        height = len(img)
        width = len(img[0])

        encodedImg = []
        for i in range(height):
            byte = 0
            shift = 0
            for j in range(width):
                pxl = img[i, j]

                ## compress 4 bit per pixel
                byte += pxl << shift
                shift += 4
                if shift == 8:
                    encodedImg.append(byte)
                    byte = 0
                    shift = 0
            if shift != 0:
                encodedImg.append(byte)
        
        return encodedImg

    ## compress 1bpp img
    def compress1bpp(self, img):
        height = len(img)
        width = len(img[0])

        encodedImg = []
        for i in range(height):
            byte = 0
            shift = 0
            encodedLine = []
            for j in range(width):
                pxl = img[i, j]

                ## compress 1 bit per pixel
                byte += pxl << shift
                shift += 1
                if shift == 8:
                    encodedLine.append(byte)
                    byte = 0
                    shift = 0
            if shift != 0:
                encodedLine.append(byte)
            encodedImg.append(encodedLine)

        return encodedImg

    def compressHs(self, img):
        return list(hs.compress(img, window_sz2 = 8, lookahead_sz2 = 4))

    ## generate a random image
    def generateRandom(self, width, height):
        return np.random.randint(255, size=(height, width, 3), dtype=np.uint8)

    ## prepare command to save image
    def getCmd4Bpp(self, img, id):
        width = len(img[0])

        ## compress img 4 bit per pixel
        encodedImg = self.compress4bpp(img)

        ## start save image command
        if id == -1:
            ## image append, use deprecated command
            data = utils.intToList(len(encodedImg)) ## size in byte
            data += utils.uShortToList(width)
            cmds = [self.com.formatFrame(0x41, data)]
        else:
            ## use new command with format as parameter
            data = [id]
            data += utils.intToList(len(encodedImg)) ## size in byte
            data += utils.uShortToList(width)
            data += [imgFmt.MONO_4BPP]
            cmds = [self.com.formatFrame(0x41, data)]

        ## pack pixels in commands
        nbDataMax = self.com.getDataSizeMax()
        i = 0
        while i < len(encodedImg):
            if nbDataMax > (len(encodedImg) - i):
                nbDataMax = (len(encodedImg) - i)

            cmds += [self.com.formatFrame(0x41, encodedImg[i:(nbDataMax + i)])]
            i += nbDataMax

        return cmds
    
    ## prepare command to save image with transparency
    def getCmd8Bpp(self, img, id):
        width = len(img[0])
        encodedImg = sum((list(row) for row in img), [])

        ## use new command with format as parameter
        data = [id]
        data += utils.intToList(len(encodedImg)) ## size in byte
        data += utils.uShortToList(width)
        data += [imgFmt.MONOALPHA_8BPP]
        cmds = [self.com.formatFrame(0x41, data)]

        ## pack pixels in commands
        nbDataMax = self.com.getDataSizeMax()
        i = 0
        while i < len(encodedImg):
            if nbDataMax > (len(encodedImg) - i):
                nbDataMax = (len(encodedImg) - i)

            cmds += [self.com.formatFrame(0x41, encodedImg[i:(nbDataMax + i)])]
            i += nbDataMax

        return cmds

    # send compressed data to the firmware
    def getCmdCompress4BppHeatshrink(self, img, id, fmt):
        width = len(img[0])

        ## compress img 4 bit per pixel
        encodedImg = self.compress4bpp(img)
        
        ## compress 4bpp image with heatshrink
        compressedImg = self.compressHs(encodedImg)

        ## start save image command
        assert (id != -1), "image append not supported with heatshrink compression"
        data = [id]
        data += utils.intToList(len(encodedImg)) # image size before Heatshrink compression
        data += utils.uShortToList(width)        # image width in pixel
        if fmt in [imgFmt.MONO_4BPP_HEATSHRINK, imgFmt.MONO_4BPP_HEATSHRINK_SAVE_COMP]:
            data += [fmt]                        # specify the format 
        else:
            raise Exception("Unknown format")

        cmds = [self.com.formatFrame(0x41, data)]

        ## pack pixels in commands
        nbDataMax = self.com.getDataSizeMax()
        i = 0
        while i < len(compressedImg):
            if nbDataMax > (len(compressedImg) - i):
                nbDataMax = (len(compressedImg) - i)

            cmds += [self.com.formatFrame(0x41, compressedImg[i:(nbDataMax + i)])]
            i += nbDataMax

        return cmds

    ## prepare command for image saving, 1 bit per pixel
    def getCmd1Bpp(self, img, id):
        width = len(img[0])

        ## compress img 1 bit per pixel
        encodedImg = self.compress1bpp(img)

        ## start save image command
        if id == -1:
            ## image append, use deprecated command
            data = utils.intToList(len(encodedImg) * len(encodedImg[0])) ## size in byte
            data += utils.uShortToList(width)
            cmds = [self.com.formatFrame(0x45, data)]
        else:
            ## use new command with format as parameter
            data = [id]
            data += utils.intToList(len(encodedImg) * len(encodedImg[0])) ## size in byte
            data += utils.uShortToList(width)
            data += [imgFmt.MONO_1BPP]
            cmds = [self.com.formatFrame(0x41, data)]

        ## pack lines in commands
        ## a command must have only full line and not overflow command buffer
        cmdDataMax = self.com.getDataSizeMax()
        lineSize = len(encodedImg[0])
        nbLineMax = cmdDataMax // lineSize
        nbLine = len(encodedImg)
        lineIdx = 0
        while lineIdx < nbLine:
            if nbLineMax > (nbLine - lineIdx):
                nbLineMax = (nbLine - lineIdx)

            data = []
            for i in range(nbLineMax):
                data += encodedImg[lineIdx]
                lineIdx += 1
            cmds += [self.com.formatFrame(0x41, data)]

        return cmds

    ## prepare command for image streaming
    def getCmdStream1Bpp(self, img, x, y, useDeprecateCmd = False):
        width = len(img[0])
        
        ## compress img 1 bit per pixel
        encodedImg = self.compress1bpp(img)
        
        ## start stream command
        data = utils.intToList(len(encodedImg) * len(encodedImg[0])) ## compressed size in byte
        data += utils.uShortToList(width)
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        if not useDeprecateCmd:
            data += [imgFmt.MONO_1BPP]
        cmds = [self.com.formatFrame(0x44, data)]

        ## pack lines in commands
        ## a command must have only full line and not overflow command buffer
        cmdDataMax = self.com.getDataSizeMax()
        lineSize = len(encodedImg[0])
        nbLineMax = cmdDataMax // lineSize
        nbLine = len(encodedImg)
        lineIdx = 0
        while lineIdx < nbLine:
            if nbLineMax > (nbLine - lineIdx):
                nbLineMax = (nbLine - lineIdx)

            data = []
            for i in range(nbLineMax):
                data += encodedImg[lineIdx]
                lineIdx += 1
            cmds += [self.com.formatFrame(0x44, data)]

        return cmds

        ## prepare command for image streaming
    def getCmdStreamHs(self, img, x, y):
        width = len(img[0])
        
        ## compress img 4 bit per pixel
        encodedImg = self.compress4bpp(img)
        
        ## compress 4bpp image with heatshrink
        compressedImg = self.compressHs(encodedImg)
        
        ## start stream command
        data = utils.intToList(len(encodedImg)) # image size before Heatshrink compression
        data += utils.uShortToList(width)
        data += utils.sShortToList(x)
        data += utils.sShortToList(y)
        data += [imgFmt.MONO_4BPP_HEATSHRINK]
        cmds = [self.com.formatFrame(0x44, data)]

        ## pack pixels in commands
        nbDataMax = self.com.getDataSizeMax()
        i = 0
        while i < len(compressedImg):
            if nbDataMax > (len(compressedImg) - i):
                nbDataMax = (len(compressedImg) - i)

            cmds += [self.com.formatFrame(0x44, compressedImg[i:(nbDataMax + i)])]
            i += nbDataMax

        return cmds

    ## prepare command for image saving
    ## param is format specific
    def getCmd(self, img, id = -1, fmt = imgFmt.MONO_4BPP, param = {}):
        img = self.convert(img, fmt)
        
        if fmt == imgFmt.MONO_1BPP:
            cmds = self.getCmd1Bpp(img, id)
        elif fmt == imgFmt.STREAM_1BPP:
            x = param['x']
            y = param['y']
            useDeprecateCmd = param['useDeprecateCmd']
            cmds = self.getCmdStream1Bpp(img, x, y, useDeprecateCmd)
        elif fmt == imgFmt.STREAM_4BPP_HEATSHRINK:
            x = param['x']
            y = param['y']
            cmds = self.getCmdStreamHs(img, x, y)
        elif fmt in [imgFmt.MONO_4BPP_HEATSHRINK, imgFmt.MONO_4BPP_HEATSHRINK_SAVE_COMP]:
            cmds = self.getCmdCompress4BppHeatshrink(img, id, fmt)
        elif fmt == imgFmt.MONOALPHA_8BPP:
            cmds = self.getCmd8Bpp(img, id)
        else:
            ## 4bpp format
            cmds = self.getCmd4Bpp(img, id)
        
        return cmds

    ##
    def appendImageRandom(self, width, height, fmt = imgFmt.MONO_4BPP):
        return self.saveImageRandom(-1, width, height, fmt)

    ##
    def appendImage(self, filename = "img/smiley.png", fmt = imgFmt.MONO_4BPP):
        return self.saveImage(-1, filename, fmt)

    ##
    def saveImageRandom(self, id, width, height, fmt = imgFmt.MONO_4BPP, param = {}):
        img = self.generateRandom(width, height)
        
        ## convert image
        cmds = self.getCmd(img, id, fmt, param)

        ## send commands
        for i, c in enumerate(cmds):
            self.com.sendRawData(c)
            if not self.com.receiveAck():
                print(f"saveImageRandom cmd {i + 1}/{len(cmds)} failed")
                return False
        
        return True

    ## save image according to a chosen format 
    def saveImage(self, id, filename = "img/smiley.png", fmt = imgFmt.MONO_4BPP, param = {}):
        if (fmt == imgFmt.MONOALPHA_8BPP):
            ## alpha channel is kept to use transparency
            img = cv2.imread(filename, cv2.IMREAD_UNCHANGED)
        else:
            ## alpha channel is cropped
            img = cv2.imread(filename) 

        ## convert image
        cmds = self.getCmd(img, id, fmt, param)

        ## send commands
        for i, c in enumerate(cmds):
            self.com.sendRawData(c)
            if not self.com.receiveAck():
                print(f"saveImage cmd {i + 1}/{len(cmds)} failed")
                return False
        
        return True

    ##
    def saveImageHeatshrink(self, id, filename = "img/smiley.png"):
        return self.saveImage(id, filename, imgFmt.MONO_4BPP_HEATSHRINK)

    ##
    def saveImageRandomHeatshrink(self, id, width, height):
        return self.saveImageRandom(id, width, height, imgFmt.MONO_4BPP_HEATSHRINK)

    ##
    def saveImage1bpp(self, id, filename = "img/smiley.png"):
        return self.saveImage(self, id, filename, imgFmt.MONO_1BPP)

    ##
    def appendImage1Bpp(self, filename = "img/smiley.png"):
        return self.appendImage(filename, imgFmt.MONO_1BPP)

    ##
    def appendImageRandom1Bpp(self, width, height):
        return self.appendImageRandom(width, height, imgFmt.MONO_1BPP)

    ##
    def saveImageRandom1Bpp(self, id, width, height):
        return self.saveImageRandom(id, width, height, imgFmt.MONO_1BPP)

    ## display an image with streaming
    def stream(self, x = 0, y = 0, filename='img/smiley.png', fmt = imgFmt.STREAM_4BPP_HEATSHRINK, useDeprecateCmd = False):
        param = {'x': x, 'y': y, 'useDeprecateCmd': useDeprecateCmd}
        return self.saveImage(-1, filename, fmt, param)

    ## display an image with streaming
    def streamRandom(self, width, height,  x = 0, y = 0):
        param = {'x': x, 'y': y}
        return self.saveImageRandom(-1, width, height, imgFmt.STREAM_1BPP, param)

    ## display an gif with streaming
    def streamGif(self, x = 0, y = 0, gif='anim/monkey-228x228.gif', repeat = 0, fmt = imgFmt.STREAM_4BPP_HEATSHRINK, invertColor = True):
        print("Converting imgs...")

        ## get all images from the gif
        cap = cv2.VideoCapture(gif)
        imgLst = []
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if invertColor:
                frame = 255 - frame
            
            imgLst.append(frame)
        cap.release()

        ## get streaming commands for each images
        streamCmd = []
        for img in imgLst:
            param = {'x': x, 'y': y, 'useDeprecateCmd': False}
            cmd = self.getCmd(img, -1, fmt, param)
            streamCmd += [cmd]
        
        ## send commands
        print("Sending imgs...")
        cnt = 0
        start = time.perf_counter()
        for _ in range(repeat + 1):
            for cmdLst in streamCmd:
                for c in cmdLst:
                    self.com.sendRawData(c)
                    if not self.com.receiveAck():
                        print("Stream cmd failed")
                        return False

                ## measure perf
                cnt += 1
                if (cnt % 20) == 0:
                    fps = cnt / (time.perf_counter() - start)
                    print(f"Stream {fps:.2f} FPS")
        
        return True
