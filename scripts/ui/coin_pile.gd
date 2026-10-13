extends Control
## Coins set down on the table: the price of a claim, put in front of
## whoever pays it until the claim is settled (see table._reserve_coins). Not
## a counter but the thing itself: stacks seen a little from above, a coin
## to a slab, as high as there are coins, a new stack beside the last once
## one is STACK high. Drawn in the 2 px blocks of the table's props.
##
## The origin is the foot of the first stack. No class_name: use preload.

const PX := 2.0
## How many coins to a stack, how wide and how thick a coin is, and from one
## stack to the next.
const STACK := 5
const COIN := 22.0
const THICK := 4.0
const STEP := 26.0
## The edge of a coin, two tones taking turns up the stack, its milling, the
## face of the one on top and the light on it.
const EDGES: Array[Color] = [Color("c8982e"), Color("a87a22")]
const MILLED := Color("7d5616")
const FACE := Color("e6bc4c")
const SHINE := Color("fbe9a4")
const RIM := Color("5a3c10")
const SHADOW := Color(0, 0, 0, 0.35)

## How many coins lie there.
var count := 0:
	set(value):
		count = maxi(value, 0)
		queue_redraw()


func _init() -> void:
	# Only for the mouse to rest on (a tooltip says how many there are).
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## What the stacks cover, from the foot of the first one (the node has no
## size of its own: it is drawn round its origin).
func extent() -> Rect2:
	@warning_ignore("integer_division")
	var stacks := maxi((count + STACK - 1) / STACK, 1)
	var high := THICK * mini(maxi(count, 1), STACK) + PX * 2.0
	return Rect2(-COIN / 2.0 - PX, -high, COIN + STEP * (stacks - 1) + PX * 2.0, high + PX)


func _has_point(point: Vector2) -> bool:
	return count > 0 and extent().has_point(point)


## Where a tooltip has to keep out of (see TipLayer).
func tip_rect() -> Rect2:
	var box := extent()
	return Rect2(global_position + box.position, box.size)


func _draw() -> void:
	var left := count
	var stack := 0
	while left > 0:
		var high := mini(left, STACK)
		_stack(Vector2(stack * STEP, 0), high, stack)
		left -= high
		stack += 1


## One stack of `high` coins standing on `foot` (the middle of its base).
func _stack(foot: Vector2, high: int, nth: int) -> void:
	var x := foot.x - COIN / 2.0
	draw_rect(Rect2(x - PX, foot.y - PX, COIN + PX * 3.0, PX * 2.0), SHADOW)
	for i in high:
		# No stack is quite straight: each coin sits a block off, or not.
		var lean := PX * float((i * 7 + nth * 3) % 3 - 1) if i > 0 else 0.0
		var y := foot.y - THICK * (i + 1)
		var at := x + lean
		draw_rect(Rect2(at, y, COIN, THICK), EDGES[i % 2])
		draw_rect(Rect2(at, y + THICK - PX, COIN, PX), MILLED)
		# A few notches of milling, not lined up from one coin to the next.
		for notch in 2:
			draw_rect(Rect2(at + PX * 3.0 + notch * 8.0 + (i % 2) * 4.0, y, PX, PX), MILLED)
		draw_rect(Rect2(at, y, PX, PX), SHINE)
		if i == high - 1:
			# The one on top shows its face: a flat lid, lighter than the edges.
			draw_rect(Rect2(at, y - PX, COIN, PX), FACE)
			draw_rect(Rect2(at + PX * 2.0, y - PX, PX * 3.0, PX), SHINE)
			draw_rect(Rect2(at + COIN - PX * 3.0, y - PX, PX * 2.0, PX), RIM)
