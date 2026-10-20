extends ItemDef


func _init() -> void:
	id = &"soul_swap"
	display_name = "Soul Swap"
	description = "Trade a random card of yours for a random card of a chosen opponent."
	price = 2
	texture_path = "res://assets/items/soul_swap.png"
	targeting = Targeting.OPPONENT


func resolve(play: Play) -> void:
	# Neither side chooses: a random card of whoever ends up trading (the user,
	# or the holder of the mirror that sent it back) for a random one of the other.
	var engine := play.engine
	var actor := play.actor
	var target := play.target
	if actor.cards.is_empty() or target.cards.is_empty():
		return
	if not await engine.reach_hand(actor, target, &"swap") or engine.over:
		return
	if actor.cards.is_empty() or target.cards.is_empty():
		return
	await engine.swap_cards(actor, engine.random_card_index(actor), target, engine.random_card_index(target), true)


func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 0.5


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 0.4
