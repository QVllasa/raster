import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var prefs
    #if APPSTORE
    @Environment(ShortcutSetup.self) private var setup
    #else
    @Environment(Accessibility.self) private var accessibility
    #endif

    var body: some View {
        @Bindable var prefs = prefs
        VStack(spacing: 10) {
            SectionCard(title: "Verhalten") {
                HStack {
                    Text("Zielbildschirm")
                    Spacer()
                    Picker("", selection: $prefs.targetScreen) {
                        ForEach(TargetScreenMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                }
                HStack {
                    Text("Erneut drücken")
                    Spacer()
                    Picker("", selection: $prefs.repeatBehavior) {
                        ForEach(RepeatBehavior.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                HStack {
                    Text("Abstand")
                    Slider(value: $prefs.gap, in: 0...24, step: 2)
                        .controlSize(.small)
                    Text("\(Int(prefs.gap)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                SwitchRow(title: "Beim Anmelden starten", isOn: $prefs.launchAtLogin)
                if prefs.loginItemNeedsApproval {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("macOS wartet auf deine Erlaubnis für den Autostart.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Button("Erlauben") { SMAppService.openSystemSettingsLoginItems() }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
            }
            .font(.callout)

            SectionCard(title: "Tastenkürzel", trailing: String(localized: "Klicken zum Ändern")) {
                ForEach(ActionGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        ForEach(group.actions) { ShortcutRow(action: $0) }
                    }
                    .padding(.bottom, 2)
                }
                HStack {
                    Text("⌫ löscht ein Kürzel, ⎋ bricht ab")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Standard wiederherstellen") { prefs.resetShortcuts() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
            }

            #if APPSTORE
            SectionCard(title: "Kurzbefehl") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(setup.isReady ? Color.green.gradient : Color.orange.gradient)
                        .frame(width: 8, height: 8)
                    Text(setup.isReady ? String(localized: "Eingerichtet – Raster bewegt Fenster über den Kurzbefehl „Raster“") : String(localized: "Nicht eingerichtet"))
                        .font(.callout)
                    Spacer()
                    Button("Prüfen") { Task { await setup.refresh() } }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(setup.status == .checking)
                }
            }
            #else
            SectionCard(title: "Bedienungshilfen") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accessibility.isTrusted ? Color.green.gradient : Color.orange.gradient)
                        .frame(width: 8, height: 8)
                    Text(accessibility.isTrusted ? String(localized: "Freigegeben – Raster darf Fenster bewegen") : String(localized: "Nicht freigegeben"))
                        .font(.callout)
                    Spacer()
                    if !accessibility.isTrusted {
                        Button("Freigeben") {
                            accessibility.request()
                            accessibility.openSettings()
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                }
            }

            #endif

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "Raster \(Bundle.main.shortVersion)").font(.callout.weight(.semibold))
                    Text("Rechtsklick auf das Menüleisten-Symbol öffnet das Menü")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
                    .buttonStyle(.glass)
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }
}

struct ShortcutRow: View {
    var action: WindowAction
    @Environment(Preferences.self) private var prefs
    @Environment(PanelState.self) private var state
    @Environment(HotKeyCenter.self) private var hotKeys
    @State private var shake = 0

    var body: some View {
        let recording = state.recording == action
        HStack(spacing: 9) {
            ScreenPreview(rects: action.preview, symbol: action.overlaySymbol)
                .frame(width: 26, height: 17)
            Text(action.title).font(.callout)
            Spacer(minLength: 6)
            if hotKeys.failed.contains(action) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("Dieses Kürzel ist schon vom System oder einer anderen App belegt.")
            }
            Button {
                if recording {
                    state.stopRecording()
                } else {
                    state.startRecording(action, prefs: prefs) {
                        NSSound.beep()
                        withAnimation(.default) { shake += 1 }
                    }
                }
            } label: {
                Text(recording ? String(localized: "Tasten drücken …") : (prefs.shortcuts[action]?.displayString ?? String(localized: "Kein Kürzel")))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(recording ? AnyShapeStyle(Palette.accentTop) :
                                        prefs.shortcuts[action] == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    .frame(minWidth: 92)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .overlay {
                if recording {
                    Capsule().strokeBorder(Palette.accent, lineWidth: 1.5).allowsHitTesting(false)
                }
            }
            .modifier(ShakeEffect(shakes: CGFloat(shake)))
            .help(recording ? String(localized: "Neue Tastenkombination drücken – ⎋ bricht ab, ⌫ löscht") : String(localized: "Klicken, um das Kürzel zu ändern"))
        }
    }
}

/// Kurzes Wackeln, wenn eine Kombination ungültig ist (z. B. nur ⌥).
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(shakes * .pi * 4), y: 0))
    }
}
