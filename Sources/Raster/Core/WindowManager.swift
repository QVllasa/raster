import AppKit

/// Eindeutiger Schlüssel eines Fensters über App-Grenzen hinweg – nur öffentliche API (CFEqual/CFHash).
struct WindowKey: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Führt Aktionen an echten Fenstern aus: Zielbildschirm bestimmen, planen, per Accessibility setzen.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    /// Wird aufgerufen, wenn eine Aktion an der fehlenden Freigabe scheitert (Panel mit Hinweis öffnen).
    var onMissingPermission: () -> Void = {}

    private let prefs = Preferences.shared
    /// Fenstergröße vor dem ersten Einrasten – für „Wiederherstellen“.
    private var original: [WindowKey: CGRect] = [:]
    /// Rechteck, das Raster zuletzt gesetzt hat – solange das Fenster so steht, gilt es als eingerastet.
    private var snapped: [WindowKey: CGRect] = [:]
    private var last: (key: WindowKey, action: WindowAction, step: Int)?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private init() {}

    func perform(_ action: WindowAction) {
        debugLog("Aktion \(action.rawValue), Freigabe \(Accessibility.shared.isTrusted), vorne \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "-") (PID \(Self.frontmostPID().map(String.init) ?? "-"))")
        guard Accessibility.shared.isTrusted else {
            Accessibility.shared.request()
            onMissingPermission()
            return
        }
        let screens = ScreenInfo.current()
        guard !screens.isEmpty else { return }
        if action.group == .allWindows {
            tile(action, screens: screens)
        } else {
            moveFocusedWindow(action, screens: screens)
        }
    }

    // MARK: Ein Fenster

    private func moveFocusedWindow(_ action: WindowAction, screens: [ScreenInfo]) {
        guard let pid = Self.frontmostPID(), pid != ownPID,
              let window = AXWindow(focusedOf: pid), !window.isFullScreen, window.canMove,
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
            window.setFrame(LayoutMath.fit(previous, into: visible))
            original[key] = nil
            snapped[key] = nil
            last = nil
        case let .frame(rect, step, screen)?:
            let after = apply(rect, to: window, visible: visible[screen])
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
    @discardableResult
    private func apply(_ rect: CGRect, to window: AXWindow, visible: CGRect) -> CGRect {
        window.setFrame(rect)
        guard let actual = window.frame else { return rect }
        var final = actual
        if let fixed = LayoutMath.correction(actual: actual, target: rect, visible: visible) {
            window.setPosition(fixed.origin)
            final = window.frame ?? fixed
        }
        Self.scheduleRedraw(window, target: rect)
        return final
    }

    /// Unter macOS 27 zeichnen manche Apps (gemessen: TextEdit) ein per Accessibility gleichzeitig
    /// vergrößertes und verschobenes Fenster nicht vollständig neu – der neue Bereich bleibt schwarz.
    /// Abhilfe: Höhe um einen Punkt verringern und erst nach einem eigenen Zeichendurchlauf der
    /// Ziel-App zurücksetzen. Gemessen verkürzt ein Anstoßen nach 0,1 s die schwarze Phase deutlich;
    /// zur Sicherheit folgen weitere nach 0,5 s und 1,2 s.
    private static func scheduleRedraw(_ window: AXWindow, target: CGRect) {
        for delay in [0.1, 0.5, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Nur, wenn das Fenster noch ungefähr dort steht, wo Raster es hingesetzt hat
                // (großzügig, weil Apps die Größe runden oder begrenzen).
                guard let frame = window.frame, frame.height > 2,
                      abs(frame.midX - target.midX) <= 60, abs(frame.midY - target.midY) <= 60 else {
                    NSLog("Raster: Neuzeichnen übersprungen (Fenster bewegt)")
                    return
                }
                let shrunk = CGSize(width: frame.width, height: frame.height - 1)
                window.setSize(shrunk)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    window.setSize(frame.size)
                    NSLog("Raster: Neuzeichnen angestoßen nach %.1f s", delay)
                }
            }
        }
    }

    // MARK: Alle Fenster eines Bildschirms

    private func tile(_ action: WindowAction, screens: [ScreenInfo]) {
        let focused = Self.frontmostPID().flatMap { AXWindow(focusedOf: $0) }
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
            snapped[key] = apply(rect, to: window, visible: screen.visible)
        }
        last = nil
    }

    /// Sichtbare Standardfenster eines Bildschirms, vorderstes zuerst.
    func visibleWindows(on screen: ScreenInfo) -> [AXWindow] {
        let entries = Self.windowEntries(on: screen, excluding: ownPID)
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

    /// Kopfzeile im Panel: Name des Zielbildschirms und Zahl der sichtbaren Fenster (ohne AX, daher auch ohne Freigabe).
    func targetScreenSummary() -> (name: String, windowCount: Int) {
        let screens = ScreenInfo.current()
        guard !screens.isEmpty else { return (String(localized: "Kein Bildschirm"), 0) }
        let index = ScreenGeometry.screenIndex(containing: ScreenInfo.mouseLocation(), in: screens.map(\.frame))
        return (screens[index].name, Self.windowEntries(on: screens[index], excluding: ownPID).count)
    }

    // MARK: Hilfen

    /// Prozess der vordersten App. Unter macOS 27 liefert NSRunningApplication für manche Apps
    /// (gemessen: Safari, TextEdit) die PID -1 – dann über die Fensterliste (Besitzer des vordersten
    /// normalen Fensters dieser App) und zuletzt über die systemweite Accessibility-Abfrage.
    static func frontmostPID() -> pid_t? {
        let app = NSWorkspace.shared.frontmostApplication
        if let pid = app?.processIdentifier, pid > 0 { return pid }
        if let name = app?.localizedName,
           let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
           let entry = list.first(where: { ($0[kCGWindowLayer as String] as? Int) == 0 && ($0[kCGWindowOwnerName as String] as? String) == name }),
           let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid > 0 {
            return pid
        }
        var value: CFTypeRef?
        var pid: pid_t = 0
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString, &value) == .success,
              let element = value, CFGetTypeID(element) == AXUIElementGetTypeID(),
              AXUIElementGetPid(element as! AXUIElement, &pid) == .success, pid > 0 else { return nil }
        return pid
    }

    private func targetScreenIndex(screens: [ScreenInfo], windowFrame: CGRect?) -> Int {
        if prefs.targetScreen == .window, let windowFrame {
            return ScreenGeometry.screenIndex(for: windowFrame, in: screens.map(\.frame))
        }
        return ScreenGeometry.screenIndex(containing: ScreenInfo.mouseLocation(), in: screens.map(\.frame))
    }

    /// Normale App-Fenster (Ebene 0) mit Mitte auf dem Bildschirm, in Z-Reihenfolge.
    private static func windowEntries(on screen: ScreenInfo, excluding ownPID: pid_t) -> [(pid: pid_t, bounds: CGRect)] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= 100, bounds.height >= 60,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  screen.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { return nil }
            return (pid, bounds)
        }
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
