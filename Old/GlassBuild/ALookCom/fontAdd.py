import math

import numpy as np

from PIL import Image
from PIL import ImageFont
from PIL import ImageDraw

from . import utils


## char width cropping
def char_width_cropping(arr, newWidth):
    width = len(arr[0])
    height = len(arr)
    
    if width < newWidth:
        ## add missing column
        missing = newWidth - width
        cropArr = np.zeros((height, width + missing))
        for i, line in enumerate(arr):
            cropArr[i][ : width] = line
    elif width > newWidth:
        ## get the width of empty column on left and right side
        leftZero = width
        rightZero = width
        for line in arr:
            ## get number length of black pixel on the left
            for i, pxl in enumerate(line):
                if pxl != 0:
                    if i < leftZero:
                        leftZero = i
            ## get number length of black pixel on the right
            for i, pxl in enumerate(reversed(line)):
                if pxl != 0:
                    if i < rightZero:
                        rightZero = i

        ## compute the number of croped columns needed on left and right side
        left = width - newWidth
        right = 0

        ## adjust cropping with empty column
        if left > leftZero:
            right += left - leftZero
            left = leftZero
        if right > rightZero:
            right = rightZero
    
        ## crop the array
        cropArr = np.zeros((height, width - left - right))
        for i, line in enumerate(arr):
            cropArr[i] = line[left : width - right]
    else:
        cropArr = arr

    return cropArr


## char height croping
## descent is the distance between basline and bottom
def char_baseline_cropping(arr, newHeight, descent, newDescent):
    width = len(arr[0])

    ## adjust baseline
    if descent < newDescent:
        ## add blank lines
        nb = newDescent - descent
        for _ in range(nb):
            arr = [0 for _ in range(width)] + arr
    elif descent > newDescent:
        ## remove blank lines
        nb = descent - newDescent

        ## get the number of line with only black pixels
        for i, line in enumerate(arr):
            nbBlank = i
            if nbBlank == nb:
                break
            if 1 in line:
                break
        if nbBlank > 0:
            arr = arr[nbBlank:]

    ## adjust height
    height = len(arr)
    if height < newHeight:
        ## add blank lines on top
        nb = newHeight - height

        row = [0 for _ in range(width)]
        for _ in range(nb):
            arr = np.append(arr, [row], axis=0)
    elif height > newHeight:
        ## remove blank top lines to match height
        nb = height - newHeight

        ## get the number of line with only black pixels
        for i, line in enumerate(np.flipud(arr)):
            nbBlank = i
            if nbBlank == nb:
                break
            if 1 in line:
                break
        
        if nbBlank > 0:
            arr = arr[:-nbBlank]
    
    return arr


## convert a char into a matrix of pixels
## char width can be forced
## baseline position is in percent of height
def char_to_pixels(char, height, path, width=-1, baseline=0.25):
    used_height = height
    newDescent = math.floor(height * baseline)

    ## while char is too big try with lower height
    while True:
        font = ImageFont.truetype(path, used_height)
        ascent, descent = font.getmetrics()   ## distance between baseline and top/bottom
        _, _, w, h = font.getbbox(char)

        ## create matrix
        ## mode 'L': 8-bit pixels, black and white
        image = Image.new('L', (w, h), 1)
        draw = ImageDraw.Draw(image)
        draw.text((0, 0), char, font=font)
        arr = np.asarray(image)
        arr = np.where(arr, 0, 1)

        ## width cropping
        if width > 0:
            arr = char_width_cropping(arr, width)

        ## height cropping
        arr = char_baseline_cropping(arr, height, descent, newDescent)

        if len(arr) == height:
            if width == -1 or len(arr[0]) == width:
                break
        
        ## if char is too big try with a lower height
        used_height -= 1

    return arr


## return a 1 byte encoding
def write1byte(nb0, nb1):
    return (nb0 << 4) + nb1


## write mutltiple sequences of 2 bytes encoding
def write2bytes(pxl, nb):
    out = []

    ## pixel On/Off is encoded on the 8th bit
    if pxl == 1:
        pxlState = 0x80
    else:
        pxlState = 0

    ## bits 7 to 1 is the number of pixel multiply by 8
    nbLoop = nb // (0x7F * 8)
    rem = nb % (0x7F * 8)

    ## writing sequences of 1016 pixels (0x7F * 8)
    for _ in range(nbLoop):
        ## on 2 bytes encoding, the first byte is always 0
        out.append(0x00)
        out.append(pxlState | 0x7F)

    nbPixels = rem // 8
    rem = rem % 8
    if nbPixels != 0:
        ## on 2 bytes encoding, the first byte is always 0
        out.append(0x00)
        out.append(pxlState | nbPixels)

    return (out, rem)

