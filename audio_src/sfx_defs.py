"""Définition de tous les effets sonores du jeu (synthèse). Chaque fonction prend l'indice de
variante `v` (rotation sans répétition dans le jeu) et renvoie un tableau mono.
REGISTRY : nom -> (fonction, nombre de variantes, pic cible en dBFS).
Les pics cibles fixent la HIÉRARCHIE sonore : l'important (dégâts subis, boss, zone) est plus fort,
le fréquent (pas, étincelles, pièces) plus discret, pour que la bataille reste lisible."""

import numpy as np

import dsp
import instruments as I
from dsp import SR, n_of

PENTA = [dsp.hz(n) for n in ("C7", "D7", "E7", "G7", "A7")]
COIN_NOTES = [dsp.hz(n) for n in ("C6", "D6", "E6", "G6", "A6", "C7", "D7", "E7")]


def stack(*parts):
    buf = np.zeros(1)
    for x, start, gain in parts:
        buf = dsp.place(buf, x, start, gain)
    return buf


def pf_of(v, spread=0.08):
    return [1.0, 1.0 - spread, 1.0 + spread * 1.2, 1.0 - spread * 0.5][v % 4]


def whoosh(dur, f0, f1, width=1.4, peak=0.3, curve=0.85):
    n = n_of(dur)
    return dsp.sweep_filter(dsp.noise(dur), f0, f1, "band", q_oct=width, curve=curve) * dsp.swell_env(n, peak, 1.6, 1.6)


# ------------------------------------------------------------------ lancers de haches
def throw_rapid(v):
    pf = pf_of(v)
    thump = dsp.osc(dsp.glide(210 * pf, 120 * pf, 0.08), shape="sine") * dsp.exp_env(n_of(0.08), 0.025)
    twang = dsp.modal(430 * pf, 0.14, [1, 2.01, 3.02], [1, 0.4, 0.2], [0.05, 0.03, 0.015])
    x = stack((whoosh(0.22, 1100 * pf, 5200 * pf), 0.0, 0.55), (twang, 0.0, 0.3), (thump, 0.0, 0.55),
              (dsp.click(0.008, 3200), 0.0, 0.5))
    return dsp.reverb(x, 0.22, 0.1)


def throw_heavy(v):
    pf = pf_of(v, 0.06)
    boom = dsp.osc(dsp.glide(165 * pf, 46 * pf, 0.55, 4), shape="sine") * dsp.exp_env(n_of(0.55), 0.17)
    knock = dsp.modal(110 * pf, 0.28, [1, 2.3, 3.7], [1, 0.5, 0.25], [0.09, 0.05, 0.03])
    creak = whoosh(0.3, 280, 900, 1.2, 0.7) * 0.5
    x = stack((boom, 0.0, 0.95), (knock, 0.0, 0.6), (creak, 0.0, 0.5), (whoosh(0.62, 350 * pf, 1800 * pf, 1.6, 0.28), 0.03, 0.65),
              (dsp.click(0.01, 1800), 0.0, 0.6))
    return dsp.reverb(x, 0.45, 0.2)


def throw_multi(v):
    pf = pf_of(v, 0.05)
    parts = []
    for i in range(3):
        s = pf * (1.0 + 0.09 * i)
        parts.append((whoosh(0.15, 1400 * s, 5600 * s, 1.3, 0.3), 0.055 * i, 0.5))
        parts.append((dsp.modal(520 * s, 0.1, [1, 2.0, 3.0], [1, 0.35, 0.15], [0.04, 0.02, 0.01]), 0.055 * i, 0.22))
        parts.append((dsp.click(0.006, 3600), 0.055 * i, 0.4))
    return dsp.reverb(stack(*parts), 0.25, 0.12)


def throw_pierce(v):
    pf = pf_of(v, 0.06)
    n = n_of(0.45)
    t = np.arange(n) / SR
    f = dsp.glide(900 * pf, 2500 * pf, 0.45, 1.6) * (1.0 + 0.012 * np.sin(2 * np.pi * 14 * t))
    zing = dsp.osc(f, shape="sine") * dsp.ad_env(n, 0.01, 0.12) * 0.5
    ring = dsp.modal(1500 * pf, 0.4, [1.0, 1.58, 2.37], [1, 0.5, 0.3], [0.16, 0.12, 0.08]) * 0.35
    air = dsp.hp(whoosh(0.4, 3200, 9000, 1.2, 0.3), 2500) * 0.5
    return dsp.reverb(stack((zing, 0, 0.8), (ring, 0.01, 0.6), (air, 0, 0.7), (dsp.click(0.008, 5000), 0, 0.4)), 0.3, 0.14)


