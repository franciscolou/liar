extends RefCounted
## Scripted scenes for rules the bot matches of simulation.gd only meet by
## luck. Every player is a puppet that answers what the scene tells it to, a
## claim is made and the state of the table is checked afterwards. It has no
## class name: preload it. Run rules_scene.tscn from the editor.

const GROGGY := &"groggy"
const MICKEY_FINN := &"bartender.mickey_finn"
const LAST_CALL := &"bartender.last_call"
const ANTIDOTE := &"doctor.antidote"
const SWINDLE := &"bard.swindle"


## Plays every scene and prints how each one went. Returns how many failed.
static func run() -> int:
	Content.ensure_loaded()
	var scenes := {
		"a mirror answers a mirror": _mirror_meets_mirror,
		"three mirrors: the last one wins": _three_mirrors,
		"a shield stops what a mirror sent back": _mirror_then_shield,
		"holding both, the shield is chosen": _choose.bind(&"shield"),
		"holding both, the mirror is chosen": _choose.bind(&"mirror"),
		"two of a kind ask nothing": _two_of_a_kind,
		"antidote after a wrong LIAR!": _antidote_after_wrong_doubt.bind(true),
		"antidote after a wrong LIAR! (human)": _antidote_after_wrong_doubt.bind(false),
		"antidote answered in the doubt window": _antidote_early,
		"antidote let through is not asked again": _antidote_declined,
		"a doll can't be doubted once pinned": _doll_stands,
		"a lie under oath costs every coin too": _oath_doubles.bind(false),
		"the truth under oath costs nothing": _oath_doubles.bind(true),
		"a spiked drink is free and adds to every price": _groggy_pays_more,
		"last call sends every copy back for a new card": _last_call,
		"a disguise repeats the last action, at its price": _disguise_repeats,
		"a swindle takes coins on their way to someone": _swindle,
		"a swindle caught lying takes nothing": _swindle_caught,
		"the first to fall loses: the blow in the air is void": _first_to_fall,
	}
	var failed := 0
	for title: String in scenes:
		var problem: String = await scenes[title].call()
		print("%s  %s%s" % ["ok    " if problem == "" else "FAILED", title, "" if problem == "" else ": " + problem])
		if problem != "":
			push_error("rules: %s: %s" % [title, problem])
			failed += 1
	return failed


# --- scenes --------------------------------------------------------------------

static func _mirror_meets_mirror() -> String:
	var table := Table.new()
	table.give(0, [&"mirror"])
	table.give(1, [&"mirror"])
	await table.spike(0, 1)
	if table.held(0) != [] or table.held(1) != []:
		return "items left: %s / %s" % [table.held(0), table.held(1)]
	return table.expect_groggy(1, 0)


static func _three_mirrors() -> String:
	var table := Table.new()
	table.give(0, [&"mirror"])
	table.give(1, [&"mirror", &"mirror"])
	await table.spike(0, 1)
	if table.held(0) != [] or table.held(1) != []:
		return "items left: %s / %s" % [table.held(0), table.held(1)]
	return table.expect_groggy(0, 1)


static func _mirror_then_shield() -> String:
	var table := Table.new()
	table.give(0, [&"shield"])
	table.give(1, [&"mirror"])
	await table.spike(0, 1)
	if table.held(0) != [] or table.held(1) != []:
		return "items left: %s / %s" % [table.held(0), table.held(1)]
	return table.expect_groggy(-1, -1)


static func _choose(wanted: StringName) -> String:
	var table := Table.new()
	table.give(1, [&"mirror", &"shield"])
	table.puppets[1].answers[Decision.Kind.PICK] = func(d: Decision) -> int:
		for i: int in d.options.size():
			if d.options[i].item.id == wanted:
				return i
		return -1
	await table.spike(0, 1)
	var picks: Array = table.asked(1, Decision.Kind.PICK)
	if picks.size() != 1 or picks[0].options.size() != 2:
		return "asked %d times" % picks.size()
	if wanted == &"shield":
		return "kept %s" % [table.held(1)] if table.held(1) != [&"mirror"] else table.expect_groggy(-1, -1)
	return "kept %s" % [table.held(1)] if table.held(1) != [&"shield"] else table.expect_groggy(0, 1)


static func _two_of_a_kind() -> String:
	var table := Table.new()
	table.give(1, [&"shield", &"shield"])
	await table.spike(0, 1)
	if not table.asked(1, Decision.Kind.PICK).is_empty():
		return "asked which shield"
	return "kept %s" % [table.held(1)] if table.held(1) != [&"shield"] else table.expect_groggy(-1, -1)


