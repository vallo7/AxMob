#!/usr/bin/env python3
"""Post-traitement des icônes rendues depuis les modèles 3D (scripts/tools/render_icons.gd) :
saturation légère, contour brun cartoon (comme les autres icônes), recadrage sur le contenu,
sortie 256x256 (+ 112 px pour les petites tailles)."""
import os
import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage as ndi

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
D = os.path.join(ROOT, "assets", "ui", "icons")
INK = np.array([0x2E, 0x17, 0x12], np.float32) / 255.0


def process(path):
    im = Image.open(path).convert("RGBA")
    rgb = ImageEnhance.Color(im.convert("RGB")).enhance(1.35)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.12)
    a = np.asarray(im.getchannel("A"), np.float32) / 255.0
    bbox = Image.fromarray((a * 255).astype(np.uint8)).getbbox()
    pad = 22
    x0, y0, x1, y1 = bbox
    side = max(x1 - x0, y1 - y0) + pad * 2
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    rgb = rgb.crop(box).resize((256, 256), Image.LANCZOS)
    a = Image.fromarray((a * 255).astype(np.uint8)).crop(box).resize((256, 256), Image.LANCZOS)
    a = np.asarray(a, np.float32) / 255.0
    col = np.asarray(rgb, np.float32) / 255.0
    inside = a > 0.5
    dist = ndi.distance_transform_edt(~inside)
    ring = np.clip(7.0 - dist + 0.5, 0, 1)
    ring = ndi.gaussian_filter(ring, 0.7)
    out_a = np.maximum(a, ring)
    out_rgb = col * a[..., None] + INK[None, None, :] * (1 - a[..., None])
    out = np.dstack([out_rgb, out_a])
    final = Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")
    return final


def main():
    for f in sorted(os.listdir(D)):
        if f.startswith("model_") and f.endswith(".png") and not f.endswith("_s.png"):
            p = os.path.join(D, f)
            final = process(p)
            final.save(p, optimize=True)
            final.resize((112, 112), Image.LANCZOS).save(p.replace(".png", "_s.png"), optimize=True)
    print("[model_icons] ok")


if __name__ == "__main__":
    main()
