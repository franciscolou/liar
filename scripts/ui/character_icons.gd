extends RefCounted
## A small icon for each character, to stand for them where a card would not
## fit (a line of the log): a 9x9 text bitmap in blocks of CELL on a dark tile
## framed in the character's own colour. One character per cell, "." for
## none; the inks are per character. A character with no icon here gets its
## initial. No class name: preload it and call icon().
##
## Character new: a bitmap in ICONS, its inks in INKS and its colour in RIMS.

const CELL := 2.0
const TILE := Color("1c1410")

const ICONS := {
	# A dagger, point up.
	&"assassin": [
		"....o....",
		"...o+o...",
		"...o+o...",
		"...o+o...",
		"...o+o...",
		".ooooooo.",
		"...o#o...",
		"...o#o...",
		"....o....",
	],
	# A pair of quavers.
	&"bard": [
		"...######",
		"...######",
		"...#....#",
		"...#....#",
		"...#....#",
		".###..###",
		"####.####",
		"####.####",
		".##...##.",
	],
	# A cocktail with its cherry.
	&"bartender": [
		"ooooooooo",
		"o###r###o",
		".o#####o.",
		"..o###o..",
		"...o#o...",
		"....o....",
		"....o....",
		"....o....",
		"..ooooo..",
	],
	# A bomb with the fuse lit.
	&"bomber": [
		"......+y.",
		".....o.+.",
		"...ooo...",
		"..o###o..",
		".o#+###o.",
		".o#####o.",
		".o#####o.",
		"..o###o..",
		"...ooo...",
	],
	# A clown's face: red hair, white paint, the nose.
	&"clown": [
		"rr.....rr",
		"rrwwwwwrr",
		".wkwwwkw.",
		".wwwrwww.",
		".wwrrrww.",
		".wkwwwkw.",
		"..wkkkw..",
		"...www...",
		".........",
	],
	# The doctor's cross.
	&"doctor": [
		"..ooooo..",
		"..o###o..",
		"ooo###ooo",
		"o#######o",
		"o#######o",
		"o#######o",
		"ooo###ooo",
		"..o###o..",
		"..ooooo..",
	],
	# A star of four points, cosmic.
	&"entity": [
		"....#....",
		"....#....",
		"...#+#...",
		"..#+w+#..",
		"##+www+##",
		"..#+w+#..",
		"...#+#...",
		"....#....",
		"....#....",
	],
	# A die, five up.
	&"gambler": [
		"ooooooooo",
		"o#######o",
		"o#k###k#o",
		"o#######o",
		"o###k###o",
		"o#######o",
		"o#k###k#o",
		"o#######o",
		"ooooooooo",
	],
	# A spade, its handle up.
	&"gravedigger": [
		"...www...",
		"...w.w...",
		"....w....",
		"....w....",
		"....w....",
		"..ooooo..",
		"..o+++o..",
		"..o+++o..",
		"...ooo...",
	],
	# A cut gem.
	&"heir": [
		".........",
		"..ooooo..",
		".o+#+#+o.",
		"ooooooooo",
		".o#-#-#o.",
		"..o#-#o..",
		"...o#o...",
		"....o....",
		".........",
	],
	# A masquerade mask.
	&"impostor": [
		".........",
		".........",
		"o#######o",
		"#########",
		"##kk#kk##",
		"#########",
		".###.###.",
		"..#...#..",
		".........",
	],
	# The scales of the court.
	&"judge": [
		"....#....",
		"#########",
		"#...#...#",
		"#...#...#",
		"+++.#.+++",
		"....#....",
		"....#....",
		"..#####..",
		".........",
	],
	# A top hat, upside down, the way a rabbit comes out of it.
	&"magician": [
		"ooooooooo",
		"o#######o",
		"ooooooooo",
		"..orrro..",
		"..o###o..",
		"..o###o..",
		"..o###o..",
		"..ooooo..",
		".........",
	],
	# A sight.
	&"mercenary": [
		"...ooo...",
		"..o.o.o..",
		".o..o..o.",
		"o...o...o",
		"oooo#oooo",
		"o...o...o",
		".o..o..o.",
		"..o.o.o..",
		"...ooo...",
	],
	# The vault, its dial in brass.
	&"mythomaniac": [
		"ooooooooo",
		"o#######o",
		"o#+++###o",
		"o#+o+#-#o",
		"o#+++###o",
		"o#####-#o",
		"o#######o",
		"ooooooooo",
		".o.....o.",
	],
	# A skull with its eyes alight.
	&"necromancer": [
		"..ooooo..",
		".o#####o.",
		"o#######o",
		"o#gg#gg#o",
		"o#gg#gg#o",
		".o##o##o.",
		"..o###o..",
		"..#o#o#..",
		"...ooo...",
	],
	# A palette with its three paints.
	&"painter": [
		"..oooo...",
		".o#b##o..",
		"o#####po.",
		"o#y####o.",
		"o###oo#o.",
		"o##o..o..",
		".o##o....",
		"..ooo....",
		".........",
	],
	# Two swords crossed.
	&"duelist": [
		"+.......+",
		".+.....+.",
		"..+...+..",
		"...+.+...",
		"....+....",
		"...+.+...",
		".oo...oo.",
		".#o...o#.",
		"#.......#",
	],
	# The sheriff's star.
	&"sheriff": [
		"....#....",
		"...###...",
		"#########",
		".#######.",
		"..##+##..",
		".#######.",
		".###.###.",
		"##.....##",
		".........",
	],
	# A fedora pulled low.
	&"spy": [
		".........",
		".........",
		"...ooo...",
		"..o###o..",
		"..o###o..",
		".orrrrro.",
		"o#######o",
		".ooooooo.",
		".........",
	],
	# A coin.
	&"vagabond": [
		"..ooooo..",
		".o#####o.",
		"o##+++##o",
		"o#+-#-+#o",
		"o#+#-#+#o",
		"o#+-#-+#o",
		"o##+++##o",
		".o#####o.",
		"..ooooo..",
	],
	# A voodoo doll, eyes stitched shut.
	&"voodooist": [
		"..ooooo.p",
		".o#x#x#o.",
		".o#####o.",
		"..o###o..",
		"oo#####oo",
		"o#o###o#o",
		"..o#o#o..",
		"..o#o#o..",
		"..oo.oo..",
	],
}

