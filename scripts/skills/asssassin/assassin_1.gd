extends Skill

signal assassin_damage

func action(player: Player) -> void:
	emit_signal("assassin_damage", self)
	player.coins -= 4
