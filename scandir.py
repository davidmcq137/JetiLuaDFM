#!/usr/bin/python3


# python(3!) helper program .. put it in the Log/ directory of the Jeti emulator
# it creates the files that the dir iterator uses to run on the emulator
# one file of dir names in Log/ and one file in each log dir with the files in that dir

import os
 
folders = []
files = []
 
for entry in os.scandir('.'):
    if entry.is_dir():
        s = entry.path[2:]
        folders.append(s)
print('Folders:')
print(folders)

with open("LogDirs.out", "w") as ld:
    for f in folders:
       ld.write(f+'\n')
 

for f in folders:
    print("Folder", f)
    files = []
    for entry in os.scandir(f):
    	if entry.is_file():
           files.append(entry.name)
    print('Files in', f)
    print (files)

    print(f+"/Logfiles.out")
	   					
    with open("./"+f+"/LogFiles.out", "w") as fd:
        for n in files:
            if n != "LogFiles.out":
                pn = "./"+f+"/"+n
                statinfo=os.stat(pn)
                print ("+", pn, statinfo.st_size)
                fd.write(n+" "+str(statinfo.st_size)+'\n')
            

