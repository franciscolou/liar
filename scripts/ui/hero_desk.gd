extends Control
## The backdrop of the HeroPanel: the player's side of the bar counter, drawn
## in the same blocks as the shop's display case (see shop_stall.gd). From the
## left: a brass nameplate over a ledger strip and the felt-lined sockets of
## the inventory, a felt mat the hand lies on, a rack where the other
## characters of the match stand on a shelf, and the end of the counter with
## the buttons. Posts with brass rivets part the sections. The inlay of the
## rail across the top lights up on the player's turn. No class name: preload
## it (see hero_panel.gd).

const PX := 2.0
## Height of the rail across the top, inlay included.
const RAIL := 8.0

# Where things are, for the HeroPanel to put its widgets on them.
const PLATE := Rect2(8, 12, 186, 26)
const LEDGER := Rect2(8, 41, 216, 26)
const SOCKET := Vector2(58, 58)
const SOCKET_STEP := 64.0
const SOCKETS_AT := Vector2(14, 106)
const MAT := Rect2(236, 12, 188, 154)
const RACK := Rect2(436, 26, 580, 138)
## How far down the rack the top of the shelf is: the foot of the cards.
const SHELF := 130.0
const POSTS: Array[float] = [228.0, 428.0, 1018.0]

const INK := Color("160c08")
const WALL: Array[Color] = [Color("3b2216"), Color("331c12")]
const SEAM := Color("1e100a")
const GRAIN := Color("2a160d")
const FRAME := Color("4a2e1a")
const FRAME_LIGHT := Color("6b4526")
const FRAME_DARK := Color("2e1b0e")
const SHELF_TOP := Color("a06e3c")
const SHELF_FRONT := Color("6a4324")
const FELT := Color("1f3a2c")
const FELT_LIGHT := Color("2a4c3a")
const FELT_DARK := Color("12241b")
const BRASS_DARK := Color("7d5616")

## The player's turn: the inlay of the rail and the nameplate light up.
var active := false:
	set(value):
		active = value
		queue_redraw()
## How many inventory sockets the counter has.
var sockets := 0:
	set(value):
		sockets = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var brass := UI.GOLD if active else UI.GOLD.darkened(0.25)
	var inlay := UI.GOLD if active else UI.BORDER

	# The counter throws a shadow on the table behind it.
	for row in 4:
		draw_rect(Rect2(0, -PX * (row + 1), w, PX), Color(0, 0, 0, 0.4 - row * 0.1))
	draw_rect(Rect2(0, 0, w, h), INK)

	# The front of the counter: upright planks, each with its own grain.
	var plank := 0
	var left := 0.0
	while left < w:
		var width := minf(18.0, w - left)
		draw_rect(Rect2(left, RAIL, width, h - RAIL), WALL[plank % 2])
		draw_rect(Rect2(left, RAIL, PX, h - RAIL), SEAM)
		for stroke in 3:
			var mark := plank * 7 + stroke * 13
			var x := left + 4.0 + (mark * 5 % 6) * PX
			var y := RAIL + 8.0 + (mark * 11 % 62) * PX
			if x < left + width:
				draw_rect(Rect2(x, y, PX, 6.0 + (mark % 4) * 4.0), GRAIN)
		left += width
		plank += 1
	# It gets darker towards the floor.
	for row in 5:
		draw_rect(Rect2(0, h - PX * (row + 1) * 2.0, w, PX * 2.0), Color(0, 0, 0, 0.3 - row * 0.06))

	_plate(PLATE, brass)
	_sunk(LEDGER, Color(INK, 0.8))
	for index in sockets:
		_socket(Rect2(SOCKETS_AT + Vector2(index * SOCKET_STEP, 0), SOCKET), brass)
	_mat(MAT)
	_rack(RACK)
	for x: float in POSTS:
		_post(x, h, brass)

	# The rail: a moulding across the top, with the inlay under it.
	draw_rect(Rect2(0, 0, w, RAIL - PX), FRAME)
	draw_rect(Rect2(0, 0, w, PX), FRAME_LIGHT)
	draw_rect(Rect2(0, RAIL - PX * 2.0, w, PX), FRAME_DARK)
	draw_rect(Rect2(0, RAIL - PX, w, PX), inlay)
	draw_rect(Rect2(0, RAIL, w, PX), Color(0, 0, 0, 0.4))
	if active:
		for row in 4:
			draw_rect(Rect2(0, RAIL + PX * row, w, PX), Color(UI.GOLD, 0.2 - row * 0.05))


## A hollow in the wood, lit from the top left: dark along the top and the
## left, a glint along the other two edges.
func _sunk(rect: Rect2, fill: Color) -> void:
	draw_rect(rect.grow(PX), FRAME_DARK)
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, PX)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(rect.position, Vector2(PX, rect.size.y)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(rect.position.x - PX, rect.end.y, rect.size.x + PX * 2.0, PX), FRAME_LIGHT)
	draw_rect(Rect2(rect.end.x, rect.position.y, PX, rect.size.y), FRAME_LIGHT)


