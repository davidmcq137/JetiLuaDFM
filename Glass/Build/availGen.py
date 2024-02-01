import json
import os
import sys

#
# availImgs.jsn has a list of all the gauge images along with their properties.
#
# this script creates a separate config-imgs-xxx.json for each image file xxx
# and then runs a version of the Activelook config generator to create
# config-imgs-xxx.txt for each of them
#
# it invokes a hacked (sorry!) version of the Activelook config generator called
# configG.py that takes file names xxx from the command line
#
# 20-Jan-2024 McQ
#

availFile = "./Images/availImgsMaster.jsn"

with open(availFile) as json_data:
	try:
		jd = json.load(json_data)
	except ValueError as valmsg:
		print("JSON decode error in " + availFile)
		print(valmsg)
		exit()

os.system("rm -v Images/small/*; rm -v Images/smaller/*")

for img in jd:
	fileid = img["widgetID"]
	name = img["BMPname"]
	if name != "":
		config = {"imgs": [{"id":fileid, "path":"./Images/" + name + ".bmp", "fmt":"mono_4bpp"}] }
		str = json.dumps(config)
		# print("dumps: " + str)
		with open("./Configs/config-imgs-" + name + ".json", "w") as cf:
			try:
				json.dump(config, cf)
			except ValueError as valmsg:
				print("Could not open json file to write " + name)
				print(valmsg)
				exit()

		os.system("set -e; python3 configG.py " + "config-imgs-" + name)
		oscmd = "set -e;mogrify -resize 90% -format png -path Images/small " + "Images/" + name + ".bmp"
		os.system(oscmd)
		oscmd = "set -e;mogrify -resize 63% -format png -path Images/smaller " + "Images/" + name + ".bmp"	
		os.system(oscmd)
		os.system("mv -v ./Images/small/" + name + ".png " +
				  " ./Images/small/" + name + "-small.png")
		os.system("mv -v ./Images/smaller/" + name + ".png " +
				  " ./Images/smaller/" + name + "-smaller.png")
	else:
		print("No BMP file for widget ",fileid)
		
	
os.system('set -e;cp -v Configs/config-*.txt ../Configs')
os.system('set -e;cp -v Images/small/*-small.png ../Images')
os.system('set -e;cp -v Images/smaller/*-smaller.png ../Images')
os.system('set -e;cp -v Images/availImgsMaster.jsn ../Json/availImgs.jsn')
