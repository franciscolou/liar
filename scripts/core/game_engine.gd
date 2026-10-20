class_name GameEngine
extends RefCounted
## Rules and flow of a match, with no knowledge of the screen.
##
## The whole match is one coroutine (run). Whenever it needs a choice it
## awaits a Controller; whenever something happens it awaits fire(), which
## is the single extension point of the game:
##
##   1. observers (the table UI) animate the event;
##   2. every character in the match and every held item gets a hook call;
##   3. a reaction window opens: each player may claim an ability whose
##      reacts_to() accepts the event, or use a reaction item.
##
## A claim made inside a reaction window is a normal claim: it can be
## doubted, costs coins, fires its own events and so on, recursively.

signal finished(winner: PlayerState)
## A decision was put to its player, and then it was answered (or dropped).
## For a screen that shows who is being waited for; nothing in the rules.
## One with context.private is nobody else's business.
signal asking(decision: Decision)
signal settled(decision: Decision)
## Several players are being asked the same thing at once (a doubt window, a
## round of side bets): `state` is &"asked" as it opens for `player`, &"passed"
## once they let it go, and &"closed" (with no player) when it is over.
signal polled(player: PlayerState, state: StringName)

## Reactions to reactions to reactions... stop being offered at this depth.
const MAX_REACTION_DEPTH := 4
const MAX_TURN_STEPS := 40
## What a doubter loses for a wrong call (see doubt_stakes).
const STAKE_COINS := &"coins"
const STAKE_DEBT := &"debt"
const STAKE_MORALE := &"morale"

var config: GameConfig
var rng := RandomNumberGenerator.new()
var players: Array = []  # PlayerState
var controllers: Array = []  # Controller, indexed by player id
var observers: Array = []  # objects with `present(event)`, awaited
var characters: Array = []  # CharacterDef in this match
var item_pool: Array = []  # ItemDef the shop can stock
var fixed_items: Array = []  # ItemDef always on sale, outside the slots
var deck: Array = []  # character ids
var shop: Array = []  # ItemDef or null per slot; one shop for the whole table
var current: PlayerState
var turn_count := 0
var over := false
var winner: PlayerState
var aborted := false
## The last ability that went through as the action of somebody's turn.
var last_action: Ability
## Set by the table so bots can take a breath; null in headless runs.
var tree: SceneTree
## Bots don't take a breath either while the table is replaying a match it
## came back to (Room.catching_up).
var hurry := false

var _reaction_depth := 0
## How many plays are being made ready and not announced yet (their target,
## whatever prepare() asks): what is asked meanwhile is the asker's secret.
var _unannounced := 0
## How many decisions have been asked so far (see _reaction_window).
var _asks := 0
## The plays whose resolve() is running, innermost last.
var _resolving: Array = []


func setup(game_config: GameConfig) -> void:
	Content.ensure_loaded()
	config = game_config
	if config.rng_seed != 0:
		rng.seed = config.rng_seed
	else:
		rng.randomize()

	# The cast: so many drawn out of every character there is, or out of the
	# ones the host picked by hand (all of those, unless a number was set).
	var ids := config.character_ids.duplicate()
	var drawn := config.pool_draw
	if ids.is_empty():
		ids = Content.characters.keys()
		drawn = clampi(config.character_count, 1, ids.size())
	if drawn > 0 and drawn < ids.size():
		_shuffle(ids)
		ids = ids.slice(0, drawn)
	characters.clear()
	for def in Content.character_list():
		if ids.has(def.id):
			characters.append(def)

	item_pool.clear()
	fixed_items.clear()
	for def in Content.item_list():
		if def.fixed:
			fixed_items.append(def)
		elif config.item_ids.is_empty() or config.item_ids.has(def.id):
			item_pool.append(def)

	var copies := maxi(config.copies_per_character, config.min_copies(characters.size()))
	deck.clear()
	for def in characters:
		for i in copies:
			deck.append(def.id)
	_shuffle(deck)

	players.clear()
	for i in config.seats.size():
		var seat: Dictionary = config.seats[i]
		var p := PlayerState.new()
		p.id = i
		p.name = seat.get("name", "Player %d" % (i + 1))
		p.is_bot = seat.get("bot", false)
		p.morale = config.start_morale
		p.coins = config.start_coins
		for c in hand_limit(p):
			p.cards.append(deck.pop_back())
		players.append(p)

	shop.clear()
	for i in config.shop_slots:
		shop.append(_random_item())
	controllers.resize(players.size())


func run() -> void:
	await fire(&"game_started")
	# Whoever opens the match is drawn, unless the config names a seat.
	var index := rng.randi_range(0, players.size() - 1)
	if config.first_seat >= 0:
		index = config.first_seat % players.size()
	while not over:
		current = players[index]
		if current.alive:
			await _play_turn(current)
			if config.max_turns > 0 and turn_count >= config.max_turns:
				break
		index = (index + 1) % players.size()
	if aborted:
		return
	await fire(&"game_over", {"winner": winner})
	finished.emit(winner)


# --- events ------------------------------------------------------------------

func fire(type: StringName, data: Dictionary = {}) -> GameEvent:
	var event := GameEvent.new(type, data)
	await fire_event(event)
	return event


func fire_event(event: GameEvent) -> void:
	for controller in controllers:
		if controller != null:
			controller.observe(event)
	for observer in observers:
		await observer.present(event)
	for def in characters:
		await def.on_event(event, self)
	for p in players:
		if p.alive:
			for instance in p.items.duplicate():
				if p.items.has(instance):
					await instance.def.on_held_event(event, p, instance, self)
	await _reaction_window(event)


func _reaction_window(event: GameEvent) -> void:
	if over or _reaction_depth >= MAX_REACTION_DEPTH:
		return
	# What only one of them can get is raced for first; the rest goes round
	# the table, each in their turn.
	await _contested_window(event)
	for p in seat_order(current):
		# Asked again for as long as they back out of what they picked (a
		# target, a card to give up): that is a step back, not a pass.
		var again := true
		while again:
			again = false
			if over or event.cancelled:
				return
			var options := reaction_options(p, event).filter(func(option: Dictionary) -> bool:
				return not _contested(option))
			if options.is_empty():
				break
			var choice: Variant = null
			var asked := false
			var early: Dictionary = _early_reactions(event).get(p.id, {})
			if event.data.get("auto") == p:
				choice = options[0]
			elif _same_option(options, early.get("answer")) != null:
				# Already answered in the doubt window. Once: it is spent.
				choice = _same_option(options, early.answer)
				early.answer = null
			else:
				# What they saw there and let through is not offered again.
				options = options.filter(func(option: Dictionary) -> bool:
					return _same_option(early.get("offered", []), option) == null)
				if options.is_empty():
					break
				var d := Decision.new(Decision.Kind.REACT, p)
				d.options = options
				d.context = {"event": event}
				choice = await ask(d)
				asked = true
			if choice == null:
				break
			# Only if they did back out of something: a reaction that came to
			# nothing without asking them anything would be offered forever.
			var asks := _asks
			again = not await _react(p, choice, event) and asked and not p.is_bot and _asks != asks


## `player` answers `event` with reaction option `choice`. False if they
## backed out of it before anything was announced.
func _react(player: PlayerState, choice: Dictionary, event: GameEvent) -> bool:
	_reaction_depth += 1
	var play: Play
	if choice.kind == &"ability":
		play = await claim(player, choice.ability, event)
	else:
		play = await use_item(player, choice.item, event)
	_reaction_depth -= 1
	return play != null


## Whether reaction `option` plays something only one player can get (see
## Playable.contested).
func _contested(option: Dictionary) -> bool:
	var source: Playable = option.ability if option.kind == &"ability" else option.item.def
	return source.contested


