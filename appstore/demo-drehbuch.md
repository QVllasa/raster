# Drehbuch: Review-Video für Apple (Guideline 2.1)

Ziel: eine durchgehende Bildschirmaufnahme ohne Schnitt, auf echtem Mac mit macOS 27,
TestFlight-Build 23 (= eingereichter Build). Beginnt mit dem ersten Start der App.

## Vorher (einmalig bzw. vor jeder Aufnahme)
- macOS 27 installiert, TestFlight mit info@vllasa.com, Build 23 installiert.
- GitHub-Variante (io.github.qvllasa.raster) beendet, damit Kürzel nicht doppelt belegt sind.
- Für eine Aufnahme ab Erststart: Bedienungshilfen-Freigabe von com.vllasa.raster zurückgesetzt
  (User: `tccutil reset Accessibility com.vllasa.raster`), alte „Raster“-Einträge aus der Liste entfernt.
- „Nicht stören“ an, keine privaten Fenster auf dem aufgenommenen Bildschirm: nur Finder, TextEdit
  und Notizen/Karten mit neutralem Inhalt; Dock und Menüleiste ohne persönliche Daten.

## Ablauf im Video
1. Leerer Schreibtisch mit drei neutralen Fenstern (TextEdit, Finder, Rechner o. Ä.), unsortiert.
2. Raster aus TestFlight/Programme starten → Panel öffnet sich unter dem Menüleistensymbol.
3. Hinweis auf fehlende Bedienungshilfen-Freigabe → Systemeinstellungen öffnen →
   Raster einschalten (User bestätigt mit Touch ID/Passwort) → zurück, Panel zeigt Bereitschaft.
4. Frage nach „Beim Anmelden öffnen“ beantworten (sichtbar, dass nur mit Zustimmung).
5. TextEdit anklicken → Cmd+Links (linke Hälfte), Finder → Cmd+Rechts (rechte Hälfte).
6. Cmd+Hoch maximiert, erneut Cmd+Hoch stellt wieder her.
7. Panel öffnen, Kachel „Viertel oben links“ o. Ä. anklicken → Fenster springt.
8. Ctrl+Option+A (Raster), Ctrl+Option+S (nebeneinander), Ctrl+Option+M (Fokus + Stapel).
9. Rechtsklick auf das Symbol → Einstellungen: Kürzel, Abstand ändern und Wirkung zeigen.
10. Rechtsklick → „Tastenkürzel pausieren“ → Cmd+Links wirkt nicht → wieder einschalten.
11. Rechtsklick → Raster beenden. Ende.

Jede gedrückte Tastenkombination wird unten im Bild als Einblendung gezeigt, weil
Tastendrücke in einer Bildschirmaufnahme sonst unsichtbar sind.

## Prüfliste pro Aufnahme (Bild für Bild)
- Beginnt wirklich mit dem Start der App, kein Schnitt, alle 11 Schritte vorhanden.
- Jede Aktion hat sichtbar die erwartete Wirkung; kein Ruckeln, kein falsches Fenster aktiv.
- Keine privaten Inhalte: keine Mitteilungen, Namen, Mails, Chats, Pfade mit persönlichem Inhalt.
- Einblendungen korrekt, lesbar und synchron mit der Aktion.
- Texte im Bild lesbar (Auflösung), keine abgeschnittenen Ränder.
- Einheitliche Sprache (Englisch) in App und System, damit Apple alles versteht.
