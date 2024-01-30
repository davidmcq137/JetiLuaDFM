How to add new widgets:

If the new widget has an image that will be displayed on the glasses, create the
image in a bmp file.

Edit the file Glass/Build/Images/avialImgsMaster.jsn.

Add a new array element as required. The "ALid" field is the Activelook id
number that will be used for the image if the entry has one. Set the "BMPfile"
field to the filename of the bmp file. Enter all the relevant info for the
image.

If the ALid field is 0, then it is assumed that the ESP will draw the widget
"manually" with no image (e.g. the text/data widget with widget type "wytpe" of
"htext") and no config-imgs-xxx.txt file will be created.

Then go to the Glass/Build directory and run availGen.py which will read
configImgsMaster.jsn to create the individual json "snippets" to feed to the
slightly modified version of the AL config generator (configG.py) and then
create the config-imgs-xxx.txt file that corresponds to that snipped for the
image .. the Activelook id will be ALid. The script will also generate the two
derived png files needed by the app.

After creating all the .txt fragment files for the images, the script will copy
a working version of the file availImagesMaster.jsn to the Glass/Json directory
as availImgs.jsn. It will also copy the png files to Glass/Images/ and the AL
image .txt fragment files to Glass/Configs.


