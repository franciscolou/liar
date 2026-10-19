extends Control
## Which guard answers a play aimed at its holder (GameEngine._choose_guard:
## a Shield and a Mirror in the same inventory), not a menu: the table goes
## dark, what is coming hangs at the top (the card of the character claimed,
## or the item used) with a red bolt pulsing under it, and each guard stands
## below it, big, on a brass plinth. Under the hand the bolt comes down at
## the guard and shows what it would do: a Shield takes the blow in a burst
## of sparks, a Mirror flashes and sends the bolt back up at whoever sent it.
## There is no way out (a holder always defends): one of them is picked.
##
## Options: [{label, description, item}], from GameEngine._choose_guard, and
## `context.play` is the play coming. No class name: preload it.

signal picked(index: int)
## A sound for the table to play.
signal sounded(sound: String)

const SIZE := Vector2(1152, 648)
const PX := 2.0
const VEIL := Color(0.02, 0.03, 0.06, 0.86)
## The middle of what is coming, and how far below it the bolt waits.
const THREAT_AT := Vector2(576, 178)
const THREAT_CARD := 1.3
const THREAT_ITEM := 1.6
const BOLT_WAIT := 104.0
## Where the guards stand: the middle of the row and the step between them.
const ROW_Y := 300.0
const ROW_STEP := 300.0
const STANCE := Vector2(230, 300)
const ITEM_SCALE := 2.6
## One pass of the bolt under the hand: down, the answer, a rest.
const CYCLE := 1.5
const FALL := 0.42
const BOUNCE := 0.38
const SPARKS := 14
const BOLT := Color("ff5a3c")
const BOLT_CORE := Color("fff0c0")
const BOLT_DEEP := Color("9a1e14")
const SHINE := Color("cfe8ff")

var _stances: Array[Stance] = []
## What the bolt is drawn on: over the guards, so a blow lands in front.
var _fx: Control
var _threat: Control
var _hot := -1
## When the hand came onto the guard it is on: the bolt starts from there.
var _hot_since := 0.0
var _time := 0.0
## Whether the sound of the answer was played for this hover already.
var _sounded := false
## The way each spark of a blow on a shield flies.
var _rng := RandomNumberGenerator.new()
var _spark_dirs: Array[Vector2] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Only the look of the sparks: drawn the same for every pass.
	_rng.seed = 7
	for i in SPARKS:
		var angle := -PI + _rng.randf_range(0.15, PI - 0.15)
		_spark_dirs.append(Vector2.from_angle(angle) * _rng.randf_range(70.0, 170.0))


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
	title.position = Vector2(0, 28)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var hint := UI.label("Only one of them answers it, and it breaks.", 14, UI.MUTED)
	hint.position = Vector2(0, 60)
	hint.size = Vector2(SIZE.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	var play: Variant = d.context.get("play")
	if play is Play:
		_threat = _threat_of(play)
		_threat.position = THREAT_AT - _threat.size / 2.0
		_threat.pivot_offset = _threat.size / 2.0
		_threat.scale = Vector2.ONE * 0.4
		_threat.modulate.a = 0.0
		add_child(_threat)
		var arrive := _threat.create_tween().set_parallel()
		arrive.tween_property(_threat, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		arrive.tween_property(_threat, "modulate:a", 1.0, 0.2)

	var count: int = d.options.size()
	for i in count:
		var option: Dictionary = d.options[i]
		var stance := Stance.new()
		stance.size = STANCE
		var x := SIZE.x / 2.0 + (i - (count - 1) / 2.0) * ROW_STEP
		stance.position = Vector2(x - STANCE.x / 2.0, ROW_Y)
		stance.setup(option, _answer_of(option, play))
		stance.modulate.a = 0.0
		stance.clicked.connect(_pick.bind(i))
		stance.mouse_entered.connect(_hover.bind(i))
		stance.mouse_exited.connect(_unhover.bind(i))
		add_child(stance)
		_stances.append(stance)
		var rise := stance.create_tween().set_parallel()
		rise.tween_property(stance, "modulate:a", 1.0, 0.3).set_delay(0.12 + 0.08 * i)
		rise.tween_property(stance, "position:y", ROW_Y, 0.4).from(ROW_Y + 30.0) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.12 + 0.08 * i)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_paint)
	add_child(_fx)


## The guards, in the order the keyboard walks them.
func views() -> Array:
	return _stances


## What is coming: the card of the character claimed, face up (the whole table
## heard the claim), or the item used.
func _threat_of(play: Play) -> Control:
	if play.is_claim():
		var card := CardView.new(THREAT_CARD)
		card.interactive = false
		card.tips = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_card(play.ability().character_id, true)
		var name_tag := UI.label(play.source.display_name, 14, UI.GOLD, true)
		name_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_tag.position = Vector2(-90, -24)
		name_tag.size = Vector2(card.size.x + 180, 20)
		card.add_child(name_tag)
		return card
	var item := ItemView.new(THREAT_ITEM)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.set_item(play.source as ItemDef)
	return item


