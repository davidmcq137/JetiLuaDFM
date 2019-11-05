from __future__ import print_function

from PIL import Image, ImageDraw
from io import BytesIO
import json
import math
import requests
import ConfigParser
import os

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
    return requests.request("GET",
                            "https://maps.googleapis.com/maps/api/staticmap",
                            stream=True,
                            params=kwargs)

def get_Gmaps_image(zoom, latitude, longitude, API_key):
    latlong= str(latitude) + "," + str(longitude)
    Greq = Gmaps_api_request(
        key=API_key,
        center=latlong,
        zoom="%d" % zoom,
        size="640x640",
        maptype="satellite")
    return Image.open(BytesIO(Greq.content)).convert("RGB")

def Gmaps_feet_per_px(lat, zoom): # first constant from Google, second one converts to ft from m
    return 156543.03392 * 3.280839895013123 * math.cos(math.radians(lat)) / math.pow(2,zoom)

def Gmaps_px_per_foot(lat, zoom):
    return 1.0 / Gmaps_feet_per_px(lat, zoom)

# function to compute x and y distance in ft from two pairs of lat/long

def delta_xy_from_latlong(latitude1, longitude1, latitude2, longitude2):
    rE = 21220539.7  # 6371 km * 1000 m/km * 3.28084 ft/m ... radius of earth in ft, fudge of 1/0.985
    x = rE * math.radians(longitude1 - longitude2) * math.cos(math.radians((latitude1+latitude2) / 2))
    y = rE * math.radians(latitude1 - latitude2)
    return (x,y)

def rotateXY(x, y, rotation):
   sinShape = math.sin(math.radians(rotation))
   cosShape = math.cos(math.radians(rotation))
   return ((x * cosShape - y * sinShape), (x * sinShape + y * cosShape))

# experimentation showed these zooms best for these field image widths
# probably only need 2-3 per field

crop_to_zoom = {1000:17, 1500:17, 2500:16, 3000:16, 4000:15, 5000:15, 6000:15, 12000:14}

config=ConfigParser.ConfigParser()
osp = os.path.expanduser('~/LSO-Gmap-Image-Gen.conf')

config.read(osp) # so that we don't get caught in the "post my API key on Github" trap...

Gmap_API_Key = config.get('KEYS', 'api_key')

# alternately fill in and uncomment the following line and comment out the config.get line:
# Gmap_API_Key = 'asdf1234asdf or whatever'

print("Using Google Maps API Key:", Gmap_API_Key)
print("Reading Field Config file: Fields.jsn")

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

    print()
    
    for im_index in range(len(fld["images"])): 

        filename = fld["images"][im_index]["filename"]
        field_image_width_ft  = fld["images"][im_index]["xrange"]
        field_image_height_ft =field_image_width_ft/2
        zoom = crop_to_zoom[field_image_width_ft] 
    
        print(field_name, filename, latitude, longitude, field_image_width_ft, zoom)

        Gmaps = get_Gmaps_image(zoom, latitude, longitude, Gmap_API_Key)
    
        # note that in PIL the image.rotate operation rotates about the image center, not
        # the 0,0 point as was the case in Russell's original implementation so we have less
        # work to do (vs. translate, rotate, and then translate back)
    
        Gmaps_rotate = Gmaps.rotate(truedir-270)
    
        field_image_width_px =  Gmaps_px_per_foot(latitude, zoom) * field_image_width_ft
        field_image_height_px = Gmaps_px_per_foot(latitude, zoom) * field_image_height_ft
    
        wwGr, hhGr = Gmaps_rotate.size  # note the image size

        # clip the rotated image to the requested field image size. Also offset the position of 
        # the runway in the image to be 1/4 of the way up from the bottom since we stand to that 
        # narrower side when flying

        clip_box = (wwGr/2 - field_image_width_px / 2,
                    hhGr/2 - field_image_height_px * 3 / 4,
                    wwGr/2 + field_image_width_px / 2,
                    hhGr/2 + field_image_height_px / 4)


        Gmaps_rotate_crop = Gmaps_rotate.crop(clip_box)

        wwGrc, hhGrc = Gmaps_rotate_crop.size # note image size again...

        # now produce the transmitter-sized image

        Jeti = Gmaps_rotate_crop.resize( (320, 160) )

        # originally we put the yellow rectangle on the larger rotated image before cropping but
        # since it was a one pixel line (the width= option seems not to work), the vertical line
        # got lost when shrinking to 320x160, so we have to apply it instead to the final image
        # and thus adjust the pixel size of the runway accordingly (ugg)
        
        # create a drawing context for the rectangle
        
        dd = ImageDraw.Draw(Jeti)
        
        wwj, hhj = Jeti.size # note image size again... j/Grc ratio will adjust px per inch
        
        runway_length_px = runway_length_ft * Gmaps_px_per_foot(latitude, zoom) * wwj/wwGrc
        runway_width_px  = runway_width_ft  * Gmaps_px_per_foot(latitude, zoom) * hhj/hhGrc

        # draw the yellow rectangle for the runway to confirm registration
        
        dd.rectangle( ((int(wwj/2 - runway_length_px/2), int(3*hhj/4 - runway_width_px/2) ),
                       (int(wwj/2 + runway_length_px/2), int(3*hhj/4 + runway_width_px/2) )),
                      outline='yellow')

        lat, lon = 0,0 # reset from last time in case no POIs
        
        if fld.get("POI"): # loop over POIs if any exist
            for iP in range(len(fld["POI"])):
                
                lat = fld["POI"][iP]["lat"]
                lon = fld["POI"][iP]["long"]

                # first compute distance in original x,y frame (north up, in ft) from
                # POIs to center of runway ... then rotate POIs x,y coords same as image
                # use the simple equirectangular projection as in DFM-LSO.lua
                
                dx, dy = delta_xy_from_latlong(latitude, longitude, lat, lon)

                dxr, dyr = rotateXY(dx, dy, truedir-270) 

                # now adjust pixels per foot to current Jeti image
                
                dxr_px = dxr * Gmaps_px_per_foot(latitude, zoom) * wwj/wwGrc
                dyr_px = dyr * Gmaps_px_per_foot(latitude, zoom) * hhj/hhGrc
                
                # compute "absolute" screen coords in screen coord system
                
                dxr_px_abs = int(wwj / 2 - dxr_px)
                dyr_px_abs = int(hhj * 3 / 4 + dyr_px)

                # warn user of some POIs not visible in largest image of field
                
                if field_image_width_ft == 6000: # should not be 6000 but last item in crop_to_zoom dict
                    if dxr_px_abs < 0 or dxr_px_abs > wwj or dyr_px_abs < 0 or dyr_px_abs > hhj:
                        print("Warning: POI out of bounds at min zoom:", lat, lon, filename)
                          
                # mark POIs with a circle of 4x4 pixels on the image
                
                dd.ellipse( [(dxr_px_abs-2, dyr_px_abs-2), (dxr_px_abs+2, dyr_px_abs+2)],
                            fill="yellow")

        Jeti.save(filename, "PNG")












