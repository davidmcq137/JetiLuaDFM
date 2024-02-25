import sys
import math
from PIL import Image, ImageDraw, ImageFont

############################################################
# http://stackoverflow.com/questions/3122049/drawing-an-anti-aliased-line-with-thepython-imaging-library
# https://en.wikipedia.org/wiki/Xiaolin_Wu%27s_line_algorithm

import math

def plot(draw, img, x, y, c, col, steep, dash_interval):
    """Draws an antiliased pixel on a line."""
    if steep:
        x, y = y, x
    if x < img.size[0] and y < img.size[1] and x >= 0 and y >= 0:
        c = c * (float(col[3]) / 255.0)
        p = img.getpixel((x, y))
        x = int(x)
        y = int(y)
        if dash_interval:
            d = dash_interval - 1
            if (x / dash_interval) % d == 0 and (y / dash_interval) % d == 0:
                return
        draw.point((x, y), fill=(
            int((p[0] * (1 - c)) + col[0] * c),
            int((p[1] * (1 - c)) + col[1] * c),
            int((p[2] * (1 - c)) + col[2] * c), 255))

def iround(x):
    """Rounds x to the nearest integer."""
    return ipart(x + 0.5)


def ipart(x):
    """Floors x."""
    return math.floor(x)


def fpart(x):
    """Returns the fractional part of x."""
    return x - math.floor(x)


def rfpart(x):
    """Returns the 1 minus the fractional part of x."""
    return 1 - fpart(x)


def draw_line_antialiased(draw, img, x1, y1, x2, y2, col, dash_interval=None):
    """Draw an antialised line in the PIL ImageDraw.

    Implements the Xialon Wu antialiasing algorithm.

    col - color
    """
    dx = x2 - x1
    if not dx:
        draw.line((x1, y1, x2, y2), fill=col, width=1)
        return

    dy = y2 - y1
    steep = abs(dx) < abs(dy)
    if steep:
        x1, y1 = y1, x1
        x2, y2 = y2, x2
        dx, dy = dy, dx
    if x2 < x1:
        x1, x2 = x2, x1
        y1, y2 = y2, y1
    gradient = float(dy) / float(dx)

    # handle first endpoint
    xend = round(x1)
    yend = y1 + gradient * (xend - x1)
    xgap = rfpart(x1 + 0.5)
    xpxl1 = xend    # this will be used in the main loop
    ypxl1 = ipart(yend)
    plot(draw, img, xpxl1, ypxl1, rfpart(yend) * xgap, col, steep,
         dash_interval)
    plot(draw, img, xpxl1, ypxl1 + 1, fpart(yend) * xgap, col, steep,
         dash_interval)
    intery = yend + gradient  # first y-intersection for the main loop

    # handle second endpoint
    xend = round(x2)
    yend = y2 + gradient * (xend - x2)
    xgap = fpart(x2 + 0.5)
    xpxl2 = xend    # this will be used in the main loop
    ypxl2 = ipart(yend)
    plot(draw, img, xpxl2, ypxl2, rfpart(yend) * xgap, col, steep,
         dash_interval)
    plot(draw, img, xpxl2, ypxl2 + 1, fpart(yend) * xgap, col, steep,
         dash_interval)

    # main loop
    for x in range(int(xpxl1 + 1), int(xpxl2)):
        plot(draw, img, x, ipart(intery), rfpart(intery), col, steep,
             dash_interval)
        plot(draw, img, x, ipart(intery) + 1, fpart(intery), col, steep,
             dash_interval)
        intery = intery + gradient
		
############################################################

# usage: python3 gaugeGen.py wid, hgt, x0, y0, rad, minA, maxA, maj, min, fine, labels, title, tx, ty, file
#
# where wid is width of overall image in pixels
#       hgt is height of overall image in pixels
#       x0 is x origin in pixels
#       y0 is y origin in pixels
#       rad us the radius of the outermost tick start point in pixels
#       minA is the angle in degrees (north is 0, cw is positive) of the min value
#       maxA is the angle in degrees (north is 0, cw is positive) of the max value
#       maj is the number of major (labeled) tics
#       min is the number of minor tics
#       fine is the number of fine tics
#       labels is a comma separated string of the labels, length should match maj e.g. "12,13,14,14,16,17,18"
#       title is the gauge title e.g "m/s"
#       file is the output filename e.g. "foo.bmp" (file will be output as a bmp)

