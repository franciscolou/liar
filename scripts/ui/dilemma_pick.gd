extends Control
## The choice of a Prisoner's Dilemma (duelist.gd), not a menu: the table goes
## dark, the player's own sword hangs big in the middle over a heap of coins,
## the other player's sword waits in the shadow above with a question mark
## (they are choosing at the same time, in secret), and the two answers stand
## on either side like dueling cartels: Contribute in gold on the left, Attack
## in blood red on the right, each with what comes of it for each answer the
## other may give. Under the hand a cartel lifts and its rim lights with a
## glint running across it, and the sword answers: driven point first into
## the coins for Contribute, raised at the other sword, red hot and shaking,
## for Attack. A click on a cartel picks it; there is no way out.
##
## Options: [{label, description, does, outcomes}], does &"give" or &"strike",
## outcomes [{if, then, tone}] (tone &"good", &"bad", &"hit" or &"none").
## context.rival is the other player. No class name: preload it.

signal picked(index: int)
## A sound for the table to play.
signal sounded(sound: String)

const SIZE := Vector2(1152, 648)
const PX := 2.0
const VEIL := Color(0.04, 0.015, 0.02, 0.86)
## The player's sword: where its guard hangs, how big it is drawn, and how it
## sits at rest; for Contribute it goes down point first into the coins, for
## Attack it is turned point up at the other sword, the guard coming down so
## that the point stays on the screen.
const SWORD_AT := Vector2(576, 214)
const SWORD_ZOOM := 2.5
const REST := PI / 2.0 + 0.18
const GIVE_ANGLE := PI / 2.0
const GIVE_DROP := 86.0
const STRIKE_ANGLE := -PI / 2.0 + 0.25
const STRIKE_DROP := 120.0
## The heap of coins under it, and the other sword, in the shadow above.
const HEAP_AT := Vector2(576, 470)
const RIVAL_AT := Vector2(576, 120)
## The cartels: their size, the top of the row and how far they stand off the sword.
const CARTEL := Vector2(258, 318)
const CARTEL_TOP := 160.0
const CARTEL_OFF := 112.0
const SHOW := 0.3
const SHOW_STAGGER := 0.1
const GOLD_COIN: Array[Color] = [Color("5a3c10"), Color("b8862a"), Color("e6bc4c"), Color("fff0b0")]

