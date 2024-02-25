How to add new instruments/widgets:

Edit the file Glass/Build/Images/avialInstrumentsMaster.jsn.

If a new gauge "form" (basic image property) is required, add that to the forms
object. This is only necessary if a new gauge type is added.

Then add a new array element to the instruments object referring to the proper
formID in the form object. Many instruments can refer to the same formIDs.

Then go to the Glass/Build directory and run availGen.py which will read
configInstrumentsMaster.jsn ... first it will create all the required bmp file
images using either gaugeGen.py or hbarGen.py.

Then, once the bmp files exist, it will create the individual json "snippets" to
feed to the slightly modified version of the AL config generator (configG.py)
which will then create the config-imgs-xxx.txt file that corresponds to that
snippets for the images.

The Activelook id will be assigned automatically in the order of the array in
the instruments object. IDs of 0 will be assigned to instruments that do not
require an image. The script will also generate the two derived png files needed
by the app.

After creating all the .txt fragment files for the images, the script will copy
a working version of the file availInstrumentsMaster.jsn to the Glass/Json directory
as availInstruments.jsn. It will also copy the png files to Glass/Images/ and the AL
image .txt fragment files to Glass/Configs.


