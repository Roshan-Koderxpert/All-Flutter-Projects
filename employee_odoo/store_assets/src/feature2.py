"""Play Store feature graphic (1024x500): brand-first 3D composition — logo + headline on the left,
a floating stack of real-looking app cards and 3D icons on the right. Rendered with headless Chrome."""
import os, subprocess
import icons
HERE = os.path.dirname(os.path.abspath(__file__)); ASSETS = os.path.dirname(HERE)
OUT = f"{HERE}/out"; os.makedirs(OUT, exist_ok=True)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1024, 500

CSS = f"""
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-Bold.ttf');font-weight:700}}
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-SemiBold.ttf');font-weight:600}}
@font-face{{font-family:P;src:url('file://{HERE}/fonts/Poppins-Regular.ttf');font-weight:400}}
*{{box-sizing:border-box}} html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden}}
body{{font-family:P,sans-serif;position:relative;color:#fff;background:linear-gradient(160deg,#2F76B0 0%,#1F5786 48%,#123A5E 100%)}}
.blob{{position:absolute;border-radius:50%}}
.glow{{position:absolute;left:520px;top:-140px;width:760px;height:760px;border-radius:50%;background:radial-gradient(closest-side,rgba(255,255,255,.14),rgba(255,255,255,0))}}
.logo{{position:absolute;left:64px;top:46px;display:flex;align-items:center;filter:drop-shadow(1px 1px 0 #0B2238) drop-shadow(1px 1px 0 #0B2238) drop-shadow(1px 1px 0 #0B2238) drop-shadow(0 14px 12px rgba(0,0,0,.45))}}
.logo img{{display:block}}
.title{{position:absolute;left:64px;top:126px;font-weight:700;font-size:52px;line-height:1.08;letter-spacing:-1.2px;white-space:nowrap;text-shadow:0 8px 24px rgba(0,0,0,.25)}}
.sub{{position:absolute;left:64px;top:258px;width:470px;font-size:20px;line-height:1.45;color:rgba(255,255,255,.86)}}
.feat{{position:absolute;left:64px;top:346px;display:flex;gap:9px}}
.feat span{{display:inline-flex;align-items:center;gap:8px;padding:9px 15px;border-radius:999px;background:rgba(255,255,255,.12);border:1.5px solid rgba(255,255,255,.24);font-weight:600;font-size:15px;box-shadow:0 8px 20px rgba(0,0,0,.18)}}
.feat i{{width:9px;height:9px;border-radius:50%;background:#F06022;display:inline-block;box-shadow:0 0 0 3px rgba(240,96,34,.3)}}
.odoo{{position:absolute;left:64px;top:412px;font-size:14px;color:rgba(255,255,255,.6);letter-spacing:.3px}}
.scene{{position:absolute;inset:0;perspective:1600px;perspective-origin:76% 44%}}
.card{{position:absolute;background:#fff;border-radius:18px;color:#1A1A2E;box-shadow:0 34px 60px -14px rgba(4,16,34,.6),0 6px 14px rgba(4,16,34,.15);transform-style:preserve-3d}}
.card:after{{content:"";position:absolute;inset:0;border-radius:18px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.7)}}
.pill{{position:absolute;display:inline-flex;align-items:center;gap:8px;background:#fff;border-radius:999px;padding:9px 16px;font-weight:600;font-size:15px;color:#1A1A2E;box-shadow:0 18px 34px -8px rgba(4,16,34,.55)}}
.dot{{width:10px;height:10px;border-radius:50%;background:#2EB85C;box-shadow:0 0 0 4px rgba(46,184,92,.22)}}
.ico{{position:absolute}} .ico svg{{display:block;overflow:visible}}
.ground{{position:absolute;border-radius:50%;background:radial-gradient(closest-side,rgba(0,0,0,.5),rgba(0,0,0,0));filter:blur(8px)}}
.tile{{flex:1;background:#F5F8FB;border:1.5px solid #E1E8F0;border-radius:12px;padding:10px 0;text-align:center}}
.tile b{{display:block;font-size:12px;color:#1F5786;font-weight:600}} .tile span{{display:block;font-size:19px;font-weight:700;color:#1F5786;margin-top:2px}}
.btn{{flex:1;border-radius:10px;text-align:center;padding:9px 0;font-weight:600;font-size:13px}}
"""
RY = -16; RX = 8

def card(x, y, w, z, rot, html, pad="14px 16px"):
    return f'<div class="card" style="left:{x}px;top:{y}px;width:{w}px;padding:{pad};transform:rotateY({RY}deg) rotateX({RX}deg) translateZ({z}px) rotate({rot}deg)">{html}</div>'
def pill(x, y, z, rot, html):
    return f'<div class="pill" style="left:{x}px;top:{y}px;transform:rotateY({RY}deg) rotateX({RX}deg) translateZ({z}px) rotate({rot}deg)">{html}</div>'
def ico(x, y, z, rot, svg):
    return f'<div class="ico" style="left:{x}px;top:{y}px;transform:translateZ({z}px) rotate({rot}deg)">{svg}</div>'

