extends Control
## What a player's statuses look like on their box: stars circling someone
## groggy, the Voodooist's doll slumped in a corner, a bundle of dynamite with
## its fuse lit, the chains of the Entity wound about the box, the wax seal of
## the court on somebody under oath. The chips next to the player still name every status and
## explain it; this is the part that can be read from across the table.
##
## Everything is drawn in small pixels and moves by itself for as long as the
## status lasts. The doll is a node of its own (VoodooDoll), kept here, and so
## are the chains (chains_fx.gd). To give another status a look, add its id to LOOKS and
## draw it on a canvas of its own, as _bomb and _near are. No class name:
## preload it (see SeatView, HeroPanel).
##
## A status put there by a borrowed action (the Impostor's Perfect Disguise)
## keeps the look of one for as long as it lasts: see set_borrowed.

const VoodooDoll := preload("res://scripts/ui/voodoo_doll.gd")
const ChainsFx := preload("res://scripts/ui/chains_fx.gd")

const GROGGY := &"groggy"
const HEXED := &"hexed"
const TICKING := &"ticking"
const ENTROPY := &"entropy"
const SWORN := &"truth_bound"
const LOOKS: Array[StringName] = [GROGGY, HEXED, TICKING, ENTROPY, SWORN]

const CELL := 2.0
## The ring a groggy player's stars fly on: radians per second, and how much
## higher its right end sits than its left (a slope, so it is not seen dead level).
const RING_SPEED := 0.6
const RING_TILT := -0.07
## How unruly the ring is, 0 for a perfect one: each thing on it runs ahead
## and falls behind, swings wide and bobs on its own.
const TURBULENCE := 1.0
## Seconds for a look to fade in or out.
const FADE := 0.25
## Seconds the chains take to be thrown round the box.
const BIND := 0.55
## Seconds the wax takes to cool and set once the seal is pressed, seconds a
## seal pressed ahead of its status waits for it (see press_seal), and
## seconds a jolt of it lasts.
const SEAL_SET := 0.45
const SEAL_HOLD := 3.0
const SEAL_JOLT := 0.4
const OUTLINE := Color("1a100c")
const GOLD := Color("f2c84b")
const GLINT := Color("fff3c4")
const SPARK := Color("ffffff")
const BUBBLE := Color("9fd24a")
const RED := Color("c8322a")
const RED_LIGHT := Color("ea6a4e")
const RED_DARK := Color("86201c")
const PAPER := Color("d8c9a0")
const STRAP := Color("3a2a1c")
const BRASS := Color("d9a840")
const FUSE := Color("b89a6a")
const EMBER := Color("ff7a2a")
const FLAME := Color("ffd060")

const STAR := [
	"....#....",
	"....#....",
	"...#+#...",
	"####+####",
	".##+++##.",
	"..#+++#..",
	"..##+##..",
	".##...##.",
	".#.....#.",
]
const STAR_INK := {"#": GOLD, "+": GLINT}
const STAR_FLASH := {"#": GLINT, "+": SPARK}
const TWINKLE := [
	".#.",
	"#+#",
	".#.",
]
const TWINKLE_INK := {"#": SPARK, "+": GLINT}
const DROP := [
	".##.",
	"#..#",
	"#.+#",
	".##.",
]
const DROP_INK := {"#": BUBBLE, "+": GLINT}
## What goes round a groggy player, evenly spread: a star, then smaller things.
const ORBIT := [STAR, TWINKLE, DROP, STAR, DROP, TWINKLE, STAR, TWINKLE, DROP]
## The seal of the court, a disc of burgundy wax: how many pixels across its
## picture is, the radius of the flat the die left in it, of the ring raised
## on that flat and of the beads between ring and wall, and where the light
## comes from.
const SEAL_SIZE := 36
const SEAL_DIE := 12.2
const SEAL_RING := 8.6
const SEAL_BEADS := 10.5
const SEAL_LIGHT := Vector2(-0.7071, -0.7071)
## The scales, raised in the middle of it.
const SEAL_EMBLEM := [
	".....#.....",
	".#########.",
	".#...#...#.",
	".#...#...#.",
	"###..#..###",
	".....#.....",
	".....#.....",
	"...#####...",
]
const WAX_OUTLINE := Color("2e060c")
const WAX_SHADOW := Color("5a0e18")
const WAX_FLAT := Color("70121e")
const WAX := Color("8e1c2b")
const WAX_LIGHT := Color("ae2e3e")
const WAX_SHINE := Color("d25a66")
const WAX_GLINT := Color("f6bcbc")
## The same wax still molten, before the die comes down on it.
const MOLTEN_OUTLINE := Color("7a1c10")
const MOLTEN_SHADOW := Color("b02a1c")
const MOLTEN := Color("e8502c")
const MOLTEN_LIGHT := Color("ff8a3c")
const MOLTEN_GLINT := Color("ffd9a0")

