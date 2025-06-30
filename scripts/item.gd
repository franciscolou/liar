class_name Item

extends Node2D

@export var iname: String
@export var description: String
@export var price: int
@export var action: Skill

var i_owner: Player = null

var is_hidden: bool = false

func flip() -> void:
	self.get_node("ItemBack").visible = !self.get_node("ItemBack").visible
