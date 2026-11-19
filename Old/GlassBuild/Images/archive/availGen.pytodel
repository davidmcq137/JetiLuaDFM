import json
import os
import sys

availFile = "./Configs/availImgs.jsn"

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
	print("id, name", fileid, name)

	
