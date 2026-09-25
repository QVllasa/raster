import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private let prefs = Preferences.shared
    private let hotKeys = HotKeyCenter.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(prefs: prefs)
        WindowManager.shared.onMissingPermission = { [weak self] in self?.controller.openPanel() }
        hotKeys.onAction = { action in WindowManager.shared.perform(action) }
        registerShortcuts()
        firstRun()

        // Diagnose: `--open` bzw. `--settings` öffnet das Panel direkt nach dem Start.
        if CommandLine.arguments.contains("--open") || CommandLine.arguments.contains("--settings") {
            let route: Route = CommandLine.arguments.contains("--settings") ? .settings : .overview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.controller.openPanel(route: route) }
        }
    }

    /// Meldet die Kürzel an und bei jeder Änderung in den Einstellungen neu.
    private func registerShortcuts() {
        withObservationTracking {
            hotKeys.register(prefs.shortcuts)
        } onChange: { [weak self] in
            Task { @MainActor in self?.registerShortcuts() }
        }
    }

    /// Beim allerersten Start: als Anmeldeobjekt eintragen (startet mit dem Mac) und um die Freigabe bitten.
    private func firstRun() {
        let key = "firstRunDone"
        guard Bundle.main.bundleURL.pathExtension == "app", !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        prefs.launchAtLogin = true
        if !Accessibility.shared.isTrusted {
            Accessibility.shared.request()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.controller.openPanel() }
        }
    }
}
