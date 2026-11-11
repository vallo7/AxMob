"""Boss : le Kraken (poulpe géant couronné, phase 4). Six tentacules à trois os, grosse tête
bleue, yeux furieux, couronne d'or. Budget : 7 000 triangles, 24 os.
Animations : idle-loop, run-loop, attack (écrasement, frappe à 50 %), charge_windup,
charge-loop, roar, hit, death."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, M_align, axis_rot, wave, smooth, ease_out, seg  # noqa: E402
from mathutils import Vector  # noqa: E402

ANGLES = [-35, 35, -90, 90, -145, 145]  # degrés depuis l'avant (+Y) vers +X
PATH = [(0.5, 0.52, 0.0), (0.76, 0.38, 0.05), (1.02, 0.27, 0.12), (1.3, 0.22, 0.09), (1.58, 0.28, -0.09), (1.84, 0.46, -0.2)]
RADII = [0.27, 0.24, 0.2, 0.15, 0.1, 0.04]
HEAD = (1.0, 0.95, 0.95)
HEAD_Z = 1.25


def dirs(a):
    r = math.radians(a)
    return Vector((math.sin(r), math.cos(r), 0)), Vector((math.cos(r), -math.sin(r), 0))


def tentacle_points(i):
    d, perp = dirs(ANGLES[i])
    sgn = 1 if i % 2 == 0 else -1
    return [d * r + perp * lat * sgn + Vector((0, 0, z)) for r, z, lat in PATH]


def head_color(c, n):
    return "blue_light" if n.z < -0.55 else "blue"


def tent_color(c, n):
    if math.hypot(c.x, c.y) > 1.75:
        return "pink"
    return "blue_light" if n.z < -0.35 else "blue"


def build():
    ax.reset_scene()
    spec = [("root", None, (0, 0, 0)), ("body", "root", (0, 0, 0.7))]
    for i in range(6):
        pts = tentacle_points(i)
        spec += [(f"t{i}a", "body", tuple(pts[0])), (f"t{i}b", f"t{i}a", tuple(pts[2])), (f"t{i}c", f"t{i}b", tuple(pts[4]))]
    rig = ax.Rig("enemy_boss", spec)
    m = ax.Mesher()
    m.add(ax.ellipsoid(HEAD, 20, 12, M((0, 0, HEAD_Z))), head_color, "body")
    m.add(ax.ellipsoid((0.9, 0.86, 0.72), 18, 10, M((0, -0.04, HEAD_Z + 0.5))), "blue", "body", crease=0)
    # taches claires sur le dessus du crâne
    for d in ax.fibonacci_sphere(30):
        if d.z < 0.35 or d.y > 0.55:
            continue
        p = Vector((0, -0.04, HEAD_Z + 0.5)) + Vector((d.x * 0.88, d.y * 0.84, d.z * 0.72 * 0.98))
        m.add(ax.ellipsoid((0.11, 0.11, 0.035), 6, 3, M_align(p, d)), "blue_light", "body", crease=0, grad=0.5)
    # yeux, sourcils, bouche, dents
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.25, 0.15, 0.3), 10, 6, M((sx * 0.4, 0.8, 1.38))), "white", "body", crease=0)
        m.add(ax.ellipsoid((0.12, 0.07, 0.15), 8, 5, M((sx * 0.4, 0.93, 1.38))), "black", "body", crease=0)
        # Reflet cartoon dans la pupille (le regard « vit »)
        m.add(ax.ellipsoid((0.068, 0.034, 0.068), 6, 4, M((sx * 0.4 + 0.038, 0.983, 1.440))), "white", "body", crease=0)
        m.add(ax.ellipsoid((0.04, 0.03, 0.05), 5, 3, M((sx * 0.45, 0.99, 1.45))), "white", "body", crease=0)
        m.add(ax.box((0.5, 0.09, 0.1), 0.02, 1, M((sx * 0.4, 0.82, 1.68), (0, -sx * 24, 0))), "navy", "body", crease=0)
    m.add(ax.ellipsoid((0.26, 0.07, 0.1), 10, 5, M((0, 0.94, 0.92))), "ink", "body", crease=0)
    for sx in (-1, 1):
        m.add(ax.cyl(0.05, 0.0, 0.12, 5, 0.0, True, True, M((sx * 0.1, 0.99, 0.97), (180, 0, 0))), "white", "body", crease=0)
    # couronne
    top = HEAD_Z + 0.5 + 0.72 - 0.06
    m.add(ax.cyl(0.5, 0.44, 0.2, 16, top - 0.1, True, True), "gold", "body", crease=30)
    for k in range(6):
        a = 2 * math.pi * k / 6
        m.add(ax.cyl(0.1, 0.0, 0.38, 5, 0.0, True, True, M((0.45 * math.sin(a), 0.45 * math.cos(a) - 0.04, top + 0.22))),
              "gold", "body", crease=0)
    m.add(ax.ellipsoid((0.09, 0.09, 0.09), 6, 4, M((0, 0.48, top + 0.08))), "red", "body", crease=0)
    # tentacules : poids fondus entre les trois os
    for i in range(6):
        pts = tentacle_points(i)
        lens = [0.0]
        for a, b in zip(pts, pts[1:]):
            lens.append(lens[-1] + (b - a).length)
        tb, tc = lens[2] / lens[-1], lens[4] / lens[-1]
        m.add(ax.tube(pts, RADII, 12, 0.6), tent_color, None, weights_t=[(f"t{i}a", 0.0), (f"t{i}b", tb), (f"t{i}c", tc)], crease=0)
    obj = m.build("enemy_boss", rig=rig)
    animate(rig)
    return obj


def curl(i, deg):
    """Relève (+) ou abaisse (-) le tentacule i autour de l'axe horizontal perpendiculaire."""
    return axis_rot(dirs(ANGLES[i])[1], deg)


