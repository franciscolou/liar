extends Control
## What a Voodoo doll does to whoever carries it (Puppet Strings): not a
## menu. The lights go down to purple, the doll hangs in the middle of the
## table, awake, and three choices hang from it on strings, one for each thing
## it can do (hurt, take coins, take an item): a picture, a name and a line,
## with nothing round them, bobbing a little where they are. The one the
## player is on pulls its string taut and a purple frame lights up round it,
## never the same shape two moments running, and the doll jerks on it. A
## choice the doll can't make there (no coins to take, no item, a full
## inventory) still hangs there, its string cut, gone grey under a padlock,
## with the reason in red. A click on a choice picks it.
##
## Options: [{label, description, does, disabled, reason}] (see voodooist.gd).
## No class name: preload it.

signal picked(index: int)
## A click on a tag that can't be picked.
signal refused

const VoodooDoll := preload("res://scripts/ui/voodoo_doll.gd")

const SIZE := Vector2(1152, 648)
const PX := 2.0
const VEIL := Color(0.04, 0.01, 0.06, 0.86)
const STRING := Color("b98ae0")
const STRING_LIT := Color("f0dcff")
const STRING_DEAD := Color("5c5560")
## Where the doll hangs (the point it sits on) and how big it is drawn.
const DOLL_AT := Vector2(576, 236)
const DOLL_SCALE := 2.2
## The tags: their size, the gap between them and the top of the row.
const TAG := Vector2(170, 196)
const TAG_GAP := 26.0
const TAG_TOP := 296.0
## Seconds the tags take to show, and how much later each starts.
const SHOW := 0.3
const SHOW_STAGGER := 0.07

var _tags: Array[Tag] = []
var _doll: VoodooDoll
var _time := 0.0
var _hovered := -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(d: Decision) -> void:
	var veil := ColorRect.new()
	veil.color = Color(VEIL, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.show_behind_parent = true
	add_child(veil)
	create_tween().tween_property(veil, "color:a", VEIL.a, 0.25)

	var title := UI.label(d.prompt, 22, UI.CREAM, true)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.position = Vector2(0, 44)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var hint := UI.label("Pull one of the strings.", 14, UI.MUTED)
	hint.position = Vector2(0, 76)
	hint.size = Vector2(SIZE.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_doll = VoodooDoll.new()
	_doll.facing = 1.0
	_doll.position = DOLL_AT
	_doll.scale = Vector2.ONE * DOLL_SCALE
	_doll.level = 0.0
	add_child(_doll)
	create_tween().tween_property(_doll, "level", 1.0, 0.3)

	var count: int = d.options.size()
	var left: float = (SIZE.x - count * TAG.x - (count - 1) * TAG_GAP) / 2.0
	for i in count:
		var option: Dictionary = d.options[i]
		var tag := Tag.new()
		tag.setup(option, i)
		tag.size = TAG
		tag.position = Vector2(left + i * (TAG.x + TAG_GAP), TAG_TOP)
		tag.modulate.a = 0.0
		tag.clicked.connect(_pick.bind(i))
		tag.refused.connect(_refuse.bind(tag))
		tag.mouse_entered.connect(_hover.bind(i))
		tag.mouse_exited.connect(_unhover.bind(i))
		add_child(tag)
		_tags.append(tag)
		tag.create_tween().tween_property(tag, "modulate:a", 1.0, SHOW).set_delay(0.05 + i * SHOW_STAGGER)


## The tags that can be picked, in the order the keyboard walks them.
func views() -> Array:
	return _tags.filter(func(tag: Tag) -> bool: return not tag.disabled)


func _pick(index: int) -> void:
	picked.emit(index)


func _refuse(tag: Tag) -> void:
	UI.shake(tag, 5.0, 0.25)
	refused.emit()


func _hover(index: int) -> void:
	_hovered = index
	_tags[index].hot = true
	if not _tags[index].disabled:
		# The doll jerks on the string.
		var jerk := _doll.create_tween()
		jerk.tween_property(_doll, "stagger", 0.6, 0.08)
		jerk.tween_property(_doll, "stagger", 0.0, 0.4)


func _unhover(index: int) -> void:
	_tags[index].hot = false
	if _hovered == index:
		_hovered = -1


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in _tags.size():
		var tag := _tags[i]
		# Each string is tied to its own part of the doll, left to right.
		var hand := DOLL_AT + (_doll.heart() + Vector2(-9.0 + 9.0 * i, 3.0 - 4.0 * absf(i - 1.0))) * DOLL_SCALE
		var pin := tag.position + tag.pin()
		if tag.disabled:
			# Cut: a loose end hangs from the doll, and one from the tag.
			var cut := hand.lerp(pin, 0.3)
			_string(hand, cut + Vector2(-8, 14), STRING_DEAD, 4.0)
			_string(pin + Vector2(10, -34), pin, STRING_DEAD, 4.0)
			continue
		var taut := i == _hovered
		var ink := STRING_LIT if taut else STRING
		var sag := 2.0 if taut else 14.0 + 3.0 * sin(_time * 1.7 + i)
		if taut:
			# A glow round the taut string.
			_string(hand, pin, Color(UI.PURPLE, 0.35), 0.0, PX * 3.0)
		_string(hand, pin, ink, sag)


## A string in blocks from `a` to `b`, sagging `sag` in the middle.
func _string(a: Vector2, b: Vector2, ink: Color, sag: float, width := PX) -> void:
	var steps := maxi(int(a.distance_to(b) / PX), 1)
	for s in steps + 1:
		var t := float(s) / steps
		var at := a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t))
		at = (at / PX).floor() * PX
		draw_rect(Rect2(at - Vector2(width, width) / 2.0 + Vector2(PX, PX) / 2.0, Vector2(width, width)), ink)


