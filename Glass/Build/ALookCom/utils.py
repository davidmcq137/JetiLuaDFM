import os
import struct
import sys
import numpy

import cv2
from PIL import Image
from PIL import ImageDraw

from . import CohenSutherlandLc
from . import imgFmt
from . import imgMdp08
from . import imgMdp05
from . import display
from . import fontAdd
from . import fontData
from . import fontSize


## convert a unsigned short in a int list
## return : list
def uShortToList(value):
    bt = value.to_bytes(length=2, byteorder='big', signed=False)
    return [bt[0], bt[1]]

## convert a signed short in a int list
## return : list
def sShortToList(value):
    bt = value.to_bytes(length=2, byteorder='big', signed=True)
    return [bt[0], bt[1]]

## convert a int in a int list
## return : list
def intToList(value):
    bt = value.to_bytes(length=4, byteorder='big')
    return [bt[0], bt[1], bt[2], bt[3]]

## convert list to signed char
## return : list
def listToSChar(lst):
    bin = bytearray(lst)
    return struct.unpack('>b', bin)[0] ## '>b' = signed char

## convert list to unsigned short
## return : list
def listToUShort(lst):
    bin = bytearray(lst)
    return struct.unpack('>H', bin)[0] ## '>H' = big indian unsigned short

## convert list to short
## return : list
def listToShort(lst):
    bin = bytearray(lst)
    return struct.unpack('>h', bin)[0] ## '>H' = big indian short

## convert list to unsigned int
## return : unsigned int
def listToUInt(lst):
    bin = bytearray(lst)
    return struct.unpack('>I', bin)[0] ## '>I' = big indian unsigned int

## convert a string in a int array
## return : array of int
def strToList(str, maxLen = -1):
    lst = []
    for char in str:
        lst.append(ord(char))
    if (maxLen == -1) or (len(str) < maxLen):
        lst.append(0) ## end of string

    return lst

## convert a list of int into a string 
def listToStr(lst, len = -1):
    str = ""
    
    for char in lst:
        if char != 0:
            str += chr(char)
        else:
            break

        if len != -1:
            len -= 1
            if len == 0:
                break
    return str

## clamp to value to minn > n > maxn
def clamp(n, minn, maxn):
        return max(min(maxn, n), minn)

## convert serial number to ble public address
def getBlePublicAddress(versYear, versWeek, versNumber):
    bt = versNumber.to_bytes(length=3, byteorder=sys.byteorder, signed=False)
    return f"80:{versYear:02X}:{versWeek:02X}:{bt[2]:02X}:{bt[1]:02X}:{bt[0]:02X}"

## convert serial number to ble private address
def getBlePrivateAddress(versYear, versWeek, versNumber):
    bt = versNumber.to_bytes(length=3, byteorder=sys.byteorder, signed=False)
    return f"C0:{versYear:02X}:{versWeek:02X}:{bt[2]:02X}:{bt[1]:02X}:{bt[0]:02X}"

## get number of pixel of a point
def getPointNbPixel(x, y, clippingX0, clippingY0, clippingX1, clippingY1):
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    if (clippingX0 <= x <= clippingX1) and (clippingY0 <= y <= clippingY1):
        return 1
    else:
        return 0

## get number of pixel for a rectangle
def getRectNbPixel(x0, y0, x1, y1, clippingX0, clippingY0, clippingX1, clippingY1):
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    pxl = 0
    nbLine = 0

    if (x0 > clippingX1 and x1 > clippingX1) or (x1 < clippingX0 and x0 < clippingX0) or (y0 > clippingY1 and y1 > clippingY1) or (y0 < clippingY0 and y1 < clippingY0):
        return 0

    myX0 = clamp(x0, clippingX0, clippingX1)
    myY0 = clamp(y0, clippingY0, clippingY1)
    myX1 = clamp(x1, clippingX0, clippingX1)
    myY1 = clamp(y1, clippingY0, clippingY1)

    myWidth = abs(myX1 - myX0)  + 1
    myHeight = abs(myY1 - myY0) + 1

    if clippingY0 <= y0 <= clippingY1:
        nbLine += 1
        pxl += myWidth
    if clippingY0 <= y1 <= clippingY1 and y0 != y1:
        nbLine += 1
        pxl += myWidth
    if clippingX0 <= x0 <= clippingX1:
        nbLine += 1
        pxl += myHeight
    if clippingX0 <= x1 <= clippingX1 and x0 != x1:
        nbLine += 1
        pxl += myHeight

    ## corner have common pixel
    if nbLine == 2:
        pxl -= 1
    elif nbLine == 3:
        pxl -= 2
    elif nbLine == 4:
        pxl -= 4

    return pxl

