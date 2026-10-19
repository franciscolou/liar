"""Draws assets/items/fresh_card.png: the shop's "Fresh Card" (a card of the
hand traded for one from the deck), 61x64 like the other item icons.

A single card back, darkened almost to black, with a "?" in the middle.
Run: python3 tools/gen_item_icon.py
"""
from PIL import Image

W, H = 61, 64
OUT = "assets/items/fresh_card.png"

INK = (6, 5, 8, 255)
WOOD = (34, 22, 14, 255)
WOOD_DARK = (24, 15, 10, 255)
TRIM = (70, 52, 26, 255)
TRIM_DARK = (48, 35, 18, 255)
GOLD = (222, 172, 70, 255)

QUESTION = [
	".####.",
	"##..##",
	"....##",
	"...##.",
	"..##..",
	"..##..",
	"......",
	"..##..",
]
SCALE = 2  # each cell of QUESTION is SCALE x SCALE pixels


def card(img, x0, y0, w, h):
	px = img.load()
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			edge = x in (x0, x0 + w - 1) or y in (y0, y0 + h - 1)
			# Rounded corners.
			if (x in (x0, x0 + w - 1)) and (y in (y0, y0 + h - 1)):
				continue
			if edge:
				px[x, y] = INK
			elif x in (x0 + 2, x0 + w - 3) or y in (y0 + 2, y0 + h - 3):
				px[x, y] = TRIM if (x + y) % 2 == 0 else TRIM_DARK
			elif x in (x0 + 1, x0 + w - 2) or y in (y0 + 1, y0 + h - 2):
				px[x, y] = WOOD_DARK
			else:
				px[x, y] = WOOD if (x // 2 + y // 2) % 2 == 0 else WOOD_DARK
	cx, cy = x0 + w // 2, y0 + h // 2
	qw, qh = len(QUESTION[0]) * SCALE, len(QUESTION) * SCALE
	qx, qy = cx - qw // 2, cy - qh // 2
	strokes = [
		(qx + i * SCALE + a, qy + j * SCALE + b)
		for j, row in enumerate(QUESTION) for i, ch in enumerate(row) if ch == "#"
		for a in range(SCALE) for b in range(SCALE)
	]
	# A dark rim under and to the right of each stroke, then the stroke.
	for x, y in strokes:
		for dx, dy in ((1, 0), (0, 1), (1, 1)):
			px[x + dx, y + dy] = INK
	for x, y in strokes:
		px[x, y] = GOLD


def main():
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	card(img, 14, 3, 33, 58)
	img.save(OUT)


if __name__ == "__main__":
	main()
