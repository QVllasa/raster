import AppKit

/// Führt Aktionen an echten Fenstern aus: Zielbildschirm bestimmen, planen, Rahmen setzen.
/// Die GitHub-Version greift per Accessibility zu (AXWindow), die App-Store-Version über den
/// Begleit-Kurzbefehl (ShortcutWindow) – der Ablauf ist derselbe.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    /// Wird aufgerufen, wenn eine Aktion an fehlender Einrichtung scheitert (Panel mit Hinweis öffnen).
    var onSetupNeeded: () -> Void = {}

    private let prefs = Preferences.shared
    /// Fenstergröße vor dem ersten Einrasten – für „Wiederherstellen“.
    private var original: [AnyHashable: CGRect] = [:]
    /// Rechteck, das Raster zuletzt gesetzt hat – solange das Fenster so steht, gilt es als eingerastet.
    private var snapped: [AnyHashable: CGRect] = [:]
    private var last: (key: AnyHashable, action: WindowAction, step: Int)?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    /// Aktionen laufen nacheinander – beim Kurzbefehl dauert eine gut eine halbe Sekunde.
    private var pending: Task<Void, Never>?

    private init() {}

    func perform(_ action: WindowAction) {
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            await self?.execute(action)
        }
    }

    private func execute(_ action: WindowAction) async {
        debugLog("Aktion \(action.rawValue), vorne \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "-") (PID \(Self.frontmostPID().map(String.init) ?? "-"))")
        guard await isReady() else {
            onSetupNeeded()
            return
        }
        let screens = ScreenInfo.current()
        guard !screens.isEmpty else { return }
        do {
            if action.group == .allWindows {
                try await tile(action, screens: screens)
            } else {
                try await moveFocusedWindow(action, screens: screens)
            }
        } catch {
            debugLog("Fehler: \(error)")
            noteFailure(error)
            NSSound.beep()
        }
    }

    // MARK: Ein Fenster

    private func moveFocusedWindow(_ action: WindowAction, screens: [ScreenInfo]) async throws {
        guard let pid = Self.frontmostPID(), pid != ownPID,
              let window = focusedWindow(of: pid), !window.isFullScreen, window.canMove,
              let frame = window.frame else {
            debugLog("kein bewegbares Fenster gefunden")
            NSSound.beep()
            return
        }
        let key = window.key
        let isSnapped = snapped[key].map { Self.approximately($0, frame) } ?? false
        let repeatStep = isSnapped && last?.key == key && last?.action == action ? last?.step : nil
        let visible = screens.map(\.visible)
        let target = targetScreenIndex(screens: screens, windowFrame: frame)
        debugLog("Fenster \(frame), Zielbildschirm \(target), Wiederholung \(repeatStep.map(String.init) ?? "nein")")

        switch WindowPlanner.plan(action: action, window: frame, screens: visible, targetScreen: target,
                                  gap: prefs.gap, behavior: prefs.repeatBehavior, repeatStep: repeatStep) {
        case .restore:
            guard let previous = original[key] else { NSSound.beep(); return }
            _ = try await window.setFrame(LayoutMath.fit(previous, into: visible))
            original[key] = nil
            snapped[key] = nil
            last = nil
        case let .frame(rect, step, screen)?:
            let after = try await apply(rect, to: window, visible: visible[screen])
            // Hat sich nichts bewegt (Fenster lehnt Änderungen ab), nichts merken – sonst gälte es als eingerastet.
            guard Self.didMove(before: frame, after: after, target: rect) else {
                debugLog("Fenster hat die Änderung abgelehnt")
                NSSound.beep()
                return
            }
            if !isSnapped { original[key] = frame }
            snapped[key] = after
            last = (key, action, step)
        case nil:
            NSSound.beep()
        }
    }

    /// Setzt das Fenster und korrigiert, falls es wegen einer Mindestgröße größer geblieben ist.
    private func apply(_ rect: CGRect, to window: any WindowHandle, visible: CGRect) async throws -> CGRect {
        guard let actual = try await window.setFrame(rect) else { return rect }
        guard let fixed = LayoutMath.correction(actual: actual, target: rect, visible: visible) else { return actual }
        return try await window.setFrame(fixed) ?? fixed
    }

    // MARK: Alle Fenster eines Bildschirms

    private func tile(_ action: WindowAction, screens: [ScreenInfo]) async throws {
        let focused = Self.frontmostPID().flatMap { focusedWindow(of: $0) }
        let screen = screens[targetScreenIndex(screens: screens, windowFrame: focused?.frame)]
        let found = visibleWindows(on: screen)
        // Das fokussierte Fenster kommt zuerst (oben links bzw. „Fokus“ links), der Rest in Z-Reihenfolge.
        let order = Self.focusFirst(found.indices.map { $0 }, focused: found.firstIndex { $0.key == focused?.key })
        let windows = order.map { found[$0] }
        guard !windows.isEmpty else { NSSound.beep(); return }

        let rects: [CGRect]
        switch action {
        case .tileColumns: rects = LayoutMath.columns(count: windows.count, in: screen.visible, gap: prefs.gap)
        case .focusStack: rects = LayoutMath.focusStack(count: windows.count, in: screen.visible, gap: prefs.gap)
        default: rects = LayoutMath.grid(count: windows.count, in: screen.visible, gap: prefs.gap)
        }
        for (window, rect) in zip(windows, rects) {
            guard let frame = window.frame else { continue }
            let key = window.key
            let isSnapped = snapped[key].map { Self.approximately($0, frame) } ?? false
            if !isSnapped { original[key] = frame }
            snapped[key] = try await apply(rect, to: window, visible: screen.visible)
        }
        last = nil
    }

    // MARK: Fenster finden (je nach Version)

    #if APPSTORE
    private func isReady() async -> Bool {
        let setup = ShortcutSetup.shared
        if !setup.isReady { await setup.refresh() }
        return setup.isReady
    }

    private func noteFailure(_ error: Error) {
        ShortcutSetup.shared.note(error)
        if !ShortcutSetup.shared.isReady { onSetupNeeded() }
    }

    private func focusedWindow(of pid: pid_t) -> (any WindowHandle)? {
        WindowList.frontmost(of: pid, in: WindowList.all(excluding: ownPID)).map(ShortcutWindow.init)
    }

    /// Sichtbare Standardfenster eines Bildschirms, vorderstes zuerst.
    func visibleWindows(on screen: ScreenInfo) -> [any WindowHandle] {
        WindowList.entries(on: screen, excluding: ownPID).map(ShortcutWindow.init)
    }
    #else
    private func isReady() async -> Bool {
        guard Accessibility.shared.isTrusted else {
            Accessibility.shared.request()
            return false
        }
        return true
    }

    private func noteFailure(_ error: Error) {}

    private func focusedWindow(of pid: pid_t) -> (any WindowHandle)? { AXWindow(focusedOf: pid) }

    /// Sichtbare Standardfenster eines Bildschirms, vorderstes zuerst.
    func visibleWindows(on screen: ScreenInfo) -> [any WindowHandle] {
        let entries = WindowList.entries(on: screen, excluding: ownPID)
        var byApp: [pid_t: [AXWindow]] = [:]
        for pid in Set(entries.map(\.pid)) { byApp[pid] = AXWindow.all(of: pid) }
        let candidates = byApp.values.flatMap { $0 }
            .compactMap { window in window.frame.map { (window: window, frame: $0) } }
        let matches = Self.match(entries: entries.map { ($0.pid, $0.bounds) },
                                 windows: candidates.map { ($0.window.pid, $0.frame) })
        return matches.compactMap { index -> AXWindow? in
            guard let index else { return nil }
            let window = candidates[index].window
            return window.isStandard && !window.isMinimized && !window.isFullScreen ? window : nil
        }
    }
    #endif

    /// Ordnet jedem Eintrag der Fensterliste das AX-Fenster derselben App mit gleichem Rahmen (±2 pt) zu;
    /// jedes AX-Fenster höchstens einmal. nil = kein passendes Fenster.
    nonisolated static func match(entries: [(pid: pid_t, bounds: CGRect)], windows: [(pid: pid_t, frame: CGRect)]) -> [Int?] {
        var used = Set<Int>()
        return entries.map { entry in
            let hit = windows.indices.first { i in
                !used.contains(i) && windows[i].pid == entry.pid && windows[i].frame.isClose(to: entry.bounds)
            }
            if let hit { used.insert(hit) }
            return hit
        }
    }

    /// Kopfzeile im Panel: Name des Zielbildschirms und Zahl der sichtbaren Fenster (ohne Freigabe möglich).
    func targetScreenSummary() -> (name: String, windowCount: Int) {
        let screens = ScreenInfo.current()
        guard !screens.isEmpty else { return (String(localized: "Kein Bildschirm"), 0) }
        let index = ScreenGeometry.screenIndex(containing: ScreenInfo.mouseLocation(), in: screens.map(\.frame))
        return (screens[index].name, WindowList.entries(on: screens[index], excluding: ownPID).count)
    }

    // MARK: Hilfen

    static func frontmostPID() -> pid_t? { WindowList.frontmostPID() }

    private func targetScreenIndex(screens: [ScreenInfo], windowFrame: CGRect?) -> Int {
        if prefs.targetScreen == .window, let windowFrame {
            return ScreenGeometry.screenIndex(for: windowFrame, in: screens.map(\.frame))
        }
        return ScreenGeometry.screenIndex(containing: ScreenInfo.mouseLocation(), in: screens.map(\.frame))
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        if ProcessInfo.processInfo.environment["RASTER_DEBUG"] != nil { print("[Raster]", message()) ; fflush(stdout) }
    }

    static func approximately(_ a: CGRect, _ b: CGRect) -> Bool { a.isClose(to: b) }

    /// Stellt `focused` an den Anfang, die übrige Reihenfolge bleibt.
    nonisolated static func focusFirst<T: Equatable>(_ items: [T], focused: T?) -> [T] {
        guard let focused, let index = items.firstIndex(of: focused) else { return items }
        var result = items
        result.remove(at: index)
        return [focused] + result
    }

    /// Erfolgreich, wenn sich das Fenster verändert hat oder schon am Ziel stand.
    nonisolated static func didMove(before: CGRect, after: CGRect, target: CGRect) -> Bool {
        !before.isClose(to: after) || before.isClose(to: target)
    }
}
