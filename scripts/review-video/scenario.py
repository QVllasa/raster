"""Drehbuch des App-Review-Videos (siehe appstore/demo-drehbuch.md).

  scenario.py setup <ordner>     Demo-Fenster anlegen, andere Apps ausblenden
  scenario.py explore           AX-Baum von Raster ausgeben (Panel muss offen sein)
  scenario.py record <ordner>    Aufnahme: screencapture + Ablauf + steps.json
  scenario.py restore <ordner>   ausgeblendete Apps wieder einblenden

Store-Version (seit 08.10.2026): statt der Bedienungshilfen-Freigabe zeigt das Video die Automations-
Abfrage für Shortcuts Events und das Hinzufügen des Begleit-Kurzbefehls „Raster“ in der Kurzbefehle-App.
Vor einer Aufnahme ab Erststart: `tccutil reset AppleEvents com.vllasa.raster`, den Kurzbefehl „Raster“
in der Kurzbefehle-App löschen, `defaults delete com.vllasa.raster firstRunDone`.
Build-Nummer für die Einblendung: Umgebungsvariable RASTER_BUILD (sonst Zahl der Commits).
"""
import json, os, signal, subprocess, sys, time
import Quartz
import drive as d

RASTER = "com.vllasa.raster"
BUILD = os.environ.get("RASTER_BUILD") or subprocess.run(["git", "rev-list", "--count", "HEAD"], capture_output=True, text=True).stdout.strip()
DEMO = ""  # Pfad des Demo-Ordners, wird in setup()/record() gesetzt
DEMO_APPS = {"com.apple.finder", "com.apple.TextEdit", RASTER, "com.apple.systempreferences", "com.apple.shortcuts"}


def osa(script):
    return subprocess.run(["osascript", "-e", script], capture_output=True, text=True).stdout.strip()


def main_bounds():
    b = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
    return b.origin.x, b.origin.y, b.size.width, b.size.height


def quit_if_running(name):
    """AppleScript startet eine App, um ihr „quit“ zu schicken – deshalb vorher prüfen."""
    osa(f'if application "{name}" is running then tell application "{name}" to quit')


# --- Ursprungszustand von Dock und Schreibtischsymbolen ---
ORIGINAL = os.path.expanduser("~/.raster-review-video-original.json")
SETTINGS = [("com.apple.dock", "autohide", "Dock"), ("com.apple.finder", "CreateDesktop", "Finder")]


def save_original():
    """Nur beim ersten Mal sichern – solange die Datei existiert, gilt der dort gespeicherte Zustand."""
    if os.path.exists(ORIGINAL):
        return
    state = {}
    for dom, key, _ in SETTINGS:
        r = subprocess.run(["defaults", "read", dom, key], capture_output=True, text=True)
        state[f"{dom}/{key}"] = r.stdout.strip() if r.returncode == 0 else None
    json.dump(state, open(ORIGINAL, "w"))


def restore_original():
    if not os.path.exists(ORIGINAL):
        return
    state = json.load(open(ORIGINAL))
    for dom, key, proc in SETTINGS:
        old = state.get(f"{dom}/{key}")
        if old is None:
            subprocess.run(["defaults", "delete", dom, key], capture_output=True)
        else:
            subprocess.run(["defaults", "write", dom, key, "-bool", "true" if old in ("1", "true") else "false"])
        subprocess.run(["killall", proc])
    os.remove(ORIGINAL)


# --- Vorbereitung ---------------------------------------------------------------------------

