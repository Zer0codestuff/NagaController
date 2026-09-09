import Cocoa
import SwiftUI

enum UIStyle {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.48, green: 0.81, blue: 0.40, alpha: 1)
            : NSColor(srgbRed: 0.16, green: 0.48, blue: 0.24, alpha: 1)
    })
    static let selection = accent.opacity(0.11)
    static let separator = Color.primary.opacity(0.09)
    static let inset = Color.primary.opacity(0.035)

    static func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: weight))
    }
}

struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct StatusDot: View {
    let active: Bool
    var body: some View {
        Circle().fill(active ? UIStyle.accent : Color.secondary.opacity(0.5))
            .frame(width: 6, height: 6).accessibilityHidden(true)
    }
}
