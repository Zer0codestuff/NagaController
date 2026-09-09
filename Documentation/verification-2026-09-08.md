# UI and background verification

Verification began on the local update based on 2.0.0 and continued for the 2.1.0 release.

## Automated checks

- `bash Scripts/build_app.sh`: release build and strict code-signature verification pass with the existing NagaController Dev identity.
- `bash Scripts/test.sh`: 369 checks pass on the active keyboard layout. These cover the input engine, USB protocol, every key-picker entry's physical key-down and key-up, modifier flags, profile round trips, existing text assignments, and side-photo target coverage.
- `git diff --check`: pass.
- PNG alpha verified. The 1024 x 1536 mouse image preserves RGB values in its opaque foreground.

## Running app

Verified through macOS accessibility controls and native screenshots:

- Selecting a side button on the photo selects the matching assignment and inspector.
- A key chosen from Tasti saves immediately. Adding Command updates the saved chord.
- Recording Tab assigns Tab and ends recording without moving focus.
- Adding a second sequence step and changing it retains the first step.
- Top-view controls select the matching DPI, click or wheel-tilt assignment.
- Both existing permissions are reported as granted. The event tap reports In esecuzione.
- Closing the window leaves the same process running. After more than one minute, sampled CPU usage was 0.0% and resident memory was about 131 MiB without a mouse connected. These are idle samples, not a load benchmark.
- Returning to the app still reports the input service running.
- A temporary UI Verification profile was deleted after the test. Parsed profile JSON and settings match the pre-test backup exactly.
- Snapshots checked at 1180 x 820 in light appearance and 980 x 700 in dark appearance. All 12 side assignments remain reachable; the inspector scrolls at smaller heights.

## USB verification on September 9

The user connected the USB receiver. Read-only diagnosis and same-value write/readback verification succeeded through the installed app, with both privacy permissions granted. Receiver `1532:00b4` reported 1600 DPI on both axes, 500 Hz, battery 100%, mode 0 and no warnings. Both `dpiWriteReadbackVerified` and `pollingWriteReadbackVerified` were true.

A stale hardware panel after hotplug was reproduced. AppDelegate now observes HID connection name/transport changes, coalesces them for 400 ms and waits for a busy hardware controller before issuing a read-only refresh. Button activity does not cause refreshes. Build and all 369 checks pass after this fix. The installed app showed 1600/1600 DPI and 500 Hz after relaunch. Physical unplug/replug remains pending.

The app found a recovery journal from a previous session for the attached receiver, with original mode 0. The explicit Restore original mode command succeeded and removed the journal. The receiver was already in mode 0, so this verified recovery cleanup, not a driver-to-normal transition.

Real remapped output, release timing on-device, Bluetooth recognition, wheel tilt and driver-mode restore still require testing. Background process and service checks alone do not establish end-to-end hardware behavior.

The existing protocol fixtures are not physical-device captures. Do not present them as on-device verification.

## Side-photo hover fix

The full-image frames of the twelve individual hover handlers overlapped, so button 12 won pointer tracking. A single continuous hover handler now resolves the pointer against the actual polygons, with centered-image coordinate conversion. Release build and 395 checks pass, including 26 new geometry checks. In the installed app, pointer checks highlighted buttons 5 and 3 independently and removed the white outline over the mouse body. The selected button kept its green highlight.

## Audio verification for 2.1.0

Release build and 425 checks pass. Thirty new checks cover all three audio actions, paired system event encoding, synthetic markers, duplicate press suppression, subsequent presses and profile persistence.

In the installed app, the Audio inspector saved all three choices and the Prova button exercised the same output function used by ButtonMapper. CoreAudio readback showed volume 0.503937 to 0.5625 after volume up, then 0.5 after volume down. Mute changed from 0 to 1 and back to 0 without changing that volume. No sound was played for the test. The temporary Audio Verification profile was deleted; parsed profile JSON matched the pre-test backup exactly.

The native audio UI was visually checked. Physical mouse-to-volume output remains part of the pending on-device remapping checks. The release DMG targets Apple Silicon and is ad-hoc signed, not notarized. The installed development-signed copy retains its existing permission identity.
