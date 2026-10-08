# /// script
# requires-python = ">=3.11"
# dependencies = ["pyjwt", "cryptography", "requests"]
# ///
"""Bereitet Raster in App Store Connect vollständig vor und reicht es ein.

  uv run scripts/asc_submit.py prepare   # Texte, Kategorien, Alter, Preis, Verfügbarkeit, Screenshots, Prüfer-Infos
  uv run scripts/asc_submit.py upload    # Build hochladen (altool auf dem Mac mit Xcode) und auf Verarbeitung warten
  uv run scripts/asc_submit.py attach    # verarbeiteten Build an die Version hängen
  uv run scripts/asc_submit.py video     # dist-store/Raster-review-demo.mp4 als Anhang für App Review hochladen
  uv run scripts/asc_submit.py check     # Vollständigkeit prüfen
  uv run scripts/asc_submit.py submit    # zur Prüfung einreichen
  uv run scripts/asc_submit.py status    # Status abfragen

Braucht ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE (siehe scripts/asc.py), XCODE_HOST und REVIEW_PHONE
(lokal: source ~/.appstore-raster/env.sh) und einen vorhandenen App-Eintrag.
"""
import hashlib, json, os, pathlib, subprocess, sys, time
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from asc import call

ROOT = pathlib.Path(__file__).resolve().parent.parent
META = json.loads((ROOT / "appstore/metadata.json").read_text())
LOCALES = ["en-US", "de-DE"]
PRIMARY = META.get("primary_language", "en-US")
M = META[PRIMARY]
VERSION = (ROOT / "VERSION").read_text().strip()
XCODE_HOST = os.environ.get("XCODE_HOST", "")  # Mac mit Xcode für altool, z. B. user@host (lokal in ~/.appstore-raster/env.sh)
REVIEW_CONTACT = {
    "contactFirstName": "Qendrim", "contactLastName": "Vllasa",
    "contactEmail": META["contact_email"], "contactPhone": os.environ.get("REVIEW_PHONE", ""),  # lokal in ~/.appstore-raster/env.sh
}


def ok(status, data, what):
    if status >= 300:
        raise SystemExit(f"✗ {what}: {status}\n{json.dumps(data, indent=1, ensure_ascii=False)[:3000]}")
    return data


def get(path, what="GET"):
    s, d = call("GET", path)
    return ok(s, d, f"{what} {path}")


def app():
    d = get(f"/v1/apps?filter[bundleId]={META['bundle_id']}")
    if not d["data"]:
        raise SystemExit("✗ Es gibt noch keinen App-Eintrag für com.vllasa.raster in App Store Connect – bitte im Browser anlegen.")
    return d["data"][0]


