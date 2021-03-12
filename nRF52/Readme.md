# BLE/UART bridge
This is code based (well mostly just lifted completly and modified slightly) on an example included in the NRF5 SDK.  It has been modified to handle two way communcation to a GPS (though not restricted to being used with a GPS - It just in in our case).

Compiled and tested against the nRF5 SDK version 160098a08e2

Compiled with the free version of the SEGGER Embedded Studio for Arm v4.52b.

You will need to edit the DIYDrag.emProject file and update the path to the nRF SDK for your install.  Change all references to the path "/Users/chris/Documents/nRF5SDK160098a08e2" to what ever it is on your system.

Download link for SDK can be found here:
https://www.nordicsemi.com/-/media/Software-and-other-downloads/SDKs/nRF5/Binaries/nRF5SDK160098a08e2.zip

There is an updated SDK (17.0.2) available from nordic semi, but direct replacement breaks the build, and will require troubleshooting. 