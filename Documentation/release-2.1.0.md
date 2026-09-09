# NagaController 2.1.0

The new Sistema editor replaces Audio with 25 system functions in six categories: audio (volume up/down, mute), playback (play/pause, previous/next track), brightness, screenshots (screen, selection, clipboard, recording tools), windows and spaces (Mission Control, app windows, desktop, previous/next space, hide app, app switcher) and tools (Spotlight, Finder, System Settings, Notification Center, Do Not Disturb). Each press runs the action once, with a Prova preview button. Existing audio mappings open in Sistema unchanged, and shell commands remain a separate action type.

This release also includes:

- A native light/dark interface with restrained green accents, interactive mouse photographs and separate side/top views.
- A keyboard picker with categories, modifiers, shortcut recording and editable sequences. Existing text assignments are preserved until replaced.
- Correct per-button hover outlines on the mouse photograph.
- Background remapping after closing the window, clearer permission/service status and hardware refresh after connection changes.

Notes:

- Screenshots, Mission Control, spaces and Do Not Disturb use the keyboard shortcuts configured in macOS. Disabled or unassigned shortcuts show setup instructions; Do Not Disturb needs an enabled shortcut in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.
- Brightness uses the Mac's brightness keys; external monitors must support macOS brightness control.

Validation: release build and 730 automated checks passed. Native volume and mute changes were verified through the running app and CoreAudio readback. USB DPI/polling read and same-value write/readback passed at 1600 DPI and 500 Hz. Physical remapping of the new system actions, Bluetooth and driver-mode transition tests remain pending.

The DMG contains an Apple Silicon build for macOS 13 or later. It is ad-hoc signed and not notarized. Existing profiles are retained. Intel Macs can build from source.
