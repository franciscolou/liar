extends CanvasLayer
## The way from one screen to the next. One node hung on the root, above every
## scene: it covers the screen, changes the scene behind the cover and then
## uncovers the new one. `Transition.go(path, Transition.DOORS)` takes the
## place of `change_scene_to_file(path)`.
##
## Each style is something of the saloon, drawn in code in the blocks of the
## shop stall:
## - DOORS: the two leaves of a plank door slam shut and swing open again
##   (walking into the saloon, or out of it);
## - KEYHOLE: the screen closes down to a keyhole in a door and opens from it
##   (knocking on the door of a room);
## - DEAL: card backs are dealt all over the screen and turned over (the
##   match begins);
## - GATHER: the cards are thrown in, swept into one deck and taken away (the
##   match is over).
##
## A second `go` before the first one is over only changes where it ends.
## Nothing here touches the state of a match: the dice are its own.
##
## No class_name: use preload.

const NODE_NAME := "Transition"
const DOORS := &"doors"
const KEYHOLE := &"keyhole"
const DEAL := &"deal"
const GATHER := &"gather"
## Seconds each style takes to cover the screen and to uncover it.
const TIMES := {
	DOORS: [0.45, 0.7],
	KEYHOLE: [0.55, 0.65],
	DEAL: [0.75, 0.75],
	GATHER: [0.6, 0.9],
}
## The least time the screen stays covered.
const HOLD := 0.18
## A frame that took longer than this (the next scene loading) counts as this.
const LONGEST_FRAME := 1.0 / 30.0
const SOUND_DIR := "res://assets/sounds/"
const SIZE := Vector2(1152, 648)

enum Phase { IDLE, COVER, HOLD, UNCOVER }

var _style := DOORS
var _target := ""
var _phase := Phase.IDLE
var _t := 0.0  # how far into the phase, 0 to 1 (seconds, while it holds)
var _last := 0
var _screen: Screen
var _hole: ColorRect
var _sfx: Dictionary = {}  # name -> AudioStreamPlayer


## Covers the screen in `style`, changes to the scene at `path` and uncovers
## it. With `cut` the scene changes at once and the cover is already there:
## for leaving a scene that must not go on running under it (the table).
static func go(path: String, style := DOORS, cut := false) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var node: Node = root.get_node_or_null(NODE_NAME)
	if node == null:
		node = new()
		node.name = NODE_NAME
		# The root is busy while a scene is on its way in.
		root.add_child.call_deferred(node)
	node._go(path, style, cut)


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = Screen.new()
	_screen.size = SIZE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.hide()
	add_child(_screen)
	_hole = ColorRect.new()
	_hole.size = SIZE
	_hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = KEYHOLE_SHADER
	_hole.material = look
	_hole.hide()
	add_child(_hole)
	set_process(false)


func _go(path: String, style: StringName, cut: bool) -> void:
	_target = path
	var viewport := get_viewport()
	if viewport != null:
		# Nothing is typed into the screen that is leaving.
		viewport.gui_release_focus()
	match _phase:
		Phase.IDLE:
			_style = style
			_screen.style = style
			_screen.deal()
			_last = Time.get_ticks_msec()
			_enter(Phase.COVER)
			if cut:
				_t = 1.0
			else:
				_play({DOORS: "ui_doors_shut", KEYHOLE: "ui_lock", DEAL: "ui_deal", GATHER: "ui_deal"}[style])
			set_process(true)
			_show()
		Phase.UNCOVER:
			# Back over the screen, from wherever the cover had got to.
			_phase = Phase.COVER
			_t = 1.0 - _t
	if cut and _phase == Phase.COVER:
		_t = 1.0
		_process(0.0)


func _enter(phase: Phase) -> void:
	_phase = phase
	_t = 0.0


func _process(_delta: float) -> void:
	# By the clock: the table may have left time slowed down.
	var now := Time.get_ticks_msec()
	var delta := minf((now - _last) / 1000.0, LONGEST_FRAME)
	_last = now
	match _phase:
		Phase.COVER:
			_t = minf(_t + delta / TIMES[_style][0], 1.0)
			if _t >= 1.0 and is_inside_tree():
				_enter(Phase.HOLD)
				_change()
		Phase.HOLD:
			_t += delta
			var scene := get_tree().current_scene
			if scene != null and scene.is_node_ready():
				if _target != "":
					_change()
				elif _t >= HOLD:
					_enter(Phase.UNCOVER)
					_play({DOORS: "ui_doors_open", KEYHOLE: "ui_unlock", DEAL: "ui_flip", GATHER: "ui_gather"}[_style])
		Phase.UNCOVER:
			_t = minf(_t + delta / TIMES[_style][1], 1.0)
			if _t >= 1.0:
				_enter(Phase.IDLE)
				set_process(false)
				_screen.hide()
				_hole.hide()
				offset = Vector2.ZERO
				return
	_show()


