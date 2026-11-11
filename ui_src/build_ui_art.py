#!/usr/bin/env python3
"""Génère tous les éléments d'interface AxMob (phase 6) dans assets/ui/.

 1. Nettoie / recadre / redimensionne les éléments FOURNIS (logo, icône, bannières, pièce, étoile,
    trophée, cadeau) : ui_src/provided/ -> assets/ui/.
 2. Dessine les éléments supplémentaires dans le MÊME style (ui_src/candy.py) : boutons, panneaux,
    barres, interrupteurs, curseurs, joystick, icônes.
Déterministe. Usage : python3 ui_src/build_ui_art.py [--only icons|buttons|panels|bars|misc|provided]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from candy import (SS, Layer, canvas, draw_on, ellipse, hexc, line, polygon, rrect,  # noqa: E402
                   smooth, to_mask)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PROVIDED = os.path.join(ROOT, "ui_src", "provided")
OUT = os.path.join(ROOT, "assets", "ui")


def out(*parts):
    p = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


# ------------------------------------------------------------------------------------------
# 1. Éléments fournis
# ------------------------------------------------------------------------------------------
def clean(im, threshold=10):
    """Alpha < seuil -> 0 (franges quasi invisibles), puis recadrage sur le contenu."""
    im = im.convert("RGBA")
    a = np.asarray(im).copy()
    a[a[..., 3] < threshold] = 0
    im = Image.fromarray(a, "RGBA")
    box = im.getchannel("A").getbbox()
    return im.crop(box) if box else im


def fit(im, width=None, height=None):
    w, h = im.size
    if width:
        height = round(h * width / w)
    else:
        width = round(w * height / h)
    return im.resize((width, height), Image.LANCZOS)


def provided():
    def p(name):
        return os.path.join(PROVIDED, name)

    fit(clean(Image.open(p("logo.png"))), width=900).save(out("brand", "logo.png"), optimize=True)
    for c in ("blue", "red", "yellow"):
        fit(clean(Image.open(p(f"{c}_banner.png"))), width=1024).save(
            out("brand", f"banner_{c}.png"), optimize=True)
    for n in ("coin", "star", "trophy", "gift"):
        fit(clean(Image.open(p(f"{n}.png"))), height=320).save(out("icons", f"{n}.png"), optimize=True)
        fit(clean(Image.open(p(f"{n}.png"))), height=112).save(out("icons", f"{n}_s.png"), optimize=True)
    # icône de l'application : carrée, plein cadre
    ic = Image.open(p("app_icon.jpg")).convert("RGB")
    ic.resize((512, 512), Image.LANCZOS).save(out("brand", "app_icon.png"), optimize=True)
    ic.resize((192, 192), Image.LANCZOS).save(out("brand", "app_icon_192.png"), optimize=True)
    # icône adaptative Android : avant-plan = icône à ~70 % (zone de sécurité) aux coins arrondis,
    # arrière-plan = la même image étirée et floutée (prolongement naturel du ciel).
    bg = ic.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(36))
    bg.save(out("brand", "adaptive_background.png"), optimize=True)
    size = 312
    fg_icon = ic.resize((size, size), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=size * 4 // 5, fill=255)
    fg_icon.putalpha(m.resize((size, size), Image.LANCZOS))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(fg_icon, ((432 - size) // 2, (432 - size) // 2))
    fg.save(out("brand", "adaptive_foreground.png"), optimize=True)
    # démarrage Android : page blanche (icône de démarrage totalement transparente)
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(out("brand", "splash_blank.png"))


# ------------------------------------------------------------------------------------------
# 2. Boutons, panneaux, barres
# ------------------------------------------------------------------------------------------
BTN = {  # (haut, bas, lèvre)
    "green": ("#9CF24E", "#2FC24A", "#1E8F3A"),
    "blue": ("#4FD2FF", "#1E7BF0", "#1655B8"),
    "yellow": ("#FFE95A", "#FFA818", "#D77A08"),
    "red": ("#FF7A5C", "#F0362C", "#A8201C"),
    "purple": ("#C69CFF", "#8A4FE8", "#5C2FB0"),
    "grey": ("#E2E8F0", "#A9B4C6", "#7B879C"),
}


def button(name, size=(256, 144), suffix=""):
    w, h = size
    k = h / 144.0
    top, bottom, lip = BTN[name]
    L = Layer(size)
    lm = canvas(w, h)
    rrect(draw_on(lm), (4, 18 * k, w - 4, h - 4), 52 * k)
    lipmask = to_mask(lm)
    L.shadow(lipmask, 0, 4 * k, 5 * k, "#10203C", 0.30)
    L.add(lipmask, lip, lip, 14 * k, spec=0.0, flat=0.7, rim=0.1, edge=0.0)
    fm = canvas(w, h)
    rrect(draw_on(fm), (4, 4, w - 4, h - 22 * k), 50 * k)
    L.add(to_mask(fm), top, bottom, 30 * k, spec=0.45, flat=0.30, gloss=0.55, rim=0.35, edge=0.28)
    L.image().save(out("buttons", f"btn{suffix}_{name}.png"), optimize=True)


def round_button(name, size=(176, 192)):
    w, h = size
    top, bottom, lip = BTN[name]
    L = Layer(size)
    lm = canvas(w, h)
    ellipse(draw_on(lm), (4, 20, w - 4, h - 4))
    lipmask = to_mask(lm)
    L.shadow(lipmask, 0, 4, 5, "#10203C", 0.30)
    L.add(lipmask, lip, lip, 14, spec=0.0, flat=0.7, rim=0.1, edge=0.0)
    fm = canvas(w, h)
    ellipse(draw_on(fm), (4, 4, w - 4, h - 24))
    L.add(to_mask(fm), top, bottom, 38, spec=0.45, flat=0.25, gloss=0.55, rim=0.35, edge=0.28)
    L.image().save(out("buttons", f"btn_round_{name}.png"), optimize=True)


def panel(name, body_top, body_bottom, frame_top, frame_bottom, size=(256, 256), r=64, pad=16):
    w, h = size
    L = Layer(size)
    fm = canvas(w, h)
    rrect(draw_on(fm), (4, 4, w - 4, h - 12), r)
    frame = to_mask(fm)
    L.shadow(frame, 0, 4, 5, "#10203C", 0.28)
    L.add(frame, frame_top, frame_bottom, 22, spec=0.3, flat=0.3, gloss=0.35, rim=0.3, edge=0.3)
    bm = canvas(w, h)
    rrect(draw_on(bm), (4 + pad, 4 + pad, w - 4 - pad, h - 12 - pad), r - pad)
    L.add(to_mask(bm), body_top, body_bottom, 26, spec=0.0, flat=0.6, inset=True, rim=0.12, edge=0.12)
    L.image().save(out("panels", f"{name}.png"), optimize=True)


def plate(name, top, bottom, rim, size=(192, 96), r=48, alpha=1.0):
    """Pastille de HUD (compteurs) : capsule gonflée sans lèvre."""
    w, h = size
    L = Layer(size)
    m = canvas(w, h)
    rrect(draw_on(m), (3, 3, w - 3, h - 6), r)
    mask = to_mask(m)
    L.shadow(mask, 0, 3, 4, "#0A1630", 0.30)
    L.add(mask, rim, rim, 10, spec=0.0, flat=0.6, rim=0.25, edge=0.2)
    m2 = canvas(w, h)
    rrect(draw_on(m2), (3 + 7, 3 + 7, w - 3 - 7, h - 6 - 7), r - 7)
    L.add(to_mask(m2), top, bottom, 14, spec=0.0, flat=0.6, inset=True, rim=0.1, edge=0.1)
    im = L.image()
    if alpha < 1.0:
        a = np.asarray(im).copy()
        a[..., 3] = (a[..., 3] * alpha).astype(np.uint8)
        im = Image.fromarray(a, "RGBA")
    im.save(out("panels", f"{name}.png"), optimize=True)


def tube(name, size, top, bottom, rim, inset=True):
    w, h = size
    r = h // 2
    L = Layer(size)
    m = canvas(w, h)
    rrect(draw_on(m), (2, 2, w - 2, h - 4), r - 2)
    mask = to_mask(m)
    L.shadow(mask, 0, 2, 3, "#0A1630", 0.25)
    L.add(mask, rim, rim, 8, spec=0.0, flat=0.6, rim=0.2, edge=0.15)
    m2 = canvas(w, h)
    rrect(draw_on(m2), (2 + 6, 2 + 6, w - 2 - 6, h - 4 - 6), r - 8)
    L.add(to_mask(m2), top, bottom, 10, spec=0.0, flat=0.6, inset=inset, rim=0.1, edge=0.1)
    L.image().save(out("bars", f"{name}.png"), optimize=True)


def fill(name, size, top, bottom):
    w, h = size
    L = Layer(size)
    m = canvas(w, h)
    rrect(draw_on(m), (1, 1, w - 1, h - 1), h // 2 - 1)
    L.add(to_mask(m), top, bottom, h * 0.42, spec=0.35, flat=0.2, gloss=0.5, rim=0.3, edge=0.25)
    L.image().save(out("bars", f"{name}.png"), optimize=True)


def circle_asset(path, size, top, bottom, bevel, ring=None, **kw):
    w, h = size
    L = Layer(size)
    m = canvas(w, h)
    g = 9  # marge : l'ombre portée ne doit pas être coupée par le bord de l'image
    ellipse(draw_on(m), (g, g - 3, w - g, h - g - 3))
    mask = to_mask(m)
    if kw.pop("shadow", True):
        L.shadow(mask, 0, 3, 3, "#0A1630", 0.28)
    L.add(mask, top, bottom, bevel, **kw)
    if ring:
        m2 = canvas(w, h)
        ellipse(draw_on(m2), (g + ring, g - 3 + ring, w - g - ring, h - g - 3 - ring))
        L.add(to_mask(m2), top, bottom, bevel * 0.6, spec=0.2, flat=0.3, gloss=0.3, inset=True)
    L.image().save(path, optimize=True)


def widgets():
    for n in BTN:
        button(n)
        button(n, (160, 90), "_s")
        round_button(n)
    panel("panel_light", "#FFFDF4", "#FFE9BC", "#3FA9FF", "#1C6BDB")
    panel("panel_dark", "#31449A", "#222F6E", "#6FB6FF", "#2F6FE0")
    panel("panel_card", "#FFFFFF", "#EAF2FF", "#9FC8FF", "#6FA2F0", r=56, pad=12)
    panel("panel_gold", "#FFF3B8", "#FFD45A", "#FFC21E", "#E58E0C", r=56, pad=14)
    plate("plate_dark", "#2A3A86", "#1D2860", "#6FB6FF")
    plate("plate_light", "#FFFDF4", "#FFE9BC", "#3FA9FF")
    tube("bar_frame", (256, 64), "#1B2554", "#27357C", "#6FB6FF")
    fill("bar_red", (192, 44), "#FF8A78", "#F0362C")
    fill("bar_green", (192, 44), "#B6F76A", "#2FC24A")
    fill("bar_yellow", (192, 44), "#FFEE70", "#FFA818")
    fill("bar_blue", (192, 44), "#7CE0FF", "#1E7BF0")
    fill("bar_white", (192, 44), "#FFFFFF", "#CFE0FA")
    tube("slider_track", (256, 48), "#1B2554", "#27357C", "#6FB6FF")
    # interrupteur
    for name, (t, b, lip) in (("on", BTN["green"]), ("off", BTN["grey"])):
        L = Layer((192, 104))
        m = canvas(192, 104)
        rrect(draw_on(m), (3, 3, 189, 96), 46)
        mask = to_mask(m)
        L.shadow(mask, 0, 3, 4, "#0A1630", 0.28)
        L.add(mask, lip, lip, 10, spec=0.0, flat=0.6, edge=0.1)
        m2 = canvas(192, 104)
        rrect(draw_on(m2), (10, 10, 182, 88), 39)
        L.add(to_mask(m2), t, b, 22, spec=0.3, flat=0.35, gloss=0.35, inset=True, rim=0.1, edge=0.15)
        L.image().save(out("bars", f"toggle_{name}.png"), optimize=True)
    circle_asset(out("bars", "knob_white.png"), (96, 104), "#FFFFFF", "#CFDDF5", 30,
                 spec=0.5, flat=0.1, gloss=0.4)
    circle_asset(out("bars", "knob_yellow.png"), (112, 120), "#FFF27A", "#FFA818", 34, ring=18,
                 spec=0.5, flat=0.2, gloss=0.45)


# ------------------------------------------------------------------------------------------
# 3. Joystick et divers
# ------------------------------------------------------------------------------------------
def misc():
    # base du joystick : anneau de verre clair
    size = (320, 320)
    L = Layer(size)
    m = canvas(*size)
    ellipse(draw_on(m), (6, 6, 314, 314))
    L.add(to_mask(m), "#FFFFFF", "#BFE3FF", 54, spec=0.2, flat=0.8, rim=0.5, edge=0.2, gloss=0.2)
    m2 = canvas(*size)
    ellipse(draw_on(m2), (40, 40, 280, 280))
    L.add(to_mask(m2), "#5DB2FF", "#2A6FE0", 40, spec=0.0, flat=0.7, inset=True, rim=0.1, edge=0.1)
    im = L.image()
    a = np.asarray(im).copy()
    a[..., 3] = (a[..., 3] * 0.62).astype(np.uint8)
    Image.fromarray(a, "RGBA").save(out("misc", "joy_base.png"), optimize=True)
    circle_asset(out("misc", "joy_knob.png"), (176, 184), "#FFFFFF", "#7CC4FF", 60,
                 spec=0.7, flat=0.0, gloss=0.55)
    # pastille de notification (rouge) et point
    circle_asset(out("misc", "badge_red.png"), (72, 76), "#FF8A78", "#E02A22", 24, spec=0.5, gloss=0.4)
    circle_asset(out("misc", "badge_green.png"), (72, 76), "#B6F76A", "#2FC24A", 24, spec=0.5, gloss=0.4)
    # point de chargement (lumière)
    circle_asset(out("misc", "dot_white.png"), (48, 52), "#FFFFFF", "#CFE0FA", 16, spec=0.4, gloss=0.3)
    # rayons de victoire (fond tournant de l'écran de fin) : éventail doux, teinté en jeu
    size = 512
    img = np.zeros((size, size), np.float32)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    ang = np.arctan2(yy - size / 2, xx - size / 2)
    rad = np.hypot(yy - size / 2, xx - size / 2) / (size / 2)
    rays = (np.cos(ang * 6) > 0.35).astype(np.float32)
    rays = np.asarray(Image.fromarray((rays * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)),
                      np.float32) / 255
    fade = np.clip(1.0 - rad, 0, 1) ** 1.2
    img = rays * fade
    rgba = np.dstack([np.ones((size, size, 3), np.float32), img * 0.55])
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(out("misc", "rays.png"), optimize=True)
    # ombre douce (pastille) pour les personnages dans le menu
    size = 256
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.hypot((xx - size / 2) / (size / 2), (yy - size / 2) / (size / 2) * 1.6)
    a = np.clip(1.0 - d, 0, 1) ** 1.6 * 0.55
    rgba = np.dstack([np.zeros((size, size, 3), np.float32), a])
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(out("misc", "soft_shadow.png"), optimize=True)


# ------------------------------------------------------------------------------------------
# 4. Icônes (grille 192 x 192)
# ------------------------------------------------------------------------------------------
IC = 192


def glyph(name, fn, top="#FFFFFF", bottom="#CFE0FA", bevel=14, shadow="#0A2A6E", **kw):
    """Icône blanche gonflée avec légère ombre portée colorée (lisible sur tous les boutons)."""
    m = canvas(IC, IC)
    fn(draw_on(m))
    mask = smooth(to_mask(m), 0.6)
    L = Layer((IC, IC))
    L.shadow(mask, 0, 5, 3.5, shadow, 0.40)
    L.add(mask, top, bottom, bevel, spec=kw.pop("spec", 0.45), flat=kw.pop("flat", 0.15),
          gloss=kw.pop("gloss", 0.3), rim=0.3, edge=0.22)
    L.image().save(out("icons", f"{name}.png"), optimize=True)


def colored(name, parts, shadow="#0A1630"):
    """Icône multi-couches : parts = [(fn, top, bottom, bevel, opts)], dessinées dans l'ordre."""
    L = Layer((IC, IC))
    first = True
    for fn, top, bottom, bevel, opts in parts:
        m = canvas(IC, IC)
        fn(draw_on(m))
        mask = smooth(to_mask(m), 0.6)
        if first:
            L.shadow(mask, 0, 5, 3.5, shadow, 0.35)
            first = False
        o = dict(spec=0.45, flat=0.15, gloss=0.3, rim=0.3, edge=0.25)
        o.update(opts)
        L.add(mask, top, bottom, bevel, **o)
    L.image().save(out("icons", f"{name}.png"), optimize=True)


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [((x - cx) * c - (y - cy) * s + cx, (x - cx) * s + (y - cy) * c + cy) for x, y in pts]


