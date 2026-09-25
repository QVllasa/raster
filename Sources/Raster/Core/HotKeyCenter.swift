import Carbon
import Observation

/// Registriert die globalen Tastenkürzel über Carbon (`RegisterEventHotKey`). Das braucht keine Freigabe
/// und hat Vorrang vor den Kürzeln der Apps – genau wie früher bei SplitScreen.
@MainActor
@Observable
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// Aktionen, deren Kürzel macOS abgelehnt hat (z. B. vom System belegt).
    private(set) var failed: Set<WindowAction> = []
    /// Vom User pausiert (Rechtsklick-Menü) – alle Kürzel sind dann abgemeldet.
    var isPaused = false {
        didSet { if isPaused != oldValue { apply() } }
    }

    @ObservationIgnored var onAction: (WindowAction) -> Void = { _ in }
    @ObservationIgnored private var map: [WindowAction: Shortcut] = [:]
    @ObservationIgnored private var refs: [EventHotKeyRef] = []
    @ObservationIgnored private var handler: EventHandlerRef?
    @ObservationIgnored private var suspendedForRecording = false

    private static let signature: OSType = 0x5253_5452 // 'RSTR'

    private init() {}

    func register(_ map: [WindowAction: Shortcut]) {
        self.map = map
        apply()
    }

    /// Während ein Kürzel aufgenommen wird, dürfen die bestehenden nicht auslösen.
    func suspendForRecording() {
        suspendedForRecording = true
        apply()
    }

    func resumeAfterRecording() {
        suspendedForRecording = false
        apply()
    }

    private func apply() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        guard !isPaused, !suspendedForRecording else { return }
        installHandlerIfNeeded()

        var failures = Set<WindowAction>()
        for (index, action) in WindowAction.allCases.enumerated() {
            guard let shortcut = map[action] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id,
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
            } else {
                failures.insert(action)
                NSLog("Raster: Kürzel \(shortcut.displayString) für \(action.title) nicht registrierbar (\(status))")
            }
        }
        if failures != failed { failed = failures }
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == HotKeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let index = Int(id.id)
            // Carbon liefert Tastaturereignisse auf dem Hauptthread aus.
            MainActor.assumeIsolated {
                guard WindowAction.allCases.indices.contains(index) else { return }
                HotKeyCenter.shared.onAction(WindowAction.allCases[index])
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