## write multiple pixels sequences with 1 and 2 bytes encoding
def writeRle(nb0, nb1):
    out = []

    ## In Fw, Off pixels are displayed first
    ## so write them first
    while nb0 > 0:
        if nb0 <= 15:
            ## 1 byte encoding
            tmpOn = min(nb1, 15)
            out.append(write1byte(nb0, tmpOn))
            nb0 = 0
            nb1 -= tmpOn
        elif nb0 <= 30:
            ## even here 1 byte is still more efficient
            out.append(write1byte(15, 0))
            nb0 -= 15
        else:
            ## 2 bytes encoding
            lst, rem = write2bytes(0, nb0)
            out += lst
            nb0 = rem
    
    while nb1 > 0:
        if nb1 <= 15:
            ## 1 byte encoding
            out.append(write1byte(0, nb1))
            nb1 = 0
        elif nb1 <= 30:
            ## even here 1 byte is still more efficient
            out.append(write1byte(0, 15))
            nb1 -= 15
        else:
            ## 2 bytes encoding
            lst, rem = write2bytes(1, nb1)
            out += lst
            nb1 = rem

    return out


## encod a matrix of pixel into ActiveLook format
def pixel_to_rle(arr):
    h, w = arr.shape
    arr = arr.reshape(-1) ## reshape matrix on 1 dimension

    ## cpt01 [number of on pixels, number of off pixels]
    prev = int(arr[0])
    cnt01 = [0, 0]
    out = []
    for pxl in arr:
        pxl = int(pxl)  ## pixel are float
        if pxl != prev:
            ## while pixels are repeated, just increment cpt01[pixel]
            ## In Fw, Off pixels are displayed first
            ## so write memory when switching On to Off
            if pxl == 0:
                out += writeRle(cnt01[0], cnt01[1])
                cnt01 = [0, 0]
        cnt01[pxl] += 1
        prev = pxl

    ## encoding last pixels
    if cnt01[0] > 0 or cnt01[1] > 0:
        out += writeRle(cnt01[0], cnt01[1])

    ## adding char header
    out = [0, w] + out
    out[0] = len(out)
    assert(out[0] <= 255) # a char must be stored on 255 bytes maximum
    
    return out


## convert ActiveLook encoding to pixel matrix
def rle_to_matrix(arr, height):
    w = arr[1]

    pixels = []
    go = False
    for elem in arr[2:]:
        if elem == 0:
            ## 2 bytes encoding
            ## 1st byte is always 0
            go = True
        elif go == True:
            go = False
            pxl = elem >> 7          ## 8th bit is the pixel value
            nb = (elem & 0x7F) * 8   ## 7 to 1 bits are the number of pixel multiply by 8
            for _ in range(nb):
                pixels.append(pxl)
        else :
            nb0 = elem >> 4
            nb1 = elem & 0x0F
            for _ in range(nb0):
                pixels.append(0)
            for _ in range(nb1):
                pixels.append(1)

    ## create matrix
    mat = []
    for i in range(height):
        mat.append(pixels[i * w : (i + 1) * w])

    return mat


## convert a font to the ActiveLook format
## widthDict, can be use to specify the width of each char with a dictionary
def getFontData(height, path, firstChar, lastChar, fmt=0x02, widthDict={}, baseline=0.25):
    oFirst = ord(firstChar)
    oLast = ord(lastChar)
    
    listChar = []
    for c in range(oFirst, oLast + 1):
        listChar.append(chr(c))
    
    header = [fmt, height] + utils.uShortToList(oFirst) + utils.uShortToList(oLast)
    offsetTable = []
    charTable = []
    offset = 0
    for char in listChar:
        ## char -> pixel matrix
        if char in widthDict:
            width = widthDict[char]
        else:
            width = -1
        arrPixel = char_to_pixels(char, height, path, width, baseline)
        
        ## pixel matrix -> rle encoding
        arrRle = pixel_to_rle(arrPixel)

        charTable += arrRle
        offsetTable += utils.sShortToList(offset)
        
        ## calculating  next offset
        offset += len(arrRle)

    if fmt == 0x01:
        ## format 0x01, add 0 in offset table to reach a size of 250 bytes
        nbChar = len(listChar)
        offsetTable += [0x00 for _ in range(2 * (125 - nbChar))]
    
    data = header + offsetTable + charTable

    return data
