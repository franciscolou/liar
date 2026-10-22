"""Paints the Necromancer (Ezekiel Ashgrave) in pixel art, cell by cell:
`python3 tools/gen_necromancer_art.py`, then `python3 tools/gen_proto_cards.py Necromancer`.

Needs Pillow. The picture is worked out on a grid of W x H cells and each
cell is blown up to SCALE x SCALE pixels for assets/cards/portraits/Necromancer.png
(a whole multiple of the card's 55:100, so the card is cut from it cleanly).
It is a stand-in until a painting is made. Won't paint over a portrait that
is already there without --force.

He stands in a graveyard at night, deep in his hood, a skull held up in his
left hand with a green fire in it: that fire is the light of the picture, so
everything near it is lit from below and to the left, and whatever faces
away from it falls into the dark of the night.
"""
import math
import os
import sys
from PIL import Image

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "cards", "portraits", "Necromancer.png")

W, H = 110, 200
SCALE = 8
# The night, from above and to the left (the moon), and the fire, low left.
MOON = (-0.5, -0.8, 0.5)
FIRE_AT = (30, 118)

BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


OUTLINE = hexc("07090a")
ROBE = [hexc(c) for c in ("0b100f", "131b19", "1c2825", "273834", "354a43")]
HOOD_IN = [hexc(c) for c in ("040605", "080c0b", "0e1412")]
SKIN = [hexc(c) for c in ("2a3430", "485a50", "6f8a78", "9fc0a4", "cfeed0")]
BONE = [hexc(c) for c in ("4a4636", "7a7458", "aea684", "d8d0b0", "f4efdc")]
FLAME = [hexc(c) for c in ("0f4a2a", "1f8a4a", "3fd070", "8cff9e", "e6ffe8")]
TRIM = [hexc(c) for c in ("3a3a2c", "6a6a50", "9a9878", "c8c4a0")]
WOOD = [hexc(c) for c in ("140e0a", "2a1c12", "42301e", "5a4428")]
STONE = [hexc(c) for c in ("0c1214", "151d20", "1f2a2e", "2b383c", "3a4a4e")]
FOG = hexc("26403a")
EYE = hexc("b6ffbf")

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


def lit(nx, ny, light=MOON):
    nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
    lx, ly, lz = light
    n = math.sqrt(lx * lx + ly * ly + lz * lz)
    return max(0.0, (nx * lx + ny * ly + nz * lz) / n)


def fire_light(x, y, reach=70.0):
    """How much of the green fire reaches cell (x, y): 0 to 1."""
    d = math.hypot(x - FIRE_AT[0], (y - FIRE_AT[1]) * 0.9)
    return max(0.0, 1.0 - d / reach) ** 1.6


