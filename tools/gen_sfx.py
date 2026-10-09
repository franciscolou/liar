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


def chalk():
    """A stroke of chalk across a table: it catches and slips on the grain."""
    out = bandpass(noise(0.34, 0.03, 0.5, 7), 1500, 6500)
    rng = random.Random(9)
    grip = [rng.uniform(0.25, 1.0) for _ in range(40)]
    # Loud where it catches, nearly silent where it skips.
    out = [s * grip[int(i / RATE * 90) % 40] * min(1.0, (len(out) - i) / (0.05 * RATE)) for i, s in enumerate(out)]
    # And the two short strokes of the head.
    for at in (0.3, 0.38):
        mix(out, bandpass(noise(0.07, 0.008, 0.05, 11 + int(at * 100)), 1800, 7000), at, 0.8)
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
    """A pistol fired once, close: crack, punch and a short room."""
    out = silence(0.8)
    mix(out, noise(0.05, 0.0002, 0.016, 25), 0.0, 1.7)
    mix(out, highpass(noise(0.012, 0.0001, 0.004, 26), 3000), 0.0, 1.2)
    mix(out, tone(160, 0.3, 0.0005, 0.13, glide=0.25), 0.0, 2.0)
    mix(out, lowpass(noise(0.25, 0.0005, 0.08, 27), 500), 0.0, 1.4)
    tail = lowpass(noise(0.75, 0.003, 0.28, 28), lambda t: 300 + 4500 * math.exp(-t * 9.0))
    mix(out, tail, 0.01, 0.7)
    mix(out, lowpass(noise(0.15, 0.002, 0.06, 29), 2000), 0.1, 0.3)
    return drive(out[:int(0.8 * RATE)], 4.5)


def steel_click(weight=1.0, seed=27):
    """A steel part of a gun catching on another; the higher `weight`, the
    bigger and lower the part."""
    out = silence(0.16)
    mix(out, bandpass(noise(0.03, 0.0004, 0.009, seed), 900 / weight, 5500 / weight), 0.0, 1.0)
    for freq, gain, decay in ((1250, 0.6, 0.02), (2100, 0.5, 0.016), (3400, 0.3, 0.011)):
        mix(out, tone(freq / weight, 0.1, 0.0004, decay * weight), 0.0, gain)
    # The mass behind it: the knock carried by the frame of the gun.
    mix(out, lowpass(noise(0.06, 0.0006, 0.02 * weight, seed + 1), 700), 0.0, 0.9 * weight)
    mix(out, tone(260 / weight, 0.12, 0.001, 0.035 * weight, glide=0.65), 0.0, 0.7 * weight)
    return out


def drive(samples, amount):
    """Soft saturation: thickens a sound and brings its quiet parts up."""
    peak = max(abs(s) for s in samples) or 1.0
    return [math.tanh(amount * s / peak) for s in samples]


def gunshot(seconds=1.9, seed=101):
    """A revolver fired in a closed room, too close: the crack, the blast in
    the chest, the walls throwing it back and the ears left ringing."""
    out = silence(seconds)
    # The crack.
    mix(out, noise(0.07, 0.0002, 0.022, seed), 0.0, 1.8)
    mix(out, highpass(noise(0.015, 0.0001, 0.005, seed + 1), 3000), 0.0, 1.3)
    # The blast: a boom falling into the floor, and the air it moves.
    mix(out, tone(150, 0.7, 0.0005, 0.32, glide=0.2), 0.0, 2.4)
    mix(out, tone(46, 0.9, 0.004, 0.5), 0.0, 1.6)
    mix(out, lowpass(noise(0.5, 0.0005, 0.16, seed + 2), 450), 0.0, 1.8)
    # The room: the blast darkening as it dies, slapping back off the walls.
    tail = lowpass(noise(seconds, 0.003, 0.75, seed + 3), lambda t: 260 + 5200 * math.exp(-t * 5.0))
    mix(out, tail, 0.01, 0.9)
    for k, (delay, gain) in enumerate(((0.09, 0.5), (0.21, 0.32), (0.38, 0.2), (0.6, 0.11))):
        echo = lowpass(noise(0.22, 0.002, 0.09, seed + 4 + k), 2200 - 400 * k)
        mix(out, echo, delay, gain)
        mix(out, tone(90 - 10 * k, 0.2, 0.002, 0.09, glide=0.6), delay, gain)
    out = drive(out[:int(seconds * RATE)], 5.0)
    # The ears: a thin whine left behind, added after the saturation.
    for freq, gain in ((3420, 0.035), (3466, 0.025)):
        mix(out, tone(freq, seconds - 0.1, 0.12, 1.3), 0.05, gain)
    return out[:int(seconds * RATE)]


def item_roulette():
    """Under the spin of the cylinder: a low, uneasy drone that swells until
    the cylinder stops."""
    seconds = 1.9
    out = silence(seconds)
    for freq, gain in ((49.0, 1.0), (51.2, 0.8), (73.4, 0.45), (98.6, 0.25)):
        mix(out, tone(freq, seconds, 1.5, 0.25, "tri"), 0.0, gain)
    air = lowpass(noise(seconds, 1.5, 0.25, 93), 320)
    mix(out, air, 0.0, 0.6)
    return lowpass(out, 500)


def item_roulette_tick():
    """One chamber of the cylinder going past the ratchet."""
    return steel_click(1.25, 27)


def item_roulette_cock():
    """The hammer hauled back: the sear, then the full cock."""
    out = silence(0.34)
    mix(out, steel_click(1.5, 97), 0.0, 0.6)
    mix(out, steel_click(2.3, 99), 0.085, 1.0)
    mix(out, tone(110, 0.16, 0.002, 0.07, glide=0.7), 0.085, 0.7)
    mix(out, tone(2300, 0.12, 0.001, 0.05), 0.09, 0.06)
    return drive(out, 2.2)


def item_roulette_shot():
    return gunshot()


def item_soul_swap():
    """Two voices crossing."""
    out = silence(0.8)
    mix(out, tone(330, 0.7, 0.05, 0.5, glide=2.5, vibrato=0.012), 0.0, 0.6)
    mix(out, tone(825, 0.7, 0.05, 0.5, glide=0.4, vibrato=0.012), 0.0, 0.6)
    mix(out, lowpass(noise(0.6, 0.2, 0.3, 33), 1200), 0.0, 0.2)
    return out


# --- abilities ----------------------------------------------------------------

def pluck(freq, seconds=0.5, decay=0.3):
    """A gut string plucked: bright at the start, mellow as it dies."""
    out = silence(seconds)
    for n in range(1, 8):
        mix(out, tone(freq * n, seconds, 0.002, decay / n ** 0.8), 0.0, 1.0 / n ** 1.1)
    mix(out, highpass(noise(0.01, 0.0005, 0.004, int(freq)), 2000), 0.0, 0.3)
    return out


def wood_knock(seed=61):
    """A gavel on its block."""
    out = silence(0.3)
    mix(out, lowpass(noise(0.05, 0.0004, 0.014, seed), 1800), 0.0, 1.0)
    for freq, gain, decay in ((175, 0.9, 0.06), (410, 0.6, 0.04), (720, 0.35, 0.025)):
        mix(out, tone(freq, 0.2, 0.0005, decay), 0.0, gain)
    mix(out, lowpass(noise(0.25, 0.01, 0.1, seed + 1), 700), 0.02, 0.12)
    return out


