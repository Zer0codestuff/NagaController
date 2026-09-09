import Cocoa

// Retained for profiles saved before the Sistema editor.
enum AudioAction: String, Codable, CaseIterable {
    case volumeUp, volumeDown, mute

    var title: String { SystemAction(audio: self).title }
    var symbol: String { SystemAction(audio: self).symbol }

    func event(down: Bool) -> CGEvent? {
        SystemAction(audio: self).mediaEvent(down: down)
    }
}
