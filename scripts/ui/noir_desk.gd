extends Control
## The desk the screens before a match are laid on (room_screen.gd and
## setup_screen.gd), and the things that lie on it. One script draws them
## all, in the blocks of the shop's display case (see shop_stall.gd), and
## `kind` says which one a node is:
##
## - DESK: the top of the desk itself, boards under the light of one lamp
##   (a shader over the whole screen), with the odds and ends in `props`;
## - SHEET: a sheet of paper, for whatever is written on it;
## - CLIPBOARD: a board with a clip and a ruled sheet;
## - CASE: an open briefcase seen from above, brown leather with brass
##   fittings, lined with red velvet over foam cut to hold what is in it;
## - PLAQUE: a brass plate screwed to the desk, for a title;
## - NAMEPLATE: the block of wood with a brass plate that says whose desk
##   this is;
## - QUILL: the quill pen as a thing of its own, whose barbs give under the
##   mouse as if a finger were run along them (see `quill`).
##
## Each is only a backdrop: the screen puts its own widgets on it, as
## children, and the static helpers at the end dress those widgets for the
## surface they are on (ink on paper, a rubber stamp, a brass plate).
## No class name: preload it.

const Transition := preload("res://scripts/ui/transition.gd")

enum Kind { DESK, SHEET, CLIPBOARD, CASE, PLAQUE, NAMEPLATE, QUILL }

const PX := 2.0
const SCREEN := Vector2(1152, 648)

const PAPER := Color("e2d4ae")
const PAPER_LIGHT := Color("f0e6c8")
const PAPER_DARK := Color("c6b488")
const PAPER_SHADE := Color("a8966c")
const TELEGRAM := Color("dcc890")
## Paper that has been in a drawer for thirty years (see `aged`).
## Paper that has only yellowed: still whole, and easy to read.
const DIM_PAPER := Color("d0bf93")
const OLD_PAPER := Color("c9b27e")
const OLD_TELEGRAM := Color("bd9f63")
const OLD_STAIN := Color("5a3814")
## How deep the edge of an old sheet can be eaten into.
const WORN := 8.0
const BLOT := Color("0b090d")
## Length of the steel nib of the quill, ferrule included.
const NIB := 40.0
## Where the vane of the quill starts, from its point.
const QUILL_BARE := 62.0
## The barbs of a QUILL under a finger: the fastest finger they follow, how
## far they give (px), and the spring that brings them back. The damping is
## a little over critical (2 * sqrt(spring)): they go straight back to rest,
## without swinging past it (the user found the swinging "jelly-like").
const QUILL_FASTEST := 900.0
const QUILL_GIVE := 20.0
## How hard a finger resting on the vane parts the barbs under it, and how
## much shorter a barb pushed all the way over lies.
const QUILL_PRESS := 3200.0
## How far along the pen a finger is felt, to either side of it (px): only
## the barbs right under it give (the user found a wider touch unreal).
const QUILL_TOUCH := 9.0
const QUILL_FLATTEN := 0.3
const QUILL_SPRING := 260.0
const QUILL_DAMPING := 34.0
const QUILL := Color("efe9da")
const QUILL_UNDER := Color("d6cebb")
const QUILL_TIP := Color("7d6f5c")
const HORN := Color("e6d9b4")
const COIN := Color("d9a840")
const COIN_LIGHT := Color("f3d573")
const COIN_SHADE := Color("b07f24")
const COIN_DARK := Color("6b4a12")
const INK := Color("2a2018")
const INK_FADED := Color("75654c")
const INK_RED := Color("a3281c")
const INK_BLUE := Color("27386b")
const INK_GREEN := Color("3d5a22")

const WOOD := Color("4a2e1a")
const WOOD_LIGHT := Color("6b4526")
const WOOD_DARK := Color("2e1b0e")
const BOARD := Color("5c3d24")
## The briefcase: its hide, its lining, how much of the lid shows along the
## top and how wide the rim round the well is.
const HIDE := Color("7a4824")
const HIDE_LIGHT := Color("9c6636")
const LEATHER_DARK := Color("3a2110")
## The lining is a jeweller's: dark, and bright only where it catches light.
const VELVET_DEEP := Color("160205")
const VELVET := Color("27050a")
const VELVET_LIGHT := Color("430a12")
const VELVET_SHEEN := Color("6c1520")
## The case is seen from a little in front: how much of the lid standing at
## the far side shows and how far it narrows towards its far edge (not at
## all: the user found a tapered lid odd), the rim down the sides, the
## rim at the hinges (head) and at the near side (foot), and how much of
## the near wall shows.
const CASE_LID := 110.0
const CASE_LEAN := 0.0
const CASE_RIM := 20.0
const CASE_HEAD := 12.0
const CASE_FOOT := 10.0
const CASE_FRONT := 30.0
## The light of both screens is the lantern of the menu: a little dim and
## warm, and less of it far from the lamp. Laid over everything on the desk
## and multiplied into it (see `lamplight`). It is steady: the user did not
## like it flickering.
const LAMPLIGHT_SHADER := "shader_type canvas_item;
render_mode blend_mul;

uniform vec2 lamp = vec2(576.0, 260.0);
uniform float dim = 0.93;

void fragment() {
	vec2 px = floor(UV * vec2(1152.0, 648.0) / 2.0) * 2.0;
	float far = smoothstep(0.25, 1.25, length((px - lamp) / vec2(1.35, 1.0)) / 640.0);
	COLOR = vec4(vec3(1.0, 0.95, 0.85) * (dim - far * 0.1), 1.0);
}
"
## Things dragged off the desk do not all start at once: the last one starts
## this far into the slide. And how far past the edge of the screen they go
## (shadows, and whatever sticks out of their boxes).
const SLIDE_SPREAD := 0.35
const SLIDE_PAST := 90.0
## How far to either side of its place a prop of the desk may reach (the
## coins and the thrown cards are the widest).
const PROP_REACH := 150.0
## Props marked `live` answer the mouse. Thrown cards: how much of the mouse's
## speed a card under it picks up, how fast that is lost on the felt-less wood,
## how much an off-centre push turns it, and how far from where it was thrown
## down it may be pushed.
const CARD_CATCH := 0.45
const CARD_DRAG := 7.0
const CARD_TORQUE := 0.00004
const CARD_ROAM := 90.0
const CARD_TWIST := 0.6
const CARD_FASTEST := 2400.0
## How close to the edge of the screen the middle of a card may be pushed.
const CARD_MARGIN := 36.0
## Coins: how closely the glint follows the mouse, and how fast it comes and
## goes.
const GLINT_FOLLOW := 18.0
const GLINT_FADE := 6.0
const BRASS := Color("b98a2e")
const BRASS_LIGHT := Color("e6bc4c")
const BRASS_DARK := Color("7d5616")
const STEEL := Color("8e949a")
const STEEL_LIGHT := Color("d2d6da")
const STEEL_DARK := Color("4c5056")

## A paper clip, the top of it past the edge of the sheet.
const CLIP := [
	"..###..",
	".#...#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	"...#.#.",
	"...#.#.",
	"....#..",
]
## How many of its rows are above the sheet.
const CLIP_OUT := 3
## Where the sheet of a clipboard is on its board, and how much narrower and
## shorter than the board it is.
const SHEET_AT := Vector2(10, 18)
const SHEET_LESS := Vector2(20, 28)

## The boards of the desk run across the screen; the lamp lights a pool of
## them and the rest falls into the dark, in steps.
const DESK_SHADER := "
uniform vec2 lamp = vec2(576.0, 260.0);
uniform float reach = 620.0;
const float PX = 2.0;

void fragment() {
	vec2 cell = floor(UV * SCREEN / PX);
	vec3 wood = tone(planks(vec2(cell.y, cell.x), 37.0, 0.0));
	vec2 off = (cell * PX - lamp) / vec2(1.35, 1.0);
	float glow = 1.0 - smoothstep(0.1, 1.0, length(off) / reach);
	float level = glow * 8.0;
	float low = floor(level);
	float edge = mod(cell.x + cell.y, 2.0) < 1.0 ? 0.3 : 0.7;
	level = (low + (level - low > edge ? 1.0 : 0.0)) / 8.0;
	vec3 warmth = mix(vec3(0.8, 0.86, 1.0), vec3(1.12, 1.0, 0.82), level);
	COLOR = vec4(wood * mix(0.42, 1.75, level) * warmth, 1.0);
}
"

var kind := Kind.DESK
## SHEET: the colour of the paper.
var tone := PAPER:
	set(value):
		tone = value
		queue_redraw()
## SHEET and CLIPBOARD: the first ruled line, from the top of the sheet (on
## a clipboard the sheet starts at SHEET_AT), and the distance from one to
## the next (0: plain paper).
var ruled_from := 0.0:
	set(value):
		ruled_from = value
		queue_redraw()
var ruled := 0.0:
	set(value):
		ruled = value
		queue_redraw()
## SHEET: a red line down the left margin, this far from the edge (0: none).
var margin := 0.0
## SHEET: the bottom right corner is folded over.
var dog_ear := true
## SHEET: an old sheet: the edges eaten into and browned, foxed all over,
## folded in four once. It has no dog ear.
var aged := false
## SHEET and CLIPBOARD: the paper has gone brown towards its edges, though it
## is whole (an aged sheet always has).
var browned := false
## SHEET, aged: the bottom right corner was torn off.
var torn := false
## SHEET: a paper clip on the top edge, this far from the left (0: none).
var clip_at := 0.0
## SHEET: the ring a glass left on it (radius 0: none).
var stain := Vector3.ZERO
## SHEET: a dotted border, like a telegram form.
var bordered := false
## SHEET: it comes off the desk a little under the mouse.
var lifts := false
## SHEET: ink that got on the paper, a Vector3 for each mark: where (x, y)
## and how big the drop is. A negative size is a smear instead, wiped while
## it was wet: faint, and that many pixels long.
var inked: Array[Vector3] = []
## CASE: the foam ridges that part its compartments: how far down each is.
var ridges: Array[float] = []:
	set(value):
		ridges = value
		queue_redraw()
## CASE: the hollows cut in the foam, one for each thing it holds, in the
## case's own coordinates.
var sockets: Array[Rect2] = []:
	set(value):
		sockets = value
		queue_redraw()
## NAMEPLATE: where the brass plate is on the block.
var plate := Rect2()
## PLAQUE and NAMEPLATE: the brass is lit.
var lit := false:
	set(value):
		lit = value
		queue_redraw()
