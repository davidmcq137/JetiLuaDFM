To have the V-SensXF app make an audio announcement that tracks a Result, use
   the __+__ key to create a new line in the Announcement menu and select one of
   the Results which must have been previously defined from the main Result
   Expressions menu. You must also select an announcement type. The __Reset__ button
   will delete all the announcements.

There are three types of announcements: __Periodic__, __Automatic__ and __Edge__. Once you
   select the type on the Announcements menu, press __Edit__ to edit the
   details. Each of the three types has slightly different detail screens.

All of the announcement type detail menus have a line to set the enable switch
    which enables or disables all announcements for this Result. It is set in
    the usual Jeti way.

Each Result type can also specify a custom audio file to be spoken as part of the
    announcements. These are wav files and are in a language-specific
    directory. For English, it is Apps/V-SensXF/Audio/en - other languages will
    have subdirectories named with their two letter localization code.

There are several wav files already included and you are free to add your
    own. You can also create new directories for other languages. We recommend
    creating the wav files with the TTS system at rc-thoughts.com. Many thanks
    to Tero for his support to our community! The app reads the
    language-specific audio directory at startup and will present in the menu
    all of the files it finds.

If a custom wav file is not selected, the app will announce generically, for
   example Result 1.

__Periodic__ announcements require the time between announcements in seconds. The
	 default value is 10. You can also specify decimal places and units for
	 the announcement.

__Automatic__ announcements are spaced in time according to how quickly the
	  value of the result is changing. You set the minimum interval for when
	  the Result is changing rapidly, and a maxiumum interval when the
	  Result is not changing. Announcements will never be closer in time
	  than the minimum setting, nor will the be further apart than the
	  maximum. You also set a change scale factor, which is approximately
	  how much the Result has to change to make a new announcement. This
	  will depend on the range of values of Result. For example if the
	  Result is airspeed in km/h, a value of 10 or 20 might be
	  appropriate.You can vary the scale factor to make the announcements
	  more or less chatty.

__Edge__ annoumcments are triggered when the value of the Result goes from 0 to
     1 (rising edge) or 1 to 0 (falling edge). It is intended for Results which
     are logical values of 0 or 1, but can be used for any value of Result. The
     actual threshold is 0.5 as you might expect. This type of announcement is
     particularly useful on conjunction with the nfi, nfo, box or step
     functions. You can also set up stick shakers on the edge transitions for
     the left or right stick and with several shake patters. The stick shaker is
     not supported on all transmitters.

