import cv2
import numpy as np

from colormath.color_objects import sRGBColor, LabColor
from colormath.color_diff import delta_e_cie2000, delta_e_cie1976
from colormath.color_conversions import convert_color


PaletteRryg = [
    {'name': 'Black',   'bgr': [0.,   0.,   0.], 'raw': 0},
    {'name': 'R',       'bgr': [0.,   0.,  76.], 'raw': 4},
    {'name': 'RR',      'bgr': [0.,   0., 153.], 'raw': 5},
    {'name': 'G',       'bgr': [0.,  51.,   0.], 'raw': 8},
    {'name': 'RG',      'bgr': [0.,  51.,  76.], 'raw': 12},
    {'name': 'RRG',     'bgr': [0.,  51., 153.], 'raw': 13}, 
    {'name': 'Y',       'bgr': [0.,  89.,  89.], 'raw': 2},
    {'name': 'RY',      'bgr': [0.,  89., 166.], 'raw': 6},
    {'name': 'RRY',     'bgr': [0.,  89., 242.], 'raw': 7},
    {'name': 'GY',      'bgr': [0., 140.,  89.], 'raw': 10},
    {'name': 'RGY',     'bgr': [0., 140., 166.], 'raw': 14},
    {'name': 'RRGY',    'bgr': [0., 140., 242.], 'raw': 15}
]


PaletteRyyg = [
    {'name': 'Black',   'bgr': [0.,  0.,    0.], 'raw': 0},
    {'name': 'R',       'bgr': [0.,  0.,   76.], 'raw': 2},
    {'name': 'G',       'bgr': [0.,  51.,   0.], 'raw': 8},
    {'name': 'RG',      'bgr': [0.,  51.,  76.], 'raw': 10},
    {'name': 'Y',       'bgr': [0.,  89.,  89.], 'raw': 1},
    {'name': 'RY',      'bgr': [0.,  89., 166.], 'raw': 3},
    {'name': 'GY',      'bgr': [0., 140.,  89.], 'raw': 9},
    {'name': 'RGY',     'bgr': [0., 140., 166.], 'raw': 11},
    {'name': 'YY',      'bgr': [0., 179., 179.], 'raw': 5},
    {'name': 'RYY',     'bgr': [0., 179., 255.], 'raw': 7},
    {'name': 'GYY',     'bgr': [0., 230., 179.], 'raw': 13},
    {'name': 'RGYY',    'bgr': [0., 230., 255.], 'raw': 15}
]


## return a matrix with each pixel to format RYYG
def convertToRyyg(img):
    img = cv2.rotate(img, cv2.ROTATE_180)
    
    channel1 = img[:,:,0]
    channel2 = img[:,:,1]
    channel3 = img[:,:,2]
        
    # seuillage des canaux
    seuil = 128
    channel1_bin = cv2.threshold(channel1, seuil, 255, cv2.THRESH_BINARY)[1]
    channel2_bin = cv2.threshold(channel2, seuil, 255, cv2.THRESH_BINARY)[1]
    channel3_bin = cv2.threshold(channel3, seuil, 255, cv2.THRESH_BINARY)[1]

    final_image = np.zeros_like(img, np.uint8)
    final_image[:,:,0] = channel1_bin
    final_image[:,:,1] = channel2_bin
    final_image[:,:,2] = channel3_bin
    
    final_image_BVR = final_image

    # Mappe le jaune (les pixels qui sont à 255 pour Vert + Rouge) dans le canal Bleu
    for i in range(0, np.shape(final_image)[0]):
        for j in range(0, np.shape(final_image)[1]):
            if (final_image[i,j,1]==255) & (final_image[i,j,2]==255):
                final_image_BVR[i,j,0] = 255
                final_image_BVR[i,j,1] = 0
                final_image_BVR[i,j,2] = 0

    # Mapper les couleurs sur 4 bits via un dictionnaire Python
    bleuJaune =  final_image_BVR[:,:,0]/255*2
    vert = final_image_BVR[:,:,1]/255*1
    rouge = final_image_BVR[:,:,2]/255*8
    
    couleur = bleuJaune + vert + rouge
    couleur = couleur.astype(np.uint8)
   
    return couleur


def getDistanceCustom(c1, c2):
    ## BGR format
    b = (c1[0] - c2[0]) ** 2
    g = (c1[1] - c2[1]) ** 2
    r = (c1[2] - c2[2]) ** 2

    ## Y distance
    return 0.299 * r + 0.587 * g + 0.114 * b


def getDistance(c1, c2):
    ## BGR format
    b = (c1[0] - c2[0]) ** 2
    g = (c1[1] - c2[1]) ** 2
    r = (c1[2] - c2[2]) ** 2
    mean_r = c1[2] + c2[2] / 2

    if mean_r < 128:
        res = 2 * r + 4 * g + 3 * b
    else:
        res = 3 * r + 4 * g + 2 * b

    return res


def getDistanceRedmean(c1, c2):
    ## BGR format
    b = (c1[0] - c2[0]) ** 2
    g = (c1[1] - c2[1]) ** 2
    r = (c1[2] - c2[2]) ** 2
    mean_r = c1[2] + c2[2] / 2

    return (2 + mean_r / 256) * r + 4 * g + (2 + (255 - mean_r) / 256) * b


def getDistanceCie1976(c1, c2):
    ## BGR format
    c1 = sRGBColor(c1[2], c1[1], c1[0], True)
    c2 = sRGBColor(c2[2], c2[1], c2[0], True)
    c1 = convert_color(c1, LabColor)
    c2 = convert_color(c2, LabColor)

    ## Delta E Equation
    return delta_e_cie1976(c1, c2)


