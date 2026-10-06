extends ItemDef


func _init() -> void:
	id = &"roulette"
	display_name = "Russian Roulette"
	description = "A random player, you included, loses 1 Morale."
	price = 2
	texture_path = "res://assets/items/roulette.png"
	targeting = Targeting.RANDOM
	tags = [&"damage"]


func target_candidates(play: Play) -> Array:
	return play.engine.players.filter(func(p): return p.alive and not p.has_status(&"untargetable"))


func resolve(play: Play) -> void:
	await play.engine.deal_damage(play.actor, play.target, play)


func ai_weight(player: PlayerState, engine: GameEngine) -> float:
	return 1.5 if player.morale > 1 and engine.alive_players().size() > 2 else 0.2


func ai_buy_weight(player: PlayerState, _engine: GameEngine) -> float:
	return 0.8 if player.morale > 1 else 0.1
