extends "res://scripts/ui/hero_desk.gd"
## The shop's backdrop: a display case built into the saloon wall, made in the
## same workshop as the player's counter (hero_desk.gd, whose brushes it
## borrows): a beam across the top carries the titles, the goods stand on a
## shelf in front of a back wall of upright planks, and the deck lies on a
## stitched felt tray at the right end. Everything is under
## the lamp, in dithered steps, and the brass and the inlay light up when the
## shop is pinned open.
##
## The case folds and opens, anchored to its right edge so the tray never
## moves. It is painted once at its full width (`span`) and drawn as the right
## part of that picture, with the left end of the frame (`_cap`) drawn on top
## wherever the left edge happens to be; a picture is kept for each look.
##
## The pieces that stand in front of the case are inner classes: the lever
## of the reroll (`Lever`) and the sign hung over it (`Sign`). No class name: preload it (see table.gd).

const HeroDesk := preload("res://scripts/ui/hero_desk.gd")

## Height of the beam the titles are painted on, and width of the frame on
## the other three sides.
const BEAM := 16.0
const EDGE := 6.0
## A corner bracket, as seen in the top left corner: brass, with a rivet.
const BRACKET := [
	"######",
	"#o####",
	"##+...",
	"##....",
	"##....",
	"##....",
]

## Clicked to stay open: the brass and the inlay of the frame light up.
var pinned := false:
	set(value):
		pinned = value
		queue_redraw()
## Where the top of each shelf is, from the top of the case.
var shelves: Array[float] = []:
	set(value):
		shelves = value
		queue_redraw()
## Posts between groups of goods, each as far from the right edge (the edge
## that stays put).
var posts: Array = []:
	set(value):
		posts = value
		queue_redraw()
## How much of the right end is the tray of the deck.
var tray := 0.0:
	set(value):
		tray = value
		queue_redraw()
## The width of the case open; 0 is whatever width it has.
var span := 0.0:
	set(value):
		span = value
		queue_redraw()

## The pictures already painted, by look; the bare back wall, by size.
var _looks: Dictionary = {}
static var _walls: Dictionary = {}


func _init() -> void:
	# Unlike the counter, the case takes the mouse: it opens and pins.
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var full := maxf(span, size.x)
	var cells := Vector2i(ceili(full / PX), ceili(size.y / PX))
	var shown := mini(ceili(size.x / PX), cells.x)
	if cells.y <= 0 or shown <= 0:
		return
	# The case throws a shadow on the table to its left and below it.
	for step in 3:
		var fade := 0.32 - step * 0.1
		draw_rect(Rect2(-PX * (step + 1), PX * 2.0, PX, size.y), Color(0, 0, 0, fade))
		draw_rect(Rect2(-PX * step, size.y + PX * step, size.x + PX * step, PX), Color(0, 0, 0, fade))
	var key := "%s|%s|%s|%s|%s" % [cells, pinned, shelves, posts, tray]
	if not _looks.has(key):
		_looks[key] = [ImageTexture.create_from_image(_paint_case(cells)), ImageTexture.create_from_image(_paint_cap(cells.y))]
	var pictures: Array = _looks[key]
	var drawn := Vector2(shown * PX, size.y)
	draw_texture_rect_region(pictures[0], Rect2(Vector2(size.x - drawn.x, 0), drawn),
			Rect2(cells.x - shown, 0, shown, cells.y))
	var cap: Texture2D = pictures[1]
	draw_texture_rect(cap, Rect2(Vector2.ZERO, Vector2(cap.get_size()) * PX), false)


# === the picture ==============================================================

