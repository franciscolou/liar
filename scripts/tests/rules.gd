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
		"a silver tongue keeps the coins from a swindle": _swindle_talked_down,
		"the first to fall loses: the blow in the air is void": _first_to_fall,
		"a demolition goes past shield and mirror": _demolition,
		"a shield stops a time bomb as it is planted": _time_bomb.bind(&"shield"),
		"a mirror sends a time bomb back as it is planted": _time_bomb.bind(&"mirror"),
		"a ticking bomb goes past shield and mirror": _time_bomb.bind(&""),
		"a shakedown takes 3 coins from one player": _shakedown.bind(&"", 3),
		"a shakedown takes no more than there is": _shakedown.bind(&"broke", 2),
		"a shield stops a shakedown": _shakedown.bind(&"shield", 0),
		"a mirror turns a shakedown round": _shakedown.bind(&"mirror", -3),
		"a silver tongue keeps the coins from a shakedown": _shakedown.bind(&"bard", 0),
		"entropy breaks into 1 Morale and 3 coins": _entropy.bind(2, 1, 3),
		"entropy at full Morale breaks into 5 coins": _entropy.bind(3, 0, 5),
		"entropy takes the whole turn": _entropy_whole_turn,
		"entropy is thrown away by a LIAR! call": _entropy_wasted.bind(true),
		"entropy survives a claim let pass": _entropy_wasted.bind(false),
		"a Morale becomes an item, and the change": _materialize.bind(&"shield", 1),
		"a dearer item is paid for on top of the Morale": _materialize.bind(&"potion", -4),
		"the last Morale is not for sale": _materialize_last,
		"an untraceable hand can't be peeked at": _untraceable.bind(&"peek"),
		"an untraceable hand can't be swapped": _untraceable.bind(&"swap"),
		"an untraceable hand keeps its copy through a last call": _untraceable.bind(&"recall"),
		"nobody is untraceable from themselves": _untraceable_own,
		"an item thrown away costs nothing and takes no turn": _discard,
		"two swindles: the human is heard before the bot": _swindle_race.bind(false),
		"two swindles: only one of them takes the coins": _swindle_race.bind(true),
		"a claim is paid for as it is announced; a liar caught gets it back": _paid_up_front.bind(false),
		"a claim paid for up front stays paid when it is true": _paid_up_front.bind(true),
		"soul swap: the user says which card they hand over": _soul_swap.bind(false),
		"soul swap off a mirror: the holder says which card they hand over": _soul_swap.bind(true),
		"untraceable items can't be seized": _untraceable_items.bind(&"sheriff.confiscate"),
		"untraceable items can't be blown up": _untraceable_items.bind(&"bomber.demolition"),
		"side bets are placed at once and claimed after": _side_bets.bind(true),
		"nobody bets on the doubt of a side bet": _side_bets.bind(false),
		"a party: ten free rerolls, and the turn goes on": _party,
		"a spy looks at the card they choose": _peek_chosen,
		"last call for a card the caller doesn't hold": _last_call_named,
		"a bluffed sold out names its card before the claim": _shed_named_first,
		"a number of the hand-picked characters is drawn": _cast_drawn,
		"a bluffed street bargain warns of the two Morale": _bargain_caution,
		"backing out of a bluffed swindle goes back to the question": _swindle_backed_out,
		"a proven card the ability already traded is not traded twice": _proven_shed_once,
		"a choice made before the announcement is private, one made after is not": _private_choices,
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


## The Bomber blows up one item of a player who holds a shield and a mirror:
## neither answers, and both are still there afterwards.
static func _demolition() -> String:
	var table := Table.new(true, [&"bomber"])
	table.engine.players[0].cards = [&"bomber", &"judge"]
	table.give(1, [&"shield", &"mirror", &"potion"])
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return table.engine.players[1]
	table.puppets[0].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 2
	var coins: int = table.engine.players[0].coins
	await table.engine.claim(table.engine.players[0], table.ability(&"bomber.demolition"))
	if not table.asked(1, Decision.Kind.PICK).is_empty():
		return "the target was asked how to defend"
	if table.engine.players[0].coins != coins:
		return "it cost %d coins" % (coins - table.engine.players[0].coins)
	return "" if table.held(1) == [&"shield", &"mirror"] else "kept %s" % [table.held(1)]


