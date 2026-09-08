import Cocoa
import SwiftUI

struct SensitivityPane: View {
    @ObservedObject private var model = WorkspaceModel.shared
    @State private var dpiX = ""
    @State private var dpiY = ""
    @State private var rate = 1000
    @State private var editedDPI = false
    @State private var editedRate = false
    private var device: RazerDeviceController { .shared }
    private var available: Bool { device.isConnected && !device.isBusy }
    private var validDPI: Bool {
        guard let x = Int(dpiX), let y = Int(dpiY) else { return false }
        return (100...30000).contains(x) && (100...30000).contains(y)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sensibilità del sensore").font(.title2.weight(.semibold))
                        Text("Le impostazioni hardware cambiano solo quando le applichi.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { device.refresh() } label: { Label("Aggiorna", systemImage: "arrow.clockwise") }
                        .disabled(device.isBusy)
                }
                if !device.isConnected {
                    Label("Controllo hardware non disponibile. Collega il mouse tramite USB o ricevitore compatibile.",
                          systemImage: "cable.connector").foregroundStyle(.secondary)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DPI").font(.headline)
                        Text("Valore letto: X \(device.dpiX.map(String.init) ?? "non disponibile") · Y \(device.dpiY.map(String.init) ?? "non disponibile")")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            TextField("Asse X", text: Binding(get: { dpiX }, set: { dpiX = $0; editedDPI = true })).frame(width: 140)
                            TextField("Asse Y", text: Binding(get: { dpiY }, set: { dpiY = $0; editedDPI = true })).frame(width: 140)
                            Spacer()
                            Button("Applica DPI") {
                                guard let x = Int(dpiX), let y = Int(dpiY), validDPI else { return }
                                device.setDPI(x: x, y: y)
                                editedDPI = false
                            }.disabled(!available || !validDPI || device.dpiX == nil || device.dpiY == nil)
                        }
                        HStack {
                            Text("Predefiniti").foregroundStyle(.secondary)
                            ForEach([400, 800, 1600, 3200, 6400], id: \.self) { value in
                                Button("\(value)") { dpiX = String(value); dpiY = String(value); editedDPI = true }
                            }
                        }
                        Text("Da 100 a 30.000 DPI per asse. I predefiniti compilano i campi, non modificano il mouse.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Frequenza di aggiornamento").font(.headline)
                        Text(device.pollingRate.map { "Valore letto: \($0) Hz" } ?? "Valore non disponibile")
                            .foregroundStyle(.secondary)
                        HStack {
                            Picker("Frequenza", selection: Binding(get: { rate }, set: { rate = $0; editedRate = true })) {
                                ForEach([125, 500, 1000], id: \.self) { Text("\($0) Hz").tag($0) }
                            }.pickerStyle(.segmented).frame(maxWidth: 340)
                            Spacer()
                            Button("Applica frequenza") {
                                device.setPollingRate(rate)
                                editedRate = false
                            }.disabled(!available || device.pollingRate == nil)
                        }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Modalità driver per i pulsanti superiori", isOn: Binding(
                            get: { device.driverModeEnabled },
                            set: { device.setDriverModeEnabled($0) }
                        )).disabled(!available || device.recoveryPending)
                        Text("Opzionale. Consente al software di gestire i pulsanti DPI superiori sui dispositivi compatibili. Può sostituire la loro funzione DPI integrata. Disattivala per ripristinare la modalità normale.")
                            .font(.callout).foregroundStyle(.secondary)
                        if device.recoveryPending {
                            Button("Ripristina modalità originale") { device.recoverOriginalMode() }
                                .disabled(device.isBusy)
                            Text("Usa lo stesso ricevitore nella porta USB originale. Il ripristino non avviene automaticamente dopo una chiusura imprevista.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    if device.isBusy { ProgressView().controlSize(.small) }
                    Text(device.statusMessage).font(.callout).foregroundStyle(.secondary)
                }
            }.padding(24)
        }
        .textFieldStyle(.roundedBorder)
        .onAppear { updateFields() }
        .onChange(of: model.revision) { _ in updateFields() }
    }

    private func updateFields() {
        if !editedDPI {
            dpiX = device.dpiX.map(String.init) ?? ""
            dpiY = device.dpiY.map(String.init) ?? ""
        }
        if !editedRate, let value = device.pollingRate, [125, 500, 1000].contains(value) { rate = value }
    }
}

