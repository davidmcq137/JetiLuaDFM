from serial.tools import list_ports

def getUsbInfo():
    """only serial_number usefull for the moment !"""
    comp = list_ports.comports()
    for info in comp:
        ## windows
        if info.manufacturer == 'Microsoft':
            return {'name': info.name, 'manufacturer': info.manufacturer, 'serial': info.serial_number}
        ## linux (quick and dirty)
        if info.interface == "CDC":
            return({'name': info.name, 'manufacturer': info.manufacturer, 'serial': info.serial_number})
