import AppKit
import ApplicationServices

/// Private, aber seit Jahren stabile Funktion: liefert die CGWindowID zu einem AX-Fenster.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Dünner Wrapper um ein Fenster einer anderen App (Accessibility-API, AX-Koordinaten).
struct AXWindow {
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

    var id: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(element, &id) == .success && id != 0 ? id : nil
    }

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

    /// Größe → Position → Größe: Die erste Größe verhindert, dass das Fenster beim Verschieben auf einen
    /// kleineren Bildschirm hängen bleibt, die zweite korrigiert, was macOS beim Verschieben begrenzt hat.
    /// „Enhanced User Interface“ (von VoiceOver & Co. gesetzt) animiert jede Änderung – kurz abschalten.
    func setFrame(_ rect: CGRect) {
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