## Player 0 plants a Time Bomb on player 1, who holds `defence` when it is
## planted: it answers there and then. Whoever ends up carrying the bomb gets
## a shield and a mirror only once it ticks, and neither stops the blast.
static func _time_bomb(defence: StringName) -> String:
	var table := Table.new(true, [&"bomber"])
	var engine := table.engine
	var bomber: PlayerState = engine.players[0]
	var victim: PlayerState = engine.players[1]
	bomber.cards = [&"bomber", &"judge"]
	if defence != &"":
		table.give(1, [defence])
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return victim
	await engine.claim(bomber, table.ability(&"bomber.time_bomb"))
	if table.held(1) != []:
		return "kept %s" % [table.held(1)]
	var carrier: PlayerState = bomber if defence == &"mirror" else victim
	for p: PlayerState in [bomber, victim]:
		if p.has_status(&"ticking") != (p == carrier and defence != &"shield"):
			return "%s %s a bomb" % [p.name, "carries" if p.has_status(&"ticking") else "carries no"]
	if defence == &"shield":
		return ""
	var seat := engine.players.find(carrier)
	table.give(seat, [&"shield", &"mirror"])
	var morale := carrier.morale
	engine.turn_count += 1
	await engine.fire(&"turn_ended", {"player": carrier})
	if carrier.has_status(&"ticking"):
		return "still ticking"
	if table.held(seat) != [&"shield", &"mirror"]:
		return "kept %s" % [table.held(seat)]
	return "" if carrier.morale == morale - 1 else "Morale went from %d to %d" % [morale, carrier.morale]


## Player 0, on `morale`, claims Entropy and then starts a turn: `healed` and
## `coins` are what the chains should break into.
static func _entropy(morale: int, healed: int, coins: int) -> String:
	var table := Table.new(true, [&"entity"])
	var engine := table.engine
	var p: PlayerState = engine.players[0]
	p.cards = [&"entity", &"judge"]
	p.morale = morale
	p.cards.resize(engine.hand_limit(p))
	await engine.claim(p, table.ability(&"entity.entropy"))
	if not p.has_status(&"entropy"):
		return "no chains"
	if p.morale != morale or p.coins != 20:
		return "paid at once: %d Morale, %d coins" % [p.morale, p.coins]
	await engine.fire(&"turn_started", {"player": p})
	if p.has_status(&"entropy"):
		return "still in chains"
	if p.morale != morale + healed:
		return "%d Morale" % p.morale
	return "" if p.coins == 20 + coins else "gained %d coins" % (p.coins - 20)


static func _entropy_whole_turn() -> String:
	var table := Table.new(true, [&"entity"])
	var engine := table.engine
	var entropy := table.ability(&"entity.entropy")
	if engine.claim_block_reason(engine.players[0], entropy) != "":
		return "not offered on a fresh turn"
	engine.players[0].turn["busy"] = true
	return "" if engine.claim_block_reason(engine.players[0], entropy) != "" else "offered after something else"


## Player 0 is in chains when player 1 bluffs a Mickey Finn. If they `call`
## it, the chains go at once and the next turn pays nothing, right as the
## call was; if they let it pass, the chains pay as ever.
static func _entropy_wasted(call: bool) -> String:
	var table := Table.new(true, [&"entity"])
	var engine := table.engine
	var p: PlayerState = engine.players[0]
	p.morale = 2
	await engine.add_status(p, &"entropy", {"by": p.id})
	if call:
		table.puppets[0].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
			return d.options[0] if not d.options.is_empty() else false
	await table.spike(1, 2)
	if table.asked(0, Decision.Kind.DOUBT).is_empty():
		return "never offered the call"
	if p.has_status(&"entropy") == call:
		return "the chains are gone" if not call else "still in chains"
	if call and engine.players[1].morale != engine.config.start_morale - 1:
		return "the liar was not caught"
	await engine.fire(&"turn_started", {"player": p})
	# Either way 3 coins: what a right call pays, or what the chains do.
	var paid := "%d Morale, %d coins" % [p.morale - 2, p.coins - 20]
	return "" if paid == ("0 Morale, 3 coins" if call else "1 Morale, 3 coins") else "paid " + paid


