"""Re-render the top band (background + logo + headline + subtitle) of each Play Store slide
with the KoderXpert logo built in natively, then paste it over the existing render.
Rows below the band are untouched; the background CSS is identical, so there is no seam."""
import os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__)); ASSETS = os.path.dirname(HERE)
SHOTS = f"{ASSETS}/play_screenshots"; FEATURE = f"{ASSETS}/play_feature_graphic_1024x500.png"
OUT = f"{HERE}/out"; os.makedirs(OUT, exist_ok=True)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
INK = "#14213D"
def run(a): subprocess.run(["magick"] + a, check=True)
def shot(html, w, h, png):
    p = png.replace(".png", ".html"); open(p, "w").write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--allow-file-access-from-files", f"--window-size={w},{h}", f"--screenshot={png}", "file://" + p],
                   check=True, capture_output=True)

FONTS = f"""@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-Bold.ttf');font-weight:700}}
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-Regular.ttf');font-weight:400}}"""

BG = {
 "light": ("linear-gradient(180deg,#FFFFFF 0%,#F1F5FA 100%)", [(-260,720,620,"#E3ECF6"),(760,-330,640,"#F06022"),(-220,1520,700,"#1F5786")]),
 "blue":  ("linear-gradient(160deg,#2B6FA6 0%,#1F5786 45%,#143D62 100%)", [(-240,-200,620,"rgba(255,255,255,.07)"),(680,1320,760,"rgba(255,255,255,.08)"),(790,120,220,"#F06022")]),
 "orange":("linear-gradient(160deg,#FF7A3D 0%,#F06022 45%,#D24A14 100%)", [(-240,-220,640,"rgba(255,255,255,.09)"),(660,1340,760,"rgba(255,255,255,.1)"),(800,130,200,"#1F5786")]),
 "navy":  ("linear-gradient(160deg,#1E4A6B 0%,#14384F 50%,#0C2333 100%)", [(-240,-200,620,"rgba(255,255,255,.06)"),(700,1360,720,"rgba(255,255,255,.06)"),(800,120,200,"#F06022")]),
 "feature":("linear-gradient(160deg,#2B6FA6 0%,#1F5786 45%,#143D62 100%)", [(-180,-260,520,"rgba(255,255,255,.07)"),(560,300,600,"rgba(255,255,255,.08)"),(990,-80,150,"#F06022")]),
}
def bg_html(mode):
    grad, blobs = BG[mode]
    bl = "".join(f'<div class="blob" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px;background:{c}{";opacity:.95" if mode=="blue" and c=="#F06022" else ""}"></div>' for x,y,s,c in blobs)
    return f'<div class="bg" style="background:{grad}">{bl}</div>'

# logo variants: (mark, word, extrude colour, soft shadow). Colours are the shared brand files:
# white + orange on dark backgrounds, navy (#1D5884) + orange on light ones; the orange slide
# carries the navy version on a white plate so the orange "X" stays visible.
LOGO = {
 "light": ("mk_l.png", "wd_l.png", "#A9B9CB", "rgba(20,33,61,.32)"),
 "blue":  ("mk_d.png", "wd_d.png", "#0B2238", "rgba(0,0,0,.5)"),
 "navy":  ("mk_d.png", "wd_d.png", "#0B2238", "rgba(0,0,0,.5)"),
 "orange":("mk_d.png", "wd_d.png", "#7A2A0A", "rgba(70,22,4,.5)"),
}
def logo_html(mode, mark_h, word_h, gap, style, depth=5):
    mk, wd, ex, sh = LOGO[mode]
    ext = " ".join(f"drop-shadow(1px 1px 0 {ex})" for _ in range(depth))
    inner = (f'<img src="file://{OUT}/{mk}" style="height:{mark_h}px">'
             f'<img src="file://{OUT}/{wd}" style="height:{word_h}px;margin-left:{gap}px;margin-top:{mark_h*0.06:.0f}px">')
    return f'<div class="logo" style="{style};filter:{ext} drop-shadow(0 16px 14px {sh})">{inner}</div>'

