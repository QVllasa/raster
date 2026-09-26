# Raster im Mac App Store? – Bewertung (26.09.2026)

**Ergebnis: Nein. Raster wird stattdessen mit Developer ID signiert und von Apple notarisiert.**
Für Nutzer ist das genauso vertrauenswürdig: Die App öffnet sich ohne Gatekeeper-Warnung.

## Warum nicht der App Store

Apps im Mac App Store müssen in der App-Sandbox laufen (Review-Richtlinie 2.4.5 i). Die Sandbox sperrt
aber genau die Schnittstelle, von der Raster lebt: die Accessibility-API, mit der eine App Fenster
**anderer** Apps liest und verschiebt.

Gemessen mit `Raster --ax-probe <pid>` gegen ein TextEdit-Fenster:

| Variante | `AXIsProcessTrusted` | `AXWindows` von TextEdit | Fenster bewegt |
|---|---|---|---|
| ohne Sandbox (GitHub-Version) | ja | ok | ✓ |
| ohne Sandbox, Hardened Runtime (notarisierbar) | ja | ok | ✓ |
| mit Sandbox, aus dem Terminal gestartet | ja | −25204 `cannotComplete` | ✗ |
| mit Sandbox, normal über LaunchServices gestartet | ja | −25204 `cannotComplete` | ✗ |

Die Freigabe „Bedienungshilfen“ war in allen Fällen erteilt – die Sandbox blockiert trotzdem jede Abfrage.

Die bekannten Fenster-Manager im Store (Magnet, BetterSnapTool, Divvy, Cinch, Moom, SplitScreen von Ginkapps)
stammen alle aus der Zeit vor der Sandbox-Pflicht (Juni 2012) und laufen als Altbestand ohne Sandbox –
bei SplitScreen per `codesign -d --entitlements -` nachgeprüft: keine `app-sandbox`-Berechtigung.
Neue Apps bekommen diese Ausnahme nicht. Eine Sandbox-Version von Raster könnte also keine Fenster bewegen
und würde entweder abgelehnt oder wäre nutzlos.

## Was stattdessen passiert

1. **Developer-ID-Zertifikat** für Vllasa Ventures UG (Team QU9LB387VU) – darf laut Apple nur der Kontoinhaber
   anlegen (API-Antwort: „This operation can only be performed by the Account Holder“). Die Zertifikatsanfrage
   liegt unter `~/.appstore-raster/devid.csr`, der private Schlüssel bleibt lokal.
2. `scripts/import-devid.sh <heruntergeladene .cer>` – einmalig, legt einen eigenen Schlüsselbund an.
3. `scripts/notarize.sh` – baut, signiert mit Hardened Runtime, lässt Apple notarisieren (`notarytool`,
   App-Store-Connect-API-Schlüssel), heftet das Ticket an und packt das Release-ZIP.
4. Das ZIP kommt als Release auf GitHub (`QVllasa/raster`).

Hinweis: Mit dem Wechsel von der lokalen Signatur auf Developer ID ändert sich die Signatur-Identität.
Die Bedienungshilfen-Freigabe muss danach **einmal** neu erteilt werden, bleibt dann aber über alle
künftigen Updates erhalten.
