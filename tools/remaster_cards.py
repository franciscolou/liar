"""Proposes a remastered version of every card in assets/cards/ into
assets/cards_v2/, leaving the originals alone: `python3 tools/remaster_cards.py`.

Needs Pillow. The drawing itself is kept (shapes, poses, colours); what is
added is finish: contour lines where two surfaces meet, light from the top
left on every form, warm lights against cool shadows, and a dithered vignette
that pulls the eye to the character.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "assets", "cards")
OUT = os.path.join(HERE, "..", "assets", "cards_v2")
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
EDGE = 46      # colour distance at which two neighbours are different surfaces
CONTOUR = 0.72  # the darker side of a hard edge is multiplied by this
LIT = 1.10     # top-left rims
SHADED = 0.88  # bottom-right rims
RIM = 30       # colour distance at which a form is taken to turn


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def dist(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def scale(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def grade(c):
    """Cool shadows, warm lights, a little more contrast."""
    l = lum(c) / 255.0
    r, g, b = c
    cool = (1.0 - l) ** 2 * 0.16
    warm = l ** 2 * 0.10
    r = r * (1.0 - cool * 0.9 + warm)
    g = g * (1.0 - cool * 0.5 + warm * 0.5)
    b = b * (1.0 + cool * 0.9 - warm * 0.8)
    out = []
    for v in (r, g, b):
        v = (v / 255.0 - 0.5) * 1.1 + 0.5
        out.append(max(0, min(255, int(v * 255))))
    return tuple(out)


def remaster(path):
    src = Image.open(path).convert("RGB")
    w, h = src.size
    px = src.load()
    out = Image.new("RGB", (w, h))
    op = out.load()

    def at(x, y):
        return px[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]

    for y in range(h):
        for x in range(w):
            c = at(x, y)
            k = 1.0
            up, left, down, right = at(x, y - 1), at(x - 1, y), at(x, y + 1), at(x + 1, y)
            hard = [n for n in (up, left, down, right) if dist(c, n) > EDGE]
            if hard and all(lum(c) <= lum(n) for n in hard):
                # The darker side of a hard edge becomes the contour.
                k *= CONTOUR
            else:
                # Rims: lit where the form turns up/left, shaded down/right.
                if dist(c, up) > RIM or dist(c, left) > RIM:
                    k *= LIT
                if dist(c, down) > RIM or dist(c, right) > RIM:
                    k *= SHADED
            c = grade(scale(c, k))
            # Dithered vignette, stronger at the bottom corners.
            dx = (x - (w - 1) / 2.0) / (w / 2.0)
            dy = (y - (h - 1) * 0.42) / (h * 0.58)
            v = max(0.0, (dx * dx + dy * dy) - 0.55) * 1.5
            if v * 16.0 > BAYER[y % 4][x % 4] + 0.5:
                c = scale(c, 0.72)
            op[x, y] = c
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name in sorted(os.listdir(SRC)):
        if name.endswith(".png"):
            remaster(os.path.join(SRC, name)).save(os.path.join(OUT, name))
            print(name)