width = int(sys.argv[1])
height = int(sys.argv[2])
x0 = int(sys.argv[3])
y0 = int(sys.argv[4])
radius = int(sys.argv[5])
minA = int(sys.argv[6])
maxA = int(sys.argv[7])
major = int(sys.argv[8])
minor = int(sys.argv[9])
fine = int(sys.argv[10])
labels = sys.argv[11].split(",")
title = sys.argv[12]
tx = int(sys.argv[13])
ty = int(sys.argv[14])
file = sys.argv[15]

#print("width", width, type(width))

mult = 1
im = Image.new('RGB', (width * mult, height * mult))

w = im.size[0]
h = im.size[1]
linewidth = 2

draw = ImageDraw.Draw(im)

font = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSansMono-ExtraCondensedLight.ttf", mult*17)
#font = ImageFont.truetype("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", 70)
#font = ImageFont.truetype("/usr/share/fonts/opentype/cantarell/Cantarell-Regular.otf", 60)

dot = mult*2
draw.ellipse((x0 - dot, y0 - dot, x0 + dot, y0 + dot), fill=(255,255,255,255))

def rr(start, end, step):
	if end > start:
		while start <= end:
			yield start
			start += step
	else:
		while start >= end:
			yield start
			start += step


ro = radius * mult
ri = ro * .75
rt = ro * .60

draw.text((tx, ty), title, font=font, anchor = "mm")

# over-writing ticks seemed to be causing issues with the antialiasing.. so use ticlist to avoid that

ticlist = []

labelIdx = 0
for alpha in rr (minA, maxA, (maxA - minA) / major):
	xo = ro * math.sin(math.radians(alpha))
	yo = ro * math.cos(math.radians(alpha))

	xi = ri * math.sin(math.radians(alpha))
	yi = ri * math.cos(math.radians(alpha))	
	
	#draw.line((x0 + xi, h - (y0 + yi), x0 + xo, h - (y0 + yo)), fill=(255,255,255,128), width=linewidth)
	draw_line_antialiased(draw, im, x0 + xi, h - (y0 + yi), x0 + xo, h - (y0 + yo), (255,255,255,255))
	ticlist.append(alpha)
	
	xt = rt * math.sin(math.radians(alpha))
	yt = rt * math.cos(math.radians(alpha))

	if labelIdx < len(labels):
		draw.text((x0 + xt, h - (y0 + yt)), labels[labelIdx], font=font, anchor="mm")
		labelIdx = labelIdx + 1
	
ri = ro * .75

for alpha in rr (minA, maxA, (maxA - minA) / minor):
	xo = ro * math.sin(math.radians(alpha))
	yo = ro * math.cos(math.radians(alpha))

	xi = ri * math.sin(math.radians(alpha))
	yi = ri * math.cos(math.radians(alpha))	

	if ticlist.count(alpha) == 0:
		#draw.line((x0 + xi, h - (y0 + yi), x0 + xo, h - (y0 + yo)), fill=(255,255,255,128), width=linewidth)
		draw_line_antialiased(draw, im, x0 + xi, h - (y0 + yi), x0 + xo, h - (y0 + yo), (255,255,255,255))
		ticlist.append(alpha)
	
ri = ro * .85
for alpha in rr (minA, maxA, (maxA - minA) / fine):
	xo = ro * math.sin(math.radians(alpha))
	yo = ro * math.cos(math.radians(alpha))

	xi = ri * math.sin(math.radians(alpha))
	yi = ri * math.cos(math.radians(alpha))	

	if ticlist.count(alpha) == 0:
		#draw.line((x0 + xi, h - (y0 + yi), x0 + xo, h - (y0 + yo)), fill=(255,255,255,128), width=linewidth)
		draw_line_antialiased(draw, im, x0 + xi, h - (y0 + yi), x0 + xo, h - (y0 + yo), (255,255,255,255))


if mult > 1.0:
	im160 = im.resize((160,160), Image.BICUBIC)
else:
	im160 = im

#Show image
#im.show()

im160.save(file, "BMP")

