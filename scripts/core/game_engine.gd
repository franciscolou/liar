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

## Reactions to reactions to reactions... stop being offered at this depth.
const MAX_REACTION_DEPTH := 4
const MAX_TURN_STEPS := 40

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
## Set by the table so bots can take a breath; null in headless runs.
var tree: SceneTree

var _reaction_depth := 0


func setup(game_config: GameConfig) -> void:
	Content.ensure_loaded()
	config = game_config
	if config.rng_seed != 0:
		rng.seed = config.rng_seed
	else:
		rng.randomize()

	var ids := config.character_ids.duplicate()
	if ids.is_empty():
		var all := Content.characters.keys()
		_shuffle(all)
		ids = all.slice(0, clampi(config.character_count, 1, all.size()))
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
	var index := 0
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
	for p in seat_order(current):
		if over or event.cancelled:
			return
		var options := reaction_options(p, event)
		if options.is_empty():
			continue
		var choice: Variant
		if event.data.get("auto") == p:
			choice = options[0]
		else:
			var d := Decision.new(Decision.Kind.REACT, p)
			d.options = options
			d.context = {"event": event}
			choice = await ask(d)
		if choice == null:
			continue
		_reaction_depth += 1
		if choice.kind == &"ability":
			await claim(p, choice.ability, event)
		else:
			await use_item(p, choice.item, event)
		_reaction_depth -= 1


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
			if option.enabled:
				out.append(option)
	for instance: ItemInstance in player.items:
		var def := instance.def
		if def.kind == ItemDef.Kind.REACTION and def.reacts_to(event, player, self):
			if blocked_reason(player, def.tags) == "" and def.can_use(player, self) == "":
				out.append({"kind": &"item", "item": instance, "enabled": true, "reason": ""})
	return out


# --- decisions ---------------------------------------------------------------

func ask(decision: Decision) -> Variant:
	if aborted:
		match decision.kind:
			Decision.Kind.DOUBT:
				return false
			Decision.Kind.PICK:
				return -1
		return null
	return await controllers[decision.player.id].decide(decision)


## Stops the match where it stands (the table was closed). Whatever is still
## suspended unwinds without touching controllers or observers again.
func abort() -> void:
	aborted = true
	over = true
	observers.clear()


## Lets bots hesitate when there is a table to watch.
func think(seconds: float) -> void:
	if tree != null and seconds > 0.0 and not aborted:
		await tree.create_timer(seconds / maxf(config.anim_speed, 0.1)).timeout


func turn_options(player: PlayerState) -> Dictionary:
	var out := {"abilities": [], "buy": [], "use": [], "extras": [], "reroll": null}
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
		var reason := "" if can_pay(player, config.reroll_cost) else Loc.t("Not enough coins")
		out.reroll = {
			"kind": &"reroll", "cost": config.reroll_cost, "enabled": reason == "",
			"reason": reason, "credit": config.reroll_cost > player.coins,
		}
	for instance: ItemInstance in player.items:
		var def := instance.def
		var reason := ""
		if def.kind != ItemDef.Kind.ACTIVE:
			reason = def.kind_label()
		else:
			reason = blocked_reason(player, def.tags)
			if reason == "":
				reason = def.can_use(player, self)
			if reason == "" and def.targeting != Playable.Targeting.NONE and _candidates_for(player, def).is_empty():
				reason = Loc.t("No valid target")
		out.use.append({"kind": &"use", "item": instance, "enabled": reason == "", "reason": reason})
	return out


## `slot` is the shop slot, or -1 for an item that is always on sale.
func _buy_option(player: PlayerState, def: ItemDef, slot: int) -> Dictionary:
	var reason := ""
	if player.items.size() >= config.inventory_limit:
		reason = Loc.t("Inventory full")
	elif not can_pay(player, def.price):
		reason = Loc.t("Not enough coins")
	return {
		"kind": &"buy", "slot": slot, "item": def, "enabled": reason == "",
		"reason": reason, "credit": def.price > player.coins,
	}


