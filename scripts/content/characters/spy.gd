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
		description = "See a card of your choice from a player."
		on_turn = true
		targeting = Targeting.OPPONENT

	func resolve(play: Play) -> void:
		await play.engine.peek_card(play.actor, play.target)


class Untraceable extends Ability:
	func _init() -> void:
		id = &"spy.untraceable"
		display_name = "Untraceable"
		description = "Your cards and items can't be seen or manipulated."
		trigger_text = "When another player is about to see or mess with your cards or your items, or your own Last Call calls in your cards"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		# Their hand (GameEngine.reach_hand) or what they hold (reach_items).
		return (event.type == &"before_hand_reach" or event.type == &"before_item_reach") and event.data.owner == player

	func resolve(play: Play) -> void:
		play.event.cancelled = true

	func ai_react_weight(event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
		# A Last Call asks every hand: with no copy of the card there is
		# nothing to keep, but now and then a hand vanishes all the same.
		if event.type == &"before_hand_reach" and event.data.how == &"recall" and not player.cards.has(event.data.card):
			return 0.15
		return 0.85