# ------------------------------------------------------------------ impacts (couche « hache »)
def hit_rapid(v):
    pf = pf_of(v, 0.1)
    wood = dsp.modal(520 * pf, 0.16, [1, 2.76, 5.4], [1, 0.55, 0.25], [0.06, 0.035, 0.018])
    sub = dsp.osc(dsp.glide(150, 90, 0.06), shape="sine") * dsp.exp_env(n_of(0.06), 0.02)
    return stack((wood, 0, 0.8), (dsp.click(0.01, 2600 * pf), 0, 0.7), (sub, 0, 0.6), (dsp.crackle(0.07, 1200, 3000), 0.004, 0.25))


def hit_heavy(v):
    pf = pf_of(v, 0.07)
    sub = dsp.osc(dsp.glide(115 * pf, 42 * pf, 0.4, 3.5), shape="sine") * dsp.exp_env(n_of(0.4), 0.12)
    body = dsp.modal(185 * pf, 0.3, [1, 2.4, 4.4], [1, 0.6, 0.3], [0.12, 0.07, 0.04])
    crack = dsp.bp(dsp.noise(0.1), 800, 5000) * dsp.exp_env(n_of(0.1), 0.022)
    crunch = dsp.crackle(0.16, 1500, 2200) * dsp.exp_env(n_of(0.16), 0.07)
    x = stack((sub, 0, 1.0), (body, 0, 0.8), (crack, 0, 0.9), (crunch, 0.005, 0.55))
    return dsp.reverb(x, 0.4, 0.16)


def hit_multi(v):
    pf = pf_of(v, 0.1)
    tik = dsp.modal(900 * pf, 0.1, [1, 2.6, 4.9], [1, 0.4, 0.2], [0.03, 0.018, 0.01])
    return stack((tik, 0, 0.7), (dsp.click(0.008, 3800 * pf), 0, 0.7), (dsp.osc(dsp.glide(200, 120, 0.04), shape="sine") * dsp.exp_env(n_of(0.04), 0.015), 0, 0.4))


def hit_pierce(v):
    pf = pf_of(v, 0.08)
    ring = dsp.modal(2100 * pf, 0.35, [1, 1.62, 2.48, 3.4], [1, 0.7, 0.5, 0.3], [0.2, 0.14, 0.1, 0.06])
    return dsp.reverb(stack((ring, 0, 0.7), (dsp.click(0.01, 5200), 0, 0.8), (dsp.crackle(0.08, 1500, 4500), 0, 0.3)), 0.3, 0.14)


# ------------------------------------------------------------------ matières des ennemis
def mat_shell(v):
    pf = pf_of(v, 0.07)
    k = dsp.modal(1800 * pf, 0.08, [1, 1.7, 2.9], [1, 0.7, 0.4], [0.018, 0.012, 0.008])
    return stack((k, 0, 0.6), (dsp.crackle(0.1, 1800, 3500), 0, 0.6), (dsp.osc(300 * pf, 0.04) * dsp.exp_env(n_of(0.04), 0.012), 0, 0.5))


def mat_squish(v):
    pf = pf_of(v, 0.1)
    pop = dsp.osc(dsp.glide(620 * pf, 230 * pf, 0.09), shape="sine") * dsp.exp_env(n_of(0.09), 0.03)
    wet = dsp.bp(dsp.noise(0.1), 900, 2600) * dsp.exp_env(n_of(0.1), 0.025)
    return stack((pop, 0, 0.8), (wet, 0.004, 0.45))


def mat_hollow(v):
    pf = pf_of(v, 0.06)
    d = dsp.modal(205 * pf, 0.3, [1, 2.4, 3.9], [1, 0.45, 0.2], [0.12, 0.07, 0.04])
    return dsp.reverb(stack((d, 0, 0.9), (dsp.click(0.01, 1300), 0, 0.5)), 0.3, 0.12)


def mat_bubble(v):
    pf = pf_of(v, 0.08)
    n = n_of(0.22)
    t = np.arange(n) / SR
    f = dsp.glide(280 * pf, 720 * pf, 0.22, 1.5) * (1.0 + 0.03 * np.sin(2 * np.pi * 16 * t))
    boing = dsp.osc(f, shape="sine") * dsp.exp_env(n, 0.09)
    pop = dsp.osc(dsp.glide(900, 300, 0.03), shape="sine") * dsp.exp_env(n_of(0.03), 0.01)
    return stack((boing, 0, 0.8), (pop, 0.16, 0.5))


