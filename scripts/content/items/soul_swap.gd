extends ItemDef


func _init() -> void:
	id = &"soul_swap"
	display_name = "Soul Swap"
	description = "Trade one of your cards, at random, for a random card of a chosen opponent."
	price = 2
	texture_path = "res://assets/items/soul_swap.png"
	targeting = Targeting.OPPONENT


func resolve(play: Play) -> void:
	var engine := play.engine
	await engine.swap_cards(
		play.actor, engine.random_card_index(play.actor),
		play.target, engine.random_card_index(play.target))


func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 0.5


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 0.4
