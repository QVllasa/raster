// Erzeugt die Mac-App-Store-Screenshots (2880 × 1800, ohne Alphakanal).
// Aufruf: swift scripts/make-store-screenshots.swift <aufnahmen-ordner> <ziel-ordner> <de|en>
// Der Aufnahmen-Ordner enthält dark/ und light/ aus `Raster --snapshot … --window-only`.
import AppKit
import SwiftUI

let args = CommandLine.arguments
let source = URL(fileURLWithPath: args[1])
let target = URL(fileURLWithPath: args[2])
let lang = args.count > 3 ? args[3] : "de"
try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

func image(_ path: String) -> NSImage {
    guard let img = NSImage(contentsOf: source.appendingPathComponent(path)) else { fatalError("fehlt: \(path)") }
    return img
}

let indigo = Color(red: 0.38, green: 0.42, blue: 1.0)
let cyan = Color(red: 0.18, green: 0.78, blue: 0.96)
let accent = LinearGradient(colors: [indigo, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)

// MARK: Bausteine

/// Stilisiertes App-Fenster mit Ampel-Knöpfen und angedeutetem Inhalt.
struct MockWindow: View {
    var tint: Color
    var lines = 5
    var highlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 15, height: 15) }
                Spacer()
            }
            .padding(.horizontal, 18).frame(height: 44)
            .background(Color.white.opacity(0.06))
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.75)).frame(width: 180, height: 22)
                ForEach(0..<lines, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.13))
                        .frame(height: 14).padding(.trailing, CGFloat((i * 37) % 120))
                }
                Spacer(minLength: 0)
            }
            .padding(26)
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(highlighted ? AnyShapeStyle(accent) : AnyShapeStyle(Color.white.opacity(0.12)), lineWidth: highlighted ? 4 : 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }
}

/// Bildschirm mit Schreibtisch-Verlauf, Menüleiste und frei platzierten Fenstern (Rechtecke in Anteilen).
struct MockScreen: View {
    var windows: [(CGRect, Color, Bool)]
    var size: CGSize

    var body: some View {
        let gap: CGFloat = 14
        let menubar: CGFloat = 30
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.13, green: 0.16, blue: 0.36), Color(red: 0.05, green: 0.27, blue: 0.40)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(Color.black.opacity(0.35)).frame(height: menubar)
            ForEach(windows.indices, id: \.self) { i in
                let (unit, tint, hi) = windows[i]
                let area = CGRect(x: gap, y: menubar + gap, width: size.width - 2 * gap, height: size.height - menubar - 2 * gap)
                let r = CGRect(x: area.minX + unit.minX * area.width, y: area.minY + unit.minY * area.height,
                               width: unit.width * area.width, height: unit.height * area.height).insetBy(dx: gap / 2, dy: gap / 2)
                MockWindow(tint: tint, lines: max(2, Int(r.height / 60)), highlighted: hi)
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 3))
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(Color(white: 0.07)))
        .shadow(color: .black.opacity(0.55), radius: 60, y: 30)
    }
}

/// Glas-Tastenkappen wie „⌘ ←“.
struct KeyCaps: View {
    var keys: [String]

    var body: some View {
        HStack(spacing: 22) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 76, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 132, minHeight: 132)
                    .padding(.horizontal, key.count > 1 ? 18 : 0)
                    .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.white.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            }
        }
    }
}

struct Slide<Visual: View>: View {
    var title: String
    var subtitle: String
    var light = false
    @ViewBuilder var visual: Visual