func ability_option(player: PlayerState, ability: Ability) -> Dictionary:
	var reason := claim_block_reason(player, ability)
	return {
		"kind": &"ability", "ability": ability, "enabled": reason == "", "reason": reason,
		"legit": player.has_character(ability.character_id), "credit": ability.cost > player.coins,
	}


func claim_block_reason(player: PlayerState, ability: Ability) -> String:
	if ability.info_only:
		return Loc.t("Always active")
	if player.has_status(&"truth_bound") and not player.has_character(ability.character_id):
		return Loc.t("Under Oath: you can't lie")
	var reason := blocked_reason(player, ability.tags)
	if reason != "":
		return reason
	if ability.fresh_turn and player.turn.get("busy", false):
		return Loc.t("Takes the whole turn")
	if ability.cost > 0 and not can_pay(player, ability.cost):
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
				await buy_item(p, choice.item, choice.slot)
			&"reroll":
				await reroll_shop(p)
			&"use":
				await use_item(p, choice.item)
			&"extra":
				p.turn["busy"] = true
				await choice.run.call(p, self)
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
## announcing it; otherwise the Play, whatever its outcome.
func claim(actor: PlayerState, ability: Ability, trigger: GameEvent = null) -> Play:
	var play := Play.new()
	play.engine = self
	play.actor = actor
	play.source = ability
	play.event = trigger
	play.cost = ability.cost
	play.truthful = actor.has_character(ability.character_id)
	if not await _choose_target(play):
		return null
	if not await ability.prepare(play):
		return null
	actor.turn["busy"] = true

	await fire(&"claim_declared", {"play": play})
	var doubter := await _doubt_window(play)
	var proven := false
	if doubter != null:
		if await challenge(doubter, play):
			await fire(&"claim_resolved", {"play": play})
			return play
		proven = true
	# The ability itself may send the card away (Fickle, Swindle...).
	var copies := actor.cards.count(ability.character_id)

	if not over and actor.alive:
		if not await pay(actor, play.cost):
			play.failed = true
		else:
			var resolving := await fire(&"claim_resolving", {"play": play})
			if resolving.cancelled:
				play.cancelled = true
				await fire(&"claim_cancelled", {"play": play})
			else:
				await _resolve(play)
	if proven and actor.cards.count(ability.character_id) >= copies:
		await renew_proven_card(actor, ability.character_id)
	await fire(&"claim_resolved", {"play": play})
	if not play.truthful and doubter == null and not play.failed and not over and actor.alive:
		await fire(&"lie_succeeded", {"play": play, "player": actor})
	return play


## `doubter` calls LIAR! on `play`, whose `truthful` must be up to date.
## Returns true if it was a lie. Also used for claims that stay open to doubt
## after they resolved (see voodooist.gd). When it was the truth, the caller
## owes the actor a renew_proven_card().
func challenge(doubter: PlayerState, play: Play) -> bool:
	var actor := play.actor
	play.doubter = doubter
	await fire(&"doubt_declared", {"play": play, "doubter": doubter})
	await fire(&"doubt_revealed", {"play": play, "doubter": doubter, "truthful": play.truthful})
	if play.truthful:
		await pay(doubter, config.doubt_cost, &"doubt")
		await fire(&"doubt_failed", {"play": play, "doubter": doubter, "defender": actor})
		return false
	play.failed = true
	await lose_morale(actor, 1, doubter, &"lie", play)
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
	if not await _choose_target(play):
		return null
	if not await instance.def.prepare(play):
		return null
	player.items.erase(instance)
	player.turn["busy"] = true
	instance.hidden = false
	await fire(&"item_used", {"player": player, "item": instance, "play": play})
	await _resolve(play)
	return play