def mat_kraken(v):
    pf = pf_of(v, 0.05)
    slap = dsp.lp(dsp.noise(0.12), 900) * dsp.exp_env(n_of(0.12), 0.05)
    thump = dsp.osc(dsp.glide(210 * pf, 85 * pf, 0.2), shape="sine") * dsp.exp_env(n_of(0.2), 0.07)
    squelch = dsp.sweep_filter(dsp.noise(0.2), 900, 150, "band", 1.3) * dsp.exp_env(n_of(0.2), 0.08)
    return dsp.reverb(stack((slap, 0, 0.9), (thump, 0, 0.9), (squelch, 0.02, 0.5)), 0.4, 0.14)


# ------------------------------------------------------------------ éliminations
def die_shell(v):
    pf = pf_of(v, 0.08)
    crunch = dsp.crackle(0.16, 2200, 3000) * dsp.exp_env(n_of(0.16), 0.06)
    pop = dsp.osc(dsp.glide(720 * pf, 180 * pf, 0.06), shape="sine") * dsp.exp_env(n_of(0.06), 0.02)
    sp = dsp.sparkle(0.4, PENTA, 22, 0.35)
    return dsp.reverb(stack((crunch, 0, 0.8), (pop, 0, 0.8), (sp, 0.03, 0.5)), 0.35, 0.16)


def die_squish(v):
    pf = pf_of(v, 0.08)
    sq = dsp.osc(dsp.glide(520 * pf, 1500 * pf, 0.08, 1.5), shape="sine") * dsp.exp_env(n_of(0.08), 0.05)
    pop = dsp.osc(dsp.glide(900, 250, 0.05), shape="sine") * dsp.exp_env(n_of(0.05), 0.016)
    parts = [(sq, 0, 0.7), (pop, 0.075, 0.8), (dsp.sparkle(0.35, PENTA, 18, 0.3), 0.06, 0.5)]
    for i, (a, b) in enumerate(((300, 700), (380, 900), (450, 1100))):
        parts.append((dsp.osc(dsp.glide(a * pf, b * pf, 0.05), shape="sine") * dsp.exp_env(n_of(0.05), 0.02), 0.11 + 0.05 * i, 0.3))
    return dsp.reverb(stack(*parts), 0.3, 0.14)


def die_hollow(v):
    pf = pf_of(v, 0.06)
    dong = dsp.modal(130 * pf, 0.5, [1, 2.4, 3.9, 5.5], [1, 0.5, 0.3, 0.15], [0.2, 0.1, 0.06, 0.03])
    crack = dsp.crackle(0.18, 1100, 2400) * dsp.exp_env(n_of(0.18), 0.07)
    return dsp.reverb(stack((dong, 0, 0.9), (crack, 0.02, 0.75), (dsp.sparkle(0.4, PENTA, 18, 0.3), 0.08, 0.5)), 0.45, 0.18)


def die_bubble(v):
    pf = pf_of(v, 0.07)
    n = n_of(0.3)
    deflate = dsp.sweep_filter(dsp.noise(0.3), 2500, 400, "band", 1.5) * dsp.swell_env(n, 0.15, 1.2, 1.4)
    tone = dsp.osc(dsp.glide(650 * pf, 180 * pf, 0.3, 1.4), shape="sine") * dsp.exp_env(n, 0.12)
    pop = dsp.osc(dsp.glide(1100, 300, 0.035), shape="sine") * dsp.exp_env(n_of(0.035), 0.012)
    return dsp.reverb(stack((deflate, 0, 0.7), (tone, 0, 0.55), (pop, 0.31, 0.8), (dsp.sparkle(0.4, PENTA, 18, 0.3), 0.3, 0.45)), 0.35, 0.15)


