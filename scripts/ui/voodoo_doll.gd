extends Control
## The Voodooist's doll: a rag doll seen from the side, slumped back against
## whatever is behind it, the far leg laid out in front of it along what it
## sits on and the near one hanging, an arm dangling and a head that lolls.
## It was sewn together out of whatever there was: burlap, a darker cloth
## for half the head and the far limbs, tan, slate, mustard and wine patches,
## every seam in pale thread. One button eye, one stitched cross, a noose of
## twine, a heart sewn on the chest, straw at the cuffs and three pins.
##
## It is a toy: nothing in it moves by itself, it only settles, swaying. What moves is what it does: purple motes
## wind round it and into its chest, and more are drawn out of whoever it is
## pinned on (`drain`).
##
## Asleep (`awake` 0) it is only a rag doll: slumped further, its head on its
## chest, still, its colours gone dull, and nothing magic about it at all.
## Awake, the sway and the purple come back. `hunger` makes it feed hard (a
## doll cursing its carrier) and `stagger` makes it totter about where it
## sits (a doll dragging something over to itself).
##
## The origin is the point it sits on. Every part is a bitmap turned about
## its joint. StatusFx keeps one for as long as a player is hexed; PlayFx
## throws one (see _fx_voodooist_hex). No class name: preload it.

## The bitmaps are laid out in cells of CELL, facing right, and the whole
## doll is drawn GROWN times that, turned to face `facing`.
const CELL := 1.5
const GROWN := 1.2
## How far it leans back, and the joints its floppy parts hang from.
const LEAN := -0.2
const NECK := Vector2(0, -20)
const SHOULDER := Vector2(7, -15)
const HIP := Vector2(2, -3)
## Its chest, facing right: where everything it takes ends up (see heart()).
const HEART := Vector2(-3, -13)
const HEX := Color("9a62c4")
const HEX_LIGHT := Color("d3a6f2")
const HEX_DARK := Color("5a2f86")
## Motes winding round it, and motes on their way in from `drain`.
const SWIRL := 18
const STREAM := 9

## o: outline, B: burlap, L: where the light catches it, S: its shadow,
## D: a darker cloth, T: tan, G: slate, M: mustard, W: wine, c: pale thread,
## P: a patch of other cloth, r: red thread, t: brown thread, x: a stitched
## eye, k and w: a button, n: twine, y: straw, e: steel, h and H: a pin's head.
const INK := {
	"o": Color("1c110a"), "B": Color("8a5f38"), "L": Color("a87a4c"), "S": Color("5e3f24"),
	"P": Color("6a5a46"), "r": Color("8a2418"), "t": Color("3e2815"), "x": Color("2a0c0a"),
	"k": Color("16100e"), "w": Color("cfc6b0"), "n": Color("c2a468"), "y": Color("c9a23e"),
	"e": Color("d6dde8"), "h": Color("c8322a"), "H": Color("ff8a70"),
	"D": Color("684428"), "T": Color("b48c5a"), "G": Color("4f5f66"), "M": Color("a8802c"),
	"W": Color("742c30"), "c": Color("e2d4b2"),
}
const HEAD := [
	"..ooooooo..",
	".oLLLBcDDo.",
	"oLLBBBcDDSo",
	"oLxBxBBkkSo",
	"oLBxBBckwSo",
	"oBxBxBBBBSo",
	"oBBBBBcBBSo",
	"oBrBrBrBrSo",
	".oBrBrBrSo.",
	"..ooooooo..",
]
const BODY := [
	"...nnnnnnnn...",
	"..onnnnnnnno..",
	".oLLBBBBcTTSo.",
	"oLLBBrrBcTTTSo",
	"oLBBrrrrcTTTSo",
	"oLBBBrrBBcTTSo",
	"oBBBBBBBBcccSo",
	"oGGGcBBBBBBBSo",
	"oGGGcBtBtBBBSo",
	"oGGGcBBBBBWWSo",
	"oScccBBBBcWWSo",
	".oSSBBBBBSSSo.",
	"..oooooooooo..",
]
## The arm on the far side, cut from the darker cloth.
const ARM_FAR := [
	".oo.",
	"oDDo",
	"oDDo",
	"oDSo",
	"occo",
	"oBSo",
	"oBSo",
	"oSSo",
	"oyyo",
	".yy.",
]
## Hanging from the shoulder: its top middle is the joint.
const ARM := [
	".oo.",
	"oLBo",
	"oLBo",
	"oBBo",
	"occo",
	"oMMo",
	"oMSo",
	"oMSo",
	"oyyo",
	".yy.",
]
## The leg laid out in front of it, its foot turned up at the far end.
const LEG_FLAT := [
	".............ooo.",
	".oooooooooooooTSo",
	"oDDDDcBBBcDDDDTSo",
	"oDDDDcBBBcDDDSSSo",
	"oSSSSSSSSSSSSSSo.",
	".oooooooooooooo..",
]
## The leg that hangs, from the hip at its top.
const LEG_LOOSE := [
	".ooooo...",
	"oLBBBSo..",
	"oLBBBSo..",
	"oBcccSo..",
	"oWWWBSo..",
	"oWWWBSo..",
	"oBcccSo..",
	"oBBBBSo..",
	"oBBBSSooo",
	"oTTTTTTSo",
	"oSSSSSSSo",
	".ooooooo.",
]
## A pin, from its point up to its head.
const PIN := [
	"....oo",
	"...ohH",
	"...ohh",
	"..eeo.",
	".ee...",
	"ee....",
]

