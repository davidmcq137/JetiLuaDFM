#!/usr/bin/python3

import json
import os
import sys


#
# The availFile (see below) has a list of all the gauge images along with their properties.
#
# This script creates a separate config-imgs-xxx.json for each image file xxx
# and then runs a version of the Activelook config generator to create
# config-imgs-xxx.txt for each of them
#
# It invokes a hacked (sorry!) version of the Activelook config generator called
# configG.py that takes file names xxx from the command line
#
# 20-Jan-2024 McQ
# Updates:
# 25-Feb-2024 McQ New Json formats and file names, adding forms
#

availFile = "./Images/availInstrumentsMaster.jsn"

with open(availFile) as json_data:
	try:
		jd = json.load(json_data)
	except ValueError as valmsg:
		print("JSON decode error in " + availFile)
		print(valmsg)
		exit()

# delete any old images first

os.system("rm Images/small/*; rm Images/smaller/*; rm Images/Image*")
os.system("rm Configs/config-imgs-Image*")

# usage: python3 gaugeGen.py wid, hgt, x0, y0, rad, minA, maxA, maj, min, fine, labels, title, tx, ty, file
# usage: python3 hbarGen.py wid, hgt, x0, y0, barw, barh, maj, labels, title, tx, ty, file

# now loop over the instruments file and create all the required bmp images

imageID = 0
frm = jd["forms"]
for ins in jd["instruments"]:
	if ins["wtype"] == "gauge" or ins["wtype"] == "compass":
		imageID += 1
		formID = ins["formID"]
		ff = frm[formID]
		imgs = "./Images/Image{:02d}.bmp".format(imageID)
		print("Creating Image:", imgs, ins["wtype"], ff["descr"])
		options = str(ff["width"]) + " " + str(ff["height"]) + " "
		options = options + str(ff["x0"]) + " " + str(ff["y0"]) + " "
		options = options + str(ff["radius"]) + " " + str(ff["minA"]) + " "
		options = options + str(ff["maxA"]) + " " + str(ff["major"]) + " "
		options = options + str(ff["minor"]) + " " + str(ff["fine"]) + " "
		options = options + "'" + ins["ticlabels"] + "' "
		options = options + "'" + ins["label"] + "' "
		options = options + str(ff["xlbl"]) + " " + str(ff["ylbl"]) + " "
		options = options + imgs
		#print("gaugeGen.py options: ", options)
		os.system("set -e; python3 gaugeGen.py " + options)
	elif ins["wtype"] == "hbar":
		imageID += 1
		formID = ins["formID"]
		ff = frm[formID]
		imgs = "./Images/Image{:02d}.bmp".format(imageID)
		print("Creating Image:", imgs, ins["wtype"], ff["descr"])
		options = str(ff["width"]) + " " + str(ff["height"]) + " "
		options = options + str(ff["x0"]) + " " + str(ff["y0"]) + " "
		options = options + str(ff["barW"]) + " " + str(ff["barH"]) + " "
		options = options + str(ff["major"]) + " "
		options = options + "'" + ins["ticlabels"] + "' "
		options = options + "'" + ins["label"] + "' "
		options = options + str(ff["xlbl"]) + " " + str(ff["ylbl"]) + " "
		options = options + imgs
		#print("hbarGen.py options: ", options)
		os.system("set -e; python3 hbarGen.py " + options)

imageID = 0
for imgs in jd["instruments"]:
	#print("loop", imgs["wtype"])
	if imgs["wtype"] == "gauge" or imgs["wtype"] == "compass" or imgs["wtype"] == "hbar":
		imageID += 1
		name = "Image{:02d}.bmp".format(imageID)
		sname = "Image{:02d}".format(imageID)
		config = {"imgs": [{"id":imageID, "path":"./Images/" + name, "fmt":"mono_4bpp"}] }
		str = json.dumps(config)
		#print("dumps: " + str)
		with open("./Configs/config-imgs-" + sname + ".json", "w") as cf:
			try:
				json.dump(config, cf)
			except ValueError as valmsg:
				print("Could not open json file to write " + name)
				print(valmsg)
				exit()

		os.system("set -e; python3 configG.py " + "config-imgs-" + sname)
		oscmd = "set -e;mogrify -resize 90% -format png -path Images/small " + "Images/" + name
		os.system(oscmd)
		oscmd = "set -e;mogrify -resize 63% -format png -path Images/smaller " + "Images/" + name	
		os.system(oscmd)
		os.system("mv ./Images/small/" + sname + ".png " +
				  " ./Images/small/" + sname + "-small.png")
		os.system("mv ./Images/smaller/" + sname + ".png " +
				  " ./Images/smaller/" + sname + "-smaller.png")

			
os.system('set -e;cp -v Configs/config-*.txt ../Glass/Configs')
os.system('set -e;cp -v Images/small/*-small.png ../Glass/Images')
os.system('set -e;cp -v Images/smaller/*-smaller.png ../Glass/Images')
os.system('set -e;cp -v Images/availInstrumentsMaster.jsn ../Glass/Json/availInstruments.jsn')
os.system('set -e;cp -v Images/availFmtMaster.jsn ../Glass/Json/availFmt.jsn')

os.system('set -e;lua prepCI.lua')
os.system('set -e;cp -v Images/instruments.jsn ../Glass/Json')
os.system('set -e;cp -v Images/instr.jsn ../Glass/Json')
