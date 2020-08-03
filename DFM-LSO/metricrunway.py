from __future__ import print_function

from PIL import Image, ImageDraw, ImageFile
import json
import math
import requests
import os
import sys

# note: relies on file ~/getrunway.conf in the home dir to store the google api key
#
# note: TX will display image with runway horizontal, with pilot position below runway
# rotate field orientation by 180 if rendered upside down
#
# Google maps api zoom level -> scale
# https://gis.stackexchange.com/questions/7430/
# metersPerPx = 156543.03392 * Math.cos(latLng.lat() * Math.PI / 180) / Math.pow(2, zoom)
#
# Zoom Scale (m/px)
# 20 : 1128.497220
# 19 : 2256.994440
# 18 : 4513.988880
# 17 : 9027.977761
# 16 : 18055.955520
# 15 : 36111.911040
# 14 : 72223.822090
# 13 : 144447.644200
# 12 : 288895.288400
# 11 : 577790.576700
# 10 : 1155581.153000
# 9	 : 2311162.307000
# 8	 : 4622324.614000
# 7	 : 9244649.227000
# 6	 : 18489298.450000
# 5	 : 36978596.910000
# 4	 : 73957193.820000
# 3	 : 147914387.600000
# 2	 : 295828775.300000
# 1	 : 591657550.500000


def Gmaps_api_request(**kwargs):

	ret = requests.request("GET",
		 					"https://maps.googleapis.com/maps/api/staticmap",
							stream=True,
							params=kwargs)
	if str(ret).strip() != "<Response [200]>":
		print("Google maps error (bad API key?): ", ret)
		exit()
	return ret

def get_Gmaps_image(zoom, latitude, longitude):
	if os.name == "posix":
		fd = open("/home/davidmcq/getrunway.conf", "r") # Linux
	elif os.name == "nt":
		fd = open("getrunway.conf", "r")	# Windows
	else:
		print("unknown os", os.name)
		exit()
	api_key = fd.readline()
	fd.close()
	latlong= str(latitude) + "," + str(longitude)
	with open("temp%d.png" % zoom, "wb") as file:
		file.write(Gmaps_api_request(
			center=latlong,
			zoom="%d" % zoom,
			size=imageSize,
			maptype="satellite",
			key=api_key
		).content)
	return Image.open("temp%d.png" % zoom).convert("RGB")

def Gmaps_meters_per_px(lat, zoom): # 156... constant from Google
	return 156543.03392 * math.cos(math.radians(lat)) / math.pow(2,zoom)

def Gmaps_px_per_meter(lat, zoom):
	return 1.0 / Gmaps_meters_per_px(lat, zoom)

def rotateXYdeg(x, y, rotation):
	sind = math.sin(math.radians(rotation))
	cosd = math.cos(math.radians(rotation))
	return x * cosd - y * sind, x * sind + y * cosd

rE = 6371000  # 6371*1000 radius of earth in meters, approx

#print ("Takes two command line args. First is Fields filename, second creates iPad images")
#print ("Give two commandline args to generate iPad images")

if len(sys.argv) > 2:
	iPad = True
	imageSize = "2048x2048"
	imageOut = (2048, 1024)
	print("iPad mode")
else:
	iPad = False
	imageSize = "640x640"
	imageOut = (320, 160)
	print("Jeti mode")
	
# experimentation showed these zooms best for these field image widths

crop_to_zoom = {1000:16, 2000:15, 4000:14}

if len(sys.argv) > 1:
	fieldFile = sys.argv[1] + ".jsn"
else:
	fieldFile = "TriFields.jsn"

print("Reading Field file ", fieldFile)


with open(fieldFile) as json_data:
	try:
		jd	= json.load(json_data)
	except ValueError as valmsg:
		print("JSON Decode error in " + fieldFile)
		print(valmsg)
		exit()

# in case no default for images

	#defImages = jd.get("fields_defaults").get("images", [1000, 2000, 4000])
	defImages = [1000, 1500, 2000, 3000, 4000]	

	#print("defImages", defImages)
	
# First loop over all the fields read from Fields.jsn

