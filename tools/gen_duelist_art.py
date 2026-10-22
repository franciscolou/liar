"""Paints the Duelist (Vittorio "Steel" Bellandi) in pixel art, cell by cell:
`python3 tools/gen_duelist_art.py --force`, then `python3 tools/gen_proto_cards.py Duelist`.

It was the stand-in for the painting: it never paints over a portrait that is
already there unless told to (--force).

Needs Pillow. Drawn like the Painter (tools/gen_painter_art.py, whose brushes
are copied here): a grid of W x H cells, each blown up to SCALE x SCALE pixels
for assets/cards/portraits/Duelist.png, a whole multiple of the card's 55:100.
Rounded things are shaded per cell from a light up and to the left, with an
ordered dither between the tones.
"""
import math
import os
import sys
from PIL import Image

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "cards", "portraits", "Duelist.png")

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


OUTLINE = hexc("140c10")
SKIN = [hexc(c) for c in ("6e3e2c", "9a5c42", "c4835e", "deaa84", "f0caa6")]
HAIR = [hexc(c) for c in ("120c0c", "211616", "33231f", "4a332b")]
HAT = [hexc(c) for c in ("0e0a10", "1c1520", "2c2232", "3e3246")]
PLUME = [hexc(c) for c in ("5c0e12", "8e1a1e", "c02a26", "e85a46", "f8a08a")]
COAT = [hexc(c) for c in ("1a0c12", "2e141c", "4a1e2a", "6a2c3a", "8a3e4c")]
LACE = [hexc(c) for c in ("8a8478", "bdb6a6", "e2dccc", "faf6ec")]
BRASS = [hexc(c) for c in ("5a3c10", "8e6420", "c8962e", "f2d488")]
STEEL = [hexc(c) for c in ("4a5262", "6c7686", "9aa4b4", "c8d0dc", "eef3fa")]
LEATHER = [hexc(c) for c in ("2a1208", "4a2412", "6e3a1e")]
SASH = [hexc(c) for c in ("4a0a0e", "7a1418", "a8241e", "d04a36")]

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
    # A fencing hall at night: a warm glow behind the head, falling off in
    # dithered steps into a deep wine-dark wall.
    ramp = [hexc(c) for c in ("0c0709", "150b0f", "201015", "2e171d", "3e2026", "512b2f")]
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 50) / 64.0, (y - 70) / 84.0)
            img[y][x] = tone(ramp, 1.0 - d, x, y)
    # Wainscot panels low on the wall.
    panel = [hexc("1a0d0f"), hexc("26141a"), hexc("341c22")]
    for y in range(150, 200):
        for x in range(W):
            if y == 150:
                img[y][x] = panel[2]
            elif y == 151:
                img[y][x] = panel[0]
            elif x % 26 in (0, 1):
                img[y][x] = panel[0] if x % 26 == 0 else panel[2]
    # Two sabres crossed on the wall behind, dim in the room's light.
    for (x1, y1, x2, y2) in ((70, 6, 106, 60), (106, 6, 70, 60)):
        steps = 80
        for i in range(steps + 1):
            t = i / steps
            x = int(x1 + (x2 - x1) * t)
            y = int(y1 + (y2 - y1) * t)
            img[y][x] = hexc("6a5c62")
            if 0 <= y + 1 < H:
                img[y + 1][x] = hexc("3a3036")
    for (x, y) in ((100, 50), (76, 50)):
        for dx in range(-4, 5):
            img[y][x + dx] = hexc("7a5a2a")
        for dy in range(1, 6):
            img[y + dy][x] = hexc("3a1c10")


# --- him ----------------------------------------------------------------------

def coat():
    # A burgundy doublet, fitted, with a row of brass buttons.
    pts = [(8, 200), (10, 152), (20, 126), (40, 114), (70, 114), (90, 126), (100, 152), (102, 200)]
    poly(pts, COAT, part=2, shade=lambda x, y: 0.78 - (x - 14) / 105.0 - max(0, y - 170) / 140.0)
    # The front edge and the buttons down it.
    for y in range(120, 200):
        put(56, y, COAT[0], 2)
        put(57, y, COAT[3], 2)
    for y in range(132, 196, 10):
        blob(60, y, 1.8, 1.8, BRASS, part=2, bias=0.15)
    # Folds.
    for (x1, y1, x2, y2) in ((30, 140, 26, 198), (80, 140, 86, 198), (44, 150, 42, 198)):
        line(x1, y1, x2, y2, COAT[1], part=2)
        line(x1 + 1, y1, x2 + 1, y2, COAT[3], part=2)
    # A red sash over the shoulder, from his right to his left hip.
    poly([(70, 116), (82, 120), (34, 200), (20, 200)], SASH, part=3,
         shade=lambda x, y: 0.7 - (x - 20) / 120.0 + (0.12 if (x + y) % 9 < 2 else 0.0))
    seams(3, 2)


