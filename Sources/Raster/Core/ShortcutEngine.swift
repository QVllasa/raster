#if APPSTORE
import AppKit
import Observation

/// Fenster der App-Store-Version: Rahmen aus der Fensterliste, bewegt über den Begleit-Kurzbefehl.
/// Die Sandbox erlaubt keine Accessibility-Zugriffe auf fremde Fenster; Apples Kurzbefehl-Aktionen
/// „Fenster suchen / bewegen / Größe ändern“ dürfen das.
struct ShortcutWindow: WindowHandle {
    let entry: WindowEntry

    var key: AnyHashable { entry.id }
    var pid: pid_t { entry.pid }
    var frame: CGRect? { WindowList.entry(id: entry.id)?.bounds ?? entry.bounds }
    var canMove: Bool { true }
    /// Ein Vollbildfenster füllt genau einen Bildschirm (ohne Menüleiste und Dock).
    var isFullScreen: Bool {
        MainActor.assumeIsolated { ScreenInfo.current().contains { $0.frame.isClose(to: entry.bounds) } }
    }

    func setFrame(_ rect: CGRect) async throws -> CGRect? {
        let current = frame ?? entry.bounds
        try await ShortcutRunner.run(input: ShortcutPayload.json(app: entry.app, current: current.origin, target: rect))
        return WindowList.entry(id: entry.id)?.bounds
    }
}

enum ShortcutError: Error, Equatable {
    /// Der Kurzbefehl „Raster“ fehlt in der Kurzbefehle-App.
    case notInstalled
    /// Der Nutzer hat Raster die Steuerung von Kurzbefehlen verweigert (Systemeinstellungen → Automation).
    case automationDenied
    case failed(code: Int, message: String)
}

/// Führt den Kurzbefehl über Apple Events an „Shortcuts Events“ aus – nacheinander auf einer eigenen Warteschlange,
/// damit mehrere Kürzel kurz hintereinander nicht durcheinandergeraten und der Hauptthread frei bleibt.
enum ShortcutRunner {
    private static let queue = DispatchQueue(label: "io.github.qvllasa.raster.shortcut")

    static func run(input: String) async throws {
        _ = try await execute(ShortcutPayload.runScript(input: input))
    }

    static func isInstalled() async throws -> Bool {
        try await execute(ShortcutPayload.existsScript()).booleanValue
    }

    private static func execute(_ source: String) async throws -> NSAppleEventDescriptor {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try executeNow(source)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func executeNow(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else { throw ShortcutError.failed(code: 0, message: "Skript ungültig") }
        var info: NSDictionary?
        let result = script.executeAndReturnError(&info)
        guard let info else { return result }
        let code = info[NSAppleScript.errorNumber] as? Int ?? 0
        let message = info[NSAppleScript.errorMessage] as? String ?? ""
        NSLog("Raster: Kurzbefehl fehlgeschlagen (%d): %@", code, message)
        switch code {
        case -1743: throw ShortcutError.automationDenied
        case -1728: throw ShortcutError.notInstalled
        default: throw ShortcutError.failed(code: code, message: message)
        }
    }
}

/// Einrichtungsstand der Store-Version: Kurzbefehl vorhanden und Automation erlaubt?
@MainActor
@Observable
final class ShortcutSetup {
    static let shared = ShortcutSetup()

    enum Status: Equatable {
        case unknown, checking, ready, notInstalled, automationDenied
        case error(String)
    }

    private(set) var status: Status = .unknown

    var isReady: Bool { status == .ready }

    private init() {}

    /// Fragt „Shortcuts Events“, ob der Kurzbefehl existiert. Beim ersten Mal zeigt macOS die Automations-Abfrage.
    func refresh() async {
        guard status != .checking else { return }
        status = .checking
        do {
            status = try await ShortcutRunner.isInstalled() ? .ready : .notInstalled
        } catch ShortcutError.automationDenied {
            status = .automationDenied
        } catch ShortcutError.notInstalled {
            status = .notInstalled
        } catch ShortcutError.failed(let code, let message) {
            status = .error("\(message) (\(code))")
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    /// Ordnet einen Fehler beim Anordnen dem Einrichtungsstand zu.
    func note(_ error: Error) {
        switch error as? ShortcutError {
        case .automationDenied?: status = .automationDenied
        case .notInstalled?: status = .notInstalled
        case .failed(let code, let message)?: status = .error("\(message) (\(code))")
        case nil: status = .error(error.localizedDescription)
        }
    }

    /// Öffnet die mitgelieferte Kurzbefehl-Datei – die Kurzbefehle-App bietet an, sie hinzuzufügen.
    func install() {
        guard let url = Bundle.main.url(forResource: ShortcutPayload.shortcutName, withExtension: "shortcut") else {
            NSLog("Raster: Kurzbefehl-Datei fehlt im Paket")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif
