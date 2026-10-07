"""Cuts the large paintings of a prototype folder down to card art, leaving
assets/cards/ alone: `python3 tools/gen_proto_cards.py [set ...]` (no names: all).

Needs Pillow. Each set in SETS reads assets/<set>/ and writes its own folder.
A painting is cropped to the card's 55:100 shape and shrunk to SCALE times the
card size. The game uses the set UI.CARD_ART_DIR points at; the frame is still
laid over it by UI.card_face.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(__file__)
ASSETS = os.path.join(HERE, "..", "assets")

W, H = 55, 100
SCALE = 4

# Source files whose name is not the card's.
RENAME = {"Maigician": "Magician", "SpyLarge": "Spy"}

# set (its folder in assets/) -> {out, anchor, base}. `anchor` says where the
# crop sits across a painting wider than the card: 0 keeps the left edge, 1 the
# right one. Centred when not listed. A card the set has no painting for is
# taken from the set named in `base`.
SETS = {
    "prototype": {
        "out": "cards_proto",
        "anchor": {
            "Assassin": 0.0,
            "Bartender": 0.25,
            "Bomber": 1.0,
            "Doctor": 0.8,
            "Spy": 0.3,
        },
    },
    "prototype2": {
        "out": "cards_proto2",
        "base": "prototype",
        "anchor": {
            "Spy": 0.2,
        },
    },
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


def paintings(name):
    """card name -> (set, file) for every card `name` covers, its base included."""
    spec = SETS[name]
    found = paintings(spec["base"]) if "base" in spec else {}
    for file in sorted(os.listdir(os.path.join(ASSETS, name))):
        stem, ext = os.path.splitext(file)
        if ext.lower() == ".png":
            found[RENAME.get(stem, stem)] = (name, file)
    return found


def build(name):
    folder = SETS[name]["out"]
    out = os.path.join(ASSETS, folder)
    os.makedirs(out, exist_ok=True)
    for card_name, (source, file) in sorted(paintings(name).items()):
        image = Image.open(os.path.join(ASSETS, source, file)).convert("RGB")
        anchor = SETS[source]["anchor"].get(card_name, 0.5)
        card = cut(image, anchor).resize((W * SCALE, H * SCALE), Image.LANCZOS)
        card.save(os.path.join(out, card_name + ".png"), optimize=True)
        print("%s/%s -> %s/%s.png" % (source, file, folder, card_name))


def main():
    for name in sys.argv[1:] or SETS:
        build(name)


if __name__ == "__main__":
    main()
