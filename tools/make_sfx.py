#!/usr/bin/env python3
"""Generate the game's procedural SFX pack (and optional ambient music loop).

Synthesizes short 16-bit mono WAVs with numpy + stdlib wave — no external
audio assets or downloads. Output paths match SoundManager.SOUNDS.

Usage:  python tools/make_sfx.py            # the 7 SFX into assets/sfx/
        python tools/make_sfx.py --ambient  # also assets/music/ambient_loop.wav
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "sfx"
MUSIC_DIR = ROOT / "assets" / "music"
SR = 44100


def tone(freq: float, dur: float, sr: int = SR) -> np.ndarray:
    t = np.arange(int(dur * sr)) / sr
    return np.sin(2 * np.pi * freq * t)


def sweep(f0: float, f1: float, dur: float, sr: int = SR) -> np.ndarray:
    t = np.arange(int(dur * sr)) / sr
    freq = np.linspace(f0, f1, t.size)
    phase = 2 * np.pi * np.cumsum(freq) / sr
    return np.sin(phase)


def noise(dur: float, sr: int = SR) -> np.ndarray:
    return np.random.default_rng(7).uniform(-1.0, 1.0, int(dur * sr))


def lowpass(sig: np.ndarray, strength: int = 8) -> np.ndarray:
    kernel = np.ones(strength) / strength
    return np.convolve(sig, kernel, mode="same")


def env(sig: np.ndarray, attack: float = 0.005, sr: int = SR) -> np.ndarray:
    """Fast attack, exponential decay over the remaining length."""
    n = sig.size
    a = int(attack * sr)
    shape = np.ones(n)
    shape[:a] = np.linspace(0.0, 1.0, max(a, 1))
    shape[a:] = np.exp(-4.0 * np.arange(n - a) / max(n - a, 1))
    return sig * shape


def write_wav(path: Path, sig: np.ndarray, sr: int = SR) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = np.max(np.abs(sig))
    if peak > 0:
        sig = sig / peak * 0.85
    data = (sig * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    print(f"WROTE {path.relative_to(ROOT)} ({sig.size / sr:.2f}s)")


def make_sfx() -> None:
    # unit_select: bright rising chirp
    write_wav(SFX_DIR / "unit_select.wav", env(sweep(880, 1320, 0.06)))
    # unit_move: tiny click + low blip
    move = np.concatenate([noise(0.002), tone(440, 0.05)])
    write_wav(SFX_DIR / "unit_move.wav", env(move))
    # unit_attack: low square-ish grunt + noise burst
    attack = np.sign(tone(180, 0.12)) * 0.6 + noise(0.12) * 0.4
    write_wav(SFX_DIR / "unit_attack.wav", env(attack))
    # unit_death: falling sweep + dull noise tail
    death = sweep(110, 55, 0.4) * 0.7 + lowpass(noise(0.4), 16) * 0.3
    write_wav(SFX_DIR / "unit_death.wav", env(death, attack=0.002))
    # building_place: deep thunk + filtered tail
    place = tone(70, 0.25) * 0.8 + lowpass(noise(0.25), 24) * 0.2
    write_wav(SFX_DIR / "building_place.wav", env(place, attack=0.001))
    # building_hit: mid thud + crack
    hit = tone(100, 0.15) * 0.6 + noise(0.15) * 0.4
    write_wav(SFX_DIR / "building_hit.wav", env(hit, attack=0.001))
    # resource_gather: two short high ticks
    tick1 = env(tone(1600, 0.03), attack=0.001)
    gap = np.zeros(int(0.06 * SR))
    tick2 = env(tone(2200, 0.03), attack=0.001)
    write_wav(SFX_DIR / "resource_gather.wav", np.concatenate([tick1, gap, tick2]))


def make_ambient() -> None:
    """~96s seamless ambient piece (not a drone): a slow 8-chord pad
    progression in A minor with 2s equal-power crossfades, a quiet sub root,
    and sparse pentatonic bell plucks. Everything is written circularly
    (indices wrap modulo n), so the loop point is continuous."""
    sr = 22050
    dur = 96.0
    n = int(dur * sr)
    sig = np.zeros(n)
    rng = np.random.default_rng(42)

    # Am F C G Am C F Em — root + third + fifth (Hz)
    chords = [
        [110.0, 130.8, 164.8],
        [87.3, 110.0, 130.8],
        [130.8, 164.8, 196.0],
        [98.0, 123.5, 146.8],
        [110.0, 130.8, 164.8],
        [130.8, 164.8, 196.0],
        [87.3, 110.0, 130.8],
        [82.4, 98.0, 123.5],
    ]
    seg = n // len(chords)
    xfade = int(2.0 * sr)
    for ci, chord in enumerate(chords):
        length = seg + xfade
        tt = np.arange(length) / sr
        win = np.ones(length)
        win[:xfade] = 0.5 - 0.5 * np.cos(np.pi * np.arange(xfade) / xfade)
        win[-xfade:] = 0.5 + 0.5 * np.cos(np.pi * np.arange(xfade) / xfade)
        wave = np.zeros(length)
        for f in chord:
            phase = rng.uniform(0.0, 2.0 * np.pi)
            wave += 0.10 * np.sin(2 * np.pi * f * tt + phase)
            wave += 0.07 * np.sin(2 * np.pi * f * 1.004 * tt + phase * 0.7)
        wave += 0.09 * np.sin(2 * np.pi * (chord[0] / 2.0) * tt)  # sub root
        idx = (ci * seg + np.arange(length)) % n
        sig[idx] += wave * win

    # Sparse bell plucks on the A minor pentatonic, ~1 every 3s.
    penta = [220.0, 261.6, 293.7, 329.6, 392.0, 440.0]
    for t0 in np.sort(rng.uniform(0.0, dur, 30)):
        f = penta[int(rng.integers(len(penta)))]
        plen = int(2.5 * sr)
        tt = np.arange(plen) / sr
        env = np.exp(-2.2 * tt)
        bell = (
            np.sin(2 * np.pi * f * tt)
            + 0.35 * np.sin(2 * np.pi * 2.0 * f * tt)
            + 0.15 * np.sin(2 * np.pi * 3.01 * f * tt)
        ) * env
        idx = (int(t0 * sr) + np.arange(plen)) % n
        sig[idx] += 0.16 * bell

    write_wav(MUSIC_DIR / "ambient_loop.wav", sig, sr)


if __name__ == "__main__":
    make_sfx()
    if "--ambient" in sys.argv:
        make_ambient()