def blob(cx, cy, rx, ry, ramp, part=1, bias=0.0, rot=0.0, clip=None, light=MOON, glow=0.0):
    """A filled ellipse shaded as a dome; `glow` adds the fire's light."""
    c, s = math.cos(rot), math.sin(rot)
    reach = int(max(rx, ry)) + 2
    for y in range(int(cy) - reach, int(cy) + reach + 1):
        for x in range(int(cx) - reach, int(cx) + reach + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = (dx * c + dy * s) / rx
            v = (-dx * s + dy * c) / ry
            if u * u + v * v <= 1.0 and (clip is None or clip(x, y)):
                level = lit(u * 0.9, v * 0.9, light) * 0.95 + bias + glow * fire_light(x, y)
                put(x, y, tone(ramp, level, x, y), part)


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


def tint(color, toward, k):
    return tuple(int(a + (b - a) * k) for a, b in zip(color, toward))


# --- the graveyard ------------------------------------------------------------

def background():
    # Night sky: near black at the top, a sick green haze low down where the
    # fire's light hangs in the fog.
    sky = [hexc(c) for c in ("05080a", "081012", "0c1818", "10221e", "163026", "1d3e2e")]
    for y in range(H):
        for x in range(W):
            haze = 0.25 + 0.55 * (y / H) ** 1.4 + 0.35 * fire_light(x, y, 110.0)
            img[y][x] = tone(sky, haze, x, y)
    # The moon, high on the right, behind a bar of cloud.
    moon = [hexc(c) for c in ("4a5a52", "7a8e80", "b4c8b4", "e2f0dc")]
    for y in range(4, 30):
        for x in range(72, 102):
            d = math.hypot(x - 88, y - 16)
            if d < 10.5:
                level = 0.95 - 0.04 * d - (0.25 if (x - 84) ** 2 + (y - 13) ** 2 < 5 else 0.0)
                img[y][x] = tone(moon, level, x, y)
            elif d < 15 and (x + y) % 3 == 0:
                img[y][x] = tint(img[y][x], moon[0], 0.35)
    for y in range(17, 21):
        for x in range(66, 108):
            if (x * 7 + y * 3) % 11 > 2:
                img[y][x] = tone([hexc("0a1214"), hexc("121c1e"), hexc("1a2628")], 0.3 + 0.12 * (y - 17), x, y)
    # A dead tree on the left, against the sky.
    bark = hexc("060908")
    line(8, 110, 12, 44, bark, width=3)
    line(11, 62, 2, 48, bark, width=2)
    line(12, 54, 24, 36, bark, width=2)
    line(20, 40, 22, 28, bark)
    line(22, 38, 30, 34, bark)
    line(5, 52, 0, 50, bark)
    line(11, 74, 22, 66, bark)
    # Tombstones, a crooked cross and the fog lying low between them.
    for (x0, y0, w, h, round_top) in ((74, 150, 14, 22, True), (94, 158, 12, 18, False), (2, 160, 12, 18, True)):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                top = y0 + (2.5 - math.sqrt(max(0.0, 6.25 - ((x - x0 - w / 2) / (w / 5.0)) ** 2)) if round_top else 0)
                if y >= top:
                    level = 0.55 - (x - x0) / (w * 2.2) + 0.25 * fire_light(x, y, 120.0)
                    put(x, y, tone(STONE, level, x, y), 30)
        for i in range(2, w - 3, 3):
            put(x0 + i, y0 + 7, STONE[0], 30)
    for (x, y) in ((100, 128), (101, 128)):
        pass
    line(100, 124, 100, 150, STONE[2], width=2, part=30)
    line(95, 131, 105, 129, STONE[2], width=2, part=30)
    for y in range(140, 200):
        for x in range(W):
            wave = math.sin(x * 0.18 + y * 0.05) * 3 + math.sin(x * 0.07 - y * 0.2) * 4
            if y > 168 + wave and mask[y][x] in (0, 30) and (x * 3 + y * 5) % 4 != 0:
                img[y][x] = tint(img[y][x], FOG, 0.45 + 0.2 * fire_light(x, y, 120.0))


# --- him ----------------------------------------------------------------------

def robe():
    # The long cloak, hanging from the hood to the foot of the picture.
    pts = [(14, 200), (16, 150), (24, 118), (36, 104), (74, 104), (86, 118), (94, 150), (98, 200)]
    poly(pts, ROBE, part=2, shade=lambda x, y: 0.45 - (x - 20) / 160.0 + 0.6 * fire_light(x, y))
    # Deep folds.
    for (x1, y1, x2, y2) in ((40, 120, 34, 198), (56, 130, 58, 198), (72, 122, 80, 198), (30, 150, 24, 198)):
        line(x1, y1, x2, y2, ROBE[0], part=2)
        line(x1 + 1, y1, x2 + 1, y2, ROBE[2], part=2)
    # The opening down the front, edged with bone-white thread and runes.
    for y in range(112, 200):
        x = 55 + int((y - 112) * 0.05)
        put(x, y, TRIM[0], 2)
        put(x - 1, y, tone(TRIM, 0.4 + 0.5 * fire_light(x, y), x, y), 2)
        put(x + 1, y, TRIM[0], 2)
        if y % 9 == 0:
            for (ox, oy) in ((-3, 0), (-3, 1), (-4, 2), (-2, 2), (-3, 3)):
                put(x + ox, y + oy, tone(TRIM, 0.5 + 0.4 * fire_light(x, y), x, y), 2)
    # A belt of bone beads.
    for i in range(-16, 17, 3):
        bx = 55 + i
        by = 150 + int(abs(i) * 0.15)
        blob(bx, by, 1.4, 1.2, BONE, part=3, bias=-0.1, glow=0.6)


def hood():
    # The hood: tall and peaked, falling to the shoulders.
    pts = [(28, 112), (30, 80), (36, 52), (46, 34), (56, 26), (66, 34), (76, 52), (82, 80), (84, 112), (70, 106), (42, 106)]
    poly(pts, ROBE, part=4, shade=lambda x, y: 0.62 - (x - 30) / 90.0 - (y - 26) / 300.0 + 0.55 * fire_light(x, y))
    # The rim of the hood, a turned-back edge catching what light there is.
    for y in range(40, 108):
        for x in range(30, 84):
            if mask[y][x] != 4:
                continue
            dx, dy = (x + 0.5 - 56) / 17.0, (y + 0.5 - 74) / 26.0
            d = dx * dx + dy * dy
            if 1.0 < d < 1.45:
                put(x, y, tone(ROBE, 0.7 - dx * 0.35 + 0.6 * fire_light(x, y), x, y), 4)
    # The dark inside of it.
    for y in range(44, 106):
        for x in range(36, 78):
            dx, dy = (x + 0.5 - 56) / 17.0, (y + 0.5 - 74) / 26.0
            if dx * dx + dy * dy <= 1.0:
                put(x, y, tone(HOOD_IN, 0.4 + 0.5 * fire_light(x, y), x, y), 5)
    # Seams of the cloth.
    line(56, 27, 56, 46, ROBE[0], part=4)


def face():
    # Gaunt and grey, lit from below by the fire: the brow and the hollows
    # of the eyes in shadow, the cheekbones and chin catching green.
    under = (-0.55, 0.75, 0.5)
    blob(56, 80, 11, 15, SKIN, part=6, bias=-0.28, light=under, glow=0.55)
    # Sunken cheeks.
    for (cx, side) in ((49, -1), (63, 1)):
        for y in range(82, 90):
            put(cx + side * (0 if y < 86 else 1), y, SKIN[0], 6)
    # The brow ridge throws its shadow over the eyes...
    for x in range(46, 67):
        for y in range(68, 75):
            if mask[y][x] == 6:
                img[y][x] = tone(SKIN, 0.05 + 0.12 * (y - 68) / 7.0, x, y)
    # ...and out of it, the eyes burn.
    for (ex, ey) in ((51, 74), (61, 74)):
        for (ox, oy, c) in ((0, 0, EYE), (1, 0, EYE), (-1, 0, FLAME[3]), (2, 0, FLAME[3]),
                            (0, -1, FLAME[2]), (1, -1, FLAME[2]), (0, 1, FLAME[1]), (1, 1, FLAME[1])):
            put(ex + ox, ey + oy, c, 6)
    # A long nose, lit from beneath on its tip and nostrils.
    for y in range(75, 85):
        put(56, y, SKIN[1], 6)
        put(55, y, SKIN[2] if y > 80 else SKIN[1], 6)
    put(55, 85, SKIN[3], 6)
    put(57, 85, SKIN[0], 6)
    # Thin lips, a grim line, and a pointed beard of grey.
    for x in range(51, 62):
        put(x, 89 + (1 if x in (51, 61) else 0), hexc("1a1214"), 6)
    beard = [hexc(c) for c in ("1e2220", "3a403c", "5e6660", "8a948a")]
    poly([(48, 91), (64, 91), (61, 98), (57, 106), (55, 106), (51, 98)], beard, part=7,
         shade=lambda x, y: 0.2 + 0.7 * fire_light(x, y) - (x - 48) / 60.0)
    for (x1, y1, x2, y2) in ((52, 93, 55, 104), (56, 93, 56, 105), (60, 93, 57, 103)):
        line(x1, y1, x2, y2, beard[0], part=7)
    seams(7, 6)
    seams(6, 5)


def staff():
    # His staff, held in his right hand, with a ram's skull on top.
    line(90, 196, 86, 58, WOOD[1], width=3, part=8)
    line(89, 196, 85, 58, WOOD[2], width=1, part=8)
    for y in (70, 92, 128):
        line(84, y, 90, y + 1, WOOD[0], part=8)
    # The crown of a skull, wide over a narrow jaw, mounted on the wood.
    blob(86, 46, 7, 6.5, BONE, part=9, bias=-0.05)
    blob(86, 53, 4.5, 3, BONE, part=9, bias=-0.2)
    # Deep sockets with a spark of the fire in each, and the hole of the nose.
    for ex in (83, 88):
        for (ox, oy) in ((0, 0), (1, 0), (0, 1), (1, 1), (0, -1)):
            put(ex + ox, 47 + oy, OUTLINE, 9)
        put(ex, 48, FLAME[2], 9)
    put(86, 50, OUTLINE, 9)
    put(86, 51, OUTLINE, 9)
    for x in range(83, 90):
        put(x, 54, OUTLINE if x % 2 == 0 else BONE[3], 9)
    for (x, y) in ((85, 40), (86, 41), (86, 42), (87, 43)):
        put(x, y, BONE[0], 9)
    # A charm hanging from it on a cord, below the skull.
    line(89, 58, 93, 66, TRIM[1], part=9)
    blob(93, 68, 1.4, 1.8, FLAME, part=9, bias=-0.1)
    # The hand round it: long knuckles closed over the wood.
    for i in range(4):
        y = 106 + i * 3
        line(84, y, 91, y + 1, SKIN[1], width=2, part=10)
        put(84, y, SKIN[2], 10)
        put(85, y - 1, SKIN[2], 10)
    line(83, 104, 85, 118, SKIN[0], part=10)
    poly([(76, 200), (80, 140), (84, 118), (92, 116), (96, 140), (98, 200)], ROBE, part=11,
         shade=lambda x, y: 0.35 - (x - 76) / 90.0)
    seams(11, 2)


def skull_hand():
    # His left arm comes up, the sleeve falling back from a bony wrist.
    poly([(14, 200), (16, 160), (22, 140), (34, 132), (40, 146), (34, 200)], ROBE, part=12,
         shade=lambda x, y: 0.4 + 0.7 * fire_light(x, y) - (y - 130) / 200.0)
    for (x1, y1, x2, y2) in ((22, 150, 18, 196), (30, 142, 28, 196)):
        line(x1, y1, x2, y2, ROBE[0], part=12)
    seams(12, 2)
    # The hand, palm up, fingers long and thin, cupping the skull from below.
    blob(31, 132, 7, 4, SKIN, part=13, bias=-0.05, light=(-0.4, 0.8, 0.4), glow=0.7)
    for (x0, y0, x1, y1) in ((24, 131, 21, 124), (27, 129, 25, 121), (36, 129, 39, 122), (38, 132, 42, 126)):
        line(x0, y0, x1, y1, SKIN[2], width=2, part=13)
        put(x1, y1, SKIN[3], 13)
    # The skull in it, all lit up from inside.
    blob(31, 116, 10, 9.5, BONE, part=14, bias=0.1, light=(-0.4, -0.5, 0.7), glow=0.45)
    blob(31, 124, 6.5, 3.5, BONE, part=14, bias=0.0, glow=0.4)
    # Eye holes and nose, with the fire showing through.
    for (ex, ey) in ((27, 116), (35, 116)):
        blob(ex, ey, 2.6, 2.4, [OUTLINE, FLAME[0], FLAME[1]], part=14, bias=-0.3)
        put(ex, ey, FLAME[3], 14)
        put(ex - 1, ey, FLAME[2], 14)
    for (x, y) in ((31, 120), (30, 121), (32, 121), (31, 121)):
        put(x, y, OUTLINE, 14)
    # Teeth.
    for x in range(26, 37):
        put(x, 124, OUTLINE if x % 2 == 0 else BONE[3], 14)
        put(x, 125, OUTLINE if x % 2 == 0 else BONE[2], 14)
    # A crack across the crown.
    for (x, y) in ((28, 108), (29, 109), (29, 110), (30, 111), (31, 111), (32, 112)):
        put(x, y, BONE[0], 14)
    seams(14, 13)


def fire():
    # Green fire rising off the skull, licking up in tongues, and sparks
    # drifting away above it.
    for y in range(60, 112):
        for x in range(8, 56):
            rise = (112 - y) / 52.0
            sway = math.sin(y * 0.28 + x * 0.05) * 4 * rise + math.sin(y * 0.11) * 3 * rise
            width = 11.0 * (1.0 - rise) ** 0.7 + 0.5
            d = abs(x + 0.5 - (31 + sway))
            tongue = math.sin(x * 0.9 + y * 0.35) * 0.5 + 0.5
            if d < width * (0.6 + 0.4 * tongue) and mask[y][x] not in (14,):
                heat = (1.0 - d / max(width, 0.1)) * (1.0 - rise * 0.75)
                if heat > 0.05:
                    put(x, y, tone(FLAME, heat * 1.05 + 0.08, x, y), 15)
    for (x, y) in ((22, 56), (40, 50), (28, 44), (36, 62), (18, 66), (44, 70), (33, 36), (25, 52)):
        put(x, y, FLAME[3], 15)
        put(x, y + 1, FLAME[1], 15)
    # The glow it casts on the cloth around it.
    for y in range(96, 160):
        for x in range(10, 64):
            if mask[y][x] in (2, 12) and fire_light(x, y, 40.0) > 0.25 and (x + y) % 2 == 0:
                img[y][x] = tint(img[y][x], FLAME[1], 0.25 * fire_light(x, y, 40.0))


def wisps():
    # Pale souls winding up round him, thin as smoke.
    soul = [hexc(c) for c in ("1f4a3a", "3f8a6a", "8ce0b8")]
    for (x0, y0, length, phase, reach) in ((6, 186, 60, 0.0, 6.0), (102, 178, 70, 1.7, 5.0), (60, 196, 40, 3.1, 4.0)):
        for i in range(length):
            y = y0 - i * 1.2
            x = x0 + math.sin(i * 0.15 + phase) * reach + (i * 0.25 if x0 < 50 else -i * 0.25)
            if mask[int(y)][int(x)] in (0, 30) and i % 7 != 3:
                level = 0.9 - i / length
                put(int(x), int(y), tone(soul, level, int(x), int(y)), 0)
                mask[int(y)][int(x)] = 0


def main():
    if os.path.exists(OUT) and "--force" not in sys.argv:
        print("portraits/Necromancer.png is already there: pass --force to paint over it")
        return
    background()
    robe()
    staff()
    hood()
    face()
    skull_hand()
    outline()
    fire()
    wisps()
    image = Image.new("RGB", (W, H))
    pixels = image.load()
    for y in range(H):
        for x in range(W):
            pixels[x, y] = img[y][x] if img[y][x] is not None else OUTLINE
    image = image.resize((W * SCALE, H * SCALE), Image.NEAREST)
    image.save(OUT, optimize=True)
    print("portraits/Necromancer.png: %dx%d" % image.size)


if __name__ == "__main__":
    main()
