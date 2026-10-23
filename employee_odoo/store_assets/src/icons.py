"""Inline-SVG 3D-style icons shared by the store artwork generators."""
SH = '<filter id="sh" x="-40%" y="-40%" width="180%" height="200%"><feDropShadow dx="0" dy="22" stdDeviation="16" flood-color="#06101c" flood-opacity=".38"/></filter>'

def pin(size=220):
    return f'''<svg width="{size}" height="{size*1.3:.0f}" viewBox="0 0 200 260"><defs>{SH}
<linearGradient id="pg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF9A62"/><stop offset=".55" stop-color="#F06022"/><stop offset="1" stop-color="#C6400F"/></linearGradient>
<radialGradient id="pi" cx=".35" cy=".3" r=".9"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#DDE4EC"/></radialGradient></defs>
<ellipse cx="100" cy="244" rx="44" ry="11" fill="#000" opacity=".28"/>
<path d="M100 6C50 6 12 46 12 96c0 64 88 142 88 142s88-78 88-142C188 46 150 6 100 6z" fill="url(#pg)" filter="url(#sh)"/>
<path d="M52 52c16-22 46-32 74-22" stroke="#fff" stroke-opacity=".55" stroke-width="12" stroke-linecap="round" fill="none"/>
<circle cx="100" cy="96" r="40" fill="url(#pi)"/><circle cx="100" cy="96" r="40" fill="none" stroke="#000" stroke-opacity=".1" stroke-width="6"/>
<circle cx="100" cy="96" r="14" fill="#F06022"/></svg>'''

def clock(size=240):
    ticks = "".join(f'<line x1="120" y1="44" x2="120" y2="{56 if i%3 else 62}" stroke="#1F5786" stroke-width="{6 if i%3==0 else 4}" stroke-linecap="round" transform="rotate({i*30} 120 120)"/>' for i in range(12))
    return f'''<svg width="{size}" height="{size}" viewBox="0 0 240 240"><defs>{SH}
<radialGradient id="rim" cx=".3" cy=".25" r="1"><stop offset="0" stop-color="#4C93D2"/><stop offset=".6" stop-color="#1F5786"/><stop offset="1" stop-color="#0F3352"/></radialGradient>
<radialGradient id="face" cx=".4" cy=".35" r=".9"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#E4EAF1"/></radialGradient></defs>
<ellipse cx="120" cy="232" rx="70" ry="10" fill="#000" opacity=".25"/>
<circle cx="120" cy="120" r="110" fill="url(#rim)" filter="url(#sh)"/>
<circle cx="120" cy="120" r="88" fill="url(#face)"/><circle cx="120" cy="120" r="88" fill="none" stroke="#000" stroke-opacity=".08" stroke-width="10"/>
{ticks}
<line x1="120" y1="120" x2="120" y2="70" stroke="#14213D" stroke-width="11" stroke-linecap="round" transform="rotate(300 120 120)"/>
<line x1="120" y1="120" x2="120" y2="52" stroke="#14213D" stroke-width="8" stroke-linecap="round" transform="rotate(60 120 120)"/>
<line x1="120" y1="126" x2="120" y2="48" stroke="#F06022" stroke-width="4" stroke-linecap="round" transform="rotate(200 120 120)"/>
<circle cx="120" cy="120" r="9" fill="#F06022"/>
<path d="M44 84c14-30 44-52 78-56" stroke="#fff" stroke-opacity=".55" stroke-width="12" stroke-linecap="round" fill="none"/></svg>'''

def calendar(size=240, day="24"):
    return f'''<svg width="{size}" height="{size}" viewBox="0 0 240 240"><defs>{SH}
<linearGradient id="cg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF8F55"/><stop offset="1" stop-color="#D9481A"/></linearGradient>
<linearGradient id="cb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#E9EEF4"/></linearGradient></defs>
<ellipse cx="120" cy="232" rx="80" ry="10" fill="#000" opacity=".25"/>
<rect x="36" y="58" width="192" height="172" rx="26" fill="#B9C6D4"/>
<rect x="24" y="46" width="192" height="172" rx="26" fill="url(#cb)" filter="url(#sh)"/>
<path d="M24 72a26 26 0 0 1 26-26h140a26 26 0 0 1 26 26v34H24z" fill="url(#cg)"/>
<rect x="64" y="24" width="18" height="48" rx="9" fill="#1F5786"/><rect x="158" y="24" width="18" height="48" rx="9" fill="#1F5786"/>
<rect x="68" y="28" width="5" height="30" rx="3" fill="#fff" opacity=".45"/><rect x="162" y="28" width="5" height="30" rx="3" fill="#fff" opacity=".45"/>
<text x="120" y="188" text-anchor="middle" font-family="P" font-weight="700" font-size="74" fill="#1F5786">{day}</text>
<circle cx="196" cy="196" r="30" fill="#2EB85C" stroke="#fff" stroke-width="6"/><path d="M182 196l10 10 20-22" stroke="#fff" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'''