def setup(folder):
    os.makedirs(folder, exist_ok=True)
    demo = os.path.join(folder, "Demo Project")
    os.makedirs(demo, exist_ok=True)
    docs = {
        "Meeting Notes.txt": "Meeting Notes\n\n- Review the Q4 roadmap\n- Agree on the release date\n- Collect feedback from the team\n",
        "Ideas.txt": "Ideas\n\n1. Simpler onboarding\n2. Dark mode screenshots\n3. Keyboard shortcut cheat sheet\n",
    }
    for name, text in docs.items():
        open(os.path.join(demo, name), "w").write(text)
    open(os.path.join(demo, "Budget.csv"), "w").write("Item,Amount\nDesign,1200\nDevelopment,4800\n")
    # andere sichtbare Apps merken und ausblenden (nichts wird beendet)
    visible = osa('tell application "System Events" to get bundle identifier of every application process whose visible is true').split(", ")
    hide = [b for b in visible if b and b not in DEMO_APPS]
    if "com.apple.dt.Xcode" not in hide and subprocess.run(["pgrep", "-x", "Xcode"], capture_output=True).returncode == 0:
        hide.append("com.apple.dt.Xcode")
    json.dump(hide, open(os.path.join(folder, "hidden.json"), "w"))
    for b in hide:
        osa(f'tell application "System Events" to set visible of (first application process whose bundle identifier is "{b}") to false')
    quit_if_running("System Settings")
    quit_if_running("Raster")
    # Schreibtischsymbole ausblenden (private Dateinamen), Zustand merken
    save_original()
    subprocess.run(["defaults", "write", "com.apple.finder", "CreateDesktop", "-bool", "false"])
    subprocess.run(["killall", "Finder"])
    # Dock ausblenden (zeigt Badges und Vorschaubilder minimierter Fenster), Zustand merken
    subprocess.run(["defaults", "write", "com.apple.dock", "autohide", "-bool", "true"])
    subprocess.run(["killall", "Dock"])
    time.sleep(2.5)
    # Finder: ein Fenster mit dem Demo-Ordner, ohne Seitenleiste
    osa('tell application "Finder" to close every window')
    osa(f'tell application "Finder" to open POSIX file "{demo}"')
    time.sleep(1)
    osa('tell application "Finder" to set sidebar width of front window to 0')
    for name in docs:
        subprocess.run(["open", "-a", "TextEdit", os.path.join(demo, name)])
    time.sleep(2.5)
    osa('tell application "TextEdit" to close (every window whose name does not end with ".txt") saving no')
    time.sleep(0.5)
    x, y, w, h = main_bounds()
    # unordentlich verteilt, sich teilweise überdeckend
    def te_bounds(name, l, t, r, b):   # über TextEdit selbst, damit es die Fläche neu zeichnet
        osa(f'tell application "TextEdit" to set bounds of window "{name}" to {{{int(l)}, {int(t)}, {int(r)}, {int(b)}}}')
    te_bounds("Meeting Notes.txt", x + w * .06, y + h * .12, x + w * .46, y + h * .58)
    te_bounds("Ideas.txt", x + w * .38, y + h * .26, x + w * .74, y + h * .68)
    osa('tell application "TextEdit" to activate'); time.sleep(0.8)
    # TextEdit zeichnet unter macOS 27 nach Größenänderungen teils schwarze Flächen – anstoßen
    for name in ("Meeting Notes", "Ideas"):
        win = textedit_window(name)
        x0, y0, w0, h0 = d.frame(win)
        d.set_frame(win, x0, y0, w0, h0 - 1); time.sleep(0.15); d.set_frame(win, x0, y0, w0, h0)
    time.sleep(0.5)
    d.set_frame(finder_window(), x + w * .20, y + h * .50, w * .40, h * .36)
    d.move(x + w * .5, y + h * .5, 0.3)
    print("versteckt:", hide)


def restore(folder):
    for b in json.load(open(os.path.join(folder, "hidden.json"))):
        osa(f'tell application "System Events" to set visible of (first application process whose bundle identifier is "{b}") to true')
    restore_original()
    osa('tell application "TextEdit" to close (every window whose name ends with ".txt") saving no')
    osa('tell application "Finder" to close (every window whose name is "Demo Project")')


# --- Raster-Oberfläche finden --------------------------------------------------------------

def raster_app():
    for _ in range(40):
        a = d.app(RASTER)
        if a is not None and status_item(a) is not None:
            return a
        time.sleep(0.25)
    raise SystemExit("Raster läuft nicht")


