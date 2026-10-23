"""Per-target slide compositions for gen_ios.py (design units: 1080 wide)."""
import icons
from gen_ios import iphone, ipad, card, pill, ico, ground, stat_tiles, appr_card, list_overlay, LEAVE_CARDS, EXP_CARDS

# Overlay specs in CAPTURE pixels, filled in after the simulator captures are measured.
# Each entry: list of (top, left, width, html_builder(K)) — see helpers below.
OV = {"iphone": {}, "ipad": {}}
def overlays(target, name, fs):
    global CUR_F, CUR_W, CUR_PAD
    CUR_F, CUR_W, CUR_PAD = FACT[target], CAPW[target], PAD[target]
    out = ""
    for top, left, width, build in OV[target].get(name, []):
        out += f'<div style="position:absolute;top:{top}px;left:{left}px;width:{width}px">{build(fs)}</div>'
    return out

R = -14
TITLES = {
 "01_attendance": ("light", "Clock in.<br>Stay on track.", "Live hours and a GPS route, in one tap."),
 "02_route":      ("blue",  "See the journey<br>behind the day.", "Distance, duration and every point, on a map."),
 "03_history":    ("light", "Every hour,<br>accounted for.", "Month by month, matched to your Odoo records."),
 "04_leaves":     ("orange","Know your balance<br>before you ask.", "Live balances and a calendar you can act on."),
 "05_request":    ("light", "Half a day.<br>Or just two hours.", "Request exactly the time you need."),
 "06_approvals":  ("blue",  "Approve your team<br>in one tap.", "Time off requests, reviewed on the move."),
 "07_expenses":   ("light", "Expenses,<br>settled faster.", "Submit, review and approve, no paperwork."),
 "08_privacy":    ("navy",  "Your location,<br>your choice.", "Tracking runs only between check-in and check-out."),
}
SHOT = {"01_attendance": "home.png", "02_route": "route.png", "03_history": "attendance.png", "04_leaves": "leaves.png",
        "05_request": "apply.png", "06_approvals": "approvals.png", "07_expenses": "expenses.png", "08_privacy": "privacy.png"}