## `slot` is the shop slot holding `def`, or -1 for an item that is always
## on sale (those never run out and take no slot).
func buy_item(player: PlayerState, def: ItemDef, slot := -1) -> void:
	var stocked := slot >= 0
	if stocked and (slot >= shop.size() or shop[slot] != def):
		return
	if not stocked and not fixed_items.has(def):
		return
	if def == null or player.items.size() >= config.inventory_limit:
		return
	if not await pay(player, def.price, &"shop"):
		return
	player.turn["busy"] = true
	if stocked:
		shop[slot] = null
	var instance := ItemInstance.new(def)
	await fire(&"item_buying", {"player": player, "item": instance, "slot": slot})
	if player.alive:
		player.items.append(instance)
		await fire(&"item_bought", {"player": player, "item": instance, "slot": slot})
	if stocked:
		shop[slot] = _random_item()
		await fire(&"shop_restocked", {"slot": slot})


## Pays to replace everything in the slots. Items always on sale stay.
func reroll_shop(player: PlayerState) -> void:
	if item_pool.is_empty() or not await pay(player, config.reroll_cost, &"shop"):
		return
	player.turn["busy"] = true
	for slot in shop.size():
		shop[slot] = _random_item()
	await fire(&"shop_rerolled", {"player": player})


func give_item(player: PlayerState, def: ItemDef, hidden := false) -> ItemInstance:
	if def == null or player.items.size() >= config.inventory_limit:
		return null
	var instance := ItemInstance.new(def)
	instance.hidden = hidden
	player.items.append(instance)
	await fire(&"item_gained", {"player": player, "item": instance})
	return instance


## Removes a held item without using it (shields and mirrors breaking).
func break_item(player: PlayerState, instance: ItemInstance) -> void:
	player.items.erase(instance)
	instance.hidden = false
	await fire(&"item_broken", {"player": player, "item": instance})


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


## Whether `player` could cover the fine for a wrong call, on credit if need be.
func can_doubt(player: PlayerState) -> bool:
	return player.alive and can_pay(player, config.doubt_cost)


func _doubt_window(play: Play) -> PlayerState:
	var voters := []
	for p in seat_order(play.actor):
		if p != play.actor and can_doubt(p):
			voters.append(p)
	# Humans answer first so that a bot's call never spoils theirs.
	var ordered := voters.filter(func(p): return not p.is_bot) + voters.filter(func(p): return p.is_bot)
	var doubters := []
	for p: PlayerState in ordered:
		if over:
			return null
		var d := Decision.new(Decision.Kind.DOUBT, p)
		d.context = {"play": play}
		if await ask(d):
			if not p.is_bot:
				return p
			doubters.append(p)
	for p in voters:
		if doubters.has(p):
			return p
	return null


func _resolve(play: Play) -> void:
	if play.target != null:
		var targeted := await fire(&"targeted", {"play": play, "target": play.target})
		if targeted.data.get("blocked", false):
			play.blocked = true
		elif targeted.data.get("reflected", false):
			if play.target == play.actor:
				play.blocked = true
			else:
				var original := play.actor
				play.actor = play.target
				play.target = original
				play.reflected = true
	if play.blocked or over or not play.actor.alive:
		return
	if play.target != null and not play.target.alive:
		return
	await play.source.resolve(play)


# --- coins -------------------------------------------------------------------

func can_pay(player: PlayerState, amount: int) -> bool:
	if player.coins >= amount:
		return true
	var probe := GameEvent.new(&"payment_short", {"player": player, "amount": amount})
	return not reaction_options(player, probe).is_empty()


func pay(player: PlayerState, amount: int, reason: StringName = &"cost") -> bool:
	if amount <= 0:
		return true
	if player.coins < amount:
		var short := await fire(&"payment_short", {
			"player": player, "amount": amount, "allowed": false, "auto": player,
		})
		if not short.data.allowed or over or not player.alive:
			return false
	await change_coins(player, -amount, reason)
	return true


func change_coins(player: PlayerState, delta: int, reason: StringName, other: PlayerState = null) -> void:
	if delta == 0:
		return
	player.coins += delta
	await fire(&"coins", {"player": player, "delta": delta, "reason": reason, "other": other})


