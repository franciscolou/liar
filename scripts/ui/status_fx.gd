extends Control
## What a player's statuses look like on their box: stars circling someone
## groggy, the Voodooist's doll slumped in a corner, a bundle of dynamite with
## its fuse lit. The chips next to the player still name every status and
## explain it; this is the part that can be read from across the table.
##
## Everything is drawn in small pixels and moves by itself for as long as the
## status lasts. The doll is a node of its own (VoodooDoll), kept here. To give another status a look, add its id to LOOKS and
## draw it from _draw(). No class name: preload it (see SeatView, HeroPanel).

const VoodooDoll := preload("res://scripts/ui/voodoo_doll.gd")

const GROGGY := &"groggy"
const HEXED := &"hexed"
const TICKING := &"ticking"
const LOOKS: Array[StringName] = [GROGGY, HEXED, TICKING]

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
var _doll: VoodooDoll

var _wanted := {}  # status id -> bool
var _level := {}  # status id -> 0..1, how far its look has faded in
## The bomb goes off when the turn being played ends.
var _urgent := false
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(_draw_far_side)
	_doll = VoodooDoll.new()
	_doll.level = 0.0
	add_child(_doll)
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
	if _wanted.values().has(true):
		set_process(true)


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
	return out


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
	var busy := false
	for id: StringName in LOOKS:
		var target := 1.0 if _wanted.get(id, false) else 0.0
		_level[id] = move_toward(_level.get(id, 0.0), target, delta / FADE)
		busy = busy or _level[id] > 0.0
	_doll.level = _level.get(HEXED, 0.0)
	if not busy:
		set_process(false)
	queue_redraw()
	back.queue_redraw()


func _draw() -> void:
	if _level.get(TICKING, 0.0) > 0.0:
		_draw_bomb(_level[TICKING])
	if _level.get(GROGGY, 0.0) > 0.0:
		_draw_stars(self, _level[GROGGY], true)


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
func _draw_bomb(level: float) -> void:
	var shake := Vector2(roundf(sin(_time * 38.0)), 0) if _urgent else Vector2.ZERO
	if _urgent:
		draw_circle(bomb_foot + Vector2(0, -14), 23.0 + 4.0 * sin(_time * 10.0), Color(RED, level * 0.22))
	draw_set_transform(bomb_foot + shake, 0.0, Vector2.ONE * lerpf(0.5, 1.0, ease(level, 0.4)))
	for i: int in 3:
		var x := -10.0 + i * 7.0
		var height := 26.0 if i == 1 else 24.0
		draw_rect(Rect2(x - 1, -height - 1, 8, height + 1), Color(OUTLINE, level))
		draw_rect(Rect2(x, -height, 6, height), Color(RED, level))
		draw_rect(Rect2(x, -height, 2, height), Color(RED_LIGHT, level))
		draw_rect(Rect2(x + 5, -height, 1, height), Color(RED_DARK, level))
		# The paper end of the stick.
		draw_rect(Rect2(x, -height, 6, 3), Color(PAPER, level))
		draw_rect(Rect2(x, -height + 3, 6, 1), Color(RED_DARK, level))
	draw_rect(Rect2(-12, -15, 23, 5), Color(OUTLINE, level))
	draw_rect(Rect2(-11, -14, 21, 3), Color(STRAP, level))
	draw_rect(Rect2(-2, -15, 4, 5), Color(BRASS, level))

	# The fuse climbs out of the middle stick and curls over; what is left of
	# it is short when the bomb is about to go off.
	var path: Array[Vector2] = [Vector2(-1, -28), Vector2(-1, -30), Vector2(1, -32), Vector2(3, -34), Vector2(5, -35)]
	var left := 2 if _urgent else path.size()
	for i: int in left:
		draw_rect(Rect2(path[i], Vector2(2, 2)), Color(FUSE, level))
	var tip := path[left - 1] + Vector2(1, -1)
	draw_circle(tip, 7.0 + 2.0 * sin(_time * 9.0), Color(EMBER, level * 0.24))
	for i: int in 4:
		var life := fposmod(_time * 1.8 + i * 0.25, 1.0)
		var way := Vector2.from_angle(-PI / 2.0 + (i - 1.5) * 0.7 + sin(i * 12.9) * 0.3)
		var ember := tip + way * (4.0 + life * 12.0) + Vector2(0, life * life * 6.0)
		draw_rect(Rect2(ember.round(), Vector2(2, 2)), Color(FLAME if i % 2 == 0 else EMBER, level * (1.0 - life)))
	match int(_time * 14.0) % 3:
		0:
			draw_rect(Rect2(tip + Vector2(-1, -4), Vector2(2, 8)), Color(FLAME, level))
			draw_rect(Rect2(tip + Vector2(-4, -1), Vector2(8, 2)), Color(FLAME, level))
		1:
			for corner: Vector2 in [Vector2(-3, -3), Vector2(2, -3), Vector2(-3, 2), Vector2(2, 2)]:
				draw_rect(Rect2(tip + corner, Vector2(2, 2)), Color(EMBER, level))
			draw_rect(Rect2(tip + Vector2(-2, -2), Vector2(4, 4)), Color(FLAME, level))
		_:
			draw_rect(Rect2(tip + Vector2(-3, -3), Vector2(6, 6)), Color(FLAME, level))
	draw_rect(Rect2(tip + Vector2(-1, -1), Vector2(2, 2)), Color(SPARK, level))
	draw_set_transform(Vector2.ZERO)


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