## The reactions to `event` that only one player can get (Playable.contested)
## go to whoever plays them first, not by seat: everyone who could is asked at
## once and the first answer closes the round, as in a doubt window. Bots hold
## back until every human has passed, and one of those willing is drawn. If
## what the winner played came to nothing (a lie caught, coins talked out of
## it) and the event is still there to be answered, those who had not
## answered yet are asked again.
func _contested_window(event: GameEvent) -> void:
	var heard := {}  # player id -> true: they played it or let it go
	while not over and not event.cancelled:
		var taker: PlayerState = null
		var choice: Variant = null
		var humans: Array = []
		var bots: Array = []
		for p: PlayerState in seat_order(current):
			if heard.has(p.id):
				continue
			var options := reaction_options(p, event).filter(_contested)
			if options.is_empty():
				continue
			var early: Dictionary = _early_reactions(event).get(p.id, {})
			var ahead: Variant = _same_option(options, early.get("answer"))
			if ahead != null:
				# Answered back in the doubt window: nobody was quicker than that.
				if taker == null:
					taker = p
					choice = ahead
					early.answer = null
				continue
			# What they saw there and let through is not offered again.
			options = options.filter(func(option: Dictionary) -> bool:
				return _same_option(early.get("offered", []), option) == null)
			if options.is_empty():
				continue
			var d := Decision.new(Decision.Kind.REACT, p)
			d.options = options
			d.context = {"event": event}
			(bots if p.is_bot else humans).append(d)
		if taker == null and not humans.is_empty():
			var poll := DoubtPoll.new()
			poll.open = humans.size()
			for d: Decision in humans:
				_poll_reaction(d, poll, heard)
			if not poll.done:
				await poll.settled
			for d: Decision in humans:
				if not d.context.get("answered", false):
					controllers[d.player.id].withdraw(d)
			if over:
				return
			if not poll.result.is_empty():
				taker = poll.result.player
				choice = poll.result.choice
		if taker == null:
			var willing := []
			for d: Decision in bots:
				if over:
					return
				var answer: Variant = _same_option(d.options, await ask(d))
				heard[d.player.id] = true
				if answer != null:
					willing.append({"player": d.player, "choice": answer})
			if not willing.is_empty():
				# Whoever of them reaches for it first.
				var first: Dictionary = willing[rng.randi_range(0, willing.size() - 1)]
				taker = first.player
				choice = first.choice
		if taker == null:
			return
		heard[taker.id] = true
		if not await _react(taker, choice, event) and not taker.is_bot:
			# They backed out before announcing it: a step back, not a pass.
			# They are asked again, with whoever had not answered yet.
			heard.erase(taker.id)


## Waits for one human's answer in a contested window that others are in too.
func _poll_reaction(d: Decision, poll: DoubtPoll, heard: Dictionary) -> void:
	var answer: Variant = await ask(d)
	d.context["answered"] = true
	if poll.done:
		return
	heard[d.player.id] = true
	poll.open -= 1
	var choice: Variant = _same_option(d.options, answer)
	if choice != null:
		poll.result = {"player": d.player, "choice": choice}
	if poll.open <= 0 or not poll.result.is_empty():
		poll.done = true
		poll.settled.emit()


## Answers given ahead of time, in the doubt window, to the reaction window
## of `event`: {player id: {answer: option or null to pass, offered: what they
## chose from}}. They stand for the claim_resolving of that claim and for
## whatever happens while it resolves.
func _early_reactions(event: GameEvent) -> Dictionary:
	var cause: Play = event.data.get("play")
	if event.type == &"claim_resolving" and cause != null:
		return _early_of(cause)
	return {} if _resolving.is_empty() else _early_of(_resolving.back())


func _early_of(play: Play) -> Dictionary:
	if not play.params.has("early_reactions"):
		play.params["early_reactions"] = {}
	return play.params["early_reactions"]


## The entry of `options` that plays the same thing as `wanted`, or null.
func _same_option(options: Array, wanted: Variant) -> Variant:
	if wanted is Dictionary:
		for option: Dictionary in options:
			if option.kind == wanted.get("kind") and option.get("ability") == wanted.get("ability") and option.get("item") == wanted.get("item"):
				return option
	return null


## What `player` may already answer `play` with as it is announced, instead
## of waiting to be asked: the reactions to its claim_resolving and those
## that see their own trigger coming (Ability.foresees).
func early_options(player: PlayerState, play: Play) -> Array:
	var out := reaction_options(player, GameEvent.new(&"claim_resolving", {"play": play}))
	if not player.alive:
		return out
	for def in characters:
		for ability: Ability in def.abilities:
			if ability.info_only or not ability.foresees(play, player, self):
				continue
			var option := ability_option(player, ability)
			if option.enabled and _same_option(out, option) == null:
				out.append(option)
	return out


## What `player` could play in response to `event`.
func reaction_options(player: PlayerState, event: GameEvent) -> Array:
	var out := []
	if not player.alive:
		return out
	var cause: Play = event.data.get("play")
	for def in characters:
		for ability: Ability in def.abilities:
			if ability.info_only or not ability.reacts_to(event, player, self):
				continue
			if cause != null and cause.source == ability and cause.actor == player and not ability.self_chain:
				continue
			var option := ability_option(player, ability)
			if option.enabled and _has_targets(player, ability, event):
				out.append(option)
	for instance: ItemInstance in player.items:
		var def := instance.def
		if def.kind == ItemDef.Kind.REACTION and def.reacts_to(event, player, self):
			if item_lock_reason(instance) == "" and blocked_reason(player, def.tags) == "" and def.can_use(player, self) == "":
				out.append({"kind": &"item", "item": instance, "enabled": true, "reason": ""})
	return out


## Whether `ability`, claimed by `player` in answer to `event`, would have
## anyone to aim at. One with nobody would be offered only to come to nothing.
func _has_targets(player: PlayerState, ability: Ability, event: GameEvent) -> bool:
	return ability.targeting == Playable.Targeting.NONE or not _candidates_for(player, ability, event).is_empty()


# --- decisions ---------------------------------------------------------------

func ask(decision: Decision) -> Variant:
	if aborted:
		match decision.kind:
			Decision.Kind.DOUBT:
				return false
			Decision.Kind.PICK:
				return -1
		return null
	# Nobody else is to know that a choice is being made before its play is
	# announced: that somebody is choosing a card to give up tells of a bluff.
	if _unannounced > 0:
		decision.context["private"] = true
	_asks += 1
	asking.emit(decision)
	var answer: Variant = await controllers[decision.player.id].decide(decision)
	settled.emit(decision)
	return answer


## Puts each of `decisions` to its player, all at once, and waits until every
## one of them has answered: {player id: answer}. Bots answer on the spot.
func ask_all(decisions: Array) -> Dictionary:
	var answers := {}
	if decisions.is_empty():
		return answers
	var poll := DoubtPoll.new()
	poll.open = decisions.size()
	for d: Decision in decisions:
		if not d.player.is_bot:
			polled.emit(d.player, &"asked")
	for d: Decision in decisions:
		_poll_answer(d, poll, answers)
	if not poll.done:
		await poll.settled
	polled.emit(null, &"closed")
	return answers


func _poll_answer(d: Decision, poll: DoubtPoll, answers: Dictionary) -> void:
	answers[d.player.id] = await ask(d)
	if not d.player.is_bot:
		polled.emit(d.player, &"passed")
	poll.open -= 1
	if poll.open <= 0:
		poll.done = true
		poll.settled.emit()


## Stops the match where it stands (the table was closed). Whatever is still
## suspended unwinds without touching controllers or observers again.
func abort() -> void:
	aborted = true
	over = true
	observers.clear()


