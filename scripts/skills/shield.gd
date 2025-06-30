extends Skill

func action(player: Player) -> void:
	player.shielded = true
	player.get_node("ShieldIndicator").visible = true

func can_make_action(player: Player) -> bool:
	return !player.shielded