## How much of it is there: it grows in and fades with this.
var level := 1.0:
	set(value):
		level = value
		visible = level > 0.0
		set_process(visible)
## Where what it takes comes from, from its own origin: the middle of the box
## of whoever it is pinned on. Nothing is drawn out of anybody while this is
## Vector2.INF (in the air, say).
var drain := Vector2.INF
## In the air: everything loose flies about.
var thrown := false
## Which way it faces: -1 left (its back to the right), 1 right.
var facing := -1.0
## 0 asleep, 1 awake: see the top of the file.
var awake := 1.0
## 0 to 1: how hard it is feeding, and how badly it totters.
var hunger := 0.0
var stagger := 0.0
## Whether there is room under it for a leg to hang. Without it both legs
## lie along what it sits on.
var hangs := true
var _time := 0.0
## The clock of the swirl, which runs faster the hungrier it is.
var _suck := 0.0
## Where the whole of it is pushed and how far it is tipped, as it totters.
var _shift := Vector2.ZERO
var _tilt := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# So that two dolls do not move as one.
	_time = randf() * 20.0


## Its chest, from where it sits.
func heart() -> Vector2:
	return Vector2(HEART.x * facing, HEART.y)


func _process(delta: float) -> void:
	_time += delta
	_suck += delta * (0.5 + 3.5 * hunger)
	queue_redraw()


func _draw() -> void:
	_draw_swirl(false)
	var grown := lerpf(0.5, 1.0, ease(level, 0.4))
	# It only settles: slow sways that never start or stop, each part in its
	# own time, so nothing in it is ever seen to begin again.
	# Asleep, it does not even sway: it lies where it was put.
	var life := awake
	var asleep := 1.0 - awake
	var lean := LEAN - 0.1 * asleep + 0.03 * life * sin(_time * 0.7)
	var swing := life * (0.16 * sin(_time * 1.3) + 0.05 * sin(_time * 2.9 + 1.0))
	var dangle := 0.5 + 0.15 * asleep + 0.1 * life * sin(_time * 1.1 + 1.0)
	var loll := -0.08 + 0.38 * asleep + life * (0.06 * sin(_time * 0.9) + 0.02 * sin(_time * 2.3))
	var sway := 0.03 * life * sin(_time * 1.6 + 2.0)
	# Coming to: it jerks, a few times, and the head comes up off its chest.
	var stir := sin(awake * PI)
	if stir > 0.01:
		loll += stir * 0.25 * sin(_time * 31.0)
		dangle += stir * 0.3 * sin(_time * 27.0 + 1.0)
		swing += stir * 0.3 * sin(_time * 23.0)
	if not hangs:
		# Sat on the floor: the near leg lies out too, a little raised.
		swing = -1.32 + 0.03 * life * sin(_time * 1.3)
	# Tottering: the whole of it lurches about and hops, limbs flung loose.
	_tilt = stagger * (0.32 * sin(_time * 3.1) + 0.14 * sin(_time * 7.3 + 1.0))
	_shift = stagger * Vector2(6.0 * sin(_time * 2.3) + 3.0 * sin(_time * 5.9), -5.0 * absf(sin(_time * 4.6)))
	if stagger > 0.0:
		loll += stagger * 0.45 * sin(_time * 3.7)
		dangle += stagger * 0.5 * sin(_time * 6.1)
		swing += stagger * 0.4 * sin(_time * 5.3) * (1.0 if hangs else 0.2)
	# Feeding hard, it trembles with it.
	_shift.x += hunger * 1.5 * sin(_time * 41.0)
	var kick := 0.0
	if thrown:
		swing = 0.9 * sin(_time * 19.0)
		dangle = 1.2 + 0.8 * sin(_time * 23.0)
		loll = 0.35 * sin(_time * 17.0)
		kick = -0.5 + 0.4 * sin(_time * 21.0)

	# Behind the body: the far arm, and the far leg laid out in front.
	_part(ARM_FAR, SHOULDER.rotated(lean), lean - dangle, Vector2(-3, -1), grown)
	_part(LEG_FLAT, Vector2(1, -4), kick, Vector2(-1, -5), grown)
	# The body leans back over the hips; the near leg hangs in front of it.
	_part(BODY, Vector2.ZERO, lean, Vector2(-10.5, -19.5), grown)
	_part(LEG_LOOSE, HIP, swing, Vector2(-5, -1), grown)
	# The near arm hangs straight down from the shoulder.
	_part(ARM, Vector2(-7, -15).rotated(lean), sway + (dangle - 0.5 if thrown else 0.0), Vector2(-3, -1), grown)
	var neck := NECK.rotated(lean)
	_part(HEAD, neck, lean + loll, Vector2(-8.25, -13.5), grown)
	# The pins that keep it working: through the crown, the chest and the leg.
	_part(PIN, neck, lean + loll, Vector2(2, -21), grown)
	_part(PIN, Vector2.ZERO, lean, Vector2(3, -19), grown)
	_part(PIN, Vector2(1, -4), kick, Vector2(13, -12), grown)
	draw_set_transform(Vector2.ZERO)
	_draw_swirl(true)


