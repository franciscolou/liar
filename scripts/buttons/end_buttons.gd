extends Node

@onready var again_button = $Again
@onready var back_button = $Back
# Called when the node enters the scene tree for the first time.
func _ready():
	again_button.pressed.connect(_on_again)
	back_button.pressed.connect(_on_back)


func _on_again() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
