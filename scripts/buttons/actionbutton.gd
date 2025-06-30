extends Button

@onready var gm := get_node("/root/Main/GameManager")

func _on_button_down() -> void:
	pass

func _on_item_selected(index):
	var skill_scene = $".".get_item_metadata(index)
	if skill_scene.can_make_action(gm.current_player):
		gm.set_log(gm.current_player.pname + " chose " + skill_scene.sname + " from " + skill_scene.get_parent().cname + ".")
		self.disabled = true
		if skill_scene.target_needed and gm.current_player.target == null:
			gm.state = "waiting_target"
		else:
			gm.state = "waiting_approval"
		gm.current_player.requested_action = skill_scene.sname
		gm.show_challenge_options(gm.current_player)