## What a guard would do to `play`, in a few words.
func _answer_of(option: Dictionary, play: Variant) -> String:
	var def: ItemDef = option.get("item")
	if def != null and def.id == &"mirror":
		return Loc.t("Sends it back at %s.") % play.actor.name if play is Play else Loc.t("Sends it back.")
	if def != null and def.id == &"shield":
		return Loc.t("Stops it here.")
	return option.get("description", "")


func _reflects(index: int) -> bool:
	return index >= 0 and index < _stances.size() and _stances[index].reflects


func _pick(index: int) -> void:
	picked.emit(index)


func _hover(index: int) -> void:
	_hot = index
	_hot_since = _time
	_sounded = false
	_stances[index].hot = true


func _unhover(index: int) -> void:
	_stances[index].hot = false
	_stances[index].struck = 0.0
	if _hot == index:
		_hot = -1


func _process(delta: float) -> void:
	_time += delta
	if _hot >= 0:
		var phase := fmod(_time - _hot_since, CYCLE)
		var stance := _stances[_hot]
		stance.struck = clampf(1.0 - (phase - FALL) / 0.3, 0.0, 1.0) if phase >= FALL else 0.0
		if phase >= FALL and not _sounded:
			_sounded = true
			sounded.emit("item_mirror" if stance.reflects else "item_shield")
		if is_instance_valid(_threat):
			# Hit back by its own bolt, what sent it shakes.
			var back := phase - FALL - BOUNCE
			var jolt := clampf(1.0 - back / 0.25, 0.0, 1.0) if stance.reflects and back >= 0.0 else 0.0
			_threat.position.x = THREAT_AT.x - _threat.size.x / 2.0 + roundf(4.0 * jolt * sin(_time * 70.0) / PX) * PX
	elif is_instance_valid(_threat):
		_threat.position.x = THREAT_AT.x - _threat.size.x / 2.0
	if _fx != null:
		_fx.queue_redraw()


## The bolt, the sparks and the rings, over the guards.
func _paint() -> void:
	var from := THREAT_AT + Vector2(0, BOLT_WAIT)
	if _hot < 0:
		# Waiting under what sent it, pulsing.
		var bob := roundf(3.0 * sin(_time * 3.0) / PX) * PX
		_bolt(from + Vector2(0, bob), Vector2.DOWN, 0.85 + 0.15 * sin(_time * 7.0), 0.0)
		return
	var stance := _stances[_hot]
	var hit := stance.position + stance.impact()
	var phase := fmod(_time - _hot_since, CYCLE)
	if phase < FALL:
		var t := phase / FALL
		var at := from.lerp(hit, t * t)
		_bolt(at, (hit - from).normalized(), 1.0, 26.0 * t)
	elif stance.reflects:
		var back := phase - FALL
		if back < BOUNCE:
			var t := back / BOUNCE
			var at := hit.lerp(from - Vector2(0, 40), 1.0 - (1.0 - t) * (1.0 - t))
			_bolt(at, (from - hit).normalized(), 1.0, 26.0)
			_ring(hit, back / 0.3, SHINE)
		elif back < BOUNCE + 0.3:
			_ring(from - Vector2(0, 40), (back - BOUNCE) / 0.3, BOLT)
	else:
		_sparks(hit, phase - FALL)
		_ring(hit, (phase - FALL) / 0.25, BOLT_CORE)


## The bolt: a chunky comet in blocks, its head at `at`, going `way`, with a
## tail as long as `tail`.
func _bolt(at: Vector2, way: Vector2, glow: float, tail: float) -> void:
	var steps := int(tail / 4.0) + 3
	for i in range(steps, 0, -1):
		var along := at - way * i * 5.0
		var fade := 1.0 - float(i) / (steps + 1)
		var r := maxf(2.0, 11.0 * fade)
		_blob(along, r, Color(BOLT_DEEP, 0.7 * fade * glow))
	_blob(at, 20.0, Color(BOLT, 0.18 * glow))
	_blob(at, 13.0, Color(BOLT, glow))
	_blob(at, 7.0, Color(BOLT_CORE, glow))


## A round blot of blocks.
func _blob(at: Vector2, radius: float, ink: Color) -> void:
	var c := (at / PX).round() * PX
	var cells := int(radius / PX)
	for y in range(-cells, cells + 1):
		var half := int(sqrt(maxf(cells * cells - y * y, 0.0)))
		_fx.draw_rect(Rect2(c + Vector2(-half * PX, y * PX), Vector2((half * 2 + 1) * PX, PX)), ink)


## A ring of blocks opening out from `at`, `t` from 0 to 1.
func _ring(at: Vector2, t: float, ink: Color) -> void:
	if t < 0.0 or t > 1.0:
		return
	var radius := 10.0 + 46.0 * t
	var count := 20
	for i in count:
		var spot := at + Vector2.from_angle(TAU * i / count) * radius
		_fx.draw_rect(Rect2((spot / PX).round() * PX, Vector2(PX * 2, PX * 2)), Color(ink, 1.0 - t))


