import os, json, math, textwrap, zipfile
from pathlib import Path

base = Path(__file__).resolve().parents[1] / "Art" / "CoreV0"
for sub in ["skeletons","leaves","flowers","inflorescences"]:
    (base/sub).mkdir(parents=True, exist_ok=True)

# Shared SVG helpers
def svg_wrap(body, w=256, h=256, viewbox=None):
    vb = viewbox or f"0 0 {w} {h}"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{vb}">
<g stroke-linecap="round" stroke-linejoin="round">
{body}
</g>
</svg>'''

def save_svg(path, body, w=256, h=256, viewbox=None):
    Path(path).write_text(svg_wrap(body,w,h,viewbox), encoding="utf-8")

GREEN="#5f8f63"; GREEN2="#7daa71"; DARK="#31543b"; STEM="#5a7d4d"
FLOWER="#d98fa6"; FLOWER2="#f2c4d2"; GOLD="#d7b45a"; BLUE="#86a7cf"; PURPLE="#a58ac7"
BROWN="#775b43"; WHITE="#f5f2eb"

# ---------- leaves ----------
leaf_defs = {
"L01_fern_frond": f'''
<path d="M128 235 C125 180 129 95 133 25" fill="none" stroke="{STEM}" stroke-width="7"/>
''' + "\n".join(
    f'<path d="M130 {y} C{80-(i%2)*4} {y-18} {64-(i%2)*3} {y-30} 128 {y-6} C{176+(i%2)*4} {y-18} {192+(i%2)*3} {y-30} 132 {y-6}" fill="{GREEN2}" stroke="{DARK}" stroke-width="2"/>'
    for i,y in enumerate(range(55,220,23))
),
"L02_needle": f'''
<path d="M128 235 C128 170 128 95 128 25" fill="none" stroke="{STEM}" stroke-width="8"/>
''' + "\n".join(
    f'<path d="M128 {y} L{55+(i%3)*10} {y-28} M128 {y+4} L{198-(i%3)*10} {y-26}" stroke="{GREEN}" stroke-width="5"/>'
    for i,y in enumerate(range(55,215,20))
),
"L03_scale": f'''
<path d="M128 235 C126 180 128 90 128 25" fill="none" stroke="{DARK}" stroke-width="8"/>
''' + "\n".join(
    f'<ellipse cx="{105 if i%2==0 else 151}" cy="{y}" rx="28" ry="10" transform="rotate({-35 if i%2==0 else 35} {105 if i%2==0 else 151} {y})" fill="{GREEN}" stroke="{DARK}" stroke-width="2"/>'
    for i,y in enumerate(range(45,220,18))
),
"L04_grass": "\n".join(
    f'<path d="M128 238 Q{70+i*15} {150-i*8} {55+i*22} 35" fill="none" stroke="{GREEN}" stroke-width="8"/>'
    for i in range(7)
),
"L05_strap": f'''
<path d="M128 238 C105 175 100 95 116 22 C129 92 132 165 128 238Z" fill="{GREEN2}" stroke="{DARK}" stroke-width="3"/>
<path d="M128 238 C155 175 162 96 148 28 C134 95 129 170 128 238Z" fill="{GREEN}" stroke="{DARK}" stroke-width="3"/>
''',
"L06_palmate_compound": f'''
<path d="M128 235 L128 150" stroke="{STEM}" stroke-width="8"/>
''' + "\n".join(
    f'<ellipse cx="{128+math.cos(math.radians(a))*60:.1f}" cy="{150+math.sin(math.radians(a))*55:.1f}" rx="20" ry="55" transform="rotate({a+90} {128+math.cos(math.radians(a))*60:.1f} {150+math.sin(math.radians(a))*55:.1f})" fill="{GREEN2}" stroke="{DARK}" stroke-width="3"/>'
    for a in [210,245,280,315,350]
),
"L07_pinnate": f'''
<path d="M128 235 L128 35" stroke="{STEM}" stroke-width="7"/>
''' + "\n".join(
    f'<ellipse cx="{92}" cy="{y}" rx="18" ry="42" transform="rotate(-58 92 {y})" fill="{GREEN2}" stroke="{DARK}" stroke-width="2"/><ellipse cx="{164}" cy="{y}" rx="18" ry="42" transform="rotate(58 164 {y})" fill="{GREEN}" stroke="{DARK}" stroke-width="2"/>'
    for y in [70,110,150,190]
),
"L08_trifoliate": f'''
<path d="M128 235 L128 150" stroke="{STEM}" stroke-width="8"/>
<ellipse cx="128" cy="100" rx="31" ry="52" fill="{GREEN2}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="88" cy="132" rx="31" ry="50" transform="rotate(-45 88 132)" fill="{GREEN}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="168" cy="132" rx="31" ry="50" transform="rotate(45 168 132)" fill="{GREEN}" stroke="{DARK}" stroke-width="3"/>
''',
"L09_palmate_lobed": f'''
<path d="M128 235 L128 170" stroke="{STEM}" stroke-width="8"/>
<path d="M128 165 L97 112 L112 118 L92 72 L122 95 L128 37 L138 96 L169 71 L151 119 L168 113 L128 165Z" fill="{GREEN}" stroke="{DARK}" stroke-width="4"/>
''',
"L10_heart_round": f'''
<path d="M128 235 L128 158" stroke="{STEM}" stroke-width="8"/>
<path d="M128 165 C78 125 50 70 88 50 C111 38 128 61 128 80 C128 61 146 38 169 50 C207 70 178 126 128 165Z" fill="{GREEN2}" stroke="{DARK}" stroke-width="4"/>
''',
"L11_standard_broad": f'''
<path d="M128 235 L128 170" stroke="{STEM}" stroke-width="8"/>
<path d="M128 170 C82 145 65 86 128 38 C191 86 174 145 128 170Z" fill="{GREEN}" stroke="{DARK}" stroke-width="4"/>
<path d="M128 163 L128 57" stroke="{DARK}" stroke-width="3"/>
''',
"L12_succulent": f'''
<g transform="translate(128 150)">
''' + "\n".join(
    f'<ellipse cx="0" cy="-44" rx="22" ry="75" transform="rotate({a})" fill="{GREEN2 if i%2==0 else GREEN}" stroke="{DARK}" stroke-width="3"/>'
    for i,a in enumerate(range(0,360,45))
) + "</g>",
"L13_large_broad": f'''
<path d="M128 235 L128 175" stroke="{STEM}" stroke-width="10"/>
<path d="M128 180 C50 155 35 75 128 22 C221 75 206 155 128 180Z" fill="{GREEN2}" stroke="{DARK}" stroke-width="4"/>
<path d="M128 170 L128 45" stroke="{DARK}" stroke-width="3"/>
''',
"L14_ericoid": f'''
<path d="M128 235 C125 180 128 90 128 28" stroke="{STEM}" stroke-width="7" fill="none"/>
''' + "\n".join(
    f'<path d="M128 {y} l{-35 if i%2==0 else 35} -14" stroke="{GREEN}" stroke-width="6"/>'
    for i,y in enumerate(range(55,220,16))
),
}
for name, body in leaf_defs.items():
    save_svg(base/"leaves"/f"{name}.svg", body)

# ---------- flower heads ----------
flower_defs = {}
flower_defs["F01_cone"] = f'''<ellipse cx="128" cy="135" rx="45" ry="65" fill="{BROWN}" stroke="{DARK}" stroke-width="4"/>
<path d="M100 95 l56 75 M93 125 l65 44 M98 160 l52 32" stroke="{GOLD}" stroke-width="4" opacity=".65"/>'''
flower_defs["F02_daisy"] = f'''<g transform="translate(128 128)">''' + "".join(
    f'<ellipse cx="0" cy="-57" rx="18" ry="48" transform="rotate({a})" fill="{WHITE}" stroke="{DARK}" stroke-width="2"/>'
    for a in range(0,360,30)
) + f'''<circle cx="0" cy="0" r="34" fill="{GOLD}" stroke="{DARK}" stroke-width="3"/></g>'''
flower_defs["F03_globe"] = f'''<circle cx="128" cy="128" r="72" fill="{PURPLE}" stroke="{DARK}" stroke-width="4"/>''' + "".join(
    f'<circle cx="{128+math.cos(a)*45:.1f}" cy="{128+math.sin(a)*45:.1f}" r="9" fill="{FLOWER2}" opacity=".8"/>'
    for a in [i*math.pi/6 for i in range(12)]
)
flower_defs["F04_bilabiate"] = f'''<path d="M70 115 C88 72 168 72 186 115 C168 116 150 122 139 141 C128 160 95 160 79 140 C71 130 69 122 70 115Z" fill="{PURPLE}" stroke="{DARK}" stroke-width="4"/>
<path d="M95 138 C105 166 151 166 163 138" fill="none" stroke="{FLOWER2}" stroke-width="8"/>'''
flower_defs["F05_pea"] = f'''<ellipse cx="128" cy="88" rx="54" ry="42" fill="{FLOWER}" stroke="{DARK}" stroke-width="4"/>
<ellipse cx="88" cy="130" rx="34" ry="47" transform="rotate(-35 88 130)" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="168" cy="130" rx="34" ry="47" transform="rotate(35 168 130)" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>
<path d="M110 128 Q128 176 146 128 Q128 145 110 128Z" fill="{PURPLE}" stroke="{DARK}" stroke-width="3"/>'''
flower_defs["F06_orchid"] = f'''<ellipse cx="86" cy="100" rx="34" ry="55" transform="rotate(-45 86 100)" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="170" cy="100" rx="34" ry="55" transform="rotate(45 170 100)" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="128" cy="78" rx="32" ry="55" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>
<path d="M95 135 Q128 105 161 135 Q150 190 128 190 Q106 190 95 135Z" fill="{PURPLE}" stroke="{DARK}" stroke-width="4"/>'''
flower_defs["F07_spadix_spathe"] = f'''<path d="M80 190 C52 135 72 72 133 45 C154 93 143 155 80 190Z" fill="{WHITE}" stroke="{DARK}" stroke-width="4"/>
<path d="M125 180 Q130 115 135 65" stroke="{GOLD}" stroke-width="18" fill="none"/>'''
flower_defs["F08_lily"] = f'''<g transform="translate(128 128)">''' + "".join(
    f'<ellipse cx="0" cy="-52" rx="25" ry="65" transform="rotate({a})" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>'
    for a in range(0,360,60)
) + f'''<circle cx="0" cy="0" r="12" fill="{GOLD}"/></g>'''
flower_defs["F09_iris"] = f'''<path d="M128 125 C85 40 63 76 75 118 C82 144 105 145 128 125Z" fill="{PURPLE}" stroke="{DARK}" stroke-width="3"/>
<path d="M128 125 C171 40 193 76 181 118 C174 144 151 145 128 125Z" fill="{PURPLE}" stroke="{DARK}" stroke-width="3"/>
<path d="M128 118 C104 88 95 45 128 36 C161 45 152 88 128 118Z" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>
<path d="M128 124 C98 147 94 190 128 208 C162 190 158 147 128 124Z" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>'''
flower_defs["F10_bell"] = f'''<path d="M84 72 Q128 42 172 72 L188 155 Q128 200 68 155Z" fill="{BLUE}" stroke="{DARK}" stroke-width="4"/>
<path d="M68 155 Q98 138 128 155 Q158 138 188 155" fill="none" stroke="{DARK}" stroke-width="4"/>'''
flower_defs["F11_trumpet"] = f'''<path d="M105 52 Q128 34 151 52 L145 110 Q190 130 195 180 Q128 205 61 180 Q66 130 111 110Z" fill="{FLOWER2}" stroke="{DARK}" stroke-width="4"/>'''
flower_defs["F12_tubular"] = f'''<path d="M107 45 Q128 32 149 45 L154 172 Q128 195 102 172Z" fill="{FLOWER}" stroke="{DARK}" stroke-width="4"/>
<path d="M103 171 Q128 151 153 171" fill="none" stroke="{FLOWER2}" stroke-width="8"/>'''
flower_defs["F13_cruciform"] = f'''<g transform="translate(128 128)">
<ellipse cx="0" cy="-48" rx="25" ry="48" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="0" cy="48" rx="25" ry="48" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="-48" cy="0" rx="48" ry="25" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="48" cy="0" rx="48" ry="25" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>
<circle cx="0" cy="0" r="16" fill="{GOLD}"/></g>'''
flower_defs["F14_five_star"] = f'''<path d="M128 35 L149 94 L212 96 L162 135 L178 198 L128 161 L78 198 L94 135 L44 96 L107 94Z" fill="{FLOWER2}" stroke="{DARK}" stroke-width="4"/>
<circle cx="128" cy="128" r="18" fill="{GOLD}"/>'''
flower_defs["F15_mallow"] = f'''<g transform="translate(128 128)">''' + "".join(
    f'<ellipse cx="0" cy="-53" rx="34" ry="58" transform="rotate({a})" fill="{FLOWER}" stroke="{DARK}" stroke-width="3"/>'
    for a in range(0,360,72)
) + f'''<circle cx="0" cy="0" r="18" fill="{DARK}"/><path d="M128 128 L128 58" stroke="{GOLD}" stroke-width="9"/></g>'''
flower_defs["F16_rose_multi"] = f'''<g transform="translate(128 128)">''' + "".join(
    f'<ellipse cx="{math.cos(math.radians(a))*r:.1f}" cy="{math.sin(math.radians(a))*r:.1f}" rx="{28-r*0.08:.1f}" ry="{42-r*0.08:.1f}" transform="rotate({a+90})" fill="{FLOWER if r<35 else FLOWER2}" stroke="{DARK}" stroke-width="2"/>'
    for r in [55,35,18] for a in range(0,360,60)
) + "</g>"
flower_defs["F17_spurred_violet"] = f'''<ellipse cx="92" cy="103" rx="34" ry="52" transform="rotate(-45 92 103)" fill="{PURPLE}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="164" cy="103" rx="34" ry="52" transform="rotate(45 164 103)" fill="{PURPLE}" stroke="{DARK}" stroke-width="3"/>
<ellipse cx="128" cy="83" rx="32" ry="46" fill="{FLOWER2}" stroke="{DARK}" stroke-width="3"/>
<path d="M96 136 Q128 194 160 136 Q128 159 96 136Z" fill="{WHITE}" stroke="{DARK}" stroke-width="3"/>
<path d="M128 162 L128 220" stroke="{PURPLE}" stroke-width="10"/>'''
flower_defs["F18_cup_saucer"] = f'''<path d="M70 105 Q128 40 186 105 Q180 185 128 198 Q76 185 70 105Z" fill="{WHITE}" stroke="{DARK}" stroke-width="4"/>
<circle cx="128" cy="132" r="27" fill="{GOLD}" opacity=".75"/>'''
for name, body in flower_defs.items():
    save_svg(base/"flowers"/f"{name}.svg", body)

# ---------- skeletons (prototype silhouettes) ----------
def stem(x1,y1,x2,y2,w=8): return f'<path d="M{x1} {y1} Q{(x1+x2)/2} {(y1+y2)/2-10} {x2} {y2}" stroke="{STEM}" stroke-width="{w}" fill="none"/>'
skel_defs={}
skel_defs["S01_upright_herb"] = stem(128,240,128,45,9) + ''.join(stem(128,y,85,y-25,5)+stem(128,y+8,171,y-18,5) for y in [90,135,180])
skel_defs["S02_clumping_herb"] = ''.join(stem(128,240,75+i*18,55+(i%3)*15,7) for i in range(7))
skel_defs["S03_rosette_bulb"] = ''.join(f'<ellipse cx="128" cy="190" rx="22" ry="92" transform="rotate({a} 128 190)" fill="{GREEN2}" stroke="{DARK}" stroke-width="3"/>' for a in [-55,-32,-12,12,32,55]) + stem(128,210,128,55,8)
skel_defs["S04_groundcover"] = stem(45,205,210,180,8)+''.join(stem(70+i*30,200-i*3,70+i*30,120-(i%2)*20,5) for i in range(5))
skel_defs["S05_vine"] = f'<path d="M72 235 C70 160 205 170 178 95 C160 50 95 74 110 28" fill="none" stroke="{STEM}" stroke-width="8"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="22" fill="{GREEN2}" stroke="{DARK}" stroke-width="3"/>' for x,y in [(88,190),(160,155),(175,105),(120,70)])
skel_defs["S06_shrub"] = ''.join(stem(128,238,60+i*22,70+(i%3)*18,8) for i in range(7)) + ''.join(f'<circle cx="{55+i*25}" cy="{88+(i%2)*20}" r="32" fill="{GREEN2}" opacity=".85"/>' for i in range(7))
skel_defs["S07_broadleaf_tree"] = f'<rect x="113" y="115" width="30" height="125" rx="12" fill="{BROWN}"/><circle cx="128" cy="78" r="78" fill="{GREEN2}" stroke="{DARK}" stroke-width="4"/><circle cx="84" cy="96" r="48" fill="{GREEN}"/><circle cx="172" cy="96" r="48" fill="{GREEN}"/>'
skel_defs["S08_tropical_large_herb"] = ''.join(stem(128,235,70+i*30,70+(i%2)*25,9) for i in range(5)) + ''.join(f'<ellipse cx="{70+i*30}" cy="{70+(i%2)*25}" rx="28" ry="70" transform="rotate({-35+i*18} {70+i*30} {70+(i%2)*25})" fill="{GREEN2}" stroke="{DARK}" stroke-width="3"/>' for i in range(5))
skel_defs["S09_orchid_epiphyte"] = ''.join(f'<ellipse cx="128" cy="205" rx="24" ry="70" transform="rotate({a} 128 205)" fill="{GREEN}" stroke="{DARK}" stroke-width="3"/>' for a in [-55,-25,0,25,55]) + stem(128,210,128,60,6)
skel_defs["S10_conifer"] = f'<rect x="118" y="80" width="20" height="160" fill="{BROWN}"/>' + ''.join(f'<path d="M128 {45+i*32} L{55+i*4} {105+i*28} L{201-i*4} {105+i*28} Z" fill="{GREEN if i%2==0 else GREEN2}" stroke="{DARK}" stroke-width="3"/>' for i in range(4))
skel_defs["S11_grass_clump"] = ''.join(f'<path d="M128 238 Q{55+i*24} {135-i*4} {70+i*20} 30" fill="none" stroke="{GREEN2 if i%2 else GREEN}" stroke-width="8"/>' for i in range(7))
skel_defs["S12_fern"] = ''.join(f'<path d="M128 238 Q{80+i*18} {150-i*3} {58+i*24} 45" fill="none" stroke="{GREEN}" stroke-width="12"/>' for i in range(6))
for name, body in skel_defs.items():
    save_svg(base/"skeletons"/f"{name}.svg", body)

# ---------- inflorescences ----------
inflo_defs = {
"I01_single": '<circle cx="128" cy="110" r="35" fill="#d98fa6"/><path d="M128 145 L128 240" stroke="#5a7d4d" stroke-width="8"/>',
"I02_corymb": '<path d="M128 240 L128 160 M128 180 L80 120 M128 180 L176 120 M128 160 L128 100" stroke="#5a7d4d" stroke-width="6" fill="none"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="24" fill="#f2c4d2"/>' for x,y in [(80,110),(128,90),(176,110),(105,125),(151,125)]),
"I03_spike": '<path d="M128 240 L128 45" stroke="#5a7d4d" stroke-width="8"/>' + ''.join(f'<circle cx="{105 if i%2==0 else 151}" cy="{60+i*18}" r="15" fill="#a58ac7"/>' for i in range(9)),
"I04_raceme": '<path d="M128 240 L128 45" stroke="#5a7d4d" stroke-width="7"/>' + ''.join(f'<path d="M128 {65+i*24} L{95 if i%2==0 else 161} {55+i*24}" stroke="#5a7d4d" stroke-width="4"/><circle cx="{90 if i%2==0 else 166}" cy="{52+i*24}" r="16" fill="#d98fa6"/>' for i in range(7)),
"I05_panicle": '<path d="M128 240 L128 65" stroke="#5a7d4d" stroke-width="7"/>' + ''.join(f'<path d="M128 {170-i*28} L{80 if i%2==0 else 176} {135-i*26}" stroke="#5a7d4d" stroke-width="4"/><circle cx="{75 if i%2==0 else 181}" cy="{130-i*26}" r="15" fill="#f2c4d2"/>' for i in range(5)),
"I06_umbel": '<path d="M128 240 L128 135" stroke="#5a7d4d" stroke-width="8"/>' + ''.join(f'<path d="M128 135 L{128+math.cos(math.radians(a))*75:.1f} {135+math.sin(math.radians(a))*70:.1f}" stroke="#5a7d4d" stroke-width="4"/><circle cx="{128+math.cos(math.radians(a))*78:.1f}" cy="{135+math.sin(math.radians(a))*73:.1f}" r="14" fill="#f2c4d2"/>' for a in range(200,341,28)),
"I07_globose_head": '<path d="M128 240 L128 155" stroke="#5a7d4d" stroke-width="8"/><circle cx="128" cy="105" r="62" fill="#a58ac7"/>',
"I08_cyme": '<path d="M128 240 L128 150 M128 170 L83 110 M128 170 L173 110 M83 110 L64 80 M83 110 L100 78 M173 110 L155 78 M173 110 L192 80" stroke="#5a7d4d" stroke-width="5" fill="none"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="16" fill="#d98fa6"/>' for x,y in [(64,76),(100,74),(155,74),(192,76),(128,112)]),
"I09_axillary": '<path d="M128 240 L128 45" stroke="#5a7d4d" stroke-width="8"/>' + ''.join(f'<circle cx="{98 if i%2==0 else 158}" cy="{75+i*35}" r="18" fill="#f2c4d2"/>' for i in range(5)),
"I10_cone_spore": '<path d="M128 240 L128 150" stroke="#5a7d4d" stroke-width="8"/><ellipse cx="128" cy="100" rx="42" ry="68" fill="#775b43"/><path d="M100 75 L155 145 M100 110 L155 155" stroke="#d7b45a" stroke-width="4"/>',
}
for name, body in inflo_defs.items():
    save_svg(base/"inflorescences"/f"{name}.svg", body)

manifest = {
    "version": "0.1-prototype",
    "purpose": "SwiftUI庭描画方式の検証用。最終アートではない。",
    "coordinateSystem": {
        "partCanvas": [256,256],
        "rootAnchor": [128,240],
        "notes": "骨格・花序はrootAnchorが地面側。葉・花は中央基準で、最終的には骨格側のattachment slotsへ配置。"
    },
    "recommendedRuntime": "SVGは制作原本。iOS実装ではPDF/PNGへビルド時変換、またはSwiftUI Canvas/Path化を推奨。",
    "categories": {
        "skeletons": list(skel_defs.keys()),
        "leaves": list(leaf_defs.keys()),
        "flowers": list(flower_defs.keys()),
        "inflorescences": list(inflo_defs.keys())
    },
    "style": {
        "intent": "デフォルメ植物・フラットベクター・太めの輪郭。忘却状態は別画像を作らず彩度/透明度フィルタで表現。"
    }
}
(base/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2), encoding="utf-8")
(base/"README.md").write_text(textwrap.dedent("""
# 花図鑑 庭パーツ Core v0

これは最終アートではなく、モジュール合成方式を実機で検証するためのプロトタイプ素材です。

- skeletons: 12
- leaves: 14
- flowers: 18
- inflorescences: 10

方針:
1. SVGを制作原本にする
2. iOSアプリにはPNG/PDFへ変換して入れるか、将来的にSwiftUI Canvas/Pathへ置換する
3. 色違い・忘却状態は原則として別画像を増やさずコードで表現する
4. 属固有の特徴は、共通パーツで庭が動いた後に追加する

画像のアンカーやスタイルは manifest.json を参照。
""").strip()+"\n", encoding="utf-8")

