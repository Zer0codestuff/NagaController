# NagaController

A macOS menu bar app for the Razer Naga V2 HyperSpeed. It remaps the 12 side buttons and the extra mouse controls, and reads or changes DPI and polling rate over the USB receiver. Fork of [DParent10/NagaController](https://github.com/DParent10/NagaController).

## Features

- Native settings window (SwiftUI) with three sections: Pulsanti, Sensibilità, Stato
- Physical 3x4 grid for side buttons 1 to 12, plus the two top DPI buttons, wheel tilt left/right, middle, left and right click (logical indices 13 to 19)
- Actions per button: keyboard shortcut (recorded or chosen from a preset list, with modifiers), multi-step key sequence, mouse action (browser back/forward, real mouse buttons 4/5, middle/left/right click, scroll), text snippet, launch application, shell command, macro, profile switch, disabled, or original passthrough
- Profiles with auto-save, import/export as JSON, rename/duplicate/delete
- DPI (100 to 30000 per axis) and polling rate (125/500/1000 Hz) read and written through the Razer USB protocol, with read-back verification
- Optional "driver mode" for the top DPI buttons, with journaled restore of the original mode at quit
- Menu bar popover with remapping toggle and battery level when available

## Requirements

- macOS 13.0 or later
- Razer Naga V2 HyperSpeed connected through its HyperSpeed USB receiver (`1532:00b4`) for DPI, polling rate and driver mode. Remapping also works over Bluetooth; hardware settings do not.
- Xcode Command Line Tools with Swift 5.9+ to build from source

## Install and first run

1. Download `NagaController-v2.0.0.dmg` from the [latest release](https://github.com/Zer0codestuff/NagaController/releases/latest), or build the app bundle (see below).
2. Open the DMG and drag `NagaController.app` to Applications. Permissions are tied to the app location, so do not move it afterwards.
3. The release is not notarized. On first launch right-click the app and choose Open, or run `xattr -dr com.apple.quarantine /Applications/NagaController.app`.
4. Launch it. macOS prompts for two permissions; both are required:
   - Accessibility (System Settings > Privacy & Security > Accessibility)
   - Input Monitoring (System Settings > Privacy & Security > Input Monitoring)
5. Open the settings window from the menu bar icon, turn on "Rimappatura", and assign actions.

The Stato section shows the current permission state, the detected device, and the last input seen. If a permission was granted after launch, macOS may require restarting the app.

## Build from source

```bash
bash Scripts/build_app.sh        # release build, ad-hoc signed, writes ./NagaController.app
open NagaController.app
```

Without a signing identity the bundle is ad-hoc signed and macOS forgets its permissions on every rebuild. For development, create a local self-signed identity once:

```bash
bash Scripts/make_dev_certificate.sh   # creates "NagaController Dev" in the login keychain
```

`build_app.sh` picks it up automatically. Set `SIGNING_IDENTITY="Developer ID Application: ..."` to use a real identity instead. Builds are not notarized.

To produce the distributable disk image (ad-hoc signed, with an Applications shortcut):

```bash
bash Scripts/make_dmg.sh              # writes NagaController-v<version>.dmg
```

## Tests and diagnostics

```bash
bash Scripts/test.sh             # dependency-free checks, no XCTest needed
```

Read-only hardware diagnostics (requires Input Monitoring for the launching process):

```bash
open NagaController.app --args --diagnose-file /tmp/naga.json
cat /tmp/naga.json
```

Add `--verify-hardware` to also write back the current DPI and polling values and confirm the read-back. Values are not changed.

Add `--snapshot /tmp/ui.png` to render the settings window to a PNG without touching the hardware.

## How input handling works

- `HIDListener` observes only Razer devices whose product ID is `0x00b4` or whose name contains "naga", on a background run loop.
- Each physical press/release is recorded with its timestamp. `EventTapManager` consumes a matching system event only if it arrives within 25 ms of a recorded HID edge, so regular keyboards are never blocked.
- Synthetic events are tagged through `eventSourceUserData` and ignored by the tap.
- Held buttons are released on stop, disconnect, profile change, or when the tap is disabled by the system.
- Buttons 13 to 16 (DPI, wheel tilt) rely on documented driver-mode reports and are only reported when a matching report is observed.

## Project structure

- `Sources/NagaController/ButtonMapping/` action model, event synthesis, layout-aware browser shortcuts
- `Sources/NagaController/EventTap/` CGEvent tap and correlation with HID input
- `Sources/NagaController/HID/` IOHID listener and pure report decoding
- `Sources/NagaController/Hardware/` Razer USB protocol codec, IOHID feature-report transport, device controller
- `Sources/NagaController/UI/` SwiftUI settings window and menu bar popover
- `Sources/NagaController/Utils/` profiles storage, permissions, battery monitor
- `Tests/` dependency-free test sources run by `Scripts/test.sh`
- `Resources/` Info.plist and bundled default profiles

## Credits and license

Protocol facts come from the published OpenRazer sources and pull request 2850; no GPL code is included. Licensed under MIT, see [LICENSE](LICENSE).
