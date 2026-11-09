"""Musique originale d'AxMob : trois morceaux de plage, synthétisés et composés par code.
 - run  : « Sunny Chase »  112 BPM, do majeur, 16 mesures. 3 couches (stems) synchronisées :
          A rythme (basse, kick, congas, shaker) ; B harmonie (ukulélé, marimba, nappe) ;
          C mélodie (steel drum). Le jeu les fait entrer selon l'intensité du combat.
 - boss : « Kraken Rumble » 126 BPM, la mineur, 16 mesures, 3 couches plus lourdes (toms, cuivres).
 - menu : « Lagoon »        96 BPM, do majeur, 16 mesures, un seul morceau doux (stéréo).
Chaque couche est rendue avec sa propre réverbération puis REPLIÉE sur la boucle (la queue des
dernières notes rejoint le début) : la boucle est sans couture."""

import numpy as np

import dsp
import instruments as I
from dsp import SR

H = dsp.hz

CHORDS = {
    "C": ["C4", "E4", "G4", "C5"], "Am": ["A3", "C4", "E4", "A4"], "F": ["F3", "A3", "C4", "F4"],
    "G": ["G3", "B3", "D4", "G4"], "Em": ["E3", "G3", "B3", "E4"], "Dm": ["D4", "F4", "A4", "D5"],
    "E": ["E3", "G#3", "B3", "E4"],
}
ROOTS = {"C": "C2", "Am": "A1", "F": "F2", "G": "G2", "Em": "E2", "Dm": "D2", "E": "E2"}
FIFTHS = {"C": "G2", "Am": "E2", "F": "C3", "G": "D3", "Em": "B2", "Dm": "A2", "E": "B2"}


class Song:
    """Séquenceur 16 doubles-croches par mesure, rendu stéréo avec repli de boucle."""

    def __init__(self, bpm, bars, tail=3.0):
        self.bpm = bpm
        self.bars = bars
        self.step = 60.0 / bpm / 4.0
        self.loop_s = self.step * 16 * bars
        self.tail = tail
        self.reset()

    def reset(self):
        self.buf = np.zeros((int((self.loop_s + self.tail) * SR), 2))

    def at(self, bar, step):
        return (bar * 16 + step) * self.step

    def add(self, x, t, gain=1.0, pan=0.0):
        st = dsp.pan(x, pan)
        s = int(round(t * SR))
        e = min(s + len(st), len(self.buf))
        if e > s:
            self.buf[s:e] += st[: e - s] * gain

    def render(self, rv=0.55, wet=0.2, drive=1.0, rms=-18.0):
        x = dsp.reverb(self.buf, rv, wet, 0.5, 0.015, tail=min(rv * 1.2, 2.6))
        n = int(self.loop_s * SR)
        loop = x[:n].copy()
        extra = x[n:]
        loop[: len(extra)] += extra[: len(loop)]
        if drive > 1.0:
            loop = dsp.sat(loop, drive)
        loop = dsp.hp(loop, 30.0, 2)
        return dsp.normalize_rms(loop, rms)


def _bars(progression):
    return [(i, c) for i, c in enumerate(progression)]


# ==========================================================================================
# RUN : Sunny Chase
# ==========================================================================================
RUN_PROG = ["C", "Am", "F", "G"] * 2 + ["F", "G", "Em", "Am"] + ["F", "G", "C", "C"]

