"""Bibliothèque de modélisation AxMob (Phase 4) : palette « plage », primitives low-poly,
squelette, animations procédurales, export GLB.

Tous les scripts d'asset (blender/source/*.py) l'utilisent ; on les lance en headless :
    python blender/source/crab.py              # module pip `bpy` (Python 3.13)
    blender -b -P blender/source/crab.py       # Blender installé

Conventions (plan §6.2) — à ne pas changer sans mettre à jour le jeu :
  * 1 unité = 1 m, Z vers le haut, origine au sol (au centre de la base).
  * L'AVANT de chaque modèle est +Y dans Blender : après export glTF (Y-up) il devient -Z,
    la convention du jeu (Planar : yaw 0 = avant = -Z). Droite du modèle = +X.
  * Un seul matériau « mat_palette » (atlas 8x8 de couleurs à dégradé vertical) pour tous les
    modèles : un seul matériau dans le jeu, donc le batching est préservé.
  * Personnages : UN seul maillage skinné (un appel de dessin) ; chaque pièce est liée à un
    os (poids 1) ou fondue entre os (tentacules). Les os sont de simples pivots (tête = point
    de pivot, orientés comme l'armature) : une rotation d'os = rotation autour de ce point.
  * Animations : fonctions du temps échantillonnées à 30 i/s, noms « idle-loop », « hit »...
    (le suffixe « -loop » fait boucler l'animation à l'import Godot ; il est retiré du nom).
"""

import math
import os
import shutil
import struct
import sys
import zlib

import bpy  # doit être importé avant bmesh/mathutils (module pip)
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(LIB_DIR, "..", "..", ".."))
EXPORT_DIR = os.path.join(REPO, "blender", "export")
GAME_MODELS = os.path.join(REPO, "assets", "models")
TEX_DIR = os.path.join(REPO, "assets", "textures")
PALETTE_PNG = os.path.join(TEX_DIR, "palette.png")

FPS = 30

# --------------------------------------------------------------------------------------------
# Palette « plage » : style jeu mobile fun / hyper casual (couleurs franches, dégradés doux).
# Phase 7 : teintes ramenées vers celles du LOGO (pierre violette pour l'acier et les gris, or / orange /
# rouge chauds, bois orangé, corail à la place du rose). Régénérer l'atlas : python ui_src/build_palette.py
# --------------------------------------------------------------------------------------------

COLORS = {
    # sable et mer
    "sand": "#F6CF7A", "sand_light": "#FBE6B0", "sand_dark": "#D9AC63", "sand_wet": "#C9985A",
    "water": "#34C6E0", "water_light": "#CFCBF2", "water_deep": "#1E8FD0", "foam": "#FFFFFF",
    # neutres
    "white": "#FFF8EC", "cream": "#FFE9C4", "grey_light": "#CFCBE2", "grey": "#8883A8",
    "grey_dark": "#4A4670", "ink": "#232638", "black": "#14141F",
    # chauds
    "red": "#E8362D", "red_dark": "#B8302C", "coral": "#FF7A68", "orange": "#FF9230",
    "orange_dark": "#E5701A", "yellow": "#FFD43B", "gold": "#FFC233", "gold_dark": "#D89010",
    # roses / violets
    "pink": "#FF6B4A", "pink_light": "#FFA27E", "pink_dark": "#D4402C", "purple": "#9B5CFF",
    "purple_dark": "#6B3BC4", "purple_light": "#C3A0FF", "magenta": "#D43FD6",
    # froids
    "teal": "#6A66B4", "teal_dark": "#443F86", "blue": "#3E7BFF", "blue_dark": "#2A52C9",
    "blue_light": "#A9A5DD", "navy": "#26397A", "indigo": "#4B47D8",
    # verts
    "lime": "#9BE04E", "green": "#3FBF6A", "green_dark": "#24905A", "green_light": "#7CDB8A",
    "palm": "#2EA65A", "palm_dark": "#1B7A45", "olive": "#8CC24A",
    # bois, peau
    "wood": "#B8693A", "wood_dark": "#7E4A2A", "wood_light": "#DC9A62", "skin": "#FFC9A0",
    "skin_dark": "#EBA37C", "blush": "#FF9B94",
    # métal
    "steel": "#ABA8D2", "steel_light": "#E8E5F8", "steel_dark": "#625F98",
}
ORDER = list(COLORS)
# Roundeur par défaut des boîtes/prismes sans congé explicite (phase 5).
AUTO_ROUND = True
AUTO_BEVEL_RATIO = 0.16
AUTO_BEVEL_MAX = 0.06
# Les petits détails (sourcils, lamelles) restent francs : on n'arrondit que les volumes visibles.
AUTO_MIN_SIZE = 0.08
AUTO_ROUND_MIN_RADIUS = 0.07
AUTO_ROUND_BELOW = 8
AUTO_ROUND_SEGS = 14
AUTO_ROUND_RINGS = 8
GRID = 8
CELL = 32
PAD = 2.5  # marge (texels) évitant les débordements de couleur entre cellules
assert len(ORDER) <= GRID * GRID, "palette trop grande pour l'atlas 8x8"


