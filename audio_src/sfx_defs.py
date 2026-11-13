"""Effets sonores d'AxMob (phase 7) : refonte « arcade d'action » — plus sec, plus percutant, moins
« jouet » que la phase 5 (fini les bulles, marimbas et steel drums). Principes :
 - chaque son est construit en COUCHES : transitoire (clic/claque), corps (grave ou matière),
   queue (air, débris, métal) ; le transitoire donne l'attaque nette, le corps le poids ;
 - HIÉRARCHIE par les pics cibles (REGISTRY) : l'important (dégâts subis, boss, zone) dépasse les
   effets fréquents (lancers, impacts, pièces) ; la musique vit plus bas encore ;
 - les sons fréquents restent courts, ternes dans l'aigu (pas de fatigue) et variés (3+ variantes) ;
 - interface : clics doux et propres, jingles à base de cuivres/cloches discrets (pas de marimba).
Déterministe : graine fixe (dsp.RNG). Sorties mono 44,1 kHz, converties par build_audio.py."""

import numpy as np

import dsp
import instruments as I
from dsp import SR, n_of

H = dsp.hz


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


def thud(f0, f1, dur, tau, curve=4.0):
    """Corps grave : sinus qui chute de f0 à f1."""
    return dsp.osc(dsp.glide(f0, f1, dur, curve), shape="sine") * dsp.exp_env(n_of(dur), tau)


def snap(dur=0.02, lo=1500.0, hi=6000.0, tau=0.005):
    n = n_of(dur)
    return dsp.bp(dsp.noise(dur), lo, hi) * dsp.exp_env(n, tau)


def metal(f, dur=0.4, tau=0.18, ratios=(1.0, 2.32, 4.25, 6.63), amps=(1.0, 0.6, 0.35, 0.2)):
    """Résonance métallique inharmonique (lame, cloche, acier)."""
    return dsp.modal(f, dur, list(ratios), list(amps), [tau, tau * 0.7, tau * 0.5, tau * 0.35])


