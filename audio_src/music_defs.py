"""Musique originale d'AxMob (phase 7) : « aventure arcade », tonalité de ré mineur, mixage discret.
Trois morceaux, synthétisés par code (aucun échantillon, aucun droit d'auteur) :
 - run  : « Island Raid »  118 BPM, 16 mesures, 3 couches (stems) synchronisées que le jeu fait entrer
          selon l'intensité du combat : A rythme (batterie, taiko, basse), B harmonie (cordes staccato,
          nappe, cuivres), C mélodie (flûte + lead synthé).
 - boss : « Kraken Rising » 132 BPM, même principe, plus lourd (taiko doublés, basse saturée, cuivres).
 - menu : « Golden Shore »  100 BPM, guitare nylon, nappe de cordes, flûte lyrique, percussions légères.
Intention de mixage : une musique d'ambiance qui porte l'action sans la couvrir — niveaux moyens bas,
mélodie clairsemée (des silences), peu d'énergie dans les médiums où vivent les effets, graves
tenus par la basse et le taiko. Chaque couche est repliée sur sa boucle : bouclage sans couture."""

import numpy as np

import dsp
import instruments as I
from dsp import SR

H = dsp.hz

CHORDS = {
    "Dm": ["D3", "F3", "A3", "D4"],
    "Bb": ["Bb2", "D3", "F3", "Bb3"],
    "F": ["F3", "A3", "C4", "F4"],
    "C": ["C3", "E3", "G3", "C4"],
    "Gm": ["G2", "Bb2", "D3", "G3"],
    "A": ["A2", "C#3", "E3", "A3"],
}
ROOTS = {"Dm": "D2", "Bb": "Bb1", "F": "F2", "C": "C2", "Gm": "G2", "A": "A1"}


class Song:
    """Séquenceur 16 doubles-croches par mesure, rendu stéréo avec repli de boucle."""

    def __init__(self, bpm, bars, tail=3.0):
        self.bpm = bpm
        self.bars = bars
        self.step = 60.0 / bpm / 4.0
        self.loop_s = self.step * 16 * bars
        self.tail = tail
        self.buf = np.zeros((int((self.loop_s + self.tail) * SR), 2))

    def at(self, bar, step):
        return (bar * 16 + step) * self.step

    def add(self, x, t, gain=1.0, pan=0.0):
        st = dsp.pan(x, pan)
        s = int(round(t * SR))
        e = min(s + len(st), len(self.buf))
        if e > s:
            self.buf[s:e] += st[: e - s] * gain

    def render(self, rv=0.5, wet=0.15, drive=1.0, rms=-22.0, hp_hz=32.0):
        x = dsp.reverb(self.buf, rv, wet, 0.55, 0.012, tail=min(rv * 1.2, 2.6))
        n = int(self.loop_s * SR)
        loop = x[:n].copy()
        extra = x[n:]
        loop[: len(extra)] += extra[: len(loop)]
        if drive > 1.0:
            loop = dsp.sat(loop, drive)
        loop = dsp.hp(loop, hp_hz, 2)
        return dsp.normalize_rms(loop, rms)


def _bars(prog):
    return list(enumerate(prog))


def _notes(ch):
    return [H(n) for n in CHORDS[ch]]