def check(size=200):
    return f'''<svg width="{size}" height="{size}" viewBox="0 0 220 220"><defs>{SH}
<radialGradient id="gr" cx=".32" cy=".28" r="1"><stop offset="0" stop-color="#7BE597"/><stop offset=".55" stop-color="#2EB85C"/><stop offset="1" stop-color="#157A35"/></radialGradient></defs>
<ellipse cx="110" cy="212" rx="64" ry="9" fill="#000" opacity=".25"/>
<circle cx="110" cy="106" r="94" fill="url(#gr)" filter="url(#sh)"/>
<path d="M66 110l30 30 60-66" stroke="#fff" stroke-width="22" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M40 78c12-26 36-44 66-50" stroke="#fff" stroke-opacity=".5" stroke-width="12" stroke-linecap="round" fill="none"/></svg>'''

def coins(size=260):
    c = ""
    for i in range(4):
        cy = 176 - i * 20
        c += f'<path d="M30 {cy}a80 26 0 0 0 160 0v-8a80 26 0 0 1-160 0z" fill="#C97A16"/><ellipse cx="110" cy="{cy-8}" rx="80" ry="26" fill="url(#gold)"/>'
    return f'''<svg width="{size}" height="{size*.85:.0f}" viewBox="0 0 260 220"><defs>{SH}
<linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFD27A"/><stop offset=".5" stop-color="#F5A623"/><stop offset="1" stop-color="#E0851A"/></linearGradient>
<radialGradient id="gold2" cx=".35" cy=".3" r=".9"><stop offset="0" stop-color="#FFE3A3"/><stop offset="1" stop-color="#F5A623"/></radialGradient></defs>
<ellipse cx="120" cy="204" rx="110" ry="12" fill="#000" opacity=".25"/>
<g filter="url(#sh)">{c}
<ellipse cx="110" cy="108" rx="80" ry="26" fill="url(#gold2)"/><ellipse cx="110" cy="108" rx="60" ry="18" fill="none" stroke="#C97A16" stroke-opacity=".5" stroke-width="3"/>
<text x="110" y="118" text-anchor="middle" font-family="P" font-weight="700" font-size="28" fill="#B4620E">₹</text>
<g transform="translate(206 120) rotate(18)"><path d="M-10 -66a28 68 0 0 0 0 132h20a28 68 0 0 0 0-132z" fill="#C97A16"/><ellipse cx="10" cy="0" rx="28" ry="68" fill="url(#gold)"/><text x="10" y="14" text-anchor="middle" font-family="P" font-weight="700" font-size="40" fill="#B4620E">₹</text></g></g></svg>'''

def shield(size=220):
    return f'''<svg width="{size}" height="{size*1.18:.0f}" viewBox="0 0 220 260"><defs>{SH}
<linearGradient id="sg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4C93D2"/><stop offset=".55" stop-color="#1F5786"/><stop offset="1" stop-color="#0F3352"/></linearGradient></defs>
<ellipse cx="110" cy="248" rx="64" ry="10" fill="#000" opacity=".25"/>
<path d="M110 10l84 32v78c0 60-38 96-84 118-46-22-84-58-84-118V42z" fill="url(#sg)" filter="url(#sh)"/>
<path d="M110 34l64 24v62c0 48-30 78-64 96-34-18-64-48-64-96V58z" fill="#fff" fill-opacity=".1"/>
<path d="M52 66c12-16 30-28 52-32" stroke="#fff" stroke-opacity=".5" stroke-width="10" stroke-linecap="round" fill="none"/>
<rect x="74" y="112" width="72" height="58" rx="14" fill="#fff"/><path d="M88 112v-16a22 22 0 0 1 44 0v16" stroke="#fff" stroke-width="12" fill="none" stroke-linecap="round"/>
<circle cx="110" cy="138" r="8" fill="#F06022"/><rect x="106" y="138" width="8" height="16" rx="3" fill="#F06022"/></svg>'''

