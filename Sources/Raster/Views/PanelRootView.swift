import AppKit
import SwiftUI

enum Route: Hashable {
    case overview
    case settings
}

@MainActor
@Observable
final class PanelState {
    var route: Route = .overview
    /// Name des Zielbildschirms und Zahl seiner Fenster (für die Kopfzeile).
    var screenName = ""
    var windowCount = 0
    var screenCount = 1
    /// Aktion, deren Kürzel gerade aufgenommen wird.
    private(set) var recording: WindowAction?

    @ObservationIgnored var close: () -> Void = {}
    @ObservationIgnored var perform: (WindowAction) -> Void = { _ in }
    @ObservationIgnored private var keyMonitor: Any?

    func go(_ route: Route) {
        stopRecording()
        withAnimation(.smooth(duration: 0.32)) { self.route = route }
    }

    func refreshSummary() {
        let summary = WindowManager.shared.targetScreenSummary()
        screenName = summary.name
        windowCount = summary.windowCount
        screenCount = max(1, NSScreen.screens.count)
    }

    // MARK: Kürzel-Aufnahme

    /// Nimmt die nächste Tastenkombination für `action` auf. Solange sind alle globalen Kürzel abgemeldet,
    /// damit z. B. ⌘← aufgenommen statt ausgeführt wird. Esc bricht ab, ⌫ löscht das Kürzel.
    func startRecording(_ action: WindowAction, prefs: Preferences, onInvalid: @escaping () -> Void) {
        stopRecording()
        recording = action
        HotKeyCenter.shared.suspendForRecording()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let shortcut = Shortcut(event: event)
            let keyCode = event.keyCode
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, let action = self.recording else { return false }
                let bare = shortcut.flags.isEmpty
                if bare && keyCode == 53 {
                    self.stopRecording()
                } else if bare && (keyCode == 51 || keyCode == 117) {
                    prefs.setShortcut(nil, for: action)
                    self.stopRecording()
                } else if shortcut.isValid {
                    prefs.setShortcut(shortcut, for: action)
                    self.stopRecording()
                } else {
                    onInvalid()
                }
                return true
            }
            return consumed ? nil : event
        }
    }

    func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if recording != nil {
            recording = nil
            HotKeyCenter.shared.resumeAfterRecording()
        }
    }
}

struct PanelRootView: View {
    @Environment(PanelState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            PanelHeader()
            ZStack(alignment: .top) {
                switch state.route {
                case .overview:
                    ScrollView { LayoutsView().padding(.bottom, 2) }
                        .scrollIndicators(.never)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .settings:
                    ScrollView { SettingsView().padding(.bottom, 2) }
                        .scrollIndicators(.never)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .frame(width: PanelMetrics.width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .onExitCommand { state.close() }
    }
}

struct PanelHeader: View {
    @Environment(PanelState.self) private var state
    @Environment(HotKeyCenter.self) private var hotKeys

    var body: some View {
        HStack(spacing: 10) {
            switch state.route {
            case .overview:
                AppGlyph()
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "Raster").font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if hotKeys.isPaused {
                    GlassIconButton(symbol: "play.fill", help: "Tastenkürzel fortsetzen") { hotKeys.isPaused = false }
                }
                GlassIconButton(symbol: "gearshape", help: "Einstellungen") { state.go(.settings) }
            case .settings:
                GlassIconButton(symbol: "chevron.left", help: "Zurück") { state.go(.overview) }
                Text("Einstellungen").font(.title3.weight(.semibold))
                Spacer()
            }
        }
        .frame(height: 38)
    }

    private var subtitle: String {
        if hotKeys.isPaused { return String(localized: "Tastenkürzel pausiert") }
        let windows = state.windowCount == 1 ? String(localized: "1 Fenster") : String(localized: "\(state.windowCount) Fenster")
        return state.screenName.isEmpty ? windows : "\(state.screenName) · \(windows)"
    }
}