## Player 0 turns a Morale into `item`: `coins` is what that does to their
## purse. The item is theirs at once, but not to be used in that turn.
static func _materialize(item: StringName, coins: int) -> String:
	var table := Table.new(true, [&"entity"])
	var engine := table.engine
	var p: PlayerState = engine.players[0]
	p.cards = [&"entity", &"judge"]
	engine.turn_count = 1
	table.puppets[0].answers[Decision.Kind.PICK] = func(d: Decision) -> int:
		for i: int in d.options.size():
			if d.options[i].has("item") and d.options[i].item.id == item:
				return i
		return -1
	await engine.claim(p, table.ability(&"entity.materialize"))
	if p.morale != 2 or table.held(0) != [item]:
		return "%d Morale, holding %s" % [p.morale, table.held(0)]
	if p.coins != 20 + coins:
		return "purse went by %d" % (p.coins - 20)
	var use: Dictionary = engine.turn_options(p).use[0]
	if Content.items[item].kind == ItemDef.Kind.ACTIVE and use.enabled:
		return "usable in the turn it was made"
	engine.turn_count = 2
	use = engine.turn_options(p).use[0]
	if Content.items[item].kind == ItemDef.Kind.ACTIVE and not use.enabled:
		return "still sealed a turn later: %s" % use.reason
	return ""


static func _materialize_last() -> String:
	var table := Table.new(true, [&"entity"])
	var engine := table.engine
	var p: PlayerState = engine.players[0]
	p.morale = 1
	p.cards = [&"entity"]
	if table.ability(&"entity.materialize").can_use(p, engine) == "":
		return "offered on the last Morale"
	await engine.claim(p, table.ability(&"entity.materialize"))
	return "" if p.morale == 1 and table.held(0) == [] else "%d Morale, holding %s" % [p.morale, table.held(0)]


## Player 0 shakes player 1 down. `defence` is what player 1 has against it
## (an item, the Bard, or only 2 coins: "broke") and `haul` how many coins
## should end up changing hands (negative: the other way).
static func _shakedown(defence: StringName, haul: int) -> String:
	var table := Table.new(true, [&"sheriff", &"bard"])
	var engine := table.engine
	var sheriff: PlayerState = engine.players[0]
	var target: PlayerState = engine.players[1]
	sheriff.cards = [&"sheriff", &"judge"]
	match defence:
		&"broke":
			target.coins = 2
		&"bard":
			target.cards = [&"bard", &"judge"]
			table.puppets[1].answers[Decision.Kind.REACT] = func(d: Decision) -> Variant:
				for option: Dictionary in d.options:
					if option.kind == &"ability" and option.ability.id == &"bard.silver_tongue":
						return option
				return null
		&"shield", &"mirror":
			table.give(1, [defence])
	var before: Array = [sheriff.coins, target.coins]
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return target
	await engine.claim(sheriff, table.ability(&"sheriff.shakedown"))
	if sheriff.coins != before[0] + haul or target.coins != before[1] - haul:
		return "coins: %d / %d" % [sheriff.coins, target.coins]
	if engine.players[2].coins != 20:
		return "the third player was touched"
	return "" if table.held(1) == [] else "kept %s" % [table.held(1)]


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
	if groggy.coins != 20 - patch_up.cost - 2:
		return "a paid ability left %d coins" % groggy.coins
	# Paid for once, the drink is slept off: the next price is the plain one.
	if groggy.has_status(GROGGY):
		return "still groggy after paying"
	return "" if engine.price(groggy, 3) == 3 else "still paying more"


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
	table.puppets[0].answers[Decision.Kind.PICK] = _names.bind(&"judge")
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
	var seen := Witness.new()
	engine.observers.append(seen)
	await engine.gain_coins(engine.players[1], 4, &"bounty")
	if bard.coins != 24 or engine.players[1].coins != 21:
		return "coins: %d / %d" % [bard.coins, engine.players[1].coins]
	# The trick is good once: the card went back for another.
	var traded: Array = seen.of(&"cards_changed")
	if traded.size() != 1 or traded[0].data.old != &"bard" or bard.cards[1] != &"judge":
		return "the Bard was not traded away"
	bard.cards = [&"bard", &"judge"]
	for d: Decision in table.asked(1, Decision.Kind.REACT) + table.asked(2, Decision.Kind.REACT):
		if d.context.event.data.get("reason") == &"swindle":
			return "the haul was offered to %s" % d.player.name
	await engine.gain_coins(bard, 4, &"bounty")
	return "" if bard.coins == 28 else "the Bard swindled their own coins"