def die_kraken(v):
    sub = dsp.osc(dsp.glide(90, 28, 1.6, 2.5), shape="sine") * dsp.exp_env(n_of(1.6), 0.5)
    f = dsp.glide(95, 35, 1.8, 1.8)
    groan = dsp.lp(dsp.osc(f, shape="saw"), 420) * dsp.swell_env(n_of(1.8), 0.12, 1.2, 1.1)
    splash = dsp.sweep_filter(dsp.noise(1.2), 5000, 500, "low") * dsp.exp_env(n_of(1.2), 0.35)
    shimmer = dsp.hp(dsp.noise(1.4), 6500) * dsp.swell_env(n_of(1.4), 0.2, 1.4, 1.3) * 0.18
    crack = dsp.bp(dsp.noise(0.12), 700, 4500) * dsp.exp_env(n_of(0.12), 0.03)
    x = stack((sub, 0, 1.0), (groan, 0.02, 0.8), (splash, 0.0, 0.5), (shimmer, 0.15, 0.6), (crack, 0, 0.8),
              (dsp.sparkle(1.2, PENTA, 14, 0.35), 0.5, 0.6))
    return dsp.reverb(x, 1.3, 0.3)


# ------------------------------------------------------------------ zone / boss
def splash_heavy(v):
    pf = pf_of(v, 0.05)
    sub = dsp.osc(dsp.glide(95 * pf, 28 * pf, 0.9, 3), shape="sine") * dsp.exp_env(n_of(0.9), 0.28)
    crack = dsp.bp(dsp.noise(0.14), 900, 4500) * dsp.exp_env(n_of(0.14), 0.02)
    rumble = dsp.lp(dsp.noise(1.0, "brown"), 220) * dsp.exp_env(n_of(1.0), 0.33)
    sand = (dsp.hp(dsp.noise(0.6), 2200) * dsp.ad_env(n_of(0.6), 0.01, 0.16) * 0.4
            + dsp.crackle(0.6, 1400, 3500) * dsp.exp_env(n_of(0.6), 0.2) * 0.55)
    wood = dsp.modal(150 * pf, 0.3, [1, 2.4, 4.9], [1, 0.6, 0.3], [0.1, 0.06, 0.03])
    return dsp.reverb(stack((sub, 0, 1.0), (crack, 0, 0.9), (rumble, 0, 0.8), (sand, 0.02, 0.6), (wood, 0, 0.5)), 0.9, 0.3)


def boss_slam(v):
    big = splash_heavy(0)
    sub = dsp.osc(dsp.glide(70, 22, 1.4, 3), shape="sine") * dsp.exp_env(n_of(1.4), 0.4)
    debris = dsp.crackle(1.0, 1800, 2000) * dsp.exp_env(n_of(1.0), 0.3)
    return dsp.reverb(stack((big, 0, 0.9), (sub, 0, 1.0), (debris, 0.1, 0.6)), 1.2, 0.3)


def boss_roar(v):
    dur = 1.5
    n = n_of(dur)
    t = np.arange(n) / SR
    f = dsp.glide(88, 54, dur, 1.4) * (1.0 + 0.02 * np.sin(2 * np.pi * 5 * t))
    am = 0.62 + 0.38 * np.sin(2 * np.pi * 26 * t)
    saw = dsp.osc(f, shape="saw")
    formant = dsp.sweep_filter(saw, 450, 950, "band", 1.3) * 1.2 + dsp.lp(saw, 600) * 0.7
    growl = dsp.lp(dsp.noise(dur), 1100) * 0.25
    x = (formant + growl) * am * dsp.swell_env(n, 0.3, 1.5, 1.2)
    return dsp.reverb(x, 0.9, 0.22)


def boss_warning(v):
    dur = 2.4
    n = n_of(dur)
    drone = dsp.osc(55.0, dur, "saw") * 0.6 + dsp.osc(82.4, dur, "saw") * 0.4
    drone = dsp.sweep_filter(drone, 160, 900, "low", curve=0.8) * dsp.swell_env(n, 0.8, 1.5, 1.2)
    riser = dsp.sweep_filter(dsp.noise(dur), 300, 6500, "band", 1.6, curve=1.2) * (np.linspace(0, 1, n) ** 2) * 0.5
    parts = [(drone, 0, 0.9), (riser, 0, 0.7)]
    for tt in (0.2, 0.55, 1.15, 1.5):
        parts.append((dsp.osc(dsp.glide(85, 42, 0.18, 3), shape="sine") * dsp.exp_env(n_of(0.18), 0.07), tt, 1.0))
    return dsp.reverb(stack(*parts), 1.2, 0.25)


def boss_charge(v):
    dur = 0.9
    n = n_of(dur)
    t = np.arange(n) / SR
    f = dsp.glide(90, 520, dur, 0.7)
    x = dsp.sweep_filter(dsp.osc(f, shape="saw"), 250, 2200, "low")
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * (20 + 20 * t / dur) * t)
    x *= dsp.swell_env(n, 0.9, 1.4, 1.0)
    return dsp.reverb(x, 0.4, 0.15)


