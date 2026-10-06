"""Synthesizes the game's short sound effects into assets/sounds/*.wav.

Standard library only: `python3 tools/gen_sfx.py [name ...]` (no names: all).
Every sound is a function returning mono samples in -1..1; tweak and rerun.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
TAU = math.tau


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(into, samples, at=0.0, gain=1.0):
    start = int(at * RATE)
    if len(into) < start + len(samples):
        into.extend([0.0] * (start + len(samples) - len(into)))
    for i, s in enumerate(samples):
        into[start + i] += s * gain
    return into


def env(t, attack, decay):
    """Linear attack, exponential decay (`decay` = time to fall to ~5%)."""
    if t < attack:
        return t / attack
    return math.exp(-3.0 * (t - attack) / decay)


def tone(freq, seconds, attack=0.004, decay=0.3, shape="sine", glide=1.0, vibrato=0.0):
    """One note. `glide` multiplies the pitch over its length; `freq` may be a function of t."""
    out = []
    phase = 0.0
    n = int(seconds * RATE)
    for i in range(n):
        t = i / RATE
        f = freq(t) if callable(freq) else freq * glide ** (i / n)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * 6.0 * t)
        phase += f / RATE
        x = phase % 1.0
        if shape == "sine":
            s = math.sin(TAU * x)
        elif shape == "tri":
            s = 4.0 * abs(x - 0.5) - 1.0
        elif shape == "saw":
            s = 2.0 * x - 1.0
        else:  # soft square
            s = math.tanh(3.0 * math.sin(TAU * x))
        out.append(s * env(t, attack, decay))
    return out


def noise(seconds, attack=0.002, decay=0.1, seed=1):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) * env(i / RATE, attack, decay) for i in range(int(seconds * RATE))]


def lowpass(samples, cutoff):
    """One-pole low-pass; `cutoff` in Hz, or a function of t."""
    out = []
    y = 0.0
    for i, s in enumerate(samples):
        c = cutoff(i / RATE) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-TAU * c / RATE)
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, low)]


def bandpass(samples, low, high):
    return highpass(lowpass(samples, high), low)


def bell(freq, seconds, decay, partials=((1.0, 1.0), (2.0, 0.5), (3.01, 0.25), (4.2, 0.12))):
    out = silence(seconds)
    for ratio, gain in partials:
        mix(out, tone(freq * ratio, seconds, 0.002, decay / (0.6 + 0.4 * ratio)), 0.0, gain)
    return out


# --- the sounds ---------------------------------------------------------------

def card_draw():
    """A card sliding off the deck and snapping into place."""
    slide = bandpass(noise(0.16, 0.03, 0.09, 3), 1800, lambda t: 3500 + 30000 * t)
    out = mix(silence(0.24), slide, 0.0, 0.9)
    snap = highpass(noise(0.03, 0.001, 0.012, 5), 2500)
    mix(out, snap, 0.13, 0.9)
    mix(out, tone(190, 0.05, 0.001, 0.03), 0.13, 0.5)
    return out


def piano(freq, seconds, decay):
    """A felt-hammer piano note: harmonics that die faster the higher they are."""
    out = silence(seconds)
    for n in range(1, 9):
        stretch = n * math.sqrt(1.0 + 0.0004 * n * n)
        mix(out, tone(freq * stretch, seconds, 0.004, decay / (1.0 + 0.45 * (n - 1))), 0.0, 1.0 / n ** 1.3)
    return lowpass(out, 3200)


def upright_bass(freq, seconds, decay=0.5, slide=1.0):
    """A plucked double bass string; `slide` bends the pitch over the note."""
    out = silence(seconds)
    for n, gain in ((1, 1.0), (2, 0.5), (3, 0.22), (4, 0.08)):
        mix(out, tone(freq * n, seconds, 0.006, decay / n ** 0.5, glide=slide), 0.0, gain)
    mix(out, lowpass(noise(0.03, 0.001, 0.012, 41), 700), 0.0, 0.5)
    return out


def vibes(freq, seconds, decay):
    """A vibraphone bar with its slow motor tremolo."""
    out = silence(seconds)
    mix(out, tone(freq, seconds, 0.003, decay), 0.0, 1.0)
    mix(out, tone(freq * 4.0, seconds, 0.002, decay * 0.25), 0.0, 0.18)
    return [s * (0.8 + 0.2 * math.sin(TAU * 5.5 * i / RATE)) for i, s in enumerate(out)]


def brush(seconds=0.12, seed=43):
    """A brush tap on the snare."""
    return bandpass(noise(seconds, 0.004, seconds * 0.5, seed), 1500, 6000)


def truth():
    """Smoky club resolve: a bass pluck under a rolled vibraphone 6/9 chord."""
    out = silence(1.25)
    mix(out, upright_bass(73.4, 0.9, 0.7), 0.0, 0.9)              # D2
    for i, f in enumerate((370.0, 440.0, 493.9, 659.3)):          # F#4 A4 B4 E5
        mix(out, vibes(f, 1.1, 0.8), 0.05 + i * 0.045, 0.3)
    mix(out, brush(0.1), 0.0, 0.12)
    return out


def lie():
    """Caught: a low diminished piano stab and the bass sliding down."""
    out = silence(1.2)
    for f in (65.4, 77.8, 92.5, 185.0):                           # C2 Eb2 F#2 F#3
        mix(out, piano(f, 1.1, 0.9), 0.0, 0.5)
    mix(out, upright_bass(98.0, 0.7, 0.6, slide=0.6), 0.16, 0.8)  # G2 falling
    mix(out, brush(0.14, 45), 0.0, 0.25)
    mix(out, tone(55, 0.12, 0.002, 0.08, glide=0.6), 0.0, 0.5)
    return out


def cancel():
    """An ability fizzles out."""
    out = silence(0.45)
    mix(out, tone(520, 0.36, 0.004, 0.22, "tri", glide=0.3), 0.0, 0.8)
    mix(out, lowpass(noise(0.3, 0.01, 0.15, 9), 900), 0.02, 0.5)
    return out


# The ring of a real coin, measured from a recording of coins spilling:
# (frequency in Hz, gain, seconds to decay). Three groups carry the sound,
# around 5.5 kHz, 9.5 kHz and 12 kHz.
COIN_MODES = (
    (4910, 0.06, 0.07), (5097, 0.055, 0.1), (5355, 0.08, 0.07), (5531, 0.82, 0.06),
    (5607, 0.25, 0.08), (5746, 0.11, 0.035), (5968, 0.06, 0.1), (6174, 0.08, 0.11),
    (6623, 0.125, 0.09), (6893, 0.06, 0.1), (7173, 0.08, 0.1), (7720, 0.11, 0.1),
    (8156, 0.07, 0.07), (8699, 0.09, 0.07), (9058, 0.065, 0.11), (9292, 0.26, 0.11),
    (9426, 0.52, 0.09), (9497, 1.0, 0.05), (9601, 0.5, 0.11), (9721, 0.14, 0.03),
    (9788, 0.19, 0.11), (10234, 0.05, 0.1), (10394, 0.05, 0.11), (11669, 0.08, 0.06),
    (11736, 0.22, 0.08), (11908, 0.08, 0.03), (12001, 0.06, 0.06), (12281, 0.22, 0.035),
)

# Under 1, the ring dies sooner than on the recording's last coin, as it does
# for a coin landing on a pile.
COIN_DAMPING = 0.6


def coin(hits, pitch=1.0, seed=51):
    """A coin landing among others. `hits` are its knocks, (seconds, strength):
    the landing and the quick rebounds. Each knock sets the whole disc ringing
    again, a little differently every time."""
    rng = random.Random(seed)
    seconds = 0.24
    out = silence(seconds)
    for at, strength in hits:
        for freq, gain, decay in COIN_MODES:
            # Where the coin is struck changes how much each mode answers.
            g = gain * strength * rng.uniform(0.55, 1.0) * (1.6 if freq > 11000 else 1.0)
            w = TAU * freq * pitch / RATE
            phase = rng.uniform(0, TAU)
            start = int(at * RATE)
            # `decay` is the measured time constant, in seconds.
            for i in range(int((seconds - at) * RATE)):
                out[start + i] += g * math.exp(-i / RATE / (decay * COIN_DAMPING)) * math.sin(w * i + phase)
        # The contact itself.
        mix(out, highpass(noise(0.004, 0.0002, 0.0015, rng.randrange(1 << 30)), 4500), at, 1.6 * strength)
    return out


def item_get():
    """Something drops into the inventory."""
    out = silence(0.35)
    mix(out, tone(523.3, 0.1, 0.002, 0.08, "tri"), 0.0, 0.7)
    mix(out, tone(784.0, 0.22, 0.002, 0.16, "tri"), 0.07, 0.7)
    mix(out, highpass(noise(0.03, 0.001, 0.015, 11), 3000), 0.0, 0.25)
    return out


def item_use():
    """Fallback for an item without a sound of its own."""
    out = silence(0.35)
    mix(out, tone(392.0, 0.3, 0.003, 0.2, "tri", glide=1.5), 0.0, 0.7)
    mix(out, tone(784.0, 0.2, 0.003, 0.14), 0.08, 0.3)
    return out


def heal():
    """Morale comes back: a warm rising arpeggio."""
    out = silence(0.9)
    for i, f in enumerate((523.3, 659.3, 784.0, 1046.5)):
        mix(out, tone(f, 0.5, 0.01, 0.34, vibrato=0.003), i * 0.085, 0.55)
        mix(out, tone(f * 2, 0.3, 0.01, 0.18), i * 0.085, 0.12)
    return out


def item_silencer():
    """A suppressed shot."""
    out = silence(0.4)
    puff = lowpass(noise(0.3, 0.001, 0.07, 13), lambda t: 500 + 4000 * math.exp(-t * 40))
    mix(out, puff, 0.0, 1.0)
    mix(out, tone(120, 0.16, 0.001, 0.09, glide=0.4), 0.0, 0.9)
    mix(out, highpass(noise(0.2, 0.02, 0.12, 15), 4000), 0.03, 0.12)
    return out


def item_potion():
    """Cork, then gulps."""
    out = silence(0.85)
    mix(out, tone(900, 0.05, 0.001, 0.03, glide=2.2), 0.0, 0.6)
    mix(out, highpass(noise(0.02, 0.001, 0.01, 17), 2000), 0.0, 0.3)
    rng = random.Random(19)
    for i in range(7):
        at = 0.12 + i * 0.085 + rng.uniform(-0.012, 0.012)
        base = 260 + 55 * i + rng.uniform(-20, 20)
        mix(out, tone(base, 0.075, 0.008, 0.06, glide=1.9), at, 0.7)
    return out


def item_mirror():
    """Glass ringing as the effect bounces back."""
    out = silence(1.0)
    for ratio, gain, decay in ((1.0, 0.6, 0.7), (1.47, 0.45, 0.55), (2.09, 0.4, 0.45), (2.56, 0.3, 0.4), (3.39, 0.2, 0.3)):
        ring = tone(1560 * ratio, 0.95, 0.002, decay)
        mix(out, [s * (0.75 + 0.25 * math.sin(TAU * 9.0 * i / RATE)) for i, s in enumerate(ring)], 0.03, gain)
    mix(out, highpass(noise(0.03, 0.001, 0.012, 21), 5000), 0.03, 0.6)
    swell = tone(3120, 0.2, 0.18, 0.02, glide=0.5)
    mix(out, swell, 0.0, 0.15)
    return out


def item_shield():
    """A blow stopped by metal."""
    out = silence(0.75)
    for ratio, gain, decay in ((1.0, 0.7, 0.5), (2.76, 0.6, 0.35), (5.4, 0.4, 0.22), (8.93, 0.25, 0.14)):
        mix(out, tone(310 * ratio, 0.7, 0.001, decay), 0.0, gain)
    mix(out, bandpass(noise(0.08, 0.001, 0.03, 23), 800, 6000), 0.0, 0.9)
    mix(out, tone(90, 0.12, 0.001, 0.07, glide=0.6), 0.0, 0.7)
    return out


def item_death():
    """A low toll."""
    out = silence(1.3)
    partials = ((1.0, 1.0), (2.0, 0.6), (2.4, 0.45), (3.0, 0.3), (4.5, 0.15))
    mix(out, bell(98.0, 1.25, 1.1, partials), 0.0, 0.9)
    mix(out, lowpass(noise(0.05, 0.001, 0.02, 25), 1500), 0.0, 0.5)
    return out


def item_roulette():
    """The cylinder spins and slows down."""
    out = silence(0.95)
    at = 0.0
    gap = 0.035
    i = 0
    while at < 0.8:
        click = highpass(noise(0.015, 0.0005, 0.006, 27 + i), 1800)
        mix(out, click, at, 0.8)
        mix(out, tone(1500, 0.02, 0.0005, 0.01), at, 0.35)
        at += gap
        gap *= 1.17
        i += 1
    return out


def item_cloak():
    """Cloth swept around the shoulders."""
    body = noise(0.55, 0.16, 0.25, 31)
    swept = bandpass(body, 300, lambda t: 5000 * math.exp(-t * 4.0) + 500)
    return mix(silence(0.6), swept, 0.0, 1.0)


def item_soul_swap():
    """Two voices crossing."""
    out = silence(0.8)
    mix(out, tone(330, 0.7, 0.05, 0.5, glide=2.5, vibrato=0.012), 0.0, 0.6)
    mix(out, tone(825, 0.7, 0.05, 0.5, glide=0.4, vibrato=0.012), 0.0, 0.6)
    mix(out, lowpass(noise(0.6, 0.2, 0.3, 33), 1200), 0.0, 0.2)
    return out


SOUNDS = {
    "card_draw": card_draw,
    "truth": truth,
    "lie": lie,
    "cancel": cancel,
    "heal": heal,
    "coin_1": lambda: coin(((0.0, 1.0), (0.011, 0.45)), 1.0, 51),
    "coin_2": lambda: coin(((0.0, 0.8), (0.016, 0.6), (0.027, 0.3)), 1.035, 53),
    "coin_3": lambda: coin(((0.0, 1.0), (0.008, 0.35)), 0.97, 55),
    "item_get": item_get,
    "item_use": item_use,
    "item_silencer": item_silencer,
    "item_potion": item_potion,
    "item_mirror": item_mirror,
    "item_shield": item_shield,
    "item_death": item_death,
    "item_roulette": item_roulette,
    "item_cloak": item_cloak,
    "item_soul_swap": item_soul_swap,
}
PEAK = 0.7
# Sounds that sit lower in the mix than the rest.
PEAKS = {"truth": 0.42, "lie": 0.42, "coin_1": 0.38, "coin_2": 0.38, "coin_3": 0.38}


def write(name, samples):
    # A few ms of fade at both ends: no click when the sound starts or is cut.
    fade = int(0.004 * RATE)
    for i in range(min(fade, len(samples))):
        samples[i] *= i / fade
        samples[-1 - i] *= i / fade
    level = PEAKS.get(name, PEAK)
    peak = (max(abs(s) for s in samples) or 1.0) / level
    frames = b"".join(struct.pack("<h", int(s / peak * 32767)) for s in samples)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(frames)
    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) / peak
    print("%-16s %.2fs  rms %.3f" % (name, len(samples) / RATE, rms))


if __name__ == "__main__":
    for sound in sys.argv[1:] or SOUNDS:
        write(sound, SOUNDS[sound]())
