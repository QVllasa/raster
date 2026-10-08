import CoreGraphics

/// Ein Fenster einer anderen App – egal, ob Raster es per Accessibility (GitHub-Version) oder über den
/// Begleit-Kurzbefehl (App-Store-Version) bewegt. Alle Rahmen in Bildschirmpunkten, Ursprung oben links.
protocol WindowHandle {
    /// Identität über Aktionen hinweg (AX-Element bzw. Fensternummer des Window-Servers).
    var key: AnyHashable { get }
    var pid: pid_t { get }
    /// Aktueller Rahmen, frisch gelesen; nil, wenn das Fenster nicht mehr erreichbar ist.
    var frame: CGRect? { get }
    var canMove: Bool { get }
    var isFullScreen: Bool { get }
    /// Setzt Position und Größe und liefert den Rahmen, der danach tatsächlich gilt.
    func setFrame(_ rect: CGRect) async throws -> CGRect?
}
