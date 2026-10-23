"""App Store screenshot generator — same design as the Play Store set, iOS device frames.

Targets:
  iphone : 1320 x 2868  (iPhone 6.9")   captures from the iPhone 17 Pro Max simulator (1320x2868)
  ipad   : 2064 x 2752  (iPad 13")      captures from the iPad Pro 13" simulator (2064x2752)

The page is authored in 1080-wide design units and rendered by headless Chrome with a device
scale factor that yields the exact App Store pixel size.
"""
import os, subprocess, sys
import icons
HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BLUE, ORANGE, INK = "#1F5786", "#F06022", "#14213D"

TARGETS = {
    #            final W,H     design H   capture W,H    shots dir
    "iphone": dict(W=1320, H=2868, DH=2347, CW=1320, CH=2868, shots="shots_iphone", out="out_iphone"),
    "ipad":   dict(W=2064, H=2752, DH=1440, CW=2064, CH=2752, shots="shots_ipad",   out="out_ipad"),
}

def css(t):
    return f"""
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-Bold.ttf');font-weight:700}}
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-Regular.ttf');font-weight:400}}
*{{box-sizing:border-box}}
html,body{{margin:0;width:1080px;height:{t['DH']}px;overflow:hidden}}
body{{font-family:P,sans-serif;position:relative;color:#fff}}
.bg{{position:absolute;inset:0;overflow:hidden}} .blob{{position:absolute;border-radius:50%}}
.logo{{position:absolute;left:0;right:0;display:flex;justify-content:center;align-items:center}} .logo img{{display:block}}
.title{{position:absolute;left:60px;right:60px;text-align:center;font-weight:700;line-height:1.08;letter-spacing:-1.5px}}
.sub{{position:absolute;left:90px;right:90px;text-align:center;font-weight:400;line-height:1.35}}
.scene{{position:absolute;inset:0;perspective:2600px;perspective-origin:50% 42%}}
.dev{{position:absolute;transform-style:preserve-3d}}
.dev .lay{{position:absolute;inset:0}}
.dev .body{{position:absolute;inset:0;background:#0B0D10;box-shadow:inset 0 0 0 3px #3B4046,inset 0 0 0 4px #1A1D21,0 70px 120px -20px rgba(0,0,0,.55)}}
.dev .screen{{position:absolute;overflow:hidden;background:#fff}}
.dev .screen img.shot{{position:absolute;left:0;top:0;display:block}}
.island{{position:absolute;left:50%;transform:translateX(-50%);background:#000;border-radius:999px}}
.btn{{position:absolute;background:#2C3035;border-radius:3px}}
.ov{{position:absolute;left:0;top:0;width:{t['CW']}px;transform-origin:0 0;font-family:P;color:#1A1A2E}}
.ground{{position:absolute;border-radius:50%;background:radial-gradient(closest-side,rgba(0,0,0,.45),rgba(0,0,0,0));filter:blur(8px)}}
.card{{position:absolute;background:#fff;border-radius:28px;box-shadow:0 50px 90px -20px rgba(8,20,40,.45),0 10px 24px rgba(8,20,40,.12);color:#1A1A2E;font-family:P}}
.pill{{position:absolute;display:inline-flex;align-items:center;gap:14px;background:#fff;border-radius:999px;padding:18px 34px;font-weight:600;font-size:30px;color:#1A1A2E;box-shadow:0 30px 60px -12px rgba(8,20,40,.4);white-space:nowrap}}
.dot{{width:18px;height:18px;border-radius:50%;background:#2EB85C;box-shadow:0 0 0 8px rgba(46,184,92,.2)}}
.ico{{position:absolute}} .ico svg{{display:block;overflow:visible}}
"""

