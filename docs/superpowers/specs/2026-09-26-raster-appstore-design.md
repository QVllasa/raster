# Raster im Mac App Store (Design)

Stand: 26.09.2026 · Entscheidungen im Auftrag des Users („entscheide alles selbst“, „wenn dann unter Vllasa Ventures“).

## Ziel
Raster zusätzlich zur freien GitHub-Version als kostenlose App im Mac App Store anbieten – Anbieter
**Vllasa Ventures UG (haftungsbeschränkt)**, Team QU9LB387VU – inklusive aller Store-Materialien.

## Machbarkeit (gemessen, siehe docs/app-store-bewertung.md)
Die App-Sandbox blockiert Accessibility-Anfragen an andere Apps (`deny mach-lookup com.apple.axserver (per-pid)`).
Mit genau einer Ausnahme-Berechtigung funktioniert es in der Sandbox vollständig:
`com.apple.security.temporary-exception.mach-lookup.local-name = [com.apple.axserver]`.
Die Ausnahme wird im Prüferhinweis begründet. Risiko: Apple kann sie ablehnen – dann bleibt die GitHub-Version.

## Entscheidungen
| Frage | Entscheidung |
|---|---|
| Bundle-ID Store | `com.vllasa.raster` (GitHub-Version bleibt `io.github.qvllasa.raster`, beide können nebeneinander existieren) |
| Name im Store | de: „Raster – Fenster anordnen“, en: „Raster – Window Tiling“ |
| Preis | kostenlos, alle Länder |
| Kategorien | Productivity (primär), Utilities |
| Sprachen | App und Store-Texte Deutsch + Englisch; Fallback Englisch (CFBundleDevelopmentRegion en) |
| Private Schnittstellen | `_AXUIElementGetWindow` entfällt in **beiden** Varianten: Fensteridentität über AX-Element (CFEqual/CFHash), Zuordnung zur Fensterliste über PID + Rahmen |
| Snapshot-Modus | nur GitHub-Variante (`#if !APPSTORE`), nutzt `CGWindowListCreateImage` per dlsym |
| Autostart | Store: erst nach Zustimmung (Karte im Panel beim ersten Start, Richtlinie 2.4.5 iii); GitHub: wie bisher automatisch |
| Build | `scripts/build-appstore.sh` mit `-DAPPSTORE`, Sandbox + Ausnahme, Profil eingebettet, Symbolprüfung, `productbuild` → .pkg |
| Upload | `altool` auf dem alten Mac (Xcode) per SSH, wie bei Puls |
| Website | GitHub Pages `qvllasa.github.io/raster` (en + de): Start, Support, Datenschutz, Impressum |
| Screenshots | 2880 × 1800, ohne Alphakanal, je Sprache 5 Stück |

## Was nur der User tun kann
1. App-Eintrag in App Store Connect anlegen (API erlaubt kein CREATE auf `apps`).
2. `gh auth login` (Repository + GitHub Pages für Support-/Datenschutz-URL).

## Tests
Selbsttest um Zuordnung „Fensterliste ↔ AX-Fenster über Rahmen“ und Autostart-Zustimmung erweitern;
`--ax-probe` gegen den signierten Store-Build in der Sandbox; Übersetzungsprüfung per Skript (jeder Schlüssel übersetzt).
