extends ItemDef


func _init() -> void:
	id = &"cloak"
	display_name = "Invisibility Cloak"
	description = "You can't be targeted by abilities or items until your next turn starts."
	price = 7
	texture_path = "res://assets/items/cloak.png"
	status_defs = {
		&"untargetable": {
			"name": "Invisible",
			"description": "Can't be targeted by abilities or items until this player's next turn starts.",
			"color": Color("5c3a8c"),
		},
	}


func can_use(player: PlayerState, _engine: GameEngine) -> String:
	return Loc.t("Already invisible") if player.has_status(&"untargetable") else ""


func resolve(play: Play) -> void:
	await play.engine.add_status(play.actor, &"untargetable", {"expires": &"own_turn_start"})


func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
	return 3.0 if player.morale <= 1 else 0.3


func ai_buy_weight(player: PlayerState, _engine: GameEngine) -> float:
	return 1.5 if player.morale <= 1 else 0.4
