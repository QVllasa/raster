import AppKit

/// Ein Bildschirm in AX-Koordinaten (Ursprung oben links am Hauptbildschirm, y nach unten).
struct ScreenInfo: Equatable {
    let frame: CGRect
    /// Fläche ohne Menüleiste und Dock.
    let visible: CGRect
    let name: String

    /// Liest die Bildschirme jedes Mal frisch – an- und abgesteckte Monitore sind sofort berücksichtigt.
    @MainActor static func current() -> [ScreenInfo] {
        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 0
        return screens.map {
            ScreenInfo(frame: ScreenGeometry.toAX($0.frame, primaryHeight: primaryHeight),
                       visible: ScreenGeometry.toAX($0.visibleFrame, primaryHeight: primaryHeight),
                       name: $0.localizedName)
        }
    }

    /// Mauszeiger in AX-Koordinaten.
    @MainActor static func mouseLocation() -> CGPoint {
        ScreenGeometry.toAX(point: NSEvent.mouseLocation, primaryHeight: NSScreen.screens.first?.frame.height ?? 0)
    }
}

enum HorizontalDirection {
    case left, right
}

enum ScreenGeometry {
    // MARK: Umrechnung Cocoa (Ursprung unten links) ↔ AX (Ursprung oben links)

    static func toAX(_ cocoa: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: cocoa.minX, y: primaryHeight - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }

    static func toCocoa(_ ax: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: ax.minX, y: primaryHeight - ax.maxY, width: ax.width, height: ax.height)
    }

    static func toAX(point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    // MARK: Bildschirmwahl

    /// Bildschirm, der den Punkt enthält (halboffen, damit die Grenze eindeutig ist); sonst der nächstgelegene.
    static func screenIndex(containing point: CGPoint, in frames: [CGRect]) -> Int {
        if let hit = frames.firstIndex(where: {
            point.x >= $0.minX && point.x < $0.maxX && point.y >= $0.minY && point.y < $0.maxY
        }) {
            return hit
        }
        return nearest(to: point, in: frames)
    }

    /// Bildschirm mit der größten Überdeckung durch das Fenster; liegt es nirgends, der nächste zur Fenstermitte.
    static func screenIndex(for window: CGRect, in frames: [CGRect]) -> Int {
        let areas = frames.map { frame -> CGFloat in
            let cut = frame.intersection(window)
            return cut.isNull ? 0 : cut.width * cut.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 {
            return best
        }
        return nearest(to: CGPoint(x: window.midX, y: window.midY), in: frames)
    }

    /// Nächster Bildschirm links bzw. rechts (nach Mittelpunkt), nil am Rand.
    static func neighbor(of index: Int, direction: HorizontalDirection, in frames: [CGRect]) -> Int? {
        guard frames.indices.contains(index) else { return nil }
        let current = frames[index]
        return frames.indices
            .filter { $0 != index }
            .filter { direction == .left ? frames[$0].midX < current.midX : frames[$0].midX > current.midX }
            .min { a, b in
                let da = abs(frames[a].midX - current.midX) + abs(frames[a].midY - current.midY) * 0.5
                let db = abs(frames[b].midX - current.midX) + abs(frames[b].midY - current.midY) * 0.5
                return da < db
            }
    }

    /// Nächster/vorheriger Bildschirm in Leserichtung (links → rechts, dann oben → unten), zyklisch.
    static func cycle(from index: Int, step: Int, in frames: [CGRect]) -> Int {
        guard frames.count > 1 else { return index }
        let order = frames.indices.sorted {
            frames[$0].minX != frames[$1].minX ? frames[$0].minX < frames[$1].minX : frames[$0].minY < frames[$1].minY
        }
        let position = order.firstIndex(of: index) ?? 0
        let next = ((position + step) % order.count + order.count) % order.count
        return order[next]
    }

    private static func nearest(to point: CGPoint, in frames: [CGRect]) -> Int {
        func distance(_ r: CGRect) -> CGFloat {
            let dx = max(r.minX - point.x, 0, point.x - r.maxX)
            let dy = max(r.minY - point.y, 0, point.y - r.maxY)
            return dx * dx + dy * dy
        }
        return frames.indices.min { distance(frames[$0]) < distance(frames[$1]) } ?? 0
    }
}
