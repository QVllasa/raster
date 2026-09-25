import AppKit
import SwiftUI

enum Palette {
    static let accentTop = Color(red: 0.38, green: 0.42, blue: 1.0)
    static let accentBottom = Color(red: 0.18, green: 0.78, blue: 0.96)
    static let accent = LinearGradient(colors: [accentTop, accentBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Heller, halbtransparenter Untergrund für Karten auf dem Glas-Panel (wie in Puls).
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    var highlighted = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(highlighted ? 0.13 : 0.06)
                                          : Color.white.opacity(highlighted ? 0.7 : 0.45))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.18 : 0.75),
                                                .white.opacity(scheme == .dark ? 0.03 : 0.2)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.8)
            }
    }
}

extension View {
    func card(cornerRadius: CGFloat = 18, highlighted: Bool = false) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

struct SectionCard<Content: View>: View {
    var title: String?
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.4)
                        .lineLimit(1)
                    Spacer()
                    if let trailing {
                        Text(trailing).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct GlassIconButton: View {
    var symbol: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(help)
    }
}

struct AppGlyph: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Palette.accent)
            HStack(spacing: size * 0.06) {
                RoundedRectangle(cornerRadius: size * 0.06, style: .continuous).fill(.white)
                VStack(spacing: size * 0.06) {
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous).fill(.white.opacity(0.75))
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous).fill(.white.opacity(0.55))
                }
            }
            .padding(size * 0.22)
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.accentTop.opacity(0.35), radius: 6, y: 2)
    }
}

/// Mini-Bildschirm mit den Zielflächen einer Aktion (Einheitsrechtecke, y von oben).
struct ScreenPreview: View {
    var rects: [CGRect]
    var symbol: String? = nil
    var active = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 2.5
            let area = CGRect(origin: .zero, size: geo.size).insetBy(dx: inset, dy: inset)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.primary.opacity(scheme == .dark ? 0.08 : 0.06))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.primary.opacity(active ? 0.35 : 0.2), lineWidth: 1)
                ForEach(Array(rects.enumerated()), id: \.offset) { index, unit in
                    let r = CGRect(x: area.minX + unit.minX * area.width, y: area.minY + unit.minY * area.height,
                                   width: unit.width * area.width, height: unit.height * area.height)
                        .insetBy(dx: 0.9, dy: 0.9)
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Palette.accent)
                        .opacity(index == 0 ? 1 : 0.72)
                        .frame(width: max(0, r.width), height: max(0, r.height))
                        .offset(x: r.minX, y: r.minY)
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: min(geo.size.height * 0.36, 12), weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
    }
}

struct SwitchRow: View {
    var title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
