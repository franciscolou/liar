extends ItemDef


func _init() -> void:
	id = &"mirror"
	display_name = "Magic Mirror"
	description = "While you hold it, the next ability or item aimed at you bounces back to its user. The mirror breaks. Their own Mirror or Shield may answer it."
	price = 9
	texture_path = "res://assets/items/mirror.png"
	kind = Kind.PASSIVE
	guard = true


func on_held_event(event: GameEvent, holder: PlayerState, instance: ItemInstance, engine: GameEngine) -> void:
	if not await engine.guards(instance, holder, event):
		return
	event.data["reflected"] = true
	await engine.break_item(holder, instance)


# Sending it back beats stopping it, unless whoever sent it can answer in kind.
func ai_guard_weight(play: Play, _holder: PlayerState) -> float:
	var answered := play.actor.items.any(
		func(other: ItemInstance) -> bool: return other.def.guard and not other.hidden)
	return 0.3 if answered else 3.0


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.5
