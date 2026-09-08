# AGENTS.md

## Purpose

macOS menu bar app (Swift, AppKit + SwiftUI, no Xcode project) that remaps the buttons of the Razer Naga V2 HyperSpeed and controls DPI / polling rate over the USB receiver `1532:00b4`. Fork of DParent10/NagaController, remote `origin` is `Zer0codestuff/NagaController`, `upstream` is the original.

## Architecture

- `Sources/NagaController/main.swift`: CLI switches (`--diagnose`, `--diagnose-file <path>`, `--verify-hardware`, `--snapshot <png>`), otherwise starts `AppDelegate`.
- `AppDelegate`: starts `HIDListener`, `RazerDeviceController.refresh()`, the event tap (only when Accessibility and Input Monitoring are granted), a 2 s permission poll, menu bar item and popover; defers quit until `restoreOriginalMode` completes.
- `ButtonMapping/`: `ActionType` (mouse, disabled, keySequence, application, systemCommand, textSnippet, macro, profileSwitch), `ButtonMapper` (press/hold/release semantics, synthetic marker `eventSourceUserData`), `KeyboardLayoutShortcut` (browser back/forward per layout).
- `EventTap/EventTapManager`: CGEvent tap; consumes an event only if `HIDListener.consume` matches a HID edge within 25 ms. Logical indices: 1..12 side grid, 13 DPI up, 14 DPI down, 15 wheel left, 16 wheel right, 17 middle, 18 left, 19 right.
- `HID/HIDListener` + `HID/InputModel`: IOHIDManager on a dedicated thread, pure decoders (`NagaInput`, `InputEdgeMatcher`, `DriverButtonState`).
- `Hardware/`: `RazerProtocol` (90-byte report codec, CRC, transaction IDs), `MacRazerUSBTransport` (IOHID feature reports on the mouse collection with 90-byte feature size), `RazerDeviceController` (`@MainActor` facade, serial worker queue, driver-mode recovery journal in `~/Library/Application Support/NagaController/driver-mode-recovery.json`).
- `UI/`: `MappingViewController` (NSHostingController with `NagaWorkspace`), `ActionInspector`, `SettingsPanes` (Sensitivity, Status, ProfileManager), `MainViewController` (popover), `MappingWindowController`.
- `Utils/ConfigManager`: profiles JSON, auto-save, `didChangeNotification`, `lastError`.

## Build, run, test

```bash
swift build                      # debug
bash Scripts/make_dev_certificate.sh   # once: self-signed "NagaController Dev" identity, keeps TCC grants across rebuilds
bash Scripts/build_app.sh        # release bundle ./NagaController.app, signed with the dev identity if present, else ad-hoc
bash Scripts/test.sh             # 164 dependency-free checks (XCTest is not available with CLI tools only)
bash Scripts/make_dmg.sh         # ad-hoc signed release DMG (NagaController-v<version>.dmg, git-ignored)
gh release create vX.Y.Z NagaController-vX.Y.Z.dmg --title "NagaController X.Y.Z" --notes-file <file>   # publish
open NagaController.app --args --diagnose-file /tmp/naga.json   # read-only hardware probe
./NagaController.app/Contents/MacOS/NagaController --snapshot /tmp/ui.png  # UI render without hardware
```

`Package.swift` also declares a `TapTester` executable and an XCTest target (`Tests/NagaControllerTests`) that cannot run without Xcode.

## Current status (2026-09-08)

- Multi-agent rewrite (UI, input engine, hardware protocol) integrated into the main checkout. Build and `Scripts/test.sh` (164 checks) pass. Committed and pushed to `origin/main` as 2.0.0.
- UI verified by snapshot. Hardware DPI/polling read and write-back verified on the real receiver. Still unverified on device: mode read fallback (0x1f), driver mode toggle and restore, side button remapping and wheel tilt in daily use.
- `--diagnose` run from a terminal fails with `0xe00002e2` (kIOReturnNotPermitted): the launching process needs Input Monitoring. Use `open -n NagaController.app --args --diagnose-file <path>` instead.
- Worktrees `../naga-worktree-{input,ui,hardware}` on branches `work/*` hold the sub-agent originals; they are fully merged and can be removed with `git worktree remove`.

## Recent changes

- Mouse actions `button4`/`button5`: when the frontmost app is a browser (`MouseAction.browserBundlePrefixes`) they are converted to `browserBack`/`browserForward`, because Safari and Chrome on macOS ignore mouse buttons 4/5. Real clicks are still sent elsewhere. `ButtonMapper.frontmostBundleIdentifier` is injectable for tests.
- `KeyboardLayoutShortcut.browserStroke`: brackets are used only when reachable without Option; otherwise ⌘← / ⌘→ (the user's layout is "Italian - Pro", where `[` needs Option).
- Version bumped to 2.0.0 (`CFBundleVersion` 3). GitHub release v2.0.0 published with `NagaController-v2.0.0.dmg` built by `Scripts/make_dmg.sh`. The stale tracked `NagaController-v0.1.0.dmg` was removed from git; root DMGs are now ignored.

- Deleted emptied legacy UI files (`ActionEditorViewController`, `GlassyBatteryView`, `MouseMappingView`).
- `PermissionManager`: added `ensureInputMonitoringPermission()` and `requestMissingPermissions()`; the app now requests both permissions at launch and before opening the corresponding System Settings pane, so it appears in the Privacy lists.
- `RazerHardwareSession.readMode()`: retries the mode query with transaction 0x1f when the OpenRazer 0xff variant returns status 4 (timeout), which is what this receiver did during on-device probes.
- `Scripts/make_dev_certificate.sh` added; `build_app.sh` auto-selects the "NagaController Dev" identity. Ad-hoc builds lost Accessibility and Input Monitoring after every rebuild (designated requirement was the cdhash).
- On-device verification with `--diagnose --verify-hardware`: DPI 1600/1600 and polling 500 Hz read, written back and re-read successfully; battery 100%.
- README rewritten for 2.0.0.

## Installed copy

The user runs `/Applications/NagaController.app` (2.0.0, bundle id `com.zer0codestuff.NagaController`). The old upstream 0.1.0 (`com.example.NagaController`) was removed from `/Applications` together with its Accessibility and Input Monitoring grants and its UserDefaults. After a rebuild, copy `./NagaController.app` over `/Applications/NagaController.app` and relaunch.

## Preferences and constraints

- User-facing strings in Italian; code, comments, docs, commit messages in English.
- No em dashes anywhere.
- MIT only: protocol knowledge from OpenRazer docs / PR 2850, no GPL code copied; OpenMouse is unlicensed, do not copy.
- Never change hardware settings on init or refresh; driver mode only through the explicit toggle, always journaled and restored.
- Do not claim signing or notarization that does not exist.

## Known issues / next steps

- On-device verification of: side button remap, browser back/forward, button 4/5, wheel tilt, DPI and polling write-back, driver mode toggle and restore.
- Two `onChange(of:perform:)` deprecation warnings remain because the deployment target is macOS 13.
- `Resources/default-profiles.json` still ships English descriptions ("Copy", "Paste") in the Default profile.
- `SETUP-INSTRUCTIONS.md` and `dmg-assets/` describe the upstream author's signing identity and create-dmg flow; not used by this fork (see `Scripts/make_dmg.sh`).

## Do not

- Do not commit or push without an explicit request.
- Do not open the receiver with IOUSBHost exclusive access (conflicts with the system HID driver).
- Do not reintroduce the legacy neon card UI or global keyboard interception outside explicit shortcut recording.
- Do not add permanent stub models for UI compilation.