func _change() -> void:
	var path := _target
	_target = ""
	get_tree().change_scene_to_file(path)


## Puts on the screen the cover as it is now.
func _show() -> void:
	# 0: nothing in the way. 1: the screen is covered.
	var cover := 1.0
	match _phase:
		Phase.COVER:
			cover = _t
		Phase.UNCOVER:
			cover = 1.0 - _t
	_screen.show()
	_screen.cover = cover
	_screen.leaving = _phase == Phase.UNCOVER
	_screen.queue_redraw()
	_hole.visible = _style == KEYHOLE
	if _style == KEYHOLE:
		# Slow near the keyhole, fast when the whole door is out of sight.
		(_hole.material as ShaderMaterial).set_shader_parameter("open", pow(1.0 - cover, 2.4))
	# The doors shake the room as they meet.
	offset = Vector2.ZERO
	if _style == DOORS and _phase == Phase.HOLD:
		var slam := maxf(1.0 - _t / HOLD, 0.0)
		offset = Vector2(0, roundf(sin(_t * 70.0) * 5.0 * slam))


func _play(sound: String) -> void:
	if not is_inside_tree():
		return
	if not _sfx.has(sound):
		var stream: AudioStream = null
		var path := "%s%s.wav" % [SOUND_DIR, sound]
		if ResourceLoader.exists(path):
			stream = load(path)
		elif FileAccess.file_exists(path):
			# Not imported yet (the editor has not rescanned): read the file directly.
			stream = AudioStreamWAV.load_from_file(path)
		var player: AudioStreamPlayer = null
		if stream != null:
			player = AudioStreamPlayer.new()
			player.stream = stream
			player.bus = Settings.SFX_BUS
			add_child(player)
		_sfx[sound] = player
	if _sfx[sound] != null:
		_sfx[sound].play()


## The door the keyhole is cut in: planks, a brass escutcheon round the hole
## and, through the hole, the screen. `open` goes from 0 (shut) to 1 (the
## hole is wider than the screen).
const KEYHOLE_SHADER := "
shader_type canvas_item;

uniform float open = 1.0;
const vec2 SCREEN = vec2(1152.0, 648.0);
const float BLOCK = 6.0;
const float WIDEST = 2400.0;

float keyhole(vec2 p, float r) {
	float head = length(p - vec2(0.0, -0.45 * r)) - 0.62 * r;
	float down = clamp((p.y + 0.1 * r) / (1.1 * r), 0.0, 1.0);
	float body = max(abs(p.x) - mix(0.24, 0.5, down) * r, max(-0.1 * r - p.y, p.y - r));
	return min(head, body);
}

void fragment() {
	vec2 px = (floor(UV * SCREEN / BLOCK) + 0.5) * BLOCK;
	float d = keyhole(px - SCREEN * 0.5 - vec2(0.0, 10.0), max(open * WIDEST, 0.001));
	float plank = floor(px.x / 48.0);
	vec3 wood = mod(plank, 2.0) < 1.0 ? vec3(0.231, 0.133, 0.086) : vec3(0.2, 0.11, 0.07);
	if (mod(px.x, 48.0) < BLOCK) {
		wood = vec3(0.118, 0.063, 0.039);
	}
	// The grain: a few strokes, always the same ones on the same plank.
	float mark = fract(sin(plank * 12.9898 + floor(px.y / 54.0) * 78.233) * 43758.5453);
	if (abs(mod(px.x, 48.0) - 12.0 - mark * 24.0) < BLOCK * 0.5 && mod(px.y, 54.0) < 12.0 + mark * 30.0) {
		wood = vec3(0.165, 0.086, 0.051);
	}
	vec3 color = wood * 0.8;
	if (d < BLOCK) {
		color = vec3(0.086, 0.047, 0.031);
	} else if (d < BLOCK * 3.0) {
		// Lit from the top left.
		color = px.x + px.y < SCREEN.x * 0.5 + SCREEN.y * 0.5 ? vec3(0.902, 0.737, 0.298) : vec3(0.72, 0.56, 0.2);
	} else if (d < BLOCK * 4.0) {
		color = vec3(0.49, 0.337, 0.086);
	} else if (d < BLOCK * 5.0) {
		color = wood * 0.45;
	}
	COLOR = vec4(color, d < 0.0 && open > 0.0005 ? 0.0 : 1.0);
}
"


