"""Décors de plage (phase 4) : un GLB par objet, posés par le jeu autour de l'arène (hors de la
zone de jeu). Palmier, parasol, serviette, ballon, château de sable, coquillage, étoile de mer,
rocher, seau et pelle, planche de surf. Budget : 150 à 1 200 triangles chacun."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, M_align  # noqa: E402
from mathutils import Vector  # noqa: E402


def finish(name, m):
    m.build(name)
    ax.export(name)


def sector(c, k):
    return int(((math.degrees(math.atan2(c.x, c.y)) % 360.0) / (360.0 / k)))


def palm():
    ax.reset_scene()
    m = ax.Mesher()
    path = [Vector((0.0, 0.0, 0.0)), Vector((0.12, 0.02, 1.2)), Vector((0.4, 0.1, 2.4)), Vector((0.55, 0.15, 3.6)), Vector((0.45, 0.15, 4.7))]
    rad = [0.3, 0.26, 0.22, 0.19, 0.16]
    m.add(ax.tube(path, rad, 10, 0.0), lambda c, n: "wood_dark" if int(c.z * 5) % 2 == 0 else "wood", crease=0, grad=0.5)
    top = path[-1]
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [top + d * 0.15 + Vector((0, 0, 0.0)), top + d * 1.0 + Vector((0, 0, 0.55)), top + d * 1.9 + Vector((0, 0, 0.5)), top + d * 2.6 + Vector((0, 0, -0.15))]
        m.add(ax.tube(pts, [(0.16, 0.045), (0.34, 0.04), (0.3, 0.035), (0.06, 0.02)], 5, 0.2),
              lambda c, n: "palm_dark" if n.z < -0.2 else "palm", crease=0, grad=0.6)
    for k in range(3):
        a = 2 * math.pi * k / 3
        m.add(ax.ellipsoid((0.17, 0.17, 0.17), 8, 5, M(tuple(top + Vector((0.25 * math.cos(a), 0.25 * math.sin(a), -0.28))))), "wood_dark", crease=0)
    finish("deco_palm", m)


def umbrella():
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.cyl(0.05, 0.05, 2.3, 6, 0.0, True, True), "wood_light", crease=0)
    prof = [(1.62, 1.98), (1.5, 2.05), (1.05, 2.33), (0.55, 2.55), (0.12, 2.62)]  # bas -> haut
    m.add(ax.lathe(prof, 16, M(rot=(0, 0, 0)), True, False), lambda c, n: "red" if sector(c, 8) % 2 == 0 else "white", crease=0, grad=0.7)
    m.add(ax.lathe([(1.62, 1.98), (1.5, 1.94), (1.0, 2.2), (0.2, 2.5)], 16, None, False, False), "white", crease=0, grad=0.5)
    m.add(ax.ellipsoid((0.09, 0.09, 0.09), 6, 4, M((0, 0, 2.66))), "gold", crease=0)
    m.add(ax.dome(0.5, 0.1, 12, 2, 0.0), "sand_dark", crease=0)
    obj = m.build("deco_umbrella")
    obj.rotation_euler = (math.radians(8), 0, 0)
    ax.export("deco_umbrella")


def towel():
    ax.reset_scene()
    m = ax.Mesher()
    for i, col in enumerate(("blue", "white", "yellow", "white", "blue")):
        m.add(ax.box((0.3, 2.3, 0.05), 0.01, 1, M(((i - 2) * 0.3, 0, 0.025))), col, crease=40, grad=0.2)
    for sx in (-0.75, 0.75):
        m.add(ax.box((0.03, 2.4, 0.03), 0.0, 1, M((sx, 0, 0.02))), "white", crease=0)
    finish("deco_towel", m)


def beach_ball():
    ax.reset_scene()
    m = ax.Mesher()
    cols = ["red", "white", "blue", "yellow", "red", "white"]
    m.add(ax.ellipsoid((0.5, 0.5, 0.5), 18, 10, M((0, 0, 0.5))), lambda c, n: "white" if abs(n.z) > 0.93 else cols[sector(c, 6)], crease=0, grad=0.6)
    finish("deco_ball", m)


def sandcastle():
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.cyl(1.0, 0.95, 0.8, 14, 0.0, True, True, M((0, 0, 0), scale=(1.6, 0.7, 1))), "sand", crease=40)
    for x, h, r in ((-1.3, 1.5, 0.55), (1.3, 1.5, 0.55), (0.0, 1.9, 0.62)):
        y = 0.0 if x != 0.0 else -0.3
        m.add(ax.cyl(r, r * 0.88, h, 12, 0.0, True, True, M((x, y, 0))), "sand_light", crease=40)
        m.add(ax.cyl(r + 0.1, r + 0.1, 0.12, 12, h, True, True, M((x, y, 0))), "sand", crease=40)
        for k in range(6):
            a = 2 * math.pi * k / 6
            m.add(ax.box((0.2, 0.14, 0.2), 0.01, 1, M((x + r * 0.95 * math.cos(a), y + r * 0.95 * math.sin(a), h + 0.22), (0, 0, math.degrees(a)))), "sand_light", crease=40)
    m.add(ax.cyl(0.02, 0.02, 0.7, 5, 1.9, True, True, M((0, -0.3, 0))), "wood_light", crease=0)
    m.add(ax.prism([(0, 0), (0.4, -0.12), (0, -0.24)], 0.03, 0.0, 1, M((0, -0.3, 2.45), (90, 0, 90))), "pink", crease=0)
    m.add(ax.dome(0.32, 0.5, 10, 4, 0.0, M((0, 0.62, 0.0))), "wood_dark", crease=0)
    finish("deco_sandcastle", m)


def shell():
    ax.AUTO_ROUND_BELOW = 0  # coquillage : beaucoup de petites pièces, déjà rond ; on garde le budget
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.ellipsoid((0.4, 0.34, 0.12), 12, 6, M((0, 0, 0.1))), "pink_light", crease=0)
    for k in range(7):
        a = math.radians(-60 + k * 20)
        d = Vector((math.sin(a), math.cos(a), 0))
        m.add(ax.ellipsoid((0.035, 0.3, 0.05), 5, 3, M_align(Vector((0, 0, 0.17)) + d * 0.02, (0, 0, 1), -math.degrees(a)) @ M((0, 0.16, 0))), "coral", crease=0)
    m.add(ax.ellipsoid((0.1, 0.07, 0.07), 6, 4, M((0, -0.32, 0.1))), "cream", crease=0)
    finish("deco_shell", m)


def starfish():
    ax.reset_scene()
    m = ax.Mesher()
    for k in range(5):
        a = 2 * math.pi * k / 5
        pts = [Vector((0, 0, 0.07)), Vector((math.sin(a) * 0.22, math.cos(a) * 0.22, 0.07)), Vector((math.sin(a) * 0.5, math.cos(a) * 0.5, 0.045))]
        m.add(ax.tube(pts, [(0.1, 0.06), (0.075, 0.05), (0.02, 0.025)], 6, 0.3), "orange", crease=0)
        m.add(ax.ellipsoid((0.025, 0.025, 0.015), 5, 3, M((math.sin(a) * 0.3, math.cos(a) * 0.3, 0.115))), "yellow", crease=0)
    m.add(ax.ellipsoid((0.14, 0.14, 0.08), 8, 4, M((0, 0, 0.07))), "orange_dark", crease=0)
    finish("deco_starfish", m)


def rock():
    ax.reset_scene()
    m = ax.Mesher()
    for (x, y, z, rx, ry, rz) in ((0, 0, 0.35, 0.8, 0.65, 0.5), (0.7, 0.2, 0.22, 0.5, 0.42, 0.34), (-0.55, -0.35, 0.2, 0.45, 0.4, 0.3)):
        m.add(ax.ellipsoid((rx, ry, rz), 9, 6, M((x, y, z), (0, 0, x * 40))), lambda c, n: "grey_light" if n.z > 0.6 else "grey", crease=60, grad=0.9)
    m.add(ax.ellipsoid((0.3, 0.25, 0.08), 6, 4, M((0.1, 0.05, 0.78))), "green", crease=0)
    finish("deco_rock", m)


def bucket():
    ax.reset_scene()
    m = ax.Mesher()
    m.add(ax.cyl(0.26, 0.36, 0.5, 14, 0.0, True, False), "blue", crease=40)
    m.add(ax.torus(0.36, 0.035, 14, 5, M((0, 0, 0.5))), "blue_dark", crease=0)
    m.add(ax.tube([(-0.36, 0, 0.5), (-0.3, 0, 0.82), (0, 0, 0.95), (0.3, 0, 0.82), (0.36, 0, 0.5)], [0.02] * 5, 5, 0), "grey_dark", crease=0)
    m.add(ax.dome(0.3, 0.08, 12, 2, 0.45), "sand_dark", crease=0)
    # pelle posée
    m.add(ax.tube([(0.6, -0.3, 0.04), (0.9, -0.6, 0.04)], [0.025, 0.025], 5, 0), "red", crease=0)
    m.add(ax.prism([(-0.14, 0.0), (0.14, 0.0), (0.12, -0.28), (0.0, -0.34), (-0.12, -0.28)], 0.03, 0.0, 1, M((0.55, -0.25, 0.05), (0, 0, 40))), "red", crease=0)
    finish("deco_bucket", m)


def surfboard():
    ax.reset_scene()
    m = ax.Mesher()
    def band(c, n):
        z = c.z
        return "yellow" if 1.0 < z < 1.3 else ("teal" if 1.45 < z < 1.7 else "white")
    prof = [(0.0, 0.0), (0.24, 0.35), (0.3, 0.9), (0.29, 1.5), (0.2, 2.0), (0.0, 2.25)]
    m.add(ax.lathe(prof, 12, M((0, 0, 0), (0, 0, 0), (1, 0.14, 1))), band, crease=60, grad=0.3)
    m.add(ax.prism([(0, 0), (0.08, 0.25), (0.0, 0.3)], 0.025, 0.0, 1, M((0, -0.08, 0.1), (90, 0, 90))), "grey_dark", crease=0)
    obj = m.build("deco_surfboard")
    obj.rotation_euler = (math.radians(10), math.radians(-6), 0)
    ax.export("deco_surfboard")


def main():
    # La bibliothèque est partagée : on rétablit l'arrondi automatique entre chaque asset.
    for fn in (palm, umbrella, towel, beach_ball, sandcastle, shell, starfish, rock, bucket, surfboard):
        ax.AUTO_ROUND_BELOW = 8
        fn()


if __name__ == "__main__":
    ax.main_guard(main)
