extends ItemDef


func _init() -> void:
	id = &"shield"
	display_name = "Shield"
	description = "While you hold it, the next ability or item aimed at you is blocked. The shield breaks."
	price = 5
	texture_path = "res://assets/items/shield.png"
	kind = Kind.PASSIVE
	guard = true


func on_held_event(event: GameEvent, holder: PlayerState, instance: ItemInstance, engine: GameEngine) -> void:
	if not await engine.guards(instance, holder, event):
		return
	event.data["blocked"] = true
	await engine.break_item(holder, instance)


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.5
