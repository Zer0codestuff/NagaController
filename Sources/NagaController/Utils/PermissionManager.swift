import Cocoa
import ApplicationServices

final class PermissionManager {
    static let shared = PermissionManager()
    private init() {}

    func ensureAccessibilityPermission() {
        guard !isProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // Registers the app in the Input Monitoring list; macOS shows its own prompt once.
    func ensureInputMonitoringPermission() {
        guard !hasInputMonitoringPermission() else { return }
        _ = CGRequestListenEventAccess()
    }

    func requestMissingPermissions() {
        ensureAccessibilityPermission()
        ensureInputMonitoringPermission()
    }

    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func hasAccessibilityPermission() -> Bool {
        isProcessTrusted()
    }

    func hasInputMonitoringPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return true
    }

    func openAccessibilityPreferences() {
        ensureAccessibilityPermission()
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringPreferences() {
        ensureInputMonitoringPermission()
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}
