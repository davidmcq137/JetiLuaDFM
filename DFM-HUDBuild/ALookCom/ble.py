# BLE abstraction Layer

import asyncio

from bleak import BleakScanner

class Ble:
    # filter used by __runGetAdvData()
    def __advScanFilter(self, d, adv):
        if d.name == self.__advScanName:
            self.__advData = adv
            return True
        else:
            return False


    # Handle scan failure for debug
    async def __runError(self, timeout):
        dev_lst = await BleakScanner.discover(timeout)
        print(f"Failed to find device, scanned devices:")
        for d in dev_lst:
            print(f" - {d.address}, {d.name}")


    async def __runScan(self, timeout):
        return await BleakScanner.discover(timeout)


    async def __runScanByName(self, name, timeout):
        return await BleakScanner.find_device_by_filter(
            lambda d, ad: d.name == name,
            timeout
        )


    async def __runScanByAddr(self, addr_lst, timeout):
        return await BleakScanner.find_device_by_filter(
            lambda d, ad: d.address in addr_lst,
            timeout
        )


    async def __runScanBySrv(self, srvUuid, timeout):
        return await BleakScanner.find_device_by_filter(
            lambda d, ad: srvUuid in ad.service_uuids,
            timeout
        )


    # runner to get advertizing data
    async def __runGetAdvData(self, name):
        self.__advScanName = name
        d = await BleakScanner.find_device_by_filter(self.__advScanFilter)
        if d:
            return self.__advData
        else:
            return None


    # scan for device
    def scan(self, timeout=30.0):
        loop = asyncio.get_event_loop()
        return loop.run_until_complete(self.__runScan(timeout))


    def scanByName(self, name, timeout=30.0, debug=True):
        loop = asyncio.get_event_loop()
        dev = loop.run_until_complete(self.__runScanByName(name, timeout))

        if debug and not dev:
            loop.run_until_complete(self.__runError(timeout))

        return dev


    def scanByAddr(self, addr, timeout=30.0, debug=True):
        loop = asyncio.get_event_loop()
        dev = loop.run_until_complete(self.__runScanByAddr(addr, timeout))

        if debug and not dev:
            loop.run_until_complete(self.__runError(timeout))

        return dev


    def scanBySrv(self, srvUuid, timeout=30.0, debug=True):
        loop = asyncio.get_event_loop()
        dev = loop.run_until_complete(self.__runScanBySrv(srvUuid, timeout))

        if debug and not dev:
            loop.run_until_complete(self.__runError(timeout))

        return dev


    def getAdvData(self, name, debug=True):
        loop = asyncio.get_event_loop()
        adv_raw = loop.run_until_complete(self.__runGetAdvData(name))

        if adv_raw:
            adv = {}

            mfr = adv_raw.manufacturer_data
            key = list(mfr.keys())[0]
            value = list(mfr[key])
            key = key.to_bytes(length=2, byteorder='big', signed=False)
            key = [key[1], key[0]]
            adv['manufacturer_data'] = key + value

            adv['rssi'] = adv_raw.rssi
        else:
            loop.run_until_complete(self.__runError(10.0))
            adv = None

        return adv
