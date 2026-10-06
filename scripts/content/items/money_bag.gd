extends ItemDef

const BONUS := 2


func _init() -> void:
	id = &"money_bag"
	display_name = "Money Bag"
	description = "While you hold it, your income at the start of each turn is %d coins higher." % BONUS
	price = 5
	texture_path = "res://assets/items/money_bag.png"
	kind = Kind.PASSIVE


func on_held_event(event: GameEvent, holder: PlayerState, _instance: ItemInstance, _engine: GameEngine) -> void:
	if event.type == &"income" and event.data.player == holder:
		event.data.amount += BONUS


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 2.0
