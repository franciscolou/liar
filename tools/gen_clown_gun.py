"""Paints assets/ui/clown_gun.png, the Clown's circus pistol: the Death's pistol
(assets/items/death.png) pixel for pixel, in toy colours.

Every pixel keeps the light it had and only changes its colour: the slide
goes hot pink, the frame turquoise, trigger and guard lime, the wooden grip
yellow with polka dots and the muzzle gets the orange cap of a toy gun. The
outline stays dark, a little purple. Run: python3 tools/gen_clown_gun.py
"""
import colorsys
import os

from PIL import Image

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "assets", "items", "death.png")
OUT = os.path.join(HERE, "..", "assets", "ui", "clown_gun.png")

# Hue (0..1) and saturation of each part.
SLIDE = (0.92, 0.75)  # hot pink
FRAME = (0.48, 0.70)  # turquoise
GUARD = (0.24, 0.80)  # lime
GRIP = (0.14, 0.85)  # yellow
DOTS = (0.98, 0.85)  # red
CAP = (0.07, 0.95)  # orange
OUTLINE = (0.78, 0.55)  # dark purple

# Rows of the art: the slide down to SLIDE_END, the frame below it, and the
# trigger guard under the frame, left of the grip.
SLIDE_END = 22
FRAME_END = 29
CAP_END = 9  # the muzzle: columns up to here
# Polka dots on the grip: centres, radius 1.5 px.
DOT_AT = [(49, 34), (45, 40), (51, 43), (47, 48), (52, 52)]


def lum(r, g, b):
    return (0.3 * r + 0.59 * g + 0.11 * b) / 255.0


def paint(rgb, tone, lift=1.0):
    """`rgb`'s light in the colour `tone`, brightened by `lift` (the steel was
    dim: toy plastic is not)."""
    hue, sat = tone
    value = min(1.0, max(colorsys.rgb_to_hsv(*(c / 255.0 for c in rgb))[2], lum(*rgb)) * lift)
    return tuple(round(c * 255) for c in colorsys.hsv_to_rgb(hue, sat, value))


def main():
    image = Image.open(SRC).convert("RGBA")
    out = image.copy()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = image.getpixel((x, y))
            if a == 0:
                continue
            if a < 200:
                # The faint shine along the top edge stays as it is.
                continue
            light = lum(r, g, b)
            wooden = r > b + 12
            if light < 0.09 and not wooden:
                rgb = paint((r, g, b), OUTLINE, 2.2)
            elif wooden:
                near_dot = any((x - cx) ** 2 + (y - cy) ** 2 <= 2.3 for cx, cy in DOT_AT)
                rgb = paint((r, g, b), DOTS if near_dot else GRIP, 2.4 if near_dot else 2.9)
            elif x <= CAP_END and y <= FRAME_END:
                rgb = paint((r, g, b), CAP, 2.0)
            elif y <= SLIDE_END:
                rgb = paint((r, g, b), SLIDE, 1.75)
            elif y <= FRAME_END:
                rgb = paint((r, g, b), FRAME, 2.1)
            else:
                rgb = paint((r, g, b), GUARD, 2.4)
            out.putpixel((x, y), rgb + (a,))
    out.save(OUT, optimize=True)
    print("death.png -> ui/clown_gun.png")


if __name__ == "__main__":
    main()
