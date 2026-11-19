
import serial

from .comMixed import ComMixed
from .comBin import ComBin

def getComClass():
    dev = None
    ports = serial.tools.list_ports.comports()
    for p in ports:
        if (p.vid == 0xFFFE) and (p.pid == 0x1112):
            dev = p.device
            break
    
    if not dev:
        # fuck it
        return ComBin

    frame = bytes([0xFF, 0x06, 0x00, 0x05, 0xAA])
    ser = serial.Serial(dev, timeout=1.75)
    ser.write(frame)
    b = ser.read(1)

    # for Mixed com, answer will have ASCII format : '0x0123456...'
    if b == b'0':
        ret = ComMixed
    else:
        ret = ComBin
    ser.close()

    return ret