## get number of pixel for a full rectangle
def getRectFullNbPixel(x0, y0, x1, y1, clippingX0, clippingY0, clippingX1, clippingY1):
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    pxl = 0

    if (x0 > clippingX1 and x1 > clippingX1) or (x1 < clippingX0 and x0 < clippingX0) or (y0 > clippingY1 and y1 > clippingY1) or (y0 < clippingY0 and y1 < clippingY0):
        return 0

    myX0 = clamp(x0, clippingX0, clippingX1)
    myY0 = clamp(y0, clippingY0, clippingY1)
    myX1 = clamp(x1, clippingX0, clippingX1)
    myY1 = clamp(y1, clippingY0, clippingY1)

    myWidth = abs(myX1 - myX0)  + 1
    myHeight = abs(myY1 - myY0) + 1

    pxl = myWidth * myHeight

    return pxl

## get number of pixel for the diameter of a circle
def getCircleNbPixel(x, y, r, clippingX0, clippingY0, clippingX1, clippingY1):
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    ## Midpoint circle algorithm / Bresenham
    f = 1 - r
    ddf_x = 1
    ddf_y = -2 * r
    a = 0
    b = r

    circle = []

    circle.append([x, y + r])
    circle.append([x, y - r])
    circle.append([x + r, y])
    circle.append([x - r, y])
 
    while a < b:
        if f >= 0:
            b -= 1
            ddf_y += 2
            f += ddf_y
        a += 1
        ddf_x += 2
        f += ddf_x
        circle.append([x + a, y + b])
        circle.append([x - a, y + b])
        circle.append([x + a, y - b])
        circle.append([x - a, y - b])
        circle.append([x + b, y + a])
        circle.append([x - b, y + a])
        circle.append([x + b, y - a])
        circle.append([x - b, y - a])

    ## remove duplicated pixel
    circle = numpy.unique(circle, axis=0)

    ## get number of pixel in clipping region
    pxl = 0
    for x, y in circle:
        pxl += getPointNbPixel(x, y, clippingX0, clippingY0, clippingX1, clippingY1)
    return pxl

## get number of pixel for a full circle
def getCircleFullNbPixel(x, y, r, clippingX0, clippingY0, clippingX1, clippingY1):
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    ## Midpoint circle algorithm / Bresenham
    f = 1 - r
    ddf_x = 1
    ddf_y = -2 * r
    a = 0
    b = r

    circle = []

    for my_y in range(y - r, y + r + 1):
        circle.append([x, my_y])
    for my_x in range(x - r, x + r + 1):
        circle.append([my_x, y])
    

    while a < b:
        if f >= 0:
            b -= 1
            ddf_y += 2
            f += ddf_y
        
        a += 1
        ddf_x += 2
        f += ddf_x

        for my_x in range(x - a, x + a + 1):
            circle.append([my_x, y + b])
            circle.append([my_x, y - b])

        for my_y in range(y - a, y + a + 1):
            for my_x in range(x - b, x + b + 1):
                circle.append([my_x, my_y])

    ## remove duplicated pixel
    circle = numpy.unique(circle, axis=0)

    ## get number of pixel in clipping region
    pxl = 0
    for x, y in circle:
        pxl += getPointNbPixel(x, y, clippingX0, clippingY0, clippingX1, clippingY1)
    return pxl

## get number of pixel for a line
def getLineNbPixel(x0, y0, x1, y1, clippingX0, clippingY0, clippingX1, clippingY1):
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    x0, y0, x1, y1 = CohenSutherlandLc.lineClipping(x0, y0, x1, y1, clippingX0, clippingY0, clippingX1, clippingY1)

    if x0 is None:
        return 0
    
    width = abs(x1 - x0) + 1
    height = abs(y1 - y0) + 1

    if width > height:
        pxl = width
    else:
        pxl = height

    return pxl


