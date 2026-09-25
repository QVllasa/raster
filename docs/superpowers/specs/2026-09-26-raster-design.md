# Raster – Fenster anordnen per Tastenkürzel (Design)

Stand: 26.09.2026 · Autor: Claude (Entscheidungen im Auftrag des Users getroffen: „entscheide alles selbst“)

## Ziel

Eine eigene, schlanke Menüleisten-App für das neue MacBook, die die alte App „SplitScreen“ (Ginkapps, v4.6)
ersetzt. Mit Tastenkürzeln wird das aktive Fenster auf eine Bildschirmhälfte, ein Viertel, ein Drittel oder
Vollbild gebracht, und alle Fenster eines Bildschirms lassen sich auf einmal aufteilen. Die App startet mit
dem Mac, ist immer in der Menüleiste sichtbar und dort über ein Liquid-Glass-Panel bedien- und einstellbar –
im selben Stil und mit derselben Architektur wie „Puls“ (`~/Projects/puls`).

**Was der User gesagt hat:** ⌘← / ⌘→ bringen ein Fenster auf die linke/rechte Hälfte; Autostart; Fenster
eines Bildschirms anordnen und aufteilen; mehrere Bildschirme berücksichtigen, maßgeblich ist der Bildschirm
mit der Maus bzw. der aktive; Liquid Glass; immer sichtbar und einstellbar in der Menüleiste wie Puls.

**Belegt vom alten Mac (per SSH ausgelesen):** SplitScreen hatte genau drei Kürzel: ⌘← (linke Hälfte),
⌘→ (rechte Hälfte), ⌘↑ (Vollbild) – jeweils nur Command. Diese werden 1:1 die Standardbelegung.

**Erfolgskriterien**
1. ⌘← / ⌘→ / ⌘↑ verhalten sich wie früher – ohne dass der User etwas einstellen muss.
2. Bei mehreren Bildschirmen landet das Fenster auf dem Bildschirm unter dem Mauszeiger (umstellbar auf
   „Bildschirm des aktiven Fensters“).
3. Ein Kürzel teilt alle sichtbaren Fenster des Zielbildschirms in ein Raster auf.
4. Die App startet nach jedem Neustart von selbst und bleibt in der Menüleiste.
5. Nach einem Update/Neubau bleibt die Bedienungshilfen-Freigabe gültig (stabile Signatur).

## Nicht-Ziele (YAGNI)

Kein Einrasten per Ziehen an den Bildschirmrand, keine App-Ausnahmelisten, keine eigenen Layout-Editoren,
kein Sparkle-Updater, kein App Store, keine Spaces-Verwaltung.

## Entscheidungen

| Frage | Entscheidung | Begründung |
|---|---|---|
| Name | **Raster**, Bundle-ID `io.github.qvllasa.raster` | kurz, deutsch, passt zu „Puls“ |
| Technik | Swift-Package ohne Xcode-Projekt, AppKit + SwiftUI, macOS 26 | wie Puls; Xcode ist nicht installiert |
| Globale Kürzel | Carbon `RegisterEventHotKey` | braucht keine Freigabe, hat Vorrang vor App-Kürzeln (wie SplitScreen/MASShortcut) |
| Fenster bewegen | Accessibility-API (`AXUIElement`) | einziger offizieller Weg für fremde Fenster; braucht Freigabe „Bedienungshilfen“ |
| Zielbildschirm | Standard **Maus**, umschaltbar auf **aktives Fenster** | Wunsch des Users |
| Erneutes Drücken derselben Hälfte | Standard **Breite wechseln** (½ → ⅔ → ⅓), wählbar: *Nichts* / *Zum Nachbarbildschirm* | bewährt (Rectangle); Nachbarbildschirm als Windows-artige Alternative bei mehreren Monitoren |
| Abstand zwischen Fenstern | 0–24 pt, Standard **0** | SplitScreen hatte keinen Abstand |
| Autostart | `SMAppService.mainApp`, beim ersten Start automatisch an | wie Puls |
| Signatur | eigene lokale Identität „Raster Local Signing“ im Schlüsselbund `raster-signing.keychain-db`, Fallback ad hoc | Freigabe bleibt über Neubauten gültig |
| Panel nach Klick auf ein Layout | schließt sich | Fokus geht sofort zurück zur Arbeit |
| Kürzel pausieren | Rechtsklick-Menü „Tastenkürzel pausieren“ | ⌘←/⌘→ überdecken sonst „Zeilenanfang/-ende“ in Texteingaben – schnelle Abhilfe ohne Einstellungen |