func _paint_case(cells: Vector2i) -> Image:
	_img = _wall(cells).duplicate()
	_brass = BRASS_ON if pinned else BRASS_OFF
	var beam := int(BEAM / PX)
	var shelf_end := cells.x - 3
	if tray > 0.0:
		shelf_end = cells.x - int(tray / PX) - 1
		_mat(Rect2i(cells.x - int(tray / PX) + 3, beam + 1, int(tray / PX) - 7, cells.y - beam - 5))
	var last := -1
	for top: float in shelves:
		var row := int(top / PX)
		_shelf(3, shelf_end, row)
		last = maxi(last, row)
	if last >= 0:
		# Under the last shelf it is the front of the counter, in the shade:
		# the prices stand out on it.
		for y in range(last + 5, cells.y - 3):
			for x in range(3, shelf_end):
				var deep := 0.3 if _bayer(x, y) < 0.75 else 0.18
				_dim(x, y, deep)
	for at: float in posts:
		_column(cells.x - int(at / PX), cells.y)
	if tray > 0.0:
		_column(shelf_end, cells.y)
	_beam(cells.x)
	# The moulding down the right side and along the foot.
	for y in range(beam, cells.y):
		_put(cells.x - 3, y, _inlay(y))
		_put(cells.x - 2, y, FRAME)
		_put(cells.x - 1, y, FRAME_DARK)
	for x in cells.x:
		_put(x, cells.y - 3, _inlay(x))
		_put(x, cells.y - 2, FRAME if _hash(x / 4, 41) > 0.25 else FRAME_DARK.lightened(0.08))
		_put(x, cells.y - 1, FRAME_DARK)
	_corner(Vector2i(cells.x - 1, 0), Vector2i(-1, 1))
	_corner(Vector2i(cells.x - 1, cells.y - 1), Vector2i(-1, -1))
	var picture := _img
	_img = null
	return picture


## The left end of the frame, drawn over the picture wherever the left edge
## is: the moulding and the two corner brackets. The rest is clear.
func _paint_cap(rows: int) -> Image:
	_img = Image.create(BRACKET[0].length(), rows, false, Image.FORMAT_RGBA8)
	_brass = BRASS_ON if pinned else BRASS_OFF
	var beam := int(BEAM / PX)
	for y in range(beam, rows):
		_put(0, y, FRAME_LIGHT)
		_put(1, y, FRAME if _hash(y / 3, 43) > 0.2 else FRAME_DARK.lightened(0.1))
		_put(2, y, _inlay(y))
	for y in beam:
		_put(0, y, FRAME_LIGHT if y > 0 else FRAME_LIGHT.lightened(0.15))
	for x in 3:
		_put(x, rows - 3, _inlay(x))
		_put(x, rows - 2, FRAME)
		_put(x, rows - 1, FRAME_DARK)
	_corner(Vector2i(0, 0), Vector2i(1, 1))
	_corner(Vector2i(0, rows - 1), Vector2i(1, -1))
	var picture := _img
	_img = null
	return picture


## The back wall: upright planks counted from the right (so that they stay
## put while the left edge slides), deep inside the case, under the lamp and
## in the shadow of the beam.
static func _wall(cells: Vector2i) -> Image:
	if _walls.has(cells):
		return _walls[cells]
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var beam := int(BEAM / PX)
	for y in cells.y:
		for x in cells.x:
			var from_right := cells.x - 1 - x
			var n := from_right / PLANK
			var across := PLANK - 1 - (from_right - n * PLANK)
			var level := _grain(across, y, n * 5 + 2) - 1
			if across == 0:
				level = 0
			elif across == 1:
				level += 1
			# The lamp is above: the light falls down the wall and dies
			# towards the foot; the beam throws a band of shadow under it.
			var light := 0.35 - float(y - beam) / (cells.y - beam) * 1.3
			var under := y - beam
			if under >= 0 and under < 4:
				light -= 1.0 - under * 0.25
			level += floori(light + _bayer(x, y))
			image.set_pixel(x, y, WOOD[clampi(level, 0, 6)])
	_walls[cells] = image
	return image


## The beam across the top: a plank laid flat, nearest the lamp, rounded on
## top, with the inlay along its foot and its shadow on the wall.
func _beam(cols: int) -> void:
	var beam := int(BEAM / PX)
	for x in cols:
		_put(x, 0, FRAME_LIGHT.lightened(0.18) if _hash(x / 6, 7) < 0.2 else FRAME_LIGHT)
		for y in range(1, beam - 2):
			var level := _grain(y + 2, x, 991) + 1
			if y == 1:
				level += 1
			elif y == beam - 3:
				level -= 1
			_put(x, y, WOOD[clampi(level, 0, 6)])
		_put(x, beam - 2, FRAME_DARK)
		_put(x, beam - 1, _inlay(x))
		_dim(x, beam, 0.45)
		if _bayer(x, beam + 1) < 0.5:
			_dim(x, beam + 1, 0.3)
	# A glint runs along the inlay when the brass is lit.
	if pinned:
		for x in range(9, cols, 37):
			_put(x, beam - 1, _brass[4])