# ---- floating elements shared by both targets (positions are per target) ----
def summary_card():
    return '''<div style="font-weight:600;font-size:26px;color:#6B7684">September 2026</div>
<div style="display:flex;gap:40px;margin-top:10px"><div><div style="font-weight:700;font-size:46px;color:#1F5786;line-height:1">168h 20m</div><div style="font-size:24px;color:#6B7684;margin-top:6px">Worked hours</div></div>
<div><div style="font-weight:700;font-size:46px;color:#F06022;line-height:1">+6h 30m</div><div style="font-size:24px;color:#6B7684;margin-top:6px">Overtime</div></div></div>
<div style="height:14px;border-radius:7px;background:#E8EEF5;margin-top:22px;overflow:hidden"><div style="width:86%;height:100%;background:linear-gradient(90deg,#1F5786,#4C93D2)"></div></div>
<div style="font-size:24px;color:#6B7684;margin-top:10px">21 of 22 working days · 1 absent</div>'''
def bal(name, rem, used, tot, col):
    return f'''<div style="display:flex;align-items:center;gap:18px"><div style="width:54px;height:54px;border-radius:14px;background:{col};color:#fff;display:flex;align-items:center;justify-content:center;font-size:28px">▦</div><div style="font-weight:600;font-size:28px">{name}</div></div>
<div style="font-weight:700;font-size:54px;color:{col};line-height:1;margin-top:18px">{rem}</div><div style="font-size:24px;color:#6B7684;margin-top:4px">days remaining</div>
<div style="height:12px;border-radius:6px;background:#E8EEF5;margin-top:16px;overflow:hidden"><div style="width:{used/tot*100:.0f}%;height:100%;background:{col}"></div></div><div style="font-size:22px;color:#6B7684;margin-top:8px">{used} / {tot} used</div>'''
def hours_card():
    return '''<div style="display:flex;align-items:center;justify-content:space-between"><div><div style="font-weight:700;font-size:32px">Custom Hours</div><div style="font-size:24px;color:#6B7684;margin-top:4px">Request specific hours on one day</div></div>
<div style="width:96px;height:54px;border-radius:27px;background:#1F5786;position:relative;flex:none;margin-left:20px"><div style="position:absolute;right:6px;top:6px;width:42px;height:42px;border-radius:50%;background:#fff"></div></div></div>
<div style="display:flex;gap:18px;margin-top:22px"><div style="flex:1;background:#F3F6FA;border-radius:16px;padding:16px 20px"><div style="font-size:22px;color:#6B7684">From</div><div style="font-weight:600;font-size:30px">10:00 AM</div></div><div style="flex:1;background:#F3F6FA;border-radius:16px;padding:16px 20px"><div style="font-size:22px;color:#6B7684">To</div><div style="font-weight:600;font-size:30px">12:00 PM</div></div></div>'''
def approve_card():
    return '''<div style="display:flex;align-items:center;gap:18px"><div style="flex:none;width:68px;height:68px;border-radius:50%;background:#1F5786;color:#fff;font-weight:700;font-size:32px;display:flex;align-items:center;justify-content:center">P</div>
<div style="flex:1;min-width:0"><div style="font-weight:700;font-size:32px;line-height:1.1;white-space:nowrap">Priya Sharma</div><div style="font-weight:600;font-size:25px;color:#1F5786;white-space:nowrap">Paid Time Off · 2 days</div></div><span style="background:#FFF0E8;color:#F06022;font-weight:600;font-size:22px;padding:8px 18px;border-radius:999px;white-space:nowrap">To Approve</span></div>
<div style="display:flex;gap:18px;margin-top:24px"><div style="flex:1;border:3px solid #E5484D;color:#E5484D;border-radius:16px;text-align:center;padding:16px 0;font-weight:600;font-size:27px">✕ Refuse</div><div style="flex:1;background:#2EB85C;color:#fff;border-radius:16px;text-align:center;padding:18px 0;font-weight:600;font-size:27px;box-shadow:0 12px 24px rgba(46,184,92,.4)">✓ Approve</div></div>'''
def expense_card():
    return '''<div style="display:flex;align-items:center;gap:18px"><div style="flex:none;width:68px;height:68px;border-radius:18px;background:#FFF0E8;color:#F06022;font-size:34px;display:flex;align-items:center;justify-content:center">🚕</div>
<div style="flex:1;min-width:0"><div style="font-weight:700;font-size:32px;line-height:1.1;white-space:nowrap">Client visit – Taxi</div><div style="font-size:24px;color:#6B7684;white-space:nowrap">Priya Sharma · 08 Sep 2026</div></div><div style="font-weight:700;font-size:34px;color:#1F5786">₹1,220</div></div>
<div style="display:flex;gap:18px;margin-top:24px"><div style="flex:1;border:3px solid #E5484D;color:#E5484D;border-radius:16px;text-align:center;padding:16px 0;font-weight:600;font-size:27px">✕ Refuse</div><div style="flex:1;background:#2EB85C;color:#fff;border-radius:16px;text-align:center;padding:18px 0;font-weight:600;font-size:27px;box-shadow:0 12px 24px rgba(46,184,92,.4)">✓ Approve</div></div>'''
def privacy_card():
    return '''<div style="display:flex;align-items:center;justify-content:space-between"><div><div style="font-weight:700;font-size:32px">Location tracking</div><div style="font-size:24px;color:#6B7684;margin-top:4px">Only between check-in and check-out</div></div>
<div style="width:96px;height:54px;border-radius:27px;background:#2EB85C;position:relative;flex:none;margin-left:20px"><div style="position:absolute;right:6px;top:6px;width:42px;height:42px;border-radius:50%;background:#fff"></div></div></div>
<div style="display:flex;gap:14px;margin-top:22px;flex-wrap:wrap"><span style="background:#F3F6FA;border-radius:999px;padding:10px 20px;font-size:23px;color:#1F5786;font-weight:600">✓ Stops at check-out</span><span style="background:#F3F6FA;border-radius:999px;padding:10px 20px;font-size:23px;color:#1F5786;font-weight:600">✓ Turn off anytime</span></div>'''
lifted_stats = lambda: stat_tiles(fs=0.86)