## The target calls LIAR! on a true claim, pays for it, and still gets to
## throw the status off.
static func _antidote_after_wrong_doubt(bot: bool) -> String:
	var table := Table.new(bot)
	var target: PlayerState = table.engine.players[1]
	target.cards = [&"doctor", &"judge"]
	var coins := target.coins
	table.puppets[1].answers[Decision.Kind.DOUBT] = func(_d: Decision) -> StringName: return GameEngine.STAKE_COINS
	var offers := [0]
	table.puppets[1].answers[Decision.Kind.REACT] = func(d: Decision) -> Variant:
		for option: Dictionary in d.options:
			if option.kind == &"ability" and option.ability.id == ANTIDOTE:
				offers[0] += 1
				return option
		return null
	await table.spike(0, 1)
	# The fine and nothing else: the Antidote is free, drink or no drink.
	if target.coins != coins - table.engine.config.doubt_cost:
		return "paid %d for the wrong call" % (coins - target.coins)
	if offers[0] != 1:
		return "offered the antidote %d times" % offers[0]
	return table.expect_groggy(-1, -1)


## A human target sees the Antidote next to LIAR! and takes it there.
static func _antidote_early() -> String:
	var table := Table.new(false)
	table.engine.players[1].cards = [&"doctor", &"judge"]
	var offered := [0]
	table.puppets[1].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		offered[0] = d.context.reactions.size()
		return d.context.reactions[0] if offered[0] == 1 and d.context.reactions[0].ability.id == ANTIDOTE else false
	await table.spike(0, 1)
	if offered[0] != 1:
		return "%d reactions offered with the claim" % offered[0]
	if table.asked(1, Decision.Kind.REACT).any(_offers_antidote):
		return "asked again once the status landed"
	return table.expect_groggy(-1, -1)


static func _antidote_declined() -> String:
	var table := Table.new(false)
	table.engine.players[1].cards = [&"doctor", &"judge"]
	await table.spike(0, 1)
	if table.asked(1, Decision.Kind.REACT).any(_offers_antidote):
		return "asked again after letting it pass"
	return table.expect_groggy(1, 0)


static func _doll_stands() -> String:
	var table := Table.new()
	var engine := table.engine
	engine.players[0].cards = [&"voodooist", &"judge"]
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return engine.players[1]
	await engine.claim(engine.players[0], table.ability(&"voodooist.hex"))
	if not engine.players[1].has_status(&"hexed"):
		return "no doll pinned"
	for p: PlayerState in engine.players:
		for extra: Dictionary in engine.turn_options(p).extras:
			if extra.id != &"voodooist.break":
				return "%s is offered %s" % [p.name, extra.id]
	return ""


## Under Oath anyone may still lie and anyone may still call it: a lie caught
## costs every coin on top of the Morale, and the truth is as safe as ever.
static func _oath_doubles(truthful: bool) -> String:
	var table := Table.new()
	var engine := table.engine
	var sworn: PlayerState = engine.players[0 if truthful else 1]
	var other := 1 if truthful else 0
	await engine.add_status(sworn, &"truth_bound", {"expires": &"own_turn_end", "by": 2})
	table.puppets[2].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		return d.options[0] if not d.options.is_empty() else false
	await table.spike(sworn.id, other)
	if table.asked(2, Decision.Kind.DOUBT).is_empty():
		return "nobody was offered the call"
	var lost := engine.config.start_morale - sworn.morale
	if lost != (0 if truthful else 1):
		return "the sworn player lost %d Morale" % lost
	# The drink is free: the truth leaves the 20 coins alone.
	if sworn.coins != (20 if truthful else 0):
		return "the sworn player has %d coins left" % sworn.coins
	return table.expect_groggy(other if truthful else -1, sworn.id if truthful else -1)


static func _offers_antidote(d: Decision) -> bool:
	return d.options.any(func(option: Dictionary) -> bool:
		return option.kind == &"ability" and option.ability.id == ANTIDOTE)


static func _groggy_pays_more() -> String:
	var table := Table.new()
	await table.spike(0, 1)
	if table.engine.players[0].coins != 20:
		return "the drink cost %d" % (20 - table.engine.players[0].coins)
	var engine := table.engine
	var groggy: PlayerState = engine.players[1]
	# What is free stays free.
	if engine.ability_option(groggy, table.ability(MICKEY_FINN)).cost != 0:
		return "a free ability is offered for %d" % engine.ability_option(groggy, table.ability(MICKEY_FINN)).cost
	await table.spike(1, 2)
	table.give(1, [&"potion"])
	await engine.use_item(groggy, groggy.items[0])
	if groggy.coins != 20:
		return "free things cost the groggy %d" % (20 - groggy.coins)
	# What has a price has a higher one.
	var patch_up := table.ability(&"doctor.patch_up")
	if engine.ability_option(groggy, patch_up).cost != patch_up.cost + 2:
		return "a paid ability is offered for %d" % engine.ability_option(groggy, patch_up).cost
	if engine.price(groggy, engine.config.reroll_cost) != engine.config.reroll_cost + 2:
		return "reroll for %d" % engine.price(groggy, engine.config.reroll_cost)
	if engine.price(engine.players[0], 3) != 3:
		return "the sober pay more too"
	groggy.morale = 1
	await engine.claim(groggy, patch_up)
	return "" if groggy.coins == 20 - patch_up.cost - 2 else "a paid ability left %d coins" % groggy.coins


