import SwiftUI

/// Übersicht im Panel: alle Anordnungen als Kacheln, gruppiert. Klick wendet sie auf das vorderste Fenster an.
struct LayoutsView: View {
    @Environment(PanelState.self) private var state
    @Environment(Preferences.self) private var prefs
    #if APPSTORE
    @Environment(ShortcutSetup.self) private var setup
    #else
    @Environment(Accessibility.self) private var accessibility
    #endif

    var body: some View {
        VStack(spacing: 10) {
            #if APPSTORE
            if !setup.isReady {
                StoreSetupCard()
            }
            #else
            if !accessibility.isTrusted {
                PermissionCard()
            }
            #endif
            if prefs.needsLoginConsent {
                LoginConsentCard()
            }
            SectionCard(title: "Hälften & Vollbild") {
                TileRow(actions: ActionGroup.halves.actions)
                TileRow(actions: ActionGroup.screen.actions)
            }
            SectionCard(title: "Viertel & Drittel") {
                TileRow(actions: ActionGroup.quarters.actions)
                TileRow(actions: ActionGroup.thirds.actions, compact: true)
            }
            SectionCard(title: "Alle Fenster", trailing: state.windowCount == 1 ? String(localized: "1 Fenster") : String(localized: "\(state.windowCount) Fenster")) {
                TileRow(actions: ActionGroup.allWindows.actions)
            }
            if state.screenCount > 1 {
                SectionCard(title: "Bildschirme", trailing: String(localized: "\(state.screenCount) angeschlossen")) {
                    TileRow(actions: ActionGroup.displays.actions)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: prefs.targetScreen == .mouse ? "cursorarrow" : "macwindow")
                Text(prefs.targetScreen == .mouse ? String(localized: "Ziel ist der Bildschirm unter dem Mauszeiger")
                                                  : String(localized: "Ziel ist der Bildschirm des aktiven Fensters"))
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

/// Store-Version: fragt einmal, ob Raster mit dem Mac starten soll.
struct LoginConsentCard: View {
    @Environment(Preferences.self) private var prefs

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text("Mit dem Mac starten?").font(.callout.weight(.semibold))
                Text("Dann stehen die Tastenkürzel nach jedem Neustart sofort bereit. Du kannst das jederzeit in den Einstellungen ändern.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Ja, automatisch starten") { answer(true) }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                    Button("Nein") { answer(false) }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func answer(_ start: Bool) {
        prefs.loginConsentAnswered = true
        prefs.launchAtLogin = start
    }
}

#if !APPSTORE
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
                Text("Raster braucht die Freigabe „Bedienungshilfen“, um Fenster anderer Apps zu verschieben. In den Systemeinstellungen Raster einschalten – danach geht es sofort los. Fehlt Raster in der Liste, unten auf „+“ klicken und Raster aus „Programme“ wählen.")
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
#else
/// Store-Version: Die Sandbox erlaubt keine Accessibility-Zugriffe – Fenster bewegt der Begleit-Kurzbefehl „Raster“.
/// Zwei Schritte: Kurzbefehl hinzufügen und Raster die Automation erlauben.
struct StoreSetupCard: View {
    @Environment(ShortcutSetup.self) private var setup

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange.gradient)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.callout.weight(.semibold))
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    switch setup.status {
                    case .notInstalled, .unknown:
                        Button("Kurzbefehl hinzufügen") { setup.install() }
                            .buttonStyle(.glassProminent)
                            .tint(.orange)
                            .controlSize(.small)
                    case .automationDenied:
                        Button("Systemeinstellungen öffnen") { setup.openAutomationSettings() }
                            .buttonStyle(.glassProminent)
                            .tint(.orange)
                            .controlSize(.small)
                    case .checking, .ready, .error:
                        EmptyView()
                    }
                    Button("Erneut prüfen") { Task { await setup.refresh() } }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(setup.status == .checking)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.orange.opacity(0.12))
        }
        .card()
        .task { if !setup.isReady { await setup.refresh() } }
    }

    private var title: String {
        switch setup.status {
        case .unknown, .checking: String(localized: "Einrichtung wird geprüft …")
        case .notInstalled: String(localized: "Kurzbefehl „Raster“ hinzufügen")
        case .automationDenied: String(localized: "Automation erlauben")
        case .error: String(localized: "Kurzbefehl nicht erreichbar")
        case .ready: ""
        }
    }

    private var explanation: String {
        switch setup.status {
        case .unknown, .checking:
            String(localized: "Raster fragt die Kurzbefehle-App, ob alles bereit ist. Beim ersten Mal bittet macOS um deine Erlaubnis – mit „Erlauben“ bestätigen.")
        case .notInstalled:
            String(localized: "Die App-Store-Version bewegt Fenster über Apples Kurzbefehle. Dafür einmal den mitgelieferten Kurzbefehl hinzufügen: Die Kurzbefehle-App öffnet sich, dort auf „Kurzbefehl hinzufügen“ klicken.")
        case .automationDenied:
            String(localized: "macOS braucht deine Erlaubnis, dass Raster Kurzbefehle ausführen darf: Systemeinstellungen → Datenschutz & Sicherheit → Automation → bei Raster „Kurzbefehle“ einschalten.")
        case .error(let message):
            String(localized: "Die Kurzbefehle-App hat nicht geantwortet: \(message)")
        case .ready:
            ""
        }
    }
}
#endif
