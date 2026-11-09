"""Bibliothèque de synthèse audio d'AxMob (phase 5). NumPy + SciPy, aucun échantillon externe.

Tout le son du jeu est synthétisé par du code : aucune licence, tout est remplaçable, reproductible
(graines fixes) et réglable. Principes de « sound design » appliqués ici :
  - couches : transitoire (clic/impact) + corps (ton) + queue (réverbération / air) ;
  - enveloppes exponentielles (jamais linéaires : une décroissance naturelle est exponentielle) ;
  - synthèse modale pour le bois, le métal et les coques (somme de partiels amortis) ;
  - balayages de hauteur et de filtre pour le mouvement (whoosh, boing, bulles) ;
  - saturation douce (tanh) plutôt qu'écrêtage, fondus de 1-3 ms contre les clics ;
  - réverbération par convolution avec une réponse synthétique (bruit filtré à décroissance exp.).
Les sons sont mono (positionnés par le jeu) sauf musique, ambiance et interface (stéréo).
"""

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(20261108)

# --------------------------------------------------------------------------------------------
# Notes
# --------------------------------------------------------------------------------------------
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(note: str) -> float:
    """'C4' -> 261.63 ; 'F#3', 'Bb2' acceptés."""
    n = NOTE_NAMES[note[0]]
    i = 1
    if note[i] == "#":
        n += 1
        i += 1
    elif note[i] == "b":
        n -= 1
        i += 1
    octave = int(note[i:])
    return 440.0 * 2.0 ** ((n - 9 + 12 * (octave - 4)) / 12.0)


def semis(f: float, s: float) -> float:
    return f * 2.0 ** (s / 12.0)


# --------------------------------------------------------------------------------------------
# Bases
# --------------------------------------------------------------------------------------------
def n_of(dur: float) -> int:
    return max(int(round(dur * SR)), 1)


def time(dur: float) -> np.ndarray:
    return np.arange(n_of(dur)) / SR


def osc(freq, dur=None, shape="sine", phase=0.0):
    """Oscillateur à fréquence constante ou variable (tableau en Hz, 1 valeur par échantillon)."""
    if np.isscalar(freq):
        f = np.full(n_of(dur), float(freq))
    else:
        f = np.asarray(freq, dtype=float)
    ph = phase + 2.0 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2.0 / np.pi * np.arcsin(np.sin(ph))
    if shape in ("saw", "square"):
        # Bande limitée par synthèse additive (quelques harmoniques suffisent pour des basses/cuivres).
        out = np.zeros_like(ph)
        f0 = float(np.mean(f))
        kmax = int(min(24, max(1, (SR * 0.45) / max(f0, 20.0))))
        if shape == "saw":
            for k in range(1, kmax + 1):
                out += np.sin(k * ph) / k
            return out * (2.0 / np.pi)
        for k in range(1, kmax + 1, 2):
            out += np.sin(k * ph) / k
        return out * (4.0 / np.pi)
    raise ValueError(shape)


def glide(f0, f1, dur, curve=3.0):
    """Courbe de fréquence exponentielle f0 -> f1 (curve > 1 : plus rapide au début)."""
    u = np.linspace(0.0, 1.0, n_of(dur))
    k = 1.0 - (1.0 - u) ** curve
    return f0 * (f1 / f0) ** k


def noise(dur, color="white"):
    n = n_of(dur)
    w = RNG.standard_normal(n)
    if color == "white":
        return w
    spec = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1] if len(f) > 1 else 1.0
    if color == "pink":
        spec /= np.sqrt(f)
    elif color == "brown":
        spec /= f
    out = np.fft.irfft(spec, n)
    return out / (np.std(out) + 1e-9)


def exp_env(n, tau):
    """Décroissance exponentielle (constante de temps tau en secondes)."""
    return np.exp(-np.arange(n) / SR / max(tau, 1e-4))


