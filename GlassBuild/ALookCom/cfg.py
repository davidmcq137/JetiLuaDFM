from time import time
import re
import random

from .commandPub import CommandPub
from .img import Img


class Cfg:
    def __init__(self, com):
        self.com = com
        self.cmd = CommandPub(com)
        self.img = Img(com)


    def getSysCfgName(self):
        ret, cfgs = self.cmd.cfgList()
        assert ret

        for cfg in cfgs:
            if cfg['isSystem']:
                return cfg['name']

        return ""


    def load(self, fileName = 'config/config.txt'):
        f = open(fileName, 'r')
        lines = f.readlines()
        f.close()

        ret, x, y, luma, als, gesture = self.cmd.settings()

        ## disable sensor so firmware is faster
        if als or gesture:
            self.cmd.enableSensor(False)

        lineCnt = 0
        start = time()
        for l in lines:
            lineCnt += 1
            print(f"loadConfig line {lineCnt} / {len(lines)}")

            ## strip space
            l = l.strip(" ")

            ## remove comments
            if not re.match(r"^\s*#.*$", l):

                ## remove empty lines
                if l != "\n":
                    ## remove '0x' at the start of the string
                    prefix = '0x'
                    if l.startswith(prefix):
                        l = l[len(prefix):]

                    ## line format ex: FF41000B00000708003CAA
                    ## convert hex string to int
                    bin = bytes.fromhex(l)
                    self.com.sendRawData(bin)
                    
                    ## cmd giving answer
                    cmdId = bin[1]
                    if cmdId == 0xA2:
                        if not self.com.receiveFrame(cmdId):
                            return False
                    
                    ## Cmd ack
                    if not self.com.receiveAck():
                        return False

        ## restore sensor config
        if als:
            self.cmd.enableAls(True)
        if gesture:
            self.cmd.enableGesture(True)
            
        end = time()
        dur = round(end - start, 3)
        print(f"load: {dur}s")
        return True


    def update(self, filename, cfg, password):
        """update system config, manually do the write cfg without changing version"""
        ret = True

        ## get system config version
        cmdRet, version, nbImg, nbLayout, nbFont, nbPage, nbGauge = self.cmd.cfgRead(cfg)
        ret &= cmdRet

        ## write config
        ret &= self.cmd.cfgWrite(cfg, version, password)

        ## load
        ret &= self.load(filename)
        
        return ret

    
    def loadRandom(self, name = "test", imgs = [[50, 50]], nbLayout = 0, fonts = [{'height': 12, 'start': ' ', 'end': '~'}], nbPage = 0, nbGauge = 0, version = 0, password = 0):
        ## on memory full, answer make time to arrive
        bak = self.com.getTimeout()
        self.com.setTimeout(self.cmd.longTimeout)

        # print(f"config: {name}")
        ret = self.cmd.cfgWrite(name, version, password)
        if not ret:
            self.com.setTimeout(bak)
            return False

        ## save fonts
        for i, f in enumerate(fonts):
            ret = self.cmd.fontSave(i + 4, f['height'], 'font/Roboto/Roboto-Black.ttf', f['start'], f['end'])
            if not ret:
                self.com.setTimeout(bak)
                return False

        ## generate imgs
        for i, img in enumerate(imgs):
            # print(f"img: {i}/{len(imgs)}")
            height = img[0]
            width = img[1]
            ret = self.img.saveImageRandom(i, width, height)
            if not ret:
                self.com.setTimeout(bak)
                return False

        ## generate layouts
        cmd = self.cmd.layoutCmdRect(random.randint(0, 50), random.randint(0, 50), random.randint(51, 200), random.randint(51, 200))
        for i in range(nbLayout):
            # print(f"layout: {i}/{nbLayout}")
            ret = self.cmd.layoutSave(i, 
                                x0 = random.randint(0, 200), 
                                y0 = random.randint(0, 200), 
                                width = random.randint(0, 200), 
                                height = random.randint(0, 200), 
                                txtX0 = 125, 
                                txtY0 = 25, 
                                font = 1, 
                                txtRot = 4, 
                                foreColor = 15, 
                                backColor = 0, 
                                txtOpacity = 15, 
                                cmd = cmd)
            if not ret:
                self.com.setTimeout(bak)
                return False

        ## generate pages
        for i in range(nbPage):
            # print(f"page: {i}/{nbPage}")
            layoutId = 0
            x = random.randint(0, 50)
            y = random.randint(0, 50)
            ret = self.cmd.pageSave(i, [[layoutId, x, y]])
            if not ret:
                self.com.setTimeout(bak)
                return False

        ## generate gauges
        for i in range(nbGauge):
            # print(f"gauge: {i}/{nbGauge}")
            x = random.randint(0, 50)
            y = random.randint(0, 50)
            rInt = random.randint(10, 50)
            rExt = random.randint(rInt + 10, rInt + 50)
            startCoord = random.randint(1, 16)
            endCoord = random.randint(1, 16)
            clockWise = bool(random.getrandbits(1))
            ret = self.cmd.gaugeSave(i, x, y, rExt, rInt, startCoord, endCoord, clockWise)
            if not ret:
                self.com.setTimeout(bak)
                return False
        
        self.com.setTimeout(bak)
        return True


    def loadFullRandom(self, name = "test", version = 0, password = 0):
        nbImg = random.randint(0, 10)
        imgs = [[50, 50] for _ in range(nbImg)]
        nbLayout = 50
        nbFont = random.randint(0, 4)
        fonts = [{'height': 12, 'start': ' ', 'end': '~'} for _ in range(nbFont)]
        nbPage = random.randint(0, 10)
        nbGauge = random.randint(0, 10)

        return self.loadRandom(name, imgs, nbLayout, fonts, nbPage, nbGauge, version, password)
