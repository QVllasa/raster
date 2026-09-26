# Raster App Store – Umsetzungsplan

> REQUIRED SUB-SKILL: superpowers:executing-plans. Spec: docs/superpowers/specs/2026-09-26-raster-appstore-design.md

1. **Private API entfernen** – `AXWindow` ohne `_AXUIElementGetWindow`; `WindowKey` = AX-Identität; `WindowManager.match(entries:windows:)` ordnet über PID + Rahmen (±2 pt, jedes AX-Fenster höchstens einmal). Test `testMatchByFrame` zuerst.
2. **Flavor** – `Flavor.isAppStore`; Snapshot nur ohne APPSTORE; Autostart-Zustimmung (`LoginConsent.needsPrompt(isAppStore:answered:)`, Test `testLoginConsent`) + Karte im Panel.
3. **Zweisprachig** – en.lproj/de.lproj Localizable.strings (Schlüssel = deutscher Text), `String(localized:)` für Modelltexte, `scripts/check-strings.py` prüft Vollständigkeit; Info.plist `CFBundleDevelopmentRegion en`, `CFBundleLocalizations [en, de]`.
4. **Store-Build** – appstore/Raster.entitlements, `scripts/build-appstore.sh`, Bundle-ID + Profil per API; `--ax-probe` gegen den signierten Sandbox-Build.
5. **Store-Material** – appstore/metadata.json (de-DE, en-US inkl. Prüferhinweis), docs/ Website (en + de), Screenshots 2880 × 1800 (de, en), `scripts/asc_submit.py` (mehrsprachig).
6. **Einreichung** – Upload über den alten Mac, `prepare` / `attach` / `submit`, sobald App-Eintrag und Website existieren.