## Lets bots hesitate when there is a table to watch.
func think(seconds: float) -> void:
	if tree != null and seconds > 0.0 and not aborted and not hurry:
		await tree.create_timer(seconds / maxf(config.anim_speed, 0.1)).timeout


func turn_options(player: PlayerState) -> Dictionary:
	var out := {"abilities": [], "buy": [], "use": [], "discard": [], "extras": [], "reroll": null}
	for def in characters:
		for ability: Ability in def.abilities:
			if ability.on_turn:
				out.abilities.append(ability_option(player, ability))
		for extra: Dictionary in def.turn_extras(player, self):
			extra["kind"] = &"extra"
			extra["character"] = def.id
			out.extras.append(extra)
	for def: ItemDef in fixed_items:
		out.buy.append(_buy_option(player, def, -1))
	for slot in shop.size():
		if shop[slot] != null:
			out.buy.append(_buy_option(player, shop[slot], slot))
	if not item_pool.is_empty():
		var cost := reroll_cost(player)
		var reason := "" if can_pay(player, cost) else Loc.t("Not enough coins")
		out.reroll = {
			"kind": &"reroll", "cost": cost, "enabled": reason == "",
			"reason": reason, "credit": cost > player.coins,
			"free": free_rerolls(player),
		}
	for instance: ItemInstance in player.items:
		var def := instance.def
		var reason := ""
		if def.kind != ItemDef.Kind.ACTIVE:
			reason = def.kind_label()
		else:
			reason = item_lock_reason(instance)
			if reason == "":
				reason = blocked_reason(player, def.tags)
			if reason == "":
				reason = def.can_use(player, self)
			if reason == "" and def.targeting != Playable.Targeting.NONE and _candidates_for(player, def).is_empty():
				reason = Loc.t("No valid target")
		out.use.append({"kind": &"use", "item": instance, "enabled": reason == "", "reason": reason})
		# Anything held can be thrown away, whatever it is and however new.
		out.discard.append({"kind": &"discard", "item": instance, "enabled": true, "reason": ""})
	return out


## `slot` is the shop slot, or -1 for an item that is always on sale.
func _buy_option(player: PlayerState, def: ItemDef, slot: int) -> Dictionary:
	var reason := ""
	var cost := price(player, def.price)
	if def.service:
		reason = blocked_reason(player, def.tags)
		if reason == "" and def.whole_turn and player.turn.get("busy", false):
			reason = Loc.t("Takes the entire turn")
		if reason == "":
			reason = def.can_use(player, self)
	elif player.items.size() >= config.inventory_limit:
		reason = Loc.t("Inventory full")
	if reason == "" and not can_pay(player, cost):
		reason = Loc.t("Not enough coins")
	return {
		"kind": &"buy", "slot": slot, "item": def, "enabled": reason == "",
		"reason": reason, "credit": cost > player.coins, "cost": cost,
	}


## `cost` is what the ability would cost right now (see claim_cost).
func ability_option(player: PlayerState, ability: Ability) -> Dictionary:
	var reason := claim_block_reason(player, ability)
	var cost := claim_cost(player, ability)
	return {
		"kind": &"ability", "ability": ability, "enabled": reason == "", "reason": reason,
		"legit": player.has_character(ability.character_id), "credit": cost > player.coins,
		"cost": cost, "detail": ability.detail(player, self),
		"caution": ability.caution(player, self),
	}


## What statuses add to every price `player` pays (the `surcharge` of a
## status: see bartender.gd).
func surcharge(player: PlayerState) -> int:
	var extra := 0
	for status_id: StringName in player.statuses:
		extra += int(player.statuses[status_id].get("surcharge", 0))
	return extra


## What `player` pays right now for something priced at `amount`: a claim,
## an item bought, a reroll, a turn extra. Whatever has a price pays the
## surcharge() on top of it; what is free stays free. The fine of a wrong
## LIAR! is not a purchase and does not go through here.
func price(player: PlayerState, amount: int) -> int:
	return amount + surcharge(player) if amount > 0 else amount


## The rerolls of the shop `player` has for nothing in the turn being played
## (heir.gd puts them in `turn.free_rerolls`).
func free_rerolls(player: PlayerState) -> int:
	return int(player.turn.get("free_rerolls", 0))


## What replacing the shop slots costs `player` right now.
func reroll_cost(player: PlayerState) -> int:
	return 0 if free_rerolls(player) > 0 else price(player, config.reroll_cost)


## What claiming `ability` costs `player` right now.
func claim_cost(player: PlayerState, ability: Ability) -> int:
	return price(player, ability.cost_for(player, self))


func claim_block_reason(player: PlayerState, ability: Ability) -> String:
	if ability.info_only:
		return Loc.t("Always active")
	var reason := blocked_reason(player, ability.tags)
	if reason != "":
		return reason
	if ability.fresh_turn and player.turn.get("busy", false):
		return Loc.t("Takes the entire turn")
	var cost := claim_cost(player, ability)
	if cost > 0 and not can_pay(player, cost):
		return Loc.t("Not enough coins")
	reason = ability.can_use(player, self)
	if reason == "" and ability.targeting != Playable.Targeting.NONE and _candidates_for(player, ability).is_empty():
		reason = Loc.t("No valid target")
	return reason


func _candidates_for(player: PlayerState, source: Playable, event: GameEvent = null) -> Array:
	var probe := Play.new()
	probe.engine = self
	probe.actor = player
	probe.source = source
	probe.event = event
	return source.target_candidates(probe)


# --- turn --------------------------------------------------------------------

func _play_turn(p: PlayerState) -> void:
	turn_count += 1
	p.turn = {}
	await fire(&"turn_started", {"player": p})
	await _tick_statuses(p, &"own_turn_start")
	var income := await fire(&"income", {"player": p, "amount": config.income})
	await gain_coins(p, income.data.amount, &"income")

	var steps := 0
	while not over and p.alive and steps < MAX_TURN_STEPS:
		steps += 1
		var d := Decision.new(Decision.Kind.TURN, p)
		d.options = turn_options(p)
		var choice: Variant = await ask(d)
		if not choice is Dictionary:
			break
		match choice.get("kind", &"end"):
			&"buy":
				var bought := await buy_item(p, choice.item, choice.slot)
				if bought and choice.item.whole_turn:
					break
			&"reroll":
				await reroll_shop(p)
			&"use":
				await use_item(p, choice.item)
			&"discard":
				await discard_item(p, choice.item)
			&"extra":
				p.turn["busy"] = true
				await choice.run.call(p, self)
				if choice.get("ends_turn", false):
					break
			&"ability":
				var play := await claim(p, choice.ability)
				if play != null and choice.ability.ends_turn:
					break
			_:
				break
	if p.alive and not over:
		await _tick_statuses(p, &"own_turn_end")
	await fire(&"turn_ended", {"player": p})


# --- claims and items --------------------------------------------------------

