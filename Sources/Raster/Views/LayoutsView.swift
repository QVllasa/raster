import SwiftUI

/// Übersicht im Panel: alle Anordnungen als Kacheln, gruppiert. Klick wendet sie auf das vorderste Fenster an.
struct LayoutsView: View {
    @Environment(PanelState.self) private var state
    @Environment(Accessibility.self) private var accessibility
    @Environment(Preferences.self) private var prefs

    var body: some View {
        VStack(spacing: 10) {
            if !accessibility.isTrusted {
                PermissionCard()
            }
            SectionCard(title: "Hälften & Vollbild") {
                TileRow(actions: ActionGroup.halves.actions)
                TileRow(actions: ActionGroup.screen.actions)
            }
            SectionCard(title: "Viertel & Drittel") {
                TileRow(actions: ActionGroup.quarters.actions)
                TileRow(actions: ActionGroup.thirds.actions, compact: true)
            }
            SectionCard(title: "Alle Fenster", trailing: state.windowCount == 1 ? "1 Fenster" : "\(state.windowCount) Fenster") {
                TileRow(actions: ActionGroup.allWindows.actions)
            }
            if state.screenCount > 1 {
                SectionCard(title: "Bildschirme", trailing: "\(state.screenCount) angeschlossen") {
                    TileRow(actions: ActionGroup.displays.actions)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: prefs.targetScreen == .mouse ? "cursorarrow" : "macwindow")
                Text(prefs.targetScreen == .mouse ? "Ziel ist der Bildschirm unter dem Mauszeiger"
                                                  : "Ziel ist der Bildschirm des aktiven Fensters")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
    }
}

struct TileRow: View {
    var actions: [WindowAction]
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ForEach(actions) { LayoutTile(action: $0, compact: compact) }
        }
    }
}

struct LayoutTile: View {
    var action: WindowAction
    var compact = false
    @Environment(PanelState.self) private var state
    @Environment(Preferences.self) private var prefs
    @State private var hovering = false

    var body: some View {
        let shortcut = prefs.shortcuts[action]?.displayString
        Button { state.perform(action) } label: {
            VStack(spacing: 3) {
                ScreenPreview(rects: action.preview, symbol: action.overlaySymbol, active: hovering)
                    .frame(height: compact ? 22 : 25)
                Text(action.shortTitle)
                    .font(.system(size: compact ? 10 : 10.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(shortcut ?? "–")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, compact ? 4 : 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .card(cornerRadius: 13, highlighted: hovering)
            .scaleEffect(hovering ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .onHover { over in withAnimation(.snappy(duration: 0.18)) { hovering = over } }
        .help(shortcut.map { "\(action.title) – \($0)" } ?? action.title)
        .accessibilityLabel(action.title)
    }
}

struct PermissionCard: View {
    @Environment(Accessibility.self) private var accessibility

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange.gradient)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text("Freigabe fehlt").font(.callout.weight(.semibold))
                Text("Raster braucht die Freigabe „Bedienungshilfen“, um Fenster anderer Apps zu verschieben. In den Systemeinstellungen Raster einschalten – danach geht es sofort los.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Systemeinstellungen öffnen") {
                    accessibility.request()
                    accessibility.openSettings()
                }
                .buttonStyle(.glassProminent)
                .tint(.orange)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.orange.opacity(0.12))
        }
        .card()
    }
}