## The nameplate: a dark plate in a brass rim, screwed on at both ends.
func _plate(rect: Rect2, brass: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(PX, PX * 2.0), rect.size), Color(0, 0, 0, 0.45))
	draw_rect(rect, BRASS_DARK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x - PX, rect.size.y - PX)), brass)
	draw_rect(rect.grow(-PX), INK)
	draw_rect(Rect2(rect.position + Vector2(PX, PX), Vector2(rect.size.x - PX * 2.0, PX)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(rect.position.x + PX, rect.end.y - PX * 2.0, rect.size.x - PX * 2.0, PX), Color(brass, 0.18))
	for x: float in [rect.position.x + PX * 2.0, rect.end.x - PX * 3.0]:
		_rivet(Vector2(x, rect.position.y + rect.size.y / 2.0 - PX / 2.0), brass)


## A place for one item: a felt-lined socket with brass corners.
func _socket(rect: Rect2, brass: Color) -> void:
	_sunk(rect, FELT_DARK)
	var felt := rect.grow(-PX * 2.0)
	draw_rect(felt, FELT)
	draw_rect(Rect2(felt.position, Vector2(felt.size.x, PX)), FELT_DARK)
	draw_rect(Rect2(felt.position, Vector2(PX, felt.size.y)), FELT_DARK)
	draw_rect(Rect2(felt.position.x + PX, felt.end.y - PX, felt.size.x - PX, PX), FELT_LIGHT)
	draw_rect(Rect2(felt.end.x - PX, felt.position.y + PX, PX, felt.size.y - PX), FELT_LIGHT)
	for corner in 4:
		var way := Vector2(-1 if corner % 2 == 1 else 1, -1 if corner >= 2 else 1)
		var at := Vector2(rect.end.x if way.x < 0.0 else rect.position.x, rect.end.y if way.y < 0.0 else rect.position.y)
		for step in 3:
			_cell(at, way, Vector2(step, 0), BRASS_DARK if step == 2 else brass)
			_cell(at, way, Vector2(0, step), BRASS_DARK if step == 2 else brass)


## The mat of the hand: felt with a stitched border.
func _mat(rect: Rect2) -> void:
	_sunk(rect, FELT)
	draw_rect(Rect2(rect.position.x + PX, rect.end.y - PX, rect.size.x - PX, PX), FELT_LIGHT)
	draw_rect(Rect2(rect.end.x - PX, rect.position.y + PX, PX, rect.size.y - PX), FELT_LIGHT)
	var seam := rect.grow(-PX * 3.0)
	var x := seam.position.x
	while x < seam.end.x - PX:
		draw_rect(Rect2(x, seam.position.y, PX * 2.0, PX), FELT_LIGHT)
		draw_rect(Rect2(x, seam.end.y - PX, PX * 2.0, PX), FELT_LIGHT)
		x += PX * 4.0
	var y := seam.position.y + PX * 2.0
	while y < seam.end.y - PX * 2.0:
		draw_rect(Rect2(seam.position.x, y, PX, PX * 2.0), FELT_LIGHT)
		draw_rect(Rect2(seam.end.x - PX, y, PX, PX * 2.0), FELT_LIGHT)
		y += PX * 4.0


## The rack of the other characters: a niche with a shelf near its foot,
## which the cards stand on (their names are on the cards themselves).
func _rack(rect: Rect2) -> void:
	_sunk(rect, Color(0, 0, 0, 0.0))
	draw_rect(rect, Color(0, 0, 0, 0.2))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, PX * 2.0)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(rect.position, Vector2(PX, rect.size.y)), Color(0, 0, 0, 0.4))
	var top := rect.position.y + SHELF
	draw_rect(Rect2(rect.position.x, top, rect.size.x, PX), SHELF_TOP)
	draw_rect(Rect2(rect.position.x, top + PX, rect.size.x, PX), SHELF_FRONT)
	draw_rect(Rect2(rect.position.x, top + PX * 2.0, rect.size.x, PX), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(rect.position.x, top + PX * 3.0, rect.size.x, PX), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(rect.position.x, top + PX * 2.0, rect.size.x, rect.end.y - top - PX * 2.0), Color(0, 0, 0, 0.34))


## A post between two sections, from under the rail to the floor.
func _post(x: float, h: float, brass: Color) -> void:
	draw_rect(Rect2(x - PX, RAIL, PX, h - RAIL), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(x, RAIL, PX * 2.0, h - RAIL), FRAME)
	draw_rect(Rect2(x, RAIL, PX, h - RAIL), FRAME_LIGHT)
	draw_rect(Rect2(x + PX * 2.0, RAIL, PX, h - RAIL), FRAME_DARK)
	for y: float in [RAIL + 8.0, h - 14.0]:
		_rivet(Vector2(x, y), brass)


func _rivet(at: Vector2, brass: Color) -> void:
	draw_rect(Rect2(at, Vector2(PX * 2.0, PX * 2.0)), BRASS_DARK)
	draw_rect(Rect2(at, Vector2(PX, PX)), UI.CREAM)
	draw_rect(Rect2(at + Vector2(PX, 0), Vector2(PX, PX)), brass)
	draw_rect(Rect2(at + Vector2(0, PX), Vector2(PX, PX)), brass)


## One pixel of a corner at `at` that opens towards `way`.
func _cell(at: Vector2, way: Vector2, step: Vector2, color: Color) -> void:
	var cell := at + step * PX * way
	cell -= Vector2(PX if way.x < 0.0 else 0.0, PX if way.y < 0.0 else 0.0)
	draw_rect(Rect2(cell, Vector2(PX, PX)), color)
