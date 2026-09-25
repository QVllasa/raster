import AppKit
import Carbon

/// `Raster --selftest` prüft die reine Geometrie ohne echte Fenster (Exit-Code 0 = alles bestanden).
enum SelfTest {
    private static var failures = 0
    private static var checks = 0

    static func run() -> Int32 {
        let tests: [(String, () -> Void)] = [
            ("testHalves", testHalves),
            ("testGap", testGap),
            ("testThirds", testThirds),
            ("testAlmostMaximizedAndCenter", testAlmostMaximizedAndCenter),
            ("testGridCounts", testGridCounts),
            ("testColumns", testColumns),
            ("testFocusStack", testFocusStack),
            ("testTransfer", testTransfer),
            ("testClampKeepsEdge", testClampKeepsEdge),
            ("testConversion", testConversion),
            ("testConversionStackedScreens", testConversionStackedScreens),
            ("testMouseOnSeam", testMouseOnSeam),
            ("testWindowScreen", testWindowScreen),
            ("testNeighbor", testNeighbor),
            ("testCycle", testCycle),
            ("testDefaults", testDefaults),
            ("testShortcutCodable", testShortcutCodable),
            ("testValidity", testValidity),
        ]
        for (name, test) in tests {
            let before = failures
            test()
            print(failures == before ? "✓ \(name)" : "✗ \(name)")
        }
        print(failures == 0 ? "alle Prüfungen bestanden (\(checks))" : "\(failures) von \(checks) Prüfungen fehlgeschlagen")
        return failures == 0 ? 0 : 1
    }

    static func check(_ condition: Bool, _ message: @autoclosure () -> String) {
        checks += 1
        if !condition {
            failures += 1
            print("  FEHLER: \(message())")
        }
    }

    static func same(_ a: CGRect, _ b: CGRect, _ label: String) {
        let ok = abs(a.minX - b.minX) < 0.5 && abs(a.minY - b.minY) < 0.5
            && abs(a.width - b.width) < 0.5 && abs(a.height - b.height) < 0.5
        check(ok, "\(label): erwartet \(b), erhalten \(a)")
    }

    // MARK: LayoutMath

    /// MacBook-Bildschirm in AX-Koordinaten: 25 pt Menüleiste oben, Dock ausgeblendet.
    static let visible = CGRect(x: 0, y: 25, width: 1512, height: 920)

    static func testHalves() {
        same(LayoutMath.rect(for: .fraction(x: 0, y: 0, w: 0.5, h: 1), in: visible, gap: 0),
             CGRect(x: 0, y: 25, width: 756, height: 920), "linke Hälfte")
        same(LayoutMath.rect(for: .fraction(x: 0.5, y: 0, w: 0.5, h: 1), in: visible, gap: 0),
             CGRect(x: 756, y: 25, width: 756, height: 920), "rechte Hälfte")
        same(LayoutMath.rect(for: .fraction(x: 0, y: 0.5, w: 1, h: 0.5), in: visible, gap: 0),
             CGRect(x: 0, y: 485, width: 1512, height: 460), "untere Hälfte")
    }

    static func testGap() {
        same(LayoutMath.rect(for: .fraction(x: 0, y: 0, w: 0.5, h: 1), in: visible, gap: 10),
             CGRect(x: 10, y: 35, width: 741, height: 900), "linke Hälfte mit Abstand")
        same(LayoutMath.rect(for: .fraction(x: 0, y: 0, w: 1, h: 1), in: visible, gap: 10),
             CGRect(x: 10, y: 35, width: 1492, height: 900), "Vollfläche mit Abstand")
    }

    static func testThirds() {
        let twoThirds = LayoutMath.rect(for: .fraction(x: 0, y: 0, w: 2.0 / 3, h: 1), in: visible, gap: 0)
        check(abs(twoThirds.width - 1008) < 0.5, "⅔ Breite 1008, erhalten \(twoThirds.width)")
        same(LayoutMath.rect(for: .fraction(x: 2.0 / 3, y: 0, w: 1.0 / 3, h: 1), in: visible, gap: 0),
             CGRect(x: 1008, y: 25, width: 504, height: 920), "rechtes Drittel")
    }

