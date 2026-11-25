# Notification Center regression checks

Run `bash script/test-menu-bar-concealer.sh` on macOS. It compiles the production
concealer against test doubles for preferences, app state and the system backend.
It checks suspension, updates while suspended, restoration of the current layout,
an activation completing after suspension, and quitting during suspension.

The macOS 27 integration check requires a real mouse click: `AXPress` alone does
not deliver the mouse event watched by Ice. With items hidden, click the system
clock once. Notification Center should open and remain usable. Close it by
clicking outside, pressing Escape or clicking the clock again; hidden items
should disappear again. Repeat with an empty notification list and with desktop
widgets enabled. Modifier-clicks on the clock must retain their system behavior.

The compatibility fix temporarily releases Ice's assessment assertion while the
notification panel is open, so hidden icons are temporarily visible. It does not
change saved layout or permissions, restart Notification Center, or bypass other
applications' system restrictions. It is a clock-click fix, not a replacement for
the assessment backend's other macOS limitations.

For local updates, retain the installed bundle ID, path, signing certificate and
entitlements. Never reset TCC as part of these checks.

## macOS 27 divider spacing

With both sections enabled and collapsed, the hidden and always-hidden dividers
must have no menu bar slot. Check again after opening and closing Notification
Center, switching input sources, and switching Spaces: system relayout must not
restore padding for an invisible divider. The Ice icon and section hotkeys must
still reveal their sections. With section dividers enabled, revealing a section
should attach its chevron; collapsing it should remove that slot again. Disabling
the always-hidden section must also disable its hotkey, even if its divider was
already detached. Re-enabling it must restore section behavior without a blank
slot. Older macOS versions retain the physical-divider implementation.
