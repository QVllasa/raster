import CoreGraphics

/// Zielfläche als Anteil der sichtbaren Bildschirmfläche; y zählt von oben (wie AX-Koordinaten).
enum Region: Equatable {
    case fraction(x: Double, y: Double, w: Double, h: Double)
}

/// Reine Geometrie: Rechtecke rein, Rechtecke raus. Alle Rechtecke in AX-Koordinaten
/// (Ursprung oben links am Hauptbildschirm, y wächst nach unten).
enum LayoutMath {
    /// Zielrechteck einer Region. Außen- und Innenabstand sind jeweils `gap`: Die Fläche schrumpft um gap/2,
    /// jede Zelle wird noch einmal um gap/2 eingerückt – so addieren sich benachbarte Zellen zu genau `gap`.
    static func rect(for region: Region, in visible: CGRect, gap: CGFloat) -> CGRect {
        guard case let .fraction(fx, fy, fw, fh) = region else { return visible }
        let area = visible.insetBy(dx: gap / 2, dy: gap / 2)
        let cell = CGRect(x: area.minX + area.width * fx,
                          y: area.minY + area.height * fy,
                          width: area.width * fw,
                          height: area.height * fh)
        return cell.insetBy(dx: gap / 2, dy: gap / 2).integralish
    }

    static func almostMaximized(in visible: CGRect) -> CGRect {
        let size = CGSize(width: visible.width * 0.9, height: visible.height * 0.9)
        return CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// Mittig platzieren, Größe bleibt – höchstens auf die sichtbare Fläche begrenzt.
    static func centered(_ window: CGRect, in visible: CGRect) -> CGRect {
        let size = CGSize(width: min(window.width, visible.width), height: min(window.height, visible.height))
        return CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// Raster für n Fenster: rows = ⌊√n⌋, cols = ⌈n/rows⌉. Die letzte Zeile verteilt ihre Fenster
    /// über die volle Breite, damit keine Lücke bleibt.
    static func grid(count: Int, in visible: CGRect, gap: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        let rows = max(1, Int(Double(count).squareRoot()))
        let cols = Int((Double(count) / Double(rows)).rounded(.up))
        var result: [CGRect] = []
        for row in 0..<rows {
            let inRow = row == rows - 1 ? count - cols * (rows - 1) : cols
            for col in 0..<inRow {
                let region = Region.fraction(x: Double(col) / Double(inRow), y: Double(row) / Double(rows),
                                             w: 1 / Double(inRow), h: 1 / Double(rows))
                result.append(rect(for: region, in: visible, gap: gap))
            }
        }
        return result
    }

    /// Alle Fenster nebeneinander in gleich breiten Spalten.
    static func columns(count: Int, in visible: CGRect, gap: CGFloat) -> [CGRect] {
        (0..<max(0, count)).map { i in
            rect(for: .fraction(x: Double(i) / Double(count), y: 0, w: 1 / Double(count), h: 1), in: visible, gap: gap)
        }
    }

    /// Erstes Fenster links auf der Hälfte, alle übrigen rechts übereinander gestapelt.
    static func focusStack(count: Int, in visible: CGRect, gap: CGFloat) -> [CGRect] {
        guard count > 1 else { return count == 1 ? [rect(for: .fraction(x: 0, y: 0, w: 1, h: 1), in: visible, gap: gap)] : [] }
        let rest = count - 1
        return [rect(for: .fraction(x: 0, y: 0, w: 0.5, h: 1), in: visible, gap: gap)]
            + (0..<rest).map { i in
                rect(for: .fraction(x: 0.5, y: Double(i) / Double(rest), w: 0.5, h: 1 / Double(rest)), in: visible, gap: gap)
            }
    }

    /// Überträgt ein Fenster proportional von einer Fläche auf eine andere (Bildschirmwechsel).
    static func transfer(_ rect: CGRect, from: CGRect, to: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return centered(rect, in: to) }
        let width = min(to.width, rect.width / from.width * to.width)
        let height = min(to.height, rect.height / from.height * to.height)
        var x = to.minX + (rect.minX - from.minX) / from.width * to.width
        var y = to.minY + (rect.minY - from.minY) / from.height * to.height
        x = min(max(x, to.minX), to.maxX - width)
        y = min(max(y, to.minY), to.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Bleibt ein Fenster größer als verlangt (Mindestgröße), wird es an der Kante des Ziels ausgerichtet,
    /// die am Bildschirmrand liegt, und vollständig in die sichtbare Fläche geschoben.
    static func clamp(actual: CGRect, target: CGRect, visible: CGRect) -> CGRect {
        var x = actual.minX
        var y = actual.minY
        if actual.width > target.width + 1 {
            let atTrailingEdge = target.maxX >= visible.maxX - 1 && target.minX > visible.minX + 1
            x = atTrailingEdge ? target.maxX - actual.width : target.minX
        }
        if actual.height > target.height + 1 {
            let atBottomEdge = target.maxY >= visible.maxY - 1 && target.minY > visible.minY + 1
            y = atBottomEdge ? target.maxY - actual.height : target.minY
        }
        x = max(visible.minX, min(x, visible.maxX - actual.width))
        y = max(visible.minY, min(y, visible.maxY - actual.height))
        return CGRect(x: x, y: y, width: actual.width, height: actual.height)
    }
}

extension CGRect {
    /// Auf ganze Punkte runden, ohne Kanten benachbarter Zellen auseinanderlaufen zu lassen.
    var integralish: CGRect {
        let minX = self.minX.rounded(), minY = self.minY.rounded()
        return CGRect(x: minX, y: minY, width: maxX.rounded() - minX, height: maxY.rounded() - minY)
    }
}
