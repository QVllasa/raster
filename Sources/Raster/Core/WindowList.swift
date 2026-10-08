import AppKit

/// Ein Eintrag der Fensterliste des Window-Servers (öffentliche API, keine Freigabe nötig).
struct WindowEntry: Equatable {
    let id: CGWindowID
    let pid: pid_t
    /// Name der besitzenden App, wie ihn auch die Kurzbefehl-Aktion „Fenster suchen“ kennt.
    let app: String
    /// Rahmen in Bildschirmpunkten, Ursprung oben links (gleiches System wie Accessibility).
    let bounds: CGRect
}

/// Normale App-Fenster (Ebene 0) in Z-Reihenfolge, vorderstes zuerst.
enum WindowList {
    static func all(excluding ownPID: pid_t) -> [WindowEntry] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        return parse(list, excluding: ownPID)
    }

    /// Fenster mit Mitte auf dem Bildschirm.
    static func entries(on screen: ScreenInfo, excluding ownPID: pid_t) -> [WindowEntry] {
        all(excluding: ownPID).filter { screen.frame.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)) }
    }

    /// Ein bestimmtes Fenster frisch gelesen; nil, wenn es nicht mehr auf dem Bildschirm ist.
    static func entry(id: CGWindowID) -> WindowEntry? {
        guard let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]] else { return nil }
        return parse(list, excluding: 0).first { $0.id == id }
    }

    /// Vorderstes Fenster einer App in der Liste – bei der aktiven App ihr Hauptfenster.
    nonisolated static func frontmost(of pid: pid_t, in entries: [WindowEntry]) -> WindowEntry? {
        entries.first { $0.pid == pid }
    }

    /// Behält normale, sichtbare, nicht winzige Fenster fremder Apps – in der Reihenfolge der Liste.
    nonisolated static func parse(_ list: [[String: Any]], excluding ownPID: pid_t) -> [WindowEntry] {
        list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != ownPID,
                  let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= 100, bounds.height >= 60,
                  ((info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0 else { return nil }
            return WindowEntry(id: id, pid: pid, app: info[kCGWindowOwnerName as String] as? String ?? "", bounds: bounds)
        }
    }

    /// Prozess der vordersten App. Unter macOS 27 liefert NSRunningApplication für manche Apps
    /// (gemessen: Safari, TextEdit) die PID -1 – dann über die Fensterliste (Besitzer des vordersten
    /// normalen Fensters dieser App); die GitHub-Version zuletzt über die systemweite Accessibility-Abfrage.
    @MainActor static func frontmostPID() -> pid_t? {
        let app = NSWorkspace.shared.frontmostApplication
        if let pid = app?.processIdentifier, pid > 0 { return pid }
        if let name = app?.localizedName, let entry = all(excluding: 0).first(where: { $0.app == name }) {
            return entry.pid
        }
        #if APPSTORE
        return nil
        #else
        var value: CFTypeRef?
        var pid: pid_t = 0
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString, &value) == .success,
              let element = value, CFGetTypeID(element) == AXUIElementGetTypeID(),
              AXUIElementGetPid(element as! AXUIElement, &pid) == .success, pid > 0 else { return nil }
        return pid
        #endif
    }
}
