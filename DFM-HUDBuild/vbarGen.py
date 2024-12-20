import sys
import math
from PIL import Image, ImageDraw, ImageFont

# usage: python3 vbarGen.py wid, hgt, x0, y0, barw, barh, maj, labels, title, tx, ty, file
#
# where wid is width of overall image in pixels
#       hgt is height of overall image in pixels
#       x0 is x origin in pixels
#       y0 is y origin in pixels
#       barw is the bar width in pixels
#       barh is the bar height in pixels
#       maj is the number of major (labeled) tics
#       labels is a comma separated string of the labels, length should match maj e.g. "12,13,14,14,16,17,18"
#       title is the gauge title e.g "m/s"
#       file is the output filename e.g. "foo.bmp" (file will be output as a bmp)

width = int(sys.argv[1])
height = int(sys.argv[2])
x0 = int(sys.argv[3])
y0 = int(sys.argv[4])
barw = int(sys.argv[5])
barh = int(sys.argv[6])
major = int(sys.argv[7])
labels = sys.argv[8].split(",")
title = sys.argv[9]
tx = int(sys.argv[10])
ty = int(sys.argv[11])
file = sys.argv[12]

mult = 1
im = Image.new('RGB', (width * mult, height * mult))

w = im.size[0]
h = im.size[1]
linewidth = 1
fontsize = 16

draw = ImageDraw.Draw(im)

font = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSansMono-ExtraCondensedLight.ttf", mult*fontsize)

def rr(start, end, step):
	if end > start:
		while start <= end:
			yield start
			start += step
	else:
		while start >= end:
			yield start
			start += step

#print("x0, y0, x0+barw, y0+barh", x0, y0, x0+barw, y0+barh)
draw.rectangle((x0, y0, x0 + barw, y0 + barh), outline=(255,255,255,255), width=linewidth)
			
draw.text((tx, ty), title, font=font, anchor = "mm")

labelIdx = 0
for yl in  rr(0, barh, barh / major):
	#print("yl+y0", yl+y0)
	draw.line((x0, yl + y0, x0 + barw, yl + y0), fill=(255,255,255,255), width=linewidth)
	
	if labelIdx < len(labels):
		draw.text((y0 + yl, x0 + barw + fontsize / 2 + 2), labels[labelIdx], font=font, anchor="mm")
		labelIdx = labelIdx + 1
	


if mult > 1.0:
	im160 = im.resize((160,160), Image.BICUBIC)
else:
	im160 = im

#Show image
#im.show()

im160.save(file, "BMP")

