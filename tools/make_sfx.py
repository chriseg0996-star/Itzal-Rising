#!/usr/bin/env python3
"""Generate the game's procedural SFX pack.

Synthesizes short 16-bit mono WAVs with numpy + stdlib wave — no external
audio assets or downloads. Output paths match SoundManager.SOUNDS.

Music is NOT generated here: it is real files the user drops into
assets/music/menu/ (synthesized music hit a quality ceiling). SFX only.

Usage:  python tools/make_sfx.py   # the 7 SFX into assets/sfx/
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "sfx"
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


if __name__ == "__main__":
    make_sfx()
