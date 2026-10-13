extends Control
## The clock of a timed turn (GameConfig.turn_seconds): an outline round the
## box of whoever is playing, drawn in the 2 px blocks of the boxes. It starts
## whole and green and is eaten away, clockwise from the middle of the top,
## as the time goes, turning yellow, orange and at last a dark red.
##
## With `fuse` it burns like one: sparks fly off the end of the line as it
## is eaten (the time the table has for its side bets, round their prompt).
##
## The node is laid over the box it goes round (`box`, in its own
## coordinates) and only draws: it takes no input. No class_name: use preload.

const PX := 2.0
## How thick the line is, and how far outside the box it runs.
const WIDTH := 4.0
const GAP := 2.0
## The colour of the line by how much time is left, from none to all of it.
const INKS: Array[Color] = [Color("5a0f0c"), Color("a3241a"), Color("d8662a"), Color("e6bc4c"), Color("78a846")]
## Under this much time left the line throbs.
const HURRY := 0.25
## The sparks of a fuse: how many leave its end every frame, how fast, how
## long they last and how hard they fall.
const SPARKS := 2
const SPARK_SPEED := 90.0
const SPARK_LIFE := 0.4
const SPARK_FALL := 300.0
const SPARK_INKS: Array[Color] = [Color("fff6d0"), Color("ffd94a"), Color("f08a24"), Color("9a2a14")]

## The box the clock goes round.
var box := Rect2():
	set(value):
		box = value
		queue_redraw()
## How much of the time is left, 1 to 0. Below 0 the clock is put away.
var left := -1.0:
	set(value):
		left = value
		visible = value >= 0.0
		queue_redraw()


## The line burns away like a fuse, throwing sparks off its end.
var fuse := false
var _sparks: Array = []  # {at, v, age, life}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func _process(delta: float) -> void:
	if not visible:
		_sparks.clear()
		return
	if fuse:
		# Only drawing: any dice will do.
		if left > 0.0:
			var end := tip()
			for i in SPARKS:
				_sparks.append({
					"at": end, "v": Vector2(randf_range(-1.0, 1.0), randf_range(-1.3, 0.3)) * SPARK_SPEED,
					"age": 0.0, "life": randf_range(0.4, 1.0) * SPARK_LIFE,
				})
		for spark: Dictionary in _sparks:
			spark.age += delta
			spark.v.y += SPARK_FALL * delta
			spark.at += spark.v * delta
		_sparks = _sparks.filter(func(spark: Dictionary) -> bool: return spark.age < spark.life)
	if fuse or left < HURRY:
		queue_redraw()


## Where the line ends right now: the burning end of a fuse.
func tip() -> Vector2:
	var rect := _frame().grow(-WIDTH / 2.0)
	var way := (1.0 - clampf(left, 0.0, 1.0)) * 2.0 * (rect.size.x + rect.size.y)
	for side: Array in _sides(rect):
		var length: float = side[1]
		if way <= length:
			var from: Vector2 = side[2]
			var along: Vector2 = side[3]
			return from + along * way
		way -= length
	return rect.position + Vector2(rect.size.x / 2.0, 0)


## What the line runs along the inside of: the box and the gap round it, on
## the grid of the blocks. Its sides are whole blocks long and so is half of
## its width, or the stretches, each measured from its own corner, would end
## a pixel apart where two of them meet (they did, at two of the corners).
func _frame() -> Rect2:
	var rect := box.grow(GAP + WIDTH)
	var at := (rect.position / PX).round() * PX
	var extent := (rect.size / (PX * 2.0)).round() * PX * 2.0
	return Rect2(at, extent)


## The four sides of `rect` as stretches of the way round it, clockwise from
## the middle of the top: [where it begins, how long, its first point, its way].
func _sides(rect: Rect2) -> Array:
	var w := rect.size.x
	var h := rect.size.y
	return [
		[0.0, w / 2.0, rect.position + Vector2(w / 2.0, 0), Vector2.RIGHT],
		[w / 2.0, h, rect.position + Vector2(w, 0), Vector2.DOWN],
		[w / 2.0 + h, w, rect.end, Vector2.LEFT],
		[w * 1.5 + h, h, rect.position + Vector2(0, h), Vector2.UP],
		[w * 1.5 + h * 2.0, w / 2.0, rect.position, Vector2.RIGHT],
	]


## The colour of a clock with `amount` of its time left.
static func ink(amount: float) -> Color:
	var at := clampf(amount, 0.0, 1.0) * (INKS.size() - 1)
	var low := mini(int(at), INKS.size() - 2)
	return INKS[low].lerp(INKS[low + 1], at - low)


func _draw() -> void:
	if left < 0.0:
		return
	var rect := _frame()
	var color := ink(left)
	if left < HURRY:
		color = color.lightened(0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)))
	# The whole way round, faint, and over it what is left of the time.
	_stroke(rect, 0.0, 1.0, Color(UI.INK, 0.55))
	_stroke(rect, 1.0 - clampf(left, 0.0, 1.0), 1.0, color)
	if not fuse:
		return
	# The burning end, flickering, and what flies off it.
	if left > 0.0:
		var at := tip().round()
		var flare := 4.0 + PX * float(randi() % 3)
		draw_rect(Rect2(at - Vector2(flare, flare), Vector2(flare, flare) * 2.0), Color(SPARK_INKS[2], 0.75))
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), SPARK_INKS[1])
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), SPARK_INKS[0])
	for spark: Dictionary in _sparks:
		var spent: float = spark.age / spark.life
		var ink := SPARK_INKS[mini(int(spent * SPARK_INKS.size()), SPARK_INKS.size() - 1)]
		var pos: Vector2 = spark.at
		draw_rect(Rect2((pos / PX).floor() * PX, Vector2(PX, PX)), ink)


## Draws the outline of `rect` from `from` to `to` of the way round it (0 to
## 1, clockwise from the middle of the top), in blocks.
func _stroke(rect: Rect2, from: float, to: float, color: Color) -> void:
	var around := 2.0 * (rect.size.x + rect.size.y)
	var start := from * around
	var stop := to * around
	for side: Array in _sides(rect):
		var begins: float = side[0]
		var length: float = side[1]
		var corner_at: Vector2 = side[2]
		var way: Vector2 = side[3]
		var a := maxf(start, begins) - begins
		var b := minf(stop, begins + length) - begins
		# The corners belong to the sides that lie flat: an upright one stops
		# short of them, so no two stretches are ever drawn over each other
		# (the joins showed, darker, wherever the line is see-through).
		if way.x == 0.0:
			a = maxf(a, WIDTH)
			b = minf(b, length - WIDTH)
		if b <= a:
			continue
		var head := corner_at + way * (roundf(a / PX) * PX)
		var tail := corner_at + way * (roundf(b / PX) * PX)
		# The line lies inside `rect`, along the side it runs on.
		var inward := Vector2(-way.y, way.x)
		var corner := Vector2(minf(head.x, tail.x), minf(head.y, tail.y))
		var extent := (tail - head).abs() + inward.abs() * WIDTH
		if inward.x < 0.0:
			corner.x -= WIDTH
		if inward.y < 0.0:
			corner.y -= WIDTH
		draw_rect(Rect2(corner, extent), color)
