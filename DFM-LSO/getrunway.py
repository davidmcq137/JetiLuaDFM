from __future__ import print_function

from PIL import Image, ImageDraw, ImageFile
import json
import math
import requests
import os
#import ConfigParser
import sys

# note .. if you get an error on i/o to the image17 file probably the google api
# call is broken .. need to get a better error message for this!!!
#
# note: relies on file ~/getrunway.conf in the home dir to store the google api key
#
# note: TX will display image with runway horizontal, with pilot position below runway
# rotate field orientation by 180 if rendered upside down
#
# Google maps api zoom level -> scale
# https://gis.stackexchange.com/questions/7430/
# metersPerPx = 156543.03392 * Math.cos(latLng.lat() * Math.PI / 180) / Math.pow(2, zoom)
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
	#config = ConfigParser.ConfigParser()
	#osp = os.path.expanduser('/home/getrunway.conf')
	#config.read(osp)
	#api_key = config.get('KEYS', 'api_key')
	#print("api_key:", api_key)
	fd = open("/home/davidmcq/getrunway.conf", "r")
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

def Gmaps_feet_per_px(lat, zoom): # first constant from Google, second one converts to ft from m
	return 156543.03392 * 3.280839895013123 * math.cos(math.radians(lat)) / math.pow(2,zoom)

def Gmaps_px_per_foot(lat, zoom):
	return 1.0 / Gmaps_feet_per_px(lat, zoom)

#print (len(sys.argv))
#print (sys.argv[0])
#print (sys.argv[1])
#print (sys.argv[2])

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

crop_to_zoom = {1500:17, 3000:16, 6000:15, 12000:14}

if len(sys.argv) > 1:
	fieldFile = sys.argv[1] + ".jsn"
else:
	fieldFile = "Fields.jsn"

print("Reading Field file ", fieldFile)


with open(fieldFile) as json_data:
	try:
		jd	= json.load(json_data)
	except ValueError as valmsg:
		print("JSON Decode error in " + fieldFile)
		print(valmsg)
		exit()

# in case no default for images

	defImages = jd.get("fields_defaults").get("images", [1500, 3000, 6000])

	#print("defImages", defImages)
	
# First loop over all the fields read from Fields.jsn

for fld in jd["fields"]:

	field_name=fld["name"]
	short_name=fld["shortname"]

	view = fld.get("view", "Standard")
	latitude = fld["lat"]
	longitude =	fld["long"]
	truedir = fld["runway"]["trueDir"]
	runway_length_ft = fld["runway"]["length"]
	runway_width_ft =  fld["runway"]["width"]
	runway_x_offset_ft = fld["runway"].get("x_offset", 0)
	runway_y_offset_ft = -fld["runway"].get("y_offset", 0)
	#print("runway_x_offset_ft: ", runway_x_offset_ft)
	#print("runway_y_offset_ft: ", runway_y_offset_ft)	
	#print("runway_length_ft: ", runway_length_ft)
		
	# Then loop over all images for that field

	if fld.get("images") == None:
		fld["images"] = defImages
	
	for im_index in range(len(fld["images"])): 

		#filename = fld["images"][im_index]["filename"]
		#field_image_width_ft  = fld["images"][im_index]["xrange"]
		field_image_width_ft  = fld["images"][im_index]
		field_image_height_ft = field_image_width_ft/2
		filename = short_name + "_" + str(field_image_width_ft) + "_ft.png"
		#print("Constructed Filename: ", filename)
		if field_image_width_ft < 1500 or field_image_width_ft > 12000:
			print("Field image width must be between 1500 and 12000")
			exit()

		zoom = 0
		iw = 0
		for width in crop_to_zoom:
			if field_image_width_ft <= width:
				zoom = crop_to_zoom[width]
				iw = width
				#print("zoom=", zoom)
				#print("imagewidth=", width)
				#print("field_image_width_ft=", field_image_width_ft)
				break

		if zoom == 0:
			print("Crop error. exiting")
			exit()

		#old way with only zoom levels being the ones in the dict
		#above code allows widths between the fixed zoom levels
		#zoom = crop_to_zoom[field_image_width_ft]

		if iPad:
			filename = "iPad_" + filename

		print(field_name, filename, latitude, longitude, field_image_width_ft, zoom)

		# Russell stored intermediate reps in memory. We shall be lazy and store them
		# in temp files since it's easy to do that with the data from requests()
		
		Gmaps = get_Gmaps_image(zoom, latitude, longitude)
	
		# note that in PIL the image.rotate operation rotates about the image center, not
		# the 0,0 point as was the case in Russell's original implementation so we have less
		# work to do (vs. translate, rotate, and then translate back)
	
		Gmaps_rotate = Gmaps.rotate(truedir-270)
	
		field_image_width_px =	Gmaps_px_per_foot(latitude, zoom) * field_image_width_ft
		field_image_height_px = Gmaps_px_per_foot(latitude, zoom) * field_image_height_ft
	
		wwGr, hhGr = Gmaps_rotate.size	# note the image size

		# clip the rotated image to the requested field image size. For the "Standard" view,
		# offset the position of 
		# the runway in the image to be 1/4 of the way up from the bottom since we stand to that 
		# narrower side when flying
		# for the "Centered" view put the runway in the center

		if view == "Standard":
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

		runway_width_px	   = runway_width_ft    * Gmaps_px_per_foot(latitude, zoom)
		runway_length_px   = runway_length_ft   * Gmaps_px_per_foot(latitude, zoom)
		runway_x_offset_px = runway_x_offset_ft * Gmaps_px_per_foot(latitude, zoom)
		runway_y_offset_px = runway_y_offset_ft * Gmaps_px_per_foot(latitude, zoom)		
		
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
		dd.rectangle( ((int(wwj/2 - runway_length_px/2 + runway_x_offset_px), int(hhj * topMult - runway_width_px/2 + runway_y_offset_px) ),
					   (int(wwj/2 + runway_length_px/2 + runway_x_offset_px), int(hhj * topMult + runway_width_px/2 + runway_y_offset_px) )),
					  outline='yellow')

		Jeti.save(filename, "PNG")

print(" ")
print("Don't forget to copy the updated Fields.jsn file along with the PNGs !!!")













