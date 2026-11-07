"""Ennemi lourd : la Tortue (phase 4). Grosse carapace verte à plaques hexagonales, tête
renfrognée, pattes courtes. Budget : 2 500 triangles, 16 os.
Animations : idle-loop, run-loop (dandinement), attack (coup de tête), hit, death."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, M_align, wave, smooth, ease_out, seg  # noqa: E402
from mathutils import Vector  # noqa: E402

SHELL = (0.78, 0.92, 0.5)  # rayons x, y, hauteur de la calotte
SHELL_Z = 0.30


def shell_point(x, y):
    k = 1.0 - (x / SHELL[0]) ** 2 - (y / SHELL[1]) ** 2
    z = SHELL_Z + SHELL[2] * math.sqrt(max(k, 0.0))
    nz = (z - SHELL_Z) / SHELL[2] ** 2
    n = Vector((x / SHELL[0] ** 2, y / SHELL[1] ** 2, nz)).normalized()
    return Vector((x, y, z)), n


def build():
    ax.reset_scene()
    spec = [
        ("root", None, (0, 0, 0)),
        ("shell", "root", (0, 0, 0.35)),
        ("head", "shell", (0, 0.7, 0.42)),
        ("leg_fl", "shell", (-0.5, 0.42, 0.34)),
        ("leg_fr", "shell", (0.5, 0.42, 0.34)),
        ("leg_bl", "shell", (-0.5, -0.4, 0.34)),
        ("leg_br", "shell", (0.5, -0.4, 0.34)),
        ("tail", "shell", (0, -0.85, 0.28)),
    ]
    rig = ax.Rig("enemy_heavy", spec)
    m = ax.Mesher()
    # carapace : calotte + ventre + liseré crème
    m.add(ax.dome(1.0, SHELL[2], 20, 7, SHELL_Z, M(scale=(SHELL[0], SHELL[1], 1.0))), "green_dark", "shell")
    m.add(ax.cyl(1.0, 1.0, 0.09, 20, SHELL_Z - 0.09, True, True, M(scale=(SHELL[0] * 1.02, SHELL[1] * 1.02, 1))),
          "cream", "shell", crease=30)
    m.add(ax.cyl(1.0, 0.9, 0.12, 20, 0.12, True, True, M(scale=(SHELL[0] * 0.9, SHELL[1] * 0.9, 1))),
          "olive", "shell", crease=30)
    # plaques hexagonales : une centrale + six autour + deux de bord
    plates = [(0, 0, 0.3)]
    for k in range(6):
        a = math.radians(60 * k + 30)
        plates.append((0.52 * math.sin(a), 0.62 * math.cos(a), 0.26))
    for k in (0, 3):
        a = math.radians(60 * k + 30)
        plates.append((0.78 * math.sin(a) * 0.82, 0.95 * math.cos(a) * 0.74, 0.2))
    plates = plates[:7]
    for x, y, r in plates:
        pos, n = shell_point(x, y)
        m.add(ax.dome(r, 0.07, 6, 2, 0.0, M_align(pos + n * 0.0, n, 0, 1.0)), "lime", "shell", crease=0, grad=0.6)
    # tête, cou, yeux, sourcils, bouche
    m.add(ax.ellipsoid((0.27, 0.3, 0.25), 12, 8, M((0, 1.02, 0.46))), "olive", "head")
    m.add(ax.ellipsoid((0.2, 0.25, 0.2), 8, 5, M((0, 0.76, 0.42))), "olive", "head", crease=0)
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.085, 0.07, 0.095), 8, 5, M((sx * 0.14, 1.24, 0.58))), "white", "head", crease=0)
        m.add(ax.ellipsoid((0.045, 0.03, 0.055), 6, 4, M((sx * 0.14, 1.295, 0.58))), "black", "head", crease=0)
        m.add(ax.box((0.17, 0.05, 0.04), 0.0, 1, M((sx * 0.14, 1.25, 0.69), (0, -sx * 26, 0))), "green_dark", "head", crease=0)
    m.add(ax.ellipsoid((0.13, 0.04, 0.025), 8, 3, M((0, 1.27, 0.4))), "ink", "head", crease=0)
    # pattes (cylindres épais) + griffes
    for side, sx in (("l", -1), ("r", 1)):
        for tag, y in (("f", 0.42), ("b", -0.4)):
            m.add(ax.ellipsoid((0.2, 0.22, 0.22), 10, 6, M((sx * 0.55, y, 0.2))), "olive", f"leg_{tag}{side}", crease=0)
            m.add(ax.ellipsoid((0.2, 0.22, 0.07), 8, 4, M((sx * 0.55, y + 0.06, 0.03))), "cream", f"leg_{tag}{side}", crease=0)
    m.add(ax.cyl(0.1, 0.0, 0.3, 6, 0.0, True, True, M((0, -0.86, 0.27), (-90, 0, 0))), "olive", "tail", crease=0)
    obj = m.build("enemy_heavy", rig=rig)
    animate(rig)
    return obj


def animate(rig):
    def legs(u, cyc, lift, swing):
        out = {}
        for b, ph in (("leg_fl", 0.0), ("leg_br", 0.0), ("leg_fr", 0.5), ("leg_bl", 0.5)):
            sgn = -1 if b.endswith("l") else 1
            out[b] = {
                "rot": (swing * wave(u, cyc, ph + 0.25), 0, 0),
                "loc": (0, 0, lift * max(0.0, wave(u, cyc, ph))),
            }
        return out

    def idle(u, t):
        p = legs(u, 1, 0, 0)
        p["shell"] = {"scale": (1, 1, 1 + 0.03 * wave(u)), "rot": (0, 1.5 * wave(u, 1, 0.2), 0)}
        peek = ease_out(seg(u, 0.55, 0.75)) - smooth(seg(u, 0.85, 1.0))
        p["head"] = {"loc": (0, 0.06 * peek, 0), "rot": (3 * wave(u, 1, 0.3), 8 * wave(u, 1, 0.5), 0)}
        p["tail"] = {"rot": (0, 0, 10 * wave(u, 2))}
        return p

    def run(u, t):
        p = legs(u, 1, 0.07, 22)
        p["root"] = {"loc": (0, 0, 0.025 * abs(wave(u, 2)))}
        p["shell"] = {"rot": (2 * wave(u, 2), 7 * wave(u, 1), 0)}
        p["head"] = {"rot": (4 * wave(u, 2, 0.2), -6 * wave(u, 1), 0), "loc": (0, 0.04 * wave(u, 2, 0.5), 0)}
        p["tail"] = {"rot": (0, 0, 14 * wave(u, 1))}
        return p

    def attack(u, t):
        # 0..0.5 : la tête rentre et la carapace se baisse ; 0.5 : coup de tête ; puis retour
        wind = ease_out(seg(u, 0.0, 0.46))
        strike = seg(u, 0.46, 0.56)
        back = smooth(seg(u, 0.62, 1.0))
        k = wind * (1 - strike) - 1.0 * strike * (1 - back)
        p = legs(u, 1, 0, 0)
        p["head"] = {"loc": (0, -0.3 * k, 0), "scale": (1 - 0.15 * wind * (1 - strike), 1, 1 - 0.15 * wind * (1 - strike))}
        p["shell"] = {"rot": (-5 * wind * (1 - strike) + 4 * strike * (1 - back), 0, 0)}
        p["root"] = {"loc": (0, 0.28 * strike * (1 - back), -0.04 * wind * (1 - strike))}
        return p

    def hit(u, t):
        k = wave(seg(u, 0, 1) * 0.5, 1)
        p = legs(u, 1, 0, 0)
        p["shell"] = {"rot": (-5 * k, 6 * k, 5 * k), "scale": (1 + 0.04 * k, 1 + 0.04 * k, 1 - 0.07 * k)}
        p["head"] = {"loc": (0, -0.12 * k, 0)}
        return p

    def death(u, t):
        flip = ease_out(seg(u, 0.0, 0.55))
        p = {}
        p["shell"] = {"rot": (0, 0, 180 * flip), "loc": (0, 0, 0.18 * math.sin(math.pi * flip))}
        p["head"] = {"loc": (0, -0.1 * flip, 0), "rot": (0, 0, 20 * wave(u, 3) * flip)}
        for b, ph in (("leg_fl", 0.0), ("leg_br", 0.0), ("leg_fr", 0.5), ("leg_bl", 0.5)):
            p[b] = {"rot": (30 * wave(u, 4, ph) * flip, 0, 0)}
        return p

    rig.bake("idle", 1.8, idle, loop=True)
    rig.bake("run", 0.9, run, loop=True)
    rig.bake("attack", 0.9, attack)
    rig.bake("hit", 0.3, hit)
    rig.bake("death", 0.7, death)
    rig.finish()


def main():
    build()
    ax.export("enemy_heavy")


if __name__ == "__main__":
    ax.main_guard(main)
