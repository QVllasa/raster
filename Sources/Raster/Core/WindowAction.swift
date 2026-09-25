import AppKit

enum ActionGroup: String, CaseIterable, Identifiable {
    case halves, screen, quarters, thirds, allWindows, displays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .halves: "Hälften"
        case .screen: "Ganzer Bildschirm"
        case .quarters: "Viertel"
        case .thirds: "Drittel"
        case .allWindows: "Alle Fenster auf dem Bildschirm"
        case .displays: "Bildschirme"
        }
    }

    var actions: [WindowAction] { WindowAction.allCases.filter { $0.group == self } }
}

/// Alle Anordnungen, die Raster kennt – mit Titel, Zielfläche, Vorschau und Standardkürzel.
enum WindowAction: String, CaseIterable, Codable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case maximize, almostMaximize, center, restore
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case nextDisplay, previousDisplay
    case tileGrid, tileColumns, focusStack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: "Linke Hälfte"
        case .rightHalf: "Rechte Hälfte"
        case .topHalf: "Obere Hälfte"
        case .bottomHalf: "Untere Hälfte"
        case .maximize: "Maximieren"
        case .almostMaximize: "Fast maximieren"
        case .center: "Zentrieren"
        case .restore: "Wiederherstellen"
        case .topLeft: "Oben links"
        case .topRight: "Oben rechts"
        case .bottomLeft: "Unten links"
        case .bottomRight: "Unten rechts"
        case .leftThird: "Linkes Drittel"
        case .centerThird: "Mittleres Drittel"
        case .rightThird: "Rechtes Drittel"
        case .leftTwoThirds: "Linke zwei Drittel"
        case .rightTwoThirds: "Rechte zwei Drittel"
        case .nextDisplay: "Nächster Bildschirm"
        case .previousDisplay: "Vorheriger Bildschirm"
        case .tileGrid: "Raster"
        case .tileColumns: "Nebeneinander"
        case .focusStack: "Fokus + Stapel"
        }
    }

    /// Kurzer Titel für die Kacheln im Panel.
    var shortTitle: String {
        switch self {
        case .leftHalf: "Links"
        case .rightHalf: "Rechts"
        case .topHalf: "Oben"
        case .bottomHalf: "Unten"
        case .almostMaximize: "Fast voll"
        case .restore: "Zurück"
        case .leftThird: "Links"
        case .centerThird: "Mitte"
        case .rightThird: "Rechts"
        case .leftTwoThirds: "⅔ links"
        case .rightTwoThirds: "⅔ rechts"
        case .nextDisplay: "Nächster"
        case .previousDisplay: "Vorheriger"
        default: title
        }
    }

    var group: ActionGroup {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: .halves
        case .maximize, .almostMaximize, .center, .restore: .screen
        case .topLeft, .topRight, .bottomLeft, .bottomRight: .quarters
        case .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds: .thirds
        case .nextDisplay, .previousDisplay: .displays
        case .tileGrid, .tileColumns, .focusStack: .allWindows
        }
    }

    /// Feste Zielfläche für Aktionen, die nur ein Fenster betreffen; nil bei Sonderfällen.
    var region: Region? {
        let third = 1.0 / 3
        switch self {
        case .leftHalf: return .fraction(x: 0, y: 0, w: 0.5, h: 1)
        case .rightHalf: return .fraction(x: 0.5, y: 0, w: 0.5, h: 1)
        case .topHalf: return .fraction(x: 0, y: 0, w: 1, h: 0.5)
        case .bottomHalf: return .fraction(x: 0, y: 0.5, w: 1, h: 0.5)
        case .maximize: return .fraction(x: 0, y: 0, w: 1, h: 1)
        case .topLeft: return .fraction(x: 0, y: 0, w: 0.5, h: 0.5)
        case .topRight: return .fraction(x: 0.5, y: 0, w: 0.5, h: 0.5)
        case .bottomLeft: return .fraction(x: 0, y: 0.5, w: 0.5, h: 0.5)
        case .bottomRight: return .fraction(x: 0.5, y: 0.5, w: 0.5, h: 0.5)
        case .leftThird: return .fraction(x: 0, y: 0, w: third, h: 1)
        case .centerThird: return .fraction(x: third, y: 0, w: third, h: 1)
        case .rightThird: return .fraction(x: 2 * third, y: 0, w: third, h: 1)
        case .leftTwoThirds: return .fraction(x: 0, y: 0, w: 2 * third, h: 1)
        case .rightTwoThirds: return .fraction(x: third, y: 0, w: 2 * third, h: 1)
        default: return nil
        }
    }

    /// Rechtecke im Einheitsquadrat (y von oben) für die Mini-Bildschirm-Grafik.
    var preview: [CGRect] {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        if case let .fraction(x, y, w, h)? = region { return [CGRect(x: x, y: y, width: w, height: h)] }
        switch self {
        case .almostMaximize: return [CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)]
        case .center: return [CGRect(x: 0.22, y: 0.18, width: 0.56, height: 0.64)]
        case .restore: return [CGRect(x: 0.14, y: 0.2, width: 0.5, height: 0.52)]
        case .nextDisplay, .previousDisplay: return [CGRect(x: 0.25, y: 0.22, width: 0.5, height: 0.56)]
        case .tileGrid: return LayoutMath.gridFractions(count: 4)
        case .tileColumns: return (0..<3).map { CGRect(x: Double($0) / 3, y: 0, width: 1.0 / 3, height: 1) }
        case .focusStack: return [CGRect(x: 0, y: 0, width: 0.5, height: 1),
                                  CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                                  CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)]
        default: return [unit]
        }
    }

    /// Zusatzsymbol über der Vorschau (Richtung, Rückgängig …).
    var overlaySymbol: String? {
        switch self {
        case .restore: "arrow.uturn.backward"
        case .nextDisplay: "arrow.right"
        case .previousDisplay: "arrow.left"
        case .center: "plus"
        default: nil
        }
    }

    /// Standardbelegung laut Spec; ⌘←/⌘→/⌘↑ wie früher in SplitScreen.
    var defaultShortcut: Shortcut? {
        let co: NSEvent.ModifierFlags = [.control, .option]
        let coc: NSEvent.ModifierFlags = [.control, .option, .command]
        switch self {
        case .leftHalf: return Shortcut(keyCode: 123, modifiers: .command)
        case .rightHalf: return Shortcut(keyCode: 124, modifiers: .command)
        case .maximize: return Shortcut(keyCode: 126, modifiers: .command)
        case .topHalf: return Shortcut(keyCode: 126, modifiers: co)
        case .bottomHalf: return Shortcut(keyCode: 125, modifiers: co)
        case .almostMaximize: return Shortcut(keyCode: 36, modifiers: co)
        case .center: return Shortcut(keyCode: 8, modifiers: co)
        case .restore: return Shortcut(keyCode: 51, modifiers: co)
        case .topLeft: return Shortcut(keyCode: 32, modifiers: co)
        case .topRight: return Shortcut(keyCode: 34, modifiers: co)
        case .bottomLeft: return Shortcut(keyCode: 38, modifiers: co)
        case .bottomRight: return Shortcut(keyCode: 40, modifiers: co)
        case .leftThird: return Shortcut(keyCode: 2, modifiers: co)
        case .centerThird: return Shortcut(keyCode: 3, modifiers: co)
        case .rightThird: return Shortcut(keyCode: 5, modifiers: co)
        case .leftTwoThirds: return Shortcut(keyCode: 14, modifiers: co)
        case .rightTwoThirds: return Shortcut(keyCode: 17, modifiers: co)
        case .nextDisplay: return Shortcut(keyCode: 124, modifiers: coc)
        case .previousDisplay: return Shortcut(keyCode: 123, modifiers: coc)
        case .tileGrid: return Shortcut(keyCode: 0, modifiers: co)
        case .tileColumns: return Shortcut(keyCode: 1, modifiers: co)
        case .focusStack: return Shortcut(keyCode: 46, modifiers: co)
        }
    }
}
