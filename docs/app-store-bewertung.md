# Raster im Mac App Store – Bewertung (26.09.2026)

**Ergebnis: Ja – mit genau einer Ausnahme-Berechtigung läuft Raster vollständig in der App-Sandbox.**
Raster erscheint daher zusätzlich zur freien GitHub-Version als kostenlose App im Mac App Store
(Anbieter: Vllasa Ventures UG (haftungsbeschränkt), Bundle-ID `com.vllasa.raster`).

## Das Problem

Apps im Mac App Store müssen in der App-Sandbox laufen (Review-Richtlinie 2.4.5 i). Die Sandbox sperrt
standardmäßig die Accessibility-API gegenüber **anderen** Apps – genau die Schnittstelle, mit der Raster
Fenster liest und verschiebt. Das Systemprotokoll nennt den Grund:

```
Sandbox: Raster deny(1) mach-lookup com.apple.axserver (per-pid)
```

## Die Lösung

Eine einzige Ausnahme erlaubt der Sandbox genau diesen Zugriff:

```xml
<key>com.apple.security.temporary-exception.mach-lookup.local-name</key>
<array><string>com.apple.axserver</string></array>
```

`…mach-lookup.global-name` allein reicht nicht, `…local-name` allein reicht – es wird nur diese eine verwendet.
Die Freigabe „Bedienungshilfen“ muss der Nutzer weiterhin selbst erteilen.

## Gemessen

Mit `Raster --ax-probe <pid>` gegen ein TextEdit-Fenster (Freigabe erteilt):

| Variante | `AXWindows` von TextEdit | Fenster bewegt |
|---|---|---|
| ohne Sandbox (GitHub-Version) | ok | ✓ |
| ohne Sandbox, Hardened Runtime (notarisierbar) | ok | ✓ |
| Sandbox ohne Ausnahme | −25204 `cannotComplete` | ✗ |
| Sandbox + Ausnahme `…global-name` | −25204 `cannotComplete` | ✗ |
| Sandbox + Ausnahme `…local-name` | ok | ✓ |
| Store-Binary (`-DAPPSTORE`) mit den Store-Berechtigungen, normal gestartet | ok, 8 von 8 sichtbaren Fenstern zugeordnet | ✓ |

## Was die Store-Version sonst anders macht

- keine privaten Schnittstellen (Fensteridentität über das AX-Element, Zuordnung zur Fensterliste über App und Rahmen)
- kein Snapshot-Modus (der nutzt `CGWindowListCreateImage`)
- Autostart erst nach ausdrücklicher Zustimmung (Richtlinie 2.4.5 iii)

## Risiko

Apple prüft Ausnahme-Berechtigungen einzeln. Die Begründung steht im Prüferhinweis
(`appstore/metadata.json`, `review_notes`). Lehnt Apple sie ab, bleibt die GitHub-Version – dort zusätzlich
mit Developer-ID-Signatur und Notarisierung (`scripts/notarize.sh`), sobald das Developer-ID-Zertifikat vorliegt.

Die bekannten älteren Fenster-Manager im Store (Magnet, BetterSnapTool, Divvy, Cinch, SplitScreen) stammen aus der
Zeit vor der Sandbox-Pflicht und laufen ohne Sandbox – bei SplitScreen nachgeprüft (`codesign -d --entitlements -`).
