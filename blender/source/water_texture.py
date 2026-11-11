#!/usr/bin/env python3
"""Texture de l'eau (phase 6) : assets/textures/water_noise.png, 256 x 256, SANS bpy, répétable.
 R = réseau de caustiques (arêtes de cellules de Worley), G = bruit de scintillement,
 B = nappes douces basse fréquence. Déterministe (graine fixe).
Usage : python3 blender/source/water_texture.py
"""
import os

import numpy as np
from PIL import Image

N = 256
CELLS = 8


def worley_ridge(rng, cells, n):
    """Distance F2 - F1 répétable : ~0 sur les arêtes entre cellules."""
    pts = (np.stack(np.meshgrid(np.arange(cells), np.arange(cells), indexing="ij"), -1)
           + rng.random((cells, cells, 2))) / cells
    ys, xs = (np.mgrid[0:n, 0:n] + 0.5) / n
    dist = []
    for oy in (-1, 0, 1):          # 9 copies du motif : répétable sur le tore
        for ox in (-1, 0, 1):
            for p in pts.reshape(-1, 2):
                dist.append(np.hypot(ys - (p[0] + oy), xs - (p[1] + ox)).astype(np.float32))
    two = np.partition(np.stack(dist), 1, axis=0)[:2]
    return two[1] - two[0]


def main():
    rng = np.random.default_rng(11)
    ridge = worley_ridge(rng, CELLS, N)
    r = 1.0 - np.clip(ridge / 0.045, 0, 1)
    r = r * r * (3 - 2 * r)
    g = rng.random((N, N))
    # B : nappes douces répétables (somme de sinusoïdes entières)
    yy, xx = np.mgrid[0:N, 0:N] / N * 2 * np.pi
    b = 0.5 + 0.25 * np.sin(xx * 2 + yy * 3 + 1.0) + 0.2 * np.sin(xx * 4 - yy * 2 + 2.0) + 0.1 * np.sin(yy * 5)
    img = np.dstack([r, g, np.clip(b, 0, 1), np.ones((N, N))])
    out = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "water_noise.png")
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.abspath(out), optimize=True)
    print("[water] ok")


if __name__ == "__main__":
    main()
