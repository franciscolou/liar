extends CharacterDef
## M. Bones. Information and discretion.


func _init() -> void:
	id = &"spy"
	display_name = "Spy"
	title = "M. Bones"
	texture_path = "res://assets/cards/Spy.png"
	order = 10
	_add(SneakPeek.new())
	_add(Untraceable.new())


class SneakPeek extends Ability:
	func _init() -> void:
		id = &"spy.sneak_peek"
		display_name = "Sneak Peek"
		description = "See a random card from a chosen player."
		on_turn = true
		targeting = Targeting.OPPONENT

	func resolve(play: Play) -> void:
		await play.engine.peek_card(play.actor, play.target)


class Untraceable extends Ability:
	func _init() -> void:
		id = &"spy.untraceable"
		display_name = "Untraceable"
		description = "Your cards vanish until it is over: they can't be seen, taken or replaced."
		trigger_text = "When another player is about to see, take or replace one of your cards"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"before_hand_reach" and event.data.owner == player

	func resolve(play: Play) -> void:
		play.event.cancelled = true

	func ai_react_weight(_event: GameEvent, _player: PlayerState, _engine: GameEngine) -> float:
		return 0.85
