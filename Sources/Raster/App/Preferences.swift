import Foundation
import Observation
import ServiceManagement

/// Welcher Bildschirm bei einem Kürzel gilt.
enum TargetScreenMode: String, CaseIterable, Identifiable {
    case mouse, window

    var id: String { rawValue }
    var title: String { self == .mouse ? "Maus" : "Aktives Fenster" }
}

/// Was passiert, wenn dieselbe Hälfte noch einmal gedrückt wird.
enum RepeatBehavior: String, CaseIterable, Identifiable {
    case none, cycleWidth, moveToNeighbor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Nichts"
        case .cycleWidth: "Breite wechseln (½ → ⅔ → ⅓)"
        case .moveToNeighbor: "Zum Nachbarbildschirm"
        }
    }
}

@Observable
final class Preferences {
    static let shared = Preferences(defaults: .standard)

    @ObservationIgnored private let defaults: UserDefaults

    var targetScreen: TargetScreenMode {
        didSet { defaults.set(targetScreen.rawValue, forKey: "targetScreen") }
    }
    var repeatBehavior: RepeatBehavior {
        didSet { defaults.set(repeatBehavior.rawValue, forKey: "repeatBehavior") }
    }
    /// Abstand zwischen Fenstern und zum Rand in Punkt (0–24).
    var gap: Double {
        didSet { defaults.set(gap, forKey: "gap") }
    }
    /// Aktuelle Belegung; eine fehlende Aktion hat kein Kürzel.
    private(set) var shortcuts: [WindowAction: Shortcut]
    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, !isSyncingLoginItem else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Raster: Anmeldeobjekt konnte nicht geändert werden: \(error)")
            }
            syncLoginItem()
        }
    }
    /// macOS hat den Autostart registriert, wartet aber auf Genehmigung in den Systemeinstellungen.
    private(set) var loginItemNeedsApproval = false
    @ObservationIgnored private var isSyncingLoginItem = false

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            "targetScreen": TargetScreenMode.mouse.rawValue,
            "repeatBehavior": RepeatBehavior.cycleWidth.rawValue,
            "gap": 0.0,
        ])
        targetScreen = TargetScreenMode(rawValue: defaults.string(forKey: "targetScreen") ?? "") ?? .mouse
        repeatBehavior = RepeatBehavior(rawValue: defaults.string(forKey: "repeatBehavior") ?? "") ?? .cycleWidth
        gap = defaults.double(forKey: "gap")
        shortcuts = Self.loadShortcuts(from: defaults)
        let status = SMAppService.mainApp.status
        launchAtLogin = Self.isLoginItemOn(status)
        loginItemNeedsApproval = status == .requiresApproval
    }

    /// „Genehmigung erforderlich“ zählt als an – sonst würde der gerade angelegte Eintrag sofort wieder abgemeldet.
    static func isLoginItemOn(_ status: SMAppService.Status) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    /// Gleicht den Schalter mit dem tatsächlichen Systemzustand ab, ohne erneut zu (de)registrieren.
    func syncLoginItem() {
        let status = SMAppService.mainApp.status
        isSyncingLoginItem = true
        launchAtLogin = Self.isLoginItemOn(status)
        loginItemNeedsApproval = status == .requiresApproval
        isSyncingLoginItem = false
    }

    /// Setzt oder löscht ein Kürzel. Hatte eine andere Aktion dieselbe Kombination, verliert sie sie.
    func setShortcut(_ shortcut: Shortcut?, for action: WindowAction) {
        var map = shortcuts
        if let shortcut {
            for (other, existing) in map where existing == shortcut && other != action {
                map[other] = nil
            }
        }
        map[action] = shortcut
        shortcuts = map
        saveShortcuts()
    }

    func resetShortcuts() {
        shortcuts = Dictionary(uniqueKeysWithValues: WindowAction.allCases.compactMap { action in
            action.defaultShortcut.map { (action, $0) }
        })
        defaults.removeObject(forKey: "shortcuts")
    }

    // MARK: Speichern

    /// Gespeichert werden alle Aktionen, gelöschte als `null` – so fallen sie nicht auf den Standard zurück.
    private func saveShortcuts() {
        var stored: [String: Shortcut?] = [:]
        for action in WindowAction.allCases { stored[action.rawValue] = .some(shortcuts[action]) }
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: "shortcuts") }
    }

    private static func loadShortcuts(from defaults: UserDefaults) -> [WindowAction: Shortcut] {
        let stored = defaults.data(forKey: "shortcuts")
            .flatMap { try? JSONDecoder().decode([String: Shortcut?].self, from: $0) } ?? [:]
        var map: [WindowAction: Shortcut] = [:]
        for action in WindowAction.allCases {
            if let entry = stored[action.rawValue] {
                if let shortcut = entry { map[action] = shortcut }
            } else if let fallback = action.defaultShortcut {
                map[action] = fallback
            }
        }
        return map
    }
}
