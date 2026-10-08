extends RefCounted
## Scripted scenes for rules the bot matches of simulation.gd only meet by
## luck. Every player is a puppet that answers what the scene tells it to, a
## claim is made and the state of the table is checked afterwards. It has no
## class name: preload it. Run rules_scene.tscn from the editor.

const GROGGY := &"groggy"
const MICKEY_FINN := &"bartender.mickey_finn"
const ANTIDOTE := &"doctor.antidote"


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
		"nobody calls LIAR! on a claim under oath": _oath_stands,
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


## A claim made Under Oath can only be true: nobody is offered the call, but
## whoever can answer the claim with a reaction is still asked about that.
static func _oath_stands() -> String:
	var table := Table.new(false)
	var engine := table.engine
	engine.players[1].cards = [&"doctor", &"judge"]
	await engine.add_status(engine.players[0], &"truth_bound", {"expires": &"own_turn_end", "by": 2})
	await table.spike(0, 1)
	var doubts: Array = table.asked(1, Decision.Kind.DOUBT)
	if doubts.size() != 1 or doubts[0].context.reactions.size() != 1:
		return "the target was asked %d times" % doubts.size()
	if not doubts[0].options.is_empty():
		return "the target may stake %s" % [doubts[0].options]
	if not table.asked(2, Decision.Kind.DOUBT).is_empty():
		return "a bystander was asked"
	return table.expect_groggy(1, 0)


static func _offers_antidote(d: Decision) -> bool:
	return d.options.any(func(option: Dictionary) -> bool:
		return option.kind == &"ability" and option.ability.id == ANTIDOTE)


# --- the stage ------------------------------------------------------------------

## Three players with coins to spare. Player 0 holds the Bartender.
class Table extends RefCounted:
	var engine: GameEngine
	var puppets: Array = []

	## `bots`: false seats player 1 as a human, who is asked first in a doubt
	## window and may answer it with a reaction.
	func _init(bots := true) -> void:
		var config := GameConfig.new()
		for i in 3:
			config.seats.append({"name": "P%d" % i, "bot": bots or i != 1})
		config.character_ids = [&"bartender", &"doctor", &"voodooist", &"judge"]
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