# ==========================================================================================
# RUN : Island Raid (ré mineur, 118 BPM)
# ==========================================================================================
RUN_PROG = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "C", "Gm", "Gm", "Bb", "A", "Gm", "Bb", "C", "A"]
RUN_MELODY = [
    # A : motif principal (mesures 0-7) — clair, rythmé, avec des silences
    (0, 0, "A4", 3), (0, 4, "D5", 2), (0, 6, "F5", 2), (0, 8, "E5", 4),
    (1, 0, "D5", 3), (1, 4, "A4", 2), (1, 6, "C5", 2), (1, 8, "D5", 6),
    (2, 0, "F5", 3), (2, 4, "E5", 2), (2, 6, "D5", 2), (2, 8, "F5", 4),
    (3, 0, "G5", 6), (3, 8, "E5", 3), (3, 12, "C5", 3),
    (4, 0, "A4", 3), (4, 4, "D5", 2), (4, 6, "F5", 2), (4, 8, "A5", 4),
    (5, 0, "G5", 3), (5, 4, "F5", 2), (5, 6, "E5", 2), (5, 8, "D5", 6),
    (6, 0, "F5", 3), (6, 4, "D5", 2), (6, 6, "Bb4", 2), (6, 8, "D5", 4),
    (7, 0, "E5", 4), (7, 8, "G5", 3), (7, 12, "E5", 3),
    # B : montée (mesures 8-11)
    (8, 0, "G5", 4), (8, 4, "Bb5", 2), (8, 6, "A5", 2), (8, 8, "G5", 4), (8, 12, "D5", 4),
    (9, 0, "G5", 4), (9, 4, "F5", 2), (9, 6, "G5", 2), (9, 8, "A5", 8),
    (10, 0, "Bb5", 3), (10, 4, "A5", 2), (10, 6, "G5", 2), (10, 8, "F5", 4), (10, 12, "D5", 4),
    (11, 0, "E5", 3), (11, 4, "A5", 3), (11, 8, "C#6", 8),
    # C : retombée (mesures 12-15)
    (12, 0, "D6", 4), (12, 6, "C6", 2), (12, 8, "Bb5", 4), (12, 12, "G5", 4),
    (13, 0, "Bb5", 4), (13, 6, "A5", 2), (13, 8, "F5", 8),
    (14, 0, "G5", 4), (14, 4, "E5", 4), (14, 8, "C5", 4), (14, 12, "E5", 4),
    (15, 0, "E5", 6), (15, 8, "A4", 8),
]


def _drums_run(s, bars, intensity=1.0):
    for bar in range(bars):
        kicks = [0, 6, 10] if bar % 4 != 3 else [0, 6, 10, 14]
        for st in kicks:
            s.add(I.kick(1.0 if st in (0, 10) else 0.8), s.at(bar, st), 0.95)
        for st in (4, 12):
            s.add(I.snare(0.85), s.at(bar, st), 0.62, 0.05)
            s.add(I.clap(0.7), s.at(bar, st), 0.34, -0.1)
        for st in range(0, 16, 2):
            acc = 0.62 if st % 4 == 2 else 0.4
            s.add(I.hat(acc), s.at(bar, st), 0.34 * intensity, 0.3)
        for st in (1, 5, 9, 13):
            s.add(I.hat(0.22), s.at(bar, st), 0.3 * intensity, 0.35)
        if bar % 2 == 1:
            s.add(I.hat(0.7, True), s.at(bar, 14), 0.3, 0.3)
        if bar % 2 == 0:
            s.add(I.taiko(68.0, 0.7), s.at(bar, 0), 0.55)
        if bar % 4 == 3:  # petit roulement de fin de phrase
            for k, st in enumerate((12, 13, 14, 15)):
                s.add(I.snare(0.5 + 0.12 * k), s.at(bar, st), 0.42, 0.05)
            s.add(I.taiko(95.0, 0.8), s.at(bar, 14), 0.5)
    s.add(I.crash(0.8), s.at(0, 0), 0.4, 0.2)
    s.add(I.crash(0.7), s.at(8, 0), 0.3, -0.2)


def _bass_run(s, prog):
    patt = [(0, 1.0, 1.0), (2, 1.0, 0.7), (3, 1.0, 0.55), (6, 2.0, 0.8), (8, 1.0, 0.95), (10, 1.0, 0.7), (11, 1.0, 0.55), (14, 1.5, 0.8)]
    for bar, ch in _bars(prog):
        r = H(ROOTS[ch])
        for st, mult, vel in patt:
            if st == 14 and ch in ("Gm", "A"):
                mult = 2.0
            s.add(I.synth_bass(r * mult, 0.22, vel), s.at(bar, st), 0.88)