## One thing the doll can do: a picture, its name and what it does, with
## nothing round them, bobbing a little, a knot at the top for the string.
## Under the hand a purple frame lights up round it, its edge wavering and
## flickering, never the same shape. Disabled, it is grey under a padlock,
## with the reason in red, and lights nothing.
class Tag extends Control:
	signal clicked
	signal refused

	const CELL := 3.0
	const GLOW := Color("d3a6f2")
	const GLOW_DEEP := Color("8e4fb5")
	const KNOT := Color("b98ae0")
	## How far it bobs, and how fast.
	const BOB := 3.0
	const BOB_SPEED := 1.6
	## The frame: how far in from the edge it runs, how round its corners
	## are (the power of the superellipse: higher is squarer), how far its
	## edge wanders and seconds for it to light or go out.
	const FRAME_IN := 6.0
	const FRAME_SQUARE := 5.0
	const WANDER := 5.0
	const FRAME_FADE := 0.15
	const INKS := {
		"o": Color("1a0c0c"), "R": Color("c8322a"), "L": Color("ff8a70"), "D": Color("86201c"),
		"Y": Color("f2c84b"), "y": Color("b8862a"), "B": Color("8a5f38"), "S": Color("5e3f24"),
		"N": Color("c2a468"), "I": Color("a39c92"), "G": Color("d9a840"), "g": Color("7d5616"),
	}
	const HEART := [
		"..ooo...ooo..",
		".oRRRo.oRRRo.",
		"oRLLRRoRRRRRo",
		"oRLRRRoRRRRRo",
		"oRRRRo.oRRRDo",
		".oRRRRo.RRDo.",
		"..oRRo.oRDo..",
		"...oRRoRDo...",
		"....oRRDo....",
		".....oDo.....",
		"......o......",
	]
	const COINS := [
		"...oooooo....",
		"..oYYLLYYo...",
		"..oyYYYYyo...",
		"..oooooooo...",
		"..oYYYYYYo...",
		"..oyyyyyyo...",
		"..oYYYYYYooo.",
		"..oyyyyyyYYo.",
		"..oYYYYYYyyo.",
		"..oyyyyyyooo.",
		"...oooooo....",
	]
	const SACK := [
		".....oooo....",
		"....oNNNNo...",
		".....oNNo....",
		"....oBBBBo...",
		"...oBBBBBBo..",
		"..oBBLBBBBBo.",
		"..oBLBBBBBBo.",
		"..oBBBBBBBSo.",
		"..oBBBBBBSSo.",
		"...oSSSSSSo..",
		"....oooooo...",
	]
	const LOCK := [
		"..oooo..",
		".oIIIIo.",
		".oI..Io.",
		".oI..Io.",
		"oooooooo",
		"oGGGGGGo",
		"oGGooGGo",
		"oGgoogGo",
		"oggggggo",
		"oooooooo",
	]
	const PICTURES := {&"hurt": HEART, &"coins": COINS, &"item": SACK}

	var disabled := false
	## Hovered (or the keyboard is on it).
	var hot := false
	var _picture: Array = HEART
	var _bob := 0.0
	var _lit := 0.0
	var _time := 0.0
	var _texts: Array[Control] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func setup(option: Dictionary, index: int) -> void:
		disabled = option.get("disabled", false)
		_picture = PICTURES.get(option.get("does"), HEART)
		_time = index * 1.9
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if disabled else Control.CURSOR_POINTING_HAND
		var heading := UI.label(option.get("label", "?"), 18, UI.MUTED if disabled else UI.GOLD, true)
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.position = Vector2(8, 82)
		heading.size = Vector2(154, 24)
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(heading)
		var about := UI.label(option.get("reason", "") if disabled else option.get("description", ""), 13,
				UI.RED.lightened(0.15) if disabled else UI.CREAM)
		about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.position = Vector2(12, 110)
		about.size = Vector2(146, 70)
		about.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(about)
		_texts = [heading, about]
		for text: Control in _texts:
			text.set_meta(&"y", text.position.y)

	## Where the string is tied, from the tag's corner.
	func pin() -> Vector2:
		return Vector2(size.x / 2.0, 18.0 + _bob)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if disabled:
				refused.emit()
			else:
				clicked.emit()

	func _process(delta: float) -> void:
		_time += delta
		# It bobs in blocks, like everything drawn here.
		_bob = roundf(BOB * sin(_time * BOB_SPEED) / 2.0) * 2.0
		_lit = move_toward(_lit, 1.0 if hot and not disabled else 0.0, delta / FRAME_FADE)
		for text: Control in _texts:
			text.position.y = text.get_meta(&"y") + _bob
		queue_redraw()

	func _draw() -> void:
		if _lit > 0.0:
			_draw_frame()
		# The knot the string is tied to.
		var knot := pin()
		var knot_ink := Color("6a6466") if disabled else KNOT
		draw_rect(Rect2(knot - Vector2(3, 3), Vector2(6, 6)), knot_ink.darkened(0.4))
		draw_rect(Rect2(knot - Vector2(2, 2), Vector2(4, 4)), knot_ink)
		# The picture, and over it, if it can't be done, the padlock.
		var wide: int = _picture[0].length()
		var corner := Vector2((size.x - wide * CELL) / 2.0, 30.0 + _bob)
		_bitmap(_picture, corner, CELL, disabled)
		if disabled:
			_bitmap(LOCK, corner + Vector2(wide * CELL - 14, 18), CELL, false)

	## A rounded frame whose edge wanders in and out in slow waves of its own
	## and flickers, in blocks: a glow outside, a bright line in the middle.
	func _draw_frame() -> void:
		var half := size / 2.0 - Vector2(FRAME_IN, FRAME_IN)
		var middle := size / 2.0 + Vector2(0, _bob)
		var steps := int((half.x + half.y) * 4.0 / PX * 1.3)
		var beat := floorf(_time * 14.0)
		for s in steps:
			var a := TAU * s / steps
			var c := cos(a)
			var n := sin(a)
			# A superellipse: a rectangle with round corners.
			var edge := Vector2(signf(c) * pow(absf(c), 2.0 / FRAME_SQUARE) * half.x,
					signf(n) * pow(absf(n), 2.0 / FRAME_SQUARE) * half.y)
			var out := edge.normalized()
			var wander := WANDER * (0.55 * sin(3.0 * a + _time * 2.3) + 0.3 * sin(7.0 * a - _time * 3.1)
					+ 0.15 * sin(13.0 * a + _time * 5.7))
			var at := ((middle + edge + out * wander) / PX).floor() * PX
			# Here and there it flickers out, never in the same places twice.
			var flicker := fposmod(sin(floorf(s / 6.0) * 12.9898 + beat * 78.233) * 43758.5453, 1.0)
			if flicker < 0.12:
				continue
			var shine := 0.6 + 0.4 * flicker
			draw_rect(Rect2(at - Vector2(PX, PX), Vector2(PX * 3.0, PX * 3.0)), Color(GLOW_DEEP, 0.35 * _lit * shine))
			draw_rect(Rect2(at, Vector2(PX, PX)), Color(GLOW.lerp(Color.WHITE, 0.25 * flicker), _lit * shine))
		# Motes of the spell rising inside it.
		for i in 6:
			var life := fposmod(_time * 0.7 + i / 6.0, 1.0)
			var at := Vector2(20 + fposmod(i * 37.0, size.x - 40), size.y - 14 - life * (size.y - 30))
			draw_rect(Rect2((at / PX).floor() * PX, Vector2(PX * 2, PX * 2)), Color(GLOW, 0.7 * _lit * sin(life * PI)))

	func _bitmap(rows: Array, corner: Vector2, cell: float, grey: bool) -> void:
		for row_index in rows.size():
			var row: String = rows[row_index]
			for column in row.length():
				var key := row[column]
				if not INKS.has(key):
					continue
				var ink: Color = INKS[key]
				if grey:
					var v := ink.get_luminance() * 0.55
					ink = Color(v, v, v * 1.05)
				draw_rect(Rect2(corner + Vector2(column, row_index) * cell, Vector2(cell, cell)), ink)
