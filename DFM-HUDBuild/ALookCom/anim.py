import os

import cv2

from . import utils
from . import imgFmt
from .img import Img


class Anim:
    def __init__(self, com):
        self.com = com
        self.img = Img(com)

    ## return the number of elements before the fist difference
    def _sameValueLen(self, la, lb):
        assert(len(la) == len(lb)), "different length is not handled"

        cnt = 0
        for a, b in zip(la, lb):
            if a == b:
                cnt += 1
            else:
                break
        
        return cnt

    ## return the number of elements before the fist difference, start counting from the end
    def _sameValueLenReverse(self, la, lb):
        assert(len(la) == len(lb)), "different length is not handled"

        cnt = 0
        i = len(la)
        while i > 0:
            i -= 1
            if la[i] == lb[i]:
                cnt += 1
            else:
                break
        
        return cnt

    ## encode full image for animation
    def _encodFullImgCmd(self, fmt, img):
        if fmt in [imgFmt.MONO_4BPP, imgFmt.RYYG, imgFmt.RRYG]:
            encodedImg = self.img.compress4bpp(img)
            return (encodedImg, len(encodedImg), len(encodedImg))
        elif fmt == imgFmt.MONO_4BPP_HEATSHRINK:
            encodedImg = self.img.compress4bpp(img)
            compressedImg = self.img.compressHs(encodedImg)
            return (compressedImg, len(encodedImg), len(compressedImg))
        else:
            raise Exception("unsupported format")

    ## prepare command for animation saving
    def getCmd(self, id, imgs, fmt = imgFmt.MONO_4BPP, useDeprecateCmd = False):
        if useDeprecateCmd:
            assert(fmt in [imgFmt.MONO_4BPP])
        else:
            assert(fmt in [imgFmt.MONO_4BPP, imgFmt.MONO_4BPP_HEATSHRINK, imgFmt.RYYG, imgFmt.RRYG])

        firstImg = self.img.convert(imgs[0], fmt)

        ## first image encoded as complete image
        (rawAnim, imgSize, compressedSize) = self._encodFullImgCmd(fmt, firstImg)

        prev = firstImg

        width = firstImg.shape[1]

        for img in imgs[1:]:
            img = self.img.convert(img, fmt)

            ## crop width
            lines = []
            for i, line in enumerate(img):
                ## crop the line
                crop = []
                xOffset = self._sameValueLen(line, prev[i])
                if xOffset != len(line):
                    end = self._sameValueLenReverse(line, prev[i])
                    crop = line[xOffset : len(line) - end]
                
                ## transform to 4bpp compression
                byte = 0
                shift = 0
                encCrop = []
                for pxl in crop:
                    ## compress 4 bit per pixel
                    byte += pxl << shift
                    shift += 4
                    if shift == 8:
                        encCrop.append(byte)
                        byte = 0
                        shift = 0
                if shift != 0:
                    encCrop.append(byte)

                lines.append({'offset': xOffset, 'widthPxl': len(crop), 'encodedData': encCrop})
            
            ## crop height
            class BreakIt(Exception): pass
            yOffset = 0
            try:
                for line in lines:
                    if line['widthPxl'] == 0:
                        yOffset += 1
                    else:
                        ## break only the for loop
                        raise BreakIt
            except BreakIt:
                pass
                
            height = len(lines) - yOffset
            i = yOffset + height
            try:
                while (i > 0) and (height > 0):
                    i -= 1
                    if lines[i]['widthPxl'] == 0:
                        height -= 1
                    else:
                        ## break only the while loop
                            raise BreakIt
            except BreakIt:
                pass

            ## restitue data
            frame = []
            lHeight = utils.uShortToList(height)
            lYOffset = utils.sShortToList(yOffset)
            frame += lHeight + lYOffset
            for line in lines[yOffset : yOffset + height]:
                widthPxl = line['widthPxl']
                lwidthPxl = utils.uShortToList(widthPxl)
                lXOffset = utils.sShortToList(line['offset'])
                frame += lwidthPxl + lXOffset + line['encodedData']

            rawAnim += frame
            prev = img

        ## start save animation command
        data = [id]
        data += utils.intToList(len(rawAnim))
        data += utils.intToList(imgSize)
        data += utils.uShortToList(width)
        if not useDeprecateCmd:
            data += [fmt]
            data += utils.intToList(compressedSize)
        cmds = [self.com.formatFrame(0x95, data)]

        ## pack data in commands
        nbDataMax = self.com.getDataSizeMax()
        i = 0
        while i < len(rawAnim):
            if nbDataMax > (len(rawAnim) - i):
                nbDataMax = (len(rawAnim) - i)

            cmds += [self.com.formatFrame(0x95, rawAnim[i:(nbDataMax + i)])]
            i += nbDataMax

        return cmds
    
    ## prepare command for animation saving
    def getCmdFolder(self, id, folder, fmt = imgFmt.MONO_4BPP, useDeprecateCmd = False):
        ## list file in folder
        imgs = []
        for f in sorted(os.listdir(folder)):
            path = os.path.join(folder, f)
            if os.path.isfile(path):
                img = cv2.imread(path)
                imgs.append(img)

        return self.getCmd(id, imgs, fmt, useDeprecateCmd)

    ## prepare command for animation saving
    def getCmdGif(self, id, gif, invertColor, fmt = imgFmt.MONO_4BPP):

        cap = cv2.VideoCapture(gif)

        imgs = []
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if invertColor:
                ## invert color
                frame = 255 - frame
            
            imgs.append(frame)
            

        cap.release()

        return self.getCmd(id, imgs, fmt)

    ## save an animation, takes all images of a folder
    def saveAnimation(self, id, folder = "anim/cube-302x256", fmt = imgFmt.MONO_4BPP, useDeprecateCmd = False):
        ## convert image
        cmds = self.getCmdFolder(id, folder, fmt, useDeprecateCmd)

        ## send commands
        for c in cmds:
            self.com.sendRawData(c)
            if not self.com.receiveAck():
                return False
        
        return True
    
    ## save an animation from a gif
    def saveAnimationGif(self, id, gif = "anim/monkey-228x228.gif", invertColor = True, fmt = imgFmt.MONO_4BPP):
        ## convert image
        cmds = self.getCmdGif(id, gif, invertColor, fmt)

        ## send commands
        for c in cmds:
            self.com.sendRawData(c)
            if not self.com.receiveAck():
                return False
        
        return True
