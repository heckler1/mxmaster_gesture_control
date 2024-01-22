# MX Master Gesture Control

This gesture controller replaces the basic default functionality of Logi Options or Logi Options+ for the MX Master 3 mouse: Switching between virtual desktops and opening mission control with the thumb button.

## How It Works

This Swift app intercepts a custom mouse button (as remapped by Karabiner) and uses it for detecting gestures. It translates those gestures to unused function key presses (F18/F19), where the standard mission control keyboard shortcuts for changing virtual desktops [have been remapped to those values](./remapped_keyboard_shortcuts.png).

Karabiner also remaps the standard shortcuts from all other devices to the F-key shortcuts, to retain stock-like behavior.

The F keys are just a shim, as the Swift key pressing events do not seem to correctly send Control modifiers for desktop switching. If the Control modifier could be properly applied, the system shortcuts could remain stock and much less Karabiner intervention would be required (essentially only the mouse button translation).

All keyboard event handling is based on https://gist.github.com/BalazsGyarmati/e199080a9e47733870889626609d34c5

## Karabiner

[A custom Karabiner config](./karabiner.json) is used to intercept the key presses that pressing the gesture button on an unconfigured MX Master 3 sends: L-Cmd + Tab. It translates these to an unused mouse button press (button 27) so that the gesture control daemon has a clear signal.

It also reinterprets the normal Mission Control keyboard shortcuts from other devices into the F18/F19 keys that the remapped keyboard shortcuts use.

Finally, the Karabiner config sends the forward and back buttons as L-Cmd + Left/Right Arrow, for broader application compatibility. In this repo they are reversed from the default, but that's easily swapped around.

## Build/Install

```bash
swiftc mxmaster_gesture_control/main.swift -o ~/.local/bin/mxmaster_gesture_control
```

## Start on login

As long as `~/.local/bin` is in your $PATH

```
cat << EOF >> ~/Library/LaunchAgents/mxmaster_gesture_control.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sheckler.mxmastergesturecontrol</string>
    <key>ProgramArguments</key>
    <array>
        <string>mxmaster_gesture_control</string>
    </array>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
```