## The inlay at step `i` along it: brass when pinned, dull otherwise.
func _inlay(i: int) -> Color:
	if pinned:
		return _brass[4] if i % 29 == 7 else (_brass[2] if i % 2 == 0 else _brass[1])
	return INLAY_OFF[2] if i % 29 == 7 else (INLAY_OFF[1] if i % 2 == 0 else INLAY_OFF[0])


## A shelf from `from` to `to` (cells) whose top is at `row`: a lit edge, a
## front with its grain, a dark lip, its shadow on the wall, and brass
## brackets under it.
func _shelf(from: int, to: int, row: int) -> void:
	for x in range(from, to):
		_dim(x, row - 1, 0.2)
		var lit := _hash(x, row + 17) < 0.1
		_put(x, row, SHELF_TOP.lightened(0.28) if lit else SHELF_TOP)
		var grain := _hash(x / 3, row + 29) < 0.3
		_put(x, row + 1, SHELF_FRONT.darkened(0.15) if grain else SHELF_FRONT)
		_put(x, row + 2, Color("4a2e18"))
		_dim(x, row + 3, 0.55)
		if _bayer(x, row + 4) < 0.6:
			_dim(x, row + 4, 0.35)
	# Brackets hold it up, counted from the right like the planks.
	var x := to - 8
	while x > from + 4:
		for step in 3:
			_put(x - step, row + 3 + step, _brass[1] if step == 0 else _brass[0])
			_put(x - step + 1, row + 3 + step, _brass[2])
		_put(x + 1, row + 3, _brass[3])
		x -= 36


## A post from under the beam to the foot, with a capital and two rivets.
func _column(c: int, rows: int) -> void:
	var beam := int(BEAM / PX)
	for y in range(beam, rows - 3):
		_dim(c - 1, y, 0.35)
		_put(c, y, FRAME_LIGHT)
		_put(c + 1, y, FRAME if _hash(c, y / 3) > 0.2 else FRAME_DARK.lightened(0.1))
		_put(c + 2, y, FRAME_DARK)
	for x in range(c - 1, c + 4):
		_put(x, beam, FRAME_LIGHT)
		_put(x, beam + 1, FRAME)
		_put(x, beam + 2, FRAME_DARK)
		_dim(x, beam + 3, 0.3)
	for y: int in [beam + 5, rows - 9]:
		_rivet(c, y)


## A corner bracket with its corner at the cell `at`, opening towards `way`.
func _corner(at: Vector2i, way: Vector2i) -> void:
	for y: int in BRACKET.size():
		var row: String = BRACKET[y]
		for x: int in row.length():
			var mark := row[x]
			if mark == ".":
				continue
			var c := at + Vector2i(x * way.x, y * way.y)
			var tone: Color = _brass[2]
			if mark == "o":
				tone = _brass[4]
			elif mark == "+":
				tone = _brass[0]
			elif x == 0 or y == 0:
				# The edge facing the lamp catches it; the others are in shade.
				tone = _brass[3] if (y == 0 and way.y > 0) or (x == 0 and way.x > 0) else _brass[0]
			_put(c.x, c.y, tone)


# === the pieces in front of the case ==========================================

