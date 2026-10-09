extends CharacterDef
## M. Bones. Information and discretion.


func _init() -> void:
	id = &"spy"
	display_name = "Spy"
	title = "M. Bones"
	texture_path = "res://assets/cards/Spy.png"
	order = 10
	_add(SneakPeek.new())
	_add(LowProfile.new())


class SneakPeek extends Ability:
	func _init() -> void:
		id = &"spy.sneak_peek"
		display_name = "Sneak Peek"
		description = "See a random card from a chosen player."
		on_turn = true
		targeting = Targeting.OPPONENT

	func resolve(play: Play) -> void:
		await play.engine.peek_card(play.actor, play.target)


class LowProfile extends Ability:
	func _init() -> void:
		id = &"spy.low_profile"
		display_name = "Low Profile"
		description = "Hide the item you just bought from the other players. The shop keeps it on sale, so nobody can tell what you took."
		trigger_text = "When you buy an item"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"item_buying" and event.data.player == player

	func resolve(play: Play) -> void:
		play.event.data.item.hidden = true

	func ai_react_weight(_event: GameEvent, _player: PlayerState, _engine: GameEngine) -> float:
		return 0.6
