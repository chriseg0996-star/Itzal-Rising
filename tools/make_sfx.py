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
    """~75s seamless drone: every component frequency is an integer number of
    cycles over the duration, so the loop point is mathematically continuous."""
    sr = 22050
    dur = 75.0
    n = int(dur * sr)
    t = np.arange(n) / sr

    def locked(freq: float) -> float:
        return round(freq * dur) / dur  # snap to integer cycles over dur

    sig = np.zeros(n)
    for freq, amp in [(55.0, 0.30), (110.0, 0.22), (164.8, 0.14), (220.0, 0.08)]:
        f = locked(freq)
        # slow amplitude swell, also integer-cycle so it loops
        lfo = 0.5 + 0.5 * np.sin(2 * np.pi * locked(1.0 / 25.0) * t + freq)
        sig += amp * np.sin(2 * np.pi * f * t) * (0.55 + 0.45 * lfo)
    # faint shimmering high partial
    sig += 0.04 * np.sin(2 * np.pi * locked(659.2) * t) * (
        0.5 + 0.5 * np.sin(2 * np.pi * locked(1.0 / 37.5) * t)
    )
    write_wav(MUSIC_DIR / "ambient_loop.wav", sig, sr)


if __name__ == "__main__":
    make_sfx()
    if "--ambient" in sys.argv:
        make_ambient()