def formant(f0, dur, formants, vib=0.0, breath=0.1):
    """Voix grognée : scie filtrée par des formants (sons de monstre / de souffle du héros)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    f = f0 * (1.0 + vib * np.sin(2 * np.pi * 6.0 * t))
    src = dsp.osc(f, None, "saw") if False else dsp.osc(f, dur, "saw")
    out = np.zeros(n)
    for fc, bw, g in formants:
        out += dsp.bp(src, fc * (1 - bw), fc * (1 + bw)) * g
    return out + dsp.bp(dsp.noise(dur), 800, 3500) * breath


# ------------------------------------------------------------------ lancers de haches
def throw_rapid(v):
    pf = pf_of(v)
    mech = thud(190 * pf, 95 * pf, 0.07, 0.022) * 0.7
    air = whoosh(0.2, 1400 * pf, 6200 * pf, 1.5, 0.32)
    shing = metal(3300 * pf, 0.1, 0.03, (1.0, 2.7), (1.0, 0.4)) * 0.35
    return dsp.reverb(stack((mech, 0, 0.6), (snap(0.012, 2500, 7000, 0.004), 0, 0.5), (air, 0.005, 0.55), (shing, 0.01, 0.4)), 0.2, 0.08)


def throw_heavy(v):
    pf = pf_of(v, 0.06)
    boom = thud(150 * pf, 44 * pf, 0.5, 0.15)
    chunk = dsp.lp(dsp.noise(0.1), 900) * dsp.exp_env(n_of(0.1), 0.03)
    air = whoosh(0.5, 300 * pf, 2000 * pf, 1.6, 0.3) * 0.8
    return dsp.reverb(stack((boom, 0, 0.9), (chunk, 0, 0.8), (snap(0.015, 900, 3500, 0.005), 0, 0.5), (air, 0.02, 0.6)), 0.4, 0.14)


def throw_multi(v):
    pf = pf_of(v, 0.05)
    parts = []
    for i in range(3):
        s = pf * (1.0 + 0.08 * i)
        parts.append((whoosh(0.14, 1600 * s, 6400 * s, 1.4, 0.3), 0.05 * i, 0.5))
        parts.append((thud(210 * s, 120 * s, 0.05, 0.018), 0.05 * i, 0.4))
        parts.append((snap(0.01, 2800, 7000, 0.003), 0.05 * i, 0.4))
    return dsp.reverb(stack(*parts), 0.22, 0.09)


def throw_pierce(v):
    pf = pf_of(v, 0.06)
    n = n_of(0.4)
    f = dsp.glide(1000 * pf, 3000 * pf, 0.4, 1.8)
    zing = dsp.osc(f, shape="sine") * dsp.ad_env(n, 0.012, 0.11) * 0.35
    air = dsp.hp(whoosh(0.36, 3200, 9500, 1.1, 0.35), 2600) * 0.6
    return dsp.reverb(stack((zing, 0, 0.8), (air, 0, 0.8), (snap(0.01, 4000, 9000, 0.003), 0, 0.5), (thud(160, 90, 0.05, 0.02), 0, 0.4)), 0.28, 0.1)


# ------------------------------------------------------------------ impacts (couche « hache »)
def hit_rapid(v):
    pf = pf_of(v, 0.1)
    body = thud(170 * pf, 85, 0.07, 0.025)
    thwack = dsp.bp(dsp.noise(0.08), 600 * pf, 3200 * pf) * dsp.exp_env(n_of(0.08), 0.022)
    return stack((snap(0.012, 2200, 6000, 0.004), 0, 0.8), (thwack, 0, 0.8), (body, 0, 0.8), (metal(2400 * pf, 0.08, 0.025, (1, 2.4), (1, 0.4)), 0, 0.2))


def hit_heavy(v):
    pf = pf_of(v, 0.07)
    sub = thud(120 * pf, 38 * pf, 0.45, 0.14)
    crack = dsp.bp(dsp.noise(0.12), 700, 5000) * dsp.exp_env(n_of(0.12), 0.026)
    debris = dsp.crackle(0.2, 1800, 2400) * dsp.exp_env(n_of(0.2), 0.08)
    thump = dsp.lp(dsp.noise(0.16), 400) * dsp.exp_env(n_of(0.16), 0.05)
    return dsp.reverb(stack((sub, 0, 1.0), (crack, 0, 0.9), (thump, 0, 0.7), (debris, 0.006, 0.5)), 0.38, 0.14)


def hit_multi(v):
    pf = pf_of(v, 0.1)
    return stack((snap(0.01, 2500, 7000, 0.003), 0, 0.8), (thud(220 * pf, 120, 0.045, 0.016), 0, 0.6), (metal(1800 * pf, 0.07, 0.02, (1, 2.5), (1, 0.4)), 0, 0.25))


def hit_pierce(v):
    pf = pf_of(v, 0.08)
    slice_ = dsp.hp(dsp.noise(0.1), 2800) * dsp.exp_env(n_of(0.1), 0.03)
    return dsp.reverb(stack((slice_, 0, 0.8), (metal(2600 * pf, 0.3, 0.12), 0, 0.4), (snap(0.01, 4500, 9000, 0.003), 0, 0.6), (thud(140, 80, 0.05, 0.02), 0, 0.4)), 0.25, 0.1)


# ------------------------------------------------------------------ matières des ennemis
def mat_shell(v):
    pf = pf_of(v, 0.07)
    return stack((snap(0.015, 2000 * pf, 6500, 0.005), 0, 0.7), (dsp.crackle(0.1, 1800, 3500), 0, 0.5), (thud(260 * pf, 140, 0.05, 0.016), 0, 0.5))


def mat_squish(v):
    pf = pf_of(v, 0.07)
    wet = dsp.bp(dsp.noise(0.12), 250 * pf, 1400) * dsp.exp_env(n_of(0.12), 0.035)
    return stack((wet, 0, 0.8), (thud(140 * pf, 70, 0.08, 0.03), 0, 0.7), (snap(0.01, 900, 2800, 0.004), 0, 0.3))


def mat_hollow(v):
    pf = pf_of(v, 0.06)
    return stack((thud(210 * pf, 120 * pf, 0.1, 0.04), 0, 0.8), (dsp.bp(dsp.noise(0.06), 500, 1800) * dsp.exp_env(n_of(0.06), 0.014), 0, 0.5), (snap(0.008, 1500, 4000, 0.003), 0, 0.3))


def mat_bubble(v):
    pf = pf_of(v, 0.08)
    return stack((thud(320 * pf, 150, 0.07, 0.025), 0, 0.7), (dsp.bp(dsp.noise(0.09), 800, 2800) * dsp.exp_env(n_of(0.09), 0.022), 0, 0.5), (snap(0.008, 2000, 5000, 0.003), 0, 0.3))


def mat_kraken(v):
    pf = pf_of(v, 0.05)
    return dsp.reverb(stack((thud(120 * pf, 55, 0.3, 0.1), 0, 0.9), (dsp.bp(dsp.noise(0.2), 200, 1200) * dsp.exp_env(n_of(0.2), 0.06), 0, 0.7), (snap(0.012, 800, 3000, 0.005), 0, 0.5)), 0.4, 0.12)


# ------------------------------------------------------------------ morts
def die_shell(v):
    pf = pf_of(v, 0.07)
    shatter = dsp.crackle(0.4, 1500, 3000) * dsp.exp_env(n_of(0.4), 0.14)
    return dsp.reverb(stack((snap(0.02, 1500, 7000, 0.008), 0, 0.8), (thud(180 * pf, 60, 0.25, 0.08), 0, 0.9), (shatter, 0.01, 0.8), (metal(1500 * pf, 0.3, 0.1, (1, 1.8, 3.1), (1, 0.5, 0.3)), 0.02, 0.18)), 0.35, 0.12)


def die_squish(v):
    pf = pf_of(v, 0.07)
    splat = dsp.bp(dsp.noise(0.3), 220, 2200) * dsp.exp_env(n_of(0.3), 0.07)
    return dsp.reverb(stack((thud(150 * pf, 50, 0.25, 0.09), 0, 0.9), (splat, 0, 0.8), (snap(0.015, 1000, 3500, 0.006), 0, 0.5), (dsp.crackle(0.15, 700, 1800), 0.03, 0.3)), 0.3, 0.1)


def die_hollow(v):
    pf = pf_of(v, 0.05)
    n = n_of(0.5)
    deflate = dsp.sweep_filter(dsp.noise(0.5), 5200, 500, "low") * dsp.exp_env(n, 0.17) * 0.5
    return dsp.reverb(stack((snap(0.012, 2000, 6000, 0.004), 0, 0.8), (thud(260 * pf, 80, 0.2, 0.06), 0, 0.9), (deflate, 0.01, 0.8)), 0.3, 0.1)


def die_bubble(v):
    pf = pf_of(v, 0.07)
    return dsp.reverb(stack((snap(0.012, 1800, 6000, 0.004), 0, 0.8), (thud(300 * pf, 90, 0.18, 0.05), 0, 0.9), (dsp.hp(dsp.noise(0.3), 2500) * dsp.exp_env(n_of(0.3), 0.06), 0.005, 0.5)), 0.3, 0.1)


def die_kraken(v):
    boom = thud(95, 30, 1.2, 0.35, 3.0)
    roar = formant(70, 1.4, [(300, 0.4, 1.0), (850, 0.3, 0.6)], 0.01, 0.2) * dsp.swell_env(n_of(1.4), 0.15, 1.2, 1.4)
    debris = dsp.crackle(1.0, 1400, 2200) * dsp.exp_env(n_of(1.0), 0.35)
    water = dsp.bp(dsp.noise(1.2), 300, 2500) * dsp.swell_env(n_of(1.2), 0.25, 1.5, 1.8) * 0.5
    return dsp.reverb(stack((boom, 0, 1.0), (roar, 0, 0.6), (snap(0.03, 600, 4000, 0.01), 0, 0.8), (debris, 0.03, 0.6), (water, 0.1, 0.5)), 0.9, 0.2)


# ------------------------------------------------------------------ zones, boss
def splash_heavy(v):
    pf = pf_of(v, 0.05)
    boom = thud(100 * pf, 34, 0.7, 0.2)
    wave = whoosh(0.6, 200, 3000, 1.6, 0.18, 0.9) * 0.9
    return dsp.reverb(stack((boom, 0, 1.0), (dsp.bp(dsp.noise(0.2), 500, 4500) * dsp.exp_env(n_of(0.2), 0.04), 0, 0.8), (wave, 0.01, 0.55), (dsp.crackle(0.3, 1500, 2500) * dsp.exp_env(n_of(0.3), 0.1), 0.03, 0.4)), 0.6, 0.16)


def boss_slam(v):
    boom = thud(85, 26, 1.4, 0.4, 3.0)
    crack = dsp.bp(dsp.noise(0.25), 400, 6000) * dsp.exp_env(n_of(0.25), 0.05)
    rumble = dsp.lp(dsp.noise(1.5, "brown"), 150) * dsp.exp_env(n_of(1.5), 0.5)
    debris = dsp.crackle(1.0, 1200, 2500) * dsp.exp_env(n_of(1.0), 0.3)
    return dsp.reverb(stack((boom, 0, 1.0), (crack, 0, 0.9), (rumble, 0, 0.7), (debris, 0.04, 0.5), (I.taiko(48, 0.8), 0, 0.5)), 1.0, 0.2)


def boss_roar(v):
    n = n_of(1.6)
    sweep = dsp.glide(95, 60, 1.6, 1.5)
    t = np.arange(n) / SR
    src = dsp.osc(sweep * (1.0 + 0.02 * np.sin(2 * np.pi * 8 * t)), shape="saw")
    out = np.zeros(n)
    for fc, bw, g in ((280, 0.35, 1.0), (760, 0.3, 0.8), (1900, 0.3, 0.3)):
        out += dsp.bp(src, fc * (1 - bw), fc * (1 + bw)) * g
    out = dsp.sat(out + dsp.bp(dsp.noise(1.6), 500, 2500) * 0.25, 2.2) * dsp.swell_env(n, 0.18, 1.3, 1.3)
    return dsp.reverb(out, 0.8, 0.2)


def boss_warning(v):
    parts = []
    for i in range(3):
        parts.append((I.brass_stab(H("A3"), 0.28, 0.9), 0.38 * i, 0.55))
        parts.append((I.brass_stab(H("D#4"), 0.28, 0.85), 0.38 * i, 0.45))
        parts.append((I.taiko(70.0, 0.9), 0.38 * i, 0.5))
    parts.append((I.riser(1.2, 0.7), 0.0, 0.3))
    return dsp.reverb(stack(*parts), 0.6, 0.18)


def boss_charge(v):
    n = n_of(0.9)
    rise = whoosh(0.9, 200, 4500, 1.3, 0.7, 1.1)
    eng = dsp.osc(dsp.glide(60, 130, 0.9, 1.8), shape="saw") * dsp.swell_env(n, 0.8, 1.4, 1.3) * 0.3
    return dsp.reverb(stack((rise, 0, 0.9), (dsp.lp(eng, 700), 0, 0.8), (thud(100, 50, 0.3, 0.1), 0.0, 0.5)), 0.4, 0.1)


def boss_phase(v):
    return dsp.reverb(stack((thud(100, 32, 1.0, 0.3), 0, 1.0), (I.crash(0.9), 0.0, 0.5), (I.riser(0.5, 0.6), 0, 0.4), (I.taiko(60, 0.9), 0.0, 0.7), (I.brass_stab(H("D3"), 0.5, 0.9), 0.04, 0.5)), 0.8, 0.18)


def boss_defeated(v):
    parts = [(thud(90, 30, 1.2, 0.35), 0, 1.0), (I.crash(1.0), 0.0, 0.6), (I.taiko(60, 1.0), 0.0, 0.7)]
    for i, nname in enumerate(("D4", "F4", "A4", "D5")):
        parts.append((I.brass_stab(H(nname), 0.6, 0.9), 0.35 + 0.16 * i, 0.5))
        parts.append((I.strings_long([H(nname)], 1.2, 0.6, 0.1, 0.8), 0.35 + 0.16 * i, 0.3))
    parts.append((I.brass_stab(H("D5"), 1.6, 1.0), 1.05, 0.65))
    parts.append((I.glock(H("D6"), 1.6, 0.6), 1.05, 0.3))
    return dsp.reverb(stack(*parts), 1.1, 0.22)


# ------------------------------------------------------------------ apparitions, combat
def spawn_water(v):
    """Un ennemi surgit de l'eau : éclaboussure montante + gouttes + petit grondement."""
    pf = pf_of(v, 0.1)
    splash = whoosh(0.4, 500 * pf, 4500, 1.4, 0.3, 0.9) * 0.9
    drops = dsp.crackle(0.35, 900, 5200) * dsp.exp_env(n_of(0.35), 0.12)
    gloop = thud(240 * pf, 90, 0.18, 0.06) * 0.7
    return dsp.reverb(stack((splash, 0, 0.8), (drops, 0.03, 0.55), (gloop, 0.02, 0.8), (snap(0.02, 1500, 6000, 0.008), 0, 0.5)), 0.3, 0.1)