const INKS := {
	&"assassin": {"o": Color("8a8e98"), "+": Color("eef0f4"), "#": Color("b0562e")},
	&"bard": {"o": Color("f2c84b"), "#": Color("f2c84b")},
	&"bartender": {"o": Color("c9d2e0"), "#": Color("e85a3a"), "r": Color("c8102a")},
	&"bomber": {"o": Color("9a9aa6"), "#": Color("4a4a56"), "+": Color("a8a8b8"), "y": Color("ffd84a")},
	&"clown": {"r": Color("e8402a"), "w": Color("f4efe6"), "k": Color("1a1a1a")},
	&"doctor": {"o": Color("f4efe6"), "#": Color("d83a2e")},
	&"entity": {"#": Color("9a62c4"), "+": Color("6cd6e8"), "w": Color("ffffff")},
	&"gambler": {"o": Color("8a1e1a"), "#": Color("f4efe6"), "k": Color("1a1010")},
	&"gravedigger": {"o": Color("4a4a54"), "+": Color("a8a8b4"), "w": Color("8a5a2a")},
	&"heir": {"o": Color("1c4a6a"), "#": Color("5fd0f0"), "+": Color("e8fbff"), "-": Color("2f8ab0")},
	&"impostor": {"#": Color("8e4fb5"), "k": Color("120818"), "o": Color("c9a0e8")},
	&"judge": {"#": Color("e6bc4c"), "+": Color("fff0b0")},
	&"magician": {"o": Color("8a8a98"), "#": Color("2a2a34"), "r": Color("c8302a")},
	&"mercenary": {"o": Color("e85a3a"), "#": Color("ffd0a0")},
	&"mythomaniac": {"o": Color("2a2a30"), "#": Color("7a7e8a"), "+": Color("e6bc4c"), "-": Color("4a4e58")},
	&"duelist": {"+": Color("dfe6f0"), "o": Color("e6bc4c"), "#": Color("8a1e24")},
	&"necromancer": {"o": Color("6e6852"), "#": Color("e8e0c8"), "g": Color("7dff9a")},
	&"painter": {"o": Color("3a2410"), "#": Color("b07a44"), "b": Color("4f8fe0"), "p": Color("e877b8"), "y": Color("f2cf3c")},
	&"sheriff": {"#": Color("e6bc4c"), "+": Color("fff0b0")},
	&"spy": {"o": Color("8a8a98"), "#": Color("2e2c34"), "r": Color("8a2a2a")},
	&"vagabond": {"o": Color("6e4a14"), "#": Color("e6bc4c"), "+": Color("b8862a"), "-": Color("fff0b0")},
	&"voodooist": {"o": Color("3a2410"), "#": Color("c9a070"), "x": Color("1a1010"), "p": Color("e83a3a")},
}

