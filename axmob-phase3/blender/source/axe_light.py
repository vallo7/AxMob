"""Hache rapide (spike Phase 0) : modélisation paramétrique low-poly + animation 'spin' + export GLB.

Exécution headless :
    python blender/source/axe_light.py            # avec le module pip `bpy`
    blender -b -P blender/source/axe_light.py     # avec Blender installé

Conventions (plan §6.2) : 1 unité = 1 m, origine au centre de masse (entre le manche
et la lame), transformations appliquées, nom d'objet 'axe_light', animation 'spin'
(boucle). Le manche est le long de l'axe Y de Blender (devient -Z / avant dans Godot
après conversion glTF Y-up) ; la lame est du côté +X.
"""

import math
import os
import sys

import bpy  # doit être importé avant bmesh/mathutils (module pip)
import bmesh  # noqa: E402
from mathutils import Matrix  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export", "axe_light.glb")
if len(sys.argv) > 1 and sys.argv[-1].endswith(".glb"):
    OUT = sys.argv[-1]

# Palette D4 « Arène de pierre » : acier + accents orange + manche sombre
PALETTE = {
    "mat_steel": (0.62, 0.66, 0.72, 1.0),
    "mat_accent": (0.93, 0.47, 0.12, 1.0),
    "mat_handle": (0.20, 0.14, 0.10, 1.0),
}


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name: str, rgba: tuple) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.7
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def part_from_bmesh(name: str, builder, material: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    builder(bm)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def build_handle(bm: bmesh.types.BMesh) -> None:
    # Cylindre hexagonal le long de Y : longueur 0.80, rayon 0.035
    bmesh.ops.create_cone(
        bm, cap_ends=True, segments=6, radius1=0.035, radius2=0.035, depth=0.80,
        matrix=Matrix.Rotation(math.radians(90), 4, "X"),
    )


def build_blade(bm: bmesh.types.BMesh) -> None:
    # Lame : prisme à section plate, tranchant à +X, dos collé au manche
    t = 0.025  # demi-épaisseur
    pts = [(0.03, 0.10), (0.03, 0.34), (0.30, 0.42), (0.34, 0.22), (0.30, 0.02)]
    top = [bm.verts.new((x, y, t)) for x, y in pts]
    bot = [bm.verts.new((x, y, -t)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((top[i], bot[i], bot[j], top[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def build_band(bm: bmesh.types.BMesh) -> None:
    # Bague orange à la base de la lame
    bmesh.ops.create_cone(
        bm, cap_ends=True, segments=6, radius1=0.05, radius2=0.05, depth=0.06,
        matrix=Matrix.Translation((0, 0.06, 0))
        @ Matrix.Rotation(math.radians(90), 4, "X"),
    )


def build_axe() -> bpy.types.Object:
    mats = {k: make_material(k, v) for k, v in PALETTE.items()}
    parts = [
        part_from_bmesh("handle", build_handle, mats["mat_handle"]),
        part_from_bmesh("blade", build_blade, mats["mat_steel"]),
        part_from_bmesh("band", build_band, mats["mat_accent"]),
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    axe = bpy.context.view_layer.objects.active
    axe.name = "axe_light"
    axe.data.name = "axe_light"
    # Recentre l'origine au centre de masse approximatif (milieu du manche)
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS", center="BOUNDS")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_flat()
    return axe


def add_spin(obj: bpy.types.Object, frames: int = 24, fps: int = 60) -> None:
    scene = bpy.context.scene
    scene.render.fps = fps
    scene.frame_start, scene.frame_end = 0, frames
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.keyframe_insert("rotation_euler", index=2, frame=0)
    obj.rotation_euler[2] = math.radians(360)
    obj.keyframe_insert("rotation_euler", index=2, frame=frames)
    act = obj.animation_data.action
    act.name = "spin-loop"
    act.use_fake_user = True
    # Lecture linéaire ; la dernière pose (360°) == la première. Le suffixe '-loop' du nom
    # fait importer l'animation en boucle par Godot (le suffixe est retiré du nom).
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"


def _fcurves(action):
    # Blender 5 : fcurves via les channelbags (slotted actions) ; avant : action.fcurves
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.extend(cb.fcurves)
    return out


def count_tris(obj: bpy.types.Object) -> int:
    dg = bpy.context.evaluated_depsgraph_get()
    me = obj.evaluated_get(dg).to_mesh()
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    obj.evaluated_get(dg).to_mesh_clear()
    return n


def main() -> None:
    reset_scene()
    axe = build_axe()
    add_spin(axe)
    print(f"[blender] axe_light: {count_tris(axe)} triangles, dims={tuple(round(d, 3) for d in axe.dimensions)}")
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(OUT),
        export_format="GLB",
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_yup=True,
    )
    print(f"[blender] exporté: {os.path.abspath(OUT)}")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(OUT).replace(".glb", ".blend"))


if __name__ == "__main__":
    main()
