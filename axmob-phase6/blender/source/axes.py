"""Les quatre haches projectiles (phase 4). À plat dans le plan XY (le jeu les fait tourner
autour de l'axe vertical) : manche le long de +Y (pointe = avant), lame côté +X, origine au
centre. Tailles de base ~0,8 m (le jeu applique visual_scale du ProjectileData).
  axe_light  — hachette d'acier bleutée, manche orange        (tourelle rapide)
  axe_heavy  — hache à double tranchant, acier sombre et rouge (tourelle lourde)
  axe_multi  — petite hachette jaune et rose                   (tourelle multiple)
  axe_pierce — hache-lance effilée à lame cyan                 (tourelle perforante)
Budget : 250 à 500 triangles chacune."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M  # noqa: E402


def finish(name, m):
    m.build(name)
    ax.export(name)


def handle(m, y0, y1, r, color, grip=None, pommel="gold", bands=3):
    m.add(ax.cyl(r, r, y1 - y0, 8, y0, True, True, M((0, 0, 0), (-90, 0, 0)) @ M()), color, crease=40)
    # cyl est vertical (Z) : on le couche le long de +Y
    if grip:
        for k in range(bands):
            y = y0 + 0.08 + k * 0.07
            m.add(ax.torus(r + 0.004, 0.012, 10, 4, M((0, y, 0), (90, 0, 0))), grip, crease=0)
    m.add(ax.ellipsoid((r * 1.8, r * 1.8, r * 1.8), 8, 5, M((0, y0, 0))), pommel, crease=0)


def blade(m, pts, thick, color, edge, bevel=0.012, mirror=False):
    def col(c, n):
        return edge if abs(c.x) > 0.7 * max(abs(p[0]) for p in pts) else color

    m.add(ax.prism(pts, thick, bevel, 1), col, crease=50, grad=0.6)
    if mirror:
        m.add(ax.prism([(-x, y) for x, y in pts[::-1]], thick, bevel, 1), col, crease=50, grad=0.6)


def light():
    ax.reset_scene()
    m = ax.Mesher()
    handle_len = (-0.4, 0.4)
    m.add(ax.cyl(0.036, 0.036, 0.8, 8, 0.0, True, True, M((0, -0.4, 0), (-90, 0, 0))), "orange", crease=40)
    m.add(ax.cyl(0.04, 0.04, 0.2, 8, 0.0, True, True, M((0, -0.4, 0), (-90, 0, 0))), "wood_dark", crease=40)
    for k in range(3):
        m.add(ax.torus(0.04, 0.012, 8, 3, M((0, -0.3 + k * 0.06, 0), (90, 0, 0))), "gold", crease=0)
    m.add(ax.ellipsoid((0.06, 0.06, 0.06), 8, 5, M((0, -0.41, 0))), "gold", crease=0)
    m.add(ax.cyl(0.06, 0.05, 0.16, 8, 0.0, True, True, M((0, 0.24, 0), (-90, 0, 0))), "steel_dark", crease=40)
    blade(m, [(0.03, 0.22), (0.27, 0.1), (0.37, 0.3), (0.27, 0.5), (0.03, 0.4)], 0.05, "steel_dark", "steel_light")
    m.add(ax.cyl(0.04, 0.0, 0.14, 6, 0.0, True, True, M((-0.06, 0.34, 0), (0, 90, 0))), "steel_dark", crease=0)
    finish("axe_light", m)


def heavy():
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.cyl(0.05, 0.05, 0.84, 8, 0.0, True, True, M((0, -0.42, 0), (-90, 0, 0))), "wood_dark", crease=40)
    for k in range(3):
        m.add(ax.torus(0.056, 0.016, 8, 3, M((0, -0.32 + k * 0.07, 0), (90, 0, 0))), "red", crease=0)
    m.add(ax.ellipsoid((0.085, 0.085, 0.085), 8, 5, M((0, -0.43, 0))), "red_dark", crease=0)
    m.add(ax.cyl(0.09, 0.08, 0.2, 8, 0.0, True, True, M((0, 0.2, 0), (-90, 0, 0))), "steel_dark", crease=40)
    pts = [(0.05, 0.16), (0.3, 0.04), (0.42, 0.3), (0.3, 0.56), (0.05, 0.44)]
    blade(m, pts, 0.07, "steel_dark", "steel_light", 0.016, mirror=True)
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.045, 0.03, 0.05), 6, 4, M((sx * 0.14, 0.3, 0.04))), "red", crease=0)
    finish("axe_heavy", m)


def multi():
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.cyl(0.032, 0.032, 0.7, 8, 0.0, True, True, M((0, -0.35, 0), (-90, 0, 0))), "yellow", crease=40)
    m.add(ax.ellipsoid((0.055, 0.055, 0.055), 8, 5, M((0, -0.36, 0))), "pink", crease=0)
    for k in range(2):
        m.add(ax.torus(0.036, 0.011, 8, 3, M((0, -0.26 + k * 0.06, 0), (90, 0, 0))), "pink", crease=0)
    m.add(ax.cyl(0.055, 0.045, 0.13, 8, 0.0, True, True, M((0, 0.2, 0), (-90, 0, 0))), "steel_dark", crease=40)
    blade(m, [(0.03, 0.18), (0.22, 0.1), (0.3, 0.26), (0.22, 0.42), (0.03, 0.34)], 0.045, "steel", "white")
    finish("axe_multi", m)


def pierce():
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.cyl(0.03, 0.03, 1.0, 8, 0.0, True, True, M((0, -0.5, 0), (-90, 0, 0))), "grey_dark", crease=40)
    for k in range(3):
        m.add(ax.torus(0.034, 0.011, 8, 3, M((0, -0.38 + k * 0.06, 0), (90, 0, 0))), "teal", crease=0)
    m.add(ax.ellipsoid((0.05, 0.05, 0.05), 8, 5, M((0, -0.51, 0))), "gold", crease=0)
    m.add(ax.cyl(0.05, 0.04, 0.16, 8, 0.0, True, True, M((0, 0.4, 0), (-90, 0, 0))), "steel_dark", crease=40)
    leaf = [(0.0, 1.02), (0.1, 0.84), (0.115, 0.6), (0.0, 0.5), (-0.115, 0.6), (-0.1, 0.84)]
    m.add(ax.prism(leaf, 0.04, 0.01, 1), lambda c, n: "water_light" if abs(c.x) < 0.045 else "blue_light", crease=50, grad=0.6)
    for sx in (-1, 1):
        m.add(ax.prism([(sx * 0.05, 0.52), (sx * 0.22, 0.4), (sx * 0.05, 0.64)] if sx > 0 else [(-0.05, 0.64), (-0.22, 0.4), (-0.05, 0.52)],
                       0.035, 0.0, 1), "steel_light", crease=0)
    finish("axe_pierce", m)


def main():
    for fn in (light, heavy, multi, pierce):
        fn()


if __name__ == "__main__":
    ax.main_guard(main)