def boss_phase(v):
    return dsp.reverb(stack((boss_roar(0)[: n_of(1.0)], 0, 0.9),
                            (dsp.osc(dsp.glide(80, 30, 0.8, 3), shape="sine") * dsp.exp_env(n_of(0.8), 0.25), 0, 1.0)), 0.9, 0.25)


def boss_defeated(v):
    boom = splash_heavy(0)
    parts = [(boom, 0, 1.0), (die_kraken(0), 0.0, 0.6)]
    arp = [dsp.hz(x) for x in ("C5", "E5", "G5", "C6", "E6", "G6", "C7")]
    for i, f in enumerate(arp):
        parts.append((I.marimba(f, 0.7, 0.9), 0.9 + 0.075 * i, 0.55))
    parts.append((I.steel(dsp.hz("C5"), 1.6, 0.9), 1.55, 0.5))
    parts.append((I.steel(dsp.hz("G5"), 1.6, 0.9), 1.55, 0.35))
    parts.append((dsp.hp(dsp.noise(1.6), 6000) * dsp.swell_env(n_of(1.6), 0.25, 1.3, 1.5) * 0.12, 1.0, 1.0))
    parts.append((dsp.sparkle(1.8, PENTA, 24, 0.5), 1.0, 0.6))
    return dsp.reverb(stack(*parts), 1.4, 0.28)


# ------------------------------------------------------------------ vie des ennemis
def enemy_spawn(v):
    pf = pf_of(v, 0.1)
    n = n_of(0.12)
    b1 = dsp.osc(dsp.glide(280 * pf, 760 * pf, 0.12, 1.5), shape="sine") * dsp.ad_env(n, 0.005, 0.05)
    b2 = dsp.osc(dsp.glide(400 * pf, 1000 * pf, 0.08, 1.5), shape="sine") * dsp.ad_env(n_of(0.08), 0.004, 0.03)
    puff = dsp.hp(dsp.noise(0.12), 1500) * dsp.exp_env(n_of(0.12), 0.04) * 0.4
    return stack((b1, 0, 0.8), (b2, 0.07, 0.5), (puff, 0.02, 0.5))


def enemy_windup(v):
    pf = pf_of(v, 0.1)
    dur = 0.3
    n = n_of(dur)
    t = np.arange(n) / SR
    f = dsp.glide(95 * pf, 150 * pf, dur, 1.0)
    x = dsp.lp(dsp.osc(f, shape="saw"), 650) * (0.55 + 0.45 * np.sin(2 * np.pi * 28 * t)) * dsp.swell_env(n, 0.8, 1.5, 1.0)
    return x


def combat_activate(v):
    tick = I.marimba(dsp.hz("E6"), 0.2, 0.5)
    return stack((whoosh(0.28, 800, 3500, 1.2, 0.5), 0, 0.55), (tick, 0.1, 0.3), (dsp.click(0.008, 1400), 0, 0.5))


# ------------------------------------------------------------------ pièces
def coin_spawn(v):
    f = dsp.hz(["G6", "E6", "A6"][v % 3])
    return dsp.fm_bell(f, 0.18, 3.5, 1.5, 0.06, 0.03)


def coin_get(i):
    f = COIN_NOTES[i % len(COIN_NOTES)]
    main = dsp.fm_bell(f, 0.45, 3.5, 2.4, 0.2, 0.08)
    over = dsp.fm_bell(f * 2, 0.3, 3.5, 1.6, 0.1, 0.05)
    return stack((main, 0, 0.8), (over, 0.004, 0.3), (dsp.click(0.004, 6500), 0, 0.3))


def multi_kill(v):
    parts = []
    for i, nname in enumerate(("C5", "E5", "G5", "C6", "E6")):
        parts.append((I.marimba(dsp.hz(nname), 0.6, 0.9), 0.06 * i, 0.7))
    parts.append((dsp.hp(dsp.noise(0.9), 5000) * dsp.swell_env(n_of(0.9), 0.3, 1.3, 1.5) * 0.12, 0.1, 1.0))
    parts.append((dsp.sparkle(0.9, PENTA, 26, 0.5), 0.2, 0.6))
    return dsp.reverb(stack(*parts), 0.8, 0.24)