## The one the coins were going to holds a Bard too: the Swindle is announced
## and takes nothing.
static func _swindle_talked_down() -> String:
	var table := Table.new(true, [&"bard"])
	var engine := table.engine
	var bard: PlayerState = engine.players[0]
	var target: PlayerState = engine.players[1]
	bard.cards = [&"bard", &"judge"]
	target.cards = [&"bard", &"judge"]
	table.puppets[0].answers[Decision.Kind.REACT] = _swindles
	table.puppets[1].answers[Decision.Kind.REACT] = func(d: Decision) -> Variant:
		for option: Dictionary in d.options:
			if option.kind == &"ability" and option.ability.id == &"bard.silver_tongue":
				return option
		return null
	var seen := Witness.new()
	engine.observers.append(seen)
	await engine.gain_coins(target, 4, &"bounty")
	if bard.coins != 20 or target.coins != 24:
		return "coins: %d / %d" % [bard.coins, target.coins]
	# It came to nothing: the Bard stays in the hand.
	return "" if seen.of(&"cards_changed").is_empty() and bard.cards == [&"bard", &"judge"] else "the Bard was traded away"


static func _swindle_caught() -> String:
	var table := Table.new(true, [&"bard"])
	var engine := table.engine
	# Once: not again for the coins the right call pays.
	table.puppets[2].answers[Decision.Kind.REACT] = func(d: Decision) -> Variant:
		return _swindles(d) if d.context.event.data.get("reason") == &"bounty" else null
	# A bluffer names the card that would go before announcing anything.
	table.puppets[2].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 0
	table.puppets[1].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		return d.options[0] if not d.options.is_empty() else false
	await engine.gain_coins(engine.players[1], 4, &"bounty")
	if engine.players[2].morale != engine.config.start_morale - 1:
		return "the liar kept their Morale"
	# The bounty, and the 3 coins of the right call.
	if engine.players[1].coins != 27 or engine.players[2].coins != 20:
		return "coins: %d / %d" % [engine.players[1].coins, engine.players[2].coins]
	return "" if engine.players[2].cards == [&"judge", &"judge"] else "the liar's hand changed"


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


## Player 1 answers whatever comes for their hand with an Untraceable: the
## peek, the swap or the recall misses them, and only them.
static func _untraceable(how: StringName) -> String:
	var table := Table.new(true, [&"spy"])
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	var spy: PlayerState = engine.players[1]
	spy.cards = [&"spy", &"judge"]
	table.puppets[1].answers[Decision.Kind.REACT] = _vanishes
	match how:
		&"peek":
			table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return spy
			await engine.claim(engine.players[0], table.ability(&"spy.sneak_peek"))
			if not seen.of(&"card_peeked").is_empty():
				return "the card was seen"
		&"swap":
			await engine.swap_cards(engine.players[0], 0, spy, 0)
			if not seen.of(&"cards_swapped").is_empty() or engine.players[0].cards[0] != &"bartender":
				return "the cards changed hands"
		&"recall":
			table.puppets[0].answers[Decision.Kind.PICK] = _names.bind(&"judge")
			await engine.claim(engine.players[0], table.ability(LAST_CALL))
			var recalled: Array = seen.of(&"cards_recalled")
			if recalled.size() != 1 or recalled[0].data.hands.size() != 3:
				return "the wrong hands were recalled"
	if spy.cards != [&"spy", &"judge"]:
		return "the hand became %s" % [spy.cards]
	var missed: Array = seen.of(&"hand_missed")
	if missed.size() != 1 or missed[0].data.owner != spy or missed[0].data.how != how:
		return "missed %d times" % missed.size()
	return ""


