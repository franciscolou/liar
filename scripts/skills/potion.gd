extends Skill

signal recover

func action(player: Player) -> void:
	emit_signal("recover", self)

func can_make_action(player: Player) -> bool:
	return player.cards.size() < 2