def make(target, dev, DEV_TOP, P):
    """Build the LAYOUTS dict for one target. P holds per-slide element positions (design units)."""
    L = {}
    for name, (mode, title, sub) in TITLES.items():
        def body(t, name=name, mode=mode):
            fs = P["ov_fs"]
            ry = R if P[name].get("flip", False) is False else -R
            frame, PH, K = dev(t, SHOT[name], P["dev_left"] + P[name].get("dx", 0), DEV_TOP, ry, rz=P[name].get("rz", 0),
                               overlays=overlays(target, name, fs), dy=P[name].get("dy", 0))
            out = ground(P["dev_left"] + 40, DEV_TOP + PH - 60, P["ground_w"], 140) + frame
            for kind, *a in P[name]["els"]:
                if kind == "card": out += card(a[0], a[1], a[2], a[3](), ry, rot=-3, pad=a[4] if len(a) > 4 else "28px 32px")
                elif kind == "pill": out += pill(a[0], a[1], a[2], ry, rot=-3)
                elif kind == "ico": out += ico(a[0], a[1], a[2], rot=a[3])
                elif kind == "map": out += icons.maptile(a[0], a[1], a[2], ry=a[3])
            return out
        L[name] = dict(mode=mode, title=title, sub=sub, body=body, **P["text"])
    return L

# ---------------- iPhone 6.9" (design canvas 1080 x 2347) ----------------
IP = {
 "text": dict(logo_top=50, title_top=170, title_fs=86, sub_top=440, sub_fs=34),
 "dev_left": 160, "ground_w": 680, "ov_fs": 1.0,
 "01_attendance": dict(els=[("card", 60, 1215, 880, lifted_stats, "22px 26px"), ("pill", 560, 1455, '<span class="dot"></span>Route tracking active'),
                            ("ico", 60, 600, icons.clock(230), -8), ("map", -40, 1930, 400, -30)]),
 "02_route": dict(flip=True, els=[("pill", 40, 1400, '<span class="dot"></span>Live · 42 points captured'), ("map", 600, 1900, 400, 24)]),
 "03_history": dict(rz=-4, els=[("card", 40, 1080, 640, summary_card, "30px 36px"), ("pill", 620, 1450, '<span class="dot"></span>On Duty · 04:12 today'),
                                ("ico", 40, 1990, icons.bars(300) if hasattr(icons, "bars") else icons.calendar(260, "30"), 0), ("ico", 800, 600, icons.clock(200), 8)]),
 "04_leaves": dict(els=[("card", 40, 1040, 420, lambda: bal("Paid Time Off", "17.0", 3, 20, "#1F5786"), "28px 30px"),
                        ("card", 60, 1500, 420, lambda: bal("Sick Leave", "8.5", 1.5, 10, "#F06022"), "28px 30px"),
                        ("pill", 560, 1380, '<span style="width:18px;height:18px;border-radius:50%;background:#2EB85C"></span>Approved · 2 days'),
                        ("ico", 760, 540, icons.calendar(240, "12"), 10)]),
 "05_request": dict(flip=True, els=[("card", 40, 1270, 620, hours_card, "28px 32px"), ("pill", 300, 1880, 'Only <span style="font-weight:700;color:#F06022">&nbsp;2h&nbsp;</span> deducted'),
                                    ("ico", 60, 600, icons.half(230), -6), ("ico", 840, 1560, icons.calendar(220, "16"), 8)]),
 "06_approvals": dict(els=[("card", 40, 1140, 640, approve_card, "28px 30px"), ("pill", 520, 1530, '<span class="dot"></span>Approved · Priya notified'), ("ico", 60, 580, icons.check(210), -8)]),
 "07_expenses": dict(flip=True, rz=3, els=[("card", 40, 1120, 640, expense_card, "28px 30px"), ("pill", 600, 1470, '<span class="dot"></span>Approved · ₹13,570'), ("ico", 40, 1990, icons.coins(300), 0)]),
 "08_privacy": dict(els=[("card", 40, 1620, 640, privacy_card, "28px 32px"), ("ico", 60, 600, icons.shield(220), -8), ("ico", 870, 1080, icons.pin(160), 10)]),
}
# ---------------- iPad 13" (design canvas 1080 x 1440) ----------------
IPAD = {
 "text": dict(logo_top=36, title_top=140, title_fs=76, sub_top=360, sub_fs=30),
 "dev_left": 90, "ground_w": 900, "ov_fs": 1.0,
 "01_attendance": dict(els=[("card", 80, 880, 700, lifted_stats, "20px 24px"), ("pill", 640, 1120, '<span class="dot"></span>Route tracking active'),
                            ("ico", 20, 440, icons.clock(190), -8), ("map", -60, 1150, 330, -30)]),
 "02_route": dict(flip=True, els=[("pill", 20, 1000, '<span class="dot"></span>Live · 42 points captured'), ("map", 760, 1130, 330, 24)]),
 "03_history": dict(rz=-3, els=[("card", 80, 820, 600, summary_card, "26px 32px"), ("pill", 620, 1160, '<span class="dot"></span>On Duty · 04:12 today'), ("ico", 860, 440, icons.clock(170), 8)]),
 "04_leaves": dict(els=[("card", 80, 760, 400, lambda: bal("Paid Time Off", "17.0", 3, 20, "#1F5786"), "26px 28px"),
                        ("card", 680, 1080, 400, lambda: bal("Sick Leave", "8.5", 1.5, 10, "#F06022"), "26px 28px"),
                        ("ico", 820, 430, icons.calendar(200, "12"), 10)]),
 "05_request": dict(flip=True, dy=700, els=[("card", 80, 900, 600, hours_card, "26px 30px"), ("pill", 640, 1230, 'Only <span style="font-weight:700;color:#F06022">&nbsp;2h&nbsp;</span> deducted'),
                                    ("ico", 850, 430, icons.calendar(200, "16"), 8)]),
 "06_approvals": dict(els=[("card", 80, 860, 620, approve_card, "26px 28px"), ("pill", 640, 1200, '<span class="dot"></span>Approved · Priya notified'), ("ico", 30, 430, icons.check(180), -8)]),
 "07_expenses": dict(flip=True, rz=2, els=[("card", 80, 860, 620, expense_card, "26px 28px"), ("pill", 540, 1160, '<span class="dot"></span>Approved · ₹13,570'), ("ico", 900, 1200, icons.coins(240), 0)]),
 "08_privacy": dict(els=[("card", 80, 1040, 480, privacy_card, "26px 30px"), ("ico", 30, 440, icons.shield(180), -8), ("ico", 880, 760, icons.pin(140), 10)]),
}
LAYOUTS = {"iphone": make("iphone", iphone, 610, IP), "ipad": make("ipad", ipad, 500, IPAD)}

