class_name PlayFx
extends Control
## The signature effect of every ability and item: what the table shows and
## plays the moment a play takes effect, before its consequences (coins,
## Morale, cards) are animated by their own events.
##
## An effect is a method named after the id of the ability or item, with the
## dot turned into an underscore: `_fx_assassin_blood_count(play)`,
## `_fx_potion(play)`. To give a new play an effect, add its method here and
## its sound to tools/gen_sfx.py. How long it lasts follows what is at stake:
## a potion is a blink, a hex takes its time.
##
## Everything is drawn here in chunky pixels (bits, rings, lines) on top of
## the table, which lends its anchors, sounds and clock.

const PIXEL := 4.0
const BLOOD := Color("b3201a")
const SMOKE := Color("4a4458")
const STEEL := Color("c9d2e0")
const SPIRIT := Color("7fe0d8")
## The potion going down: how many steps, over how long, and what is left
## where the liquid was.
const DRAIN_FRAMES := 12
const DRAIN_TIME := 0.6
const EMPTY_GLASS := Color(0.78, 0.9, 0.96, 0.16)

## The match screen (table.gd): untyped, it has no class name.
var table: Variant
## Who aimed the last targeted play, for effects that bounce back.
var last_attacker: PlayerState

var _bits: Array = []
var _rings: Array = []
var _lines: Array = []
var _drain_frames: Dictionary = {}  # texture path -> Array of Texture2D


func _init(match_table: Variant) -> void:
	table = match_table
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func has_effect(play: Play) -> bool:
	return has_method(_method(play.source.id))


## Plays the effect of `play`, if it has one, and waits for it.
func play_effect(play: Play) -> void:
	var method := _method(play.source.id)
	if has_method(method):
		await call(method, play)


## A passive item giving itself up to protect `holder`.
func item_broken(holder: PlayerState, def: ItemDef) -> void:
	var here: Vector2 = table._anchor(holder)
	if def.id == &"shield":
		burst(here, STEEL, 16, 240.0, 0.4)
		burst(here, UI.GOLD, 8, 300.0, 0.3)
		ring(here, UI.BLUE, 20.0, 90.0, 0.3, 5.0)
		table._shake_screen(7.0)
	elif def.id == &"mirror":
		flash(Color(0.8, 0.95, 1.0, 0.3), 0.25)
		burst(here, Color("bfe9f5"), 20, 260.0, 0.55)
		ring(here, Color.WHITE, 10.0, 110.0, 0.35, 3.0)
		if last_attacker != null and last_attacker != holder:
			line(here, table._anchor(last_attacker), Color("bfe9f5"), 6.0, 0.35, 0.15)


func _method(id: StringName) -> String:
	return "_fx_" + String(id).replace(".", "_")


# --- characters ---------------------------------------------------------------

func _fx_assassin_blood_count(play: Play) -> void:
	await _stab(play)


func _fx_assassin_streak_thirst(play: Play) -> void:
	await _stab(play)


## The blade comes out, then one clean cut across the target.
func _stab(play: Play) -> void:
	var there := _at(play.target)
	_snd("fx_blade")
	dim(0.45, 0.75)
	await _wait(0.2)
	line(there + Vector2(-80, -56), there + Vector2(80, 56), Color.WHITE, 7.0, 0.3, 0.06)
	await _wait(0.07)
	burst(there, BLOOD, 22, 260.0, 0.6, 520.0)
	flash(Color(0.6, 0.0, 0.0, 0.3), 0.3)
	table._shake_screen(9.0)
	await _wait(0.4)