def small_shot(seed=71):
    """One round of a burst: all crack, little room."""
    out = silence(0.3)
    mix(out, noise(0.04, 0.0002, 0.012, seed), 0.0, 1.5)
    mix(out, tone(130, 0.12, 0.0005, 0.06, glide=0.35), 0.0, 1.6)
    mix(out, lowpass(noise(0.25, 0.002, 0.09, seed + 1), 1500), 0.0, 0.4)
    return out


def fx_blade():
    """Steel out of the sheath, then the cut."""
    out = silence(0.75)
    draw = bandpass(noise(0.22, 0.05, 0.1, 63), lambda t: 1800 + 22000 * t, lambda t: 5000 + 30000 * t)
    mix(out, draw, 0.0, 0.7)
    for freq, gain in ((4150, 0.3), (6300, 0.22), (7900, 0.15)):
        mix(out, tone(freq, 0.45, 0.08, 0.2), 0.02, gain)
    mix(out, lowpass(noise(0.08, 0.001, 0.03, 65), 900), 0.26, 1.1)
    mix(out, tone(95, 0.15, 0.001, 0.07, glide=0.6), 0.26, 0.9)
    mix(out, highpass(noise(0.05, 0.001, 0.02, 67), 3000), 0.26, 0.35)
    return out


def fx_shade():
    """Something quick and quiet crossing the table, close to the ground."""
    out = silence(0.7)
    body = noise(0.5, 0.22, 0.1, 141)
    mix(out, bandpass(body, 250, lambda t: 500 + 2600 * math.exp(-((t - 0.3) / 0.11) ** 2)), 0.04, 1.0)
    mix(out, lowpass(noise(0.12, 0.02, 0.04, 143), 600), 0.0, 0.35)
    return out


def fx_lute():
    """A sly little run on the lute."""
    out = silence(1.0)
    for i, freq in enumerate((293.7, 349.2, 440.0, 523.3, 587.3)):  # D4 F4 A4 C5 D5
        mix(out, pluck(freq, 0.6, 0.32), i * 0.075, 0.7)
    mix(out, pluck(146.8, 0.8, 0.5), 0.0, 0.5)
    return out


def harp(freq, seconds, decay):
    """A harp string, plucked with the flesh of the finger: the instrument
    the Bard's tunes are played on. Soft and round where pluck() is bright:
    the overtones fall away as on a real string plucked two fifths of the
    way along it (a little brighter than 1/n squared, which was found
    muffled; every fifth one missing), the higher
    ones die much sooner than the note, they are a hair sharp as on a
    stretched string, and the attack is a small thump instead of a click.
    `freq` may be a function of t, for a note that is bent."""
    pitch = freq if callable(freq) else (lambda t: freq)
    out = silence(seconds)
    for n in range(1, 15):
        level = abs(math.sin(n * math.pi * 0.4)) / n ** 1.5
        if level < 0.004:
            continue
        sharp = n * math.sqrt(1.0 + 0.00012 * n * n)
        partial = tone(lambda t, k=sharp: pitch(t) * k, seconds, 0.005, decay / (1.0 + 0.16 * (n - 1) ** 1.2))
        mix(out, partial, 0.0, level)
    mix(out, lowpass(noise(0.02, 0.001, 0.008, int(pitch(0.0))), 2200), 0.0, 0.1)
    return out


def bent(below, freq, climb=0.06):
    """The pitch of a note bent into: it starts at `below` and is at `freq`
    within `climb` seconds (a smooth scoop, easing out, like the way a
    saxophone gets to a note; quick unless told otherwise), and just after
    that it has a very slight vibrato (5 Hz, 12 cents each way)."""
    scoop = 1200.0 * math.log2(below / freq)

    def pitch(t):
        left = max(1.0 - t / climb, 0.0)
        waver = 12.0 * math.sin(TAU * 5.0 * (t - climb - 0.01)) if t > climb + 0.01 else 0.0
        return freq * 2.0 ** ((scoop * left * left + waver) / 1200.0)
    return pitch


def serenade_lead(melody, hold=True):
    """The melody of one of the Bard's tunes, played while the coins of a
    Swindle dance over to him, with nothing under it yet. It is given, note
    for note and to the hundredth of a second (3/4 at 75 to the minute), as
    (frequency, start, duration): notes plucked on a harp, nothing added to
    them and none of their rests filled. A fourth value is the pitch a note
    is bent into from (see bent), and a fifth how long the bend takes. With
    `hold`, the last one is held instead: struck as written (a B flat) and
    slid up a whole tone to C with a vibrato on it. Each tune then builds
    its own room around it, and is passed through lowpass(out, 4800) at the
    end."""
    # How loud the harp is over what is under it.
    lead = 1.5
    # A string that is stopped is damped by the hand, not cut: this much
    # of it is still heard after the time the note was given.
    release = 0.12
    out = silence(4.6)
    for entry in melody[:-1] if hold else melody:
        freq, at, note = entry[:3]
        # A long note is let ring for its whole time instead of dying early.
        decay = max(0.5, note * 1.4)
        # A note held for more than a second is let go of slowly, inside its
        # own time, instead.
        short = note <= 1.0
        pick = harp(freq if len(entry) == 3 else bent(entry[3], freq, *entry[4:]), note + (release if short else 0.0), decay)
        fade = int((release if short else 0.7) * RATE)
        pick = [s * min(1.0, (len(pick) - i) / fade) for i, s in enumerate(pick)]
        mix(out, pick, at, lead)
    if not hold:
        return out
    # The last note alone is held (asked for after the rest was fixed). It
    # is struck as B flat and carried up to C: a slow slide of a whole tone
    # with an even vibrato on it all the way, the same small amount above
    # and below.
    low, at, _note = melody[-1]
    held = 2.5
    # It is let go of gently: the last stretch of it fades to nothing.
    fade_out = 1.0

    def sliding(t):
        # Still on B flat for a moment, then up, easing in and out.
        up = min(max(t - 0.25, 0.0) / 0.95, 1.0)
        up = up * up * (3.0 - 2.0 * up)
        waver = 14.0 * min(t / 0.2, 1.0) * math.sin(TAU * 5.5 * t)
        return low * 2.0 ** ((200.0 * up + waver) / 1200.0)

    # It dies away slowly, so that the slide is heard to its end.
    ringing = harp(sliding, held, 4.5)
    ringing = [s * min(1.0, (len(ringing) - i) / (fade_out * RATE)) for i, s in enumerate(ringing)]
    mix(out, ringing, at, lead)
    return out


