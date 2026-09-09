import Cocoa
import Carbon.HIToolbox
import IOKit.hidsystem

enum SystemActionGroup: String, CaseIterable {
    case audio = "Audio"
    case playback = "Riproduzione"
    case brightness = "Luminosità"
    case screenshots = "Screenshot"
    case windows = "Finestre e spazi"
    case tools = "Strumenti"

    var actions: [SystemAction] { SystemAction.allCases.filter { $0.group == self } }
}

enum SystemAction: String, Codable, CaseIterable {
    case volumeUp, volumeDown, mute
    case playPause, previousTrack, nextTrack
    case brightnessUp, brightnessDown
    case screenshot, screenshotSelection, screenshotOptions
    case screenshotClipboard, screenshotSelectionClipboard
    case missionControl, applicationWindows, showDesktop, previousSpace, nextSpace
    case hideApplication, switchApplication
    case spotlight, finder, systemSettings, notificationCenter, doNotDisturb

    init(audio: AudioAction) {
        switch audio {
        case .volumeUp: self = .volumeUp
        case .volumeDown: self = .volumeDown
        case .mute: self = .mute
        }
    }

    var group: SystemActionGroup {
        switch self {
        case .volumeUp, .volumeDown, .mute: return .audio
        case .playPause, .previousTrack, .nextTrack: return .playback
        case .brightnessUp, .brightnessDown: return .brightness
        case .screenshot, .screenshotSelection, .screenshotOptions,
             .screenshotClipboard, .screenshotSelectionClipboard: return .screenshots
        case .missionControl, .applicationWindows, .showDesktop, .previousSpace, .nextSpace,
             .hideApplication, .switchApplication: return .windows
        case .spotlight, .finder, .systemSettings, .notificationCenter, .doNotDisturb: return .tools
        }
    }

    var title: String {
        switch self {
        case .volumeUp: return "Aumenta volume"
        case .volumeDown: return "Diminuisci volume"
        case .mute: return "Attiva/disattiva audio"
        case .playPause: return "Riproduci/pausa"
        case .previousTrack: return "Traccia precedente"
        case .nextTrack: return "Traccia successiva"
        case .brightnessUp: return "Aumenta luminosità"
        case .brightnessDown: return "Diminuisci luminosità"
        case .screenshot: return "Cattura schermo intero"
        case .screenshotSelection: return "Cattura selezione"
        case .screenshotOptions: return "Opzioni screenshot e registrazione"
        case .screenshotClipboard: return "Schermo intero negli appunti"
        case .screenshotSelectionClipboard: return "Selezione negli appunti"
        case .missionControl: return "Mission Control"
        case .applicationWindows: return "Mostra finestre dell'app"
        case .showDesktop: return "Mostra Scrivania"
        case .previousSpace: return "Spazio a sinistra"
        case .nextSpace: return "Spazio a destra"
        case .hideApplication: return "Nascondi app corrente"
        case .switchApplication: return "Cambia applicazione"
        case .spotlight: return "Apri Spotlight"
        case .finder: return "Apri Finder"
        case .systemSettings: return "Apri Impostazioni di Sistema"
        case .notificationCenter: return "Mostra Centro Notifiche"
        case .doNotDisturb: return "Attiva/disattiva Non disturbare"
        }
    }

    var symbol: String {
        switch self {
        case .volumeUp: return "speaker.plus.fill"
        case .volumeDown: return "speaker.minus.fill"
        case .mute: return "speaker.slash.fill"
        case .playPause: return "playpause.fill"
        case .previousTrack: return "backward.end.fill"
        case .nextTrack: return "forward.end.fill"
        case .brightnessUp: return "sun.max"
        case .brightnessDown: return "sun.min"
        case .screenshot: return "camera"
        case .screenshotSelection: return "viewfinder"
        case .screenshotOptions: return "camera.viewfinder"
        case .screenshotClipboard, .screenshotSelectionClipboard: return "clipboard"
        case .missionControl: return "rectangle.3.group"
        case .applicationWindows: return "macwindow.on.rectangle"
        case .showDesktop: return "menubar.dock.rectangle"
        case .previousSpace: return "rectangle.lefthalf.inset.filled.arrow.left"
        case .nextSpace: return "rectangle.righthalf.inset.filled.arrow.right"
        case .hideApplication: return "eye.slash"
        case .switchApplication: return "arrow.left.arrow.right"
        case .spotlight: return "magnifyingglass"
        case .finder: return "folder"
        case .systemSettings: return "gearshape"
        case .notificationCenter: return "bell"
        case .doNotDisturb: return "moon"
        }
    }