static func _disguise_repeats() -> String:
	var table := Table.new()
	var engine := table.engine
	var disguise := table.ability(&"impostor.perfect_disguise")
	if disguise.can_use(engine.players[2], engine) == "":
		return "offered with nothing to repeat"
	await table.spike(0, 1)
	if engine.ability_option(engine.players[2], disguise).detail != table.ability(MICKEY_FINN).display_name:
		return "would repeat '%s'" % engine.ability_option(engine.players[2], disguise).detail
	table.puppets[2].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return engine.players[0]
	await engine.claim(engine.players[2], disguise)
	if not engine.players[0].has_status(GROGGY) or engine.players[0].statuses[GROGGY].get("by", -1) != 2:
		return "the drink was not repeated"
	if engine.players[2].coins != 20:
		return "a free action cost %d" % (20 - engine.players[2].coins)
	if engine.last_action != table.ability(MICKEY_FINN):
		return "the disguise became the last action"
	# A paid action costs the same through the disguise.
	var patch_up := table.ability(&"doctor.patch_up")
	engine.last_action = patch_up
	engine.players[2].morale = 1
	await engine.claim(engine.players[2], disguise)
	if engine.players[2].morale != 2:
		return "the cure was not repeated"
	return "" if engine.players[2].coins == 20 - patch_up.cost else "paid %d" % (20 - engine.players[2].coins)


static func _last_call() -> String:
	var table := Table.new()
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	var total := engine.deck.size()
	table.puppets[0].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 1
	await engine.claim(engine.players[0], table.ability(LAST_CALL))
	var recalled: Array = seen.of(&"cards_recalled")
	if recalled.size() != 1:
		return "recalled %d times" % recalled.size()
	var d: Dictionary = recalled[0].data
	if d.card != &"judge" or d.hands.size() != 5:
		return "%d copies of %s went back" % [d.hands.size(), d.card]
	if engine.deck.size() != total:
		return "deck went from %d to %d" % [total, engine.deck.size()]
	for p: PlayerState in engine.players:
		if p.cards.size() != 2:
			return "%s holds %d cards" % [p.name, p.cards.size()]
	return "" if engine.players[0].cards[0] == &"bartender" else "the other card changed"


## Any coins on their way to someone else, but not the income of a turn and
## not what a Swindle already took.
static func _swindle() -> String:
	var table := Table.new(true, [&"bard"])
	var engine := table.engine
	var bard: PlayerState = engine.players[0]
	bard.cards = [&"bard", &"judge"]
	table.puppets[0].answers[Decision.Kind.REACT] = _swindles
	await engine.gain_coins(engine.players[1], 1, &"income")
	if not table.asked(0, Decision.Kind.REACT).is_empty():
		return "offered against the income of a turn"
	await engine.gain_coins(engine.players[1], 4, &"bounty")
	if bard.coins != 24 or engine.players[1].coins != 21:
		return "coins: %d / %d" % [bard.coins, engine.players[1].coins]
	for d: Decision in table.asked(1, Decision.Kind.REACT) + table.asked(2, Decision.Kind.REACT):
		if d.context.event.data.reason == &"swindle":
			return "the haul was offered to %s" % d.player.name
	await engine.gain_coins(bard, 4, &"bounty")
	return "" if bard.coins == 28 else "the Bard swindled their own coins"


static func _swindle_caught() -> String:
	var table := Table.new(true, [&"bard"])
	var engine := table.engine
	table.puppets[2].answers[Decision.Kind.REACT] = _swindles
	table.puppets[1].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		return d.options[0] if not d.options.is_empty() else false
	await engine.gain_coins(engine.players[1], 4, &"bounty")
	if engine.players[2].morale != engine.config.start_morale - 1:
		return "the liar kept their Morale"
	if engine.players[1].coins != 24 or engine.players[2].coins != 20:
		return "coins: %d / %d" % [engine.players[1].coins, engine.players[2].coins]
	return ""