func gain_coins(player: PlayerState, amount: int, reason: StringName, other: PlayerState = null) -> void:
	if amount <= 0 or not player.alive:
		return
	var gain := await fire(&"before_gain", {"player": player, "amount": amount, "reason": reason})
	if gain.data.amount > 0:
		await change_coins(player, gain.data.amount, reason, other)


## Returns how many coins actually changed hands.
func steal_coins(thief: PlayerState, victim: PlayerState, amount: int, play: Play = null) -> int:
	amount = mini(amount, maxi(victim.coins, 0))
	if amount <= 0:
		return 0
	var steal := await fire(&"before_steal", {
		"thief": thief, "victim": victim, "amount": amount, "play": play,
	})
	if steal.cancelled or over:
		return 0
	amount = mini(amount, maxi(victim.coins, 0))
	await change_coins(victim, -amount, &"stolen", thief)
	await gain_coins(thief, amount, &"steal", victim)
	return amount


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


## Any loss of Morale. `cause` is &"damage" or &"lie" (caught bluffing).
func lose_morale(target: PlayerState, amount: int, source: PlayerState, cause: StringName, play: Play = null) -> bool:
	if not target.alive:
		return false
	var before := await fire(&"before_morale_loss", {
		"target": target, "source": source, "amount": amount, "cause": cause, "play": play,
	})
	if before.cancelled or before.data.amount <= 0 or not target.alive:
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


func _eliminate(player: PlayerState, killer: PlayerState, play: Play) -> void:
	player.alive = false
	deck.append_array(player.cards)
	_shuffle(deck)
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
		var index := 0
		if player.cards.size() > 1:
			var d := Decision.new(Decision.Kind.PICK, player)
			d.prompt = Loc.t("%s, you lost Morale: give up a card") % player.name
			d.options = player.cards.map(func(card): return {
				"label": Content.character(card).display_name, "card": card,
			})
			index = await ask(d)
			if index < 0 or index >= player.cards.size():
				index = random_card_index(player)
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


## A doubt showed the whole table that `player` holds `character_id`: the card
## goes back to the deck and they draw another one.
func renew_proven_card(player: PlayerState, character_id: StringName) -> void:
	if over or not player.alive:
		return
	await replace_card(player, player.cards.find(character_id), &"proven")


func swap_cards(a: PlayerState, a_index: int, b: PlayerState, b_index: int) -> void:
	if a_index < 0 or a_index >= a.cards.size() or b_index < 0 or b_index >= b.cards.size():
		return
	var card: StringName = a.cards[a_index]
	a.cards[a_index] = b.cards[b_index]
	b.cards[b_index] = card
	await fire(&"cards_swapped", {"a": a, "a_index": a_index, "b": b, "b_index": b_index})


func peek_card(viewer: PlayerState, owner: PlayerState) -> void:
	if owner.cards.is_empty():
		return
	var index := rng.randi_range(0, owner.cards.size() - 1)
	await fire(&"card_peeked", {
		"viewer": viewer, "owner": owner, "index": index, "card": owner.cards[index],
	})


func random_card_index(player: PlayerState) -> int:
	return rng.randi_range(0, player.cards.size() - 1) if not player.cards.is_empty() else -1


# --- statuses ----------------------------------------------------------------

## options: expires (&"own_turn_start" | &"own_turn_end" | &"never"),
## turns (how many of those boundaries it survives, default 1),
## by (player id that applied it), blocks (tags the player can't use).
func add_status(player: PlayerState, status_id: StringName, options: Dictionary = {}) -> void:
	if not player.alive:
		return
	player.statuses[status_id] = options
	await fire(&"status_added", {"player": player, "status": status_id})


func remove_status(player: PlayerState, status_id: StringName) -> void:
	if player.statuses.erase(status_id):
		await fire(&"status_removed", {"player": player, "status": status_id})


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
