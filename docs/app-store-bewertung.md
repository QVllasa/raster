# Raster im Mac App Store – Bewertung (Stand 08.10.2026)

**Ergebnis: Ja – die Store-Version läuft vollständig in der App-Sandbox, ohne Accessibility und ohne
Ausnahme-Berechtigung.** Fenster werden über einen mitgelieferten Kurzbefehl bewegt. Raster erscheint
zusätzlich zur freien GitHub-Version als kostenlose App im Mac App Store (Anbieter: Vllasa Ventures UG
(haftungsbeschränkt), Bundle-ID `com.vllasa.raster`).

## Der Weg bis hierher

1. **26.09.2026 – erster Ansatz:** Sandbox plus die Ausnahme
   `com.apple.security.temporary-exception.mach-lookup.local-name` für `com.apple.axserver`. Damit funktionierte
   die Accessibility-API auch in der Sandbox (gemessen mit `Raster --ax-probe`, siehe unten).
2. **02.10.2026 – Ablehnung (Build 33):** Richtlinie 2.4.5(i), die Ausnahme wird nicht gewährt, und 2.4.5
   („Accessibility-Missbrauch“). Apples Entwickler-Support bestätigt: Accessibility und App-Sandbox sind
   unvereinbar; Magnet, Moom, BetterSnapTool und Co. laufen aus der Zeit vor der Sandbox-Pflicht ohne Sandbox.
3. **08.10.2026 – Umbau:** Die Store-Version verwendet keine Accessibility mehr. Vorbild ist „941 Tiles“
   (blakecrosley.com, Juli 2026 freigegeben): Fenster über die öffentliche Fensterliste lesen, den Zielrahmen
   selbst berechnen, das Verschieben an Apples eigene Kurzbefehl-Aktionen abgeben.

## Wie die Store-Version Fenster bewegt

- **Lesen:** `CGWindowListCopyWindowInfo` liefert Besitzer-App, Fensternummer und Rahmen aller sichtbaren
  Fenster (`Sources/Raster/Core/WindowList.swift`). Keine Freigabe nötig, keine Fensterinhalte oder -titel.
- **Rechnen:** Kacheln, Raster, Ränder wie bisher (`WindowManager`), unabhängig von der Fensterquelle
  (`protocol WindowHandle`).
- **Bewegen:** Ein Begleit-Kurzbefehl „Raster“ liegt im App-Paket (`Resources/Raster.shortcut`, erzeugt und
  signiert von `scripts/make-shortcut.py`). Er besteht aus Apples Systemaktionen *Wörterbuch lesen → Fenster
  suchen (App-Name, X- und Y-Position) → Fenstergröße ändern → Fenster bewegen → Fenstergröße ändern*.
  Raster übergibt ihm `{"app":"TextEdit","x0":120,"y0":80,"x":0,"y":25,"w":756,"h":920}` und ruft ihn über den
  dokumentierten Befehl `run shortcut … with input` von **Shortcuts Events** auf (`ShortcutEngine.swift`),
  also per Apple-Event, im Hintergrund, ohne dass die Kurzbefehle-App in den Vordergrund kommt.
- **Einrichtung:** Beim ersten Öffnen des Panels fragt macOS die Automation ab („Raster möchte Shortcuts
  Events steuern“). Das Panel zeigt dann die Karte „Kurzbefehl „Raster“ hinzufügen“; ein Klick öffnet den
  Kurzbefehl in der Kurzbefehle-App, dort ein Klick auf „Kurzbefehl hinzufügen“. Fertig.

## Berechtigungen der Store-Version

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.scripting-targets</key>
<dict>
    <key>com.apple.shortcuts.events</key>
    <array><string>com.apple.shortcuts.run</string></array>