def blobs(mode, DH):
    """Background gradient + blobs; the two bottom blobs are anchored to the canvas bottom."""
    b = DH - 1920  # extra height vs. the Play Store canvas
    if mode == "light":
        return ("background:linear-gradient(180deg,#FFFFFF 0%,#F1F5FA 100%)",
                f'<div class="blob" style="left:-260px;top:{720+b//2}px;width:620px;height:620px;background:#E3ECF6"></div>'
                f'<div class="blob" style="left:760px;top:-330px;width:640px;height:640px;background:{ORANGE}"></div>'
                f'<div class="blob" style="left:-220px;top:{1520+b}px;width:700px;height:700px;background:{BLUE}"></div>')
    if mode == "blue":
        return ("background:linear-gradient(160deg,#2B6FA6 0%,#1F5786 45%,#143D62 100%)",
                f'<div class="blob" style="left:-240px;top:-200px;width:620px;height:620px;background:rgba(255,255,255,.07)"></div>'
                f'<div class="blob" style="left:680px;top:{1320+b}px;width:760px;height:760px;background:rgba(255,255,255,.08)"></div>'
                f'<div class="blob" style="left:790px;top:120px;width:220px;height:220px;background:{ORANGE};opacity:.95"></div>')
    if mode == "orange":
        return ("background:linear-gradient(160deg,#FF7A3D 0%,#F06022 45%,#D24A14 100%)",
                f'<div class="blob" style="left:-240px;top:-220px;width:640px;height:640px;background:rgba(255,255,255,.09)"></div>'
                f'<div class="blob" style="left:660px;top:{1340+b}px;width:760px;height:760px;background:rgba(255,255,255,.1)"></div>'
                f'<div class="blob" style="left:800px;top:130px;width:200px;height:200px;background:{BLUE}"></div>')
    return ("background:linear-gradient(160deg,#1E4A6B 0%,#14384F 50%,#0C2333 100%)",
            f'<div class="blob" style="left:-240px;top:-200px;width:620px;height:620px;background:rgba(255,255,255,.06)"></div>'
            f'<div class="blob" style="left:700px;top:{1360+b}px;width:720px;height:720px;background:rgba(255,255,255,.06)"></div>'
            f'<div class="blob" style="left:800px;top:120px;width:200px;height:200px;background:{ORANGE}"></div>')

LOGO = {"light": ("mk_l.png", "wd_l.png", "#A9B9CB", "rgba(20,33,61,.32)"),
        "blue": ("mk_d.png", "wd_d.png", "#0B2238", "rgba(0,0,0,.5)"),
        "navy": ("mk_d.png", "wd_d.png", "#0B2238", "rgba(0,0,0,.5)"),
        "orange": ("mk_d.png", "wd_d.png", "#7A2A0A", "rgba(70,22,4,.5)")}
def logo_html(mode, top, mark_h=76, word_h=26, gap=22):
    mk, wd, ex, sh = LOGO[mode]
    ext = " ".join(f"drop-shadow(1px 1px 0 {ex})" for _ in range(5))
    return (f'<div class="logo" style="top:{top}px;filter:{ext} drop-shadow(0 16px 14px {sh})">'
            f'<img src="file://{HERE}/out/{mk}" style="height:{mark_h}px">'
            f'<img src="file://{HERE}/out/{wd}" style="height:{word_h}px;margin-left:{gap}px;margin-top:{mark_h*0.06:.0f}px"></div>')

# ---------- device frames ----------
def iphone(t, shot, left, top, ry, rx=5, rz=0, overlays="", PW=760, B=16, dy=0):
    SW = PW - 2*B; SH = round(SW * t['CH'] / t['CW']); PH = SH + 2*B
    K = SW / t['CW']
    layers = "".join(f'<div class="lay" style="border-radius:74px;transform:translateZ({-2.0*(i+1):.1f}px);background:{"#23272C" if i<14 else "#0B0F13"}"></div>' for i in range(18))
    btns = (f'<div class="btn" style="left:-5px;top:{PH*0.19:.0f}px;width:6px;height:56px"></div>'
            f'<div class="btn" style="left:-5px;top:{PH*0.26:.0f}px;width:6px;height:100px"></div>'
            f'<div class="btn" style="left:-5px;top:{PH*0.34:.0f}px;width:6px;height:100px"></div>'
            f'<div class="btn" style="right:-5px;top:{PH*0.28:.0f}px;width:6px;height:150px"></div>')
    return (f'<div class="dev" style="left:{left}px;top:{top}px;width:{PW}px;height:{PH}px;transform:rotateY({ry}deg) rotateX({rx}deg) rotateZ({rz}deg)">'
            f'{layers}<div class="body" style="border-radius:74px"></div>{btns}'
            f'<div class="screen" style="inset:{B}px;border-radius:58px"><img class="shot" src="file://{HERE}/{t["shots"]}/{shot}" style="width:{SW}px;top:{-dy*K:.0f}px">'
            f'<div style="position:absolute;left:0;top:{-dy*K:.0f}px;width:{t["CW"]}px;transform:scale({K:.5f});transform-origin:0 0">{overlays}</div>'
            f'<div class="island" style="top:{SW*0.0225:.0f}px;width:{SW*0.27:.0f}px;height:{SW*0.075:.0f}px"></div></div></div>'), PH, K

