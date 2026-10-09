extends CanvasLayer
## The way from one screen to the next. One node hung on the root, above every
## scene: it covers the screen, changes the scene behind the cover and then
## uncovers the new one. `Transition.go(path, Transition.DOORS)` takes the
## place of `change_scene_to_file(path)`.
##
## Each style is something of the saloon, drawn in code, in blocks:
## - DOORS: the two leaves of a plank door slam shut and swing open again
##   (walking into the saloon, or out of it);
## - KEYHOLE: the screen closes down to a keyhole in a door and opens from it
##   (knocking on the door of a room);
## - DEAL: card backs are dealt all over the screen (the match begins);
## - GATHER: the cards are thrown in from all sides (the match is over).
## Either way the cards leave the same way: swept into one deck in the middle
## of the screen, which is then taken away.
##
## The wood of both doors is one shader (WOOD): boards with their own tone,
## grain that wanders and goes round the knots, worn patches, nails.
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
	DEAL: [0.75, 0.9],
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
var _doors: ColorRect
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
	_doors = _shaded(DOORS_SHADER)
	_hole = _shaded(KEYHOLE_SHADER)
	set_process(false)


## A sheet over the whole screen, painted by the shader in `code`.
func _shaded(code: String) -> ColorRect:
	var sheet := ColorRect.new()
	sheet.size = SIZE
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = code
	sheet.material = look
	sheet.hide()
	add_child(sheet)
	return sheet


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
					_play({DOORS: "ui_doors_open", KEYHOLE: "ui_unlock", DEAL: "ui_gather", GATHER: "ui_gather"}[_style])
		Phase.UNCOVER:
			_t = minf(_t + delta / TIMES[_style][1], 1.0)
			if _t >= 1.0:
				_enter(Phase.IDLE)
				set_process(false)
				_screen.hide()
				_doors.hide()
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
	_doors.visible = _style == DOORS
	if _style == DOORS:
		# They fall shut faster and faster, and open the way a door is pushed.
		var shut := smoothstep(0.0, 1.0, cover) if _phase == Phase.UNCOVER else cover * cover
		(_doors.material as ShaderMaterial).set_shader_parameter("shut", shut)
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


