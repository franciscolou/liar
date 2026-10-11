"""Cuts the large paintings in assets/cards/portraits/ down to the card art in
assets/cards/: `python3 tools/gen_proto_cards.py [Name ...]` (no names: all).

Needs Pillow. A painting is cropped to the card's 55:100 shape and shrunk to
SCALE times the card size. The frame is laid over it by UI.card_face; the end
screen shows the paintings themselves.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "cards")
SRC = os.path.join(OUT, "portraits")

W, H = 55, 100
SCALE = 4

# Where the crop sits across a painting wider than the card: 0 keeps the left
# edge, 1 the right one. Centred when not listed.
ANCHOR = {
    "Spy": 0.2,
}


def cut(image, anchor):
    """The largest 55:100 window of `image`, placed by `anchor` on the spare axis."""
    width, height = image.size
    if width * H > height * W:
        crop = round(height * W / H)
        left = round((width - crop) * anchor)
        return image.crop((left, 0, left + crop, height))
    crop = round(width * H / W)
    top = round((height - crop) * anchor)
    return image.crop((0, top, width, top + crop))


def build(name):
    image = Image.open(os.path.join(SRC, name + ".png")).convert("RGB")
    card = cut(image, ANCHOR.get(name, 0.5)).resize((W * SCALE, H * SCALE), Image.LANCZOS)
    card.save(os.path.join(OUT, name + ".png"), optimize=True)
    print("portraits/%s.png -> %s.png" % (name, name))


def main():
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(SRC) if f.lower().endswith(".png"))
    for name in names:
        build(name)


if __name__ == "__main__":
    main()