def ad_env(n, attack, tau, curve=1.0):
    """Attaque douce (sinus) puis décroissance exponentielle."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    a = np.sin(a * np.pi / 2.0) ** 2
    return a * np.exp(-np.maximum(t - attack, 0.0) / max(tau, 1e-4)) ** curve


def swell_env(n, peak, attack_pow=2.0, release_pow=1.5):
    """Montée puis descente lisses, pic à la fraction `peak` de la durée (whoosh, riser)."""
    u = np.linspace(0.0, 1.0, n)
    up = np.clip(u / peak, 0, 1) ** attack_pow
    down = np.clip((1.0 - u) / (1.0 - peak), 0, 1) ** release_pow
    return np.where(u < peak, up, down)


def fade(x, in_ms=2.0, out_ms=4.0):
    x = x.copy()
    ni = min(int(in_ms * SR / 1000), len(x) // 2)
    no = min(int(out_ms * SR / 1000), len(x) // 2)
    if ni > 0:
        x[:ni] *= np.linspace(0, 1, ni) ** 2
    if no > 0:
        x[-no:] *= np.linspace(1, 0, no) ** 2
    return x


# --------------------------------------------------------------------------------------------
# Filtres
# --------------------------------------------------------------------------------------------
def _sos(kind, fc, order=2):
    fc = np.clip(fc, 20.0, SR * 0.45)
    return signal.butter(order, fc, btype=kind, fs=SR, output="sos")


def lp(x, fc, order=2):
    return signal.sosfilt(_sos("low", fc, order), x, axis=0)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos("high", fc, order), x, axis=0)


def bp(x, lo, hi, order=2):
    lo = max(lo, 20.0)
    hi = min(max(hi, lo * 1.05), SR * 0.45)
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x, axis=0)


def sweep_filter(x, f0, f1, kind="low", q_oct=None, block=128, curve=1.0):
    """Filtre à fréquence de coupure variable (balayage exponentiel f0 -> f1), par blocs.
    Pour un passe-bande, `q_oct` est la largeur en octaves."""
    n = len(x)
    out = np.zeros(n)
    zi = None
    for s in range(0, n, block):
        u = (s / max(n - 1, 1)) ** curve
        fc = f0 * (f1 / f0) ** u
        if kind == "band":
            w = q_oct or 1.0
            sos = signal.butter(2, [max(fc / 2 ** (w / 2), 20), min(fc * 2 ** (w / 2), SR * 0.45)],
                                btype="band", fs=SR, output="sos")
        else:
            sos = _sos(kind, fc)
        if zi is None or zi.shape[0] != sos.shape[0]:
            zi = np.zeros((sos.shape[0], 2))
        seg, zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
        out[s:s + block] = seg
    return out


# --------------------------------------------------------------------------------------------
# Synthèse modale (bois, métal, coques, cloches) et FM
# --------------------------------------------------------------------------------------------
def modal(f, dur, ratios, amps, taus, detune=0.0):
    """Somme de partiels amortis : le coeur du son de bois/métal/membrane."""
    n = n_of(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, (r, a, tau) in enumerate(zip(ratios, amps, taus)):
        d = detune * (1.0 if i % 2 == 0 else -1.0)
        out += a * np.sin(2 * np.pi * (f * r + d) * t) * np.exp(-t / tau)
    return out


def fm_bell(f, dur, ratio=3.5, index=3.0, tau=0.35, index_tau=0.12):
    """Cloche FM : modulation dont l'indice décroît plus vite que l'amplitude (brillant -> doux)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * ratio * t)
    idx = index * np.exp(-t / index_tau)
    return np.sin(2 * np.pi * f * t + idx * mod) * np.exp(-t / tau)


def click(dur=0.006, fc=3000.0, tau=0.0015):
    """Transitoire de percussion : bruit filtré très bref."""
    n = noise(dur)
    return bp(n, fc * 0.6, fc * 1.6) * exp_env(len(n), tau)


def crackle(dur, density=900.0, fc=3500.0):
    """Craquements aléatoires (coquille, sable, papier froissé) : impulsions poissonniennes filtrées."""
    n = n_of(dur)
    gate = (RNG.random(n) < density / SR).astype(float)
    gate = np.convolve(gate, exp_env(int(0.004 * SR), 0.0008), mode="same")
    x = noise(dur) * gate
    return bp(x, fc * 0.5, fc * 1.8)


def sparkle(dur, notes, density=22.0, vol=0.5, tau=0.18):
    """Pluie de petites cloches aiguës sur des notes données (confettis sonores)."""
    n = n_of(dur)
    out = np.zeros(n)
    count = max(int(density * dur), 1)
    for i in range(count):
        start = int(RNG.random() ** 1.4 * (n - 1))
        f = RNG.choice(notes)
        b = fm_bell(f, 0.25, ratio=2.76, index=1.5, tau=tau, index_tau=0.05)
        amp = vol * (0.35 + 0.65 * RNG.random()) * (1.0 - start / n) ** 0.7
        end = min(start + len(b), n)
        out[start:end] += b[:end - start] * amp
    return out


# --------------------------------------------------------------------------------------------
# Mixage, stéréo, espace
# --------------------------------------------------------------------------------------------
def place(buf, x, start_s, gain=1.0):
    """Ajoute `x` dans `buf` (agrandi au besoin) à `start_s` secondes."""
    s = int(round(start_s * SR))
    need = s + len(x)
    if need > len(buf):
        pad = np.zeros((need - len(buf),) + buf.shape[1:])
        buf = np.concatenate([buf, pad], axis=0)
    buf[s:s + len(x)] += x * gain
    return buf


