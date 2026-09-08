import Foundation

@MainActor
final class RazerDeviceController {
    static let shared = RazerDeviceController()
    static let didUpdateNotification = Notification.Name("RazerDeviceControllerDidUpdate")
    private(set) var isConnected = false
    private(set) var isBusy = false
    private(set) var dpiX: Int?
    private(set) var dpiY: Int?
    private(set) var pollingRate: Int?
    private(set) var batteryLevel: Int?
    private(set) var driverModeEnabled = false
    private(set) var recoveryPending = false
    private(set) var statusMessage = "Collegare il ricevitore USB e premere Aggiorna."

    private let queue = DispatchQueue(label: "NagaController.hardware", qos: .userInitiated)
    private let worker = Worker()
    private var shuttingDown = false

    // Construction does not open the receiver or change its settings.
    private init() {}
    func refresh() { submit(.refresh) }
    func setDPI(x: Int, y: Int) { submit(.dpi(x, y)) }
    func setPollingRate(_ hz: Int) { submit(.polling(hz)) }
    func setDriverModeEnabled(_ enabled: Bool) { submit(.mode(enabled)) }

    // The app must defer termination until this callback. Failed restores retain
    // the journal for an explicit recovery attempt on a later launch.
    func restoreOriginalMode(completion: @escaping @MainActor @Sendable () -> Void = {}) {
        shuttingDown = true
        submit(.restore, completion: completion)
    }
    // Manual recovery does not stop future operations, unlike the shutdown hook.
    func recoverOriginalMode() { submit(.recover) }

    private enum Operation: Sendable {
        case refresh, dpi(Int, Int), polling(Int), mode(Bool), restore, recover
    }
    private func submit(_ operation: Operation, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard !shuttingDown || completion != nil else { return }
        // Do not enqueue stale slider writes. Shutdown restoration is the one
        // operation allowed behind an in-flight request.
        guard !isBusy || completion != nil else { return }
        isBusy = true
        statusMessage = "Comunicazione con il mouse…"
        notify()
        let worker = worker
        queue.async { [weak self] in
            let outcome = worker.perform(operation)
            DispatchQueue.main.async {
                guard let self else { completion?(); return }
                self.isBusy = false
                self.isConnected = outcome.connected
                self.dpiX = outcome.snapshot?.dpiX
                self.dpiY = outcome.snapshot?.dpiY
                self.pollingRate = outcome.snapshot?.pollingRate
                self.batteryLevel = outcome.snapshot?.batteryLevel
                self.driverModeEnabled = outcome.snapshot?.mode == 3
                self.recoveryPending = outcome.recoveryPending
                self.statusMessage = outcome.message
                self.notify()
                completion?()
            }
        }
    }
    private func notify() { NotificationCenter.default.post(name: Self.didUpdateNotification, object: self) }

    // All worker state is confined to queue. Never capture the controller in
    // transport callbacks or block the main queue waiting for hardware.
    private final class Worker: @unchecked Sendable {
        private struct Recovery: Codable {
            let identity: String
            let originalMode: UInt8
        }
        fileprivate struct Outcome {
            let connected: Bool
            let snapshot: RazerHardwareSnapshot?
            let message: String
            let recoveryPending: Bool
        }
        private let journalURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NagaController/driver-mode-recovery.json")
        private var modeChangedThisSession = false

        fileprivate func perform(_ operation: Operation) -> Outcome {
            // Shutdown without an outstanding mode change requires no USB I/O.
            if case .restore = operation, !modeChangedThisSession {
                return Outcome(connected: false, snapshot: nil, message: "Nessuna modalità da ripristinare.",
                               recoveryPending: FileManager.default.fileExists(atPath: journalURL.path))
            }
            let transport = MacRazerUSBTransport()
            var connected = false
            defer { transport.close() }
            do {
                // Validate user input before opening any device.
                if case .dpi(let x, let y) = operation { _ = try RazerCommand.setDPI(x: x, y: y) }
                if case .polling(let hz) = operation { _ = try RazerCommand.setPolling(hz) }
                try transport.open()
                connected = true
                let session = RazerHardwareSession(transport: transport)
                switch operation {
                case .refresh: break
                case .dpi(let x, let y): try session.setDPI(x: x, y: y)
                case .polling(let hz): try session.setPolling(hz)
                case .mode(let enabled):
                    let current = try session.readMode()
                    let target: UInt8 = enabled ? 3 : 0
                    if current != target {
                        if FileManager.default.fileExists(atPath: journalURL.path) {
                            let saved = try readRecovery()
                            guard saved.identity == transport.identity else {
                                throw RazerHardwareError.transport("Ripristino pendente per un altro ricevitore. Nessuna modalità modificata.")
                            }
                            guard modeChangedThisSession else {
                                throw RazerHardwareError.transport("Ripristinare esplicitamente la modalità della sessione precedente prima di modificarla.")
                            }
                        } else {
                            // Atomic journal write must succeed BEFORE mode SET.
                            try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            let data = try JSONEncoder().encode(Recovery(identity: transport.identity, originalMode: current))
                            try data.write(to: journalURL, options: .atomic)
                        }
                        // A timeout can follow a successful device write, so
                        // restoration is required even if readback fails.
                        modeChangedThisSession = true
                        try session.setMode(target)
                    }
                case .restore, .recover:
                    let saved = try readRecovery()
                    guard saved.identity == transport.identity else {
                        throw RazerHardwareError.transport("Ricollegare il ricevitore alla porta USB originale per ripristinare la modalità.")
                    }
                    if try session.readMode() != saved.originalMode { try session.setMode(saved.originalMode) }
                    try FileManager.default.removeItem(at: journalURL)
                    modeChangedThisSession = false
                }
                let snapshot = try session.readSnapshot()
                let recoveryPending = FileManager.default.fileExists(atPath: journalURL.path)
                let message = recoveryPending
                        ? (modeChangedThisSession
                            ? "Valori letti. La modalità originale verrà ripristinata all'uscita."
                            : "Ripristino pendente da una sessione precedente. Usare Ripristina modalità.")
                        : "Valori hardware letti tramite USB."
                return Outcome(connected: true, snapshot: snapshot,
                               message: ([message] + snapshot.warnings).joined(separator: "\n"),
                               recoveryPending: recoveryPending)
            } catch {
                return Outcome(connected: connected, snapshot: nil, message: error.localizedDescription,
                               recoveryPending: FileManager.default.fileExists(atPath: journalURL.path))
            }
        }
        private func readRecovery() throws -> Recovery {
            let saved = try JSONDecoder().decode(Recovery.self, from: Data(contentsOf: journalURL))
            guard saved.originalMode == 0 || saved.originalMode == 3 else {
                throw RazerHardwareError.invalidValue("Record di ripristino non valido.")
            }
            return saved
        }
    }
}
