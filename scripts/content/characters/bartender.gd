extends CharacterDef
## Rosie Malone. Pours the drinks at the Quiver and hears every word.
##
## A spiked drink is a status with a `surcharge` (see GameEngine.price):
## whatever has a price costs whoever drank it more. It wears off the first
## time they pay for something, with that surcharge on it: it is ticked here.

const GROGGY := &"groggy"
const SURCHARGE := 2


func _init() -> void:
	id = &"bartender"
	display_name = "Bartender"
	title = "Rosie Malone"
	texture_path = "res://assets/cards/Bartender.png"
	order = 140
	status_defs = {
		GROGGY: {
			"name": "Groggy",
			"description": "Whatever costs coins costs %d more: abilities, items, rerolls. Wears off once this player has paid for something.", "args": [SURCHARGE],
			"color": Color("7f9a3c"),
		},
	}
	_add(MickeyFinn.new())
	_add(LastCall.new())


## What a payment is made for when it is a purchase (the `reason` of its
## "coins" event): a claim or a turn extra, and the shop. A fine is not one.
const PURCHASES: Array[StringName] = [&"cost", &"shop"]


func on_event(event: GameEvent, engine: GameEngine) -> void:
	# The drink is slept off with the first thing it made dearer.
	if event.type != &"coins" or event.data.delta >= 0 or not PURCHASES.has(event.data.reason):
		return
	var drinker: PlayerState = event.data.player
	if drinker.alive and drinker.has_status(GROGGY):
		await engine.remove_status(drinker, GROGGY)


class MickeyFinn extends Ability:
	func _init() -> void:
		id = &"bartender.mickey_finn"
		display_name = "Mickey Finn"
		describe("Spike a player's drink. The next thing they pay coins for costs them %d more.", [SURCHARGE])
		on_turn = true
		targeting = Targeting.OPPONENT
		inflicts = true

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(GROGGY))

	func resolve(play: Play) -> void:
		await play.engine.add_status(play.target, GROGGY, {
			"by": play.actor.id, "surcharge": SURCHARGE,
		})

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 0.7

	# A thin purse feels it the most: two coins may be the whole turn.
	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 2.5 if candidate.coins < 6 else 1.0


class LastCall extends Ability:
	func _init() -> void:
		id = &"bartender.last_call"
		display_name = "Last Call"
		description = "Name any character of the match. You and everyone else holding it discards it and draws a new card."
		on_turn = true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var actor := play.actor
		# Any character of the match, held or not: it is named, not shown.
		var cast: Array = engine.characters
		var d := Decision.new(Decision.Kind.PICK, actor)
		d.prompt = Loc.t("%s, last call: which character goes on the tray?") % actor.name
		d.options = cast.map(func(def: CharacterDef) -> Dictionary: return {"label": def.display_name, "card": def.id})
		d.context = {
			"play": play, "foreign": true,
			# A bot would rather not give up what it holds.
			"weights": cast.map(func(def: CharacterDef) -> float: return 0.2 if actor.has_character(def.id) else 1.0),
		}
		var index: int = await engine.ask(d)
		if index < 0 or index >= cast.size():
			index = engine.rng.randi_range(0, cast.size() - 1)
		if engine.over or not actor.alive:
			return
		await engine.recall_cards(actor, cast[index].id)

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 0.5