def spawn_sand(v):
    """Un ennemi sort du sable : éclatement sourd + sable qui retombe + cailloux."""
    pf = pf_of(v, 0.1)
    burst = dsp.bp(dsp.noise(0.28), 300 * pf, 3200) * dsp.exp_env(n_of(0.28), 0.07)
    grains = dsp.crackle(0.4, 1300, 4200) * dsp.exp_env(n_of(0.4), 0.14)
    return stack((thud(130 * pf, 60, 0.2, 0.07), 0, 0.9), (burst, 0, 0.8), (grains, 0.03, 0.55), (snap(0.012, 900, 3000, 0.005), 0, 0.4))


def enemy_windup(v):
    pf = pf_of(v, 0.1)
    n = n_of(0.3)
    return stack((whoosh(0.3, 400 * pf, 1800 * pf, 1.4, 0.8), 0, 0.5), (dsp.osc(dsp.glide(120 * pf, 200 * pf, 0.3, 1.5), shape="saw") * dsp.swell_env(n, 0.85, 1.6, 1.2) * 0.12, 0, 0.5))


def combat_activate(v):
    n = n_of(0.5)
    pulse = thud(110, 70, 0.25, 0.09)
    rise = whoosh(0.45, 300, 3500, 1.3, 0.75, 1.1) * 0.6
    return dsp.reverb(stack((pulse, 0, 0.7), (rise, 0, 0.5), (metal(900, 0.3, 0.12, (1, 1.5, 2.0), (1, 0.5, 0.3)), 0.02, 0.15)), 0.35, 0.1)


