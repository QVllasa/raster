"""Erzeugt Resources/{en,de}.lproj/Localizable.strings.

Schlüssel sind die deutschen Texte im Code; Resources/l10n/en.json enthält die englischen Übersetzungen.
Das Skript sucht alle übersetzbaren Texte in Sources/ und bricht ab, wenn eine Übersetzung fehlt.
Aufruf: python3 scripts/gen-strings.py [--list]
"""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
PATTERNS = [
    r'String\(localized: "((?:[^"\\]|\\.)*)"\)',
    r'(?<![A-Za-z])Text\("((?:[^"\\]|\\.)*)"\)',
    r'Button\("((?:[^"\\]|\\.)*)"\)',
    r'\.help\("((?:[^"\\]|\\.)*)"\)',
    r'(?:title|help): "((?:[^"\\]|\\.)*)"',
]

def key_of(literal: str) -> str:
    # Swift-Interpolation → Formatplatzhalter, wie SwiftUI/String(localized:) den Schlüssel bildet.
    return re.sub(r'\\\((?:[^()]|\([^()]*\))*\)', lambda m: "%lld" if re.search(r"[Cc]ount|Int\(", m.group(0)) else "%@", literal)

keys = set()
for f in (root / "Sources").rglob("*.swift"):
    if f.name in ("SelfTest.swift", "Snapshot.swift", "Diagnostics.swift"):
        continue
    text = f.read_text()
    for pattern in PATTERNS:
        for m in re.finditer(pattern, text):
            if re.search(r"[A-Za-zÄÖÜäöü]", m.group(1)):
                keys.add(key_of(m.group(1)))

if "--list" in sys.argv:
    print("\n".join(sorted(keys, key=str.lower)))
    sys.exit(0)

en = json.loads((root / "Resources/l10n/en.json").read_text())
missing = sorted(k for k in keys if k not in en)
unused = sorted(k for k in en if k not in keys)
if missing:
    print("✗ Übersetzung fehlt für:\n  " + "\n  ".join(missing))
    sys.exit(1)

def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

for lang, table in [("en", en), ("de", {k: k for k in en})]:
    d = root / f"Resources/{lang}.lproj"
    d.mkdir(parents=True, exist_ok=True)
    lines = [f"/* Raster – {lang} (erzeugt von scripts/gen-strings.py, nicht von Hand bearbeiten) */", ""]
    lines += [f'"{esc(k)}" = "{esc(v)}";' for k, v in sorted(table.items(), key=lambda kv: kv[0].lower())]
    (d / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"✓ {len(keys)} Texte übersetzt" + (f", {len(unused)} unbenutzt: {unused}" if unused else ""))