## Two left, 1 Morale each. One is hit and bargains it away; the attacker
## calls LIAR! with Morale, is wrong and falls. The match is over there: the
## hit that was still to land takes nothing.
static func _first_to_fall() -> String:
	var table := Table.new(true, [&"vagabond"])
	var engine := table.engine
	var attacker: PlayerState = engine.players[0]
	var target: PlayerState = engine.players[1]
	engine.players[2].alive = false
	attacker.morale = 1
	attacker.coins = 0
	target.morale = 1
	target.cards = [&"vagabond"]
	table.puppets[1].answers[Decision.Kind.REACT] = func(d: Decision) -> Variant:
		for option: Dictionary in d.options:
			if option.kind == &"ability" and option.ability.id == &"vagabond.street_bargain":
				return option
		return null
	table.puppets[0].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		return GameEngine.STAKE_MORALE if d.options.has(GameEngine.STAKE_MORALE) else false
	await engine.deal_damage(attacker, target)
	if attacker.alive:
		return "the wrong call cost nothing"
	if not target.alive or target.morale != 1:
		return "the winner fell too (Morale %d)" % target.morale
	return "" if engine.winner == target else "no winner"


static func _swindles(d: Decision) -> Variant:
	for option: Dictionary in d.options:
		if option.kind == &"ability" and option.ability.id == SWINDLE:
			return option
	return null


# --- the stage ------------------------------------------------------------------

## Three players with coins to spare. Player 0 holds the Bartender.
class Table extends RefCounted:
	var engine: GameEngine
	var puppets: Array = []

	## `bots`: false seats player 1 as a human, who is asked first in a doubt
	## window and may answer it with a reaction. `cast`: characters on top of
	## the usual ones.
	func _init(bots := true, cast: Array = []) -> void:
		var config := GameConfig.new()
		for i in 3:
			config.seats.append({"name": "P%d" % i, "bot": bots or i != 1})
		config.character_ids = [&"bartender", &"doctor", &"voodooist", &"judge", &"impostor"]
		config.character_ids.append_array(cast)
		config.rng_seed = 7
		engine = GameEngine.new()
		engine.setup(config)
		for p: PlayerState in engine.players:
			var puppet := Puppet.new()
			puppet.engine = engine
			puppet.player = p
			engine.controllers[p.id] = puppet
			puppets.append(puppet)
			p.cards = [&"judge", &"judge"]
			p.coins = 20
		engine.players[0].cards = [&"bartender", &"judge"]

	func give(index: int, items: Array) -> void:
		for id: StringName in items:
			engine.players[index].items.append(ItemInstance.new(Content.items[id]))

	func held(index: int) -> Array:
		return engine.players[index].items.map(func(instance: ItemInstance) -> StringName: return instance.def.id)

	func ability(id: StringName) -> Ability:
		for def: CharacterDef in engine.characters:
			for found: Ability in def.abilities:
				if found.id == id:
					return found
		return null

	## Every decision of `kind` player `index` was asked for.
	func asked(index: int, kind: Decision.Kind) -> Array:
		return puppets[index].seen.filter(func(d: Decision) -> bool: return d.kind == kind)

	## Player `from` claims Mickey Finn on player `to`.
	func spike(from: int, to: int) -> void:
		puppets[from].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return engine.players[to]
		await engine.claim(engine.players[from], ability(MICKEY_FINN))

	## "" if `who` is the only one left groggy, spiked by `by` (-1: nobody is).
	func expect_groggy(who: int, by: int) -> String:
		for p: PlayerState in engine.players:
			if p.has_status(GROGGY) != (p.id == who):
				return "%s %s groggy" % [p.name, "is" if p.has_status(GROGGY) else "is not"]
		if who >= 0 and engine.players[who].statuses[GROGGY].get("by", -1) != by:
			return "spiked by %d" % engine.players[who].statuses[GROGGY].get("by", -1)
		return ""


## Keeps every event the table was shown.
class Witness extends RefCounted:
	var events: Array = []

	func present(event: GameEvent) -> void:
		events.append(event)

	func of(type: StringName) -> Array:
		return events.filter(func(event: GameEvent) -> bool: return event.type == type)


## Answers what the scene set for each kind of decision, and nothing (let it
## pass, no pick) for the rest. Keeps every decision it was asked.
class Puppet extends Controller:
	var answers: Dictionary = {}  # Decision.Kind -> Callable(Decision)
	var seen: Array = []

	func decide(d: Decision) -> Variant:
		seen.append(d)
		if answers.has(d.kind):
			return answers[d.kind].call(d)
		match d.kind:
			Decision.Kind.DOUBT:
				return false
			Decision.Kind.PICK:
				return -1
		return null
