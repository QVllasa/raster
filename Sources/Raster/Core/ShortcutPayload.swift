import CoreGraphics
import Foundation

/// Was die App-Store-Version dem Begleit-Kurzbefehl „Raster“ übergibt (siehe scripts/make-shortcut.py):
/// App-Name und aktuelle Position, um das Fenster zu finden, und den Zielrahmen. Reine Textarbeit,
/// damit der Selbsttest sie ohne Kurzbefehle-App prüfen kann.
enum ShortcutPayload {
    static let shortcutName = "Raster"

    /// Eingabe, bei der der Kurzbefehl nichts findet und nichts tut (Position −1 hat kein Fenster).
    static let noopJSON = json(app: shortcutName, current: CGPoint(x: -1, y: -1), target: .zero)

    /// JSON mit ganzzahligen Punkten (Kurzbefehle vergleicht Positionen exakt).
    static func json(app: String, current: CGPoint, target: CGRect) -> String {
        let numbers: [(String, CGFloat)] = [
            ("x0", current.x), ("y0", current.y),
            ("x", target.minX), ("y", target.minY), ("w", target.width), ("h", target.height),
        ]
        let fields = ["\"app\":\"\(escapedForJSON(app))\""] + numbers.map { key, value in "\"\(key)\":\(Int(value.rounded()))" }
        return "{" + fields.joined(separator: ",") + "}"
    }

    /// AppleScript, der den Kurzbefehl im Hintergrund über „Shortcuts Events“ ausführt (öffnet die App nicht).
    /// Solange die Automations-Abfrage offen ist, wartet der Aufruf – beim Leerlauf-Aufruf der Einrichtung
    /// deshalb mit viel Zeit, damit der Nutzer den Dialog in Ruhe lesen kann.
    static func runScript(input: String, timeout: Int = 8) -> String {
        """
        with timeout of \(timeout) seconds
            tell application id "com.apple.shortcuts.events"
                run shortcut "\(shortcutName)" with input "\(escapedForAppleScript(input))"
            end tell
        end timeout
        """
    }

    /// AppleScript, der nur prüft, ob der Kurzbefehl vorhanden ist (löst beim ersten Mal die Automations-Abfrage aus).
    static func existsScript() -> String {
        """
        with timeout of 8 seconds
            tell application id "com.apple.shortcuts.events" to exists shortcut "\(shortcutName)"
        end timeout
        """
    }

    static func escapedForJSON(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func escapedForAppleScript(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