def status_item(a):
    bar = d.attr(a, "AXExtrasMenuBar")
    kids = d.attr(bar, "AXChildren") if bar is not None else None
    return kids[0] if kids else None


def panel_element(a, role, text, timeout=5):
    end = time.time() + timeout
    while time.time() < end:
        for w in d.attr(a, "AXWindows") or []:
            el = d.find(w, role=role, contains=text)
            if el is not None:
                return el
        time.sleep(0.2)
    return None


def menu_item(a, text, timeout=3):
    end = time.time() + timeout
    while time.time() < end:
        el = d.find(status_item(a), role="AXMenuItem", contains=text)
        if el is not None:
            return el
        time.sleep(0.15)
    return None


def explore():
    a = raster_app()
    print("Statussymbol:", d.frame(status_item(a)))
    for w in d.attr(a, "AXWindows") or []:
        d.dump(w)


def textedit_window(title):
    te = d.app("com.apple.TextEdit")
    for w in d.attr(te, "AXWindows") or []:
        if title in (d.attr(w, "AXTitle") or ""):
            return w
    return None


def finder_item(name):
    f = d.app("com.apple.finder")
    for w in d.attr(f, "AXWindows") or []:
        if d.attr(w, "AXTitle") == "Programme":
            for el, _ in d.walk(w, max_depth=12):
                if d.attr(el, "AXRole") in ("AXImage", "AXTextField", "AXStaticText", "AXGroup") and (d.attr(el, "AXTitle") == name or d.attr(el, "AXValue") == name or d.attr(el, "AXDescription") == name):
                    if d.frame(el):
                        return el
    return None


def finder_window(timeout=8):
    end = time.time() + timeout
    while True:
        f = d.app("com.apple.finder")
        for w in (d.attr(f, "AXWindows") or []) if f is not None else []:
            if "Demo Project" in (d.attr(w, "AXTitle") or ""):
                return w
        if time.time() > end:
            return None
        time.sleep(0.3)


def click_title(win):
    """Fenster nach vorn holen (AX), dann sichtbar in die Titelleiste klicken."""
    d.press_action(win, "AXRaise")
    pid = d.pid_of("com.apple.TextEdit") if "Demo Project" not in (d.attr(win, "AXTitle") or "") else None
    osa('tell application "TextEdit" to activate' if pid else 'tell application "Finder" to activate')
    time.sleep(0.3)
    x, y, w, h = d.frame(win)
    d.click(x + w * 0.5, y + 14)


def allow_automation(timeout=6):
    """Automations-Abfrage „Raster möchte Shortcuts Events steuern“ sichtbar mit „Erlauben“ beantworten.
    Liefert True, wenn der Dialog erschien. Der Dialog gehört dem Prozess UserNotificationCenter."""
    end = time.time() + timeout
    while time.time() < end:
        unc = d.app("com.apple.UserNotificationCenter")
        if unc is not None:
            for el, _ in d.walk(unc, max_depth=8):
                if d.attr(el, "AXRole") == "AXButton" and d.label(el).strip().lower() in ("erlauben", "ok", "allow"):
                    time.sleep(1.2)                       # Dialog kurz stehen lassen, damit man ihn lesen kann
                    d.click(*d.center(el))
                    return True
        time.sleep(0.25)
    return False


def shortcuts_button(text, timeout=10):
    """Knopf im Import-Fenster der Kurzbefehle-App (z. B. „Kurzbefehl hinzufügen“)."""
    end = time.time() + timeout
    while time.time() < end:
        sc = d.app("com.apple.shortcuts")
        for w in (d.attr(sc, "AXWindows") or []) if sc is not None else []:
            el = d.find(w, role="AXButton", contains=text)
            if el is not None and d.frame(el):
                return el
        time.sleep(0.3)
    return None


def setup_card(a, timeout=0.5):
    """Einrichtungskarte der Store-Version im Panel (Knopf „Kurzbefehl hinzufügen“)."""
    return panel_element(a, "AXButton", "Kurzbefehl hinzufügen", timeout=timeout)


