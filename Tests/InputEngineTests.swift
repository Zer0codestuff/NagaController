import Foundation
import Cocoa

enum InputEngineTests {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func run() throws -> Int {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw Failure(description: message) }
            count += 1
        }
        try check(NagaInput.isSupported(vendor: 0x1532, product: 0x00b4, name: nil), "Receiver ID")
        try check(!NagaInput.isSupported(vendor: 0x1532, product: 1, name: "Razer Keyboard"), "Other Razer keyboard excluded")
        try check(!NagaInput.isSupported(vendor: 0x068e, product: 1, name: "Keyboard"), "Unrelated vendor excluded")
        try check(!NagaInput.isSupported(vendor: 1, product: 0x00b4, name: "Naga"), "Product/name alone insufficient")
        for index in 1...10 {
            try check(NagaInput.button(page: 7, usage: UInt32(0x1d + index), value: 1) == index, "Side keyboard usage")
        }
        try check(NagaInput.button(page: 7, usage: 0x2d, value: 1) == 11, "Minus")
        try check(NagaInput.button(page: 7, usage: 0x2e, value: 1) == 12, "Equals")
        try check(NagaInput.button(page: 9, usage: 3, value: 1) == 17, "Middle")
        try check(NagaInput.button(page: 9, usage: 1, value: 1) == 18, "Left")
        try check(NagaInput.button(page: 9, usage: 2, value: 1) == 19, "Right")
        try check(NagaInput.button(page: 12, usage: 0x238, value: -1) == 15, "AC Pan left")
        try check(NagaInput.button(page: 12, usage: 0x238, value: 1) == 16, "AC Pan right")
        try check(NagaInput.button(page: 12, usage: 0x238, value: 0) == nil, "Pan zero")
        try check(NagaInput.button(page: 0xff00, usage: 1, value: 0x80) == nil, "No guessed DPI cookies")

        var matcher = InputEdgeMatcher()
        matcher.record(button: 1, down: true, timestamp: 10)
        try check(!matcher.consume(button: 2, down: true, timestamp: 10.001), "Different key")
        try check(!matcher.consume(button: 1, down: false, timestamp: 10.001), "Wrong edge")
        try check(matcher.consume(button: 1, down: true, timestamp: 10.001), "Fresh edge")
        try check(!matcher.consume(button: 1, down: true, timestamp: 10.002), "Single consumption")
        matcher.record(button: 1, down: true, timestamp: 11)
        try check(!matcher.consume(button: 1, down: true, timestamp: 11.1), "100 ms is stale")
        matcher.record(button: 1, down: false, timestamp: 12)
        try check(matcher.consume(button: 1, down: false, timestamp: 12.001), "Independent release")
        matcher.record(button: 1, down: true, timestamp: 13)
        matcher.reset()
        try check(!matcher.consume(button: 1, down: true, timestamp: 13), "Reset clears evidence")

        // Fixtures reconstructed from published PR2850 protocol facts, not device captures.
        let held: [UInt8] = [4, 0x20, 0x21, 0x22, 0x23] + Array(repeating: 0, count: 11)
        try check(NagaInput.driverButtons(report: held) == Set([13, 14, 15, 16]), "Driver held set")
        try check(NagaInput.driverButtons(report: [4] + Array(repeating: 0, count: 15)) == [], "Driver release")
        try check(NagaInput.driverButtons(report: Array(held.prefix(8))) == nil, "Reject short packets")
        try check(NagaInput.driverButtons(report: [5] + Array(repeating: 0, count: 15)) == nil, "Reject other report IDs")
        try check(NagaInput.driverMouseButtons(report: [0x60] + Array(repeating: 0, count: 7)) == [15, 16], "Mouse tilt bits")
        try check(NagaInput.driverMouseButtons(report: [0x60]) == nil, "Reject truncated mouse packet")
        var driverState = DriverButtonState()
        try check(driverState.update(source: "mouse", buttons: [15]).pressed == [15], "First driver press")
        try check(driverState.update(source: "keyboard", buttons: [15]).pressed.isEmpty, "Cross-interface press deduped")
        try check(driverState.update(source: "mouse", buttons: []).released.isEmpty, "Other source still holds")
        try check(driverState.update(source: "keyboard", buttons: []).released == [15], "Final driver release")
        var repeatOwner = InputRepeatOwnership()
        let signature = InputRepeatOwnership.Signature(keyboardType: 1, sourcePID: 0, sourceState: 1)
        repeatOwner.claim(button: 1, signature: signature)
        try check(repeatOwner.matches(button: 1, signature: signature, physicallyHeld: true), "Owned Naga repeat suppressed")
        try check(!repeatOwner.matches(button: 1, signature: signature, physicallyHeld: false), "No repeat ownership after physical release")
        try check(!repeatOwner.matches(button: 2, signature: signature, physicallyHeld: true), "No ownership of other key")
        try check(!repeatOwner.matches(button: 1, signature: .init(keyboardType: 2, sourcePID: 0, sourceState: 1), physicallyHeld: true), "Other keyboard signature")
        repeatOwner.invalidate(button: 1)
        try check(!repeatOwner.matches(button: 1, signature: signature, physicallyHeld: true), "Intervening unqualified keyboard event revokes repeat ownership")

        var events: [CGEvent] = []
        let mapper = ButtonMapper(eventSink: { events.append($0) })
        mapper.frontmostBundleIdentifier = { "com.apple.TextEdit" }
        mapper.updateMapping([1: .mouse(action: .button4, description: nil), 2: .disabled])
        mapper.handlePress(buttonIndex: 1)
        mapper.handlePress(buttonIndex: 1)
        try check(events.count == 1, "Duplicate physical down deduplicated")
        try check(events[0].type == .otherMouseDown && events[0].getIntegerValueField(.mouseEventButtonNumber) == 3, "Real mouse button 4")
        mapper.handleRelease(buttonIndex: 1)
        try check(events.last?.type == .otherMouseUp, "Balanced mouse release")
        mapper.handle(buttonIndex: 2)
        mapper.handle(buttonIndex: 19)
        try check(events.count == 2, "Disabled and unmapped emit nothing")
        try check(mapper.hasMapping(buttonIndex: 2) && !mapper.hasMapping(buttonIndex: 19), "Disabled differs from nil")
        mapper.updateMapping([1: .mouse(action: .leftClick, description: nil)])
        mapper.handlePress(buttonIndex: 1)
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: 40, y: 50), mouseButton: .left)!
        try check(mapper.dragEvent(for: move)?.type == .leftMouseDragged, "Held click becomes drag")
        mapper.updateMapping([:])
        try check(events.last?.type == .leftMouseUp, "Mapping change releases hold")
        try check(mapper.dragEvent(for: move) == nil, "No stale drag after reset")
        mapper.updateMapping([1: .keySequence(keys: [KeyStroke(key: "c", modifiers: ["cmd"])], description: nil)])
        mapper.handlePress(buttonIndex: 1)
        mapper.releaseAll()
        try check(events.last?.type == .keyUp, "Cleanup releases held key")
        try check(events.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == ButtonMapper.syntheticMarker }, "Every emitted event is tagged")
        for action in [MouseAction.button5, .middleClick, .rightClick, .scrollUp, .scrollDown, .scrollLeft, .scrollRight] {
            mapper.updateMapping([1: .mouse(action: action, description: nil)])
            let before = events.count
            mapper.handle(buttonIndex: 1)
            try check(events.count > before, "Mouse action emits event: \(action)")
        }
        mapper.updateMapping([1: .mouse(action: .button4, description: nil)])
        mapper.handle(buttonIndex: 1)
        try check(events.suffix(2).map(\.type) == [.otherMouseDown, .otherMouseUp], "Button 4 is a real click outside browsers")
        try check(events.last?.getIntegerValueField(.mouseEventButtonNumber) == 3, "Button 4 uses button number 3")
        mapper.frontmostBundleIdentifier = { "com.google.Chrome.canary" }
        let beforeBrowser = events.count
        mapper.handle(buttonIndex: 1)
        try check(events.count == beforeBrowser, "Browser navigation is deferred to the main queue, no raw click emitted")
        try check(MouseAction.isBrowser(bundleIdentifier: "org.mozilla.firefox") && !MouseAction.isBrowser(bundleIdentifier: "com.apple.finder"), "Browser detection")
        try check(MouseAction.button4.browserEquivalent == .browserBack && MouseAction.button5.browserEquivalent == .browserForward && MouseAction.middleClick.browserEquivalent == nil, "Browser equivalents")
        let stroke = KeyboardLayoutShortcut.browserStroke(for: .browserBack)
        try check(stroke != nil && stroke!.modifiers.contains("cmd") && !stroke!.modifiers.contains("option"), "Browser shortcut never requires Option")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NagaInputTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "NagaInputTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
            ButtonMapper.shared.updateMapping([:])
        }
        let url = root.appendingPathComponent("profiles.json")
        let config = ConfigManager(storageURL: url, defaults: defaults)
        try check(config.createProfile(name: "Vuoto"), "Create blank profile")
        try check(config.mappingForCurrentProfile().isEmpty, "Blank mapping retained")
        for action in MouseAction.allCases {
            config.setAction(forButton: 1, action: .mouse(action: action, description: nil))
            let restored = ConfigManager(storageURL: url, defaults: defaults)
            restored.load()
            try check(restored.mappingForCurrentProfile()[1] == .mouse(action: action, description: nil), "Mouse JSON roundtrip \(action)")
        }
        config.setAction(forButton: 1, action: .disabled)
        let restored = ConfigManager(storageURL: url, defaults: defaults)
        restored.load()
        try check(restored.mappingForCurrentProfile()[1] == .disabled, "Disabled persisted")
        config.setAction(forButton: 1, action: nil)
        restored.load()
        try check(restored.mappingForCurrentProfile().isEmpty, "Nil removes mapping without fallback")
        try check(config.createProfile(name: "Secondo"), "Create second")
        config.setAction(forButton: 3, action: .profileSwitch(profile: "Vuoto", description: nil))
        config.setCurrentProfile("Vuoto")
        try check(config.renameProfile(from: "Vuoto", to: "Primo"), "Rename")
        restored.load()
        try check(restored.currentProfileName == "Primo", "Selection persisted after rename")
        restored.setCurrentProfile("Secondo")
        try check(restored.mappingForCurrentProfile()[3] == .profileSwitch(profile: "Primo", description: nil), "Renamed profile-switch target updated")
        try check(config.deleteProfile(named: "Secondo"), "Delete")
        restored.load()
        try check(restored.availableProfiles() == ["Primo"], "Deleted profiles do not reappear")
        let emptyURL = root.appendingPathComponent("empty.json")
        try Data(#"{"profiles":{}}"#.utf8).write(to: emptyURL)
        try config.importProfiles(from: emptyURL, merge: false)
        restored.load()
        try check(restored.profiles.isEmpty, "Empty profile collection survives reload")
        let legacyURL = root.appendingPathComponent("legacy.json")
        try Data(#"{"profiles":{"Legacy":{"buttons":{"1":{"type":"keySequence","keys":[{"key":"c","modifiers":["cmd"]}]}}}},"settings":{"currentProfile":"Legacy"}}"#.utf8).write(to: legacyURL)
        try config.importProfiles(from: legacyURL, merge: false)
        try check(config.mappingForCurrentProfile()[1] == .keySequence(keys: [KeyStroke(key: "c", modifiers: ["cmd"])], description: nil), "Legacy JSON accepted")
        let blocked = root.appendingPathComponent("file")
        try Data().write(to: blocked)
        let failing = ConfigManager(storageURL: blocked.appendingPathComponent("profiles.json"), defaults: defaults)
        failing.saveUserProfiles()
        try check(failing.lastError != nil, "Save failure visible")
        return count
    }
}