## Their own Soul Swap and their own Last Call still go through their hand.
static func _untraceable_own() -> String:
	var table := Table.new(true, [&"spy"])
	var engine := table.engine
	var spy: PlayerState = engine.players[1]
	spy.cards = [&"spy", &"judge"]
	table.puppets[1].answers[Decision.Kind.REACT] = _vanishes
	await engine.swap_cards(spy, 0, engine.players[0], 0)
	if spy.cards[0] != &"bartender":
		return "their own swap missed"
	return "" if table.asked(1, Decision.Kind.REACT).is_empty() else "asked about their own swap"


## Player 0 throws one of two items away: any of them may go, the purse stays
## as it was and the turn is as fresh as before (Entropy is still on offer).
static func _discard() -> String:
	var table := Table.new(true, [&"entity"])
	var engine := table.engine
	var p: PlayerState = engine.players[0]
	table.give(0, [&"shield", &"potion"])
	var offered: Array = engine.turn_options(p).discard
	if offered.size() != 2 or not offered.all(func(option: Dictionary) -> bool: return option.enabled):
		return "%d items offered to be thrown away" % offered.size()
	var seen := Witness.new()
	engine.observers.append(seen)
	await engine.discard_item(p, offered[0].item)
	if table.held(0) != [&"potion"]:
		return "kept %s" % [table.held(0)]
	if p.coins != 20:
		return "purse went by %d" % (p.coins - 20)
	if seen.of(&"item_discarded").size() != 1 or seen.of(&"item_discarded")[0].data.index != 0:
		return "the table was not told"
	return "" if engine.claim_block_reason(p, table.ability(&"entity.entropy")) == "" else "it took up the turn"


## Players 0 and 1 both swindle the coins on their way to player 2: one of
## them gets all of it. With player 1 a human, it is theirs, whatever the
## seats say; between `bots` it is either's, and only one's.
static func _swindle_race(bots: bool) -> String:
	var table := Table.new(bots, [&"bard"])
	var engine := table.engine
	for i: int in 2:
		engine.players[i].cards = [&"bard", &"judge"]
		table.puppets[i].answers[Decision.Kind.REACT] = _swindles
	await engine.gain_coins(engine.players[2], 4, &"bounty")
	var hauls: Array = [engine.players[0].coins - 20, engine.players[1].coins - 20]
	if engine.players[2].coins != 20:
		return "the coins still got there"
	if bots:
		return "" if hauls == [4, 0] or hauls == [0, 4] else "hauls: %s" % [hauls]
	return "" if hauls == [0, 4] else "hauls: %s" % [hauls]


## The option of a card pick that shows `card`, -1 if there is none.
static func _names(d: Decision, card: StringName) -> int:
	for i: int in d.options.size():
		if d.options[i].get("card") == card:
			return i
	return -1


## Player 1 claims a Time Bomb on player 0, holding the Bomber or not, and
## player 2 calls LIAR!. The 3 coins are gone by the time anyone is asked;
## a liar gets them back with the Morale they lose, and the right call pays.
static func _paid_up_front(truthful: bool) -> String:
	var table := Table.new(true, [&"bomber"])
	var engine := table.engine
	var actor: PlayerState = engine.players[1]
	if truthful:
		actor.cards = [&"bomber", &"judge"]
	var purse := [-1]
	table.puppets[1].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return engine.players[0]
	table.puppets[2].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		purse[0] = actor.coins
		return d.options[0] if not d.options.is_empty() else false
	await engine.claim(actor, table.ability(&"bomber.time_bomb"))
	if purse[0] != 17:
		return "%d coins while the claim was open" % purse[0]
	var doubter: PlayerState = engine.players[2]
	if truthful:
		if actor.coins != 17 or doubter.coins != 20 - engine.config.doubt_cost:
			return "coins: %d / %d" % [actor.coins, doubter.coins]
		return "" if engine.players[0].has_status(&"ticking") else "no bomb planted"
	if actor.coins != 20 or actor.morale != engine.config.start_morale - 1:
		return "the liar has %d coins and %d Morale" % [actor.coins, actor.morale]
	return "" if doubter.coins == 20 + engine.config.doubt_reward else "the right call paid %d" % (doubter.coins - 20)