# ------------------------------------------------------------------ pièces, progression
def coin_spawn(v):
    pf = pf_of(v, 0.06)
    return stack((metal(2800 * pf, 0.07, 0.02, (1, 2.4), (1, 0.4)), 0, 0.4), (snap(0.006, 3500, 8000, 0.002), 0, 0.3))


COIN_STEPS = [0, 2, 4, 7, 9, 12, 14, 16]


def coin_get(v):
    f = H("D6") * 2.0 ** (COIN_STEPS[v % 8] / 12.0)
    return dsp.reverb(stack((metal(f, 0.4, 0.14, (1.0, 2.0, 3.01, 4.2), (1.0, 0.45, 0.25, 0.15)), 0, 0.8), (snap(0.008, 4000, 9000, 0.002), 0, 0.5), (metal(f * 1.5, 0.2, 0.07, (1, 2.0), (1, 0.4)), 0.03, 0.3)), 0.25, 0.08)


def multi_kill(v):
    parts = [(whoosh(0.5, 400, 5000, 1.4, 0.5), 0, 0.6), (I.taiko(78.0, 0.9), 0.0, 0.6), (I.crash(0.7), 0.1, 0.3)]
    for i, nname in enumerate(("D5", "F5", "A5", "D6")):
        parts.append((I.glock(H(nname), 0.7, 0.8), 0.18 + 0.07 * i, 0.4))
    return dsp.reverb(stack(*parts), 0.6, 0.15)


