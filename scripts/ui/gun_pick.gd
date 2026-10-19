extends Control
## The two choices of a Clown's gun (Bang!, see clown.gd), not menus: the
## table goes dark, the circus gun hangs big in the middle and the two
## choices stand on either side of it like circus bills, each in a frame of
## light bulbs that chase round it under the hand. A click on a bill picks it.
##
## `context.look` says which choice it is:
##   &"gun": the Clown loads it or not, before the claim. A cartridge on the
##     left, a party blower on the right, and the gun turns to whichever the
##     player is on; "Back to the table" (Esc, right click) backs out without
##     claiming anything.
##   &"duck": the target, with the gun aimed down at them, pays to duck or
##     takes their chances. Coins under an arrow on the left, a heart with a
##     question mark on the right; on that one the gun shakes harder. There
##     is no way out: one of the two has to be picked.
##
## Options: [{label, description, does}], does one of &"load", &"empty",
## &"duck", &"chance". No class name: preload it.

signal picked(index: int)
## A sound for the table to play (a cock of the hammer on the cartridge).
signal sounded(sound: String)

const SIZE := Vector2(1152, 648)
const PX := 2.0
const VEIL := Color(0.05, 0.015, 0.025, 0.86)
const GUN_ART := "res://assets/ui/clown_gun.png"
const GUN_AT := Vector2(576, 318)
const GUN_SIZE := Vector2(61, 64) * 4.0
## The bills: their size, the top of the row and how far they stand off the gun.
const BILL := Vector2(204, 260)
const BILL_TOP := 190.0
const BILL_OFF := 26.0
## Seconds the bills take to show, and how much later the second starts.
const SHOW := 0.3
const SHOW_STAGGER := 0.08
## Seconds the gun takes to turn round.
const TURN := 0.18
## How far off straight down the gun is turned when it is aimed at the player.
const AIM_TILT := 0.3

