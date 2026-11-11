"""Héros : le Vacancier au bob turquoise (phase 4). Grosse tête, lunettes de soleil, chemise à
fleurs, short bleu, tongs. Le chapeau (disque turquoise + bandeau blanc) le rend identifiable
de dessus dans toutes les situations. Budget : 3 000 triangles, 24 os (7 utilisés).
Animations : idle-loop, run-loop, hit, death."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, M_align, wave, smooth, ease_out, seg  # noqa: E402
from mathutils import Vector  # noqa: E402

SHIRT = (0.31, 0.27, 0.3)
SHIRT_C = Vector((0, 0, 0.76))


def hat_color(c, n):
    return "teal_dark" if n.z < -0.5 else "teal"


def build():
    ax.reset_scene()
    spec = [
        ("root", None, (0, 0, 0)),
        ("body", "root", (0, 0, 0.5)),
        ("head", "body", (0, 0, 0.98)),
        ("arm_l", "body", (-0.3, 0, 0.86)),
        ("arm_r", "body", (0.3, 0, 0.86)),
        ("leg_l", "root", (-0.13, 0, 0.45)),
        ("leg_r", "root", (0.13, 0, 0.45)),
    ]
    rig = ax.Rig("char_player", spec)
    m = ax.Mesher()
    # jambes, shorts, tongs
    for side, sx in (("l", -1), ("r", 1)):
        b = f"leg_{side}"
        m.add(ax.capsule(0.095, 0.16, 8, 3, M((sx * 0.13, 0, 0.25))), "skin", b, crease=0)
        m.add(ax.cyl(0.125, 0.14, 0.16, 10, 0.31, True, True, M((sx * 0.13, 0, 0.0))), "blue", b, crease=40)
        m.add(ax.ellipsoid((0.125, 0.21, 0.05), 10, 5, M((sx * 0.13, 0.05, 0.05))), "yellow", b, crease=0)
        m.add(ax.ellipsoid((0.1, 0.05, 0.04), 6, 3, M((sx * 0.13, 0.08, 0.1))), "orange", b, crease=0)
    # bassin et torse (chemise à fleurs)
    m.add(ax.ellipsoid((0.31, 0.26, 0.17), 14, 7, M((0, 0, 0.5))), "blue", "body")
    m.add(ax.ellipsoid(SHIRT, 16, 9, M(tuple(SHIRT_C))), lambda c, n: "coral" if n.z > -0.5 else "blue", "body")
    for d in ax.fibonacci_sphere(26):
        if d.z < -0.1 or d.z > 0.8:
            continue
        p = SHIRT_C + Vector((d.x * SHIRT[0], d.y * SHIRT[1], d.z * SHIRT[2])) * 0.985
        col = "white" if (int(d.x * 10) + int(d.y * 10)) % 2 == 0 else "yellow"
        m.add(ax.ellipsoid((0.065, 0.065, 0.02), 6, 3, M_align(p, d)), col, "body", crease=0, grad=0.4)
    # bras
    for side, sx in (("l", -1), ("r", 1)):
        b = f"arm_{side}"
        m.add(ax.ellipsoid((0.115, 0.115, 0.13), 8, 5, M((sx * 0.35, 0, 0.84))), "coral", b, crease=0)
        m.add(ax.capsule(0.075, 0.2, 8, 3, M((sx * 0.4, 0, 0.66), (0, sx * 8, 0))), "skin", b, crease=0)
        m.add(ax.ellipsoid((0.085, 0.085, 0.085), 8, 5, M((sx * 0.43, 0, 0.5))), "skin", b, crease=0)
    # tête
    m.add(ax.ellipsoid((0.42, 0.4, 0.4), 18, 11, M((0, 0, 1.2))), "skin", "head")
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.06, 0.04, 0.09), 6, 4, M((sx * 0.41, 0, 1.16))), "skin_dark", "head", crease=0)
        m.add(ax.ellipsoid((0.07, 0.03, 0.05), 6, 3, M((sx * 0.25, 0.37, 1.07), (0, 0, sx * -10))), "blush", "head", crease=0)
        # lunettes : verres noirs, éclats, branches
        m.add(ax.ellipsoid((0.135, 0.045, 0.1), 10, 5, M((sx * 0.17, 0.375, 1.26))), "black", "head", crease=0)
        m.add(ax.ellipsoid((0.04, 0.02, 0.025), 5, 3, M((sx * 0.2, 0.415, 1.3))), "white", "head", crease=0)
        m.add(ax.tube([(sx * 0.3, 0.33, 1.27), (sx * 0.4, 0.15, 1.25)], [0.02, 0.02], 4, 0), "ink", "head", crease=0)
    m.add(ax.box((0.12, 0.03, 0.03), 0.0, 1, M((0, 0.385, 1.27))), "ink", "head", crease=0)
    m.add(ax.ellipsoid((0.05, 0.055, 0.05), 7, 4, M((0, 0.4, 1.16))), "skin_dark", "head", crease=0)
    m.add(ax.tube([(-0.14, 0.375, 1.05), (0, 0.395, 1.015), (0.14, 0.375, 1.05)], [0.02, 0.02, 0.02], 5, 0.5), "ink", "head", crease=0)
    # cheveux dépassant du chapeau
    m.add(ax.ellipsoid((0.36, 0.16, 0.2), 10, 6, M((0, -0.28, 1.2))), "wood_dark", "head", crease=0)
    # bob : calotte, bandeau, bord évasé
    m.add(ax.cyl(0.36, 0.3, 0.22, 16, 1.44, True, False), hat_color, "head", crease=35)
    m.add(ax.dome(0.3, 0.07, 16, 3, 1.66), "teal", "head", crease=0)
    m.add(ax.cyl(0.372, 0.365, 0.06, 16, 1.48, False, False), "white", "head", crease=35)
    m.add(ax.cyl(0.58, 0.36, 0.1, 20, 1.38, True, True), hat_color, "head", crease=35)
    # pompon et repère d'orientation (flèche blanche sur le dessus : on voit où regarde le héros)
    m.add(ax.ellipsoid((0.085, 0.085, 0.085), 8, 5, M((0, -0.02, 1.76))), "coral", "head", crease=0)
    m.add(ax.prism([(0.0, 0.27), (-0.12, 0.04), (0.12, 0.04)], 0.022, 0.0, 1, M((0, 0, 1.738))), "white", "head", crease=0)
    obj = m.build("char_player", rig=rig)
    animate(rig)
    return obj


def animate(rig):
    def limbs(u, cyc, leg, arm):
        return {
            "leg_l": {"rot": (leg * wave(u, cyc, 0.0), 0, 0)},
            "leg_r": {"rot": (leg * wave(u, cyc, 0.5), 0, 0)},
            "arm_l": {"rot": (arm * wave(u, cyc, 0.5), 0, -4)},
            "arm_r": {"rot": (arm * wave(u, cyc, 0.0), 0, 4)},
        }

    def idle(u, t):
        p = limbs(u, 1, 0, 3)
        p["body"] = {"scale": (1, 1, 1 + 0.02 * wave(u)), "rot": (0, 0, 1.5 * wave(u, 1, 0.25))}
        p["head"] = {"rot": (2 * wave(u, 1, 0.1), 0, 2 * wave(u, 1, 0.4))}
        return p

    def run(u, t):
        p = limbs(u, 1, 42, 48)
        p["root"] = {"loc": (0, 0, 0.07 * abs(wave(u, 2, 0.0)))}
        p["body"] = {"rot": (6, 0, 6 * wave(u, 1, 0.0))}
        p["head"] = {"rot": (-3, 4 * wave(u, 1, 0.5), 0)}
        return p

    def hit(u, t):
        k = wave(seg(u, 0, 1) * 0.5, 1)
        p = limbs(u, 1, 0, 0)
        p["body"] = {"rot": (14 * k, 0, 4 * k), "scale": (1 + 0.06 * k, 1 + 0.06 * k, 1 - 0.1 * k)}
        p["arm_l"] = {"rot": (-10, 0, -40 * k)}
        p["arm_r"] = {"rot": (-10, 0, 40 * k)}
        p["head"] = {"rot": (-10 * k, 0, 0)}
        return p

    def death(u, t):
        fall = ease_out(seg(u, 0.0, 0.55))
        bounce = max(0.0, math.sin(math.pi * seg(u, 0.5, 0.75))) * 0.08
        p = {}
        p["root"] = {"rot": (88 * fall, 0, 0), "loc": (0, 0, bounce)}
        p["arm_l"] = {"rot": (0, 0, -70 * fall)}
        p["arm_r"] = {"rot": (0, 0, 70 * fall)}
        p["leg_l"] = {"rot": (0, 0, -14 * fall)}
        p["leg_r"] = {"rot": (0, 0, 14 * fall)}
        p["head"] = {"rot": (-14 * fall, 0, 10 * fall)}
        return p

    rig.bake("idle", 1.6, idle, loop=True)
    rig.bake("run", 0.5, run, loop=True)
    rig.bake("hit", 0.3, hit)
    rig.bake("death", 0.9, death)
    rig.finish()


def main():
    build()
    ax.export("char_player")


if __name__ == "__main__":
    ax.main_guard(main)