## The ring the stars fly on, in this node's coordinates: its middle, and how
## far it reaches to each side and towards and away from the viewer.
var ring_centre := Vector2.ZERO
var ring_reach := Vector2(100, 20)
## The far side of that ring. The owner adds it to the tree *under* the
## player's box (before the panel or the texts the stars should pass behind),
## at the same position as this node.
var back: Control
## Where the doll sits: a point with something to lean back on to its right,
## something to lay a leg along to its left and room under it for the other
## leg to hang. And what it feeds on: the middle of
## the player's box.
var doll_foot := Vector2.ZERO:
	set(value):
		doll_foot = value
		_place_doll()
var doll_drain := Vector2.ZERO:
	set(value):
		doll_drain = value
		_place_doll()
## Which way the doll faces: -1 left (its back to something on its right), 1
## right.
var doll_facing := -1.0:
	set(value):
		doll_facing = value
		_place_doll()
## Whether a leg of the doll hangs under where it sits (see VoodooDoll.hangs).
var doll_hangs := true:
	set(value):
		doll_hangs = value
		_place_doll()
## From its place to the corner a thrown doll strikes first (see doll_way).
var doll_drop := Vector2(0, -60)
## Where the dynamite stands: the middle of its base.
var bomb_foot := Vector2.ZERO
## What the chains are wound about: the player's box.
var chain_box := Rect2():
	set(value):
		chain_box = value
		_chains.box = value
## Where the seal of an oath is set: its middle.
var seal_at := Vector2.ZERO
var _doll: VoodooDoll
var _chains: ChainsFx
## The dynamite and the near half of the stars, each on a canvas of its own:
## a look is spoiled by a material (see set_borrowed), and a material is the
## whole node's.
var _bomb: Control
var _near: Control
var _seal: Control
## Whether the player is under oath, as of the last sync, and the seconds a
## seal pressed before that still waits for it.
var _sworn := false
var _seal_hold := 0.0
## 0 as the seal is pressed into the hot wax, 1 once it has set.
var _seal_set := 1.0
## 1 as the seal jumps, down to 0.
var _seal_jolt := 0.0

var _wanted := {}  # status id -> bool
var _level := {}  # status id -> 0..1, how far its look has faded in
## The bomb goes off when the turn being played ends.
var _urgent := false
var _time := 0.0
var _borrowed := {}  # status id -> bool, see set_borrowed
## What a borrowed status is drawn with: the material of PlayFx.GlitchFx,
## kept going here.
var _spoiled: ShaderMaterial
static var _spoiled_shader: Shader
## The seal, pressed and molten: painted once (see _seal_picture).
static var _seal_pressed: ImageTexture
static var _seal_molten: ImageTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(_draw_far_side)
	_bomb = _canvas(_draw_bomb)
	_near = _canvas(_draw_near_side)
	_seal = _canvas(_draw_seal)
	_seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_doll = VoodooDoll.new()
	_doll.level = 0.0
	add_child(_doll)
	_chains = ChainsFx.new()
	add_child(_chains)
	# So that two players under the same spell do not move as one.
	_time = randf() * 20.0


