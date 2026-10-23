extends Node
## Opens the match screen with a full table (the viewer and seven bots), in
## touch mode or not, to look at its layout. Not part of any test run.

@export var touch := true
@export var bots := 7

const TouchMode := preload("res://scripts/ui/touch_mode.gd")


func _ready() -> void:
	Settings.ensure_loaded()
	TouchMode._apply(touch)
	var c := GameConfig.default_config()
	c.seats = [{"name": "chiconet", "bot": false}]
	var names := ["Bones", "Pablo", "Miah", "Valentino", "Judson", "Vincent", "Dolores"]
	for i in bots:
		c.seats.append({"name": names[i], "bot": true})
	c.character_ids = []
	c.character_count = 20
	c.copies_per_character = c.min_copies(20)
	c.suspect_book = true
	c.first_seat = 1
	GameConfig.current = c
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
