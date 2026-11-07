"""Les quatre tourelles lance-haches (phase 4), sur le thème plage :
  turret_rapid  — seau de sable orange, double canon      (cadence élevée)
  turret_heavy  — tonneau en bois, gros canon              (dégâts élevés)
  turret_multi  — château de sable, éventail de canons     (groupes)
  turret_pierce — piédestal de pierre, défense de narval   (perforation)
Chaque GLB contient : Base (fixe), Pivot (tourne) > Head, Barrel (recule) > Muzzle, et les
pièces de palier Tier_1 (enfant de Base), Tier_2 et Tier_3 (enfants de Pivot), visibles aux
niveaux 4, 7 et 10 (plan §6.2). Budget : 3 500 triangles tous paliers confondus."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
from ax import M, M_align, wave  # noqa: E402
from mathutils import Vector  # noqa: E402


def mound(m, bone=None, r=1.05, h=0.14):
    """Petit tas de sable au pied de la tourelle (ancre le modèle dans le décor)."""
    m.add(ax.dome(r, h, 20, 3, 0.0, M(scale=(1, 1, 1))), "sand_dark", bone, crease=0, grad=0.5)


def assemble(name, base, head, barrel, tiers, barrel_origin, muzzle_y):
    ax.reset_scene()
    root = ax.empty(name, kind="CUBE", size=0.2)
    base_obj = base().build("Base", parent=root)
    pivot = ax.empty("Pivot", parent=root)
    head().build("Head", parent=pivot)
    barrel_obj = barrel().build("Barrel", parent=pivot, origin=barrel_origin)
    ax.empty("Muzzle", loc=(0, muzzle_y, 0), parent=barrel_obj, kind="SPHERE", size=0.08)
    t1, t2, t3 = tiers()
    t1.build("Tier_1", parent=base_obj)
    t2.build("Tier_2", parent=pivot)
    t3.build("Tier_3", parent=pivot)
    ax.export(name)


def turntable(m, z, r, color, h=0.14):
    m.add(ax.cyl(r, r * 0.94, h, 18, z, True, True), color, None, crease=30)


def tube_y(m, x, z, y0, y1, r, color, bone=None):
    """Canon horizontal le long de +Y."""
    m.add(ax.cyl(r, r, y1 - y0, 10, y0, True, True, M((x, 0, z), (-90, 0, 0)) @ M()), color, bone, crease=30)


def barrel_cyl(m, x, z, y0, y1, r0, r1, color):
    # lathe vertical -> couché : (-90° autour de X) envoie +Z vers +Y
    m.add(ax.cyl(r0, r1, y1 - y0, 12, 0.0, True, True, M((x, y0, z), (-90, 0, 0))), color, None, crease=30)


# ----------------------------------------------------------------------------------- rapide
def rapid():
    def base():
        m = ax.Mesher()
        mound(m)
        prof = [(0.74, 0.04), (0.78, 0.2), (0.805, 0.32), (0.835, 0.44), (0.855, 0.52), (0.92, 0.76)]
        m.add(ax.lathe(prof, 20, None, True, True), lambda c, n: "yellow" if 0.3 < c.z < 0.46 else "orange", None, crease=40)
        m.add(ax.torus(0.92, 0.055, 20, 6, M((0, 0, 0.76))), "yellow", None, crease=0)
        m.add(ax.cyl(0.84, 0.84, 0.05, 20, 0.74, True, True), "orange_dark", None, crease=30)
        return m

    def head():
        m = ax.Mesher()
        turntable(m, 0.76, 0.56, "teal_dark")
        m.add(ax.ellipsoid((0.5, 0.56, 0.4), 16, 9, M((0, -0.02, 1.02))), "teal")
        m.add(ax.ellipsoid((0.2, 0.2, 0.06), 8, 4, M((0, -0.1, 1.4))), "white", crease=0)
        return m

    def barrel():
        m = ax.Mesher()
        for x in (-0.15, 0.15):
            barrel_cyl(m, x, 1.02, 0.28, 1.0, 0.1, 0.095, "steel")
            barrel_cyl(m, x, 1.02, 0.92, 1.06, 0.135, 0.135, "orange")
        return m

    def tiers():
        a, b, c = ax.Mesher(), ax.Mesher(), ax.Mesher()
        # palier 1 : fanion et guirlande de coquillages sur le seau
        a.add(ax.cyl(0.03, 0.03, 1.0, 6, 0.7, True, True, M((0.62, -0.6, 0))), "wood_light", None, crease=0)
        a.add(ax.prism([(0, 0), (0.42, -0.14), (0, -0.28)], 0.03, 0.0, 1, M((0.62, -0.6, 1.5), (90, 0, 90))), "red", None, crease=0)
        for k in range(8):
            ang = 2 * math.pi * k / 8
            a.add(ax.ellipsoid((0.07, 0.05, 0.05), 6, 4, M((0.93 * math.sin(ang), 0.93 * math.cos(ang), 0.5))), "coral", None, crease=0)
        # palier 2 : carquois latéraux avec manches de haches
        for sx in (-1, 1):
            b.add(ax.cyl(0.13, 0.13, 0.5, 10, 0.0, True, True, M((sx * 0.55, -0.2, 0.95), (-60, 0, 0))), "orange_dark", None, crease=30)
            b.add(ax.cyl(0.14, 0.14, 0.05, 10, 0.0, True, True, M((sx * 0.55, -0.3, 1.05), (-60, 0, 0))), "gold", None, crease=30)
            for dx in (-0.05, 0.05):
                b.add(ax.cyl(0.025, 0.025, 0.3, 5, 0.0, True, True, M((sx * 0.55 + dx, -0.38, 1.25), (-60, 0, 0))), "wood_light", None, crease=0)
        # palier 3 : soleil doré
        c.add(ax.cyl(0.2, 0.2, 0.05, 14, 1.4, True, True), "gold", None, crease=30)
        for k in range(10):
            ang = 2 * math.pi * k / 10
            c.add(ax.cyl(0.05, 0.0, 0.17, 5, 0.0, True, True, M_align((0.27 * math.sin(ang), -0.1 + 0.27 * math.cos(ang), 1.43), (math.sin(ang), math.cos(ang), 0.0))), "gold", None, crease=0)
        c.add(ax.ellipsoid((0.09, 0.09, 0.05), 8, 4, M((0, -0.1 + 0.0, 1.46))), "orange", None, crease=0)
        return a, b, c

    assemble("turret_rapid", base, head, barrel, tiers, (0, 0.28, 1.02), 0.78)


# ----------------------------------------------------------------------------------- lourde
def heavy():
    def base():
        m = ax.Mesher()
        mound(m)
        prof = [(0.7, 0.04), (0.82, 0.25), (0.88, 0.5), (0.82, 0.75), (0.7, 0.92)]
        m.add(ax.lathe(prof, 20, None, True, True), "wood", None, crease=50)
        for z, r in ((0.24, 0.835), (0.72, 0.835)):
            m.add(ax.torus(r, 0.04, 20, 6, M((0, 0, z))), "steel_dark", None, crease=0)
        m.add(ax.cyl(0.7, 0.7, 0.04, 20, 0.92, True, True), "wood_light", None, crease=30)
        return m

    def head():
        m = ax.Mesher()
        turntable(m, 0.96, 0.62, "red_dark")
        m.add(ax.ellipsoid((0.6, 0.6, 0.42), 16, 9, M((0, 0, 1.26))), "red")
        for k in range(6):
            ang = 2 * math.pi * k / 6 + 0.3
            m.add(ax.ellipsoid((0.05, 0.05, 0.05), 5, 3, M((0.52 * math.sin(ang), 0.52 * math.cos(ang), 1.32))), "gold", crease=0)
        return m

    def barrel():
        m = ax.Mesher()
        barrel_cyl(m, 0, 1.28, 0.2, 1.1, 0.36, 0.3, "grey_dark")
        barrel_cyl(m, 0, 1.28, 1.02, 1.18, 0.43, 0.43, "steel_dark")
        return m

    def tiers():
        a, b, c = ax.Mesher(), ax.Mesher(), ax.Mesher()
        for sx in (-1, 1):  # palier 1 : plaques d'armure
            a.add(ax.box((0.08, 0.7, 0.55), 0.02, 2, M((sx * 0.9, 0.0, 0.5))), "steel", None, crease=30)
            a.add(ax.box((0.1, 0.5, 0.12), 0.02, 2, M((sx * 0.9, 0.0, 0.85))), "red_dark", None, crease=30)
        # palier 2 : casque à pointes + frein de bouche
        b.add(ax.cyl(0.14, 0.0, 0.4, 8, 1.62, True, True), "steel_light", None, crease=30)
        for k in range(4):
            ang = math.pi / 2 * k + math.pi / 4
            d = (math.cos(ang), 0.0, math.sin(ang))
            b.add(ax.cyl(0.05, 0.0, 0.2, 5, 0.0, True, True, M_align((0.45 * d[0], 1.1, 1.28 + 0.45 * d[2]), d)), "steel_light", None, crease=0)
        # palier 3 : bandes d'or et bannière
        for y in (0.45, 0.78):
            c.add(ax.torus(0.37, 0.045, 18, 6, M((0, y, 1.28), (90, 0, 0))), "gold", None, crease=0)
        c.add(ax.cyl(0.03, 0.03, 0.9, 6, 1.2, True, True, M((0.0, -0.55, 0))), "wood_dark", None, crease=0)
        c.add(ax.prism([(-0.3, 0), (0.3, 0), (0.3, -0.45), (0, -0.62), (-0.3, -0.45)], 0.03, 0.0, 1, M((0, -0.55, 2.0), (90, 0, 0))), "red", None, crease=0)
        c.add(ax.ellipsoid((0.1, 0.02, 0.1), 6, 4, M((0, -0.58, 1.8))), "gold", None, crease=0)
        return a, b, c

    assemble("turret_heavy", base, head, barrel, tiers, (0, 0.2, 1.28), 1.0)


# ----------------------------------------------------------------------------------- multiple
def multi():
    def base():
        m = ax.Mesher()
        mound(m)
        m.add(ax.cyl(0.82, 0.72, 0.8, 16, 0.04, True, True), lambda c, n: "sand" , None, crease=30)
        m.add(ax.cyl(0.88, 0.88, 0.08, 16, 0.74, True, True), "sand_light", None, crease=30)
        for k in range(8):
            ang = 2 * math.pi * k / 8
            m.add(ax.box((0.24, 0.16, 0.2), 0.02, 1, M((0.82 * math.sin(ang), 0.82 * math.cos(ang), 0.92), (0, 0, -math.degrees(ang)))), "sand_light", None, crease=30)
        m.add(ax.dome(0.22, 0.3, 10, 4, 0.04, M((0, 0.74, 0.0))), "wood_dark", None, crease=0)  # porte
        return m

    def head():
        m = ax.Mesher()
        turntable(m, 0.84, 0.55, "pink_dark")
        m.add(ax.ellipsoid((0.52, 0.52, 0.4), 16, 9, M((0, 0, 1.1))), "yellow")
        m.add(ax.torus(0.5, 0.04, 18, 6, M((0, 0, 1.02))), "pink", crease=0)
        return m

    def fan(m, angles, color_ring="pink"):
        for a in angles:
            r = math.radians(a)
            d = Vector((math.sin(r), math.cos(r), 0))
            c = Vector((0, 0, 1.1)) + d * 0.3
            m.add(ax.cyl(0.095, 0.09, 0.62, 10, 0.0, True, True, M(tuple(c - Vector((0, 0.3, 0)) + Vector((0, 0.3, 0))), (-90, 0, -a)) @ M()), "steel", None, crease=30)

    def barrel():
        m = ax.Mesher()
        for a in (-24, 0, 24):
            r = math.radians(a)
            base_p = Vector((0, 0.35, 1.1))
            m.add(ax.cyl(0.095, 0.09, 0.62, 10, 0.0, True, True, M(tuple(base_p), (-90, 0, -a))), "steel", None, crease=30)
            tip = base_p + Vector((math.sin(r), math.cos(r), 0)) * 0.6
            m.add(ax.cyl(0.13, 0.13, 0.1, 10, 0.0, True, True, M(tuple(tip), (-90, 0, -a))), "pink", None, crease=30)
        return m

    def tiers():
        a, b, c = ax.Mesher(), ax.Mesher(), ax.Mesher()
        for k, sx in enumerate((-1, 1)):  # palier 1 : fanions sur les créneaux
            a.add(ax.cyl(0.025, 0.025, 0.55, 6, 1.0, True, True, M((sx * 0.5, -0.5 if sx < 0 else 0.5, 0))), "wood_light", None, crease=0)
            a.add(ax.prism([(0, 0), (0.34, -0.11), (0, -0.22)], 0.03, 0.0, 1, M((sx * 0.5, -0.5 if sx < 0 else 0.5, 1.5), (90, 0, 90))), "pink", None, crease=0)
        for ang in (-48, 48):  # palier 2 : deux canons de plus (éventail à cinq)
            r = math.radians(ang)
            base_p = Vector((0, 0.35, 1.1))
            b.add(ax.cyl(0.085, 0.08, 0.55, 10, 0.0, True, True, M(tuple(base_p), (-90, 0, -ang))), "steel", None, crease=30)
            tip = base_p + Vector((math.sin(r), math.cos(r), 0)) * 0.55
            b.add(ax.cyl(0.12, 0.12, 0.09, 10, 0.0, True, True, M(tuple(tip), (-90, 0, -ang))), "pink", None, crease=30)
        c.add(ax.cyl(0.3, 0.26, 0.14, 12, 1.42, True, True), "gold", None, crease=30)  # palier 3 : couronne
        for k in range(5):
            ang = 2 * math.pi * k / 5
            c.add(ax.cyl(0.07, 0.0, 0.22, 5, 0.0, True, True, M((0.26 * math.sin(ang), 0.26 * math.cos(ang), 1.64))), "gold", None, crease=0)
        c.add(ax.ellipsoid((0.07, 0.07, 0.07), 6, 4, M((0, 0.3, 1.5))), "pink", None, crease=0)
        return a, b, c

    assemble("turret_multi", base, head, barrel, tiers, (0, 0.35, 1.1), 0.62)


# ----------------------------------------------------------------------------------- perforante
def pierce():
    def base():
        m = ax.Mesher()
        mound(m)
        m.add(ax.cyl(0.84, 0.76, 0.5, 14, 0.04, True, True), "grey", None, crease=30)
        m.add(ax.cyl(0.66, 0.6, 0.34, 14, 0.52, True, True), "grey_light", None, crease=30)
        m.add(ax.torus(0.84, 0.05, 20, 6, M((0, 0, 0.5))), "water_light", None, crease=0)
        for k in range(6):
            ang = 2 * math.pi * k / 6 + 0.4
            m.add(ax.ellipsoid((0.1, 0.07, 0.06), 6, 4, M((0.92 * math.sin(ang), 0.92 * math.cos(ang), 0.1))), "foam", None, crease=0)
        return m

    def head():
        m = ax.Mesher()
        turntable(m, 0.84, 0.5, "blue_dark")
        m.add(ax.ellipsoid((0.4, 0.62, 0.38), 16, 9, M((0, 0, 1.12))), lambda c, n: "white" if n.z < -0.35 else "blue")
        m.add(ax.prism([(0.0, 0.2), (-0.34, -0.3), (0.0, -0.3)], 0.06, 0.0, 1, M((0, -0.05, 1.4), (0, 90, 0))), "blue_dark", None, crease=0)
        for sx in (-1, 1):
            m.add(ax.ellipsoid((0.07, 0.07, 0.08), 8, 5, M((sx * 0.3, 0.35, 1.22))), "white", None, crease=0)
            m.add(ax.ellipsoid((0.04, 0.04, 0.05), 6, 4, M((sx * 0.34, 0.39, 1.23))), "black", None, crease=0)
        return m

    def barrel():
        m = ax.Mesher()
        barrel_cyl(m, 0, 1.12, 0.3, 1.35, 0.17, 0.025, lambda c, n: "white")
        for y in (0.45, 0.7, 0.95):
            m.add(ax.torus(0.155 - (y - 0.45) * 0.14, 0.03, 12, 5, M((0, y, 1.12), (90, 0, 0))), "blue_light", None, crease=0)
        m.add(ax.cyl(0.02, 0.0, 0.05, 5, 0.0, True, True, M((0, 1.35, 1.12), (-90, 0, 0))), "gold", None, crease=0)
        return m

    def tiers():
        a, b, c = ax.Mesher(), ax.Mesher(), ax.Mesher()
        for sx in (-1, 1):  # palier 1 : nageoires latérales
            a.add(ax.prism([(0, 0.2), (0.34, -0.05), (0.0, -0.3)], 0.05, 0.0, 1, M((sx * 0.9, 0.0, 0.62), (0, 0, 0))), "blue_dark", None, crease=0)
        for y in (0.62, 0.9, 1.15):  # palier 2 : anneaux stabilisateurs
            b.add(ax.torus(0.2, 0.04, 14, 6, M((0, y, 1.12), (90, 0, 0))), "teal", None, crease=0)
        for sx in (-1, 1):
            b.add(ax.ellipsoid((0.2, 0.05, 0.1), 8, 4, M((sx * 0.5, 0.55, 1.12), (0, 0, sx * 15))), "teal", None, crease=0)
        c.add(ax.ellipsoid((0.16, 0.16, 0.3), 6, 4, M((0, -0.2, 1.7))), "water_light", None, crease=0)  # palier 3 : cristal
        c.add(ax.torus(0.17, 0.035, 14, 6, M((0, -0.2, 1.46))), "gold", None, crease=0)
        c.add(ax.torus(0.3, 0.03, 16, 6, M((0, 0.0, 0.84))), "gold", None, crease=0)
        return a, b, c

    assemble("turret_pierce", base, head, barrel, tiers, (0, 0.3, 1.12), 1.05)


def main():
    which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["rapid", "heavy", "multi", "pierce"]
    fns = {"rapid": rapid, "heavy": heavy, "multi": multi, "pierce": pierce}
    for k in which:
        fns[k]()


if __name__ == "__main__":
    ax.main_guard(main)
