#if !APPSTORE
import AppKit
import ApplicationServices

/// Eindeutiger Schlüssel eines Fensters über App-Grenzen hinweg – nur öffentliche API (CFEqual/CFHash).
struct WindowKey: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

/// Dünner Wrapper um ein Fenster einer anderen App (Accessibility-API, AX-Koordinaten) – GitHub-Version.
struct AXWindow: WindowHandle {
    let element: AXUIElement
    let pid: pid_t

    /// Fokussiertes (ersatzweise Haupt-)Fenster einer App.
    init?(focusedOf pid: pid_t) {
        let app = Self.application(pid)
        guard let window = Self.copy(app, kAXFocusedWindowAttribute) ?? Self.copy(app, kAXMainWindowAttribute),
              CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        self.element = window as! AXUIElement
        self.pid = pid
    }

    private init(element: AXUIElement, pid: pid_t) {
        self.element = element
        self.pid = pid
    }

    static func all(of pid: pid_t) -> [AXWindow] {
        guard let list = copy(application(pid), kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return list.map { AXWindow(element: $0, pid: pid) }
    }

    /// Identität über öffentliche API: Zwei AX-Elemente desselben Fensters sind laut CFEqual gleich.
    var key: AnyHashable { WindowKey(element: element) }

    var frame: CGRect? {
        guard let position = Self.copy(element, kAXPositionAttribute), let size = Self.copy(element, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    /// Position lässt sich setzen (Sheets und manche Dialoge erlauben das nicht).
    var canMove: Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &settable) == .success && settable.boolValue
    }

    var isStandard: Bool { (Self.copy(element, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole }
    var isMinimized: Bool { (Self.copy(element, kAXMinimizedAttribute) as? Bool) ?? false }
    var isFullScreen: Bool { (Self.copy(element, "AXFullScreen") as? Bool) ?? false }

    /// Setzt den Rahmen sofort und liefert den tatsächlichen zurück; stößt danach das Neuzeichnen an.
    func setFrame(_ rect: CGRect) async throws -> CGRect? {
        apply(rect)
        let actual = frame
        Self.scheduleRedraw(self, target: rect)
        return actual
    }

    /// Größe → Position → Größe: Die erste Größe verhindert, dass das Fenster beim Verschieben auf einen
    /// kleineren Bildschirm hängen bleibt, die zweite korrigiert, was macOS beim Verschieben begrenzt hat.
    /// „Enhanced User Interface“ (von VoiceOver & Co. gesetzt) animiert jede Änderung – kurz abschalten.
    func apply(_ rect: CGRect) {
        let app = Self.application(pid)
        let enhanced = (Self.copy(app, "AXEnhancedUserInterface") as? Bool) ?? false
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        setSize(rect.size)
        setPosition(rect.origin)
        setSize(rect.size)
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
    }

    func setPosition(_ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        }
    }

    func setSize(_ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        }
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

    // MARK: Hilfen

    private static func application(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        // Hängende Apps sollen Raster nicht blockieren.
        AXUIElementSetMessagingTimeout(app, 0.8)
        return app
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }
}
#endif