## Player 0 uses a Soul Swap on player 1. Whoever ends up trading (player 1,
## off a `mirror`) hands over the second card of their hand, by choice.
static func _soul_swap(mirror: bool) -> String:
	var table := Table.new()
	var engine := table.engine
	var user: PlayerState = engine.players[0]
	var target: PlayerState = engine.players[1]
	user.cards = [&"bartender", &"impostor"]
	target.cards = [&"doctor", &"voodooist"]
	table.give(0, [&"soul_swap"])
	if mirror:
		table.give(1, [&"mirror"])
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return target
	for i: int in 2:
		table.puppets[i].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 1
	await engine.use_item(user, user.items[0])
	var chooser := 1 if mirror else 0
	if table.asked(chooser, Decision.Kind.PICK).size() != 1 or not table.asked(1 - chooser, Decision.Kind.PICK).is_empty():
		return "the wrong player chose"
	var given: StringName = &"voodooist" if mirror else &"impostor"
	var taker: PlayerState = user if mirror else target
	if not taker.cards.has(given):
		return "%s did not change hands: %s / %s" % [given, user.cards, target.cards]
	return "" if user.cards.size() == 2 and target.cards.size() == 2 else "a hand lost a card"


## Player 0 comes for the one item of player 1, who answers with an
## Untraceable: it stays where it is.
static func _untraceable_items(with: StringName) -> String:
	var table := Table.new(true, [&"spy", &"sheriff", &"bomber"])
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	var spy: PlayerState = engine.players[1]
	spy.cards = [&"spy", &"judge"]
	table.give(1, [&"potion"])
	engine.players[0].cards = [&"sheriff", &"bomber"]
	table.puppets[1].answers[Decision.Kind.REACT] = _vanishes
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return spy
	await engine.claim(engine.players[0], table.ability(with))
	if table.held(1) != [&"potion"] or table.held(0) != []:
		return "items: %s / %s" % [table.held(0), table.held(1)]
	var missed: Array = seen.of(&"items_missed")
	return "" if missed.size() == 1 and missed[0].data.owner == spy else "missed %d times" % missed.size()


## Player 0 spikes player 1, who calls LIAR! and is wrong. Player 2 is asked
## for a side bet in the round of bets, with the side already in the answer.
## `honest`: they hold the Gambler and collect. Otherwise player 0 calls
## LIAR! on the bet itself, and nobody is asked to bet on that.
static func _side_bets(honest: bool) -> String:
	var table := Table.new(true, [&"gambler"])
	var engine := table.engine
	var bettor: PlayerState = engine.players[2]
	if honest:
		bettor.cards = [&"gambler", &"judge"]
	var spiked := table.ability(MICKEY_FINN)
	table.puppets[1].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		return d.options[0] if d.context.play.source == spiked and not d.options.is_empty() else false
	if not honest:
		table.puppets[0].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
			return d.options[0] if not d.options.is_empty() else false
	# The truth: the second of the two sides.
	table.puppets[2].answers[Decision.Kind.PICK] = func(d: Decision) -> int:
		return 1 if d.context.get("look") == &"side_bet" else -1
	await table.spike(0, 1)
	var rounds := 0
	for i: int in 3:
		for d: Decision in table.asked(i, Decision.Kind.PICK):
			if d.context.get("look") == &"side_bet":
				rounds += 1
				if i != 2 or not d.context.has("seconds"):
					return "player %d was asked to bet" % i
	if rounds != 1:
		return "%d rounds of bets" % rounds
	if honest:
		return "" if bettor.coins == 20 - 2 + 6 else "the bet left %d coins" % bettor.coins
	# Caught: the stake comes back, the Morale goes, and there was no bet.
	if bettor.coins != 20 or bettor.morale != engine.config.start_morale - 1:
		return "the liar has %d coins and %d Morale" % [bettor.coins, bettor.morale]
	return table.expect_groggy(1, 0)


