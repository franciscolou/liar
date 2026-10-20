"""Paints the Painter (Monsieur Vermeil) in pixel art, cell by cell:
`python3 tools/gen_painter_art.py`, then `python3 tools/gen_proto_cards.py Painter`.

Needs Pillow. The picture is worked out on a grid of W x H cells and each
cell is blown up to SCALE x SCALE pixels for assets/cards/portraits/Painter.png
(a whole multiple of the card's 55:100, so the card is cut from it cleanly).
Every rounded thing is shaded per cell from a light up and to the left, with
an ordered dither between the tones, as the other cards' paintings look.
"""
import math
import os
from PIL import Image

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "cards", "portraits", "Painter.png")

W, H = 110, 200
SCALE = 8
LIGHT = (-0.55, -0.75, 0.6)

BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


OUTLINE = hexc("1b0f14")
SKIN = [hexc(c) for c in ("7e4a34", "a9684a", "cf8f68", "e6b08a", "f4d0ac")]
SMOCK = [hexc(c) for c in ("6f6656", "9b8f76", "c4b796", "e2d6b6", "f6eedb")]
BERET = [hexc(c) for c in ("1a0d16", "2c1626", "44223a", "62344f")]
HAIR = [hexc(c) for c in ("1c1009", "2e1b10", "45291a")]
WOOD = [hexc(c) for c in ("5a3418", "80502a", "a8743c", "c99858", "e2b878")]
SCARF = [hexc(c) for c in ("5c1218", "8a1e24", "b8322e", "dc5a48")]
BRUSH = [hexc(c) for c in ("3a1a10", "6a2e1c", "94482a")]
FERRULE = [hexc(c) for c in ("6c6c74", "a8a8b0", "e0e0e6")]
BLUE = [hexc(c) for c in ("1f3f86", "2f62b8", "4f8fe0", "8fc0f6")]
PINK = [hexc(c) for c in ("8a2a5e", "c04a8a", "e877b8", "f8b6dc")]
YELLOW = [hexc(c) for c in ("8a6a10", "c89a1c", "f2cf3c", "fff0a0")]
WHITE = [hexc(c) for c in ("9a9488", "cfc8b8", "f2ece0", "ffffff")]
RED = [hexc(c) for c in ("6a1210", "a8241c", "d8402e", "f2806a")]
GREEN = [hexc(c) for c in ("1e4a2a", "2f7040", "4f9a5a", "8ccc88")]

img = [[None] * W for _ in range(H)]
mask = [[0] * W for _ in range(H)]  # 0 background, else the id of the part


def put(x, y, color, part=1):
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = color
        mask[y][x] = part


def tone(ramp, level, x, y):
    """`level` 0..1 picked from `ramp`, dithered between two neighbours."""
    level = max(0.0, min(0.999, level))
    f = level * (len(ramp) - 1)
    i = int(f)
    frac = f - i
    # Flat bands with a narrow dithered seam between them, not a grain all over.
    if frac > 0.68:
        i += 1
    elif frac > 0.32 and (frac - 0.32) / 0.36 * 16 > BAYER[y % 4][x % 4] + 0.5:
        i += 1
    return ramp[min(i, len(ramp) - 1)]


def lit(nx, ny):
    nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
    lx, ly, lz = LIGHT
    n = math.sqrt(lx * lx + ly * ly + lz * lz)
    return max(0.0, (nx * lx + ny * ly + nz * lz) / n)