def mac_version(app_id):
    d = get(f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=MAC_OS&limit=10")
    editable = [v for v in d["data"] if v["attributes"]["appStoreState"] in
                ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")]
    if editable:
        return editable[0]
    if d["data"]:
        return d["data"][0]
    s, d = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
        "attributes": {"platform": "MAC_OS", "versionString": VERSION},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    return ok(s, d, "Version anlegen")["data"]


def editable_app_info(app_id):
    infos = get(f"/v1/apps/{app_id}/appInfos")["data"]
    for i in infos:
        if i["attributes"].get("state", i["attributes"].get("appStoreState")) not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE"):
            return i
    return infos[0]


def prepare():
    a = app(); app_id = a["id"]
    print("▸ App", app_id, a["attributes"]["name"])

    # Inhalte Dritter: keine; Hauptsprache Englisch
    ok(*call("PATCH", f"/v1/apps/{app_id}", {"data": {"type": "apps", "id": app_id, "attributes": {
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT", "primaryLocale": PRIMARY}}}), "Inhaltsrechte/Sprache")

    info = editable_app_info(app_id)
    info_id = info["id"]
    ok(*call("PATCH", f"/v1/appInfos/{info_id}", {"data": {"type": "appInfos", "id": info_id, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": META["primary_category"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": META["secondary_category"]}}}}}), "Kategorien")
    print("✓ Kategorien")

    locs = get(f"/v1/appInfos/{info_id}/appInfoLocalizations")["data"]
    for LOC in LOCALES:
        T = META[LOC]
        attrs = {"name": T["name"], "subtitle": T["subtitle"], "privacyPolicyUrl": META["privacy_url"]}
        loc = next((l for l in locs if l["attributes"]["locale"] == LOC), None)
        if loc:
            ok(*call("PATCH", f"/v1/appInfoLocalizations/{loc['id']}", {"data": {"type": "appInfoLocalizations",
                "id": loc["id"], "attributes": attrs}}), f"App-Info-Texte {LOC}")
        else:
            ok(*call("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations",
                "attributes": {"locale": LOC, **attrs},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}}), f"App-Info-Texte {LOC}")
        print(f"✓ Name, Untertitel, Datenschutz-URL ({LOC})")

    # Altersfreigabe: alles „keine“ → 4+
    s, d = call("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    decl = ok(s, d, "Altersfreigabe lesen")["data"]
    booleans = {"advertising", "ageAssurance", "gambling", "healthOrWellnessTopics", "lootBox", "messagingAndChat",
                "parentalControls", "unrestrictedWebAccess", "userGeneratedContent", "socialMedia", "socialMediaAgeRestricted"}
    skip = {"kidsAgeBand", "ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride",
            "gracRatingClassificationNumber", "developerAgeRatingInfoUrl"}
    new = {k: (False if k in booleans else "NONE") for k in decl["attributes"] if k not in skip}
    for _ in range(len(new) + 1):
        s, d = call("PATCH", f"/v1/ageRatingDeclarations/{decl['id']}", {"data": {"type": "ageRatingDeclarations",
            "id": decl["id"], "attributes": new}})
        if s < 300:
            break
        # Feld mit falschem Typ umdrehen (Boolean <-> „NONE“) bzw. unbekanntes Feld entfernen
        fixed = False
        for err in d.get("errors", []):
            field = err.get("source", {}).get("pointer", "").rsplit("/", 1)[-1]
            if field in new:
                new[field] = "NONE" if isinstance(new[field], bool) else False
                fixed = True
        if not fixed:
            ok(s, d, "Altersfreigabe")
    print("✓ Altersfreigabe (keine Einschränkungen)")

    # Preis: kostenlos
    points = get(f"/v1/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")["data"]
    free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
    s, d = call("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${price1}"}]}}},
        "included": [{"type": "appPrices", "id": "${price1}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    ok(s, d, "Preis")
    print("✓ Preis: kostenlos")

    # Verfügbarkeit: alle Länder
    s, d = call("GET", f"/v1/apps/{app_id}/appAvailabilityV2")
    if s == 404 or not d.get("data"):
        terrs, url = [], "/v1/territories?limit=200"
        while url:
            page = get(url); terrs += [t["id"] for t in page["data"]]; url = page["links"].get("next")
        included = [{"type": "territoryAvailabilities", "id": f"${{t{i}}}", "attributes": {"available": True},
                     "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for i, t in enumerate(terrs)]
        ok(*call("POST", "/v2/appAvailabilities", {"data": {"type": "appAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}},
                              "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": x["id"]} for x in included]}}},
            "included": included}), "Verfügbarkeit")
        print(f"✓ Verfügbarkeit: {len(terrs)} Länder")
    else:
        print("✓ Verfügbarkeit bereits gesetzt")

    # Version
    v = mac_version(app_id); v_id = v["id"]
    ok(*call("PATCH", f"/v1/appStoreVersions/{v_id}", {"data": {"type": "appStoreVersions", "id": v_id, "attributes": {
        "versionString": VERSION, "copyright": META["copyright"], "releaseType": "AFTER_APPROVAL"}}}), "Version")
    print("✓ Version", VERSION)

    vlocs = get(f"/v1/appStoreVersions/{v_id}/appStoreVersionLocalizations")["data"]
    for LOC in LOCALES:
        T = META[LOC]
        vattrs = {"description": T["description"], "keywords": T["keywords"], "promotionalText": T["promotional_text"],
                  "supportUrl": META["support_url"], "marketingUrl": META["marketing_url"]}
        vloc = next((l for l in vlocs if l["attributes"]["locale"] == LOC), None)
        if vloc:
            ok(*call("PATCH", f"/v1/appStoreVersionLocalizations/{vloc['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": vloc["id"], "attributes": vattrs}}), f"Versionstexte {LOC}")
        else:
            vloc = ok(*call("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations",
                "attributes": {"locale": LOC, **vattrs},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": v_id}}}}}), f"Versionstexte {LOC}")["data"]
        print(f"✓ Beschreibung, Suchbegriffe, Werbetext, URLs ({LOC})")
        upload_screenshots(vloc["id"], LOC[:2])

    # Prüfer-Informationen
    review = {**REVIEW_CONTACT, "demoAccountRequired": False, "notes": M["review_notes"]}
    s, d = call("GET", f"/v1/appStoreVersions/{v_id}/appStoreReviewDetail")
    if s == 200 and d.get("data"):
        ok(*call("PATCH", f"/v1/appStoreReviewDetails/{d['data']['id']}", {"data": {"type": "appStoreReviewDetails",
            "id": d["data"]["id"], "attributes": review}}), "Prüfer-Infos")
    else:
        ok(*call("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": review,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": v_id}}}}}), "Prüfer-Infos")
    print("✓ Prüfer-Kontakt und Hinweise")


def upload_screenshots(vloc_id, lang):
    import requests
    files = sorted((ROOT / f"appstore/screenshots/{lang}").glob("*.png"))
    sets = get(f"/v1/appStoreVersionLocalizations/{vloc_id}/appScreenshotSets")["data"]
    desktop = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == "APP_DESKTOP"), None)
    if desktop:
        for shot in get(f"/v1/appScreenshotSets/{desktop['id']}/appScreenshots")["data"]:
            call("DELETE", f"/v1/appScreenshots/{shot['id']}")
    else:
        desktop = ok(*call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": "APP_DESKTOP"},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id}}}}}),
            "Screenshot-Satz")["data"]
    for f in files:
        blob = f.read_bytes()
        shot = ok(*call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": f.name, "fileSize": len(blob)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": desktop["id"]}}}}}),
            f"Screenshot {f.name} reservieren")["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = blob[op["offset"]: op["offset"] + op["length"]]
            r = requests.request(op["method"], op["url"], data=chunk,
                                 headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])}, timeout=120)
            if r.status_code >= 300:
                raise SystemExit(f"✗ Upload {f.name}: {r.status_code} {r.text[:300]}")
        ok(*call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}}), f"Screenshot {f.name}")
        print("  ✓ Screenshot", f.name)
    for _ in range(30):
        states = [s["attributes"]["assetDeliveryState"]["state"]
                  for s in get(f"/v1/appScreenshotSets/{desktop['id']}/appScreenshots")["data"]]
        if all(s == "COMPLETE" for s in states):
            break
        if any(s == "FAILED" for s in states):
            raise SystemExit(f"✗ Screenshot-Verarbeitung fehlgeschlagen: {states}")
        time.sleep(5)
    print(f"✓ {len(files)} Screenshots verarbeitet")


