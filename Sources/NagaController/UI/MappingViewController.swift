import Cocoa
import SwiftUI
import Combine
import UniformTypeIdentifiers

final class MappingViewController: NSHostingController<NagaWorkspace> {
    init() { super.init(rootView: NagaWorkspace()) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

enum WorkspaceSection: String, CaseIterable {
    case buttons = "Pulsanti"
    case sensitivity = "Sensibilità"
    case status = "Stato"

    var symbol: String {
        switch self {
        case .buttons: return "square.grid.3x3"
        case .sensitivity: return "speedometer"
        case .status: return "info.circle"
        }
    }
}

@MainActor
final class WorkspaceModel: ObservableObject {
    static let shared = WorkspaceModel()
    @Published var section: WorkspaceSection = .buttons
    @Published var profile = ""
    @Published var profiles: [String] = []
    @Published var mapping: [Int: ActionType] = [:]
    @Published var remappingActive = false
    @Published var deviceName = "Nessun mouse rilevato"
    @Published var error: String?
    @Published var revision = 0
    @Published var activeButton: Int?
    private var subscriptions = Set<AnyCancellable>()

    private init() {
        let names = [
            ConfigManager.didChangeNotification, HIDListener.didUpdateNotification,
            RazerDeviceController.didUpdateNotification,
            NSApplication.didBecomeActiveNotification,
            EventTapManager.didUpdateNotification
        ]
        for name in names {
            NotificationCenter.default.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: Notification.Name("NagaButtonActivity"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self, let index = note.userInfo?["buttonIndex"] as? Int else { return }
                self.activeButton = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    if self?.activeButton == index { self?.activeButton = nil }
                }
            }.store(in: &subscriptions)
        refresh()
    }

    func refresh() {
        let config = ConfigManager.shared
        profile = config.currentProfileName
        profiles = config.availableProfiles()
        mapping = config.mappingForCurrentProfile()
        error = config.lastError
        deviceName = HIDListener.shared.connectedDeviceName ?? "Nessun mouse rilevato"
        remappingActive = EventTapManager.shared.isRunning && EventTapManager.shared.isRemappingEnabled
        revision += 1
    }

    func setRemapping(_ value: Bool) {
        EventTapManager.shared.isRemappingEnabled = value
        ConfigManager.shared.setRemappingEnabled(value)
        refresh()
    }

    func save(_ action: ActionType?, button: Int) {
        ConfigManager.shared.setAction(forButton: button, action: action)
        refresh()
    }

    func selectProfile(_ name: String) {
        ConfigManager.shared.setCurrentProfile(name)
        refresh()
    }

    func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ConfigManager.shared.importProfiles(from: url); refresh() }
        catch { self.error = error.localizedDescription }
    }

    func exportProfiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "NagaController-profili.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ConfigManager.shared.exportAllProfiles(to: url) }
        catch { self.error = error.localizedDescription }
    }
}

struct NagaWorkspace: View {
    @ObservedObject private var model = WorkspaceModel.shared
    @State private var selectedButton = 1
    @State private var manageProfiles = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Label("NagaController", systemImage: "computermouse")
                    .font(.headline).padding(.top, 8)
                VStack(spacing: 4) {
                    ForEach(WorkspaceSection.allCases, id: \.self) { section in
                        Button { model.section = section } label: {
                            Label(section.rawValue, systemImage: section.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(model.section == section ? Color.accentColor.opacity(0.13) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                Text(model.deviceName).font(.caption).foregroundStyle(.secondary)
                Toggle("Rimappatura", isOn: Binding(
                    get: { model.remappingActive }, set: { model.setRemapping($0) }
                )).toggleStyle(.switch).controlSize(.small)
                Text(model.remappingActive ? "Attiva" : "Non attiva")
                    .font(.caption).foregroundStyle(model.remappingActive ? Color.green : .secondary)
            }
            .padding(16).frame(width: 190)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(model.section.rawValue).font(.system(size: 25, weight: .semibold))
                    Spacer()
                    Picker("Profilo", selection: Binding(get: { model.profile }, set: model.selectProfile)) {
                        ForEach(model.profiles, id: \.self) { Text($0).tag($0) }
                    }.frame(width: 230)
                    Menu {
                        Button("Gestisci profili…") { manageProfiles = true }
                        Divider()
                        Button("Importa JSON…") { model.importProfiles() }
                        Button("Esporta tutti i profili…") { model.exportProfiles() }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).frame(width: 28)
                }.padding(24)
                Divider()
                if !PermissionManager.shared.hasAccessibilityPermission() || !PermissionManager.shared.hasInputMonitoringPermission() {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised")
                        Text("Autorizza l'app per attivare le assegnazioni.").font(.callout)
                        Spacer()
                        Button("Configura permessi") { model.section = .status }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                }
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.callout).padding(12)
                }
                Group {
                    switch model.section {
                    case .buttons: buttons
                    case .sensitivity: SensitivityPane()
                    case .status: StatusPane()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .tint(.green)
        .sheet(isPresented: $manageProfiles) { ProfileManagerPane() }
        .onAppear { model.refresh() }
    }

    private var buttons: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Pannello laterale").font(.headline)
                    Text("Seleziona un pulsante per modificarne l'azione.")
                        .font(.callout).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(1...12, id: \.self) { index in buttonTile(index) }
                    }
                    Text("Parte superiore e rotella").font(.headline).padding(.top, 8)
                    ForEach(13...19, id: \.self) { index in
                        Button { selectedButton = index } label: {
                            HStack {
                                Text("\(index)").monospacedDigit().foregroundStyle(.secondary).frame(width: 24)
                                Text(buttonName(index))
                                Spacer()
                                if selectedButton == index { Image(systemName: "checkmark").foregroundStyle(.green) }
                            }.padding(9)
                                .background(selectedButton == index ? Color.green.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(minWidth: 285, idealWidth: 340, maxWidth: 400)
            Divider()
            ScrollView {
                ActionInspector(button: selectedButton)
                    .id("\(model.profile)-\(selectedButton)")
            }.frame(minWidth: 290, maxWidth: .infinity)
        }.padding(24)
    }

    private func buttonTile(_ index: Int) -> some View {
        Button { selectedButton = index } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(index)").font(.system(size: 22, weight: .medium, design: .rounded))
                Text(model.mapping[index]?.displayName ?? "Originale")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                .padding(10)
                .background(selectedButton == index ? Color.green.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                    model.activeButton == index ? Color.green : selectedButton == index ? Color.green.opacity(0.7) : Color.secondary.opacity(0.15),
                    lineWidth: model.activeButton == index ? 3 : 1
                ))
        }.buttonStyle(.plain).accessibilityLabel("Pulsante \(index), \(model.mapping[index]?.displayName ?? "Originale")")
    }
}

func buttonName(_ index: Int) -> String {
    switch index {
    case 13: return "DPI su · anteriore"
    case 14: return "DPI giù · posteriore"
    case 15: return "Rotella a sinistra"
    case 16: return "Rotella a destra"
    case 17: return "Clic centrale"
    case 18: return "Clic sinistro"
    case 19: return "Clic destro"
    default: return "Pulsante laterale \(index)"
    }
}
