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
const PORCELAIN := Color("f2efe6")
const EARTH := Color("6b4a2a")
const EMBER := Color("ff7a2a")
const CHIP_RED := Color("c8402f")
const CHIP_GREEN := Color("3f8a5a")
## The middle of the table, where a bet is pushed to.
const POT := Vector2(576, 322)
const COIN_ART := "res://assets/ui/coin.png"
## The potion going down: how many steps, over how long, and what is left
## where the liquid was.
const GAVEL_RAISED := 0.95  # radians the gavel is lifted before a knock
const SCALES_Y := 266.0  # where the pivot of the scales of the court stands
## A firework rocket: how long it climbs, and how long what it leaves behind
## takes to go out.
const ROCKET_RISE := 0.5
const ROCKET_TAIL := 0.3
const BOLT := Color("ffd84a")
const DRAIN_FRAMES := 12
const DRAIN_TIME := 0.6
const EMPTY_GLASS := Color(0.78, 0.9, 0.96, 0.16)
## How long an item takes to be printed out of the hat.
const PRINT_TIME := 0.85

## The match screen (table.gd): untyped, it has no class name.
var table: Variant
## Who aimed the last targeted play, for effects that bounce back.
var last_attacker: PlayerState

var _bits: Array = []
var _rings: Array = []
var _lines: Array = []
var _rockets: Array = []
var _bolts: Array = []
var _drain_frames: Dictionary = {}  # texture path -> Array of Texture2D
## The lasso of a Confiscate, turning overhead until it is thrown.
var _lasso: RopeFx
var _lasso_spin: Tween
## The hat of a Hat Trick, set down and waiting for what comes out of it.
var _hat: HatFx
var _hat_owner: PlayerState
## The wand of a Counterfeit, out and pointing until the copy is made.
var _wand: WandFx
var _wand_owner: PlayerState


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


func _fx_heir_sold_out(play: Play) -> void:
	await _fireworks(play.actor, 2)


func _fx_heir_passive_income(play: Play) -> void:
	await _fireworks(play.actor, 3)


## Money, and the party that comes with it: rockets leave one after the other,
## each from its own spot, and burst where they get to.
func _fireworks(who: PlayerState, shells: int) -> void:
	var here := _at(who)
	var colors: Array[Color] = [UI.GOLD, Color("e0503c"), Color("c08adf")]
	var pads: Array[Vector2] = []
	var skies: Array[Vector2] = []
	# What happens when: [seconds, shell, whether it is the burst].
	var cues: Array = []
	var leaves := 0.0
	for i in shells:
		var column := i - (shells - 1) / 2.0
		pads.append(here + Vector2(column * 38.0 + randf_range(-14.0, 14.0), randf_range(34.0, 56.0)))
		var sky := here + Vector2(column * 70.0 + randf_range(-16.0, 16.0), -72.0 - 14.0 * (i % 2) - randf_range(0.0, 14.0))
		# Under the top of the screen, for the players sitting up there.
		skies.append(Vector2(sky.x, maxf(sky.y, 26.0)))
		cues.append([leaves, i, false])
		cues.append([leaves + ROCKET_RISE, i, true])
		leaves += randf_range(0.12, 0.24)
	cues.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	_snd("fx_firework_launch")
	var now := 0.0
	for cue: Array in cues:
		if cue[0] > now:
			await _wait(cue[0] - now)
			now = cue[0]
		var i: int = cue[1]
		if not cue[2]:
			rocket(pads[i], skies[i], colors[i], ROCKET_RISE)
			continue
		# One sound each: they ring on over one another.
		_snd("fx_firework_%d" % (i + 1))
		burst(skies[i], colors[i], 18, 190.0, 0.6, 160.0)
		ring(skies[i], colors[i].lightened(0.3), 6.0, 46.0, 0.3, 3.0)
		flash(Color(colors[i], 0.07), 0.12)
		table._shake_screen(3.0)
	await _wait(0.35)


## Two knocks of the gavel on the witness, and the oath closes around them.
func _fx_judge_under_oath(play: Play) -> void:
	var there := _at(play.target)
	await _gavel(play.target, UI.GOLD)
	ring(there, UI.GOLD, 120.0, 40.0, 0.35, 6.0)
	ring(there, Color.WHITE, 40.0, 52.0, 0.45, 3.0)
	await _wait(0.4)


