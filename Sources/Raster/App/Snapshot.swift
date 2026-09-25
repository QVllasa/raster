import AppKit
import SwiftUI

/// `Raster --snapshot <ordner> [--light]` zeigt das Panel mit Übersicht und Einstellungen
/// und speichert Bildschirmfotos des eigenen Fensters (für Doku und Sichtprüfung).
@MainActor
final class Snapshot {
    private let directory: URL
    private let state = PanelState()
    private var panel: GlassPanel!

    init(directory: String) {
        self.directory = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func start() {
        if CommandLine.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
        if CommandLine.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let root = PanelRootView()
            .environment(Preferences.shared)
            .environment(state)
            .environment(HotKeyCenter.shared)
            .environment(Accessibility.shared)
        panel = GlassPanel(rootView: root)
        state.refreshSummary()
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let height = PanelMetrics.height(screens: state.screenCount)
        panel.setFrame(NSRect(x: screen.maxX - PanelMetrics.width - 16, y: screen.maxY - height - 6,
                              width: PanelMetrics.width, height: height), display: true)
        panel.orderFrontRegardless()

        let suffix = CommandLine.arguments.contains("--light") ? "-hell" : "-dunkel"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            capture(name: "uebersicht" + suffix)
            state.route = .settings
            try? await Task.sleep(for: .seconds(1.2))
            capture(name: "einstellungen" + suffix)
            NSApp.terminate(nil)
        }
    }

    private func capture(name: String) {
        guard let image = Self.captureImage(of: panel) else {
            print("Aufnahme fehlgeschlagen:", name)
            return
        }
        Self.write(image, to: directory.appendingPathComponent("\(name).png"))
    }

    /// Nimmt das eigene Fenster samt Schreibtisch dahinter auf (ohne Bildschirmaufnahme-Freigabe möglich).
    static func captureImage(of panel: NSWindow, margin: CGFloat = 24) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
              let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(symbol, to: Fn.self)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let f = panel.frame.insetBy(dx: -margin, dy: -margin)
        let rect = CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)
        // onScreenBelowWindow (4) | includingWindow (8): Panel samt Schreibtisch dahinter; bestResolution = 8
        return fn(rect, 4 | 8, UInt32(panel.windowNumber), 8)?.takeRetainedValue()
    }

    static func write(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("gespeichert:", url.path, image.width, "x", image.height)
    }
}
