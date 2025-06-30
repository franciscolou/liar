extends Skill

signal damage

func action(player: Player) -> void:
	emit_signal("damage", self)
	player.coins -= 4

func can_make_action(player: Player) -> bool:
	return player.coins >= 4