    var help: String {
        switch self {
        case .brightnessUp, .brightnessDown:
            return "Come i tasti luminosità del Mac. I monitor esterni devono supportare il controllo da macOS."
        case .playPause, .previousTrack, .nextTrack:
            return "Controlla la riproduzione multimediale attiva, come i tasti del Mac."
        case .screenshot, .screenshotSelection:
            return "Salva nella destinazione scelta nelle opzioni Screenshot di macOS."
        case .screenshotOptions:
            return "Apre gli strumenti di macOS per catturare lo schermo, una finestra o registrare un video."
        case .screenshotClipboard, .screenshotSelectionClipboard:
            return "Copia la cattura negli appunti al posto di salvarla come file."
        case .previousSpace, .nextSpace:
            return "Passa allo spazio adiacente, se presente."
        case .switchApplication:
            return "Passa all'ultima app utilizzata, come un tocco su Command-Tab."
        case .hideApplication:
            return "Nasconde l'app in primo piano senza chiuderla."
        case .doNotDisturb:
            return "Usa la scorciatoia Non disturbare configurata in macOS. Le impostazioni di full immersion possono sincronizzarsi con gli altri dispositivi."
        default:
            return "Una sola azione a ogni pressione. Tenere premuto il pulsante non la ripete."
        }
    }

    var mediaKey: Int? {
        switch self {
        case .volumeUp: return Int(NX_KEYTYPE_SOUND_UP)
        case .volumeDown: return Int(NX_KEYTYPE_SOUND_DOWN)
        case .mute: return Int(NX_KEYTYPE_MUTE)
        case .brightnessUp: return Int(NX_KEYTYPE_BRIGHTNESS_UP)
        case .brightnessDown: return Int(NX_KEYTYPE_BRIGHTNESS_DOWN)
        case .playPause: return Int(NX_KEYTYPE_PLAY)
        // A short press on the Mac's seek keys skips a track.
        case .nextTrack: return Int(NX_KEYTYPE_FAST)
        case .previousTrack: return Int(NX_KEYTYPE_REWIND)
        default: return nil
        }
    }

    func mediaEvent(down: Bool) -> CGEvent? {
        guard let mediaKey else { return nil }
        let state = down ? 0xA : 0xB
        return NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
            context: nil, subtype: 8, data1: (mediaKey << 16) | (state << 8), data2: -1)?.cgEvent
    }

    var shortcut: MacSystemShortcut? {
        switch self {
        case .screenshot: return .init(id: 28, keyCode: kVK_ANSI_3, flags: [.maskCommand, .maskShift])
        case .screenshotClipboard: return .init(id: 29, keyCode: kVK_ANSI_3, flags: [.maskCommand, .maskShift, .maskControl])
        case .screenshotSelection: return .init(id: 30, keyCode: kVK_ANSI_4, flags: [.maskCommand, .maskShift])
        case .screenshotSelectionClipboard: return .init(id: 31, keyCode: kVK_ANSI_4, flags: [.maskCommand, .maskShift, .maskControl])
        case .screenshotOptions: return .init(id: 184, keyCode: kVK_ANSI_5, flags: [.maskCommand, .maskShift])
        case .missionControl: return .init(id: 32, keyCode: kVK_UpArrow, flags: .maskControl)
        case .applicationWindows: return .init(id: 33, keyCode: kVK_DownArrow, flags: .maskControl)
        case .showDesktop: return .init(id: 36, keyCode: kVK_F11)
        case .previousSpace: return .init(id: 79, keyCode: kVK_LeftArrow, flags: .maskControl)
        case .nextSpace: return .init(id: 81, keyCode: kVK_RightArrow, flags: .maskControl)
        case .switchApplication: return .init(keyCode: kVK_Tab, flags: .maskCommand)
        case .notificationCenter: return .init(keyCode: kVK_ANSI_N, flags: .maskSecondaryFn)
        case .doNotDisturb: return .init(id: 175)
        default: return nil
        }
    }

    var applicationBundleIdentifier: String? {
        switch self {
        case .spotlight: return "com.apple.Spotlight"
        case .finder: return "com.apple.finder"
        case .systemSettings: return "com.apple.systempreferences"
        default: return nil
        }
    }

    var needsAccessibility: Bool { mediaKey != nil || shortcut != nil }

    var shortcutSetupMessage: String {
        let section = group == .screenshots ? "Screenshot" : "Mission Control"
        return "Assegna e abilita la scorciatoia in Tastiera > Abbreviazioni da tastiera > \(section)."
    }
}
