"""Instruments synthétisés d'AxMob : percussions, cordes pincées, marimba, steel drum, basses,
pads, cuivres. Chaque fonction renvoie un tableau mono (note complète, queue incluse)."""

import numpy as np

import dsp
from dsp import SR, RNG


def _vel(v):
    return 0.35 + 0.65 * v


def marimba(f, dur=1.0, vel=0.8):
    """Lame de marimba : partiels 1 / 3,93 / 9,46, plus longs dans les graves, coup de mailloche."""
    tau = float(np.clip(0.5 * (262.0 / f) ** 0.55, 0.12, 1.1))
    bright = 0.15 + 0.35 * vel
    body = dsp.modal(f, dur, [1.0, 3.93, 9.46], [1.0, bright, bright * 0.25], [tau, tau * 0.26, tau * 0.09])
    knock = dsp.click(0.012, min(1400 + f * 1.2, 6000), 0.004) * 0.22 * vel
    body = body * _vel(vel)
    body[: len(knock)] += knock
    return dsp.fade(body, 1.0, 12.0)


def steel(f, dur=1.4, vel=0.8):
    """Steel drum : partiels harmoniques, battements lents (désaccord), attaque « ping »."""
    s = float(np.clip((400.0 / f) ** 0.25, 0.7, 1.4))
    body = dsp.modal(f, dur, [1.0, 2.0, 3.01, 4.0, 5.04, 6.1], [1.0, 0.65, 0.36, 0.22, 0.1, 0.05],
                     [0.95 * s, 0.6 * s, 0.34 * s, 0.22 * s, 0.14 * s, 0.1 * s], detune=1.15)
    ping = dsp.click(0.01, 4200, 0.003) * 0.25 * vel
    body = body * _vel(vel)
    body[: len(ping)] += ping
    return dsp.fade(body, 1.0, 15.0)


def pluck(f, dur=0.9, bright=1.0, tau=0.5, damp=False):
    """Corde pincée (synthèse additive) : harmoniques 1/k, les aigus meurent plus vite."""
    n = dsp.n_of(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    kmax = int(min(18, SR * 0.45 / f))
    base_tau = 0.07 if damp else tau
    for k in range(1, kmax + 1):
        amp = bright ** (k - 1) / (k ** 1.12)
        tk = base_tau / (k ** 0.55)
        fk = f * k * (1.0 + 0.00018 * k * k)
        out += amp * np.sin(2 * np.pi * fk * t + RNG.random() * 0.4) * np.exp(-t / tk)
    scratch = dsp.click(0.01, 3200, 0.003) * (0.5 if damp else 0.25)
    out[: len(scratch)] += scratch
    return dsp.fade(out / 2.2, 0.6, 10.0)


def strum(freqs, dur=1.2, spread_ms=9.0, up=False, vel=0.8, damp=False, tau=0.55):
    """Accord de ukulélé : cordes pincées en décalé (la main balaie les cordes)."""
    order = list(reversed(freqs)) if up else list(freqs)
    n = dsp.n_of(dur + len(order) * spread_ms / 1000.0)
    out = np.zeros(n)
    for i, f in enumerate(order):
        note = pluck(f, dur, bright=0.78 + 0.14 * vel, tau=tau, damp=damp) * (0.8 + 0.2 * RNG.random())
        out = dsp.place(out, note, i * spread_ms / 1000.0)[:n]
    return out * _vel(vel) * 0.85


def bass(f, dur=0.5, vel=0.8, tau=0.32):
    """Basse ronde et rebondissante : sinus + triangle, légère chute de hauteur à l'attaque."""
    n = dsp.n_of(dur)
    fr = f * (1.0 + 0.35 * np.exp(-np.arange(n) / SR / 0.018))
    x = dsp.osc(fr, shape="sine") + 0.35 * dsp.osc(fr * 2, shape="tri") + 0.12 * dsp.osc(fr * 3, shape="sine")
    x *= dsp.ad_env(n, 0.004, tau)
    x = dsp.sat(x, 1.8)
    return dsp.fade(x * _vel(vel) * 0.7, 1.0, 12.0)


def kick(vel=0.9):
    n = dsp.n_of(0.38)
    fr = dsp.glide(150.0, 46.0, 0.38, curve=6.0)
    x = dsp.osc(fr, shape="sine") * np.exp(-np.arange(n) / SR / 0.13)
    c = dsp.click(0.012, 2500, 0.003)
    x[: len(c)] += c * 0.5
    return dsp.fade(dsp.sat(x, 1.7) * (0.55 + 0.45 * vel), 0.5, 20.0)


def conga(f=235.0, slap=False, vel=0.8):
    n = dsp.n_of(0.35)
    t = np.arange(n) / SR
    fr = f * (1.0 + 0.45 * np.exp(-t / 0.012))
    body = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / (0.06 if slap else 0.11))
    body += 0.4 * np.sin(2 * np.pi * np.cumsum(fr * 1.58) / SR) * np.exp(-t / 0.05)
    s = dsp.click(0.02, 2800 if slap else 1800, 0.006) * (0.9 if slap else 0.35)
    body[: len(s)] += s
    return dsp.fade(body * _vel(vel) * 0.8, 0.5, 15.0)


