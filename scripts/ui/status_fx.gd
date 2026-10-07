extends Control
## What a player's statuses look like on their box: stars circling someone
## groggy, the Voodooist's doll slumped in a corner, a bundle of dynamite with
## its fuse lit. The chips next to the player still name every status and
## explain it; this is the part that can be read from across the table.
##
## Everything is drawn here in small pixels and moves by itself for as long as
## the status lasts. To give another status a look, add its id to LOOKS and
## draw it from _draw(). No class name: preload it (see SeatView, HeroPanel).

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
## The doll, from the point of the ledge it sits on: how far it has sagged to
## one side (radians), and the joints its floppy parts hang from.
const SLUMP := 0.1
const NECK := Vector2(1, -17)
const SHOULDER := Vector2(9, -14)
const HIP := Vector2(5, -3)

const OUTLINE := Color("1a100c")
const GOLD := Color("f2c84b")
const GLINT := Color("fff3c4")
const SPARK := Color("ffffff")
const BUBBLE := Color("9fd24a")
const HEX := Color("9a62c4")
const HEX_LIGHT := Color("d3a6f2")
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

## o: outline, B: burlap, L: where the light catches it, S: its shadow,
## r: stitches, x: the eyes, w: steel, h and H: the head of a pin.
const DOLL_INK := {
	"o": Color("2a1a10"), "B": Color("b98d5a"), "L": Color("d4aa74"), "S": Color("8f6a40"),
	"r": Color("7a2a1c"), "x": Color("3a0f0c"), "w": Color("d6dde8"),
	"h": Color("c8322a"), "H": Color("ff8a70"),
}
## A sack of a head, too big for the rest: two crosses for eyes, a mouth
## sewn shut and a seam where it was closed.
const DOLL_HEAD := [
	"...ooooooo...",
	"..oLLLLBBBo..",
	".oLLBBBBBrSo.",
	"oLxBxBBBxBxSo",
	"oLBxBBBBBxBSo",
	"oBxBxBBBxBxSo",
	"oBBBBBBBBBSSo",
	"oBBBrrrrrBBSo",
	".oBBBBBBBSSo.",
	"..oSSSSSSSo..",
	"...ooooooo...",
]
## A heart stitched on the chest and a seam down the belly.
const DOLL_BODY := [
	"..ooooo..",
	".oLBBBSo.",
	"oLBrBrBSo",
	"oBBrrrBSo",
	"oBBBrBBSo",
	"oBBBBBBSo",
	"oBBBrBBSo",
	".oBBBBSo.",
	"..ooooo..",
]
## Hanging from the shoulder: its top middle is the joint.
const DOLL_ARM := [
	".o.",
	"oLo",
	"oBo",
	"oro",
	"oBo",
	"oSo",
	".o.",
]
## The leg laid out along the ledge, its foot turned up at the far end.
const DOLL_LEG_FLAT := [
	".ooo........",
	"oLBoooooooo.",
	"oBBBrBrBrBSo",
	"oSBBBBBBBSSo",
	".oooooooooo.",
]
## The leg that hangs over the edge, from the hip at its top.
const DOLL_LEG_LOOSE := [
	"..ooo.",
	".oLBSo",
	".oBBSo",
	".oBrSo",
	".oBBSo",
	".oBrSo",
	".oBBSo",
	"ooBBSo",
	"oLBBSo",
	".oooo.",
]
## A pin, from its point up to its head.
const DOLL_PIN := [
	"...oo",
	"..ohH",
	"..ohh",
	".wwo.",
	"ww...",
]

## The ring the stars fly on, in this node's coordinates: its middle, and how
## far it reaches to each side and towards and away from the viewer.
var ring_centre := Vector2.ZERO
var ring_reach := Vector2(100, 20)
## The far side of that ring. The owner adds it to the tree *under* the
## player's box (before the panel or the texts the stars should pass behind),
## at the same position as this node.
var back: Control
## Where the doll sits, a point on a ledge with room under it for a leg to
## hang, and where the dynamite stands: the middle of its base.
var doll_foot := Vector2.ZERO
var bomb_foot := Vector2.ZERO

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


func _process(delta: float) -> void:
	_time += delta
	var busy := false
	for id: StringName in LOOKS:
		var target := 1.0 if _wanted.get(id, false) else 0.0
		_level[id] = move_toward(_level.get(id, 0.0), target, delta / FADE)
		busy = busy or _level[id] > 0.0
	if not busy:
		set_process(false)
	queue_redraw()
	back.queue_redraw()


