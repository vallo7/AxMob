"""Moteur de rendu « bonbon » des éléments d'interface AxMob (phase 6).

Reproduit le style des éléments fournis (bannières, pièce, étoile, trophée, cadeau) : volumes
gonflés, dégradé doux du clair vers le saturé, reflet principal en haut à gauche, liseré clair en
haut et liseré plus sombre en bas, AUCUN contour noir. Pas de dépendance 3D : un masque 2D est
« gonflé » (distance au bord -> hauteur -> normales) puis éclairé.

Tout est déterministe : mêmes entrées = mêmes pixels (la CI peut régénérer et comparer).
"""

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SS = 3  # suréchantillonnage (anticrénelage)
LIGHT = np.array([-0.42, -0.66, 0.62], dtype=np.float32)
LIGHT /= np.linalg.norm(LIGHT)
_H = LIGHT + np.array([0.0, 0.0, 1.0], dtype=np.float32)
_H /= np.linalg.norm(_H)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def canvas(w, h):
    """Masque vide (float 0..1) à la résolution suréchantillonnée."""
    return Image.new("L", (w * SS, h * SS), 0)


def draw_on(img):
    return ImageDraw.Draw(img)


def to_mask(img):
    return np.asarray(img, dtype=np.float32) / 255.0


def S(v):
    """Coordonnée logique -> pixels suréchantillonnés."""
    if isinstance(v, (tuple, list)):
        return type(v)(S(x) for x in v)
    return v * SS


def rrect(d, box, r, fill=255):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([S(x0), S(y0), S(x1), S(y1)], radius=S(r), fill=fill)


def ellipse(d, box, fill=255):
    x0, y0, x1, y1 = box
    d.ellipse([S(x0), S(y0), S(x1), S(y1)], fill=fill)


def polygon(d, pts, fill=255):
    d.polygon([(S(x), S(y)) for x, y in pts], fill=fill)