## The lever of the reroll: a brass rod with a red ball on a brass boss,
## pulled down towards whoever is looking (`pull`), like the handle of a
## slot machine. It leans a little under the mouse and while pressed.
class Lever extends Button:
	const PIVOT := Vector2(26, 28)
	const LENGTH := 20.0
	const KNOB := 7.0
	const RED: Array[Color] = [Color("3a0b0b"), Color("7c1714"), Color("b3271d"), Color("e0503a"), Color("ffc2a8")]
	const DULL: Array[Color] = [Color("1e1210"), Color("3b2a26"), Color("564039"), Color("6e5750"), Color("8c7a70")]

	## How far it is pulled: 0 upright, 1 all the way down.
	var pull_amount := 0.0:
		set(value):
			pull_amount = value
			queue_redraw()
	var _pulling: Tween

	func _init() -> void:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		size = Vector2(48, 48)
		pivot_offset = size / 2.0
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for sig: Signal in [mouse_entered, mouse_exited, button_down, button_up]:
			sig.connect(queue_redraw)

	## All the way down with a clunk, then back up on its spring.
	func pull(pace := 1.0) -> void:
		if _pulling != null:
			_pulling.kill()
		_pulling = create_tween()
		_pulling.tween_property(self, "pull_amount", 1.0, 0.2 / pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pulling.tween_interval(0.12 / pace)
		_pulling.tween_property(self, "pull_amount", 0.0, 0.55 / pace).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var lean := pull_amount
		if pull_amount == 0.0 and not disabled:
			if is_pressed():
				lean = 0.22
			elif is_hovered():
				lean = 0.1
		var angle := lean * PI
		var brass: Array[Color] = HeroDesk.BRASS_ON if (is_hovered() and not disabled) else HeroDesk.BRASS_OFF
		var red: Array[Color] = DULL if disabled else RED
		# The boss on the wall: a plate with two screws, and the hub.
		var plate := Rect2(PIVOT - Vector2(8, 13), Vector2(16, 26))
		draw_rect(Rect2(plate.position + Vector2(2, 2), plate.size), Color(0, 0, 0, 0.4))
		draw_rect(plate, brass[0])
		draw_rect(plate.grow(-2), brass[2])
		draw_rect(Rect2(plate.position + Vector2(2, 2), Vector2(plate.size.x - 4, 2)), brass[3])
		for y: float in [plate.position.y + 3, plate.end.y - 7]:
			draw_rect(Rect2(PIVOT.x - 2, y, 4, 4), brass[1])
			draw_rect(Rect2(PIVOT.x - 2, y, 2, 2), brass[4])
		draw_rect(Rect2(PIVOT - Vector2(5, 5), Vector2(10, 10)), brass[0])
		draw_rect(Rect2(PIVOT - Vector2(3, 3), Vector2(6, 6)), brass[1])
		# The rod: it swings towards the eye, so it only shortens and lengthens.
		var tip := PIVOT + Vector2(0, -LENGTH * cos(angle))
		var top := minf(tip.y, PIVOT.y)
		var rod := Rect2(PIVOT.x - 2, snappedf(top, 2.0), 4, maxf(snappedf(absf(tip.y - PIVOT.y), 2.0), 2.0))
		draw_rect(rod, brass[1])
		draw_rect(Rect2(rod.position, Vector2(2, rod.size.y)), brass[3])
		# The knob, bigger as it comes nearer, lit from the top left.
		var r := KNOB * (1.0 + 0.4 * sin(angle))
		var cells := ceili(r / 2.0)
		for gy in range(-cells, cells):
			for gx in range(-cells, cells):
				var d := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * 2.0 / r
				var reach := d.length()
				if reach > 1.0:
					continue
				var lit := -d.dot(Vector2(0.55, 0.65).normalized()) * 0.8 + sqrt(maxf(0.0, 1.0 - reach * reach)) * 0.6
				var tone := 0
				if reach > 0.86:
					tone = 0
				elif lit > 0.95:
					tone = 4
				elif lit > 0.62:
					tone = 3
				elif lit > 0.2:
					tone = 2
				else:
					tone = 1
				draw_rect(Rect2(tip.snappedf(2.0) + Vector2(gx, gy) * 2.0, Vector2(2, 2)), red[tone])


## The sign of the shop: a board in a brass rim, hung by two chains from a
## wrought-iron bracket that stands on the left end of the beam. It goes
## wherever the left edge of the case goes, and swings with it: the faster
## the case opens or folds, the harder it swings.
class Sign extends Control:
	const PX := 2.0
	## Where the arm of the bracket is, above the beam.
	const ARM := -32.0
	const BOARD_TOP := -25.0
	const BOARD_HEIGHT := 18.0
	const SPRING := 55.0
	const DAMPING := 2.6
	## How hard the sign swings for each pixel per second the case changes speed.
	const INERTIA := 0.00016
	const IRON: Array[Color] = [Color("0d0a09"), Color("221c19"), Color("3a322d"), Color("5a5049")]

	var stall  # the ShopStall
	var board: Control
	var _label: Label
	var _spin := 0.0
	var _last := INF
	var _was := 0.0

	func _init(of, text: String) -> void:
		stall = of
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		board = Control.new()
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.draw.connect(_draw_board)
		add_child(board)
		_label = UI.label(text, 11, UI.GOLD, true)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(_label)
		_label.resized.connect(_fit)
		_fit()

	## The board is as wide as what is written on it.
	func _fit() -> void:
		var width := snappedf(_label.get_minimum_size().x + 22.0, PX * 2.0)
		board.size = Vector2(width, BOARD_HEIGHT)
		board.position = Vector2(8.0, BOARD_TOP)
		board.pivot_offset = Vector2(width / 2.0, ARM - BOARD_TOP)
		_label.position = Vector2(0, 0)
		_label.size = board.size
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		queue_redraw()

	func _process(delta: float) -> void:
		position.x = stall.position.x
		if delta <= 0.0:
			return
		var step := minf(delta, 1.0 / 30.0)
		var speed := 0.0 if _last == INF else (position.x - _last) / delta
		_last = position.x
		# The case lurches; the sign lags behind it.
		_spin -= (speed - _was) * INERTIA
		_was = speed
		if board.rotation == 0.0 and absf(_spin) < 0.02:
			_spin = 0.0
			return
		_spin += (-SPRING * board.rotation - DAMPING * _spin) * step
		board.rotation = clampf(board.rotation + _spin * step, -0.55, 0.55)
		if absf(board.rotation) < 0.002 and absf(_spin) < 0.02:
			board.rotation = 0.0
			_spin = 0.0
		queue_redraw()

	func _draw() -> void:
		# The bracket: an upright on the beam, the arm, and a curl under it.
		var post := 8.0
		var reach := board.position.x + board.size.x + 6.0
		draw_rect(Rect2(post - 2.0, ARM, 6.0, -ARM), IRON[0])
		draw_rect(Rect2(post, ARM, 2.0, -ARM), IRON[2])
		draw_rect(Rect2(post - 4.0, -2.0, 10.0, 4.0), IRON[1])
		draw_rect(Rect2(post - 4.0, -2.0, 10.0, 2.0), IRON[3])
		draw_rect(Rect2(post - 2.0, ARM - 2.0, reach - post + 2.0, 4.0), IRON[0])
		draw_rect(Rect2(post, ARM - 2.0, reach - post, 2.0), IRON[2])
		draw_rect(Rect2(reach, ARM - 4.0, 4.0, 4.0), IRON[1])
		draw_rect(Rect2(reach, ARM - 4.0, 2.0, 2.0), IRON[3])
		for step in 4:
			var curl := Vector2(post + 4.0 + step * 2.0, ARM + 8.0 - absf(step - 1.5) * 2.0)
			draw_rect(Rect2(curl, Vector2(2, 2)), IRON[1 if step % 2 == 0 else 2])
		# The chains, from the arm to the corners of the board as it swings.
		var turn := board.get_transform()
		for corner: float in [6.0, board.size.x - 6.0]:
			var hook := Vector2(board.position.x + corner, ARM + 2.0)
			var ring := turn * Vector2(corner, 0.0)
			var links := maxi(int(hook.distance_to(ring) / 3.0), 1)
			for i in links + 1:
				var at := hook.lerp(ring, float(i) / links).snappedf(1.0)
				draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), IRON[3] if i % 2 == 0 else IRON[1])

	func _draw_board() -> void:
		var s := board.size
		board.draw_rect(Rect2(Vector2(2, 2), s), Color(0, 0, 0, 0.4))
		var brass: Array[Color] = HeroDesk.BRASS_OFF
		board.draw_rect(Rect2(Vector2.ZERO, s), brass[0])
		board.draw_rect(Rect2(Vector2.ZERO, Vector2(s.x - PX, PX)), brass[3])
		board.draw_rect(Rect2(Vector2.ZERO, Vector2(PX, s.y - PX)), brass[2])
		# The board inside the rim: dark planks laid flat, with their grain.
		for y in range(1, int(s.y / PX) - 1):
			for x in range(1, int(s.x / PX) - 1):
				var level := HeroDesk._grain(y + 1, x, 613) - 1
				if y == 1:
					level -= 1
				board.draw_rect(Rect2(x * PX, y * PX, PX, PX), HeroDesk.WOOD[clampi(level, 0, 6)])
		for x: float in [PX * 2.0, s.x - PX * 4.0]:
			board.draw_rect(Rect2(x, s.y / 2.0 - PX, PX * 2.0, PX * 2.0), brass[1])
			board.draw_rect(Rect2(x, s.y / 2.0 - PX, PX, PX), brass[4])