def wave_start(v):
    parts = [(I.taiko(66.0, 1.0), 0.0, 0.7), (I.taiko(88.0, 0.9), 0.22, 0.5)]
    for k, nname in enumerate(("D4", "A4")):
        parts.append((I.brass_stab(H(nname), 0.45, 0.9), 0.44 if k == 0 else 0.44, 0.5))
    parts.append((I.brass_stab(H("F4"), 0.45, 0.9), 0.44, 0.4))
    parts.append((I.crash(0.8), 0.44, 0.3))
    return dsp.reverb(stack(*parts), 0.7, 0.16)


def wave_clear(v):
    parts = []
    for i, nname in enumerate(("D4", "F4", "A4", "D5")):
        parts.append((I.brass_stab(H(nname), 0.3, 0.85), 0.11 * i, 0.5))
    parts.append((I.brass_stab(H("D5"), 0.9, 0.9), 0.46, 0.5))
    parts.append((I.brass_stab(H("A4"), 0.9, 0.8), 0.46, 0.4))
    parts.append((I.strings_long([H("D4"), H("A4"), H("D5")], 1.0, 0.6, 0.05, 0.7), 0.4, 0.35))
    parts.append((I.glock(H("A6"), 1.2, 0.6), 0.5, 0.3))
    return dsp.reverb(stack(*parts), 0.8, 0.18)


