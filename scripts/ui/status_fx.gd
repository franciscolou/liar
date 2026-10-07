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
## How far the doll has slid over, in radians: it leans on the box to its left.
const SLUMP := -0.24
## Its hips, above the middle of its base: what the slump turns around.
const HIP := Vector2(0, -5)

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

const DOLL_INK := {
	"o": Color("2a1a10"), "B": Color("b98d5a"), "S": Color("8f6a40"),
	"x": Color("1a1210"), "n": Color("1a1210"), "w": Color("e8e2c8"),
	"m": Color("3a2416"), "h": Color("c8402f"),
}
## One stitched X for an eye, one button.
const DOLL_HEAD := [
	"...ooooo...",
	"..oBBBBBo..",
	".oBBBBBBSo.",
	"oBxBxBBBBSo",
	"oBBxBBnnBSo",
	"oBxBxBnwBSo",
	"oBBBBBBBBSo",
	".oBmBmBmSo.",
	"..oBBBBSo..",
	"...ooooo...",
]
const DOLL_BODY := [
	"..ooooo..",
	".oBBBBSo.",
	"oBBBBBBSo",
	"oBBhBhBSo",
	"oBBhhhBSo",
	"oBBBhBBSo",
	".ooooooo.",
]
const DOLL_ARM := [
	".o.",
	"oBo",
	"oBo",
	"oBo",
	"oSo",
	".o.",
]
const DOLL_LEG := [
	".oooo.",
	"oBBBSo",
	".oooo.",
]

## The ring the stars fly on, in this node's coordinates: its middle, and how
## far it reaches to each side and towards and away from the viewer.
var ring_centre := Vector2.ZERO
var ring_reach := Vector2(100, 20)
## The far side of that ring. The owner adds it to the tree *under* the
## player's box (before the panel or the texts the stars should pass behind),
## at the same position as this node.
var back: Control
## Where the doll sits and where the dynamite stands: the middle of their base.
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

## The doll sits where it was dropped, leaning on the box: a slow breath, a
## head that lolls, limbs that settle now and then. Something purple hangs
## around it.
func _draw_doll(level: float) -> void:
	var breath := sin(_time * TAU / 3.4)
	var heart := doll_foot + Vector2(0, -17)
	for ring: int in 3:
		draw_circle(heart, 17.0 + ring * 5.0 + breath * 1.5, Color(HEX, level * (0.2 - 0.055 * ring)))
	for i: int in 5:
		var life := fposmod(_time * 0.32 + i / 5.0, 1.0)
		var mote := doll_foot + Vector2(-17.0 + 8.5 * i + sin(_time * 1.3 + i * 2.1) * 3.0, -2.0 - life * 40.0)
		var side := 3.0 if i % 2 == 0 else 2.0
		draw_rect(Rect2(mote.round(), Vector2(side, side)), Color(HEX_LIGHT, level * sin(life * PI) * 0.9))

	var grown := lerpf(0.5, 1.0, ease(level, 0.4))
	# The chest rises a pixel on the in-breath and takes head and arms along.
	var lift := Vector2(0, -1) if breath > 0.25 else Vector2.ZERO
	# Limbs: one leg shifts, one arm hangs and sways, the other twitches.
	var kick := Vector2(1, 0) if fposmod(_time + 2.0, 6.1) < 0.22 else Vector2.ZERO
	var sway := Vector2(-1, 0) if sin(_time * 1.1) > 0.0 else Vector2.ZERO
	var twitch := Vector2(0, -2) if fposmod(_time, 5.3) < 0.16 else Vector2.ZERO
	# The legs lie flat on the ground; everything above the hips has slid over.
	draw_set_transform(doll_foot, 0.0, Vector2.ONE * grown)
	_bitmap_at(DOLL_LEG, DOLL_INK, Vector2(-15, -6), level)
	_bitmap_at(DOLL_LEG, DOLL_INK, Vector2(3, -6) + kick, level)
	draw_set_transform(doll_foot + HIP * grown, SLUMP, Vector2.ONE * grown)
	lift -= HIP
	_bitmap_at(DOLL_ARM, DOLL_INK, Vector2(-15, -19) + lift + sway, level)
	_bitmap_at(DOLL_ARM, DOLL_INK, Vector2(8, -18) + lift + twitch, level)
	_bitmap_at(DOLL_BODY, DOLL_INK, Vector2(-10, -19) + lift, level)
	# The head hangs towards the box, and nods off every so often.
	var loll := Vector2(1, 0) if sin(_time * 0.9) > 0.6 else Vector2.ZERO
	var nod := Vector2(0, 1) if sin(_time * 0.37 + 1.0) > 0.9 else Vector2.ZERO
	var head := Vector2(-14, -37) + lift + loll + nod
	_bitmap_at(DOLL_HEAD, DOLL_INK, head, level)
	# The pin that keeps it working, stuck through the crown.
	var pin := head + Vector2(16, 0)
	for step: int in 3:
		draw_rect(Rect2(pin + Vector2(step * 2, -step * 2), Vector2(2, 2)), Color(Color("c9d2e0"), level))
	draw_rect(Rect2(pin + Vector2(5, -9), Vector2(4, 4)), Color(OUTLINE, level))
	draw_rect(Rect2(pin + Vector2(6, -8), Vector2(2, 2)), Color(Color("e0503c"), level))
	draw_set_transform(Vector2.ZERO)


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
