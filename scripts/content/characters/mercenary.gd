extends CharacterDef
## Pablo Bianque. Gets paid for bodies.


func _init() -> void:
	id = &"mercenary"
	display_name = "Mercenary"
	title = "Pablo Bianque"
	texture_path = "res://assets/cards/Mercenary.png"
	order = 20
	_add(Bounty.new())
	_add(Collateral.new())


class Bounty extends Ability:
	const REWARD := 7

	func _init() -> void:
		id = &"mercenary.bounty"
		display_name = "Bounty"
		description = "Gain %d coins." % REWARD
		trigger_text = "When you eliminate a player"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"player_eliminated" and event.data.killer == player

	func resolve(play: Play) -> void:
		await play.engine.gain_coins(play.actor, REWARD, &"bounty")


class Collateral extends Ability:
	func _init() -> void:
		id = &"mercenary.collateral"
		display_name = "Collateral"
		description = "Pay 5 coins to also damage another player."
		trigger_text = "When you deal damage"
		cost = 5
		targeting = Targeting.OPPONENT
		tags = [&"damage"]

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"damage_dealt" and event.data.source == player

	func target_candidates(play: Play) -> Array:
		var already_hit: PlayerState = play.event.data.target if play.event != null else null
		return play.engine.targetable_opponents(play.actor).filter(func(p): return p != already_hit)

	func resolve(play: Play) -> void:
		await play.engine.deal_damage(play.actor, play.target, play)