func _ready() -> void:
	set_process(_wanted.values().has(true))


## Shows the looks of the statuses `player` has right now (none for null).
func sync(player: PlayerState, engine: GameEngine) -> void:
	_urgent = false
	for id: StringName in LOOKS:
		_wanted[id] = player != null and player.alive and player.has_status(id)
	if _wanted[TICKING]:
		var planted: int = player.statuses[TICKING].get("planted", 0)
		_urgent = engine.current == player and planted < engine.turn_count
	if not _wanted[ENTROPY]:
		_chains.bound = 0.0
	_sworn = _wanted[SWORN]
	if _sworn and _level.get(SWORN, 0.0) <= 0.0:
		# Nobody pressed it: it sets by itself as it shows.
		_seal_set = 0.0
	_wanted[SWORN] = _sworn or _seal_hold > 0.0
	if _wanted.values().has(true):
		set_process(true)


## Whether status `id` was put on the player by a borrowed action: its look
## is torn and drained to purple like everything else the Impostor copies
## (see PlayFx.GlitchFx), until the status is put on again by something else.
func set_borrowed(id: StringName, on: bool) -> void:
	_borrowed[id] = on
	if on and _spoiled == null:
		if _spoiled_shader == null:
			_spoiled_shader = Shader.new()
			_spoiled_shader.code = PlayFx.GlitchFx.CODE
		_spoiled = ShaderMaterial.new()
		_spoiled.shader = _spoiled_shader
		_spoil()
	for id_and_canvas: Array in [[GROGGY, _near], [GROGGY, back], [HEXED, _doll], [TICKING, _bomb], [ENTROPY, _chains], [SWORN, _seal]]:
		var canvas: CanvasItem = id_and_canvas[1]
		canvas.material = _spoiled if _borrowed.get(id_and_canvas[0], false) else null


func borrowed(id: StringName) -> bool:
	return _borrowed.get(id, false)


# The same fits as PlayFx.GlitchFx: nearly steady for a moment, then torn again.
func _spoil() -> void:
	var fit := 0.5 + 0.5 * absf(sin(_time * 5.3) * sin(_time * 1.9 + 1.0))
	_spoiled.set_shader_parameter("amount", fit)
	_spoiled.set_shader_parameter("beat", floorf(_time * PlayFx.GlitchFx.BEATS))


func _canvas(drawn: Callable) -> Control:
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(drawn)
	add_child(canvas)
	return canvas