def maptile(left, top, size=380, ry=-30, rx=58):
    """3D map tile lying flat with a standing pin."""
    return f'''<div class="ico" style="left:{left}px;top:{top}px;width:{size}px;height:{size}px;transform-style:preserve-3d;transform:rotateX({rx}deg) rotateZ({ry}deg)">
<div style="position:absolute;inset:0;border-radius:44px;background:#BFC9D6;transform:translateZ(-26px)"></div>
<div style="position:absolute;inset:0;border-radius:44px;background:#CBD5E0;transform:translateZ(-13px)"></div>
<div style="position:absolute;inset:0;border-radius:44px;overflow:hidden;background:#EEF1F4;box-shadow:0 60px 80px -10px rgba(0,0,0,.5)">
<svg width="{size}" height="{size}" viewBox="0 0 380 380">
<rect x="0" y="230" width="380" height="150" fill="#DDEFD3"/><rect x="220" y="0" width="160" height="150" fill="#E7E2D8"/>
<g stroke="#fff" stroke-width="30" fill="none" stroke-linecap="round"><path d="M-20 120H400"/><path d="M130 -20V400"/><path d="M280 140V400"/><path d="M-20 300H400"/></g>
<g stroke="#C9D1DB" stroke-width="3" fill="none"><path d="M-20 120H400"/><path d="M130 -20V400"/><path d="M280 140V400"/><path d="M-20 300H400"/></g>
<rect x="40" y="40" width="60" height="50" rx="8" fill="#DCE2EA"/><rect x="160" y="160" width="90" height="100" rx="8" fill="#DCE2EA"/><rect x="310" y="180" width="50" height="90" rx="8" fill="#DCE2EA"/><rect x="40" y="330" width="70" height="40" rx="8" fill="#CFE5C4"/>
<path d="M60 340C60 250 130 300 130 230S60 150 130 120 260 120 260 120" stroke="#F06022" stroke-width="12" fill="none" stroke-linecap="round" stroke-dasharray="22 16"/>
<circle cx="60" cy="340" r="18" fill="#2EB85C" stroke="#fff" stroke-width="6"/>
</svg></div>
<div style="position:absolute;left:{size*.68-28:.0f}px;top:{size*.32-24:.0f}px;width:56px;height:26px;border-radius:50%;background:rgba(0,0,0,.35);filter:blur(6px)"></div>
<div style="position:absolute;left:{size*.68-60:.0f}px;top:{size*.32-150:.0f}px;transform:rotateZ({-ry}deg) rotateX({-rx}deg);transform-origin:60px 150px">{pin(120)}</div>
</div>'''

def half(size=220):
    return f'''<svg width="{size}" height="{size}" viewBox="0 0 220 220"><defs>{SH}
<linearGradient id="hb" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4C93D2"/><stop offset="1" stop-color="#1F5786"/></linearGradient>
<linearGradient id="ho" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF9A62"/><stop offset="1" stop-color="#D9481A"/></linearGradient></defs>
<ellipse cx="110" cy="212" rx="70" ry="9" fill="#000" opacity=".25"/>
<g filter="url(#sh)"><path d="M18 110a92 30 0 0 0 184 0v16a92 30 0 0 1-184 0z" fill="#0F3352"/>
<ellipse cx="110" cy="110" rx="92" ry="30" fill="url(#hb)"/><path d="M110 80a92 30 0 0 1 0 60z" fill="url(#ho)"/></g>
<g transform="translate(110 30)"><circle r="46" fill="#fff" filter="url(#sh)"/><text x="0" y="16" text-anchor="middle" font-family="P" font-weight="700" font-size="46" fill="#1F5786">½</text></g>
<line x1="110" y1="76" x2="110" y2="110" stroke="#fff" stroke-width="6" stroke-linecap="round" opacity=".9"/></svg>'''

def bars(size=260):
    def bar(x, h, col, dark):
        y = 200 - h
        return (f'<path d="M{x} {y+18}l24-14v{h}l-24 14z" fill="{dark}"/>'
                f'<rect x="{x-40}" y="{y+18}" width="40" height="{h}" fill="{col}"/>'
                f'<path d="M{x-40} {y+18}l40 0 24-14-40 0z" fill="{col}"/><path d="M{x-40} {y+18}l40 0 24-14-40 0z" fill="#fff" fill-opacity=".45"/>')
    return f'''<svg width="{size}" height="{size*.9:.0f}" viewBox="0 0 260 234"><defs>{SH}</defs>
<ellipse cx="130" cy="224" rx="110" ry="10" fill="#000" opacity=".25"/>
<g filter="url(#sh)">{bar(70,90,'#1F5786','#0F3352')}{bar(140,150,'#F06022','#B33E0E')}{bar(210,120,'#1F5786','#0F3352')}</g>
<path d="M20 78l60-30 70 24 80-60" stroke="#2EB85C" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/><circle cx="230" cy="12" r="10" fill="#2EB85C" stroke="#fff" stroke-width="4"/></svg>'''