# ======================= overlay specs: iPhone 17 Pro Max captures (1320 x 2868) =======================
FACT = {"iphone": 1320 / 1080, "ipad": 0.8}     # capture px per Android-design px (3x vs 2x scale)
CAPW = {"iphone": 1320, "ipad": 2064}
PAD  = {"iphone": 48, "ipad": 128}                # list side margin in capture px
CUR_F, CUR_W, CUR_PAD = FACT["iphone"], 1320, 48
def px(v): return f"{v*CUR_F:.0f}px"

def today_card(fs):
    tile = lambda l, v: (f'<div style="flex:1;background:#fff;border:2px solid #E4EAF1;border-radius:{px(22)};padding:{px(24)} 0;text-align:center">'
                         f'<div style="font-weight:600;font-size:{px(30)};color:#1F5786">{l}</div><div style="font-weight:700;font-size:{px(44)};color:#1F5786;margin-top:{px(8)}">{v}</div></div>')
    return f'''<div style="background:#fff;border-radius:{px(28)};padding:{px(40)} {px(40)} {px(34)};font-family:P;color:#1A1A2E">
<div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:center;gap:{px(24)}"><div style="width:{px(80)};height:{px(80)};border-radius:{px(20)};background:#1F5786;color:#fff;display:flex;align-items:center;justify-content:center;font-size:{px(40)}">◷</div><div style="font-weight:700;font-size:{px(40)}">Today's Attendance</div></div>
<span style="background:#1F5786;color:#fff;font-weight:600;font-size:{px(26)};padding:{px(8)} {px(24)};border-radius:999px">On Duty</span></div>
<div style="display:flex;gap:{px(22)};margin-top:{px(34)}">{tile("Check In","09:32")}{tile("Check Out","--:--")}{tile("Hours","04:12")}</div>
<div style="display:flex;gap:{px(22)};margin-top:{px(32)}"><div style="flex:1;background:#EEF2F6;color:#8A96A3;border-radius:{px(22)};text-align:center;padding:{px(30)} 0;font-weight:600;font-size:{px(34)}">⇥&nbsp; Check In</div><div style="flex:1;background:#E5484D;color:#fff;border-radius:{px(22)};text-align:center;padding:{px(30)} 0;font-weight:600;font-size:{px(34)}">⇤&nbsp; Check Out</div></div>
<div style="text-align:center;margin-top:{px(30)};font-weight:600;font-size:{px(28)};color:#2EB85C">● Route tracking active</div>
<div style="text-align:center;margin-top:{px(18)};font-weight:600;font-size:{px(32)};color:#1F5786">→&nbsp; View attendance history</div></div>'''

