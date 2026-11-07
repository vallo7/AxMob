"""Ennemi élite : le Poisson-globe violet (phase 4). Boule hérissée d'épines dorées, couronne
d'or : silhouette radicalement différente des autres et lisible de loin. Budget : 2 500
triangles, 16 os. Animations : idle-loop, run-loop (bonds), attack (gonflage + ruée), hit, death."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, M_align, wave, smooth, ease_out, seg  # noqa: E402
from mathutils import Vector  # noqa: E402

BODY = (0.52, 0.5, 0.5)
CENTER = Vector((0, 0, 0.62))


def body_color(c, n):
    return "cream" if n.z < -0.4 else "purple"


def build():
    ax.reset_scene()
    spec = [
        ("root", None, (0, 0, 0)),
        ("body", "root", (0, 0, 0.62)),
        ("fin_l", "body", (-0.5, 0.1, 0.62)),
        ("fin_r", "body", (0.5, 0.1, 0.62)),
        ("tail", "body", (0, -0.5, 0.62)),
        ("foot_l", "body", (-0.2, 0.0, 0.3)),
        ("foot_r", "body", (0.2, 0.0, 0.3)),
    ]
    rig = ax.Rig("enemy_elite", spec)
    m = ax.Mesher()
    m.add(ax.ellipsoid(BODY, 16, 10, M(tuple(CENTER))), body_color, "body")
    # épines dorées réparties sur la sphère (pas sur le visage ni sous le ventre)
    for d in ax.fibonacci_sphere(34):
        if d.y > 0.5 or d.z < -0.45:
            continue
        p = CENTER + Vector((d.x * BODY[0], d.y * BODY[1], d.z * BODY[2])) * 0.93
        m.add(ax.cyl(0.062, 0.0, 0.24, 5, 0.0, True, True, M_align(p, d)), "gold", "body", crease=0, grad=0.8)
    # visage : yeux, sourcils furieux, bouche, joues
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.13, 0.09, 0.14), 8, 5, M((sx * 0.22, 0.43, 0.78))), "white", "body", crease=0)
        m.add(ax.ellipsoid((0.065, 0.05, 0.08), 6, 4, M((sx * 0.22, 0.5, 0.78))), "black", "body", crease=0)
        m.add(ax.box((0.24, 0.05, 0.06), 0.0, 1, M((sx * 0.22, 0.45, 0.93), (0, -sx * 28, 0))), "purple_dark", "body", crease=0)
        m.add(ax.ellipsoid((0.07, 0.03, 0.05), 6, 3, M((sx * 0.34, 0.4, 0.58))), "pink", "body", crease=0)
    m.add(ax.ellipsoid((0.11, 0.05, 0.075), 8, 4, M((0, 0.5, 0.52))), "orange_dark", "body", crease=0)
    m.add(ax.ellipsoid((0.06, 0.03, 0.04), 6, 3, M((0, 0.54, 0.52))), "ink", "body", crease=0)
    # nageoires, queue
    for side, sx in (("l", -1), ("r", 1)):
        m.add(ax.ellipsoid((0.24, 0.05, 0.14), 8, 4, M((sx * 0.7, 0.1, 0.62), (0, sx * 18, sx * -25))),
              "purple_light", f"fin_{side}", crease=0)
    m.add(ax.ellipsoid((0.035, 0.26, 0.24), 6, 4, M((0, -0.72, 0.66))), "purple_light", "tail", crease=0)
    # pieds orange
    for side, sx in (("l", -1), ("r", 1)):
        m.add(ax.ellipsoid((0.11, 0.16, 0.1), 8, 5, M((sx * 0.2, 0.05, 0.1))), "orange", f"foot_{side}", crease=0)
        m.add(ax.cyl(0.065, 0.065, 0.22, 6, 0.1, True, False, M((sx * 0.2, 0.0, 0.0))), "orange", f"foot_{side}", crease=0)
    # couronne
    top = CENTER.z + BODY[2] - 0.05
    m.add(ax.cyl(0.21, 0.19, 0.1, 10, top, True, True), "gold", "body", crease=30)
    for k in range(5):
        a = 2 * math.pi * k / 5
        m.add(ax.cyl(0.055, 0.0, 0.17, 5, 0.0, True, True, M((0.17 * math.sin(a), 0.17 * math.cos(a), top + 0.08))),
              "gold", "body", crease=0)
    m.add(ax.ellipsoid((0.05, 0.05, 0.05), 6, 4, M((0, 0.2, top + 0.06))), "red", "body", crease=0)
    obj = m.build("enemy_elite", rig=rig)
    animate(rig)
    return obj


def animate(rig):
    def fins(u, cyc, amp, base=0):
        return {
            "fin_l": {"rot": (0, base + amp * wave(u, cyc), 0)},
            "fin_r": {"rot": (0, -(base + amp * wave(u, cyc)), 0)},
        }

    def idle(u, t):
        p = fins(u, 1, 14, 6)
        s = 1 + 0.04 * wave(u)
        p["body"] = {"scale": (s, s, s)}
        p["tail"] = {"rot": (0, 0, 10 * wave(u, 1, 0.2))}
        p["root"] = {"loc": (0, 0, 0.02 * wave(u, 1, 0.5))}
        p["foot_l"] = {"rot": (0, 0, 0)}
        return p

    def run(u, t):
        hop = abs(wave(u, 1, 0.0) * 0.5 + 0.0)  # deux bonds par boucle
        h = abs(math.sin(math.pi * u * 2))
        p = fins(u, 4, 30, 8)
        p["root"] = {"loc": (0, 0, 0.16 * h)}
        land = max(0.0, 1.0 - h * 6.0)  # écrasement à l'atterrissage
        p["body"] = {"scale": (1 + 0.07 * land, 1 + 0.07 * land, 1 - 0.12 * land), "rot": (-5 * h, 4 * wave(u, 2), 0)}
        p["tail"] = {"rot": (0, 0, 16 * wave(u, 4))}
        p["foot_l"] = {"rot": (40 * wave(u, 2), 0, 0)}
        p["foot_r"] = {"rot": (-40 * wave(u, 2), 0, 0)}
        return p

    def attack(u, t):
        wind = ease_out(seg(u, 0.0, 0.46))
        strike = seg(u, 0.46, 0.55)
        back = smooth(seg(u, 0.6, 1.0))
        inflate = 1 + 0.4 * wind * (1 - strike) + 0.0
        s = inflate - 0.1 * strike * (1 - back)
        shake = 0.02 * wave(u, 14) * wind * (1 - strike)
        p = fins(u, 1, 0, 25 * wind)
        p["body"] = {"scale": (s + shake, s - shake, s)}
        p["root"] = {"loc": (0, 0.4 * strike * (1 - back), 0.06 * wind * (1 - strike))}
        p["tail"] = {"rot": (0, 0, 20 * wave(u, 6) * wind)}
        return p

    def hit(u, t):
        k = wave(seg(u, 0, 1) * 0.5, 1)
        p = fins(u, 1, 0, 30 * k)
        p["body"] = {"rot": (-10 * k, 0, 14 * k), "scale": (1 - 0.08 * k, 1 + 0.1 * k, 1 - 0.08 * k)}
        return p

    def death(u, t):
        puff = ease_out(seg(u, 0.0, 0.35))
        pop = smooth(seg(u, 0.35, 0.55))
        s = 1 + 0.45 * puff
        p = fins(u, 1, 0, -20 * pop)
        p["body"] = {
            "scale": (s * (1 + 0.2 * pop), s * (1 + 0.2 * pop), s * (1 - 0.8 * pop)),
            "rot": (0, 0, 40 * ease_out(seg(u, 0.35, 1.0))),
        }
        p["tail"] = {"rot": (0, 0, 20 * wave(u, 3) * (1 - pop))}
        return p

    rig.bake("idle", 1.2, idle, loop=True)
    rig.bake("run", 0.6, run, loop=True)
    rig.bake("attack", 0.8, attack)
    rig.bake("hit", 0.3, hit)
    rig.bake("death", 0.6, death)
    rig.finish()


def main():
    build()
    ax.export("enemy_elite")


if __name__ == "__main__":
    ax.main_guard(main)
