"""Cuts the recorded sounds in assets/sounds/*.mp3 down to the effects the
game plays, as assets/sounds/*.wav (the synthesized ones are gen_sfx.py's).

Needs an MP3 decoder: `pip install miniaudio`, then
`python3 tools/cut_sfx.py [name ...]` (no names: all).
Every sound is a function returning mono samples in -1..1; tweak and rerun.
"""
import os
import struct
import sys
import wave

import miniaudio

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def clip(name, start, end, fade_in=0.005, fade_out=0.05, speed=1.0):
    """The stretch of `name`.mp3 from `start` to `end` seconds, faded at both
    ends and with its loudest sample at 1. `speed` plays it faster (and higher)."""
    decoded = miniaudio.decode_file(os.path.join(OUT, name + ".mp3"), nchannels=1, sample_rate=RATE,
            output_format=miniaudio.SampleFormat.SIGNED16)
    cut = [s / 32768.0 for s in decoded.samples[int(start * RATE):int(end * RATE)]]
    if speed != 1.0:
        out = []
        at = 0.0
        while at < len(cut) - 1:
            i = int(at)
            out.append(cut[i] + (cut[i + 1] - cut[i]) * (at - i))
            at += speed
        cut = out
    peak = max(abs(s) for s in cut) or 1.0
    n = len(cut)
    rise = max(int(fade_in * RATE), 1)
    fall = max(int(fade_out * RATE), 1)
    return [s / peak * min(i / rise, (n - 1 - i) / fall, 1.0) for i, s in enumerate(cut)]


def mix(into, samples, at=0.0, gain=1.0):
    start = int(at * RATE)
    if len(into) < start + len(samples):
        into.extend([0.0] * (start + len(samples) - len(into)))
    for i, s in enumerate(samples):
        into[start + i] += s * gain
    return into


def ui_doors_shut():
    """The saloon doors meet. The slam falls 0.45 s in, when the leaves do
    (Transition.TIMES[DOORS][0]); the swing of the leaves leads up to it."""
    out = mix([], clip("door_sliding", 0.85, 1.25, 0.12, 0.08, 1.3), 0.08, 0.3)
    return mix(out, clip("door-closing", 0.0, 0.57, 0.0, 0.08), 0.45 - 0.165)


def ui_doors_open():
    """And swing open again."""
    return clip("door_sliding", 0.55, 1.6, 0.06, 0.4, 1.25)


def fx_mickey_pour():
    """A drink poured into a glass."""
    return clip("pouring", 0.08, 0.8, 0.01, 0.12)


def fx_gulp():
    """And swallowed: played apart, when the glass is tipped."""
    return clip("gulp", 0.32, 0.68, 0.01, 0.06)


def fx_vault():
    """A safe opened: the wheel worked, then the bolts drawn and the door
    let go, half a second in (when the vault of a Cash Out swings open)."""
    return clip("safe-opening", 0.05, 1.08, 0.005, 0.1)


SOUNDS = {
    "ui_doors_shut": ui_doors_shut,
    "ui_doors_open": ui_doors_open,
    "fx_mickey_pour": fx_mickey_pour,
    "fx_gulp": fx_gulp,
    "fx_vault": fx_vault,
}
# How loud each one ends up (its loudest sample).
PEAK = {"ui_doors_shut": 0.8, "ui_doors_open": 0.5, "fx_mickey_pour": 0.6, "fx_gulp": 0.75, "fx_vault": 0.8}


def main():
    names = sys.argv[1:] or list(SOUNDS)
    for name in names:
        samples = SOUNDS[name]()
        top = max(abs(s) for s in samples) or 1.0
        gain = PEAK[name] / top
        path = os.path.join(OUT, name + ".wav")
        with wave.open(path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
        print("%s  %.2fs" % (name, len(samples) / RATE))


if __name__ == "__main__":
    main()
