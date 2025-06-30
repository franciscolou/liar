extends Skill

signal damage

func action(player: Player) -> void:
	emit_signal("damage", self)
