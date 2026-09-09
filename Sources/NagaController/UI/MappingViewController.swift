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

struct NagaWorkspace: View {
    @ObservedObject private var model = WorkspaceModel.shared
    @State private var selectedButton = 1
    @State private var manageProfiles = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                toolbar
                Divider()
                if !model.permissionsGranted {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised")
                        Text("Concedi i permessi per usare le assegnazioni.")
                        Spacer()
                        Button("Configura") { model.section = .status }
                    }.font(.callout).padding(.horizontal, 24).padding(.vertical, 10)
                        .background(UIStyle.inset)
                    Divider()
                }
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.callout).padding(12)
                }
                Group {
                    switch model.section {
                    case .buttons:
                        HStack(spacing: 0) {
                            MouseWorkspace(selectedButton: $selectedButton)
                                .frame(minWidth: 390, maxWidth: .infinity, maxHeight: .infinity)
                            Divider()
                            ScrollView {
                                ActionInspector(button: selectedButton)
                                    .id("\(model.profile)-\(selectedButton)")
                                    .padding(24)
                            }.frame(width: 340)
                                .background(.background.opacity(0.45))
                        }
                    case .sensitivity: SensitivityPane()
                    case .status: StatusPane()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                HStack(spacing: 8) {
                    StatusDot(active: model.connected && model.remappingActive)
                    Text(model.serviceStatus)
                    Spacer()
                    Image(systemName: "menubar.rectangle")
                    Text("Resta attiva quando chiudi la finestra")
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 20).frame(height: 32)
            }
        }
        .background {
            if CommandLine.arguments.contains("--snapshot") { Color(nsColor: .windowBackgroundColor) }
        }
        .tint(UIStyle.accent)
        .sheet(isPresented: $manageProfiles) { ProfileManagerPane() }
        .onAppear {
            model.refresh()
            let args = CommandLine.arguments
            if args.contains("--snapshot"), let index = args.firstIndex(of: "--snapshot-button"),
               args.indices.contains(index + 1), let button = Int(args[index + 1]), (1...19).contains(button) {
                selectedButton = button
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "computermouse.fill").font(.system(size: 24, weight: .light))
                    .foregroundStyle(UIStyle.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Naga").font(.system(size: 22, weight: .semibold))
                    Text("Controller").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 34)
            VStack(spacing: 4) {
                ForEach(WorkspaceSection.allCases, id: \.self) { section in
                    Button { model.section = section } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbol).frame(width: 18)
                            Text(section.rawValue).fontWeight(model.section == section ? .medium : .regular)
                            Spacer()
                        }.padding(.horizontal, 12).frame(height: 36)
                            .foregroundStyle(model.section == section ? UIStyle.accent : .primary)
                            .background(model.section == section ? UIStyle.selection : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(model.section == section ? [.isSelected] : [])
                }
            }.padding(.horizontal, 10)
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Naga V2 HyperSpeed").font(.system(size: 12, weight: .medium))
                    HStack(spacing: 6) {
                        StatusDot(active: model.connected)
                        Text(model.connected ? model.transport ?? "Connesso" : "Mouse scollegato")
                    }.font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Toggle("Rimappatura", isOn: Binding(
                    get: { model.remappingEnabled }, set: model.setRemapping
                )).toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
            }.padding(18)
        }.frame(width: 184).frame(maxHeight: .infinity)
            .background(SidebarMaterial())
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.section.rawValue).font(.system(size: 22, weight: .semibold))
                Text(model.section == .buttons ? "Il tuo mouse, le tue assegnazioni." : model.section == .sensitivity ? "Sensore e controlli hardware" : "Connessione e funzionamento")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Profilo", selection: Binding(get: { model.profile }, set: model.selectProfile)) {
                ForEach(model.profiles, id: \.self) { Text($0).tag($0) }
            }.frame(width: 205)
            Menu {
                Button("Gestisci profili…") { manageProfiles = true }
                Divider()
                Button("Importa profili…") { model.importProfiles() }
                Button("Esporta profili…") { model.exportProfiles() }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 17)) }
            .menuStyle(.borderlessButton).frame(width: 24).help("Gestisci, importa o esporta profili")
        }.padding(.horizontal, 24).frame(height: 88)
    }
}

func buttonName(_ index: Int) -> String {
    switch index {
    case 13: return "DPI su"
    case 14: return "DPI giù"
    case 15: return "Rotella a sinistra"
    case 16: return "Rotella a destra"
    case 17: return "Clic centrale"
    case 18: return "Clic sinistro"
    case 19: return "Clic destro"
    default: return "Pulsante laterale \(index)"
    }
}
