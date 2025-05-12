class_name Card

extends Node2D

@export var cname: String
@export var description: String
@export var skill1: Skill
@export var skill2: Skill
	
func flip() -> void:
	self.get_node("CardBack").visible = !self.get_node("CardBack").visible
