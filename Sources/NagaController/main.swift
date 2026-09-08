import Cocoa

let arguments = CommandLine.arguments
if arguments.contains("--diagnose") || arguments.contains("--diagnose-file") || arguments.contains("--verify-hardware") {
    var output: URL?
    if let index = arguments.firstIndex(of: "--diagnose-file"), arguments.indices.contains(index + 1) {
        output = URL(fileURLWithPath: arguments[index + 1])
    }
    exit(NagaDiagnostics.run(verifyWrites: arguments.contains("--verify-hardware"), output: output))
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
