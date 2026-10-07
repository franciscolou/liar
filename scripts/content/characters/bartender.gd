extends CharacterDef
## Rosie Malone. Pours the drinks at the Quiver and hears every word.
##
## A spiked drink is a status that blocks the tag &"doubt" (see
## GameEngine.doubt_stakes). It wears off with the turns of whoever poured
## it, not of whoever drank it, so it is ticked here.

const GROGGY := &"groggy"


func _init() -> void:
	id = &"bartender"
	display_name = "Bartender"
	title = "Rosie Malone"
	texture_path = "res://assets/cards/Bartender.png"
	order = 140
	status_defs = {
		GROGGY: {
			"name": "Groggy",
			"description": "Can't call LIAR! on anyone. Wears off at the end of the next turn of whoever spiked the drink.",
			"color": Color("7f9a3c"),
		},
	}
	_add(MickeyFinn.new())
	_add(LiquidCourage.new())


func on_event(event: GameEvent, engine: GameEngine) -> void:
	match event.type:
		&"turn_ended":
			var host: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if not p.alive or not p.has_status(GROGGY):
					continue
				var status: Dictionary = p.statuses[GROGGY]
				# Poured during this very turn: it lasts through the next one.
				if status.get("by", -1) == host.id and status.get("poured", 0) < engine.turn_count:
					await engine.remove_status(p, GROGGY)
		&"player_eliminated":
			var dead: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if p.alive and p.has_status(GROGGY) and p.statuses[GROGGY].get("by", -1) == dead.id:
					await engine.remove_status(p, GROGGY)


class MickeyFinn extends Ability:
	func _init() -> void:
		id = &"bartender.mickey_finn"
		display_name = "Mickey Finn"
		description = "Pay 3 coins to spike a player's drink. They can't call LIAR! until the end of your next turn."
		on_turn = true
		cost = 3
		targeting = Targeting.OPPONENT
		inflicts = true

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(GROGGY))

	func resolve(play: Play) -> void:
		await play.engine.add_status(play.target, GROGGY, {
			"by": play.actor.id, "blocks": [&"doubt"], "poured": play.engine.turn_count,
		})

	# Wasted on a table too broke to doubt anyone.
	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		for p: PlayerState in engine.opponents(player):
			if p.coins >= engine.config.doubt_cost and not p.has_status(GROGGY):
				return 0.9
		return 0.15

	# Whoever can afford a wrong call is the one doing the calling.
	func ai_target_weight(play: Play, candidate: PlayerState) -> float:
		return 3.0 if candidate.coins >= play.engine.config.doubt_cost else 1.0


class LiquidCourage extends Ability:
	const REFUND := 4

	func _init() -> void:
		id = &"bartender.liquid_courage"
		display_name = "Liquid Courage"
		description = "Gain %d coins: the wrong call is on the house." % REFUND
		trigger_text = "When you call LIAR! and were wrong"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"doubt_failed" and event.data.doubter == player

	func resolve(play: Play) -> void:
		await play.engine.gain_coins(play.actor, REFUND, &"liquid_courage")