# ------------------------------------------------------------------ jingles
def wave_start(v):
    parts = [(I.horn(dsp.hz("C4"), 1.3, 0.8), 0.0, 0.8), (I.horn(dsp.hz("G4"), 1.3, 0.8), 0.02, 0.45)]
    for i, nname in enumerate(("G5", "C6", "E6")):
        parts.append((I.marimba(dsp.hz(nname), 0.6, 0.8), 0.45 + 0.1 * i, 0.5))
    for i in range(8):
        parts.append((I.shaker(0.5 + 0.05 * i), 0.1 + 0.06 * i, 0.5))
    return dsp.reverb(stack(*parts), 0.9, 0.25)


def wave_clear(v):
    parts = []
    for i, nname in enumerate(("C5", "E5", "G5", "C6")):
        parts.append((I.marimba(dsp.hz(nname), 0.7, 0.9), 0.09 * i, 0.65))
    for nname in ("C5", "G5", "E6"):
        parts.append((I.steel(dsp.hz(nname), 1.2, 0.9), 0.4, 0.35))
    parts.append((I.shaker(0.8), 0.4, 0.6))
    parts.append((dsp.sparkle(0.8, PENTA, 20, 0.4), 0.4, 0.5))
    return dsp.reverb(stack(*parts), 0.8, 0.24)


def game_over(v):
    parts = []
    for i, nname in enumerate(("G5", "E5", "C5")):
        parts.append((I.marimba(dsp.hz(nname), 0.9, 0.8), 0.25 * i, 0.7))
    f = dsp.glide(196, 130, 1.0, 1.2)
    womp = dsp.lp(dsp.osc(f, shape="saw"), 520) * dsp.swell_env(n_of(1.0), 0.2, 1.4, 1.2)
    parts.append((womp, 0.75, 0.8))
    parts.append((I.pad([dsp.hz("C3"), dsp.hz("G3"), dsp.hz("Eb4")], 1.6, 0.5), 0.7, 0.4))
    return dsp.reverb(stack(*parts), 1.1, 0.26)


def turret_upgrade(v):
    parts = []
    for i, nname in enumerate(("C5", "E5", "G5", "C6")):
        parts.append((I.marimba(dsp.hz(nname), 0.6, 0.9), 0.045 * i, 0.65))
    parts.append((whoosh(0.7, 500, 6000, 1.6, 0.7, 1.2), 0, 0.35))
    parts.append((dsp.fm_bell(dsp.hz("C7"), 0.5, 3.5, 2.0, 0.25, 0.08), 0.22, 0.45))
    parts.append((dsp.fm_bell(dsp.hz("E7"), 0.5, 3.5, 2.0, 0.25, 0.08), 0.3, 0.35))
    parts.append((dsp.sparkle(0.8, PENTA, 22, 0.4), 0.15, 0.5))
    return dsp.reverb(stack(*parts), 0.7, 0.22)


# ------------------------------------------------------------------ héros
def player_hurt(v):
    pf = pf_of(v, 0.07)
    n = n_of(0.3)
    t = np.arange(n) / SR
    f = dsp.glide(900 * pf, 380 * pf, 0.3, 2.0) * (1.0 + 0.03 * np.sin(2 * np.pi * 18 * t))
    squeak = (dsp.osc(f, shape="sine") + 0.3 * dsp.osc(f * 2, shape="sine")) * dsp.exp_env(n, 0.11)
    thump = dsp.osc(dsp.glide(130, 58, 0.14), shape="sine") * dsp.exp_env(n_of(0.14), 0.05)
    slap = dsp.bp(dsp.noise(0.1), 700, 3000) * dsp.exp_env(n_of(0.1), 0.03)
    return dsp.reverb(stack((squeak, 0.01, 0.65), (thump, 0, 0.95), (slap, 0, 0.5)), 0.3, 0.12)


