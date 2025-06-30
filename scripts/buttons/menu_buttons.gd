extends Node

@onready var play_button = $Play
@onready var quit_button = $Quit
# Called when the node enters the scene tree for the first time.
func _ready():
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit() -> void:
	get_tree().quit()