## `actor` declares `ability`. Returns null if they backed out before
## announcing it; otherwise the Play, whatever its outcome. `params` are
## choices already made for it (see gambler.gd).
##
## The price is put down as the claim is announced, before anyone answers it:
## what a player has is always what they have left to spend, and nothing is
## bought on the hope that an earlier claim comes to nothing. A liar who is
## caught gets it back (challenge): a lie costs Morale, not coins.
func claim(actor: PlayerState, ability: Ability, trigger: GameEvent = null, params: Dictionary = {}) -> Play:
	var play := Play.new()
	play.engine = self
	play.actor = actor
	play.source = ability
	play.event = trigger
	play.params = params.duplicate()
	play.cost = claim_cost(actor, ability)
	play.truthful = actor.has_character(ability.character_id)
	if not await _make_ready(play):
		return null
	actor.turn["busy"] = true

	await fire(&"claim_declared", {"play": play})
	if not over and actor.alive:
		if await pay(actor, play.cost, &"cost", play):
			play.paid = play.cost
		else:
			play.failed = true
	var doubter: PlayerState = null
	var stake := STAKE_COINS
	var proven := false
	var host := _host_claim(play)
	if not play.failed and not over and actor.alive and host == null:
		var doubt := await _doubt_window(play)
		doubter = doubt.get("player")
		stake = doubt.get("stake", STAKE_COINS)
	if doubter != null:
		if await challenge(doubter, play, stake):
			await fire(&"claim_resolved", {"play": play})
			return play
		proven = true
		# The claim was proven: whoever let it pass may think again.
		var early := _early_of(play)
		for id: int in early.keys():
			if early[id].answer == null:
				early.erase(id)
	# The ability itself may send the card away (Sold Out...).
	var copies := actor.cards.count(ability.character_id)

	if not play.failed and not over and actor.alive:
		var resolving := await fire(&"claim_resolving", {"play": play})
		if resolving.cancelled:
			play.cancelled = true
			await fire(&"claim_cancelled", {"play": play})
		else:
			await _resolve(play)
			if trigger == null and ability.on_turn and ability.repeatable:
				last_action = ability
	# A proven card is traded so that nobody keeps knowing it. One the ability
	# itself already traded is known to nobody: it is not traded twice (not
	# even when what was drawn in its place is the same character again).
	var shed := play.shed or play.aimed().shed
	if proven and not play.stand_in and not shed and actor.cards.count(ability.character_id) >= copies:
		await renew_proven_card(actor, ability.character_id)
	await fire(&"claim_resolved", {"play": play})
	# Riding on its host, the lie is the host's: it stands or falls with it.
	if not play.truthful and doubter == null and not play.failed and not over and actor.alive and host == null:
		await fire(&"lie_succeeded", {"play": play, "player": actor})
	return play


## The claim `play` is paying for, when `play` claims the same character
## (the On the Cuff a Street Bargain needs, see vagabond.gd): a LIAR! is about
## the card, not the ability, so the two are one claim to the table. `play`
## gets no doubt window of its own: the host's answers for both, and a liar
## caught there loses one Morale for the pair.
func _host_claim(play: Play) -> Play:
	var event := play.event
	if event == null or event.type != &"payment_short":
		return null
	var host: Play = event.data.get("play")
	if host == null or host == play or host.actor != play.actor or not host.is_claim():
		return null
	return host if host.ability().character_id == play.ability().character_id else null


## A claim made in answer to `event` outside its reaction window (a hook that
## gathers the answers its own way: gambler.gd). It is one more level of
## reactions, like any other.
func claim_reaction(player: PlayerState, ability: Ability, event: GameEvent, params: Dictionary = {}) -> Play:
	_reaction_depth += 1
	var play := await claim(player, ability, event, params)
	_reaction_depth -= 1
	return play


## False once reactions are nested as deep as they go.
func can_react() -> bool:
	return not over and _reaction_depth < MAX_REACTION_DEPTH


## The coins `player` would forfeit, on top of the Morale, if caught lying
## right now: every one of them Under Oath (see judge.gd), none otherwise.
func oath_stake(player: PlayerState) -> int:
	return maxi(player.coins, 0) if player.has_status(&"truth_bound") else 0


## `doubter` calls LIAR! on `play`, whose `truthful` must be up to date.
## Returns true if it was a lie. When it was the truth, the caller owes the
## actor a renew_proven_card(). `stake` is one of doubt_stakes(): what the
## doubter loses for a wrong call.
func challenge(doubter: PlayerState, play: Play, stake: StringName = STAKE_COINS) -> bool:
	var actor := play.actor
	play.doubter = doubter
	await fire(&"doubt_declared", {"play": play, "doubter": doubter, "stake": stake})
	await fire(&"doubt_revealed", {"play": play, "doubter": doubter, "truthful": play.truthful})
	if play.truthful:
		if stake == STAKE_MORALE:
			# A bet lost, not an attack: nobody gets credit for it.
			await lose_morale(doubter, 1, null, &"doubt", play)
		else:
			await pay(doubter, config.doubt_cost, &"doubt")
		await fire(&"doubt_failed", {"play": play, "doubter": doubter, "defender": actor})
		return false
	play.failed = true
	# What the claim cost was put down as it was made: a lie costs Morale instead.
	if play.paid > 0:
		var back := play.paid
		play.paid = 0
		await change_coins(actor, back, &"refund", null, play)
	# Sworn when the lie was told, whatever becomes of the oath meanwhile.
	var sworn := actor.has_status(&"truth_bound")
	await lose_morale(actor, 1, doubter, &"lie", play)
	# Perjury: the purse goes to the bank, whether or not the Morale was saved.
	if sworn and actor.alive and not over and actor.coins > 0:
		await change_coins(actor, -actor.coins, &"oath")
	if not over and doubter.alive:
		await gain_coins(doubter, config.doubt_reward, &"doubt_reward")
	if not over and doubter.alive:
		await fire(&"doubt_succeeded", {"play": play, "doubter": doubter, "liar": actor})
	return true


func use_item(player: PlayerState, instance: ItemInstance, trigger: GameEvent = null) -> Play:
	if not player.items.has(instance):
		return null
	var play := Play.new()
	play.engine = self
	play.actor = player
	play.source = instance.def
	play.item = instance
	play.event = trigger
	if not await _make_ready(play):
		return null
	player.items.erase(instance)
	player.turn["busy"] = true
	instance.hidden = false
	await fire(&"item_used", {"player": player, "item": instance, "play": play})
	await _resolve(play)
	return play


## Everything `play` needs settled before it is announced: who it is aimed
## at and whatever its source asks (prepare). False if the actor backed out.
## What is asked meanwhile is marked private (see ask).
func _make_ready(play: Play) -> bool:
	_unannounced += 1
	var ready := await _choose_target(play)
	if ready:
		ready = await play.source.prepare(play)
	_unannounced -= 1
	return ready


## Carries out a play that was never announced as a claim or an item use (a
## bomb going off, see bomber.gd): shields and mirrors get their say (unless
## it is `unstoppable`), the table shows its effect and then it resolves.
func carry_out(play: Play) -> void:
	await _resolve(play)


## `slot` is the shop slot holding `def`, or -1 for an item that is always
## on sale (those never run out and take no slot). False if nothing was bought.
## Without `restock` the slot stays empty until restock_slot() (painter.gd).
func buy_item(player: PlayerState, def: ItemDef, slot := -1, restock := true) -> bool:
	var stocked := slot >= 0
	if stocked and (slot >= shop.size() or shop[slot] != def):
		return false
	if not stocked and not fixed_items.has(def):
		return false
	if def != null and def.service:
		return await _buy_service(player, def)
	if def == null or player.items.size() >= config.inventory_limit:
		return false
	if not await pay(player, price(player, def.price), &"shop"):
		return false
	player.turn["busy"] = true
	var instance := ItemInstance.new(def)
	await fire(&"item_buying", {"player": player, "item": instance, "slot": slot})
	# An item bought out of sight (nothing does it today: it was the Spy's
	# Low Profile) leaves the shelf as it was: a slot that changed would tell
	# the table what was taken.
	var unseen := instance.hidden and player.alive
	if stocked and not unseen:
		shop[slot] = null
	if player.alive:
		player.items.append(instance)
		await fire(&"item_bought", {"player": player, "item": instance, "slot": slot})
	if stocked and not unseen and restock:
		await restock_slot(slot)
	return true


## Puts something new on an empty shelf.
func restock_slot(slot: int) -> void:
	if slot < 0 or slot >= shop.size() or shop[slot] != null:
		return
	shop[slot] = _random_item()
	await fire(&"shop_restocked", {"slot": slot})