def player_death(v):
    dur = 1.1
    n = n_of(dur)
    t = np.arange(n) / SR
    f = dsp.glide(1400, 180, dur, 1.5) * (1.0 + 0.04 * np.sin(2 * np.pi * 6 * t) * (t / dur))
    whistle = dsp.osc(f, shape="sine") * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t)) * dsp.ad_env(n, 0.02, 0.9)
    thump = dsp.osc(dsp.glide(140, 45, 0.3, 3), shape="sine") * dsp.exp_env(n_of(0.3), 0.1)
    womp = dsp.lp(dsp.osc(dsp.glide(220, 90, 0.8, 1.2), shape="saw"), 380) * dsp.swell_env(n_of(0.8), 0.2, 1.3, 1.2)
    parts = [(whistle, 0.0, 0.55), (thump, 0.0, 1.0), (womp, 0.15, 0.7)]
    for i, (a, b) in enumerate(((700, 250), (520, 200), (420, 160))):
        parts.append((dsp.osc(dsp.glide(a, b, 0.07), shape="sine") * dsp.exp_env(n_of(0.07), 0.03), 0.9 + 0.1 * i, 0.4))
    return dsp.reverb(stack(*parts), 0.9, 0.24)


def step_sand(v):
    centers = [1400, 1900, 1600, 2300]
    c = centers[v % 4]
    shuffle = dsp.bp(dsp.noise(0.09), c * 0.5, c * 2.0) * dsp.ad_env(n_of(0.09), 0.004, 0.03)
    grit = dsp.crackle(0.08, 2200, 2600) * dsp.exp_env(n_of(0.08), 0.03)
    return stack((shuffle, 0, 0.8), (grit, 0.002, 0.5))


# ------------------------------------------------------------------ interface
def ui_tap(v):
    n = n_of(0.1)
    pop = dsp.osc(dsp.glide(720, 430, 0.1, 3), shape="sine") * dsp.exp_env(n, 0.03)
    return stack((pop, 0, 0.8), (dsp.click(0.006, 2800), 0, 0.3))


def ui_confirm(v):
    return dsp.reverb(stack((I.marimba(dsp.hz("E5"), 0.4, 0.8), 0, 0.7), (I.marimba(dsp.hz("B5"), 0.5, 0.8), 0.07, 0.7)), 0.4, 0.14)


def ui_denied(v):
    n = n_of(0.26)
    bonk = dsp.osc(dsp.glide(190, 120, 0.26, 2), shape="sine") * dsp.exp_env(n, 0.09)
    bonk2 = dsp.osc(dsp.glide(205, 128, 0.26, 2), shape="tri") * dsp.exp_env(n, 0.06)
    return stack((bonk, 0, 0.8), (bonk2, 0.0, 0.4), (dsp.lp(dsp.noise(0.06), 600) * dsp.exp_env(n_of(0.06), 0.02), 0, 0.5))


def ui_open(v):
    return dsp.reverb(stack((whoosh(0.2, 600, 3000, 1.3, 0.7), 0, 0.5), (I.marimba(dsp.hz("G5"), 0.35, 0.6), 0.1, 0.5)), 0.3, 0.1)


def ui_close(v):
    return dsp.reverb(stack((whoosh(0.18, 3000, 600, 1.3, 0.3), 0, 0.5), (I.marimba(dsp.hz("D5"), 0.3, 0.6), 0.05, 0.5)), 0.3, 0.1)


def ui_buy(v):
    parts = [(coin_get(i), 0.07 * i, 0.5) for i in (2, 3, 5)]
    for nname in ("C5", "G5", "C6"):
        parts.append((I.marimba(dsp.hz(nname), 0.6, 0.9), 0.22, 0.5))
    parts.append((dsp.sparkle(0.6, PENTA, 22, 0.4), 0.2, 0.5))
    return dsp.reverb(stack(*parts), 0.6, 0.2)


def ui_toggle(v):
    return stack((I.marimba(dsp.hz("A5"), 0.2, 0.6), 0, 0.7), (dsp.click(0.006, 2400), 0, 0.5))