def getInter(a, b, c, d):
    """ get the intersection between segments [ab] and [cd]"""
    ## segment is in vertical
    if (a[0] - b[0]) == 0 and (c[0] - d[0]) != 0:
        m = (c[1] - d[1]) / (c[0] - d[0])
        o = c[1] - m*c[0]
        xi = a[0]
        yi = a[0]*m + o
    ## other segment is in vertical
    elif (c[0] - d[0]) == 0 and (a[0] - b[0]) != 0 :
        m = (a[1] - b[1]) / (a[0] - b[0])
        b = a[1] - m*a[0]
        xi = c[0]
        yi = c[0]*m + b
    elif (c[0] - d[0]) == 0 and (a[0] - b[0]) == 0 :
        return a[0], a[1]
    else:
        ## get the equations of each segments then get intersection point
        m1 = (c[1] - d[1]) / (c[0] - d[0])
        o1 = c[1] - m1*c[0]
        m2 = (a[1] - b[1]) / (a[0] - b[0])
        o2 = a[1] - m2*a[0]
        xi = (o1-o2) / (m2-m1)
        yi = m1 * xi + o1
    return xi, yi

def intersect(s0,s1):
    """ tell if s0 and s1 intersect or not"""
    ### solutions using dots products
    dx0 = s0[1][0]-s0[0][0]
    dx1 = s1[1][0]-s1[0][0]
    dy0 = s0[1][1]-s0[0][1]
    dy1 = s1[1][1]-s1[0][1]
    p0 = dy1*(s1[1][0]-s0[0][0]) - dx1*(s1[1][1]-s0[0][1])
    p1 = dy1*(s1[1][0]-s0[1][0]) - dx1*(s1[1][1]-s0[1][1])
    p2 = dy0*(s0[1][0]-s1[0][0]) - dx0*(s0[1][1]-s1[0][1])
    p3 = dy0*(s0[1][0]-s1[1][0]) - dx0*(s0[1][1]-s1[1][1])
    return (p0*p1<=0) & (p2*p3<=0)


def getPolyNbPixels(lvalues, clippingX0, clippingY0, clippingX1, clippingY1):
    """ get the number of pixels that compose the polyline
        case where 1 segment is included in another is not treated (segments parallels with pixel in common)"""
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    pxl = 0
    ## from points get segments
    lseg = [[lvalues[i], lvalues[i+1]] for i in range(len(lvalues)-1)]

    ## get real segments visible in the screen
    lRealSeg = []
    for [[x0, y0], [x1, y1]] in lseg:         
        x1, y1, x2, y2 = CohenSutherlandLc.lineClipping(x0, y0, x1, y1, clippingX0, clippingY0, clippingX1, clippingY1)
        if x1 != None:
            lRealSeg.append([[x1, y1], [x2, y2]])

    passed = []
    for [[x0, y0], [x1, y1]] in lRealSeg:
        ### get pixels of segments
        pxl += getLineNbPixel(x0, y0, x1, y1, clippingX0, clippingY0, clippingX1, clippingY1)
        lpoints = []
        for [A, B] in passed:
            if intersect([A, B], [[x0, y0], [x1, y1]]):
                xi, yi = getInter(A, B, [x0, y0], [x1, y1])
                ## if intersections check if pixel already removed
                if not [int(xi), int(yi)] in lpoints:
                    lpoints.append([int(xi), int(yi)])
                    pxl -= 1
        passed.append([[x0, y0], [x1, y1]])
    return pxl

def getThickPolyNbPixels(lvalues, thickness, layoutX0, layoutY0, 
                         clippingX0, clippingY0, clippingX1, clippingY1, image=None):
    """ get the number of pixels that compose the polyline
        As it is more difficult to count pixel number with thick lines, we draw the line in an array and 
        count the number of pixel in the clipping area"""
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)

    if image==None:
        image = Image.new('L', (display.WIDTH, display.HEIGHT), 0)  
    draw = ImageDraw.Draw(image)

    ## from points get segments
    lseg = [[lvalues[i], lvalues[i+1]] for i in range(len(lvalues)-1)]

    ## Draw lines
    for [[x0, y0], [x1, y1]] in lseg:         
        draw.line([(layoutX0+x0, layoutY0+y0), (layoutX0+x1, layoutY0+y1)], fill=1, width=thickness)

    # Clip image
    clipped = image.crop([clippingX0, clippingY0, clippingX1+1, clippingY1+1])

    ## Count pixel in the clipping region 
    count = numpy.count_nonzero(numpy.asarray(clipped))

    # Return new image storing all display
    new_image = Image.new('L', (display.WIDTH, display.HEIGHT), 0)  
    new_image.paste(clipped, [clippingX0, clippingY0])

    return count, new_image
    
