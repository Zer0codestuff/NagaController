import Foundation

@main
struct TestRunner {
    static func main() {
        do {
            let core = try InputEngineTests.run()
            print("Input engine: \(core) checks passed")
            let system = try SystemActionTests.run()
            print("System actions: \(system) checks passed")
            let hardware = try HardwareProtocolTests.run()
            print("Hardware protocol: \(hardware) checks passed")
            print("PASS: \(core + system + hardware) checks")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