### Aktionen und Standard-Kürzel

| Gruppe | Aktion | Kürzel |
|---|---|---|
| Hälften | Linke Hälfte | ⌘← |
| | Rechte Hälfte | ⌘→ |
| | Obere Hälfte | ⌃⌥↑ |
| | Untere Hälfte | ⌃⌥↓ |
| Ganzer Bildschirm | Maximieren | ⌘↑ |
| | Fast maximieren (90 %, zentriert) | ⌃⌥↩ |
| | Zentrieren (Größe bleibt) | ⌃⌥C |
| | Wiederherstellen (Größe vor dem ersten Einrasten) | ⌃⌥⌫ |
| Viertel | Oben links / oben rechts / unten links / unten rechts | ⌃⌥U / ⌃⌥I / ⌃⌥J / ⌃⌥K |
| Drittel | Linkes / mittleres / rechtes Drittel | ⌃⌥D / ⌃⌥F / ⌃⌥G |
| | Linke / rechte zwei Drittel | ⌃⌥E / ⌃⌥T |
| Bildschirme | Auf nächsten / vorherigen Bildschirm | ⌃⌥⌘→ / ⌃⌥⌘← |
| Alle Fenster | Raster (alle sichtbaren Fenster des Bildschirms) | ⌃⌥A |
| | Nebeneinander (Spalten) | ⌃⌥S |
| | Fokus links, Rest rechts gestapelt | ⌃⌥M |

Alle Kürzel sind in den Einstellungen per Aufnahme-Feld änderbar oder löschbar. Ein Kürzel muss ⌘ oder ⌃
enthalten (macOS lehnt reine ⌥-Kürzel ab). Doppelt vergebene Kürzel werden bei der alten Aktion entfernt.

## Architektur

```
Sources/Raster/
  App/        main.swift, AppDelegate, StatusItemController, GlassPanel, Preferences, SelfTest, Snapshot
  Core/       WindowAction (Katalog), Shortcut (Tastenkürzel-Modell), HotKeyCenter (Carbon),
              LayoutMath (reine Geometrie), ScreenGeometry (Koordinaten + Bildschirmwahl),
              AXWindow (AX-Wrapper), WindowManager (führt Aktionen aus), Accessibility (Freigabe)
  Views/      PanelRootView, LayoutsView (Kacheln), SettingsView, ShortcutRecorder, Components
```

- **LayoutMath** ist rein funktional (Rechtecke rein, Rechtecke raus) und damit ohne Fenster testbar:
  Zielrechteck je Aktion inkl. Abstand, Raster-/Spalten-/Stapel-Aufteilung für n Fenster, Breiten-Zyklus,
  proportionale Übertragung auf einen anderen Bildschirm.
- **ScreenGeometry** rechnet zwischen Cocoa-Koordinaten (Ursprung unten links) und AX/CG-Koordinaten
  (Ursprung oben links am Hauptbildschirm) um und wählt den Zielbildschirm (Maus / größte Überdeckung mit dem
  Fenster / Nachbar links-rechts / nächster-vorheriger in Leserichtung). Arbeitet auf reinen `CGRect`-Listen,
  damit auch das testbar ist.
- **WindowManager** holt das fokussierte Fenster (`frontmostApplication` → `AXFocusedWindow`), berechnet das
  Ziel, setzt Größe → Position → Größe (fängt Mindestgrößen und Bildschirmwechsel ab), schaltet dabei
  `AXEnhancedUserInterface` kurz ab und korrigiert, falls ein Fenster größer bleibt als verlangt. Merkt sich
  pro Fenster (PID + CGWindowID) die Ursprungsgröße für „Wiederherstellen“ und die letzte Aktion für den Zyklus.
- **Alle Fenster**: `CGWindowListCopyWindowInfo(onScreenOnly)` liefert sichtbare Fenster in Z-Reihenfolge;
  Ebene 0, Mitte auf dem Zielbildschirm, mind. 100×60, nicht die eigene App; per CGWindowID den passenden
  AX-Fenstern zugeordnet (nur `AXStandardWindow`, nicht minimiert). Vorderstes Fenster kommt oben links hin.
