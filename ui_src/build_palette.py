#!/usr/bin/env python3
"""Régénère assets/textures/palette.png (atlas de couleurs des modèles) SANS Blender, depuis les
couleurs de blender/source/lib/ax.py. Les GLB ne changent pas : ils pointent vers des cases de
l'atlas par UV, recolorer l'atlas recolore tous les modèles d'un coup."""
import importlib.util
import os
import sys
from unittest import mock

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
for name in ("bpy", "bmesh", "mathutils"):
    sys.modules[name] = mock.MagicMock()
spec = importlib.util.spec_from_file_location("ax", os.path.join(ROOT, "blender", "source", "lib", "ax.py"))
ax = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ax)
ax.ensure_palette()
print("[palette] ok ->", ax.PALETTE_PNG)