def fx_serenade():
    """The first tune: nine notes of 0.3 s each. The room around it is noir,
    slow and unresolved: a bass that barely moves (F, C, D flat, C), a low
    drone, dark chords on a vibraphone (F minor 9, D flat major 7, and a C7
    with a sharp nine left hanging) and a brush on the second and third
    beats."""
    f4, gs4, as4, c5, ds5 = 349.23, 415.30, 466.16, 523.25, 622.25
    starts = ((f4, 0.0), (f4, 0.4), (gs4, 1.2), (f4, 1.4), (gs4, 1.6), (ds5, 1.8), (c5, 2.2), (as4, 2.4), (as4, 2.8))
    out = serenade_lead([(freq, at, 0.3) for freq, at in starts])
    mix(out, lowpass(tone(43.65, 4.4, 0.6, 5.0), 200), 0.0, 0.5)
    for freq, at, ring in ((87.31, 0.0, 1.5), (130.81, 1.6, 0.8), (69.30, 2.4, 0.6), (65.41, 2.8, 1.7)):
        mix(out, upright_bass(freq, ring, ring * 0.8), at, 0.75)
    chords = (((207.65, 261.63, 311.13, 392.0), 0.0, 2.3), ((207.65, 261.63, 349.23), 2.4, 0.5),
              ((164.81, 233.08, 311.13), 2.8, 1.7))
    for chord, at, ring in chords:
        for i, freq in enumerate(chord):
            mix(out, vibes(freq, ring, ring * 0.8), at + i * 0.012, 0.16)
    for at in (0.8, 1.6, 3.2, 4.0):
        mix(out, brush(0.16, 43 + int(at * 10)), at, 0.22)
    return lowpass(out, 4800)


def fx_serenade_2():
    """The second tune: seven notes, a blues riff that climbs only as far as
    the B flat and waits there. Its room is its own, a con being walked up to
    and pulled off: no drone and no pad. The bass walks up under the riff (F,
    A flat, B flat, a B natural slipped into the rest, C), a piano answers
    in the gaps (a dry F minor 7, then the bare tritone of C7 under the held
    B flat), and when the note gets to C the tune lands, where the first one
    is left hanging: F minor with its sixth and ninth rolled on the
    vibraphone, the low F under it and a brush stirred on the snare."""
    f4, gs4, as4 = 349.23, 415.30, 466.16
    out = serenade_lead(((f4, 0.0, 0.2), (f4, 0.4, 0.8), (gs4, 1.2, 0.2), (f4, 1.4, 0.2), (gs4, 1.6, 0.2),
                         (as4, 1.8, 0.2), (as4, 2.2, 0.2)))
    walk = ((87.31, 0.0, 0.7, 0.75), (103.83, 0.8, 0.7, 0.7), (116.54, 1.6, 0.4, 0.7), (123.47, 2.0, 0.2, 0.55),
            (130.81, 2.4, 0.8, 0.8), (87.31, 3.2, 1.5, 0.85))
    for freq, at, ring, gain in walk:
        mix(out, upright_bass(freq, ring, ring * 0.8), at, gain)
    # The piano, short and dry, under the long F and in the rest.
    for freq in (207.65, 261.63, 311.13):
        mix(out, piano(freq, 0.35, 0.22), 0.8, 0.14)
    for freq in (164.81, 233.08):
        mix(out, piano(freq, 0.8, 0.6), 2.4, 0.16)
    # Home: the chord is rolled upwards as the held note arrives.
    for i, freq in enumerate((207.65, 293.66, 392.0, 587.33)):
        mix(out, vibes(freq, 1.5, 1.3), 3.2 + i * 0.05, 0.15)
    mix(out, lowpass(tone(43.65, 1.5, 0.3, 2.0), 200), 3.2, 0.45)
    for at in (0.8, 1.6, 2.0):
        mix(out, brush(0.12, 43 + int(at * 10)), at, 0.2)
    mix(out, brush(1.2, 77), 3.2, 0.1)
    return lowpass(out, 4800)


def fx_serenade_3():
    """The third tune ("aguda", the high one): eight short notes that come
    down from a high F and then rock between A flat and C, the first and the
    seventh bent into from a whole tone below (the seventh slowly, in 0.2 s,
    and lasting until the next note: at the 0.06 s it was given, with the
    bass coming in under it, the bend could not be heard). The last one, an
    A flat, is
    left ringing where it is (asked for; no slide on this one). Its room is the darkest of the three and the slowest: nothing
    in it keeps time. Three long chords on the vibraphone, each rolled, over
    a bass that sinks by half a step into the last one: B flat minor 11 (a
    cluster, C against D flat), the G flat seventh a tritone away from the
    dominant, in which the A flat and C of the lute are the ninth and the
    sharp eleventh, and F minor 11, stacked low and close under the A flat
    the lute is left on (B minor and B flat minor were tried there and
    turned down). A low F comes in under it and a brush is stirred, not
    tapped. Nothing is added above the tune."""
    gs4, as4, c5, ds5, f5 = 415.30, 466.16, 523.25, 622.25, 698.46
    out = serenade_lead(((f5, 0.0, 0.2, ds5), (ds5, 0.6, 0.2), (as4, 1.2, 0.2), (gs4, 1.6, 0.2), (c5, 1.8, 0.2),
                         (gs4, 2.2, 0.2), (c5, 2.4, 0.4, as4, 0.2), (gs4, 2.8, 1.8)), False)
    for freq, at, ring, slide in ((58.27, 0.0, 1.6, 1.0), (92.50, 1.6, 0.8, 1.0), (87.31, 2.4, 2.2, 1.0)):
        mix(out, upright_bass(freq, ring, ring * 0.8, slide), at, 0.75)
    mix(out, lowpass(tone(43.65, 2.2, 0.5, 2.6), 200), 2.4, 0.45)
    chords = (((207.65, 261.63, 277.18, 311.13), 0.0, 1.7), ((164.81, 233.08, 277.18), 1.6, 0.9),
              ((155.56, 207.65, 233.08, 261.63), 2.5, 2.1))
    # (The last chord waits a tenth of a second: the lute bends into its C
    # at 2.4, and with the chord struck on top of it the bend was not heard.)
    for chord, at, ring in chords:
        for i, freq in enumerate(chord):
            mix(out, vibes(freq, ring, ring * 0.8), at + i * 0.035, 0.15)
    for at, seed in ((0.0, 81), (2.4, 83)):
        stir = noise(1.5, 0.5, 1.0, seed)
        mix(out, bandpass(stir, 1500, 5000), at, 0.05)
    return lowpass(out, 4800)


def fx_serenade_4():
    """The fourth tune ("volta", the way back): nine short notes, a quick
    leap up and a turn around B flat, the last one a C bent into from a
    whole tone below. That one is held (asked for, with the bend drawn out
    to match: it takes 0.7 s to get up to the C) and rings to the end. Its
    room is slow and dark like the third's, but it is a felt piano that
    plays the chords here, low and rolled, and it ends where it began: D
    flat major 9 under the leap, a C with its fourth and a flat nine under
    the turn (B flat minor over a C in the bass), and where F minor was due,
    D flat again, with a sharp eleventh and the C of the lute as its major
    seventh. That last chord comes in with the note before the last (asked
    for), so that the held note climbs over it. The bass goes D flat, C, D flat, a low D flat comes in under
    the last chord and a brush is stirred as it rings."""
    ds4, f4, gs4, as4, c5, ds5 = 311.13, 349.23, 415.30, 466.16, 523.25, 622.25
    out = serenade_lead(((ds4, 0.0, 0.2), (f4, 0.2, 0.2), (ds5, 0.4, 0.2), (as4, 0.6, 0.2), (as4, 1.2, 0.2),
                         (gs4, 1.4, 0.2), (f4, 1.6, 0.2), (as4, 1.8, 0.2), (c5, 2.2, 2.3, as4, 0.7)), False)
    for freq, at, ring in ((69.30, 0.0, 1.2), (65.41, 1.2, 0.6), (69.30, 1.8, 2.8)):
        mix(out, upright_bass(freq, ring, ring * 0.8), at, 0.75)
    mix(out, lowpass(tone(34.65, 2.8, 0.5, 3.2), 200), 1.8, 0.45)
    chords = (((174.61, 207.65, 261.63, 311.13), 0.0, 1.3), ((233.08, 277.18, 349.23), 1.2, 0.7),
              ((174.61, 207.65, 261.63, 392.0), 1.8, 2.8))
    for chord, at, ring in chords:
        for i, freq in enumerate(chord):
            mix(out, piano(freq, ring, ring * 0.8), at + i * 0.04, 0.12)
    mix(out, bandpass(noise(1.5, 0.5, 1.0, 87), 1500, 5000), 1.8, 0.05)
    return lowpass(out, 4800)