- **HotKeyCenter** registriert alle Kürzel, meldet belegte Kombinationen (Fehler von `RegisterEventHotKey`)
  zurück an die Oberfläche und kann pausiert werden (Aufnahme-Modus, Menüpunkt „pausieren“).
- **Accessibility** prüft `AXIsProcessTrusted()`, fragt beim ersten Start nach und pollt alle 1,5 s, solange
  die Freigabe fehlt; die Oberfläche zeigt dann einen Hinweis mit Knopf zu den Systemeinstellungen.

## Oberfläche (Liquid Glass)

Rahmenloses `NSPanel` mit `NSGlassEffectView` (wie Puls), 384 pt breit, am Menüleisten-Symbol verankert,
schließt bei Klick daneben oder Esc. Menüleisten-Symbol: Vorlagenbild (zwei Fensterhälften), passt sich hell/dunkel an.

- **Kopf:** App-Glyphe, „Raster“, darunter der Zielbildschirm und die Anzahl sichtbarer Fenster
  (z. B. „Studio Display · 4 Fenster“), Zahnrad → Einstellungen.
- **Hinweiskarte** (nur ohne Freigabe): orange, „Bedienungshilfen freigeben“.
- **Kachel-Gruppen** als Glaskarten: Hälften, Ganzer Bildschirm, Viertel, Drittel, Alle Fenster, Bildschirme.
  Jede Kachel zeigt einen Mini-Bildschirm mit hervorgehobener Zielfläche (Verlauf Indigo → Cyan), den Namen
  und das Kürzel; Hover hebt die Kachel an. Klick wendet die Aktion auf das vorderste Fenster an.
- **Einstellungen:** Zielbildschirm (Segment), erneutes Drücken (Menü), Abstand (Schieber), beim Anmelden
  starten; Liste aller Aktionen mit Kürzel-Aufnahme (Klick → Tasten drücken, Esc bricht ab, ⌫ löscht),
  Warnsymbol bei nicht registrierbaren Kürzeln, „Standard wiederherstellen“; Freigabe-Status; Version + Beenden.
- **Rechtsklick-Menü:** Raster öffnen, Einstellungen …, Tastenkürzel pausieren, Raster beenden.

## Fehlerbehandlung

- Keine Freigabe → Aktion wird nicht ausgeführt, Systemabfrage + Panel mit Hinweiskarte öffnen.
- Kein fokussiertes Fenster / Fenster nicht verschiebbar (`AXSizable`/`AXPosition` nicht setzbar) → kurzer
  Systemton (`NSSound.beep`), sonst nichts.
- Vollbild-Fenster (`AXFullScreen`) werden übersprungen.
- Kürzel belegt → Warnsymbol mit Tooltip in den Einstellungen, übrige Kürzel funktionieren weiter.
- Bildschirm an-/abgesteckt → Bildschirme werden bei jeder Aktion frisch gelesen, kein Cache.

## Tests

- `Raster --selftest`: prüft LayoutMath und ScreenGeometry mit festen Beispiel-Bildschirmen (einzeln, zwei
  nebeneinander, versetzt übereinander, mit Menüleiste/Dock), Koordinaten-Umrechnung, Rasteraufteilung für
  1–9 Fenster, Zyklus, Kürzel-Darstellung und Codable-Rundreise. Beendet sich mit Exit-Code ≠ 0 bei Fehlern.
- `Raster --snapshot <ordner>`: fotografiert Panel-Ansichten (hell/dunkel) zur Sichtprüfung des Designs.
- Manuell nach Installation und Freigabe: ⌘←/⌘→/⌘↑ an einem echten Fenster, Raster mit mehreren Fenstern.

## Auslieferung

`scripts/build-app.sh` baut universell (arm64 + x86_64), signiert mit „Raster Local Signing“ (Fallback ad hoc),
packt ZIP; `scripts/install.sh` kopiert nach `/Applications/Raster.app`, beendet eine laufende Instanz und
startet neu. Beim ersten Start trägt sich Raster als Anmeldeobjekt ein.