    static func testAlmostMaximizedAndCenter() {
        same(LayoutMath.almostMaximized(in: visible),
             CGRect(x: 75.6, y: 71, width: 1360.8, height: 828), "fast maximiert")
        same(LayoutMath.centered(CGRect(x: 0, y: 25, width: 800, height: 600), in: visible),
             CGRect(x: 356, y: 185, width: 800, height: 600), "zentriert")
        same(LayoutMath.centered(CGRect(x: 0, y: 0, width: 2000, height: 1200), in: visible),
             visible, "zu großes Fenster wird beim Zentrieren begrenzt")
    }

    static func testGridCounts() {
        check(LayoutMath.grid(count: 0, in: visible, gap: 0).isEmpty, "0 Fenster → leer")
        let one = LayoutMath.grid(count: 1, in: visible, gap: 0)
        check(one.count == 1, "1 Fenster → 1 Rechteck")
        if one.count == 1 { same(one[0], visible, "1 Fenster füllt alles") }
        let two = LayoutMath.grid(count: 2, in: visible, gap: 0)
        check(two.count == 2, "2 Fenster → 2 Rechtecke")
        if two.count == 2 {
            same(two[0], CGRect(x: 0, y: 25, width: 756, height: 920), "2er-Raster links")
            same(two[1], CGRect(x: 756, y: 25, width: 756, height: 920), "2er-Raster rechts")
        }
        let three = LayoutMath.grid(count: 3, in: visible, gap: 0)
        check(three.count == 3 && three.allSatisfy { abs($0.width - 504) < 0.5 && abs($0.height - 920) < 0.5 },
              "3 Fenster → drei Spalten, erhalten \(three)")
        let five = LayoutMath.grid(count: 5, in: visible, gap: 0)
        check(five.count == 5, "5 Fenster → 5 Rechtecke")
        if five.count == 5 {
            same(five[0], CGRect(x: 0, y: 25, width: 504, height: 460), "5er-Raster oben links")
            same(five[2], CGRect(x: 1008, y: 25, width: 504, height: 460), "5er-Raster oben rechts")
            same(five[3], CGRect(x: 0, y: 485, width: 756, height: 460), "5er-Raster unten links (gestreckt)")
            same(five[4], CGRect(x: 756, y: 485, width: 756, height: 460), "5er-Raster unten rechts (gestreckt)")
        }
        check(LayoutMath.grid(count: 9, in: visible, gap: 0).count == 9, "9 Fenster → 9 Rechtecke")
    }

    static func testColumns() {
        let cols = LayoutMath.columns(count: 4, in: visible, gap: 0)
        check(cols.count == 4 && cols.allSatisfy { abs($0.width - 378) < 0.5 }, "4 Spalten à 378, erhalten \(cols)")
    }

    static func testFocusStack() {
        let stack = LayoutMath.focusStack(count: 3, in: visible, gap: 0)
        check(stack.count == 3, "Fokus + 2 → 3 Rechtecke")
        if stack.count == 3 {
            same(stack[0], CGRect(x: 0, y: 25, width: 756, height: 920), "Fokusfenster links")
            same(stack[1], CGRect(x: 756, y: 25, width: 756, height: 460), "Stapel oben")
            same(stack[2], CGRect(x: 756, y: 485, width: 756, height: 460), "Stapel unten")
        }
        let single = LayoutMath.focusStack(count: 1, in: visible, gap: 0)
        check(single.count == 1 && single.first == visible, "Fokus allein → Vollfläche")
    }

    static func testTransfer() {
        let target = CGRect(x: 1512, y: -400, width: 2560, height: 1415)
        same(LayoutMath.transfer(CGRect(x: 0, y: 25, width: 756, height: 920), from: visible, to: target),
             CGRect(x: 1512, y: -400, width: 1280, height: 1415), "linke Hälfte → linke Hälfte des großen Bildschirms")
        let small = CGRect(x: 0, y: 0, width: 800, height: 500)
        let moved = LayoutMath.transfer(CGRect(x: 0, y: 25, width: 1512, height: 920), from: visible, to: small)
        check(small.contains(moved), "Übertragung bleibt innerhalb des Zielbildschirms")
    }

