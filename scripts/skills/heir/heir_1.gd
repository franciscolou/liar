extends Skill

signal heir_exchange

func action(player: Player) -> void:
	emit_signal("heir_exchange", self)
	player.coins += 5
