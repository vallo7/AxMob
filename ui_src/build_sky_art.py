#!/usr/bin/env python3
"""Génère assets/textures/clouds.png : nuages « dessin animé » (blanc, ombre lavande, bord doux),
3 formes dans un atlas 1024x512 (chaque case 341x512). Déterministe."""
import os
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "clouds.png")
CELL_W, CELL_H = 342, 512


def cloud(blobs, w=CELL_W, h=CELL_H, ss=3):
    W, H = w * ss, h * ss
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for cx, cy, r in blobs:
        d.ellipse([(cx - r) * ss, (cy - r) * ss, (cx + r) * ss, (cy + r) * ss], fill=255)
    base_y = max(cy + r * 0.55 for cx, cy, r in blobs)
    d.rectangle([0, base_y * ss, W, H], fill=0)  # fond plat (dessous aplati)
    m = m.resize((w, h), Image.LANCZOS)
    mask = np.asarray(m, np.float32) / 255.0
    yy = np.arange(h)[:, None].astype(np.float32) / h
    top = np.array([1.0, 0.99, 0.96])
    bot = np.array([0.78, 0.78, 0.96])
    t = np.clip((yy - 0.25) / 0.5, 0, 1)[..., None]
    col = top * (1 - t) + bot * t
    soft = np.asarray(m.filter(ImageFilter.GaussianBlur(1.6)), np.float32)[..., None] / 255.0
    rgb = np.broadcast_to(col, (h, w, 3))
    a = np.clip(soft * 1.0, 0, 1)
    return np.dstack([rgb, a])


def main():
    shapes = [
        [(90, 330, 62), (160, 290, 82), (235, 325, 66), (130, 350, 50), (200, 355, 50)],
        [(70, 340, 48), (125, 305, 66), (190, 280, 78), (250, 320, 58), (160, 352, 56)],
        [(110, 335, 56), (180, 305, 70), (245, 340, 50), (150, 355, 48)],
    ]
    atlas = np.zeros((CELL_H, CELL_W * 3, 4), np.float32)
    for i, s in enumerate(shapes):
        atlas[:, i * CELL_W:(i + 1) * CELL_W] = cloud(s)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray((atlas * 255).astype(np.uint8), "RGBA").save(OUT, optimize=True)
    print("[sky_art] ok ->", OUT)


if __name__ == "__main__":
    main()
