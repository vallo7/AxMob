"""Décor principal (phase 4) : l'île de sable de la plage, la bouée-rebord de l'arène et la mer.

  arena_beach.glb : `Ground` (disque de sable irrégulier + pente vers la mer, texture sand.png
                    peinte ici) et `Rim` (quatre arcs de bouée rouge et blanche, entre les
                    tourelles) — rayon de jeu 13 m ; le jeu met l'ensemble à l'échelle de
                    arena_radius / 13.
  ocean.glb       : disque de mer finement découpé (animé par le shader du jeu).
Le contour de l'île est `edge(theta)` : la MÊME formule est reprise dans le shader de la mer
(assets/shaders/ax_ocean.gdshader) pour dessiner l'écume ; changer l'une impose de changer l'autre.
Budget arena_beach : 6 000 triangles ; ocean : 2 500."""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import ax  # noqa: E402
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from ax import M  # noqa: E402
from mathutils import Vector  # noqa: E402

ARENA_R = 13.0
RIM_R = ARENA_R + 0.55
EDGE_BASE = 22.5
TEX_HALF = 26.0  # la texture couvre ±26 m
TEX_PX = 1024
TURRET_ANGLES = (45, 135, 225, 315)  # degrés depuis +Y ; la bouée est interrompue autour
GAP = 13.0  # demi-largeur de la coupure (degrés)


def edge(theta: float) -> float:
    return EDGE_BASE + 1.0 * math.sin(3 * theta + 0.6) + 0.6 * math.sin(5 * theta + 2.0)


def ground_z(r: float, e: float) -> float:
    """Plat jusqu'à e-2.4, puis pente douce qui passe sous la ligne d'eau (z = -0.28)."""
    t = (r - (e - 2.4)) / 2.7
    if t <= 0:
        return 0.0
    t = min(t, 1.6)
    return -0.62 * t * t * (3 - 2 * t) if t < 1 else -0.62 - (t - 1) * 0.5


# ------------------------------------------------------------------ texture de sable (numpy)
def box_blur(img: np.ndarray, radius: int, passes: int = 3) -> np.ndarray:
    """Flou (≈ gaussien après 3 passes) en numpy pur : somme cumulée séparable, bords répétés."""
    out = img.astype(np.float64)
    k = 2 * radius + 1
    for _ in range(passes):
        for axis in (0, 1):
            pad = [(0, 0)] * out.ndim
            pad[axis] = (radius + 1, radius)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            hi = np.take(c, np.arange(k, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - k), axis=axis)
            out = (hi - lo) / k
    return out