def add_rot(a, b):
    return tuple(x + y for x, y in zip(a, b))


def tent_pose(i, c_a, c_b, c_c, s_a=0.0, s_b=0.0, s_c=0.0):
    return {
        f"t{i}a": {"rot": add_rot(curl(i, c_a), (0, 0, s_a))},
        f"t{i}b": {"rot": add_rot(curl(i, c_b), (0, 0, s_b))},
        f"t{i}c": {"rot": add_rot(curl(i, c_c), (0, 0, s_c))},
    }


def animate(rig):
    def wavy(u, cyc, ca, cb, cc, sa, sb, sc, lag=0.1):
        out = {}
        for i in range(6):
            ph = ANGLES[i] / 360.0 * 1.0
            out.update(tent_pose(
                i,
                ca * wave(u, cyc, ph),
                cb * wave(u, cyc, ph - lag),
                cc * wave(u, cyc, ph - 2 * lag),
                sa * wave(u, cyc, ph + 0.25),
                sb * wave(u, cyc, ph + 0.25 - lag),
                sc * wave(u, cyc, ph + 0.25 - 2 * lag),
            ))
        return out

    def idle(u, t):
        p = wavy(u, 1, 5, 8, 12, 4, 7, 10)
        p["body"] = {"scale": (1, 1, 1 + 0.025 * wave(u)), "loc": (0, 0, 0.02 * wave(u, 1, 0.25))}
        return p

    def run(u, t):
        p = wavy(u, 2, 14, 22, 30, 8, 14, 20, 0.08)
        p["root"] = {"loc": (0, 0, 0.05 * abs(wave(u, 2)))}
        p["body"] = {"rot": (3 * wave(u, 2, 0.25), 3 * wave(u, 2), 0)}
        return p

    def attack(u, t):
        wind = ease_out(seg(u, 0.0, 0.46))
        strike = seg(u, 0.46, 0.54)
        back = smooth(seg(u, 0.62, 1.0))
        k = wind * (1 - strike) - 0.45 * strike * (1 - back)
        p = {}
        for i in range(6):
            front = 1.0 if abs(ANGLES[i]) < 100 else 0.35
            p.update(tent_pose(i, 38 * k * front, 52 * k * front, 60 * k * front, 0, 0, 0))
        p["root"] = {"loc": (0, 0.0, 0.45 * wind * (1 - strike) - 0.1 * strike * (1 - back))}
        p["body"] = {"rot": (-12 * wind * (1 - strike) + 9 * strike * (1 - back), 0, 0),
                     "scale": (1 + 0.06 * strike * (1 - back), 1 + 0.06 * strike * (1 - back), 1 - 0.1 * strike * (1 - back))}
        return p

    def charge_windup(u, t):
        k = ease_out(seg(u, 0.0, 0.5))
        p = {}
        for i in range(6):
            p.update(tent_pose(i, -10 * k, -18 * k, -26 * k, 6 * wave(u, 6) * k, 0, 0))
        p["root"] = {"loc": (0, -0.12 * k, -0.18 * k)}
        p["body"] = {"rot": (-8 * k, 3 * wave(u, 9) * k, 0), "scale": (1 + 0.05 * k, 1 + 0.05 * k, 1 - 0.1 * k)}
        return p

    def charge(u, t):
        p = {}
        for i in range(6):
            fwd = math.cos(math.radians(ANGLES[i]))
            p.update(tent_pose(i, -8 * fwd + 6 * wave(u, 2, i * 0.1), -14 * fwd + 10 * wave(u, 2, i * 0.1 - 0.1),
                               -22 * fwd + 14 * wave(u, 2, i * 0.1 - 0.2), 5 * wave(u, 4, i * 0.1)))
        p["root"] = {"loc": (0, 0.0, 0.04 * abs(wave(u, 4)))}
        p["body"] = {"rot": (10, 0, 2 * wave(u, 4))}
        return p

    def roar(u, t):
        k = math.sin(math.pi * seg(u, 0.0, 1.0))
        p = {}
        for i in range(6):
            p.update(tent_pose(i, 28 * k, 40 * k, 50 * k, (6 if i % 2 == 0 else -6) * wave(u, 6) * k, 0, 0))
        s = 1 + 0.12 * k
        p["body"] = {"rot": (-12 * k, 2 * wave(u, 10) * k, 0), "scale": (s, s, s)}
        p["root"] = {"loc": (0, 0, 0.2 * k)}
        return p

    def hit(u, t):
        k = wave(seg(u, 0, 1) * 0.5, 1)
        p = {}
        for i in range(6):
            p.update(tent_pose(i, -10 * k, -14 * k, -18 * k))
        p["body"] = {"rot": (-6 * k, 0, 4 * k), "scale": (1 + 0.05 * k, 1 + 0.05 * k, 1 - 0.09 * k)}
        return p

    def death(u, t):
        fall = ease_out(seg(u, 0.0, 0.7))
        p = {}
        for i in range(6):
            p.update(tent_pose(i, 25 * fall * (1 - 0.5 * fall) + 12 * wave(u, 3, i * 0.15) * (1 - fall),
                               50 * fall, 80 * fall, 0, 0, 0))
        p["body"] = {"scale": (1 + 0.18 * fall, 1 + 0.18 * fall, 1 - 0.65 * fall), "rot": (0, 0, 10 * wave(u, 4) * (1 - fall))}
        p["root"] = {"loc": (0, 0, -0.18 * fall)}
        return p

    rig.bake("idle", 2.0, idle, loop=True)
    rig.bake("run", 0.8, run, loop=True)
    rig.bake("attack", 1.4, attack)
    rig.bake("charge_windup", 0.8, charge_windup)
    rig.bake("charge", 0.4, charge, loop=True)
    rig.bake("roar", 1.0, roar)
    rig.bake("hit", 0.3, hit)
    rig.bake("death", 1.6, death)
    rig.finish()


def main():
    build()
    ax.export("enemy_boss")


if __name__ == "__main__":
    ax.main_guard(main)