def game_over(v):
    parts = [(I.taiko(55.0, 1.0), 0.0, 0.8), (thud(90, 30, 1.2, 0.35), 0.0, 0.7)]
    for i, nname in enumerate(("A3", "F3", "D3")):
        parts.append((I.strings_long([H(nname), H(nname) * 1.5], 1.3, 0.6, 0.1, 0.9), 0.3 * i + 0.1, 0.4))
        parts.append((I.brass_stab(H(nname), 0.7, 0.8), 0.3 * i + 0.1, 0.3))
    return dsp.reverb(stack(*parts), 1.2, 0.24)


def turret_upgrade(v):
    ratchet = stack(*[(snap(0.012, 1800, 6000, 0.004), 0.045 * i, 0.4) for i in range(5)])
    power = whoosh(0.45, 400, 6500, 1.3, 0.8, 1.2) * 0.7
    parts = [(ratchet, 0, 0.7), (thud(140, 60, 0.15, 0.05), 0.2, 0.6), (power, 0.05, 0.6)]
    for i, nname in enumerate(("D5", "A5", "D6")):
        parts.append((I.glock(H(nname), 0.9, 0.9), 0.22 + 0.07 * i, 0.4))
        parts.append((I.brass_stab(H(nname) / 2, 0.3, 0.7), 0.22 + 0.07 * i, 0.3))
    return dsp.reverb(stack(*parts), 0.5, 0.13)


def player_hurt(v):
    pf = pf_of(v, 0.07)
    grunt = formant(150 * pf, 0.22, [(520, 0.3, 1.0), (1500, 0.3, 0.5)], 0.0, 0.15) * dsp.ad_env(n_of(0.22), 0.012, 0.09)
    return stack((thud(150 * pf, 55, 0.22, 0.07), 0, 1.0), (snap(0.02, 700, 3500, 0.008), 0, 0.7), (grunt, 0.0, 0.55), (dsp.lp(dsp.noise(0.2), 600) * dsp.exp_env(n_of(0.2), 0.06), 0, 0.5))


