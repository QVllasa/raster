#!/usr/bin/env python3
"""Erzeugt den Begleit-Kurzbefehl „Raster“ für die Mac-App-Store-Version.

Die Store-Version darf in der App-Sandbox keine Fenster anderer Apps per Accessibility bewegen.
Stattdessen übergibt sie das Ziel an diesen Kurzbefehl, der Apples eigene Aktionen
„Fenster suchen“, „Fenstergröße ändern“ und „Fenster bewegen“ (macOS 12+) ausführt.

Eingabe des Kurzbefehls (Text, JSON), alles in Bildschirmpunkten mit Ursprung oben links:
    {"app": "TextEdit", "x0": 120, "y0": 80, "x": 0, "y": 25, "w": 756, "h": 920}
app/x0/y0 bestimmen das Fenster (App-Name und aktuelle Position), x/y/w/h sind das Ziel.

Aufruf: python3 scripts/make-shortcut.py [--out VERZEICHNIS] [--name NAME]
Schreibt NAME.shortcut (signiert, für den Import per Doppelklick) und NAME.unsigned.shortcut.
Die Signatur erledigt `shortcuts sign` (macOS 12+, Kurzbefehle-App vorhanden).
"""
import argparse
import pathlib
import plistlib
import subprocess
import sys
import uuid

NAMESPACE = uuid.UUID("7d2c1e4a-4f0e-4c7b-9f0c-a5a5a5000001")
OBJECT_REPLACEMENT = "￼"


def stable_uuid(label: str) -> str:
    """Gleicher Name → gleiche UUID, damit die Datei reproduzierbar bleibt."""
    return str(uuid.uuid5(NAMESPACE, label)).upper()


def output_ref(action_uuid: str, output_name: str, key: str | None = None) -> dict:
    """Verweis auf die Ausgabe einer früheren Aktion, optional auf einen Wörterbuch-Schlüssel."""
    ref = {"OutputName": output_name, "OutputUUID": action_uuid, "Type": "ActionOutput"}
    if key is not None:
        ref["Aggrandizements"] = [{"DictionaryKey": key, "Type": "WFDictionaryValueVariableAggrandizement"}]
    return ref


def attachment(ref: dict) -> dict:
    return {"Value": ref, "WFSerializationType": "WFTextTokenAttachment"}


def token_string(ref: dict) -> dict:
    """Text- oder Zahlenparameter, der nur aus einer Variablen besteht."""
    return {
        "Value": {"attachmentsByRange": {"{0, 1}": ref}, "string": OBJECT_REPLACEMENT},
        "WFSerializationType": "WFTextTokenString",
    }


def action(identifier: str, label: str, **params) -> dict:
    return {
        "WFWorkflowActionIdentifier": identifier,
        "WFWorkflowActionParameters": {"UUID": stable_uuid(label), **params},
    }


def filter_template(prop: str, value: dict, kind: str) -> dict:
    """Eine Filterzeile „<Eigenschaft> ist <Wert>“ (Operator 4 = ist)."""
    return {"Operator": 4, "Property": prop, "Removable": True, "Values": {kind: value}}


def build(shortcut_name: str) -> dict:
    dictionary = stable_uuid("dictionary")
    windows = stable_uuid("find-windows")

    def value(key: str) -> dict:
        return token_string(output_ref(dictionary, "Dictionary", key))

    window = attachment(output_ref(windows, "Windows"))
    actions = [
        # 1. Eingabe als Wörterbuch lesen
        action("is.workflow.actions.detect.dictionary", "dictionary",
               WFInput={"Value": {"Type": "ExtensionInput"}, "WFSerializationType": "WFTextTokenAttachment"}),
        # 2. Das eine Fenster der App an der aktuellen Position finden
        action("is.workflow.actions.filter.windows", "find-windows",
               WFContentItemFilter={
                   "Value": {
                       "WFActionParameterFilterPrefix": 1,
                       "WFActionParameterFilterTemplates": [
                           filter_template("App Name", value("app"), "String"),
                           filter_template("X Position", value("x0"), "Number"),
                           filter_template("Y Position", value("y0"), "Number"),
                       ],
                       "WFContentPredicateBoundedDate": False,
                   },
                   "WFSerializationType": "WFContentPredicateTableTemplate",
               },
               WFContentItemLimitEnabled=True, WFContentItemLimitNumber=1),
        # 3. Größe → Position → Größe, wie in der Accessibility-Variante: Die erste Größe verhindert, dass das
        #    Fenster beim Verschieben auf einen kleineren Bildschirm hängen bleibt, die zweite korrigiert nach.
        action("is.workflow.actions.resizewindow", "resize-1", WFWindow=window, WFConfiguration="Dimensions",
               WFWidth=value("w"), WFHeight=value("h"), WFBringToFront=False),
        action("is.workflow.actions.movewindow", "move", WFWindow=window, WFPosition="Coordinates",
               WFXCoordinate=value("x"), WFYCoordinate=value("y"), WFBringToFront=False),
        action("is.workflow.actions.resizewindow", "resize-2", WFWindow=window, WFConfiguration="Dimensions",
               WFWidth=value("w"), WFHeight=value("h"), WFBringToFront=False),
    ]
    return {
        "WFWorkflowName": shortcut_name,
        "WFWorkflowClientVersion": "2607.0.3",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983, "WFWorkflowIconGlyphNumber": 59511},
        "WFWorkflowTypes": [],
        "WFWorkflowInputContentItemClasses": ["WFStringContentItem", "WFDictionaryContentItem"],
        "WFWorkflowHasShortcutInputVariables": True,
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowImportQuestions": [],
        "WFWorkflowActions": actions,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", default="dist-store", help="Zielverzeichnis (Standard: dist-store)")
    parser.add_argument("--name", default="Raster", help="Name des Kurzbefehls (Standard: Raster)")
    parser.add_argument("--no-sign", action="store_true", help="nur die unsignierte Datei schreiben")
    args = parser.parse_args()

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    unsigned = out / f"{args.name}.unsigned.shortcut"
    signed = out / f"{args.name}.shortcut"
    unsigned.write_bytes(plistlib.dumps(build(args.name), fmt=plistlib.FMT_BINARY))
    print(f"✓ {unsigned}")
    if args.no_sign:
        return 0
    signed.unlink(missing_ok=True)
    result = subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", str(unsigned), "--output", str(signed)],
                            capture_output=True, text=True)
    if result.returncode != 0 or not signed.exists():
        print(f"✗ Signieren fehlgeschlagen: {result.stderr.strip() or result.stdout.strip()}")
        return 1
    print(f"✓ {signed} ({signed.stat().st_size} Bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
