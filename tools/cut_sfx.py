"""Cuts the recorded sounds in assets/sounds/*.mp3 down to the effects the
game plays, as assets/sounds/*.wav (the synthesized ones are gen_sfx.py's).

Needs an MP3 decoder: `pip install miniaudio`, then
`python3 tools/cut_sfx.py [name ...]` (no names: all).
Every sound is a function returning mono samples in -1..1; tweak and rerun.
"""
import math
import os
import struct
import sys
import wave

import miniaudio

RATE = 44100
TAU = 2.0 * math.pi
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


def fx_chains_break():
    """Chains snapping and falling apart: the first of the two takes in the
    recording (the second starts at 1.5 s)."""
    return clip("chains-breaking", 0.0, 1.18, 0.0, 0.1)


def echo(samples, gap=0.3, repeats=2, fall=0.42, cutoff=2600.0):
    """`samples` heard again `repeats` times, `gap` seconds apart, each one
    `fall` as loud as the one before and duller (a one-pole lowpass at
    `cutoff`, once more for every bounce): a laugh coming back off the far
    side of an empty ring."""
    out = list(samples) + [0.0] * int(gap * repeats * RATE)
    k = 1.0 - math.exp(-TAU * cutoff / RATE)
    bounce = list(samples)
    for r in range(1, repeats + 1):
        low = 0.0
        for i, s in enumerate(bounce):
            low += k * (s - low)
            bounce[i] = low
        at = int(gap * r * RATE)
        gain = fall ** r
        for i, s in enumerate(bounce):
            out[at + i] += s * gain
    return out


def reverb(samples, tail=2.4, wet=0.4, room=0.88, damp=0.3, size=1.4):
    """A big hall after `samples`: Schroeder's (as in Freeverb) four combs in
    parallel, each with a lowpass in its feedback (`damp`) so the tail darkens
    as it dies, then two allpasses in a row to smear the repeats into a wash.
    `room` is the feedback (how long it rings), `size` stretches the delays,
    `wet` how much of it is mixed under the dry sound."""
    n = len(samples) + int(tail * RATE)
    dry = list(samples) + [0.0] * (n - len(samples))
    combs = [int(d * size * RATE / 44100) for d in (1116, 1188, 1277, 1356)]
    washed = [0.0] * n
    for delay in combs:
        line = [0.0] * delay
        low = 0.0
        for i in range(n):
            j = i % delay
            out = line[j]
            low = out * (1.0 - damp) + low * damp
            line[j] = dry[i] + low * room
            washed[i] += out / len(combs)
    for delay in (int(556 * size), int(441 * size)):
        line = [0.0] * delay
        for i in range(n):
            j = i % delay
            held = line[j]
            line[j] = washed[i] + held * 0.5
            washed[i] = held - washed[i] * 0.5
    return [d + w * wet for d, w in zip(dry, washed)]


def ringing(samples):
    """The Clown's laughs, as the user asked to hear them: an echo first,
    and the whole of it in a big hall."""
    return reverb(echo(samples))


# The five laughs of clown-laugh.mp3, apart: an empty Bang! picks one of them.
LAUGHS = [(0.04, 2.9), (4.36, 7.24), (8.74, 11.88), (12.98, 15.82), (16.92, 19.22)]


def _laugh(n):
    start, end = LAUGHS[n - 1]
    return lambda: ringing(clip("clown-laugh", start, end, 0.01, 0.25))


def fx_party_blower():
    """The party blower an empty clown gun goes off with."""
    return clip("partyblower", 0.0, 1.0, 0.003, 0.2)


def fx_crowd_laugh():
    """The table laughing at whoever ducked an empty gun: from where the laugh
    starts in the recording, with its tail faded out."""
    return clip("crowd-laughing", 0.75, 4.6, 0.05, 1.4)


def fx_clown_laughter():
    """The Clown's Laughter."""
    return ringing(clip("clown-laugh-skill", 0.0, 2.3, 0.005, 0.5))


SOUNDS = {
    "ui_doors_shut": ui_doors_shut,
    "ui_doors_open": ui_doors_open,
    "fx_mickey_pour": fx_mickey_pour,
    "fx_gulp": fx_gulp,
    "fx_vault": fx_vault,
    "fx_chains_break": fx_chains_break,
    "fx_party_blower": fx_party_blower,
    "fx_crowd_laugh": fx_crowd_laugh,
    "fx_clown_laughter": fx_clown_laughter,
}
for _n in range(1, len(LAUGHS) + 1):
    SOUNDS["fx_clown_laugh_%d" % _n] = _laugh(_n)
# How loud each one ends up (its loudest sample).
PEAK = {"ui_doors_shut": 0.8, "ui_doors_open": 0.5, "fx_mickey_pour": 0.6, "fx_gulp": 0.75, "fx_vault": 0.8,
    "fx_chains_break": 0.9, "fx_party_blower": 0.7, "fx_crowd_laugh": 0.55, "fx_clown_laughter": 0.8}
PEAK.update({"fx_clown_laugh_%d" % _n: 0.7 for _n in range(1, len(LAUGHS) + 1)})


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
