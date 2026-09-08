import Cocoa
import SwiftUI

final class MainViewController: NSViewController {
    override func loadView() {
        let host = NSHostingController(rootView: NagaPopover())
        addChild(host)
        view = host.view
        preferredContentSize = NSSize(width: 340, height: 260)
    }

    func refreshPermissionStatuses() {
        WorkspaceModel.shared.refresh()
    }
}

private struct NagaPopover: View {
    @ObservedObject private var model = WorkspaceModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("NagaController", systemImage: "computermouse").font(.headline)
            Text(model.deviceName).foregroundStyle(.secondary)
            Toggle("Rimappatura attiva", isOn: Binding(
                get: { model.remappingActive },
                set: { model.setRemapping($0) }
            ))
            Text(model.remappingActive ? "Profilo: \(model.profile)" : "I pulsanti mantengono la funzione originale.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Button("Configura mouse…") { MappingWindowController.shared.show() }
            HStack {
                Button("Permessi…") {
                    WorkspaceModel.shared.section = .status
                    MappingWindowController.shared.show()
                }
                Spacer()
                Button("Esci") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 340, height: 260)
        .onAppear { model.refresh() }
    }
}
