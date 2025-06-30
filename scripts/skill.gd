class_name Skill

extends Node

@export var sname: String
@export var description: String
@export var target_needed: bool
@export var ends_turn: bool

func action(player: Player) -> void: 
	print("Ação padrão!")
	
func can_make_action(player: Player) -> bool:
	return true
