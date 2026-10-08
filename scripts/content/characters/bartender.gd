extends CharacterDef
## Rosie Malone. Pours the drinks at the Quiver and hears every word.
##
## A spiked drink is a status with a `surcharge` (see GameEngine.price):
## whatever has a price costs whoever drank it more. It wears off with the
## turns of whoever poured it, not of whoever drank it, so it is ticked here.

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
			"description": "Whatever costs coins costs %d more: abilities, items, rerolls. Wears off at the end of the next turn of whoever spiked the drink." % SURCHARGE,
			"color": Color("7f9a3c"),
		},
	}
	_add(MickeyFinn.new())
	_add(LastCall.new())


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
		description = "Spike a player's drink. Whatever costs them coins costs %d more until the end of your next turn." % SURCHARGE
		on_turn = true
		targeting = Targeting.OPPONENT
		inflicts = true

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(GROGGY))

	func resolve(play: Play) -> void:
		await play.engine.add_status(play.target, GROGGY, {
			"by": play.actor.id, "surcharge": SURCHARGE, "poured": play.engine.turn_count,
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
		description = "Show a card from your hand. Everyone holding that character, you included, discards it and draws a new card."
		on_turn = true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var actor := play.actor
		var index := await engine.pick_own_card(actor, Loc.t("%s, last call: which card goes on the tray?") % actor.name)
		if index < 0 or engine.over or not actor.alive:
			return
		await engine.recall_cards(actor, index)

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 0.5