def route_stats(fs):
    it = lambda ic, v, l: (f'<div style="display:flex;gap:{px(16)};align-items:flex-start"><div style="width:{px(44)};height:{px(44)};border-radius:{px(12)};background:#FFF0E8;color:#F06022;display:flex;align-items:center;justify-content:center;font-size:{px(26)};font-weight:700">{ic}</div>'
                           f'<div><div style="font-weight:700;font-size:{px(38)};line-height:1">{v}</div><div style="font-size:{px(28)};color:#6B7684;margin-top:{px(6)}">{l}</div></div></div>')
    return f'<div style="display:flex;gap:{px(70)};align-items:center;background:#fff;padding:{px(6)} 0 {px(10)};color:#1A1A2E;font-family:P">{it("⟲","3.6 km","Distance")}{it("◷","01:12","Duration")}{it("◉","42","Points")}</div>'

def route_path(fs):
    return '''<svg width="1320" height="2868" viewBox="0 0 1320 2868" style="display:block">
<path d="M300 2300C330 2150 420 2080 470 1950S560 1700 610 1620 640 1540 660 1507" stroke="#F06022" stroke-width="20" fill="none" stroke-linecap="round" stroke-dasharray="36 26" style="filter:drop-shadow(0 4px 6px rgba(0,0,0,.25))"/>
<circle cx="300" cy="2300" r="130" fill="none" stroke="#2EB85C" stroke-width="5" opacity=".18"/><circle cx="300" cy="2300" r="85" fill="none" stroke="#2EB85C" stroke-width="7" opacity=".35"/>
<circle cx="300" cy="2300" r="36" fill="#2EB85C" stroke="#fff" stroke-width="12"/><path d="M285 2300l10 10 20-22" stroke="#fff" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'''

def today_row(fs):
    return f'''<div style="background:#F3F6FA;border-radius:{px(26)};padding:{px(26)} {px(34)};display:flex;align-items:center;gap:{px(26)};font-family:P;color:#1A1A2E">
<div style="width:{px(92)};height:{px(92)};border-radius:{px(22)};background:#1F5786;color:#fff;display:flex;align-items:center;justify-content:center;font-size:{px(44)}">▦</div>
<div><div style="display:flex;align-items:center;gap:{px(18)}"><span style="font-weight:700;font-size:{px(38)}">Today</span><span style="background:#1F5786;color:#fff;font-weight:600;font-size:{px(24)};padding:{px(6)} {px(20)};border-radius:999px">On Duty</span></div>
<div style="font-size:{px(28)};color:#6B7684;margin-top:{px(6)}">In 10/09/2026 09:32:14 · Out --:-- · <b style="color:#1F5786">04:12</b></div></div></div>'''