var _bills: Array[Bill] = []
var _gun: TextureRect
var _time := 0.0
var _facing := 1.0
var _look: StringName = &"gun"
var _cancellable := false
## Where the gun points at rest: to the left, or down at whoever is aimed at.
var _rest := 0.0
## How hard the gun shakes (0 to 1), and whether it is done spinning in.
var _shake := 0.0
var _shaking := 0.0
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
	title.position = Vector2(0, 44)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_look = d.context.get("look", &"gun")
	_cancellable = d.cancellable
	# Aimed at the player, down at the counter, a little askew.
	_rest = -PI / 2.0 + AIM_TILT if _look == &"duck" else 0.0
	var play: Variant = d.context.get("play")
	var hint := UI.label(Loc.t("Loaded or empty? Only %s knows.") % play.actor.name
			if _look == &"duck" and play is Play else Loc.t("Only you will know. The table sees the coins put down either way."), 14, UI.MUTED)
	hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hint.position = Vector2(0, 76)
	hint.size = Vector2(SIZE.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_gun = TextureRect.new()
	_gun.texture = UI.tex(GUN_ART)
	_gun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gun.size = GUN_SIZE
	_gun.pivot_offset = GUN_SIZE / 2.0
	_gun.position = GUN_AT - GUN_SIZE / 2.0
	_gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gun.scale = Vector2.ONE * 0.3
	_gun.rotation = _rest - TAU
	add_child(_gun)
	var spin := _gun.create_tween().set_parallel()
	spin.tween_property(_gun, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spin.tween_property(_gun, "rotation", _rest, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	spin.chain().tween_callback(func() -> void: _settled = true)

	var count: int = mini(d.options.size(), 2)
	for i in count:
		var bill := Bill.new()
		bill.setup(d.options[i], i)
		bill.size = BILL
		var left := GUN_AT.x - GUN_SIZE.x / 2.0 - BILL_OFF - BILL.x if i == 0 else GUN_AT.x + GUN_SIZE.x / 2.0 + BILL_OFF
		bill.position = Vector2(left, BILL_TOP)
		bill.modulate.a = 0.0
		bill.clicked.connect(_pick.bind(i))
		bill.mouse_entered.connect(_hover.bind(i))
		bill.mouse_exited.connect(_unhover.bind(i))
		add_child(bill)
		_bills.append(bill)
		bill.create_tween().tween_property(bill, "modulate:a", 1.0, SHOW).set_delay(0.1 + i * SHOW_STAGGER)

	if d.cancellable:
		var back := UI.button("Back to the table", UI.BORDER, 15)
		back.size = UI.grown(Vector2(210, 34))
		back.position = Vector2(GUN_AT.x - back.size.x / 2.0, SIZE.y - 30.0 - back.size.y)
		TipLayer.attach(back, "Leave without claiming anything." if UI.touch else "Leave without claiming anything (Esc or right click).")
		# A word in the dark, with a thin gold line under it: no plate.
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var line := StyleBoxFlat.new()
			line.bg_color = Color(UI.GOLD, 0.12 if state == "hover" else 0.0)
			line.border_color = Color(UI.GOLD, 0.9 if state == "hover" else 0.4)
			line.border_width_bottom = 2
			back.add_theme_stylebox_override(state, line)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			back.add_theme_color_override(state, UI.CREAM)
		back.pressed.connect(_pick.bind(-1))
		add_child(back)


## The bills, in the order the keyboard walks them.
func views() -> Array:
	return _bills


func _gui_input(event: InputEvent) -> void:
	if _cancellable and not UI.touch and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_pick(-1)


func _pick(index: int) -> void:
	picked.emit(index)


func _hover(index: int) -> void:
	var bill := _bills[index]
	bill.hot = true
	if _look == &"duck":
		# Taking chances, the gun shakes harder; ducking, it settles.
		_shake = 1.0 if bill.does == &"chance" else 0.0
		sounded.emit("item_roulette_tick" if bill.does == &"chance" else "coin_1")
		return
	# The barrel turns to the bill: the art points left, and the bill on the
	# right is where an empty gun would go.
	var facing := 1.0 if index == 0 else -1.0
	if facing != _facing:
		_facing = facing
		_gun.create_tween().tween_property(_gun, "scale:x", facing, TURN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var nudge := _gun.create_tween()
	nudge.tween_property(_gun, "rotation", 0.12 * facing, 0.08)
	nudge.tween_property(_gun, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if bill.does == &"load":
		sounded.emit("item_roulette_tick")
	else:
		# A pinch of the party, out of the blower on the bill.
		var party := PlayFx.ConfettiFx.new(1.0)
		add_child(party)
		party.blast(bill.position + bill.picture_middle(), Vector2.UP.rotated(-0.5), 12, 0)


func _unhover(index: int) -> void:
	_bills[index].hot = false
	_shake = 0.0


func _process(delta: float) -> void:
	_time += delta
	# The gun hangs there, breathing a little.
	if is_instance_valid(_gun):
		_gun.position.y = GUN_AT.y - GUN_SIZE.y / 2.0 + roundf(3.0 * sin(_time * 1.4) / PX) * PX
		# Aimed at someone, it is never quite still, and shakes when they gamble.
		if _look == &"duck" and _settled:
			_shaking = move_toward(_shaking, _shake, delta * 6.0)
			_gun.rotation = _rest + 0.015 * sin(_time * 3.1) + 0.05 * _shaking * sin(_time * 47.0)


## One of the two choices: a picture, its name and what it does, on a dark
## bill in a frame of light bulbs. Under the hand the bulbs chase round it
## and the picture lifts.
class Bill extends Control:
	signal clicked

	const CELL := 5.0
	const BULB_STEP := 16.0
	const BULB := 4.0
	const INSET := 8.0
	const PAPER := Color("2a1418")
	const PAPER_EDGE := Color("5a2a2e")
	const WARM := Color("ffd27a")
	const PARTY: Array[Color] = [
		Color("ff4fa3"), Color("ffd84a"), Color("4fd6ff"), Color("7be04a"), Color("ff7a2a"), Color("b07bff"),
	]
	const INKS := {
		"o": Color("1a0c0c"), "L": Color("fff0c0"), "C": Color("d07a3c"), "D": Color("8a4a22"),
		"Y": Color("e6b84a"), "y": Color("a07a26"), "g": Color("6b4f18"),
		"W": Color("f6efe0"), "w": Color("c9bfae"), "R": Color("e0403a"), "r": Color("9a2622"),
		"P": Color("ff4fa3"), "B": Color("4fd6ff"), "G": Color("7be04a"), "Q": Color("ffd84a"),
	}
	const CARTRIDGE := [
		"...ooo...",
		"..oLCCo..",
		".oLCCCDo.",
		".oLCCCDo.",
		".oCCCCDo.",
		"ooooooooo",
		"oYLYYYyyo",
		"oYLYYYyyo",
		"oYLYYYyyo",
		"oYLYYYyyo",
		"oYLYYYyyo",
		"oYYYYYyyo",
		"ooooooooo",
		"oyyyyyygo",
		"ooooooooo",
	]
	const BLOWER := [
		"..P.....Q...B..",
		"......G.....P..",
		"Q..B......Q....",
		"......oo.....G.",
		"..P..oWWo..B...",
		"....oWRWWo.....",
		".G.oWWWRWo..P..",
		"..oRWWWWWo.....",
		"..oWWRWWo..Q...",
		".oWWWWwo..B....",
		".oWRWWo........",
		"oWWWwo....G....",
		"oRWwo..........",
		"oWwo...........",
		"ooo............",
	]

	const COINS_DOWN := [
		".....ooo.....",
		".....oWo.....",
		".....oWo.....",
		".....oWo.....",
		"...ooWWWoo...",
		"....oWWWo....",
		".....oWo.....",
		"......o......",
		".............",
		"..ooooooooo..",
		"..oLYYYYYyo..",
		"..ooooooooo..",
		"..oYYYYYYyo..",
		"..ooooooooo..",
		"..oLYYYYYyo..",
		"..ooooooooo..",
	]
	const HEART_RISK := [
		"..ooo...ooo.....oooo..",
		".oRRRo.oRRRo...oWWWWo.",
		"oRLLRRoRRRRRo.oWWooWWo",
		"oRLRRRoRRRRRo.ooo.oWWo",
		"oRRRRRRRRRRro....oWWo.",
		".oRRRRRRRRro....oWWo..",
		"..oRRRRRRro.....oWWo..",
		"...oRRRRro......oooo..",
		"....oRRro.......oWWo..",
		".....oro........oWWo..",
		"......o.........oooo..",
	]
	const PICTURES := {&"load": CARTRIDGE, &"empty": BLOWER, &"duck": COINS_DOWN, &"chance": HEART_RISK}
	const DANGER := Color("ff5a44")

	var does: StringName = &"load"
	## Hovered (or the keyboard is on it).
	var hot := false
	var _picture: Array = CARTRIDGE
	var _lit := 0.0
	var _time := 0.0
	var _lift := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func setup(option: Dictionary, index: int) -> void:
		does = option.get("does", &"load" if index == 0 else &"empty")
		_picture = PICTURES.get(does, CARTRIDGE)
		var heading := UI.label(option.get("label", "?"), 20, UI.GOLD, true)
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A price comes after the name: the coin and the amount.
		var line := UI.priced(heading, option.price, 20) if option.get("price", 0) > 0 else HBoxContainer.new()
		if line.get_child_count() == 0:
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(heading)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.position = Vector2(12, 150)
		line.size = Vector2(180, 26)
		add_child(line)
		var about := UI.label(option.get("description", ""), 13, UI.CREAM)
		about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.position = Vector2(18, 180)
		about.size = Vector2(168, 66)
		about.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(about)

	## The middle of the picture, from the bill's corner.
	func picture_middle() -> Vector2:
		return Vector2(size.x / 2.0, 34.0 + _picture.size() * CELL / 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _process(delta: float) -> void:
		_time += delta
		_lit = move_toward(_lit, 1.0 if hot else 0.0, delta / 0.15)
		_lift = move_toward(_lift, 6.0 if hot else 0.0, delta * 60.0)
		queue_redraw()

	func _draw() -> void:
		# The bill: dark paper with a lighter rim, in blocks.
		draw_rect(Rect2(Vector2.ZERO, size), PAPER_EDGE)
		draw_rect(Rect2(Vector2(PX, PX), size - Vector2(PX, PX) * 2.0), PAPER)
		draw_rect(Rect2(Vector2(INSET + 6, 134), Vector2(size.x - (INSET + 6) * 2.0, PX)), Color(UI.GOLD, 0.35))
		_bulbs()
		var wide: int = _picture[0].length()
		var corner := Vector2(roundf((size.x - wide * CELL) / 2.0 / PX) * PX, 34.0 - roundf(_lift / PX) * PX)
		for row in _picture.size():
			var line: String = _picture[row]
			for column in line.length():
				var key := line[column]
				if INKS.has(key):
					draw_rect(Rect2(corner + Vector2(column, row) * CELL, Vector2(CELL, CELL)), INKS[key])

	## Light bulbs all round the edge. At rest they glow low and still; under
	## the hand they chase round, one lit in three, a step at a time.
	func _bulbs() -> void:
		var spots: Array[Vector2] = []
		var inner := Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)
		var across := int(inner.size.x / BULB_STEP)
		var down := int(inner.size.y / BULB_STEP)
		var step := Vector2(inner.size.x / across, inner.size.y / down)
		for i in across:
			spots.append(inner.position + Vector2(i * step.x, 0))
		for i in down:
			spots.append(inner.position + Vector2(inner.size.x, i * step.y))
		for i in across:
			spots.append(inner.end - Vector2(i * step.x, 0))
		for i in down:
			spots.append(inner.position + Vector2(0, inner.size.y - i * step.y))
		var beat := int(_time * 9.0)
		for i in spots.size():
			var ink: Color = WARM
			if does == &"empty":
				ink = PARTY[i % PARTY.size()]
			elif does == &"chance":
				ink = DANGER
			var chase := 1.0 if (i + beat) % 3 == 0 else 0.25
			var glow := lerpf(0.4, chase, _lit)
			var at := (spots[i] / PX).floor() * PX
			if glow > 0.5:
				draw_rect(Rect2(at - Vector2(BULB, BULB) / 2.0 - Vector2(PX, PX), Vector2(BULB + PX * 2.0, BULB + PX * 2.0)),
						Color(ink, 0.3 * glow))
			draw_rect(Rect2(at - Vector2(BULB, BULB) / 2.0, Vector2(BULB, BULB)), ink.darkened(0.6).lerp(ink, glow))
