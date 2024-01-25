# MX Master Gesture Control

This gesture controller replaces the basic default functionality of Logi Options or Logi Options+ for the MX Master 3 mouse: Switching between virtual desktops and opening mission control with the thumb button.

## How It Works

This Swift app intercepts a custom mouse button (as remapped by Karabiner) and uses it for detecting gestures. It translates those gestures the standard Mission Control keyboard shortcuts for changing virtual desktops (Ctrl-LeftArrow/Ctrl-RightArrow).

All keyboard event handling is based on https://gist.github.com/BalazsGyarmati/e199080a9e47733870889626609d34c5

## Karabiner

[A custom Karabiner config](./karabiner.json) is used to intercept the key presses that pressing the gesture button on an unconfigured MX Master 3 sends: L-Cmd + Tab. It translates these to an unused mouse button press (button 27) so that the gesture control daemon has a clear signal.

The Karabiner config sends the forward and back buttons as L-Cmd + Left/Right Arrow, for broader application compatibility. In this repo they are reversed from the default, but that's easily swapped around. Handling these buttons is done in Karabiner as oppposed to the Swift binary so as to take advantage of Karabiner's device ID filtering, limiting potential for side effects on other devices.

## Build/Install

```bash
swiftc mxmaster_gesture_control/main.swift -o ~/.local/bin/mxmaster_gesture_control
```

## Start on login

```
cat << EOF >> ~/Library/LaunchAgents/mxmaster_gesture_control.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourname.mxmastergesturecontrol</string>
    <key>Program</key>
    <string>/Users/yourname/.local/bin/mxmaster_gesture_control</string>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load for the first time and accept the Accessibility prompt
launchctl load ~/Library/LaunchAgents/mxmaster_gesture_control.plist
```