def shaker(vel=0.6, tau=0.03):
    n = dsp.n_of(0.12)
    x = dsp.hp(dsp.noise(0.12), 5200) * dsp.ad_env(n, 0.006, tau)
    return dsp.fade(x * _vel(vel) * 0.6, 0.5, 8.0)


def rim(vel=0.8):
    x = dsp.modal(1700, 0.1, [1.0, 2.3, 4.1], [1.0, 0.5, 0.2], [0.012, 0.008, 0.004])
    c = dsp.click(0.01, 2600, 0.002)
    x[: len(c)] += c * 0.6
    return dsp.fade(x * _vel(vel) * 0.7, 0.3, 6.0)


def tom(f=110.0, vel=0.9):
    n = dsp.n_of(0.6)
    fr = dsp.glide(f * 1.7, f, 0.6, curve=5.0)
    x = dsp.osc(fr, shape="sine") * np.exp(-np.arange(n) / SR / 0.2)
    c = dsp.click(0.015, 1500, 0.004)
    x[: len(c)] += c * 0.5
    return dsp.fade(dsp.sat(x, 1.4) * _vel(vel), 0.5, 25.0)


def pad(freqs, dur=2.0, vel=0.5, attack=0.35):
    """Nappe douce : triangles légèrement désaccordés, attaque et relâche lentes, filtre doux."""
    n = dsp.n_of(dur)
    out = np.zeros(n)
    for f in freqs:
        for d in (-0.35, 0.0, 0.4):
            out += dsp.osc(f * (1.0 + d * 0.004), dur, shape="tri", phase=RNG.random() * 6.28)
    env = np.clip(np.arange(n) / SR / attack, 0, 1) ** 2 * np.clip((n - np.arange(n)) / SR / 0.5, 0, 1) ** 1.5
    out = dsp.lp(out, 1800.0) * env
    return out / (len(freqs) * 3.0) * _vel(vel)


def brass(f, dur=0.35, vel=0.9):
    """Coup de cuivres : dents de scie empilées, filtre qui s'ouvre puis se ferme (« wah » de cuivre)."""
    n = dsp.n_of(dur)
    x = np.zeros(n)
    for d in (-0.003, 0.0, 0.003):
        x += dsp.osc(f * (1 + d), dur, shape="saw")
    x = dsp.sweep_filter(x, 500.0, 2600.0, "low", curve=0.35)
    env = dsp.ad_env(n, 0.012, 0.22)
    x = dsp.sat(x * env, 1.4)
    return dsp.fade(x * _vel(vel) * 0.55, 1.0, 20.0)


def horn(f, dur=1.2, vel=0.8):
    """Conque / corne douce : triangle + saw filtrés avec vibrato lent (fanfare de plage)."""
    n = dsp.n_of(dur)
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.3, 0, 1)
    x = dsp.osc(f * vib, shape="saw") * 0.6 + dsp.osc(f * vib, shape="tri")
    x = dsp.lp(x, 1500.0)
    env = np.clip(t / 0.06, 0, 1) ** 1.5 * np.clip((dur - t) / 0.25, 0, 1)
    return dsp.fade(x * env * _vel(vel) * 0.5, 1.0, 20.0)
