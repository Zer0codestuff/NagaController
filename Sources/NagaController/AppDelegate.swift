import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var observers: [NSObjectProtocol] = []
    private var permissionTimer: Timer?
    private var hadInputPermission = false
    private var isTerminating = false

    private var snapshotPath: String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--snapshot"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigManager.shared.load()
        installApplicationMenu()

        if snapshotPath == nil {
            PermissionManager.shared.requestMissingPermissions()
            HIDListener.shared.start()
            RazerDeviceController.shared.refresh()
            hadInputPermission = PermissionManager.shared.hasInputMonitoringPermission()
            startRemappingIfPermitted()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.checkPermissions() }
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "NagaController")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentViewController = MainViewController()
        for name in [RazerDeviceController.didUpdateNotification, EventTapManager.didUpdateNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    if name == RazerDeviceController.didUpdateNotification {
                        HIDListener.shared.setDriverModeEnabled(RazerDeviceController.shared.driverModeEnabled)
                    }
                    self?.updateStatusItem()
                }
            })
        }
        updateStatusItem()
        MappingWindowController.shared.show()

        if let path = snapshotPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.captureWindow(to: path)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MappingWindowController.shared.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        EventTapManager.shared.stop()
        HIDListener.shared.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard snapshotPath == nil else { return .terminateNow }
        guard !isTerminating else { return .terminateLater }
        isTerminating = true
        EventTapManager.shared.stop()
        DispatchQueue.main.async {
            RazerDeviceController.shared.restoreOriginalMode {
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    private func startRemappingIfPermitted() {
        let permission = PermissionManager.shared
        guard permission.hasAccessibilityPermission(), permission.hasInputMonitoringPermission() else { return }
        EventTapManager.shared.start(listenOnly: !ConfigManager.shared.getRemappingEnabled())
    }

    private func checkPermissions() {
        let permission = PermissionManager.shared
        let input = permission.hasInputMonitoringPermission()
        if input && !hadInputPermission {
            HIDListener.shared.stop()
            HIDListener.shared.start()
            RazerDeviceController.shared.refresh()
        }
        hadInputPermission = input
        if !permission.hasAccessibilityPermission() || !input {
            if EventTapManager.shared.isRunning { EventTapManager.shared.stop() }
        } else if !EventTapManager.shared.isRunning {
            startRemappingIfPermitted()
        }
        updateStatusItem()
    }

    private func updateStatusItem() {
        let hardware = RazerDeviceController.shared
        statusItem?.button?.title = hardware.batteryLevel.map { " \($0)%" } ?? ""
        let active = EventTapManager.shared.isRunning && EventTapManager.shared.isRemappingEnabled
        statusItem?.button?.toolTip = active ? "NagaController · Rimappatura attiva" : "NagaController · Rimappatura in pausa"
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            (popover.contentViewController as? MainViewController)?.refreshPermissionStatuses()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func showSettings() {
        popover.performClose(nil)
        MappingWindowController.shared.show()
    }

    private func installApplicationMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "Impostazioni…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Esci da NagaController", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        editItem.title = "Modifica"
        let edit = NSMenu(title: "Modifica")
        edit.addItem(withTitle: "Annulla", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Taglia", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Seleziona tutto", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func captureWindow(to path: String) {
        guard let view = MappingWindowController.shared.window?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fputs("Unable to capture the settings window.\n", stderr)
            NSApp.terminate(nil)
            return
        }
        view.layoutSubtreeIfNeeded()
        view.cacheDisplay(in: view.bounds, to: bitmap)
        do {
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
            print("UI snapshot: \(path)")
        } catch {
            fputs("Snapshot failed: \(error.localizedDescription)\n", stderr)
        }
        NSApp.terminate(nil)
    }
}
