"""Draws stand-in art for characters that have no painted card yet:
`python3 tools/gen_placeholder_cards.py [Name ...]` (no names: all).

Needs Pillow. Each card is 55x100, drawn in flat shapes with a one-step shade,
close enough to the painted ones to sit next to them until the real art comes.
The frame is laid over them by the game (UI.card_face), as with every card.
"""
import os
import sys
from PIL import Image, ImageDraw

W, H = 55, 100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "cards")


def rgb(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(color, k):
    """Darker (k < 1) or lighter (k > 1) version of a colour."""
    return tuple(max(0, min(255, int(c * k))) for c in color[:3]) + (255,)


class Card:
    def __init__(self, bg):
        self.im = Image.new("RGBA", (W, H), rgb(bg))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x, y, w, h, color):
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=color if isinstance(color, tuple) else rgb(color))

    def oval(self, x, y, w, h, color):
        self.d.ellipse([x, y, x + w - 1, y + h - 1], fill=color if isinstance(color, tuple) else rgb(color))

    def poly(self, points, color):
        self.d.polygon(points, fill=color if isinstance(color, tuple) else rgb(color))

    def line(self, points, color, width=1):
        self.d.line(points, fill=color if isinstance(color, tuple) else rgb(color), width=width)

    def px(self, x, y, color):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((x, y), color if isinstance(color, tuple) else rgb(color))

    def glow(self, cx, cy, radius, color, steps=4):
        """A soft disc behind the figure: rings of the colour, brighter inside."""
        base = rgb(color)
        back = self.im.getpixel((1, 1))
        for i in range(steps):
            k = (i + 1) / (steps + 1)
            r = radius * (1.0 - i / steps)
            mixed = tuple(int(back[c] + (base[c] - back[c]) * k) for c in range(3)) + (255,)
            self.oval(int(cx - r), int(cy - r), int(2 * r), int(2 * r), mixed)

    def bust(self, skin, top, cx=27, head_y=24, head_w=17, head_h=20, shoulders=38, neck=7):
        """Head, neck and a torso that runs off the bottom of the card. The
        right-hand side of everything is one step darker."""
        skin_c, top_c = rgb(skin), rgb(top)
        body_y = head_y + head_h + 3
        left = cx - shoulders // 2
        # Torso: sloped shoulders, then straight down.
        self.poly([(left + 5, body_y), (left + shoulders - 6, body_y), (left + shoulders - 1, body_y + 7),
                   (left + shoulders - 1, H), (left, H), (left, body_y + 7)], top_c)
        self.poly([(cx + 3, body_y), (left + shoulders - 6, body_y), (left + shoulders - 1, body_y + 7),
                   (left + shoulders - 1, H), (cx + 3, H)], shade(top_c, 0.8))
        # Neck.
        self.rect(cx - neck // 2, head_y + head_h - 3, neck, 8, shade(skin_c, 0.82))
        # Head.
        self.oval(cx - head_w // 2, head_y, head_w, head_h, skin_c)
        self.rect(cx + head_w // 2 - 3, head_y + 5, 2, head_h - 9, shade(skin_c, 0.85))
        return body_y

    def eyes(self, cx, y, color="#1a1210", gap=4):
        self.rect(cx - gap - 1, y, 2, 2, color)
        self.rect(cx + gap - 1, y, 2, 2, color)

    def arm(self, points, sleeve, hand, skin, width=5):
        """A sleeve along `points` ending in a hand at the last one."""
        self.line(points, shade(rgb(sleeve), 0.72), width + 2)
        self.line(points, sleeve, width)
        x, y = points[-1]
        self.oval(x - hand // 2, y - hand // 2, hand, hand, skin)

    def save(self, name):
        self.im.save(os.path.join(OUT, name + ".png"))
        print(name)


def impostor():
    """Jane Doe: a trench coat, a hat pulled low and a mask where the face
    should be. The half of her that shows has no features at all."""
    c = Card("#16222b")
    c.glow(27, 40, 34, "#35505c")
    # A street lamp far behind her.
    c.rect(6, 12, 1, 70, "#0f171d")
    c.rect(4, 10, 5, 3, "#e8d48a")
    body = c.bust("#d8b99a", "#8a7350", head_y=25)
    # Coat: lapels, belt and buttons.
    c.poly([(20, body), (27, body + 16), (27, body)], "#6d5a3c")
    c.poly([(34, body), (27, body + 16), (27, body)], "#5c4b31")
    c.rect(26, body + 16, 2, 40, "#5c4b31")
    c.rect(8, body + 30, 39, 4, "#4a3b26")
    c.rect(25, body + 29, 5, 6, "#c9a24a")
    for y in (body + 20, body + 40):
        c.rect(22, y, 2, 2, "#2e2416")
        c.rect(31, y, 2, 2, "#2e2416")
    # Hair down one side.
    c.rect(18, 30, 3, 20, "#3a2418")
    c.rect(34, 30, 3, 16, "#2c1a12")
    # The mask, held over the left half of the face.
    c.oval(17, 27, 13, 18, "#f2efe6")
    c.rect(27, 28, 3, 16, "#f2efe6")
    c.rect(20, 33, 4, 2, "#16222b")
    c.rect(25, 33, 3, 2, "#16222b")
    c.line([(20, 40), (22, 42), (26, 42), (28, 40)], "#16222b")
    c.rect(29, 27, 1, 18, "#b9b4a6")
    # The hat: wide brim, dented crown, a band.
    c.rect(11, 25, 33, 3, "#23232b")
    c.rect(11, 27, 33, 1, "#14141a")
    c.poly([(17, 25), (19, 14), (25, 16), (30, 13), (37, 15), (38, 25)], "#2c2c36")
    c.rect(17, 22, 22, 3, "#7a1f1f")
    # Hand on the mask's stick.
    c.arm([(11, 80), (13, 60), (20, 48)], "#8a7350", 5, "#d8b99a")
    c.line([(21, 47), (23, 44)], "#3a2a18", 1)
    return c


def gambler():
    """Dolores "Snake Eyes" Quinn: red dress, a fan of cards, a coin in the air
    and two dice showing ones."""
    c = Card("#123a2a")
    c.glow(27, 44, 36, "#2f7350")
    # Felt pattern.
    for y in range(6, H, 12):
        for x in range(4 + (y // 12 % 2) * 6, W, 12):
            c.px(x, y, "#0c2a1e")
    body = c.bust("#b8805c", "#a8242c", head_y=26)
    # Neckline and a string of pearls.
    c.poly([(20, body), (34, body), (27, body + 12)], "#b8805c")
    for i, x in enumerate(range(20, 35, 2)):
        c.px(x, body + 1 + (2 if 2 < i < 5 else 1 if i in (1, 2, 5, 6) else 0), "#f4eede")
    # Hair: a dark bob with a gold comb.
    c.oval(17, 21, 21, 16, "#1c1014")
    c.rect(17, 28, 4, 16, "#1c1014")
    c.rect(34, 28, 4, 14, "#140a0e")
    c.oval(20, 27, 15, 18, "#b8805c")
    c.rect(20, 25, 15, 4, "#1c1014")
    c.rect(33, 22, 4, 2, "#e6bc4c")
    c.eyes(27, 34)
    c.rect(22, 32, 4, 1, "#1c1014")
    c.rect(29, 32, 4, 1, "#1c1014")
    c.rect(25, 41, 5, 1, "#8c1c22")
    # A fan of cards in her left hand.
    c.arm([(10, 86), (11, 70), (15, 62)], "#a8242c", 5, "#b8805c")
    for i, (dx, tilt) in enumerate(((-6, -5), (-2, -2), (2, 1), (6, 4))):
        x = 14 + dx
        c.poly([(x, 60), (x + tilt, 44), (x + tilt + 7, 45), (x + 7, 61)], "#efe6cf" if i % 2 == 0 else "#ddd2b6")
        c.rect(x + tilt + 2, 47, 2, 2, "#a8242c" if i % 2 == 0 else "#1c1014")
    # A coin flipped off her right thumb.
    c.arm([(45, 88), (44, 74), (41, 66)], "#851c22", 5, "#a06a4a")
    c.oval(38, 46, 9, 9, "#8b6218")
    c.oval(39, 47, 7, 7, "#e6bc4c")
    c.rect(42, 49, 1, 3, "#8b6218")
    for y in (57, 60, 63):
        c.px(42, y, "#e6bc4c")
    # Snake eyes on the table edge.
    for x in (19, 29):
        c.rect(x, 85, 8, 8, "#f2efe6")
        c.rect(x + 7, 85, 1, 8, "#b9b4a6")
        c.rect(x, 92, 8, 1, "#b9b4a6")
        c.rect(x + 3, 88, 2, 2, "#1a1210")
    return c


def gravedigger():
    """Mortimer "Six Feet" Graves: a top hat, a long black coat, a shovel and
    a moon over somebody's cross."""
    c = Card("#1b2233")
    c.oval(33, 6, 18, 18, "#d9d6c3")
    c.oval(37, 5, 16, 16, "#1b2233")
    # The hill and its markers.
    c.oval(-20, 78, 95, 60, "#121723")
    c.rect(6, 62, 2, 18, "#0c1018")
    c.rect(2, 67, 10, 2, "#0c1018")
    c.poly([(42, 84), (42, 72), (45, 69), (48, 72), (48, 84)], "#2b3346")
    body = c.bust("#c9c2ae", "#17171c", head_y=27, head_w=14, head_h=22, shoulders=30)
    # A grey scarf and a row of buttons.
    c.rect(22, body - 2, 11, 5, "#5b5f68")
    c.rect(28, body + 3, 4, 12, "#4a4e56")
    for y in range(body + 18, H, 9):
        c.rect(26, y, 2, 2, "#5b5f68")
    # Hollow face.
    c.rect(22, 36, 3, 3, "#3a3640")
    c.rect(29, 36, 3, 3, "#3a3640")
    c.rect(23, 37, 1, 1, "#e8e2c8")
    c.rect(30, 37, 1, 1, "#e8e2c8")
    c.rect(24, 44, 6, 1, "#3a3640")
    c.rect(20, 40, 2, 6, "#a8a290")
    # Top hat with a mourning band.
    c.rect(16, 26, 23, 2, "#0c0c10")
    c.rect(20, 8, 15, 18, "#17171c")
    c.rect(31, 8, 4, 18, "#0c0c10")
    c.rect(20, 21, 15, 3, "#4b2a52")
    # The shovel, blade up, in a gloved hand.
    c.rect(46, 30, 2, 66, "#6b4a2a")
    c.rect(47, 30, 1, 66, "#4a3018")
    c.poly([(42, 30), (52, 30), (52, 20), (47, 14), (42, 20)], "#8a93a3")
    c.poly([(47, 30), (52, 30), (52, 20), (47, 14)], "#5e6676")
    c.arm([(40, 92), (43, 74), (46, 62)], "#17171c", 5, "#3a3640")
    return c


def bartender():
    """Rosie Malone: red hair, rolled sleeves, a shelf of bottles behind her
    and a glass whose colour nobody should trust."""
    c = Card("#3a2415")
    # The back bar: two shelves of bottles and a mirror's glint.
    c.rect(0, 0, W, 34, "#2a180d")
    for shelf in (15, 33):
        c.rect(0, shelf, W, 2, "#5a3a1e")
    bottles = ("#3f7a4a", "#b8862e", "#7a2a2a", "#3a5a8a", "#c9c2ae", "#3f7a4a", "#b8862e", "#7a2a2a")
    for i, color in enumerate(bottles):
        x = 3 + i * 7
        for shelf, tall in ((15, 9 + (i * 3) % 4), (33, 10 + (i * 5) % 4)):
            c.rect(x, shelf - tall, 4, tall, color)
            c.rect(x + 1, shelf - tall - 3, 2, 3, color)
            c.rect(x + 3, shelf - tall, 1, tall, shade(rgb(color), 0.7))
    c.glow(27, 52, 24, "#5a3a1e", 3)
    body = c.bust("#e3b592", "#e9e2d0", head_y=30)
    # Vest over the shirt, sleeves rolled.
    c.poly([(9, body + 8), (20, body), (25, body + 22), (25, H), (9, H)], "#2e3a36")
    c.poly([(46, body + 8), (35, body), (30, body + 22), (30, H), (46, H)], "#232d2a")
    c.rect(26, body + 24, 3, 3, "#c9a24a")
    c.rect(26, body + 34, 3, 3, "#c9a24a")
    c.poly([(22, body), (33, body), (27, body + 8)], "#e3b592")
    # Hair: red, pinned up, a loose curl.
    c.oval(17, 24, 21, 17, "#b5421f")
    c.oval(22, 19, 12, 10, "#c5512a")
    c.rect(17, 32, 3, 12, "#b5421f")
    c.rect(35, 32, 3, 10, "#8f3216")
    c.oval(20, 31, 15, 18, "#e3b592")
    c.rect(20, 29, 15, 4, "#b5421f")
    c.eyes(27, 38, "#2a1a10")
    c.line([(24, 45), (26, 46), (29, 46), (31, 44)], "#8c3a2a")
    c.px(22, 42, "#d49a7a")
    c.px(32, 42, "#d49a7a")
    # The drink she slides across: a little too green.
    c.arm([(10, 94), (9, 80), (14, 72)], "#e9e2d0", 5, "#e3b592")
    c.rect(11, 60, 9, 12, "#cfe6ea")
    c.rect(12, 63, 7, 8, "#7fbf3a")
    c.rect(18, 60, 1, 12, "#9fbcc2")
    c.px(14, 61, "#b6e86a")
    c.px(16, 58, "#b6e86a")
    c.px(13, 56, "#7fbf3a")
    # The bar top.
    c.rect(0, 94, W, 6, "#6b4424")
    c.rect(0, 94, W, 1, "#8a5c34")
    return c


def sheriff():
    """Sheriff Amos Harlan: the hat, the moustache, the star, and a hand held
    out for what the town owes him."""
    c = Card("#a8552a")
    # Dusk: bands of sky and a low sun.
    for i, color in enumerate(("#7a3423", "#93432a", "#b5612e", "#cf8a3a")):
        c.rect(0, i * 14, W, 14, color)
    c.oval(34, 30, 20, 20, "#f0c060")
    c.rect(0, 56, W, 44, "#5a3320")
    c.poly([(0, 56), (10, 50), (18, 56)], "#4a2a1a")
    c.poly([(36, 56), (46, 47), (55, 56)], "#4a2a1a")
    body = c.bust("#c98f66", "#8b7355", head_y=27, shoulders=40)
    # Leather vest, a neckerchief and the star.
    c.poly([(7, body + 8), (19, body), (24, body + 26), (24, H), (7, H)], "#4a2e1c")
    c.poly([(47, body + 8), (36, body), (31, body + 26), (31, H), (47, H)], "#3a2214")
    c.poly([(21, body - 1), (34, body - 1), (27, body + 9)], "#8c2020")
    for dx, dy in ((0, -3), (-3, -1), (3, -1), (-2, 3), (2, 3), (0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-1, 1), (1, 1), (0, -2)):
        c.px(15 + dx, body + 16 + dy, "#e6bc4c")
    c.px(15, body + 16, "#fff0b0")
    # Moustache and a hard stare.
    c.rect(22, 38, 2, 1, "#1a1210")
    c.rect(30, 38, 2, 1, "#1a1210")
    c.rect(21, 42, 12, 3, "#4a3524")
    c.rect(20, 44, 3, 3, "#4a3524")
    c.rect(31, 44, 3, 3, "#3a281a")
    c.rect(20, 34, 3, 6, "#6b5038")
    c.rect(32, 34, 3, 6, "#5a4028")
    # The hat.
    c.oval(8, 24, 39, 9, "#3a2a1c")
    c.rect(8, 29, 39, 2, "#241810")
    c.poly([(17, 27), (19, 13), (26, 16), (33, 13), (37, 27)], "#4a3626")
    c.rect(18, 23, 19, 3, "#241810")
    c.px(27, 24, "#e6bc4c")
    # An open palm, and two coins already in it.
    c.arm([(47, 92), (48, 78), (44, 70)], "#8b7355", 7, "#c98f66")
    c.rect(40, 66, 5, 2, "#8b6218")
    c.rect(40, 65, 5, 1, "#e6bc4c")
    c.rect(41, 63, 5, 2, "#8b6218")
    c.rect(41, 62, 5, 1, "#e6bc4c")
    # Gun belt.
    c.rect(7, 88, 41, 4, "#241810")
    c.rect(25, 87, 5, 6, "#c9a24a")
    return c


def doctor():
    """Dr. Ezra "Sawbones" Quill: a head mirror, round glasses, a coat that
    has seen things and a syringe held like a cigar."""
    c = Card("#3c5a52")
    # Tiles.
    for y in range(0, H, 10):
        c.rect(0, y, W, 1, "#32504a")
    for x in range(0, W, 10):
        c.rect(x, 0, 1, H, "#32504a")
    c.glow(27, 44, 28, "#5f8a7c", 3)
    body = c.bust("#dcb48e", "#e8e6de", head_y=26)
    # Coat lapels, shirt and tie; old stains near the hem.
    c.poly([(20, body), (27, body + 18), (16, body + 10)], "#cfccc2")
    c.poly([(34, body), (27, body + 18), (38, body + 10)], "#b8b5aa")
    c.poly([(23, body), (31, body), (27, body + 10)], "#6f8a9a")
    c.rect(26, body + 4, 3, 12, "#7a1f1f")
    c.rect(12, body + 34, 5, 3, "#8c2a22")
    c.rect(15, body + 37, 3, 4, "#8c2a22")
    c.rect(36, body + 44, 4, 3, "#7a231c")
    c.rect(33, body + 20, 6, 1, "#9a978c")
    c.rect(34, body + 17, 1, 4, "#3a5a8a")
    c.rect(36, body + 17, 1, 4, "#8c2a22")
    # Thin grey hair, a moustache, a tired smile.
    c.rect(18, 30, 3, 10, "#9a9a96")
    c.rect(34, 30, 3, 10, "#7e7e7a")
    c.rect(21, 26, 13, 3, "#9a9a96")
    c.rect(23, 41, 9, 2, "#8a8a86")
    c.rect(25, 44, 5, 1, "#8c5a4a")
    # Round glasses.
    for x in (21, 28):
        c.rect(x, 34, 6, 5, "#2a2a2a")
        c.rect(x + 1, 35, 4, 3, "#bfe0e6")
        c.px(x + 1, 35, "#ffffff")
    c.rect(27, 36, 1, 1, "#2a2a2a")
    # Head mirror on its band.
    c.rect(19, 28, 17, 2, "#2a2a2a")
    c.oval(24, 20, 9, 9, "#8a93a3")
    c.oval(25, 21, 7, 7, "#dfe8f0")
    c.rect(28, 24, 1, 1, "#5e6676")
    # The syringe.
    c.arm([(45, 92), (45, 76), (41, 66)], "#e8e6de", 5, "#dcb48e")
    c.rect(40, 48, 3, 16, "#dfe8f0")
    c.rect(40, 54, 3, 8, "#7fbf3a")
    c.rect(41, 40, 1, 8, "#aab3c0")
    c.rect(39, 64, 5, 1, "#8a93a3")
    c.px(41, 37, "#b6e86a")
    return c


def bomber():
    """Barnaby "Boom" Flint: goggles, a soot-black beard, and a round bomb
    with its fuse already burning."""
    c = Card("#3a1410")
    c.glow(27, 46, 38, "#8a3a18")
    # Embers in the air.
    for x, y, color in ((6, 14, "#ffb347"), (48, 22, "#ff7a2a"), (12, 40, "#ff7a2a"), (44, 8, "#ffd98a"),
                        (50, 50, "#ffb347"), (4, 62, "#ff7a2a"), (40, 34, "#ffd98a")):
        c.px(x, y, color)
        c.px(x, y + 1, shade(rgb(color), 0.6))
    body = c.bust("#c08a66", "#4a4238", head_y=26, head_w=19, shoulders=42)
    # Overalls with a strap of charges across the chest.
    c.rect(18, body + 6, 19, H, "#6b3d24")
    c.rect(28, body + 6, 9, H, "#55301c")
    c.rect(18, body, 3, 8, "#6b3d24")
    c.rect(34, body, 3, 8, "#55301c")
    for i in range(4):
        x, y = 12 + i * 8, body + 14 + i * 5
        c.rect(x, y, 3, 8, "#b3261f")
        c.rect(x + 2, y, 1, 8, "#801812")
        c.rect(x + 1, y - 2, 1, 2, "#d8c9a0")
    # Bald, sooty, with a beard like a brush.
    c.rect(18, 40, 19, 9, "#1a1614")
    c.oval(18, 40, 19, 12, "#1a1614")
    c.rect(24, 43, 7, 1, "#c9c2ae")
    c.px(22, 30, "#2a2420")
    c.px(33, 31, "#2a2420")
    c.px(30, 28, "#2a2420")
    # Goggles: brass rims, firelit lenses.
    c.rect(17, 33, 21, 2, "#3a2a1c")
    for x in (19, 28):
        c.rect(x, 31, 8, 7, "#b8862e")
        c.rect(x + 1, 32, 6, 5, "#ffb347")
        c.rect(x + 1, 32, 2, 2, "#fff0b0")
        c.rect(x + 4, 35, 3, 2, "#e0661a")
    # The bomb, held up, fuse burning.
    c.arm([(46, 94), (47, 80), (43, 72)], "#4a4238", 6, "#c08a66")
    c.oval(34, 54, 16, 16, "#0e0e12")
    c.oval(36, 56, 5, 4, "#3a3a46")
    c.rect(40, 51, 4, 4, "#2a2a32")
    c.line([(42, 51), (44, 47), (47, 46), (49, 42)], "#b89a6a", 1)
    c.rect(48, 39, 3, 3, "#ff7a2a")
    c.px(49, 40, "#fff0b0")
    for x, y in ((51, 37), (47, 37), (52, 41), (49, 36)):
        c.px(x, y, "#ffd98a")
    return c


CARDS = {
    "Impostor": impostor,
    "Gambler": gambler,
    "Gravedigger": gravedigger,
    "Bartender": bartender,
    "Sheriff": sheriff,
    "Doctor": doctor,
    "Bomber": bomber,
}

if __name__ == "__main__":
    for name in sys.argv[1:] or CARDS:
        CARDS[name]().save(name)