def fx_serenade_5():
    """The fifth tune ("harmonia"): the lute plays two strings at a time,
    five pairs and one note alone, and the last pair (F and D) is held for
    0.8 s, both strings struck and stopped together. No bend, no vibrato and
    nothing held beyond that: the notes are as given. The tune brings its
    own harmony, so its room is the barest of them: a bass in long notes (A
    flat, F, B flat) and two or three soft bars of the vibraphone under each
    stretch, only the notes the lute leaves out: A flat major 9, F minor 9
    and, under the last pair, a B flat ninth left open. A brush is stirred
    as it rings."""
    ds4, f4, gs4, as4, c5, d5, ds5 = 311.13, 349.23, 415.30, 466.16, 523.25, 587.33, 622.25
    out = serenade_lead(((ds5, 0.0, 0.2), (as4, 0.0, 0.2), (gs4, 0.4, 0.2), (ds5, 0.4, 0.2), (ds4, 1.0, 0.2),
                         (f4, 1.2, 0.2), (c5, 1.2, 0.2), (gs4, 1.6, 0.2), (c5, 1.6, 0.2),
                         (f4, 2.2, 0.8), (d5, 2.2, 0.8)), False)
    for freq, at, ring in ((51.91, 0.0, 1.2), (87.31, 1.2, 1.0), (58.27, 2.2, 2.4)):
        mix(out, upright_bass(freq, ring, ring * 0.8), at, 0.75)
    chords = (((196.0, 261.63), 0.0, 1.3), ((155.56, 196.0, 207.65), 1.2, 1.1), ((207.65, 261.63, 293.66), 2.2, 2.4))
    for chord, at, ring in chords:
        for i, freq in enumerate(chord):
            mix(out, vibes(freq, ring, ring * 0.8), at + i * 0.035, 0.14)
    mix(out, bandpass(noise(1.5, 0.5, 1.0, 91), 1500, 5000), 2.2, 0.05)
    return lowpass(out, 4800)


def fx_doll_hit():
    """A rag doll thrown against wood: a soft thump, and the straw in it."""
    out = silence(0.4)
    mix(out, tone(120, 0.2, 0.002, 0.09, glide=0.5), 0.0, 1.0)
    mix(out, lowpass(noise(0.12, 0.002, 0.07, 221), 900), 0.0, 0.9)
    mix(out, bandpass(noise(0.22, 0.01, 0.16, 223), 2500, 7000), 0.02, 0.18)
    return out


def fx_lute_flourish():
    """A quick turn and a bright chord: nothing sticks to him."""
    out = silence(0.8)
    for i, freq in enumerate((587.3, 523.3, 587.3)):
        mix(out, pluck(freq, 0.3, 0.15), i * 0.06, 0.6)
    for freq in (293.7, 370.0, 440.0, 587.3):  # D major
        mix(out, pluck(freq, 0.55, 0.36), 0.2, 0.5)
    return out


def fx_cash():
    """A cash register: the bell, the drawer, the change."""
    out = silence(0.9)
    mix(out, bell(2093.0, 0.6, 0.45), 0.0, 0.6)
    mix(out, bell(2637.0, 0.5, 0.35), 0.0, 0.3)
    mix(out, steel_click(1.8, 73), 0.09, 0.8)
    mix(out, lowpass(noise(0.12, 0.01, 0.05, 75), 900), 0.1, 0.5)
    for i, at in enumerate((0.2, 0.27, 0.36)):
        mix(out, coin(((0.0, 1.0), (0.01, 0.4)), 0.95 + 0.05 * i, 77 + i), at, 0.35)
    return out


def fx_gavel():
    """One knock of a gavel on its sounding block: hardwood on hardwood, a
    dry hollow "tock" with hardly any hiss in it."""
    out = silence(0.4)
    # The contact: a short, dull click.
    mix(out, lowpass(noise(0.012, 0.0003, 0.004, 61), 2600), 0.0, 0.7)
    # The block: the modes of a bar of wood, the low ones ringing longest.
    for freq, gain, decay in ((235, 1.0, 0.075), (545, 0.8, 0.05), (905, 0.5, 0.034), (1380, 0.28, 0.022), (1990, 0.12, 0.014)):
        mix(out, tone(freq, 0.3, 0.0006, decay), 0.0, gain)
    # The bench under it.
    mix(out, tone(118, 0.2, 0.001, 0.07, glide=0.8), 0.0, 0.7)
    mix(out, lowpass(noise(0.2, 0.006, 0.06, 62), 500), 0.01, 0.1)
    return drive(out, 1.6)


def chain_rattle(seconds, links, seed):
    """A small chain shaken: `links` little knocks of metal on metal, thick at
    the start and thinning out."""
    rng = random.Random(seed)
    out = silence(seconds + 0.12)
    for _ in range(links):
        at = seconds * rng.random() ** 1.8
        freq = rng.uniform(2600, 6200)
        strength = rng.uniform(0.3, 1.0) * (1.0 - 0.6 * at / seconds)
        mix(out, tone(freq, 0.1, 0.0004, rng.uniform(0.02, 0.05)), at, 0.5 * strength)
        mix(out, tone(freq * 1.51, 0.06, 0.0004, 0.015), at, 0.25 * strength)
        mix(out, highpass(noise(0.004, 0.0002, 0.0015, rng.randrange(1 << 30)), 5000), at, 0.6 * strength)
    return out


def fx_scales_chain():
    """The scales of the court set down: the foot on the table, the chains
    shaking out and the pans coming to rest."""
    out = silence(0.6)
    mix(out, tone(150, 0.12, 0.001, 0.05, glide=0.7), 0.0, 0.5)
    mix(out, lowpass(noise(0.05, 0.001, 0.02, 241), 900), 0.0, 0.5)
    mix(out, chain_rattle(0.42, 14, 243), 0.03, 0.8)
    for freq, gain in ((1180, 0.12), (1873, 0.08)):
        mix(out, tone(freq, 0.4, 0.002, 0.25), 0.06, gain)
    return out


