# Digital Sustain

Digital Sustain turns an iPad into a large, hold-to-engage MIDI sustain pedal for a Mac. It sends MIDI channel 1 CC 64: 127 while held, then 0 when released.

> This is a fully vibe-coded project, built with Codex.

## Connect it to your Mac

Choose one transport in your music app. Enabling more than one sends duplicate CC 64 events.

### USB (Inter-Device Audio and MIDI)

1. Connect the iPad to the Mac with USB.
2. In **Audio MIDI Setup → Audio Devices**, select the iPad and click **Enable** to enter Inter-Device Audio and MIDI mode.
3. In the music app, enable the **Digital Sustain USB** MIDI source.

### Bluetooth LE MIDI

1. Launch Digital Sustain and allow its Bluetooth permission.
2. On the Mac, choose **Audio MIDI Setup → MIDI Studio → Configure Bluetooth**.
3. Connect to **Digital Sustain**, then enable that MIDI source in the music app.

### Network MIDI

1. Put the iPad and Mac on the same trusted local network and launch Digital Sustain. Allow the local-network prompt.
2. In **Audio MIDI Setup → MIDI Studio → Network**, enable a Mac session and connect to the iPad session named in the app status pill.
3. Enable that network MIDI source in the music app.

## Physical-device check

Connect the iPad by USB, select it as the Xcode run destination, choose a signing team if Xcode asks, and run the `DigitalSustain` scheme. Then follow one connection path above and verify CC 64 values with a MIDI monitor or your host application.