## The scales of the court sink on the side of whoever doubted and are then
## thrown over to the Judge's, brass on brass. The fine follows.
func _fx_judge_contempt(play: Play) -> void:
	var doubter: PlayerState = play.event.data.get("doubter") if play.event != null else null
	var here := _at(play.actor)
	var there := _at(doubter) if doubter != null else here
	var box: Control = table._node_of(doubter)
	var speed: float = table._speed
	# Each of the two gets the pan on their own side of the table.
	var doubt := ScaleFx.LEAN * (-1.0 if there.x < here.x else 1.0)
	var scales := ScaleFx.new()
	scales.position = Vector2(clampf((here.x + there.x) / 2.0, 340.0, 812.0), SCALES_Y)
	# It grows from its foot, as something set down on the table.
	scales.pivot_offset = Vector2(0, ScaleFx.POST * ScaleFx.PIXEL)
	scales.scale = Vector2.ONE * 0.7
	scales.modulate.a = 0.0
	add_child(scales)
	_snd("fx_scales_chain")
	dim(0.45, 1.85)
	var enter := scales.create_tween().set_parallel()
	enter.tween_property(scales, "modulate:a", 1.0, 0.12 / speed)
	enter.tween_property(scales, "scale", Vector2.ONE, 0.22 / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The doubt is laid on its pan first, and weighs, in no hurry.
	enter.tween_property(scales, "tilt", doubt, 0.4 / speed).set_delay(0.25 / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ring(there, UI.RED, 70.0, 24.0, 0.4, 4.0)
	stream(there, scales.position + scales.pan(doubt), UI.RED, 5, 0.3, 0.12)
	await _wait(0.55)
	if not is_instance_valid(scales):
		return

	# Then the truth on the other one, and the ruling: all of it at once.
	stream(here, scales.position + scales.pan(-doubt), UI.GOLD, 6, 0.26, 0.1)
	await _wait(0.3)
	if not is_instance_valid(scales):
		return
	scales.create_tween().tween_property(scales, "tilt", -doubt, 0.14 / speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _wait(0.14)
	if not is_instance_valid(scales):
		return
	_snd("fx_scales")
	scales.jolt()
	burst(scales.position + scales.pan(-doubt), ScaleFx.LIGHT, 12, 220.0, 0.35, 500.0, 6.0)
	burst(scales.position, UI.GOLD, 6, 160.0, 0.3, 300.0, 6.0)
	ring(scales.position, UI.GOLD, 24.0, 170.0, 0.45, 6.0)
	ring(there, UI.RED, 16.0, 96.0, 0.28, 6.0)
	flash(Color(1.0, 0.85, 0.45, 0.14), 0.2)
	if box != null:
		UI.shake(box, 9.0, 0.2)
	table._shake_screen(8.0)
	# The beam bounces off its stop and stays down.
	var settle := scales.create_tween()
	settle.tween_property(scales, "tilt", -doubt * 0.62, 0.1 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(scales, "tilt", -doubt, 0.11 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	settle.tween_property(scales, "tilt", -doubt * 0.9, 0.06 / speed)
	settle.tween_property(scales, "tilt", -doubt, 0.07 / speed)
	await _wait(0.65)
	if not is_instance_valid(scales):
		return
	var leave := scales.create_tween()
	leave.tween_property(scales, "modulate:a", 0.0, 0.2 / speed)
	leave.tween_callback(scales.queue_free)


## The gavel comes down twice on the box of `who`, unhurried.
func _gavel(who: PlayerState, color: Color) -> void:
	var there := _at(who)
	var box: Control = table._node_of(who)
	var speed: float = table._speed
	var gavel := GavelFx.new()
	gavel.position = GavelFx.origin_for(there)
	gavel.rotation = GAVEL_RAISED
	gavel.modulate.a = 0.0
	add_child(gavel)
	gavel.create_tween().tween_property(gavel, "modulate:a", 1.0, 0.12 / speed)
	await _wait(0.3)
	for knock in 2:
		if not is_instance_valid(gavel):
			return
		gavel.create_tween().tween_property(gavel, "rotation", 0.0, 0.07 / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _wait(0.07)
		_snd("fx_gavel")
		burst(there, Color("c9a26a"), 10, 200.0, 0.3, 500.0, 6.0)
		ring(there, color, 16.0, 96.0, 0.28, 6.0)
		if box != null:
			UI.shake(box, 9.0, 0.2)
		table._shake_screen(6.0)
		await _wait(0.16)
		if not is_instance_valid(gavel):
			return
		if knock == 0:
			# Back up, in no hurry, for the second one.
			gavel.create_tween().tween_property(gavel, "rotation", GAVEL_RAISED, 0.3 / speed) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await _wait(0.42)
	await _wait(0.2)
	if not is_instance_valid(gavel):
		return
	var leave := gavel.create_tween()
	leave.tween_property(gavel, "modulate:a", 0.0, 0.2 / speed)
	leave.tween_callback(gavel.queue_free)


## The hat is set down mouth up and something stirs in it. What comes out is
## only known once the item is gained (item_conjured); if nothing does, the
## hat is put away when the play is over.
func _fx_magician_hat_trick(play: Play) -> void:
	drop_hat()
	var here := _at(play.actor)
	var speed: float = table._speed
	var hat := HatFx.new()
	# Room over it for the item, and under it for the hat itself.
	hat.position = Vector2(here.x, clampf(here.y + 16.0, HatFx.ITEM.y + HatFx.LIFT + 26.0, size.y - 50.0))
	hat.scale = Vector2(0.3, 0.3)
	hat.modulate.a = 0.0
	add_child(hat)
	_hat = hat
	_hat_owner = play.actor
	_snd("fx_poof")
	var land := hat.create_tween().set_parallel()
	land.tween_property(hat, "modulate:a", 1.0, 0.1 / speed)
	land.tween_property(hat, "scale", Vector2.ONE, 0.22 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.3)
	if not is_instance_valid(hat):
		return
	burst(hat.position, SMOKE.lightened(0.3), 12, 90.0, 0.6, -60.0, 10.0)
	ring(hat.position, UI.PURPLE.lightened(0.3), 8.0, 60.0, 0.3, 3.0)
	hat.create_tween().tween_property(hat, "glow", 1.0, 0.25 / speed)
	await _wait(0.3)


## True while the hat of `who` is out with nothing pulled from it yet.
func conjuring(who: PlayerState) -> bool:
	return _hat != null and is_instance_valid(_hat) and _hat_owner == who


## An item printed into being over the hat, row by row from the bottom up,
## and then sent to `home`, its place in the inventory. `label` is what the
## table calls it once it is whole.
func item_conjured(texture: Texture2D, home: Vector2, label: String) -> void:
	var hat := _hat
	_hat = null
	_hat_owner = null
	if hat == null or not is_instance_valid(hat):
		return
	var speed: float = table._speed
	hat.set_item(texture)
	_snd("fx_conjure")
	hat.create_tween().tween_property(hat, "printed", 1.0, PRINT_TIME / speed)
	await _wait(PRINT_TIME)
	if not is_instance_valid(hat):
		return

	# The last row lands: it is a real thing now.
	var middle := hat.position + hat.item_middle()
	hat.set_item(null)
	var item: TextureRect = table._sprite(texture, middle, HatFx.ITEM)
	flash(Color(0.8, 0.65, 1.0, 0.12), 0.15)
	ring(middle, Color.WHITE, 12.0, 76.0, 0.3, 4.0)
	burst(middle, UI.GOLD, 14, 180.0, 0.45, 220.0)
	burst(middle, UI.PURPLE.lightened(0.35), 10, 120.0, 0.5, -40.0)
	UI.pop(item, 1.25, 0.18)
	table._float(label, middle + Vector2(0, -HatFx.ITEM.y / 2.0 - 10.0), UI.BLUE)
	var leave := hat.create_tween()
	leave.tween_property(hat, "glow", 0.0, 0.2 / speed)
	leave.tween_property(hat, "modulate:a", 0.0, 0.2 / speed)
	leave.tween_callback(hat.queue_free)
	await _wait(0.4)
	if not is_instance_valid(item):
		return

	# And into the pocket.
	var pocket := item.create_tween().set_parallel()
	pocket.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pocket.tween_property(item, "position", home - HatFx.ITEM / 2.0, 0.3 / speed)
	pocket.tween_property(item, "scale", Vector2.ONE * 0.5, 0.3 / speed)
	await _wait(0.3)
	_snd("item_get")
	rise(home, UI.PURPLE.lightened(0.4), 6, 16.0)
	if is_instance_valid(item):
		item.queue_free()


## Puts away a hat nothing came out of.
func drop_hat() -> void:
	if _hat != null and is_instance_valid(_hat):
		var leave := _hat.create_tween()
		leave.tween_property(_hat, "modulate:a", 0.0, 0.15 / table._speed)
		leave.tween_callback(_hat.queue_free)
	_hat = null
	_hat_owner = null


## Clears away what an effect left out waiting for something that never
## came: the play is over.
func put_away() -> void:
	drop_lasso()
	drop_hat()
	drop_wand()


## The wand slides out from behind the Magician's box, turns on the item
## being copied and lets a ray fly at it. It stays out until the copy is
## gained (item_copied) or the play is over.
func _fx_magician_counterfeit(play: Play) -> void:
	drop_wand()
	var speed: float = table._speed
	var here := _at(play.actor)
	var box: Control = table._node_of(play.actor)
	var wand := WandFx.new()
	# Out of whichever edge of the box faces the middle of the table.
	wand.way = Vector2.DOWN if here.y < POT.y else Vector2.UP
	wand.rest = here
	if box != null:
		var rect := box.get_global_rect()
		wand.rest = Vector2(clampf(here.x, rect.position.x + 20.0, rect.end.x - 20.0),
				rect.end.y if wand.way == Vector2.DOWN else rect.position.y)
	wand.rotation = wand.way.angle()
	wand.out = 0.0
	add_child(wand)
	_wand = wand
	_wand_owner = play.actor
	_snd("fx_shimmer")
	wand.create_tween().tween_property(wand, "out", 1.0, 0.3 / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise(wand.rest + wand.way * 20.0, BOLT, 5, 14.0)
	await _wait(0.34)
	var def: ItemDef = play.params.get("item")
	if def == null or not is_instance_valid(wand):
		return
	var original := _copied_from(play.actor, def)
	if not await _zap(wand, original):
		return
	ring(original, Color.WHITE, 40.0, 14.0, 0.3, 3.0)
	await _wait(0.4)


## Where the item `def` that `copier` is copying can be seen: in the hands of
## the player who has it (the shop is only a fallback, if it is gone by now).
func _copied_from(copier: PlayerState, def: ItemDef) -> Vector2:
	for p: PlayerState in table.engine.opponents(copier):
		for i: int in p.items.size():
			if p.items[i].def == def and not p.items[i].hidden:
				return table._item_spot(p, i)
	return table._shop_point(table.engine.shop.find(def), def)


## The wand turns on `at` and fires: a ray, and sparks where it lands. False
## if the wand is gone before it could.
func _zap(wand: WandFx, at: Vector2) -> bool:
	var speed: float = table._speed
	var turn := wrapf((at - wand.position).angle() - wand.rotation, -PI, PI)
	# A wand that a twirl left pointing there has nothing to line up.
	if absf(turn) > 0.03:
		var aim := wand.create_tween().set_parallel()
		aim.tween_property(wand, "rotation", wand.rotation + turn, 0.16 / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		aim.tween_property(wand, "charge", 1.0, 0.2 / speed)
		await _wait(0.24)
		if not is_instance_valid(wand):
			return false
	var tip := wand.tip()
	_snd("fx_zap")
	bolt(tip, at)
	burst(tip, Color.WHITE, 4, 90.0, 0.2, 0.0, 4.0)
	burst(at, BOLT, 12, 200.0, 0.45, 300.0, 6.0)
	burst(at, Color.WHITE, 6, 130.0, 0.35, 300.0, 4.0)
	ring(at, BOLT, 6.0, 36.0, 0.28, 3.0)
	for i in 5:
		burst(tip.lerp(at, randf_range(0.15, 0.9)), BOLT.lightened(0.3), 1, 70.0, 0.35, 160.0, 4.0)
	# The kick of it, back along the wand.
	var held := wand.position
	var kick := wand.create_tween()
	kick.tween_property(wand, "position", held - Vector2.from_angle(wand.rotation) * 7.0, 0.04 / speed)
	kick.tween_property(wand, "position", held, 0.14 / speed)
	wand.create_tween().tween_property(wand, "charge", 0.0, 0.3 / speed)
	return true


## A flourish before the trick: the wand spins a couple of times about its
## own middle, slow into it and slow out, its tip lighting up and shedding
## sparks as it goes round, and comes to rest pointing at `at`: the spin is
## the aiming. False if the wand is gone before it is done.
func _twirl(wand: WandFx, at: Vector2) -> bool:
	var speed: float = table._speed
	_snd("fx_shimmer")
	# Two full turns, and on round the same way to where it has to point.
	var onto := fposmod((at - wand.middle()).angle() - wand.rotation, TAU)
	var spin := wand.create_tween().set_parallel()
	spin.tween_method(wand.twirl, wand.rotation, wand.rotation + TAU * 2.0 + onto, 0.66 / speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(wand, "charge", 1.0, 0.66 / speed)
	for i in 6:
		await _wait(0.11)
		if not is_instance_valid(wand):
			return false
		burst(wand.tip(), BOLT if i % 2 == 0 else Color.WHITE, 2, 90.0, 0.3, 80.0, 4.0)
	ring(wand.middle(), BOLT, 34.0, 8.0, 0.2, 3.0)
	await _wait(0.06)
	return is_instance_valid(wand)


## True while the wand of `who` is out with nothing copied yet.
func copying(who: PlayerState) -> bool:
	return _wand != null and is_instance_valid(_wand) and _wand_owner == who


## The copy made: the wand turns on `home`, its place in the inventory, the
## same ray goes there and the item comes out of the sparks. `label` is what
## the table calls it; `item_size` is how big it is drawn in that inventory.
func item_copied(texture: Texture2D, home: Vector2, item_size: Vector2, label: String) -> void:
	var wand := _wand
	_wand = null
	_wand_owner = null
	if wand == null or not is_instance_valid(wand):
		return
	var speed: float = table._speed
	if not await _twirl(wand, home):
		return
	if not await _zap(wand, home):
		return
	var item: TextureRect = table._sprite(texture, home, item_size)
	item.scale = Vector2.ONE * 0.2
	item.create_tween().tween_property(item, "scale", Vector2.ONE, 0.24 / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash(Color(1.0, 0.95, 0.6, 0.1), 0.15)
	table._float(label, home + Vector2(0, -item_size.y / 2.0 - 12.0), UI.BLUE)
	await _wait(0.14)
	_snd("item_get")
	await _wait(0.3)
	_stow(wand)
	await _wait(0.2)
	# The inventory draws the real one from here on.
	if is_instance_valid(item):
		item.queue_free()


## Puts away a wand that had nothing more to do.
func drop_wand() -> void:
	if _wand != null and is_instance_valid(_wand):
		_stow(_wand)
	_wand = null
	_wand_owner = null


## The wand turns back the way it came out and slides in behind the box.
func _stow(wand: WandFx) -> void:
	var speed: float = table._speed
	var turn := wrapf(wand.way.angle() - wand.rotation, -PI, PI)
	var leave := wand.create_tween()
	leave.tween_property(wand, "rotation", wand.rotation + turn, 0.12 / speed)
	# A twirl may have left it off the spot it came out to.
	leave.parallel().tween_property(wand, "position", wand.rest + wand.way * WandFx.CLEAR, 0.12 / speed)
	leave.tween_property(wand, "out", 0.0, 0.2 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.tween_callback(wand.queue_free)


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


## Every paper in her pockets goes up in smoke; someone else walks out of it.
func _fx_impostor_cover_story(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_hush")
	burst(here, SMOKE.lightened(0.25), 18, 100.0, 0.6, -40.0, 11.0)
	ring(here, UI.CREAM, 80.0, 12.0, 0.35, 3.0)
	await _wait(0.4)


## The mask comes up. Whoever they said they were, that is who they are.
func _fx_impostor_perfect_disguise(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_mask")
	dim(0.5, 0.95)
	ring(here, PORCELAIN, 120.0, 26.0, 0.4, 4.0)
	await _wait(0.4)
	flash(Color(1.0, 1.0, 1.0, 0.22), 0.2)
	burst(here, PORCELAIN, 18, 150.0, 0.5, -30.0, 9.0)
	ring(here, UI.GOLD, 20.0, 96.0, 0.35, 4.0)
	await _wait(0.5)


## Chips pushed forward; the coin itself is flown by coin_flip.
func _fx_gambler_double_down(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_chips")
	burst(here, CHIP_RED, 6, 120.0, 0.35, 420.0)
	burst(here, CHIP_GREEN, 6, 120.0, 0.35, 420.0)
	await _wait(0.3)


## A stack of chips slid to the middle of the table.
func _fx_gambler_side_bet(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_chips")
	stream(here, POT, CHIP_RED, 5, 0.35, 0.2)
	stream(here, POT, CHIP_GREEN, 4, 0.4, 0.25)
	await _wait(0.45)
	ring(POT, UI.GOLD, 10.0, 46.0, 0.3, 4.0)
	await _wait(0.2)


## The shovel goes into the deck twice, and something comes up.
func _fx_gravedigger_exhume(_play: Play) -> void:
	var deck: Vector2 = table._bank()
	_snd("fx_dig")
	for i in 2:
		burst(deck + Vector2(0, 18), EARTH, 10, 170.0, 0.45, 520.0)
		table._shake_screen(4.0)
		await _wait(0.36)
	rise(deck, SPIRIT, 8, 26.0)
	ring(deck, SPIRIT, 8.0, 56.0, 0.4, 3.0)
	await _wait(0.3)


## A bell, a cross over the body, and the purse changes hands.
func _fx_gravedigger_last_rites(play: Play) -> void:
	var dead: PlayerState = play.event.data.get("player") if play.event != null else null
	var here := _at(play.actor)
	var there := _at(dead) if dead != null else here
	_snd("fx_bell")
	dim(0.5, 1.0)
	line(there + Vector2(0, -44), there + Vector2(0, 40), UI.CREAM, 6.0, 0.6, 0.15)
	line(there + Vector2(-24, -18), there + Vector2(24, -18), UI.CREAM, 6.0, 0.6, 0.15)
	await _wait(0.5)
	stream(there, here, UI.GOLD, 8, 0.4, 0.25)
	await _wait(0.45)


## A glass slid down the bar. Whatever was in it starts working at once.
func _fx_bartender_mickey_finn(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	_snd("fx_pour")
	await _wait(0.4)
	line(here, there, Color("cfe6ea"), 4.0, 0.25, 0.3)
	await _wait(0.32)
	rise(there, Color("9fd24a"), 14, 44.0)
	ring(there, Color("7f9a3c"), 90.0, 18.0, 0.45, 5.0)
	await _wait(0.5)


func _fx_bartender_liquid_courage(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_pour")
	rise(here, Color("d99a2e"), 12, 40.0)
	await _wait(0.3)
	ring(here, UI.GOLD, 14.0, 76.0, 0.3, 4.0)
	await _wait(0.3)


## The badge comes out spinning, catches the light, and then the whole room
## feels a hand in its pocket.
func _fx_sheriff_shakedown(play: Play) -> void:
	var here := _at(play.actor)
	var speed: float = table._speed
	var badge := BadgeFx.new()
	badge.position = here
	badge.scale = Vector2.ONE * 0.2
	badge.rotation = -TAU * 2.5
	badge.modulate.a = 0.0
	add_child(badge)
	_snd("fx_whistle")
	dim(0.45, 1.7)
	# Out of the pocket: a quick spin that winds down as it grows.
	var enter := badge.create_tween().set_parallel()
	enter.tween_property(badge, "modulate:a", 1.0, 0.1 / speed)
	enter.tween_property(badge, "scale", Vector2.ONE, 0.5 / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(badge, "rotation", 0.0, 0.58 / speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in 4:
		burst(here, UI.GOLD, 3, 120.0, 0.25, 0.0, 6.0)
		await _wait(0.14)
	await _wait(0.06)
	if not is_instance_valid(badge):
		return

	# Held still, it catches the light.
	_snd("fx_glint")
	badge.create_tween().tween_property(badge, "shine", 1.0, 0.45 / speed)
	rise(here, BadgeFx.LIGHT, 8, 34.0)
	await _wait(0.47)
	if not is_instance_valid(badge):
		return

	# The wave, and what it shakes out of everyone it reaches.
	var pulse := badge.create_tween()
	pulse.tween_property(badge, "scale", Vector2.ONE * 1.3, 0.07 / speed)
	pulse.tween_property(badge, "scale", Vector2.ONE, 0.22 / speed)
	_snd("fx_wave")
	ring(here, UI.GOLD, 30.0, 400.0, 0.6, 6.0)
	ring(here, BadgeFx.LIGHT, 20.0, 300.0, 0.5, 3.0)
	flash(Color(1.0, 0.9, 0.5, 0.14), 0.2)
	table._shake_screen(5.0)
	await _wait(0.22)
	for p: PlayerState in table.engine.opponents(play.actor):
		var there := _at(p)
		ring(there, UI.RED, 80.0, 18.0, 0.35, 4.0)
		burst(there, UI.GOLD, 6, 150.0, 0.35, 420.0)
		stream(there, here, UI.GOLD, 4, 0.35, 0.2)
		var box: Control = table._node_of(p)
		if box is SeatView:
			UI.shake(box, 6.0, 0.25)
	await _wait(0.5)
	if not is_instance_valid(badge):
		return
	var leave := badge.create_tween().set_parallel()
	leave.tween_property(badge, "modulate:a", 0.0, 0.2 / speed)
	leave.tween_property(badge, "scale", Vector2.ONE * 0.8, 0.2 / speed)
	leave.chain().tween_callback(badge.queue_free)


## The lasso comes off the saddle and goes round overhead. It keeps turning
## until there is something to throw it at (item_roped) or the play is over.
func _fx_sheriff_confiscate(play: Play) -> void:
	drop_lasso()
	var here := _at(play.actor)
	var speed: float = table._speed
	var rope := RopeFx.new()
	rope.hand = here
	rope.tip = here + Vector2(0, -56)
	rope.loop = 4.0
	rope.squash = 0.4
	rope.slack = 0.3
	rope.modulate.a = 0.0
	add_child(rope)
	_lasso = rope
	_snd("fx_lasso_spin")
	var grow := rope.create_tween().set_parallel()
	grow.tween_property(rope, "modulate:a", 1.0, 0.1 / speed)
	grow.tween_property(rope, "loop", 22.0, 0.2 / speed)
	_lasso_spin = rope.create_tween().set_loops()
	_lasso_spin.tween_method(rope.whirl.bind(here + Vector2(0, -56)), 0.0, TAU, 0.36 / speed)
	await _wait(0.75)


## Lets go of a lasso nobody threw: the play ended with nothing to rope.
func drop_lasso() -> void:
	if _lasso_spin != null:
		_lasso_spin.kill()
		_lasso_spin = null
	if _lasso != null and is_instance_valid(_lasso):
		var leave := _lasso.create_tween()
		leave.tween_property(_lasso, "modulate:a", 0.0, 0.15 / table._speed)
		leave.tween_callback(_lasso.queue_free)
	_lasso = null


## The lasso of `thief`, in hand and ready to be thrown: the one turning
## over their head if there is one, a new one otherwise.
func _lasso_in_hand(thief: PlayerState) -> RopeFx:
	var here := _at(thief)
	var rope := _lasso
	if _lasso_spin != null:
		_lasso_spin.kill()
		_lasso_spin = null
	_lasso = null
	if rope == null or not is_instance_valid(rope):
		rope = RopeFx.new()
		rope.hand = here
		rope.tip = here + Vector2(0, -56)
		rope.squash = 0.4
		add_child(rope)
	rope.modulate.a = 1.0
	return rope


## Draws the loop of `rope` back and lashes it out at `at`. False if the rope
## did not last that long.
func _throw_lasso(rope: RopeFx, at: Vector2) -> bool:
	var speed: float = table._speed
	# The wind-up: the loop is drawn back, away from what it is after.
	rope.slack = 0.3
	var back := rope.hand + (rope.hand - at).normalized() * 46.0 + Vector2(0, -34)
	var draw_back := rope.create_tween().set_parallel()
	draw_back.tween_property(rope, "tip", back, 0.14 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	draw_back.tween_property(rope, "loop", 18.0, 0.14 / speed)
	await _wait(0.14)
	if not is_instance_valid(rope):
		return false
	# The strike: nothing, and then all of it at once, like a whip.
	rope.slack = 0.12
	rope.create_tween().tween_method(rope.fling.bind(rope.tip, at), 0.0, 1.0, 0.16 / speed) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await _wait(0.17)
	return is_instance_valid(rope)


## An item changing inventory at the end of a rope: the loop is thrown from
## `thief` to where the item lies (`item_at`), drawn tight around it and
## hauled back to `home`, its place in the thief's inventory. `caught` is
## called the moment the loop closes: the item is no longer where it was.
func item_roped(thief: PlayerState, texture: Texture2D, item_at: Vector2, home: Vector2, caught: Callable) -> void:
	var speed: float = table._speed
	var rope := _lasso_in_hand(thief)
	_snd("fx_lasso")
	if not await _throw_lasso(rope, item_at):
		return

	# The catch: it lands with a crack and is drawn tight.
	caught.call()
	flash(Color(1.0, 1.0, 1.0, 0.1), 0.1)
	ring(item_at, PORCELAIN, 8.0, 46.0, 0.2, 4.0)
	table._shake_screen(6.0)
	var item_size := Vector2(44, 46)
	var item := TextureRect.new()
	item.texture = texture
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.size = item_size
	item.pivot_offset = item_size / 2.0
	item.position = item_at - item_size / 2.0
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	# Under the rope: the loop goes round it.
	move_child(item, rope.get_index())
	UI.pop(item, 1.3, 0.15)
	burst(item_at, RopeFx.ROPE, 8, 130.0, 0.3, 300.0, 6.0)
	# Pulled taut all at once, the rope twangs.
	rope.slack = 0.03
	rope.twang(3.0)
	rope.create_tween().tween_property(rope, "loop", 15.0, 0.1 / speed)
	await _wait(0.24)
	if not is_instance_valid(rope):
		return

	# The haul: item and loop come home together, the rope going slack as it
	# is gathered in.
	rope.slack = 0.2
	var haul := rope.create_tween().set_parallel()
	haul.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	haul.tween_property(rope, "tip", home, 0.45 / speed)
	haul.tween_property(item, "position", home - item_size / 2.0, 0.45 / speed)
	await _wait(0.47)
	_snd("item_get")
	if is_instance_valid(item):
		UI.pop(item, 1.4, 0.2)
	if is_instance_valid(rope):
		var leave := rope.create_tween()
		leave.tween_property(rope, "modulate:a", 0.0, 0.12 / speed)
		leave.tween_callback(rope.queue_free)
	await _wait(0.2)
	if is_instance_valid(item):
		item.queue_free()


## A rope thrown at an inventory with nothing in it: the loop shuts on air
## where the first item would be (`at`), drops, and is dragged back empty.
func rope_missed(thief: PlayerState, at: Vector2) -> void:
	var speed: float = table._speed
	var rope := _lasso_in_hand(thief)
	_snd("fx_lasso_miss")
	if not await _throw_lasso(rope, at):
		return

	# Nothing there: no crack, no jolt, only the loop closing on itself.
	burst(at, SMOKE.lightened(0.4), 6, 70.0, 0.35, -30.0, 7.0)
	rope.slack = 0.05
	rope.twang(2.0)
	rope.create_tween().tween_property(rope, "loop", 6.0, 0.08 / speed)
	await _wait(0.22)
	if not is_instance_valid(rope):
		return

	# Then it is only a rope: it drops where it is and lies there.
	var ground := minf(at.y + 36.0, size.y - 22.0)
	rope.slack = 0.28
	if rope.hand.y < ground:
		rope.ground = ground + 6.0
	var fall := rope.create_tween().set_parallel()
	fall.tween_property(rope, "tip:y", ground, 0.34 / speed).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(rope, "loop", 13.0, 0.2 / speed)
	fall.tween_property(rope, "squash", 0.3, 0.2 / speed)
	await _wait(0.26)
	burst(Vector2(at.x, ground), EARTH.lightened(0.3), 5, 50.0, 0.3, 120.0, 6.0)
	table._float("NOTHING!", at + Vector2(0, -26), UI.MUTED, 22)
	await _wait(0.5)
	if not is_instance_valid(rope):
		return

	# Dragged home along the table, with nothing in it.
	rope.slack = 0.3
	var drag := rope.create_tween()
	drag.tween_property(rope, "tip", rope.hand + Vector2(0, 14), 0.42 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drag.parallel().tween_property(rope, "modulate:a", 0.0, 0.14 / speed).set_delay(0.3 / speed)
	drag.tween_callback(rope.queue_free)
	await _wait(0.46)


## A red cross; the rest is the heal itself.
func _fx_doctor_patch_up(play: Play) -> void:
	var here := _at(play.actor)
	_cross(here, 30.0, Color("e0503c"))
	ring(here, PORCELAIN, 16.0, 70.0, 0.35, 4.0)
	await _wait(0.4)


func _fx_doctor_antidote(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_shimmer")
	_cross(here, 22.0, UI.GREEN.lightened(0.2))
	ring(here, UI.GREEN, 100.0, 16.0, 0.35, 5.0)
	await _wait(0.3)
	rise(here, PORCELAIN, 10, 44.0)
	await _wait(0.3)


## A match, a fuse, and a parcel left on somebody's chair.
func _fx_bomber_time_bomb(play: Play) -> void:
	var here := _at(play.actor)
	var there := _at(play.target)
	_snd("fx_fuse")
	burst(here, EMBER, 6, 90.0, 0.3, -60.0, 6.0)
	stream(here, there, EMBER, 9, 0.5, 0.35)
	await _wait(0.6)
	for i in 2:
		_snd("item_roulette_tick")
		ring(there, EMBER, 46.0, 14.0, 0.2, 4.0)
		await _wait(0.2)


## It was always going to end like this.
func _fx_bomber_blast(play: Play) -> void:
	var there := _at(play.target)
	_snd("item_roulette_tick")
	ring(there, UI.RED, 90.0, 10.0, 0.3, 4.0)
	await _wait(0.32)
	_snd("fx_boom")
	flash(Color(1.0, 0.85, 0.5, 0.55), 0.3)
	burst(there, EMBER, 30, 420.0, 0.7, 300.0, 12.0)
	burst(there, Color("ffd98a"), 18, 300.0, 0.5, 200.0, 9.0)
	burst(there, SMOKE, 16, 160.0, 1.0, -60.0, 13.0)
	ring(there, Color.WHITE, 10.0, 170.0, 0.4, 8.0)
	table._float("BOOM!", there + Vector2(0, -30), EMBER, 34)
	UI.shake(table._table, 26.0, 0.5)
	await _wait(0.75)


## A coin thumbed into the air in front of `who`; it lands on its answer.
func coin_flip(who: PlayerState, heads: bool) -> void:
	var here := _at(who)
	var speed: float = table._speed
	var coin: TextureRect = table._sprite(UI.tex(COIN_ART), here, Vector2(44, 44))
	var ground := coin.position.y - 56.0
	_snd("fx_coin_flip")
	var toss := coin.create_tween()
	toss.tween_property(coin, "position:y", ground - 110.0, 0.4 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	toss.tween_property(coin, "position:y", ground, 0.34 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var spin := coin.create_tween().set_loops(7)
	spin.tween_property(coin, "scale:x", 0.08, 0.05 / speed)
	spin.tween_property(coin, "scale:x", 1.0, 0.05 / speed)
	await _wait(0.76)
	if not is_instance_valid(coin):
		return
	var at := here + Vector2(0, -56)
	if heads:
		_snd("coin_2")
		ring(at, UI.GOLD, 10.0, 76.0, 0.35, 5.0)
		burst(at, UI.GOLD, 16, 200.0, 0.5, 420.0)
		UI.pop(coin, 1.6, 0.25)
	else:
		_snd("coin_3")
		coin.modulate = Color(0.5, 0.46, 0.42)
		burst(at, SMOKE.lightened(0.2), 8, 90.0, 0.4, -20.0, 9.0)
	table._float("HEADS!" if heads else "TAILS", at + Vector2(0, -40), UI.GOLD if heads else UI.MUTED, 28)
	await _wait(0.6)
	if not is_instance_valid(coin):
		return
	var leave := coin.create_tween()
	leave.tween_property(coin, "modulate:a", 0.0, 0.2 / speed)
	leave.tween_callback(coin.queue_free)


## A plus sign, the way it is painted on a medicine chest.
func _cross(at: Vector2, arm: float, color: Color) -> void:
	line(at + Vector2(0, -arm), at + Vector2(0, arm), color, 12.0, 0.4, 0.08)
	line(at + Vector2(-arm, 0), at + Vector2(arm, 0), color, 12.0, 0.4, 0.08)


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


## A rocket going up from `from` to `to` in `time` seconds, slowing as it
## climbs: a bright head and, behind it, a tail of sparks that droops, thins
## out and is gone a moment after the rocket is.
func rocket(from: Vector2, to: Vector2, color: Color, time := ROCKET_RISE) -> void:
	_rockets.append({"a": from, "b": to, "c": color, "t": 0.0, "fly": time, "life": time + ROCKET_TAIL})
	_wake()


## A crackling ray from `from` to `to`: white in a yellow glow, never the
## same shape two moments running.
func bolt(from: Vector2, to: Vector2, life := 0.28) -> void:
	_bolts.append({"a": from, "b": to, "t": 0.0, "life": life, "seed": randf() * 100.0})
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
	for shape in _rockets:
		shape.t += dt
	for shape in _bolts:
		shape.t += dt
	_rockets = _rockets.filter(func(shape: Dictionary) -> bool: return shape.t < shape.life)
	_bolts = _bolts.filter(func(shape: Dictionary) -> bool: return shape.t < shape.life)
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)
	_rings = _rings.filter(func(shape: Dictionary) -> bool: return shape.t < shape.life)
	_lines = _lines.filter(func(shape: Dictionary) -> bool: return shape.t < shape.life)
	if _bits.is_empty() and _rings.is_empty() and _lines.is_empty() and _rockets.is_empty() and _bolts.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for shape in _lines:
		var head := 1.0 if shape.draw <= 0.0 else clampf(shape.t / shape.draw, 0.0, 1.0)
		var fade := clampf((shape.life - shape.t) / maxf(shape.life - shape.draw, 0.01), 0.0, 1.0)
		var tip: Vector2 = shape.a.lerp(shape.b, head)
		draw_line(shape.a, tip, Color(0, 0, 0, 0.5 * fade), shape.w + 4.0)
		draw_line(shape.a, tip, Color(shape.c, shape.c.a * fade), shape.w)
	for shape in _rockets:
		_draw_rocket(shape)
	for shape in _bolts:
		_draw_bolt(shape)
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


## The head of a rocket and the sparks it shed over the last ROCKET_TAIL
## seconds, the oldest of them the faintest, the smallest and the lowest.
func _draw_rocket(shape: Dictionary) -> void:
	var sparks := 18
	for step: int in sparks:
		var age := ROCKET_TAIL * step / sparks
		var then: float = shape.t - age
		# Nothing was shed before it left, or after it burst.
		if then < 0.0 or then > shape.fly:
			continue
		var along: float = 1.0 - pow(1.0 - then / shape.fly, 2.0)
		var old := step / float(sparks)
		var at: Vector2 = shape.a.lerp(shape.b, along) + Vector2(sin(then * 31.0 + step) * 3.0 * old, age * age * 260.0)
		var side := PIXEL * (2.0 if step < 5 else 1.0)
		var ink: Color = Color.WHITE if step == 0 else shape.c.lightened(0.5 * (1.0 - old))
		var corner := ((at - Vector2(side, side) / 2.0) / PIXEL).round() * PIXEL
		draw_rect(Rect2(corner, Vector2(side, side)), Color(ink, 1.0 - old * old))


## A ray as a broken line of pixels between its two ends, kinked afresh every
## few hundredths of a second and fading out over its last third.
func _draw_bolt(shape: Dictionary) -> void:
	var way: Vector2 = shape.b - shape.a
	var side := way.orthogonal().normalized()
	var kinks := maxi(int(way.length() / 30.0), 2)
	var beat := floorf(shape.t / 0.04)
	var points: Array[Vector2] = [shape.a]
	for i: int in range(1, kinks):
		var chance: float = fposmod(sin(shape.seed + i * 12.9898 + beat * 78.233) * 43758.5453, 1.0)
		points.append(shape.a + way * (i / float(kinks)) + side * (chance - 0.5) * 24.0)
	points.append(shape.b)
	var cells := {}
	for i: int in points.size() - 1:
		var steps := maxi(ceili(points[i].distance_to(points[i + 1]) / 2.0), 1)
		for step: int in steps + 1:
			cells[Vector2i((points[i].lerp(points[i + 1], step / float(steps)) / PIXEL).floor())] = true
	var alpha := clampf((1.0 - shape.t / shape.life) * 3.0, 0.0, 1.0)
	for cell: Vector2i in cells:
		draw_rect(Rect2(Vector2(cell) * PIXEL - Vector2(3, 3), Vector2(PIXEL + 6.0, PIXEL + 6.0)), Color(BOLT, alpha * 0.85))
	for cell: Vector2i in cells:
		draw_rect(Rect2(Vector2(cell) * PIXEL, Vector2(PIXEL, PIXEL)), Color(Color.WHITE, alpha))


# --- props ---------------------------------------------------------------------

## The Magician's wand: black, capped in white at both ends. Its origin is
## the end it is held by and it points along +x. It comes out from behind a
## box: `rest` is the point of the box's edge it crosses, `way` the direction
## out of it, and `out` (0 to 1) how much of it has come through; what is
## still behind the edge is not drawn. `charge` (0 to 1) lights its tip.
class WandFx extends Control:
	const PIXEL := 4.0
	const LENGTH := 15  # in pixels of the wand
	## How far from the edge it floats once it is all out.
	const CLEAR := 12.0
	const EDGE := Color("0d0b12")
	const BODY := Color("262230")
	const SHINE := Color("5d5670")
	const CAP := Color("f2efe6")
	const CAP_SHADE := Color("b9b4c4")
	const GLOW := Color("ffd84a")

	var rest := Vector2.ZERO
	var way := Vector2.UP
	var out := 1.0:
		set(value):
			out = value
			position = rest + way * (out * (LENGTH * PIXEL + CLEAR) - LENGTH * PIXEL)
			queue_redraw()
	var charge := 0.0:
		set(value):
			charge = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Where its far end is, in the coordinates of whatever holds the wand.
	func tip() -> Vector2:
		return position + Vector2.from_angle(rotation) * LENGTH * PIXEL

	func middle() -> Vector2:
		return position + Vector2.from_angle(rotation) * LENGTH * PIXEL / 2.0

	## Turns it to `angle` about its middle, not about the end it is held by.
	func twirl(angle: float) -> void:
		var hub := middle()
		rotation = angle
		position = hub - Vector2.from_angle(angle) * LENGTH * PIXEL / 2.0

	func _draw() -> void:
		_cells(-1, -2, LENGTH + 2, 4, EDGE)
		_cells(0, -1, LENGTH, 2, BODY)
		_cells(0, -1, LENGTH, 1, SHINE)
		for cap: int in [0, LENGTH - 3]:
			_cells(cap, -1, 3, 2, CAP)
			_cells(cap, 0, 3, 1, CAP_SHADE)
		if charge <= 0.0:
			return
		# A star of light on the tip, its arms as long as the charge.
		var arm := roundi(3.0 * charge)
		for i in range(1, arm + 1):
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				_cells(LENGTH + step.x * i, step.y * i - (1 if step.y < 0 else 0), 1, 1, GLOW if i == arm else Color.WHITE)
		_cells(LENGTH - 1, -1, 2, 2, Color.WHITE)

	## A block of pixels of the wand, less whatever of it is still behind the
	## edge it comes out of.
	func _cells(x: int, y: int, w: int, h: int, ink: Color) -> void:
		var hidden := ceili(maxf(LENGTH * PIXEL - out * (LENGTH * PIXEL + CLEAR), 0.0) / PIXEL)
		var from := maxi(x, hidden) if hidden > 0 else x
		if from >= x + w:
			return
		draw_rect(Rect2(Vector2(from, y) * PIXEL, Vector2(x + w - from, h) * PIXEL), ink)



## The sheriff's badge: a five-pointed star in the same chunky pixels as the
## rest of the effects, three tones of gold and a dark rim. `shine` (0 to 1)
## runs a glint across it.
class BadgeFx extends Control:
	const PIXEL := 4.0
	## From the middle of the star to a point, in pixels of the badge.
	const REACH := 10
	const EDGE := Color("4a2e0e")
	const LIGHT := Color("ffe9a0")
	const MID := Color("e6bc4c")
	const DARK := Color("b07f24")

	var shine := 0.0:
		set(value):
			shine = value
			queue_redraw()

	var _rim: Array[Vector2i] = []
	var _gold: Dictionary = {}  # Vector2i -> Color

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cut()

	## Cuts the star out of a grid: the pixels of its edge that face the light
	## (up and left) are bright, the ones facing away are dark.
	func _cut() -> void:
		var star := PackedVector2Array()
		for i in 5:
			star.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 5.0) * REACH)
			star.append(Vector2.from_angle(-PI / 2.0 + TAU * (i + 0.5) / 5.0) * REACH * 0.45)
		var inside := {}
		for y in range(-REACH - 1, REACH + 1):
			for x in range(-REACH - 1, REACH + 1):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), star):
					inside[Vector2i(x, y)] = true
		for cell: Vector2i in inside:
			var lit := not inside.has(cell + Vector2i.UP) or not inside.has(cell + Vector2i.LEFT)
			var shaded := not inside.has(cell + Vector2i.DOWN) or not inside.has(cell + Vector2i.RIGHT)
			# Where the star is too thin to have two sides, it is plain gold.
			_gold[cell] = MID if lit == shaded else (LIGHT if lit else DARK)
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not inside.has(cell + step) and not _rim.has(cell + step):
					_rim.append(cell + step)

	func _draw() -> void:
		for cell: Vector2i in _rim:
			_dot(cell, EDGE)
		for cell: Vector2i in _gold:
			_dot(cell, _gold[cell])
		if shine <= 0.0 or shine >= 1.0:
			return
		# The glint crosses from the top left; a smaller one answers it.
		var path := Vector2(-6, -6).lerp(Vector2(5, 5), shine)
		_glint(Vector2i(path.round()), roundi(4.0 * sin(shine * PI)))
		var late := clampf((shine - 0.35) / 0.65, 0.0, 1.0)
		_glint(Vector2i(6, -4), roundi(2.0 * sin(late * PI)))

	## A plus of light, `arm` pixels from its middle to each end.
	func _glint(at: Vector2i, arm: int) -> void:
		if arm <= 0:
			return
		for i in range(1, arm + 1):
			var ink := LIGHT if i == arm else Color.WHITE
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				_dot(at + step * i, ink)
		_dot(at, Color.WHITE)

	func _dot(cell: Vector2i, ink: Color) -> void:
		draw_rect(Rect2(Vector2(cell) * PIXEL, Vector2(PIXEL, PIXEL)), ink)


## The scales of the court, in brass: a post on a stepped foot, a beam across
## its top and a pan hung by chains from each end. The origin is the pivot.
## `tilt` leans the beam; the pans hang from its ends and swing behind them.
class ScaleFx extends Control:
	const PIXEL := 4.0
	## How far the beam goes down to one side before it meets its stop.
	const LEAN := 0.3
	## In pixels of the scales: the pivot to each end of the beam, an end of
	## the beam down to its pan, half the width of a pan, the pivot to the foot.
	const ARM := 24.0
	const DROP := 15
	const PAN := 8
	const POST := 30
	const EDGE := Color("2c1a08")
	const LIGHT := Color("ffe9a0")
	const MID := Color("e6bc4c")
	const DARK := Color("b07f24")
	const SHADE := Color("7d5616")
	## How hard a pan is pulled back under its end of the beam, and how fast
	## its swing dies.
	const PULL := 90.0
	const DAMPING := 5.0

	## The lean of the beam, in radians: positive lowers the pan on the right.
	var tilt := 0.0

	## Where each pan hangs (left, right), sideways, and how fast it is going.
	var _pans: Array[float] = [1.0 - ARM, ARM - 1.0]
	var _speeds: Array[float] = [0.0, 0.0]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var step := minf(delta, 1.0 / 30.0)
		for i in 2:
			_speeds[i] += ((_hook(i).x - _pans[i]) * PULL - _speeds[i] * DAMPING) * step
			_pans[i] += _speeds[i] * step
		queue_redraw()

	## The beam hitting its stop: both pans are thrown about on their chains.
	func jolt(strength := 30.0) -> void:
		_speeds[0] -= strength
		_speeds[1] += strength * 0.7

	## The middle of the pan on `side` (negative: left), from the pivot.
	func pan(side: float) -> Vector2:
		var i := 0 if side < 0.0 else 1
		return Vector2(_pans[i], _hook(i).y + DROP + 1.0) * PIXEL

	## The end of the beam a pan hangs from, in pixels of the scales.
	func _hook(i: int) -> Vector2:
		var reach := ceili(ARM * cos(tilt))
		var column := -reach if i == 0 else reach - 1
		return Vector2(column + (1.0 if i == 0 else 0.0), roundi((column + 0.5) * tan(tilt)))

	func _draw() -> void:
		var chains := {}
		var pans := {}
		for i in 2:
			var hook := Vector2i(_hook(i))
			var middle := roundi(_pans[i])
			var rim := hook.y + DROP
			_link(chains, hook + Vector2i(-1, 2), Vector2i(middle - PAN + 1, rim - 1))
			_link(chains, hook + Vector2i(0, 2), Vector2i(middle + PAN - 2, rim - 1))
			_fill(pans, middle - PAN, rim, PAN * 2, 1, LIGHT)
			_fill(pans, middle - PAN + 1, rim + 1, PAN * 2 - 2, 1, MID)
			_fill(pans, middle + PAN - 4, rim + 1, 3, 1, DARK)
			_fill(pans, middle - PAN + 3, rim + 2, PAN * 2 - 6, 1, DARK)
		_paint(chains, 2.0)
		_paint(pans, PIXEL)

		# The post, with a collar halfway down, on its two steps.
		var stand := {}
		_fill(stand, -1, 2, 1, POST - 2, MID)
		_fill(stand, 0, 2, 1, POST - 2, DARK)
		_fill(stand, -2, 13, 4, 2, MID)
		_fill(stand, -2, 13, 4, 1, LIGHT)
		_fill(stand, -5, POST, 10, 2, MID)
		_fill(stand, -5, POST, 10, 1, LIGHT)
		_fill(stand, -9, POST + 2, 18, 2, MID)
		_fill(stand, -9, POST + 2, 18, 1, LIGHT)
		_fill(stand, 6, POST + 3, 3, 1, DARK)
		_paint(stand, PIXEL)

		# The beam, a knob at each end, and the hub it turns on under a finial.
		var beam := {}
		var slope := tan(tilt)
		var reach := ceili(ARM * cos(tilt))
		for column in range(-reach, reach):
			var row := roundi((column + 0.5) * slope)
			beam[Vector2i(column, row - 1)] = LIGHT
			beam[Vector2i(column, row)] = MID
		for i in 2:
			var hook := Vector2i(_hook(i))
			_fill(beam, hook.x - 1, hook.y - 2, 2, 4, MID)
			_fill(beam, hook.x - 1, hook.y - 2, 2, 1, LIGHT)
			_fill(beam, hook.x - 1, hook.y + 1, 2, 1, DARK)
		_fill(beam, -1, -5, 2, 3, MID)
		_fill(beam, -2, -8, 4, 3, MID)
		_fill(beam, -2, -8, 3, 1, LIGHT)
		_fill(beam, 1, -7, 1, 2, DARK)
		_fill(beam, -3, -3, 6, 6, MID)
		_fill(beam, -3, -3, 6, 1, LIGHT)
		_fill(beam, -3, -3, 1, 6, LIGHT)
		_fill(beam, 2, -2, 1, 5, DARK)
		_fill(beam, -2, 2, 5, 1, DARK)
		_fill(beam, -1, -1, 2, 2, SHADE)
		_paint(beam, PIXEL)

	## A chain from one pixel to another, a link light and a link dark.
	func _link(cells: Dictionary, from: Vector2i, to: Vector2i) -> void:
		var steps := maxi(maxi(absi(to.x - from.x), absi(to.y - from.y)), 1)
		for step in steps + 1:
			var cell := Vector2i(Vector2(from).lerp(Vector2(to), step / float(steps)).round())
			cells[cell] = MID if step % 2 == 0 else SHADE

	func _fill(cells: Dictionary, x: int, y: int, w: int, h: int, ink: Color) -> void:
		for row in h:
			for column in w:
				cells[Vector2i(x + column, y + row)] = ink

	## Draws `cells` (Vector2i -> Color) with a dark rim `rim` wide around them.
	func _paint(cells: Dictionary, rim: float) -> void:
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * PIXEL - Vector2(rim, rim), Vector2(PIXEL + rim * 2.0, PIXEL + rim * 2.0)), EDGE)
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * PIXEL, Vector2(PIXEL, PIXEL)), cells[cell])


## A lasso. The rope is a chain of points with weight and no stiffness: held
## at one end, tied to the loop at the other, it sags, trails behind whatever
## the loop does and snaps about when it is pulled tight. It is drawn in the
## chunky pixels of the other effects.
class RopeFx extends Control:
	const PIXEL := 4.0
	const ROPE := Color("b98d54")
	const EDGE := Color("2a1a10")
	const KNOT := Color("6b4a2a")
	## The twisted strands, as they come round one after the other along the
	## rope, and how many pixels of rope each one shows for.
	const STRANDS: Array[Color] = [Color("dcb87c"), Color("b98d54"), Color("8a6238"), Color("a67c48")]
	const TWIST := 5.0
	const LINKS := 18
	const GRAVITY := 1500.0
	## How much of its speed a point of the rope keeps from one step to the next.
	const DRAG := 0.955

	## Where the rope is held, and the middle of the loop at its other end.
	var hand := Vector2.ZERO
	var tip := Vector2.ZERO
	## The radius of the loop, and how round it looks (1: seen flat on).
	var loop := 20.0
	var squash := 1.0
	## How much longer the rope is than the straight way from hand to loop:
	## 0 is taut, 0.3 hangs and whips about.
	var slack := 0.2
	## What the rope lies on when it is let go: no point of it gets below.
	var ground := INF

	var _points := PackedVector2Array()
	var _before := PackedVector2Array()
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		_swing(minf(delta, 1.0 / 30.0))
		queue_redraw()

	## The loop going round over the head of whoever holds it, about `centre`.
	func whirl(angle: float, centre: Vector2) -> void:
		tip = centre + Vector2(cos(angle) * 30.0, sin(angle) * 10.0)
		squash = 0.4 + 0.1 * sin(angle)

	## The loop on its way from `from` to `to` (`along` from 0 to 1): lashed
	## out almost straight, with a low arc and a flick from side to side that
	## dies as it gets there. How sudden it is is up to whoever drives `along`.
	func fling(along: float, from: Vector2, to: Vector2) -> void:
		var way := to - from
		var arc := minf(way.length() * 0.1, 30.0) * sin(along * PI)
		var flick := way.orthogonal().normalized() * sin(along * TAU) * 10.0 * (1.0 - along)
		tip = from.lerp(to, along) + Vector2(0, -arc) + flick
		loop = lerpf(18.0, 26.0, along)
		squash = lerpf(0.45, 0.9, along)

	## A jolt sideways along the whole rope, as when it is pulled tight.
	func twang(strength: float) -> void:
		if _points.size() < LINKS:
			return
		var side := (_knot() - hand).orthogonal().normalized()
		for i in range(1, LINKS - 1):
			_points[i] += side * sin(TAU * i / (LINKS - 1)) * strength

	## Where the rope meets the loop: on its rim, on the side the rope comes from.
	func _knot() -> Vector2:
		var from := hand if _points.size() < LINKS else _points[LINKS - 2]
		var toward := (from - tip).angle()
		return tip + Vector2(cos(toward) * loop, sin(toward) * loop * squash)

	## One step of the rope: every point keeps going the way it was, falls a
	## little, and is then pulled back to within reach of its neighbours.
	func _swing(delta: float) -> void:
		var knot := _knot()
		if _points.size() < LINKS:
			for i in LINKS:
				_points.append(hand.lerp(knot, i / float(LINKS - 1)))
			_before = _points.duplicate()
		var reach := hand.distance_to(knot) * (1.0 + slack) / (LINKS - 1)
		for i in range(1, LINKS - 1):
			var now := _points[i]
			_points[i] = now + (now - _before[i]) * DRAG + Vector2(0, GRAVITY) * delta * delta
			_points[i].y = minf(_points[i].y, ground)
			_before[i] = now
		for pass_ in 8:
			_points[0] = hand
			_points[LINKS - 1] = knot
			for i in LINKS - 1:
				var gap := _points[i + 1] - _points[i]
				var length := gap.length()
				# A rope pulls and never pushes.
				if length <= reach:
					continue
				var pull := gap * (1.0 - reach / length)
				var first := i == 0
				var last := i + 1 == LINKS - 1
				if not first:
					_points[i] += pull * (1.0 if last else 0.5)
				if not last:
					_points[i + 1] -= pull * (1.0 if first else 0.5)
		_points[0] = hand
		_points[LINKS - 1] = knot

	func _draw() -> void:
		if _points.size() < LINKS:
			return
		# The loop is rope too: it wobbles as it goes.
		var ring := PackedVector2Array()
		for i in 21:
			var angle := TAU * i / 20.0
			var wobble := 1.0 + 0.09 * sin(angle * 3.0 + _time * 9.0)
			ring.append(tip + Vector2(cos(angle) * loop, sin(angle) * loop * squash) * wobble)
		var cells := {}
		_trace(_points, cells)
		_trace(ring, cells)
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * PIXEL - Vector2(2, 2), Vector2(PIXEL + 4.0, PIXEL + 4.0)), EDGE)
		for cell: Vector2i in cells:
			var strand: Color = cells[cell]
			draw_rect(Rect2(Vector2(cell) * PIXEL, Vector2(PIXEL, PIXEL)), strand)
		# The knot: a dark lump where the rope runs into the loop.
		var knot := (_points[LINKS - 1] / PIXEL).floor() * PIXEL - Vector2(PIXEL, PIXEL) / 2.0
		draw_rect(Rect2(knot - Vector2(2, 2), Vector2(PIXEL, PIXEL) * 2.0 + Vector2(4, 4)), EDGE)
		draw_rect(Rect2(knot, Vector2(PIXEL, PIXEL) * 2.0), KNOT)
		draw_rect(Rect2(knot, Vector2(PIXEL, PIXEL)), STRANDS[3])

	## Marks in `cells` the pixels that the line through `path` goes over,
	## each with the colour of the strand that is on top at that point.
	func _trace(path: PackedVector2Array, cells: Dictionary) -> void:
		var run := 0.0
		for i in path.size() - 1:
			var length := path[i].distance_to(path[i + 1])
			var steps := maxi(ceili(length / 2.0), 1)
			for step in steps + 1:
				var along := step / float(steps)
				var cell := Vector2i((path[i].lerp(path[i + 1], along) / PIXEL).floor())
				if not cells.has(cell):
					cells[cell] = STRANDS[int((run + length * along) / TWIST) % STRANDS.size()]
			run += length


## The Magician's hat, set down mouth up, and what it brings into being: an
## item printed row by row over it, from the bottom up, under a ring of light
## that climbs with the last row. Its origin is the middle of the mouth.
class HatFx extends Control:
	const PIXEL := 4.0
	## The size the item is printed at, and how far over the mouth it floats.
	const ITEM := Vector2(92, 96)
	const LIFT := 16.0
	## K: outline, B: felt, H: where the light catches it, R: the band,
	## M: the inside of the hat.
	const SHAPE: Array[String] = [
		".....KKKKKKKKKKK.....",
		"..KKKHHHHHHHHHHHKKK..",
		".KHHHKMMMMMMMMMKBBBK.",
		"KHHHHKMMMMMMMMMKBBBBK",
		".KHHHBKKKKKKKKKBBBBK.",
		"..KKKBBBBBBBBBBBKKK..",
		".....KRRRRRRRRRK.....",
		".....KRRRRRRRRRK.....",
		".....KHBBBBBBBBK.....",
		".....KHBBBBBBBBK.....",
		".....KHBBBBBBBBK.....",
		".....KHBBBBBBBBK.....",
		".....KHBBBBBBBBK.....",
		"......KKKKKKKKK......",
	]
	## The cell of SHAPE the origin sits on: the middle of the mouth.
	const MOUTH := Vector2(10.5, 3.0)
	const INK := {"K": Color("0d0b12"), "B": Color("262230"), "H": Color("5d5670"), "R": Color("c22a22")}
	const DEPTH := Color("120a1c")
	const SPELL := Color("c79bff")
	const SPELL_DEEP := Color("7a45c9")
	const GOLD := Color("ffd76a")
	const MOTES := 10

	## How much of the item is there, 0 to 1 from the bottom up.
	var printed := 0.0
	## How hard the inside of the hat is shining, 0 to 1.
	var glow := 0.0

	var _item: Texture2D
	## The shape of the item with nothing in it: what is yet to be printed.
	var _outline: Texture2D
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	## What the hat prints from now on; null takes it away.
	func set_item(texture: Texture2D) -> void:
		_item = texture
		_outline = null
		printed = 0.0
		var image := texture.get_image() if texture != null else null
		if image == null:
			return
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var blank := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		blank.fill(Color(1, 1, 1, 0))
		var white := blank.duplicate() as Image
		white.fill(Color.WHITE)
		blank.blit_rect_mask(white, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		_outline = ImageTexture.create_from_image(blank)

	## The middle of the printed item, from the origin.
	func item_middle() -> Vector2:
		return Vector2(0, -LIFT - ITEM.y / 2.0)

	func _draw() -> void:
		var corner := Vector2(-ITEM.x / 2.0, -LIFT - ITEM.y)
		var rows := int(ITEM.y / PIXEL)
		var done := clampi(floori(printed * rows), 0, rows)
		# The row being laid down right now, from the origin.
		var level := corner.y + ITEM.y - done * PIXEL
		var printing := _item != null and printed < 1.0
		if printing:
			# What the hat throws up at it.
			for x: float in [-28.0, -12.0, 4.0, 20.0]:
				var beam := 0.1 + 0.07 * sin(_time * 11.0 + x)
				draw_rect(Rect2(x, level, 8.0, -level), Color(SPELL, beam * glow))
		_halo(Vector2.ZERO, Vector2(54, 10), 16, 2.2, false)
		for y in SHAPE.size():
			for x in SHAPE[y].length():
				var mark := SHAPE[y][x]
				if mark == ".":
					continue
				var ink: Color = INK.get(mark, DEPTH)
				if mark == "M":
					ink = DEPTH.lerp(SPELL, glow * (0.75 + 0.25 * sin(_time * 9.0 + x)))
				elif mark == "K":
					# Lit from inside, its edge shows against the dark of the table.
					ink = ink.lerp(SPELL_DEEP, 0.25 + 0.45 * glow)
				draw_rect(Rect2((Vector2(x, y) - MOUTH) * PIXEL, Vector2(PIXEL, PIXEL)), ink)
		_halo(Vector2.ZERO, Vector2(54, 10), 16, 2.2, true)
		if _item == null:
			return
		var reach := Vector2(ITEM.x / 2.0 + 16.0, 9.0)
		if printing:
			_halo(Vector2(0, level), reach, 18, -3.4, false)
		if _outline != null:
			# Yet to come: every other row of its shape, like something seen through.
			for row in range(0, rows - done, 2):
				_strip(_outline, corner, row, Color(SPELL, 0.32 + 0.1 * sin(_time * 13.0 + row)))
		if done > 0:
			var part := done * PIXEL / ITEM.y
			var source := _item.get_size()
			draw_texture_rect_region(_item, Rect2(corner.x, level, ITEM.x, done * PIXEL),
					Rect2(0, source.y * (1.0 - part), source.x, source.y * part))
		if not printing:
			return
		if _outline != null:
			# Fresh off the line it is still white hot.
			for step in mini(3, done):
				_strip(_outline, corner, rows - done + step, Color(1.0, 0.92, 1.0, 0.8 - 0.27 * step))
		# The line itself, and the head running along it.
		draw_rect(Rect2(corner.x - 8.0, level - PIXEL, ITEM.x + 16.0, PIXEL), Color(SPELL_DEEP, 0.9))
		draw_rect(Rect2(corner.x, level - PIXEL, ITEM.x, PIXEL), Color.WHITE)
		var sweep := 0.5 + 0.5 * sin(_time * 26.0)
		var head := snappedf(corner.x + sweep * (ITEM.x - 8.0), PIXEL)
		draw_rect(Rect2(head - 2.0, level - PIXEL - 4.0, 12.0, 12.0), GOLD)
		draw_rect(Rect2(head, level - PIXEL - 2.0, 8.0, 8.0), Color.WHITE)
		_halo(Vector2(0, level), reach, 18, -3.4, true)
		_motes(corner, level)

	## One row of `texture`, `row` rows down from the top of the item.
	func _strip(texture: Texture2D, corner: Vector2, row: int, tint: Color) -> void:
		var source := texture.get_size()
		var step := PIXEL / ITEM.y
		draw_texture_rect_region(texture, Rect2(corner.x, corner.y + row * PIXEL, ITEM.x, PIXEL),
				Rect2(0, source.y * step * row, source.x, source.y * step), tint)

	## Half of a ring of lights lying flat about `at`, going round: the far
	## half, drawn before what it circles, or the `near` one, drawn after.
	func _halo(at: Vector2, radius: Vector2, dots: int, turn: float, near: bool) -> void:
		if glow <= 0.0:
			return
		for i in dots:
			var angle := TAU * i / dots + _time * turn
			if (sin(angle) >= 0.0) != near:
				continue
			var ink := GOLD if i % 3 == 0 else SPELL
			_dot(at + Vector2(cos(angle), sin(angle)) * radius, Color(ink, glow * (0.95 if near else 0.45)))

	## Sparks that come off the line and drift up; every third one is a star.
	func _motes(corner: Vector2, level: float) -> void:
		for i in MOTES:
			var seed_ := i * 0.618
			var life := fposmod(_time * (1.1 + 0.6 * fposmod(seed_ * 3.7, 1.0)) + seed_, 1.0)
			var at := Vector2(corner.x + ITEM.x * fposmod(seed_ * 7.3, 1.0) + sin(_time * 5.0 + i) * 4.0,
					level - 8.0 - life * 46.0)
			var shade: Color = [Color.WHITE, GOLD, SPELL][i % 3]
			var ink := Color(shade, 1.0 - life * life)
			_dot(at, ink)
			if i % 3 == 0 and life < 0.6:
				for arm: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					_dot(at + arm * PIXEL, Color(ink, ink.a * 0.7))

	func _dot(at: Vector2, ink: Color) -> void:
		draw_rect(Rect2((at / PIXEL).floor() * PIXEL, Vector2(PIXEL, PIXEL)), ink)
