extends CharacterDef
## Judson Varela. There is no order without justice.


func _init() -> void:
	id = &"judge"
	display_name = "Judge"
	title = "Judson Varela"
	texture_path = "res://assets/cards/Judge.png"
	order = 70
	status_defs = {
		&"truth_bound": {
			"name": "Under Oath",
			"description": "Can't lie: may only use abilities of characters actually held. Lasts until the end of this player's next turn.",
			"color": Color("c9a24a"),
		},
	}
	_add(UnderOath.new())
	_add(ContemptOfCourt.new())


class UnderOath extends Ability:
	func _init() -> void:
		id = &"judge.under_oath"
		display_name = "Under Oath"
		description = "Choose a player. They can't lie until the end of their next turn."
		on_turn = true
		targeting = Targeting.OPPONENT

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(&"truth_bound"))

	func resolve(play: Play) -> void:
		await play.engine.add_status(play.target, &"truth_bound", {"expires": &"own_turn_end"})

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 0.7


class ContemptOfCourt extends Ability:
	const FINE := 5

	func _init() -> void:
		id = &"judge.contempt"
		display_name = "Contempt of Court"
		description = "Take up to %d coins from the player who doubted you." % FINE
		trigger_text = "When you are doubted and were telling the truth"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return (event.type == &"doubt_failed" and event.data.defender == player
				and event.data.doubter.alive and event.data.doubter.coins > 0)

	func resolve(play: Play) -> void:
		await play.engine.steal_coins(play.actor, play.event.data.doubter, FINE, play)
