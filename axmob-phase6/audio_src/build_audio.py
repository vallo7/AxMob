"""Rend tout l'audio du jeu vers assets/audio/ (déterministe, graines fixes).
  python3 audio_src/build_audio.py [--only sfx|music|amb] [--report]
Sorties : assets/audio/sfx/<nom>_<variante>.wav (mono 44,1 kHz 16 bits),
          assets/audio/music/*.ogg et assets/audio/amb/*.ogg (stéréo, Vorbis q5).
Le rapport (assets/audio/REPORT.md) liste durées, pics, niveaux RMS et centroïdes spectraux."""

import argparse
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import dsp  # noqa: E402
import music_defs  # noqa: E402
import sfx_defs  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio")


def write_wav(path, x, channels=1):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = dsp.to_int16(x)
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(dsp.SR)
        w.writeframes(data.tobytes())


WAV_IMPORT = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://assets/audio/sfx/{name}"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def ensure_pcm_import(path):
    """Godot 4.7 compresse les WAV en QOA par défaut : pour des effets courts on veut du PCM 16 bits
    (qualité exacte, aucun coût de décodage). Le fichier .import fixe ce réglage (compress/mode=0)."""
    imp = path + ".import"
    if os.path.exists(imp):
        txt = open(imp).read()
        if "compress/mode=0" in txt:
            return
        if "compress/mode=" in txt:
            txt = "\n".join("compress/mode=0" if l.startswith("compress/mode=") else l for l in txt.split("\n"))
            open(imp, "w").write(txt)
            return
    with open(imp, "w") as f:
        f.write(WAV_IMPORT.format(name=os.path.basename(path)))


def write_ogg(path, x, quality=5):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "t.wav")
        write_wav(wav, x, 2 if x.ndim == 2 else 1)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", str(quality), path], check=True)


def centroid(x):
    mono = x if x.ndim == 1 else x.mean(axis=1)
    spec = np.abs(np.fft.rfft(mono))
    f = np.fft.rfftfreq(len(mono), 1.0 / dsp.SR)
    return float((spec * f).sum() / (spec.sum() + 1e-9))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["sfx", "music", "amb"])
    args = ap.parse_args()
    rows = []
    if args.only in (None, "sfx"):
        for name, (fn, count, peak) in sfx_defs.REGISTRY.items():
            for v in range(count):
                x = fn(v)
                x = dsp.trim_silence(x, -55.0)
                x = dsp.master(x, peak=peak, drive=1.0)
                wav_path = os.path.join(OUT, "sfx", f"{name}_{v}.wav")
                write_wav(wav_path, x)
                ensure_pcm_import(wav_path)
                rows.append((f"sfx/{name}_{v}", len(x) / dsp.SR, dsp.peak_db(x), dsp.rms_db(x), centroid(x), 1))
        print(f"[audio] {len(sfx_defs.REGISTRY)} effets rendus")
    if args.only in (None, "music"):
        for key, stems in (("run", music_defs.render_run()), ("boss", music_defs.render_boss())):
            for s, x in stems.items():
                write_ogg(os.path.join(OUT, "music", f"{key}_{s}.ogg"), x)
                rows.append((f"music/{key}_{s}", len(x) / dsp.SR, dsp.peak_db(x), dsp.rms_db(x), centroid(x), 2))
        x = music_defs.render_menu()
        write_ogg(os.path.join(OUT, "music", "menu.ogg"), x)
        rows.append(("music/menu", len(x) / dsp.SR, dsp.peak_db(x), dsp.rms_db(x), centroid(x), 2))
        print("[audio] musiques rendues")
    if args.only in (None, "amb"):
        x = sfx_defs.amb_beach()
        x = dsp.normalize_rms(x, -26.0)
        write_ogg(os.path.join(OUT, "amb", "beach.ogg"), x)
        rows.append(("amb/beach", len(x) / dsp.SR, dsp.peak_db(x), dsp.rms_db(x), centroid(x), 2))
        print("[audio] ambiance rendue")
    if args.only is None:
        lines = ["# Rapport audio (généré par audio_src/build_audio.py)", "",
                 "| fichier | durée s | pic dBFS | RMS dBFS | centroïde Hz |", "|---|---|---|---|---|"]
        for name, d, pk, rms, c, _ in rows:
            lines.append(f"| {name} | {d:.2f} | {pk:.1f} | {rms:.1f} | {c:.0f} |")
        with open(os.path.join(OUT, "REPORT.md"), "w") as f:
            f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
