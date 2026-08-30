# Digital Sustain

Digital Sustain turns an iPad into a large, hold-to-engage MIDI sustain pedal for a Mac.

## Connect it to your Mac

1. Put the iPad and Mac on the same trusted local network.
2. Launch Digital Sustain on the iPad and allow the local-network prompt.
3. On the Mac, open **Audio MIDI Setup** and choose **Window > Show MIDI Studio**.
4. Open **Network**, enable the Mac session if needed, then connect to the iPad session whose name appears in the app's status pill.
5. Select that network MIDI source in your music app or MIDI monitor.
6. Hold the iPad pedal. The Mac should receive MIDI channel 1 CC 64 with value 127; releasing it sends value 0.

The app uses Apple's MIDI Network Session. The USB cable is for installing and debugging the app; it is not a general USB-MIDI connection from a normal iPad app to macOS.

## Physical-device check

Connect the iPad by USB, select it as the Xcode run destination, choose a signing team if Xcode asks, and run the `DigitalSustain` scheme. Then follow the connection steps above and verify CC 64 values with a MIDI monitor or your host application.