def hex_rgb(h: str) -> tuple:
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (1, 3, 5))


def _hash_noise(w: int, h: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    coarse = rng.random((h // 4 + 2, w // 4 + 2))
    # interpolation bilinéaire grossière -> « grain » doux de 4 texels
    ys = np.linspace(0, coarse.shape[0] - 1.001, h)
    xs = np.linspace(0, coarse.shape[1] - 1.001, w)
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    a = coarse[y0][:, x0]
    b = coarse[y0][:, x0 + 1]
    c = coarse[y0 + 1][:, x0]
    d = coarse[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def palette_pixels() -> np.ndarray:
    """Atlas RGB uint8 (origine en bas à gauche, convention Blender). Chaque cellule : base en
    bas -> 18 % plus claire en haut (faux éclairage ambiant) + grain léger."""
    size = GRID * CELL
    img = np.zeros((size, size, 3), dtype=np.float32)
    ys = np.arange(CELL)
    for i, name in enumerate(ORDER):
        col, row = i % GRID, i // GRID  # row 0 = rangée du haut
        base = np.array(hex_rgb(COLORS[name]), dtype=np.float32)
        y_c = np.clip(ys, PAD, CELL - 1 - PAD)
        t = ((y_c - PAD) / (CELL - 1 - 2 * PAD))[:, None, None]  # 0 bas .. 1 haut
        shade = 0.84 + 0.12 * t + 0.04 * t * t  # dégradé doux (phase 5 : moins contrasté)
        light = np.clip(base * shade + (1.0 - base) * 0.05 * t * t, 0, 1)
        # Couleurs un peu plus vives et chaudes : style « jouet » (phase 5).
        grey = light.mean(axis=2, keepdims=True)
        light = np.clip(grey + (light - grey) * 1.07, 0, 1)
        cell = np.broadcast_to(light, (CELL, CELL, 3)).copy()
        # Phase 5 : plus de grain dans la palette (textures lisses, aplats nets et doux).
        y0 = (GRID - 1 - row) * CELL  # indice de ligne depuis le bas
        img[y0 : y0 + CELL, col * CELL : (col + 1) * CELL, :] = cell
    return (np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def write_png(path: str, rgb_bottom_up: np.ndarray) -> None:
    """Écrit un PNG RGB 8 bits (sans dépendance) depuis un tableau origine bas-gauche."""
    arr = np.flipud(rgb_bottom_up)
    h, w = arr.shape[:2]
    channels = arr.shape[2] if arr.ndim == 3 else 1
    color_type = {1: 0, 3: 2, 4: 6}[channels]
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = struct.pack(">I", len(data)) + tag + data
        return body + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def ensure_palette() -> None:
    write_png(PALETTE_PNG, palette_pixels())


def cell_uv(name: str, su: float, sv: float) -> tuple:
    """UV (convention Blender, v vers le haut) dans la cellule de `name` ; su, sv dans [0,1]."""
    i = ORDER.index(name)
    col, row = i % GRID, i // GRID
    px = PAD + min(max(su, 0.0), 1.0) * (CELL - 2 * PAD)
    py = PAD + min(max(sv, 0.0), 1.0) * (CELL - 2 * PAD)
    return ((col * CELL + px) / (GRID * CELL), ((GRID - 1 - row) * CELL + py) / (GRID * CELL))


# --------------------------------------------------------------------------------------------
# Scène, matériau
# --------------------------------------------------------------------------------------------


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    ensure_palette()


def make_image_material(name: str, png_path: str, roughness: float = 0.9) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png_path, check_existing=True)
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def palette_material() -> bpy.types.Material:
    if "mat_palette" in bpy.data.materials:
        return bpy.data.materials["mat_palette"]
    return make_image_material("mat_palette", PALETTE_PNG)


# --------------------------------------------------------------------------------------------
# Transformations et primitives (retournent un bmesh temporaire, fusionné par Mesher.add)
# --------------------------------------------------------------------------------------------


def M(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)) -> Matrix:
    """Matrice 4x4 : échelle, puis rotation XYZ (degrés), puis translation."""
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    return Matrix.Translation(loc) @ r @ s


def M_align(loc, normal, spin=0.0, scale=1.0) -> Matrix:
    """Pose un objet (axe Z local = `normal`) en `loc`, tourné de `spin` degrés autour de sa normale."""
    n = Vector(normal).normalized()
    q = Vector((0, 0, 1)).rotation_difference(n)
    sc = (scale, scale, scale) if isinstance(scale, (int, float)) else scale
    return (
        Matrix.Translation(loc)
        @ q.to_matrix().to_4x4()
        @ Euler((0, 0, math.radians(spin))).to_matrix().to_4x4()
        @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1.0))
    )


def axis_rot(axis, deg: float) -> tuple:
    """Rotation de `deg` degrés autour d'un axe quelconque, en angles d'Euler XYZ (degrés)
    utilisables comme pose d'os."""
    from mathutils import Quaternion

    e = Quaternion(Vector(axis).normalized(), math.radians(deg)).to_euler("XYZ")
    return (math.degrees(e.x), math.degrees(e.y), math.degrees(e.z))


def fibonacci_sphere(n: int):
    """n directions quasi uniformes sur la sphère unité (épines, boutons)."""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = golden * i
        out.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    return out


def _apply(bm: bmesh.types.BMesh, xf) -> bmesh.types.BMesh:
    if xf is not None:
        bmesh.ops.transform(bm, matrix=xf, verts=bm.verts[:])
        if xf.determinant() < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    return bm


def lathe(profile, segs=16, xf=None, cap_bottom=True, cap_top=True) -> bmesh.types.BMesh:
    """Solide de révolution autour de Z. `profile` = [(rayon, z), ...] du bas vers le haut ;
    un rayon ~0 donne un pôle. Formes organiques, chapeaux, seaux, coques, cônes..."""
    bm = bmesh.new()
    angles = [2.0 * math.pi * k / segs for k in range(segs)]
    rings = []
    for r, z in profile:
        if r < 1e-5:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a in angles])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        if len(a) == 1 and len(b) == 1:
            continue
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1:
                bm.faces.new((a[0], b[k2], b[k]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[k2], b[0]))
            else:
                bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap_bottom and len(rings[0]) > 1:
        bm.faces.new(rings[0][::-1])
    if cap_top and len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    return _apply(bm, xf)


