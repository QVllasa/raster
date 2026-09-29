"""Nachbearbeitung und Prüfung des Review-Videos.

  post.py captions <roh.mov> <steps.json> <fertig.mp4>
      Legt die englischen Einblendungen (aus steps.json) als Bilder unten ins Video
      und kodiert es als H.264-MP4 für App Store Connect.

  post.py frames <video> <ordner>
      Berechnet für jedes Bild eine Prüfsumme (ffmpeg framemd5), fasst pixelgleiche
      Folgebilder zu Gruppen zusammen, zieht von jeder Gruppe ein Bild heraus und legt
      Kontaktbögen (3×2 Bilder) an. Schreibt frames.json mit Bildnummer, Zeit und Gruppe.
"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/SFNS.ttf"


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height,r_frame_rate,nb_frames,duration", "-of", "json", path],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)["streams"][0]


def caption_png(text, width, path):
    scale = width / 1728
    font = ImageFont.truetype(FONT, int(40 * scale))
    pad_x, pad_y = int(28 * scale), int(16 * scale)
    tmp = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    l, t, r, b = tmp.textbbox((0, 0), text, font=font)
    w, h = r - l + 2 * pad_x, b - t + 2 * pad_y
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=int(18 * scale), fill=(20, 20, 24, 225))
    d.text((pad_x - l, pad_y - t), text, font=font, fill=(255, 255, 255, 255))
    img.save(path)
    return w, h


def settings_frames(video, b):
    """Bildnummern (erstes, letztes), in denen das Einstellungsfenster über dem zu verdeckenden Bereich
    liegt: Der Bereich unterscheidet sich dann deutlich vom Bild kurz vor dem Öffnen. Läuft auf dem
    fertigen Video mit fester Bildrate, also bildgenau."""
    x, y, w, h = b["blur"]
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-vf", f"crop={w}:{h}:{x}:{y},scale=28:11,format=gray",
                          "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    size = 28 * 11
    n = len(raw) // size
    fr = lambda i: raw[i * size:(i + 1) * size]
    start = int(b["t"] * 30)
    ref = fr(max(0, start - 30))                     # ca. 1 s vor dem Öffnen
    diff = lambda i: sum(abs(p - q) for p, q in zip(fr(i), ref)) / size
    first = next((i for i in range(max(0, start - 30), min(n, start + 300)) if diff(i) > 25), None)
    if first is None:
        return None
    last = first
    while last + 1 < n and diff(last + 1) > 25:
        last += 1
    return first, last


def captions(src, steps_json, dst):
    info = probe(src)
    W, H = int(info["width"]), int(info["height"])
    TRIM = 1.0   # erste Sekunde: Aufnahme startet, Menüleiste halb eingeblendet
    entries = json.load(open(steps_json))
    # screencapture beginnt verzögert und schreibt die Datei erst am Ende. Startverzögerung =
    # Zeitpunkt des Stoppsignals minus Länge der Aufnahme (je Durchgang gemessen).
    stop = next((e["stop"] for e in entries if "stop" in e), None)
    LAT = max(0.0, stop - float(info["duration"])) if stop else 0.8
    print(f"Startverzögerung der Aufnahme: {LAT:.2f} s")
    steps = [dict(e, t=max(0, e["t"] - TRIM - LAT)) for e in entries if "text" in e]
    blurs = [dict(e, t=e["t"] - TRIM - LAT) for e in entries if "blur" in e]
    workdir = os.path.splitext(dst)[0] + "-captions"
    os.makedirs(workdir, exist_ok=True)
    # Durchgang 1: Einblendungen, feste Bildrate
    tmp = os.path.join(workdir, "pass1.mp4")
    inputs, filters, last = ["-ss", str(TRIM), "-i", src], [], "0:v"
    for i, s in enumerate(steps):
        png = os.path.join(workdir, f"c{i:02d}.png")
        w, h = caption_png(s["text"], W, png)
        inputs += ["-i", png]
        x, y = (W - w) // 2, H - h - int(H * 0.06)
        a, b = s["t"], s["t"] + s["hold"]
        filters.append(f"[{last}][{i + 1}:v]overlay={x}:{y}:enable='between(t,{a},{b})'[v{i}]")
        last = f"v{i}"
    filters.append(f"[{last}]fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2[out]")
    end = max(s["t"] + s["hold"] for s in steps) + 1.0   # Standbild am Ende abschneiden
    subprocess.run(["ffmpeg", "-y", "-v", "error", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]",
                    "-t", f"{end:.2f}", "-c:v", "libx264", "-preset", "fast", "-crf", "10", "-pix_fmt", "yuv420p", tmp], check=True)
    # Durchgang 2: private Daten bildgenau verdecken, Endkodierung
    filters, last = [], "0:v"
    for j, b in enumerate(blurs):
        fr = settings_frames(tmp, b)
        if fr is None:
            continue
        f0, f1 = fr
        print(f"Weichzeichner: Bild {f0}–{f1} ({f0 / 30:.2f}–{f1 / 30:.2f} s)")
        x, y, w, h = b["blur"]
        filters.append(f"[{last}]split[bb{j}][bs{j}];[bs{j}]crop={w}:{h}:{x}:{y},boxblur=24:3[bl{j}];"
                       f"[bb{j}][bl{j}]overlay={x}:{y}:enable='between(n,{f0},{f1})'[b{j}]")
        last = f"b{j}"
    vf = ["-filter_complex", ";".join(filters), "-map", f"[{last}]"] if filters else []
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, *vf, "-c:v", "libx264", "-preset", "slow", "-crf", "20",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", dst], check=True)
    print("fertig:", dst, probe(dst))


def frames(src, outdir):
    os.makedirs(outdir, exist_ok=True)
    md5 = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-map", "0:v:0", "-f", "framemd5", "-"],
                         capture_output=True, text=True, check=True).stdout
    tb = next(l for l in md5.splitlines() if l.startswith("#tb 0:")).split(":")[1].strip()
    tb_num, tb_den = map(int, tb.split("/"))
    rows = [l.split(",") for l in md5.splitlines() if l and not l.startswith("#")]
    times = [int(r[2]) * tb_num / tb_den for r in rows]          # pts – auch bei variabler Bildrate korrekt
    fps = len(rows) / max(times[-1] - times[0], 1e-9) if len(rows) > 1 else 0
    groups, prev = [], None
    for idx, r in enumerate(rows):
        h = r[-1].strip()
        if h != prev:
            groups.append({"first": idx, "last": idx, "hash": h, "t": round(times[idx], 3)})
            prev = h
        else:
            groups[-1]["last"] = idx
    # alle Bilder herausziehen, dann nur das erste jeder Gruppe behalten
    tmp = os.path.join(outdir, "all")
    os.makedirs(tmp, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-fps_mode", "passthrough", "-q:v", "2",
                    os.path.join(tmp, "f%06d.jpg")], check=True)
    for i, g in enumerate(groups):
        g["file"] = f"u{i + 1:05d}.jpg"
        os.replace(os.path.join(tmp, f"f{g['first'] + 1:06d}.jpg"), os.path.join(outdir, g["file"]))
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    # Kontaktbögen 3×2 mit Bildnummer und Zeit
    font = ImageFont.truetype(FONT, 22)
    cols, rows_, per = 3, 2, 6
    for s in range(0, len(groups), per):
        tiles = groups[s:s + per]
        tw, th = 1100, 740
        sheet = Image.new("RGB", (cols * tw, rows_ * th), "white")
        for k, g in enumerate(tiles):
            im = Image.open(os.path.join(outdir, g["file"])).convert("RGB")
            im.thumbnail((tw, th - 28))
            x, y = (k % cols) * tw, (k // cols) * th
            sheet.paste(im, (x, y + 28))
            ImageDraw.Draw(sheet).text((x + 6, y + 2), f"#{g['first']}-{g['last']}  t={g['t']}s", font=font, fill="black")
        sheet.save(os.path.join(outdir, f"sheet{s // per:03d}.jpg"), quality=88)
    json.dump({"fps": fps, "frames": len(rows), "groups": groups}, open(os.path.join(outdir, "frames.json"), "w"), indent=1)
    print(f"{len(rows)} Bilder, {len(groups)} unterschiedliche, {-(-len(groups) // per)} Kontaktbögen, {fps:.2f} fps")


if __name__ == "__main__":
    {"captions": lambda: captions(*sys.argv[2:5]), "frames": lambda: frames(*sys.argv[2:4])}[sys.argv[1]]()