def arc_ring(d, cx, cy, r_out, r_in, a0, a1, step=3):
    pts_o = [(cx + r_out * math.cos(math.radians(a)), cy + r_out * math.sin(math.radians(a)))
             for a in range(int(a0), int(a1) + 1, step)]
    pts_i = [(cx + r_in * math.cos(math.radians(a)), cy + r_in * math.sin(math.radians(a)))
             for a in range(int(a1), int(a0) - 1, -step)]
    polygon(d, pts_o + pts_i)


def axe_parts(cx, cy, scale, deg, blade_top="#F2F6FB", blade_bottom="#8E9FB8"):
    """Hache de l'univers du jeu : manche en bois + double lame en croissant."""
    def handle(d):
        pts = [(cx - 9 * scale, cy - 70 * scale), (cx + 9 * scale, cy - 70 * scale),
               (cx + 9 * scale, cy + 70 * scale), (cx - 9 * scale, cy + 70 * scale)]
        polygon(d, rot(pts, cx, cy, deg))

    def blade(d):
        for sx in (-1, 1):
            pts = []
            # arc extérieur (grand) de haut en bas puis arc intérieur concave (retour)
            for t in np.linspace(-1.0, 1.0, 26):
                a = t * math.radians(84)
                pts.append((cx + sx * (6 + 50 * math.cos(a) ** 0.9) * scale,
                            cy - 40 * scale + 46 * math.sin(a) * scale))
            for t in np.linspace(1.0, -1.0, 26):
                a = t * math.radians(70)
                pts.append((cx + sx * (6 + 20 * math.cos(a)) * scale,
                            cy - 40 * scale + 40 * math.sin(a) * scale))
            polygon(d, rot(pts, cx, cy, deg))
        pts = [(cx - 15 * scale, cy - 62 * scale), (cx + 15 * scale, cy - 62 * scale),
               (cx + 15 * scale, cy - 18 * scale), (cx - 15 * scale, cy - 18 * scale)]
        polygon(d, rot(pts, cx, cy, deg))
    return [(handle, "#E8A25E", "#B0652A", 8, dict(gloss=0.1)),
            (blade, blade_top, blade_bottom, 12, dict(spec=0.5))]