## Where the look of status `id` is on screen right now, as the points it
## flies apart from when the status is broken (none without a look showing).
func pieces(id: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _level.get(id, 0.0) <= 0.0:
		return out
	var onto := get_global_transform()
	match id:
		GROGGY:
			for i: int in ORBIT.size():
				if ORBIT[i] == STAR:
					out.append(onto * _on_ring(_time * RING_SPEED + TAU * i / ORBIT.size()))
		HEXED:
			out.append(onto * (doll_foot + _doll.heart()))
		TICKING:
			out.append(onto * (bomb_foot + Vector2(0, -14)))
		ENTROPY:
			out = _chains.links()
		SWORN:
			out.append(onto * seal_at)
	return out


## Where the seal is set, on screen, whether or not it is there.
func seal_spot() -> Vector2:
	return get_global_transform() * seal_at


## The seal is there at once, pressed into wax still hot: the gavel has just
## come down. The status follows (sync); a seal it does not follow is gone
## after SEAL_HOLD seconds.
func press_seal() -> void:
	_seal_hold = SEAL_HOLD
	_seal_set = 0.0
	_wanted[SWORN] = true
	_level[SWORN] = 1.0
	set_process(true)


## The seal jumps: the oath is being put to the test.
func jolt_seal() -> void:
	_seal_jolt = 1.0
	set_process(true)


## The doll is there at once, whole: it was thrown and has just landed.
func doll_landed() -> void:
	if _wanted.get(HEXED, false):
		_level[HEXED] = 1.0
		_doll.level = 1.0


## Where the doll sits and what it hits on the way there, on screen: thrown,
## it strikes the corner above its place and slides down to it.
func doll_way() -> Array[Vector2]:
	var onto := get_global_transform()
	return [onto * (doll_foot + doll_drop), onto * doll_foot]


func _place_doll() -> void:
	if _doll != null:
		_doll.position = doll_foot
		_doll.facing = doll_facing
		_doll.hangs = doll_hangs
		_doll.drain = doll_drain - doll_foot


func _process(delta: float) -> void:
	_time += delta
	if _seal_hold > 0.0:
		_seal_hold -= delta
		if _seal_hold <= 0.0:
			_wanted[SWORN] = _sworn
	_seal_set = move_toward(_seal_set, 1.0, delta / SEAL_SET)
	_seal_jolt = move_toward(_seal_jolt, 0.0, delta / SEAL_JOLT)
	var busy := false
	for id: StringName in LOOKS:
		var target := 1.0 if _wanted.get(id, false) else 0.0
		_level[id] = move_toward(_level.get(id, 0.0), target, delta / FADE)
		busy = busy or _level[id] > 0.0
	_doll.level = _level.get(HEXED, 0.0)
	# The chains are thrown on link by link, and are gone at once: they do
	# not fade, they break (see PlayFx.chains_break).
	_chains.bound = move_toward(_chains.bound, 1.0, delta / BIND) if _wanted.get(ENTROPY, false) else 0.0
	_level[ENTROPY] = 1.0 if _wanted.get(ENTROPY, false) else 0.0
	if not busy:
		set_process(false)
	if _spoiled != null:
		_spoil()
	_bomb.queue_redraw()
	_near.queue_redraw()
	_seal.queue_redraw()
	back.queue_redraw()


# --- groggy ---------------------------------------------------------------------

## Stars, sparkles and bubbles flying round the player on a flat ring, seen a
## little from above: across the front of the box, round the side and away
## behind it. `near_side` picks the half of the ring this canvas shows: what
## is far away is drawn by `back`, under the box, and comes out smaller and
## dimmer.
func _draw_stars(canvas: CanvasItem, level: float, near_side: bool) -> void:
	for i: int in ORBIT.size():
		# Nothing keeps its place in the line: two slow waves, out of step
		# with each other and with the neighbours, push it along and hold it back.
		var drift := (0.2 * sin(_time * 0.83 + i * 2.3) + 0.09 * sin(_time * 1.9 + i * 5.1)) * TURBULENCE
		var angle := _time * RING_SPEED + TAU * i / ORBIT.size() + drift
		# 1 right in front of the box, -1 right behind it.
		var near := sin(angle)
		if (near >= 0.0) != near_side:
			continue
		var depth := (near + 1.0) / 2.0
		# It swings a little wide or cuts in, and rides up and down.
		var swing := 1.0 + 0.09 * sin(_time * 1.27 + i * 1.9) * TURBULENCE
		var bob := Vector2(0, (sin(_time * 2.3 + i * 1.7) * 3.0 + sin(_time * 3.7 + i * 4.1) * 1.5) * TURBULENCE)
		var cell := CELL * lerpf(0.6, 1.25, depth)
		var alpha := level * lerpf(0.45, 1.0, depth)
		var dim := 0.4 * (1.0 - depth)
		var shape: Array = ORBIT[i]
		if shape == STAR:
			for step: int in [2, 1]:
				var tail := _on_ring(angle - 0.13 * step, swing) + bob
				canvas.draw_rect(Rect2(tail - Vector2(cell, cell), Vector2(cell, cell) * 2.0),
						Color(GOLD.darkened(dim), alpha * (0.55 - 0.2 * step)))
			# A star now and then catches the light.
			var bright := fposmod(_time * 0.9 + i * 0.37, 1.0) < 0.12
			_pixels(canvas, STAR, STAR_FLASH if bright else STAR_INK, _on_ring(angle, swing) + bob, alpha, cell, dim)
		elif shape == TWINKLE:
			_pixels(canvas, TWINKLE, TWINKLE_INK, _on_ring(angle, swing) + bob, alpha * (0.55 + 0.45 * sin(_time * 7.0 + i)), cell, dim)
		else:
			_pixels(canvas, DROP, DROP_INK, _on_ring(angle, swing) + bob, alpha * 0.9, cell, dim)


func _draw_far_side() -> void:
	if _level.get(GROGGY, 0.0) > 0.0:
		_draw_stars(back, _level[GROGGY], false)


func _draw_near_side() -> void:
	if _level.get(GROGGY, 0.0) > 0.0:
		_draw_stars(_near, _level[GROGGY], true)


## Where the ring is at `angle`: 0 at its right end, a quarter turn later
## right in front of the box. `swing` widens (above 1) or tightens the turn.
## The whole ring rocks slowly, like a plate about to settle.
func _on_ring(angle: float, swing := 1.0) -> Vector2:
	var across := cos(angle) * ring_reach.x * swing
	var tilt := RING_TILT + 0.035 * sin(_time * 0.6) * TURBULENCE
	return ring_centre + Vector2(across, sin(angle) * ring_reach.y * swing + across * tilt)


# --- ticking --------------------------------------------------------------------

## Three sticks strapped together and a fuse that never stops spitting. While
## the turn that sets it off is being played, the fuse is nearly gone and the
## whole bundle shakes.
func _draw_bomb() -> void:
	var level: float = _level.get(TICKING, 0.0)
	if level <= 0.0:
		return
	var shake := Vector2(roundf(sin(_time * 38.0)), 0) if _urgent else Vector2.ZERO
	if _urgent:
		_bomb.draw_circle(bomb_foot + Vector2(0, -14), 23.0 + 4.0 * sin(_time * 10.0), Color(RED, level * 0.22))
	_bomb.draw_set_transform(bomb_foot + shake, 0.0, Vector2.ONE * lerpf(0.5, 1.0, ease(level, 0.4)))
	for i: int in 3:
		var x := -10.0 + i * 7.0
		var height := 26.0 if i == 1 else 24.0
		_bomb.draw_rect(Rect2(x - 1, -height - 1, 8, height + 1), Color(OUTLINE, level))
		_bomb.draw_rect(Rect2(x, -height, 6, height), Color(RED, level))
		_bomb.draw_rect(Rect2(x, -height, 2, height), Color(RED_LIGHT, level))
		_bomb.draw_rect(Rect2(x + 5, -height, 1, height), Color(RED_DARK, level))
		# The paper end of the stick.
		_bomb.draw_rect(Rect2(x, -height, 6, 3), Color(PAPER, level))
		_bomb.draw_rect(Rect2(x, -height + 3, 6, 1), Color(RED_DARK, level))
	_bomb.draw_rect(Rect2(-12, -15, 23, 5), Color(OUTLINE, level))
	_bomb.draw_rect(Rect2(-11, -14, 21, 3), Color(STRAP, level))
	_bomb.draw_rect(Rect2(-2, -15, 4, 5), Color(BRASS, level))

	# The fuse climbs out of the middle stick and curls over; what is left of
	# it is short when the bomb is about to go off.
	var path: Array[Vector2] = [Vector2(-1, -28), Vector2(-1, -30), Vector2(1, -32), Vector2(3, -34), Vector2(5, -35)]
	var left := 2 if _urgent else path.size()
	for i: int in left:
		_bomb.draw_rect(Rect2(path[i], Vector2(2, 2)), Color(FUSE, level))
	var tip := path[left - 1] + Vector2(1, -1)
	_bomb.draw_circle(tip, 7.0 + 2.0 * sin(_time * 9.0), Color(EMBER, level * 0.24))
	for i: int in 4:
		var life := fposmod(_time * 1.8 + i * 0.25, 1.0)
		var way := Vector2.from_angle(-PI / 2.0 + (i - 1.5) * 0.7 + sin(i * 12.9) * 0.3)
		var ember := tip + way * (4.0 + life * 12.0) + Vector2(0, life * life * 6.0)
		_bomb.draw_rect(Rect2(ember.round(), Vector2(2, 2)), Color(FLAME if i % 2 == 0 else EMBER, level * (1.0 - life)))
	match int(_time * 14.0) % 3:
		0:
			_bomb.draw_rect(Rect2(tip + Vector2(-1, -4), Vector2(2, 8)), Color(FLAME, level))
			_bomb.draw_rect(Rect2(tip + Vector2(-4, -1), Vector2(8, 2)), Color(FLAME, level))
		1:
			for corner: Vector2 in [Vector2(-3, -3), Vector2(2, -3), Vector2(-3, 2), Vector2(2, 2)]:
				_bomb.draw_rect(Rect2(tip + corner, Vector2(2, 2)), Color(EMBER, level))
			_bomb.draw_rect(Rect2(tip + Vector2(-2, -2), Vector2(4, 4)), Color(FLAME, level))
		_:
			_bomb.draw_rect(Rect2(tip + Vector2(-3, -3), Vector2(6, 6)), Color(FLAME, level))
	_bomb.draw_rect(Rect2(tip + Vector2(-1, -1), Vector2(2, 2)), Color(SPARK, level))
	_bomb.draw_set_transform(Vector2.ZERO)


# --- under oath -----------------------------------------------------------------

## A seal of burgundy wax, as a die leaves it: a thick glossy rim squeezed out
## all round, never quite a circle, and inside it the flat the die pressed,
## with a ring, a border of beads and the scales of the court raised on it.
## Pressed, it starts as a blob of molten wax, wider than the seal, and the
## die's work shows as it cools. It does not move again, but for a glint now
## and then and a jump when the oath is tested.
func _draw_seal() -> void:
	var level: float = _level.get(SWORN, 0.0)
	if level <= 0.0:
		return
	if _seal_pressed == null:
		_seal_pressed = _seal_picture(true)
		_seal_molten = _seal_picture(false)
	var cooled := ease(_seal_set, 0.35)
	var jump := sin(_seal_jolt * PI)
	var grown := 1.0 + 0.5 * (1.0 - cooled) + 0.3 * jump
	var turn := 0.3 * sin(_seal_jolt * TAU * 1.5) * _seal_jolt
	_seal.draw_set_transform(seal_at + Vector2(0, -5.0 * jump), turn, Vector2.ONE * grown)
	var frame := Rect2(Vector2.ONE * -SEAL_SIZE / 2.0, Vector2.ONE * SEAL_SIZE)
	_seal.draw_texture_rect(_seal_pressed, frame, false, Color(1, 1, 1, level))
	if cooled < 1.0:
		_seal.draw_texture_rect(_seal_molten, frame, false, Color(1, 1, 1, level * (1.0 - cooled)))
	# The light catches the rim now and then.
	if cooled >= 1.0 and (fposmod(_time * 0.3, 1.0) < 0.06 or _seal_jolt > 0.5):
		var spot := (SEAL_LIGHT * 14.0).round()
		_seal.draw_rect(Rect2(spot + Vector2(-1, -3), Vector2(2, 6)), Color(SPARK, level))
		_seal.draw_rect(Rect2(spot + Vector2(-3, -1), Vector2(6, 2)), Color(SPARK, level))
	_seal.draw_set_transform(Vector2.ZERO)


## The seal painted pixel by pixel, lit from the top left: `pressed` with the
## work of the die in it, or else a smooth blob of molten wax.
static func _seal_picture(pressed: bool) -> ImageTexture:
	var image := Image.create(SEAL_SIZE, SEAL_SIZE, false, Image.FORMAT_RGBA8)
	var middle := (SEAL_SIZE - 1) / 2.0
	for y: int in SEAL_SIZE:
		for x: int in SEAL_SIZE:
			var from := Vector2(x - middle, y - middle)
			var far := from.length()
			# The wax ran a little further here than there.
			var angle := from.angle()
			var edge := 15.6 + 0.9 * sin(3.0 * angle + 0.7) + 0.6 * sin(5.0 * angle + 2.1) + 0.45 * sin(2.0 * angle + 4.0)
			if far > edge:
				continue
			var lit := (from / far).dot(SEAL_LIGHT) if far > 0.0 else 0.0
			var ink: Color
			if far > edge - 1.0:
				ink = WAX_OUTLINE if pressed else MOLTEN_OUTLINE
			elif not pressed:
				var slope := lit * far / edge
				ink = MOLTEN_GLINT if slope > 0.3 and slope < 0.5 and lit > 0.9 else \
						(MOLTEN_LIGHT if slope > 0.2 else (MOLTEN_SHADOW if slope < -0.5 else MOLTEN))
			elif far >= SEAL_DIE:
				# The rim: a roll of wax, bright where it faces the light.
				var across := (far - SEAL_DIE) / (edge - 1.0 - SEAL_DIE)
				var slope := -cos(PI * across) * lit
				if across > 0.3 and across < 0.62 and lit > 0.8:
					ink = WAX_GLINT
				elif (across > 0.25 and across < 0.7 and lit > 0.45) or (across > 0.3 and across < 0.6 and lit < -0.9):
					ink = WAX_SHINE
				else:
					ink = WAX_LIGHT if slope > 0.45 else (WAX_SHADOW if slope < -0.45 else WAX)
			elif far > SEAL_DIE - 1.3:
				# The wall of the flat: in the rim's shade on the lit side.
				ink = WAX_SHADOW if lit > 0.25 else (WAX_LIGHT if lit < -0.35 else WAX_FLAT)
			elif _seal_raised(from):
				ink = WAX_LIGHT
			else:
				ink = WAX_SHADOW if _seal_raised(from + Vector2.UP) else WAX_FLAT
			image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)