for fld in jd["trifields"]:

	field_name=fld["name"]
	short_name=fld["shortname"]

	View = fld.get("View", "Standard")
	latitude = fld["lat"]
	coslat = math.cos(math.radians(latitude))
	longitude =	fld["long"]
	trueDir = fld["startHeading"]
	runway_length_m = fld["runway"]["length"]
	runway_width_m =  fld["runway"]["width"]
	runway_x_offset_m = fld["runway"].get("x_offset", 0)
	runway_y_offset_m = -fld["runway"].get("y_offset", 0)
		
	# Then loop over all images for that field

	if fld.get("images") == None:
		fld["images"] = defImages
	
	for im_index in range(len(fld["images"])): 

		field_image_width_m  = fld["images"][im_index]
		field_image_height_m = field_image_width_m/2
		filename = short_name + "_Tri_" + str(field_image_width_m) + "_m.png"
		#print("Constructed Filename: ", filename)
		
		if field_image_width_m < 1000 or field_image_width_m > 4000:
			print("Field image width must be between 1000 and 4000m")
			exit()

		zoom = 0
		iw = 0
		for width in crop_to_zoom:
			if field_image_width_m <= width:
				zoom = crop_to_zoom[width]
				iw = width
				#print("zoom=", zoom)
				#print("imagewidth=", width)
				#print("field_image_width_m=", field_image_width_m)
				break

		if zoom == 0:
			print("Crop error. exiting")
			exit()

		#old way with only zoom levels being the ones in the dict
		#above code allows widths between the fixed zoom levels
		#zoom = crop_to_zoom[field_image_width_m]

		if iPad:
			filename = "iPad_" + filename

		print(field_name, filename, latitude, longitude, field_image_width_m, zoom)

		# Russell stored intermediate reps in memory. We shall be lazy and store them
		# in temp files since it's easy to do that with the data from requests()
		
		Gmaps = get_Gmaps_image(zoom, latitude, longitude)
	
		# note that in PIL the image.rotate operation rotates about the image center, not
		# the 0,0 point as was the case in Russell's original implementation so we have less
		# work to do (vs. translate, rotate, and then translate back)
	
		Gmaps_rotate = Gmaps.rotate(trueDir-270)
	
		field_image_width_px =	Gmaps_px_per_meter(latitude, zoom) * field_image_width_m
		field_image_height_px = Gmaps_px_per_meter(latitude, zoom) * field_image_height_m
	
		wwGr, hhGr = Gmaps_rotate.size	# note the image size

		# clip the rotated image to the requested field image size. For the "Standard" view,
		# offset the position of 
		# the runway in the image to be 1/4 of the way up from the bottom since we stand to that 
		# narrower side when flying
		# for the "Centered" view put the runway in the center

		if View == "Standard":
			botMult = 0.25
			topMult = 0.75
		else:
			botMult = 0.50
			topMult = 0.50

		clip_box = (wwGr/2 - field_image_width_px / 2,
					hhGr/2 - field_image_height_px * topMult,
					wwGr/2 + field_image_width_px / 2,
					hhGr/2 + field_image_height_px * botMult)


		Gmaps_rotate_crop = Gmaps_rotate.crop(clip_box)

		wwGrc, hhGrc = Gmaps_rotate_crop.size # note image size again...

		runway_width_px	   = runway_width_m    * Gmaps_px_per_meter(latitude, zoom)
		runway_length_px   = runway_length_m   * Gmaps_px_per_meter(latitude, zoom)
		runway_x_offset_px = runway_x_offset_m * Gmaps_px_per_meter(latitude, zoom)
		runway_y_offset_px = runway_y_offset_m * Gmaps_px_per_meter(latitude, zoom)		
		
		# now produce the transmitter-sized image

		#print("imageOut: ", imageOut)
		
		Jeti = Gmaps_rotate_crop.resize( imageOut )


		# originally we put the yellow rectangle on the larger rotated image before cropping but
		# since it was a one pixel line (the width= option seems not to work), the vertical line
		# got lost when shrinking to 320x160, so we have to apply it instead to the final image
		# and thus adjust the pixel size of the runway accordingly (ugg)
		
		# create a drawing context for the rectangle
		
		dd = ImageDraw.Draw(Jeti)
		
		wwj, hhj = Jeti.size # note image size again... j/Grc ratio will adjust px per inch

		runway_length_px = runway_length_px * wwj/wwGrc
		runway_width_px	 = runway_width_px	* hhj/hhGrc
		runway_x_offset_px = runway_x_offset_px * wwj/wwGrc
		runway_y_offset_px = runway_y_offset_px * hhj/hhGrc		

		# draw the yellow rectangle for the runway to confirm registration
		# print("runway_length_px, runway_x_offset_px: ", runway_length_px, runway_x_offset_px)
		dd.rectangle( ((int(wwj/2 - runway_length_px/2 + runway_x_offset_px),
						int(hhj * topMult - runway_width_px/2 + runway_y_offset_px) ),
					   (int(wwj/2 + runway_length_px/2 + runway_x_offset_px),
						int(hhj * topMult + runway_width_px/2 + runway_y_offset_px) )),
					  outline='yellow')

		NoFly = fld.get("NoFly")
		if NoFly:
			NoFly_pix = []
			for i in range(len(NoFly)):
				x = rE * (math.radians(NoFly[i]["long"]) - math.radians(longitude)) * coslat
				y = rE * (math.radians(NoFly[i]["lat"]) - math.radians(latitude))
				xr, yr = rotateXYdeg(x, y, trueDir - 270.0)
				xr = xr * Gmaps_px_per_meter(latitude, zoom)
				yr = yr * Gmaps_px_per_meter(latitude, zoom)
				xr = xr * wwj / wwGrc + wwj / 2
				yr = -yr * hhj / hhGrc + hhj * topMult
				NoFly_pix.append((xr, yr))
				if fld.get("noFlyZone") != "Outside":
					color = "red"
				else:
					color = "greenyellow"
					
			dd.polygon(NoFly_pix, outline=color)

		NoFlyC = fld.get("NoFlyCircle")
		#print("NoFlyC", NoFlyC)
		if NoFlyC:
			for i in range(len(NoFlyC)):
				x = rE * (math.radians(NoFlyC[i]["long"]) - math.radians(longitude)) * coslat
				y = rE * (math.radians(NoFlyC[i]["lat"]) - math.radians(latitude))
				r = NoFlyC[i]["radius"]
				rp = r * Gmaps_px_per_meter(latitude, zoom) * wwj / wwGrc
				#print("wwj/wwGrc, hhj/hhGrc", wwj/wwGrc, hhj/hhGrc)
				xr, yr = rotateXYdeg(x, y, trueDir - 270.0)
				xr = xr * Gmaps_px_per_meter(latitude, zoom)
				yr = yr * Gmaps_px_per_meter(latitude, zoom)
				xr = xr * wwj / wwGrc + wwj / 2
				yr = -yr * hhj / hhGrc + hhj * topMult
				if NoFlyC[i].get("noFlyZone") != "Outside":
					color = "red"
				else:
					color = "greenyellow"
				
				dd.ellipse([xr - rp, yr - rp, xr + rp, yr + rp], outline=color, width=1)

		Jeti.save(filename, "PNG")

print(" ")
print("Don't forget to copy the updated Fields.jsn file along with the PNGs !!!")













