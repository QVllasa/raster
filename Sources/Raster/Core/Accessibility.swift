#if !APPSTORE
import AppKit
import ApplicationServices
import Observation

/// Freigabe „Bedienungshilfen“ – ohne sie darf die GitHub-Version keine fremden Fenster bewegen.
/// (Die App-Store-Version nutzt stattdessen den Begleit-Kurzbefehl, siehe ShortcutEngine.swift.)
@MainActor
@Observable
final class Accessibility {
    static let shared = Accessibility()

    private(set) var isTrusted = AXIsProcessTrusted()
    @ObservationIgnored private var timer: Timer?

    private init() {
        startPollingIfNeeded()
    }

    /// Zeigt die Systemabfrage (nur solange die Freigabe fehlt).
    func request() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        isTrusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        startPollingIfNeeded()
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Solange die Freigabe fehlt, alle 1,5 s nachsehen – die Oberfläche aktualisiert sich dann von selbst.
    private func startPollingIfNeeded() {
        guard !isTrusted, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            MainActor.assumeIsolated {
                let shared = Accessibility.shared
                shared.isTrusted = AXIsProcessTrusted()
                if shared.isTrusted {
                    shared.timer?.invalidate()
                    shared.timer = nil
                }
            }
        }
    }
}
#endif