def paint_sand(path: str) -> None:
    n = TEX_PX
    xs = (np.arange(n) + 0.5) / n * 2 * TEX_HALF - TEX_HALF
    X, Y = np.meshgrid(xs, xs)  # X vers la droite ; Y vers le haut de l'image (origine bas-gauche)
    R = np.hypot(X, Y)
    TH = np.arctan2(X, Y)  # 0 = +Y (avant)
    E = np.vectorize(edge)(TH) if False else EDGE_BASE + 1.0 * np.sin(3 * TH + 0.6) + 0.6 * np.sin(5 * TH + 2.0)
    D = R - E
    rng = np.random.default_rng(7)

    def lerp(a, b, t):
        return a + (b - a) * np.clip(t, 0, 1)[..., None]

    def sm(a, b, x):
        t = np.clip((x - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)

    # Phase 6 (cartoon) : sable plus chaud et saturé, aplats nets, traits de « coup de pinceau ».
    c_sand = np.array([0.955, 0.775, 0.40])
    c_light = np.array([0.99, 0.88, 0.58])
    c_dark = np.array([0.88, 0.67, 0.33])
    c_wet = np.array([0.84, 0.625, 0.345])
    c_foam = np.array([1.0, 0.99, 0.94])

    img = np.broadcast_to(c_sand, (n, n, 3)).copy()
    img = lerp(img, np.broadcast_to(c_light, img.shape), sm(ARENA_R + 0.9, ARENA_R + 3.5, R))  # sable sec clair
    img = lerp(img, np.broadcast_to(c_dark, img.shape), 0.22 * sm(ARENA_R - 1.4, ARENA_R + 0.2, R) * (1 - sm(ARENA_R + 0.2, ARENA_R + 1.4, R)))
    wet = sm(-3.6, -1.2, D)
    img = lerp(img, np.broadcast_to(c_wet, img.shape), wet * 0.9)
    # petites vaguelettes d'écume sur le sable mouillé (festons) : traits plus francs (cartoon)
    scallop = D + 0.22 * np.sin(TH * 46 + 3 * np.sin(TH * 7))
    for off, w, a in ((-2.5, 0.10, 0.55), (-1.9, 0.12, 0.7), (-1.3, 0.2, 0.95)):
        band = np.exp(-(((scallop - off) / w) ** 2))
        img = lerp(img, np.broadcast_to(c_foam, img.shape), band * a)
    # ondulations (rides de sable) : très discrètes dans l'arène, plus marquées dehors
    noise_lo = np.kron(rng.random((n // 64 + 2, n // 64 + 2)), np.ones((64, 64)))[:n, :n]
    ripple = np.sin((R * 2.4 + noise_lo * 2.0 + 2.0 * np.sin(TH * 9)) * 1.0)
    amp = 0.008 + 0.02 * sm(ARENA_R, ARENA_R + 3, R)  # phase 5 : sable plus lisse
    img *= (1.0 + ripple * amp)[..., None]
    # variations douces + grain + quelques cailloux
    blobs = np.kron(rng.random((n // 32 + 2, n // 32 + 2)), np.ones((32, 32)))[:n, :n]
    img *= (1.0 + (blobs - 0.5) * 0.03)[..., None]
    # phase 5 : plus de grain ni de cailloux (texture lisse) ; léger flou final contre les marches des blobs
    img = box_blur(img, 2, 3)
    # Phase 6 : touches cartoon dessinées à la main (après le flou, donc nettes).
    in_arena = 1 - sm(ARENA_R + 1.0, ARENA_R + 2.4, R)
    # 1) traits de vent : arcs clairs concentriques par plaques
    patch = np.kron(rng.random((n // 96 + 2, n // 96 + 2)), np.ones((96, 96)))[:n, :n]
    patch = box_blur(patch[..., None], 24, 3)[..., 0]
    stroke = sm(0.80, 0.93, np.sin(R * 1.2 + 1.6 * np.sin(TH * 4 + R * 0.15)))
    stroke *= sm(0.52, 0.62, patch) * in_arena
    img = lerp(img, np.broadcast_to(c_light, img.shape), stroke * 0.5)
    # 2) pastilles de sable plus foncées (petits cailloux/creux) et éclats clairs
    px = 2 * TEX_HALF / n
    for _ in range(150):
        r0 = ARENA_R * math.sqrt(rng.random()) * 1.02
        a0 = rng.random() * 2 * math.pi
        cx, cy = r0 * math.sin(a0), r0 * math.cos(a0)
        rad = 0.22 + 0.30 * rng.random()
        mask = np.clip((rad - np.hypot(X - cx, Y - cy)) / (px * 1.2), 0, 1)
        img = lerp(img, np.broadcast_to(c_dark * 0.96, img.shape), mask * 0.55)
        mask2 = np.clip((rad * 0.45 - np.hypot(X - cx + rad * 0.3, Y - cy - rad * 0.3)) / (px * 1.2), 0, 1)
        img = lerp(img, np.broadcast_to(c_light, img.shape), mask2 * 0.55)
    for _ in range(22):
        r0 = ARENA_R * math.sqrt(rng.random())
        a0 = rng.random() * 2 * math.pi
        cx, cy = r0 * math.sin(a0), r0 * math.cos(a0)
        arm = 0.26 + 0.14 * rng.random()
        horiz = np.clip((0.09 - np.abs(Y - cy)) / (px * 1.2), 0, 1) * np.clip((arm - np.abs(X - cx)) / (px * 1.2), 0, 1)
        vert = np.clip((0.09 - np.abs(X - cx)) / (px * 1.2), 0, 1) * np.clip((arm - np.abs(Y - cy)) / (px * 1.2), 0, 1)
        img = lerp(img, np.broadcast_to(np.array([1.0, 0.98, 0.86]), img.shape), np.maximum(horiz, vert) * 0.7)
    # hors de l'île : couleur d'eau (jamais visible : la mer est dessinée par-dessus)
    img = lerp(img, np.broadcast_to(np.array([0.3, 0.75, 0.85]), img.shape), sm(0.5, 1.5, D))
    ax.write_png(path, (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8))


# ------------------------------------------------------------------ maillages
def ground_mesh():
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    n_theta = 72
    ts = [0.0, 0.12, 0.28, 0.42, 0.54, 0.64, 0.72, 0.78, 0.83, 0.87, 0.9, 0.93, 0.955, 0.975, 0.99, 1.0, 1.04, 1.1]
    rings = []
    for t in ts:
        row = []
        for j in range(n_theta):
            th = 2 * math.pi * j / n_theta
            e = edge(th)
            r = t * e if t <= 1.0 else e * t
            z = ground_z(r, e)
            row.append(bm.verts.new((r * math.sin(th), r * math.cos(th), z)))
        rings.append(row)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for j in range(n_theta):
            j2 = (j + 1) % n_theta
            if i == 0:
                f = bm.faces.new((rings[0][0], b[j2], b[j]))
            else:
                f = bm.faces.new((a[j], b[j], b[j2], a[j2]))
            f.smooth = True
    center = rings[0]
    # le premier anneau (t=0) est un point répété : on le fusionne
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    for f in bm.faces:
        for lp in f.loops:
            lp[uvl].uv = (0.5 + lp.vert.co.x / (2 * TEX_HALF), 0.5 + lp.vert.co.y / (2 * TEX_HALF))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def build_arena():
    ax.reset_scene()
    root = ax.empty("arena_beach", kind="CUBE", size=0.3)
    sand_png = os.path.join(ax.TEX_DIR, "sand.png")
    paint_sand(sand_png)
    import bpy

    bm = ground_mesh()
    me = bpy.data.meshes.new("Ground")
    bm.to_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    ground = bpy.data.objects.new("Ground", me)
    bpy.context.collection.objects.link(ground)
    me.materials.append(ax.make_image_material("mat_sand", sand_png, 1.0))
    ground.parent = root
    ground["tris"] = tris

    # bouée-rebord : quatre arcs entre les tourelles
    def stripe(c, n):
        a = math.degrees(math.atan2(c.x, c.y)) % 360.0
        return "red" if int(a / 7.5) % 2 == 0 else "white"

    m = ax.Mesher()
    segs_minor, tube_r = 10, 0.34
    for gap_center in TURRET_ANGLES:
        pass
    # un arc = suite de quads le long de l'angle ; on fabrique un tore complet puis on retire les
    # faces dont l'angle tombe dans une coupure.
    tor = ax.torus(RIM_R, tube_r, 96, segs_minor, M((0, 0, tube_r * 0.82), scale=(1, 1, 0.86)))
    kill = []
    for f in tor.faces:
        c = f.calc_center_median()
        a = math.degrees(math.atan2(c.x, c.y)) % 360.0
        if any(min(abs(a - g), 360 - abs(a - g)) < GAP for g in TURRET_ANGLES):
            kill.append(f)
    bmesh.ops.delete(tor, geom=kill, context="FACES")
    m.add(tor, stripe, crease=0, grad=0.9)
    # embouts arrondis : petites sphères blanches de part et d'autre de chaque coupure
    for g in TURRET_ANGLES:
        for s in (-1, 1):
            a = math.radians(g + s * GAP)
            m.add(ax.ellipsoid((tube_r * 0.98, tube_r * 0.98, tube_r * 0.84), 8, 5,
                               M((RIM_R * math.sin(a), RIM_R * math.cos(a), tube_r * 0.82))), "white", crease=0)
    rim = m.build("Rim", parent=root)
    ax.export("arena_beach")


def ocean_mesh():
    ax.reset_scene()
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rings_r = [0, 8, 14, 18, 20, 21.5, 22.7, 24, 25.3, 26.6, 28, 30, 33, 38, 46, 60, 80]
    n_theta = 64
    rows = []
    for r in rings_r:
        rows.append([bm.verts.new((r * math.sin(2 * math.pi * j / n_theta), r * math.cos(2 * math.pi * j / n_theta), 0.0)) for j in range(n_theta)])
    for i in range(len(rows) - 1):
        a, b = rows[i], rows[i + 1]
        for j in range(n_theta):
            j2 = (j + 1) % n_theta
            if i == 0:
                bm.faces.new((a[0], b[j2], b[j]))
            else:
                bm.faces.new((a[j], b[j], b[j2], a[j2]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    for f in bm.faces:
        f.smooth = True
        for lp in f.loops:
            lp[uvl].uv = (0.5 + lp.vert.co.x / 160.0, 0.5 + lp.vert.co.y / 160.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    import bpy

    me = bpy.data.meshes.new("Ocean")
    bm.to_mesh(me)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    obj = bpy.data.objects.new("Ocean", me)
    bpy.context.collection.objects.link(obj)
    me.materials.append(ax.palette_material())
    obj["tris"] = tris
    ax.export("ocean")


def main():
    build_arena()
    ocean_mesh()


if __name__ == "__main__":
    ax.main_guard(main)