def ipad(t, shot, left, top, ry, rx=5, rz=0, overlays="", PW=940, B=44, dy=0):
    SW = PW - 2*B; SH = round(SW * t['CH'] / t['CW']); PH = SH + 2*B
    K = SW / t['CW']
    layers = "".join(f'<div class="lay" style="border-radius:60px;transform:translateZ({-2.0*(i+1):.1f}px);background:{"#23272C" if i<14 else "#0B0F13"}"></div>' for i in range(18))
    return (f'<div class="dev" style="left:{left}px;top:{top}px;width:{PW}px;height:{PH}px;transform:rotateY({ry}deg) rotateX({rx}deg) rotateZ({rz}deg)">'
            f'{layers}<div class="body" style="border-radius:60px"></div>'
            f'<div style="position:absolute;left:50%;top:{B//2-5}px;width:10px;height:10px;border-radius:50%;background:#1A1D21;transform:translateX(-50%);box-shadow:inset 0 0 0 2px #2C3035"></div>'
            f'<div class="screen" style="inset:{B}px;border-radius:26px"><img class="shot" src="file://{HERE}/{t["shots"]}/{shot}" style="width:{SW}px;top:{-dy*K:.0f}px">'
            f'<div style="position:absolute;left:0;top:{-dy*K:.0f}px;width:{t["CW"]}px;transform:scale({K:.5f});transform-origin:0 0">{overlays}</div></div></div>'), PH, K

def card(left, top, w, html, ry, rot=0, z=170, pad="30px 36px"):
    return f'<div class="card" style="left:{left}px;top:{top}px;width:{w}px;padding:{pad};transform:rotateY({ry}deg) translateZ({z}px) rotate({rot}deg)">{html}</div>'
def pill(left, top, html, ry, rot=0, z=190):
    return f'<div class="pill" style="left:{left}px;top:{top}px;transform:rotateY({ry}deg) translateZ({z}px) rotate({rot}deg)">{html}</div>'
def ico(left, top, svg, rot=0, z=220):
    return f'<div class="ico" style="left:{left}px;top:{top}px;transform:translateZ({z}px) rotate({rot}deg)">{svg}</div>'
def ground(left, top, w, h):
    return f'<div class="ground" style="left:{left}px;top:{top}px;width:{w}px;height:{h}px"></div>'

# ---------- dummy-data fragments (in capture px; scaled into the screen) ----------
def stat_tiles(ci="09:32", co="--:--", hrs="04:12", fs=1.0):
    t = lambda l, v: (f'<div style="flex:1;background:#fff;border:2px solid #E4EAF1;border-radius:{22*fs:.0f}px;padding:{22*fs:.0f}px 0;text-align:center">'
                      f'<div style="font-weight:600;font-size:{30*fs:.0f}px;color:#1F5786">{l}</div><div style="font-weight:700;font-size:{44*fs:.0f}px;color:#1F5786;margin-top:{8*fs:.0f}px">{v}</div></div>')
    return f'<div style="display:flex;gap:{22*fs:.0f}px">{t("Check In",ci)}{t("Check Out",co)}{t("Hours",hrs)}</div>'

