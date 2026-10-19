extends Control
## The backdrop of the HeroPanel: the player's side of the bar counter, drawn
## in the same blocks as the shop's display case (see shop_stall.gd). From the
## left: a brass nameplate over a ledger strip and the felt-lined sockets of
## the inventory, a felt mat the hand lies on, a rack where the other
## characters of the match stand on a shelf, and the end of the counter with
## the buttons, on a raised panel. Posts with brass rivets part the sections.
## The inlay of the rail across the top lights up on the player's turn.
##
## It is painted cell by cell (a cell is PX × PX pixels) into a picture that is
## kept for each look: the wood has the grain, knots and dithered wear of the
## saloon doors and the desk (Transition.WOOD), lit from above by the lamp in
## dithered steps; the felt has a nap, the brass four tones. No class name:
## preload it (see hero_panel.gd).

const PX := 2.0
## Height of the rail across the top, inlay included.
const RAIL := 8.0

# Where things are, for the HeroPanel to put its widgets on them.
const PLATE := Rect2(8, 12, 186, 26)
const LEDGER := Rect2(8, 42, 216, 26)
const SOCKET := Vector2(58, 58)
const SOCKET_STEP := 64.0
const SOCKETS_AT := Vector2(14, 106)
const MAT := Rect2(236, 12, 188, 154)
const RACK := Rect2(436, 26, 580, 138)
## How far down the rack the top of the shelf is: the foot of the cards.
const SHELF := 130.0
const POSTS: Array[float] = [228.0, 428.0, 1018.0]
## The raised panel at the end of the counter, behind the buttons.
const END_PANEL := Rect2(1024, 18, 124, 146)

const INK := Color("160c08")
const SEAM := Color("1e100a")
const FRAME := Color("4a2e1a")
const FRAME_LIGHT := Color("6b4526")
const FRAME_DARK := Color("2e1b0e")
const SHELF_TOP := Color("a06e3c")
const SHELF_FRONT := Color("6a4324")
const FELT := Color("1f3a2c")
const FELT_LIGHT := Color("2a4c3a")
const FELT_DARK := Color("12241b")
const BRASS_DARK := Color("7d5616")

## The wood, darkest to lightest: the tones of Transition.WOOD.
const WOOD: Array[Color] = [
	Color(0.086, 0.047, 0.031), Color(0.118, 0.063, 0.039), Color(0.165, 0.086, 0.051),
	Color(0.200, 0.110, 0.071), Color(0.231, 0.133, 0.086), Color(0.290, 0.180, 0.102),
	Color(0.400, 0.260, 0.145),
]
## The felt, darkest to lightest; FELT is the fourth.
const NAP: Array[Color] = [
	Color("08130d"), Color("0f1f17"), Color("16291f"), Color("1f3a2c"), Color("2a4c3a"), Color("386150"),
]
## Brass, dark to glint, lit and unlit.
const BRASS_ON: Array[Color] = [Color("7d5616"), Color("b48c2f"), Color("e6bc4c"), Color("f5d983"), Color("fff4cf")]
const BRASS_OFF: Array[Color] = [Color("5a3d10"), Color("876823"), Color("ad8d39"), Color("c4a660"), Color("dccb9b")]
## The inlay of the rail on someone else's turn.
const INLAY_OFF: Array[Color] = [Color("5e4628"), Color("8a6a3a"), Color("a88552")]
## Planks of the counter front, in cells.
const PLANK := 9
## How far apart the knots of a plank may be, in cells.
const KNOT_SPAN := 45
## Ordered dithering, 4 × 4.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## The player's turn: the inlay of the rail and the nameplate light up.
var active := false:
	set(value):
		if active != value:
			active = value
			queue_redraw()
## How many inventory sockets the counter has.
var sockets := 0:
	set(value):
		if sockets != value:
			sockets = value
			queue_redraw()

