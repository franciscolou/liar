extends Control
## The chains of the Entity's Entropy, thrown over a player's box: two of
## them crossed over it, corner to corner, held where they meet by a
## four-pointed star. They are not quite of this table:
## every link is seen three times over, in red, in cyan and in pale steel, a
## little apart, and light of every
## colour runs along them and drifts between them.
##
## Drawn in code, in blocks, like the rest of StatusFx, which keeps it. No
## class name: preload it.

const CELL := 2.0
## From one link to the next along a chain: they overlap, as links do.
const PITCH := 8.0
## How far short of the corners of the box the chains stop: the last link,
## and its three images, stay inside it.
const INSET := 10.0
## How far apart the three images of a link are.
const SPLIT := 2.0
## How much wider they are while the chains are still being thrown on.
const SPLIT_BINDING := 12.0
const STEEL := Color("e9ecff")
const STEEL_DARK := Color("8f96c4")
const RED := Color(1.0, 0.16, 0.36)
const CYAN := Color(0.1, 0.95, 1.0)
const VIOLET := Color("9b6bff")
const ALARM := Color("ff2a3c")
const ALARM_DARK := Color("8a0f1e")
const VOID := Color("05030a")
const STAR := [
	"....#....",
	"....#....",
	"....#....",
	"...#+#...",
	"###+++###",
	"...#+#...",
	"....#....",
	"....#....",
	"....#....",
]
## Lights drifting between the chains.
const MOTES := 14
## Chains with nothing left in them (see snap): plain iron, the seconds the
## light takes to leave them before they give, how long the pieces are
## there for, and what they fall under.
const IRON := Color("9a9fa8")
const IRON_DARK := Color("4a4e57")
const DRAIN := 0.14
const WRECK := 1.15
const WEIGHT := 760.0

## What the chains are wound about, in the coordinates of this node.
var box := Rect2():
	set(value):
		box = value
		_lay()
## How much of each chain has been thrown on, 0 to 1 from its first link.
var bound := 0.0:
	set(value):
		bound = value
		visible = bound > 0.0 or not _wreck.is_empty()
		set_process(visible)

## How close they are to being thrown away, 0 to 1: the player in them has
## a hand on the LIAR! that would cost them (see StatusFx.threaten). They go
## red and strain at the box, and a hole starts where the star was.
var doomed := 0.0

## One entry per chain: the middle of every link, first to last.
var _chains: Array = []
var _time := 0.0
## The links (and the star, `link` -1) of chains that snapped, each {at,
## speed, turn, spin, floor, link}, and the seconds since.
var _wreck: Array = []
var _snapped := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# So that two players in chains do not shimmer as one.
	_time = randf() * 20.0


func _ready() -> void:
	set_process(visible)


func _process(delta: float) -> void:
	_time += delta
	if not _wreck.is_empty():
		_fall(delta)
	queue_redraw()


## Whoever was in them is out, and whatever ran through them went too: the
## colours go out of them, they are ordinary iron for a moment, and then
## they break all at once and fall where they hung. Nothing of the sky in
## it, and nothing is paid (compare PlayFx.chains_break).
func snap() -> void:
	_wreck.clear()
	_snapped = 0.0
	var centre := box.get_center()
	for chain: Array in _chains:
		for i: int in _shown(chain):
			var at: Vector2 = chain[i]
			var way: Vector2 = chain[mini(i + 1, chain.size() - 1)] - chain[maxi(i - 1, 0)]
			var out := (at - centre).normalized() if at.distance_to(centre) > 1.0 else Vector2.UP
			_wreck.append({
				"at": at, "turn": way.angle(), "link": i,
				"speed": out * randf_range(30.0, 190.0) + Vector2(randf_range(-70.0, 70.0), randf_range(-230.0, -40.0)),
				"spin": randf_range(-14.0, 14.0),
				"floor": at.y + randf_range(26.0, 64.0),
			})
	if bound >= 1.0:
		_wreck.append({"at": centre, "turn": 0.0, "link": -1, "speed": Vector2(randf_range(-30.0, 30.0), -150.0),
				"spin": randf_range(-9.0, 9.0), "floor": centre.y + 50.0})
	visible = not _wreck.is_empty()
	set_process(visible)
	queue_redraw()


func _fall(delta: float) -> void:
	_snapped += delta
	if _snapped >= WRECK:
		_wreck.clear()
		visible = bound > 0.0
		set_process(visible)
		return
	if _snapped < DRAIN:
		return
	for piece: Dictionary in _wreck:
		var speed: Vector2 = piece.speed + Vector2(0, WEIGHT * delta)
		var at: Vector2 = piece.at + speed * delta
		piece.turn += piece.spin * delta
		if at.y > piece.floor and speed.y > 0.0:
			# It lands, hops once and lies there.
			at.y = piece.floor
			var hops := speed.y > 120.0
			speed = Vector2(speed.x * 0.45, -speed.y * 0.28) if hops else Vector2.ZERO
			piece.spin *= 0.3 if hops else 0.0
		piece.speed = speed
		piece.at = at


