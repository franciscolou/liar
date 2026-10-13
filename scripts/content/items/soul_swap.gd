extends ItemDef


func _init() -> void:
	id = &"soul_swap"
	display_name = "Soul Swap"
	description = "Trade a card of your choice for a random card of a chosen opponent."
	price = 2
	texture_path = "res://assets/items/soul_swap.png"
	targeting = Targeting.OPPONENT


func resolve(play: Play) -> void:
	# Whoever ends up trading says which card they hand over: the user, or the
	# holder of the mirror that sent it back (they are play.actor by then).
	var engine := play.engine
	var actor := play.actor
	var target := play.target
	if actor.cards.is_empty() or target.cards.is_empty():
		return
	if not await engine.reach_hand(actor, target, &"swap") or engine.over:
		return
	var given := await engine.pick_own_card(actor, Loc.t("%s, which card do you hand to %s?") % [actor.name, target.name])
	if given < 0 or engine.over or target.cards.is_empty():
		return
	await engine.swap_cards(actor, given, target, engine.random_card_index(target), true)


func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 0.5


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 0.4