## Pictures already painted, by look, and the bare wood, by size.
static var _pictures: Dictionary = {}
static var _woods: Dictionary = {}

var _img: Image
var _brass: Array[Color]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var cells := Vector2i(ceili(size.x / PX), ceili(size.y / PX))
	if cells.x <= 0 or cells.y <= 0:
		return
	# The counter throws a shadow on the table behind it.
	for row in 4:
		draw_rect(Rect2(0, -PX * (row + 1), size.x, PX), Color(0, 0, 0, 0.4 - row * 0.1))
	var key := "%d,%d,%d,%s" % [cells.x, cells.y, sockets, active]
	if not _pictures.has(key):
		_pictures[key] = ImageTexture.create_from_image(_paint(cells))
	draw_texture_rect(_pictures[key], Rect2(Vector2.ZERO, Vector2(cells) * PX), false)


# === the picture ==============================================================

func _paint(cells: Vector2i) -> Image:
	_img = _wood(cells).duplicate()
	_brass = BRASS_ON if active else BRASS_OFF
	_raised(_cells(END_PANEL))
	_plate(_cells(PLATE))
	_sunk(_cells(LEDGER))
	_ledger(_cells(LEDGER))
	for index in sockets:
		_socket(_cells(Rect2(SOCKETS_AT + Vector2(index * SOCKET_STEP, 0), SOCKET)))
	_mat(_cells(MAT))
	_rack(_cells(RACK))
	for x: float in POSTS:
		_post(int(x / PX), cells.y)
	_rail(cells.x)
	var picture := _img
	_img = null
	return picture


## The front of the counter: upright planks with their grain, under the lamp.
static func _wood(cells: Vector2i) -> Image:
	if _woods.has(cells):
		return _woods[cells]
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var middle := cells.x / 2.0
	for y in cells.y:
		for x in cells.x:
			var n := x / PLANK
			var across := x - n * PLANK
			var level := _grain(across, y, n * 3)
			if across == 0:
				level = 0
			elif across == 1:
				level += 1
			elif across == PLANK - 1:
				level -= 1
			# The lamp hangs over the middle: lighter up there, darker to the
			# floor and the ends, in dithered steps.
			var light := 0.55 - float(y) / cells.y * 1.1 - absf(x - middle) / middle * 0.45
			level += floori(light + _bayer(x, y))
			image.set_pixel(x, y, WOOD[clampi(level, 0, 6)])
	_woods[cells] = image
	return image


## The tone of plank `id` at (x, y), `x` across the plank: Transition.WOOD's grain.
static func _grain(x: int, y: int, id: int) -> int:
	var level := 3 + floori(_hash(id, 3) * 2.0)
	# A knot now and then, and the grain goes round it.
	var stretch := floori(float(y) / KNOT_SPAN)
	var knot := Vector2(2 + floorf(_hash(id, stretch) * (PLANK - 4)),
			stretch * KNOT_SPAN + 6 + floorf(_hash(stretch + 7, id) * (KNOT_SPAN - 12)))
	var off := (Vector2(x, y) - knot) * Vector2(1.0, 0.45)
	var ring := off.length() if _hash(id + 13, stretch + 5) < 0.15 else 99.0
	var along := x - int(signf(off.x) * floorf(3.0 * exp(-ring * ring / 40.0) + 0.5))
	along += floori(sin(y * 0.05 + id * 5.0) * 1.2 + 0.5)
	# Streaks, each broken into pieces of its own length.
	var streak := _hash(along, id + 1)
	var piece := _hash(along + id * 31, floori((y + streak * 90.0) / (26.0 + streak * 44.0)))
	if streak < 0.24 and piece < 0.75:
		level -= 1
	elif streak > 0.84 and piece < 0.6:
		level += 1
	# Worn patches, dithered.
	var wear := _soft(x * 0.11 + id * 17.0, y * 0.035 + id * 17.0)
	if (x + y) % 2 == 0:
		level += 1 if wear > 0.68 else (-1 if wear < 0.27 else 0)
	if ring < 1.6:
		level = 1
	elif ring < 2.7:
		level = 2
	elif ring < 3.6:
		level = 5
	elif ring < 4.5:
		level = 2
	return level


