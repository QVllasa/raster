import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let prefs: Preferences
    private let state = PanelState()
    private(set) lazy var panel: GlassPanel = makePanel()
    private var outsideClickMonitor: Any?

    init(prefs: Preferences) {
        self.prefs = prefs
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Raster")
            image?.isTemplate = true
            button.image = image?.withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(String(localized: "Raster Fensteranordnung"))
            button.toolTip = String(localized: "Raster – Fenster anordnen")
        }
        state.close = { [weak self] in self?.closePanel() }
        state.perform = { [weak self] action in
            // Erst schließen, damit das Zielfenster wieder ungestört vorne liegt.
            self?.closePanel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { WindowManager.shared.perform(action) }
        }
        observePause()
    }

    /// Pausierte Kürzel: Symbol wird ausgegraut.
    private func observePause() {
        withObservationTracking {
            statusItem.button?.appearsDisabled = HotKeyCenter.shared.isPaused
        } onChange: { [weak self] in
            Task { @MainActor in self?.observePause() }
        }
    }

    // MARK: Panel

    private func makePanel() -> GlassPanel {
        let root = PanelRootView()
            .environment(prefs)
            .environment(state)
            .environment(HotKeyCenter.shared)
            .environment(Accessibility.shared)
        return GlassPanel(rootView: root)
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            panel.isVisible ? closePanel() : openPanel()
        }
    }

    func openPanel(route: Route? = nil) {
        if let route { state.route = route }
        state.refreshSummary()
        prefs.syncLoginItem()
        positionPanel()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
        statusItem.button?.highlight(true)

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.closePanel() }
            }
        }
    }

    func closePanel() {
        guard panel.isVisible else { return }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        state.stopRecording()
        statusItem.button?.highlight(false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.outsideClickMonitor == nil else { return }
                self.panel.orderOut(nil)
                self.state.route = .overview
            }
        })
    }

    private func positionPanel() {
        guard let buttonWindow = statusItem.button?.window else { return }
        let anchor = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height = min(PanelMetrics.height(screens: state.screenCount), visible.height - 16)
        let size = NSSize(width: PanelMetrics.width, height: height)
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = anchor.minY - size.height - 6
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    // MARK: Kontextmenü

    private func showMenu() {
        closePanel()
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item(String(localized: "Raster öffnen"), #selector(menuOpen)))
        menu.addItem(item(String(localized: "Einstellungen …"), #selector(menuSettings), key: ","))
        let pause = item(String(localized: "Tastenkürzel pausieren"), #selector(menuTogglePause))
        pause.state = HotKeyCenter.shared.isPaused ? .on : .off
        menu.addItem(pause)
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Raster beenden"), #selector(menuQuit), key: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in self.statusItem.menu = nil }
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func menuOpen() { openPanel(route: .overview) }
    @objc private func menuSettings() { openPanel(route: .settings) }
    @objc private func menuTogglePause() { HotKeyCenter.shared.isPaused.toggle() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}