</dict>
```

Keine temporäre Ausnahme. `com.apple.shortcuts.run` ist die Zugriffsgruppe, die Shortcuts Events in seiner
Skript-Definition (`sdef`) für den Befehl `run shortcut` deklariert. Der Store-Build bricht ab, wenn die
Berechtigungen das Wort `temporary-exception` enthalten oder das Programm ein `_AX*`-Symbol importiert
(`scripts/build-appstore.sh`).

## Gemessen

Lokal mit der Store-Variante unter Sandbox (`scripts/build-store-local.sh`, gleiche Berechtigungen, lokale
Signatur) und `Raster --shortcut-probe <pid>` gegen ein TextEdit-Fenster:

| Prüfung | Ergebnis |
|---|---|
| Programm importiert `_AX*`-Symbole | 0 (`nm -u`) |
| Selbsttest (`--selftest`, beide Varianten) | 141 Prüfungen bestanden |
| Kurzbefehl aus dem App-Paket importierbar | ✓ (Doppelklick/`open` → Kurzbefehle zeigt „Kurzbefehl hinzufügen“) |
| `run shortcut` aus der Sandbox nur mit `scripting-targets` | ✓ – Automations-Abfrage erscheint einmal, danach kein Dialog; keine temporäre Ausnahme nötig |
| Fenster über den Kurzbefehl bewegt und Rahmen wie berechnet | ✓ – TextEdit: Ziel (0, 33, 756, 920) → Fensterliste (0, 33, 756, 920) |
| Laufzeit eines Aufrufs (`run shortcut` über Shortcuts Events) | 0,2 s warm, 2,6 s beim allerersten Aufruf |
| Tastenkürzel in der laufenden Sandbox-App (Hälften, Maximieren + Wiederherstellen, Zyklus, Raster, Nebeneinander, Fokus + Stapel) | ✓ alle |

Gemessene Eigenheiten: Die Aktion „Fenster suchen“ vergleicht X/Y-Position in globalen Bildschirmpunkten mit
Ursprung oben links, also genau den Werten der Fensterliste (`kCGWindowBounds`). Der Window-Server meldet den
neuen Rahmen erst kurz nach der Rückkehr des Kurzbefehls – `ShortcutWindow.setFrame` liest deshalb bis 0,5 s
nach, bis der Rahmen am Ziel oder stabil ist (sonst galt ein bewegtes Fenster als „abgelehnt“). Minimierte
Fenster fehlen in der Fensterliste und werden beim Kacheln ausgelassen.

Zum Vergleich die Messung des ersten Ansatzes (26.09.2026, `Raster --ax-probe`): ohne Sandbox ok; Sandbox ohne
Ausnahme −25204 `cannotComplete`; Sandbox mit `…mach-lookup.local-name com.apple.axserver` ok. Dieser Weg ist
seit der Ablehnung vom 02.10.2026 geschlossen.

## Was die Store-Version sonst anders macht

- keine Accessibility, keine Freigabe „Bedienungshilfen“, keine privaten Schnittstellen
- kein Snapshot-Modus (der nutzt `CGWindowListCreateImage`)
- Autostart erst nach ausdrücklicher Zustimmung (Richtlinie 2.4.5 iii)
- Fensteridentität über die Fensternummer der Fensterliste; der Kurzbefehl findet das Fenster über App-Name
  und aktuelle Position, deshalb werden Positionen ganzzahlig übergeben

## Risiko

Apple hat mit 941 Tiles im Juli 2026 genau dieses Muster freigegeben. Offen bleibt, ob der Prüfer die
Einrichtung (Automations-Abfrage, Kurzbefehl hinzufügen) als zumutbar ansieht; die Schritte stehen im
Prüferhinweis (`appstore/review-notes.txt`) und im Bildschirmvideo. Lehnt Apple erneut ab, bleibt die
GitHub-Version mit Accessibility – dort zusätzlich mit Developer-ID-Signatur und Notarisierung
(`scripts/notarize.sh`), sobald das Developer-ID-Zertifikat vorliegt.