func _draw() -> void:
	if _level.get(HEXED, 0.0) > 0.0:
		_draw_doll(_level[HEXED])
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


# --- hexed ----------------------------------------------------------------------

## A rag doll sat on a ledge and left there: one leg laid out along it, the
## other hanging over the edge and swinging, an arm that dangles, a head too
## heavy for its neck. Nothing in it moves by itself: it only settles, and
## now and then something tugs at a pin. Something purple hangs around it.
func _draw_doll(level: float) -> void:
	var heart := doll_foot + Vector2(0, -17)
	var pulse := sin(_time * TAU / 3.4)
	for ring: int in 3:
		draw_circle(heart, 18.0 + ring * 5.0 + pulse * 1.5, Color(HEX, level * (0.18 - 0.05 * ring)))
	for i: int in 5:
		var life := fposmod(_time * 0.32 + i / 5.0, 1.0)
		var mote := doll_foot + Vector2(-19.0 + 9.0 * i + sin(_time * 1.3 + i * 2.1) * 3.0, -2.0 - life * 44.0)
		var side := 3.0 if i % 2 == 0 else 2.0
		draw_rect(Rect2(mote.round(), Vector2(side, side)), Color(HEX_LIGHT, level * sin(life * PI) * 0.9))

	var grown := lerpf(0.5, 1.0, ease(level, 0.4))
	# A tug at a pin every few seconds: everything loose jumps and swings back.
	var since := fposmod(_time, 5.7)
	var jolt := exp(-since * 2.2) * cos(since * 9.0)
	var slump := SLUMP + 0.03 * sin(_time * 0.7) + 0.05 * jolt
	var swing := 0.2 * sin(_time * 1.7) + 0.3 * jolt
	var dangle := 0.55 + 0.12 * sin(_time * 1.3 + 1.0) - 0.25 * jolt
	var loll := 0.14 + 0.08 * sin(_time * 0.9) + 0.1 * jolt

	# Behind the body: the leg over the edge and the arm on the far side.
	_doll_part(DOLL_LEG_LOOSE, HIP, swing, Vector2(-7, -1), grown, level)
	_doll_part(DOLL_ARM, SHOULDER.rotated(slump), slump - dangle, Vector2(-3, -1), grown, level)
	# The body sags over the hips; the other leg lies along the ledge in front of it.
	_doll_part(DOLL_BODY, Vector2.ZERO, slump, Vector2(-7, -18), grown, level)
	_doll_part(DOLL_LEG_FLAT, Vector2.ZERO, 0.0, Vector2(-23, -10), grown, level)
	# The near arm hangs straight down, its hand on the ledge.
	_doll_part(DOLL_ARM, Vector2(-9, -14).rotated(slump), 0.04 * jolt, Vector2(-3, -1), grown, level)
	var neck := NECK.rotated(slump)
	_doll_part(DOLL_HEAD, neck, slump + loll, Vector2(-13, -21), grown, level)
	# The pins that keep it working: through the crown, the chest and the leg.
	_doll_part(DOLL_PIN, neck, slump + loll, Vector2(8, -29), grown, level)
	_doll_part(DOLL_PIN, Vector2.ZERO, slump, Vector2(5, -17), grown, level)
	_doll_part(DOLL_PIN, Vector2.ZERO, 0.0, Vector2(-22, -17), grown, level)
	draw_set_transform(Vector2.ZERO)


## One piece of the doll: `rows` turned by `angle` about `joint` (a point
## counted from where the doll sits), with its top left corner at `corner`
## from that joint.
func _doll_part(rows: Array, joint: Vector2, angle: float, corner: Vector2, grown: float, level: float) -> void:
	draw_set_transform(doll_foot + joint * grown, angle, Vector2.ONE * grown)
	_bitmap_at(rows, DOLL_INK, corner, level)


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


## Draws `rows` in this node, with their top left corner at `corner`.
func _bitmap_at(rows: Array, ink: Dictionary, corner: Vector2, alpha: float) -> void:
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if ink.has(row[x]):
				var color: Color = ink[row[x]]
				draw_rect(Rect2(corner + Vector2(x, y) * CELL, Vector2(CELL, CELL)), Color(color, alpha))