def fx_scales():
    """The scales thrown over: the beam slams against its stop, the whole
    brass frame rings with it and the chains go on shaking underneath."""
    out = silence(1.7)
    # The blow: metal on metal, and the weight of the thing behind it.
    mix(out, bandpass(noise(0.05, 0.0003, 0.018, 231), 700, 7500), 0.0, 1.3)
    mix(out, tone(72, 0.35, 0.001, 0.16, glide=0.55), 0.0, 1.5)
    mix(out, lowpass(noise(0.2, 0.001, 0.07, 233), 420), 0.0, 0.8)
    # The frame: the modes of a heavy bar of brass, each one doubled a hair
    # apart, so that the ring beats as it dies.
    for ratio, gain, decay in ((1.0, 1.0, 1.3), (2.76, 0.8, 0.95), (5.4, 0.55, 0.6), (8.93, 0.35, 0.35), (13.3, 0.2, 0.2)):
        for detune in (1.0, 1.007):
            mix(out, tone(164.0 * ratio * detune, 1.6, 0.001, decay), 0.0, gain * 0.5)
    # The pans, struck a moment later as the chains pull tight.
    for freq, gain, decay in ((1180, 0.3, 0.5), (1873, 0.22, 0.4), (2960, 0.16, 0.28)):
        mix(out, tone(freq, 0.9, 0.001, decay), 0.012, gain)
    mix(out, chain_rattle(0.55, 16, 235), 0.04, 0.3)
    return drive(out[:int(1.7 * RATE)], 1.8)


def fx_firework_launch():
    """A rocket screaming up: a whistle that starts as high as it gets and
    sinks and thins out as it goes, over the hiss of its tail."""
    seconds = 0.62
    out = silence(seconds)
    mix(out, lowpass(noise(0.04, 0.001, 0.015, 253), 1500), 0.0, 0.5)
    # Two reeds a hair apart, so that it shrieks rather than sings.
    for detune, gain in ((1.0, 1.0), (1.013, 0.6), (2.0, 0.18)):
        mix(out, tone(lambda t: 4300 * detune * math.exp(-t * 1.15), seconds, 0.012, 0.42, vibrato=0.012), 0.0, gain)
    mix(out, bandpass(noise(seconds, 0.02, 0.3, 251), 3000, 9000), 0.0, 0.35)
    return out


def firework(seed, chord, pitch=1.0, sparks=22):
    """A shell bursting the way a cartoon draws it: a snap, a fat boom that
    drops like a slide whistle let go, a bright chord of stars thrown out
    with it, and the sparks crackling down."""
    rng = random.Random(seed)
    out = silence(1.45)
    mix(out, noise(0.03, 0.0003, 0.01, seed), 0.0, 1.3)
    mix(out, tone(430 * pitch, 0.3, 0.001, 0.13, shape="square", glide=0.14), 0.0, 0.9)
    mix(out, tone(150 * pitch, 0.45, 0.002, 0.22, glide=0.3), 0.0, 1.8)
    mix(out, lowpass(noise(0.5, 0.002, 0.17, seed + 1), lambda t: 400 + 7000 * math.exp(-t * 13.0)), 0.0, 1.3)
    out = drive(out, 2.6)
    for i, freq in enumerate(chord):
        mix(out, bell(freq, 0.8, 0.55), 0.03 + 0.045 * i, 0.16)
    for _ in range(sparks):
        late = rng.random() ** 1.5
        crack = highpass(noise(0.012, 0.0003, rng.uniform(0.002, 0.006), rng.randrange(1 << 30)), rng.uniform(2500, 6000))
        mix(out, crack, 0.14 + 0.95 * late, rng.uniform(0.12, 0.34) * (1.0 - 0.6 * late))
    return out[:int(1.45 * RATE)]


def status_break():
    """A status coming off: something small and brittle snapped in two, and
    the bits of it landing."""
    out = silence(0.4)
    mix(out, highpass(noise(0.012, 0.0003, 0.004, 261), 2500), 0.0, 1.0)
    mix(out, tone(260, 0.06, 0.0005, 0.03, glide=0.6), 0.0, 0.5)
    for freq, gain, decay in ((2350, 0.5, 0.06), (3320, 0.35, 0.045), (4870, 0.2, 0.03)):
        mix(out, tone(freq, 0.2, 0.0005, decay), 0.0, gain)
    for i, at in enumerate((0.07, 0.12, 0.19)):
        mix(out, tone(3900 + 700 * i, 0.08, 0.0005, 0.025), at, 0.16 - 0.04 * i)
        mix(out, highpass(noise(0.004, 0.0002, 0.0015, 263 + i), 5000), at, 0.2)
    return out


def fx_zap():
    """A wand let off: the snap of it, a bright ray dropping in pitch as it
    flies, crackling, and the sparkle where it lands."""
    out = silence(0.62)
    mix(out, highpass(noise(0.02, 0.0005, 0.008, 291), 3000), 0.0, 0.8)
    ray = tone(lambda t: 900 + 3200 * math.exp(-t * 14.0), 0.3, 0.003, 0.16, shape="saw")
    mix(out, lowpass(ray, 6000), 0.0, 0.45)
    mix(out, tone(lambda t: 1800 + 2600 * math.exp(-t * 10.0), 0.3, 0.003, 0.14), 0.0, 0.5)
    crackle = bandpass(noise(0.25, 0.005, 0.12, 293), 2500, 8000)
    mix(out, [s * (0.5 + 0.5 * math.sin(TAU * 55.0 * i / RATE)) for i, s in enumerate(crackle)], 0.0, 0.35)
    for i, freq in enumerate((2093.0, 2637.0, 3136.0, 4186.0)):
        mix(out, bell(freq, 0.35, 0.25), 0.1 + 0.035 * i, 0.16)
    return out


def fx_poof():
    """A rising whistle, a puff of smoke and the sparkle after it."""
    out = silence(1.05)
    mix(out, tone(420, 0.3, 0.05, 0.3, glide=3.6), 0.0, 0.35)
    mix(out, lowpass(noise(0.4, 0.004, 0.14, 81), lambda t: 500 + 5000 * math.exp(-t * 14.0)), 0.3, 1.0)
    mix(out, tone(110, 0.15, 0.002, 0.07, glide=0.5), 0.3, 0.6)
    for i, freq in enumerate((1568.0, 1975.5, 2349.3, 3136.0)):
        mix(out, bell(freq, 0.4, 0.3), 0.5 + i * 0.055, 0.22)
    return out