## A raised panel of the wainscot: a bevelled frame round a field of wood a
## little nearer the light.
func _raised(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var inner := mini(mini(x - r.position.x, r.end.x - 1 - x), mini(y - r.position.y, r.end.y - 1 - y))
			var c := _at(x, y)
			if inner == 0:
				c = FRAME_DARK
			elif inner == 1:
				var lit := x - r.position.x == 1 or y - r.position.y == 1
				c = FRAME_LIGHT if lit else SEAM
			elif inner == 2:
				c = FRAME
			elif inner == 3:
				var lit := x - r.position.x == 3 or y - r.position.y == 3
				c = c.darkened(0.45) if lit else c.lightened(0.12)
			elif _bayer(x, y) < 0.5:
				c = c.lightened(0.06)
			_put(x, y, c)


## The nameplate: dark enamel in a bevelled brass rim, screwed on at both ends.
func _plate(r: Rect2i) -> void:
	_shadow(Rect2i(r.position + Vector2i(1, 1), r.size), 0.45)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var top := y == r.position.y
			var left := x == r.position.x
			var bottom := y == r.end.y - 1
			var right := x == r.end.x - 1
			if top or left:
				_put(x, y, _brass[4] if top and left else _brass[3])
			elif bottom or right:
				_put(x, y, _brass[0])
			elif y == r.position.y + 1 or x == r.position.x + 1:
				_put(x, y, _brass[0].darkened(0.3))
			elif y == r.end.y - 2 or x == r.end.x - 2:
				_put(x, y, _brass[1])
			else:
				# The enamel, with a soft sheen across its lower half.
				var c := INK
				if y > r.position.y + r.size.y / 2 and _bayer(x, y) < 0.25:
					c = Color("24140d")
				_put(x, y, c)
	# A glint runs along the top of the rim.
	for x in range(r.position.x + 4, r.end.x - 4, 23):
		_put(x, r.position.y, _brass[4])
	for x: int in [r.position.x + 2, r.end.x - 4]:
		_screw(x, r.position.y + r.size.y / 2 - 1)


## The ledger strip: a groove cut into the wood, lined with dark leather.
func _ledger(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Color("1b0f09")
			if _hash(x, y + 91) < 0.08:
				c = Color("231409")
			_put(x, y, c)
	_inner_shadow(r, 2)
	# A tooled line along the leather, a cell in from the edges.
	for x in range(r.position.x + 2, r.end.x - 2):
		if x % 2 == 0:
			_put(x, r.end.y - 2, Color("3a2414"))


## A place for one item: a felt-lined socket with brass corners.
func _socket(r: Rect2i) -> void:
	_sunk(r)
	_felt(r, 0)
	for corner in 4:
		var way := Vector2i(-1 if corner % 2 == 1 else 1, -1 if corner >= 2 else 1)
		var at := Vector2i(r.end.x - 1 if way.x < 0 else r.position.x, r.end.y - 1 if way.y < 0 else r.position.y)
		for step in 4:
			var tone: Color = _brass[3] if step == 0 else (_brass[0] if step == 3 else _brass[2])
			_put(at.x + step * way.x, at.y, tone)
			_put(at.x, at.y + step * way.y, tone)
		# The bracket's shadow on the felt, along the inside of its arms.
		for step in range(2, 4):
			_dim(at.x + step * way.x, at.y + way.y, 0.35)
			_dim(at.x + way.x, at.y + step * way.y, 0.35)
		_put(at.x + way.x, at.y + way.y, _brass[1])


## The mat of the hand: felt with a stitched border.
func _mat(r: Rect2i) -> void:
	_sunk(r)
	_felt(r, 1)
	var seam := r.grow(-3)
	var x := seam.position.x
	while x < seam.end.x - 1:
		for y: int in [seam.position.y, seam.end.y - 1]:
			_stitch(x, y, Vector2i(1, 0))
		x += 4
	var y := seam.position.y + 2
	while y < seam.end.y - 2:
		for sx: int in [seam.position.x, seam.end.x - 1]:
			_stitch(sx, y, Vector2i(0, 1))
		y += 4


## One stitch of thread, two cells along `way`, with its hole in the felt.
func _stitch(x: int, y: int, way: Vector2i) -> void:
	_put(x, y, NAP[5])
	_put(x + way.x, y + way.y, NAP[4])
	_put(x + way.x * 2, y + way.y * 2, NAP[0])


## The rack of the other characters: a niche with a shelf near its foot,
## which the cards stand on (their names are on the cards themselves).
func _rack(r: Rect2i) -> void:
	_sunk(r)
	# The back of the niche is the same wood, deep in the shade.
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var deep := 0.5
			var down := y - r.position.y
			if down < 5:
				deep += 0.08 * (5 - down) if _bayer(x, y) < 0.75 else 0.0
			if x - r.position.x < 3:
				deep += 0.12
			_put(x, y, _at(x, y).darkened(deep))
	var top := r.position.y + int(SHELF / PX)
	for x in range(r.position.x, r.end.x):
		var lit := _hash(x, 17) < 0.12
		_put(x, top - 1, _at(x, top - 1).darkened(0.25))
		_put(x, top, SHELF_TOP.lightened(0.25) if lit else SHELF_TOP)
		var grain := _hash(x / 3, 29) < 0.3
		_put(x, top + 1, SHELF_FRONT.darkened(0.15) if grain else SHELF_FRONT)
		_put(x, top + 2, Color("4a2e18"))
		for y in range(top + 3, r.end.y):
			_put(x, y, _at(x, y).darkened(0.55 if y == top + 3 else 0.35))
	# Brackets hold the shelf up, under its lip.
	for x in range(r.position.x + 30, r.end.x - 10, 72):
		for y in range(top + 3, mini(top + 6, r.end.y)):
			_put(x, y, FRAME_LIGHT if y == top + 3 else FRAME)
			_put(x + 1, y, FRAME_DARK)


## A post between two sections, from under the rail to the floor, with a
## capital under the rail and two rivets.
func _post(c: int, rows: int) -> void:
	var rail := int(RAIL / PX)
	for y in range(rail, rows):
		_dim(c - 1, y, 0.35)
		_put(c, y, FRAME_LIGHT)
		_put(c + 1, y, FRAME if _hash(c, y / 3) > 0.2 else FRAME_DARK.lightened(0.1))
		_put(c + 2, y, FRAME_DARK)
	# The capital.
	for x in range(c - 1, c + 4):
		_put(x, rail, FRAME_LIGHT)
		_put(x, rail + 1, FRAME)
		_put(x, rail + 2, FRAME_DARK)
	_dim(c - 2, rail + 1, 0.35)
	for x in range(c - 1, c + 4):
		_dim(x, rail + 3, 0.3)
	for y: int in [rail + 5, rows - 7]:
		_rivet(c, y)


## The rail: a rounded moulding across the top, with the inlay under it.
func _rail(cols: int) -> void:
	var inlay: Array[Color] = INLAY_OFF
	if active:
		inlay = [_brass[1], _brass[2], _brass[4]]
	for x in cols:
		_put(x, 0, FRAME_LIGHT.lightened(0.15) if _hash(x / 5, 3) < 0.15 else FRAME_LIGHT)
		_put(x, 1, FRAME.lightened(0.06) if _hash(x / 4, 5) < 0.3 else FRAME)
		_put(x, 2, FRAME_DARK)
		_put(x, 3, inlay[2] if x % 29 == 7 else (inlay[1] if x % 2 == 0 else inlay[0]))
		_dim(x, 4, 0.4)
		if active:
			# The light of the turn spills down the planks, dithered.
			for row in 4:
				if _bayer(x, 5 + row) < 0.5 - row * 0.12:
					_put(x, 5 + row, _at(x, 5 + row).lerp(UI.GOLD, 0.22))


# --- pieces ------------------------------------------------------------------

## A hollow in the wood, lit from the top left: a dark rim, and a glint along
## the far edges where the light catches the lip.
func _sunk(r: Rect2i) -> void:
	var rim := r.grow(1)
	for x in range(rim.position.x, rim.end.x):
		_put(x, rim.position.y, FRAME_DARK)
		_put(x, rim.end.y - 1, FRAME_LIGHT)
	for y in range(rim.position.y, rim.end.y - 1):
		_put(rim.position.x, y, FRAME_DARK)
		_put(rim.end.x - 1, y, FRAME_LIGHT)


## Felt in `r`, its nap speckled and darker towards the edges, with the
## shadow of the lip along the top and the left. `vary` varies the nap.
func _felt(r: Rect2i, vary: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var level := 3
			var edge := mini(mini(x - r.position.x, r.end.x - 1 - x), mini(y - r.position.y, r.end.y - 1 - y))
			if edge < 1:
				level -= 2
			elif edge < 3 and _bayer(x, y) < 0.5:
				level -= 1
			if y - r.position.y < 2 or x - r.position.x < 2:
				level -= 1
			var nap := _soft(x * 0.23 + vary * 40.0, y * 0.23)
			if nap > 0.66 and (x + y) % 2 == 0:
				level += 1
			elif nap < 0.3 and (x + y) % 2 == 0:
				level -= 1
			var speck := _hash(x + vary * 211, y)
			if speck < 0.05:
				level += 1
			elif speck > 0.96:
				level -= 1
			_put(x, y, NAP[clampi(level, 0, 5)])


## The shadow of the rim inside a hollow, `depth` cells deep, dithered.
func _inner_shadow(r: Rect2i, depth: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var from := mini(x - r.position.x, y - r.position.y)
			if from < depth and (from == 0 or _bayer(x, y) < 0.5):
				_dim(x, y, 0.4)


func _rivet(x: int, y: int) -> void:
	_dim(x + 1, y + 2, 0.4)
	_dim(x + 2, y + 1, 0.4)
	_put(x, y, _brass[4])
	_put(x + 1, y, _brass[2])
	_put(x, y + 1, _brass[2])
	_put(x + 1, y + 1, _brass[0])


## A screw head: a rivet with its slot.
func _screw(x: int, y: int) -> void:
	_rivet(x, y)
	_put(x + 1, y, _brass[1])
	_put(x, y + 1, _brass[1])


func _shadow(r: Rect2i, amount: float) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_dim(x, y, amount)


# --- cells ---------------------------------------------------------------------

func _cells(rect: Rect2) -> Rect2i:
	return Rect2i(Vector2i((rect.position / PX).floor()), Vector2i((rect.size / PX).floor()))


func _put(x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
		_img.set_pixel(x, y, color)


func _at(x: int, y: int) -> Color:
	if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
		return _img.get_pixel(x, y)
	return INK


func _dim(x: int, y: int, amount: float) -> void:
	_put(x, y, _at(x, y).darkened(amount))


static func _bayer(x: int, y: int) -> float:
	return BAYER[(y % 4) * 4 + x % 4] / 16.0


static func _hash(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


static func _soft(x: float, y: float) -> float:
	var i := Vector2i(floori(x), floori(y))
	var f := Vector2(x - i.x, y - i.y)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var top := lerpf(_hash(i.x, i.y), _hash(i.x + 1, i.y), f.x)
	var bottom := lerpf(_hash(i.x, i.y + 1), _hash(i.x + 1, i.y + 1), f.x)
	return lerpf(top, bottom, f.y)
