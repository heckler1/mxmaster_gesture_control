# MX Master Gesture Control

This Swift app intercepts a custom mouse button as remapped by Karabiner, and uses it for detecting gestures. It translates those gestures to unused function key presses (f17-f19), where the standard mission control keyboard shortcuts have been remapped to those values. 

Karabiner also remaps the standard shortcuts to the F-key shortcuts to retain stocklike behavior

The F keys are just a shim, as the swift key presser did not seem to correctly send Control modifiers for desktop switching. If the Control modifier could be properly applied, the system shortcuts could remain stock and much less Karabiner intervention would be required.

All keyboard event handling is based on https://gist.github.com/BalazsGyarmati/e199080a9e47733870889626609d34c5


## Build/Install

``` bash
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