def panel_open(a):
    return bool(d.attr(a, "AXWindows"))


def press_icon(a):
    """Maus sichtbar aufs Symbol, auslösen über AX (simulierte Klicks erreicht die Menüleiste unter macOS 27 nicht)."""
    d.move(*d.center(status_item(a)), 0.6)
    time.sleep(0.15)
    d.press(status_item(a))


def open_panel(a):
    if not panel_open(a):
        press_icon(a)
        end = time.time() + 3
        while time.time() < end and not panel_open(a):
            time.sleep(0.1)
    time.sleep(0.8)


def close_panel(a):
    if panel_open(a):
        press_icon(a)
        end = time.time() + 3
        while time.time() < end and panel_open(a):
            time.sleep(0.1)


# --- Aufnahme --------------------------------------------------------------------------------

def record(folder):
    global DEMO
    DEMO = os.path.join(folder, "Demo Project")
    raw = os.path.join(folder, "raw.mov")
    if os.path.exists(raw):
        os.remove(raw)
    rec = subprocess.Popen(["screencapture", "-v", "-C", "-k", "-D1", raw])
    d.start_clock()
    time.sleep(3)
    try:
        run()
    finally:
        time.sleep(2)
        d.LOG.append({"stop": round(time.time() - d.T0, 3)})   # zur Messung der Startverzögerung
        rec.send_signal(signal.SIGINT)
        rec.wait(timeout=30)
        d.save_log(os.path.join(folder, "steps.json"))
        print("Aufnahme:", raw)


def wait(s):
    time.sleep(s)