def fx_conjure():
    """Something printed out of thin air, row by row, and the chime when it is whole."""
    out = silence(1.6)
    # The hum of it coming, climbing all the way.
    mix(out, tone(196.0, 0.86, 0.25, 0.9, "tri", glide=3.0, vibrato=0.012), 0.0, 0.2)
    # The rows: quick glassy ticks, each a step higher.
    steps = (0, 2, 4, 7, 9)
    for i in range(14):
        freq = 659.3 * 2 ** ((steps[i % 5] + 12 * (i // 5)) / 12.0)
        mix(out, tone(freq, 0.09, 0.002, 0.05, "tri"), 0.03 + i * 0.058, 0.3)
        mix(out, highpass(noise(0.012, 0.0004, 0.004, 231 + i), 5000), 0.03 + i * 0.058, 0.1)
    # Whole: a bright chord.
    for i, freq in enumerate((1568.0, 1975.5, 2349.3, 3136.0)):
        mix(out, bell(freq, 0.6, 0.45), 0.86 + i * 0.012, 0.3)
    return out


def fx_shimmer():
    """One thing becoming two."""
    out = silence(0.8)
    for i, freq in enumerate((1318.5, 1975.5, 2637.0)):
        swell = tone(freq, 0.45, 0.28, 0.08, vibrato=0.004)
        mix(out, swell, i * 0.03, 0.4)
        mix(out, tone(freq * 1.006, 0.5, 0.004, 0.3), 0.33, 0.3)
    return out


def fx_sniper_aim():
    """A laser sight settling on somebody: a thin whine and a beep that
    hurries up. 1.55 s, the time the rifle takes to find its target."""
    out = silence(1.6)
    mix(out, tone(1400, 1.55, 0.3, 4.0, glide=1.5, vibrato=0.01), 0.0, 0.12)
    for at in (0.0, 0.4, 0.72, 0.97, 1.16, 1.3, 1.4, 1.48):
        mix(out, tone(1760, 0.06, 0.002, 0.04), at, 0.5)
    return out


def fx_sniper():
    """One round from a long rifle: the crack, the valley answering twice,
    and the bolt worked afterwards."""
    out = silence(2.4)
    shot = gunshot(1.9, 211)
    mix(out, shot, 0.0, 1.0)
    mix(out, tone(48, 0.6, 0.001, 0.3, glide=0.5), 0.0, 1.6)
    mix(out, bandpass(noise(0.05, 0.0002, 0.015, 213), 2500, 9000), 0.0, 1.2)
    for at, gain, cutoff in ((0.33, 0.3, 1800), (0.71, 0.16, 1100)):
        mix(out, lowpass(shot, cutoff), at, gain)
    mix(out, steel_click(1.5, 215), 1.25, 0.45)
    mix(out, steel_click(1.1, 217), 1.42, 0.5)
    return drive(out[:int(2.4 * RATE)], 3.0)


# The vault (fx_vault) is a recording: see cut_sfx.py.


def fx_shutter():
    """A camera: the shutter and the film advancing."""
    out = silence(0.35)
    mix(out, steel_click(0.7, 97), 0.0, 1.0)
    mix(out, steel_click(0.8, 98), 0.06, 0.8)
    mix(out, bandpass(noise(0.12, 0.01, 0.06, 99), 2000, 5000), 0.1, 0.25)
    return out


def fx_hush():
    """Something slipping out of sight."""
    body = noise(0.45, 0.12, 0.18, 103)
    return mix(silence(0.5), bandpass(body, 500, lambda t: 6000 * math.exp(-t * 5.0) + 700), 0.0, 1.0)


def fx_tin():
    """Loose change shaken out of a tin cup."""
    out = silence(0.7)
    for i, at in enumerate((0.0, 0.07, 0.13, 0.22, 0.28)):
        mix(out, coin(((0.0, 1.0), (0.012, 0.4)), 0.5 + 0.03 * i, 105 + i), at, 0.6)
        mix(out, tone(1150, 0.08, 0.001, 0.03), at, 0.25)
    return out


def fx_scribble():
    """A debt written down and stamped."""
    out = silence(0.75)
    at = 0.0
    for i in range(5):
        stroke = bandpass(noise(0.07, 0.015, 0.035, 111 + i), 1800, 6500)
        mix(out, stroke, at, 0.5 + 0.1 * (i % 2))
        at += 0.075
    mix(out, wood_knock(117), 0.45, 0.9)
    return out


def fx_hex():
    """A drone that should not be in the room, and the needle going in."""
    out = silence(1.45)
    for freq, gain in ((82.4, 1.0), (87.3, 0.8), (116.5, 0.6), (233.1, 0.2)):  # E, F against it, the tritone
        mix(out, tone(freq, 1.4, 0.45, 0.6, "tri", vibrato=0.012), 0.0, gain)
    whisper = bandpass(noise(1.3, 0.5, 0.5, 121), 1500, 4000)
    mix(out, [x * (0.6 + 0.4 * math.sin(TAU * 7.0 * i / RATE)) for i, x in enumerate(whisper)], 0.0, 0.25)
    mix(out, highpass(noise(0.012, 0.0003, 0.004, 123), 3500), 0.6, 0.9)
    mix(out, lowpass(noise(0.1, 0.002, 0.04, 125), 700), 0.6, 0.9)
    mix(out, tone(1900, 0.35, 0.002, 0.16, glide=0.45), 0.6, 0.3)
    return lowpass(out, 5000)


def fade_out(samples, seconds=0.012):
    """Brings the end of a sound down to silence, so a cut note does not click."""
    n = min(int(seconds * RATE), len(samples))
    for i in range(n):
        samples[-1 - i] *= i / n
    return samples


def fx_mask():
    """A mask lifted into place: a swish of cloth, then porcelain on bone."""
    out = silence(0.6)
    mix(out, bandpass(noise(0.25, 0.1, 0.1, 131), 900, lambda t: 2500 + 9000 * t), 0.0, 0.6)
    for freq, gain, decay in ((1320, 0.6, 0.09), (2050, 0.4, 0.06), (3300, 0.2, 0.04)):
        mix(out, tone(freq, 0.25, 0.001, decay), 0.26, gain)
    mix(out, bell(1760.0, 0.3, 0.2), 0.3, 0.15)
    return out


def fx_chips():
    """Clay chips pushed into the pot."""
    out = silence(0.5)
    rng = random.Random(133)
    for i in range(6):
        at = i * 0.045 + rng.uniform(0, 0.012)
        mix(out, highpass(noise(0.012, 0.0004, 0.004, 135 + i), 2200), at, 0.8)
        mix(out, tone(2400 + rng.uniform(-300, 400), 0.04, 0.0005, 0.014), at, 0.5)
        mix(out, tone(880 + rng.uniform(-80, 80), 0.05, 0.0005, 0.018), at, 0.3)
    return out


def fx_coin_flip():
    """A coin rung off a thumbnail, turning in the air."""
    out = silence(0.75)
    mix(out, coin(((0.0, 1.0),), 1.25, 141), 0.0, 0.8)
    ring = tone(5200, 0.7, 0.002, 0.45)
    mix(out, [s * (0.5 + 0.5 * math.sin(TAU * 26.0 * i / RATE)) for i, s in enumerate(ring)], 0.01, 0.3)
    return out


def fx_dig():
    """A shovel driven into wet earth, twice."""
    out = silence(0.8)
    for at, seed in ((0.0, 143), (0.36, 147)):
        mix(out, bandpass(noise(0.18, 0.02, 0.08, seed), 300, 2600), at, 0.9)
        mix(out, tone(110, 0.14, 0.002, 0.07, glide=0.6), at + 0.02, 0.9)
        mix(out, steel_click(1.6, seed + 1), at, 0.35)
        # The earth thrown aside.
        mix(out, lowpass(noise(0.2, 0.03, 0.09, seed + 2), 900), at + 0.14, 0.4)
    return out


def fx_bell():
    """A funeral bell, once."""
    out = silence(1.6)
    mix(out, bell(196.0, 1.5, 1.3, ((1.0, 1.0), (2.0, 0.6), (2.4, 0.45), (3.0, 0.3), (4.5, 0.15))), 0.0, 1.0)
    mix(out, lowpass(noise(0.03, 0.001, 0.012, 151), 1500), 0.0, 0.5)
    return out


def fx_pour():
    """A drink poured, set down and slid along the bar."""
    out = silence(0.85)
    rng = random.Random(153)
    for i in range(14):
        at = i * 0.028 + rng.uniform(-0.006, 0.006)
        mix(out, tone(520 + 40 * i + rng.uniform(-40, 40), 0.05, 0.006, 0.035, glide=1.6), max(at, 0.0), 0.5)
    mix(out, bandpass(noise(0.4, 0.05, 0.2, 155), 1500, 5000), 0.0, 0.12)
    mix(out, bell(2350.0, 0.25, 0.14), 0.45, 0.4)
    mix(out, lowpass(noise(0.03, 0.001, 0.012, 157), 900), 0.45, 0.6)
    mix(out, bandpass(noise(0.3, 0.05, 0.15, 159), 700, 2600), 0.5, 0.3)
    return out


def fx_whistle():
    """A police whistle: one short blast and a longer one, the pea rattling."""
    out = silence(0.62)
    for at, seconds in ((0.0, 0.15), (0.22, 0.32)):
        body = tone(2850, seconds, 0.008, seconds * 2.5)
        trill = [s * (0.55 + 0.45 * math.sin(TAU * 34.0 * i / RATE)) for i, s in enumerate(body)]
        mix(out, fade_out(trill), at, 0.8)
        mix(out, fade_out(tone(5700, seconds, 0.008, seconds * 2.0)), at, 0.15)
        mix(out, fade_out(bandpass(noise(seconds, 0.01, seconds * 2.0, 161), 2500, 7000)), at, 0.25)
    return out


def fx_glint():
    """Light caught on polished brass: one clean ping and the shimmer after it."""
    out = silence(0.7)
    mix(out, bell(3136.0, 0.6, 0.4), 0.0, 0.6)
    mix(out, bell(4186.0, 0.5, 0.3), 0.03, 0.35)
    shimmer = tone(6272, 0.5, 0.05, 0.3)
    mix(out, [x * (0.5 + 0.5 * math.sin(TAU * 18.0 * i / RATE)) for i, x in enumerate(shimmer)], 0.02, 0.15)
    return out


def fx_lasso_spin():
    """A rope going round overhead: three swishes, each a little harder."""
    out = silence(0.8)
    for i, at in enumerate((0.0, 0.24, 0.46)):
        swish = bandpass(noise(0.22, 0.09, 0.09, 201 + i), 500, lambda t: 1800 + 9000 * t)
        mix(out, swish, at, 0.6 + 0.15 * i)
    return out


def fx_lasso():
    """The rope drawn back, cracked out like a whip, and hauled in."""
    out = silence(0.95)
    mix(out, bandpass(noise(0.16, 0.08, 0.06, 207), 500, lambda t: 1200 + 6000 * t), 0.0, 0.5)
    # The strike: a rush that climbs out of hearing and ends in the crack.
    mix(out, bandpass(noise(0.16, 0.12, 0.03, 208), 1500, lambda t: 3000 + 60000 * t), 0.14, 0.9)
    mix(out, highpass(noise(0.018, 0.0003, 0.006, 209), 3000), 0.30, 1.6)
    mix(out, noise(0.03, 0.0003, 0.01, 210), 0.30, 0.8)
    mix(out, tone(170, 0.2, 0.001, 0.09, "tri", glide=0.6), 0.30, 0.8)
    mix(out, lowpass(noise(0.06, 0.001, 0.025, 211), 900), 0.30, 0.7)
    mix(out, bandpass(noise(0.35, 0.1, 0.2, 213), 400, 1800), 0.54, 0.3)
    return out


def fx_lasso_miss():
    """The rope drawn back and cracked out at nothing: it shuts on air, drops and is dragged home."""
    out = silence(1.5)
    mix(out, bandpass(noise(0.16, 0.08, 0.06, 207), 500, lambda t: 1200 + 6000 * t), 0.0, 0.5)
    mix(out, bandpass(noise(0.16, 0.12, 0.03, 208), 1500, lambda t: 3000 + 60000 * t), 0.14, 0.9)
    # No crack: a dry flick where the loop closes on nothing.
    mix(out, highpass(noise(0.014, 0.0003, 0.005, 221), 4000), 0.31, 0.45)
    # It falls on the wood and bounces once.
    for at, gain in ((0.56, 1.0), (0.70, 0.45)):
        mix(out, lowpass(noise(0.08, 0.001, 0.03, 223), 700), at, 0.7 * gain)
        mix(out, tone(105, 0.12, 0.001, 0.05, glide=0.7), at, 0.45 * gain)
    # A let-down note, and the rope dragged back.
    mix(out, tone(392.0, 0.3, 0.02, 0.22, "tri", glide=0.62), 0.74, 0.2)
    mix(out, bandpass(noise(0.4, 0.12, 0.22, 225), 300, 1500), 1.05, 0.28)
    return out


def fx_wave():
    """A shockwave rolling out across the room: the thump, the air rushing
    after it, and a ring of brass on top."""
    out = silence(1.0)
    mix(out, tone(95, 0.5, 0.004, 0.28, glide=0.45), 0.0, 1.6)
    mix(out, lowpass(noise(0.5, 0.01, 0.2, 221), 400), 0.0, 0.8)
    rush = bandpass(noise(0.9, 0.12, 0.45, 223), 300, lambda t: 5000 * math.exp(-t * 3.0) + 500)
    mix(out, rush, 0.02, 0.7)
    mix(out, bell(784.0, 0.6, 0.5), 0.0, 0.12)
    return out


def fx_fuse():
    """A match struck, and a fuse catching."""
    out = silence(0.9)
    mix(out, highpass(noise(0.12, 0.01, 0.05, 183), 3000), 0.0, 0.8)
    hiss = highpass(noise(0.75, 0.08, 0.6, 185), 4500)
    mix(out, [s * (0.6 + 0.4 * math.sin(TAU * 31.0 * i / RATE)) for i, s in enumerate(hiss)], 0.1, 0.5)
    return out


def fx_boom():
    """A powder charge going off in a small room, and what comes down after."""
    out = silence(1.5)
    mix(out, noise(0.06, 0.0003, 0.02, 187), 0.0, 1.6)
    mix(out, tone(70, 0.9, 0.001, 0.4, glide=0.3), 0.0, 2.4)
    mix(out, lowpass(noise(1.4, 0.004, 0.5, 189), lambda t: 200 + 5000 * math.exp(-t * 6.0)), 0.0, 1.4)
    mix(out, lowpass(noise(0.9, 0.2, 0.5, 191), 300), 0.15, 0.6)
    for i, at in enumerate((0.5, 0.68, 0.8, 0.97)):
        mix(out, bandpass(noise(0.05, 0.001, 0.02, 193 + i), 800, 4000), at, 0.25)
    return drive(out[:int(1.5 * RATE)], 3.5)


# The doors themselves (ui_doors_shut, ui_doors_open) are recordings: see cut_sfx.py.


def ui_lock():
    """A key turned in a door: the wards, then the bolt going home."""
    out = silence(0.75)
    for i, at in enumerate((0.1, 0.17, 0.25)):
        mix(out, steel_click(0.6 + 0.08 * i, 321 + i), at, 0.3)
    mix(out, steel_click(1.5, 327), 0.47, 1.0)
    mix(out, tone(95, 0.25, 0.001, 0.09, glide=0.7), 0.47, 0.6)
    return out


def ui_unlock():
    """The bolt drawn back."""
    out = silence(0.5)
    mix(out, steel_click(1.4, 331), 0.0, 1.0)
    mix(out, steel_click(0.7, 333), 0.09, 0.35)
    mix(out, tone(120, 0.2, 0.001, 0.07, glide=1.3), 0.0, 0.4)
    return out


def card_flick(seed, pitch=1.0):
    """One card leaving the deck in a hurry."""
    out = silence(0.09)
    mix(out, bandpass(noise(0.06, 0.008, 0.03, seed), 1800 * pitch, 7000 * pitch), 0.0, 0.8)
    mix(out, highpass(noise(0.02, 0.0005, 0.007, seed + 1), 3000), 0.045, 0.7)
    mix(out, tone(210 * pitch, 0.03, 0.001, 0.015), 0.045, 0.3)
    return out


def ui_deal():
    """A whole table dealt at once: cards flicked out faster than the eye,
    landing on the cloth all over."""
    rng = random.Random(341)
    out = silence(0.95)
    for i in range(20):
        at = 0.02 + 0.66 * i / 19 + rng.uniform(-0.008, 0.008)
        mix(out, card_flick(343 + i * 2, rng.uniform(0.85, 1.2)), at, rng.uniform(0.6, 1.0))
    return out


def ui_flip():
    """A row of cards turned over in one sweep of the hand."""
    rng = random.Random(381)
    out = silence(0.8)
    mix(out, bandpass(noise(0.6, 0.2, 0.3, 383), 1500, lambda t: 2500 + 9000 * t), 0.0, 0.3)
    for i in range(12):
        at = 0.04 + 0.5 * i / 11
        snap = highpass(noise(0.02, 0.0005, 0.008, 385 + i), 2600)
        mix(out, snap, at, rng.uniform(0.35, 0.6))
        mix(out, tone(rng.uniform(170, 230), 0.04, 0.001, 0.02), at, 0.2)
    return out


def ui_gather():
    """The cards swept together across the cloth, squared with two taps on
    the table and taken away."""
    out = silence(0.95)
    mix(out, bandpass(noise(0.5, 0.25, 0.22, 401), 1200, lambda t: 6000 - 5000 * t), 0.0, 0.6)
    for i, at in enumerate((0.52, 0.64)):
        mix(out, lowpass(noise(0.04, 0.0005, 0.012, 403 + i), 2200), at, 0.9 - 0.25 * i)
        mix(out, tone(160, 0.08, 0.0005, 0.04), at, 0.6 - 0.2 * i)
    mix(out, bandpass(noise(0.2, 0.05, 0.1, 407), 900, 3500), 0.74, 0.25)
    return out


SOUNDS = {
    "ui_lock": ui_lock,
    "ui_unlock": ui_unlock,
    "ui_deal": ui_deal,
    "ui_flip": ui_flip,
    "ui_gather": ui_gather,
    "card_draw": card_draw,
    "truth": truth,
    "lie": lie,
    "cancel": cancel,
    "heal": heal,
    "coin_1": lambda: coin(((0.0, 1.0), (0.011, 0.45)), 1.0, 51),
    "coin_2": lambda: coin(((0.0, 0.8), (0.016, 0.6), (0.027, 0.3)), 1.035, 53),
    "coin_3": lambda: coin(((0.0, 1.0), (0.008, 0.35)), 0.97, 55),
    "fx_blade": fx_blade,
    "fx_shade": fx_shade,
    "fx_lute": fx_lute,
    "fx_lute_flourish": fx_lute_flourish,
    "fx_cash": fx_cash,
    "fx_gavel": fx_gavel,
    "fx_scales_chain": fx_scales_chain,
    "fx_scales": fx_scales,
    "fx_firework_launch": fx_firework_launch,
    "fx_firework_1": lambda: firework(271, (1046.5, 1318.5, 1568.0)),
    "fx_firework_2": lambda: firework(275, (1318.5, 1568.0, 2093.0), 1.12),
    "fx_firework_3": lambda: firework(279, (1568.0, 2093.0, 2637.0), 0.9),
    "status_break": status_break,
    "fx_zap": fx_zap,
    "fx_poof": fx_poof,
    "fx_conjure": fx_conjure,
    "fx_shimmer": fx_shimmer,
    "fx_sniper_aim": fx_sniper_aim,
    "fx_serenade": fx_serenade,
    "fx_serenade_2": fx_serenade_2,
    "fx_serenade_3": fx_serenade_3,
    "fx_serenade_4": fx_serenade_4,
    "fx_serenade_5": fx_serenade_5,
    "fx_doll_hit": fx_doll_hit,
    "chalk": chalk,
    "fx_sniper": fx_sniper,
    "fx_shutter": fx_shutter,
    "fx_hush": fx_hush,
    "fx_tin": fx_tin,
    "fx_scribble": fx_scribble,
    "fx_hex": fx_hex,
    "fx_mask": fx_mask,
    "fx_chips": fx_chips,
    "fx_coin_flip": fx_coin_flip,
    "fx_dig": fx_dig,
    "fx_bell": fx_bell,
    "fx_pour": fx_pour,
    "fx_whistle": fx_whistle,
    "fx_glint": fx_glint,
    "fx_lasso_spin": fx_lasso_spin,
    "fx_lasso_miss": fx_lasso_miss,
    "fx_lasso": fx_lasso,
    "fx_wave": fx_wave,
    "fx_fuse": fx_fuse,
    "fx_boom": fx_boom,
    "item_get": item_get,
    "item_use": item_use,
    "item_silencer": item_silencer,
    "item_potion": item_potion,
    "item_mirror": item_mirror,
    "item_shield": item_shield,
    "item_death": item_death,
    "item_roulette": item_roulette,
    "item_roulette_tick": item_roulette_tick,
    "item_roulette_cock": item_roulette_cock,
    "item_roulette_shot": item_roulette_shot,
    "item_soul_swap": item_soul_swap,
}
PEAK = 0.7
# Sounds that sit lower in the mix than the rest.
PEAKS = {
    "truth": 0.42, "lie": 0.42, "coin_1": 0.38, "coin_2": 0.38, "coin_3": 0.38, "item_roulette": 0.5,
    "fx_hush": 0.4, "fx_shutter": 0.5, "fx_scribble": 0.5, "fx_tin": 0.5, "fx_shimmer": 0.5, "fx_lute": 0.55,
    "fx_lute_flourish": 0.55, "fx_cash": 0.55, "fx_poof": 0.6, "chalk": 0.28, "fx_serenade": 0.8, "fx_serenade_2": 0.8, "fx_serenade_3": 0.8, "fx_serenade_4": 0.8, "fx_serenade_5": 0.8, "fx_doll_hit": 0.6, "fx_sniper_aim": 0.3, "fx_sniper": 0.95, "fx_hex": 0.75,
    "item_death": 0.9,
    "fx_mask": 0.5, "fx_chips": 0.45, "fx_coin_flip": 0.45, "fx_dig": 0.6, "fx_bell": 0.6, "fx_pour": 0.5,
    "fx_whistle": 0.4, "fx_glint": 0.45, "fx_lasso_spin": 0.45, "fx_lasso": 0.7, "fx_lasso_miss": 0.6, "fx_conjure": 0.55, "fx_wave": 0.75, "fx_fuse": 0.45, "fx_boom": 0.95,
    "fx_scales_chain": 0.4, "fx_scales": 0.9,
    "fx_firework_launch": 0.45, "fx_firework_1": 0.88, "fx_firework_2": 0.88, "fx_firework_3": 0.88, "status_break": 0.4, "fx_zap": 0.55,
    "item_roulette_tick": 0.6, "item_roulette_cock": 0.8, "item_roulette_shot": 0.97,
    "ui_lock": 0.55, "ui_unlock": 0.5, "ui_deal": 0.5, "ui_flip": 0.45,
    "ui_gather": 0.5,
}


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