SLIDES = {
 "01": ("light", "Clock in.<br>Stay on track.", "Live hours and a GPS route, in one tap."),
 "02": ("blue", "See the journey<br>behind the day.", "Distance, duration and every point, on a map."),
 "03": ("light", "Every hour,<br>accounted for.", "Month by month, matched to your Odoo records."),
 "04": ("orange", "Know your balance<br>before you ask.", "Live balances and a calendar you can act on."),
 "05": ("light", "Half a day.<br>Or just two hours.", "Request exactly the time you need."),
 "06": ("blue", "Approve your team<br>in one tap.", "Time off requests, reviewed on the move."),
 "07": ("light", "Expenses,<br>settled faster.", "Submit, review and approve, no paperwork."),
 "08": ("navy", "Your location,<br>your choice.", "Tracking runs only between check-in and check-out."),
}
BAND = 480
CSS = f"""{FONTS}
*{{box-sizing:border-box}} html,body{{margin:0;width:1080px;height:1920px;overflow:hidden}}
body{{font-family:P,sans-serif;position:relative}}
.bg{{position:absolute;inset:0;overflow:hidden}} .blob{{position:absolute;border-radius:50%}}
.logo{{position:absolute;left:0;right:0;display:flex;justify-content:center;align-items:center}}
.logo img{{display:block}} .plate{{display:flex;align-items:center;background:#fff}}
.title{{position:absolute;top:150px;left:60px;right:60px;text-align:center;font-weight:700;font-size:86px;line-height:1.08;letter-spacing:-1.5px}}
.sub{{position:absolute;top:420px;left:90px;right:90px;text-align:center;font-weight:400;font-size:34px;line-height:1.35}}"""
for f in sorted(os.listdir(SHOTS)):
    if not f.endswith(".png"): continue
    mode, title, sub = SLIDES[f[:2]]
    dark = mode == "light"
    tc, sc = (INK, "#5B6572") if dark else ("#fff", "rgba(255,255,255,.82)")
    html = (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{bg_html(mode)}'
            f'{logo_html(mode, 76, 26, 22, "top:34px")}<div class="title" style="color:{tc}">{title}</div>'
            f'<div class="sub" style="color:{sc}">{sub}</div></body></html>')
    shot(html, 1080, 1920, f"{OUT}/band_{f}")
    run([f"{OUT}/band_{f}", "-crop", f"1080x{BAND}+0+0", "+repage", f"{OUT}/_band.png"])
    run([f"{SHOTS}/{f}", f"{OUT}/_band.png", "-geometry", "+0+0", "-composite", f"{OUT}/{f}"])
    print("ok", f)

# feature graphic: re-render the left column (bg + logo + headline + chips), x 0..584
FCSS = f"""{FONTS}
*{{box-sizing:border-box}} html,body{{margin:0;width:1024px;height:500px;overflow:hidden}}
body{{font-family:P,sans-serif;position:relative;color:#fff}}
.bg{{position:absolute;inset:0;overflow:hidden}} .blob{{position:absolute;border-radius:50%}}
.logo{{position:absolute;display:flex;align-items:center}} .logo img{{display:block}} .plate{{display:flex;align-items:center;background:#fff}}
.title{{position:absolute;left:64px;top:118px;width:600px;font-weight:700;font-size:52px;line-height:1.1;letter-spacing:-1px;white-space:nowrap}}
.sub{{position:absolute;left:64px;top:248px;width:500px;font-size:20px;line-height:1.4;color:rgba(255,255,255,.85)}}
.feat{{position:absolute;left:64px;top:340px;display:flex;gap:9px}}
.feat span{{display:inline-flex;align-items:center;gap:8px;padding:8px 14px;border-radius:999px;background:rgba(255,255,255,.12);border:1.5px solid rgba(255,255,255,.22);font-weight:600;font-size:15px}}
.feat i{{width:9px;height:9px;border-radius:50%;background:#F06022;display:inline-block}}"""
html = (f'<!doctype html><html><head><meta charset="utf-8"><style>{FCSS}</style></head><body>{bg_html("feature")}'
        f'{logo_html("blue", 46, 16, 14, "left:64px;top:40px", depth=3)}'
        f'<div class="title">Your team\'s workday,<br>in one app.</div>'
        f'<div class="sub">Attendance with GPS routes, time off, approvals<br>and expenses — synced with your Odoo.</div>'
        f'<div class="feat"><span><i></i>Attendance</span><span><i></i>Time Off</span><span><i></i>Approvals</span><span><i></i>Expenses</span></div></body></html>')
shot(html, 1024, 500, f"{OUT}/band_feature.png")
run([f"{OUT}/band_feature.png", "-crop", "600x240+0+0", "+repage", f"{OUT}/_bandF.png"])
run([FEATURE, f"{OUT}/_bandF.png", "-geometry", "+0+0", "-composite", f"{OUT}/play_feature_graphic_1024x500.png"])
print("ok feature")