func _draw_wreck() -> void:
	var dead := clampf(_snapped / DRAIN, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(WRECK - 0.35, WRECK, _snapped)
	var split := SPLIT * (1.0 - dead)
	for image: int in 3:
		if image < 2 and dead >= 1.0:
			continue
		var ink: Color = [RED, CYAN, STEEL][image]
		for piece: Dictionary in _wreck:
			var at: Vector2 = piece.at + Vector2([-split, split, 0.0][image], 0)
			if piece.link < 0:
				draw_set_transform(Vector2.ZERO)
				if image == 2:
					draw_set_transform(at.round(), piece.turn)
					_star(Vector2.ZERO, Color(VIOLET.lerp(IRON_DARK, dead), alpha), Color(Color.WHITE.lerp(IRON, dead), alpha))
				continue
			draw_set_transform(at.round(), piece.turn)
			if image < 2:
				_link(piece.link, Color(ink, 0.6 * (1.0 - dead)), Color(ink, 0.6 * (1.0 - dead)))
			else:
				_link(piece.link, Color(STEEL.lerp(IRON, dead), alpha), Color(STEEL_DARK.lerp(IRON_DARK, dead), alpha))
	draw_set_transform(Vector2.ZERO)


## Where every link that is on is right now, on screen: what the chains fly
## apart from when they break.
func links() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var onto := get_global_transform()
	for chain: Array in _chains:
		for i: int in _shown(chain):
			out.append(onto * chain[i])
	return out


## Where the chains cross, on screen.
func knot() -> Vector2:
	return get_global_transform() * box.get_center()


func _lay() -> void:
	_chains.clear()
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var around := box.grow(-INSET)
	var corners: Array[Vector2] = [around.position, Vector2(around.end.x, around.position.y),
			around.end, Vector2(around.position.x, around.end.y)]
	_chains.append(_run(corners[0], corners[2], 5.0))
	_chains.append(_run(corners[1], corners[3], 5.0))


## The links of a chain hung from `from` to `to`, sagging by `sag` in the
## middle.
func _run(from: Vector2, to: Vector2, sag: float) -> Array:
	var points: Array = []
	var count := maxi(roundi(from.distance_to(to) / PITCH), 2)
	for i: int in count + 1:
		var along := float(i) / count
		points.append(from.lerp(to, along) + Vector2(0, sin(along * PI) * sag))
	return points


func _shown(chain: Array) -> int:
	return clampi(ceili(bound * chain.size()), 0, chain.size())


func _draw() -> void:
	if not _wreck.is_empty():
		_draw_wreck()
		return
	if _chains.is_empty():
		return
	var split := lerpf(SPLIT_BINDING, SPLIT, bound * bound)
	var centre := box.get_center()
	# About to go: everything they are is red, beating fast.
	var beat := 0.5 + 0.5 * sin(_time * 13.0)
	split += 3.0 * doomed * beat
	draw_circle(centre, 20.0 + 3.0 * sin(_time * 2.1), Color(VIOLET.lerp(ALARM, doomed), (0.1 + 0.16 * doomed * beat) * bound))
	for image: int in 3:
		var ink: Color = [RED, CYAN, STEEL][image].lerp(ALARM, doomed)
		var apart := Vector2([-split, split, 0.0][image], 0)
		for c: int in _chains.size():
			var chain: Array = _chains[c]
			var shown := _shown(chain)
			for i: int in shown:
				var at: Vector2 = chain[i] + apart
				if doomed > 0.0:
					# Pulled taut towards where they cross, and shivering.
					at += (centre - at).limit_length(2.0 * doomed * beat)
					at += Vector2(sin(_time * 41.0 + i * 1.9 + c), cos(_time * 35.0 + i * 2.3)) * 1.2 * doomed
				var way: Vector2 = chain[mini(i + 1, chain.size() - 1)] - chain[maxi(i - 1, 0)]
				draw_set_transform(at.round(), way.angle())
				if image < 2:
					_link(i, Color(ink, 0.6), Color(ink, 0.6))
					continue
				# The light running along it, and the link being thrown on.
				var lit := _glow(c, i, chain.size())
				var head := bound < 1.0 and i >= shown - 2
				var bright: Color = Color.WHITE if head else STEEL.lerp(_hue(c, i), lit)
				var shade: Color = bright if head else STEEL_DARK.lerp(_hue(c, i), lit)
				var hot := ALARM.lerp(Color.WHITE, 0.55 * maxf(beat, lit))
				_link(i, bright.lerp(hot, doomed), shade.lerp(ALARM_DARK.lerp(ALARM, beat), doomed))
	draw_set_transform(Vector2.ZERO)
	if bound < 1.0:
		return
	_drift(centre)
	# The star that holds them where they cross.
	var pulse := 0.5 + 0.5 * sin(_time * 3.3)
	draw_circle(centre, 9.0 + 3.0 * pulse, Color(VIOLET.lerp(ALARM, doomed), 0.22 + 0.2 * doomed * beat))
	_star(centre + Vector2(-split, 0), Color(RED, 0.6), Color(RED, 0.6))
	_star(centre + Vector2(split, 0), Color(CYAN, 0.6), Color(CYAN, 0.6))
	_star(centre, VIOLET.lerp(Color.WHITE, 0.4 + 0.4 * pulse).lerp(ALARM, doomed), Color.WHITE)
	if doomed > 0.0:
		_maw(centre, (5.0 + 2.0 * beat) * doomed)


## One link at the origin, lying along +x: every other one is seen face on,
## a ring, and the ones between edge on, a bar through the two next to it.
func _link(index: int, light: Color, dark: Color) -> void:
	if index % 2 == 1:
		draw_rect(Rect2(-5, -1, 10, 2), light)
		return
	draw_rect(Rect2(-6, -4, 12, 2), light)
	draw_rect(Rect2(-6, 2, 12, 2), dark)
	draw_rect(Rect2(-6, -2, 2, 4), light)
	draw_rect(Rect2(4, -2, 2, 4), dark)


## How brightly link `index` of chain `chain` is lit: two lights run along
## each of them, one after the other.
func _glow(chain: int, index: int, count: int) -> float:
	var lit := 0.0
	for light: int in 2:
		var at := fposmod(_time * 0.3 + light * 0.5 + chain * 0.27, 1.0) * count
		lit = maxf(lit, 1.0 - absf(index - at) / 3.5)
	return clampf(lit, 0.0, 1.0)


func _hue(chain: int, index: int) -> Color:
	return Color.from_hsv(fposmod(index * 0.035 + _time * 0.22 + chain * 0.5, 1.0), 0.55, 1.0)


## Small lights that leave the ends of the chains and wander in between them
## to the star, every one a colour of its own.
func _drift(centre: Vector2) -> void:
	for i: int in MOTES:
		var chain: Array = _chains[i % 2]
		var life := fposmod(_time * (0.16 + 0.05 * _noise(i * 3.1)) + _noise(i * 7.7), 1.0)
		var from: Vector2 = chain[0] if i % 4 < 2 else chain[chain.size() - 1]
		var along := from.lerp(centre, life)
		var side := (centre - from).orthogonal().normalized()
		var at := along + side * sin(life * TAU * 1.5 + i) * 16.0 * (1.0 - life)
		var ink := Color.from_hsv(fposmod(i * 0.21 + _time * 0.1, 1.0), 0.5, 1.0)
		var alpha := sin(life * PI) * (0.55 + 0.45 * sin(_time * 9.0 + i * 2.0))
		var corner := (at / CELL).floor() * CELL
		draw_rect(Rect2(corner, Vector2(CELL, CELL)), Color(ink, alpha))
		if i % 3 == 0:
			for arm: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_rect(Rect2(corner + arm * CELL, Vector2(CELL, CELL)), Color(ink, alpha * 0.5))


## The hole that would take them, starting to open on the star: a black
## disc in blocks with a red rim.
func _maw(at: Vector2, radius: float) -> void:
	var cells := ceili(radius / CELL) + 2
	for y: int in range(-cells, cells + 1):
		for x: int in range(-cells, cells + 1):
			var far := (Vector2(x + 0.5, y + 0.5) * CELL).length()
			if far <= radius + CELL:
				draw_rect(Rect2((at / CELL).round() * CELL + Vector2(x, y) * CELL, Vector2(CELL, CELL)), VOID if far <= radius else ALARM)


func _star(at: Vector2, edge: Color, core: Color) -> void:
	var corner := (at / CELL).round() * CELL - Vector2(STAR[0].length(), STAR.size()) * CELL / 2.0
	for y: int in STAR.size():
		var row: String = STAR[y]
		for x: int in row.length():
			if row[x] != ".":
				draw_rect(Rect2(corner + Vector2(x, y) * CELL, Vector2(CELL, CELL)), core if row[x] == "+" else edge)


## A number from 0 to 1 that is always the same for the same `x`.
func _noise(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)