def getDistanceCie2000(c1, c2):
    ## BGR format
    c1 = sRGBColor(c1[2], c1[1], c1[0], True)
    c2 = sRGBColor(c2[2], c2[1], c2[0], True)
    c1 = convert_color(c1, LabColor)
    c2 = convert_color(c2, LabColor)

    ## Delta E Equation
    return delta_e_cie2000(c1, c2)


def getClosestColor(c, palette):
    idx = 0
    min = getDistanceCie2000(c, palette[0]['bgr'])

    if min != 0:
        for i in range(1, len(palette)):
            dist = getDistanceCie2000(c, palette[i]['bgr'])
            if dist < min:
                min = dist
                idx = i
    
    return idx


def convertViaDistance(img, palette):
    img = cv2.rotate(img, cv2.ROTATE_180)

    height = img.shape[0]
    width = img.shape[1]

    ## create a dictionary of color conversion
    ## to reduce conversion duration
    colorMap = {}
    out = np.zeros((height, width), dtype=np.uint8)
    for i in range(height):
        for j in range(width):
            key = tuple(img[i][j])
            if not key in colorMap:
                colorMap[key] = getClosestColor(img[i][j], palette)
            out[i][j] = palette[colorMap[key]]['raw']

    return out


def convertViaDistanceToRyyg(img):
    return convertViaDistance(img, PaletteRyyg)

def convertViaDistanceToRryg(img):
    return convertViaDistance(img, PaletteRryg)

## display converted matrix
def displayMatrix(matrix, palette):
    height = len(matrix)
    width = len(matrix[0])

    img = np.zeros((height, width, 3), dtype=np.uint8)
    for i in range(height):
        for j in range(width):
            c = [255, 0, 0] ## default to a flashy blue to detect erros
            for p in palette:
                if (matrix[i][j] == p['raw']):
                    c = p['bgr']

            img[i, j] = c


def displayMatrixRyyg(matrix):
    displayMatrix(matrix, PaletteRyyg)

def displayMatrixRryg(matrix):
    displayMatrix(matrix, PaletteRryg)


## function used to generate color palette
def colorMixer(colors, gain = 0):
    ## opencv colors are BGR
    rIdx = 2
    gIdx = 1
    bIdx = 0

    n = len(colors)
    
    ## mix all the colors
    palette = []
    for i in range(2 ** n):
        c = [0, 0, 0]
        raw = 0
        name = ""

        if (i & 1) != 0:
            c = np.add(c, colors[0]['bgr'])
            raw += colors[0]['raw']
            name += colors[0]['name']
        if (i & 2) != 0:
            c = np.add(c, colors[1]['bgr'])
            raw += colors[1]['raw']
            name += colors[1]['name']
        if (i & 4) != 0:
            c = np.add(c, colors[2]['bgr'])
            raw += colors[2]['raw']
            name += colors[2]['name']
        if (i & 8) != 0:
            c = np.add(c, colors[3]['bgr'])
            raw += colors[3]['raw']
            name += colors[3]['name']

        c = np.divide(c, 4)

        if name == "":
            name = "Black"

        palette.append({'name': name, 'bgr': c, 'raw': raw})

    ## remove duplicates
    seen = []
    res = []
    for c in palette:
        if c['bgr'].tolist() not in seen:
            seen.append(c['bgr'].tolist())
            res.append(c)
    palette = res

    ## compute gain
    if gain == 0:
        max = 0
        for c in palette:
            if c['bgr'][rIdx] > max:
                max = c['bgr'][rIdx]
            if c['bgr'][gIdx] > max:
                max = c['bgr'][gIdx]
            if c['bgr'][bIdx] > max:
                max = c['bgr'][bIdx]
        gain = 255 / max
    print(f"Gain;{gain}")

    ## apply gain
    for i in enumerate(palette):
        i = i[0]
        tmp = np.multiply(palette[i]['bgr'], gain)
        palette[i]['bgr'] = np.around(tmp)
    
    ## print
    for c in palette:
        print(f"{c['name']};R: {int(c['bgr'][rIdx])}, G: {int(c['bgr'][gIdx])}, B : {int(c['bgr'][bIdx])}")
    
    return palette


def colorMixerRgyy():
    # even lines: 4BPP: (Lower right)(Upper right)(Lower Left)(Upper Left)
    # GYYR

    colors = [
        {'name': 'R', 'bgr': [0,   0, 218], 'raw': 0b0010},
        {'name': 'G', 'bgr': [0, 146,   0], 'raw': 0b1000},
        {'name': 'Y', 'bgr': [0, 255, 255], 'raw': 0b0001},
        {'name': 'Y', 'bgr': [0, 255, 255], 'raw': 0b0100}
    ]

    return colorMixer(colors)

def colorMixerRrgy():
    # even lines: 4BPP: (Lower right)(Upper right)(Lower Left)(Upper Left)
    # RYGR

    colors = [
        {'name': 'R', 'bgr': [0,   0, 218], 'raw': 0b0100},
        {'name': 'R', 'bgr': [0,   0, 218], 'raw': 0b0001},
        {'name': 'G', 'bgr': [0, 146,   0], 'raw': 0b1000},
        {'name': 'Y', 'bgr': [0, 255, 255], 'raw': 0b0010}
    ]

    ## use same gain as rgyy
    return colorMixer(colors, 1.4010989010989)


##### main #####
if __name__ == '__main__':
    filepath = "C:/Projets/cobra-cfg-generator/cfgDescriptor/mdp08/img/test-304x167.png"
    #filepath = "C:/Projets/cobra-cfg-generator/cfgDescriptor/mdp08/img/colors-178x188.png"
    img = cv2.imread(filepath)

    mat = convertViaDistanceToRyyg(img)
    displayMatrixRyyg(mat)

    mat = convertViaDistanceToRryg(img)
    displayMatrixRryg(mat)

    print(colorMixerRgyy())
