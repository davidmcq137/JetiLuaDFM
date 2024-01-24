# BLE abstraction Layer

import asyncio
import sys

from bleak import uuids
from bleak import BleakClient
from bleak import BleakScanner


class BleClient:
    __DEVICE_NAME_UUID      = "00002a00-0000-1000-8000-00805f9b34fb"
    __SPS_WRITE_UUID        = "0783b03e-8535-b5a0-7140-a304d2495cba"
    __SPS_READ_UUID         = "0783b03e-8535-b5a0-7140-a304d2495cb8"
    __SPS_CTRL_UUID         = "0783b03e-8535-b5a0-7140-a304d2495cb9"
    __SPS_GESTURE_UUID      = "0783b03e-8535-b5a0-7140-a304d2495cbb"
    __SPS_TOUCH_UUID        = "0783b03e-8535-b5a0-7140-a304d2495cbc"

    __RETRY                 = 20

    __CTRL_FLOW_ON = 1
    __CTRL_FLOW_OFF = 2
    __CTRL_ERROR = 3
    __CTRL_ERR_OVERFLOW = 4
    __CTRL_ERR_MISSING_CFG_WRITE = 6

    # constructor
    def __init__(self):
        self.__rxQueue = asyncio.Queue()

        self.__ctrl = self.__CTRL_FLOW_ON
        self.__allowedToSend = True
        self.__ignoreCtrl = False
        self.__swipe = False

    # destructor
    def __del__(self):
        self.disconnect()
        self.__client = None

    # read notify callback
    def __spsReadNotif(self, sender, data):
        for d in data:
            self.__rxQueue.put_nowait(d)

    # flow control notify callback
    def __spsFlowCtrlNotif(self, sender, data):
        msg = {self.__CTRL_FLOW_ON: 'Flow On', self.__CTRL_FLOW_OFF: "Flow Off", self.__CTRL_ERROR: 'Ctrl Error', self.__CTRL_ERR_OVERFLOW: 'Ctrl overflow', self.__CTRL_ERR_MISSING_CFG_WRITE: 'Ctrl missing cfg write'}
        ctrl = data[0]

        if not self.__ignoreCtrl:
            self.__ctrl = ctrl

            if self.__ctrl == self.__CTRL_FLOW_ON:
                self.__allowedToSend = True
            if self.__ctrl == self.__CTRL_FLOW_OFF:
                self.__allowedToSend = False

            assert (self.__ctrl != self.__CTRL_ERR_OVERFLOW), "BLE overflow !!!"

        if ctrl in msg:
            print(f'Ble {msg[ctrl]}')
        else:
            print(f'Ble Ctrl: unknown code {ctrl}')

    # gesture event notify callback
    def __spsGestureNotif(self, sender, data):
        print("BLE: SWIPE")
        self.__swipe = True

    # touch event notify callback
    def __spsTouchNotif(self, sender, data):
        print("BLE: Touch")

    # disconnect callback
    def __disconnectCb(self, client):
        print("BLE: disconnect")
        self.__client = None

    # connection runner
    async def __runConnect(self, dev):
        self.__client = BleakClient(dev, self.__disconnectCb)

        retry = self.__RETRY
        connected = False
        while (retry > 0) and not connected:
            try:
                if sys.platform == 'win32':
                    connected = await self.__client.connect(timeout=30.0, use_cached=False)
                elif sys.platform == 'linux':
                    connected = await self.__client.connect(timeout=30.0)
                else:
                    connected = await self.__client.connect()
            except Exception as e:
                dev = await BleakScanner.find_device_by_address(dev.address, timeout=30.0)
                lastErr = e
                retry -= 1

        if not connected:
            raise Exception(f"failed to connect {dev}\n{lastErr}")

        retry = self.__RETRY
        done = False
        while (retry > 0) and not done:
            try:
                # read notification
                await self.__client.start_notify(self.__SPS_READ_UUID, self.__spsReadNotif)

                # flow control notification
                await self.__client.start_notify(self.__SPS_CTRL_UUID, self.__spsFlowCtrlNotif)

                # gesture event notification
                await self.__client.start_notify(self.__SPS_GESTURE_UUID, self.__spsGestureNotif)

                # touch event notification
                await self.__client.start_notify(self.__SPS_TOUCH_UUID, self.__spsTouchNotif)

                done = True
            except Exception as e:
                lastErr = e
                retry -= 1

        if not done:
            raise Exception(f"failed to enable notifications {dev}\n{lastErr}")

        # BlueZ doesn't have a proper way to get the MTU, so we have this hack.
        # If this doesn't work for you, you can set the client._mtu_size attribute
        # to override the value instead.
        if self.__client._backend.__class__.__name__ == "BleakClientBlueZDBus":
            await self.__client._backend._acquire_mtu()

        print("Connected " + dev.name)

    # diconnection runner
    async def __runDiconnect(self):
        if self.__client:
            await self.__client.disconnect()
        print("Disconnected")

    # write gatt
    async def __runWrite(self, data):
        while not self.__allowedToSend:
            assert (self.__ctrl != self.__CTRL_ERR_OVERFLOW), "BLE overflow !!!"
            assert self.__client.is_connected
            await asyncio.sleep(0.1)

        retry = self.__RETRY
        done = False
        while (retry > 0) and not done:
            try:
                await self.__client.write_gatt_char(self.__SPS_WRITE_UUID, data, response=True)
                done = True
            except Exception as e:
                lastErr = e
                retry -= 1

        if not done:
            raise Exception(f"fail to write on SPS service, data: {data}\n{lastErr}")

    # read runner
    async def __runRead(self, size, timeout):
        out = []

        try:
            while size > 0:
                b = await asyncio.wait_for(self.__rxQueue.get(), timeout)
                out.append(b)
                size -= 1
        except asyncio.TimeoutError:
            return out

        return out

    # get device name runner
    async def __runGetDeviceName(self):
        retry = self.__RETRY
        done = False
        while (retry > 0) and not done:
            try:
                rawName = await self.__client.read_gatt_char(self.__DEVICE_NAME_UUID)
                done = True
            except Exception as e:
                lastErr = e
                retry -= 1

        if not done:
            assert f"fail to get device name\n{lastErr}"

        return rawName.decode("ascii")

    # get all info that can given when connecting in BLE
    async def __runGetInfo(self):
        linfo = {}

        for srv in self.__client.services:
            for charac in srv.characteristics:
                if "read" in charac.properties:
                    name = uuids.uuidstr_to_str(charac.uuid)
                    if name != "Unknown":
                        retry = self.__RETRY
                        done = False
                        while (retry > 0) and not done:
                            try:
                                res = await self.__client.read_gatt_char(charac)
                                done = True
                            except:
                                retry -= 1
                        isString = 'Name' in name or 'String' in name
                        if isString:
                            lres = ""
                        else:
                            lres = []
                        for val in res:
                            if isString:
                                lres += chr(int(val))
                            else:
                                lres.append(int(val))
                        print(f"'{name}': '{lres}'")
                        linfo[name] = lres

        # BlueZ (linux) hides characteristics that is uses for other things for some reason.
        # The device name characteristic is on of those. We have a workaround that allows you to read the characteristic directly by UUID.
        if "Device Name" not in linfo:
            rawName = await self.__client.read_gatt_char(self.__DEVICE_NAME_UUID)
            linfo["Device Name"] = rawName.decode("ascii")

        return linfo

    # connect to a device
    def connect(self, dev):
        print("Connecting " + dev.name + "...")

        loop = asyncio.get_event_loop()
        loop.run_until_complete(self.__runConnect(dev))

    # diconnect from a device
    def disconnect(self):
        print("Disconnecting...")
        if self.__client:
            loop = asyncio.get_event_loop()
            loop.run_until_complete(self.__runDiconnect())

    # reset SPS rx buffer
    def resetRxbuffer(self):
        self.__rxBuff = bytearray()

    # SPS write
    def write(self, data):
        loop = asyncio.get_event_loop()
        loop.run_until_complete(self.__runWrite(data))

    # SPS read
    def read(self, size=1, timeout=1.75):
        loop = asyncio.get_event_loop()
        return loop.run_until_complete(self.__runRead(size, timeout))

    # get Device name
    def getDeviceName(self):
        loop = asyncio.get_event_loop()
        return loop.run_until_complete(self.__runGetDeviceName())

    # get connection MTU
    def getMtu(self):
        # remove size of Op-Code (1 Byte) and Attribute Handle (2 Bytes)
        return self.__client.mtu_size - 3

    # get all info that can given when connecting in BLE
    def getValueInfo(self):
        loop = asyncio.get_event_loop()
        return loop.run_until_complete(self.__runGetInfo())

    # enable/disable assert on overflow
    def setIgnoreCtrl(self, val):
        self.__ignoreCtrl = val
        self.__allowedToSend = True

    # check if there was a swipe since the last call
    def isSwipe(self):
        s = self.__swipe
        self.__swipe = False
        return s
