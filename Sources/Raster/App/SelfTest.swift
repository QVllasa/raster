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
            ("testPrefsDefaults", testPrefsDefaults),
            ("testSetShortcutRemovesDuplicate", testSetShortcutRemovesDuplicate),
            ("testResetShortcuts", testResetShortcuts),
            ("testPlanFirstPressUsesTargetScreen", testPlanFirstPressUsesTargetScreen),
            ("testPlanCycleWidth", testPlanCycleWidth),
            ("testPlanRepeatNone", testPlanRepeatNone),
            ("testPlanMoveToNeighbor", testPlanMoveToNeighbor),
            ("testPlanDisplays", testPlanDisplays),
            ("testPlanMaximizeToggles", testPlanMaximizeToggles),
            ("testLoginItemStatusMapping", testLoginItemStatusMapping),
            ("testSnapOutcomeDetectsNoMove", testSnapOutcomeDetectsNoMove),
            ("testCorrectionSkipsStaleReadback", testCorrectionSkipsStaleReadback),
            ("testRestoreOntoMissingScreen", testRestoreOntoMissingScreen),
            ("testFocusedWindowComesFirst", testFocusedWindowComesFirst),
            ("testMatchByFrame", testMatchByFrame),
            ("testLoginConsent", testLoginConsent),
            ("testShortcutPayload", testShortcutPayload),
            ("testShortcutScripts", testShortcutScripts),
            ("testWindowListParse", testWindowListParse),
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

    // MARK: Einstellungen

    /// Eigene, danach gelöschte Defaults-Domäne, damit die echten Einstellungen unberührt bleiben.
    static func withTestDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "io.github.qvllasa.raster.selftest"
        UserDefaults().removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!
        body(defaults)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    static func testPrefsDefaults() {
        withTestDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            check(prefs.shortcuts[.leftHalf] == WindowAction.leftHalf.defaultShortcut, "Standard ⌘← ohne gespeicherte Werte")
            check(prefs.targetScreen == .mouse, "Zielbildschirm standardmäßig Maus")
            check(prefs.repeatBehavior == .cycleWidth, "erneutes Drücken standardmäßig Breite wechseln")
            check(prefs.gap == 0, "Abstand standardmäßig 0")
        }
    }

    static func testSetShortcutRemovesDuplicate() {
        withTestDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            let controlOptionA = Shortcut(keyCode: 0, modifiers: [.control, .option])
            prefs.setShortcut(controlOptionA, for: .leftHalf)
            check(prefs.shortcuts[.leftHalf] == controlOptionA, "neues Kürzel gesetzt")
            check(prefs.shortcuts[.tileGrid] == nil, "Raster verliert das doppelte Kürzel")
            let reloaded = Preferences(defaults: defaults)
            check(reloaded.shortcuts[.leftHalf] == controlOptionA, "neues Kürzel bleibt nach Neustart")
            check(reloaded.shortcuts[.tileGrid] == nil, "gelöschtes Kürzel bleibt gelöscht statt Standard")
            check(reloaded.shortcuts[.rightHalf] == WindowAction.rightHalf.defaultShortcut, "andere Kürzel unverändert")
        }
    }

    static func testResetShortcuts() {
        withTestDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            prefs.setShortcut(nil, for: .maximize)
            prefs.resetShortcuts()
            check(prefs.shortcuts[.maximize] == WindowAction.maximize.defaultShortcut, "Zurücksetzen stellt ⌘↑ wieder her")
            check(Preferences(defaults: defaults).shortcuts[.maximize] == WindowAction.maximize.defaultShortcut, "Zurücksetzen gespeichert")
        }
    }

    // MARK: WindowPlanner

    /// MacBook links, großer Monitor rechts (sichtbare Flächen in AX-Koordinaten).
    static let macBook = CGRect(x: 0, y: 25, width: 1512, height: 920)
    static let monitor = CGRect(x: 1512, y: -200, width: 2560, height: 1415)
    static let pair = [macBook, monitor]

    static func plan(_ action: WindowAction, window: CGRect, target: Int, repeatOf step: Int? = nil,
                     behavior: RepeatBehavior = .cycleWidth) -> WindowPlanner.Result? {
        WindowPlanner.plan(action: action, window: window, screens: pair, targetScreen: target,
                           gap: 0, behavior: behavior, repeatStep: step)
    }

    static func frame(_ result: WindowPlanner.Result?) -> CGRect? {
        if case let .frame(rect, _, _)? = result { return rect }
        return nil
    }

    static func testPlanFirstPressUsesTargetScreen() {
        let window = CGRect(x: 100, y: 100, width: 700, height: 500) // liegt auf dem MacBook
        same(frame(plan(.leftHalf, window: window, target: 1)) ?? .null,
             CGRect(x: 1512, y: -200, width: 1280, height: 1415), "⌘← mit Maus auf dem Monitor → linke Hälfte des Monitors")
        same(frame(plan(.rightHalf, window: window, target: 0)) ?? .null,
             CGRect(x: 756, y: 25, width: 756, height: 920), "⌘→ auf dem MacBook")
        same(frame(plan(.center, window: window, target: 1)) ?? .null,
             CGRect(x: 2442, y: 257.5, width: 700, height: 500), "Zentrieren auf dem Zielbildschirm, Größe bleibt")
    }

    static func testPlanCycleWidth() {
        let half = CGRect(x: 0, y: 25, width: 756, height: 920)
        let second = plan(.leftHalf, window: half, target: 1, repeatOf: 0)
        same(frame(second) ?? .null, CGRect(x: 0, y: 25, width: 1008, height: 920),
             "2. Druck → ⅔ auf dem Bildschirm des Fensters (nicht dem der Maus)")
        if case let .frame(_, step, _)? = second { check(step == 1, "Schritt 1 nach 2. Druck") }
        same(frame(plan(.leftHalf, window: half, target: 0, repeatOf: 1)) ?? .null,
             CGRect(x: 0, y: 25, width: 504, height: 920), "3. Druck → ⅓")
        same(frame(plan(.leftHalf, window: half, target: 0, repeatOf: 2)) ?? .null,
             CGRect(x: 0, y: 25, width: 756, height: 920), "4. Druck → wieder ½")
        same(frame(plan(.rightHalf, window: half, target: 0, repeatOf: 0)) ?? .null,
             CGRect(x: 504, y: 25, width: 1008, height: 920), "rechte Hälfte → rechte ⅔")
    }

    static func testPlanRepeatNone() {
        let half = CGRect(x: 0, y: 25, width: 756, height: 920)
        same(frame(plan(.leftHalf, window: half, target: 0, repeatOf: 0, behavior: .none)) ?? .null,
             half, "ohne Wiederholungsverhalten bleibt es bei ½")
    }

    static func testPlanMoveToNeighbor() {
        let rightHalf = CGRect(x: 756, y: 25, width: 756, height: 920)
        same(frame(plan(.rightHalf, window: rightHalf, target: 0, repeatOf: 0, behavior: .moveToNeighbor)) ?? .null,
             CGRect(x: 1512, y: -200, width: 1280, height: 1415), "rechte Hälfte erneut → linke Hälfte des rechten Monitors")
        let monitorRight = CGRect(x: 2792, y: -200, width: 1280, height: 1415)
        same(frame(plan(.rightHalf, window: monitorRight, target: 1, repeatOf: 0, behavior: .moveToNeighbor)) ?? .null,
             monitorRight, "ganz rechts gibt es keinen Nachbarn → bleibt")
        let monitorLeft = CGRect(x: 1512, y: -200, width: 1280, height: 1415)
        same(frame(plan(.leftHalf, window: monitorLeft, target: 1, repeatOf: 0, behavior: .moveToNeighbor)) ?? .null,
             CGRect(x: 756, y: 25, width: 756, height: 920), "linke Hälfte erneut → rechte Hälfte des linken Bildschirms")
    }

    static func testPlanDisplays() {
        let leftHalf = CGRect(x: 0, y: 25, width: 756, height: 920)
        same(frame(plan(.nextDisplay, window: leftHalf, target: 0)) ?? .null,
             CGRect(x: 1512, y: -200, width: 1280, height: 1415), "nächster Bildschirm überträgt die linke Hälfte proportional")
        same(frame(plan(.previousDisplay, window: leftHalf, target: 0)) ?? .null,
             CGRect(x: 1512, y: -200, width: 1280, height: 1415), "bei zwei Bildschirmen ist der vorherige derselbe (zyklisch)")
        let single = WindowPlanner.plan(action: .nextDisplay, window: leftHalf, screens: [macBook], targetScreen: 0,
                                        gap: 0, behavior: .cycleWidth, repeatStep: nil)
        check(single == nil, "nur ein Bildschirm → nichts zu tun")
    }

    static func testPlanMaximizeToggles() {
        same(frame(plan(.maximize, window: CGRect(x: 10, y: 40, width: 500, height: 400), target: 0)) ?? .null,
             macBook, "⌘↑ maximiert")
        check(plan(.maximize, window: macBook, target: 0, repeatOf: 0) == .restore, "⌘↑ auf maximiertem Fenster → wiederherstellen")
        check(plan(.restore, window: macBook, target: 0) == .restore, "Wiederherstellen → restore")
        check(plan(.tileGrid, window: macBook, target: 0) == nil, "Alle-Fenster-Aktionen plant der WindowManager selbst")
    }

    // MARK: Review-Befunde

    static func testLoginItemStatusMapping() {
        check(Preferences.isLoginItemOn(.enabled), "aktiviert → an")
        check(Preferences.isLoginItemOn(.requiresApproval), "Genehmigung ausstehend → bleibt an (nicht abmelden)")
        check(!Preferences.isLoginItemOn(.notRegistered), "nicht registriert → aus")
        check(!Preferences.isLoginItemOn(.notFound), "nicht gefunden → aus")
    }

    static func testSnapOutcomeDetectsNoMove() {
        let before = CGRect(x: 200, y: 150, width: 600, height: 400)
        let target = CGRect(x: 0, y: 25, width: 756, height: 920)
        check(!WindowManager.didMove(before: before, after: before, target: target),
              "Fenster unverändert, obwohl Ziel anders → nicht bewegt (Signalton, nichts merken)")
        check(WindowManager.didMove(before: before, after: target, target: target), "Ziel erreicht → bewegt")
        check(WindowManager.didMove(before: target, after: target, target: target), "stand schon am Ziel → gilt als erfolgreich")
        check(WindowManager.didMove(before: before, after: CGRect(x: 0, y: 25, width: 900, height: 920), target: target),
              "Mindestgröße, aber bewegt → bewegt")
    }

    static func testCorrectionSkipsStaleReadback() {
        let target = CGRect(x: 756, y: 25, width: 756, height: 920)
        let minSize = CGRect(x: 756, y: 25, width: 900, height: 920)
        same(LayoutMath.correction(actual: minSize, target: target, visible: visible) ?? .null,
             CGRect(x: 612, y: 25, width: 900, height: 920), "Mindestgröße am Ziel → an rechte Kante korrigieren")
        let stale = CGRect(x: 200, y: 150, width: 1200, height: 800)
        check(LayoutMath.correction(actual: stale, target: target, visible: visible) == nil,
              "veraltetes Rückleserechteck (Position nicht angekommen) → keine Korrektur")
        check(LayoutMath.correction(actual: target, target: target, visible: visible) == nil, "passt genau → keine Korrektur")
    }

    static func testRestoreOntoMissingScreen() {
        let onMonitor = CGRect(x: 2000, y: 100, width: 800, height: 600)
        same(LayoutMath.fit(onMonitor, into: pair), onMonitor, "Bildschirm noch da → unverändert")
        let fitted = LayoutMath.fit(onMonitor, into: [macBook])
        check(macBook.contains(fitted), "Monitor abgesteckt → Fenster landet vollständig auf dem MacBook, erhalten \(fitted)")
        check(abs(fitted.width - 800) < 0.5 && abs(fitted.height - 600) < 0.5, "Größe bleibt, wenn sie passt")
        let huge = LayoutMath.fit(CGRect(x: 3000, y: 0, width: 2400, height: 1400), into: [macBook])
        check(macBook.contains(huge), "zu großes Fenster wird auf den Bildschirm begrenzt")
    }

    static func testFocusedWindowComesFirst() {
        check(WindowManager.focusFirst([7, 3, 9], focused: 9) == [9, 7, 3], "fokussiertes Fenster nach vorn, Rest in Z-Reihenfolge")
        check(WindowManager.focusFirst([7, 3, 9], focused: 7) == [7, 3, 9], "schon vorn → unverändert")
        check(WindowManager.focusFirst([7, 3, 9], focused: 42) == [7, 3, 9], "Fokus auf anderem Bildschirm → unverändert")
        check(WindowManager.focusFirst([7, 3, 9], focused: Int?.none) == [7, 3, 9], "kein Fokus → unverändert")
    }

    static func testMatchByFrame() {
        let a = CGRect(x: 0, y: 25, width: 756, height: 920), b = CGRect(x: 756, y: 25, width: 756, height: 920)
        let entries: [(pid: pid_t, bounds: CGRect)] = [(10, b), (10, a), (20, a), (30, a)]
        let windows: [(pid: pid_t, frame: CGRect)] = [(10, a), (10, CGRect(x: 757, y: 25, width: 755, height: 920)), (20, a)]
        check(WindowManager.match(entries: entries, windows: windows) == [1, 0, 2, nil],
              "Zuordnung über App + Rahmen (±2 pt), fremde App/fehlendes Fenster → nil")
        let twins: [(pid: pid_t, bounds: CGRect)] = [(10, a), (10, a)]
        check(WindowManager.match(entries: twins, windows: [(10, a), (10, a)]) == [0, 1],
              "zwei gleich große Fenster einer App werden verschiedenen AX-Fenstern zugeordnet")
    }

    static func testLoginConsent() {
        check(Preferences.needsLoginConsent(isAppStore: true, answered: false), "Store-Version fragt vor dem Autostart")
        check(!Preferences.needsLoginConsent(isAppStore: true, answered: true), "nach der Antwort nicht erneut fragen")
        check(!Preferences.needsLoginConsent(isAppStore: false, answered: false), "GitHub-Version startet wie gewünscht automatisch")
        withTestDefaults { defaults in
            let prefs = Preferences(defaults: defaults)
            check(!prefs.loginConsentAnswered, "anfangs unbeantwortet")
            prefs.loginConsentAnswered = true
            check(Preferences(defaults: defaults).loginConsentAnswered, "Antwort wird gespeichert")
        }
    }

    // MARK: Store-Version (Kurzbefehl)

    static func testShortcutPayload() {
        let json = ShortcutPayload.json(app: "TextEdit", current: CGPoint(x: 120.4, y: 79.6),
                                        target: CGRect(x: 0, y: 25, width: 756, height: 920))
        check(json == #"{"app":"TextEdit","x0":120,"y0":80,"x":0,"y":25,"w":756,"h":920}"#,
              "JSON mit gerundeten Ganzzahlen, erhalten \(json)")
        let odd = ShortcutPayload.json(app: #"A "B" \ C"#, current: .zero, target: .zero)
        check(odd.hasPrefix(#"{"app":"A \"B\" \\ C""#), "Anführungszeichen und Backslash im App-Namen werden maskiert, erhalten \(odd)")
        check(odd.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } != nil, "Ergebnis ist gültiges JSON")
        check(ShortcutPayload.noopJSON == #"{"app":"Raster","x0":-1,"y0":-1,"x":0,"y":0,"w":0,"h":0}"#,
              "Leerlauf-Eingabe trifft kein Fenster, erhalten \(ShortcutPayload.noopJSON)")
    }

    static func testShortcutScripts() {
        check(ShortcutPayload.runScript(input: "{}", timeout: 120).contains("with timeout of 120 seconds"), "Zeitlimit einstellbar")
        let script = ShortcutPayload.runScript(input: #"{"app":"TextEdit"}"#)
        check(script.contains(#"run shortcut "Raster" with input "{\"app\":\"TextEdit\"}""#),
              "JSON wird für AppleScript maskiert, erhalten \(script)")
        check(script.contains("com.apple.shortcuts.events") && script.contains("with timeout"),
              "läuft über Shortcuts Events mit Zeitlimit")
        check(ShortcutPayload.existsScript().contains(#"exists shortcut "Raster""#), "Prüfskript fragt nach dem Kurzbefehl")
    }

    static func testWindowListParse() {
        func row(_ id: Int, _ pid: Int, _ layer: Int, _ x: Double, _ y: Double, _ w: Double, _ h: Double, alpha: Double = 1, app: String = "App") -> [String: Any] {
            [kCGWindowNumber as String: id, kCGWindowOwnerPID as String: pid, kCGWindowLayer as String: layer,
             kCGWindowBounds as String: ["X": x, "Y": y, "Width": w, "Height": h] as NSDictionary,
             kCGWindowAlpha as String: alpha, kCGWindowOwnerName as String: app]
        }
        let rows = [row(1, 10, 0, 0, 25, 756, 920, app: "TextEdit"), row(2, 99, 0, 0, 0, 800, 600), row(3, 20, 25, 0, 0, 800, 600),
                    row(4, 20, 0, 10, 10, 50, 50), row(5, 20, 0, 100, 100, 800, 600, alpha: 0), row(6, 20, 0, 300, 300, 800, 600, app: "Safari")]
        let entries = WindowList.parse(rows, excluding: 99)
        check(entries.map(\.id) == [1, 6], "nur Ebene 0, fremde PID, sichtbar, nicht winzig – in Reihenfolge, erhalten \(entries.map(\.id))")
        check(entries.first?.app == "TextEdit" && entries.first?.bounds == CGRect(x: 0, y: 25, width: 756, height: 920), "App-Name und Rahmen übernommen")
        check(WindowList.frontmost(of: 20, in: entries)?.id == 6, "vorderstes Fenster einer App")
        check(WindowList.frontmost(of: 42, in: entries) == nil, "unbekannte App → nil")
    }
}