## What it feeds on. A dark haze hangs behind it; motes wind in round its
## chest, wide and slow at first and tight and fast at the end, each with a
## tail, the near half of every turn in front of the doll (`front`) and the
## far half behind it; and a line of them comes over from `drain`, bending
## as it goes.
func _draw_swirl(front: bool) -> void:
	# Asleep there is no magic in it at all.
	var magic := level * awake
	if magic <= 0.0:
		return
	if not front:
		var pulse := 1.0 + (0.08 + 0.1 * hunger) * sin(_time * (1.9 + 6.0 * hunger))
		for step: int in 4:
			var reach := (46.0 + 4.0 * hunger - step * 9.0) * pulse
			# Two bars crossed, each step smaller: round enough, in blocks.
			for arms: Vector2 in [Vector2(reach, reach * 0.5), Vector2(reach * 0.62, reach * 0.8)]:
				draw_rect(Rect2((heart() - arms).round(), (arms * 2.0).round()), Color(HEX_DARK, magic * (0.075 + 0.03 * hunger)))
	for i: int in SWIRL:
		var life := fposmod(_suck + float(i) / SWIRL, 1.0)
		var angle := i * 2.4 + life * life * 10.0 + _suck * 1.4
		if (sin(angle) >= 0.0) != front:
			continue
		var side := (6.0 if life < 0.35 else (4.0 if life < 0.7 else 3.0)) + roundf(2.0 * hunger)
		var ink := HEX.lerp(HEX_LIGHT, life)
		var glow := magic * minf(sin(life * PI) * 1.6, 1.0)
		for tail: int in 4:
			var turn := angle - tail * (0.2 + 0.15 * hunger)
			var reach := lerpf(46.0 + 20.0 * hunger, 5.0, pow(life, 0.75)) + tail * 1.5
			var at := heart() + Vector2(cos(turn) * reach, sin(turn) * reach * 0.66)
			_mote(at, maxf(side - tail, 2.0), Color(ink if tail == 0 else HEX, glow * (1.0 - tail * 0.24)))
	if not front or drain == Vector2.INF:
		return
	var across := heart() - drain
	var bow := across.orthogonal().normalized() * across.length() * 0.28
	# Hungry, the stream thickens and rushes in.
	var stream := STREAM + int(16.0 * hunger)
	for i: int in stream:
		var life := fposmod(_time * (0.6 + 1.8 * hunger) + float(i) / stream, 1.0)
		var bend := drain.lerp(heart(), 0.5) + bow * (1.0 - 0.6 * hunger) * sin(_time * 0.8 + i)
		var at := drain.lerp(bend, life).lerp(bend.lerp(heart(), life), life)
		var glow := magic * minf(sin(life * PI) * 1.6, 1.0)
		_mote(at, (5.0 if i % 2 == 0 else 3.0) + roundf(2.0 * hunger), Color(HEX_LIGHT, glow))
		_mote(at, (9.0 if i % 2 == 0 else 7.0) + roundf(4.0 * hunger), Color(HEX, glow * (0.3 + 0.3 * hunger)))


func _mote(at: Vector2, side: float, ink: Color) -> void:
	draw_rect(Rect2((at - Vector2(side, side) / 2.0).round(), Vector2(side, side)), ink)


## One piece of it: `rows` turned by `angle` about `joint` (a point counted
## from where the doll sits), with its top left corner at `corner` from that
## joint.
func _part(rows: Array, joint: Vector2, angle: float, corner: Vector2, grown: float) -> void:
	joint = joint.rotated(_tilt) + _shift
	draw_set_transform(Vector2(joint.x * facing, joint.y) * grown * GROWN, (angle + _tilt) * facing, Vector2(facing, 1.0) * grown * GROWN)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if INK.has(row[x]):
				draw_rect(Rect2(corner + Vector2(x, y) * CELL, Vector2(CELL, CELL)), Color(_ink(row[x]), level))


## The colour of `key`, gone dull while the doll sleeps: greyer and darker,
## the red of the thread and the pins most of all.
func _ink(key: String) -> Color:
	var color: Color = INK[key]
	var asleep := 1.0 - awake
	if asleep <= 0.0:
		return color
	var grey := Color.from_hsv(0.08, 0.18, color.get_luminance() * 0.7)
	var dulled := 0.75 if "rhHW".contains(key) else 0.5
	return color.lerp(grey, dulled * asleep).darkened(0.2 * asleep)