    static func testClampKeepsEdge() {
        let target = CGRect(x: 756, y: 25, width: 756, height: 920)
        same(LayoutMath.clamp(actual: CGRect(x: 756, y: 25, width: 900, height: 920), target: target, visible: visible),
             CGRect(x: 612, y: 25, width: 900, height: 920), "zu breites Fenster bleibt rechts bündig")
        let left = CGRect(x: 0, y: 25, width: 756, height: 920)
        same(LayoutMath.clamp(actual: CGRect(x: 0, y: 25, width: 900, height: 920), target: left, visible: visible),
             CGRect(x: 0, y: 25, width: 900, height: 920), "zu breites Fenster bleibt links bündig")
        let bottom = CGRect(x: 0, y: 485, width: 1512, height: 460)
        same(LayoutMath.clamp(actual: CGRect(x: 0, y: 485, width: 1512, height: 600), target: bottom, visible: visible),
             CGRect(x: 0, y: 345, width: 1512, height: 600), "zu hohes Fenster bleibt unten bündig")
    }

    // MARK: ScreenGeometry

    static func testConversion() {
        same(ScreenGeometry.toAX(CGRect(x: 0, y: 0, width: 1512, height: 982), primaryHeight: 982),
             CGRect(x: 0, y: 0, width: 1512, height: 982), "Hauptbildschirm bleibt gleich")
        same(ScreenGeometry.toAX(CGRect(x: 0, y: 900, width: 100, height: 82), primaryHeight: 982),
             CGRect(x: 0, y: 0, width: 100, height: 82), "Rechteck am oberen Rand → AX y = 0")
        same(ScreenGeometry.toCocoa(CGRect(x: 0, y: 0, width: 100, height: 82), primaryHeight: 982),
             CGRect(x: 0, y: 900, width: 100, height: 82), "Rückweg nach Cocoa")
        let p = ScreenGeometry.toAX(point: CGPoint(x: 10, y: 982), primaryHeight: 982)
        check(p == CGPoint(x: 10, y: 0), "Mauspunkt oben links → (10, 0), erhalten \(p)")
    }

    static func testConversionStackedScreens() {
        same(ScreenGeometry.toAX(CGRect(x: 0, y: 982, width: 2560, height: 1440), primaryHeight: 982),
             CGRect(x: 0, y: -1440, width: 2560, height: 1440), "Bildschirm über dem Hauptbildschirm hat negatives AX-y")
        same(ScreenGeometry.toAX(CGRect(x: -300, y: -1080, width: 1920, height: 1080), primaryHeight: 982),
             CGRect(x: -300, y: 982, width: 1920, height: 1080), "Bildschirm darunter, versetzt")
    }