def icons():
    # --- glyphes blancs ---
    glyph("play", lambda d: polygon(d, [(64, 38), (64, 154), (158, 96)]))
    glyph("pause", lambda d: (rrect(d, (54, 42, 88, 150), 12), rrect(d, (104, 42, 138, 150), 12)))
    glyph("back", lambda d: line(d, [(122, 38), (64, 96), (122, 154)], 26))
    glyph("close", lambda d: (line(d, [(52, 52), (140, 140)], 26), line(d, [(140, 52), (52, 140)], 26)))
    glyph("check", lambda d: line(d, [(44, 100), (80, 136), (148, 58)], 28))
    glyph("plus", lambda d: (rrect(d, (80, 40, 112, 152), 14), rrect(d, (40, 80, 152, 112), 14)))
    glyph("arrow_up", lambda d: (polygon(d, [(96, 28), (156, 96), (118, 96), (118, 160), (74, 160),
                                             (74, 96), (36, 96)])))

    def home(d):
        polygon(d, [(96, 24), (172, 94), (152, 94), (152, 160), (40, 160), (40, 94), (20, 94)])
        rrect(d, (80, 106, 112, 160), 8, fill=0)
    glyph("home", home)

    def replay(d):
        arc_ring(d, 96, 98, 66, 40, 20, 300)
        polygon(d, [(142, 20), (176, 74), (112, 78)])
    glyph("replay", replay)

    def lock(d):
        arc_ring(d, 96, 76, 40, 22, 180, 360)
        rrect(d, (40, 72, 56, 100), 4)
        rrect(d, (136, 72, 152, 100), 4)
        rrect(d, (34, 84, 158, 160), 22)
        ellipse(d, (84, 108, 108, 132), fill=0)
        rrect(d, (90, 124, 102, 146), 5, fill=0)
    glyph("lock", lock, "#FFE95A", "#FFA818", shadow="#6A3A00")

    def music(d):
        ellipse(d, (30, 112, 82, 160))
        ellipse(d, (100, 98, 152, 146))
        polygon(d, [(70, 52), (140, 36), (140, 62), (70, 78)])
        rrect(d, (66, 52, 82, 140), 6)
        rrect(d, (136, 36, 152, 124), 6)
    glyph("music", music)

    def sound(d):
        polygon(d, [(28, 74), (62, 74), (104, 36), (104, 156), (62, 118), (28, 118)])
        arc_ring(d, 100, 96, 46, 34, -48, 48)
        arc_ring(d, 100, 96, 72, 60, -48, 48)
    glyph("sound", sound)

    def vibrate(d):
        rrect(d, (66, 28, 126, 164), 16)
        rrect(d, (78, 44, 114, 140), 6, fill=0)
        arc_ring(d, 96, 96, 90, 72, 155, 205)
        arc_ring(d, 96, 96, 90, 72, -25, 25)
        arc_ring(d, 96, 96, 62, 48, 150, 210)
        arc_ring(d, 96, 96, 62, 48, -30, 30)
    glyph("vibrate", vibrate)

    def graphics(d):
        rrect(d, (24, 36, 168, 134), 18)
        rrect(d, (40, 52, 152, 118), 8, fill=0)
        rrect(d, (80, 134, 112, 154), 4)
        rrect(d, (56, 150, 136, 166), 8)
        polygon(d, [(96, 60), (104, 82), (126, 90), (104, 98), (96, 120), (88, 98), (66, 90), (88, 82)])
    glyph("graphics", graphics)

    def chart(d):
        rrect(d, (28, 98, 66, 160), 8)
        rrect(d, (77, 60, 115, 160), 8)
        rrect(d, (126, 28, 164, 160), 8)
    glyph("chart", chart)

    def globe(d):
        ellipse(d, (24, 24, 168, 168))
        ellipse(d, (40, 40, 152, 152), fill=0)
        ellipse(d, (70, 24, 122, 168))
        ellipse(d, (82, 24, 110, 168), fill=0)
        rrect(d, (24, 90, 168, 102), 5)
        rrect(d, (40, 56, 152, 66), 4)
        rrect(d, (40, 126, 152, 136), 4)
    glyph("globe", globe)

    def video(d):
        rrect(d, (22, 40, 134, 152), 22)
        polygon(d, [(142, 80), (172, 58), (172, 134), (142, 112)])
        polygon(d, [(58, 70), (58, 122), (104, 96)], fill=0)
    glyph("video", video, "#FFFFFF", "#CFE0FA")

    def speed(d):
        for i, x in enumerate((34, 70, 106)):
            line(d, [(x, 44), (x + 40, 96), (x, 148)], 22)
    glyph("speed", speed, "#FFFFFF", "#CFE0FA")
    glyph("speed_blue", speed, "#7CD0FF", "#1E7BF0", shadow="#0A2A6E")

    # --- icônes colorées ---
    def heart(d):
        ellipse(d, (22, 34, 100, 112))
        ellipse(d, (92, 34, 170, 112))
        polygon(d, [(26, 88), (166, 88), (96, 166)])
    colored("heart", [(heart, "#FF9A8A", "#E8202A", 30, dict(gloss=0.5))], shadow="#5A0A10")

    def skull(d):
        ellipse(d, (32, 22, 160, 128))
        rrect(d, (58, 100, 134, 164), 20)
    parts = [(skull, "#FFF27A", "#FFB21A", 30, dict(gloss=0.45)),
             (lambda d: (ellipse(d, (58, 66, 92, 106)), ellipse(d, (100, 66, 134, 106)),
                         polygon(d, [(96, 104), (86, 124), (106, 124)])),
              "#6A3A12", "#3A1C06", 10, dict(spec=0.0, flat=0.6, inset=True, gloss=0.0, rim=0.1)),
             (lambda d: [rrect(d, (x, 134, x + 7, 156), 3) for x in (74, 90, 105)],
              "#C8860E", "#B27208", 4, dict(spec=0.0, flat=0.7, gloss=0.0, rim=0.05))]
    colored("skull", parts, shadow="#5A3000")

    def skull_red(d):
        skull(d)
    colored("skull_red", [(skull_red, "#FF9A8A", "#E02A22", 30, dict(gloss=0.45)),
                          parts[1], (parts[2][0], "#A8201C", "#8A1814", 4, parts[2][4])],
            shadow="#5A0A10")

    def clock(d):
        ellipse(d, (22, 22, 170, 170))
    colored("clock", [
        (clock, "#7CD0FF", "#1E7BF0", 34, dict(gloss=0.4)),
        (lambda d: ellipse(d, (40, 40, 152, 152)), "#FFFFFF", "#DDE9FA", 30,
         dict(spec=0.2, flat=0.4, inset=True, gloss=0.0, rim=0.1)),
        (lambda d: (rrect(d, (90, 56, 102, 100), 6), rrect(d, (90, 90, 130, 102), 6)),
         "#2A4AA8", "#1B2F7A", 6, dict(spec=0.2, flat=0.7, gloss=0.0, rim=0.05)),
        (lambda d: ellipse(d, (88, 88, 104, 104)), "#FF7A5C", "#E02A22", 6,
         dict(spec=0.2, flat=0.5, gloss=0.0, rim=0.05)),
    ])

    def gear(d):
        ellipse(d, (42, 42, 150, 150))
        for k in range(8):
            pts = [(80, 12), (112, 12), (112, 46), (80, 46)]
            polygon(d, rot(pts, 96, 96, k * 45))
        ellipse(d, (68, 68, 124, 124), fill=0)
    colored("gear", [(gear, "#E4ECF7", "#8E9FBC", 22, dict(gloss=0.4)),
                     (lambda d: ellipse(d, (74, 74, 118, 118)), "#4A5E96", "#2A3A70", 10,
                      dict(spec=0.0, flat=0.6, inset=True, gloss=0.0, rim=0.08))])

    colored("axe", axe_parts(96, 100, 1.1, 38))
    colored("axe_light", axe_parts(96, 100, 0.8, 38))
    colored("axe_heavy", axe_parts(96, 98, 1.35, 38, "#FFB27A", "#D8501C"))
    multi = []
    for deg, ox in ((-30, -34), (0, 0), (30, 34)):
        multi += axe_parts(96 + ox * 0.5, 108, 0.7, deg)
    colored("axe_multi", multi)

    def pierce_line(d):
        rrect(d, (10, 92, 182, 108), 8)
        polygon(d, [(182, 84), (190, 100), (182, 116), (160, 100)])
    colored("axe_pierce", axe_parts(80, 100, 0.95, 38) + [
        (pierce_line, "#FFFFFF", "#9DD2FF", 8, dict(spec=0.3, flat=0.4, gloss=0.2))])

    def bolt(d):
        polygon(d, [(112, 14), (40, 108), (86, 108), (70, 178), (152, 76), (104, 76), (130, 14)])
    colored("bolt", [(bolt, "#FFF27A", "#FF9A12", 24, dict(gloss=0.5))], shadow="#6A3A00")

    # coin_plus : la pièce fournie + une pastille verte « + » (cohérent avec la pièce du HUD)
    coin = Image.open(out("icons", "coin.png")).convert("RGBA").resize((150, 150), Image.LANCZOS)
    cp = Image.new("RGBA", (IC, IC), (0, 0, 0, 0))
    cp.alpha_composite(coin, (8, 34))
    L = Layer((IC, IC))
    mm = canvas(IC, IC)
    d = draw_on(mm)
    rrect(d, (130, 14, 154, 76), 9)
    rrect(d, (111, 33, 173, 57), 9)
    L.add(smooth(to_mask(mm), 0.6), "#B6F76A", "#2FC24A", 9, spec=0.4, flat=0.3, gloss=0.3)
    cp.alpha_composite(L.image())
    cp.save(out("icons", "coin_plus.png"), optimize=True)
    colored("shield", [(lambda d: polygon(d, [(96, 20), (160, 40), (156, 110), (96, 170), (36, 110),
                                              (32, 40)]), "#7CD0FF", "#1E7BF0", 28, dict(gloss=0.45)),
                       (lambda d: polygon(d, [(96, 46), (136, 58), (133, 104), (96, 140), (59, 104),
                                              (56, 58)]), "#FFFFFF", "#CFE0FA", 20,
                        dict(spec=0.2, flat=0.4, inset=True, gloss=0.0, rim=0.1))])


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else "all"
    if only in ("all", "provided"):
        provided()
    if only in ("all", "buttons", "panels", "bars"):
        widgets()
    if only in ("all", "misc"):
        misc()
    if only in ("all", "icons"):
        icons()
    print("[ui_art] ok ->", OUT)


if __name__ == "__main__":
    main()
