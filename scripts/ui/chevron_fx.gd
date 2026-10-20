extends Control
## The mark of a play on the table: a golden chevron set against the box of
## whoever made it, pointing at whoever it is aimed at. It is cast as the
## play is announced (cast): drawn back against the box, it shoots across the
## table to the target leaving a trail of fading chevrons, strikes there in a
## pulse of light and comes home, and from then on it only rests against its
## box, breathing a little, with a glint running along it now and then. That
## is all that stays for the rest of the turn (the table clears it as the
## next turn starts: dismiss).
##
## Drawn in blocks of CELL from a text bitmap pointing right, turned towards
## the target. A play that hurts or takes (`hostile`) strikes in red. No class
## name: preload it (see table._stage_arrow).

const CELL := 3.0
const SHAPE := [
	"ooo.........",
	"o#+o........",
	"o##+o.......",
	".o##+o......",
	"..o##+o.....",
	"...o###o....",
	"....o###o...",
	"...o##-o....",
	"..o##-o.....",
	".o##-o......",
	"o##-o.......",
	"o#-o........",
	"ooo.........",
]
const OUTLINE := Color("4a2c0c")
const GOLD := Color("f2c84b")
const GOLD_LIGHT := Color("fff0b0")
const GOLD_DARK := Color("b8862a")
const RED := Color("ef5a48")
## The parts of a cast, in seconds: drawn back, the flight, the strike, home.
const DRAW_BACK := 0.12
const FLIGHT := 0.34
const STRIKE := 0.2
const HOME := 0.32
const TRAIL_STEP := 16.0

## Where it rests (against the actor's box) and where it strikes (just
## outside the target's box), on the table.
var rest := Vector2.ZERO
var strike := Vector2.ZERO
var hostile := false

## Where the chevron is right now, and how big.
var _at := Vector2.ZERO
var _grow := 1.0
var _trail: Array = []  # [{at, life}]
var _pulse := -1.0  # seconds since the strike; -1 with none
var _time := 0.0
var _resting := false
var _fade := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Shoots the chevron at its target and back. `speed` is the table's pace.
func cast(speed: float) -> void:
	_at = rest
	_resting = false
	var way := (strike - rest).normalized()
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_at = rest - way * 6.0 * sin(t * PI / 2.0)
		_grow = 1.0 + 0.15 * t, 0.0, 1.0, DRAW_BACK / speed)
	tween.tween_method(_fly.bind(rest - way * 6.0), 0.0, 1.0, FLIGHT / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_pulse = 0.0
		_grow = 1.6)
	tween.tween_property(self, "_grow", 1.0, STRIKE / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		_at = strike.lerp(rest, t), 0.0, 1.0, HOME / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _resting = true)
	set_process(true)


## Gone: it fades where it is, and is freed.
func dismiss(speed: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "_fade", 0.0, 0.3 / speed)
	tween.tween_callback(queue_free)


func _fly(t: float, from: Vector2) -> void:
	var before := _at
	_at = from.lerp(strike, t)
	_grow = 1.15 - 0.15 * t
	# A ghost left behind every so often along the way.
	var last: Vector2 = _trail.back().at if not _trail.is_empty() else from
	if last.distance_to(_at) >= TRAIL_STEP or before == from:
		_trail.append({"at": _at, "life": 1.0})


func _process(delta: float) -> void:
	_time += delta
	for ghost: Dictionary in _trail:
		ghost.life -= delta * 2.2
	_trail = _trail.filter(func(ghost: Dictionary) -> bool: return ghost.life > 0.0)
	if _pulse >= 0.0:
		_pulse += delta
		if _pulse > 0.5:
			_pulse = -1.0
	queue_redraw()


func _draw() -> void:
	var angle := (strike - rest).angle()
	for ghost: Dictionary in _trail:
		_chevron(ghost.at, angle, 0.8, 0.45 * ghost.life * _fade, false)
	if _pulse >= 0.0:
		var t := _pulse / 0.5
		var ink := RED if hostile else GOLD_LIGHT
		_diamond(strike, 8.0 + 34.0 * t, Color(ink, (1.0 - t) * _fade))
		_diamond(strike, 4.0 + 18.0 * t, Color(GOLD, (1.0 - t) * 0.7 * _fade))
	var breathe := 1.5 * sin(_time * 2.4) if _resting else 0.0
	_chevron(_at + Vector2.from_angle(angle) * breathe, angle, _grow, _fade, _resting)


## The chevron centred on `at`, turned to `angle`, `grow` times its size.
## While resting, a glint runs down it every few seconds.
func _chevron(at: Vector2, angle: float, grow: float, alpha: float, glint: bool) -> void:
	if alpha <= 0.0:
		return
	var cell := CELL * grow
	var width := String(SHAPE[0]).length()
	var corner := -Vector2(width, SHAPE.size()) * cell / 2.0
	draw_set_transform(at, angle)
	var sweep := fposmod(_time * 0.45, 1.0) * 3.0 * SHAPE.size() if glint else -100.0
	for y: int in SHAPE.size():
		var row: String = SHAPE[y]
		for x: int in row.length():
			var ink: Color
			match row[x]:
				"o":
					ink = OUTLINE
				"#":
					ink = GOLD.lerp(RED, 0.35) if hostile else GOLD
				"+":
					ink = GOLD_LIGHT
				"-":
					ink = GOLD_DARK
				_:
					continue
			if row[x] != "o" and absf(x + y - sweep) < 1.5:
				ink = GOLD_LIGHT
			draw_rect(Rect2(corner + Vector2(x, y) * cell, Vector2(cell, cell)), Color(ink, alpha))
	draw_set_transform(Vector2.ZERO)


func _diamond(at: Vector2, reach: float, ink: Color) -> void:
	var points := PackedVector2Array([at + Vector2(reach, 0), at + Vector2(0, reach), at - Vector2(reach, 0), at - Vector2(0, reach), at + Vector2(reach, 0)])
	draw_polyline(points, ink, 2.0)