def upload():
    """Lädt das Paket mit altool hoch – lokal, sobald Xcode installiert ist, sonst über den Mac in XCODE_HOST."""
    pkg = ROOT / f"dist-store/Raster-{VERSION}.pkg"
    if not pkg.exists():
        raise SystemExit("✗ Paket fehlt – zuerst scripts/build-appstore.sh")
    local_altool = subprocess.run(["xcrun", "--find", "altool"], capture_output=True, text=True).returncode == 0
    args = ["xcrun", "altool", "--upload-app", "-f", str(pkg), "-t", "macos", "--apiKey", os.environ["ASC_KEY_ID"],
            "--apiIssuer", os.environ["ASC_ISSUER_ID"], "--show-progress"]
    if local_altool:
        out = subprocess.run(args, capture_output=True, text=True)
        out = out.stdout + out.stderr
    else:
        remote = f"/tmp/Raster-{VERSION}.pkg"
        subprocess.run(["scp", "-q", str(pkg), f"{XCODE_HOST}:{remote}"], check=True)
        args[4] = remote
        out = subprocess.run(["ssh", XCODE_HOST, " ".join(args) + " 2>&1 | tail -15"], capture_output=True, text=True).stdout
    print("\n".join(out.strip().splitlines()[-15:]))
    if "UPLOAD SUCCEEDED" not in out and "No errors uploading" not in out:
        raise SystemExit("✗ Upload fehlgeschlagen")
    wait_for_build()


def current_build(app_id):
    plist = ROOT / "dist-store/Raster.app/Contents/Info.plist"
    build = subprocess.run(["plutil", "-extract", "CFBundleVersion", "raw", str(plist)], capture_output=True, text=True).stdout.strip()
    d = get(f"/v1/builds?filter[app]={app_id}&filter[version]={build}&filter[preReleaseVersion.platform]=MAC_OS")
    return build, (d["data"][0] if d["data"] else None)


def wait_for_build():
    app_id = app()["id"]
    for i in range(90):
        build, b = current_build(app_id)
        state = b["attributes"]["processingState"] if b else "noch nicht sichtbar"
        print(f"  Build {build}: {state}")
        if state == "VALID":
            print("✓ Build verarbeitet"); return b
        if state in ("FAILED", "INVALID"):
            raise SystemExit("✗ Build von Apple abgelehnt – siehe E-Mail an den Account-Inhaber")
        time.sleep(60)
    raise SystemExit("✗ Build nach 90 Minuten noch nicht verarbeitet")


