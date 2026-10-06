extends ItemDef


func _init() -> void:
	id = &"silencer"
	display_name = "Silencer"
	description = "Use it the moment an opponent's ability is about to take effect: the ability is cancelled."
	price = 6
	texture_path = "res://assets/items/silencer.png"
	kind = Kind.REACTION


func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
	return event.type == &"claim_resolving" and event.data.play.actor != player


func resolve(play: Play) -> void:
	play.event.cancelled = true


func ai_react_weight(event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
	var incoming: Play = event.data.play
	if incoming.target == player:
		return 0.95 if incoming.source.tags.has(&"damage") or incoming.source.tags.has(&"steal") else 0.5
	return 0.05


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.0