## `player` turns a held item into `amount` coins (painter.gd). It is the item
## changing form, not a gain: nothing takes the coins on their way.
func sell_item(player: PlayerState, instance: ItemInstance, amount: int) -> void:
	var index := player.items.find(instance)
	if index == -1:
		return
	player.items.erase(instance)
	player.turn["busy"] = true
	instance.hidden = false
	await fire(&"item_sold", {"player": player, "item": instance, "index": index, "amount": amount})
	await change_coins(player, amount, &"sold")


## A service (ItemDef.service) is paid for and done at once, as a play of the
## buyer that nobody can doubt: its choices come first (prepare), so backing
## out costs nothing.
func _buy_service(player: PlayerState, def: ItemDef) -> bool:
	var play := Play.new()
	play.engine = self
	play.actor = player
	play.source = def
	play.item = ItemInstance.new(def)
	if not await _make_ready(play):
		return false
	if not await pay(player, price(player, def.price), &"shop"):
		return false
	player.turn["busy"] = true
	await fire(&"service_bought", {"player": player, "item": play.item, "play": play})
	await _resolve(play)
	return true


## Pays to replace everything in the slots. Items always on sale stay.
func reroll_shop(player: PlayerState) -> void:
	if item_pool.is_empty():
		return
	if free_rerolls(player) > 0:
		player.turn["free_rerolls"] = free_rerolls(player) - 1
	elif not await pay(player, price(player, config.reroll_cost), &"shop"):
		return
	player.turn["busy"] = true
	for slot in shop.size():
		shop[slot] = _random_item()
	await fire(&"shop_rerolled", {"player": player})


## `sealed`: it can't be put to use for as long as the turn being played
## lasts (see item_lock_reason).
func give_item(player: PlayerState, def: ItemDef, hidden := false, sealed := false) -> ItemInstance:
	if def == null or player.items.size() >= config.inventory_limit:
		return null
	var instance := ItemInstance.new(def)
	instance.hidden = hidden
	if sealed:
		instance.sealed_turn = turn_count
	player.items.append(instance)
	await fire(&"item_gained", {"player": player, "item": instance})
	return instance


## "" unless `instance` is too new to be used: it came sealed (give_item) in
## the turn being played. What it does by itself, held, it does from the start.
func item_lock_reason(instance: ItemInstance) -> String:
	return Loc.t("Can't be used in the turn it was made") if instance.sealed_turn == turn_count else ""


## Removes a held item without using it (shields and mirrors breaking, the
## Bomber's "Demolition").
func break_item(player: PlayerState, instance: ItemInstance) -> void:
	var index := player.items.find(instance)
	player.items.erase(instance)
	instance.hidden = false
	await fire(&"item_broken", {"player": player, "item": instance, "index": index})


## `player` throws a held item away, on their own turn: it costs nothing, pays
## nothing and is no move of the turn (what takes a fresh turn still has one).
## A hidden item goes as it was: nobody is shown what it was.
func discard_item(player: PlayerState, instance: ItemInstance) -> void:
	var index := player.items.find(instance)
	if index == -1:
		return
	player.items.erase(instance)
	await fire(&"item_discarded", {"player": player, "item": instance, "index": index})


## Moves a held item from one inventory to another. A hidden item stays
## hidden: only the two of them know what changed hands.
func take_item(thief: PlayerState, victim: PlayerState, instance: ItemInstance) -> bool:
	if not victim.items.has(instance) or thief.items.size() >= config.inventory_limit:
		return false
	var index := victim.items.find(instance)
	victim.items.erase(instance)
	thief.items.append(instance)
	await fire(&"item_stolen", {"thief": thief, "victim": victim, "item": instance, "index": index})
	return true


## Has the actor of `play` pick who it is aimed at, if its source asks for
## a target. False if there is nobody to aim at or they backed out.
func choose_target(play: Play) -> bool:
	return await _choose_target(play)


func _choose_target(play: Play) -> bool:
	var source := play.source
	if source.targeting == Playable.Targeting.NONE:
		return true
	var candidates := source.target_candidates(play)
	if candidates.is_empty():
		return false
	if source.targeting == Playable.Targeting.RANDOM:
		play.target = candidates[rng.randi_range(0, candidates.size() - 1)]
		return true
	var d := Decision.new(Decision.Kind.TARGET, play.actor)
	d.options = candidates
	d.context = {"play": play}
	d.prompt = Loc.t("Choose a target for %s") % source.display_name
	d.cancellable = true
	play.target = await ask(d)
	return play.target != null


## What `player` may put up for a LIAR! call, lost if the claim was true.
## With the coins for the fine there is nothing to choose. Without them it is
## a debt (only if something lets them go that far into the red) or 1 Morale.
## Empty for someone who can't call LIAR! at all.
func doubt_stakes(player: PlayerState, _play: Play = null) -> Array[StringName]:
	var out: Array[StringName] = []
	# A status may take the call away altogether (it blocks the tag &"doubt").
	if not player.alive or blocked_reason(player, [&"doubt"]) != "":
		return out
	if player.coins >= config.doubt_cost or config.doubt_cost <= 0:
		out.append(STAKE_COINS)
		return out
	if can_pay(player, config.doubt_cost):
		out.append(STAKE_DEBT)
	out.append(STAKE_MORALE)
	return out


## Who calls LIAR! on `play` and with what: {player, stake}, or {} if nobody.
## The whole table is asked at once and the first call closes the window.
## Bots hold their tongue until every human has let the claim pass.
func _doubt_window(play: Play) -> Dictionary:
	var humans := []
	var bots := []
	for p in seat_order(play.actor):
		if p != play.actor and p.alive:
			(bots if p.is_bot else humans).append(p)
	var asked := []
	for p: PlayerState in humans:
		var d := Decision.new(Decision.Kind.DOUBT, p)
		d.options = doubt_stakes(p, play)
		d.context = {
			"play": play,
			# Answering the claim with a reaction is the third way out of this window.
			"reactions": early_options(p, play),
		}
		# Someone who can neither doubt nor react has nothing to be asked.
		if not d.options.is_empty() or not d.context.reactions.is_empty():
			asked.append(d)
	if not asked.is_empty():
		var poll := DoubtPoll.new()
		poll.open = asked.size()
		for d: Decision in asked:
			polled.emit(d.player, &"asked")
		for d: Decision in asked:
			_poll_doubt(d, poll)
		if not poll.done:
			await poll.settled
		for d: Decision in asked:
			if not d.context.get("answered", false):
				controllers[d.player.id].withdraw(d)
		polled.emit(null, &"closed")
		if over or not poll.result.is_empty():
			return {} if over else poll.result
	var willing := []
	for p: PlayerState in bots:
		if over:
			return {}
		var d := Decision.new(Decision.Kind.DOUBT, p)
		d.options = doubt_stakes(p, play)
		if d.options.is_empty():
			continue
		d.context = {"play": play}
		var answer: Variant = await ask(d)
		if answer is StringName and d.options.has(answer):
			willing.append({"player": p, "stake": answer})
	# Whoever of them shouts first.
	return {} if willing.is_empty() else willing[rng.randi_range(0, willing.size() - 1)]


## Waits for one human's answer in a doubt window that others are in too.
func _poll_doubt(d: Decision, poll: DoubtPoll) -> void:
	var answer: Variant = await ask(d)
	d.context["answered"] = true
	if poll.done:
		return
	if not d.context.reactions.is_empty():
		_early_of(d.context.play)[d.player.id] = {
			"answer": _same_option(d.context.reactions, answer), "offered": d.context.reactions,
		}
	poll.open -= 1
	if answer is StringName and d.options.has(answer):
		poll.result = {"player": d.player, "stake": answer}
	else:
		polled.emit(d.player, &"passed")
	if poll.open <= 0 or not poll.result.is_empty():
		poll.done = true
		poll.settled.emit()


