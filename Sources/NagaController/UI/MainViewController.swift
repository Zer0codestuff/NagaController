import Cocoa
import SwiftUI

final class MainViewController: NSViewController {
    override func loadView() {
        let host = NSHostingController(rootView: NagaPopover())
        addChild(host)
        view = host.view
        preferredContentSize = NSSize(width: 320, height: 288)
    }

    func refreshPermissionStatuses() { WorkspaceModel.shared.refresh() }
}

private struct NagaPopover: View {
    @ObservedObject private var model = WorkspaceModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "computermouse.fill").font(.title2).foregroundStyle(UIStyle.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("NagaController").font(.headline)
                    Text(model.connected ? "Naga V2 HyperSpeed" : "Mouse scollegato")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Picker("Profilo", selection: Binding(get: { model.profile }, set: model.selectProfile)) {
                ForEach(model.profiles, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Rimappatura", isOn: Binding(
                get: { model.remappingEnabled }, set: model.setRemapping
            )).toggleStyle(.switch).controlSize(.small)
            HStack(spacing: 7) {
                StatusDot(active: model.connected && model.remappingActive)
                Text(model.serviceStatus)
            }.font(.caption).foregroundStyle(.secondary)
            Divider()
            Button("Configura mouse…") { MappingWindowController.shared.show() }
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button("Stato e permessi…") {
                    model.section = .status
                    MappingWindowController.shared.show()
                }
                Spacer()
                Button("Esci") { NSApp.terminate(nil) }
            }.font(.callout)
        }.padding(20).frame(width: 320, height: 288).tint(UIStyle.accent)
            .onAppear { model.refresh() }
    }
}
