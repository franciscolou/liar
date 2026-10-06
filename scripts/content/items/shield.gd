extends ItemDef


func _init() -> void:
	id = &"shield"
	display_name = "Shield"
	description = "While you hold it, the next ability or item aimed at you is blocked. The shield breaks."
	price = 5
	texture_path = "res://assets/items/shield.png"
	kind = Kind.PASSIVE


func on_held_event(event: GameEvent, holder: PlayerState, instance: ItemInstance, engine: GameEngine) -> void:
	if event.type != &"targeted" or event.data.target != holder:
		return
	if event.data.get("blocked", false) or event.data.get("reflected", false) or event.data.play.reflected:
		return
	event.data["blocked"] = true
	await engine.break_item(holder, instance)


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.5
