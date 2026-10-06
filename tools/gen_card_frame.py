"""Draws the frame laid over every card face: `python3 tools/gen_card_frame.py`.

Needs Pillow. The game composes it with the art at runtime (UI.card_face).
"""
import os
from PIL import Image
W, H = 55, 100
DARK = (61, 36, 12, 255)
GOLD = (183, 135, 30, 255)
LIGHT = (217, 168, 64, 255)
SHADE = (139, 98, 24, 255)
INNER = (36, 20, 8, 150)
CUT = [3, 2, 1]  # transparent pixels per row at each corner, as on the card back

def cut(y):
    e = min(y, H - 1 - y)
    return CUT[e] if e < len(CUT) else 0

def inside(x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return False
    c = cut(y)
    return c <= x < W - c

def depth(x, y):
    """Distance in pixels to the outside of the card shape (chebyshev rings)."""
    d = 0
    while all(inside(x + dx, y + dy) for dx in range(-d - 1, d + 2) for dy in range(-d - 1, d + 2)
            if max(abs(dx), abs(dy)) == d + 1 and (dx == 0 or dy == 0)):
        d += 1
        if d > 6:
            break
    return d

im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
for y in range(H):
    for x in range(W):
        if not inside(x, y):
            continue
        d = depth(x, y)
        if d == 0:
            im.putpixel((x, y), DARK)
        elif d == 1:
            lit = (x + y) < (W + H) / 2 - 22
            im.putpixel((x, y), LIGHT if lit else GOLD)
        elif d == 2:
            im.putpixel((x, y), SHADE)
        elif d == 3:
            im.putpixel((x, y), INNER)
# corner studs
for cx, cy in [(6, 6), (W - 7, 6), (6, H - 7), (W - 7, H - 7)]:
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if abs(dx) + abs(dy) <= 1:
                im.putpixel((cx + dx, cy + dy), GOLD)
    im.putpixel((cx, cy), LIGHT)
im.save(os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "card_frame.png"))