def getNbPixelImg(path, x, y, clippingX0, clippingY0, clippingX1, clippingY1, fmt):
    """get pixel count for grayscale image in 4bpp or 1bpp"""
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)

    if (fmt == imgFmt.MONOALPHA_8BPP):
        ## alpha channel is kept to use transparency
        img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    else:
        ## alpha channel is cropped
        img = cv2.imread(path) 
    if fmt == imgFmt.MONO_4BPP:
        img = imgMdp05.convertDefault(img)
    elif fmt == imgFmt.MONO_4BPP_HEATSHRINK:
        img = imgMdp05.convertDefault(img)
    elif fmt == imgFmt.MONO_4BPP_HEATSHRINK_SAVE_COMP:
        img = imgMdp05.convertDefault(img)
    elif fmt == imgFmt.MONO_1BPP:
        img = imgMdp05.convert1Bpp(img)
    elif fmt == imgFmt.STREAM_1BPP:
        img = imgMdp05.convert1Bpp(img)
    elif fmt == imgFmt.STREAM_4BPP_HEATSHRINK:
        img = imgMdp05.convertDefault(img)
    elif fmt == imgFmt.RYYG:
        img = imgMdp08.convertViaDistanceToRyyg(img)
    elif fmt == imgFmt.RRYG:
        img = imgMdp08.convertViaDistanceToRryg(img)
    elif fmt == imgFmt.MONOALPHA_8BPP:
        img = imgMdp05.convert8Bpp(img)
    else:
        assert False, "Unknown format"
    
    height = img.shape[0]
    width = img.shape[1]
    
    x2 = x + width
    y2 = y + height 

    if x > clippingX1 or x2 < clippingX0 or y > clippingY1 or y2 < clippingY0:
        return 0, width, height

    myX0 = clamp(x, clippingX0, clippingX1)
    myY0 = clamp(y, clippingY0, clippingY1)
    myX1 = clamp(x2, clippingX0, clippingX1)
    myY1 = clamp(y2, clippingY0, clippingY1)


    cropImg = img[myY0-y: myY1-y+1, myX0-x: myX1-x+1]
    count = 0
    for lines in cropImg:
        for pixel in lines:
            if fmt == imgFmt.MONOALPHA_8BPP:
                count += int(pixel%16 and pixel>15)
            else:
                count += int(pixel > 0)
    return count, width, height


def getPixelsTransparencyOverlay(path1, path2, x1, y1, x2, y2):
    '''takes 2 image paths 
    displays the first at x1,y1 and the second at x2,y2 
    then returns the pixel values, and the number of pixels that should be on the display taking the transparency into account
    also returns the width and height of the total overlay of the 2 images'''
    
    img1 = cv2.imread(path1, cv2.IMREAD_UNCHANGED)
    img1 = cv2.rotate(img1, cv2.ROTATE_180)
    img1 = imgMdp05.convert8Bpp(img1)
    img2 = cv2.imread(path2, cv2.IMREAD_UNCHANGED)
    img2 = cv2.rotate(img2, cv2.ROTATE_180)
    img2 = imgMdp05.convert8Bpp(img2)
    
    computed_display_screen = numpy.zeros((display.HEIGHT, display.WIDTH))
    for i in range(height1 := min(img1.shape[0], display.HEIGHT - x1)):
        for j in range(width1 := min(img1.shape[1], display.WIDTH - y1)):
            color = img1[i, j]//16
            alpha = (img1[i,j]%16)
            computed_display_screen[i + x1, j + y1] = color*alpha//15
    for i in range(height2 := min(img2.shape[0], display.HEIGHT - x2)):
        for j in range(width2 := min(img2.shape[1], display.WIDTH - y2)):
            color = img2[i,j]//16
            alpha = img2[i,j]%16
            anti_alpha = 15 - alpha
            computed_display_screen[i + x2, j + y2] = (computed_display_screen[i + x2, j + y2]*anti_alpha + color*alpha)//15

    max_width = max(x1 + width1, x2 + width2) - min(x1,x2)
    max_height = max(y1 + height1, y2 + height2) - min(y1,y2)
    return computed_display_screen, numpy.count_nonzero(computed_display_screen), max_width, max_height


## get number of pixel of each images in the folder
def getNbPixelAnim(folder, x, y, clippingX0, clippingY0, clippingX1, clippingY1, fmt = imgFmt.MONO_4BPP):
    imgs = []
    
    ## for each file in folder
    for f in sorted(os.listdir(folder)):
        path = os.path.join(folder, f)
        if os.path.isfile(path):
            count, width, height = getNbPixelImg(path, x, y, clippingX0, clippingY0, clippingX1, clippingY1, fmt)
            imgs.append({'count': count, 'width': width, 'height': height})
    
    return imgs

