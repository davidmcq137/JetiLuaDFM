from __future__ import print_function

from PIL import Image, ImageDraw
import json
import math
import requests
import os
import ConfigParser
import sys

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
# 9  : 2311162.307000
# 8  : 4622324.614000
# 7  : 9244649.227000
# 6  : 18489298.450000
# 5  : 36978596.910000
# 4  : 73957193.820000
# 3  : 147914387.600000
# 2  : 295828775.300000
# 1  : 591657550.500000


def Gmaps_api_request(**kwargs):
    res =  requests.request("GET",
                            "https://maps.googleapis.com/maps/api/staticmap",
                            stream=True,
                            params=kwargs)
    print("URL:", res.url)
    return res

def get_Gmaps_image(zoom, latitude, longitude):
    config = ConfigParser.ConfigParser()
    osp = os.path.expanduser('~/getrunway.conf')
    config.read(osp)
    api_key = config.get('KEYS', 'api_key')
    #print("api_key:", api_key)
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
#print (sys.argv[1])

print ("Give any commandline arg to generate iPad images")

if len(sys.argv) > 1:
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

with open("Fields.jsn") as json_data:
    jd  = json.load(json_data)

# First loop over all the fields read from Fields.jsn

for fld in jd["fields"]:

    field_name=fld["name"]
    short_name=fld["shortname"]

    latitude =         fld["runway"]["lat"]
    longitude =        fld["runway"]["long"] 
    truedir =          fld["runway"]["trueDir"]
    runway_length_ft = fld["runway"]["length"]
    runway_width_ft =  fld["runway"]["width"]

    # Then loop over all images for that field

    for im_index in range(len(fld["images"])): 

        filename = fld["images"][im_index]["filename"]
        field_image_width_ft  = fld["images"][im_index]["xrange"]
        field_image_height_ft =field_image_width_ft/2
        zoom = crop_to_zoom[field_image_width_ft] 

        if iPad:
            filename = "iPad_" + filename

        print(field_name, filename, latitude, longitude, field_image_width_ft, zoom)

        # Russell stored intermediate reps in memory. We shall be lazy and store them
        # in temp files since it's easy to do that with the data from requests()
        
        Gmaps = get_Gmaps_image(zoom, latitude, longitude)
        wwGr, hhGr = Gmaps.size  # note the image size    
        print("size ww,hh:", wwGr, hhGr)


		# note that in PIL the image.rotate operation rotates about the image center, not
        # the 0,0 point as was the case in Russell's original implementation so we have less
        # work to do (vs. translate, rotate, and then translate back)

        print("pre w:", Gmaps_px_per_foot(latitude,zoom), field_image_width_ft)
        print("pre h:", Gmaps_px_per_foot(latitude,zoom), field_image_height_ft)						
        Gmaps_rotate = Gmaps.rotate(truedir-270)
    
        field_image_width_px =  Gmaps_px_per_foot(latitude, zoom) * field_image_width_ft
        field_image_height_px = Gmaps_px_per_foot(latitude, zoom) * field_image_height_ft
    
        wwGr, hhGr = Gmaps_rotate.size  # note the image size

        print("size ww,hh:", wwGr, hhGr)

        # clip the rotated image to the requested field image size. Also offset the position of 
        # the runway in the image to be 1/4 of the way up from the bottom since we stand to that 
        # narrower side when flying

        clip_box = (wwGr/2 - field_image_width_px / 2,
                    hhGr/2 - field_image_height_px * 3 / 4,
                    wwGr/2 + field_image_width_px / 2,
                    hhGr/2 + field_image_height_px / 4)


        Gmaps_rotate_crop = Gmaps_rotate.crop(clip_box)

        wwGrc, hhGrc = Gmaps_rotate_crop.size # note image size again...

        runway_width_px  = runway_width_ft  * Gmaps_px_per_foot(latitude, zoom)
        runway_length_px = runway_length_ft * Gmaps_px_per_foot(latitude, zoom)

        # now produce the transmitter-sized image

        print("imageOut: ", imageOut)
		
        Jeti = Gmaps_rotate_crop.resize( imageOut )


        # originally we put the yellow rectangle on the larger rotated image before cropping but
        # since it was a one pixel line (the width= option seems not to work), the vertical line
        # got lost when shrinking to 320x160, so we have to apply it instead to the final image
        # and thus adjust the pixel size of the runway accordingly (ugg)
        
        # create a drawing context for the rectangle
        
        dd = ImageDraw.Draw(Jeti)
        
        wwj, hhj = Jeti.size # note image size again... j/Grc ratio will adjust px per inch
        
        runway_length_px = runway_length_px * wwj/wwGrc
        runway_width_px  = runway_width_px  * hhj/hhGrc

        # draw the yellow rectangle for the runway to confirm registration
        
        dd.rectangle( ((int(wwj/2 - runway_length_px/2), int(3*hhj/4 - runway_width_px/2) ),
                       (int(wwj/2 + runway_length_px/2), int(3*hhj/4 + runway_width_px/2) )),
                      outline='yellow')

        Jeti.save(filename, "PNG")

print(" ")
print("Don't forget to copy the updated Fields.jsn file along with the PNGs !!!")













