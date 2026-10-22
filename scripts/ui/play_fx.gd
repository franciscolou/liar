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
## How far past a cursed box the bending of a curse_flush reaches, easing off.
const WARP_FEATHER := 48.0
const VoodooDoll := preload("res://scripts/ui/voodoo_doll.gd")
const Sounds := preload("res://scripts/ui/sounds.gd")
const Painter := preload("res://scripts/content/characters/painter.gd")
## Monochrome: how long the brush takes from box to box, and along each one.
const BRUSH_HOP := 0.38
const BRUSH_SWEEP := 0.42
const COIN_ART := "res://assets/ui/coin.png"
const HEART_ART := "res://assets/ui/heart.png"
## The potion going down: how many steps, over how long, and what is left
## where the liquid was.
const GAVEL_RAISED := 0.95  # radians the gavel is lifted before a knock
const SEAL_WAX := Color("8e1c2b")  # the wax of the seal an oath leaves (StatusFx)
const SCALES_Y := 266.0  # where the pivot of the scales of the court stands
## A firework rocket: how long it climbs, and how long what it leaves behind
## takes to go out.
const ROCKET_RISE := 0.5
const ROCKET_TAIL := 0.3
const BOLT := Color("ffd84a")
## A Demolition: how far in front of the Bomber the bomb is set down, and
## the hops it gets to the item in. For each one: how much of the way it has
## covered when it comes down, how far off to the side (in BOMB_STRAY), how
## high it goes and how long it is in the air.
const BOMB_REST := 74.0
const BOMB_FLOOR := 430.0
const BOMB_STRAY := 22.0
const BOMB_HOPS: Array = [[0.6, 1.0, 96.0, 0.54], [0.84, 0.5, 38.0, 0.36], [0.95, 0.15, 15.0, 0.24], [1.0, 0.0, 5.0, 0.14]]
## Radians a second it spins at as it is thrown; each bounce takes some off.
const BOMB_SPIN := 9.0
## A bomb that found nothing to blow up (bomb_missed): the least it covers in
## a hop as it bounces away, and how many hops it gets to leave the screen.
const BOMB_ROLL := 110.0
const BOMB_MISSES := 14
## The Bard's tunes, one of them drawn for each Swindle: the sound (see
## fx_serenade* in gen_sfx.py) and when each of its notes is played, in seconds
## from its start. The lute is plucked on every one of them. `long` is the
## notes that are held, by their place in `notes`, and for how many seconds:
## the strings go on shaking for as long as those sound.
const SERENADES: Array[Dictionary] = [
	{"sound": "fx_serenade", "notes": [0.0, 0.4, 1.2, 1.4, 1.6, 1.8, 2.2, 2.4, 2.8], "long": {8: 2.5}},
	{"sound": "fx_serenade_2", "notes": [0.0, 0.4, 1.2, 1.4, 1.6, 1.8, 2.2], "long": {1: 0.8, 6: 2.5}},
	{"sound": "fx_serenade_3", "notes": [0.0, 0.6, 1.2, 1.6, 1.8, 2.2, 2.4, 2.8], "long": {6: 0.4, 7: 1.8}},
	{"sound": "fx_serenade_4", "notes": [0.0, 0.2, 0.4, 0.6, 1.2, 1.4, 1.6, 1.8, 2.2], "long": {8: 2.3}},
	{"sound": "fx_serenade_5", "notes": [0.0, 0.4, 1.0, 1.2, 1.6, 2.2], "long": {5: 0.8}},
]
## How long the lute stays out: the tune and what rings on after it.
const SERENADE_LENGTH := 5.0
## A Silver Tongue: how far short of the coins the palm of the hand stops, how
## far from its grip on the neck the lute strikes, and the radians it is
## lifted before a blow.
const GLOVE_SHORT := 40.0
const LUTE_REACH := 84.0
const LUTE_LIFT := 0.95
## How many times it comes down on the hand.
const LUTE_BLOWS := 3
## How far back the lute is wound for a blow at the glove, how far it goes on
## through it, and how far from the edge of the screen its belly has to stay.
const LUTE_WIND := 1.3
const LUTE_SWEEP := 0.5
const LUTE_ROOM := 24.0
## A Shakedown: the px one hop of the boot covers and the seconds it takes,
## how high over the coins the heel is drawn back, how far back the boot is
## tipped to pour (toe down: see BootFx.pose), the most coins shown, the
## seconds between two coins jumping out of the pile and each one's time in
## the air, and the same for the coins poured out.
const BOOT_HOP := 170.0
const BOOT_STRIDE := 0.2
const BOOT_COCKED := 26.0
const BOOT_TIPPED := -1.6
const BOOT_COINS := 6
const BOOT_SPIT := 0.1
const BOOT_ARC := 0.5
const BOOT_POUR := 0.15
const BOOT_DROP := 0.24
const DRAIN_FRAMES := 12
const DRAIN_TIME := 0.6
const EMPTY_GLASS := Color(0.78, 0.9, 0.96, 0.16)
## How long an item takes to be printed out of the hat.
const PRINT_TIME := 0.85
## The Entity: the violet of its light, and how far apart the three images
## of its things are drawn.
const COSMOS := Color("9b6bff")
const PRISM_SPLIT := 6.0
## The chains of an Entropy, broken: how long they fly at full speed, how slow
## time goes for the pieces after that, how long they take to wind in on
## what they become (and from one of those to the next), and how many coins
## at most are shown.
const DEBRIS_BLAST := 0.1
const DEBRIS_PACE := 0.05
const CONDENSE := 0.9
const CONDENSE_STAGGER := 0.08
const DEBRIS_COINS := 6
## How long the chains of an Entropy thrown away take to go into the hole.
const SWALLOW := 0.8
## The singularity of a Materialize: how far from the box it opens, how wide
## the circle round it is before and at the end of the spin, how fast things
## go round it (radians a second) at both ends, how long the spin takes to
## build up and to die down, how far things are pulled out of shape, and the
## size of what is made.
const HOLE_REACH := 78.0
const ORBIT := 46.0
const ORBIT_TIGHT := 30.0
const WHIRL_SLOW := 2.6
const WHIRL_FAST := 30.0
const SPIN_UP := 2.1
const UNWIND := 0.7
const NOODLE := 1.5
const MADE := Vector2(61, 64)
## What is made, on its way to the inventory: the seconds it takes, how far
## round it goes on the way (radians), how much wider its circle gets (as a
## share of the distance, within these bounds) and the part of the way it
## spends still going round the hole before its circle sets off.
const SLING := 1.05
const SLING_SWEEP := 8.8
const SLING_SWELL := 0.2
const SLING_SWELL_MIN := 26.0
const SLING_SWELL_MAX := 60.0
const SLING_STAY := 0.28
## A card thrown on the tray of a Last Call, and where one is held up to be
## seen before it goes in (from the middle of the tray).
## The shadow of a Sneak Peek: how far short of the hand its hat stops, the
## seconds it takes to creep there, to reach for the card, to hold it up
## (for the table: the player who is the one looking says when they have
## seen it), to put it back and to slide home.
const LURK_SHY := 58.0
const LURK_CREEP := 1.0
const LURK_REACH := 0.16
const LURK_LIFT := 0.2
const LURK_GLANCE := 0.55
const LURK_RETURN := 0.18
const LURK_HOME := 0.4
## A shadow that found no card there: how far to each side it feels for one,
## how many question marks it is left with and how fast it is gone.
const LURK_GROPE := 26.0
const LURK_PUZZLED := 3
const LURK_FLEE := 0.16
## How big the card is while it is looked at, by the viewer and by others,
## and how far it is lifted then: clear of the hat's side for the viewer,
## off its place for the others.
const LURK_SHOWN := 1.7
const LURK_SHOWN_AWAY := 1.25
const LURK_LIFTED := 34.0
const LURK_LIFTED_AWAY := 14.0
## How far from the box of the Gambler a side bet is laid.
const BET_REACH := 52.0
## How far off the box the needle of an Antidote waits, and how deep it goes.
const NEEDLE_OFF := 24.0
const NEEDLE_IN := 12.0
const SERUM := Color("6fe08a")
const TOSSED := Vector2(44, 80)
const TOSS_SHOWN := Vector2(0, -112)
const TOSS_SHOWN_ZOOM := 2.2
const TOSS_STYLES := 6

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
## The boot of a Shakedown, out from the moment it is drawn back until the
## coins are home: whose it is, whose coins it is over, and the pose it was
## last sent to (see _boot_go).
var _boot: BootFx
var _boot_owner: PlayerState
var _boot_target: PlayerState
var _boot_pose: Array = []
## The hat of a Hat Trick, set down and waiting for what comes out of it.
var _hat: HatFx
var _hat_owner: PlayerState
## The wand of a Counterfeit, out and pointing until the copy is made.
var _wand: WandFx
var _wand_owner: PlayerState
## The tray of a Last Call, on the table until the cards are in.
var _tray: TrayFx
## The vault of a Cash Out, open until the coins are out.
var _vault: VaultFx
var _vault_owner: PlayerState
## The doll of a Hex, lying where it landed until the hex takes hold.
var _doll: VoodooDoll
var _doll_target: PlayerState
## The Voodooist pulling the strings of her dolls (Puppet Strings), until
## the turn is over (cut_strings): what her dolls do in the meantime is
## theirs to show.
var _strings: PlayerState
## The bomb of a Demolition, lit and waiting to be told which item it is for.
var _bomb: BombFx
## The chains of an Entropy in pieces, hanging in the air until they are
## made into what they pay.
var _debris: DebrisFx
var _debris_owner: PlayerState
## The singularity of a Materialize, open until the item is made; then the
## item itself, standing where it was until it is gained.
var _hole: SingularityFx
var _hole_owner: PlayerState
## True once what goes round the hole is the item it made.
var _made := false
var _made_at := Vector2.INF
## What makes a borrowed action look and sound wrong (see corrupt).
## The shadow of a Sneak Peek, out and waiting for card_peeked.
var _lurk: LurkFx
var _lurk_owner: PlayerState
## The hands an Untraceable took off the table: player id -> their card views.
var _vanished: Dictionary = {}
## The inventories an Untraceable took off the table: player id -> true.
var _hidden_items: Dictionary = {}
## The side bets lying on the table: player id -> BillsFx.
var _bets: Dictionary = {}
var _glitch: GlitchFx
## The plays that stepped in while it was on (see step_in): they are nobody's
## copy, and it is held back for as long as any of them is on the table.
var _guests: Array[Play] = []


func _init(match_table: Variant) -> void:
	table = match_table
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func has_effect(play: Play) -> bool:
	return has_method(_method(play.source.id))


## Plays the effect of `play`, if it has one, and waits for it.
func play_effect(play: Play) -> void:
	var method := _method(play.source.id)
	if not has_method(method):
		return
	# An item used in the middle of a borrowed action is not part of the copy.
	var guest := _glitch != null and not _guests.has(play) and not _borrowed(play)
	if guest:
		step_in(play)
	await call(method, play)
	if guest:
		step_out(play)


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
	await _stab(play, play.actor)


func _fx_assassin_streak_thirst(play: Play) -> void:
	# Straight on from the one who has just fallen to the next, if that is
	# where the shade is: if the Assassin's own blow felled them. Whoever
	# got the kill some other way (catching a liar) starts from their own box.
	var from := play.actor
	if play.event != null:
		var fallen: Variant = play.event.data.get("player")
		var blow: Variant = play.event.data.get("play")
		if fallen is PlayerState and fallen != play.target and blow is Play and blow.actor == play.actor:
			from = fallen
	await _stab(play, from)


## The table goes dark and a shade slips out of the box of `from`, crosses to
## the target and goes in behind their box: from the edge on, it is out of
## sight. Then one clean cut across them.
func _stab(play: Play, from: PlayerState) -> void:
	var speed: float = table._speed
	var here := _at(from)
	var there := _at(play.target)
	dim(0.55, 1.35)
	var shade := ShadeFx.new()
	shade.speed = speed
	shade.run(here, there, POT)
	var cover: Control = table._node_of(play.target)
	if cover != null:
		shade.behind = cover.get_global_rect()
	add_child(shade)
	_snd("fx_shade")
	burst(here, ShadeFx.HOOD_LIT, 6, 90.0, 0.3, 0.0, 6.0)
	var move := shade.create_tween()
	move.tween_property(shade, "sunk", 0.0, 0.16 / speed)
	move.tween_property(shade, "travel", 1.0, 0.4 / speed).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	move.tween_property(shade, "sunk", 1.0, 0.12 / speed)
	move.tween_interval(ShadeFx.GHOST_LIFE / speed)
	move.tween_callback(shade.queue_free)
	await _wait(0.56)
	_snd("fx_blade")
	await _wait(0.2)
	line(there + Vector2(-80, -56), there + Vector2(80, 56), Color.WHITE, 7.0, 0.3, 0.06)
	await _wait(0.07)
	burst(there, BLOOD, 22, 260.0, 0.6, 520.0)
	flash(Color(0.6, 0.0, 0.0, 0.3), 0.3)
	table._shake_screen(9.0)
	await _wait(0.4)


## A tune worth stopping for. The Bard's lute comes out beside him and is
## played, its strings shaking and notes drifting up from it, while the coins
## dance over to the tune (table._dance_coins): nobody waits for any of it,
## the match goes on under the music.
func _fx_bard_swindle(play: Play) -> void:
	var speed: float = table._speed
	var here := _at(play.actor)
	var lute := LuteFx.new()
	lute.position = here + (POT - here).limit_length(84.0)
	lute.rotation = -0.5
	lute.scale = Vector2(0.5, 0.5)
	lute.modulate.a = 0.0
	add_child(lute)
	# Which tune is only what this screen hears: the global dice will do.
	var tune: Dictionary = SERENADES.pick_random()
	var notes: Array = tune.notes
	_snd(tune.sound)
	ring(lute.position, UI.GOLD, 10.0, 60.0, 0.4)
	var played := lute.create_tween()
	played.tween_property(lute, "modulate:a", 1.0, 0.12 / speed)
	played.parallel().tween_property(lute, "scale", Vector2.ONE, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# It is put away once the tune has rung out.
	played.tween_interval(SERENADE_LENGTH / speed)
	played.tween_property(lute, "modulate:a", 0.0, 0.4 / speed)
	played.tween_callback(lute.queue_free)
	# Plucked on every note of the tune, and a note of music let go with it.
	for i in notes.size():
		var strike := get_tree().create_timer(maxf(notes[i], 0.01) / speed)
		strike.timeout.connect(_pluck.bind(lute, i, float(tune.long.get(i, 0.0)) / speed))
	await _wait(0.25)


## The lute is plucked for note `index` of the tune: its strings shake (for
## `held` seconds, if the note is one that is held), it tips a little the
## other way, and a note drifts up from it.
func _pluck(lute: LuteFx, index: int, held := 0.0) -> void:
	if not is_instance_valid(lute):
		return
	lute.pluck(held)
	lute.create_tween().tween_property(lute, "rotation", -0.5 + (0.07 if index % 2 == 0 else -0.07), 0.18 / table._speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_note(lute.position, index)


## One note of the tune, let go over `at`.
func _note(at: Vector2, index: int) -> void:
	var note := NoteFx.new()
	note.ink = UI.GOLD if index % 2 == 0 else UI.PURPLE.lightened(0.4)
	note.sway = 1.0 if index % 2 == 0 else -1.0
	note.home = at + Vector2(randf_range(-46.0, 46.0), randf_range(-34.0, -10.0))
	add_child(note)
	var up := note.create_tween().set_parallel()
	up.tween_property(note, "risen", 1.0, 1.1 / table._speed)
	up.tween_property(note, "modulate:a", 0.0, 0.4 / table._speed).set_delay(0.7 / table._speed)
	up.chain().tween_callback(note.queue_free)


## A hand in a white glove slips out of the thief's box and goes for the
## Bard's coins, in no straight line: it looks round, has second thoughts,
## and does the last stretch with its fingers itching. The lute comes down
## on it, and again, swung from the Bard's side towards where the hand came
## from: every blow sweeps it further back along its own path, fingers wide
## and shaking, with the lute coming after it, until it bolts home.
func _fx_bard_silver_tongue(play: Play) -> void:
	var speed: float = table._speed
	var purse: Vector2 = table._coin_anchor(play.actor)
	var thief: Variant = play.event.data.get("thief") if play.event != null else null
	if thief is PlayerState and booting(thief, play.actor):
		# It is a boot that is after them, not a hand.
		await _boot_bonked(play)
		return
	var from := POT
	if thief is PlayerState:
		from = table._clear_of(table._node_of(thief), _at(thief), purse, 0.0)
	if from.distance_to(purse) < GLOVE_SHORT * 2.0:
		from = POT
	var way := (purse - from).normalized()
	var across := way.orthogonal()
	var aim := way.angle()
	# Where it is stopped: its fingers on the coins.
	var reach := purse - way * GLOVE_SHORT
	var glove := GloveFx.new()
	glove.position = from
	glove.rotation = aim
	glove.flipped = way.x < 0.0
	glove.scale = Vector2(0.4, 0.4)
	glove.modulate.a = 0.0
	add_child(glove)
	var move := glove.create_tween()
	move.tween_property(glove, "modulate:a", 1.0, 0.08 / speed)
	move.parallel().tween_property(glove, "scale", Vector2.ONE, 0.16 / speed)
	move.parallel().tween_property(glove, "position", from.lerp(reach, 0.38) + across * 10.0, 0.22 / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# A look to one side and to the other: is anybody watching?
	move.tween_property(glove, "rotation", aim - 0.4, 0.09 / speed)
	move.parallel().tween_property(glove, "fidget", 1.0, 0.05 / speed)
	move.tween_property(glove, "rotation", aim + 0.3, 0.12 / speed)
	move.tween_property(glove, "rotation", aim, 0.07 / speed)
	move.parallel().tween_property(glove, "fidget", 0.0, 0.07 / speed)
	# Further in, and then second thoughts.
	move.tween_property(glove, "position", from.lerp(reach, 0.74) - across * 8.0, 0.18 / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_property(glove, "position", from.lerp(reach, 0.62) - across * 4.0, 0.14 / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move.parallel().tween_property(glove, "spread", 0.5, 0.1 / speed)
	move.tween_interval(0.1 / speed)
	# The last stretch, fingers itching.
	move.tween_property(glove, "position", reach, 0.34 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.parallel().tween_property(glove, "fidget", 1.0, 0.1 / speed)
	move.parallel().tween_property(glove, "spread", 0.0, 0.2 / speed)
	# The lute is held by the neck and swung like a bat, from beside the
	# hand's path: its belly comes round from the Bard's side and sweeps the
	# hand back the way it came. The grip is on whichever side of the path is
	# nearer the middle of the screen, and moves with every blow: it is swung
	# with the whole arm, not turned on a pin.
	var room := get_viewport_rect().grow(-LUTE_ROOM)
	var side := 1.0
	if (reach - across * LUTE_REACH).distance_squared_to(room.get_center()) \
			< (reach + across * LUTE_REACH).distance_squared_to(room.get_center()):
		side = -1.0
	var held := across * side * LUTE_REACH
	var grip := reach + held
	# Turning this way round takes the belly back along the hand's path.
	var turn := side
	var struck := held.angle()
	# How far it is wound back: less, where the belly would leave the screen.
	var lift := LUTE_WIND
	while lift > 0.5 and not room.has_point(grip - Vector2.from_angle(struck - turn * lift) * LUTE_REACH):
		lift -= 0.1
	var raised := struck - turn * lift * 0.7
	var club := Control.new()
	club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	club.position = grip
	club.rotation = raised
	club.modulate.a = 0.0
	var lute := LuteFx.new()
	lute.position = Vector2(LuteFx.BELLY - LUTE_REACH, 0.0)
	club.add_child(lute)
	add_child(club)
	# Every blow drives the hand further back along its own path, a little
	# more each time, and the lute goes after it.
	var spot := reach
	var step := clampf(from.distance_to(reach) / (LUTE_BLOWS + 0.5), 14.0, 60.0)
	await _wait(0.85)
	club.create_tween().tween_property(club, "modulate:a", 1.0, 0.12 / speed)
	await _wait(0.3)
	for knock in LUTE_BLOWS:
		if not is_instance_valid(club) or not is_instance_valid(glove):
			return
		# The last one goes all the way round first, and lands hardest.
		var last := knock == LUTE_BLOWS - 1
		var wind := 0.2 if last else 0.14
		var fall := 0.22 if last else 0.07
		var hard := 1.0 + 0.25 * knock
		grip = spot + held
		# Where the hand is sent, and so where the next one lands.
		var sent := step * (0.7 + 0.3 * knock)
		var back := spot - way * sent
		var swing := club.create_tween()
		swing.tween_property(club, "position", grip + way * (20.0 if last else 12.0), wind / speed) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		swing.parallel().tween_property(club, "rotation", struck - turn * lift, wind / speed) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if last:
			struck += turn * TAU
			raised += turn * TAU
		swing.tween_property(club, "position", grip - way * 6.0, fall / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		swing.parallel().tween_property(club, "rotation", struck, fall / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# It goes on through, pushing the hand ahead of it, and is then drawn
		# back beside where the hand went.
		swing.tween_property(club, "position", grip - way * 14.0, 0.1 / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		swing.parallel().tween_property(club, "rotation", struck + turn * LUTE_SWEEP, 0.1 / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		swing.parallel().tween_property(lute, "scale", Vector2(0.86, 1.18), 0.04 / speed)
		swing.parallel().tween_property(lute, "scale", Vector2.ONE, 0.12 / speed).set_delay(0.04 / speed)
		var after := grip if last else back + held
		swing.tween_property(club, "position", after, 0.25 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		swing.parallel().tween_property(club, "rotation", raised, 0.25 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _wait(wind + fall)
		if not is_instance_valid(glove):
			return
		# A different wreck of a sound for every blow.
		table._play_sfx("fx_lute_bonk_%d" % (knock + 1), "fx_lute_bonk")
		lute.pluck(0.5)
		burst(spot, Color.WHITE, 8 + 4 * knock, 200.0 * hard, 0.3, 400.0, 6.0)
		ring(spot, UI.GOLD, 10.0, 70.0 * hard, 0.25, 5.0)
		# The way it is sent.
		for off: float in [-14.0, 14.0]:
			line(spot + across * off, spot + across * off - way * sent, Color.WHITE, 3.0, 0.22)
		table._shake_screen(5.0 * hard)
		# Squashed against the belly, then back the way it came, stiff,
		# fingers wide and shaking all over.
		move.kill()
		glove.sting = 1.0
		glove.spread = 1.0
		glove.fidget = 1.0
		glove.rotation = aim
		glove.position = spot
		move = glove.create_tween()
		move.tween_property(glove, "position", spot - way * sent * 0.55, 0.05 / speed)
		move.parallel().tween_property(glove, "scale", Vector2(0.65, 1.3), 0.05 / speed)
		move.tween_property(glove, "position", back, 0.14 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		move.parallel().tween_property(glove, "scale", Vector2.ONE, 0.14 / speed)
		move.parallel().tween_property(glove, "sting", 0.0, 0.5 / speed)
		move.tween_callback(_alarm.bind(back))
		for wag: float in [0.3, -0.3, 0.2, 0.0]:
			move.tween_property(glove, "rotation", aim + wag, 0.06 / speed)
		spot = back
		if not last:
			await _wait(0.38)
	# Home it goes, as fast as it can, and he plays it off.
	move.tween_interval(0.12 / speed)
	move.tween_property(glove, "position", from, 0.24 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move.parallel().tween_property(glove, "modulate:a", 0.0, 0.08 / speed).set_delay(0.16 / speed)
	move.tween_callback(glove.queue_free)
	await _wait(0.45)
	_snd("fx_lute_flourish")
	if is_instance_valid(club):
		lute.pluck(0.4)
		_note(reach, 0)
		_note(reach, 1)
		var away := club.create_tween()
		away.tween_interval(0.45 / speed)
		away.tween_property(club, "modulate:a", 0.0, 0.25 / speed)
		away.tween_callback(club.queue_free)
	await _wait(0.5)


## Three short strokes over `at`: whatever is there has had a fright.
func _alarm(at: Vector2) -> void:
	for tilt: float in [-0.6, 0.0, 0.6]:
		var out := Vector2.UP.rotated(tilt)
		line(at + out * 34.0, at + out * 48.0, Color.WHITE, 4.0, 0.3)


func _fx_heir_sold_out(play: Play) -> void:
	await _fireworks(play.actor, 2)


func _fx_heir_party(play: Play) -> void:
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
	await _gavel(play.target, UI.GOLD, true)
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
## Two knocks of the gavel on the box of `who`. With `seals`, the second one
## leaves the seal of the court on it (StatusFx.press_seal).
func _gavel(who: PlayerState, color: Color, seals := false) -> void:
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
		if seals and knock == 1 and box != null:
			box.seal_pressed()
			var spot: Vector2 = box.seal_spot()
			_snd("fx_seal")
			ring(spot, SEAL_WAX.lightened(0.25), 6.0, 34.0, 0.3, 3.0)
			burst(spot, SEAL_WAX.lightened(0.3), 6, 90.0, 0.4, 320.0, 4.0)
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


## Perjury: the gavel is held up over the coins of `who`, at `at`, and comes
## down on them once, hard, with the word. The coins leave for the bank after it.
func perjury(who: PlayerState, at: Vector2) -> void:
	var box: Control = table._node_of(who)
	var speed: float = table._speed
	var gavel := GavelFx.new()
	gavel.position = GavelFx.origin_for(at)
	gavel.rotation = GAVEL_RAISED * 1.25
	gavel.modulate.a = 0.0
	add_child(gavel)
	gavel.create_tween().tween_property(gavel, "modulate:a", 1.0, 0.12 / speed)
	dim(0.35, 0.9)
	await _wait(0.45)
	if not is_instance_valid(gavel):
		return
	gavel.create_tween().tween_property(gavel, "rotation", 0.0, 0.06 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.06)
	_snd("fx_gavel")
	# The word comes down with it (not awaited: the coins do not wait for it).
	table._stamp("PERJURY", UI.GOLD)
	burst(at, UI.GOLD, 16, 260.0, 0.5, 620.0, 6.0)
	burst(at, Color("c9a26a"), 8, 200.0, 0.3, 500.0, 6.0)
	ring(at, UI.GOLD, 12.0, 120.0, 0.32, 6.0)
	if box != null:
		UI.shake(box, 12.0, 0.25)
		box.seal_jolt()
	table._shake_screen(8.0)
	await _wait(0.22)
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
	var item: TextureRect = _sprite(texture, middle, HatFx.ITEM)
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
	drop_boot()
	drop_lasso()
	drop_hat()
	drop_wand()
	drop_tray()
	drop_vault()
	drop_doll()
	drop_bomb()
	drop_hole()
	drop_lurk()
	drop_bets()
	drop_gun()
	drop_paint()
	drop_duel()
	drop_berserk()
	drop_soul()


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
	var item: TextureRect = _sprite(texture, home, item_size)
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


## A long rifle comes out by the Mercenary with its laser still on whoever
## was just hit. It swings over, slowly, to the next one, settles there, and
## only then fires: one round, and a loud one.
func _fx_mercenary_collateral(play: Play) -> void:
	var speed: float = table._speed
	var here := _at(play.actor)
	var there := _at(play.target)
	var first := POT
	if play.event != null and play.event.data.get("target") is PlayerState and play.event.data.target != play.target:
		first = _at(play.event.data.target)
	# Out of whichever edge of the box faces the middle of the table.
	var way := Vector2.DOWN if here.y < POT.y else Vector2.UP
	var rest := here
	var box: Control = table._node_of(play.actor)
	if box != null:
		var rect := box.get_global_rect()
		rest = Vector2(clampf(here.x, rect.position.x + 20.0, rect.end.x - 20.0),
				rect.end.y if way == Vector2.DOWN else rect.position.y)
	var rifle := SniperFx.new()
	rifle.position = rest
	rifle.aim = first
	rifle.modulate.a = 0.0
	add_child(rifle)
	_snd("item_roulette_cock")
	var out := rifle.create_tween().set_parallel()
	out.tween_property(rifle, "modulate:a", 1.0, 0.15 / speed)
	out.tween_property(rifle, "position", rest + way * 30.0, 0.3 / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.4)
	if not is_instance_valid(rifle):
		return
	# The sound lasts as long as the laser takes to find its target.
	_snd("fx_sniper_aim")
	rifle.create_tween().tween_property(rifle, "beam", 1.0, 0.1 / speed)
	await _wait(0.35)
	if not is_instance_valid(rifle):
		return
	rifle.swing_to(there, POT)
	rifle.create_tween().tween_property(rifle, "swing", 1.0, 0.9 / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.9)
	ring(there, SniperFx.LASER, 70.0, 8.0, 0.28, 3.0)
	await _wait(0.3)
	if not is_instance_valid(rifle):
		return

	_snd("fx_sniper")
	var muzzle := rifle.muzzle()
	rifle.beam = 0.0
	flash(Color(1.0, 0.97, 0.85, 0.45), 0.18)
	line(muzzle, there, Color.WHITE, 10.0, 0.16)
	line(muzzle, there, Color("ffe9a0"), 4.0, 0.45)
	burst(muzzle, Color("ffd060"), 14, 260.0, 0.3)
	ring(muzzle, Color("ffe9a0"), 8.0, 60.0, 0.2, 6.0)
	burst(there, BLOOD, 22, 320.0, 0.6, 500.0)
	burst(there, STEEL, 8, 240.0, 0.4, 400.0)
	ring(there, Color.WHITE, 10.0, 150.0, 0.35, 6.0)
	ring(there, BLOOD, 10.0, 90.0, 0.5, 4.0)
	table._shake_screen(14.0)
	# The rifle is thrown back and its barrel up, and comes down again.
	var home := rifle.position
	var recoil := rifle.create_tween()
	recoil.tween_property(rifle, "position", home - Vector2.from_angle(rifle.rotation) * 22.0, 0.05 / speed)
	recoil.tween_property(rifle, "position", home, 0.4 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rifle.kick = 0.3
	rifle.create_tween().tween_property(rifle, "kick", 0.0, 0.45 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.8)
	if not is_instance_valid(rifle):
		return
	var away := rifle.create_tween()
	away.tween_property(rifle, "modulate:a", 0.0, 0.2 / speed)
	away.tween_callback(rifle.queue_free)
	await _wait(0.2)


## The vault is set down by the Mythomaniac, its wheel is spun and the door
## swings open on everything nobody caught. It stays open: the coins of the
## Cash Out fly out of it (table._anim_coins asks vault_mouth), and it is
## shut and taken away when the play is over (put_away).
func _fx_mythomaniac_cash_out(play: Play) -> void:
	drop_vault()
	var speed: float = table._speed
	var here := _at(play.actor)
	var vault := VaultFx.new()
	vault.position = here + (POT - here).limit_length(100.0)
	vault.scale = Vector2(0.6, 0.6)
	vault.modulate.a = 0.0
	add_child(vault)
	_vault = vault
	_vault_owner = play.actor
	_snd("fx_vault")
	var down := vault.create_tween().set_parallel()
	down.tween_property(vault, "modulate:a", 1.0, 0.12 / speed)
	down.tween_property(vault, "scale", Vector2.ONE, 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The wheel turns with the clicks of the sound, slower and slower.
	down.tween_property(vault, "spin", 7.0, 0.5 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.52)
	if not is_instance_valid(vault):
		return
	vault.create_tween().tween_property(vault, "open", 1.0, 0.4 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.34)
	if not is_instance_valid(vault):
		return
	ring(vault.mouth(), UI.GOLD, 10.0, 80.0, 0.35, 5.0)
	burst(vault.mouth(), UI.GOLD, 12, 190.0, 0.5, 420.0)
	await _wait(0.2)


## Where coins come out of the vault `who` has open, Vector2.INF if none.
func vault_mouth(who: PlayerState) -> Vector2:
	if _vault != null and is_instance_valid(_vault) and _vault_owner == who:
		return _vault.mouth()
	return Vector2.INF


## Shuts the vault and takes it away.
func drop_vault() -> void:
	if _vault != null and is_instance_valid(_vault):
		var speed: float = table._speed
		var shut := _vault.create_tween()
		shut.tween_property(_vault, "open", 0.0, 0.16 / speed)
		shut.tween_property(_vault, "modulate:a", 0.0, 0.18 / speed)
		shut.tween_callback(_vault.queue_free)
	_vault = null
	_vault_owner = null


## The Spy's shadow, hat and all, stretches out of his box across the table
## towards the hand of whoever is being peeked at, slowly, and stops short
## of it to look left and right. There it waits: which card it takes is only
## known in card_peeked (card_snatched).
func _fx_spy_sneak_peek(play: Play) -> void:
	drop_lurk()
	if play.target == null:
		return
	var speed: float = table._speed
	var lurk := _lurk_out(play.actor, _hand_middle(play.target))
	_lurk = lurk
	_lurk_owner = play.actor
	_snd("fx_creep")
	lurk.create_tween().tween_property(lurk, "length", lurk.span, LURK_CREEP / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(LURK_CREEP + 0.08)
	if not is_instance_valid(lurk):
		return
	# Is anybody watching?
	var look := lurk.create_tween()
	look.tween_property(lurk, "peer", -1.0, 0.12 / speed)
	look.tween_interval(0.12 / speed)
	look.tween_property(lurk, "peer", 1.0, 0.16 / speed)
	look.tween_interval(0.12 / speed)
	look.tween_property(lurk, "peer", 0.0, 0.1 / speed)
	await _wait(0.64)


## A shadow for `who`, still under their box, to be sent out towards `at`.
func _lurk_out(who: PlayerState, at: Vector2) -> LurkFx:
	var lurk := LurkFx.new()
	# From under the box itself: whatever of it the box covers is not drawn.
	lurk.position = _at(who)
	var box: Control = table._node_of(who)
	if box != null:
		lurk.behind = box.get_global_rect()
	lurk.aim(at, LURK_SHY)
	add_child(lurk)
	return lurk


## The middle of the cards `p` holds, as they lie on the table.
func _hand_middle(p: PlayerState) -> Vector2:
	if p.cards.is_empty():
		return _at(p)
	return (table._card_center(p, 0) + table._card_center(p, p.cards.size() - 1)) / 2.0


## The peek itself (`d` is the data of card_peeked): an arm comes out of the
## shadow, takes the card by its edge and lifts it off its place; it is
## held up and put back, the arm going with it all the way, and the shadow
## slides home. The player at this screen sees its face when the look is
## theirs, for as long as they like (a button says they have seen it);
## everybody else sees its back, tipped towards the shadow, for a moment.
func card_snatched(d: Dictionary) -> void:
	var peeker: PlayerState = d.viewer
	var owner: PlayerState = d.owner
	var speed: float = table._speed
	var asks: bool = peeker == table.viewer
	var mine: bool = owner == table.viewer
	var view: CardView = table._card_view(owner, d.index)
	var from: Vector2 = table._card_center(owner, d.index)
	var small: float = (view.size.x if view != null else 44.0) / CardView.BASE.x
	var lurk := _lurk
	if lurk == null or not is_instance_valid(lurk) or _lurk_owner != peeker:
		# Nobody saw it coming (a peek turned round by a Mirror).
		drop_lurk()
		lurk = _lurk_out(peeker, from)
		lurk.create_tween().tween_property(lurk, "length", lurk.span, 0.35 / speed) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await _wait(0.4)
		if not is_instance_valid(lurk):
			return
	_lurk = null
	_lurk_owner = null
	# The arm goes for the near edge of the card: fast, but there to be seen.
	var way := (from - lurk.head()).normalized()
	lurk.reach_for(from - way * minf(CardView.BASE.y * small * 0.4, from.distance_to(lurk.head()) * 0.5))
	_snd("fx_snatch")
	lurk.create_tween().tween_property(lurk, "arm", 1.0, LURK_REACH / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(LURK_REACH + 0.06)
	if not is_instance_valid(lurk):
		return
	# The card hangs from two nodes: one carries it and sizes it, the other
	# tips it (see table._lean_card).
	var mover := Node2D.new()
	mover.position = from
	mover.scale = Vector2.ONE * small
	add_child(mover)
	var tilt := Node2D.new()
	mover.add_child(tilt)
	var card := CardView.new()
	card.interactive = false
	card.tips = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = -CardView.BASE / 2.0
	# Out of the hand on screen it leaves as it was there: face up.
	card.set_card(d.card if mine else &"", mine)
	tilt.add_child(card)
	table._set_cards_shown([view], false)
	_snd("card_draw")
	# The arm goes where the card goes, from here until it is put down.
	lurk.carried = mover
	# Lifted off its place: a little towards the shadow for the table. For
	# the player who is looking it is drawn over beside the hat, on the side
	# of the middle of the table, where it can be read and hides neither
	# the shadow nor the arm that holds it.
	var big := LURK_SHOWN if asks else small * LURK_SHOWN_AWAY
	var held := from - way * LURK_LIFTED_AWAY
	if asks:
		var aside := way.orthogonal()
		if (lurk.head() + aside).distance_to(POT) > (lurk.head() - aside).distance_to(POT):
			aside = -aside
		var half := CardView.BASE * big / 2.0
		var room := minf(half.x / maxf(absf(aside.x), 0.001), half.y / maxf(absf(aside.y), 0.001))
		held = lurk.head() - way * 20.0 + aside * (room + LURK_LIFTED)
		# With room under it for the button that says it has been seen.
		held = held.clamp(half + Vector2(8, 8), Vector2(size.x - 8.0, 420.0) - half)
	var lift := mover.create_tween().set_parallel()
	lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(mover, "position", held, LURK_LIFT / speed)
	lift.tween_property(mover, "scale", Vector2.ONE * big, LURK_LIFT / speed)
	if asks:
		card.set_card(d.card, true, true)
	else:
		# Its face goes to the shadow: turned away from everyone else.
		card.set_card(&"", false, true)
		mover.create_tween().tween_method(table._lean_card.bind(tilt, -way), 0.0, 1.0, LURK_LIFT / speed)
	await _wait(LURK_LIFT)
	if asks:
		# It stays up until the player says they have seen it.
		var ok := UI.button("Got it", UI.GOLD, 16)
		table._modal.add_child(ok)
		ok.reset_size()
		# Always under the card.
		ok.position = held + Vector2(-ok.size.x / 2.0, CardView.BASE.y * big / 2.0 + 10.0)
		await ok.pressed
		if table.engine.aborted:
			return
		ok.queue_free()
	else:
		await _wait(LURK_GLANCE)
	if not is_instance_valid(mover):
		return
	# Back where it was, as if nothing had happened.
	if asks:
		card.set_card(&"", false, true)
	else:
		mover.create_tween().tween_method(table._lean_card.bind(tilt, -way), 1.0, 0.0, LURK_RETURN / speed)
		if mine:
			card.set_card(d.card, true, true)
	var back := mover.create_tween().set_parallel()
	back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(mover, "position", from, LURK_RETURN / speed)
	back.tween_property(mover, "scale", Vector2.ONE * small, LURK_RETURN / speed)
	await _wait(LURK_RETURN)
	_snd("card_draw")
	table._set_cards_shown([view], true)
	if is_instance_valid(lurk):
		lurk.carried = null
	if is_instance_valid(mover):
		mover.queue_free()
	if not is_instance_valid(lurk):
		return
	_slink(lurk)
	await _wait(LURK_HOME)


## Sends home a shadow that took nothing.
func drop_lurk() -> void:
	if _lurk != null and is_instance_valid(_lurk):
		_slink(_lurk)
	_lurk = null
	_lurk_owner = null


## The shadow draws its arm in and slides back under the box it came from.
func _slink(lurk: LurkFx) -> void:
	var speed: float = table._speed
	var leave := lurk.create_tween()
	leave.tween_property(lurk, "arm", 0.0, 0.1 / speed)
	leave.tween_property(lurk, "length", 0.0, (LURK_HOME - 0.1) / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.tween_callback(lurk.queue_free)


## An Untraceable: the hand of the Spy goes up in smoke, and stays gone
## until whatever came for it has missed (hand_missed: hand_found).
func _fx_spy_untraceable(play: Play) -> void:
	# It is their items that were being reached for, not their hand.
	if play.event != null and play.event.type == &"before_item_reach":
		await vanish_items(play.actor)
	else:
		await vanish(play.actor)


## The items `who` holds disappear from their box in a puff of smoke, until
## whatever came for them has missed (items_missed: items_found).
func vanish_items(who: PlayerState) -> void:
	var box: Variant = table._node_of(who)
	if who == null or box == null or _hidden_items.has(who.id):
		return
	_hidden_items[who.id] = true
	_snd("fx_hush")
	_puff_items(who)
	await _wait(0.1)
	box.set_items_shown(false)
	await _wait(0.4)


## The items of `who` are back where they were, out of another puff.
func items_found(who: PlayerState) -> void:
	if who == null or not _hidden_items.has(who.id):
		return
	_hidden_items.erase(who.id)
	var box: Variant = table._node_of(who)
	if box == null:
		return
	_snd("fx_hush")
	_puff_items(who)
	await _wait(0.1)
	box.set_items_shown(true)
	await _wait(0.3)


func _puff_items(who: PlayerState) -> void:
	var points: Array = []
	for i: int in who.items.size():
		points.append(table._item_spot(who, i))
	_smoke(points, 22.0 if who == table.viewer else 12.0, 12)


func vanished(who: PlayerState) -> bool:
	return who != null and _vanished.has(who.id)


## The cards `who` holds disappear from the table in a puff of smoke.
func vanish(who: PlayerState) -> void:
	if who == null or vanished(who) or who.cards.is_empty():
		return
	var views: Array = []
	for i: int in who.cards.size():
		views.append(table._card_view(who, i))
	_vanished[who.id] = views
	_snd("fx_hush")
	_puff(who, views)
	await _wait(0.1)
	table._set_cards_shown(views, false)
	await _wait(0.4)


## The cards of `who` are back where they were, out of another puff.
func hand_found(who: PlayerState) -> void:
	if not vanished(who):
		return
	var views: Array = _vanished[who.id]
	_vanished.erase(who.id)
	_snd("fx_hush")
	_puff(who, views)
	await _wait(0.1)
	table._set_cards_shown(views, true)
	for view: Variant in views:
		if view != null and is_instance_valid(view):
			UI.pop(view, 1.12, 0.2)
	await _wait(0.3)


## Every hand that is still gone comes back out of its puff of smoke, all
## at once and without holding anything up.
func bring_back() -> void:
	for id: int in _vanished.keys():
		for p: PlayerState in table.engine.players:
			if p.id == id:
				hand_found(p)


## Puts back every hand that is still gone, at once and with no show.
func drop_vanished() -> void:
	for views: Array in _vanished.values():
		table._set_cards_shown(views, true)
	_vanished.clear()
	for id: int in _hidden_items.keys():
		var box: Variant = table._node_of(table.engine.player_by_id(id))
		if box != null:
			box.set_items_shown(true)
	_hidden_items.clear()


## Smoke over each of the cards of `who`: a thick cloud that hangs and
## thins out upwards.
func _puff(who: PlayerState, views: Array) -> void:
	for i: int in views.size():
		var view: Variant = views[i]
		if view == null or not is_instance_valid(view):
			continue
		_smoke([table._card_center(who, i)], view.size.y * 0.5, 22)


## A cloud of `count` puffs over each of `points`, `reach` px tall.
func _smoke(points: Array, reach: float, count: int) -> void:
	for at: Vector2 in points:
		for n: int in count:
			var off := Vector2(randf_range(-0.5, 0.5) * reach * 0.7, randf_range(-1.0, 1.0) * reach * 0.8)
			_bits.append({
				"p": at + off, "v": off * 1.6 + Vector2(randf_range(-20, 20), -randf_range(15, 55)),
				"g": -50.0, "c": SMOKE.lightened(randf_range(0.3, 0.75)),
				"s": randf_range(0.28, 0.5) * reach, "t": -randf_range(0.0, 0.1), "life": randf_range(0.45, 0.85),
			})
	_wake()


## A Sneak Peek at a hand that is not there (`d` is the data of
## hand_missed): the shadow reaches for a card, closes its hand on nothing,
## feels around, looks about with question marks over its hat and is gone
## in a hurry.
func lurk_fooled(d: Dictionary) -> void:
	var peeker: PlayerState = d.by
	var owner: PlayerState = d.owner
	var speed: float = table._speed
	var at := _hand_middle(owner)
	# A hand that came back in the meantime (its card proven to a doubter)
	# is gone again before the shadow gets to it.
	await vanish(owner)
	var lurk := _lurk
	if lurk == null or not is_instance_valid(lurk) or _lurk_owner != peeker:
		drop_lurk()
		lurk = _lurk_out(peeker, at)
		lurk.create_tween().tween_property(lurk, "length", lurk.span, 0.35 / speed) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await _wait(0.4)
		if not is_instance_valid(lurk):
			return
	_lurk = null
	_lurk_owner = null
	var way := (at - lurk.head()).normalized()
	var side := way.orthogonal()
	# The grab, on the place where a card ought to be.
	lurk.reach_for(at)
	_snd("fx_snatch")
	lurk.create_tween().tween_property(lurk, "arm", 1.0, LURK_REACH / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(LURK_REACH + 0.22)
	# Nothing in the hand: it feels around, to one side and to the other.
	for step: float in [-1.0, 1.0]:
		if not is_instance_valid(lurk):
			return
		var grope := lurk.create_tween()
		grope.tween_property(lurk, "arm", 0.55, 0.09 / speed)
		grope.tween_callback(lurk.reach_for.bind(at + side * step * LURK_GROPE))
		grope.tween_property(lurk, "arm", 1.0, 0.11 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await _wait(0.2)
		_snd("card_draw")
		await _wait(0.14)
	if not is_instance_valid(lurk):
		return
	# And looks about, at a loss.
	lurk.create_tween().tween_property(lurk, "arm", 0.0, 0.14 / speed)
	var look := lurk.create_tween()
	look.tween_property(lurk, "peer", -1.0, 0.1 / speed)
	look.tween_interval(0.2 / speed)
	look.tween_property(lurk, "peer", 1.0, 0.14 / speed)
	look.tween_interval(0.2 / speed)
	look.tween_property(lurk, "peer", 0.0, 0.1 / speed)
	_snd("fx_puzzled")
	var over_hat := lurk.head() - way * 26.0
	for i: int in LURK_PUZZLED:
		_puzzle(over_hat + side * (i - (LURK_PUZZLED - 1) / 2.0) * 22.0 - way * (10.0 if i == 1 else 0.0),
				i * 0.13, 0.95 - i * 0.13)
	await _wait(0.95)
	if not is_instance_valid(lurk):
		return
	# Home, and fast.
	var leave := lurk.create_tween()
	leave.tween_property(lurk, "length", 0.0, LURK_FLEE / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.tween_callback(lurk.queue_free)
	await _wait(LURK_FLEE + 0.05)


## A question mark that pops up at `at` after `delay`, wobbles for `life`
## seconds and is gone.
func _puzzle(at: Vector2, delay: float, life: float) -> void:
	var speed: float = table._speed
	var mark := UI.label("?", 30, PORCELAIN, true)
	mark.add_theme_constant_override("outline_size", 6)
	mark.add_theme_color_override("font_outline_color", UI.INK)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)
	mark.reset_size()
	mark.pivot_offset = mark.size / 2.0
	mark.position = (at - mark.size / 2.0).clamp(Vector2(6, 6), size - mark.size - Vector2(6, 6))
	mark.scale = Vector2.ZERO
	mark.rotation = randf_range(-0.3, 0.3)
	var show := mark.create_tween()
	show.tween_interval(delay / speed)
	show.tween_property(mark, "scale", Vector2.ONE, 0.14 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(mark, "rotation", -mark.rotation, maxf(life - 0.3, 0.1) / speed).set_trans(Tween.TRANS_SINE)
	show.parallel().tween_property(mark, "position:y", mark.position.y - 8.0, maxf(life - 0.3, 0.1) / speed)
	show.tween_property(mark, "modulate:a", 0.0, 0.14 / speed)
	show.tween_callback(mark.queue_free)


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


## Only a rag doll, for now: it is shown in the Voodooist's hand and tossed
## underhand at the target, tumbling over in the air. It strikes the top
## corner of their box, slides down the side and stays slumped there, asleep,
## until the hex takes hold (the table then swaps it for the player's own:
## doll_thrown_at). Nothing magic about any of it: the doll only wakes up
## later, if nobody breaks it (see the doll_awake note, at the table).
func _fx_voodooist_hex(play: Play) -> void:
	drop_doll()
	var speed: float = table._speed
	var here := _at(play.actor)
	var there := _at(play.target)
	# It strikes the top corner of the box and slides down to where it sits.
	var hit := there + Vector2(70, -50)
	var rest := there + Vector2(70, 50)
	var box: Control = table._node_of(play.target)
	if box != null and box.has_method("doll_way"):
		var way: Array[Vector2] = box.doll_way()
		hit = way[0]
		rest = way[1]
	var held := here + (POT - here).limit_length(48.0)
	var doll := VoodooDoll.new()
	doll.awake = 0.0
	if box != null and box.has_method("doll_facing"):
		doll.facing = box.doll_facing()
		doll.hangs = box.doll_hangs()
	doll.position = held + Vector2(0, 10)
	doll.scale = Vector2(0.6, 0.6)
	doll.modulate.a = 0.0
	add_child(doll)
	_doll = doll
	_doll_target = play.target
	var show := doll.create_tween().set_parallel()
	show.tween_property(doll, "modulate:a", 1.0, 0.12 / speed)
	show.tween_property(doll, "position", held, 0.2 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	show.tween_property(doll, "scale", Vector2.ONE, 0.2 / speed)
	await _wait(0.4)
	if not is_instance_valid(doll):
		return
	# Underhand, in a high arc, turning over once on the way.
	_snd("fx_doll_toss")
	doll.thrown = true
	var arc := 50.0 + held.distance_to(hit) * 0.18
	var turns := -doll.facing
	var toss := func(t: float) -> void:
		doll.position = held.lerp(hit, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))
		doll.rotation = turns * TAU * t
	doll.create_tween().tween_method(toss, 0.0, 1.0, 0.5 / speed)
	await _wait(0.5)
	if not is_instance_valid(doll):
		return
	doll.rotation = 0.0
	doll.thrown = false
	_snd("fx_doll_hit")
	burst(hit, Color("a08a62"), 6, 90.0, 0.3, 260.0, 4.0)
	table._shake_screen(3.0)
	# And down the side of the box, coming to rest slumped against it.
	doll.create_tween().tween_property(doll, "position", rest, 0.5 / speed) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await _wait(0.55)
	if is_instance_valid(doll) and box != null:
		doll.drain = box.get_global_rect().get_center() - rest


## The Voodooist pulls on her strings: a thread runs from her to every doll
## of hers that is awake, and each one jerks where it sits. What each doll
## does comes after, one at a time (curse_flush, item_hexed, and the doll's
## cut of the coins at the table, table._anim_hex_cut).
func _fx_voodooist_puppet_strings(play: Play) -> void:
	_strings = play.actor
	var here := _at(play.actor)
	_snd("fx_hex")
	dim(0.35, 1.1)
	rise(here, UI.PURPLE, 10, 40.0)
	for p: PlayerState in table.engine.players:
		var status: Dictionary = p.statuses.get(&"hexed", {})
		if not p.alive or status.get("by", -1) != play.actor.id or not status.get("awake", false):
			continue
		var doll := _doll_on(p)
		if doll == null:
			continue
		var at := doll.get_global_transform() * doll.heart()
		line(here, at, Color(UI.PURPLE.lightened(0.5), 0.8), 2.0, 0.9, 0.3)
		ring(at, UI.PURPLE.lightened(0.3), 50.0, 8.0, 0.35, 3.0)
		var jerk := doll.create_tween()
		jerk.tween_interval(0.3 / table._speed)
		jerk.tween_property(doll, "stagger", 0.7, 0.12 / table._speed)
		jerk.tween_property(doll, "stagger", 0.0, 0.5 / table._speed)
	await _wait(0.9)


## Whether `who` is pulling the strings of their dolls right now.
func pulling_strings(who: PlayerState) -> bool:
	return _strings != null and _strings == who


## The strings are let go. Puppet Strings is no claim, so no claim_resolved
## puts them away: the table does it when the turn ends (it ends the turn).
func cut_strings() -> void:
	_strings = null


## The doll pinned on `p`, as it shows in their box, or null.
func _doll_on(p: PlayerState) -> VoodooDoll:
	var box: Variant = table._node_of(p)
	if box == null or not box.has_method("doll_node"):
		return null
	return box.doll_node() as VoodooDoll


## The box of `p` on screen, scale and all.
func _box_rect(p: PlayerState) -> Rect2:
	var box: Control = table._node_of(p)
	if box == null:
		return Rect2(_at(p) - Vector2(60, 40), Vector2(120, 80))
	var onto := box.get_global_transform()
	return Rect2(onto * Vector2.ZERO, box.size * onto.get_scale())


## A doll's curse coming down on whoever carries it. The doll feeds, hard:
## the purple is torn out of their box in a rush, and the box itself is drawn
## in towards the doll, twisting and shimmering (WarpFx); then the doll lets
## go, and the picture of the box is flung back out in a glittering wave. The
## blow itself follows (table._anim_damage).
func curse_flush(victim: PlayerState) -> void:
	var speed: float = table._speed
	var rect := _box_rect(victim)
	var doll := _doll_on(victim)
	var heart := doll.get_global_transform() * doll.heart() if doll != null else rect.get_center()
	_snd("fx_hex_flush")
	dim(0.45, 1.9)
	# Bigger than the box: the bending eases off outside it, to nothing.
	var warp := WarpFx.new(rect.grow(WARP_FEATHER), heart, rect.size.length() * 0.6, WARP_FEATHER * 1.6)
	add_child(warp)
	# Its own look, not the one shared under the effects (see _share_look).
	warp.use_parent_material = false
	if doll != null:
		doll.create_tween().tween_property(doll, "hunger", 1.0, 0.9 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	warp.create_tween().tween_property(warp, "pull", 1.0, 0.9 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	stream(rect.get_center(), heart, UI.PURPLE.lightened(0.35), 16, 0.35, 0.8)
	await _wait(0.4)
	stream(rect.get_center() + Vector2(-rect.size.x * 0.3, 0), heart, UI.PURPLE.lightened(0.15), 10, 0.3, 0.4)
	stream(rect.get_center() + Vector2(rect.size.x * 0.3, 0), heart, UI.PURPLE.lightened(0.15), 10, 0.3, 0.4)
	await _wait(0.6)
	# Let go: the box snaps back out, in a wave.
	if doll != null and is_instance_valid(doll):
		doll.create_tween().tween_property(doll, "hunger", 0.0, 0.35 / speed)
	flash(Color(0.6, 0.3, 0.9, 0.2), 0.3)
	if is_instance_valid(warp):
		warp.strength = 1.0
		var release := warp.create_tween().set_parallel()
		release.tween_property(warp, "pull", 0.0, 0.12 / speed)
		release.tween_property(warp, "wave", 1.0, 0.6 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		release.tween_property(warp, "strength", 0.0, 0.6 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		release.chain().tween_callback(warp.queue_free)
	await _wait(0.5)


## A doll dragging an item over to itself, sick with the effort: it totters
## and lurches where it sits, and the item comes away from its place
## (`item_at`) in fits and starts, wobbling, shrinking and going purple as it
## goes, until the doll has it. Then the doll lets go and the item is borne
## off to `home`, its place in the inventory of the doll's owner, on a trail
## of motes. `caught` is called as the item leaves its place.
func item_hexed(victim: PlayerState, texture: Texture2D, item_at: Vector2, home: Vector2, caught: Callable) -> void:
	var speed: float = table._speed
	var doll := _doll_on(victim)
	var heart := doll.get_global_transform() * doll.heart() if doll != null else item_at + Vector2(50, 30)
	_snd("fx_hex_lurch")
	if doll != null:
		doll.create_tween().tween_property(doll, "stagger", 1.0, 0.3 / speed)
	await _wait(0.3)
	caught.call()
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
	ring(item_at, UI.PURPLE.lightened(0.3), 6.0, 32.0, 0.25, 3.0)
	# In fits and starts: a tug, a wobble, a stop, and a little slipped back.
	var tugs := 4
	for i: int in tugs:
		if not is_instance_valid(item):
			return
		var t := float(i + 1) / tugs
		var goal := item_at.lerp(heart, t) + Vector2(randf_range(-10, 10), randf_range(-8, 8)) * (1.0 - t)
		var tug := item.create_tween().set_parallel()
		tug.tween_property(item, "position", goal - item_size / 2.0, 0.16 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tug.tween_property(item, "rotation", randf_range(-0.5, 0.5), 0.16 / speed)
		tug.tween_property(item, "scale", Vector2.ONE * lerpf(1.0, 0.45, t), 0.16 / speed)
		tug.tween_property(item, "modulate", Color.WHITE.lerp(UI.PURPLE.lightened(0.5), t), 0.16 / speed)
		stream(goal, heart, UI.PURPLE.lightened(0.3), 4, 0.2, 0.1)
		await _wait(0.16)
		if i < tugs - 1 and is_instance_valid(item):
			item.create_tween().tween_property(item, "position", item.position + (item_at - heart).normalized() * 5.0, 0.12 / speed)
			await _wait(0.14)
	if not is_instance_valid(item):
		return
	# Swallowed, for a moment.
	item.hide()
	burst(heart, UI.PURPLE.lightened(0.2), 8, 90.0, 0.3, -30.0, 5.0)
	if doll != null and is_instance_valid(doll):
		doll.create_tween().tween_property(doll, "stagger", 0.35, 0.2 / speed)
	await _wait(0.22)
	if not is_instance_valid(item):
		return
	# Let go, and carried off on a wide bend to its new owner.
	item.show()
	var bend := heart.lerp(home, 0.5) + (home - heart).orthogonal().normalized() * heart.distance_to(home) * 0.25
	var carry := func(t: float) -> void:
		var at := heart.lerp(bend, t).lerp(bend.lerp(home, t), t)
		item.position = at - item_size / 2.0
		item.rotation = lerpf(item.rotation, 0.0, t)
		item.scale = Vector2.ONE * lerpf(0.45, 1.0, t)
		item.modulate = UI.PURPLE.lightened(0.5).lerp(Color.WHITE, t * t)
		if randf() < 0.5:
			burst(at, UI.PURPLE.lightened(0.3), 1, 25.0, 0.45, -20.0, 5.0)
	item.create_tween().tween_method(carry, 0.0, 1.0, 0.55 / speed)
	await _wait(0.57)
	_snd("item_get")
	if is_instance_valid(item):
		UI.pop(item, 1.4, 0.2)
	if doll != null and is_instance_valid(doll):
		doll.create_tween().tween_property(doll, "stagger", 0.0, 0.5 / speed)
	await _wait(0.2)
	if is_instance_valid(item):
		item.queue_free()


## A doll reaching for items that are not there (an Untraceable): it
## totters, grasping at nothing, and settles again.
func doll_missed(victim: PlayerState, at: Vector2) -> void:
	var doll := _doll_on(victim)
	_snd("fx_hex_lurch")
	if doll != null:
		var fit := doll.create_tween()
		fit.tween_property(doll, "stagger", 1.0, 0.25 / table._speed)
		fit.tween_interval(0.4 / table._speed)
		fit.tween_property(doll, "stagger", 0.0, 0.4 / table._speed)
	burst(at, SMOKE.lightened(0.4), 6, 70.0, 0.35, -30.0, 7.0)
	table._float(Loc.t("NOTHING THERE"), at, UI.MUTED, 16)
	await _wait(0.8)


## Whether the doll thrown at `who` is lying where it landed. The table asks
## when the hex takes hold: the player's own doll (StatusFx) is then shown in
## its place, and this one is taken away with drop_doll(true).
func doll_thrown_at(who: PlayerState) -> bool:
	return _doll != null and is_instance_valid(_doll) and _doll_target == who


## Takes the thrown doll away: at once (`swapped`, another is in its place)
## or fading, if the hex never took hold.
func drop_doll(swapped := false) -> void:
	if _doll != null and is_instance_valid(_doll):
		if swapped:
			_doll.queue_free()
		else:
			var leave := _doll.create_tween()
			leave.tween_property(_doll, "modulate:a", 0.0, 0.2 / table._speed)
			leave.tween_callback(_doll.queue_free)
	_doll = null
	_doll_target = null


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
	if play.aimed() != play:
		corrupt(play)
	await _wait(0.5)


## From here on every effect is seen and heard wrong, until cleanse(): what
## the Impostor does behind the mask is somebody else's action, badly copied.
## Without a disguise it is what a borrowed action left behind coming due
## (the chains of a copied Entropy breaking), until cleanse() just the same.
func corrupt(disguise: Play = null) -> void:
	cleanse()
	_glitch = GlitchFx.new(self)
	_glitch.disguise = disguise
	add_child(_glitch)


## The table as it is again.
func cleanse() -> void:
	if _glitch != null and is_instance_valid(_glitch):
		_glitch.fade()
	_glitch = null
	_guests.clear()


## Another play comes on in the middle of a borrowed action (a reaction to
## it, say): that one is the real thing, so the borrowed look is held back
## until step_out(). What it puts on the table stays clean for good.
func step_in(play: Play) -> void:
	if _glitch == null or not is_instance_valid(_glitch) or _borrowed(play) or _guests.has(play):
		return
	_guests.append(play)
	_glitch.hush()


## `play` is over: the borrowed action is the one on the table again.
func step_out(play: Play) -> void:
	if not _guests.has(play):
		return
	_guests.erase(play)
	if _guests.is_empty() and _glitch != null and is_instance_valid(_glitch):
		_glitch.resume()


## Whether what happens on the table right now is the doing of a borrowed
## action, and not of a play that stepped in on it.
func borrowing() -> bool:
	return _glitch != null and is_instance_valid(_glitch) and _guests.is_empty()


# Whether `play` is the disguise that is on, or the action it carries out.
func _borrowed(play: Play) -> bool:
	if _glitch == null or _glitch.disguise == null:
		return false
	return play == _glitch.disguise or play == _glitch.disguise.aimed()


## Chips pushed forward; the coin itself is flown by coin_flip.
func _fx_gambler_double_down(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_chips")
	burst(here, CHIP_RED, 6, 120.0, 0.35, 420.0)
	burst(here, CHIP_GREEN, 6, 120.0, 0.35, 420.0)
	await _wait(0.3)


## The stake of a side bet: a few banknotes counted down beside the
## Gambler's box, and a coin set on them to keep them from blowing away.
## They lie there until the doubt is settled (bet_settled).
func _fx_gambler_side_bet(play: Play) -> void:
	var who := play.actor
	var speed: float = table._speed
	_take_bet(who)
	var here := _at(who)
	var bills := BillsFx.new()
	bills.position = _beside(who, BET_REACH)
	add_child(bills)
	_bets[who.id] = bills
	_snd("fx_bills")
	for i in BillsFx.NOTES:
		bills.deal(i, here - bills.position, 0.13 * i / speed, 0.17 / speed)
	await _wait(0.13 * BillsFx.NOTES + 0.13)
	if not is_instance_valid(bills):
		return
	bills.create_tween().tween_property(bills, "coin", 1.0, 0.13 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.13)
	if not is_instance_valid(bills):
		return
	# The coin lands: the notes give under it.
	bills.press = 1.0
	bills.create_tween().tween_property(bills, "press", 0.0, 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.25)


## True while `who` has a side bet lying on the table.
func betting(who: PlayerState) -> bool:
	var bills: Variant = _bets.get(who.id)
	return bills != null and is_instance_valid(bills)


## The doubt `who` bet on is settled: a bet that won is swept back into
## their box, one that lost is raked in by the house.
func bet_settled(who: PlayerState, won: bool) -> void:
	if not betting(who):
		_bets.erase(who.id)
		return
	var speed: float = table._speed
	var bills: BillsFx = _bets[who.id]
	_bets.erase(who.id)
	var to: Vector2 = _at(who) if won else table._bank()
	var time := 0.28 if won else 0.46
	_snd("fx_cash" if won else "fx_chips")
	var go := bills.create_tween()
	if won:
		# Picked up first: a little hop before it is pulled in.
		go.tween_property(bills, "position", bills.position + (bills.position - to).normalized() * 8.0, 0.09 / speed)
	go.tween_property(bills, "position", to, time / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if won else Tween.EASE_IN_OUT)
	go.parallel().tween_property(bills, "scale", Vector2.ONE * 0.55, time / speed)
	go.parallel().tween_property(bills, "modulate:a", 0.0, 0.1 / speed).set_delay((time - 0.1) / speed)
	go.tween_callback(bills.queue_free)
	await _wait(time + (0.09 if won else 0.0))


## Takes the bets nobody settled off the table.
func drop_bets() -> void:
	for id: int in _bets.keys():
		_fade_bet(_bets[id])
	_bets.clear()


func _take_bet(who: PlayerState) -> void:
	if _bets.has(who.id):
		_fade_bet(_bets[who.id])
		_bets.erase(who.id)


func _fade_bet(bills: Variant) -> void:
	if bills != null and is_instance_valid(bills):
		var fade: Tween = bills.create_tween()
		fade.tween_property(bills, "modulate:a", 0.0, 0.2 / table._speed)
		fade.tween_callback(bills.queue_free)


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


## A drink is poured in front of the Bartender and slid down the bar, going
## green on the way; whoever it is for knocks it back in one, a moment later,
## and it starts working at once.
func _fx_bartender_mickey_finn(play: Play) -> void:
	var speed: float = table._speed
	var bar := _at(play.actor)
	var mouth := _at(play.target)
	var here := bar + (POT - bar).limit_length(70.0)
	var there := mouth + (POT - mouth).limit_length(64.0)
	var glass := GlassFx.new()
	glass.position = here
	glass.modulate.a = 0.0
	glass.pouring = true
	add_child(glass)
	_snd("fx_mickey_pour")
	var pour := glass.create_tween()
	pour.tween_property(glass, "modulate:a", 1.0, 0.1 / speed)
	pour.tween_property(glass, "fill", 1.0, 0.55 / speed)
	pour.tween_callback(glass.set.bind("pouring", false))
	await _wait(0.75)
	if not is_instance_valid(glass):
		return
	var slide := glass.create_tween().set_parallel()
	slide.tween_property(glass, "position", there, 0.32 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_property(glass, "spiked", 1.0, 0.32 / speed)
	# It stands there for a moment before it is picked up.
	await _wait(0.55)
	if not is_instance_valid(glass):
		return
	_snd("fx_gulp")
	var side := -1.0 if mouth.x < there.x else 1.0
	var tip := glass.create_tween().set_parallel()
	tip.tween_property(glass, "position", there.lerp(mouth, 0.35) + Vector2(0, -10), 0.16 / speed)
	tip.tween_property(glass, "rotation", side * 2.0, 0.24 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tip.tween_property(glass, "fill", 0.0, 0.3 / speed).set_delay(0.08 / speed)
	await _wait(0.45)
	rise(mouth, Color("9fd24a"), 14, 44.0)
	ring(mouth, Color("7f9a3c"), 90.0, 18.0, 0.45, 5.0)
	if is_instance_valid(glass):
		var away := glass.create_tween()
		away.tween_property(glass, "modulate:a", 0.0, 0.2 / speed)
		away.tween_callback(glass.queue_free)
	await _wait(0.5)


## The tray is slid out to the middle of the table and waits there: the
## cards only go on it once one was shown (cards_binned).
func _fx_bartender_last_call(play: Play) -> void:
	drop_tray()
	var speed: float = table._speed
	var tray := TrayFx.new()
	tray.position = _at(play.actor)
	tray.scale = Vector2(0.35, 0.35)
	tray.modulate.a = 0.0
	add_child(tray)
	_tray = tray
	_snd("fx_pour")
	var slide := tray.create_tween().set_parallel()
	slide.tween_property(tray, "modulate:a", 1.0, 0.12 / speed)
	slide.tween_property(tray, "position", POT, 0.42 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(tray, "scale", Vector2.ONE, 0.42 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.42)
	if not is_instance_valid(tray):
		return
	_snd("fx_tin")
	ring(POT, STEEL, 30.0, 150.0, 0.3, 3.0)
	await _wait(0.2)


## Takes away a tray nothing was put on.
func drop_tray() -> void:
	if _tray != null and is_instance_valid(_tray):
		var leave := _tray.create_tween()
		leave.tween_property(_tray, "modulate:a", 0.0, 0.15 / table._speed)
		leave.tween_callback(_tray.queue_free)
	_tray = null


## The cards of a Last Call (the data of cards_recalled): the character that
## was called is held up over the tray for the table to read (it is only
## named: nobody's card), every copy at the table is thrown in, each in its
## own way, the tray is carried off to the deck and the deck deals a new card
## to each place left empty.
func cards_binned(d: Dictionary) -> void:
	var speed: float = table._speed
	var tray := _tray
	_tray = null
	if tray == null or not is_instance_valid(tray):
		# Nobody brought one (a play carried out unannounced): it just shows up.
		tray = TrayFx.new()
		tray.position = POT
		tray.modulate.a = 0.0
		add_child(tray)
		tray.create_tween().tween_property(tray, "modulate:a", 1.0, 0.15 / speed)
	var def := Content.character(d.card)
	var face := UI.card_face(def.texture_path)
	var views: Array = []
	var spots: Array = []
	var cards: Array = []
	for hand: Dictionary in d.hands:
		var view: CardView = table._card_view(hand.player, hand.index)
		var card := TossedCard.new(face, UI.tex(UI.CARD_BACK))
		card.spot = table._card_center(hand.player, hand.index) - tray.position
		card.zoom = (view.size.x if view != null else 33.0) / TOSSED.x
		card.flip_y = PI
		card.visible = false
		tray.add_child(card)
		views.append(view)
		spots.append(table._card_center(hand.player, hand.index))
		cards.append(card)

	# The card that was called: only named, it is nobody's. It is held up
	# over the tray for the table to read and then it is gone.
	var shown := TossedCard.new(face, UI.tex(UI.CARD_BACK))
	shown.spot = _at(d.player) - tray.position
	shown.zoom = 33.0 / TOSSED.x
	shown.flip_y = PI
	tray.add_child(shown)
	_snd("card_draw")
	var lift := shown.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(shown, "spot", TOSS_SHOWN, 0.4 / speed)
	lift.tween_property(shown, "zoom", TOSS_SHOWN_ZOOM, 0.4 / speed)
	lift.chain().tween_property(shown, "flip_y", 0.0, 0.22 / speed)
	await _wait(0.66)
	if not is_instance_valid(tray):
		return
	_snd("fx_glint")
	ring(tray.position + TOSS_SHOWN, UI.GOLD, 40.0, 130.0, 0.35, 4.0)
	table._float(Loc.t("LAST CALL: %s") % def.display_name.to_upper(),
			tray.position + TOSS_SHOWN + Vector2(0, -TOSSED.y * TOSS_SHOWN_ZOOM / 2.0 - 16.0), UI.GOLD, 24)
	await _wait(0.85)
	if not is_instance_valid(tray):
		return
	var fade := shown.create_tween()
	fade.tween_property(shown, "modulate:a", 0.0, 0.22 / speed)
	fade.tween_callback(shown.queue_free)
	await _wait(0.25)

	# Every copy at the table, one after the other and no two thrown alike.
	var style := randi() % TOSS_STYLES
	for i: int in cards.size():
		style = (style + 1 + randi() % (TOSS_STYLES - 1)) % TOSS_STYLES
		var wait: Tween = cards[i].create_tween()
		wait.tween_interval(maxf(i * 0.17, 0.01) / speed)
		wait.tween_callback(_toss.bind(tray, cards[i], views[i], style))
	if not cards.is_empty():
		await _wait((cards.size() - 1) * 0.17 + 1.0)
	if not is_instance_valid(tray):
		return

	# Off to the deck with all of it.
	await _wait(0.2)
	_snd("fx_tin")
	var deck: Vector2 = table._bank()
	var away := tray.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	away.tween_property(tray, "position", deck, 0.45 / speed)
	away.tween_property(tray, "scale", Vector2(0.22, 0.22), 0.45 / speed)
	away.tween_property(tray, "modulate:a", 0.0, 0.14 / speed).set_delay(0.31 / speed)
	away.chain().tween_callback(tray.queue_free)
	await _wait(0.5)
	ring(deck, STEEL, 10.0, 46.0, 0.25, 3.0)
	# The hands that kept out of it (an Untraceable) are back now that the
	# tray is gone.
	bring_back()

	# And the deck deals, fast.
	for i: int in views.size():
		var view: CardView = views[i]
		var landing: Vector2 = view.size if view != null and is_instance_valid(view) else Vector2(33, 60)
		_snd("card_draw")
		table._fly_card(deck, spots[i], Vector2(33, 60), landing, 0.2)
		get_tree().create_timer(0.2 / speed).timeout.connect(_card_dealt.bind(view))
		await _wait(0.08)
	await _wait(0.3)


## Throws `card` from where it is onto `tray`, in one of TOSS_STYLES ways.
## It leaves the hand face down and is face up by the time it lands.
func _toss(tray: TrayFx, card: TossedCard, view: CardView, style: int) -> void:
	if not is_instance_valid(tray):
		return
	var speed: float = table._speed
	var rest := _tray_rest()
	var lean := randf_range(-0.5, 0.5)
	var side := 1.0 if randf() < 0.5 else -1.0
	var time := 0.5
	var arc := 60.0
	var path := Tween.TRANS_QUAD
	card.visible = true
	table._set_cards_shown([view], false)
	_snd("card_draw")
	var fly := card.create_tween().set_parallel()
	match style:
		0:
			# Spinning about its upright axis, like a coin on a counter.
			card.flip_y = PI + TAU * 2.0
			fly.tween_property(card, "flip_y", 0.0, time / speed).set_ease(Tween.EASE_OUT)
		1:
			# End over end.
			card.flip_y = 0.0
			card.flip_x = PI + TAU * 2.0
			fly.tween_property(card, "flip_x", 0.0, time / speed).set_ease(Tween.EASE_OUT)
		2:
			# Tumbling every way at once.
			time = 0.6
			arc = 95.0
			card.flip_y = PI + TAU
			card.flip_x = TAU * 2.0
			card.rotation = lean + side * TAU
			fly.tween_property(card, "flip_y", 0.0, time / speed)
			fly.tween_property(card, "flip_x", 0.0, time / speed).set_ease(Tween.EASE_OUT)
		3:
			# Flat and fast, turning like a thrown plate.
			time = 0.4
			arc = 12.0
			card.rotation = lean + side * TAU * 3.0
			fly.tween_property(card, "flip_y", 0.0, time * 0.3 / speed)
		4:
			# Lobbed high, one lazy turn on the way down.
			time = 0.7
			arc = 175.0
			path = Tween.TRANS_SINE
			card.flip_y = 0.0
			card.flip_x = PI + TAU
			fly.tween_property(card, "flip_x", 0.0, time / speed)
		_:
			# Chucked any old way: it skids past its place and ends up crooked.
			time = 0.36
			arc = 24.0
			path = Tween.TRANS_BACK
			lean = side * randf_range(0.8, 1.4)
			card.rotation = lean - side * 2.4
			fly.tween_property(card, "flip_y", 0.0, time * 0.45 / speed)
	card.from = card.spot
	card.to = rest
	card.arc = arc
	fly.tween_property(card, "along", 1.0, time / speed).set_trans(path).set_ease(Tween.EASE_OUT)
	fly.tween_property(card, "zoom", 1.0, time / speed)
	fly.tween_property(card, "rotation", lean, time / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.chain().tween_callback(_card_landed.bind(tray, rest))


## Somewhere on the tray for a card to end up, from its middle.
func _tray_rest() -> Vector2:
	return Vector2(randf_range(-56.0, 56.0), randf_range(-14.0, 12.0))


func _card_landed(tray: TrayFx, at: Vector2) -> void:
	if not is_instance_valid(tray):
		return
	burst(tray.position + at, PORCELAIN, 4, 80.0, 0.25, 260.0, 6.0)


## A card from the deck reaches its place in a hand, face down.
func _card_dealt(view: CardView) -> void:
	if view == null or not is_instance_valid(view):
		return
	view.set_card(&"", false)
	table._set_cards_shown([view], true)
	UI.pop(view, 1.15, 0.2)


## The Sheriff's boot steps out of his box and across the table, spur
## jingling, to the coins of whoever is being shaken down, and is drawn back
## over them, heel up and rowel spinning. There it waits: the coins are only
## his once nobody stopped him (boot_stomp), and it is walked home empty if
## somebody did (put_away).
func _fx_sheriff_shakedown(play: Play) -> void:
	drop_boot()
	var speed: float = table._speed
	var coin: Vector2 = table._coin_anchor(play.target)
	var home := _at(play.actor)
	var from: Vector2 = table._clear_of(table._node_of(play.actor), home, coin, 0.0)
	var boot := BootFx.new()
	boot.facing = -1.0 if coin.x < from.x else 1.0
	boot.modulate.a = 0.0
	add_child(boot)
	_boot = boot
	_boot_owner = play.actor
	_boot_target = play.target
	_boot_pose = [BootFx.ROWEL, home, 0.0]
	boot.pose(BootFx.ROWEL, home, 0.0)
	var f := boot.facing
	# Beside the coins, heel first.
	var stand := coin + Vector2(-f * 12.0, -2.0)
	var hops := clampi(roundi(from.distance_to(stand) / BOOT_HOP), 1, 3)
	var move := boot.create_tween()
	move.tween_property(boot, "modulate:a", 1.0, 0.08 / speed)
	_boot_go(move, [BootFx.ROWEL, from, 0.0], 0.12, 8.0)
	move.tween_callback(_boot_lands.bind(boot))
	for hop in hops:
		var to := from.lerp(stand, float(hop + 1) / hops)
		_boot_go(move, [BootFx.ROWEL, to, 0.0], BOOT_STRIDE, _boot_lift(from.lerp(stand, float(hop) / hops), to))
		move.tween_callback(_boot_lands.bind(boot))
		move.tween_interval(0.04 / speed)
	# Drawn back: the toe goes down and the heel comes up over the coins.
	move.tween_callback(_snd.bind("fx_spur"))
	move.tween_property(boot, "restless", 1.0, 0.01)
	_boot_go(move, [BootFx.ROWEL, coin + Vector2(-f * 6.0, -BOOT_COCKED), -0.8], 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	move.parallel().tween_property(boot, "whirl", 20.0, 0.3 / speed)
	await _wait(0.12 + hops * (BOOT_STRIDE + 0.04) + 0.4)


## Moves the boot on from the pose it was last given to the pose `to`
## ([cell, where, lean]: see BootFx.pose), as one more step of `move`. It
## leaves the straight way by `lift` px, upwards, at the middle of it.
func _boot_go(move: Tween, to: Array, time: float, lift := 0.0) -> MethodTweener:
	var step := move.tween_method(_boot_step.bind(_boot, _boot_pose, to, lift), 0.0, 1.0, time / table._speed)
	_boot_pose = to
	return step


func _boot_step(t: float, boot: BootFx, a: Array, b: Array, lift: float) -> void:
	var cell: Vector2 = (a[0] as Vector2).lerp(b[0], t)
	var where: Vector2 = (a[1] as Vector2).lerp(b[1], t) - Vector2(0.0, lift * 4.0 * t * (1.0 - t))
	boot.pose(cell, where, lerpf(a[2], b[2], t))


## How high a hop between two places it stands on can go without the top of
## the boot leaving the screen.
func _boot_lift(a: Vector2, b: Vector2) -> float:
	return clampf(minf(a.y, b.y) - BootFx.TALL - 4.0, 4.0, 30.0)


## The heel comes down on the table at the end of a hop.
func _boot_lands(boot: BootFx) -> void:
	_snd("fx_boot_step")
	burst(boot.at(BootFx.HEEL), BootFx.DUST, 4, 70.0, 0.25, 200.0, 4.0)
	_boot_jolt(boot, Vector2(1.12, 0.86), 9.0)
	if boot.haul > 0:
		_snd("coin_%d" % (randi() % 3 + 1))


## The boot gives under a blow, and the rowel is set turning by it.
func _boot_jolt(boot: BootFx, squash: Vector2, kick: float) -> void:
	boot.scale = squash
	boot.spur(kick)
	var give := boot.create_tween()
	give.tween_property(boot, "scale", Vector2.ONE, 0.14 / table._speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True while the boot of `thief` is drawn back over the coins of `victim`.
func booting(thief: PlayerState, victim: PlayerState) -> bool:
	return _boot != null and is_instance_valid(_boot) and _boot_owner == thief and _boot_target == victim


## The coins of a Shakedown leaving their owner (the `coins` event with
## reason "stolen"): the heel comes down with everything behind it, the rowel
## of the spur on the coin of their balance, and the coins jump out of the
## pile, one after the other, in a high arc that ends in the mouth of the
## boot, which has hopped clear to catch them.
func boot_stomp(d: Dictionary) -> void:
	var boot := _boot
	var speed: float = table._speed
	var victim: PlayerState = d.player
	var total: int = -d.delta
	var coin: Vector2 = table._coin_anchor(victim)
	var f := boot.facing
	var bar: StatBar = table._stat_bar(victim)
	if bar != null:
		bar.hold_coins(victim)
	# A little further back, and down.
	var move := boot.create_tween()
	_boot_go(move, [BootFx.ROWEL, coin + Vector2(-f * 8.0, -BOOT_COCKED - 6.0), -1.0], 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_boot_go(move, [BootFx.ROWEL, coin, 0.4], 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.19)
	if boot != _boot or not is_instance_valid(boot):
		return
	_snd("fx_boot_stomp")
	boot.restless = 0.0
	boot.whirl = 0.0
	_boot_jolt(boot, Vector2(1.22, 0.72), 50.0)
	burst(coin, UI.GOLD, 14, 260.0, 0.45, 520.0)
	burst(coin, Color.WHITE, 6, 200.0, 0.25, 300.0, 6.0)
	ring(coin, UI.GOLD, 8.0, 64.0, 0.3, 5.0)
	ring(coin, Color.WHITE, 4.0, 40.0, 0.2, 3.0)
	flash(Color(1.0, 0.9, 0.5, 0.12), 0.18)
	table._shake_screen(10.0)
	var box: Control = table._node_of(victim)
	if box is SeatView:
		UI.shake(box, 8.0, 0.3)
	# It stays where it hit for a moment, then hops clear, mouth to the coins.
	var mouth := Vector2(clampf(coin.x + f * 46.0, 44.0, size.x - 44.0), maxf(coin.y - 20.0, BootFx.TALL + 8.0))
	move = boot.create_tween()
	move.tween_interval(0.06 / speed)
	_boot_go(move, [BootFx.MOUTH, mouth, 0.3], 0.24, 14.0)
	var coins := clampi(total, 1, BOOT_COINS)
	for i in coins:
		var share := total * (i + 1) / coins - total * i / coins
		var sprite := _sprite(UI.tex(COIN_ART), coin, Vector2(20, 20))
		boot.take(sprite)
		sprite.hide()
		var height := clampf(46.0 + 12.0 * i, 16.0, (coin.y + mouth.y) / 2.0 - 14.0)
		var flight := sprite.create_tween()
		flight.tween_interval((0.03 + BOOT_SPIT * i) / speed)
		flight.tween_callback(_boot_spat.bind(sprite, boot, bar, share, coin))
		flight.tween_method(_boot_spit.bind(sprite, boot, coin, height, i), 0.0, 1.0, BOOT_ARC / speed)
		flight.tween_callback(_boot_caught.bind(sprite, boot, i))
	await _wait(0.03 + BOOT_SPIT * (coins - 1) + BOOT_ARC + 0.12)
	if boot != _boot or not is_instance_valid(boot):
		return
	# Upright again, with what it got.
	_boot_go(boot.create_tween(), [BootFx.MOUTH, mouth, 0.0], 0.14)
	await _wait(0.14)


## A coin jumps out of the pile at `from`.
func _boot_spat(sprite: Control, boot: BootFx, bar: StatBar, share: int, from: Vector2) -> void:
	if is_instance_valid(boot):
		_boot_coin(sprite, boot, from)
	sprite.show()
	if bar != null:
		bar.add_coins(-share)
	burst(from, UI.GOLD, 3, 120.0, 0.2, 300.0, 4.0)


## A coin `t` of its way from the pile at `from` into the boot: thrown up
## and over, turning, and down into the mouth, wherever that is by now.
func _boot_spit(t: float, sprite: Control, boot: BootFx, from: Vector2, height: float, index: int) -> void:
	if not is_instance_valid(boot):
		return
	var into := boot.at(BootFx.MOUTH + Vector2(0.0, 5.0))
	var at := from.lerp(into, t) - Vector2(0.0, height * 4.0 * t * (1.0 - t))
	_boot_coin(sprite, boot, at)
	sprite.rotation = t * TAU * (1.5 + 0.5 * index) * boot.facing
	sprite.scale = Vector2.ONE * lerpf(1.0, 0.7, smoothstep(0.6, 1.0, t))


## Puts a coin the boot holds (see BootFx.take) at `at` on the screen.
func _boot_coin(sprite: Control, boot: BootFx, at: Vector2) -> void:
	sprite.position = boot.get_transform().affine_inverse() * at - sprite.size / 2.0


func _boot_caught(sprite: Control, boot: BootFx, index: int) -> void:
	sprite.queue_free()
	if not is_instance_valid(boot):
		return
	boot.haul += 1
	_snd("coin_%d" % (index % 3 + 1))
	burst(boot.at(BootFx.MOUTH), UI.GOLD, 3, 90.0, 0.2, 300.0, 4.0)
	_boot_jolt(boot, Vector2(1.1, 0.88), 10.0)


## True if `who` has a boot out with coins in it.
func boot_loaded(who: PlayerState) -> bool:
	return _boot != null and is_instance_valid(_boot) and _boot_owner == who and _boot.haul > 0


## Where the coins in the boot of `who` come out, if somebody else is getting
## them after all (a Swindle): the boot is left empty. Vector2.INF if there
## is no such boot.
func boot_robbed(who: PlayerState) -> Vector2:
	if not boot_loaded(who):
		return Vector2.INF
	_boot.haul = 0
	return _boot.at(BootFx.MOUTH)


## The coins of a Shakedown reaching the thief (the `coins` event with reason
## "steal"): the boot turns for home and hops back, the coins clinking in it,
## and is tipped over his balance, mouth down. The coins drop out one at a
## time and are counted in as they land; a last shake for the one that is
## not there, and the boot goes back where it came from.
func boot_pour(d: Dictionary) -> void:
	var boot := _boot
	var thief: PlayerState = d.player
	var total: int = d.delta
	var speed: float = table._speed
	var purse: Vector2 = table._coin_anchor(thief)
	var home := _at(thief)
	var bar: StatBar = table._stat_bar(thief)
	if bar != null:
		bar.hold_coins(thief)
	var heel := boot.at(BootFx.HEEL)
	var f := -1.0 if purse.x < heel.x else 1.0
	var turned := f != boot.facing
	var move := boot.create_tween()
	if turned:
		# Turned round on the spot, like a card.
		var middle := boot.at(BootFx.SHAFT)
		move.tween_method(_boot_turn.bind(boot, middle, boot.facing), 0.0, 1.0, 0.12 / speed)
		heel = middle + Vector2((BootFx.HEEL.x - BootFx.SHAFT.x) * f, BootFx.HEEL.y - BootFx.SHAFT.y) * BootFx.PIXEL
	_boot_pose = [BootFx.HEEL, heel, 0.0]
	# Where it is tipped from: the mouth ends up over the coin.
	var spout := Vector2(purse.x - f * 8.0, maxf(purse.y - 30.0, 44.0))
	var stand := Vector2(purse.x - f * 60.0, maxf(purse.y + 8.0, BootFx.TALL + 6.0))
	var hops := clampi(roundi(heel.distance_to(stand) / BOOT_HOP), 1, 3)
	for hop in hops:
		var to := heel.lerp(stand, float(hop + 1) / hops)
		_boot_go(move, [BootFx.HEEL, to, 0.0], BOOT_STRIDE + 0.02, _boot_lift(heel.lerp(stand, float(hop) / hops), to))
		move.tween_callback(_boot_lands.bind(boot))
		move.tween_interval(0.04 / speed)
	_boot_go(move, [BootFx.MOUTH, spout, BOOT_TIPPED], 0.22, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait((0.12 if turned else 0.0) + hops * (BOOT_STRIDE + 0.06) + 0.24)
	if boot != _boot or not is_instance_valid(boot):
		return
	var coins := clampi(total, 1, BOOT_COINS)
	for i in coins:
		var share := total * (i + 1) / coins - total * i / coins
		_boot_shake(boot, spout)
		boot.haul = maxi(boot.haul - 1, 0)
		var sprite := _sprite(UI.tex(COIN_ART), spout, Vector2(20, 20))
		boot.take(sprite)
		_boot_drop(0.0, sprite, boot, purse, i)
		var fall := sprite.create_tween()
		fall.tween_method(_boot_drop.bind(sprite, boot, purse, i), 0.0, 1.0, BOOT_DROP / speed)
		fall.tween_callback(_boot_paid.bind(sprite, bar, share, purse, i))
		await _wait(BOOT_POUR)
		if not is_instance_valid(boot):
			return
	boot.haul = 0
	# Is that all of it?
	for shake in 2:
		_boot_shake(boot, spout)
		await _wait(0.13)
		if not is_instance_valid(boot):
			return
	# Set down again, and back where it came from.
	_boot = null
	_boot_owner = null
	_boot_target = null
	move = boot.create_tween()
	move.tween_method(_boot_step.bind(boot, [BootFx.MOUTH, spout, BOOT_TIPPED], [BootFx.HEEL, stand, 0.0], 8.0), 0.0, 1.0, 0.16 / speed)
	move.tween_method(_boot_step.bind(boot, [BootFx.HEEL, stand, 0.0], [BootFx.HEEL, home, 0.0], 12.0), 0.0, 1.0, 0.2 / speed)
	move.parallel().tween_property(boot, "modulate:a", 0.0, 0.1 / speed).set_delay(0.1 / speed)
	move.tween_callback(boot.queue_free)
	await _wait(0.2)


## The boot turning round about the middle of its leg, which stays at
## `middle`: flat as a card half way through.
func _boot_turn(t: float, boot: BootFx, middle: Vector2, facing: float) -> void:
	boot.facing = facing if t < 0.5 else -facing
	boot.scale.x = maxf(absf(1.0 - 2.0 * t), 0.05)
	boot.pose(BootFx.SHAFT, middle, 0.0)


## A shake of the boot held mouth down over `spout`, to get a coin out.
func _boot_shake(boot: BootFx, spout: Vector2) -> void:
	var shake := boot.create_tween()
	shake.tween_method(_boot_step.bind(boot, [BootFx.MOUTH, spout, BOOT_TIPPED], [BootFx.MOUTH, spout + Vector2(0.0, 5.0), BOOT_TIPPED - 0.16], 0.0), 0.0, 1.0, 0.04 / table._speed)
	shake.tween_method(_boot_step.bind(boot, [BootFx.MOUTH, spout + Vector2(0.0, 5.0), BOOT_TIPPED - 0.16], [BootFx.MOUTH, spout, BOOT_TIPPED], 0.0), 0.0, 1.0, 0.08 / table._speed)


## A coin `t` of its way out of the mouth of the boot and down to the pile
## at `to`: it slides out and then falls faster and faster.
func _boot_drop(t: float, sprite: Control, boot: BootFx, to: Vector2, index: int) -> void:
	if not is_instance_valid(boot):
		return
	var from := boot.at(BootFx.MOUTH + Vector2(0.0, 3.0))
	var at := Vector2(lerpf(from.x, to.x, sqrt(t)), lerpf(from.y, to.y, t * t))
	_boot_coin(sprite, boot, at)
	sprite.rotation = t * TAU * (0.5 + 0.25 * index)


func _boot_paid(sprite: Control, bar: StatBar, share: int, at: Vector2, index: int) -> void:
	sprite.queue_free()
	if bar != null:
		bar.add_coins(share)
	_snd("coin_%d" % (index % 3 + 1))
	burst(at, UI.GOLD, 3, 90.0, 0.2, 300.0, 4.0)


## A Silver Tongue against a Shakedown: there is no hand to rap, there is a
## boot. It comes down all the same, and the lute meets it half way: the
## boot goes home over the table, end over end, with nothing in it.
func _boot_bonked(play: Play) -> void:
	var boot := _boot
	var home := _at(_boot_owner)
	_boot = null
	_boot_owner = null
	_boot_target = null
	var speed: float = table._speed
	var coin: Vector2 = table._coin_anchor(play.actor)
	var f := boot.facing
	# Where it is met: the leg of the boot, on its way down.
	var reach := coin + Vector2(f * 24.0, -28.0)
	# Held by the neck, in front of the boot and over it (under it, for a
	# Bard sitting at the top of the screen).
	var over := -1.0 if reach.y > 170.0 else 1.0
	var turn := f * over
	var grip := reach + Vector2(f * 0.8, over * 0.6) * LUTE_REACH
	var club := Control.new()
	club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	club.position = grip
	var struck := (reach - grip).angle() - PI
	var raised := struck - LUTE_LIFT * turn
	club.rotation = raised
	club.modulate.a = 0.0
	var lute := LuteFx.new()
	lute.position = Vector2(LuteFx.BELLY - LUTE_REACH, 0.0)
	club.add_child(lute)
	add_child(club)
	var blow := (reach - (grip - Vector2.from_angle(raised) * LUTE_REACH)).normalized()
	club.create_tween().tween_property(club, "modulate:a", 1.0, 0.12 / speed)
	await _wait(0.3)
	if not is_instance_valid(boot) or not is_instance_valid(club):
		return
	# Both of them drawn back, and both come down.
	var move := boot.create_tween()
	move.tween_method(_boot_step.bind(boot, _boot_pose, [BootFx.ROWEL, coin + Vector2(-f * 8.0, -BOOT_COCKED - 6.0), -1.0], 0.0), 0.0, 1.0, 0.14 / speed)
	move.tween_method(_boot_step.bind(boot, [BootFx.ROWEL, coin + Vector2(-f * 8.0, -BOOT_COCKED - 6.0), -1.0], [BootFx.ROWEL, coin + Vector2(0.0, -10.0), 0.1], 0.0), 0.0, 1.0, 0.07 / speed)
	var swing := club.create_tween()
	swing.tween_property(club, "position", grip - blow * 22.0, 0.14 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing.parallel().tween_property(club, "rotation", raised - turn * 0.35, 0.14 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing.tween_property(club, "position", grip + blow * 10.0, 0.07 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.parallel().tween_property(club, "rotation", struck + turn * 0.1, 0.07 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.tween_property(club, "position", grip - blow * 10.0, 0.1 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.parallel().tween_property(club, "rotation", struck - turn * 0.3, 0.1 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.tween_property(club, "position", grip, 0.25 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.parallel().tween_property(club, "rotation", raised, 0.25 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.21)
	if not is_instance_valid(boot):
		return
	_snd("fx_lute_bonk")
	lute.pluck(0.5)
	var hit := boot.at(BootFx.SHAFT)
	burst(hit, Color.WHITE, 14, 300.0, 0.3, 400.0, 6.0)
	ring(hit, UI.GOLD, 10.0, 100.0, 0.25, 5.0)
	table._shake_screen(7.0)
	_alarm(hit)
	move.kill()
	boot.restless = 0.0
	boot.whirl = 40.0
	var lift := clampf(minf(hit.y, home.y) - 50.0, 10.0, 110.0)
	move = boot.create_tween()
	move.tween_method(_boot_step.bind(boot, [BootFx.SHAFT, hit, 0.1], [BootFx.SHAFT, home, 0.1 - TAU * 2.0], lift), 0.0, 1.0, 0.55 / speed)
	move.parallel().tween_property(boot, "modulate:a", 0.0, 0.1 / speed).set_delay(0.45 / speed)
	move.tween_callback(boot.queue_free)
	await _wait(0.6)
	_snd("fx_lute_flourish")
	if is_instance_valid(club):
		lute.pluck(0.4)
		_note(reach, 0)
		_note(reach, 1)
		var away := club.create_tween()
		away.tween_interval(0.45 / speed)
		away.tween_property(club, "modulate:a", 0.0, 0.25 / speed)
		away.tween_callback(club.queue_free)
	await _wait(0.5)


## Walks home a boot that got nothing: the Shakedown was stopped.
func drop_boot() -> void:
	if _boot != null and is_instance_valid(_boot):
		var boot := _boot
		var speed: float = table._speed
		var home := _at(_boot_owner)
		var middle := boot.at(BootFx.SHAFT)
		boot.restless = 0.0
		var leave := boot.create_tween()
		leave.tween_method(_boot_step.bind(boot, [BootFx.SHAFT, middle, boot.lean], [BootFx.SHAFT, middle.lerp(home, 0.3), 0.0], 16.0), 0.0, 1.0, 0.2 / speed)
		leave.parallel().tween_property(boot, "whirl", 0.0, 0.2 / speed)
		leave.parallel().tween_property(boot, "modulate:a", 0.0, 0.12 / speed).set_delay(0.1 / speed)
		leave.tween_callback(boot.queue_free)
	_boot = null
	_boot_owner = null
	_boot_target = null


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


## A syringe, given to the Doctor's own box from the side of the middle of
## the table: a flick on the glass, a squirt to clear the needle, the jab,
## and the plunger pushed home. The status goes when the play resolves.
func _fx_doctor_antidote(play: Play) -> void:
	var who := play.actor
	var speed: float = table._speed
	var here := _at(who)
	var edge: Vector2 = table._clear_of(table._node_of(who), here, POT, 0.0)
	var way := (here - edge).normalized() if edge.distance_to(here) > 1.0 else (here - POT).normalized()
	var syringe := SyringeFx.new()
	syringe.rotation = way.angle()
	# Its needle is NEEDLE_OFF short of the box.
	var ready := edge - way * (SyringeFx.LENGTH + NEEDLE_OFF)
	syringe.position = ready - way * 30.0
	syringe.modulate.a = 0.0
	add_child(syringe)
	_snd("fx_syringe")
	var enter := syringe.create_tween().set_parallel()
	enter.tween_property(syringe, "modulate:a", 1.0, 0.1 / speed)
	enter.tween_property(syringe, "position", ready, 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Two flicks of a nail on the glass.
	var flick := syringe.create_tween()
	for i in 2:
		flick.tween_property(syringe, "rotation", way.angle() + 0.09, 0.03 / speed)
		flick.tween_property(syringe, "rotation", way.angle(), 0.08 / speed)
	await _wait(0.26)
	if not is_instance_valid(syringe):
		return
	# A squirt, to clear the needle.
	var tip := syringe.tip()
	for i in 5:
		_bits.append({
			"p": tip, "v": way.rotated(randf_range(-0.3, 0.3)) * randf_range(70.0, 150.0),
			"c": SERUM, "s": 4.0, "life": 0.3, "t": 0.0, "g": 260.0,
		})
	_wake()
	syringe.dose = 0.92
	var jab := syringe.create_tween()
	jab.tween_property(syringe, "position", ready - way * 12.0, 0.2 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	jab.tween_interval(0.03 / speed)
	jab.tween_property(syringe, "position", ready + way * (NEEDLE_OFF + NEEDLE_IN), 0.06 / speed).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	jab.parallel().tween_property(syringe, "sunk", NEEDLE_IN, 0.02 / speed).set_delay(0.04 / speed)
	await _wait(0.29)
	if not is_instance_valid(syringe):
		return
	table._shake_screen(3.0)
	burst(edge, SERUM, 6, 110.0, 0.25, 200.0, 4.0)
	ring(edge, SERUM, 4.0, 26.0, 0.2, 3.0)
	await _wait(0.1)
	if not is_instance_valid(syringe):
		return
	# The plunger goes home, and the dose spreads through the box.
	syringe.create_tween().tween_property(syringe, "dose", 0.0, 0.42 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 3:
		ring(here, SERUM, 20.0 + i * 8.0, 70.0 + i * 14.0, 0.32, 3.0)
		rise(here, SERUM.lightened(0.2), 4, 50.0)
		await _wait(0.15)
	if not is_instance_valid(syringe):
		return
	_cross(here, 20.0, SERUM)
	flash(Color(SERUM, 0.1), 0.2)
	var away := syringe.create_tween()
	away.tween_property(syringe, "sunk", 0.0, 0.03 / speed)
	away.parallel().tween_property(syringe, "position", ready - way * 26.0, 0.18 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	away.parallel().tween_property(syringe, "modulate:a", 0.0, 0.1 / speed).set_delay(0.08 / speed)
	away.tween_callback(syringe.queue_free)
	await _wait(0.2)


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


## A round black bomb is set down in front of the Bomber and its fuse lit. It
## waits there: which item it is for is only chosen as the play resolves
## (item_bombed), and a bomb nothing was chosen for is taken back (put_away).
func _fx_bomber_demolition(play: Play) -> void:
	drop_bomb()
	var here := _at(play.actor)
	var speed: float = table._speed
	var bomb := BombFx.new()
	bomb.position = here + (POT - here).normalized() * BOMB_REST
	# On the table, never on the player's own panel.
	bomb.position.y = minf(bomb.position.y, BOMB_FLOOR)
	bomb.scale = Vector2(0.3, 0.3)
	bomb.modulate.a = 0.0
	bomb.blinked.connect(_snd.bind("item_roulette_tick"))
	add_child(bomb)
	_bomb = bomb
	var land := bomb.create_tween().set_parallel()
	land.tween_property(bomb, "modulate:a", 1.0, 0.1 / speed)
	land.tween_property(bomb, "scale", Vector2.ONE, 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.22)
	if not is_instance_valid(bomb):
		return
	_snd("fx_fuse")
	bomb.lit = true
	burst(bomb.position + bomb.fuse_tip(), EMBER, 6, 90.0, 0.3, -60.0, 5.0)
	await _wait(0.35)


## True while a bomb is out with no item picked for it yet.
func bombing() -> bool:
	return _bomb != null and is_instance_valid(_bomb)


## The bomb is tossed at the item at `at`, and not well: it comes down short
## and to a side, and bounces the rest of the way there, blinking red faster
## and faster. Then the two go up together. `gone` is called as it blows:
## from then on the item is not in the inventory.
func item_bombed(texture: Texture2D, at: Vector2, item_size: Vector2, gone: Callable) -> void:
	var bomb := _bomb
	_bomb = null
	if bomb == null or not is_instance_valid(bomb):
		gone.call()
		return
	var speed: float = table._speed
	var from := bomb.position
	var way := at - from
	var side := way.orthogonal().normalized() * BOMB_STRAY * (1.0 if randf() < 0.5 else -1.0)
	var spin := BOMB_SPIN * signf(way.x if way.x != 0.0 else 1.0)
	var whole := 0.0
	for hop: Array in BOMB_HOPS:
		whole += hop[3]
	bomb.create_tween().tween_property(bomb, "hurry", 1.0, whole / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_snd("card_draw")
	var left := from
	for hop: Array in BOMB_HOPS:
		var lands: Vector2 = from + way * hop[0] + side * hop[1]
		var high: float = hop[2]
		var fly := bomb.create_tween().set_parallel()
		fly.tween_method(func(along: float) -> void:
			bomb.lift = high * 4.0 * along * (1.0 - along)
			bomb.position = left.lerp(lands, along) + Vector2(0, -bomb.lift), 0.0, 1.0, hop[3] / speed)
		fly.tween_property(bomb, "turn", bomb.turn + spin * hop[3], hop[3] / speed)
		await _wait(hop[3])
		if not is_instance_valid(bomb):
			gone.call()
			return
		# Iron on wood.
		_snd("fx_gavel")
		burst(lands + Vector2(0, BombFx.RADIUS), EARTH.lightened(0.35), 4, 70.0, 0.25, 120.0, 4.0)
		left = lands
		spin *= 0.6
	# It has got there: a last breath of frantic blinking.
	UI.shake(bomb, 2.0, 0.3 / speed)
	await _wait(0.3)
	if is_instance_valid(bomb):
		bomb.queue_free()
	gone.call()
	_snd("fx_boom")
	flash(Color(1.0, 0.85, 0.5, 0.4), 0.25)
	var wreck: TextureRect = _sprite(texture, at, item_size)
	wreck.pivot_offset = item_size / 2.0
	var apart := wreck.create_tween().set_parallel()
	apart.tween_property(wreck, "scale", Vector2.ONE * 2.2, 0.22 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	apart.tween_property(wreck, "rotation", 0.6, 0.22 / speed)
	apart.tween_property(wreck, "modulate", Color(1.0, 0.5, 0.2, 0.0), 0.22 / speed)
	apart.chain().tween_callback(wreck.queue_free)
	burst(at, EMBER, 26, 380.0, 0.6, 300.0, 10.0)
	burst(at, Color("ffd98a"), 14, 280.0, 0.45, 200.0, 8.0)
	burst(at, SMOKE, 14, 140.0, 0.9, -60.0, 12.0)
	ring(at, Color.WHITE, 8.0, 120.0, 0.35, 6.0)
	table._float("BOOM!", at + Vector2(0, -30), EMBER, 30)
	UI.shake(table._table, 18.0, 0.4)
	await _wait(0.7)


## The bomb is tossed at where an item should be (`at`) and there is nothing
## there to blow up (an Untraceable took the items off the table): it lands
## short, bounces over the spot and goes on bouncing the same way, each hop
## lower and quicker, until it is off the screen. It never goes off.
func bomb_missed(at: Vector2) -> void:
	var bomb := _bomb
	_bomb = null
	if bomb == null or not is_instance_valid(bomb):
		return
	var speed: float = table._speed
	var from := bomb.position
	var way := at - from
	var along := way.normalized() if way.length() > 1.0 else Vector2.RIGHT
	var spin := BOMB_SPIN * signf(along.x if along.x != 0.0 else 1.0)
	var stride := maxf(way.length() * BOMB_HOPS[0][0], BOMB_ROLL)
	var high: float = BOMB_HOPS[0][2]
	var time: float = BOMB_HOPS[0][3]
	var screen := Rect2(Vector2.ZERO, size).grow(BombFx.RADIUS * 2.0)
	var left := from
	_snd("card_draw")
	for hop: int in BOMB_MISSES:
		var lands := left + along * stride
		var start := left
		var top := high
		var fly := bomb.create_tween().set_parallel()
		fly.tween_method(func(t: float) -> void:
			bomb.lift = top * 4.0 * t * (1.0 - t)
			bomb.position = start.lerp(lands, t) + Vector2(0, -bomb.lift), 0.0, 1.0, time / speed)
		fly.tween_property(bomb, "turn", bomb.turn + spin * time, time / speed)
		await _wait(time)
		if not is_instance_valid(bomb):
			return
		if not screen.has_point(lands):
			break
		# Iron on wood, and nothing where the item was.
		_snd("fx_gavel")
		burst(lands + Vector2(0, BombFx.RADIUS), EARTH.lightened(0.35), 4, 70.0, 0.25, 120.0, 4.0)
		if hop == 0:
			table._float(Loc.t("NOTHING THERE"), at, UI.MUTED, 16)
		left = lands
		stride = maxf(stride * 0.8, BOMB_ROLL)
		high = maxf(high * 0.6, 22.0)
		time = maxf(time * 0.78, 0.24)
	if is_instance_valid(bomb):
		var gone := bomb.create_tween()
		gone.tween_property(bomb, "modulate:a", 0.0, 0.12 / speed)
		gone.tween_callback(bomb.queue_free)


## Takes back a bomb that was never thrown.
func drop_bomb() -> void:
	if _bomb != null and is_instance_valid(_bomb):
		var leave := _bomb.create_tween()
		leave.tween_property(_bomb, "modulate:a", 0.0, 0.15 / table._speed)
		leave.tween_callback(_bomb.queue_free)
	_bomb = null


# --- the Duelist ---------------------------------------------------------------

## How far out of a box each sword of a Prisoner's Dilemma waits, and how far
## apart the two wait at the least.
const SWORD_POST := 34.0
const SWORD_APART := 190.0
## How much of the blade goes into what it is driven into, in cells.
const SWORD_SUNK := 7
## What a sword stuck point down into the table covers, from its point.
const SWORD_FOOT := Rect2(-13, -90, 26, 96)
## Two swords laid down side by side: how far each stands from the middle.
const DILEMMA_GAP := 24.0
## How far from the point between the two players a free patch of table is
## looked for, and on what grid (a full table leaves little room).
const GROUND_REACH := 260.0
const GROUND_STEP := 10.0
## How high a laid-down sword is flung before it comes down, and how many
## whole turns it makes on the way (on top of what it takes to point down).
const SWORD_TOSS := 70.0
const SWORD_TURNS := 1
## A blow of the Dilemma: the pace the table drops to as the sword goes in,
## and for how long (real seconds) before it comes back.
const DAMAGE_SLOW := 0.2
const DAMAGE_HOLD := 0.55
## The recorded swing (sword-attack) is loudest SWING_PEAK seconds in: when
## to start it so that its peak is the blow or the meeting of two swords
## (_swords_cross: 0.3 s of wind-up and 0.16 of flight). The blow
## (_stab_box) is 0.45 s of wind-up, 0.1 of flight and then the last 0.06
## in slow motion, which the sound does not share: those take DAMAGE_REAL
## seconds of real time (the slowing down itself included).
## And how long after the clash the blades are heard giving way (sword-break).
const SWING_PEAK := 0.39
const DAMAGE_REAL := 0.2
const ATTACK_LEAD := 0.45 + 0.1 + DAMAGE_REAL - SWING_PEAK
const CROSS_LEAD := 0.3 + 0.16 - SWING_PEAK
const BREAK_LAG := 0.08
## Berserk: how long the fury takes to build (the heartbeat is as long), how
## far the sword is drawn back before it goes, and how far past each item it
## carries on.
const FURY_BUILD := 2.0
## The heart under the fury: the first gap between beats, how much shorter
## each one gets and the shortest (as in fx_heartbeat, gen_sfx.py).
const HEARTBEAT_FIRST := 0.62
const HEARTBEAT_HURRY := 0.82
const HEARTBEAT_FASTEST := 0.2
const SWORD_WIND := 22.0
const SWORD_THROUGH := 34.0
const FURY := Color("e0261a")
const SPLINTERS := Color("8a5a30")

## The two swords of a Prisoner's Dilemma, drawn and waiting for the answers:
## {player id: SwordFx}.
var _duel: Dictionary = {}
## The cracks the swords left in the table (CrackFx), until the play is over.
var _duel_marks: Array = []
## The sword of a Berserk and the fury round whoever went berserk:
## {sword, fury, by, box, tint}, or empty.
var _berserk: Dictionary = {}


## Both swords are drawn, one by each side: each comes out of its box with a
## flourish, turning over once as it grows, and then hangs there, swaying,
## pointed at the other while the two choose (duel_clash shows what they chose).
func _fx_duelist_dilemma(play: Play) -> void:
	drop_duel()
	var speed: float = table._speed
	var sides: Array = [play.actor, play.target]
	var posts: Array = sides.map(_sword_post)
	# Neighbours on a crowded table: each sword stands back from the other,
	# or the two would lie on top of each other.
	var apart: float = posts[0].distance_to(posts[1])
	if apart < SWORD_APART:
		var way: Vector2 = (posts[1] - posts[0]).normalized() if apart > 1.0 else Vector2.RIGHT
		posts[0] -= way * (SWORD_APART - apart) / 2.0
		posts[1] += way * (SWORD_APART - apart) / 2.0
	_snd("fx_sword_draw")
	for i in 2:
		var post: Vector2 = posts[i]
		var aim: float = (posts[1 - i] - post).angle()
		var sword := SwordFx.new()
		sword.position = post
		sword.rotation = aim - TAU
		sword.scale = Vector2(0.2, 0.2)
		sword.modulate.a = 0.0
		sword.trail = 1.0
		add_child(sword)
		_duel[sides[i].id] = sword
		var out := sword.create_tween().set_parallel()
		out.tween_property(sword, "modulate:a", 1.0, 0.1 / speed)
		out.tween_property(sword, "scale", Vector2.ONE, 0.45 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		out.tween_property(sword, "rotation", aim, 0.5 / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		out.chain().tween_property(sword, "trail", 0.0, 0.2 / speed)
		burst(post, STEEL, 10, 160.0, 0.35, 0.0, 4.0)
		burst(post, UI.GOLD, 6, 120.0, 0.4, -40.0, 4.0)
		ring(post, UI.GOLD, 4.0, 40.0, 0.3, 3.0)
	await _wait(0.5)
	for i in 2:
		var sword: SwordFx = _duel.get(sides[i].id)
		if sword != null and is_instance_valid(sword):
			sword.bob = true
			sword.shine()
	await _wait(0.35)


## Where `p` holds a sword: just out of their box, on the side of the middle
## of the table. Over the player's own counter, above the notice if there is
## one up: that is where they answer.
func _sword_post(p: PlayerState) -> Vector2:
	var rect := _box_rect(p)
	if p == table.viewer:
		var top := rect.position.y
		var notice: Control = table._prompt
		if notice != null and notice.visible:
			top = minf(top, notice.get_global_rect().position.y)
		return Vector2(_at(p).x, top - SWORD_POST)
	return _edge(rect, POT, -SWORD_POST)


## The point where the line from the middle of `rect` to `toward` crosses its
## edge, `inset` further in (out, if negative).
func _edge(rect: Rect2, toward: Vector2, inset: float) -> Vector2:
	var middle := rect.get_center()
	var way := (toward - middle).normalized() if toward.distance_to(middle) > 1.0 else Vector2.UP
	var half := rect.size / 2.0
	var reach := INF
	if absf(way.x) > 0.001:
		reach = half.x / absf(way.x)
	if absf(way.y) > 0.001:
		reach = minf(reach, half.y / absf(way.y))
	return middle + way * (reach - inset)


## True while the swords of a Prisoner's Dilemma are out.
func dueling() -> bool:
	return not _duel.is_empty()


## The answers of a Prisoner's Dilemma are shown. Both contributed: the two
## swords are flung up, turn over and are driven into the table side by side,
## between the two players, and the pot follows. Both attacked: they fly at
## each other, meet in the air and break. One of each: the one laid down is
## driven into the table and the other, in slow motion, into the box of
## whoever laid it down; the blow follows.
func duel_clash(d: Dictionary) -> void:
	var sides: Array = [d.duelist, d.rival]
	var strikes: Array = [d.duelist_strikes, d.rival_strikes]
	var swords: Array = []
	for p: PlayerState in sides:
		var sword: SwordFx = _duel.get(p.id) if is_instance_valid(_duel.get(p.id)) else null
		if sword == null:
			sword = SwordFx.new()
			sword.position = _sword_post(p)
			add_child(sword)
			_duel[p.id] = sword
		sword.bob = false
		swords.append(sword)
	var ground := _dilemma_ground(swords[0].position, swords[1].position)
	if strikes[0] and strikes[1]:
		await _swords_cross(swords, (ground[0] + ground[1]) / 2.0 + Vector2(0, SWORD_FOOT.position.y / 2.0))
		return
	if not strikes[0] and not strikes[1]:
		_lay_sword(swords[0], ground[0])
		await _wait(0.2)
		await _lay_sword(swords[1], ground[1])
		await _wait(0.15)
		# The pact: a gold glint runs between the two hilts.
		var hilts: Array = []
		for sword: Variant in swords:
			if is_instance_valid(sword):
				hilts.append(sword.position)
		if hilts.size() == 2:
			_snd("fx_glint")
			line(hilts[0], hilts[1], UI.GOLD, 3.0, 0.5, 0.15)
			rise((hilts[0] + hilts[1]) / 2.0, UI.GOLD, 12, 40.0)
		await _wait(0.4)
		return
	var giver := 1 if strikes[0] else 0
	await _lay_sword(swords[giver], ground[giver])
	await _wait(0.25)
	await _stab_box(swords[1 - giver], sides[giver])


## Where the two swords of a Dilemma go into the table, one for the side at
## `a` and one for the side at `b`: as close as can be to the point between
## the two, side by side, clear of the boxes and of the claim on the stage.
## On a crowded table, the patch that covers the least of them.
func _dilemma_ground(a: Vector2, b: Vector2) -> Array:
	var blocked := _ground_taken()
	var screen := Rect2(Vector2.ZERO, size).grow(-10.0)
	var middle := (a + b) / 2.0
	# Side by side across the table: the one from the left on the left.
	var side := Vector2(DILEMMA_GAP, 0) * (1.0 if a.x <= b.x else -1.0)
	var best: Array = [middle - side, middle + side]
	var least := INF
	# Every patch on a grid round the middle; what it covers weighs far more
	# than how far it is, so the nearest clear one wins.
	var steps := int(GROUND_REACH / GROUND_STEP)
	for row in range(-steps, steps + 1):
		for column in range(-steps, steps + 1):
			var shift := Vector2(column, row) * GROUND_STEP
			var away := shift.length()
			if away > GROUND_REACH:
				continue
			var spots: Array = [middle + shift - side, middle + shift + side]
			var covered := 0.0
			for spot: Vector2 in spots:
				var foot := Rect2(spot + SWORD_FOOT.position, SWORD_FOOT.size)
				if not screen.encloses(foot):
					covered += foot.size.x * foot.size.y
				for rect: Rect2 in blocked:
					var over := rect.intersection(foot)
					covered += over.size.x * over.size.y
			var cost := covered * 100.0 + away
			if cost < least:
				least = cost
				best = spots
	return best


## What a sword stuck in the table must not stand on: every box, the stage
## with the claim on it, the notice and the log.
func _ground_taken() -> Array:
	var taken: Array = []
	for p: PlayerState in table.engine.players:
		if table._node_of(p) != null:
			taken.append(_box_rect(p).grow(6.0))
	for shown: Variant in [table._stage, table._prompt]:
		if shown is Control and shown.visible:
			taken.append(shown.get_global_rect().grow(8.0))
	var log_box: Variant = table.get("_log_box")
	if log_box is Control and log_box.is_visible_in_tree():
		taken.append(log_box.get_global_rect().grow(4.0))
	return taken


## The sword is flung up off its post, turns over in the air leaving a blur
## behind it, and comes down point first into the table at `spot`.
func _lay_sword(sword: SwordFx, spot: Vector2) -> void:
	if not is_instance_valid(sword):
		return
	var speed: float = table._speed
	var lean := 0.14 if spot.x < POT.x else -0.14
	var down := PI / 2.0 + lean
	var tip := Vector2.from_angle(down) * SwordFx.TIP * SwordFx.PIXEL
	var over := spot - tip - Vector2(0, 26)
	var from := sword.position
	var top := minf(from.y, over.y) - SWORD_TOSS
	var control := Vector2((from.x + over.x) / 2.0, top)
	var start := sword.rotation
	# However it was pointing, it ends pointing down, turning the way it flies.
	var turn := angle_difference(start, down) + TAU * SWORD_TURNS * (1.0 if over.x >= from.x else -1.0)
	sword.trail = 1.0
	_snd("fx_sword_spin")
	var flight := 0.5
	var toss := sword.create_tween()
	toss.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		sword.position = from * u * u + control * 2.0 * u * t + over * t * t
		sword.rotation = start + turn * ease(t, 0.6), 0.0, 1.0, flight / speed)
	await _wait(flight)
	if not is_instance_valid(sword):
		return
	var drive := sword.create_tween().set_parallel()
	drive.tween_property(sword, "position", spot - tip + Vector2.from_angle(down) * SWORD_SUNK * SwordFx.PIXEL, 0.06 / speed).set_ease(Tween.EASE_IN)
	drive.tween_property(sword, "sunk", float(SWORD_SUNK), 0.06 / speed)
	await _wait(0.06)
	if not is_instance_valid(sword):
		return
	sword.trail = 0.0
	_sword_lands(sword, spot, 1.0)


## A sword has just gone into the table at `spot`: the wood cracks round it,
## dust and splinters fly, the blade flashes and hums.
func _sword_lands(sword: SwordFx, spot: Vector2, heft: float) -> void:
	var speed: float = table._speed
	_snd("contribute")
	_snd("fx_sword_stick")
	var crack := CrackFx.new()
	crack.position = spot
	add_child(crack)
	move_child(crack, 0)
	crack.create_tween().tween_property(crack, "grow", 1.0, 0.12 / speed).set_ease(Tween.EASE_OUT)
	_duel_marks.append(crack)
	sword.quiver = 1.0
	sword.create_tween().tween_property(sword, "quiver", 0.0, 0.9 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sword.shine()
	flash(Color(1.0, 0.95, 0.85, 0.12 * heft), 0.12)
	burst(spot, EARTH.lightened(0.45), int(12 * heft), 150.0, 0.5, 120.0, 5.0)
	burst(spot, SPLINTERS, int(8 * heft), 260.0, 0.45, 700.0, 4.0)
	burst(spot, Color("ffe9a0"), int(6 * heft), 220.0, 0.25, 0.0, 3.0)
	ring(spot, Color.WHITE, 4.0, 46.0 * heft, 0.22, 3.0)
	ring(spot, UI.GOLD, 4.0, 28.0 * heft, 0.3, 2.0)
	table._shake_screen(5.0 * heft)


## The sword is drawn back, takes aim and is thrown at the box of `victim`;
## as it goes in the table drops into slow motion for a moment: the blow,
## heard and felt. The loss of Morale follows (table._anim_damage).
func _stab_box(sword: SwordFx, victim: PlayerState) -> void:
	if not is_instance_valid(sword):
		return
	var speed: float = table._speed
	var rect := _box_rect(victim)
	var spot := _edge(rect, sword.position, 12.0)
	if victim == table.viewer:
		spot = Vector2(clampf(sword.position.x, rect.position.x + 40.0, rect.end.x - 40.0), rect.position.y + 12.0)
	var way := (spot - sword.position).normalized()
	var tip := way * SwordFx.TIP * SwordFx.PIXEL
	# Drawn back, slowly, shaking with it; then thrown hard.
	_snd("fx_sword_draw")
	# The swing comes in under the wind-up: its loudest is the blow.
	table._play_sfx_later("sword-attack", ATTACK_LEAD)
	var back := sword.create_tween().set_parallel()
	back.tween_property(sword, "rotation", sword.rotation + angle_difference(sword.rotation, way.angle()), 0.3 / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(sword, "position", sword.position - way * SWORD_WIND * 1.5, 0.4 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.tween_property(sword, "quiver", 0.6, 0.4 / speed)
	ring(sword.position, BLOOD, 60.0, 8.0, 0.4, 3.0)
	await _wait(0.45)
	if not is_instance_valid(sword):
		return
	sword.quiver = 0.0
	sword.trail = 1.0
	sword.shine()
	var from := sword.position
	var lands := spot - tip + way * SWORD_SUNK * SwordFx.PIXEL
	var fly := sword.create_tween().set_parallel()
	fly.tween_property(sword, "position", lands, 0.16 / speed).set_ease(Tween.EASE_IN)
	fly.tween_property(sword, "sunk", float(SWORD_SUNK), 0.06 / speed).set_delay(0.1 / speed)
	line(from + tip, spot, Color(STEEL, 0.6), 8.0, 0.3)
	line(from + tip, spot, Color.WHITE, 2.0, 0.22)
	await _wait(0.1)
	# The last stretch, and the blow, slowed right down.
	var slowed := _slow_down()
	await _wait(0.06)
	if not is_instance_valid(sword):
		if slowed:
			_speed_up(0.3)
		return
	sword.trail = 0.0
	_snd("fx_sword_impale")
	flash(Color(BLOOD, 0.4), 0.35)
	flash(Color(1, 1, 1, 0.3), 0.08)
	burst(spot, BLOOD, 30, 300.0, 0.7, 500.0, 6.0)
	burst(spot, BLOOD.darkened(0.3), 12, 180.0, 0.9, 300.0, 4.0)
	burst(spot, STEEL, 10, 260.0, 0.4, 300.0, 4.0)
	burst(spot, Color("ffe9a0"), 8, 300.0, 0.25, 0.0, 3.0)
	ring(spot, Color.WHITE, 6.0, 90.0, 0.3, 5.0)
	ring(spot, BLOOD, 6.0, 140.0, 0.5, 4.0)
	sword.quiver = 1.0
	sword.create_tween().tween_property(sword, "quiver", 0.0, 1.1 / speed)
	sword.shine()
	table._shake_screen(18.0)
	if slowed:
		await get_tree().create_timer(DAMAGE_HOLD, true, false, true).timeout
		_speed_up(0.35)
	await _wait(0.2)


## Takes the table into slow motion for a blow, unless it is in it already
## (the last blow of the match is the table's: see table._last_blow). Only
## the picture: the sound of the blow keeps its pace (slowed down, it was
## ugly). True if it did, for the caller to bring it back (_speed_up).
func _slow_down() -> bool:
	if table._slowed:
		return false
	table._glide_time(DAMAGE_SLOW, 0.05, false)
	return true


func _speed_up(seconds: float) -> void:
	table._glide_time(1.0, seconds, false)


## The two swords fly at each other, turning as they go, meet point to point
## at `meet` and break: the blades fly off in pieces, the hilts drop.
func _swords_cross(swords: Array, meet: Vector2) -> void:
	var speed: float = table._speed
	for sword: Variant in swords:
		if not is_instance_valid(sword):
			continue
		var way: Vector2 = (meet - sword.position).normalized()
		var back: Tween = sword.create_tween().set_parallel()
		back.tween_property(sword, "rotation", sword.rotation + angle_difference(sword.rotation, way.angle()), 0.25 / speed)
		back.tween_property(sword, "position", sword.position - way * SWORD_WIND, 0.25 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		back.tween_property(sword, "quiver", 0.5, 0.25 / speed)
	# The swing, timed so that its loudest is where they meet.
	table._play_sfx_later("sword-attack", CROSS_LEAD)
	await _wait(0.3)
	for sword: Variant in swords:
		if not is_instance_valid(sword):
			continue
		var way: Vector2 = (meet - sword.position).normalized()
		var from: Vector2 = sword.position
		var to: Vector2 = meet - way * (SwordFx.TIP * SwordFx.PIXEL + 2.0)
		sword.quiver = 0.0
		sword.trail = 1.0
		sword.create_tween().tween_property(sword, "position", to, 0.16 / speed).set_ease(Tween.EASE_IN)
		line(from + way * SwordFx.TIP * SwordFx.PIXEL, meet, Color(STEEL, 0.5), 6.0, 0.25)
	await _wait(0.16)
	_snd("sword-clash")
	table._play_sfx_later("sword-break", BREAK_LAG)
	flash(Color(1.0, 0.97, 0.88, 0.55), 0.22)
	burst(meet, Color("ffe9a0"), 26, 400.0, 0.45, 200.0, 4.0)
	burst(meet, Color.WHITE, 10, 300.0, 0.2, 0.0, 3.0)
	burst(meet, STEEL, 18, 320.0, 0.7, 600.0, 5.0)
	ring(meet, Color.WHITE, 6.0, 120.0, 0.3, 6.0)
	ring(meet, UI.GOLD, 6.0, 70.0, 0.4, 3.0)
	table._float(Loc.t("CLASH!"), meet + Vector2(0, -44), STEEL, 26)
	table._shake_screen(12.0)
	for sword: Variant in swords:
		if is_instance_valid(sword):
			sword.trail = 0.0
			_break_sword(sword, meet)
	# Broken: they free themselves, there is nothing left to put away.
	_duel.clear()
	await _wait(0.9)


## `sword` gives way: what is past SwordFx.SNAP flies off spinning, the hilt
## and the stump drop to the table and fade.
func _break_sword(sword: SwordFx, from: Vector2) -> void:
	var speed: float = table._speed
	var piece := SwordFx.new()
	piece.keep_from = SwordFx.SNAP
	# Where it broke, kept: the sword itself is gone before the piece lands.
	var start := sword.position
	piece.position = start
	piece.rotation = sword.rotation
	piece.trail = 0.7
	add_child(piece)
	sword.keep_to = SwordFx.SNAP - 1
	var away := (sword.position - from).normalized().rotated(randf_range(-0.6, 0.6))
	var flung := piece.create_tween().set_parallel()
	flung.tween_method(func(t: float) -> void:
		piece.position = start + away * 260.0 * t + Vector2(0, -120.0 * t + 420.0 * t * t), 0.0, 1.0, 0.8 / speed)
	flung.tween_property(piece, "rotation", piece.rotation + randf_range(8.0, 12.0) * signf(away.x if away.x != 0.0 else 1.0), 0.8 / speed)
	flung.tween_property(piece, "modulate:a", 0.0, 0.3 / speed).set_delay(0.5 / speed)
	flung.chain().tween_callback(piece.queue_free)
	var drop := sword.create_tween().set_parallel()
	drop.tween_property(sword, "position", sword.position + Vector2(-away.x * 30.0, 70.0), 0.5 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(sword, "rotation", sword.rotation + randf_range(-1.2, 1.2), 0.5 / speed)
	drop.tween_property(sword, "modulate:a", 0.0, 0.3 / speed).set_delay(0.4 / speed)
	drop.chain().tween_callback(sword.queue_free)


## Takes the swords of a Prisoner's Dilemma, and the cracks they left, off
## the table.
func drop_duel() -> void:
	for thing: Variant in _duel.values() + _duel_marks:
		if is_instance_valid(thing):
			var leave: Tween = thing.create_tween()
			leave.tween_property(thing, "modulate:a", 0.0, 0.3 / table._speed)
			leave.tween_callback(thing.queue_free)
	_duel.clear()
	_duel_marks.clear()


## The fury builds up in whoever goes berserk: their box turns red and burns,
## the table goes dark round it, and a sword comes out, red hot and shaking,
## pointed at what it is going to go through. It waits there: the Morale is
## given up as the play resolves (berserk_spent) and the items go one by one
## (item_pierced).
func _fx_duelist_berserk(play: Play) -> void:
	drop_berserk()
	var speed: float = table._speed
	var berserker: PlayerState = play.target if play.reflected else play.actor
	var victim := play.target
	var rect := _box_rect(berserker)
	var fury := FuryFx.new()
	fury.rect = rect
	add_child(fury)
	var box: Control = table._node_of(berserker)
	var tint := box.modulate if box != null else Color.WHITE
	# The growl, and under it a heart racing faster and faster.
	_snd("fx_fury")
	_snd("fx_heartbeat")
	dim(0.4, FURY_BUILD + 0.5)
	fury.create_tween().tween_property(fury, "heat", 1.0, FURY_BUILD / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if box != null:
		box.create_tween().tween_property(box, "modulate", Color(1.3, 0.62, 0.55, tint.a), FURY_BUILD / speed)
	# Out of the box of whoever plays it: a mirror's holder, if it was turned.
	var post := _sword_post(play.actor)
	var aim: Vector2 = table._item_spot(victim, maxi(victim.items.size() - 1, 0))
	var sword := SwordFx.new()
	sword.position = post
	sword.rotation = (aim - post).angle()
	sword.scale = Vector2(0.2, 0.2)
	sword.modulate.a = 0.0
	sword.glow = 0.0
	add_child(sword)
	_berserk = {"sword": sword, "fury": fury, "by": berserker, "box": box, "tint": tint}
	var out := sword.create_tween().set_parallel()
	out.tween_property(sword, "modulate:a", 1.0, 0.2 / speed)
	out.tween_property(sword, "scale", Vector2.ONE, 0.4 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	out.tween_property(sword, "glow", 1.0, FURY_BUILD / speed)
	out.tween_property(sword, "quiver", 1.0, FURY_BUILD / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# A pulse on every beat of the heart: the gaps are those of fx_heartbeat.
	var middle := rect.get_center()
	var at := 0.0
	var gap := HEARTBEAT_FIRST
	while at < FURY_BUILD - 0.08:
		var k := at / FURY_BUILD
		ring(middle, FURY, maxf(rect.size.x, rect.size.y) * 0.8, 10.0, 0.3, 3.0 + 4.0 * k)
		rise(middle + Vector2(0, rect.size.y * 0.3), FURY.lerp(EMBER, randf()), int(3 + 7 * k), rect.size.x * 0.4)
		table._shake_screen(1.0 + 4.0 * k)
		await _wait(gap)
		at += gap
		gap = maxf(gap * HEARTBEAT_HURRY, HEARTBEAT_FASTEST)
	await _wait(0.1)


## True while the sword of a Berserk is out over the table.
func berserking() -> bool:
	return not _berserk.is_empty() and is_instance_valid(_berserk.sword)


## The Morale of a Berserk goes, from `heart_at`: the heart bursts, the fury
## breaks loose and the sword is drawn back to be thrown.
func berserk_spent(who: PlayerState, heart_at: Vector2) -> void:
	var speed: float = table._speed
	var sword: SwordFx = _berserk.sword
	_snd("damage")
	flash(Color(FURY, 0.35), 0.3)
	burst(heart_at, BLOOD, 24, 300.0, 0.6, 400.0, 6.0)
	burst(heart_at, FURY.lightened(0.3), 10, 200.0, 0.4, 0.0, 4.0)
	ring(heart_at, FURY, 6.0, 80.0, 0.3, 5.0)
	table._float(Loc.t("BERSERK!"), _at(who) + Vector2(0, -34), FURY.lightened(0.25), 30)
	table._shake_screen(14.0)
	var fury: FuryFx = _berserk.fury
	if is_instance_valid(fury):
		var flare := fury.create_tween()
		flare.tween_property(fury, "heat", 1.6, 0.12 / speed)
		flare.tween_property(fury, "heat", 0.0, 0.6 / speed)
	var box: Control = _berserk.box
	if box != null and is_instance_valid(box):
		box.create_tween().tween_property(box, "modulate", _berserk.tint, 0.6 / speed)
	if is_instance_valid(sword):
		var way := Vector2.from_angle(sword.rotation)
		sword.create_tween().tween_property(sword, "position", sword.position - way * SWORD_WIND, 0.25 / speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.4)


## The sword of a Berserk goes through the item at `at` at full speed and on
## past it, where it waits for the next one. `gone` is called as it goes
## through: from then on the item is not in the inventory.
func item_pierced(texture: Texture2D, at: Vector2, item_size: Vector2, gone: Callable) -> void:
	var sword: SwordFx = _berserk.sword
	var speed: float = table._speed
	var from := sword.position
	var tip := Vector2.from_angle(sword.rotation) * SwordFx.TIP * SwordFx.PIXEL
	var way := (at - (from + tip)).normalized() if at.distance_to(from + tip) > 1.0 else Vector2.from_angle(sword.rotation)
	tip = way * SwordFx.TIP * SwordFx.PIXEL
	sword.rotation = way.angle()
	var lands := at - tip + way * SWORD_THROUGH
	sword.trail = 1.0
	_snd("fx_sword_whoosh")
	sword.create_tween().tween_property(sword, "position", lands, 0.1 / speed).set_ease(Tween.EASE_IN)
	line(from + tip, at + way * SWORD_THROUGH, Color(FURY, 0.7), 8.0, 0.3)
	line(from + tip, at + way * SWORD_THROUGH, Color.WHITE, 2.0, 0.2)
	await _wait(0.07)
	gone.call()
	_snd("fx_sword_pierce")
	var wreck: TextureRect = _sprite(texture, at, item_size)
	wreck.pivot_offset = item_size / 2.0
	var apart := wreck.create_tween().set_parallel()
	apart.tween_property(wreck, "scale", Vector2.ONE * 1.6, 0.2 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	apart.tween_property(wreck, "rotation", 0.5 * signf(way.x if way.x != 0.0 else 1.0), 0.2 / speed)
	apart.tween_property(wreck, "modulate", Color(1.0, 0.35, 0.3, 0.0), 0.24 / speed)
	apart.chain().tween_callback(wreck.queue_free)
	burst(at, STEEL, 14, 300.0, 0.45, 400.0, 5.0)
	burst(at, FURY, 10, 240.0, 0.4, 300.0, 4.0)
	ring(at, Color.WHITE, 4.0, 50.0, 0.22, 4.0)
	table._shake_screen(7.0)
	await _wait(0.3)


## The sword of a Berserk goes through where the items should be (`at`) and
## finds nothing: it carries on and off the table.
func sword_missed(at: Vector2) -> void:
	var sword: SwordFx = _berserk.sword
	var speed: float = table._speed
	var from := sword.position
	var way := (at - from).normalized() if at.distance_to(from) > 1.0 else Vector2.from_angle(sword.rotation)
	sword.rotation = way.angle()
	_snd("fx_sword_whoosh")
	sword.create_tween().tween_property(sword, "position", from + way * 1400.0, 0.5 / speed).set_ease(Tween.EASE_IN)
	line(from, from + way * 600.0, Color(FURY, 0.5), 6.0, 0.35)
	await _wait(0.12)
	table._float(Loc.t("NOTHING THERE"), at, UI.MUTED, 16)
	await _wait(0.35)


## Takes the sword and the fury of a Berserk off the table.
func drop_berserk() -> void:
	if _berserk.is_empty():
		return
	var speed: float = table._speed
	var sword: SwordFx = _berserk.sword
	if is_instance_valid(sword):
		var leave := sword.create_tween().set_parallel()
		leave.tween_property(sword, "modulate:a", 0.0, 0.3 / speed)
		leave.tween_property(sword, "glow", 0.0, 0.3 / speed)
		leave.chain().tween_callback(sword.queue_free)
	var fury: FuryFx = _berserk.fury
	if is_instance_valid(fury):
		var cool := fury.create_tween()
		cool.tween_property(fury, "heat", 0.0, 0.3 / speed)
		cool.tween_callback(fury.queue_free)
	var box: Control = _berserk.box
	if box != null and is_instance_valid(box):
		box.create_tween().tween_property(box, "modulate", _berserk.tint, 0.3 / speed)
	_berserk = {}


# --- the Clown ----------------------------------------------------------------

const CLOWN_GUN := "res://assets/ui/clown_gun.png"
const CLOWN_GUN_SIZE := Vector2(92, 96)
## How far from the shooter's anchor the gun is held.
const CLOWN_GUN_HELD := 80.0
## The mouth of the barrel, in pixels of the art (61x64, barrel to the left):
## up in the slide, well above the middle of the picture.
const CLOWN_BORE := Vector2(2, 20)
## How long the gun trembles, aimed, before it goes off.
const CLOWN_SUSPENSE := 0.55
## How far a box ducks under the shot.
const CLOWN_DUCK := 34.0
## The Laughter: how many HA!s are thrown at each player laughed at, how long
## apart, and how long each one flies.
const CLOWN_VOLLEY := 4
const CLOWN_VOLLEY_GAP := 0.14
const CLOWN_HA_FLIGHT := 0.45
## The colours of the party: confetti, streamers, the laughs.
const PARTY := ConfettiFx.INKS

var _gun: TextureRect
var _gun_owner: PlayerState
var _gun_aim := Vector2.LEFT


## The circus gun is twirled on a finger and comes to rest aimed at the
## target. It stays out, aimed, while they make up their mind: whether it was
## loaded is shown only after (gun_fired).
func _fx_clown_bang(play: Play) -> void:
	_draw_gun(play.actor, play.target)
	await _wait(0.5)
	if is_instance_valid(_gun):
		_snd("item_roulette_cock")
		UI.pop(_gun, 1.12, 0.12)
	await _wait(0.2)


func _draw_gun(shooter: PlayerState, target: PlayerState) -> void:
	drop_gun()
	var here := _at(shooter)
	var there := _at(target)
	var aim := (there - here).normalized() if there != here else Vector2.LEFT
	# The art points its barrel to the left; flipped, the grip stays down.
	var gun := _sprite(UI.tex(CLOWN_GUN), here + aim * CLOWN_GUN_HELD, CLOWN_GUN_SIZE)
	gun.flip_v = aim.x > 0.0
	var aimed := aim.angle() - PI
	_gun = gun
	_gun_owner = shooter
	_gun_aim = aim
	# Spun round twice on a finger before it settles.
	gun.rotation = aimed + TAU * 2.0 * (1.0 if aim.x > 0.0 else -1.0)
	gun.scale = Vector2.ONE * 0.3
	gun.modulate.a = 0.0
	var speed: float = table._speed
	var draw := gun.create_tween().set_parallel()
	draw.tween_property(gun, "modulate:a", 1.0, 0.1 / speed)
	draw.tween_property(gun, "scale", Vector2.ONE, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	draw.tween_property(gun, "rotation", aimed, 0.45 / speed).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_snd("fx_lasso_spin")


## The gun of `d` (a gun_fired event) is shown: a shot, or a flag and the
## party out of an empty barrel, and the whole table laughing.
func gun_fired(d: Dictionary) -> void:
	var shooter: PlayerState = d.shooter
	var target: PlayerState = d.target
	if _gun == null or not is_instance_valid(_gun) or _gun_owner != shooter:
		_draw_gun(shooter, target)
		await _wait(0.45)
	var gun := _gun
	if gun == null or not is_instance_valid(gun):
		return
	var speed: float = table._speed
	var aim := _gun_aim
	var here := _at(shooter)
	var there := _at(target)
	var aimed := aim.angle() - PI

	# Whoever paid to duck is out of the way before anything goes off.
	var box: Control = table._node_of(target)
	var box_at := box.position if box != null else Vector2.ZERO
	if d.ducked and box != null:
		_snd("card_draw")
		table._float(Loc.t("DUCK!"), there + Vector2(0, -44), UI.CREAM, 22)
		var dip := box.create_tween()
		dip.tween_property(box, "position", box_at + Vector2(0, CLOWN_DUCK), 0.14 / speed) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _wait(0.25)

	# The gun trembles, aimed: loaded or not?
	var tremble := gun.create_tween()
	for i in 7:
		tremble.tween_property(gun, "rotation", aimed + (0.05 if i % 2 == 0 else -0.05), CLOWN_SUSPENSE / 7.0 / speed)
	tremble.tween_property(gun, "rotation", aimed, 0.03 / speed)
	await _wait(CLOWN_SUSPENSE)
	if not is_instance_valid(gun):
		return

	var muzzle := _muzzle(gun)
	if d.loaded:
		await _gun_shot(gun, aim, muzzle, there, d.ducked)
	else:
		await _gun_party(gun, aim, muzzle, there)

	if d.ducked and box != null and is_instance_valid(box):
		var up := box.create_tween()
		up.tween_property(box, "position", box_at, 0.2 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drop_gun()


## Where the mouth of the barrel of `gun` is right now, on the screen: the
## bore of the art, wherever the picture is turned, flipped and scaled to.
func _muzzle(gun: TextureRect) -> Vector2:
	var art := gun.texture.get_size() if gun.texture != null else Vector2(61, 64)
	var fit := minf(gun.size.x / art.x, gun.size.y / art.y)
	var bore := (gun.size - art * fit) / 2.0 + CLOWN_BORE * fit
	if gun.flip_v:
		bore.y = gun.size.y - bore.y
	return gun.position + gun.pivot_offset + ((bore - gun.pivot_offset) * gun.scale).rotated(gun.rotation)


## A real round: the shot and the recoil, and blood unless the target ducked
## under it.
func _gun_shot(gun: TextureRect, aim: Vector2, muzzle: Vector2, there: Vector2, ducked: bool) -> void:
	var speed: float = table._speed
	var aimed := aim.angle() - PI
	var kick := -0.45 if aim.x > 0.0 else 0.45
	var rest := gun.position
	_snd("item_death")
	burst(muzzle, Color("ffd060"), 12, 240.0, 0.18, 0.0)
	ring(muzzle, Color.WHITE, 6.0, 50.0, 0.15, 5.0)
	# Over the head of whoever ducked.
	var hit := there + Vector2(0, -CLOWN_DUCK * 2.0) if ducked else there
	line(muzzle, hit, Color("ffe9a0"), 5.0, 0.14, 0.04)
	flash(Color(1.0, 0.95, 0.8, 0.3), 0.12)
	var recoil := gun.create_tween()
	recoil.tween_property(gun, "position", rest - aim * 22.0, 0.04 / speed)
	recoil.parallel().tween_property(gun, "rotation", aimed + kick, 0.04 / speed)
	recoil.tween_property(gun, "position", rest, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(gun, "rotation", aimed, 0.25 / speed)
	await _wait(0.05)
	if ducked:
		table._float(Loc.t("MISSED"), hit, UI.MUTED, 18)
		table._shake_screen(4.0)
	else:
		burst(there, BLOOD, 22, 260.0, 0.55, 520.0)
		table._shake_screen(12.0)
	await _wait(0.5)


## An empty gun: out of the barrel comes a flag that says so, with confetti
## and streamers, and the Clown and the table laugh.
func _gun_party(gun: TextureRect, aim: Vector2, muzzle: Vector2, there: Vector2) -> void:
	# A low blow under it all, for the weight the shot doesn't have.
	_snd("fx_clown_thump")
	_snd("fx_party_blower")
	var party := ConfettiFx.new(table._speed)
	add_child(party)
	party.blast(muzzle, aim, 46, 9)
	UI.pop(gun, 1.15, 0.12)
	ring(muzzle, PARTY[0], 6.0, 40.0, 0.25, 3.0)
	table._shake_screen(4.0)
	await _wait(0.3)
	# The Clown laughs first, and then the table with him.
	_snd("fx_clown_laugh_%d" % randi_range(1, 5))
	await _wait(0.35)
	_snd("fx_crowd_laugh")
	for i in 3:
		table._float(Loc.t("HA!"), there + Vector2(randf_range(-46.0, 46.0), randf_range(-60.0, -20.0)), PARTY[(i * 2 + 1) % PARTY.size()], 18 + i * 2)
		await _wait(0.18)
	await _wait(0.65)


## Puts away a gun that never went off.
func drop_gun() -> void:
	if _gun != null and is_instance_valid(_gun):
		var gun := _gun
		var leave := gun.create_tween()
		leave.tween_property(gun, "modulate:a", 0.0, 0.2 / table._speed)
		leave.tween_callback(gun.queue_free)
	_gun = null
	_gun_owner = null


## The Clown splits his sides, the box shaking with it, and then throws a
## volley of HA!s (CLOWN_VOLLEY each) at every player he laughs at: each one
## spins over in an arc and smacks into their box.
func _fx_clown_laughter(play: Play) -> void:
	var clown := play.actor
	var here := _at(clown)
	_snd("fx_clown_laughter")
	var box: Control = table._node_of(clown)
	if box != null:
		UI.shake(box, 5.0, 0.9 / table._speed)
	for i in 4:
		table._float(Loc.t("HA!"), here + Vector2(randf_range(-56.0, 56.0), randf_range(-58.0, -14.0)), PARTY[i], 18 + i * 3)
		rise(here, PARTY[(i + 2) % PARTY.size()], 3, 46.0)
		await _wait(0.13)
	var butts: Array = table.engine.opponents(clown).filter(
		func(p: PlayerState) -> bool: return not p.statuses.is_empty() or p.coins <= 0)
	for shot in CLOWN_VOLLEY:
		for i in butts.size():
			var ink: Color = PARTY[(i * 3 + shot * 2 + 1) % PARTY.size()]
			_throw_ha(here, butts[i], ink)
		await _wait(CLOWN_VOLLEY_GAP)
	await _wait(CLOWN_HA_FLIGHT + 0.35)


## One HA! thrown from `from` at `target`: up in an arc, turning over as it
## flies, and a smack where it lands.
func _throw_ha(from: Vector2, target: PlayerState, ink: Color) -> void:
	var to := _at(target) + Vector2(randf_range(-30.0, 30.0), randf_range(-16.0, 10.0))
	var word := UI.label(Loc.t("HA!"), 22, ink, true)
	word.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	word.add_theme_constant_override("outline_size", 6)
	word.add_theme_color_override("font_outline_color", UI.INK)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(word)
	word.reset_size()
	word.pivot_offset = word.size / 2.0
	var start := from + Vector2(randf_range(-20.0, 20.0), -20.0)
	var height := randf_range(70.0, 130.0)
	# One whole turn, the way it goes: it lands the right way up.
	var turns := 1.0 if to.x >= start.x else -1.0
	_ha_step(0.0, word, start, to, height, turns)
	var fly := word.create_tween()
	fly.tween_method(_ha_step.bind(word, start, to, height, turns), 0.0, 1.0, CLOWN_HA_FLIGHT / table._speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly.tween_callback(_ha_lands.bind(word, to, target, ink))


func _ha_step(k: float, word: Label, start: Vector2, to: Vector2, height: float, turns: float) -> void:
	if not is_instance_valid(word):
		return
	var at := start.lerp(to, k) + Vector2(0, -height * 4.0 * k * (1.0 - k))
	word.position = at - word.size / 2.0
	word.rotation = TAU * turns * k
	word.scale = Vector2.ONE * (0.6 + 0.6 * sin(k * PI) + 0.2 * k)


func _ha_lands(word: Label, at: Vector2, target: PlayerState, ink: Color) -> void:
	_snd("fx_doll_hit")
	burst(at, ink, 7, 160.0, 0.35, 260.0)
	ring(at, ink.lightened(0.3), 4.0, 30.0, 0.2, 3.0)
	var box: Control = table._node_of(target)
	if box != null:
		UI.shake(box, 4.0, 0.15 / table._speed)
	if not is_instance_valid(word):
		return
	# Squashed against the box, then gone.
	var smack := word.create_tween()
	smack.tween_property(word, "scale", Vector2(1.5, 0.6), 0.05 / table._speed)
	smack.tween_property(word, "modulate:a", 0.0, 0.25 / table._speed)
	smack.tween_callback(word.queue_free)


# --- the Entity ---------------------------------------------------------------

## The light of the table is drawn in on the Entity from all round, in three
## images that never quite meet. The chains themselves are thrown on by the
## status as it lands (chains_fx.gd, kept by StatusFx).
func _fx_entity_entropy(play: Play) -> void:
	var here := _at(play.actor)
	dim(0.5, 1.6)
	_snd("fx_entropy")
	_prism_rings(here, 190.0, 40.0, 0.5, 4.0)
	await _wait(0.28)
	_prism_rings(here, 130.0, 24.0, 0.4, 3.0)
	await _wait(0.3)
	flash(Color(COSMOS, 0.14), 0.18)
	table._shake_screen(4.0)
	await _wait(0.1)


## A ring seen the way the Entity's things are: in red, in cyan and in white,
## a little apart.
func _prism_rings(at: Vector2, from_radius: float, to_radius: float, life: float, width: float) -> void:
	ring(at + Vector2(-PRISM_SPLIT, 0), Color(PrismFx.RED, 0.75), from_radius, to_radius, life, width)
	ring(at + Vector2(PRISM_SPLIT, 0), Color(PrismFx.CYAN, 0.75), from_radius, to_radius, life, width)
	ring(at, Color.WHITE, from_radius, to_radius, life, width)


## A point beside the box of `who`, `reach` out of it towards the middle of
## the table and clear of the edges of the screen.
func _beside(who: PlayerState, reach: float) -> Vector2:
	var here := _at(who)
	var edge: Vector2 = table._clear_of(table._node_of(who), here, POT, 0.0)
	var at := edge + (POT - edge).limit_length(reach)
	return Vector2(clampf(at.x, 80.0, size.x - 80.0), clampf(at.y, 80.0, size.y - 80.0))


## The chains of an Entropy break, all at once: `links` is where every link
## of them was (StatusFx.pieces). They fly apart hard, and then time all but
## stops for them: the pieces hang over the table, turning, until they are
## drawn together into what they pay (release_morale, release_coins).
## `borrowed` chains (see StatusFx.set_borrowed) break as badly as they were
## copied: all of it is seen and heard wrong until chains_paid().
func chains_break(who: PlayerState, links: Array[Vector2], borrowed := false) -> void:
	drop_debris()
	if links.is_empty():
		return
	if borrowed:
		corrupt()
	var speed: float = table._speed
	var centre := Vector2.ZERO
	for link: Vector2 in links:
		centre += link / links.size()
	var debris := DebrisFx.new()
	debris.speed = speed
	debris.room = Rect2(Vector2.ZERO, size).grow(-14.0)
	add_child(debris)
	debris.scatter(links, centre)
	_debris = debris
	_debris_owner = who
	# The iron is a recording; the deep of it and what hangs after are not.
	_snd("fx_chains_break")
	_snd("fx_supernova")
	flash(Color(1.0, 1.0, 1.0, 0.45), 0.22)
	_prism_rings(centre, 24.0, 260.0, 0.45, 6.0)
	ring(centre, COSMOS.lightened(0.3), 10.0, 150.0, 0.7, 3.0)
	burst(centre, Color.WHITE, 16, 460.0, 0.28, 0.0, 6.0)
	table._shake_screen(12.0)
	var slow := debris.create_tween()
	slow.tween_interval(DEBRIS_BLAST / speed)
	slow.tween_property(debris, "pace", DEBRIS_PACE, 0.22 / speed).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await _wait(0.85)


## The chains of an Entropy thrown away (their owner called LIAR!): a
## singularity opens where they cross and takes them, `links`, straight in,
## link after link and whole. Nothing comes out of it. `borrowed` chains go
## as badly as they were copied.
func chains_swallowed(links: Array[Vector2], borrowed := false) -> void:
	if links.is_empty():
		return
	# Not over a disguise that is on: that look is somebody else's to end.
	var spoiled := borrowed and (_glitch == null or not is_instance_valid(_glitch))
	if spoiled:
		corrupt()
	var speed: float = table._speed
	var centre := Vector2.ZERO
	for link: Vector2 in links:
		centre += link / links.size()
	var chains := SwallowFx.new()
	add_child(chains)
	chains.lay(links, centre)
	var hole := SingularityFx.new()
	hole.speed = speed
	hole.position = centre
	add_child(hole)
	dim(0.5, SWALLOW + 1.0)
	_snd("fx_singularity")
	_prism_rings(centre, 90.0, 14.0, 0.4, 3.0)
	hole.create_tween().tween_property(hole, "open", 1.0, 0.35 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.4)
	if not is_instance_valid(hole) or not is_instance_valid(chains):
		return
	_snd("fx_chains")
	var feed := hole.create_tween().set_parallel()
	feed.tween_property(chains, "drawn", 1.0, SWALLOW / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	feed.tween_property(hole, "spin", 12.0, SWALLOW / speed)
	feed.tween_property(hole, "pull", 1.0, SWALLOW / speed)
	for beat: float in [0.0, 0.45, 0.8]:
		get_tree().create_timer(maxf(beat * SWALLOW, 0.01) / speed).timeout.connect(_drawn_in.bind(hole))
	await _wait(SWALLOW)
	if is_instance_valid(chains):
		chains.queue_free()
	if not is_instance_valid(hole):
		return
	# It shuts on what it took.
	table._shake_screen(4.0)
	table._float(Loc.t("WASTED"), centre + Vector2(0, -34), UI.MUTED, 18)
	var close := hole.create_tween()
	close.tween_property(hole, "open", 0.0, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close.tween_callback(hole.queue_free)
	await _wait(0.4)
	if spoiled:
		cleanse()


## True while the broken chains of `who` hang in the air.
func releasing(who: PlayerState) -> bool:
	return _debris != null and is_instance_valid(_debris) and _debris_owner == who


## The Morale the chains pay: some of the pieces wind in on one point, are a
## heart there and go to `to`, its place in the Morale of `who`.
func release_morale(who: PlayerState, to: Vector2) -> void:
	if not releasing(who):
		return
	var hearts := await _condense(0.4, UI.tex(HEART_ART), 1, Vector2(34, 34))
	for heart: PrismFx in hearts:
		_send(heart, to, 0.5, 0.0)
	await _wait(0.34)
	ring(to, Color("ff7a8c"), 4.0, 26.0, 0.3, 3.0)


## The coins the chains pay (`d` is their "coins" event): every piece left
## winds in on a row of points, they are coins there and go to the purse one
## after the other, counted in as they land.
func release_coins(d: Dictionary) -> void:
	var who: PlayerState = d.player
	var total: int = d.delta
	var purse: Vector2 = table._coin_anchor(who)
	var bar: StatBar = table._stat_bar(who)
	var count := clampi(total, 1, DEBRIS_COINS)
	var coins := await _condense(1.0, UI.tex(COIN_ART), count, Vector2(24, 24))
	drop_debris()
	if coins.size() != count:
		for coin: PrismFx in coins:
			coin.queue_free()
		return
	if bar != null:
		bar.hold_coins(who)
	for i in count:
		var share := total * (i + 1) / count - total * i / count
		_send(coins[i], purse, 0.8, i * 0.09)
		get_tree().create_timer((0.3 + i * 0.09) / table._speed).timeout.connect(_coin_home.bind(bar, share, purse, i))
	await _wait(0.34 + count * 0.09)


## `share` of the pieces still loose wind in on `count` points beside whoever
## was in chains and are `texture` there, `extent` across: its three images
## come together as it forms. Returns those pictures (PrismFx), whole; none
## if the pieces are gone.
func _condense(share: float, texture: Texture2D, count: int, extent: Vector2) -> Array:
	var debris := _debris
	var made: Array = []
	if debris == null or not is_instance_valid(debris):
		return made
	var speed: float = table._speed
	var around := _beside(_debris_owner, 64.0)
	var each := maxi(int(debris.loose() * share / count), 1)
	_snd("fx_stardust")
	for i in count:
		var spot := around + Vector2((i - (count - 1) / 2.0) * (extent.x + 4.0), 0.0 if i % 2 == 0 else -8.0)
		var wait := i * CONDENSE_STAGGER
		var batch := debris.gather(each, spot)
		var wind := debris.create_tween()
		if wait > 0.0:
			wind.tween_interval(wait / speed)
		wind.tween_method(debris.pull.bind(batch), 0.0, 1.0, CONDENSE / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wind.tween_callback(debris.absorb.bind(batch))
		var prism := PrismFx.new(texture, extent)
		prism.position = spot
		prism.split = 12.0
		prism.scale = Vector2.ONE * 0.3
		prism.modulate.a = 0.0
		add_child(prism)
		var born := (wait + CONDENSE * 0.6) / speed
		var show := prism.create_tween().set_parallel()
		show.tween_property(prism, "modulate:a", 1.0, 0.25 / speed).set_delay(born)
		show.tween_property(prism, "scale", Vector2.ONE, 0.36 / speed).set_delay(born).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		show.tween_property(prism, "split", 0.0, 0.4 / speed).set_delay(born)
		made.append(prism)
	await _wait(CONDENSE + (count - 1) * CONDENSE_STAGGER + 0.12)
	return made.filter(func(prism: Variant) -> bool: return is_instance_valid(prism))


## Sends `thing` to `to`, shrinking to `shrink` of its size, and is done with it.
func _send(thing: Control, to: Vector2, shrink: float, delay: float) -> void:
	var speed: float = table._speed
	var go := thing.create_tween()
	if delay > 0.0:
		go.tween_interval(delay / speed)
	go.tween_property(thing, "position", to, 0.3 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	go.parallel().tween_property(thing, "scale", Vector2.ONE * shrink, 0.3 / speed)
	go.tween_callback(thing.queue_free)


## A coin of the chains lands in the pile at `at` and is counted in.
func _coin_home(bar: StatBar, share: int, at: Vector2, index: int) -> void:
	if bar != null:
		bar.add_coins(share)
	_snd("coin_%d" % (index % 3 + 1))
	burst(at, UI.GOLD, 3, 90.0, 0.2, 300.0, 4.0)


## The chains have paid all they were going to: what is left of them goes,
## and so does the look of borrowed ones (see chains_break).
func chains_paid() -> void:
	drop_debris()
	if _glitch != null and is_instance_valid(_glitch) and _glitch.disguise == null:
		cleanse()


## Lets go of the pieces of the chains nothing was made of.
func drop_debris() -> void:
	if _debris != null and is_instance_valid(_debris):
		var leave := _debris.create_tween()
		leave.tween_property(_debris, "modulate:a", 0.0, 0.5 / table._speed)
		leave.tween_callback(_debris.queue_free)
	_debris = null
	_debris_owner = null


## A hole the size of a coin opens beside the Entity: black, with every
## colour going round it. What is fed to it comes later: the coins as they
## are paid (hoard_cost, which may have opened it already), the Morale as it
## is given up (spaghettify).
func _fx_entity_materialize(play: Play) -> void:
	var fresh := not materializing(play.actor)
	_open_hole(play.actor)
	await _wait(0.45 if fresh else 0.15)


func _open_hole(who: PlayerState) -> SingularityFx:
	if materializing(who):
		return _hole
	drop_hole()
	var speed: float = table._speed
	var hole := SingularityFx.new()
	hole.speed = speed
	hole.whirl_speed = WHIRL_SLOW
	hole.reach = ORBIT
	hole.position = _beside(who, HOLE_REACH)
	add_child(hole)
	_hole = hole
	_hole_owner = who
	_snd("fx_singularity")
	_prism_rings(hole.position, 90.0, 14.0, 0.4, 3.0)
	hole.create_tween().tween_property(hole, "open", 1.0, 0.4 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return hole


## True while the singularity of `who` is open with nothing made yet.
func materializing(who: PlayerState) -> bool:
	return _hole != null and is_instance_valid(_hole) and _hole_owner == who and not _made


## The coins a Materialize costs on top of the Morale (`d` is their "coins"
## event): they leave the purse for the singularity, which opens now if it
## was not open yet, and go round it, waiting for the Morale.
func hoard_cost(d: Dictionary) -> void:
	var who: PlayerState = d.player
	var total: int = -d.delta
	var hole := _open_hole(who)
	var purse: Vector2 = table._coin_anchor(who)
	var bar: StatBar = table._stat_bar(who)
	if bar != null:
		bar.hold_coins(who)
	var count := clampi(total, 1, DEBRIS_COINS)
	_snd("spend")
	for i in count:
		var share := total * (i + 1) / count - total * i / count
		hole.take(UI.tex(COIN_ART), Vector2(20, 20), purse, TAU * i / count, i * 0.1, 0.4)
		table._count_coins(bar, -share, i * 0.1)
	await _wait(0.45 + count * 0.1)


## The Morale `who` gave up for a Materialize. The heart leaves its place at
## `from` for the singularity and goes round it with whatever coins are
## there already, faster and faster, drawn out longer and thinner, until on
## one of the turns what comes round is `item`. That slows down, is itself
## again and goes on round the singularity, for item_materialized.
## `label` is what the table calls it.
func spaghettify(who: PlayerState, from: Vector2, item: Texture2D, label: String) -> void:
	if not materializing(who) or item == null:
		return
	var hole := _hole
	var speed: float = table._speed
	var at := hole.position
	dim(0.55, SPIN_UP + UNWIND + 0.9)
	hole.take(UI.tex(HEART_ART), Vector2(26, 26), from, PI, 0.0, 0.4)
	_snd("fx_spaghettify")
	await _wait(0.4)
	if not is_instance_valid(hole):
		return
	var wind := hole.create_tween().set_parallel()
	wind.tween_property(hole, "whirl_speed", WHIRL_FAST, SPIN_UP / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	wind.tween_property(hole, "stretch", NOODLE, SPIN_UP / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	wind.tween_property(hole, "reach", ORBIT_TIGHT, SPIN_UP / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wind.tween_property(hole, "spin", 16.0, SPIN_UP / speed)
	wind.tween_property(hole, "pull", 1.0, SPIN_UP / speed)
	# The table is drawn in with it, at a quickening beat.
	for beat: float in [0.0, 0.55, 1.0, 1.35, 1.62, 1.82, 1.96]:
		get_tree().create_timer(maxf(beat * SPIN_UP / 2.1, 0.01) / speed).timeout.connect(_drawn_in.bind(hole))
	await _wait(SPIN_UP)
	if not is_instance_valid(hole):
		return

	# One more turn, and it is something else that comes round.
	hole.become(item, MADE)
	_snd("fx_materialize")
	flash(Color(0.85, 0.75, 1.0, 0.4), 0.2)
	_prism_rings(at, 16.0, 150.0, 0.4, 5.0)
	burst(at, Color.WHITE, 14, 300.0, 0.4, 0.0, 6.0)
	burst(at, COSMOS.lightened(0.3), 12, 200.0, 0.5, -30.0)
	table._shake_screen(8.0)
	var settle := hole.create_tween().set_parallel()
	settle.tween_property(hole, "whirl_speed", 3.0, UNWIND / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(hole, "stretch", 0.0, UNWIND / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(hole, "reach", ORBIT, UNWIND / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle.tween_property(hole, "spin", 2.0, UNWIND / speed)
	settle.tween_property(hole, "pull", 0.0, UNWIND / speed)
	await _wait(UNWIND)
	if not is_instance_valid(hole):
		return

	# It is a thing now, and goes on round the hole until it is somebody's
	# (item_materialized).
	_made = true
	_made_at = at
	ring(at, Color.WHITE, 10.0, 60.0, 0.3, 3.0)
	table._float(label, at + Vector2(0, -ORBIT - MADE.y / 2.0 - 6.0), UI.BLUE)
	await _wait(0.2)


## A closing ring about the singularity: everything near it leans in.
func _drawn_in(hole: SingularityFx) -> void:
	if is_instance_valid(hole):
		_prism_rings(hole.position, 84.0, 16.0, 0.3, 2.0)


## True while what `who` made out of Morale goes round the hole, not yet theirs.
func made_for(who: PlayerState) -> bool:
	return _made and _hole != null and is_instance_valid(_hole) and _hole_owner == who


## Where the singularity of `who` was: the change of a Materialize comes out
## of there. Vector2.INF if there was none.
func made_at(who: PlayerState) -> Vector2:
	return _made_at if _hole_owner == who else Vector2.INF


## What was made leaves the turn it was on for `home`, its place in the
## inventory, without ever stopping: it goes on round, on a circle that opens
## wide and then closes on `home`, shrinking to `shrink` of its size and
## coming upright on the way. The hole closes behind it.
func item_materialized(home: Vector2, shrink: float) -> void:
	var hole := _hole
	var made := _made
	_hole = null
	_made = false
	if hole == null or not is_instance_valid(hole):
		return
	var speed: float = table._speed
	var picture := hole.held()
	var pose := hole.pose()
	var turning := hole.whirl_speed
	var wide := hole.reach
	var hub := hole.position
	hole.clear()
	var close := hole.create_tween()
	close.tween_property(hole, "open", 0.0, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close.tween_callback(hole.queue_free)
	if not made or picture == null:
		return
	var item := PrismFx.new(picture, MADE)
	item.position = pose[0]
	item.rotation = pose[1]
	item.split = 5.0
	add_child(item)
	var way := {
		"hub": hub, "home": home, "wide": wide, "from": pose[1] - PI / 2.0,
		# It leaves at the speed it was going round at, and gathers more.
		"lead": turning * SLING, "sweep": maxf(SLING_SWEEP, turning * SLING),
		"swell": clampf(hub.distance_to(home) * SLING_SWELL, SLING_SWELL_MIN, SLING_SWELL_MAX),
		"upright": snappedf(pose[1], TAU), "shrink": shrink,
	}
	var fly := item.create_tween()
	fly.tween_method(_sling.bind(item, way), 0.0, 1.0, SLING / speed)
	await _wait(SLING)
	_snd("item_get")
	rise(home, COSMOS.lightened(0.4), 6, 16.0)
	if is_instance_valid(item):
		item.queue_free()


## One moment (`t`, 0 to 1) of the way of a made item from the hole to its
## place: it goes on round the hole on a circle that opens, then the middle
## of the circle sets off for the place while the circle closes to nothing.
func _sling(t: float, item: PrismFx, way: Dictionary) -> void:
	if not is_instance_valid(item):
		return
	var lead: float = way.lead
	var angle: float = way.from + lead * t + (way.sweep - lead) * t * t
	var middle: Vector2 = (way.hub as Vector2).lerp(way.home, smoothstep(SLING_STAY, 1.0, t))
	var wide: float = (way.wide + way.swell * smoothstep(0.0, 0.45, t)) * (1.0 - smoothstep(0.5, 1.0, t))
	item.position = middle + Vector2.from_angle(angle) * wide
	# Turned along its way at first, upright by the time it is there.
	var settled := smoothstep(0.4, 0.95, t)
	item.rotation = lerp_angle(angle + PI / 2.0, way.upright, settled)
	item.scale = Vector2.ONE * lerpf(1.0, way.shrink, smoothstep(0.5, 1.0, t))
	item.split = 5.0 * (1.0 - t)


## Closes a singularity nothing came out of, with whatever was going round it.
func drop_hole() -> void:
	if _hole != null and is_instance_valid(_hole):
		var close := _hole.create_tween()
		close.tween_property(_hole, "open", 0.0, 0.2 / table._speed)
		close.parallel().tween_property(_hole, "modulate:a", 0.0, 0.2 / table._speed)
		close.tween_callback(_hole.queue_free)
	_hole = null
	_hole_owner = null
	_made = false
	_made_at = Vector2.INF


## A coin thumbed into the air in front of `who`; it lands on its answer.
func coin_flip(who: PlayerState, heads: bool, won: bool) -> void:
	var here := _at(who)
	var speed: float = table._speed
	var coin: TextureRect = _sprite(UI.tex(COIN_ART), here, Vector2(44, 44))
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
	if won:
		_snd("coin_2")
		ring(at, UI.GOLD, 10.0, 76.0, 0.35, 5.0)
		burst(at, UI.GOLD, 16, 200.0, 0.5, 420.0)
		UI.pop(coin, 1.6, 0.25)
	else:
		_snd("coin_3")
		coin.modulate = Color(0.5, 0.46, 0.42)
		burst(at, SMOKE.lightened(0.2), 8, 90.0, 0.4, -20.0, 9.0)
	table._float(Loc.t("HEADS" if heads else "TAILS") + ("!" if won else ""), at + Vector2(0, -40), UI.GOLD if won else UI.MUTED, 28)
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
		var flask: TextureRect = _sprite(frames[0], here + Vector2(0, -34), Vector2(84, 88))
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
	var gun: TextureRect = _sprite(UI.tex(play.source.texture_path), here + aim * 80.0, Vector2(92, 96))
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


## All Is Color: the Painter's three paints whirl out round his box and
## settle, and the palette is set down (see PalettePick).
func _fx_painter_all_is_color(play: Play) -> void:
	var here := _at(play.actor)
	_snd("fx_brush")
	for i: int in Painter.PAINTS.size():
		var paint: Color = Painter.PAINTS[i]
		ring(here, paint, 8.0 + 6.0 * i, 70.0 + 14.0 * i, 0.5, 5.0)
		burst(here, paint, 8, 170.0, 0.5, 260.0, 6.0)
		await _wait(0.1)
	await _wait(0.25)


## Monochrome, as it is announced: the Painter's palette opens beside his
## box with the brush stirring the paint, and waits there for the two he
## chooses (paint_pair), which only comes once the table let the claim pass.
func _fx_painter_monochrome(play: Play) -> void:
	drop_paint()
	var kit := PaletteFx.new()
	kit.position = _beside(play.actor, 80.0)
	# Not under the stage, in the middle of the table: beside it.
	if kit.position.x > 330.0 and kit.position.x < 822.0 and kit.position.y > 190.0:
		kit.position.x = 300.0 if kit.position.x < POT.x else 852.0
		# Nor under the prompt, which sits just over the counter.
		kit.position.y = minf(kit.position.y, 360.0)
	kit.scale = Vector2.ZERO
	add_child(kit)
	var brush := BrushFx.new()
	brush.scale = Vector2.ONE * 1.8
	brush.position = kit.position + Vector2(0, -14)
	brush.modulate.a = 0.0
	add_child(brush)
	_paint_kit = {"palette": kit, "brush": brush, "actor": play.actor}
	_snd("fx_paint_dip")
	var open := kit.create_tween().set_parallel()
	open.tween_property(kit, "scale", Vector2.ONE, 0.35 / table._speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_property(kit, "rotation", 0.0, 0.35 / table._speed).from(-1.2)
	open.tween_property(brush, "modulate:a", 1.0, 0.2 / table._speed).set_delay(0.2 / table._speed)
	# Stirring, round and round the gobs, until the two are chosen.
	brush.set_meta(&"stir", true)
	await _wait(0.45)


## The two a Monochrome chose (players_painted): the brush dives into this
## round's colour, flies to each box dripping on the way and lays three
## strokes across it, back and forth, with a flick of drops at the end; then
## a thread of paint runs between the two boxes and the brush goes home. The
## strokes soak away into the paint the status leaves running down the boxes.
func paint_pair(d: Dictionary) -> void:
	var speed: float = table._speed
	var tint: Color = d.tint
	var painter: PlayerState = d.painter
	if _paint_kit.is_empty() or not is_instance_valid(_paint_kit.get("brush")):
		_fx_painter_monochrome(d.play)
		await _wait(0.4)
	var kit: PaletteFx = _paint_kit.palette
	var brush: BrushFx = _paint_kit.brush
	brush.set_meta(&"stir", false)
	# The dip: into the gob of this colour, and out loaded.
	var gob: Vector2 = kit.position + kit.gob(Painter.PAINTS.find(tint))
	brush.tint = tint
	kit.dipped = Painter.PAINTS.find(tint)
	var dip := brush.create_tween()
	dip.tween_property(brush, "position", gob + Vector2(0, -26), 0.18 / speed)
	dip.tween_property(brush, "position", gob, 0.12 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dip.tween_property(brush, "position", gob + Vector2(0, -34), 0.2 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.3)
	_snd("fx_paint_dip")
	burst(gob, tint, 10, 120.0, 0.45, 420.0, 4.0)
	await _wait(0.25)
	dim(0.32, 1.0 + 2.2 * d.pair.size())
	var strokes: Array = []
	var boxes: Array[Rect2] = []
	for p: PlayerState in d.pair:
		var holder: Variant = table._node_of(p)
		if holder == null:
			continue
		var box: Rect2 = holder.get_global_rect()
		# A big panel (the viewer's own) is painted along its top only.
		box = Rect2(box.position, Vector2(minf(box.size.x, 320.0), minf(box.size.y, 110.0)))
		boxes.append(box)
		await _brush_flight(brush, box.position + Vector2(-8, 14), tint)
		for row: int in 3:
			var y := box.size.y * (0.18 + 0.32 * row)
			var left := box.position + Vector2(-6, y)
			var right := box.position + Vector2(box.size.x + 6, y + 6.0 * (row - 1))
			var from := left if row % 2 == 0 else right
			var to := right if row % 2 == 0 else left
			var stroke := StrokeFx.new()
			stroke.thick = box.size.y * 0.36
			stroke.tint = tint
			stroke.from = from
			stroke.to = to
			add_child(stroke)
			move_child(stroke, brush.get_index())
			strokes.append(stroke)
			_snd("fx_brush")
			var sweep := brush.create_tween().set_parallel()
			sweep.tween_property(brush, "position", to, 0.26 / speed).from(from).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			sweep.tween_property(brush, "rotation", 0.35 if row % 2 == 0 else -0.6, 0.26 / speed)
			sweep.tween_property(stroke, "progress", 1.0, 0.26 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await _wait(0.27)
		# The flick: drops thrown off the brush across the box.
		_snd("fx_paint_flick")
		var tip := brush.position
		brush.create_tween().tween_property(brush, "rotation", -1.2, 0.08 / speed)
		burst(tip, tint, 18, 260.0, 0.6, 520.0, 4.0)
		burst(box.get_center(), tint.lightened(0.3), 8, 140.0, 0.4, 300.0, 6.0)
		_snd("fx_splat")
		await _wait(0.3)
	# The two are one colour now: a thread of paint runs from one to the other.
	if boxes.size() == 2:
		_snd("fx_paint_link")
		stream(boxes[0].get_center(), boxes[1].get_center(), tint, 18, 0.55, 0.4)
		stream(boxes[1].get_center(), boxes[0].get_center(), tint.lightened(0.25), 12, 0.55, 0.4)
		await _wait(0.5)
		for box: Rect2 in boxes:
			ring(box.get_center(), tint, 10.0, 90.0, 0.4, 5.0)
	for stroke: StrokeFx in strokes:
		var soak := stroke.create_tween()
		soak.tween_interval(0.3 / speed)
		soak.tween_property(stroke, "modulate:a", 0.0, 0.5 / speed)
		soak.tween_callback(stroke.queue_free)
	await _brush_flight(brush, kit.position + Vector2(0, -14), tint)
	drop_paint()
	await _wait(0.2)


## The brush on its way to `to`, in an arc, dripping `tint` as it goes.
func _brush_flight(brush: BrushFx, to: Vector2, tint: Color) -> void:
	var from := brush.position
	var lift := clampf(from.distance_to(to) * 0.3, 40.0, 140.0)
	# Never over the top of the screen: to the seats up there it dips instead.
	if minf(from.y, to.y) - lift < 24.0:
		lift = -lift * 0.6
	var dripped := [0.0]
	var time := clampf(from.distance_to(to) / 900.0, 0.25, 0.55)
	brush.create_tween().tween_method(func(t: float) -> void:
		brush.position = from.lerp(to, t) + Vector2(0, -lift * sin(t * PI))
		brush.rotation = lerpf(-0.4, 0.3, t)
		if t - dripped[0] > 0.12:
			dripped[0] = t
			burst(brush.position, tint, 1, 30.0, 0.7, 700.0, 4.0), 0.0, 1.0, time / table._speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(time)


## Whether a Monochrome's palette is open, waiting for its two.
func painting() -> bool:
	return not _paint_kit.is_empty() and is_instance_valid(_paint_kit.get("palette"))


func drop_paint() -> void:
	for key: String in ["palette", "brush"]:
		var node: Variant = _paint_kit.get(key)
		if node != null and is_instance_valid(node):
			var gone := (node as Control).create_tween()
			gone.tween_property(node, "modulate:a", 0.0, 0.25 / table._speed)
			gone.parallel().tween_property(node, "scale", Vector2.ONE * 0.3, 0.25 / table._speed)
			gone.tween_callback((node as Node).queue_free)
	_paint_kit = {}


## A painted player reached past the paint: a gob of their colour splashes
## off their box.
func paint_splash(who: PlayerState, paint: Color) -> void:
	var here := _at(who)
	_snd("fx_splat")
	burst(here + Vector2(0, -20), paint, 16, 220.0, 0.55, 480.0, 6.0)
	ring(here, paint, 10.0, 60.0, 0.3, 5.0)
	await _wait(0.45)


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


## A picture the effect puts on the table. It is kept under the effects, not
## on the table's own layer, so that whatever is done to them is done to it
## (see GlitchFx).
func _sprite(texture: Texture2D, center: Vector2, sprite_size: Vector2) -> TextureRect:
	var sprite: TextureRect = table._sprite(texture, center, sprite_size)
	sprite.reparent(self)
	return sprite


func _at(p: PlayerState) -> Vector2:
	return table._anchor(p)


func _snd(sound: String) -> void:
	table._play_sfx(sound)


func _wait(seconds: float) -> void:
	await table._wait(seconds)


func _wake() -> void:
	set_process(true)


## A Monochrome's palette and brush, open beside the Painter (see paint_pair):
## {palette, brush, actor}, or empty.
var _paint_kit: Dictionary = {}

func _ready() -> void:
	set_process(false)
	child_entered_tree.connect(_share_look)


## Whatever is put under the effects is drawn with their material, so that
## what spoils them (see GlitchFx) spoils all of it.
func _share_look(node: Node) -> void:
	if node is CanvasItem:
		# What a guest of a borrowed action (see step_in) puts down is its
		# own: it keeps out of the look of the effects, and its parts follow it.
		node.use_parent_material = node.get_parent() != self or _guests.is_empty()
	if not node.child_entered_tree.is_connected(_share_look):
		node.child_entered_tree.connect(_share_look)
	for child: Node in node.get_children():
		_share_look(child)


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


# --- the Necromancer ------------------------------------------------------------

const NECRO_BONE := Color("e8e0c8")
const NECRO_GLOW := Color("7dff9a")
const NECRO_DEEP := Color("1f8a4a")
## How far from the Necromancer's box the skull of a Retaliation rises.
const SKULL_REACH := 66.0
## How far it is drawn back before it is let go.
const SKULL_WIND := 24.0
const SKULL_FLIGHT := 0.32
## How far the soul of a Drain rises off the cards that were left.
const SOUL_RISE := 46.0
## How wide the soul swings round as it is reeled in.
const SOUL_SWING := 64.0
const SOUL_REEL := 0.95
## Where the soul waits, once swallowed, for the Morale it is worth.
const SOUL_ORBIT := 34.0

## The soul a Drain took, going round the Necromancer until its Morale comes
## (drain_morale), or null.
var _soul: SoulFx
var _soul_owner: PlayerState


## Retaliation. The wound the Necromancer has just taken bleeds up out of
## his box and the blood sets, cell by cell, into a skull, still smeared
## with it. Its eyes catch a
## green fire, it turns on whoever struck him and a thread of that blood
## shoots out to them; it chatters, draws back and is flung along the thread,
## screaming, eating it up as it goes, and bursts into bone on their box. The
## blow itself comes after (morale_lost). Turned by a mirror, the skull goes
## to the one who struck him all the same, glances off and comes back.
func _fx_necromancer_retaliation(play: Play) -> void:
	var speed: float = table._speed
	# Turned by a mirror, the play is its holder's, aimed at the Necromancer.
	var turned := play.reflected
	var caster: PlayerState = play.target if turned else play.actor
	var struck: PlayerState = play.actor if turned else play.target
	var here := _at(caster)
	var there := _at(struck)
	var spot := _beside(caster, SKULL_REACH)
	dim(0.6, 3.0 if turned else 2.6)

	# His voice over all of it: it swells to its worst as the skull is let go.
	_snd("retaliation")
	# The wound opens again and bleeds upwards.
	_snd("fx_necro_wound")
	var box: Control = table._node_of(caster)
	if box != null:
		var throb := box.create_tween()
		throb.tween_property(box, "modulate", Color(1.5, 0.45, 0.45), 0.08 / speed)
		throb.tween_property(box, "modulate", Color.WHITE, 0.5 / speed)
	burst(here, BLOOD, 12, 150.0, 0.45, 280.0, 6.0)
	stream(here, spot, BLOOD, 22, 0.42, 0.55)
	var skull := SkullFx.new()
	skull.speed = speed
	skull.position = spot
	skull.gaze = (there - spot).normalized()
	add_child(skull)
	await _wait(0.3)
	if not is_instance_valid(skull):
		return

	# It sets, still smeared with the blood it was made of.
	_snd("fx_bone_rattle")
	skull.create_tween().tween_property(skull, "formed", 1.0, 0.65 / speed).set_trans(Tween.TRANS_SINE)
	await _wait(0.65)
	if not is_instance_valid(skull):
		return
	skull.create_tween().tween_property(skull, "bloody", SkullFx.STAINED, 0.5 / speed)

	# Its eyes light, and it looks round at them.
	_snd("fx_soul_flare")
	var light := skull.create_tween().set_parallel()
	light.tween_property(skull, "eyes", 1.0, 0.15 / speed)
	light.tween_property(skull, "fire", 1.0, 0.4 / speed)
	ring(spot, NECRO_GLOW, 6.0, 64.0, 0.35, 4.0)
	burst(spot, NECRO_GLOW, 12, 150.0, 0.45, -140.0, 6.0)
	UI.pop(skull, 1.2)
	await _wait(0.3)
	if not is_instance_valid(skull):
		return

	# The thread of blood finds them.
	var thread := ThreadFx.new()
	thread.speed = speed
	thread.a = spot
	thread.b = there
	add_child(thread)
	move_child(thread, skull.get_index())
	_snd("fx_blood_thread")
	_snd("carnage")
	thread.create_tween().tween_property(thread, "reach", 1.0, 0.26 / speed) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await _wait(0.26)
	if not is_instance_valid(skull):
		return
	var marked: Control = table._node_of(struck)
	if marked != null:
		var blink := marked.create_tween()
		blink.tween_property(marked, "modulate", Color(1.5, 0.5, 0.5), 0.06 / speed)
		blink.tween_property(marked, "modulate", Color.WHITE, 0.3 / speed)
	# It lands on them wet.
	ring(there, BLOOD, 54.0, 8.0, 0.3, 4.0)
	burst(there, BLOOD, 16, 240.0, 0.45, 520.0, 7.0)
	burst(there, Color("6a0a0a"), 8, 140.0, 0.4, 400.0, 5.0)
	table._shake_screen(5.0)
	thread.create_tween().tween_property(thread, "slack", 2.0, 0.5 / speed).set_trans(Tween.TRANS_SINE)

	# It chatters at them, and is drawn back.
	_snd("fx_skull_chatter")
	skull.chatter = 1.0
	await _wait(0.42)
	if not is_instance_valid(skull):
		return
	var back := spot - (there - spot).normalized() * SKULL_WIND
	var wind := skull.create_tween().set_parallel()
	wind.tween_property(skull, "position", back, 0.18 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wind.tween_property(skull, "scale", Vector2(0.85, 1.15), 0.18 / speed)
	await _wait(0.2)
	if not is_instance_valid(skull):
		return

	# Let go, tearing through the cord.
	_snd("fx_skull_scream")
	_snd("carnage2")
	skull.chatter = 0.0
	skull.jaw = 1.0
	skull.trail = true
	skull.scale = Vector2(1.2, 0.85)
	skull.create_tween().tween_property(skull, "scale", Vector2.ONE, SKULL_FLIGHT / speed)
	var carry := func(k: float) -> void:
		if is_instance_valid(skull):
			skull.position = back.lerp(there, k)
		if is_instance_valid(thread):
			thread.eaten = k
	skull.create_tween().tween_method(carry, 0.0, 1.0, SKULL_FLIGHT / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(SKULL_FLIGHT)
	if not is_instance_valid(skull):
		return
	if is_instance_valid(thread):
		thread.queue_free()

	if turned:
		# Off the mirror, the way it came.
		_snd("item_mirror")
		ring(there, Color("bfe9f5"), 8.0, 90.0, 0.3, 4.0)
		burst(there, Color("bfe9f5"), 14, 220.0, 0.4, 0.0, 5.0)
		table._shake_screen(6.0)
		skull.gaze = (here - there).normalized()
		skull.create_tween().tween_property(skull, "rotation", TAU * (1.0 if here.x < there.x else -1.0), 0.4 / speed)
		var bounce := skull.create_tween()
		bounce.tween_property(skull, "position", here, 0.4 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _wait(0.4)
		if not is_instance_valid(skull):
			return
		there = here

	# It bursts on them.
	_snd("fx_skull_shatter")
	var shards := ShardsFx.new()
	shards.speed = speed
	shards.position = there
	shards.burst((there - spot).normalized())
	add_child(shards)
	skull.queue_free()
	burst(there, NECRO_GLOW, 16, 240.0, 0.5, -80.0, 6.0)
	burst(there, BLOOD, 18, 280.0, 0.6, 520.0)
	ring(there, Color.WHITE, 8.0, 84.0, 0.2, 5.0)
	ring(there, NECRO_GLOW, 10.0, 130.0, 0.45, 6.0)
	flash(Color(0.25, 0.9, 0.45, 0.18), 0.3)
	table._shake_screen(13.0)
	await _wait(0.45)


## Drain. Over the cards the fallen player left, a sigil opens and their
## soul rises out of them, wailing. A green tendril reaches out of the
## Necromancer's box with a bony claw at its end, closes on it and reels it in
## round a wide spiral, the soul streaming behind; his box swallows it in a
## pulse of green. What is left of it goes round him until its Morale comes
## (drain_morale), and the sigils close.
func _fx_necromancer_drain(play: Play) -> void:
	var speed: float = table._speed
	var here := _at(play.actor)
	var fallen: Variant = play.event.data.get("player") if play.event != null else null
	var grave := _at(fallen) if fallen is PlayerState else POT
	if grave.distance_to(here) < 40.0:
		grave = POT
	dim(0.65, 3.6)

	# His voice, calling the soul up, for as long as it takes to reel it in.
	_snd("drain")
	# The circle opens on the cards they left, and the cards stir.
	_snd("fx_necro_sigil")
	var low := SigilFx.new()
	low.speed = speed
	low.position = grave + Vector2(0, 10)
	low.radius = 58.0
	add_child(low)
	low.create_tween().tween_property(low, "open", 1.0, 0.45 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if fallen is PlayerState:
		for i in fallen.left.size():
			var view: CardView = table._card_view(fallen, i)
			if view == null:
				continue
			var was := view.modulate
			var stir := view.create_tween()
			stir.tween_property(view, "modulate", Color(0.6, 1.5, 0.8), 0.25 / speed)
			stir.tween_property(view, "modulate", was, 0.9 / speed)
			UI.shake(view, 4.0, 0.4)
	await _wait(0.45)

	# The soul comes up out of them.
	_snd("fx_soul_wail")
	var soul := SoulFx.new()
	soul.speed = speed
	soul.position = grave
	soul.modulate.a = 0.0
	add_child(soul)
	var up := soul.create_tween().set_parallel()
	up.tween_property(soul, "position", grave + Vector2(0, -SOUL_RISE), 0.6 / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	up.tween_property(soul, "modulate:a", 1.0, 0.3 / speed)
	rise(grave, NECRO_GLOW, 12, 30.0)
	await _wait(0.55)
	if not is_instance_valid(soul):
		return
	soul.struggle = 1.0

	# Out of him, the tendril and the claw.
	var high := SigilFx.new()
	high.speed = speed
	high.position = here
	high.radius = 80.0
	high.spin = -1.0
	add_child(high)
	high.create_tween().tween_property(high, "open", 1.0, 0.35 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tendril := TendrilFx.new()
	tendril.speed = speed
	tendril.a = _beside(play.actor, 10.0)
	tendril.b = soul.position
	add_child(tendril)
	_snd("fx_soul_reach")
	tendril.create_tween().tween_property(tendril, "reach", 1.0, 0.42 / speed) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await _wait(0.42)
	if not is_instance_valid(soul) or not is_instance_valid(tendril):
		return

	# It closes on the soul.
	_snd("fx_soul_grab")
	tendril.create_tween().tween_property(tendril, "grip", 1.0, 0.1 / speed)
	soul.struggle = 2.0
	UI.pop(soul, 0.8)
	ring(soul.position, NECRO_GLOW, 30.0, 6.0, 0.2, 3.0)
	burst(soul.position, SoulFx.BODY, 8, 120.0, 0.3, 0.0, 5.0)
	await _wait(0.22)
	if not is_instance_valid(soul) or not is_instance_valid(tendril):
		return

	# Reeled in, round and round.
	_snd("fx_soul_drain")
	soul.trail = true
	var start := soul.position
	var side := 1.0 if start.x < here.x else -1.0
	var pull := func(k: float) -> void:
		var turn := k * TAU * 1.25 * side
		var at := start.lerp(here, k) + Vector2(sin(turn), (1.0 - cos(turn)) * 0.5) * SOUL_SWING * sin(PI * k)
		if is_instance_valid(soul):
			soul.heading = at - soul.position
			soul.position = at
			soul.stretch = sin(PI * k)
		if is_instance_valid(tendril):
			tendril.b = at
	soul.create_tween().tween_method(pull, 0.0, 1.0, SOUL_REEL / speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _wait(SOUL_REEL)
	if not is_instance_valid(soul):
		return

	# Swallowed.
	_snd("fx_soul_absorb")
	if is_instance_valid(tendril):
		tendril.queue_free()
	soul.trail = false
	soul.stretch = 0.0
	soul.struggle = 0.0
	ring(here, NECRO_GLOW, 110.0, 8.0, 0.4, 5.0)
	ring(here, Color.WHITE, 70.0, 4.0, 0.3, 3.0)
	burst(here, NECRO_GLOW, 20, 220.0, 0.55, -90.0, 6.0)
	flash(Color(0.3, 1.0, 0.55, 0.14), 0.35)
	table._shake_screen(6.0)
	var gorged: Control = table._node_of(play.actor)
	if gorged != null:
		var pulse := gorged.create_tween()
		pulse.tween_property(gorged, "modulate", Color(0.7, 1.6, 0.9), 0.1 / speed)
		pulse.tween_property(gorged, "modulate", Color.WHITE, 0.6 / speed)
	# What is left of it: a wisp going round him.
	var shrink := soul.create_tween()
	shrink.tween_property(soul, "scale", Vector2(0.45, 0.45), 0.2 / speed)
	soul.circle(here, SOUL_ORBIT)
	_soul = soul
	_soul_owner = play.actor
	for sigil: SigilFx in [low, high]:
		var close := sigil.create_tween()
		close.tween_property(sigil, "open", 0.0, 0.4 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		close.tween_callback(sigil.queue_free)
	await _wait(0.4)


func draining(who: PlayerState) -> bool:
	return _soul != null and is_instance_valid(_soul) and _soul_owner == who


## The Morale a Drain gives: the soul going round the Necromancer is wound
## into a heart, green fading to red, that goes to `to`, its place in his
## Morale.
func drain_morale(who: PlayerState, to: Vector2) -> void:
	if not draining(who):
		return
	var speed: float = table._speed
	var soul := _soul
	_soul = null
	_soul_owner = null
	var at := soul.position
	soul.circle(at, 0.0)
	var wind := soul.create_tween().set_parallel()
	wind.tween_property(soul, "scale", Vector2(0.15, 0.15), 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	wind.tween_property(soul, "rotation", TAU, 0.25 / speed)
	ring(at, NECRO_GLOW, 28.0, 4.0, 0.25, 3.0)
	await _wait(0.25)
	if is_instance_valid(soul):
		soul.queue_free()
	_snd("fx_soul_flare")
	var heart := _sprite(UI.tex(HEART_ART), at, Vector2(30, 30))
	heart.pivot_offset = heart.size / 2.0
	heart.modulate = Color(0.5, 1.8, 0.8)
	heart.scale = Vector2(0.3, 0.3)
	burst(at, NECRO_GLOW, 10, 140.0, 0.35, 0.0, 5.0)
	var go := heart.create_tween().set_parallel()
	go.tween_property(heart, "scale", Vector2(1.3, 1.3), 0.15 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	go.tween_property(heart, "modulate", Color.WHITE, 0.45 / speed)
	go.tween_property(heart, "position", to - heart.size / 2.0, 0.42 / speed) \
			.set_delay(0.12 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	go.tween_property(heart, "scale", Vector2(0.8, 0.8), 0.3 / speed).set_delay(0.24 / speed)
	go.chain().tween_callback(heart.queue_free)
	stream(at, to, NECRO_GLOW, 8, 0.4, 0.3)
	await _wait(0.55)
	ring(to, Color("ff7a8c"), 4.0, 26.0, 0.3, 3.0)
	ring(to, NECRO_GLOW, 4.0, 34.0, 0.4, 2.0)


## A soul nobody's Morale came for fades away.
func drop_soul() -> void:
	if _soul != null and is_instance_valid(_soul):
		var soul := _soul
		var fade := soul.create_tween()
		fade.tween_property(soul, "modulate:a", 0.0, 0.3 / table._speed)
		fade.tween_callback(soul.queue_free)
	_soul = null
	_soul_owner = null


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


## What a borrowed action looks and sounds like, for as long as this is in
## the tree. It is the material of the PlayFx and of everything under it, so
## it touches only what the effects themselves draw: strips of them jump
## sideways, lines of them drop out, and all of it is drained to a dark
## purple. Every sound of the table is bent out of tune meanwhile, over a
## slowed-down toll. Nothing in it knows what effect it is spoiling.
class GlitchFx extends Node:
	const CODE := """
shader_type canvas_item;

uniform float amount = 0.0;
uniform float beat = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float strip = floor(VERTEX.y / 10.0);
	float torn = step(1.0 - 0.3 * amount, hash(vec2(strip, beat)));
	VERTEX.x += torn * (hash(vec2(strip, beat + 7.0)) - 0.5) * 30.0 * amount;
}

void fragment() {
	vec4 c = COLOR;
	float grey = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 purple = mix(vec3(0.06, 0.0, 0.11), vec3(0.6, 0.3, 0.86), grey);
	c.rgb = mix(c.rgb, purple, 0.8 * amount);
	float row = floor(FRAGCOORD.y / 4.0);
	c.a *= 1.0 - 0.7 * amount * step(0.88, hash(vec2(row, beat + 3.0)));
	c.rgb += vec3(0.35, 0.1, 0.5) * amount * step(0.97, hash(vec2(row, beat + 5.0)));
	COLOR = c;
}
"""
	## How many times a second the picture breaks in a new way.
	const BEATS := 12.0
	## How far down the sounds of the table are bent, and how it wavers.
	const PITCH := 0.8
	const WAVER := 0.09

	## 0 to 1: how much of it shows.
	var strength := 0.0
	## The Perfect Disguise this is the look of.
	var disguise: Play

	var _host: PlayFx
	var _fade: Tween
	var _look := ShaderMaterial.new()
	var _time := 0.0
	var _leaving := false
	var _bent: Array = []  # AudioEffect put on the SFX bus, taken off on the way out
	var _pitch: AudioEffectPitchShift

	func _init(host: PlayFx) -> void:
		_host = host
		var shader := Shader.new()
		shader.code = CODE
		_look.shader = shader
		_look.set_shader_parameter("amount", 0.0)

	func _ready() -> void:
		_host.material = _look
		_show(1.0, 0.18)
		_bend_sounds()
		_toll("fx_bell", 0.4, -7.0)
		_toll("fx_hex", 0.55, -9.0)

	func _exit_tree() -> void:
		_straighten_sounds()
		if _host.material == _look:
			_host.material = null

	## Fades out and frees itself.
	func fade() -> void:
		if _leaving:
			return
		_leaving = true
		_straighten_sounds()
		_show(0.0, 0.3).tween_callback(queue_free)

	## Held back while a play that is nobody's copy is on the table.
	func hush() -> void:
		if _leaving:
			return
		_straighten_sounds()
		_show(0.0, 0.12)

	## The borrowed action goes on. Only the look comes back: bending the
	## sounds again would bend what the other play left ringing.
	func resume() -> void:
		if not _leaving:
			_show(1.0, 0.18)

	func _show(to: float, seconds: float) -> Tween:
		if _fade != null:
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(self, "strength", to, seconds / _host.table._speed)
		return _fade

	func _process(delta: float) -> void:
		_time += delta
		# It comes in fits: nearly steady for a moment, then torn again.
		var fit := 0.5 + 0.5 * absf(sin(_time * 5.3) * sin(_time * 1.9 + 1.0))
		_look.set_shader_parameter("amount", strength * fit)
		_look.set_shader_parameter("beat", floorf(_time * BEATS))
		if _pitch != null:
			_pitch.pitch_scale = PITCH + WAVER * sin(_time * 7.0) * sin(_time * 2.3)

	# Everything on the SFX bus comes out lower, wavering and doubled a
	# little off: the sounds of the effect itself, played wrong.
	func _bend_sounds() -> void:
		var bus := AudioServer.get_bus_index(Settings.SFX_BUS)
		if bus < 0:
			return
		_pitch = AudioEffectPitchShift.new()
		_pitch.pitch_scale = PITCH
		var chorus := AudioEffectChorus.new()
		chorus.voice_count = 2
		chorus.dry = 0.7
		chorus.wet = 0.6
		chorus.set_voice_rate_hz(0, 1.3)
		chorus.set_voice_depth_ms(0, 5.0)
		chorus.set_voice_rate_hz(1, 2.1)
		chorus.set_voice_depth_ms(1, 7.0)
		var crush := AudioEffectDistortion.new()
		crush.mode = AudioEffectDistortion.MODE_LOFI
		crush.drive = 0.35
		for effect: AudioEffect in [_pitch, chorus, crush]:
			AudioServer.add_bus_effect(bus, effect)
			_bent.append(effect)

	func _straighten_sounds() -> void:
		var bus := AudioServer.get_bus_index(Settings.SFX_BUS)
		if bus >= 0:
			for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
				if _bent.has(AudioServer.get_bus_effect(bus, i)):
					AudioServer.remove_bus_effect(bus, i)
		_bent.clear()
		_pitch = null

	# A sound of the game dragged out far below its pitch, under the rest.
	func _toll(sound: String, pitch: float, volume: float) -> void:
		var sounds: Dictionary = _host.table._sfx
		var known: AudioStreamPlayer = sounds[sound] if sounds.has(sound) else _host.table._load_sfx(sound)
		if known == null:
			return
		var player := AudioStreamPlayer.new()
		player.stream = known.stream
		player.pitch_scale = pitch
		player.volume_db = volume + Sounds.level(sound)
		player.bus = Settings.SFX_BUS
		add_child(player)
		player.play()


## A serving tray seen from above, in the chunky pixels of the other effects:
## a silver oval with a handle at each end and a cork bottom. Its origin is
## its middle; the cards thrown on it are its children.
class TrayFx extends Control:
	const PIXEL := 4.0
	## Half the tray, in its own pixels, and how wide the rim is (as a share
	## of the way out from the middle).
	const HALF := Vector2i(31, 18)
	const RIM := 0.74
	const EDGE := Color("1c1a22")
	const LIGHT := Color("f1f5fa")
	const MID := Color("b7c2d1")
	const DARK := Color("76808f")
	const CORK := Color("9a6a3c")
	const CORK_DARK := Color("7d5230")
	const SHADOW := Color(0, 0, 0, 0.3)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cells := {}
		for y in range(-HALF.y, HALF.y + 1):
			for x in range(-HALF.x, HALF.x + 1):
				var out := Vector2(x / float(HALF.x), y / float(HALF.y)).length_squared()
				if out > 1.0:
					continue
				if out > RIM:
					# Lit from the top left.
					var lit := -x / float(HALF.x) * 0.5 - y / float(HALF.y)
					cells[Vector2i(x, y)] = LIGHT if lit > 0.35 else (DARK if lit < -0.35 else MID)
				elif out > RIM - 0.07:
					cells[Vector2i(x, y)] = CORK_DARK
				else:
					cells[Vector2i(x, y)] = CORK_DARK if (x * 7 + y * 13) % 11 == 0 else CORK
		for side: int in [-1, 1]:
			for y in range(-4, 5):
				for step in 3:
					var x := side * (HALF.x + 1 + step)
					cells[Vector2i(x, y)] = MID if absi(y) < 4 and step < 2 else DARK
			for y in range(-2, 3):
				cells.erase(Vector2i(side * (HALF.x + 1), y))
		for cell: Vector2i in cells:
			draw_rect(Rect2((Vector2(cell) + Vector2(1.5, 2.5)) * PIXEL, Vector2(PIXEL, PIXEL)), SHADOW)
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * PIXEL - Vector2(2, 2), Vector2(PIXEL + 4, PIXEL + 4)), EDGE)
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * PIXEL, Vector2(PIXEL, PIXEL)), cells[cell])


## A card in the air. It is flat: turning it about its upright axis (flip_y)
## or end over end (flip_x) squeezes it, and shows its back for the half of
## each turn it faces away. `along` carries it from `from` to `to` over an
## arc; `spot` is its middle, in its parent.
class TossedCard extends TextureRect:
	var face: Texture2D
	var back: Texture2D
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var arc := 0.0
	var spot := Vector2.ZERO:
		set(value):
			spot = value
			position = spot - size / 2.0
	var along := 0.0:
		set(value):
			along = value
			spot = from.lerp(to, along) + Vector2(0, -arc * sin(PI * clampf(along, 0.0, 1.0)))
	var zoom := 1.0:
		set(value):
			zoom = value
			_pose()
	var flip_x := 0.0:
		set(value):
			flip_x = value
			_pose()
	var flip_y := 0.0:
		set(value):
			flip_y = value
			_pose()

	func _init(card_face: Texture2D, card_back: Texture2D) -> void:
		face = card_face
		back = card_back
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		size = PlayFx.TOSSED
		pivot_offset = size / 2.0
		_pose()

	func _pose() -> void:
		var across := cos(flip_y)
		var down := cos(flip_x)
		scale = Vector2(maxf(absf(across), 0.06), maxf(absf(down), 0.06)) * zoom
		var side := face if across * down >= 0.0 else back
		if texture != side:
			texture = side
			texture_filter = UI.card_filter(side)


## A lasso. The rope is a chain of points with weight and no stiffness: held
## at one end, tied to the loop at the other, it sags, trails behind whatever
## the loop does and snaps about when it is pulled tight. It is drawn in
## blocks like the other effects, but in finer ones (those of the desk and the
## shop stall), so that a rope a few pixels thick can show its twist.
class RopeFx extends Control:
	const PIXEL := 2.0
	## How far the rope reaches to each side of its middle line.
	const GIRTH := 1.0
	const ROPE := Color("b98d54")
	const EDGE := Color("2a1a10")
	const KNOT := Color("6b4a2a")
	## The twisted strands, as they come round one after the other along the
	## rope, how many pixels of rope each one shows for, and how much they
	## lean across it.
	const STRANDS: Array[Color] = [Color("b98d54"), Color("b08650"), Color("98723f"), Color("ab824c")]
	const TWIST := 5.0
	const LEAN := 1.5
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
		for i in 33:
			var angle := TAU * i / 32.0
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
		# The knot: a dark lump with its corners off, where the rope runs
		# into the loop.
		var knot := (_points[LINKS - 1] / PIXEL).round() * PIXEL
		draw_rect(Rect2(knot + Vector2(-8, -6), Vector2(16, 12)), EDGE)
		draw_rect(Rect2(knot + Vector2(-6, -8), Vector2(12, 16)), EDGE)
		draw_rect(Rect2(knot + Vector2(-6, -4), Vector2(12, 8)), KNOT)
		draw_rect(Rect2(knot + Vector2(-4, -6), Vector2(8, 12)), KNOT)
		draw_rect(Rect2(knot + Vector2(-4, -4), Vector2(4, 2)), STRANDS[3])
		draw_rect(Rect2(knot + Vector2(-4, -2), Vector2(2, 2)), STRANDS[3])
		draw_rect(Rect2(knot + Vector2(-2, 2), Vector2(6, 2)), KNOT.darkened(0.3))

	## Marks in `cells` the pixels that a rope laid along `path` covers, each
	## with the colour of the strand that is on top at that point: the strands
	## go across the rope at a slant.
	func _trace(path: PackedVector2Array, cells: Dictionary) -> void:
		var run := 0.0
		var across := Vector2.DOWN
		for i in path.size() - 1:
			var length := path[i].distance_to(path[i + 1])
			if length > 0.01:
				across = (path[i + 1] - path[i]).orthogonal() / length
			var steps := maxi(ceili(length), 1)
			for step in steps + 1:
				var along := step / float(steps)
				var at := path[i].lerp(path[i + 1], along)
				for side: float in [0.0, -1.0, 1.0, -2.0, 2.0]:
					var off := side * GIRTH / 2.0
					var cell := Vector2i(((at + across * off) / PIXEL).floor())
					if not cells.has(cell):
						var turn := (run + length * along + off * LEAN) / TWIST
						cells[cell] = STRANDS[posmod(floori(turn), STRANDS.size())]
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


## The glass of a Mickey Finn, the one the Bartender holds up on her card: a
## hurricane glass on a short stem, with a drink that goes from red at the
## bottom to yellow at the top and, once it is full, a wedge of pineapple, a
## cherry, a sprig and a straw. `fill` is how much is in it, `spiked` how far
## the drink has turned green (it starts to fizz), and `pouring` draws the
## stream that fills it.
class GlassFx extends Control:
	const PIXEL := 2.0
	const EDGE := Color("0d0b12")
	const GLASS := Color("cfe6ea")
	const RIM := Color("f4fbfc")
	## The drink from the bottom of the bowl to the top of it, and spiked.
	const DRINK: Array[Color] = [Color("c9322a"), Color("f08a2a"), Color("f6c445")]
	const SPIKED: Array[Color] = [Color("4f8a2a"), Color("9fd24a"), Color("d8f07a")]
	const PINEAPPLE := Color("f4c93a")
	const CHERRY := Color("d2222a")
	const LEAF := Color("4f9a3a")
	const STRAW := Color("f0803a")
	## Half the width of the bowl, row by row from the lip down: it flares,
	## draws in and swells before it closes on the stem.
	const BOWL: Array[int] = [7, 7, 7, 6, 6, 6, 6, 7, 7, 8, 8, 8, 8, 8, 7, 7, 6, 5, 4, 3]
	const TOP := -16
	const STEM := 5
	## Rows of the bowl the drink never reaches: the lip.
	const HEADROOM := 3

	var fill := 0.0:
		set(value):
			fill = value
			# Dressed once it is full, and it stays dressed as it is drunk.
			_dressed = _dressed or fill >= 0.98
			queue_redraw()
	var spiked := 0.0:
		set(value):
			spiked = value
			queue_redraw()
	var pouring := false:
		set(value):
			pouring = value
			queue_redraw()
	var _dressed := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The colour of the drink `depth` of the way down the bowl (0 top, 1 bottom).
	func _drink(depth: float) -> Color:
		var up := (1.0 - depth) * 2.0
		var plain := DRINK[0].lerp(DRINK[1], up) if up < 1.0 else DRINK[1].lerp(DRINK[2], up - 1.0)
		var green := SPIKED[0].lerp(SPIKED[1], up) if up < 1.0 else SPIKED[1].lerp(SPIKED[2], up - 1.0)
		return plain.lerp(green, spiked)

	func _draw() -> void:
		var bowl := BOWL.size()
		var bottom := TOP + bowl
		var rows := roundi(fill * (bowl - HEADROOM))
		var surface := bottom - rows
		var foot := bottom + STEM
		if pouring:
			# The stream, and the splash where it lands.
			_cells(-1, TOP - 14, 2, surface - TOP + 14, _drink(0.3).lightened(0.2))
			_cells(-3, surface - 1, 1, 1, _drink(0.0).lightened(0.3))
			_cells(2, surface - 2, 1, 1, _drink(0.0).lightened(0.3))
		# Outlines: the bowl, the stem and the foot, a pixel bigger all round.
		for y in range(TOP - 1, bottom + 1):
			var h := BOWL[clampi(y - TOP, 0, bowl - 1)]
			_cells(-h - 1, y, h * 2 + 2, 1, EDGE)
		_cells(-2, bottom, 4, STEM, EDGE)
		_cells(-6, foot - 1, 12, 3, EDGE)
		_cells(-7, foot, 14, 2, EDGE)
		for y in range(TOP, bottom):
			var h := BOWL[y - TOP]
			var inside := Color(GLASS, 0.16)
			if rows > 0 and y == surface:
				inside = _drink(float(y - TOP) / bowl).lightened(0.35)
			elif y > surface:
				inside = _drink(float(y - TOP) / bowl)
			_cells(-h + 1, y, h * 2 - 2, 1, inside)
			_cells(-h, y, 1, 1, GLASS)
			_cells(h - 1, y, 1, 1, GLASS.darkened(0.3))
		# What is in it fizzes once it has been spiked.
		if spiked > 0.3:
			for bubble: Vector2i in [Vector2i(-4, 3), Vector2i(2, 5), Vector2i(-1, 8), Vector2i(4, 9), Vector2i(-3, 11), Vector2i(1, 13)]:
				if bottom - bubble.y > surface:
					_cells(bubble.x, bottom - bubble.y, 1, 1, Color(RIM, spiked * 0.85))
		# The lip, the light down the left of the bowl, the stem and the foot.
		_cells(-BOWL[0], TOP, BOWL[0] * 2, 1, RIM)
		for y in range(TOP + 2, bottom - 4):
			_cells(-BOWL[y - TOP] + 2, y, 1, 1, Color(1, 1, 1, 0.5 if y < TOP + 12 else 0.25))
		_cells(-1, bottom, 2, STEM, GLASS)
		_cells(-1, bottom, 1, STEM, RIM)
		_cells(-5, foot, 10, 1, GLASS)
		_cells(-6, foot + 1, 12, 1, GLASS.darkened(0.25))
		_cells(-4, foot, 4, 1, RIM)
		if not _dressed:
			return
		# On the lip: a wedge of pineapple, a cherry, a sprig, and the straw.
		_cells(2, TOP - 6, 1, 8, EDGE)
		_cells(3, TOP - 7, 2, 9, EDGE)
		_cells(3, TOP - 6, 1, 8, STRAW)
		_cells(4, TOP - 6, 1, 3, STRAW.lightened(0.3))
		_cells(-10, TOP - 4, 7, 5, EDGE)
		_cells(-9, TOP - 3, 5, 3, PINEAPPLE)
		_cells(-9, TOP - 3, 5, 1, PINEAPPLE.lightened(0.35))
		_cells(-8, TOP - 1, 1, 1, PINEAPPLE.darkened(0.3))
		_cells(-6, TOP - 2, 1, 1, PINEAPPLE.darkened(0.3))
		_cells(-4, TOP - 5, 4, 4, EDGE)
		_cells(-3, TOP - 4, 2, 2, CHERRY)
		_cells(-3, TOP - 4, 1, 1, CHERRY.lightened(0.4))
		for leaf in 4:
			_cells(-1 + leaf, TOP - 5 - leaf, 2, 1, LEAF if leaf % 2 == 0 else LEAF.darkened(0.25))

	func _cells(x: int, y: int, w: int, h: int, ink: Color) -> void:
		if w > 0 and h > 0:
			draw_rect(Rect2(Vector2(x, y) * PIXEL, Vector2(w, h) * PIXEL), ink)


## The rifle of a Collateral, seen from the side with its barrel along +x: a
## bolt action in walnut and blued steel, with a scope, a suppressor, a
## folded bipod and the laser under the barrel. It turns about where it is
## held to keep pointing at `aim`, wherever the two of them go. `beam` lights
## the laser, all the way to the aim; `kick` throws the barrel up (in
## radians) when it fires.
class SniperFx extends Control:
	const PIXEL := 2.0
	const LASER := Color("ff2a2a")
	## Nothing but blacks and browns: outline, steel in three tones, walnut
	## in three, the leather of the pad and the amber glass of the scope.
	const INKS := {
		"K": Color("0b0806"), "B": Color("1c1714"), "G": Color("3b2f27"), "H": Color("6a5747"),
		"W": Color("6b3d1c"), "L": Color("94602f"), "D": Color("3f230e"), "R": Color("2a170b"),
		"A": Color("8a4f1c"), "S": Color("d09a55"),
	}
	const BODY: Array = [
		"...............................BB...........................................",
		"..............................GGGG..........................................",
		"..............................BBBB........GGHHHGGGBB........................",
		"..................GGGKG..GG...BBBB....GG.BBBBBBBBS..........................",
		".................RBBBKBGGGGGHGGGGGGHHGGGGBBBBBBBBA..........................",
		".................RBBBKBBBBBBBBBBBBBBBBBBBBBBBBBBBA..........................",
		"..................BBBKB..BB....BB.....BB..KKKKKKKKKK........................",
		"....LLLLLLLLLL...........KK...........KK.........................GHHGGGGGK..",
		"....DWWWWWWWWD.....GGGGGGGGGGGGGGGGGGHHGHHGHHGHHGHHGGGGGHHHHHHGGKBBKBKBKBK..",
		"KRLLLLKLLLLKLLLLLLBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKBBKBKBKBK..",
		"KRWWWWWWWDDDDDWDDWBBBBBBBBBBBBGGBLLLLLLLLLLLLLLLLLGGKGGKGGK......KKKKKKKKK..",
		"KRWDDDDWWWWDDDDDDD.BBBBBBBBBBBBGGWWWWDDDDDWWDDDWWWBB.BBBBBK.................",
		"KRWWWWWWWDDKKKKLWD.BBBHBBK.GBBB.HDDDDDDDDDDDDDDDDD..........................",
		"KRWDDDWDD.....LWD..K..H..K.GBKB.GG..............GG..........................",
		"KRWWWDD.......RWD..K...H.K.GBKB....KKGGGKGGGKGGGGB..........................",
		"KRWDD........LWD....KKKKKK.GBKB....KKBBBKBBBKBBBB...........................",
		"KRD..........RWD...........KKKK....KK.......................................",
		"............DDD.............................................................",
	]
	## The cell of BODY that is held: the bore runs along the row above it.
	const HELD := Vector2i(20, 11)
	## Where the barrel ends and where the laser starts, in pixels of the rifle.
	const MUZZLE := 54
	const SIGHT := 38

	var aim := Vector2.ZERO
	var beam := 0.0
	var kick := 0.0
	## How far round it is from where it pointed to the aim given to swing_to().
	var swing := 0.0:
		set(value):
			swing = value
			var way := Vector2.from_angle(_swing_over + lerpf(_swing_from.x, _swing_to.x, swing))
			aim = position + way * lerpf(_swing_from.y, _swing_to.y, swing)
	## The two ends of a swing as (angle from _swing_over, distance).
	var _swing_from := Vector2.ZERO
	var _swing_to := Vector2.ZERO
	var _swing_over := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_point()

	## Gets it ready to be turned on `target` by `swing`. The barrel goes
	## round (an aim that slid across could pass through the rifle), and by
	## the side `over` is on: across the table, not behind whoever holds it.
	func swing_to(target: Vector2, over: Vector2) -> void:
		_swing_over = (over - position).angle()
		_swing_from = Vector2(angle_difference(_swing_over, (aim - position).angle()), position.distance_to(aim))
		_swing_to = Vector2(angle_difference(_swing_over, (target - position).angle()), position.distance_to(target))
		swing = 0.0

	func muzzle() -> Vector2:
		return position + Vector2.from_angle(rotation) * MUZZLE * PIXEL

	func _process(_delta: float) -> void:
		_point()
		queue_redraw()

	## Aiming left, the rifle is turned over so that the scope stays on top.
	func _point() -> void:
		var angle := (aim - position).angle()
		var turned := absf(angle) > PI / 2.0
		scale.y = -1.0 if turned else 1.0
		rotation = angle + (kick if turned else -kick)

	func _draw() -> void:
		for y in BODY.size():
			var row: String = BODY[y]
			var x := 0
			while x < row.length():
				var cell := row[x]
				var run := 1
				while x + run < row.length() and row[x + run] == cell:
					run += 1
				if cell != ".":
					draw_rect(Rect2(Vector2(x - HELD.x, y - HELD.y) * PIXEL, Vector2(run, 1) * PIXEL), INKS[cell])
				x += run
		if beam <= 0.0:
			return
		var reach := position.distance_to(aim)
		var from := SIGHT * PIXEL
		# It never burns quite steadily.
		var glow := beam * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.03))
		draw_rect(Rect2(from, -1.0, maxf(reach - from, 0.0), 6.0), Color(LASER, glow * 0.22))
		draw_rect(Rect2(from, 1.0, maxf(reach - from, 0.0), 2.0), Color(LASER.lightened(0.25), glow))
		draw_rect(Rect2(reach - 8.0, -6.0, 16.0, 16.0), Color(LASER, glow * 0.35))
		draw_rect(Rect2(reach - 4.0, -2.0, 8.0, 8.0), Color(LASER, glow))
		draw_rect(Rect2(reach - 2.0, 0.0, 4.0, 4.0), Color(1.0, 0.9, 0.85, glow))


## The shade of the Assassin: a small hooded figure in the colours of his
## card, seen from the side and on the run. `sunk` hides it from the feet up,
## as if it went down into whatever it stands on (1 is all of it); `travel`
## takes it along the way given to run(), leaving what it was a moment ago
## fading behind it.
class ShadeFx extends Control:
	const PIXEL := 4.0
	const EDGE := Color("0d0b12")
	const CLOAK := Color("1b1a2d")
	const FOLD := Color("110f1d")
	const HOOD := Color("2a2c5a")
	const HOOD_LIT := Color("4a4e96")
	const MASK := Color("ecebf2")
	const EYE := Color("0a0406")
	const BLADE := Color("c9c9cb")
	const INKS := {"K": EDGE, "C": CLOAK, "F": FOLD, "H": HOOD, "L": HOOD_LIT, "M": MASK, "E": EYE, "S": BLADE}
	## Facing right: the hood and the mask, the cloak streaming behind and
	## the blade held out in front.
	const BODY: Array = [
		"......HHHH..",
		".....HLLLLH.",
		"....HHLLMMM.",
		"..CCHHHHMEM.",
		".CCCCHHHMM..",
		"CCCFCCHHH...",
		".CCCFCCCCKSS",
		"..CCCFCCC...",
		"...CCCCCC...",
	]
	## The legs, apart and together.
	const STRIDES: Array = [
		["..FF....FF..", ".FF......FF."],
		["....FFFF....", ".....FF....."],
	]
	const COLUMNS := 12
	const ROWS := 11
	## How many strides the whole way takes.
	const STEPS := 7.0
	## How far the way bends round the middle of the table.
	const BOW := 46.0
	const GHOST_EVERY := 0.022
	const GHOST_LIFE := 0.2

	## How fast the table is playing.
	var speed := 1.0
	var sunk := 1.0:
		set(value):
			sunk = value
			queue_redraw()
	var travel := 0.0:
		set(value):
			travel = value
			position = _from.lerp(_bend, travel).lerp(_bend.lerp(_to, travel), travel)
	## What it goes in behind, on screen: nothing of it is drawn there.
	var behind := Rect2()
	var _from := Vector2.ZERO
	var _bend := Vector2.ZERO
	var _to := Vector2.ZERO
	var _facing := 1
	var _ghosts: Array = []  # {at, stride, t}
	var _since := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Sets the way from `from` to `to`. It keeps to the edge: the way bends
	## away from `around`.
	func run(from: Vector2, to: Vector2, around: Vector2) -> void:
		_from = from
		_to = to
		var middle := (from + to) / 2.0
		var side := (to - from).orthogonal().normalized()
		if side.dot(around - middle) > 0.0:
			side = -side
		_bend = middle + side * BOW
		_facing = -1 if to.x < from.x else 1
		travel = 0.0

	func _process(delta: float) -> void:
		var dt := delta * speed
		for ghost: Dictionary in _ghosts:
			ghost.t += dt
		_ghosts = _ghosts.filter(func(ghost: Dictionary) -> bool: return ghost.t < GHOST_LIFE)
		if travel > 0.0 and travel < 1.0:
			_since += dt
			if _since >= GHOST_EVERY:
				_since = 0.0
				_ghosts.append({"at": position, "stride": _stride(), "t": 0.0})
		queue_redraw()

	func _stride() -> int:
		return int(travel * STEPS) % 2

	func _draw() -> void:
		for ghost: Dictionary in _ghosts:
			var left := 1.0 - float(ghost.t) / GHOST_LIFE
			_figure(ghost.at - position, ghost.stride, ROWS, Color(HOOD, 0.45 * left * left))
		var shown := ceili(ROWS * (1.0 - sunk))
		if shown > 0:
			_figure(Vector2(0.0, (ROWS - shown) * PIXEL), _stride(), shown)

	## The figure with its middle at `at`, down to row `shown`. Given an
	## `ink`, it is all of that one colour.
	func _figure(at: Vector2, stride: int, shown: int, ink: Variant = null) -> void:
		var rows: Array = BODY + STRIDES[stride]
		var corner := at - Vector2(COLUMNS, ROWS) * PIXEL / 2.0
		for y in mini(shown, ROWS):
			var row: String = rows[y]
			for x in COLUMNS:
				var cell := row[x]
				if cell == ".":
					continue
				var column := x if _facing > 0 else COLUMNS - 1 - x
				var block := Rect2(corner + Vector2(column, y) * PIXEL, Vector2(PIXEL, PIXEL))
				if behind.has_point(position + block.get_center()):
					continue
				draw_rect(block, INKS[cell] if ink == null else ink)


## A note of music, in blocks: it rises from `home` as `risen` goes to 1,
## swaying to the side `sway` says.
class NoteFx extends Control:
	const PIXEL := 3.0
	const SHAPE := [
		"...##",
		"...#.",
		"...#.",
		".###.",
		"####.",
		".##..",
	]
	var ink := Color.WHITE
	var home := Vector2.ZERO
	var sway := 1.0
	var risen := 0.0:
		set(value):
			risen = value
			position = home + Vector2(sin(risen * TAU * 1.5) * 9.0 * sway, -52.0 * risen)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for layer in 2:
			for y in SHAPE.size():
				var row: String = SHAPE[y]
				for x in row.length():
					if row[x] != "#":
						continue
					var cell := Vector2(x - 2, y - 3) * PIXEL
					if layer == 0:
						draw_rect(Rect2(cell + Vector2(PIXEL, PIXEL), Vector2(PIXEL, PIXEL)), Color(0, 0, 0, 0.5))
					else:
						draw_rect(Rect2(cell, Vector2(PIXEL, PIXEL)), ink)


## The vault of a Cash Out, seen from one side and a little from above: its
## front, its right side and its top, a steel box on feet with a framed
## doorway. The door hangs on the left of the doorway and swings out towards
## the viewer: `open` goes from 0 (shut) to 1 (wide open, its inner face
## showing), and what is inside lights up as it goes. `spin` turns the wheel
## on the door.
class VaultFx extends Control:
	const PIXEL := 3.0
	const EDGE := Color("0d0b12")
	const STEEL_DARK := Color("333941")
	const STEEL := Color("59626e")
	const STEEL_LIT := Color("8b95a1")
	const STEEL_TOP := Color("a3adb8")
	const BRASS := Color("e6bc4c")
	const BRASS_DARK := Color("7d5616")
	const DARK := Color("120d0a")
	const GOLD_LIT := Color("fff3c4")
	const FELT := Color("5a1f1c")
	## In pixels of the vault: the front face (left, top, right, bottom), how
	## deep the box is, the doorway and how far round the door goes.
	const FRONT := Rect2i(-11, -9, 16, 20)
	const DEPTH := 6
	const DOORWAY := Rect2i(-9, -7, 12, 16)
	const SWING := 1.95
	## The wheel in its two positions: upright and turned an eighth.
	const WHEEL := [
		["..#..", "..#..", "#####", "..#..", "..#.."],
		["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	]

	var open := 0.0:
		set(value):
			open = value
			queue_redraw()
	var spin := 0.0:
		set(value):
			spin = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Where the coins come out, in the coordinates of whatever holds the vault.
	func mouth() -> Vector2:
		return position + Vector2(DOORWAY.get_center()) * PIXEL * scale

	func _draw() -> void:
		var left := FRONT.position.x
		var top := FRONT.position.y
		var right := FRONT.end.x
		var bottom := FRONT.end.y
		# The shadow it throws on the table, to the right of it.
		for i in 4:
			_cells(left + 2 + i, bottom + 1, FRONT.size.x + DEPTH - i * 2, 1, Color(0, 0, 0, 0.32 - i * 0.06))
		# Outlines first: every face, a pixel bigger all round.
		_cells(left - 1, top - 1, FRONT.size.x + 2, FRONT.size.y + 2, EDGE)
		for i in DEPTH:
			_cells(right + i, top - i - 2, 2, FRONT.size.y + 2, EDGE)
			_cells(left + i, top - i - 2, FRONT.size.x + 2, 2, EDGE)
		# The feet: two under the front, one seen under the far corner.
		_cells(left + 1, bottom, 3, 2, EDGE)
		_cells(right - 4, bottom, 3, 2, EDGE)
		_cells(right + DEPTH - 3, bottom - DEPTH + 1, 2, 2, EDGE)
		# The top, lit, and the side, in shade: each row or column a step
		# further back.
		for i in DEPTH:
			_cells(left + i + 1, top - i - 1, FRONT.size.x, 1, STEEL_TOP if i > 0 else GOLD_LIT.lerp(STEEL_TOP, 0.7))
			_cells(right + i, top - i - 1, 1, FRONT.size.y, STEEL_DARK if i > 0 else STEEL_DARK.lightened(0.12))
		for bolt: int in [top + 2, bottom - 4]:
			_cells(right + 2, bolt - 3, 1, 1, STEEL)
			_cells(right + 4, bolt - 5, 1, 1, STEEL)
		_cells(left + 4, top - 4, 6, 1, STEEL_LIT.lightened(0.2))
		# The front, its edges caught by the light, and a brass plate.
		_cells(left, top, FRONT.size.x, FRONT.size.y, STEEL)
		_cells(left, top, FRONT.size.x, 1, STEEL_LIT)
		_cells(left, top, 1, FRONT.size.y, STEEL_LIT)
		_cells(left, bottom - 1, FRONT.size.x, 1, STEEL_DARK)
		_cells(right - 1, top, 1, FRONT.size.y, STEEL_DARK)
		for corner: Vector2i in [Vector2i(left + 1, top + 1), Vector2i(right - 2, top + 1), Vector2i(left + 1, bottom - 2), Vector2i(right - 2, bottom - 2)]:
			_cells(corner.x, corner.y, 1, 1, STEEL_LIT)
		_cells(DOORWAY.end.x + 1, bottom - 4, 2, 2, BRASS_DARK)
		_cells(DOORWAY.end.x + 1, bottom - 4, 1, 1, BRASS)

		# The doorway and what is in it: the light comes up as the door goes.
		var way := DOORWAY
		_cells(way.position.x - 1, way.position.y - 1, way.size.x + 2, way.size.y + 2, EDGE)
		_cells(way.position.x, way.position.y, way.size.x, way.size.y, DARK.lerp(FELT, open * 0.8))
		if open > 0.0:
			var shelf := way.position.y + 7
			# Bars stacked on the shelf, and coins and a sack under it.
			for bar: Vector2i in [Vector2i(1, 5), Vector2i(5, 5), Vector2i(3, 3), Vector2i(8, 5)]:
				_cells(way.position.x + bar.x, way.position.y + bar.y, 3, 2, Color(BRASS_DARK, open))
				_cells(way.position.x + bar.x, way.position.y + bar.y, 3, 1, Color(BRASS, open))
				_cells(way.position.x + bar.x, way.position.y + bar.y, 1, 1, Color(GOLD_LIT, open))
			_cells(way.position.x, shelf, way.size.x, 1, Color(STEEL_DARK, open))
			_cells(way.position.x, shelf + 1, way.size.x, 1, Color(0, 0, 0, 0.35 * open))
			for pile: Vector3i in [Vector3i(1, 5, 3), Vector3i(4, 3, 3), Vector3i(8, 4, 3)]:
				for row in pile.y:
					_cells(way.position.x + pile.x, way.end.y - 1 - row, pile.z, 1,
							Color(BRASS if row % 2 == 0 else BRASS_DARK, open))
				_cells(way.position.x + pile.x, way.end.y - pile.y, pile.z, 1, Color(GOLD_LIT, open))
			for glint: Vector2i in [Vector2i(2, 2), Vector2i(9, 3), Vector2i(6, 10), Vector2i(10, 12)]:
				_cells(way.position.x + glint.x, way.position.y + glint.y, 1, 1, Color(1, 1, 1, open * 0.9))
		for hinge: int in [way.position.y + 2, way.end.y - 4]:
			_cells(way.position.x - 2, hinge, 2, 2, BRASS_DARK)
			_cells(way.position.x - 2, hinge, 1, 1, BRASS)

		# The door, a column at a time from its hinges: turned by `angle`, a
		# column `k` along it is that much across and, coming towards the
		# viewer, that much lower.
		var angle := open * SWING
		var inner := angle > PI / 2.0
		var face := STEEL.lerp(STEEL_DARK, sin(angle) * 0.5) if not inner else Color("454d57")
		for k in way.size.x:
			var at := _on_door(k, 0, angle)
			_cells(at.x, at.y - 1, 1, way.size.y + 2, EDGE)
		for k in way.size.x:
			var at := _on_door(k, 0, angle)
			_cells(at.x, at.y, 1, way.size.y, face)
			_cells(at.x, at.y, 1, 1, face.lightened(0.25))
			_cells(at.x, at.y + way.size.y - 1, 1, 1, face.darkened(0.3))
		# Its free edge has the thickness of the steel.
		var lip := _on_door(way.size.x, 0, angle)
		_cells(lip.x, lip.y - 1, 1, way.size.y + 2, EDGE)
		if sin(angle) > 0.25:
			_cells(lip.x, lip.y, 1, way.size.y, STEEL_LIT)
		if inner:
			# The inside of the door: the bars of the lock.
			for bar: int in [3, 7, 11]:
				var from := _on_door(2, bar, angle)
				var to := _on_door(way.size.x - 2, bar, angle)
				_cells(mini(from.x, to.x), from.y, absi(to.x - from.x) + 1, 1, STEEL_LIT)
			return
		if cos(angle) < 0.35:
			return
		for stud: Vector2i in [Vector2i(1, 1), Vector2i(way.size.x - 2, 1), Vector2i(1, way.size.y - 2), Vector2i(way.size.x - 2, way.size.y - 2)]:
			var at := _on_door(stud.x, stud.y, angle)
			_cells(at.x, at.y, 1, 1, STEEL_LIT)
		# The dial over the wheel, and the wheel.
		var dial := _on_door(5, 2, angle)
		_cells(dial.x, dial.y, 2, 2, GOLD_LIT)
		_cells(dial.x + 1, dial.y + 1, 1, 1, EDGE)
		var wheel: Array = WHEEL[int(spin) % 2]
		for y in wheel.size():
			var row: String = wheel[y]
			for x in row.length():
				var at := _on_door(4 + x, 7 + y, angle)
				_cells(at.x, at.y, 1, 1, BRASS if row[x] == "#" else STEEL_DARK)
		var hub := _on_door(6, 9, angle)
		_cells(hub.x, hub.y, 1, 1, GOLD_LIT)

	## Where the point `k` across and `y` down the door is, in pixels of the
	## vault, with the door turned by `angle`.
	func _on_door(k: int, y: int, angle: float) -> Vector2i:
		return Vector2i(DOORWAY.position.x + roundi(k * cos(angle)), DOORWAY.position.y + y + roundi(k * sin(angle) * 0.5))

	func _cells(x: int, y: int, w: int, h: int, ink: Color) -> void:
		if w > 0 and h > 0:
			draw_rect(Rect2(Vector2(x, y) * PIXEL, Vector2(w, h) * PIXEL), ink)


## The Bard's lute, lying with its neck to the right: a pear of a body with
## a rose in it, a fretted neck and a pegbox bent back. pluck() sets its
## strings shaking; they die down by themselves.
class LuteFx extends Control:
	const PIXEL := 4.0
	const EDGE := Color("0d0b12")
	const WOOD := Color("b9783a")
	const WOOD_LIT := Color("d99a52")
	const WOOD_DARK := Color("7a4a24")
	const NECK := Color("4a2c16")
	const FRET := Color("c9b27a")
	const STRING := Color("f4ecd6")
	## Half the height of the body, column by column from its round end.
	const BODY: Array[int] = [3, 5, 6, 7, 7, 7, 7, 6, 6, 5, 5, 4, 3, 2]
	const BODY_AT := -9
	## Where the middle of its belly is, from its origin.
	const BELLY := 12.0

	## How hard the strings are shaking, 1 right after a pluck.
	var ring := 0.0
	## How hard they go on shaking while a held note sounds.
	const HELD := 0.6
	var _held := 0.0
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The strings are struck. A note that is held for `held` seconds keeps
	## them shaking that long, and they come to rest as it dies away.
	func pluck(held := 0.0) -> void:
		ring = 1.0
		_held = held

	func _process(delta: float) -> void:
		_time += delta
		# The last stretch of a held note is the strings settling.
		_held = maxf(_held - delta, 0.0)
		ring = maxf(ring - delta * 2.4, HELD if _held > HELD / 2.4 else 0.0)
		queue_redraw()

	func _draw() -> void:
		var neck_from := BODY_AT + BODY.size() - 1
		for i in BODY.size():
			_cells(BODY_AT + i - 1, -BODY[i] - 1, 3, BODY[i] * 2 + 2, EDGE)
		_cells(neck_from, -2, 16, 4, EDGE)
		_cells(neck_from + 14, -4, 5, 7, EDGE)
		for i in BODY.size():
			var h := BODY[i]
			_cells(BODY_AT + i, -h, 1, h * 2, WOOD)
			_cells(BODY_AT + i, -h, 1, 2, WOOD_LIT)
			_cells(BODY_AT + i, h - 1, 1, 1, WOOD_DARK)
		# The rose, the bridge, the neck with its frets and the pegbox.
		_cells(-4, -2, 4, 4, WOOD_DARK)
		_cells(-3, -1, 2, 2, EDGE)
		_cells(-8, -2, 1, 4, NECK)
		_cells(neck_from, -1, 15, 2, NECK)
		for fret in 4:
			_cells(neck_from + 2 + fret * 3, -1, 1, 2, FRET)
		_cells(neck_from + 15, -3, 3, 5, WOOD_DARK)
		for peg: Vector2i in [Vector2i(neck_from + 15, -4), Vector2i(neck_from + 17, -4), Vector2i(neck_from + 16, 2)]:
			_cells(peg.x, peg.y, 1, 1, FRET)
		# The strings: still at both ends, shaking widest in the middle.
		var length := neck_from + 15 + 8
		for string in 3:
			for x in range(-8, neck_from + 15):
				var along := float(x + 8) / length
				var shake := sin(_time * 55.0 + string * 2.1 + x * 0.5) * ring * sin(along * PI) * 1.2
				draw_rect(Rect2(Vector2(x, (string - 1) * 0.9 - 0.25 + shake) * PIXEL, Vector2(PIXEL, PIXEL * 0.5)), STRING)

	func _cells(x: int, y: int, w: int, h: int, ink: Color) -> void:
		if w > 0 and h > 0:
			draw_rect(Rect2(Vector2(x, y) * PIXEL, Vector2(w, h) * PIXEL), ink)


## A loose hand in a white glove out of an old cartoon, reaching to the
## right: a puffy cuff, the thumb up, three fat fingers and the three black
## darts on its back. It is not a
## bitmap: palm, fingers, thumb and cuff are rounded shapes filled in cells,
## each with its own outline, so that the fingers can move. `spread` opens
## them wide (1: a hand that has had a fright), `fidget` sets them twitching
## and `sting` reddens it (1 right after a blow); `flipped` turns it over, for
## a hand that reaches to the left with its thumb still up. Its origin is the
## middle of the palm.
class GloveFx extends Control:
	const PIXEL := 3.0
	## How many cells one unit of the shapes below is.
	const SIZE := 0.9
	const EDGE := Color("0d0b12")
	const WHITE := Color("f6f3ea")
	const SHADE := Color("b9bcc9")
	const SORE := Color("e0503c")
	## The cells it is drawn in: everything below has to fit, with two to spare.
	const GRID := Rect2i(-15, -15, 32, 30)
	## Where each finger leaves the palm, and how long it is.
	const KNUCKLES: Array[float] = [-4.3, 0.0, 4.3]
	const FINGERS: Array[float] = [6.5, 7.5, 6.5]

	var flipped := false
	var fidget := 0.0
	var spread := 0.0:
		set(value):
			spread = value
			queue_redraw()
	var sting := 0.0:
		set(value):
			sting = value
			queue_redraw()
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		if fidget > 0.0:
			queue_redraw()

	func _draw() -> void:
		var white := WHITE.lerp(SORE, sting * 0.7)
		var shade := SHADE.lerp(SORE.darkened(0.3), sting * 0.7)
		var palm: Array = [[Vector2(-4.0, 0.0), Vector2(0.0, 0.0), 6.0]]
		_stamp(palm, white, shade)
		# One finger at a time, so that there is a line between two of them
		# even when they are held together; none where they join the palm.
		for i in 3:
			var tilt := (i - 1) * (0.05 + 0.5 * spread) + sin(_time * 21.0 + i * 2.1) * 0.13 * fidget
			var root := Vector2(3.0, KNUCKLES[i])
			_stamp([[root, root + Vector2.from_angle(tilt) * (FINGERS[i] + 1.5 * spread), 2.7]], white, shade, palm)
		for dart: int in [-4, -1, 2]:
			for x in range(-5, -1):
				_cell(Vector2i(x, dart), EDGE)
		var thumb := Vector2(-2.0, -4.0)
		var lifted := -1.0 - 0.6 * spread + sin(_time * 21.0 + 5.0) * 0.1 * fidget
		_stamp([[thumb, thumb + Vector2.from_angle(lifted) * (6.0 + spread), 2.6]], white, shade)
		_stamp([[Vector2(-10.5, -5.0), Vector2(-10.5, 5.0), 2.9]], white, shade)

	## Fills in the cells inside any of `shapes` (each one [from, to, radius]:
	## everything within `radius` of that stretch), shaded along the lower
	## edge, with an outline all round, except where it would fall inside
	## one of `joined`.
	func _stamp(shapes: Array, ink: Color, shade: Color, joined: Array = []) -> void:
		var w := GRID.size.x
		var h := GRID.size.y
		var filled := PackedByteArray()
		filled.resize(w * h)
		for gy in h:
			for gx in w:
				if _inside(_middle(gx, gy), shapes):
					filled[gy * w + gx] = 1
		var under := -w if flipped else w
		for gy in range(2, h - 2):
			for gx in range(1, w - 1):
				var at := gy * w + gx
				var cell := GRID.position + Vector2i(gx, gy)
				if filled[at] == 1:
					_cell(cell, shade if filled[at + under] == 0 else ink)
				elif filled[at - 1] == 1 or filled[at + 1] == 1 or filled[at - w] == 1 or filled[at + w] == 1:
					if joined.is_empty() or not _inside(_middle(gx, gy), joined):
						_cell(cell, EDGE)

	## The middle of the cell at `gx`, `gy` of GRID, in the units of the shapes.
	func _middle(gx: int, gy: int) -> Vector2:
		return (Vector2(GRID.position) + Vector2(gx + 0.5, gy + 0.5)) / SIZE

	func _inside(point: Vector2, shapes: Array) -> bool:
		for shape: Array in shapes:
			var from: Vector2 = shape[0]
			var to: Vector2 = shape[1]
			if Geometry2D.get_closest_point_to_segment(point, from, to).distance_to(point) <= shape[2]:
				return true
		return false

	func _cell(cell: Vector2i, ink: Color) -> void:
		var y := -cell.y - 1 if flipped else cell.y
		draw_rect(Rect2(Vector2(cell.x, y) * PIXEL, Vector2(PIXEL, PIXEL)), ink)


## The bomb of a Demolition: a ball of black iron with a collar and a lit
## fuse, in blocks. The ball is shaded from a light up and to the left, not
## drawn cell by cell. `turn` spins it (the collar and the fuse go round; the
## light stays where it is) and `lift` is how far off the table it
## is (its shadow stays down there); it blinks red, faster as `hurry` goes
## from 0 to 1.
class BombFx extends Control:
	signal blinked

	const PIXEL := 2.0
	## The ball, in cells; the origin is its middle.
	const BALL := 8.6
	const RADIUS := BALL * PIXEL
	## Where the light falls on it, in cells from the middle.
	const LIGHT := Vector2(-3.0, -3.5)
	const OUTLINE := Color("09080d")
	## From the glint outwards: how far from LIGHT (in radii) each tone reaches.
	const TONES: Array = [
		[0.15, Color("f4f2ff")], [0.4, Color("7f7a99")], [0.88, Color("403c52")],
		[1.3, Color("2a2734")], [9.0, Color("1a1821")],
	]
	## The light the table throws back on the far rim.
	const BOUNCE := Color("4e4964")
	## The collar the fuse comes out of, row by row from the top. K: outline,
	## L: lit, M: metal, D: in shade.
	const COLLAR: Array[String] = ["KKKKKKK", "KLLMMDK", "KLMMDDK", "KMMDDDK"]
	const COLLAR_AT := Vector2(-3, -12)
	const METAL := {"K": Color("09080d"), "L": Color("b9b4c9"), "M": Color("807a90"), "D": Color("4b4759")}
	## The fuse, cell by cell from the collar to where it burns.
	const FUSE: Array[Vector2] = [
		Vector2(0, -13), Vector2(0, -14), Vector2(1, -15), Vector2(2, -16), Vector2(3, -16), Vector2(4, -15), Vector2(5, -15),
	]
	const ROPE: Array[Color] = [Color("d8b877"), Color("94713d")]
	const ALARM := Color("ff2a1a")
	const SPARK := Color("ff7a2a")
	## Blinks a second, at rest and at the very end.
	const SLOW := 2.5
	const FAST := 13.0

	var turn := 0.0:
		set(value):
			turn = value
			queue_redraw()
	var lift := 0.0
	var hurry := 0.0
	var lit := false

	var _iron: Array = []  # [Rect2, Color, how red it turns]
	var _halo: Array = []  # Rect2
	var _trim: Array = []  # [Rect2, Color]: the collar and the fuse
	var _phase := 0.0
	var _red := false
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var reach := ceili(BALL) + 2
		for row in range(-reach, reach + 1):
			for column in range(-reach, reach + 1):
				var cell := Vector2(column, row)
				var out := cell.length()
				if out > BALL + 2.0:
					continue
				if out > BALL:
					_halo.append(_block(cell))
				elif out > BALL - 1.1:
					_iron.append([_block(cell), OUTLINE, 0.35])
				elif out > BALL - 2.7 and cell.normalized().dot(Vector2(0.6, 0.8)) > 0.8:
					_iron.append([_block(cell), BOUNCE, 0.75])
				else:
					var from_light := (cell - LIGHT).length() / BALL
					for tone: Array in TONES:
						if from_light < tone[0]:
							_iron.append([_block(cell), tone[1], 0.75])
							break
		for row in COLLAR.size():
			for column in COLLAR[row].length():
				_trim.append([_block(COLLAR_AT + Vector2(column, row)), METAL[COLLAR[row][column]]])
		for index in FUSE.size():
			_trim.append([_block(FUSE[index]), ROPE[index % 2]])

	## Where the fuse burns, from the origin, as the bomb is turned now.
	func fuse_tip() -> Vector2:
		return (FUSE[-1] * PIXEL).rotated(turn)

	func _block(cell: Vector2) -> Rect2:
		return Rect2((cell - Vector2(0.5, 0.5)) * PIXEL, Vector2(PIXEL, PIXEL))

	func _process(delta: float) -> void:
		if not lit:
			return
		_time += delta
		_phase += delta * lerpf(SLOW, FAST, hurry)
		var red := fposmod(_phase, 1.0) < 0.5
		if red and not _red:
			blinked.emit()
		_red = red
		queue_redraw()

	func _draw() -> void:
		# The shadow stays on the table, smaller the higher the bomb is.
		var spread := RADIUS * (1.0 - minf(lift / 220.0, 0.45))
		var ground := Vector2(0, lift + RADIUS)
		draw_rect(Rect2(ground + Vector2(-spread, -PIXEL), Vector2(spread * 2.0, PIXEL * 2.0)).abs(), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(ground + Vector2(-spread * 0.6, -PIXEL * 2.0), Vector2(spread * 1.2, PIXEL * 4.0)).abs(), Color(0, 0, 0, 0.22))
		# The light does not turn with the ball: only the collar and the fuse
		# go round it.
		draw_set_transform(Vector2.ZERO, turn)
		for block: Array in _trim:
			draw_rect(block[0], block[1])
		draw_set_transform(Vector2.ZERO, 0.0)
		var red := _red and lit
		if red:
			for block: Rect2 in _halo:
				draw_rect(block, Color(ALARM, 0.3))
		for block: Array in _iron:
			draw_rect(block[0], block[1].lerp(ALARM, block[2]) if red else block[1])
		draw_set_transform(Vector2.ZERO, turn)
		if lit:
			# The spark: a plus and a cross of rays, taking turns.
			var tip: Vector2 = FUSE[-1] * PIXEL
			var plus := fposmod(_time * 12.0, 1.0) < 0.5
			for ray: Vector2 in ([Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT] if plus
					else [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]):
				draw_rect(_block(FUSE[-1] + ray * 2.0), SPARK)
				draw_rect(_block(FUSE[-1] + ray), Color("ffe08a"))
			draw_rect(Rect2(tip - Vector2(PIXEL, PIXEL), Vector2(PIXEL, PIXEL) * 2.0), Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0)


## The Sheriff's boot, seen from the side with its toe to the right (`facing`
## turns it round): a short leg cut in a V at the top, with the dark of the
## inside showing in it, piping and a pull strap, a tooled front, a toe cap,
## a stacked heel and a golden spur strapped on behind it, whose rowel turns (`whirl`, in radians a
## second). The origin is where the back of the heel meets the table. It is
## cut out of a grid like the badge: the edges that face the light are
## bright, the ones that face away are dark. `haul` is how many coins show
## in its mouth, and `restless` (0 to 1) makes it tremble where it is.
##
## It is drawn in two layers, the inside of the leg and then all the rest:
## what is given to it with take() goes in between, so that a coin falling
## into the mouth goes down behind the leather.
class BootFx extends Control:
	const PIXEL := 2.0
	const EDGE := Color("140a06")
	const HIDE := Color("6e3a1a")
	const LIT := Color("96562a")
	const SHEEN := Color("84481f")
	const DARK := Color("4c2610")
	const DEEP := Color("351809")
	const LINING := Color("1e0f09")
	const WELT := Color("221309")
	const WELT_STITCH := Color("5a3a20")
	const STACK := Color("3a2213")
	const STITCH := Color("e2c084")
	const PIPING := Color("c9973f")
	## The spur, in gold.
	const SPUR := Color("f2c84b")
	const SPUR_LIT := Color("fff0a8")
	const SPUR_DARK := Color("a8741c")
	const GOLD := Color("ffd84a")
	const GOLD_DARK := Color("c8902a")
	const DUST := Color("c9b48a")
	## The cells it is cut out of, and the shapes, in cells.
	const GRID := Rect2i(-16, -31, 44, 33)
	const UPPER: Array[Vector2] = [
		Vector2(0, -26), Vector2(5.5, -22.5), Vector2(11, -27), Vector2(11.5, -13), Vector2(13, -9.5),
		Vector2(17, -7.5), Vector2(21, -6), Vector2(24, -4), Vector2(24, -2), Vector2(9, -2), Vector2(7, -4.5),
		Vector2(-0.5, -4.5), Vector2(-1, -10), Vector2(0, -15),
	]
	const INSIDE: Array[Vector2] = [Vector2(0, -26), Vector2(1, -28), Vector2(10, -29), Vector2(11, -27), Vector2(5.5, -22.5)]
	const TREAD: Array[Vector2] = [Vector2(8.5, -2), Vector2(24.5, -2), Vector2(24, 0), Vector2(9, 0)]
	const BLOCK: Array[Vector2] = [Vector2(-0.5, -4.5), Vector2(7.5, -4.5), Vector2(6.5, 0), Vector2(1, 0)]
	## What is stitched into the front of the leg: a flame over a diamond,
	## and the studs beside them.
	const TOOLING: Array[Vector2i] = [
		Vector2i(5, -21), Vector2i(4, -20), Vector2i(6, -20), Vector2i(3, -19), Vector2i(7, -19), Vector2i(3, -18),
		Vector2i(7, -18), Vector2i(4, -17), Vector2i(6, -17), Vector2i(5, -16), Vector2i(5, -19), Vector2i(5, -18),
		Vector2i(4, -14), Vector2i(5, -15), Vector2i(6, -14), Vector2i(5, -13),
	]
	const STUDS: Array[Vector2i] = [Vector2i(2, -16), Vector2i(8, -16), Vector2i(2, -15), Vector2i(8, -15)]
	## Where the leather folds at the ankle.
	const CREASES: Array[Vector2i] = [Vector2i(9, -11), Vector2i(10, -10), Vector2i(11, -10), Vector2i(8, -9)]
	## Places on it, in cells: the middle of the rowel, the middle of the
	## mouth, the middle of the leg and the back of the heel on the table.
	const ROWEL := Vector2(-8.5, -5.5)
	const MOUTH := Vector2(5.5, -25.0)
	const SHAFT := Vector2(5.5, -14.0)
	const HEEL := Vector2(1.0, 0.0)
	## How many points the rowel has, and how long they are, in cells: a
	## long one and a short one in turn.
	const POINTS := 8
	const POINT := 5
	const POINT_SHORT := 3
	## How tall it stands, in px.
	const TALL := 58.0

	var facing := 1.0:
		set(value):
			facing = value
			_redraw()
	var haul := 0:
		set(value):
			haul = value
			queue_redraw()
	var whirl := 0.0
	var restless := 0.0
	## How far it is tipped back, toe up, in radians (see pose).
	var lean := 0.0
	var _spin := 0.0
	## What a knock added to the turning of the rowel: it dies down by itself.
	var _kick := 0.0
	var _time := 0.0
	var _inside: Array[Vector2i] = []
	var _cells: Dictionary = {}  # Vector2i -> Color: everything in front of the inside
	var _front := Control.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.draw.connect(_draw_front)
		add_child(_front)
		_cut()

	## Where `cell` is, in px from the origin.
	func spot(cell: Vector2) -> Vector2:
		return Vector2(cell.x * facing, cell.y) * PIXEL

	## Where `cell` is on the screen.
	func at(cell: Vector2) -> Vector2:
		return position + (spot(cell) * scale).rotated(rotation)

	## Puts `cell` at `where` on the screen, the boot tipped back by `tip`
	## radians: toe up, heel down (toe down, if negative).
	func pose(cell: Vector2, where: Vector2, tip: float) -> void:
		lean = tip
		rotation = -tip * facing
		position = where - (spot(cell) * scale).rotated(rotation)

	## Takes `node` between its two layers.
	func take(node: Control) -> void:
		if node.get_parent() != null:
			node.reparent(self, false)
		else:
			add_child(node)
		move_child(node, 0)

	## Sets the rowel turning at `kick` radians a second, if it is not
	## turning faster already.
	func spur(kick: float) -> void:
		_kick = maxf(_kick, kick)

	func _process(delta: float) -> void:
		_time += delta
		if whirl != 0.0 or _kick > 0.1 or restless > 0.0:
			_spin += (whirl + _kick) * delta
			_kick *= exp(-3.0 * delta)
			_redraw()

	func _redraw() -> void:
		queue_redraw()
		_front.queue_redraw()

	func _cut() -> void:
		var upper := PackedVector2Array(UPPER)
		var inside := PackedVector2Array(INSIDE)
		var tread := PackedVector2Array(TREAD)
		var block := PackedVector2Array(BLOCK)
		var leather := {}
		for y in range(GRID.position.y, GRID.end.y):
			for x in range(GRID.position.x, GRID.end.x):
				var cell := Vector2i(x, y)
				var middle := Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(middle, upper):
					leather[cell] = true
				elif Geometry2D.is_point_in_polygon(middle, inside):
					_inside.append(cell)
				elif Geometry2D.is_point_in_polygon(middle, tread):
					_cells[cell] = WELT
				elif Geometry2D.is_point_in_polygon(middle, block):
					# The lifts the heel is stacked from.
					_cells[cell] = STACK if posmod(y, 2) == 1 else WELT
		for cell: Vector2i in leather:
			var lit := not leather.has(cell + Vector2i.UP) or not leather.has(cell + Vector2i.LEFT)
			var shaded := not leather.has(cell + Vector2i.DOWN) or not leather.has(cell + Vector2i.RIGHT)
			# The toe cap and the counter round the heel are of a darker hide.
			var capped := cell.x - 0.9 * (cell.y + 2) >= 21.5 \
					or (cell.x < 4 and cell.y > -12 and cell.x + (cell.y + 12) * 0.35 < 4.0)
			var ink := DARK if capped else HIDE
			if lit != shaded:
				ink = DEEP if shaded else (HIDE if capped else LIT)
			elif not capped and cell.y < -12 and cell.x >= 9:
				# The leg is round: it turns away from the light before its edge.
				ink = DARK
			elif not capped and cell.y < -13 and (cell.x == 2 or cell.x == 3):
				# And catches it just inside the edge that faces it.
				ink = SHEEN
			_cells[cell] = ink
		# Piping along the cut of the top, and the pull strap at the front of it.
		for x in range(0, 11):
			var y := roundi(-26.0 + x * 3.5 / 5.5) if x < 5.5 else roundi(-22.5 - (x - 5.5) * 4.5 / 5.5)
			_tool(leather, Vector2i(x, y), PIPING)
		for y in range(-24, -20):
			_tool(leather, Vector2i(10, y), DEEP)
		for cell: Vector2i in TOOLING:
			_tool(leather, cell, STITCH)
		for cell: Vector2i in STUDS:
			_tool(leather, cell, PIPING)
		for cell: Vector2i in CREASES:
			_tool(leather, cell, DARK)
		# The seam down the side, the stitches of the toe cap and of the counter.
		for y in range(-12, -4, 2):
			_tool(leather, Vector2i(6, y), DARK)
		for y: int in [-6, -4]:
			_tool(leather, Vector2i(roundi(21.5 + 0.9 * (y + 2)) - 1, y), STITCH)
		_tool(leather, Vector2i(21, -4), STITCH)
		_tool(leather, Vector2i(2, -10), STITCH)
		_tool(leather, Vector2i(3, -8), STITCH)
		# The welt is sewn on, and the heel nailed.
		for x in range(10, 24, 2):
			_cells[Vector2i(x, -2)] = WELT_STITCH
		_cells[Vector2i(2, -1)] = SPUR_DARK
		_cells[Vector2i(5, -1)] = SPUR_DARK
		# The spur: its strap over the instep with a buckle on it, the band
		# round the heel, and the shank with its hook.
		for x in range(3, 12):
			_cells[Vector2i(x, roundi(-7.0 - (x - 3) * 0.4))] = DEEP
		_cells[Vector2i(7, -9)] = SPUR
		_cells[Vector2i(8, -9)] = SPUR_LIT
		_cells[Vector2i(8, -8)] = SPUR_DARK
		for x in range(-1, 3):
			_cells[Vector2i(x, -7)] = SPUR_LIT if x < 1 else SPUR
			_cells[Vector2i(x, -6)] = SPUR_DARK
		_cells[Vector2i(3, -7)] = SPUR
		for x in range(-6, -1):
			_cells[Vector2i(x, -6)] = SPUR
		for x in range(-5, -1):
			_cells[Vector2i(x, -5)] = SPUR_DARK
		_cells[Vector2i(-3, -7)] = SPUR
		var solid := _cells.duplicate()
		for cell: Vector2i in _inside:
			solid[cell] = LINING
		for cell: Vector2i in solid:
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not solid.has(cell + step):
					_cells[cell + step] = EDGE

	func _tool(leather: Dictionary, cell: Vector2i, ink: Color) -> void:
		if leather.has(cell):
			_cells[cell] = ink

	## The inside of the leg, through the cut of the top, and the coins in it.
	func _draw() -> void:
		draw_set_transform(_tremble())
		# The coins lie in the bottom of the cut: the more of them, the higher.
		var level := -23 - mini(haul, 3)
		for cell: Vector2i in _inside:
			var ink := LINING
			if haul > 0 and cell.y >= level:
				ink = GOLD if posmod(cell.x + cell.y, 3) != 0 else GOLD_DARK
			_dot(self, cell, ink)

	func _draw_front() -> void:
		_front.draw_set_transform(_tremble())
		for cell: Vector2i in _cells:
			_dot(_front, cell, _cells[cell])
		# The rowel, on the end of the shank: its points, and a rim to each
		# so that it reads against anything.
		var points := {}
		for k in POINTS:
			var out := Vector2.from_angle(_spin + TAU * k / POINTS)
			var reach := POINT if k % 2 == 0 else POINT_SHORT
			for i in range(1, reach + 1):
				points[Vector2i((ROWEL + out * i * 0.95).floor())] = SPUR_LIT if i == reach else (SPUR if i > 1 else SPUR_DARK)
		for cell: Vector2i in points:
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not points.has(cell + step) and not _cells.has(cell + step):
					_dot(_front, cell + step, EDGE)
		for cell: Vector2i in points:
			_dot(_front, cell, points[cell])
		_dot(_front, Vector2i(ROWEL.floor()), SPUR_LIT)

	## How far off its place it is drawn this instant, held back and itching.
	func _tremble() -> Vector2:
		return (Vector2(sin(_time * 47.0), cos(_time * 39.0)) * 1.2 * restless).round()

	func _dot(on: Control, cell: Vector2i, ink: Color) -> void:
		var x := cell.x if facing > 0.0 else -cell.x - 1
		on.draw_rect(Rect2(Vector2(x, cell.y) * PIXEL, Vector2(PIXEL, PIXEL)), ink)


## A picture seen the way the Entity's things are: three images of it, a red
## one, a cyan one and the true one, `split` pixels apart. Its origin is its
## middle.
class PrismFx extends Control:
	const RED := Color(1.0, 0.16, 0.36)
	const CYAN := Color(0.1, 0.95, 1.0)

	## texture -> its shape filled in white, for the two coloured images.
	static var _shapes := {}

	var texture: Texture2D
	var extent := Vector2.ZERO
	var split := 0.0:
		set(value):
			split = value
			queue_redraw()

	func _init(picture: Texture2D, picture_size: Vector2) -> void:
		texture = picture
		extent = picture_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		if texture == null:
			return
		var corner := -extent / 2.0
		if split >= 1.0:
			var shape := PrismFx.silhouette(texture)
			draw_texture_rect(shape, Rect2(corner + Vector2(-split, 0), extent), false, Color(RED, 0.6))
			draw_texture_rect(shape, Rect2(corner + Vector2(split, 0), extent), false, Color(CYAN, 0.6))
		draw_texture_rect(texture, Rect2(corner, extent), false)

	## The shape of `picture` with nothing in it but white.
	static func silhouette(picture: Texture2D) -> Texture2D:
		if _shapes.has(picture):
			return _shapes[picture]
		var shape: Texture2D = picture
		var image := picture.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			var blank := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
			blank.fill(Color(1, 1, 1, 0))
			var white := blank.duplicate() as Image
			white.fill(Color.WHITE)
			blank.blit_rect_mask(white, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			shape = ImageTexture.create_from_image(blank)
		_shapes[picture] = shape
		return shape


## The chains of an Entropy in pieces: every link of them and the splinters
## between, thrown out from where they broke. `pace` is how fast time goes
## for them: 1 as they break, next to nothing a moment later, when they hang
## in the air and turn. Then they are called in, a batch at a time (gather,
## pull), winding in on a point until there is nothing left of them (absorb).
class DebrisFx extends Control:
	const STEEL := Color("e9ecff")

	var pace := 1.0
	## The speed of the table.
	var speed := 1.0
	## What they stay inside: a piece that reaches an edge of it turns back.
	var room := Rect2()

	var _shards: Array = []
	var _batches := {}  # batch -> {to, t}
	var _next := 0
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Breaks up from `links`, away from `centre`.
	func scatter(links: Array[Vector2], centre: Vector2) -> void:
		for i: int in links.size():
			_throw(links[i], centre, i % 2 == 0, 1.0, randf_range(200.0, 560.0))
			if i % 3 == 0:
				_throw(links[i], centre, false, 0.5, randf_range(320.0, 720.0))

	func _throw(from: Vector2, centre: Vector2, ring: bool, shard_size: float, force: float) -> void:
		var out := from - centre
		var way := out.normalized() if out.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		_shards.append({
			"p": from, "v": way.rotated(randf_range(-0.6, 0.6)) * force, "turn": randf() * TAU,
			"spin": randf_range(-16.0, 16.0), "ring": ring, "size": shard_size, "hue": randf(),
			"batch": -1, "from": from,
		})

	func _process(delta: float) -> void:
		_time += delta
		var dt := delta * speed * pace
		for shard: Dictionary in _shards:
			if shard.batch == -1:
				shard.p += shard.v * dt
				shard.turn += shard.spin * dt
				if room.size.x > 0.0:
					if (shard.p.x < room.position.x and shard.v.x < 0.0) or (shard.p.x > room.end.x and shard.v.x > 0.0):
						shard.v.x = -shard.v.x
					if (shard.p.y < room.position.y and shard.v.y < 0.0) or (shard.p.y > room.end.y and shard.v.y > 0.0):
						shard.v.y = -shard.v.y
		queue_redraw()

	## How many pieces have not been called in yet.
	func loose() -> int:
		var count := 0
		for shard: Dictionary in _shards:
			if shard.batch == -1:
				count += 1
		return count

	## Calls in `count` of the loose pieces, from wherever they are, to wind
	## in on `to`. Returns their batch.
	func gather(count: int, to: Vector2) -> int:
		var batch := _next
		_next += 1
		_batches[batch] = {"to": to, "t": 0.0}
		var free := _shards.filter(func(shard: Dictionary) -> bool: return shard.batch == -1)
		free.shuffle()
		for shard: Dictionary in free.slice(0, count):
			shard.batch = batch
			shard.from = shard.p
		return batch

	## How far the pieces of `batch` have wound in, 0 to 1.
	func pull(t: float, batch: int) -> void:
		if _batches.has(batch):
			_batches[batch].t = t

	## The pieces of `batch` are what they were called in to be.
	func absorb(batch: int) -> void:
		_shards = _shards.filter(func(shard: Dictionary) -> bool: return shard.batch != batch)
		_batches.erase(batch)

	func _draw() -> void:
		for image: int in 3:
			for shard: Dictionary in _shards:
				var at: Vector2 = shard.p
				var turn: float = shard.turn
				var shard_size: float = shard.size
				if shard.batch != -1:
					var called: Dictionary = _batches.get(shard.batch, {})
					if called.is_empty():
						continue
					var k: float = called.t
					at = called.to + (shard.from - called.to).rotated(k * 4.0) * (1.0 - k)
					turn += k * 9.0
					shard_size *= 1.0 - 0.6 * k
				var split := 2.0 + 3.0 * (0.5 + 0.5 * sin(_time * 3.0 + shard.hue * TAU))
				var ink := STEEL.lerp(Color.from_hsv(fposmod(shard.hue + _time * 0.15, 1.0), 0.6, 1.0),
						0.5 + 0.5 * sin(_time * 5.0 + shard.hue * 40.0))
				if image < 2:
					ink = Color(PrismFx.RED if image == 0 else PrismFx.CYAN, 0.6)
				draw_set_transform((at + Vector2([-split, split, 0.0][image], 0)).round(), turn, Vector2.ONE * shard_size)
				if shard.ring:
					draw_rect(Rect2(-4, -3, 8, 2), ink)
					draw_rect(Rect2(-4, 1, 8, 2), ink)
					draw_rect(Rect2(-4, -1, 2, 2), ink)
					draw_rect(Rect2(2, -1, 2, 2), ink)
				else:
					draw_rect(Rect2(-4, -1, 8, 2), ink)
		draw_set_transform(Vector2.ZERO)


## The chains of an Entropy going into a singularity at `hub`: every link
## is drawn straight to it along its own line, all of them by the same
## length, the way a chain is hauled in, and is gone at the rim of the hole.
## They keep their shape to the end. `drawn` is how far the haul has got.
class SwallowFx extends Control:
	const STEEL_DARK := Color("8f96c4")
	## Where a link is gone: under the disc of the hole.
	const RIM := 9.0
	const SPLIT := 2.0

	var hub := Vector2.ZERO
	var drawn := 0.0

	var _links: Array = []  # {way, far, index}
	var _reach := 0.0
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func lay(links: Array[Vector2], centre: Vector2) -> void:
		hub = centre
		for i: int in links.size():
			var out := links[i] - centre
			var far := out.length()
			_links.append({"way": out / far if far > 0.5 else Vector2.RIGHT, "far": far, "index": i})
			_reach = maxf(_reach, far)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var hauled := drawn * (_reach + 4.0)
		# Wider apart the harder they are pulled.
		var split := SPLIT + 4.0 * drawn
		for image: int in 3:
			var apart := Vector2([-split, split, 0.0][image], 0)
			for link: Dictionary in _links:
				var left: float = link.far - hauled
				if left <= RIM:
					continue
				var way: Vector2 = link.way
				# Taut, and shivering with it.
				var shiver := way.orthogonal() * sin(_time * 34.0 + link.index * 1.7) * 1.5 * minf(drawn * 4.0, 1.0)
				draw_set_transform((hub + way * left + shiver + apart).round(), way.angle())
				if image < 2:
					var ghost := Color(PrismFx.RED if image == 0 else PrismFx.CYAN, 0.6)
					_link(link.index, ghost, ghost)
				else:
					var lit := Color.from_hsv(fposmod(link.index * 0.035 + _time * 0.6, 1.0), 0.55, 1.0)
					var near := clampf(1.0 - (left - RIM) / 40.0, 0.0, 1.0)
					_link(link.index, DebrisFx.STEEL.lerp(lit, near), STEEL_DARK.lerp(lit, near))
		draw_set_transform(Vector2.ZERO)

	# The links of ChainsFx: a ring face on, then a bar edge on.
	func _link(index: int, light: Color, dark: Color) -> void:
		if index % 2 == 1:
			draw_rect(Rect2(-5, -1, 10, 2), light)
			return
		draw_rect(Rect2(-6, -4, 12, 2), light)
		draw_rect(Rect2(-6, 2, 12, 2), dark)
		draw_rect(Rect2(-6, -2, 2, 4), light)
		draw_rect(Rect2(4, -2, 2, 4), dark)


## The singularity of a Materialize: a black disc with a bright rim, dust of
## every colour turning round it on a ring seen from a little above, and
## whatever was fed to it going round on a circle of its own (take). Those
## are pulled out of shape as `stretch` grows: longer along their way and
## thinner across it, bent round the circle, each in its three images.
## `reach` is how wide the circle is, `whirl_speed` how fast they go round
## (radians a second), `open` how big the hole is (0 to 1), `spin` how fast
## its dust turns and `pull` how much starlight is falling into it.
class SingularityFx extends Control:
	const PIXEL := 2.0
	const RADIUS := 13.0
	const INK := Color("05030a")
	const RIM := Color("f4eaff")
	const HALO := Color("9b6bff")
	const DUST := 26
	const STREAKS := 12
	## How much further out the tail of something pulled long is than its
	## head, for every pixel of its length, and how much thinner (1: to nothing).
	const TRAIL_OUT := 0.09
	const TAPER := 0.75

	var open := 0.0
	var spin := 2.5
	var whirl_speed := 2.6
	var stretch := 0.0
	var reach := 46.0
	var pull := 0.0
	## The speed of the table.
	var speed := 1.0

	var _orbiters: Array = []  # {tex, extent, from, phase, join}
	var _whirl := 0.0
	var _turn := 0.0
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		var dt := delta * speed
		_time += dt
		_turn += spin * dt
		_whirl += whirl_speed * dt
		queue_redraw()

	## Something `extent` across comes from `from` (on screen) and joins the
	## circle, `phase` round it from the first, in `time` seconds.
	func take(texture: Texture2D, extent: Vector2, from: Vector2, phase: float, delay: float, time: float) -> void:
		var orbiter := {"tex": texture, "extent": extent, "from": from - global_position, "phase": phase, "join": 0.0}
		_orbiters.append(orbiter)
		var come := create_tween()
		if delay > 0.0:
			come.tween_interval(delay / speed)
		come.tween_method(_join.bind(orbiter), 0.0, 1.0, time / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	func _join(t: float, orbiter: Dictionary) -> void:
		orbiter.join = t

	## All that was going round is one thing now: `texture`, `extent` across.
	func become(texture: Texture2D, extent: Vector2) -> void:
		var phase: float = _orbiters[0].phase if not _orbiters.is_empty() else 0.0
		_orbiters = [{"tex": texture, "extent": extent, "from": Vector2.ZERO, "phase": phase, "join": 1.0}]

	func clear() -> void:
		_orbiters.clear()

	## The picture of the first thing going round, or null.
	func held() -> Texture2D:
		return _orbiters[0].tex if not _orbiters.is_empty() else null

	## Where the first thing going round is on screen, and how it is turned.
	func pose() -> Array:
		var head: float = _whirl + (_orbiters[0].phase if not _orbiters.is_empty() else 0.0)
		return [global_position + Vector2.from_angle(head) * reach, head + PI / 2.0]

	func _draw() -> void:
		var radius := RADIUS * open
		if open > 0.0:
			draw_circle(Vector2.ZERO, radius * 2.6, Color(HALO, 0.12 * open))
			_dust(radius, false)
			var cells := ceili(radius / PIXEL) + 2
			for y: int in range(-cells, cells + 1):
				for x: int in range(-cells, cells + 1):
					var out := Vector2(x + 0.5, y + 0.5) * PIXEL
					var far := out.length()
					if far <= radius:
						draw_rect(Rect2(Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), INK)
					elif far <= radius + PIXEL * 1.5:
						# The rim: light of every colour, going round.
						var tint := Color.from_hsv(fposmod(out.angle() / TAU + _turn * 0.12, 1.0), 0.45, 1.0)
						draw_rect(Rect2(Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), RIM.lerp(tint, 0.6))
			_dust(radius, true)
			_infall(radius)
		for orbiter: Dictionary in _orbiters:
			_noodle(orbiter)
		draw_set_transform(Vector2.ZERO)

	## Half of the ring of dust: the far half, drawn before the hole, or the
	## `near` one, drawn after.
	func _dust(radius: float, near: bool) -> void:
		for i: int in DUST:
			var angle := TAU * i / DUST + _turn * (1.0 + 0.25 * (i % 3))
			if (sin(angle) >= 0.0) != near:
				continue
			var wide := radius + 6.0 + 5.0 * (i % 4)
			var at := Vector2(cos(angle) * wide, sin(angle) * wide * 0.36 + cos(angle) * wide * 0.12)
			var ink := Color.from_hsv(fposmod(float(i) / DUST + _time * 0.1, 1.0), 0.6, 1.0)
			var dot := PIXEL * (2.0 if i % 5 == 0 else 1.0)
			draw_rect(Rect2((at / PIXEL).floor() * PIXEL, Vector2(dot, dot)), Color(ink, open * (0.95 if near else 0.4)))

	## Starlight from all round, falling in on a turn.
	func _infall(radius: float) -> void:
		if pull <= 0.0:
			return
		for i: int in STREAKS:
			var seed_ := i * 0.618
			var life := fposmod(_time * (0.9 + 0.7 * fposmod(seed_ * 3.7, 1.0)) * (1.0 + pull) + seed_, 1.0)
			var ink := Color.from_hsv(fposmod(seed_, 1.0), 0.4, 1.0)
			for tail: int in 3:
				var then := maxf(life - 0.04 * tail, 0.0)
				var at := Vector2.from_angle(seed_ * TAU + then * 2.6) * lerpf(96.0, radius, then * then)
				draw_rect(Rect2((at / PIXEL).floor() * PIXEL, Vector2(PIXEL, PIXEL)), Color(ink, pull * life * (1.0 - 0.3 * tail)))

	## One of the things going round: its picture cut in slices across, each
	## put where its place along the circle is.
	func _noodle(orbiter: Dictionary) -> void:
		var texture: Texture2D = orbiter.tex
		var extent: Vector2 = orbiter.extent
		var join: float = orbiter.join
		var head: float = _whirl + orbiter.phase
		var wide := maxf(reach, 1.0)
		var length := extent.x * (1.0 + stretch * 4.0)
		var thick := extent.y / (1.0 + stretch * 1.4)
		# Straight while it is whole, round the circle once it gives.
		var bend := clampf(stretch * 3.0, 0.0, 1.0) if join >= 1.0 else 0.0
		var middle: Vector2 = orbiter.from.lerp(Vector2.from_angle(head) * wide, join)
		var facing := lerp_angle(0.0, head + PI / 2.0, join)
		var slices := clampi(int(length / 4.0), 4, 56)
		var piece := length / slices
		var source := texture.get_size()
		var split := 1.0 + stretch * 3.0
		var shape: Texture2D = PrismFx.silhouette(texture) if stretch > 0.05 else null
		for image: int in 3:
			if image < 2 and shape == null:
				continue
			var tint: Color = [Color(PrismFx.RED, 0.4), Color(PrismFx.CYAN, 0.4), Color.WHITE][image]
			var shift: float = [-split, split, 0.0][image]
			for s: int in slices:
				# How far behind the middle of the picture this slice is.
				var back := (s + 0.5) * piece - length / 2.0
				var flat := middle - Vector2.from_angle(facing) * back + Vector2.from_angle(facing - PI / 2.0) * shift
				# What trails is further out, and thinner: it is falling in.
				var trail := float(s) / slices * bend
				var angle := head - back / wide
				var round_ := Vector2.from_angle(angle) * (wide + shift + (back + length / 2.0) * TRAIL_OUT * bend)
				var across := thick * (1.0 - TAPER * trail)
				draw_set_transform(flat.lerp(round_, bend), lerp_angle(facing, angle + PI / 2.0, bend))
				draw_texture_rect_region(texture if image == 2 else shape,
						Rect2(-piece / 2.0 - 0.5, -across / 2.0, piece + 1.0, across),
						Rect2(source.x * (1.0 - float(s + 1) / slices), 0, source.x / slices, source.y),
						Color(tint, tint.a * (1.0 - 0.5 * trail)))


## The shadow of a Sneak Peek: the Spy's own, hat and shoulders, cast long
## across the table from under his box, along its own x. Its origin is
## inside the box, and nothing of it is drawn over `behind`, the box: it
## comes out from under whatever edge it crosses. It is flat and of one
## darkness: every cell is drawn once. `length` is how far its hat has got;
## `peer` turns the head to one side and the other; `arm` sends an arm of
## shadow from the shoulder to the point given to `reach_for`, or to the
## near edge of the card it has `carried`, wherever that goes. The one thing
## in it that is not shadow is the ember of his cigarette.
class LurkFx extends Control:
	const PIXEL := 3.0
	const INK := Color(0.02, 0.012, 0.03, 0.64)
	const EMBER := Color("ff8a3a")
	## Hat, head and shoulders, from the crown down.
	const BUST: Array[String] = [
		".......#######.......",
		"......#########......",
		"......#########......",
		".....###########.....",
		"..#################..",
		".###################.",
		"....#############....",
		".....###########.....",
		".....###########.....",
		".....###########.....",
		"......#########......",
		".......#######.......",
		"........#####........",
		".......#######.......",
		"....#############....",
		"..#################..",
		".###################.",
		"#####################",
	]
	## The rows that turn with the head, and the row the arm leaves from.
	const HEAD_ROWS := 12
	const SHOULDER_ROW := 15
	## Half the width of the shadow where it leaves the box, in cells.
	const ROOT := 4.0

	var length := 0.0:
		set(value):
			length = value
			queue_redraw()
	## The length that leaves the hat as far from what it is aimed at as asked.
	var span := 0.0
	var peer := 0.0:
		set(value):
			peer = value
			queue_redraw()
	var arm := 0.0:
		set(value):
			arm = value
			queue_redraw()
	## The box it comes from under, on the screen.
	var behind := Rect2()
	## The card its arm holds on to (the node that carries and sizes it).
	var carried: Node2D
	var _arm_to := Vector2.ZERO
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Lays the shadow towards `at`, to stop `shy` short of it.
	func aim(at: Vector2, shy: float) -> void:
		var way := at - position
		rotation = way.angle()
		span = maxf(way.length() - shy, BUST.size() * PIXEL + 12.0)

	## Where the crown of the hat is on the table.
	func head() -> Vector2:
		return position + Vector2.from_angle(rotation) * length

	## The point on the table its arm goes to as `arm` goes to 1.
	func reach_for(at: Vector2) -> void:
		_arm_to = (at - position).rotated(-rotation)

	func _process(delta: float) -> void:
		_time += delta
		if carried != null and is_instance_valid(carried):
			# Its hand stays on the edge of the card that is nearest the hat.
			var way := (head() - carried.position).normalized()
			var half: Vector2 = CardView.BASE * carried.scale.x / 2.0
			var edge := minf(half.x / maxf(absf(way.x), 0.001), half.y / maxf(absf(way.y), 0.001))
			reach_for(carried.position + way * edge * 0.8)
		# The ember breathes.
		queue_redraw()

	## True if the cell at `cx`, `cy` is out from under the box.
	func _out(cx: int, cy: int, along: Vector2, across: Vector2) -> bool:
		return not behind.has_point(position + along * ((cx + 0.5) * PIXEL) + across * ((cy + 0.5) * PIXEL))

	func _draw() -> void:
		var rows := BUST.size()
		var wide := BUST[0].length()
		var top := roundi(length / PIXEL)
		var neck := top - rows
		var along := Vector2.from_angle(rotation)
		var across := along.orthogonal() * -1.0
		# Past this many cells from the origin nothing is under the box.
		var clear := 0
		if behind.has_area():
			for corner: Vector2 in [behind.position, behind.end, Vector2(behind.position.x, behind.end.y), Vector2(behind.end.x, behind.position.y)]:
				clear = maxi(clear, ceili(corner.distance_to(position) / PIXEL) + 1)
		# The body: one strip for each step from the box to the shoulders,
		# wider the further the shadow is thrown.
		for x in maxi(neck, 0):
			var half := roundi(lerpf(ROOT, wide / 2.0, float(x) / neck))
			if x >= clear:
				draw_rect(Rect2(x * PIXEL, -half * PIXEL, PIXEL, half * 2.0 * PIXEL), INK)
				continue
			# Near the box: cell by cell, in runs, leaving out what it covers.
			var since := -half
			for y in range(-half, half + 1):
				if y == half or not _out(x, y, along, across):
					if y > since:
						draw_rect(Rect2(x * PIXEL, since * PIXEL, PIXEL, (y - since) * PIXEL), INK)
					since = y + 1
		# Bust and arm share cells: gathered first, so that none is drawn twice.
		var cells := {}
		var turned := roundi(peer * 2.0)
		for row in rows:
			var cx := top - row - 1
			var shift := turned if row < HEAD_ROWS else 0
			for column in wide:
				if BUST[row][column] == "#":
					cells[Vector2i(cx, column - wide / 2 + shift)] = true
		if arm > 0.0:
			var side := 1.0 if _arm_to.y >= 0.0 else -1.0
			var shoulder := Vector2(top - SHOULDER_ROW - 1, side * (wide / 2.0 - 3.0))
			var hand := shoulder.lerp(_arm_to / PIXEL, arm)
			var steps := int(shoulder.distance_to(hand)) + 1
			for i in steps + 1:
				var at := shoulder.lerp(hand, float(i) / steps)
				# Thicker at the end: the hand.
				var thick := 2 if i < steps - 2 else 3
				for dy in range(-thick + 1, thick):
					for dx in range(-thick + 1, thick):
						if absi(dx) + absi(dy) < thick + 1:
							cells[Vector2i(roundi(at.x) + dx, roundi(at.y) + dy)] = true
		for cell: Vector2i in cells:
			if cell.x >= clear or _out(cell.x, cell.y, along, across):
				draw_rect(Rect2(cell.x * PIXEL, cell.y * PIXEL, PIXEL, PIXEL), INK)
		if neck > 0 and (top - 10 >= clear or _out(top - 10, wide / 2 - 3 + turned, along, across)):
			# The cigarette, at the side of the face.
			var glow := 0.65 + 0.35 * sin(_time * 5.0)
			var lit := Vector2((top - 10) * PIXEL, (wide / 2 - 3 + turned) * PIXEL)
			draw_rect(Rect2(lit - Vector2(PIXEL, PIXEL), Vector2(PIXEL * 3.0, PIXEL * 3.0)), Color(EMBER, 0.25 * glow))
			draw_rect(Rect2(lit, Vector2(PIXEL, PIXEL)), Color(EMBER.lightened(0.3 * glow), 1.0))


## The stake of a side bet: a few banknotes counted down one on another,
## each a little askew, and a coin set on them as a paperweight, in blocks.
## Its origin is the middle of the pile. `coin` drops the coin (0: not there
## yet, 1: down) and `press` is the give of the notes under it. They lie
## still: the user did not want their ends moving in the wind.
class BillsFx extends Control:
	const PIXEL := 2.0
	const NOTES := 3
	## A note, in cells.
	const NOTE := Vector2i(22, 10)
	## Where each note lies, and how it is turned.
	const PLACES: Array[Vector2] = [Vector2(-6, 5), Vector2(6, -4), Vector2(0, 0)]
	const TURNS: Array[float] = [-0.32, 0.24, -0.05]
	## Where the coin sits: on the left of the pile, its right end free.
	const COIN_AT := Vector2(-10, 0)
	const COIN_SIZE := 18.0
	const COIN_FALL := 54.0
	const DARK := Color("1c4a2a")
	const GREEN := Color("4f9460")
	const LIGHT := Color("8fc793")
	const PALE := Color("cfe8c4")
	const SEAL := Color("2c6b3c")

	var coin := 0.0:
		set(value):
			coin = value
			queue_redraw()
	var press := 0.0:
		set(value):
			press = value
			queue_redraw()
	var _laid := PackedFloat32Array([0.0, 0.0, 0.0])
	var _from := Vector2.ZERO
	var _coin_art: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_coin_art = UI.tex(PlayFx.COIN_ART)

	## Deals note `index` onto the pile from `from` (seen from the pile),
	## after `delay` seconds, in `time`.
	func deal(index: int, from: Vector2, delay: float, time: float) -> void:
		_from = from
		create_tween().tween_method(_lay.bind(index), 0.0, 1.0, time).set_delay(delay) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _lay(amount: float, index: int) -> void:
		_laid[index] = amount
		queue_redraw()

	func _draw() -> void:
		for i in NOTES:
			var laid := _laid[i]
			if laid <= 0.0:
				continue
			var at := _from.lerp(PLACES[i], laid)
			draw_set_transform(at, TURNS[i] + (1.0 - laid) * (2.4 if i % 2 == 0 else -2.0))
			_note(i, Color(1, 1, 1, minf(laid * 4.0, 1.0)))
		draw_set_transform(Vector2.ZERO)
		if coin <= 0.0:
			return
		var drop := (1.0 - coin) * COIN_FALL
		var squash := 1.0 - 0.25 * press
		var extent := Vector2(COIN_SIZE, COIN_SIZE * squash)
		# Its shadow closes in under it as it comes down.
		draw_rect(Rect2(COIN_AT - Vector2(7, 4) + Vector2(3, 5), Vector2(14, 8)), Color(0, 0, 0, 0.4 * coin))
		draw_texture_rect(_coin_art, Rect2(COIN_AT - extent / 2.0 + Vector2(0, -drop + (COIN_SIZE - extent.y) / 2.0), extent), false)

	## One note, its middle at the origin, column by column.
	func _note(_index: int, tint: Color) -> void:
		var w := NOTE.x
		var h := NOTE.y
		for x in w:
			var left := (x - w / 2.0) * PIXEL
			var top := -h / 2.0 * PIXEL
			draw_rect(Rect2(left, top, PIXEL, h * PIXEL), DARK * tint)
			if x == 0 or x == w - 1:
				continue
			draw_rect(Rect2(left, top + PIXEL, PIXEL, (h - 2) * PIXEL), GREEN * tint)
			# A fine frame inside the edge, and the seal in the middle.
			if x == 2 or x == w - 3:
				draw_rect(Rect2(left, top + PIXEL * 2.0, PIXEL, (h - 4) * PIXEL), LIGHT * tint)
			elif x > 2 and x < w - 3:
				draw_rect(Rect2(left, top + PIXEL * 2.0, PIXEL, PIXEL), LIGHT * tint)
				draw_rect(Rect2(left, top + (h - 3) * PIXEL, PIXEL, PIXEL), LIGHT * tint)
			var off := absf(x - (w - 1) / 2.0)
			if off < 3.0:
				var tall := 6 if off < 2.0 else 4
				draw_rect(Rect2(left, top + (h - tall) / 2.0 * PIXEL, PIXEL, tall * PIXEL), SEAL * tint)
				if off < 1.0:
					draw_rect(Rect2(left, top + (h / 2.0 - 1.0) * PIXEL, PIXEL, PIXEL * 2.0), PALE * tint)
			elif x == 4 or x == w - 5:
				# What it is worth, in each corner.
				draw_rect(Rect2(left, top + PIXEL * 3.0, PIXEL, PIXEL), PALE * tint)
				draw_rect(Rect2(left, top + (h - 4) * PIXEL, PIXEL, PIXEL), PALE * tint)


## The syringe of an Antidote, in blocks, lying along its own x with the
## needle ahead: the thumb rest and the rod of the plunger, the finger
## flange, the glass barrel with what is left of the `dose` (1: full), the
## hub and the needle. Its origin is the back of the thumb rest when the
## plunger is all the way out. `sunk` is how much of the needle, from its
## point, is inside something and not drawn.
class SyringeFx extends Control:
	const PIXEL := 2.0
	const LENGTH := 78.0
	## Where the barrel starts and ends, and how far the plunger travels.
	const BARREL := 20.0
	const BARREL_END := 56.0
	const HUB_END := 60.0
	const TRAVEL := 28.0
	const EDGE := Color("12161c")
	const GLASS := Color(0.78, 0.9, 0.96, 0.4)
	const GLASS_LIGHT := Color(0.95, 0.99, 1.0, 0.85)
	const STEEL := Color("c9d2e0")
	const STEEL_DARK := Color("7a8494")
	const RUBBER := Color("2a2f3a")

	var dose := 1.0:
		set(value):
			dose = value
			queue_redraw()
	var sunk := 0.0:
		set(value):
			sunk = value
			queue_redraw()
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func tip() -> Vector2:
		return position + Vector2.from_angle(rotation) * LENGTH

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pushed := roundf((1.0 - dose) * TRAVEL / PIXEL) * PIXEL
		# The stopper sits just inside the barrel when the dose is whole.
		var stopper := BARREL + 2.0 + pushed
		# The plunger: thumb rest, rod.
		_b(pushed - PIXEL, -9.0, 6.0, 18.0, EDGE)
		_b(pushed, -7.0, PIXEL, 14.0, STEEL)
		_b(pushed, -7.0, PIXEL, 4.0, Color.WHITE)
		_b(pushed + 4.0, -3.0, stopper - pushed - 4.0, 6.0, EDGE)
		_b(pushed + 4.0, -1.0, stopper - pushed - 4.0, PIXEL, STEEL_DARK)
		# The barrel: glass, with what is in it.
		_b(BARREL - PIXEL, -8.0, BARREL_END - BARREL + 4.0, 16.0, EDGE)
		_b(BARREL, -6.0, BARREL_END - BARREL, 12.0, GLASS)
		var serum := BARREL_END - stopper - 4.0
		if serum > 0.0:
			_b(stopper + 4.0, -6.0, serum, 12.0, PlayFx.SERUM)
			_b(stopper + 4.0, 2.0, serum, 4.0, PlayFx.SERUM.darkened(0.25))
			# Bubbles going up it.
			for bubble in 3:
				var along := fposmod(_time * (14.0 + bubble * 5.0) + bubble * 11.0, maxf(serum - 2.0, 1.0))
				_b(BARREL_END - PIXEL - roundf(along / PIXEL) * PIXEL, -4.0 + bubble * 4.0, PIXEL, PIXEL, Color(1, 1, 1, 0.7))
		_b(stopper, -6.0, 4.0, 12.0, RUBBER)
		_b(BARREL, -6.0, BARREL_END - BARREL, PIXEL, GLASS_LIGHT)
		# The marks of the measure.
		var mark := BARREL + 8.0
		while mark < BARREL_END - 2.0:
			_b(mark, 0.0, PIXEL, 6.0, Color(EDGE, 0.55))
			mark += 6.0
		# The flange the fingers pull against.
		_b(BARREL - 4.0, -13.0, 6.0, 26.0, EDGE)
		_b(BARREL - PIXEL, -11.0, PIXEL, 22.0, STEEL)
		_b(BARREL - PIXEL, -11.0, PIXEL, 6.0, Color.WHITE)
		# The hub and the needle.
		_b(BARREL_END + PIXEL, -5.0, HUB_END - BARREL_END, 10.0, EDGE)
		_b(BARREL_END + PIXEL, -3.0, HUB_END - BARREL_END - PIXEL, 6.0, STEEL_DARK)
		var needle := LENGTH - HUB_END - PIXEL - sunk
		if needle > 0.0:
			_b(HUB_END + PIXEL, -1.0, needle, PIXEL, STEEL)
			if sunk <= 0.0:
				_b(LENGTH - PIXEL, -1.0, PIXEL, PIXEL, Color.WHITE)

	func _b(x: float, y: float, w: float, h: float, ink: Color) -> void:
		draw_rect(Rect2(x, y, w, h), ink)


## The box of whoever carries a cursed doll, as the doll feeds on it: a
## patch of the screen over the box, drawn again bent out of shape. While the
## doll sucks (`pull`, 0 to 1) the picture is drawn in towards the doll and
## twisted round it, rows of it jittering sideways and the colour going
## purple; when it lets go (`wave`, 0 to 1, fading with `strength`) a ring
## runs out from the doll pushing the picture outwards, split into colours and
## glinting. Everything is bent in blocks of 2 pixels, like the rest of the
## effects. Its own material: it stays out of the look of a borrowed action.
class WarpFx extends ColorRect:
	const CODE := "
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 rect_size = vec2(100.0);
uniform vec2 centre = vec2(50.0);
uniform float pull = 0.0;
uniform float wave = 0.0;
uniform float strength = 0.0;
uniform float time = 0.0;
uniform float reach = 120.0;
uniform float feather = 40.0;
uniform vec4 tint : source_color = vec4(0.62, 0.38, 0.8, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = floor(p / 2.0) * 2.0 + 1.0;
	vec2 d = q - centre;
	float dist = length(d);
	float fall = 1.0 - smoothstep(0.0, reach, dist);
	// Nothing is bent at the edge of the patch, and less and less on the way
	// to it: no seam between what is bent and what is not.
	float edge = min(min(p.x, rect_size.x - p.x), min(p.y, rect_size.y - p.y));
	float mask = smoothstep(0.0, feather, edge);
	mask *= mask * (3.0 - 2.0 * mask);
	float beat = floor(time * 30.0);
	float row = floor(q.y / 2.0);
	float k = pull * pull;
	// Sucked in: what is further out is drawn closer, twisted round the doll.
	vec2 offset = d * k * 0.55 * fall;
	float turn = k * 0.9 * fall;
	offset += vec2(d.x * cos(turn) - d.y * sin(turn), d.x * sin(turn) + d.y * cos(turn)) - d;
	offset.x += (hash(vec2(row, beat)) - 0.5) * 12.0 * k;
	offset.y += (hash(vec2(floor(q.x / 4.0), beat + 7.0)) - 0.5) * 4.0 * k;
	// Let go: a ring running out, pushing the picture before it.
	float ring = exp(-pow((dist - wave * reach * 1.4) / 22.0, 2.0)) * strength * mask;
	vec2 way = dist > 0.001 ? d / dist : vec2(0.0);
	offset -= way * ring * 16.0;
	offset.x += (hash(vec2(row, beat + 3.0)) - 0.5) * 14.0 * ring;
	offset *= mask;
	k *= mask;
	vec2 per = vec2(dFdx(SCREEN_UV).x / dFdx(UV).x, dFdy(SCREEN_UV).y / dFdy(UV).y) / rect_size;
	vec4 c = texture(screen_tex, SCREEN_UV + offset * per);
	float split = ring * 4.0 + k * 3.0;
	if (split > 0.05) {
		c.r = texture(screen_tex, SCREEN_UV + (offset + vec2(split, 0.0)) * per).r;
		c.b = texture(screen_tex, SCREEN_UV + (offset - vec2(split, 0.0)) * per).b;
	}
	c.rgb = mix(c.rgb, c.rgb * tint.rgb * 1.35, k * fall * 0.7);
	float glint = hash(q + beat);
	if (glint > 0.92 && ring > 0.25) {
		c.rgb = mix(c.rgb, glint > 0.97 ? vec3(1.0, 0.95, 1.0) : vec3(0.85, 0.65, 1.0), ring);
	}
	COLOR = vec4(c.rgb, 1.0);
}
"
	static var _shader: Shader

	var pull := 0.0:
		set(value):
			pull = value
			material.set_shader_parameter("pull", value)
	var wave := 0.0:
		set(value):
			wave = value
			material.set_shader_parameter("wave", value)
	var strength := 0.0:
		set(value):
			strength = value
			material.set_shader_parameter("strength", value)
	var _time := 0.0

	## Over `rect`, on screen, bending round `centre`, also on screen, as far
	## as `reach`; it eases off over the last `feather` pixels to the edge.
	func _init(rect: Rect2, centre: Vector2, reach: float, feather: float) -> void:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = CODE
		material = ShaderMaterial.new()
		material.shader = _shader
		position = rect.position
		size = rect.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material.set_shader_parameter("rect_size", rect.size)
		material.set_shader_parameter("centre", centre - rect.position)
		material.set_shader_parameter("reach", reach)
		material.set_shader_parameter("feather", feather)

	func _process(delta: float) -> void:
		_time += delta
		material.set_shader_parameter("time", _time)


## Confetti and streamers out of an empty clown gun. Confetti are flat bits of
## paper that flip over as they flutter down. Streamers are long strips of
## paper: a chain of points that unrolls out of the barrel behind its head,
## droops with its weight and falls, curling and twisting as it goes (the
## back of the strip, darker, shows where it turns over). Everything in blocks
## of PIXEL, and the node goes once the last bit has.
class ConfettiFx extends Control:
	const PIXEL := 2.0
	const AIR := 2.6  # how fast the air slows them
	const FALL := 140.0  # what gravity does to a flake
	const LIFE := 2.2
	## A streamer: how many links, how far apart, how heavy and how long it lasts.
	const LINKS := 32
	const LINK := 4.5
	const RIBBON_FALL := 230.0
	const RIBBON_AIR := 1.6
	const RIBBON_LIFE := 2.6
	const INKS: Array[Color] = [
		Color("ff4fa3"), Color("ffd84a"), Color("4fd6ff"), Color("7be04a"), Color("ff7a2a"), Color("b07bff"),
	]

	var _speed := 1.0
	var _flakes: Array = []
	var _ribbons: Array = []

	func _init(speed := 1.0) -> void:
		_speed = speed
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	## Out of `at`, along `way`: `flakes` bits of confetti and `ribbons`
	## streamers.
	func blast(at: Vector2, way: Vector2, flakes: int, ribbons: int) -> void:
		for i in flakes:
			var dir := way.rotated(randf_range(-0.6, 0.6))
			_flakes.append({
				"p": at, "v": dir * randf_range(180.0, 560.0), "c": INKS[randi() % INKS.size()],
				"t": 0.0, "life": LIFE * randf_range(0.6, 1.0), "spin": randf_range(6.0, 16.0),
				"phase": randf() * TAU, "sway": randf_range(14.0, 30.0), "big": randi() % 3 == 0,
			})
		for i in ribbons:
			# Fanned out, some higher than others, so they don't land as one.
			var dir := way.rotated(lerpf(-0.55, 0.55, (i + randf_range(-0.3, 0.3)) / maxf(ribbons - 1, 1)))
			var points: Array[Vector2] = []
			for k in LINKS:
				points.append(at)
			_ribbons.append({
				"p": points, "v": dir * randf_range(420.0, 640.0), "c": INKS[i % INKS.size()],
				"t": 0.0, "life": RIBBON_LIFE * randf_range(0.85, 1.0),
				"curl": randf_range(0.35, 0.6), "twist": randf_range(0.3, 0.55), "phase": randf() * TAU,
			})
		set_process(true)

	func _process(delta: float) -> void:
		var dt := delta * _speed
		for flake: Dictionary in _flakes:
			flake.t += dt
			flake.v *= exp(-AIR * dt)
			flake.v.y += FALL * dt
			flake.p += flake.v * dt
		for ribbon: Dictionary in _ribbons:
			ribbon.t += dt
			_pull(ribbon, dt)
		_flakes = _flakes.filter(func(flake: Dictionary) -> bool: return flake.t < flake.life)
		_ribbons = _ribbons.filter(func(ribbon: Dictionary) -> bool: return ribbon.t < ribbon.life)
		if _flakes.is_empty() and _ribbons.is_empty():
			queue_free()
		queue_redraw()

	## The head flies and falls; every link follows the one before it, never
	## more than LINK away, and sinks a little on its own: the strip unrolls out
	## of the barrel and then hangs and drops.
	func _pull(ribbon: Dictionary, dt: float) -> void:
		var points: Array[Vector2] = ribbon.p
		ribbon.v *= exp(-RIBBON_AIR * dt)
		ribbon.v.y += RIBBON_FALL * dt
		points[0] += ribbon.v * dt
		for k in range(1, points.size()):
			# Paper is light: what is out of the barrel drifts down by itself.
			if points[k] != points[k - 1]:
				points[k].y += RIBBON_FALL * 0.25 * dt * minf(ribbon.t * 2.0, 1.0)
			var gap: Vector2 = points[k] - points[k - 1]
			if gap.length() > LINK:
				points[k] = points[k - 1] + gap.normalized() * LINK

	func _draw() -> void:
		for ribbon: Dictionary in _ribbons:
			_draw_ribbon(ribbon)
		for flake: Dictionary in _flakes:
			var fade := _fade(flake)
			var turn: float = cos(flake.t * flake.spin + flake.phase)
			var at: Vector2 = flake.p + Vector2(sin(flake.t * 4.0 + flake.phase) * flake.sway * minf(flake.t, 1.0), 0.0)
			var across := maxf(1.0, roundf(absf(turn) * (3.0 if flake.big else 2.0)))
			var tall := 2.0 if flake.big else 1.0
			var ink: Color = flake.c if turn > 0.0 else flake.c.darkened(0.3)
			draw_rect(Rect2((at / PIXEL).floor() * PIXEL, Vector2(across, tall) * PIXEL), Color(ink, fade))

	## A strip along the links, curling to either side of them, as wide as
	## the paper shows where it is: full face on, a thread edge on, its darker
	## back after it turns over.
	func _draw_ribbon(ribbon: Dictionary) -> void:
		var fade := _fade(ribbon)
		var points: Array[Vector2] = ribbon.p
		var outline := Color(0.08, 0.04, 0.06, 0.55 * fade)
		var spots: Array = []
		for k in range(points.size() - 1):
			var a := points[k]
			var b := points[k + 1]
			if a == b:
				continue
			var side := (b - a).orthogonal().normalized()
			var curl: float = sin(k * ribbon.curl + ribbon.phase + ribbon.t * 4.0) * 5.0
			var twist: float = cos(k * ribbon.twist + ribbon.phase * 2.0 + ribbon.t * 6.0)
			var wide := 1 + roundi(absf(twist) * 2.0)
			var ink: Color = ribbon.c if twist > 0.0 else ribbon.c.darkened(0.4)
			spots.append([a.lerp(b, 0.5) + side * curl, side, wide, ink])
		for spot: Array in spots:
			_strip(spot[0], spot[1], spot[2], outline, PIXEL)
		for spot: Array in spots:
			_strip(spot[0], spot[1], spot[2], Color(spot[3], fade), 0.0)

	func _strip(at: Vector2, side: Vector2, wide: int, ink: Color, grow: float) -> void:
		for w in wide:
			var cell: Vector2 = ((at + side * (w - (wide - 1) / 2.0) * PIXEL) / PIXEL).floor() * PIXEL
			draw_rect(Rect2(cell - Vector2(grow, grow) / 2.0, Vector2(PIXEL * 2.0 + grow, PIXEL * 2.0 + grow)), ink)

	func _fade(bit: Dictionary) -> float:
		return clampf((bit.life - bit.t) / 0.4, 0.0, 1.0)


## The Painter's brush: a long wooden handle, a brass ferrule and the bristles
## loaded with `tint`, in cells. Its origin is the tip of the bristles, and the
## handle goes up and to the right from it.
class BrushFx extends Control:
	const CELL := 2.0
	const HANDLE := Color("6a2e1c")
	const HANDLE_LIGHT := Color("94482a")
	const FERRULE := Color("b8b8c0")
	const FERRULE_DARK := Color("6c6c74")
	const OUTLINE := Color("1b0f14")

	var tint := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		# Stirring: little circles over the palette, while it waits.
		if get_meta(&"stir", false):
			rotation = 0.3 * sin(_time * 5.0)
			position += Vector2(cos(_time * 5.0), sin(_time * 5.0)) * 0.6
		queue_redraw()

	func _draw() -> void:
		# Along the brush, from the tip (0) up the handle.
		var way := Vector2(0.55, -0.83)
		var side := way.orthogonal()
		for i: int in 34:
			var along := i * CELL
			var half := 3 if i < 8 else (2 if i < 13 else 1)
			for w: int in range(-half, half + 1):
				var at := (way * along + side * w * CELL).snapped(Vector2(CELL, CELL))
				var ink: Color
				if i < 8:
					ink = tint.lightened(0.3) if w < 0 else (tint.darkened(0.3) if w == half else tint)
					if i < 2 and absi(w) == half:
						continue
				elif i < 13:
					ink = FERRULE if w <= 0 else FERRULE_DARK
				else:
					ink = HANDLE_LIGHT if w < 0 else HANDLE
				if absi(w) == half and i >= 8:
					ink = OUTLINE
				draw_rect(Rect2(at, Vector2(CELL, CELL)), ink)


## A stroke of paint laid along a line as `progress` goes from 0 to 1: a band
## with ragged edges and the streaks of the bristles in it.
class StrokeFx extends Control:
	const CELL := 2.0

	var tint := Color.WHITE
	var thick := 10.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var length := from.distance_to(to) * progress
		var way := (to - from).normalized()
		var side := way.orthogonal()
		var along := 0.0
		while along < length:
			var ragged := 2.0 * floorf(1.5 * sin(along * 0.21) + 0.8 * sin(along * 0.57))
			var top := -thick / 2.0 + ragged * 0.5
			var bottom := thick / 2.0 + ragged
			var across := top
			while across < bottom:
				var at := (from + way * along + side * across).snapped(Vector2(CELL, CELL))
				var streak := fposmod(across + 3.0 * sin(along * 0.05), 6.0) < 2.0
				var ink := tint.lightened(0.25) if across < top + CELL else (tint.darkened(0.25) if streak else tint)
				draw_rect(Rect2(at, Vector2(CELL, CELL)), ink)
				across += CELL
			along += CELL


## The Painter's palette, small, held beside his box during a Monochrome: a
## kidney of wood and the three gobs of paint, the one dipped into (`dipped`)
## swirling. Drawn in cells around its middle.
class PaletteFx extends Control:
	const CELL := 2.0
	const REACH := Vector2(38, 24)
	const WOOD := [Color("6e4222"), Color("8f5a30"), Color("b07a44"), Color("cf9e60")]
	const OUTLINE := Color("1b0f14")

	var dipped := -1
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Where gob `i` sits, from the middle.
	func gob(i: int) -> Vector2:
		return [Vector2(-20, -6), Vector2(-4, -13), Vector2(13, -11), Vector2(-18, 8)][clampi(i, 0, 3)]

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var y := -REACH.y
		while y <= REACH.y:
			var x := -REACH.x
			while x <= REACH.x:
				var u := x / REACH.x
				var v := y / REACH.y
				var round_ := u * u + v * v
				var hole := Vector2(x, y).distance_to(Vector2(20, 8))
				if round_ <= 1.0 and hole > 5.0:
					var ink: Color = OUTLINE if round_ > 0.86 or hole < 7.0 else WOOD[clampi(int((0.6 - u * 0.2 - v * 0.3) * WOOD.size()), 0, 3)]
					draw_rect(Rect2(x, y, CELL, CELL), ink)
				x += CELL
			y += CELL
		for i: int in Painter.PAINTS.size():
			var paint: Color = Painter.PAINTS[i]
			var r := 5.0 + (1.5 * sin(_time * 8.0) if i == dipped else 0.0)
			var at := gob(i)
			var gy := -r
			while gy <= r:
				var gx := -r
				while gx <= r:
					if Vector2(gx, gy).length() <= r:
						var ink := paint.lightened(0.35) if gx + gy < -r * 0.6 else paint
						draw_rect(Rect2((at + Vector2(gx, gy)).snapped(Vector2(CELL, CELL)), Vector2(CELL, CELL)), ink)
					gx += CELL
				gy += CELL


## The Duelist's sword, a rapier seen flat, in blocks of PIXEL: brass pommel,
## leather grip, swept brass guard and a long steel blade that tapers to the
## point. The origin is the guard; the blade points along +x. Built cell by
## cell once (_init) and outlined; `sunk` hides the end of the blade (driven
## into something), `keep_from`/`keep_to` keep only a stretch of it (the two
## pieces of a broken sword), `glow` sets it red hot, `quiver` shakes it,
## `bob` lets it hang in the air, breathing and swaying, and `trail` leaves
## fading copies of where it was a moment ago behind it as it moves.
class SwordFx extends Control:
	const PIXEL := 2.0
	## The cell of the point, and where the blade gives way when it breaks.
	const TIP := 38
	const SNAP := 18
	const OUTLINE := Color("0e0a0c")
	const STEEL_LIT := Color("eef3fa")
	const STEEL := Color("b8c2d0")
	const STEEL_DARK := Color("6c7686")
	const BRASS: Array[Color] = [Color("f2d488"), Color("c8962e"), Color("7a5418")]
	const LEATHER: Array[Color] = [Color("8a4a24"), Color("5a2a14"), Color("3a180a")]
	const HOT := Color("ff3a1a")
	## How many frames of blur a moving sword leaves behind, and their tint.
	const TRAIL := 6
	const BLUR := Color("dfe9ff")

	var sunk := 0.0:
		set(value):
			sunk = value
			queue_redraw()
	var keep_from := -99
	var keep_to := 99
	var glow := 0.0
	var quiver := 0.0
	var bob := false
	var trail := 0.0

	var _cells: Array = []  # [Vector2i, Color]
	## Where it was over the last TRAIL frames, oldest first (parent space).
	var _past: Array[Transform2D] = []
	var _time := randf() * 10.0
	var _shine := -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inks := {}
		# The blade, three rows that taper to one.
		for x in range(1, TIP + 1):
			inks[Vector2i(x, 0)] = STEEL
			if x < TIP - 6:
				inks[Vector2i(x, -1)] = STEEL_LIT
			if x < TIP - 3:
				inks[Vector2i(x, 1)] = STEEL_DARK
		# The guard, swept back at both ends.
		for y in range(-5, 6):
			inks[Vector2i(0, y)] = BRASS[0] if y < 0 else BRASS[1]
		for y in range(-4, 5):
			inks[Vector2i(-1, y)] = BRASS[2]
		inks[Vector2i(1, -5)] = BRASS[0]
		inks[Vector2i(1, 5)] = BRASS[1]
		inks[Vector2i(2, -5)] = BRASS[1]
		inks[Vector2i(2, 5)] = BRASS[2]
		# The grip, wrapped.
		for x in range(-8, -1):
			inks[Vector2i(x, -1)] = LEATHER[0]
			inks[Vector2i(x, 0)] = LEATHER[1] if x % 2 == 0 else LEATHER[0]
			inks[Vector2i(x, 1)] = LEATHER[2]
		# The pommel.
		for at: Vector2i in [Vector2i(-10, -2), Vector2i(-11, -1), Vector2i(-10, -1), Vector2i(-9, -1),
				Vector2i(-11, 0), Vector2i(-10, 0), Vector2i(-9, 0), Vector2i(-11, 1), Vector2i(-10, 1), Vector2i(-9, 1), Vector2i(-10, 2)]:
			inks[at] = BRASS[0] if at.y < 0 else (BRASS[1] if at.y == 0 else BRASS[2])
		var rim := {}
		for at: Vector2i in inks:
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not inks.has(at + step):
					rim[at + step] = OUTLINE
		for at: Vector2i in rim:
			_cells.append([at, OUTLINE])
		for at: Vector2i in inks:
			_cells.append([at, inks[at]])

	## A gleam runs down the blade, once.
	func shine() -> void:
		_shine = 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _shine >= 0.0:
			_shine += delta * 2.2
			if _shine > 1.2:
				_shine = -1.0
		if trail > 0.0:
			_past.append(get_transform())
			if _past.size() > TRAIL:
				_past.pop_front()
		elif not _past.is_empty():
			_past.pop_front()
		queue_redraw()

	func _draw() -> void:
		# The blur first, under the sword: each copy where it was, fainter
		# the older it is.
		var here := get_transform().affine_inverse()
		for i in _past.size():
			var fade := float(i + 1) / (_past.size() + 1) * 0.45 * maxf(trail, 0.3)
			draw_set_transform_matrix(here * _past[i])
			for cell: Array in _cells:
				var at: Vector2i = cell[0]
				if cell[1] != OUTLINE and at.x >= keep_from and at.x <= keep_to and at.x <= TIP - int(sunk):
					draw_rect(Rect2((Vector2(at) - Vector2(0.5, 0.5)) * PIXEL, Vector2(PIXEL, PIXEL)), Color(BLUR, fade))
		var drift := Vector2.ZERO
		var sway := 0.0
		if bob:
			drift.y = sin(_time * 2.2) * 2.0
			sway = sin(_time * 1.3) * 0.06
		if quiver > 0.0:
			drift += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * quiver
		draw_set_transform(drift.rotated(-rotation), sway)
		var hidden := TIP - int(sunk)
		var gleam := int(lerpf(1.0, TIP, _shine)) if _shine >= 0.0 else -999
		var hot := clampf(glow, 0.0, 1.0)
		if hot > 0.0:
			# A red heat round all of it, flickering.
			var halo := Color(HOT, 0.18 * hot * (0.8 + 0.2 * sin(_time * 25.0)))
			for cell: Array in _cells:
				var at: Vector2i = cell[0]
				if at.x >= keep_from and at.x <= keep_to and at.x <= hidden:
					draw_rect(Rect2((Vector2(at) - Vector2(1.5, 1.5)) * PIXEL, Vector2(3, 3) * PIXEL), halo)
		for cell: Array in _cells:
			var at: Vector2i = cell[0]
			if at.x < keep_from or at.x > keep_to or at.x > hidden:
				continue
			var ink: Color = cell[1]
			if ink != OUTLINE:
				if hot > 0.0 and at.x > 0:
					ink = ink.lerp(HOT.lightened(0.2 * float(at.y == -1)), hot * 0.7)
				if absi(at.x - gleam) <= 1 and at.x > 0:
					ink = ink.lerp(Color.WHITE, 0.8)
			draw_rect(Rect2((Vector2(at) - Vector2(0.5, 0.5)) * PIXEL, Vector2(PIXEL, PIXEL)), ink)


## The fury of a Berserk round a box: blocky flames licking up from its
## edges, darker red at the root and yellow at the tips, as tall as `heat`.
class FuryFx extends Control:
	const CELL := 3.0
	const INKS: Array[Color] = [Color("5a0a08"), Color("b3201a"), Color("e0261a"), Color("ff7a2a"), Color("ffd060")]

	var rect := Rect2()
	var heat := 0.0

	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if heat <= 0.01:
			return
		var reach := 22.0 * heat
		var r := Rect2(rect.position.snapped(Vector2(CELL, CELL)), rect.size.snapped(Vector2(CELL, CELL)))
		# Along the top, flames go up; along the sides, they lean out.
		var x := r.position.x
		while x < r.end.x:
			_flame(Vector2(x, r.position.y), Vector2.UP, reach, x * 0.13)
			_flame(Vector2(x, r.end.y), Vector2.UP, reach * 0.4, x * 0.11 + 3.0)
			x += CELL
		var y := r.position.y
		while y < r.end.y:
			_flame(Vector2(r.position.x, y), Vector2(-0.6, -0.8), reach * 0.7, y * 0.17 + 7.0)
			_flame(Vector2(r.end.x, y), Vector2(0.6, -0.8), reach * 0.7, y * 0.15 + 11.0)
			y += CELL
		# The box itself glows from inside.
		draw_rect(r, Color(INKS[2], 0.12 * clampf(heat, 0.0, 1.0)))
		draw_rect(r, Color(INKS[3], 0.7 * clampf(heat, 0.0, 1.0)), false, CELL)

	func _flame(root: Vector2, way: Vector2, reach: float, phase: float) -> void:
		var tall := reach * (0.45 + 0.55 * absf(sin(phase + _time * 7.0) * cos(phase * 0.7 + _time * 4.3)))
		var steps := int(tall / CELL)
		for i in steps:
			var k := float(i) / maxf(steps, 1)
			var ink: Color = INKS[clampi(1 + int(k * 3.99), 0, 4)]
			ink.a = 1.0 - k * 0.6
			var at := (root + way * i * CELL).snapped(Vector2(CELL, CELL))
			draw_rect(Rect2(at, Vector2(CELL, CELL)), ink)


## The crack a sword driven into the table leaves round its point: a few
## jagged splits of dark wood radiating out, lit on one lip, in blocks of
## CELL. `grow` takes them from nothing to their full length.
class CrackFx extends Control:
	const CELL := 2.0
	const DARK := Color(0.08, 0.04, 0.02, 0.85)
	const LIP := Color(0.85, 0.62, 0.38, 0.35)

	var grow := 0.0:
		set(value):
			grow = value
			queue_redraw()

	var _splits: Array = []  # each an Array of Vector2, from the middle out

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := randi_range(5, 7)
		for i in count:
			var angle := TAU * (i + randf_range(-0.3, 0.3)) / count
			var length := randf_range(18.0, 34.0)
			var points: Array = [Vector2.ZERO]
			var at := Vector2.ZERO
			var steps := 4
			for k in steps:
				angle += randf_range(-0.5, 0.5)
				at += Vector2.from_angle(angle) * length / steps
				# Flattened: it is the table, seen from above at a slant.
				points.append(Vector2(at.x, at.y * 0.55))
			_splits.append(points)

	func _draw() -> void:
		for points: Array in _splits:
			for k in points.size() - 1:
				var a: Vector2 = points[k]
				var b: Vector2 = points[k + 1]
				var reach := clampf(grow * (points.size() - 1) - k, 0.0, 1.0)
				if reach <= 0.0:
					continue
				b = a.lerp(b, reach)
				var steps := maxi(int(a.distance_to(b) / CELL), 1)
				for n in steps + 1:
					var p := a.lerp(b, float(n) / steps).snapped(Vector2(CELL, CELL))
					var thick := CELL * (2.0 if k == 0 else 1.0)
					draw_rect(Rect2(p, Vector2(thick, thick)), DARK)
					draw_rect(Rect2(p + Vector2(0, -CELL), Vector2(CELL, CELL)), LIP)
		# The splintered hole the point is in.
		draw_rect(Rect2(Vector2(-3, -2) * CELL, Vector2(6, 4) * CELL), Color(DARK, DARK.a * grow))


## The skull of a Retaliation, seen from the front, in blocks of PIXEL, with
## its middle at the origin. `formed` (0 to 1) sets it out of blood: cells
## show up red in no order and turn to bone. `eyes` lights the sockets, whose
## sparks look along `gaze`; `fire` is the green fire it burns in, streaming
## back from where it is going; `jaw` opens it (`chatter` makes it rattle on
## its own) and `trail` leaves faint copies of it behind as it flies.
class SkullFx extends Control:
	const PIXEL := 5.0
	const CRANIUM: Array = [
		"...KKKKK...",
		"..KLLBBBK..",
		".KLLBBBBSK.",
		"KLBBBBBBBSK",
		"KBEEEBEEESK",
		"KBEEEBEEESK",
		"KSBEEBEESSK",
		".KSBBNBBSK.",
		".KSSNNNSSK.",
		"..KSSSSSK..",
	]
	const JAW: Array = [
		"..KTKTKTK..",
		"..KSBBBSK..",
		"...KKKKK...",
	]
	const COLUMNS := 11
	const INKS := {
		"K": Color("2a2418"), "L": Color("fffaf0"), "B": Color("e8e0c8"), "S": Color("a89c80"),
		"E": Color("0a0f0c"), "N": Color("1a1612"), "T": Color("f4efdc"),
	}
	const FLAME: Array = [Color("0f4a2a"), Color("1f8a4a"), Color("3fd070"), Color("8cff9e"), Color("e6ffe8")]
	const GLOW := Color("7dff9a")
	const BLOOD := Color("8a1410")
	## How much of it is still smeared with blood once it has set.
	const STAINED := 0.35
	const GHOST_EVERY := 0.02
	const GHOST_LIFE := 0.18

	var speed := 1.0
	var formed := 0.0
	var eyes := 0.0
	var fire := 0.0
	var jaw := 0.0
	var chatter := 0.0
	var gaze := Vector2.ZERO
	var trail := false
	## 1: it comes out of the clot all smeared; it dries to STAINED.
	var bloody := 1.0
	var _clock := 0.0
	var _was := Vector2.INF
	var _lean := Vector2.ZERO
	var _ghosts: Array = []  # {at, t}
	var _since := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var dt := delta * speed
		_clock += dt
		var moved := Vector2.ZERO if _was == Vector2.INF else position - _was
		_was = position
		# The fire streams back from the way it goes, and settles when it stops.
		var pull := (-moved / maxf(dt, 0.001) * 0.012).limit_length(10.0)
		_lean = _lean.lerp(pull, minf(1.0, dt * 12.0))
		for ghost: Dictionary in _ghosts:
			ghost.t += dt
		_ghosts = _ghosts.filter(func(ghost: Dictionary) -> bool: return ghost.t < GHOST_LIFE)
		_since += dt
		if trail and moved.length() > 0.5 and _since >= GHOST_EVERY:
			_since = 0.0
			_ghosts.append({"at": position, "t": 0.0})
		queue_redraw()

	func _draw() -> void:
		for ghost: Dictionary in _ghosts:
			var left := 1.0 - float(ghost.t) / GHOST_LIFE
			var local: Vector2 = ((ghost.at - position) / scale).rotated(-rotation)
			_figure(local, Color(GLOW, 0.4 * left * left))
		if fire > 0.0:
			_draw_fire()
		_figure(Vector2.ZERO)

	## Tongues of fire round the crown, flickering, leaning with _lean.
	func _draw_fire() -> void:
		var top := -float(CRANIUM.size() + JAW.size()) / 2.0
		for gy in range(-12, 8):
			var rise := clampf(-float(gy) / 12.0, 0.0, 1.0)
			var width := 9.0 - 6.0 * rise + 0.8 * sin(_clock * 7.0 + gy)
			for gx in range(-11, 12):
				var lean := _lean.x / PIXEL * rise * 1.4
				var d := absf(gx - lean - sin(_clock * 5.0 + gy * 0.7) * rise * 1.2)
				var lick := 0.5 + 0.5 * sin(_clock * 11.0 + gx * 1.9 + gy * 1.3)
				var heat := (1.2 - d / width) * (1.0 - rise * 0.6) * (0.7 + 0.4 * lick)
				if heat <= 0.05:
					continue
				var level := clampf(heat * 1.2, 0.0, 0.999) * (FLAME.size() - 1)
				var ink: Color = FLAME[int(level)]
				var at := Vector2(gx - 0.5, top + gy + 1.0 + _lean.y / PIXEL * rise) * PIXEL
				draw_rect(Rect2(at, Vector2(PIXEL, PIXEL)), Color(ink, fire * minf(1.0, heat * 2.5)))

	func _figure(at: Vector2, ink: Variant = null) -> void:
		var rows := CRANIUM.size() + JAW.size()
		var corner := at - Vector2(COLUMNS, rows) * PIXEL / 2.0
		var opened := maxf(jaw, chatter * (0.5 + 0.5 * sin(_clock * 40.0)))
		var drop := roundf(opened * 2.0) * PIXEL
		var look := Vector2i(clampi(roundi(gaze.x * 1.2), -1, 1), -1 if gaze.y < -0.55 else 0)
		for y in rows:
			var row: String = CRANIUM[y] if y < CRANIUM.size() else JAW[y - CRANIUM.size()]
			var down := drop if y >= CRANIUM.size() else 0.0
			for x in COLUMNS:
				var cell := row[x]
				if cell == ".":
					continue
				var block := Rect2(corner + Vector2(x * PIXEL, y * PIXEL + down), Vector2(PIXEL, PIXEL))
				if ink != null:
					draw_rect(block, ink)
					continue
				var chance := fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
				if chance > formed + 0.3:
					continue
				var color: Color = INKS[cell]
				if chance > formed:
					color = BLOOD.lightened(0.15 * chance)
				elif cell != "E" and cell != "K" and cell != "N":
					# Smeared: blood in streaks running down from the crown.
					var smear := fposmod(sin(x * 37.719 + floorf(y / 3.0) * 11.31) * 9137.13, 1.0)
					if smear < bloody * 0.6:
						color = color.lerp(BLOOD if smear > bloody * 0.25 else Color("5a0808"), 0.55 + 0.3 * bloody)
				if cell == "E" and eyes > 0.0 and chance <= formed:
					# The spark in each socket, and its light round it.
					var core := (x == 3 + look.x or x == 7 + look.x) and y == 5 + look.y
					color = color.lerp(GLOW, eyes * (1.0 if core else 0.25))
					if core:
						color = color.lerp(Color.WHITE, 0.4 * eyes)
				draw_rect(block, color)
		if ink == null and eyes > 0.0 and formed >= 1.0:
			for socket: float in [3.0, 7.0]:
				var middle := corner + Vector2((socket + look.x + 0.5) * PIXEL, (5.5 + look.y) * PIXEL)
				var flicker := 0.75 + 0.25 * sin(_clock * 13.0 + socket)
				draw_rect(Rect2(middle - Vector2(5, 5), Vector2(10, 10)), Color(GLOW, 0.22 * eyes * flicker))


## A cord of blood from `a` to `b`: thick and fleshy, uneven along its
## length, dark at the rims, glistening on top and twisted with sinew. It is
## grown as far as `reach` (0 to 1), with a swollen head while it is still
## lunging, and gone up to `eaten`, where it ends torn and spraying. It hangs
## as loose as `slack` says; bulges run down it to the far end, as if it
## pumped, and thick drops fall off it. All in blocks of CELL.
class ThreadFx extends Control:
	const CELL := 3.0
	## How thick it is (its radius in px), and how much a bulge adds.
	const GIRTH := 10.0
	const BULGE := 6.0
	const HEAD := 1.7
	const RIM := Color("2a0303")
	const DEEP := Color("6a0a0a")
	const RED := Color("a8180f")
	const BRIGHT := Color("d83020")
	const SHINE := Color("ff9a80")

	var speed := 1.0
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var reach := 0.0
	var eaten := 0.0
	var slack := 12.0
	var _clock := 0.0
	var _drops: Array = []  # {p, v, t, s}
	var _since := 0.0
	var _was_eaten := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _point(t: float) -> Vector2:
		var way := b - a
		var side := way.orthogonal().normalized()
		var wiggle := (sin(t * 13.0 - _clock * 11.0) + 0.35 * sin(t * 37.0 + _clock * 8.0)) * slack * sin(PI * t)
		# It sags under its own weight.
		return a + way * t + side * wiggle + Vector2(0.0, slack * 0.9 * sin(PI * t))

	## Its radius at `t`: uneven, swelling where a bulge passes, a head at
	## the front while it is still reaching and frayed where it was torn.
	func _girth(t: float) -> float:
		var length := maxf(a.distance_to(b), 1.0)
		var r := GIRTH * (0.8 + 0.2 * sin(t * length / 23.0) + 0.12 * sin(t * length / 7.0 + 1.3))
		var bulge := fposmod(t * 2.2 - _clock * 1.8, 1.0)
		r += BULGE * exp(-pow((bulge - 0.5) / 0.07, 2.0))
		if reach < 1.0:
			r *= 1.0 + (HEAD - 1.0) * clampf(1.0 - (reach - t) * length / 18.0, 0.0, 1.0)
		if eaten > 0.0:
			r *= 1.0 + 0.6 * clampf(1.0 - (t - eaten) * length / 14.0, 0.0, 1.0)
		# The ends taper into the skull and into the box it holds on to.
		return r * clampf(minf(t, 1.0 - t) * length / 10.0 + 0.45, 0.0, 1.0)

	func _process(delta: float) -> void:
		var dt := delta * speed
		_clock += dt
		_since += dt
		if reach > 0.2 and eaten < reach and _since > 0.045:
			_since = 0.0
			var at := _point(randf_range(eaten, reach))
			_drops.append({"p": at, "v": Vector2(randf_range(-15, 15), 30), "t": 0.0, "s": 1.0 + randf()})
		# Torn as it is eaten: the end sprays.
		if eaten > _was_eaten and eaten < 1.0:
			var at := _point(eaten)
			for i in 3:
				var out := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 200.0) + Vector2(0, -60)
				_drops.append({"p": at, "v": out, "t": 0.0, "s": 1.0 + randf() * 1.5})
		_was_eaten = eaten
		for drop: Dictionary in _drops:
			drop.t += dt
			drop.v.y += 700.0 * dt
			drop.p += drop.v * dt
		_drops = _drops.filter(func(drop: Dictionary) -> bool: return drop.t < 0.6)
		queue_redraw()

	func _draw() -> void:
		var length := a.distance_to(b)
		if length < 1.0 or reach <= 0.0:
			return
		var cells := {}
		var steps := int(length / 2.5)
		for i in steps + 1:
			var t := float(i) / steps
			if t > reach or t < eaten:
				continue
			var p := _point(t)
			var ahead := _point(minf(t + 0.01, 1.0)) - _point(maxf(t - 0.01, 0.0))
			var n := ahead.orthogonal().normalized()
			if n.y > 0.0:
				n = -n  # n points up: that side catches the light.
			var r := _girth(t)
			var v := -r
			while v <= r:
				var u := v / r  # -1 the top rim, 1 the bottom one
				var ink := RED
				if absf(u) > 0.78:
					ink = RIM
				elif u > 0.3:
					ink = DEEP
				elif u < -0.2:
					ink = BRIGHT
				# Sinew, twisting along it.
				if fposmod(t * length / 9.0 + u * 0.8, 1.0) < 0.14 and absf(u) < 0.7:
					ink = DEEP
				# Wet: a glint that slides along the top.
				if u > -0.62 and u < -0.36 and fposmod(t * length / 17.0 - _clock * 0.6, 1.0) < 0.3:
					ink = SHINE
				cells[Vector2i(((p - n * v) / CELL).floor())] = ink
				v += CELL * 0.7
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), cells[cell])
		for drop: Dictionary in _drops:
			var corner: Vector2 = (drop.p / CELL).floor() * CELL
			var stretch: float = clampf(absf(drop.v.y) / 250.0, 1.0, 2.2)
			var size: Vector2 = Vector2(CELL, CELL * stretch) * drop.s
			draw_rect(Rect2(corner - Vector2(1, 1), size + Vector2(2, 2)), Color(RIM, 1.0 - drop.t / 0.6))
			draw_rect(Rect2(corner, size), Color(RED, 1.0 - drop.t / 0.6))

## Bits of a skull flying apart: a few small bone shapes, turning, that fall,
## bounce once on the table and lie there a moment before they fade.
class ShardsFx extends Control:
	const CELL := 3.0
	const SHAPES: Array = [
		[".##.", "####", "#..#"],
		["##", "##", "#."],
		["###.", ".###"],
		["..#", ".##", "##."],
		["#.#.#", "#####"],
		["##", "#."],
	]
	const BONE := Color("e8e0c8")
	const SHADE := Color("a89c80")
	const EDGE := Color("2a2418")
	const LIFE := 1.1

	var speed := 1.0
	var _pieces: Array = []  # {p, v, r, spin, shape, floor, hops, t, tone}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Flung out from the origin, mostly along `way`.
	func burst(way: Vector2) -> void:
		for i in 16:
			var out := (way * 0.6 + Vector2.from_angle(randf() * TAU)).normalized()
			_pieces.append({
				"p": Vector2.ZERO, "v": out * randf_range(140.0, 340.0) + Vector2(0, -160.0),
				"r": randf() * TAU, "spin": randf_range(-14.0, 14.0), "shape": i % SHAPES.size(),
				"floor": randf_range(26.0, 64.0), "hops": 0, "t": 0.0, "tone": randf_range(-0.12, 0.1),
			})

	func _process(delta: float) -> void:
		var dt := delta * speed
		var alive := false
		for piece: Dictionary in _pieces:
			piece.t += dt
			if piece.hops < 2:
				piece.v.y += 980.0 * dt
				piece.p += piece.v * dt
				piece.r += piece.spin * dt
				if piece.p.y > piece.floor and piece.v.y > 0.0:
					piece.p.y = piece.floor
					piece.hops += 1
					piece.v = Vector2(piece.v.x * 0.5, -piece.v.y * 0.3)
					piece.spin *= 0.4
			alive = alive or piece.t < LIFE
		if not alive:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for piece: Dictionary in _pieces:
			var fade := 1.0 - clampf((piece.t - LIFE * 0.6) / (LIFE * 0.4), 0.0, 1.0)
			if fade <= 0.0:
				continue
			var shape: Array = SHAPES[piece.shape]
			var middle := Vector2(shape[0].length(), shape.size()) * CELL / 2.0
			draw_set_transform(piece.p, piece.r)
			for pass_ in 2:
				for y in shape.size():
					var row: String = shape[y]
					for x in row.length():
						if row[x] == ".":
							continue
						var at := Vector2(x, y) * CELL - middle
						if pass_ == 0:
							draw_rect(Rect2(at - Vector2(1, 1), Vector2(CELL + 2.0, CELL + 2.0)), Color(EDGE, fade))
						else:
							var ink := (SHADE if y == shape.size() - 1 else BONE).lightened(piece.tone)
							draw_rect(Rect2(at, Vector2(CELL, CELL)), Color(ink, fade))
		draw_set_transform(Vector2.ZERO, 0.0)


## A circle of summoning lying on the table, seen at a slant: two rings, a
## five-pointed star between them and runes round it, all in green blocks
## that flicker. It opens out to `radius` as `open` goes to 1, and turns,
## the way `spin` says.
class SigilFx extends Control:
	const CELL := 2.0
	const SQUASH := 0.42
	const GLOW := Color("7dff9a")
	const DEEP := Color("1f8a4a")
	const RUNES: Array = [
		["#.#", "###", ".#.", ".#.", ".#."],
		["##.", "#.#", "##.", "#..", "#.."],
		["#..", "##.", "#.#", "##.", "#.."],
		[".#.", "#.#", ".#.", "#.#", ".#."],
		["###", "..#", ".#.", "#..", "###"],
		["#.#", "#.#", ".#.", "#.#", "#.#"],
	]

	var speed := 1.0
	var radius := 60.0
	var open := 0.0
	var spin := 1.0
	var _turn := 0.0
	var _clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock += delta * speed
		_turn += delta * speed * 0.9 * spin
		queue_redraw()

	func _on(angle: float, r: float) -> Vector2:
		return Vector2(cos(angle) * r, sin(angle) * r * SQUASH)

	func _ring(cells: Dictionary, r: float) -> void:
		var steps := maxi(int(TAU * r / CELL), 12)
		for i in steps:
			cells[Vector2i((_on(TAU * i / steps, r) / CELL).floor())] = true

	func _stroke(cells: Dictionary, from: Vector2, to: Vector2) -> void:
		var steps := maxi(int(from.distance_to(to) / CELL), 1)
		for i in steps + 1:
			cells[Vector2i((from.lerp(to, float(i) / steps) / CELL).floor())] = true

	func _draw() -> void:
		if open <= 0.0:
			return
		var r := radius * open
		var alpha := clampf(open, 0.0, 1.0)
		var cells := {}
		_ring(cells, r)
		_ring(cells, r * 0.8)
		var points: Array[Vector2] = []
		for i in 5:
			points.append(_on(_turn + TAU * i / 5.0 - PI / 2.0, r * 0.78))
		for i in 5:
			_stroke(cells, points[i], points[(i + 2) % 5])
		for i in RUNES.size():
			var at := _on(-_turn * 0.6 + TAU * i / RUNES.size(), r * 0.9) / CELL
			var rune: Array = RUNES[i]
			for y in rune.size():
				for x in 3:
					if rune[y][x] == "#":
						cells[Vector2i(floori(at.x) + x - 1, floori(at.y) + y - 2)] = true
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * CELL - Vector2(2, 2), Vector2(CELL + 4.0, CELL + 4.0)), Color(DEEP, 0.35 * alpha))
		for cell: Vector2i in cells:
			var flicker := 0.6 + 0.4 * sin(_clock * 7.0 + cell.x * 0.35 + cell.y * 0.8)
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(GLOW, alpha * flicker))


## A soul out of its body: a small ghost in blocks with hollow eyes and a
## wailing mouth, its tail rippling under it. `struggle` makes it writhe,
## `stretch` draws it out along `heading` (the way it is being pulled) and
## `trail` leaves faint copies of it behind. circle() sets it going round a
## point, flattened, as if over the table.
class SoulFx extends Control:
	const PIXEL := 4.0
	const BODY := Color("d8fff0")
	const RIM := Color("5fe0a0")
	const HOLLOW := Color("0a1a14")
	const SHAPE: Array = [
		"...ooooo...",
		"..owwwwwo..",
		".owwwwwwwo.",
		"owwKKwKKwwo",
		"owwKKwKKwwo",
		"owwwwwwwwwo",
		"owwwwKwwwwo",
		"owwwKKKwwwo",
		"owwwwKwwwwo",
		"owwwwwwwwwo",
	]
	const COLUMNS := 11
	const TAIL := 4
	const GHOST_EVERY := 0.025
	const GHOST_LIFE := 0.3

	var speed := 1.0
	var struggle := 0.0
	var stretch := 0.0
	var heading := Vector2.ZERO
	var trail := false
	var _clock := 0.0
	var _ghosts: Array = []  # {at, t}
	var _since := 0.0
	var _center := Vector2.ZERO
	var _radius := 0.0
	var _angle := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func circle(center: Vector2, radius: float) -> void:
		_center = center
		_radius = radius
		_angle = (position - center).angle() if radius > 0.0 else 0.0

	func _process(delta: float) -> void:
		var dt := delta * speed
		_clock += dt
		if _radius > 0.0:
			_angle += dt * 3.2
			var at := _center + Vector2(cos(_angle), sin(_angle) * 0.5) * _radius
			position = position.lerp(at, minf(1.0, dt * 8.0))
		for ghost: Dictionary in _ghosts:
			ghost.t += dt
		_ghosts = _ghosts.filter(func(ghost: Dictionary) -> bool: return ghost.t < GHOST_LIFE)
		_since += dt
		if trail and _since >= GHOST_EVERY:
			_since = 0.0
			_ghosts.append({"at": position, "t": 0.0})
		queue_redraw()

	func _draw() -> void:
		for ghost: Dictionary in _ghosts:
			var left := 1.0 - float(ghost.t) / GHOST_LIFE
			draw_set_transform(((ghost.at - position) / scale).rotated(-rotation), 0.0, Vector2(0.8, 0.8))
			_figure(Color(RIM, 0.35 * left * left))
		var wobble := Vector2(sin(_clock * 17.0) * 2.0 * struggle, sin(_clock * 13.0) * struggle)
		var turn := sin(_clock * 11.0) * 0.16 * struggle
		if heading.length() > 0.5:
			turn = lerp_angle(turn, heading.angle() + PI / 2.0, stretch)
		draw_set_transform(wobble, turn, Vector2(1.0 - 0.25 * stretch, 1.0 + 0.7 * stretch))
		var glow := 0.75 + 0.25 * sin(_clock * 5.0)
		draw_rect(Rect2(Vector2(-COLUMNS * 0.8, -9.0) * PIXEL, Vector2(COLUMNS * 1.6, 18.0) * PIXEL), Color(RIM, 0.08 * glow))
		draw_rect(Rect2(Vector2(-COLUMNS * 0.65, -7.5) * PIXEL, Vector2(COLUMNS * 1.3, 15.0) * PIXEL), Color(RIM, 0.12 * glow))
		_figure()
		draw_set_transform(Vector2.ZERO, 0.0)

	func _figure(ink: Variant = null) -> void:
		var rows := SHAPE.size() + TAIL
		var corner := -Vector2(COLUMNS, rows) * PIXEL / 2.0
		# The mouth opens and shuts on the wail.
		var wail := 0.5 + 0.5 * sin(_clock * 9.0)
		for y in SHAPE.size():
			var row: String = SHAPE[y]
			for x in COLUMNS:
				var cell := row[x]
				if cell == ".":
					continue
				var color: Color = RIM if cell == "o" else (HOLLOW if cell == "K" else BODY)
				if cell == "K" and y == 8 and wail < 0.4:
					color = BODY
				draw_rect(Rect2(corner + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), color if ink == null else ink)
		# The tail: three tips rippling, thinning to nothing.
		for k in TAIL:
			for x in COLUMNS:
				var ripple := sin(x * 1.7 - _clock * 9.0) * 0.5 + 0.5
				if k >= int(ripple * TAIL + 0.5) or (k == TAIL - 1 and x % 4 == 1):
					continue
				var y := SHAPE.size() + k
				var color: Color = RIM if x == 0 or x == COLUMNS - 1 or k == int(ripple * TAIL - 0.5) else BODY
				color.a = 1.0 - 0.18 * k
				if ink != null:
					color = ink
				draw_rect(Rect2(corner + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), color)


## A green tendril reaching from `a` towards `b`, as far as `reach` (0 to 1),
## writhing, thorned, with light running out along it to a bony claw at its
## end, which closes as `grip` goes to 1.
class TendrilFx extends Control:
	const CELL := 3.0
	const GLOW := Color("7dff9a")
	const DEEP := Color("1f8a4a")
	const DARK := Color("06140c")
	const BONE := Color("e8e0c8")
	const SHADE := Color("a89c80")
	## Facing right, the fingers spread and closed.
	const CLAWS: Array = [
		[
			".....BB.",
			"...BB...",
			"BBBB....",
			"BBBBSSBB",
			"BBBB....",
			"...BB...",
			".....BB.",
		],
		[
			"..BBBB..",
			"BBBB..B.",
			"BBBB...B",
			"BBBS....",
			"BBBB...B",
			"BBBB..B.",
			"..BBBB..",
		],
	]

	var speed := 1.0
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var reach := 0.0
	var grip := 0.0
	var _clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock += delta * speed
		queue_redraw()

	func _draw() -> void:
		if reach <= 0.0:
			return
		var tip := a.lerp(b, reach)
		var way := tip - a
		var length := way.length()
		if length < 1.0:
			return
		var side := way.orthogonal() / length
		var cells := {}  # cell -> light
		var steps := int(length / 2.0)
		var points: Array[Vector2] = []
		for i in steps + 1:
			var s := float(i) / steps
			var p := a + way * s + side * sin(s * 9.0 - _clock * 10.0) * 10.0 * sin(PI * s)
			points.append(p)
			var thick := 3 if s < 0.35 else (2 if s < 0.75 else 1)
			var light := 1.0 if fposmod(s * 2.5 - _clock * 3.0, 1.0) < 0.12 else 0.0
			for ox in thick:
				for oy in thick:
					var cell := Vector2i((p / CELL).floor()) + Vector2i(ox - (thick >> 1), oy - (thick >> 1))
					cells[cell] = maxf(cells.get(cell, 0.0), light)
			# Thorns, every so often, alternating sides.
			if i % 14 == 7 and s < 0.9:
				var out := side * (1.0 if int(i / 14.0) % 2 == 0 else -1.0)
				for k in range(1, 3):
					cells[Vector2i(((p + out * CELL * (thick + k)) / CELL).floor())] = 0.0
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * CELL - Vector2(2, 2), Vector2(CELL + 4.0, CELL + 4.0)), Color(DARK, 0.8))
		for cell: Vector2i in cells:
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), DEEP.lerp(GLOW, 0.45 + 0.55 * cells[cell]))
		var facing := (points[-1] - points[maxi(points.size() - 4, 0)]).angle() if points.size() > 1 else way.angle()
		var claw: Array = CLAWS[1 if grip > 0.5 else 0]
		var middle := Vector2(0.0, claw.size() * CELL / 2.0)
		draw_set_transform(tip, facing)
		for pass_ in 2:
			for y in claw.size():
				var row: String = claw[y]
				for x in row.length():
					if row[x] == ".":
						continue
					var at := Vector2(x * CELL, y * CELL) - middle
					if pass_ == 0:
						draw_rect(Rect2(at - Vector2(1, 1), Vector2(CELL + 2.0, CELL + 2.0)), DARK)
					else:
						draw_rect(Rect2(at, Vector2(CELL, CELL)), SHADE if row[x] == "S" else BONE)
		draw_set_transform(Vector2.ZERO, 0.0)
