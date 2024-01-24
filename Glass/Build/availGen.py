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

availFile = "./Images/availImgs.jsn"

with open(availFile) as json_data:
	try:
		jd = json.load(json_data)
	except ValueError as valmsg:
		print("JSON decode error in " + availFile)
		print(valmsg)
		exit()

for img in jd:
	fileid = img["id"]
	name = img["name"]
	config = {"imgs": [{"id":fileid, "path":"./Images/" + name + ".bmp", "fmt":"mono_4bpp"}] }
	str = json.dumps(config)
	#print("dumps: " + str)
	with open("./Configs/config-imgs-" + name + ".json", "w") as cf:
		try:
			json.dump(config, cf)
		except ValueError as valmsg:
			print("Could not open json file to write " + name)
			print(valmsg)
			exit()

	oscmd = "python3 configG.py " + "config-imgs-" + name
	#print("os cmd: " + oscmd)
	os.system(oscmd)

os.system('cp -v Configs/config-*.txt ../Configs')
os.system('cp -v Images/*-small.png ../Images')
		
	
	
	
 
	