static func _party() -> String:
	var table := Table.new(true, [&"heir"])
	var engine := table.engine
	var heir: PlayerState = engine.players[0]
	heir.cards = [&"heir", &"judge"]
	var party := table.ability(&"heir.party")
	if party.ends_turn:
		return "it ends the turn"
	if engine.turn_options(heir).reroll.cost != engine.config.reroll_cost:
		return "the reroll was free before the party"
	await engine.claim(heir, party)
	var reroll: Dictionary = engine.turn_options(heir).reroll
	if reroll.cost != 0 or reroll.free != 10:
		return "reroll for %d, %d free" % [reroll.cost, reroll.free]
	await engine.reroll_shop(heir)
	if heir.coins != 20 or engine.free_rerolls(heir) != 9:
		return "%d coins, %d rerolls left" % [heir.coins, engine.free_rerolls(heir)]
	return "" if engine.claim_block_reason(heir, party) != "" else "offered twice in a turn"


static func _peek_chosen() -> String:
	var table := Table.new(true, [&"spy"])
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	engine.players[0].cards = [&"spy", &"judge"]
	engine.players[1].cards = [&"doctor", &"voodooist"]
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return engine.players[1]
	table.puppets[0].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 1
	await engine.claim(engine.players[0], table.ability(&"spy.sneak_peek"))
	var picks: Array = table.asked(0, Decision.Kind.PICK)
	if picks.size() != 1 or picks[0].context.get("hand_of") != engine.players[1] or picks[0].options.size() != 2:
		return "asked %d times" % picks.size()
	var peeked: Array = seen.of(&"card_peeked")
	return "" if peeked.size() == 1 and peeked[0].data.card == &"voodooist" else "the wrong card was seen"


static func _last_call_named() -> String:
	var table := Table.new()
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	engine.players[1].cards = [&"doctor", &"judge"]
	table.puppets[0].answers[Decision.Kind.PICK] = _names.bind(&"doctor")
	await engine.claim(engine.players[0], table.ability(LAST_CALL))
	var recalled: Array = seen.of(&"cards_recalled")
	if recalled.size() != 1 or recalled[0].data.card != &"doctor" or recalled[0].data.hands.size() != 1:
		return "the wrong cards were recalled"
	if engine.players[0].cards != [&"bartender", &"judge"]:
		return "the caller's hand became %s" % [engine.players[0].cards]
	return "" if engine.players[1].cards[1] == &"judge" and engine.players[1].cards.size() == 2 else "the wrong card went"


## Player 1 bluffs a Sold Out: the card that goes is asked for before the
## table hears of the claim, and it is the one that goes.
static func _shed_named_first() -> String:
	var table := Table.new(true, [&"heir"])
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	var liar: PlayerState = engine.players[1]
	liar.cards = [&"judge", &"voodooist"]
	var early := [false]
	table.puppets[1].answers[Decision.Kind.PICK] = func(_d: Decision) -> int:
		early[0] = seen.of(&"claim_declared").is_empty()
		return 1
	await engine.claim(liar, table.ability(&"heir.sold_out"))
	if not early[0] or table.asked(1, Decision.Kind.PICK).size() != 1:
		return "the card was asked for after the claim"
	var traded: Array = seen.of(&"cards_changed")
	if traded.size() != 1 or traded[0].data.old != &"voodooist" or liar.cards[0] != &"judge":
		return "the wrong card went"
	return "" if liar.coins == 24 else "%d coins" % liar.coins


static func _cast_drawn() -> String:
	var config := GameConfig.new()
	for i in 3:
		config.seats.append({"name": "P%d" % i, "bot": true})
	var pool: Array = [&"bartender", &"doctor", &"voodooist", &"judge", &"impostor", &"spy"]
	config.character_ids = pool.duplicate()
	config.pool_draw = 3
	config.rng_seed = 11
	var engine := GameEngine.new()
	engine.setup(config)
	if engine.characters.size() != 3:
		return "%d characters in the match" % engine.characters.size()
	for def: CharacterDef in engine.characters:
		if not pool.has(def.id):
			return "%s was not among the chosen" % def.id
	config.pool_draw = 0
	engine = GameEngine.new()
	engine.setup(config)
	return "" if engine.characters.size() == pool.size() else "not all of the chosen are in"