def mix(*layers):
    """Somme de couches de longueurs différentes, alignées au début."""
    n = max(len(a) for a in layers)
    out = np.zeros(n)
    for a in layers:
        out[:len(a)] += a
    return out


def pan(x, p):
    """Mono -> stéréo, loi de puissance constante (p de -1 gauche à +1 droite)."""
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def widen(st, ms=11.0, amt=0.35):
    """Élargissement stéréo (effet Haas) : chaque canal reçoit un peu de l'autre, retardé."""
    d = max(int(ms * SR / 1000), 1)
    left, right = st[:, 0], st[:, 1]
    right_d = np.concatenate([np.zeros(d), right[:-d]])
    left_d = np.concatenate([np.zeros(d), left[:-d]])
    return np.stack([left * (1 - amt) + right_d * amt, right * (1 - amt) + left_d * amt], axis=1)


def _ir(rt60, damp, length_s, seed, predelay=0.012):
    rng = np.random.default_rng(seed)
    n = int(length_s * SR)
    t = np.arange(n) / SR
    env = np.exp(-6.91 * t / rt60)
    ir = rng.standard_normal(n) * env
    # Amortissement des aigus croissant avec le temps : réverbération naturelle.
    out = np.zeros(n)
    block = 2048
    zi = None
    for s in range(0, n, block):
        fc = max(18000.0 * (1.0 - damp) ** (s / n * 4.0) + 700.0, 700.0)
        sos = _sos("low", fc)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        seg, zi = signal.sosfilt(sos, ir[s:s + block], zi=zi)
        out[s:s + block] = seg
    pd = int(predelay * SR)
    out = np.concatenate([np.zeros(pd), out])
    # Réflexions précoces éparses.
    for k in range(6):
        pos = pd + int((0.007 + 0.011 * k + 0.004 * rng.random()) * SR)
        if pos < len(out):
            out[pos] += (0.55 - 0.07 * k) * (1 if k % 2 == 0 else -1) * np.max(np.abs(out)) * 0.6
    return out / (np.sqrt(np.sum(out ** 2)) + 1e-9)


def reverb(x, rt60=0.6, wet=0.25, damp=0.55, predelay=0.012, tail=None):
    """Réverbération par convolution (mono ou stéréo). La queue allonge le signal."""
    tail = tail if tail is not None else min(rt60 * 1.1, 3.0)
    if x.ndim == 1:
        ir = _ir(rt60, damp, tail, 11, predelay)
        w = signal.fftconvolve(x, ir)
        out = np.zeros(len(w))
        out[:len(x)] += x * (1.0 - wet * 0.5)
        return out + w * wet * 2.2
    outs = []
    for c in range(x.shape[1]):
        ir = _ir(rt60, damp, tail, 11 + 7 * c, predelay)
        w = signal.fftconvolve(x[:, c], ir)
        out = np.zeros(len(w))
        out[:len(x)] += x[:, c] * (1.0 - wet * 0.5)
        outs.append(out + w * wet * 2.2)
    return np.stack(outs, axis=1)


def sat(x, drive=1.5):
    """Saturation douce (chaleur, cohésion) normalisée pour garder le niveau."""
    return np.tanh(x * drive) / np.tanh(drive)


def soft_limit(x, ceiling=0.9):
    """Limiteur doux : quasi linéaire sous le plafond, arrondit les crêtes au lieu de les écrêter."""
    return ceiling * np.tanh(x / ceiling)


def normalize_rms(x, target_db):
    """Amène le niveau efficace (RMS) à `target_db` puis limite doucement les crêtes."""
    r = np.sqrt(np.mean(np.square(x))) + 1e-12
    return soft_limit(x * (10 ** (target_db / 20.0) / r), 0.92)


def peak_db(x):
    return 20 * np.log10(np.max(np.abs(x)) + 1e-12)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-12)


def normalize(x, peak=-1.0):
    m = np.max(np.abs(x)) + 1e-12
    return x * (10 ** (peak / 20.0) / m)


def master(x, peak=-1.0, drive=1.0, hp_hz=25.0):
    """Finition d'un son : filtre sub, saturation douce, fondus, normalisation au pic."""
    x = hp(x, hp_hz, 2)
    if drive > 1.0:
        x = sat(x, drive)
    x = fade(x, 1.5, 6.0)
    return normalize(x, peak)


def trim_silence(x, thresh_db=-60.0):
    a = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    idx = np.where(a > 10 ** (thresh_db / 20.0))[0]
    if len(idx) == 0:
        return x
    return x[: idx[-1] + int(0.01 * SR)]


def to_int16(x):
    return np.clip(np.round(x * 32767.0), -32768, 32767).astype(np.int16)
