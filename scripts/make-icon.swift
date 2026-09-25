// Erzeugt das App-Icon (Resources/AppIcon.icns) – vollflächig, macOS maskiert es selbst.
// Aufruf: swift scripts/make-icon.swift Resources && iconutil -c icns Resources/AppIcon.iconset
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let space = CGColorSpaceCreateDeviceRGB()

    // Hintergrund: Indigo → Cyan
    let colors = [NSColor(srgbRed: 0.33, green: 0.30, blue: 0.98, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.26, green: 0.52, blue: 1.00, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.16, green: 0.80, blue: 0.95, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Weicher Glanz oben links (Glas-Anmutung)
    let glow = CGGradient(colorsSpace: space,
                          colors: [NSColor.white.withAlphaComponent(0.42).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.26, y: s * 0.86), startRadius: 0,
                           endCenter: CGPoint(x: s * 0.26, y: s * 0.86), endRadius: s * 0.78, options: [])

    // Glas-Bildschirm
    let pane = CGRect(x: s * 0.14, y: s * 0.22, width: s * 0.72, height: s * 0.56)
    let panePath = CGPath(roundedRect: pane, cornerWidth: s * 0.1, cornerHeight: s * 0.1, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.06, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(panePath)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(panePath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
    ctx.setLineWidth(s * 0.008)
    ctx.strokePath()

    // Aufteilung: links eine Hälfte, rechts zwei gestapelte Viertel
    let inner = pane.insetBy(dx: s * 0.045, dy: s * 0.045)
    let gap = s * 0.035
    let halfWidth = (inner.width - gap) / 2
    let quarterHeight = (inner.height - gap) / 2
    let cells: [(CGRect, CGFloat)] = [
        (CGRect(x: inner.minX, y: inner.minY, width: halfWidth, height: inner.height), 1.0),
        (CGRect(x: inner.minX + halfWidth + gap, y: inner.minY + quarterHeight + gap, width: halfWidth, height: quarterHeight), 0.82),
        (CGRect(x: inner.minX + halfWidth + gap, y: inner.minY, width: halfWidth, height: quarterHeight), 0.62),
    ]
    for (rect, alpha) in cells {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: s * 0.03, color: NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: s * 0.045, cornerHeight: s * 0.045, transform: nil))
        ctx.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: root.appendingPathComponent("AppIcon-1024.png"))
print("Iconset erzeugt:", iconset.path)