RUN_MELODY = [
    # (mesure, pas, note, durée en pas)
    (0, 0, "E5", 3), (0, 3, "G5", 1), (0, 4, "A5", 3), (0, 7, "G5", 1), (0, 8, "E5", 4), (0, 12, "D5", 2), (0, 14, "E5", 2),
    (1, 0, "C5", 3), (1, 3, "E5", 1), (1, 4, "A5", 3), (1, 7, "G5", 1), (1, 8, "E5", 6), (1, 14, "D5", 2),
    (2, 0, "C6", 3), (2, 3, "A5", 1), (2, 4, "G5", 3), (2, 7, "A5", 1), (2, 8, "C6", 4), (2, 12, "A5", 4),
    (3, 0, "D6", 3), (3, 3, "B5", 1), (3, 4, "G5", 3), (3, 7, "A5", 1), (3, 8, "B5", 2), (3, 10, "D6", 2), (3, 12, "G5", 4),
    (4, 0, "E5", 3), (4, 3, "G5", 1), (4, 4, "A5", 3), (4, 7, "G5", 1), (4, 8, "E6", 4), (4, 12, "D6", 2), (4, 14, "C6", 2),
    (5, 0, "A5", 3), (5, 3, "C6", 1), (5, 4, "E6", 3), (5, 7, "D6", 1), (5, 8, "C6", 6), (5, 14, "A5", 2),
    (6, 0, "C6", 3), (6, 3, "A5", 1), (6, 4, "F5", 3), (6, 7, "A5", 1), (6, 8, "C6", 4), (6, 12, "D6", 4),
    (7, 0, "D6", 3), (7, 3, "B5", 1), (7, 4, "G5", 3), (7, 7, "B5", 1), (7, 8, "D6", 6), (7, 14, "G5", 2),
    (8, 0, "A5", 2), (8, 2, "C6", 2), (8, 4, "A5", 2), (8, 6, "G5", 2), (8, 8, "F5", 4), (8, 12, "A5", 4),
    (9, 0, "B5", 2), (9, 2, "D6", 2), (9, 4, "B5", 2), (9, 6, "A5", 2), (9, 8, "G5", 4), (9, 12, "B5", 4),
    (10, 0, "G5", 2), (10, 2, "B5", 2), (10, 4, "E6", 4), (10, 8, "D6", 2), (10, 10, "B5", 2), (10, 12, "G5", 4),
    (11, 0, "A5", 2), (11, 2, "C6", 2), (11, 4, "E6", 4), (11, 8, "C6", 2), (11, 10, "A5", 2), (11, 12, "E5", 4),
    (12, 0, "F5", 2), (12, 2, "A5", 2), (12, 4, "C6", 6), (12, 10, "A5", 2), (12, 12, "G5", 4),
    (13, 0, "G5", 2), (13, 2, "B5", 2), (13, 4, "D6", 6), (13, 10, "B5", 2), (13, 12, "A5", 4),
    (14, 0, "E5", 3), (14, 3, "G5", 1), (14, 4, "C6", 4), (14, 8, "E6", 6), (14, 14, "D6", 2),
    (15, 0, "C6", 8), (15, 10, "G5", 2), (15, 12, "E5", 4),
]


def _bass_line(song, prog, patterns, gain=0.9):
    for bar, ch in _bars(prog):
        r, f = H(ROOTS[ch]), H(FIFTHS[ch])
        for step, kind, dur_steps, vel in patterns:
            freq = {"r": r, "f": f, "o": r * 2, "a": H(ROOTS[prog[(bar + 1) % len(prog)]])}[kind]
            song.add(I.bass(freq, dur_steps * song.step + 0.1, vel), song.at(bar, step), gain, 0.0)


def _drums_run(song, bars, dense=1.0):
    for bar in range(bars):
        for st in (0, 8):
            song.add(I.kick(0.95 if st == 0 else 0.8), song.at(bar, st), 0.9)
        song.add(I.kick(0.5), song.at(bar, 14), 0.5)
        for st in (4, 12):
            song.add(I.rim(0.8), song.at(bar, st), 0.55, 0.15)
        for st, kind in ((2, "o"), (3, "s"), (6, "s"), (7, "o"), (10, "o"), (11, "s"), (14, "s")):
            f = 235.0 if kind == "o" else 330.0
            song.add(I.conga(f, kind == "s", 0.7), song.at(bar, st), 0.5, -0.35)
        for st in range(16):
            acc = 0.85 if st % 4 == 2 else (0.55 if st % 2 == 0 else 0.35)
            song.add(I.shaker(acc), song.at(bar, st), 0.55 * dense, 0.3)


def render_run():
    """Renvoie les trois couches de la musique de jeu (dict nom -> stéréo)."""
    out = {}
    # A : rythme + basse
    s = Song(112, 16)
    _drums_run(s, 16)
    _bass_line(s, RUN_PROG, [(0, "r", 3, 1.0), (3, "r", 1, 0.6), (6, "f", 2, 0.8), (8, "r", 3, 0.9),
                             (11, "o", 1, 0.6), (12, "f", 2, 0.8), (14, "a", 2, 0.7)])
    out["a"] = s.render(0.35, 0.1, 1.3, -17.0)
    # B : ukulélé + marimba + nappe
    s = Song(112, 16)
    for bar, ch in _bars(RUN_PROG):
        notes = [H(n) for n in CHORDS[ch]]
        s.add(I.strum(notes, 1.0, 10, False, 0.9, tau=0.5), s.at(bar, 0), 0.5, -0.2)
        for st in (2, 6, 10, 14):
            s.add(I.strum(notes, 0.35, 7, st % 8 != 2, 0.7, damp=True), s.at(bar, st), 0.42, -0.2)
        arp = [H(n) for n in CHORDS[ch]]
        order = [0, 1, 2, 3, 2, 1, 2, 3]
        for i, k in enumerate(order):
            s.add(I.marimba(arp[k] * 2, 0.5, 0.55 + 0.1 * (i % 2)), s.at(bar, i * 2), 0.28, 0.4)
        s.add(I.pad([H(n) for n in CHORDS[ch][:3]], s.step * 16 + 0.5, 0.5), s.at(bar, 0), 0.5, 0.0)
    out["b"] = s.render(0.7, 0.22, 1.1, -19.5)
    # C : mélodie steel drum
    s = Song(112, 16)
    for bar, step, note, dur_steps in RUN_MELODY:
        s.add(I.steel(H(note), dur_steps * s.step + 0.6, 0.85), s.at(bar, step), 0.55, 0.15)
        s.add(I.marimba(H(note) / 2, 0.5, 0.5), s.at(bar, step), 0.12, -0.3)
    out["c"] = s.render(0.9, 0.28, 1.0, -20.0)
    return out