def appr_card(initial, name, kind, date, days, badge="To Approve", desc=None, fs=1.0):
    s = lambda v: f"{v*fs:.0f}px"
    d = f'<div style="font-size:{s(32)};color:#4B5563;margin:{s(22)} 0 0 0">{desc}</div>' if desc else ''
    return f'''<div style="background:#fff;border-radius:{s(28)};padding:{s(34)} {s(40)} {s(36)} {s(44)};position:relative;overflow:hidden;box-shadow:0 8px 30px rgba(20,33,61,.06)">
<div style="position:absolute;left:0;top:0;bottom:0;width:{s(10)};background:#F06022"></div>
<div style="display:flex;align-items:center;gap:{s(22)}"><div style="flex:none;width:{s(84)};height:{s(84)};border-radius:50%;background:#1F5786;color:#fff;font-weight:700;font-size:{s(40)};display:flex;align-items:center;justify-content:center">{initial}</div>
<div style="flex:1;min-width:0"><div style="font-weight:700;font-size:{s(40)};line-height:1.1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{name}</div><div style="font-weight:600;font-size:{s(32)};color:#1F5786;margin-top:{s(6)};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{kind}</div></div>
<span style="background:#F06022;color:#fff;font-weight:600;font-size:{s(27)};padding:{s(10)} {s(24)};border-radius:999px;white-space:nowrap">{badge}</span></div>{d}
<div style="display:flex;align-items:center;justify-content:space-between;margin-top:{s(26)};font-size:{s(32)};color:#4B5563"><span>▦&nbsp; {date}</span><span style="background:#E8EEF5;color:#1F5786;font-weight:700;font-size:{s(28)};padding:{s(8)} {s(22)};border-radius:{s(14)}">{days}</span></div>
<div style="display:flex;gap:{s(26)};margin-top:{s(30)}"><div style="flex:1;border:3px solid #E5484D;color:#E5484D;border-radius:{s(18)};text-align:center;padding:{s(22)} 0;font-weight:600;font-size:{s(34)}">✕&nbsp; Refuse</div><div style="flex:1;background:#2EB85C;color:#fff;border-radius:{s(18)};text-align:center;padding:{s(24)} 0;font-weight:600;font-size:{s(34)}">✓&nbsp; Approve</div></div></div>'''

LEAVE_CARDS = [("P","Priya Sharma","Paid Time Off","12 Sep 2026 → 13 Sep 2026","2 days"),
               ("A","Arjun Mehta","Sick Leave","10 Sep 2026","1 day"),
               ("N","Neha Patel","Parental Leave","21 Sep 2026 → 25 Sep 2026","5 days")]
EXP_CARDS = [("P","Priya Sharma","[TRAVEL] Client visit – Taxi","08 Sep 2026","₹ 1,220","Submitted","Airport to client office"),
             ("R","Rahul Verma","[FOOD] Team lunch","07 Sep 2026","₹ 3,450","Submitted","Sprint review lunch"),
             ("N","Neha Patel","[HOTEL] Conference stay","05 Sep 2026","₹ 8,900","Submitted","2 nights, Mumbai")]
def list_overlay(cards, top, left, width, height, fs=1.0, bg="#F3F6FA"):
    return (f'<div style="position:absolute;top:{top}px;left:{left}px;width:{width}px;height:{height}px;background:{bg};'
            f'display:flex;flex-direction:column;gap:{34*fs:.0f}px;padding:0">{"".join(cards)}</div>')

# Per-target layout parameters. Overlay coordinates (capture px) are filled from the captures.
def render(target, only=()):
    t = TARGETS[target]
    from layouts import LAYOUTS  # per-slide compositions live next to this file
    os.makedirs(f"{HERE}/{t['out']}", exist_ok=True)
    for name, spec in LAYOUTS[target].items():
        if only and not any(name.startswith(o) for o in only): continue
        mode = spec["mode"]; bgc, bl = blobs(mode, t["DH"])
        dark = mode == "light"; tc, sc = (INK, "#5B6572") if dark else ("#fff", "rgba(255,255,255,.82)")
        body = spec["body"](t)
        html = (f'<!doctype html><html><head><meta charset="utf-8"><style>{css(t)}</style></head><body>'
                f'<div class="bg" style="{bgc}">{bl}</div>{logo_html(mode, spec["logo_top"])}'
                f'<div class="title" style="top:{spec["title_top"]}px;font-size:{spec["title_fs"]}px;color:{tc}">{spec["title"]}</div>'
                f'<div class="sub" style="top:{spec["sub_top"]}px;font-size:{spec["sub_fs"]}px;color:{sc}">{spec["sub"]}</div>'
                f'<div class="scene">{body}</div></body></html>')
        p = f"{HERE}/{t['out']}/{name}.html"; open(p, "w").write(html)
        png = f"{HERE}/{t['out']}/{name}.png"
        dsf = t["W"] / 1080
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--force-device-scale-factor={dsf:.6f}",
                        "--allow-file-access-from-files", f"--window-size=1080,{t['DH']}", f"--screenshot={png}", "file://" + p],
                       check=True, capture_output=True)
        subprocess.run(["magick", png, "-resize", f"{t['W']}x{t['H']}!", "-crop", f"{t['W']}x{t['H']}+0+0", "+repage", png], check=True)
        print("ok", target, name)

if __name__ == "__main__":
    target = sys.argv[1]; render(target, tuple(sys.argv[2:]))