    var body: some View {
        ZStack {
            LinearGradient(colors: light ? [Color(white: 0.97), Color(white: 0.87)]
                                         : [Color(red: 0.07, green: 0.08, blue: 0.13), Color(red: 0.03, green: 0.035, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(indigo.opacity(light ? 0.10 : 0.18)).frame(width: 1600, height: 1600).blur(radius: 280).offset(x: 700, y: 100)
            Circle().fill(cyan.opacity(light ? 0.08 : 0.12)).frame(width: 1100, height: 1100).blur(radius: 240).offset(x: -900, y: 600)
            HStack(alignment: .center, spacing: 110) {
                VStack(alignment: .leading, spacing: 36) {
                    HStack(spacing: 22) {
                        Image(nsImage: NSImage(contentsOfFile: "Resources/AppIcon-1024.png")!)
                            .resizable().frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        Text("Raster").font(.system(size: 56, weight: .semibold, design: .rounded))
                            .foregroundStyle(light ? Color.black.opacity(0.75) : Color.white.opacity(0.88))
                    }
                    Text(title)
                        .font(.system(size: 118, weight: .bold))
                        .kerning(-2)
                        .foregroundStyle(light ? Color.black : Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(light ? Color.black.opacity(0.55) : Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 1040, alignment: .leading)
                visual.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 150)
        }
        .frame(width: 2880, height: 1800)
    }
}

func panel(_ img: NSImage, height: CGFloat, light: Bool = false) -> some View {
    // Aufnahme ist 2× (Panel 640 pt hoch, Ecken 30 pt) – Ecken sauber rund ausschneiden
    Image(nsImage: img).resizable().interpolation(.high)
        .frame(width: height * img.size.width / img.size.height, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 30 / 640, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(light ? 0.2 : 0.55), radius: 60, y: 30)
}

// MARK: Texte

struct Copy { let title: String; let subtitle: String }
let texts: [String: [Copy]] = [
    "de": [
        Copy(title: "Fenster an ihren Platz. Sofort.", subtitle: "⌘← und ⌘→ legen das Fenster auf die Bildschirmhälfte, ⌘↑ maximiert. Noch einmal drücken wechselt die Breite."),
        Copy(title: "Jede Anordnung ein Klick.", subtitle: "Hälften, Viertel, Drittel, zentrieren und zurücksetzen – im Glas-Panel der Menüleiste."),
        Copy(title: "Alle Fenster auf einmal.", subtitle: "⌃⌥A teilt alle sichtbaren Fenster eines Bildschirms in ein Raster – oder nebeneinander, oder Fokus + Stapel."),
        Copy(title: "Gemacht für mehrere Bildschirme.", subtitle: "Es gilt der Bildschirm unter dem Mauszeiger. Fenster wandern per Kürzel zum nächsten Monitor."),
        Copy(title: "Deine Kürzel, deine Regeln.", subtitle: "Jedes Kürzel änderbar, Abstand zwischen Fenstern einstellbar – in Hell und Dunkel. Keine Datensammlung."),
    ],
    "en": [
        Copy(title: "Windows in place. Instantly.", subtitle: "⌘← and ⌘→ snap the window to half the screen, ⌘↑ maximizes. Press again to cycle the width."),
        Copy(title: "Every layout, one click.", subtitle: "Halves, quarters, thirds, center and restore – in a glass panel in your menu bar."),
        Copy(title: "All windows at once.", subtitle: "⌃⌥A tiles every visible window on a display into a grid – or side by side, or focus + stack."),
        Copy(title: "Made for multiple displays.", subtitle: "The display under your mouse pointer is the target. Send windows to the next display with a shortcut."),
        Copy(title: "Your shortcuts, your rules.", subtitle: "Change any shortcut and set the gap between windows – in light and dark. No data collection."),
    ],
]
let t = texts[lang]!
let screen = CGSize(width: 1320, height: 830)
let blue = Color(red: 0.36, green: 0.52, blue: 1.0), teal = Color(red: 0.2, green: 0.78, blue: 0.8)
let orange = Color(red: 1.0, green: 0.6, blue: 0.3), pink = Color(red: 0.95, green: 0.4, blue: 0.65)

@MainActor func render<V: View>(_ name: String, _ view: V) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("Rendern fehlgeschlagen: \(name)") }
    // App Store verlangt Bilder ohne Alphakanal
    let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    let data = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try! data.write(to: target.appendingPathComponent("\(name).png"))
    print("✓", name, cg.width, "×", cg.height)
}

MainActor.assumeIsolated {
    render("01-haelften", Slide(title: t[0].title, subtitle: t[0].subtitle) {
        VStack(spacing: 60) {
            MockScreen(windows: [(CGRect(x: 0, y: 0, width: 0.5, height: 1), blue, true),
                                 (CGRect(x: 0.5, y: 0, width: 0.5, height: 1), teal, false)], size: screen)
            KeyCaps(keys: ["⌘", "←"])
        }
    })
    render("02-panel", Slide(title: t[1].title, subtitle: t[1].subtitle) {
        panel(image("dark/uebersicht-dunkel.png"), height: 1560)
    })
    render("03-alle-fenster", Slide(title: t[2].title, subtitle: t[2].subtitle) {
        VStack(spacing: 60) {
            MockScreen(windows: [(CGRect(x: 0, y: 0, width: 0.5, height: 0.5), blue, true),
                                 (CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5), teal, false),
                                 (CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), orange, false),
                                 (CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5), pink, false)], size: screen)
            KeyCaps(keys: ["⌃", "⌥", "A"])
        }
    })
    render("04-bildschirme", Slide(title: t[3].title, subtitle: t[3].subtitle) {
        VStack(spacing: 50) {
            HStack(alignment: .bottom, spacing: 40) {
                MockScreen(windows: [(CGRect(x: 0, y: 0, width: 1, height: 1), orange, false)],
                           size: CGSize(width: 500, height: 320))
                MockScreen(windows: [(CGRect(x: 0, y: 0, width: 0.5, height: 1), blue, true),
                                     (CGRect(x: 0.5, y: 0, width: 0.5, height: 1), teal, false)],
                           size: CGSize(width: 780, height: 490))
            }
            KeyCaps(keys: ["⌃", "⌥", "⌘", "→"])
        }
    })
    render("05-einstellungen", Slide(title: t[4].title, subtitle: t[4].subtitle, light: true) {
        HStack(spacing: 50) {
            panel(image("light/einstellungen-hell.png"), height: 1140, light: true)
            panel(image("dark/einstellungen-dunkel.png"), height: 1140)
        }
    })
}
