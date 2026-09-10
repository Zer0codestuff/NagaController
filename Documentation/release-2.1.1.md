# NagaController 2.1.1

Fixes Bluetooth detection. macOS shows the mouse over Bluetooth Low Energy as "Naga V2 HS" with identity `068e:00b5`; the app previously filtered only the receiver's vendor ID `1532` and excluded it. NagaController now enumerates the exact Bluetooth pair without touching unrelated devices, so the same saved profile applies over Bluetooth and the USB receiver. DPI, polling rate and driver mode still require the receiver.

Validation: release build and 745 automated checks passed, including 15 new identity and enumeration regression checks. Startup logs confirm `Naga connected via Bluetooth Low Energy` and an active blocking event tap. Saved profiles remained byte-identical across install and relaunch. Physical Bluetooth button actions still need user testing.

The DMG contains an Apple Silicon build for macOS 13 or later. It is ad-hoc signed and not notarized. Existing profiles are retained. Intel Macs can build from source.
