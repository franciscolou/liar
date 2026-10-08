class_name BotController
extends Controller
## A simple opponent: plays its real cards most of the time, bluffs now and
## then, and doubts when a claim looks impossible or too dangerous to allow.
## Content steers it through the ai_* hints on Playable.

var boldness := 0.3  # appetite for bluffing
var suspicion := 0.1  # base chance of doubting any claim
var _claims: Dictionary = {}  # player id -> {character id: true}
var _steps := 0
## Its own dice, for a bot whose rolls must not disturb the match's (see
## HumanController.stand_in). Null: it rolls the engine's.
var rng: RandomNumberGenerator


func observe(event: GameEvent) -> void:
	match event.type:
		&"turn_started":
			if event.data.player == player:
				_steps = 0
		&"claim_declared":
			var play: Play = event.data.play
			if not _claims.has(play.actor.id):
				_claims[play.actor.id] = {}
			_claims[play.actor.id][play.ability().character_id] = true
		&"cards_changed", &"card_lost", &"card_drawn", &"hand_redrawn":
			_claims.erase(event.data.player.id)
		&"cards_swapped":
			_claims.erase(event.data.a.id)
			_claims.erase(event.data.b.id)


func decide(d: Decision) -> Variant:
	match d.kind:
		Decision.Kind.TURN:
			await engine.think(0.7)
			return _turn(d.options)
		Decision.Kind.TARGET:
			await engine.think(0.3)
			return _target(d)
		Decision.Kind.DOUBT:
			return _doubt(d.context.play, d.options)
		Decision.Kind.REACT:
			return _react(d)
		Decision.Kind.PICK:
			return _pick(d)
	return null


func _turn(options: Dictionary) -> Dictionary:
	_steps += 1
	if _steps > 6:
		return {"kind": &"end"}
	var dice := _dice()

	# Something it wants and can't pay for yet (breaking a hex, defusing a
	# bomb): it stops spending until it can.
	var saving := false
	for extra: Dictionary in options.extras:
		if extra.enabled and dice.randf() < extra.get("ai", 0.7):
			return extra
		if not extra.enabled and extra.get("cost", 0) > player.coins and extra.get("ai", 0.7) >= 0.5:
			saving = true

	for use: Dictionary in options.use:
		if use.enabled and dice.randf() < use.item.def.ai_weight(player, engine) / 3.0:
			return use

	var buys := {}
	# The last free slot is kept for something it can use: an inventory full
	# of shields and money bags can't take the item that would end the match.
	var last_slot := player.items.size() >= engine.config.inventory_limit - 1
	for buy: Dictionary in options.buy:
		if last_slot and buy.item.kind != ItemDef.Kind.ACTIVE:
			continue
		# Bots only shop with coins they actually have.
		if buy.enabled and not buy.credit and not saving:
			buys[buy] = buy.item.ai_buy_weight(player, engine)
	if not buys.is_empty() and dice.randf() < 0.45:
		var buy: Variant = _weighted(buys)
		if buy != null:
			return buy
	var reroll: Variant = options.reroll
	if reroll != null and reroll.enabled and player.coins >= reroll.cost + 4 and dice.randf() < 0.08:
		return reroll

	var plays := {}
	for option: Dictionary in options.abilities:
		if not option.enabled:
			continue
		var weight: float = option.ability.ai_weight(player, engine)
		if not option.legit:
			weight *= boldness / oath_caution(player, engine)
		if option.credit and not player.has_character(&"vagabond"):
			weight *= 0.05
		if saving and option.ability.cost > 0:
			weight *= 0.1
		plays[option] = weight
	var choice: Variant = _weighted(plays)
	return choice if choice != null else {"kind": &"end"}


func _target(d: Decision) -> Variant:
	var play: Play = d.context.get("play")
	var weights := {}
	for candidate: PlayerState in d.options:
		weights[candidate] = play.source.ai_target_weight(play, candidate) if play != null else 1.0
	return _weighted(weights)


## The stake to call LIAR! with, or false to let the claim pass.
func _doubt(play: Play, stakes: Array) -> Variant:
	var ability := play.ability()
	if stakes.is_empty():
		return false
	# Holding every copy of the character proves the claim is a lie.
	if player.cards.count(ability.character_id) >= engine.copies_in_play():
		return stakes[0]
	var stake := doubt_stake(player, stakes)
	if stake == &"":
		return false
	# Bots grow impatient, so that a table of cowards still ends the match.
	var chance := suspicion + minf(engine.turn_count * 0.002, 0.25)
	if play.target == player:
		chance += 0.12
		if ability.tags.has(&"damage"):
			chance += 0.15 if player.morale > 1 else 0.4
		if ability.tags.has(&"steal") and player.coins >= 5:
			chance += 0.25
	chance += 0.1 * player.cards.count(ability.character_id)
	chance += ability.ai_suspicion(play, player)
	# Someone who has already claimed more characters than fit in a hand.
	if _claims.get(play.actor.id, {}).size() > engine.config.hand_size:
		chance += 0.15
	# Few people bluff Under Oath, with their whole purse on the line.
	chance /= oath_caution(play.actor, engine)
	if stake == GameEngine.STAKE_MORALE:
		chance *= 0.4
	elif player.coins - engine.config.doubt_cost < 2:
		chance *= 0.5
	return stake if _dice().randf() < chance else false


## How much less a bluff is worth to `who` right now, for the coins a lie
## caught Under Oath would cost: 1 with nothing extra at stake.
static func oath_caution(who: PlayerState, game: GameEngine) -> float:
	return 1.0 + game.oath_stake(who) / 6.0


## What a bot that isn't sure would put up, or &"" if nothing is worth it.
static func doubt_stake(who: PlayerState, stakes: Array) -> StringName:
	if stakes.has(GameEngine.STAKE_COINS):
		return GameEngine.STAKE_COINS
	# A tab the bot can back up beats bleeding for a hunch.
	if stakes.has(GameEngine.STAKE_DEBT) and who.has_character(&"vagabond"):
		return GameEngine.STAKE_DEBT
	if stakes.has(GameEngine.STAKE_MORALE) and who.morale > 1:
		return GameEngine.STAKE_MORALE
	return &""


func _react(d: Decision) -> Variant:
	var event: GameEvent = d.context.event
	for option: Dictionary in d.options:
		var chance := 0.0
		if option.kind == &"ability":
			chance = option.ability.ai_react_weight(event, player, engine)
			if not option.legit:
				chance *= boldness * 0.8 / oath_caution(player, engine)
			if option.credit and not player.has_character(&"vagabond"):
				chance *= 0.2
		else:
			chance = option.item.def.ai_react_weight(event, player, engine)
		if _dice().randf() < chance:
			return option
	return null


## An option at random, leaning towards what the content says is better.
func _pick(d: Decision) -> int:
	if d.options.is_empty():
		return -1
	var hints: Array = d.context.get("weights", [])
	var weights := {}
	for i: int in d.options.size():
		weights[i] = float(hints[i]) if i < hints.size() else 1.0
	var choice: Variant = _weighted(weights)
	return choice if choice != null else _dice().randi_range(0, d.options.size() - 1)


func _dice() -> RandomNumberGenerator:
	return rng if rng != null else engine.rng


func _weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return null
	var roll := _dice().randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0:
			return key
	return weights.keys().back()