## The colour of each character's frame.
const RIMS := {
	&"assassin": Color("8a2a22"), &"bard": Color("d8a050"), &"bartender": Color("e85a3a"),
	&"bomber": Color("e8702a"), &"clown": Color("e8402a"), &"doctor": Color("d83a2e"),
	&"entity": Color("9a62c4"), &"gambler": Color("c8302a"), &"gravedigger": Color("8a8a7a"),
	&"heir": Color("5fd0f0"), &"impostor": Color("8e4fb5"), &"judge": Color("e6bc4c"),
	&"magician": Color("c8302a"), &"mercenary": Color("e85a3a"), &"mythomaniac": Color("e6bc4c"),
	&"duelist": Color("b8322e"), &"necromancer": Color("3fbf6a"), &"painter": Color("e877b8"), &"sheriff": Color("e6bc4c"), &"spy": Color("8a8a98"),
	&"vagabond": Color("a8743c"), &"voodooist": Color("8e4fb5"),
}


## The icon of `character_id`, `zoom` times its size (one CELL per bitmap
## cell and a frame of one pixel: 20 px across).
static func icon(character_id: StringName, zoom := 1.0) -> Control:
	var tile := Tile.new()
	tile.rows = ICONS.get(character_id, [])
	tile.inks = INKS.get(character_id, {})
	tile.rim = RIMS.get(character_id, UI.GOLD)
	tile.zoom = zoom
	if tile.rows.is_empty():
		var def := Content.character(character_id)
		tile.initial = def.display_name.left(1).to_upper() if def != null else "?"
	return tile


class Tile extends Control:
	var rows: Array = []
	var inks: Dictionary = {}
	var rim := Color.WHITE
	var zoom := 1.0
	var initial := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _ready() -> void:
		custom_minimum_size = Vector2.ONE * (9 * CELL + 2) * zoom
		if initial != "":
			var letter := UI.label(initial, 11, rim, true)
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			letter.size = custom_minimum_size
			add_child(letter)

	func _draw() -> void:
		var cell := CELL * zoom
		var whole := Vector2.ONE * (9 * CELL + 2) * zoom
		draw_rect(Rect2(Vector2.ZERO, whole), rim.darkened(0.25))
		draw_rect(Rect2(Vector2.ONE * zoom, whole - Vector2.ONE * 2.0 * zoom), TILE)
		for y: int in rows.size():
			var row: String = rows[y]
			for x: int in row.length():
				if inks.has(row[x]):
					draw_rect(Rect2(Vector2(x, y) * cell + Vector2.ONE * zoom, Vector2(cell, cell)), inks[row[x]])
