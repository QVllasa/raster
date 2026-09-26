import AppKit
import ApplicationServices

/// `Raster --ax-probe <pid>` prüft, ob Raster Fenster einer bestimmten App lesen und bewegen darf
/// (z. B. in der App-Sandbox), ohne das vorderste Fenster des Users anzufassen.
enum Diagnostics {
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
        window.setFrame(moved)
        let after = window.frame ?? .null
        print("Rahmen nachher:", after)
        window.setFrame(before)
        let success = after.isClose(to: moved)
        print(success ? "✓ Fenster lässt sich bewegen" : "✗ Fenster hat sich nicht bewegt")
        return success ? 0 : 1
    }
}