## DESK: what lies around on it: {kind, at, turn}. Kinds: &"ring" (the mark of
## a glass), &"glass", &"ashtray", &"cards" (a few, face down: fanned by
## `count` and `fan`, or thrown down as `lay` says, [x, y, turn] for each, at
## `scale`), &"coins" (two stacks and some loose ones), &"quill" (a feather
## pen `length` long, its nib at `at`) and &"ink" (a blot `size` across, with
## its spatter).
var props: Array = []:
	set(value):
		props = value
		queue_redraw()

## QUILL: how long the pen is.
var span := 300.0
## QUILL: where the finger is, in the pen's own coordinates, instead of the
## mouse. For looking at the pen from a tool, which cannot hold the mouse
## still over the window; null follows the mouse.
var finger: Variant = null

## QUILL: how far the barbs of each column are pushed along the pen, and how
## fast they are moving, for the upper side of the vane and the lower one.
var _bend: Array[PackedFloat32Array] = []
var _swing: Array[PackedFloat32Array] = []
var _finger := Vector2.ZERO
var _touched := false
## DESK: how far its props have been dragged off it (see `slide`).
var bare := 0.0:
	set(value):
		bare = value
		queue_redraw()

var _lift := 0.0
## DESK: what the live props are doing, by their index in `props`: for cards,
## each card's push (`off`, `vel`, `spin`, `twirl`); for coins, the glint
## (`at`, `shine`) and where the tops of the coins were last drawn (`tops`).
var _stir: Dictionary = {}
var _mouse := Vector2.INF
var _home := Vector2.ZERO
var _homed := false
var _wood: ColorRect


## One of the things above, as large as `rect` and where it says.
static func make(what: Kind, rect: Rect2):
	var thing := new()
	thing.kind = what
	thing.position = rect.position
	thing.size = rect.size
	thing.pivot_offset = rect.size / 2.0
	return thing


## The desk, over the whole screen, lit from `lamp`.
static func desk(lamp := Vector2(576, 260), reach := 620.0):
	var thing := new()
	thing.kind = Kind.DESK
	thing.set_anchors_preset(Control.PRESET_FULL_RECT)
	thing._lay_wood(lamp, reach)
	return thing


## The quill pen, its point at `at`, lying towards `turn`. Unlike the one in
## `props`, this one answers the mouse.
static func quill(at: Vector2, turn: float, length := 300.0):
	var thing := new()
	thing.kind = Kind.QUILL
	thing.position = at
	thing.rotation = turn
	thing.span = length
	for side in 2:
		var still := PackedFloat32Array()
		still.resize(int(length / PX) + 1)
		thing._bend.append(still)
		thing._swing.append(still.duplicate())
	return thing


## The light of the lantern, to lay over everything a screen has on its desk
## (after `things`: it is not one of them, and stays when they are dragged
## off). Whatever the screen opens later (the settings) goes over it.
static func lamplight(lamp := Vector2(576, 260)) -> ColorRect:
	var light := ColorRect.new()
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = LAMPLIGHT_SHADER
	look.set_shader_parameter("lamp", lamp)
	light.material = look
	return light


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func _ready() -> void:
	var live := kind == Kind.DESK and props.any(func(prop: Dictionary) -> bool: return prop.get("live", false))
	set_process(lifts or kind == Kind.QUILL or live)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _lay_wood(lamp: Vector2, reach: float) -> void:
	_wood = ColorRect.new()
	_wood.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood.show_behind_parent = true
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = "shader_type canvas_item;\n" + Transition.WOOD + DESK_SHADER
	look.set_shader_parameter("lamp", lamp)
	look.set_shader_parameter("reach", reach)
	_wood.material = look
	add_child(_wood)


## A sheet that lifts follows the mouse by itself: what is written on it
## takes the mouse first, so the sheet is never told.
func _process(delta: float) -> void:
	if kind == Kind.QUILL:
		_ruffle(delta)
		return
	if kind == Kind.DESK:
		_stir_props(delta)
		return
	if not _homed:
		_home = position
		_homed = true
	var at := get_global_transform().affine_inverse() * get_global_mouse_position()
	var over := Rect2(Vector2(0, _lift), size).has_point(at)
	var goal := 4.0 if over else 0.0
	if is_equal_approx(_lift, goal):
		return
	_lift = move_toward(_lift, goal, delta * 40.0)
	# Only up and down: a sheet may be on its way across the desk (see `slide`).
	position.y = _home.y - _lift
	queue_redraw()


## The live props of the desk under the mouse: a thrown card it runs over is
## pushed the way it went, and the coins catch the light where it is.
func _stir_props(delta: float) -> void:
	var at := get_local_mouse_position()
	# Measured over the frame's own time, and only so fast: a mouse coming
	# back into the window, or a slow frame, is not a flick.
	var speed := Vector2.ZERO if _mouse == Vector2.INF or delta <= 0.0 else ((at - _mouse) / delta).limit_length(CARD_FASTEST)
	_mouse = at
	delta = minf(delta, 1.0 / 30.0)
	var moving := false
	for index in props.size():
		var prop: Dictionary = props[index]
		if not prop.get("live", false):
			continue
		match prop.kind:
			&"cards":
				moving = _push_cards(index, prop, at, speed, delta) or moving
			&"coins":
				moving = _shine_coins(index, at, delta) or moving
	if moving:
		queue_redraw()


func _cards_stir(index: int, count: int) -> Dictionary:
	if not _stir.has(index):
		var still: Array[Vector2] = []
		still.resize(count)
		still.fill(Vector2.ZERO)
		var turns: Array[float] = []
		turns.resize(count)
		turns.fill(0.0)
		_stir[index] = {"off": still, "vel": still.duplicate(), "spin": turns, "twirl": turns.duplicate()}
	return _stir[index]


## Only the card on top under the mouse is pushed; true while any still moves.
func _push_cards(index: int, prop: Dictionary, at: Vector2, speed: Vector2, delta: float) -> bool:
	var lay: Array = _lay_of(prop)
	var stir := _cards_stir(index, lay.size())
	var grown: float = prop.get("scale", 1.0)
	var card := Rect2(Vector2(-27.5, -50), Vector2(55, 100))
	if bare <= 0.0 and speed.length() > 30.0:
		for i in range(lay.size() - 1, -1, -1):
			var place: Array = lay[i]
			var spot: Vector2 = prop.at + Vector2(place[0], place[1]) + stir.off[i]
			var turn: float = prop.get("turn", 0.0) + place[2] + stir.spin[i]
			var local := Transform2D(turn, Vector2(grown, grown), 0.0, spot).affine_inverse() * at
			if not card.has_point(local):
				continue
			var catch := minf(1.0, delta * 25.0)
			stir.vel[i] += (speed * CARD_CATCH - stir.vel[i]) * catch
			# Pushed off its middle, it turns as well.
			var arm := at - spot
			stir.twirl[i] += (arm.x * speed.y - arm.y * speed.x) * CARD_TORQUE * catch
			break
	var moving := false
	var drag := exp(-CARD_DRAG * delta)
	for i in lay.size():
		if stir.vel[i].length() < 2.0 and absf(stir.twirl[i]) < 0.02:
			stir.vel[i] = Vector2.ZERO
			stir.twirl[i] = 0.0
			continue
		moving = true
		stir.off[i] += stir.vel[i] * delta
		stir.spin[i] = clampf(stir.spin[i] + stir.twirl[i] * delta, -CARD_TWIST, CARD_TWIST)
		# Never far from the hand it was thrown down with, nor off the desk.
		if stir.off[i].length() > CARD_ROAM:
			stir.off[i] = stir.off[i].limit_length(CARD_ROAM)
			var out: Vector2 = stir.off[i].normalized()
			stir.vel[i] -= out * maxf(stir.vel[i].dot(out), 0.0)
		var home: Vector2 = prop.at + Vector2(lay[i][0], lay[i][1])
		var room := Rect2(Vector2(CARD_MARGIN, CARD_MARGIN), size - Vector2(CARD_MARGIN, CARD_MARGIN) * 2.0)
		var spot: Vector2 = home + stir.off[i]
		var kept := spot.clamp(room.position, room.end)
		if kept != spot:
			stir.off[i] = kept - home
			if kept.x != spot.x:
				stir.vel[i].x = 0.0
			if kept.y != spot.y:
				stir.vel[i].y = 0.0
		stir.vel[i] *= drag
		stir.twirl[i] *= drag
	return moving


## True while the glint is to be seen.
func _shine_coins(index: int, at: Vector2, delta: float) -> bool:
	if not _stir.has(index):
		_stir[index] = {"at": at, "shine": 0.0, "tops": []}
	var stir: Dictionary = _stir[index]
	var over: bool = bare <= 0.0 and stir.tops.any(func(top: Vector2) -> bool: return top.distance_to(at) < 16.0)
	if over:
		stir.at = at if stir.shine <= 0.0 else stir.at.lerp(at, minf(1.0, delta * GLINT_FOLLOW))
	var was: float = stir.shine
	stir.shine = move_toward(stir.shine, 1.0 if over else 0.0, delta * GLINT_FADE)
	return stir.shine > 0.0 or was > 0.0