struct StatusPane: View {
    @ObservedObject private var model = WorkspaceModel.shared
    private var permissions: PermissionManager { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Permessi e connessione").font(.title2.weight(.semibold))
                    Spacer()
                    Button("Ricontrolla") { model.refresh() }
                }
                Text("Dopo aver concesso i permessi, riattiva la rimappatura. macOS potrebbe richiedere di riaprire l'app.")
                    .foregroundStyle(.secondary)
                GroupBox {
                    VStack(spacing: 20) {
                        permissionRow("Accessibilità", granted: permissions.hasAccessibilityPermission(),
                                      detail: "Consente di inviare le azioni configurate.",
                                      open: permissions.openAccessibilityPreferences)
                        Divider()
                        permissionRow("Monitoraggio input", granted: permissions.hasInputMonitoringPermission(),
                                      detail: "Consente di riconoscere e intercettare i pulsanti.",
                                      open: permissions.openInputMonitoringPreferences)
                    }.padding(12)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        statusRow("Dispositivo", model.deviceName)
                        statusRow("Trasporto", HIDListener.shared.transport ?? "Non disponibile")
                        statusRow("Batteria", RazerDeviceController.shared.batteryLevel.map { "\($0)%" } ?? "Non disponibile")
                        Divider()
                        statusRow("Intercettazione input", EventTapManager.shared.isRunning ? "In esecuzione" : "Non disponibile")
                        statusRow("Rimappatura", model.remappingActive ? "Attiva" : "Non attiva")
                        statusRow("Ultimo input", HIDListener.shared.lastInputDescription)
                    }.padding(12)
                }
                Text(RazerDeviceController.shared.statusMessage).font(.callout).foregroundStyle(.secondary)
                Text("I tasti principali sinistro e destro mantengono la funzione originale finché non assegni un'azione.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }

    private func permissionRow(_ title: String, granted: Bool, detail: String, open: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? Color.green : .orange).font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(granted ? "Concesso" : "Da concedere").foregroundStyle(.secondary)
            Button("Apri impostazioni", action: open)
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary).frame(width: 160, alignment: .leading)
            Text(value.isEmpty ? "Nessun dato" : value).textSelection(.enabled)
            Spacer()
        }
    }
}

struct ProfileManagerPane: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var model = WorkspaceModel.shared
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Gestisci profili").font(.title2.weight(.semibold))
            Picker("Profilo corrente", selection: Binding(get: { model.profile }, set: model.selectProfile)) {
                ForEach(model.profiles, id: \.self) { Text($0).tag($0) }
            }
            TextField("Nome del profilo", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Button("Crea vuoto") { perform { ConfigManager.shared.createProfile(name: name) } }
                Button("Duplica corrente") { perform { ConfigManager.shared.duplicateProfile(source: model.profile, as: name) } }
                Button("Rinomina") { perform { ConfigManager.shared.renameProfile(from: model.profile, to: name) } }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Divider()
            HStack {
                Button("Elimina profilo…") {
                    let alert = NSAlert()
                    alert.messageText = "Eliminare \(model.profile)?"
                    alert.informativeText = "Le assegnazioni di questo profilo verranno eliminate."
                    alert.addButton(withTitle: "Elimina")
                    alert.addButton(withTitle: "Annulla")
                    if alert.runModal() == .alertFirstButtonReturn {
                        perform { ConfigManager.shared.deleteProfile(named: model.profile) }
                    }
                }.disabled(model.profiles.count <= 1)
                Spacer()
                Button("Fine") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            if let message = error ?? model.error { Text(message).foregroundStyle(.red).font(.callout) }
        }.padding(24).frame(width: 520)
    }

    private func perform(_ action: () -> Bool) {
        guard action() else { error = "Operazione non riuscita. Scegli un nome diverso e non vuoto."; return }
        name = ""
        error = nil
        model.refresh()
    }
}
