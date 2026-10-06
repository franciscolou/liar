extends ItemDef


func _init() -> void:
	id = &"potion"
	display_name = "Potion"
	description = "Recover 1 Morale."
	price = 10
	texture_path = "res://assets/items/potion.png"
	tags = [&"heal"]


func can_use(player: PlayerState, engine: GameEngine) -> String:
	return "" if player.morale < engine.config.start_morale else Loc.t("Morale is full")


func resolve(play: Play) -> void:
	await play.engine.heal(play.actor, 1)


func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 3.0


func ai_buy_weight(player: PlayerState, engine: GameEngine) -> float:
	return 2.0 if player.morale < engine.config.start_morale else 0.0