## Tally of a doubt window, shared by the coroutines asking each human.
class DoubtPoll extends RefCounted:
	signal settled
	var open := 0
	var done := false
	var result := {}


func _resolve(play: Play) -> void:
	# A mirror sends the play back at whoever aimed it, and that is a play
	# aimed at them like any other: it goes back and forth for as long as
	# there is a mirror to break, until it lands or a shield stops it.
	while play.target != null and not over:
		var targeted := await fire(&"targeted", {"play": play, "target": play.target})
		if targeted.data.get("blocked", false):
			play.blocked = true
			break
		if not targeted.data.get("reflected", false):
			break
		if play.target == play.actor:
			# Aimed at themselves: there is nobody to send it back to.
			play.blocked = true
			break
		var sender := play.actor
		play.actor = play.target
		play.target = sender
		play.reflected = not play.reflected
	if play.blocked or over or not play.actor.alive:
		return
	if play.target != null and not play.target.alive:
		return
	_resolving.append(play)
	await fire(&"play_effect", {"play": play})
	await play.source.resolve(play)
	_resolving.erase(play)


## For the passive items that answer a play aimed at their holder (they set
## ItemDef.guard: shield.gd, mirror.gd). True if `instance` is the one that
## acts on this `targeted` event: only one does, and a holder with more than
## one kind of them chooses which.
func guards(instance: ItemInstance, holder: PlayerState, event: GameEvent) -> bool:
	if event.type != &"targeted" or event.data.target != holder or event.data.play.source.unstoppable:
		return false
	if not event.data.has("guard"):
		event.data["guard"] = await _choose_guard(holder, event.data.play)
	return event.data.guard == instance


func _choose_guard(holder: PlayerState, play: Play) -> ItemInstance:
	# The first of each kind held, in the order of the inventory.
	var held: Array = []
	for instance: ItemInstance in holder.items:
		if instance.def.guard and not held.any(func(other: ItemInstance) -> bool: return other.def == instance.def):
			held.append(instance)
	if held.size() <= 1:
		return null if held.is_empty() else held[0]
	var d := Decision.new(Decision.Kind.PICK, holder)
	d.prompt = Loc.t("%s's %s is aimed at you. What do you answer it with?") % [play.actor.name, play.source.display_name]
	d.options = held.map(func(instance: ItemInstance) -> Dictionary: return {
		"label": instance.def.display_name, "description": instance.def.description, "item": instance.def,
	})
	d.context = {
		"play": play,
		"look": &"guard",
		"weights": held.map(func(instance: ItemInstance) -> float: return instance.def.ai_guard_weight(play, holder)),
	}
	var index: int = await ask(d)
	return held[index] if index >= 0 and index < held.size() else held[0]


# --- coins -------------------------------------------------------------------

func can_pay(player: PlayerState, amount: int) -> bool:
	if player.coins >= amount:
		return true
	var probe := GameEvent.new(&"payment_short", {"player": player, "amount": amount})
	return not reaction_options(player, probe).is_empty()


## `play`: the claim the coins are the price of, for the `coins` event.
func pay(player: PlayerState, amount: int, reason: StringName = &"cost", play: Play = null) -> bool:
	if amount <= 0:
		return true
	if player.coins < amount:
		var short := await fire(&"payment_short", {
			"player": player, "amount": amount, "allowed": false, "auto": player, "play": play,
		})
		if not short.data.allowed or over or not player.alive:
			return false
		# What was allowed is the debt as it stood. Coins spent while the tab
		# was being argued over (a reaction with a price) may have used it up.
		if not can_pay(player, amount):
			return false
	await change_coins(player, -amount, reason, null, play)
	return true


func change_coins(player: PlayerState, delta: int, reason: StringName, other: PlayerState = null, play: Play = null) -> void:
	if delta == 0:
		return
	player.coins += delta
	await fire(&"coins", {"player": player, "delta": delta, "reason": reason, "other": other, "play": play})


func gain_coins(player: PlayerState, amount: int, reason: StringName, other: PlayerState = null) -> void:
	if amount <= 0 or not player.alive:
		return
	var gain := await fire(&"before_gain", {"player": player, "amount": amount, "reason": reason})
	if gain.data.amount > 0:
		await change_coins(player, gain.data.amount, reason, other)


## Returns how many coins actually changed hands. `taken` and `given` are the
## reasons of the two `coins` events, for a theft the table shows its own way
## (the doll of a Voodooist: &"hexed" and &"voodoo").
func steal_coins(thief: PlayerState, victim: PlayerState, amount: int, play: Play = null, taken := &"stolen", given := &"steal") -> int:
	amount = mini(amount, maxi(victim.coins, 0))
	if amount <= 0:
		return 0
	var steal := await fire(&"before_steal", {
		"thief": thief, "victim": victim, "amount": amount, "play": play,
	})
	if steal.cancelled or over:
		return 0
	amount = mini(amount, maxi(victim.coins, 0))
	await change_coins(victim, -amount, taken, thief)
	await gain_coins(thief, amount, given, victim)
	return amount


## A coin tossed in front of the whole table. True for heads. `lucky_heads`
## says which side `player` is hoping for: the table cheers or sighs by it.
func flip_coin(player: PlayerState, lucky_heads := true) -> bool:
	var heads := rng.randf() < 0.5
	await fire(&"coin_flipped", {"player": player, "heads": heads, "won": heads == lucky_heads})
	return heads


## Something content wants the table to hear about and that no other event
## tells. `text` is an English key with one %s, for the player's name; `tag`
## names what the news is about, for a table that shows it its own way.
func note(player: PlayerState, text: String, good := true, tag := &"") -> void:
	await fire(&"note", {"player": player, "text": text, "good": good, "tag": tag})


func set_counter(player: PlayerState, counter_id: StringName, value: int) -> void:
	var delta := value - player.counter(counter_id)
	player.counters[counter_id] = value
	await fire(&"counter_changed", {
		"player": player, "counter": counter_id, "value": value, "delta": delta,
	})


# --- morale ------------------------------------------------------------------

## Damage from an ability or item. Returns true if Morale was lost.
func deal_damage(source: PlayerState, target: PlayerState, play: Play = null) -> bool:
	if not target.alive or blocked_reason(source, [&"damage"]) != "":
		return false
	if not await lose_morale(target, 1, source, &"damage", play):
		return false
	if not over:
		await fire(&"damage_dealt", {"source": source, "target": target, "play": play})
	return true


## Any loss of Morale. `cause` is &"damage", &"lie" (caught bluffing) or
## &"doubt" (Morale staked on a wrong call, with no `source`).
##
## The match ends with the first fall that leaves one player standing, and
## nobody loses Morale after that: whatever was still on its way to the
## winner (the blow they were answering when the other one fell) is void.
func lose_morale(target: PlayerState, amount: int, source: PlayerState, cause: StringName, play: Play = null) -> bool:
	if not target.alive or over:
		return false
	var before := await fire(&"before_morale_loss", {
		"target": target, "source": source, "amount": amount, "cause": cause, "play": play,
	})
	if before.cancelled or before.data.amount <= 0 or not target.alive or over:
		return false
	target.morale = maxi(target.morale - before.data.amount, 0)
	await fire(&"morale_lost", {
		"target": target, "source": source, "amount": before.data.amount, "cause": cause, "play": play,
	})
	if target.morale <= 0 and target.alive:
		await _eliminate(target, source, play)
	else:
		await _fit_hand(target)
	return true