def line(d, pts, width, fill=255):
    p = [(S(x), S(y)) for x, y in pts]
    d.line(p, fill=fill, width=int(S(width)), joint="curve")
    r = S(width) / 2.0
    for x, y in (p[0], p[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def smooth(mask, px):
    """Adoucit les angles vifs d'un masque (ouverture/fermeture par flou + seuil)."""
    m = ndi.gaussian_filter(mask, S(px))
    return np.clip((m - 0.5) * 6.0 + 0.5, 0.0, 1.0)


def height(mask, bevel):
    """Hauteur (px suréchantillonnés) : profil en quart de cercle sur `bevel` px de bord."""
    inside = mask > 0.5
    dist = ndi.distance_transform_edt(inside).astype(np.float32)
    b = max(S(bevel), 1.0)
    t = np.clip(dist / b, 0.0, 1.0)
    return np.sqrt(1.0 - (1.0 - t) ** 2) * b, dist


def shade(mask, top, bottom, bevel, spec=0.55, rim=0.35, edge=0.30, edge_tint=None,
          flat=0.0, gloss=0.0, inset=False):
    """Éclaire un volume gonflé. Retourne (rgb float HxWx3, alpha float HxW).

    top/bottom : couleurs du dégradé vertical (haut -> bas du masque).
    flat : 0 = très gonflé (pièce, étoile), 1 = presque plat (bannière, fond de bouton).
    gloss : intensité du grand reflet doux en haut à gauche.
    """
    hgt, dist = height(mask, bevel)
    hgt = ndi.gaussian_filter(hgt, max(S(0.9), 1.0))  # gomme les marches de la distance
    if flat > 0.0:
        hgt = hgt * (1.0 - flat)
    gy, gx = np.gradient(hgt)
    if inset:  # creux : la lumière éclaire le bord opposé
        gx, gy = -gx, -gy
    n = np.dstack([-gx, -gy, np.ones_like(hgt)]).astype(np.float32)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    ys, xs = np.nonzero(mask > 0.5)
    if len(ys) == 0:
        return np.zeros(mask.shape + (3,), np.float32), mask
    y0, y1 = ys.min(), ys.max()
    t = np.clip((np.arange(mask.shape[0], dtype=np.float32) - y0) / max(y1 - y0, 1), 0, 1)[:, None]
    base = (top[None, None, :] * (1.0 - t[..., None]) + bottom[None, None, :] * t[..., None])
    base = np.broadcast_to(base, mask.shape + (3,)).copy()
    ndl = np.clip(np.einsum("ijk,k->ij", n, LIGHT), 0.0, 1.0)
    diff = 0.80 + 0.30 * ndl  # éclairage enveloppé : jamais de noir
    col = base * diff[..., None]
    # liseré clair en haut (arête tournée vers la lumière) et plus sombre en bas
    slope = 1.0 - n[..., 2]
    up = np.clip(-n[..., 1], 0.0, 1.0) * slope
    down = np.clip(n[..., 1], 0.0, 1.0) * slope
    col = col + rim * up[..., None] * (1.0 - col) * 1.6
    et = bottom * 0.62 if edge_tint is None else edge_tint
    col = col * (1.0 - edge * np.clip(down * 2.2, 0, 1)[..., None]) \
        + et[None, None, :] * (edge * np.clip(down * 2.2, 0, 1)[..., None]) * 0.6
    sp = np.clip(np.einsum("ijk,k->ij", n, _H), 0.0, 1.0) ** 38
    col = col + spec * sp[..., None] * (1.0 - flat * 0.5)
    if gloss > 0.0:
        # grand reflet doux : ellipse floue dans le tiers haut-gauche du volume
        gm = np.zeros_like(mask)
        cx = x0 = None
        xs0, xs1 = xs.min(), xs.max()
        w = xs1 - xs0
        h = y1 - y0
        yy, xx = np.mgrid[0:mask.shape[0], 0:mask.shape[1]].astype(np.float32)
        ex = (xx - (xs0 + w * 0.36)) / max(w * 0.34, 1)
        ey = (yy - (y0 + h * 0.22)) / max(h * 0.16, 1)
        gm = np.clip(1.0 - (ex * ex + ey * ey), 0.0, 1.0) ** 1.4
        inner = np.clip(dist / max(S(bevel) * 0.6, 1), 0, 1)
        col = col + gloss * (gm * inner)[..., None] * (1.0 - col) * 1.1
    return np.clip(col, 0.0, 1.0), mask


def over(dst_rgb, dst_a, src_rgb, src_a):
    """Composition « source over » de couches float (alpha non prémultiplié)."""
    out_a = src_a + dst_a * (1.0 - src_a)
    safe = np.maximum(out_a, 1e-6)[..., None]
    out = (src_rgb * src_a[..., None] + dst_rgb * dst_a[..., None] * (1.0 - src_a[..., None])) / safe
    return out, out_a


class Layer:
    """Une couche gonflée : masque + couleurs. Les couches s'empilent dans l'ordre d'appel."""

    def __init__(self, size):
        self.w, self.h = size
        shape = (self.h * SS, self.w * SS)
        self.rgb = np.zeros(shape + (3,), np.float32)
        self.a = np.zeros(shape, np.float32)

    def add(self, mask, top, bottom, bevel, **kw):
        rgb, a = shade(mask, hexc(top) if isinstance(top, str) else top,
                       hexc(bottom) if isinstance(bottom, str) else bottom, bevel, **kw)
        self.rgb, self.a = over(self.rgb, self.a, rgb, a)
        return self

    def flat(self, mask, color, alpha=1.0):
        c = hexc(color) if isinstance(color, str) else color
        rgb = np.broadcast_to(c, mask.shape + (3,))
        self.rgb, self.a = over(self.rgb, self.a, rgb, mask * alpha)
        return self

    def shadow(self, mask, dx, dy, blur, color="#000000", alpha=0.25):
        """Ombre portée DOUCE sous les couches existantes (à appeler avant elles)."""
        m = ndi.shift(mask, (S(dy), S(dx)), order=1)
        m = ndi.gaussian_filter(m, S(blur)) * alpha
        rgb = np.broadcast_to(hexc(color), m.shape + (3,))
        self.rgb, self.a = over(self.rgb, self.a, rgb, m)
        return self

    def image(self):
        a = np.clip(self.a, 0, 1)
        rgba = np.dstack([self.rgb, a])
        im = Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA")
        return im.resize((self.w, self.h), Image.LANCZOS)
