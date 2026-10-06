extends CharacterDef
## Augustus Belmont. Money was never the problem.


func _init() -> void:
	id = &"heir"
	display_name = "Heir"
	title = "Augustus Belmont"
	texture_path = "res://assets/cards/Heir.png"
	order = 40
	_add(Fickle.new())
	_add(SoldOut.new())


class Fickle extends Ability:
	func _init() -> void:
		id = &"heir.fickle"
		display_name = "Fickle"
		description = "Swap this card for a random one and gain 5 coins."
		on_turn = true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var index := play.actor.cards.find(character_id)
		if index == -1:
			index = engine.random_card_index(play.actor)
		await engine.replace_card(play.actor, index, &"fickle")
		await engine.gain_coins(play.actor, 5, &"fickle")

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		return 0.5 if player.has_character(character_id) else 1.0


class SoldOut extends Ability:
	func _init() -> void:
		id = &"heir.sold_out"
		display_name = "Sold Out"
		description = "Spend your whole turn to gain 5 coins."
		on_turn = true
		fresh_turn = true

	func resolve(play: Play) -> void:
		await play.engine.gain_coins(play.actor, 5, &"sold_out")

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.4