var _cartels: Array[Cartel] = []
var _sword: PlayFx.SwordFx
var _rival: PlayFx.SwordFx
var _ask: Label
var _time := 0.0
## Which cartel the hand is on: -1 none, else its index.
var _hot := -1
## How far the sword has gone toward each answer (0 to 1).
var _give := 0.0
var _strike := 0.0
var _swing := 0.0
var _settled := false


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
	title.position = Vector2(0, 30)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var rival: Variant = d.context.get("rival")
	var who: String = rival.name if rival is PlayerState else "?"
	var hint := UI.label(Loc.t("%s is choosing at the same time. Neither of you will know until both have chosen.") % who, 14, UI.MUTED)
	hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hint.position = Vector2(0, 62)
	hint.size = Vector2(SIZE.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	# The other sword, dark, pointed at this one, and the question over it.
	_rival = PlayFx.SwordFx.new()
	_rival.position = RIVAL_AT + Vector2(-SWORD_ZOOM * 26.0, 0)
	_rival.scale = Vector2.ONE * SWORD_ZOOM * 0.7
	_rival.modulate = Color(0.25, 0.22, 0.28, 0.0)
	_rival.bob = true
	add_child(_rival)
	_rival.create_tween().tween_property(_rival, "modulate:a", 0.9, 0.4).set_delay(0.15)
	_ask = UI.label("?", 30, UI.GOLD, true)
	_ask.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ask.size = Vector2(40, 40)
	_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Past the point of the other sword: what it will do is the question.
	_ask.position = RIVAL_AT + Vector2(64, -24)
	_ask.add_theme_constant_override("outline_size", 6)
	_ask.add_theme_color_override("font_outline_color", UI.INK)
	add_child(_ask)
	# Whose it is, by the pommel.
	var tag := UI.label(who, 14, UI.MUTED, true)
	tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tag.size = Vector2(200, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.position = RIVAL_AT + Vector2(-SWORD_ZOOM * 26.0 - 24.0 - 200.0, -10)
	add_child(tag)

	# The player's own sword: drawn out of nothing with a turn, then hanging.
	_sword = PlayFx.SwordFx.new()
	_sword.position = SWORD_AT
	_sword.scale = Vector2.ONE * 0.4
	_sword.rotation = REST - TAU
	_sword.trail = 1.0
	add_child(_sword)
	var draw_in := _sword.create_tween().set_parallel()
	draw_in.tween_property(_sword, "scale", Vector2.ONE * SWORD_ZOOM, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	draw_in.tween_property(_sword, "rotation", REST, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	draw_in.chain().tween_callback(func() -> void:
		_settled = true
		_sword.trail = 0.0
		_sword.shine())

	var count: int = mini(d.options.size(), 2)
	for i in count:
		var cartel := Cartel.new()
		cartel.size = CARTEL
		cartel.setup(d.options[i], i)
		var left := SWORD_AT.x - CARTEL_OFF - CARTEL.x if i == 0 else SWORD_AT.x + CARTEL_OFF
		cartel.position = Vector2(left, CARTEL_TOP)
		cartel.modulate.a = 0.0
		cartel.clicked.connect(_pick.bind(i))
		cartel.mouse_entered.connect(_hover.bind(i))
		cartel.mouse_exited.connect(_unhover.bind(i))
		add_child(cartel)
		_cartels.append(cartel)
		var show := cartel.create_tween().set_parallel()
		show.tween_property(cartel, "modulate:a", 1.0, SHOW).set_delay(0.15 + i * SHOW_STAGGER)
		cartel.position.x += -24.0 if i == 0 else 24.0
		show.tween_property(cartel, "position:x", left, SHOW + 0.1).set_delay(0.15 + i * SHOW_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The cartels, in the order the keyboard walks them.
func views() -> Array:
	return _cartels


func _pick(index: int) -> void:
	picked.emit(index)


func _hover(index: int) -> void:
	_cartels[index].hot = true
	_hot = index
	_sword.trail = 1.0
	if _cartels[index].does == &"strike":
		sounded.emit("fx_sword_whoosh")
	else:
		sounded.emit("coin_1")


func _unhover(index: int) -> void:
	_cartels[index].hot = false
	if _hot == index:
		_hot = -1


func _process(delta: float) -> void:
	_time += delta
	var does: StringName = _cartels[_hot].does if _hot >= 0 and _hot < _cartels.size() else &""
	_give = move_toward(_give, 1.0 if does == &"give" else 0.0, delta * 5.0)
	_strike = move_toward(_strike, 1.0 if does == &"strike" else 0.0, delta * 5.0)
	if is_instance_valid(_sword) and _settled:
		var give := ease(_give, 0.4)
		var strike := ease(_strike, 0.4)
		var angle := REST + 0.04 * sin(_time * 1.3)
		angle = lerp_angle(angle, GIVE_ANGLE, give)
		angle = lerp_angle(angle, STRIKE_ANGLE, strike)
		_sword.rotation = angle
		var breathe := roundf(3.0 * sin(_time * 1.6) / PX) * PX * (1.0 - maxf(give, strike))
		_sword.position = SWORD_AT + Vector2(0, breathe + GIVE_DROP * give + STRIKE_DROP * strike)
		# Into the coins, the end of the blade disappears in them.
		_sword.sunk = 9.0 * give
		_sword.glow = strike
		_sword.quiver = 0.35 * strike
		if give <= 0.01 and strike <= 0.01 and _hot < 0:
			_sword.trail = 0.0
	if is_instance_valid(_ask):
		_ask.modulate.a = 0.6 + 0.4 * sin(_time * 3.0)
		_ask.position.y = RIVAL_AT.y - 24.0 + roundf(2.0 * sin(_time * 2.0) / PX) * PX
	if is_instance_valid(_rival):
		# The other sword follows this one: it rises when this one does.
		_rival.rotation = lerp_angle(0.0, 0.35, _strike)
	queue_redraw()


func _draw() -> void:
	_draw_heap()


## A heap of gold coins, in blocks, with a glint that comes and goes and a
## warm glow when the sword is going into it.
func _draw_heap() -> void:
	var glow := ease(_give, 0.5)
	if glow > 0.0:
		for r in [64.0, 46.0, 30.0]:
			draw_rect(Rect2(HEAP_AT + Vector2(-r, -r * 0.45), Vector2(r * 2.0, r * 0.9)), Color(UI.GOLD, 0.06 * glow))
	# Rows of coins seen side on, wider at the foot: [half width, height].
	var rows: Array = [[58, 0], [50, -8], [40, -16], [28, -24], [16, -32]]
	for row: Array in rows:
		var half: float = row[0]
		var y: float = HEAP_AT.y + row[1]
		var x := -half
		while x < half:
			var at := Vector2(HEAP_AT.x + x, y)
			draw_rect(Rect2(at, Vector2(12, 8)), GOLD_COIN[0])
			draw_rect(Rect2(at + Vector2(PX, 0), Vector2(8, 4)), GOLD_COIN[2])
			draw_rect(Rect2(at + Vector2(PX, 4), Vector2(8, 2)), GOLD_COIN[1])
			x += 10.0
	# A glint wandering over the heap.
	var spark := HEAP_AT + Vector2(roundf(36.0 * sin(_time * 0.9) / PX) * PX, -18.0 + roundf(8.0 * cos(_time * 1.3) / PX) * PX)
	var shine := 0.5 + 0.5 * sin(_time * 4.0)
	draw_rect(Rect2(spark - Vector2(1, 5), Vector2(PX, 10)), Color(GOLD_COIN[3], shine))
	draw_rect(Rect2(spark - Vector2(5, 1), Vector2(10, PX)), Color(GOLD_COIN[3], shine))


## One of the two answers: a dueling cartel of dark leather with brass
## corners, a picture, the name and, for each answer the other player may
## give, what comes of it. Under the hand it lifts, its rim lights in its
## colour and a glint runs across it.
class Cartel extends Control:
	signal clicked

	const CELL := 5.0
	const INSET := 10.0
	const LEATHER := Color("24100f")
	const LEATHER_EDGE := Color("4a2222")
	const BRASS: Array[Color] = [Color("5a3c10"), Color("c8962e"), Color("f2d488")]
	const TONES := {&"good": Color("8cd06a"), &"bad": Color("ef5a48"), &"hit": Color("f2c84b"), &"none": Color("9a9488")}
	const RIMS := {&"give": Color("e6bc4c"), &"strike": Color("e0261a")}
	const INKS := {
		"o": Color("140c10"), "S": Color("eef3fa"), "s": Color("9aa4b4"), "d": Color("5c6676"),
		"Y": Color("f2d488"), "y": Color("c8962e"), "g": Color("7a5418"),
		"L": Color("8a4a24"), "R": Color("e0261a"), "r": Color("8e1a1e"), "W": Color("fff0e0"),
	}
	## A sword driven into a heap of coins.
	const GIVE := [
		".......oYo.......",
		"......oYyYo......",
		".......oLo.......",
		".......oLo.......",
		"....ooooYoooo....",
		"....oyYYYYYyo....",
		"....ooooSoooo....",
		".......oSo.......",
		".......oSo.......",
		".......oSo.......",
		".......oSo.......",
		"...ooooosooooo...",
		"..oYYYYYYYYYYYo..",
		".ooooooooooooooo.",
		"oyYYYYYYYYYYYYYyo",
		"ooooooooooooooooo",
		"oYYyYYYYyYYYYyYYo",
		"ooooooooooooooooo",
	]
	## A sword thrust up and across, a red cut behind it.
	const STRIKE := [
		"..............oSo",
		".............oSo.",
		"............oSo..",
		"...R.......oSo...",
		"....R.....oSo....",
		".....R...oSo.....",
		"......R.oSo......",
		".......oSo.......",
		"..oyo.oSo........",
		"...oyoSo.........",
		"....oyo..........",
		"...oLoyo.........",
		"..oLo.oyo........",
		".oYo.............",
		"oYo..............",
		"oo...............",
		".................",
		".................",
	]
	## The other player's answer, small, before each outcome.
	const COIN := ["..ooo..", ".oYYYo.", "oYYyYYo", "oYyYyYo", "oYYyYYo", ".oyyyo.", "..ooo.."]
	const BLADE := [".....oo", "....oSo", "...oSo.", "o.oSo..", ".oyo...", ".oo.o..", "o......"]

	var does: StringName = &"give"
	## Hovered (or the keyboard is on it).
	var hot := false
	var _lit := 0.0
	var _lift := 0.0
	var _time := 0.0
	var _glint := -1.0
	var _outcomes: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func setup(option: Dictionary, index: int) -> void:
		does = option.get("does", &"give" if index == 0 else &"strike")
		var rim: Color = RIMS.get(does, UI.GOLD)
		var heading := UI.label(option.get("label", "?"), 24, rim.lightened(0.15), true)
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.position = Vector2(12, 112)
		heading.size = Vector2(size.x - 24, 30)
		heading.add_theme_constant_override("outline_size", 4)
		heading.add_theme_color_override("font_outline_color", UI.INK)
		add_child(heading)
		_outcomes = option.get("outcomes", [])
		var y := 160.0
		for outcome: Dictionary in _outcomes:
			var condition := UI.label(outcome.get("if", ""), 13, UI.MUTED)
			condition.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			condition.mouse_filter = Control.MOUSE_FILTER_IGNORE
			condition.position = Vector2(48, y)
			condition.size = Vector2(size.x - 62, 18)
			condition.clip_text = true
			add_child(condition)
			var result := UI.label(outcome.get("then", ""), 15, TONES.get(outcome.get("tone", &"none"), UI.CREAM), true)
			result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			result.mouse_filter = Control.MOUSE_FILTER_IGNORE
			result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result.position = Vector2(48, y + 18)
			result.size = Vector2(size.x - 62, 40)
			add_child(result)
			y += 70.0
		if _outcomes.is_empty():
			var about := UI.label(option.get("description", ""), 13, UI.CREAM)
			about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			about.mouse_filter = Control.MOUSE_FILTER_IGNORE
			about.position = Vector2(18, 160)
			about.size = Vector2(size.x - 36, 120)
			add_child(about)
		mouse_entered.connect(func() -> void: _glint = 0.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _process(delta: float) -> void:
		_time += delta
		_lit = move_toward(_lit, 1.0 if hot else 0.0, delta / 0.15)
		_lift = move_toward(_lift, 8.0 if hot else 0.0, delta * 70.0)
		if _glint >= 0.0:
			_glint += delta * 1.6
			if _glint > 1.4:
				_glint = -1.0
		position.y = CARTEL_TOP - roundf(_lift / PX) * PX
		queue_redraw()

	func _draw() -> void:
		var rim: Color = RIMS.get(does, UI.GOLD)
		# The glow round it, under the hand.
		if _lit > 0.0:
			for k in 3:
				var out := PX * (k + 1) * 2.0
				draw_rect(Rect2(Vector2(-out, -out), size + Vector2(out, out) * 2.0), Color(rim, 0.08 * _lit * (3 - k)))
		draw_rect(Rect2(Vector2.ZERO, size), LEATHER_EDGE.lerp(rim.darkened(0.3), _lit))
		draw_rect(Rect2(Vector2(PX, PX) * 2.0, size - Vector2(PX, PX) * 4.0), LEATHER)
		# A thin engraved frame inside, lit in the cartel's colour.
		var frame := Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)
		var ink := Color(rim, lerpf(0.25, 0.85, _lit))
		draw_rect(Rect2(frame.position, Vector2(frame.size.x, PX)), ink)
		draw_rect(Rect2(frame.position + Vector2(0, frame.size.y - PX), Vector2(frame.size.x, PX)), ink)
		draw_rect(Rect2(frame.position, Vector2(PX, frame.size.y)), ink)
		draw_rect(Rect2(frame.position + Vector2(frame.size.x - PX, 0), Vector2(PX, frame.size.y)), ink)
		# Brass corners.
		for corner: Vector2 in [Vector2.ZERO, Vector2(size.x - 12, 0), Vector2(0, size.y - 12), size - Vector2(12, 12)]:
			draw_rect(Rect2(corner, Vector2(12, 12)), BRASS[0])
			draw_rect(Rect2(corner + Vector2(PX, PX), Vector2(8, 8)), BRASS[1])
			draw_rect(Rect2(corner + Vector2(PX, PX), Vector2(4, 4)), BRASS[2])
		# The divider under the name.
		draw_rect(Rect2(Vector2(INSET + 14, 148), Vector2(size.x - (INSET + 14) * 2.0, PX)), Color(rim, 0.35))
		_draw_bitmap(GIVE if does == &"give" else STRIKE, Vector2(size.x / 2.0, 20), CELL, true)
		# Before each outcome, the other player's answer: a coin or a blade.
		var y := 166.0
		for i in _outcomes.size():
			_draw_bitmap(COIN if i == 0 else BLADE, Vector2(30, y + 8), 3.0, true)
			y += 70.0
		_draw_glint()

	func _draw_bitmap(rows: Array, top_middle: Vector2, cell: float, centred: bool) -> void:
		var wide: int = rows[0].length()
		var corner := top_middle - Vector2(wide * cell / 2.0 if centred else 0.0, 0)
		corner = (corner / PX).floor() * PX
		for row in rows.size():
			var line: String = rows[row]
			for column in line.length():
				var key := line[column]
				if INKS.has(key):
					draw_rect(Rect2(corner + Vector2(column, row) * cell, Vector2(cell, cell)), INKS[key])

	## A band of light that crosses the cartel once, slanted, as the hand comes on.
	func _draw_glint() -> void:
		if _glint < 0.0:
			return
		var reach := size.x + size.y * 0.5
		var x0 := -size.y * 0.5 + _glint * reach
		var y := 0.0
		while y < size.y:
			var x := x0 + y * 0.5
			var from := clampf(x, PX * 2.0, size.x - PX * 2.0)
			var to := clampf(x + 14.0, PX * 2.0, size.x - PX * 2.0)
			if to > from:
				draw_rect(Rect2(from, y, to - from, PX), Color(1, 1, 1, 0.08))
			y += PX