# ------------------------------------------------------------------ ambiance (stéréo, boucle)
def amb_beach(loop_s=32.0, xfade=1.6):
    """Mer, écume, vent léger et quelques mouettes : boucle parfaite par fondu enchaîné circulaire."""
    total = loop_s + xfade
    n = n_of(total)
    t = np.arange(n) / SR
    chans = []
    for c in range(2):
        pink = dsp.noise(total, "pink")
        phase = 0.7 * c
        # Période des houles : diviseurs de la durée de boucle -> enveloppe périodique.
        swell = 0.5 + 0.5 * np.sin(2 * np.pi * (4.0 * t / loop_s) + phase)
        swell2 = 0.5 + 0.5 * np.sin(2 * np.pi * (5.0 * t / loop_s) + 2.0 + phase)
        env = (0.25 + 0.75 * (0.6 * swell + 0.4 * swell2)) ** 1.6
        surf = dsp.lp(pink, 900) * env * 0.9
        foam = dsp.hp(dsp.noise(total), 3000) * env ** 3 * 0.22
        rumble = dsp.lp(dsp.noise(total, "brown"), 160) * (0.4 + 0.6 * env) * 0.5
        wind = dsp.bp(dsp.noise(total), 300, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * (3.0 * t / loop_s) + c)) * 0.05
        chans.append(surf + foam + rumble + wind)
    st = np.stack(chans, axis=1)
    # Mouettes (cris courts, très discrets).
    gulls = [(5.2, -0.5), (14.8, 0.6), (23.5, -0.2)]
    for start, p in gulls:
        dur = 0.45
        gt = np.arange(n_of(dur)) / SR
        f = dsp.glide(1700, 2500, dur, 1.2) * (1.0 + 0.05 * np.sin(2 * np.pi * 22 * gt)) * (1.0 - 0.3 * (gt / dur))
        call = (dsp.osc(f, shape="sine") + 0.4 * dsp.osc(f * 2, shape="sine")) * dsp.ad_env(n_of(dur), 0.04, 0.16)
        st = dsp.place(st, dsp.pan(call, p) * 0.06, start)[:n]
    st = dsp.hp(st, 25.0, 2)  # pas de composante continue (rumble brun)
    head = st[:n_of(loop_s)].copy()
    tail = st[n_of(loop_s):n_of(loop_s) + n_of(xfade)]
    k = len(tail)
    w = np.linspace(0, 1, k)[:, None]
    head[:k] = head[:k] * np.sin(w * np.pi / 2) + tail * np.cos(w * np.pi / 2)
    return head


# nom -> (fonction, variantes, pic cible dBFS)
REGISTRY = {
    "throw_rapid": (throw_rapid, 3, -9.0),
    "throw_heavy": (throw_heavy, 2, -5.0),
    "throw_multi": (throw_multi, 2, -9.0),
    "throw_pierce": (throw_pierce, 2, -9.0),
    "hit_rapid": (hit_rapid, 3, -7.0),
    "hit_heavy": (hit_heavy, 2, -3.5),
    "hit_multi": (hit_multi, 2, -9.0),
    "hit_pierce": (hit_pierce, 2, -8.0),
    "mat_shell": (mat_shell, 2, -9.0),
    "mat_squish": (mat_squish, 2, -9.0),
    "mat_hollow": (mat_hollow, 2, -8.0),
    "mat_bubble": (mat_bubble, 2, -9.0),
    "mat_kraken": (mat_kraken, 2, -6.0),
    "die_shell": (die_shell, 2, -6.0),
    "die_squish": (die_squish, 2, -6.0),
    "die_hollow": (die_hollow, 2, -5.5),
    "die_bubble": (die_bubble, 2, -6.0),
    "die_kraken": (die_kraken, 1, -2.0),
    "splash_heavy": (splash_heavy, 2, -2.5),
    "boss_slam": (boss_slam, 1, -1.5),
    "boss_roar": (boss_roar, 1, -3.0),
    "boss_warning": (boss_warning, 1, -3.0),
    "boss_charge": (boss_charge, 1, -5.0),
    "boss_phase": (boss_phase, 1, -2.5),
    "boss_defeated": (boss_defeated, 1, -2.0),
    "enemy_spawn": (enemy_spawn, 3, -14.0),
    "enemy_windup": (enemy_windup, 2, -13.0),
    "combat_activate": (combat_activate, 1, -12.0),
    "coin_spawn": (coin_spawn, 3, -18.0),
    "coin_get": (coin_get, 8, -9.0),
    "multi_kill": (multi_kill, 1, -4.0),
    "wave_start": (wave_start, 1, -4.0),
    "wave_clear": (wave_clear, 1, -4.0),
    "game_over": (game_over, 1, -3.0),
    "turret_upgrade": (turret_upgrade, 1, -4.5),
    "player_hurt": (player_hurt, 3, -3.0),
    "player_death": (player_death, 1, -2.5),
    "step_sand": (step_sand, 4, -18.0),
    "ui_tap": (ui_tap, 1, -8.0),
    "ui_confirm": (ui_confirm, 1, -6.0),
    "ui_denied": (ui_denied, 1, -8.0),
    "ui_open": (ui_open, 1, -9.0),
    "ui_close": (ui_close, 1, -10.0),
    "ui_buy": (ui_buy, 1, -5.0),
    "ui_toggle": (ui_toggle, 1, -9.0),
}