## Morale given up by choice, as the price of something (entity.gd). It is no
## blow: nothing gets to stop it or answer it and nobody takes credit for it.
## Never the last point. The hand follows, as with any other loss.
func spend_morale(player: PlayerState, amount: int, play: Play = null) -> bool:
	if over or not player.alive or amount <= 0 or player.morale <= amount:
		return false
	player.morale -= amount
	await fire(&"morale_spent", {"player": player, "amount": amount, "play": play})
	await _fit_hand(player)
	return true


func heal(player: PlayerState, amount: int) -> bool:
	if not player.alive or blocked_reason(player, [&"heal"]) != "":
		return false
	var healed := mini(amount, config.start_morale - player.morale)
	if healed <= 0:
		return false
	player.morale += healed
	await fire(&"morale_gained", {"player": player, "amount": healed})
	await _fit_hand(player)
	return true


## `player` is taken out of the match by the host of the room, having left it
## (Room.away). Nothing of theirs stays on the table: the cards go back into
## the deck, which is shuffled, and the coins to the bank. It is nobody's
## doing, so nobody gets anything out of it. It comes as the answer to
## whatever they were being asked, in the middle of anything, so the table is
## told and nothing else: no hooks, no window to react to it.
func kick(player: PlayerState) -> void:
	if not player.alive or over:
		return
	player.alive = false
	player.morale = 0
	player.coins = 0
	deck.append_array(player.cards)
	player.cards.clear()
	_shuffle(deck)
	player.items.clear()
	player.statuses.clear()
	var alive := alive_players()
	if alive.size() <= 1:
		over = true
		winner = alive[0] if alive.size() == 1 else null
	var event := GameEvent.new(&"player_kicked", {"player": player})
	for controller in controllers:
		if controller != null:
			controller.observe(event)
	for observer in observers:
		await observer.present(event)


func _eliminate(player: PlayerState, killer: PlayerState, play: Play) -> void:
	player.alive = false
	# What they held stays on the table for all to see: it is out of the match.
	player.left = player.cards.duplicate()
	player.cards.clear()
	player.items.clear()
	player.statuses.clear()
	var alive := alive_players()
	if alive.size() <= 1:
		over = true
		winner = alive[0] if alive.size() == 1 else null
	await fire(&"player_eliminated", {"player": player, "killer": killer, "play": play})


# --- cards -------------------------------------------------------------------

## A player never holds more cards than Morale points.
func hand_limit(player: PlayerState) -> int:
	return mini(config.hand_size, player.morale)


## Brings the hand back to hand_limit() after Morale changed: the player picks
## what to give up (shown to the whole table, then shuffled into the deck), or
## draws from the deck.
func _fit_hand(player: PlayerState) -> void:
	if not player.alive:
		return
	var limit := hand_limit(player)
	while player.cards.size() > limit and not over:
		var index := await pick_own_card(player, Loc.t("%s, you lost Morale: give up a card") % player.name)
		if not player.alive or index < 0:
			return
		var card: StringName = player.cards.pop_at(index)
		deck.append(card)
		_shuffle(deck)
		await fire(&"card_lost", {"player": player, "index": index, "card": card})
	while player.alive and player.cards.size() < limit and not deck.is_empty() and not over:
		player.cards.append(deck.pop_back())
		await fire(&"card_drawn", {"player": player, "index": player.cards.size() - 1})


## Sends the card back to the deck and draws another one.
func replace_card(player: PlayerState, index: int, reason: StringName = &"swap") -> void:
	if index < 0 or index >= player.cards.size() or deck.is_empty():
		return
	var old: StringName = player.cards[index]
	player.cards[index] = deck.pop_back()
	deck.append(old)
	_shuffle(deck)
	await fire(&"cards_changed", {"player": player, "index": index, "reason": reason, "old": old})


## Trades the card at `index` of the hand for the one at `deck_index` of the
## deck (the player chose it: see gravedigger.gd), then shuffles the deck.
func trade_with_deck(player: PlayerState, index: int, deck_index: int, reason: StringName = &"swap") -> void:
	if index < 0 or index >= player.cards.size() or deck_index < 0 or deck_index >= deck.size():
		return
	var old: StringName = player.cards[index]
	player.cards[index] = deck[deck_index]
	deck[deck_index] = old
	_shuffle(deck)
	await fire(&"cards_changed", {"player": player, "index": index, "reason": reason, "old": old})


## The whole hand goes back into the deck and as many cards come out of it.
func redraw_hand(player: PlayerState) -> void:
	var count := player.cards.size()
	if count == 0 or not player.alive:
		return
	deck.append_array(player.cards)
	player.cards.clear()
	_shuffle(deck)
	for i in count:
		player.cards.append(deck.pop_back())
	await fire(&"hand_redrawn", {"player": player, "count": count})


## A doubt showed the whole table that `player` holds `character_id`: the card
## goes back to the deck and they draw another one.
func renew_proven_card(player: PlayerState, character_id: StringName) -> void:
	if over or not player.alive:
		return
	await replace_card(player, player.cards.find(character_id), &"proven")


## `by` calls `card` in: every copy of it, in whatever hand it is (their own
## too), goes back to the deck, and each of those places gets a new card.
func recall_cards(by: PlayerState, card: StringName) -> void:
	# Any other hand may be kept out of this (see reach_hand). Every hand is
	# asked, copy or not: asking only those who hold one would tell whoever
	# called it who does.
	var kept: Array = []
	for p: PlayerState in seat_order(by):
		if not await reach_hand(by, p, &"recall", card):
			kept.append(p)
	if over:
		return
	var hands: Array = []
	for p: PlayerState in seat_order(by):
		if kept.has(p):
			continue
		for i: int in p.cards.size():
			if p.cards[i] == card:
				hands.append({"player": p, "index": i})
	# The new cards come out first: as far as the deck goes, nobody draws
	# back what was just handed in.
	var drawn: Array = []
	while drawn.size() < hands.size() and not deck.is_empty():
		drawn.append(deck.pop_back())
	for i: int in hands.size():
		deck.append(card)
	_shuffle(deck)
	while drawn.size() < hands.size():
		drawn.append(deck.pop_back())
	for i: int in hands.size():
		hands[i].player.cards[hands[i].index] = drawn[i]
	await fire(&"cards_recalled", {"player": by, "card": card, "hands": hands})


## Before `by` sees, takes or replaces cards in the hand of `owner` (`how`:
## &"peek", &"swap", &"recall"): false when the hand was kept out of reach
## (before_hand_reach cancelled, see spy.gd), and then hand_missed says so.
## `card` is the character a recall named. Their own hand is out of this,
## a Last Call's caller's included: nobody slips out of their own call.
func reach_hand(by: PlayerState, owner: PlayerState, how: StringName, card := &"") -> bool:
	if by == owner or not owner.alive:
		return true
	var data := {"owner": owner, "by": by, "how": how}
	if how == &"recall":
		data.card = card
	var reach := await fire(&"before_hand_reach", data)
	if not reach.cancelled:
		return true
	if not over:
		await fire(&"hand_missed", data.duplicate())
	return false


## Before `by` takes or destroys an item `owner` holds (`how`: &"steal",
## &"break"): false when the items were kept out of reach (before_item_reach
## cancelled, see spy.gd), and then items_missed says so.
func reach_items(by: PlayerState, owner: PlayerState, how: StringName) -> bool:
	if by == owner or not owner.alive:
		return true
	var data := {"owner": owner, "by": by, "how": how}
	var reach := await fire(&"before_item_reach", data)
	if not reach.cancelled:
		return true
	if not over:
		await fire(&"items_missed", data.duplicate())
	return false


