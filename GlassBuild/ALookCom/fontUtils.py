from . import fontData


FontFirstChar = ' '
FontLastChar = '~'

def getFontWidth(font):
    if font > 0:
        ## font 0 and 1 are the same
        font -= 1

    offset = fontData.OFFSET[font]
    data = fontData.DATA[font]

    c = FontFirstChar
    i = 0

    width = {}
    while c <= FontLastChar:
        idx = offset[i]
        width[c] = data[idx + 1]

        i += 1
        c = chr(ord(c) + 1)
    
    return width


def getFontNbPxl(font):
    if font > 0:
        ## font 0 and 1 are the same
        font -= 1

    offset = fontData.OFFSET[font]
    data = fontData.DATA[font]

    c = FontFirstChar
    i = 0

    pxl = {}
    while c <= FontLastChar:
        idx = offset[i]
        len = data[idx]
        width = data[idx + 1]

        pxl[c] = 0
        j = idx + 2
        while j < idx + len:
            ## See if this is a byte that encodes some on and off pixels.
            if data[j]:
                off = (data[j] >> 4) & 15
                on = data[j] & 15
                j += 1
            ## Otherwise, see if this is a repeated on pixel byte.
            elif data[j + 1] & 0x80:
                off = 0
                on = (data[j + 1] & 0x7f) * 8
                j += 2
            ## Otherwise, this is a repeated off pixel byte.
            else:
                off = data[j + 1] * 8
                on = 0
                j += 2
            
            pxl[c] += on

        i += 1
        c = chr(ord(c) + 1)
    
    return pxl


##### main #####
if __name__ == '__main__':
    for i in range(1, 4):
        with open(f"font_{i}.txt", 'w') as f:
            f.write(f"FontWidth_{i} = {getFontWidth(i)}")
            f.write("\n")
            f.write(f"FontPxl_{i} = {getFontNbPxl(i)}")