# ==========================================================================================
# BOSS : Kraken Rumble (la mineur)
# ==========================================================================================
BOSS_PROG = ["Am", "F", "C", "G"] * 2 + ["Am", "F", "G", "E"] + ["Am", "F", "E", "E"]
BOSS_CHORDS = {
    "Am": ["A3", "C4", "E4", "A4"], "F": ["F3", "A3", "C4", "F4"], "C": ["C4", "E4", "G4", "C5"],
    "G": ["G3", "B3", "D4", "G4"], "E": ["E3", "G#3", "B3", "E4"],
}
BOSS_MELODY = [
    (0, 0, "A5", 2), (0, 2, "C6", 2), (0, 4, "E6", 4), (0, 8, "D6", 2), (0, 10, "C6", 2), (0, 12, "A5", 4),
    (1, 0, "A5", 2), (1, 2, "C6", 2), (1, 4, "F6", 4), (1, 8, "E6", 2), (1, 10, "C6", 2), (1, 12, "A5", 4),
    (2, 0, "G5", 2), (2, 2, "C6", 2), (2, 4, "E6", 4), (2, 8, "G6", 4), (2, 12, "E6", 4),
    (3, 0, "D6", 2), (3, 2, "B5", 2), (3, 4, "G5", 4), (3, 8, "A5", 2), (3, 10, "B5", 2), (3, 12, "D6", 4),
    (4, 0, "A5", 2), (4, 2, "C6", 2), (4, 4, "E6", 4), (4, 8, "A6", 4), (4, 12, "G6", 4),
    (5, 0, "F6", 2), (5, 2, "E6", 2), (5, 4, "C6", 4), (5, 8, "A5", 2), (5, 10, "C6", 2), (5, 12, "F6", 4),
    (6, 0, "G6", 4), (6, 4, "E6", 4), (6, 8, "C6", 4), (6, 12, "E6", 4),
    (7, 0, "D6", 4), (7, 4, "B5", 4), (7, 8, "G5", 4), (7, 12, "D6", 4),
    (8, 0, "E6", 4), (8, 4, "C6", 4), (8, 8, "A5", 4), (8, 12, "C6", 4),
    (9, 0, "F6", 4), (9, 4, "C6", 4), (9, 8, "A5", 4), (9, 12, "F5", 4),
    (10, 0, "G5", 2), (10, 2, "B5", 2), (10, 4, "D6", 4), (10, 8, "G6", 4), (10, 12, "D6", 4),
    (11, 0, "G#5", 2), (11, 2, "B5", 2), (11, 4, "E6", 4), (11, 8, "G#6", 4), (11, 12, "E6", 4),
    (12, 0, "A5", 2), (12, 2, "C6", 2), (12, 4, "E6", 4), (12, 8, "A6", 6), (12, 14, "G6", 2),
    (13, 0, "F6", 4), (13, 4, "A5", 4), (13, 8, "C6", 4), (13, 12, "F6", 4),
    (14, 0, "G#5", 2), (14, 2, "B5", 2), (14, 4, "E6", 6), (14, 10, "D6", 2), (14, 12, "B5", 4),
    (15, 0, "E6", 8), (15, 8, "G#5", 4), (15, 12, "B5", 4),
]
BOSS_ROOTS = {"Am": "A1", "F": "F1", "C": "C2", "G": "G1", "E": "E2"}


