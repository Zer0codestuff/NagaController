import Cocoa
import Carbon.HIToolbox

enum KeyboardLayoutShortcut {
    /// Resolve the character, not the ANSI physical bracket position. Layouts
    /// that need Option for brackets (Italian, German) get Command + arrow
    /// instead: not every browser matches ⌘[ through an Option chord, while
    /// Safari, Chrome, Firefox and Edge all navigate with ⌘← and ⌘→.
    static func browserStroke(for action: MouseAction) -> KeyStroke? {
        let wanted = action == .browserBack ? "[" : "]"
        guard action == .browserBack || action == .browserForward else { return nil }
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
           let stroke = bracketStroke(wanted, layoutData: Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()) {
            return stroke
        }
        let arrow = action == .browserBack ? kVK_LeftArrow : kVK_RightArrow
        return KeyStroke(key: action == .browserBack ? "left arrow" : "right arrow", modifiers: ["cmd"], keyCode: UInt16(arrow))
    }

    private static func bracketStroke(_ wanted: String, layoutData data: CFData) -> KeyStroke? {
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        let choices: [(UInt32, [String])] = [(0, []), (UInt32(shiftKey), ["shift"])]
        for (modifiers, names) in choices {
            for code in UInt16(0)..<128 {
                var deadKey: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), modifiers >> 8,
                                            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                            &deadKey, characters.count, &length, &characters)
                if status == noErr && String(utf16CodeUnits: characters, count: length) == wanted {
                    return KeyStroke(key: wanted, modifiers: ["cmd"] + names, keyCode: code)
                }
            }
        }
        return nil
    }
}