## Player 1, a human, bluffs a Swindle and then cancels the choice of the
## card that would go: nothing is announced and they are asked again, where
## they may still swindle (or pass).
static func _swindle_backed_out() -> String:
	var table := Table.new(false, [&"bard"])
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	var picks := [0]
	table.puppets[1].answers[Decision.Kind.REACT] = _swindles
	table.puppets[1].answers[Decision.Kind.PICK] = func(_d: Decision) -> int:
		picks[0] += 1
		return -1 if picks[0] == 1 else 0
	await engine.gain_coins(engine.players[2], 4, &"bounty")
	if table.asked(1, Decision.Kind.REACT).size() != 2:
		return "asked to react %d times" % table.asked(1, Decision.Kind.REACT).size()
	if seen.of(&"claim_declared").size() != 1:
		return "%d claims announced" % seen.of(&"claim_declared").size()
	return "" if engine.players[1].coins == 24 and engine.players[2].coins == 20 else "coins: %d / %d" % [engine.players[1].coins, engine.players[2].coins]


## Player 0 really holds the Heir, sells it out and is called a liar. The
## card drawn in its place is another Heir: it stays, nobody saw it.
static func _proven_shed_once() -> String:
	var table := Table.new(true, [&"heir"])
	var engine := table.engine
	var seen := Witness.new()
	engine.observers.append(seen)
	var heir: PlayerState = engine.players[0]
	heir.cards = [&"heir", &"judge"]
	engine.deck.append(&"heir")
	table.puppets[1].answers[Decision.Kind.DOUBT] = func(d: Decision) -> Variant:
		return d.options[0] if not d.options.is_empty() else false
	await engine.claim(heir, table.ability(&"heir.sold_out"))
	var traded: Array = seen.of(&"cards_changed")
	if traded.size() != 1 or traded[0].data.reason != &"sold_out":
		return "traded %d times" % traded.size()
	return "" if heir.cards == [&"heir", &"judge"] and heir.coins == 24 else "hand %s, %d coins" % [heir.cards, heir.coins]


## Player 1 bluffs a Sold Out (the card to give up is chosen before anyone
## hears of it) and player 0 seizes one of two items (chosen once the claim
## has gone through): only the first is marked private.
static func _private_choices() -> String:
	var table := Table.new(true, [&"heir", &"sheriff"])
	var engine := table.engine
	engine.players[1].cards = [&"judge", &"voodooist"]
	table.puppets[1].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 0
	await engine.claim(engine.players[1], table.ability(&"heir.sold_out"))
	var secret: Array = table.asked(1, Decision.Kind.PICK)
	if secret.size() != 1 or not secret[0].context.get("private", false):
		return "the card to give up was chosen in the open"
	engine.players[0].cards = [&"sheriff", &"judge"]
	table.give(1, [&"potion", &"soul_swap"])
	table.puppets[0].answers[Decision.Kind.TARGET] = func(_d: Decision) -> PlayerState: return engine.players[1]
	table.puppets[0].answers[Decision.Kind.PICK] = func(_d: Decision) -> int: return 0
	await engine.claim(engine.players[0], table.ability(&"sheriff.confiscate"))
	var aimed: Array = table.asked(0, Decision.Kind.TARGET)
	var seized: Array = table.asked(0, Decision.Kind.PICK)
	if aimed.size() != 1 or not aimed[0].context.get("private", false):
		return "the target was chosen in the open"
	return "" if seized.size() == 1 and not seized[0].context.get("private", false) else "the item to seize was chosen in private"


static func _bargain_caution() -> String:
	var table := Table.new(true, [&"vagabond"])
	var engine := table.engine
	var bargain := table.ability(&"vagabond.street_bargain")
	if engine.ability_option(engine.players[1], bargain).caution == "":
		return "no warning for a bluff"
	engine.players[1].cards = [&"vagabond", &"judge"]
	return "" if engine.ability_option(engine.players[1], bargain).caution == "" else "a warning for the truth"


static func _vanishes(d: Decision) -> Variant:
	for option: Dictionary in d.options:
		if option.kind == &"ability" and option.ability.id == &"spy.untraceable":
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