## The sparks of a blow taken on a shield, `age` seconds after it.
func _sparks(at: Vector2, age: float) -> void:
	var life := 0.6
	if age > life:
		return
	var fade := 1.0 - age / life
	for dir: Vector2 in _spark_dirs:
		var spot := at + dir * age + Vector2(0, 260.0 * age * age)
		var ink := BOLT_CORE.lerp(BOLT, age / life)
		_fx.draw_rect(Rect2((spot / PX).round() * PX, Vector2(PX * 3, PX * 3)), Color(ink, fade))
		_fx.draw_rect(Rect2(((spot - dir * 0.03) / PX).round() * PX, Vector2(PX, PX)), Color(BOLT, fade * 0.6))


## One guard: the item, big, on a brass plinth, its name and what it would do.
## Under the hand it lifts and the plinth lights up.
class Stance extends Control:
	signal clicked

	const PLINTH_Y := 206.0
	const PLINTH := Vector2(170, 22)
	const BRASS := Color("c9a44a")
	const BRASS_HI := Color("f0d27a")
	const BRASS_LO := Color("6e5320")
	const SHADOW := Color(0, 0, 0, 0.45)

	## Hovered (or the keyboard is on it).
	var hot := false
	## How hard the bolt just hit it (1 at the blow, down to 0).
	var struck := 0.0
	var reflects := false
	var _item: ItemView
	var _lit := 0.0
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func setup(option: Dictionary, answer: String) -> void:
		var def: ItemDef = option.get("item")
		reflects = def != null and def.id == &"mirror"
		_item = ItemView.new(ITEM_SCALE)
		_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_item.set_item(def)
		_item.position = Vector2((size.x - _item.size.x) / 2.0, PLINTH_Y - _item.size.y + 4.0)
		add_child(_item)
		var heading := UI.label(option.get("label", "?"), 20, UI.GOLD, true)
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.position = Vector2(0, PLINTH_Y + 30.0)
		heading.size = Vector2(size.x, 26)
		add_child(heading)
		var about := UI.label(answer, 14, UI.CREAM)
		about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.mouse_filter = Control.MOUSE_FILTER_IGNORE
		about.position = Vector2(4, PLINTH_Y + 58.0)
		about.size = Vector2(size.x - 8, 40)
		add_child(about)

	## Where the bolt meets it, from the stance's corner.
	func impact() -> Vector2:
		return _item.position + Vector2(_item.size.x / 2.0, _item.size.y * 0.42)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _process(delta: float) -> void:
		_time += delta
		_lit = move_toward(_lit, 1.0 if hot else 0.0, delta / 0.15)
		if _item != null:
			var rest := PLINTH_Y - _item.size.y + 4.0
			var lift := roundf((10.0 * _lit + 3.0 * sin(_time * 1.6)) / PX) * PX
			# A shield is knocked down by the blow; a mirror only flashes.
			var knock := 0.0 if reflects else roundf(8.0 * struck / PX) * PX
			_item.position.y = rest - lift + knock
			var flash := struck if reflects else struck * 0.4
			_item.modulate = Color(1.0 + flash, 1.0 + flash, 1.0 + flash * 1.2)
		queue_redraw()

	func _draw() -> void:
		var middle := size.x / 2.0
		# The shadow of the item on the plinth, smaller as it lifts.
		var shadow_w := roundf((110.0 - 30.0 * _lit) / PX) * PX
		draw_rect(Rect2(Vector2(middle - shadow_w / 2.0, PLINTH_Y - 4.0), Vector2(shadow_w, 4.0)), SHADOW)
		# The plinth: a brass slab seen a little from above, in blocks.
		var left := middle - PLINTH.x / 2.0
		var top := Rect2(Vector2(left, PLINTH_Y), Vector2(PLINTH.x, 8.0))
		var face := Rect2(Vector2(left + 4.0, PLINTH_Y + 8.0), Vector2(PLINTH.x - 8.0, PLINTH.y - 8.0))
		draw_rect(top, BRASS.lerp(BRASS_HI, _lit))
		draw_rect(Rect2(top.position, Vector2(top.size.x, PX)), BRASS_HI)
		draw_rect(face, BRASS_LO.lerp(BRASS, 0.5 * _lit))
		draw_rect(Rect2(face.position + Vector2(0, face.size.y - PX), Vector2(face.size.x, PX)), BRASS_LO.darkened(0.4))
		# Rivets along the face.
		for i in 5:
			var x := face.position.x + 12.0 + i * (face.size.x - 24.0) / 4.0
			draw_rect(Rect2(Vector2(roundf(x / PX) * PX, face.position.y + 4.0), Vector2(PX * 2, PX * 2)), BRASS_HI.lerp(BRASS_LO, 0.3))
		# Under the hand, a glow round the item: steel blue for a mirror,
		# warm for anything else.
		if _lit > 0.0 and _item != null:
			var glow := Rect2(_item.position, _item.size).grow(6.0)
			var ink := Color(SHINE if reflects else BRASS_HI, 0.5 * _lit)
			var arm := 14.0
			var bar := PX * 2.0
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var at := glow.position + glow.size * corner
				draw_rect(Rect2(at - Vector2(corner.x * arm, corner.y * bar), Vector2(arm, bar)), ink)
				draw_rect(Rect2(at - Vector2(corner.x * bar, corner.y * arm), Vector2(bar, arm)), ink)
