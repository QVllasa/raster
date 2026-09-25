import AppKit
import SwiftUI

enum PanelMetrics {
    static let width: CGFloat = 384
    static let height: CGFloat = 640
    /// Mit mehreren Bildschirmen kommt die Gruppe „Bildschirme“ dazu.
    static func height(screens: Int) -> CGFloat { screens > 1 ? 770 : height }
    static let cornerRadius: CGFloat = 30
}

/// Rahmenloses, schwebendes Panel mit echtem Liquid-Glass-Hintergrund (NSGlassEffectView).
/// `nonactivatingPanel`: Ein Klick darauf aktiviert Raster nicht – das vorderste Fenster bleibt das Ziel.
final class GlassPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let glass = NSGlassEffectView()
        glass.cornerRadius = PanelMetrics.cornerRadius
        glass.style = .regular
        // Leichte Tönung, damit Text auch über unruhigem Hintergrund gut lesbar bleibt.
        glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.28)
        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []
        glass.contentView = host
        contentView = glass
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