def attach():
    app_id = app()["id"]
    v = mac_version(app_id)
    build, b = current_build(app_id)
    if not b or b["attributes"]["processingState"] != "VALID":
        raise SystemExit(f"✗ Build {build} ist noch nicht verarbeitet")
    if b["attributes"].get("usesNonExemptEncryption") is None:
        call("PATCH", f"/v1/builds/{b['id']}", {"data": {"type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}})
    ok(*call("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build", {"data": {"type": "builds", "id": b["id"]}}), "Build anhängen")
    print("✓ Build", build, "an Version", v["attributes"]["versionString"], "angehängt")


def video():
    """Bildschirmvideo als Anhang für App Review hochladen (ersetzt vorhandene Anhänge)."""
    import requests
    path = ROOT / "dist-store/Raster-review-demo.mp4"
    blob = path.read_bytes()
    v = mac_version(app()["id"])
    s, d = call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail")
    detail = ok(s, d, "Prüfer-Infos lesen")["data"]
    for old in get(f"/v1/appStoreReviewDetails/{detail['id']}/appStoreReviewAttachments")["data"]:
        call("DELETE", f"/v1/appStoreReviewAttachments/{old['id']}")
        print("  – alter Anhang entfernt:", old["attributes"].get("fileName"))
    att = ok(*call("POST", "/v1/appStoreReviewAttachments", {"data": {"type": "appStoreReviewAttachments",
        "attributes": {"fileName": path.name, "fileSize": len(blob)},
        "relationships": {"appStoreReviewDetail": {"data": {"type": "appStoreReviewDetails", "id": detail["id"]}}}}}),
        "Anhang reservieren")["data"]
    for op in att["attributes"]["uploadOperations"]:
        chunk = blob[op["offset"]: op["offset"] + op["length"]]
        r = requests.request(op["method"], op["url"], data=chunk,
                             headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])}, timeout=300)
        if r.status_code >= 300:
            raise SystemExit(f"✗ Upload {path.name}: {r.status_code} {r.text[:300]}")
    ok(*call("PATCH", f"/v1/appStoreReviewAttachments/{att['id']}", {"data": {"type": "appStoreReviewAttachments",
        "id": att["id"], "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}}), "Anhang abschließen")
    for _ in range(60):
        state = get(f"/v1/appStoreReviewAttachments/{att['id']}")["data"]["attributes"]["assetDeliveryState"]["state"]
        if state == "COMPLETE":
            break
        if state == "FAILED":
            raise SystemExit("✗ Anhang-Verarbeitung fehlgeschlagen")
        time.sleep(5)
    print(f"✓ Video {path.name} ({len(blob) // 1024 // 1024} MB) als Review-Anhang hochgeladen: {state}")


def check():
    a = app(); v = mac_version(a["id"])
    print("App:", a["attributes"]["name"], "| Version:", v["attributes"]["versionString"], v["attributes"]["appStoreState"])
    s, d = call("GET", f"/v1/appStoreVersions/{v['id']}/build"); print("Build:", (d.get("data") or {}).get("attributes", {}).get("version"))
    vloc = get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]
    for l in vloc:
        sets = get(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")["data"]
        n = sum(len(get(f"/v1/appScreenshotSets/{x['id']}/appScreenshots")["data"]) for x in sets)
        print("Lokalisierung", l["attributes"]["locale"], "| Beschreibung", len(l["attributes"]["description"] or ""), "Zeichen | Screenshots", n)


def submit():
    a = app(); v = mac_version(a["id"])
    s, d = call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "MAC_OS"},
        "relationships": {"app": {"data": {"type": "apps", "id": a["id"]}}}}})
    sub = ok(s, d, "Einreichung anlegen")["data"]
    ok(*call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}}), "Version zur Einreichung")
    ok(*call("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"],
        "attributes": {"submitted": True}}}), "Einreichen")
    print("✓ Eingereicht:", sub["id"])


def status():
    a = app(); v = mac_version(a["id"])
    subs = get(f"/v1/reviewSubmissions?filter[app]={a['id']}&filter[platform]=MAC_OS&limit=5")["data"]
    print(json.dumps({"version": v["attributes"]["versionString"], "state": v["attributes"]["appStoreState"],
                      "submissions": [(s["id"], s["attributes"]["state"]) for s in subs]}, ensure_ascii=False))


if __name__ == "__main__":
    {"prepare": prepare, "upload": upload, "attach": attach, "video": video, "check": check, "submit": submit,
     "status": status, "wait": wait_for_build}[sys.argv[1]]()
