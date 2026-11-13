"""Instruments synthétiques d'AxMob (phase 7) : palette « aventure arcade » professionnelle
(batterie nette, basse synthé, cordes staccato, cuivres, flûte, guitare nylon) en remplacement de la
palette « plage » de la phase 5 (ukulélé, marimba, steel drum) jugée trop enfantine.
Chaque fonction renvoie un tableau mono (float) ; le niveau relatif est réglé par `vel` (0..1)."""

import numpy as np
from scipy import signal

import dsp
from dsp import SR, n_of


def _vel(v):
    return float(np.clip(v, 0.0, 1.2))


# ------------------------------------------------------------------ percussions
def kick(vel=0.9):
    """Grosse caisse courte et ronde : chute de hauteur rapide + claque de peau."""
    d = 0.42
    n = n_of(d)
    t = np.arange(n) / SR
    f = 46.0 + 120.0 * np.exp(-t / 0.028)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.17)
    click = dsp.bp(dsp.noise(0.02), 1800, 5200) * dsp.exp_env(n_of(0.02), 0.004)
    out = body.copy()
    out[: len(click)] += click * 0.35
    return dsp.sat(out, 1.6) * _vel(vel)


def snare(vel=0.9):
    """Caisse claire serrée : fût + timbre de bruit + courte réverbération d'ambiance (réalisée au mixage)."""
    n = n_of(0.30)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(205.0 - 40.0 * np.exp(-t / 0.03)) / SR) * np.exp(-t / 0.075)
    wires = dsp.bp(dsp.noise(0.30), 2200, 9000) * np.exp(-t / 0.085)
    snap = dsp.hp(dsp.noise(0.30), 4500) * np.exp(-t / 0.018)
    return (body * 0.55 + wires * 0.6 + snap * 0.35) * _vel(vel)


def clap(vel=0.8):
    """Clap : trois bouffées de bruit rapprochées + queue courte."""
    n = n_of(0.28)
    out = np.zeros(n)
    for off, g in ((0.0, 0.7), (0.011, 0.8), (0.023, 0.9)):
        k = int(off * SR)
        burst = dsp.bp(dsp.noise(0.09), 1100, 3800) * dsp.exp_env(n_of(0.09), 0.018)
        out[k : k + len(burst)] += burst[: n - k] * g
    tail = dsp.bp(dsp.noise(0.28), 900, 3000) * dsp.exp_env(n, 0.07)
    return (out + tail * 0.4) * _vel(vel)


def hat(vel=0.6, open_=False):
    d = 0.22 if open_ else 0.06
    n = n_of(d)
    tau = 0.085 if open_ else 0.016
    x = dsp.hp(dsp.noise(d), 7000) * dsp.exp_env(n, tau)
    metal = sum(np.sin(2 * np.pi * f * np.arange(n) / SR) for f in (3150, 4380, 5420, 6890)) / 4.0
    return (x * 0.8 + metal * dsp.exp_env(n, tau) * 0.25) * _vel(vel)


def rim(vel=0.7):
    n = n_of(0.08)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1700 * t) + 0.6 * np.sin(2 * np.pi * 2650 * t)
    out = x * np.exp(-t / 0.012)
    c = dsp.click(0.01, 3500)
    out[: len(c)] += c * 0.4
    return out * _vel(vel) * 0.7


def taiko(f=70.0, vel=0.9):
    """Tambour grave de combat : peau lourde, longue résonance, coup de baguette sourd."""
    d = 0.9
    n = n_of(d)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(f * (1.0 + 0.55 * np.exp(-t / 0.045))) / SR) * np.exp(-t / 0.33)
    thump = dsp.lp(dsp.noise(d), 500) * np.exp(-t / 0.05)
    stick = dsp.bp(dsp.noise(0.03), 900, 3000) * dsp.exp_env(n_of(0.03), 0.006)
    out = body + thump * 0.5
    out[: len(stick)] += stick * 0.35
    return dsp.sat(out, 1.4) * _vel(vel)


def tom(f=110.0, vel=0.8):
    return taiko(f, vel)[: n_of(0.5)] * dsp.exp_env(n_of(0.5), 0.3)


def cymbal_swell(dur=2.0, vel=0.6):
    n = n_of(dur)
    x = dsp.hp(dsp.noise(dur), 3500)
    env = (np.linspace(0, 1, n) ** 2.4) * np.exp(-np.maximum(np.arange(n) / SR - dur * 0.92, 0) / 0.05)
    return x * env * _vel(vel)


def crash(vel=0.8):
    n = n_of(1.8)
    x = dsp.hp(dsp.noise(1.8), 3000)
    metal = sum(np.sin(2 * np.pi * f * np.arange(n) / SR) for f in (3100, 4200, 5300, 6700, 8100)) / 5
    return (x * 0.7 + metal * 0.3) * dsp.exp_env(n, 0.55) * _vel(vel)


# ------------------------------------------------------------------ basses et harmonie
def synth_bass(f, dur=0.3, vel=0.8, cutoff=(2600.0, 420.0), grit=1.6):
    """Basse synthé de jeu d'action : scie + carré + sous-grave, filtre qui se referme vite."""
    n = n_of(dur + 0.06)
    saw = dsp.osc(f, None if False else (n / SR), "saw")
    sq = dsp.osc(f * 1.003, n / SR, "square")
    sub = np.sin(2 * np.pi * (f * 0.5) * np.arange(n) / SR)
    x = saw * 0.55 + sq * 0.25 + sub * 0.7
    x = dsp.sweep_filter(x, cutoff[0], cutoff[1], "low", curve=0.45)
    t = np.arange(n) / SR
    env = np.minimum(t / 0.004, 1.0) * np.exp(-np.maximum(t - dur * 0.55, 0.0) / 0.07)
    env *= np.exp(-t / (dur * 2.2))
    return dsp.sat(x * env, grit) * _vel(vel)