## Whether the die left the wax raised at `from` the middle of the seal.
static func _seal_raised(from: Vector2) -> bool:
	var far := from.length()
	if absf(far - SEAL_RING) < 0.55:
		return true
	if absf(far - SEAL_BEADS) < 0.8 and absf(fposmod(from.angle() / (PI / 8.0) + 0.5, 1.0) - 0.5) < 0.24:
		return true
	var cell := Vector2i(floori(from.x + 5.5), floori(from.y + 4.0))
	if cell.y >= 0 and cell.y < SEAL_EMBLEM.size() and cell.x >= 0 and cell.x < 11:
		return String(SEAL_EMBLEM[cell.y])[cell.x] == "#"
	return false


# --- pixels ---------------------------------------------------------------------

## Draws `rows` (one character per pixel, "." for none) on `canvas`, centred
## on `at`, in pixels of `cell` and `dim` darker than their ink.
func _pixels(canvas: CanvasItem, rows: Array, ink: Dictionary, at: Vector2, alpha: float, cell: float, dim: float) -> void:
	var corner := at - Vector2(String(rows[0]).length(), rows.size()) * cell / 2.0
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if ink.has(row[x]):
				var color: Color = ink[row[x]]
				canvas.draw_rect(Rect2(corner + Vector2(x, y) * cell, Vector2(cell, cell)), Color(color.darkened(dim), alpha))
