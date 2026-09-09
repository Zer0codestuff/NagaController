import Cocoa
import Carbon.HIToolbox

struct SystemKeyStroke: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags

    var displayName: String {
        let modifiers: [(CGEventFlags, String)] = [
            (.maskControl, "ctrl"), (.maskAlternate, "alt"), (.maskShift, "shift"),
            (.maskCommand, "cmd"), (.maskSecondaryFn, "fn")
        ]
        let key = KeyboardKeyCatalog.current().first { $0.code == keyCode }
        return KeyStroke(key: key?.key ?? "", modifiers: modifiers.compactMap { flags.contains($0.0) ? $0.1 : nil },
                         keyCode: keyCode).formattedShortcut()
    }
}

struct MacSystemShortcut {
    let id: Int?
    private let fallback: SystemKeyStroke?

    init(id: Int? = nil, keyCode: Int? = nil, flags: CGEventFlags = []) {
        self.id = id
        fallback = keyCode.map { SystemKeyStroke(keyCode: CGKeyCode($0), flags: flags) }
    }

    func resolve(in preferences: [String: Any]) -> SystemKeyStroke? {
        guard let id, let entry = preferences[String(id)] else { return fallback }
        // Disabled or unassigned shortcuts must not fall back to an unrelated key combination.
        guard let entry = entry as? [String: Any], entry["enabled"] as? Bool == true,
              let value = entry["value"] as? [String: Any], value["type"] as? String == "standard",
              let parameters = value["parameters"] as? [Int], parameters.count == 3,
              (0..<128).contains(parameters[1]), parameters[2] >= 0 else { return nil }
        let flags = CGEventFlags(rawValue: UInt64(parameters[2]))
        let modifiers: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate, .maskSecondaryFn]
        return SystemKeyStroke(keyCode: CGKeyCode(parameters[1]), flags: flags.intersection(modifiers))
    }

    static func preferences() -> [String: Any] {
        UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys")?["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") else { return }
        NSWorkspace.shared.open(url)
    }
}
