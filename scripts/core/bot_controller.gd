class_name BotController
extends Controller
## A simple opponent: plays its real cards most of the time, bluffs now and
## then, and doubts when a claim looks impossible or too dangerous to allow.
## Content steers it through the ai_* hints on Playable.

var boldness := 0.3  # appetite for bluffing
var suspicion := 0.1  # base chance of doubting any claim
var _claims: Dictionary = {}  # player id -> {character id: true}
var _steps := 0


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
		&"cards_changed", &"card_lost", &"card_drawn":
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
			return _doubt(d.context.play)
		Decision.Kind.REACT:
			return _react(d)
		Decision.Kind.PICK:
			return engine.rng.randi_range(0, d.options.size() - 1) if not d.options.is_empty() else -1
	return null


func _turn(options: Dictionary) -> Dictionary:
	_steps += 1
	if _steps > 6:
		return {"kind": &"end"}
	var rng := engine.rng

	for extra: Dictionary in options.extras:
		if extra.enabled and rng.randf() < extra.get("ai", 0.7):
			return extra

	for use: Dictionary in options.use:
		if use.enabled and rng.randf() < use.item.def.ai_weight(player, engine) / 3.0:
			return use

	var buys := {}
	for buy: Dictionary in options.buy:
		# Bots only shop with coins they actually have.
		if buy.enabled and not buy.credit:
			buys[buy] = buy.item.ai_buy_weight(player, engine)
	if not buys.is_empty() and rng.randf() < 0.45:
		var buy: Variant = _weighted(buys)
		if buy != null:
			return buy
	var reroll: Variant = options.reroll
	if reroll != null and reroll.enabled and player.coins >= reroll.cost + 4 and rng.randf() < 0.08:
		return reroll

	var plays := {}
	for option: Dictionary in options.abilities:
		if not option.enabled:
			continue
		var weight: float = option.ability.ai_weight(player, engine)
		if not option.legit:
			weight *= boldness
		if option.credit and not player.has_character(&"vagabond"):
			weight *= 0.05
		plays[option] = weight
	var choice: Variant = _weighted(plays)
	return choice if choice != null else {"kind": &"end"}


func _target(d: Decision) -> Variant:
	var play: Play = d.context.get("play")
	var weights := {}
	for candidate: PlayerState in d.options:
		weights[candidate] = play.source.ai_target_weight(play, candidate) if play != null else 1.0
	return _weighted(weights)


func _doubt(play: Play) -> bool:
	var ability := play.ability()
	if play.actor.has_status(&"truth_bound"):
		return false
	# Holding every copy of the character proves the claim is a lie.
	if player.cards.count(ability.character_id) >= engine.copies_in_play():
		return true
	# A wrong call would have to go on a tab the bot can't back up.
	if player.coins < engine.config.doubt_cost and not player.has_character(&"vagabond"):
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
	# Someone who has already claimed more characters than fit in a hand.
	if _claims.get(play.actor.id, {}).size() > engine.config.hand_size:
		chance += 0.15
	if player.coins - engine.config.doubt_cost < 2:
		chance *= 0.5
	return engine.rng.randf() < chance


func _react(d: Decision) -> Variant:
	var event: GameEvent = d.context.event
	for option: Dictionary in d.options:
		var chance := 0.0
		if option.kind == &"ability":
			chance = option.ability.ai_react_weight(event, player, engine)
			if not option.legit:
				chance *= boldness * 0.8
			if option.credit and not player.has_character(&"vagabond"):
				chance *= 0.2
		else:
			chance = option.item.def.ai_react_weight(event, player, engine)
		if engine.rng.randf() < chance:
			return option
	return null


func _weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return null
	var roll := engine.rng.randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0:
			return key
	return weights.keys().back()