def blob(cx, cy, rx, ry, ramp, part=1, bias=0.0, rot=0.0, clip=None):
    """A filled ellipse shaded as a dome."""
    c, s = math.cos(rot), math.sin(rot)
    reach = int(max(rx, ry)) + 2
    for y in range(int(cy) - reach, int(cy) + reach + 1):
        for x in range(int(cx) - reach, int(cx) + reach + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = (dx * c + dy * s) / rx
            v = (-dx * s + dy * c) / ry
            if u * u + v * v <= 1.0 and (clip is None or clip(x, y)):
                put(x, y, tone(ramp, lit(u * 0.9, v * 0.9) * 0.95 + bias, x, y), part)


def poly(points, ramp, part=1, shade=None):
    """A filled polygon; `shade(x, y)` gives each cell's level (0..1)."""
    ys = [p[1] for p in points]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        yc = y + 0.5
        xs = []
        n = len(points)
        for i in range(n):
            x1, y1 = points[i]
            x2, y2 = points[(i + 1) % n]
            if (y1 <= yc < y2) or (y2 <= yc < y1):
                xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for a, b in zip(xs[::2], xs[1::2]):
            for x in range(int(round(a)), int(round(b))):
                level = shade(x, y) if shade else 0.6
                put(x, y, tone(ramp, level, x, y), part)


def line(x1, y1, x2, y2, color, width=1, part=1):
    steps = int(max(abs(x2 - x1), abs(y2 - y1)) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        x = x1 + (x2 - x1) * t
        y = y1 + (y2 - y1) * t
        for ox in range(width):
            for oy in range(width):
                put(int(x) + ox - width // 2, int(y) + oy - width // 2, color, part)


def outline(parts=None):
    """Dark cells round every part (or the ones listed), on the outside."""
    marks = []
    for y in range(H):
        for x in range(W):
            if mask[y][x] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and mask[ny][nx] != 0 and (parts is None or mask[ny][nx] in parts):
                    marks.append((x, y))
                    break
    for x, y in marks:
        img[y][x] = OUTLINE
        mask[y][x] = 99


def seams(a, b):
    """A dark line where part `a` meets part `b`, on `a`'s side."""
    marks = []
    for y in range(H):
        for x in range(W):
            if mask[y][x] != a:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and mask[ny][nx] == b:
                    marks.append((x, y))
                    break
    for x, y in marks:
        img[y][x] = OUTLINE


# --- the room ---------------------------------------------------------------

def background():
    # A dim studio: a warm glow behind the head, falling off in dithered steps.
    ramp = [hexc(c) for c in ("0e0910", "171018", "211622", "2e1d2c", "3c2737", "4d3343")]
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 58) / 62.0, (y - 74) / 80.0)
            img[y][x] = tone(ramp, 1.0 - d, x, y)
    # Old strokes on the wall: the colours of the trade.
    for (x, y, length, ramp_, slope) in ((8, 22, 16, BLUE, 0.35), (86, 30, 14, PINK, -0.3),
                                         (92, 58, 12, YELLOW, 0.4), (4, 70, 10, PINK, -0.2),
                                         (96, 92, 9, BLUE, 0.25)):
        for i in range(length):
            for w in range(3):
                cx, cy = x + i, int(y + i * slope) + w
                if 0 <= cx < W and 0 <= cy < H and (i + w) % 5 != 0:
                    img[cy][cx] = tone(ramp_[:2] + [hexc("2a1c28")], 0.35 + 0.1 * w, cx, cy)
    # His easel behind his shoulder, and on it a canvas in his three colours.
    leg = [hexc("24160f"), hexc("3a2418"), hexc("553521")]
    for y in range(10, 200):
        for x, k in ((88, 0), (89, 1), (90, 2), (91, 1)):
            img[y][x + (y - 10) // 40] = leg[k]
    frame = [hexc("3a2418"), hexc("6a4428"), hexc("8a5c34")]
    for y in range(14, 98):
        for x in range(80, 110):
            edge = x in (80, 81) or y in (14, 15, 96, 97)
            if edge:
                img[y][x] = frame[2] if (x == 80 or y == 14) else frame[1]
                continue
            # Three broad strokes, wet and a little dim in the room's light.
            band = (y - 16) + (x - 82) * 0.6
            ramp_ = BLUE if band < 26 else (PINK if band < 52 else YELLOW)
            img[y][x] = tone([hexc("1a1218")] + ramp_[:3], 0.42 + 0.18 * math.sin((x + y * 0.4) * 0.35), x, y)
    for x in range(78, 110):
        img[98][x] = frame[0]
        img[99][x] = frame[1]
        img[100][x] = frame[0]


# --- him ----------------------------------------------------------------------

def smock():
    # Shoulders and chest: a painter's smock, loose and stained.
    pts = [(10, 200), (12, 150), (20, 128), (40, 116), (70, 116), (90, 128), (98, 150), (100, 200)]
    poly(pts, SMOCK, part=2, shade=lambda x, y: 0.82 - (x - 18) / 110.0 - max(0, y - 170) / 120.0)
    # Folds.
    for (x1, y1, x2, y2) in ((34, 140, 30, 198), (58, 150, 60, 198), (78, 138, 84, 198), (46, 128, 42, 150)):
        line(x1, y1, x2, y2, SMOCK[1], part=2)
        line(x1 + 1, y1, x2 + 1, y2, SMOCK[3], part=2)
    # Paint on it, flicked and smeared.
    spots = [(30, 160, BLUE), (36, 166, BLUE), (64, 172, PINK), (70, 168, PINK), (52, 184, YELLOW),
             (80, 150, YELLOW), (26, 186, PINK), (86, 178, BLUE), (44, 172, YELLOW), (74, 190, BLUE)]
    for (x, y, ramp) in spots:
        blob(x, y, 2.2, 1.6, ramp, part=2)
    for (x, y, ramp) in ((40, 156, PINK), (66, 182, YELLOW), (82, 164, BLUE)):
        put(x, y, ramp[2], 2)
        put(x + 1, y + 1, ramp[1], 2)


def neck_and_scarf():
    poly([(46, 98), (64, 98), (66, 120), (44, 120)], SKIN, part=3,
         shade=lambda x, y: 0.55 - (x - 44) / 60.0 - (0.3 if y < 108 else 0.0))
    # The red neckerchief, knotted at the throat.
    poly([(36, 116), (74, 116), (70, 124), (40, 124)], SCARF, part=4, shade=lambda x, y: 0.75 - (x - 36) / 70.0)
    poly([(48, 122), (62, 122), (58, 146), (55, 150), (52, 146)], SCARF, part=4, shade=lambda x, y: 0.6 - (x - 48) / 40.0)
    blob(55, 122, 5, 4, SCARF, part=4, bias=0.1)
    seams(4, 2)


def head():
    blob(55, 78, 20, 24, SKIN, part=5, bias=0.08)
    # Ears.
    blob(35, 80, 3.5, 6, SKIN, part=5, bias=-0.1)
    blob(75, 80, 3.5, 6, SKIN, part=5, bias=-0.15)
    # Dark hair under the beret, over the ears.
    poly([(34, 60), (40, 58), (40, 76), (36, 74)], HAIR, part=6, shade=lambda x, y: 0.5)
    poly([(70, 58), (76, 60), (75, 74), (70, 76)], HAIR, part=6, shade=lambda x, y: 0.3)
    # Brows: arched, one a little higher, the look of a man who knows the price.
    for i in range(9):
        put(42 + i, 71 - (1 if 2 < i < 7 else 0), HAIR[0], 5)
        put(42 + i, 72 - (1 if 2 < i < 7 else 0), HAIR[1], 5)
    for i in range(9):
        put(59 + i, 70 - (1 if 1 < i < 6 else 0) - (1 if i == 3 else 0), HAIR[0], 5)
        put(59 + i, 71 - (1 if 1 < i < 6 else 0) - (1 if i == 3 else 0), HAIR[1], 5)
    # Eyes, half shut, sly.
    for (x0, look) in ((44, 2), (61, 2)):
        for i in range(6):
            put(x0 + i, 76, OUTLINE, 5)
        for i in range(1, 5):
            put(x0 + i, 77, WHITE[2], 5)
        put(x0 + look, 77, hexc("3a2412"), 5)
        put(x0 + look + 1, 77, hexc("1a0f08"), 5)
        for i in range(6):
            put(x0 + i, 78, SKIN[1], 5)
    # Nose: a long one, lit on its left.
    for y in range(78, 90):
        put(56, y, SKIN[1], 5)
        put(54, y, SKIN[4] if y < 86 else SKIN[3], 5)
    put(53, 89, SKIN[1], 5)
    put(57, 90, SKIN[0], 5)
    put(54, 90, SKIN[1], 5)
    # Cheeks warm with wine.
    for (x, y) in ((44, 84), (45, 85), (46, 84), (64, 84), (65, 85), (66, 84)):
        put(x, y, hexc("d97a6a"), 5)
    # The moustache, waxed into two curls.
    for i in range(-11, 12):
        x = 55 + i
        y = 92 + int(abs(i) * 0.12)
        put(x, y, HAIR[1], 5)
        put(x, y + 1, HAIR[0], 5)
        if abs(i) < 8:
            put(x, y - 1, HAIR[2] if i < 0 else HAIR[1], 5)
    for side in (-1, 1):
        for (ox, oy) in ((12, 91), (13, 90), (14, 89), (14, 88), (13, 87), (12, 87), (11, 88)):
            put(55 + side * ox, oy, HAIR[0], 5)
    # A thin smile and the tuft under the lip.
    for i in range(-5, 6):
        put(55 + i, 97 - (1 if abs(i) > 3 else 0), hexc("6a2a20"), 5)
    for i in range(-2, 3):
        put(55 + i, 98, SKIN[3], 5)
    for (x, y) in ((54, 100), (55, 100), (56, 100), (55, 101), (55, 102)):
        put(x, y, HAIR[1], 5)
    # The jaw, shadowed where it turns under.
    for x in range(40, 71):
        for y in range(H - 1, 0, -1):
            if mask[y][x] == 5:
                img[y][x] = SKIN[1]
                img[y - 1][x] = tone(SKIN, 0.3, x, y - 1) if abs(x - 55) < 12 else img[y - 1][x]
                break
    seams(5, 3)


def beret():
    # Pulled down to one side, with its little stalk.
    blob(51, 56, 27, 10, BERET, part=7, rot=-0.12, bias=0.05)
    blob(48, 52, 22, 8, BERET, part=7, rot=-0.12, bias=0.2)
    poly([(50, 42), (54, 42), (53, 47), (51, 47)], BERET, part=7, shade=lambda x, y: 0.5)
    # A stripe of paint where he wiped a brush on it.
    for i in range(10):
        put(60 + i, 53 + i // 4, PINK[2], 7)
        put(60 + i, 54 + i // 4, PINK[1], 7)
    seams(7, 5)


def palette_arm():
    # His left arm comes up from below, the palette on his thumb.
    poly([(8, 200), (6, 170), (14, 152), (26, 150), (30, 168), (28, 200)], SMOCK, part=8,
         shade=lambda x, y: 0.7 - (x - 6) / 60.0)
    # The palette: a kidney of wood, the thumb through its hole.
    blob(30, 148, 28, 17, WOOD, part=9, rot=-0.18, bias=0.05)
    blob(30, 148, 28, 17, WOOD, part=9, rot=-0.18, bias=0.05,
         clip=lambda x, y: (x - 46) ** 2 / 64.0 + (y - 156) ** 2 / 25.0 > 1.0)
    for y in range(H):
        for x in range(W):
            if mask[y][x] == 9 and (x - 46) ** 2 / 64.0 + (y - 156) ** 2 / 25.0 <= 1.0:
                img[y][x] = None
                mask[y][x] = 0
    # Restore what shows through the notch.
    for y in range(150, 162):
        for x in range(38, 55):
            if mask[y][x] == 0:
                img[y][x] = tone(SMOCK, 0.45, x, y)
                mask[y][x] = 2
    # Grain.
    for (x1, y1, x2, y2) in ((10, 146, 24, 138), (14, 154, 34, 146), (22, 160, 40, 152)):
        line(x1, y1, x2, y2, WOOD[1], part=9)
    # The thumb, coming up through the hole.
    blob(26, 156, 3.5, 4.5, SKIN, part=10, bias=0.05)
    # Blobs of paint, mixed and smeared.
    for (x, y, r, ramp) in ((12, 145, 4.0, BLUE), (21, 138, 4.2, PINK), (33, 136, 4.0, YELLOW),
                            (44, 140, 3.4, WHITE), (50, 147, 3.0, RED), (14, 155, 3.2, GREEN)):
        blob(x, y, r, r * 0.8, ramp, part=11, bias=0.15)
    for (x, y, ramp) in ((27, 146, PINK), (30, 147, BLUE), (33, 146, YELLOW)):
        for i in range(4):
            put(x + i, y + (i % 2), ramp[1], 11)
    seams(9, 2)


def brush_arm():
    # His right hand holds the brush up, as if to measure you with it.
    poly([(78, 200), (80, 164), (86, 140), (96, 136), (104, 150), (102, 200)], SMOCK, part=12,
         shade=lambda x, y: 0.62 - (x - 78) / 70.0)
    seams(12, 2)
    blob(91, 132, 7, 8, SKIN, part=13, bias=0.02)
    # Knuckles.
    for (x, y) in ((86, 128), (88, 127), (90, 126), (92, 126)):
        put(x, y, SKIN[1], 13)
    # The brush: handle, ferrule and a tip loaded with pink.
    line(96, 150, 84, 104, BRUSH[1], width=2, part=14)
    line(97, 150, 85, 104, BRUSH[2], width=1, part=14)
    line(84, 104, 82, 96, FERRULE[1], width=2, part=14)
    put(83, 98, FERRULE[2], 14)
    put(82, 100, FERRULE[2], 14)
    blob(80.5, 91, 2.6, 4.2, PINK, part=14, bias=0.1, rot=0.25)
    put(80, 86, PINK[3], 14)
    # Fingers round the handle, over it.
    for (x, y) in ((87, 134), (88, 135), (89, 136), (90, 137), (91, 137)):
        put(x, y, SKIN[2], 13)
    for i in range(4):
        put(85 + i, 131 + i, SKIN[0], 13)
    seams(13, 14)


def drips():
    # A few drops of paint that ran off the brush onto the smock.
    for (x, y, ramp) in ((88, 160, PINK), (92, 170, PINK)):
        for i in range(4):
            put(x, y + i, ramp[2 if i < 3 else 1], 2)


def main():
    background()
    smock()
    neck_and_scarf()
    head()
    beret()
    brush_arm()
    palette_arm()
    drips()
    outline()
    image = Image.new("RGB", (W, H))
    pixels = image.load()
    for y in range(H):
        for x in range(W):
            pixels[x, y] = img[y][x] if img[y][x] is not None else OUTLINE
    image = image.resize((W * SCALE, H * SCALE), Image.NEAREST)
    image.save(OUT, optimize=True)
    print("portraits/Painter.png: %dx%d" % image.size)


if __name__ == "__main__":
    main()
