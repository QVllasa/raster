"""Steuert den Mac für das App-Review-Video: Tastenkürzel, Mausbewegungen, Klicks und
Accessibility-Abfragen. Jeder Schritt wird mit Zeitstempel protokolliert, daraus entstehen
später die englischen Einblendungen im Video.

Nur benutzen, wenn niemand sonst gerade am Mac arbeitet – alle Eingaben sind global.
"""
import json, math, re, subprocess, time
import Quartz
from ApplicationServices import (AXUIElementCreateApplication, AXUIElementCopyAttributeValue,
                                 AXUIElementPerformAction, AXValueGetValue, kAXValueCGPointType,
                                 kAXValueCGSizeType)

CMD, SHIFT, OPT, CTRL = 1 << 20, 1 << 17, 1 << 19, 1 << 18
FN, NUMPAD = 1 << 23, 1 << 21
KEYS = {"left": 123, "right": 124, "down": 125, "up": 126, "space": 49, "return": 36, "esc": 53,
        "a": 0, "s": 1, "d": 2, "f": 3, "m": 46, "u": 32, "i": 34, "j": 38, "k": 40, "c": 8,
        "e": 14, "t": 17, "r": 15, "comma": 43, "delete": 51, "n": 45, "o": 31, "w": 13}
ARROWS = {"left", "right", "down", "up"}

LOG = []
T0 = None


def start_clock():
    global T0
    T0 = time.time()


def mark(caption, hold=3.0):
    """Einblendung ab jetzt für `hold` Sekunden (Zeit relativ zum Aufnahmestart). Danach kurz warten,
    damit die Einblendung sicher vor der zugehörigen Aktion im Bild steht."""
    LOG.append({"t": round(time.time() - T0, 2), "hold": hold, "text": caption})
    time.sleep(0.9)


def save_log(path):
    with open(path, "w") as f:
        json.dump(LOG, f, indent=1, ensure_ascii=False)


def key(name, *mods):
    flags = 0
    for m in mods:
        flags |= m
    if name in ARROWS:
        flags |= FN | NUMPAD
    code = KEYS[name]
    for down in (True, False):
        ev = Quartz.CGEventCreateKeyboardEvent(None, code, down)
        Quartz.CGEventSetFlags(ev, flags)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(0.05)


def type_text(text):
    for ch in text:
        ev = Quartz.CGEventCreateKeyboardEvent(None, 0, True)
        Quartz.CGEventKeyboardSetUnicodeString(ev, 1, ch)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        ev = Quartz.CGEventCreateKeyboardEvent(None, 0, False)
        Quartz.CGEventKeyboardSetUnicodeString(ev, 1, ch)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(0.09)


def double_click(x, y):
    for n in (1, 2):
        for t in (Quartz.kCGEventLeftMouseDown, Quartz.kCGEventLeftMouseUp):
            ev = Quartz.CGEventCreateMouseEvent(None, t, (x, y), Quartz.kCGMouseButtonLeft)
            Quartz.CGEventSetIntegerValueField(ev, Quartz.kCGMouseEventClickState, n)
            Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
            time.sleep(0.05)


def mouse_pos():
    p = Quartz.CGEventGetLocation(Quartz.CGEventCreate(None))
    return p.x, p.y


def move(x, y, duration=0.6):
    """Weiche Mausbewegung, damit man ihr im Video folgen kann."""
    x0, y0 = mouse_pos()
    steps = max(2, int(duration * 60))
    for i in range(1, steps + 1):
        s = i / steps
        s = 0.5 - 0.5 * math.cos(math.pi * s)
        ev = Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventMouseMoved, (x0 + (x - x0) * s, y0 + (y - y0) * s), 0)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(duration / steps)


def click(x, y, right=False, move_first=True):
    if move_first:
        move(x, y)
    down, up, btn = ((Quartz.kCGEventRightMouseDown, Quartz.kCGEventRightMouseUp, Quartz.kCGMouseButtonRight) if right
                     else (Quartz.kCGEventLeftMouseDown, Quartz.kCGEventLeftMouseUp, Quartz.kCGMouseButtonLeft))
    for t in (down, up):
        ev = Quartz.CGEventCreateMouseEvent(None, t, (x, y), btn)
        Quartz.CGEventSetIntegerValueField(ev, Quartz.kCGMouseEventClickState, 1)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
        time.sleep(0.08)


# --- Accessibility-Hilfen -------------------------------------------------------------------

def pid_of(bundle_id):
    out = subprocess.run(["lsappinfo", "info", "-only", "pid", "-app", bundle_id], capture_output=True, text=True).stdout
    m = re.search(r"pid\s*=\s*(\d+)", out)
    return int(m.group(1)) if m else None


def attr(el, name):
    err, val = AXUIElementCopyAttributeValue(el, name, None)
    return val if err == 0 else None


def frame(el):
    p, s = attr(el, "AXPosition"), attr(el, "AXSize")
    if p is None or s is None:
        return None
    _, pt = AXValueGetValue(p, kAXValueCGPointType, None)
    _, sz = AXValueGetValue(s, kAXValueCGSizeType, None)
    return pt.x, pt.y, sz.width, sz.height


def center(el):
    x, y, w, h = frame(el)
    return x + w / 2, y + h / 2


def walk(el, depth=0, max_depth=25):
    yield el, depth
    if depth >= max_depth:
        return
    for child in attr(el, "AXChildren") or []:
        yield from walk(child, depth + 1, max_depth)


def label(el):
    parts = [attr(el, a) for a in ("AXTitle", "AXDescription", "AXValue", "AXHelp", "AXIdentifier")]
    return " | ".join(str(p) for p in parts if p not in (None, ""))


def find(app_el, role=None, contains=None):
    for el, _ in walk(app_el):
        if role and attr(el, "AXRole") != role:
            continue
        if contains and contains.lower() not in label(el).lower():
            continue
        return el
    return None


def dump(app_el, max_depth=25):
    for el, d in walk(app_el, max_depth=max_depth):
        f = frame(el)
        print("  " * d + f"{attr(el, 'AXRole')} [{label(el)}] {tuple(round(v) for v in f) if f else ''}")


def app(bundle_id):
    pid = pid_of(bundle_id)
    return AXUIElementCreateApplication(pid) if pid else None


def press(el):
    return AXUIElementPerformAction(el, "AXPress")


def set_frame(el, x, y, w, h):
    from ApplicationServices import AXUIElementSetAttributeValue, AXValueCreate, kAXValueCGPointType as P, kAXValueCGSizeType as S
    AXUIElementSetAttributeValue(el, "AXSize", AXValueCreate(S, Quartz.CGSize(w, h)))
    AXUIElementSetAttributeValue(el, "AXPosition", AXValueCreate(P, Quartz.CGPoint(x, y)))
    AXUIElementSetAttributeValue(el, "AXSize", AXValueCreate(S, Quartz.CGSize(w, h)))


def press_action(el, action):
    return AXUIElementPerformAction(el, action)