def collar():
    # A falling lace collar over the shoulders.
    poly([(34, 108), (76, 108), (86, 122), (60, 132), (55, 128), (50, 132), (24, 122)], LACE, part=4,
         shade=lambda x, y: 0.82 - (x - 26) / 90.0 - (0.2 if (x + 2 * y) % 7 == 0 else 0.0))
    # Its scalloped edge.
    for x in range(25, 86):
        y = 123 + (1 if x % 4 in (1, 2) else 0) + (5 if 48 < x < 62 else 0) - abs(x - 55) // 14
        put(x, y, LACE[0], 4)
    seams(4, 2)


def neck():
    poly([(47, 100), (63, 100), (64, 112), (46, 112)], SKIN, part=5,
         shade=lambda x, y: 0.5 - (x - 46) / 60.0 - (0.3 if y < 108 else 0.0))


def head():
    blob(55, 80, 18, 23, SKIN, part=6, bias=0.06)
    blob(37, 82, 3, 5.5, SKIN, part=6, bias=-0.1)
    # Long dark hair down to the collar, on both sides of the face.
    poly([(34, 62), (40, 60), (42, 90), (40, 118), (30, 116), (32, 90)], HAIR, part=7,
         shade=lambda x, y: 0.55 - (y - 60) / 160.0)
    poly([(70, 60), (77, 64), (78, 92), (80, 118), (70, 116), (70, 90)], HAIR, part=7,
         shade=lambda x, y: 0.32 - (y - 60) / 200.0)
    for (x1, y1, x2, y2) in ((36, 70, 34, 112), (74, 70, 76, 112), (38, 80, 37, 114)):
        line(x1, y1, x2, y2, HAIR[3], part=7)
    # Brows: straight and low, one cut through by the scar.
    for i in range(9):
        put(43 + i, 72 + (1 if i > 6 else 0), HAIR[0], 6)
        put(43 + i, 73 + (1 if i > 6 else 0), HAIR[1], 6)
    for i in range(9):
        if i in (3, 4):
            continue
        put(59 + i, 72 + (1 if i < 2 else 0), HAIR[0], 6)
        put(59 + i, 73 + (1 if i < 2 else 0), HAIR[1], 6)
    # Eyes: narrowed, looking straight at you.
    for x0 in (44, 60):
        for i in range(6):
            put(x0 + i, 77, OUTLINE, 6)
        for i in range(1, 5):
            put(x0 + i, 78, LACE[2], 6)
        put(x0 + 2, 78, hexc("2a1a10"), 6)
        put(x0 + 3, 78, hexc("120a06"), 6)
        for i in range(6):
            put(x0 + i, 79, SKIN[1], 6)
    # The scar, from the brow down across the cheek.
    for i in range(14):
        put(62 + i // 3, 70 + i, hexc("d88a7a") if i % 2 else hexc("b06a5c"), 6)
    # Nose: straight, lit on its left.
    for y in range(79, 91):
        put(56, y, SKIN[1], 6)
        put(54, y, SKIN[4] if y < 87 else SKIN[3], 6)
    put(53, 90, SKIN[1], 6)
    put(57, 91, SKIN[0], 6)
    # A thin moustache and the pointed beard under the lip.
    for i in range(-8, 9):
        put(55 + i, 94 + abs(i) // 5, HAIR[0], 6)
        if abs(i) < 6:
            put(55 + i, 93, HAIR[2], 6)
    for i in range(-4, 5):
        put(55 + i, 98, hexc("6a2a24"), 6)
    poly([(51, 100), (59, 100), (56, 108), (55, 110), (54, 108)], HAIR, part=6, shade=lambda x, y: 0.4)
    # The jaw in shade where it turns under.
    for x in range(40, 71):
        for y in range(H - 1, 0, -1):
            if mask[y][x] == 6:
                img[y][x] = SKIN[1]
                break
    seams(6, 5)


def hat():
    # A wide brim tilted down over one eye, the crown pinched.
    blob(54, 61, 42, 6, HAT, part=8, rot=-0.1, bias=0.1)
    blob(56, 50, 15, 10, HAT, part=8, rot=-0.1, bias=0.15)
    # The crown pinched in at the top.
    for x in range(52, 61):
        put(x, 41 + abs(x - 56) // 3, HAT[0], 8)
    # The hatband, and the plume sweeping back off it.
    for x in range(41, 72):
        put(x, 55 + (x - 41) // 14, SASH[2], 8)
        put(x, 56 + (x - 41) // 14, SASH[1], 8)
    blob(46, 54, 2.2, 2.2, BRASS, part=8, bias=0.2)
    for i in range(46):
        t = i / 45.0
        cx = 44 - 30 * t + 4 * math.sin(t * 3.0)
        cy = 50 - 26 * t + 16 * t * t
        r = 4.5 * (1.0 - t) + 1.2
        blob(cx, cy, r, r * 0.7, PLUME, part=9, rot=0.6 - t, bias=0.1 - 0.3 * t)
    # The barbs of the plume.
    for i in range(0, 44, 3):
        t = i / 45.0
        cx = 44 - 30 * t + 4 * math.sin(t * 3.0)
        cy = 50 - 26 * t + 16 * t * t
        line(cx, cy, cx - 3, cy + 5 * (1.0 - t), PLUME[1], part=9)
    seams(8, 6)


def sword_arm():
    # His right arm up across the body, the rapier held in salute: the hilt
    # by his left shoulder, the blade going up past his face to the corner.
    poly([(80, 200), (82, 168), (76, 148), (60, 140), (54, 150), (68, 162), (72, 200)], COAT, part=10,
         shade=lambda x, y: 0.6 - (x - 54) / 70.0)
    seams(10, 2)
    # The gauntlet round the grip.
    blob(53, 140, 7, 6, LEATHER, part=11, bias=0.25)
    for (x, y) in ((48, 138), (50, 137), (52, 136), (54, 136)):
        put(x, y, LEATHER[0], 11)
    # The cup guard and the quillons.
    blob(50, 132, 6, 3.5, BRASS, part=12, rot=-0.5, bias=0.1)
    line(42, 136, 58, 126, BRASS[2], width=2, part=12)
    line(42, 137, 58, 127, BRASS[0], width=1, part=12)
    blob(41, 137, 1.6, 1.6, BRASS, part=12, bias=0.3)
    blob(59, 126, 1.6, 1.6, BRASS, part=12, bias=0.3)
    # The pommel below the hand.
    blob(57, 149, 2.4, 2.4, BRASS, part=12, bias=0.2)
    # The blade, from the guard to the top right, a long thin taper.
    x0, y0, x1, y1 = 48, 129, 100, 4
    steps = 200
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        width = 2 if t < 0.85 else 1
        put(int(x), int(y), STEEL[3], 13)
        if width > 1:
            put(int(x) + 1, int(y), STEEL[1], 13)
            put(int(x) - 1, int(y), STEEL[4] if t < 0.7 else STEEL[3], 13)
    # The light running down it.
    for i in range(40, 70):
        t = i / steps
        put(int(x0 + (x1 - x0) * t) - 1, int(y0 + (y1 - y0) * t), (255, 255, 255), 13)
    seams(11, 12)


def main():
    if os.path.exists(OUT) and "--force" not in sys.argv:
        print("portraits/Duelist.png is there already: --force to paint over it")
        return
    background()
    coat()
    collar()
    neck()
    head()
    hat()
    sword_arm()
    outline()
    image = Image.new("RGB", (W, H))
    pixels = image.load()
    for y in range(H):
        for x in range(W):
            pixels[x, y] = img[y][x] if img[y][x] is not None else OUTLINE
    image = image.resize((W * SCALE, H * SCALE), Image.NEAREST)
    image.save(OUT, optimize=True)
    print("portraits/Duelist.png: %dx%d" % image.size)


if __name__ == "__main__":
    main()
