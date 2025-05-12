class_name Skill

extends Node

@export var sname: String
@export var description: String
@export var target_needed: bool

func action(player: Player) -> void: 
	print("Ação padrão!")
