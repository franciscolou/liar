extends ItemDef


func _init() -> void:
	id = &"death"
	display_name = "Death"
	description = "The target loses 1 Morale."
	price = 7
	fixed = true
	texture_path = "res://assets/items/death.png"
	targeting = Targeting.OPPONENT
	tags = [&"damage"]


func resolve(play: Play) -> void:
	await play.engine.deal_damage(play.actor, play.target, play)


func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 3.0


func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 2.5


func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
	return 1.0 + (3 - candidate.morale)