## `a` is who trades: `b` may keep their hand out of it (see reach_hand),
## unless the caller has been through that already (`reached`).
func swap_cards(a: PlayerState, a_index: int, b: PlayerState, b_index: int, reached := false) -> void:
	if a_index < 0 or a_index >= a.cards.size() or b_index < 0 or b_index >= b.cards.size():
		return
	if not reached and not await reach_hand(a, b, &"swap"):
		return
	if over or a_index >= a.cards.size() or b_index >= b.cards.size():
		return
	var card: StringName = a.cards[a_index]
	a.cards[a_index] = b.cards[b_index]
	b.cards[b_index] = card
	await fire(&"cards_swapped", {"a": a, "a_index": a_index, "b": b, "b_index": b_index})


## `viewer` looks at one card of `owner`, of their choosing: the cards are
## face down to them, so what they choose is a place in the hand. Returns
## where the card lies, -1 if nothing was seen.
func peek_card(viewer: PlayerState, owner: PlayerState) -> int:
	if owner.cards.is_empty():
		return -1
	if not await reach_hand(viewer, owner, &"peek") or over or owner.cards.is_empty():
		return -1
	var index := await pick_hidden_card(viewer, owner, Loc.t("Which of %s's cards do you look at?") % owner.name)
	if over or index < 0 or index >= owner.cards.size():
		return -1
	await fire(&"card_peeked", {
		"viewer": viewer, "owner": owner, "index": index, "card": owner.cards[index],
	})
	return index


## Lets `player` choose one of the cards `owner` holds without seeing them,
## by where it lies in the hand: its index, a random one if they don't
## answer, -1 with an empty hand.
func pick_hidden_card(player: PlayerState, owner: PlayerState, prompt: String) -> int:
	if owner.cards.size() <= 1:
		return owner.cards.size() - 1
	var d := Decision.new(Decision.Kind.PICK, player)
	d.prompt = prompt
	d.options = []
	for i: int in owner.cards.size():
		d.options.append({"label": Loc.t("Card %d") % (i + 1), "description": ""})
	# Picked where they lie, in the hand of whoever holds them (see table._open_pick).
	d.context = {"hand_of": owner}
	var index: int = await ask(d)
	if index < 0 or index >= owner.cards.size():
		index = random_card_index(owner)
	return index


## For an ability that sends "this card" away (heir.gd, bard.gd): whoever
## claims it without holding the card says, before the claim is announced,
## which one goes in its place. Asked only then, the table can't tell a bluff
## from the truth by a choice made afterwards. False if they backed out.
func choose_card_to_shed(play: Play) -> bool:
	var actor := play.actor
	var character_id := _own_card(play)
	if actor.has_character(character_id) or actor.cards.size() <= 1:
		return true
	var d := Decision.new(Decision.Kind.PICK, actor)
	d.prompt = Loc.t("Choose the card to swap")
	d.cancellable = true
	d.context = {"play": play, "quiet": true}
	d.options = actor.cards.map(func(card): return {
		"label": Content.character(card).display_name, "card": card,
	})
	var index: int = await ask(d)
	if index < 0 or index >= actor.cards.size():
		return false
	play.params["shed"] = actor.cards[index]
	return true


## Sends "this card" of `play` back to the deck for a new one: the claimed
## character if the actor holds it, otherwise what choose_card_to_shed() kept.
func shed_card(play: Play, reason: StringName) -> void:
	var actor := play.actor
	var index := actor.cards.find(_own_card(play))
	if index == -1:
		index = actor.cards.find(play.params.get("shed", &""))
	if index == -1:
		index = random_card_index(actor)
	play.shed = true
	await replace_card(actor, index, reason)


## The character that "this card" of `play` is: the one claimed, or the one
## whose claim carries it out (params.card: an action the Impostor repeats
## sends the Impostor away, not the card of whoever did it first).
func _own_card(play: Play) -> StringName:
	return play.params.get("card", play.ability().character_id)


## Lets `player` choose one of the cards in their hand: its index, a random
## one if they don't answer, -1 with an empty hand.
func pick_own_card(player: PlayerState, prompt: String) -> int:
	if player.cards.size() <= 1:
		return player.cards.size() - 1
	var d := Decision.new(Decision.Kind.PICK, player)
	d.prompt = prompt
	d.options = player.cards.map(func(card): return {
		"label": Content.character(card).display_name, "card": card,
	})
	var index: int = await ask(d)
	if index < 0 or index >= player.cards.size():
		index = random_card_index(player)
	return index


func random_card_index(player: PlayerState) -> int:
	return rng.randi_range(0, player.cards.size() - 1) if not player.cards.is_empty() else -1


# --- statuses ----------------------------------------------------------------

## options: expires (&"own_turn_start" | &"own_turn_end" | &"never"),
## turns (how many of those boundaries it survives, default 1),
## by (player id that applied it), blocks (tags the player can't use),
## surcharge (coins added to every price the player pays: see price()).
func add_status(player: PlayerState, status_id: StringName, options: Dictionary = {}) -> void:
	if not player.alive:
		return
	player.statuses[status_id] = options
	await fire(&"status_added", {"player": player, "status": status_id})


## `reason` says why, when it is not just over: &"wasted" for one that was
## thrown away with nothing for it (see entity.gd).
func remove_status(player: PlayerState, status_id: StringName, reason := &"") -> void:
	var was: Dictionary = player.statuses.get(status_id, {})
	if player.statuses.erase(status_id):
		await fire(&"status_removed", {"player": player, "status": status_id, "reason": reason, "was": was})


## "" if nothing stops `player` from using something with these tags.
func blocked_reason(player: PlayerState, tags: Array) -> String:
	for status_id: StringName in player.statuses:
		for tag in player.statuses[status_id].get("blocks", []):
			if tags.has(tag):
				var def: Dictionary = Content.statuses.get(status_id, {})
				return Loc.t("%s: can't %s") % [Loc.t(def.get("name", status_id)), Loc.t(tag)]
	return ""


func _tick_statuses(player: PlayerState, boundary: StringName) -> void:
	for status_id: StringName in player.statuses.keys():
		var status: Dictionary = player.statuses.get(status_id, {})
		if status.get("expires", &"never") != boundary:
			continue
		status["turns"] = status.get("turns", 1) - 1
		if status.turns <= 0:
			await remove_status(player, status_id)


# --- queries -----------------------------------------------------------------

func alive_players() -> Array:
	return players.filter(func(p): return p.alive)


## Living players in turn order, starting at `first`.
func seat_order(first: PlayerState) -> Array:
	var out := []
	var start := first.id if first != null else 0
	for i in players.size():
		var p: PlayerState = players[(start + i) % players.size()]
		if p.alive:
			out.append(p)
	return out


func opponents(player: PlayerState) -> Array:
	return players.filter(func(p): return p.alive and p != player)


func targetable_opponents(player: PlayerState) -> Array:
	return players.filter(func(p): return p.alive and p != player and not p.has_status(&"untargetable"))


func player_by_id(player_id: int) -> PlayerState:
	return players[player_id] if player_id >= 0 and player_id < players.size() else null


## Everything that can be bought right now, without repeats.
func items_on_sale() -> Array:
	var defs := fixed_items.duplicate()
	for def in shop:
		if def != null and not defs.has(def):
			defs.append(def)
	return defs


## Every item this match has, on the shelf or not; services (ItemDef.service)
## are not things anyone can hold.
func items_in_match() -> Array:
	return (fixed_items + item_pool).filter(func(def: ItemDef) -> bool: return not def.service)


func copies_in_play() -> int:
	return maxi(config.copies_per_character, config.min_copies(characters.size()))


func _random_item() -> ItemDef:
	if item_pool.is_empty():
		return null
	return item_pool[rng.randi_range(0, item_pool.size() - 1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp
