import Cocoa
import SwiftUI

private enum EditorKind: String, CaseIterable {
    case original = "Funzione originale"
    case mouse = "Azione mouse"
    case shortcut = "Scorciatoia"
    case text = "Testo"
    case application = "Applicazione"
    case profile = "Cambia profilo"
    case shell = "Comando shell"
    case macro = "Macro"
    case disabled = "Disabilitato"
}

struct ActionInspector: View {
    let button: Int
    @ObservedObject private var model = WorkspaceModel.shared
    @State private var kind: EditorKind = .original
    @State private var text = ""
    @State private var description = ""
    @State private var keys: [KeyStroke] = []
    @State private var selectedStroke = 0
    @State private var mouse: MouseAction = .browserBack
    @State private var recording = false
    @State private var validationError: String?
    @State private var preset = "tab"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(buttonName(button)).font(.title2.weight(.semibold))
            Text("Le modifiche vengono salvate nel profilo \(model.profile).")
                .font(.caption).foregroundStyle(.secondary)
            if button >= 18 {
                Label("Mantieni un clic principale disponibile per usare il Mac.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
            }
            Picker("Azione", selection: Binding(get: { kind }, set: changeKind)) {
                ForEach(EditorKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Divider()
            editor
            if kind != .original && kind != .disabled {
                TextField("Nome facoltativo", text: $description)
                    .onSubmit { persist() }
                Text("Premi Invio per salvare i campi di testo.").font(.caption).foregroundStyle(.secondary)
            }
            if let validationError {
                Text(validationError).font(.callout).foregroundStyle(.red)
            }
            Spacer(minLength: 12)
        }
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { load() }
        .onChange(of: model.mapping[button]) { _ in
            if !recording { load() }
        }
        .onDisappear { recording = false }
    }

    @ViewBuilder private var editor: some View {
        switch kind {
        case .original:
            Label("Nessuna rimappatura", systemImage: "arrow.uturn.backward")
            Text("Il segnale originale passa senza modifiche. Non equivale a disabilitare il pulsante.")
                .foregroundStyle(.secondary)
        case .disabled:
            Label("Pulsante disabilitato", systemImage: "nosign")
            Text("Il segnale viene bloccato solo quando la rimappatura è attiva.")
                .foregroundStyle(.secondary)
        case .mouse:
            HStack {
                Button("Indietro") { mouse = .browserBack; persist() }
                Button("Avanti") { mouse = .browserForward; persist() }
            }
            Text("Consigliati per navigare nel browser.").font(.caption).foregroundStyle(.secondary)
            Picker("Funzione", selection: Binding(get: { mouse }, set: { mouse = $0; persist() })) {
                ForEach(MouseAction.allCases, id: \.rawValue) { Text($0.title).tag($0) }
            }
            Text("I pulsanti mouse 4 e 5 inviano clic reali. Nei browser, che su macOS li ignorano, vengono convertiti automaticamente in Indietro e Avanti.")
                .font(.callout).foregroundStyle(.secondary)
        case .shortcut:
            shortcutEditor
        case .text:
            TextEditor(text: $text).font(.body).frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            Button("Applica testo") { persist() }
        case .application:
            TextField("Percorso dell'applicazione", text: $text).onSubmit { persist() }
            Button("Scegli applicazione…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.applicationBundle]
                panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url { text = url.path; persist() }
            }
        case .profile:
            Picker("Profilo destinazione", selection: Binding(get: { text }, set: { text = $0; if !text.isEmpty { persist() } })) {
                Text("Scegli un profilo").tag("")
                ForEach(model.profiles, id: \.self) { Text($0).tag($0) }
            }
        case .shell:
            Text("Il comando verrà eseguito alla pressione del pulsante. Usa solo comandi che conosci.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.system(.body, design: .monospaced)).frame(minHeight: 100)
            Button("Applica comando") { persist() }
        case .macro:
            Text("Passaggi JSON. La macro esistente resta invariata finché non applichi una versione valida.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.system(.body, design: .monospaced)).frame(minHeight: 230)
            Button("Applica macro") { persist() }
        }
    }

    private var shortcutEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            if keys.count > 1 {
                Text("Sequenza di \(keys.count) tasti. Modifica un passaggio senza cancellare gli altri.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Passaggio", selection: $selectedStroke) {
                    ForEach(keys.indices, id: \.self) { index in
                        Text("\(index + 1). \(keys[index].formattedShortcut())").tag(index)
                    }
                }
            }
            Text(keys.indices.contains(selectedStroke) ? keys[selectedStroke].formattedShortcut() : "Nessun tasto")
                .font(.system(size: 26, weight: .medium)).frame(maxWidth: .infinity, minHeight: 58)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            ShortcutCapture(isRecording: $recording) { stroke in
                if keys.indices.contains(selectedStroke) { keys[selectedStroke] = stroke }
                else { keys.append(stroke); selectedStroke = keys.count - 1 }
                persist()
            }.frame(height: 32)
            Text(recording ? "Premi un tasto, anche Tab, Invio o Esc. Per annullare usa il pulsante." : "La tastiera viene intercettata solo durante la registrazione.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(["cmd", "shift", "alt", "ctrl"], id: \.self) { modifier in
                    Toggle(modifierSymbol(modifier), isOn: Binding(
                        get: { keys.indices.contains(selectedStroke) && keys[selectedStroke].modifiers.contains(modifier) },
                        set: { enabled in
                            guard keys.indices.contains(selectedStroke) else { return }
                            keys[selectedStroke].modifiers.removeAll { $0 == modifier }
                            if enabled { keys[selectedStroke].modifiers.append(modifier) }
                            persist()
                        }
                    )).toggleStyle(.checkbox)
                }
            }
            HStack {
                Picker("Tasto", selection: $preset) {
                    ForEach(["tab", "return", "escape", "space", "delete", "forward delete",
                             "left arrow", "right arrow", "up arrow", "down arrow", "home", "end",
                             "page up", "page down"] + (1...20).map { "f\($0)" }, id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
                Button("Usa") {
                    let stroke = KeyStroke(key: preset, modifiers: keys.indices.contains(selectedStroke) ? keys[selectedStroke].modifiers : [], keyCode: KeyStroke.keyCode(for: preset))
                    if keys.indices.contains(selectedStroke) { keys[selectedStroke] = stroke }
                    else { keys.append(stroke) }
                    persist()
                }
            }
            HStack {
                Button("Aggiungi passaggio") {
                    keys.append(KeyStroke(key: "tab", modifiers: [], keyCode: 48))
                    selectedStroke = keys.count - 1
                    persist()
                }
                if keys.count > 1 {
                    Button("Rimuovi") {
                        keys.remove(at: selectedStroke)
                        selectedStroke = max(0, selectedStroke - 1)
                        persist()
                    }
                }
            }
        }
    }

    private func changeKind(_ newKind: EditorKind) {
        guard newKind != kind else { return }
        if kind == .macro || keys.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Sostituire l'azione esistente?"
            alert.informativeText = "La macro o sequenza verrà sostituita nel profilo corrente."
            alert.addButton(withTitle: "Sostituisci")
            alert.addButton(withTitle: "Annulla")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        recording = false
        kind = newKind
        text = newKind == .macro ? "[]" : ""
        keys = []
        selectedStroke = 0
        description = ""
        validationError = nil
        if [.original, .disabled, .mouse].contains(newKind) { persist() }
    }

    private func load() {
        description = ""
        keys = []
        switch model.mapping[button] {
        case nil: kind = .original
        case .disabled: kind = .disabled
        case .mouse(let action, let label): kind = .mouse; mouse = action; description = label ?? ""
        case .keySequence(let strokes, let label):
            kind = .shortcut; keys = strokes; description = label ?? ""
            selectedStroke = min(selectedStroke, max(0, keys.count - 1))
        case .textSnippet(let value, let label): kind = .text; text = value; description = label ?? ""
        case .application(let value, let label): kind = .application; text = value; description = label ?? ""
        case .profileSwitch(let value, let label): kind = .profile; text = value; description = label ?? ""
        case .systemCommand(let value, let label): kind = .shell; text = value; description = label ?? ""
        case .macro(let steps, let label):
            kind = .macro; description = label ?? ""
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            text = (try? encoder.encode(steps)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
    }

    private func persist() {
        validationError = nil
        let label = description.isEmpty ? nil : description
        let action: ActionType?
        switch kind {
        case .original: action = nil
        case .disabled: action = .disabled
        case .mouse: action = .mouse(action: mouse, description: label)
        case .shortcut:
            guard !keys.isEmpty else { return }
            action = .keySequence(keys: keys, description: label)
        case .text: action = .textSnippet(text: text, description: label)
        case .application: action = .application(path: text, description: label)
        case .profile: action = .profileSwitch(profile: text, description: label)
        case .shell: action = .systemCommand(command: text, description: label)
        case .macro:
            do {
                let steps = try JSONDecoder().decode([MacroStep].self, from: Data(text.utf8))
                guard steps.allSatisfy({ ["key", "text", "delay"].contains($0.type) &&
                    ($0.type != "key" || $0.keyStroke != nil) &&
                    ($0.type != "text" || $0.text != nil) &&
                    ($0.type != "delay" || ($0.delayMs ?? -1) >= 0) }) else {
                    validationError = "Passaggi non validi: usa key, text o delay con il relativo valore."
                    return
                }
                action = .macro(steps: steps, description: label)
            } catch { validationError = "JSON non valido: \(error.localizedDescription)"; return }
        }
        model.save(action, button: button)
    }
}

private func modifierSymbol(_ value: String) -> String {
    ["cmd": "⌘", "shift": "⇧", "alt": "⌥", "ctrl": "⌃"][value] ?? value
}

/// A local monitor exists only while the user explicitly arms this control.
private struct ShortcutCapture: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (KeyStroke) -> Void

    func makeNSView(context: Context) -> CaptureButton { CaptureButton() }
    func updateNSView(_ view: CaptureButton, context: Context) {
        view.onCapture = { stroke in isRecording = false; onCapture(stroke) }
        view.onRecordingChange = { isRecording = $0 }
        view.setRecording(isRecording)
    }
    static func dismantleNSView(_ nsView: CaptureButton, coordinator: ()) { nsView.setRecording(false) }
}

private final class CaptureButton: NSButton {
    var onCapture: ((KeyStroke) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?
    private var monitor: Any?
    private var resignation: NSObjectProtocol?
    private var recording = false

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        title = "Registra scorciatoia"
        target = self
        action = #selector(toggleRecording)
        resignation = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let window = note.object as? NSWindow, window === self.window else { return }
            self.setRecording(false)
            self.onRecordingChange?(false)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func toggleRecording() { setRecording(!recording); onRecordingChange?(recording) }
    func setRecording(_ value: Bool) {
        guard value != recording else { return }
        recording = value
        title = value ? "Annulla registrazione" : "Registra scorciatoia"
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard value else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording, event.window === self.window, self.window?.isKeyWindow == true else { return event }
            let flags = event.modifierFlags
            var modifiers: [String] = []
            if flags.contains(.command) { modifiers.append("cmd") }
            if flags.contains(.shift) { modifiers.append("shift") }
            if flags.contains(.option) { modifiers.append("alt") }
            if flags.contains(.control) { modifiers.append("ctrl") }
            let stroke = KeyStroke(key: KeyStroke.canonicalKeyString(for: event.keyCode, characters: event.charactersIgnoringModifiers), modifiers: modifiers, keyCode: event.keyCode)
            self.setRecording(false)
            self.onCapture?(stroke)
            return nil
        }
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignation { NotificationCenter.default.removeObserver(resignation) }
    }
}