def ellipsoid(radii=(0.5, 0.5, 0.5), segs=14, rings=9, xf=None) -> bmesh.types.BMesh:
    rx, ry, rz = radii
    if AUTO_ROUND and max(radii) >= AUTO_ROUND_MIN_RADIUS and segs <= AUTO_ROUND_BELOW:
        # Phase 5 : yeux, articulations, pinces... plus de facettes visibles (silhouette ronde).
        segs, rings = AUTO_ROUND_SEGS, max(rings, AUTO_ROUND_RINGS)
    prof = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        prof.append((math.cos(a), math.sin(a)))
    prof = [(0.0 if abs(c) < 1e-6 else c, s) for c, s in prof]
    bm = lathe([(c, s) for c, s in prof], segs=segs)
    bmesh.ops.scale(bm, vec=(rx, ry, rz), verts=bm.verts[:])
    return _apply(bm, xf)


def dome(radius=0.5, height=0.3, segs=16, rings=5, base=0.0, xf=None) -> bmesh.types.BMesh:
    """Demi-ellipsoïde (calotte) posé sur z=base, fond fermé."""
    prof = [(radius, base)]
    for i in range(1, rings + 1):
        a = math.pi / 2 * i / rings
        prof.append((radius * math.cos(a) if i < rings else 0.0, base + height * math.sin(a)))
    return lathe(prof, segs=segs, xf=xf)