attendance = '''<div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:center;gap:9px"><div style="width:30px;height:30px;border-radius:9px;background:#1F5786;color:#fff;display:flex;align-items:center;justify-content:center;font-size:15px">◷</div><b style="font-size:14px;white-space:nowrap">Today's Attendance</b></div><span style="background:#1F5786;color:#fff;font-size:10px;font-weight:600;padding:3px 9px;border-radius:999px;white-space:nowrap">On Duty</span></div>
<div style="display:flex;gap:9px;margin-top:12px"><div class="tile"><b>Check In</b><span>09:32</span></div><div class="tile"><b>Check Out</b><span>--:--</span></div><div class="tile"><b>Hours</b><span>04:12</span></div></div>
<div style="display:flex;align-items:center;gap:7px;margin-top:11px;font-size:12px;color:#2EB85C;font-weight:600"><span class="dot" style="width:8px;height:8px"></span>Route tracking active</div>'''
approval = '''<div style="display:flex;align-items:center;gap:10px"><div style="flex:none;width:36px;height:36px;border-radius:50%;background:#1F5786;color:#fff;font-weight:700;font-size:16px;display:flex;align-items:center;justify-content:center">P</div>
<div style="flex:1"><div style="font-weight:700;font-size:15px;line-height:1.1;white-space:nowrap">Priya Sharma</div><div style="font-weight:600;font-size:12px;color:#1F5786;white-space:nowrap">Paid Time Off · 2 days</div></div><span style="background:#FFF0E8;color:#F06022;font-weight:600;font-size:11px;padding:4px 10px;border-radius:999px;white-space:nowrap">To Approve</span></div>
<div style="display:flex;gap:9px;margin-top:12px"><div class="btn" style="border:2px solid #E5484D;color:#E5484D">✕ Refuse</div><div class="btn" style="background:#2EB85C;color:#fff;box-shadow:0 8px 16px rgba(46,184,92,.4)">✓ Approve</div></div>'''
balance = '''<div style="display:flex;align-items:center;gap:8px"><div style="width:26px;height:26px;border-radius:8px;background:#F06022;color:#fff;display:flex;align-items:center;justify-content:center;font-size:13px">▦</div><b style="font-size:13px">Paid Time Off</b></div>
<div style="font-weight:700;font-size:26px;color:#1F5786;line-height:1;margin-top:9px">17.0 <span style="font-size:12px;font-weight:400;color:#6B7684">days left</span></div>
<div style="height:6px;border-radius:3px;background:#E8EEF5;margin-top:9px;overflow:hidden"><div style="width:15%;height:100%;background:#F06022"></div></div>'''
expense = '''<div style="display:flex;align-items:center;gap:9px"><div style="width:30px;height:30px;border-radius:9px;background:#FFF0E8;font-size:15px;display:flex;align-items:center;justify-content:center">🚕</div>
<div style="flex:1"><div style="font-weight:700;font-size:13px;line-height:1.1">Client visit – Taxi</div><div style="font-size:11px;color:#6B7684">08 Sep · Submitted</div></div><b style="font-size:15px;color:#1F5786">₹1,220</b></div>'''

scene = "".join([
    '<div class="ground" style="left:560px;top:440px;width:520px;height:90px"></div>',
    ico(578, 22, 60, -8, icons.clock(112)),
    card(652, 126, 296, 30, -2, attendance, pad="16px 18px"),
    card(616, 308, 268, 90, -3, approval, pad="14px 16px"),
    card(858, 40, 158, 0, 2, balance, pad="13px 14px"),
    pill(872, 262, 110, -3, '<span class="dot"></span>Approved'),
    icons.maptile(848, 392, 170, ry=-32, rx=58).replace('class="ico"', 'class="ico" data-map="1"', 1),
])

logo = (f'<div class="logo"><img src="file://{OUT}/mk_d.png" style="height:50px"><img src="file://{OUT}/wd_d.png" style="height:17px;margin-left:14px;margin-top:3px"></div>')
html = f'''<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>
<div class="blob" style="left:-220px;top:-280px;width:600px;height:600px;background:rgba(255,255,255,.07)"></div>
<div class="glow"></div>
<div class="blob" style="left:520px;top:330px;width:620px;height:620px;background:rgba(255,255,255,.07)"></div>
<div class="blob" style="left:986px;top:-90px;width:170px;height:170px;background:#F06022;opacity:.95"></div>
{logo}
<div class="title">Your team's workday,<br>in one app.</div>
<div class="sub">Attendance with GPS routes, time off, approvals and expenses — synced with Odoo.</div>
<div class="feat"><span><i></i>Attendance</span><span><i></i>Time Off</span><span><i></i>Approvals</span><span><i></i>Expenses</span></div>
<div class="scene">{scene}</div></body></html>'''
p = f"{OUT}/feature2.html"; open(p, "w").write(html)
out = f"{OUT}/play_feature_graphic_1024x500.png"
subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                "--allow-file-access-from-files", f"--window-size={W},{H}", f"--screenshot={out}", "file://" + p],
               check=True, capture_output=True)
print("ok", out)