def getNbPixelFont(font, str, rot, x, y, clippingX0, clippingY0, clippingX1, clippingY1, path="", size=0):
    if len(str)==0:
        return 0
    if path == "":
        if font > 0:
            font -= 1
        lMat = []
        for car in str:
            mat = fontAdd.rle_to_matrix(fontData.DATA[font][fontData.OFFSET[font][ord(car)-ord(' ')]:fontData.OFFSET[font][ord(car)-ord(' ')+2]], fontSize.getFontHeight(font + 1))
            lMat.append(numpy.array(mat))
        fin = lMat[0]
        for k in range(1, len(lMat)):
            fin = numpy.concatenate((fin, lMat[k]), axis=1)
    else:
        fin = fontAdd.char_to_pixels(str, size, path)
    h, w = fin.shape
    ## we have to move from (lenght-1) or (width-1) indexes to go from the last to the first
    equi = [(0, False, x, y), (0, True, x-(w-1), y), 
            (3, False, x-(h-1), y), (3, True, x-(h-1), y-(w-1)),
            (2, False, x-(w-1), y-(h-1)), (2, True, x, y-(h-1)),
            (1, False, x, y-(w-1)), (1, True, x, y)]
    rota, flip, x , y= equi[rot]
    if flip:
        for (i,line) in enumerate(fin):
            fin[i] = numpy.flip(line)
    fin = numpy.rot90(fin, rota)
    height, width = fin.shape
    clippingX0 = clamp(clippingX0, 0, display.WIDTH-1)
    clippingY0 = clamp(clippingY0, 0, display.HEIGHT-1)
    clippingX1 = clamp(clippingX1, 0, display.WIDTH-1)
    clippingY1 = clamp(clippingY1, 0, display.HEIGHT-1)
    x2 = x + width
    y2 = y + height

    if x > clippingX1 or x2 < clippingX0 or y > clippingY1 or y2 < clippingY0:
        return 0


    myX0 = clamp(x, clippingX0, clippingX1)
    myY0 = clamp(y, clippingY0, clippingY1)
    myX1 = clamp(x2, clippingX0, clippingX1)
    myY1 = clamp(y2, clippingY0, clippingY1)

    cropGray = fin[myY0-y: myY1-y+1, myX0-x: myX1-x+1]

    count = 0
    for lines in cropGray:
        for pixel in lines:
            if pixel > 0:
                count +=1
    return count


def get_line(start, end):
    """Bresenham's Line Algorithm"""
    # Setup initial conditions
    x1, y1 = start
    x2, y2 = end
    dx = x2 - x1
    dy = y2 - y1

    # Determine how steep the line is
    is_steep = abs(dy) > abs(dx)

    # Rotate line
    if is_steep:
        x1, y1 = y1, x1
        x2, y2 = y2, x2

    # Swap start and end points if necessary and store swap state
    swapped = False
    if x1 > x2:
        x1, x2 = x2, x1
        y1, y2 = y2, y1
        swapped = True

    # Recalculate differentials
    dx = x2 - x1
    dy = y2 - y1

    # Calculate error
    error = int(dx / 2.0)
    ystep = 1 if y1 < y2 else -1

    # Iterate over bounding box generating points between start and end
    y = y1
    points = []
    for x in range(x1, x2 + 1):
        coord = [y, x] if is_steep else [x, y]
        points.append(coord)
        error -= abs(dy)
        if error < 0:
            y += ystep
            error += dx

    # Reverse the list if the coordinates were swapped
    if swapped:
        points.reverse()
    return points


def getPxlPolyScreen(lLine):
    """get matrix of screen from a list of lines"""
    lcoord = []
    for [x0, y0, x1, y1] in lLine:
        lcoord += get_line((y0, x0), (y1, x1))
    mat = numpy.zeros((display.HEIGHT, display.WIDTH))
    for [x, y] in lcoord:
        mat[x][y] = 1
    return(mat)

def getQspiIdNameSize():
    qspiIdPartSize= [[0,'firmware', 120], 
                    [1, 'param', 64], 
                    [2, 'log', 52], 
                    [3, 'generic', 3200], 
                    [4, 'platform_params', 8],
                    [5, 'partition_table', 4],
                    [6, 'fw_exec',320],
                    [7, 'fw_update', 320],
                    [8, 'product_header', 4],
                    [9, 'image_header', 4]]
    return qspiIdPartSize