def render_run():
    out = {}
    s = Song(118, 16)
    _drums_run(s, 16)
    _bass_run(s, RUN_PROG)
    out["a"] = s.render(0.3, 0.07, 1.25, -22.0, 40.0)
    # B : cordes staccato (ostinato), nappe, cuivres discrets
    s = Song(118, 16)
    order = [0, 2, 1, 3, 2, 1, 3, 2]
    for bar, ch in _bars(RUN_PROG):
        n = _notes(ch)
        for i in range(16):
            k = order[i % 8]
            vel = 0.82 if i % 4 == 0 else (0.62 if i % 2 == 0 else 0.45)
            f = n[k] * (2.0 if k < 2 and bar >= 8 else 1.0)
            s.add(I.strings_stac(f, 0.12, vel), s.at(bar, i), 0.42, -0.3 + 0.6 * (i % 2))
        s.add(I.strings_long(n[:3], s.step * 16 + 0.3, 0.5, 0.5), s.at(bar, 0), 0.5)
        if bar % 2 == 0:
            for st, v in ((0, 0.8), (6, 0.55)):
                s.add(I.brass_stab(n[0] * 2, 0.26, v), s.at(bar, st), 0.28, 0.1)
                s.add(I.brass_stab(n[2] * 2, 0.26, v * 0.9), s.at(bar, st), 0.22, -0.1)
    out["b"] = s.render(0.7, 0.17, 1.1, -23.5)
    # C : mélodie flûte + lead
    s = Song(118, 16)
    for bar, step, note, d in RUN_MELODY:
        f = H(note)
        s.add(I.flute(f, d * s.step * 0.9, 0.8), s.at(bar, step), 0.5, 0.1)
        s.add(I.lead_synth(f, d * s.step * 0.9, 0.7), s.at(bar, step), 0.22 if bar < 8 else 0.3, -0.12)
        if bar in (3, 7, 11, 15) and step == 8:
            s.add(I.glock(f * 2, 0.9, 0.5), s.at(bar, step), 0.18, 0.3)
    out["c"] = s.render(0.9, 0.22, 1.0, -25.0)
    return out


# ==========================================================================================
# BOSS : Kraken Rising (ré mineur, 132 BPM)
# ==========================================================================================
BOSS_PROG = ["Dm", "Dm", "Bb", "A"] * 2 + ["Gm", "Gm", "Bb", "A"] + ["Dm", "Bb", "A", "A"]
BOSS_MELODY = [
    (0, 0, "D5", 2), (0, 3, "D5", 1), (0, 4, "F5", 2), (0, 8, "E5", 2), (0, 11, "D5", 3),
    (1, 0, "D5", 2), (1, 3, "D5", 1), (1, 4, "A5", 2), (1, 8, "G5", 2), (1, 11, "F5", 3),
    (2, 0, "Bb4", 2), (2, 3, "Bb4", 1), (2, 4, "D5", 2), (2, 8, "F5", 4), (2, 12, "E5", 2),
    (3, 0, "C#5", 3), (3, 4, "E5", 3), (3, 8, "A5", 8),
    (4, 0, "D5", 2), (4, 3, "D5", 1), (4, 4, "F5", 2), (4, 8, "E5", 2), (4, 11, "D5", 3),
    (5, 0, "A5", 2), (5, 3, "A5", 1), (5, 4, "G5", 2), (5, 8, "F5", 2), (5, 11, "E5", 3),
    (6, 0, "F5", 2), (6, 3, "F5", 1), (6, 4, "G5", 2), (6, 8, "A5", 4), (6, 12, "Bb5", 2),
    (7, 0, "A5", 4), (7, 8, "E5", 8),
    (8, 0, "G5", 3), (8, 4, "D5", 2), (8, 6, "G5", 2), (8, 8, "Bb5", 4), (8, 12, "A5", 2),
    (9, 0, "G5", 3), (9, 4, "F5", 2), (9, 6, "D5", 2), (9, 8, "G5", 6),
    (10, 0, "Bb5", 3), (10, 4, "A5", 2), (10, 6, "F5", 2), (10, 8, "D5", 4), (10, 12, "F5", 2),
    (11, 0, "E5", 3), (11, 4, "G5", 3), (11, 8, "C#6", 8),
    (12, 0, "D6", 3), (12, 4, "A5", 2), (12, 6, "F5", 2), (12, 8, "D5", 8),
    (13, 0, "Bb5", 3), (13, 4, "F5", 2), (13, 6, "D5", 2), (13, 8, "Bb4", 8),
    (14, 0, "A5", 3), (14, 4, "E5", 2), (14, 6, "C#5", 2), (14, 8, "E5", 8),
    (15, 0, "A5", 4), (15, 4, "G5", 4), (15, 8, "E5", 4), (15, 12, "C#5", 4),
]