## Shared by the two doors. Everything is counted in cells (the blocks the
## door is drawn in), and a board is a step of tone(): dark to light.
const WOOD := "
const vec2 SCREEN = vec2(1152.0, 648.0);
const vec3 BRASS_LIT = vec3(0.96, 0.86, 0.52);
const vec3 BRASS = vec3(0.902, 0.737, 0.298);
const vec3 BRASS_SHADE = vec3(0.72, 0.565, 0.184);
const vec3 BRASS_DARK = vec3(0.49, 0.337, 0.086);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float soft(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 tone(float level) {
	if (level < 0.5) return vec3(0.086, 0.047, 0.031);
	if (level < 1.5) return vec3(0.118, 0.063, 0.039);
	if (level < 2.5) return vec3(0.165, 0.086, 0.051);
	if (level < 3.5) return vec3(0.200, 0.110, 0.071);
	if (level < 4.5) return vec3(0.231, 0.133, 0.086);
	if (level < 5.5) return vec3(0.290, 0.180, 0.102);
	return vec3(0.40, 0.26, 0.145);
}

// The wood of board `id` at cell `c`. The grain runs along y; the board is
// `width` cells across.
float grain(vec2 c, float id, float width) {
	float level = 3.0 + floor(hash(vec2(id, 3.0)) * 2.0);
	// A knot now and then, and the grain goes round it.
	float stretch = floor(c.y / 110.0);
	vec2 roll = vec2(hash(vec2(id, stretch)), hash(vec2(stretch + 7.0, id)));
	vec2 knot = vec2(floor(4.0 + roll.x * (width - 8.0)), floor(stretch * 110.0 + 15.0 + roll.y * 80.0));
	vec2 off = (c - knot) * vec2(1.0, 0.45);
	float ring = hash(vec2(id + 13.0, stretch + 5.0)) < 0.45 ? length(off) : 99.0;
	float x = c.x - sign(off.x) * floor(3.0 * exp(-ring * ring / 40.0) + 0.5);
	x += floor(sin(c.y * 0.05 + id * 5.0) * 1.2 + 0.5);
	// Streaks, each broken into pieces of its own length.
	float streak = hash(vec2(x, id + 1.0));
	float piece = hash(vec2(x + id * 31.0, floor((c.y + streak * 90.0) / (26.0 + streak * 44.0))));
	if (streak < 0.24 && piece < 0.75) {
		level -= 1.0;
	} else if (streak > 0.84 && piece < 0.6) {
		level += 1.0;
	}
	// Worn patches, dithered.
	float wear = soft(c * vec2(0.11, 0.035) + id * 17.0);
	if (mod(c.x + c.y, 2.0) < 1.0) {
		level += wear > 0.68 ? 1.0 : (wear < 0.27 ? -1.0 : 0.0);
	}
	if (ring < 1.6) {
		level = 1.0;
	} else if (ring < 2.7) {
		level = 2.0;
	} else if (ring < 3.6) {
		level = 5.0;
	} else if (ring < 4.5) {
		level = 2.0;
	}
	return level;
}

// A wall of upright planks `width` cells wide. With `cut`, each is made of
// lengths of that many cells, butted and nailed where they meet.
float planks(vec2 c, float width, float cut) {
	float n = floor(c.x / width);
	float x = c.x - n * width;
	float id = n * 3.0;
	float along = 50.0;
	if (cut > 0.0) {
		float y = c.y + floor(hash(vec2(n, 21.0)) * cut);
		id += floor(y / cut) * 57.0;
		along = mod(y, cut);
	}
	float level = grain(vec2(x, c.y), id, width);
	if (x < 1.0) {
		return 0.0;
	}
	if (x < 2.0) {
		level += 1.0;
	} else if (x >= width - 1.0) {
		level -= 1.0;
	}
	if (cut > 0.0) {
		if (along < 1.0) {
			level = 1.0;
		} else if (along < 2.0) {
			level += 1.0;
		}
		bool column = (x >= 4.0 && x < 6.0) || (x >= width - 6.0 && x < width - 4.0);
		bool row = (along >= 5.0 && along < 7.0) || (along >= cut - 6.0 && along < cut - 4.0);
		if (column && row) {
			// A nail head, lit from the top left.
			bool lit = (x == 4.0 || x == width - 6.0) && (along == 5.0 || along == cut - 6.0);
			level = lit ? 6.0 : 0.0;
		}
	}
	return level;
}
"


## The saloon doors: two leaves of planks on strap hinges, with brass-studded
## rails, a stile where they meet and a pull. The right leaf is the left one
## in a mirror. `shut` goes from 0 (out of sight) to 1 (the leaves meet).
const DOORS_SHADER := "shader_type canvas_item;
" + WOOD + "
uniform float shut = 0.0;
const float PX = 2.0;
// In cells: the leaf, its rails, the stile at each edge and its planks.
const vec2 LEAF = vec2(288.0, 324.0);
const float RAIL = 15.0;
const float HINGED = 9.0;
const float STILE = 13.0;
const float PLANK = 19.0;
const vec2 PULL = vec2(255.0, 150.0);
const vec3 IRON = vec3(0.105, 0.095, 0.1);
const vec3 IRON_LIT = vec3(0.3, 0.28, 0.29);

vec3 door(vec2 c) {
	vec3 color = tone(planks(vec2(c.x - HINGED, c.y), PLANK, 0.0));
	// Which rail this is (0: none) and how far down it.
	float rail = 0.0;
	float y = 0.0;
	float mid = floor((LEAF.y - RAIL) * 0.5);
	if (c.y < RAIL) {
		rail = 1.0;
		y = c.y;
	} else if (c.y >= mid && c.y < mid + RAIL) {
		rail = 2.0;
		y = c.y - mid;
	} else if (c.y >= LEAF.y - RAIL) {
		rail = 3.0;
		y = c.y - LEAF.y + RAIL;
	} else {
		// The shadow a rail throws on the planks under it.
		float under = c.y < mid ? c.y - RAIL : c.y - mid - RAIL;
		color *= under < 1.0 ? 0.55 : (under < 2.0 ? 0.75 : (under < 3.0 ? 0.9 : 1.0));
	}
	if (c.x < HINGED) {
		color = tone(c.x < 1.0 ? 0.0 : (c.x >= HINGED - 1.0 ? 1.0 : grain(c, 300.0, HINGED) + 1.0));
	}
	if (rail > 0.0) {
		// The grain of a rail runs across.
		float level = grain(vec2(y, c.x), 200.0 + rail, RAIL) + 1.0;
		color = tone(y < 1.0 ? 6.0 : (y >= RAIL - 1.0 ? 1.0 : level));
		if (y == 3.0 || y == RAIL - 4.0) {
			color = BRASS_DARK;
		}
		// A brass stud over every plank.
		vec2 stud = vec2(mod(c.x - HINGED, PLANK) - 8.0, y - 6.0);
		if (c.x >= HINGED && stud.x >= 0.0 && stud.x < 3.0 && stud.y >= 0.0 && stud.y < 3.0) {
			color = stud.x + stud.y < 1.0 ? BRASS_LIT : (stud.x > 1.0 || stud.y > 1.0 ? BRASS_DARK : BRASS);
		}
		if (rail != 2.0) {
			// The strap of a hinge: a knuckle at the edge, then a tongue
			// that narrows to a point, riveted down.
			float reach = 78.0;
			float half_width = min(3.0, floor((reach - c.x) / 3.0));
			if (c.x < 5.0 && y >= 2.0 && y < RAIL - 2.0) {
				color = c.x == 1.0 ? IRON_LIT : IRON;
			} else if (c.x < reach && abs(y - 7.0) <= half_width) {
				color = y - 7.0 == -half_width ? IRON_LIT : IRON;
				if (y == 7.0 && mod(c.x, 14.0) == 9.0) {
					color = IRON_LIT;
				}
			}
		}
	}
	// The stile where the two leaves meet.
	float stile = c.x - LEAF.x + STILE;
	if (stile >= 0.0) {
		color = tone(stile < 1.0 ? 6.0 : grain(vec2(stile, c.y), 400.0, STILE) + 1.0);
		if (stile == 4.0) {
			color = BRASS_SHADE;
		} else if (stile >= STILE - 2.0) {
			color = tone(0.0);
		} else if (stile >= STILE - 3.0) {
			color = tone(2.0);
		}
	}
	// The pull: a plate with a ring, in blocks of two cells.
	vec2 plate = c - PULL;
	vec2 cast = plate - vec2(2.0, 3.0);
	if (cast.x >= 0.0 && cast.x < 12.0 && cast.y >= 0.0 && cast.y < 24.0) {
		color *= 0.6;
	}
	if (plate.x >= 0.0 && plate.x < 12.0 && plate.y >= 0.0 && plate.y < 24.0) {
		vec2 b = floor(plate / 2.0);
		bool corner = (b.x == 0.0 || b.x == 5.0) && (b.y == 0.0 || b.y == 11.0);
		bool hole = b.x >= 2.0 && b.x <= 3.0 && b.y >= 4.0 && b.y <= 7.0;
		if (!corner && !hole) {
			if (b.x >= 1.0 && b.x <= 4.0 && b.y >= 3.0 && b.y <= 8.0) {
				color = BRASS_DARK;
			} else if ((b.x == 1.0 || b.x == 4.0) && (b.y == 1.0 || b.y == 10.0)) {
				color = vec3(0.945, 0.89, 0.753);
			} else if (b.x == 5.0 || b.y == 11.0) {
				color = BRASS_SHADE;
			} else {
				color = plate.x < 1.0 || plate.y < 1.0 ? BRASS_LIT : BRASS;
			}
		}
	}
	// The lamps hang high: the door is darker towards the floor.
	return color * (1.05 - 0.04 * floor(c.y / 54.0));
}

void fragment() {
	vec2 at = UV * SCREEN;
	float leaf = SCREEN.x * 0.5;
	// From the nearer side of the screen, and from the hinges of that leaf.
	float side = at.x < leaf ? at.x : SCREEN.x - at.x;
	float x = side + floor((1.0 - shut) * leaf / PX) * PX;
	if (x < leaf) {
		COLOR = vec4(door(floor(vec2(x, at.y) / PX)), 1.0);
	} else {
		// The room goes dark, and each leaf throws a shadow ahead of it.
		float cast = max(0.3 - floor((x - leaf) / 6.0) * 0.05, 0.0) * min((1.0 - shut) * 8.0, 1.0);
		COLOR = vec4(0.0, 0.0, 0.0, 0.45 * shut + cast * (1.0 - 0.45 * shut));
	}
}
"


## The door the keyhole is cut in: planks, a brass escutcheon round the hole
## and, through the hole, the screen. `open` goes from 0 (shut) to 1 (the
## hole is wider than the screen).
const KEYHOLE_SHADER := "shader_type canvas_item;
" + WOOD + "
uniform float open = 1.0;
const float BLOCK = 3.0;
const float WIDEST = 2400.0;

float keyhole(vec2 p, float r) {
	float head = length(p - vec2(0.0, -0.45 * r)) - 0.62 * r;
	float down = clamp((p.y + 0.1 * r) / (1.1 * r), 0.0, 1.0);
	float body = max(abs(p.x) - mix(0.24, 0.5, down) * r, max(-0.1 * r - p.y, p.y - r));
	return min(head, body);
}

void fragment() {
	vec2 cell = floor(UV * SCREEN / BLOCK);
	vec2 px = (cell + 0.5) * BLOCK;
	float d = keyhole(px - SCREEN * 0.5 - vec2(0.0, 10.0), max(open * WIDEST, 0.001));
	vec3 wood = tone(planks(cell, 20.0, 150.0)) * 0.9;
	vec3 color = wood;
	// Lit from the top left.
	bool lit = px.x + px.y < SCREEN.x * 0.5 + SCREEN.y * 0.5;
	if (d < 6.0) {
		color = vec3(0.086, 0.047, 0.031);
	} else if (d < 9.0) {
		color = lit ? BRASS_SHADE : BRASS_LIT;
	} else if (d < 21.0) {
		color = lit ? BRASS : BRASS_SHADE;
		if (d >= 13.5 && d < 16.5) {
			color = lit ? BRASS_SHADE : BRASS_DARK;
		}
	} else if (d < 24.0) {
		color = lit ? BRASS_LIT : BRASS_DARK;
	} else if (d < 27.0) {
		color = BRASS_DARK;
	} else if (d < 36.0) {
		color = wood * (d < 30.0 ? 0.4 : (d < 33.0 ? 0.6 : 0.8));
	}
	COLOR = vec4(color, d < 0.0 && open > 0.0005 ? 0.0 : 1.0);
}
"


## What is drawn over the scene when it is cards. Whatever the style, it also
## keeps the mouse away from the screen underneath.
class Screen extends Control:
	const INK := Color("160c08")
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
				"turn": randf_range(-0.07, 0.07),
				"spin": randf_range(-2.5, 2.5),
				"order": float(order[i]) / (COLUMNS * ROWS - 1),
				"from": slot + out * 760.0,
			})
		# Dealt last, drawn on top.
		_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)

	func _draw() -> void:
		# The doors are a sheet of their own (see DOORS_SHADER).
		if style == DEAL or style == GATHER:
			_draw_cards()

	# --- the cards -----------------------------------------------------------------

	func _draw_cards() -> void:
		# The cloth under the cards: their round corners leave gaps.
		var cloth := smoothstep(0.6, 0.95, cover) if not leaving else smoothstep(0.82, 1.0, cover)
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, cloth))
		var t := 1.0 - cover if leaving else cover
		for card: Dictionary in _cards:
			var at: Vector2 = card.slot
			var turn: float = card.turn
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
			else:
				# Swept into one deck, which is then taken off the table.
				var u := clampf((t - card.order * 0.3) / 0.4, 0.0, 1.0)
				var eased := smoothstep(0.0, 1.0, u)
				at = (card.slot as Vector2).lerp(DECK + Vector2(0, -card.order * 6.0), eased)
				turn *= 1.0 - eased * 0.8
				var away := clampf((t - 0.76) / 0.24, 0.0, 1.0)
				at.y += away * away * 560.0
			draw_set_transform(at, turn)
			draw_texture_rect(_back, Rect2(-CARD * 0.5 + Vector2(3, 4), CARD), false, Color(0, 0, 0, 0.3))
			draw_texture_rect(_back, Rect2(-CARD * 0.5, CARD), false)
		draw_set_transform(Vector2.ZERO)