## What is drawn over the scene: the doors or the cards. It also keeps the
## mouse away from the screen underneath.
class Screen extends Control:
	const PX := 2.0
	const INK := Color("160c08")
	const WALL: Array[Color] = [Color("3b2216"), Color("331c12")]
	const SEAM := Color("1e100a")
	const GRAIN := Color("2a160d")
	const FRAME := Color("4a2e1a")
	const FRAME_LIGHT := Color("6b4526")
	const FRAME_DARK := Color("2e1b0e")
	const BRASS := Color("e6bc4c")
	const BRASS_SHADE := Color("b8902f")
	const BRASS_DARK := Color("7d5616")
	const PLANK := 48.0
	const RAIL := 30.0
	const STILE := 26.0
	## The pull of a door: a plate with a ring, in blocks of 4 px.
	const PULL := [
		".####.",
		"#o##o#",
		"######",
		"#+--+#",
		"#|..|#",
		"#|..|#",
		"#|..|#",
		"#|..|#",
		"#+--+#",
		"######",
		"#o##o#",
		".####.",
	]
	const CARD := Vector2(110, 200)
	const COLUMNS := 12
	const ROWS := 4
	const STEP := Vector2(100, 170)
	## Where the dealer's hand is: under the screen.
	const DEALER := Vector2(576, 800)
	const DECK := Vector2(576, 324)

	var style := DOORS
	var cover := 0.0
	## The cover is on its way out (it may leave by another way than it came).
	var leaving := false
	var _back: Texture2D
	var _cards: Array = []  # {slot, turn, spin, order, from}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Lays the cards out anew: no two deals look the same.
	func deal() -> void:
		_back = UI.tex(UI.CARD_BACK)
		_cards.clear()
		var order := range(COLUMNS * ROWS)
		order.shuffle()
		for i in COLUMNS * ROWS:
			var cell := Vector2(i % COLUMNS, floorf(float(i) / COLUMNS))
			var slot := SIZE * 0.5 + (cell - Vector2(COLUMNS - 1, ROWS - 1) * 0.5) * STEP
			slot += Vector2(randf_range(-5, 5), randf_range(-5, 5))
			var out := (slot - SIZE * 0.5).normalized()
			_cards.append({
				"slot": slot,
				"cell": cell,
				"turn": randf_range(-0.07, 0.07),
				"spin": randf_range(-2.5, 2.5),
				"order": float(order[i]) / (COLUMNS * ROWS - 1),
				"from": slot + out * 760.0,
			})
		# Dealt last, drawn on top.
		_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)

	func _draw() -> void:
		match style:
			DOORS:
				_draw_doors()
			DEAL, GATHER:
				_draw_cards()

	# --- the doors -----------------------------------------------------------------

	func _draw_doors() -> void:
		# They fall shut faster and faster, and open the way a door is pushed.
		var shut := cover * cover if not leaving else smoothstep(0.0, 1.0, cover)
		var leaf := SIZE.x * 0.5
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.45 * shut))
		for side in 2:
			# The right leaf is the left one in a mirror.
			var flip := -1.0 if side == 1 else 1.0
			var x := (shut - 1.0) * leaf
			draw_set_transform(Vector2(SIZE.x if side == 1 else 0.0, 0.0), 0.0, Vector2(flip, 1.0))
			_draw_leaf(x, leaf, 1.0 - shut)
		draw_set_transform(Vector2.ZERO)

	## One leaf, `leaf` wide, with its outer edge at `x`; `ajar` is how far it
	## is from shut.
	func _draw_leaf(x: float, leaf: float, ajar: float) -> void:
		var h := SIZE.y
		# The shadow it throws on the floor ahead of it.
		for step in 6:
			draw_rect(Rect2(x + leaf + step * 6.0, 0, 6.0, h), Color(0, 0, 0, (0.3 - step * 0.05) * minf(ajar * 8.0, 1.0)))
		draw_rect(Rect2(x, 0, leaf, h), INK)
		var plank := 0
		var left := x
		while left < x + leaf - STILE:
			var width := minf(PLANK, x + leaf - STILE - left)
			draw_rect(Rect2(left, 0, width, h), WALL[plank % 2])
			draw_rect(Rect2(left, 0, PX, h), SEAM)
			draw_rect(Rect2(left + PX, 0, PX, h), Color(1, 1, 1, 0.03))
			for stroke in 7:
				var mark := plank * 7 + stroke * 13
				var gx := left + 8.0 + (mark * 5 % 16) * PX
				var gy := 40.0 + (mark * 37 % 280) * PX
				if gx < left + width - PX:
					draw_rect(Rect2(gx, gy, PX, 14.0 + (mark % 5) * 8.0), GRAIN)
			left += PLANK
			plank += 1
		# The rails across the planks, each nailed to every one of them.
		for y: float in [0.0, (h - RAIL) * 0.5, h - RAIL]:
			draw_rect(Rect2(x, y, leaf, RAIL), FRAME)
			draw_rect(Rect2(x, y, leaf, PX), FRAME_LIGHT)
			draw_rect(Rect2(x, y + RAIL - PX, leaf, PX), FRAME_DARK)
			draw_rect(Rect2(x, y + RAIL, leaf, PX * 2.0), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(x, y + 8.0, leaf, PX), BRASS_DARK)
			draw_rect(Rect2(x, y + RAIL - 10.0, leaf, PX), BRASS_DARK)
			var nail := x + PLANK * 0.5
			while nail < x + leaf - STILE:
				draw_rect(Rect2(nail - 3.0, y + 12.0, 6.0, 6.0), BRASS_DARK)
				draw_rect(Rect2(nail - 3.0, y + 12.0, 4.0, 4.0), BRASS)
				nail += PLANK
		# The stile where the two leaves meet.
		var stile := x + leaf - STILE
		draw_rect(Rect2(stile, 0, STILE, h), FRAME)
		draw_rect(Rect2(stile, 0, PX, h), FRAME_LIGHT)
		draw_rect(Rect2(stile + 8.0, 0, PX, h), BRASS_SHADE)
		draw_rect(Rect2(x + leaf - PX * 2.0, 0, PX * 2.0, h), INK)
		draw_rect(Rect2(x + leaf - PX * 3.0, 0, PX, h), FRAME_DARK)
		# The pull.
		var at := Vector2(stile - 40.0, (h - PULL.size() * 4.0) * 0.5)
		draw_rect(Rect2(at + Vector2(4, 6), Vector2(24, PULL.size() * 4.0)), Color(0, 0, 0, 0.4))
		for row in PULL.size():
			var line: String = PULL[row]
			for column in line.length():
				var color := BRASS
				match line[column]:
					".":
						continue
					"o":
						color = Color("f1e3c0")
					"-", "|", "+":
						color = BRASS_DARK
				if column == line.length() - 1 or row == PULL.size() - 1:
					color = BRASS_SHADE if color == BRASS else color
				draw_rect(Rect2(at + Vector2(column, row) * 4.0, Vector2(4, 4)), color)

	# --- the cards -----------------------------------------------------------------

	func _draw_cards() -> void:
		# The cloth under the cards: their round corners leave gaps.
		var cloth := smoothstep(0.6, 0.95, cover) if not leaving else smoothstep(0.82, 1.0, cover)
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, cloth))
		var t := 1.0 - cover if leaving else cover
		for card: Dictionary in _cards:
			var at: Vector2 = card.slot
			var turn: float = card.turn
			var squash := Vector2.ONE
			if not leaving and style == DEAL:
				# Dealt one by one from the dealer's hand, spinning.
				var u := clampf((t - card.order * 0.62) / 0.38, 0.0, 1.0)
				if u <= 0.0:
					continue
				var eased := 1.0 - pow(1.0 - u, 3.0)
				at = DEALER.lerp(card.slot, eased)
				turn += card.spin * (1.0 - eased)
			elif not leaving:
				# Thrown in from all sides.
				var u := clampf((t - card.order * 0.5) / 0.5, 0.0, 1.0)
				if u <= 0.0:
					continue
				var eased := 1.0 - pow(1.0 - u, 3.0)
				at = (card.from as Vector2).lerp(card.slot, eased)
				turn += card.spin * 0.5 * (1.0 - eased)
			elif style == DEAL:
				# Turned over, in a wave from the top left.
				var wave: float = (card.cell.x + card.cell.y * 1.5) / (COLUMNS - 1 + (ROWS - 1) * 1.5)
				var u := clampf((t - wave * 0.6) / 0.4, 0.0, 1.0)
				if u >= 1.0:
					continue
				squash = Vector2(cos(u * PI * 0.5), 1.0 + 0.12 * sin(u * PI))
			else:
				# Swept into one deck, which is then taken off the table.
				var u := clampf((t - card.order * 0.3) / 0.4, 0.0, 1.0)
				var eased := smoothstep(0.0, 1.0, u)
				at = (card.slot as Vector2).lerp(DECK + Vector2(0, -card.order * 6.0), eased)
				turn *= 1.0 - eased * 0.8
				var away := clampf((t - 0.76) / 0.24, 0.0, 1.0)
				at.y += away * away * 560.0
			draw_set_transform(at, turn, squash)
			draw_texture_rect(_back, Rect2(-CARD * 0.5 + Vector2(3, 4), CARD), false, Color(0, 0, 0, 0.3))
			draw_texture_rect(_back, Rect2(-CARD * 0.5, CARD), false)
		draw_set_transform(Vector2.ZERO)
