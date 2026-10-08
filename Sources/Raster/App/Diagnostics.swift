import AppKit

/// Diagnose von der Kommandozeile, ohne das vorderste Fenster des Users anzufassen:
/// GitHub-Version `Raster --ax-probe <pid>` (Accessibility), Store-Version `Raster --shortcut-probe <pid>`
/// (Begleit-Kurzbefehl in der Sandbox). Beide verschieben das erste Fenster der App kurz und stellen es zurück.
enum Diagnostics {
    #if APPSTORE
    static func shortcutProbe(pid: pid_t) -> Int32 {
        let entries = WindowList.all(excluding: ProcessInfo.processInfo.processIdentifier)
        print("Fensterliste:", entries.count, "Fenster,", Set(entries.map(\.pid)).count, "Apps")
        guard let entry = WindowList.frontmost(of: pid, in: entries) else {
            print("✗ kein Fenster der PID \(pid) in der Liste")
            return 1
        }
        let window = ShortcutWindow(entry: entry)
        print("Fenster von \(entry.app) (\(entry.id)):", entry.bounds)
        let moved = entry.bounds.offsetBy(dx: 40, dy: 30)
        print("Eingabe:", ShortcutPayload.json(app: entry.app, current: entry.bounds.origin, target: moved))
        let group = DispatchGroup()
        group.enter()
        var outcome: Result<CGRect?, Error> = .success(nil)
        Task.detached {
            defer { group.leave() }
            do {
                let after = try await window.setFrame(moved)
                _ = try await window.setFrame(entry.bounds)
                outcome = .success(after)
            } catch {
                outcome = .failure(error)
            }
        }
        group.wait()
        switch outcome {
        case .success(let after):
            print("Rahmen nachher:", after.map { "\($0)" } ?? "unbekannt")
            let ok = after.map { $0.isClose(to: moved) } ?? false
            print(ok ? "✓ Fenster lässt sich über den Kurzbefehl bewegen" : "✗ Fenster hat sich nicht bewegt")
            return ok ? 0 : 1
        case .failure(let error):
            print("✗ Fehler:", error)
            return 2
        }
    }
    #else
    static func axProbe(pid: pid_t) -> Int32 {
        print("Freigabe (AXIsProcessTrusted):", AXIsProcessTrusted())
        MainActor.assumeIsolated {
            for screen in ScreenInfo.current() {
                let windows = WindowManager.shared.visibleWindows(on: screen)
                print("Bildschirm \(screen.name): \(windows.count) Fenster zugeordnet (\(Set(windows.map(\.pid)).count) Apps)")
            }
        }
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)
        print("AXWindows-Abfrage:", error.rawValue, error == .success ? "(ok)" : error == .cannotComplete ? "(cannotComplete – Verbindung blockiert)" : error == .apiDisabled ? "(apiDisabled – keine Freigabe)" : "")
        let windows = AXWindow.all(of: pid)
        print("Fenster der App:", windows.count)
        guard let window = windows.first(where: { $0.frame != nil }), let before = window.frame else {
            print("✗ kein lesbares Fenster")
            return 1
        }
        print("Rahmen vorher:", before, "verschiebbar:", window.canMove)
        let moved = before.offsetBy(dx: 40, dy: 30)
        window.apply(moved)
        let after = window.frame ?? .null
        print("Rahmen nachher:", after)
        window.apply(before)
        let success = after.isClose(to: moved)
        print(success ? "✓ Fenster lässt sich bewegen" : "✗ Fenster hat sich nicht bewegt")
        return success ? 0 : 1
    }
    #endif
}