def strings_stac(f, dur=0.18, vel=0.7, bright=1.0):
    """Cordes staccato (section) : 3 scies désaccordées, attaque d'archet, extinction rapide."""
    n = n_of(dur + 0.05)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for cents in (-11.0, 0.0, 12.0):
        x += dsp.osc(f * 2.0 ** (cents / 1200.0), n / SR, "saw")
    x /= 3.0
    x = dsp.sweep_filter(x, 4200.0 * bright, 1500.0, "low", curve=0.6)
    bow = dsp.bp(dsp.noise(n / SR), 2500, 6500) * np.exp(-t / 0.02) * 0.1
    env = np.minimum(t / 0.012, 1.0) * np.exp(-np.maximum(t - dur * 0.4, 0.0) / 0.05)
    return (x * env + bow) * _vel(vel)


def strings_long(freqs, dur=2.0, vel=0.5, attack=0.45, release=0.5):
    """Nappe de cordes legato : scies désaccordées, attaque lente, filtre qui s'ouvre."""
    n = n_of(dur + release)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        for cents in (-9.0, 4.0, 10.0):
            x += dsp.osc(f * 2.0 ** (cents / 1200.0), n / SR, "saw")
    x /= max(len(freqs) * 3.0, 1.0)
    x = dsp.sweep_filter(x, 900.0, 2300.0, "low", curve=0.8)
    env = np.minimum(t / attack, 1.0) ** 1.5 * np.where(t < dur, 1.0, np.exp(-(t - dur) / (release * 0.4)))
    trem = 1.0 + 0.04 * np.sin(2 * np.pi * 5.1 * t)
    return x * env * trem * _vel(vel)


def brass_stab(f, dur=0.32, vel=0.8, swell=0.04):
    """Cuivre en coup sec : 4 scies, filtre à enveloppe (attaque « wah » courte), formant de trompette."""
    n = n_of(dur + 0.08)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for cents in (-9.0, -3.0, 4.0, 10.0):
        x += dsp.osc(f * 2.0 ** (cents / 1200.0), n / SR, "saw")
    x /= 4.0
    x = dsp.sweep_filter(x, 650.0, 3600.0, "low", curve=0.15)
    x = x + dsp.bp(x, 1100, 1900) * 0.5
    env = np.minimum(t / max(swell, 0.006), 1.0) * np.exp(-np.maximum(t - dur * 0.5, 0.0) / 0.09)
    return dsp.sat(x * env, 1.3) * _vel(vel)


def flute(f, dur=0.6, vel=0.7, vib=1.0):
    """Flûte/siffle de jeu : sinus + harmonique faible, souffle, vibrato qui s'installe."""
    n = n_of(dur + 0.12)
    t = np.arange(n) / SR
    v = 1.0 + 0.0042 * vib * np.sin(2 * np.pi * 5.3 * t) * np.clip((t - 0.12) / 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * v) / SR
    x = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = dsp.bp(dsp.noise(n / SR), 2200, 6000) * (0.05 + 0.05 * np.exp(-t / 0.05))
    env = np.minimum(t / 0.03, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.05))
    return (x + breath) * env * _vel(vel)


def lead_synth(f, dur=0.5, vel=0.7):
    """Lead synthé doux : scie filtrée + triangle, léger vibrato (pour doubler la flûte, plus de corps)."""
    n = n_of(dur + 0.1)
    t = np.arange(n) / SR
    v = 1.0 + 0.003 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.1) / 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * v) / SR
    saw = sum(np.sin(k * ph) / k for k in range(1, 9)) * 0.6
    tri = np.arcsin(np.sin(ph)) * 0.6
    x = dsp.lp(saw * 0.6 + tri, 3200)
    env = np.minimum(t / 0.012, 1.0) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.07))
    return x * env * _vel(vel)


def nylon(f, dur=1.0, vel=0.8, bright=0.7, damp=False):
    """Guitare nylon / harpe : corde pincée (Karplus-Strong filtré), son chaud et boisé."""
    n = n_of(dur)
    p = max(int(round(SR / f)), 4)
    ex = dsp.noise(p / SR)
    ex = dsp.lp(ex, 1800.0 + 4500.0 * bright)
    ex = ex[:p] * np.hanning(p) ** 0.3
    g = 0.9965 if not damp else 0.975
    a = np.zeros(p + 2)
    a[0] = 1.0
    a[p] = -g * 0.5
    a[p + 1] = -g * 0.5
    sig = np.zeros(n)
    sig[:p] = ex
    out = signal.lfilter([1.0], a, sig)
    out = out / (np.max(np.abs(out)) + 1e-9)
    return dsp.fade(out, 1.0, 12.0) * _vel(vel) * 0.7


def glock(f, dur=0.8, vel=0.5):
    """Célesta/glockenspiel discret : petit éclat FM (accents rares, jamais mélodie principale)."""
    return dsp.fm_bell(f, dur, ratio=3.01, index=1.8, tau=0.28, index_tau=0.05) * _vel(vel)


def riser(dur=2.0, vel=0.6):
    """Montée de tension : bruit filtré qui s'ouvre + ton qui monte."""
    n = n_of(dur)
    x = dsp.sweep_filter(dsp.noise(dur), 300.0, 9000.0, "low", curve=1.4)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * np.cumsum(180.0 * 2.0 ** (2.0 * t / dur)) / SR) * 0.3
    return (x + tone) * (np.linspace(0, 1, n) ** 1.7) * _vel(vel)
