extends Control
## Who a play is on, drawn on the table the way a saloon keeps score: a
## chalk mark. A ring where it comes from, a line by an unsteady hand, and
## two strokes for the head where it ends. The chalk skips on the grain, so
## the line is made of blocks, some of them missing and no two as white.
## It takes the place of ArrowFx. No class name: preload it (see table.gd).

const BLOCK := 3.0
## How far apart the blocks of a stroke are laid, and how far the hand
## strays from a straight line.
const STEP := 3.0
const BOW := 0.045
const WOBBLE := 2.2
const RING := 9.0
const HEAD := 24.0
const HEAD_SPREAD := 0.5
## The part of `progress` the line takes; the head is drawn in the rest.
const LINE_SHARE := 0.8
const ERASER_WOOD := Color("6a4324")
const ERASER_FELT := Color("d8d2c4")

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

## How much of it the eraser has been over (see wipe).
var erased := 0.0:
	set(value):
		erased = value
		queue_redraw()

var _ring: Array = []  # blocks: {at, alpha}
var _line: Array = []
var _head: Array = []
var _built := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Where the chalk is right now (for whatever follows it: dust, a sound).
func tip() -> Vector2:
	return from.lerp(to, clampf(progress / LINE_SHARE, 0.0, 1.0))


## Rubbed out: an eraser runs over it from the ring to the head, taking the
## chalk with it stretch by stretch, and then it is gone.
func wipe(time := 0.3) -> void:
	var rub := create_tween()
	rub.tween_property(self, "erased", 1.0, time)
	rub.tween_callback(queue_free)


func _draw() -> void:
	if progress <= 0.0:
		return
	if not _built:
		_build()
	# The eraser has been over the first `gone` blocks, in the order drawn.
	var gone := int(erased * (_ring.size() + _line.size() + _head.size()))
	var rubbing := Vector2.INF
	for stroke: Array in [[_ring, 1.0], [_line, clampf(progress / LINE_SHARE, 0.0, 1.0)],
			[_head, clampf((progress - LINE_SHARE) / (1.0 - LINE_SHARE), 0.0, 1.0)]]:
		var blocks: Array = stroke[0]
		if gone > 0 and gone < blocks.size():
			rubbing = blocks[gone].at
		_blocks(blocks, stroke[1], mini(gone, blocks.size()))
		gone = maxi(gone - blocks.size(), 0)
	if erased > 0.0 and erased < 1.0 and rubbing != Vector2.INF:
		# The eraser: a block of wood with felt under it, and the dust it raises.
		draw_rect(Rect2(rubbing + Vector2(-8, -7), Vector2(18, 5)), ERASER_WOOD)
		draw_rect(Rect2(rubbing + Vector2(-8, -2), Vector2(18, 7)), ERASER_FELT)
		draw_rect(Rect2(rubbing + Vector2(-8, 3), Vector2(18, 2)), ERASER_FELT.darkened(0.25))
		for i in 4:
			var puff := Vector2(sin(erased * 40.0 + i * 2.1) * 12.0, 8.0 + cos(erased * 31.0 + i) * 4.0)
			draw_rect(Rect2((rubbing + puff).round(), Vector2(2, 2)), Color(color, 0.45))


func _blocks(blocks: Array, share: float, from := 0) -> void:
	var count := roundi(blocks.size() * share)
	for i in range(from, count):
		var block: Dictionary = blocks[i]
		# What the chalk leaves in the grain next to the stroke.
		draw_rect(Rect2(block.at + Vector2(1, 1), Vector2(BLOCK, BLOCK)), Color(0, 0, 0, 0.3 * block.alpha))
	for i in range(from, count):
		var block: Dictionary = blocks[i]
		draw_rect(Rect2(block.at, Vector2(BLOCK, BLOCK)), Color(color, block.alpha))


## Lays the blocks out once. The dice are seeded by the two ends, so the same
## mark is the same every time it is drawn (only drawing: not the match's).
func _build() -> void:
	_built = true
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([from, to])
	var along := to - from
	var side := along.orthogonal().normalized()
	# The hand does not go straight: the line bows a little to one side.
	var middle := from.lerp(to, 0.5) + side * along.length() * BOW * (1.0 if dice.randf() < 0.5 else -1.0)
	var steps := maxi(ceili(along.length() / STEP), 1)
	var drift := 0.0
	for i in steps + 1:
		var t := float(i) / steps
		var at := from.lerp(middle, t).lerp(middle.lerp(to, t), t)
		drift = clampf(drift + dice.randf_range(-0.6, 0.6), -WOBBLE, WOBBLE)
		_stroke(_line, at + side * drift, side, dice)
	# The ring it starts from, a little way back from the first stroke.
	var hub := from - along.normalized() * RING
	for i in 26:
		var turn := Vector2.from_angle(TAU * i / 26.0)
		_stroke(_ring, hub + turn * RING, turn, dice, 1)
	# The head: two strokes back from the end, along the way the line came in.
	var back := (middle - to).normalized()
	for way: float in [-HEAD_SPREAD, HEAD_SPREAD]:
		var arm := back.rotated(way)
		for i in int(HEAD / STEP):
			_stroke(_head, to + arm * i * STEP, arm.orthogonal(), dice)


## One touch of the chalk at `at`: up to `width` blocks across `side`, the
## middle one nearly always there and the others when the chalk catches.
func _stroke(into: Array, at: Vector2, side: Vector2, dice: RandomNumberGenerator, width := 3) -> void:
	for k in width:
		var off := k - (width - 1) / 2.0
		if dice.randf() > (0.92 if off == 0.0 else 0.6):
			continue
		var cell := ((at + side * off * BLOCK) / BLOCK).floor() * BLOCK
		into.append({"at": cell, "alpha": dice.randf_range(0.55, 1.0)})