## A tune that walks over to the mark and picks their pocket.
func _fx_bard_swindle(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	_snd("fx_lute")
	ring(here, UI.GOLD, 10.0, 60.0, 0.4)
	stream(here, there, UI.GOLD, 10, 0.55, 0.4)
	stream(here, there, UI.PURPLE.lightened(0.3), 6, 0.6, 0.45)
	await _wait(0.7)
	ring(there, UI.GOLD, 70.0, 16.0, 0.3)
	await _wait(0.25)


func _fx_bard_silver_tongue(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_lute_flourish")
	ring(here, UI.GOLD, 20.0, 100.0, 0.4, 5.0)
	rise(here, Color("f6e6a8"), 12, 70.0)
	await _wait(0.2)
	ring(here, Color.WHITE, 20.0, 120.0, 0.4, 3.0)
	await _wait(0.35)


func _fx_heir_fickle(play: Play) -> void:
	await _fireworks(play.actor, 2)


func _fx_heir_sold_out(play: Play) -> void:
	await _fireworks(play.actor, 3)


## Money, and the party that comes with it.
func _fireworks(who: PlayerState, shells: int) -> void:
	var here := _at(who)
	_snd("fx_cash")
	var colors: Array[Color] = [UI.GOLD, Color("e0503c"), Color("c08adf")]
	for i in shells:
		var sky := here + Vector2((i - (shells - 1) / 2.0) * 70.0, -60.0 - 14.0 * (i % 2))
		line(here, sky, colors[i].lightened(0.4), 3.0, 0.12, 0.1)
		await _wait(0.12)
		burst(sky, colors[i], 18, 190.0, 0.6, 160.0)
		ring(sky, colors[i].lightened(0.3), 6.0, 46.0, 0.3, 3.0)
	await _wait(0.4)


## Two knocks of the gavel, and the oath closes around the witness.
func _fx_judge_under_oath(play: Play) -> void:
	var there := _at(play.target)
	_snd("fx_gavel")
	for i in 2:
		ring(there, UI.GOLD, 110.0, 34.0, 0.24, 11.0)
		table._shake_screen(6.0)
		await _wait(0.24)
	ring(there, Color.WHITE, 34.0, 44.0, 0.4, 3.0)
	burst(there, UI.GOLD, 10, 120.0, 0.4)
	await _wait(0.4)


func _fx_judge_contempt(play: Play) -> void:
	var doubter: PlayerState = play.event.data.get("doubter") if play.event != null else null
	var there := _at(doubter if doubter != null else play.actor)
	_snd("fx_gavel")
	for i in 2:
		ring(there, UI.RED, 100.0, 30.0, 0.24, 11.0)
		flash(Color(0.6, 0.1, 0.05, 0.16), 0.2)
		table._shake_screen(7.0)
		await _wait(0.24)
	await _wait(0.25)


## A puff of smoke, and something that was not there a second ago.
func _fx_magician_hat_trick(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_poof")
	rise(here, UI.PURPLE.lightened(0.4), 8, 40.0)
	await _wait(0.3)
	burst(here, UI.PURPLE, 26, 130.0, 0.7, -40.0, 11.0)
	burst(here, SMOKE.lightened(0.3), 14, 90.0, 0.8, -60.0, 12.0)
	ring(here, Color.WHITE, 8.0, 80.0, 0.3, 3.0)
	await _wait(0.25)
	rise(here, UI.GOLD, 12, 80.0)
	await _wait(0.3)


func _fx_magician_counterfeit(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_shimmer")
	ring(here + Vector2(-16, 0), UI.BLUE, 60.0, 14.0, 0.35, 3.0)
	await _wait(0.16)
	ring(here + Vector2(16, 0), UI.PURPLE.lightened(0.2), 60.0, 14.0, 0.35, 3.0)
	await _wait(0.3)
	rise(here, UI.BLUE.lightened(0.4), 12, 60.0)
	await _wait(0.2)


func _fx_mercenary_bounty(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_cash")
	burst(here, UI.GOLD, 16, 200.0, 0.5, 420.0)
	ring(here, UI.GOLD, 10.0, 70.0, 0.3)
	await _wait(0.45)


## A burst that does not stop at the first body.
func _fx_mercenary_collateral(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	_snd("fx_burst_fire")
	for i in 3:
		var spread := Vector2(randf_range(-22, 22), randf_range(-16, 16))
		line(here, there + spread, Color("ffe9a0"), 4.0, 0.1, 0.04)
		burst(here, Color("ffd060"), 4, 150.0, 0.15)
		burst(there + spread, BLOOD if i == 2 else STEEL, 7, 190.0, 0.35, 400.0)
		flash(Color(1.0, 0.95, 0.8, 0.14), 0.07)
		table._shake_screen(5.0)
		await _wait(0.09)
	await _wait(0.35)


## The door of the vault swings open on everything nobody caught.
func _fx_mythomaniac_cash_out(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_vault")
	ring(here, STEEL, 54.0, 54.0, 0.5, 12.0)
	ring(here, STEEL.darkened(0.3), 34.0, 34.0, 0.5, 4.0)
	await _wait(0.5)
	ring(here, UI.GOLD, 30.0, 130.0, 0.4, 5.0)
	for i in 3:
		burst(here, UI.GOLD, 12, 240.0, 0.7, 520.0)
		await _wait(0.1)
	await _wait(0.25)


## A lens finds its subject; the shutter does the rest.
func _fx_spy_sneak_peek(play: Play) -> void:
	var there := _at(play.target)
	ring(there, UI.BLUE, 120.0, 30.0, 0.3, 3.0)
	line(there + Vector2(-46, 0), there + Vector2(46, 0), UI.BLUE, 3.0, 0.35)
	line(there + Vector2(0, -46), there + Vector2(0, 46), UI.BLUE, 3.0, 0.35)
	await _wait(0.3)
	_snd("fx_shutter")
	flash(Color(1.0, 1.0, 1.0, 0.3), 0.18)
	await _wait(0.25)


func _fx_spy_low_profile(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_hush")
	burst(here, SMOKE, 16, 80.0, 0.6, -30.0, 12.0)
	ring(here, SMOKE.lightened(0.2), 60.0, 10.0, 0.35, 3.0)
	await _wait(0.4)


## Whatever was in the tin cup, instead of his pride.
func _fx_vagabond_street_bargain(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_tin")
	ring(here, UI.GREEN, 20.0, 90.0, 0.35, 5.0)
	burst(here, Color("b98a3c"), 12, 180.0, 0.5, 520.0)
	await _wait(0.5)


func _fx_vagabond_on_the_cuff(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_scribble")
	for i in 4:
		var y := -14.0 + 9.0 * i
		line(here + Vector2(-30, y), here + Vector2(30 - 12 * (i % 2), y), UI.CREAM, 3.0, 0.45, 0.07)
		await _wait(0.08)
	await _wait(0.1)
	ring(here, UI.RED, 40.0, 26.0, 0.25, 5.0)
	await _wait(0.2)


## The needle goes in slowly. Nobody at the table likes how long it takes.
func _fx_voodooist_hex(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	_snd("fx_hex")
	dim(0.55, 1.25)
	rise(here, UI.PURPLE, 10, 50.0)
	line(here, there, UI.PURPLE, 4.0, 0.75, 0.55)
	await _wait(0.6)
	burst(there, UI.PURPLE, 20, 170.0, 0.6, -60.0)
	burst(there, Color("1a0f1e"), 10, 110.0, 0.7, -30.0, 11.0)
	ring(there, UI.PURPLE.lightened(0.3), 90.0, 12.0, 0.35, 5.0)
	flash(Color(0.4, 0.1, 0.6, 0.25), 0.35)
	table._shake_screen(6.0)
	await _wait(0.55)


# --- items --------------------------------------------------------------------

## The flask is uncorked and drunk down, gulp by gulp; then it takes effect.
func _fx_potion(play: Play) -> void:
	var here := _at(play.actor)
	_snd("item_potion")
	var frames := _drained(play.source.texture_path)
	if not frames.is_empty():
		var speed: float = table._speed
		var flask: TextureRect = table._sprite(frames[0], here + Vector2(0, -34), Vector2(84, 88))
		flask.scale = Vector2.ONE * 0.4
		flask.modulate.a = 0.0
		var lift := flask.create_tween().set_parallel()
		lift.tween_property(flask, "modulate:a", 1.0, 0.1 / speed)
		lift.tween_property(flask, "scale", Vector2.ONE, 0.18 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Tipped back to drink.
		lift.tween_property(flask, "rotation", 0.5, 0.3 / speed).set_delay(0.1 / speed)
		await _wait(0.15)
		for frame: Texture2D in frames:
			if not is_instance_valid(flask):
				return
			flask.texture = frame
			await _wait(DRAIN_TIME / frames.size())
		if not is_instance_valid(flask):
			return
		var away := flask.create_tween()
		away.tween_property(flask, "modulate:a", 0.0, 0.3 / speed)
		away.tween_callback(flask.queue_free)
	rise(here, UI.GREEN.lightened(0.2), 14, 60.0)
	await _wait(0.3)
	ring(here, UI.GREEN, 14.0, 80.0, 0.35, 4.0)
	await _wait(0.25)


## A pistol comes up, finds its target and fires once: no ceremony.
func _fx_death(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	var aim := (there - here).normalized()
	# The art points its barrel to the left; flipped, the grip stays down.
	var gun: TextureRect = table._sprite(UI.tex(play.source.texture_path), here + aim * 80.0, Vector2(92, 96))
	gun.flip_v = aim.x > 0.0
	var aimed := aim.angle() - PI
	# Positive rotation is clockwise: the muzzle must climb, whichever way it points.
	var kick := -0.45 if aim.x > 0.0 else 0.45
	gun.rotation = aimed + kick * 1.6
	gun.scale = Vector2.ONE * 0.4
	gun.modulate.a = 0.0
	var speed: float = table._speed
	var draw := gun.create_tween().set_parallel()
	draw.tween_property(gun, "modulate:a", 1.0, 0.1 / speed)
	draw.tween_property(gun, "scale", Vector2.ONE, 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	draw.tween_property(gun, "rotation", aimed, 0.22 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_snd("item_roulette_tick")
	await _wait(0.5)
	if not is_instance_valid(gun):
		return

	_snd("item_death")
	var rest := gun.position
	var muzzle := here + aim * 126.0
	burst(muzzle, Color("ffd060"), 12, 240.0, 0.18, 0.0)
	ring(muzzle, Color.WHITE, 6.0, 50.0, 0.15, 5.0)
	line(muzzle, there, Color("ffe9a0"), 5.0, 0.14, 0.04)
	flash(Color(1.0, 0.95, 0.8, 0.3), 0.12)
	var recoil := gun.create_tween()
	recoil.tween_property(gun, "position", rest - aim * 22.0, 0.04 / speed)
	recoil.parallel().tween_property(gun, "rotation", aimed + kick, 0.04 / speed)
	recoil.tween_property(gun, "position", rest, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(gun, "rotation", aimed, 0.25 / speed)
	await _wait(0.05)
	burst(there, BLOOD, 22, 260.0, 0.55, 520.0)
	table._shake_screen(12.0)
	await _wait(0.5)
	if not is_instance_valid(gun):
		return
	var leave := gun.create_tween()
	leave.tween_property(gun, "modulate:a", 0.0, 0.2 / speed)
	leave.tween_callback(gun.queue_free)


func _fx_cloak(play: Play) -> void:
	var here := _at(play.actor)
	_snd("item_cloak")
	ring(here, SMOKE.lightened(0.3), 100.0, 16.0, 0.4, 5.0)
	burst(here, SMOKE.lightened(0.15), 20, 90.0, 0.7, -30.0, 12.0)
	await _wait(0.5)


## One muffled shot, and whoever was talking stops.
func _fx_silencer(play: Play) -> void:
	var here := _at(play.actor)
	var incoming: Variant = play.event.data.get("play") if play.event != null else null
	_snd("item_silencer")
	burst(here, Color("ffd060"), 5, 130.0, 0.15)
	if incoming != null and incoming.actor != play.actor:
		var there := _at(incoming.actor)
		line(here, there, STEEL, 3.0, 0.2, 0.05)
		await _wait(0.06)
		burst(there, SMOKE.lightened(0.3), 10, 110.0, 0.4, -20.0, 9.0)
	await _wait(0.3)


## Two souls change places over the table.
func _fx_soul_swap(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	_snd("item_soul_swap")
	dim(0.4, 1.0)
	ring(here, SPIRIT, 60.0, 12.0, 0.35, 3.0)
	ring(there, UI.PURPLE.lightened(0.3), 60.0, 12.0, 0.35, 3.0)
	await _wait(0.2)
	stream(here, there, SPIRIT, 12, 0.6, 0.4)
	stream(there, here, UI.PURPLE.lightened(0.3), 12, 0.6, 0.4)
	await _wait(0.65)
	ring(here, UI.PURPLE.lightened(0.3), 12.0, 70.0, 0.3, 3.0)
	ring(there, SPIRIT, 12.0, 70.0, 0.3, 3.0)
	await _wait(0.2)


## The art of a flask at `path` with its red liquid going down, full first and
## empty last. Empty if the art cannot be read.
func _drained(path: String) -> Array:
	if _drain_frames.has(path):
		return _drain_frames[path]
	var frames: Array = []
	_drain_frames[path] = frames
	var texture := UI.tex(path)
	var image := texture.get_image() if texture != null else null
	if image == null:
		return frames
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var liquid: Array[Vector2i] = []
	var top := image.get_height()
	var bottom := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.35 and c.r > c.g * 1.8 and c.r > c.b * 1.8:
				liquid.append(Vector2i(x, y))
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if liquid.is_empty():
		return frames
	for step in DRAIN_FRAMES + 1:
		var level := top + (bottom - top + 1) * step / float(DRAIN_FRAMES)
		var frame := image.duplicate() as Image
		for at: Vector2i in liquid:
			if at.y < level:
				frame.set_pixel(at.x, at.y, EMPTY_GLASS)
		frames.append(ImageTexture.create_from_image(frame))
	return frames


# --- the brushes --------------------------------------------------------------

## Square sparks thrown out from a point. Negative `gravity` makes them float.
func burst(at: Vector2, color: Color, count := 14, speed := 180.0, life := 0.5, gravity := 300.0, bit_size := 8.0) -> void:
	for i in count:
		var direction := Vector2.from_angle(randf() * TAU)
		_bits.append({
			"p": at, "v": direction * speed * randf_range(0.35, 1.0), "g": gravity,
			"c": color.lightened(randf_range(-0.15, 0.2)), "s": bit_size,
			"t": 0.0, "life": life * randf_range(0.6, 1.0),
		})
	_wake()


## Bits that drift up from around a point: bubbles, sparkles, embers.
func rise(at: Vector2, color: Color, count := 10, spread := 50.0) -> void:
	for i in count:
		_bits.append({
			"p": at + Vector2(randf_range(-spread, spread), randf_range(-10, 30)),
			"v": Vector2(randf_range(-12, 12), -randf_range(40, 110)), "g": -40.0,
			"c": color.lightened(randf_range(-0.1, 0.25)), "s": 8.0,
			"t": -randf_range(0.0, 0.25), "life": randf_range(0.5, 0.85),
		})
	_wake()


## Bits that travel from one point to another, one after the other.
func stream(from: Vector2, to: Vector2, color: Color, count := 10, time := 0.5, stagger := 0.3) -> void:
	var side := (to - from).orthogonal().normalized()
	for i in count:
		var sway := side * randf_range(-22, 22)
		_bits.append({
			"p": from + sway, "v": (to - from) / time, "g": 0.0,
			"c": color.lightened(randf_range(-0.1, 0.25)), "s": 9.0,
			"t": -stagger * i / count, "life": time,
		})
	_wake()


## A circle that grows or closes in.
func ring(at: Vector2, color: Color, from_radius: float, to_radius: float, life := 0.35, width := 4.0) -> void:
	_rings.append({"at": at, "c": color, "a": from_radius, "b": to_radius, "w": width, "t": 0.0, "life": life})
	_wake()


## A stroke from `from` to `to`, drawn over `draw_time` and then fading.
func line(from: Vector2, to: Vector2, color: Color, width := 4.0, life := 0.3, draw_time := 0.0) -> void:
	_lines.append({"a": from, "b": to, "c": color, "w": width, "t": 0.0, "life": life + draw_time, "draw": draw_time})
	_wake()


## The whole screen blinks `color`.
func flash(color: Color, time := 0.25) -> void:
	var rect := _veil(color)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, time / table._speed)
	tween.tween_callback(rect.queue_free)


## The table goes dark for `time` seconds, under the effect.
func dim(alpha: float, time: float) -> void:
	var rect := _veil(Color(0, 0, 0, 0))
	move_child(rect, 0)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", alpha, 0.15 / table._speed)
	tween.tween_interval(maxf(time - 0.4, 0.0) / table._speed)
	tween.tween_property(rect, "color:a", 0.0, 0.25 / table._speed)
	tween.tween_callback(rect.queue_free)


func _veil(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	add_child(rect)
	return rect


func _at(p: PlayerState) -> Vector2:
	return table._anchor(p)


func _snd(sound: String) -> void:
	table._play_sfx(sound)


func _wait(seconds: float) -> void:
	await table._wait(seconds)


func _wake() -> void:
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var dt: float = delta * table._speed
	for bit in _bits:
		bit.t += dt
		if bit.t > 0.0:
			bit.v.y += bit.g * dt
			bit.p += bit.v * dt
	for shape in _rings:
		shape.t += dt
	for shape in _lines:
		shape.t += dt
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)
	_rings = _rings.filter(func(shape: Dictionary) -> bool: return shape.t < shape.life)
	_lines = _lines.filter(func(shape: Dictionary) -> bool: return shape.t < shape.life)
	if _bits.is_empty() and _rings.is_empty() and _lines.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for shape in _lines:
		var head := 1.0 if shape.draw <= 0.0 else clampf(shape.t / shape.draw, 0.0, 1.0)
		var fade := clampf((shape.life - shape.t) / maxf(shape.life - shape.draw, 0.01), 0.0, 1.0)
		var tip: Vector2 = shape.a.lerp(shape.b, head)
		draw_line(shape.a, tip, Color(0, 0, 0, 0.5 * fade), shape.w + 4.0)
		draw_line(shape.a, tip, Color(shape.c, shape.c.a * fade), shape.w)
	for shape in _rings:
		var k: float = shape.t / shape.life
		var radius: float = lerpf(shape.a, shape.b, 1.0 - pow(1.0 - k, 2.0))
		draw_arc(shape.at, radius, 0.0, TAU, 28, Color(shape.c, shape.c.a * (1.0 - k * k)), shape.w)
	for bit in _bits:
		if bit.t <= 0.0:
			continue
		var k: float = bit.t / bit.life
		var corner: Vector2 = (bit.p / PIXEL).floor() * PIXEL
		var side: float = maxf(PIXEL, bit.s * (1.0 - 0.5 * k))
		draw_rect(Rect2(corner, Vector2(side, side)), Color(bit.c, 1.0 - k * k * k))