## The barbs follow a finger run along the vane, part where it goes across
## them, and then go straight back.
func _ruffle(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	var at: Vector2 = finger if finger != null else get_local_mouse_position()
	var speed := ((at - _finger) / delta).limit_length(QUILL_FASTEST) if _touched else Vector2.ZERO
	_finger = at
	_touched = true
	var mid := -sin(clampf(at.x / span, 0.0, 1.0) * PI) * 12.0
	var on := at.x > QUILL_BARE - 8.0 and at.x < span + 24.0 and at.y > mid - 48.0 and at.y < mid + 36.0
	var side := 0 if at.y < mid else 1
	var moving := false
	for half in 2:
		var bend := _bend[half]
		var swing := _swing[half]
		for column in bend.size():
			if on and half == side:
				var away := (column * PX - at.x) / QUILL_TOUCH
				var near := exp(-away * away)
				# Along the pen they lean with the finger; across it they part,
				# each column its own way.
				swing[column] += (speed.x * 12.0 + speed.y * (_roll(column * 3 + half) - 0.5) * 16.0) * near * delta
				# And they open round the finger itself, even when it is still.
				swing[column] += away * near * QUILL_PRESS * delta
			swing[column] += (-QUILL_SPRING * bend[column] - QUILL_DAMPING * swing[column]) * delta
			bend[column] = clampf(bend[column] + swing[column] * delta, -QUILL_GIVE, QUILL_GIVE)
			if absf(bend[column]) > 0.2 or absf(swing[column]) > 2.0:
				moving = true
			else:
				bend[column] = 0.0
				swing[column] = 0.0
	if moving or _lift > 0.0:
		queue_redraw()
	# One more frame after the last barb comes to rest, to draw it at rest.
	_lift = 1.0 if moving else 0.0


func _draw() -> void:
	match kind:
		Kind.QUILL:
			draw_set_transform(Vector2(6, 8).rotated(-rotation))
			_quill(span, true)
			draw_set_transform(Vector2.ZERO)
			_quill(span, false)
		Kind.DESK:
			for index in props.size():
				var prop: Dictionary = props[index]
				var at: Vector2 = prop.at
				if bare > 0.0:
					# Dragged aside with the rest; what is drawn stays the same.
					prop = prop.duplicate()
					# A prop has no box: it is taken to be this wide round its place.
					prop.at = at + Vector2(_dragged(at.x - PROP_REACH, PROP_REACH * 2.0, index, bare), 0.0)
				prop.salt = int(at.x * 3.0 + at.y)
				prop.index = index
				_draw_prop(prop)
		Kind.SHEET:
			_sheet(Rect2(Vector2.ZERO, size))
		Kind.CLIPBOARD:
			_clipboard()
		Kind.CASE:
			_case()
		Kind.PLAQUE:
			_brass_plate(Rect2(Vector2.ZERO, size))
		Kind.NAMEPLATE:
			_nameplate()


## Always the same number for the same `n`, from 0 to 1.
func _roll(n: int) -> float:
	return fposmod(sin(n * 12.9898 + 4.1) * 43758.5453, 1.0)


func _b(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


## What a thing lying on the desk keeps the lamp from: darker close to it.
func _shadow(rect: Rect2, drop: Vector2) -> void:
	draw_rect(Rect2(rect.position + drop * 1.7, rect.size), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(rect.position + drop, rect.size), Color(0, 0, 0, 0.34))


func _sheet(rect: Rect2) -> void:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var ear := 12.0 if dog_ear and not aged else 0.0
	if aged:
		_old_sheet(rect)
	else:
		_shadow(rect, Vector2(3, 4) + Vector2(_lift, _lift) * 1.5)
		# The body, short of the corner that is folded over.
		_b(o.x, o.y, w, h - ear, tone)
		for row in int(ear / PX):
			var width := w - (row + 1) * PX
			_b(o.x, o.y + h - ear + row * PX, width, PX, tone)
			_b(o.x + w - ear, o.y + h - ear + row * PX, width - w + ear, PX, PAPER_SHADE)
		# Lit from the top left.
		_b(o.x, o.y, w, PX, PAPER_LIGHT)
		_b(o.x, o.y, PX, h, PAPER_LIGHT)
		_b(o.x + w - PX, o.y, PX, h - ear, PAPER_DARK)
		_b(o.x, o.y + h - PX, w - ear, PX, PAPER_DARK)
		if ear > 0.0:
			_b(o.x + w - ear - PX, o.y + h - ear - PX, ear + PX, PX, PAPER_DARK)
			_b(o.x + w - ear - PX, o.y + h - ear, PX, ear, PAPER_DARK)
		# It was folded in two once.
		var fold := o.y + roundf(h * 0.52 / PX) * PX
		_b(o.x + PX, fold, w - PX * 2.0, 1, Color(PAPER_LIGHT, 0.8))
		_b(o.x + PX, fold + 1, w - PX * 2.0, 1, Color(PAPER_DARK, 0.55))
	if browned and not aged:
		for band: Array in [[22.0, 0.06], [12.0, 0.08], [5.0, 0.1]]:
			var deep: float = band[0]
			var brown := Color(OLD_STAIN, band[1])
			_b(o.x, o.y, w, deep, brown)
			_b(o.x, o.y + h - deep, w - ear, deep, brown)
			_b(o.x, o.y + deep, deep, h - deep * 2.0, brown)
			_b(o.x + w - deep, o.y + deep, deep, h - deep * 2.0 - ear, brown)
	# From the size in whole pixels: moving a sheet by a fraction of one (see
	# `lifts`) can leave its size a hair short, and every speck would move.
	var seed_of := int(roundf(w) * 7.0 + roundf(h) * 13.0)
	var away := WORN + 2.0 if aged else 4.0
	for speck in int(w * h / (350.0 if aged else 900.0)):
		var speck_x := o.x + away + floorf(_roll(seed_of + speck * 3) * (w - away * 2.0 - 2.0) / PX) * PX
		var speck_y := o.y + away + floorf(_roll(seed_of + speck * 3 + 1) * (h - away * 2.0 - 14.0) / PX) * PX
		var kind_of := _roll(seed_of + speck * 3 + 2)
		var dark := Color(OLD_STAIN, 0.3) if aged else Color(PAPER_DARK, 0.7)
		_b(speck_x, speck_y, PX * (2.0 if kind_of > 0.8 else 1.0), PX, dark if kind_of > 0.35 else Color(PAPER_LIGHT, 0.5 if aged else 0.9))
	if stain.z > 0.0:
		_ring(o + Vector2(stain.x, stain.y), stain.z, stain.z - 4.0, Color(0.42, 0.24, 0.1, 0.2), seed_of)
	for mark in inked.size():
		_ink_mark(o + Vector2(inked[mark].x, inked[mark].y), inked[mark].z, seed_of + mark * 53)
	if ruled > 0.0:
		var rule := o.y + ruled_from
		while rule < o.y + h - 8.0:
			_b(o.x + 6.0, rule, w - 12.0, 1, Color(INK_BLUE, 0.28))
			rule += ruled
	if margin > 0.0:
		_b(o.x + margin, o.y + PX, 1, h - PX * 2.0 - ear, Color(INK_RED, 0.4))
	if bordered:
		var inner := rect.grow(-14.0 if aged else -8.0)
		var x := inner.position.x
		while x < inner.end.x - PX:
			_b(x, inner.position.y, PX * 2.0, PX, Color(INK_FADED, 0.6))
			if x < inner.end.x - ear - 8.0:
				_b(x, inner.end.y - PX, PX * 2.0, PX, Color(INK_FADED, 0.6))
			x += PX * 4.0
		var y := inner.position.y
		while y < inner.end.y - PX:
			_b(inner.position.x, y, PX, PX * 2.0, Color(INK_FADED, 0.6))
			if y < inner.end.y - ear - 8.0:
				_b(inner.end.x - PX, y, PX, PX * 2.0, Color(INK_FADED, 0.6))
			y += PX * 4.0
	if clip_at > 0.0:
		var at := o + Vector2(clip_at, -CLIP_OUT * PX)
		for row in CLIP.size():
			var line: String = CLIP[row]
			for column in line.length():
				if line[column] != "#":
					continue
				var cell := at + Vector2(column, row) * PX
				_b(cell.x + PX, cell.y + PX, PX, PX, Color(0, 0, 0, 0.28))
				_b(cell.x, cell.y, PX, PX, STEEL_LIGHT if column == 1 or row == 0 else STEEL)


## Ink left on a sheet (see `inked`): a drop that fell from the pen, with
## what it threw round itself, or the dry streaks of one that was wiped.
## Mixed into the paper, not laid over it: where two shapes meet there is
## no darker patch.
func _ink_mark(at: Vector2, size: float, salt: int) -> void:
	if size < 0.0:
		var faint := tone.lerp(INK, 0.3)
		for streak in 3:
			var reach := -size * (1.0 - streak * 0.28)
			var x := streak * PX * 2.0
			while x < reach:
				var run := PX * (1.0 + floorf(_roll(salt + streak * 31 + int(x)) * 4.0))
				# It gives out towards the end.
				if _roll(salt + streak * 17 + int(x) + 5) > x / reach * 0.85:
					_b(at.x + x, at.y + streak * PX * 2.0, run, PX, faint)
				x += run + PX
		return
	var wet := tone.lerp(INK, 0.78)
	_disc(at, size, wet)
	for lobe in 2:
		var way := Vector2.from_angle(_roll(salt + lobe * 3) * TAU)
		_disc(((at + way * size * 0.7) / PX).floor() * PX, size * (0.45 + _roll(salt + lobe * 3 + 1) * 0.3), wet)
	for drop in int(3.0 + size):
		var way := Vector2.from_angle(_roll(salt + drop * 5 + 40) * TAU)
		var spot := ((at + way * size * (1.6 + _roll(salt + drop * 5 + 41) * 1.6)) / PX).floor() * PX
		_b(spot.x, spot.y, PX * (2.0 if drop % 3 == 0 else 1.0), PX, wet if drop % 2 == 0 else tone.lerp(INK, 0.45))


## Value noise along a line: the same for the same `at` and `salt`.
func _soft(at: float, salt: int) -> float:
	var low := floori(at)
	var t := at - low
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(_roll(low * 7 + salt), _roll((low + 1) * 7 + salt), t)


## How far the edge of an old sheet is eaten into, `along` one of its sides.
func _bite(along: float, salt: int) -> float:
	var worn := _soft(along / 16.0, salt * 101 + 11) * 3.4 + _roll(int(along) * 3 + salt) * 1.2
	return clampf(floorf(worn - 0.6) * PX, 0.0, WORN - PX)


## The body of an old sheet: ragged all round, browned towards the edges,
## blotched, and worn white along the folds.
func _old_sheet(rect: Rect2) -> void:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var salt := int(roundf(w) * 7.0 + roundf(h) * 13.0)
	var rip := 30.0 if torn else 0.0
	var edge := tone.darkened(0.28)
	_shadow(rect.grow(-PX * 2.0), Vector2(3, 4) + Vector2(_lift, _lift) * 1.5)
	var y := WORN
	while y < h - WORN:
		var left := _bite(y, salt)
		var right := _bite(y, salt + 1) + maxf(0.0, roundf((y - h + rip) * 0.9 / PX) * PX)
		_b(o.x + left, o.y + y, w - left - right, PX, tone)
		_b(o.x + left, o.y + y, PX, PX, edge)
		_b(o.x + w - right - PX, o.y + y, PX, PX, edge)
		y += PX
	var x := WORN
	while x < w - WORN:
		var top := _bite(x, salt + 2)
		_b(o.x + x, o.y + top, 4, WORN - top, tone)
		_b(o.x + x, o.y + top, 4, PX, edge)
		if x < w - WORN - rip:
			var foot := _bite(x, salt + 3)
			_b(o.x + x, o.y + h - WORN, 4, WORN - foot, tone)
			_b(o.x + x, o.y + h - foot - PX, 4, PX, edge)
		x += 4.0
	# Browner towards the edges, where the air got at it.
	var inner := rect.grow(-WORN)
	for band: Array in [[26.0, 0.07], [14.0, 0.09], [6.0, 0.12]]:
		var deep: float = band[0]
		var brown := Color(OLD_STAIN, band[1])
		_b(inner.position.x, inner.position.y, inner.size.x, deep, brown)
		_b(inner.position.x, inner.end.y - deep, inner.size.x - rip, deep, brown)
		_b(inner.position.x, inner.position.y + deep, deep, inner.size.y - deep * 2.0, brown)
		_b(inner.end.x - deep, inner.position.y + deep, deep, inner.size.y - deep * 2.0 - rip, brown)
	# Damp got to it here and there.
	for blotch in 9:
		var size := 8.0 + _roll(salt + blotch * 4) * 22.0
		var at := inner.position + Vector2(34, 34) + Vector2(_roll(salt + blotch * 4 + 1), _roll(salt + blotch * 4 + 2)) * (inner.size - Vector2(80, 80))
		at = (at / PX).floor() * PX
		_disc(at, size, Color(OLD_STAIN, 0.07))
		_ring(at, size, size - PX, Color(OLD_STAIN, 0.1), salt + blotch)
		_disc(at + Vector2(PX, -PX), size * 0.55, Color(OLD_STAIN, 0.06))
	# Folded in four, and the folds have worn pale and begun to split.
	var across := o.y + roundf(h * 0.52 / PX) * PX
	var down := o.x + roundf(w * 0.49 / PX) * PX
	_b(inner.position.x, across, inner.size.x, PX, Color(PAPER_LIGHT, 0.5))
	_b(inner.position.x, across + PX, inner.size.x, 1, Color(OLD_STAIN, 0.4))
	_b(down, inner.position.y, PX, inner.size.y, Color(PAPER_LIGHT, 0.4))
	_b(down + PX, inner.position.y, 1, inner.size.y, Color(OLD_STAIN, 0.3))
	for scuff in 26:
		var along := _roll(salt + scuff * 2 + 60)
		var pale := Color(PAPER_LIGHT, 0.55)
		if scuff % 2 == 0:
			_b(inner.position.x + floorf(along * (inner.size.x - 8.0) / PX) * PX, across - PX + (scuff % 3) * PX, PX * (1 + scuff % 3), PX, pale)
		else:
			_b(down - PX + (scuff % 3) * PX, inner.position.y + floorf(along * (inner.size.y - 8.0) / PX) * PX, PX, PX * (1 + scuff % 3), pale)
	_disc(Vector2(down, across), 6.0, Color(PAPER_LIGHT, 0.4))
	# A split where the fold meets the edge, and a tear in from the top.
	_b(o.x + WORN - PX, across, 18, PX, Color(OLD_STAIN, 0.75))
	var tear := Vector2(o.x + roundf(w * 0.66 / PX) * PX, o.y + PX)
	for step in 9:
		_b(tear.x + (PX if step % 3 == 1 else 0.0) + floorf(step / 4.0) * PX, tear.y + step * PX, PX, PX, Color(OLD_STAIN, 0.8))


func _clipboard() -> void:
	var w := size.x
	var h := size.y
	var board := Rect2(0, 8, w, h - 8)
	_shadow(board, Vector2(4, 5))
	draw_rect(board, BOARD)
	_b(0, board.position.y, w, PX, WOOD_LIGHT)
	_b(0, board.position.y, PX, board.size.y, WOOD_LIGHT)
	_b(w - PX, board.position.y, PX, board.size.y, WOOD_DARK)
	_b(0, h - PX, w, PX, WOOD_DARK)
	# The hardboard: speckled, not grained.
	for speck in 150:
		var x := 4.0 + floorf(_roll(speck * 2 + 900) * (w - 8.0) / PX) * PX
		var y := board.position.y + 4.0 + floorf(_roll(speck * 2 + 901) * (board.size.y - 8.0) / PX) * PX
		_b(x, y, PX, PX, WOOD_DARK if speck % 3 > 0 else WOOD_LIGHT)
	dog_ear = false
	_sheet(Rect2(SHEET_AT, size - SHEET_LESS))
	# The clip: a steel spring plate over the top of the sheet, with the
	# lever that opens it standing past the board.
	var mid := roundf(w / 2.0 / PX) * PX
	var jaw := Rect2(mid - 62, 10, 124, 16)
	draw_rect(Rect2(jaw.position + Vector2(2, 3), jaw.size), Color(0, 0, 0, 0.4))
	draw_rect(jaw, STEEL)
	_b(jaw.position.x, jaw.position.y, jaw.size.x, PX, STEEL_LIGHT)
	_b(jaw.position.x, jaw.end.y - PX * 2.0, jaw.size.x, PX * 2.0, STEEL_DARK)
	_b(jaw.position.x, jaw.position.y + PX * 3.0, jaw.size.x, PX, Color(STEEL_DARK, 0.5))
	var lever := Rect2(mid - 30, 0, 60, 12)
	draw_rect(lever, STEEL_DARK)
	draw_rect(Rect2(lever.position + Vector2(PX, PX), lever.size - Vector2(PX * 2.0, PX)), STEEL)
	_b(lever.position.x + PX, lever.position.y + PX, lever.size.x - PX * 2.0, PX, STEEL_LIGHT)
	_b(mid - 8, 4, 16, 4, INK)
	for x: float in [jaw.position.x + 6.0, jaw.end.x - 10.0]:
		_rivet(Vector2(x, jaw.position.y + 6.0), STEEL_LIGHT, STEEL, STEEL_DARK)


## How far something at `left`, `wide` across, has been dragged when the desk
## is `amount` bare: off the nearer side of the screen, each thing starting
## at a moment of its own (`index` picks it) and gathering speed.
static func _dragged(left: float, wide: float, index: int, amount: float) -> float:
	var late := fposmod(sin(index * 12.9898 + 4.1) * 43758.5453, 1.0) * SLIDE_SPREAD
	var t := clampf((amount - late) / (1.0 - SLIDE_SPREAD), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	if left + wide / 2.0 < SCREEN.x / 2.0:
		return -(left + wide + SLIDE_PAST) * t
	return (SCREEN.x - left + SLIDE_PAST) * t


## Everything a screen has lying on `desk`: its own children, where they
## belong. For `slide`; ask once the screen is built.
static func things(screen: Control, desk: Control) -> Array:
	var found: Array = []
	for child in screen.get_children():
		if child is Control and child != desk:
			found.append({"node": child, "home": child.position.x})
	return found


## Drags `found` (see `things`) and the props of `desk` off the desk, the
## left half of the screen to the left and the right half to the right, as
## `amount` goes from 0 to 1, and back on as it returns to 0.
static func slide(desk: Control, found: Array, amount: float) -> void:
	desk.set(&"bare", amount)
	for index in found.size():
		var node: Control = found[index].node
		if not is_instance_valid(node):
			continue
		var home: float = found[index].home
		node.position.x = home + _dragged(home, node.size.x, index + 7, amount)


## The case lies open and is seen from a little in front of it: the lid
## stands up at the far side, on its hinges and two brass stays, showing its
## lining; then the body, which we look into; then the near wall of it, in
## the shade, with the latches and the handle. Leather outside, stitched,
## capped with brass at the corners; inside, a jeweller's lining over foam,
## with a hollow cut for each thing.
func _case() -> void:
	var w := size.x
	var h := size.y
	var top := Rect2(0, CASE_LID, w, h - CASE_LID - CASE_FRONT)
	var front := Rect2(0, h - CASE_FRONT, w, CASE_FRONT)
	var well := Rect2(CASE_RIM, CASE_LID + CASE_HEAD, w - CASE_RIM * 2.0, top.size.y - CASE_HEAD - CASE_FOOT)
	var thread := HIDE_LIGHT.lightened(0.3)
	_shadow(Rect2(0, CASE_LID, w, h - CASE_LID), Vector2(6, 9))
	# The lid: its far edge is past the top of the screen.
	var row := 0.0
	while row < CASE_LID:
		var lean := roundf((CASE_LID - row) / CASE_LID * CASE_LEAN / PX) * PX
		_b(lean, row, w - lean * 2.0, PX, HIDE.darkened(0.2))
		_b(lean, row, PX * 2.0, PX, HIDE_LIGHT.darkened(0.1))
		_b(w - lean - PX * 2.0, row, PX * 2.0, PX, LEATHER_DARK)
		# Its lining, inside a brass beading.
		var edge := lean + CASE_RIM
		if row >= 12.0 and row < CASE_LID - 10.0:
			_b(edge - 4.0, row, w - edge * 2.0 + 8.0, PX, BRASS_DARK)
			_b(edge - PX, row, w - edge * 2.0 + 4.0, PX, VELVET)
		row += PX
	# The lining again, in rows as wide as the lid is there, for the sheen.
	var band := 12.0
	while band < CASE_LID - 10.0:
		var tall := minf(14.0, CASE_LID - 10.0 - band)
		var lean := roundf((CASE_LID - band - tall) / CASE_LID * CASE_LEAN / PX) * PX + CASE_RIM
		_velvet(Rect2(lean, band, w - lean * 2.0, tall), 2.4, band * 2.4)
		band += tall
	_b(CASE_LEAN + CASE_RIM, 12.0, w - (CASE_LEAN + CASE_RIM) * 2.0, PX, BRASS_DARK)
	_b(CASE_RIM - 4.0, CASE_LID - 10.0, w - CASE_RIM * 2.0 + 8.0, PX, BRASS)
	# Buttoned down in a lattice, like the lid of a jeweller's box.
	var tuft_row := 0
	var tuft := 40.0
	while tuft < CASE_LID - 18.0:
		var lean := (CASE_LID - tuft) / CASE_LID * CASE_LEAN + CASE_RIM
		var count := 12 if tuft_row % 2 == 0 else 11
		for index in count:
			var across := lean + 30.0 + (w - lean * 2.0 - 60.0) * (index + (0.0 if tuft_row % 2 == 0 else 0.5)) / 11.0
			across = roundf(across / PX) * PX
			_b(across - 4.0, tuft - PX, 12, 6, Color(0, 0, 0, 0.45))
			_b(across, tuft, 4, 4, BRASS_DARK)
			_b(across, tuft, PX, PX, BRASS_LIGHT)
		tuft += 26.0
		tuft_row += 1
	# The maker's plate.
	var badge := Rect2(roundf(w / 2.0 / PX) * PX - 30.0, CASE_LID - 36.0, 60, 12)
	draw_rect(Rect2(badge.position + Vector2(PX, PX), badge.size), Color(0, 0, 0, 0.5))
	draw_rect(badge, BRASS_DARK)
	draw_rect(Rect2(badge.position, badge.size - Vector2(PX, PX)), BRASS_LIGHT)
	draw_rect(badge.grow(-PX), BRASS)
	_b(badge.position.x + 10.0, badge.position.y + 5.0, 40, 1, BRASS_DARK)

	# The body, from above.
	draw_rect(top, HIDE)
	for speck in int(w * h / 500.0):
		var grain_x := floorf(_roll(speck * 2 + 300) * (w - 4.0) / PX) * PX
		var grain_y := top.position.y + floorf(_roll(speck * 2 + 301) * (top.size.y - 4.0) / PX) * PX
		_b(grain_x, grain_y, PX * (1 + speck % 2), PX, Color(LEATHER_DARK, 0.5) if speck % 3 > 0 else Color(HIDE_LIGHT, 0.6))
	_b(0, top.position.y, PX, top.size.y, HIDE_LIGHT)
	_b(w - PX, top.position.y, PX, top.size.y, LEATHER_DARK)
	_b(0, top.position.y, w, PX, LEATHER_DARK)
	# Stitched down the sides, in a pale thread.
	var y := top.position.y + 14.0
	while y < top.end.y - 12.0:
		_b(7, y, 1, 4, thread)
		_b(w - 8.0, y, 1, 4, thread)
		y += 8.0
	# A brass beading runs round the mouth of the well.
	draw_rect(well.grow(PX * 3.0), BRASS_DARK)
	draw_rect(Rect2(well.position - Vector2(PX * 3.0, PX * 3.0), well.size + Vector2(PX * 5.0, PX * 5.0)), BRASS_LIGHT)
	draw_rect(well.grow(PX * 2.0), BRASS)
	draw_rect(well.grow(PX), LEATHER_DARK.darkened(0.4))
	_velvet(well, 0.55)
	# Dark under the rim that overhangs it, on the far side and the left.
	for depth in 4:
		var shade := Color(0, 0, 0, 0.42 - depth * 0.1)
		_b(well.position.x, well.position.y + depth * PX, well.size.x, PX, shade)
		_b(well.position.x + depth * PX, well.position.y, PX, well.size.y, shade)
	_b(well.position.x + PX, well.end.y - PX, well.size.x - PX, PX, VELVET_SHEEN)
	_b(well.end.x - PX, well.position.y + PX, PX, well.size.y - PX, VELVET_LIGHT)
	# Foam ridges between the compartments: the pile catches the lamp along
	# the top of them.
	for ridge: float in ridges:
		_b(well.position.x, ridge, well.size.x, 6, VELVET_LIGHT)
		_b(well.position.x, ridge, well.size.x, PX, VELVET_SHEEN)
		_b(well.position.x, ridge + 4.0, well.size.x, PX, VELVET)
		_b(well.position.x, ridge + 6.0, well.size.x, PX, Color(0, 0, 0, 0.5))
		_b(well.position.x, ridge + 8.0, well.size.x, PX, Color(0, 0, 0, 0.22))
	# A hollow cut in the foam for each thing: black at the far edge, where
	# the lamp does not reach, and a bright lip at the near one.
	for socket: Rect2 in sockets:
		draw_rect(socket, VELVET_DEEP.darkened(0.35))
		_b(socket.position.x, socket.position.y, socket.size.x, PX * 2.0, Color(0, 0, 0, 0.5))
		_b(socket.position.x, socket.position.y, PX * 2.0, socket.size.y, Color(0, 0, 0, 0.5))
		_b(socket.position.x - PX, socket.end.y, socket.size.x + PX * 2.0, PX, VELVET_SHEEN)
		_b(socket.end.x, socket.position.y, PX, socket.size.y, VELVET_LIGHT)
		_b(socket.position.x + PX * 2.0, socket.end.y - PX, socket.size.x - PX * 2.0, PX, VELVET)

	# The near wall, in the shade of its own rim.
	draw_rect(front, HIDE.darkened(0.34))
	_b(0, front.position.y, w, PX, HIDE_LIGHT)
	_b(0, front.position.y + PX, w, PX, LEATHER_DARK)
	for depth in 4:
		_b(0, front.position.y + PX * 2.0 + depth * PX, w, PX, Color(0, 0, 0, 0.3 - depth * 0.07))
	_b(0, h - PX, w, PX, LEATHER_DARK.darkened(0.3))
	var x := 18.0
	while x < w - 20.0:
		_b(x, front.position.y + 8.0, 4, 1, Color(thread, 0.7))
		_b(x, h - 6.0, 4, 1, Color(thread, 0.7))
		x += 8.0
	for speck in int(w / 6.0):
		_b(floorf(_roll(speck + 800) * (w - 4.0) / PX) * PX, front.position.y + 10.0 + floorf(_roll(speck + 900) * (CASE_FRONT - 18.0) / PX) * PX, PX * 2.0, PX, Color(LEATHER_DARK, 0.5))
	# The handle, on two brass mounts in the middle of it.
	var grip := Rect2(roundf(w / 2.0 / PX) * PX - 66.0, front.position.y + 10.0, 132, CASE_FRONT - 4.0)
	for post: float in [grip.position.x, grip.end.x - 14.0]:
		_b(post - PX, grip.position.y - PX, 18, 12, BRASS_DARK)
		_b(post - PX, grip.position.y - PX, 16, 10, BRASS)
		_b(post - PX, grip.position.y - PX, 16, PX, BRASS_LIGHT)
		_b(post + PX, grip.position.y + 8.0, 10, grip.size.y - 16.0, LEATHER_DARK)
	draw_rect(Rect2(grip.position.x + 4.0, grip.end.y - 4.0, grip.size.x, 8), Color(0, 0, 0, 0.35))
	_b(grip.position.x, grip.end.y - 10.0, grip.size.x, 10, HIDE)
	_b(grip.position.x, grip.end.y - 10.0, grip.size.x, PX, HIDE_LIGHT)
	_b(grip.position.x, grip.end.y - PX, grip.size.x, PX, LEATHER_DARK)
	var stitch := grip.position.x + 18.0
	while stitch < grip.end.x - 20.0:
		_b(stitch, grip.end.y - 6.0, 4, 1, thread)
		stitch += 8.0

	# Brass: a cap on each corner of the body, round onto the near wall.
	for corner in 4:
		var way := Vector2(-1 if corner % 2 == 1 else 1, -1 if corner >= 2 else 1)
		var at := Vector2(w if way.x < 0.0 else 0.0, front.position.y if way.y < 0.0 else top.position.y)
		for step in 13:
			var long := (13 - step) * PX
			var cell := at + Vector2(0, step * PX) * way
			var strip := Rect2(cell.x - (long if way.x < 0.0 else 0.0), cell.y - (PX if way.y < 0.0 else 0.0), long, PX)
			draw_rect(strip, BRASS_LIGHT if step == 0 else BRASS)
			draw_rect(Rect2(strip.end.x - PX if way.x > 0.0 else strip.position.x, strip.position.y, PX, PX), BRASS_DARK)
		_rivet(at + Vector2(8, 8) * way - Vector2(PX, PX), UI.CREAM, BRASS_LIGHT, BRASS_DARK)
		if way.y < 0.0:
			var side := 0.0 if way.x > 0.0 else w - 22.0
			_b(side, front.position.y + PX, 22, CASE_FRONT - PX, BRASS.darkened(0.25))
			_b(side, front.position.y + PX, 22, PX, BRASS)
			_b(side, h - PX, 22, PX, BRASS_DARK.darkened(0.3))
			_rivet(Vector2(side + 8.0, h - 12.0), BRASS_LIGHT, BRASS, BRASS_DARK)
	# The hinges, and the stays that hold the lid up.
	for hinge: float in [roundf(w * 0.2 / PX) * PX, roundf(w * 0.8 / PX) * PX]:
		_b(hinge - 18.0, CASE_LID - 10.0, 36, 20, BRASS_DARK)
		_b(hinge - 18.0, CASE_LID - 10.0, 34, 18, BRASS)
		_b(hinge - 18.0, CASE_LID - 10.0, 34, PX, BRASS_LIGHT)
		_b(hinge - 18.0, CASE_LID - PX, 34, PX * 2.0, BRASS_DARK)
		for pin: float in [hinge - 14.0, hinge + 8.0]:
			_rivet(Vector2(pin, CASE_LID - 7.0), UI.CREAM, BRASS_LIGHT, BRASS_DARK)
			_rivet(Vector2(pin, CASE_LID + 4.0), UI.CREAM, BRASS_LIGHT, BRASS_DARK)
	# They run from the rim of the body up the side of the lid, clear of
	# what is in the well.
	for stay: float in [8.0, w - 12.0]:
		var sign_of := 1.0 if stay < w / 2.0 else -1.0
		for link in 22:
			_b(stay + sign_of * roundf(link * 0.5) * PX, CASE_LID + 6.0 - link * 4.0, 4, 4, BRASS_DARK if link % 4 == 3 else BRASS_LIGHT)
		_rivet(Vector2(stay, CASE_LID + 6.0), UI.CREAM, BRASS_LIGHT, BRASS_DARK)
	# The latches: a plate on the rim, the hasp folded down the near wall.
	for latch: float in [roundf(w * 0.22 / PX) * PX, roundf(w * 0.78 / PX) * PX]:
		_b(latch - 20.0, front.position.y - CASE_FOOT + PX, 40, CASE_FOOT - PX, BRASS)
		_b(latch - 20.0, front.position.y - CASE_FOOT + PX, 40, PX, BRASS_LIGHT)
		_b(latch - 16.0, front.position.y, 32, CASE_FRONT - 8.0, BRASS_DARK)
		_b(latch - 16.0, front.position.y, 30, CASE_FRONT - 10.0, BRASS.darkened(0.12))
		_b(latch - 16.0, front.position.y, 30, PX, BRASS_LIGHT)
		_b(latch - 5.0, front.position.y + 8.0, 10, 6, UI.INK)
		_b(latch - 5.0, front.position.y + 14.0, 10, PX, BRASS_LIGHT)


## A jeweller's lining over `rect`: a deep red pile that is almost black
## where it turns from the lamp and flares where it turns to it, in streaks
## that run across it slantwise (`lean`: how far a streak drifts sideways
## for each pixel down; `down`: how far the streaks have drifted already,
## for a lining drawn in pieces), ragged from row to row.
func _velvet(rect: Rect2, lean: float, down := 0.0) -> void:
	draw_rect(rect, VELVET)
	var tones := [VELVET_DEEP, VELVET, VELVET_LIGHT, VELVET_SHEEN]
	var wide := rect.size.x
	var y := 0.0
	while y < rect.size.y:
		var ragged := (_roll(int(y + down) * 3 + 17) - 0.5) * 16.0 - y * lean - down
		var since := 0.0
		var level := 1
		var x := 0.0
		while x <= wide:
			var here := -1
			if x < wide:
				var u := (x + ragged) / wide
				var glow := exp(-pow((u - 0.24) / 0.085, 2.0)) + 0.8 * exp(-pow((u - 0.83) / 0.12, 2.0)) - 0.55 * exp(-pow((u - 0.52) / 0.13, 2.0))
				here = 3 if glow > 0.82 else (2 if glow > 0.42 else (1 if glow > -0.2 else 0))
			if here != level:
				if level != 1 and x > since:
					_b(rect.position.x + since, rect.position.y + y, x - since, minf(PX, rect.size.y - y), tones[level])
				since = x
				level = here
			x += 4.0
		y += PX
	# The nap: single tufts lying the other way.
	for speck in int(rect.size.x * rect.size.y / 420.0):
		var nap_x := rect.position.x + 2.0 + floorf(_roll(speck * 2 + 100) * (rect.size.x - 6.0) / PX) * PX
		var nap_y := rect.position.y + floorf(_roll(speck * 2 + 101) * (rect.size.y - 2.0) / PX) * PX
		_b(nap_x, nap_y, PX, PX, Color(VELVET_SHEEN, 0.35) if speck % 3 == 0 else Color(0, 0, 0, 0.3))


func _nameplate() -> void:
	var w := size.x
	var h := size.y
	var all := Rect2(Vector2.ZERO, size)
	_shadow(all, Vector2(4, 6))
	# A block of dark wood, bevelled: the top face catches the lamp.
	draw_rect(all, WOOD)
	_b(0, 0, w, PX * 3.0, WOOD_LIGHT)
	_b(0, 0, w, PX, WOOD_LIGHT.lightened(0.15))
	_b(0, 0, PX, h, WOOD_LIGHT)
	_b(w - PX, PX * 3.0, PX, h - PX * 3.0, WOOD_DARK)
	_b(0, h - PX * 2.0, w, PX * 2.0, WOOD_DARK)
	for stroke in int(w / 30.0):
		var x := 8.0 + floorf(_roll(stroke * 2 + 700) * (w - 50.0) / PX) * PX
		var y := 10.0 + floorf(_roll(stroke * 2 + 701) * (h - 18.0) / PX) * PX
		if not plate.grow(2.0).has_point(Vector2(x, y)):
			_b(x, y, 12.0 + (stroke % 3) * 8.0, PX, Color(WOOD_DARK, 0.6))
	_brass_plate(plate)


## A brass plate, screwed on at both ends.
func _brass_plate(rect: Rect2) -> void:
	var brass := BRASS.lightened(0.16) if lit else BRASS
	draw_rect(Rect2(rect.position + Vector2(PX, PX * 2.0), rect.size), Color(0, 0, 0, 0.45))
	draw_rect(rect, BRASS_DARK)
	draw_rect(Rect2(rect.position, rect.size - Vector2(PX, PX)), BRASS_LIGHT)
	draw_rect(Rect2(rect.position + Vector2(PX, PX), rect.size - Vector2(PX * 2.0, PX * 2.0)), brass)
	# A dull sheen across it.
	var sheen := rect.size.y * 0.4
	_b(rect.position.x + PX, rect.position.y + PX, rect.size.x - PX * 2.0, roundf(sheen / PX) * PX, Color(1, 0.95, 0.75, 0.1))
	# An engraved line just inside the edge.
	var line := rect.grow(-PX * 3.0)
	draw_rect(line, Color(BRASS_DARK, 0.75), false, 1.0)
	for x: float in [rect.position.x + PX * 5.0, rect.end.x - PX * 7.0]:
		_rivet(Vector2(x, rect.position.y + roundf(rect.size.y / 2.0 / PX) * PX - PX), UI.CREAM, BRASS_LIGHT, BRASS_DARK)


func _rivet(at: Vector2, glint: Color, metal: Color, dark: Color) -> void:
	draw_rect(Rect2(at, Vector2(PX * 2.0, PX * 2.0)), dark)
	draw_rect(Rect2(at, Vector2(PX, PX)), glint)
	draw_rect(Rect2(at + Vector2(PX, 0), Vector2(PX, PX)), metal)
	draw_rect(Rect2(at + Vector2(0, PX), Vector2(PX, PX)), metal)


## A disc in blocks, one strip to each row.
func _disc(centre: Vector2, radius: float, color: Color) -> void:
	var y := -radius
	while y < radius:
		var half := floorf(sqrt(maxf(radius * radius - (y + PX / 2.0) * (y + PX / 2.0), 0.0)) / PX) * PX
		if half > 0.0:
			_b(centre.x - half, centre.y + y, half * 2.0, PX, color)
		y += PX


## A ring in blocks, with gaps here and there (`gaps` picks them; 0: whole).
func _ring(centre: Vector2, outer: float, inner: float, color: Color, gaps := 0) -> void:
	var y := -outer
	var row := 0
	while y < outer:
		var mid := y + PX / 2.0
		var far := floorf(sqrt(maxf(outer * outer - mid * mid, 0.0)) / PX) * PX
		var near := floorf(sqrt(maxf(inner * inner - mid * mid, 0.0)) / PX) * PX
		row += 1
		if far > near:
			if gaps == 0 or _roll(gaps + row * 2) > 0.22:
				_b(centre.x - far, centre.y + y, far - near, PX, color)
			if gaps == 0 or _roll(gaps + row * 2 + 1) > 0.22:
				_b(centre.x + near, centre.y + y, far - near, PX, color)
		y += PX


func _draw_prop(prop: Dictionary) -> void:
	var at: Vector2 = prop.at
	var turn: float = prop.get("turn", 0.0)
	match prop.kind:
		&"ring":
			_ring(at, 24.0, 20.0, Color(0, 0, 0, 0.2), prop.get("salt", 1))
		&"glass":
			_disc(at + Vector2(6, 8), 32.0, Color(0, 0, 0, 0.35))
			_disc(at, 32.0, Color("6f6a62"))
			_disc(at, 30.0, Color("c9c6bc"))
			_disc(at, 26.0, Color("5a2f0c"))
			_disc(at + Vector2(-2, -2), 22.0, Color("9a5514"))
			_disc(at + Vector2(-6, -6), 12.0, Color("c07a22"))
			# Two cubes of ice, and the lamp in the rim.
			for cube: Vector2 in [Vector2(-14, -6), Vector2(2, 4)]:
				draw_rect(Rect2(at + cube, Vector2(14, 14)), Color(0.95, 0.9, 0.78, 0.5))
				draw_rect(Rect2(at + cube, Vector2(14, PX)), Color(1, 1, 1, 0.7))
				draw_rect(Rect2(at + cube, Vector2(PX, 14)), Color(1, 1, 1, 0.7))
			_b(at.x - 20, at.y - 26, 10, PX, Color.WHITE)
			_b(at.x - 26, at.y - 20, PX, 8, Color.WHITE)
		&"ashtray":
			_disc(at + Vector2(5, 6), 34.0, Color(0, 0, 0, 0.35))
			_disc(at, 34.0, Color("16110f"))
			_ring(at, 32.0, 28.0, Color("5c5048"))
			_disc(at, 24.0, Color("2c2624"))
			for speck in 14:
				var spot := at + Vector2(_roll(speck + 40) - 0.5, _roll(speck + 60) - 0.5) * 34.0
				draw_rect(Rect2(spot.floor(), Vector2(PX, PX)), Color("7c746c") if speck % 2 == 0 else Color("4a4440"))
			_b(at.x - 26, at.y - 24, 10, PX, Color("a09488"))
			# The cigar, resting in a notch of the rim.
			draw_set_transform(at, turn)
			_b(-8, 1, 62, 8, Color(0, 0, 0, 0.3))
			_b(-6, -4, 58, 8, Color("5e3a1e"))
			_b(-6, -4, 58, PX, Color("86582c"))
			_b(-6, 2, 58, PX, Color("3c2412"))
			_b(34, -4, 6, 8, BRASS_LIGHT)
			_b(36, -4, PX, 8, INK_RED)
			_b(-14, -4, 8, 8, Color("8c8680"))
			_b(-14, -4, 8, PX, Color("b8b2aa"))
			_b(-6, -4, PX, 8, Color("f08020"))
			draw_set_transform(Vector2.ZERO)
		&"cards":
			var back := UI.tex(UI.CARD_BACK)
			var lay := _lay_of(prop)
			var card := Rect2(Vector2(-27.5, -50), Vector2(55, 100))
			var grown: float = prop.get("scale", 1.0)
			var stir: Dictionary = _stir.get(prop.get("index", -1), {})
			for i in lay.size():
				var place: Array = lay[i]
				var spot := at + Vector2(place[0], place[1])
				var spun: float = turn + place[2]
				if not stir.is_empty():
					spot += stir.off[i]
					spun += stir.spin[i]
				draw_set_transform(spot + Vector2(4, 5), spun, Vector2(grown, grown))
				draw_rect(card, Color(0, 0, 0, 0.35))
				draw_set_transform(spot, spun, Vector2(grown, grown))
				if back != null:
					draw_texture_rect(back, card, false)
			draw_set_transform(Vector2.ZERO)
		&"coins":
			# A pile: the stacks stand against each other, loose coins lie at
			# their feet and one leans on them. From the back to the front.
			_coin(at + Vector2(2, -12), 7, 1)
			_coin(at + Vector2(-30, -2), 4, 2, 1)
			_coin(at + Vector2(32, 0), 5, 3)
			_coin(at + Vector2(-56, 14), 1, 4)
			_leaning_coin(at + Vector2(54, 0))
			_coin(at + Vector2(-2, 18), 2, 5, 1)
			_coin(at + Vector2(-32, 30), 1, 6, 1)
			_coin(at + Vector2(30, 32), 1, 7)
			_coin(at + Vector2(88, 26), 1, 8, 1)
			_glint(at + Vector2(-8, -48))
			_glint(at + Vector2(40, 22))
			var stir: Dictionary = _stir.get(prop.get("index", -1), {})
			if prop.get("live", false):
				# Where the tops are, for the glint to know what is metal.
				var tops: Array = []
				for coin: Array in [[Vector2(2, -12), 7, 1], [Vector2(-30, -2), 4, 2], [Vector2(32, 0), 5, 3],
						[Vector2(-56, 14), 1, 4], [Vector2(-2, 18), 2, 5], [Vector2(-32, 30), 1, 6],
						[Vector2(30, 32), 1, 7], [Vector2(88, 26), 1, 8]]:
					tops.append(_coin_top(at + coin[0], coin[1], coin[2]))
				if stir.is_empty():
					_stir[prop.index] = {"at": Vector2.ZERO, "shine": 0.0, "tops": tops}
				else:
					stir.tops = tops
					if stir.shine > 0.0:
						_cursor_glint(stir.at, stir.shine, tops)
		&"quill":
			var length: float = prop.get("length", 240.0)
			draw_set_transform(at + Vector2(6, 8), turn)
			_quill(length, true)
			draw_set_transform(at, turn)
			_quill(length, false)
			draw_set_transform(Vector2.ZERO)
		&"ink":
			_blot(at, prop.get("size", 10.0), prop.get("salt", 1))


## A stack of `high` gold coins seen from above and a little from the front:
## the milled edge of each shows under the one on top of it. `face` is the
## side that is up: 0 the star, 1 the wreath of dots round a boss.
func _coin(at: Vector2, high: int, salt: int, face := 0) -> void:
	var r := 16.0
	_disc(at + Vector2(5, 7), r, Color(0, 0, 0, 0.38))
	var top := at
	for layer in high:
		top = at + Vector2(roundf((_roll(salt * 9 + layer) - 0.5) * 2.0) * PX, -layer * 4.0)
		_disc(top + Vector2(0, 4), r, COIN_DARK)
		_disc(top + Vector2(0, PX), r, COIN_SHADE.darkened(0.12) if layer % 2 == 1 else COIN_SHADE)
		# The milling: fine cuts down the edge, where it faces us.
		var cut := -r + 3.0
		while cut < r - 2.0:
			_b(top.x + cut, top.y + PX + floorf(sqrt(r * r - cut * cut) / PX) * PX - PX, 1, PX, COIN_DARK)
			cut += 4.0
	# Some have been through more hands than others.
	var gold := COIN.darkened(0.1) if salt % 3 == 0 else COIN
	# The face: a raised rim, a field sunk inside it, lit from the top left.
	_disc(top, r, COIN_SHADE)
	_disc(top + Vector2(-PX, -PX), r - PX, COIN_LIGHT)
	_disc(top, r - PX, gold)
	_disc(top, r - 4.0, COIN_DARK)
	_disc(top + Vector2(PX, PX), r - 6.0, COIN_LIGHT)
	_disc(top, r - 6.0, gold.darkened(0.08))
	if face == 0:
		# Struck in the middle: a star of four points, its lit sides bright.
		for arm in 5:
			var half := (2 - absi(arm - 2)) * PX
			_b(top.x - PX - half, top.y - 5.0 + arm * PX, PX * 2.0 + half * 2.0, PX, COIN_DARK)
		_b(top.x - PX, top.y - 9.0, PX * 2.0, 18, COIN_DARK)
		_b(top.x - PX, top.y - 9.0, PX, 16, COIN_LIGHT)
		_b(top.x - 5.0, top.y - PX, 8, PX, COIN_LIGHT)
	else:
		# The other side: a boss in the middle and a wreath of dots round it.
		for dot in 8:
			var spot := top + (Vector2.from_angle(dot * TAU / 8.0 + 0.4) * 7.0 / PX).round() * PX
			_b(spot.x - PX, spot.y - PX, PX, PX, COIN_DARK)
			_b(spot.x - PX, spot.y - PX, 1, 1, COIN_LIGHT)
		_disc(top + Vector2(PX, PX), 4.0, COIN_DARK)
		_disc(top, 4.0, COIN_LIGHT)
		_b(top.x, top.y, PX, PX, gold)
	# The lamp on the rim.
	_b(top.x - 10.0, top.y - 14.0, 8, PX, Color(1, 1, 0.9))
	_b(top.x - 14.0, top.y - 10.0, PX, 6, Color(1, 1, 0.9))


## Where the face of the top coin of a stack drawn by `_coin` is.
func _coin_top(at: Vector2, high: int, salt: int) -> Vector2:
	var layer := high - 1
	return at + Vector2(roundf((_roll(salt * 9 + layer) - 0.5) * 2.0) * PX, -layer * 4.0)


## The lamp caught by the coins where the mouse is: the gold under it lit,
## only where there is a face of a coin, and a star of light over it.
func _cursor_glint(at: Vector2, shine: float, tops: Array) -> void:
	var centre := (at / PX).floor() * PX
	var twinkle := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.012)
	var reach := 14.0
	var y := -reach
	while y <= reach:
		var x := -reach
		while x <= reach:
			var cell := centre + Vector2(x, y)
			var near := 1.0 - Vector2(x, y).length() / reach
			if near > 0.0 and tops.any(func(top: Vector2) -> bool: return top.distance_to(cell + Vector2(1, 1)) < 15.0):
				# Stepped like the lamp elsewhere: brighter in rings towards the middle.
				var step := ceilf(near * 3.0) / 3.0
				draw_rect(Rect2(cell, Vector2(PX, PX)), Color(1, 0.96, 0.78, step * 0.7 * shine))
			x += PX
		y += PX
	var arm := roundf(12.0 * twinkle / PX) * PX
	var light := Color(1, 1, 0.92, 0.95 * shine)
	_b(centre.x - arm, centre.y, arm * 2.0 + PX, PX, light)
	_b(centre.x, centre.y - arm, PX, arm * 2.0 + PX, light)
	# Shorter rays across, as the lamp breaks on a milled edge.
	for d in [-4.0, -2.0, 2.0, 4.0]:
		_b(centre.x + d, centre.y + d, PX, PX, Color(1, 1, 0.92, 0.55 * shine))
		_b(centre.x + d, centre.y - d, PX, PX, Color(1, 1, 0.92, 0.55 * shine))
	_b(centre.x - PX, centre.y - PX, PX * 3.0, PX * 3.0, Color(1, 1, 0.95, 0.6 * shine))
	_b(centre.x, centre.y, PX, PX, Color(1, 1, 1, shine))


## A coin on its edge, leaning on the stack to its left: seen almost side on.
func _leaning_coin(at: Vector2) -> void:
	_oval(at + Vector2(6, 12), 12.0, 6.0, Color(0, 0, 0, 0.38))
	_oval(at + Vector2(4, PX), 8.0, 16.0, COIN_DARK)
	_oval(at + Vector2(PX, 0), 8.0, 16.0, COIN_SHADE)
	_oval(at, 8.0, 16.0, COIN)
	_oval(at, 4.0, 12.0, COIN_DARK)
	_oval(at + Vector2(PX, 0), 4.0, 10.0, COIN.darkened(0.08))
	_b(at.x - 6.0, at.y - 10.0, PX, 8, Color(1, 1, 0.9))
	_b(at.x - 4.0, at.y - 14.0, PX, 4, Color(1, 1, 0.9))


## The places of the thrown cards of a &"cards" prop: [x, y, turn] each.
func _lay_of(prop: Dictionary) -> Array:
	var lay: Array = prop.get("lay", [])
	if not lay.is_empty():
		return lay
	var count: int = prop.get("count", 3)
	var fan: float = prop.get("fan", 0.22)
	for index in count:
		lay.append([index * 9.0, -absf(index - (count - 1) / 2.0) * 2.0, (index - (count - 1) / 2.0) * fan])
	return lay


## A star of light, where the lamp catches an edge.
func _glint(at: Vector2) -> void:
	_b(at.x - 5.0, at.y, 12, PX, Color(1, 1, 0.92, 0.9))
	_b(at.x, at.y - 5.0, PX, 12, Color(1, 1, 0.92, 0.9))
	_b(at.x - PX, at.y - PX, 6, 6, Color(1, 1, 0.92, 0.35))
	_b(at.x, at.y, PX, PX, Color.WHITE)


## An ellipse in blocks, one strip to each row.
func _oval(centre: Vector2, across: float, down: float, color: Color) -> void:
	var y := -down
	while y < down:
		var mid := (y + PX / 2.0) / down
		var half := floorf(across * sqrt(maxf(1.0 - mid * mid, 0.0)) / PX) * PX
		if half > 0.0:
			_b(centre.x - half, centre.y + y, half * 2.0, PX, color)
		y += PX


## A blot of ink `size` across, with the drops that flew from it.
func _blot(at: Vector2, size: float, salt: int) -> void:
	_disc(at, size, BLOT)
	for lobe in 4:
		var way := Vector2.from_angle(_roll(salt + lobe * 3) * TAU)
		_disc(((at + way * size * 0.75) / PX).floor() * PX, size * (0.4 + _roll(salt + lobe * 3 + 1) * 0.35), BLOT)
	for drop in int(5 + size * 0.6):
		var way := Vector2.from_angle(_roll(salt + drop * 5 + 40) * TAU)
		var far := size * (1.5 + _roll(salt + drop * 5 + 41) * 2.6)
		var spot := ((at + way * far) / PX).floor() * PX
		var wide := maxf(PX, floorf(size * 0.34 * _roll(salt + drop * 5 + 42) / PX) * PX)
		if wide <= PX:
			_b(spot.x, spot.y, PX * (2.0 if drop % 3 == 0 else 1.0), PX, BLOT)
		else:
			_disc(spot, wide, BLOT)
			# A drop that flew far leaves a tail pointing back.
			_b(spot.x - roundf(way.x * wide / PX) * PX, spot.y - roundf(way.y * wide / PX) * PX, PX, PX, BLOT)
	# Still wet: the lamp is in it.
	if size >= 6.0:
		_b(at.x - floorf(size * 0.45 / PX) * PX, at.y - floorf(size * 0.5 / PX) * PX, PX * 2.0, PX, Color("4a4658"))
		_b(at.x - floorf(size * 0.45 / PX) * PX - PX, at.y - floorf(size * 0.5 / PX) * PX + PX, PX, PX, Color("2c2a38"))


## A quill pen lying along x, the point at the origin: a steel nib for India
## ink in a brass ferrule (slit, breather hole, the point black and wet),
## the bare horn of the shaft, then the vane, its barbs swept
## back towards the tip, fluffy at the base, split here and there and dark
## at the end. With `shade`, only the shadow it throws.
func _quill(length: float, shade: bool) -> void:
	var dark := Color(0, 0, 0, 0.3)
	var bare := QUILL_BARE
	var x := bare
	while x < length:
		var v := (x - bare) / (length - bare)
		var mid := roundf(-sin(x / length * PI) * 12.0 / PX) * PX
		var swell := pow(sin(PI * pow(v, 0.62)), 0.75)
		var column := int(x / PX)
		var split := _roll(column * 5 + 3)
		for side in 2:
			var reach := (38.0 if side == 0 else 26.0) * swell
			if v < 0.16:
				reach *= 0.45 + _roll(column * 9 + side) * 0.95
			elif split < 0.05:
				reach *= 0.3 + side * 0.25
			elif split < 0.13:
				reach *= 0.82
			var sway := _bend[side][column] if not _bend.is_empty() and column < _bend[side].size() else 0.0
			# A barb that leans lies lower.
			reach *= 1.0 - QUILL_FLATTEN * absf(sway) / QUILL_GIVE
			var k := PX
			while k <= reach:
				# The tips give the most; at the shaft the barbs are held.
				var given := roundf(sway * pow(k / reach, 1.4) / PX) * PX
				var block := Vector2(x + roundf(k * 0.75 / PX) * PX + given, mid - k if side == 0 else mid + k)
				var color := dark
				if not shade:
					var out := k / reach
					color = QUILL if side == 0 else QUILL_UNDER
					if column % 3 == 0:
						color = color.darkened(0.09)
					if out < 0.22:
						color = color.darkened(0.16)
					elif out > 0.9:
						color = color.lightened(0.5) if side == 0 else color.darkened(0.12)
					if _roll(column * 13 + int(k) * 7 + side) < 0.035:
						color = color.darkened(0.25)
					# The end of the feather is dark, in bars.
					var tip := clampf((v - 0.66) / 0.3, 0.0, 1.0)
					if tip > 0.0 and (int((x + k * 0.75) / 10.0) % 2 == 0 or tip > 0.75):
						color = color.lerp(QUILL_TIP, tip * 0.85)
				_b(block.x, block.y, PX, PX, color)
				k += PX
		x += PX
	# The shaft, from the ferrule to where it thins out inside the vane.
	x = NIB - 4.0
	while x < length - 8.0:
		var mid := roundf(-sin(x / length * PI) * 12.0 / PX) * PX
		var thick := 6.0 if x < bare else (4.0 if x < length * 0.6 else PX)
		var top := mid - floorf(thick / 2.0 / PX) * PX + PX
		if shade:
			_b(x, top, PX, thick, dark)
		else:
			_b(x, top, PX, thick, HORN)
			if thick > PX:
				_b(x, top, PX, PX, HORN.lightened(0.5))
				_b(x, top + thick - PX, PX, PX, HORN.darkened(0.3))
		x += PX
	# The nib: a point that widens to its shoulders, then the ferrule that
	# holds it on the horn.
	x = 0.0
	while x < NIB:
		var half := PX
		if x >= NIB - 10.0:
			half = 5.0
		elif x >= 6.0:
			half = minf(PX + floorf((x - 4.0) / 4.0) * PX, 8.0)
		# The shoulders are cut in before the ferrule.
		if x >= NIB - 14.0 and x < NIB - 10.0:
			half = 6.0
		var top := PX - half
		if shade:
			_b(x, top, PX, half * 2.0, dark)
		elif x >= NIB - 10.0:
			_b(x, top, PX, half * 2.0, BRASS)
			_b(x, top, PX, PX, BRASS_LIGHT)
			_b(x, top + half * 2.0 - PX, PX, PX, BRASS_DARK)
			if x == NIB - 10.0 or x == NIB - PX:
				_b(x, top, PX, half * 2.0, BRASS_DARK)
		else:
			# Wet with ink at the point, and the ink has run up the slit.
			var wet := x < 12.0 or (x < 20.0 and _roll(int(x) + 5) < 0.5)
			_b(x, top, PX, half * 2.0, BLOT if wet else STEEL)
			if not wet and half > PX:
				_b(x, top, PX, PX, STEEL_LIGHT)
				_b(x, top + PX, PX, PX, STEEL_LIGHT.darkened(0.12))
				_b(x, top + half * 2.0 - PX, PX, PX, STEEL_DARK)
		x += PX
	if not shade:
		# The slit, from the point to the breather hole.
		_b(12, PX, 12, 1, STEEL_DARK.darkened(0.5))
		_b(22, 0, 4, 4, BLOT)
		_b(22, 0, PX, 1, STEEL_LIGHT)
		_b(4, 0, 4, 1, Color("4a4658"))


# --- dressing the widgets a screen puts on these -------------------------------

## A label written on paper: ink, and no shadow under the letters.
static func ink(label: Label, color: Color = INK) -> Label:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return label


## A label printed on paper.
static func written(text: String, size := 16, color: Color = INK, is_bold := false) -> Label:
	return ink(UI.label(text, size, color, is_bold), color)


## A line to write on: no box, only the rule under the words.
static func line(edit: LineEdit, color: Color = INK_BLUE, rule := true) -> void:
	var looks := {
		"normal": Color(INK_FADED, 0.55 if rule else 0.0),
		"focus": INK_RED,
		"read_only": Color(INK_FADED, 0.3 if rule else 0.0),
	}
	for state: String in looks:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = looks[state]
		box.border_width_bottom = 2
		box.content_margin_left = 4
		box.content_margin_right = 4
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		box.anti_aliasing = false
		edit.add_theme_stylebox_override(state, box)
	edit.add_theme_color_override("font_color", color)
	edit.add_theme_color_override("font_uneditable_color", INK_FADED)
	edit.add_theme_color_override("font_placeholder_color", Color(INK_FADED, 0.55))
	edit.add_theme_color_override("caret_color", INK)
	edit.add_theme_color_override("selection_color", Color(INK_BLUE, 0.3))
	edit.add_theme_color_override("font_selected_color", INK)


## A button drawn on paper in ink: a box that fills in under the mouse.
static func penned(b: Button, color: Color = INK) -> void:
	var looks := {
		"normal": [0.0, 0.75],
		"hover": [0.14, 1.0],
		"pressed": [0.3, 1.0],
		"disabled": [0.0, 0.22],
	}
	for state: String in looks:
		var box := UI.box(Color(color, looks[state][0]), Color(color, looks[state][1]), 2, 2, 4)
		b.add_theme_stylebox_override(state, box)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, color)
	b.add_theme_color_override("font_disabled_color", Color(color, 0.3))


## A button that is the mark of a rubber stamp: red ink, a double border.
static func stamp(b: Button, color: Color = INK_RED) -> void:
	var looks := {
		"normal": [0.0, 0.9],
		"hover": [0.14, 1.0],
		"pressed": [0.3, 1.0],
		"disabled": [0.0, 0.3],
	}
	for state: String in looks:
		var box := UI.box(Color(color, looks[state][0]), Color(color, looks[state][1]), 3, 3, 6)
		b.add_theme_stylebox_override(state, box)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, color)
	b.add_theme_color_override("font_disabled_color", Color(INK_FADED, 0.6))
	b.add_theme_font_override("font", UI.bold())
	b.draw.connect(func():
		var mark := Color(INK_FADED, 0.35) if b.disabled else Color(color, 0.8)
		b.draw_rect(Rect2(Vector2(6, 6), b.size - Vector2(12, 12)), mark, false, 1.0))