def player_death(v):
    n = n_of(1.0)
    fall = dsp.osc(dsp.glide(330, 90, 1.0, 2.0), shape="saw") * dsp.exp_env(n, 0.3) * 0.25
    grunt = formant(130, 0.5, [(450, 0.3, 1.0), (1200, 0.3, 0.5)], 0.0, 0.2) * dsp.ad_env(n_of(0.5), 0.02, 0.18)
    return dsp.reverb(stack((thud(110, 32, 0.9, 0.25), 0, 1.0), (dsp.lp(fall, 1200), 0.05, 0.5), (grunt, 0, 0.6), (I.taiko(52, 0.9), 0.1, 0.5)), 0.7, 0.18)


def step_sand(v):
    pf = pf_of(v, 0.1)
    return stack((dsp.bp(dsp.noise(0.08), 400 * pf, 2400) * dsp.exp_env(n_of(0.08), 0.02), 0, 0.6), (dsp.crackle(0.1, 1600, 3500) * dsp.exp_env(n_of(0.1), 0.03), 0, 0.5), (thud(120 * pf, 70, 0.05, 0.015), 0, 0.4))


# ------------------------------------------------------------------ interface
def ui_tap(v):
    return stack((snap(0.012, 1800, 5200, 0.0035), 0, 0.8), (thud(900, 520, 0.05, 0.012, 2.0), 0, 0.5), (metal(2100, 0.06, 0.015, (1, 2.4), (1, 0.4)), 0, 0.2))


def ui_down(v):
    return stack((snap(0.01, 900, 3200, 0.003), 0, 0.7), (thud(420, 260, 0.04, 0.01, 2.0), 0, 0.5))


def ui_pop(v):
    n = n_of(0.12)
    blip = dsp.osc(dsp.glide(420, 880, 0.12, 2.0), shape="sine") * dsp.ad_env(n, 0.004, 0.05)
    return stack((blip, 0, 0.7), (snap(0.008, 2500, 7000, 0.0025), 0, 0.3))


def ui_whoosh(v):
    return stack((whoosh(0.32, 500, 5500, 1.5, 0.45, 1.0), 0, 0.7), (snap(0.01, 1500, 5000, 0.003), 0.0, 0.2))


def ui_confirm(v):
    parts = []
    for i, nname in enumerate(("A4", "E5")):
        parts.append((I.brass_stab(H(nname), 0.18, 0.75), 0.08 * i, 0.5))
    parts.append((I.glock(H("A6"), 0.5, 0.6), 0.1, 0.3))
    parts.append((snap(0.01, 2000, 6000, 0.003), 0, 0.3))
    return dsp.reverb(stack(*parts), 0.3, 0.1)


def ui_denied(v):
    n = n_of(0.22)
    buzz = dsp.lp(dsp.osc(dsp.glide(140, 100, 0.22, 1.5), shape="square"), 700) * dsp.ad_env(n, 0.005, 0.09) * 0.45
    return stack((thud(170, 80, 0.12, 0.04), 0, 0.8), (buzz, 0, 0.7), (snap(0.008, 600, 2200, 0.003), 0, 0.3))


def ui_open(v):
    return stack((whoosh(0.28, 400, 4200, 1.5, 0.55, 1.0), 0, 0.6), (thud(300, 160, 0.08, 0.025), 0.02, 0.4), (snap(0.01, 1800, 6000, 0.003), 0.0, 0.3), (metal(1500, 0.25, 0.09, (1, 2.0, 3.0), (1, 0.4, 0.2)), 0.1, 0.15))


def ui_close(v):
    return stack((whoosh(0.22, 4200, 400, 1.5, 0.35, 1.0), 0, 0.5), (thud(220, 120, 0.07, 0.022), 0.1, 0.4), (snap(0.01, 1200, 4500, 0.003), 0.14, 0.25))