def render_boss():
    out = {}
    bpm = 126
    s = Song(bpm, 16)
    for bar in range(16):
        for st in (0, 4, 8, 12):
            s.add(I.kick(1.0 if st % 8 == 0 else 0.85), s.at(bar, st), 1.0)
        for st in (4, 12):
            s.add(I.tom(150.0, 0.7), s.at(bar, st), 0.35, 0.3)
        s.add(I.tom(95.0, 0.9), s.at(bar, 0), 0.55, -0.2)
        s.add(I.tom(120.0, 0.8), s.at(bar, 10), 0.45, 0.2)
        if bar % 4 == 3:
            for st, f in ((12, 140.0), (13, 120.0), (14, 105.0), (15, 90.0)):
                s.add(I.tom(f, 0.9), s.at(bar, st), 0.6, (st - 13) * 0.2)
        for st in range(16):
            acc = 0.9 if st % 4 == 2 else 0.45
            s.add(I.shaker(acc), s.at(bar, st), 0.5, 0.35)
        ch = BOSS_PROG[bar]
        r = H(BOSS_ROOTS[ch])
        for st, mult, vel in ((0, 1, 1.0), (3, 1, 0.7), (6, 1, 0.8), (8, 2, 0.8), (10, 1, 0.7), (12, 1.5, 0.9), (14, 1, 0.8)):
            s.add(I.bass(r * mult, 0.3, vel, 0.25), s.at(bar, st), 0.95)
    out["a"] = s.render(0.35, 0.1, 1.5, -16.5)
    s = Song(bpm, 16)
    for bar, ch in _bars(BOSS_PROG):
        notes = [H(n) for n in BOSS_CHORDS[ch]]
        for st in (0, 3, 6, 10, 12):
            s.add(I.brass(notes[0] / 2 * 2, 0.28, 0.9), s.at(bar, st), 0.35, -0.3)
            s.add(I.brass(notes[2], 0.28, 0.8), s.at(bar, st), 0.28, 0.3)
        for st in range(0, 16, 2):
            s.add(I.strum(notes, 0.3, 5, st % 4 != 0, 0.9, damp=True), s.at(bar, st), 0.38, 0.0)
        s.add(I.pad([H(n) for n in BOSS_CHORDS[ch][:3]], s.step * 16 + 0.5, 0.6, 0.15), s.at(bar, 0), 0.6)
    out["b"] = s.render(0.8, 0.24, 1.3, -19.0)
    s = Song(bpm, 16)
    for bar, step, note, dur_steps in BOSS_MELODY:
        s.add(I.steel(H(note), dur_steps * s.step + 0.4, 0.95), s.at(bar, step), 0.5, 0.1)
        s.add(I.marimba(H(note), 0.4, 0.9), s.at(bar, step), 0.22, -0.2)
    out["c"] = s.render(0.9, 0.26, 1.0, -20.0)
    return out


# ==========================================================================================
# MENU : Lagoon
# ==========================================================================================
MENU_PROG = ["C", "Am", "F", "G", "C", "Am", "Dm", "G", "F", "G", "Em", "Am", "F", "G", "C", "C"]
MENU_CH = dict(CHORDS)
MENU_CH["Dm"] = ["D4", "F4", "A4", "D5"]


def render_menu():
    s = Song(96, 16, tail=3.5)
    for bar, ch in _bars(MENU_PROG):
        notes = [H(n) for n in MENU_CH[ch]]
        s.add(I.strum(notes, 1.6, 14, False, 0.7, tau=0.7), s.at(bar, 0), 0.45, -0.25)
        s.add(I.strum(notes, 0.8, 12, True, 0.55), s.at(bar, 8), 0.3, -0.25)
        for i, k in enumerate([0, 2, 1, 3, 2, 1, 3, 2]):
            s.add(I.marimba(notes[k] * 2, 0.8, 0.5), s.at(bar, i * 2), 0.26, 0.35)
        s.add(I.pad(notes[:3], s.step * 16 + 0.8, 0.5, 0.5), s.at(bar, 0), 0.55)
        r = H(ROOTS[ch])
        s.add(I.bass(r, 0.8, 0.8, 0.5), s.at(bar, 0), 0.8)
        s.add(I.bass(r * 1.5 if ch != "G" else r * 2, 0.5, 0.6, 0.35), s.at(bar, 10), 0.6)
        for st in (0, 8):
            s.add(I.kick(0.6), s.at(bar, st), 0.45)
        for st in range(0, 16, 2):
            s.add(I.shaker(0.35 + 0.15 * (st % 4 == 2)), s.at(bar, st), 0.4, 0.3)
        s.add(I.rim(0.5), s.at(bar, 12), 0.3, 0.1)
    mel = [
        (0, 0, "G5", 6), (0, 8, "E5", 4), (1, 0, "E5", 6), (1, 8, "C5", 4), (2, 0, "A5", 6), (2, 8, "F5", 4), (3, 0, "B5", 8),
        (4, 0, "G5", 6), (4, 8, "E5", 4), (5, 0, "A5", 6), (5, 8, "C6", 4), (6, 0, "D6", 6), (6, 8, "A5", 4), (7, 0, "G5", 8),
        (8, 0, "C6", 6), (8, 8, "A5", 4), (9, 0, "D6", 6), (9, 8, "B5", 4), (10, 0, "E6", 6), (10, 8, "B5", 4), (11, 0, "C6", 8),
        (12, 0, "A5", 6), (12, 8, "F5", 4), (13, 0, "B5", 6), (13, 8, "D6", 4), (14, 0, "C6", 12),
    ]
    for bar, step, note, d in mel:
        s.add(I.steel(H(note), d * s.step + 0.8, 0.7), s.at(bar, step), 0.45, 0.15)
    return s.render(1.0, 0.3, 1.1, -18.0)