## A button that is a brass plate standing out of the desk, pushed in when
## pressed (the END TURN of the table: HeroPanel._brass).
static func brass(b: Button, bright := false) -> void:
	var metal := BRASS_LIGHT.darkened(0.08) if bright else BRASS
	var looks := {
		"normal": [metal, 0, 4],
		"hover": [metal.lightened(0.18), 0, 4],
		"pressed": [metal.darkened(0.15), 4, 0],
	}
	for state: String in looks:
		var box := UI.box(looks[state][0], BRASS_DARK.darkened(0.35), 2, 2, 6)
		box.border_width_top = 2 + looks[state][1]
		box.border_width_bottom = 2 + looks[state][2]
		b.add_theme_stylebox_override(state, box)
	var off := UI.box(WOOD_DARK, Color("1e100a"), 2, 2, 6)
	off.border_width_bottom = 6
	b.add_theme_stylebox_override("disabled", off)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, UI.INK)
	b.add_theme_font_override("font", UI.bold())


## A button on the velvet of the case: an outline in gold thread, lit when `on`.
static func velvet(b: Button, on := false) -> void:
	var edge := UI.GOLD if on else BRASS
	b.add_theme_stylebox_override("normal", UI.box(VELVET_DEEP if on else Color(VELVET_DEEP, 0.7), edge, 2, 3, 6))
	b.add_theme_stylebox_override("hover", UI.box(VELVET_LIGHT, UI.GOLD, 2, 3, 6))
	b.add_theme_stylebox_override("pressed", UI.box(VELVET_DEEP, UI.GOLD, 2, 3, 6))
	b.add_theme_stylebox_override("disabled", UI.box(Color(VELVET_DEEP, 0.5), Color(BRASS_DARK, 0.7), 2, 3, 6))
	b.add_theme_color_override("font_color", UI.GOLD if on else UI.CREAM)
	b.add_theme_color_override("font_disabled_color", Color(UI.CREAM, 0.3))


## BBCode written for the dark panels, in the inks of a sheet of paper.
static func in_ink(bbcode: String) -> String:
	return (bbcode.replace(UI.hex(UI.GOLD), UI.hex(INK_RED))
			.replace(UI.hex(UI.MUTED), UI.hex(INK_FADED))
			.replace(UI.hex(UI.BLUE), UI.hex(INK_BLUE))
			.replace(UI.hex(UI.GREEN), UI.hex(INK_GREEN)))
