# AGENTS.md

## Purpose

macOS menu bar app (Swift, AppKit + SwiftUI, no Xcode project) that remaps the buttons of the Razer Naga V2 HyperSpeed and controls DPI / polling rate over the USB receiver `1532:00b4`. Fork of DParent10/NagaController, remote `origin` is `Zer0codestuff/NagaController`, `upstream` is the original.

## Architecture

- `Sources/NagaController/main.swift`: CLI switches (`--diagnose`, `--diagnose-file <path>`, `--verify-hardware`, `--snapshot <png>`), otherwise starts `AppDelegate`.
- `AppDelegate`: starts `HIDListener`, `RazerDeviceController.refresh()`, the event tap (only when Accessibility and Input Monitoring are granted), a 2 s permission poll, menu bar item and popover; defers quit until `restoreOriginalMode` completes.
- `ButtonMapping/`: `ActionType` (system, legacy audio, mouse, disabled, keySequence, application, systemCommand, textSnippet, macro, profileSwitch), `ButtonMapper` (press/hold/release semantics, synthetic marker `eventSourceUserData`), `KeyboardLayoutShortcut` (browser back/forward per layout). `SystemAction` groups native system controls; `MacSystemShortcut` reads configured macOS shortcuts without changing preferences.
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
bash Scripts/test.sh             # 730 dependency-free checks (XCTest is not available with CLI tools only)
bash Scripts/make_dmg.sh         # ad-hoc signed release DMG (NagaController-v<version>.dmg, git-ignored)
gh release create vX.Y.Z NagaController-vX.Y.Z.dmg --title "NagaController X.Y.Z" --notes-file <file>   # publish
open NagaController.app --args --diagnose-file /tmp/naga.json   # read-only hardware probe
./NagaController.app/Contents/MacOS/NagaController --snapshot /tmp/ui.png  # UI render without hardware
```

`Package.swift` also declares a `TapTester` executable and an XCTest target (`Tests/NagaControllerTests`) that cannot run without Xcode.

## Current status (2026-09-09)

- Version 2.1.0, build 4, includes the Sistema editor alongside the native UI, keyboard picker and background/hotplug fixes. Published as GitHub release v2.1.0 with `NagaController-v2.1.0.dmg` (Apple Silicon, ad-hoc signed, not notarized). Installed in `/Applications/NagaController.app` with the existing development signing identity. Debug/release builds and 730 dependency-free checks pass.
- Sistema checked in isolated light/dark snapshots at 980 x 700, plus the missing-shortcut state at 1180 x 780. Live UI automation was blocked by the terminal's Accessibility permission. The installed executable matches the release build, and the user profile JSON remained byte-identical after snapshots and relaunch.
- Earlier UI checks covered native light/dark appearance, background process survival and the active event tap. On September 9, USB receiver read and same-value write/readback passed: 1600 DPI on both axes, 500 Hz, battery 100%, normal mode 0, no warnings. Physical remapping and driver-mode restore still require user testing.
- `--diagnose` run from a terminal fails with `0xe00002e2` (kIOReturnNotPermitted): the launching process needs Input Monitoring. Use `open -n NagaController.app --args --diagnose-file <path>` instead.
- Worktrees `../naga-worktree-{input,ui,hardware}` on branches `work/*` hold the sub-agent originals; they are fully merged and can be removed with `git worktree remove`.

## Recent changes

- Sistema replaces the Audio editor with 25 functions in six categories: audio, playback, brightness, screenshots, windows/spaces, and tools. Tools include Spotlight, Finder, System Settings, Notification Center and Do Not Disturb. Selection saves immediately; Prova runs the selected function. Shell commands remain separate.
- System actions run once per physical press. Media events use tagged down/up pairs; keyboard actions honor configured macOS shortcuts, and app switching explicitly releases Command. Disabled/unassigned shortcuts show setup guidance. Spotlight opens directly because its keyboard shortcut may be disabled.
- Legacy `audio` JSON remains readable and is not migrated on load. Its earlier volume and mute implementation was tested live before this change. `Tests/SystemActionTests.swift` adds 305 checks for the catalog, event encoding, press/release behavior, shortcut overrides, legacy preservation and mixed-profile import/export.
- Sistema snapshots use `CFFIXED_USER_HOME` with synthetic profiles under `.build/system-ui-home`, without starting hardware/input services or changing real profiles. The pre-update installed bundle is preserved at `.build/system-install.TDzXAb/NagaController.app`.

- Fixed side-photo hover always highlighting button 12. One continuous pointer tracker resolves the cursor against the actual button polygons, accounting for image centering and scaling. Live checks covered buttons 3 and 5 and the empty mouse body; 26 regression checks cover all 12 targets at two sizes.

- `Tasti` replaces the text editor with `KeyboardKeyCatalog` and `KeyboardKeySelector`, physical key codes, current-layout labels, modifiers and local shortcut recording. Existing text actions remain unchanged until replaced by the user. Multi-step sequences remain editable.
- `WorkspaceModel`, `MouseWorkspace` and adaptive `UIStyle` provide a native sidebar, a mouse photo with 12 polygon targets, top controls, and a separate assignment inspector. PNG assets with real alpha and provenance are in `Resources/Mouse/`.
- Closing the window retains the menu-bar service. A scoped ProcessInfo activity prevents App Nap while remapping is active and still permits system sleep. Permission and active-service states are shown separately.
- A previous-session recovery journal was cleared through the explicit restore command on September 9. The receiver was already in normal mode 0, so a driver-to-normal transition remains unverified.
- Hardware state refreshes after HID connection name or transport changes. Refreshes are debounced and wait for active hardware operations; button events do not trigger USB reads. Physical unplug/replug validation is pending.
- Verification details and light/dark screenshots are in `Documentation/verification-2026-09-08.md`. Profiles were restored after temporary UI tests.

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

The user runs `/Applications/NagaController.app` (2.1.0, bundle id `com.zer0codestuff.NagaController`). The old upstream 0.1.0 (`com.example.NagaController`) was removed from `/Applications` together with its Accessibility and Input Monitoring grants and its UserDefaults. After a rebuild, copy `./NagaController.app` over `/Applications/NagaController.app` and relaunch.

## Preferences and constraints

- User-facing strings in Italian; code, comments, docs, commit messages in English.
- Native macOS light/dark appearance with restrained Razer green accents. Preserve transparent PNG alpha and the interactive mouse photo.
- No em dashes anywhere.
- MIT only: protocol knowledge from OpenRazer docs / PR 2850, no GPL code copied; OpenMouse is unlicensed, do not copy.
- Never change hardware settings on init or refresh; driver mode only through the explicit toggle, always journaled and restored.
- Do not claim signing or notarization that does not exist.

## Known issues / next steps

- Pending on-device verification: side button remap and release timing, browser back/forward, button 4/5, wheel tilt, driver mode toggle and restore, USB unplug/replug. Bluetooth has not been tested.
- New system actions still need live testing with the mouse. Do Not Disturb has no assigned shortcut on this Mac; the inspector links to keyboard settings for setup. Brightness depends on display support for macOS brightness keys, and media keys depend on the playback app.
- `onChange(of:perform:)` deprecation warnings remain because the deployment target is macOS 13.
- `Resources/default-profiles.json` still ships English descriptions ("Copy", "Paste") in the Default profile.
- `SETUP-INSTRUCTIONS.md` and `dmg-assets/` describe the upstream author's signing identity and create-dmg flow; not used by this fork (see `Scripts/make_dmg.sh`).

## Do not

- Do not commit or push without an explicit request.
- Do not open the receiver with IOUSBHost exclusive access (conflicts with the system HID driver).
- Do not reintroduce the legacy neon card UI or global keyboard interception outside explicit shortcut recording.
- Do not add permanent stub models for UI compilation.
- Do not change macOS keyboard shortcuts automatically. Lock, sleep, shutdown and restart are outside the agreed Sistema catalog.