def ui_buy(v):
    parts = [(snap(0.01, 3000, 8000, 0.003), 0, 0.5), (metal(H("E6"), 0.5, 0.2, (1, 2.0, 3.0, 4.2), (1, 0.5, 0.3, 0.15)), 0.0, 0.7), (metal(H("A6"), 0.5, 0.22, (1, 2.0, 3.0), (1, 0.5, 0.3)), 0.07, 0.6), (thud(160, 80, 0.12, 0.04), 0, 0.5)]
    parts.append((I.brass_stab(H("A4"), 0.2, 0.7), 0.0, 0.25))
    return dsp.reverb(stack(*parts), 0.35, 0.1)


def ui_toggle(v):
    return stack((snap(0.008, 1500, 5000, 0.002), 0, 0.8), (thud(650, 400, 0.04, 0.01, 2.0), 0, 0.5), (snap(0.006, 2500, 7000, 0.0018), 0.045, 0.5))


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



# nom -> (fonction, variantes, pic cible dBFS) : les pics fixent la hiérarchie sonore.
REGISTRY = {
    "throw_rapid": (throw_rapid, 3, -10.0),
    "throw_heavy": (throw_heavy, 2, -6.0),
    "throw_multi": (throw_multi, 2, -10.0),
    "throw_pierce": (throw_pierce, 2, -10.0),
    "hit_rapid": (hit_rapid, 3, -8.0),
    "hit_heavy": (hit_heavy, 2, -4.0),
    "hit_multi": (hit_multi, 2, -10.0),
    "hit_pierce": (hit_pierce, 2, -9.0),
    "mat_shell": (mat_shell, 2, -10.0),
    "mat_squish": (mat_squish, 2, -10.0),
    "mat_hollow": (mat_hollow, 2, -9.0),
    "mat_bubble": (mat_bubble, 2, -10.0),
    "mat_kraken": (mat_kraken, 2, -7.0),
    "die_shell": (die_shell, 2, -7.0),
    "die_squish": (die_squish, 2, -7.0),
    "die_hollow": (die_hollow, 2, -6.5),
    "die_bubble": (die_bubble, 2, -7.0),
    "die_kraken": (die_kraken, 1, -2.0),
    "splash_heavy": (splash_heavy, 2, -3.0),
    "boss_slam": (boss_slam, 1, -1.5),
    "boss_roar": (boss_roar, 1, -3.5),
    "boss_warning": (boss_warning, 1, -3.5),
    "boss_charge": (boss_charge, 1, -6.0),
    "boss_phase": (boss_phase, 1, -3.0),
    "boss_defeated": (boss_defeated, 1, -2.5),
    "spawn_water": (spawn_water, 3, -14.0),
    "spawn_sand": (spawn_sand, 3, -14.0),
    "enemy_windup": (enemy_windup, 2, -14.0),
    "combat_activate": (combat_activate, 1, -13.0),
    "coin_spawn": (coin_spawn, 3, -19.0),
    "coin_get": (coin_get, 8, -10.0),
    "multi_kill": (multi_kill, 1, -5.0),
    "wave_start": (wave_start, 1, -5.0),
    "wave_clear": (wave_clear, 1, -5.0),
    "game_over": (game_over, 1, -4.0),
    "turret_upgrade": (turret_upgrade, 1, -5.5),
    "player_hurt": (player_hurt, 3, -3.5),
    "player_death": (player_death, 1, -3.0),
    "step_sand": (step_sand, 4, -19.0),
    "ui_tap": (ui_tap, 1, -10.0),
    "ui_down": (ui_down, 1, -16.0),
    "ui_pop": (ui_pop, 1, -15.0),
    "ui_whoosh": (ui_whoosh, 1, -12.0),
    "ui_confirm": (ui_confirm, 1, -7.0),
    "ui_denied": (ui_denied, 1, -9.0),
    "ui_open": (ui_open, 1, -10.0),
    "ui_close": (ui_close, 1, -11.0),
    "ui_buy": (ui_buy, 1, -6.0),
    "ui_toggle": (ui_toggle, 1, -10.0),
}