def render_boss():
    out = {}
    s = Song(132, 16)
    for bar in range(16):
        for st in (0, 4, 8, 12):
            s.add(I.kick(1.0 if st % 8 == 0 else 0.88), s.at(bar, st), 0.95)
        s.add(I.kick(0.8), s.at(bar, 14), 0.7)
        for st in (4, 12):
            s.add(I.snare(0.9), s.at(bar, st), 0.62, 0.05)
            s.add(I.clap(0.8), s.at(bar, st), 0.38, -0.1)
        for st in range(16):
            acc = 0.6 if st % 4 == 2 else (0.4 if st % 2 == 0 else 0.24)
            s.add(I.hat(acc), s.at(bar, st), 0.3, 0.3)
        s.add(I.taiko(64.0, 0.9), s.at(bar, 0), 0.62)
        s.add(I.taiko(82.0, 0.8), s.at(bar, 6), 0.5)
        s.add(I.taiko(64.0, 0.75), s.at(bar, 10), 0.5)
        if bar % 4 == 3:
            for k, st in enumerate((12, 13, 14, 15)):
                s.add(I.taiko(120.0 - 12 * k, 0.8), s.at(bar, st), 0.5, -0.2 + 0.13 * k)
        ch = BOSS_PROG[bar]
        r = H(ROOTS[ch])
        for st in range(16):
            if st in (0, 3, 6, 8, 10, 12, 14, 15):
                mult = 2.0 if st in (6, 14) else 1.0
                s.add(I.synth_bass(r * mult, 0.16, 0.9 if st % 4 == 0 else 0.65, grit=2.2), s.at(bar, st), 0.85)
    s.add(I.crash(0.9), s.at(0, 0), 0.4, 0.2)
    s.add(I.crash(0.8), s.at(8, 0), 0.35, -0.2)
    out["a"] = s.render(0.32, 0.07, 1.4, -21.5, 40.0)
    s = Song(132, 16)
    for bar, ch in _bars(BOSS_PROG):
        n = _notes(ch)
        for i in range(16):
            k = [0, 1, 2, 1][i % 4]
            vel = 0.85 if i % 4 == 0 else 0.55
            s.add(I.strings_stac(n[k], 0.1, vel, 0.9), s.at(bar, i), 0.4, -0.35 + 0.7 * (i % 2))
        s.add(I.strings_long([n[0], n[1], n[2]], s.step * 16 + 0.3, 0.55, 0.3), s.at(bar, 0), 0.5)
        for st in (0, 3, 6, 10):
            s.add(I.brass_stab(n[0] * 2, 0.24, 0.9), s.at(bar, st), 0.3, -0.12)
            s.add(I.brass_stab(n[2] * 2, 0.24, 0.8), s.at(bar, st), 0.24, 0.12)
    out["b"] = s.render(0.7, 0.16, 1.25, -23.0)
    s = Song(132, 16)
    for bar, step, note, d in BOSS_MELODY:
        f = H(note)
        s.add(I.lead_synth(f, d * s.step * 0.85, 0.85), s.at(bar, step), 0.36, 0.0)
        s.add(I.brass_stab(f, d * s.step * 0.8, 0.8), s.at(bar, step), 0.16, 0.12)
        s.add(I.flute(f * 2, d * s.step * 0.8, 0.5), s.at(bar, step), 0.12, -0.15)
    out["c"] = s.render(0.8, 0.18, 1.2, -24.5)
    return out