def cyl(r1=0.5, r2=None, h=1.0, segs=12, z0=0.0, cap_bottom=True, cap_top=True, xf=None):
    r2 = r1 if r2 is None else r2
    prof = [(r1, z0), (r2, z0 + h)]
    return lathe(prof, segs=segs, xf=xf, cap_bottom=cap_bottom, cap_top=cap_top)


def capsule(r=0.2, length=0.6, segs=10, rings=3, xf=None):
    """Capsule le long de Z, `length` = longueur du corps cylindrique entre les deux calottes."""
    prof = [(0.0, -length / 2 - r)]
    for i in range(1, rings + 1):
        a = -math.pi / 2 + math.pi / 2 * i / rings
        prof.append((r * math.cos(a), -length / 2 + r * math.sin(a)))
    for i in range(rings):
        a = math.pi / 2 * i / rings
        prof.append((r * math.cos(a), length / 2 + r * math.sin(a)))
    prof.append((0.0, length / 2 + r))
    return lathe(prof, segs=segs, xf=xf)


def torus(R=1.0, r=0.1, major=24, minor=8, xf=None) -> bmesh.types.BMesh:
    bm = bmesh.new()
    grid = []
    for i in range(major):
        a = 2.0 * math.pi * i / major
        row = []
        for j in range(minor):
            b = 2.0 * math.pi * j / minor
            rr = R + r * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
        grid.append(row)
    for i in range(major):
        for j in range(minor):
            i2, j2 = (i + 1) % major, (j + 1) % minor
            bm.faces.new((grid[i][j], grid[i2][j], grid[i2][j2], grid[i][j2]))
    return _apply(bm, xf)


def box(size=(1, 1, 1), bevel=0.0, seg=2, xf=None) -> bmesh.types.BMesh:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=tuple(size), verts=bm.verts[:])
    if bevel <= 0 and AUTO_ROUND and min(size) >= AUTO_MIN_SIZE:
        # Phase 5 : plus d'arêtes vives sur les boîtes — un petit chanfrein arrondit la silhouette
        # (le lissage des normales, `crease` 66°, en fait un congé doux).
        bevel = min(AUTO_BEVEL_MAX, AUTO_BEVEL_RATIO * min(size))
        seg = 1
    if bevel > 0:
        bmesh.ops.bevel(
            bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], offset=bevel, offset_type="OFFSET",
            segments=seg, profile=0.5, affect="EDGES",
        )
    return _apply(bm, xf)


def prism(points, thick=0.1, bevel=0.0, seg=2, xf=None) -> bmesh.types.BMesh:
    """Polygone convexe (XY, sens anti-horaire) extrudé de ±thick/2 selon Z."""
    bm = bmesh.new()
    h = thick / 2.0
    top = [bm.verts.new((x, y, h)) for x, y in points]
    bot = [bm.verts.new((x, y, -h)) for x, y in points]
    bm.faces.new(top)
    bm.faces.new(bot[::-1])
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bevel <= 0 and AUTO_ROUND and thick >= AUTO_MIN_SIZE:
        bevel = min(AUTO_BEVEL_MAX, AUTO_BEVEL_RATIO * min(thick, 1.0))
        seg = 1
    if bevel > 0:
        bmesh.ops.bevel(
            bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], offset=bevel, offset_type="OFFSET",
            segments=seg, profile=0.5, affect="EDGES",
        )
    return _apply(bm, xf)


def _frames(points):
    """Repères à transport parallèle le long d'une polyligne."""
    tangents = []
    for i, p in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        tangents.append((b - a).normalized())
    up = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    n = tangents[0].cross(up).normalized()
    frames = []
    for t in tangents:
        n = (n - t * n.dot(t)).normalized()
        frames.append((t, n, t.cross(n).normalized()))
    return frames