def run():
    # 1. Start
    d.mark(f"Raster 1.0 (build {BUILD}) on macOS 27: launching the app from the Applications folder", 9)
    fw_ = finder_window()
    d.press_action(fw_, "AXRaise")
    osa('tell application "Finder" to activate'); wait(0.4)
    fx, fy, fwid, fh = d.frame(fw_)
    d.move(fx + fwid * 0.5, fy + fh * 0.6, 0.6); wait(0.8)   # Maus sichtbar zum Finder, kein Klick (Finder ist aktiv)
    d.key("a", d.CMD, d.SHIFT); wait(1.5)            # Gehe zu → Programme (im selben Fenster)
    osa('tell application "Finder"\nactivate\nselect file "Raster.app" of folder "Applications" of startup disk\nend tell')
    wait(1.2)
    icon = finder_item("Raster")
    if icon is not None:
        d.move(*d.center(icon), 0.7); wait(0.3); d.double_click(*d.center(icon))
    else:
        d.key("o", d.CMD)
    wait(2.5)
    a = raster_app()
    osa('tell application "Finder" to set target of (first window whose name is "Programme") to POSIX file "' + DEMO + '"'); wait(0.8)

    # 2. Panel über das Menüleistensymbol
    d.mark("Raster now sits in the menu bar. Clicking its icon opens the panel", 4)
    open_panel(a); wait(1)
    d.mark("The panel shows every layout as a tile, together with its keyboard shortcut", 4)
    wait(3.2)

    # 3. Einrichtung der Store-Version: Automation erlauben, Kurzbefehl hinzufügen (keine Bedienungshilfen)
    if allow_automation(timeout=4):
        d.mark("macOS asks once whether Raster may control Shortcuts Events. The user allows it", 5)
        wait(2.5)
    btn = setup_card(a, timeout=1)
    if btn is not None:
        d.mark("Raster needs its companion shortcut. No Accessibility permission is requested", 5)
        wait(2.5)
        d.move(*d.center(btn), 0.6); wait(0.3); d.click(*d.center(btn)); wait(3.5)
        d.mark("Shortcuts shows the bundled shortcut: Find Windows, Resize Window, Move Window", 6)
        add = shortcuts_button("hinzufügen", timeout=12)
        wait(4)
        if add is None:
            raise SystemExit("Kurzbefehle: Knopf „Kurzbefehl hinzufügen“ nicht gefunden")
        d.mark("Click Add Shortcut", 3)
        d.move(*d.center(add), 0.6); wait(0.3); d.click(*d.center(add)); wait(2.5)
        quit_if_running("Shortcuts"); quit_if_running("Kurzbefehle"); wait(1.5)
        open_panel(a); wait(0.5)
        again = panel_element(a, "AXButton", "Erneut prüfen", timeout=1)
        if again is not None:
            d.click(*d.center(again))
        end = time.time() + 15
        while time.time() < end and setup_card(a, timeout=0.3) is not None:
            time.sleep(0.3)
        if setup_card(a, timeout=0.3) is not None:
            raise SystemExit("Einrichtungskarte verschwindet nicht")
        wait(1)
        d.mark("Shortcut added. Raster is ready, no restart needed", 3)
        wait(2.5)
    else:
        d.mark("The companion shortcut was already added. Raster is ready", 3)
        wait(2.5)

    # 5. Tastenkürzel
    notes, ideas, finder = textedit_window("Meeting Notes"), textedit_window("Ideas"), finder_window()
    click_title(notes); wait(1)
    d.mark("Command + Left Arrow: left half", 3); d.key("left", d.CMD); wait(2.5)
    click_title(finder_window()); wait(1)
    d.mark("Command + Right Arrow: right half", 3); d.key("right", d.CMD); wait(2.5)
    click_title(textedit_window("Ideas")); wait(1)
    d.mark("Command + Up Arrow: maximize", 3); d.key("up", d.CMD); wait(2.5)
    d.mark("Command + Up Arrow again: back to the previous size", 3); d.key("up", d.CMD); wait(2.5)

    # 6. Panel-Kacheln
    d.mark("Or click a layout in the panel: top left quarter", 7)
    open_panel(a); wait(1)
    tile = panel_element(a, "AXButton", "Oben links")
    d.click(*d.center(tile)); wait(2.5)
    close_panel(a); wait(1)

    # 7. Alle Fenster
    d.mark("Control + Option + A: all windows as a grid", 3); d.key("a", d.CTRL, d.OPT); wait(3)
    d.mark("Control + Option + S: side by side", 3); d.key("s", d.CTRL, d.OPT); wait(3)
    d.mark("Control + Option + M: focus + stack", 3); d.key("m", d.CTRL, d.OPT); wait(3)

    # 8. Einstellungen
    d.mark("The gear button in the panel opens the settings", 4)
    open_panel(a)
    gear = panel_element(a, "AXButton", "Einstellungen")
    d.click(*d.center(gear)); wait(2.5)
    d.mark("Settings: every shortcut can be changed, gap between windows, launch at login", 5)
    slider = panel_element(a, "AXSlider", "")
    if slider is not None:
        d.move(*d.center(slider)); wait(1)
        start = float(d.attr(slider, "AXValue") or 0)
        down = start >= 12                       # sichtbar verändern: von groß nach klein oder umgekehrt
        target = 4 if down else 20
        for _ in range(40):
            v = float(d.attr(slider, "AXValue") or 0)
            if (down and v <= target) or (not down and v >= target):
                break
            d.press_action(slider, "AXDecrement" if down else "AXIncrement"); wait(0.2)
        print("Abstand", start, "->", d.attr(slider, "AXValue"))
    wait(2)
    close_panel(a); wait(1)
    d.mark("Control + Option + A again: the grid now uses the new gap", 3); d.key("a", d.CTRL, d.OPT); wait(3)

    # 9. Hinweis auf das Kontextmenü, Ende
    d.mark("Right-clicking the menu bar icon offers Settings, Pause Shortcuts and Quit Raster", 5)
    d.move(*d.center(status_item(a)), 0.8); wait(4.5)


if __name__ == "__main__":
    cmd = sys.argv[1]
    {"setup": lambda: setup(sys.argv[2]), "explore": explore,
     "record": lambda: record(sys.argv[2]), "restore": lambda: restore(sys.argv[2])}[cmd]()
