extends Skill

func action(player: Player) -> void:
	var target_card = player.target.cards.pick_random()
	target_card.flip()
	await player.get_tree().create_timer(4.0).timeout
	target_card.flip()
