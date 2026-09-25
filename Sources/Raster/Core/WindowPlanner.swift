import CoreGraphics

/// Entscheidet rein rechnerisch, wohin ein einzelnes Fenster soll – ohne echte Fenster anzufassen.
/// Alle Rechtecke in AX-Koordinaten; `screens` sind die sichtbaren Flächen aller Bildschirme.
enum WindowPlanner {
    enum Result: Equatable {
        /// Neues Fensterrechteck, Zyklus-Schritt und Index des Bildschirms, auf dem es landet.
        case frame(CGRect, step: Int, screen: Int)
        /// Fenster auf die Größe vor dem ersten Einrasten zurücksetzen.
        case restore
    }

    /// Breiten beim wiederholten Drücken von linker/rechter Hälfte.
    static let cycleWidths: [Double] = [0.5, 2.0 / 3, 1.0 / 3]

    /// - Parameters:
    ///   - targetScreen: Bildschirm laut Einstellung (Maus bzw. aktives Fenster) – gilt beim ersten Druck.
    ///   - repeatStep: Schritt der vorigen, identischen Aktion, wenn das Fenster seitdem unverändert ist; sonst nil.
    ///     Bei Wiederholung gilt der Bildschirm, auf dem das Fenster jetzt steht.
    static func plan(action: WindowAction, window: CGRect, screens: [CGRect], targetScreen: Int,
                     gap: CGFloat, behavior: RepeatBehavior, repeatStep: Int?) -> Result? {
        guard !screens.isEmpty else { return nil }
        let windowScreen = ScreenGeometry.screenIndex(for: window, in: screens)
        let target = screens.indices.contains(targetScreen) ? targetScreen : windowScreen
        let base = repeatStep == nil ? target : windowScreen

        func frame(_ region: Region, on index: Int, step: Int = 0) -> Result {
            .frame(LayoutMath.rect(for: region, in: screens[index], gap: gap), step: step, screen: index)
        }

        switch action {
        case .restore:
            return .restore
        case .tileGrid, .tileColumns, .focusStack:
            return nil
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1 else { return nil }
            let to = ScreenGeometry.cycle(from: windowScreen, step: action == .nextDisplay ? 1 : -1, in: screens)
            return .frame(LayoutMath.transfer(window, from: screens[windowScreen], to: screens[to]), step: 0, screen: to)
        case .maximize:
            return repeatStep == nil ? frame(.fraction(x: 0, y: 0, w: 1, h: 1), on: base) : .restore
        case .almostMaximize:
            return .frame(LayoutMath.almostMaximized(in: screens[base]), step: 0, screen: base)
        case .center:
            return .frame(LayoutMath.centered(window, in: screens[base]), step: 0, screen: base)
        case .leftHalf, .rightHalf:
            let isLeft = action == .leftHalf
            guard let step = repeatStep else { return frame(action.region!, on: base) }
            switch behavior {
            case .none:
                return frame(action.region!, on: base)
            case .cycleWidth:
                let next = (step + 1) % cycleWidths.count
                let width = cycleWidths[next]
                return frame(.fraction(x: isLeft ? 0 : 1 - width, y: 0, w: width, h: 1), on: base, step: next)
            case .moveToNeighbor:
                guard let neighbor = ScreenGeometry.neighbor(of: base, direction: isLeft ? .left : .right, in: screens) else {
                    return frame(action.region!, on: base)
                }
                // Wie unter Windows: über den Rand hinweg landet das Fenster auf der zugewandten Hälfte.
                let opposite = isLeft ? WindowAction.rightHalf : .leftHalf
                return frame(opposite.region!, on: neighbor)
            }
        default:
            guard let region = action.region else { return nil }
            return frame(region, on: base)
        }
    }
}