    static func testMouseOnSeam() {
        let side = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: 0, width: 2560, height: 1440)]
        check(ScreenGeometry.screenIndex(containing: CGPoint(x: 1512, y: 100), in: side) == 1, "Punkt auf der Grenze → rechter Bildschirm")
        check(ScreenGeometry.screenIndex(containing: CGPoint(x: 1511.5, y: 100), in: side) == 0, "Punkt knapp links → linker Bildschirm")
        check(ScreenGeometry.screenIndex(containing: CGPoint(x: 3000, y: 1200), in: side) == 1, "Punkt unter dem MacBook, im großen Bildschirm")
        let gap = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1100, y: 0, width: 1000, height: 800)]
        check(ScreenGeometry.screenIndex(containing: CGPoint(x: 1080, y: 100), in: gap) == 1, "Punkt in Lücke → nächstgelegener")
        check(ScreenGeometry.screenIndex(containing: CGPoint(x: 5, y: 5), in: []) == 0, "keine Bildschirme → 0")
    }

    static func testWindowScreen() {
        let side = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: 0, width: 2560, height: 1440)]
        check(ScreenGeometry.screenIndex(for: CGRect(x: 1300, y: 100, width: 1000, height: 600), in: side) == 1, "größere Überdeckung gewinnt")
        check(ScreenGeometry.screenIndex(for: CGRect(x: 1000, y: 100, width: 800, height: 600), in: side) == 0, "größere Überdeckung links")
        check(ScreenGeometry.screenIndex(for: CGRect(x: 9000, y: 100, width: 800, height: 600), in: side) == 1, "ganz außerhalb → nächster")
    }

    static let threeScreens = [CGRect(x: 0, y: 0, width: 1512, height: 982),
                               CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                               CGRect(x: 1512, y: -200, width: 2560, height: 1440)]

    static func testNeighbor() {
        check(ScreenGeometry.neighbor(of: 0, direction: .left, in: threeScreens) == 1, "links vom MacBook")
        check(ScreenGeometry.neighbor(of: 0, direction: .right, in: threeScreens) == 2, "rechts vom MacBook")
        check(ScreenGeometry.neighbor(of: 1, direction: .left, in: threeScreens) == nil, "ganz links → nil")
        check(ScreenGeometry.neighbor(of: 2, direction: .right, in: threeScreens) == nil, "ganz rechts → nil")
        check(ScreenGeometry.neighbor(of: 2, direction: .left, in: threeScreens) == 0, "vom rechten der nächste links ist das MacBook")
    }

    static func testCycle() {
        check(ScreenGeometry.cycle(from: 0, step: 1, in: threeScreens) == 2, "MacBook → rechts")
        check(ScreenGeometry.cycle(from: 2, step: 1, in: threeScreens) == 1, "rechts → zyklisch ganz links")
        check(ScreenGeometry.cycle(from: 1, step: -1, in: threeScreens) == 2, "ganz links rückwärts → ganz rechts")
        check(ScreenGeometry.cycle(from: 0, step: 1, in: [threeScreens[0]]) == 0, "ein Bildschirm → bleibt")
    }

    // MARK: Aktionen und Kürzel

    static func testDefaults() {
        let left = WindowAction.leftHalf.defaultShortcut
        check(left?.keyCode == 123 && left?.modifiers == NSEvent.ModifierFlags.command.rawValue, "linke Hälfte = ⌘← wie SplitScreen")
        check(left?.displayString == "⌘←", "Anzeige ⌘←, erhalten \(left?.displayString ?? "nil")")
        check(WindowAction.rightHalf.defaultShortcut?.displayString == "⌘→", "rechte Hälfte = ⌘→")
        check(WindowAction.maximize.defaultShortcut?.displayString == "⌘↑", "Maximieren = ⌘↑")
        check(WindowAction.tileGrid.defaultShortcut?.displayString == "⌃⌥A", "Raster = ⌃⌥A, erhalten \(WindowAction.tileGrid.defaultShortcut?.displayString ?? "nil")")
        check(WindowAction.nextDisplay.defaultShortcut?.displayString == "⌃⌥⌘→", "nächster Bildschirm = ⌃⌥⌘→")
        check(WindowAction.restore.defaultShortcut?.displayString == "⌃⌥⌫", "Wiederherstellen = ⌃⌥⌫")
        let all = WindowAction.allCases.compactMap(\.defaultShortcut)
        check(all.count == WindowAction.allCases.count, "jede Aktion hat ein Standardkürzel")
        check(Set(all).count == all.count, "keine doppelten Standardkürzel")
        check(WindowAction.allCases.allSatisfy { !$0.preview.isEmpty }, "jede Aktion hat eine Vorschau")
        check(WindowAction.allCases.allSatisfy { !$0.title.isEmpty }, "jede Aktion hat einen Titel")
    }

    static func testShortcutCodable() {
        let original = Shortcut(keyCode: 0, modifiers: [.control, .option])
        let data = try? JSONEncoder().encode([WindowAction.tileGrid.rawValue: original])
        let decoded = data.flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) }
        check(decoded?[WindowAction.tileGrid.rawValue] == original, "Kürzel übersteht JSON-Rundreise")
    }

    static func testValidity() {
        check(!Shortcut(keyCode: 0, modifiers: [.option]).isValid, "⌥A ist ungültig")
        check(!Shortcut(keyCode: 0, modifiers: [.shift]).isValid, "⇧A ist ungültig")
        check(Shortcut(keyCode: 0, modifiers: [.control, .option]).isValid, "⌃⌥A ist gültig")
        check(Shortcut(keyCode: 123, modifiers: [.command]).isValid, "⌘← ist gültig")
        check(Shortcut(keyCode: 122, modifiers: []).isValid, "F1 allein ist gültig")
        check(Shortcut(keyCode: 0, modifiers: [.control, .option]).carbonModifiers == UInt32(controlKey | optionKey), "Carbon-Modifier ⌃⌥")
    }
}
