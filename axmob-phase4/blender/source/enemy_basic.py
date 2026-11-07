"""Ennemi basique : le Crabe rouge (phase 4). Rond, bien lisible de dessus : carapace rouge,
deux pinces crème, yeux sur tiges, six pattes. Budget : 1 200 triangles, 16 os.

    python blender/source/enemy_basic.py
Animations : idle-loop, run-loop, attack (frappe à 50 %), hit, death.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, wave, smooth, ease_out, seg  # noqa: E402


def shell_color(c, n):
    return "orange" if n.z < -0.35 else "red"


def build():
    ax.reset_scene()
    LEGS = [("1", 0.10), ("2", -0.03), ("3", -0.16)]
    spec = [("root", None, (0, 0, 0)), ("body", "root", (0, 0, 0.3))]
    for side, sx in (("l", -1), ("r", 1)):
        spec += [
            (f"claw_{side}", "body", (sx * 0.34, 0.12, 0.38)),
            (f"jaw_{side}", f"claw_{side}", (sx * 0.66, 0.44, 0.42)),
        ]
        for n, y in LEGS:
            spec.append((f"leg_{side}{n}", "body", (sx * 0.30, y, 0.28)))
    rig = ax.Rig("enemy_basic", spec)
    m = ax.Mesher()

    # carapace (deux pièces : dessus bombé, jupe) + taches claires
    m.add(ax.ellipsoid((0.43, 0.35, 0.25), 14, 8, M((0, 0, 0.32))), shell_color, "body")
    for x, y, z, s in ((-0.16, 0.0, 0.52, 0.07), (0.15, -0.05, 0.53, 0.06), (0.0, -0.17, 0.5, 0.05)):
        m.add(ax.ellipsoid((s, s * 1.2, s * 0.5), 6, 3, M((x, y, z))), "coral", "body", crease=0)
    # bouche
    m.add(ax.ellipsoid((0.11, 0.03, 0.035), 8, 4, M((0, 0.355, 0.27))), "ink", "body", crease=0)
    # yeux sur tiges + sourcils
    for sx in (-1, 1):
        m.add(ax.tube([(sx * 0.14, 0.2, 0.5), (sx * 0.15, 0.25, 0.64)], [0.035, 0.03], 5, 0),
              "red_dark", "body", crease=0)
        m.add(ax.ellipsoid((0.085, 0.085, 0.085), 8, 5, M((sx * 0.15, 0.26, 0.7))), "white", "body", crease=0)
        m.add(ax.ellipsoid((0.045, 0.03, 0.05), 6, 4, M((sx * 0.15, 0.335, 0.7))), "black", "body", crease=0)
        m.add(ax.box((0.15, 0.04, 0.035), 0.0, 1, M((sx * 0.15, 0.31, 0.8), (0, -sx * 22, 0))),
              "red_dark", "body", crease=0)

    # pinces (le côté gauche est symétrisé vers la droite)
    sh, el, pm = (-0.34, 0.12, 0.38), (-0.55, 0.27, 0.41), (-0.66, 0.44, 0.42)
    m.add(ax.tube([sh, el, pm], [0.07, 0.065, 0.06], 6, 0.3), "red", "claw_l", mirror_bone="claw_r", crease=0)
    m.add(ax.ellipsoid((0.15, 0.17, 0.13), 8, 5, M(pm)), "red", "claw_l", mirror_bone="claw_r", crease=0)
    up = [(-0.66, 0.47, 0.49), (-0.62, 0.6, 0.52), (-0.55, 0.73, 0.48)]
    m.add(ax.tube(up, [0.075, 0.055, 0.02], 6, 0.2), "cream", "claw_l", mirror_bone="claw_r", crease=0)
    lo = [(-0.66, 0.47, 0.35), (-0.62, 0.59, 0.33), (-0.56, 0.71, 0.37)]
    m.add(ax.tube(lo, [0.07, 0.05, 0.02], 6, 0.2), "cream", "jaw_l", mirror_bone="jaw_r", crease=0)

    # pattes : trois par côté
    for side, sx in (("l", -1), ("r", 1)):
        for n, y in LEGS:
            pts = [(sx * 0.3, y, 0.28), (sx * 0.52, y + 0.04, 0.33), (sx * 0.66, y - 0.03, 0.03)]
            m.add(ax.tube(pts, [0.04, 0.032, 0.022], 5, 0), "red_dark", f"leg_{side}{n}", crease=0)

    obj = m.build("enemy_basic", rig=rig)
    animate(rig)
    return obj


def animate(rig):
    def legs(u, amp_lift, amp_swing, cycles):
        out = {}
        for side, sgn in (("l", 1.0), ("r", -1.0)):
            for i, n in enumerate(("1", "2", "3")):
                phase = 0.5 * ((i + (0 if side == "l" else 1)) % 2)
                s = wave(u, cycles, phase)
                lift = max(0.0, s) * amp_lift * sgn
                swing = wave(u, cycles, phase + 0.25) * amp_swing * sgn
                out[f"leg_{side}{n}"] = {"rot": (0, lift, swing)}
        return out

    def idle(u, t):
        p = legs(u, 0, 0, 1)
        p["body"] = {"scale": (1, 1, 1 + 0.035 * wave(u))}
        snap = max(0.0, wave(u, 2, 0.1)) ** 6
        for side, sgn in (("l", 1), ("r", -1)):
            p[f"claw_{side}"] = {"rot": (6 * wave(u, 1, 0.15 * sgn), 0, sgn * 4 * wave(u))}
            p[f"jaw_{side}"] = {"rot": (-8 - 16 * snap, 0, 0)}
        return p

    def run(u, t):
        p = legs(u, 34, 16, 2)
        bob = abs(wave(u, 2, 0)) * 0.035
        p["root"] = {"loc": (0, 0, bob)}
        p["body"] = {"rot": (3, 3 * wave(u, 2, 0.25), 3 * wave(u, 2))}
        for side, sgn in (("l", 1), ("r", -1)):
            p[f"claw_{side}"] = {"rot": (14 + 9 * wave(u, 2, 0.1 * sgn), 0, sgn * 6 * wave(u, 2))}
            p[f"jaw_{side}"] = {"rot": (-12 + 8 * wave(u, 2, 0.3), 0, 0)}
        return p

    def attack(u, t):
        # 0..0.5 armement (pinces levées, recul), 0.5 coup, ensuite relâchement
        wind = ease_out(seg(u, 0.0, 0.46))
        strike = seg(u, 0.46, 0.56)
        back = smooth(seg(u, 0.6, 1.0))
        k = wind * (1 - strike) + strike * (1 - back) * -0.55
        p = legs(u, 0, 0, 1)
        p["root"] = {"loc": (0, 0.2 * strike * (1 - back) - 0.05 * wind * (1 - strike), 0)}
        p["body"] = {"rot": (14 * wind * (1 - strike) - 8 * strike * (1 - back), 0, 0)}
        for side, sgn in (("l", 1), ("r", -1)):
            p[f"claw_{side}"] = {"rot": (70 * k, 0, sgn * (-10 * wind))}
            open_ = 38 * wind * (1 - strike)
            p[f"jaw_{side}"] = {"rot": (-open_ - 6, 0, 0)}
        return p

    def hit(u, t):
        k = wave(seg(u, 0, 1) * 0.5, 1)  # 0 -> 1 -> 0
        p = legs(u, 0, 0, 1)
        p["body"] = {"rot": (-12 * k, 5 * k, 0), "scale": (1 + 0.1 * k, 1 + 0.1 * k, 1 - 0.18 * k)}
        for side, sgn in (("l", 1), ("r", -1)):
            p[f"claw_{side}"] = {"rot": (-30 * k, 0, sgn * 18 * k)}
        return p

    def death(u, t):
        flip = ease_out(seg(u, 0.0, 0.5))
        curl = smooth(seg(u, 0.3, 1.0))
        p = {}
        p["root"] = {"rot": (0, 0, 0), "loc": (0, 0, 0.1 * wave(flip * 0.5, 1) )}
        p["body"] = {"rot": (0, 180 * flip, 0), "loc": (0, 0, 0)}
        for side, sgn in (("l", 1), ("r", -1)):
            for n in ("1", "2", "3"):
                p[f"leg_{side}{n}"] = {"rot": (0, -sgn * 55 * curl + sgn * 8 * wave(u, 3), 0)}
            p[f"claw_{side}"] = {"rot": (-25 * curl, 0, sgn * 25 * curl)}
        return p

    rig.bake("idle", 1.4, idle, loop=True)
    rig.bake("run", 0.5, run, loop=True)
    rig.bake("attack", 0.7, attack)
    rig.bake("hit", 0.25, hit)
    rig.bake("death", 0.5, death)
    rig.finish()


def main():
    build()
    ax.export("enemy_basic")


if __name__ == "__main__":
    ax.main_guard(main)