# ==========================================================================================
# MENU : Golden Shore (ré mineur, 100 BPM) — chaleureux, héroïque, sans lourdeur
# ==========================================================================================
MENU_PROG = ["Dm", "Bb", "F", "C", "Dm", "Bb", "F", "C", "Gm", "Dm", "Bb", "A", "Gm", "Bb", "C", "A"]
MENU_MELODY = [
    (0, 0, "A5", 8), (0, 8, "F5", 4), (0, 12, "G5", 4),
    (1, 0, "D5", 8), (1, 8, "F5", 8),
    (2, 0, "A5", 8), (2, 8, "C6", 4), (2, 12, "A5", 4),
    (3, 0, "G5", 8), (3, 8, "E5", 8),
    (4, 0, "F5", 8), (4, 8, "A5", 4), (4, 12, "D6", 4),
    (5, 0, "C6", 8), (5, 8, "Bb5", 8),
    (6, 0, "A5", 8), (6, 8, "F5", 4), (6, 12, "A5", 4),
    (7, 0, "G5", 12), (7, 12, "E5", 4),
    (8, 0, "D6", 8), (8, 8, "Bb5", 8),
    (9, 0, "A5", 8), (9, 8, "F5", 8),
    (10, 0, "D6", 8), (10, 8, "C6", 4), (10, 12, "Bb5", 4),
    (11, 0, "E6", 8), (11, 8, "C#6", 8),
    (12, 0, "D6", 8), (12, 8, "Bb5", 8),
    (13, 0, "F6", 8), (13, 8, "D6", 8),
    (14, 0, "E6", 8), (14, 8, "G5", 8),
    (15, 0, "A5", 16),
]


def render_menu():
    s = Song(100, 16, tail=3.5)
    for bar, ch in _bars(MENU_PROG):
        n = _notes(ch)
        order = [0, 2, 1, 3, 2, 1, 3, 2]
        for i, k in enumerate(order):
            s.add(I.nylon(n[k] * (1.0 if i % 2 == 0 else 2.0), 0.9, 0.7 + 0.1 * (i % 4 == 0)), s.at(bar, i * 2), 0.38, -0.25)
        s.add(I.strings_long(n[:3], s.step * 16 + 0.6, 0.5, 0.9, 0.8), s.at(bar, 0), 0.6)
        r = H(ROOTS[ch]) * (2.0 if ch in ("Bb", "A") else 1.0)
        s.add(I.synth_bass(r, 0.9, 0.6, cutoff=(1200.0, 300.0), grit=1.2), s.at(bar, 0), 0.7)
        s.add(I.synth_bass(r * 1.5, 0.35, 0.45, cutoff=(1200.0, 300.0), grit=1.2), s.at(bar, 10), 0.55)
        for st in (0, 8):
            s.add(I.kick(0.55), s.at(bar, st), 0.5)
        s.add(I.rim(0.5), s.at(bar, 12), 0.3, 0.2)
        for st in range(0, 16, 2):
            s.add(I.hat(0.3 + 0.1 * (st % 4 == 2)), s.at(bar, st), 0.2, 0.3)
        if bar % 4 == 0:
            s.add(I.taiko(66.0, 0.5), s.at(bar, 0), 0.3)
    for bar, step, note, d in MENU_MELODY:
        f = H(note)
        s.add(I.flute(f, d * s.step * 0.92, 0.8, 1.2), s.at(bar, step), 0.46, 0.1)
        s.add(I.lead_synth(f, d * s.step * 0.9, 0.5), s.at(bar, step), 0.1, -0.1)
    return s.render(1.1, 0.26, 1.05, -22.0)
