"""Ennemi rapide : la Crevette rose (phase 4). Corps allongé et arqué, bien distinct du crabe
rond. Budget : 1 000 triangles, 16 os. Animations : idle-loop, run-loop, attack, hit, death."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, wave, smooth, ease_out, seg  # noqa: E402


def body_color(c, n):
    return "cream" if n.z < -0.45 else "pink"


def build():
    ax.reset_scene()
    spec = [
        ("root", None, (0, 0, 0)),
        ("body", "root", (0, 0.1, 0.35)),
        ("seg1", "body", (0, 0.0, 0.36)),
        ("seg2", "seg1", (0, -0.2, 0.34)),
        ("seg3", "seg2", (0, -0.4, 0.30)),
        ("tail", "seg3", (0, -0.58, 0.25)),
        ("ant_l", "body", (-0.07, 0.45, 0.5)),
        ("ant_r", "body", (0.07, 0.45, 0.5)),
        ("legs_l", "body", (-0.12, 0.15, 0.22)),
        ("legs_r", "body", (0.12, 0.15, 0.22)),
    ]
    rig = ax.Rig("enemy_fast", spec)
    m = ax.Mesher()
    m.add(ax.ellipsoid((0.21, 0.31, 0.22), 12, 8, M((0, 0.22, 0.38))), body_color, "body")
    m.add(ax.ellipsoid((0.19, 0.17, 0.2), 10, 6, M((0, -0.1, 0.37))), "coral", "seg1")
    m.add(ax.ellipsoid((0.17, 0.16, 0.18), 10, 6, M((0, -0.3, 0.33))), "pink", "seg2")
    m.add(ax.ellipsoid((0.15, 0.15, 0.16), 10, 6, M((0, -0.48, 0.28))), "coral", "seg3")
    # éventail de queue
    m.add(ax.ellipsoid((0.075, 0.2, 0.022), 8, 4, M((0, -0.77, 0.19), (-14, 0, 0))), "pink_dark", "tail", crease=0)
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.065, 0.17, 0.02), 8, 4, M((sx * 0.1, -0.73, 0.2), (-10, 0, sx * 32))),
              "pink_dark", "tail", crease=0)
    # rostre, yeux
    m.add(ax.tube([(0, 0.42, 0.46), (0, 0.66, 0.56)], [0.05, 0.012], 5, 0), "pink_dark", "body", crease=0)
    for sx in (-1, 1):
        m.add(ax.ellipsoid((0.075, 0.075, 0.075), 8, 5, M((sx * 0.13, 0.43, 0.5))), "black", "body", crease=0)
        # Reflet cartoon dans la pupille (le regard « vit »)
        m.add(ax.ellipsoid((0.034, 0.017, 0.034), 6, 4, M((sx * 0.13 + 0.024, 0.486, 0.530))), "white", "body", crease=0)
        m.add(ax.ellipsoid((0.026, 0.026, 0.026), 5, 3, M((sx * 0.15, 0.49, 0.54))), "white", "body", crease=0)
        m.add(ax.box((0.13, 0.035, 0.03), 0.0, 1, M((sx * 0.13, 0.46, 0.6), (0, -sx * 24, 0))),
              "ink", "body", crease=0)
    # antennes (longues, fines, orientées vers l'avant)
    for side, sx in (("l", -1), ("r", 1)):
        pts = [(sx * 0.07, 0.45, 0.5), (sx * 0.16, 0.7, 0.6), (sx * 0.34, 0.93, 0.56), (sx * 0.56, 1.02, 0.46)]
        m.add(ax.tube(pts, [0.02, 0.016, 0.012, 0.007], 4, 0), "pink_dark", f"ant_{side}", crease=0)
    # petites pattes sous la carapace
    for side, sx in (("l", -1), ("r", 1)):
        for y in (0.32, 0.2, 0.08):
            pts = [(sx * 0.13, y, 0.24), (sx * 0.27, y + 0.03, 0.12), (sx * 0.3, y - 0.01, 0.0)]
            m.add(ax.tube(pts, [0.03, 0.024, 0.016], 4, 0), "pink_dark", f"legs_{side}", crease=0)
    obj = m.build("enemy_fast", rig=rig)
    animate(rig)
    return obj


def animate(rig):
    def chain(u, cyc, amp, pitch, lag=0.12):
        out = {}
        for i, b in enumerate(("seg1", "seg2", "seg3", "tail")):
            out[b] = {"rot": (pitch * wave(u, cyc * 2, -lag * i), 0, amp * (1 + 0.35 * i) * wave(u, cyc, -lag * i))}
        return out

    def legs(u, cyc, amp):
        return {
            "legs_l": {"rot": (amp * wave(u, cyc, 0.0), 0, 0)},
            "legs_r": {"rot": (amp * wave(u, cyc, 0.5), 0, 0)},
        }

    def idle(u, t):
        p = chain(u, 1, 5, 3)
        p.update(legs(u, 2, 6))
        p["body"] = {"scale": (1, 1, 1 + 0.03 * wave(u))}
        p["ant_l"] = {"rot": (0, 0, 8 * wave(u, 1, 0.0))}
        p["ant_r"] = {"rot": (0, 0, -8 * wave(u, 1, 0.3))}
        return p

    def run(u, t):
        p = chain(u, 2, 9, 7)
        p.update(legs(u, 4, 30))
        p["root"] = {"loc": (0, 0, 0.03 * abs(wave(u, 2)))}
        p["body"] = {"rot": (4 * wave(u, 4), 0, 3 * wave(u, 2, 0.25))}
        p["ant_l"] = {"rot": (6 * wave(u, 2), 0, 12 * wave(u, 2, 0.1))}
        p["ant_r"] = {"rot": (6 * wave(u, 2, 0.4), 0, -12 * wave(u, 2, 0.2))}
        return p

    def attack(u, t):
        wind = ease_out(seg(u, 0.0, 0.46))
        strike = seg(u, 0.46, 0.56)
        back = smooth(seg(u, 0.6, 1.0))
        curl = wind * (1 - strike) - 0.35 * strike * (1 - back)
        p = {}
        for b in ("seg1", "seg2", "seg3", "tail"):
            p[b] = {"rot": (-22 * curl, 0, 0)}
        p["root"] = {"loc": (0, 0.35 * strike * (1 - back) - 0.08 * wind * (1 - strike), -0.05 * wind * (1 - strike))}
        p["body"] = {"rot": (-10 * wind * (1 - strike) + 10 * strike * (1 - back), 0, 0)}
        p["ant_l"] = {"rot": (-25 * strike, 0, 0)}
        p["ant_r"] = {"rot": (-25 * strike, 0, 0)}
        return p

    def hit(u, t):
        k = wave(seg(u, 0, 1) * 0.5, 1)
        p = chain(u, 1, 0, 0)
        p["body"] = {"rot": (-8 * k, 0, 16 * k), "scale": (1 - 0.1 * k, 1 + 0.12 * k, 1 - 0.1 * k)}
        for b in ("seg1", "seg2", "seg3", "tail"):
            p[b] = {"rot": (0, 0, -20 * k)}
        return p

    def death(u, t):
        roll = ease_out(seg(u, 0.0, 0.45))
        curl = smooth(seg(u, 0.2, 0.8))
        p = {}
        p["body"] = {"rot": (0, 90 * roll, 0)}
        for b in ("seg1", "seg2", "seg3", "tail"):
            p[b] = {"rot": (-24 * curl, 0, 0)}
        p["legs_l"] = {"rot": (30 * wave(u, 3), 0, 0)}
        p["legs_r"] = {"rot": (-30 * wave(u, 3), 0, 0)}
        return p

    rig.bake("idle", 1.2, idle, loop=True)
    rig.bake("run", 0.4, run, loop=True)
    rig.bake("attack", 0.6, attack)
    rig.bake("hit", 0.25, hit)
    rig.bake("death", 0.5, death)
    rig.finish()


def main():
    build()
    ax.export("enemy_fast")


if __name__ == "__main__":
    ax.main_guard(main)