def balance_tiles(fs):
    tile = lambda name, rem, used, tot, col: (f'<div style="flex:1;background:#fff;border-radius:{px(26)};padding:{px(30)} {px(30)} {px(28)};box-shadow:0 6px 20px rgba(20,33,61,.06)">'
        f'<div style="display:flex;align-items:center;gap:{px(16)}"><div style="width:{px(54)};height:{px(54)};border-radius:{px(14)};background:{col};color:#fff;display:flex;align-items:center;justify-content:center;font-size:{px(26)}">▦</div><div style="font-weight:600;font-size:{px(30)};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{name}</div></div>'
        f'<div style="font-weight:700;font-size:{px(56)};color:{col};line-height:1;margin-top:{px(26)}">{rem}</div><div style="font-size:{px(26)};color:#6B7684;margin-top:{px(6)}">days remaining</div>'
        f'<div style="height:{px(10)};border-radius:{px(5)};background:#E8EEF5;margin-top:{px(18)};overflow:hidden"><div style="width:{used/tot*100:.0f}%;height:100%;background:{col}"></div></div><div style="font-size:{px(22)};color:#6B7684;margin-top:{px(8)}">{used} / {tot} used</div></div>')
    return f'<div style="display:flex;gap:{px(26)};background:#F3F6FA;padding:0 0 {px(10)};font-family:P;color:#1A1A2E">{tile("Paid Time Off","17.0",3.0,20.0,"#1F5786")}{tile("Sick Leave","8.5",1.5,10.0,"#F06022")}</div>'

def fromto(fs, pad=30):
    fld = lambda v: f'<div style="flex:1;background:#F3F6FA;border-radius:{px(18)};padding:{px(pad)} {px(40)};display:flex;justify-content:space-between;align-items:center;font-size:{px(34)};color:#1A1A2E">{v}<span style="color:#6B7684;font-size:{px(30)}">⌄</span></div>'
    return f'<div style="display:flex;gap:{px(30)};background:#fff;font-family:P">{fld("10:00 AM")}{fld("12:00 PM")}</div>'

def list_ov(cards, height):
    return (f'<div style="width:{CUR_W}px;height:{height}px;background:#F3F6FA;padding:0 {CUR_PAD}px;display:flex;flex-direction:column;gap:{px(34)};font-family:P;color:#1A1A2E">{"".join(cards)}</div>')

OV["iphone"] = {
 "01_attendance": [(923, 50, 1220, today_card)],
 "02_route":      [(0, 0, 1320, route_path), (385, 33, 1000, route_stats)],
 "03_history":    [(403, 50, 1220, today_row)],
 "04_leaves":     [(560, 50, 1043, balance_tiles)],
 "05_request":    [(1917, 60, 1200, fromto)],
 "06_approvals":  [(965, 0, 1320, lambda fs: list_ov([appr_card(*c, fs=CUR_F) for c in LEAVE_CARDS], 1600))],
 "07_expenses":   [(965, 0, 1320, lambda fs: list_ov([appr_card(i, n, k, d, a, badge=b, desc=ds, fs=CUR_F) for i, n, k, d, a, b, ds in EXP_CARDS], 1600))],
}

# ======================= overlay specs: iPad Pro 13" captures (2064 x 2752) =======================
def route_path_ipad(fs):
    return '''<svg width="2064" height="2752" viewBox="0 0 2064 2752" style="display:block">
<path d="M480 2240C520 2080 640 2000 720 1860S900 1640 980 1560 1040 1480 1080 1448" stroke="#F06022" stroke-width="22" fill="none" stroke-linecap="round" stroke-dasharray="40 28" style="filter:drop-shadow(0 4px 6px rgba(0,0,0,.25))"/>
<circle cx="480" cy="2240" r="140" fill="none" stroke="#2EB85C" stroke-width="5" opacity=".18"/><circle cx="480" cy="2240" r="92" fill="none" stroke="#2EB85C" stroke-width="7" opacity=".35"/>
<circle cx="480" cy="2240" r="40" fill="#2EB85C" stroke="#fff" stroke-width="12"/><path d="M463 2240l11 11 22-24" stroke="#fff" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'''
OV["ipad"] = {
 "01_attendance": [(568, 128, 1808, today_card)],
 "02_route":      [(0, 0, 2064, route_path_ipad), (190, 48, 900, route_stats)],
 "03_history":    [(208, 128, 1808, today_row)],
 "04_leaves":     [(312, 128, 696, balance_tiles)],
 "05_request":    [(2144, 432, 1196, lambda fs: fromto(fs, pad=34))],
 "06_approvals":  [(600, 0, 2064, lambda fs: list_ov([appr_card(*c, fs=CUR_F) for c in LEAVE_CARDS], 1960))],
 "07_expenses":   [(600, 0, 2064, lambda fs: list_ov([appr_card(i, n, k, d, a, badge=b, desc=ds, fs=CUR_F) for i, n, k, d, a, b, ds in EXP_CARDS], 1960))],
}
