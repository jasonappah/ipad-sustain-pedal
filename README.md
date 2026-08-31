# Digital Sustain

Digital Sustain turns my iPad into a large, hold-to-engage MIDI sustain pedal for a Mac. It sends MIDI channel 1 CC 64: 127 while held, then 0 when released.

https://github.com/user-attachments/assets/9432ef78-3735-4767-9851-20f544226b06

<p float="left" style="display: flex; align-items: flex-start; gap: 10px;">
<img width="472" height="328" alt="A screenshot of the app with showing a prompt directing users to the settings page" src="https://github.com/user-attachments/assets/0093cb86-3f47-4404-9bb7-e5da60a189f8" />
<img width="472" height="328" alt="A screenshot of the Settings UI" src="https://github.com/user-attachments/assets/5f9fa869-258d-4e28-bcab-36baddd6e74a" />
<img width="472" height="328" alt="A screenshot of the pedal in unpressed state" src="https://github.com/user-attachments/assets/72dfe4ba-cc63-4b6d-b7fc-58fec557d9ef" />
<img width="472" height="328" alt="A screenshot of the pedal in pressed state" src="https://github.com/user-attachments/assets/a7de9d08-fb1f-4c25-83d9-5c5b0ad90550" />
</p>


> This is a fully vibe-coded project, built with Codex. I've been away from home for a couple months, and I bought a used MIDI controller so I can still play keys a little bit, but I didn't buy a sustain pedal. I am doing exactly what you think I'm doing with this app. sorry if that was a visual you didn't want :p. Spiritual successor to [this thing](https://github.com/jasonappah/blink-sustain-pedal) which technically worked, but was so high latency that it was practically useless and also just functionally annoying to use. With the iPad version, even using RTP MIDI (MIDI over Wi-FI) is really great latency wise.

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