def tube(points, radii, segs=10, tip=0.8, xf=None) -> bmesh.types.BMesh:
    """Tube lofté le long d'une polyligne (tentacules, queues, antennes, bras). Chaque sommet
    reçoit son abscisse normalisée dans la couche `t` (pour fondre les poids entre os)."""
    pts = [Vector(p) for p in points]
    rad = [(r, r) if isinstance(r, (int, float)) else r for r in radii]
    bm = bmesh.new()
    tl = bm.verts.layers.float.new("t")
    lens = [0.0]
    for i in range(1, len(pts)):
        lens.append(lens[-1] + (pts[i] - pts[i - 1]).length)
    total = max(lens[-1], 1e-6)
    frames = _frames(pts)
    rings = []
    for i, p in enumerate(pts):
        t, n, b = frames[i]
        row = []
        for k in range(segs):
            a = 2.0 * math.pi * k / segs
            v = bm.verts.new(p + n * math.cos(a) * rad[i][0] + b * math.sin(a) * rad[i][1])
            v[tl] = lens[i] / total
            row.append(v)
        rings.append(row)
    for i in range(len(rings) - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    # bouts arrondis (anneau réduit + pôle)
    for end, sign in ((0, -1), (len(pts) - 1, 1)):
        t = frames[end][0] * sign
        p = pts[end]
        r0, r1 = rad[end]
        ring = rings[end]
        if tip <= 0:
            bm.faces.new(ring if sign < 0 else ring[::-1])
            continue
        n, b = frames[end][1], frames[end][2]
        mid = []
        for k in range(segs):
            a = 2.0 * math.pi * k / segs
            v = bm.verts.new(
                p + t * (min(r0, r1) * tip * 0.55) + n * math.cos(a) * r0 * 0.72
                + b * math.sin(a) * r1 * 0.72
            )
            v[tl] = 0.0 if sign < 0 else 1.0
            mid.append(v)
        pole = bm.verts.new(p + t * (min(r0, r1) * tip * 1.05))
        pole[tl] = 0.0 if sign < 0 else 1.0
        for k in range(segs):
            k2 = (k + 1) % segs
            if sign > 0:
                bm.faces.new((ring[k], ring[k2], mid[k2], mid[k]))
                bm.faces.new((mid[k], mid[k2], pole))
            else:
                bm.faces.new((ring[k2], ring[k], mid[k], mid[k2]))
                bm.faces.new((mid[k2], mid[k], pole))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _apply(bm, xf)


def mirror_x(bm: bmesh.types.BMesh) -> bmesh.types.BMesh:
    """Copie symétrique (x -> -x) d'un bmesh temporaire."""
    out = bm.copy()
    bmesh.ops.scale(out, vec=(-1, 1, 1), verts=out.verts[:])
    bmesh.ops.reverse_faces(out, faces=out.faces[:])
    return out


# --------------------------------------------------------------------------------------------
# Mesher : fusionne les pièces en un seul maillage (couleurs de palette, UV, poids d'os)
# --------------------------------------------------------------------------------------------


class Mesher:
    def __init__(self) -> None:
        self.bm = bmesh.new()
        self.pal = self.bm.faces.layers.int.new("pal")
        self.dv = self.bm.verts.layers.deform.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.groups: list = []

    def gi(self, name: str) -> int:
        if name not in self.groups:
            self.groups.append(name)
        return self.groups.index(name)

    def add(
        self, tmp, color, bone=None, smooth=True, crease=66.0, grad=1.0, weights_t=None,
        mirror_bone=None,
    ) -> None:
        """Ajoute une pièce. `color` : nom de palette, ou fonction(centre, normale) -> nom.
        `bone` : os lié (poids 1). `weights_t` : [(os, t), ...] triés, poids fondus selon la
        couche `t` d'un `tube`. `crease` : angle (°) au-delà duquel les arêtes restent vives.
        `mirror_bone` : ajoute aussi la copie symétrique liée à cet os."""
        if mirror_bone is not None:
            self._merge(mirror_x(tmp), color, mirror_bone, smooth, crease, grad, weights_t, True)
        self._merge(tmp, color, bone, smooth, crease, grad, weights_t, False)

    def _merge(self, tmp, color, bone, smooth, crease, grad, weights_t, mirrored) -> None:
        if smooth and crease > 0:
            sharp = [
                e for e in tmp.edges
                if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(crease)
            ]
            if sharp:
                bmesh.ops.split_edges(tmp, edges=sharp)
        tl = tmp.verts.layers.float.get("t")
        if len(tmp.verts) == 0:
            return
        lo = Vector((min(v.co[i] for v in tmp.verts) for i in range(3)))
        hi = Vector((max(v.co[i] for v in tmp.verts) for i in range(3)))
        ext = Vector((max(hi[i] - lo[i], 1e-4) for i in range(3)))
        vmap = {}
        for v in tmp.verts:
            nv = self.bm.verts.new(v.co)
            vmap[v] = nv
            if weights_t is not None and tl is not None:
                self._blend(nv, v[tl], weights_t)
            elif bone is not None:
                nv[self.dv][self.gi(bone)] = 1.0
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            center = f.calc_center_median()
            name = color(center, f.normal) if callable(color) else color
            nf[self.pal] = ORDER.index(name)
            nf.smooth = smooth
            for loop in nf.loops:
                co = loop.vert.co
                n = Vector(((co[i] - lo[i]) / ext[i] for i in range(3)))
                sv = 0.5 + (n.z - 0.5) * grad
                loop[self.uv].uv = cell_uv(name, 0.5 * (n.x + n.y), sv)

    def _blend(self, vert, t, weights_t) -> None:
        dv = vert[self.dv]
        if t <= weights_t[0][1]:
            dv[self.gi(weights_t[0][0])] = 1.0
            return
        if t >= weights_t[-1][1]:
            dv[self.gi(weights_t[-1][0])] = 1.0
            return
        for (b0, t0), (b1, t1) in zip(weights_t, weights_t[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / max(t1 - t0, 1e-6)
                k = k * k * (3 - 2 * k)
                dv[self.gi(b0)] = 1.0 - k
                dv[self.gi(b1)] = k
                return

    def tris(self) -> int:
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def build(self, name: str, rig=None, parent=None, origin=(0, 0, 0)) -> bpy.types.Object:
        """Crée l'objet. `origin` : point d'ancrage (les sommets sont décalés de -origin)."""
        origin = Vector(origin)
        if origin.length > 0:
            bmesh.ops.translate(self.bm, vec=-origin, verts=self.bm.verts[:])
        self.bm.normal_update()
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        n_tris = self.tris()
        self.bm.free()
        obj = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(obj)
        me.materials.append(palette_material())
        obj.location = origin
        if rig is not None:
            for g in self.groups:
                if g not in rig.bones:
                    raise ValueError(f"{name}: groupe/os inconnu {g}")
            for g in self.groups:
                obj.vertex_groups.new(name=g)
            obj.parent = rig.obj
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = rig.obj
        elif parent is not None:
            obj.parent = parent
        obj["tris"] = n_tris
        return obj


# --------------------------------------------------------------------------------------------
# Squelette (os = pivots) et animations procédurales
# --------------------------------------------------------------------------------------------


class Rig:
    """`spec` : liste de (os, parent|None, (x, y, z) pivot). Tous les os pointent vers +Y avec
    un roulis nul : leurs axes locaux sont ceux du modèle (X droite, Y avant, Z haut)."""

    def __init__(self, name: str, spec) -> None:
        self.name = name
        self.bones = {b: (p, Vector(h)) for b, p, h in spec}
        data = bpy.data.armatures.new(name)
        self.obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(self.obj)
        bpy.context.view_layer.objects.active = self.obj
        bpy.ops.object.mode_set(mode="EDIT")
        for b, p, h in spec:
            eb = data.edit_bones.new(b)
            eb.head = Vector(h)
            eb.tail = Vector(h) + Vector((0.0, 0.12, 0.0))
            if p:
                eb.parent = data.edit_bones[p]
        bpy.ops.object.mode_set(mode="OBJECT")
        self.obj.animation_data_create()
        self.actions = []

    def bake(self, name: str, seconds: float, fn, loop: bool = False) -> None:
        """Échantillonne `fn(u, t) -> {os: (rot_deg, loc, scale)}` (u = 0..1, t en s) à 30 i/s.
        Les os absents de la réponse restent au repos. Une boucle doit être périodique."""
        frames = max(int(round(seconds * FPS)), 2)
        act = bpy.data.actions.new(name + ("-loop" if loop else ""))
        act.use_fake_user = True
        self.obj.animation_data.action = act
        for pb in self.obj.pose.bones:
            pb.rotation_mode = "XYZ"
        # Boucle : N échantillons (u = 0..(N-1)/N), SANS image finale dupliquée -> période exacte
        # de N/30 s. Le jeu (ModelRig) retire la copie de la dernière clé ajoutée à l'export.
        last = frames - 1 if loop else frames
        for f in range(last + 1):
            u = f / frames
            pose = fn(u, u * seconds)
            for pb in self.obj.pose.bones:
                rot, loc, scl = _pose_values(pose.get(pb.name))
                pb.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
                pb.location = loc
                pb.scale = scl
                pb.keyframe_insert("rotation_euler", frame=f + 1)
                pb.keyframe_insert("location", frame=f + 1)
                pb.keyframe_insert("scale", frame=f + 1)
        self.actions.append(act)
        self.obj.animation_data.action = None

    def finish(self) -> None:
        for pb in self.obj.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)


def _pose_values(entry):
    rot, loc, scl = (0, 0, 0), (0, 0, 0), (1, 1, 1)
    if entry is None:
        return rot, loc, scl
    if isinstance(entry, dict):
        return entry.get("rot", rot), entry.get("loc", loc), entry.get("scale", scl)
    # tuple court : (rot,) ou (rot, loc) ou (rot, loc, scale)
    rot = entry[0]
    if len(entry) > 1:
        loc = entry[1]
    if len(entry) > 2:
        scl = entry[2]
    if isinstance(scl, (int, float)):
        scl = (scl, scl, scl)
    return rot, loc, scl


# outils d'animation
def smooth(x: float) -> float:
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def ease_out(x: float) -> float:
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) ** 3


def ease_in(x: float) -> float:
    x = min(max(x, 0.0), 1.0)
    return x**3


def seg(u: float, a: float, b: float) -> float:
    """Progression 0..1 de u entre a et b (bornée)."""
    return min(max((u - a) / max(b - a, 1e-6), 0.0), 1.0)


def wave(u: float, cycles: float = 1.0, phase: float = 0.0) -> float:
    return math.sin(2.0 * math.pi * (u * cycles + phase))


# --------------------------------------------------------------------------------------------
# Objets utilitaires, statistiques, export
# --------------------------------------------------------------------------------------------


def empty(name: str, loc=(0, 0, 0), parent=None, kind="PLAIN_AXES", size=0.1):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = kind
    obj.empty_display_size = size
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def tri_count(objs) -> int:
    total = 0
    for o in objs:
        if o.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return total


def world_bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return lo, hi


def export(name: str, report: bool = True) -> str:
    """Exporte tout le contenu de la scène en GLB (blender/export + assets/models) et enregistre
    le .blend source. Retourne le chemin du GLB."""
    os.makedirs(EXPORT_DIR, exist_ok=True)
    glb = os.path.join(EXPORT_DIR, name + ".glb")
    objs = list(bpy.context.scene.objects)
    has_anim = any(a.users > 0 or a.use_fake_user for a in bpy.data.actions)
    bpy.ops.export_scene.gltf(
        filepath=glb,
        export_format="GLB",
        export_animations=has_anim,
        export_animation_mode="ACTIONS",
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
        # Le jeu applique sa propre texture (assets/textures/palette.png) via le shader ax_toon :
        # inutile d'embarquer l'image dans chaque GLB (28 copies, et Godot les extrairait).
        export_image_format="NONE",
    )
    if os.path.isdir(os.path.join(REPO, "assets")):
        os.makedirs(GAME_MODELS, exist_ok=True)
        shutil.copyfile(glb, os.path.join(GAME_MODELS, name + ".glb"))
    blend = os.path.join(EXPORT_DIR, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    for stale in (blend + "1",):
        if os.path.exists(stale):
            os.remove(stale)
    if report:
        lo, hi = world_bounds(objs)
        d = hi - lo
        acts = ", ".join(sorted(a.name for a in bpy.data.actions))
        print(
            f"[blender] {name}: {tri_count(objs)} triangles, "
            f"dim {d.x:.2f} x {d.y:.2f} x {d.z:.2f} m, animations [{acts}]"
        )
    return glb


def main_guard(fn) -> None:
    """Exécute `fn()` ; code de sortie 1 si une exception survient (le CI échoue)."""
    try:
        fn()
    except Exception:  # noqa: BLE001
        import traceback

        traceback.print_exc()
        sys.exit(1)
